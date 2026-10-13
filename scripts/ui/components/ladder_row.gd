class_name LadderRow
extends Control
## One step of the Husbyggeri "trappen" (addendum 2.6): number badge, name, state chip.
## States: current (you live here), done, next (can be built next: gold chip), locked (dashed, dimmed).
## The selected row gets the gold double ring (focus); nothing else on the screen is gold except the "next" chip.
## `title` and `chip` are DISPLAY strings: the owner passes tr(KEY) (and re-passes them on NOTIFICATION_TRANSLATION_CHANGED).

const INK := Color("#2b2340")
const GOLD := Color("#e3c372")
const MOSS := Color("#6b9a3e")
const CHALK := Color("#fbf5e6")
const PARCH_DARK := Color("#ecdcb4")
const MUTED := Color("#4c4058")
const BADGE_LOCKED := Color("#a3957f")
const F_NUM := preload("res://assets/fonts/Caprasimo-Regular.ttf")
const F_NAME := preload("res://assets/fonts/AlegreyaSans-ExtraBold.ttf")
const F_CHIP := preload("res://assets/fonts/AlegreyaSans-Bold.ttf")
const BoxStyle = preload("res://scripts/ui/theme/tt_box_style.gd")

const STATES: Array[StringName] = [&"current", &"done", &"next", &"locked"]

@export var number: int = 1:
	set(v):
		number = v
		queue_redraw()
@export var title: String = "":
	set(v):
		title = v
		queue_redraw()
@export var chip: String = "":
	set(v):
		chip = v
		queue_redraw()
@export var state: StringName = &"locked":
	set(v):
		state = v
		queue_redraw()
@export var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(300, 50)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pure description of the row (tests): badge colour, chip fill, whether the border is dashed, whether the gold ring is drawn.
static func plan(p_state: StringName, p_selected: bool) -> Dictionary:
	var locked := p_state == &"locked"
	var badge := MOSS if p_state == &"current" else (INK if p_state == &"done" else (GOLD if p_state == &"next" else BADGE_LOCKED))
	var chip_fill := MOSS if p_state == &"current" else (GOLD if p_state == &"next" else Color(0, 0, 0, 0))
	return {
		"fill": PARCH_DARK if locked else CHALK, "dashed": locked, "gold_ring": p_selected,
		"badge": badge, "badge_text": CHALK if p_state in [&"current", &"done"] else INK,
		"chip_fill": chip_fill, "title_color": MUTED if locked else INK,
	}


func _box(fill: Color, border: Color, bw: int, radius: int, center := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.draw_center = center
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


func _draw() -> void:
	var pl := plan(state, selected)
	var r := Rect2(6, 5, size.x - 12, size.y - 10)
	if bool(pl["gold_ring"]):
		draw_style_box(_box(GOLD, GOLD, 3, 13, false), r.grow(3))
		draw_style_box(_box(INK, INK, 2, 15, false), r.grow(5))
	if bool(pl["dashed"]):
		var dashed: StyleBox = BoxStyle.new()
		dashed.set("fill", pl["fill"])
		dashed.set("border_color", Color(INK.r, INK.g, INK.b, 0.4))
		dashed.set("border_width", 2.0)
		dashed.set("radius", 10.0)
		dashed.set("dashed", true)
		draw_style_box(dashed, r)
	else:
		draw_style_box(_box(pl["fill"], INK, 2, 10), r)
	var c := r.position + Vector2(24, r.size.y * 0.5)
	draw_circle(c, 15.0, pl["badge"])
	draw_arc(c, 15.0, 0, TAU, 32, INK, 2.0, true)
	var ns := str(number)
	var w := F_NUM.get_string_size(ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(F_NUM, c + Vector2(-w * 0.5, 7.0), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, pl["badge_text"])
	draw_string(F_NAME, Vector2(r.position.x + 50, r.position.y + r.size.y * 0.5 + 7.0), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 150, 19, pl["title_color"])
	if chip != "":
		var cw := F_CHIP.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var cr := Rect2(r.end.x - cw - 22, r.position.y + 8, cw + 14, r.size.y - 16)
		var cfill: Color = pl["chip_fill"]
		if cfill.a > 0:
			draw_style_box(_box(cfill, INK, 2, 8), cr)
		draw_string(F_CHIP, cr.position + Vector2(7, cr.size.y * 0.5 + 5), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CHALK if state == &"current" else (INK if state == &"next" else MUTED))
