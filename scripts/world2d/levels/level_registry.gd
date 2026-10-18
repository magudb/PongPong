class_name LevelRegistry
extends RefCounted
## The levels of a levelled builder area (package V3-levels, design DUNGEON_V2_ADDENDUM 7.3 and design_v2.md 4.2 / 4.3) built from a
## Dictionary of the shape of data/traetoppen/traetoppen.json, and the ONE place that answers `level_at(world_pos)`.
##
## DATA (sketch px, header `scale` = world px per sketch px, K = 3.0): levels (platforms) with rank, bit, centre, rx, ry and a walk spec
## {inset, keepout[]}; bridges with from / to, a centre line, width and rank; stubs (bridge pieces that leave the map, part of the platform
## they leave from), ladders, climb zones, lifts, buildings, props, spawns, landmarks. Everything is converted to WORLD px here (x, y of
## the screen plane: the sketch is already drawn in the project's 36 degree projection, so world = sketch x K on both axes).
##
## MODEL (design 4.1 option 4, "painted heights with ranked levels"):
##   * a level is a polygon region in the screen plane; a platform's region is its ellipse (inset 0.96) minus the keep-outs (trunk circle,
##     hut circles, props, the shadow of the Upper deck on the Torvet); a bridge's region is the strip of its centre line (width / 2 each side);
##   * level_at(pos) is a FUNCTION OF POSITION: the platforms are disjoint by construction, a bridge strip carries priority 1 so where it
##     overlaps a disc (the landing) the bridge wins; null where no level has the point (the void between decks, keep-outs);
##   * a bridge end is `over` when the bridge is painted after the platform (rank above: B4 B5 B8 and the B0..B3 ends on A / B) and `under`
##     when the platform's rim covers it (B0..B3 on the Upper deck, E and C; B6 B7 on F and G). At an `under` end the actor must change level
##     ONE BODY RADIUS BEFORE the rim, so the strip stops there (the gate) and the platform gets a landing pad that reaches out to the gate;
##   * physics layers are allocated from FIRST_BIT = 12 (project.godot names only 1..11 and is not touched): the JSON's `bit` wins when given,
##     else the next free one in file order (platforms, then bridges).
##
## levels_graph() is the READ-ONLY view the planner of the towns track (LevelNav, RT21) walks: the same Level objects the builder
## collides with, so planner and collision cannot drift. Coordinates are WORLD px; Iso.to_ground() converts to ground px.

const FIRST_BIT := 12
const LAST_BIT := 32
const DEFAULT_PATH := "res://data/traetoppen/traetoppen.json"
const WALK_POINTS := 64
const KEEPOUT_POINTS := 16
const PAD_OVERLAP := 2.0
const DEFAULT_BODY_RADIUS := 25.0
## ry / rx of every ground circle drawn in the sketch (parsed: 0.5770 - 0.5776, the project's 36 degree camera family).
const SKETCH_SQUASH := 0.5776
## Edge of the cells of the lookup grid level_at uses to find the few levels near a point (world px).
const GRID_CELL := 256.0

static var last_error: String = ""

var data: Dictionary = {}
var scale: float = 3.0
var body_radius: float = DEFAULT_BODY_RADIUS
var bounds: Rect2 = Rect2()
var levels: Array[Level] = []             # platforms then bridges, in file order
var platforms: Array[Level] = []
var bridges: Array[Level] = []
var stubs: Array[Dictionary] = []         # {id, level, path, width, sag, exit, polygon}
var ladders: Array[Dictionary] = []       # {id, from, to, bottom, top, width, seconds, prompt}
var climb_zones: Array[Dictionary] = []   # {id, from, to, a, b, r, seconds, perk, prompt}
var lifts: Array[Dictionary] = []         # {id, level, top, basket, stand, to_area, spawn, seconds, prompt}
var spawns: Dictionary = {}               # name -> world Vector2
var landmarks: Array[Dictionary] = []     # {n, id, name_key, level, centre, r}
var landings: Dictionary = {}             # platform id -> Array[Dictionary] (see _add_landing)
var notes: Array[String] = []             # data problems met while building (the validator reports the same and more)

