extends RefCounted
## Section art_home (package A1-art-home, wave 2): the home art as shipped in res://assets - houses, furniture, interior, floors, icons, props - against the
## contracts of addendum 3.5 and the CONTENT SNAPSHOT tools/art/features/home/specs/content_contract.json (A1 cannot read lua/data or lua/items, those are F1's in
## wave 3; F1's validator rule R19 proves the snapshot against the real Lua, so nothing is skipped here).
##
## Headless and independent of the Python validator (tools/art/features/home/isometric/validate_features_home.py implements the same checks a second time):
##   furniture_files  furniture_sprite_counts  mirror_ok_measured  icons_complete  icons_ink_outline  icons_night_rim  props_manifest  contract_matches_snapshot
##   tier_anchor_identical  house_mass_monotonic  house_height_monotonic  night_layers_additive_trimmed  scaffolds_nine  interior_pieces  floors_no_mipmaps  byte_budget  readme_verdict
## Fix round (independent review of A1): furniture_looks_distinct (no two ids share an identical or near-identical r0 sprite or icon)  house_ground_contact  scaffold_anchor_matches_tier
##   furniture_ground_contact (the anchors are checked on PIXELS: footprint corners, lowest opaque rows, extents, y-sort key from the footprint)  symmetry_measured_consistent
##   float_layers_legendary_only  room_windows_contract  readme_fix_round
const SECTION := "art_home"
const TIMEOUT_S := 240.0

const HOME_DIR := "res://assets/iso_props/home"
const FURN_DIR := "res://assets/iso_props/furniture"
const INTERIOR_DIR := "res://assets/iso_props/interior"
const FEATURES_DIR := "res://assets/iso_props/features"
const ICON_DIR := "res://assets/icons/home"
const ROOM_DIR := "res://assets/data/home/rooms"
const TILE_DIR := "res://assets/iso_tiles"
const SPEC_DIR := "res://tools/art/features/home/specs"
const README := "res://tools/art/features/home/README.md"
const PROPS_LUA := "res://lua/config/props_features.lua"

const INK := Vector3(43, 35, 64)
const RIM := Vector3(228, 239, 245)        # e4eff5
const NIGHT := Vector3(47, 54, 84)         # 2f3654
const BUDGET_BYTES := 12000000
## fabric key -> painter pattern (furniture_traetoppen.FABRICS); stripe, quilt and damask are "patterned" (a mirrored pattern is a different pattern)
const FABRIC_PATTERN := {"natur": "weave", "roed": "weave", "blaa": "stripe", "groen": "quilt", "bordeaux": "velvet", "blommevelour": "velvet",
	"guld": "damask", "rosendamask": "damask", "kongeblaa": "damask", "maane": "velvet"}
const PATTERNED := ["stripe", "quilt", "damask"]
## one tile is a diamond 128 x 75.2 px (36 degrees): +x = (+HW, +HH), +z = (-HW, +HH) per tile
const HW := 64.0
const HH := 37.6
## two different ids closer than this (mean abs RGB over the union of the opaque pixels, silhouette within 1 %) are the same picture; the closest legitimate pair is 4.7
const NEAR_DUP_MEAN := 2.0
## symmetry rule of tools/art/features/home/isometric/measure_symmetry.py: two views are equal below both limits
const SYM_ERR_MAX := 20.0
const SYM_SIL_MAX := 4.0
const NEW_PROPS := ["chest_trae", "chest_jern", "chest_fe", "chest_konge", "dig_glimmer", "unique_glimmer", "tent", "slate_vein", "marble_vein"]

var _t
var _cache: Dictionary = {}


func run(t) -> void:
	_t = t
	var spec_doc: Dictionary = _json(SPEC_DIR + "/furniture_art_spec.json")
	var contract: Dictionary = _json(SPEC_DIR + "/content_contract.json")
	var spec: Array = spec_doc.get("items", [])
	var fj_doc: Dictionary = _json(FURN_DIR + "/furniture.json")
	var fj: Dictionary = fj_doc.get("items", {})
	var home_doc: Dictionary = _json(HOME_DIR + "/home.json")
	t.check("inputs_present", spec.size() == 130 and not fj.is_empty() and not home_doc.is_empty() and (contract.get("tiers", []) as Array).size() == 10,
		"spec %d items, furniture.json %d, home.json %d tiers, snapshot %d tiers" % [spec.size(), fj.size(), (home_doc.get("tiers", []) as Array).size(), (contract.get("tiers", []) as Array).size()])
	if spec.size() != 130 or fj.is_empty() or home_doc.is_empty():
		return
	_furniture(spec, contract, fj)
	_furniture_anchors(fj)
	_symmetry_and_floats(fj)
	_mirror(spec, fj)
	_icons(spec, contract)
	_distinct_looks(spec, fj, contract)
	_houses(home_doc, contract, fj)
	_house_pixels(home_doc)
	_rooms_and_floors(home_doc, contract)
	_interior()
	_props()
	_budget()
	_readme()


# ---------------------------------------------------------------- helpers

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


## Loaded image, converted to RGBA8 (cached by path).  Null when missing or undecodable.
func _img(path: String) -> Image:
	if _cache.has(path):
		return _cache[path]
	var im: Image = null
	if FileAccess.file_exists(path):
		# decoded from the raw file bytes (not through ResourceLoader): independent of the import state, and no "loaded resource as image file" warning per sprite
		var bytes := FileAccess.get_file_as_bytes(path)
		im = Image.new()
		var err := ERR_FILE_UNRECOGNIZED
		if path.ends_with(".webp"):
			err = im.load_webp_from_buffer(bytes)
		elif path.ends_with(".png"):
			err = im.load_png_from_buffer(bytes)
		if err == OK and not im.is_empty():
			im.convert(Image.FORMAT_RGBA8)
		else:
			im = null
	_cache[path] = im
	return im


func _needed(sym: String) -> Array:
	match sym:
		"c4":
			return [0]
		"c2", "wall2":
			return [0, 1]
	return [0, 1, 2, 3]


func _lum(c: Vector3) -> float:
	var out := Vector3.ZERO
	for i in 3:
		var v := c[i] / 255.0
		out[i] = v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * out.x + 0.7152 * out.y + 0.0722 * out.z


func _contrast(a: Vector3, b: Vector3) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## [mean colour Vector3 of the OUTERMOST ring, ring pixel count]: opaque (a >= 128) pixels within Manhattan distance 2 of an empty (a < 32) pixel.
func _ring(im: Image) -> Array:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	var offs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var sum := Vector3.ZERO
	var n := 0
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			if d[i + 3] < 128:
				continue
			var touch := false
			for o in offs:
				var nx := x + o.x
				var ny := y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if d[(ny * w + nx) * 4 + 3] < 32:
					touch = true
					break
			if touch:
				sum += Vector3(d[i], d[i + 1], d[i + 2])
				n += 1
	return [sum / float(maxi(n, 1)), n]


## max(bbox w, bbox h) / image size of the pixels with alpha > 8
func _fill(im: Image) -> float:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			if d[(y * w + x) * 4 + 3] > 8:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if x1 < 0:
		return 0.0
	return float(maxi(x1 - x0 + 1, y1 - y0 + 1)) / float(w)


# ---------------------------------------------------------------- furniture

