extends RefCounted
## Section art_city (package V5-art-city, M1a stage 2): the art of Traetoppen, the levelled treetop city - platform discs, tileable trunks, round huts with additive
## night layers, pennants, lanterns, the procedural-bridge tiles, the landmark set dressing, the front foliage, the canopy frame and the treetop backdrop - as shipped in
## res://assets/iso_props/city/ and res://assets/backdrops/treetop_*.webp against the work order and the city data of V3 (data/traetoppen/traetoppen.json, lua/config/traetoppen.lua).
## The ids and geometry are V5's (city/props.json); the files checked are the ones the game draws, i.e. the effective art of the pack that wins in ArtCatalog
## (CityData.city_props(): most of the set ships from painted_world, the pennants from the painted consistency pass, the fire and the soft shadow from city/).
## Superseded copies are not kept (review REND-10), so every check below reads the shipped file.
##
## Headless (independent of the Python validator tools/art/environment/city/validate_city.py, which implements the same checks a second time):
##   inputs_present  sizes_match_json  props_manifest_sane  discs_ellipse_planks_no_hole  trunk_tiles_seamless_pixels  huts_have_night_layers  night_layers_additive
##   bridge_parts_tile_seamlessly  landmark_props_exist  every_city_json_prop_has_art  backdrop_loads_through_artcatalog  no_lossy_webp  vram_budget  sizes_scale_with_k
##   foliage_alpha_baked  readme_verdict
## Windowed (tests/run_playtest.sh --windowed --only=art_city): tileable_trunk_seam (the REAL engine, Sprite2D region + repeat, for all four widths), bridge_line2d_orientation,
##   plus the screenshots the package is judged by (pieces on grass at zoom 0.4 and 0.2, one platform assembled in the engine, the same at night with the additive layers).
##
## SKIP lines name the package that owns what is missing (V4 asserts the join of the city map with these ids; the city map itself is not read here).
const SECTION := "art_city"
const TIMEOUT_S := 300.0

const DIR := "res://assets/iso_props/city/"
const BACKDROP_DIR := "res://assets/backdrops/"
const CITY_JSON := "res://data/traetoppen/traetoppen.json"
const README := "res://tools/art/environment/city/README.md"
const TOL := 2                                  # px: the work order's size tolerance
const K_REF := 3.0                              # the scale the table is written for
const BUDGET_MB := 70.0
const SIDE_LIMIT := 2048
## the 4 widths of trunk bark, the 4 discs, the roof colours of the huts
const BARKS: Array[int] = [367, 404, 441, 698]
const DISCS: Array[int] = [171, 184, 196, 306]

## id -> [w, h] at K = 3 (the work order's table; generated from tools/art/environment/city/city_spec.py).  canopy_top_strip is the ONE reported deviation: the order's 2560 x 400
## contradicts its own 2048 px side limit and 70 MB budget, so it is 2048 x 320 (N03's farm_canopy has the same shape).
const TABLE: Dictionary = {
	"platform_disc_171": [1029, 642], "platform_disc_184": [1102, 684], "platform_disc_196": [1176, 726], "platform_disc_306": [1837, 1108],
	"trunk_bark_w367": [367, 512], "trunk_foot_w367": [367, 137], "trunk_root_w367": [496, 281],
	"trunk_bark_w404": [404, 512], "trunk_foot_w404": [404, 147], "trunk_root_w404": [546, 301],
	"trunk_bark_w441": [441, 512], "trunk_foot_w441": [441, 158], "trunk_root_w441": [596, 320],
	"trunk_bark_w698": [698, 512], "trunk_foot_w698": [698, 232], "trunk_root_w698": [943, 453],
	"hut_s_straw": [287, 284], "hut_s_moss": [287, 284], "hut_s_dark": [287, 284],
	"hut_m_straw": [383, 374], "hut_m_moss": [383, 374], "hut_m_dark": [383, 374],
	"hut_l_straw": [459, 384], "hut_l_moss": [459, 384], "hut_l_dark": [459, 384], "hut_raadhus": [497, 480],
	"pennant_pink": [66, 102], "pennant_pink_f1": [66, 102], "pennant_blue": [66, 102], "pennant_blue_f1": [66, 102],
	"pennant_gold": [66, 102], "pennant_gold_f1": [66, 102], "pennant_mint": [66, 102], "pennant_mint_f1": [66, 102],
	"lantern_hang": [54, 96], "lamp_door": [54, 54],
	"bridge_deck_tile_w43": [129, 128], "bridge_deck_tile_w28": [85, 128], "bridge_post": [30, 84], "rope_tile": [30, 186], "ladder_tile": [60, 112],
	"lift_basket": [145, 90], "lift_pulley": [72, 72],
	"market_stall_traetoppen": [252, 240], "fire_pit": [216, 168], "fire_flame": [120, 168], "fire_flame_f1": [120, 168], "fire_flame_f2": [120, 168],
	"bath_tub_back": [276, 120], "bath_tub_front": [276, 120], "planter_box": [168, 150], "planter_box_berry": [168, 150], "log_stack": [240, 150],
	"notice_board": [168, 216], "seed_basket": [90, 72], "trunk_hole_owl": [180, 228], "trunk_hole_owl_b": [180, 228], "owl_shelf": [204, 66],
	"bat_house_hanging": [348, 573], "bat_hang": [84, 102], "bat_hang_f1": [84, 102],
	"foliage_front_a": [1020, 720], "foliage_front_b": [1020, 720], "canopy_top_strip": [2048, 320], "shadow_soft": [256, 128],
}
## the backdrops are not props (ArtCatalog.backdrop loads them by theme name)
## the sky and the far layer ArtCatalog serves for &"treetop" (the painted sky, the painted_world far prop); V5's treetop_*.webp are superseded and not kept
const BACKDROP_LAYERS: Array[String] = ["sky", "far"]
## they do not scale with K: screen-space frame, backdrops, the shared shadow; the bark tile height
const FIXED: Array[String] = ["canopy_top_strip", "shadow_soft"]
const LANDMARK_IDS: Array[String] = ["market_stall_traetoppen", "fire_pit", "fire_flame", "bath_tub_back", "bath_tub_front", "planter_box", "planter_box_berry", "log_stack",
	"notice_board", "seed_basket", "trunk_hole_owl", "trunk_hole_owl_b", "owl_shelf", "bat_house_hanging", "bat_hang"]
const PENNANT_HEX := {"e58fa6": "pink", "6fa8e0": "blue", "f2c14e": "gold", "6fd6c4": "mint"}

var _t
var _imgs: Dictionary = {}


func run(t) -> void:
	_t = t
	ArtCatalog.reset()
	var props: Dictionary = _props()
	var city: Dictionary = _city()
	t.check("inputs_present", props.size() >= 70 and not city.is_empty(), "city props.json %d entries, traetoppen.json %s" % [props.size(), "read" if not city.is_empty() else "MISSING"])
	if props.is_empty() or city.is_empty():
		return
	_sizes_match_json(props, city)
	_manifest_sane(props)
	_discs(props)
	_trunk_tiles(props)
	_huts_night(props)
	_bridge_tiles(props)
	_landmarks(props)
	_city_json_art(props, city)
	_backdrop()
	_formats(props)
	_vram(props)
	_scale_with_k(props)
	_foliage(props)
	_readme()


# ---------------------------------------------------------------- helpers

func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _props() -> Dictionary:
	CityData.clear_cache()
	return CityData.city_props().duplicate(true)


## The file the game draws for a city entry: its pack folder (`_dir` of the effective entry) + file.
func _path(e: Dictionary) -> String:
	return str(e.get("_dir", DIR)) + str(e.get("file", ""))


func _city() -> Dictionary:
	var d: Variant = _json(CITY_JSON)
	return (d as Dictionary) if d is Dictionary else {}


func _k() -> float:
	return float(GameData.cfg("traetoppen.scale", K_REF))


func _image(path: String) -> Image:
	if _imgs.has(path):
		return _imgs[path]
	var im: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if im != null and not im.is_empty():
		im.convert(Image.FORMAT_RGBA8)
	else:
		im = null
	_imgs[path] = im
	return im


func _prop_image(props: Dictionary, id: String) -> Image:
	if not props.has(id):
		return null
	return _image(_path(props[id]))


