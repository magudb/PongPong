extends RefCounted
const SECTION := "release_updates"
const V := preload("res://scripts/release/release_version.gd")

func _release() -> Dictionary:
	return {"tag_name": "v1.2.3", "draft": false, "prerelease": false, "assets": [{"name": "Traetoppen-v1.2.3-windows.zip", "browser_download_url": "https://github.com/magudb/PongPong/releases/download/v1.2.3/Traetoppen-v1.2.3-windows.zip", "digest": "sha256:" + "a".repeat(64), "size": 12345}]}

func run(t) -> void:
	for pair in [["1.10.0", "1.9.9"], ["2.0.0", "1.99.99"], ["0.1.1", "0.1.0"]]:
		t.check("semver_" + pair[0], V.newer(pair[0], pair[1]))
	for version in ["1.2", "01.2.3", "1.2.3-beta", "1.2.3.4", "9999999999.2.3", "-1.2.3"]:
		t.check("reject_" + version, V.numbers(version).is_empty())
	t.check("no_downgrade", not V.newer("1.0.0", "2.0.0") and not V.newer("1.0.0", "1.0.0"))
	t.check("valid_matching_asset", not V.select_asset(_release(), "1.2.2", "magudb/PongPong", "windows").is_empty())
	for property in ["draft", "prerelease"]:
		var release := _release()
		release[property] = true
		t.check("ignore_" + property, V.select_asset(release, "1.0.0", "magudb/PongPong", "windows").is_empty())
	t.check("ignore_other_platform", V.select_asset(_release(), "1.0.0", "magudb/PongPong", "macos").is_empty())
	for property in ["browser_download_url", "digest", "size"]:
		var release := _release()
		release.assets[0][property] = "https://example.com/update.zip" if property == "browser_download_url" else "" if property == "digest" else 2147483648
		t.check("reject_asset_" + property, V.select_asset(release, "1.0.0", "magudb/PongPong", "windows").is_empty())
	var updates := ReleaseUpdates.inst()
	t.check("development_does_not_auto_check", not ReleaseUpdates.production())
	updates._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	t.check("offline_is_nonfatal", updates.state == "unavailable")
	updates._completed(HTTPRequest.RESULT_SUCCESS, 404, PackedStringArray(), PackedByteArray())
	t.check("no_first_release_is_normal", updates.state == "current")
	updates._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "not json".to_utf8_buffer())
	t.check("malformed_response_is_nonfatal", updates.state == "unavailable")
	var download := ProjectSettings.globalize_path("user://updater-test.zip")
	var file := FileAccess.open(download, FileAccess.WRITE)
	file.store_string("tampered")
	file.close()
	updates.available = {"sha256": "a".repeat(64)}
	updates.downloaded_path = download
	updates._downloading = true
	updates._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	t.check("tampered_download_removed", updates.state == "download_failed" and not FileAccess.file_exists(download))
	_install_results(t, updates)
	_retry_reuses_download(t, updates)
	_prune_downloads(t, updates)
	await _helpers_end_to_end(t, updates)
	updates.available.clear()
	updates._set_state("current")
	updates.checked = true
	await t.go_menu()
	# The previous session's install outcome is shown on the title until the player has seen the panel.
	var row: Button = t.tree.current_scene.find_child("UpdatesButton", true, false)
	updates.report = {"status": "failed", "reason": "locked"}
	updates.changed.emit()
	t.check("title_reports_failed_install", row.visible and row.text == TranslationServer.translate("UPDATE_REPORT_FAILED"), row.text)
	updates.report = {"status": "installed", "reason": ""}
	updates.changed.emit()
	var installed_text := TranslationServer.translate("UPDATE_REPORT_INSTALLED") % ReleaseUpdates.current_version()
	t.check("title_reports_installed_version", row.visible and row.text == installed_text, row.text)
	var settings: TTScreen = t.tree.current_scene.get_node("SettingsUI")
	settings.open()
	await t.frames(2)
	settings.updates_button.pressed.emit()
	await t.frames(2)
	var panel: TTScreen = settings.get_node("Updates")
	t.check("settings_opens_update_panel", panel.is_open() and t.autoload("GameManager").modal_stack() == [&"settings", &"updates"])
	t.check("panel_shows_install_report", panel.status_label.text.begins_with(installed_text), panel.status_label.text)
	var rules := UiAudit.rule_report(panel)
	t.check("update_panel_rules", rules.ok, str(rules.defects))
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("escape_returns_to_settings", not panel.is_open() and settings.is_open() and settings.get_viewport().gui_get_focus_owner() == settings.updates_button)
	t.check("closing_panel_acknowledges_report", updates.report.is_empty() and not row.visible)
	updates._fail("locked")
	t.check("install_failure_names_its_reason", panel.status_label.text == TranslationServer.translate("UPDATE_FAIL_LOCKED"), panel.status_label.text)
	updates._fail("not-a-reason")
	t.check("unknown_failure_is_generic", panel.status_label.text == TranslationServer.translate("UPDATE_STATE_INSTALL_FAILED"), panel.status_label.text)
	updates._set_state("current")
	settings.close()
	await UiAudit.audit_screen(t, "updates")

