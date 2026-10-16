class_name PieceCatalog
extends RefCounted
## Resolves the id of a room piece to art, footprint and layer (T-towns-core, TOWNS addendum 4.4, design_towns.md 4.3). A room JSON names its pieces by ids; this is the ONE place that
## decides what is drawn, in this order:
##   1. the baked KIT manifest (assets/iso_props/shops/core/shops.json, .../special/shops.json: integration track I3 / I4);
##   2. furniture.json (A1, 130 pieces);
##   3. data/interiors/stand_ins.json (a kit id -> an existing furniture id: an oven is a fireplace, a tub is a rug): drawn at the footprint and layer of the KIT table;
##   4. a PLACEHOLDER box labelled with the id (an id nothing knows; the size comes from the kit table when it knows the id).
## data/interiors/kit_footprints.json holds the footprint and layer of the 104 kit ids, so a room validates before the art exists and does not change the day the art lands.
## Every stand-in that was drawn is REPORTED (used_stand_ins): never silent. Nothing here names a class of a later wave; the manifests of later packages are plain JSON read when they exist.
##
## resolve(id, rot) -> {id, source: "kit" | "furniture" | "stand_in" | "placeholder", art_id, layer, footprint: Vector2i (placement, rotated), file, size, pivot, ysort, flip,
##                      night, glow, label}.   Entry shape of the manifests (furniture.json): items { id: { layer, rot_map, rot { k: { file, size, pivot, footprint, ysort? } } } }.

const FURNITURE_JSON := "res://assets/iso_props/furniture/furniture.json"
const FURNITURE_DIR := "res://assets/iso_props/furniture/"
const KIT_MANIFESTS: Array[String] = ["res://assets/iso_props/shops/core/shops.json", "res://assets/iso_props/shops/special/shops.json"]
const EMBLEMS_JSON := "res://assets/iso_props/shops/core/emblems.json"
const STAND_INS_JSON := "res://data/interiors/stand_ins.json"
const KIT_TABLE_JSON := "res://data/interiors/kit_footprints.json"
const HALF_W := 64.0
const HALF_H := 38.0

## Test seams: a test points the catalog at fixture files; reset() forgets every cache.
static var furniture_path: String = FURNITURE_JSON
static var kit_manifest_paths: Array[String] = KIT_MANIFESTS.duplicate()
static var emblems_path: String = EMBLEMS_JSON
static var stand_ins_path: String = STAND_INS_JSON
static var kit_table_path: String = KIT_TABLE_JSON
## Every stand-in drawn since reset(): kit id -> furniture id (the validator and the section list them).
static var used_stand_ins: Dictionary = {}
static var placeholders_used: Dictionary = {}

static var _json_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _box_cache: Dictionary = {}


static func reset() -> void:
	furniture_path = FURNITURE_JSON
	kit_manifest_paths = KIT_MANIFESTS.duplicate()
	emblems_path = EMBLEMS_JSON
	stand_ins_path = STAND_INS_JSON
	kit_table_path = KIT_TABLE_JSON
	forget()


## Forgets the caches and the stand-in report (the paths stay).
static func forget() -> void:
	_json_cache.clear()
	_tex_cache.clear()
	_box_cache.clear()
	used_stand_ins.clear()
	placeholders_used.clear()


# ------------------------------------------------------------------------------------------------ the tables

static func json_of(path: String) -> Dictionary:
	if _json_cache.has(path):
		return _json_cache[path]
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = parsed
	_json_cache[path] = data
	return data


static func texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		var cached: Variant = TextureRefs.fetch(_tex_cache[path])
		if cached is Texture2D:
			return cached
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if tex == null and FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_tex_cache[path] = TextureRefs.store(tex)
	return tex


## furniture.json items: id -> def.
static func furniture() -> Dictionary:
	return _items_of(json_of(furniture_path))


