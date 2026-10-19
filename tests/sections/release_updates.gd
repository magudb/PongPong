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
	updates.available.clear()
	updates._set_state("current")
	updates.checked = true
	await t.go_menu()
	var settings: TTScreen = t.tree.current_scene.get_node("SettingsUI")
	settings.open()
	await t.frames(2)
	settings.updates_button.pressed.emit()
	await t.frames(2)
	var panel: TTScreen = settings.get_node("Updates")
	t.check("settings_opens_update_panel", panel.is_open() and t.autoload("GameManager").modal_stack() == [&"settings", &"updates"])
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
	updates.available.clear()
	updates._set_state("current")
	settings.close()
	await UiAudit.audit_screen(t, "updates")

func run_windowed(t) -> void:
	await run(t)
