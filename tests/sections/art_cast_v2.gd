extends RefCounted
## Section art_cast_v2 (package V2-cast-art, milestone M1a stage 2): the cast of the Style Guide v2 sheet "Figurer" baked by tools/art/cast_v2 - six NEW NPCs
## (bear_brumme bat_natteblik hedgehog_pip owl_fru_ugle capybara_sofus fairy_birk_npc, assets/isometric_characters/<id>) and the two RESTYLES in place
## (fairy_shopkeeper = Butiksfe Kloevermynte, cat_morfar_mis) - as the game loads them, and the tools that built them, against the art contract of plan 6.2 and design
## section 3.2 / 3.4 of docs/design/DUNGEON_V2_ADDENDUM.md.  tests/sections/art_characters.gd (P21's section, carved out to this package) holds the 42 characters to the
## pack-wide gates on the imported textures; this section holds the cast to its OWN gates and runs the Python tools.
##
## Headless (tests/run_playtest.sh --only=art_cast_v2 --no-boot; needs the project imported: the sheets are S3TC textures; the Python checks need tools/art/.venv):
##   builders_resolve  no_new_pattern_no_new_clip  shim_does_not_edit_p21  palette_table_is_the_design  roles_and_clip_sets  sheets_valid  validator_ok  import_stubs_s3tc
##   portraits_exist_and_are_busts  manifest_lists_new_ids  palette_within_de  palette_gate_has_teeth  restyle_idle_s_palette  heights_and_pivot  measure_cast_agrees
##   game_loads_new_cast  vram_budget  review_sheets_exist  readme_has_the_honest_notes  no_old_town_name  docs_match_the_code
## Windowed (tests/run_playtest.sh --windowed --only=art_cast_v2, through tools/dev/run_windowed.sh):
##   windowed_cast_shot
## What each one holds the art to:
##  * builders_resolve: tools/art/cast_v2/check_shim.py: with the folder FIRST on PYTHONPATH the generator's TT_BUILDERS resolves the six new ids and the two restyled ids to cast_v2_models,
##    keeps the other 34 P21 builders as they were (42 in all), builds all eight models with the slug and clip set the order names (villager: Brumme, Pip, Fru Ugle, Sofus, Mis; npc_flyer:
##    Natteblik, Birk, Kloevermynte), and without the folder the six ids do not exist; tools/art/cast_v2/produce_cast_v2.sh --list prints the eight ids with their builder.
##  * no_new_pattern_no_new_clip: the shim re-exports EXTRA_PATTERNS and EXTRA_CLIPS as P21's own objects (attack, spin): no new texture pattern, no new clip, no tone curve.
##  * shim_does_not_edit_p21: tools/art/characters/traetoppen_additions.py is byte-identical before and after the shim is imported and the eight models are built, the table P21 exports is not
##    mutated, and no file of tools/art/cast_v2 writes under tools/art/characters.
##  * palette_table_is_the_design: tools/art/cast_v2/palettes_v2.json carries the 13 figures of design section 3.4 and the baked models of the eight ids contain every region hex of their figure.
##  * roles_and_clip_sets: the eight folders say role npc, family, flyer (a bat and a fairy fly), display_scale 1.0, portrait.webp, no glow, cell 256 pivot [128,200], and exactly the clips of
##    their clip set (villager idle walk talk celebrate interact sleep; npc_flyer idle hover talk celebrate interact) with the frames / fps / loop of artcontract.
##  * sheets_valid: the 6 new folders: every sheet is 256 x frames by 2048 as WebP header and as imported texture, decodes, and no cell of the 8 directions x frames is blank or cut by its border.
##  * validator_ok: tools/art/core/validate_new_assets.py --root assets/isometric_characters <the six new ids> says OK for all six (the acceptance row of the order).
##  * import_stubs_s3tc: every sheet of the six has the S3TC preset (compress/mode=2, high_quality=false, mipmaps) and a Godot-assigned uid; the portraits are lossless.
##  * portraits_exist_and_are_busts: portrait.webp of the six is a 256 x 256 head-and-shoulders bust, not blank, top / left / right edges clear (artcontract.PORTRAIT_CHECKED_EDGES), baked with the guide
##    ink outline (43, 35, 64) while the world sheets keep the pack's (75, 60, 73); P07's TTPortraits resolves each id to its own folder portrait and nothing was added to assets/portraits.
##  * manifest_lists_new_ids: manifest_traetoppen.json carries a row for each of the six new ids equal to its animations.json, keeps the 36 rows of P21, and the rows of G-ghost-art (when its folders exist).
##  * palette_within_de: tools/art/cast_v2/measure_cast_v2.py palette --check: the dominant region of the idle-S frame of the single-region figures (Brumme, Fru Ugle, Sofus, Hoppe = the pack rabbit)
##    is within CIEDE2000 6 of the sketch fill, every region of the multi-region figures (Natteblik, Pip, Birk) is within 6 on the palette hex the bake starts from; A2's heroes are SKIPPED with a line.
##  * palette_gate_has_teeth: measure_cast_v2.py palette --selftest: exact colours pass, a figure in another colour fails, the CIEDE2000 numbers equal the published test pairs.
##  * restyle_idle_s_palette: the two restyles (baked into the stage on every run, installed on request) built and rendered in a throw-away stage: their idle-S frame passes the same gate
##    (cat_morfar_mis dominant region, fairy_shopkeeper region by region), their height is within 10 % of the pack, and the stage is removed again; the two installed folders are not touched here.
##  * heights_and_pivot: measure_cast_v2.py --check on the six installed folders: idle SE within +/-10 % of the pack mean (167 px), the pack outline (75, 60, 73), every frame of every clip on
##    the pivot (128, 200) (a bat flies: the flyer window); display_scale stays 1.0 (Brumme's sketch is 10.2 % short: relative sizes of a shape sketch are not binding).
##  * measure_cast_agrees: tools/art/characters/measure_cast.py --check and --selftest (P21's own gate, unchanged) still exit 0 with the new folders in assets/.
##  * game_loads_new_cast: IsoChibiSprite2D.create(<id>) on the real sheets resolves to the folder itself (no stand-in), role npc, display_scale 1, the clips of its set play, a 256 portrait.
##  * vram_budget: S3TC with mipmaps of the clips an NPC keeps resident (idle, walk / hover, talk): about 9 MB each, within 15 % of P21's villager bear_guard.
##  * review_sheets_exist: tools/art/cast_v2/README.md names the review sheets in tools/art/cast_v2/review_v2/ (13 compare_<figure>.png, contact_cast_v2, cast_next_to_pack_zoom04,
##    outline_ink_vs_pack); they exist, decode and are small, none is left unmentioned.
##  * readme_has_the_honest_notes: the README carries the honest verdict (soft CG renders, upright poses, Natteblik and Fru Ugle share their models with the hostile bat / ugleoje, Kiki's banana
##    and Rasmus's scarf are not baked, Sofus is the one new body and the one figure that can look wrong, the ink outline is not adopted for world sprites, the install order of the restyles, Codex).
##  * no_old_town_name: the fairy town is Hyggebyen: no file of this package uses the old name, and every file the section reads exists.
##  * docs_match_the_code: this header lists every check of the file by its full name and describes it.
##  * windowed_cast_shot: the eight cast figures next to the pack's bear cat rabbit fox fairy on grass at Camera zoom 0.4 (1280 x 720) are written for the human (art_cast_v2_cast_zoom04.png and a
##    zoom 0.9 close-up); every figure has pixels, the rendered height of each is within 10 % of the pack mean.
const SECTION := "art_cast_v2"
const TIMEOUT_S := 420.0

