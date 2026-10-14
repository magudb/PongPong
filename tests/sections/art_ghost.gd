extends RefCounted
## Section art_ghost (package G-ghost-art, wave 3b): the two ghost heroes Bu and Hviske (assets/isometric_characters/ghost_bu, ghost_hviske) as the game loads them,
## and the tools that built them (tools/art/ghost), against the art contract of plan 6.2 and the ghost addendum (docs/design/GHOST_ADDENDUM.md, section 10).
##
## Headless (tests/run_playtest.sh --only=art_ghost --no-boot; needs the project imported: the sheets are S3TC textures; the Python checks need tools/art/.venv):
##   builders_resolve  hook_leaves_other_characters_byte_identical  animations_json_is_the_ghost_family  sheets_valid  import_stubs_s3tc  vram_budget
##   heights_and_pivot  hover_baked_feet_window  palette_within_de  silhouette_shared_outside_the_face_band  portraits_are_busts  manifest_rows
##   game_loads_both_heroes  measure_ghost_agrees  review_sheets_exist_and_readme_names_them  readme_verdict_and_honest_notes  no_old_town_name  docs_match_the_code
## Windowed (tests/run_playtest.sh --windowed --only=art_ghost, through tools/dev/run_windowed.sh):
##   windowed_cast_shot
## What each one holds the art to:
##  * builders_resolve: the shim tools/art/ghost/traetoppen_additions.py FIRST on PYTHONPATH exposes exactly BUILDERS {ghost_bu, ghost_hviske}, EXTRA_PATTERNS {sheet} and EXTRA_CLIPS {walk, run}
##    to the generator (the listing produce_all.sh makes); both models build into the GLB of the budget (7132 vertices, 13048 triangles, 17 bones: family ghost, no legs, the stock groups);
##    the palette table is the design's (Bu E6EFFF / B9CEF2 / 93BBEE, Hviske F6E7F6 / E2BEE6 / F29DC2); the glide hook is a no-op for a model of another family; A2's plain `import ghost_model` works;
##    produce_ghost.sh refuses any other id.
##  * hook_leaves_other_characters_byte_identical: tools/art/ghost/check_hook.py: the GLBs of the fox, the bat and the fairy are byte-identical in the bare generator, with P21's module and with
##    the shim first; the ghost's own GLB differs with and without the glide hooks (the hook is alive).
##  * animations_json_is_the_ghost_family: family ghost, role player, clip_set full, flyer false, display_scale 1.0, no glow block, the 11 clips (47 frames x 8 directions), no flight clip.
##  * sheets_valid: 11 clip sheets per hero of 256 x frames by 2048, the imported textures decode, no blank cell, no cell cut by its border, and the Python validator
##    tools/art/core/validate_new_assets.py --root assets/isometric_characters ghost_bu ghost_hviske says OK for 11 clips.
##  * import_stubs_s3tc: every sheet has the S3TC stub (compress/mode=2, high_quality=false, mipmaps, fix_alpha_border) and a Godot-assigned uid; portrait.webp is lossless.
##  * vram_budget: S3TC with mipmaps: 32.9 MB per hero with every clip resident (= hobbit_pip's), 12.6 MB for the four warm clips (idle walk run interact).
##  * heights_and_pivot: idle SE = 160 px = 96 % of the pack mean (+/-10 %), the outline is the pack's, x pivot 127.5 +/- 3 and opposed rows mirrored in EVERY frame of every clip.
##  * hover_baked_feet_window: the lowest pixel of every frame of EVERY clip (jump / fall / land / hit / interact included) is inside the upright window 197..216 (measured 206.1 .. 214.2):
##    the bell hovers ~10 px; the checker has teeth (a hem ON the ground, 222 px, fails); the chibi.tscn shadow (118 px) is wider than the figure.
##  * palette_within_de: the dominant colour of the idle S frame is within CIEDE2000 <= 6 of the declared sheet hex (measured 1.3 / 1.1) and the two heroes are told apart.
##  * silhouette_shared_outside_the_face_band: Bu and Hviske are ONE silhouette: <= 0.05 % of the figure pixels differ and none below the neck line y 130; at least 10 % have visibly different RGB palettes. Exact alpha equality is valid.
##  * portraits_are_busts: portrait.webp is a 256 x 256 head-and-shoulders bust, not cut at the top or the sides, resolved by P07's TTPortraits.
##  * manifest_rows: manifest_traetoppen.json carries the rows of both heroes (SE-G2: merged by the installer).
##  * game_loads_both_heroes: IsoChibiSprite2D.create(id) resolves to the folder itself (no stand-in), family ghost, role player, not a flyer, display_scale 1, no glow, 11 clips, a 256 portrait.
##  * measure_ghost_agrees: tools/art/ghost/measure_ghost.py --check and --selftest exit 0 on the installed assets.
##  * review_sheets_exist_and_readme_names_them: tools/art/ghost/README.md names the review sheets in tools/art/ghost/review/ (contact_sheet_ghost.png, gamezoom_check.png, sketch_vs_baked.png), they exist, decode
##    and are small, and none is left unmentioned.
##  * readme_verdict_and_honest_notes: the README carries the honest notes (soft CG render, dark eyes without sclera, the glide, the egg + wisp back rows, ONE silhouette, the rejected translucent hem, no baked glow,
##    the hover), the verdict log row and the Codex note.
##  * no_old_town_name: the fairy town is Hyggebyen: no file of this package uses the old name, and every file the section reads exists.
##  * docs_match_the_code: this header lists every check of the file by its full name and describes it.
##  * windowed_cast_shot: the cast (fox, hobbit_pip, fairy, ghost_bu, ghost_hviske on the iso fixture ground; zoom 0.4, 0.9 and night 23:00) is written for the human (art_ghost_cast_*.png), the rendered
##    height of the ghost is within 10 % of the fox's, two dark eyes are drawn in the zoom 0.9 face and the white / pink figures stay clearly different from the ground at night (the night grade tints them blue-violet).
const SECTION := "art_ghost"
const TIMEOUT_S := 420.0

const Portraits := preload("res://scripts/ui/theme/tt_portraits.gd")
const PerfWorld := preload("res://tests/perf_world.gd")

const DIR := "res://assets/isometric_characters/"
const MANIFEST := "res://assets/isometric_characters/manifest_traetoppen.json"
const README := "res://tools/art/ghost/README.md"
const REVIEW_DIR := "res://tools/art/ghost/review/"
const REVIEW_MAX_BYTES := 900000
const IDS: Array[String] = ["ghost_bu", "ghost_hviske"]
const HEX := {"ghost_bu": "E6EFFF", "ghost_hviske": "F6E7F6"}
const CELL := 256
const SHEET_H := 2048
const PIVOT := [128, 200]
const DIRECTIONS := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
const SPRITE_ALPHA := 24
const PACK_REFERENCE: Array[String] = ["bear", "cat", "rabbit", "fox", "fairy"]
const HEIGHT_TOLERANCE := 0.10
const OUTLINE_TOLERANCE := 8
const DE_GATE := 6.0
## the 11 clips of the role `player`: [frames, fps, loop] (artcontract.SPEC) = 47 frames per direction
const CLIPS := {
	"idle": [4, 5, true], "walk": [6, 9, true], "run": [6, 12, true], "jump": [4, 10, false], "fall": [3, 6, true], "land": [3, 11, false],
	"celebrate": [6, 9, false], "interact": [4, 9, false], "hit": [3, 11, false], "sleep": [4, 3, true], "talk": [4, 6, true],
}
const WARM_CLIPS: Array[String] = ["idle", "walk", "run", "interact"]
const FLIGHT_CLIPS: Array[String] = ["takeoff", "hover", "fly", "flight_land"]
## the pivot contract (tools/art/characters/measure_cast.py): x of the 8-row mean of the bbox centres, mirror of opposed rows, the upright feet window
const PIVOT_X_CENTRE := 127.5
const PIVOT_X_TOL := 3.0
const MIRROR_TOL := 5.0
const FEET_WINDOW := [197, 216]
const ROW_FEET_LIMITS := [188, 226]
## budgets of the work order in decimal MB (measured on the imported .ctex: ghost_bu 32.86 MB = hobbit_pip 32.86 MB with mipmaps: S3TC DXT5 is 1 byte per pixel x 4/3 for the mip chain, so the size depends
## on the frame count only).  The order names 12.6 MB for the four warm clips idle walk run interact, but those clips are 20 of the 47 frames = 13.98 MB; 12.6 MB is 18 frames: the gate is the arithmetic of the
## named clips (14.0), the discrepancy is recorded in the README
const VRAM_ALL_MB := 32.9
const VRAM_WARM_MB := 14.0
const VRAM_SLACK := 1.02
const GLB_VERTICES := 7132
const GLB_TRIANGLES := 13048
const GLB_BONES := 17
const NECK_LINE_Y := 130
const SILHOUETTE_MAX_SHARE := 0.0005
const SHADOW_PATH := "res://assets/isometric_characters/shadow.png"
## the windowed cast: the pack's fox, hobbit and fairy next to the two heroes
const CAST_IDS: Array[String] = ["fox", "hobbit_pip", "fairy", "ghost_bu", "ghost_hviske"]
const CAST_MAP := "@id _art_ghost_cast\n@projection iso\n@ambient farm\n@theme farm\n@zone farm\n@ground\n################\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n################\n@objects\n................\n................\n................\n................\n................\n................\n................\n........@.......\n................\n................\n................\n................\n................\n................\n................\n................\n"