func _furniture(spec: Array, contract: Dictionary, fj: Dictionary) -> void:
	var t = _t
	var cf: Dictionary = contract.get("furniture", {})
	var spec_ids: Array = []
	for it in spec:
		spec_ids.append(String(it["id"]))
	var fj_ids: Array = fj.keys()
	spec_ids.sort()
	fj_ids.sort()
	var cf_ids: Array = cf.keys()
	cf_ids.sort()
	t.check("furniture_ids_equal_spec", spec_ids == fj_ids and spec_ids == cf_ids, "spec %d, furniture.json %d, snapshot %d" % [spec_ids.size(), fj_ids.size(), cf_ids.size()])
	var bad: Array[String] = []
	var mains := 0
	var floats := 0
	for it in spec:
		var id := String(it["id"])
		if not fj.has(id):
			bad.append("%s: not in furniture.json" % id)
			continue
		var e: Dictionary = fj[id]
		var c: Dictionary = cf.get(id, {})
		if str(e.get("layer")) != str(it["layer"]) or str(e.get("template")) != str(it["template"]) or str(c.get("template")) != str(it["template"]) or str(c.get("layer")) != str(it["layer"]):
			bad.append("%s: layer/template differs from spec or snapshot" % id)
		var fp_e: Array = e.get("footprint", [])
		var fp_s: Array = it["footprint"]
		var fp_c: Array = c.get("footprint", [])
		if fp_e.size() != 2 or fp_e[0] != fp_s[0] or fp_e[1] != fp_s[1] or fp_c.size() != 2 or fp_c[0] != fp_s[0] or fp_c[1] != fp_s[1]:
			bad.append("%s: footprint %s vs spec %s vs snapshot %s" % [id, fp_e, fp_s, fp_c])
		var rot: Dictionary = e.get("rot", {})
		for k in _needed(String(e.get("sym", "none"))):
			if not rot.has(str(k)):
				bad.append("%s: rotation r%d missing" % [id, k])
				continue
			var ent: Dictionary = rot[str(k)]
			var im := _img(FURN_DIR.path_join(String(ent.get("file", "x"))))
			if im == null:
				bad.append("%s: r%d file %s missing or unreadable" % [id, k, ent.get("file", "?")])
				continue
			mains += 1
			var sz: Array = ent["size"]
			var pv: Array = ent["pivot"]
			var w := im.get_width()
			var h := im.get_height()
			if int(sz[0]) != w or int(sz[1]) != h:
				bad.append("%s: r%d size %s != image %dx%d" % [id, k, sz, w, h])
			var px := int(pv[0])
			var py := int(pv[1])
			# floor / rug / tabletop pieces stand ON their pivot (inside the sprite); wall and ceiling pieces carry the ground anchor BELOW the sprite on the same vertical line (contract)
			var inside := px >= 0 and px < w and (py >= 0 and py < h if ["floor", "rug", "tabletop"].has(str(e["layer"])) else (py >= h - 1 and py < h + 400))
			if not inside:
				bad.append("%s: r%d pivot %s outside the image %dx%d (layer %s)" % [id, k, pv, w, h, e["layer"]])
			if ent.has("float"):
				floats += 1
				if _img(FURN_DIR.path_join(String(ent["float"]["file"]))) == null:
					bad.append("%s: r%d float layer missing" % [id, k])
		if not rot.has("0"):
			bad.append("%s: no r0" % id)
	t.check("furniture_files", bad.is_empty() and mains > 0, "%d main sprites; %s" % [mains, str(bad.slice(0, 4))])
	# 79 four-view pieces x 4 + 18 c2 x 2 + 14 c4 x 1 + 19 wall pieces x 2 = 404 (the first count of 373 trusted the templates' declared symmetry, 31 sprites of 15 pieces were missing
	# once the classes were MEASURED); the 11 legendary pieces carry one float layer per baked rotation = 38
	var painted := _painted_furniture()
	var expected_main := 482 if painted else 404
	var expected_float := 44 if painted else 38
	t.check("furniture_sprite_counts", mains == expected_main and floats == expected_float,
		"%d main sprites + %d float layers (%d + %d expected; painted free-standing pieces keep all four authored views)" % [mains, floats, expected_main, expected_float])


func _painted_furniture() -> bool:
	return _json(FURN_DIR + "/furniture.json").get("_contract", {}).get("illustration", "") == "painted-consistency-v1"


# ---------------------------------------------------------------- anchors on PIXELS (fix round: the first version only proved JSON arithmetic and "pivot inside the image")

## [left, right, top, bottom] of the pixels with alpha >= thr (scans in from each side and stops at the first hit); [-1, -1, -1, -1] when there is none
func _extent(im: Image, thr: int) -> Array:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	var l := -1
	var x := 0
	while x < w and l < 0:
		for y in h:
			if d[(y * w + x) * 4 + 3] >= thr:
				l = x
				break
		x += 1
	if l < 0:
		return [-1, -1, -1, -1]
	var r := -1
	x = w - 1
	while x >= 0 and r < 0:
		for y in h:
			if d[(y * w + x) * 4 + 3] >= thr:
				r = x
				break
		x -= 1
	var top := -1
	var y2 := 0
	while y2 < h and top < 0:
		for xx in w:
			if d[(y2 * w + xx) * 4 + 3] >= thr:
				top = y2
				break
		y2 += 1
	var bot := -1
	y2 = h - 1
	while y2 >= 0 and bot < 0:
		for xx in w:
			if d[(y2 * w + xx) * 4 + 3] >= thr:
				bot = y2
				break
		y2 -= 1
	return [l, r, top, bot]


func _alpha_at(im: Image, d: PackedByteArray, x: float, y: float) -> int:
	var xi := roundi(x)
	var yi := roundi(y)
	if xi < 0 or yi < 0 or xi >= im.get_width() or yi >= im.get_height():
		return -1
	return d[(yi * im.get_width() + xi) * 4 + 3]


## alpha under the four footprint corners (moved `inset` tiles towards the centre) projected from the pivot; rect = [xmin, zmin, xmax, zmax] in tiles around the pivot
func _corner_alphas(im: Image, pivot: Array, rect: Array, inset: float) -> Array:
	var d := im.get_data()
	var x0 := float(rect[0])
	var z0 := float(rect[1])
	var x1 := float(rect[2])
	var z1 := float(rect[3])
	var out: Array = []
	for c in [Vector2(x0 + inset, z0 + inset), Vector2(x1 - inset, z0 + inset), Vector2(x1 - inset, z1 - inset), Vector2(x0 + inset, z1 - inset)]:
		out.append(_alpha_at(im, d, float(pivot[0]) + HW * (c.x - c.y), float(pivot[1]) + HH * (c.x + c.y)))
	return out


## median over the columns of the footprint's right-front base edge (the x = xmax face, bottom corner to right corner) of: lowest opaque row minus the predicted ground line
func _base_edge_residual(im: Image, pivot: Array, rect: Array) -> float:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	var px := float(pivot[0])
	var py := float(pivot[1])
	var x1 := float(rect[2])
	var z0 := float(rect[1])
	var res: Array[float] = []
	for x in range(int(px + HW * x1 + 16.0), int(px + HW * (x1 - z0) - 16.0)):
		if x < 0 or x >= w:
			continue
		var y := h - 1
		while y >= 0 and d[(y * w + x) * 4 + 3] < 32:
			y -= 1
		if y >= 0:
			res.append(float(y) - (py + HH * x1 - HH * (float(x) - px - HW * x1) / HW))
	if res.is_empty():
		return 9999.0
	res.sort()
	return res[res.size() / 2]


## the y-sort key point of a footprint rect [xmin, zmin, xmax, zmax]: left-front corner when the footprint is at least as wide as deep, else the right-back corner (bake_lib.ysort_px)
func _ysort_of(rect: Array) -> Vector2:
	var x0 := float(rect[0])
	var z0 := float(rect[1])
	var x1 := float(rect[2])
	var z1 := float(rect[3])
	var kx := x1
	var kz := z0
	if (x1 - x0) >= (z1 - z0):
		kx = x0
		kz = z1
	return Vector2(HW * (kx - kz), HH * (kx + kz))


func _ysort_ok(have: Array, rect: Array) -> bool:
	var want := _ysort_of(rect)
	return have.size() == 2 and absf(float(have[0]) - want.x) <= 0.2 and absf(float(have[1]) - want.y) <= 0.2


