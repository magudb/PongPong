extends SceneTree
## Before/after contact sheet at game scale, rendered using the native engine.
var source: String
var samples: Array[String] = [
	"isometric_characters/fox/idle.webp", "isometric_characters/bat/idle.webp",
	"isometric_characters/fairy/idle.webp", "isometric_characters/hobbit_pip/idle.webp",
	"isometric_characters/rabbit_farmer/idle.webp", "isometric_characters/bear/idle.webp",
	"iso_props/home/house_t01.webp", "iso_props/home/house_t08.webp",
	"icons/home/chair_birch.webp", "icons/home/bed_toadstool.webp",
	"portraits/fox.webp", "portraits/bat.webp",
]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			source = arg.trim_prefix("--source=")
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 1040)
	var background := ColorRect.new()
	background.size = Vector2(1280, 1040)
	background.color = Color("f5eedf")
	root.add_child(background)
	for index in samples.size():
		var path := samples[index]
		var base := Vector2(30 + (index % 3) * 416, 20 + floori(float(index) / 3.0) * 256)
		var caption := Label.new()
		caption.position = base
		caption.text = path.get_base_dir().get_file() if path.begins_with("isometric_characters") else path.get_file().get_basename()
		caption.add_theme_color_override("font_color", Color("49373e"))
		root.add_child(caption)
		for side in 2:
			var image_path := source.path_join(path) if side == 0 else ProjectSettings.globalize_path("res://assets/" + path)
			var image := Image.load_from_file(image_path)
			if path.begins_with("isometric_characters"):
				image = image.get_region(Rect2i(0, 0, 256, 256))
			var card := TextureRect.new()
			card.position = base + Vector2(side * 200, 29)
			card.size = Vector2(184, 196)
			card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			card.texture = ImageTexture.create_from_image(image)
			root.add_child(card)
			var label := Label.new()
			label.position = base + Vector2(side * 200 + 64, 226)
			label.text = "original" if side == 0 else "illustrated"
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color("78675d"))
			root.add_child(label)
	await process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://docs/art/storybook")
	root.get_texture().get_image().save_png("res://docs/art/storybook/comparison.png")
	print("STORYBOOK REVIEW saved docs/art/storybook/comparison.png")
	quit()
