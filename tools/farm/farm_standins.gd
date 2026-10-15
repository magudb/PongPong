extends RefCounted
## STAND-INS for handlers that OTHER packages own, so the farm map can be tested and LOOKED AT before they land (package N01).
## Used only by tests/sections/maps_farm.gd and tools/farm/farm_shot.gd. They are NOT marker handlers: nothing registers them in
## lua/config/marker_handlers.lua, the game never loads this file, and a real handler that appears later is simply used instead
## (the callers ask IsoArea.resolve_handler(type) first and only stand in for types that resolve to "none").
##
##   home          F6  HomeExterior2D   the house sprite of a tier at the door anchor + its padded footprint collider (home.json contract)
##   tent          F6                   the tent prop on its marker cell
##   mailbox / shipping_bin / tool_shed   N02 / V6   the marker's `prop=` art on its cell (so the colliders exist for the walk tests)
##   field_expansion   N02              a stake sign + the ring of 22 rope stakes while the zone is locked, and unlock() = the recipe through
##                                      the PUBLIC IsoArea API only (set map ground `f`, area.farmable, set_terrain, remove_prop)
##   field look    P06  FarmView        every farmable cell wears the terrain `field_grass` (the untilled-field look)
##
## No access to a private member of IsoArea happens in this file: maps_farm.gd proves that by reading this source.

const HOME_JSON := "res://assets/iso_props/home/home.json"
const HOME_DIR := "res://assets/iso_props/home/"
## The door-centre anchor of the home art is the cell centre + this (anchor contract of F6): the front plane of the door cell.
const DOOR_ANCHOR := Vector2(-32.0, 19.0)
const FIELD_LOOK := &"field_grass"
const PLACED_PROP_MARKERS: Array[String] = ["mailbox", "shipping_bin", "tool_shed"]

static var _tiers_cache: Array = []


## The ten tiers of assets/iso_props/home/home.json (A1's contract file).
static func home_tiers() -> Array:
	if _tiers_cache.is_empty():
		var f := FileAccess.open(HOME_JSON, FileAccess.READ)
		if f != null:
			var j: Variant = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_tiers_cache = (j as Dictionary).get("tiers", []) as Array
	return _tiers_cache


static func anchor_of(door_cell: Vector2i) -> Vector2:
	return Iso.iso_center(door_cell) + DOOR_ANCHOR


## The padded footprint polygon of a tier in layer-local screen px relative to the anchor (what F6's body is: footprint_rect padded 20 ground px).
static func footprint_polygon(tier: int, pad: float = 20.0) -> PackedVector2Array:
	var fr: Array = (home_tiers()[tier - 1] as Dictionary)["footprint_rect"]
	var corners: Array = [Vector2(fr[0], fr[1]), Vector2(fr[2], fr[1]), Vector2(fr[2], fr[3]), Vector2(fr[0], fr[3])]
	var ground := PackedVector2Array()
	for c in corners:
		var v: Vector2 = c
		ground.append(Iso.to_ground(Vector2((v.x - v.y) * 64.0, (v.x + v.y) * 38.0)))
	var grown: Array = Geometry2D.offset_polygon(ground, pad, Geometry2D.JOIN_MITER)
	var out := PackedVector2Array()
	for p in grown[0]:
		out.append(Iso.to_screen(p))
	return out


## The house of `tier` at the door cell: the day sprite (+ the additive night layer when asked) sorted by home.json `ysort` and the padded
## footprint collider on the world layer. Added to area.objects. Returns the holder node (queue_free it to remove the house).
static func place_home(area: IsoArea, tier: int, door_cell: Vector2i, with_art: bool = true, with_night: bool = false) -> Node2D:
	var t: Dictionary = home_tiers()[tier - 1]
	var ex: Dictionary = t["exterior"]
	var ys := Vector2(float((ex["ysort"] as Array)[0]), float((ex["ysort"] as Array)[1]))
	var holder := Node2D.new()
	holder.name = "HomeStandin_t%02d" % tier
	holder.position = anchor_of(door_cell) + ys                       # layer-local, the convention of place_prop()
	if with_art:
		var pivot := Vector2(float((ex["pivot"] as Array)[0]), float((ex["pivot"] as Array)[1]))
		var spr := Sprite2D.new()
		spr.texture = load(HOME_DIR + str(ex["day"])) as Texture2D
		spr.centered = false
		spr.offset = -pivot - ys
		holder.add_child(spr)
		if with_night and str(ex.get("night", "")) != "":
			var ns := Sprite2D.new()
			ns.texture = load(HOME_DIR + str(ex["night"])) as Texture2D
			ns.centered = false
			var no: Array = ex.get("night_offset", [0, 0])
			ns.offset = -pivot - ys + Vector2(float(no[0]), float(no[1]))
			ns.material = Glow.additive_material()
			holder.add_child(ns)
	var body := StaticBody2D.new()
	body.name = "HomeBody"
	body.collision_layer = Iso.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for p in footprint_polygon(tier):
		pts.append(p - ys)
	sh.points = pts
	cs.shape = sh
	body.add_child(cs)
	holder.add_child(body)
	area.objects.add_child(holder)
	return holder


