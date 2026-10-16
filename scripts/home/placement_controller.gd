extends Node2D
## Pure preview in the current room. The manager is the only mutation owner.
const C := preload("res://scripts/ui/theme/tt_colors.gd")
var cell := Vector2i.ZERO
var item := ""
var rot := 0
var valid := false
var _ghost: Node2D
var _key := ""
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 8
func update_preview(id: String, at: Vector2i, rotation: int) -> Dictionary:
	item = id
	cell = at
	rot = rotation
	var grid := FurnitureManager.ensure_grid()
	var check := grid.can_place(item,cell,rot) if item != "" else {"ok":false,"text_key":"INDRET_CHOOSE"}
	valid = bool(check.ok)
	var key := "%s:%s:%d:%s" % [item,cell,rot,valid]
	if key != _key:
		_key = key
		if is_instance_valid(_ghost):
			_ghost.queue_free()
			_ghost = null
		var room := get_parent().get_node_or_null("HomeRoom") as HomeRoom
		if item != "" and room != null and grid.items.has(item):
			_ghost = room.make_furniture_node(item,rot,true)
			_ghost.position = room.pivot_position(item,cell,rot,_ghost.get_meta("ysort"))
			if grid.items[item].layer == "tabletop" and check.has("host"):
				var host: Dictionary = grid.placements[check.host]
				_ghost.position.y -= float(grid.items[host.item_id].surface.height_m) * HomeData.PX_PER_M_V
			_ghost.modulate = Color(C.MOSS if valid else C.ROSE,0.65)
			add_child(_ghost)
	queue_redraw()
	return check
func _draw() -> void:
	var grid := FurnitureManager.ensure_grid()
	for c in grid.floor_cells:
		var points := PackedVector2Array()
		for offset in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5),Vector2(-.5,-.5)]:
			points.append(HomeData.cell_to_local(Vector2(c) + offset))
		draw_polyline(points,Color(C.GOLD,0.3),1.0,true)
	var cells: Array = grid.footprint_cells(item,cell,rot) if grid.items.has(item) else [cell]
	if cells.is_empty(): cells = [cell]
	for c in cells:
		var points := PackedVector2Array()
		for offset in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5),Vector2(-.5,-.5)]:
			points.append(HomeData.cell_to_local(Vector2(c) + offset))
		draw_colored_polygon(points,Color(C.MOSS if valid else C.ROSE,0.32))
		draw_polyline(points,C.MOSS if valid else C.ROSE,2.0,true)
