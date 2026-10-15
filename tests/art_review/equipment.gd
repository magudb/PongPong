extends RefCounted
const SECTION := "equipment_design"
const TIMEOUT_S := 120.0
const STUDIO := "res://tools/art/drawn/equipment_studio.tscn"
const MANIFEST := "res://assets/art_studies/equipment/manifest.json"

func run(t) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	t.check("coverage", data["heroes"].size() == 8 and data["looks"].size() == 24 and data["held_examples"].size() == 8
		and data["outfits"].size() == 3 and data["items"].size() == 20,
		"all eight live heroes, three looks and one equipped pose each, twenty equipment studies")
	for hero in data["heroes"]:
		var skin: String = hero["skin"]
		t.check("hero_%s" % hero["id"], CharacterCatalog.wardrobe_body(skin) == hero["body"]
			and CharacterCatalog.hero_of_skin(skin).get("id", "") == hero["id"], "design fits the current playable cast")
	for category in ["looks", "held_examples", "items"]:
		for id in data[category]:
			var rec: Dictionary = data[category][id]
			var texture := load("res://" + str(rec["file"])) as Texture2D
			t.check("study_%s" % id, texture != null and texture.get_width() == int(rec["size"][0])
				and texture.get_height() == int(rec["size"][1]) and rec["status"] == "concept"
				and rec["views"].size() == 1 and FileAccess.file_exists("res://" + str(rec["source"])),
				"saved master, native export and honest single-view concept metadata")
	for id in data["items"]:
		var rec: Dictionary = data["items"][id]
		if rec["reference_status"] == "existing":
			t.check("item_reference_%s" % id, not EconomyManager.item_def(rec["reference_id"]).is_empty(), "reuse an existing item ID")
	var before := EconomyManager.to_dict().duplicate(true)
	var studio = load(STUDIO).instantiate()
	t.root.add_child(studio)
	for h in 8:
		studio._hero_buttons[h].pressed.emit()
		for mode in 4:
			studio._mode_buttons[mode].pressed.emit()
			var hero_id: String = data["heroes"][h]["id"]
			var key := "%s_%s" % [hero_id, data["review_modes"][mode]["id"]]
			var expected: Dictionary = data["held_examples"][hero_id] if mode == 3 else data["looks"][key]
			t.check("browse_%d_%d" % [h, mode], studio.hero_index == h and studio.mode_index == mode
				and studio._figure.texture.resource_path == "res://" + str(expected["file"]), "native hero and mode buttons choose the correct art")
	for id in data["items"]:
		studio._item_buttons[id].pressed.emit()
		t.check("select_%s" % id, studio.selected_item == id
			and studio._item_figure.texture.resource_path == "res://" + str(data["items"][id]["file"]), "equipment study can be inspected")
	t.check("no_gameplay_mutation", before == EconomyManager.to_dict(), "art review neither grants nor equips items")
	studio.free()

func run_windowed(t) -> void:
	var studio = load(STUDIO).instantiate()
	t.root.add_child(studio)
	for hero in 8:
		studio._hero_buttons[hero].pressed.emit()
		for mode in 4:
			studio._mode_buttons[mode].pressed.emit()
			await t.frames(2)
			RenderingServer.force_draw(false)
			var image: Image = t.tree.root.get_texture().get_image()
			var key := "%s_%s" % [studio.data["heroes"][hero]["id"], studio.data["review_modes"][mode]["id"]]
			var file: String = t.out_dir.path_join("equipment_%s.png" % key)
			t.check("capture_%s" % key, image != null and not image.is_empty() and image.save_png(file) == OK, file)
	studio.free()
