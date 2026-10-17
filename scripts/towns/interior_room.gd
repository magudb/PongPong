class_name InteriorRoom
extends RefCounted
## THE WALK-IN INTERIOR BUILDER (T-towns-core, TOWNS addendum 4.4 / DT13). `@builder res://scripts/towns/interior_room.gd` + `@room <id>` in a seven line stub map data/maps/int_<id>.map
## (stub_map() writes it); the room itself is DATA: data/interiors/<core|ext>/<id>.json (schema: data/interiors/schema.json, generator and validator: tools/towns/interiors). Lifted from
## D3/towns_scripts/proto/interior_room.gd. build(area, header) is RE-RUNNABLE: a room is never parked (WorldRoot2D.is_parkable) and is rebuilt on every enter.
##
## Cells: x = column (+x = screen lower-right), z = row (+z = screen lower-left), z = 0 is the back wall row, the door is on the last row (Iso.iso_center maths).
## What is built: the floor atlas (AreaTileSet), two cut-away back walls and a corner (the wall styles of assets/iso_props/interior/interior.json, windows with night layers that fade with the
## OUTDOOR hour), the doormat, two warm lamps, the pieces (PieceCatalog: baked kit > furniture.json > stand-in > labelled box; true rotations, baked y-sort, a footprint collider per floor
## piece), the invisible hatch bars on the NPC layer (+ the baked counter_hatch piece when it exists), the exit door (always open), the counter hosts (ShopCounter) or the handler nodes of
## V6 (bath / board / mailbox), a ShopHours node when the building has hours or an owner, the camera bounds (the visual box + 40 px) and zoom (zoom_fit), the spawn `default` in front of
## the door. data/interiors/dress/int_<id>.json (items, owner I4) is merged after the items of the room when it exists.

const PROPS := "res://assets/iso_props/"
const INTERIOR_JSON := PROPS + "interior/interior.json"
const HALF_W := 64.0
const HALF_H := 38.0
const WALL_Z := -1                      # walls and corner: behind every actor
const BOUNDS_PAD := 40.0
const COUNTER_KINDS: Array[String] = ["shop", "post_counter", "bar", "appraisal", "desk", "talk"]
const HANDLER_KINDS: Array[String] = ["bath", "board", "mailbox"]

## Where the room specs live: data/interiors/core and ext (T-interiors-core, T-ext-content); tests point it at fixtures with use_spec_dirs().
static var spec_dirs: Array[String] = ["res://data/interiors/core/", "res://data/interiors/ext/"]
static var dress_dir: String = "res://data/interiors/dress/"
## Statistics of the last build (tests and the budget check read them): sprites (walls, corner, doormat, pieces), night (the additive window night layers), bodies, lights, nodes ...
static var stats: Dictionary = {}

static var _specs: Dictionary = {}
static var _dress: Dictionary = {}
static var _json: Dictionary = {}


static func cell_local(cx: float, cz: float) -> Vector2:
	return Vector2((cx - cz) * HALF_W + HALF_W, (cx + cz) * HALF_H + HALF_H)


static func use_spec_dirs(dirs: Array[String], p_dress_dir: String = "res://data/interiors/dress/") -> void:
	spec_dirs = dirs.duplicate()
	dress_dir = p_dress_dir
	reset_cache()


static func reset_cache() -> void:
	_specs.clear()
	_dress.clear()
	_json.clear()


## The room spec of an id (`int_bageriet`), {} when no directory has it.
static func load_spec(id: String) -> Dictionary:
	if not _specs.has(id):
		var spec: Dictionary = {}
		for dir in spec_dirs:
			var p: String = dir + id + ".json"
			if FileAccess.file_exists(p):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
				if parsed is Dictionary:
					spec = parsed
					break
		_specs[id] = spec
	return _specs[id]


