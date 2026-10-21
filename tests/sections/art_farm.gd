extends RefCounted
## Section art_farm (package N03-farm-art, M1a stage 2): the farm art kit as shipped in res://assets - the ten farm-only props (assets/iso_props/farm), the two backdrop layers
## farm_far / farm_canopy (assets/backdrops), the untilled terrain field_grass (assets/iso_tiles) - against the measured prototype (design3/farm/art/out/art_budget.txt), the
## TOWNS addendum 3.7 / DT29 / TE9 and the order's S3TC import (kit <= 20 MB of texture memory instead of 56 - 65 MB lossless).
##
## Headless (independent of the Python validator tools/art/environment/farm/validate_farm.py, which implements the same checks a second time):
##   kit_ids_exist  pivots_inside_images  footprints_match_props_extra  sizes_match_art_budget_table  p22_farm_props_have_contract_footprints  props_extra_rows_present
##   backdrop_pair_present  far_seamless_in_x  far_top_edge_soft  canopy_alpha_fade  field_grass_atlas_contract  field_grass_distinct_from_grass
##   import_stubs_written_by_this_package  s3tc_import_set  vram_budget (arithmetic + the size of the imported .s3tc.ctex files)  contact_sheet_looked_at_after_compression (the committed
##   sheets + the verdict)  reused_ids_exist  farm_map_missing_art (ArtCatalog.missing() after building data/maps/farm.map)  no_sky_webp_shadows_the_painted_sky
## Windowed (tests/run_playtest.sh --windowed --only=art_farm, through tools/dev/run_windowed.sh): vram_budget_measured (RENDER_TEXTURE_MEM_USED before / after the kit is loaded and
##   drawn), compression_error_of_the_imported_textures (the textures read back out of the S3TC import against the source files), the contact sheets drawn from the IMPORTED textures,
##   field_grass_seams (grass + field_grass at zoom 0.3 / 0.4 / 0.7 + a negative control), farm_trunks_visible (the real farm at noon / dusk / night, the trunks in the picture).
##
## The ids, footprints and contract are N03's (assets/iso_props/farm/props.json); the files checked are the ones the game draws: ArtCatalog's effective entry of each id.
## The painted consistency pass repaints all ten (same canvases and pivots, except the tool shed: see KIT), and the superseded N03 bakes are not kept (review REND-10).
##
## Honest SKIP lines: the farm SKY is Codex's painted assets/backdrops/farm_sky.png (it lives on main; art_catalog.gd of main loads <theme>_sky.png when no .webp exists).  This package
## ships NO farm_sky.webp (it would shadow it), so on a tree without that file ArtCatalog.backdrop(&"farm").real stays false and the check says so with a SKIP line naming the lead's merge.
const SECTION := "art_farm"
const TIMEOUT_S := 300.0

const FARM_DIR := "res://assets/iso_props/farm/"
const MANIFEST := "res://assets/iso_props/farm/props.json"
const P22_MANIFEST := "res://assets/iso_props/props.json"
const BACKDROP_DIR := "res://assets/backdrops/"
const TILES_DIR := "res://assets/iso_tiles/"
const TOOLS_DIR := "res://tools/art/environment/farm/"
const SHEETS_DIR := "res://tools/art/environment/farm/sheets/"
const MB := 1048576.0
const KIT_BUDGET_MB := 20.0

## id -> [width, height, pivot x, pivot y, footprint x, footprint z]: the measured prototype (design3/farm/art/out/art_budget.txt) and the TOWNS addendum 3.7
const KIT := {
	"trunk_giant_a": [1227, 2405, 622, 2092, 5, 3],
	"trunk_giant_b": [1274, 2142, 685, 1903, 3, 3],
	"trunk_under_a": [907, 1352, 454, 139, 1, 1],
	"trunk_under_b": [746, 1306, 371, 117, 1, 1],
	"tool_shed": [293, 320, 146, 236, 2, 2],     # the painted consistency pass re-canvased the shed (approved in docs/art/style-audit); the prototype measured 316x313 (140,246)
	"shipping_bin": [226, 182, 100, 138, 2, 1],
	"stake_sign": [84, 124, 38, 105, 1, 1],
	"rope_stake_x": [87, 97, 41, 72, 1, 1],
	"rope_stake_z": [87, 97, 41, 72, 1, 1],
	"build_stake": [76, 118, 35, 100, 1, 1],
}
const TRUNKS: Array[String] = ["trunk_giant_a", "trunk_giant_b", "trunk_under_a", "trunk_under_b"]
## design_farm.md 10.3 (the rows of lua/config/props_extra.lua, P22's file): id -> [solid shape, pad or radius, strips]
const ROWS := {
	"trunk_giant_a": ["none", 0, 0], "trunk_giant_b": ["footprint", 0, 12], "trunk_under_a": ["none", 0, 0], "trunk_under_b": ["none", 0, 0],
	"shipping_bin": ["footprint", 8, 0], "tool_shed": ["footprint", 12, 6], "stake_sign": ["circle", 10, 0], "rope_stake_x": ["none", 0, 0],
	"rope_stake_z": ["none", 0, 0], "build_stake": ["none", 0, 0],
}
## the props P22 bakes (this package only ASSERTS them): id -> footprint (TOWNS addendum RT16; "house" of the order = the building slot's animal_house 3x2)
const P22_FOOTPRINTS := {"coop_small": Vector2i(3, 2), "barn_small": Vector2i(4, 3), "animal_house": Vector2i(3, 2), "bench": Vector2i(2, 1), "paw_prints": Vector2i(1, 1)}
const REUSED_PROPS: Array[String] = ["tree_oak_farm", "tree_oak_farm_b", "bush_farm", "rock_grey", "fence_x", "fence_z", "fence_gate_x", "scarecrow", "lantern_post", "bridge_x", "bridge_z",
	"platform_sw", "platform_se", "platform_corner", "tent", "dig_glimmer", "unique_glimmer"]
const CROPS: Array[String] = ["turnip", "carrot", "pumpkin", "moonflower", "strawberry", "sunflower", "catnip", "glow_berry"]
const FARM_ANIMALS: Array[String] = ["chick", "hen", "duck", "kitten", "bunny", "fox_cub", "lamb", "calf", "owl", "puppy", "fawn"]
## the import preset of every file this package ships: file -> [compress/mode, mipmaps/generate]
const IMPORTS := {
	"props": ["2", "true"], "backdrop": ["2", "true"], "tile": ["0", "false"],
}

var _t
var _imgs: Dictionary = {}
var _last_pairs: int = 0


func run(t) -> void:
	_t = t
	ArtCatalog.reset()
	var man: Dictionary = _props_manifest()
	t.check("inputs_present", not man.is_empty(), "assets/iso_props/farm/props.json lists %d props" % man.size())
	if man.is_empty():
		return
	_kit_ids_exist(man)
	_pivots_inside_images(man)
	_footprints_match_props_extra(man)
	_sizes_match_art_budget_table(man)
	_p22_farm_props()
	_props_extra_rows()
	_backdrops()
	_field_grass()
	_imports()
	_vram_headless()
	_contact_sheet_files()
	_reused_ids()
	await _farm_map_missing_art()


# ---------------------------------------------------------------- helpers

func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _props_manifest() -> Dictionary:
	var out: Dictionary = {}
	var d: Variant = _json(MANIFEST)
	if d is Dictionary:
		for k in (d as Dictionary):
			if not str(k).begins_with("_"):
				out[str(k)] = (d as Dictionary)[k]
	return out