## Polygon tests (Level.contains calls) since the registry was built: a load-independent measure of what level_at costs.
var contains_calls: int = 0

var _by_id: Dictionary = {}
# Connected mouths per level: avoid scanning every bridge for every moving actor.
var _draw_joins: Dictionary = {}
var _scan: Array[Level] = []              # bridges first (priority 1), then platforms
var _grid: Dictionary = {}                # Vector2i cell (GRID_CELL px) -> the levels whose bounding box touches it, in scan order


# ------------------------------------------------------------------ construction

## Reads and parses a JSON file; {} on any problem (last_error says why, no engine message).
static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "%s does not exist" % path
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		last_error = "%s is not a JSON object" % path
		return {}
	return parsed as Dictionary


static func from_file(path: String = DEFAULT_PATH) -> LevelRegistry:
	return from_dict(load_data(path))


static func from_dict(d: Dictionary) -> LevelRegistry:
	var r := LevelRegistry.new()
	r._build(d)
	return r


func _build(d: Dictionary) -> void:
	data = d
	scale = maxf(LuaData.num(d.get("scale", 3.0), 3.0), 0.0001)
	body_radius = LuaData.num(d.get("body_radius", DEFAULT_BODY_RADIUS), DEFAULT_BODY_RADIUS)
	var b: Array = LuaData.arr(d.get("bounds", []))
	if b.size() >= 4:
		bounds = Rect2(Vector2(LuaData.num(b[0]), LuaData.num(b[1])) * scale, Vector2(LuaData.num(b[2]), LuaData.num(b[3])) * scale)
	var used_bits: Dictionary = {}
	var next_bit: int = FIRST_BIT
	# 1. platforms
	for rec in LuaData.arr(d.get("levels", [])):
		if not (rec is Dictionary):
			continue
		var r: Dictionary = rec
		var lv := Level.new()
		lv.id = StringName(str(r.get("id", "")))
		lv.kind = &"platform"
		lv.rank = LuaData.int_of(r.get("rank", 0))
		lv.tree = StringName(str(r.get("tree", "")))
		lv.painted_z = LuaData.num(r.get("z", 0.0))
		lv.centre = _w(r.get("centre", [0, 0]))
		lv.rx = LuaData.num(r.get("rx", 0.0)) * scale
		lv.ry = LuaData.num(r.get("ry", 0.0)) * scale
		lv.rim = LuaData.num(r.get("rim", d.get("rim", 0.0))) * scale
		lv.inset = LuaData.num(LuaData.dict(r.get("walk", {})).get("inset", 1.0), 1.0)
		next_bit = _alloc_bit(lv, r, used_bits, next_bit)
		levels.append(lv)
		platforms.append(lv)
		_by_id[lv.id] = lv
	for rec in LuaData.arr(d.get("levels", [])):
		if rec is Dictionary:
			_build_walk(rec as Dictionary)
	# 2. bridges (need the platforms: tuck order, rim crossings, landing pads)
	for rec in LuaData.arr(d.get("bridges", [])):
		if not (rec is Dictionary):
			continue
		var br: Dictionary = rec
		var lv := Level.new()
		lv.id = StringName(str(br.get("id", "")))
		lv.kind = &"bridge"
		lv.priority = 1
		lv.rank = LuaData.int_of(br.get("rank", 0))
		next_bit = _alloc_bit(lv, br, used_bits, next_bit)
		_build_bridge(lv, br)
		levels.append(lv)
		bridges.append(lv)
		_by_id[lv.id] = lv
	# 3. stubs, ladders, climb zones, lifts, spawns, landmarks
	for rec in LuaData.arr(d.get("levels", [])):
		if rec is Dictionary:
			for s in LuaData.arr((rec as Dictionary).get("stubs", [])):
				if s is Dictionary:
					_build_stub(StringName(str((rec as Dictionary).get("id", ""))), s as Dictionary)
	for rec in LuaData.arr(d.get("ladders", [])):
		if rec is Dictionary:
			_build_ladder(rec as Dictionary)
	for rec in LuaData.arr(d.get("climb_zones", [])):
		if rec is Dictionary:
			var z: Dictionary = rec
			climb_zones.append({
				"id": StringName(str(z.get("id", ""))), "from": StringName(str(z.get("from", ""))), "to": StringName(str(z.get("to", ""))),
				"a": _w(z.get("a", [0, 0])), "b": _w(z.get("b", [0, 0])), "r": LuaData.num(z.get("r", 60.0)) * scale,
				"seconds": LuaData.num(z.get("seconds", 1.1), 1.1), "perk": str(z.get("perk", "climb_speed_mult")),
				"prompt": str(z.get("prompt", "LEVEL_PROMPT_CLIMB")),
			})
	for rec in LuaData.arr(d.get("lifts", [])):
		if rec is Dictionary:
			var f: Dictionary = rec
			lifts.append({
				"id": StringName(str(f.get("id", ""))), "level": StringName(str(f.get("level", ""))), "top": _w(f.get("top", [0, 0])),
				"basket": _w(f.get("basket", [0, 0])), "stand": _w(f.get("stand", f.get("top", [0, 0]))),
				"to_area": StringName(str(f.get("to_area", ""))), "spawn": StringName(str(f.get("spawn", "default"))),
				"seconds": LuaData.num(f.get("seconds", 1.6), 1.6), "prompt": str(f.get("prompt", "LEVEL_PROMPT_LIFT")),
			})
	var sp: Dictionary = LuaData.dict(d.get("spawns", {}))
	for k in sp:
		spawns[str(k)] = _w(sp[k])
	for rec in LuaData.arr(d.get("landmarks", [])):
		if rec is Dictionary:
			var m: Dictionary = rec
			var c: Array = LuaData.arr(m.get("circle", [0, 0, 0]))
			landmarks.append({
				"n": LuaData.int_of(m.get("n", 0)), "id": StringName(str(m.get("id", ""))), "name_key": str(m.get("name_key", "")),
				"level": StringName(str(m.get("level", ""))),
				"centre": Vector2(LuaData.num(c[0]), LuaData.num(c[1])) * scale if c.size() >= 2 else Vector2.ZERO,
				"r": LuaData.num(c[2]) * scale if c.size() >= 3 else 0.0,
			})
	_draw_joins.clear()
	for lv in levels:
		_draw_joins[lv] = []
	for bridge in bridges:
		for end in 2:
			var platform := get_level(bridge.from_id if end == 0 else bridge.to_id)
			if platform == null: continue
			var join := {"bridge": bridge, "platform": platform, "end": end}
			_draw_joins[bridge].append(join)
			_draw_joins[platform].append(join)
	# 4. finalise: bounding boxes, scan order
	for lv in levels:
		lv.finalize()
	_scan.clear()
	_scan.append_array(bridges)
	_scan.append_array(platforms)
	_grid.clear()
	for lv in _scan:
		if lv.bounds.size == Vector2.ZERO:
			continue
		for cx in range(floori(lv.bounds.position.x / GRID_CELL), floori(lv.bounds.end.x / GRID_CELL) + 1):
			for cy in range(floori(lv.bounds.position.y / GRID_CELL), floori(lv.bounds.end.y / GRID_CELL) + 1):
				var key := Vector2i(cx, cy)
				if not _grid.has(key):
					_grid[key] = [] as Array
				(_grid[key] as Array).append(lv)


