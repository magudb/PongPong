class_name ArtCatalog
extends RefCounted
## The single lookup for world art (plan 6.2 asset contract, decision D18): terrain(id), prop(id), backdrop(theme), icon(item_id),
## portrait(visual_id), character_exists(id). Everything returns something drawable: when a key has no real asset the answer is the
## PlaceholderArt / PropArt fallback, the id is recorded in missing() (WITHOUT push_warning / push_error: the tests print the list,
## P27 asserts it is empty for shipped content) and the real art replaces it later without a code change.
##
## Manifests (read once, lazily):
##   terrains   res://assets/iso_tiles/tiles.json (+ every tiles_*.json next to it, e.g. the A1 floors tiles_floors.json)
##              {id: {file, variants [x, y], cell [w, h], proj?}}  file is relative to the json
##   props      res://assets/iso_props/props.json UNION res://assets/iso_props/*/props.json (feature props live in features/; home/,
##              furniture/ and interior/ have their own jsons - home.json ... - which are NOT read here)
##              {id: {file, size [w, h], pivot [x, y], footprint [fx, fz], glow?: {file, center, color, size, blend}, blend?, proj?}}
##   backdrops  res://assets/backdrops/<theme>_sky.webp and <theme>_far.webp
##   icons      res://assets/icons/items/<id>.webp, then icons/home/<id>.webp, then icons/wardrobe/<id>.webp
##              (+ <id>_night.webp, the pale-rimmed variant of legendary icons for the night tile)
##   portraits  res://assets/portraits/<id>.webp, then res://assets/isometric_characters/<art id>/portrait.webp
##
## Placeholder painting is lazy (only what an area asks for), cached (static dictionaries) and timed (paint_ms()).

const TILES_DIR := "res://assets/iso_tiles/"
const PROPS_DIR := "res://assets/iso_props/"
const BACKDROP_DIR := "res://assets/backdrops/"
const ICON_DIRS: Array[String] = ["res://assets/icons/items/", "res://assets/icons/home/", "res://assets/icons/wardrobe/"]
const PORTRAIT_DIR := "res://assets/portraits/"
const CHARACTERS_DIR := "res://assets/isometric_characters/"

## Placeholder tile cell of an ortho terrain (the diamond cell is Iso.TILE_CELL_W x Iso.TILE_CELL_H).
const ORTHO_CELL := Vector2i(Iso.ORTHO_W + 16, Iso.ORTHO_H + 8)

## Backdrop colours per theme (top, bottom of the sky; far canopy colours): the zone palettes of the style guide.
const BACKDROP_THEMES := {
	&"farm": {"top": Color("8ec9e3"), "bottom": Color("e8f2dc"), "far_a": Color("7fae6a"), "far_b": Color("5f9a55"), "mist": Color("d5ecd0")},
	&"hyggebyen": {"top": Color("b3a2e4"), "bottom": Color("f6dce8"), "far_a": Color("a98fd0"), "far_b": Color("8e78c4"), "mist": Color("f2dff0")},
	&"forest": {"top": Color("10162b"), "bottom": Color("2a3a5c"), "far_a": Color("1f3a31"), "far_b": Color("2f4a3f"), "mist": Color("3a5c6a")},
	&"cave": {"top": Color("0b0f1e"), "bottom": Color("1b2038"), "far_a": Color("1c2138"), "far_b": Color("262c48"), "mist": Color("2f3654")},
	&"home": {"top": Color("2b2340"), "bottom": Color("4b3b5c"), "far_a": Color("3b2f50"), "far_b": Color("4b3b5c"), "mist": Color("5a4a6e")},
}

static var _terrain_manifest: Dictionary = {}
static var _prop_manifest: Dictionary = {}
static var _scanned: bool = false
static var _terrains: Dictionary = {}
static var _props: Dictionary = {}
static var _backdrops: Dictionary = {}
static var _icons: Dictionary = {}
static var _portraits: Dictionary = {}
static var _missing: Dictionary = {}
static var _paint_usec: int = 0


# ----------------------------------------------------------------------------- bookkeeping

