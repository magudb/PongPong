extends RefCounted
## I5 art contract and native placement studies, independent of festival gameplay.
const SECTION := "art_festival"
const TIMEOUT_S := 150.0
const View = preload("res://tools/art/drawn/festival_view.gd")
const CoreChecks = preload("res://tests/sections/art_shops.gd")
const DOC := "res://docs/art/festival/"
const SEASONS := ["spring", "summer", "autumn", "winter"]
const EXAMPLES := ["blomsterfesten", "midsommerlanterner", "hoestfesten", "vinterlysene"]

func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _bytes(size: Array) -> int:
	return CoreChecks.new()._bytes(size)

func _textures(node: Node) -> Dictionary:
	var out: Dictionary = {}
	for sprite in node.find_children("*", "Sprite2D", true, false):
		var texture: Texture2D = sprite.texture
		if texture != null and texture.resource_path.begins_with(PaintedFestivalArt.PACK):
			out[texture.resource_path] = [texture.get_width(), texture.get_height()]
	return out

func _resident(node: Node) -> int:
	var bytes := 0
	for size in _textures(node).values():
		bytes += _bytes(size)
	return bytes

func run(t) -> void:
	var manifest := PaintedFestivalArt.manifest()
	var items: Dictionary = manifest["items"]
	var contract := _json("res://tools/art/drawn/festival_layout.json")
	t.check("design_ids", items.size() == 24 and items.keys() == (contract["pieces"] as Dictionary).keys(), "all 24 I5 piece IDs follow the published contract")
	var count := 0
	var masks := 0
	var bytes := 0
	var disk := 0
	var exported: Dictionary = {}
	for id in items:
		var expected: Dictionary = contract["pieces"][id]
		var item: Dictionary = items[id]
		t.check("contract_%s" % id, item["footprint"] == expected["footprint"] and item["layer"] == expected["layer"] and item["baked"].size() == int(expected["rot_baked"]) and not item["mirror_ok"] and not item["solid"], "footprint, layer and authored views retained; non-solid art")
		var hashes: Array[String] = []
		for key in item["rot"]:
			var art := PaintedFestivalArt.piece(id, int(key))
			var texture: Texture2D = load(str(art["path"])) as Texture2D
			var fp: Array = expected["footprint"].duplicate()
			if int(key) % 2 == 1:
				fp.reverse()
			var pivot: Array = art["pivot"]
			var valid_pivot: bool = pivot[0] >= 0 and pivot[0] < texture.get_width() and pivot[1] >= 0
			if item["layer"] == "floor":
				valid_pivot = valid_pivot and pivot[1] < texture.get_height()
			elif item["layer"] == "ceiling":
				var span: Array = art["span_px"]
				valid_pivot = valid_pivot and art["anchor"] == "first_post" and Vector2(span[0], span[1]) == Vector2(192 if int(key) == 0 else -192, 114) and int(art["elevation_px"]) == 225
			else:
				valid_pivot = valid_pivot and art["anchor"] == "first_wall_cell" and int(art["mounting_height_px"]) == 95
			t.check("native_%s_r%s" % [id, key], texture.get_size() == Vector2(art["size"][0], art["size"][1]) and art["footprint"] == fp and valid_pivot and not art["flip"] and FileAccess.file_exists("res://" + str(art["illustration"])), "native image, floor/rope/wall anchor and selected painting agree")
			var hash_ := FileAccess.get_sha256(str(art["path"]))
			t.check("authored_%s_r%s" % [id, key], hash_ not in hashes, "no reused image advertised as an authored quarter turn")
			hashes.append(hash_)
			var settings := ConfigFile.new()
			settings.load(str(art["path"]) + ".import")
			t.check("import_%s_r%s" % [id, key], int(settings.get_value("params", "compress/mode", -1)) == 2 and settings.get_value("params", "mipmaps/generate", false), "S3TC + mipmaps")
			bytes += _bytes(art["size"])
			disk += FileAccess.get_file_as_bytes(str(art["path"])).size()
			exported[art["file"]] = true
			count += 1
			if art.has("night"):
				var image := Image.new()
				image.load_webp_from_buffer(FileAccess.get_file_as_bytes(str(art["night_path"])))
				var offset: Array = art["night_offset"]
				var size: Array = art["night_size"]
				t.check("glow_%s_r%s" % [id, key], image.get_size() == Vector2i(int(size[0]), int(size[1])) and image.get_used_rect() == Rect2i(0, 0, int(size[0]), int(size[1])) and offset[0] >= 0 and offset[1] >= 0 and offset[0] + size[0] <= texture.get_width() and offset[1] + size[1] <= texture.get_height() and art["glow"]["blend"] == "add" and art["glow"]["light_hint"] == "none" and int(art["glow"]["point_lights"]) == 0, "trimmed candle/flame accent fits its body and adds no point light")
				bytes += _bytes(size)
				disk += FileAccess.get_file_as_bytes(str(art["night_path"])).size()
				exported[art["night"]] = true
				masks += 1
	t.check("complete_exports", count == 53 and masks == 6, "53 authored views and six trimmed light accents")
	t.check("all_resident_budget", bytes <= 7e6, "all views + accents %.3f MB RGBA8/mips / 7 MB" % (bytes / 1e6))
	t.check("disk_budget", disk <= 700000, "%.3f MB / 0.7 MB" % (disk / 1e6))
	var actual: Dictionary = {}
	for file in DirAccess.get_files_at(PaintedFestivalArt.PACK):
		if file.ends_with(".webp"):
			actual[file] = true
	t.check("no_orphan_exports", actual.size() == exported.size() and actual.keys().all(func(k): return exported.has(k)), "every exported texture is declared exactly once")
	var config: Dictionary = GameData.cfg("festival_decor", {})
	var planned := _json(DOC + "placement.json")
	var matches: bool = config["sets"] == planned["sets"] and config["festivals"] == planned["festivals"] and JSON.parse_string(JSON.stringify(config["layout"])) == planned["layout"]
	for season_ in SEASONS:
		matches = matches and LuaData.arr(config["season_accents"][season_]) == planned["season_accents"][season_]
	t.check("config_matches_design", matches, "literal Lua placement design matches saved art data; empty Lua lists and JSON numbers normalized")
	for season_ in SEASONS:
		var set_: Dictionary = manifest["sets"][season_]
		t.check("slots_%s" % season_, set_.size() == 7 and ["pole", "string", "stage", "bench", "centre", "awning", "door"].all(func(k): return set_.has(k) and items.has(set_[k])), "all seven seasonal slot designs resolve")
	var contracts := _json(DOC + "contracts.json")
	var names: Dictionary = contracts["standard_posts"]
	var posts := View.standard_posts(Vector2.ZERO)
	t.check("standard_posts", posts.size() == 24 and names.keys().all(func(k): return posts.has(k)), "one standard set: host, judge, four stalls, two tables and sixteen gather posts")
	for name_ in names:
		var c: Array = names[name_]
		t.check("post_%s" % name_, posts[name_] == Vector2((float(c[0]) - float(c[1])) * 64, (float(c[0]) + float(c[1])) * 38), "published post offset projected with the actual tile geometry")
	for row in LuaData.arr(config["layout"]):
		t.check("layout_%s_%s" % [row["slot"], row["post"]], names.has(row["post"]) and (not row.has("to_post") or names.has(row["to_post"])), "decor refers only to standard posts")
	var mapping := {"foraar": "spring", "sommer": "summer", "efteraar": "autumn", "vinter": "winter"}
	for id in contracts["festivals"]:
		t.check("calendar_%s" % id, config["festivals"].has(id) and config["festivals"][id]["set"] == mapping[contracts["festivals"][id]["season"]], "nine fixed festivals use the designed season")
	t.check("wedding", config["festivals"].has("bryllupsfesten") and config["festivals"]["bryllupsfesten"]["centre"] == "flower_arch", "the date-dependent wedding has its spring art row")
	var budgets: Dictionary = {}
	for id in config["festivals"]:
		var holder := Node2D.new()
		t.root.add_child(holder)
		var decor := PaintedFestivalArt.create(holder, id, posts, [{"at": Vector2(600, 0), "rot": 0, "rank": 12}, {"at": Vector2(600, 100), "rot": 1}], 0, true)
		var resident := _resident(decor)
		budgets[id] = {"selected_view_rgba8_mips_bytes": resident, "unique_textures": _textures(decor).size(), "scope": "views used by this fixture, shared cast/town separate; not every rotation in a season's library"}
		t.check("season_budget_%s" % id, resident <= 1.8e6, "one event's selected views + accents + both door orientations %.3f MB / 1.8 MB" % (resident / 1e6))
		t.check("non_solid_%s" % id, decor.find_children("*", "CollisionObject2D", true, false).is_empty() and decor.find_children("*", "CollisionShape2D", true, false).is_empty() and decor.find_children("*", "PointLight2D", true, false).is_empty(), "no collisions, route changes or extra lights")
		var awnings := decor.get_children().filter(func(n): return n is Sprite2D and (n as Sprite2D).texture.resource_path.get_file().begins_with("market_stall_"))
		t.check("shared_stalls_%s" % id, awnings.size() == 4 and awnings.all(func(s): return s.texture == awnings[0].texture), "four stalls share one selected texture")
		var stage := decor.get_child(0) as Sprite2D
		t.check("world_scale_%s" % id, is_equal_approx(stage.scale.x, float(PaintedFestivalArt.piece("festival_stage")["render_scale"])) and stage.position == Vector2.ZERO, "export resolution does not shrink the world's stage or move its ground anchor")
		if config["festivals"][id]["door_wreaths"]:
			t.check("door_plane_%s" % id, decor.get_children().filter(func(n): return n.z_index == 12).size() == 1, "a wreath on another city platform keeps its supplied door rank")
		holder.free()
	var report := FileAccess.open(DOC + "event-budgets.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(budgets, "  ") + "\n")
	var empty := PaintedFestivalArt.placements("missing_festival", posts)
	t.check("unknown_event", empty.is_empty(), "unregistered festival has no accidental art")
	t.check("missing_anchors", PaintedFestivalArt.placements("honningdagen", {}).is_empty(), "missing post data does not pile decoration at the world origin")
	t.info("Live festival lifecycle and routed city posts are exercised by social_fest_content, festival_activities and town_loop; this section checks the independent art contract.")
	var before: Dictionary = EconomyManager.to_dict().duplicate(true)
	var studio: Node2D = load("res://tools/art/drawn/festival_gallery.tscn").instantiate()
	t.root.add_child(studio)
	t.check("studio_opens", studio.get("_view") != null and before == EconomyManager.to_dict(), "developer art studio opens without granting items or starting a festival")
	studio.free()
	for town in ["hyggebyen", "traetoppen"]:
		var view := View.new()
		t.root.add_child(view)
		view.setup(town, EXAMPLES[0])
		t.check("fixture_builds_%s" % town, view.decor != null and view.camera != null and view.find_children("FestivalReviewHost", "", true, false).size() == 1, "the %s art fixture builds its decor, guests and camera on the installed town (the windowed studies use it)" % town)
		view.free()
	var weak := _released_art(t, posts)
	await t.frames(2)
	t.check("art_freed_with_host", weak[0].get_ref() == null and weak[1].get_ref() == null, "art root and selected texture resource are released with their owner; GPU pool allocations are separate")

func _released_art(t, posts: Dictionary) -> Array[WeakRef]:
	var holder := Node2D.new()
	t.root.add_child(holder)
	var decor := PaintedFestivalArt.create(holder, "honningdagen", posts)
	var texture: Texture2D = (decor.get_child(0) as Sprite2D).texture
	var weak: Array[WeakRef] = [weakref(decor), weakref(texture)]
	holder.free()
	return weak

func run_windowed(t) -> void:
	var manifest := PaintedFestivalArt.manifest()
	var reviewed: Dictionary = {}
	for season_ in SEASONS:
		var ids: Array = (manifest["sets"][season_] as Dictionary).values()
		ids.append_array(manifest["season_accents"][season_])
		var entries: Array[Dictionary] = []
		for id in ids:
			for rotation in manifest["items"][id]["rot"]:
				var art := PaintedFestivalArt.piece(id, int(rotation))
				entries.append({"label": "%s r%s" % [id, rotation], "path": art["path"]})
				reviewed[art["path"]] = true
		await CoreChecks.new()._pages(t, "festival_" + season_, entries)
	t.check("all_views_reviewed", reviewed.size() == 53, "all 53 authored views appear in the four seasonal sheet groups")
	for town in ["hyggebyen", "traetoppen"]:
		for index in 4:
			for mode in ["day", "evening"]:
				var view := View.new()
				t.root.add_child(view)
				view.setup(town, EXAMPLES[index], mode == "evening")
				await t.frames(5)
				var image: Image = await t.capture("festival_%s_%s_%s" % [town, SEASONS[index], mode])
				if image != null:
					t.expect_not_blank(image, Rect2i(0, 0, 1280, 720), "painted %s %s %s art study" % [town, SEASONS[index], mode])
				t.check("lights_%s_%s_%s" % [town, SEASONS[index], mode], view.area.find_children("*", "PointLight2D", true, false).size() <= 12 and view.decor.find_children("*", "PointLight2D", true, false).is_empty(), "at most twelve existing town lights; decor adds zero")
				t.check("budget_%s_%s_%s" % [town, SEASONS[index], mode], _resident(view.decor) <= 1.8e6, "native fixture holds only the selected festival art within 1.8 MB")
				view.free()
				await t.frames(1)