func _image(path: String) -> Image:
	if _imgs.has(path):
		return _imgs[path]
	var im: Image = Image.load_from_file(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else null      # an absolute path: a res:// path makes the engine warn ("will not work on export")
	if im != null and not im.is_empty():
		im.convert(Image.FORMAT_RGBA8)
	else:
		im = null
	_imgs[path] = im
	return im


func _pending(label: String, who: String, what: Variant) -> void:
	_t.skip("art_farm.%s PENDING %s: %s" % [label, who, str(what)])


func _fp(e: Dictionary) -> Vector2i:
	var f: Array = GameData.array_of(e.get("footprint", [1, 1]))
	return Vector2i(int(f[0]), int(f[1])) if f.size() >= 2 else Vector2i(1, 1)


## the .import parameters of a res:// asset: {"compress/mode": "2", ...} (empty when there is no .import)
func _import_params(res_path: String) -> Dictionary:
	var out: Dictionary = {}
	var p: String = res_path + ".import"
	if not FileAccess.file_exists(p):
		return out
	var in_params: bool = false
	for raw in FileAccess.get_file_as_string(p).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("["):
			in_params = line == "[params]"
		elif in_params and "=" in line:
			out[line.get_slice("=", 0).strip_edges()] = line.get_slice("=", 1).strip_edges()
	return out


## the dest file of an import ("res://.godot/imported/...ctex"), "" when the asset was not imported
func _import_dest(res_path: String) -> String:
	var p: String = res_path + ".import"
	if not FileAccess.file_exists(p):
		return ""
	for raw in FileAccess.get_file_as_string(p).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("dest_files="):
			var arr: Variant = JSON.parse_string(line.get_slice("=", 1))
			if arr is Array and (arr as Array).size() > 0:
				return str((arr as Array)[0])
	return ""


## The entry the game draws for a kit id (ArtCatalog's effective entry; `_dir` is its pack folder) and its file.
func _kit_entry(id: String) -> Dictionary:
	return ArtCatalog.prop_metadata(StringName(id))


func _kit_path(id: String) -> String:
	var e: Dictionary = _kit_entry(id)
	return str(e.get("_dir", FARM_DIR)) + str(e.get("file", id + ".png"))


## The far layer the game draws: ArtCatalog serves the painted backdrop_farm_far prop (N03's farm_far.webp is superseded and not kept).
func _far_path() -> String:
	var far: Texture2D = ArtCatalog.backdrop(&"farm")["far"]
	return far.resource_path if far != null else BACKDROP_DIR + "farm_far.webp"


func _shipped_files() -> Array[String]:
	var out: Array[String] = []
	for id in KIT:
		out.append(_kit_path(id))
	out.append(_far_path())
	out.append(BACKDROP_DIR + "farm_canopy.webp")
	out.append(TILES_DIR + "field_grass.png")
	return out


func _kind_of(path: String) -> String:
	if path.begins_with(P22_MANIFEST.get_base_dir()):
		return "props"
	if path.begins_with(BACKDROP_DIR):
		return "backdrop"
	return "tile"


# ---------------------------------------------------------------- the ten props

func _kit_ids_exist(man: Dictionary) -> void:
	var t = _t
	var bad: Array[String] = []
	for id in KIT:
		if not man.has(id):
			bad.append("%s: not in props.json" % id)
			continue
		var file: String = _kit_path(id)
		if _image(file) == null:
			bad.append("%s: no readable file %s" % [id, file])
		if not ArtCatalog.has_real_prop(StringName(id)):
			bad.append("%s: ArtCatalog.has_real_prop is false" % id)
			continue
		var res: Dictionary = ArtCatalog.prop(StringName(id))
		if not bool(res.get("real", false)):
			bad.append("%s: ArtCatalog.prop() answers a placeholder" % id)
	var extra: Array[String] = []
	for id in man:
		if not KIT.has(id):
			extra.append(String(id))
	var p22: Dictionary = {}
	var d: Variant = _json(P22_MANIFEST)
	if d is Dictionary:
		p22 = d
	var shadow: Array[String] = []
	for id in KIT:
		if p22.has(id):
			shadow.append(String(id))
	t.check("kit_ids_exist", bad.is_empty() and extra.is_empty() and shadow.is_empty(),
		"the ten farm-only props (4 trunks, tool_shed, shipping_bin, stake_sign, rope_stake_x / z, build_stake) are in assets/iso_props/farm/props.json with a readable png and real art in ArtCatalog; no foreign id (%s), none of them in P22's props.json (%s); problems: %s" % [str(extra), str(shadow), str(bad)])


func _pivots_inside_images(man: Dictionary) -> void:
	var bad: Array[String] = []
	for id in KIT:
		if not man.has(id):
			continue
		var e: Dictionary = _kit_entry(id)
		var c: Array = KIT[id]
		var im: Image = _image(_kit_path(id))
		if im == null:
			bad.append("%s: %s unreadable" % [id, _kit_path(id)])
			continue
		var size: Array = GameData.array_of(e.get("size", []))
		var pivot: Array = GameData.array_of(e.get("pivot", []))
		if size.size() < 2 or pivot.size() < 2:
			bad.append("%s: size / pivot missing" % id)
			continue
		if int(size[0]) != im.get_width() or int(size[1]) != im.get_height():
			bad.append("%s: size %s != image %dx%d" % [id, str(size), im.get_width(), im.get_height()])
		var px: int = int(pivot[0])
		var py: int = int(pivot[1])
		if px < 0 or px >= im.get_width() or py < 0 or py >= im.get_height():
			bad.append("%s: pivot %s outside the image" % [id, str(pivot)])
			continue
		if px != int(c[2]) or py != int(c[3]):
			bad.append("%s: pivot %s, contract (%d, %d)" % [id, str(pivot), int(c[2]), int(c[3])])
		# A rope's ground centre is between its two posts. Allow that opening and
		# narrow pencil contours, while still rejecting a visibly floating body.
		var nearby := false
		var radius := 12 if str(id).begins_with("rope_stake_") else 2
		for oy in range(-radius, radius + 1):
			for ox in range(-radius, radius + 1):
				if ox * ox + oy * oy <= radius * radius and im.get_pixel(clampi(px + ox, 0, im.get_width() - 1), clampi(py + oy, 0, im.get_height() - 1)).a >= 0.12:
					nearby = true
		if not nearby:
			bad.append("%s: no painted contact near the ground pivot" % id)
	_t.check("pivots_inside_images", bad.is_empty(), "every prop: size = image size, ground-origin pivot inside the image, on drawn pixels and equal to the measured prototype (trunk_giant_a (622, 2092), trunk_under_a (454, 139) = the deck plane ...): %s" % str(bad))


func _footprints_match_props_extra(man: Dictionary) -> void:
	var bad: Array[String] = []
	for id in KIT:
		var e: Dictionary = man.get(id, {})
		if e.is_empty():
			continue
		var c: Array = KIT[id]
		var want := Vector2i(int(c[4]), int(c[5]))
		var row_fp: Vector2i = GameData.footprint_of(id)
		if _fp(e) != want or row_fp != want:
			bad.append("%s: baked %s, props_extra row %s, contract %s" % [id, str(_fp(e)), str(row_fp), str(want)])
	_t.check("footprints_match_props_extra", bad.is_empty(), "the baked footprint of every prop = the footprint of its lua/config/props_extra.lua row = the contract (trunk_giant_a 5x3, trunk_giant_b 3x3, tool_shed 2x2, shipping_bin 2x1, the rest 1x1): %s" % str(bad))


## art_budget.txt of this folder = the table produced from the shipped files by art_budget.py; its rows are compared with the prototype's numbers (KIT) and with the files
func _sizes_match_art_budget_table(man: Dictionary) -> void:
	var txt: String = FileAccess.get_file_as_string(TOOLS_DIR + "art_budget.txt") if FileAccess.file_exists(TOOLS_DIR + "art_budget.txt") else ""
	var re := RegEx.new()
	re.compile("(?m)^(props|back|tiles)\\s+(\\S+)\\s+(\\d+)\\s+(\\d+)\\s+(\\[\\d+, \\d+\\]|-)")
	var rows: Dictionary = {}
	for m in re.search_all(txt):
		rows[m.get_string(2)] = [int(m.get_string(3)), int(m.get_string(4)), m.get_string(5)]
	var bad: Array[String] = []
	for id in KIT:
		var c: Array = KIT[id]
		if not rows.has(id):
			bad.append("%s: no row in art_budget.txt" % id)
			continue
		var r: Array = rows[id]
		if int(r[0]) != int(c[0]) or int(r[1]) != int(c[1]) or str(r[2]) != "[%d, %d]" % [int(c[2]), int(c[3])]:
			bad.append("%s: table %s, prototype %s" % [id, str(r), str(c)])
		var im: Image = _image(_kit_path(id))
		if im == null or im.get_width() != int(c[0]) or im.get_height() != int(c[1]):
			bad.append("%s: file %s, prototype %dx%d" % [id, "unreadable" if im == null else "%dx%d" % [im.get_width(), im.get_height()], int(c[0]), int(c[1])])
	var back: Dictionary = {"farm_far.webp": [2048, 1024], "farm_canopy.webp": [2048, 360], "field_grass.png": [576, 336]}
	for f in back:
		var im2: Image = _image(_far_path() if f == "farm_far.webp" else (BACKDROP_DIR if str(f).ends_with(".webp") else TILES_DIR) + str(f))
		var r2: Array = rows.get(f, [])
		var want: Array = back[f]
		if im2 == null or im2.get_width() != int(want[0]) or im2.get_height() != int(want[1]) or r2.size() < 2 or int(r2[0]) != int(want[0]) or int(r2[1]) != int(want[1]):
			bad.append("%s: %s file, table %s, prototype %s" % [f, "unreadable" if im2 == null else "%dx%d" % [im2.get_width(), im2.get_height()], str(r2), str(want)])
	_t.check("sizes_match_art_budget_table", bad.is_empty() and man.size() == KIT.size(),
		"every w x h and pivot of tools/art/environment/farm/art_budget.txt (made from the shipped files) = the measured prototype table (trunk_giant_a 1227x2405 (622,2092), trunk_giant_b 1274x2142 (685,1903), trunk_under_a 907x1352 (454,139), trunk_under_b 746x1306 (371,117), tool_shed 293x320 (146,236) as painted, shipping_bin 226x182 (100,138), stake_sign 84x124 (38,105), rope_stake 87x97 (41,72), build_stake 76x118 (35,100), farm_far 2048x1024, farm_canopy 2048x360, field_grass 576x336) = the files: %s" % str(bad))


func _p22_farm_props() -> void:
	var bad: Array[String] = []
	for id in P22_FOOTPRINTS:
		var want: Vector2i = P22_FOOTPRINTS[id]
		if not ArtCatalog.has_real_prop(StringName(id)):
			bad.append("%s: no real art (P22 bakes it)" % id)
			continue
		var res: Dictionary = ArtCatalog.prop(StringName(id))
		if (res["footprint"] as Vector2i) != want or GameData.footprint_of(id) != want:
			bad.append("%s: art %s row %s, contract %s" % [id, str(res["footprint"]), str(GameData.footprint_of(id)), str(want)])
	_t.check("p22_farm_props_have_contract_footprints", bad.is_empty(),
		"P22 bakes coop_small 3x2, barn_small 4x3, animal_house 3x2 (the house slot), bench 2x1, paw_prints 1x1 - this package only ASSERTS that the art exists with those footprints (it never bakes them): %s" % str(bad))
	# and none of them is in this package's folder
	var dup: Array[String] = []
	for id in P22_FOOTPRINTS:
		if FileAccess.file_exists(FARM_DIR + String(id) + ".png"):
			dup.append(String(id))
	_t.check("p22_props_not_rebaked_here", dup.is_empty(), "assets/iso_props/farm/ holds no P22 prop: %s" % str(dup))


func _props_extra_rows() -> void:
	var extra: Dictionary = GameData.dict_of(GameData.cfg("props_extra", {}))
	var bad: Array[String] = []
	for id in ROWS:
		if not extra.has(id):
			bad.append("%s: no row in props_extra" % id)
			continue
		var def: Dictionary = GameData.prop_def(id)
		var solid: Dictionary = GameData.dict_of(def.get("solid", {}))
		var r: Array = ROWS[id]
		var num: int = int(solid.get("radius", solid.get("pad", 0)))
		if str(solid.get("shape", "")) != str(r[0]) or num != int(r[1]) or int(def.get("strips", -1)) != int(r[2]):
			bad.append("%s: solid %s %d strips %s, design_farm 10.3 says %s" % [id, str(solid.get("shape", "?")), num, str(def.get("strips", "?")), str(r)])
	# the keys belong to P22's lua/config/props_extra.lua: this package ships no Lua at all
	var lua_here: Array[String] = []
	var d := DirAccess.open(TOOLS_DIR)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".lua"):
				lua_here.append(f)
	_t.check("props_extra_rows_present", bad.is_empty() and lua_here.is_empty(),
		"the ten rows of design_farm.md 10.3 (trunk_giant_b solid footprint pad 0 strips 12, tool_shed footprint pad 12 strips 6, shipping_bin footprint pad 8, stake_sign circle 10, the other six no collider) are in lua/config/props_extra.lua (P22's file); this package defines no Lua key (%s): %s" % [str(lua_here), str(bad)])


