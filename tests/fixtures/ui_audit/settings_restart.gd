extends SceneTree
## A second Godot process must observe the shared file written by the menu.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	await process_frame
	var settings: GDScript = load("res://scripts/ui/settings_ui.gd")
	settings.call("apply_saved")
	var config := ConfigFile.new()
	var loaded := config.load("user://settings.cfg") == OK
	var master := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	var ok: bool = loaded and is_equal_approx(db_to_linear(master), 0.75) and config.get_value("video", "size", -1) == 1 and config.get_value("game", "locale", "") == "da" and config.get_value("other_owner", "kept", "") == "unchanged"
	print("PASS menus.settings_persist_across_restart" if ok else "FAIL menus.settings_persist_across_restart")
	quit(0 if ok else 1)
