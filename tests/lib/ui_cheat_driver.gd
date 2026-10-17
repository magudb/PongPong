extends RefCounted
func open(t, _host: Node, _ctx: Dictionary) -> Node:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	var screen: Node = t.world().game_ui.get_screen(&"cheat_menu")
	screen.open()
	await t.frames(3)
	return screen
func close(t, _node: Node, _host: Node) -> void:
	await t.clear_scene()
	GameManager.clear_config_overrides()
