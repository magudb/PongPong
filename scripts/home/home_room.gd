class_name HomeRoom
extends Node2D
## One isometric room per home tier: TileMapLayer floor + two cut-away back walls (sprites per tile edge) + furniture on a FurnitureGrid.
## Layer order (bottom -> top):  Floor  Rugs  Walls  WallItems  World(y-sorted: furniture, tabletop, characters)  Ceiling  Glow(additive)  Fx

const CELL := Vector2i(144, 84)
const TILE := Vector2i(128, 76)
const DAY_GLOW := 0.5                      # halos are subtle by day, full strength at night

var tier := 1
var room: Dictionary
var grid := FurnitureGrid.new()
var floor_map: TileMapLayer
var rugs: Node2D
var walls: Node2D
var wall_items: Node2D
var world: Node2D
var ceiling: Node2D
var glow_layer: Node2D
var night := false
var nodes: Dictionary = {}                 # uid -> Node2D
var _glows: Dictionary = {}                # uid -> Array[Sprite2D]
var _floaters: Array = []                  # {node, phase}
var _night_overlays: Array = []
var _wall_style := "plank"
var area: IsoArea
var _t := 0.0


static func build(target: IsoArea, _header: Dictionary) -> void:
	var view := HomeRoom.new()
	view.name = "HomeRoom"
	view.area = target
	target.add_child(view)
	view._build(HomeManager.tier)

func _build(t: int) -> void:
	tier = t
	room = HomeData.room(t)
	_wall_style = room.wall_style
	grid = FurnitureManager.ensure_grid()
	var source := _make_floor()
	floor_map = area.ground
	floor_map.tile_set = source.tile_set
	for c in source.get_used_cells():
		floor_map.set_cell(c, source.get_cell_source_id(c), source.get_cell_atlas_coords(c))
	source.free()
	floor_map.position = -Vector2(HomeData.HALF_W, HomeData.HALF_H)
	floor_map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rugs = _layer("Rugs")
	rugs.z_index = -9
	walls = _layer("Walls")
	walls.z_index = -8
	wall_items = _layer("WallItems")
	wall_items.z_index = -7
	world = area.objects
	ceiling = _layer("Ceiling")
	ceiling.z_index = 4
	glow_layer = _layer("Glow")
	glow_layer.z_index = 5
	_build_walls()
	_build_door()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for c in grid.floor_cells:
		var p := HomeData.cell_to_local(Vector2(c))
		low = low.min(p)
		high = high.max(p)
	area.bounds = Rect2(low - Vector2(240, 320), high - low + Vector2(480, 560))
	area.spawns["default"] = area.to_global(HomeData.cell_to_local(Vector2(grid.spawn_cell)))
	area.zoom_default = float(room.zoom_fit)
	area.zoom_range = Vector2(0.35, 1.2)
	area.walkable_test = func(p: Vector2): return grid.is_walkable(Vector2i(HomeData.local_to_cell(area.to_local(p)).round()))
	_build_collision()
	for uid in grid.placements:
		_draw_placement(uid)
	var exit := Warp2D.new()
	exit.name = "HomeExit"
	exit.setup({"to":"farm","spawn":"from_home","label":"ZONE_FARM","r":-0.2}, area, grid.door_cell)
	exit.position = HomeData.cell_to_local(Vector2(grid.door_cell))
	area.objects.add_child(exit)
	set_night(TimeManager.is_night())

func _build_collision() -> void:
	# Solid boundary on each exposed tile edge, including the front cutaway.
	# The exit trigger is inside the door tile; no collision gap leads to void.
	var body := StaticBody2D.new()
	body.name = "RoomBoundary"
	body.collision_layer = Iso.LAYER_WORLD
	body.collision_mask = 0
	area.add_child(body)
	for c in grid.floor_cells:
		for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if grid.floor_cells.has(c + direction):
				continue
			var midpoint := HomeData.cell_to_local(Vector2(c) + Vector2(direction) * 0.5)
			var edge := HomeData.cell_to_local(Vector2(-direction.y, direction.x)) * 0.5
			var shape := SegmentShape2D.new()
			shape.a = midpoint - edge
			shape.b = midpoint + edge
			var cs := CollisionShape2D.new()
			cs.shape = shape
			body.add_child(cs)


