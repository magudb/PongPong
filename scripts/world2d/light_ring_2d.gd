class_name LightRing2D
extends Node2D
## Expanding fairy-light ring (teal, "svampelys") drawn on the floor in ground space.

var radius: float = 300.0 * Iso.S
var t: float = 0.0


func setup(p_radius: float) -> void:
	radius = p_radius


func _ready() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "t", 1.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(queue_free)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.squash()))
	var a: float = 1.0 - t
	draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 64, Color("6fd6c4", 0.28 * a), 30.0 * Iso.S, true)
	draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 64, Color("e6f5f1", 0.9 * a), 5.0 * Iso.S, true)