var _t
var _meta: Dictionary = {}                # id -> parsed animations.json
var _s3tc_bytes: Dictionary = {}          # id -> imported S3TC bytes of all sheets (with mipmaps)
var _s3tc_warm: Dictionary = {}           # id -> bytes of the four warm clips
var _pivot: Dictionary = {}               # id -> {"problems": [], "frames": int, "sheets": int, "x_min", "x_max", "y_min", "y_max", "row_min", "row_max"}
var _figure_width_max := 0                # widest figure (idle, all rows and frames) in px
var _py := ""


func run(t) -> void:
	_t = t
	for id in IDS:
		_meta[id] = _json(DIR + id + "/animations.json")
	_py = _python()
	_builders(t)
	_hook(t)
	_animations_json(t)
	_scan_sheets(t)
	_import_stubs(t)
	_vram(t)
	_heights_and_pivot(t)
	_hover(t)
	_palette(t)
	_silhouette(t)
	_portraits(t)
	_manifest(t)
	await _game_loads(t)
	_measure_agrees(t)
	_docs(t)


# ---------------------------------------------------------------- helpers

func _python() -> String:
	if FileAccess.file_exists("res://tools/art/.venv/bin/python"):
		return ProjectSettings.globalize_path("res://tools/art/.venv/bin/python")
	return ""


func _abs(res_path: String) -> String:
	return ProjectSettings.globalize_path(res_path)


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
	return bytes / 1000000.0


## The imported (S3TC) sheet of one clip, decompressed to RGBA8, plus the compressed byte size; {} when it is not imported.
func _imported(path: String) -> Dictionary:
	var tex := load(path) as Texture2D
	if tex == null:
		return {}
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return {}
	var out := {"width": tex.get_width(), "height": tex.get_height(), "compressed": img.is_compressed(), "format": img.get_format(), "bytes": img.get_data().size()}
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	out["image"] = img
	return out


## Runs a Python tool of the art venv: {code, output, lines}; code -1 and an explanatory output when the venv is missing.
func _run_py(args: PackedStringArray) -> Dictionary:
	if _py == "":
		return {"code": -1, "output": "tools/art/.venv/bin/python not found (tools/art/setup_env.sh)", "lines": PackedStringArray()}
	var with_flags := PackedStringArray(["-B"])        # no __pycache__ in the folders of other packages
	with_flags.append_array(args)
	return _t.run_tool(_py, with_flags)


func _last_line(res: Dictionary) -> String:
	var lines: PackedStringArray = res.get("lines", PackedStringArray())
	return lines[lines.size() - 1] if lines.size() > 0 else str(res.get("output", ""))


# ---------------------------------------------------------------- the builders (task 1 and 2)

func _builders(t) -> void:
	if _py == "":
		t.skip("art_ghost.builders_resolve: tools/art/.venv is missing (tools/art/setup_env.sh builds it): the model / shim / script checks of G-ghost-art are Python checks")
		return
	var ghost := _abs("res://tools/art/ghost")
	var generator := _abs("res://tools/art/generator")
	var core := _abs("res://tools/art/core")
	var characters := _abs("res://tools/art/characters")
	# 1. what produce_all.sh lists with the shim FIRST on PYTHONPATH (the very snippet of its characters slice)
	var code := "\n".join([
		"import sys, json",
		"sys.dont_write_bytecode = True",
		"sys.path[:0] = ['%s', '%s', '%s', '%s']" % [ghost, generator, core, characters],
		"import build_assets as b, ghost_model as g, artpaths, shutil",
		"out = {'listing': sorted(b.TT_BUILDERS), 'patterns': sorted(b.EXTRA_PATTERNS), 'clips': sorted(b.EXTRA_CLIPS), 'module': b.TT_BUILDERS['ghost_bu'].__module__}",
		"models = {}",
		"work = artpaths.stage_root() / 'ghost_builder_check'",
		"for cid in ('ghost_bu', 'ghost_hviske'):",
		"    m = b.TT_BUILDERS[cid]()",
		"    st = b.export(m, work)",
		"    models[cid] = {'name': m.name, 'slug': m.slug, 'clip_set': m.clip_set, 'height': m.height, 'verts': st['vertices'], 'tris': st['triangles'], 'bones': st['bones'], 'groups': sorted(gr.name for gr in m.groups if gr.name not in ('Ghost', 'Motion')),",
		"                   'legs': [gr.name for gr in m.groups if gr.name.startswith(('Foot_', 'HindFoot_'))], 'patterns': sorted(set(m.patterns.values())), 'palette': {k: m.palette[k] for k in ('body', 'sheet_dark', 'hem', 'cheek', 'eye')}}",
		"shutil.rmtree(work, ignore_errors=True)",
		"out['models'] = models",
		"out['table'] = {h: g.HERO_PALETTE[h] for h in g.HERO_PALETTE}",
		"out['ids'] = list(g.GHOST_IDS)",
		"class Fox: name = 'fox'",
		"import numpy as np",
		"q = np.zeros((4, 3, 3)); tr = np.zeros((4, 3, 3)); sc = np.ones((4, 3, 3))",
		"before = (q.copy(), tr.copy(), sc.copy())",
		"for hook in g.GHOST_CLIP_HOOKS.values(): hook(Fox(), None, None, 1.0, None, q, tr, sc)",
		"out['hook_noop'] = bool((q == before[0]).all() and (tr == before[1]).all() and (sc == before[2]).all())",
		"print('RESULT ' + json.dumps(out))",
	])
	var res: Dictionary = _run_py(PackedStringArray(["-I", "-c", code]))
	var line := ""
	for l in res["lines"]:
		if str(l).begins_with("RESULT "):
			line = str(l).substr(7)
	var data: Variant = JSON.parse_string(line) if line != "" else null
	if int(res["code"]) != 0 or not (data is Dictionary):
		t.check("builders_resolve", false, "python could not load the shim / ghost_model (exit %s): %s" % [str(res["code"]), str(res["output"]).substr(0, 400)])
		return
	var d: Dictionary = data
	var problems: Array[String] = []
	if d["listing"] != ["ghost_bu", "ghost_hviske"]:
		problems.append("build_assets.TT_BUILDERS with the shim first = %s (want exactly ghost_bu, ghost_hviske: the listing produce_all.sh --stage-only builds)" % str(d["listing"]))
	if d["patterns"] != ["sheet"] or d["clips"] != ["run", "walk"]:
		problems.append("EXTRA_PATTERNS %s / EXTRA_CLIPS %s (want [sheet] / [run, walk])" % [str(d["patterns"]), str(d["clips"])])
	if str(d["module"]) != "ghost_model":
		problems.append("the shim's builders come from module %s (want ghost_model)" % str(d["module"]))
	var want_groups := ["Arm_L", "Arm_R", "Body", "Eye_L", "Eye_R", "Head", "Tail"]
	var models: Dictionary = d["models"]
	for id in IDS:
		var m: Dictionary = models[id]
		if m["name"] != "ghost" or m["slug"] != id or m["clip_set"] != "full" or float(m["height"]) != 1.92:
			problems.append("%s: family %s slug %s clip_set %s height %s (want ghost / %s / full / 1.92)" % [id, m["name"], m["slug"], m["clip_set"], str(m["height"]), id])
		if int(m["verts"]) != GLB_VERTICES or int(m["tris"]) != GLB_TRIANGLES or int(m["bones"]) != GLB_BONES:
			problems.append("%s: GLB %d vertices %d triangles %d bones (budget %d / %d / %d)" % [id, int(m["verts"]), int(m["tris"]), int(m["bones"]), GLB_VERTICES, GLB_TRIANGLES, GLB_BONES])
		if m["groups"] != want_groups or not (m["legs"] as Array).is_empty():
			problems.append("%s: groups %s legs %s (want the stock groups %s and no legs)" % [id, str(m["groups"]), str(m["legs"]), str(want_groups)])
		if m["patterns"] != ["sheet"]:
			problems.append("%s: texture patterns %s (a quiet cloth weave 'sheet', no fur strokes)" % [id, str(m["patterns"])])
	var tb: Dictionary = d["table"]
	var bu: Dictionary = tb["bu"]
	var hv: Dictionary = tb["hviske"]
	if str(bu["sheet"]).to_upper() != "E6EFFF" or str(bu["collar"]).to_upper() != "B9CEF2" or str(bu["hem"]).to_upper() != "93BBEE":
		problems.append("palette table Bu %s (want E6EFFF / B9CEF2 / 93BBEE)" % str(bu))
	if str(hv["sheet"]).to_upper() != "F6E7F6" or str(hv["collar"]).to_upper() != "E2BEE6" or str(hv["hem"]).to_upper() != "F29DC2":
		problems.append("palette table Hviske %s (want F6E7F6 / E2BEE6 / F29DC2)" % str(hv))
	if str(hv["blush"]) == str(bu["blush"]):
		problems.append("Hviske has the same blush as Bu (the design: pinker blush)")
	if d["ids"] != IDS or not bool(d["hook_noop"]):
		problems.append("GHOST_IDS %s, glide hook no-op on another family: %s" % [str(d["ids"]), str(d["hook_noop"])])
	# 1b. A2's view: only this folder + the generator on the path (no shim, no P21 module): `import ghost_model` builds both models and the hook is exported
	var a2_code := "\n".join([
		"import sys",
		"sys.dont_write_bytecode = True",
		"sys.path[:0] = ['%s', '%s']" % [ghost, generator],
		"import ghost_model as g",
		"m = g.make_ghost('hviske')",
		"print('A2 ' + m.name + ' ' + m.slug + ' ' + ','.join(sorted(g.GHOST_CLIP_HOOKS)) + ' ' + ','.join(sorted(g.HERO_PALETTE)))",
	])
	var a2: Dictionary = _run_py(PackedStringArray(["-I", "-c", a2_code]))
	if int(a2["code"]) != 0 or not ("A2 ghost ghost_hviske run,walk bu,hviske" in str(a2["output"])):
		problems.append("A2's import of ghost_model (this folder + the generator on PYTHONPATH, nothing else) failed: %s" % str(a2["output"]).substr(0, 200))
	# 2. produce_ghost.sh: parses, and refuses any other character id (it builds exactly the two ghosts)
	var script := _abs("res://tools/art/ghost/produce_ghost.sh")
	var syn: Dictionary = _t.run_tool("/bin/bash", PackedStringArray(["-n", script]))
	if int(syn["code"]) != 0:
		problems.append("produce_ghost.sh does not parse: %s" % str(syn["output"]).substr(0, 200))
	var refuse: Dictionary = _t.run_tool("/bin/bash", PackedStringArray([script, "fox"]))
	if int(refuse["code"]) != 2:
		problems.append("produce_ghost.sh fox exited %s (want 2: it must never build another character)" % str(refuse["code"]))
	t.check("builders_resolve", problems.is_empty(), "shim first on PYTHONPATH -> TT_BUILDERS %s, EXTRA_PATTERNS %s, EXTRA_CLIPS %s; both models build into the GLB of the budget (family ghost, %d vertices each, 13048 triangles, 17 bones, the stock groups, no legs), the palette table is the design's, the glide hook does nothing for another family, A2's plain `import ghost_model` works, produce_ghost.sh refuses other ids %s" % [str(d["listing"]), str(d["patterns"]), str(d["clips"]), int((models["ghost_bu"] as Dictionary)["verts"]), str(problems.slice(0, 4))])