## Marker types whose handler package has not landed: IsoArea.resolve_handler(type).kind == "none".
static func unhandled(area: IsoArea, type: String) -> bool:
	return str(IsoArea.resolve_handler(type).get("kind", "none")) == "none" and not area.marker_handlers.has(type)


## Places the props of the data markers nobody handles yet (tent, mailbox, bin, shed, the stake sign of the expansion) and the rope ring of
## every LOCKED expansion zone. Returns {"nodes": Array[Node], "ropes": {zone id: Array[Node2D]}, "zones": {zone id: Array[Vector2i]},
## "stand_in_for": Array[String] of the marker types that were stood in for}.
static func place_yard(area: IsoArea) -> Dictionary:
	var out: Dictionary = {"nodes": [], "ropes": {}, "zones": {}, "stand_in_for": []}
	var stood: Dictionary = {}
	for rec in area.markers:
		var type: String = str(rec["type"])
		var params: Dictionary = rec["params"]
		var cell: Vector2i = rec["cell"]
		var prop_id: String = ""
		if type == "tent":
			prop_id = "tent"
		elif type in PLACED_PROP_MARKERS:
			prop_id = str(params.get("prop", ""))
		elif type == "field_expansion":
			prop_id = "stake_sign"
		if prop_id == "" or not unhandled(area, type):
			continue
		stood[type] = true
		var node: Node2D = area.place_prop(prop_id, cell)
		(out["nodes"] as Array).append(node)
		if type == "field_expansion":
			var id: String = str(params.get("id", ""))
			var problems: Array[String] = []
			var cells: Array[Vector2i] = IsoArea.parse_cells(str(params.get("cells", "")), Vector2i(area.map.width, area.map.height), problems)
			(out["zones"] as Dictionary)[id] = cells
			(out["ropes"] as Dictionary)[id] = _rope_ring(area, cells)
	out["stand_in_for"] = stood.keys()
	return out


## A ring of rope stakes on the outermost cells of a zone: `rope_stake_x` on the first / last row, `rope_stake_z` on the first / last column.
static func _rope_ring(area: IsoArea, cells: Array[Vector2i]) -> Array:
	var minx: int = 1 << 30
	var maxx: int = -(1 << 30)
	var miny: int = 1 << 30
	var maxy: int = -(1 << 30)
	for c in cells:
		minx = mini(minx, c.x)
		maxx = maxi(maxx, c.x)
		miny = mini(miny, c.y)
		maxy = maxi(maxy, c.y)
	var ring: Array = []
	for c in cells:
		if c.y == miny or c.y == maxy:
			ring.append(area.place_prop("rope_stake_x", c))
		elif c.x == minx or c.x == maxx:
			ring.append(area.place_prop("rope_stake_z", c))
	return ring


## What buying a field expansion does, through the PUBLIC IsoArea API only (the proof that P04 needs no edit): the zone cells become `f` in
## the map, tillable, wear the field look; the rope props go. Returns the number of cells unlocked.
static func unlock(area: IsoArea, cells: Array, ropes: Array) -> int:
	var n: int = 0
	for c in cells:
		var cell: Vector2i = c
		area.map.set_ground(cell, "f")
		area.farmable[cell] = true
		area.set_terrain(cell, FIELD_LOOK)
		n += 1
	for node in ropes:
		area.remove_prop(node)
	return n


## The untilled look of the field (FarmView.setup does this for every farmable cell, and after an unlock).
static func apply_field_look(area: IsoArea) -> int:
	var n: int = 0
	for c in area.farmable:
		area.set_terrain(c, FIELD_LOOK)
		n += 1
	return n
