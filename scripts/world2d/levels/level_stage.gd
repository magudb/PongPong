class_name LevelStage
extends RefCounted
## Builds a LEVELLED builder area from the city data (package V3-levels): the structure V4's CityBuilder reuses and the scene the windowed
## probes (tests/levels_shots) and the section city_levels look at. It does NOT edit any framework file: it only uses the documented hook of
## IsoArea builders (design 4.8) - `area.bounds / spawns / zoom_range / walkable_test`, the `floors` it adds itself, the area's own `objects`
## (the ONE y-sorted node: ranked z_index, then y), `colliders` and `triggers`.
##
## What it creates, in this order:
##   registry     LevelRegistry.from_dict(data) (levels, bridges, stubs, ladders, lifts, landings)
##   floors       Node2D "Floors" (not y-sorted): platform discs at z = rank - 4, lower trunks at rank - 6, bridge decks at rank - 4
##   objects      trunk upper segments, huts, props, lanterns, posts and ropes, owl holes, bat houses, foliage, the ladder, the lift - all at
##                z_index = rank of their level (decor ranks from the data), so the draw order is DATA, not computed
##   colliders    per platform ONE Railing body (ring with gaps, keep-outs, wings) and per bridge one rail body, each on that level's bit ONLY
##   triggers     the ClimbLane ends (ladder + the monkey's trunk climb) and the RopeLift
##   LevelTracker (child of the area) gives every actor its level; LevelGlow (halos + <= 12 PointLight2D); OccluderFade
## The visible art is LevelPainter's flat stand-in shapes unless opts.painter is false (a builder that draws its own sprites).
##
##   LevelStage.build(area, data, opts) -> LevelStage        opts: art (Dictionary of textures), painter (bool), sky (bool), canopy (bool)
##   LevelStage.of(area) -> LevelStage                        the stage an area was built with (area meta), null otherwise
## The stage keeps its textures in INSTANCE dictionaries (never static variables) and hangs itself on the area's meta, so everything goes away
## with the area. A builder area is never parked: every visit builds again (warm rebuild budget 40 ms).

const META := &"level_stage"
const CAP_RUNGS_TO := 565.0              # sketch px: the ladder is drawn again above the Upper deck's rim down to this y

var area: IsoArea
var registry: LevelRegistry
var data: Dictionary = {}
var art: Dictionary = {}
var scale: float = 3.0
var floors: Node2D
var tracker: LevelTracker
var glow: LevelGlow
var fade: OccluderFade
var strips: Array[BridgeStrip] = []
var railings: Array[Railing] = []
var lanes: Array[ClimbLane] = []
var lifts: Array[RopeLift] = []
var shapes: Dictionary = {}              # id -> Node2D of the stand-in shapes (huts, props ...) for tests and the occluder registry
var build_ms: float = 0.0
var canopy_layer: CanvasLayer


static func of(a: Node) -> LevelStage:
	if a != null and a.has_meta(META):
		return a.get_meta(META) as LevelStage
	return null


static func build(p_area: IsoArea, p_data: Dictionary, opts: Dictionary = {}) -> LevelStage:
	var s := LevelStage.new()
	s._build(p_area, p_data, opts)
	return s