## Helper result files: read with or without a byte order mark, unknown reasons stay generic, and the startup
## report takes the newest result and removes every result and handshake file.
func _install_results(t, updates: ReleaseUpdates) -> void:
	var folder := ProjectSettings.globalize_path(ReleaseUpdates.CACHE)
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("install-1.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]) + '{"status":"rolled_back","reason":"launch"}'.to_utf8_buffer())
	file.close()
	t.check("result_with_bom_is_read", ReleaseUpdates.read_result(path) == {"status": "rolled_back", "reason": "launch"})
	for case in [["unknown_reason_is_dropped", '{"status":"failed","reason":"elsewhere"}', {"status": "failed", "reason": ""}], ["unknown_status_is_ignored", '{"status":"maybe"}', {}], ["malformed_result_is_ignored", "not json", {}]]:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(case[1])
		file.close()
		t.check(case[0], ReleaseUpdates.read_result(path) == case[2], ReleaseUpdates.read_result(path))
	for pair in [['{"status":"rolled_back","reason":"launch"}', {"status": "failed", "reason": "launch"}], ['{"status":"installed","reason":""}', {"status": "installed", "reason": ""}]]:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(pair[0])
		file.close()
		file = FileAccess.open(path + ".ready", FileAccess.WRITE)
		file.store_string("ready")
		file.close()
		var report := updates.take_report()
		t.check("startup_report_" + str(pair[1].status), report == pair[1] and not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".ready"), report)
	t.check("no_result_no_report", updates.take_report().is_empty())

## A verified archive left by a failed install is installed again without a second download.
func _retry_reuses_download(t, updates: ReleaseUpdates) -> void:
	var folder := ProjectSettings.globalize_path(ReleaseUpdates.CACHE.path_join("9.9.9"))
	DirAccess.make_dir_recursive_absolute(folder)
	var payload := folder.path_join("Traetoppen-v9.9.9-windows.zip")
	var file := FileAccess.open(payload, FileAccess.WRITE)
	file.store_string("verified payload")
	file.close()
	updates.available = {"version": "9.9.9", "name": payload.get_file(), "url": "https://127.0.0.1:9/never", "sha256": FileAccess.get_sha256(payload), "size": 16}
	updates._fail("locked")
	updates.download()
	t.check("retry_reuses_verified_download", updates.state == "ready" and updates.downloaded_path == payload, updates.state)
	DirAccess.remove_absolute(payload)
	DirAccess.remove_absolute(folder)

## Old update archives do not pile up next to the saves: an installed or unknown version goes at startup, a newer one
## stays for a retry until another download starts, and an archive the helper rejected is removed at once.
func _prune_downloads(t, updates: ReleaseUpdates) -> void:
	var folder := ProjectSettings.globalize_path(ReleaseUpdates.CACHE)
	for version in [ReleaseUpdates.current_version(), "junk", "9.9.9"]:
		DirAccess.make_dir_recursive_absolute(folder.path_join(version))
		var file := FileAccess.open(folder.path_join(version).path_join("Traetoppen-v%s-windows.zip" % version), FileAccess.WRITE)
		file.store_string("archive")
		file.close()
	updates.prune_downloads()
	t.check("startup_prunes_installed_downloads", Array(DirAccess.get_directories_at(folder)) == ["9.9.9"], DirAccess.get_directories_at(folder))
	updates.downloaded_path = folder.path_join("9.9.9").path_join("Traetoppen-v9.9.9-windows.zip")
	updates._fail("locked")
	t.check("failed_install_keeps_download_for_retry", FileAccess.file_exists(updates.downloaded_path))
	updates._fail("checksum")
	t.check("rejected_archive_is_removed", not FileAccess.file_exists(updates.downloaded_path))
	updates.prune_downloads("9.9.10")
	t.check("new_download_replaces_older_ones", DirAccess.get_directories_at(folder).is_empty(), DirAccess.get_directories_at(folder))
	updates.downloaded_path = ""
	updates._set_state("current")