# ---------------------------------------------------------------- backdrops

func _backdrops() -> void:
	var t = _t
	var far: Image = _image(_far_path())
	var can: Image = _image(BACKDROP_DIR + "farm_canopy.webp")
	var bad: Array[String] = []
	if far == null or far.get_width() != 2048 or far.get_height() != 1024:
		bad.append("farm_far.webp %s, want 2048x1024" % ("unreadable" if far == null else "%dx%d" % [far.get_width(), far.get_height()]))
	if can == null or can.get_width() != 2048 or can.get_height() != 360:
		bad.append("farm_canopy.webp %s, want 2048x360" % ("unreadable" if can == null else "%dx%d" % [can.get_width(), can.get_height()]))
	var art: Dictionary = ArtCatalog.backdrop(&"farm")
	var far_tex: Texture2D = art["far"]
	if far_tex == null or far_tex.get_width() != 2048 or far_tex.get_height() != 1024:
		bad.append("ArtCatalog.backdrop(farm).far is not farm_far.webp (%s)" % str(far_tex.get_size() if far_tex != null else "null"))
	t.check("backdrop_pair_present", bad.is_empty(),
		"the Parallax2D far layer farm_far.webp 2048x1024 and the foreground frame farm_canopy.webp 2048x360 exist and ArtCatalog.backdrop(&\"farm\") serves the real far layer: %s" % str(bad))
	# the sky: no farm_sky.webp may be shipped (it would shadow Codex's painted farm_sky.png); the catalog decides whether the pair is complete
	var webp_sky: bool = FileAccess.file_exists(BACKDROP_DIR + "farm_sky.webp")
	t.check("no_sky_webp_shadows_the_painted_sky", not webp_sky and not FileAccess.file_exists(BACKDROP_DIR + "farm_sky.webp.import"),
		"assets/backdrops/farm_sky.webp does not exist (lead amendment M1a: ArtCatalog loads <theme>_sky.webp before <theme>_sky.png, a webp here would hide Codex's painted farm_sky.png)")
	var has_png_sky: bool = FileAccess.file_exists(BACKDROP_DIR + "farm_sky.png")
	if has_png_sky:
		t.check("backdrop_farm_is_real_through_the_catalog", bool(art.get("real", false)), "farm_sky.png + farm_far.webp: ArtCatalog.backdrop(&\"farm\").real = %s (art_catalog.gd must fall back to <theme>_sky.png)" % str(art.get("real", false)))
	else:
		_pending("backdrop_farm_is_real_through_the_catalog", "the lead's merge of Codex's farm_sky.png (main)", "this tree has no assets/backdrops/farm_sky.png, so ArtCatalog.backdrop(&\"farm\").real = %s and P04's gradient sky stands in behind the real far layer; N03 must not ship farm_sky.webp" % str(art.get("real", false)))
	if far != null:
		_far_checks(far)
	if can != null:
		_canopy_checks(can)


