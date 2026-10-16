extends RefCounted
## Farm actions are input-driven; this helper never assigns position or calls till/plant/water.
var suite

func check(t, leg: String, id: String, ok: bool, detail := "") -> void:
	suite._check(t, leg, id, ok, detail)

func face_plot(t, cell: Vector2i) -> bool:
	var area: IsoArea = t.world().area
	var approach := area.cell_to_global(cell + Vector2i(0, 1))
	var route := await LoopWalker.walk_to(t, approach, 5, 20)
	# A short real movement sets facing NE, without leaving the approach cell.
	LoopWalker._steer(t, area.cell_to_global(cell) - t.player().global_position)
	await t.physics(2)
	t.release_all()
	await t.physics(5)
	if not route.ok or t.player().target_cell() != cell:
		t.info("Farm approach " + str(route) + " target=" + str(t.player().target_cell()) + " wanted=" + str(cell) + " facing=" + str(t.player().facing8))
	return route.ok and t.player().target_cell() == cell

func tool(t, slot: int, expected: float) -> bool:
	t.tap(StringName("slot_%d" % slot))
	await t.frames(2)
	var before: float = t.player().stamina
	var used: Array = []
	var report := func(item, cell, ok): used.append({"item": item, "cell": cell, "ok": ok})
	t.player().tool_used.connect(report)
	t.tap(&"use_tool")
	await t.physics(2)
	var paid: float = before - t.player().stamina
	t.player().tool_used.disconnect(report)
	await t.until(func(): return t.player().state == PlayerBody2D.S.FREE, 2)
	return used.size() == 1 and bool(used[0].ok) and absf(paid - expected * float(SpeciesPerks.current("tool_cost_mult", 1.0))) < 0.01

func run(t, owner) -> void:
	suite = owner
	var world: WorldRoot2D = t.world()
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var qm: Node = t.autoload("QuestManager")
	t.autoload("TimeManager").set_weather(&"klart")
	var cells: Array = world.farm.farmable_cells()
	cells.sort_custom(func(a, b): return world.area.cell_to_global(a).distance_squared_to(t.player().global_position) < world.area.cell_to_global(b).distance_squared_to(t.player().global_position))
	var selected: Array[Vector2i] = []
	for cell in cells:
		if world.farm.state_of(cell) == FarmGrid.State.EMPTY and world.farm.can_till(cell) and world.farm.can_till(cell + Vector2i(0, 1)):
			selected.append(cell)
		if selected.size() == 3:
			break
	var planting_seed := &"carrot_seeds"
	t.player().hotbar.assign(6, planting_seed)
	var success := true
	var costs := true
	var watered_events: Array = []
	var planted_events: Array = []
	var bus: Node = t.autoload("EventBus")
	var on_water := func(id): watered_events.append(id)
	var on_plant := func(id, crop): planted_events.append([id, crop])
	bus.crop_watered.connect(on_water)
	bus.crop_planted.connect(on_plant)
	for cell in selected:
		var approached := await face_plot(t, cell)
		check(t, "L10", "l10_walk_to_plot_%d_%d" % [cell.x, cell.y], approached)
		if not approached:
			success = false
			costs = false
			continue
		costs = await tool(t, 1, 3.0) and costs
		success = world.farm.state_of(cell) == FarmGrid.State.TILLED and success
		costs = await tool(t, 7, 0.5) and costs
		success = world.farm.state_of(cell) == FarmGrid.State.PLANTED and success
		costs = await tool(t, 2, 1.5) and costs
		success = world.farm.state_of(cell) == FarmGrid.State.WATERED and success
	bus.crop_watered.disconnect(on_water)
	bus.crop_planted.disconnect(on_plant)
	check(t, "L10", "l10_till_plant_water", success and selected.size() == 3 and planted_events.size() == 3 and watered_events.size() == 3, "plant=" + str(planted_events) + " water=" + str(watered_events))
	check(t, "L10", "l10_energy_costs", costs)
	var objectives := true
	for id in [&"till", &"plant", &"water"]:
		var progress: Dictionary = qm.get_objective_progress(&"forste_dage", id)
		objectives = objectives and int(progress.get("current", -1)) == 3
	check(t, "L10", "l10_forste_dage_objectives", objectives, str(qm.get_objective_progress(&"forste_dage", &"plant")))
	var hints: Node = world.get_node("FarmTutorialHints")
	for repeat in hints.hints.size():
		hints.tick(hints.last_shown + 13)
	var prior: int = suite.probe.named("tutorial_hint_shown").filter(func(e): return e.payload.id == "can").size()
	hints.request("can")
	hints.tick(hints.last_shown + 13)
	var after: int = suite.probe.named("tutorial_hint_shown").filter(func(e): return e.payload.id == "can").size()
	check(t, "L10", "l10_hint_once_per_save", bool(gm.get_flag(&"tut_hint_can", false)) and prior == 1 and after == prior)
	await LoopClock.to(t, 17, 59)
	check(t, "L11", "l11_bed_closed_before_18", not world.can_sleep_now())
	await LoopClock.to(t, 18)
	check(t, "L11", "l11_bed_opens_at_18", world.can_sleep_now())
	var day: int = gm.total_day()
	var slept := await LoopClock.bed_sleep(t)
	check(t, "L11", "l11_sleep_rolls_day", slept and gm.total_day() == day + 1 and gm.hour == 6 and t.player().stamina == t.player().max_stamina)
	var grew := true
	for cell in selected:
		var plot: FarmGrid.PlotData = world.farm.get_plot(cell)
		grew = grew and plot != null and plot.growth_days > 0
	check(t, "L11", "l11_crops_grow", grew)
	await LoopClock.to(t, 24, 10)
	check(t, "L11", "l11_no_pass_out_at_midnight", gm.total_day() == day + 1 and gm.hour == 24 and gm.minute == 10 and not world.sleeping)
	# The production curfew reads the config's raw 26-hour day.
	gm.set_config_override("towns.curfew.enabled", true)
	await world.travel(&"traetoppen", &"from_farm")
	var go_home := float(gm.config_value("towns.curfew.go_home", 25.75))
	await LoopClock.to(t, int(go_home), roundi(fmod(go_home, 1) * 60))
	await t.until(func(): return world.area.map.id == &"farm" and not world.traveling, 8)
	check(t, "L11", "l11_curfew_at_the_configured_time", world.area.map.id == &"farm" and gm.hour == int(go_home))
	gm.set_config_override("towns.curfew.enabled", false)
	await world.travel(&"hyggebyen", &"default")
	await LoopClock.to(t, 25, 50)
	gm.advance_time(20)
	await LoopClock.settle(t)
	check(t, "L11", "l11_pass_out_wakes_on_farm", world.area.map.id == &"farm" and gm.hour == 6 and gm.minute == 0 and gm.total_day() == day + 2 and Iso.to_ground(t.player().global_position - world.area.get_spawn("from_home")).length() < 6)
