extends RefCounted
const SECTION := "release_updates"
## Above the section's own bounds, so a slow helper fails its handshake check with the helper's reason instead of the watchdog:
## per helper (Windows via pwsh, macOS) ReleaseUpdates.handshake() polls up to 120 game seconds and the exit wait is 60 s, and
## the PowerShell warm start before the Windows one waits up to 180 s (540 s in all). The default 120 s ran out in the local gate
## (four shards at once) while the pwsh handshake was still polling; there the whole section took 93 s where it takes 2 s alone.
const TIMEOUT_S := 600.0
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
	# without the boot stage (--no-boot) nothing created the service yet: inst() adds it to the root deferred, and the
	# handshake below needs its tree
	if not updates.is_inside_tree():
		await t.frames(1)
	_catalogue_selection(t, updates)
	t.check("development_does_not_auto_check", not ReleaseUpdates.production())
	updates._completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	t.check("offline_is_nonfatal", updates.state == "unavailable")
	updates._completed(HTTPRequest.RESULT_SUCCESS, 404, PackedStringArray(), PackedByteArray())
	t.check("missing_repository_is_unavailable", updates.state == "unavailable")
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
	# A fresh session, as after the helper relaunched the game: the title builds before the service reads the result.
	var result := ProjectSettings.globalize_path(ReleaseUpdates.CACHE).path_join("install-2.json")
	_write(result, '{"status":"failed","reason":"locked"}')
	t.tree.root.remove_child(updates)
	t.tree.root.remove_meta("tt_release_updates")
	updates.queue_free()
	await t.go_menu()
	updates = ReleaseUpdates.inst()
	# The previous session's install outcome is shown on the title until the player has seen the panel.
	var row: Button = t.tree.current_scene.find_child("UpdatesButton", true, false)
	t.check("title_reports_previous_session", row.visible and row.text == TranslationServer.translate("UPDATE_REPORT_FAILED") and not FileAccess.file_exists(result), row.text)
	updates._set_state("current")
	updates.checked = true
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
	# REL-10: the panel names where the check goes, and the automatic check at the title can be switched off (and on again).
	var source: Label = panel.source_label
	var auto_check: CheckBox = panel.auto_check
	t.check("update_panel_names_github", source.text.contains("github.com/" + ReleaseUpdates.repository()), source.text)
	t.check("auto_check_defaults_on", ReleaseUpdates.auto_check_enabled() and auto_check.button_pressed)
	auto_check.grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	t.check("auto_check_switch_saves_off", not auto_check.button_pressed and not ReleaseUpdates.auto_check_enabled() and SettingsStore.value("updates", "auto_check", true) == false)
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	t.check("auto_check_switch_saves_on", auto_check.button_pressed and ReleaseUpdates.auto_check_enabled())
	panel.primary.grab_focus()
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("escape_returns_to_settings", not panel.is_open() and settings.is_open() and settings.get_viewport().gui_get_focus_owner() == settings.updates_button)
	t.check("closing_panel_acknowledges_report", updates.report.is_empty() and not row.visible)
	updates._fail("locked")
	t.check("install_failure_names_its_reason", panel.status_label.text == TranslationServer.translate("UPDATE_FAIL_LOCKED"), panel.status_label.text)
	updates._fail("not-a-reason")
	t.check("unknown_failure_is_generic", panel.status_label.text == TranslationServer.translate("UPDATE_STATE_INSTALL_FAILED"), panel.status_label.text)
	# REL-09: a download runs in the background. Closing the panel keeps it, the panel shows MB and per cent, "Stop" cancels it,
	# and only a download that stalls (no byte for STALL_SECONDS) fails; there is no total time limit.
	updates.available = {"version": "9.9.9", "size": 418 * 1048576, "sha256": "a".repeat(64)}
	updates.downloaded_path = ProjectSettings.globalize_path("user://updater-test-partial.zip")
	updates._downloading = true
	updates._set_state("downloading")
	settings.updates_button.pressed.emit()
	await t.frames(2)
	t.check("download_shows_megabytes", panel.is_open() and panel.status_label.text.contains("418") and panel.progress_bar.visible and panel.progress_bar.show_percentage, panel.status_label.text)
	t.check("download_offers_stop", panel.primary.text == TranslationServer.translate("UPDATE_STOP") and not panel.primary.disabled)
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("closing_keeps_download", not panel.is_open() and updates.state == "downloading")
	settings.updates_button.pressed.emit()
	await t.frames(2)
	# Reopened mid-download the panel lands on "Luk", not on "Stop": one more Enter must not throw the progress away.
	var reopened_focus := panel.get_viewport().gui_get_focus_owner()
	t.check("reopened_download_focuses_close", reopened_focus == panel.back, str(reopened_focus))
	panel.primary.grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	t.check("stop_cancels_download", updates.state == "available" and not updates._downloading)
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	updates._downloading = true
	updates._set_state("downloading")
	updates._last_bytes = updates.downloaded_bytes()
	updates._stalled = 0.0
	updates._watch(ReleaseUpdates.STALL_SECONDS * 0.5)
	var alive: bool = updates.state == "downloading"
	updates._watch(ReleaseUpdates.STALL_SECONDS * 0.5 + 0.1)
	t.check("stalled_download_fails", alive and updates.state == "download_failed" and not updates._downloading)
	# A download that failed in the background keeps the title's "Ny version" row, the way back to the retry.
	var title_row: Button = t.tree.current_scene._updates_button
	t.check("failed_download_keeps_title_row", title_row.visible and title_row in t.tree.current_scene._rows)
	# Quitting during a download leaves no partial archive behind (it never resumes).
	var leaving := ReleaseUpdates.new()
	t.tree.root.add_child(leaving)
	var leftover := ProjectSettings.globalize_path("user://updater-test-leftover.zip")
	var partial := FileAccess.open(leftover, FileAccess.WRITE)
	partial.store_string("half an archive")
	partial.close()
	leaving.downloaded_path = leftover
	leaving._downloading = true
	leaving.state = "downloading"
	t.tree.root.remove_child(leaving)
	t.check("quit_removes_partial_download", not FileAccess.file_exists(leftover) and not leaving._downloading)
	leaving.free()
	updates.available.clear()
	updates._set_state("current")
	settings.close()
	await UiAudit.audit_screen(t, "updates")

