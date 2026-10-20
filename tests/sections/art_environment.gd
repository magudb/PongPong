extends RefCounted
## Section art_environment (package P22-art-environment, M1a stage 1): the environment art as shipped in res://assets - ground tiles (17 diamond + 7 ortho atlases), props
## (spike set, farm contract props, Hyggebyen, the Moerkeskoven forest set, crops, painted decals / fx / seamless textures), backdrops, the gameplay rows of
## lua/config/props_extra.lua - against the contracts of plan 6.2 / R.1 / R.10, the TOWNS addendum (RT16) and the DUNGEON addendum (7.5, 8.11).
##
## Headless and independent of the Python validator (tools/art/environment/validate_environment.py implements the same checks a second time):
##   tiles_manifest_lists_every_terrain  tiles_contract_cells_and_projection  tile_atlases_import_without_mipmaps  ortho_tiles_periodic_edges
##   props_manifest_sane  props_have_gameplay_rows  props_extra_ids_exist  props_extra_blueprint_ids_present  props_lua_ids_exist  map_prop_ids_exist
##   farm_contract_props_sizes_and_footprints  farm_rows_complete  farm_ids_resolved_by_installed_pack  no_foreign_or_dropped_ids
##   forest_art_ids_exist  forest_crowns_baked_at_36  dungeon_crowns_present_and_sized  forest_albedo_within_ambient_headroom  dungeon_prop_defs_complete
##   dungeon_ids_in_catalog  image_props_contract  backdrops_present  fixtures_missing_only_pending  hyggebyen_map_art_complete  ortho_decision_*  budget  readme_verdict
##   prop_packs_listed (review REND-10: ArtCatalog reads the packs in its explicit PROP_PACKS order, never by folder name)  no_superseded_art_files
## Windowed (tests/run_playtest.sh --windowed --only=art_environment): filter_seams_mixed_terrains (grass + flowers, forest floor + glow, iso and ortho, at zoom 0.3 / 0.4 /
## 0.7 and a negative control), forest_ortho_readable (the outline (75,60,73) and the crowns on #1c2138 at zoom 0.4), plus the screenshots the package is judged by.
##
## The ids and their metadata are P22's (iso_props/props.json); the files checked are the ones the game draws: ArtCatalog's effective entry of each id, so an id a
## later art pack repaints is checked in its painted file (the superseded P22 copies are not kept, review REND-10).
##
## PENDING lines: ids whose art belongs to a LATER package (N03 farm kit, N06 dress, V5 city, P04's wall rows) are listed as SKIP lines naming the package; they are never
## silently accepted: the check that carries them counts everything else strictly.
const SECTION := "art_environment"
const TIMEOUT_S := 300.0

const TILES_DIR := "res://assets/iso_tiles/"
const PROPS_DIR := "res://assets/iso_props/"
const BACKDROP_DIR := "res://assets/backdrops/"
const DECISION := "res://assets/iso_tiles/ORTHO_DECISION.md"
const README := "res://tools/art/environment/README.md"

## the ten farm-only props of N03 (design_farm.md 10.2) and the dress props of N06: rows exist in props_extra.lua, their ART is a later package's
const N03_IDS: Array[String] = ["trunk_giant_a", "trunk_giant_b", "trunk_under_a", "trunk_under_b", "tool_shed", "shipping_bin", "stake_sign", "rope_stake_x", "rope_stake_z", "build_stake"]
const N06_IDS: Array[String] = ["flower_box", "garden_arch", "fountain_small", "royal_banner", "blossom_cluster", "sunflower_row", "leaf_pile", "pumpkin_stack", "snow_patch", "bunting_x", "vine_hang"]
## the five ortho wall props the DUNGEON amendment drops (forest_wall_a/b/c, cave_wall_a/b): P04's props.lua rows and AreaTileSet.WALL_PROPS still name them
const DROPPED_WALLS: Array[String] = ["forest_wall_a", "forest_wall_b", "forest_wall_c", "cave_wall_a", "cave_wall_b"]
const FOREIGN_FILES: Array[String] = ["field_grass", "farm_sky", "farm_far", "farm_canopy", "dock_x"]

## task 3 of the order: every blueprint prop id (the buildings, street furniture, farm contract props, crops, the lantern colourways, the shop quarter of the features addendum)
const BLUEPRINT_IDS: Array[String] = ["house_town_hall", "house_bakery", "house_seedshop", "house_smithy", "house_animalstore", "tower_wizard", "house_king_treetop", "well", "fountain",
	"market_stall", "market_stall_furniture", "market_stall_tailor", "plank_stack", "bench", "signpost", "warp_gate_stone", "bed", "coop_small", "barn_small", "animal_house", "paw_prints",
	"roof_patch", "apple_tree", "wheat_sack", "beehive_stand", "stone_path_a", "stone_path_b", "stone_path_c", "lantern_post_rose", "lantern_post_lavender", "lantern_post_mint",
	"mailbox_red", "chest_noegle", "crop_strawberry_0", "crop_strawberry_1", "crop_strawberry_2", "crop_strawberry_3", "crop_sunflower_0", "crop_sunflower_1", "crop_sunflower_2",
	"crop_sunflower_3", "crop_catnip_0", "crop_catnip_1", "crop_catnip_2", "crop_catnip_3", "crop_glow_berry_0", "crop_glow_berry_1", "crop_glow_berry_2", "crop_glow_berry_3"]

## RT16 task 2: id -> [w, h, pivot x, pivot y, footprint x, footprint z]
const FARM_CONTRACT := {"coop_small": [350, 295, 155, 218, 3, 2], "barn_small": [472, 424, 208, 313, 4, 3], "animal_house": [319, 270, 143, 199, 3, 2], "paw_prints": [39, 49, 16, 29, 1, 1],
	"apple_tree": [359, 398, 172, 355, 1, 1], "bench": [174, 144, 78, 107, 2, 1], "signpost": [84, 130, 38, 112, 1, 1]}
## RT16 task 3 / design_farm.md 10.3 verbatim: id -> [fx, fz, solid shape, solid number (pad / radius), strips]; mailbox_red is the V amendment (circle 20 + interact mailbox) and wins
const FARM_ROWS := {"trunk_giant_a": [5, 3, "none", 0, 0], "trunk_giant_b": [3, 3, "footprint", 0, 12], "trunk_under_a": [1, 1, "none", 0, 0], "trunk_under_b": [1, 1, "none", 0, 0],
	"mailbox_red": [1, 1, "circle", 20, 0], "shipping_bin": [2, 1, "footprint", 8, 0], "tool_shed": [2, 2, "footprint", 12, 6], "bench": [2, 1, "none", 0, 0], "stake_sign": [1, 1, "circle", 10, 0],
	"rope_stake_x": [1, 1, "none", 0, 0], "rope_stake_z": [1, 1, "none", 0, 0], "paw_prints": [1, 1, "none", 0, 0], "build_stake": [1, 1, "none", 0, 0],
	"coop_small": [3, 2, "footprint", 16, 8], "barn_small": [4, 3, "footprint", 16, 12], "animal_house": [3, 2, "footprint", 16, 8]}

## DUNGEON addendum task 1: the forest set (VTK bakes + painted layers)
const FOREST_IDS: Array[String] = ["crown_s_a", "crown_s_b", "crown_m_a", "crown_m_b", "crown_l_a", "crown_l_b", "bush_eyes_a", "bush_eyes_b", "empty_bush", "eyes_glow", "cave_ring", "cave_ring_up",
	"cave_stone_a", "cave_stone_b", "cave_stone_c", "cave_stone_d", "cave_stone_e", "home_rope", "runestone_dormant", "runestone_active", "rune_glow", "pond_lily", "pond_ripple", "pond_sheen",
	"path_tile_o", "pond_water_o", "floor_patch_a", "floor_patch_b", "floor_patch_c", "mist_patch_a", "mist_patch_b", "firefly_dot", "lantern_light"]
## task 4: the ids the experience layer names
const EXPERIENCE_IDS: Array[String] = ["telegraph_ring_s", "telegraph_ring_m", "telegraph_ring_l", "telegraph_line", "boss_arena_ring", "halo_amber", "halo_violet", "crown_spark", "fx_hit_spark",
	"fx_heal_sparkle", "tornebaer", "chest_noegle"]
## everything above the ambient ceiling (R > 77, G > 94, B > 133) is an additive layer
const ADDITIVE_IDS: Array[String] = ["eyes_glow", "rune_glow", "pond_sheen", "pond_ripple", "hulen_eyes", "firefly_dot", "halo_amber", "halo_violet", "crown_spark", "fx_hit_spark", "fx_heal_sparkle",
	"telegraph_ring_s", "telegraph_ring_m", "telegraph_ring_l", "telegraph_line", "boss_arena_ring"]
## radius R of the disc, table width, table height (px) of the crowns
const CROWNS := {"s": [170, 400, 420], "m": [230, 530, 550], "l": [300, 670, 690]}
const AMBIENT := Vector3(77.0, 94.0, 133.0)             # 4d5e85
## palette id -> [sketch colour after the grade (r, g, b), tolerance per channel]
const PALETTE := {"crown": [Vector3(0x35, 0x3b, 0x62), 30.0], "bush": [Vector3(0x2a, 0x2f, 0x4c), 26.0], "cave_ring": [Vector3(0x4b, 0x4d, 0x6e), 30.0],
	"cave_stone": [Vector3(0x4d, 0x5e, 0x82), 44.0], "runestone": [Vector3(0x4d, 0x5e, 0x82), 44.0], "pond_lily": [Vector3(0x3f, 0x8f, 0x6a), 50.0]}
const SIN36 := 0.5878

var _t
var _imgs: Dictionary = {}


func run(t) -> void:
	_t = t
	ArtCatalog.reset()
	var tiles: Dictionary = _tiles()
	var props: Dictionary = _props()
	t.check("inputs_present", not tiles.is_empty() and not props.is_empty(), "tiles.json %d terrains, props.json %d props" % [tiles.size(), props.size()])
	if tiles.is_empty() or props.is_empty():
		return
	_tiles_checks(tiles)
	_props_checks(props)
	_packs()
	_farm_checks(props)
	_forest_checks(props)
	_image_props(props)
	_backdrops()
	await _worlds(props)
	_decision()
	_budget()
	_readme()


