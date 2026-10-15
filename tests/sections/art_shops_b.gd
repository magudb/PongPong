extends RefCounted
## Specialist art and removable dressing; runtime town integration is separate.
const SECTION := "art_shops_b"
const TIMEOUT_S := 150.0
const View = preload("res://tools/art/drawn/shop_special_view.gd")
const CoreChecks = preload("res://tests/sections/art_shops.gd")
const InteriorChecks = preload("res://tests/sections/art_interiors.gd")
const DOC := "res://docs/art/shop-special/"

func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _cells(item: Dictionary, defs: Dictionary) -> Array[Vector2i]:
	var fp: Array = defs[item["id"]]["footprint"].duplicate()
	if int(item.get("rot", 0)) % 2 == 1:
		fp.reverse()
	var out: Array[Vector2i] = []
	for x in int(fp[0]):
		for z in int(fp[1]):
			out.append(Vector2i(int(item["cell"][0]) + x, int(item["cell"][1]) + z))
	return out

func _at(c: Array) -> Vector2i:
	return Vector2i(int(c[0]), int(c[1]))

func _flood(room: Dictionary, blocked: Dictionary) -> Dictionary:
	var start := _at(room["spawn_cell"])
	if blocked.has(start):
		return {}
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	var index := 0
	while index < todo.size():
		var c := todo[index]
		index += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = c + d
			if q.x >= 0 and q.y >= 0 and q.x < int(room["cols"]) and q.y < int(room["rows"]) and not blocked.has(q) and not seen.has(q):
				seen[q] = true
				todo.append(q)
	return seen

func _issues(room: Dictionary, extras: Array, defs: Dictionary) -> Array[String]:
	var forbidden: Dictionary = {}
	var occupied: Dictionary = {}
	var hatch: Dictionary = {}
	var support: Dictionary = {}
	var errors: Array[String] = []
	for post in room["posts"]:
		forbidden[_at(post["cell"])] = true
		if str(post.get("kind", "")) == "keeper":
			for dx in [-1, 0, 1]:
				for z in [1, 3]:
					forbidden[Vector2i(int(post["cell"][0]) + dx, z)] = true
	for marker in room["markers"]:
		if marker["type"] == "hatch":
			for c in marker["cells"]:
				hatch[_at(c)] = true
				forbidden[_at(c)] = true
		elif marker["type"] != "door":
			forbidden[_at(marker["cell"])] = true
	for z in range(3, int(room["rows"])):
		forbidden[Vector2i(int(room["door"]["cell"][0]), z)] = true
	for item in room["items"]:
		for c in _cells(item, defs):
			if defs[item["id"]]["layer"] == "floor":
				occupied[c] = true
			if item.get("role") == "counter":
				forbidden[c] = true
	for item in room["items"] + extras:
		var d: Dictionary = defs.get(item.get("id"), {})
		if d.get("surface", false) or d.get("template") == "table" or item.get("id") in ["dough_table", "sewing_table", "seed_display_table", "potting_bench", "blueprint_table", "junk_table"]:
			for c in _cells(item, defs):
				support[c] = true
	for item in extras:
		if not defs.has(item.get("id")):
			errors.append("unknown ID")
			continue
		var layer := str(defs[item["id"]]["layer"])
		for c in _cells(item, defs):
			if c.x < 0 or c.y < 0 or c.x >= int(room["cols"]) or c.y >= int(room["rows"]):
				errors.append("outside floor")
			if layer != "wall" and forbidden.has(c):
				errors.append("reserved cell")
			if layer == "floor":
				if occupied.has(c):
					errors.append("overlapping furniture")
				occupied[c] = true
			if layer == "tabletop" and not support.has(c):
				errors.append("unsupported tabletop")
	var citizen := _flood(room, occupied)
	var player_blocked := occupied.duplicate()
	player_blocked.merge(hatch)
	var player := _flood(room, player_blocked)
	for post in room["posts"]:
		if not citizen.has(_at(post["cell"])):
			errors.append("post unreachable")
	for marker in room["markers"]:
		if marker["type"] not in ["hatch", "door"] and not player.has(_at(marker["cell"])):
			errors.append("host unreachable")
	if not player.has(_at(room["door"]["cell"])):
		errors.append("door unreachable")
	return errors