func _hook(t) -> void:
	if _py == "":
		t.skip("art_ghost.hook_leaves_other_characters_byte_identical: tools/art/.venv is missing (tools/art/setup_env.sh)")
		return
	var res: Dictionary = _run_py(PackedStringArray(["-I", _abs("res://tools/art/ghost/check_hook.py")]))
	t.check("hook_leaves_other_characters_byte_identical", int(res["code"]) == 0 and _last_line(res).begins_with("check_hook: OK"),
		"tools/art/ghost/check_hook.py (fox, bat, fairy GLB sha256 in the bare generator / with P21's module / with the shim first; the ghost with and without the glide hooks): exit %s, %s" % [str(res["code"]), _last_line(res).substr(0, 220)])


# ---------------------------------------------------------------- animations.json

func _animations_json(t) -> void:
	var problems: Array[String] = []
	for id in IDS:
		var meta: Dictionary = _meta[id]
		if meta.is_empty():
			problems.append("%s: no animations.json" % id)
			continue
		if str(meta.get("family", "")) != "ghost":
			problems.append("%s family %s" % [id, str(meta.get("family", ""))])
		if bool(meta.get("flyer", true)):
			problems.append("%s is flagged a flyer" % id)
		if float(meta.get("display_scale", 0.0)) != 1.0:
			problems.append("%s display_scale %s" % [id, str(meta.get("display_scale", "?"))])
		if meta.has("glow"):
			problems.append("%s has a glow block (no baked glow: a baked halo is darkened by the night grade, the glow is a light of G-ghost-play)" % id)
		if str(meta.get("role", "")) != "player" or str(meta.get("clip_set", "")) != "full" or str(meta.get("portrait", "")) != "portrait.webp":
			problems.append("%s role %s clip_set %s portrait %s" % [id, str(meta.get("role", "")), str(meta.get("clip_set", "")), str(meta.get("portrait", ""))])
		if _ints(meta.get("cell_size", [])) != [CELL, CELL] or _ints(meta.get("pivot", [])) != PIVOT or meta.get("directions", []) != DIRECTIONS:
			problems.append("%s cell / pivot / directions %s %s %s" % [id, str(meta.get("cell_size", "?")), str(meta.get("pivot", "?")), str(meta.get("directions", "?"))])
		var anims: Dictionary = meta.get("animations", {})
		var got: Array = anims.keys()
		got.sort()
		var want: Array = CLIPS.keys()
		want.sort()
		if got != want:
			problems.append("%s clips %s (want the 11 clips of a player, NO flight clips: the ghost is not a flyer)" % [id, str(got)])
		var frames := 0
		for clip in CLIPS.keys():
			if not anims.has(clip):
				continue
			var spec: Array = CLIPS[clip]
			var a: Dictionary = anims[clip]
			frames += int(a.get("frames", 0))
			if int(a.get("frames", 0)) != int(spec[0]) or int(a.get("fps", 0)) != int(spec[1]) or bool(a.get("loop", not bool(spec[2]))) != bool(spec[2]) or str(a.get("sheet", "")) != clip + ".webp":
				problems.append("%s/%s frames/fps/loop/sheet %s want %s" % [id, clip, str(a), str(spec)])
		if frames != 47:
			problems.append("%s has %d frames per direction (want 47)" % [id, frames])
	t.check("animations_json_is_the_ghost_family", problems.is_empty(), "animations.json of ghost_bu and ghost_hviske: family ghost, role player, clip_set full, flyer false, display_scale 1.0, no glow block, cell 256 pivot [128,200], the 11 clips (47 frames x 8 directions) with their frames / fps / loop %s" % str(problems.slice(0, 4)))


# ---------------------------------------------------------------- the sheets: size, imported S3TC texture, cells

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


func _line_opaque(cell: Image, fixed: int, from: int, to: int, horizontal: bool) -> bool:
	for i in range(from, to + 1):
		var c: Color = cell.get_pixel(i, fixed) if horizontal else cell.get_pixel(fixed, i)
		if int(round(c.a * 255.0)) > SPRITE_ALPHA:
			return true
	return false


func _cut_by_border(data: PackedByteArray) -> bool:
	for i in CELL:
		if int(data[(i) * 4 + 3]) > SPRITE_ALPHA or int(data[((CELL - 1) * CELL + i) * 4 + 3]) > SPRITE_ALPHA or int(data[(i * CELL) * 4 + 3]) > SPRITE_ALPHA or int(data[(i * CELL + CELL - 1) * 4 + 3]) > SPRITE_ALPHA:
			return true
	return false


