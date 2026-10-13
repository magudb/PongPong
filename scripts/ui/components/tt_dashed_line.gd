@tool
extends Control
## 2px dashed divider ("border-top: 2px dashed #cdb98f" above the quest rewards).

@export var color := Color("#cdb98f"):
	set(v):
		color = v
		queue_redraw()
@export var thickness := 2.0
@export var dash := 6.0
@export var gap := 4.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var x := 0.0
	var y := thickness * 0.5
	while x < size.x:
		draw_line(Vector2(x, y), Vector2(minf(x + dash, size.x), y), color, thickness)
		x += dash + gap