## The baked kit pieces of every manifest that exists: id -> def (+ `_dir`, the folder the files of its manifest are relative to). {} while nothing is baked.
static func kit_manifest() -> Dictionary:
	var out: Dictionary = {}
	for p in kit_manifest_paths:
		var data: Dictionary = json_of(p)
		if data.is_empty():
			continue
		var dir: String = p.get_base_dir() + "/"
		var items: Dictionary = _items_of(data)
		for id in items:
			var d: Variant = items[id]
			if d is Dictionary:
				var def: Dictionary = (d as Dictionary).duplicate()
				def["_dir"] = dir
				out[str(id)] = def
	return out


static func kit_manifest_exists() -> bool:
	for p in kit_manifest_paths:
		if FileAccess.file_exists(p):
			return true
	return false


## data/interiors/kit_footprints.json `pieces`: id -> {footprint, layer, rot_baked, template, package, set}.
static func kit_table() -> Dictionary:
	var pieces: Variant = json_of(kit_table_path).get("pieces", {})
	return pieces as Dictionary if pieces is Dictionary else {}


## `emblems`: id -> {package, size} (the 15 plates of the door signs).
static func kit_emblems() -> Dictionary:
	var e: Variant = json_of(kit_table_path).get("emblems", {})
	return e as Dictionary if e is Dictionary else {}


static func stand_in_table() -> Dictionary:
	var s: Variant = json_of(stand_ins_path).get("stand_ins", {})
	return s as Dictionary if s is Dictionary else {}


static func _items_of(data: Dictionary) -> Dictionary:
	var items: Variant = data.get("items", null)
	if items is Dictionary:
		return items
	var flat: Dictionary = {}
	for k in data:
		if not str(k).begins_with("_") and data[k] is Dictionary and (data[k] as Dictionary).has("rot"):
			flat[k] = data[k]
	return flat


# ------------------------------------------------------------------------------------------------ resolve

## Where the art of `item_id` comes from and how it sits in the room (see the header). `rot` 0..3 (quarter turns).
static func resolve(item_id: String, rot: int = 0) -> Dictionary:
	var r: int = posmod(rot, 4)
	var out: Dictionary = {"id": item_id, "source": "placeholder", "art_id": "", "layer": "floor", "footprint": Vector2i.ONE, "file": "", "size": Vector2i.ZERO,
			"pivot": Vector2.ZERO, "ysort": Vector2.ZERO, "flip": false, "night": "", "night_offset": Vector2.ZERO, "glow": {}, "label": item_id}
	var kit_row: Dictionary = kit_table().get(item_id, {}) as Dictionary
	var manifest: Dictionary = kit_manifest()
	var furn: Dictionary = furniture()
	var def: Dictionary = {}
	if manifest.has(item_id):
		def = manifest[item_id]
		out["source"] = "kit"
		out["art_id"] = item_id
	elif furn.has(item_id):
		def = furn[item_id]
		out["source"] = "furniture"
		out["art_id"] = item_id
		def = (def as Dictionary).duplicate()
		def["_dir"] = FURNITURE_DIR
	else:
		var target: String = str(stand_in_table().get(item_id, ""))
		if target != "" and furn.has(target):
			def = (furn[target] as Dictionary).duplicate()
			def["_dir"] = FURNITURE_DIR
			out["source"] = "stand_in"
			out["art_id"] = target
			used_stand_ins[item_id] = target
		else:
			placeholders_used[item_id] = true
	# the placement layer and footprint: the kit table is the authority for a kit id, else the piece's own definition
	var layer: String = str(kit_row.get("layer", def.get("layer", "floor")))
	var fp: Vector2i = _footprint_of(kit_row, def, r)
	out["layer"] = layer
	out["footprint"] = fp
	if def.is_empty():
		_fill_box(out)
		return out
	var ent: Dictionary = {}
	var idx: int = r
	var rot_map: Variant = def.get("rot_map", null)
	if rot_map is Array and (rot_map as Array).size() > r and (rot_map[r] is Array):
		idx = int(rot_map[r][0])
		out["flip"] = bool(rot_map[r][1])
	var rots: Dictionary = def.get("rot", {}) as Dictionary
	ent = rots.get(str(idx), rots.get("0", {})) as Dictionary
	if ent.is_empty():
		_fill_box(out)
		return out
	var dir: String = str(def.get("_dir", FURNITURE_DIR))
	out["file"] = dir + str(ent.get("file", ""))
	out["size"] = _v2i(ent.get("size", [0, 0]))
	out["pivot"] = _v2(ent.get("pivot", [0, 0]))
	if str(out["source"]) == "stand_in":
		out["ysort"] = footprint_ysort(fp)               # the sort point of the PLACEMENT footprint, not of the stand-in's own one
	else:
		out["ysort"] = _v2(ent.get("ysort", [0, 0]))
	if ent.has("night"):
		out["night"] = dir + str(ent["night"])
		out["night_offset"] = _v2(ent.get("night_offset", [0, 0]))
	if ent.has("glow"):
		out["glow"] = ent["glow"]
	return out