func _row_boxes(sheet: Image, frame: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for row in 8:
		out.append(_alpha_bbox(sheet.get_region(Rect2i(frame * CELL, row * CELL, CELL, CELL))))
	return out


## Problems of one frame (8 row boxes) against the pivot contract (measure_cast.pivot_problems, class upright); y = the feet window of EVERY clip.
func _pivot_problems(boxes: Array[Rect2i], check_y: bool) -> Array[String]:
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
		if mean_bottom < float(FEET_WINDOW[0]) or mean_bottom > float(FEET_WINDOW[1]):
			out.append("feet line %.1f outside %d..%d (upright, pivot y %d)" % [mean_bottom, int(FEET_WINDOW[0]), int(FEET_WINDOW[1]), PIVOT[1]])
		var bad: Array[String] = []
		for i in 8:
			var bottom: int = boxes[i].end.y - 1
			if bottom < int(ROW_FEET_LIMITS[0]) or bottom > int(ROW_FEET_LIMITS[1]):
				bad.append("%s:%d" % [DIRECTIONS[i], bottom])
		if not bad.is_empty():
			out.append("lowest pixel of row(s) %s outside %d..%d" % [" ".join(bad), int(ROW_FEET_LIMITS[0]), int(ROW_FEET_LIMITS[1])])
	return out


func _pivot_measure(id: String, clip: String, sheet: Image, frames: int) -> void:
	var rec: Dictionary = _pivot.get(id, {"problems": [], "sheets": 0, "frames": 0, "x_min": 1.0e9, "x_max": -1.0e9, "y_min": 1.0e9, "y_max": -1.0e9, "row_min": 1000, "row_max": -1000})
	rec["sheets"] = int(rec["sheets"]) + 1
	for f in frames:
		var boxes: Array[Rect2i] = _row_boxes(sheet, f)
		rec["frames"] = int(rec["frames"]) + 1
		var all_there := true
		var mx := 0.0
		var my := 0.0
		for b in boxes:
			if b.size == Vector2i.ZERO:
				all_there = false
				break
			mx += (float(b.position.x) + float(b.end.x - 1)) / 16.0
			my += float(b.end.y - 1) / 8.0
			rec["row_min"] = mini(int(rec["row_min"]), b.end.y - 1)
			rec["row_max"] = maxi(int(rec["row_max"]), b.end.y - 1)
			if clip == "idle":
				_figure_width_max = maxi(_figure_width_max, b.size.x)
		if all_there:
			rec["x_min"] = minf(float(rec["x_min"]), mx)
			rec["x_max"] = maxf(float(rec["x_max"]), mx)
			rec["y_min"] = minf(float(rec["y_min"]), my)
			rec["y_max"] = maxf(float(rec["y_max"]), my)
		for pr in _pivot_problems(boxes, true):
			if (rec["problems"] as Array).size() < 6:
				(rec["problems"] as Array).append("%s f%d: %s" % [clip, f, pr])
	_pivot[id] = rec


func _scan_sheets(t) -> void:
	var t0 := Time.get_ticks_msec()
	var size_bad: Array[String] = []
	var cell_bad: Array[String] = []
	var format_bad: Array[String] = []
	var cells := 0
	var sheets := 0
	_pivot.clear()
	for id in IDS:
		var anims: Dictionary = (_meta[id] as Dictionary).get("animations", {})
		var id_bytes := 0.0
		var warm_bytes := 0.0
		for clip in anims.keys():
			var frames := int((anims[clip] as Dictionary).get("frames", 0))
			var path: String = DIR + id + "/" + clip + ".webp"
			sheets += 1
			var hs := _webp_size(path)
			if hs != Vector2i(CELL * frames, SHEET_H):
				size_bad.append("%s/%s header %s want %s" % [id, clip, str(hs), str(Vector2i(CELL * frames, SHEET_H))])
				continue
			var imp := _imported(path)
			if imp.is_empty():
				size_bad.append("%s/%s: not imported (no texture): run godot --import" % [id, clip])
				continue
			if int(imp["width"]) != CELL * frames or int(imp["height"]) != SHEET_H:
				size_bad.append("%s/%s texture %dx%d" % [id, clip, int(imp["width"]), int(imp["height"])])
				continue
			if not bool(imp["compressed"]) or not (int(imp["format"]) in [Image.FORMAT_DXT1, Image.FORMAT_DXT3, Image.FORMAT_DXT5, Image.FORMAT_RGTC_RG]):
				format_bad.append("%s/%s format %d" % [id, clip, int(imp["format"])])
			id_bytes += float(imp["bytes"])
			if clip in WARM_CLIPS:
				warm_bytes += float(imp["bytes"])
			var gpu: Image = imp["image"]
			_pivot_measure(id, str(clip), gpu, frames)
			for row in 8:
				for f in frames:
					cells += 1
					var cell := gpu.get_region(Rect2i(f * CELL, row * CELL, CELL, CELL))
					if cell.is_invisible():
						cell_bad.append("%s/%s row %d frame %d blank" % [id, clip, row, f])
						continue
					if _cut_by_border(cell.get_data()) and cell_bad.size() < 30:
						cell_bad.append("%s/%s row %d frame %d touches the cell border" % [id, clip, row, f])
		_s3tc_bytes[id] = id_bytes
		_s3tc_warm[id] = warm_bytes
	var py_ok := true
	var py_line := "python validator skipped (tools/art/.venv missing)"
	if _py != "":
		var res: Dictionary = _run_py(PackedStringArray([_abs("res://tools/art/core/validate_new_assets.py"), "--root", _abs("res://assets/isometric_characters"), "ghost_bu", "ghost_hviske"]))
		py_ok = int(res["code"]) == 0 and str(res["output"]).count("clips 11") == 2 and str(res["output"]).count("OK ") >= 2
		py_line = "validate_new_assets.py: %s" % _last_line(res)
	else:
		t.skip("art_ghost.sheets_valid (python half): tools/art/.venv is missing, only the in-game half ran")
	t.check("sheets_valid", size_bad.is_empty() and cell_bad.is_empty() and format_bad.is_empty() and sheets == 22 and cells == 2 * 47 * 8 and py_ok,
		"%d sheets of 2 heroes (11 clips each): WebP header = import size = 256 x frames by 2048, S3TC textures decode, %d cells (47 frames x 8 directions per hero), none blank, none cut by its border; %s (scan %.1f s) %s %s %s" % [sheets, cells, py_line, float(Time.get_ticks_msec() - t0) / 1000.0, str(size_bad.slice(0, 3)), str(cell_bad.slice(0, 3)), str(format_bad.slice(0, 3))])


func _param(text: String, key: String) -> String:
	var rx := RegEx.new()
	rx.compile("(?m)^" + key + "=(.+)$")
	var m := rx.search(text)
	return m.get_string(1).strip_edges() if m != null else ""


func _import_stubs(t) -> void:
	var bad: Array[String] = []
	var n := 0
	for id in IDS:
		for clip in CLIPS.keys():
			n += 1
			var imp: String = DIR + id + "/" + str(clip) + ".webp.import"
			if not FileAccess.file_exists(imp):
				bad.append("%s/%s: no .import" % [id, clip])
				continue
			var text := FileAccess.get_file_as_string(imp)
			if _param(text, "compress/mode") != "2" or _param(text, "compress/high_quality") != "false" or _param(text, "mipmaps/generate") != "true" or _param(text, "process/fix_alpha_border") != "true":
				bad.append("%s/%s: compress/mode %s high_quality %s mipmaps %s fix_alpha_border %s" % [id, clip, _param(text, "compress/mode"), _param(text, "compress/high_quality"), _param(text, "mipmaps/generate"), _param(text, "process/fix_alpha_border")])
			if not ("path.s3tc=" in text) or not ("uid://" in text):
				bad.append("%s/%s: not imported as S3TC / no Godot-assigned uid (run godot --import and tools/pull_meta.sh)" % [id, clip])
		var pimp: String = DIR + id + "/portrait.webp.import"
		var ptext := FileAccess.get_file_as_string(pimp) if FileAccess.file_exists(pimp) else ""
		if ptext == "" or _param(ptext, "compress/mode") == "2" or "path.s3tc=" in ptext:
			bad.append("%s/portrait.webp: must be a lossless import (project default), got %s" % [id, "no .import" if ptext == "" else "compress/mode " + _param(ptext, "compress/mode")])
	t.check("import_stubs_s3tc", bad.is_empty() and n == 22, "%d sheet stubs: S3TC (compress/mode=2, high_quality=false), mipmaps on, fix_alpha_border on (the translucent-edge fix of the exporter), imported as path.s3tc with a Godot-assigned uid; portrait.webp lossless %s" % [n, str(bad.slice(0, 4))])


func _vram(t) -> void:
	var hobbit := 0.0
	for clip in CLIPS.keys():
		var imp := _imported(DIR + "hobbit_pip/" + str(clip) + ".webp")
		hobbit += float(imp.get("bytes", 0))
	var parts: Array[String] = []
	var bad: Array[String] = []
	for id in IDS:
		var all_mb := _mb(float(_s3tc_bytes.get(id, 0.0)))
		var warm_mb := _mb(float(_s3tc_warm.get(id, 0.0)))
		parts.append("%s %.2f MB (warm %.2f)" % [id, all_mb, warm_mb])
		if all_mb > VRAM_ALL_MB * VRAM_SLACK or all_mb < 20.0:
			bad.append("%s %.2f MB of S3TC with every clip resident (budget %.1f)" % [id, all_mb, VRAM_ALL_MB])
		if warm_mb > VRAM_WARM_MB * VRAM_SLACK:
			bad.append("%s %.2f MB for the four warm clips (budget %.1f)" % [id, warm_mb, VRAM_WARM_MB])
		if hobbit > 0.0 and absf(all_mb - _mb(hobbit)) / _mb(hobbit) > 0.03:
			bad.append("%s differs from hobbit_pip's %.2f MB by more than 3 %%" % [id, _mb(hobbit)])
	t.info("VRAM S3TC + mipmaps, every clip resident: %s; hobbit_pip %.2f MB (the budget of the world does not change: a save plays ONE hero)" % [", ".join(parts), _mb(hobbit)])
	t.check("vram_budget", bad.is_empty() and hobbit > 0.0, "S3TC with mipmaps per hero: %s <= %.1f MB with every clip resident (= the hobbit's %.2f MB), the four warm clips (idle walk run interact: 20 of 47 frames) <= %.1f MB (the order says 12.6, which is 18 frames) %s" % [", ".join(parts), VRAM_ALL_MB, _mb(hobbit), VRAM_WARM_MB, str(bad)])


# ---------------------------------------------------------------- heights, outline, pivot, hover

## bbox height (alpha > 24) of the idle SE frame 0 and the mean outline colour of the isolated outline pixels (alpha 130..150 next to a clear pixel) of the RAW WebP: the rule of
## tools/art/characters/measure_cast.py and of art_characters.figure_heights_match_pack (independent of the import state)
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


func _heights_and_pivot(t) -> void:
	var heights: Array[float] = []
	var out_sum := Vector3.ZERO
	var out_n := 0
	for id in PACK_REFERENCE:
		var f := _figure(id)
		if f.is_empty():
			continue
		heights.append(float(f["height"]))
		if (f["outline"] as Vector3).x >= 0.0:
			out_sum += f["outline"]
			out_n += 1
	var mean := 0.0
	for h in heights:
		mean += h
	mean /= maxf(float(heights.size()), 1.0)
	var pack_out: Vector3 = out_sum / maxf(float(out_n), 1.0)
	var bad: Array[String] = []
	var report: Array[String] = []
	for id in IDS:
		var f := _figure(id)
		if f.is_empty():
			bad.append("%s: no idle sheet" % id)
			continue
		var ratio: float = float(f["height"]) / mean
		report.append("%s %d px = %d%%" % [id, int(f["height"]), int(round(ratio * 100.0))])
		if absf(ratio - 1.0) > HEIGHT_TOLERANCE:
			bad.append("%s %d px = %d%% of the pack mean %.1f px (limit +/-10%%)" % [id, int(f["height"]), int(round(ratio * 100.0)), mean])
		var oc: Vector3 = f["outline"]
		if oc.x < 0.0 or absf(oc.x - pack_out.x) > OUTLINE_TOLERANCE or absf(oc.y - pack_out.y) > OUTLINE_TOLERANCE or absf(oc.z - pack_out.z) > OUTLINE_TOLERANCE:
			bad.append("%s outline %s vs pack %s" % [id, str(oc.round()), str(pack_out.round())])
		var rec: Dictionary = _pivot.get(id, {})
		if rec.is_empty() or int(rec["frames"]) != 47:
			bad.append("%s: pivot scan saw %s frames (want 47)" % [id, str(rec.get("frames", 0))])
			continue
		for pr in rec["problems"]:
			if not ("feet line" in str(pr)) and not ("lowest pixel" in str(pr)):
				bad.append("%s %s" % [id, str(pr)])
	var xs := ""
	for id in IDS:
		var r: Dictionary = _pivot.get(id, {})
		if not r.is_empty():
			xs += "%s x %.1f..%.1f " % [id, float(r["x_min"]), float(r["x_max"])]
	t.check("heights_and_pivot", bad.is_empty() and heights.size() == PACK_REFERENCE.size(),
		"idle SE height %s of the pack mean %.1f px (bear cat rabbit fox fairy; gate +/-10 %%), outline = the pack's %s (+/-%d), every frame of every clip stands on the pivot x: the 8-row mean of the bbox centres %s(want %.1f +/- %d), opposed rows mirrored (+/-%d) %s" % [", ".join(report), mean, str(pack_out.round()), OUTLINE_TOLERANCE, xs, PIVOT_X_CENTRE, int(PIVOT_X_TOL), int(MIRROR_TOL), str(bad.slice(0, 4))])


## A synthetic 8-row sheet whose figure's lowest opaque pixel is exactly `lowest` (a block 80 px wide centred on the pivot).
func _synthetic_sheet(lowest: int, dx: int) -> Image:
	var im := Image.create(CELL, CELL * 8, false, Image.FORMAT_RGBA8)
	for row in 8:
		im.fill_rect(Rect2i(128 + dx - 40, row * CELL + lowest - 120, 80, 121), Color(1, 1, 1, 1))
	return im


func _hover(t) -> void:
	var bad: Array[String] = []
	var lines: Array[String] = []
	var lo_all := 1.0e9
	var hi_all := -1.0e9
	for id in IDS:
		var rec: Dictionary = _pivot.get(id, {})
		if rec.is_empty():
			bad.append("%s: no pivot scan" % id)
			continue
		for pr in rec["problems"]:
			if ("feet line" in str(pr)) or ("lowest pixel" in str(pr)):
				bad.append("%s %s" % [id, str(pr)])
		lines.append("%s %.1f..%.1f (rows %d..%d)" % [id, float(rec["y_min"]), float(rec["y_max"]), int(rec["row_min"]), int(rec["row_max"])])
		lo_all = minf(lo_all, float(rec["y_min"]))
		hi_all = maxf(hi_all, float(rec["y_max"]))
	# the hem hovers: the lowest pixel is clearly ABOVE the 222 px that a bell standing on the ground reaches (and not floating off the pivot either)
	var hover_ok := hi_all <= 215.0 and lo_all >= 203.0
	# the checker has teeth: a hem on the ground (222), the first small hover (217) and a floating figure (190) are all flagged; the design's 214 passes
	var teeth: Array[String] = []
	for case in [[222, true], [217, true], [190, true], [214, false], [210, false]]:
		var flagged := not _pivot_problems(_row_boxes(_synthetic_sheet(int(case[0]), 0), 0), true).is_empty()
		if flagged != bool(case[1]):
			teeth.append("lowest pixel %d was %s" % [int(case[0]), "flagged" if flagged else "accepted"])
	if _pivot_problems(_row_boxes(_synthetic_sheet(210, 8), 0), true).is_empty():
		teeth.append("a figure shifted 8 px sideways was accepted")
	var shadow_w := _shadow_visible_width()
	var front_w := _front_width("ghost_bu")
	var shadow_ok := shadow_w > 0 and front_w > 0 and absi(shadow_w - front_w) <= 10
	t.check("hover_baked_feet_window", bad.is_empty() and hover_ok and teeth.is_empty() and shadow_ok,
		"the bell's lowest lobes hover ~10 px above the contract pivot: the lowest pixel (8-row mean, every frame of EVERY clip incl. jump / fall / land / hit / interact) %s inside the upright window %d..%d (measured 206.1..214.2, a hem on the ground gives 222); the checker flags 222 / 217 / 190 and accepts 214 / 210 %s; the chibi.tscn shadow (%d px visible, the order says 118) is as wide as the ghost seen from the front (%d px: bell and mittens; the widest idle row, %d px, includes the wisp) and stays on the floor, so the baked hover gap shows between the hem and its shadow %s" % [", ".join(lines), int(FEET_WINDOW[0]), int(FEET_WINDOW[1]), str(teeth), shadow_w, front_w, _figure_width_max, str(bad.slice(0, 3))])


## Width of the visible shadow ellipse of scenes/isometric/chibi.tscn (alpha > 24 of shadow.png).
func _shadow_visible_width() -> int:
	var tex := load(SHADOW_PATH) as Texture2D
	if tex == null:
		return 0
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var r := img.get_used_rect()
	var x0 := r.end.x
	var x1 := -1
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if int(round(img.get_pixel(x, y).a * 255.0)) > SPRITE_ALPHA:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
	return x1 - x0 + 1 if x1 >= 0 else 0


## Width of the figure of the idle sheet seen from the front (row S, frame 0) in px.
func _front_width(id: String) -> int:
	var im := _decode(DIR + id + "/idle.webp")
	if im == null:
		return 0
	var cell := im.get_region(Rect2i(0, 0, CELL, CELL))
	var x0 := CELL
	var x1 := -1
	var data := cell.get_data()
	for y in CELL:
		for x in CELL:
			if int(data[(y * CELL + x) * 4 + 3]) > SPRITE_ALPHA:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
	return x1 - x0 + 1 if x1 >= 0 else 0


# ---------------------------------------------------------------- palette (CIEDE2000) and the shared silhouette

func _srgb2lab(rgb: Vector3) -> Vector3:
	var c := [rgb.x / 255.0, rgb.y / 255.0, rgb.z / 255.0]
	for i in 3:
		c[i] = c[i] / 12.92 if c[i] <= 0.04045 else pow((c[i] + 0.055) / 1.055, 2.4)
	var x: float = (0.4124564 * c[0] + 0.3575761 * c[1] + 0.1804375 * c[2]) / 0.95047
	var y: float = (0.2126729 * c[0] + 0.7151522 * c[1] + 0.0721750 * c[2]) / 1.0
	var z: float = (0.0193339 * c[0] + 0.1191920 * c[1] + 0.9503041 * c[2]) / 1.08883
	var f := [x, y, z]
	for i in 3:
		f[i] = pow(f[i], 1.0 / 3.0) if f[i] > 0.008856 else 7.787 * f[i] + 16.0 / 116.0
	return Vector3(116.0 * f[1] - 16.0, 500.0 * (f[0] - f[1]), 200.0 * (f[1] - f[2]))


func _de2000(l1: Vector3, l2: Vector3) -> float:
	var c1 := sqrt(l1.y * l1.y + l1.z * l1.z)
	var c2 := sqrt(l2.y * l2.y + l2.z * l2.z)
	var cb := (c1 + c2) / 2.0
	var g := 0.5 * (1.0 - sqrt(pow(cb, 7.0) / (pow(cb, 7.0) + pow(25.0, 7.0))))
	var a1p := (1.0 + g) * l1.y
	var a2p := (1.0 + g) * l2.y
	var c1p := sqrt(a1p * a1p + l1.z * l1.z)
	var c2p := sqrt(a2p * a2p + l2.z * l2.z)
	var h1p := fposmod(rad_to_deg(atan2(l1.z, a1p)), 360.0)
	var h2p := fposmod(rad_to_deg(atan2(l2.z, a2p)), 360.0)
	var dlp := l2.x - l1.x
	var dcp := c2p - c1p
	var dh := h2p - h1p
	if c1p * c2p == 0.0:
		dh = 0.0
	elif dh > 180.0:
		dh -= 360.0
	elif dh < -180.0:
		dh += 360.0
	var dhp := 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(dh / 2.0))
	var lbp := (l1.x + l2.x) / 2.0
	var cbp := (c1p + c2p) / 2.0
	var hs := h1p + h2p
	var hbp := hs
	if c1p * c2p != 0.0:
		if absf(h1p - h2p) <= 180.0:
			hbp = hs / 2.0
		else:
			hbp = (hs + 360.0) / 2.0 if hs < 360.0 else (hs - 360.0) / 2.0
	var tt := 1.0 - 0.17 * cos(deg_to_rad(hbp - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * hbp)) + 0.32 * cos(deg_to_rad(3.0 * hbp + 6.0)) - 0.20 * cos(deg_to_rad(4.0 * hbp - 63.0))
	var dth := 30.0 * exp(-pow((hbp - 275.0) / 25.0, 2.0))
	var rc := 2.0 * sqrt(pow(cbp, 7.0) / (pow(cbp, 7.0) + pow(25.0, 7.0)))
	var sl := 1.0 + 0.015 * pow(lbp - 50.0, 2.0) / sqrt(20.0 + pow(lbp - 50.0, 2.0))
	var sc := 1.0 + 0.045 * cbp
	var sh := 1.0 + 0.015 * cbp * tt
	var rt := -sin(deg_to_rad(2.0 * dth)) * rc
	return sqrt(pow(dlp / sl, 2.0) + pow(dcp / sc, 2.0) + pow(dhp / sh, 2.0) + rt * (dcp / sc) * (dhp / sh))