const Catalog := preload("res://scripts/isometric/character_catalog.gd")
const PerfWorld := preload("res://tests/perf_world.gd")
## P07's real portrait resolver (no class_name: preloaded by path like tests/sections/art_characters.gd does)
const Portraits := preload("res://scripts/ui/theme/tt_portraits.gd")

const DIR := "res://assets/isometric_characters/"
const PORTRAIT_DIR := "res://assets/portraits/"
const MANIFEST := "res://assets/isometric_characters/manifest_traetoppen.json"
const README := "res://tools/art/cast_v2/README.md"
const REVIEW_DIR := "res://tools/art/cast_v2/review_v2/"
const REVIEW_MAX_BYTES := 900000
const CELL := 256
const SHEET_H := 2048
const PIVOT := [128, 200]
const DIRECTIONS := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
const SPRITE_ALPHA := 24
const NEW_IDS: Array[String] = ["bear_brumme", "bat_natteblik", "hedgehog_pip", "owl_fru_ugle", "capybara_sofus", "fairy_birk_npc"]
const RESTYLE_IDS: Array[String] = ["fairy_shopkeeper", "cat_morfar_mis"]
const CAST_IDS: Array[String] = ["bear_brumme", "bat_natteblik", "hedgehog_pip", "owl_fru_ugle", "capybara_sofus", "fairy_birk_npc", "fairy_shopkeeper", "cat_morfar_mis"]
const SET_OF := {"bear_brumme": "villager", "bat_natteblik": "npc_flyer", "hedgehog_pip": "villager", "owl_fru_ugle": "villager", "capybara_sofus": "villager",
	"fairy_birk_npc": "npc_flyer", "fairy_shopkeeper": "npc_flyer", "cat_morfar_mis": "villager"}
const SET_CLIPS := {"villager": ["idle", "walk", "talk", "celebrate", "interact", "sleep"], "npc_flyer": ["idle", "hover", "talk", "celebrate", "interact"]}
## clip -> [frames, fps, loop] (artcontract.SPEC / FLIGHT)
const CLIP_SPEC := {"idle": [4, 5, true], "walk": [6, 9, true], "talk": [4, 6, true], "celebrate": [6, 9, false], "interact": [4, 9, false], "sleep": [4, 3, true], "hover": [5, 8, true]}
const FLYERS: Array[String] = ["bat_natteblik", "fairy_birk_npc", "fairy_shopkeeper"]
const PACK_REFERENCE: Array[String] = ["bear", "cat", "rabbit", "fox", "fairy"]
const HEIGHT_TOLERANCE := 0.10
const INK := Vector3(43, 35, 64)
const INK_TOLERANCE := 10.0
const REVIEW_NEED: Array[String] = ["contact_cast_v2", "cast_next_to_pack_zoom04", "outline_ink_vs_pack", "compare_hoppe", "compare_brumme", "compare_morfar_mis", "compare_natteblik",
	"compare_rasmus", "compare_bertil", "compare_bodil", "compare_kloevermynte", "compare_birk", "compare_pip", "compare_fru_ugle", "compare_sofus", "compare_kiki"]

var _t
var _py := ""
var _meta: Dictionary = {}
var _bytes_s3tc: Dictionary = {}          # id -> imported S3TC bytes of every sheet
var _resident_s3tc: Dictionary = {}       # id -> bytes of idle + walk / hover + talk


func run(t) -> void:
	_t = t
	for id in CAST_IDS:
		_meta[id] = _json(DIR + id + "/animations.json")
	_py = _python()
	_shim(t)
	_roles_and_clips(t)
	_scan_sheets(t)
	_validator(t)
	_import_stubs(t)
	_portraits(t)
	_manifest(t)
	_palette(t)
	_restyle(t)
	_heights_and_pivot(t)
	_measure_agrees(t)
	await _game_loads(t)
	_vram(t)
	_docs(t)


# ---------------------------------------------------------------- helpers

func _python() -> String:
	if FileAccess.file_exists("res://tools/art/.venv/bin/python"):
		return ProjectSettings.globalize_path("res://tools/art/.venv/bin/python")
	return ""


func _abs(res_path: String) -> String:
	return ProjectSettings.globalize_path(res_path).trim_suffix("/")


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


