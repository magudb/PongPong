extends Node
## Rebuild route distances from the shipped maps, room colliders and level graph.
@onready var root: Window = get_tree().root

var routes := {"areas": {}, "portals": [], "format": 1, "inputs": {}}
var failures: Array[String] = []
var gates_of: Dictionary = {}

func run() -> void:
	await get_tree().process_frame
	var begin := Time.get_ticks_usec()
	for id in ["hyggebyen", "farm"]:
		await _grid(id)
	_city()
	await _rooms()
	for gate in LuaData.arr(_sidecar().get("gates", [])):
		routes.portals.append(["traetoppen." + str(gate.name), str(gate.to) + "." + str(gate.to_gate)])
	for area in gates_of:
		for gate in gates_of[area]:
			routes.portals.append([str(area) + "." + str(gate.name), str(gate.to) + "." + str(gate.to_gate)])
	for path in input_paths():
		routes.inputs[path] = FileAccess.get_sha256(path)
	if not failures.is_empty():
		for failure in failures:
			print("FAIL ", failure)
		get_tree().quit(1)
		return
	var output := "res://data/towns/routes.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		print("FAIL cannot write ", output)
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(routes, "", true) + "\n")
	file.close()
	print("PASS route_bake: %d areas, %.1f ms, %d source hashes" % [routes.areas.size(), float(Time.get_ticks_usec() - begin) / 1000.0, routes.inputs.size()])
	get_tree().quit()

static func input_paths() -> Array[String]:
	var paths: Array[String] = ["res://data/maps/hyggebyen.map", "res://data/maps/farm.map", "res://data/towns/traetoppen.json", "res://data/traetoppen/traetoppen.json", "res://scripts/towns/nav_grid.gd", "res://scripts/towns/level_nav.gd", "res://scripts/towns/fest_set.gd", "res://scripts/towns/town_marks.gd", "res://tools/towns/bake_routes.gd", "res://tools/towns/route_baker.gd", "res://lua/config/props.lua", "res://data/interiors/kit_footprints.json"]
	for dir in ["res://data/interiors/core", "res://data/interiors/ext", "res://data/interiors/dress"]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for name in DirAccess.get_files_at(dir):
			if name.ends_with(".json"):
				paths.append(dir + "/" + name)
	for path in ["res://assets/iso_props/furniture/furniture.json", "res://assets/iso_props/shops/core/shops.json", "res://assets/iso_props/shops/special/shops.json"]:
		if FileAccess.file_exists(path):
			paths.append(path)
	paths.sort()
	return paths

func _sidecar() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/towns/traetoppen.json"))

func _matrix(nav: NavGrid, names: Array, cells: Array, caps: Array, id: String) -> Dictionary:
	var matrix: Array = []
	var positions: Array = []
	for i in names.size():
		var row: Array = []
		var pos := Iso.to_ground(nav.cell_pos(cells[i]))
		positions.append([pos.x, pos.y])
		for j in names.size():
			if i == j:
				row.append(0)
				continue
			var path := nav.path(cells[i], cells[j])
			if not bool(path.ok):
				failures.append("%s: %s -> %s has no route" % [id, names[i], names[j]])
			row.append(roundi(float(path.length)) if path.ok else -1)
		matrix.append(row)
	return {"names": names, "d": matrix, "cap": caps, "pos": positions}

func _grid(id: String) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(AreaMap.parse_text(FileAccess.get_file_as_string("res://data/maps/" + id + ".map")))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var markers := TownMarks.collect(area)
	var nav := NavGrid.bake_area(area)
	var resolved := TownMarks.resolve_cells(nav, markers)
	var names: Array = []
	var cells: Array = []
	var caps: Array = []
	failures.append_array(markers.errors)
	gates_of[id] = markers.gates
	for door in markers.doors:
		var name := "door_" + str(door.building)
		names.append(name)
		cells.append(resolved.cells[name])
		caps.append(99)
	for gate in markers.gates:
		names.append(str(gate.name))
		cells.append(resolved.cells[gate.name])
		caps.append(99)
	for post in markers.posts:
		if FestSet.is_satellite(str(post.name)):
			continue
		names.append(str(post.name))
		cells.append(resolved.cells[post.name])
		caps.append(int(post.get("cap", 1)))
	for snap in resolved.snaps:
		if int(snap[1]) > 2:
			failures.append("%s anchor %s moved %s cells" % [id, snap[0], snap[1]])
	routes.areas[id] = _matrix(nav, names, cells, caps, id)
	routes.areas[id]["snaps"] = resolved.snaps
	print("BAKE ", id, ": ", names.size(), " anchors; ", nav.bake_us, " us navigation")
	holder.free()
	await get_tree().process_frame