# ---------------------------------------------------------------- helpers

func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _tiles() -> Dictionary:
	var out: Dictionary = {}
	var d: Variant = _json(TILES_DIR + "tiles.json")
	if d is Dictionary:
		for k in (d as Dictionary):
			if not str(k).begins_with("_"):
				out[str(k)] = (d as Dictionary)[k]
	return out


## P22's ids, each with ArtCatalog's effective entry (the pack that wins; `_dir` is its folder).
func _props() -> Dictionary:
	var out: Dictionary = {}
	var d: Variant = _json(PROPS_DIR + "props.json")
	if d is Dictionary:
		for k in (d as Dictionary):
			if not str(k).begins_with("_"):
				out[str(k)] = ArtCatalog.prop_metadata(StringName(str(k)))
	return out


## The file the game draws for an entry (or for one of its layers, `file` relative to the entry's pack folder).
func _path(e: Dictionary, file: Variant = null) -> String:
	return (str(e.get("_dir", PROPS_DIR)) + str(e.get("file", "") if file == null else file)).simplify_path()


func _image(path: String) -> Image:
	if _imgs.has(path):
		return _imgs[path]
	var im: Image = Image.load_from_file(ProjectSettings.globalize_path(path))      # an absolute path: a res:// path makes the engine warn ("will not work on export")
	if im != null and not im.is_empty():
		im.convert(Image.FORMAT_RGBA8)
	else:
		im = null
	_imgs[path] = im
	return im


func _lua(table: String) -> Dictionary:
	return GameData.dict_of(GameData.cfg(table, {}))


func _fp(e: Dictionary) -> Vector2i:
	var f: Array = GameData.array_of(e.get("footprint", [1, 1]))
	return Vector2i(int(f[0]), int(f[1])) if f.size() >= 2 else Vector2i(1, 1)


func _pending(label: String, who: String, what: Variant) -> void:
	_t.skip("art_environment.%s PENDING %s: %s" % [label, who, str(what)])


## [x0, y0, x1, y1] (inclusive) of the pixels with alpha above `thr` (0..255), or [] when there are none
func _bounds(im: Image, thr: int) -> Array:
	var w: int = im.get_width()
	var h: int = im.get_height()
	var data: PackedByteArray = im.get_data()
	var x0: int = w
	var x1: int = -1
	var y0: int = -1
	var y1: int = -1
	for y in h:
		var row: int = y * w * 4
		var lo: int = -1
		for x in w:
			if data[row + x * 4 + 3] > thr:
				lo = x
				break
		if lo < 0:
			continue
		var hi: int = lo
		for x in range(w - 1, lo - 1, -1):
			if data[row + x * 4 + 3] > thr:
				hi = x
				break
		if y0 < 0:
			y0 = y
		y1 = y
		x0 = mini(x0, lo)
		x1 = maxi(x1, hi)
	return [] if y0 < 0 else [x0, y0, x1, y1]


## mean colour (0..255) of the pixels with alpha >= thr, sampled every `step` pixels
func _mean_rgb(im: Image, thr: int, step: int = 3) -> Vector3:
	var w: int = im.get_width()
	var h: int = im.get_height()
	var data: PackedByteArray = im.get_data()
	var sum := Vector3.ZERO
	var n: int = 0
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var i: int = (y * w + x) * 4
			if data[i + 3] >= thr:
				sum += Vector3(data[i], data[i + 1], data[i + 2])
				n += 1
			x += step
		y += step
	return sum / float(maxi(n, 1))


# ---------------------------------------------------------------- tiles

func _tiles_checks(tiles: Dictionary) -> void:
	var t = _t
	var want: Array[StringName] = []
	want.append_array(AreaTileSet.ISO_TERRAINS)
	want.append_array(AreaTileSet.ORTHO_TERRAINS)
	var missing: Array[String] = []
	var not_real: Array[String] = []
	for id in want:
		if not tiles.has(String(id)):
			missing.append(String(id))
		elif not ArtCatalog.has_real_terrain(id):
			not_real.append(String(id))
	t.check("tiles_manifest_lists_every_terrain", missing.is_empty() and not_real.is_empty(),
		"tiles.json lists the %d terrains of AreaTileSet (17 diamond + 7 ortho); missing %s, listed without a loadable atlas %s" % [want.size(), str(missing), str(not_real)])
	var bad: Array[String] = []
	for id in want:
		var e: Dictionary = tiles.get(String(id), {})
		if e.is_empty():
			continue
		var cell: Array = GameData.array_of(e.get("cell", []))
		var variants: Array = GameData.array_of(e.get("variants", []))
		var ortho: bool = AreaTileSet.ORTHO_TERRAINS.has(id)
		var want_cell: Array = [112, 64] if ortho else [144, 84]
		var want_var: Array = [2, 2] if String(id).begins_with("water_") else [4, 4]
		if cell.size() < 2 or int(cell[0]) != want_cell[0] or int(cell[1]) != want_cell[1]:
			bad.append("%s cell %s" % [id, str(cell)])
		if variants.size() < 2 or int(variants[0]) != want_var[0] or int(variants[1]) != want_var[1]:
			bad.append("%s variants %s" % [id, str(variants)])
		if ortho and (str(e.get("proj", "")) != "ortho" or not _arr_eq(GameData.array_of(e.get("tile", [])), [96, 56])):
			bad.append("%s ortho entry %s" % [id, str(e)])
		var im: Image = _image(TILES_DIR + str(e.get("file", "")))
		if im == null or cell.size() < 2 or variants.size() < 2 or im.get_width() != int(cell[0]) * int(variants[0]) or im.get_height() != int(cell[1]) * int(variants[1]):
			bad.append("%s atlas %s != variants x cell" % [id, "unreadable" if im == null else "%dx%d" % [im.get_width(), im.get_height()]])
	t.check("tiles_contract_cells_and_projection", bad.is_empty(),
		"diamond atlases: cell 144 x 84, periodic 4 x 4 (water 2 x 2); ortho atlases: tile 96 x 56 in a 112 x 64 cell, proj ortho, 4 x 4, file ortho_<terrain>.png %s" % str(bad.slice(0, 4)))
	var stubless: Array[String] = []
	for id in want:
		var e2: Dictionary = tiles.get(String(id), {})
		if e2.is_empty():
			continue
		var imp: String = TILES_DIR + str(e2.get("file", "")) + ".import"
		var txt: String = FileAccess.get_file_as_string(imp) if FileAccess.file_exists(imp) else ""
		if not ("mipmaps/generate=false" in txt and "compress/mode=0" in txt):
			stubless.append(String(id))
	t.check("tile_atlases_import_without_mipmaps", stubless.is_empty(),
		"every tile atlas imports lossless WITHOUT mipmaps (periodic cells would bleed into each other at mip >= 1, review R.1); offenders %s" % str(stubless))
	_ortho_edges(tiles)


## ortho atlas variants meet seamlessly: the last column of tile (i, j) continues into the first column of (i + 1, j) (wrapping 3 -> 0) and likewise for rows
func _ortho_edges(tiles: Dictionary) -> void:
	var worst: float = 0.0
	var worst_id: String = ""
	var ok: bool = true
	var rows: Array[String] = []
	for id in AreaTileSet.ORTHO_TERRAINS:
		var e: Dictionary = tiles.get(String(id), {})
		var im: Image = _image(TILES_DIR + str(e.get("file", ""))) if not e.is_empty() else null
		if im == null:
			ok = false
			continue
		var cw: int = 112
		var ch: int = 64
		var x0: int = (cw - 96) / 2
		var y0: int = (ch - 56) / 2
		var edge_sum: float = 0.0
		var inner_sum: float = 0.0
		var n: int = 0
		for j in 4:
			for i in 4:
				var ni: int = (i + 1) % 4
				var nj: int = (j + 1) % 4
				for y in range(y0 + 2, y0 + 54, 2):
					edge_sum += _col_diff(im.get_pixel(i * cw + x0 + 95, j * ch + y), im.get_pixel(ni * cw + x0, j * ch + y))
					inner_sum += _col_diff(im.get_pixel(i * cw + x0 + 50, j * ch + y), im.get_pixel(i * cw + x0 + 51, j * ch + y))
					n += 1
				for x in range(x0 + 4, x0 + 92, 2):
					edge_sum += _col_diff(im.get_pixel(i * cw + x, j * ch + y0 + 55), im.get_pixel(i * cw + x, nj * ch + y0))
					inner_sum += _col_diff(im.get_pixel(i * cw + x, j * ch + y0 + 30), im.get_pixel(i * cw + x, j * ch + y0 + 31))
					n += 1
		var edge: float = edge_sum / float(n)
		var inner: float = inner_sum / float(n)
		rows.append("%s %.1f/%.1f" % [id, edge, inner])
		var limit: float = inner * 1.5 + 1.5
		if edge > limit:
			ok = false
		if edge - inner > worst:
			worst = edge - inner
			worst_id = String(id)
	_t.check("ortho_tiles_periodic_edges", ok,
		"the seam between neighbouring variants of every ortho atlas is no rougher than the texture itself (mean abs step on the 0..255 scale, edge/inner: %s; limit inner x 1.5 + 1.5; worst excess %.1f on %s)" % [" ".join(rows), worst, worst_id])


## numeric array equality: JSON hands numbers over as floats, and [96.0, 56.0] == [96, 56] is false for GDScript arrays
func _arr_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > 0.0001:
			return false
	return true


