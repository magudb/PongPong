class_name LevelRules
extends RefCounted
## The validator of the levelled city data (data/traetoppen/traetoppen.json): a PURE function, LevelRules.validate(data) -> Array[String]
## (empty = valid). Package V3-levels ships it; the city map (V4) and the art / life packages call it at their own gates.
## Every problem string starts with its rule id, so a test can assert WHICH rule caught a mutant:
##   R1 structure    scale, bounds, ids unique, and the SHAPE of every record the rules and the builder read: lists are lists of objects,
##                   points are [x, y] of finite numbers, radii / widths / times are numbers > 0, decor ranks are numbers, the header keys
##                   (body_radius <= BODY_RADIUS_MAX, zoom, canopy) are what the registry reads, coordinates stay within +-COORD_MAX sketch px
##                   (a garbage document is answered with R1 problems and nothing else: the geometry rules below only ever see vetted shapes)
##   R2 ranks        every level and bridge rank is a multiple of 10 and unique; decor ranks are unique and never equal a level rank
##   R3 bits         physics layers unique and inside LevelRegistry.FIRST_BIT .. LAST_BIT
##   R4 bridge ends  both ends name a platform, the platforms differ, each end point lies inside its platform's full ellipse, the strip of the
##                   bridge is not empty
##   R5 tuck order   a bridge painted BEFORE a platform (lower rank) is covered by that platform's rim at that end ("under"), one painted
##                   after lies "over" it; the declared `ends` of every bridge must say what the ranks say
##   R6 ladders      from / to are platforms, the lane starts on the walk region of `from` and ends on that of `to`
##   R7 lifts        the level exists and the stand point is walkable on it; climb zones join two platforms and start / end on them
##   R8 spawns       default, from_farm, from_hyggebyen, from_skovlift exist and every spawn is on a level
##   R9 landmarks    every landmark circle has its centre inside the level it names
##   R10 references  keep-outs, huts, props and lamps name things that exist; each building stands on the level it names
##   R11 lights      at most 12 PointLight2D (the rest are additive halos)
##   R12 disjoint    the walk regions of the platforms never overlap on screen (the one overlap, Torvet x Upper, is cut out by a keep-out)
## The geometry comes from LevelRegistry, the same objects the builder collides with. Whatever the input, validate() raises no engine error:
## a wrong type is a problem string, never a script error that would return the empty (= "valid") list.

const MAX_POINT_LIGHTS := 12
const DISJOINT_STEP := 72.0
## The sketch is 1800 x 1240 px; anything beyond this magnitude (or a scale beyond SCALE_MAX) is garbage and would make the registry's grid and
## R12's sampling run for ever.
const COORD_MAX := 10000.0
const SCALE_MAX := 20.0
const MAX_SAMPLES := 60000
## A body radius beyond this (world px; the figures' is 25) would make the strips and landing pads of the registry as large as the whole city.
const BODY_RADIUS_MAX := 500.0
## list-valued keys of the document whose entries are objects (the shape rules below say what each entry must carry)
const OBJECT_LISTS := ["ladders", "climb_zones", "lifts", "buildings", "lanterns", "door_lamps", "props", "lights", "landmarks",
	"trunks", "owl_holes", "bat_houses", "foliage", "markers"]


