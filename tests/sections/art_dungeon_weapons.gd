extends RefCounted
const SECTION := "art_dungeon_weapons"
const TIMEOUT_S := 180.0
func run(t) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/held_equipment/dungeon/manifest.json"))
	var packing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/dungeon-loadout/weapon-packing.json"))
	var ids: Array = []
	for id in GameData.lua().get_all_item_ids():
		if str(id).begins_with("wpn_"): ids.append(str(id))
	t.check("all_22_weapons_have_independent_paintings",ids.size() == 22 and manifest.items.size() == 22 and ids.all(func(id): return manifest.items.has(id)))
	t.check("eight_authored_directions",manifest.directions == ["S","SW","W","NW","N","NE","E","SE"] and packing.views == 176)
	var atlases := {}
	for raw_id in ids:
		var id := str(raw_id)
		var spec: Dictionary = manifest.items[id]
		var path := str(spec.atlas)
		atlases[path] = true
		var picture := Image.new()
		var ok := picture.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK
		t.check("atlas_"+id,ok and picture.get_size() == Vector2i(512,256))
		if not ok: continue
		var views: Array = spec.views
		var valid := views.size() == 8
		for view in views:
			var at := Vector2i(int(view.rect[0])+int(view.grip[0]),int(view.rect[1])+int(view.grip[1]))
			valid = valid and picture.get_pixelv(at).a > .3 and int(view.height) > 40
			valid = valid and picture.get_pixel(int(view.rect[0]),int(view.rect[1])).a == 0
		t.check("all_grips_inside_clean_cutouts_"+id,valid)
		var source := str(spec.source)
		t.check("selected_source_pinned_"+id,FileAccess.get_sha256("res://"+source) == packing.sources[source])
		var rarity := ItemKinds.rarity_of(id)
		var icon := Image.new()
		var base := "res://assets/icons/items/"+id+".webp"
		t.check("icon_size_budget_"+id,icon.load_webp_from_buffer(FileAccess.get_file_as_bytes(base)) == OK and icon.get_size() == Vector2i(128,128) and FileAccess.get_file_as_bytes(base).size() <= 30*1024)
		var legendary := rarity == &"legendary"
		var expected := "res://assets/icons/items/"+id+("_night" if legendary else "")+".webp"
		t.check("both_resolvers_"+id,ArtCatalog.icon_path(StringName(id),legendary) == expected and TTItemIcon.resolve_path(id,rarity) == expected)
		if legendary:
			var night := Image.new()
			var loaded := night.load_webp_from_buffer(FileAccess.get_file_as_bytes(expected)) == OK
			var rim := false
			if loaded:
				for y in 128:
					for x in 128:
						if icon.get_pixel(x,y).a == 0 and night.get_pixel(x,y).a > .9:
							var color := night.get_pixel(x,y)
							if absf(color.r-228.0/255) < .01 and absf(color.g-239.0/255) < .01 and absf(color.b-245.0/255) < .01: rim = true
			t.check("legendary_night_rim_"+id,loaded and rim)
	t.check("no_weapon_aliases_old_stock_art",atlases.size() == 22 and not atlases.has("res://assets/held_equipment/tools.webp"))
func run_windowed(t) -> void:
	await run(t)
	await t.start_world()
	var layer := CanvasLayer.new()
	layer.layer = 26
	t.tree.root.add_child(layer)
	var root := Control.new()
	root.theme = preload("res://assets/ui/theme.tres")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var background := ColorRect.new()
	background.color = Color("f4e6c4")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var night := ColorRect.new()
	night.color = Color("2f3654")
	night.position = Vector2(0,360)
	night.size = Vector2(1280,360)
	root.add_child(night)
	var ids := ["wpn_sword_moon","wpn_club_trunk","wpn_spear_root","wpn_staff_star"]
	for row in 2:
		for index in 4:
			var id: String = ids[index]
			var slot := RaritySlot.new()
			slot.item_id = StringName(id)
			slot.rarity = &"legendary"
			slot.slot_size = 128
			slot.show_word = true
			if row == 1: slot.ui_override = {"label":Color("e4eff5")}
			slot.position = Vector2(90+index*310,60+row*360)
			root.add_child(slot)
			var label := Label.new()
			label.text = TranslationServer.translate(str(ItemKinds.def(id).name_key))
			label.theme_type_variation = &"Display22"
			label.position = Vector2(35+index*310,240+row*360)
			if row == 1: label.add_theme_color_override("font_color",Color("e4eff5"))
			root.add_child(label)
	await t.frames(4)
	await t.capture("legendary_day_night_icons")
	layer.free()
