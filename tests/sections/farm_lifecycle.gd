extends RefCounted
const SECTION := "farm_lifecycle"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var grid: FarmGrid = w.farm
	var gm: Node = t.autoload("GameManager")
	var tm: Node = t.autoload("TimeManager")
	var eco: Node = t.autoload("EconomyManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	tm.set_weather(&"klart")
	for season in [&"foraar", &"sommer", &"efteraar", &"vinter"]:
		gm.set_config_override("time.weather_chances." + str(season), {"klart": 1.0})
	var cell: Vector2i = grid.farmable_cells()[0]
	eco.add_item(&"turnip_seeds", 3, true)
	eco.add_item(&"strawberry_seeds", 2, true)
	eco.add_item(&"fairy_dust_water", 1, true)
	t.check("till_and_water_before_planting", grid.till(cell) and grid.water(cell))
	t.check("repeated_watering_has_no_effect", not grid.water(cell))
	t.check("planting_uses_existing_water", grid.plant(cell, &"turnip_seeds") == "" and grid.get_plot(cell).eligible_water and grid.state_of(cell) == FarmGrid.State.WATERED)
	for i in 4:
		if i > 0: grid.water(cell)
		gm.end_day()
		tm.set_weather(&"klart")
	t.check("watered_crop_ripens_after_four_nights", grid.state_of(cell) == FarmGrid.State.READY)
	grid.water(cell)
	var before: int = eco.count_item(&"turnip")
	t.check("harvest_keeps_watered_tilled_soil", grid.harvest(cell) > 0 and grid.state_of(cell) == FarmGrid.State.TILLED and grid.get_plot(cell).watered and eco.count_item(&"turnip") > before)
	t.check("can_replant_without_hoe", grid.plant(cell, &"turnip_seeds") == "" and grid.get_plot(cell).eligible_water)
	gm.end_day()
	tm.set_weather(&"klart")
	var growth: float = grid.get_plot(cell).growth_days
	gm.end_day()
	tm.set_weather(&"klart")
	t.check("dry_day_pauses_growth_without_killing_crop", grid.get_plot(cell).growth_days == growth and grid.state_of(cell) == FarmGrid.State.PLANTED)
	t.check("scythe_protects_living_crops", not grid.clear_crop(cell))
	t.check("pickaxe_can_clear_living_crop_to_tilled_soil", grid.clear_crop(cell, false) and grid.state_of(cell) == FarmGrid.State.TILLED)
	t.check("strawberry_can_be_planted", grid.plant(cell, &"strawberry_seeds") == "")
	for i in 4:
		grid.water(cell)
		gm.end_day()
		tm.set_weather(&"klart")
	t.check("berry_harvest_retains_bush", grid.harvest(cell) > 0 and grid.get_plot(cell).regrowing and grid.get_plot(cell).crop_id == &"strawberry" and grid.visual_stage(cell) == 2)
	var wire: Dictionary = JSON.parse_string(JSON.stringify(grid.to_dict()))
	t.check("regrowing_crop_roundtrips", grid.from_dict(wire) and grid.get_plot(cell).regrowing)
	var seeds: int = eco.count_item(&"strawberry_seeds")
	for i in 4:
		grid.water(cell)
		gm.end_day()
		tm.set_weather(&"klart")
	t.check("berries_regrow_without_spending_seed", grid.state_of(cell) == FarmGrid.State.READY and eco.count_item(&"strawberry_seeds") == seeds and grid.harvest(cell) > 0)
	# Advance the actual calendar rather than synthesizing day/season events.
	while gm.season == &"foraar":
		gm.end_day()
		tm.set_weather(&"klart")
	t.check("spring_berry_withers_in_summer", grid.state_of(cell) == FarmGrid.State.WITHERED and grid.harvest(cell) == 0)
	wire = JSON.parse_string(JSON.stringify(grid.to_dict()))
	t.check("dead_crop_save_roundtrip", grid.from_dict(wire) and grid.state_of(cell) == FarmGrid.State.WITHERED)
	t.check("dead_crops_reject_water_and_supplies", not grid.water(cell) and not grid.apply_supply(cell, &"fairy_dust_water"))
	t.check("scythe_clears_dead_crop_and_preserves_soil", grid.clear_crop(cell) and grid.state_of(cell) == FarmGrid.State.TILLED)
	var n: int = eco.count_item(&"strawberry_seeds")
	t.check("out_of_season_planting_keeps_seed", grid.plant(cell, &"strawberry_seeds") == "UI_NOT_IN_SEASON" and eco.count_item(&"strawberry_seeds") == n)
	grid.plant(cell, &"turnip_seeds")
	# Carrots and turnips span spring/summer; only turnips end at autumn.
	grid.water(cell)
	var next_cell: Vector2i = grid.farmable_cells()[1]
	eco.add_item(&"carrot_seeds", 1, true)
	grid.till(next_cell)
	grid.plant(next_cell, &"carrot_seeds")
	for i in 4:
		grid.water(cell)
		gm.end_day()
		tm.set_weather(&"klart")
	t.check("crop_is_mature_before_season_end", grid.state_of(cell) == FarmGrid.State.READY)
	while gm.season == &"sommer":
		gm.end_day()
		tm.set_weather(&"klart")
	t.check("out_of_season_mature_crop_also_withers", grid.state_of(cell) == FarmGrid.State.WITHERED)
	t.check("multiseason_crop_survives_season_boundary", grid.state_of(next_cell) != FarmGrid.State.WITHERED and grid.get_plot(next_cell).crop_id == &"carrot")
	var bad := {"plots": {"1,1": {"state": 2, "crop_id": "carrot", "regrowing": true}}}
	var original := grid.to_dict()
	t.check("rejects_impossible_regrowth_without_mutation", not grid.from_dict(bad) and grid.to_dict() == original)