## The overlay items of a room (data/interiors/dress/<id>.json {items}), [] when there is none.
static func load_dress(id: String) -> Array:
	if not _dress.has(id):
		var items: Array = []
		var p: String = dress_dir + id + ".json"
		if FileAccess.file_exists(p):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary and (parsed as Dictionary).get("items", null) is Array:
				items = (parsed as Dictionary)["items"]
		_dress[id] = items
	return _dress[id]


## The room's own items followed by its dressing overlay.
static func items_of(spec: Dictionary) -> Array:
	var all: Array = (spec.get("items", []) as Array).duplicate()
	all.append_array(load_dress(str(spec.get("id", ""))))
	return all

## Pure file planning for the world's fade/approach prefetch; no textures load.
static func art_paths(id: String) -> Array[String]:
	var spec := load_spec(id)
	var paths: Dictionary = {}
	if spec.is_empty():
		return []
	for item in items_of(spec):
		var piece := PieceCatalog.resolve(str(item.id), int(item.get("rot", 0)))
		for key in ["file", "night"]:
			if str(piece.get(key, "")) != "":
				paths[str(piece[key])] = true
	var floor := ArtCatalog.terrain_metadata(StringName(str(spec.floor)))
	if not floor.is_empty():
		paths[str(floor._dir)+str(floor.file)] = true
	var common := _json_of(INTERIOR_JSON)
	for group in common.values():
		if group is Dictionary:
			for row in group.values():
				if row is Dictionary:
					for key in ["file", "night"]:
						if str(row.get(key, "")) != "":
							paths[PROPS+"interior/"+str(row[key])] = true
	var result: Array[String] = []
	for path in paths:
		result.append(str(path))
	return result


## The stub map text of a room (data/interiors stay data; the seven lines the area registry reads). zone: the outer area's zone id (city for Hyggebyen, traetoppen for the city).
static func stub_map(room_id: String, building: String, zone: String) -> String:
	return "@id %s\n@title BLD_%s\n@projection iso\n@ambient home\n@zone %s\n@builder res://scripts/towns/interior_room.gd\n@room %s\n" % [room_id, building.to_upper(), zone, room_id]


## F6's own formula: the camera zoom that fits the room.
static func zoom_fit(cols: int, rows: int) -> float:
	var n: float = float(cols + rows)
	return 0.85 * minf(1280.0 / (n * 64.0), 720.0 / (n * 38.0 + 280.0))


static func _json_of(path: String) -> Dictionary:
	if not _json.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_json[path] = parsed if parsed is Dictionary else {}
	return _json[path]


# ------------------------------------------------------------------------------------------------ the builder

