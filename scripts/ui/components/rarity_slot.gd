class_name RaritySlot
extends Control
## An inventory / wardrobe / furniture cell with the rarity treatment of the style guide (addendum 2.1):
##   fill + 3 px ring in the rarity colour (the guide's own "Sjælden" slot is exactly this), pips (shape + count) bottom-left,
##   count bottom-right, optionally the rarity WORD under the tile (colour is never the only cue).
##   `selected` = the GOLD double ring (3 px gold + 2 px ink) and it REPLACES the rarity ring: gold means focus, never rarity.
##   `unknown` = Samlerbog silhouette (dashed border, the icon as a dark shape), `empty` = the guide's empty slot.
##   An item whose icon file does not exist yet shows the same coloured initial badge as TTItemIcon (a missing picture never
##   leaves an empty tile; plan()["badge"]); an `unknown` tile never shows it (it must not give the item away).
## The five rarities are the five states of the tile; legendary is the only dark tile (night 2f3654, Himmel ring a9d3e0, gold
## pips f2c14e) and its icon is the `<id>_night.webp` rim variant, or - when that file is missing - drawn on a pale disc of
## radius 0.60 x the icon edge (see TTItemIcon). Colours come from Rarity.ui(): there is no colour literal for a rarity here.
## The control is slot_size + 2 * PAD so the rings may be drawn outside the cell without clipping.
##
## `plan()` is the pure description of what is drawn (tests assert on it; the headless renderer cannot be sampled).

const INK := Color("#2b2340")
const GOLD := Color("#e3c372")
const EMPTY := Color("#ecdcb4")
const PAD := 8.0
const WORD_HEIGHT := 22.0
const TILE_RADIUS := 10
const COUNT_FONT := preload("res://assets/fonts/Caprasimo-Regular.ttf")
const WORD_FONT := preload("res://assets/fonts/AlegreyaSans-ExtraBold.ttf")
const BoxStyle = preload("res://scripts/ui/theme/tt_box_style.gd")

## The icon (and its `_night` variant) depends on the rarity, so assigning `rarity` re-resolves it: the order in which `item_id`
## and `rarity` are assigned does not matter.
@export var rarity: StringName = &"normal":
	set(v):
		rarity = v
		_reload_icon()
## an item id: the icon is looked up through TTItemIcon (items / home / wardrobe directories, `_night` for legendary)
@export var item_id: StringName = &"":
	set(v):
		item_id = v
		_reload_icon()
## an explicit picture; wins over item_id (and then carries no night variant logic)
@export var icon: Texture2D:
	set(v):
		icon = v
		queue_redraw()
## the item's display name: only its first letter is used, for the badge of an item whose icon file does not exist (yet)
@export var display_name: String = "":
	set(v):
		display_name = v
		queue_redraw()
@export var count: int = 1:
	set(v):
		count = v
		queue_redraw()
@export var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
@export var empty: bool = false:
	set(v):
		empty = v
		queue_redraw()
@export var unknown: bool = false:
	set(v):
		unknown = v
		queue_redraw()
@export var slot_size: float = 66.0:
	set(v):
		slot_size = v
		_fit()
## draw the rarity word (RARITY_<ID>, translated) under the tile
@export var show_word: bool = false:
	set(v):
		show_word = v
		_fit()
var ui_override: Dictionary = {}

var _item_tex: Texture2D
var _night_file: bool = false
var _icon_path: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _fit() -> void:
	custom_minimum_size = Vector2(slot_size + 2.0 * PAD, slot_size + 2.0 * PAD + (WORD_HEIGHT if show_word else 0.0))
	queue_redraw()


func _reload_icon() -> void:
	if item_id == &"":
		_item_tex = null
		_night_file = false
		_icon_path = ""
	else:
		var e := TTItemIcon.load_icon(item_id, rarity)
		_item_tex = e["tex"]
		_night_file = bool(e["night"])
		_icon_path = str(e["path"])
	queue_redraw()


## The file the item picture comes from right now ("" = none found: the badge is drawn). Follows `item_id` AND `rarity`.
func icon_path() -> String:
	return _icon_path


# ---------------------------------------------------------------- the pure draw description