## The dominant colour of the idle S cell (row 0, frame 0) of the raw WebP: the median RGB of the brightest 45 % of the fully opaque pixels (tools/art/ghost/palette_check.py).
func _dominant(id: String) -> Vector3:
	var img := _decode(DIR + id + "/idle.webp")
	if img == null:
		return Vector3(-1, -1, -1)
	var cell := img.get_region(Rect2i(0, 0, CELL, CELL))
	var data := cell.get_data()
	var lums: Array = []
	var px: Array = []
	for i in CELL * CELL:
		if int(data[i * 4 + 3]) == 255:
			var r := float(data[i * 4])
			var g := float(data[i * 4 + 1])
			var b := float(data[i * 4 + 2])
			lums.append(r * 0.299 + g * 0.587 + b * 0.114)
			px.append(Vector3(r, g, b))
	if px.is_empty():
		return Vector3(-1, -1, -1)
	var sorted_l := lums.duplicate()
	sorted_l.sort()
	# numpy.percentile(lum, 55), linear interpolation
	var pos := 0.55 * float(sorted_l.size() - 1)
	var lo := int(floor(pos))
	var hi := mini(lo + 1, sorted_l.size() - 1)
	var cut: float = float(sorted_l[lo]) + (pos - float(lo)) * (float(sorted_l[hi]) - float(sorted_l[lo]))
	var rs: Array = []
	var gs: Array = []
	var bs: Array = []
	for i in px.size():
		if float(lums[i]) >= cut:
			rs.append((px[i] as Vector3).x)
			gs.append((px[i] as Vector3).y)
			bs.append((px[i] as Vector3).z)
	return Vector3(_median(rs), _median(gs), _median(bs))