func _alloc_bit(lv: Level, rec: Dictionary, used: Dictionary, next_bit: int) -> int:
	var want: int = LuaData.int_of(rec.get("bit", 0))
	if want >= FIRST_BIT and want <= LAST_BIT and not used.has(want):
		lv.bit = want
		used[want] = true
		return maxi(next_bit, want + 1)
	var b: int = next_bit
	while used.has(b) and b <= LAST_BIT:
		b += 1
	if want != 0:
		notes.append("level %s: bit %d is taken or out of %d..%d, allocated %d" % [lv.id, want, FIRST_BIT, LAST_BIT, b])
	lv.bit = b
	used[b] = true
	return b + 1


# ------------------------------------------------------------------ geometry (static helpers, also used by the builders)

## sketch point [x, y] -> world px
func _w(p: Variant) -> Vector2:
	var a: Array = LuaData.arr(p)
	if a.size() < 2:
		return Vector2.ZERO
	return Vector2(LuaData.num(a[0]), LuaData.num(a[1])) * scale


## `n` points of an ellipse, counter-clockwise on screen order (angle 0 = east, y down).
static func ellipse_points(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## The point of an ellipse (parameter angle `a`).
static func ellipse_point(c: Vector2, rx: float, ry: float, a: float) -> Vector2:
	return c + Vector2(cos(a) * rx, sin(a) * ry)


## The ellipse parameter angle of a point (the angle the railing gaps are measured in).
static func ellipse_angle(c: Vector2, rx: float, ry: float, p: Vector2) -> float:
	return atan2((p.y - c.y) / ry, (p.x - c.x) / rx)


## Where the ray from `from` along the unit vector `dir` leaves the ellipse (parameter t >= 0, 0 when `from` is outside).
static func ray_leaves_ellipse(from: Vector2, dir: Vector2, c: Vector2, rx: float, ry: float) -> float:
	var o: Vector2 = (from - c) / Vector2(rx, ry)
	var v: Vector2 = dir / Vector2(rx, ry)
	var a: float = v.dot(v)
	var b: float = 2.0 * o.dot(v)
	var cc: float = o.dot(o) - 1.0
	if a <= 0.0000001 or cc > 0.0:
		return 0.0
	var disc: float = b * b - 4.0 * a * cc
	if disc < 0.0:
		return 0.0
	return (-b + sqrt(disc)) / (2.0 * a)


## The strip polygon of a straight or bent centre line (butt ends); empty when the line is shorter than 1 px.
static func strip_polygon(line: PackedVector2Array, width: float) -> PackedVector2Array:
	if line.size() < 2 or line[0].distance_to(line[line.size() - 1]) < 1.0:
		return PackedVector2Array()
	var res: Array = Geometry2D.offset_polyline(line, width * 0.5, Geometry2D.JOIN_MITER, Geometry2D.END_BUTT)
	if res.is_empty():
		return PackedVector2Array()
	return res[0] as PackedVector2Array


# ------------------------------------------------------------------ platforms

func _build_walk(rec: Dictionary) -> void:
	var lv: Level = _by_id.get(StringName(str(rec.get("id", ""))), null)
	if lv == null:
		return
	var walk: Dictionary = LuaData.dict(rec.get("walk", {}))
	var outers: Array[PackedVector2Array] = [ellipse_points(lv.centre, lv.rx * lv.inset, lv.ry * lv.inset, WALK_POINTS)]
	var holes_out: Array[PackedVector2Array] = []
	for ko in LuaData.arr(walk.get("keepout", [])):
		if not (ko is Dictionary):
			continue
		var res: Dictionary = _resolve_keepout(lv, rec, ko as Dictionary)
		if res.is_empty():
			continue
		lv.keepouts.append(res)
		var poly: PackedVector2Array = res["polygon"]
		var next: Array[PackedVector2Array] = []
		for o in outers:
			for piece in Geometry2D.clip_polygons(o, poly):
				if Geometry2D.is_polygon_clockwise(piece):
					holes_out.append(piece)
				else:
					next.append(piece)
		outers = next
	lv.regions = outers
	lv.holes = holes_out


## One keep-out of a platform: {ref, kind, polygon, c, rx, ry, collide}. `ellipse` entries are circles / ellipses drawn on the ground
## (trunk, hut wall, prop footprint); the Upper deck's shadow is the hull of its ellipse and the same ellipse shifted down by the rim.
func _resolve_keepout(lv: Level, rec: Dictionary, ko: Dictionary) -> Dictionary:
	if ko.has("circle"):
		var tr: Dictionary = LuaData.dict(rec.get("trunk", {}))
		var rx: float = LuaData.num(tr.get("rx", 0.0)) * scale
		var ry: float = LuaData.num(tr.get("ry", rx / scale * SKETCH_SQUASH)) * scale
		return _ellipse_keepout("circle:%s" % str(ko["circle"]), lv.centre, rx, ry)
	if ko.has("hut"):
		var b: Dictionary = _record("buildings", str(ko["hut"]))
		if b.is_empty():
			notes.append("level %s: keep-out hut %s does not exist" % [lv.id, ko["hut"]])
			return {}
		var wr: float = LuaData.num(b.get("wall_r", 0.0)) * scale
		return _ellipse_keepout("hut:%s" % str(ko["hut"]), _w([b.get("cx", 0), b.get("base_y", 0)]), wr, wr * SKETCH_SQUASH)
	if ko.has("prop"):
		var p: Dictionary = _record("props", str(ko["prop"]))
		if p.is_empty():
			notes.append("level %s: keep-out prop %s does not exist" % [lv.id, ko["prop"]])
			return {}
		var keep: Array = LuaData.arr(p.get("keep", [10, 6]))
		if keep.size() < 2:
			keep = [10, 6]
		return _ellipse_keepout("prop:%s" % str(ko["prop"]), _w(p.get("at", [0, 0])), LuaData.num(keep[0]) * scale, LuaData.num(keep[1]) * scale)
	if ko.has("ellipse"):
		var name: String = str(ko["ellipse"])
		if name.ends_with("_deck_shadow"):
			var other: Level = _by_id.get(StringName(name.trim_suffix("_deck_shadow")), null)
			if other == null:
				notes.append("level %s: keep-out %s names an unknown level" % [lv.id, name])
				return {}
			var pts := PackedVector2Array()
			pts.append_array(ellipse_points(other.centre, other.rx, other.ry, 48))
			pts.append_array(ellipse_points(other.centre + Vector2(0, other.rim), other.rx, other.ry, 48))
			var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
			if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
				hull.remove_at(hull.size() - 1)
			return {"ref": "ellipse:%s" % name, "kind": &"hull", "polygon": hull, "c": other.centre, "rx": other.rx, "ry": other.ry, "collide": true}
	notes.append("level %s: unknown keep-out %s" % [lv.id, ko])
	return {}


func _ellipse_keepout(ref: String, c: Vector2, rx: float, ry: float) -> Dictionary:
	return {"ref": ref, "kind": &"ellipse", "polygon": ellipse_points(c, rx, ry, KEEPOUT_POINTS), "c": c, "rx": rx, "ry": ry, "collide": true}


func _record(list_key: String, id: String) -> Dictionary:
	for rec in LuaData.arr(data.get(list_key, [])):
		if rec is Dictionary and str((rec as Dictionary).get("id", "")) == id:
			return rec as Dictionary
	return {}


# ------------------------------------------------------------------ bridges, stubs, ladders

func _build_bridge(lv: Level, rec: Dictionary) -> void:
	lv.from_id = StringName(str(rec.get("from", "")))
	lv.to_id = StringName(str(rec.get("to", "")))
	lv.width = LuaData.num(rec.get("width", 28.0)) * scale
	lv.sag = LuaData.num(rec.get("sag", 0.0)) * scale
	var path := PackedVector2Array()
	for p in LuaData.arr(rec.get("path", [])):
		path.append(_w(p))
	lv.path = path
	if path.size() < 2:
		notes.append("bridge %s: a path needs two points" % lv.id)
		return
	var end_ids: Array[StringName] = [lv.from_id, lv.to_id]
	var ends_pt: Array[Vector2] = [path[0], path[path.size() - 1]]
	var outward: Array[Vector2] = [(path[1] - path[0]).normalized(), (path[path.size() - 2] - path[path.size() - 1]).normalized()]
	var gates: Array[Vector2] = [ends_pt[0], ends_pt[1]]
	for i in 2:
		var pl: Level = _by_id.get(end_ids[i], null)
		if pl == null or pl.kind != &"platform":
			notes.append("bridge %s: end %d has no platform %s" % [lv.id, i, end_ids[i]])
			lv.ends.append(&"over")
			lv.rim_points.append(ends_pt[i])
			continue
		var t_rim: float = ray_leaves_ellipse(ends_pt[i], outward[i], pl.centre, pl.rx, pl.ry)
		var rim_pt: Vector2 = ends_pt[i] + outward[i] * t_rim
		lv.rim_points.append(rim_pt)
		var under: bool = lv.rank < pl.rank
		lv.ends.append(&"under" if under else &"over")
		if under:
			gates[i] = rim_pt + outward[i] * body_radius          # the gate: one body radius before the tuck-in line
		# the platform's landing pad: from the gate (or the rim of an `over` end) to just past the path end
		var p_out: Vector2 = (gates[i] if under else rim_pt) + outward[i] * PAD_OVERLAP
		var p_in: Vector2 = ends_pt[i] - outward[i] * PAD_OVERLAP
		var pad: PackedVector2Array = strip_polygon(PackedVector2Array([p_out, p_in]), lv.width)
		if not pad.is_empty():
			pl.pads.append(pad)
		_add_landing(pl, {
			"id": lv.id, "kind": &"bridge", "under": under, "point": rim_pt, "dir": outward[i], "width": lv.width,
			"end": ends_pt[i], "gate": gates[i],
		})
	var line := PackedVector2Array()
	line.append(gates[0])
	for k in range(1, path.size() - 1):
		line.append(path[k])
	line.append(gates[1])
	lv.gate_path = line
	var poly: PackedVector2Array = strip_polygon(line, lv.width)
	var strip_regions: Array[PackedVector2Array] = []
	if not poly.is_empty():
		strip_regions.append(poly)
	lv.regions = strip_regions
	lv.centre = (gates[0] + gates[1]) * 0.5


func _build_stub(level_id: StringName, s: Dictionary) -> void:
	var pl: Level = _by_id.get(level_id, null)
	if pl == null:
		return
	var path := PackedVector2Array()
	for p in LuaData.arr(s.get("path", [])):
		path.append(_w(p))
	if path.size() < 2:
		notes.append("stub %s: a path needs two points" % s.get("id", ""))
		return
	var width: float = LuaData.num(s.get("width", 44.0)) * scale
	var poly: PackedVector2Array = strip_polygon(path, width)
	if poly.is_empty():
		return
	pl.pads.append(poly)
	var dir: Vector2 = (path[1] - path[0]).normalized()
	var t_rim: float = ray_leaves_ellipse(path[0], dir, pl.centre, pl.rx, pl.ry)
	var rim_pt: Vector2 = path[0] + dir * t_rim
	# the stub's rails start where its centre line crosses the walk ring of the platform: that is the gate the Railing's wings meet
	var t_ring: float = ray_leaves_ellipse(path[0], dir, pl.centre, pl.rx * pl.inset, pl.ry * pl.inset)
	_add_landing(pl, {"id": StringName(str(s.get("id", ""))), "kind": &"stub", "under": false, "point": rim_pt, "dir": dir, "width": width, "end": path[0], "gate": path[0] + dir * t_ring})
	var ex: Dictionary = LuaData.dict(s.get("exit", {}))
	stubs.append({
		"id": StringName(str(s.get("id", ""))), "level": level_id, "path": path, "width": width, "sag": LuaData.num(s.get("sag", 0.0)) * scale,
		"exit": {"area": StringName(str(ex.get("area", ""))), "spawn": StringName(str(ex.get("spawn", "default"))), "label": str(ex.get("label", ""))},
		"polygon": poly,
	})


func _build_ladder(l: Dictionary) -> void:
	var lane: Array = LuaData.arr(l.get("lane", []))
	if lane.size() < 2:
		return
	var rec := {
		"id": StringName(str(l.get("id", ""))), "from": StringName(str(l.get("from", ""))), "to": StringName(str(l.get("to", ""))),
		"bottom": _w(lane[0]), "top": _w(lane[1]), "width": LuaData.num(l.get("width", 20.0)) * scale,
		"seconds": LuaData.num(l.get("seconds", 1.1), 1.1), "prompt": str(l.get("prompt", "LEVEL_PROMPT_CLIMB")),
		"rungs": LuaData.int_of(l.get("rungs", 9)),
	}
	ladders.append(rec)
	# the lane crosses the rim ring of the level it climbs onto: a railing gap there (and a gap in the Torvet's shadow arc, see Railing)
	var to_l: Level = _by_id.get(rec["to"], null)
	if to_l != null and to_l.kind == &"platform":
		var dir: Vector2 = ((rec["bottom"] as Vector2) - (rec["top"] as Vector2)).normalized()
		var t_walk: float = ray_leaves_ellipse(rec["top"], dir, to_l.centre, to_l.rx * to_l.inset, to_l.ry * to_l.inset)
		var hit: Vector2 = (rec["top"] as Vector2) + dir * t_walk
		_add_landing(to_l, {"id": rec["id"], "kind": &"ladder", "under": false, "point": hit, "dir": dir, "width": rec["width"], "end": rec["top"], "gate": hit})


## A landing of a platform: where a bridge end / stub / ladder crosses its rim. `point` lies on the ellipse (the full one for bridges
## and stubs, the walk ellipse for ladders), `dir` points away from the disc along the line, `gate` is where the strip starts.
func _add_landing(pl: Level, rec: Dictionary) -> void:
	var a: float = ellipse_angle(pl.centre, pl.rx, pl.ry, rec["point"])
	rec["angle"] = a
	rec["half_angle"] = (rec["width"] as float) * 0.5 / maxf(pl.rx, 1.0)
	if not landings.has(pl.id):
		var fresh: Array[Dictionary] = []
		landings[pl.id] = fresh
	(landings[pl.id] as Array).append(rec)


# ------------------------------------------------------------------ queries

func get_level(id: StringName) -> Level:
	return _by_id.get(id, null)


func has_level(id: StringName) -> bool:
	return _by_id.has(id)


func landings_of(id: StringName) -> Array:
	return (landings.get(id, []) as Array).duplicate(true)


## The level that holds a world position, or null. A function of the position only: bridges (priority 1) before platforms, the platforms are
## disjoint. Null in the void between decks and inside keep-outs.
func level_at(pos: Vector2) -> Level:
	var near: Variant = _grid.get(Vector2i(floori(pos.x / GRID_CELL), floori(pos.y / GRID_CELL)), null)
	if near == null:
		return null
	for lv in near as Array:
		if lv.bounds.has_point(pos):
			contains_calls += 1
			if lv.contains(pos):
				return lv
	return null


## Join surfaces overlap in the painting. Promote the actor BEFORE its feet
## change collision levels, so the next deck cannot cut through its head/body.
## Only connected bridge mouths participate; crossing bridges stay separate.
func draw_rank(pos: Vector2, level: Level) -> int:
	var rank := level.rank
	const CLEARANCE := 176.0
	for join: Dictionary in _draw_joins.get(level, []):
		var bridge: Level = join.bridge
		var platform: Level = join.platform
		var end: int = join.end
		var mouth: Vector2 = bridge.gate_path[0 if end == 0 else bridge.gate_path.size()-1]
		var inside: Vector2 = bridge.path[0 if end == 0 else bridge.path.size()-1]
		var closest := Geometry2D.get_closest_point_to_segment(pos, mouth, inside)
		if pos.distance_squared_to(closest) <= CLEARANCE * CLEARANCE:
			rank = maxi(rank, maxi(platform.rank, bridge.rank))
	return rank


## A body-sized clear landing for testing/teleports, never inside a planter,
## hut or railing. Prefer the front walkway, then try the other open arcs.
func safe_point(id: StringName) -> Variant:
	var level := get_level(id)
	if level == null or level.is_bridge(): return null
	for radius in [0.72, 0.55, 0.84]:
		for degrees in [90, 60, 120, 30, 150, 0, 180, 210, 330, 240, 300, 270]:
			var angle := deg_to_rad(float(degrees))
			var at: Vector2 = level.centre + Vector2(cos(angle)*level.rx, sin(angle)*level.ry)*float(radius)
			var clear := level_id_at(at) == id
			for edge in 8:
				var offset := Vector2.from_angle(TAU*edge/8.0)*body_radius*1.1
				clear = clear and level_id_at(at+offset) == id
			if clear: return at
	return null


## The id of the level at a position, &"" when there is none.
func level_id_at(pos: Vector2) -> StringName:
	var lv: Level = level_at(pos)
	return lv.id if lv != null else &""


## A stub or ladder record by id ({} when unknown).
func get_stub(id: StringName) -> Dictionary:
	for s in stubs:
		if s["id"] == id:
			return s
	return {}


func get_ladder(id: StringName) -> Dictionary:
	for l in ladders:
		if l["id"] == id:
			return l
	return {}


func get_lift(id: StringName) -> Dictionary:
	for f in lifts:
		if f["id"] == id:
			return f
	return {}


## Length of a bridge's centre line in GROUND px (the unit of speeds and the design's walking-time table).
func ground_length(lv: Level) -> float:
	var total: float = 0.0
	for i in range(1, lv.path.size()):
		total += Iso.to_ground(lv.path[i] - lv.path[i - 1]).length()
	return total


# ------------------------------------------------------------------ the planner's read-only view (RT21)

## The level graph LevelNav (towns track) plans over, instead of the sketch JSON. WORLD px; `squash` converts to ground px (y / squash).
##   levels   [{id, kind: "platform", rank, bit, centre, rx, ry, rim, polygons: [outer...], holes: [hole...], keepouts: [{ref, polygon}],
##              landings: [{id, kind, point, dir, width, gate, end}]}]            walkable region = polygons minus holes (pads included in polygons)
##   bridges  [{id, from, to, rank, bit, width, a, b, gate_a, gate_b, ends: ["over"|"under", ...], length, polygon}]
##            a / b are the authored path ends (on the platforms), gate_a / gate_b the ends of the strip; length in ground px
##   stubs    [{id, level, a, b, width, exit: {area, spawn}}]       ladders [{id, from, to, bottom, top, width, seconds}]
##   lifts    [{id, level, top, basket, stand, to_area, spawn, seconds}]      climb_zones [{id, from, to, a, b, r, seconds}]
##   spawns   {name: world position}
## The dictionary is a copy: changing it never changes the area.
func levels_graph() -> Dictionary:
	var lv_out: Array = []
	for lv in platforms:
		var polys: Array = []
		for p in lv.regions:
			polys.append(p)
		for p in lv.pads:
			polys.append(p)
		var ko: Array = []
		for k in lv.keepouts:
			ko.append({"ref": k["ref"], "polygon": k["polygon"]})
		lv_out.append({
			"id": lv.id, "kind": lv.kind, "rank": lv.rank, "bit": lv.bit, "centre": lv.centre, "rx": lv.rx, "ry": lv.ry, "rim": lv.rim,
			"polygons": polys, "holes": lv.holes.duplicate(), "keepouts": ko, "landings": landings_of(lv.id),
		})
	var br_out: Array = []
	for lv in bridges:
		br_out.append({
			"id": lv.id, "from": lv.from_id, "to": lv.to_id, "rank": lv.rank, "bit": lv.bit, "width": lv.width,
			"a": lv.path[0] if not lv.path.is_empty() else Vector2.ZERO, "b": lv.path[lv.path.size() - 1] if not lv.path.is_empty() else Vector2.ZERO,
			"gate_a": lv.gate_path[0] if not lv.gate_path.is_empty() else Vector2.ZERO,
			"gate_b": lv.gate_path[lv.gate_path.size() - 1] if not lv.gate_path.is_empty() else Vector2.ZERO,
			"ends": lv.ends.duplicate(), "length": ground_length(lv), "polygon": lv.regions[0] if not lv.regions.is_empty() else PackedVector2Array(),
		})
	var st_out: Array = []
	for s in stubs:
		st_out.append({"id": s["id"], "level": s["level"], "a": (s["path"] as PackedVector2Array)[0], "b": (s["path"] as PackedVector2Array)[(s["path"] as PackedVector2Array).size() - 1], "width": s["width"], "exit": (s["exit"] as Dictionary).duplicate()})
	return {
		"scale": scale, "squash": Iso.squash(), "body_radius": body_radius, "bounds": bounds,
		"levels": lv_out, "bridges": br_out, "stubs": st_out, "ladders": ladders.duplicate(true), "lifts": lifts.duplicate(true),
		"climb_zones": climb_zones.duplicate(true), "spawns": spawns.duplicate(),
	}


## levels_graph() of the shipped data/traetoppen/traetoppen.json (what the planner calls without owning a registry).
static func shipped_graph() -> Dictionary:
	return from_file().levels_graph()