## Every baked sprite must stand where its footprint is.  floor / rug pieces carry the contact shadow of the footprint diamond, so (relative to the pivot): the four footprint corners
## (inset 0.3 tile) are covered, the lowest opaque row sits at the front corner (py + HH x (fx + fz) / 2, measured -13 .. -2 px), the left / right extents reach the side corners
## (measured -3 .. +29 / -26 .. +2 px); tabletop pieces have ONE contact ellipse of fixed size (13 px below the pivot, -17 / +18 px left / right); wall and ceiling pieces have the pivot BELOW
## the sprite on its vertical centre line.  A shifted pivot (the review moved one by 30 px) or a wrong y-sort key (+60 px) fails here, and still passed "pivot inside the image".
func _furniture_anchors(fj: Dictionary) -> void:
	var bad: Array[String] = []
	var n := 0
	for id in fj:
		var e: Dictionary = fj[id]
		var layer := str(e.get("layer"))
		var rot: Dictionary = e.get("rot", {})
		for k in rot:
			var ent: Dictionary = rot[k]
			var im := _img(FURN_DIR.path_join(String(ent.get("file", "x"))))
			if im == null:
				continue                                 # furniture_files reports a missing file
			n += 1
			var ex := _extent(im, 24)
			var px := float(ent["pivot"][0])
			var py := float(ent["pivot"][1])
			var fx := float(ent["footprint"][0])
			var fz := float(ent["footprint"][1])
			var tag := "%s r%s" % [id, k]
			if ex[0] < 0:
				bad.append("%s: empty sprite" % tag)
				continue
			if layer == "floor" or layer == "rug":
				var rect := [-fx / 2.0, -fz / 2.0, fx / 2.0, fz / 2.0]
				var half := fx / 2.0 + fz / 2.0
				var cor := _corner_alphas(im, ent["pivot"], rect, 0.3)
				var low: float = float(ex[3]) - (py + HH * half)
				var lef: float = float(ex[0]) - (px - HW * half)
				var rig: float = float(ex[1]) - (px + HW * half)
				if int(cor.min()) < 16 or low < -18.0 or low > 3.0 or lef < -8.0 or lef > 34.0 or rig < -34.0 or rig > 7.0:
					bad.append("%s: corner alphas %s, lowest row %+.0f, left %+.0f, right %+.0f px against the footprint" % [tag, cor, low, lef, rig])
				if layer == "floor" and not _ysort_ok(ent.get("ysort", []), rect):
					bad.append("%s: ysort %s is not the key corner %s of the footprint" % [tag, ent.get("ysort"), _ysort_of(rect)])
			elif layer == "tabletop":
				var dl: float = float(ex[3]) - py
				var dx0: float = float(ex[0]) - px
				var dx1: float = float(ex[1]) - px
				if dl < 8.0 or dl > 18.0 or dx0 < -22.0 or dx0 > -12.0 or dx1 < 13.0 or dx1 > 23.0:
					bad.append("%s: tabletop contact ellipse at %+.0f below, %+.0f left, %+.0f right of the pivot" % [tag, dl, dx0, dx1])
			else:
				var gap: float = py - float(ex[3])
				var cx: float = (float(ex[0]) + float(ex[1])) / 2.0 - px
				var lo := 30.0 if layer == "wall" else 105.0
				var hi := 125.0 if layer == "wall" else 145.0
				if gap < lo or gap > hi or absf(cx) > 16.0:
					bad.append("%s: %s piece, ground point %.0f px below the sprite, centre line off by %+.1f" % [tag, layer, gap, cx])
	_t.check("furniture_ground_contact", n > 0 and bad.is_empty(), "%d sprites; %s" % [n, str(bad.slice(0, 4))])


# ---------------------------------------------------------------- symmetry classes are MEASURED, float layers belong to the legendary pieces

func _equal_views(p: Array) -> bool:
	return float(p[0]) < SYM_ERR_MAX and float(p[1]) < SYM_SIL_MAX


## the measured class from the three pair measurements of specs/symmetry_measured.json (the rule of measure_symmetry.classify)
func _sym_class(declared: String, pairs: Dictionary) -> String:
	if declared == "c4" and _equal_views(pairs["r0_r1"]) and _equal_views(pairs["r0_r2"]):
		return "c4"
	if _equal_views(pairs["r0_r2"]) and _equal_views(pairs["r1_r3"]):
		return "c2"
	return "none"


## silhouette mismatch in percent (xor of alpha > 128 over the union) of two sprites aligned by their pivots
func _sil_mismatch(ea: Dictionary, eb: Dictionary) -> float:
	var ia := _img(FURN_DIR.path_join(String(ea["file"])))
	var ib := _img(FURN_DIR.path_join(String(eb["file"])))
	if ia == null or ib == null:
		return 0.0
	var pax := int(ea["pivot"][0])
	var pay := int(ea["pivot"][1])
	var pbx := int(eb["pivot"][0])
	var pby := int(eb["pivot"][1])
	var wa := ia.get_width()
	var ha := ia.get_height()
	var wb := ib.get_width()
	var hb := ib.get_height()
	var da := ia.get_data()
	var db := ib.get_data()
	var uni := 0
	var xor_n := 0
	for ry in range(mini(-pay, -pby), maxi(ha - pay, hb - pby)):
		var ya := ry + pay
		var yb := ry + pby
		for rx in range(mini(-pax, -pbx), maxi(wa - pax, wb - pbx)):
			var xa := rx + pax
			var xb := rx + pbx
			var aa := false
			var ab := false
			if ya >= 0 and ya < ha and xa >= 0 and xa < wa:
				aa = da[(ya * wa + xa) * 4 + 3] > 128
			if yb >= 0 and yb < hb and xb >= 0 and xb < wb:
				ab = db[(yb * wb + xb) * 4 + 3] > 128
			if aa or ab:
				uni += 1
				if aa != ab:
					xor_n += 1
	return 100.0 * float(xor_n) / float(maxi(uni, 1))


func _symmetry_and_floats(fj: Dictionary) -> void:
	var t = _t
	if _painted_furniture():
		var painted_bad: Array[String] = []
		for id in fj:
			var entry: Dictionary = fj[id]
			var wall := str(entry["layer"]) == "wall"
			var expected := 2 if wall else 4
			if str(entry["sym"]) != ("wall2" if wall else "none") or (entry["rot"] as Dictionary).size() != expected:
				painted_bad.append("%s: painted object needs %d authored views" % [id, expected])
			for k in expected:
				if int(entry["rot_map"][k][0]) != k or bool(entry["rot_map"][k][1]):
					painted_bad.append("%s r%d: must use its own painted view without flipping" % [id, k])
			if not str(entry.get("illustration", "")).begins_with("tools/art/drawn/sources/"):
				painted_bad.append("%s: missing painted master" % id)
		t.check("symmetry_measured_consistent", fj.size() == 130 and painted_bad.is_empty(),
			"130 painted pieces: no rotational symmetry reduction; all four free-standing/two wall views retained; %s" % str(painted_bad.slice(0, 4)))
	else:
		_legacy_symmetry(fj)
	var fbad: Array[String] = []
	var legendary := 0
	for id in fj:
		var is_leg := str(fj[id].get("rarity")) == "legendary"
		if is_leg:
			legendary += 1
		for k in (fj[id]["rot"] as Dictionary):
			if (fj[id]["rot"][k] as Dictionary).has("float") != is_leg:
				fbad.append("%s r%s: float layer on a %s piece / missing on a legendary one" % [id, k, fj[id].get("rarity")])
	t.check("float_layers_legendary_only", fbad.is_empty() and legendary == 11, "%d legendary pieces carry float layers on every rotation, no other piece has one (README + furniture.json _contract say so); %s" % [legendary, str(fbad.slice(0, 3))])