## Public releases can be created before their artifacts exist. Pick the newest
## usable release, not merely the first/latest release or its unverified asset.
func _catalogue_selection(t, updates: ReleaseUpdates) -> void:
	var platform := ReleaseUpdates.platform_name()
	if platform.is_empty():
		# CI's Linux editor tests the same selector with an explicit Windows target.
		platform = "windows"
	var compatible := _release()
	compatible.assets[0].name = "Traetoppen-v1.2.3-%s.zip" % platform
	compatible.assets[0].browser_download_url = "https://github.com/magudb/PongPong/releases/download/v1.2.3/" + compatible.assets[0].name
	var pending := {"tag_name": "v1.2.9", "draft": false, "prerelease": false, "assets": []}
	var selection := V.select_catalogue([pending, compatible], "1.0.0", "magudb/PongPong", platform)
	t.check("assetless_latest_does_not_hide_usable_update", selection.state == "available" and selection.asset.get("version", "") == "1.2.3", selection)
	selection = V.select_catalogue([pending], "1.0.0", "magudb/PongPong", platform)
	t.check("incomplete_new_release_is_not_current", selection.state == "unavailable", selection)
	selection = V.select_catalogue([], "1.0.0", "magudb/PongPong", platform)
	t.check("empty_release_catalogue_is_current", selection.state == "current", selection)
	var draft := compatible.duplicate(true)
	draft.draft = true
	selection = V.select_catalogue([draft], "1.0.0", "magudb/PongPong", platform)
	t.check("draft_catalogue_is_not_an_update", selection.state == "current" and selection.asset.is_empty(), selection)
	var unsafe := compatible.duplicate(true)
	unsafe.assets[0].browser_download_url = "https://example.com/update.zip"
	selection = V.select_catalogue([unsafe], "1.0.0", "magudb/PongPong", platform)
	t.check("untrusted_catalogue_asset_is_unavailable", selection.state == "unavailable" and selection.asset.is_empty(), selection)
	updates._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify([pending, compatible]).to_utf8_buffer())
	var expected := "unavailable" if ReleaseUpdates.platform_name().is_empty() else "available"
	t.check("catalogue_response_reaches_selector", updates.state == expected and (expected != "available" or updates.available.get("version", "") == "1.2.3"), updates.state)
	var newest := compatible.duplicate(true)
	newest.tag_name = "v1.10.0"
	newest.assets[0].name = "Traetoppen-v1.10.0-%s.zip" % platform
	newest.assets[0].browser_download_url = "https://github.com/magudb/PongPong/releases/download/v1.10.0/" + newest.assets[0].name
	selection = V.select_catalogue([compatible, newest, pending], "1.0.0", "magudb/PongPong", platform)
	t.check("catalogue_uses_semver_not_list_order", selection.state == "available" and selection.asset.get("version", "") == "1.10.0", selection)
	selection = V.select_catalogue([compatible], "2.0.0", "magudb/PongPong", platform)
	t.check("catalogue_never_downgrades", selection.state == "current" and selection.asset.is_empty(), selection)
	selection = V.select_catalogue(["not a release"], "1.0.0", "magudb/PongPong", platform)
	t.check("malformed_catalogue_is_not_current", selection.state == "unavailable", selection)
	var oversized: Array = []
	oversized.resize(101)
	selection = V.select_catalogue(oversized, "1.0.0", "magudb/PongPong", platform)
	t.check("catalogue_response_is_bounded", selection.state == "unavailable" and selection.asset.is_empty(), selection)
	_catalogue_pagination(t, updates, compatible)
	_catalogue_metadata(t, updates)

