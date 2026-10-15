class_name Dust2D
extends Node2D
## Tiny roll/landing dust puff (soft circles, squashed to the ground plane).

var t: float = 0.0


func _ready() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "t", 1.0, 0.45)
	tw.tween_callback(queue_free)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.squash()))
	for i in 5:
		var a: float = float(i) * TAU / 5.0 + 0.4
		var p: Vector2 = Vector2(cos(a), sin(a)) * (10.0 + 34.0 * t) * Iso.S
		draw_circle(p, (9.0 + 9.0 * t) * Iso.S, Color(0.93, 0.88, 0.78, 0.55 * (1.0 - t)))
