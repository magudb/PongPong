class_name CityBuilder
extends RefCounted
## The builder of the area `traetoppen` (package V4-city-map): the levelled treetop city of the Miljoeer v2 sketch. data/maps/traetoppen.map is header-only
## (`@builder res://scripts/traetoppen/city_builder.gd`); IsoArea calls `CityBuilder.build(area, header)` on every visit (a builder area is never parked).
##
## WHAT IT DOES (design_v2.md 4.8): it reads data/traetoppen/traetoppen.json (V3), lets LevelStage (V3) build the structure with painter = false (the
## registry, the rim rails and bridge rails on the per-level physics bits, the rope bridges, the ladder and the monkey's trunk climb, the Skovlift,
## LevelTracker, LevelGlow, OccluderFade, area.bounds / spawns / zoom range / walkable_test) and then DRAWS the city with V5's art through ArtCatalog ids:
##   backdrop    the treetop sky and the far trunks sized to the sketch (IsoArea's own backdrop assumes Iso.ZOOM_MIN) and continued HEADROOM_PX above it,
##               the canopy frame on CanvasLayer 3 (it gives way when the camera zooms out, see CanopyFrame)
##   floors      (not y-sorted, z = rank - 4) the platform discs, the lower trunks with their root flares, the hanging lanterns / door lamps at rank + 1, the
##               owl holes, the bat houses, the front foliage, the Skovlift rope
##   objects     (the ONE y-sorted node, z_index = rank of the level, then y) the upper trunk segments with their feet, the huts with pennants and additive night
##               layers, the stall, the fire pit with its flame, the log stack, the notice board, the seed basket, the kitchen gardens, the tub halves, the ladder
##   markers     npc / node markers through IsoArea.resolve_handler (the real handler when it exists), the rest are V6's and skipped silently and counted;
##               while P14's npc handler is missing TraetoppenPreviewCitizens places the labelled stand-ins; the two ambient owls sit in their holes
##   triggers    the two warps at the ends of the bridge stubs, the three signs, the ten landmark circles (game_event landmark_entered once per visit),
##               the Skovlift gate (unlock day, closed forest)
##   preview     while no P14 / HUD exist: the labelled stand-in citizens and the small prompt / whisper / toast overlay (TraetoppenPreviewCitizens)
## After the build it calls Svc.static_call(town_script_path, "attach", [area, "traetoppen"]) (the towns track's CityTown, no hard dependency).
## Nothing of the framework (iso_area, world_2d, game_data, art_catalog) is edited; the build touches only the documented builder hook.

const TOWN_SCRIPT := "res://scripts/towns/city_town.gd"
const META := &"city_build"
const FILTER := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
const FOOT_NECK_PX := 30.0          # the rows of a trunk foot that are bark tile rows (V5: neck_px)
const BARK_TILE_PX := 512.0         # the bark tile's height: an upper segment ends at tile row 512 so its foot continues the pattern
const ROOT_OVERLAP_PX := 60.0       # a lower trunk's bark runs this far below the ground-ellipse centre, hidden by the wider root flare
const OWL_SHELF_DY := 128.0         # the ledge under an owl hole (V5's assembly)
const BAT_DY := 26.0                # the hanging bat under the tip of its house (V5's assembly)
const FLAME_DY := 24.0              # the flame's base below the fire pit's pivot (V5's assembly)
const TUB_SORT_DY := 2.0            # the tub's back half sorts this far behind, its front half this far before the figure in the tub
const WARP_REACH := 0.5             # extra reach of the bridge warps in cells (the diamond then covers the whole width of the stub)
const SIGN_RADIUS := Vector2(70, 36)
const FAR_REPEATS := 3
const SKY_MARGIN := 1400.0
const SKY_OVERLAP_PX := 16.0           # the flat sky above and below the gradient reaches this far under it
## The camera may scroll this far ABOVE the sketch's top edge (world px): the top platforms A and B stand under the canopy frame otherwise (the player
## on the north rim of A at the game zoom was drawn under it, the area's minimum zoom showed the platforms cut by the strip). The sky is flat above
## the sketch (SkyAbove) and the far trunks are continued by a mirrored slice (FarAbove, FAR_ABOVE_PX tall).
const HEADROOM_PX := 450.0
const FAR_ABOVE_PX := 600.0
const SKY_TOP := Color("cfe0a8")        # the first / last row of V5's treetop_sky gradient: the sky above and below the sketch continues in these
const SKY_BOTTOM := Color("4f6f3a")

## The towns track's attach script (CityTown). A test points this at its own script to prove the call; the shipped value is the default.
static var town_script_path: String = TOWN_SCRIPT

## The three signs (sketch px): they stand on the open floor of their level next to the way they point at.
const SIGNS := [
	{"id": "farm", "at": [1338, 1008], "level": "g", "key": "TRAE_SIGN_FARM"},
	{"id": "hyggebyen", "at": [478, 1050], "level": "f", "key": "TRAE_SIGN_HYGGEBYEN"},
	{"id": "skovlift", "at": [1306, 322], "level": "b", "key": "TRAE_SIGN_SKOVLIFT"},
]