## A string outside the canonical release scheme is intentional and ignored;
## absent/non-string required tags are broken metadata, not proof of currency.
func _catalogue_metadata(t, updates: ReleaseUpdates) -> void:
	for platform in ["windows", "macos", ""]:
		var compatible := _release()
		compatible.assets[0].name = "Traetoppen-v1.2.3-%s.zip" % platform
		compatible.assets[0].browser_download_url = "https://github.com/magudb/PongPong/releases/download/v1.2.3/" + compatible.assets[0].name
		for case in [["missing", null], ["null", null], ["integer", 123], ["float", 1.2], ["bool", false], ["array", []], ["object", {}]]:
			var malformed := {"draft": false, "prerelease": false, "assets": []}
			if case[0] != "missing": malformed.tag_name = case[1]
			var selection := V.select_catalogue([malformed], "1.0.0", "magudb/PongPong", platform)
			t.check("invalid_required_tag_%s_%s" % [case[0], platform], selection.state == "unavailable" and selection.asset.is_empty(), selection)
			selection = V.select_catalogue([malformed, compatible], "1.0.0", "magudb/PongPong", platform)
			var expected := "unavailable" if platform.is_empty() else "available"
			t.check("invalid_tag_keeps_verified_fallback_%s_%s" % [case[0], platform], selection.state == expected and (expected != "available" or selection.asset.get("version", "") == "1.2.3"), selection)
			if platform == "macos":
				updates._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify([malformed]).to_utf8_buffer())
				t.check("invalid_tag_response_" + case[0], updates.state == "unavailable" and updates.available.is_empty(), updates.state)
		for tag in ["", "nightly", "1.2.3", "v01.2.3", "v1.2.3-beta", "v1.2", "v9999999999.2.3"]:
			var selection := V.select_catalogue([{"tag_name": tag, "draft": false, "prerelease": false, "assets": []}], "1.0.0", "magudb/PongPong", platform)
			var expected := "unavailable" if platform.is_empty() else "current"
			t.check("noncanonical_string_tag_%s_%s" % [tag, platform], selection.state == expected and selection.asset.is_empty(), selection)
		for flag in ["draft", "prerelease"]:
			var malformed := {"draft": false, "prerelease": false, "assets": []}
			malformed[flag] = true
			var selection := V.select_catalogue([malformed], "1.0.0", "magudb/PongPong", platform)
			t.check("required_tag_even_when_%s_%s" % [flag, platform], selection.state == "unavailable" and selection.asset.is_empty(), selection)

