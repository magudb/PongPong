extends Node2D
## Pure preview in the current room. The manager is the only mutation owner.
## Indretning calls update_preview() every frame; the placement is re-validated (can_place walks the room) and the ghost and the floor
## grid are redrawn only when the item, the cell, the rotation, the stock or the room's placements changed (UIC-06). The floor grid's
## outlines are cached per room.
const C := preload("res://scripts/ui/theme/tt_colors.gd")
var cell := Vector2i.ZERO
var item := ""
var rot := 0
var valid := false
var _ghost: Node2D
var _key := ""
## how many times the placement was re-validated (the tests read it)
var evaluations := 0
var _check: Dictionary = {}
var _check_key := []
var _floor_lines: Array[PackedVector2Array] = []
var _floor_key := []
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 8
func update_preview(id: String, at: Vector2i, rotation: int) -> Dictionary:
	var grid := FurnitureManager.ensure_grid()
	var check_key := [id,at,rotation,grid.get_instance_id(),grid.placements.hash(),grid.max_items,FurnitureManager.count_stock(id) if id != "" else 0]
	if check_key == _check_key:
		return _check
	_check_key = check_key
	evaluations += 1
	item = id
	cell = at
	rot = rotation
	var check := grid.can_place(item,cell,rot) if item != "" else {"ok":false,"text_key":"INDRET_CHOOSE"}
	if item != "" and FurnitureManager.count_stock(item) == 0:
		check = {"ok":false,"text_key":"FURNI_REJECT_UNKNOWN_ITEM"}
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
	_check = check
	queue_redraw()
	return check
func _draw() -> void:
	var grid := FurnitureManager.ensure_grid()
	var floor_key := [grid.get_instance_id(),grid.floor_cells.size()]
	if floor_key != _floor_key:
		_floor_key = floor_key
		_floor_lines.clear()
		for c in grid.floor_cells:
			var outline := PackedVector2Array()
			for offset in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5),Vector2(-.5,-.5)]:
				outline.append(HomeData.cell_to_local(Vector2(c) + offset))
			_floor_lines.append(outline)
	for outline in _floor_lines:
		draw_polyline(outline,Color(C.GOLD,0.3),1.0,true)
	var cells: Array = grid.footprint_cells(item,cell,rot) if grid.items.has(item) else [cell]
	if cells.is_empty(): cells = [cell]
	for c in cells:
		var points := PackedVector2Array()
		for offset in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5),Vector2(-.5,-.5)]:
			points.append(HomeData.cell_to_local(Vector2(c) + offset))
		draw_colored_polygon(points,Color(C.MOSS if valid else C.ROSE,0.32))
		draw_polyline(points,C.MOSS if valid else C.ROSE,2.0,true)