var area: IsoArea
var data: Dictionary = {}
var k: float = 3.0
var stage: LevelStage
var registry: LevelRegistry
var floors: Node2D
var objects: Node2D
var build_ms: float = 0.0
## What the build made, for the section and for later packages.
var warps: Array[Warp2D] = []
var signs: Array[Interactable2D] = []
var landmarks: Array[LandmarkTrigger] = []
var lift_gate: LiftGate
var night: NightFx
var citizens_placed: int = 0
var preview_hints: Node                     # the M1a prompt / whisper / toast overlay (null once P14 has landed)
var ambient_owls: Array[Node2D] = []
var marker_nodes: Dictionary = {}           # marker id -> Node (handled by a real handler)
var huts: Dictionary = {}                   # building id -> the hut container node
var planters_drawn: int = 0
var town_attached: bool = false
var art_problems: Array[String] = []


## The camera limits of the city: the sketch's bounds with HEADROOM_PX more above the top edge.
static func camera_bounds(sketch_bounds: Rect2) -> Rect2:
	return Rect2(sketch_bounds.position.x, sketch_bounds.position.y - HEADROOM_PX, sketch_bounds.size.x, sketch_bounds.size.y + HEADROOM_PX)


static func of(a: Node) -> CityBuilder:
	if a != null and a.has_meta(META):
		return a.get_meta(META) as CityBuilder
	return null


## The `@builder` entry point (static: IsoArea calls it on the script).
static func build(p_area: IsoArea, header: Dictionary) -> void:
	var t0: int = Time.get_ticks_usec()
	var d: Dictionary = CityData.load_data()
	if d.is_empty():
		p_area.builder_error = "city: %s" % LevelRegistry.last_error
		return
	var b := CityBuilder.new()
	b._build(p_area, header, d)
	b.build_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	p_area.set_meta(META, b)
	# the towns track's hook (CityTown.attach(area, "traetoppen")): late-bound, absent until T-director lands
	b.town_attached = ResourceLoader.exists(town_script_path)
	Svc.static_call(town_script_path, &"attach", [p_area, "traetoppen"], null)


func _build(p_area: IsoArea, _header: Dictionary, p_data: Dictionary) -> void:
	area = p_area
	data = p_data
	k = CityData.scale_of(data)
	stage = LevelStage.build(area, data, {"painter": false, "art": _stage_art()})
	registry = stage.registry
	# the camera limits: the sketch's bounds plus HEADROOM_PX above (LevelStage set the bounds of the registry; the registry keeps its own for the sky etc.)
	area.bounds = camera_bounds(registry.bounds)
	floors = stage.floors
	objects = area.objects
	_paint_backdrop()
	_paint_discs_and_trunks()
	_place_markers()
	_paint_huts()
	_paint_props()
	_paint_lamps()
	_paint_decor()
	_paint_ladder()
	_paint_lift()
	_paint_canopy()
	_make_warps()
	_make_signs()
	_make_landmarks()
	_gate_lift()
	night = NightFx.new()
	night.name = "NightFx"
	area.add_child(night)
	night.collect(self)


# ------------------------------------------------------------------ art helpers

func _tex(id: StringName) -> Texture2D:
	return ArtCatalog.prop(id)["texture"] as Texture2D


func _stage_art() -> Dictionary:
	return {"deck": _tex(&"bridge_deck_tile_w43"), "post": _tex(&"bridge_post"), "basket": _tex(&"lift_basket"),
		"rope_color": Color("76614d"), "outline_color": Color("4b3c49")}


## A sprite of an ArtCatalog prop at `pos` under `parent` (ground-origin pivot: centered = false, offset = -pivot), additive when the art says so.
func _spr(parent: Node, id: StringName, pos: Vector2 = Vector2.ZERO, z: int = 0, sort_dy: float = 0.0) -> Sprite2D:
	var p: Dictionary = ArtCatalog.prop(id)
	var s := Sprite2D.new()
	s.name = String(id)
	s.texture = p["texture"]
	s.centered = false
	s.offset = -(p["pivot"] as Vector2) - Vector2(0, sort_dy)
	s.position = pos + Vector2(0, sort_dy)
	s.z_index = z
	s.texture_filter = FILTER
	if str(p["blend"]) == "add":
		s.material = Glow.additive_material()
	if not bool(p.get("real", false)):
		art_problems.append(String(id))
	parent.add_child(s, true)
	return s