func _median(values: Array) -> float:
	values.sort()
	var n := values.size()
	if n == 0:
		return 0.0
	return float(values[n / 2]) if n % 2 == 1 else (float(values[n / 2 - 1]) + float(values[n / 2])) / 2.0


func _palette(t) -> void:
	var bad: Array[String] = []
	var parts: Array[String] = []
	var dom := {}
	for id in IDS:
		var med := _dominant(id)
		dom[id] = med
		if med.x < 0.0:
			bad.append("%s: no idle sheet" % id)
			continue
		var hex: String = HEX[id]
		var want := Vector3(float(hex.substr(0, 2).hex_to_int()), float(hex.substr(2, 2).hex_to_int()), float(hex.substr(4, 2).hex_to_int()))
		var de := _de2000(_srgb2lab(want), _srgb2lab(med))
		parts.append("%s #%s dE00 %.1f" % [id, hex, de])
		if de > DE_GATE:
			bad.append("%s dominant %s vs #%s: dE00 %.1f > %.0f" % [id, str(med.round()), hex, de, DE_GATE])
	var apart := 0.0
	if dom.size() == 2 and (dom["ghost_bu"] as Vector3).x >= 0.0 and (dom["ghost_hviske"] as Vector3).x >= 0.0:
		apart = _de2000(_srgb2lab(dom["ghost_bu"]), _srgb2lab(dom["ghost_hviske"]))
	if apart < 6.0:
		bad.append("Bu and Hviske are only dE00 %.1f apart (they must be told apart at a glance)" % apart)
	# teeth: the same measurement against another hero's hex must fail the gate
	var wrong_hex: Vector3 = Vector3(246, 231, 246)
	var wrong := _de2000(_srgb2lab(wrong_hex), _srgb2lab(dom.get("ghost_bu", Vector3.ZERO)))
	if wrong <= DE_GATE:
		bad.append("the gate has no teeth: Bu measured against Hviske's hex is only dE00 %.1f" % wrong)
	t.check("palette_within_de", bad.is_empty(), "the dominant colour of the idle S frame (median of the brightest 45 %% of the opaque pixels of the raw WebP) is within CIEDE2000 <= %.0f of the declared sheet hex: %s (measured 1.3 / 1.1 on the PNG masters); the heroes are dE00 %.1f apart, Bu against Hviske's hex dE00 %.1f (the gate has teeth) %s" % [DE_GATE, ", ".join(parts), apart, wrong, str(bad.slice(0, 3))])


func _silhouette(t) -> void:
	var diff_px := 0
	var area_px := 0
	var palette_px := 0
	var low_y := -1
	var high_y := 9999
	var t0 := Time.get_ticks_msec()
	var missing: Array[String] = []
	for clip in CLIPS.keys():
		var a := _decode(DIR + "ghost_bu/" + str(clip) + ".webp")
		var b := _decode(DIR + "ghost_hviske/" + str(clip) + ".webp")
		if a == null or b == null or a.get_size() != b.get_size():
			missing.append(str(clip))
			continue
		var da := a.get_data()
		var db := b.get_data()
		var w := a.get_width()
		var n := da.size() / 4
		for i in n:
			var pa := int(da[i * 4 + 3]) > SPRITE_ALPHA
			if pa:
				area_px += 1
				if int(da[i * 4 + 3]) >= 200 and int(db[i * 4 + 3]) >= 200:
					var rgb_delta := maxi(absi(int(da[i * 4]) - int(db[i * 4])), maxi(absi(int(da[i * 4 + 1]) - int(db[i * 4 + 1])), absi(int(da[i * 4 + 2]) - int(db[i * 4 + 2]))))
					if rgb_delta >= 8:
						palette_px += 1
			if pa != (int(db[i * 4 + 3]) > SPRITE_ALPHA):
				diff_px += 1
				var y := (i / w) % CELL
				low_y = maxi(low_y, y)
				high_y = mini(high_y, y)
	var share := float(diff_px) / maxf(float(area_px), 1.0)
	var palette_share := float(palette_px) / maxf(float(area_px), 1.0)
	t.check("silhouette_shared_outside_the_face_band", missing.is_empty() and palette_share >= 0.10 and share <= SILHOUETTE_MAX_SHARE and low_y <= NECK_LINE_Y,
		"Bu and Hviske share the garment silhouette: %d of %d figure pixels differ in alpha = %.3f %% (limit %.2f %%), none below y %d (changed rows %d..%d); %.1f %% have a visible RGB difference (minimum 10 %%, so identical files fail). Exact alpha equality is valid for the drawn palette variants. %s (%.1f s)" % [diff_px, area_px, share * 100.0, SILHOUETTE_MAX_SHARE * 100.0, NECK_LINE_Y, high_y, low_y, palette_share * 100.0, str(missing), float(Time.get_ticks_msec() - t0) / 1000.0])


# ---------------------------------------------------------------- portraits and the manifest

## Problems of one bust: 256 x 256, not blank, not cut at the top or the sides (the bottom is cut at the torso by design), and it really is a bust (it reaches the bottom edge).
func _bust_problems(path: String) -> Array[String]:
	var img := _decode(path)
	if img == null:
		return ["%s: missing or not decodable" % path.get_file()]
	if img.get_size() != Vector2i(CELL, CELL):
		return ["%s is %s" % [path.get_file(), str(img.get_size())]]
	var data := img.get_data()
	var top := false
	var left := false
	var right := false
	var bottom := false
	var any := false
	for i in CELL:
		top = top or int(data[i * 4 + 3]) > SPRITE_ALPHA
		bottom = bottom or int(data[((CELL - 1) * CELL + i) * 4 + 3]) > SPRITE_ALPHA
		left = left or int(data[(i * CELL) * 4 + 3]) > SPRITE_ALPHA
		right = right or int(data[(i * CELL + CELL - 1) * 4 + 3]) > SPRITE_ALPHA
	for i in CELL * CELL:
		if int(data[i * 4 + 3]) > SPRITE_ALPHA:
			any = true
			break
	var out: Array[String] = []
	if not any:
		out.append("%s is blank" % path.get_file())
	if top or left or right:
		var cut: Array[String] = []
		if top:
			cut.append("top")
		if left:
			cut.append("left")
		if right:
			cut.append("right")
		out.append("%s is CUT at the %s" % [path.get_file(), "/".join(cut)])
	if any and not bottom:
		out.append("%s does not reach the bottom edge: a bust is cut at the torso, this is a full-body crop" % path.get_file())
	return out


func _portraits(t) -> void:
	var bad: Array[String] = []
	for id in IDS:
		bad.append_array(_bust_problems(DIR + id + "/portrait.webp"))
		if Portraits.resolve_visual_path([id]) != DIR + id + "/portrait.webp":
			bad.append("TTPortraits resolves %s to %s" % [id, Portraits.resolve_visual_path([id])])
		var tex := Portraits.portrait_by_sprite(id)
		if tex == null or tex.get_width() != CELL or tex.get_height() != CELL:
			bad.append("portrait_by_sprite(%s) is %s" % [id, str(tex)])
	var py_line := "python validator skipped"
	if _py != "":
		var res: Dictionary = _run_py(PackedStringArray([_abs("res://tools/art/core/validate_new_assets.py"), "--root", _abs("res://assets/isometric_characters"), "ghost_bu", "ghost_hviske"]))
		py_line = "validate_new_assets.py (portrait: 256 x 256, not blank, not cut at the top or the sides): exit %s" % str(res["code"])
		if int(res["code"]) != 0:
			bad.append("validate_new_assets.py exit %s: %s" % [str(res["code"]), _last_line(res)])
	t.check("portraits_are_busts", bad.is_empty(), "portrait.webp of both heroes: a 256 x 256 head-and-shoulders bust from the 14 degree camera, reaches the bottom edge (cut at the bell) and never the top or the sides, resolved by P07's TTPortraits to the folder's own portrait; %s %s" % [py_line, str(bad.slice(0, 4))])