## The real helpers, started with the command line install() builds and answered by its handshake, update a throwaway
## installation: argument order, the "ready" file and the result file are one contract between game and helper.
## The Windows helper runs wherever PowerShell does (pwsh on Linux and macOS); the macOS one needs codesign and ditto.
func _helpers_end_to_end(t, updates: ReleaseUpdates) -> void:
	var root := ProjectSettings.globalize_path("user://updater-e2e")
	for platform in ["windows", "macos"]:
		var program := _helper_program(platform)
		if program.is_empty():
			t.skip("helper_e2e_" + platform)
			continue
		_remove_tree(root)
		DirAccess.make_dir_recursive_absolute(root.path_join("games"))
		updates.failure = ""
		var target := _fake_update(platform, root, updates)
		var result := root.path_join("install-e2e.json")
		var command := updates.helper_command(platform, ReleaseUpdates.write_helper(platform), target, result, 0, false)
		var process := OS.create_process(program, command[1])
		t.check("helper_e2e_%s_handshake" % platform, await updates.handshake(process, result), updates.failure)
		await t.until(func(): return not OS.is_process_running(process), 60.0)
		var installed := FileAccess.get_file_as_string(target.path_join("Traetoppen.pck" if platform == "windows" else "Contents/Resources/version.txt"))
		t.check("helper_e2e_%s_installed" % platform, ReleaseUpdates.read_result(result) == {"status": "installed", "reason": ""} and installed == "new", installed)
	_remove_tree(root)
	updates.available.clear()
	updates.downloaded_path = ""
	updates._set_state("current")

func _helper_program(platform: String) -> String:
	var out := []
	if platform == "windows":
		if OS.get_name() == "Windows": return OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		OS.execute("/bin/sh", ["-c", "command -v pwsh"], out)
		return str(out[0]).strip_edges() if not out.is_empty() else ""
	return "/bin/bash" if OS.get_name() == "macOS" else ""

## An installed "old" game and a verified update archive of a "new" one, set up as a finished download.
func _fake_update(platform: String, root: String, updates: ReleaseUpdates) -> String:
	var archive := root.path_join("update.zip")
	var target := root.path_join("games/Traetoppen" if platform == "windows" else "games/Traetoppen.app")
	if platform == "windows":
		DirAccess.make_dir_recursive_absolute(target)
		for name in ["Traetoppen.exe", "Traetoppen.pck"]: _write(target.path_join(name), "old")
		var zip := ZIPPacker.new()
		zip.open(archive)
		for name in ["Traetoppen/Traetoppen.exe", "Traetoppen/Traetoppen.pck"]:
			zip.start_file(name)
			zip.write_file("new".to_utf8_buffer())
			zip.close_file()
		zip.close()
	else:
		var incoming := root.path_join("incoming/Traetoppen.app")
		for pair in [[target, "old"], [incoming, "new"]]:
			var bundle: String = pair[0]
			DirAccess.make_dir_recursive_absolute(bundle.path_join("Contents/MacOS"))
			DirAccess.make_dir_recursive_absolute(bundle.path_join("Contents/Resources"))
			DirAccess.copy_absolute("/usr/bin/true", bundle.path_join("Contents/MacOS/Trætoppen"))
			OS.execute("/bin/chmod", ["755", bundle.path_join("Contents/MacOS/Trætoppen")])
			_write(bundle.path_join("Contents/Resources/version.txt"), pair[1])
			_write(bundle.path_join("Contents/Info.plist"), '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>io.github.magudb.traetoppen</string><key>CFBundleExecutable</key><string>Trætoppen</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>\n')
			OS.execute("/usr/bin/codesign", ["--force", "--sign", "-", bundle])
		OS.execute("/usr/bin/ditto", ["-c", "-k", "--keepParent", incoming, archive])
	updates.downloaded_path = archive
	updates.available = {"version": "9.9.9", "name": archive.get_file(), "sha256": FileAccess.get_sha256(archive), "size": FileAccess.get_file_as_bytes(archive).size()}
	return target

func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for folder in DirAccess.get_directories_at(path): _remove_tree(path.path_join(folder))
	for file in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run_windowed(t) -> void:
	await run(t)