## A repeating strip of a tileable prop (bark, ladder, rope): `top_left` and `region` in world px.
func _tiled(parent: Node, id: StringName, top_left: Vector2, region: Rect2, z: int = 0) -> Sprite2D:
	var p: Dictionary = ArtCatalog.prop(id)
	var s := Sprite2D.new()
	s.name = String(id)
	s.texture = p["texture"]
	s.centered = false
	s.region_enabled = true
	s.region_rect = region
	s.position = top_left
	s.z_index = z
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = FILTER
	if not bool(p.get("real", false)):
		art_problems.append(String(id))
	parent.add_child(s, true)
	return s


## A looping multi-frame sprite (pennant sway, flame, hanging bat): AnimatedSprite2D over the frames V5 lists on the first frame.
func _anim(parent: Node, base: StringName, fps: float, pos: Vector2 = Vector2.ZERO) -> AnimatedSprite2D:
	var ids: Array[StringName] = CityData.frames_of(base)
	var p0: Dictionary = ArtCatalog.prop(ids[0])
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	for id in ids:
		frames.add_frame("default", ArtCatalog.prop(id)["texture"] as Texture2D)
	var a := AnimatedSprite2D.new()
	a.name = String(base)
	a.sprite_frames = frames
	a.centered = false
	a.offset = -(p0["pivot"] as Vector2)
	a.position = pos
	a.texture_filter = FILTER
	if str(p0["blend"]) == "add":
		a.material = Glow.additive_material()
	if not bool(p0.get("real", false)):
		art_problems.append(String(base))
	parent.add_child(a, true)
	a.play("default")
	a.frame = int(randi() % ids.size())
	return a


func _container(parent: Node, node_name: String, pos: Vector2, z: int) -> Node2D:
	var c := Node2D.new()
	c.name = node_name
	c.position = pos
	c.z_index = z
	parent.add_child(c)
	return c


func _w(p: Variant) -> Vector2:
	return CityData.world(data, p)


func _rank(level_id: Variant) -> int:
	return CityData.rank_of(data, level_id)


# ------------------------------------------------------------------ backdrop and canopy

func _paint_backdrop() -> void:
	var bd: Dictionary = ArtCatalog.backdrop(&"treetop")
	if not bool(bd["real"]):
		art_problems.append("backdrop:treetop")
	var rect: Rect2 = registry.bounds
	var wide: Rect2 = rect.grow_individual(SKY_MARGIN, 0.0, SKY_MARGIN, 0.0)
	var sky_tex: Texture2D = bd["sky"]
	var top_col: Color = SKY_TOP
	var bottom_col: Color = SKY_BOTTOM
	# the gradient spans the sketch's own height; above and below it the end colours continue
	var above := ColorRect.new()
	above.name = "SkyAbove"
	above.color = top_col
	above.position = Vector2(wide.position.x, rect.position.y - SKY_MARGIN)
	above.size = Vector2(wide.size.x, SKY_MARGIN + SKY_OVERLAP_PX)      # tucked under the sky gradient: no hairline of the clear colour at the join
	above.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.backdrop.add_child(above)
	var sky := Sprite2D.new()
	sky.name = "Sky"
	sky.texture = sky_tex
	sky.centered = false
	sky.position = wide.position
	sky.scale = Vector2(wide.size.x / float(sky_tex.get_width()), wide.size.y / float(sky_tex.get_height()))
	area.backdrop.add_child(sky)
	var below := ColorRect.new()
	below.name = "SkyBelow"
	below.color = bottom_col
	below.position = Vector2(wide.position.x, rect.end.y - SKY_OVERLAP_PX)
	below.size = Vector2(wide.size.x, SKY_MARGIN + SKY_OVERLAP_PX)
	below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.backdrop.add_child(below)
	# the far trunks, the mist and the ground strip: one tile as tall as the sketch, FAR_REPEATS tiles side by side. Each tile is a sprite of its own
	# WITHOUT texture repeat: with repeat on, the bilinear filter at the top edge of the picture blends in the bottom rows of the tile (the dark ground
	# strip) and draws a dark hairline across the whole width at the sketch's top edge, where the camera now looks (HEADROOM_PX above it)
	var far_tex: Texture2D = bd["far"]
	var far_scale: float = rect.size.y / float(far_tex.get_height())
	var tile_w: float = float(far_tex.get_width()) * far_scale
	var far := Node2D.new()
	far.name = "Far"
	far.position = Vector2(rect.get_center().x - tile_w * float(FAR_REPEATS) * 0.5, rect.position.y)
	area.backdrop.add_child(far)
	# above the sketch (where the camera may look, HEADROOM_PX): the top rows of the far tile mirrored upwards - the trunks are straight stripes there,
	# so the join at the sketch's top edge is seamless and the sky (SkyAbove) shows between them
	var rows: float = ceilf(FAR_ABOVE_PX / far_scale)
	var far_above := Node2D.new()
	far_above.name = "FarAbove"
	far_above.position = Vector2(far.position.x, rect.position.y - rows * far_scale)
	area.backdrop.add_child(far_above)
	for i in FAR_REPEATS:
		far.add_child(_far_tile(far_tex, far_scale, Vector2(float(i) * tile_w, 0.0), 0.0))
		far_above.add_child(_far_tile(far_tex, far_scale, Vector2(float(i) * tile_w, 0.0), rows))


