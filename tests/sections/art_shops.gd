extends RefCounted
## Art/consumer contract gate. Visual review evidence is under docs/art/shop-core.
const SECTION := "art_shops"
const TIMEOUT_S := 150.0
const View = preload("res://tools/art/drawn/shop_core_view.gd")

func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _bytes(size: Array) -> int:
	var w := int(size[0])
	var h := int(size[1])
	var total := 0
	while true:
		total += w * h * 4
		if w == 1 and h == 1:
			return total
		w = maxi(w >> 1, 1)
		h = maxi(h >> 1, 1)
	return total

func run(t) -> void:
	var contract := _json("res://tools/art/drawn/shop_core_layout.json")
	var pieces := PaintedShopArt.pieces()
	var badges: Dictionary = _json(PaintedShopArt.PACK + "emblems.json")["emblems"]
	t.check("design_ids", pieces.keys() == (contract["pieces"] as Dictionary).keys() and pieces.size() == 20 and badges.size() == 15, "20 core pieces and 15 text-free emblems")
	var count := 0
	var night_count := 0
	var total_bytes := 0
	var sprite_bytes := 0
	var disk := 0
	for id in pieces:
		var item: Dictionary = pieces[id]
		var expected: Dictionary = contract["pieces"][id]
		t.check("contract_%s" % id, item["footprint"] == expected["footprint"] and item["layer"] == expected["layer"] and item["baked"].size() == int(expected["rot_baked"]) and item["fallback_id"] == expected["fallback_id"], "towns footprint/layer/authored views/fallback retained")
		var fingerprints: Array[String] = []
		for key in item["rot"]:
			var rotation := int(key)
			var art := PaintedShopArt.piece(id, rotation)
			var texture: Texture2D = load(str(art["path"])) as Texture2D
			var fp: Array = expected["footprint"].duplicate()
			if rotation % 2 == 1:
				fp.reverse()
			var pivot: Array = art["pivot"]
			var floor_pivot: bool = pivot[0] >= 0 and pivot[1] >= 0 and pivot[0] < texture.get_width() and pivot[1] < texture.get_height()
			var wall_pivot: bool = pivot[1] > 0 and pivot[0] >= 0 and pivot[0] < texture.get_width()
			if item["layer"] == "wall" and id != "sign_bracket":
				wall_pivot = wall_pivot and art.get("anchor") == "first_wall_cell" and int(art.get("mounting_height_px", 0)) == 45
			t.check("native_%s_r%s" % [id, key], texture.get_size() == Vector2(art["size"][0], art["size"][1]) and art["footprint"] == fp
				and (floor_pivot if item["layer"] == "floor" else wall_pivot) and FileAccess.file_exists("res://" + str(art["illustration"])) and not art["flip"], "native dimensions, floor/wall anchor and independent painted view")
			var hash_ := FileAccess.get_sha256(str(art["path"]))
			t.check("distinct_%s_r%s" % [id, key], hash_ not in fingerprints, "no reused image advertised as another authored rotation")
			fingerprints.append(hash_)
			var config := ConfigFile.new()
			config.load(str(art["path"]) + ".import")
			t.check("import_%s_r%s" % [id, key], int(config.get_value("params", "compress/mode", -1)) == 2 and config.get_value("params", "mipmaps/generate", false), "S3TC and mipmaps")
			var bytes := _bytes(art["size"])
			total_bytes += bytes
			sprite_bytes += bytes
			disk += FileAccess.get_file_as_bytes(str(art["path"])).size()
			count += 1
			if art.has("night"):
				var night_path := PaintedShopArt.PACK + str(art["night"])
				var night: Texture2D = load(night_path) as Texture2D
				var offset: Array = art["night_offset"]
				var size: Array = art["night_size"]
				var image := Image.new()
				image.load_webp_from_buffer(FileAccess.get_file_as_bytes(night_path))
				t.check("heat_%s_r%s" % [id, key], night.get_size() == Vector2(size[0], size[1]) and offset[0] >= 0 and offset[1] >= 0
					and offset[0] + size[0] <= texture.get_width() and offset[1] + size[1] <= texture.get_height()
					and image.get_used_rect() == Rect2i(0, 0, int(size[0]), int(size[1])), "trimmed light mask fits the painted fire; origin retained")
				total_bytes += _bytes(size)
				disk += FileAccess.get_file_as_bytes(night_path).size()
				night_count += 1
			elif id in ["forge", "brick_oven"]:
				t.check("solid_back_%s_r%s" % [id, key], rotation >= 2, "rear masonry carries no fire mask")
	for id in badges:
		var rec: Dictionary = badges[id]
		var path := PaintedShopArt.PACK + str(rec["file"])
		var texture: Texture2D = load(path) as Texture2D
		t.check("emblem_%s" % id, texture.get_size() == Vector2(96, 96) and Vector2(rec["pivot"][0], rec["pivot"][1]) == Vector2(48, 48) and id in contract["emblems"], "native round profession badge, separate bracket")
		total_bytes += _bytes(rec["size"])
		sprite_bytes += _bytes(rec["size"])
		disk += FileAccess.get_file_as_bytes(path).size()
	t.check("complete_exports", count == 51 and night_count == 5, "51 authored views plus 15 badges and five front-only fire masks")
	t.check("vram_budget", total_bytes <= 8.8e6 and sprite_bytes / 66.0 <= 150000, "RGBA8 + complete mip chains: %.3f MB / 8.8 MB; mean %.1f KB / 150 KB" % [total_bytes / 1e6, sprite_bytes / 66000.0])
	t.check("disk_budget", disk <= 800000, "%.3f MB / 0.8 MB for all exported artwork" % (disk / 1e6))
	var rooms := PaintedShopArt.rooms()
	t.check("core_rooms", rooms.size() == 14, "all 14 core layouts captured from the towns generator")
	for id in rooms:
		var missing: Array[String] = []
		var room_bytes := 0
		var paths: Dictionary = {}
		for item in rooms[id]["items"]:
			var art := PaintedShopArt.piece(str(item["id"]), int(item.get("rot", 0)))
			if art.is_empty():
				missing.append(str(item["id"]))
			elif pieces.has(item["id"]) and not paths.has(art["path"]):
				paths[art["path"]] = true
				room_bytes += _bytes(art["size"])
				if art.has("night"):
					room_bytes += _bytes(art["night_size"])
		t.check("room_%s" % id, missing.is_empty() and room_bytes <= 3e6, "zero unresolved pieces or requested rotations; core-kit textures %.3f MB / 3 MB, existing furniture/shell/cast separate; %s" % [room_bytes / 1e6, missing])
	var live_table := "res://data/interiors/kit_footprints.json"
	if FileAccess.file_exists(live_table):
		var live: Dictionary = _json(live_table)["pieces"]
		var mismatch: Array[String] = []
		for id in pieces:
			for field in ["footprint", "layer"]:
				if live.get(id, {}).get(field) != pieces[id][field]:
					mismatch.append("%s.%s" % [id, field])
		t.check("live_towns_contract", mismatch.is_empty(), str(mismatch))
	else:
		t.skip("live_towns_contract: T-towns-core is unfinished on m1b; local snapshot contract is checked above")
	var previous_clear := RenderingServer.get_default_clear_color()
	var studio: Node2D = load("res://tools/art/drawn/shop_core_gallery.tscn").instantiate()
	t.root.add_child(studio)
	t.check("studio_opens", studio.get("_ids").size() == 14 and studio.get("_view") != null, "developer art studio opens with the 14 rooms")
	studio.free()
	RenderingServer.set_default_clear_color(previous_clear)

