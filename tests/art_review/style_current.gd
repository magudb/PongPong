extends RefCounted
const SECTION := "style_current"
const TIMEOUT_S := 120.0

func run_windowed(t) -> void:
	var host := Control.new()
	t.root.add_child(host)
	for side in 2:
		var background := ColorRect.new()
		background.position = Vector2(side * 640, 0)
		background.size = Vector2(640, 720)
		background.color = Color("f4e6c4") if side == 0 else Color("2b2340")
		host.add_child(background)
		var color_ := Color("2b2340") if side == 0 else Color("f4e6c4")
		var title := Label.new()
		title.position = Vector2(24 + side * 640, 24)
		title.text = "Trætoppen · Æ Ø Å · 1.250"
		title.add_theme_font_override("font", load("res://assets/fonts/Caprasimo-Regular.ttf"))
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", color_)
		host.add_child(title)
		var text := Label.new()
		text.position = Vector2(24 + side * 640, 72)
		text.text = "Alegreya Sans · Æ Ø Å æ ø å · cream, ink and fairy gold"
		text.add_theme_font_size_override("font_size", 18)
		text.add_theme_color_override("font_color", color_)
		host.add_child(text)
		var files: PackedStringArray = DirAccess.get_files_at("res://assets/ui/icons")
		var index := 0
		for file in files:
			if not file.ends_with(".svg"):
				continue
			var icon := TextureRect.new()
			icon.texture = load("res://assets/ui/icons/" + file)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(55 + side * 640 + (index % 4) * 145, 150 + floorf(float(index) / 4.0) * 120)
			icon.size = Vector2(52, 52)
			if file in ["speaker.svg", "caret.svg", "check.svg"]:
				icon.modulate = color_
			host.add_child(icon)
			var label := Label.new()
			label.position = icon.position + Vector2(-32, 58)
			label.text = file.trim_suffix(".svg")
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", color_)
			host.add_child(label)
			index += 1
		var buy := Button.new()
		buy.text = "Køb"
		buy.position = Vector2(40 + side * 640, 430)
		buy.size = Vector2(160, 50)
		buy.theme_type_variation = "ButtonPrimary"
		host.add_child(buy)
		if side == 0:
			buy.grab_focus()
	await t.frames(3)
	var image: Image = await t.capture("theme_assets_light_dark")
	t.expect_not_blank(image, Rect2i(0, 0, 1280, 720), "seven vector assets and guide typefaces render on light/dark guide palettes")
	host.free()
	for id in ["rasmus", "pedro"]:
		var studio = load("res://tools/art/drawn/equipment_fit_gallery.tscn").instantiate()
		t.root.add_child(studio)
		studio._select_body(id)
		await t.frames(2)
		var valid := true
		for button in studio.find_children("*", "Button", true, false):
			valid = valid and button.get_theme_font_size("font_size") >= 20 and button.get_global_rect().end.x <= 1280
		t.check("guide_display_type_%s" % id, valid, "Caprasimo controls meet the 20 px guide floor and fit the viewport")
		await t.capture("equipment_controls_%s" % id)
		studio.free()
	for night in [false, true]:
		await _homes(t, night)
	await _materials(t)

func _background(t, night: bool) -> Control:
	var host := Control.new()
	t.root.add_child(host)
	var paper := ColorRect.new()
	paper.size = Vector2(1280, 720)
	paper.color = Color("2b2340") if night else Color("f4e6c4")
	host.add_child(paper)
	return host

func _label(host: Control, text: String, at: Vector2, night: bool) -> void:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f4e6c4") if night else Color("2b2340"))
	host.add_child(label)

func _homes(t, night: bool) -> void:
	var host := _background(t, night)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/iso_props/home/home.json"))
	_label(host, "Painted home foundations · all ten tiers · native textures at 0.22 scale", Vector2(20, 8), night)
	for index in 10:
		var rec: Dictionary = data["tiers"][index]["exterior"]
		var origin := Vector2(38 + (index % 5) * 256, 42 + floori(index / 5.0) * 335)
		var day := Sprite2D.new()
		day.texture = load("res://assets/iso_props/home/" + str(rec["day"]))
		day.centered = false
		day.scale = Vector2.ONE * 0.22
		day.position = origin
		if night:
			day.modulate = Color(0.35, 0.39, 0.52)
		host.add_child(day)
		if night:
			var light := Sprite2D.new()
			light.texture = load("res://assets/iso_props/home/" + str(rec["night"]))
			light.centered = false
			light.scale = day.scale
			light.position = origin + Vector2(rec["night_offset"][0], rec["night_offset"][1]) * 0.22
			var blend := CanvasItemMaterial.new()
			blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			light.material = blend
			host.add_child(light)
		_label(host, "Tier %d" % (index + 1), origin + Vector2(0, 294), night)
	await t.frames(3)
	var shot: Image = await t.capture("painted_home_%s" % ("night" if night else "day"))
	t.expect_not_blank(shot, Rect2i(0, 0, 1280, 720), "ten painted home textures and registered night layers render")
	host.free()

func _materials(t) -> void:
	var host := _background(t, false)
	_label(host, "Rebuilt painted material variants · native textures", Vector2(20, 16), false)
	var ids := ["lantern_post_lavender", "lantern_post_mint", "lantern_post_rose", "chest_jern", "market_stall_furniture", "market_stall_tailor"]
	for index in ids.size():
		var image := TextureRect.new()
		image.texture = load("res://assets/iso_props/zz_painted_consistency/%s.webp" % ids[index])
		image.position = Vector2(45 + (index % 3) * 420, 65 + floori(index / 3.0) * 315)
		image.size = Vector2(330, 250)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		host.add_child(image)
		_label(host, ids[index], image.position + Vector2(0, 250), false)
	await t.frames(3)
	var shot: Image = await t.capture("rebuilt_material_variants")
	t.expect_not_blank(shot, Rect2i(0, 0, 1280, 720), "six painted pigment variants render through native imports")
	host.free()
