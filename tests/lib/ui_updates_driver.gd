extends RefCounted
func open(_t, host: Node, _ctx: Dictionary) -> Node:
	var service := ReleaseUpdates.inst()
	service.checked = true
	service._set_state("current")
	var screen: Node = load("res://scenes/ui/update_panel.tscn").instantiate()
	host.add_child(screen)
	screen.open()
	return screen