func run_windowed(t) -> void:
	var entries: Array[Dictionary] = []
	var pieces := PaintedShopArt.pieces()
	for id in pieces:
		for rotation in pieces[id]["rot"]:
			var art := PaintedShopArt.piece(id, int(rotation))
			entries.append({"label": "%s r%s" % [id, rotation], "path": art["path"]})
	await _pages(t, "views", entries)
	entries.clear()
	var badges: Dictionary = _json(PaintedShopArt.PACK + "emblems.json")["emblems"]
	for id in badges:
		entries.append({"label": id, "path": PaintedShopArt.PACK + str(badges[id]["file"])})
	await _pages(t, "emblems", entries)
	for id in PaintedShopArt.rooms():
		var comparison: bool = id in ["bageriet", "smedjen", "badehuset"]
		for mode in (["stand_in", "day", "night"] if comparison else ["day"]):
			var view := View.new()
			t.root.add_child(view)
			view.setup_core(id, mode == "stand_in", mode == "night")
			view.fit_viewport(Vector2(1280, 650), Vector2(0, 40))
			await t.frames(4)
			if mode == "day" and comparison:
				await _keeper_depth(t, view, id)
			var image: Image = await t.capture("shop_%s_%s" % [id, mode])
			if image != null:
				t.expect_not_blank(image, Rect2i(0, 0, 1280, 720), "painted %s %s" % [id, mode])
			t.check("lights_%s_%s" % [id, mode], view.find_children("*", "PointLight2D", true, false).size() <= 1, "at most one service-fire light hint")
			view.free()
			await t.frames(1)

