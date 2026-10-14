extends RefCounted
## Registry driver: a conforming menu screen that nevertheless opens a pause modal on Esc / Start (it must fail an esc_depth 0 row).

const Screen = preload("res://tests/fixtures/ui_audit/screen.gd")
const EscOpens = preload("res://tests/fixtures/ui_audit/esc_opens_pause.gd")


func open(_t, host: Control, _ctx: Dictionary) -> Node:
	var s := Screen.new()
	host.add_child(s)
	var n := Node.new()
	n.set_script(EscOpens)
	s.add_child(n)
	return s
