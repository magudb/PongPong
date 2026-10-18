extends RefCounted
## A read-only view of the live floor and public destinations. No second map layout or save state.
const C := preload("res://scripts/ui/theme/tt_colors.gd")

static func capture(area: IsoArea, player: Node2D, fog: Minimap2D = null) -> Dictionary:
	var out := {"area_id": area.map.id, "title": area.map.title, "surfaces": [], "paths": [], "places": [], "player": player.global_position}
	var stage := LevelStage.of(area)
	if stage != null:
		for level in stage.registry.levels:
			for polygon in level.regions + level.pads:
				_surface(out, polygon, C.MOSS if level.kind == &"platform" else C.BARK)
			for polygon in level.holes:
				_surface(out, polygon, C.PARCHMENT_DARK)
		for ladder in stage.registry.ladders:
			out.paths.append(PackedVector2Array([ladder.bottom, ladder.top]))
		for climb in stage.registry.climb_zones:
			out.paths.append(PackedVector2Array([climb.a, climb.b]))
		for lift in stage.lifts:
			_place(out, lift.global_position, _area_name(lift.to_area), "exit")
	else:
		_grid(out, area, fog)
	for node in area.get_tree().get_nodes_in_group("warp"):
		if not node is Warp2D or not area.is_ancestor_of(node) or not node.armed or not node.is_visible_in_tree():
			continue
		if not _seen(area, node.global_position, fog):
			continue
		var label: String = node.name_key if node is Door2D else node.label_key
		if label.is_empty(): label = _area_name(node.to_area)
		_place(out, node.global_position, label, "exit")
	for node in area.get_tree().get_nodes_in_group("npc"):
		if node is Npc2D and area.is_ancestor_of(node) and node.is_visible_in_tree() and _seen(area, node.global_position, fog):
			_place(out, node.global_position, node.display_name_key, "person")
	for marker in area.markers:
		var node: Node = marker.get("node")
		if marker.type == "home" and node is Node2D:
			_place(out, node.global_position + Vector2(0, 18), "HOME_WORLD_TITLE", "exit")
		if node is Greenhouse2D and node.action == "door" and FarmEquipment.greenhouse_built():
			_place(out, node.global_position, "FARMSITE_GREENHOUSE", "exit")
	out.places.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.kind != b.kind: return a.kind == "exit"
		return TranslationServer.translate(a.label).naturalnocasecmp_to(TranslationServer.translate(b.label)) < 0)
	return out

static func _seen(area: IsoArea, point: Vector2, fog: Minimap2D) -> bool:
	return fog == null or fog.is_seen(area.global_to_cell(point))

static func _area_name(id: StringName) -> String:
	var map := WorldRoot2D.load_map(id)
	return map.title if map != null and not map.title.is_empty() else "MAP_EXIT"

static func _place(out: Dictionary, point: Vector2, label: String, kind: String) -> void:
	if label.is_empty(): return
	for old in out.places:
		if old.label == label and old.position.distance_squared_to(point) < 1.0: return
	out.places.append({"position": point, "label": label, "kind": kind})

static func _surface(out: Dictionary, polygon: PackedVector2Array, color: Color) -> void:
	if polygon.size() >= 3: out.surfaces.append({"polygon": polygon, "color": color})

static func _grid(out: Dictionary, area: IsoArea, fog: Minimap2D) -> void:
	if area.ground == null or area.ground.tile_set == null: return
	var half := Vector2(area.ground.tile_set.tile_size) * 0.5
	for cell in area.ground.get_used_cells():
		var center := area.ground.to_global(area.ground.map_to_local(cell))
		if not _seen(area, center, fog): continue
		var color := C.MOSS
		match area.map.ground_at(cell) if area.map.width > 0 else "p":
			"~": color = C.SKY
			"=", "p": color = C.BARK
			"W", "#": color = C.INK
			"c", "x": color = C.TEXT_FAINT
		var offsets := [Vector2(0, -half.y), Vector2(half.x, 0), Vector2(0, half.y), Vector2(-half.x, 0)] if area.projection == &"iso" else [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
		var polygon := PackedVector2Array()
		for offset in offsets: polygon.append(center + offset)
		_surface(out, polygon, color)