## One tile of the far backdrop (no texture repeat, see _paint_backdrop); `mirrored_rows` > 0 = only the top rows, flipped (the strip above the sketch).
func _far_tile(tex: Texture2D, tile_scale: float, pos: Vector2, mirrored_rows: float) -> Sprite2D:
	var tile := Sprite2D.new()
	tile.texture = tex
	tile.centered = false
	tile.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	tile.scale = Vector2.ONE * tile_scale
	tile.position = pos
	if mirrored_rows > 0.0:
		tile.flip_v = true
		tile.region_enabled = true
		tile.region_rect = Rect2(0.0, 0.0, float(tex.get_width()), mirrored_rows)
	return tile


func _paint_canopy() -> void:
	var layer: int = LuaData.int_of(LuaData.dict(data.get("canopy", {})).get("layer", 3), 3)
	var frame := CanopyFrame.new()
	frame.name = "Canopy"
	frame.layer = layer
	frame.strip = _tex(&"canopy_top_strip")
	area.add_child(frame)


# ------------------------------------------------------------------ discs and trunks

func _paint_discs_and_trunks() -> void:
	for lv in registry.platforms:
		var rec: Dictionary = CityData.record(data, "levels", String(lv.id))
		var disc: Sprite2D = _spr(floors, CityData.disc_art(LuaData.num(rec.get("rx", 0.0))), lv.centre, lv.rank - 4)
		disc.name = "Disc_%s" % lv.id
	for rec in LuaData.arr(data.get("trunks", [])):
		var t: Dictionary = rec
		var bark: StringName = CityData.trunk_art(LuaData.num(t.get("rx", 0.0)))
		var bw: float = float((ArtCatalog.prop(bark)["size"] as Vector2).x)
		var cx: float = LuaData.num(t["cx"]) * k
		var y_top: float = LuaData.num(t["y_top"]) * k
		var y_bot: float = LuaData.num(t["y_bot"]) * k
		var rank: int = LuaData.int_of(t["rank"])
		if str(t["part"]) == "lower":
			# the trunk below a deck: behind the disc, down to the ground ellipse and its root flare
			var low: Node2D = _container(floors, "Trunk_%s" % t["id"], Vector2(cx, y_bot), rank)
			_tiled(low, bark, Vector2(-bw * 0.5, y_top - y_bot), Rect2(0.0, 0.0, bw, (y_bot - y_top) + ROOT_OVERLAP_PX))
			_spr(low, CityData.root_art(bark))
		else:
			# the trunk above a deck: a bark segment ending at tile row 512 over the foot, which stands on the deck's centre
			var up: Node2D = _container(objects, "Trunk_%s" % t["id"], Vector2(cx, y_bot), rank)
			var length: float = (y_bot - y_top) - FOOT_NECK_PX
			var off: float = fposmod(BARK_TILE_PX - fposmod(length, BARK_TILE_PX), BARK_TILE_PX)
			_tiled(up, bark, Vector2(-bw * 0.5, -FOOT_NECK_PX - length), Rect2(0.0, off, bw, length))
			_spr(up, CityData.foot_art(bark))
			if bool(t.get("occlude_fade", false)):
				stage.fade.register(up, y_bot, Vector2(cx - bw * 0.5, cx + bw * 0.5), y_top, rank)


# ------------------------------------------------------------------ huts, props, lamps, decor

func _paint_huts() -> void:
	for rec in LuaData.arr(data.get("buildings", [])):
		var b: Dictionary = rec
		var id: String = str(b["id"])
		var art: StringName = CityData.hut_art(id)
		if art == &"":
			art_problems.append("hut_of:%s" % id)
			continue
		var p: Dictionary = ArtCatalog.prop(art)
		var pos: Vector2 = Vector2(LuaData.num(b["cx"]), LuaData.num(b["base_y"])) * k
		var rank: int = _rank(b["level"])
		var hut: Node2D = _container(objects, "Hut_%s" % id, pos, rank)
		_spr(hut, art)
		if b.has("pennant"):
			var pennant: StringName = CityData.pennant_art(str(b["pennant"]))
			var apex: Array = LuaData.arr(LuaData.dict(CityData.city_props().get(String(art), {})).get("apex", [0, 0]))
			if pennant != &"" and apex.size() >= 2:
				_anim(hut, pennant, 2.0, Vector2(LuaData.num(apex[0]), LuaData.num(apex[1])) - (p["pivot"] as Vector2))
		var lit: StringName = CityData.night_art(art)
		if lit != &"":
			var layer: Sprite2D = _spr(hut, lit)
			layer.name = "Night"
			layer.set_meta("night_strength", 1.0)
			layer.modulate.a = 0.0
			layer.visible = false
		huts[id] = hut
		if bool(b.get("occlude_fade", false)):
			var size: Vector2 = p["size"] as Vector2
			var pivot: Vector2 = p["pivot"] as Vector2
			stage.fade.register(hut, pos.y, Vector2(pos.x - pivot.x, pos.x - pivot.x + size.x), pos.y - pivot.y, rank)