static func build(area: IsoArea, header: Dictionary) -> void:
	var t0: int = Time.get_ticks_usec()
	var extra: Dictionary = header.get("extra", {}) as Dictionary
	var id: String = str(extra.get("room", header.get("id", "")))
	var spec: Dictionary = load_spec(id)
	if spec.is_empty():
		area.builder_error = "no room spec %s" % id
		return
	var cols: int = int(spec["cols"])
	var rows: int = int(spec["rows"])
	var building: String = str(spec.get("building", ""))
	var st: Dictionary = {"sprites": 0, "night": 0, "bodies": 0, "lights": 0, "furniture": 0, "walls": 0, "hatch": 0, "stand_ins": 0, "placeholders": 0, "counters": 0, "handlers": 0, "pieces": 0, "accent_masks": 0, "service_lights": 0}
	var inter: Dictionary = _json_of(INTERIOR_JSON)
	var walls: Dictionary = inter.get("walls", {}) as Dictionary
	var night_sprites: Array[Sprite2D] = []
	# --- floor
	var sid: int = AreaTileSet.source_for(&"iso", StringName(str(spec["floor"])))
	for z in rows:
		for x in cols:
			area.ground.set_cell(Vector2i(x, z), sid, Iso.atlas_coords(Vector2i(x, z)))
	# --- the two cut-away back walls + the corner
	var style: String = str(spec["wall_style"])
	var windows: Dictionary = spec.get("windows", {}) as Dictionary
	var wz: Array = windows.get("z", []) as Array
	var wx: Array = windows.get("x", []) as Array
	for x in cols:
		_wall(area, walls, style, "win" if _has_int(wz, x) else ("b" if x % 2 == 0 else "a"), 0, Vector2(float(x), -0.5), st, night_sprites)
	for z in rows:
		_wall(area, walls, style, "win" if _has_int(wx, z) else ("b" if z % 2 == 0 else "a"), 1, Vector2(-0.5, float(z)), st, night_sprites)
	var corner: Dictionary = walls.get("corner_%s" % style, {}) as Dictionary
	if not corner.is_empty():
		_sprite(area.objects, corner, PROPS + "interior/", cell_local(-0.5, -0.5)).z_index = WALL_Z
		st["sprites"] += 1
	var door: Vector2i = _cell_of(spec["door"]["cell"])
	var mat: Dictionary = (inter.get("door", {}) as Dictionary).get("doormat_r0", {}) as Dictionary
	if not mat.is_empty():
		_sprite(area.ground_fx, mat, PROPS + "interior/", cell_local(float(door.x), float(door.y)))
		st["sprites"] += 1
	# --- the pieces (the room's own, then the dressing overlay)
	for it in spec.get("items", []):
		_item(area, it as Dictionary, st)
	st["base_sprites"] = st["sprites"]
	for it in load_dress(id):
		_item(area, it as Dictionary, st)
	# --- the hatch: invisible bars on the NPC layer between the counter ends and the side walls (the player is stopped, citizens pass)
	var hatch_art: Dictionary = {}
	if PieceCatalog.kit_manifest().has("counter_hatch"):
		hatch_art = PieceCatalog.resolve("counter_hatch", 0)             # the baked piece; nothing is drawn while it does not exist
	for mk in spec.get("markers", []):
		if str((mk as Dictionary)["type"]) == "hatch":
			for c in (mk as Dictionary)["cells"]:
				var hc: Vector2i = _cell_of(c)
				_hatch_cell(area, hc)
				st["hatch"] += 1
				if not hatch_art.is_empty() and str(hatch_art["file"]) != "":
					_piece_sprite(area, hatch_art, hc, 1, 1, st)
	# --- two lamps (the `home` ambient keeps rooms warm)
	for i in 2:
		var p: Vector2 = cell_local(float(cols) * (0.3 + 0.4 * float(i)), float(rows) * 0.45) + Vector2(0, -150)
		var l := PointLight2D.new()
		l.texture = Glow.light_texture()
		l.texture_scale = 280.0 / 128.0
		l.color = Color("ffd98a")
		# Two additive key lights overlap the counter. The old 0.6 clipped
		# pastel faces and paper grain to white even in daylight.
		l.energy = 0.12
		l.position = p
		area.objects.add_child(l)
		var halo := Sprite2D.new()
		halo.texture = Glow.halo_texture()
		halo.position = p
		halo.modulate = Color(1.0, 0.85, 0.5, 0.5)
		halo.material = Glow.additive_material()
		area.objects.add_child(halo)
		st["lights"] += 1
	# --- the exit door (always open: closing time evicts, it never traps)
	var exit_info: Dictionary = spec["exit"] as Dictionary
	var warp := Door2D.new()
	warp.always_open = true
	warp.building_id = building
	warp.setup({"to": str(exit_info["area"]), "spawn": str(exit_info["spawn"]), "label": ""}, area, door)
	warp.name = "ExitDoor"
	warp.position = cell_local(float(door.x), float(door.y)) + Vector2(0, 40)
	area.triggers.add_child(warp)
	# --- the counter hosts and the handler markers
	for mk in spec.get("markers", []):
		_marker(area, mk as Dictionary, building, st)
	# --- opening hours / eviction
	var row: Dictionary = Hours.building(building)
	if row.has("hours") or row.has("owner"):
		var sh := ShopHours.new()
		sh.setup(building, str(spec["id"]), str(exit_info["area"]), str(exit_info["spawn"]))
		area.add_child(sh)
	if not night_sprites.is_empty():
		var wc := WindowClock.new()
		wc.name = "WindowClock"
		wc.sprites = night_sprites
		area.add_child(wc)
	# --- camera + spawns (bounds = the VISUAL box + 40 px, so a view that is larger than the room is centred)
	var minx: float = cell_local(0.0, float(rows - 1)).x - HALF_W
	var maxx: float = cell_local(float(cols - 1), 0.0).x + HALF_W
	var miny: float = -212.0
	var maxy: float = cell_local(float(cols - 1), float(rows - 1)).y + HALF_H
	area.bounds = Rect2(minx - BOUNDS_PAD, miny - BOUNDS_PAD, (maxx - minx) + 2.0 * BOUNDS_PAD, (maxy - miny) + 2.0 * BOUNDS_PAD)
	area.play_rect = Rect2(minx, 0.0, maxx - minx, maxy)
	var sp: Vector2i = _cell_of(spec["spawn_cell"])
	area.spawns["default"] = cell_local(float(sp.x), float(sp.y))
	area.spawns["from_street"] = area.spawns["default"]
	var zf: float = zoom_fit(cols, rows)
	area.zoom_default = zf
	area.zoom_range = Vector2(minf(0.35, zf), maxf(1.2, zf))
	var walk_rect := Rect2(minx, 0.0, maxx - minx, maxy)
	area.walkable_test = func(p: Vector2) -> bool: return walk_rect.has_point(p)
	# posts for the citizens (the room director's anchors): name -> global px
	var posts: Dictionary = {"door": cell_local(float(door.x), float(door.y))}
	for p in spec.get("posts", []):
		posts[str((p as Dictionary)["id"])] = cell_local(float((p["cell"] as Array)[0]), float((p["cell"] as Array)[1]))
	area.set_meta("posts", posts)
	area.set_meta("room_spec", spec)
	var floor_surface := "stone" if str(spec.get("floor","")).contains("stone") or str(spec.get("floor","")).contains("tile") else "wood"
	area.set_meta("surface_fn",func(_position: Vector2) -> String:return floor_surface)
	if bool(area.get_meta("town_population_enabled", true)):
		Svc.static_call("res://scripts/towns/town_director.gd", &"attach_room", [area, spec])
	st["build_us"] = Time.get_ticks_usec() - t0
	st["zoom_fit"] = zf
	st["nodes"] = _count_nodes(area)
	stats = st