## Sorted ids that fell back to a placeholder since the last reset: "terrain:grass", "prop:house_farm", "backdrop:farm",
## "icon:carrot", "portrait:fairy_mayor".
static func missing() -> Array[String]:
	var out: Array[String] = []
	for k in _missing.keys():
		out.append(str(k))
	out.sort()
	return out


static func clear_missing() -> void:
	_missing.clear()


## Forgets every cache and manifest (tests that add assets, hot reload of art).
static func reset() -> void:
	_terrain_manifest.clear()
	_prop_manifest.clear()
	_scanned = false
	_terrains.clear()
	_props.clear()
	_backdrops.clear()
	_icons.clear()
	_portraits.clear()
	_missing.clear()
	_paint_usec = 0


## Milliseconds spent painting placeholders since the last reset (the boot-cost budget of task 2 is 200 ms).
static func paint_ms() -> float:
	return float(_paint_usec) / 1000.0


static func _note_missing(kind: String, id: String) -> void:
	_missing["%s:%s" % [kind, id]] = true


# ----------------------------------------------------------------------------- manifests

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return {}
	return json.data


static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	_terrain_manifest.clear()
	_prop_manifest.clear()
	# terrains: tiles.json and every tiles_*.json
	var tdir := DirAccess.open(TILES_DIR)
	if tdir != null:
		var jsons: Array[String] = []
		for f in tdir.get_files():
			if f == "tiles.json" or (f.begins_with("tiles_") and f.ends_with(".json")):
				jsons.append(f)
		jsons.sort()
		for f in jsons:
			var d: Dictionary = _read_json(TILES_DIR + f)
			for id in d:
				if str(id).begins_with("_") or not (d[id] is Dictionary):
					continue
				var e: Dictionary = (d[id] as Dictionary).duplicate()
				e["_dir"] = TILES_DIR
				_terrain_manifest[str(id)] = e
	# props: iso_props/props.json, then iso_props/<dir>/props.json (later directories override on a clash)
	var jsons_p: Array[String] = [PROPS_DIR + "props.json"]
	var pdir := DirAccess.open(PROPS_DIR)
	if pdir != null:
		var subs: Array[String] = []
		for sub in pdir.get_directories():
			if FileAccess.file_exists(PROPS_DIR + sub + "/props.json"):
				subs.append(sub)
		subs.sort()
		for sub in subs:
			jsons_p.append(PROPS_DIR + sub + "/props.json")
	for path in jsons_p:
		var d2: Dictionary = _read_json(path)
		var dir: String = path.get_base_dir() + "/"
		for id in d2:
			if str(id).begins_with("_") or not (d2[id] is Dictionary):
				continue
			var e2: Dictionary = (d2[id] as Dictionary).duplicate()
			e2["_dir"] = dir
			_prop_manifest[str(id)] = e2


static func terrain_manifest_ids() -> Array[String]:
	_scan()
	var out: Array[String] = []
	for k in _terrain_manifest.keys():
		out.append(str(k))
	out.sort()
	return out


static func prop_manifest_ids() -> Array[String]:
	_scan()
	var out: Array[String] = []
	for k in _prop_manifest.keys():
		out.append(str(k))
	out.sort()
	return out


static func has_real_terrain(id: StringName) -> bool:
	_scan()
	var e: Variant = _terrain_manifest.get(String(id), null)
	return e is Dictionary and ResourceLoader.exists(str((e as Dictionary)["_dir"]) + str((e as Dictionary).get("file", "")))


static func has_real_prop(id: StringName) -> bool:
	_scan()
	var e: Variant = _prop_manifest.get(String(id), null)
	return e is Dictionary and ResourceLoader.exists(str((e as Dictionary)["_dir"]) + str((e as Dictionary).get("file", "")))


static func _vec2(v: Variant, default_value: Vector2) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float((v as Array)[0]), float((v as Array)[1]))
	return default_value


static func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D


# ----------------------------------------------------------------------------- terrains