func _build(p_area: IsoArea, p_data: Dictionary, opts: Dictionary) -> void:
	var t0: int = Time.get_ticks_usec()
	area = p_area
	data = p_data
	registry = LevelRegistry.from_dict(p_data)
	scale = registry.scale
	var painter: bool = bool(opts.get("painter", true))
	art = opts.get("art", {}) as Dictionary
	if art.is_empty() and painter:
		art = LevelPainter.make_art()
	# --- the documented builder hook of IsoArea
	area.bounds = registry.bounds
	var zoom: Dictionary = LuaData.dict(data.get("zoom", {}))
	area.zoom_range = Vector2(LuaData.num(zoom.get("min", 0.2), 0.2), LuaData.num(zoom.get("max", 0.7), 0.7))
	area.zoom_default = LuaData.num(zoom.get("default", 0.4), 0.4)
	for k in registry.spawns:
		area.spawns[str(k)] = registry.spawns[k]
	var reg: LevelRegistry = registry
	area.walkable_test = func(p: Vector2) -> bool: return reg.level_at(p) != null
	# --- structure
	floors = Node2D.new()
	floors.name = "Floors"
	area.add_child(floors)
	var nodes: Dictionary = {"floors": floors, "colliders": area.colliders}
	if painter and bool(opts.get("sky", true)):
		_paint_backdrop()
	fade = OccluderFade.new()
	fade.name = "OccluderFade"
	area.add_child(fade)
	for lv in registry.platforms:
		if painter:
			LevelPainter.add_disc(floors, lv, art)
		railings.append(Railing.build(nodes, lv, registry, art))
	for lv in registry.bridges:
		strips.append(BridgeStrip.build(nodes, lv, registry, art))
	for st in registry.stubs:
		var pl: Level = registry.get_level(st["level"])
		if pl != null:
			strips.append(BridgeStrip.build_stub(nodes, st, pl, registry, art))
	if painter:
		_paint_scene()
	_make_links()
	_make_glow()
	tracker = LevelTracker.new()
	tracker.name = "LevelTracker"
	area.add_child(tracker)
	tracker.attach(area, registry)
	if painter and bool(opts.get("canopy", true)):
		_paint_canopy()
	area.set_meta(META, self)
	build_ms = float(Time.get_ticks_usec() - t0) / 1000.0


# ------------------------------------------------------------------ stand-in scene

func _rank_of(level_id: Variant) -> int:
	var lv: Level = registry.get_level(StringName(str(level_id)))
	return lv.rank if lv != null else 0


func _w(p: Variant) -> Vector2:
	var a: Array = LuaData.arr(p)
	return Vector2(LuaData.num(a[0]), LuaData.num(a[1])) * scale if a.size() >= 2 else Vector2.ZERO


func _paint_backdrop() -> void:
	var rect: Rect2 = registry.bounds.grow(1400.0)
	area.backdrop.add_child(LevelPainter.sky_node(rect))
	area.backdrop.add_child(LevelPainter.far_bars_node(rect, scale))
	area.backdrop.add_child(LevelPainter.ground_strip_node(registry.bounds, scale))


