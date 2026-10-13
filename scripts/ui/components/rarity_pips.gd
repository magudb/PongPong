class_name RarityPips
extends Control
## The non-colour rarity cue: `Rarity.pips(rarity)` small shapes in a row (rank - 1: none for normal), the SHAPE changes with
## the rarity (leaf, diamond, sparkle, star). Used in slots (bottom-left), detail cards, list rows and tooltips.
## Pure vector drawing: no font, no texture, sharp at any zoom. Colours come from Rarity.ui(): the pip colour of a rarity is its
## ring colour, legendary pips are gold (f2c14e) because they sit on the night tile.

const INK := Color("#2b2340")

@export var rarity: StringName = &"normal":
	set(v):
		rarity = v
		_refresh()
@export var pip_size: float = 11.0:
	set(v):
		pip_size = v
		_refresh()
@export var gap: float = 3.0:
	set(v):
		gap = v
		_refresh()
## set to override the pip colour (alpha > 0)
var colour_override: Color = Color(0, 0, 0, 0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Number of pips drawn for a rarity (rank - 1).
func pip_count() -> int:
	return Rarity.pips(rarity)


func pip_width() -> float:
	var n := pip_count()
	return n * pip_size + maxi(n - 1, 0) * gap


func _refresh() -> void:
	custom_minimum_size = Vector2(pip_width(), pip_size + 3.0 if pip_count() > 0 else 0.0)
	queue_redraw()


## Outline of one pip: "leaf" | "diamond" | "sparkle" | "star" centred on `c`, radius `r` ("none" -> empty).
static func polygon(shape: String, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"leaf":
			for i in 9:
				var t := float(i) / 8.0
				pts.append(c + Vector2(r * 0.66 * sin(PI * t), -r + 2.0 * r * t))
			for i in 9:
				var t := 1.0 - float(i) / 8.0
				pts.append(c + Vector2(-r * 0.66 * sin(PI * t), -r + 2.0 * r * t))
		"diamond":
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.92, 0), c + Vector2(0, r), c + Vector2(-r * 0.92, 0)])
		"sparkle":
			for i in 8:
				var a := -PI / 2.0 + i * PI / 4.0
				var rr := r if i % 2 == 0 else r * 0.46
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
		"star":
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				var rr := r if i % 2 == 0 else r * 0.52
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


## Draws `n` pips of `shape` in `col` onto any CanvasItem, the first one centred at `first_centre`, `step` apart (x).
static func draw_row(ci: CanvasItem, shape: String, n: int, first_centre: Vector2, step: float, pip_diameter: float, col: Color) -> void:
	for i in n:
		var poly := polygon(shape, first_centre + Vector2(step * i, 0.0), pip_diameter * 0.5)
		if poly.size() < 3:
			continue
		ci.draw_colored_polygon(poly, col)
		var closed := poly.duplicate()
		closed.append(poly[0])
		ci.draw_polyline(closed, INK, 1.2 if pip_diameter <= 12.0 else 1.6, true)


func _draw() -> void:
	var n := pip_count()
	if n == 0:
		return
	var col: Color = colour_override if colour_override.a > 0.0 else Rarity.ui(rarity)["pip"]
	draw_row(self, Rarity.shape(rarity), n, Vector2(pip_size * 0.5, size.y * 0.5), pip_size + gap, pip_size, col)