func _col_diff(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0 * 255.0


# ---------------------------------------------------------------- props

## Every art pack folder (a props.json under iso_props/) is named in ArtCatalog.PROP_PACKS, which fixes the override order; a
## folder the list misses would silently not be read, a listed folder without a props.json is a typo.
func _packs() -> void:
	var folders: Array[String] = []
	for sub in DirAccess.get_directories_at(PROPS_DIR):
		if FileAccess.file_exists(PROPS_DIR + sub + "/props.json"):
			folders.append(sub)
	var unlisted: Array = folders.filter(func(f: String) -> bool: return not ArtCatalog.PROP_PACKS.has(f))
	var empty: Array = ArtCatalog.PROP_PACKS.filter(func(f: String) -> bool: return not folders.has(f))
	_t.check("prop_packs_listed", unlisted.is_empty() and empty.is_empty() and folders.size() >= 10,
		"%d pack folders, all in ArtCatalog.PROP_PACKS (the override order); unlisted %s, listed without a props.json %s" % [folders.size(), str(unlisted), str(empty)])
	# A superseded entry keeps its id and metadata (P22 / V5 / N03 contracts, CityData's geometry), but not its files: a copy nobody draws would ship and
	# invite edits that never show (review REND-10). Drawn = named by the entry ArtCatalog uses for its id.
	var entries: Dictionary = {}                    # id -> [[pack folder, entry], ...] in override order
	var drawn: Dictionary = {}
	for dir in [PROPS_DIR] + ArtCatalog.PROP_PACKS.map(func(pack: String) -> String: return PROPS_DIR + pack + "/"):
		var d: Variant = _json(dir + "props.json")
		if not (d is Dictionary):
			continue
		for id in d:
			if not str(id).begins_with("_") and d[id] is Dictionary:
				if not entries.has(id):
					entries[id] = []
				entries[id].append([dir, d[id]])
	for id in entries:
		var last: Array = entries[id].back()
		for f in _entry_files(last[0], last[1]):
			drawn[f] = true
	var superseded: Array[String] = []
	var n := 0
	for id in entries:
		for pair in entries[id].slice(0, -1):
			n += 1
			for f in _entry_files(pair[0], pair[1]):
				if not drawn.has(f) and FileAccess.file_exists(f):
					superseded.append("%s (%s, drawn from %s)" % [f.trim_prefix(PROPS_DIR), id, str(entries[id].back()[0]).trim_prefix(PROPS_DIR)])
	# the backdrops: ArtCatalog prefers <theme>_sky.png over <theme>_sky.webp and the painted backdrop_<theme>_far prop over <theme>_far.webp
	for f in DirAccess.get_files_at(BACKDROP_DIR):
		var theme := f.get_basename().trim_suffix("_sky").trim_suffix("_far")
		if (f.ends_with("_sky.webp") and FileAccess.file_exists(BACKDROP_DIR + theme + "_sky.png")) or (f.ends_with("_far.webp") and entries.has("backdrop_%s_far" % theme)):
			superseded.append("backdrops/%s (ArtCatalog draws the painted layer instead)" % f)
	_t.check("no_superseded_art_files", superseded.is_empty() and n > 100, "%d superseded pack entries keep no file of their own, no backdrop is shadowed by a painted one: %s" % [n, str(superseded.slice(0, 5))])


## The files an entry of a pack names (its sprite and its glow / ground layers), as simplified res:// paths.
func _entry_files(dir: String, e: Dictionary) -> Array[String]:
	var out: Array[String] = [(dir + str(e.get("file", ""))).simplify_path()]
	for layer in ["glow", "ground"]:
		if e.get(layer) is Dictionary:
			out.append((dir + str((e[layer] as Dictionary).get("file", ""))).simplify_path())
	return out


func _props_checks(props: Dictionary) -> void:
	var t = _t
	var bad: Array[String] = []
	var listed_files: Dictionary = {}
	for id in props:
		var e: Dictionary = props[id]
		var file: String = _path(e)
		listed_files[file] = true
		var im: Image = _image(file)
		if im == null:
			bad.append("%s: no readable file %s" % [id, file])
			continue
		var size: Array = GameData.array_of(e.get("size", []))
		var pivot: Array = GameData.array_of(e.get("pivot", []))
		if size.size() < 2 or int(size[0]) != im.get_width() or int(size[1]) != im.get_height():
			bad.append("%s: size %s != image %dx%d" % [id, str(size), im.get_width(), im.get_height()])
		if pivot.size() < 2 or int(pivot[0]) < 0 or int(pivot[0]) >= im.get_width() or int(pivot[1]) < 0 or int(pivot[1]) >= im.get_height():
			bad.append("%s: pivot %s outside the image" % [id, str(pivot)])
		var fp: Array = GameData.array_of(e.get("footprint", []))
		if fp.size() < 2 or int(fp[0]) < 1 or int(fp[1]) < 1:
			bad.append("%s: footprint %s" % [id, str(fp)])
		var g: Variant = e.get("glow", null)
		if g is Dictionary:
			listed_files[_path(e, (g as Dictionary).get("file", ""))] = true
			if not FileAccess.file_exists(_path(e, (g as Dictionary).get("file", ""))):
				bad.append("%s: glow file missing" % id)
	t.check("props_manifest_sane", bad.is_empty(), "%d props: every file reads, size = image size, the pivot (ground origin) is inside the image, footprints are positive; %s" % [props.size(), str(bad.slice(0, 4))])
	var stray: Array[String] = []
	var dir := DirAccess.open(PROPS_DIR)
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".png") and not listed_files.has(PROPS_DIR + f):
				stray.append(f)
	t.check("no_stray_prop_files", stray.is_empty(), "every png of assets/iso_props is a prop or a glow of one: stray %s" % str(stray.slice(0, 5)))
	var foreign: Array[String] = []
	for id in props:
		if N03_IDS.has(id) or N06_IDS.has(id) or DROPPED_WALLS.has(id) or FOREIGN_FILES.has(id):
			foreign.append(id)
	t.check("no_foreign_or_dropped_ids", foreign.is_empty(), "P22's manifest carries no N03 / N06 / N07 / V5 id and none of the dropped walls forest_wall_a/b/c, cave_wall_a/b: %s" % str(foreign))
	# every baked id has a gameplay row (props.lua, props_extra.lua, props_features.lua) and the row's footprint is the baked one
	var rowless: Array[String] = []
	var fp_bad: Array[String] = []
	for id in props:
		var def: Dictionary = GameData.prop_def(id)
		if def.is_empty():
			rowless.append(id)
			continue
		if def.has("art"):
			continue
		var e2: Dictionary = props[id]
		if def.has("footprint") and GameData.footprint_of(id) != _fp(e2):
			fp_bad.append("%s row %s baked %s" % [id, str(GameData.footprint_of(id)), str(_fp(e2))])
	t.check("props_have_gameplay_rows", rowless.is_empty() and fp_bad.is_empty(), "every baked prop has a row and the footprint of the row is the baked footprint: no row %s; mismatch %s" % [str(rowless.slice(0, 5)), str(fp_bad.slice(0, 5))])
	# The original P22 manifest leaves the ten farm-kit rows to their own pack.
	var extra: Dictionary = _lua("props_extra")
	var no_art: Array[String] = []
	var pend: Array[String] = []
	for id in extra:
		var def2: Dictionary = GameData.dict_of(extra[id])
		var art_id: String = str(def2.get("art", id))
		if props.has(art_id) and ArtCatalog.has_real_prop(StringName(art_id)):
			continue
		if N03_IDS.has(String(id)):
			pend.append(String(id))
		else:
			no_art.append(String(id))
	t.check("props_extra_ids_exist", no_art.is_empty() and extra.size() >= 100, "all %d rows of lua/config/props_extra.lua resolve to real art (ids without art: %s)" % [extra.size(), str(no_art.slice(0, 6))])
	t.check("farm_ids_resolved_by_installed_pack", N03_IDS.all(func(id):return ArtCatalog.has_real_prop(StringName(id))) and _count_in(N03_IDS,props)==0,
		"the installed painted farm pack resolves all ten IDs; the historical P22 manifest still respects its carve-out")
	var absent: Array[String] = []
	for id in BLUEPRINT_IDS:
		if not extra.has(id) and not GameData.prop_def(id).has("footprint"):
			absent.append(id)
		elif not props.has(id):
			absent.append(id + " (no art)")
	t.check("props_extra_blueprint_ids_present", absent.is_empty(), "the %d blueprint ids of order task 3 (+ crops, lantern colourways, shop quarter) have a row and real art: %s" % [BLUEPRINT_IDS.size(), str(absent)])
	# lua/config/props.lua: every key of P04's table has art, except the dropped wall rows (P04's file still lists them)
	var base: Dictionary = _lua("props")
	var base_missing: Array[String] = []
	var base_dropped: Array[String] = []
	for id in base:
		var art_id2: String = str(GameData.dict_of(base[id]).get("art", id))
		if ArtCatalog.has_real_prop(StringName(art_id2)):
			continue
		if DROPPED_WALLS.has(String(id)):
			base_dropped.append(String(id))
		else:
			base_missing.append(String(id))
	t.check("props_lua_ids_exist", base_missing.is_empty(), "every prop id of lua/config/props.lua (%d) has real art: without art %s" % [base.size(), str(base_missing)])
	if not base_dropped.is_empty():
		_pending("props_lua_ids_exist", "P04-area-framework (handoff)", "props.lua still lists the dropped ortho walls %s (DUNGEON amendment); AreaTileSet.WALL_PROPS / IsoArea._wall_prop_for follow" % str(base_dropped))
	_map_ids(props)


func _count_in(ids: Array[String], props: Dictionary) -> int:
	var n: int = 0
	for id in ids:
		if props.has(id):
			n += 1
	return n


## ids named by data/maps/*.map (`@prop` rows and `prop=` of markers): real art, or pending for the package that owns it
func _map_ids(props: Dictionary) -> void:
	var dir := DirAccess.open("res://data/maps")
	if dir == null:
		_t.skip("art_environment.map_prop_ids_exist (no res://data/maps)")
		return
	var unknown: Array[String] = []
	var pend: Dictionary = {}
	var n_ids: int = 0
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".map"):
			files.append(f)
	files.sort()
	for f in files:
		var m: AreaMap = AreaMap.parse_text(FileAccess.get_file_as_string("res://data/maps/" + f), f)
		var ids: Dictionary = {}
		for ch in m.props:
			ids[str(GameData.dict_of(m.props[ch]).get("prop", ""))] = true
		for ch in m.markers:
			var mp: String = str(GameData.dict_of(m.markers[ch]).get("prop", ""))
			if mp != "":
				ids[mp] = true
		for id in ids:
			if id == "":
				continue
			n_ids += 1
			var art_id: String = str(GameData.prop_def(id).get("art", id))
			if ArtCatalog.has_real_prop(StringName(art_id)):
				continue
			if N03_IDS.has(id):
				pend["N03-farm-art"] = str(pend.get("N03-farm-art", "")) + f + ":" + id + " "
			elif N06_IDS.has(id):
				pend["N06-farm-art-seasons"] = str(pend.get("N06-farm-art-seasons", "")) + f + ":" + id + " "
			elif DROPPED_WALLS.has(id):
				pend["P04 wall rows"] = str(pend.get("P04 wall rows", "")) + f + ":" + id + " "
			else:
				unknown.append("%s:%s" % [f, id])
	_t.check("map_prop_ids_exist", unknown.is_empty(), "every prop id named by data/maps/*.map (%d uses in %d maps) has real art or is pending by name: unknown %s" % [n_ids, files.size(), str(unknown)])
	for who in pend:
		_pending("map_prop_ids_exist", str(who), pend[who].strip_edges())


