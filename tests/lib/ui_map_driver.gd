extends RefCounted

func open(t, _host: Node, _ctx: Dictionary) -> Node:
	var phase := GameManager.current_phase
	EventBus.new_game_started.connect(func(): GameManager.set_flag(GameManager.FLAG_INTRO_PENDING, false), CONNECT_ONE_SHOT)
	await t.start_world()
	GameManager.hour = 12
	GameManager.change_phase(phase)
	var screen: Node = t.world().game_ui.get_screen(&"map_ui")
	screen.open()
	await t.frames(3)
	return screen

func close(t, _node: Node, _host: Node) -> void:
	await t.clear_scene()
