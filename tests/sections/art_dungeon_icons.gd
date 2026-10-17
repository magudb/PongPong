extends RefCounted
const SECTION := "art_dungeon_icons"
const TIMEOUT_S := 180.0
const MANIFEST := "res://tools/art/features/dungeon/manifest.json"
func run(t) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	t.check("all_51_icons",data.items.size() == 51)
	var counts := {"weapon":0,"rough":0,"gem":0,"material":0}
	var legendary := 0
	for raw_id in data.items:
		var id := str(raw_id)
		var spec: Dictionary = data.items[id]
		var item := ItemKinds.def(id)
		t.check("definition_"+id,not item.is_empty() and str(item.rarity) == str(spec.rarity))
		var group := "weapon" if id.begins_with("wpn_") else "rough" if id.begins_with("rough_") else "gem" if id.begins_with("gem_") else "material"
		counts[group] += 1
		var path := "res://assets/icons/items/"+str(spec.file)
		var bytes := FileAccess.get_file_as_bytes(path)
		var image := Image.new()
		var loaded := image.load_webp_from_buffer(bytes) == OK
		t.check("size_alpha_budget_"+id,loaded and image.get_size() == Vector2i(128,128) and bytes.size() <= 30720 and image.get_pixel(0,0).a == 0)
		t.check("rarity_rim_colour_"+id,Color(str(spec.ring)).is_equal_approx(Rarity.ui(spec.rarity).ring))
		t.check("selected_source_"+id,FileAccess.get_sha256("res://"+str(spec.source)) == str(spec.source_sha256))
		var night := str(spec.rarity) == "legendary"
		var wanted := "res://assets/icons/items/"+str(spec.night if night else spec.file)
		t.check("ui_resolves_"+id,ArtCatalog.icon_path(StringName(id),night) == wanted and TTItemIcon.resolve_path(id,spec.rarity) == wanted)
		if night:
			legendary += 1
			var variant := Image.new()
			var ok := variant.load_webp_from_buffer(FileAccess.get_file_as_bytes(wanted)) == OK
			t.check("night_variant_"+id,ok and variant.get_size() == Vector2i(128,128))
	t.check("category_coverage",counts == {"weapon":22,"rough":4,"gem":14,"material":11},str(counts))
	t.check("seven_night_variants",legendary == 7)
	for id in LuaData.dict(Svc.lua_config("dungeon_loot.lantern_gem.existing",{})):
		t.check("existing_lantern_theme_icon_"+id,ArtCatalog.icon_path(StringName(id)) != "" and TTItemIcon.resolve_path(id,ItemKinds.rarity_of(id)) != "")
func run_windowed(t) -> void:
	await run(t)
	await t.start_world()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var ids: Array = data.items.keys()
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
		background.color = Color("2f3654" if dark else "f4e6c4")
		for page in ceili(ids.size()/18.0):
			for child in contents.get_children(): child.free()
			for index in range(page*18,mini(ids.size(),(page+1)*18)):
				var id := str(ids[index])
				var spec: Dictionary = data.items[id]
				var offset := index-page*18
				var at := Vector2(20+(offset%6)*210,12+floori(offset/6.0)*230)
				var slot := RaritySlot.new()
				slot.item_id = StringName(id)
				slot.rarity = StringName(str(spec.rarity))
				slot.slot_size = 112
				slot.show_word = true
				slot.position = at+Vector2(20,0)
				if dark: slot.ui_override = {"label":Color("e4eff5")}
				contents.add_child(slot)
				var label := Label.new()
				label.text = TranslationServer.translate(str(ItemKinds.def(id).name_key))
				label.theme_type_variation = &"Heavy17"
				label.position = at+Vector2(0,160)
				label.size = Vector2(195,50)
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				if dark: label.add_theme_color_override("font_color",Color("e4eff5"))
				contents.add_child(label)
			await t.frames(3)
			await t.capture("%s_page_%d" % ["night" if dark else "day",page+1])
	layer.free()