## The footprint (w, d) of an id at a rotation (quarter turns): what the validator and the colliders use.
static func footprint(item_id: String, rot: int = 0) -> Vector2i:
	return resolve(item_id, rot)["footprint"]


static func layer_of(item_id: String) -> String:
	return str(resolve(item_id, 0)["layer"])


## Vector from the centre of a footprint to its LEFT corner: the baked y-sort offset of furniture.json (-(fx + fz) * 32, (fz - fx) * 19).
static func footprint_ysort(fp: Vector2i) -> Vector2:
	return Vector2(-float(fp.x + fp.y) * HALF_W * 0.5, float(fp.y - fp.x) * HALF_H * 0.5)


static func _footprint_of(kit_row: Dictionary, def: Dictionary, rot: int) -> Vector2i:
	var base: Vector2i = Vector2i.ONE
	if not kit_row.is_empty():
		base = _v2i(kit_row.get("footprint", [1, 1]))
		return Vector2i(base.y, base.x) if rot % 2 == 1 else base
	var rots: Dictionary = def.get("rot", {}) as Dictionary
	var rot_map: Variant = def.get("rot_map", null)
	var idx: int = rot
	if rot_map is Array and (rot_map as Array).size() > rot and (rot_map[rot] is Array):
		idx = int(rot_map[rot][0])
	var ent: Variant = rots.get(str(idx), null)
	if ent is Dictionary and (ent as Dictionary).has("footprint"):
		return _v2i((ent as Dictionary)["footprint"])
	base = _v2i(def.get("footprint", [1, 1]))
	return Vector2i(base.y, base.x) if rot % 2 == 1 else base


static func _v2(v: Variant) -> Vector2:
	return Vector2(float(v[0]), float(v[1])) if v is Array and (v as Array).size() >= 2 else Vector2.ZERO


static func _v2i(v: Variant) -> Vector2i:
	return Vector2i(int(v[0]), int(v[1])) if v is Array and (v as Array).size() >= 2 else Vector2i.ONE


# ------------------------------------------------------------------------------------------------ the placeholder box

## A labelled box of the footprint's size: honest "no art for this id" (the label is the id, set by the room builder).
static func _fill_box(out: Dictionary) -> void:
	var fp: Vector2i = out["footprint"]
	var box: Dictionary = box_art(fp)
	out["file"] = ""
	out["size"] = box["size"]
	out["pivot"] = box["pivot"]
	out["ysort"] = footprint_ysort(fp)
	out["source"] = "placeholder"
	out["texture"] = box["texture"]


