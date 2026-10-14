extends SceneTree
## Capture the imported sprites in the engine. No saves are written.
const OUT := "res://docs/art/drawn/"

class FootprintOverlay extends Node2D:
	# Keep this dynamic: -s drivers compile before the project's autoloads exist.
	var area

	func _draw() -> void:
		for y in area.map.height:
			for x in area.map.width:
				if area.map.ground_at(Vector2i(x, y)) == "#":
					continue
				var tile := Iso.iso_diamond(Vector2i(x, y))
				tile.append(tile[0])
				draw_polyline(tile, Color(0.12, 0.26, 0.27, .22), 1.0, true)
		for rec in area.prop_nodes:
			if not String(rec["id"]).begins_with("house_"):
				continue
			var fp := GameData.footprint_of(rec["id"])
			var corners := Iso.iso_footprint(rec["cell"], fp.x, fp.y)
			draw_polyline(PackedVector2Array([corners[3], corners[2], corners[1]]), Color("5fdbe3"), 2.0, true)

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	if "--items-only" in OS.get_cmdline_user_args():
		await _items()
		print("DRAWN ART captured every registered item")
		quit()
		return
	var manager := root.get_node("GameManager")
	manager.start_new_game("Art review", 0)
	var world := load("res://scenes/main/world.tscn").instantiate() as Node2D
	root.add_child(world)
	current_scene = world
	for frame in 120:
		await process_frame
		if frame > 15 and not bool(world.get("traveling")):
			break
	await _shot("world.png")
	# A daylight close view keeps the painted detail clear beside the dawn capture.
	manager.hour = 10
	# The normal mouse-wheel zoom path, including its camera limits.
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	for step in 3:
		Input.parse_input_event(wheel)
		await process_frame
	for frame in 30:
		await process_frame
	await _shot("world-close.png")
	var overlay := FootprintOverlay.new()
	overlay.area = world.get("area")
	overlay.z_index = 99
	overlay.area.add_child(overlay)
	await _shot("world-footprints.png")
	overlay.queue_free()
	await process_frame
	manager.hour = 21
	for frame in 60:
		await process_frame
	await _shot("world-night.png")
	world.queue_free()
	await process_frame
	current_scene = null
	await _cast()
	await _buildings()
	await _terrain()
	await _items()
	print("DRAWN ART captured world, daylight close view, night, full cast, buildings, every terrain and every item")
	quit()


func _shot(file: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT + file)


func _terrain() -> void:
	var ids := ArtCatalog.terrain_manifest_ids()
	var canvas := _paper(Vector2i(1280, ceili(float(ids.size()) / 4) * 200))
	for index in ids.size():
		var row := floori(float(index) / 4)
		var id: StringName = ids[index]
		var art := ArtCatalog.terrain(id)
		var ortho: bool = art["proj"] == &"ortho"
		var panel := Node2D.new()
		panel.position = Vector2(160 + (index % 4) * 320, 80 + row * 200)
		panel.scale = Vector2.ONE * .48
		canvas.add_child(panel)
		for y in 4:
			for x in 4:
				var tile := Sprite2D.new()
				var texture := AtlasTexture.new()
				texture.atlas = art["texture"]
				texture.region = Rect2(Vector2(Iso.atlas_coords(Vector2i(x, y), art["variants"]) * art["cell"]), Vector2(art["cell"]))
				tile.texture = texture
				tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				tile.position = Vector2((x - 1.5) * Iso.ORTHO_W, (y - 1.5) * Iso.ORTHO_H) if ortho else Iso.iso_center(Vector2i(x, y)) - Vector2(0, 3 * Iso.TILE_H / 2)
				panel.add_child(tile)
		_caption(canvas, String(id), Vector2((index % 4) * 320, row * 200 + 165), 320)
	await _shot("terrain.png")
	canvas.queue_free()
	await process_frame


func _paper(size: Vector2i) -> Control:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = size
	var canvas := Control.new()
	var paper := ColorRect.new()
	paper.size = Vector2(size)
	paper.color = Color("f5eedf")
	canvas.add_child(paper)
	root.add_child(canvas)
	return canvas


func _items() -> void:
	var lua := root.get_node("LuaRuntime")
	var ids: Array = lua.get_all_item_ids()
	ids.sort()
	for page in ceili(float(ids.size()) / 96):
		var canvas := _paper(Vector2i(1536, 1080))
		for index in mini(96, ids.size() - page * 96):
			var id: String = ids[page * 96 + index]
			var def: Dictionary = lua.get_item_def(id)
			var item := TTItemIcon.new()
			item.item_id = StringName(id)
			item.rarity = StringName(str(def.get("rarity", "normal")))
			item.id_fallback = false
			item.position = Vector2((index % 12) * 128 + 12, floori(float(index) / 12) * 132 + 4)
			item.size = Vector2(104, 104)
			canvas.add_child(item)
			_caption(canvas, id, Vector2((index % 12) * 128, floori(float(index) / 12) * 132 + 110), 128)
		await _shot("items-%d.png" % (page + 1))
		canvas.queue_free()
		await process_frame


func _caption(canvas: Control, text: String, at: Vector2, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("645b54"))
	label.add_theme_font_size_override("font_size", 12)
	canvas.add_child(label)


func _cast() -> void:
	var ids: Array[String] = []
	for id in DirAccess.get_directories_at("res://assets/isometric_characters"):
		if FileAccess.file_exists("res://assets/isometric_characters/" + id + "/animations.json"):
			ids.append(id)
	ids.sort()
	var canvas := _paper(Vector2i(1280, ceili(float(ids.size()) / 8) * 175 + 30))
	for i in ids.size():
		var row := floori(float(i) / 8.0)
		var character := IsoChibiSprite2D.create(ids[i])
		character.show_shadow = false
		character.set_direction_index(1)
		character.position = Vector2(80 + (i % 8) * 160, 145 + row * 175)
		character.scale = Vector2.ONE * .65
		character.set_process(false)
		canvas.add_child(character)
		_caption(canvas, ids[i], Vector2((i % 8) * 160, 165 + row * 175), 160)
	await _shot("cast.png")
	canvas.queue_free()
	await process_frame


func _buildings() -> void:
	var canvas := _paper(Vector2i(1280, 960))
	var files: Array[String] = [
		"res://assets/iso_props/drawn/house_farm.webp",
		"res://assets/iso_props/drawn/house_mushroom_rose.webp",
		"res://assets/iso_props/drawn/house_mushroom_lavender.webp",
		"res://assets/iso_props/drawn/house_mushroom_mint.webp",
	]
	for tier in range(1, 11):
		files.append("res://assets/iso_props/home/house_t%02d.webp" % tier)
	for i in files.size():
		var row := floori(float(i) / 5.0)
		var card := TextureRect.new()
		card.position = Vector2(10 + (i % 5) * 256, 8 + row * 316)
		card.size = Vector2(236, 280)
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.texture = load(files[i]) as Texture2D
		canvas.add_child(card)
		_caption(canvas, files[i].get_file().get_basename(), Vector2((i % 5) * 256, 291 + row * 316), 256)
	await _shot("buildings.png")
	canvas.queue_free()
	await process_frame
