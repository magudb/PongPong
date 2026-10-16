class_name LevelNav
extends RefCounted
## Level-aware paths over the actual LevelRegistry polygons, holes and keepouts.
## Points use ground pixels. Authored sidecar points use the registry's sketch scale.
const CELL := 32.0
const BODY := 20.0
const BAKED_CELLS := "res://data/towns/nav_city.json"
static var use_baked_cells := true
var data: Dictionary
var levels: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var gate_ids: Dictionary = {}
var snap_stats: Array = []
var bake_info: Dictionary = {}
var _ids: Dictionary = {}
var _links: Dictionary = {}
var _scale := 3.0
var _squash := 0.59375

static func make(city_data: Dictionary = {}) -> LevelNav:
	var n := LevelNav.new()
	n.data = city_data if city_data.has("levels") else LevelRegistry.shipped_graph()
	n._scale = float(n.data.get("scale", 3.0))
	n._squash = float(n.data.get("squash", Iso.squash()))
	n._bake()
	return n

func ground_of(sx: float, sy: float) -> Vector2:
	return Vector2(sx * _scale, sy * _scale / _squash)

func _ground(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y / _squash)

func _polygon(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(_ground(p))
	return out

func _walkable(level: Dictionary, p: Vector2) -> bool:
	var inside := false
	for poly in level.polygons:
		if Geometry2D.is_point_in_polygon(p, poly):
			inside = true
			break
	if not inside:
		return false
	for poly in level.holes:
		if Geometry2D.is_point_in_polygon(p, poly):
			return false
	return true

func _centre(level: Dictionary, c: Vector2i) -> Vector2:
	return (level.org as Vector2) + (Vector2(c) + Vector2(0.5, 0.5)) * CELL

func _cell(level: Dictionary, p: Vector2) -> Vector2i:
	return Vector2i(((p - (level.org as Vector2)) / CELL).floor())

func _nearest(level: Dictionary, p: Vector2) -> Vector2i:
	var grid: AStarGrid2D = level.grid
	var cell := _cell(level, p)
	var best := cell
	var distance := INF
	for radius in range(0, 9):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var c := cell + Vector2i(x, y)
				if not grid.is_in_boundsv(c) or grid.is_point_solid(c):
					continue
				if level.has("main") and not (level.main as Dictionary).has(c):
					continue
				var d := _centre(level, c).distance_squared_to(p)
				if d < distance:
					distance = d
					best = c
		if distance < INF:
			break
	if distance == INF:
		for c in LuaData.dict(level.get("main", {})):
			var d := _centre(level, c).distance_squared_to(p)
			if d < distance:
				distance = d
				best = c
	snap_stats.append(sqrt(distance))
	return best

func snap(point: Vector2, index: int) -> Dictionary:
	if index < 0 or index >= levels.size():
		return {"ok": false}
	var level: Dictionary = levels[index]
	var cell := _nearest(level, point)
	var grid: AStarGrid2D = level.grid
	if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
		return {"ok": false}
	var pos := _centre(level, cell)
	return {"ok": true, "pos": pos, "distance": point.distance_to(pos)}

func _main_component(grid: AStarGrid2D) -> Dictionary:
	var visited := {}
	var largest := {}
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x, y)
			if grid.is_point_solid(cell) or visited.has(cell):
				continue
			var component := {cell: true}
			var pending: Array[Vector2i] = [cell]
			visited[cell] = true
			while not pending.is_empty():
				var current: Vector2i = pending.pop_back()
				for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = current + step
					if grid.is_in_boundsv(next) and not grid.is_point_solid(next) and not visited.has(next):
						visited[next] = true
						component[next] = true
						pending.append(next)
			if component.size() > largest.size():
				largest = component
	return largest