## {texture, size, pivot} of the placeholder box for a footprint: the floor parallelogram and a low block on it, drawn once per footprint.
static func box_art(fp: Vector2i) -> Dictionary:
	var key: String = "%dx%d" % [fp.x, fp.y]
	if _box_cache.has(key):
		var cached: Variant = TextureRefs.fetch(_box_cache[key])
		if cached is Dictionary:
			return cached
	var span: float = float(fp.x + fp.y)
	var w: int = int(span * HALF_W) + 4
	var h_top: float = span * HALF_H
	var height: int = 54
	var h: int = int(h_top) + height + 4
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var centre := Vector2(float(w) * 0.5, float(height) + h_top * 0.5 + 2.0)
	# the ground parallelogram of the footprint around its centre: top, right, bottom, left corners
	var half_x: float = float(fp.x) * HALF_W * 0.5
	var half_z: float = float(fp.y) * HALF_W * 0.5
	var qx: float = float(fp.x) * HALF_H * 0.5
	var qz: float = float(fp.y) * HALF_H * 0.5
	var top := centre + Vector2(half_x - half_z, -(qx + qz))
	var right := centre + Vector2(half_x + half_z, qx - qz)
	var bottom := centre + Vector2(half_z - half_x, qx + qz)
	var left := centre + Vector2(-half_x - half_z, qz - qx)
	_fill_poly(img, [top, right, bottom, left], Color(0.84, 0.74, 0.55, 0.95))
	var lift := Vector2(0, -float(height))
	_fill_poly(img, [left, bottom, bottom + lift, left + lift], Color(0.62, 0.50, 0.36, 0.95))
	_fill_poly(img, [bottom, right, right + lift, bottom + lift], Color(0.72, 0.58, 0.41, 0.95))
	_fill_poly(img, [top + lift, right + lift, bottom + lift, left + lift], Color(0.93, 0.83, 0.63, 0.95))
	var art: Dictionary = {"texture": ImageTexture.create_from_image(img), "size": Vector2i(w, h), "pivot": centre}
	_box_cache[key] = TextureRefs.store(art)
	return art


static func _fill_poly(img: Image, pts: Array, color: Color) -> void:
	var minx: int = img.get_width()
	var maxx: int = 0
	var miny: int = img.get_height()
	var maxy: int = 0
	for p in pts:
		minx = mini(minx, int(floor((p as Vector2).x)))
		maxx = maxi(maxx, int(ceil((p as Vector2).x)))
		miny = mini(miny, int(floor((p as Vector2).y)))
		maxy = maxi(maxy, int(ceil((p as Vector2).y)))
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(p as Vector2)
	for y in range(maxi(miny, 0), mini(maxy + 1, img.get_height())):
		for x in range(maxi(minx, 0), mini(maxx + 1, img.get_width())):
			if Geometry2D.is_point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), poly):
				img.set_pixel(x, y, color)


# ------------------------------------------------------------------------------------------------ door signs

## The plate of an emblem id from assets/iso_props/shops/core/emblems.json ({} while the I3 manifest does not exist): {texture, size, pivot}.
static func emblem(emblem_id: String) -> Dictionary:
	var data: Dictionary = json_of(emblems_path)
	if data.is_empty():
		return {}
	var table: Variant = data.get("emblems", data)
	var entry: Variant = null
	if table is Dictionary:
		entry = (table as Dictionary).get(emblem_id, null)
	elif table is Array:
		for e in (table as Array):
			if e is Dictionary and str((e as Dictionary).get("id", "")) == emblem_id:
				entry = e
				break
	if not (entry is Dictionary) or not (entry as Dictionary).has("file"):
		return {}
	var tex: Texture2D = texture(emblems_path.get_base_dir() + "/" + str((entry as Dictionary)["file"]))
	if tex == null:
		return {}
	var size: Vector2i = _v2i((entry as Dictionary).get("size", [tex.get_width(), tex.get_height()]))
	var pivot: Vector2 = _v2((entry as Dictionary).get("pivot", [float(size.x) * 0.5, float(size.y) * 0.5]))
	return {"texture": tex, "size": size, "pivot": pivot}


## The ids of every plate emblems.json lists ([] while it does not exist).
static func emblem_ids() -> Array[String]:
	var out: Array[String] = []
	var data: Dictionary = json_of(emblems_path)
	var table: Variant = data.get("emblems", data)
	if table is Dictionary:
		for k in (table as Dictionary):
			if not str(k).begins_with("_") and (table[k] is Dictionary):
				out.append(str(k))
	elif table is Array:
		for e in (table as Array):
			if e is Dictionary and (e as Dictionary).has("id"):
				out.append(str((e as Dictionary)["id"]))
	out.sort()
	return out


## The sign bracket piece (a wall piece of the I3 manifest) resolved like any piece, or {} while it is not baked (nothing is drawn then).
static func sign_bracket() -> Dictionary:
	if not kit_manifest().has("sign_bracket"):
		return {}
	return resolve("sign_bracket", 0)