func _paint_props() -> void:
	for rec in LuaData.arr(data.get("props", [])):
		var pr: Dictionary = rec
		var id: String = str(pr["id"])
		var pos: Vector2 = _w(pr.get("at", [0, 0]))
		var rank: int = _rank(pr.get("level", ""))
		var art: StringName = StringName(str(pr.get("art", "")))
		match id:
			"fire_pit":
				var pit: Node2D = _container(objects, "Prop_fire_pit", pos, rank)
				_spr(pit, art)
				_anim(pit, &"fire_flame", 8.0, Vector2(0, FLAME_DY))
			"bath_tub":
				_spr(objects, &"bath_tub_back", pos, rank, -TUB_SORT_DY).name = "TubBack"
				_spr(objects, &"bath_tub_front", pos, rank, TUB_SORT_DY).name = "TubFront"
			"planter1", "planter2", "planter3":
				# the kitchen gardens are P19's `node` markers; without its handler the beds are drawn as plain decoration
				if not marker_nodes.has(id):
					var kind: String = str(CityData.PLANTER_KINDS.get(id, "planter_herb"))
					_spr(_container(objects, "Prop_%s" % id, pos, rank), CityData.PLANTER_ART[kind] as StringName)
					planters_drawn += 1
			_:
				_spr(_container(objects, "Prop_%s" % id, pos, rank), art)


func _paint_lamps() -> void:
	var groups: Dictionary = {}
	for rec in LuaData.arr(data.get("lanterns", [])) + LuaData.arr(data.get("door_lamps", [])):
		var lamp: Dictionary = rec
		var lid: String = str(lamp["level"])
		if not groups.has(lid):
			var g := Node2D.new()
			g.name = "Lamps_%s" % lid
			g.z_index = _rank(lid) + 1
			floors.add_child(g)
			groups[lid] = g
		_spr(groups[lid] as Node, &"lamp_door" if lamp.has("building") else &"lantern_hang", _w(lamp["at"]))


func _paint_decor() -> void:
	var holes: Array = LuaData.arr(data.get("owl_holes", []))
	for i in holes.size():
		var h: Dictionary = holes[i]
		var at: Vector2 = _w(h["at"])
		var rank: int = LuaData.int_of(h.get("rank", 175))
		_spr(floors, &"trunk_hole_owl" if i % 2 == 0 else &"trunk_hole_owl_b", at, rank).name = "OwlHole_%d" % i
		_spr(floors, &"owl_shelf", at + Vector2(0, OWL_SHELF_DY), rank).name = "OwlShelf_%d" % i
	for rec in LuaData.arr(data.get("bat_houses", [])):
		var bh: Dictionary = rec
		var tip: Vector2 = Vector2(LuaData.num(bh["cx"]), LuaData.num(bh["tip_y"])) * k
		var rank: int = LuaData.int_of(bh.get("rank", 180))
		_spr(floors, &"bat_house_hanging", tip, rank)
		var bat: AnimatedSprite2D = _anim(floors, &"bat_hang", 1.0, tip + Vector2(0, BAT_DY))
		bat.z_index = rank
	var foliage_ids: Array[StringName] = [&"foliage_front_a", &"foliage_front_b"]
	var fi: int = 0
	for rec in LuaData.arr(data.get("foliage", [])):
		var fo: Dictionary = rec
		_spr(floors, foliage_ids[fi % 2], _w(fo["at"]), LuaData.int_of(fo["rank"])).name = "Foliage_%s" % fo["id"]
		fi += 1
	_paint_ambient_owls()


## The ambient owls (landmark 9): a plain idle pack owl in each hole after Fru Ugle's: no name, no talking, no collision, a critter of the scenery.
func _paint_ambient_owls() -> void:
	for m in CityData.markers_of(data, "ambient_owl"):
		var owl: IsoChibiSprite2D = IsoChibiSprite2D.create(str((m["params"] as Dictionary).get("visual", CityData.AMBIENT_OWL_VISUAL)))
		if owl == null:
			continue
		var holder: Node2D = _container(objects, "AmbientOwl_%s" % m["id"], area.to_local(m["at"] as Vector2), LuaData.int_of(m.get("rank", 175), 175) + 1)
		owl.show_shadow = false
		owl.set_direction_index(0)
		holder.add_child(owl)
		holder.add_to_group(&"ambient_owl")
		ambient_owls.append(holder)


