@tool
extends Control
## Row of ink-outlined hearts with half-heart support (dark-forest HUD, guide section 10).
## Value is counted in HALF hearts: 7 of 10 = three full hearts + one half.
## Full = rose #e58fa6, half = pale rose #f2c3cf (literal from the guide), empty = #4a4560. Never red.

const INK := Color("#2b2340")
const FULL := Color("#e58fa6")
const HALF := Color("#f2c3cf")
const EMPTY := Color("#4a4560")

@export var max_hearts: int = 5:
	set(v):
		max_hearts = maxi(1, v)
		_refresh()
@export var half_hearts: int = 7:
	set(v):
		half_hearts = clampi(v, 0, max_hearts * 2)
		queue_redraw()
@export var heart_size := Vector2(30, 28):
	set(v):
		heart_size = v
		_refresh()
@export var gap: float = 4.0:
	set(v):
		gap = v
		_refresh()

var _poly := PackedVector2Array()


func _ready() -> void:
	_refresh()


func set_health(current: float, maximum: float) -> void:
	## Convenience for 0..max health values (e.g. 70 / 100 -> 7 half hearts of 10).
	max_hearts = max_hearts
	half_hearts = int(round(clampf(current / maxf(maximum, 0.001), 0.0, 1.0) * max_hearts * 2.0))


func _refresh() -> void:
	custom_minimum_size = Vector2(max_hearts * heart_size.x + (max_hearts - 1) * gap, heart_size.y)
	_poly = _build_heart(heart_size)
	queue_redraw()


static func _build_heart(sz: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps:
		var t := TAU * float(i) / float(steps)
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x / 34.0 + 0.5, 0.5 - (y + 3.0) / 34.0 * 1.05))
	# fit into 0..1 box then scale (leave 1.5px for the stroke)
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for p in pts:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var span := max_p - min_p
	var inner := sz - Vector2(3, 3)
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2.ONE * 1.5 + (p - min_p) / span * inner)
	return out


func _draw() -> void:
	if _poly.is_empty():
		_poly = _build_heart(heart_size)
	for i in max_hearts:
		var halves := half_hearts - i * 2
		var col := EMPTY
		if halves >= 2:
			col = FULL
		elif halves == 1:
			col = HALF
		var off := Vector2(i * (heart_size.x + gap), 0)
		var shifted := PackedVector2Array()
		for p in _poly:
			shifted.append(p + off)
		draw_colored_polygon(shifted, col)
		var closed := shifted.duplicate()
		closed.append(shifted[0])
		draw_polyline(closed, INK, 3.0, true)