func _ints(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(int(x))
	return out


func _mb(bytes: float) -> float:
	return bytes / 1048576.0


## Runs a Python tool of the art venv: {code, output, lines}; code -1 and an explanatory output when the venv is missing.
func _run_py(args: PackedStringArray) -> Dictionary:
	if _py == "":
		return {"code": -1, "output": "tools/art/.venv/bin/python not found (tools/art/setup_env.sh)", "lines": PackedStringArray()}
	return _t.run_tool(_py, args)


func _last_line(res: Dictionary) -> String:
	var lines: PackedStringArray = res.get("lines", PackedStringArray())
	return lines[lines.size() - 1] if lines.size() > 0 else str(res.get("output", ""))


func _skip_py(t, what: String) -> void:
	t.skip("art_cast_v2.%s: tools/art/.venv is missing (tools/art/setup_env.sh): the Python gate of package V2-cast-art did not run" % what)


# ---------------------------------------------------------------- the shim (task 1)

func _shim(t) -> void:
	if _py == "":
		for n in ["builders_resolve", "no_new_pattern_no_new_clip", "shim_does_not_edit_p21", "palette_table_is_the_design"]:
			_skip_py(t, n)
		return
	var res: Dictionary = _run_py(PackedStringArray(["-I", _abs("res://tools/art/cast_v2/check_shim.py")]))
	var ids: Dictionary = t.parse_tool_ids(res)
	var passed: Array = ids["pass"]
	var failed: Array = ids["fail"]
	var detail: String = ""
	for line in res.get("lines", PackedStringArray()):
		if str(line).begins_with("FAIL"):
			detail += str(line).substr(0, 300) + " | "
	var listing: Dictionary = _t.run_tool("/bin/bash", PackedStringArray([_abs("res://tools/art/cast_v2/produce_cast_v2.sh"), "--list"]))
	var listed := 0
	for id in CAST_IDS:
		if ("%s " % id) in str(listing["output"]) and "cast_v2_models" in str(listing["output"]):
			listed += 1
	t.check("builders_resolve", "builders_resolve" in passed and listed == 8 and int(listing["code"]) == 0 and "shim won the import" in str(listing["output"]),
		"check_shim.py: TT_BUILDERS resolves the 8 ids to cast_v2_models (6 new + 2 restyled), 34 P21 builders untouched, slug and clip set as ordered; produce_cast_v2.sh --list prints %d of 8 ids (exit %s) %s" % [listed, str(listing["code"]), detail])
	t.check("no_new_pattern_no_new_clip", "no_new_pattern_no_new_clip" in passed, "EXTRA_PATTERNS / EXTRA_CLIPS of the shim are P21's own objects (attack, spin) %s" % detail)
	t.check("shim_does_not_edit_p21", "shim_does_not_edit_p21" in passed and failed.is_empty(), "tools/art/characters/traetoppen_additions.py is byte-identical before and after the shim ran, its table is not mutated, nothing writes under tools/art/characters; failed ids %s" % str(failed))
	t.check("palette_table_is_the_design", "palette_table_is_the_design" in passed, "palettes_v2.json = the 13 figures of design 3.4, every region hex is a colour of the baked model %s" % detail)


# ---------------------------------------------------------------- roles, clip sets, sheets

func _roles_and_clips(t) -> void:
	var problems: Array[String] = []
	var checked := 0
	for id in CAST_IDS:
		var meta: Dictionary = _meta[id]
		if meta.is_empty():
			problems.append("%s has no animations.json" % id)
			continue
		checked += 1
		var set_name: String = SET_OF[id]
		if str(meta.get("role", "")) != "npc":
			problems.append("%s role %s want npc" % [id, str(meta.get("role", ""))])
		if str(meta.get("clip_set", "")) != set_name:
			problems.append("%s clip_set %s want %s" % [id, str(meta.get("clip_set", "")), set_name])
		if str(meta.get("family", "")) == "":
			problems.append("%s has no family" % id)
		if bool(meta.get("flyer", false)) != (id in FLYERS):
			problems.append("%s flyer %s" % [id, str(meta.get("flyer", false))])
		if float(meta.get("display_scale", 0.0)) != 1.0:
			problems.append("%s display_scale %s (sprites are never scaled individually)" % [id, str(meta.get("display_scale", "?"))])
		if str(meta.get("portrait", "")) != "portrait.webp":
			problems.append("%s portrait %s" % [id, str(meta.get("portrait", ""))])
		if meta.has("glow"):
			problems.append("%s has a glow block (only the glowing lysesvamp may)" % id)
		if _ints(meta.get("cell_size", [])) != [CELL, CELL] or _ints(meta.get("pivot", [])) != PIVOT or meta.get("directions", []) != DIRECTIONS:
			problems.append("%s cell/pivot/directions" % id)
		var anims: Dictionary = meta.get("animations", {})
		var got: Array = anims.keys()
		got.sort()
		var want: Array = (SET_CLIPS[set_name] as Array).duplicate()
		want.sort()
		if got != want:
			problems.append("%s clips %s want %s" % [id, str(got), str(want)])
		for clip in want:
			if not anims.has(clip):
				continue
			var spec: Array = CLIP_SPEC[clip]
			var a: Dictionary = anims[clip]
			if int(a.get("frames", 0)) != int(spec[0]) or int(a.get("fps", 0)) != int(spec[1]) or bool(a.get("loop", not bool(spec[2]))) != bool(spec[2]) or str(a.get("sheet", "")) != clip + ".webp":
				problems.append("%s/%s frames/fps/loop/sheet %s want %s" % [id, clip, str(a), str(spec)])
	t.check("roles_and_clip_sets", problems.is_empty() and checked == 8,
		"%d folders (6 new + the 2 restyled in place): role npc, flyer = bat / fairy, display_scale 1.0, portrait.webp, no glow, cell 256 pivot [128,200], exactly the clips of the clip set (villager: Brumme Pip Fru Ugle Sofus Mis; npc_flyer: Natteblik Birk Kloevermynte) with the frames / fps / loop of the contract; %s" % [checked, str(problems.slice(0, 6))])


func _cut_by_border(data: PackedByteArray) -> bool:
	var limit := SPRITE_ALPHA + 16
	for i in CELL:
		if int(data[i * 4 + 3]) > limit or int(data[((CELL - 1) * CELL + i) * 4 + 3]) > limit:
			return true
		if int(data[(i * CELL) * 4 + 3]) > limit or int(data[(i * CELL + CELL - 1) * 4 + 3]) > limit:
			return true
	return false


## The six new folders: header size = import size = 256 x frames by 2048, S3TC textures decode, no blank or cut cell; S3TC bytes are summed per id for the budget.
func _scan_sheets(t) -> void:
	var size_bad: Array[String] = []
	var cell_bad: Array[String] = []
	var format_bad: Array[String] = []
	var sheets := 0
	var cells := 0
	for id in CAST_IDS:
		var anims: Dictionary = (_meta[id] as Dictionary).get("animations", {})
		var id_bytes := 0.0
		var resident := 0.0
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
			var gpu: Image = tex.get_image()
			if gpu == null or gpu.is_empty() or tex.get_width() != CELL * frames or tex.get_height() != SHEET_H:
				size_bad.append("%s/%s texture %dx%d" % [id, clip, tex.get_width(), tex.get_height()])
				continue
			if not gpu.is_compressed() or not (gpu.get_format() in [Image.FORMAT_DXT1, Image.FORMAT_DXT3, Image.FORMAT_DXT5, Image.FORMAT_RGTC_RG]):
				format_bad.append("%s/%s format %d" % [id, clip, gpu.get_format()])
			var b := float(gpu.get_data().size())
			id_bytes += b
			if clip in ["idle", "walk", "hover", "talk"]:
				resident += b
			if not (id in NEW_IDS):
				continue                    # the two restyled folders are measured for their sizes only (art_characters scans their cells)
			gpu.decompress()
			if gpu.get_format() != Image.FORMAT_RGBA8:
				gpu.convert(Image.FORMAT_RGBA8)
			for row in 8:
				for f in frames:
					cells += 1
					var cell := gpu.get_region(Rect2i(f * CELL, row * CELL, CELL, CELL))
					if cell.is_invisible():
						cell_bad.append("%s/%s row %d frame %d blank" % [id, clip, row, f])
					elif _cut_by_border(cell.get_data()) and cell_bad.size() < 40:
						cell_bad.append("%s/%s row %d frame %d touches the cell border" % [id, clip, row, f])
		_bytes_s3tc[id] = id_bytes
		_resident_s3tc[id] = resident
	t.check("sheets_valid", size_bad.is_empty() and cell_bad.is_empty() and format_bad.is_empty() and sheets == 45 and cells > 800,
		"%d sheets of the eight folders: WebP header = import size = 256 x frames by 2048, S3TC; the 6 new ones decode to %d cells (8 directions x frames), none blank, none cut by its border; %s %s %s" % [sheets, cells, str(size_bad.slice(0, 3)), str(cell_bad.slice(0, 3)), str(format_bad.slice(0, 3))])


func _validator(t) -> void:
	if _py == "":
		_skip_py(t, "validator_ok")
		return
	var args := PackedStringArray([_abs("res://tools/art/core/validate_new_assets.py"), "--root", _abs("res://assets/isometric_characters")])
	args.append_array(PackedStringArray(NEW_IDS))
	var res: Dictionary = _run_py(args)
	var oks := 0
	for line in res.get("lines", PackedStringArray()):
		if str(line).begins_with("OK   "):
			oks += 1
	t.check("validator_ok", int(res["code"]) == 0 and oks == 6, "tools/art/core/validate_new_assets.py --root assets/isometric_characters <the six new ids>: exit %s, %d x OK, '%s'" % [str(res["code"]), oks, _last_line(res)])


func _param(text: String, key: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(key + "="):
			return line.substr(key.length() + 1).strip_edges()
	return ""


func _import_stubs(t) -> void:
	var bad: Array[String] = []
	var n := 0
	for id in NEW_IDS:
		for clip in ((_meta[id] as Dictionary).get("animations", {}) as Dictionary).keys():
			n += 1
			var imp: String = DIR + id + "/" + str(clip) + ".webp.import"
			if not FileAccess.file_exists(imp):
				bad.append("%s/%s: no .import" % [id, clip])
				continue
			var text := FileAccess.get_file_as_string(imp)
			if _param(text, "compress/mode") != "2" or _param(text, "compress/high_quality") != "false" or _param(text, "mipmaps/generate") != "true":
				bad.append("%s/%s: preset is not S3TC + mipmaps" % [id, clip])
			if not text.contains("uid=\"uid://"):
				bad.append("%s/%s: no Godot-assigned uid yet (godot --headless --import, twice; pull_meta.sh)" % [id, clip])
		var pimp := DIR + id + "/portrait.webp.import"
		if FileAccess.file_exists(pimp) and _param(FileAccess.get_file_as_string(pimp), "compress/mode") == "2":
			bad.append("%s portrait is VRAM compressed (portraits are lossless)" % id)
	t.check("import_stubs_s3tc", bad.is_empty() and n == 34,
		"%d sheet .import files of the six new folders carry compress/mode=2, high_quality=false, mipmaps (S3TC) and a Godot-assigned uid; portraits stay lossless %s" % [n, str(bad.slice(0, 4))])


# ---------------------------------------------------------------- portraits (task 3)

## the isolated outline pixels of a bust (alpha 200 .. 250 next to a clear pixel): the median colour; the guide ink is alpha .92, the pack outline alpha .55 (about 140)
func _bust_outline(im: Image) -> Vector3:
	var data: PackedByteArray = im.get_data()
	var rs: Array[int] = []
	var gs: Array[int] = []
	var bs: Array[int] = []
	for y in range(1, CELL - 1):
		for x in range(1, CELL - 1):
			var a: int = int(data[(y * CELL + x) * 4 + 3])
			if a < 200 or a > 250:
				continue
			if int(data[(y * CELL + x - 1) * 4 + 3]) == 0 or int(data[(y * CELL + x + 1) * 4 + 3]) == 0 or int(data[((y - 1) * CELL + x) * 4 + 3]) == 0 or int(data[((y + 1) * CELL + x) * 4 + 3]) == 0:
				var o := (y * CELL + x) * 4
				rs.append(int(data[o]))
				gs.append(int(data[o + 1]))
				bs.append(int(data[o + 2]))
	if rs.size() < 30:
		return Vector3(-1, -1, -1)
	rs.sort()
	gs.sort()
	bs.sort()
	var m := rs.size() / 2
	return Vector3(float(rs[m]), float(gs[m]), float(bs[m]))


func _bust_problems(id: String) -> Array[String]:
	var out: Array[String] = []
	var path: String = DIR + id + "/portrait.webp"
	var im := _decode(path)
	if im == null:
		out.append("%s: portrait.webp unreadable" % id)
		return out
	if im.get_size() != Vector2i(CELL, CELL):
		out.append("%s portrait is %s" % [id, str(im.get_size())])
		return out
	if im.is_invisible():
		out.append("%s portrait blank" % id)
		return out
	var data: PackedByteArray = im.get_data()
	for i in CELL:
		if int(data[i * 4 + 3]) > SPRITE_ALPHA:
			out.append("%s cut at the top" % id)
			break
	for j in CELL:
		if int(data[(j * CELL) * 4 + 3]) > SPRITE_ALPHA or int(data[(j * CELL + CELL - 1) * 4 + 3]) > SPRITE_ALPHA:
			out.append("%s cut at a side" % id)
			break
	return out


func _portraits(t) -> void:
	var bad: Array[String] = []
	var report: Array[String] = []
	for id in NEW_IDS:
		bad.append_array(_bust_problems(id))
		var im := _decode(DIR + id + "/portrait.webp")
		if im != null and im.get_size() == Vector2i(CELL, CELL):
			var oc := _bust_outline(im)
			report.append("%s %s" % [id, str(oc.round())])
			if oc.x < 0.0 or absf(oc.x - INK.x) > INK_TOLERANCE or absf(oc.y - INK.y) > INK_TOLERANCE or absf(oc.z - INK.z) > INK_TOLERANCE:
				bad.append("%s bust outline %s is not the guide ink %s" % [id, str(oc.round()), str(INK)])
		# the world sheet keeps the pack outline: idle SE, isolated outline pixels (alpha 130 .. 150) of the sheet cell
		var sheet := _decode(DIR + id + "/idle.webp")
		if sheet != null:
			var cell := sheet.get_region(Rect2i(0, 7 * CELL, CELL, CELL))
			var data: PackedByteArray = cell.get_data()
			var rgb := Vector3.ZERO
			var cnt := 0
			for y in range(1, CELL - 1):
				for x in range(1, CELL - 1):
					var a: int = int(data[(y * CELL + x) * 4 + 3])
					if a < 130 or a > 150:
						continue
					if int(data[(y * CELL + x - 1) * 4 + 3]) == 0 or int(data[(y * CELL + x + 1) * 4 + 3]) == 0 or int(data[((y - 1) * CELL + x) * 4 + 3]) == 0 or int(data[((y + 1) * CELL + x) * 4 + 3]) == 0:
						var o := (y * CELL + x) * 4
						rgb += Vector3(float(data[o]), float(data[o + 1]), float(data[o + 2]))
						cnt += 1
			if cnt < 30 or absf(rgb.x / cnt - 75.0) > 9.0 or absf(rgb.y / cnt - 60.0) > 9.0 or absf(rgb.z / cnt - 73.0) > 9.0:
				bad.append("%s world sheet outline %s is not the pack's (75,60,73)" % [id, str((rgb / maxf(float(cnt), 1.0)).round())])
		# P07's resolver: the folder's own portrait, never a stand-in, and the file loads as a 256 bust
		if Portraits.resolve_visual_path([id]) != DIR + id + "/portrait.webp":
			bad.append("TTPortraits resolves %s to %s" % [id, Portraits.resolve_visual_path([id])])
		var tex := Portraits.portrait_by_sprite(id)
		if tex == null or tex.get_width() != CELL or tex.get_height() != CELL:
			bad.append("portrait_by_sprite(%s) is %s" % [id, str(tex)])
		if FileAccess.file_exists(PORTRAIT_DIR + id + ".webp"):
			bad.append("assets/portraits/%s.webp exists (the cast's busts live in their folders, nothing goes to assets/portraits)" % id)
	t.check("portraits_exist_and_are_busts", bad.is_empty(),
		"portrait.webp of the six new folders: 256 x 256 head-and-shoulders busts (14 degree camera), not blank, top / left / right clear, baked with the guide ink outline [%s] while the world sheets keep (75,60,73); TTPortraits resolves each to its own folder, nothing in assets/portraits %s" % [", ".join(report), str(bad.slice(0, 4))])


# ---------------------------------------------------------------- manifest (task 3)

func _manifest(t) -> void:
	var man: Dictionary = _json(MANIFEST)
	var chars: Dictionary = man.get("characters", {})
	var problems: Array[String] = []
	for id in NEW_IDS:
		if not chars.has(id):
			problems.append("%s not in manifest_traetoppen.json" % id)
			continue
		var row: Dictionary = chars[id]
		var meta: Dictionary = _meta[id]
		for k in ["role", "clip_set", "family", "flyer", "display_scale", "portrait"]:
			if row.get(k) != meta.get(k):
				problems.append("%s.%s manifest %s vs animations.json %s" % [id, k, str(row.get(k)), str(meta.get(k))])
		if row.get("animations", {}) != meta.get("animations", {}):
			problems.append("%s clip table differs from animations.json" % id)
	var p21_rows := 0
	for id in ["hobbit_pip", "squirrel", "fairy_mayor", "fairy_shopkeeper", "cat_morfar_mis", "bear_guard", "snurresvamp", "lysesvamp", "fairy_tailor", "owl", "duck", "tornebusk"]:
		if chars.has(id):
			p21_rows += 1
	var ghost_note := ""
	for gid in ["ghost_bu", "ghost_hviske"]:
		if DirAccess.dir_exists_absolute(_abs(DIR + gid)):
			if not chars.has(gid):
				problems.append("the ghost folder %s exists but its manifest row is missing (the shared manifest lost a row of G-ghost-art)" % gid)
			else:
				ghost_note += gid + " "
	var keys: Array = chars.keys()
	var sorted_keys := keys.duplicate()
	sorted_keys.sort()
	t.check("manifest_lists_new_ids", problems.is_empty() and p21_rows == 12 and int(man.get("format_version", 0)) == 2 and keys == sorted_keys and chars.size() >= 42,
		"manifest_traetoppen.json carries the six new rows equal to their animations.json (merged by the installer), keeps the P21 rows (%d of 12 sampled) and the ghost rows [%s]; %d rows in all, sorted, format_version 2 %s" % [p21_rows, ghost_note.strip_edges(), chars.size(), str(problems.slice(0, 4))])


# ---------------------------------------------------------------- the palette gate (task 5)

func _palette(t) -> void:
	if _py == "":
		_skip_py(t, "palette_within_de")
		_skip_py(t, "palette_gate_has_teeth")
		return
	var tool := _abs("res://tools/art/cast_v2/measure_cast_v2.py")
	var args := PackedStringArray([tool, "palette", "--check", "--root", _abs("res://assets/isometric_characters")])
	args.append_array(PackedStringArray(NEW_IDS))
	args.append("rabbit")
	var res: Dictionary = _run_py(args)
	var skips := 0
	var nfail := 0
	for line in res.get("lines", PackedStringArray()):
		if "SKIP" in str(line):
			skips += 1
			t.skip("art_cast_v2.palette_within_de (hero figure): %s" % str(line).strip_edges())      # a visible line naming the package that owns the gate
		if " FAIL" in str(line) or "MISSING" in str(line):
			nfail += 1
	t.check("palette_within_de", int(res["code"]) == 0 and nfail == 0 and "every figure within CIEDE2000 6" in str(res["output"]),
		"measure_cast_v2.py palette --check on the installed folders: dominant region of the idle-S frame within dE00 6 of the sketch fill (Brumme, Fru Ugle, Sofus, Hoppe = the pack rabbit), every sketch region within 6 on the palette hex (Natteblik, Pip, Birk); %d hero figure(s) of A2 SKIPPED (art_wardrobe.hero_palettes_within_de, package A2-art-wardrobe has not baked its bases); exit %s, '%s'" % [skips, str(res["code"]), _last_line(res)])
	var teeth: Dictionary = _run_py(PackedStringArray([tool, "--selftest"]))
	t.check("palette_gate_has_teeth", int(teeth["code"]) == 0 and "accepts" in str(teeth["output"]), "measure_cast_v2.py --selftest: exit %s, '%s'" % [str(teeth["code"]), _last_line(teeth)])


func _rm_rf(abs_dir: String) -> void:
	var d := DirAccess.open(abs_dir)
	if d == null:
		return
	d.include_hidden = true
	for sub in d.get_directories():
		_rm_rf(abs_dir.path_join(sub))
	for f in d.get_files():
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)


## The two restyles are baked into the stage on every run and installed only on request: here they are built and their idle-S frame rendered in a throw-away stage inside tools/art/_stage.
func _restyle(t) -> void:
	if _py == "":
		_skip_py(t, "restyle_idle_s_palette")
		return
	var tool := _abs("res://tools/art/cast_v2/measure_cast_v2.py")
	var stage := _abs("res://tools/art/_stage") + "/v2cast_test"
	_rm_rf(stage)
	var args := PackedStringArray([tool, "render", "--stage", stage])
	args.append_array(PackedStringArray(RESTYLE_IDS))
	var made: Dictionary = _run_py(args)
	var root := stage + "/masters/isometric_characters"
	var pal_args := PackedStringArray([tool, "palette", "--check", "--root", root])
	pal_args.append_array(PackedStringArray(RESTYLE_IDS))
	var pal: Dictionary = _run_py(pal_args) if int(made["code"]) == 0 else {"code": -1, "output": str(made["output"]), "lines": PackedStringArray()}
	var h_args := PackedStringArray([tool, "--check", "--no-pivot", "--root", root])
	h_args.append_array(PackedStringArray(RESTYLE_IDS))
	var hts: Dictionary = _run_py(h_args) if int(made["code"]) == 0 else {"code": -1, "output": str(made["output"]), "lines": PackedStringArray()}
	_rm_rf(stage)
	t.check("restyle_idle_s_palette", int(made["code"]) == 0 and int(pal["code"]) == 0 and int(hts["code"]) == 0 and "every figure within CIEDE2000 6" in str(pal["output"]) and "within +/-10%" in str(hts["output"]) and not DirAccess.dir_exists_absolute(stage),
		"fairy_shopkeeper (Butiksfe Kloevermynte: hood-bob 9b86d6, coronet, dress e88f9f) and cat_morfar_mis (body a7adb9, green irises, tabby stripes) built and rendered in a throw-away stage (exit %s): palette gate exit %s ('%s'), height gate exit %s ('%s'); the stage is removed again" % [str(made["code"]), str(pal["code"]), _last_line(pal).substr(0, 120), str(hts["code"]), _last_line(hts).substr(0, 120)])


# ---------------------------------------------------------------- heights, outline, pivot (task 6)

func _heights_and_pivot(t) -> void:
	if _py == "":
		_skip_py(t, "heights_and_pivot")
		return
	var tool := _abs("res://tools/art/cast_v2/measure_cast_v2.py")
	var args := PackedStringArray([tool, "--check", "--root", _abs("res://assets/isometric_characters")])
	args.append_array(PackedStringArray(NEW_IDS))
	var res: Dictionary = _run_py(args)
	t.check("heights_and_pivot", int(res["code"]) == 0 and "within +/-10%" in str(res["output"]),
		"measure_cast_v2.py --check on the six installed folders (it imports P21's measure_cast.py): idle SE within +/-10 %% of the pack mean, the pack outline, every frame of every clip on the pivot (128, 200); exit %s, '%s'" % [str(res["code"]), _last_line(res).substr(0, 170)])


func _measure_agrees(t) -> void:
	if _py == "":
		_skip_py(t, "measure_cast_agrees")
		return
	var tool := _abs("res://tools/art/characters/measure_cast.py")
	var res: Dictionary = _run_py(PackedStringArray([tool, "--check", "--root", _abs("res://assets/isometric_characters"), "--no-pivot"]))
	var self_res: Dictionary = _run_py(PackedStringArray([tool, "--selftest"]))
	t.check("measure_cast_agrees", int(res["code"]) == 0 and int(self_res["code"]) == 0, "P21's tools/art/characters/measure_cast.py (unchanged) --check exit %s, --selftest exit %s with the new folders in assets/" % [str(res["code"]), str(self_res["code"])])


# ---------------------------------------------------------------- the game loads the cast

func _game_loads(t) -> void:
	var host := Node2D.new()
	host.name = "ArtCastV2Host"
	t.root.add_child(host)
	var bad: Array[String] = []
	var report: Array[String] = []
	for id in CAST_IDS:
		if Catalog.resolve(id) != id:
			bad.append("CharacterCatalog.resolve(%s) = '%s': the stand-in chain still wins over the art" % [id, Catalog.resolve(id)])
		var sprite := IsoChibiSprite2D.create(id)
		if sprite == null:
			bad.append("%s: IsoChibiSprite2D.create returned null" % id)
			continue
		host.add_child(sprite)
		sprite.set_direction_index(7)
		await t.frames(2)
		var names := sprite.get_clip_names()
		report.append("%s %d clips" % [id, names.size()])
		var want: Array = SET_CLIPS[SET_OF[id]]
		if sprite.resolved_id != id or sprite.role != "npc" or sprite.display_scale != 1.0 or names.size() != want.size() or sprite.flyer != (id in FLYERS):
			bad.append("%s resolved %s role %s display_scale %s flyer %s clips %d" % [id, sprite.resolved_id, sprite.role, str(sprite.display_scale), str(sprite.flyer), names.size()])
		for clip in want:
			if not sprite.has_clip(StringName(clip)):
				bad.append("%s has no clip %s" % [id, clip])
				continue
			sprite.play_loop(StringName(clip))
		await t.frames(2)
		var portrait := sprite.get_portrait()
		if portrait == null or portrait.get_width() != CELL:
			bad.append("%s get_portrait() is %s" % [id, str(portrait)])
		sprite.queue_free()
	host.queue_free()
	await t.frames(1)
	t.check("game_loads_new_cast", bad.is_empty(), "IsoChibiSprite2D.create(<id>) on the real sheets: resolves to the folder itself (CharacterCatalog.resolve = id, no stand-in), role npc, display_scale 1, flyer = bat / fairy, every clip of the set plays, a 256 portrait (%s) %s" % [", ".join(report), str(bad.slice(0, 4))])


func _resident_bytes(id: String) -> float:
	var total := 0.0
	var anims: Dictionary = _json(DIR + id + "/animations.json").get("animations", {})
	for clip in anims.keys():
		if clip in ["idle", "walk", "hover", "talk"]:
			var tex := load(DIR + id + "/" + str(clip) + ".webp") as Texture2D
			if tex != null:
				total += float(tex.get_image().get_data().size())
	return total


func _vram(t) -> void:
	var guard := _resident_bytes("bear_guard")
	var bad: Array[String] = []
	var parts: Array[String] = []
	for id in CAST_IDS:
		var mb := _mb(float(_resident_s3tc.get(id, 0.0)))
		parts.append("%s %.1f" % [id, mb])
		if mb < 6.0 or mb > 12.0 or guard <= 0.0 or absf(float(_resident_s3tc.get(id, 0.0)) - guard) > 0.15 * guard:
			bad.append("%s %.1f MB resident (P21's villager bear_guard %.1f MB)" % [id, mb, _mb(guard)])
	var disk_mb := 0.0
	for id in NEW_IDS:
		var d := DirAccess.open(DIR + id)
		if d != null:
			for f in d.get_files():
				var fa := FileAccess.open(DIR + id + "/" + f, FileAccess.READ)
				if fa != null:
					disk_mb += _mb(float(fa.get_length()))
	t.info("VRAM S3TC+mips of idle + walk/hover + talk per NPC, MB: %s; disk of the six new folders %.1f MB" % [", ".join(parts), disk_mb])
	t.check("vram_budget", bad.is_empty() and disk_mb < 9.0, "resident S3TC+mipmaps of idle walk/hover talk about 9 MB per NPC (%s; P21's villager bear_guard %.1f MB), the six new folders take %.1f MB on disk (budget about 7 + slack) %s" % [", ".join(parts), _mb(guard), disk_mb, str(bad.slice(0, 3))])


# ---------------------------------------------------------------- the honest README, the review sheets, the town name, the doc-drift guard

func _docs(t) -> void:
	var text := FileAccess.get_file_as_string(README) if FileAccess.file_exists(README) else ""
	_review_sheets(t, text)
	var need := ["soft CG render", "upright", "presentation pose", "hostile bat", "ugleoje", "banana", "scarf", "Sofus", "the one new body", "ink outline", "not adopted", "install-restyles", "Codex", "Accepted", "known weaknesses", "contact sheet", "formskitse"]
	var missing: Array[String] = []
	for w in need:
		if not (w.to_lower() in text.to_lower()):
			missing.append(w)
	t.check("readme_has_the_honest_notes", text.length() > 3000 and missing.is_empty(), "tools/art/cast_v2/README.md carries the honest verdict (soft CG renders not flat vector, upright poses = presentation poses, Natteblik and Fru Ugle share their models with the hostile bat / ugleoje, Kiki's banana and Rasmus's scarf not baked, Sofus the one new body, the ink outline not adopted for world sprites, the install order of the restyles, the Codex note); missing %s" % str(missing))
	var old_name := "Fes" + "by"
	var hits: Array[String] = []
	var owned: Array[String] = [README, "res://tools/art/cast_v2/cast_v2_models.py", "res://tools/art/cast_v2/traetoppen_additions.py", "res://tools/art/cast_v2/produce_cast_v2.sh", "res://tools/art/cast_v2/measure_cast_v2.py",
		"res://tools/art/cast_v2/check_shim.py", "res://tools/art/cast_v2/review_v2.py", "res://tools/art/cast_v2/palettes_v2.json", MANIFEST]
	for id in CAST_IDS:
		owned.append(DIR + id + "/animations.json")
	for path in owned:
		if not FileAccess.file_exists(path):
			hits.append("MISSING " + path.get_file())
		elif old_name.to_lower() in FileAccess.get_file_as_string(path).to_lower():
			hits.append(path.get_file())
	t.check("no_old_town_name", hits.is_empty(), "the fairy town is called Hyggebyen: no file of this package uses the old name, and every file the section reads exists %s" % str(hits))
	_docs_match_the_code(t)


func _review_sheets(t, readme: String) -> void:
	var rx := RegEx.new()
	rx.compile("review_v2/([A-Za-z0-9_\\-]+\\.png)")
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
		elif im.get_width() < 300 or im.get_height() < 200:
			problems.append("%s is only %s" % [f, str(im.get_size())])
		if bytes.size() > REVIEW_MAX_BYTES:
			problems.append("%s is %d KB (limit %d KB)" % [f, bytes.size() / 1024, REVIEW_MAX_BYTES / 1024])
	var on_disk: Array[String] = []
	var d := DirAccess.open(REVIEW_DIR)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".png"):
				on_disk.append(f)
	for f in on_disk:
		if not named.has(f):
			problems.append("%s is in review_v2/ but the README does not mention it" % f)
	for need in REVIEW_NEED:
		if not ((need + ".png") in named):
			problems.append("the README names no %s.png" % need)
	if "impl/reports" in readme or ".pongpong-build" in readme:
		problems.append("the README points at files outside the repo (the lead's impl/reports or .pongpong-build)")
	t.check("review_sheets_exist", problems.is_empty() and named.size() >= REVIEW_NEED.size(),
		"%d review_v2/*.png named in tools/art/cast_v2/README.md exist in the repo (%d KB in all, each decodes and is < %d KB): 13 compare_<figure> (sketch | bust | idle S | idle SE), contact_cast_v2, cast_next_to_pack_zoom04 (the real windowed shot), outline_ink_vs_pack; none is left unmentioned %s" % [named.size(), total / 1024, REVIEW_MAX_BYTES / 1024, str(problems.slice(0, 4))])


