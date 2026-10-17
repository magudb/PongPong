extends SceneTree
## Localization key coverage and CSV lint (PLAN 3.4, 8.2 row 13, addendum 4.4).
##
##   godot --headless --path . -s res://tests/loc_check.gd [-- --strict] [--root=PATH] [--dump=FILE] [--quiet]
##
## What it does
##   1. Lints res://localization (the rules of LocalizationManager.lint(): header, malformed rows, duplicates, missing da/en text,
##      % placeholders, keep-imports, key ownership, voiced keys).
##   2. Scans scripts/**/*.gd, scenes/**/*.tscn, lua/**/*.lua and data/maps/*.map for translation keys: literal ones
##      (tr("KEY"), *_key = "KEY", text = "KEY" in scenes, api.notification("KEY", ...), @title/label=/text=/prompt= in maps) and the
##      dynamic families (ITEM_<id>[_DESC|_HINT] for every Lua item / shop stock / quest reward, SHOP_<id>, RECIPE_<id>, NPC_<id>,
##      QUEST_<id>_TITLE/_DESC/_OFFER, OBJ_<QUEST>_<OBJ> then OBJ_<OBJ>, ZONE_<id>, BUILDING_<id>, UI_MONTH_*, UI_WEEKDAY_*,
##      UI_WEATHER_*, HOME_TIER_<n>[_DESC|_GATE], DLG_BUILDER_T<nn>_*, FSET_<id>, OUTFIT_<id>, RARITY_<id>, HYGGE_<id>,
##      FIND_CONTAINER_/FIND_AREA_/FIND_SPOT_<id>, FURNI_REJECT_<reason>).
##   3. Asserts that every referenced key has a text in da AND en.
##   4. When assets/audio/voice/manifest.json exists: voiced keys must still have the text the voice was generated from (R.17).
##
## Exit code: lenient (default) - 0 unless the NON-legacy CSVs break a rule (duplicates, ownership, missing keep-import, ...);
##            missing keys and the tolerated legacy da.csv problems are printed. (Until wave 3 the screens and data are not all there.)
##            --strict  - 1 on ANY missing key, malformed row, duplicate or other lint issue, legacy da.csv included (P26 gate).
## --root=PATH scans another project root (default res://; the CSVs are read from <root>/localization), --dump=FILE writes the
## reference index as JSON (tools/loc/prune_legacy.py uses it), --quiet prints only the summary line.

const LM := preload("res://scripts/autoload/localization_manager.gd")

const BASE_ZONES: PackedStringArray = ["farm", "city", "dark_forest", "forest_edge", "dybe_bregner", "mushroom_grove", "crystal_cave"]
const BASE_BUILDINGS: PackedStringArray = ["coop", "barn", "house"]
const WEATHER_IDS: PackedStringArray = ["klart", "regn", "taage", "sne", "torden"]
const MONTH_IDS: PackedStringArray = ["foraar", "sommer", "efteraar", "vinter"]
## Dynamic families this script enumerates from data (the Lua tables are the truth for them): tools/loc/prune_legacy.py does not let a
## code prefix such as "ITEM_" keep every legacy row of the family alive.
const ENUMERATED_PREFIXES: PackedStringArray = ["ITEM_", "SHOP_", "RECIPE_", "NPC_", "QUEST_", "OBJ_", "ZONE_", "BUILDING_", "UI_MONTH_",
	"UI_WEEKDAY_", "UI_WEATHER_", "HOME_TIER_", "FSET_", "OUTFIT_", "RARITY_", "HYGGE_", "FIND_CONTAINER_", "FIND_AREA_", "FIND_SPOT_", "FURNI_REJECT_"]
## Placement reject reasons of the Indretning screen (addendum 3.7: FURNI_REJECT_* x15, owner F7). Expanded when code mentions the family.
const FURNI_REJECT_REASONS: PackedStringArray = ["BLOCKS_PATH", "BLOCKS_WINDOW", "DOOR_BLOCKED", "FULL", "NEEDS_SURFACE", "NEEDS_WALL",
	"NEEDS_WINDOW", "OUT_OF_ROOM", "OVERLAP", "SLOT_TAKEN", "TOO_TALL", "UNKNOWN_ITEM", "WALL_ORIENTATION", "WALL_TAKEN", "WINDOW_TAKEN"]

