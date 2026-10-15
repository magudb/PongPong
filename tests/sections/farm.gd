extends RefCounted
## FarmSystem plot round-trip (the gap save.gd defers to `farm.save_roundtrip`): till / plant / water survive
## to_dict -> JSON -> from_dict, including the upgraded grid and a plot the save does not know.
const SECTION := "farm"
const TIMEOUT_S := 60.0


func run(t) -> void:
	var eco = t.autoload("EconomyManager")
	var gm = t.autoload("GameManager")
	# FarmSystem._ready pulls crop_defs from Lua and builds the 4x3 grid; the meshes are harmless headless.
	var farm: Node3D = load("res://scripts/farm/farm_system.gd").new()
	t.tree.root.add_child(farm)
	await t.frames(2)

	t.check("farm_builds_grid", farm.plots.size() == 12 and farm.farm_level == 1, "12 plots at farm_level 1")

	var empty: Dictionary = farm.to_dict()
	var empty_json: Dictionary = JSON.parse_string(JSON.stringify(empty))
	t.check("empty_farm_serialises", empty_json != null and (empty_json["plots"] as Dictionary).size() == 12 and int(empty_json["farm_level"]) == 1,
		"to_dict survives JSON.stringify/parse with every plot")

	# Till -> plant -> water one plot. Seeds come from the economy (starter kit or add_item).
	var plot_id: StringName = &"plot_1_1"
	var seed_id: StringName = &"turnip_seeds"
	if eco.count_item(seed_id) < 1:
		eco.add_item(seed_id, 1, true)
	t.check("farm_till", farm.till_plot(plot_id), "plot_1_1 tills")
	t.check("farm_plant", farm.plant_crop(plot_id, &"turnip"), "turnip planted (one seed spent)")
	t.check("farm_water", farm.water_plot(plot_id), "plot watered")
	var before: Dictionary = farm.to_dict()["plots"]["1,1"]

	# Round-trip through JSON the way SaveManager writes a section.
	var text := JSON.stringify(farm.to_dict())
	var loaded: Dictionary = JSON.parse_string(text)
	var farm2: Node3D = load("res://scripts/farm/farm_system.gd").new()
	t.tree.root.add_child(farm2)
	await t.frames(2)
	farm2.from_dict(loaded)
	var after: Dictionary = farm2.to_dict()["plots"]["1,1"]

	t.check("farm_roundtrip_plot",
		str(after["id"]) == str(before["id"]) and int(after["state"]) == int(before["state"])
		and str(after["crop_id"]) == str(before["crop_id"]) and int(after["growth_stage"]) == int(before["growth_stage"])
		and bool(after["watered"]) == bool(before["watered"]) and int(after["planted_day"]) == int(before["planted_day"]),
		"id/state/crop/growth/watered/planted_day survive JSON: %s" % str(after))

	# A save that only knows some keys still lands on the defaults of the rest (no crash, no stale state).
	var partial := {"plots": {"1,1": {"id": "plot_1_1", "state": 2, "crop_id": "turnip"}}, "farm_level": 2, "upgrades": [&"greenhouse"]}
	farm2.from_dict(partial)
	var rebuilt: Dictionary = farm2.to_dict()
	t.check("farm_partial_save_defaults",
		int(rebuilt["farm_level"]) == 2 and (rebuilt["upgrades"] as Array) == [&"greenhouse"]
		and int(rebuilt["plots"]["1,1"]["state"]) == 2 and str(rebuilt["plots"]["1,1"]["crop_id"]) == "turnip"
		and bool(rebuilt["plots"]["1,1"]["watered"]) == false and int(rebuilt["plots"]["1,1"]["growth_stage"]) == 0
		and (rebuilt["plots"] as Dictionary).size() == 12,
		"missing keys default (watered false, stage 0), level/upgrades land, the other 11 plots stay")

	# An unknown plot key in the save is ignored rather than inventing a 13th plot.
	farm2.from_dict({"plots": {"9,9": {"id": "plot_9_9", "state": 4}}})
	t.check("farm_unknown_plot_ignored", farm2.plots.size() == 12 and farm2.get_plot_at(9, 9) == null, "save cannot grow the grid")

	t.check("farm_harvest_needs_ready", farm.harvest_plot(plot_id) == 0, "a watered (not READY) plot yields nothing")
	farm2.free()
	farm.free()