func _layer(n: String) -> Node2D:
	var l := Node2D.new()
	l.name = n
	add_child(l)
	return l


func _make_floor() -> TileMapLayer:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = TILE
	var src_id := 0
	var want: String = room["floor"]
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/iso_tiles/%s.png" % want)
	src.texture_region_size = CELL
	for j in 4:
		for i in 4:
			src.create_tile(Vector2i(i, j))
	src_id = ts.add_source(src)
	var m := TileMapLayer.new()
	m.name = "Floor"
	m.tile_set = ts
	for c in grid.floor_cells:
		m.set_cell(c, src_id, Vector2i(c.x % 4, c.y % 4))
	return m


func _wall_piece(kind: String, axis: String) -> Dictionary:
	var key := "wall_%s_%s_r%d" % [_wall_style, kind, 0 if axis == "z" else 1]
	return (HomeData.interior()["walls"] as Dictionary)[key]


func _sprite_from(meta: Dictionary, base: String, extra_offset := Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = HomeData.tex(base + String(meta["file"]))
	s.centered = false
	s.offset = -Vector2(meta["pivot"][0], meta["pivot"][1]) - extra_offset
	return s


func _build_walls() -> void:
	var base := HomeData.PROPS + "interior/"
	var corner: Dictionary = (HomeData.interior()["walls"] as Dictionary)["corner_%s" % _wall_style]
	for x in int(room["rows"][0]):
		var kind := "win" if grid.window_z.has(x) else ("b" if x % 2 == 0 else "a")
		_add_wall(kind, "z", Vector2(x, -0.5), base)
	for z in room["rows"].size():
		var kind2 := "win" if grid.window_x.has(z) else ("b" if z % 2 == 0 else "a")
		_add_wall(kind2, "x", Vector2(-0.5, z), base)
	var c := _sprite_from(corner, base)
	c.position = HomeData.cell_to_local(Vector2(-0.5, -0.5))
	walls.add_child(c)


func _add_wall(kind: String, axis: String, c: Vector2, base: String) -> void:
	var meta := _wall_piece(kind, axis)
	var s := _sprite_from(meta, base)
	s.position = HomeData.cell_to_local(c)
	walls.add_child(s)
	if meta.has("night"):
		var o := Sprite2D.new()
		o.texture = HomeData.tex(base + String(meta["night"]))
		o.centered = false
		o.offset = s.offset
		o.position = s.position
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		o.material = mat
		o.visible = false
		o.modulate = Color(0.55, 0.7, 1.0, 0.85)      # moonlight through the glass (cool)
		glow_layer.add_child(o)
		_night_overlays.append(o)


func door_world() -> Vector2:
	return HomeData.cell_to_local(Vector2(grid.door_cell))


func _build_door() -> void:
	var base := HomeData.PROPS + "interior/"
	var dm: Dictionary = (HomeData.interior()["door"] as Dictionary)
	var mat := _sprite_from(dm["doormat_r0"], base)
	mat.position = HomeData.cell_to_local(Vector2(grid.door_cell))
	rugs.add_child(mat)


func _glow_sprite(col: Color, radius_px: float, strength: float, local_pos: Vector2) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = HomeData.tex(HomeData.PROPS + "fx/glow_soft.webp")
	g.position = local_pos
	g.scale = Vector2.ONE * (radius_px * 2.83 / 256.0)
	g.modulate = Color(col.r, col.g, col.b, clampf(strength * DAY_GLOW, 0.0, 1.0))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = mat
	g.set_meta("base_strength", strength)
	g.set_meta("base_scale", g.scale)
	return g


# ---- furniture nodes -------------------------------------------------------------------------------------------------------------
func make_furniture_node(item_id: String, rot: int, ghost := false) -> Node2D:
	## returns a Node2D whose origin is the y-sort key point; add `pivot_world` (see pivot_position) to place it
	var meta: Dictionary = grid.items[item_id]
	var mp := (meta["rot_map"] as Array)[rot] as Array
	var baked_r := int(mp[0])
	var flip := bool(mp[1])
	var ent: Dictionary = (meta["rot"] as Dictionary)[str(baked_r)]
	var root := Node2D.new()
	root.name = item_id
	var ys := Vector2(ent["ysort"][0], ent["ysort"][1]) if ent.has("ysort") else Vector2.ZERO
	var piv := Vector2(ent["pivot"][0], ent["pivot"][1])
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = HomeData.tex(HomeData.PROPS + "furniture/" + String(ent["file"]))
	spr.centered = false
	if flip:
		var d := HomeData.rot_dims(meta["footprint"], rot)              # the y-sort key of the TURNED footprint (left-front corner if W >= D)
		var kx := -d.x * 0.5 if d.x >= d.y else d.x * 0.5
		var kz := d.y * 0.5 if d.x >= d.y else -d.y * 0.5
		ys = Vector2((kx - kz) * HomeData.HALF_W, (kx + kz) * 37.6)
		piv.x = float(spr.texture.get_width()) - piv.x
		spr.flip_h = true
	spr.offset = -piv - ys
	root.add_child(spr)
	root.set_meta("ysort", ys)
	root.set_meta("pivot", piv)
	root.set_meta("ent", ent)
	root.set_meta("flip", flip)
	root.set_meta("tex_w", float(spr.texture.get_width()))
	if ent.has("float"):
		var f := Sprite2D.new()
		f.name = "Float"
		f.texture = HomeData.tex(HomeData.PROPS + "furniture/" + String(ent["float"]["file"]))
		f.centered = false
		f.offset = spr.offset
		f.flip_h = flip
		root.add_child(f)
		if not ghost:
			_floaters.append({"node": f, "phase": randf() * TAU, "amp": float(ent["float"].get("bob_px", 5))})
	return root


func pivot_position(item_id: String, cell: Vector2i, rot: int, ys: Vector2) -> Vector2:
	var m: Dictionary = grid.items[item_id]
	var layer: String = m["layer"]
	if layer == "wall":
		var seg := grid.wall_segments(item_id, cell, rot)
		var idxs: Array = seg[1]
		var mid := (float(idxs[0]) + float(idxs[-1])) * 0.5
		return HomeData.cell_to_local(Vector2(mid, -0.5) if seg[0] == "z" else Vector2(-0.5, mid)) + ys
	return HomeData.cell_to_local(grid.footprint_center(item_id, cell, rot)) + ys


func _draw_placement(uid: int) -> void:
	var placement: Dictionary = grid.placements[uid]
	var item_id: String = placement.item_id
	var cell: Vector2i = placement.cell
	var rot: int = placement.rot
	var meta: Dictionary = grid.items[item_id]
	var layer: String = meta["layer"]
	var node := make_furniture_node(item_id, rot)
	node.set_meta("furniture_uid", uid)
	var ys: Vector2 = node.get_meta("ysort")
	var ent: Dictionary = node.get_meta("ent")
	match layer:
		"floor":
			node.position = pivot_position(item_id, cell, rot, ys)
			world.add_child(node)
		"rug":
			node.position = pivot_position(item_id, cell, rot, ys)
			rugs.add_child(node)
		"wall":
			node.position = pivot_position(item_id, cell, rot, ys)
			wall_items.add_child(node)
		"ceiling":
			node.position = pivot_position(item_id, cell, rot, ys) - Vector2(0, 0)
			ceiling.add_child(node)
		"tabletop":
			var host_uid: int = grid.placements[uid]["host"]
			var host: Node2D = nodes[host_uid]
			var hmeta: Dictionary = grid.items[grid.placements[host_uid]["item_id"]]
			var hp: Dictionary = grid.placements[host_uid]
			var slots := grid.surface_slot_cells(host_uid)
			var sc: Vector2i = slots[grid.placements[uid]["slot"]]
			var hctr := grid.footprint_center(hp["item_id"], hp["cell"], hp["rot"])
			var rel := HomeData.cell_to_local(Vector2(sc)) - HomeData.cell_to_local(hctr)
			node.position = ys - (host.get_meta("ysort") as Vector2) + rel - Vector2(0, float(hmeta["surface"]["height_m"]) * HomeData.PX_PER_M_V)
			host.add_child(node)
	nodes[uid] = node
	_attach_glow(uid, ent, node, layer)
	if layer == "floor":
		var body := StaticBody2D.new()
		body.collision_layer = Iso.LAYER_WORLD
		body.collision_mask = 0
		var cs := CollisionPolygon2D.new()
		var dims := HomeData.rot_dims(meta.footprint, rot)
		var center := grid.footprint_center(item_id, cell, rot)
		var poly := PackedVector2Array()
		for corner in [Vector2(-dims.x,-dims.y),Vector2(dims.x,-dims.y),Vector2(dims.x,dims.y),Vector2(-dims.x,dims.y)]:
			poly.append(HomeData.cell_to_local(center + corner * 0.5) - node.position)
		cs.polygon = poly
		body.add_child(cs)
		node.add_child(body)
		if meta.has("interact"):
			for front in grid.front_cells(item_id, cell, rot):
				if grid.floor_cells.has(front):
					var interaction: Interactable2D = load("res://scripts/home/furniture_node_2d.gd").new()
					interaction.kind = str(meta.interact.type)
					interaction.prompt_key = "UI_SLEEP" if interaction.kind == "sleep" else "HOME_WORLD_USE"
					interaction.position = HomeData.cell_to_local(Vector2(front))
					interaction.radius = Vector2(36, 24)
					area.objects.add_child(interaction)


func _attach_glow(uid: int, ent: Dictionary, node: Node2D, _layer: String) -> void:
	if not ent.has("glow"):
		return
	var g: Dictionary = ent["glow"]
	var piv: Vector2 = node.get_meta("pivot")
	var ys: Vector2 = node.get_meta("ysort")
	var gc := Vector2(g["center"][0], g["center"][1])
	if bool(node.get_meta("flip")):
		gc.x = float(node.get_meta("tex_w")) - gc.x
	var local := gc - piv                                                            # relative to the pivot
	var sp := _glow_sprite(Color.html(g["color"]), float(g["radius_px"]), float(g["strength"]), Vector2.ZERO)
	sp.set_meta("anchor_node", node)
	sp.set_meta("anchor_off", local - ys)                                            # node origin = pivot_world + ysort -> glow = origin - ysort + (center - pivot)
	glow_layer.add_child(sp)
	sp.visible = true
	_glows[uid] = [sp]
	_update_glow_pos(sp)
	sp.modulate.a = clampf(float(sp.get_meta("base_strength")) * (1.5 if night else DAY_GLOW), 0.0, 1.0)


func _update_glow_pos(sp: Sprite2D) -> void:
	var n: Node2D = sp.get_meta("anchor_node")
	sp.global_position = n.global_position + (sp.get_meta("anchor_off") as Vector2)


func set_night(on: bool) -> void:
	night = on
	for o in _night_overlays:
		o.visible = on
	for uid in _glows:
		for g in _glows[uid]:
			g.modulate.a = clampf(float(g.get_meta("base_strength")) * (1.5 if on else DAY_GLOW), 0.0, 1.0)


func _process(dt: float) -> void:
	_t += dt
	for e in _floaters:
		var n: Sprite2D = e["node"]
		if is_instance_valid(n):
			n.position.y = sin(_t * 2.6 + float(e["phase"])) * float(e["amp"])
	for uid in _glows:
		for g in _glows[uid]:
			if is_instance_valid(g.get_meta("anchor_node")):
				_update_glow_pos(g)
				var flick := 1.0 + 0.05 * sin(_t * 5.0 + float(uid))
				g.scale = (g.get_meta("base_scale") as Vector2) * flick
	if TimeManager.is_night() != night:
		set_night(TimeManager.is_night())

