extends RefCounted
## Section art_characters (package P21-art-characters, wave 3; carved out to V2-cast-art, which owns this file): the 42 characters baked by tools/art/characters (36, P21) and
## tools/art/cast_v2 (the six Figurer v2 NPCs of V2-cast-art) as they ship in res://assets
## (hobbits, squirrel, fairy skins, NPC fairies, named villagers, farm animals, forest creatures, boss) plus the 12 pack busts, against the
## art contract of plan 6.2 / addendum 3.5 and the roles of lua/config/npcs.lua + characters.lua.
##
## Headless (tests/run_playtest.sh --only=art_characters --no-boot), independent of the Python validator (tools/art/core/validate_new_assets.py checks
## the same things a second time on the WebP masters; this section checks what the GAME loads: the imported S3TC textures):
##   roster_is_42  lily_and_feature_fairies_are_baked  roles_and_clip_sets  players_have_all_clips  manifest_lists_the_roster
##   sheet_sizes_and_cells  sheets_are_vram_compressed  figures_on_the_pivot  pivot_check_has_teeth  clips_animate  boss_spin_all_sides
##   portraits_exist_and_are_busts  pack_busts  portrait_lookup_order  pack_busts_replace_the_full_body_crops  import_presets_and_s3tc
##   roster_resolves_without_fallback  roster_visuals_resolve  feature_fairies_do_not_use_the_shopkeeper_fallback  all_character_ids_resolve
##   figure_heights_match_pack  outline_colour_matches_pack  vram_budget_hyggebyen  readme_verdict_and_honest_notes
##   readme_points_at_the_review_sheets  docs_match_the_code  no_old_town_name
## (roster_visuals_resolve covers the npcs.lua visuals, the skins of characters.lua, the farm animals and the enemies; docs_match_the_code keeps this
## list and the docstring of tools/art/characters/measure_cast.py honest.)
## figures_on_the_pivot: every frame of every clip of the 42 new characters AND of the 12 pack characters (the contract by example) stands on the art
## contract pivot (128, 200): the 8 direction rows are rotations about the vertical axis through the pivot, so the mean of their bounding-box centres
## is x 127.5 and opposed rows mirror each other; the lowest pixel (the feet line) is inside the window of the body class.  The same numbers as
## tools/art/characters/measure_cast.py (pivot section of its docstring); pivot_check_has_teeth runs the checker on synthetic sheets.
## Windowed (tests/run_playtest.sh --windowed --only=art_characters, through tools/dev/run_windowed.sh): cast_pixels and cast_matches_pack (the whole cast on grass next to
## the pack at Camera zoom 0.4, 1280x720, with measured pixel heights, screenshots for the human) and vram_budget_measured (the render server's own
## texture memory with everything of Hyggebyen loaded).
## Needs the project imported (godot --headless --import, twice on a fresh clone): the sheets are S3TC textures.
const SECTION := "art_characters"
const TIMEOUT_S := 300.0

const Catalog := preload("res://scripts/isometric/character_catalog.gd")
const PerfWorld := preload("res://tests/perf_world.gd")
## P07's real portrait resolver (no class_name: preloaded by path like scripts/ui/dev/ui_smoke.gd does)
const Portraits := preload("res://scripts/ui/theme/tt_portraits.gd")

const DIR := "res://assets/isometric_characters/"
const PORTRAIT_DIR := "res://assets/portraits/"
const MANIFEST := "res://assets/isometric_characters/manifest_traetoppen.json"
const README := "res://tools/art/characters/README.md"
const CELL := 256
const SHEET_H := 2048
const PIVOT := [128, 200]
const DIRECTIONS := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
const PACK: Array[String] = ["bat", "cat", "bear", "rabbit", "fairy", "monkey", "capybara", "fox", "raccoon", "penguin", "hedgehog", "frog"]
## the figures the height gate compares with (plan 6.4 item 2: the sketch characters bear cat rabbit, plus fox and fairy; the bat's 2.8 m
## wingspan makes its body height meaningless for a height comparison, it is in the screenshot instead)
const PACK_REFERENCE: Array[String] = ["bear", "cat", "rabbit", "fox", "fairy"]
const HEIGHT_TOLERANCE := 0.10
const OUTLINE_TOLERANCE := 8
const SPRITE_ALPHA := 24
const VRAM_BUDGET_MB := 400.0
const REVIEW_DIR := "res://tools/art/characters/review/"
const REVIEW_MAX_BYTES := 700000

## The pivot contract (numbers measured on the pack and the 42 new characters, see tools/art/characters/measure_cast.py):
const PIVOT_X_CENTRE := 127.5               # pivot x 128 as the centre of a bounding box in pixel indices
const PIVOT_X_TOL := 3.0                    # |mean of the 8 row centres - 127.5|
const MIRROR_TOL := 5.0                     # |centre(row) + centre(opposed row) - 255|
const QUADRUPEDS: Array[String] = ["calf", "lamb", "puppy", "fawn", "capybara"]
const FLYERS: Array[String] = ["bat", "bat_natteblik"]
## 8-row mean of the lowest figure pixel by body class / every single row (pivot y 200)
const FEET_WINDOW := {"upright": [197, 216], "quadruped": [212, 228], "glow": [208, 222], "flyer": [197, 216]}
const ROW_FEET_LIMITS := {"upright": [188, 226], "quadruped": [206, 244], "glow": [204, 232], "flyer": [178, 226]}
## clips that lift the figure by design: only x is held to the pivot there
const AIRBORNE_CLIPS: Array[String] = ["jump", "fall", "land", "takeoff", "hover", "fly", "flight_land"]

## clip -> [frames, fps, loop] (artcontract.SPEC, FLIGHT, EXTRA)
const CLIP_SPEC := {
	"idle": [4, 5, true], "walk": [6, 9, true], "run": [6, 12, true], "jump": [4, 10, false], "fall": [3, 6, true], "land": [3, 11, false],
	"celebrate": [6, 9, false], "interact": [4, 9, false], "hit": [3, 11, false], "sleep": [4, 3, true], "talk": [4, 6, true],
	"takeoff": [4, 10, false], "hover": [5, 8, true], "fly": [6, 12, true], "flight_land": [4, 10, false],
	"attack": [5, 12, false], "spin": [8, 14, true],
}
## clip set -> clips (plan 6.2 "clip sets per role")
const SET_CLIPS := {
	"full": ["idle", "walk", "run", "jump", "fall", "land", "celebrate", "interact", "hit", "sleep", "talk"],
	"npc_flyer": ["idle", "hover", "talk", "celebrate", "interact"],
	"villager": ["idle", "walk", "talk", "celebrate", "interact", "sleep"],
	"farm_animal": ["idle", "walk", "run", "interact", "sleep", "hit", "celebrate"],
	"enemy": ["idle", "walk", "run", "attack", "hit"],
	"boss": ["idle", "walk", "attack", "hit", "spin"],
	"critter": ["idle", "walk", "run", "hit", "sleep"],
}
const FLIGHT_CLIPS := ["takeoff", "hover", "fly", "flight_land"]
const ROLE_OF_SET := {"full": "player", "npc_flyer": "npc", "villager": "npc", "farm_animal": "farm_animal", "enemy": "enemy", "boss": "boss", "critter": "critter"}
## the roster: clip set -> ids (task 1 of the P21 work order + addendum 4.4: 33 + fairy_builder, fairy_furnisher, fairy_tailor = 36; V2-cast-art: + bear_brumme hedgehog_pip owl_fru_ugle
## capybara_sofus (villager) and bat_natteblik fairy_birk_npc (npc_flyer) = 42)
const ROSTER := {
	"full": ["hobbit_pip", "hobbit_moss", "hobbit_bramble", "squirrel", "fairy_dusk", "fairy_stardust"],
	"npc_flyer": ["fairy_mayor", "fairy_baker", "fairy_shopkeeper", "fairy_king", "fairy_wizard", "fairy_lily", "fairy_builder", "fairy_furnisher", "fairy_tailor", "bat_natteblik", "fairy_birk_npc"],
	"villager": ["mouse_pippin", "cat_morfar_mis", "bear_guard", "rabbit_farmer", "raccoon_smith", "penguin_postman", "bear_brumme", "hedgehog_pip", "owl_fru_ugle", "capybara_sofus"],
	"farm_animal": ["chick", "hen", "duck", "kitten", "bunny", "fox_cub", "lamb", "calf", "owl", "puppy", "fawn"],
	"enemy": ["ugleoje", "tornebusk"],
	"boss": ["snurresvamp"],
	"critter": ["lysesvamp"],
}
## fairies with the four flight clips on top of the full set
const FLYING_PLAYERS := ["fairy_dusk", "fairy_stardust"]
## people-sized characters: the height gate applies; baby animals, small creatures and the boss are sized by design (reported, not gated)
const PEOPLE: Array[String] = ["hobbit_pip", "hobbit_moss", "hobbit_bramble", "squirrel", "fairy_dusk", "fairy_stardust", "fairy_mayor", "fairy_baker",
	"fairy_shopkeeper", "fairy_king", "fairy_wizard", "fairy_lily", "fairy_builder", "fairy_furnisher", "fairy_tailor", "mouse_pippin", "cat_morfar_mis",
	"bear_guard", "rabbit_farmer", "raccoon_smith", "penguin_postman", "bear_brumme", "hedgehog_pip", "owl_fru_ugle", "capybara_sofus", "bat_natteblik", "fairy_birk_npc"]
