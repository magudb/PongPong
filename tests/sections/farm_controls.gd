extends RefCounted
const SECTION := "farm_controls"
const TIMEOUT_S := 90.0
func run(t) -> void: await _run(t)
func run_windowed(t) -> void: await _run(t)
func _run(t) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var p: Player2D = t.player()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	var hands := preload("res://tests/lib/town_loop/farm_day.gd").new()
	var cell := Vector2i(21,27)
	t.check("walk_to_middle_of_field", await hands.face_plot(t,cell))
	p.hotbar.assign(0,&"hoe_wooden")
	p.hotbar.select(0)
	var uses: Array = []
	var record := func(_item,at,ok):
		if ok: uses.append(at)
	p.tool_used.connect(record)
	_hold_tool(t)
	await t.physics(40)
	t.check("holding_on_same_plot_uses_tool_once", uses == [cell] and w.farm.state_of(cell) == FarmGrid.State.TILLED)
	var destination: Vector2 = w.area.cell_to_global(Vector2i(24,28))
	for tick in 150:
		if Iso.ground_dist(p.global_position,destination) < 8: break
		LoopWalker._steer(t,destination-p.global_position)
		await t.physics(1)
	t.release_all()
	await t.physics(30)
	var unique := {}
	for at in uses: unique[at] = true
	t.check("held_hoe_tills_each_new_plot_once", uses.size() >= 3 and unique.size() == uses.size(), str(uses))
	t.check("release_stops_repeat", not p._farm_use_held)
	uses.clear()
	var next: Vector2i = p.target_cell()
	if not w.farm.can_till(next):
		await hands.face_plot(t,Vector2i(23,27))
	_hold_tool(t)
	await t.physics(25)
	gm.push_modal(&"farm_control_probe",true)
	await t.frames(3)
	t.release_all()
	gm.pop_modal(&"farm_control_probe")
	await t.physics(2)
	t.check("modal_clears_held_farm_action", not p._farm_use_held)
	p.tool_used.disconnect(record)

func _hold_tool(t) -> void:
	t.hold(&"use_tool")
	var event := InputEventAction.new()
	event.action = &"use_tool"
	event.pressed = true
	Input.parse_input_event(event)