## One bounded page cannot establish either currency or the highest semver if
## GitHub advertises another page (even when this page has a verified update).
func _catalogue_pagination(t, updates: ReleaseUpdates, compatible: Dictionary) -> void:
	var full_page: Array = []
	for index in 100:
		full_page.append({"tag_name": "v9.0.%d" % index, "draft": index % 2 == 0, "prerelease": index % 2 != 0, "assets": []})
	for platform in ["windows", "macos", ""]:
		var selection := V.select_catalogue(full_page, "1.0.0", "magudb/PongPong", platform)
		var expected := "unavailable" if platform.is_empty() else "current"
		t.check("full_page_filters_nonstable_" + platform, selection.state == expected and selection.asset.is_empty(), selection)
	var next := PackedStringArray(['Link: <https://api.github.com/repos/magudb/PongPong/releases?per_page=100&page=2>; rel="next", <https://api.github.com/repos/magudb/PongPong/releases?per_page=100&page=3>; rel="last"'])
	updates._completed(HTTPRequest.RESULT_SUCCESS, 200, next, JSON.stringify(full_page).to_utf8_buffer())
	t.check("full_page_with_next_is_not_current", updates.state == "unavailable" and updates.available.is_empty(), updates.state)
	full_page[99] = compatible
	updates._completed(HTTPRequest.RESULT_SUCCESS, 200, next, JSON.stringify(full_page).to_utf8_buffer())
	t.check("next_page_could_have_higher_semver", updates.state == "unavailable" and updates.available.is_empty(), updates.state)
	updates._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(['lInK: <https://api.github.com/repos/magudb/PongPong/releases?page=2>; ReL = "next"']), JSON.stringify([compatible]).to_utf8_buffer())
	t.check("short_page_next_header_is_case_insensitive", updates.state == "unavailable" and updates.available.is_empty(), updates.state)
	full_page[99] = full_page[0].duplicate(true)
	for headers in [PackedStringArray(), PackedStringArray(['Link: <https://api.github.com/repos/magudb/PongPong/releases?page=1>; rel="last"'])]:
		updates._completed(HTTPRequest.RESULT_SUCCESS, 200, headers, JSON.stringify(full_page).to_utf8_buffer())
		var expected := "unavailable" if ReleaseUpdates.platform_name().is_empty() else "current"
		t.check("complete_full_page_is_not_truncated_" + str(headers.size()), updates.state == expected and updates.available.is_empty(), updates.state)

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
		if platform == "windows" and not await _interpreter_warm(t, program, updates.downloaded_path):
			continue
		var process := OS.create_process(program, command[1])
		var started := Time.get_ticks_msec()
		var ready: bool = await updates.handshake(process, result)
		var waited := float(Time.get_ticks_msec() - started) / 1000.0  # raw-time-ok: reported in the detail, never compared
		t.check("helper_e2e_%s_handshake" % platform, ready, "%s (pid %d, handshake %.1f s)" % [updates.failure, process, waited])
		# A failed handshake has reaped the helper already: it saw it exit, or OS.kill waited for it, and the engine's process
		# table does not learn of a kill, so polling that pid again raises "does not exist or is not a child" (ECHILD).
		if ready:
			await t.until(func(): return not OS.is_process_running(process), 60.0)
		var installed := FileAccess.get_file_as_string(target.path_join("Traetoppen.pck" if platform == "windows" else "Contents/Resources/version.txt"))
		t.check("helper_e2e_%s_installed" % platform, ReleaseUpdates.read_result(result) == {"status": "installed", "reason": ""} and installed == "new", installed)
	_remove_tree(root)
	updates.available.clear()
	updates.downloaded_path = ""
	updates._set_state("current")

## PowerShell is .NET: its cold start on a loaded machine (four gate shards next to on-access malware scanning of its several
## hundred assemblies) took 90-120 s where it takes under a second alone, the whole 120 s the game gives the helper to say
## "ready", so the handshake failed and was killed in some gate shards and passed in others. The interpreter is started once
## with the helper's own assembly loads and awaited (a child process: wall clock), so the handshake times the helper and not the
## cold start, and a machine that cannot start PowerShell at all fails a check that says so.
func _interpreter_warm(t, program: String, archive: String) -> bool:
	var started := Time.get_ticks_msec()
	var warm := OS.create_process(program, ["-NoProfile", "-NonInteractive", "-Command", "Add-Type -AssemblyName System.IO.Compression.FileSystem; Get-FileHash -LiteralPath '%s' -Algorithm SHA256 | Out-Null" % archive.replace("'", "''")])
	var done: bool = warm > 0 and await t.until(func(): return not OS.is_process_running(warm), 180.0)
	var waited := float(Time.get_ticks_msec() - started) / 1000.0  # raw-time-ok: reported in the detail, never compared
	var code := OS.get_process_exit_code(warm) if done else -1
	if warm > 0 and not done:
		OS.kill(warm)  # reaps it: the pid is not polled again
	t.check("helper_e2e_windows_interpreter_starts", done and code == 0, "%s (pid %d, exit %d, %.1f s)" % [program, warm, code, waited])
	return done and code == 0

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