const GLOWING: Array[String] = ["lysesvamp"]
## npc visuals that are DECLARED stand-ins (lua/config/npcs.lua: `bodil = { visual = "hobbit_bodil", fallback = "hobbit_pip" }`, "Bodil draws as hobbit_pip until hobbit_bodil exists"):
## no package of milestone M1a bakes a folder `hobbit_bodil` (A2's hero base is `hobbit_bodil_base`), so the visual draws through its fallback.  The check accepts exactly this
## stand-in and nothing else, and says so in its info line; the day a folder hobbit_bodil exists the first branch of the check (resolve(visual) == visual) takes over.
const DRAWS_AS_STAND_IN := {"hobbit_bodil": "hobbit_pip"}
## the characters.lua stand-ins that must NOT draw a skin any more once the stock art exists (index 0 = wardrobe base, 1 = stock sheet)
const SKIN_CHAINS := {
	"animal_squirrel": ["squirrel_base", "squirrel", "monkey"], "fairy_stardust": ["fairy_stardust_base", "fairy_stardust", "fairy"],
	"fairy_dusk": ["fairy_dusk_base", "fairy_dusk", "fairy"], "hobbit_pip": ["hobbit_pip_base", "hobbit_pip", "raccoon"],
	"hobbit_moss": ["hobbit_moss_base", "hobbit_moss", "raccoon"], "hobbit_bramble": ["hobbit_bramble_base", "hobbit_bramble", "raccoon"],
	"animal_fox": ["fox_base", "fox"], "animal_rabbit": ["rabbit_base", "rabbit"], "animal_hedgehog": ["hedgehog_base", "hedgehog"],
	"fairy_meadow": ["fairy_base", "fairy"],
	"animal_monkey": ["monkey_base", "monkey"], "fairy_birk": ["fairy_birk_base", "fairy_birk", "fairy"], "hobbit_bodil": ["hobbit_bodil_base", "hobbit_bodil", "hobbit_pip", "raccoon"],
	"ghost_bu": ["ghost_bu_base", "ghost_bu", "rabbit"], "ghost_hviske": ["ghost_hviske_base", "ghost_hviske", "rabbit"],
}

var _t
var _meta: Dictionary = {}                # id -> parsed animations.json (Dictionary) or {}
var _bytes_s3tc: Dictionary = {}          # id -> imported S3TC bytes of every sheet (filled by the sheet scan)
var _sheet_count := 0


func _load_meta() -> Array[String]:
	var ids: Array[String] = _all_ids()
	for id in ids:
		_meta[id] = _json(DIR + id + "/animations.json")
	return ids


func run(t) -> void:
	_t = t
	var ids: Array[String] = _load_meta()
	_roster(t, ids)
	_roles_and_clips(t)
	_manifest(t)
	_scan_sheets(t)
	_pivot_checks(t)
	_clips_animate_check(t)
	_portraits(t)
	_import_presets(t)
	_resolve(t)
	_heights_and_outline(t)
	_vram_budget(t)
	_docs(t)


# ---------------------------------------------------------------- helpers

func _all_ids() -> Array[String]:
	var out: Array[String] = []
	for set_name in ROSTER.keys():
		for id in ROSTER[set_name]:
			out.append(str(id))
	return out


func _set_of(id: String) -> String:
	for set_name in ROSTER.keys():
		if id in ROSTER[set_name]:
			return str(set_name)
	return ""


func _expected_clips(id: String) -> Array[String]:
	var out: Array[String] = []
	for c in SET_CLIPS[_set_of(id)]:
		out.append(str(c))
	if id in FLYING_PLAYERS:
		for c in FLIGHT_CLIPS:
			out.append(str(c))
	return out


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