func _local(a: Vector2, b: Vector2, index: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if index < 0 or index >= levels.size():
		return out
	var level: Dictionary = levels[index]
	var ca := _nearest(level, a)
	var cb := _nearest(level, b)
	var grid: AStarGrid2D = level.grid
	if not grid.is_in_boundsv(ca) or not grid.is_in_boundsv(cb) or grid.is_point_solid(ca) or grid.is_point_solid(cb):
		return out
	var path := grid.get_id_path(ca, cb)
	if path.is_empty():
		return out
	for c in path:
		out.append(_centre(level, c))
	return out

func _length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length

func _add_gate(pos: Vector2, level: int, kind: String, id: String) -> int:
	var index := gates.size()
	gates.append({"pos": pos, "level": level, "kind": kind, "id": id})
	gate_ids[id] = index
	return index

func _connect(a: int, b: int, points: PackedVector2Array, kind: String) -> void:
	if points.is_empty():
		return
	var length := _length(points)
	_links[Vector2i(a, b)] = {"polyline": points, "length": length, "kind": kind, "level": gates[a].level, "to_level": gates[b].level}
	var reverse := points.duplicate()
	reverse.reverse()
	_links[Vector2i(b, a)] = {"polyline": reverse, "length": length, "kind": kind, "level": gates[b].level, "to_level": gates[a].level}

func _bake() -> void:
	var start := Time.get_ticks_usec()
	var solid := 0
	var total := 0
	var prepared := _prepared_cells()
	for authored in LuaData.arr(data.get("levels", [])):
		var polygons: Array = []
		var holes: Array = []
		for p in authored.polygons:
			polygons.append(_polygon(p))
		for p in authored.holes:
			holes.append(_polygon(p))
		for keepout in authored.keepouts:
			holes.append(_polygon(keepout.polygon))
		var centre := _ground(authored.centre)
		var extent := Vector2(float(authored.rx), float(authored.ry) / _squash) + Vector2.ONE * CELL * 3
		var org := centre - extent
		var size := Vector2i((extent * 2 / CELL).ceil())
		var grid := AStarGrid2D.new()
		grid.region = Rect2i(Vector2i.ZERO, size)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()
		var level := {"id": str(authored.id), "c": centre, "org": org, "grid": grid, "polygons": polygons, "holes": holes, "n": size}
		_ids[str(authored.id)] = levels.size()
		levels.append(level)
		var rows: Array = prepared.get(str(authored.id), [])
		var cached := rows.size() == size.y and rows.all(func(row): return str(row).length() == size.x)
		var main := {}
		for y in size.y:
			for x in size.x:
				var p := _centre(level, Vector2i(x, y))
				var free := true
				if cached:
					free = str(rows[y])[x] != "1"
					if str(rows[y])[x] == "m":
						main[Vector2i(x, y)] = true
				else:
					for offset in [Vector2.ZERO, Vector2(BODY, 0), Vector2(-BODY, 0), Vector2(0, BODY), Vector2(0, -BODY)]:
						if not _walkable(level, p + offset):
							free = false
							break
				grid.set_point_solid(Vector2i(x, y), not free)
				solid += int(not free)
				total += 1
		level["main"] = main if cached else _main_component(grid)
	for bridge in LuaData.arr(data.get("bridges", [])):
		var la := int(_ids.get(str(bridge.from), -1))
		var lb := int(_ids.get(str(bridge.to), -1))
		if la < 0 or lb < 0:
			continue
		var ga := _add_gate(_ground(bridge.gate_a), la, "bridge", str(bridge.id) + "_a")
		var gb := _add_gate(_ground(bridge.gate_b), lb, "bridge", str(bridge.id) + "_b")
		_connect(ga, gb, PackedVector2Array([gates[ga].pos, _ground(bridge.a), _ground(bridge.b), gates[gb].pos]), "bridge")
	for ladder in LuaData.arr(data.get("ladders", [])):
		var la := int(_ids.get(str(ladder.from), -1))
		var lb := int(_ids.get(str(ladder.to), -1))
		if la < 0 or lb < 0:
			continue
		var ga := _add_gate(_ground(ladder.bottom), la, "ladder", str(ladder.id) + "_bottom")
		var gb := _add_gate(_ground(ladder.top), lb, "ladder", str(ladder.id) + "_top")
		_connect(ga, gb, PackedVector2Array([gates[ga].pos, gates[gb].pos]), "ladder")
	for a in gates.size():
		for b in range(a + 1, gates.size()):
			if gates[a].level == gates[b].level:
				_connect(a, b, _local(gates[a].pos, gates[b].pos, int(gates[a].level)), "walk")
	bake_info = {"bake_ms": float(Time.get_ticks_usec() - start) / 1000.0, "solid": solid, "cells": total, "gates": gates.size(), "edges": _links.size() / 2, "baked_cells": not prepared.is_empty()}

func _prepared_cells() -> Dictionary:
	if not use_baked_cells or not FileAccess.file_exists(BAKED_CELLS) or not FileAccess.file_exists("res://scripts/towns/level_nav.gd"):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BAKED_CELLS))
	if not parsed is Dictionary or int(parsed.get("format", 0)) != 1:
		return {}
	if str(parsed.get("geometry", "")) != JSON.stringify(data, "", true).sha256_text() or str(parsed.get("algorithm", "")) != FileAccess.get_sha256("res://scripts/towns/level_nav.gd"):
		return {}
	var cells: Variant = parsed.get("levels", {})
	if not cells is Dictionary:
		return {}
	for rows in cells.values():
		if not rows is Array or not rows.all(func(row): return row is String and str(row).replace("0", "").replace("1", "").replace("m", "") == ""):
			return {}
	return cells