func _legacy_symmetry(fj: Dictionary) -> void:
	var t = _t
	var doc: Dictionary = _json(SPEC_DIR + "/symmetry_measured.json")
	var items: Dictionary = doc.get("items", {})
	var bad: Array[String] = []
	var extra_views := 0
	var worst := 100.0
	for id in items:
		var m: Dictionary = items[id]
		if not fj.has(id):
			bad.append("%s: not a furniture piece" % id)
			continue
		var cls := _sym_class(String(m["declared"]), m["pairs"])
		if cls != String(m["class"]):
			bad.append("%s: class %s does not follow from its measured pairs (rule gives %s)" % [id, m["class"], cls])
		var sym := str(fj[id].get("sym"))
		if sym != String(m["class"]):
			bad.append("%s: furniture.json sym %s but measured %s" % [id, sym, m["class"]])
			continue
		# a piece that ships MORE views than its template declared must really have different views (re-measured here on the shipped sprites: some pair differs by >= 4 % of the silhouette)
		if cls != String(m["declared"]):
			extra_views += 1
			var rot: Dictionary = fj[id]["rot"]
			var best := 0.0
			for pr in [[0, 1], [0, 2], [1, 3]]:
				if rot.has(str(pr[0])) and rot.has(str(pr[1])):
					best = maxf(best, _sil_mismatch(rot[str(pr[0])], rot[str(pr[1])]))
			worst = minf(worst, best)
			if best < SYM_SIL_MAX:
				bad.append("%s: shipped as %s but its views differ by only %.2f %%" % [id, cls, best])
	for id in fj:
		var sym2 := str(fj[id].get("sym"))
		if (sym2 == "c4" or sym2 == "c2") and not items.has(id):
			bad.append("%s: ships as %s without a measurement" % [id, sym2])
	t.check("symmetry_measured_consistent", items.size() == 41 and extra_views == 15 and bad.is_empty(),
		"%d pieces measured (declared c4 or c2), %d of them ship more views than declared (the weakest differs by %.1f %% of the silhouette); %s" % [items.size(), extra_views, worst, str(bad.slice(0, 4))])


# ---------------------------------------------------------------- mirror fallback list (RV-A5)

func _mirror(spec: Array, fj: Dictionary) -> void:
	var t = _t
	if _painted_furniture():
		var painted_bad: Array[String] = []
		for id in fj:
			var entry: Dictionary = fj[id]
			if bool(entry.get("mirror_ok", true)):
				painted_bad.append("%s: painted grain/embroidery must not use mirror fallback" % id)
			for mapping in entry["rot_map"]:
				if bool(mapping[1]) or not (entry["rot"] as Dictionary).has(str(int(mapping[0]))):
					painted_bad.append("%s: mirrored or missing true view" % id)
		t.check("mirror_ok_measured", fj.size() == 130 and painted_bad.is_empty(), "130 painted objects retain their authored views, no mirror fallback; %s" % str(painted_bad.slice(0, 4)))
		return
	var doc: Dictionary = _json(SPEC_DIR + "/mirror_ok.json")
	var ids: Array = doc.get("mirror_ok", [])
	var by_id := {}
	for it in spec:
		by_id[String(it["id"])] = it
	var bad: Array[String] = []
	var worst_mean := 0.0
	var worst_sil := 0.0
	for id in ids:
		var it: Dictionary = by_id.get(String(id), {})
		if it.is_empty() or not fj.has(String(id)):
			bad.append("%s: not a spec item" % id)
			continue
		if ["unique", "legendary"].has(str(it["rarity"])):
			bad.append("%s: keepsake (%s) must never mirror" % [id, it["rarity"]])
		var fabric := String((it["style"] as Dictionary).get("fabric", "natur"))
		if PATTERNED.has(String(FABRIC_PATTERN.get(fabric, "weave"))):
			bad.append("%s: patterned fabric %s" % [id, fabric])
		var e: Dictionary = fj[String(id)]
		if str(e.get("sym")) != "none":
			bad.append("%s: symmetric piece (needs no mirror)" % id)
			continue
		var a := _mirror_pair(e, 0, 1)
		var b := _mirror_pair(e, 2, 3)
		worst_mean = maxf(worst_mean, maxf(a.x, b.x))
		worst_sil = maxf(worst_sil, maxf(a.y, b.y))
		if maxf(a.x, b.x) >= 8.0 or maxf(a.y, b.y) >= 1.0:
			bad.append("%s: mean error %.1f/%.1f, silhouette mismatch %.2f/%.2f %%" % [id, a.x, b.x, a.y, b.y])
	t.check("mirror_ok_measured", not ids.is_empty() and bad.is_empty(), "%d ids re-measured (worst mean error %.2f/255, worst silhouette mismatch %.2f %%); %s" % [ids.size(), worst_mean, worst_sil, str(bad.slice(0, 4))])


## (mean RGB error on the 0..255 scale over pixels opaque in both, silhouette mismatch in percent) of flip_h(r<ra>) against the true r<rb>
func _mirror_pair(e: Dictionary, ra: int, rb: int) -> Vector2:
	var ea: Dictionary = e["rot"][str(ra)]
	var eb: Dictionary = e["rot"][str(rb)]
	var ia := _img(FURN_DIR.path_join(String(ea["file"])))
	var ib := _img(FURN_DIR.path_join(String(eb["file"])))
	if ia == null or ib == null:
		return Vector2(255.0, 100.0)
	var a := ia.duplicate() as Image
	a.flip_x()
	var wa := a.get_width()
	var ha := a.get_height()
	var wb := ib.get_width()
	var hb := ib.get_height()
	var pax := wa - int(ea["pivot"][0])           # the pivot of a mirrored image: width - px (as measure_mirror.py, PIL ImageOps.mirror)
	var pay := int(ea["pivot"][1])
	var pbx := int(eb["pivot"][0])
	var pby := int(eb["pivot"][1])
	var x0 := mini(-pax, -pbx)
	var x1 := maxi(wa - pax, wb - pbx)
	var y0 := mini(-pay, -pby)
	var y1 := maxi(ha - pay, hb - pby)
	var da := a.get_data()
	var db := ib.get_data()
	var sum := 0.0
	var both := 0
	var uni := 0
	var xor_n := 0
	for ry in range(y0, y1):
		var ya := ry + pay
		var yb := ry + pby
		var ra_ok := ya >= 0 and ya < ha
		var rb_ok := yb >= 0 and yb < hb
		if not ra_ok and not rb_ok:
			continue
		for rx in range(x0, x1):
			var xa := rx + pax
			var xb := rx + pbx
			var aa := 0
			var ab := 0
			var ia_i := 0
			var ib_i := 0
			if ra_ok and xa >= 0 and xa < wa:
				ia_i = (ya * wa + xa) * 4
				aa = da[ia_i + 3]
			if rb_ok and xb >= 0 and xb < wb:
				ib_i = (yb * wb + xb) * 4
				ab = db[ib_i + 3]
			if aa > 128 or ab > 128:
				uni += 1
				if (aa > 128) != (ab > 128):
					xor_n += 1
			if aa > 200 and ab > 200:
				both += 1
				sum += float(absi(int(da[ia_i]) - int(db[ib_i])) + absi(int(da[ia_i + 1]) - int(db[ib_i + 1])) + absi(int(da[ia_i + 2]) - int(db[ib_i + 2]))) / 3.0
	return Vector2(sum / float(maxi(both, 1)), 100.0 * float(xor_n) / float(maxi(uni, 1)))


# ---------------------------------------------------------------- icons

