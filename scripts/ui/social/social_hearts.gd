class_name SocialHearts
extends Control
## The FRIENDSHIP heart glyph (package S-ui-core): a heart with a small green sprout on top, so it can never be mistaken for the five health hearts of the HUD
## (TTHearts, plain rose hearts). Counted in HALF hearts like TTHearts (7.5 hearts = 15). Colours: full = ROSE, half = ROSE_LIGHT (left half full), empty = the
## track colour of the parchment (DISABLED_BG) on light panels or HEART_EMPTY (4a4560) on dark ones; ink outline 2 px; the sprout is MOSS with an ink outline
## and is drawn on every heart, also empty ones (the glyph stays recognisable, colour is never the only cue: the sprout is the shape cue).
## A `stage` ring is NOT drawn here: stage names are text. Gold is never used (gold = focus).

const C := preload("res://scripts/ui/theme/tt_colors.gd")
## room above the heart for the sprout
const HEADROOM := 9.0

@export var max_hearts: int = 10:
	set(v):
		max_hearts = maxi(1, v)
		_refresh()
@export var half_hearts: int = 0:
	set(v):
		half_hearts = clampi(v, 0, max_hearts * 2)
		queue_redraw()
@export var heart_size := Vector2(26, 24):
	set(v):
		heart_size = v
		_refresh()
@export var gap: float = 3.0:
	set(v):
		gap = v
		_refresh()
@export var on_dark: bool = false

var _poly := PackedVector2Array()
var _leaf := PackedVector2Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	custom_minimum_size = Vector2(max_hearts * heart_size.x + (max_hearts - 1) * gap, heart_size.y + HEADROOM)
	_poly = _heart(heart_size)
	_leaf = _sprout(heart_size)
	queue_redraw()


static func _heart(sz: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps:
		var t := TAU * float(i) / float(steps)
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, -y))
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	var span := mx - mn
	var inner := sz - Vector2(3, 3)
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(1.5, 1.5 + HEADROOM) + (p - mn) / span * inner)
	return out


## a small leaf standing up from the cleft of the heart (stem + blade tilted to the right), drawn ABOVE the heart outline
static func _sprout(sz: Vector2) -> PackedVector2Array:
	var base := Vector2(sz.x * 0.50, HEADROOM + sz.y * 0.16)          # the cleft
	var out := PackedVector2Array()
	var w := maxf(sz.x * 0.19, 3.5)
	var h := HEADROOM + 1.0
	var n := 12
	for i in n:
		var t := PI * float(i) / float(n - 1)
		out.append(base + Vector2(sin(t) * w, -cos(t) * h * 0.5 - h * 0.5).rotated(0.55))
	for i in n:
		var t2 := PI * float(n - 1 - i) / float(n - 1)
		out.append(base + Vector2(-sin(t2) * w * 0.15, -cos(t2) * h * 0.5 - h * 0.5).rotated(0.55))
	return out


func plan() -> Array[Dictionary]:
	return describe(max_hearts, half_hearts)

static func describe(count: int, halves: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in count:
		out.append({"fill": "full" if halves - i * 2 >= 2 else ("half_left" if halves - i * 2 == 1 else "empty"), "sprout": true, "outline": 2, "gold": false})
	return out

func _draw() -> void:
	paint(self, Vector2.ZERO, max_hearts, half_hearts, heart_size, gap, on_dark)

static func paint(canvas: CanvasItem, origin: Vector2, max_hearts: int, half_hearts: int, heart_size: Vector2, gap: float, on_dark: bool = false) -> void:
	var _poly := _heart(heart_size)
	var _leaf := _sprout(heart_size)
	var empty_col: Color = C.HEART_EMPTY if on_dark else C.DISABLED_BG
	for i in max_hearts:
		var halves := half_hearts - i * 2
		var off := origin + Vector2(i * (heart_size.x + gap), 0)
		var shifted := PackedVector2Array()
		for p in _poly:
			shifted.append(p + off)
		canvas.draw_colored_polygon(shifted, empty_col)
		if halves >= 2:
			canvas.draw_colored_polygon(shifted, C.ROSE)
		elif halves == 1:
			canvas.draw_colored_polygon(shifted, C.ROSE_LIGHT)
			var left := PackedVector2Array([off + Vector2(0, 0), off + Vector2(heart_size.x * 0.5, 0), off + Vector2(heart_size.x * 0.5, heart_size.y + 8), off + Vector2(0, heart_size.y + 8)])
			for part in Geometry2D.intersect_polygons(shifted, left):
				canvas.draw_colored_polygon(part, C.ROSE)
		var closed := shifted.duplicate()
		closed.append(shifted[0])
		canvas.draw_polyline(closed, C.INK, 2.0, true)
		var leaf := PackedVector2Array()
		for p in _leaf:
			leaf.append(p + off)
		canvas.draw_colored_polygon(leaf, C.MOSS)
		var lc := leaf.duplicate()
		lc.append(leaf[0])
		canvas.draw_polyline(lc, C.INK, 1.5, true)