func run(t) -> void:
	var checks := CoreChecks.new()
	var contract := _json("res://tools/art/drawn/shop_special_layout.json")
	var pieces := PaintedShopArt.special_pieces()
	t.check("design_ids", pieces.keys() == (contract["pieces"] as Dictionary).keys() and pieces.size() == 69, "69 specialist IDs, exact published contract")
	var total_bytes := 0
	var disk := 0
	var count := 0
	var masks := 0
	var sets: Dictionary = {}
	for id in pieces:
		var item: Dictionary = pieces[id]
		var expected: Dictionary = contract["pieces"][id]
		sets[item["set"]] = true
		t.check("contract_%s" % id, item["footprint"] == expected["footprint"] and item["layer"] == expected["layer"] and item["baked"].size() == int(expected["rot_baked"]) and not item["mirror_ok"], "footprint, layer and independently authored rotation count retained")
		var fingerprints: Array[String] = []
		for key in item["rot"]:
			var art := PaintedShopArt.piece(id, int(key), false, true)
			var tex: Texture2D = load(str(art["path"])) as Texture2D
			var fp: Array = expected["footprint"].duplicate()
			if int(key) % 2 == 1:
				fp.reverse()
			var pivot: Array = art["pivot"]
			var anchor_ok: bool = pivot[0] >= 0 and pivot[0] < tex.get_width() and pivot[1] >= 0
			if item["layer"] == "floor":
				anchor_ok = anchor_ok and pivot[1] < tex.get_height()
			elif item["layer"] == "wall":
				var axis: Array = art["wall_axis"]
				anchor_ok = anchor_ok and art.get("anchor") == "first_wall_cell" and Vector2(axis[0], axis[1]) == Vector2(64 if int(key) == 0 else -64, 38)
			elif item["layer"] in ["ceiling", "tabletop"]:
				anchor_ok = anchor_ok and pivot[1] > tex.get_height() and int(art["elevation_px"]) == (112 if item["layer"] == "ceiling" else 60)
			t.check("native_%s_r%s" % [id, key], tex.get_size() == Vector2(art["size"][0], art["size"][1]) and art["footprint"] == fp and anchor_ok and not art["flip"] and FileAccess.file_exists("res://" + str(art["illustration"])), "native dimensions, mounting anchor and source painting")
			var hash_ := FileAccess.get_sha256(str(art["path"]))
			t.check("distinct_%s_r%s" % [id, key], hash_ not in fingerprints, "no copied or mirrored view presented as authored")
			fingerprints.append(hash_)
			var config := ConfigFile.new()
			config.load(str(art["path"]) + ".import")
			t.check("import_%s_r%s" % [id, key], int(config.get_value("params", "compress/mode", -1)) == 2 and config.get_value("params", "mipmaps/generate", false), "S3TC and mipmaps")
			total_bytes += checks._bytes(art["size"])
			disk += FileAccess.get_file_as_bytes(str(art["path"])).size()
			count += 1
			if art.has("night"):
				var tex_mask: Texture2D = load(str(art["night_path"])) as Texture2D
				var image := Image.new()
				image.load_webp_from_buffer(FileAccess.get_file_as_bytes(str(art["night_path"])))
				var o: Array = art["night_offset"]
				var s: Array = art["night_size"]
				t.check("accent_%s" % id, id in ["hanging_stars", "steam_vent"] and tex_mask.get_size() == Vector2(s[0], s[1]) and o[0] >= 0 and o[1] >= 0 and o[0] + s[0] <= tex.get_width() and o[1] + s[1] <= tex.get_height() and image.get_used_rect() == Rect2i(0, 0, int(s[0]), int(s[1])) and art["glow"]["light_hint"] == "none" and int(art["glow"]["point_lights"]) == 0, "trimmed additive paint accents, no extra point lights")
				total_bytes += checks._bytes(s)
				disk += FileAccess.get_file_as_bytes(str(art["night_path"])).size()
				masks += 1
	t.check("complete_exports", count == 115 and masks == 2 and sets.size() == 15, "115 authored views, two accent masks, 15 specialist sets")
	t.check("vram_budget", total_bytes <= 15.4e6, "RGBA8 plus complete mip chains: %.3f MB / 15.4 MB" % (total_bytes / 1e6))
	t.check("disk_budget", disk <= 1.4e6, "%.3f MB / 1.4 MB" % (disk / 1e6))
	var defs: Dictionary = _json(PaintedShopArt.FURNITURE + "furniture.json")["items"]
	defs.merge(PaintedShopArt.pieces(), true)
	defs.merge(pieces, true)
	var rooms: Dictionary = _json(DOC + "room-contracts.json")["rooms"]
	t.check("dressing_rooms", View.room_ids().size() == 15, "14 core rooms plus Hoppe's extended room snapshot")
	for id in View.room_ids():
		var room: Dictionary = rooms[id]
		var extra: Array = _json("res://data/interiors/dress/" + str(room["id"]) + ".json")["items"]
		var issues := _issues(room, extra, defs)
		t.check("access_%s" % id, extra.size() >= 2 and extra.size() <= 6 and issues.is_empty(), "2–6 optional pieces, full tabletop support, keeper/posts/door/customer access: %s" % [issues])
		var bytes := 0
		var paths: Dictionary = {}
		for item in room["items"] + extra:
			var is_extra: bool = item in extra
			var art := PaintedShopArt.piece(str(item["id"]), int(item.get("rot", 0)), false, is_extra)
			t.check("resolved_%s_%s" % [id, item["id"]], not art.is_empty(), "requested authored view exists")
			if art.is_empty() or paths.has(art["path"]):
				continue
			paths[art["path"]] = true
			if str(art["path"]).begins_with(PaintedShopArt.PACK) or str(art["path"]).begins_with(PaintedShopArt.SPECIAL):
				bytes += checks._bytes(art["size"])
				if art.has("night"):
					bytes += checks._bytes(art["night_size"])
		t.check("room_budget_%s" % id, bytes <= 3e6, "combined core + specialist kit %.3f MB / 3 MB; shell/cast/existing furniture separate" % (bytes / 1e6))
		var blocked_door: Array = extra.duplicate(true)
		blocked_door.append({"id": "barrel", "cell": room["door"]["cell"], "rot": 0})
		t.check("negative_door_%s" % id, not _issues(room, blocked_door, defs).is_empty(), "negative control: blocked door rejected")
		if not room["posts"].is_empty():
			var blocked_post: Array = extra.duplicate(true)
			blocked_post.append({"id": "barrel", "cell": room["posts"][0]["cell"], "rot": 0})
			t.check("negative_post_%s" % id, not _issues(room, blocked_post, defs).is_empty(), "negative control: occupied citizen post rejected")
	var towns := _json(DOC + "towns-validator.json")
	t.check("towns_validator_evidence", towns["rooms"].size() == 15 and (towns["rooms"] as Dictionary).values().all(func(v): return v.is_empty()), "all 15 overlays also passed the actual towns validator; source hash recorded")
	for path in towns["inputs_sha256"]:
		t.check("towns_evidence_%s" % path.get_file(), FileAccess.get_sha256("res://" + path) == towns["inputs_sha256"][path], "external-validator evidence belongs to the current room inputs")
	if FileAccess.file_exists("res://data/interiors/kit_footprints.json"):
		var live: Dictionary = _json("res://data/interiors/kit_footprints.json")["pieces"]
		for id in pieces:
			t.check("live_%s" % id, live.get(id, {}).get("footprint") == pieces[id]["footprint"] and live.get(id, {}).get("layer") == pieces[id]["layer"], "live towns consumer matches saved contract")
	else:
		t.skip("live_towns_contract: T-towns-core is unfinished on m1b; art contract and validator snapshots checked")
	t.skip("live_hoppe_room: T-ext-content is not installed here; extended-room dressing uses its generator snapshot")
	var old_clear := RenderingServer.get_default_clear_color()
	var studio: Node2D = load("res://tools/art/drawn/shop_special_gallery.tscn").instantiate()
	t.root.add_child(studio)
	t.check("studio_opens", studio.get("_ids").size() == 15 and studio.get("_view") != null, "browse-only studio opens without installing gameplay")
	studio.free()
	RenderingServer.set_default_clear_color(old_clear)

