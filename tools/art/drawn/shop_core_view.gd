extends "res://tools/art/drawn/interiors_view.gd"
## Art review of the towns package's room snapshots, without gameplay managers.

func setup_core(id: String, stand_in: bool = false, night: bool = false, room_definition: Dictionary = {}, review_keeper: String = "") -> void:
	room = PaintedShopArt.rooms()[id] if room_definition.is_empty() else room_definition
	var floor := TileMapLayer.new()
	floor.tile_set = AreaTileSet.tile_set(&"iso")
	floor.collision_enabled = false
	add_child(floor)
	var terrain := StringName(str(room["floor"]))
	var source := AreaTileSet.source_for(&"iso", terrain)
	var walls := Node2D.new()
	walls.name = "ReviewWalls"
	walls.z_index = -1
	add_child(walls)
	for z in int(room["rows"]):
		for x in int(room["cols"]):
			var cell := Vector2i(x, z)
			floor.set_cell(cell, source, AreaTileSet.atlas_coords_for(terrain, cell))
			_include(Rect2(Iso.iso_center(cell) - Vector2(64, 38), Vector2(128, 76)))
			if z == 0:
				_wall(walls, cell, 0, str(room["wall_style"]), (room["windows"]["z"] as Array).has(float(x)), night)
			if x == 0:
				_wall(walls, cell, 1, str(room["wall_style"]), (room["windows"]["x"] as Array).has(float(z)), night)
	_sprite("corner_" + str(room["wall_style"]), Vector2(64, 0), walls)
	var objects := Node2D.new()
	objects.name = "ReviewObjects"
	objects.y_sort_enabled = true
	add_child(objects)
	var has_light := false
	for item in room["items"]:
		var art := PaintedShopArt.piece(str(item["id"]), int(item.get("rot", 0)), stand_in)
		if art.is_empty():
			continue
		var fp: Array = art["footprint"]
		var c: Array = item["cell"]
		var at := Vector2((float(c[0]) - float(c[1]) + (float(fp[0]) - float(fp[1])) * .5) * 64 + 64,
			(float(c[0]) + float(c[1]) + (float(fp[0]) + float(fp[1]) - 2) * .5) * 38 + 38)
		if art["layer"] == "wall":
			at = Vector2((float(c[0]) + .5) * 64 + 64, (float(c[0]) - .5) * 38 + 38) if int(item.get("rot", 0)) % 2 == 0 else Vector2((-float(c[1]) - .5) * 64 + 64, (float(c[1]) - .5) * 38 + 38)
		var sprite := Sprite2D.new()
		sprite.name = "Piece_" + str(item["id"])
		sprite.texture = load(str(art["path"])) as Texture2D
		sprite.centered = false
		var pivot: Array = art["pivot"]
		sprite.position = at
		sprite.offset = -Vector2(pivot[0], pivot[1])
		if art["layer"] == "floor":
			var ys: Array = art.get("ysort", [0, 0])
			sprite.position += Vector2(ys[0], ys[1])
			sprite.offset -= Vector2(ys[0], ys[1])
			objects.add_child(sprite)
		else:
			walls.add_child(sprite)
		_include(Rect2(at - Vector2(pivot[0], pivot[1]), sprite.texture.get_size()))
		if night and art.has("night") and not stand_in:
			var glow := Sprite2D.new()
			glow.texture = load(PaintedShopArt.PACK + str(art["night"])) as Texture2D
			glow.centered = false
			var offset: Array = art["night_offset"]
			glow.position = sprite.position
			glow.offset = sprite.offset + Vector2(offset[0], offset[1])
			glow.material = Glow.additive_material()
			sprite.get_parent().add_child(glow)
			if not has_light:
				var light := PointLight2D.new()
				light.texture = Glow.light_texture()
				light.texture_scale = .75
				light.position = at - Vector2(0, 70)
				light.color = Color("ffb36b")
				light.energy = .3
				add_child(light)
				has_light = true
	var spawn: Array = room["spawn_cell"]
	var hero := IsoChibiSprite2D.create("fox")
	objects.add_child(hero)
	hero.position = Iso.iso_center(Vector2i(int(spawn[0]), int(spawn[1])))
	for post in room["posts"]:
		if str(post.get("kind", "")) != "keeper":
			continue
		var keeper_id: String = review_keeper if not review_keeper.is_empty() else str(PaintedShopArt.table("res://docs/art/shop-core/room-contracts.json")["keepers"][id])
		var npc: Dictionary = Svc.node("LuaRuntime").get_npc(keeper_id)
		var keeper := IsoChibiSprite2D.create(str(npc["visual"]))
		keeper.name = "ShopKeeper"
		objects.add_child(keeper)
		var c: Array = post["cell"]
		keeper.position = Iso.iso_center(Vector2i(int(c[0]), int(c[1])))
		break
	if night:
		modulate = Color(.72, .70, .82)
	content_rect = content_rect.grow(20)
