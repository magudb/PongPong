extends RefCounted
const SECTION := "farm_automation"
const TIMEOUT_S := 240.0
var native := false
func run(t) -> void: await _run(t)
func run_windowed(t) -> void:
	native = true
	await _run(t)
func _run(t) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	var tm: Node = t.autoload("TimeManager")
	var sm: Node = t.autoload("SaveManager")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	for season in [&"foraar", &"sommer", &"efteraar", &"vinter"]:
		gm.set_config_override("time.weather_chances."+str(season),{"klart":1.0})
	tm.set_weather(&"klart")
	for item in [&"sprinkler", &"quality_sprinkler", &"preserves_jar", &"keg"]: eco.add_item(item,2,true)
	eco.add_item(&"carrot_seeds",20,true)
	var missing: Array[String] = []
	var shelf: Dictionary = t.autoload("LuaRuntime").get_shop("greenhouse_seeds").get("stock", {})
	for crop in FarmGrid.crop_definitions():
		if not shelf.has(str(crop)+"_seeds") or GameData.item_def(StringName("preserve_"+str(crop))).is_empty() or GameData.item_def(StringName("juice_"+str(crop))).is_empty():
			missing.append(str(crop))
	t.check("every_crop_has_greenhouse_seeds_and_both_processed_outputs", missing.is_empty(), str(missing))
	var center := Vector2i(22,27)
	var hands := preload("res://tests/lib/town_loop/farm_day.gd").new()
	var neighbors: Array[Vector2i] = []
	for y in [-1,0,1]:
		for x in [-1,0,1]:
			if x == 0 and y == 0: continue
			var cell := center+Vector2i(x,y)
			neighbors.append(cell)
			w.farm.till(cell)
			w.farm.plant(cell,&"carrot_seeds")
	t.check("walk_to_sprinkler_tile", await hands.face_plot(t,center))
	w.player.hotbar.assign(7,&"sprinkler")
	t.tap(&"slot_8")
	await t.frames(2)
	t.tap(&"use_tool")
	await t.physics(2)
	await t.until(func():return w.player.state == PlayerBody2D.S.FREE,2)
	t.check("sprinkler_can_be_placed_by_tool_input", not FarmEquipment.at(&"farm",center).is_empty())
	var inventory: int = eco.count_item(&"sprinkler")
	t.check("occupied_tile_rejects_duplicate_without_spending", not PlacementService.place(&"sprinkler",center) and eco.count_item(&"sprinkler") == inventory)
	t.check("sprinkler_tile_cannot_be_sown", not w.farm.till(center))
	gm.end_day()
	var watered := 0
	var all_waited := true
	for cell in neighbors:
		if w.farm.get_plot(cell).watered: watered += 1
		all_waited = all_waited and w.farm.get_plot(cell).growth_days == 0
	t.check("basic_sprinkler_waters_four_on_morning", watered == 4)
	t.check("new_morning_water_cannot_grow_previous_dry_day", all_waited)
	gm.end_day()
	var grown := 0
	for cell in neighbors:
		if w.farm.get_plot(cell).growth_days == 1: grown += 1
	t.check("sprinkler_water_grows_four_next_night", grown == 4)
	var machine: FarmMachine2D = _machine(w.area,center)
	t.check("empty_sprinkler_can_be_picked_up", machine != null and machine.tool_hit("pickaxe",1,w.player) and eco.count_item(&"sprinkler") == inventory+1)
	await t.physics(2)
	t.check("quality_sprinkler_can_replace_basic", PlacementService.place(&"quality_sprinkler",center))
	gm.end_day()
	t.check("quality_sprinkler_waters_all_eight", neighbors.all(func(c):return w.farm.get_plot(c).watered))
	for i in 4: gm.end_day()
	t.check("automated_crops_reach_harvest", neighbors.all(func(c):return w.farm.state_of(c) == FarmGrid.State.READY))
	var jar_cell := Vector2i(24,27)
	var keg_cell := Vector2i(25,27)
	t.check("processing_machines_place_on_empty_field", PlacementService.place(&"preserves_jar",jar_cell) and PlacementService.place(&"keg",keg_cell))
	eco.add_item(&"carrot",2,true)
	var jar := FarmEquipment.at(&"farm",jar_cell)
	var keg := FarmEquipment.at(&"farm",keg_cell)
	var count: int = eco.count_item(&"carrot")
	t.check("walk_to_processing_machine", await hands.face_plot(t,jar_cell))
	w.player.hotbar.assign(7,&"carrot")
	t.tap(&"slot_8")
	await t.frames(2)
	t.tap(&"interact")
	await t.frames(3)
	t.check("machines_consume_one_crop_each", jar.has("batch") and FarmEquipment.load_crop(keg,&"carrot") and eco.count_item(&"carrot") == count-2)
	t.check("busy_machine_never_accepts_second_crop", not FarmEquipment.load_crop(jar,&"carrot") and not FarmEquipment.load_crop(keg,&"wood"))
	t.check("processing_machine_cannot_be_removed", not _machine(w.area,jar_cell).tool_hit("pickaxe",1,w.player))
	t.check("early_collection_does_nothing", not FarmEquipment.collect(jar))
	gm.end_day()
	var before: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	var directory: String = sm.save_dir
	sm.save_dir = "user://farm-automation"
	t.check("processing_jobs_save", sm.save_game(0))
	var old_id := w.get_instance_id()
	t.check("processing_jobs_load", sm.load_and_enter(0))
	await t.until(func():return t.world()!=null and t.world().get_instance_id()!=old_id,10)
	await t.frames(6)
	w=t.world()
	var restored: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	t.check("jobs_and_crop_models_survive_real_reload", restored.placed == before.placed and restored.farm == before.farm)
	jar=FarmEquipment.at(&"farm",jar_cell)
	keg=FarmEquipment.at(&"farm",keg_cell)
	gm.end_day()
	t.check("jar_ready_after_two_nights_keg_still_busy", gm.total_day() >= int(jar.batch.ready_day) and gm.total_day() < int(keg.batch.ready_day))
	eco.inventory.clear()
	for i in 24: eco.inventory.append({"id":&"wood","amount":99,"meta":{}})
	var batch: Dictionary = jar.batch.duplicate(true)
	t.check("full_backpack_keeps_finished_batch", not FarmEquipment.collect(jar) and jar.batch == batch)
	eco.inventory.clear()
	var messages: Array[String] = []
	var record_toast := func(_title, message, _icon): messages.append(message)
	t.autoload("EventBus").notification_posted.connect(record_toast)
	t.check("finished_preserves_collect_once", FarmEquipment.collect(jar) and not FarmEquipment.collect(jar) and eco.count_item(&"preserve_carrot") == 1)
	t.autoload("EventBus").notification_posted.disconnect(record_toast)
	t.check("processed_product_toast_uses_catalogue_name", messages.any(func(message):return tr("ITEM_PRESERVE_CARROT") in message) and not messages.any(func(message):return "ITEM_" in message))
	gm.end_day()
	t.check("finished_juice_collects_after_three_nights", FarmEquipment.collect(keg) and eco.count_item(&"juice_carrot") == 1)
	t.check("processing_increases_crop_value", eco.sell_value(&"preserve_carrot") > eco.sell_value(&"carrot") and eco.sell_value(&"juice_carrot") > eco.sell_value(&"carrot"))
	if native:
		w.game_ui.get_screen(&"hud").toasts.clear()
		w.player.global_position = w.area.cell_to_global(Vector2i(24,28))
		w.player._set_zoom(0.62)
		await t.physics(2)
		w.player.camera.reset_smoothing()
		w.player.camera.force_update_scroll()
		await t.frames(6)
		await t.capture("farm_machines")
	# Use the existing home progression owner to earn the prerequisite tier.
	t.check("greenhouse_requires_home_upgrade", not FarmEquipment.build_greenhouse())
	Grant.requirements(2)
	t.check("house_upgrade_starts", t.autoload("HomeManager").start_upgrade().ok)
	gm.end_day()
	await t.frames(3)
	var row: Dictionary = GameData.cfg("greenhouse",{})
	for art in [&"greenhouse", &"greenhouse_walls", &"sprinkler", &"preserves_jar", &"keg", &"planter_box", &"seed_basket"]:
		t.check("painted_art_"+str(art), ArtCatalog.prop(art).get("real",false))
	for item in row.build_cost:
		if item == "gold": eco.add_gold(int(row.build_cost[item]))
		else: eco.add_item(StringName(item),int(row.build_cost[item]),true)
	var menu: TTScreen = w.game_ui.get_screen(&"build_menu_ui")
	menu._selected_building=&"greenhouse"
	menu.open()
	await t.frames(3)
	t.check("greenhouse_offer_uses_painted_preview", not menu.build_btn.disabled and menu.preview.texture != null)
	if native: await t.capture("greenhouse_offer")
	menu.build_btn.pressed.emit()
	await t.frames(3)
	var confirm: UiConfirm = menu.find_child("UiConfirm",true,false)
	t.check("greenhouse_confirmation_defaults_cancel", confirm!=null and confirm.get_node("%CancelButton").has_focus())
	UiAudit.press(t,&"ui_cancel")
	await t.frames(2)
	t.check("greenhouse_cancel_does_not_start", not FarmEquipment.greenhouse_building())
	menu.build_btn.pressed.emit()
	await t.frames(2)
	confirm=menu.find_child("UiConfirm",true,false)
	confirm.get_node("%OkButton").grab_focus()
	UiAudit.press_pad(t,JOY_BUTTON_A)
	await t.frames(3)
	t.check("greenhouse_payment_starts_one_construction", FarmEquipment.greenhouse_building() and not FarmEquipment.build_greenhouse() and not FarmEquipment.greenhouse_built())
	menu.close()
	var payload: Dictionary = JSON.parse_string(JSON.stringify(sm.gather_payload()))
	t.check("greenhouse_construction_roundtrips", sm._apply_payload(payload).ok and FarmEquipment.greenhouse_building())
	for i in int(row.build_days): gm.end_day()
	await t.frames(3)
	t.check("greenhouse_completes_on_configured_morning", FarmEquipment.greenhouse_built() and not FarmEquipment.greenhouse_building())
	if native:
		w.game_ui.get_screen(&"hud").toasts.clear()
		w.player.global_position=w.area.get_spawn("from_greenhouse")
		w.player._set_zoom(0.6)
		await t.physics(2)
		w.player.camera.reset_smoothing()
		w.player.camera.force_update_scroll()
		await t.frames(6)
		await t.capture("greenhouse_exterior")
	var door: Greenhouse2D = w.area.find_markers("greenhouse_slot")[0].node
	t.check("walk_to_painted_greenhouse_door", await hands.face_plot(t,door.cell-Vector2i(2,0)))
	t.check("painted_door_is_the_interaction_target", w.player.nearest_interactable()==door)
	t.tap(&"interact")
	await t.until(func():return w.area.map.id == &"greenhouse" and not w.traveling,12)
	t.check("door_enters_separate_twelve_bed_greenhouse", w.area.map.id == &"greenhouse" and w.greenhouse_farm.farmable_cells().size()==12 and w.player.farm==w.greenhouse_farm)
	var indoor: FarmGrid = w.greenhouse_farm
	var cells: Array = indoor.farmable_cells()
	eco.add_item(&"snow_turnip_seeds",1,true)
	eco.add_item(&"strawberry_seeds",1,true)
	for cell in cells: indoor.till(cell)
	t.check("winter_crop_plants_indoors_in_spring", indoor.plant(cells[0],&"snow_turnip_seeds")=="")
	t.check("indoor_rain_does_not_water_beds", not indoor.get_plot(cells[0]).watered)
	tm.set_weather(&"regn")
	t.check("outdoor_rain_never_waters_greenhouse", not indoor.get_plot(cells[0]).watered)
	tm.set_weather(&"klart")
	indoor.plant(cells[1],&"strawberry_seeds")
	indoor.water(cells[0]);indoor.water(cells[1])
	gm.day=28
	gm.end_day()
	t.check("indoor_crops_survive_season_change", gm.season==&"sommer" and indoor.state_of(cells[0])!=FarmGrid.State.WITHERED and indoor.state_of(cells[1])!=FarmGrid.State.WITHERED)
	eco.add_item(&"quality_sprinkler",1,true)
	t.check("sprinkler_places_indoors", PlacementService.place(&"quality_sprinkler",Vector2i(4,4)))
	for i in 5: gm.end_day()
	t.check("indoor_sprinkler_grows_winter_crop", indoor.state_of(cells[0])==FarmGrid.State.READY)
	gm.hour=25
	gm.minute=30
	t.autoload("ShopSystem").open_shop(&"greenhouse_seeds")
	await t.frames(3)
	var shop: Control=w.game_ui.get_screen(&"shop_ui")
	t.check("seed_shelf_open_after_midnight", shop.is_open() and t.autoload("ShopSystem").is_open(&"greenhouse_seeds"))
	t.check("winter_seeds_can_be_bought", t.autoload("ShopSystem").buy_item(&"greenhouse_seeds",&"snowdrop_seeds",1))
	if native: await t.capture("greenhouse_seed_shelf")
	shop.close()
	if native:
		w.game_ui.get_screen(&"hud").toasts.clear()
		await t.frames(3)
		await t.capture("greenhouse_crops")
	payload=JSON.parse_string(JSON.stringify(sm.gather_payload()))
	t.check("both_crop_models_and_indoor_equipment_roundtrip", sm._apply_payload(payload).ok and w.greenhouse_farm.get_plot(cells[0]).crop_id==&"snow_turnip" and FarmEquipment.at(&"greenhouse",Vector2i(4,4)).item=="quality_sprinkler")
	var bad: Dictionary = payload.duplicate(true)
	bad.world.placed[0]["batch"]={"input":"carrot","output":"iron_sword","ready_day":1}
	# SAVE-07: a job whose output no longer matches its recipe is content drift (a renamed product), not damage: the save loads and
	# the job gets today's output name (this check used to pin a rejection of the whole payload); a broken shape is still refused
	var mended: Dictionary = FarmEquipment.repair_placed(bad.world.placed)
	var job: Dictionary = mended.placed[0].get("batch", {})
	t.check("renamed_machine_output_repaired_on_load", sm.validate_payload(bad).ok and (job.is_empty() or str(job.output) != "iron_sword"), str(job))
	bad.world.placed[0]["batch"]={"input":7,"output":"juice_carrot","ready_day":1}
	t.check("malformed_machine_job_rejected_before_load", not sm.validate_payload(bad).ok)
	bad=payload.duplicate(true)
	bad.world.greenhouse_farm={"plots":{"bad":{}}}
	t.check("malformed_indoor_crops_rejected_before_load", not sm.validate_payload(bad).ok)
	var route := await LoopWalker.walk_to(t,w.area.cell_to_global(Vector2i(5,9)),8,12)
	await t.until(func():return w.area.map.id==&"farm" and not w.traveling,12)
	t.check("walkable_greenhouse_exit_restores_outdoor_tools", route.ok and w.area.map.id==&"farm" and w.player.farm==w.farm)
	w.area.find_markers("greenhouse_slot")[0].node.interact(w.player)
	await t.until(func():return w.area.map.id==&"greenhouse" and not w.traveling,12)
	t.check("returning_to_greenhouse_preserves_indoor_harvest", indoor.state_of(cells[0])==FarmGrid.State.READY and w.player.farm==indoor)
	var moon_cell := Vector2i(5,4)
	eco.add_item(&"moonflower_seeds",1,true)
	indoor.plant(moon_cell,&"moonflower_seeds")
	gm.hour=25
	gm.minute=59
	gm.advance_time(1)
	t.check("sprinklers_use_six_am_even_on_raw_two_am_roll", indoor.get_plot(moon_cell).watered and indoor.get_plot(moon_cell).watered_hour == 6.0 and not indoor.get_plot(moon_cell).eligible_water)
	await LoopClock.settle(t)
	# GAP4-01: a Continue on the farm with the greenhouse built draws the greenhouse (not the build stake) and puts its door where the
	# painted door is, through the real path: load_and_enter -> scene change -> the new world enters the farm, then applies the save.
	w._enter(&"farm", &"default")
	await t.frames(2)
	var old_world := w.get_instance_id()
	var entered: bool = sm.save_game(0) and sm.load_and_enter(0)
	var arrived: bool = await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_world and t.world().get("ready_for_play") == true, 20.0)
	var loaded_world: WorldRoot2D = t.world()
	var loaded_door: Greenhouse2D = loaded_world.area.find_markers("greenhouse_slot")[0].node if arrived and loaded_world.area.map.id == &"farm" else null
	t.check("greenhouse_drawn_after_continue", entered and arrived and loaded_door != null and loaded_door._built and FarmEquipment.greenhouse_built()
		and loaded_door.position.is_equal_approx(loaded_world.area.objects.to_local(loaded_world.area.cell_to_global(loaded_door.cell - Vector2i(2, 0)))),
		"after load_and_enter the greenhouse marker is built (%s) with its door at the painted door" % [loaded_door._built if loaded_door != null else "no marker"])
	sm.save_dir=directory

func _machine(area: IsoArea, cell: Vector2i) -> FarmMachine2D:
	for node in area.find_children("*","Node",true,false):
		if node is FarmMachine2D and node.cell == cell: return node
	return null
