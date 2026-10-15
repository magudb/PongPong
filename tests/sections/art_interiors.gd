extends RefCounted
## Effective assets + layout usability; timings are observations on the current host.
const SECTION := "art_interiors"
const TIMEOUT_S := 120.0
const ViewScript = preload("res://tools/art/drawn/interiors_view.gd")

func run(t) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PaintedInteriorArt.PACK + "props.json"))
	var count := 0
	for id in manifest:
		if str(id).begins_with("_"):
			continue
		var rec: Dictionary = manifest[id]
		var art: Dictionary = ArtCatalog.prop(StringName(id))
		var tex: Texture2D = art["texture"]
		t.check("asset_%s" % id, bool(art["real"]) and tex.resource_path.begins_with(PaintedInteriorArt.PACK)
			and tex.get_width() == int(rec["size"][0]) and tex.get_height() == int(rec["size"][1])
			and FileAccess.file_exists("res://" + str(rec["illustration"])), "painted source, effective texture and dimensions agree")
		count += 1
	t.check("complete_kit", count == 103, "52 furnishing/service/dressing sprites, 15 emblems, 28 wall/corner pieces and 8 night masks")
	var ids := PaintedInteriorArt.room_ids()
	t.check("all_room_studies", ids.size() == 34, "10 home upgrades and 24 town interiors")
	var max_ms := 0.0
	for id in ids:
		var room := PaintedInteriorArt.room(id)
		var floor_cells: Dictionary = {}
		for c in room["cells"]:
			floor_cells[Vector2i(int(c[0]), int(c[1]))] = true
		var used: Dictionary = {}
		var errors: Array[String] = []
		var textures: Dictionary = {}
		for item in room["decor"]:
			textures[str(item["asset"])] = true
		var rugs_fit := true
		for item in room["ground_decor"]:
			textures[str(item["asset"])] = true
			var span: Array = ArtCatalog.prop_metadata(StringName(item["asset"]))["ground_span"]
			var first: Array = item["cell"]
			for y in int(span[1]):
				for x in int(span[0]):
					rugs_fit = rugs_fit and floor_cells.has(Vector2i(int(first[0]) + x, int(first[1]) + y))
		t.check("textiles_%s" % id, rugs_fit, "painted rugs stay within the floor and carry no collision footprint")
		for item in room["items"]:
			var name_: String = item["asset"]
			textures[name_] = true
			for cell in PaintedInteriorArt.item_cells(item):
				if not floor_cells.has(cell) or used.has(cell):
					errors.append("outside or overlapping: %s at %s" % [name_, cell])
				used[cell] = true
		var free: Dictionary = {}
		for c in room["walkable_cells"]:
			var cell := Vector2i(int(c[0]), int(c[1]))
			free[cell] = true
			if used.has(cell):
				errors.append("occupied walkable cell %s" % cell)
		var door: Array = room["door"]["cell"]
		var spawn: Array = room["spawn_cell"]
		var start := Vector2i(int(door[0]), int(door[1]))
		var spawn_cell := Vector2i(int(spawn[0]), int(spawn[1]))
		t.check("layout_%s" % id, errors.is_empty() and free.has(start) and free.has(spawn_cell) and _reachable(free, start) == free.size(),
			"no overlaps; entrance, spawn and all public floor connected; %s" % str(errors))
		if room.has("keeper_cell"):
			var c: Array = room["keeper_cell"]
			t.check("staff_band_%s" % id, not free.has(Vector2i(int(c[0]), int(c[1])))
				and free.has(Vector2i(start.x, 3)), "customer approach remains in front of the counter; keeper stays behind it")
		if room["kind"] == "home_upgrade":
			var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + str(room["source_room"])))
			t.check("tier_contract_%s" % id, source["cells"] == room["cells"] and source["door"] == room["door"]
				and source["floor"] == room["floor"] and source["max_furniture"] >= room["items"].size(), "authored footprint, doorway, floor and capacity remain the home tier's")
		var style: String = room["wall_material"]
		for kind in ["a", "b", "win"]:
			for rotation in [0, 1]:
				textures["wall_%s_%s_r%d" % [style, kind, rotation]] = true
				if kind == "win":
					textures["wall_%s_%s_r%d_night" % [style, kind, rotation]] = true
		textures["corner_" + style] = true
		textures["emblem_" + str(room["emblem"])] = true
		var bytes := 0.0
		for texture_id in textures:
			var tex: Texture2D = ArtCatalog.prop(StringName(texture_id))["texture"]
			bytes += _texture_bytes(tex)
		var terrain: Texture2D = ArtCatalog.terrain(StringName(room["floor"]))["texture"]
		bytes += float(terrain.get_width() * terrain.get_height()) * 4.0
		t.check("texture_budget_%s" % id, bytes <= 3.0e6, "%.2f MB conservative S3TC RGBA + floor estimate; shared character atlases excluded" % (bytes / 1.0e6))
		var before := Time.get_ticks_usec()
		var view := ViewScript.new()
		t.root.add_child(view)
		view.setup(id)
		max_ms = maxf(max_ms, float(Time.get_ticks_usec() - before) / 1000.0)
		view.free()
		var evening := ViewScript.new()
		t.root.add_child(evening)
		evening.setup(id, true)
		var nodes := evening.find_children("*", "", true, false)
		var lights := evening.find_children("*", "PointLight2D", true, false)
		t.check("scene_budget_%s" % id, nodes.size() + 1 <= 130 and lights.size() <= 4,
			"evening scene: %d nodes, %d lights; targets 130 / 4" % [nodes.size() + 1, lights.size()])
		evening.free()
	t.info("assembled all 34 native room studies; maximum build %.2f ms on this host (observational, not a frame-time budget)" % max_ms)
	var copy := PaintedInteriorArt.room("home_t01")
	copy["items"].clear()
	t.check("room_data_is_owned", not PaintedInteriorArt.room("home_t01")["items"].is_empty(), "editing a returned layout does not mutate the catalog")

func _texture_bytes(texture: Texture2D) -> float:
	var settings := ConfigFile.new()
	settings.load(texture.resource_path + ".import")
	var compressed: bool = int(settings.get_value("params", "compress/mode", 0)) == 2
	var mipmaps: bool = settings.get_value("params", "mipmaps/generate", false)
	var w := texture.get_width()
	var h := texture.get_height()
	var bytes := 0.0
	while true:
		# DXT5's 16-byte 4x4 blocks conservatively cover RGBA S3TC, including tiny mip padding.
		bytes += float(ceili(w / 4.0) * ceili(h / 4.0) * 16) if compressed else float(w * h * 4)
		if not mipmaps or (w == 1 and h == 1):
			break
		w = maxi(w >> 1, 1)
		h = maxi(h >> 1, 1)
	return bytes

func _reachable(cells: Dictionary, start: Vector2i) -> int:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size()