func _paint_ladder() -> void:
	for lad in registry.ladders:
		var bottom: Vector2 = lad["bottom"]
		var top: Vector2 = lad["top"]
		var from_rank: int = _rank(lad["from"])
		var to_rank: int = _rank(lad["to"])
		var tile_h: float = float((ArtCatalog.prop(&"ladder_tile")["size"] as Vector2).y)
		var tile_w: float = float((ArtCatalog.prop(&"ladder_tile")["size"] as Vector2).x)
		var length: float = bottom.y - top.y
		var host: Node2D = _container(objects, "Ladder_%s" % lad["id"], bottom, from_rank)
		# the lane's bottom is a tile boundary, so the rungs read the same from either end
		_tiled(host, &"ladder_tile", Vector2(-tile_w * 0.5, -length), Rect2(0.0, fposmod(tile_h - fposmod(length, tile_h), tile_h), tile_w, length))
		# above the Upper deck's rim the ladder is drawn again (one rank under the deck) so the rim does not swallow the top rungs
		var cap_len: float = maxf(LevelStage.CAP_RUNGS_TO * k - top.y, 0.0)
		if cap_len > 0.0:
			var cap: Node2D = _container(area, "LadderCap_%s" % lad["id"], Vector2(bottom.x, top.y), to_rank - 2)
			_tiled(cap, &"ladder_tile", Vector2(-tile_w * 0.5, 0.0), Rect2(0.0, fposmod(tile_h - fposmod(length, tile_h), tile_h), tile_w, cap_len))


## The Skovlift: V3's RopeLift moves the basket (its stub rope is hidden); the rope is V5's tile, the pulley hangs at the top.
func _paint_lift() -> void:
	for lift in stage.lifts:
		if lift.rope != null:
			lift.rope.visible = false
		var rope_w: float = float((ArtCatalog.prop(&"rope_tile")["size"] as Vector2).x)
		var rank: int = LuaData.int_of(LuaData.dict(data.get("decor_ranks", {})).get("lift_rope", 125), 125)
		var span: float = lift.basket_pos.y - lift.top_pos.y
		_tiled(objects, &"rope_tile", lift.top_pos + Vector2(-rope_w * 0.5, 0.0), Rect2(0.0, 0.0, rope_w, span), rank)
		_spr(objects, &"lift_pulley", lift.top_pos, rank + 1)


# ------------------------------------------------------------------ warps, signs, landmarks, the lift gate

func _make_warps() -> void:
	for st in registry.stubs:
		var ex: Dictionary = st["exit"]
		var path: PackedVector2Array = st["path"]
		var w := Warp2D.new()
		w.name = "Warp_%s" % st["id"]
		w.setup({"to": str(ex["area"]), "spawn": str(ex["spawn"]), "label": str(ex["label"]), "r": WARP_REACH}, area, Vector2i.ZERO)
		w.position = path[path.size() - 1]
		area.triggers.add_child(w)
		warps.append(w)


func _make_signs() -> void:
	for sd in SIGNS:
		var s: Dictionary = sd
		var at: Vector2 = _w(s["at"])
		var host: Node2D = _container(objects, "Sign_%s" % s["id"], at, _rank(s["level"]))
		_spr(host, &"signpost")
		var it := Interactable2D.new()
		it.name = "SignRead_%s" % s["id"]
		it.prompt_key = "UI_READ"
		it.radius = SIGN_RADIUS
		var key: String = str(s["key"])
		it.interacted.connect(func(_p: Node) -> void: EventBus.whisper_requested.emit(key))
		host.add_child(it)
		signs.append(it)


func _make_landmarks() -> void:
	for lm in registry.landmarks:
		var trig := LandmarkTrigger.new()
		trig.name = "Landmark_%s" % lm["id"]
		trig.landmark_id = lm["id"]
		trig.name_key = str(lm["name_key"])
		trig.level_id = lm["level"]
		trig.radius = lm["r"]
		trig.number = int(lm["n"])
		trig.position = lm["centre"]
		area.triggers.add_child(trig)
		landmarks.append(trig)


## The lift of the stage answers only through the gate: the unlock day (adventure.dark_forest_unlock_day, read like the old warp's req_day), the
## defensive TRAE_LIFT_CLOSED when the hub is not registered, then V3's ride.
func _gate_lift() -> void:
	if stage.lifts.is_empty():
		return
	var lift: RopeLift = stage.lifts[0]
	lift.set_enabled(false)
	lift_gate = LiftGate.new()
	lift_gate.name = "LiftGate"
	lift_gate.lift = lift
	lift_gate.position = lift.position
	area.triggers.add_child(lift_gate)


# ------------------------------------------------------------------ markers

