class_name TownMarks
extends RefCounted
## Shared marker collection and nav clearance for the baker and live directors.
const DEFAULT_ACT := "stand"

static func collect(area: IsoArea, town_params: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"area": str(area.map.id).trim_suffix("_draft"), "kind": "grid", "doors": [], "gates": [], "posts": [], "fest": [], "curfew": true, "errors": []}
	if town_params.has("area"):
		out["area"] = str(town_params["area"])
	out["curfew"] = str(town_params.get("curfew", "true")) != "false"
	var seen: Dictionary = {}
	for m in area.find_markers("door"):
		var p: Dictionary = m["params"]
		var c: Vector2i = m["cell"]
		(out["doors"] as Array).append({"building": str(p.get("building", "")), "cell": [c.x, c.y], "interior": str(p.get("interior", ""))})
	for m in area.find_markers("warp"):
		var pw: Dictionary = m["params"]
		var cw: Vector2i = m["cell"]
		var to_area: String = str(pw.get("to", ""))
		if to_area != "" and not to_area.begins_with("int_"):
			(out["gates"] as Array).append({"name": "gate_" + to_area, "cell": [cw.x, cw.y], "to": to_area, "to_gate": "gate_" + str(out["area"])})
	for m in area.find_markers("post"):
		var p2: Dictionary = m["params"]
		var c2: Vector2i = m["cell"]
		if str(p2.get("set", "")) == "fest":
			var spot: String = str(p2.get("spot", ""))
			(out["fest"] as Array).append({"spot": spot, "cell": [c2.x, c2.y]})
			for r in FestSet.roles():
				var nm: String = "fest_%s_%s" % [spot, r[0]]
				var off: Vector2i = r[1]
				_add_post(out, seen, {"name": nm, "cell": [c2.x + off.x, c2.y + off.y], "act": DEFAULT_ACT, "cap": 1, "fest": spot})
			continue
		var name: String = str(p2.get("name", ""))
		if name == "":
			(out["errors"] as Array).append("post marker at %s has no name" % str(c2))
			continue
		_add_post(out, seen, {"name": name, "cell": [c2.x, c2.y], "act": str(p2.get("act", DEFAULT_ACT)), "cap": int(p2.get("cap", 1)), "facing": str(p2.get("facing", ""))})
	return out


static func _add_post(out: Dictionary, seen: Dictionary, post: Dictionary) -> void:
	if seen.has(post["name"]):
		(out["errors"] as Array).append("duplicate post name %s" % post["name"])
	seen[post["name"]] = true
	(out["posts"] as Array).append(post)


## Final cell of every anchor on a baked grid: doors and gates stay where the marker is (the doorstep lies inside the inflated collider of its own house: forced free), a post on a
## blocked cell moves to the nearest free cell that no other anchor uses. Returns {cells: {anchor name -> Vector2i}, snaps: [[name, cells moved]]}.
static func resolve_cells(nav: NavGrid, col: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	var taken: Dictionary = {}
	for d in col["doors"]:
		var c := Vector2i(int(d["cell"][0]), int(d["cell"][1]))
		cells["door_%s" % d["building"]] = c
		taken[c] = true
		nav.force_free(c)
	for g in col["gates"]:
		var c2 := Vector2i(int(g["cell"][0]), int(g["cell"][1]))
		cells[str(g["name"])] = c2
		taken[c2] = true
		nav.force_free(c2)
	for p in col["posts"]:
		var c3 := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
		if not nav.blocked.has(c3):
			cells[str(p["name"])] = c3
			taken[c3] = true
	var snaps: Array = []
	for p2 in col["posts"]:
		var nm: String = str(p2["name"])
		if cells.has(nm):
			continue
		var c4 := Vector2i(int(p2["cell"][0]), int(p2["cell"][1]))
		var best: Vector2i = c4
		var found: bool = false
		for r in range(1, 7):
			var bd: float = INF
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var cc := c4 + Vector2i(dx, dy)
					if nav.astar.is_in_boundsv(cc) and not nav.blocked.has(cc) and not taken.has(cc):
						var dd: float = float(dx * dx + dy * dy)
						if dd < bd:
							bd = dd
							best = cc
							found = true
			if found:
				break
		cells[nm] = best
		taken[best] = true
		snaps.append([nm, int(round(sqrt(float((best - c4).length_squared()))))])
	return {"cells": cells, "snaps": snaps}