## Doc-drift guard: every check name listed in the header lines of this file (a line "##   name  name ..." of lower-case identifiers separated by two spaces) is a real t.check name,
## every real check name is listed there, and the description lines mention every check by its full name.
func _docs_match_the_code(t) -> void:
	var src := FileAccess.get_file_as_string("res://tests/sections/art_cast_v2.gd")
	var header := ""
	var listed: Array[String] = []
	var list_rx := RegEx.new()
	list_rx.compile("^[a-z0-9_]+(  +[a-z0-9_]+)*$")
	for line in src.split("\n"):
		if not line.begins_with("##"):
			if header != "":
				break
			continue
		header += line + "\n"
		if line.begins_with("##   "):
			var rest: String = line.substr(5).strip_edges()
			if list_rx.search(rest) != null:
				for tok in rest.split(" ", false):
					listed.append(tok)
	var rx := RegEx.new()
	rx.compile("t\\.check\\(\"([a-z0-9_]+)\"")
	var real: Array[String] = []
	for m in rx.search_all(src):
		if not real.has(m.get_string(1)):
			real.append(m.get_string(1))
	var problems: Array[String] = []
	for w in real:
		if not (w in listed):
			problems.append("check %s is not listed in the header" % w)
		if not ("* " + w + ":") in header:
			problems.append("check %s has no description line in the header" % w)
	for w in listed:
		if not (w in real):
			problems.append("the header lists %s, no such check" % w)
	t.check("docs_match_the_code", problems.is_empty() and listed.size() >= 20 and real.size() == listed.size(), "the header of art_cast_v2.gd lists %d check names, all real (%d t.check names in this file, all listed and described) %s" % [listed.size(), real.size(), str(problems.slice(0, 4))])