static func validate(data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	# ---- R1 structure
	var levels: Array = _list(out, data, "levels")
	var bridges: Array = _list(out, data, "bridges")
	var scale_v: Variant = data.get("scale", 0.0)
	if not _is_num(scale_v) or float(scale_v) <= 0.0 or float(scale_v) > SCALE_MAX:
		out.append("R1 structure: scale must be a number in (0, %d]" % int(SCALE_MAX))
	_check_bounds(out, data)
	_check_header(out, data)
	if levels.is_empty():
		out.append("R1 structure: no levels")
	var ids: Dictionary = {}
	var platform_rec: Dictionary = {}
	for rec in levels:
		if not (rec is Dictionary):
			out.append("R1 structure: a level entry is not an object")
			continue
		var id: String = str((rec as Dictionary).get("id", ""))
		if id == "" or ids.has(id):
			out.append("R1 structure: level id '%s' is empty or used twice" % id)
		ids[id] = true
		platform_rec[id] = rec
		for k in ["rank", "centre", "rx", "ry"]:
			if not (rec as Dictionary).has(k):
				out.append("R1 structure: level %s has no %s" % [id, k])
		_check_level(out, id, rec as Dictionary)
	var bridge_rec: Dictionary = {}
	for rec in bridges:
		if not (rec is Dictionary):
			out.append("R1 structure: a bridge entry is not an object")
			continue
		var id: String = str((rec as Dictionary).get("id", ""))
		if id == "" or ids.has(id):
			out.append("R1 structure: bridge id '%s' is empty or used twice" % id)
		ids[id] = true
		bridge_rec[id] = rec
		_check_bridge(out, id, rec as Dictionary)
	for key in OBJECT_LISTS:
		_check_object_list(out, data, key)
	_check_spawns(out, data)
	var decor_v: Variant = data.get("decor_ranks", {})
	if not (decor_v is Dictionary) and not (decor_v is Array and (decor_v as Array).is_empty()):      # an empty Lua table may arrive as []
		out.append("R1 structure: decor_ranks must be an object")
	elif decor_v is Dictionary:
		for k in decor_v as Dictionary:
			if not _is_coord((decor_v as Dictionary)[k]):
				out.append("R1 structure: decor_ranks.%s must be a number" % str(k))
	if not out.is_empty():
		return out                                   # a document of the wrong shape: the geometry rules would read garbage
	# ---- R2 ranks
	var ranks: Dictionary = {}
	for id in platform_rec:
		_check_rank(out, ranks, id, (platform_rec[id] as Dictionary).get("rank", null))
	for id in bridge_rec:
		_check_rank(out, ranks, id, (bridge_rec[id] as Dictionary).get("rank", null))
	var decor: Dictionary = LuaData.dict(data.get("decor_ranks", {}))
	var seen_decor: Dictionary = {}
	for k in decor:
		var v: int = LuaData.int_of(decor[k])
		if ranks.has(v):
			out.append("R2 ranks: decor rank %s = %d equals the rank of level %s" % [k, v, ranks[v]])
		if seen_decor.has(v):
			out.append("R2 ranks: decor ranks %s and %s are both %d" % [k, seen_decor[v], v])
		seen_decor[v] = k
	# ---- R3 bits
	var bits: Dictionary = {}
	for rec in levels + bridges:
		var id: String = str((rec as Dictionary).get("id", ""))
		var bit: int = LuaData.int_of((rec as Dictionary).get("bit", 0))
		if bit < LevelRegistry.FIRST_BIT or bit > LevelRegistry.LAST_BIT:
			out.append("R3 bits: %s uses physics layer %d, outside %d..%d" % [id, bit, LevelRegistry.FIRST_BIT, LevelRegistry.LAST_BIT])
		elif bits.has(bit):
			out.append("R3 bits: %s and %s share physics layer %d" % [id, bits[bit], bit])
		bits[bit] = id
	var reg: LevelRegistry = LevelRegistry.from_dict(data)
	# ---- R4 / R5 bridge ends and tuck order
	for id in bridge_rec:
		var rec: Dictionary = bridge_rec[id]
		var frm: String = str(rec.get("from", ""))
		var to: String = str(rec.get("to", ""))
		var path: Array = LuaData.arr(rec.get("path", []))
		if path.size() < 2:
			continue
		var pts: Array = [path[0], path[path.size() - 1]]
		var declared: Array = LuaData.arr(rec.get("ends", []))
		var rank: int = LuaData.int_of(rec.get("rank", 0))
		if frm == to:
			out.append("R4 bridge ends: bridge %s joins %s to itself" % [id, frm])
		var strip: Level = reg.get_level(StringName(str(id)))
		if strip != null and strip.regions.is_empty():
			out.append("R4 bridge ends: bridge %s has an empty strip (a path shorter than 1 px)" % id)
		for i in 2:
			var pid: String = frm if i == 0 else to
			if not platform_rec.has(pid):
				out.append("R4 bridge ends: bridge %s end %d names the unknown platform '%s'" % [id, i, pid])
				continue
			var pl: Dictionary = platform_rec[pid]
			var c: Vector2 = _vec(pl.get("centre", null))
			var p: Vector2 = _vec(pts[i])
			var nr: float = Vector2((p.x - c.x) / maxf(LuaData.num(pl.get("rx", 1.0)), 0.001), (p.y - c.y) / maxf(LuaData.num(pl.get("ry", 1.0)), 0.001)).length()
			if nr >= 1.0:
				out.append("R4 bridge ends: bridge %s end %d is outside platform %s (normalised radius %.3f)" % [id, i, pid, nr])
			var derived: String = "over" if rank > LuaData.int_of(pl.get("rank", 0)) else "under"
			var said: String = str(declared[i]) if declared.size() > i else ""
			if said != derived:
				out.append("R5 tuck order: bridge %s (rank %d) end %d on %s (rank %d) is %s by the ranks but declared '%s'" % [id, rank, i, pid, LuaData.int_of(pl.get("rank", 0)), derived, said])
	# ---- R6 ladders
	for rec in LuaData.arr(data.get("ladders", [])):
		var l: Dictionary = rec
		var lid: String = str(l.get("id", ""))
		var lane: Array = LuaData.arr(l.get("lane", []))
		if lane.size() < 2 or not platform_rec.has(str(l.get("from", ""))) or not platform_rec.has(str(l.get("to", ""))):
			out.append("R6 ladders: ladder %s needs a lane and two platforms" % lid)
			continue
		if LuaData.num(l.get("seconds", 0.0)) <= 0.0:
			out.append("R6 ladders: ladder %s has no climbing time" % lid)
		var scale: float = LuaData.num(data.get("scale", 3.0), 3.0)
		var bottom: Vector2 = _vec(lane[0]) * scale
		var top: Vector2 = _vec(lane[1]) * scale
		var from_l: Level = reg.get_level(StringName(str(l.get("from", ""))))
		var to_l: Level = reg.get_level(StringName(str(l.get("to", ""))))
		if from_l == null or not from_l.contains(bottom):
			out.append("R6 ladders: ladder %s starts off the walk region of %s" % [lid, l.get("from", "")])
		if to_l == null or not to_l.contains(top):
			out.append("R6 ladders: ladder %s ends off the walk region of %s" % [lid, l.get("to", "")])
	# ---- R7 lifts and climb zones
	for rec in LuaData.arr(data.get("lifts", [])):
		var f: Dictionary = rec
		var lv: Level = reg.get_level(StringName(str(f.get("level", ""))))
		var rec_w: Dictionary = reg.get_lift(StringName(str(f.get("id", ""))))
		if lv == null:
			out.append("R7 lifts: lift %s names the unknown level '%s'" % [f.get("id", ""), f.get("level", "")])
		elif rec_w.is_empty() or not lv.contains(rec_w["stand"]):
			out.append("R7 lifts: the stand point of lift %s is not walkable on %s" % [f.get("id", ""), f.get("level", "")])
		if str(f.get("to_area", "")) == "":
			out.append("R7 lifts: lift %s has no target area" % [str(f.get("id", ""))])
	for z in reg.climb_zones:
		var a: Level = reg.get_level(z["from"])
		var b: Level = reg.get_level(z["to"])
		if a == null or b == null or a == b:
			out.append("R7 lifts: climb zone %s must join two different platforms" % [str(z["id"])])
		elif not a.contains(z["a"]) or not b.contains(z["b"]):
			out.append("R7 lifts: climb zone %s starts or ends off its levels" % [str(z["id"])])
	# ---- R8 spawns
	for sname in ["default", "from_farm", "from_hyggebyen", "from_skovlift"]:
		if not reg.spawns.has(sname):
			out.append("R8 spawns: spawn %s is missing" % sname)
	for sname in reg.spawns:
		if reg.level_at(reg.spawns[sname]) == null:
			out.append("R8 spawns: spawn %s at %s is on no level" % [sname, reg.spawns[sname]])
	# ---- R9 landmarks
	for lm in reg.landmarks:
		var lv: Level = reg.get_level(lm["level"])
		if lv == null:
			out.append("R9 landmarks: landmark %s names the unknown level '%s'" % [lm["id"], lm["level"]])
		elif not lv.contains_disc(lm["centre"]):
			out.append("R9 landmarks: the circle of landmark %s has its centre outside level %s" % [lm["id"], lm["level"]])
	# ---- R10 references
	for n in reg.notes:
		out.append("R10 references: %s" % n)
	var building_ids: Dictionary = {}
	for rec in LuaData.arr(data.get("buildings", [])):
		var b: Dictionary = rec
		building_ids[str(b.get("id", ""))] = true
		var lv: Level = reg.get_level(StringName(str(b.get("level", ""))))
		var centre := Vector2(LuaData.num(b.get("cx", 0.0)), LuaData.num(b.get("base_y", 0.0))) * reg.scale
		if lv == null or lv.kind != &"platform" or lv.norm_radius(centre) > 1.15:
			out.append("R10 references: building %s does not stand on level '%s'" % [b.get("id", ""), b.get("level", "")])
	for rec in LuaData.arr(data.get("door_lamps", [])):
		if not building_ids.has(str((rec as Dictionary).get("building", ""))):
			out.append("R10 references: a door lamp names the unknown building '%s'" % [str((rec as Dictionary).get("building", ""))])
	for rec in LuaData.arr(data.get("lanterns", [])) + LuaData.arr(data.get("door_lamps", [])) + LuaData.arr(data.get("props", [])):
		if not platform_rec.has(str((rec as Dictionary).get("level", ""))):
			out.append("R10 references: an element names the unknown level '%s'" % [str((rec as Dictionary).get("level", ""))])
	# ---- R11 lights
	if LuaData.arr(data.get("lights", [])).size() > MAX_POINT_LIGHTS:
		out.append("R11 lights: %d PointLight2D entries, at most %d" % [LuaData.arr(data.get("lights", [])).size(), MAX_POINT_LIGHTS])
	# ---- R12 disjoint platforms (sampled over the bounds)
	var overlap: int = _count_platform_overlaps(reg)
	if overlap > 0:
		out.append("R12 disjoint: the walk regions of the platforms overlap at %d sample points" % overlap)
	return out


# ------------------------------------------------------------------ R1: shapes

static func _is_num(v: Variant) -> bool:
	var t: int = typeof(v)
	return (t == TYPE_INT or t == TYPE_FLOAT) and is_finite(float(v))


static func _is_coord(v: Variant) -> bool:
	return _is_num(v) and absf(float(v)) <= COORD_MAX


## A radius, width or length: a number in (0, COORD_MAX].
static func _is_len(v: Variant) -> bool:
	return _is_num(v) and float(v) > 0.0 and float(v) <= COORD_MAX


static func _is_pt(v: Variant) -> bool:
	if typeof(v) != TYPE_ARRAY:
		return false
	var a: Array = v
	return a.size() == 2 and _is_coord(a[0]) and _is_coord(a[1])


static func _is_text(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME


## [x, y] of a point, (0, 0) for anything else (the shape rules reported it already).
static func _vec(v: Variant) -> Vector2:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 2:
		return Vector2(LuaData.num((v as Array)[0]), LuaData.num((v as Array)[1]))
	return Vector2.ZERO


## data[key] as an Array; a key that is present but not a list is an R1 problem.
static func _list(out: Array[String], data: Dictionary, key: String) -> Array:
	var v: Variant = data.get(key, [])
	if typeof(v) != TYPE_ARRAY:
		out.append("R1 structure: `%s` must be a list" % key)
		return []
	return v


static func _check_object_list(out: Array[String], data: Dictionary, key: String) -> void:
	var entries: Array = _list(out, data, key)
	for i in entries.size():
		var rec: Variant = entries[i]
		if not (rec is Dictionary):
			out.append("R1 structure: %s[%d] is not an object" % [key, i])
			continue
		var r: Dictionary = rec
		var who: String = "%s[%d]" % [key, i]
		match key:
			"ladders":
				_need_text(out, who, r, "from")
				_need_text(out, who, r, "to")
				var lane: Variant = r.get("lane", [])
				if typeof(lane) != TYPE_ARRAY:
					out.append("R1 structure: %s.lane must be a list of points" % who)
				else:
					for p in lane as Array:
						if not _is_pt(p):
							out.append("R1 structure: %s.lane holds a value that is not an [x, y] point" % who)
							break
				_opt_num(out, who, r, "seconds")
				_opt_len(out, who, r, "width")
			"climb_zones":
				_need_pt(out, who, r, "a")
				_need_pt(out, who, r, "b")
				_need_text(out, who, r, "from")
				_need_text(out, who, r, "to")
				_opt_len(out, who, r, "r")
				_opt_len(out, who, r, "seconds")
			"lifts":
				_need_pt(out, who, r, "top")
				_need_pt(out, who, r, "basket")
				if r.has("stand"):
					_need_pt(out, who, r, "stand")
				_opt_text(out, who, r, "level")
				_opt_text(out, who, r, "to_area")
				_opt_len(out, who, r, "seconds")
			"buildings":
				_need_num(out, who, r, "cx")
				_need_num(out, who, r, "base_y")
				_opt_len(out, who, r, "wall_r")
				_opt_num(out, who, r, "wall_h")
				_opt_text(out, who, r, "level")
				if r.has("roof"):
					if not (r["roof"] is Dictionary):
						out.append("R1 structure: %s.roof must be an object" % who)
					else:
						for k in ["h", "rx", "ry"]:
							_opt_len(out, who + ".roof", r["roof"] as Dictionary, k)
				if r.has("door"):
					if not (r["door"] is Dictionary):
						out.append("R1 structure: %s.door must be an object" % who)
					else:
						for k in ["x", "y"]:
							_opt_num(out, who + ".door", r["door"] as Dictionary, k)
			"trunks":
				for k in ["cx", "y_top", "y_bot"]:
					_need_num(out, who, r, k)
				for k in ["rx", "ry"]:
					if not _is_len(r.get(k, null)):
						out.append("R1 structure: %s.%s must be a number > 0" % [who, k])
				_opt_text(out, who, r, "level")
			"owl_holes":
				_need_pt(out, who, r, "at")
			"bat_houses":
				_need_num(out, who, r, "cx")
				_need_num(out, who, r, "y_top")
				_need_num(out, who, r, "tip_y")
				_opt_len(out, who, r, "w")
			"foliage":
				_need_pt(out, who, r, "at")
				for k in ["rx", "ry"]:
					if not _is_len(r.get(k, null)):
						out.append("R1 structure: %s.%s must be a number > 0" % [who, k])
				_opt_num(out, who, r, "alpha")
				_opt_text(out, who, r, "level")
			"markers":
				_need_text(out, who, r, "type")
				if r.has("at"):
					_need_pt(out, who, r, "at")
				_opt_text(out, who, r, "level")
			"lanterns", "door_lamps":
				_need_pt(out, who, r, "at")
				_opt_text(out, who, r, "level")
			"props":
				_need_pt(out, who, r, "at")
				if r.has("keep") and not (_is_pt(r["keep"]) and float((r["keep"] as Array)[0]) >= 0.0 and float((r["keep"] as Array)[1]) >= 0.0):
					out.append("R1 structure: %s.keep must be [rx, ry] of two numbers >= 0" % who)
				_opt_text(out, who, r, "level")
			"lights":
				_need_pt(out, who, r, "at")
				_opt_num(out, who, r, "r_px")
			"landmarks":
				var circle: Variant = r.get("circle", [])
				if typeof(circle) != TYPE_ARRAY or (circle as Array).size() != 3 or not _is_coord((circle as Array)[0]) or not _is_coord((circle as Array)[1]) or not _is_len((circle as Array)[2]):
					out.append("R1 structure: %s.circle must be [x, y, r] of numbers (r > 0)" % who)
				_opt_text(out, who, r, "level")


static func _need_pt(out: Array[String], who: String, r: Dictionary, k: String) -> void:
	if not _is_pt(r.get(k, null)):
		out.append("R1 structure: %s.%s must be an [x, y] point" % [who, k])


static func _need_num(out: Array[String], who: String, r: Dictionary, k: String) -> void:
	if not _is_coord(r.get(k, null)):
		out.append("R1 structure: %s.%s must be a number" % [who, k])


static func _need_text(out: Array[String], who: String, r: Dictionary, k: String) -> void:
	if not _is_text(r.get(k, null)):
		out.append("R1 structure: %s.%s must be a text" % [who, k])


static func _opt_num(out: Array[String], who: String, r: Dictionary, k: String) -> void:
	if r.has(k) and not _is_coord(r[k]):
		out.append("R1 structure: %s.%s must be a number" % [who, k])


static func _opt_len(out: Array[String], who: String, r: Dictionary, k: String) -> void:
	if r.has(k) and not _is_len(r[k]):
		out.append("R1 structure: %s.%s must be a number > 0" % [who, k])


static func _opt_text(out: Array[String], who: String, r: Dictionary, k: String) -> void:
	if r.has(k) and not _is_text(r[k]):
		out.append("R1 structure: %s.%s must be a text" % [who, k])


static func _check_bounds(out: Array[String], data: Dictionary) -> void:
	var b: Variant = data.get("bounds", [])
	if typeof(b) != TYPE_ARRAY or (b as Array).size() != 4:
		out.append("R1 structure: bounds must be [x, y, w, h]")
		return
	var a: Array = b
	for v in a:
		if not _is_coord(v):
			out.append("R1 structure: bounds must be [x, y, w, h] of numbers within +-%d" % int(COORD_MAX))
			return
	if float(a[2]) <= 0.0 or float(a[3]) <= 0.0:
		out.append("R1 structure: bounds need a width and a height > 0")
		return
	var s: float = float(data["scale"]) if _is_num(data.get("scale", null)) and float(data["scale"]) <= SCALE_MAX else 3.0
	var samples: float = (float(a[2]) * s / DISJOINT_STEP) * (float(a[3]) * s / DISJOINT_STEP)
	if samples > float(MAX_SAMPLES):
		out.append("R1 structure: bounds are too large to check (%d sample points, at most %d)" % [int(samples), MAX_SAMPLES])


## The header keys the registry and the stage read: body_radius (a huge one made validate() run for ever: the strips and pads of every bridge end
## are built from it), the default rim, version, source, zoom and canopy.
static func _check_header(out: Array[String], data: Dictionary) -> void:
	if data.has("body_radius") and not (_is_num(data["body_radius"]) and float(data["body_radius"]) > 0.0 and float(data["body_radius"]) <= BODY_RADIUS_MAX):
		out.append("R1 structure: body_radius must be a number in (0, %d]" % int(BODY_RADIUS_MAX))
	_opt_num(out, "the header", data, "rim")
	_opt_num(out, "the header", data, "version")
	_opt_text(out, "the header", data, "source")
	if data.has("zoom"):
		if not (data["zoom"] is Dictionary):
			out.append("R1 structure: zoom must be an object {default, min, max}")
		else:
			for k in ["default", "min", "max"]:
				_opt_len(out, "zoom", data["zoom"] as Dictionary, k)
	if data.has("canopy"):
		if not (data["canopy"] is Dictionary):
			out.append("R1 structure: canopy must be an object")
		else:
			_opt_num(out, "canopy", data["canopy"] as Dictionary, "layer")


static func _check_level(out: Array[String], id: String, rec: Dictionary) -> void:
	var who: String = "level %s" % id
	if rec.has("centre") and not _is_pt(rec["centre"]):
		out.append("R1 structure: %s.centre must be an [x, y] point" % who)
	for k in ["rx", "ry"]:
		if rec.has(k) and not _is_len(rec[k]):
			out.append("R1 structure: %s.%s must be a number > 0" % [who, k])
	_opt_num(out, who, rec, "rim")
	_opt_num(out, who, rec, "bit")
	_opt_num(out, who, rec, "z")
	if rec.has("trunk"):
		if not (rec["trunk"] is Dictionary):
			out.append("R1 structure: %s.trunk must be an object" % who)
		else:
			_opt_len(out, who + ".trunk", rec["trunk"] as Dictionary, "rx")
			_opt_len(out, who + ".trunk", rec["trunk"] as Dictionary, "ry")
	if rec.has("walk"):
		if not (rec["walk"] is Dictionary):
			out.append("R1 structure: %s.walk must be an object" % who)
		else:
			var walk: Dictionary = rec["walk"]
			if walk.has("inset") and not (_is_num(walk["inset"]) and float(walk["inset"]) > 0.0 and float(walk["inset"]) <= 1.5):
				out.append("R1 structure: %s.walk.inset must be a number in (0, 1.5]" % who)
			if walk.has("keepout"):
				if typeof(walk["keepout"]) != TYPE_ARRAY:
					out.append("R1 structure: %s.walk.keepout must be a list" % who)
				else:
					for ko in walk["keepout"] as Array:
						if not (ko is Dictionary):
							out.append("R1 structure: %s.walk.keepout holds an entry that is not an object" % who)
							break
	if rec.has("stubs"):
		if typeof(rec["stubs"]) != TYPE_ARRAY:
			out.append("R1 structure: %s.stubs must be a list" % who)
		else:
			for s in rec["stubs"] as Array:
				if not (s is Dictionary):
					out.append("R1 structure: %s.stubs holds an entry that is not an object" % who)
					continue
				_check_path(out, who + ".stub", s as Dictionary)
				_opt_len(out, who + ".stub", s as Dictionary, "width")
				_opt_num(out, who + ".stub", s as Dictionary, "sag")
				if (s as Dictionary).has("exit") and not ((s as Dictionary)["exit"] is Dictionary):
					out.append("R1 structure: %s.stub.exit must be an object" % who)


static func _check_path(out: Array[String], who: String, rec: Dictionary) -> void:
	var path: Variant = rec.get("path", [])
	if typeof(path) != TYPE_ARRAY or (path as Array).size() < 2:
		out.append("R1 structure: %s needs a path of two points" % who)
		return
	for p in path as Array:
		if not _is_pt(p):
			out.append("R1 structure: %s.path holds a value that is not an [x, y] point" % who)
			return


static func _check_bridge(out: Array[String], id: String, rec: Dictionary) -> void:
	var who: String = "bridge %s" % id
	_check_path(out, who, rec)
	if rec.has("width") and not _is_len(rec["width"]):
		out.append("R1 structure: %s has a width of %s, a number > 0 is required (the strip would be empty)" % [who, str(rec["width"])])
	_opt_num(out, who, rec, "sag")
	_opt_num(out, who, rec, "bit")
	_need_text(out, who, rec, "from")
	_need_text(out, who, rec, "to")
	if rec.has("ends") and typeof(rec["ends"]) != TYPE_ARRAY:
		out.append("R1 structure: %s.ends must be a list" % who)


static func _check_spawns(out: Array[String], data: Dictionary) -> void:
	if not data.has("spawns"):
		return
	var sp: Variant = data["spawns"]
	if not (sp is Dictionary):
		out.append("R1 structure: spawns must be an object of [x, y] points")
		return
	for k in sp as Dictionary:
		if not _is_pt((sp as Dictionary)[k]):
			out.append("R1 structure: spawn %s must be an [x, y] point" % [str(k)])


# ------------------------------------------------------------------ the numeric rules

static func _check_rank(out: Array[String], ranks: Dictionary, id: String, v: Variant) -> void:
	var rank: int = LuaData.int_of(v, -1)
	if v == null or rank < 0 or rank % 10 != 0 or float(rank) != LuaData.num(v, -1.0):
		out.append("R2 ranks: %s has rank %s, a multiple of 10 is required" % [id, str(v)])
		return
	if ranks.has(rank):
		out.append("R2 ranks: %s and %s share rank %d" % [id, ranks[rank], rank])
	ranks[rank] = id


## Sample points inside two platform walk regions at once (0 when the platforms are disjoint, as they must be).
static func _count_platform_overlaps(reg: LevelRegistry) -> int:
	if reg.bounds.size == Vector2.ZERO:
		return 0
	var n: int = 0
	var x: float = reg.bounds.position.x
	while x < reg.bounds.end.x:
		var y: float = reg.bounds.position.y
		while y < reg.bounds.end.y:
			var hits: int = 0
			for pl in reg.platforms:
				if pl.contains(Vector2(x, y)):
					hits += 1
			if hits > 1:
				n += 1
			y += DISJOINT_STEP
		x += DISJOINT_STEP
	return n


## The rule ids ("R2", "R5" ...) a problem list contains, sorted and unique (what the mutant tests assert on).
static func rule_ids(problems: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	for p in problems:
		seen[p.get_slice(" ", 0)] = true
	var out: Array[String] = []
	for k in seen:
		out.append(str(k))
	out.sort()
	return out