## {id, texture: Texture2D, cell: Vector2i, variants: Vector2i, proj: &"iso"|&"ortho", real: bool}. atlas coords of a map cell are
## Vector2i(cell.x % variants.x, cell.y % variants.y) (Iso.atlas_coords).
static func terrain(id: StringName) -> Dictionary:
	if _terrains.has(id):
		return _terrains[id]
	_scan()
	var res: Dictionary = {}
	var e: Variant = _terrain_manifest.get(String(id), null)
	if e is Dictionary:
		var ed: Dictionary = e
		var tex: Texture2D = _load_tex(str(ed["_dir"]) + str(ed.get("file", "")))
		if tex != null:
			var cell: Vector2 = _vec2(ed.get("cell", null), Vector2(Iso.TILE_CELL_W, Iso.TILE_CELL_H))
			var variants: Vector2 = _vec2(ed.get("variants", null), Vector2(Iso.TILE_VARIANTS, Iso.TILE_VARIANTS))
			res = {"id": id, "texture": tex, "cell": Vector2i(cell), "variants": Vector2i(variants),
				"proj": StringName(str(ed.get("proj", "iso"))), "real": true}
	if res.is_empty():
		res = _placeholder_terrain(id)
		_note_missing("terrain", String(id))
	_terrains[id] = res
	return res


static func _placeholder_terrain(id: StringName) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var known: bool = PlaceholderArt.has_terrain(id)
	var paint_id: StringName = id if known else &"grass"
	var ortho: bool = PlaceholderArt.is_ortho_terrain(paint_id)
	var cell: Vector2i = ORTHO_CELL if ortho else Vector2i(Iso.TILE_CELL_W, Iso.TILE_CELL_H)
	var variants: Vector2i = Vector2i(2, 2) if str(id).begins_with("water_") else Vector2i(Iso.TILE_VARIANTS, Iso.TILE_VARIANTS)
	var atlas: Image = PlaceholderArt.paint_atlas(paint_id, cell, variants)
	var res: Dictionary = {"id": id, "texture": ImageTexture.create_from_image(atlas), "cell": cell, "variants": variants,
		"proj": &"ortho" if ortho else &"iso", "real": false}
	_paint_usec += Time.get_ticks_usec() - t0
	return res


# ----------------------------------------------------------------------------- props

## {id, texture, pivot: Vector2, size: Vector2, footprint: Vector2i, proj, blend: "" | "add", glow: {} | {texture, center: Vector2,
## color: Color, size: Vector2, blend}, real: bool}. pivot = ground origin in px from the image top-left; place the sprite with
## `centered = false, offset = -pivot` under a node at the ground origin.
static func prop(id: StringName) -> Dictionary:
	if _props.has(id):
		return _props[id]
	_scan()
	var res: Dictionary = {}
	var e: Variant = _prop_manifest.get(String(id), null)
	if e is Dictionary:
		var ed: Dictionary = e
		var dir: String = str(ed["_dir"])
		var tex: Texture2D = _load_tex(dir + str(ed.get("file", "")))
		if tex != null:
			var fp: Vector2 = _vec2(ed.get("footprint", null), Vector2(1, 1))
			res = {"id": id, "texture": tex, "pivot": _vec2(ed.get("pivot", null), Vector2(tex.get_width() * 0.5, tex.get_height() - 4.0)),
				"size": _vec2(ed.get("size", null), tex.get_size()), "footprint": Vector2i(fp),
				"proj": StringName(str(ed.get("proj", "iso"))), "blend": str(ed.get("blend", "")), "glow": {}, "real": true}
			var g: Variant = ed.get("glow", null)
			if g is Dictionary:
				var gd: Dictionary = g
				var gtex: Texture2D = _load_tex(dir + str(gd.get("file", "")))
				if gtex != null:
					res["glow"] = {"texture": gtex, "center": _vec2(gd.get("center", null), Vector2.ZERO),
						"color": Color.from_string(str(gd.get("color", "#ffffff")), Color.WHITE),
						"size": _vec2(gd.get("size", null), gtex.get_size()), "blend": str(gd.get("blend", "add"))}
	if res.is_empty():
		res = _placeholder_prop(id)
		_note_missing("prop", String(id))
	_props[id] = res
	return res


static func _placeholder_prop(id: StringName) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var def: Dictionary = GameData.prop_def(String(id))
	var fp: Vector2i = GameData.footprint_of(String(id))
	var res: Dictionary = PropArt.make(String(id), fp)
	res["id"] = id
	if not res.has("proj"):
		res["proj"] = &"iso"
	res["real"] = false
	if not res.has("blend"):
		res["blend"] = str(def.get("blend", ""))
	if not res.has("glow"):
		res["glow"] = {}
	_paint_usec += Time.get_ticks_usec() - t0
	return res