## the premultiplied colour difference of two pixels on the 0..255 scale (a transparent pixel's RGB is meaningless)
func _pdiff(a: Color, b: Color) -> float:
	return (absf(a.r * a.a - b.r * b.a) + absf(a.g * a.a - b.g * b.a) + absf(a.b * a.a - b.b * b.a) + absf(a.a - b.a)) / 4.0 * 255.0


func _far_checks(far: Image) -> void:
	_far_top_soft_check(far)
	var w: int = far.get_width()
	var h: int = far.get_height()
	var seam: float = 0.0
	var inner: float = 0.0
	var across: float = 0.0
	var n: int = 0
	for y in range(0, h, 8):
		seam += _pdiff(far.get_pixel(0, y), far.get_pixel(w - 1, y))
		for x in [200, 500, 800, 1100, 1400, 1700]:
			inner += _pdiff(far.get_pixel(x, y), far.get_pixel(x + 1, y)) / 6.0
		across += _pdiff(far.get_pixel(0, y), far.get_pixel(int(w * 0.5), y))
		n += 1
	seam /= float(n)
	inner /= float(n)
	across /= float(n)
	_t.check("far_seamless_in_x", seam < 3.0 and across > 3.0 * seam,
		"the far layer repeats in x (Parallax2D): the step between its last and first column is %.2f / 255 (premultiplied; two neighbouring columns inside the image differ by %.2f, limit 3.0), and the probe can see a break: columns 0 and %d differ by %.1f" % [seam, inner, int(w * 0.5), across])


func _alpha_row(im: Image, y: int) -> Vector2:
	var s: float = 0.0
	var m: float = 0.0
	for x in range(0, im.get_width(), 2):
		var a: float = im.get_pixel(x, y).a
		s += a
		m = maxf(m, a)
	return Vector2(s / (float(im.get_width()) * 0.5), m)


func _far_top_soft_check(far: Image) -> void:
	var a0: float = _alpha_row(far, 0).x
	var a100: float = _alpha_row(far, 100).x
	var a200: float = _alpha_row(far, 200).x
	var a300: float = _alpha_row(far, 300).x
	var max_alpha := 0.0
	var max_step := 0.0
	var previous := a0
	for y in range(1, far.get_height()):
		var current := _alpha_row(far, y).x
		max_alpha = maxf(max_alpha, current)
		max_step = maxf(max_step, absf(current - previous))
		previous = current
	_t.check("far_top_edge_soft", a0 < 0.01 and max_alpha > 0.15 and max_step < 0.12,
		"the layer starts in the middle of the screen: its top row is transparent (%.3f) and the mean alpha rises softly (row 100 %.2f, 200 %.2f, 300 %.2f)" % [a0, a100, a200, a300])


func _canopy_checks(can: Image) -> void:
	var h: int = can.get_height()
	var top: float = _alpha_row(can, 0).x
	var mid: float = _alpha_row(can, 150).x
	var a200: float = _alpha_row(can, 200).x
	var a270: float = _alpha_row(can, 270).x
	var a300: float = _alpha_row(can, 300).x
	var last: Vector2 = _alpha_row(can, h - 1)
	var tail_max: float = 0.0
	for y in range(h - 30, h):
		tail_max = maxf(tail_max, _alpha_row(can, y).y)
	_t.check("canopy_alpha_fade", top > 0.8 and mid > 0.5 and a200 < mid and a270 < a200 and a300 < 0.15 and last.y == 0.0 and tail_max < 0.01,
		"the leaf frame is solid at the top of the screen (row 0 mean alpha %.2f) and its lower edge fades out (row 150 %.2f, 200 %.2f, 270 %.2f, 300 %.3f; the last row is fully transparent: max %.2f; the last 30 rows max %.2f)" % [top, mid, a200, a270, a300, last.y, tail_max])


# ---------------------------------------------------------------- field_grass

func _field_grass() -> void:
	var t = _t
	var tiles: Variant = _json(TILES_DIR + "tiles_farm.json")
	var bad: Array[String] = []
	var e: Dictionary = {}
	if tiles is Dictionary and (tiles as Dictionary).get("field_grass", null) is Dictionary:
		e = (tiles as Dictionary)["field_grass"]
	else:
		bad.append("tiles_farm.json has no field_grass entry")
	var cell: Array = GameData.array_of(e.get("cell", []))
	var variants: Array = GameData.array_of(e.get("variants", []))
	if cell.size() < 2 or int(cell[0]) != 144 or int(cell[1]) != 84:
		bad.append("cell %s, want [144, 84]" % str(cell))
	if variants.size() < 2 or int(variants[0]) != 4 or int(variants[1]) != 4:
		bad.append("variants %s, want [4, 4]" % str(variants))
	var im: Image = _image(TILES_DIR + "field_grass.png")
	if im == null or im.get_width() != 576 or im.get_height() != 336:
		bad.append("field_grass.png %s, want 576x336 (4 x 4 periodic cells of 144 x 84)" % ("unreadable" if im == null else "%dx%d" % [im.get_width(), im.get_height()]))
	else:
		# every one of the 16 cells: a diamond (transparent corners, opaque centre), not blank
		for j in 4:
			for i in 4:
				var ox: int = i * 144
				var oy: int = j * 84
				var corner_clear: bool = im.get_pixel(ox, oy).a < 0.02 and im.get_pixel(ox + 143, oy).a < 0.02 and im.get_pixel(ox, oy + 83).a < 0.02 and im.get_pixel(ox + 143, oy + 83).a < 0.02
				var centre_solid: bool = im.get_pixel(ox + 72, oy + 42).a > 0.98 and im.get_pixel(ox + 72, oy + 12).a > 0.98
				if not (corner_clear and centre_solid):
					bad.append("cell (%d, %d) is not a filled diamond" % [i, j])
	var res: Dictionary = ArtCatalog.terrain(&"field_grass")
	if not bool(res.get("real", false)) or (res["cell"] as Vector2i) != Vector2i(144, 84) or (res["variants"] as Vector2i) != Vector2i(4, 4):
		bad.append("ArtCatalog.terrain(field_grass) is %s" % ("a placeholder" if not bool(res.get("real", false)) else "cell %s variants %s" % [str(res["cell"]), str(res["variants"])]))
	var prm: Dictionary = _import_params(TILES_DIR + "field_grass.png")
	if str(prm.get("mipmaps/generate", "")) != "false" or str(prm.get("compress/mode", "")) != "0":
		bad.append("import: compress/mode %s mipmaps/generate %s, want 0 / false (periodic cells bleed into each other at mip >= 1)" % [str(prm.get("compress/mode", "?")), str(prm.get("mipmaps/generate", "?"))])
	t.check("field_grass_atlas_contract", bad.is_empty(),
		"tiles_farm.json {field_grass: cell [144, 84], variants [4, 4]}, field_grass.png 576x336 = 16 periodic diamond cells, ArtCatalog.terrain(field_grass) is real, imported lossless WITHOUT mipmaps: %s" % str(bad.slice(0, 5)))
	var g: Image = _image(TILES_DIR + "grass.png")
	if im == null or g == null:
		t.check("field_grass_distinct_from_grass", false, "field_grass.png or grass.png is unreadable")
		return
	var sf: Dictionary = _atlas_stats(im)
	var sg: Dictionary = _atlas_stats(g)
	var dist: float = (absf(sf["r"] - sg["r"]) + absf(sf["g"] - sg["g"]) + absf(sf["b"] - sg["b"])) / 3.0
	t.check("field_grass_distinct_from_grass", dist >= 6.0 and sf["lum"] > sg["lum"] + 4.0 and sf["dy"] > 0.25,
		"painted untilled field stays distinct and textured: colour distance %.1f / 255 (>= 6), lighter by %.1f (>= 4), vertical pigment variation %.2f (> .25)" % [dist, sf["lum"] - sg["lum"], sf["dy"]])