# ---------------------------------------------------------------- farm contract (RT16)

func _farm_checks(props: Dictionary) -> void:
	var t = _t
	var bad: Array[String] = []
	for id in FARM_CONTRACT:
		var c: Array = FARM_CONTRACT[id]
		var e: Dictionary = props.get(id, {})
		if e.is_empty():
			bad.append("%s: missing" % id)
			continue
		var size: Array = GameData.array_of(e.get("size", []))
		var pivot: Array = GameData.array_of(e.get("pivot", []))
		var fp: Vector2i = _fp(e)
		# a painted pack may re-canvas the sprite (props_manifest_sane holds its size and pivot to its image); the footprint is gameplay and never moves
		var canvas_ok: bool = str(e.get("_dir", PROPS_DIR)) != PROPS_DIR or (int(size[0]) == c[0] and int(size[1]) == c[1] and int(pivot[0]) == c[2] and int(pivot[1]) == c[3])
		if not canvas_ok or fp != Vector2i(c[4], c[5]):
			bad.append("%s: %s pivot %s fp %s vs %s" % [id, str(size), str(pivot), str(fp), str(c)])
	t.check("farm_contract_props_sizes_and_footprints", bad.is_empty(),
		"footprints coop_small 3x2, barn_small 4x3, animal_house 3x2, bench 2x1, the rest 1x1, and the P22 canvases coop_small 350x295 (155,218), barn_small 472x424 (208,313), animal_house 319x270 (143,199), paw_prints 39x49 (16,29), apple_tree 359x398 (172,355), bench 174x144 (78,107), signpost 84x130 (38,112) where P22's bake is the drawn art (a painted repaint keeps the footprint, its canvas is its own): %s" % str(bad))
	var row_bad: Array[String] = []
	for id in FARM_ROWS:
		var r: Array = FARM_ROWS[id]
		var def: Dictionary = GameData.prop_def(id)
		var solid: Dictionary = GameData.dict_of(def.get("solid", {}))
		var shape: String = str(solid.get("shape", ""))
		var num: int = int(solid.get("radius", solid.get("pad", 0)))
		if GameData.footprint_of(id) != Vector2i(r[0], r[1]) or shape != str(r[2]) or num != int(r[3]) or int(def.get("strips", -1)) != int(r[4]):
			row_bad.append("%s: fp %s solid %s %d strips %s vs %s" % [id, str(GameData.footprint_of(id)), shape, num, str(def.get("strips", "?")), str(r)])
	var mb: Dictionary = GameData.prop_def("mailbox_red")
	if str(mb.get("interact", "")) != "mailbox":
		row_bad.append("mailbox_red: interact %s (the V amendment wants mailbox)" % str(mb.get("interact", "")))
	t.check("farm_rows_complete", row_bad.is_empty(), "the 16 rows of design_farm.md 10.3 are in props_extra.lua verbatim (mailbox_red: the V amendment circle 20 + interact mailbox wins over the farm's circle 14): %s" % str(row_bad))


# ---------------------------------------------------------------- forest (DUNGEON addendum)

func _forest_checks(props: Dictionary) -> void:
	var t = _t
	var ids: Array[String] = []
	ids.append_array(FOREST_IDS)
	ids.append_array(EXPERIENCE_IDS)
	ids.append("hulen_eyes")
	var missing: Array[String] = []
	for id in ids:
		if not props.has(id) or not ArtCatalog.has_real_prop(StringName(id)):
			missing.append(id)
	t.check("forest_art_ids_exist", missing.is_empty(), "the %d ids of the forest set and the experience layer have real art in the manifest: missing %s" % [ids.size(), str(missing)])
	_crowns(props)
	_albedo(props)
	_defs(props)


func _crowns(props: Dictionary) -> void:
	var t = _t
	var bad_36: Array[String] = []
	var bad_size: Array[String] = []
	var rows: Array[String] = []
	for s in CROWNS:
		var c: Array = CROWNS[s]
		var R: float = float(c[0])
		for v in ["a", "b"]:
			var id: String = "crown_%s_%s" % [s, v]
			var e: Dictionary = props.get(id, {})
			if e.is_empty():
				bad_size.append(id + " missing")
				continue
			var im: Image = _image(_path(e))
			var pivot: Array = GameData.array_of(e["pivot"])
			var size: Array = GameData.array_of(e["size"])
			var b: Array = _bounds(im, 230)
			if b.is_empty():
				bad_size.append(id + " blank")
				continue
			var rx: float = float(b[2] - b[0]) / 2.0
			var ry: float = float(b[3] - b[1]) / 2.0
			var centre: float = float(pivot[1]) - float(b[1] + b[3]) / 2.0
			var low: Array = _bounds(im, 20)
			var shadow_bottom: float = float(low[3]) - float(pivot[1])
			var want_bottom: float = 60.0 * SIN36 + SIN36 * R
			var disc: Dictionary = GameData.dict_of(e.get("disc", {}))
			# 36 degrees: the baked ground shadow is a disc squashed to sin(36) = .59 (not a circle: not a 90 degree render) and the manifest says elev 36
			if float(e.get("elev", 0.0)) != 36.0 or absf(float(disc.get("shadow_squash", 0.0)) - SIN36) > 0.01 or absf(shadow_bottom - want_bottom) > 0.08 * R:
				bad_36.append("%s: elev %s squash %s shadow bottom %.0f px below the pivot vs %.0f" % [id, str(e.get("elev")), str(disc.get("shadow_squash")), shadow_bottom, want_bottom])
			if absf((rx + ry) / 2.0 - R) > 0.06 * R or absf(centre - 0.81 * R) > 0.06 * R:
				bad_size.append("%s: disc radius %.0f (want %.0f), centre %.0f above the pivot (want %.0f)" % [id, (rx + ry) / 2.0, R, centre, 0.81 * R])
			if absf(float(size[0]) - float(c[1])) > 0.12 * float(c[1]) or absf(float(size[1]) - float(c[2])) > 0.12 * float(c[2]):
				bad_size.append("%s: size %dx%d vs about %dx%d" % [id, int(size[0]), int(size[1]), int(c[1]), int(c[2])])
			rows.append("%s %dx%d R%.0f" % [id, int(size[0]), int(size[1]), (rx + ry) / 2.0])
	t.check("forest_crowns_baked_at_36", bad_36.is_empty(), "a crown is a sphere baked with the project camera: elev 36 in the manifest and the baked ground shadow squashed to %.2f (sin 36), offset 60 ground px: %s" % [SIN36, str(bad_36)])
	t.check("dungeon_crowns_present_and_sized", bad_size.is_empty(),
		"crown_{s,m,l}_{a,b}: silhouette disc radius 170 / 230 / 300 px (+-6 %%), sphere centre 0.81 R above the sort pivot (+-.06 R), size within 12 %% of 400x420 / 530x550 / 670x690: %s %s" % [" | ".join(rows), str(bad_size)])


func _albedo(props: Dictionary) -> void:
	var t = _t
	var bad: Array[String] = []
	var checked: Array[String] = []
	for id in props:
		var e: Dictionary = props[id]
		var pal: String = str(e.get("palette", ""))
		if not PALETTE.has(pal) or str(e.get("kind", "")) == "texture":
			continue
		# the drawn file is the approved painting itself (its entry names the source illustration)
		if str(e.get("illustration", "")) == "" or not FileAccess.file_exists("res://" + str(e["illustration"])):
			bad.append("%s: drawn from %s, which names no approved painting" % [id, _path(e)])
			continue
		var actual: Vector3 = _mean_rgb(_image(_path(e)), 240)
		var m: Vector3 = actual * AMBIENT / 255.0
		checked.append("%s %02x%02x%02x" % [id, int(m.x), int(m.y), int(m.z)])
		if minf(m.x, minf(m.y, m.z)) < 8.0:
			bad.append("%s: the painting loses ambient headroom under the forest grade" % id)
	# the emissive things are additive layers and the clamped ones say so: nothing above the ceiling is baked bright into a night prop
	for id in ADDITIVE_IDS:
		if str(GameData.dict_of(props.get(id, {})).get("blend", "")) != "add":
			bad.append("%s: emissive but not blend add" % id)
	for id in ["cave_stone_a", "runestone_dormant", "runestone_active", "pond_lily"]:
		if not bool(GameData.dict_of(props.get(id, {})).get("clamped", false)):
			bad.append("%s: above the ceiling (R > 77, G > 94, B > 133) but not marked clamped" % id)
	t.check("forest_albedo_within_ambient_headroom", bad.is_empty() and checked.size() >= 20,
		"%d forest props are drawn from approved paintings with usable ambient headroom under the forest grade and separate additive lights: %s" % [checked.size(), str(bad)])