func _city() -> void:
	var city := _sidecar()
	var nav := LevelNav.make(LevelRegistry.shipped_graph())
	var names: Array = []
	var positions: Array = []
	var levels: Array = []
	var caps: Array = []
	for door in city.doors:
		names.append("door_" + str(door.building))
		positions.append(nav.ground_of(float(door.sx), float(door.sy)))
		levels.append(int(door.level))
		caps.append(99)
	for type in ["gates", "posts", "fest_sets"]:
		for post in LuaData.arr(city.get(type, [])):
			names.append("fest_%s_host" % post.spot if type == "fest_sets" else str(post.name))
			positions.append(nav.ground_of(float(post.sx), float(post.sy)))
			levels.append(int(post.level))
			caps.append(99 if type == "gates" else int(post.get("cap", 1)))
	var matrix: Array = []
	var snaps: Array = []
	var authored: Array = []
	for i in positions.size():
		authored.append([positions[i].x, positions[i].y])
		var snapped := nav.snap(positions[i], int(levels[i]))
		if not snapped.ok:
			failures.append("traetoppen: no walkable point for " + str(names[i]))
		else:
			positions[i] = snapped.pos
			snaps.append({"name": names[i], "distance": snapped.distance})
			if float(snapped.distance) > 64.0:
				print("SNAP ", names[i], ": ", snapped)
	for i in names.size():
		var row: Array = []
		for j in names.size():
			if i == j:
				row.append(0)
				continue
			var path := nav.route(positions[i], levels[i], positions[j], levels[j])
			if path.polyline.is_empty():
				failures.append("traetoppen: %s -> %s has no route" % [names[i], names[j]])
			row.append(roundi(float(path.length)) if not path.polyline.is_empty() else -1)
		matrix.append(row)
	var pos: Array = []
	for point in positions:
		pos.append([point.x, point.y])
	routes.areas.traetoppen = {"names": names, "d": matrix, "pos": pos, "authored_pos": authored, "level": levels, "cap": caps, "snaps": snaps}
	print("BAKE traetoppen: ", names.size(), " anchors; ", nav.bake_info)

func _rooms() -> void:
	for dir in ["res://data/interiors/core", "res://data/interiors/ext"]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for name in DirAccess.get_files_at(dir):
			if not name.ends_with(".json") or not name.begins_with("int_"):
				continue
			var id := name.trim_suffix(".json")
			var spec := InteriorRoom.load_spec(id)
			var holder := Node2D.new()
			root.add_child(holder)
			var area := IsoArea.new()
			holder.add_child(area)
			area.setup(AreaMap.parse_text(InteriorRoom.stub_map(id, str(spec.building), "city")))
			await get_tree().physics_frame
			await get_tree().physics_frame
			var nav := NavGrid.bake_room(area, int(spec.cols), int(spec.rows), Iso.LAYER_WORLD | Iso.LAYER_GROUND_BLOCK)
			var names: Array = ["door"]
			var caps: Array = [99]
			var cells: Array = [Vector2i(int(spec.door.cell[0]), int(spec.door.cell[1]))]
			for post in spec.posts:
				names.append(str(post.id))
				caps.append(int(post.get("capacity", 1)))
				cells.append(Vector2i(int(post.cell[0]), int(post.cell[1])))
			for cell in cells:
				nav.force_free(cell)
			routes.areas[id] = _matrix(nav, names, cells, caps, id)
			routes.portals.append([id + ".door", str(spec.exit.area) + ".door_" + str(spec.building)])
			holder.free()
			await get_tree().process_frame