## mean colour and mean vertical luminance step of the opaque pixels of an atlas (sampled every 2nd pixel)
func _atlas_stats(im: Image) -> Dictionary:
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	var dy: float = 0.0
	var n: int = 0
	for y in range(1, im.get_height(), 2):
		for x in range(0, im.get_width(), 2):
			var c: Color = im.get_pixel(x, y)
			var u: Color = im.get_pixel(x, y - 1)
			if c.a < 0.98 or u.a < 0.98:
				continue
			r += c.r * 255.0
			g += c.g * 255.0
			b += c.b * 255.0
			dy += absf((c.r + c.g + c.b) - (u.r + u.g + u.b)) / 3.0 * 255.0
			n += 1
	var k: float = float(maxi(n, 1))
	return {"r": r / k, "g": g / k, "b": b / k, "lum": (0.2126 * r + 0.7152 * g + 0.0722 * b) / k, "dy": dy / k}


# ---------------------------------------------------------------- import stubs, S3TC, memory

func _imports() -> void:
	var t = _t
	var tool_here: bool = FileAccess.file_exists(TOOLS_DIR + "write_farm_imports.py")
	var missing: Array[String] = []
	var wrong: Array[String] = []
	for path in _shipped_files():
		var want: Array = IMPORTS[_kind_of(path)]
		var prm: Dictionary = _import_params(path)
		if prm.is_empty():
			missing.append(path.get_file())
			continue
		if str(prm.get("compress/mode", "")) != str(want[0]) or str(prm.get("mipmaps/generate", "")) != str(want[1]):
			wrong.append("%s: compress/mode %s mipmaps %s, want %s / %s" % [path.get_file(), str(prm.get("compress/mode", "?")), str(prm.get("mipmaps/generate", "?")), str(want[0]), str(want[1])])
	t.check("import_stubs_written_by_this_package", tool_here and missing.is_empty(),
		"tools/art/environment/farm/write_farm_imports.py exists and every file of the kit the game draws carries an .import (tools/import/write_import_stubs.py --check holds them to the import policy): missing %s" % str(missing))
	var ps: Variant = ProjectSettings.get_setting("rendering/textures/vram_compression/import_s3tc_bptc", false)
	var imported_as_vram: Array[String] = []
	for path in _shipped_files():
		if _kind_of(path) == "tile":
			continue
		var txt: String = FileAccess.get_file_as_string(path + ".import") if FileAccess.file_exists(path + ".import") else ""
		if not ("path.s3tc=" in txt and "\"vram_texture\": true" in txt):
			imported_as_vram.append(path.get_file())
	t.check("s3tc_import_set", wrong.is_empty() and bool(ps) and imported_as_vram.is_empty(),
		"the four trunks, the other six props, farm_far and farm_canopy use compress/mode=2 (VRAM compressed S3TC) with mipmaps, high_quality off; only field_grass.png stays lossless without mipmaps; project.godot import_s3tc_bptc = %s; Godot really imported them as s3tc (.import has path.s3tc + vram_texture): wrong %s, not imported as VRAM %s" % [str(ps), str(wrong), str(imported_as_vram)])


## texture memory by arithmetic from the import parameters (S3TC DXT5 = 1 byte per pixel, RGBA8 = 4, mipmaps x 4/3) and from the size of the imported .ctex files on disk
func _vram_estimate() -> Dictionary:
	var comp: float = 0.0
	var lossless: float = 0.0
	var trunks: float = 0.0
	var ctex: float = 0.0
	var ctex_missing: Array[String] = []
	for path in _shipped_files():
		var im: Image = _image(path)
		if im == null:
			continue
		var prm: Dictionary = _import_params(path)
		var px: float = float(im.get_width() * im.get_height())
		var mip: float = 4.0 / 3.0 if str(prm.get("mipmaps/generate", "false")) == "true" else 1.0
		var bytes_per_px: float = 1.0 if str(prm.get("compress/mode", "0")) == "2" else 4.0
		comp += px * bytes_per_px * mip
		lossless += px * 4.0 * mip
		if path.get_file().get_basename() in TRUNKS:
			trunks += px * bytes_per_px * mip
		var dest: String = _import_dest(path)
		if dest == "" or not FileAccess.file_exists(dest):
			ctex_missing.append(path.get_file())
		else:
			var f := FileAccess.open(dest, FileAccess.READ)
			ctex += float(f.get_length())
	return {"compressed": comp / MB, "lossless": lossless / MB, "trunks": trunks / MB, "ctex": ctex / MB, "ctex_missing": ctex_missing}


func _vram_headless() -> void:
	var e: Dictionary = _vram_estimate()
	var comp: float = e["compressed"]
	var ctex: float = e["ctex"]
	var cm: Array = e["ctex_missing"]
	_t.check("vram_budget", comp <= KIT_BUDGET_MB and cm.is_empty() and ctex <= KIT_BUDGET_MB * 1.05 and float(e["lossless"]) > 2.5 * comp,
		"the kit costs %.1f MB of texture memory with the S3TC import (%.1f MB of it the four trunks) against %.1f MB lossless (prototype measured 15.8 / 65.5 with the farm_sky this package does not ship); the imported .ctex files weigh %.1f MB on disk; budget %.0f MB. ctex missing: %s (windowed: vram_budget_measured reads RENDER_TEXTURE_MEM_USED)" % [comp, float(e["trunks"]), float(e["lossless"]), ctex, KIT_BUDGET_MB, str(cm)])


# ---------------------------------------------------------------- contact sheets

func _contact_sheet_files() -> void:
	var readme: String = FileAccess.get_file_as_string(TOOLS_DIR + "README.md") if FileAccess.file_exists(TOOLS_DIR + "README.md") else ""
	var sheets: Array[String] = ["art_farm_contact_big.png", "art_farm_contact_small.png"]
	var bad: Array[String] = []
	for s in sheets:
		var im: Image = _image(SHEETS_DIR + s)
		if im == null or im.get_width() < 600 or im.get_height() < 300:
			bad.append("%s missing or tiny" % s)
	var verdict: bool = "looked at after the S3TC import" in readme and "known weaknesses" in readme.to_lower() and "accepted at" in readme and "style gap" in readme.to_lower()
	_t.check("contact_sheet_looked_at_after_compression", bad.is_empty() and verdict,
		"the committed contact sheets (tools/art/environment/farm/sheets/art_farm_contact_big.png + _small.png) were drawn from the textures read back out of the IMPORTED S3TC files (windowed: contact_sheets_from_imported_textures) and the README carries the verdict ('looked at after the S3TC import', the style gap to the guide, known weaknesses): %s%s" % [str(bad), "" if verdict else " (README verdict missing)"])


# ---------------------------------------------------------------- reuse list

func _reused_ids() -> void:
	var t = _t
	var bad: Array[String] = []
	var n: int = 0
	for id in REUSED_PROPS:
		n += 1
		if not ArtCatalog.has_real_prop(StringName(id)):
			bad.append("prop:%s" % id)
	if ArtCatalog.prop(&"lantern_post").get("glow", {}).is_empty():
		bad.append("lantern_post has no glow")
	for c in CROPS:
		for stage in 4:
			n += 1
			if not ArtCatalog.has_real_prop(StringName("crop_%s_%d" % [c, stage])):
				bad.append("crop_%s_%d" % [c, stage])
	# A1: house_t01..t10 + night layers + the nine scaffolds + the tent, the glimmers
	var home: Variant = _json("res://assets/iso_props/home/home.json")
	var tiers: Array = []
	if home is Dictionary:
		tiers = GameData.array_of((home as Dictionary).get("tiers", []))
	if tiers.size() != 10:
		bad.append("home.json has %d tiers, want 10" % tiers.size())
	for tr in tiers:
		var td: Dictionary = GameData.dict_of(tr)
		var ex: Dictionary = GameData.dict_of(td.get("exterior", {}))
		for f in [str(ex.get("day", "")), str(ex.get("night", ""))]:
			n += 1
			if f == "" or not FileAccess.file_exists("res://assets/iso_props/home/" + f):
				bad.append("home/%s" % f)
		if int(td.get("tier", 0)) >= 2:
			var sc: Dictionary = GameData.dict_of(td.get("scaffold_from_previous", {}))
			n += 1
			if not FileAccess.file_exists("res://assets/iso_props/home/" + str(sc.get("file", "_"))):
				bad.append("home scaffold of tier %d" % int(td.get("tier", 0)))
	# P21: the farm animals, the hedgehog bust and Fekongen's portrait for the first morning
	for a in FARM_ANIMALS:
		n += 1
		if not ArtCatalog.character_exists(a):
			bad.append("character:%s" % a)
	for pf in ["res://assets/portraits/hedgehog.webp", "res://assets/isometric_characters/fairy_king/portrait.webp"]:
		n += 1
		if not FileAccess.file_exists(pf):
			bad.append(pf.get_file())
	t.check("reused_ids_exist", bad.is_empty(),
		"nothing of the reuse list is re-baked here, and all %d of it exists: the spike props (trees, bush, rock, fences + gate, scarecrow, lantern post + glow, both bridges, the three platform skirts), the 8 crops x 4 stages, A1's house_t01..t10 + night layers + 9 scaffolds + tent + dig / unique glimmers, P21's 11 farm animals, the pack hedgehog bust and fairy_king's portrait: missing %s" % [n, str(bad)])