func _defs(props: Dictionary) -> void:
	var t = _t
	var bad: Array[String] = []
	var ids: Array[String] = []
	ids.append_array(FOREST_IDS)
	ids.append_array(EXPERIENCE_IDS)
	ids.append_array(["hulen_eyes", "mailbox_red", "cave_stone"])
	for id in ids:
		var def: Dictionary = GameData.prop_def(id)
		if def.is_empty():
			bad.append(id + ": no row")
			continue
		if not def.has("footprint") or not def.has("solid") or not def.has("strips"):
			bad.append(id + ": footprint / solid / strips missing")
		var shape: String = str(GameData.dict_of(def.get("solid", {})).get("shape", ""))
		if not ["circle", "footprint", "none"].has(shape):
			bad.append("%s: solid shape '%s' is not one IsoArea builds" % [id, shape])
	# crowns: rim crowns are not solid; the free-standing S / M variants alias the rim crown with a circle of 130 / 175 ground px
	for s in ["s", "m", "l"]:
		for v in ["a", "b"]:
			var rim: Dictionary = GameData.prop_def("crown_%s_%s" % [s, v])
			if str(GameData.dict_of(rim.get("solid", {})).get("shape", "")) != "none":
				bad.append("crown_%s_%s: the rim crown must be solid none" % [s, v])
			if s != "l":
				var sd: Dictionary = GameData.prop_def("crown_%s_%s_solid" % [s, v])
				var solid: Dictionary = GameData.dict_of(sd.get("solid", {}))
				if str(sd.get("art", "")) != "crown_%s_%s" % [s, v] or str(solid.get("shape", "")) != "circle" or int(solid.get("radius", 0)) != (130 if s == "s" else 175) or GameData.footprint_of("crown_%s_%s_solid" % [s, v]) != Vector2i(1, 1):
					bad.append("crown_%s_%s_solid: %s" % [s, v, str(sd)])
	for id in ["bush_eyes_a", "bush_eyes_b"]:
		var d2: Dictionary = GameData.prop_def(id)
		if str(d2.get("interact", "")) != "enemy_host" or str(GameData.dict_of(d2.get("solid", {})).get("shape", "")) != "circle":
			bad.append("%s: solid circle + interact enemy_host expected, got %s" % [id, str(d2)])
	for id in ["cave_stone", "cave_stone_a", "cave_stone_b", "cave_stone_c", "cave_stone_d", "cave_stone_e"]:
		var d3: Dictionary = GameData.prop_def(id)
		var s3: Dictionary = GameData.dict_of(d3.get("solid", {}))
		if str(s3.get("shape", "")) != "circle" or int(s3.get("radius", 0)) != 40:
			bad.append("%s: solid circle r 40 expected, got %s" % [id, str(s3)])
	for id in ["cave_ring", "cave_ring_up", "home_rope"]:
		if str(GameData.dict_of(GameData.prop_def(id).get("solid", {})).get("shape", "")) != "none":
			bad.append("%s: solid none expected" % id)
	for id in ["runestone_dormant", "runestone_active"]:
		var d4: Dictionary = GameData.prop_def(id)
		if str(d4.get("interact", "")) != "runestone" or str(GameData.dict_of(d4.get("solid", {})).get("shape", "")) != "circle":
			bad.append("%s: a solid ground circle (the ellipse on screen) + interact runestone expected, got %s" % [id, str(d4)])
	var mb: Dictionary = GameData.prop_def("mailbox_red")
	if GameData.footprint_of("mailbox_red") != Vector2i(1, 1) or int(GameData.dict_of(mb.get("solid", {})).get("radius", 0)) != 20 or str(mb.get("interact", "")) != "mailbox":
		bad.append("mailbox_red: footprint 1x1, circle 20, interact mailbox expected, got %s" % str(mb))
	var ch: Dictionary = GameData.prop_def("chest_noegle")
	if GameData.footprint_of("chest_noegle") != Vector2i(1, 1) or int(GameData.dict_of(ch.get("solid", {})).get("radius", 0)) != 22 or str(ch.get("interact", "")) != "chest" or str(ch.get("tier", "")) != "noegle":
		bad.append("chest_noegle: footprint 1x1, circle 22, interact chest, tier noegle expected, got %s" % str(ch))
	# the circle radii of the crowns (0.75 x R rounded: S 112-148, M 158-194, L 202-243) lie inside the ranges of the sketch table
	t.check("dungeon_prop_defs_complete", bad.is_empty(), "every id of the forest set and the experience layer has footprint + solid (a shape IsoArea builds) + strips; crowns (rim: none; free-standing S 130 / M 175), bush_eyes enemy_host, cave_stone r 40, runestone, mailbox_red, chest_noegle as ordered: %s" % str(bad.slice(0, 5)))
	var in_catalog: Array[String] = []
	ArtCatalog.clear_missing()
	for id in EXPERIENCE_IDS:
		var art: Dictionary = ArtCatalog.prop(StringName(id))
		if not bool(art.get("real", false)):
			in_catalog.append(id)
	var missing: Array[String] = ArtCatalog.missing()
	t.check("dungeon_ids_in_catalog", in_catalog.is_empty() and missing.is_empty(), "ArtCatalog.prop() serves real art for telegraph_ring_s/m/l, telegraph_line, boss_arena_ring, halo_amber, halo_violet, crown_spark, fx_hit_spark, fx_heal_sparkle, tornebaer, chest_noegle and missing() stays empty: %s %s" % [str(in_catalog), str(missing)])


# ---------------------------------------------------------------- painted props: frames, textures, light, rings

func _image_props(props: Dictionary) -> void:
	var t = _t
	var bad: Array[String] = []
	for id in ["eyes_glow", "pond_ripple"]:
		var e: Dictionary = props.get(id, {})
		var frames: int = int(e.get("frames", 0))
		var fsz: Array = GameData.array_of(e.get("frame_size", []))
		var size: Array = GameData.array_of(e.get("size", []))
		if (id == "eyes_glow" and frames != 2) or (id == "pond_ripple" and frames != 4) or fsz.size() < 2 or int(size[0]) != frames * int(fsz[0]) or int(size[1]) != int(fsz[1]):
			bad.append("%s: %d frames of %s in %s" % [id, frames, str(fsz), str(size)])
	for id in ["path_tile_o", "pond_water_o", "floor_patch_a", "floor_patch_b", "floor_patch_c"]:
		var e2: Dictionary = props.get(id, {})
		var size2: Array = GameData.array_of(e2.get("size", []))
		if not _arr_eq(size2, [256, 256]) or not bool(e2.get("seamless", false)):
			bad.append("%s: not a 256 px seamless texture" % id)
			continue
		var im: Image = _image(_path(e2))
		var edge: float = 0.0
		var inner: float = 0.0
		for k in 256:
			edge += _col_diff(im.get_pixel(0, k), im.get_pixel(255, k)) + _col_diff(im.get_pixel(k, 0), im.get_pixel(k, 255))
			inner += _col_diff(im.get_pixel(100, k), im.get_pixel(101, k)) + _col_diff(im.get_pixel(k, 100), im.get_pixel(k, 101))
		if edge > inner * 1.6 + 256.0:
			bad.append("%s: wrap-around step %.1f vs inner %.1f" % [id, edge / 512.0, inner / 512.0])
	# lantern_light: 1.0 at the centre, 0.31 at 60 % of the radius, 0 at 100 %
	var ll: Dictionary = props.get("lantern_light", {})
	var lim: Image = _image(_path(ll))
	if lim == null or lim.get_width() != 512 or lim.get_height() != 512:
		bad.append("lantern_light: 512 px expected")
	else:
		var c0: float = lim.get_pixel(256, 256).r
		var c60: float = lim.get_pixel(256 + 154, 256).r
		var c100: float = lim.get_pixel(511, 256).r
		if absf(c0 - 1.0) > 0.02 or absf(c60 - 0.31) > 0.03 or c100 > 0.02:
			bad.append("lantern_light: profile %.2f / %.2f / %.2f (want 1.0 / 0.31 / 0)" % [c0, c60, c100])
	# telegraph rings are ground circles: squashed to sin 36
	for id in ["telegraph_ring_s", "telegraph_ring_m", "telegraph_ring_l"]:
		var e3: Dictionary = props.get(id, {})
		var b: Array = _bounds(_image(_path(e3)), 200)
		if b.is_empty() or absf(float(b[3] - b[1]) / float(b[2] - b[0]) - SIN36) > 0.03:
			bad.append("%s: not a ground ellipse squashed to .59 (%s)" % [id, str(b)])
	var firefly: Dictionary = props.get("firefly_dot", {})
	if not _arr_eq(GameData.array_of(firefly.get("size", [])), [24, 24]):
		bad.append("firefly_dot: 24 x 24 expected")
	var rg: Dictionary = props.get("rune_glow", {})
	var rs: Dictionary = props.get("runestone_active", {})
	if not _arr_eq(GameData.array_of(rg.get("size", [])), GameData.array_of(rs.get("size", []))) or not _arr_eq(GameData.array_of(rg.get("pivot", [])), GameData.array_of(rs.get("pivot", []))):
		bad.append("rune_glow must have the size and pivot of runestone_active")
	var eg: Dictionary = props.get("bush_eyes_a", {})
	if GameData.dict_of(eg.get("eyes", {})).is_empty():
		bad.append("bush_eyes_a: the manifest should say where eyes_glow sits")
	t.check("image_props_contract", bad.is_empty(), "painted props: eyes_glow 2 frames, pond_ripple 4 frames, five seamless 256 px textures (wrap step), lantern_light 1.0 / 0.31 / 0, telegraph rings squashed to .59, firefly 24x24, rune_glow = runestone_active: %s" % str(bad))


# ---------------------------------------------------------------- backdrops

func _backdrops() -> void:
	var t = _t
	var bad: Array[String] = []
	for theme in ["hyggebyen", "forest"]:
		var art: Dictionary = ArtCatalog.backdrop(StringName(theme))
		if not bool(art.get("real", false)):
			bad.append("%s: not real" % theme)
			continue
		var sky: Texture2D = art["sky"]
		var far: Texture2D = art["far"]
		if sky.get_width() != 1920 or sky.get_height() != 1080 or far.get_width() != 2048 or far.get_height() != 1280:
			bad.append("%s: sky %dx%d far %dx%d" % [theme, sky.get_width(), sky.get_height(), far.get_width(), far.get_height()])
		var fim: Image = _image(far.resource_path)
		if fim == null:
			bad.append("%s: far layer unreadable" % theme)
			continue
		var step: float = 0.0
		for y in range(0, fim.get_height(), 8):
			step += _col_diff(fim.get_pixel(0, y), fim.get_pixel(fim.get_width() - 1, y))
		step /= float(fim.get_height() / 8)
		if step > 6.0:
			bad.append("%s: far layer not seamless in x (step %.1f)" % [theme, step])
		var top: Color = fim.get_pixel(1000, 5)
		if top.a > 0.05:
			bad.append("%s: far layer must be transparent at the top (the sky shows above the treetops)" % theme)
	t.check("backdrops_present", bad.is_empty(), "hyggebyen (lavender dusk) and forest (night navy with haze): the sky 1920x1080 + the far layer 2048x1280 ArtCatalog serves (the painted backdrop_<theme>_far prop), seamless in x, transparent top edge: %s" % str(bad))
	t.check("farm_backdrop_installed",bool(ArtCatalog.backdrop(&"farm").get("real",false)),"the selected painted farm backdrop is installed")


