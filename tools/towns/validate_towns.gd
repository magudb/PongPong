extends SceneTree
## Late loading keeps the command-line driver independent of autoload parse order.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var rt: GDScript = load("res://scripts/towns/route_table.gd")
	if not rt.call("load_table"):
		print("FAIL route_table_missing (run tools/towns/bake_routes.sh)")
		quit(1)
		return
	var lr: Node = root.get_node("LuaRuntime")
	var hours: GDScript = load("res://scripts/towns/hours.gd")
	var validator: GDScript = load("res://scripts/towns/towns_validate.gd")
	var buildings := {}
	for id in hours.call("registry"):
		var row: Dictionary = hours.call("building", id)
		if row.get("wave", "core") == "core":
			buildings[id] = row
	hours.set("override_registry", buildings)
	var visuals := {}
	for id in lr.call("get_npcs"):
		visuals[id] = str(lr.call("get_npc", str(id)).get("visual", id))
	var checks := [
		["routines.feasible", "routines_feasible", []],
		["routines.places_exist", "places_exist", []],
		["hours.keeper_covers_hours", "keepers_cover_hours", []],
		["hours.consistency", "hours_consistency", [lr.call("get_shops").keys()]],
		["routines.post_capacity", "post_capacity", []],
		["towns.visual_budget", "visual_budget", [visuals]],
		["routines.no_short_visits", "no_short_visits", []],
		["routines.day_wrap", "day_wrap", []],
		["hours.visits_inside_hours", "visits_inside_hours", []],
	]
	var failed := 0
	for check in checks:
		var errors: Array = validator.callv(str(check[1]), check[2])
		print(("PASS " if errors.is_empty() else "FAIL ") + str(check[0]) + ("" if errors.is_empty() else " " + str(errors)))
		failed += int(not errors.is_empty())
	hours.set("override_registry", {})
	quit(int(failed > 0))
