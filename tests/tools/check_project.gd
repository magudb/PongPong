extends SceneTree
## P01 project contract check (PLAN 3.1 + 3.2 + 3.3, review R.1/R.11, addendum 4.4, fix round RT3:
## the sixth feature autoload SocialManager, the `people` action, the towns addendum links, and the
## pad paging of UI_NAVIGATION.md F10).
##
##   godot --headless --path . -s res://tests/tools/check_project.gd            live project + fixture self-test
##   godot --headless --path . -s res://tests/tools/check_project.gd -- --text=res://project.godot
##                                                                              only the [autoload] rules on one file
##
## Exit code 0 only when every check passes. Check ids are printed as PASS/FAIL <id> so a harness
## section can wrap them one to one. Two checks (input_map_matches_contract, input_has_39_actions_...)
## answer to two ids, the `p01.` id of this tool and the `project.` id the design documents name in
## their verify lists: see _check_alias(). Only built-in classes and preload() are used: the driver
## compiles before the autoloads exist.

const Contract := preload("res://tests/tools/input_contract.gd")
const FIXTURE_PATH := "res://tests/tools/fixtures/project_with_feature_autoloads.txt"

## The 11 base autoloads, in this order, unchanged (PLAN 3.1).
const BASE_AUTOLOADS: Array = [
	["EventBus", "*res://scripts/autoload/event_bus.gd"],
	["GameManager", "*res://scripts/autoload/game_manager.gd"],
	["LocalizationManager", "*res://scripts/autoload/localization_manager.gd"],
	["SaveManager", "*res://scripts/autoload/save_manager.gd"],
	["EconomyManager", "*res://scripts/autoload/economy_manager.gd"],
	["QuestManager", "*res://scripts/autoload/quest_manager.gd"],
	["LuaRuntime", "*res://scripts/autoload/lua_runtime.gd"],
	["TimeManager", "*res://scripts/autoload/time_manager.gd"],
	["AudioManager", "*res://scripts/autoload/audio_manager.gd"],
	["ShopSystem", "*res://scripts/economy/shop_system.gd"],
	["AnimalHusbandry", "*res://scripts/farm/animal_husbandry.gd"],
]

## Feature autoloads (addendum 3.2, plus the towns addendum's SocialManager, the sixth): accepted ONLY
## after AnimalHusbandry, each at most once, in any order (parallel packages append them with
## tools/features/add_autoload.py, exception E1). The tool's CONTRACT (F1) lists the same names.
const FEATURE_AUTOLOADS: Dictionary = {
	"HomeManager": "*res://scripts/home/home_manager.gd",
	"FurnitureManager": "*res://scripts/furniture/furniture_manager.gd",
	"WardrobeManager": "*res://scripts/wardrobe/wardrobe_manager.gd",
	"LootService": "*res://scripts/loot/loot_service.gd",
	"CollectionLog": "*res://scripts/collection/collection_log.gd",
	"SocialManager": "*res://scripts/social/social_manager.gd",
}

## PLAN 3.3 layer names 1..11.
const LAYER_NAMES: Array = ["world", "player", "npc", "interactable", "enemy", "farm_plot",
	"resource_node", "ground_block", "player_attack", "enemy_attack", "pickup"]

const SUPERSEDE_LINE := "supersedes for the features: PITCH 6 note 'House interior and festivals: cut' (2.1) and the CUT row 'Farmhouse interior, festivals, friendship hearts UI, gifting, relationship events' (9.2): the home interior, a partial festival (button + event), friend gifts and the weekly chat heart are IN"

## The header line of the towns addendum (RT3, DECISION DT39: a NEW line, SUPERSEDE_LINE above never moves).
const TOWNS_SUPERSEDE_LINE := "supersedes for the towns, the farm and the social sim: PLAN 4.0's flat farm beside Hyggebyen, the CUT rows 'friendship hearts UI, gifting, relationship events' and 'festivals' (9.2) and the idea that shops are only a panel: the farm is the treetop farm Min Trækronsgård on its own branch, the citizens follow daily routines, every shop is a walk-in room with opening hours, and friendship hearts, gifts, birthdays, nine festivals, heart events and marriage-style relationships are IN: TOWNS_FARM_SOCIAL_ADDENDUM.md"

## Extensions of files that are not text (docs/design carries a few PNGs): skipped by the town name scan.
const BINARY_SUFFIXES: Array = ["png", "jpg", "jpeg", "webp", "gif", "ogg", "mp3", "wav", "ttf", "otf", "pck"]

## The retired town name, split on purpose: the team rule is that the name appears nowhere in the repo
## except the user's own Style Guide export, so a repo-wide grep for it must not hit this file.
const OLD_TOWN_NAME_PARTS: Array = ["fes", "by"]

var _passed: int = 0
var _failed: int = 0
var _text: String = ""
var _sections: Dictionary = {}