func route(pa: Vector2, la: int, pb: Vector2, lb: int) -> Dictionary:
	var empty := {"polyline": PackedVector2Array(), "length": 0.0, "hops": 0, "segments": []}
	if la < 0 or lb < 0 or la >= levels.size() or lb >= levels.size():
		return empty
	if la == lb:
		var path := _local(pa, pb, la)
		return {"polyline": path, "length": _length(path), "hops": 0, "segments": [{"polyline": path, "level": la, "to_level": lb, "kind": "walk"}]}
	# Dijkstra uses actual local walking lengths, including diagonal steps.
	var edges := _links.duplicate()
	var start_id := gates.size()
	var end_id := start_id + 1
	for id in gates.size():
		if gates[id].level == la:
			var p := _local(pa, gates[id].pos, la)
			if not p.is_empty():
				edges[Vector2i(start_id, id)] = {"polyline": p, "length": _length(p), "level": la, "to_level": la, "kind": "walk"}
		if gates[id].level == lb:
			var p := _local(gates[id].pos, pb, lb)
			if not p.is_empty():
				edges[Vector2i(id, end_id)] = {"polyline": p, "length": _length(p), "level": lb, "to_level": lb, "kind": "walk"}
	var distances := {start_id: 0.0}
	var parents := {}
	var pending := [start_id]
	while not pending.is_empty():
		pending.sort_custom(func(a: int, b: int) -> bool: return float(distances[a]) < float(distances[b]))
		var current := int(pending.pop_front())
		if current == end_id:
			break
		for edge in edges:
			if edge.x != current:
				continue
			var cost := float(distances[current]) + float(edges[edge].length)
			if cost < float(distances.get(edge.y, INF)):
				distances[edge.y] = cost
				parents[edge.y] = current
				if not edge.y in pending:
					pending.append(edge.y)
	if not parents.has(end_id):
		return empty
	var chain: Array = []
	var at := end_id
	while at != start_id:
		var before := int(parents[at])
		chain.push_front(edges[Vector2i(before, at)])
		at = before
	var out := PackedVector2Array()
	var hops := 0
	for segment in chain:
		hops += int(segment.kind != "walk")
		for point in segment.polyline:
			if out.is_empty() or out[-1].distance_to(point) > 0.01:
				out.append(point)
	return {"polyline": out, "length": float(distances[end_id]), "hops": hops, "segments": chain}