# ---------------------------------------------------------------- worlds: fixtures, farm, Hyggebyen

func _worlds(_props: Dictionary) -> void:
	var t = _t
	if not await t.start_world():
		return
	var w: WorldRoot2D = t.world()
	var allowed: Array[String] = ["backdrop:farm"]
	for id in DROPPED_WALLS:
		allowed.append("prop:" + id)
	w._enter(&"_fixture_ortho", &"default")           # leave the start area (it is parked), then drop every parked area: every build below is a FRESH build
	w.free_parked_areas()
	ArtCatalog.reset()
	AreaTileSet.reset()                                  # its source cache would otherwise hide the art lookups of a second build
	for id in [&"_fixture_iso", &"_fixture_ortho"]:
		w._enter(id, &"default")
		await t.frames(2)
	var missing: Array[String] = ArtCatalog.missing()
	var unexpected: Array[String] = []
	var pend: Array[String] = []
	for m in missing:
		if allowed.has(m):
			pend.append(m)
		else:
			unexpected.append(m)
	t.check("fixtures_missing_only_pending", unexpected.is_empty(), "the iso and the ortho fixture build with real art for every terrain and prop: missing() holds nothing but the pending ones %s; unexpected %s" % [str(pend), str(unexpected)])
	if "backdrop:farm" in pend:
		_pending("fixtures_missing_only_pending", "N03-farm-art (wave 5)", "backdrop:farm (the iso fixture's @theme farm)")
	var walls: Array[String] = []
	for m in pend:
		if m.begins_with("prop:"):
			walls.append(m)
	if not walls.is_empty():
		_pending("fixtures_missing_only_pending", "P04-area-framework (handoff)", "%s: the ortho fixture's W cells still ask for the dropped wall props (AreaTileSet.WALL_PROPS); P22 ships wall_void_o as the dark border tile" % str(walls))
	for id in [&"farm", &"hyggebyen"]:
		if not WorldRoot2D.has_area(id):
			_pending("%s_map_art_complete" % id, "P11-maps-iso / N01-farm-map (same wave)", "data/maps/%s.map does not exist yet" % id)
			continue
		w._enter(&"_fixture_iso", &"default")
		w.free_parked_areas()
		ArtCatalog.reset()
		AreaTileSet.reset()
		w._enter(id, &"default")
		await t.frames(2)
		var miss: Array[String] = ArtCatalog.missing()
		var strict: Array[String] = []
		var later: Array[String] = []
		for m in miss:
			var pid: String = m.get_slice(":", 1)
			if m == "backdrop:farm" or N03_IDS.has(pid) or N06_IDS.has(pid):
				later.append(m)
			else:
				strict.append(m)
		if id == &"hyggebyen":
			t.check("hyggebyen_map_art_complete", strict.is_empty(), "data/maps/hyggebyen.map builds with real art for every terrain, prop and backdrop: missing %s" % str(strict))
		else:
			t.check("farm_map_art_only_pending_ids", strict.is_empty(), "data/maps/farm.map: everything but the N03 kit / N06 dress / backdrop:farm has real art: missing %s" % str(strict))
			if not later.is_empty():
				_pending("farm_map_art_only_pending_ids", "N03-farm-art / N06-farm-art-seasons", str(later))
	w._enter(&"farm" if WorldRoot2D.has_area(&"farm") else &"_fixture_iso", &"default")
	await t.frames(1)


# ---------------------------------------------------------------- ORTHO_DECISION.md, budget, README

func _decision() -> void:
	var t = _t
	var txt: String = FileAccess.get_file_as_string(DECISION) if FileAccess.file_exists(DECISION) else ""
	t.check("ortho_decision_written", txt != "" and ("`ortho`" in txt or "iso fallback" in txt) and ("2026-" in txt) and ("art_environment_" in txt),
		"assets/iso_tiles/ORTHO_DECISION.md exists with the decision (ortho | iso fallback), a date and the screenshot names")
	t.check("ortho_decision_mentions_rim_depth", "rim.wall_depth = 0" in txt and "wall_depth_iso = 0" in txt and "73 / 73 / 145" in txt and "35 / 40 / 61" in txt,
		"it records rim.wall_depth = 0 from the start, the iso fallback's rim.wall_depth_iso = 0 and the measured _enter times (73 / 73 / 145 ms with wall depth 1, 35 / 40 / 61 ms with depth 0)")
	t.check("ortho_decision_mentions_crowns", ("sphere" in txt) and ("crown" in txt) and ("SoftGround" in txt) and ("DECAL" in txt or "decal" in txt) and ("does not depend" in txt),
		"it says the forest look does not depend on ortho vs iso fallback for its crowns (spheres), only the floor tiles and the border wall do, and that the smooth path and pond are decals (V8's SoftGround)")


func _budget() -> void:
	var total: int = 0
	for dir_path in [TILES_DIR, PROPS_DIR, BACKDROP_DIR]:
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".png") or f.ends_with(".webp") or f.ends_with(".json"):
				var fa := FileAccess.open(dir_path + f, FileAccess.READ)
				if fa != null:
					total += int(fa.get_length())
	# Painted PNG compatibility fixtures retain their filenames and canvases.
	# This is a disk budget; city VRAM and atlas-cell budgets are unchanged.
	_t.check("budget", total < 40000000, "top-level painted fixture archive weighs %.1f MB (budget 40 MB lossless / PNG); native canvas and live VRAM limits checked separately" % (float(total) / 1.0e6))


func _readme() -> void:
	var txt: String = FileAccess.get_file_as_string(README) if FileAccess.file_exists(README) else ""
	_t.check("readme_verdict", "accepted at" in txt and "known weaknesses" in txt.to_lower() and "Honest notes" in txt, "tools/art/environment/README.md carries the honest notes and the verdict line")


# ================================================================== windowed (tests/run_playtest.sh --windowed --only=art_environment)
## chars of the mixed-terrain maps: [a, b]; the cells take b where (x * 7 + y * 13) % 5 == 0
const MIXES := [
	{"id": "mix_farm_grass", "projection": "iso", "theme": "farm", "ambient": "farm", "ground": [".", ","], "terrains": ["grass", "grass_flowers"], "hour": 11.0},
	{"id": "mix_town_grass", "projection": "iso", "theme": "hyggebyen", "ambient": "hyggebyen", "ground": [".", ","], "terrains": ["grass_hyggebyen", "grass_hyggebyen_flowers"], "hour": 11.0},
	{"id": "mix_forest_iso", "projection": "iso", "theme": "forest", "ambient": "forest", "ground": [".", ","], "terrains": ["forest_floor", "forest_floor_glow"], "hour": 11.0},
	{"id": "mix_forest_ortho", "projection": "ortho", "theme": "forest", "ambient": "forest", "ground": ["m", "g"], "terrains": ["forest_floor_o", "forest_floor_glow_o"], "hour": 11.0},
	{"id": "mix_path_ortho", "projection": "ortho", "theme": "forest", "ambient": "forest", "ground": ["m", "p"], "terrains": ["forest_floor_o", "moss_path_o"], "hour": 11.0},
]

var _last_pairs: int = 0


func run_windowed(t) -> void:
	_t = t
	ArtCatalog.reset()
	if not await t.start_world():
		return
	var w: WorldRoot2D = t.world()
	w.warm_in_headless = true
	await w.warm_clips()
	var p: Node2D = w.player
	var cam: Camera2D = p.get("camera")
	var seams_ok: bool = true
	var probe_ok: bool = true
	for mix in MIXES:
		var id := StringName("_p22_" + str(mix["id"]))
		WorldRoot2D.register_map(id, AreaMap.parse_text(_mix_text(str(id), mix)))
		w._enter(id, &"default")
		w.day_night.override_hour = float(mix["hour"])
		w.day_night.snap()
		var a: IsoArea = w.area
		p.visible = false
		for z in [0.3, 0.4, 0.7]:
			cam.zoom = Vector2.ONE * z
			p.global_position = a.cell_to_global(Vector2i(8, 6))
			cam.reset_smoothing()
			await t.seconds(0.35)
			var img: Image = await t.capture("seams_%s_zoom_%d" % [mix["id"], int(z * 100.0)])
			var st: Dictionary = _seam_step(w, a, img.duplicate() as Image, mix["terrains"])
			var excess: float = float(st["border"]) - float(st["control"])
			var ok: bool = _last_pairs >= 6 and excess < 3.0 / 255.0
			seams_ok = seams_ok and ok
			t.check("filter_seams_%s_zoom_%d" % [mix["id"], int(z * 100.0)], ok,
				"%s: luminance step across %d tile borders %.1f / 255 vs %.1f / 255 across tile middles (excess %.1f, limit 3) at zoom %.1f" % [str(mix["terrains"]), _last_pairs, float(st["border"]) * 255.0, float(st["control"]) * 255.0, excess * 255.0, z])
			if z == 0.4:
				var neg: Dictionary = _seam_step(w, a, img.duplicate() as Image, mix["terrains"], 0.08)
				var nex: float = float(neg["border"]) - float(neg["control"])
				probe_ok = probe_ok and nex > 3.0 / 255.0
		WorldRoot2D.unregister_map(id)
	t.check("filter_seams_mixed_terrains", seams_ok, "grass + flowers (farm, Hyggebyen), forest floor + glow (iso fallback, ortho) and the moss path mix without a hairline at zoom 0.3 / 0.4 / 0.7 (Ground filter 2, atlases without mipmaps)")
	t.check("filter_seams_probe_sees_a_hairline", probe_ok, "negative control: a deliberate 20 / 255 hairline on the borders reads as excess > 3 / 255 for every mix")
	p.visible = true
	await _forest_readable(t, w, p, cam)
	await _shots(t, w, p, cam)