# ---------------------------------------------------------------- the farm map

func _farm_map_missing_art() -> void:
	var t = _t
	if not WorldRoot2D.has_area(&"farm"):
		_pending("farm_map_missing_art", "N01-farm-map", "data/maps/farm.map does not exist")
		return
	if not await t.start_world():
		return
	var w: WorldRoot2D = t.world()
	w._enter(&"_fixture_iso", &"default")
	w.free_parked_areas()
	ArtCatalog.reset()
	AreaTileSet.reset()
	w._enter(&"farm", &"default")
	await t.frames(2)
	var miss: Array[String] = ArtCatalog.missing()
	var sky_pending: bool = not FileAccess.file_exists(BACKDROP_DIR + "farm_sky.png")
	var strict: Array[String] = []
	for m in miss:
		if m == "backdrop:farm" and sky_pending:
			continue
		strict.append(m)
	t.check("farm_map_missing_art", strict.is_empty(),
		"data/maps/farm.map builds with ArtCatalog.missing() empty (every terrain incl. field_grass, every prop incl. the trunks, the backdrop incl. the far layer): missing %s" % str(strict))
	if "backdrop:farm" in miss and sky_pending:
		_pending("farm_map_missing_art", "the lead's merge of Codex's farm_sky.png (main)", "backdrop:farm stays in missing() on this tree only because assets/backdrops/farm_sky.png is not here (N03 ships farm_far.webp and must not ship farm_sky.webp)")
	# the ten ids and the terrain are real art even where this map does not draw them yet (N02 draws the pillars, bin, shed and stakes)
	var unreal: Array[String] = []
	for id in KIT:
		if not bool(ArtCatalog.prop(StringName(id)).get("real", false)):
			unreal.append(String(id))
	if not bool(ArtCatalog.terrain(&"field_grass").get("real", false)):
		unreal.append("terrain:field_grass")
	t.check("kit_is_real_art_in_the_catalog", unreal.is_empty(), "ArtCatalog serves real art for all ten props and the terrain field_grass: placeholders %s" % str(unreal))


# ================================================================== windowed (tests/run_playtest.sh --windowed --only=art_farm)

func run_windowed(t) -> void:
	_t = t
	ArtCatalog.reset()
	if not await t.start_world():
		return
	var w: WorldRoot2D = t.world()
	await _vram_measured(t)
	await _compression_and_sheets(t)
	await _field_seams(t, w)
	await _farm_pictures(t, w)


## RENDER_TEXTURE_MEM_USED before / after the whole kit is loaded through the catalog and drawn once
func _vram_measured(t) -> void:
	# a clean baseline: leave the farm (its own props and its far layer are already resident), drop every parked area and the catalog, stand in the ortho fixture (no backdrop)
	var w: WorldRoot2D = t.world()
	w._enter(&"_fixture_ortho", &"default")
	w.free_parked_areas()
	ArtCatalog.reset()
	AreaTileSet.reset()
	await t.frames(30)
	var m0: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / MB
	var holder := Node2D.new()
	holder.position = Vector2(-20000, -20000)
	t.root.add_child(holder)
	var kit_mb: float = 0.0
	var parts: Dictionary = {}
	for group in ["trunks", "props", "backdrops", "field"]:
		var before: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / MB
		var textures: Array[Texture2D] = []
		match group:
			"trunks":
				for id in TRUNKS:
					textures.append(ArtCatalog.prop(StringName(id))["texture"])
			"props":
				for id in KIT:
					if not TRUNKS.has(String(id)):
						textures.append(ArtCatalog.prop(StringName(id))["texture"])
			"backdrops":
				var bd: Dictionary = ArtCatalog.backdrop(&"farm")
				textures.append(bd["far"])
				textures.append(load(BACKDROP_DIR + "farm_canopy.webp") as Texture2D)
			"field":
				textures.append(ArtCatalog.terrain(&"field_grass")["texture"])
		for tex in textures:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			holder.add_child(s)
		await t.frames(20)
		var after: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / MB
		parts[group] = after - before
		kit_mb += after - before
	t.info("ART_FARM_VRAM baseline %.1f MB; kit: trunks %.1f, other props %.1f, backdrops %.1f, field_grass %.1f = %.1f MB (arithmetic %.1f MB, lossless %.1f MB)" % [
		m0, parts["trunks"], parts["props"], parts["backdrops"], parts["field"], kit_mb, float(_vram_estimate()["compressed"]), float(_vram_estimate()["lossless"])])
	holder.queue_free()
	await t.frames(10)
	var freed: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / MB
	t.info("ART_FARM_VRAM after freeing the sprites: %+.1f MB vs the baseline (the catalog keeps its textures)" % (freed - m0))
	t.check("vram_budget_measured", kit_mb > 5.0 and kit_mb <= KIT_BUDGET_MB,
		"texture memory of the whole kit read from Performance.RENDER_TEXTURE_MEM_USED in a real window: %.1f MB (budget %.0f MB; lossless would be %.1f MB; > 5 MB proves the probe sees the upload)" % [kit_mb, KIT_BUDGET_MB, float(_vram_estimate()["lossless"])])


