extends SceneTree
## Capture the imported sprites in the engine. No saves are written.
const OUT := "res://docs/art/drawn/"

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
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
	manager.hour = 21
	for frame in 60:
		await process_frame
	await _shot("world-night.png")
	world.queue_free()
	await process_frame
	current_scene = null
	await _cast()
	await _buildings()
	print("DRAWN ART captured world, daylight close view, night, cast and buildings")
	quit()


func _shot(file: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT + file)


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
	var canvas := _paper(Vector2i(1280, 1080))
	var ids: Array[String] = []
	for id in DirAccess.get_directories_at("res://assets/isometric_characters"):
		if FileAccess.file_exists("res://assets/isometric_characters/" + id + "/animations.json"):
			ids.append(id)
	ids.sort()
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