func _icons(spec: Array, contract: Dictionary) -> void:
	var t = _t
	var ids: Array = []
	for it in spec:
		ids.append(String(it["id"]))
	var materials: Array = contract.get("materials", [])
	for m in materials:
		ids.append(String(m))
	var missing: Array[String] = []
	var badfmt: Array[String] = []
	var worst_ring := 0.0
	var min_fill := 1.0
	var max_fill := 0.0
	var bad_ring: Array[String] = []
	var bad_fill: Array[String] = []
	for id in ids:
		var im := _img(ICON_DIR.path_join("%s.webp" % id))
		if im == null:
			missing.append(id)
			continue
		if im.get_width() != 128 or im.get_height() != 128:
			badfmt.append("%s %dx%d" % [id, im.get_width(), im.get_height()])
			continue
		var r := _ring(im)
		var col: Vector3 = r[0]
		var diff := maxf(absf(col.x - INK.x), maxf(absf(col.y - INK.y), absf(col.z - INK.z)))
		if int(r[1]) == 0 or diff > 24.0:
			bad_ring.append("%s (ring %s, %d px)" % [id, col, r[1]])
		worst_ring = maxf(worst_ring, diff)
		var f := _fill(im)
		min_fill = minf(min_fill, f)
		max_fill = maxf(max_fill, f)
		if f < 0.86 or f > 0.95:
			bad_fill.append("%s fill %.3f" % [id, f])
	t.check("icons_complete", ids.size() == 162 and materials.size() == 32 and missing.is_empty() and badfmt.is_empty(),
		"%d icons expected (130 furniture + 32 material); missing %s; wrong size %s" % [ids.size(), str(missing.slice(0, 5)), str(badfmt.slice(0, 3))])
	t.check("icons_ink_outline", bad_ring.is_empty() and bad_fill.is_empty() and missing.is_empty(),
		"outer ring within 24/255 of 2b2340 (worst %.1f), bbox fill %.3f-%.3f (0.86-0.95); %s %s" % [worst_ring, min_fill, max_fill, str(bad_ring.slice(0, 3)), str(bad_fill.slice(0, 3))])
	# legendary icons get a sibling <id>_night.webp with a pale die-cut rim (RV-A2)
	var legendary: Array[String] = []
	var cf: Dictionary = contract.get("furniture", {})
	for id in cf:
		if str((cf[id] as Dictionary).get("rarity")) == "legendary":
			legendary.append(String(id))
	legendary.sort()
	var probs: Array[String] = []
	var worst := 99.0
	for id in legendary:
		var night := _img(ICON_DIR.path_join("%s_night.webp" % id))
		var base := _img(ICON_DIR.path_join("%s.webp" % id))
		if night == null or base == null:
			probs.append("%s: icon or night variant missing" % id)
			continue
		if night.get_width() != 128 or night.get_height() != 128:
			probs.append("%s_night: wrong size" % id)
			continue
		var base_ring: Vector3 = _ring(base)[0]
		var night_ring: Array = _ring(night)
		var rc: Vector3 = night_ring[0]
		var ink_vs_rim := _contrast(base_ring, RIM)
		var rim_vs_night := _contrast(RIM, NIGHT)
		worst = minf(worst, minf(ink_vs_rim, rim_vs_night))
		if ink_vs_rim < 7.0 or rim_vs_night < 7.0:
			probs.append("%s: contrast ink/rim %.1f, rim/night %.1f" % [id, ink_vs_rim, rim_vs_night])
		if maxf(absf(rc.x - RIM.x), maxf(absf(rc.y - RIM.y), absf(rc.z - RIM.z))) > 24.0 or int(night_ring[1]) == 0:
			probs.append("%s_night: outer ring %s is not the e4eff5 rim" % [id, rc])
		if _border_opaque(night):
			probs.append("%s_night: the rim touches the cell border" % id)
	t.check("icons_night_rim", legendary.size() == 11 and probs.is_empty(),
		"%d legendary ids in the snapshot, worst contrast %.1f (ink vs rim and rim vs night tile, both >= 7); %s" % [legendary.size(), worst, str(probs.slice(0, 3))])


func _border_opaque(im: Image) -> bool:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	for i in w:
		if d[(0 * w + i) * 4 + 3] > 24 or d[((h - 1) * w + i) * 4 + 3] > 24:
			return true
	for j in h:
		if d[(j * w) * 4 + 3] > 24 or d[(j * w + w - 1) * 4 + 3] > 24:
			return true
	return false



# ---------------------------------------------------------------- no two ids look the same (fix round: curtain_natural/curtain_green, fireplace_marble/fireplace_slate, floor_lamp_iron/floor_lamp_birch shipped as twins)

func _sha(im: Image, extra: String = "") -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(im.get_data())
	if extra != "":
		ctx.update(extra.to_utf8_buffer())
	return ctx.finish().hex_encode()


## [mean abs RGB difference over the union of the opaque pixels (every 2nd pixel), silhouette mismatch in percent] of two equally sized RGBA8 images
func _union_diff(a: Image, b: Image) -> Vector2:
	var da := a.get_data()
	var db := b.get_data()
	var w := a.get_width()
	var h := a.get_height()
	var sum := 0.0
	var uni := 0
	var xor_n := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var i := (y * w + x) * 4
			var oa: bool = da[i + 3] > 128
			var ob: bool = db[i + 3] > 128
			if oa or ob:
				uni += 1
				if oa != ob:
					xor_n += 1
				sum += float(absi(int(da[i]) - int(db[i])) + absi(int(da[i + 1]) - int(db[i + 1])) + absi(int(da[i + 2]) - int(db[i + 2]))) / 3.0
	if uni == 0:
		return Vector2.ZERO
	return Vector2(sum / float(uni), 100.0 * float(xor_n) / float(uni))


## Two distinct ids must never share a picture: no identical r0 sprite, no identical icon (all 162), and within a template no pair of r0 sprites / icons that is the same shape in the same colours
## (mean difference below 2/255 over the union; renderer noise makes twins differ by a few levels, so a hash alone is not enough).  The closest legitimate pair is 4.7 (candelabra_copper / brass).
func _distinct_looks(spec: Array, fj: Dictionary, contract: Dictionary) -> void:
	var dup: Array[String] = []
	var seen_s := {}
	var seen_i := {}
	var by_template := {}
	var ids: Array = []
	for it in spec:
		var id := String(it["id"])
		ids.append(id)
		if not by_template.has(String(it["template"])):
			by_template[String(it["template"])] = []
		(by_template[String(it["template"])] as Array).append(id)
		if not fj.has(id):
			continue
		var ent: Dictionary = fj[id]["rot"]["0"]
		var im := _img(FURN_DIR.path_join(String(ent["file"])))
		if im == null:
			continue
		var h := _sha(im, "%d,%d" % [int(ent["pivot"][0]), int(ent["pivot"][1])])
		if seen_s.has(h):
			dup.append("%s == %s (r0 sprite, identical)" % [id, seen_s[h]])
		seen_s[h] = id
	for m in contract.get("materials", []):
		ids.append(String(m))
	for id in ids:
		var ic := _img(ICON_DIR.path_join("%s.webp" % id))
		if ic == null:
			continue
		var h2 := _sha(ic)
		if seen_i.has(h2):
			dup.append("%s == %s (icon, identical)" % [id, seen_i[h2]])
		seen_i[h2] = id
	var closest := 999.0
	var closest_pair := ""
	var pairs := 0
	for tpl in by_template:
		var group: Array = by_template[tpl]
		for i in group.size():
			for j in range(i + 1, group.size()):
				var a := String(group[i])
				var b := String(group[j])
				pairs += 1
				var ia := _img(ICON_DIR.path_join("%s.webp" % a))
				var ib := _img(ICON_DIR.path_join("%s.webp" % b))
				if ia != null and ib != null and ia.get_width() == ib.get_width() and ia.get_height() == ib.get_height():
					var d := _union_diff(ia, ib)
					if d.x < closest:
						closest = d.x
						closest_pair = "icons %s ~ %s" % [a, b]
					if d.x < NEAR_DUP_MEAN and d.y < 1.0:
						dup.append("%s ~ %s (icon, mean difference %.2f/255, silhouette %.2f %%)" % [a, b, d.x, d.y])
				if not fj.has(a) or not fj.has(b):
					continue
				var ea: Dictionary = fj[a]["rot"]["0"]
				var eb: Dictionary = fj[b]["rot"]["0"]
				if ea["size"] == eb["size"] and ea["pivot"] == eb["pivot"]:
					var sa := _img(FURN_DIR.path_join(String(ea["file"])))
					var sb := _img(FURN_DIR.path_join(String(eb["file"])))
					if sa != null and sb != null:
						var d2 := _union_diff(sa, sb)
						if d2.x < closest:
							closest = d2.x
							closest_pair = "sprites %s ~ %s" % [a, b]
						if d2.x < NEAR_DUP_MEAN and d2.y < 1.0:
							dup.append("%s ~ %s (r0 sprite, mean difference %.2f/255, silhouette %.2f %%)" % [a, b, d2.x, d2.y])
	_t.check("furniture_looks_distinct", dup.is_empty() and seen_s.size() == 130 and seen_i.size() == 162,
		"%d r0 sprites and %d icons are pairwise different; %d same-template pairs compared, closest %s at %.1f/255 (near-duplicate limit %.0f); %s" % [seen_s.size(), seen_i.size(), pairs, closest_pair, closest, NEAR_DUP_MEAN, str(dup.slice(0, 4))])