func _paint_scene() -> void:
	var objects: Node2D = area.objects
	# trunks: lower segments are floors (rank - 6), upper segments are objects with the platform's rank and the platform centre as pivot
	for rec in LuaData.arr(data.get("trunks", [])):
		var t: Dictionary = rec
		var rx: float = LuaData.num(t["rx"]) * scale
		var ry: float = LuaData.num(t["ry"]) * scale
		var cx: float = LuaData.num(t["cx"]) * scale
		var y_top: float = LuaData.num(t["y_top"]) * scale
		var y_bot: float = LuaData.num(t["y_bot"]) * scale
		var rank: int = LuaData.int_of(t["rank"])
		if str(t["part"]) == "lower":
			var n: Node2D = LevelPainter.trunk_node(rx, ry, 0.0, y_bot - y_top)
			n.position = Vector2(cx, y_top)
			n.z_index = rank
			n.name = str(t["id"])
			floors.add_child(n)
		else:
			var n2: Node2D = LevelPainter.trunk_node(rx, ry, y_top - y_bot, 0.0)
			n2.position = Vector2(cx, y_bot)
			n2.z_index = rank
			n2.name = str(t["id"])
			objects.add_child(n2)
			shapes[str(t["id"])] = n2
			if bool(t.get("occlude_fade", false)):
				fade.register(n2, y_bot, Vector2(cx - rx, cx + rx), y_top, rank)
	for rec in LuaData.arr(data.get("buildings", [])):
		var b: Dictionary = rec
		var hut: Node2D = LevelPainter.hut_node(b, scale)
		hut.position = Vector2(LuaData.num(b["cx"]), LuaData.num(b["base_y"])) * scale
		hut.z_index = _rank_of(b["level"])
		hut.name = "Hut_%s" % b["id"]
		objects.add_child(hut)
		shapes[str(b["id"])] = hut
		if bool(b.get("occlude_fade", false)):
			var roof: Dictionary = b["roof"]
			var cx2: float = hut.position.x
			var rrx: float = LuaData.num(roof["rx"]) * scale
			var top: float = hut.position.y + (-(LuaData.num(b["wall_h"])) + 6.0 - LuaData.num(roof["h"])) * scale
			fade.register(hut, hut.position.y, Vector2(cx2 - rrx, cx2 + rrx), top, hut.z_index)
	for rec in LuaData.arr(data.get("props", [])):
		var pr: Dictionary = rec
		var pn: Node2D = LevelPainter.prop_node(pr, scale)
		pn.position = _w(pr["at"])
		pn.z_index = _rank_of(pr["level"])
		pn.name = "Prop_%s" % pr["id"]
		objects.add_child(pn)
		shapes[str(pr["id"])] = pn
	# hanging lanterns and door lamps hang overhead: one Sprite2D each (the shared lantern texture), grouped per level at rank + 1 so they batch
	var lamp_tex: Texture2D = art.get("lantern", null)
	var groups: Dictionary = {}
	for rec in LuaData.arr(data.get("lanterns", [])) + LuaData.arr(data.get("door_lamps", [])):
		var lamp: Dictionary = rec
		var lid: String = str(lamp["level"])
		if not groups.has(lid):
			var g := Node2D.new()
			g.name = "Lamps_%s" % lid
			g.z_index = _rank_of(lid) + 1
			floors.add_child(g)
			groups[lid] = g
		if lamp_tex != null:
			var sp := Sprite2D.new()
			sp.texture = lamp_tex
			sp.centered = false
			sp.offset = Vector2(-lamp_tex.get_width() * 0.5, 0)
			sp.position = _w(lamp["at"]) + Vector2(0, -38.0 * (0.7 if lamp.has("building") else 1.0))
			sp.scale = Vector2.ONE * (0.7 if lamp.has("building") else 1.0)
			(groups[lid] as Node2D).add_child(sp)
	for rec in LuaData.arr(data.get("owl_holes", [])):
		var oh: Node2D = LevelPainter.owl_hole_node(scale)
		oh.position = _w((rec as Dictionary)["at"]) + Vector2(0, 38.0 * scale)
		oh.z_index = LuaData.int_of((rec as Dictionary)["rank"])
		objects.add_child(oh)
	for rec in LuaData.arr(data.get("bat_houses", [])):
		var bh: Dictionary = rec
		var bn: Node2D = LevelPainter.bat_house_node(LuaData.num(bh["w"]), LuaData.num(bh["tip_y"]) - LuaData.num(bh["y_top"]) + 107.0, scale)
		bn.position = Vector2(LuaData.num(bh["cx"]), LuaData.num(bh["tip_y"])) * scale
		bn.z_index = LuaData.int_of(bh["rank"])
		objects.add_child(bn)
	for rec in LuaData.arr(data.get("foliage", [])):
		var fo: Dictionary = rec
		var fn: Node2D = LevelPainter.foliage_node(LuaData.num(fo["rx"]) * scale, LuaData.num(fo["ry"]) * scale, LuaData.num(fo["alpha"], 0.5))
		fn.position = _w(fo["at"])
		fn.z_index = LuaData.int_of(fo["rank"])
		objects.add_child(fn)
	for lad in registry.ladders:
		_paint_ladder(lad)


