class_name FarmView
extends Node
## One view per visited farm area; all persistent state belongs to FarmGrid.
var grid: FarmGrid
var area: IsoArea
var _crops: Dictionary = {}

func setup(model: FarmGrid, target: IsoArea) -> void:
	grid = model
	area = target
	grid.plot_changed.connect(refresh_cell)
	refresh_all()

func _exit_tree() -> void:
	if is_instance_valid(grid) and grid.plot_changed.is_connected(refresh_cell):
		grid.plot_changed.disconnect(refresh_cell)

func _enter_tree() -> void:
	if is_instance_valid(grid) and not grid.plot_changed.is_connected(refresh_cell):
		grid.plot_changed.connect(refresh_cell)
		refresh_all()

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	for spr in _crops.values():
		if is_instance_valid(spr):
			spr.queue_free()
	_crops.clear()

func refresh_all() -> void:
	if area.map.id != grid.map.id:
		return
	for cell in grid.farmable_cells():
		refresh_cell(cell)

func refresh_cell(cell: Vector2i) -> void:
	if not is_instance_valid(area) or area.map.id != grid.map.id or not grid.can_till(cell):
		return
	area.farmable[cell] = true
	var p := grid.get_plot(cell)
	var terrain: StringName = &"field_grass" if p == null or p.state == FarmGrid.State.EMPTY else (&"soil_watered" if p.watered else &"soil_tilled")
	area.set_terrain(cell, terrain)
	var stage := grid.visual_stage(cell)
	if stage < 0:
		if _crops.has(cell):
			(_crops[cell] as Node).queue_free()
			_crops.erase(cell)
		return
	var art := ArtCatalog.prop(StringName("crop_%s_%d" % [p.crop_id, stage]))
	var spr: Sprite2D = _crops.get(cell)
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "Crop_%d_%d" % [cell.x, cell.y]
		spr.centered = false
		area.objects.add_child(spr)
		_crops[cell] = spr
		spr.position = area.objects.to_local(area.cell_to_global(cell))
	spr.texture = art.texture
	spr.offset = -art.pivot
	# Seasonal wilt keeps the approved painted silhouette and brushwork.
	spr.modulate = Color("806548") if p.state == FarmGrid.State.WITHERED else Color.WHITE
	# Reuse the approved painted glow mask; no extra dynamic lights per crop.
	var glow: Sprite2D = spr.get_node_or_null("Glow")
	var glow_art: Dictionary = art.get("glow", {}) if stage == 3 and p.crop_id == &"moonflower" else {}
	if not glow_art.is_empty():
		if glow == null:
			glow = Sprite2D.new()
			glow.name = "Glow"
			glow.material = CanvasItemMaterial.new()
			(glow.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			spr.add_child(glow)
		glow.texture = glow_art.texture
		glow.position = glow_art.center - art.pivot
		glow.modulate = glow_art.color
		glow.visible = true
	elif glow != null:
		glow.visible = false
