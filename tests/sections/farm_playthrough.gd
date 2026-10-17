extends RefCounted
const SECTION := "farm_playthrough"
const TIMEOUT_S := 240.0
const Hands := preload("res://tests/lib/town_loop/farm_day.gd")
var native := false
func run(t) -> void: await _run(t)
func run_windowed(t) -> void:
	native = true
	await _run(t)
func _run(t) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var tm: Node = t.autoload("TimeManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("time.weather_chances.foraar", {"klart": 1.0})
	tm.set_weather(&"klart")
	w.day_night.override_hour = 10
	w.day_night.snap()
	var hands := Hands.new()
	var cells: Array = w.farm.farmable_cells()
	cells.sort_custom(func(a,b): return w.area.cell_to_global(a).distance_squared_to(w.player.global_position) < w.area.cell_to_global(b).distance_squared_to(w.player.global_position))
	var selected: Array[Vector2i] = []
	for cell in cells:
		if w.farm.can_till(cell+Vector2i(0,1)):
			selected.append(cell)
		if selected.size() == 2: break
	w.player.hotbar.assign(0,&"hoe_wooden")
	w.player.hotbar.assign(1,&"watering_can_copper")
	w.player.hotbar.assign(6,&"turnip_seeds")
	for cell in selected:
		t.check("walk_to_plot_"+str(cell), await hands.face_plot(t,cell))
		t.check("hoe_input_"+str(cell), await hands.tool(t,1,3.0) and w.farm.state_of(cell) == FarmGrid.State.TILLED)
		t.check("seed_input_"+str(cell), await hands.tool(t,7,0.5) and w.farm.get_plot(cell).crop_id == &"turnip")
		t.check("water_input_"+str(cell), await hands.tool(t,2,1.5) and w.farm.get_plot(cell).watered)
	if native:
		w.player._set_zoom(0.5)
		w.player.camera.reset_smoothing()
		await t.frames(8)
		await t.capture("planted_and_watered")
	for day in 4:
		if day > 0:
			for cell in selected:
				await hands.face_plot(t,cell)
				t.check("daily_water_%d_%s" % [day,cell], await hands.tool(t,2,1.5))
		await LoopClock.to(t,18)
		t.check("sleep_grows_crops_day_%d" % day, await LoopClock.bed_sleep(t))
	t.check("both_plots_ripe_after_real_sleep", selected.all(func(c):return w.farm.state_of(c) == FarmGrid.State.READY))
	for cell in selected:
		await hands.face_plot(t,cell)
		await t.frames(20)
		t.check("ripe_plot_has_harvest_prompt_"+str(cell), tr("FARMSITE_HARVEST_FMT") % tr("ITEM_TURNIP") == w.player._prompt)
		if native: await t.capture("ripe_crop")
		var count: int = eco.count_item(&"turnip")
		t.tap(&"interact")
		await t.frames(3)
		t.check("interact_harvests_to_backpack_"+str(cell), eco.count_item(&"turnip") > count and w.farm.state_of(cell) == FarmGrid.State.TILLED)
		t.check("replant_input_without_retilling_"+str(cell), await hands.tool(t,7,0.5) and w.farm.get_plot(cell).crop_id == &"turnip")
	var bin: Node = w.area.find_markers("shipping_bin")[0].node
	w.player.hotbar.assign(7,&"turnip")
	w.player.hotbar.select(7)
	var n: int = eco.count_item(&"turnip")
	bin.interact(w.player)
	t.check("shipping_owns_full_harvest", n >= 2 and eco.count_item(&"turnip") == 0 and int(w.get_area_flag(&"farm","bin_turnip",0)) == n)
	var gold: int = eco.gold
	await LoopClock.to(t,18)
	t.check("shipping_sleep_succeeds", await LoopClock.bed_sleep(t))
	t.check("shipping_pays_once_next_morning", eco.gold == gold+n*eco.sell_value(&"turnip") and w.get_area_flag(&"farm","bin_turnip",null) == null)
	var saved: Dictionary = w.farm.to_dict()
	var sm: Node = t.autoload("SaveManager")
	var old_directory: String = sm.save_dir
	sm.save_dir = "user://farm-playthrough"
	t.check("save_replanted_fields", sm.save_game(0))
	var old_world_id := w.get_instance_id()
	t.check("load_replanted_fields", sm.load_and_enter(0))
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_world_id and t.player() != null,10)
	await t.frames(6)
	w = t.world()
	t.check("real_reload_preserves_crop_state", w.farm.to_dict() == saved)
	sm.save_dir = old_directory
	if native: await t.capture("farm_reloaded")