func _node_count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _node_count(child)
	return n

func _room_textures(view: Node2D) -> Dictionary:
	var textures: Dictionary = {}
	for node in view.find_children("*", "Sprite2D", true, false):
		var texture: Texture2D = node.texture
		if texture == null or texture.resource_path.contains("/isometric_characters/"):
			continue
		textures[texture.resource_path] = texture
	var terrain: Texture2D = ArtCatalog.terrain(StringName(str(view.get("room")["floor"])))["texture"]
	textures[terrain.resource_path] = terrain
	var sizes: Dictionary = {}
	for path in textures:
		sizes[path] = InteriorChecks.new()._texture_bytes(textures[path])
	return sizes

func run_windowed(t) -> void:
	var observations: Dictionary = {}
	var pieces := PaintedShopArt.special_pieces()
	var sets: Dictionary = {}
	for id in pieces:
		sets[str(pieces[id]["set"])] = true
	for set_id in sets:
		var entries: Array[Dictionary] = []
		for id in pieces:
			if pieces[id]["set"] != set_id:
				continue
			for rotation in pieces[id]["rot"]:
				var art := PaintedShopArt.piece(id, int(rotation), false, true)
				entries.append({"label": "%s r%s" % [id, rotation], "path": art["path"]})
		await CoreChecks.new()._pages(t, "special_" + set_id, entries)
	for id in View.room_ids():
		for mode in (["bare", "day", "night"] if id in ["bageriet", "smedjen", "skraedderiet"] else ["day", "night"]):
			var view := View.new()
			t.root.add_child(view)
			view.setup_special(id, mode != "bare", mode == "night")
			view.fit_viewport(Vector2(1280, 650), Vector2(0, 40))
			await t.frames(4)
			var image: Image = await t.capture("special_%s_%s" % [id, mode])
			if image != null:
				t.expect_not_blank(image, Rect2i(0, 0, 1280, 720), "painted specialist %s %s" % [id, mode])
			t.check("nodes_%s_%s" % [id, mode], _node_count(view) <= 130, "%s native scene nodes / 130" % _node_count(view))
			t.check("lights_%s_%s" % [id, mode], view.find_children("*", "PointLight2D", true, false).size() <= 1, "no added point lights; at most the existing core fire light")
			var texture_sizes := _room_textures(view)
			var bytes := 0.0
			for size in texture_sizes.values():
				bytes += float(size)
			t.check("resident_%s_%s" % [id, mode], bytes <= 3e6, "imported shell/floor/furniture/core/specialist/accents %.3f MB / 3 MB; shared cast and procedural fire-light texture separate" % (bytes / 1e6))
			observations[id + "_" + mode] = {"nodes": _node_count(view), "point_lights": view.find_children("*", "PointLight2D", true, false).size(), "imported_room_texture_bytes": bytes, "textures": texture_sizes}
			if mode == "night" and id in ["badehuset", "troldmandstaarnet"]:
				t.check("accent_visible_%s" % id, view.find_children("Accent_*", "Sprite2D", true, false).size() == 1, "specialist additive accent mounted over the painted object")
			view.free()
			await t.frames(1)
	var report := FileAccess.open(DOC + "native-room-budgets.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(observations, "  ") + "\n")
