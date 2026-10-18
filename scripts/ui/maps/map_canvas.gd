extends Control
## Fits the actual screen-plane geometry, so paths and player position agree with the world.
const C := preload("res://scripts/ui/theme/tt_colors.gd")
var snapshot: Dictionary = {}
var selected := -1
var _bounds := Rect2()
var _scale := 1.0
var _offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	# The only gold drawn here marks the place selected in the keyboard/mouse list.
	set_meta("tt_gold_ok", true)
	resized.connect(queue_redraw)

func show_map(value: Dictionary) -> void:
	snapshot = value
	selected = -1
	_bounds = Rect2(value.player, Vector2.ONE)
	for surface in value.surfaces:
		for point in surface.polygon: _bounds = _bounds.expand(point)
	for place in value.places: _bounds = _bounds.expand(place.position)
	queue_redraw()

func select(index: int) -> void:
	selected = index
	queue_redraw()

func _point(world: Vector2) -> Vector2:
	return (world - _bounds.position) * _scale + _offset

func _polygon(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points: out.append(_point(point))
	return out

func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel", "PanelSidebar"), Rect2(Vector2.ZERO, size))
	if snapshot.is_empty(): return
	var available := (size - Vector2(64, 64)).max(Vector2.ONE)
	_scale = minf(available.x / maxf(1, _bounds.size.x), available.y / maxf(1, _bounds.size.y))
	_offset = (size - _bounds.size * _scale) * 0.5
	for surface in snapshot.surfaces:
		draw_colored_polygon(_polygon(surface.polygon), surface.color)
	for path in snapshot.paths:
		draw_polyline(_polygon(path), C.LAVENDER, 4.0, true)
	var font := get_theme_font("font", "Display20")
	for index in snapshot.places.size():
		var place: Dictionary = snapshot.places[index]
		var point := _point(place.position)
		var active: bool = index == selected
		draw_circle(point, 12, C.INK)
		draw_circle(point, 10, C.GOLD if active else C.LAVENDER_PALE if place.kind == "exit" else C.ROSE_LIGHT)
		var number := str(index + 1)
		draw_string(font, point + Vector2(-font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, 4), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C.INK)
		if active: draw_arc(point, 16, 0, TAU, 32, C.GOLD, 3, true)
	var here := _point(snapshot.player)
	draw_circle(here, 10, C.INK)
	draw_colored_polygon(PackedVector2Array([here + Vector2(0, -8), here + Vector2(7, 0), here + Vector2(0, 8), here + Vector2(-7, 0)]), C.SKY)