# ---------------------------------------------------------------- windowed: the cast next to the pack at game zoom

## [row name, ids]: the pack reference (bear cat rabbit fox fairy) on the left of every row, the eight cast figures after it
const CAST_ROWS := [
	["row_1", ["bear", "cat", "rabbit", "fox", "fairy", "bear_brumme", "bat_natteblik", "hedgehog_pip"]],
	["row_2", ["bear", "cat", "rabbit", "fox", "fairy", "owl_fru_ugle", "capybara_sofus", "fairy_birk_npc"]],
	["row_3", ["bear", "cat", "rabbit", "fox", "fairy", "fairy_shopkeeper", "cat_morfar_mis", "bear_guard"]],
]
const CAST_STEP := Vector2(240.0, 260.0)


func run_windowed(t) -> void:
	_t = t
	for id in CAST_IDS:
		_meta[id] = _json(DIR + id + "/animations.json")
	await _cast(t)


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


func _cast(t) -> void:
	var world: Dictionary = PerfWorld.make_world(t.root, PerfWorld.GAME_ZOOM)
	var objects: Node2D = world["objects"]
	var camera: Camera2D = world["camera"]
	var placed: Array = []           # [id, node, row, col]
	var origin := Vector2(-CAST_STEP.x * 3.5, -CAST_STEP.y * 1.0)
	for r in CAST_ROWS.size():
		var ids: Array = CAST_ROWS[r][1]
		var row_nodes: Array = PerfWorld.place_cast(objects, ids, origin + Vector2(0, CAST_STEP.y * r), Vector2(CAST_STEP.x, 0), ids.size(), PerfWorld.SE, &"idle")
		for c in row_nodes.size():
			placed.append([str(ids[c]), row_nodes[c], r, c])
	camera.position = Vector2(0, 0)
	await t.frames(20)
	var img: Image = await t.capture("cast_zoom04")
	if img == null:
		return
	var k := float(img.get_width()) / float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var ground: Dictionary = t.region_stats(img, Rect2i(int(8 * k), int(8 * k), int(120 * k), int(30 * k)))
	var flat_bad: Array[String] = []
	for entry in placed:
		var vis: Node2D = entry[1]
		var screen: Vector2 = vis.get_global_transform_with_canvas().origin * k
		var s: Dictionary = t.region_stats(img, Rect2i(int(screen.x - 34.0 * k), int(screen.y - 92.0 * k), int(68.0 * k), int(100.0 * k)), 2)
		if not (int(s["distinct"]) > int(ground["distinct"]) + 6 and float(s["luma_std"]) > 0.03):
			flat_bad.append(str(entry[0]))
	# the same cast on a flat colour (shadows hidden) to MEASURE the figure height in rendered pixels
	var ground_node := (world["root"] as Node).get_child(0) as CanvasItem
	var old_clear: Color = RenderingServer.get_default_clear_color()
	var flat := Color(1.0, 0.0, 1.0)
	RenderingServer.set_default_clear_color(flat)
	ground_node.visible = false
	for entry in placed:
		var shadow := (entry[1] as Node).get_node_or_null("Shadow") as CanvasItem
		if shadow != null:
			shadow.visible = false
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
		if heights.has(id2):
			continue
		var screen2: Vector2 = (entry[1] as Node2D).get_global_transform_with_canvas().origin * k
		heights[id2] = _rendered_height(flat_img, screen2, flat, k)
	var ref := 0.0
	for id3 in PACK_REFERENCE:
		ref += float(heights.get(id3, 0.0))
	ref /= float(PACK_REFERENCE.size())
	var bad: Array[String] = []
	var report: Array[String] = []
	for id4 in CAST_IDS:
		var ratio: float = float(heights.get(id4, 0.0)) / maxf(ref, 1.0)
		report.append("%s %d%%" % [id4, int(round(ratio * 100.0))])
		if absf(ratio - 1.0) > HEIGHT_TOLERANCE:
			bad.append("%s %.0f px = %d%% of %.0f" % [id4, float(heights.get(id4, 0.0)), int(round(ratio * 100.0)), ref])
	t.check("windowed_cast_shot", bad.is_empty() and ref > 40.0 and flat_bad.is_empty(),
		"the eight cast figures next to the pack's bear cat rabbit fox fairy on grass at zoom 0.4 (art_cast_v2_cast_zoom04.png): every figure has pixels (flat: %s); rendered height: the pack %.0f px, the cast within +/-%d%% (%s) %s" % [str(flat_bad), ref, int(HEIGHT_TOLERANCE * 100.0), ", ".join(report), str(bad)])
	# a close-up at about the dialogue scale for the human: the row of the six new figures
	camera.zoom = Vector2(0.9, 0.9)
	camera.position = origin + Vector2(CAST_STEP.x * 6.5, CAST_STEP.y * 1.0 - 95.0)
	await t.frames(6)
	await t.capture("cast_closeup_zoom09")
	(world["root"] as Node).queue_free()
	await t.frames(2)