var _strict := false
var _quiet := false
var _root := "res://"
var _dump := ""

var _refs: Dictionary = {}          # key -> Array[String] sources (strong references: a miss is reported)
var _groups: Array[Dictionary] = [] # any-of groups {keys: Array[String], src: String} (OBJ_<QUEST>_<OBJ> then OBJ_<OBJ>)
var _weak: Dictionary = {}          # key-looking string literals anywhere (never a miss; they keep a key alive for prune_legacy.py)
var _dyn: Array[Dictionary] = []    # dynamic prefixes found in code {prefix, src}
var _notes: Array[String] = []      # warnings of the scan itself
var _zones: Dictionary = {}
var _counts := {"gd": 0, "tscn": 0, "lua": 0, "map": 0}

var _rx_tr: RegEx
var _rx_key_field: RegEx
var _rx_text_assign: RegEx
var _rx_tscn_text: RegEx
var _rx_weak: RegEx
var _rx_dyn_fmt: RegEx
var _rx_dyn_plus: RegEx
var _rx_notification: RegEx
var _rx_map_title: RegEx
var _rx_map_param: RegEx
var _rx_map_zone: RegEx
var _rx_unlock_zone: RegEx


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--strict":
			_strict = true
		elif a == "--quiet":
			_quiet = true
		elif a.begins_with("--root="):
			_root = a.substr(7)
		elif a.begins_with("--dump="):
			_dump = a.substr(7)
		else:
			print("loc_check: unknown argument %s (use --strict --quiet --root=PATH --dump=FILE)" % a)
			quit(2)
			return
	_compile()
	quit(_run())


func _compile() -> void:
	_rx_tr = _rx("(?:\\b(?:tr|atr|ttr)|\\bLocalizationManager\\.t|\\bTranslationServer\\.translate)\\(\\s*&?\"([^\"\\\\\\n]*)\"")
	_rx_key_field = _rx("\\b[a-z][a-z0-9_]*_key[\"']?\\s*(?::\\s*[A-Za-z]+\\s*)?[:=]\\s*&?\"([A-Z][A-Z0-9_]*)\"")
	_rx_text_assign = _rx("\\b(?:text|title|tooltip_text|placeholder_text|label|ok_button_text|cancel_button_text|dialog_text)\\s*=\\s*\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	_rx_tscn_text = _rx("(?m)^[ \\t]*[A-Za-z0-9_/]*(?:text|title|label|tooltip_text|placeholder_text)[A-Za-z0-9_]*[ \\t]*=[ \\t]*\"([A-Z][A-Z0-9_]*)\"")
	_rx_weak = _rx("&?\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	_rx_dyn_fmt = _rx("\"([A-Z][A-Z0-9_]*_)%[sd]")
	_rx_dyn_plus = _rx("\"([A-Z][A-Z0-9_]*_)\"\\s*\\+")
	_rx_notification = _rx("notification\\(\\s*\"([^\"]*)\"\\s*(?:,\\s*\"([^\"]*)\")?")
	_rx_map_title = _rx("(?m)^@title[ \\t]+([A-Z][A-Z0-9_]*)")
	_rx_map_param = _rx("\\b(?:label|text|prompt)=([A-Z][A-Z0-9_]*)")
	_rx_map_zone = _rx("(?m)^@zone[ \\t]+([a-z0-9_]+)")
	_rx_unlock_zone = _rx("unlock_zone\\(\\s*\"([a-z0-9_]+)\"")


func _rx(pattern: String) -> RegEx:
	var r := RegEx.new()
	var err := r.compile(pattern)
	if err != OK:
		push_error("loc_check: bad regex %s" % pattern)
	return r


# ---------------------------------------------------------------- main

