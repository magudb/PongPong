class_name TTItemIcon
extends Control
## Item picture slot. The picture is found through the ONE ordered lookup of the art catalog (contract 6.2, DF8):
##     res://assets/icons/items/<id>.webp   (ordinary items, tools, seeds, materials of the base game)
##     res://assets/icons/home/<id>.webp    (furniture, building materials, blueprints)
##     res://assets/icons/wardrobe/<id>.webp (garments)
## (png and svg are accepted as well, in that order, per directory). Until real art exists it draws a coloured badge with
## the item's initial so a missing icon never looks broken.
##
## Rarity: a LEGENDARY tile is the night tile (2f3654) and the ink outline of an icon is 1.25:1 on it (RV-A2), so a legendary
## piece shows its sibling `<id>_night.webp` (4 px pale die-cut rim e4eff5, ink 12.4:1). When that file is missing the icon is
## drawn on a pale disc of radius 0.60 x the icon edge (e4eff5, alpha .92, clipped to the tile): 0.60 covers every outline
## pixel of all 130 furniture icons (0.55 would leave 10 of them partly uncovered).
##
## resolve() / resolve_path() are PURE (directory list and "does this file exist" predicate are injectable), so the lookup is
## tested with fake directories (ui_foundation.item_icon_three_dirs_and_night) without depending on the art catalog (P04).
## Mode LABEL reproduces the guide mock exactly (tiny lowercase mono name).

enum Mode { BADGE, LABEL }

## The three icon directories in lookup order (the same order as ArtCatalog.icon, plan DF8).
const DIRS: Array[String] = ["res://assets/icons/items/", "res://assets/icons/home/", "res://assets/icons/wardrobe/"]
const EXTS: Array[String] = ["webp", "png", "svg"]
const NIGHT_SUFFIX := "_night"
## pale disc behind a legendary icon without a `_night` file
const NIGHT_DISC_RADIUS := 0.60
const NIGHT_DISC_ALPHA := 0.92
const NIGHT_DISC_COLOR := Color("#e4eff5")
const BADGES: Array[Color] = [
	Color("#cde0a6"), Color("#f0d49a"), Color("#e2d8f4"), Color("#cfe6f2"),
	Color("#e7b7c6"), Color("#b9c3e3"), Color("#d4e4b4"), Color("#b8b2a8"),
]
const INK := Color("#2b2340")
const MONO := preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const DISPLAY := preload("res://assets/fonts/Caprasimo-Regular.ttf")

## "id|rarity" -> {tex: Texture2D or null, path: String, night: bool}
static var _cache: Dictionary = {}

@export var item_id: StringName = &"":
	set(v):
		item_id = v
		_reload()
@export var rarity: StringName = &"normal":
	set(v):
		rarity = v
		_reload()
@export var display_name: String = "":
	set(v):
		display_name = v
		queue_redraw()
## true (default): a missing picture with no `display_name` shows the item id as its text (the id is the only name a bare icon
## has). false: the id is never shown as text - the control draws the picture when there is one and NOTHING otherwise
## (ability_slot: the id is the English 'slash', the player-facing word is ABILITY_<ID> in forest.csv).
@export var id_fallback: bool = true:
	set(v):
		id_fallback = v
		queue_redraw()
@export var mode: Mode = Mode.BADGE:
	set(v):
		mode = v
		queue_redraw()
## corner radius and ink border of the tile this icon sits on (the pale disc is clipped to it)
@export var tile_radius: float = 10.0
@export var tile_border: float = 2.0

var _tex: Texture2D
var _night_file: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# ---------------------------------------------------------------- pure lookup

## Is the dark (night) variant used for this rarity? True for the rarities whose tile is dark (legendary).
static func wants_night(rarity_id: Variant) -> bool:
	return bool(Rarity.ui(rarity_id).get("night", false))


## {path, dir, night, base_path}: the first existing `<dir><id>.<ext>` over `dirs` (in order, then EXTS); for a rarity with a
## night tile the sibling `<id>_night.<ext>` of that file when it exists (`night` = true), else the plain icon (`night` = false:
## the caller draws the pale disc). `path` is "" when no directory has the icon. `exists` is Callable(path) -> bool;
## the default is ResourceLoader.exists (imported files are remapped in an export, a plain file test would fail there).
static func resolve(id: Variant, rarity_id: Variant = &"normal", dirs: Array = DIRS, exists: Callable = Callable()) -> Dictionary:
	var out := {"path": "", "dir": "", "night": false, "base_path": ""}
	var sid := str(id)
	if sid == "" or not _is_plain_id(sid):
		return out
	for d in dirs:
		var dir := str(d)
		if not dir.ends_with("/"):
			dir += "/"
		for ext in EXTS:
			var base := "%s%s.%s" % [dir, sid, ext]
			if not _exists(base, exists):
				continue
			out["base_path"] = base
			out["dir"] = dir
			out["path"] = base
			if wants_night(rarity_id):
				var night := "%s%s%s.%s" % [dir, sid, NIGHT_SUFFIX, ext]
				if _exists(night, exists):
					out["path"] = night
					out["night"] = true
			return out
	return out


static func resolve_path(id: Variant, rarity_id: Variant = &"normal", dirs: Array = DIRS, exists: Callable = Callable()) -> String:
	return str(resolve(id, rarity_id, dirs, exists)["path"])


static func _exists(path: String, exists: Callable) -> bool:
	return bool(exists.call(path)) if exists.is_valid() else ResourceLoader.exists(path)


## ids become file names: lowercase ASCII, digits, underscores and dashes only (no path tricks).
static func _is_plain_id(sid: String) -> bool:
	for i in sid.length():
		var c := sid.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 45
		if not ok:
			return false
	return true