# ----------------------------------------------------------------------------- backdrops

## {theme, sky: Texture2D, far: Texture2D, real: bool}. Real files: assets/backdrops/<theme>_sky.webp (a sky) and <theme>_far.webp
## (a far canopy strip, seamless horizontally). Missing files fall back to a gradient sky and a soft painted canopy haze.
static func backdrop(theme: StringName) -> Dictionary:
	if _backdrops.has(theme):
		return _backdrops[theme]
	var key: StringName = theme if BACKDROP_THEMES.has(theme) else &"farm"
	var sky: Texture2D = _load_tex("%s%s_sky.webp" % [BACKDROP_DIR, theme])
	var far: Texture2D = _load_tex("%s%s_far.webp" % [BACKDROP_DIR, theme])
	var real: bool = sky != null and far != null
	if not real:
		var t0: int = Time.get_ticks_usec()
		var pal: Dictionary = BACKDROP_THEMES[key]
		if sky == null:
			sky = PlaceholderArt.sky_gradient(pal["top"], pal["bottom"])
		if far == null:
			far = PropArt.canopy_far(pal["far_a"], pal["far_b"], pal["mist"])
		_paint_usec += Time.get_ticks_usec() - t0
		_note_missing("backdrop", String(theme))
	var res: Dictionary = {"theme": theme, "sky": sky, "far": far, "real": real}
	_backdrops[theme] = res
	return res


# ----------------------------------------------------------------------------- icons, portraits, characters

## The item icon (128 x 128): items/, then home/, then wardrobe/. `night` asks for the <id>_night.webp variant of legendary
## icons (pale die-cut rim for the night tile) and falls back to the plain icon.
static func icon(item_id: StringName, night: bool = false) -> Texture2D:
	var key: String = "%s%s" % [item_id, "#night" if night else ""]
	if _icons.has(key):
		return _icons[key]
	var tex: Texture2D = null
	for dir in ICON_DIRS:
		if night:
			tex = _load_tex("%s%s_night.webp" % [dir, item_id])
		if tex == null:
			tex = _load_tex("%s%s.webp" % [dir, item_id])
		if tex != null:
			break
	if tex == null:
		var t0: int = Time.get_ticks_usec()
		tex = PropArt.icon_badge(String(item_id))
		_paint_usec += Time.get_ticks_usec() - t0
		_note_missing("icon", String(item_id))
	_icons[key] = tex
	return tex


## The directory an icon was found in ("" = none): used by tests and by tt_item_icon's resolver.
static func icon_path(item_id: StringName, night: bool = false) -> String:
	for dir in ICON_DIRS:
		if night and ResourceLoader.exists("%s%s_night.webp" % [dir, item_id]):
			return "%s%s_night.webp" % [dir, item_id]
		if ResourceLoader.exists("%s%s.webp" % [dir, item_id]):
			return "%s%s.webp" % [dir, item_id]
	return ""


## Bust of a character: assets/portraits/<id>.webp, else the portrait of the art folder the id draws with.
static func portrait(visual_id: StringName) -> Texture2D:
	if _portraits.has(visual_id):
		return _portraits[visual_id]
	var tex: Texture2D = _load_tex("%s%s.webp" % [PORTRAIT_DIR, visual_id])
	if tex == null:
		var art: String = CharacterCatalog.resolve(String(visual_id))
		if art != "":
			tex = _load_tex("%s%s.webp" % [PORTRAIT_DIR, art])
			if tex == null:
				tex = _load_tex("%s%s/portrait.webp" % [CHARACTERS_DIR, art])
	if tex == null:
		var t0: int = Time.get_ticks_usec()
		tex = PropArt.portrait_badge(String(visual_id))
		_paint_usec += Time.get_ticks_usec() - t0
		_note_missing("portrait", String(visual_id))
	_portraits[visual_id] = tex
	return tex


## True when the id (or something in its fallback chain of lua/config/characters.lua) has a character art folder.
static func character_exists(id: String) -> bool:
	return IsoChibiSprite2D.character_exists(id)