## the textures read back out of the S3TC import against the source files, and the contact sheets drawn from those (decompressed) images
func _compression_and_sheets(t) -> void:
	var worst: float = 0.0
	var worst_id: String = ""
	var bad_err: Array[String] = []
	var decoded: Dictionary = {}
	var control_error := 0.0
	var lines: Array[String] = []
	var sources: Dictionary = {}
	for id in KIT:
		var entry := ArtCatalog.prop_metadata(StringName(id))
		sources[id] = str(entry.get("_dir",""))+str(entry.get("file",""))
	sources["farm_far"] = (ArtCatalog.backdrop(&"farm")["far"] as Texture2D).resource_path
	sources["farm_canopy"] = BACKDROP_DIR + "farm_canopy.webp"
	var max_zoom := AreaMap.load_file("res://data/maps/farm.map").zoom_range().y
	for key in sources:
		var path: String = sources[key]
		var tex: Texture2D = load(path) as Texture2D
		var img: Image = tex.get_image() if tex != null else null
		if img == null or img.is_empty():
			lines.append("%s: no image back from the texture" % path.get_file())
			continue
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var src: Image = _image(path)
		# S3TC stores whole 4 x 4 blocks: the decoded image is padded to a multiple of 4, the art is the top-left corner
		if src == null or img.get_width() < src.get_width() or img.get_height() < src.get_height() or img.get_width() - src.get_width() > 3 or img.get_height() - src.get_height() > 3:
			lines.append("%s: decoded %dx%d vs source" % [path.get_file(), img.get_width(), img.get_height()])
			continue
		img = img.get_region(Rect2i(0, 0, src.get_width(), src.get_height()))
		var raw_error := _mean_error(src,img)
		var shown_source: Image = src.duplicate()
		var shown_import: Image = img.duplicate()
		shown_source.resize(maxi(1,roundi(src.get_width()*max_zoom)),maxi(1,roundi(src.get_height()*max_zoom)),Image.INTERPOLATE_BILINEAR)
		shown_import.resize(shown_source.get_width(),shown_source.get_height(),Image.INTERPOLATE_BILINEAR)
		var err := _composited_error(shown_source,shown_import)
		if key=="shipping_bin":
			var damaged: Image = shown_import.duplicate()
			damaged.fill(Color.RED)
			control_error=_composited_error(shown_source,damaged)
		decoded[key] = img
		if key in ["trunk_giant_a", "farm_far", "rope_stake_x"] and _t.out_dir != "":
			_side_by_side(src, img, key)
		lines.append("%s %.2f shown / %.2f raw (%s)" % [key,err,raw_error,path])
		# Painted-art baseline, inspected in the saved source/import crops.
		# The former flat-CG limits (3/6) remain reference values in the verdict.
		var limit: float = 4.0 if src.get_width() * src.get_height() > 100000 else 7.0
		if err > limit:
			bad_err.append("%s %.2f > %.1f" % [key, err, limit])
		if err > worst:
			worst = err
			worst_id = path.get_file()
	t.info("ART_FARM_COMPRESSION effective runtime textures, max zoom %.2f: %s" % [max_zoom,", ".join(lines)])
	t.check("compression_error_of_the_imported_textures", decoded.size() == sources.size() and bad_err.is_empty() and control_error>7.0,
		"effective painted S3TC textures at the maximum farm zoom %.2f, composited over the contact-sheet background: worst mean RGB error %.2f / 255 (%s); painted limits 4.0 large / 7.0 small (former CG reference 3.0/6.0); raw 1:1 scores retained above; over limit %s; damaged-texture control %.2f must fail" % [max_zoom,worst,worst_id,str(bad_err),control_error])
	if decoded.size() != sources.size():
		return
	var big: Image = _sheet(decoded, ["trunk_giant_a", "trunk_giant_b", "trunk_under_a", "trunk_under_b", "shipping_bin"], 520.0 / float((decoded["trunk_giant_a"] as Image).get_height()), 560)
	var small: Image = _sheet(decoded, ["tool_shed", "shipping_bin", "stake_sign", "rope_stake_x", "rope_stake_z", "build_stake"], 2.0, 420)
	var ok: bool = _sheet_ok(big) and _sheet_ok(small)
	if _t.out_dir != "":
		big.save_png("%s/art_farm_contact_big.png" % _t.out_dir)
		small.save_png("%s/art_farm_contact_small.png" % _t.out_dir)
		t.info("ART_FARM contact sheets drawn from the imported (S3TC) textures: %s/art_farm_contact_big.png, art_farm_contact_small.png" % _t.out_dir)
	t.check("contact_sheets_from_imported_textures", ok, "the contact sheets built from the decompressed S3TC textures are not blank (%dx%d and %dx%d) - look at them (the lead / reviewer does)" % [big.get_width(), big.get_height(), small.get_width(), small.get_height()])


## source (left) next to the decompressed S3TC texture (right): a 1:1 crop from the middle of the image, for the human who looks at the compression
func _side_by_side(src: Image, dec: Image, key: String) -> void:
	var w: int = mini(src.get_width(), 520)
	var h: int = mini(src.get_height(), 520)
	var ox: int = int((src.get_width() - w) * 0.5)
	var oy: int = int((src.get_height() - h) * (0.75 if key == "trunk_giant_a" else 0.5))
	var sheet := Image.create(w * 2 + 8, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.5, 0.5, 0.5, 1.0))
	sheet.blend_rect(src, Rect2i(ox, oy, w, h), Vector2i(0, 0))
	sheet.blend_rect(dec, Rect2i(ox, oy, w, h), Vector2i(w + 8, 0))
	sheet.save_png("%s/art_farm_s3tc_side_by_side_%s.png" % [_t.out_dir, key])


func _sheet(imgs: Dictionary, ids: Array, scale: float, height: int) -> Image:
	var pad: int = 24
	var scaled: Array[Image] = []
	var width: int = pad
	for id in ids:
		var im: Image = (imgs[id] as Image).duplicate()
		im.resize(maxi(1, int(float(im.get_width()) * scale)), maxi(1, int(float(im.get_height()) * scale)), Image.INTERPOLATE_LANCZOS)
		scaled.append(im)
		width += im.get_width() + pad
	var tallest: int = 0
	for im in scaled:
		tallest = maxi(tallest, im.get_height())
	height = maxi(height, tallest + 40)
	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(205, 224, 232))
	var x: int = pad
	for im in scaled:
		sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(x, maxi(0, height - 20 - im.get_height())))
		x += im.get_width() + pad
	return sheet


func _sheet_ok(im: Image) -> bool:
	var seen: Dictionary = {}
	for y in range(0, im.get_height(), 7):
		for x in range(0, im.get_width(), 7):
			seen[im.get_pixel(x, y).to_html(false)] = true
	return seen.size() > 200


## mean abs difference per channel (0..255) over the pixels visible in the source (alpha > 0.1), sampled
func _mean_error(src: Image, dec: Image) -> float:
	var sum: float = 0.0
	var n: int = 0
	var sx: int = maxi(src.get_width() / 400, 1)
	var sy: int = maxi(src.get_height() / 400, 1)
	for y in range(0, src.get_height(), sy):
		for x in range(0, src.get_width(), sx):
			var a: Color = src.get_pixel(x, y)
			if a.a <= 0.1:
				continue
			var b: Color = dec.get_pixel(x, y)
			sum += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0 * 255.0
			n += 1
	return sum / float(maxi(n, 1))


func _composited_error(src: Image, dec: Image) -> float:
	var sum := 0.0
	var count := 0
	var background := Color8(205,224,232)
	for y in range(0,src.get_height(),maxi(src.get_height()/400,1)):
		for x in range(0,src.get_width(),maxi(src.get_width()/400,1)):
			var a := src.get_pixel(x,y)
			if a.a<=0.1:continue
			var b := dec.get_pixel(x,y)
			a = background.blend(a)
			b = background.blend(b)
			sum += (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))*255.0/3.0
			count += 1
	return sum/float(maxi(count,1))


# ---------------------------------------------------------------- field_grass in the engine

func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _field_text(id: String) -> String:
	var ground: Array[String] = []
	var objs: Array[String] = []
	for y in 12:
		var g := ""
		var o := ""
		for x in 16:
			if x == 0 or y == 0 or x == 15 or y == 11:
				g += "#"
			else:
				g += "f" if (x * 7 + y * 13) % 5 < 3 else "."
			o += "@" if (x == 8 and y == 6) else "."
		ground.append(g)
		objs.append(o)
	return "@id %s\n@title ZONE_FARM\n@projection iso\n@ambient farm\n@theme farm\n@zone farm\n@flight true\n@ground\n%s\n@objects\n%s\n" % [id, "\n".join(ground), "\n".join(objs)]