## Loads (and caches) the icon of an id: {tex, path, night}. tex is null when no directory has it.
static func load_icon(id: Variant, rarity_id: Variant = &"normal") -> Dictionary:
	var key := "%s|%s" % [str(id), str(Rarity.normalize(rarity_id))]
	if _cache.has(key):
		return _cache[key]
	var r := resolve(id, rarity_id)
	var tex: Texture2D = load(str(r["path"])) as Texture2D if str(r["path"]) != "" else null
	var entry := {"tex": tex, "path": r["path"], "night": r["night"]}
	_cache[key] = entry
	return entry


static func clear_cache() -> void:
	_cache.clear()


## The pale disc of a legendary icon without `_night` file, clipped to the rounded tile:
## {center, radius, polygons: Array[PackedVector2Array]} (radius = NIGHT_DISC_RADIUS x the icon edge). `tile` is the rect of
## the tile INSIDE its ink border; `icon_rect` the rect the icon is drawn in.
static func night_disc(icon_rect: Rect2, tile: Rect2, corner_radius: float) -> Dictionary:
	var c := icon_rect.get_center()
	var r := minf(icon_rect.size.x, icon_rect.size.y) * NIGHT_DISC_RADIUS
	var circle := PackedVector2Array()
	for i in 48:
		var a := TAU * float(i) / 48.0
		circle.append(c + Vector2(cos(a), sin(a)) * r)
	var clipped := Geometry2D.intersect_polygons(circle, rounded_rect_polygon(tile, corner_radius))
	var polys: Array[PackedVector2Array] = []
	for p in clipped:
		polys.append(p)
	return {"center": c, "radius": r, "polygons": polys}


static func rounded_rect_polygon(rect: Rect2, radius: float, steps: int = 8) -> PackedVector2Array:
	var rad := clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(rect.position.x + rad, rect.position.y + rad), PI],
		[Vector2(rect.end.x - rad, rect.position.y + rad), PI * 1.5],
		[Vector2(rect.end.x - rad, rect.end.y - rad), 0.0],
		[Vector2(rect.position.x + rad, rect.end.y - rad), PI * 0.5],
	]
	for cn in corners:
		for s in range(steps + 1):
			var a: float = cn[1] + (PI * 0.5) * float(s) / float(steps)
			pts.append(cn[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Draws the clipped pale disc onto any CanvasItem (the slot components share this one implementation).
static func draw_night_disc(ci: CanvasItem, icon_rect: Rect2, tile: Rect2, corner_radius: float) -> void:
	var disc := night_disc(icon_rect, tile, corner_radius)
	var col := Color(NIGHT_DISC_COLOR.r, NIGHT_DISC_COLOR.g, NIGHT_DISC_COLOR.b, NIGHT_DISC_ALPHA)
	for poly in disc["polygons"]:
		ci.draw_colored_polygon(poly, col)


# ---------------------------------------------------------------- the control

func _reload() -> void:
	if item_id == &"":
		_tex = null
		_night_file = false
	else:
		var e := load_icon(item_id, rarity)
		_tex = e["tex"]
		_night_file = bool(e["night"])
	queue_redraw()


## The file the picture comes from right now ("" = no directory has it: the badge is drawn). Follows `item_id` AND `rarity`.
func icon_path() -> String:
	return _tex.resource_path if _tex != null else ""


## True when a legendary icon is drawn on the pale disc because its `_night` file is missing.
func uses_night_disc() -> bool:
	return _tex != null and wants_night(rarity) and not _night_file


## The text the control shows while there is no picture: `display_name`, else (with `id_fallback`) the item id, else "" (nothing
## is drawn at all).
func fallback_label() -> String:
	if display_name != "":
		return display_name
	return String(item_id).replace("_", " ") if id_fallback else ""


func _draw() -> void:
	if item_id == &"" or size.x < 6.0 or size.y < 6.0:
		return
	if _tex != null:
		var s := minf(size.x, size.y)
		var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
		if uses_night_disc():
			var tile := Rect2(Vector2.ONE * tile_border, size - Vector2.ONE * tile_border * 2.0)
			draw_night_disc(self, r, tile, maxf(tile_radius - tile_border, 0.0))
		draw_texture_rect(_tex, r, false)
		return
	var label := fallback_label()
	if label != "":
		draw_badge(self, Rect2(Vector2.ZERO, size), item_id, label, mode)


## The "no picture yet" look: a coloured badge with the item's initial (mode BADGE) or the tiny mono name (mode LABEL), inside
## `area`. Shared with RaritySlot so every tile shows the same fallback. The colour comes from the id, never from the rarity.
static func draw_badge(ci: CanvasItem, area: Rect2, id: StringName, label_text: String = "", badge_mode: Mode = Mode.BADGE) -> void:
	var label := label_text if label_text != "" else String(id).replace("_", " ")
	if badge_mode == Mode.LABEL:
		var f := MONO
		var fs := 9
		var w := f.get_string_size(label.to_lower(), HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		ci.draw_string(f, area.position + Vector2((area.size.x - w) * 0.5, area.size.y * 0.5 + 3.0), label.to_lower(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#6a5a48"))
		return
	var idx: int = absi(String(id).hash()) % BADGES.size()
	var c := area.get_center()
	var rad := minf(area.size.x, area.size.y) * 0.34
	ci.draw_circle(c, rad, BADGES[idx])
	ci.draw_arc(c, rad, 0.0, TAU, 40, INK, 2.0, true)
	var ini := label.substr(0, 1).to_upper()
	var fs2 := maxi(8, int(rad * 1.15))
	var tw := DISPLAY.get_string_size(ini, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2).x
	ci.draw_string(DISPLAY, Vector2(c.x - tw * 0.5, c.y + fs2 * 0.34), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, INK)