## map text of a mixed-terrain test platform (16 x 12, no props): ground chars a / b by a hash
func _mix_text(id: String, mix: Dictionary) -> String:
	var ground: Array[String] = []
	var objs: Array[String] = []
	var ch: Array = mix["ground"]
	for y in 12:
		var g := ""
		var o := ""
		for x in 16:
			if x == 0 or y == 0 or x == 15 or y == 11:
				g += "#"
			else:
				g += str(ch[1]) if (x * 7 + y * 13) % 5 == 0 else str(ch[0])
			o += "@" if (x == 8 and y == 6) else "."
		ground.append(g)
		objs.append(o)
	var head := "@id %s\n@title ZONE_FARM\n@projection %s\n@ambient %s\n@theme %s\n@zone farm\n@flight true\n" % [id, mix["projection"], mix["ambient"], mix["theme"]]
	return head + "@ground\n" + "\n".join(ground) + "\n@objects\n" + "\n".join(objs) + "\n"


func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## median luminance step across the shared borders of neighbouring cells of the given terrains (border) and across their middles (control)
func _seam_step(w: WorldRoot2D, a: IsoArea, img: Image, ids: Array, inject: float = 0.0) -> Dictionary:
	var ct: Transform2D = w.get_viewport().get_canvas_transform()
	var terr: Dictionary = a.get("_terrain_of")
	var iso: bool = a.projection == &"iso"
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
				var edge_len: float = 74.0 if iso else (56.0 if step.x != 0 else 96.0)
				var reach: float = edge_len * zoom * 0.12
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


# ---------------------------------------------------------------- the forest map of the previews (generated; the real floors are D1's)

const FOREST_PROPS := {"A": "crown_l_a", "B": "crown_l_b", "C": "crown_m_a", "D": "crown_m_b", "E": "crown_s_a", "F": "crown_s_b_solid", "R": "runestone_dormant", "H": "chest_noegle",
	"X": "cave_ring", "a": "cave_stone_a", "b": "cave_stone_b", "c": "cave_stone_c", "d": "cave_stone_d", "e": "cave_stone_e", "U": "bush_eyes_a", "V": "bush_eyes_b", "W": "empty_bush",
	"L": "pond_lily", "G": "glowmush_teal", "K": "glowmush_pink", "J": "glowmush_blue", "Z": "rock_dark", "Q": "home_rope"}


func _path_y(x: int) -> int:
	return int(round(17.0 + 4.0 * sin(float(x) / 5.5) - float(x) * 0.1))


## 44 x 30 ortho floor: void rim, forest floor with glow cells, a winding moss path, a pond, rim crowns, the runestone, the chest on the pond shore, the Hulen ring with its stones
func _forest_text(id: String) -> String:
	var W: int = 44
	var H: int = 30
	var placed: Dictionary = {}
	var spots: Array = [[5, 6, "A"], [14, 4, "C"], [22, 3, "A"], [31, 5, "B"], [39, 7, "C"], [3, 16, "B"], [41, 18, "A"], [6, 26, "C"], [16, 27, "A"], [27, 27, "B"], [37, 27, "A"],
		[34, 13, "D"], [11, 21, "E"], [24, 21, "F"], [28, 9, "E"], [20, 11, "D"],
		[17, 15, "R"], [12, 12, "H"], [36, 20, "X"], [33, 18, "a"], [39, 18, "b"], [33, 22, "c"], [39, 22, "d"], [36, 24, "e"],
		[26, 16, "U"], [9, 21, "V"], [30, 12, "W"], [7, 9, "L"], [9, 10, "L"], [11, 8, "L"], [22, 14, "G"], [30, 19, "K"], [8, 23, "G"], [36, 10, "J"], [19, 19, "Z"], [23, 8, "Z"]]
	for sp in spots:
		placed[Vector2i(int(sp[0]), int(sp[1]))] = str(sp[2])
	var ground: Array[String] = []
	var objs: Array[String] = []
	var spawn := Vector2i(15, _path_y(15) + 1)
	for y in H:
		var g := ""
		var o := ""
		for x in W:
			var c := "m"
			if x < 2 or y < 2 or x > W - 3 or y > H - 3:
				c = "#"
			elif absi(y - _path_y(x)) <= 1:
				c = "p"
			elif pow(float(x - 9) / 5.0, 2.0) + pow(float(y - 9) / 3.4, 2.0) < 1.0:
				c = "~"
			elif (x * 5 + y * 11) % 17 == 0:
				c = "g"
			g += c
			var oc := "."
			if Vector2i(x, y) == spawn:
				oc = "@"
			elif placed.has(Vector2i(x, y)):
				oc = str(placed[Vector2i(x, y)])
			o += oc
		ground.append(g)
		objs.append(o)
	var head := "@id %s\n@title ZONE_DARK_FOREST\n@projection ortho\n@ambient forest\n@theme forest\n@zone dark_forest\n@depth 1\n@flight false\n" % id
	var props := ""
	for k in FOREST_PROPS:
		props += "@prop %s %s\n" % [k, FOREST_PROPS[k]]
	return head + props + "@marker 1 spawn name=default\n@ground\n" + "\n".join(ground) + "\n@objects\n" + "\n".join(objs) + "\n"


func _floor_luma(img: Image, p: Vector2) -> float:
	return _luma(img.get_pixelv(Vector2i(p)))


func _patch_colour(img: Image, centre: Vector2, half_size: Vector2) -> Color:
	var rect := Rect2i(centre-half_size, half_size*2.0).intersection(Rect2i(Vector2i.ZERO,img.get_size()))
	var sum := Color(0,0,0,0)
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			sum += img.get_pixel(x,y)
	return sum / float(maxi(1,rect.size.x*rect.size.y))


func _ground_contrast(path: Color, floor_colour: Color, pond: Color) -> bool:
	return _luma(path)-_luma(floor_colour)>=10.0/255.0 and (pond.b-pond.r)-(floor_colour.b-floor_colour.r)>=12.0/255.0


func _crown_edges(img: Image, underlay: Image, centre: Vector2, radius: float) -> int:
	var good := 0
	for k in 12:
		var ang := deg_to_rad(200.0+14.0*float(k)+(0.0 if k<6 else 20.0))
		var dir := Vector2(cos(ang),sin(ang))
		# The painted silhouette is irregular. Search around the authored disc,
		# requiring the dark edge to belong to the crown, not floor texture.
		for distance in range(int(radius*0.6),int(radius*1.4)):
			var at := centre+dir*float(distance)
			var ink := img_px(img,at)
			var behind := img_px(underlay,at)
			var changed := absf(ink.r-behind.r)+absf(ink.g-behind.g)+absf(ink.b-behind.b)
			var lo := _luma(ink)
			var outside := _luma(img_px(img,at+dir*10.0))
			var inside := _luma(img_px(img,at-dir*10.0))
			if changed>=4.0/255.0 and outside-lo>=6.0/255.0 and inside-lo>=4.0/255.0:
				good += 1
				break
	return good