func _run() -> int:
	var loc_dir := _root.path_join("localization")
	var report: Dictionary = LM.parse_dir(loc_dir, _root, true)
	var summary: Dictionary = LM.summarize(report, false)
	var rows: Dictionary = report["rows"]
	_scan_tree()
	_add_conventions()
	_voiced_manifest_check(rows, summary)

	var missing: Array[Dictionary] = []   # {key, locales, srcs}
	var ref_keys: Array = _refs.keys()
	ref_keys.sort()
	for key in ref_keys:
		var lacks := _lacking_locales(rows, str(key))
		if not lacks.is_empty() and not _fixture_reference(str(key), _refs[key]):
			missing.append({"key": key, "locales": lacks, "srcs": _refs[key]})
	for g in _groups:
		var lacks_g: Array[String] = []
		for loc in LM.LOCALES:
			var ok := false
			for k in (g["keys"] as Array):
				if _lacking_locales(rows, str(k)).find(loc) < 0:
					ok = true
					break
			if not ok:
				lacks_g.append(loc)
		if not lacks_g.is_empty():
			missing.append({"key": " | ".join(g["keys"]), "locales": lacks_g, "srcs": [g["src"]]})

	var errors: Array = summary["errors"]
	var legacy: Array = summary["legacy"]
	var warnings: Array = summary["warnings"]
	var per_loc := {"da": 0, "en": 0}
	for m in missing:
		for loc in m["locales"]:
			per_loc[loc] = int(per_loc.get(loc, 0)) + 1

	if not _quiet:
		print("loc_check: root=%s | scanned gd=%d tscn=%d lua=%d map=%d | CSV files: %s | keys loaded: %d" % [
			_root, _counts["gd"], _counts["tscn"], _counts["lua"], _counts["map"], " ".join(report["files"]), rows.size()])
		print("loc_check: referenced keys: %d (+%d any-of groups) | dynamic prefixes in code: %d" % [_refs.size(), _groups.size(), _dyn.size()])
		for m in missing:
			var srcs: Array = m["srcs"]
			print("MISS %s %s <- %s%s" % [",".join(m["locales"]), m["key"], ", ".join(srcs.slice(0, 3)), " (+%d)" % (srcs.size() - 3) if srcs.size() > 3 else ""])
		for iss in errors:
			print("ERROR %s" % LM.format_issue(iss))
		for iss in legacy:
			print("LEGACY %s" % LM.format_issue(iss))
		for iss in warnings:
			print("warning %s" % LM.format_issue(iss))
		for n in _notes:
			print("note %s" % n)
	if _dump != "":
		_write_dump()

	var problems := missing.size() + errors.size() + legacy.size() if _strict else errors.size()
	print("loc_check %s (%s): missing=%d (da=%d en=%d) lint_errors=%d legacy_issues=%d warnings=%d" % [
		"FAIL" if problems > 0 else "PASS", "strict" if _strict else "lenient", missing.size(), per_loc["da"], per_loc["en"],
		errors.size(), legacy.size(), warnings.size()])
	return 1 if problems > 0 else 0