func _manifest(t) -> void:
	var man: Dictionary = _json(MANIFEST)
	var chars: Dictionary = man.get("characters", {})
	var problems: Array[String] = []
	for id in IDS:
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
	var keys: Array = chars.keys()
	var sorted_keys := keys.duplicate()
	sorted_keys.sort()
	t.check("manifest_rows", problems.is_empty() and int(man.get("format_version", 0)) == 2 and keys == sorted_keys,
		"manifest_traetoppen.json carries the rows of ghost_bu and ghost_hviske (merged by the installer, SE-G2) equal to their animations.json (role player, family ghost, flyer false, 11 clips); %d rows in all, sorted, format_version 2 %s" % [chars.size(), str(problems.slice(0, 4))])


func _game_loads(t) -> void:
	var host := Node2D.new()
	host.name = "ArtGhostHost"
	t.root.add_child(host)
	var bad: Array[String] = []
	var report: Array[String] = []
	for id in IDS:
		if CharacterCatalog.resolve(id) != id:
			bad.append("CharacterCatalog.resolve(%s) = '%s': the stand-in chain still wins over the art" % [id, CharacterCatalog.resolve(id)])
		var sprite := IsoChibiSprite2D.create(id)
		if sprite == null:
			bad.append("%s: IsoChibiSprite2D.create returned null" % id)
			continue
		host.add_child(sprite)
		sprite.set_direction_index(7)
		await t.frames(2)
		var names := sprite.get_clip_names()
		report.append("%s: %d clips, family %s" % [id, names.size(), sprite.family])
		if sprite.resolved_id != id or sprite.family != "ghost" or sprite.role != "player" or sprite.flyer or sprite.display_scale != 1.0 or not sprite.glow.is_empty() or names.size() != 11:
			bad.append("%s resolved %s family %s role %s flyer %s display_scale %s glow %s clips %d" % [id, sprite.resolved_id, sprite.family, sprite.role, str(sprite.flyer), str(sprite.display_scale), str(sprite.glow), names.size()])
		for clip in CLIPS.keys():
			if not sprite.has_clip(StringName(clip)):
				bad.append("%s has no clip %s" % [id, clip])
				continue
			sprite.play_loop(StringName(clip))
		for clip in FLIGHT_CLIPS:
			if sprite.has_clip(StringName(clip)):
				bad.append("%s has the flight clip %s (the ghost is not a flyer)" % [id, clip])
		await t.frames(2)
		var portrait := sprite.get_portrait()
		if portrait == null or portrait.get_width() != CELL:
			bad.append("%s get_portrait() is %s" % [id, str(portrait)])
		sprite.queue_free()
	host.queue_free()
	await t.frames(1)
	t.check("game_loads_both_heroes", bad.is_empty(), "IsoChibiSprite2D.create(<id>) on the real sheets: resolves to the folder itself (CharacterCatalog.resolve = id, no stand-in), family ghost, role player, not a flyer, display_scale 1, no glow, the 11 clips play, no flight clip, a 256 portrait (%s) %s" % [", ".join(report), str(bad.slice(0, 4))])


func _measure_agrees(t) -> void:
	if _py == "":
		t.skip("art_ghost.measure_ghost_agrees: tools/art/.venv is missing (tools/art/setup_env.sh)")
		return
	var tool := _abs("res://tools/art/ghost/measure_ghost.py")
	var res: Dictionary = _run_py(PackedStringArray(["-I", tool, "--check", "--root", _abs("res://assets/isometric_characters")]))
	var self_res: Dictionary = _run_py(PackedStringArray(["-I", tool, "--selftest"]))
	t.check("measure_ghost_agrees", int(res["code"]) == 0 and int(self_res["code"]) == 0 and "one silhouette" in str(res["output"]),
		"tools/art/ghost/measure_ghost.py --check exit %s (%s), --selftest exit %s (%s)" % [str(res["code"]), _last_line(res).substr(0, 160), str(self_res["code"]), _last_line(self_res).substr(0, 120)])


# ---------------------------------------------------------------- the honest README, the review sheets, the town name, the doc-drift guard

func _docs(t) -> void:
	var text := FileAccess.get_file_as_string(README) if FileAccess.file_exists(README) else ""
	_review_sheets(t, text)
	var need := ["soft CG render", "dark eyes", "no white", "glide", "egg", "wisp", "one silhouette", "translucent hem", "REJECTED", "no baked glow", "hover", "Accepted", "known weaknesses", "contact sheet", "Codex"]
	var missing: Array[String] = []
	for w in need:
		if not (w.to_lower() in text.to_lower()):
			missing.append(w)
	t.check("readme_verdict_and_honest_notes", text.length() > 2500 and missing.is_empty(), "tools/art/ghost/README.md carries the honest notes (soft CG render, the dark eyes without sclera, the glide, the egg + wisp back rows, ONE silhouette, the rejected translucent hem, no baked glow, the hover), the verdict log row and the Codex note; missing %s" % str(missing))
	var old_name := "Fes" + "by"
	var hits: Array[String] = []
	var owned: Array[String] = [README, "res://tools/art/ghost/ghost_model.py", "res://tools/art/ghost/traetoppen_additions.py", "res://tools/art/ghost/produce_ghost.sh", "res://tools/art/ghost/measure_ghost.py",
		"res://tools/art/ghost/check_hook.py", "res://tools/art/ghost/review_sheets.py", "res://tools/art/ghost/palette_check.py", "res://tools/art/ghost/occluder_equality.py", "res://tools/art/ghost/bob_probe.py", "res://tools/art/ghost/hem_fade.py"]
	for id in IDS:
		owned.append(DIR + id + "/animations.json")
	for path in owned:
		if FileAccess.file_exists(path) and old_name.to_lower() in FileAccess.get_file_as_string(path).to_lower():
			hits.append(path.get_file())
		elif not FileAccess.file_exists(path):
			hits.append("MISSING " + path.get_file())
	t.check("no_old_town_name", hits.is_empty(), "the fairy town is called Hyggebyen: no file of this package uses the old name, and every file the section reads exists %s" % str(hits))
	_docs_match_the_code(t)


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
		elif im.get_width() < 400 or im.get_height() < 200:
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
			problems.append("%s is in review/ but the README does not mention it" % f)
	for need in ["contact_sheet_ghost.png", "gamezoom_check.png", "sketch_vs_baked.png"]:
		if not (need in named):
			problems.append("the README names no %s" % need)
	if "impl/reports" in readme or ".pongpong-build" in readme:
		problems.append("the README points at files outside the repo (the lead's impl/reports or .pongpong-build)")
	t.check("review_sheets_exist_and_readme_names_them", problems.is_empty() and named.size() >= 3,
		"%d review/*.png named in tools/art/ghost/README.md exist in the repo (%d KB in all, each decodes and is < %d KB): contact_sheet_ghost (8 directions x 2 heroes, walk / run, 8 other clips, the busts), gamezoom_check (the real windowed shots at zoom 0.4 / 0.9 / night), sketch_vs_baked (the Figurer v2 cards next to the baked roster and the ghost); none is left unmentioned %s" % [named.size(), total / 1024, REVIEW_MAX_BYTES / 1024, str(problems.slice(0, 4))])


## Doc-drift guard: every check name listed in the header lines of this file (a line "##   name  name ..." of lower-case identifiers separated by two spaces) is a real t.check name,
## every real check name is listed there, and the description lines mention every check by its full name.
func _docs_match_the_code(t) -> void:
	var src := FileAccess.get_file_as_string("res://tests/sections/art_ghost.gd")
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
	t.check("docs_match_the_code", problems.is_empty() and listed.size() >= 18 and real.size() == listed.size(), "the header of art_ghost.gd lists %d check names, all real (%d t.check names in this file, all listed and described) %s" % [listed.size(), real.size(), str(problems.slice(0, 4))])


# ---------------------------------------------------------------- windowed: the cast shot (the prototype's gamezoom_check regenerated through the real section)

const CAST_STEP := Vector2(250.0, 255.0)


func run_windowed(t) -> void:
	_t = t
	await _cast_height(t)
	await _cast_shots(t)


## Rendered height of the figure whose feet pivot is at `feet` (image pixels) on the flat colour `bg` (the box of the sheet measurement: hats and tails reach below the pivot).
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


var _heights: Dictionary = {}