# ---------------------------------------------------------------- houses

func _houses(home_doc: Dictionary, contract: Dictionary, fj: Dictionary) -> void:
	var t = _t
	var tiers: Array = home_doc.get("tiers", [])
	var areas: Array[int] = []
	var heights: Array[int] = []
	var cells: Array[int] = []
	var anchors_ok := true
	var anchor_msgs: Array[String] = []
	var scaffolds := 0
	var night_bad: Array[String] = []
	for tier in tiers:
		var ex: Dictionary = tier["exterior"]
		var tn := int(tier["tier"])
		var day := _img(HOME_DIR.path_join(String(ex["day"])))
		if day == null:
			anchors_ok = false
			anchor_msgs.append("tier %d: day sprite missing" % tn)
			areas.append(0)
			heights.append(0)
			cells.append(0)
			continue
		var w := day.get_width()
		var h := day.get_height()
		var d := day.get_data()
		var n := 0
		var top := h
		var bottom := -1
		for y in h:
			var row := y * w * 4 + 3
			var hit := false
			for x in w:
				if d[row + x * 4] > 128:
					n += 1
					hit = true
			if hit:
				top = mini(top, y)
				bottom = y
		areas.append(n)
		heights.append(bottom - top + 1)
		var fpt: Array = tier["footprint_tiles"]
		cells.append(int(fpt[0]) * int(fpt[1]))
		var r: Array = tier["footprint_rect"]
		var c := int(tier["door_column"])
		# one anchor for every tier: the ground point at the centre of the door on the front plane z = 0 (the door column spans x -0.5 .. +0.5 around it)
		var piv: Array = ex["pivot"]
		var ok := is_equal_approx(float(r[3]), 0.0) and is_equal_approx(float(r[0]), -(c + 0.5)) and is_equal_approx(float(r[2]), float(fpt[0]) - c - 0.5) \
			and is_equal_approx(float(r[1]), -float(fpt[1])) and int(piv[0]) >= 0 and int(piv[0]) < w and int(piv[1]) >= 0 and int(piv[1]) < h \
			and int((ex["size"] as Array)[0]) == w and int((ex["size"] as Array)[1]) == h
		if not ok:
			anchors_ok = false
			anchor_msgs.append("tier %d: rect %s door column %d pivot %s" % [tn, r, c, piv])
		if tn > 1:
			var sc: Dictionary = tier.get("scaffold_from_previous", {})
			if not sc.is_empty() and _img(HOME_DIR.path_join(String(sc["file"]))) != null:
				scaffolds += 1
		else:
			if tier.has("scaffold_from_previous"):
				anchors_ok = false
				anchor_msgs.append("tier 1 has a scaffold")
		# night layer: ADDITIVE (blend add, normalised light colours) and TRIMMED to the bbox of its lights, placed by night_offset / night_size
		var nf := String(ex.get("night", ""))
		var night := _img(HOME_DIR.path_join(nf)) if nf != "" else null
		if night == null:
			night_bad.append("tier %d: no night layer" % tn)
			continue
		var nw := night.get_width()
		var nh := night.get_height()
		var nd := night.get_data()
		var minx := nw
		var miny := nh
		var maxx := -1
		var maxy := -1
		var dim_light := 0
		for y in nh:
			for x in nw:
				var i := (y * nw + x) * 4
				var a: int = nd[i + 3]
				if a > 0:
					minx = mini(minx, x)
					maxx = maxi(maxx, x)
					miny = mini(miny, y)
					maxy = maxi(maxy, y)
				if a >= 48 and maxi(nd[i], maxi(nd[i + 1], nd[i + 2])) < 120:
					dim_light += 1
		var size_ok: bool = (ex.get("night_size", []) as Array).size() == 2 and int(ex["night_size"][0]) == nw and int(ex["night_size"][1]) == nh
		var trimmed := maxx >= 0 and minx <= 1 and miny <= 1 and maxx >= nw - 2 and maxy >= nh - 2
		var off: Array = ex.get("night_offset", [-1, -1])
		var inside: bool = int(off[0]) >= 0 and int(off[1]) >= 0 and int(off[0]) + nw <= w and int(off[1]) + nh <= h
		if not (size_ok and trimmed and inside and String(ex.get("night_blend", "")) == "add" and dim_light == 0):
			night_bad.append("tier %d: night layer size_ok=%s trimmed=%s inside=%s blend=%s dim-light-pixels=%d" % [tn, size_ok, trimmed, inside, ex.get("night_blend"), dim_light])
	t.check("tier_anchor_identical", tiers.size() == 10 and anchors_ok, "10 tiers share the door-centre anchor (rect front edge z = 0, door column around x = 0); %s" % str(anchor_msgs.slice(0, 3)))
	var mass_ok := areas.size() == 10
	for i in range(1, areas.size()):
		mass_ok = mass_ok and areas[i] > areas[i - 1] and cells[i] > cells[i - 1]
	t.check("house_mass_monotonic", mass_ok, "opaque px %s, footprint tiles %s (each tier strictly larger than the one before)" % [str(areas), str(cells)])
	var height_ok := heights.size() == 10
	for i in range(1, heights.size()):
		height_ok = height_ok and heights[i] > heights[i - 1]
	t.check("house_height_monotonic", height_ok, "roofline heights %s (opaque px; tier n+1 above tier n)" % str(heights))
	t.check("night_layers_additive_trimmed", night_bad.is_empty() and tiers.size() == 10, str(night_bad.slice(0, 3)))
	t.check("scaffolds_nine", scaffolds == 9, "%d scaffold sprites for tiers 2..10, none for tier 1" % scaffolds)
	# the gift items of the tiers must have furniture sprites (snapshot vs furniture.json)
	var gifts_ok := true
	for c in contract.get("tiers", []):
		for g in (c as Dictionary).get("gift_items", []):
			gifts_ok = gifts_ok and fj.has(String(g))
	t.check("tier_gift_items_have_sprites", gifts_ok, "every gift_items id of the snapshot is a furniture piece")