## Locales ("da", "en") in which `key` has no text. A key that is not a CSV key at all lacks both.
func _lacking_locales(rows: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	var row: Variant = rows.get(key, null)
	for loc in LM.LOCALES:
		if row == null or str((row as Dictionary)["text"].get(loc, "")) == "":
			out.append(loc)
	return out


func _write_dump() -> void:
	var weak_keys: Array = _weak.keys()
	weak_keys.sort()
	var out := {"referenced": _refs, "groups": _groups, "weak": weak_keys, "dynamic_prefixes": _dyn, "enumerated_prefixes": Array(ENUMERATED_PREFIXES)}
	var f := FileAccess.open(_dump, FileAccess.WRITE)
	if f == null:
		print("loc_check: cannot write %s" % _dump)
		return
	f.store_string(JSON.stringify(out, " "))
	f.close()


# ---------------------------------------------------------------- scanning

func _scan_tree() -> void:
	for spec in [["scripts", "gd"], ["scenes", "tscn"], ["lua", "lua"], ["data/maps", "map"]]:
		for path in _list_files(_root.path_join(str(spec[0])), str(spec[1])):
			var text := FileAccess.get_file_as_string(path)
			var rel := path.trim_prefix(_root).trim_prefix("/")
			_counts[spec[1]] = int(_counts[spec[1]]) + 1
			match str(spec[1]):
				"gd":
					_scan_gd(text, rel)
				"tscn":
					_scan_tscn(text, rel)
				"lua":
					_scan_lua(text, rel)
				"map":
					_scan_map(text, rel)


func _list_files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with("." + ext) and not (ext == "map" and f.begins_with("_")):
			out.append(dir.path_join(f))
	for d in da.get_directories():
		if d.begins_with("."):
			continue
		out.append_array(_list_files(dir.path_join(d), ext))
	return out


func _line_offsets(text: String) -> PackedInt32Array:
	var offs := PackedInt32Array()
	var p := text.find("\n")
	while p >= 0:
		offs.append(p)
		p = text.find("\n", p + 1)
	return offs


func _src(rel: String, offs: PackedInt32Array, pos: int) -> String:
	return "%s:%d" % [rel, offs.bsearch(pos) + 1]


## Transient review copy belongs to its fixture setup. Product uses of the same
## key still require both CSV translations; unknown fixture keys still fail.
func _fixture_reference(key: String, sources: Array) -> bool:
	var owner := ""
	var method := ""
	if key.begins_with("GUIDE_"):
		var path := _root.path_join("scripts/ui/dev/guide_fixture.json")
		if not FileAccess.file_exists(path): return false
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or str((data as Dictionary).get("texts", {}).get(key, "")) == "": return false
		owner = "scripts/ui/dialogue_ui.gd"
		method = "fixture_guide"
	elif key == "REL_CAL_FIXTURE_FESTIVAL":
		owner = "scripts/ui/social/social_fixtures.gd"
		method = "festival"
	else: return false
	var path := _root.path_join(owner)
	if not FileAccess.file_exists(path): return false
	var text := FileAccess.get_file_as_string(path)
	var start := text.find("static func " + method + "(")
	if start < 0: return false
	var end := text.length()
	for marker in ["\nfunc ", "\nstatic func "]:
		var next := text.find(marker,start+1)
		if next >= 0: end = mini(end,next)
	if key == "REL_CAL_FIXTURE_FESTIVAL":
		var body := text.substr(start,end-start)
		if not body.contains('for locale in ["da", "en"]:') or not body.contains('translation.add_message(&"'+key+'"') or not body.contains("TranslationServer.add_translation(translation)"): return false
	var first_line := text.substr(0,start).count("\n")+1
	var last_line := text.substr(0,end).count("\n")+1
	for source in sources:
		var value := str(source)
		if not value.begins_with(owner+":"): return false
		var line := value.trim_prefix(owner+":").to_int()
		if line < first_line or line >= last_line: return false
	return not sources.is_empty()


func _ref(key: String, src: String) -> void:
	if not _refs.has(key):
		_refs[key] = []
	var lst: Array = _refs[key]
	if lst.size() < 6 and not (src in lst):
		lst.append(src)


## "KEY" that looks like a translation key (UPPER_CASE with an underscore) - the strong test used for everything but tr().
func _is_key(s: String) -> bool:
	return s.contains("_") and not s.ends_with("_") and LM.is_valid_key(s) and s.unicode_at(0) >= 65 and s.unicode_at(0) <= 90


func _strip_comments(text: String, marker: String) -> String:
	if not text.contains(marker):
		return text
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		if not line.contains(marker):
			continue
		var in_str := ""
		var j := 0
		while j < line.length():
			var c := line[j]
			if in_str != "":
				if c == "\\":
					j += 1
				elif c == in_str:
					in_str = ""
			elif c == "\"" or c == "'":
				in_str = c
			elif line.substr(j, marker.length()) == marker:
				lines[i] = line.substr(0, j)
				break
			j += 1
	return "\n".join(lines)


func _scan_common(text: String, rel: String, offs: PackedInt32Array) -> void:
	for m in _rx_key_field.search_all(text):
		var k := m.get_string(1)
		if _is_key(k):
			_ref(k, _src(rel, offs, m.get_start()))
	for m in _rx_weak.search_all(text):
		_weak[m.get_string(1)] = true


func _scan_gd(raw: String, rel: String) -> void:
	var text := _strip_comments(raw, "#")
	var offs := _line_offsets(text)
	_scan_common(text, rel, offs)
	for m in _rx_tr.search_all(text):
		var k := m.get_string(1)
		if LM.is_valid_key(k) and k.length() >= 3 and not k.ends_with("_"):
			_ref(k, _src(rel, offs, m.get_start()))
		elif k.contains(" ") or (k != "" and k != k.to_upper() and not k.contains("%")):
			_notes.append("%s: tr() of a text, not a key: \"%s\" (texts live in the CSVs)" % [_src(rel, offs, m.get_start()), k.left(40)])
	for m in _rx_text_assign.search_all(text):
		_ref(m.get_string(1), _src(rel, offs, m.get_start()))
	for m in _rx_dyn_fmt.search_all(text):
		_dyn.append({"prefix": m.get_string(1), "src": _src(rel, offs, m.get_start())})
	for m in _rx_dyn_plus.search_all(text):
		_dyn.append({"prefix": m.get_string(1), "src": _src(rel, offs, m.get_start())})
	for m in _rx_unlock_zone.search_all(text):
		_zones[m.get_string(1)] = true


func _scan_tscn(text: String, rel: String) -> void:
	var offs := _line_offsets(text)
	_scan_common(text, rel, offs)
	for m in _rx_tscn_text.search_all(text):
		var k := m.get_string(1)
		if _is_key(k):
			_ref(k, _src(rel, offs, m.get_start()))
		elif k.length() >= 4 and LM.is_valid_key(k):
			_weak[k] = true      # a single UPPER_CASE word (CONFIRM): a key only if the CSVs have it; never a miss


func _scan_lua(raw: String, rel: String) -> void:
	var text := _strip_comments(raw, "--")
	var offs := _line_offsets(text)
	_scan_common(text, rel, offs)
	for m in _rx_notification.search_all(text):
		for gi in [1, 2]:
			var arg := m.get_string(gi)
			if arg != "" and _is_key(arg):
				_ref(arg, _src(rel, offs, m.get_start()))
	for m in _rx_unlock_zone.search_all(text):
		_zones[m.get_string(1)] = true
	_expand_lua(rel, LM.lua_parse(text))


func _scan_map(text: String, rel: String) -> void:
	var offs := _line_offsets(text)
	for m in _rx_map_title.search_all(text):
		_ref(m.get_string(1), _src(rel, offs, m.get_start()))
	for m in _rx_map_param.search_all(text):
		var k := m.get_string(1)
		if _is_key(k):
			_ref(k, _src(rel, offs, m.get_start()))
	for m in _rx_map_zone.search_all(text):
		_zones[m.get_string(1)] = true


# ---------------------------------------------------------------- dynamic families from Lua data

func _need(key: String, src: String) -> void:
	_ref(key, src)


## `name_key` convention: the key ITEM_<ID> is required unless the definition names another key (then that literal is checked).
func _need_named(def: Variant, field: String, fallback: String, src: String) -> void:
	if def is Dictionary and (def as Dictionary).has(field) and str((def as Dictionary)[field]) != fallback:
		return
	_need(fallback, src)


func _expand_lua(rel: String, data: Dictionary) -> void:
	var items: Variant = data.get("items", null)
	if items is Dictionary:
		for id in items:
			var up := str(id).to_upper()
			var def: Variant = (items as Dictionary)[id]
			var src := "%s item %s" % [rel, id]
			_need_named(def, "name_key", "ITEM_" + up, src)
			_need_named(def, "description_key", "ITEM_%s_DESC" % up, src)
			var hint: Variant = (def as Dictionary).get("hint_key", null) if def is Dictionary else null
			if typeof(hint) == TYPE_BOOL and hint:
				_need("ITEM_%s_HINT" % up, src)       # hint_key = true: the hint key is the convention; a string is checked as a literal
	var shops: Variant = data.get("shops", null)
	if shops is Dictionary:
		for id in shops:
			var sdef: Variant = (shops as Dictionary)[id]
			_need_named(sdef, "name_key", "SHOP_" + str(id).to_upper(), "%s shop %s" % [rel, id])
			if sdef is Dictionary and (sdef as Dictionary).get("stock", null) is Dictionary:
				for item_id in (sdef as Dictionary)["stock"]:
					_need("ITEM_" + str(item_id).to_upper(), "%s shop %s stock" % [rel, id])
	var recipes: Variant = data.get("recipes", null)
	if recipes is Dictionary:
		for id in recipes:
			_need_named((recipes as Dictionary)[id], "name_key", "RECIPE_" + str(id).to_upper(), "%s recipe %s" % [rel, id])
	if str(data.get("kind", "")) == "quest" and data.has("id"):
		_expand_quest(rel, data)
	var cfg: Variant = data.get("config", null)
	if cfg is Dictionary:
		_expand_config(rel, cfg as Dictionary)


func _expand_quest(rel: String, q: Dictionary) -> void:
	var qid := str(q["id"])
	var up := qid.to_upper()
	var src := "%s quest %s" % [rel, qid]
	_need_named(q, "title_key", "QUEST_%s_TITLE" % up, src)
	_need_named(q, "description_key", "QUEST_%s_DESC" % up, src)
	var meta: Variant = q.get("meta", null)
	if meta is Dictionary and str((meta as Dictionary).get("giver", "")) != "":
		_need("QUEST_%s_OFFER" % up, src)
	if meta is Dictionary and str((meta as Dictionary).get("requires_zone", "")) != "":
		_zones[str((meta as Dictionary)["requires_zone"])] = true
	var objectives: Variant = q.get("objectives", null)
	if objectives is Array:
		for o in objectives:
			if not (o is Dictionary):
				continue
			var od: Dictionary = o
			if str(od.get("on", "")) == "zone_entered" and str(od.get("zone", "")) != "":
				_zones[str(od["zone"])] = true
			if od.has("id") and not od.has("description_key"):
				var oid := str(od["id"]).to_upper()
				_groups.append({"keys": ["OBJ_%s_%s" % [up, oid], "OBJ_" + oid], "src": "%s objective %s" % [src, od["id"]]})
	var rewards: Variant = q.get("rewards", null)
	if rewards is Dictionary and (rewards as Dictionary).get("items", null) is Dictionary:
		for item_id in (rewards as Dictionary)["items"]:
			_need("ITEM_" + str(item_id).to_upper(), src + " reward")


func _expand_config(rel: String, cfg: Dictionary) -> void:
	var npcs: Variant = cfg.get("npcs", null)
	if npcs is Dictionary:
		for id in npcs:
			_need_named((npcs as Dictionary)[id], "name_key", "NPC_" + str(id).to_upper(), "%s npc %s" % [rel, id])
	var buildings: Variant = cfg.get("buildings", null)
	if buildings is Dictionary:
		for id in buildings:
			_need_named((buildings as Dictionary)[id], "name_key", "BUILDING_" + str(id).to_upper(), "%s building %s" % [rel, id])
	for pair in [["furniture_sets", "FSET_"], ["wardrobe_sets", "OUTFIT_"]]:
		var sets: Variant = cfg.get(pair[0], null)
		if sets is Dictionary:
			for id in sets:
				var up := str(id).to_upper()
				var src := "%s %s %s" % [rel, pair[0], id]
				_need_named((sets as Dictionary)[id], "name_key", "%s%s" % [pair[1], up], src)
				_need_named((sets as Dictionary)[id], "description_key", "%s%s_DESC" % [pair[1], up], src)
	var rarity: Variant = cfg.get("rarity_tiers", null)
	if rarity is Dictionary:
		var order: Variant = (rarity as Dictionary).get("order", [])
		if order is Array:
			for id in order:
				_need_named((rarity as Dictionary).get(id, null), "name_key", "RARITY_" + str(id).to_upper(), "%s rarity %s" % [rel, id])
	var loot: Variant = cfg.get("loot", null)
	if loot is Dictionary:
		for pair in [["containers", "FIND_CONTAINER_"], ["zones", "FIND_AREA_"], ["spots", "FIND_SPOT_"]]:
			var tbl: Variant = (loot as Dictionary).get(pair[0], null)
			if tbl is Dictionary:
				for id in tbl:
					_need_named((tbl as Dictionary)[id], "name_key", "%s%s" % [pair[1], str(id).to_upper()], "%s loot %s %s" % [rel, pair[0], id])
	var home: Variant = cfg.get("home", null)
	if home is Dictionary:
		var tiers: Variant = (home as Dictionary).get("tiers", [])
		if tiers is Array:
			for t in tiers:
				if not (t is Dictionary) or not (t as Dictionary).has("tier"):
					continue
				var td: Dictionary = t
				var n := int(td["tier"])
				var src_t := "%s home tier %d" % [rel, n]
				_need_named(td, "name_key", "HOME_TIER_%d" % n, src_t)
				_need_named(td, "description_key", "HOME_TIER_%d_DESC" % n, src_t)
				if n >= 2:
					_need_named(td, "gate_hint_key", "HOME_TIER_%d_GATE" % n, src_t)
				var dlg: Variant = td.get("dialogue", null)
				if dlg is Dictionary:
					for part in dlg:
						var k := str((dlg as Dictionary)[part])
						if _is_key(k):
							_need(k, src_t + " builder dialogue " + str(part))
		var hygge: Variant = (home as Dictionary).get("hygge_levels", [])
		if hygge is Array:
			for h in hygge:
				if h is Dictionary and (h as Dictionary).has("id"):
					_need_named(h, "name_key", "HYGGE_" + str((h as Dictionary)["id"]).to_upper(), "%s hygge level %s" % [rel, (h as Dictionary)["id"]])


## Families that do not come from Lua tables: calendar names, zones, buildings, reject reasons (only when code mentions them).
func _add_conventions() -> void:
	for d in range(1, 8):
		_need("UI_WEEKDAY_%d" % d, "calendar (plan 3.9)")
	for m in MONTH_IDS:
		_need("UI_MONTH_" + m.to_upper(), "calendar (plan 3.9)")
	for w in WEATHER_IDS:
		_need("UI_WEATHER_" + w.to_upper(), "weather (plan 3.9)")
	for z in BASE_ZONES:
		_zones[z] = true
	for z in _zones:
		_need("ZONE_" + str(z).to_upper(), "zone %s (plan 3.7)" % z)
	for b in BASE_BUILDINGS:
		_need("BUILDING_" + b.to_upper(), "building type %s (plan 3.7)" % b)
	var mentioned := false
	for k in _refs:
		if str(k).begins_with("FURNI_REJECT_"):
			mentioned = true
	for d in _dyn:
		if str(d["prefix"]) == "FURNI_REJECT_":
			mentioned = true
	if mentioned:
		for r in FURNI_REJECT_REASONS:
			_need("FURNI_REJECT_" + r, "Indretning placement reasons (addendum 3.7)")


# ---------------------------------------------------------------- voiced keys vs assets/audio/voice/manifest.json (R.17)

func _voiced_manifest_check(rows: Dictionary, summary: Dictionary) -> void:
	var path := _root.path_join("assets/audio/voice/manifest.json")
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		(summary["errors"] as Array).append(LM.make_issue("voiced-hash", "error", "manifest.json", 0, "", "assets/audio/voice/manifest.json is not a JSON object"))
		return
	var entries: Dictionary = (data as Dictionary).get("lines", data)
	var checked := 0
	var voiced := _voiced_with_keys()
	for text_key in voiced:
		var vk: String = voiced[text_key]
		var entry: Variant = entries.get(vk, null)
		if not (entry is Dictionary):
			continue
		var da_text := str((rows.get(text_key, {"text": {}}) as Dictionary)["text"].get("da", ""))
		var ed: Dictionary = entry
		if ed.has("text_sha256"):
			checked += 1
			if str(ed["text_sha256"]).to_lower() != da_text.sha256_text():
				(summary["errors"] as Array).append(LM.make_issue("voiced-hash", "error", "manifest.json", 0, text_key, "the Danish text of %s changed after voice %s was generated (text_sha256 differs; R.17)" % [text_key, vk]))
		elif ed.has("text"):
			checked += 1
			if str(ed["text"]) != da_text:
				(summary["errors"] as Array).append(LM.make_issue("voiced-hash", "error", "manifest.json", 0, text_key, "the Danish text of %s changed after voice %s was generated (R.17)" % [text_key, vk]))
	if checked == 0 and not entries.is_empty():
		_notes.append("assets/audio/voice/manifest.json has no text_sha256/text field per voice key: the voiced-key hash check was skipped (format owned by P24)")


## {text_key: voice_key} of every dialogue line that carries a voice_key.
func _voiced_with_keys() -> Dictionary:
	var out: Dictionary = {}
	var dir := _root.path_join("lua/dialogue")
	var da := DirAccess.open(dir)
	if da == null:
		return out
	var block_rx := _rx("\\{[^{}]*\\}")
	var text_rx := _rx("text_key\\s*=\\s*\"([A-Z0-9_]+)\"")
	var voice_rx := _rx("voice_key\\s*=\\s*\"([^\"]+)\"")
	for f in da.get_files():
		if not f.ends_with(".lua"):
			continue
		for b in block_rx.search_all(FileAccess.get_file_as_string(dir.path_join(f))):
			var block := b.get_string()
			var v := voice_rx.search(block)
			var t := text_rx.search(block)
			if v != null and t != null:
				out[t.get_string(1)] = v.get_string(1)
	return out