func _keeper_depth(t, view: Node2D, id: String) -> void:
	var keeper: Node2D = view.get_node("ReviewObjects/ShopKeeper")
	var counter: Node2D = view.get_node("ReviewObjects/Piece_counter_pine")
	var previous_mode := keeper.process_mode
	keeper.process_mode = Node.PROCESS_MODE_DISABLED
	RenderingServer.force_draw(false)
	var visible: Image = t.tree.root.get_texture().get_image()
	keeper.hide()
	await t.frames(2)
	RenderingServer.force_draw(false)
	var hidden: Image = t.tree.root.get_texture().get_image()
	var transform := keeper.get_global_transform_with_canvas()
	var feet := Rect2i(Rect2(transform * Vector2(-18, -10), transform.get_scale() * Vector2(36, 10)))
	var head := Rect2i(Rect2(transform * Vector2(-24, -125), transform.get_scale() * Vector2(48, 35)))
	counter.hide()
	await t.frames(2)
	RenderingServer.force_draw(false)
	var bare: Image = t.tree.root.get_texture().get_image()
	keeper.show()
	await t.frames(2)
	RenderingServer.force_draw(false)
	var uncovered: Image = t.tree.root.get_texture().get_image()
	var raw_feet := _pixel_difference(uncovered, bare, feet)
	var covered_feet := _pixel_difference(visible, hidden, feet)
	t.check("keeper_feet_occluded_%s" % id, raw_feet > .1 and covered_feet <= raw_feet * .1, "counter hides at least 90%% of foot contrast; %.3f covered / %.3f uncovered (negative control)" % [covered_feet, raw_feet])
	t.check("keeper_head_visible_%s" % id, _different_pixels(visible, hidden, head) > 20, "keeper remains visible above the counter")
	counter.show()
	keeper.process_mode = previous_mode
	await t.frames(2)

func _pixel_difference(a: Image, b: Image, rect: Rect2i) -> float:
	var difference := 0.0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var d := a.get_pixel(x, y) - b.get_pixel(x, y)
			difference += absf(d.r) + absf(d.g) + absf(d.b)
	return difference

func _different_pixels(a: Image, b: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				continue
			count += 1
	return count

func _pages(t, family: String, entries: Array[Dictionary]) -> void:
	for start in range(0, entries.size(), 15):
		var host := Control.new()
		t.root.add_child(host)
		var paper := ColorRect.new()
		paper.size = Vector2(1280, 720)
		paper.color = Color("eee7d8")
		host.add_child(paper)
		for index in range(start, mini(start + 15, entries.size())):
			var slot := index - start
			var at := Vector2(slot % 5 * 256 + 10, floorf(slot / 5.0) * 235 + 10)
			if family == "emblems":
				var bracket := PaintedShopArt.piece("sign_bracket")
				for rec in [bracket, {"path": entries[index]["path"], "pivot": [48, 48]}]:
					var sprite := Sprite2D.new()
					sprite.texture = load(str(rec["path"])) as Texture2D
					sprite.centered = false
					sprite.offset = -Vector2(rec["pivot"][0], rec["pivot"][1])
					sprite.position = at + Vector2(118, 125)
					host.add_child(sprite)
			else:
				var picture := TextureRect.new()
				picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				picture.texture = load(str(entries[index]["path"])) as Texture2D
				picture.position = at
				picture.size = Vector2(236, 195)
				host.add_child(picture)
			var label := Label.new()
			label.position = at + Vector2(0, 195)
			label.text = str(entries[index]["label"])
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color("2b2340"))
			host.add_child(label)
		await t.frames(3)
		var image: Image = await t.capture("shop_%s_%02d" % [family, floori(start / 15.0) + 1])
		if image != null:
			t.expect_not_blank(image, Rect2i(0, 0, 1280, 720), "imported painted %s" % family)
		host.free()
