extends RefCounted
const SECTION := "towns_routes"
const TIMEOUT_S := 180.0
const Baker := preload("res://tools/towns/bake_routes.gd")
const Refs := preload("res://tests/lib/towns/forward_refs.gd")

func run(t) -> void:
	await t.go_menu()
	if OS.get_environment("TRAETOPPEN_BAKE_ROUTES") == "1" or not FileAccess.file_exists("res://data/towns/routes.json"):
		var result: Dictionary = t.run_godot_script("res://tools/towns/bake_routes.gd")
		t.check("bake_from_real_geometry", result.code == 0, result.output)
		if result.code != 0:
			return
	t.check("table_loads_and_plans", RouteTable.load_table())
	# Legs are timed at the clock's real rate (time.minutes_per_real_second), never a missing key's default.
	var time_cfg: Dictionary = t.autoload("LuaRuntime")._config["time"]
	var rate: Variant = time_cfg["minutes_per_real_second"]
	time_cfg["minutes_per_real_second"] = 3.0
	RouteTable.load_table()
	var timed := is_equal_approx(RouteTable.game_min_per_s, 3.0)
	time_cfg["minutes_per_real_second"] = rate
	RouteTable.load_table()
	t.check("legs_use_the_clock_rate", timed and is_equal_approx(RouteTable.game_min_per_s, float(rate)), "%s game min/s" % RouteTable.game_min_per_s)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/towns/routes.json"))
	t.expect(data.get("inputs", {}).size() == Baker.input_paths().size(), "Route source inventory also catches removed inputs")
	for path in Baker.input_paths():
		t.expect(data.get("inputs", {}).get(path, "") == FileAccess.get_sha256(path), "Route source is current: " + path)
	for area in data.areas:
		var row: Dictionary = data.areas[area]
		t.expect(row.names.size() == row.d.size() and row.names.size() == row.cap.size(), area + " table dimensions")
		var connected := true
		for i in row.names.size():
			for j in row.names.size():
				connected = connected and float(row.d[i][j]) >= 0 and (i != j or float(row.d[i][j]) == 0)
		t.expect(connected, area + " anchors are reachable")
	for spot in ["torvet", "hyggetorv", "badehus", "raadhus"]:
		var names := FestSet.post_names(spot)
		var cells := {}
		for role in FestSet.roles():
			cells[role[1]] = true
		t.expect(names.size() == 28 and cells.size() == 28, spot + " festival has 28 distinct posts")
	var path := RouteTable.path("farm.porch", "int_froebutikken.counter")
	t.expect(not path.is_empty() and not path.any(func(leg): return leg.get("estimated", false)), "Farm to shop uses real paths and portals")
	var fallback := RouteTable.path("missing.a", "missing.b")
	t.check("fallback_is_flagged", not fallback.is_empty() and fallback[0].get("estimated", false))
	var paths: Array[String] = []
	for name in ["nav_grid", "route_table", "routines", "fest_set", "npc_director", "towns_validate", "level_nav", "town_marks"]:
		paths.append("res://scripts/towns/" + name + ".gd")
	var refs := Refs.scan(paths, ["TownDirector", "TownMarker", "CitizenStub", "CityTown", "GiftRules", "GiftFlow"])
	t.check("no_forward_class_refs", refs.is_empty(), str(refs))
	t.expect_tool_ids(t.run_godot_script("res://tools/towns/validate_towns.gd"), "Town CLI validator")