static func _count_nodes(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c


static func _cell_of(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


static func _has_int(list: Array, value: int) -> bool:
	for x in list:
		if int(x) == value:
			return true
	return false


static func _sprite(parent: Node, meta: Dictionary, base: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = PieceCatalog.texture(base + str(meta["file"]))
	s.centered = false
	s.offset = -Vector2(float((meta["pivot"] as Array)[0]), float((meta["pivot"] as Array)[1]))
	s.position = pos
	parent.add_child(s)
	return s


static func _wall(area: IsoArea, walls: Dictionary, style: String, kind: String, r: int, c: Vector2, st: Dictionary, night: Array[Sprite2D]) -> void:
	var key: String = "wall_%s_%s_r%d" % [style, kind, r]
	if not walls.has(key):
		return
	var meta: Dictionary = walls[key]
	var s: Sprite2D = _sprite(area.objects, meta, PROPS + "interior/", cell_local(c.x, c.y))
	s.z_index = WALL_Z
	st["walls"] += 1
	st["sprites"] += 1
	if meta.has("night"):
		var o := Sprite2D.new()
		o.texture = PieceCatalog.texture(PROPS + "interior/" + str(meta["night"]))
		o.centered = false
		o.offset = s.offset
		o.position = s.position
		o.material = Glow.additive_material()
		o.modulate = Color(0.55, 0.7, 1.0, 0.0)
		o.z_index = WALL_Z
		o.add_to_group("window_night")           # faded by the room's WindowClock with the OUTDOOR hour, not by the `home` preset
		area.objects.add_child(o)
		night.append(o)
		st["night"] += 1                     # the additive night layer of a window is counted apart: `sprites` is the walls, corner, doormat and pieces (the design's own count: p50 25, max 31 over the 24 rooms)


## One piece of the room: sprite (layer rug on the floor fx, wall on the wall plane, the rest y-sorted in Objects) and, for a floor piece, the footprint collider on the world layer.
static func _item(area: IsoArea, it: Dictionary, st: Dictionary) -> void:
	var id: String = str(it["id"])
	var rot: int = int(it.get("rot", 0))
	var pc: Dictionary = PieceCatalog.resolve(id, rot)
	var fp: Vector2i = pc["footprint"]
	var cx: int = int((it["cell"] as Array)[0])
	var cz: int = int((it["cell"] as Array)[1])
	var layer: String = str(pc["layer"])
	st["pieces"] += 1
	if str(pc["source"]) == "stand_in":
		st["stand_ins"] += 1
	elif str(pc["source"]) == "placeholder":
		st["placeholders"] += 1
	if layer == "wall":
		# hung on the back wall: rotation 0 on the back-right wall edge (z = -0.5), rotation 1 on the back-left one (x = -0.5); the pivot is the ground anchor below the piece
		var wp: Vector2 = cell_local(float(cx), -0.5) if rot % 2 == 0 else cell_local(-0.5, float(cz))
		var ws: Sprite2D = _make_piece_sprite(pc, id)
		if ws != null:
			ws.position = wp
			ws.z_index = WALL_Z
			area.objects.add_child(ws)
			_piece_light(area, ws, pc, st)
			st["sprites"] += 1
		return
	var centre: Vector2 = cell_local(float(cx) + float(fp.x - 1) * 0.5, float(cz) + float(fp.y - 1) * 0.5)
	var spr: Sprite2D = _make_piece_sprite(pc, id)
	if spr != null:
		var ys: Vector2 = pc["ysort"]
		spr.offset -= ys                              # the node sits at the sort point (centre + ysort), the pixels stay where the art puts them
		spr.position = centre + ys
		if layer == "rug":
			area.ground_fx.add_child(spr)
		else:
			if layer == "ceiling":
				spr.z_index = 2
			area.objects.add_child(spr)
		_piece_light(area, spr, pc, st)
		st["sprites"] += 1
		if layer != "rug":
			st["furniture"] += 1
	if layer == "floor":
		var body := StaticBody2D.new()
		body.name = "Piece_%s_%d_%d" % [id, cx, cz]
		body.collision_layer = Iso.LAYER_WORLD
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := ConvexPolygonShape2D.new()
		sh.points = Iso.iso_footprint(Vector2i(cx + fp.x - 1, cz + fp.y - 1), fp.x, fp.y)
		cs.shape = sh
		body.add_child(cs)
		area.colliders.add_child(body)
		st["bodies"] += 1


## Trimmed painted masks share the body's final offset and sort owner. Their source coordinates already include the mounting height.
static func _piece_light(area: IsoArea, body: Sprite2D, pc: Dictionary, st: Dictionary) -> void:
	if str(pc.get("night", "")) == "":
		return
	var tex := PieceCatalog.texture(str(pc["night"]))
	if tex == null:
		return
	var clock := area.get_node_or_null("PieceLightClock") as PieceLightClock
	if clock == null:
		clock = PieceLightClock.new()
		clock.name = "PieceLightClock"
		area.add_child(clock)
	var mask := Sprite2D.new()
	mask.name = "PaintedLight"
	mask.texture = tex
	mask.centered = false
	mask.material = Glow.additive_material()
	mask.flip_h = body.flip_h
	var trim: Vector2 = pc.get("night_offset", Vector2.ZERO)
	if body.flip_h:
		trim.x = body.texture.get_width() - trim.x - tex.get_width()
	mask.offset = body.offset + trim
	body.add_child(mask)
	clock.accents.append(mask)
	st["accent_masks"] += 1
	var glow: Dictionary = pc.get("glow", {})
	if str(glow.get("light_hint", "")) == "at_most_one_per_room" and int(st["service_lights"]) == 0:
		var light := PointLight2D.new()
		light.name = "ServiceFire"
		light.texture = Glow.light_texture()
		light.texture_scale = 1.25
		light.color = Color(str(glow.get("color", "#ffb36b")))
		var centre := _v2_of(glow.get("center", [0, 0]))
		if body.flip_h:
			centre.x = body.texture.get_width() - centre.x
		light.position = body.offset + centre
		body.add_child(light)
		clock.lights.append(light)
		st["service_lights"] += 1
		st["lights"] += 1
	clock.refresh()


static func _v2_of(v: Array) -> Vector2:
	return Vector2(float(v[0]), float(v[1]))


## The sprite of a resolved piece (pivot at the ground anchor; position and sort point are set by the caller), or null when there is no texture. A placeholder carries its label.
static func _make_piece_sprite(pc: Dictionary, id: String) -> Sprite2D:
	var spr := Sprite2D.new()
	var tex: Texture2D = pc["texture"] as Texture2D if pc.has("texture") else PieceCatalog.texture(str(pc["file"]))
	if tex == null:
		spr.free()
		return null
	spr.texture = tex
	spr.centered = false
	var piv: Vector2 = pc["pivot"]
	if bool(pc.get("flip", false)):
		spr.flip_h = true
		piv.x = float(tex.get_width()) - piv.x
	spr.offset = -piv
	if str(pc["source"]) == "placeholder":
		var label := Label.new()
		label.text = id
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("2b2340"))
		label.size = Vector2(240, 30)
		label.position = Vector2(-120.0, -78.0)           # above the box, centred on the ground anchor (the sprite's origin)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.add_child(label)
	return spr


## A sprite of a resolved piece on one cell (the baked counter_hatch on a hatch cell), y-sorted in Objects.
static func _piece_sprite(area: IsoArea, pc: Dictionary, cell: Vector2i, fx: int, fz: int, st: Dictionary) -> void:
	var spr: Sprite2D = _make_piece_sprite(pc, str(pc["id"]))
	if spr == null:
		return
	var ys: Vector2 = pc["ysort"]
	spr.offset -= ys
	spr.position = cell_local(float(cell.x) + float(fx - 1) * 0.5, float(cell.y) + float(fz - 1) * 0.5) + ys
	area.objects.add_child(spr)
	st["sprites"] += 1


static func _hatch_cell(area: IsoArea, c: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.name = "Hatch_%d_%d" % [c.x, c.y]
	body.collision_layer = Iso.LAYER_NPC
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := ConvexPolygonShape2D.new()
	sh.points = Iso.iso_footprint(c, 1, 1)
	cs.shape = sh
	body.add_child(cs)
	area.colliders.add_child(body)


## One marker of the room JSON: the counter kinds become a ShopCounter; bath / board / mailbox are built by the handler of their own package (V6) through IsoArea.resolve_handler when one
## is registered, and fall back to a ShopCounter of that kind that only announces the use; hatch and door are handled elsewhere.
static func _marker(area: IsoArea, mk: Dictionary, building: String, st: Dictionary) -> void:
	var kind: String = str(mk["type"])
	if kind == "hatch" or kind == "door" or not mk.has("cell"):
		return
	var c: Vector2i = _cell_of(mk["cell"])
	var pos: Vector2 = cell_local(float(c.x), float(c.y))
	if kind in HANDLER_KINDS:
		var node: Node = _handler_node(area, kind, mk, pos, c)
		if node != null:
			if node.get_parent() == null:
				area.objects.add_child(node)
			if node is Node2D and (node as Node2D).position == Vector2.ZERO:
				(node as Node2D).position = pos
			st["handlers"] += 1
			return
	elif kind not in COUNTER_KINDS:
		return
	var host := ShopCounter.new()
	host.setup(kind, mk, building)
	host.position = pos
	area.objects.add_child(host)
	st["counters"] += 1


## The node of a marker type whose handler script is registered (contract: `static func create_marker(params, pos, cell, area) -> Node`), or null.
static func _handler_node(area: IsoArea, kind: String, mk: Dictionary, pos: Vector2, cell: Vector2i) -> Node:
	var h: Dictionary = IsoArea.resolve_handler(kind)
	if str(h.get("kind", "")) != "script" or str(h.get("mode", "")) != "create_marker":
		return null
	var params: Dictionary = mk.duplicate()
	params["marker"] = kind
	return (h["script"] as Script).call("create_marker", params, pos, cell, area) as Node


# ------------------------------------------------------------------------------------------------ the window clock

## The glow (0..1) of the OUTDOOR farm ambient at a raw game hour: lua/config/ambient.lua presets.farm.glow, interpolated like DayNight.glow_at (the hour wraps mod 24).
static func outdoor_glow(hour: float) -> float:
	var rows: Array = GameData.array_of(GameData.cfg("ambient.presets.farm.glow", []))
	var keys: Array[Vector2] = []
	for r in rows:
		if r is Dictionary:
			keys.append(Vector2(float((r as Dictionary).get("hour", 0.0)), float((r as Dictionary).get("v", 0.0))))
	if keys.is_empty():
		return 0.0
	keys.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var hh: float = fposmod(hour, 24.0)
	if hh <= keys[0].x:
		return keys[0].y
	for i in range(keys.size() - 1):
		var a: Vector2 = keys[i]
		var b: Vector2 = keys[i + 1]
		if hh >= a.x and hh <= b.x:
			var t: float = (hh - a.x) / maxf(b.x - a.x, 0.001)
			return lerpf(a.y, b.y, smoothstep(0.0, 1.0, t))
	return keys[keys.size() - 1].y


## Fades the additive night layers of the windows with the OUTDOOR hour (the room's own ambient is always warm).
class WindowClock extends Node:
	var sprites: Array[Sprite2D] = []

	func _ready() -> void:
		EventBus.time_of_day_changed.connect(_on_clock)
		refresh()

	func _exit_tree() -> void:
		if EventBus.time_of_day_changed.is_connected(_on_clock):
			EventBus.time_of_day_changed.disconnect(_on_clock)

	func _on_clock(_hour: int, _minute: int) -> void:
		refresh()

	func refresh() -> void:
		var gm: Node = GameData.gm()
		var hour: float = float(gm.get("hour")) + float(gm.get("minute")) / 60.0 if gm != null else 12.0
		var a: float = InteriorRoom.outdoor_glow(hour) * 0.9
		for s in sprites:
			if is_instance_valid(s):
				s.modulate = Color(0.55, 0.7, 1.0, a)


## A room owns one clock connection for all painted service and decorative masks. Window light keeps its separate cool tint.
class PieceLightClock extends Node:
	var accents: Array[Sprite2D] = []
	var lights: Array[PointLight2D] = []

	func _ready() -> void:
		EventBus.time_of_day_changed.connect(_on_clock)

	func _exit_tree() -> void:
		if EventBus.time_of_day_changed.is_connected(_on_clock):
			EventBus.time_of_day_changed.disconnect(_on_clock)

	func _on_clock(_hour: int, _minute: int) -> void:
		refresh()

	func refresh() -> void:
		var gm := GameData.gm()
		var hour: float = float(gm.get("hour")) + float(gm.get("minute")) / 60.0 if gm != null else 12.0
		var factor := InteriorRoom.outdoor_glow(hour)
		for accent in accents:
			accent.modulate.a = factor
		for light in lights:
			light.energy = factor * 0.08