## Every marker of the city: through its handler when one exists (IsoArea.resolve_handler), else skipped silently and counted (area.skipped_markers);
## the npc markers of a city without P14 get the labelled preview citizens. Each marker is recorded in area.markers like the grid maps do.
func _place_markers() -> void:
	var all: Array[Dictionary] = CityData.markers(data)
	var npcs: Array[Dictionary] = []
	for m in all:
		var type: String = str(m["type"])
		var rec: Dictionary = {"type": type, "params": m["params"], "cell": Vector2i.ZERO, "pos": m["at"], "char": "", "node": null, "nodes": []}
		match type:
			"lift":
				rec["node"] = stage.lifts[0] if not stage.lifts.is_empty() else null
				rec["builtin_data"] = true
			"climb":
				rec["node"] = stage.lanes[0] if not stage.lanes.is_empty() else null
				rec["builtin_data"] = true
			"ambient_owl":
				rec["builtin_data"] = true
			_:
				if type == "npc":
					npcs.append(m)
				var h: Dictionary = IsoArea.resolve_handler(type)
				var node: Node = null
				if str(h["kind"]) == "script":
					node = _from_handler(h, m)
				if node != null:
					_adopt(rec, node, m)
					marker_nodes[str(m["id"])] = node
				else:
					area.skipped_markers[type] = int(area.skipped_markers.get(type, 0)) + 1
		area.markers.append(rec)
	citizens_placed = TraetoppenPreviewCitizens.attach(area, npcs, data, registry)
	preview_hints = TraetoppenPreviewCitizens.attach_hints(area)


## The three entry points IsoArea._make_from_script knows (create_marker / create(params, pos) / create(params) / setup_marker).
func _from_handler(h: Dictionary, m: Dictionary) -> Node:
	var s: Script = h["script"]
	var params: Dictionary = (m["params"] as Dictionary).duplicate()
	var pos: Vector2 = m.get("pose", m["at"]) as Vector2
	match str(h["mode"]):
		"create_marker":
			return s.call("create_marker", params, pos, Vector2i.ZERO, area) as Node
		"create2":
			return s.call("create", params, pos) as Node
		"create1":
			return s.call("create", params) as Node
		"setup_marker":
			var inst: Object = s.new()
			if inst is Node:
				inst.call("setup_marker", params, pos, Vector2i.ZERO, area)
				return inst as Node
			if inst != null and not (inst is RefCounted):
				inst.free()
	return null


## Adopts what a handler made (the lines of IsoArea._adopt_marker_node) and puts it at its place in the draw order: a body is levelled by the
## LevelTracker from its position; a figure that stands where no level holds the position (the sketch draws Hoppe, Brumme and Sofus in front of
## a trunk, a pile of logs, the tub: inside their keep-outs) is put on its level by the data once (the tracker keeps a level while the
## position has none, and re-derives it as soon as the figure walks out); a figure in a trunk hole is drawn above the hole decals and
## locked; plain and static nodes take the rank of their level.
func _adopt(rec: Dictionary, node: Node, m: Dictionary) -> void:
	if node.get_parent() == null:
		objects.add_child(node)
	if node is Node2D:
		var n2: Node2D = node as Node2D
		var pos: Vector2 = m.get("pose", m["at"]) as Vector2
		n2.global_position = pos
		var level_id: StringName = StringName(str(m["level"]))
		var lv: Level = registry.get_level(level_id)
		if bool(m["window"]):
			n2.z_index = LuaData.int_of(LuaData.dict(data.get("decor_ranks", {})).get("owl_holes", 175), 175) + 1
			ActorLevel.lock(n2, &"window")
		elif node is CharacterBody2D:
			if lv != null and registry.level_at(pos) == null:
				ActorLevel.set_level(n2, lv)
		elif lv != null:
			n2.z_index = lv.rank
	rec["node"] = node
	rec["nodes"] = [node]
	if area.has_method("_track_when"):
		area.call("_track_when", m["params"], [node])


# ------------------------------------------------------------------ inner nodes

## One circle of the ten landmarks (design 4.4): emits game_event(&"landmark_entered", {id, name_key}) ONCE per visit, when the player stands inside the
## circle on the landmark's level (a position is only a level of the registry, so the Rådhus circle does not fire for a walker on the Torvet below).
class LandmarkTrigger extends Node2D:
	var landmark_id: StringName = &""
	var name_key: String = ""
	var level_id: StringName = &""
	var radius: float = 0.0
	var number: int = 0
	var entered: bool = false
	var _player_ref: Node2D = null

	func _physics_process(_delta: float) -> void:
		if entered:
			return
		var p: Node2D = null
		if is_instance_valid(_player_ref):
			p = _player_ref
		else:
			var tree: SceneTree = get_tree()
			p = tree.get_first_node_in_group("player") as Node2D if tree != null else null
			_player_ref = p
		if p == null or p.global_position.distance_to(global_position) > radius or ActorLevel.level_id(p) != level_id:
			return
		entered = true
		set_physics_process(false)
		EventBus.game_event.emit(&"landmark_entered", {"id": String(landmark_id), "name_key": name_key})