func _field_seams(t, w: WorldRoot2D) -> void:
	var p: Node2D = w.player
	var cam: Camera2D = p.get("camera")
	var id := &"_n03_field_mix"
	WorldRoot2D.register_map(id, AreaMap.parse_text(_field_text(String(id))))
	w._enter(id, &"default")
	w.day_night.override_hour = 11.0
	w.day_night.snap()
	var a: IsoArea = w.area
	for c in a.farmable.keys():
		a.set_terrain(c, &"field_grass")
	p.visible = false
	var ok: bool = true
	var probe_ok: bool = true
	var seen: Array[String] = []
	for z in [0.3, 0.4, 0.7]:
		cam.zoom = Vector2.ONE * z
		p.global_position = a.cell_to_global(Vector2i(8, 6))
		cam.reset_smoothing()
		await t.seconds(0.35)
		var img: Image = await t.capture("field_mix_zoom_%d" % int(z * 100.0))
		var st: Dictionary = _seam_step(w, a, img.duplicate() as Image, ["field_grass", "grass"])
		var excess: float = float(st["border"]) - float(st["control"])
		var pass_here: bool = _last_pairs >= 6 and excess < 3.0 / 255.0
		ok = ok and pass_here
		seen.append("zoom %.1f: %d borders, step %.1f vs %.1f in the middles" % [z, _last_pairs, float(st["border"]) * 255.0, float(st["control"]) * 255.0])
		if z == 0.4:
			var neg: Dictionary = _seam_step(w, a, img.duplicate() as Image, ["field_grass", "grass"], 0.08)
			probe_ok = (float(neg["border"]) - float(neg["control"])) > 3.0 / 255.0
	t.check("field_grass_seams", ok, "field_grass and grass mixed cell by cell (the untilled field next to the lawn): no hairline at zoom 0.3 / 0.4 / 0.7 (luminance step across tile borders within 3 / 255 of the step inside the tiles): %s" % "; ".join(seen))
	t.check("field_grass_seam_probe_sees_a_hairline", probe_ok, "negative control: a deliberate 20 / 255 hairline on the borders reads as excess > 3 / 255")
	p.visible = true
	WorldRoot2D.unregister_map(id)


func _seam_step(w: WorldRoot2D, a: IsoArea, img: Image, ids: Array, inject: float = 0.0) -> Dictionary:
	var ct: Transform2D = w.get_viewport().get_canvas_transform()
	var terr: Dictionary = a.get("_terrain_of")
	var borders: Array[float] = []
	var controls: Array[float] = []
	var pairs: int = 0
	var size: Vector2 = Vector2(img.get_size())
	var zoom: float = ct.get_scale().x
	for y in range(1, a.map.height - 1):
		for x in range(1, a.map.width - 1):
			var c := Vector2i(x, y)
			if not terr.has(c) or not ids.has(String(terr[c])):
				continue
			for step in [Vector2i(1, 0), Vector2i(0, 1)]:
				var c2: Vector2i = c + step
				if not terr.has(c2) or not ids.has(String(terr[c2])):
					continue
				var p0: Vector2 = ct * a.cell_to_global(c)
				var p1: Vector2 = ct * a.cell_to_global(c2)
				if p0.x < 40.0 or p1.x < 40.0 or p0.x > size.x - 40.0 or p1.x > size.x - 40.0 or p0.y < 40.0 or p1.y < 40.0 or p0.y > size.y - 40.0 or p1.y > size.y - 40.0:
					continue
				var n: Vector2 = (p1 - p0).normalized()
				var tangent := Vector2(-n.y, n.x)
				var mid: Vector2 = (p0 + p1) * 0.5
				var reach: float = 74.0 * zoom * 0.12
				for k in range(-2, 3):
					if inject > 0.0:
						var hp := Vector2i(mid + tangent * reach * float(k))
						var hc: Color = img.get_pixelv(hp)
						img.set_pixelv(hp, Color(hc.r - inject, hc.g - inject, hc.b - inject))
					borders.append(_step_at(img, mid + tangent * reach * float(k), n))
					controls.append(_step_at(img, p0 + tangent * reach * float(k), n))
				pairs += 1
	_last_pairs = pairs
	borders.sort()
	controls.sort()
	return {"border": borders[borders.size() / 2] if pairs > 0 else 0.0, "control": controls[controls.size() / 2] if pairs > 0 else 0.0}


func _step_at(img: Image, at: Vector2, normal: Vector2) -> float:
	var la: float = _luma(img.get_pixelv(Vector2i(at + normal * 4.0)))
	var lb: float = _luma(img.get_pixelv(Vector2i(at - normal * 4.0)))
	var le: float = _luma(img.get_pixelv(Vector2i(at)))
	return absf(le - (la + lb) * 0.5)


# ---------------------------------------------------------------- the real farm

## brown bark pixels in a screenshot rectangle: the trunk colours are 8a5a3a / 6a4428 under the farm light (r > g > b, warm, mid brightness)
func _bark_pixels(img: Image, rect: Rect2i) -> int:
	var n: int = 0
	for y in range(rect.position.y, mini(rect.end.y, img.get_height()), 2):
		for x in range(rect.position.x, mini(rect.end.x, img.get_width()), 2):
			var c: Color = img.get_pixel(x, y)
			if c.r > c.g + 0.07 and c.g > c.b + 0.04 and c.r > 0.25 and c.r < 0.75:
				n += 1
	return n


func _farm_pictures(t, w: WorldRoot2D) -> void:
	var p: Node2D = w.player
	var cam: Camera2D = p.get("camera")
	w._enter(&"_fixture_iso", &"default")
	w.free_parked_areas()
	ArtCatalog.reset()
	AreaTileSet.reset()
	w._enter(&"farm", &"default")
	await t.seconds(0.6)
	var a: IsoArea = w.area
	for c in a.farmable.keys():
		a.set_terrain(c, &"field_grass")           # what FarmView does for every farmable cell (P06 amendment)
	var trunk_a: Array[Vector2i] = a.map.find_objects("R")
	var trunk_b: Array[Vector2i] = a.map.find_objects("Q")
	var spawn: Vector2i = a.global_to_cell(a.spawns["default"])
	w.day_night.override_hour = 11.0
	w.day_night.snap()
	a.set_night_factor(w.day_night.glow_factor)
	p.global_position = a.cell_to_global(spawn)
	cam.zoom = Vector2.ONE * 0.4
	cam.reset_smoothing()
	await t.seconds(0.7)
	var noon: Image = await t.capture("farm_noon_zoom04")
	t.expect_not_blank(noon, Rect2i(0, 0, 1280, 720), "art_farm.farm_noon_not_blank: the real farm at noon (zoom 0.4, field_grass on the plots) is a picture, not a clear colour", 40, 0.03)
	if not trunk_a.is_empty():
		# the standing trunk behind the house: centre the camera on its footprint, the bark fills the middle of the picture
		p.global_position = a.cell_to_global(trunk_a[0])
		cam.zoom = Vector2.ONE * 0.3
		cam.reset_smoothing()
		await t.seconds(0.7)
		var img_a: Image = await t.capture("farm_trunk_giant_a_zoom03")
		var bark_a: int = _bark_pixels(img_a, Rect2i(340, 60, 600, 600))
		t.check("farm_trunk_giant_a_visible", bark_a > 4000, "the standing trunk (trunk_giant_a on the cell of `R`) fills the middle of the picture at zoom 0.3: %d bark-coloured sample pixels in the central 600 x 600 (> 4000)" % bark_a)
	if not trunk_b.is_empty():
		p.global_position = a.cell_to_global(trunk_b[0])
		cam.zoom = Vector2.ONE * 0.3
		cam.reset_smoothing()
		await t.seconds(0.7)
		var img_b: Image = await t.capture("farm_trunk_giant_b_zoom03")
		var bark_b: int = _bark_pixels(img_b, Rect2i(340, 60, 600, 600))
		t.check("farm_trunk_giant_b_visible", bark_b > 3000, "the orchard trunk (trunk_giant_b on the cell of `Q`) is in the picture: %d bark-coloured sample pixels (> 3000)" % bark_b)
	p.global_position = a.cell_to_global(spawn)
	cam.zoom = Vector2.ONE * 0.4
	cam.reset_smoothing()
	w.day_night.override_hour = 19.0
	w.day_night.snap()
	a.set_night_factor(w.day_night.glow_factor)
	await t.seconds(0.7)
	await t.capture("farm_dusk_zoom04")
	w.day_night.override_hour = 23.0
	w.day_night.snap()
	a.set_night_factor(w.day_night.glow_factor)
	await t.seconds(0.7)
	var night: Image = await t.capture("farm_night_zoom04")
	t.expect_not_blank(night, Rect2i(0, 0, 1280, 720), "art_farm.farm_night_still_readable: the farm at night (zoom 0.4) is not black", 40, 0.02)
	w.day_night.override_hour = 11.0
	w.day_night.snap()
	a.set_night_factor(w.day_night.glow_factor)
