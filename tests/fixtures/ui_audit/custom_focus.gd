extends Control
## A custom focusable control (like a LadderRow made focusable by the home builder): it has no theme "focus" style, so it declares the style it paints
## with the meta `tt_focus_style` and draws it itself while it has focus. With draw_ring = false it declares the style but never paints it (the
## windowed ring_pixels check must report ring_missing).

@export var draw_ring := true
var ring_style: StyleBox


func _ready() -> void:
	custom_minimum_size = Vector2(300, 50)
	focus_mode = Control.FOCUS_ALL
	ring_style = get_theme_stylebox("focus", "Button")
	set_meta(&"tt_focus_style", ring_style)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#ecdcb4"))
	if has_focus() and draw_ring:
		draw_style_box(ring_style, Rect2(Vector2.ZERO, size))
