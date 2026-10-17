extends RefCounted
const SECTION := "art_dungeon_supplies"
const TIMEOUT_S := 120.0
const MANIFEST := "res://tools/art/features/dungeon/supplies.json"
func run(t) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	t.check("five_supplies",data.items.size() == 5)
	for id in data.items:
		var spec: Dictionary = data.items[id]
		var item := ItemKinds.def(id)
		t.check("live_definition_"+id,not item.is_empty() and str(item.rarity) == str(spec.rarity))
		var path := "res://assets/icons/items/"+str(spec.file)
		var bytes := FileAccess.get_file_as_bytes(path)
		var picture := Image.new()
		var ok := picture.load_webp_from_buffer(bytes) == OK
		t.check("cutout_size_budget_"+id,ok and picture.get_size() == Vector2i(128,128) and picture.get_pixel(0,0).a == 0 and bytes.size() <= 30720)
		t.check("selected_source_"+id,FileAccess.get_sha256("res://"+str(spec.source)) == str(spec.source_sha256))
		t.check("day_and_night_resolve_"+id,ArtCatalog.icon_path(id,false) == path and ArtCatalog.icon_path(id,true) == path and TTItemIcon.resolve_path(id,spec.rarity) == path)
func run_windowed(t) -> void:
	await run(t)
	await t.start_world()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var layer := CanvasLayer.new()
	layer.layer = 26
	t.tree.root.add_child(layer)
	var root := Control.new()
	root.theme = preload("res://assets/ui/theme.tres")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var contents := Control.new()
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(contents)
	for dark in [false,true]:
		for child in contents.get_children(): child.free()
		background.color = Color("2f3654" if dark else "f4e6c4")
		var index := 0
		for id in data.items:
			var at := Vector2(32+index*248,230)
			var slot := RaritySlot.new()
			slot.item_id = StringName(id)
			slot.rarity = &"normal"
			slot.slot_size = 112
			slot.show_word = true
			slot.position = at+Vector2(44,0)
			if dark: slot.ui_override = {"label":Color("e4eff5")}
			contents.add_child(slot)
			var small := TTItemIcon.new()
			small.item_id = StringName(id)
			small.position = at+Vector2(12,-95)
			small.custom_minimum_size = Vector2(64,64)
			small.size = Vector2(64,64)
			contents.add_child(small)
			var label := Label.new()
			label.text = TranslationServer.translate(str(ItemKinds.def(id).name_key))
			label.position = at+Vector2(0,164)
			label.size = Vector2(220,60)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if dark: label.add_theme_color_override("font_color",Color("e4eff5"))
			contents.add_child(label)
			index += 1
		await t.frames(3)
		await t.capture("night" if dark else "day")
	layer.free()