## The ladder on the trunk between the decks: rails and rungs at the Torvet's rank (so a walker in front of it is drawn over it) and a cap
## above the Upper deck's rim at the Upper's rank minus 2, so the rim does not swallow the top rungs.
func _paint_ladder(lad: Dictionary) -> void:
	var bottom: Vector2 = lad["bottom"]
	var top: Vector2 = lad["top"]
	var half: float = (lad["width"] as float) * 0.5
	var from_rank: int = _rank_of(lad["from"])
	var to_rank: int = _rank_of(lad["to"])
	var length: float = bottom.y - top.y
	var rungs: int = maxi(LuaData.int_of(lad.get("rungs", 9), 9), 2)
	var body := Node2D.new()
	body.name = "Ladder_%s" % lad["id"]
	body.position = bottom
	body.z_index = from_rank
	for side in [-1.0, 1.0]:
		body.add_child(LevelPainter.line(PackedVector2Array([Vector2(side * half, 0), Vector2(side * half, -length)]), LevelPainter.BARK_DARK, 12.0))
	for k in rungs:
		var y: float = -length * (float(k) + 0.5) / float(rungs)
		body.add_child(LevelPainter.line(PackedVector2Array([Vector2(-half, y), Vector2(half, y)]), LevelPainter.BARK, 9.0))
	area.objects.add_child(body)
	shapes[str(lad["id"])] = body
	var cap := Node2D.new()
	cap.name = "LadderCap_%s" % lad["id"]
	cap.position = Vector2(bottom.x, top.y)
	cap.z_index = to_rank - 2
	var cap_len: float = maxf(CAP_RUNGS_TO * scale - top.y, 0.0)
	for side in [-1.0, 1.0]:
		cap.add_child(LevelPainter.line(PackedVector2Array([Vector2(side * half, 0), Vector2(side * half, cap_len)]), LevelPainter.BARK_DARK, 12.0))
	for k in rungs:
		var y2: float = length * (1.0 - (float(k) + 0.5) / float(rungs))
		if y2 <= cap_len:
			cap.add_child(LevelPainter.line(PackedVector2Array([Vector2(-half, y2), Vector2(half, y2)]), LevelPainter.BARK, 9.0))
	area.add_child(cap)


func _make_links() -> void:
	for lad in registry.ladders:
		for c in ClimbLane.create_pair(lad, registry):
			area.triggers.add_child(c)
			lanes.append(c)
	for zone in registry.climb_zones:
		for c in ClimbLane.create_zone_pair(zone, registry):
			area.triggers.add_child(c)
			lanes.append(c)
	for rec in registry.lifts:
		var l: RopeLift = RopeLift.create_lift(rec, registry, {"objects": area.objects}, art)
		area.triggers.add_child(l)
		lifts.append(l)


func _make_glow() -> void:
	var halos: Array = []
	for rec in LuaData.arr(data.get("lanterns", [])):
		halos.append({"at": _w((rec as Dictionary)["at"]), "r": 30.0 * scale, "color": Color("ffd98a"), "strength": 0.9})
	for rec in LuaData.arr(data.get("door_lamps", [])):
		halos.append({"at": _w((rec as Dictionary)["at"]), "r": 24.0 * scale, "color": Color("ffe0a0"), "strength": 0.8})
	var lights: Array = []
	for rec in LuaData.arr(data.get("lights", [])):
		var l: Dictionary = rec
		lights.append({"at": _w(l["at"]), "r": LuaData.num(l["r_px"]), "color": Color.from_string(str(l["color"]), Color("ffd98a")), "energy": LuaData.num(l["energy"], 0.8)})
	glow = LevelGlow.new()
	area.add_child(glow)
	glow.setup(halos, lights)


func _paint_canopy() -> void:
	canopy_layer = CanvasLayer.new()
	canopy_layer.name = "Canopy"
	canopy_layer.layer = LuaData.int_of(LuaData.dict(data.get("canopy", {})).get("layer", 3), 3)
	canopy_layer.add_child(LevelPainter.canopy_strip(3600.0, 78.0))
	canopy_layer.offset = Vector2(-1100, 0)
	area.add_child(canopy_layer)