## The house anchor on PIXELS: the ground point at the door centre must be where the footprint is.  Per tier: the four footprint corners (inset 0.25) are opaque, the base of the
## right-front wall (x = xmax face) runs along the projected ground line (median residual 3.4 .. 10.1 px measured, the review shifted a pivot by 45 px = 26 px here), the lowest row and
## the side extents reach the footprint corners; the y-sort key is the footprint's key corner.  Scaffolds are drawn around the NEW footprint at the same anchor: same y-sort key as the
## house of that tier and a frame at a constant distance from the footprint corners in all nine (left 120, right 91, bottom 80-87 px), so a scaffold pivot cannot drift alone.
func _house_pixels(home_doc: Dictionary) -> void:
	var tiers: Array = home_doc.get("tiers", [])
	var hbad: Array[String] = []
	var sbad: Array[String] = []
	var fl: Array[float] = []
	var fr: Array[float] = []
	var fb: Array[float] = []
	var n := 0
	for tier in tiers:
		var ex: Dictionary = tier["exterior"]
		var rect: Array = tier["footprint_rect"]
		var tn := int(tier["tier"])
		var day := _img(HOME_DIR.path_join(String(ex["day"])))
		if day == null:
			continue
		n += 1
		var piv: Array = ex["pivot"]
		var x0 := float(rect[0])
		var z0 := float(rect[1])
		var x1 := float(rect[2])
		var z1 := float(rect[3])
		var e := _extent(day, 32)
		var cor := _corner_alphas(day, piv, rect, 0.25)
		var lft: float = (float(piv[0]) + HW * x0) - float(e[0])
		var rgt: float = float(e[1]) - (float(piv[0]) + HW * (x1 - z0))
		var bot: float = float(e[3]) - (float(piv[1]) + HH * (x1 + z1))
		var med := _base_edge_residual(day, piv, rect)
		if int(cor.min()) < 200 or med < -3.0 or med > 17.0 or bot < -20.0 or bot > 50.0 or lft < -20.0 or lft > 70.0 or rgt < -20.0 or rgt > 70.0:
			hbad.append("tier %d: corner alphas %s, base-edge residual %.1f, lowest row %+.0f, left %+.0f, right %+.0f px against the footprint" % [tn, cor, med, bot, lft, rgt])
		if not _ysort_ok(ex.get("ysort", []), rect):
			hbad.append("tier %d: ysort %s is not the key corner %s of the footprint" % [tn, ex.get("ysort"), _ysort_of(rect)])
		var sc: Dictionary = tier.get("scaffold_from_previous", {})
		if sc.is_empty():
			continue
		var sim := _img(HOME_DIR.path_join(String(sc["file"])))
		if sim == null:
			continue
		var spv: Array = sc["pivot"]
		var se := _extent(sim, 32)
		var scor := _corner_alphas(sim, spv, rect, 0.25)
		var l2: float = (float(spv[0]) + HW * x0) - float(se[0])
		var r2: float = float(se[1]) - (float(spv[0]) + HW * (x1 - z0))
		var b2: float = float(se[3]) - (float(spv[1]) + HH * (x1 + z1))
		fl.append(l2)
		fr.append(r2)
		fb.append(b2)
		var same_key: bool = (sc.get("ysort", []) as Array).size() == 2 and absf(float(sc["ysort"][0]) - float(ex["ysort"][0])) <= 0.2 and absf(float(sc["ysort"][1]) - float(ex["ysort"][1])) <= 0.2
		if not same_key or int(scor.min()) < 200 or l2 < 112.0 or l2 > 128.0 or r2 < 83.0 or r2 > 99.0 or b2 < 74.0 or b2 > 96.0:
			sbad.append("scaffold to tier %d: ysort %s vs house %s, corner alphas %s, frame left %.0f right %.0f bottom %.0f px" % [tn, sc.get("ysort"), ex["ysort"], scor, l2, r2, b2])
	if fl.size() == 9 and (fl.max() - fl.min() > 4.0 or fr.max() - fr.min() > 4.0 or fb.max() - fb.min() > 10.0):
		sbad.append("scaffold frames are not at one distance from their footprints: left %s right %s bottom %s" % [str(fl), str(fr), str(fb)])
	_t.check("house_ground_contact", n == 10 and hbad.is_empty(), "10 houses: footprint corners opaque, wall base on the projected ground line, extents reach the corners, y-sort = key corner; %s" % str(hbad.slice(0, 3)))
	_t.check("scaffold_anchor_matches_tier", fl.size() == 9 and sbad.is_empty(), "9 scaffolds: y-sort key = the house of the same tier, frame at a constant distance from the footprint corners; %s" % str(sbad.slice(0, 3)))


# ---------------------------------------------------------------- rooms, platform stages, floors: the contract against the snapshot

func _rooms_and_floors(home_doc: Dictionary, contract: Dictionary) -> void:
	var t = _t
	var tiers: Array = home_doc.get("tiers", [])
	var ctiers: Array = contract.get("tiers", [])
	var stages: Dictionary = home_doc.get("platform_stages", {})
	var bad: Array[String] = []
	var wbad: Array[String] = []
	var caps: Array[int] = []
	var rows_back: Array[int] = []
	for i in mini(tiers.size(), ctiers.size()):
		var tier: Dictionary = tiers[i]
		var c: Dictionary = ctiers[i]
		var tn := int(tier["tier"])
		var room: Dictionary = _json(ROOM_DIR.path_join("room_t%02d.json" % tn))
		if room.is_empty():
			bad.append("room_t%02d.json missing" % tn)
			continue
		caps.append(int(room["max_furniture"]))
		var back := int((tier["platform"] as Dictionary)["back_rows"])
		rows_back.append(back)
		var stage_rows := int((stages.get(str(int((tier["platform"] as Dictionary)["stage"])), {}) as Dictionary).get("back_rows", -1))
		if back != int(c["platform_back_rows"]) or stage_rows != int(c["platform_back_rows"]):
			bad.append("tier %d: platform back_rows %d / stage %d, snapshot %d" % [tn, back, stage_rows, int(c["platform_back_rows"])])
		if int(room["max_furniture"]) != int(c["capacity"]) or str(room["floor"]) != str(c["floor"]) or str(room["wall_style"]) != str(c["walls"]):
			bad.append("tier %d: room capacity/floor/wall_style %s/%s/%s vs snapshot %s/%s/%s" % [tn, room["max_furniture"], room["floor"], room["wall_style"], c["capacity"], c["floor"], c["walls"]])
		var ir: Dictionary = tier["interior"]
		if str(ir["floor"]) != str(c["floor"]) or str(ir["wall_style"]) != str(c["walls"]) or int(ir["max_furniture"]) != int(c["capacity"]):
			bad.append("tier %d: home.json interior block differs from the snapshot" % tn)
		var rows: Array = room["rows"]
		var widest := 0
		for r in rows:
			widest = maxi(widest, int(r))
		var n := widest + rows.size()
		var zf := snappedf(0.85 * minf(1280.0 / (n * 64.0), 720.0 / (n * 38.0 + 280.0)), 0.01)
		if absf(float(room["zoom_fit"]) - zf) > 0.005:
			bad.append("tier %d: zoom_fit %s, formula %s" % [tn, room["zoom_fit"], zf])
		var ex: Dictionary = tier["exterior"]
		if String(ex["day"]).get_basename() != String(c["exterior"]) or String(ex["night"]).get_basename() != String(c["night"]) or String(room.get("floor", "")) == "":
			bad.append("tier %d: exterior file names differ from the snapshot" % tn)
		var scaf: Variant = c.get("scaffold")
		var sfp: Dictionary = tier.get("scaffold_from_previous", {})
		if (scaf == null) != sfp.is_empty() or (scaf != null and String(sfp.get("file", "")).get_basename() != String(scaf)):
			bad.append("tier %d: scaffold name differs from the snapshot" % tn)
		for k in ["rows", "cells", "door", "spawn_cell", "windows"]:
			if not room.has(k):
				bad.append("room_t%02d.json: field %s missing" % [tn, k])
		# windows: KEYS NAMED BY THE WALL, VALUES ARE THE OTHER AXIS (windows.z = x indices on the z = 0 back-right wall, windows.x = z indices on the x = 0 back-left wall); numbers arrive as floats
		var w: Dictionary = room.get("windows", {})
		var wb: Dictionary = room.get("windows_by_wall", {})
		var wz: Array = w.get("z", [])
		var wx: Array = w.get("x", [])
		var nz := (room["rows"] as Array).size()
		var width0 := int((room["rows"] as Array)[0])
		var wok: bool = not wz.is_empty() and not wx.is_empty() and wb.get("back_right_z0", []) == wz and wb.get("back_left_x0", []) == wx
		for v in wz:
			wok = wok and is_equal_approx(float(v), roundf(float(v))) and int(v) > 0 and int(v) < width0 - 1
		for v in wx:
			wok = wok and is_equal_approx(float(v), roundf(float(v))) and int(v) > 0 and int(v) < nz - 1
		if not wok or str((room.get("_contract", {}) as Dictionary).get("windows", "")) == "":
			wbad.append("room_t%02d.json: windows z %s (x indices, 0 < v < %d), x %s (z indices, 0 < v < %d), by wall %s, _contract.windows %s" % [tn, wz, width0 - 1, wx, nz - 1, wb, (room.get("_contract", {}) as Dictionary).has("windows")])
	t.check("room_windows_contract", wbad.is_empty() and caps.size() == 10, "10 rooms: windows.z = x indices on the z = 0 wall, windows.x = z indices on the x = 0 wall, windows_by_wall repeats them under unambiguous names, whole numbers (they arrive as floats: compare with int()), _contract documents it; %s" % str(wbad.slice(0, 2)))
	t.check("contract_matches_snapshot", bad.is_empty() and caps == [11, 16, 19, 26, 30, 38, 46, 57, 65, 74] and rows_back == [0, 0, 0, 0, 1, 1, 1, 2, 2, 3],
		"max_furniture %s, platform back_rows %s, zoom_fit by formula; %s" % [str(caps), str(rows_back), str(bad.slice(0, 3))])
	# floors: periodic 4x4 atlas of 144x84 cells, imported WITHOUT mipmaps (a stub next to each png)
	var fbad: Array[String] = []
	var tj: Dictionary = _json(TILE_DIR + "/tiles_floors.json")
	for n in ["stone", "plank", "parquet", "marble"]:
		var png := TILE_DIR + "/floor_%s.png" % n
		var im := _img(png)
		if im == null or im.get_width() != 576 or im.get_height() != 336:
			fbad.append("floor_%s.png missing or not 576x336" % n)
		var imp := png + ".import"
		var txt := FileAccess.get_file_as_string(imp) if FileAccess.file_exists(imp) else ""
		if not txt.contains("mipmaps/generate=false") or not txt.contains("compress/mode=0"):
			fbad.append("floor_%s.png.import is not a lossless no-mipmap preset" % n)
		if not tj.has("floor_%s" % n):
			fbad.append("tiles_floors.json lacks floor_%s" % n)
	t.check("floors_no_mipmaps", fbad.is_empty(), str(fbad.slice(0, 3)))