## E at the rim of tree B: the Skovlift behind its gates (see CityBuilder._gate_lift).
class LiftGate extends Interactable2D:
	var lift: RopeLift

	func _init() -> void:
		prompt_key = "LEVEL_PROMPT_LIFT"
		radius = RopeLift.STAND_RADIUS

	func interact(player: Node) -> void:
		if not is_enabled() or lift == null:
			return
		var gm: Node = GameData.gm()
		var day: int = int(gm.call("total_day")) if gm != null and gm.has_method("total_day") else 1
		if day < int(GameData.cfg("adventure.dark_forest_unlock_day", 1)):
			EventBus.whisper_requested.emit("TRAE_LIFT_LOCKED")
			return
		if not WorldRoot2D.has_area(lift.target()["area"] as StringName):
			EventBus.whisper_requested.emit("TRAE_LIFT_CLOSED")
			return
		lift.ride(player)


## The additive night layers of the huts follow DayNight.glow_changed like LevelGlow's halos (connected in _enter_tree, released in _exit_tree).
class NightFx extends Node:
	var layers: Array[CanvasItem] = []
	var factor: float = 0.0
	var connected_to: Object = null

	func collect(city: CityBuilder) -> void:
		for id in city.huts:
			var night_layer: Node = (city.huts[id] as Node).get_node_or_null("Night")
			if night_layer is CanvasItem:
				layers.append(night_layer as CanvasItem)
		if connected_to != null:
			set_factor(float((connected_to as Object).get("glow_factor")))

	func _enter_tree() -> void:
		var tree: SceneTree = get_tree()
		var w: Node = tree.get_first_node_in_group("world_2d") if tree != null else null
		if w != null and w.get("day_night") != null:
			connected_to = w.get("day_night")
			if not (connected_to as Object).is_connected("glow_changed", set_factor):
				(connected_to as Object).connect("glow_changed", set_factor)

	func _exit_tree() -> void:
		if connected_to != null and is_instance_valid(connected_to) and (connected_to as Object).is_connected("glow_changed", set_factor):
			(connected_to as Object).disconnect("glow_changed", set_factor)
		connected_to = null

	func set_factor(f: float) -> void:
		factor = clampf(f, 0.0, 1.0)
		for l in layers:
			if is_instance_valid(l):
				var c: Color = l.modulate
				c.a = factor
				l.modulate = c
				l.visible = factor > 0.004


## The leafy frame at the top edge of the screen (CanvasLayer 3): V5's canopy strip, drawn at viewport_width / 2048. It GIVES WAY when the camera
## zooms out: at the game zoom (0.4) its fringe takes FRACTION_FULL of the screen height, at the area's minimum zoom (0.2, the whole composition of
## the sketch) only FRACTION_MIN, so the top platforms A and B (disc tops at 252 and 402 world px, huts above) stay in view under it; in between it
## follows the zoom linearly. The strip is opaque art (V5), so what is not shown is slid out of the top of the screen, not faded.
class CanopyFrame extends CanvasLayer:
	const FRACTION_FULL := 0.16
	const FRACTION_MIN := 0.04
	const ZOOM_FULL := 0.4
	const ZOOM_MIN := 0.2
	var strip: Texture2D
	var sprite: Sprite2D
	var fraction: float = FRACTION_FULL
	var _zoom: float = -1.0
	var _view: Vector2 = Vector2.ZERO

	## The share of the screen height the fringe takes at a camera zoom (clamped to the two ends).
	static func fraction_for(zoom: float) -> float:
		return lerpf(FRACTION_MIN, FRACTION_FULL, clampf((zoom - ZOOM_MIN) / (ZOOM_FULL - ZOOM_MIN), 0.0, 1.0))

	func _ready() -> void:
		sprite = Sprite2D.new()
		sprite.name = "Strip"
		sprite.texture = strip
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(sprite)
		_fit()

	func _process(_delta: float) -> void:
		if _zoom != _camera_zoom() or _view != get_viewport().get_visible_rect().size:
			_fit()

	func _camera_zoom() -> float:
		var cam: Camera2D = get_viewport().get_camera_2d()
		return cam.zoom.x if cam != null else ZOOM_FULL

	## Drawn at viewport_width / 2048 (V5); the strip is 320 px tall at that scale (200 px of a 720 px screen), of which the top part is flat green with
	## no information, so the strip is slid up until the leafy fringe takes `fraction` of the screen height (the sketch's frame is about 11 percent).
	func _fit() -> void:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_zoom = _camera_zoom()
		_view = vp
		fraction = fraction_for(_zoom)
		var s: float = vp.x / 2048.0
		sprite.scale = Vector2.ONE * s
		sprite.position = Vector2(0.0, minf(vp.y * fraction - float(strip.get_height()) * s, 0.0))

	## The screen y of the canopy's lower edge (what must stay clear of the platforms).
	func bottom_edge() -> float:
		return sprite.position.y + float(strip.get_height()) * sprite.scale.y
