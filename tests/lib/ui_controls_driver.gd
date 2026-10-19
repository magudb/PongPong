extends RefCounted
func open(_t, host: Node, _ctx: Dictionary) -> Node:
	var screen: Node = load("res://scenes/ui/controls_panel.tscn").instantiate()
	host.add_child(screen)
	screen.open()
	return screen
