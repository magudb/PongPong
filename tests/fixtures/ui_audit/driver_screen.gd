extends RefCounted
## Registry driver (tests/lib/ui_screens.json "open": {"driver": ...}) for the fixture screens: ctx = {layout, defect, hidden}.

const Screen = preload("res://tests/fixtures/ui_audit/screen.gd")


func open(_t, host: Control, ctx: Dictionary) -> Node:
	var s := Screen.new()
	s.layout = str(ctx.get("layout", "menu"))
	s.defect = str(ctx.get("defect", ""))
	host.add_child(s)
	if bool(ctx.get("hidden", false)):
		s.visible = false                                       # a modal root that hides itself in _ready and was never opened
	return s
