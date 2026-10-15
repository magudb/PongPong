class_name Slash2D
extends Node2D
## Crescent swing effect drawn in GROUND space (squashed vertically by Iso.squash) with anti-aliased arcs.

var tint := Color("fbf5e6")
var dir_g: Vector2 = Vector2.RIGHT
var radius: float = 110.0 * Iso.S
var half_angle: float = 1.0
var duration: float = 0.28
var progress: float = 0.0


func setup(p_dir: Vector2, p_radius: float, p_half: float, p_duration: float) -> void:
	dir_g = p_dir
	radius = p_radius
	half_angle = p_half
	duration = p_duration


func _ready() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "progress", 1.0, duration)
	tw.tween_callback(queue_free)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.squash()))
	var base: float = dir_g.angle()
	# the crescent sweeps from one side to the other, then fades
	var sweep: float = clampf(progress * 1.6, 0.0, 1.0)
	var a0: float = base - half_angle
	var a1: float = a0 + half_angle * 2.0 * sweep
	var fade: float = 1.0 - smoothstep(0.55, 1.0, progress)
	var r: float = radius * (0.72 + 0.28 * sweep)
	draw_arc(Vector2.ZERO, r, a0, a1, 28, Color(tint, 0.30 * fade), 22.0 * Iso.S, true)
	draw_arc(Vector2.ZERO, r, a0, a1, 28, Color(tint, 0.85 * fade), 9.0 * Iso.S, true)
	draw_arc(Vector2.ZERO, r + 3.0 * Iso.S, a0, a1, 28, Color("e3c372", 0.9 * fade), 3.0 * Iso.S, true)