## (width, height) of a WebP file from its RIFF header (VP8X, VP8 and VP8L), without decoding it; (0, 0) for anything else.
func _webp_size(path: String) -> Vector2i:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return Vector2i.ZERO
	var b: PackedByteArray = f.get_buffer(32)
	f.close()
	if b.size() < 30 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WEBP":
		return Vector2i.ZERO
	var kind: String = b.slice(12, 16).get_string_from_ascii()
	if kind == "VP8X":
		return Vector2i((int(b[24]) | (int(b[25]) << 8) | (int(b[26]) << 16)) + 1, (int(b[27]) | (int(b[28]) << 8) | (int(b[29]) << 16)) + 1)
	if kind == "VP8 ":
		return Vector2i((int(b[26]) | (int(b[27]) << 8)) & 0x3fff, (int(b[28]) | (int(b[29]) << 8)) & 0x3fff)
	if kind == "VP8L" and b[20] == 0x2f:
		var bits: int = int(b[21]) | (int(b[22]) << 8) | (int(b[23]) << 16) | (int(b[24]) << 24)
		return Vector2i((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1)
	return Vector2i.ZERO


## Raw decode of a WebP (independent of the import state): RGBA8 or null.
func _decode(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var im := Image.new()
	if im.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) != OK or im.is_empty():
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


## JSON numbers arrive as floats: [256.0, 256.0] -> [256, 256]
func _ints(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(int(x))
	return out


func _mb(bytes: float) -> float:
	return bytes / 1048576.0


# ---------------------------------------------------------------- roster, roles, clip sets

func _roster(t, ids: Array[String]) -> void:
	var seen := {}
	var dup: Array[String] = []
	for id in ids:
		if seen.has(id):
			dup.append(id)
		seen[id] = true
	var counts: Array[String] = []
	for set_name in ROSTER.keys():
		counts.append("%s %d" % [set_name, (ROSTER[set_name] as Array).size()])
	var missing: Array[String] = []
	for id in ids:
		if (_meta[id] as Dictionary).is_empty():
			missing.append(id)
	t.check("roster_is_42", ids.size() == 42 and dup.is_empty() and missing.is_empty(),
		"%d ids (%s), duplicates %s, without animations.json %s" % [ids.size(), ", ".join(counts), str(dup), str(missing)])
	var feature: Array[String] = []
	for id in ["fairy_lily", "fairy_builder", "fairy_furnisher", "fairy_tailor"]:
		if not (_meta[id] as Dictionary).is_empty() and ResourceLoader.exists(DIR + id + "/idle.webp"):
			feature.append(id)
	t.check("lily_and_feature_fairies_are_baked", feature.size() == 4, "review R.9 (fairy_lily) + addendum 4.4 (builder, furnisher, tailor): %s" % str(feature))


func _roles_and_clips(t) -> void:
	var problems: Array[String] = []
	var checked := 0
	for id in _all_ids():
		var meta: Dictionary = _meta[id]
		if meta.is_empty():
			continue
		checked += 1
		var set_name := _set_of(id)
		if str(meta.get("role", "")) != str(ROLE_OF_SET[set_name]):
			problems.append("%s role %s want %s" % [id, str(meta.get("role", "")), str(ROLE_OF_SET[set_name])])
		if str(meta.get("clip_set", "")) != set_name:
			problems.append("%s clip_set %s want %s" % [id, str(meta.get("clip_set", "")), set_name])
		if str(meta.get("family", "")) == "":
			problems.append("%s has no family" % id)
		if bool(meta.get("flyer", false)) != (id.begins_with("fairy_") or id.begins_with("bat_")):   # a bat flies
			problems.append("%s flyer %s" % [id, str(meta.get("flyer", false))])
		if float(meta.get("display_scale", 0.0)) != 1.0:
			problems.append("%s display_scale %s (sprites are never scaled individually)" % [id, str(meta.get("display_scale", "?"))])
		if str(meta.get("portrait", "")) != "portrait.webp":
			problems.append("%s portrait %s" % [id, str(meta.get("portrait", ""))])
		if (id in GLOWING) != (meta.has("glow") and meta["glow"] is Dictionary):
			problems.append("%s glow field %s" % [id, str(meta.get("glow", "-"))])
		if _ints(meta.get("cell_size", [])) != [CELL, CELL] or _ints(meta.get("pivot", [])) != PIVOT or meta.get("directions", []) != DIRECTIONS:
			problems.append("%s cell/pivot/directions %s %s %s" % [id, str(meta.get("cell_size", "?")), str(meta.get("pivot", "?")), str(meta.get("directions", "?"))])
		var anims: Dictionary = meta.get("animations", {})
		var want := _expected_clips(id)
		var got: Array = anims.keys()
		got.sort()
		var want_sorted: Array = want.duplicate()
		want_sorted.sort()
		if got != want_sorted:
			problems.append("%s clips %s want %s" % [id, str(got), str(want_sorted)])
		for clip in want:
			if not anims.has(clip):
				continue
			var spec: Array = CLIP_SPEC[clip]
			var a: Dictionary = anims[clip]
			if int(a.get("frames", 0)) != int(spec[0]) or int(a.get("fps", 0)) != int(spec[1]) or bool(a.get("loop", not bool(spec[2]))) != bool(spec[2]) or str(a.get("sheet", "")) != clip + ".webp":
				problems.append("%s/%s frames/fps/loop/sheet %s want %s" % [id, clip, str(a), str(spec)])
	t.check("roles_and_clip_sets", problems.is_empty() and checked == 42, "%d folders: role, clip set, flyer, display_scale 1.0, portrait, glow only on lysesvamp, cell 256 pivot [128,200], every clip of the role's set with its frames/fps/loop; %s" % [checked, str(problems.slice(0, 6))])
	var players: Array[String] = []
	for id in ROSTER["full"]:
		players.append("%s %d" % [id, ((_meta[id] as Dictionary).get("animations", {}) as Dictionary).size()])
	t.check("players_have_all_clips", players.size() == 6 and ((_meta["fairy_dusk"] as Dictionary).get("animations", {}) as Dictionary).size() == 15 and ((_meta["hobbit_pip"] as Dictionary).get("animations", {}) as Dictionary).size() == 11, "player = all 11 clips (+ takeoff hover fly flight_land for the fairies): %s" % ", ".join(players))


func _manifest(t) -> void:
	var man: Dictionary = _json(MANIFEST)
	var chars: Dictionary = man.get("characters", {})
	var problems: Array[String] = []
	for id in _all_ids():
		if not chars.has(id):
			problems.append("%s not in manifest" % id)
			continue
		var row: Dictionary = chars[id]
		var meta: Dictionary = _meta[id]
		for k in ["role", "clip_set", "family", "flyer", "display_scale", "portrait"]:
			if row.get(k) != meta.get(k):
				problems.append("%s.%s manifest %s vs animations.json %s" % [id, k, str(row.get(k)), str(meta.get(k))])
		if (row.get("animations", {}) as Dictionary).keys().size() != ((meta.get("animations", {}) as Dictionary)).keys().size():
			problems.append("%s clip count differs" % id)
	t.check("manifest_lists_the_roster", problems.is_empty() and chars.size() >= 42 and int(man.get("format_version", 0)) == 2, "manifest_traetoppen.json: %d characters, %s" % [chars.size(), str(problems.slice(0, 4))])


# ---------------------------------------------------------------- the sheets: size, imported S3TC texture, cells

## Every sheet of the roster: (1) the WebP header says (256 x frames, 2048); (2) the imported texture is the same size and VRAM compressed (S3TC);
## (3) decompressed, every one of the 8 rows x frames cells is not blank and no cell is cut by its border (alpha <= tolerance on the cell edge);
## (4) the S3TC bytes are summed per character for the VRAM budget.  Cells are hashed so that clips_animate can see that frames differ.
func _scan_sheets(t) -> void:
	var t0 := Time.get_ticks_msec()
	var size_bad: Array[String] = []
	var cell_bad: Array[String] = []
	var format_bad: Array[String] = []
	var cells := 0
	var sheets := 0
	var total_bytes := 0.0
	_cell_hashes.clear()
	_pivot.clear()
	for id in _all_ids():
		var meta: Dictionary = _meta[id]
		var anims: Dictionary = meta.get("animations", {})
		var id_bytes := 0.0
		for clip in anims.keys():
			var frames := int((anims[clip] as Dictionary).get("frames", 0))
			var path: String = DIR + id + "/" + clip + ".webp"
			sheets += 1
			var hs := _webp_size(path)
			if hs != Vector2i(CELL * frames, SHEET_H):
				size_bad.append("%s/%s header %s want %s" % [id, clip, str(hs), str(Vector2i(CELL * frames, SHEET_H))])
				continue
			var tex := load(path) as Texture2D
			if tex == null:
				size_bad.append("%s/%s: not imported (no texture)" % [id, clip])
				continue
			if tex.get_width() != CELL * frames or tex.get_height() != SHEET_H:
				size_bad.append("%s/%s texture %dx%d" % [id, clip, tex.get_width(), tex.get_height()])
				continue
			var gpu: Image = tex.get_image()
			if gpu == null or gpu.is_empty():
				size_bad.append("%s/%s: no image data" % [id, clip])
				continue
			if not gpu.is_compressed() or not (gpu.get_format() in [Image.FORMAT_DXT1, Image.FORMAT_DXT3, Image.FORMAT_DXT5, Image.FORMAT_RGTC_RG]):
				format_bad.append("%s/%s format %d" % [id, clip, gpu.get_format()])
			id_bytes += float(gpu.get_data().size())
			gpu.decompress()
			if gpu.get_format() != Image.FORMAT_RGBA8:
				gpu.convert(Image.FORMAT_RGBA8)
			_pivot_measure(id, str(clip), gpu, frames)
			var hashes: Array[int] = []
			for row in 8:
				for f in frames:
					cells += 1
					var cell := gpu.get_region(Rect2i(f * CELL, row * CELL, CELL, CELL))
					if cell.is_invisible():
						cell_bad.append("%s/%s row %d frame %d blank" % [id, clip, row, f])
						hashes.append(0)
						continue
					var data: PackedByteArray = cell.get_data()
					hashes.append(hash(data))
					if _cut_by_border(data) and cell_bad.size() < 60:
						cell_bad.append("%s/%s row %d frame %d touches the cell border" % [id, clip, row, f])
			_cell_hashes["%s/%s" % [id, clip]] = hashes
		_bytes_s3tc[id] = id_bytes
		total_bytes += id_bytes
	_sheet_count = sheets
	t.check("sheet_sizes_and_cells", size_bad.is_empty() and cell_bad.is_empty() and sheets >= 250,
		"%d sheets of 42 characters: WebP header = import size = 256 x frames by 2048 and the S3TC texture decodes; %d cells (8 directions x frames), none blank, none cut by its border; %s %s" % [sheets, cells, str(size_bad.slice(0, 4)), str(cell_bad.slice(0, 4))])
	t.check("sheets_are_vram_compressed", format_bad.is_empty() and sheets > 0, "every imported sheet is S3TC (%.0f MB resident with mipmaps for all %d sheets, scan took %.1f s) %s" % [_mb(total_bytes), sheets, float(Time.get_ticks_msec() - t0) / 1000.0, str(format_bad.slice(0, 3))])


# ---------------------------------------------------------------- the pivot contract (128, 200): where in its cell does the figure stand?

## id -> {"problems": Array[String], "sheets": int, "frames": int, "x_min", "x_max", "y_min", "y_max"} filled by the sheet scan (new cast) and _pack_pivot (pack)
var _pivot: Dictionary = {}


func _body_class(id: String) -> String:
	if id in QUADRUPEDS:
		return "quadruped"
	if id in GLOWING:
		return "glow"
	return "flyer" if id in FLYERS else "upright"


## Bounding box of the pixels with alpha > SPRITE_ALPHA of a 256 x 256 RGBA8 cell: the engine's own used-rect (alpha > 0) first, then trimmed by the
## faint pixels (alpha 1..24: anti-aliased outline edge, halo of the glowing creature) on its four sides.  Rect2i() for an empty cell.
func _alpha_bbox(cell: Image) -> Rect2i:
	var r: Rect2i = cell.get_used_rect()
	if r.size == Vector2i.ZERO:
		return Rect2i()
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x - 1
	var y1 := r.end.y - 1
	while y0 <= y1 and not _line_opaque(cell, y0, x0, x1, true):
		y0 += 1
	while y1 >= y0 and not _line_opaque(cell, y1, x0, x1, true):
		y1 -= 1
	if y0 > y1:
		return Rect2i()
	while x0 <= x1 and not _line_opaque(cell, x0, y0, y1, false):
		x0 += 1
	while x1 >= x0 and not _line_opaque(cell, x1, y0, y1, false):
		x1 -= 1
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## True when a row (horizontal = true: y fixed, x in from..to) or a column has a pixel with alpha > SPRITE_ALPHA.
func _line_opaque(cell: Image, fixed: int, from: int, to: int, horizontal: bool) -> bool:
	for i in range(from, to + 1):
		var c: Color = cell.get_pixel(i, fixed) if horizontal else cell.get_pixel(fixed, i)
		if int(round(c.a * 255.0)) > SPRITE_ALPHA:
			return true
	return false


## The 8 bounding boxes (direction rows S..SE, contract order) of frame `frame` of a sheet image.
func _row_boxes(sheet: Image, frame: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for row in 8:
		out.append(_alpha_bbox(sheet.get_region(Rect2i(frame * CELL, row * CELL, CELL, CELL))))
	return out


## Problems of one frame (8 row boxes) against the pivot contract; [] when the figure stands where the contract puts it.
func _pivot_problems(boxes: Array[Rect2i], cls: String, check_y: bool) -> Array[String]:
	var out: Array[String] = []
	for b in boxes:
		if b.size == Vector2i.ZERO:
			out.append("blank row")
			return out
	var cx: Array[float] = []
	var mean_cx := 0.0
	var mean_bottom := 0.0
	for b in boxes:
		var c: float = (float(b.position.x) + float(b.end.x - 1)) / 2.0
		cx.append(c)
		mean_cx += c / 8.0
		mean_bottom += float(b.end.y - 1) / 8.0
	if absf(mean_cx - PIVOT_X_CENTRE) > PIVOT_X_TOL:
		out.append("figure is %+.1f px off the pivot x (8-row mean of the bbox centres %.1f, want %.1f +/- %d)" % [mean_cx - PIVOT_X_CENTRE, mean_cx, PIVOT_X_CENTRE, int(PIVOT_X_TOL)])
	for r in 4:
		var dev: float = cx[r] + cx[r + 4] - 2.0 * PIVOT_X_CENTRE
		if absf(dev) > MIRROR_TOL:
			out.append("rows %s/%s not mirrored about the pivot (centres %.1f + %.1f, off by %+.1f px)" % [DIRECTIONS[r], DIRECTIONS[r + 4], cx[r], cx[r + 4], dev])
	if check_y:
		var win: Array = FEET_WINDOW[cls]
		if mean_bottom < float(win[0]) or mean_bottom > float(win[1]):
			out.append("feet line %.1f outside %d..%d (%s, pivot y %d)" % [mean_bottom, int(win[0]), int(win[1]), cls, PIVOT[1]])
		var lim: Array = ROW_FEET_LIMITS[cls]
		var bad: Array[String] = []
		for i in 8:
			var bottom: int = boxes[i].end.y - 1
			if bottom < int(lim[0]) or bottom > int(lim[1]):
				bad.append("%s:%d" % [DIRECTIONS[i], bottom])
		if not bad.is_empty():
			out.append("lowest pixel of row(s) %s outside %d..%d" % [" ".join(bad), int(lim[0]), int(lim[1])])
	return out


## One decompressed RGBA8 sheet of `id`: every frame against the pivot contract, results summed up in _pivot[id].
func _pivot_measure(id: String, clip: String, sheet: Image, frames: int) -> void:
	var rec: Dictionary = _pivot.get(id, {"problems": [], "sheets": 0, "frames": 0, "x_min": 1.0e9, "x_max": -1.0e9, "y_min": 1.0e9, "y_max": -1.0e9})
	var cls := _body_class(id)
	var grounded := not (clip in AIRBORNE_CLIPS)
	rec["sheets"] = int(rec["sheets"]) + 1
	for f in frames:
		var boxes: Array[Rect2i] = _row_boxes(sheet, f)
		rec["frames"] = int(rec["frames"]) + 1
		var probs: Array[String] = _pivot_problems(boxes, cls, grounded)
		var all_there := true
		var mx := 0.0
		var my := 0.0
		for b in boxes:
			if b.size == Vector2i.ZERO:
				all_there = false
				break
			mx += (float(b.position.x) + float(b.end.x - 1)) / 16.0
			my += float(b.end.y - 1) / 8.0
		if all_there:
			rec["x_min"] = minf(float(rec["x_min"]), mx)
			rec["x_max"] = maxf(float(rec["x_max"]), mx)
			if grounded:
				rec["y_min"] = minf(float(rec["y_min"]), my)
				rec["y_max"] = maxf(float(rec["y_max"]), my)
		for pr in probs:
			if (rec["problems"] as Array).size() < 6:
				(rec["problems"] as Array).append("%s f%d: %s" % [clip, f, pr])
	_pivot[id] = rec


## The 12 pack characters through the very same measurement (their imported S3TC sheets): the contract by example.
func _pack_pivot() -> void:
	for id in PACK:
		var meta: Dictionary = _json(DIR + id + "/animations.json")
		for clip in (meta.get("animations", {}) as Dictionary).keys():
			var tex := load(DIR + id + "/" + str(clip) + ".webp") as Texture2D
			if tex == null:
				continue
			var img: Image = tex.get_image()
			if img == null or img.is_empty():
				continue
			if img.is_compressed():
				img.decompress()
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			_pivot_measure(id, str(clip), img, int((meta["animations"][clip] as Dictionary).get("frames", 0)))


func _pivot_checks(t) -> void:
	_pack_pivot()
	var bad: Array[String] = []
	var pack_bad: Array[String] = []
	var sheets := 0
	var frames := 0
	var x_min := 1.0e9
	var x_max := -1.0e9
	for id in _pivot.keys():
		var rec: Dictionary = _pivot[id]
		sheets += int(rec["sheets"])
		frames += int(rec["frames"])
		x_min = minf(x_min, float(rec["x_min"]))
		x_max = maxf(x_max, float(rec["x_max"]))
		if not (rec["problems"] as Array).is_empty():
			var line := "%s %s" % [id, str((rec["problems"] as Array)[0])]
			if id in PACK:
				pack_bad.append(line)
			else:
				bad.append(line)
	var y_info: Array[String] = []
	for id in ["hobbit_pip", "calf", "fairy_lily", "lysesvamp", "bear"]:
		if _pivot.has(id):
			y_info.append("%s %.0f..%.0f" % [id, float((_pivot[id] as Dictionary)["y_min"]), float((_pivot[id] as Dictionary)["y_max"])])
	t.check("figures_on_the_pivot", bad.is_empty() and pack_bad.is_empty() and _pivot.size() == 54 and frames > 1500,
		"%d frames of %d sheets of the 42 new characters + the 12 pack characters stand on the contract pivot (128, 200): the 8-row mean of the bbox centres is x %.1f..%.1f (want %.1f +/- %d), opposed rows mirror each other (+/-%d), the feet line (8-row mean of the lowest pixel, grounded clips) is inside its body-class window (%s); new cast %s, pack %s" % [frames, sheets, x_min, x_max, PIVOT_X_CENTRE, int(PIVOT_X_TOL), int(MIRROR_TOL), ", ".join(y_info), str(bad.slice(0, 3)), str(pack_bad.slice(0, 3))])
	_pivot_has_teeth(t)


## The checker itself must have teeth: synthetic sheets (a block standing on the pivot) pass, every kind of misplacement is reported.
func _synthetic_sheet(dx: int, dy: int, row_dx: Dictionary, quadruped: bool) -> Image:
	var im := Image.create(CELL, CELL * 8, false, Image.FORMAT_RGBA8)
	var foot := 205 + (14 if quadruped else 0)
	for row in 8:
		var lean := int(round(12.0 * sin(deg_to_rad(45.0 * row))))
		var cx := 128 + lean + dx + int(row_dx.get(row, 0))
		im.fill_rect(Rect2i(cx - 30, row * CELL + foot + dy - 110, 60, 110), Color(1, 1, 1, 1))
	return im


func _pivot_has_teeth(t) -> void:
	var cases := [
		["on the pivot", _synthetic_sheet(0, 0, {}, false), "upright", false],
		["quadruped on the pivot", _synthetic_sheet(0, 0, {}, true), "quadruped", false],
		["2 px sideways (tolerated)", _synthetic_sheet(2, 0, {}, false), "upright", false],
		["8 px sideways", _synthetic_sheet(8, 0, {}, false), "upright", true],
		["-10 px sideways", _synthetic_sheet(-10, 0, {}, false), "upright", true],
		["ONE row 12 px sideways", _synthetic_sheet(0, 0, {2: 12}, false), "upright", true],
		["20 px too low", _synthetic_sheet(0, 20, {}, false), "upright", true],
		["20 px too high", _synthetic_sheet(0, -20, {}, false), "upright", true],
		["a quadruped sheet judged as upright", _synthetic_sheet(0, 0, {}, true), "upright", true],
	]
	var wrong: Array[String] = []
	for c in cases:
		var probs: Array[String] = _pivot_problems(_row_boxes(c[1] as Image, 0), str(c[2]), true)
		if (not probs.is_empty()) != bool(c[3]):
			wrong.append("%s: %s" % [c[0], str(probs) if not probs.is_empty() else "accepted"])
	t.check("pivot_check_has_teeth", wrong.is_empty(), "synthetic sheets: a block on the pivot passes (also 2 px off), 8 px / -10 px sideways, one row 12 px sideways, 20 px too low / too high and a quadruped judged as upright are reported %s" % str(wrong))


var _cell_hashes: Dictionary = {}


## True when any pixel on the 1 px frame of a 256 x 256 RGBA8 cell has alpha above the tolerance (the figure would be cut by its cell).
## The tolerance is the validator's 24 plus the little the S3TC alpha blocks add.
func _cut_by_border(data: PackedByteArray) -> bool:
	var limit := SPRITE_ALPHA + 16
	for i in CELL:
		if int(data[i * 4 + 3]) > limit or int(data[((CELL - 1) * CELL + i) * 4 + 3]) > limit:
			return true
		if int(data[(i * CELL) * 4 + 3]) > limit or int(data[(i * CELL + CELL - 1) * 4 + 3]) > limit:
			return true
	return false


## "The animation check" of the work order as a number: every moving clip (all but a single still pose) must change from frame to frame in
## EVERY direction row (not all frames of a row identical) and the boss spin must change on every frame in every row.
func _clips_animate_check(t) -> void:
	var still: Array[String] = []
	var spin_bad: Array[String] = []
	var tested := 0
	for key in _cell_hashes.keys():
		var parts: PackedStringArray = str(key).split("/")
		var id := parts[0]
		var clip := parts[1]
		var frames := int(((_meta[id] as Dictionary).get("animations", {}) as Dictionary)[clip]["frames"])
		var hashes: Array = _cell_hashes[key]
		if hashes.size() != 8 * frames:
			continue
		for row in 8:
			tested += 1
			var distinct := {}
			for f in frames:
				distinct[hashes[row * frames + f]] = true
			if distinct.size() < 2:
				still.append("%s/%s row %d" % [id, clip, row])
			if clip == "spin" and distinct.size() != frames:
				spin_bad.append("%s/%s row %d: %d distinct of %d" % [id, clip, row, distinct.size(), frames])
	t.check("clips_animate", still.is_empty() and tested > 1000, "%d rows of clips: every row of every clip changes between frames (%s)" % [tested, str(still.slice(0, 4))])
	t.check("boss_spin_all_sides", spin_bad.is_empty() and _cell_hashes.has("snurresvamp/spin"), "snurresvamp spin: 8 directions x 8 distinct frames %s" % str(spin_bad.slice(0, 3)))


# ---------------------------------------------------------------- portraits

## head-and-shoulders bust rules of the validator: 256 x 256, not blank, not cut at the top or at the sides (alpha <= 24; the bottom is cut at the torso by design)
func _bust_problems(path: String) -> Array[String]:
	var out: Array[String] = []
	var im := _decode(path)
	if im == null:
		out.append("%s: unreadable" % path.get_file())
		return out
	if im.get_size() != Vector2i(CELL, CELL):
		out.append("%s is %s" % [path.get_file(), str(im.get_size())])
		return out
	if im.is_invisible():
		out.append("%s blank" % path.get_file())
		return out
	var data: PackedByteArray = im.get_data()
	for i in CELL:
		if int(data[i * 4 + 3]) > SPRITE_ALPHA:
			out.append("%s cut at the top" % path.get_file())
			break
	for j in CELL:
		if int(data[(j * CELL) * 4 + 3]) > SPRITE_ALPHA or int(data[(j * CELL + CELL - 1) * 4 + 3]) > SPRITE_ALPHA:
			out.append("%s cut at a side" % path.get_file())
			break
	return out


func _portraits(t) -> void:
	var bad: Array[String] = []
	for id in _all_ids():
		bad.append_array(_bust_problems(DIR + id + "/portrait.webp"))
	t.check("portraits_exist_and_are_busts", bad.is_empty(), "42 portrait.webp: 256 x 256 head-and-shoulders busts from the 14 degree camera, none blank or cut at the top/sides %s" % str(bad.slice(0, 4)))
	var pack_bad: Array[String] = []
	for id in PACK:
		pack_bad.append_array(_bust_problems(PORTRAIT_DIR + id + ".webp"))
	t.check("pack_busts", pack_bad.is_empty(), "the 12 pack characters have a bust in assets/portraits/<id>.webp (same framing as the new cast) %s" % str(pack_bad.slice(0, 4)))
	_portrait_resolver(t)
	var same := 0
	for id in PACK:
		var a := _decode(PORTRAIT_DIR + id + ".webp")
		var b := _decode(DIR + id + "/portrait.webp")
		if a != null and b != null and a.get_data() == b.get_data():
			same += 1
	t.check("pack_busts_replace_the_full_body_crops", same == 0, "none of the 12 new busts is the pack's old full-body portrait.webp (%d identical)" % same)


## portrait_lookup_order: the REAL resolver of P07 (scripts/ui/theme/tt_portraits.gd), not a copy of its rule in this file.  Against the real files:
##  - portrait_paths(id) is [assets/portraits/<id>.webp, <id>/portrait.webp] (the lookup order);
##  - resolve_visual_path([id]) is the bust for the 12 pack ids and the character folder's own portrait for the 42 new ids;
##  - the `exists` seam: when BOTH files exist the bust wins (a new id gets its own bust file later without a code change);
##  - resolve_path(npc) of every npc of npcs.lua ends at the NPC's own visual (no stand-in), and the texture loads as 256 x 256.
func _portrait_resolver(t) -> void:
	var bad: Array[String] = []
	for id in PACK:
		var paths: Array[String] = Portraits.portrait_paths(id)
		if paths.size() != 2 or paths[0] != PORTRAIT_DIR + id + ".webp" or paths[1] != DIR + id + "/portrait.webp":
			bad.append("portrait_paths(%s) = %s" % [id, str(paths)])
		if Portraits.resolve_visual_path([id]) != PORTRAIT_DIR + id + ".webp":
			bad.append("pack %s resolves to %s" % [id, Portraits.resolve_visual_path([id])])
	for id in _all_ids():
		if Portraits.resolve_visual_path([id]) != DIR + id + "/portrait.webp":
			bad.append("new %s resolves to %s" % [id, Portraits.resolve_visual_path([id])])
		var tex := Portraits.portrait_by_sprite(id)
		if tex == null or tex.get_width() != CELL or tex.get_height() != CELL:
			bad.append("portrait_by_sprite(%s) is %s" % [id, str(tex)])
	for id in PACK:
		var ptex := Portraits.portrait_by_sprite(id)
		if ptex == null or ptex.get_width() != CELL or ptex.get_height() != CELL:
			bad.append("portrait_by_sprite(%s) is %s" % [id, str(ptex)])
	# the seam: both files "exist" -> the bust wins; only the folder portrait exists -> that one
	var both := {PORTRAIT_DIR + "fairy_mayor.webp": true, DIR + "fairy_mayor/portrait.webp": true}
	if Portraits.resolve_visual_path(["fairy_mayor"], func(path: String) -> bool: return both.has(path)) != PORTRAIT_DIR + "fairy_mayor.webp":
		bad.append("with both files present the bust does not win")
	var folder_only := {DIR + "fairy_mayor/portrait.webp": true}
	if Portraits.resolve_visual_path(["fairy_mayor"], func(path: String) -> bool: return folder_only.has(path)) != DIR + "fairy_mayor/portrait.webp":
		bad.append("with only the folder portrait present it is not used")
	# every NPC of npcs.lua: its portrait is its own visual's, never a stand-in of the fallback chain
	var lua: Node = t.root.get_node_or_null("LuaRuntime")
	var npcs: Dictionary = lua.call("get_npcs") if lua != null and lua.has_method("get_npcs") else {}
	var npc_n := 0
	for npc_id in npcs.keys():
		var row: Dictionary = npcs[npc_id] if npcs[npc_id] is Dictionary else {}
		var own := str(row.get("portrait", "")) if str(row.get("portrait", "")) != "" else str(row.get("visual", ""))
		if DRAWS_AS_STAND_IN.has(own) and Catalog.resolve(own) == DRAWS_AS_STAND_IN[own]:
			own = str(DRAWS_AS_STAND_IN[own])          # a declared stand-in: its portrait is the stand-in's
		var want: String = Portraits.resolve_visual_path([own])
		var got: String = Portraits.resolve_path(StringName(str(npc_id)))
		npc_n += 1
		if want == "" or got != want:
			bad.append("npc %s (visual %s): resolve_path %s, own portrait %s" % [npc_id, own, got, want])
	if npcs.is_empty():
		t.skip("portrait_lookup_order: lua/config/npcs.lua is not loaded (the per-NPC part of the check)")
	t.check("portrait_lookup_order", bad.is_empty() and (npc_n >= 15 or npcs.is_empty()),
		"TTPortraits (P07's resolver): portrait_paths = [assets/portraits/<id>.webp, <id>/portrait.webp]; the bust wins for the 12 pack ids, the folder portrait serves the 42 new ids, both-present -> bust, %d NPCs of npcs.lua resolve to their own visual's portrait, 54 portraits load as 256 x 256 %s" % [npc_n, str(bad.slice(0, 4))])


# ---------------------------------------------------------------- import presets

func _import_presets(t) -> void:
	var bad: Array[String] = []
	var n := 0
	for id in _all_ids():
		var meta: Dictionary = _meta[id]
		for clip in (meta.get("animations", {}) as Dictionary).keys():
			n += 1
			var imp: String = DIR + id + "/" + str(clip) + ".webp.import"
			if not FileAccess.file_exists(imp):
				bad.append("%s/%s: no .import" % [id, clip])
				continue
			var text := FileAccess.get_file_as_string(imp)
			if not ("compress/mode=2" in text and "compress/high_quality=false" in text and "mipmaps/generate=true" in text):
				bad.append("%s/%s: preset is not S3TC + mipmaps" % [id, clip])
		var pimp := DIR + id + "/portrait.webp.import"
		if FileAccess.file_exists(pimp) and "compress/mode=2" in FileAccess.get_file_as_string(pimp):
			bad.append("%s portrait is VRAM compressed (portraits are lossless)" % id)
	for id in PACK:
		var bimp := PORTRAIT_DIR + id + ".webp.import"
		if FileAccess.file_exists(bimp) and "compress/mode=2" in FileAccess.get_file_as_string(bimp):
			bad.append("bust %s is VRAM compressed" % id)
	t.check("import_presets_and_s3tc", bad.is_empty() and n >= 250, "%d sheet .import files carry compress/mode=2, high_quality=false, mipmaps (S3TC); portraits and busts stay lossless %s" % [n, str(bad.slice(0, 4))])


# ---------------------------------------------------------------- the data resolves to real art (no fallback)

func _resolve(t) -> void:
	# every id of the roster is its own art
	var via_fallback: Array[String] = []
	for id in _all_ids():
		if Catalog.resolve(id) != id:
			via_fallback.append("%s -> %s" % [id, Catalog.resolve(id)])
	t.check("roster_resolves_without_fallback", via_fallback.is_empty(), "CharacterCatalog.resolve(id) == id for all 42 (no stand-in) %s" % str(via_fallback))
	# every npc.visual of lua/config/npcs.lua
	var lua: Node = t.root.get_node_or_null("LuaRuntime")
	var npcs: Dictionary = lua.call("get_npcs") if lua != null and lua.has_method("get_npcs") else {}
	var bad: Array[String] = []
	var visuals: Array[String] = []
	var stand_ins: Array[String] = []
	if npcs.is_empty():
		t.skip("roster_visuals_resolve: lua/config/npcs.lua is not loaded (no LuaRuntime or no npcs table)")
	else:
		for npc_id in npcs.keys():
			var row: Dictionary = npcs[npc_id] if npcs[npc_id] is Dictionary else {}
			var visual := str(row.get("visual", ""))
			visuals.append(visual)
			if visual == "" or Catalog.resolve(visual) != visual:
				if DRAWS_AS_STAND_IN.has(visual) and Catalog.resolve(visual) == DRAWS_AS_STAND_IN[visual]:
					stand_ins.append("%s (%s) draws as %s" % [npc_id, visual, Catalog.resolve(visual)])
				else:
					bad.append("%s: %s resolves to %s" % [npc_id, visual, Catalog.resolve(visual)])
	# every skin of characters.lua: the first TWO entries of its chain (the wardrobe base of A2 or the stock sheet), never the pack stand-in at the end
	var skin_bad: Array[String] = []
	var skin_report: Array[String] = []
	for skin_id in Catalog.skin_ids():
		var chain: Array[String] = Catalog.skin_chain(skin_id)
		var resolved: String = Catalog.resolved_visual_for_skin(skin_id)
		skin_report.append("%s -> %s" % [skin_id, resolved])
		var want: Array = SKIN_CHAINS.get(skin_id, [])
		if want.is_empty() or chain != want:
			skin_bad.append("%s chain %s" % [skin_id, str(chain)])
			continue
		var idx := chain.find(resolved)
		var stock_idx := 1
		if idx < 0 or idx > stock_idx:
			skin_bad.append("%s resolves to %s (index %d): a stand-in, not real art" % [skin_id, resolved, idx])
	# farm animals and enemies of characters.lua
	var other_bad: Array[String] = []
	for species in ["chicken", "rabbit", "duck", "cat", "dog", "sheep", "cow", "deer", "fox", "owl"]:
		for stage in ["baby", "adult"]:
			var v: String = str(Catalog.animal_look(species, stage).get("visual", ""))
			if v == "" or Catalog.resolve(v) != v:
				other_bad.append("animal %s/%s: %s -> %s" % [species, stage, v, Catalog.resolve(v)])
	for kind in ["bat", "ugleoje", "tornebusk", "lysesvamp", "snurresvamp"]:
		var ev := Catalog.enemy_visual(kind)
		if ev == "" or Catalog.resolve(ev) != ev:
			other_bad.append("enemy %s: %s -> %s" % [kind, ev, Catalog.resolve(ev)])
	if not stand_ins.is_empty():
		t.info("roster_visuals_resolve: declared stand-in(s) (npcs.lua fallback, no folder of their own in milestone M1a): %s" % "; ".join(stand_ins))
	t.check("roster_visuals_resolve", bad.is_empty() and skin_bad.is_empty() and other_bad.is_empty() and (not npcs.is_empty()) and visuals.size() >= 15,
		"%d npc.visual of npcs.lua incl. fairy_builder/furnisher/tailor, %d skins (%s), 10 farm animal species x 2 stages and 5 enemy kinds all resolve to REAL art, no fallback; %s %s %s" % [visuals.size(), skin_report.size(), "; ".join(skin_report.slice(0, 4)) + " ...", str(bad.slice(0, 3)), str(skin_bad.slice(0, 3)), str(other_bad.slice(0, 3))])
	# the three feature NPCs must draw themselves, not fairy_shopkeeper (until baked characters.lua points them there)
	var own := true
	for id in ["fairy_builder", "fairy_furnisher", "fairy_tailor"]:
		own = own and Catalog.resolve(id) == id and Catalog.resolve(id) != "fairy_shopkeeper"
	t.check("feature_fairies_do_not_use_the_shopkeeper_fallback", own, "fairy_builder, fairy_furnisher, fairy_tailor resolve to their own art")
	# every id the data mentions still resolves (the pack ids, the wardrobe bases through their stock sheet)
	var unresolved: Array[String] = []
	for id in Catalog.all_ids():
		if Catalog.resolve(id) == "":
			unresolved.append(id)
	t.check("all_character_ids_resolve", unresolved.is_empty(), "%d ids of characters.lua: unresolved %s" % [Catalog.all_ids().size(), str(unresolved)])


# ---------------------------------------------------------------- figure height and outline colour against the pack (gate 2)

## bbox height (alpha > 24) of the idle SE frame 0 and the mean outline colour of the isolated outline pixels (alpha 130..150 next to a clear pixel)
func _figure(id: String) -> Dictionary:
	var im := _decode(DIR + id + "/idle.webp")
	if im == null:
		return {}
	var cell := im.get_region(Rect2i(0, 7 * CELL, CELL, CELL))
	var data: PackedByteArray = cell.get_data()
	var top := CELL
	var bottom := -1
	for y in CELL:
		var any := false
		for x in CELL:
			if int(data[(y * CELL + x) * 4 + 3]) > SPRITE_ALPHA:
				any = true
				break
		if any:
			top = mini(top, y)
			bottom = maxi(bottom, y)
	var rgb := Vector3.ZERO
	var n := 0
	for y in range(maxi(top, 1), mini(bottom + 1, CELL - 1)):
		for x in range(1, CELL - 1):
			var a: int = int(data[(y * CELL + x) * 4 + 3])
			if a < 130 or a > 150:
				continue
			var clear_next := int(data[(y * CELL + x - 1) * 4 + 3]) == 0 or int(data[(y * CELL + x + 1) * 4 + 3]) == 0 or int(data[((y - 1) * CELL + x) * 4 + 3]) == 0 or int(data[((y + 1) * CELL + x) * 4 + 3]) == 0
			if clear_next:
				var o := (y * CELL + x) * 4
				rgb += Vector3(float(data[o]), float(data[o + 1]), float(data[o + 2]))
				n += 1
	return {"height": bottom - top + 1, "outline": (rgb / float(n)) if n >= 30 else Vector3(-1, -1, -1), "outline_px": n}


func _heights_and_outline(t) -> void:
	var ref_heights: Array[float] = []
	var ref_outline := Vector3.ZERO
	var ref_n := 0
	for id in PACK_REFERENCE:
		var f := _figure(id)
		if f.is_empty():
			continue
		ref_heights.append(float(f["height"]))
		if (f["outline"] as Vector3).x >= 0.0:
			ref_outline += f["outline"]
			ref_n += 1
	var mean := 0.0
	for h in ref_heights:
		mean += h
	mean /= maxf(float(ref_heights.size()), 1.0)
	ref_outline /= maxf(float(ref_n), 1.0)
	var bad: Array[String] = []
	var outline_bad: Array[String] = []
	var report: Array[String] = []
	for id in _all_ids():
		var f := _figure(id)
		if f.is_empty():
			bad.append("%s: no idle sheet" % id)
			continue
		var ratio: float = float(f["height"]) / mean
		if id in PEOPLE:
			report.append("%s %d%%" % [id, int(round(ratio * 100.0))])
			if absf(ratio - 1.0) > HEIGHT_TOLERANCE:
				bad.append("%s %d px = %d%% of the pack mean %.0f px" % [id, int(f["height"]), int(round(ratio * 100.0)), mean])
		if not (id in GLOWING):
			var oc: Vector3 = f["outline"]
			if oc.x < 0.0 or absf(oc.x - ref_outline.x) > OUTLINE_TOLERANCE or absf(oc.y - ref_outline.y) > OUTLINE_TOLERANCE or absf(oc.z - ref_outline.z) > OUTLINE_TOLERANCE:
				outline_bad.append("%s outline %s vs pack %s" % [id, str(oc.round()), str(ref_outline.round())])
	t.check("figure_heights_match_pack", bad.is_empty() and ref_heights.size() == PACK_REFERENCE.size(),
		"27 people-sized figures within +/-%d%% of the pack mean %.0f px (bear cat rabbit fox fairy, idle SE): %s %s" % [int(HEIGHT_TOLERANCE * 100.0), mean, ", ".join(report), str(bad)])
	t.check("outline_colour_matches_pack", outline_bad.is_empty() and ref_n == PACK_REFERENCE.size(),
		"world outline (75,60,73) at alpha .55 on every character except the glowing lysesvamp: pack mean %s, deviations > %d: %s" % [str(ref_outline.round()), OUTLINE_TOLERANCE, str(outline_bad.slice(0, 4))])


# ---------------------------------------------------------------- VRAM budget (S3TC) of Hyggebyen

## animations.json of any character id (roster ids are loaded up front; pack visuals and stand-ins on demand)
func _meta_of(id: String) -> Dictionary:
	if not _meta.has(id):
		_meta[id] = _json(DIR + id + "/animations.json")
	return _meta[id]


## imported S3TC bytes of every sheet of an id (the sheet scan filled the roster ids; any other visual is measured on demand)
func _bytes_of(id: String) -> float:
	if not _bytes_s3tc.has(id):
		var b := 0.0
		for clip in (_meta_of(id).get("animations", {}) as Dictionary).keys():
			var tex := load(DIR + id + "/" + str(clip) + ".webp") as Texture2D
			if tex != null:
				b += float(tex.get_image().get_data().size())
		_bytes_s3tc[id] = b
	return float(_bytes_s3tc[id])


## npcs of lua/config/npcs.lua whose home_area is hyggebyen (a declared stand-in visual is counted as the sprite it draws)
func _hyggebyen_visuals(t) -> Array[String]:
	var out: Array[String] = []
	var lua: Node = t.root.get_node_or_null("LuaRuntime")
	var npcs: Dictionary = lua.call("get_npcs") if lua != null and lua.has_method("get_npcs") else {}
	for npc_id in npcs.keys():
		var row: Dictionary = npcs[npc_id] if npcs[npc_id] is Dictionary else {}
		var v := str(row.get("visual", ""))
		if DRAWS_AS_STAND_IN.has(v):
			v = str(DRAWS_AS_STAND_IN[v])
		if str(row.get("home_area", "")) == "hyggebyen" and v != "" and not out.has(v):
			out.append(v)
	return out


func _vram_budget(t) -> void:
	var town := _hyggebyen_visuals(t)
	if town.is_empty():
		t.skip("vram_budget_hyggebyen: no NPC with home_area hyggebyen in lua/config/npcs.lua (LuaRuntime not loaded)")
		return
	# worst case: EVERY baked clip of every Hyggebyen NPC resident at once + the biggest player (a fairy with all 15 clips)
	var town_bytes := 0.0
	var parts: Array[String] = []
	for id in town:
		var b: float = _bytes_of(id)
		town_bytes += b
		parts.append("%s %.0f" % [id, _mb(b)])
	var best_player := ""
	var best_bytes := 0.0
	for id in ROSTER["full"]:
		var b2: float = float(_bytes_s3tc.get(id, 0.0))
		if b2 > best_bytes:
			best_bytes = b2
			best_player = id
	var total := town_bytes + best_bytes
	# the plan's residency rule (6.2): idle + walk/hover + talk of the NPCs, the player's 10 clips: far less
	var resident := 0.0
	for id in town:
		var anims: Dictionary = _meta_of(id).get("animations", {})
		var frames_total := 0
		var frames_resident := 0
		for clip in anims.keys():
			var fr := int((anims[clip] as Dictionary).get("frames", 0))
			frames_total += fr
			if clip in ["idle", "walk", "hover", "talk"]:
				frames_resident += fr
		resident += _bytes_of(id) * float(frames_resident) / maxf(float(frames_total), 1.0)
	t.info("VRAM S3TC+mips of every baked clip, MB: %s; player %s %.0f MB" % [", ".join(parts), best_player, _mb(best_bytes)])
	t.info("VRAM Hyggebyen worst case (all clips of %d NPC visuals + the player %s): %.0f MB; with the residency rule (idle walk/hover talk of the NPCs): %.0f MB" % [town.size(), best_player, _mb(total), _mb(resident + best_bytes)])
	var everyone := 0.0
	for id in _bytes_s3tc.keys():
		everyone += float(_bytes_s3tc[id])
	t.info("VRAM all 42 new characters with every clip resident: %.0f MB (never the case: areas keep what they show, plan 6.2)" % _mb(everyone))
	t.check("vram_budget_hyggebyen", _mb(total) < VRAM_BUDGET_MB and town.size() >= 12, "%.0f MB (worst case, every clip of %d Hyggebyen NPC visuals + player %s) < %.0f MB; residency rule %.0f MB" % [_mb(total), town.size(), best_player, VRAM_BUDGET_MB, _mb(resident + best_bytes)])


# ---------------------------------------------------------------- the honest README and the town name

func _docs(t) -> void:
	var text := FileAccess.get_file_as_string(README) if FileAccess.file_exists(README) else ""
	_review_sheets(t, text)
	_docs_match_the_code(t)
	var need := ["soft CG render", "stock rig", "satchel", "no walk clip", "single design", "known weaknesses", "Accepted", "contact sheet"]
	var missing: Array[String] = []
	for w in need:
		if not (w.to_lower() in text.to_lower()):
			missing.append(w)
	t.check("readme_verdict_and_honest_notes", text.length() > 1500 and missing.is_empty(), "tools/art/characters/README.md carries the honest notes (CG renders, stock rig, Pippin's satchel, no fairy walk clip, boss = one design), the verdict table and the known weaknesses; missing %s" % str(missing))
	# the town is Hyggebyen: the old working name must not appear in anything this package owns
	var old_name := "Fes" + "by"
	var hits: Array[String] = []
	for path in [README, "res://tools/art/characters/traetoppen_additions.py", "res://tools/art/characters/measure_cast.py", MANIFEST, "res://tests/sections/art_characters.gd"]:
		if FileAccess.file_exists(path) and old_name.to_lower() in FileAccess.get_file_as_string(path).to_lower() and path != "res://tests/sections/art_characters.gd":
			hits.append(path.get_file())
	for id in _all_ids():
		var p := DIR + id + "/animations.json"
		if FileAccess.file_exists(p) and old_name.to_lower() in FileAccess.get_file_as_string(p).to_lower():
			hits.append(id)
	t.check("no_old_town_name", hits.is_empty(), "the fairy town is called Hyggebyen: no file of this package uses the old name %s" % str(hits))


## The contact sheets / screenshots the quality gates 2-6 are judged on live IN THE REPO (tools/art/characters/review/) and the README points at them:
## every `review/<file>.png` the README names exists, decodes, is small, and nothing in the folder is left unmentioned; no path outside the repo
## (the lead's impl/reports folder) is referenced as evidence.
func _review_sheets(t, readme: String) -> void:
	var rx := RegEx.new()
	rx.compile("review/([A-Za-z0-9_\\-]+\\.png)")
	var named: Array[String] = []
	for m in rx.search_all(readme):
		var f: String = m.get_string(1)
		if not named.has(f):
			named.append(f)
	var problems: Array[String] = []
	var total := 0
	for f in named:
		var path := REVIEW_DIR + f
		if not FileAccess.file_exists(path):
			problems.append("%s named in the README but missing" % f)
			continue
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		total += bytes.size()
		var im := Image.new()
		if im.load_png_from_buffer(bytes) != OK or im.is_empty():
			problems.append("%s is not a readable PNG" % f)
		elif im.get_width() < 200 or im.get_height() < 80:
			problems.append("%s is only %s" % [f, str(im.get_size())])
		if bytes.size() > REVIEW_MAX_BYTES:
			problems.append("%s is %d KB (limit %d KB: review sheets must stay small)" % [f, bytes.size() / 1024, REVIEW_MAX_BYTES / 1024])
	var on_disk: Array[String] = []
	var d := DirAccess.open(REVIEW_DIR)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".png"):
				on_disk.append(f)
	for f in on_disk:
		if not named.has(f):
			problems.append("%s is in review/ but the README does not mention it" % f)
	var outside := "impl/reports" in readme or "PongPong_lead_work" in readme
	if outside:
		problems.append("the README still points at files outside the repo (impl/reports)")
	# the gates the README table lists must each name at least one sheet
	var gates_ok := true
	for g in ["contact_cast_next_to_pack", "anim_hobbits", "detail_hobbit_feet", "portraits_96px", "cast_pack_and_new_zoom04", "anim_boss_spin"]:
		if not (g in readme):
			gates_ok = false
			problems.append("README names no %s sheet" % g)
	t.check("readme_points_at_the_review_sheets", problems.is_empty() and gates_ok and named.size() >= 14,
		"%d review/*.png named in tools/art/characters/README.md exist in the repo (%d KB in total, each decodes and is < %d KB), none is left unmentioned, no reference to impl/reports; %s" % [named.size(), total / 1024, REVIEW_MAX_BYTES / 1024, str(problems.slice(0, 4))])


## Doc-drift guard (review defect: the header of this file listed a check that did not exist, measure_cast.py claimed it measured eyes):
## every check name listed in the header lines of this file ("##   name  name ...") is a real t.check name, every real check name is mentioned in
## the header, and the docstring of measure_cast.py does not claim to measure what it does not (eye / face presence).
func _docs_match_the_code(t) -> void:
	var src := FileAccess.get_file_as_string("res://tests/sections/art_characters.gd")
	var header := ""
	var listed: Array[String] = []
	for line in src.split("\n"):
		if not line.begins_with("##"):
			if header != "":
				break
			continue
		header += line + "\n"
		if line.begins_with("##   "):
			for tok in line.substr(5).strip_edges().split(" ", false):
				listed.append(tok)
	var rx := RegEx.new()
	rx.compile("t\\.check\\(\"([a-z0-9_]+)\"")
	var real: Array[String] = []
	for m in rx.search_all(src):
		if not real.has(m.get_string(1)):
			real.append(m.get_string(1))
	var problems: Array[String] = []
	for name in listed:
		if not real.has(name):
			problems.append("the header lists %s, no such check" % name)
	for name in real:
		if not (name in header):
			problems.append("check %s is not mentioned in the header" % name)
	var cast_py := FileAccess.get_file_as_string("res://tools/art/characters/measure_cast.py")
	if cast_py == "" or "eye/face presence" in cast_py or not ("NOTHING about eyes" in cast_py):
		problems.append("measure_cast.py docstring claims eye/face measurement or is missing")
	t.check("docs_match_the_code", problems.is_empty() and listed.size() >= 20 and real.size() >= 26,
		"the header of art_characters.gd lists %d checks, all real (%d t.check names in the file, all mentioned); measure_cast.py's docstring says it measures nothing about eyes %s" % [listed.size(), real.size(), str(problems.slice(0, 4))])


# ---------------------------------------------------------------- windowed: the cast next to the pack, measured VRAM

## [group name, ids] rows of the cast screenshot: the pack reference first, the new cast in rows, the pack again at the end of the last row
const CAST_ROWS := [
	["pack_and_players", ["bear", "cat", "rabbit", "bat", "fox", "fairy", "hobbit_pip", "hobbit_moss", "hobbit_bramble", "squirrel", "fairy_dusk", "fairy_stardust"]],
	["npc_fairies", ["fairy_mayor", "fairy_baker", "fairy_shopkeeper", "fairy_king", "fairy_wizard", "fairy_lily", "fairy_builder", "fairy_furnisher", "fairy_tailor", "mouse_pippin", "cat_morfar_mis", "bear_guard"]],
	["villagers_and_farm", ["rabbit_farmer", "raccoon_smith", "penguin_postman", "chick", "hen", "duck", "kitten", "bunny", "fox_cub", "lamb", "calf", "owl"]],
	["creatures_and_pack", ["puppy", "fawn", "ugleoje", "tornebusk", "lysesvamp", "snurresvamp", "bear", "cat", "rabbit", "bat", "fox", "fairy"]],
	["figurer_v2_npcs", ["bear_brumme", "bat_natteblik", "hedgehog_pip", "owl_fru_ugle", "capybara_sofus", "fairy_birk_npc"]],
]
const CAST_STEP := Vector2(240.0, 250.0)


func run_windowed(t) -> void:
	_t = t
	_load_meta()
	await _cast(t)
	await _vram_measured(t)


func _cast(t) -> void:
	var world: Dictionary = PerfWorld.make_world(t.root, PerfWorld.GAME_ZOOM)
	var objects: Node2D = world["objects"]
	var camera: Camera2D = world["camera"]
	var placed: Array = []           # [id, node, row, col]
	var origin := Vector2(-CAST_STEP.x * 5.5, -CAST_STEP.y * 1.5)
	for r in CAST_ROWS.size():
		var ids: Array = CAST_ROWS[r][1]
		var row_nodes: Array = PerfWorld.place_cast(objects, ids, origin + Vector2(0, CAST_STEP.y * r), Vector2(CAST_STEP.x, 0), ids.size(), PerfWorld.SE, &"idle")
		for c in row_nodes.size():
			placed.append([str(ids[c]), row_nodes[c], r, c])
	camera.position = Vector2(0, 0)
	await t.frames(20)
	var img: Image = await t.capture("cast_pack_and_new_zoom04")
	if img == null:
		return
	var k := float(img.get_width()) / float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var ground: Dictionary = t.region_stats(img, Rect2i(int(8 * k), int(8 * k), int(120 * k), int(30 * k)))
	var flat_bad: Array[String] = []
	var report: Array[String] = []
	for entry in placed:
		var id: String = entry[0]
		var vis: Node2D = entry[1]
		var screen: Vector2 = vis.get_global_transform_with_canvas().origin * k
		var rect := Rect2i(int(screen.x - 34.0 * k), int(screen.y - 92.0 * k), int(68.0 * k), int(100.0 * k))
		var s: Dictionary = t.region_stats(img, rect, 2)
		var good: bool = int(s["distinct"]) > int(ground["distinct"]) + 6 and float(s["luma_std"]) > 0.03
		if not good:
			flat_bad.append(id)
		report.append("%s:%d" % [id, int(s["distinct"])])
	t.check("cast_pixels", flat_bad.is_empty() and placed.size() == 54, "all %d figures (42 new + the pack's bear cat rabbit bat fox fairy twice) have pixels at game zoom 0.4 on grass; ground %d colours; flat: %s" % [placed.size(), int(ground["distinct"]), str(flat_bad)])
	# the same cast on a flat colour, so that the figure height can be MEASURED in rendered pixels (the ground diamonds are green like many figures)
	var ground_node := (world["root"] as Node).get_child(0) as CanvasItem
	var old_clear: Color = RenderingServer.get_default_clear_color()
	var flat := Color(1.0, 0.0, 1.0)
	RenderingServer.set_default_clear_color(flat)
	ground_node.visible = false
	for entry in placed:
		var shadow := (entry[1] as Node).get_node_or_null("Shadow") as CanvasItem
		if shadow != null:
			shadow.visible = false          # the soft contact shadow is not part of the figure
	await t.frames(6)
	var flat_img: Image = await t.capture("cast_flat_for_measuring")
	RenderingServer.set_default_clear_color(old_clear)
	ground_node.visible = true
	for entry in placed:
		var shadow2 := (entry[1] as Node).get_node_or_null("Shadow") as CanvasItem
		if shadow2 != null:
			shadow2.visible = true
	if flat_img == null:
		return
	var heights := {}
	for entry in placed:
		var id2: String = entry[0]
		var vis2: Node2D = entry[1]
		var screen2: Vector2 = vis2.get_global_transform_with_canvas().origin * k
		var h := _rendered_height(flat_img, screen2, flat, k)
		if not heights.has(id2):
			heights[id2] = h
	var ref := 0.0
	for id3 in PACK_REFERENCE:
		ref += float(heights.get(id3, 0.0))
	ref /= float(PACK_REFERENCE.size())
	var bad: Array[String] = []
	var rep2: Array[String] = []
	for id4 in PEOPLE:
		var ratio: float = float(heights.get(id4, 0.0)) / maxf(ref, 1.0)
		rep2.append("%s %d%%" % [id4, int(round(ratio * 100.0))])
		if absf(ratio - 1.0) > HEIGHT_TOLERANCE:
			bad.append("%s %.0f px = %d%% of %.0f" % [id4, float(heights.get(id4, 0.0)), int(round(ratio * 100.0)), ref])
	t.check("cast_matches_pack", bad.is_empty() and ref > 40.0 and flat_bad.is_empty(),
		"rendered at zoom 0.4: the pack's bear cat rabbit fox fairy stand %.0f px tall; 27 people-sized new figures within +/-%d%% (%s) %s" % [ref, int(HEIGHT_TOLERANCE * 100.0), ", ".join(rep2), str(bad)])
	# four close-ups for the human (zoom 0.9 = about the dialogue scale): columns 0-5 / 6-11, rows 0-1 / 2-3 of the cast
	camera.zoom = Vector2(0.9, 0.9)
	var left_x := origin.x + CAST_STEP.x * 2.5
	var right_x := origin.x + CAST_STEP.x * 8.5
	var upper_y := origin.y + CAST_STEP.y * 0.5 - 95.0
	var lower_y := origin.y + CAST_STEP.y * 2.5 - 95.0
	for shot in [["cast_closeup_1_pack_and_mayor_to_lily", left_x, upper_y], ["cast_closeup_2_players_and_builder_to_oak", right_x, upper_y],
			["cast_closeup_3_rosa_to_animals", left_x, lower_y], ["cast_closeup_4_farm_animals_and_pack", right_x, lower_y]]:
		camera.position = Vector2(float(shot[1]), float(shot[2]))
		await t.frames(6)
		await t.capture(str(shot[0]))
	(world["root"] as Node).queue_free()
	await t.frames(2)


## Rendered height of the figure whose feet pivot is at `feet` (image pixels) on the flat colour `bg`: from the highest to the lowest pixel that differs
## from the background (the same bounding box the sheet measurement uses: hobbit feet and tails reach below the pivot).
func _rendered_height(img: Image, feet: Vector2, bg: Color, k: float) -> float:
	var x0 := maxi(int(feet.x - 44.0 * k), 0)
	var x1 := mini(int(feet.x + 44.0 * k), img.get_width() - 1)
	var y0 := maxi(int(feet.y - 90.0 * k), 0)
	var y1 := mini(int(feet.y + 12.0 * k), img.get_height() - 1)
	var top := -1
	var bottom := -1
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := img.get_pixel(x, y)
			if maxf(absf(c.r - bg.r), maxf(absf(c.g - bg.g), absf(c.b - bg.b))) * 255.0 > 40.0:
				if top < 0:
					top = y
				bottom = y
				break
	return float(bottom - top + 1) / k if top >= 0 else 0.0


func _vram_measured(t) -> void:
	var town := _hyggebyen_visuals(t)
	if town.is_empty():
		t.skip("vram_budget_measured: no Hyggebyen NPCs (LuaRuntime not loaded)")
		return
	var before: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var keep: Array = []
	var ids: Array[String] = town.duplicate()
	var best := "fairy_dusk"             # the biggest player: 15 clips, 66 frames (the two fairy skins are equal)
	ids.append(best)
	var sheets := 0
	for id in ids:
		for clip in (_meta_of(id).get("animations", {}) as Dictionary).keys():
			var tex := load(DIR + id + "/" + clip + ".webp") as Texture2D
			if tex != null:
				keep.append(tex)
				sheets += 1
	await t.frames(3)
	var after: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var mb: float = _mb(after - before)
	keep.clear()
	await t.frames(2)
	t.check("vram_budget_measured", mb < VRAM_BUDGET_MB and sheets >= 80, "render server texture memory with every baked clip of the %d Hyggebyen NPC visuals and the player %s resident (%d sheets): +%.0f MB (limit %.0f MB; the computed S3TC figure of the headless check is the same data)" % [town.size(), best, sheets, mb, VRAM_BUDGET_MB])