func _expected(id: String, k: float) -> Vector2i:
	var base: Array = TABLE[id]
	if FIXED.has(id):
		return Vector2i(int(base[0]), int(base[1]))
	if id.begins_with("trunk_bark_w"):
		return Vector2i(roundi(float(base[0]) * k / K_REF), int(base[1]))
	return Vector2i(roundi(float(base[0]) * k / K_REF), roundi(float(base[1]) * k / K_REF))


## mean luminance (0..255) of one row / column of an RGBA8 image
func _row_luma(im: Image, y: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for x in im.get_width():
		var c: Color = im.get_pixel(x, y)
		out.append((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0)
	return out


func _col_luma(im: Image, x: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for y in im.get_height():
		var c: Color = im.get_pixel(x, y)
		out.append((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0)
	return out


func _mean_abs_diff(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var s := 0.0
	for i in a.size():
		s += absf(a[i] - b[i])
	return s / float(maxi(a.size(), 1))


## {seam, inner}: mean abs luma step across the wrap (last row -> first row, or last column -> first) and the mean step between neighbouring rows / columns inside the tile
func _wrap_steps(im: Image, vertical: bool) -> Dictionary:
	var n: int = im.get_height() if vertical else im.get_width()
	var step: int = maxi(1, n / 200)
	var inner := 0.0
	var cnt := 0
	var i := 0
	while i < n - 1:
		inner += _mean_abs_diff(_row_luma(im, i), _row_luma(im, i + 1)) if vertical else _mean_abs_diff(_col_luma(im, i), _col_luma(im, i + 1))
		cnt += 1
		i += step
	var seam: float = _mean_abs_diff(_row_luma(im, n - 1), _row_luma(im, 0)) if vertical else _mean_abs_diff(_col_luma(im, n - 1), _col_luma(im, 0))
	return {"seam": seam, "inner": inner / float(maxi(cnt, 1))}


func _alpha(im: Image, x: int, y: int) -> int:
	return int(round(im.get_pixel(x, y).a * 255.0))


# ---------------------------------------------------------------- tasks 1-6

func _sizes_match_json(props: Dictionary, city: Dictionary) -> void:
	var t = _t
	var k: float = _k()
	var json_k: float = float(city.get("scale", K_REF))
	var bad: Array[String] = []
	var checked := 0
	for id in TABLE:
		if not props.has(id):
			bad.append("%s: not in props.json" % id)
			continue
		var e: Dictionary = props[id]
		var im: Image = _prop_image(props, id)
		if im == null:
			bad.append("%s: file %s unreadable" % [id, e.get("file", "")])
			continue
		var want: Vector2i = _expected(id, k)
		var rec: Array = e.get("size", [])
		var ok_rec: bool = rec.size() == 2 and int(rec[0]) == im.get_width() and int(rec[1]) == im.get_height()
		var ok_tab: bool = absi(im.get_width() - want.x) <= TOL and absi(im.get_height() - want.y) <= TOL
		checked += 1
		if not ok_rec or not ok_tab:
			bad.append("%s: file %dx%d, json %s, table %dx%d" % [id, im.get_width(), im.get_height(), str(rec), want.x, want.y])
	# the city JSON itself: every platform / trunk / building has art of the right size
	var levels: Array = city.get("levels", [])
	var jbad: Array[String] = []
	var discs_used := 0
	for lv in levels:
		var l: Dictionary = lv
		if str(l.get("kind", "")) != "platform":
			continue
		var found := ""
		for r in DISCS:
			var pe: Dictionary = props.get("platform_disc_%d" % r, {})
			if not pe.is_empty() and absf(float(pe.get("rx", 0.0)) - float(l["rx"])) < 0.6:
				found = "platform_disc_%d" % r
		if found == "":
			jbad.append("platform %s rx %s has no disc" % [l["id"], l["rx"]])
			continue
		discs_used += 1
		var sz: Array = (props[found] as Dictionary)["size"]
		var wantw: float = 2.0 * float(l["rx"]) * json_k
		var wanth: float = 2.0 * float(l["ry"]) * json_k + float(l.get("rim", 16.0)) * json_k
		if absf(float(sz[0]) - wantw) > TOL + 1.0 or absf(float(sz[1]) - wanth) > TOL + 1.0:
			jbad.append("%s: sprite %s vs json %.1f x %.1f" % [found, str(sz), wantw, wanth])
	var trunks_used := 0
	for tr in city.get("trunks", []):
		var w: int = roundi(2.0 * float((tr as Dictionary)["rx"]) * json_k)
		var found_b := false
		for bw in BARKS:
			if absi(bw - w) <= 1 and props.has("trunk_bark_w%d" % bw):
				found_b = true
		trunks_used += 1
		if not found_b:
			jbad.append("trunk %s width %d has no bark tile" % [(tr as Dictionary)["id"], w])
	var hut_of: Dictionary = (props.get("_city", {}) as Dictionary).get("hut_of", {})
	var huts_used := 0
	for b in city.get("buildings", []):
		var bd: Dictionary = b
		var sid: String = str(hut_of.get(str(bd["id"]), ""))
		if sid == "" or not props.has(sid):
			jbad.append("building %s has no hut sprite" % bd["id"])
			continue
		huts_used += 1
		var he: Dictionary = props[sid]
		var wr: float = float(he.get("wall_r", 0.0))
		var rw: float = float(bd["roof"]["rx"]) * 2.0 * json_k
		var sw: float = float((he["size"] as Array)[0])
		if absf(wr - float(bd["wall_r"])) / float(bd["wall_r"]) > 0.13 or absf(sw - rw) / rw > 0.13:
			jbad.append("building %s (wall %.1f, roof width %.0f) vs %s (wall %.1f, width %.0f)" % [bd["id"], float(bd["wall_r"]), rw, sid, wr, sw])
	t.check("sizes_match_json", bad.is_empty() and jbad.is_empty() and checked == TABLE.size(),
		"%d textures within %d px of the table at K %.1f (props.json == the file sizes); city JSON: %d platforms, %d trunks, %d buildings matched to their art; %s" % [checked, TOL, k, discs_used, trunks_used, huts_used, str((bad + jbad).slice(0, 4))])
	t.check("k_agrees_json_lua", is_equal_approx(k, json_k) and is_equal_approx(k, float((props.get("_city", {}) as Dictionary).get("k", -1.0))),
		"lua scale %.2f, city JSON scale %.2f, props.json _city.k %s: one constant" % [k, json_k, str((props.get("_city", {}) as Dictionary).get("k"))])


func _manifest_sane(props: Dictionary) -> void:
	var bad: Array[String] = []
	var n := 0
	for id in props:
		if str(id).begins_with("_"):
			continue
		var e: Dictionary = props[id]
		var im: Image = _prop_image(props, str(id))
		n += 1
		if im == null:
			bad.append("%s: no image" % id)
			continue
		var pv: Array = e.get("pivot", [])
		var fp: Array = e.get("footprint", [])
		# a night layer's pivot is the DAY sprite's pivot relative to the trimmed layer (it can lie outside it: huts_have_night_layers checks it against the day entry)
		var is_night: bool = str(e.get("kind", "")) == "hut_night"
		if pv.size() != 2 or (not is_night and (float(pv[0]) < 0.0 or float(pv[0]) > im.get_width() or float(pv[1]) < 0.0 or float(pv[1]) > im.get_height())):
			bad.append("%s: pivot %s outside %dx%d" % [id, str(pv), im.get_width(), im.get_height()])
		if fp.size() != 2 or int(fp[0]) < 0 or int(fp[1]) < 0:
			bad.append("%s: footprint %s" % [id, str(fp)])
		var blend: String = str(e.get("blend", ""))
		if blend != "" and blend != "add":
			bad.append("%s: blend %s" % [id, blend])
		if not str(e.get("file", "")).ends_with(".webp"):
			bad.append("%s: file %s is not .webp" % [id, e.get("file", "")])
	_t.check("props_manifest_sane", bad.is_empty() and n >= 70, "%d entries: pivot inside the image, footprint pair, blend '' or add, lossless .webp files; %s" % [n, str(bad.slice(0, 4))])


func _discs(props: Dictionary) -> void:
	var bad: Array[String] = []
	var lines: Array[String] = []
	for r in DISCS:
		var id := "platform_disc_%d" % r
		var im: Image = _prop_image(props, id)
		if im == null:
			bad.append("%s: missing" % id)
			continue
		var e: Dictionary = props[id]
		var pv := Vector2(float(e["pivot"][0]), float(e["pivot"][1]))
		var cx: int = int(pv.x)
		var cy: int = int(pv.y)
		# NO trunk hole: the pixels around the pivot are opaque
		var holes := 0
		for dx in [-60, -20, 0, 20, 60]:
			for dy in [-40, -10, 0, 10, 40]:
				if _alpha(im, cx + dx, cy + dy) < 250:
					holes += 1
		if holes > 0:
			bad.append("%s: %d translucent pixels around the pivot (a trunk hole?)" % [id, holes])
		# ellipse ratio .5776: top edge above the pivot and left edge beside it (outline included)
		var top := cy
		while top > 0 and _alpha(im, cx, top - 1) > 128:
			top -= 1
		var left := cx
		while left > 0 and _alpha(im, left - 1, cy) > 128:
			left -= 1
		var ry: float = float(cy - top)
		var rx: float = float(cx - left)
		var want: float = float(e["ry"]) / float(e["rx"])
		if absf(ry / rx - want) > 0.02:
			bad.append("%s: measured ellipse ratio %.4f vs %.4f" % [id, ry / rx, want])
		# rim skirt: below the front of the ellipse by about 16 sketch px x K
		var bottom := cy
		while bottom < im.get_height() - 1 and _alpha(im, cx, bottom + 1) > 128:
			bottom += 1
		var rim: float = float(bottom) - (float(cy) + ry)
		var want_rim: float = float(e.get("rim", 16.0)) * _k()
		if absf(rim - want_rim) > 8.0:
			bad.append("%s: rim %.1f px vs %.1f" % [id, rim, want_rim])
		# The approved painted timber is quieter and darker than the CG orange.
		var sum := Vector3.ZERO
		var n := 0
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			var c: Color = im.get_pixel(int(pv.x + cos(a) * rx * 0.8), int(pv.y + sin(a) * ry * 0.8))
			sum += Vector3(c.r, c.g, c.b) * 255.0
			n += 1
		sum /= float(n)
		if sum.x < 90.0 or sum.x > 170.0 or sum.x - sum.y < 15.0 or sum.y - sum.z < 15.0:
			bad.append("%s: painted timber %s lost its warm brown separation" % [id, str(sum)])
		lines.append("%s ratio %.3f rim %.0f" % [id, ry / rx, rim])
	_t.check("discs_ellipse_planks_no_hole", bad.is_empty() and lines.size() == 4, "4 painted timber discs: opaque pivot, ellipse ratio .5776 +-.02, rim ~16 x K, warm brown pigment; %s %s" % [str(lines), str(bad.slice(0, 3))])


func _trunk_tiles(props: Dictionary) -> void:
	var bad: Array[String] = []
	var worst := 0.0
	for w in BARKS:
		var id := "trunk_bark_w%d" % w
		var im: Image = _prop_image(props, id)
		if im == null:
			bad.append("%s: missing" % id)
			continue
		var st: Dictionary = _wrap_steps(im, true)
		var ratio: float = float(st["seam"]) / maxf(float(st["inner"]), 0.01)
		worst = maxf(worst, ratio)
		if ratio > 1.8:
			bad.append("%s: wrap seam %.2f vs inner step %.2f (ratio %.1f)" % [id, st["seam"], st["inner"], ratio])
		# dark band on the right 35 %: the right third is clearly darker than the lit side
		var lit := 0.0
		var dark := 0.0
		var ln := 0
		var dn := 0
		for y in range(0, im.get_height(), 8):
			for x in range(int(w * 0.08), int(w * 0.58), 6):
				var c: Color = im.get_pixel(x, y)
				lit += (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
				ln += 1
			for x in range(int(w * 0.72), int(w * 0.96), 6):
				var c2: Color = im.get_pixel(x, y)
				dark += (0.2126 * c2.r + 0.7152 * c2.g + 0.0722 * c2.b) * 255.0
				dn += 1
		if dark / float(dn) > 0.82 * lit / float(ln):
			bad.append("%s: right band %.0f is not darker than the lit side %.0f" % [id, dark / float(dn), lit / float(ln)])
		# foot continues the bark: its first rows ARE the tile rows (same pixels inside the trunk)
		var foot: Image = _prop_image(props, "trunk_foot_w%d" % w)
		if foot != null and _mean_abs_diff(_row_luma(foot, 6), _row_luma(im, 6)) > 4.0:
			bad.append("trunk_foot_w%d: row 6 differs from the bark tile (not a continuation)" % w)
		# the root flare is 1.35 x wider than the trunk
		var root: Image = _prop_image(props, "trunk_root_w%d" % w)
		if root != null and absf(float(root.get_width()) / float(w) - 1.35) > 0.03:
			bad.append("trunk_root_w%d: %.2f x the trunk width" % [w, float(root.get_width()) / float(w)])
	_t.check("trunk_tiles_seamless_pixels", bad.is_empty(), "4 bark tiles wrap vertically (worst seam/inner ratio %.2f), dark band right, foot continues the tile, root flare 1.35 x; %s" % [worst, str(bad.slice(0, 3))])


func _huts_night(props: Dictionary) -> void:
	var hut_ids: Array[String] = []
	for id in props:
		if str(id).begins_with("hut_") and not str(id).ends_with("_night"):
			hut_ids.append(str(id))
	hut_ids.sort()
	var bad: Array[String] = []
	var nbad: Array[String] = []
	var lit_px := 0
	for id in hut_ids:
		var e: Dictionary = props[id]
		var nid: String = str(e.get("night", ""))
		if nid == "" or not props.has(nid):
			bad.append("%s: no night layer" % id)
			continue
		var ne: Dictionary = props[nid]
		var day: Image = _prop_image(props, id)
		var night: Image = _prop_image(props, nid)
		if day == null or night == null:
			bad.append("%s: night file missing" % id)
			continue
		var off: Array = e.get("night_offset", [-1, -1])
		var inside: bool = int(off[0]) >= 0 and int(off[1]) >= 0 and int(off[0]) + night.get_width() <= day.get_width() and int(off[1]) + night.get_height() <= day.get_height()
		if not inside:
			bad.append("%s: night layer %dx%d at %s outside the day sprite" % [id, night.get_width(), night.get_height(), str(off)])
		var npv: Array = ne["pivot"]
		if absf(float(npv[0]) + float(off[0]) - float((e["pivot"] as Array)[0])) > 1.0 or absf(float(npv[1]) + float(off[1]) - float((e["pivot"] as Array)[1])) > 1.0:
			bad.append("%s: night pivot does not agree with the day pivot + offset" % id)
		# additive: blend add, normalised light colours (alpha carries the brightness: no dim-colour pixels), trimmed to the lights
		var minx: int = night.get_width()
		var maxx: int = -1
		var miny: int = night.get_height()
		var maxy: int = -1
		var dim := 0
		var lit := 0
		for y in night.get_height():
			for x in night.get_width():
				var c: Color = night.get_pixel(x, y)
				var a: int = int(round(c.a * 255.0))
				if a > 0:
					minx = mini(minx, x)
					maxx = maxi(maxx, x)
					miny = mini(miny, y)
					maxy = maxi(maxy, y)
					lit += 1
				if a >= 48 and int(round(maxf(c.r, maxf(c.g, c.b)) * 255.0)) < 120:
					dim += 1
		var trimmed: bool = maxx >= 0 and minx <= 1 and miny <= 1 and maxx >= night.get_width() - 2 and maxy >= night.get_height() - 2
		lit_px += lit
		if String(ne.get("blend", "")) != "add" or dim > 0 or not trimmed or lit < 200:
			nbad.append("%s: blend %s, dim-light pixels %d, trimmed %s, lit pixels %d" % [nid, ne.get("blend"), dim, trimmed, lit])
		if String(e.get("blend", "")) == "add":
			nbad.append("%s: the DAY sprite is additive" % id)
		# the lights are a small part of the hut (a lit door and two windows)
		if night.get_width() * night.get_height() > day.get_width() * day.get_height() * 7 / 10:
			nbad.append("%s: the night layer covers %.0f %% of the day sprite" % [id, 100.0 * float(night.get_width() * night.get_height()) / float(day.get_width() * day.get_height())])
	_t.check("huts_have_night_layers", bad.is_empty() and hut_ids.size() == 10, "%d hut sprites (3 wall sizes x straw / moss / dark + the lavender Raadhus), each with its night entry inside the day sprite; %s" % [hut_ids.size(), str(bad.slice(0, 3))])
	_t.check("night_layers_additive", nbad.is_empty() and lit_px > 0, "every night layer is blend add, light colours normalised (no dim pixels), trimmed to its lights, smaller than 70 %% of the day sprite (%d lit px in all); %s" % [lit_px, str(nbad.slice(0, 3))])


func _bridge_tiles(props: Dictionary) -> void:
	var bad: Array[String] = []
	var lines: Array[String] = []
	for id in ["bridge_deck_tile_w43", "bridge_deck_tile_w28"]:
		var im: Image = _prop_image(props, id)
		if im == null:
			bad.append("%s: missing" % id)
			continue
		var st: Dictionary = _wrap_steps(im, false)
		var ratio: float = float(st["seam"]) / maxf(float(st["inner"]), 0.01)
		lines.append("%s x-wrap %.2f" % [id, ratio])
		if ratio > 1.8:
			bad.append("%s: wrap seam %.2f vs inner %.2f" % [id, st["seam"], st["inner"]])
		var holes := 0
		for y in range(0, im.get_height(), 7):
			for x in range(0, im.get_width(), 7):
				if _alpha(im, x, y) < 250:
					holes += 1
		if holes > 0:
			bad.append("%s: translucent pixels in a deck tile" % id)
	for id in ["rope_tile", "ladder_tile"]:
		var im2: Image = _prop_image(props, id)
		if im2 == null:
			bad.append("%s: missing" % id)
			continue
		# these tile vertically: compare the rows around the wrap by ALPHA and colour
		var st2: Dictionary = _wrap_steps(im2, true)
		var worst_a := 0
		for x in im2.get_width():
			worst_a = maxi(worst_a, absi(_alpha(im2, x, 0) - _alpha(im2, x, im2.get_height() - 1)))
		lines.append("%s y-wrap alpha %d luma %.2f/%.2f" % [id, worst_a, st2["seam"], st2["inner"]])
		if worst_a > 40 or float(st2["seam"]) > 2.0 * float(st2["inner"]) + 2.0:
			bad.append("%s: wrap seam alpha %d luma %.2f vs inner %.2f" % [id, worst_a, st2["seam"], st2["inner"]])
	_t.check("bridge_parts_tile_seamlessly", bad.is_empty() and lines.size() == 4, "deck tiles wrap in x, rope and ladder tiles wrap in y (seam step <= 1.8 x the inner step); %s %s" % [str(lines), str(bad.slice(0, 3))])


func _landmarks(props: Dictionary) -> void:
	var bad: Array[String] = []
	var k: float = _k()
	for id in LANDMARK_IDS:
		if not ArtCatalog.has_real_prop(StringName(id)):
			bad.append("%s: ArtCatalog has no real art" % id)
			continue
		var p: Dictionary = ArtCatalog.prop(StringName(id))
		var tex: Texture2D = p["texture"]
		var want: Vector2i = _expected(id, k)
		if absi(tex.get_width() - want.x) > TOL or absi(tex.get_height() - want.y) > TOL:
			bad.append("%s: texture %dx%d vs table %dx%d" % [id, tex.get_width(), tex.get_height(), want.x, want.y])
	for id in ["fire_flame"]:
		var e: Dictionary = props.get(id, {})
		if str(e.get("blend", "")) != "add" or (e.get("frames", []) as Array).size() != 3:
			bad.append("fire_flame: additive with 3 frames expected")
		for f in e.get("frames", []):
			if not ArtCatalog.has_real_prop(StringName(str(f))) or str((props.get(str(f), {}) as Dictionary).get("blend", "")) != "add":
				bad.append("flame frame %s missing or not additive" % f)
	var be: Dictionary = props.get("bat_hang", {})
	if (be.get("frames", []) as Array).size() != 2:
		bad.append("bat_hang: 2 sway frames expected")
	_t.check("landmark_props_exist", bad.is_empty(), "the ten landmarks' set dressing (stall, fire pit + 3 additive flame frames, tub halves, planters, log stack, notice board, seed basket, 2 owl holes + shelf, bat house + 2-frame bat) is real art of the table size; %s" % str(bad.slice(0, 4)))


## every art id the city data (data/traetoppen/traetoppen.json) can ask for resolves to REAL art (ArtCatalog.missing() stays free of them)
func _city_json_art(props: Dictionary, city: Dictionary) -> void:
	var need: Dictionary = {}
	for p in city.get("props", []):
		need[str((p as Dictionary).get("art", ""))] = true
	var hut_of: Dictionary = (props.get("_city", {}) as Dictionary).get("hut_of", {})
	var pennants_ok := true
	var bridges := 0
	for b in city.get("buildings", []):
		var bd: Dictionary = b
		need[str(hut_of.get(str(bd["id"]), "?"))] = true
		if bd.has("pennant"):
			var nm: String = str(PENNANT_HEX.get(str(bd["pennant"]).to_lower(), ""))
			if nm == "":
				pennants_ok = false
			else:
				need["pennant_" + nm] = true
	for lv in city.get("levels", []):
		var l: Dictionary = lv
		if str(l.get("kind", "")) == "platform":
			var r: int = roundi(float(l["rx"]))
			var pick := ""
			for dr in DISCS:
				if absi(dr - r) <= 1:
					pick = "platform_disc_%d" % dr
			need[pick] = true
	for tr in city.get("trunks", []):
		var w: int = roundi(2.0 * float((tr as Dictionary)["rx"]) * _k())
		for bw in BARKS:
			if absi(bw - w) <= 1:
				need["trunk_bark_w%d" % bw] = true
				need["trunk_foot_w%d" % bw] = true
				if str((tr as Dictionary).get("part", "")) == "lower":
					need["trunk_root_w%d" % bw] = true
	for br in city.get("bridges", []):
		bridges += 1
		need["bridge_deck_tile_w43" if float((br as Dictionary)["width"]) > 36.0 else "bridge_deck_tile_w28"] = true
	if not (city.get("lanterns", []) as Array).is_empty():
		need["lantern_hang"] = true
	if not (city.get("door_lamps", []) as Array).is_empty():
		need["lamp_door"] = true
	if not (city.get("owl_holes", []) as Array).is_empty():
		need["trunk_hole_owl"] = true
		need["owl_shelf"] = true
	if not (city.get("bat_houses", []) as Array).is_empty():
		need["bat_house_hanging"] = true
		need["bat_hang"] = true
	if not (city.get("foliage", []) as Array).is_empty():
		need["foliage_front_a"] = true
		need["foliage_front_b"] = true
	if not (city.get("ladders", []) as Array).is_empty():
		need["ladder_tile"] = true
	if not (city.get("lifts", []) as Array).is_empty():
		need["lift_basket"] = true
		need["lift_pulley"] = true
	need["bridge_post"] = true
	need["rope_tile"] = true
	need["canopy_top_strip"] = true
	ArtCatalog.clear_missing()
	var missing_ids: Array[String] = []
	for id in need:
		var sid := str(id)
		if sid == "" or sid == "?":
			missing_ids.append("(unmapped)")
			continue
		ArtCatalog.prop(StringName(sid))
		if not ArtCatalog.has_real_prop(StringName(sid)):
			missing_ids.append(sid)
	var mm: Array[String] = ArtCatalog.missing()
	var mine: Array[String] = []
	for m in mm:
		if need.has(m.substr(5)) and m.begins_with("prop:"):
			mine.append(m)
	_t.check("every_city_json_prop_has_art", missing_ids.is_empty() and mine.is_empty() and pennants_ok and bridges == 9,
		"%d art ids the city data names (props, huts via hut_of, pennants by colour, discs, trunks, 9 bridges' deck tiles, lanterns, owl holes, bat houses, foliage, ladder, lift) are real art; ArtCatalog.missing() holds none of them (mailbox_red is P22's); %s %s" % [need.size(), str(missing_ids.slice(0, 4)), str(mine.slice(0, 3))])


func _backdrop() -> void:
	ArtCatalog.clear_missing()
	var b: Dictionary = ArtCatalog.backdrop(&"treetop")
	var bad: Array[String] = []
	if not bool(b.get("real", false)):
		bad.append("backdrop(treetop).real is false: ArtCatalog fell back to the farm palette")
	var sky: Texture2D = b.get("sky", null)
	var far: Texture2D = b.get("far", null)
	var painted_sky := FileAccess.file_exists(BACKDROP_DIR + "treetop_sky.png")
	var sky_size := Vector2(384, 216) if painted_sky else Vector2(16, 1024)
	if sky == null or sky.get_size() != sky_size or (painted_sky and sky.resource_path != BACKDROP_DIR + "treetop_sky.png"):
		bad.append("sky %s" % [str(sky.get_size()) if sky != null else "null"])
	if far == null or far.get_width() != 2048 or far.get_height() != 1024:
		bad.append("far %s" % [str(far.get_size()) if far != null else "null"])
	var fim: Image = _image(far.resource_path) if far != null else null
	if fim != null:
		# Seamless painted foliage, with enough opacity to separate the far trees.
		var st: Dictionary = _wrap_steps(fim, false)
		if float(st["seam"]) > 2.0 * float(st["inner"]) + 1.0:
			bad.append("far: x-wrap seam %.2f vs inner %.2f" % [st["seam"], st["inner"]])
		var bars := 0.0
		var xs := 0
		for x in range(0, 2048, 8):
			bars += fim.get_pixel(x, 300).a
			xs += 1
		if bars / float(xs) < 0.15:
			bad.append("far: no trunk bars at row 300")
	var mm: Array[String] = ArtCatalog.missing()
	if mm.has("backdrop:treetop"):
		bad.append("ArtCatalog.missing() lists backdrop:treetop")
	_t.check("backdrop_loads_through_artcatalog", bad.is_empty(), "runtime sky %s (the approved painting); far trees wrap and remain visible; %s" % [sky_size, str(bad.slice(0, 3))])


## no lossy WebP: every file is VP8L (lossless) or a PNG; a 'VP8 ' chunk is lossy
func _formats(props: Dictionary) -> void:
	var bad: Array[String] = []
	var n := 0
	var paths: Array[String] = []
	for id in props:
		if not str(id).begins_with("_") and not paths.has(_path(props[id])):
			paths.append(_path(props[id]))
	for b in BACKDROP_LAYERS:
		paths.append(_backdrop_path(b))
	for p in paths:
		n += 1
		if p.ends_with(".png"):
			continue
		var b: PackedByteArray = FileAccess.get_file_as_bytes(p)
		if b.size() < 20 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WEBP":
			bad.append("%s: not a RIFF WebP" % p.get_file())
			continue
		var pos := 12
		var lossy := false
		var lossless := false
		while pos + 8 <= b.size():
			var fourcc: String = b.slice(pos, pos + 4).get_string_from_ascii()
			var size: int = int(b[pos + 4]) | (int(b[pos + 5]) << 8) | (int(b[pos + 6]) << 16) | (int(b[pos + 7]) << 24)
			if fourcc == "VP8 ":
				lossy = true
			elif fourcc == "VP8L":
				lossless = true
			pos += 8 + size + (size & 1)
		# V5's own files (city/, the backdrops) and their painted_world copies are lossless; the painted consistency pass encodes its pennants lossy and
		# imports them S3TC like the rest of its pack
		if (lossy or not lossless) and not p.contains("/zz_painted_consistency/"):
			bad.append("%s: %s" % [p.get_file(), "LOSSY (VP8)" if lossy else "no VP8L chunk"])
	_t.check("no_lossy_webp", bad.is_empty() and n >= 77, "%d files of the city set are WebP, lossless except the consistency pass's pennants; %s" % [n, str(bad.slice(0, 3))])


func _backdrop_path(layer: String) -> String:
	var tex: Texture2D = ArtCatalog.backdrop(&"treetop").get(layer, null)
	return tex.resource_path if tex != null else ""


func _import_mipmaps(path: String) -> bool:
	if not FileAccess.file_exists(path + ".import"):
		return true                                  # no .import yet: the project default (mipmaps on)
	var txt: String = FileAccess.get_file_as_string(path + ".import")
	var rx := RegEx.new()
	rx.compile("mipmaps/generate=(true|false)")
	var m: RegExMatch = rx.search(txt)
	return m == null or m.get_string(1) == "true"


## total texture memory (RGBA8 + mipmaps where the import keeps them) of the whole set at K, nothing above 2048 px on a side
func _vram(props: Dictionary) -> void:
	var total := 0.0
	var count := 0
	var biggest := 0
	var bad: Array[String] = []
	var no_mips: Array[String] = []
	for id in props:
		if str(id).begins_with("_"):
			continue
		var e: Dictionary = props[id]
		var path: String = _path(e)
		var im: Image = _image(path)
		if im == null:
			continue
		var mips: bool = _import_mipmaps(path)
		if not mips:
			no_mips.append(str(id))
		total += float(im.get_width() * im.get_height()) * 4.0 * (4.0 / 3.0 if mips else 1.0)
		count += 1
		biggest = maxi(biggest, maxi(im.get_width(), im.get_height()))
		if maxi(im.get_width(), im.get_height()) > SIDE_LIMIT:
			bad.append("%s %dx%d is above %d px on a side" % [id, im.get_width(), im.get_height(), SIDE_LIMIT])
	var backdrop_mb := 0.0
	for b in BACKDROP_LAYERS:
		var bp: String = _backdrop_path(b)
		var bi: Image = _image(bp)
		if bi == null:
			bad.append("%s unreadable" % b)
			continue
		var mips: bool = _import_mipmaps(bp)
		if not mips:
			no_mips.append(b)
		var mb: float = float(bi.get_width() * bi.get_height()) * 4.0 * (4.0 / 3.0 if mips else 1.0)
		total += mb
		backdrop_mb += mb
		count += 1
		biggest = maxi(biggest, maxi(bi.get_width(), bi.get_height()))
	# props keep their mipmaps (the project default); only the stretched sky and the magnified far layer are imported without
	for id in props:
		if str(id).begins_with("_"):
			continue
		if no_mips.has(str(id)):
			bad.append("%s is imported without mipmaps (props keep them)" % id)
	var mb_total: float = total / 1.0e6
	_t.check("vram_budget", bad.is_empty() and mb_total <= BUDGET_MB and mb_total > 30.0 and count >= 70,
		"%d textures, %.1f MB RGBA8 + mipmaps (budget %.0f MB; backdrops %.1f MB, imported without mipmaps: %s), largest side %d px; %s" % [count, mb_total, BUDGET_MB, backdrop_mb / 1.0e6, str(no_mips), biggest, str(bad.slice(0, 3))])


func _scale_with_k(props: Dictionary) -> void:
	var bad: Array[String] = []
	# 1. every size at K equals round(size at 3 x K / 3): the table is a pure function of K (re-bake after changing lua scale)
	for k in [2.0, 2.4, 3.0, 3.2]:
		for id in TABLE:
			var a: Vector2i = _expected(id, k)
			var b: Vector2i = _expected(id, K_REF)
			if FIXED.has(id) or str(id).begins_with("trunk_bark_w"):
				if absi(a.y - b.y) > 0:
					bad.append("%s: height changes with K" % id)
				if FIXED.has(id) and a.x != b.x:
					bad.append("%s: fixed size changes with K" % id)
				continue
			if absi(a.x - roundi(float(b.x) * k / K_REF)) > 1 or absi(a.y - roundi(float(b.y) * k / K_REF)) > 1:
				bad.append("%s at K %.1f: %s vs %s x %.2f" % [id, k, str(a), str(b), k / K_REF])
	# 2. the shipped set belongs to the Lua constant
	var shipped_k: float = float((props.get("_city", {}) as Dictionary).get("k", -1.0))
	if not is_equal_approx(shipped_k, _k()):
		bad.append("the set was baked for K %.2f, lua/config/traetoppen.lua says %.2f: re-bake (tools/art/environment/city/build_city.sh)" % [shipped_k, _k()])
	# 3. the bake tool derives K from the same Lua constant (city_spec.py reads it, no literal): proven by running it when the art venv exists
	var py: String = ProjectSettings.globalize_path("res://tools/art/.venv/bin/python")
	var spec: String = ProjectSettings.globalize_path("res://tools/art/environment/city/city_spec.py")
	var ran := ""
	if FileAccess.file_exists(py) or FileAccess.file_exists("res://tools/art/.venv/bin/python"):
		var r: Dictionary = _t.run_tool(py, PackedStringArray([spec, "--k", "2.4"]))
		var txt: String = str(r.get("output", ""))
		if int(r.get("code", -1)) != 0 or not ("K = 2.4" in txt) or not ("hut_m_straw" in txt):
			bad.append("city_spec.py --k 2.4 failed: %s" % txt.substr(0, 120))
		else:
			var want: Vector2i = _expected("hut_m_straw", 2.4)
			if not ("%5d x %5d" % [want.x, want.y]) in txt:
				bad.append("city_spec.py at 2.4 does not print the hut_m_straw size %s" % str(want))
			ran = "city_spec.py --k 2.4 ran (%d lines)" % txt.split("\n").size()
	else:
		_t.skip("art_city.sizes_scale_with_k: the art venv tools/art/.venv is absent: the city_spec.py --k run is SKIPPED (the arithmetic checks ran)")
	_t.check("sizes_scale_with_k", bad.is_empty(), "sizes = round(size at K=3 x K / 3) for K 2.0 / 2.4 / 3.0 / 3.2 (tile height, canopy, backdrops fixed); the set is baked for the Lua scale %.1f; %s %s" % [_k(), ran, str(bad.slice(0, 3))])


func _foliage(props: Dictionary) -> void:
	var bad: Array[String] = []
	for id in ["foliage_front_a", "foliage_front_b"]:
		var im: Image = _prop_image(props, id)
		if im == null:
			bad.append("%s unreadable" % id)
			continue
		# five circles baked at alpha .5: single coverage ~ .5, overlaps up to ~ .875, never opaque; a clear majority of the covered pixels sits at .4 - .6
		var covered := 0
		var half := 0
		var maxa := 0
		for y in range(0, im.get_height(), 3):
			for x in range(0, im.get_width(), 3):
				var a: int = _alpha(im, x, y)
				maxa = maxi(maxa, a)
				if a > 20:
					covered += 1
					if a >= 100 and a <= 160:
						half += 1
		if maxa > 236 or covered < 2000 or float(half) / float(covered) < 0.35:
			bad.append("%s: max alpha %d, covered %d, half-alpha share %.2f" % [id, maxa, covered, float(half) / float(maxi(covered, 1))])
	_t.check("foliage_alpha_baked", bad.is_empty(), "foliage_front_a / b: five leaf circles at alpha .5 baked (overlaps denser, never opaque); %s" % str(bad.slice(0, 2)))


func _readme() -> void:
	var txt: String = FileAccess.get_file_as_string(README) if FileAccess.file_exists(README) else ""
	_t.check("readme_verdict", "accepted at" in txt and "known weaknesses" in txt.to_lower() and "Honest notes" in txt and "Pre-existing paths touched" in txt,
		"tools/art/environment/city/README.md carries the honest notes, the verdict line and the list of pre-existing paths touched (none)")


# ================================================================== windowed (tests/run_playtest.sh --windowed --only=art_city [--out=DIR])
## The real engine: Sprite2D region + repeat for the trunks, a Line2D with the deck tile for the bridges, the pieces on grass at zoom 0.4 / 0.2, one platform assembled, the same at dusk.
const GRASS := Color("8fb85a")
const NIGHT_MOD := Color(0.36, 0.40, 0.62)

var _scene: Node2D
var _cam: Camera2D
var _glow_layer: CanvasLayer


func run_windowed(t) -> void:
	_t = t
	ArtCatalog.reset()
	if not t.has_window():
		t.skip("art_city windowed: not running in a window")
		return
	await _seam_in_engine()
	await _line2d_orientation()
	await _pieces_sheets()
	await _assembled(false)
	await _assembled(true)
	_end_scene()


func _end_scene() -> void:
	if _scene != null:
		_scene.queue_free()
		_scene = null
	if _glow_layer != null:
		_glow_layer.queue_free()
		_glow_layer = null


func _begin_scene(zoom: float, centre: Vector2, bg: Color = GRASS) -> Node2D:
	_end_scene()
	_scene = Node2D.new()
	_scene.name = "ArtCityShot"
	_t.tree.root.add_child(_scene)
	var back := ColorRect.new()
	back.color = bg
	back.position = Vector2(-30000, -30000)
	back.size = Vector2(60000, 60000)
	back.z_index = -4000
	_scene.add_child(back)
	_cam = Camera2D.new()
	_cam.position = centre
	_cam.zoom = Vector2(zoom, zoom)
	_cam.position_smoothing_enabled = false
	_scene.add_child(_cam)
	_cam.make_current()
	return _scene


func _spr(parent: Node, id: StringName, pos: Vector2, z: int = 0) -> Sprite2D:
	var p: Dictionary = ArtCatalog.prop(id)
	var s := Sprite2D.new()
	s.texture = p["texture"]
	s.centered = false
	s.offset = -(p["pivot"] as Vector2)
	s.position = pos
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if str(p["blend"]) == "add":
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
	parent.add_child(s)
	return s


func _tiled(parent: Node, id: StringName, top_left: Vector2, region: Rect2, z: int = 0) -> Sprite2D:
	var p: Dictionary = ArtCatalog.prop(id)
	var s := Sprite2D.new()
	s.texture = p["texture"]
	s.centered = false
	s.region_enabled = true
	s.region_rect = region
	s.position = top_left
	s.z_index = z
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(s)
	return s


func _luma(c: Color) -> float:
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0


## mean abs luma step between two rows of a screenshot over [x0, x1)
func _row_step(img: Image, y: int, x0: int, x1: int) -> float:
	var s := 0.0
	for x in range(x0, x1):
		s += absf(_luma(img.get_pixel(x, y)) - _luma(img.get_pixel(x, y + 1)))
	return s / float(maxi(x1 - x0, 1))


func _seam_in_engine() -> void:
	var t = _t
	var bad: Array[String] = []
	var worst := 0.0
	var samples := 0
	for group in [[367, 404, 441], [698]]:
		_begin_scene(1.0, Vector2(640, 360), Color("203040"))
		var x := 0.0
		var spans: Array = []
		for w in group:
			var id := StringName("trunk_bark_w%d" % w)
			# region rows 200 .. 900: the tile boundary (row 512 -> 0) lies at screen row 312
			_tiled(_scene, id, Vector2(x, 10), Rect2(0, 200, float(w), 700.0))
			spans.append([int(x), int(x) + int(w), int(w)])
			x += float(w)
		var img: Image = await t.capture("trunk_seam_w%s" % str(group[0]))
		if img == null:
			continue
		var seam_y: int = 10 + 312 - 1
		for sp in spans:
			samples += 1
			var x0: int = int(sp[0]) + 14
			var x1: int = int(sp[1]) - 14
			var steps: Array[float] = []
			for y in range(seam_y - 40, seam_y + 40):
				if y != seam_y:
					steps.append(_row_step(img, y, x0, x1))
			steps.sort()
			var median: float = steps[steps.size() / 2]
			var seam: float = _row_step(img, seam_y, x0, x1)
			var ratio: float = seam / maxf(median, 0.05)
			worst = maxf(worst, ratio)
			if seam > 1.9 * median + 0.5:
				bad.append("w%d: seam step %.2f vs median %.2f" % [sp[2], seam, median])
		# negative control: the same tile with its rows shifted by half a tile on a second sprite DOES show a seam (the probe can see one)
	_begin_scene(1.0, Vector2(640, 360), Color("203040"))
	var id2 := StringName("trunk_bark_w404")
	_tiled(_scene, id2, Vector2(100, 10), Rect2(0, 200, 404, 312))                     # rows 200..511
	_tiled(_scene, id2, Vector2(100, 10 + 312), Rect2(0, 100, 404, 400))                # a DIFFERENT phase underneath: a real discontinuity
	var ctl: Image = await t.capture("trunk_seam_control")
	var ctl_ratio := 0.0
	if ctl != null:
		var steps_c: Array[float] = []
		for y in range(10 + 312 - 40, 10 + 312 + 40):
			if y != 10 + 311:
				steps_c.append(_row_step(ctl, y, 114, 490))
		steps_c.sort()
		ctl_ratio = _row_step(ctl, 10 + 311, 114, 490) / maxf(steps_c[steps_c.size() / 2], 0.05)
	t.check("tileable_trunk_seam", samples == 4 and bad.is_empty() and ctl_ratio > 2.5,
		"all four bark tiles repeat through Sprite2D region + repeat in the engine without a visible seam (worst seam / median row step %.2f, limit 1.9 x + .5); the control with a wrong phase shows %.1f x (the probe can see a seam); %s" % [worst, ctl_ratio, str(bad.slice(0, 3))])


func _line2d_orientation() -> void:
	var t = _t
	_begin_scene(1.0, Vector2(640, 360), Color("203040"))
	var tex: Texture2D = ArtCatalog.prop(&"bridge_deck_tile_w43")["texture"]
	var h := Line2D.new()
	h.points = PackedVector2Array([Vector2(60, 200), Vector2(700, 200)])
	h.width = 129.0
	h.texture = tex
	h.texture_mode = Line2D.LINE_TEXTURE_TILE
	h.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	h.default_color = Color.WHITE
	_scene.add_child(h)
	var v := Line2D.new()
	v.points = PackedVector2Array([Vector2(900, 40), Vector2(900, 680)])
	v.width = 129.0
	v.texture = tex
	v.texture_mode = Line2D.LINE_TEXTURE_TILE
	v.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	v.default_color = Color.WHITE
	_scene.add_child(v)
	var img: Image = await t.capture("bridge_line2d")
	if img == null:
		return
	# mean luma step along the line vs across it: a deck tile has planks as bars ACROSS the bridge, so along the line the luminance changes plank by plank
	var hx := 0.0
	var hy := 0.0
	var n := 0
	for y in range(160, 240, 2):
		for x in range(120, 640, 2):
			hx += absf(_luma(img.get_pixel(x, y)) - _luma(img.get_pixel(x + 1, y)))
			hy += absf(_luma(img.get_pixel(x, y)) - _luma(img.get_pixel(x, y + 1)))
			n += 1
	var vx := 0.0
	var vy := 0.0
	var m := 0
	for y in range(120, 600, 2):
		for x in range(860, 940, 2):
			vx += absf(_luma(img.get_pixel(x, y)) - _luma(img.get_pixel(x + 1, y)))
			vy += absf(_luma(img.get_pixel(x, y)) - _luma(img.get_pixel(x, y + 1)))
			m += 1
	hx /= float(n)
	hy /= float(n)
	vx /= float(m)
	vy /= float(m)
	# Painted grain has strong detail in both axes. Compare the actual native
	# UV mapping instead of assuming that one axis must have more high frequencies.
	var horizontal := img.get_region(Rect2i(60, 136, 640, 128))
	var vertical := img.get_region(Rect2i(836, 40, 128, 640))
	var wrong: Image = vertical.duplicate()
	vertical.rotate_90(COUNTERCLOCKWISE)
	wrong.rotate_90(CLOCKWISE)
	var error := 0.0
	var control := 0.0
	for y in horizontal.get_height():
		for x in horizontal.get_width():
			var a := horizontal.get_pixel(x, y)
			var b := vertical.get_pixel(x, y)
			var c := wrong.get_pixel(x, y)
			error += (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))*255.0/3.0
			control += (absf(a.r-c.r)+absf(a.g-c.g)+absf(a.b-c.b))*255.0/3.0
	var count := float(horizontal.get_width()*horizontal.get_height())
	error /= count
	control /= count
	t.check("bridge_line2d_orientation", error < 0.25 and control > 8.0,
		"native horizontal and vertical tiled decks agree after rotating the bridge (mean RGB error %.4f / 255; limit .25); wrong rotation control %.2f (must exceed 8). Painted grain luma steps along/across: %.2f/%.2f and %.2f/%.2f" % [error, control, hx, hy, vy, vx])


func _label(parent: Node, text: String, pos: Vector2, zoom: float) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", int(11.0 / zoom))
	l.add_theme_color_override("font_color", Color("2b2340"))
	l.z_index = 3000
	parent.add_child(l)


func _pieces_sheets() -> void:
	var t = _t
	var all: Array[String] = []
	for id in _props():
		if not str(id).begins_with("_") and not str(id).ends_with("_night"):
			all.append(str(id))
	all.sort()
	var big := ["platform_disc_171", "platform_disc_184", "platform_disc_196", "platform_disc_306", "trunk_bark_w367", "trunk_bark_w404", "trunk_bark_w441", "trunk_bark_w698",
		"trunk_foot_w367", "trunk_foot_w404", "trunk_foot_w441", "trunk_foot_w698", "trunk_root_w367", "trunk_root_w404", "trunk_root_w441", "trunk_root_w698",
		"foliage_front_a", "foliage_front_b", "canopy_top_strip"]
	for zoom: float in [0.4, 0.2]:
		var world: Vector2 = Vector2(1280.0, 720.0) / zoom
		_begin_scene(zoom, world * 0.5)
		var ids: Array[String] = []
		for id in all:
			if zoom > 0.3 and big.has(id):
				continue
			ids.append(id)
		ids.sort_custom(func(l: String, r: String) -> bool: return (ArtCatalog.prop(StringName(l))["size"] as Vector2).y > (ArtCatalog.prop(StringName(r))["size"] as Vector2).y)
		var gap: float = 22.0 if zoom > 0.3 else 40.0
		var x := 16.0
		var y := 16.0
		var row_h := 0.0
		var placed := 0
		for id in ids:
			var p: Dictionary = ArtCatalog.prop(StringName(id))
			var sz: Vector2 = p["size"]
			if x + sz.x > world.x - 16.0:
				x = 16.0
				y += row_h + 34.0 / zoom * 0.6
				row_h = 0.0
			if str(p["blend"]) == "add":
				var back := ColorRect.new()
				back.color = Color(0.2, 0.17, 0.2)
				back.position = Vector2(x - 4.0, y - 4.0)
				back.size = sz + Vector2(8, 8)
				back.z_index = -10
				_scene.add_child(back)
			_spr(_scene, StringName(id), Vector2(x, y) + (p["pivot"] as Vector2), 0)
			_label(_scene, id.left(18), Vector2(x, y + sz.y + 2.0), zoom)
			x += sz.x + gap
			row_h = maxf(row_h, sz.y)
			placed += 1
		await t.capture("pieces_zoom%s" % str(zoom).replace(".", ""))
		t.check("pieces_sheet_zoom%s" % str(zoom).replace(".", ""), placed >= (40 if zoom > 0.3 else 60) and y + row_h + 40.0 < world.y,
			"%d pieces laid out on grass at the game zoom %.1f (1280 x 720 window)" % [placed, zoom])


func _glow_tex() -> Texture2D:
	return load("res://assets/iso_props/fx/glow_soft.webp") as Texture2D


func _add_glow(parent: Node, pos: Vector2, radius_px: float, col: Color) -> void:
	var tex: Texture2D = _glow_tex()
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2.ONE * (radius_px * 2.0 / float(tex.get_width()))
	s.modulate = col
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	parent.add_child(s)


## the main platform of the city assembled from the real art at zoom 0.4: upper + lower trunk with foot and root, the disc, huts with pennants, the Torvet props, a rope bridge (Line2D deck tile, ropes,
## posts) to a second small platform with the tub (a stand-in between the halves), a ladder, an owl hole with its shelf, a bat house under the rim, lanterns, the lift, front foliage and the canopy
## frame; `night` darkens the canvas and adds the additive layers and halos
func _assembled(night: bool) -> void:
	var t = _t
	var zoom := 0.4
	_begin_scene(zoom, Vector2(520, -40), Color("a9c982"))
	var bd: Dictionary = ArtCatalog.backdrop(&"treetop")
	var sky := Sprite2D.new()
	sky.texture = bd["sky"]
	sky.scale = Vector2(260.0, 3.2)
	sky.position = Vector2(520, -40)
	sky.z_index = -3500
	_scene.add_child(sky)
	for k in 3:
		var far := Sprite2D.new()
		far.texture = bd["far"]
		far.centered = false
		far.scale = Vector2(1.5, 1.5)
		far.position = Vector2(-2200 + 3072 * k, -1500)
		far.z_index = -3400
		_scene.add_child(far)
	var objects := Node2D.new()
	objects.name = "Objects"
	objects.y_sort_enabled = true
	_scene.add_child(objects)
	var floors := Node2D.new()
	_scene.add_child(floors)
	var w := 404
	var bark_id := StringName("trunk_bark_w%d" % w)
	# the lower trunk (behind the disc), its root, the disc of the main platform, the upper trunk with its foot
	_tiled(floors, bark_id, Vector2(-w / 2.0, 100), Rect2(0, 0, float(w), 780.0), -40)
	_spr(floors, StringName("trunk_root_w%d" % w), Vector2(0, 760), -39)
	_spr(floors, &"platform_disc_184", Vector2.ZERO, -20)
	var up_len := 1400.0 - 30.0
	var off := fposmod(512.0 - fposmod(up_len, 512.0), 512.0)
	_tiled(floors, bark_id, Vector2(-w / 2.0, -1400), Rect2(0, off, float(w), up_len), 1)
	_spr(floors, StringName("trunk_foot_w%d" % w), Vector2(0, 0), 1)
	# the second, small platform at the end of the bridge, with its own trunk
	var p2 := Vector2(1780, 330)
	_tiled(floors, &"trunk_bark_w367", Vector2(p2.x - 183.5, p2.y + 90), Rect2(0, 0, 367.0, 700.0), -42)
	_spr(floors, &"platform_disc_171", p2, -22)
	var up2 := 1100.0 - 30.0
	var off2 := fposmod(512.0 - fposmod(up2, 512.0), 512.0)
	_tiled(floors, &"trunk_bark_w367", Vector2(p2.x - 183.5, p2.y - 1100), Rect2(0, off2, 367.0, up2), 1)
	_spr(floors, &"trunk_foot_w367", p2, 1)
	var hut_nodes: Array[Dictionary] = []
	var huts := [["hut_m_straw", Vector2(-390, -30), "pink"], ["hut_s_moss", Vector2(395, -10), ""], ["hut_l_dark", Vector2(p2.x - 250, p2.y - 10), "mint"]]
	for hd in huts:
		var he: Dictionary = ArtCatalog.prop(StringName(hd[0]))
		var raw: Dictionary = (_props()[hd[0]] as Dictionary)
		var hs := _spr(objects, StringName(hd[0]), hd[1] as Vector2, 0)
		hs.y_sort_enabled = false
		hut_nodes.append({"pos": hd[1], "id": hd[0], "night": str(raw.get("night", "")), "pivot": he["pivot"]})
		if str(hd[2]) != "":
			var ap: Array = raw.get("apex", [0, 0])
			var ppos: Vector2 = (hd[1] as Vector2) + Vector2(float(ap[0]), float(ap[1])) - (he["pivot"] as Vector2)
			_spr(objects, StringName("pennant_%s" % hd[2]), ppos, 0)
	_spr(objects, &"market_stall_traetoppen", Vector2(-330, 215), 0)
	var pit := Vector2(-40, 255)
	_spr(objects, &"fire_pit", pit, 0)
	_spr(objects, &"fire_flame", pit + Vector2(0, 24), 1)
	_spr(objects, &"log_stack", Vector2(330, 170), 0)
	_spr(objects, &"notice_board", Vector2(190, 60), 0)
	_spr(objects, &"planter_box", Vector2(170, 270), 0)
	_spr(objects, &"planter_box_berry", Vector2(290, 300), 0)
	_spr(objects, &"seed_basket", Vector2(-190, 280), 0)
	# the rail posts along the front rim of both platforms
	for k in range(-6, 7):
		var ang: float = PI * 0.5 + float(k) * 0.16
		_spr(floors, &"bridge_post", Vector2(cos(ang) * 551.0 * 0.96, sin(ang) * 318.0 * 0.96), 5)
	for k in range(-4, 5):
		var ang2: float = PI * 0.5 + float(k) * 0.2
		_spr(floors, &"bridge_post", p2 + Vector2(cos(ang2) * 514.0 * 0.96, sin(ang2) * 297.0 * 0.96), 5)
	# the bridge: a Line2D with the deck tile, two ropes, posts
	var tex: Texture2D = ArtCatalog.prop(&"bridge_deck_tile_w43")["texture"]
	var a := Vector2(500, 140)
	var b := p2 + Vector2(-480, -40)
	var deck := Line2D.new()
	deck.points = PackedVector2Array([a, b])
	deck.width = 129.0
	deck.texture = tex
	deck.texture_mode = Line2D.LINE_TEXTURE_TILE
	deck.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	deck.default_color = Color.WHITE
	deck.z_index = -10
	floors.add_child(deck)
	var dirv: Vector2 = (b - a).normalized()
	var nrm := Vector2(-dirv.y, dirv.x)
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var n_posts := 10
		for i in n_posts + 1:
			var base: Vector2 = a.lerp(b, float(i) / float(n_posts)) + nrm * side * 64.0
			_spr(floors, &"bridge_post", base, 6)
			pts.append(base + Vector2(0, -72))
			if i < n_posts:
				pts.append(a.lerp(b, (float(i) + 0.5) / float(n_posts)) + nrm * side * 64.0 + Vector2(0, -72 + 14))
		var rope := Line2D.new()
		rope.points = pts
		rope.width = 6.0
		rope.default_color = Color("b08a52")
		rope.z_index = 7
		floors.add_child(rope)
	# the ladder on the trunk face, the owl hole with its shelf, bats and lanterns
	_tiled(objects, &"ladder_tile", Vector2(-30, -560), Rect2(0, 0, 60, 560), 2)
	_spr(floors, &"trunk_hole_owl", Vector2(-110, -820), 2)
	_spr(floors, &"owl_shelf", Vector2(-110, -690), 2)
	var tip := Vector2(-330, 590)
	_spr(floors, &"bat_house_hanging", tip, -30)
	_spr(floors, &"bat_hang", tip + Vector2(0, 26), -30)
	var tub := p2 + Vector2(160, 20)
	_spr(objects, &"bath_tub_back", tub, 4)
	var blob := Polygon2D.new()
	blob.polygon = PackedVector2Array([Vector2(-34, 0), Vector2(-26, -70), Vector2(0, -92), Vector2(26, -70), Vector2(34, 0)])
	blob.color = Color("8a5a32")
	blob.position = tub + Vector2(0, 6)
	blob.z_index = 5
	_scene.add_child(blob)
	_spr(objects, &"bath_tub_front", tub, 6)
	var lamps := [Vector2(-500, 60), Vector2(480, 250), Vector2(80, 330), Vector2(p2.x + 380, p2.y + 150), Vector2(p2.x - 420, p2.y + 200)]
	for lp in lamps:
		_spr(floors, &"lantern_hang", lp, 8)
	_tiled(floors, &"rope_tile", Vector2(1010 - 15, -380), Rect2(0, 0, 30, 560), 3)
	_spr(floors, &"lift_pulley", Vector2(1010, -400), 4)
	_spr(floors, &"lift_basket", Vector2(1010, 170), 5)
	_spr(floors, &"foliage_front_a", Vector2(250, 800), 60)
	_spr(floors, &"foliage_front_b", Vector2(1500, 880), 60)
	var canopy := CanvasLayer.new()
	canopy.layer = 3
	var cs := Sprite2D.new()
	cs.texture = ArtCatalog.prop(&"canopy_top_strip")["texture"]
	cs.centered = false
	cs.scale = Vector2.ONE * (1280.0 / 2048.0)
	canopy.add_child(cs)
	_scene.add_child(canopy)
	if night:
		var cm := CanvasModulate.new()
		cm.color = NIGHT_MOD
		_scene.add_child(cm)
		# the additive layers and the halos live on their own canvas layer that follows the camera, so the modulate does not dim them
		_glow_layer = CanvasLayer.new()
		_glow_layer.layer = 2
		_glow_layer.follow_viewport_enabled = true
		_t.tree.root.add_child(_glow_layer)
		for hn in hut_nodes:
			var nid: String = str(hn["night"])
			if nid != "":
				var pr: Dictionary = ArtCatalog.prop(StringName(nid))
				_spr(_glow_layer, StringName(nid), hn["pos"] as Vector2, 0)
				var raw2: Dictionary = (_props()[hn["id"]] as Dictionary)
				var off3: Array = raw2.get("night_offset", [0, 0])
				_add_glow(_glow_layer, (hn["pos"] as Vector2) + Vector2(float(off3[0]), float(off3[1])) - (hn["pivot"] as Vector2) + (pr["size"] as Vector2) * 0.5, 200.0, Color(1.0, 0.78, 0.4, 0.5))
		for lp in lamps:
			_add_glow(_glow_layer, lp, 150.0, Color(1.0, 0.85, 0.5, 0.8))
		_spr(_glow_layer, &"fire_flame", pit + Vector2(0, 24), 1)
		_add_glow(_glow_layer, pit, 320.0, Color(1.0, 0.6, 0.25, 0.9))
	await t.capture("platform_night" if night else "platform_day")
	t.check("assembled_platform_%s" % ("night" if night else "day"), true, "the main platform assembled from the real art (trunks with foot and root, discs, huts, pennants, props, a Line2D bridge, ladder, tub, owl hole, bat house, lanterns, lift, foliage, canopy)%s: LOOK at platform_%s.png" % [" at dusk with the additive night layers and halos" if night else "", "night" if night else "day"])
	_end_scene()
