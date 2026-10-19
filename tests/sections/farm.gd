extends RefCounted
const SECTION := "farm"
const TIMEOUT_S := 120.0

func run(t) -> void:
	await t.go_menu()
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var tm: Node = t.autoload("TimeManager")
	var bus: Node = t.autoload("EventBus")
	var saved_gm: Dictionary = gm.to_dict()
	var saved_eco: Dictionary = eco.to_dict()
	var weather: StringName = tm.weather
	gm.day = 1
	gm.season = &"sommer"
	gm.hour = 12
	tm.set_weather(&"klart")
	var grid := FarmGrid.new()
	t.tree.root.add_child(grid)
	var cell: Vector2i = grid.farmable_cells()[0]
	t.check("only_authored_farm_cells", not grid.till(Vector2i(-1, -1)) and not grid.till(Vector2i(40, 24)) and grid.till(cell))
	t.check("no_double_till", not grid.till(cell))
	for crop in grid.crop_defs:
		gm.day = 1
		gm.season = StringName(grid.crop_defs[crop].seasons[0])
		grid.from_dict({"plots": {}})
		var seed := StringName(crop + "_seeds")
		eco.add_item(seed, 1, true)
		grid.till(cell)
		var observed: Array = []
		var inventory_changed := func(_items: Dictionary) -> void:
			observed.append(grid.get_plot(cell).crop_id == StringName(crop))
		bus.player_inventory_changed.connect(inventory_changed)
		t.expect(grid.plant(cell, seed) == "", crop + " seed consumed")
		bus.player_inventory_changed.disconnect(inventory_changed)
		t.expect(observed == [true], crop + " commits before inventory observers")
		var days := int(grid.crop_defs[crop].stages) * int(grid.crop_defs[crop].days_per_stage)
		for day in days:
			gm.hour = 25 if crop == "moonflower" else 12
			grid.water(cell)
			gm.day += 1
			bus.day_started.emit(gm.day, gm.season)
			t.expect(grid.get_plot(cell).growth_days == day + 1, crop + " one growth per watered day")
			t.expect(grid.visual_stage(cell) in range(4), crop + " four painted stages")
		t.expect(grid.state_of(cell) == FarmGrid.State.READY and grid.visual_stage(cell) == 3, crop + " configured ripening")
		var before: int = eco.count_item(StringName(crop))
		observed.clear()
		var on_gain := func(id: StringName, _amount: int) -> void:
			if id == StringName(crop):
				observed.append(grid.state_of(cell) != FarmGrid.State.READY and grid.harvest(cell) == 0)
		bus.item_gained.connect(on_gain)
		var amount := grid.harvest(cell)
		bus.item_gained.disconnect(on_gain)
		t.expect(amount >= 1 and eco.count_item(StringName(crop)) == before + amount and observed == [true], crop + " atomic harvest")
	gm.day = 1
	gm.season = &"sommer"
	gm.hour = 12
	tm.set_weather(&"klart")
	grid.from_dict({"plots": {}})
	grid.till(cell)
	eco.add_item(&"moonflower_seeds", 1, true)
	grid.water(cell) # Wet bare soil at noon does not become night-watered just by sowing at night.
	gm.hour = 20
	grid.plant(cell, &"moonflower_seeds")
	t.check("moon_seed_does_not_retime_bare_soil_watering", not grid.get_plot(cell).eligible_water)
	gm.hour = 12
	for hour in [19.99, 20.0, 23.99, 24.5, 25.99, 2.0, 5.99, 6.0, 12.0]:
		var expected: bool = float(hour) >= 20.0 or float(hour) < 6.0
		t.expect(grid.in_water_window(hour) == expected and grid.in_water_window(hour, &"turnip"), "Raw moon-water edge " + str(hour))
	grid.water(cell)
	gm.day += 1
	bus.day_started.emit(gm.day, gm.season)
	t.check("day_water_does_not_grow_moon_crop", grid.get_plot(cell).growth_days == 0)
	grid.water(cell)
	gm.hour = 25
	gm.minute = 30
	grid.water(cell)
	gm.day += 1
	gm.hour = 2
	bus.day_started.emit(gm.day, gm.season)
	t.check("moon_crop_watered_at_01_30_grows_at_roll", grid.get_plot(cell).growth_days == 1)
	bus.day_started.emit(gm.day, gm.season)
	t.check("duplicate_day_signal_cannot_grow_twice", grid.get_plot(cell).growth_days == 1)
	tm.set_weather(&"klart")
	grid.from_dict({"plots": {}})
	grid.till(cell)
	eco.add_item(&"turnip_seeds", 2, true)
	grid.plant(cell, &"turnip_seeds")
	gm.hour = 12
	gm.day += 1
	tm.roll_weather_for_day()
	tm.set_weather(&"regn")
	bus.day_started.emit(gm.day, gm.season)
	t.check("new_rain_does_not_grow_yesterdays_dry_crop", grid.get_plot(cell).growth_days == 0 and grid.get_plot(cell).watered)
	gm.day += 1
	tm.roll_weather_for_day()
	tm.set_weather(&"klart")
	bus.day_started.emit(gm.day, gm.season)
	t.check("rainy_day_growth_survives_clear_morning", grid.get_plot(cell).growth_days == 1 and not grid.get_plot(cell).watered)
	eco.add_item(&"fertilizer", 2, true)
	eco.add_item(&"fairy_dust_water", 1, true)
	t.check("fertilizer_once_per_harvest", grid.apply_supply(cell, &"fertilizer") and not grid.apply_supply(cell, &"fertilizer"))
	t.check("auto_water_supply", grid.apply_supply(cell, &"fairy_dust_water") and grid.get_plot(cell).auto_water_days == 3)
	for day in 3:
		gm.day += 1
		bus.day_started.emit(gm.day, gm.season)
	t.check("auto_water_three_days_and_ripe", grid.state_of(cell) == FarmGrid.State.READY and grid.get_plot(cell).auto_water_days == 0)
	var original := grid.to_dict()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(original))
	t.check("json_roundtrip", grid.from_dict(saved) and grid.to_dict() == original)
	eco.inventory.clear()
	for i in 24:
		eco.inventory.append({"id": &"wood", "amount": 99, "meta": {}})
	t.check("full_bag_keeps_ripe_crop", grid.harvest(cell) == 0 and grid.state_of(cell) == FarmGrid.State.READY and grid.get_plot(cell).fertilizer)
	eco.inventory.clear()
	t.check("fertilizer_bonus_yield", grid.harvest(cell) >= 2 and not grid.get_plot(cell).fertilizer)
	var unchanged := grid.to_dict()
	# (an unknown crop id used to be in this list; since SAVE-07 it is content drift that loads as a tilled plot, checked below)
	for corrupt in [{"plots": []}, {"plots": {"oops": {}}}, {"plots": {"1,1": {"state": 999}}}, {"plots": {"1,1": {"growth_days": -1}}}, {"plots": {"1,1": {"watered": "yes"}}}, {"plots": {"1,1": {"state": 4, "crop_id": ""}}}]:
		t.expect(not grid.from_dict(corrupt) and grid.to_dict() == unchanged, "Corrupt save leaves crops unchanged")
	var drift := {"plots": {"%d,%d" % [cell.x, cell.y]: {"state": 4, "crop_id": "unknown"}}}
	t.check("unknown_crop_loads_as_tilled_plot", grid.from_dict(drift) and grid.get_plot(cell) != null and grid.get_plot(cell).crop_id == &"" and grid.state_of(cell) == FarmGrid.State.TILLED)
	grid.from_dict(unchanged)
	var changed: Array = []
	grid.plot_changed.connect(func(c: Vector2i) -> void: changed.append(c))
	grid.from_dict({"plots": {}})
	t.check("load_clears_old_view_cells", cell in changed and grid.plots.is_empty())
	var zones: Array = []
	var unlocked := func(id: StringName) -> void: zones.append(id)
	bus.plot_unlocked.connect(unlocked)
	var before_cells: int = grid.farmable_cells().size()
	t.check("unlock_cells_from_marker_grammar", grid.unlock_cells("east") == 42 and grid.farmable_cells().size() == before_cells + 42)
	t.check("plot_unlocked_once_per_zone", grid.unlock_cells("east") == 0 and zones == [&"zone:east"])
	bus.plot_unlocked.disconnect(unlocked)
	t.check("zones_are_not_duplicated_in_crop_save", grid.to_dict().keys() == ["plots"])
	var save: Node = t.autoload("SaveManager")
	var verdict: Dictionary = save.validate_payload({"meta": {"version": 2}, "world": {"farm": {"plots": {"bad": {}}}}})
	t.check("save_preflight_rejects_bad_crops", not verdict.ok and verdict.code == "invalid")
	for crop in grid.crop_defs:
		for stage in 4:
			t.expect(ArtCatalog.prop(StringName("crop_%s_%d" % [crop, stage])).get("real", false), "Painted crop " + crop + " " + str(stage))
	grid.free()
	gm.from_dict(saved_gm)
	eco.from_dict(saved_eco)
	tm.set_weather(weather)