func _forest_readable(t, w: WorldRoot2D, p: Node2D, cam: Camera2D) -> void:
	var id := &"_p22_forest"
	WorldRoot2D.register_map(id, AreaMap.parse_text(_forest_text(String(id))))
	w._enter(id, &"default")
	await t.frames(3)
	var a: IsoArea = w.area
	var ct0: Transform2D
	cam.zoom = Vector2.ONE * 0.4
	var vis: IsoChibiSprite2D = p.get("visual")
	vis.set_process(false)
	p.set_physics_process(false)
	# the player on bare floor, 3 cells off the path: the crown (E at 11,21) and the pond are in view from here
	var stand := Vector2i(14, 20)
	p.global_position = a.cell_to_global(stand) + Vector2(0, 28)
	cam.reset_smoothing()
	await t.seconds(0.5)
	var with_img: Image = await t.capture("forest_player")
	p.visible = false
	await t.frames(2)
	var without: Image = await t.capture("forest_empty")
	p.visible = true
	ct0 = w.get_viewport().get_canvas_transform()
	# (a) the player's silhouette: the pixels that change when the player is hidden; its ring against the floor behind it
	var size := Vector2i(with_img.get_size())
	var ring_sum: float = 0.0
	var floor_sum: float = 0.0
	var ring_n: int = 0
	var inner_n: int = 0
	var inner_sum: float = 0.0
	var mask: Dictionary = {}
	var feet: Vector2i = Vector2i(ct0 * p.global_position)
	for y in range(maxi(feet.y - 130, 1), mini(feet.y + 30, size.y - 1)):
		for x in range(maxi(feet.x - 70, 1), mini(feet.x + 70, size.x - 1)):
			var d: Color = with_img.get_pixel(x, y) - without.get_pixel(x, y)
			if absf(d.r) + absf(d.g) + absf(d.b) > 0.03:
				mask[Vector2i(x, y)] = true
	for k in mask:
		var c: Vector2i = k
		var edge: bool = not (mask.has(c + Vector2i(1, 0)) and mask.has(c - Vector2i(1, 0)) and mask.has(c + Vector2i(0, 1)) and mask.has(c - Vector2i(0, 1)))
		if edge:
			ring_sum += _luma(with_img.get_pixelv(c))
			floor_sum += _luma(without.get_pixelv(c))
			ring_n += 1
		else:
			inner_sum += _luma(with_img.get_pixelv(c))
			inner_n += 1
	var ring: float = ring_sum / float(maxi(ring_n, 1))
	var floor_l: float = floor_sum / float(maxi(ring_n, 1))
	var inner: float = inner_sum / float(maxi(inner_n, 1))
	t.check("forest_player_edge_separates_from_the_floor", ring_n >= 40 and (absf(ring - floor_l) >= 4.0 / 255.0 or absf(ring - inner) >= 4.0 / 255.0),
		"the pack outline (75,60,73) at zoom 0.4 on the night floor: the %d edge pixels of the figure read %.0f / 255 against the floor %.0f / 255 and the body %.0f / 255 (needs >= 4 / 255 against either: the thin outline of a SHADED figure on the night floor is marginal by design; V8's unshaded actors make it pop)" % [ring_n, ring * 255.0, floor_l * 255.0, inner * 255.0])
	# (b) a crown's painted outline against the floor and its own leaves.
	var rec: Dictionary = {}
	for r in a.prop_nodes:
		if str(r["id"]) == "crown_s_a":
			rec = r
	var good: int = 0
	var crown_control := -1
	var crown_info: String = "crown_s_a not placed"
	if not rec.is_empty():
		var node: Node2D = (rec["nodes"] as Array)[0]
		var disc: Dictionary = GameData.dict_of(GameData.dict_of(_props().get("crown_s_a", {})).get("disc", {}))
		var R: float = float(disc.get("radius", 170.0))
		var centre: Vector2 = ct0 * (node.global_position - Vector2(0, 0.81 * R))
		var rs: float = (R - 3.0) * ct0.get_scale().x
		var visibility: Array[bool] = []
		for part in rec["nodes"]:
			visibility.append(part.visible)
			part.visible=false
		p.visible=false
		var underlay: Image = await t.capture("forest_crown_underlay")
		for i in visibility.size():
			rec["nodes"][i].visible=visibility[i]
		p.visible=true
		good=_crown_edges(without,underlay,centre,rs)
		crown_control=_crown_edges(underlay,underlay,centre,rs)
		crown_info = "%d of 12 rays around the painted silhouette (nominal radius %.0f px) show >=6/255 outside and >=4/255 inside contrast, attributable to the crown; missing-crown control %d" % [good,rs,crown_control]
	t.check("forest_crown_outline_readable", good >= 7 and crown_control==0, crown_info)
	# (c) the lit path and the pond against the floor: readable at a glance (a bare probe map: floor | path | water, no props, no player)
	var probe := &"_p22_ground_probe"
	var rows: Array[String] = []
	var orows: Array[String] = []
	for y in 12:
		var g := ""
		var o := ""
		for x in 16:
			if x == 0 or y == 0 or x == 15 or y == 11:
				g += "#"
			elif x < 5:
				g += "m"
			elif x < 10:
				g += "p"
			else:
				g += "~"
			o += "@" if (x == 2 and y == 5) else "."
		rows.append(g)
		orows.append(o)
	WorldRoot2D.register_map(probe, AreaMap.parse_text("@id _p22_ground_probe\n@title ZONE_DARK_FOREST\n@projection ortho\n@ambient forest\n@theme forest\n@zone dark_forest\n@depth 1\n@flight false\n@ground\n%s\n@objects\n%s\n" % ["\n".join(rows), "\n".join(orows)]))
	w._enter(probe, &"default")
	await t.frames(3)
	var a2: IsoArea = w.area
	p.visible = false
	p.global_position = a2.cell_to_global(Vector2i(8, 6))
	cam.reset_smoothing()
	await t.seconds(0.4)
	var pimg: Image = await t.capture("forest_ground_probe")
	var ct1: Transform2D = w.get_viewport().get_canvas_transform()
	# Average several painted tile interiors: a single pixel can be a pencil
	# stroke or path pebble. Keep the original contrast thresholds.
	var half_size := Vector2(96.0*1.4,56.0*3.3)*ct1.get_scale()
	var path_c := _patch_colour(pimg,ct1*a2.cell_to_global(Vector2i(7,6)),half_size)
	var floor_c := _patch_colour(pimg,ct1*a2.cell_to_global(Vector2i(3,6)),half_size)
	var pond_c := _patch_colour(pimg,ct1*a2.cell_to_global(Vector2i(12,6)),half_size)
	var lp: float = _luma(path_c)
	var lf: float = _luma(floor_c)
	var path_ok: bool = lp - lf >= 10.0 / 255.0
	var pond_hue := (pond_c.b-pond_c.r)-(floor_c.b-floor_c.r)
	var pond_ok: bool = pond_hue * 255.0 >= 12.0
	var floor_control := _ground_contrast(floor_c,floor_c,floor_c)
	t.check("forest_ground_reads_path_and_pond", _ground_contrast(path_c,floor_c,pond_c) and not floor_control,
		"painted tile patch means at zoom .4: path %s is %.2f/255 lighter than floor %s (needs 10); pond %s is %.2f/255 bluer relative to red than the floor (needs 12); same-floor control fails both" % [path_c.to_html(false),(lp-lf)*255.0,floor_c.to_html(false),pond_c.to_html(false),pond_hue*255.0])
	WorldRoot2D.unregister_map(probe)
	p.visible = true
	t.check("forest_ortho_readable", ring_n >= 40 and good >= 7 and path_ok and pond_ok,
		"art.forest_ortho_readable: the outline (75,60,73), the crowns' dark outline, the path and the pond stay readable on the forest night floor (#1c2138 clear, grade 4d5e85) at zoom 0.4")
	t.expect_not_blank(with_img, Rect2i(240, 120, 800, 480), "forest_ortho_readable: the forest picture is not a flat fill")
	p.set_physics_process(true)
	vis.set_process(true)
	WorldRoot2D.unregister_map(id)


func img_px(img: Image, at: Vector2) -> Color:
	return img.get_pixelv(Vector2i(clampf(at.x, 0.0, float(img.get_width() - 1)), clampf(at.y, 0.0, float(img.get_height() - 1))))


## the pictures the package is judged by: the real farm and Hyggebyen maps (when they exist) at noon / dusk / night, the generated forest, and a board of every new prop
func _shots(t, w: WorldRoot2D, p: Node2D, cam: Camera2D) -> void:
	for id in [&"farm", &"hyggebyen"]:
		if not WorldRoot2D.has_area(id):
			t.skip("art_environment.shots_%s no data/maps/%s.map yet (P11 / N01)" % [id, id])
			continue
		w._enter(id, &"default")
		cam.zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
		for hour in [11.0, 19.2, 23.0]:
			w.day_night.override_hour = hour
			w.day_night.snap()
			w.area.set_night_factor(w.day_night.glow_factor)
			await t.seconds(0.5)
			var img: Image = await t.capture("%s_%02d" % [id, int(hour)])
			t.expect_not_blank(img, Rect2i(320, 140, 640, 420), "%s at %.1f h renders (real art)" % [id, hour])
		# the platform edge zoomed out: the sky and the far canopy of the theme (backdrops) around the floating platform
		w.day_night.override_hour = 11.0
		w.day_night.snap()
		w.area.set_night_factor(0.0)
		cam.zoom = Vector2.ONE * 0.3
		var rect: Rect2 = w.area.play_rect
		p.global_position = w.area.to_global(Vector2(rect.get_center().x, rect.end.y - 160.0))
		cam.reset_smoothing()
		await t.seconds(0.5)
		await t.capture("%s_edge_zoom30" % id)
		cam.zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
	var fid := &"_p22_forest_view"
	WorldRoot2D.register_map(fid, AreaMap.parse_text(_forest_text(String(fid))))
	w._enter(fid, &"default")
	cam.zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
	p.global_position = w.area.cell_to_global(Vector2i(17, _path_y(17)))
	cam.reset_smoothing()
	await t.seconds(0.6)
	await t.capture("forest_view")
	cam.zoom = Vector2.ONE * 0.3
	p.global_position = w.area.cell_to_global(Vector2i(24, 15))
	cam.reset_smoothing()
	await t.seconds(0.5)
	await t.capture("forest_wide")
	cam.zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
	WorldRoot2D.unregister_map(fid)
	# the board: every new prop on a plain platform, three per row, at game zoom: pivots on the cell centres, footprints, glow
	var board: Array[String] = []
	for line in _props().keys():
		board.append(str(line))
	board.sort()
	var skip_ids: Array = ["lantern_light", "path_tile_o", "pond_water_o", "floor_patch_a", "floor_patch_b", "floor_patch_c", "mist_patch_a", "mist_patch_b", "boss_arena_ring", "tree_giant_crown", "firefly_dot"]
	var ids: Array[String] = []
	for b in board:
		if not skip_ids.has(b) and not b.begins_with("crop_") and not b.begins_with("platform_"):
			ids.append(b)
	var per_page: int = 36
	var page: int = 0
	while page * per_page < ids.size():
		var chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
		var objs: Array[String] = []
		var ground: Array[String] = []
		var props_txt := ""
		var cols: int = 6
		var rows: int = 6
		var W: int = cols * 5 + 3
		var H: int = rows * 5 + 3
		var grid: Dictionary = {}
		for k in per_page:
			var idx: int = page * per_page + k
			if idx >= ids.size():
				break
			var cx: int = 3 + (k % cols) * 5
			var cy: int = 4 + (k / cols) * 5
			grid[Vector2i(cx, cy)] = chars[k]
			props_txt += "@prop %s %s\n" % [chars[k], ids[idx]]
		for y in H:
			var g := ""
			var o := ""
			for x in W:
				g += "#" if (x == 0 or y == 0 or x == W - 1 or y == H - 1) else "."
				o += "@" if (x == 1 and y == 1) else (str(grid[Vector2i(x, y)]) if grid.has(Vector2i(x, y)) else ".")
			ground.append(g)
			objs.append(o)
		var bid := StringName("_p22_board_%d" % page)
		var text := "@id %s\n@title ZONE_FARM\n@projection iso\n@ambient farm\n@theme farm\n@zone farm\n@flight true\n%s@ground\n%s\n@objects\n%s\n" % [bid, props_txt, "\n".join(ground), "\n".join(objs)]
		WorldRoot2D.register_map(bid, AreaMap.parse_text(text))
		w._enter(bid, &"default")
		w.day_night.override_hour = 11.0
		w.day_night.snap()
		w.area.set_night_factor(0.0)
		cam.zoom = Vector2.ONE * 0.36
		p.visible = false
		p.global_position = w.area.cell_to_global(Vector2i(W / 2, H / 2))
		cam.reset_smoothing()
		await t.seconds(0.5)
		await t.capture("board_%d" % page)
		WorldRoot2D.unregister_map(bid)
		page += 1
	p.visible = true
	cam.zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
	w._enter(&"farm" if WorldRoot2D.has_area(&"farm") else &"_fixture_iso", &"default")
	await t.frames(1)