func _initialize() -> void:
	var text_arg: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--text="):
			text_arg = a.substr(7)
	if text_arg != "":
		_run_text_mode(text_arg)
	else:
		_run_live()
		_run_selftest()
	print("P01 check_project: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --------------------------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------------------------

func _check(id: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
		print("PASS %s" % id)
	else:
		_failed += 1
		print("FAIL %s: %s" % [id, detail])


## One verdict under two ids: the `p01.` id of this tool and the `project.` id the design documents
## (UI_NAVIGATION.md, TOWNS_FARM_SOCIAL_ADDENDUM.md) name in their verify lists. Both lines are
## printed (and counted) so a harness wrapper finds either one.
func _check_alias(id: String, alias_id: String, ok: bool, detail: String = "") -> void:
	_check(id, ok, detail)
	_check(alias_id, ok, detail)


func _setting(path: String, default: Variant = null) -> Variant:
	return ProjectSettings.get_setting(path, default)


## Parses project.godot style text into {section: [[key, value], ...]} (continuation lines of
## multi-line values never start with `identifier=`, so they are skipped).
static func parse_sections(text: String) -> Dictionary:
	var sections: Dictionary = {"": []}
	var current: String = ""
	var key_re: RegEx = RegEx.new()
	key_re.compile("^[A-Za-z0-9_][A-Za-z0-9_/.\\-]*$")
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line == "" or line.begins_with(";"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			current = line.substr(1, line.length() - 2)
			if not sections.has(current):
				sections[current] = []
			continue
		var eq: int = line.find("=")
		if eq > 0 and key_re.search(line.substr(0, eq)) != null:
			var list: Array = sections[current]
			list.append([line.substr(0, eq), line.substr(eq + 1).strip_edges()])
	return sections


static func autoload_entries(sections: Dictionary) -> Array:
	var out: Array = []
	var list: Array = sections.get("autoload", [])
	for pair: Array in list:
		var value: String = String(pair[1])
		if value.begins_with("\"") and value.ends_with("\"") and value.length() >= 2:
			value = value.substr(1, value.length() - 2)
		out.append([String(pair[0]), value])
	return out


## The autoload rules: 11 base lines first, in order, paths unchanged; afterwards only the feature
## autoloads of FEATURE_AUTOLOADS (six), each once, with their contract path. Returns error strings.
static func autoload_errors(entries: Array) -> Array:
	var errors: Array = []
	var n: int = BASE_AUTOLOADS.size()
	if entries.size() < n:
		errors.append("expected the %d base autoloads, found only %d" % [n, entries.size()])
	for i: int in range(mini(n, entries.size())):
		var got: Array = entries[i]
		var want: Array = BASE_AUTOLOADS[i]
		if FEATURE_AUTOLOADS.has(got[0]):
			errors.append("feature autoload %s sits at position %d, before/inside the base block (must come AFTER AnimalHusbandry)" % [got[0], i + 1])
		elif got[0] != want[0]:
			errors.append("position %d: expected %s, found %s" % [i + 1, want[0], got[0]])
		elif got[1] != want[1]:
			errors.append("%s: path changed to %s (expected %s)" % [got[0], got[1], want[1]])
	var seen: Dictionary = {}
	for i: int in range(n, entries.size()):
		var e: Array = entries[i]
		if not FEATURE_AUTOLOADS.has(e[0]):
			errors.append("unexpected autoload %s after the base block (only the %s feature autoloads are allowed)" % [e[0], _count_word(FEATURE_AUTOLOADS.size())])
		elif seen.has(e[0]):
			errors.append("feature autoload %s appears more than once" % e[0])
		elif e[1] != FEATURE_AUTOLOADS[e[0]]:
			errors.append("%s: path %s, expected %s" % [e[0], e[1], FEATURE_AUTOLOADS[e[0]]])
		seen[e[0]] = true
	return errors


## "six" for 6: the messages follow FEATURE_AUTOLOADS.size() instead of a literal that goes stale
## with the next feature autoload (the five became six in fix round RT3).
static func _count_word(n: int) -> String:
	var words: Array = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	return String(words[n]) if n >= 0 and n < words.size() else str(n)


func _has_key(section: String, key: String) -> bool:
	var list: Array = _sections.get(section, [])
	for pair: Array in list:
		if pair[0] == key:
			return true
	return false


func _keys_with_prefix(section: String, prefix: String) -> Array:
	var out: Array = []
	var list: Array = _sections.get(section, [])
	for pair: Array in list:
		if String(pair[0]).begins_with(prefix):
			out.append(pair[0])
	return out


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _gitignore_rules() -> Array:
	var rules: Array = []
	for raw: String in _read_text("res://.gitignore").split("\n"):
		var line: String = raw.strip_edges()
		if line != "" and not line.begins_with("#"):
			rules.append(line)
	return rules


## Every file under a directory, at any depth (no suffix filter, no skipped directories).
func _list_files(dir_path: String) -> Array:
	var found: Array = []
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return found
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		var full: String = dir_path.path_join(name)
		if d.current_is_dir():
			found.append_array(_list_files(full))
		else:
			found.append(full)
		name = d.get_next()
	d.list_dir_end()
	return found


func _find_files(dir_path: String, suffix: String, skip_dirs: Array) -> Array:
	var found: Array = []
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return found
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		var full: String = dir_path.path_join(name)
		if d.current_is_dir():
			if not skip_dirs.has(name):
				found.append_array(_find_files(full, suffix, skip_dirs))
		elif name.ends_with(suffix):
			found.append(full)
		name = d.get_next()
	d.list_dir_end()
	return found


# --------------------------------------------------------------------------------------------
# text mode: only the autoload rules on one file
# --------------------------------------------------------------------------------------------

func _run_text_mode(path: String) -> void:
	var text: String = _read_text(path)
	_check("p01.text_file_readable", text != "", "cannot read %s" % path)
	if text == "":
		return
	var errors: Array = autoload_errors(autoload_entries(parse_sections(text)))
	_check("p01.autoloads_base_in_order_features_after", errors.is_empty(), "; ".join(errors))


# --------------------------------------------------------------------------------------------
# live project
# --------------------------------------------------------------------------------------------

func _run_live() -> void:
	_text = _read_text("res://project.godot")
	_check("p01.project_godot_readable", _text != "", "res://project.godot is empty or missing")
	_sections = parse_sections(_text)

	# [application]
	_check("p01.name_is_traetoppen", _setting("application/config/name") == "Trætoppen", "name = %s" % _setting("application/config/name"))
	var features: PackedStringArray = _setting("application/config/features", PackedStringArray())
	_check("p01.features_4_7_gl_compatibility",
		features.has("4.7") and features.has("GL Compatibility") and not features.has("Forward Plus") and not features.has("Mobile"),
		"features = %s" % str(features))
	_check("p01.custom_user_dir",
		bool(_setting("application/config/use_custom_user_dir", false)) and _setting("application/config/custom_user_dir_name") == "Traetoppen"
		and OS.get_user_data_dir().get_file() == "Traetoppen",
		"use=%s name=%s dir=%s" % [_setting("application/config/use_custom_user_dir"), _setting("application/config/custom_user_dir_name"), OS.get_user_data_dir()])
	_check("p01.main_scene_and_icon", _setting("application/run/main_scene") == "res://scenes/main/main_menu.tscn" and _setting("application/config/icon") == "res://icon.svg",
		"main_scene = %s, icon = %s" % [_setting("application/run/main_scene"), _setting("application/config/icon")])

	# [display]
	_check("p01.viewport_1280x720", int(_setting("display/window/size/viewport_width")) == 1280 and int(_setting("display/window/size/viewport_height")) == 720,
		"viewport = %sx%s" % [_setting("display/window/size/viewport_width"), _setting("display/window/size/viewport_height")])
	_check("p01.stretch_canvas_items_expand", _setting("display/window/stretch/mode") == "canvas_items" and _setting("display/window/stretch/aspect") == "expand",
		"stretch = %s / %s" % [_setting("display/window/stretch/mode"), _setting("display/window/stretch/aspect")])
	_check("p01.no_window_size_override",
		not _has_key("display", "window/size/window_width_override") and not _has_key("display", "window/size/window_height_override")
		and int(_setting("display/window/size/window_width_override", 0)) == 0 and int(_setting("display/window/size/window_height_override", 0)) == 0,
		"window_width/height_override must not be set (screenshot-only in the UI spike)")

	# [rendering]
	_check("p01.renderer_gl_compatibility",
		_text.contains("renderer/rendering_method=\"gl_compatibility\"") and _text.contains("renderer/rendering_method.mobile=\"gl_compatibility\"")
		and _setting("rendering/renderer/rendering_method") == "gl_compatibility" and _setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility",
		"desktop and mobile rendering_method must both be gl_compatibility (file and live setting)")
	_check("p01.texture_filter_is_2", int(_setting("rendering/textures/canvas_textures/default_texture_filter")) == 2,
		"default_texture_filter = %s (2 = Linear Mipmap; 3 would be Nearest Mipmap, review R.1)" % _setting("rendering/textures/canvas_textures/default_texture_filter"))
	_check("p01.s3tc_bptc_import_on", bool(_setting("rendering/textures/vram_compression/import_s3tc_bptc", false)), "import_s3tc_bptc must be true")
	var clear: Color = _setting("rendering/environment/defaults/default_clear_color", Color.BLACK)
	_check("p01.clear_color_sky_a9d3e0", clear.is_equal_approx(Color.html("a9d3e0")), "default_clear_color = %s" % clear.to_html(false))
	var texture_defaults: Dictionary = _setting("importer_defaults/texture", {})
	_check("p01.importer_default_texture_mipmaps", texture_defaults.get("mipmaps/generate", false) == true, "importer_defaults/texture = %s" % str(texture_defaults))
	_check("p01.no_msaa_and_no_snap",
		_keys_with_prefix("rendering", "anti_aliasing/").is_empty() and _keys_with_prefix("rendering", "2d/snap").is_empty(),
		"rendering section carries %s" % str(_keys_with_prefix("rendering", "anti_aliasing/") + _keys_with_prefix("rendering", "2d/snap")))

	# [gui], [internationalization]
	_check("p01.gui_theme_custom", _setting("gui/theme/custom") == "res://assets/ui/theme.tres", "gui/theme/custom = %s" % _setting("gui/theme/custom"))
	_check("p01.locale_fallback_en", _setting("internationalization/locale/fallback") == "en", "locale/fallback = %s" % _setting("internationalization/locale/fallback"))
	var translations: PackedStringArray = _setting("internationalization/locale/translations", PackedStringArray())
	_check("p01.no_locale_translations_list", translations.is_empty() and not _has_key("internationalization", "locale/translations"),
		"locale/translations must not exist (LocalizationManager loads the CSVs at runtime, PLAN 3.4): %s" % str(translations))

	# [layer_names]
	var names_ok: bool = true
	var names_detail: String = ""
	for i: int in range(LAYER_NAMES.size()):
		var got: String = _setting("layer_names/2d_physics/layer_%d" % (i + 1), "")
		if got != LAYER_NAMES[i]:
			names_ok = false
			names_detail += " layer_%d=%s (want %s)" % [i + 1, got, LAYER_NAMES[i]]
	_check("p01.layer_names_2d_1_to_11", names_ok, names_detail)
	var names3d: Array = _keys_with_prefix("layer_names", "3d_")
	_check("p01.no_3d_layer_names", names3d.is_empty(), "3D layer names left: %s" % str(names3d))
	_check("p01.no_animation_3d_key", not _sections.has("animation"), "[animation] section is still present")

	# [autoload]
	var entries: Array = autoload_entries(_sections)
	var aerr: Array = autoload_errors(entries)
	_check("p01.autoloads_base_in_order_features_after", aerr.is_empty(), "; ".join(aerr))
	var missing_scripts: Array = []
	for e: Array in entries:
		var path: String = String(e[1]).trim_prefix("*")
		if not FileAccess.file_exists(path):
			missing_scripts.append(e[0])
	_check("p01.autoload_scripts_exist", missing_scripts.is_empty(), "autoload without a script file: %s" % str(missing_scripts))
	var tree_names: Array = []
	for c: Node in root.get_children():
		tree_names.append(String(c.name))
	var node_ok: bool = true
	var cursor: int = -1
	for e: Array in entries:
		var at: int = tree_names.find(String(e[0]))
		if at < 0 or at <= cursor:
			node_ok = false
		cursor = at
	_check("p01.autoload_nodes_booted_in_order", node_ok, "autoload nodes under root: %s" % str(tree_names))

	# [input]
	var ierr: Array = Contract.verify()
	_check_alias("p01.input_map_matches_contract", "project.input_map_matches_contract", ierr.is_empty(), "; ".join(ierr))
	_check_alias("p01.input_has_39_actions_incl_map", "project.input_has_39_actions_incl_map",
		Contract.ACTIONS.size() == 39 and Contract.ADDENDUM.size() == 5 and Contract.TOWN.size() == 1 and Contract.HOTBAR.size() == 2 and Contract.NAVIGATION.size() == 1 and Contract.ACTIONS.size() - Contract.ADDENDUM.size() - Contract.TOWN.size() - Contract.HOTBAR.size() - Contract.NAVIGATION.size() == 30
		and _all_present(Contract.ADDENDUM) and _all_present(Contract.TOWN) and _all_present(Contract.HOTBAR) and _all_present(Contract.NAVIGATION),
		"the contract has %d actions (want 39 = 30 + 5 addendum + 1 town + 2 named hotbar bindings + 1 map)" % Contract.ACTIONS.size())
	var inv: Array = Contract.actual_signatures("inventory")
	var inv_want: Array = ["key:%d" % KEY_I, "key:%d" % KEY_TAB]
	inv_want.sort()
	_check("p01.inventory_i_and_tab_not_f10", inv == inv_want and not inv.has("key:%d" % KEY_F10), "inventory = %s" % str(inv))
	var wheel_actions: Array = []
	for a: String in Contract.ACTIONS:
		for sig: String in Contract.actual_signatures(a):
			if sig == "mouse:%d" % MOUSE_BUTTON_WHEEL_UP or sig == "mouse:%d" % MOUSE_BUTTON_WHEEL_DOWN:
				wheel_actions.append(a)
	wheel_actions.sort()
	_check("p01.wheel_only_on_zoom", wheel_actions == ["zoom_in", "zoom_out"], "mouse wheel is bound to %s (rotate_item must not use it)" % str(wheel_actions))
	var qerr: Array = Contract.qualifier_errors()
	_check("p01.input_events_are_plain_unqualified", qerr.is_empty(), "; ".join(qerr))
	var uerr: Array = Contract.ui_nav_errors()
	_check("p01.ui_accept_cancel_take_joy_a_b_dpad_walks_focus", uerr.is_empty(), "; ".join(uerr))
	var perr: Array = Contract.ui_page_errors()
	# 39 contract actions (including People, hotbar and map) + four ui_* overrides.
	_check("project.ui_page_pad_bindings",
		perr.is_empty() and Contract.UI_OVERRIDES.size() == 4 and Contract.ACTIONS.size() + Contract.UI_OVERRIDES.size() == 43 and Contract.UI_PAGE_ACTIONS.size() == 2
		and Contract.actual_signatures("ui_page_up") == ["joy:%d" % JOY_BUTTON_LEFT_SHOULDER, "key:%d" % KEY_Q, "logicalkey:%d" % KEY_PAGEUP]
		and Contract.actual_signatures("ui_page_down") == ["joy:%d" % JOY_BUTTON_RIGHT_SHOULDER, "key:%d" % KEY_E, "logicalkey:%d" % KEY_PAGEDOWN],
		"; ".join(perr) if not perr.is_empty() else "ui_page_up must be Q + PageUp + LB (joy 9) and ui_page_down E + PageDown + RB (joy 10), nothing else (Q / E: review UX-16); 39 + 4 overrides = 43 actions")

	# repo hygiene
	_check_hygiene()


func _all_present(names: Array) -> bool:
	for a: String in names:
		if not InputMap.has_action(a):
			return false
	return true


func _check_hygiene() -> void:
	var rules: Array = _gitignore_rules()
	var needed_feature: Array = ["project.godot.lock", "tools/art/_stage/", "tools/features/_stage/", "tools/features/reports/"]
	var missing: Array = []
	for r: String in needed_feature:
		if not rules.has(r):
			missing.append(r)
	_check("project.gitignore_has_feature_entries", missing.is_empty(), "missing .gitignore rules: %s" % str(missing))
	var needed_base: Array = [".godot/", "*.translation", ".mimocode/", ".playwright-mcp/", "__pycache__/", "tools/art/.venv/", "/scratch/",
		".DS_Store", "Thumbs.db", ".vscode/", ".idea/", "saves/"]
	var missing_base: Array = []
	for r: String in needed_base:
		if not rules.has(r):
			missing_base.append(r)
	_check("p01.gitignore_keeps_base_and_tool_entries", missing_base.is_empty(), "missing .gitignore rules: %s" % str(missing_base))
	_check("project.export_presets_are_versioned", not rules.has("export_presets.cfg") and FileAccess.file_exists("res://export_presets.cfg"), "desktop export presets are committed; credentials remain below ignored .godot/")
	_check("p01.gitignore_commits_import_and_uid", not rules.has("*.import") and not rules.has("*.uid") and rules.has("*.translation"),
		"*.import/*.uid must not be ignored (a fresh clone needs them); *.translation must stay ignored")

	var attr_lines: Array = []
	for raw: String in _read_text("res://.gitattributes").split("\n"):
		attr_lines.append(raw.strip_edges())
	var binary_missing: Array = []
	for ext: String in ["webp", "png", "ogg", "ttf", "jpg"]:
		if not attr_lines.has("*.%s binary" % ext):
			binary_missing.append(ext)
	var lfs_commented: bool = attr_lines.has("#assets/**/*.webp filter=lfs diff=lfs merge=lfs -text")
	var lfs_active: bool = false
	for l: String in attr_lines:
		if l.contains("filter=lfs") and not l.begins_with("#"):
			lfs_active = true
	_check("p01.gitattributes_binary_and_commented_lfs", binary_missing.is_empty() and lfs_commented and not lfs_active,
		"binary missing for %s, commented LFS line %s, LFS active %s" % [str(binary_missing), lfs_commented, lfs_active])

	_check("p01.docs_gdignore_exists", FileAccess.file_exists("res://docs/.gdignore"), "docs/.gdignore is missing")
	var stale: Array = _find_files("res://docs", ".import", ["PongPong_Isometric2D"])
	_check("p01.docs_has_no_stale_import_files", stale.is_empty(), "%d stale .import file(s) under docs/, e.g. %s" % [stale.size(), stale.slice(0, 2)])
	_check("p01.obsolete_3d_asset_dirs_gone", not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://assets/models"))
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://assets/textures")), "assets/models or assets/textures still exists")

	# docs/design
	var plan: String = _read_text("res://docs/design/PLAN_2D.md")
	var addendum: String = _read_text("res://docs/design/PLAN_2D_FEATURES.md")
	var json_text: String = _read_text("res://docs/design/features_workpackages.json")
	var parsed: Variant = JSON.parse_string(json_text) if json_text != "" else null
	_check("p01.design_files_exist", plan != "" and addendum != "" and parsed is Dictionary and (parsed as Dictionary).has("newPackages"),
		"docs/design/{PLAN_2D.md, PLAN_2D_FEATURES.md, features_workpackages.json} must exist and the json must parse")
	_check("p01.design_plan_links_addendum_and_supersede_line",
		plan.contains("](PLAN_2D_FEATURES.md)") and plan.contains("](features_workpackages.json)") and plan.contains(SUPERSEDE_LINE) and plan.begins_with("# TRÆTOPPEN"),
		"PLAN_2D.md must link both files and carry the supersede line in its header")
	# the towns addendum (RT3 task 3, DT39): its files exist, PLAN_2D.md links both and carries the NEW header line
	var towns: String = _read_text("res://docs/design/TOWNS_FARM_SOCIAL_ADDENDUM.md")
	var towns_json_text: String = _read_text("res://docs/design/towns_farm_social_workpackages.json")
	var towns_parsed: Variant = JSON.parse_string(towns_json_text) if towns_json_text != "" else null
	_check("p01.design_plan_links_towns_addendum",
		towns != "" and towns_parsed is Dictionary and (towns_parsed as Dictionary).has("newPackages")
		and plan.contains("](TOWNS_FARM_SOCIAL_ADDENDUM.md)") and plan.contains("](towns_farm_social_workpackages.json)")
		and plan.contains(TOWNS_SUPERSEDE_LINE) and plan.contains(SUPERSEDE_LINE) and plan.begins_with("# TRÆTOPPEN"),
		"docs/design/{TOWNS_FARM_SOCIAL_ADDENDUM.md, towns_farm_social_workpackages.json} must exist (the json must parse) and PLAN_2D.md must link both and carry the towns supersede line (the features line stays too)")
	# the retired town name: no file of docs/design (any depth, every text file, file names included)
	var old_town: String = OLD_TOWN_NAME_PARTS[0] + OLD_TOWN_NAME_PARTS[1]
	var scanned: int = 0
	var name_hits: Array = []
	for f: String in _list_files("res://docs/design"):
		var suffix: String = f.get_extension().to_lower()
		if f.to_lower().contains(old_town):
			name_hits.append(f)
		if BINARY_SUFFIXES.has(suffix):
			continue
		scanned += 1
		if _read_text(f).to_lower().contains(old_town):
			name_hits.append(f)
	_check("p01.design_files_use_current_town_name", name_hits.is_empty() and scanned >= 10,
		"the retired town name appears in %s (the town is Hyggebyen, genitive Hyggebyens); %d text files scanned (the scan must really see docs/design)" % [str(name_hits.slice(0, 4)), scanned])


# --------------------------------------------------------------------------------------------
# fixture self-test of the autoload rules (no Godot project state involved)
# --------------------------------------------------------------------------------------------

func _expect_ok(id: String, entries: Array) -> void:
	var errs: Array = autoload_errors(entries)
	_check(id, errs.is_empty(), "; ".join(errs))


func _expect_reject(id: String, entries: Array, fragment: String) -> void:
	var errs: Array = autoload_errors(entries)
	var hit: bool = false
	for e: String in errs:
		if e.contains(fragment):
			hit = true
	_check(id, hit, "expected an error containing '%s', got %s" % [fragment, str(errs)])


## Builds one in-memory key event for the signature self-test.
func _key_ev(code: int) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code as Key
	ev.device = Contract.ANY_DEVICE
	return ev


## Negative control for the input rules, in the live process: break the live InputMap on purpose,
## require the rules to see it, restore it. Runs after every live check (they are already done).
func _run_input_negative_controls() -> void:
	var errors_before: Array = Contract.verify()
	# signature(): the plain form is stable, every qualifier changes it
	var plain: InputEventKey = _key_ev(KEY_W)
	_check("p01.signature_plain_key_has_no_qualifier", Contract.signature(plain) == "key:%d" % KEY_W and Contract.qualifiers(plain) == "",
		"plain W signature is %s" % Contract.signature(plain))
	# label -> [event, the signature the PLAIN form of the same binding has]
	var variants: Dictionary = {}
	var v: InputEventKey = _key_ev(KEY_W)
	v.shift_pressed = true
	variants["shift"] = [v, "key:%d" % KEY_W]
	v = _key_ev(KEY_W)
	v.ctrl_pressed = true
	variants["ctrl"] = [v, "key:%d" % KEY_W]
	v = _key_ev(KEY_W)
	v.alt_pressed = true
	variants["alt"] = [v, "key:%d" % KEY_W]
	v = _key_ev(KEY_W)
	v.meta_pressed = true
	variants["meta"] = [v, "key:%d" % KEY_W]
	v = _key_ev(KEY_W)
	v.command_or_control_autoremap = true
	variants["command_or_control_autoremap"] = [v, "key:%d" % KEY_W]
	v = _key_ev(KEY_W)
	v.location = KEY_LOCATION_LEFT
	variants["key location"] = [v, "key:%d" % KEY_W]
	v = _key_ev(KEY_W)
	v.device = 0
	variants["device 0"] = [v, "key:%d" % KEY_W]
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.device = Contract.ANY_DEVICE
	mouse.shift_pressed = true
	variants["shift on a mouse button"] = [mouse, "mouse:%d" % MOUSE_BUTTON_LEFT]
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.device = 1
	variants["pad device 1"] = [pad, "joy:%d" % JOY_BUTTON_A]
	var blind: Array = []
	for label: String in variants:
		var pair: Array = variants[label]
		var sig: String = Contract.signature(pair[0])
		if sig == pair[1] or not sig.begins_with(pair[1]) or Contract.qualifiers(pair[0]) == "":
			blind.append(label)
	_check("p01.signature_sees_modifiers_location_and_device", blind.is_empty(), "signature() cannot tell these from the plain binding: %s" % str(blind))

	# live map: Shift+W on move_forward must be rejected by the exact comparison AND by the qualifier rule
	var shifted: InputEventKey = _key_ev(KEY_W)
	shifted.shift_pressed = true
	InputMap.action_add_event("move_forward", shifted)
	var verify_errs: Array = Contract.verify()
	var qual_errs: Array = Contract.qualifier_errors()
	InputMap.action_erase_event("move_forward", shifted)
	_check("p01.control_shift_w_on_move_forward_is_rejected", not verify_errs.is_empty() and not qual_errs.is_empty(),
		"an extra Shift+W binding on move_forward was not detected (verify %d, qualifier %d)" % [verify_errs.size(), qual_errs.size()])
	# replacing the plain I by Ctrl+I on inventory (the plain event gone, the qualified one in its place)
	var plain_events: Array = InputMap.action_get_events("inventory")
	var ctrl_i: InputEventKey = _key_ev(KEY_I)
	ctrl_i.ctrl_pressed = true
	InputMap.action_erase_events("inventory")
	InputMap.action_add_event("inventory", ctrl_i)
	for e: InputEvent in plain_events:
		if not (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_I):
			InputMap.action_add_event("inventory", e)
	var ctrl_verify: Array = Contract.verify()
	InputMap.action_erase_events("inventory")
	for e: InputEvent in plain_events:
		InputMap.action_add_event("inventory", e)
	_check("p01.control_ctrl_i_on_inventory_is_rejected", not ctrl_verify.is_empty(), "Ctrl+I instead of I on inventory was not detected")

	# ui_accept without the pad button (the 4.7.2 engine default): the ui rule must flag it
	var accept_events: Array = InputMap.action_get_events("ui_accept")
	for e: InputEvent in accept_events:
		if e is InputEventJoypadButton:
			InputMap.action_erase_event("ui_accept", e)
	var ui_without_pad: Array = Contract.ui_errors()
	for e: InputEvent in accept_events:
		if not InputMap.action_has_event("ui_accept", e):
			InputMap.action_add_event("ui_accept", e)
	_check("p01.control_ui_accept_without_joy_a_is_rejected", not ui_without_pad.is_empty(), "ui_accept without joy A was not detected")
	_run_page_and_town_controls()

	var errors_after: Array = Contract.verify()
	# the order of the messages follows InputMap.get_actions(), which a re-added action changes: compare the sorted lists
	var sorted_before: Array = errors_before.duplicate()
	var sorted_after: Array = errors_after.duplicate()
	sorted_before.sort()
	sorted_after.sort()
	_check("p01.control_restored_live_input_map", sorted_after == sorted_before,
		"the negative controls left the InputMap changed: before %s, after %s" % [str(errors_before), str(errors_after)])


## Takes the joypad button events off one action of the live InputMap and returns them.
func _strip_pad_events(action: String) -> Array:
	var removed: Array = []
	if not InputMap.has_action(action):
		return removed
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			removed.append(e)
	for e: InputEvent in removed:
		InputMap.action_erase_event(action, e)
	return removed


func _pad_button_event(button: int) -> InputEventJoypadButton:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.device = Contract.ANY_DEVICE
	ev.button_index = button as JoyButton
	return ev


## Negative controls of the pad paging (UI.1) and the `people` action (RT3.2), in the live process
## like the controls above: break the live InputMap on purpose, require the rules to see it, restore.
func _run_page_and_town_controls() -> void:
	# ui_page_up without LB (the 4.7.2 engine default: PageUp only)
	var lost_lb: Array = _strip_pad_events("ui_page_up")
	var without_lb: Array = Contract.ui_page_errors()
	for e: InputEvent in lost_lb:
		InputMap.action_add_event("ui_page_up", e)
	_check("p01.control_ui_page_up_without_lb_is_rejected", not lost_lb.is_empty() and not without_lb.is_empty() and str(without_lb).contains("ui_page_up"),
		"ui_page_up without LB was not detected: %s" % str(without_lb))
	# ui_page_down on LB instead of RB (the two shoulder buttons swapped)
	var lost_rb: Array = _strip_pad_events("ui_page_down")
	var lb_event: InputEventJoypadButton = _pad_button_event(JOY_BUTTON_LEFT_SHOULDER)
	InputMap.action_add_event("ui_page_down", lb_event)
	var on_lb: Array = Contract.ui_page_errors()
	InputMap.action_erase_event("ui_page_down", lb_event)
	for e: InputEvent in lost_rb:
		InputMap.action_add_event("ui_page_down", e)
	_check("p01.control_ui_page_down_on_lb_is_rejected", not lost_rb.is_empty() and not on_lb.is_empty() and str(on_lb).contains("ui_page_down"),
		"ui_page_down on LB instead of RB was not detected: %s" % str(on_lb))
	# the paging must keep RB on drink and rotate_item: take it off drink and the page probes see it
	var lost_drink: Array = _strip_pad_events("drink")
	var without_drink: Array = Contract.ui_page_errors()
	for e: InputEvent in lost_drink:
		InputMap.action_add_event("drink", e)
	_check("p01.control_drink_without_rb_is_rejected_by_the_page_probes", not lost_drink.is_empty() and str(without_drink).contains("does not trigger drink"),
		"RB taken off drink was not detected: %s" % str(without_drink))
	# the `people` action: gone from the InputMap = rejected by the contract and by the count check's premise
	if not InputMap.has_action("people"):
		_check("p01.control_people_removed_is_rejected", false, "the live project has no people action: the control cannot run (see p01.input_map_matches_contract)")
		_check("p01.control_people_extra_key_is_rejected", false, "the live project has no people action: the control cannot run (see p01.input_map_matches_contract)")
		return
	var people_events: Array = InputMap.action_get_events("people")
	var people_deadzone: float = InputMap.action_get_deadzone("people")
	InputMap.erase_action("people")
	var without_people: Array = Contract.verify()
	var has_people: bool = InputMap.has_action("people")
	InputMap.add_action("people", people_deadzone)
	for e: InputEvent in people_events:
		InputMap.action_add_event("people", e)
	_check("p01.control_people_removed_is_rejected", not people_events.is_empty() and not has_people and str(without_people).contains("missing action people"),
		"a project without the people action was not detected: %s" % str(without_people))
	# `people` on a second key (an extra binding) is as wrong as a missing one
	var extra_key: InputEventKey = _key_ev(KEY_O)
	InputMap.action_add_event("people", extra_key)
	var extra: Array = Contract.verify()
	InputMap.action_erase_event("people", extra_key)
	_check("p01.control_people_extra_key_is_rejected", str(extra).contains("people: expected events"), "an extra key on people was not detected: %s" % str(extra))


func _run_selftest() -> void:
	var fixture_text: String = _read_text(FIXTURE_PATH)
	_check("p01.fixture_present", fixture_text != "", "%s is missing" % FIXTURE_PATH)
	var fixture: Array = autoload_entries(parse_sections(fixture_text))
	_check("p01.fixture_is_11_base_plus_6_feature_lines", fixture.size() == BASE_AUTOLOADS.size() + FEATURE_AUTOLOADS.size(),
		"fixture has %d autoload lines, the contract is %d base + %d feature lines" % [fixture.size(), BASE_AUTOLOADS.size(), FEATURE_AUTOLOADS.size()])
	var base: Array = fixture.slice(0, BASE_AUTOLOADS.size())
	var feats: Array = fixture.slice(BASE_AUTOLOADS.size())
	var feat_names: Array = []
	for f: Array in feats:
		feat_names.append(f[0])
	feat_names.sort()
	var contract_names: Array = FEATURE_AUTOLOADS.keys()
	contract_names.sort()
	_check("p01.fixture_features_are_exactly_the_contract", feat_names == contract_names and FEATURE_AUTOLOADS.get("SocialManager", "") == "*res://scripts/social/social_manager.gd",
		"fixture feature lines %s, contract %s (SocialManager, the sixth, is part of both)" % [str(feat_names), str(contract_names)])

	_expect_ok("p01.fixture_accepted_base_plus_feature_lines", fixture)
	_expect_ok("p01.fixture_accepted_base_only", base)
	_expect_ok("p01.fixture_accepted_any_subset_in_any_order", base + [feats[3], feats[0]])
	var reversed: Array = feats.duplicate()
	reversed.reverse()
	_expect_ok("p01.fixture_accepted_features_reversed", base + reversed)

	# the real project.godot plus the feature lines appended by hand, exactly what add_autoload.py will do
	var live: Array = []
	for e: Array in autoload_entries(_sections):
		if not FEATURE_AUTOLOADS.has(e[0]):
			live.append(e)
	_expect_ok("p01.live_project_accepts_appended_feature_lines", live + feats)

	var swapped: Array = fixture.duplicate()
	var tmp: Array = swapped[1]
	swapped[1] = swapped[2]
	swapped[2] = tmp
	_expect_reject("p01.fixture_rejects_swapped_base_order", swapped, "position 2")
	_expect_reject("p01.fixture_rejects_missing_base_autoload", fixture.slice(0, 5) + fixture.slice(6), "position 6")
	var before: Array = base.duplicate()
	before.insert(10, feats[0])
	_expect_reject("p01.fixture_rejects_feature_before_animal_husbandry", before, "before/inside the base block")
	_expect_reject("p01.fixture_rejects_duplicate_feature_line", fixture + [feats[2]], "more than once")
	_expect_reject("p01.fixture_rejects_unknown_extra_autoload", fixture + [["DebugOverlay", "*res://scripts/debug/overlay.gd"]], "unexpected autoload DebugOverlay")
	var moved: Array = fixture.duplicate(true)
	moved[3] = ["SaveManager", "*res://scripts/save/save_manager.gd"]
	_expect_reject("p01.fixture_rejects_changed_base_path", moved, "path changed")
	var wrong_path: Array = base + [["HomeManager", "*res://scripts/elsewhere/home.gd"]]
	_expect_reject("p01.fixture_rejects_feature_autoload_with_wrong_path", wrong_path, "expected *res://scripts/home/home_manager.gd")
	# the sixth feature autoload (SocialManager, towns addendum RT3): accepted at its contract path only, once, and the list stays closed behind it
	_expect_ok("p01.fixture_accepts_social_manager_alone_after_the_base", base + [["SocialManager", "*res://scripts/social/social_manager.gd"]])
	_expect_reject("p01.fixture_rejects_social_manager_with_wrong_path", base + [["SocialManager", "*res://scripts/elsewhere/social.gd"]], "expected *res://scripts/social/social_manager.gd")
	_expect_reject("p01.fixture_rejects_social_manager_inside_the_base_block", base.slice(0, 4) + [["SocialManager", "*res://scripts/social/social_manager.gd"]] + base.slice(4), "before/inside the base block")
	_expect_reject("p01.fixture_rejects_seventh_unknown_autoload_behind_social_manager", fixture + [["PeopleManager", "*res://scripts/social/people_manager.gd"]], "unexpected autoload PeopleManager")

	_run_input_negative_controls()
