extends Node2D
## Art-only native scene assembly, shared by the gallery and capture checks.
var room: Dictionary
var content_rect := Rect2()

func setup(id: String, night: bool = false) -> void:
	room = PaintedInteriorArt.room(id)
	var floor := TileMapLayer.new()
	floor.name = "PaintedFloor"
	floor.tile_set = AreaTileSet.tile_set(&"iso")
	floor.collision_enabled = false
	add_child(floor)
	var terrain := StringName(str(room["floor"]))
	var source := AreaTileSet.source_for(&"iso", terrain)
	var cells: Dictionary = {}
	for c in room["cells"]:
		var cell := Vector2i(int(c[0]), int(c[1]))
		cells[cell] = true
		floor.set_cell(cell, source, AreaTileSet.atlas_coords_for(terrain, cell))
		_include(Rect2(Iso.iso_center(cell) - Vector2(Iso.TILE_W, Iso.TILE_H) * .5, Vector2(Iso.TILE_W, Iso.TILE_H)))
	# A narrow cut edge gives the floor a physical thickness without hiding the exit.
	var edge := Node2D.new()
	edge.z_index = -1
	add_child(edge)
	for cell in cells:
		var diamond := Iso.iso_diamond(cell)
		for side in [0, 1]:
			if cells.has(cell + (Vector2i(1, 0) if side == 0 else Vector2i(0, 1))):
				continue
			var a: Vector2 = diamond[1 + side]
			var b: Vector2 = diamond[2 + side]
			var slab := Polygon2D.new()
			slab.polygon = PackedVector2Array([a, b, b + Vector2(0, 12), a + Vector2(0, 12)])
			slab.color = Color("96744e") if side == 0 else Color("795e44")
			edge.add_child(slab)
	var rugs := Node2D.new()
	rugs.name = "PaintedTextiles"
	add_child(rugs)
	for item in room["ground_decor"]:
		_sprite(str(item["asset"]), PaintedInteriorArt.item_position(item), rugs)
	var walls := Node2D.new()
	walls.name = "PaintedWalls"
	add_child(walls)
	var style := str(room["wall_material"])
	for cell in cells:
		if cell.y == 0:
			_wall(walls, cell, 0, style, (room["windows"]["z"] as Array).has(float(cell.x)), night)
		if cell.x == 0:
			_wall(walls, cell, 1, style, (room["windows"]["x"] as Array).has(float(cell.y)), night)
	_sprite("corner_" + style, Vector2(Iso.TILE_W * .5, 0), walls)
	for item in room["decor"]:
		var c: Array = item["cell"]
		var rotation: int = item["wall"]
		var at := Iso.iso_center(Vector2i(int(c[0]), int(c[1]))) + Vector2(Iso.TILE_W * (-.25 if rotation == 1 else .25), -Iso.TILE_H * .25 - float(item["height"]))
		var sprite := _sprite(str(item["asset"]), at, walls)
		if item["asset"] == "picture_leaf":
			# A flat wall picture follows its wall plane; the lantern keeps its authored volume.
			var plane := sprite.transform
			plane.x = Vector2(1, Iso.squash() * (-1 if rotation == 1 else 1))
			sprite.transform = plane
		elif night and item["asset"] == "wall_lantern":
			var light := PointLight2D.new()
			light.texture = Glow.light_texture()
			light.texture_scale = .8
			light.color = Color("ffd299")
			light.energy = .55
			light.position = at
			add_child(light)
	var objects := Node2D.new()
	objects.name = "PaintedFurnishings"
	objects.y_sort_enabled = true
	add_child(objects)
	for item in room["items"]:
		var sprite := _sprite(str(item["asset"]), PaintedInteriorArt.item_position(item), objects)
		if ArtCatalog.prop_metadata(StringName(item["asset"])).get("layer", "floor") == "ceiling":
			sprite.z_index = 2
	var door: Array = room["door"]["cell"]
	var at := Iso.iso_center(Vector2i(int(door[0]), int(door[1])))
	var emblem := _sprite("emblem_" + str(room["emblem"]), at + Vector2(-70, 40), self)
	emblem.scale = Vector2.ONE * .65
	var hero := IsoChibiSprite2D.create("fox")
	objects.add_child(hero)
	var spawn: Array = room["spawn_cell"]
	hero.position = Iso.iso_center(Vector2i(int(spawn[0]), int(spawn[1])))
	if room.has("keeper_cell"):
		var keeper := IsoChibiSprite2D.create(_keeper_art())
		objects.add_child(keeper)
		var c: Array = room["keeper_cell"]
		keeper.position = Iso.iso_center(Vector2i(int(c[0]), int(c[1])))
	if night:
		modulate = Color(.72, .70, .82)
	content_rect = content_rect.grow(20)

func _keeper_art() -> String:
	match str(room.get("emblem", "")):
		"smith", "carpenter", "timber": return "bear"
		"post": return "penguin"
		"owl": return "owl"
		_: return "fairy"

func _wall(host: Node2D, cell: Vector2i, rotation: int, style: String, window: bool, night: bool) -> void:
	var kind := "win" if window else ("b" if (cell.x + cell.y) % 3 == 0 else "a")
	var id := "wall_%s_%s_r%d" % [style, kind, rotation]
	var at := Iso.iso_center(cell) + Vector2(Iso.TILE_W * (.25 if rotation == 0 else -.25), -Iso.TILE_H * .25)
	_sprite(id, at, host)
	if window and night:
		var glow := _sprite(id + "_night", at, host)
		glow.material = Glow.additive_material()

func _sprite(id: String, at: Vector2, host: Node2D) -> Sprite2D:
	var art: Dictionary = ArtCatalog.prop(StringName(id))
	var sprite := Sprite2D.new()
	sprite.name = id
	sprite.texture = art["texture"]
	sprite.centered = false
	sprite.position = at
	sprite.offset = -(art["pivot"] as Vector2)
	host.add_child(sprite)
	_include(Rect2(at + sprite.offset, art["size"]))
	return sprite

func _include(rect: Rect2) -> void:
	content_rect = rect if content_rect.size == Vector2.ZERO else content_rect.merge(rect)

func fit_viewport(size: Vector2, origin: Vector2 = Vector2.ZERO) -> void:
	var zoom := minf((size.x - 60) / content_rect.size.x, (size.y - 60) / content_rect.size.y)
	zoom = minf(zoom, 1.15)
	scale = Vector2.ONE * zoom
	position = origin + size * .5 - content_rect.get_center() * zoom
