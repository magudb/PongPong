extends RefCounted
## Registry driver for the nested-modal fixture: open() builds the base screen, open_level(t, host, level) opens modal `level`.
## ctx.defect plants one of the broken behaviours of modals.gd.

const Modals = preload("res://tests/fixtures/ui_audit/modals.gd")


func open(_t, host: Control, ctx: Dictionary) -> Node:
	var m := Modals.new()
	m.name = "Modals"
	m.defect = str(ctx.get("defect", ""))
	host.add_child(m)
	return m


func open_level(_t, host: Control, level: int) -> void:
	(host.get_node("Modals") as Control).open_level(level)