## The cast on a flat colour at game zoom 0.4 (the shadow hidden), so that the figure height is MEASURED in rendered pixels.
func _cast_height(t) -> void:
	var world: Dictionary = PerfWorld.make_world(t.root, PerfWorld.GAME_ZOOM)
	var objects: Node2D = world["objects"]
	var camera: Camera2D = world["camera"]
	var origin := Vector2(-CAST_STEP.x * 2.0, 0.0)
	var placed: Array = PerfWorld.place_cast(objects, CAST_IDS, origin, Vector2(CAST_STEP.x, 0.0), CAST_IDS.size(), PerfWorld.SE, &"idle")
	camera.position = Vector2(0, -60)
	var ground_node := (world["root"] as Node).get_child(0) as CanvasItem
	var old_clear: Color = RenderingServer.get_default_clear_color()
	var flat := Color(1.0, 0.0, 1.0)
	RenderingServer.set_default_clear_color(flat)
	ground_node.visible = false
	for vis in placed:
		var shadow := (vis as Node).get_node_or_null("Shadow") as CanvasItem
		if shadow != null:
			shadow.visible = false
	await t.frames(8)
	var img: Image = await t.capture("cast_flat_for_measuring")
	RenderingServer.set_default_clear_color(old_clear)
	if img == null:
		(world["root"] as Node).queue_free()
		return
	var k := float(img.get_width()) / float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	_heights.clear()
	for i in placed.size():
		var vis: Node2D = placed[i]
		var screen: Vector2 = vis.get_global_transform_with_canvas().origin * k
		_heights[CAST_IDS[i]] = _rendered_height(img, screen, flat, k)
	(world["root"] as Node).queue_free()
	await t.frames(2)


func _set_hour(world, hour: float) -> void:
	world.day_night.override_hour = hour
	world.day_night.snap()
	world.area.set_night_factor(world.day_night.glow_factor)


## Dark connected blobs (luma < 0.27) of at least `min_px` pixels inside `rect`: the eyes of the zoom 0.9 face.
func _dark_blobs(img: Image, rect: Rect2i, min_px: int) -> Array[Rect2i]:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var seen := {}
	var blobs: Array[Rect2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var key := y * 100000 + x
			if seen.has(key) or _t.luma(img.get_pixel(x, y)) >= 0.27:
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[key] = true
			var count := 0
			var box := Rect2i(x, y, 1, 1)
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				count += 1
				box = box.expand(p)
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + off
					if r.has_point(q) and not seen.has(q.y * 100000 + q.x) and _t.luma(img.get_pixel(q.x, q.y)) < 0.27:
						seen[q.y * 100000 + q.x] = true
						stack.append(q)
			if count >= min_px:
				blobs.append(Rect2i(box.position, box.size + Vector2i.ONE))
	return blobs


func _cast_shots(t) -> void:
	if not await t.start_world():
		return
	var world = t.world()
	WorldRoot2D.register_map(&"_art_ghost_cast", AreaMap.parse_text(CAST_MAP))
	world._enter(&"_art_ghost_cast", &"default")
	await t.seconds(0.6)
	_set_hour(world, 11.0)
	var a: IsoArea = world.area
	var made: Array = []
	# row 1 (back) faces SE, row 2 faces SW, row 3 (front) faces the camera (S): the ghosts of each row stand next to the fox, the hobbit and the fairy.  Cells step (+2, -2) = 256 ground px east
	for row in [[Vector2i(2, 8), 7], [Vector2i(4, 10), 1], [Vector2i(6, 12), 0]]:
		var start: Vector2i = row[0]
		for i in CAST_IDS.size():
			var v: IsoChibiSprite2D = IsoChibiSprite2D.create(CAST_IDS[i])
			a.objects.add_child(v)
			v.position = a.to_local(a.cell_to_global(Vector2i(start.x + 2 * i, start.y - 2 * i)))
			v.set_direction_index(int(row[1]))
			made.append(v)
	world.player.visible = false
	var cam: Camera2D = world.player.get("camera")
	var centre := a.cell_to_global(Vector2i(8, 8))
	world.player.global_position = centre
	cam.zoom = Vector2(0.4, 0.4)
	cam.reset_smoothing()
	await t.seconds(0.8)
	var img04: Image = await t.capture("cast_noon_zoom04")
	cam.zoom = Vector2(0.9, 0.9)
	var ghost_node: Node2D = made[CAST_IDS.size() * 2 + 3]            # the front row, facing S: Bu (Hviske stands to his right)
	var hviske_node: Node2D = made[CAST_IDS.size() * 2 + 4]
	world.player.global_position = (ghost_node.global_position + hviske_node.global_position) * 0.5 + Vector2(0.0, -70.0)
	cam.reset_smoothing()
	await t.seconds(0.8)
	var img09: Image = await t.capture("cast_noon_zoom09")
	var k := float(img09.get_width()) / float(ProjectSettings.get_setting("display/window/size/viewport_width")) if img09 != null else 1.0
	# the two dark eyes of Bu in the zoom 0.9 face: two dark blobs of the head box (the figure is ~160 px tall at scale 1: the eyes are at 0.65..0.80 of it)
	var bu_screen: Vector2 = ghost_node.get_global_transform_with_canvas().origin * k
	var eyes: Array[Rect2i] = []
	if img09 != null:
		eyes = _dark_blobs(img09, Rect2i(int(bu_screen.x - 55.0 * 0.9 * k), int(bu_screen.y - 150.0 * 0.9 * k), int(110.0 * 0.9 * k), int(70.0 * 0.9 * k)), 12)
	cam.zoom = Vector2(0.4, 0.4)
	world.player.global_position = centre
	cam.reset_smoothing()
	_set_hour(world, 23.0)
	await t.seconds(0.9)
	var img_night: Image = await t.capture("cast_night_zoom04")
	# night: the white / pink ghosts stay a clearly different colour from the dark ground between the fox and the hobbit of the front row (the night grade tints them blue-violet, it does not hide them)
	var night_ok := false
	var night_note := "no night image"
	if img_night != null:
		var kn := float(img_night.get_width()) / float(ProjectSettings.get_setting("display/window/size/viewport_width"))
		var bu_body := Color(0, 0, 0, 0)
		for gi in [CAST_IDS.size() * 2 + 3, CAST_IDS.size() * 2 + 4]:
			var gs: Vector2 = (made[gi] as Node2D).get_global_transform_with_canvas().origin * kn
			bu_body += (t.region_stats(img_night, Rect2i(int(gs.x - 10.0 * kn), int(gs.y - 34.0 * kn), int(20.0 * kn), int(24.0 * kn)), 2)["mean"] as Color) * 0.5
		var fs: Vector2 = (made[CAST_IDS.size() * 2] as Node2D).get_global_transform_with_canvas().origin * kn
		var hs: Vector2 = (made[CAST_IDS.size() * 2 + 1] as Node2D).get_global_transform_with_canvas().origin * kn
		var mid := (fs + hs) * 0.5
		var ground_c: Color = t.region_stats(img_night, Rect2i(int(mid.x - 12.0 * kn), int(mid.y - 22.0 * kn), int(24.0 * kn), int(14.0 * kn)), 2)["mean"]
		var delta: float = t.color_delta(bu_body, ground_c)
		night_ok = delta >= 40.0
		night_note = "night 23:00: the ghost bodies are %s, the ground between the fox and the hobbit %s, colour delta %d (want >= 40)" % [bu_body.to_html(false), ground_c.to_html(false), int(delta)]
	# the height: rendered px of the ghost against the fox (measured on the flat-colour cast of _cast_height)
	var fox_h := float(_heights.get("fox", 0.0))
	var bu_h := float(_heights.get("ghost_bu", 0.0))
	var hv_h := float(_heights.get("ghost_hviske", 0.0))
	var ratio_bu := bu_h / maxf(fox_h, 1.0)
	var ratio_hv := hv_h / maxf(fox_h, 1.0)
	t.info("rendered height at zoom 0.4: %s" % str(_heights))
	var pix_ok := false
	if img04 != null:
		pix_ok = true
		var ground: Dictionary = t.region_stats(img04, Rect2i(8, 8, 120, 30))
		for gi in [CAST_IDS.size() * 2 + 3, CAST_IDS.size() * 2 + 4]:
			var gs2: Vector2 = (made[gi] as Node2D).get_global_transform_with_canvas().origin
			var s: Dictionary = t.region_stats(img04, Rect2i(int(gs2.x - 30.0), int(gs2.y - 80.0), 60, 90), 2)
			pix_ok = pix_ok and int(s["distinct"]) > int(ground["distinct"]) + 6
	var two_eyes := eyes.size() >= 2
	if two_eyes:
		eyes.sort_custom(func(p: Rect2i, q: Rect2i) -> bool: return p.position.x < q.position.x)
		two_eyes = absi(eyes[0].position.y - eyes[1].position.y) <= 14 and eyes[1].position.x - eyes[0].end.x >= 2
	t.check("windowed_cast_shot", fox_h > 40.0 and absf(ratio_bu - 1.0) <= HEIGHT_TOLERANCE and absf(ratio_hv - 1.0) <= HEIGHT_TOLERANCE and pix_ok and two_eyes and night_ok,
		"cast on the iso fixture ground (fox, hobbit_pip, fairy, ghost_bu, ghost_hviske; three rows SE / SW / S) at zoom 0.4, 0.9 and night 23:00 written for the human (art_ghost_cast_*.png); rendered height at zoom 0.4: fox %.0f px, ghost_bu %.0f px (%d%%), ghost_hviske %.0f px (%d%%), within 10 %% of the fox; the ghosts have pixels on the ground; %d dark eye blob(s) in the zoom 0.9 face of Bu (want two, side by side); %s" % [fox_h, bu_h, int(round(ratio_bu * 100.0)), hv_h, int(round(ratio_hv * 100.0)), eyes.size(), night_note])
	# leave the world the way the next section expects it
	for v in made:
		if is_instance_valid(v):
			(v as Node).queue_free()
	world.player.visible = true
	world.day_night.override_hour = -1.0
	WorldRoot2D.unregister_map(&"_art_ghost_cast")
	await t.frames(2)
