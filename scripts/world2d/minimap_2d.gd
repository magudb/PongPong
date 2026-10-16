class_name Minimap2D
extends Control
## Terrain is a cached pixel map. Only the dot layer updates at 10 Hz.
const C := preload("res://scripts/ui/theme/tt_colors.gd")
var area: IsoArea
var fog := {}
var fully_revealed := false
var _last_cell := Vector2i(-999,-999)
var _image: Image
var _texture: ImageTexture
var _view: TextureRect
var _dots: Array[Dictionary] = []
var _timer: Timer
var _overlay: Control
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_view = TextureRect.new()
	_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_view.mouse_filter = MOUSE_FILTER_IGNORE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://shaders/circle_mask.gdshader")
	_view.material = mask
	add_child(_view)
	move_child(_view,0)
	_overlay = DotLayer.new()
	_overlay.owner_map = self
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_overlay)
	_timer = Timer.new()
	_timer.wait_time = .1
	_timer.timeout.connect(update_map)
	add_child(_timer)
	_timer.start()
func set_area(value: IsoArea) -> void:
	area = value
	fog.clear()
	_dots.clear()
	_last_cell = Vector2i(-999,-999)
	fully_revealed = false
	if not is_instance_valid(area) or area.map.width <= 0 or area.map.height <= 0:
		area = null
		if _view != null: _view.texture = null
		if _overlay != null: _overlay.queue_redraw()
		return
	var floors := DungeonFloors.inst()
	fully_revealed = floors != null and floors.is_revealed(DungeonFloors.floor_of(area))
	_image = Image.create(area.map.width,area.map.height,false,Image.FORMAT_RGBA8)
	_image.fill(C.NIGHT)
	_texture = ImageTexture.create_from_image(_image)
	_view.texture = _texture
	update_map(true)
func reveal_all() -> void:
	fully_revealed = true
	update_map(true)
func is_seen(cell: Vector2i) -> bool:
	return fully_revealed or fog.has(cell)
func _reveal(cell: Vector2i) -> void:
	for y in range(maxi(0,cell.y-14),mini(area.map.height,cell.y+15)):
		for x in range(maxi(0,cell.x-14),mini(area.map.width,cell.x+15)):
			var c := Vector2i(x,y)
			if Vector2(c-cell).length_squared() <= 196 and not fog.has(c):
				fog[c] = true
				if not fully_revealed: _image.set_pixel(x,y,_color_at(c))
	_texture.update(_image)
func _color_at(cell: Vector2i) -> Color:
	match area.map.ground_at(cell):
		"#","W": return C.NIGHT_TRACK
		"~": return Color("3a5c6a")
		"p": return Color("6b825c")
		"c","x": return Color("58617c")
	return C.SHADOW_MOSS
func _paint() -> void:
	for y in area.map.height:
		for x in area.map.width:
			var cell := Vector2i(x,y)
			var color := C.NIGHT
			if is_seen(cell): color = _color_at(cell)
			_image.set_pixel(x,y,color)
	_texture.update(_image)
func update_map(force := false) -> void:
	if not is_instance_valid(area) or (not force and not is_visible_in_tree()): return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null: return
	var cell := area.global_to_cell(player.global_position)
	if force or cell != _last_cell:
		_reveal(cell)
		if fully_revealed and force: _paint()
		_last_cell = cell
	_dots.clear()
	for marker in area.markers:
		var kind := str(marker.get("type",""))
		var at: Vector2i = marker.cell
		var params: Dictionary = marker.params
		var color := Color.TRANSPARENT
		if kind == "enemy" and int(params.get("boss",0)) == 1:
			_dot(at,C.CHALK,5,true)
			continue
		var seen := is_seen(at)
		if kind == "chest":
			if LootMarkers.is_done(area,at,LootMarkers.context_for(area,at)): continue
			if not seen and Vector2(at-cell).length() > DungeonRun.chest_sense_cells(): continue
			var node: Node = marker.get("node")
			if node != null and bool(node.get("is_open")): continue
			color = C.GOLD
		elif seen and kind == "runestone": color = C.GLOWSHROOM
		elif seen and kind == "warp": color = C.OWL_EYE if DungeonFloors.floor_of_id(params.get("to","")) > DungeonFloors.floor_of(area) else C.SKY
		elif seen and kind == "spawn": color = C.SKY
		if color.a > 0: _dot(at,color,3)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Enemy2D or not enemy.is_awake() or enemy.state == Enemy2D.S.DEAD: continue
		var at := area.global_to_cell(enemy.global_position)
		if Vector2(at-cell).length_squared() <= 100: _dot(at,C.ROSE,2.5)
	_dot(cell,C.CHALK,4)
	_overlay.queue_redraw()
func _dot(cell: Vector2i, color: Color, radius: float, ring := false) -> void:
	var point := (Vector2(cell)+Vector2(.5,.5))/Vector2(area.map.width,area.map.height)*size
	if point.distance_to(size*.5) < size.x*.5-radius-3: _dots.append({"position":point,"color":color,"radius":radius,"ring":ring})
class DotLayer extends Control:
	var owner_map: Minimap2D
	func _draw() -> void:
		var center := size*.5
		draw_arc(center,size.x*.5-2,0,TAU,96,C.GOLD,3,true)
		for dot in owner_map._dots:
			if dot.ring: draw_arc(dot.position,dot.radius,0,TAU,20,dot.color,2,true)
			else: draw_circle(dot.position,dot.radius,dot.color)