# ---------------------------------------------------------------- interior pieces

func _interior() -> void:
	var t = _t
	var ij: Dictionary = _json(INTERIOR_DIR + "/interior.json")
	var bad: Array[String] = []
	var n := 0
	for grp in ["walls", "door"]:
		for k in (ij.get(grp, {}) as Dictionary):
			var m: Dictionary = ij[grp][k]
			var im := _img(INTERIOR_DIR.path_join(String(m["file"])))
			n += 1
			if im == null:
				bad.append("%s: file missing" % k)
				continue
			var pv: Array = m["pivot"]
			if int(pv[0]) < 0 or int(pv[0]) >= im.get_width() or int(pv[1]) < 0 or int(pv[1]) >= im.get_height() + 0:
				bad.append("%s: pivot %s outside %dx%d" % [k, pv, im.get_width(), im.get_height()])
			if m.has("night") and _img(INTERIOR_DIR.path_join(String(m["night"]))) == null:
				bad.append("%s: night layer missing" % k)
	var glow := _img("res://assets/iso_props/fx/glow_soft.webp")
	t.check("interior_pieces", n == 24 and bad.is_empty() and glow != null and glow.get_width() == 256,
		"%d wall/corner/door pieces (3 styles x [plain, pilaster, window] x 2 yaws + 3 corner posts + doormat x 2 + door post), glow_soft.webp %s; %s" % [n, glow != null, str(bad.slice(0, 3))])


# ---------------------------------------------------------------- the nine new props

func _props() -> void:
	var t = _t
	var pj: Dictionary = _json(FEATURES_DIR + "/props.json")
	var bad: Array[String] = []
	var lua := FileAccess.get_file_as_string(PROPS_LUA) if FileAccess.file_exists(PROPS_LUA) else ""
	if not lua.contains('kind = "config"') or not lua.contains("props_features = {"):
		bad.append("lua/config/props_features.lua is missing or not a config file with props_features")
	for id in NEW_PROPS:
		if not pj.has(id):
			bad.append("%s not in props.json" % id)
			continue
		var m: Dictionary = pj[id]
		var im := _img(FEATURES_DIR.path_join(String(m["file"])))
		if im == null:
			bad.append("%s: sprite missing" % id)
			continue
		var pv: Array = m["pivot"]
		if int(pv[0]) < 0 or int(pv[0]) >= im.get_width() or int(pv[1]) < 0 or int(pv[1]) >= im.get_height():
			bad.append("%s: pivot outside the image" % id)
		if (m["size"] as Array)[0] != im.get_width() or (m["size"] as Array)[1] != im.get_height():
			bad.append("%s: size differs from the image" % id)
		var fp: Array = m["footprint"]
		if fp.size() != 2 or int(fp[0]) < 1 or int(fp[1]) < 1:
			bad.append("%s: bad footprint" % id)
		if m.has("glow") and _img(FEATURES_DIR.path_join(String(m["glow"]["file"]))) == null:
			bad.append("%s: glow file missing" % id)
		if ["dig_glimmer", "unique_glimmer"].has(id) and String(m.get("blend", "")) != "add":
			bad.append("%s: an additive soft sprite must say blend add" % id)
		# the gameplay entry: footprint + solid shape + interact type, equal footprint
		var rx := RegEx.new()
		rx.compile("(?m)^\\s*%s = \\{ art = \"%s\", footprint = \\{ (\\d+), (\\d+) \\}.*solid = \\{.*interact = \"(\\w+)\"" % [id, id])
		var hit := rx.search(lua)
		if hit == null:
			bad.append("%s: no entry (art, footprint, solid, interact) in props_features.lua" % id)
		elif int(hit.get_string(1)) != int(fp[0]) or int(hit.get_string(2)) != int(fp[1]):
			bad.append("%s: Lua footprint differs from props.json" % id)
	var extra: Array[String] = []
	for k in pj:
		if not String(k).begins_with("_") and not NEW_PROPS.has(String(k)):
			extra.append(String(k))
	t.check("props_manifest", bad.is_empty() and extra.is_empty(), "nine props in props.json + lua/config/props_features.lua; %s %s" % [str(bad.slice(0, 4)), str(extra)])


# ---------------------------------------------------------------- bytes

func _bytes(dir: String) -> int:
	var total := 0
	var da := DirAccess.open(dir)
	if da == null:
		return 0
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		var p := dir.path_join(name)
		if da.current_is_dir():
			total += _bytes(p)
		elif not name.ends_with(".import") and not name.ends_with(".uid"):
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null:
				total += int(f.get_length())
		name = da.get_next()
	da.list_dir_end()
	return total


func _budget() -> void:
	var total := 0
	for d in ["res://assets/iso_props/home", "res://assets/iso_props/furniture", "res://assets/iso_props/interior", "res://assets/iso_props/fx", "res://assets/iso_props/features", "res://assets/icons/home", "res://assets/data/home"]:
		total += _bytes(d)
	for n in ["stone", "plank", "parquet", "marble"]:
		var f := FileAccess.open(TILE_DIR + "/floor_%s.png" % n, FileAccess.READ)
		if f != null:
			total += int(f.get_length())
	_t.check("byte_budget", total > 0 and total <= BUDGET_BYTES, "%.2f MB on disk (budget %.0f MB; the plan's estimate is about 9.2 MB)" % [total / 1e6, BUDGET_BYTES / 1e6])


# ---------------------------------------------------------------- README verdict (task 8) and the roofline statement (task 9)

func _readme() -> void:
	var txt := FileAccess.get_file_as_string(README) if FileAccess.file_exists(README) else ""
	var verdict := txt.contains("## Verdict") and txt.contains("accepted on") and txt.to_lower().contains("known weaknesses")
	var sheets := true
	for s in ["tiers_contact_sheet", "tiers_strip_night", "interior_wall_pieces", "material_icons", "furniture_icons_130", "legendary_icons_on_night", "props", "ladder_"]:
		sheets = sheets and txt.contains(s)
	_t.check("readme_verdict", verdict and sheets, "README.md has the human verdict (accepted on <date>, known weaknesses) and names every contact sheet of task 8")
	# the fix round of the independent review: what the README must say (so the consumers F3 / F6 read it)
	var fixed := txt.contains("small-decor ladders were checked for duplicates") and txt.contains("symmetry_measured.json") and txt.contains("windows_by_wall") and txt.contains("legendary pieces only") \
		and txt.contains("back_right_z0") and txt.contains("int(")
	_t.check("readme_fix_round", fixed, "README states: small-decor ladders checked for duplicates, symmetry measured (symmetry_measured.json), room windows key contract (windows_by_wall, int()), float layers on legendary pieces only")
	var roofline := txt.contains("roofline")
	_t.check("readme_states_roofline", roofline and (txt.contains("dip") or txt.contains("monotonic")), "README states what became of the roofline heights at tiers 7 and 9 (RV-A9)")