## What the tile looks like for these inputs: {state: "empty"|"unknown"|"filled", fill, border, rings: [{color, width}],
## rarity_ring_shown, gold_ring, pips: {count, shape, color}, night, disc, badge, has_picture, count_color, word_color}.
## `has_picture`: an icon exists; `night_file`: the icon is the `_night` rim variant; `has_item`: the slot holds an item id
## (`badge` = a filled tile with an item but no picture: the initial badge of TTItemIcon is drawn instead of an empty tile).
static func plan(rarity_id: Variant, is_selected: bool, is_empty: bool, is_unknown: bool, has_picture: bool = false, night_file: bool = false, override: Dictionary = {}, has_item: bool = false) -> Dictionary:
	var ui: Dictionary = Rarity.ui(rarity_id)
	for k in override:
		ui[k] = override[k]
	var p := {
		"state": "filled", "fill": ui["fill"], "border": INK, "rings": [], "rarity_ring_shown": false, "gold_ring": false,
		"pips": {"count": 0, "shape": "none", "color": ui["pip"]}, "night": bool(ui["night"]), "disc": false,
		"badge": false, "has_picture": has_picture, "count_color": INK, "word_color": ui["label"],
	}
	if is_empty:
		p["state"] = "empty"
		p["fill"] = EMPTY
		p["night"] = false
		return p
	if is_unknown:
		p["state"] = "unknown"
		p["fill"] = EMPTY
		p["border"] = Color(INK.r, INK.g, INK.b, 0.45)
		p["night"] = false
		return p
	if is_selected:
		p["gold_ring"] = true
		p["rings"] = [{"color": GOLD, "width": 3}, {"color": INK, "width": 2}]
	elif bool(ui["has_ring"]) and int(ui["ring_w"]) > 0:
		p["rarity_ring_shown"] = true
		p["rings"] = [{"color": ui["ring"], "width": int(ui["ring_w"])}]
	p["pips"] = {"count": Rarity.pips(rarity_id), "shape": Rarity.shape(rarity_id), "color": ui["pip"]}
	p["disc"] = has_picture and bool(ui["night"]) and not night_file
	p["badge"] = has_item and not has_picture
	if bool(ui["night"]):
		p["count_color"] = ui["icon_rim"] if (ui["icon_rim"] as Color).a > 0.0 else Color("#e4eff5")
	return p


## The plan of this very slot.
func current_plan() -> Dictionary:
	return plan(rarity, selected, empty, unknown, _picture() != null, _night_file if icon == null else true, ui_override, item_id != &"")


## Text of the rarity word under/next to the tile ("Sjælden").
func word_text() -> String:
	return tr(Rarity.label_key(rarity))


func _picture() -> Texture2D:
	return icon if icon != null else _item_tex


# ---------------------------------------------------------------- drawing

func _box(fill: Color, border: Color, bw: int, radius: int, draw_center := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.draw_center = draw_center
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


func _draw() -> void:
	var pl := current_plan()
	var cell := Rect2(PAD, PAD, slot_size, slot_size)
	var tex := _picture()
	match str(pl["state"]):
		"empty":
			draw_style_box(_box(EMPTY, INK, 2, TILE_RADIUS), cell)
			draw_line(cell.position + Vector2(5, 4), cell.position + Vector2(cell.size.x - 5, 4), Color(INK.r, INK.g, INK.b, 0.15), 3.0)
		"unknown":
			var dashed: StyleBox = BoxStyle.new()
			dashed.set("fill", EMPTY)
			dashed.set("border_color", pl["border"])
			dashed.set("border_width", 2.0)
			dashed.set("radius", float(TILE_RADIUS))
			dashed.set("dashed", true)
			draw_style_box(dashed, cell)
		_:
			var rings: Array = pl["rings"]
			if bool(pl["gold_ring"]):
				draw_style_box(_box(GOLD, GOLD, 3, 13, false), cell.grow(3))
				draw_style_box(_box(INK, INK, 2, 15, false), cell.grow(5))
			elif not rings.is_empty():
				var w := int(rings[0]["width"])
				draw_style_box(_box(rings[0]["color"], rings[0]["color"], w, 13, false), cell.grow(float(w)))
			draw_style_box(_box(pl["fill"], INK, 2, TILE_RADIUS), cell)
	if tex != null:
		var r := cell.grow(-8.0)
		if str(pl["state"]) == "unknown":
			draw_texture_rect(tex, r, false, Color(INK.r, INK.g, INK.b, 0.22))
		else:
			if bool(pl["disc"]):
				TTItemIcon.draw_night_disc(self, r, cell.grow(-2.0), float(TILE_RADIUS) - 2.0)
			draw_texture_rect(tex, r, false)
	elif bool(pl["badge"]):
		TTItemIcon.draw_badge(self, cell.grow(-8.0), item_id, display_name)
	if str(pl["state"]) == "filled":
		var pips: Dictionary = pl["pips"]
		var n := int(pips["count"])
		if n > 0:
			var psz: float = clampf(slot_size / 6.0, 8.0, 11.0)
			var step := psz + 3.0
			var room := cell.size.x - 12.0                       # the pips must stay INSIDE the tile, also at 4 pips in a 46 px slot
			if n * step > room:
				step = room / float(n)
				psz = minf(psz, step - 1.0)
			RarityPips.draw_row(self, str(pips["shape"]), n, cell.position + Vector2(6.0 + step * 0.5, cell.size.y - 9.0), step, psz, pips["color"])
		if count > 1:
			var txt := str(count)
			var w2 := COUNT_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(COUNT_FONT, cell.position + Vector2(cell.size.x - 5.0 - w2, cell.size.y - 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, pl["count_color"])
	if show_word and str(pl["state"]) == "filled":
		var word := word_text()
		var ww := WORD_FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(WORD_FONT, Vector2((size.x - ww) * 0.5, PAD * 2.0 + slot_size + 14.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, pl["word_color"])
