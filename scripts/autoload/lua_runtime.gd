extends Node
## Bridge to Lua for quests, dialogue, items, shops, recipes and the game's data tables (D13, D14).
##
## A pure-GDScript interpreter of a documented Lua SUBSET (no GDExtension): top-level assignments of literal tables and
## top-level functions with `local`, `if/return`, the `api.*` calls and the expression operators `and or not == ~= < <= > >= ..`.
## The parser lives in scripts/data/lua_parser.gd (+ lua_tokens.gd); the load-time lint in scripts/data/lua_lint.gd and
## `tools/lua/lint.gd`. Everything outside the subset is reported in `lint_report` at load - never as an engine warning.
## A real Lua GDExtension can replace the internals later: the public API below stays stable.
##
## Files are loaded from res://lua/** (any directory; the `kind = "..."` header decides what a file is):
##   config   -> get_config("a.b.c", default)   merged by top-level key; two files must not define the same key
##   items    -> get_item_def(id), get_all_item_ids()
##   quest    -> registered with QuestManager; hooks via call_quest_event()
##   dialogue -> get_dialogue(id, context)
##   recipes  -> get_recipes(category?), get_recipe(id)
##   shops    -> get_shop(id), get_shops()
##   registry -> get_registry(name), get_registry_entry(name, id): `registry = "<name>"` header + a top-level table of that
##               name = { <id> = {...} }; one file per citizen / building / festival ... (routines, buildings, events, festivals)
##   (config.npcs -> get_npc(id), get_npcs())
## `reload_scripts()` re-reads everything (bound to F9 in debug builds only).
##
## Semantics worth knowing (they are tested in tests/sections/data.gd):
##   * Lua truthiness: only nil and false are false (0, "" and empty tables are true).
##   * A bare identifier that is not a local or parameter reads the WORLD FLAG of that name (`context.home_tier or home_tier or 1`).
##   * Comparing values of different types is false, never an engine error (`false == 3`).
##   * api.emit(name, payload) carries the payload; api.notification(title, message) runs both through tr().
##   * Unknown api functions are logged once (print, not an engine warning) and answer nil.
##   * The social functions (api.get_hearts / add_hearts / is_birthday / festival) are late-bound to the SocialManager autoload
##     (S-core): without it they answer nil and change nothing. `api.festival()` answers "" (a TRUTHY string in Lua) when no
##     festival is on: compare it (`api.festival() ~= ""`), never test it.

## A Lua number outside +-1e15 is clamped before int() (int(1e30) is INT64_MIN on x86 and would read as a full deduction).
const ARG_INT_LIMIT := 1.0e15
const LUA_ROOT := "res://lua"
const API_VERSION := 2

const _Parser := preload("res://scripts/data/lua_parser.gd")
const _Lint := preload("res://scripts/data/lua_lint.gd")

const _RARITY_IDS := ["normal", "uncommon", "rare", "unique", "legendary", "common"]
## names the parser keeps for its own result keys: a table of that name is never extracted, so a registry cannot use them
const _RESERVED_KEYS := ["functions", "table_assigns", "source_path", "kind", "id"]

var _scripts: Dictionary = {}          # script_id -> parsed script dict
var _quest_modules: Dictionary = {}    # quest_id -> script_id
var _dialogue_modules: Dictionary = {} # dialogue_id -> script_id
var _item_defs: Dictionary = {}        # item_id -> def
var _config: Dictionary = {}
var _recipes: Dictionary = {}          # recipe_id -> def (kind "recipes")
var _shops: Dictionary = {}            # shop_id -> def (kind "shops")
var _registries: Dictionary = {}       # registry name -> {id -> def} (kind "registry": routines, buildings, events, festivals ...)
var _config_owner: Dictionary = {}     # top-level config key -> script id
var _owner_of: Dictionary = {}         # "items:<id>" / "recipes:<id>" / "shops:<id>" / "registry:<name>:<id>" / "quest:<id>" / "dialogue:<id>" -> script id
var _logged_once: Dictionary = {}
var _hot_reload_enabled: bool = true

## Findings of LuaLint (plus data-level checks) for every file loaded by the last reload_scripts()/load_file():
## Array of {path, line, rule, token, message}. Empty = lint clean.
var lint_report: Array[Dictionary] = []
## Consistency notes that are not syntax: an id defined by two files (the later file wins). Same shape as lint_report; a clean
## lint does not depend on it (a duplicate is a content bug of the file that owns the id, not a Lua subset violation).
var data_report: Array[Dictionary] = []
## Milliseconds the last reload_scripts() needed (tests assert it stays small).
var load_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload_scripts()
	set_process_unhandled_key_input(_hot_reload_enabled and OS.is_debug_build())


## F9 hot reload, debug builds only (the engine's own key, not a project input action).
func _unhandled_key_input(event: InputEvent) -> void:
	if not (_hot_reload_enabled and OS.is_debug_build()):
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F9:
		reload_scripts(true)
		get_viewport().set_input_as_handled()


# =============================================================================================== public API

## Re-reads every Lua file under res://lua. `announce` posts the "reloaded" toast (F9); the boot load is silent.
func reload_scripts(announce: bool = false) -> void:
	var t0 := Time.get_ticks_msec()
	_scripts.clear()
	_quest_modules.clear()
	_dialogue_modules.clear()
	_item_defs.clear()
	_config.clear()
	_recipes.clear()
	_shops.clear()
	_registries.clear()
	_config_owner.clear()
	_owner_of.clear()
	_logged_once.clear()
	lint_report.clear()
	data_report.clear()
	_scan_dir(LUA_ROOT)
	_register_all()
	load_ms = Time.get_ticks_msec() - t0
	_print_lint_summary()
	var gm := _node("GameManager")
	if gm != null and gm.has_method("invalidate_config_cache"):
		gm.call("invalidate_config_cache")
	# marker_handlers.lua may have changed: drop the memoised marker registry and entry-point scripts (late-bound,
	# like Svc.static_call: an autoload must compile without the global class cache, so no class_name reference)
	var iso_area: Variant = load("res://scripts/world2d/iso_area.gd")
	if iso_area is Script:
		(iso_area as Script).callv(&"clear_handler_cache", [])
	if announce:
		var bus := _node("EventBus")
		if bus != null:
			bus.emit_signal("notification_posted", tr("NOTIF_LUA_RELOADED_TITLE"), _format_count(tr("NOTIF_LUA_RELOADED_MSG"), _scripts.size()), "lua")


## Reads, lints, parses and registers ONE file (also from outside res://lua, e.g. a test fixture).
## Returns its script id, or "" when the file cannot be read. Call reload_scripts() afterwards to restore the normal state.
func load_file(path: String) -> String:
	var sid := _load_script(path)
	if sid != "":
		_register_script(sid)
		_post_register()
		var gm := _node("GameManager")
		if gm != null and gm.has_method("invalidate_config_cache"):
			gm.call("invalidate_config_cache")
	return sid


func call_quest_event(quest_id: String, event: String, payload: Dictionary = {}) -> void:
	var sid: String = _quest_modules.get(quest_id, "")
	if sid == "":
		return
	_invoke_module_event(sid, event, payload)


func get_dialogue(dialogue_id: String, context: Dictionary = {}) -> Dictionary:
	var sid: String = _dialogue_modules.get(str(dialogue_id), "")
	if sid == "":
		return {}
	return _invoke_module_function(sid, "get_dialogue", [context])


## Runs the quest's is_available(context); a quest without the hook is always available — including quest defs that
## were registered without a script (QuestManager.register_quest_from_lua is the source of truth for existence).
## `context` is whatever the caller passes (QuestManager sends day / gold / home_tier; a bare identifier in the
## function still reads world flags). A hook answering a falsy value means not available (Lua truthiness: only nil
## and false are false).
func is_quest_available(quest_id: String, context: Dictionary = {}) -> bool:
	var sid: String = _quest_modules.get(str(quest_id), "")
	if sid == "":
		return true
	var script: Dictionary = _scripts.get(sid, {})
	if not script.get("functions", {}).has("is_available"):
		return true
	return _truthy(_invoke_function(sid, "is_available", [context]))


func get_item_def(item_id: String) -> Dictionary:
	return _item_defs.get(str(item_id), {})


func get_all_item_ids() -> Array:
	return _item_defs.keys()


## Dotted path into the merged config ("player.walk_speed", "crops.carrot.seasons", "time.seasons.0").
func get_config(path: String, default_value: Variant = null) -> Variant:
	var parts := path.split(".")
	var cur: Variant = _config
	for p in parts:
		if typeof(cur) == TYPE_DICTIONARY and (cur as Dictionary).has(p):
			cur = cur[p]
		elif typeof(cur) == TYPE_ARRAY and p.is_valid_int() and int(p) >= 0 and int(p) < (cur as Array).size():
			cur = cur[int(p)]
		else:
			return default_value
	return cur


## id -> recipe def of every `kind = "recipes"` file (declaration order). `category` filters by def.category.
## The returned dictionary is the live registry: treat it as read-only.
func get_recipes(category: String = "") -> Dictionary:
	if category == "":
		return _recipes
	var out := {}
	for rid in _recipes:
		if str((_recipes[rid] as Dictionary).get("category", "")) == category:
			out[rid] = _recipes[rid]
	return out


func get_recipe(recipe_id: String) -> Dictionary:
	return _recipes.get(str(recipe_id), {})


## Shop def (`kind = "shops"` files) with its `id` filled in; extra fields (tabs, rotation, price_curve, open_weekdays,
## buys, ...) arrive untouched. {} when unknown.
func get_shop(shop_id: String) -> Dictionary:
	return _shops.get(str(shop_id), {})


func get_shops() -> Dictionary:
	return _shops


## id -> def of every `kind = "registry"` file whose header says `registry = "<name>"` (routines, buildings, events, festivals ...),
## in load order. {} for an unknown name. The returned dictionary is the live registry: treat it as read-only (as get_recipes).
func get_registry(registry_name: String) -> Dictionary:
	return _registries.get(registry_name, {})


## One registry entry (the def under `<id>` in the table named `registry_name`), {} when the registry or the id is unknown. Read-only.
func get_registry_entry(registry_name: String, id: String) -> Dictionary:
	var entry: Variant = (_registries.get(registry_name, {}) as Dictionary).get(id, {})
	return entry if typeof(entry) == TYPE_DICTIONARY else {}


## NPC roster entry (lua/config/npcs.lua) with its `id` filled in; {} when unknown.
func get_npc(npc_id: String) -> Dictionary:
	var d: Variant = get_config("npcs.%s" % npc_id, {})
	return d if typeof(d) == TYPE_DICTIONARY else {}


func get_npcs() -> Dictionary:
	var d: Variant = get_config("npcs", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}


## Expose parsed scripts for tooling/debug
func get_all_script_ids() -> Array:
	return _scripts.keys()


func has_script(script_id: String) -> bool:
	return _scripts.has(script_id)


## Lint of an arbitrary source text (docs examples, tests): same rules as the load-time lint. Empty = clean.
func lint_source(source: String, path: String = "") -> Array[Dictionary]:
	return _Lint.lint(source, path)


## "N finding(s) in M file(s)" - or "" when clean.
func lint_summary() -> String:
	if lint_report.is_empty():
		return ""
	var files := {}
	for f in lint_report:
		files[str(f["path"])] = true
	return "%d lint finding(s) in %d file(s)" % [lint_report.size(), files.size()]


## Parses a Lua source (no registration). See scripts/data/lua_parser.gd for the shape of the result.
func parse_lua_source(source: String, path: String = "") -> Dictionary:
	var out: Dictionary = _Parser.parse_source(source, path)
	out["kind"] = str(out["table_assigns"].get("kind", ""))
	out["id"] = str(out["table_assigns"].get("id", ""))
	if out["kind"] == "":
		out["kind"] = _detect_kind(out, path)
	return out


# ---------------------------------------------------------------------------------------------- called from Lua

func lua_log(msg: String) -> void:
	print("[Lua] ", msg)


func lua_emit(event_name: String, payload: Dictionary = {}) -> void:
	var bus := _node("EventBus")
	if bus != null:
		bus.emit_signal("lua_event", StringName(event_name), payload)


func lua_get_flag(flag: String, default_value: Variant = false) -> Variant:
	var gm := _node("GameManager")
	if gm == null:
		return default_value
	return gm.get_flag(StringName(flag), default_value)


func lua_set_flag(flag: String, value: Variant) -> void:
	var gm := _node("GameManager")
	if gm != null:
		gm.set_flag(StringName(flag), value)


func lua_add_gold(amount: int) -> void:
	var eco := _node("EconomyManager")
	if eco != null:
		eco.add_gold(amount)


func lua_add_item(item_id: String, amount: int = 1) -> void:
	var eco := _node("EconomyManager")
	if eco != null:
		eco.add_item(StringName(item_id), amount)


func lua_remove_item(item_id: String, amount: int = 1) -> bool:
	var eco := _node("EconomyManager")
	return bool(eco.remove_item(StringName(item_id), amount)) if eco != null else false


func lua_has_item(item_id: String, amount: int = 1) -> bool:
	var eco := _node("EconomyManager")
	return bool(eco.has_item(StringName(item_id), amount)) if eco != null else false


## Title and message are translated (a translation KEY becomes the text of the current language, plain text stays).
func lua_notification(title: String, message: String) -> void:
	var bus := _node("EventBus")
	if bus != null:
		bus.emit_signal("notification_posted", _translate(title), _translate(message), "lua")


func lua_unlock_zone(zone_id: String) -> void:
	var gm := _node("GameManager")
	if gm != null:
		gm.unlock_zone(StringName(zone_id))


# =============================================================================================== loading

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var files: Array[String] = []
	var dirs: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			if dir.current_is_dir():
				dirs.append(entry)
			elif entry.get_extension() == "lua":
				files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	dirs.sort()
	for f in files:
		_load_script(path.path_join(f))
	for d in dirs:
		_scan_dir(path.path_join(d))


## Reads + lints + parses one file into _scripts. Returns the script id ("" on a read error).
func _load_script(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LuaRuntime: cannot read %s" % path)
		return ""
	var source := file.get_as_text()
	file.close()
	lint_report.append_array(_Lint.lint(source, path))
	var parsed := parse_lua_source(source, path)
	var sid := _script_id(path)
	_scripts[sid] = parsed
	return sid


func _script_id(path: String) -> String:
	var prefix := LUA_ROOT + "/"
	var rel := path.trim_prefix(prefix) if path.begins_with(prefix) else path.trim_prefix("res://")
	return rel.trim_suffix(".lua")


func _register_all() -> void:
	for sid in _scripts.keys():
		_register_script(str(sid))
	_post_register()


func _register_script(sid: String) -> void:
	var script: Dictionary = _scripts[sid]
	var path := str(script.get("source_path", ""))
	var kind := _normalize_kind(str(script.get("kind", "")))
	script["kind"] = kind
	match kind:
		"quest":
			var qid: String = str(script.get("id", "")) if str(script.get("id", "")) != "" else sid
			_claim("quest", qid, sid, path)
			_quest_modules[qid] = sid
			var qm := _node("QuestManager")
			if qm != null and qm.has_method("register_quest_from_lua"):
				# the definition (objectives, rewards, meta ...) without the function bodies: a quest manager keeps it
				# and a save may contain it, the executable part stays private to the runtime
				var definition := script.duplicate()
				definition.erase("functions")
				qm.register_quest_from_lua(definition)
		"dialogue":
			var did: String = str(script.get("id", "")) if str(script.get("id", "")) != "" else sid
			_claim("dialogue", did, sid, path)
			_dialogue_modules[did] = sid
		"items":
			var defs: Variant = script.get("items", {})
			if typeof(defs) == TYPE_DICTIONARY:
				for item_id in defs:
					_claim("items", str(item_id), sid, path)
					_item_defs[str(item_id)] = defs[item_id]
					_check_item(str(item_id), defs[item_id], path)
		"config":
			var cfg: Variant = script.get("config", {})
			if typeof(cfg) == TYPE_DICTIONARY:
				for key in cfg:
					var owner_sid: String = _config_owner.get(str(key), "")
					if owner_sid != "" and owner_sid != sid:
						_add_finding(path, 0, "duplicate_key", str(key), "config table `%s` is already defined by %s: two config files must not define the same top-level key" % [key, owner_sid])
					_config_owner[str(key)] = sid
				_merge_dict(_config, cfg)
		"recipes":
			var rdefs: Variant = script.get("recipes", {})
			if typeof(rdefs) == TYPE_DICTIONARY:
				for rid in rdefs:
					_claim("recipes", str(rid), sid, path)
					_recipes[str(rid)] = rdefs[rid]
		"registry":
			_register_registry(script, sid, path)
		"shops":
			var sdefs: Variant = script.get("shops", {})
			if typeof(sdefs) == TYPE_DICTIONARY:
				for shop_id in sdefs:
					_claim("shops", str(shop_id), sid, path)
					_shops[str(shop_id)] = sdefs[shop_id]
	_check_tables_header(script, path)


## `kind = "registry"`: the header `registry = "<name>"` names a top-level table `<name> = { <id> = {...} }`; its entries join the
## registry `<name>` (several files may feed one registry, each id once: a second file defining an id lands in data_report and
## the later file wins). A file without a usable header is the finding `registry_header` and registers nothing.
func _register_registry(script: Dictionary, sid: String, path: String) -> void:
	var rname := str((script.get("table_assigns", {}) as Dictionary).get("registry", ""))
	var usable := rname != "" and not (rname in _RESERVED_KEYS)
	var rtab: Variant = script.get(rname) if usable else null
	if typeof(rtab) != TYPE_DICTIONARY:
		_add_finding(path, 0, "registry_header", rname, "a kind = \"registry\" file needs `registry = \"<name>\"` and a top-level table of that name (`<name> = { <id> = { ... } }`); the name cannot be one of %s" % ", ".join(_RESERVED_KEYS))
		return
	if not _registries.has(rname):
		_registries[rname] = {}
	for rkey in rtab:
		_claim("registry:" + rname, str(rkey), sid, path)
		(_registries[rname] as Dictionary)[str(rkey)] = rtab[rkey]


## Fills in the `id` of recipes, shops and NPCs so a def is self-describing (the key it was declared under).
func _post_register() -> void:
	for rid in _recipes:
		if typeof(_recipes[rid]) == TYPE_DICTIONARY:
			(_recipes[rid] as Dictionary)["id"] = str(rid)
	for shop_id in _shops:
		if typeof(_shops[shop_id]) == TYPE_DICTIONARY:
			(_shops[shop_id] as Dictionary)["id"] = str(shop_id)
	var npcs: Variant = _config.get("npcs", {})
	if typeof(npcs) == TYPE_DICTIONARY:
		for npc_id in npcs:
			if typeof(npcs[npc_id]) == TYPE_DICTIONARY:
				(npcs[npc_id] as Dictionary)["id"] = str(npc_id)


func _normalize_kind(kind: String) -> String:
	return "quest" if kind == "quests" else kind


## The `kind` header wins (so lua/data/** files work in any directory); else the directory; else the content.
func _detect_kind(parsed: Dictionary, path: String) -> String:
	for pair in [["/quests/", "quest"], ["/dialogue/", "dialogue"], ["/items/", "items"], ["/config/", "config"], ["/recipes/", "recipes"], ["/shops/", "shops"]]:
		if path.contains(pair[0]):
			return pair[1]
	if parsed.has("objectives"):
		return "quest"
	if (parsed["functions"] as Dictionary).has("get_dialogue") or parsed.has("lines"):
		return "dialogue"
	for k in ["config", "items", "recipes", "shops"]:
		if parsed.has(k):
			return k
	return "module"


## Records which file defined an id; a second file defining the same id is reported (the later one wins, as before).
func _claim(domain: String, id: String, sid: String, path: String) -> void:
	var key := "%s:%s" % [domain, id]
	var previous: String = _owner_of.get(key, "")
	if previous != "" and previous != sid:
		data_report.append({"path": path, "line": 0, "rule": "duplicate_id", "token": id, "message": "%s `%s` is already defined by %s (the later file wins)" % [domain, id, previous]})
	_owner_of[key] = sid


func _check_item(item_id: String, def: Variant, path: String) -> void:
	if typeof(def) != TYPE_DICTIONARY:
		return
	var rarity := str((def as Dictionary).get("rarity", ""))
	if rarity != "" and not (rarity in _RARITY_IDS):
		_add_finding(path, 0, "rarity", item_id, "item `%s` has rarity \"%s\", which is not on the ladder (normal uncommon rare unique legendary; `common` is an alias of normal)" % [item_id, rarity])


## `tables = { "a", "b" }` header: every named top-level table has to exist.
func _check_tables_header(script: Dictionary, path: String) -> void:
	var tables: Variant = script.get("tables", null)
	if typeof(tables) == TYPE_ARRAY:
		for table_name in tables:
			if not script.has(str(table_name)):
				_add_finding(path, 0, "tables_header", str(table_name), "the `tables` header names `%s`, but the file has no top-level table of that name" % table_name)


func _add_finding(path: String, line: int, rule: String, token: String, message: String) -> void:
	lint_report.append({"path": path, "line": line, "rule": rule, "token": token, "message": message})


func _print_lint_summary() -> void:
	if not data_report.is_empty():
		print("[Lua] %d data note(s): %s" % [data_report.size(), "; ".join(data_report.map(func(n: Dictionary) -> String: return str(n["message"])))])
	if lint_report.is_empty():
		return
	print("[Lua] %s (LuaRuntime.lint_report; run tools/lua/lint.gd for the list)" % lint_summary())
	var shown := 0
	for f in lint_report:
		if shown >= 12:
			print("[Lua]   ... %d more" % (lint_report.size() - shown))
			break
		print("[Lua]   ", _Lint.format(f))
		shown += 1


func _merge_dict(target: Dictionary, source: Dictionary) -> void:
	for k in source:
		if typeof(source[k]) == TYPE_DICTIONARY and target.has(k) and typeof(target[k]) == TYPE_DICTIONARY:
			_merge_dict(target[k], source[k])
		else:
			target[k] = source[k]


# =============================================================================================== compat (used by tools and tests)

## Legacy helper: parses the top-level table `table_name` of `text` into out[table_name] when the file defines it.
func _extract_named_table(text: String, table_name: String, out: Dictionary) -> void:
	var parsed: Dictionary = _Parser.parse_source(text)
	if parsed.has(table_name) and not (table_name in _RESERVED_KEYS):
		out[table_name] = parsed[table_name]


## Index of the `--` that starts a line comment (outside a string), or -1.
func _find_comment(line: String) -> int:
	var in_str := false
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_str:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				in_str = false
		elif c == "\"" or c == "'":
			in_str = true
			quote = c
		elif c == "-" and i + 1 < line.length() and line[i + 1] == "-":
			return i
		i += 1
	return -1


# =============================================================================================== invoking functions

func _invoke_module_event(sid: String, event: String, payload: Dictionary) -> void:
	var script: Dictionary = _scripts.get(sid, {})
	var fname_candidates := [event, "on_" + event]
	# Friendly aliases used by our quest scripts: quest_accepted -> on_accept, ...
	match event:
		"quest_accepted": fname_candidates.append("on_accept")
		"quest_offered": fname_candidates.append("on_offer")
		"quest_completed": fname_candidates.append("on_complete")
		"quest_failed": fname_candidates.append("on_fail")
		"day_started": fname_candidates.append("on_day_started")
	for fname in fname_candidates:
		if script.get("functions", {}).has(fname):
			_invoke_function(sid, fname, [payload])
			return
	# Fall back to handle_event(event, payload)
	if script.get("functions", {}).has("handle_event"):
		_invoke_function(sid, "handle_event", [event, payload])


func _invoke_module_function(sid: String, fname: String, args: Array) -> Dictionary:
	var script: Dictionary = _scripts.get(sid, {})
	if not script.get("functions", {}).has(fname):
		return {}
	var result: Variant = _invoke_function(sid, fname, args)
	if typeof(result) == TYPE_DICTIONARY:
		return result
	return {}


## Runs the function `fname` of script `sid` with `args` and returns what it returns (nil -> null). A function that is
## missing, or whose body uses something outside the subset, answers null; nothing here raises an engine error.
func _invoke_function(sid: String, fname: String, args: Array) -> Variant:
	var script: Dictionary = _scripts.get(sid, {})
	var func_def: Dictionary = script.get("functions", {}).get(fname, {})
	if func_def.is_empty():
		return null
	var params: Array = func_def.get("params", [])
	var scope := {}
	for i in params.size():
		scope[str(params[i])] = args[i] if i < args.size() else null
	if not func_def.has("ast"):
		func_def["ast"] = _Parser.compile_body(str(func_def.get("body", "")))     # lazily, once
	var outcome: Variant = _exec_block(func_def["ast"], scope)
	if outcome == null:
		return null
	return (outcome as Array)[0]


## Executes a block of statements. Returns null when the block ran to its end, or [value] when a `return` was hit.
func _exec_block(stmts: Array, scope: Dictionary) -> Variant:
	for s in stmts:
		match str(s[0]):
			"local", "assign":
				scope[str(s[1])] = _ev(s[2], scope)
			"call":
				_ev(s[1], scope)
			"if":
				var taken := false
				for branch in s[1]:
					if _truthy(_ev(branch[0], scope)):
						taken = true
						var r: Variant = _exec_block(branch[1], scope)
						if r != null:
							return r
						break
				if not taken and s[2] != null:
					var r2: Variant = _exec_block(s[2], scope)
					if r2 != null:
						return r2
			"return":
				return [null if s[1] == null else _ev(s[1], scope)]
	return null


# =============================================================================================== expression evaluation

func _ev(e: Array, scope: Dictionary) -> Variant:
	match str(e[0]):
		"lit":
			return e[1]
		"var":
			return _lookup(str(e[1]), scope)
		"field":
			return _field(_ev(e[1], scope), str(e[2]))
		"index":
			var base: Variant = _ev(e[1], scope)
			var key: Variant = _ev(e[2], scope)
			if typeof(base) == TYPE_DICTIONARY:
				return (base as Dictionary).get(key if typeof(key) == TYPE_STRING else str(key))
			if typeof(base) == TYPE_ARRAY and typeof(key) == TYPE_INT and int(key) >= 1 and int(key) <= (base as Array).size():
				return base[int(key) - 1]
			return null
		"call":
			var args: Array = []
			for a in e[2]:
				args.append(_ev(a, scope))
			return _call(str(e[1]), args)
		"tbl":
			var v: Variant = e[1]
			if typeof(v) == TYPE_DICTIONARY or typeof(v) == TYPE_ARRAY:
				return v.duplicate(true)
			return v
		"or":
			var l: Variant = _ev(e[1], scope)
			return l if _truthy(l) else _ev(e[2], scope)
		"and":
			var l2: Variant = _ev(e[1], scope)
			return _ev(e[2], scope) if _truthy(l2) else l2
		"not":
			return not _truthy(_ev(e[1], scope))
		"neg":
			var n: Variant = _ev(e[1], scope)
			return -n if (typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT) else null
		"cmp":
			return _compare(str(e[1]), _ev(e[2], scope), _ev(e[3], scope))
		"cat":
			return _tostr(_ev(e[1], scope)) + _tostr(_ev(e[2], scope))
		"unsupported":
			_log_once("unsupported Lua construct (%s) evaluates to nil: see LuaRuntime.lint_report" % str(e[1]))
			return null
	return null


## Name resolution: a local or parameter first, then the world flag of that name (nil when unset).
func _lookup(var_name: String, scope: Dictionary) -> Variant:
	if scope.has(var_name):
		return scope[var_name]
	if var_name == "gold":
		var eco := _node("EconomyManager")
		return eco.get("gold") if eco != null else null
	return lua_get_flag(var_name, null)


func _field(base: Variant, key: String) -> Variant:
	if typeof(base) == TYPE_DICTIONARY:
		return (base as Dictionary).get(key)
	return null


func _call(path: String, args: Array) -> Variant:
	var fname := path.trim_prefix("api.")
	if fname.contains("."):
		_log_once("unsupported Lua call `%s` (library functions are not available): see LuaRuntime.lint_report" % path)
		return null
	return _call_api(fname, args)


## The functions Lua can call (statements and queries): api.<name>(...) or the bare query name.
func _call_api(method: String, args: Array) -> Variant:
	match method:
		"add_gold":
			lua_add_gold(_int_arg(args, 0, 0))
			return null
		"add_item":
			lua_add_item(_str_arg(args, 0), _int_arg(args, 1, 1))
			return null
		"remove_item":
			return lua_remove_item(_str_arg(args, 0), _int_arg(args, 1, 1))
		"set_flag":
			lua_set_flag(_str_arg(args, 0), args[1] if args.size() > 1 else true)
			return null
		"get_flag":
			return lua_get_flag(_str_arg(args, 0), null)
		"has_flag":
			return _truthy(lua_get_flag(_str_arg(args, 0), null))
		"has_item":
			return lua_has_item(_str_arg(args, 0), _int_arg(args, 1, 1))
		"get_gold":
			var eco := _node("EconomyManager")
			return eco.get("gold") if eco != null else 0
		# the social functions (addendum 8.6): late-bound to the SocialManager autoload (S-core), nil and no effect without it
		"get_hearts":
			return _social_call("hearts", [_str_arg(args, 0)], TYPE_INT)
		"add_hearts":
			_social_call("add_hearts", [_str_arg(args, 0), _int_arg(args, 1, 0), &"lua"])
			return null
		"is_birthday":
			return _social_call("is_birthday", [_str_arg(args, 0)], TYPE_BOOL)
		"festival":
			return _social_call("festival_active", [], TYPE_STRING)
		"notification":
			lua_notification(_str_arg(args, 0), _str_arg(args, 1))
			return null
		"unlock_zone":
			lua_unlock_zone(_str_arg(args, 0))
			return null
		"emit":
			lua_emit(_str_arg(args, 0), args[1] if args.size() > 1 and typeof(args[1]) == TYPE_DICTIONARY else {})
			return null
		"log":
			lua_log(_str_arg(args, 0))
			return null
		"offer_quest":
			var qm := _node("QuestManager")
			if qm != null:
				qm.offer_quest(StringName(_str_arg(args, 0)))
			return null
		"complete_quest":
			var qm2 := _node("QuestManager")
			if qm2 != null:
				qm2.complete_quest(StringName(_str_arg(args, 0)))
			return null
	_log_once("unknown Lua function `%s` evaluates to nil (api functions: add_gold add_item remove_item set_flag get_flag has_flag has_item get_gold notification unlock_zone emit log offer_quest complete_quest get_hearts add_hearts is_birthday festival)" % method)
	return null


## Calls `method` of the SocialManager autoload (S-core) and converts the answer to `as_type` (TYPE_INT / TYPE_BOOL / TYPE_STRING;
## TYPE_NIL keeps it as is). null when the autoload is not there or lacks the method: no manager, no answer, nothing is guessed.
func _social_call(method: String, call_args: Array, as_type: int = TYPE_NIL) -> Variant:
	var sm := _node("SocialManager")
	if sm == null or not sm.has_method(method):
		return null
	var answer: Variant = sm.callv(method, call_args)
	match as_type:
		TYPE_INT:
			return int(answer) if _is_number(answer) else null
		TYPE_BOOL:
			return bool(answer) if typeof(answer) == TYPE_BOOL else null
		TYPE_STRING:
			return str(answer) if _is_text(answer) else null
	return answer


# =============================================================================================== value semantics

## Lua truthiness: only nil and false are false.
func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
	return true


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _is_text(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME


## Lua comparison: numbers compare numerically (3 == 3.0), texts as texts, everything else only with its own type;
## a mismatch is simply "not equal" and an order comparison of unlike types is false - never an engine error.
func _compare(op: String, a: Variant, b: Variant) -> bool:
	match op:
		"==":
			return _equal(a, b)
		"~=":
			return not _equal(a, b)
	var comparable := (_is_number(a) and _is_number(b)) or (_is_text(a) and _is_text(b))
	if not comparable:
		_log_once("comparing %s with %s (`%s`) is false in this runtime (Lua would raise an error)" % [type_string(typeof(a)), type_string(typeof(b)), op])
		return false
	var x: Variant = str(a) if _is_text(a) else a
	var y: Variant = str(b) if _is_text(b) else b
	match op:
		"<":
			return x < y
		"<=":
			return x <= y
		">":
			return x > y
		">=":
			return x >= y
	return false


func _equal(a: Variant, b: Variant) -> bool:
	if _is_number(a) and _is_number(b):
		return float(a) == float(b)
	if _is_text(a) and _is_text(b):
		return str(a) == str(b)
	if typeof(a) != typeof(b):
		return false
	return a == b


func _tostr(v: Variant) -> String:
	if v == null:
		return "nil"
	return str(v)


func _int_arg(args: Array, i: int, default_value: int) -> int:
	if i >= args.size():
		return default_value
	var v: Variant = args[i]
	if _is_number(v):
		return int(clampf(float(v), -ARG_INT_LIMIT, ARG_INT_LIMIT))
	if _is_text(v) and str(v).is_valid_float():
		return int(clampf(str(v).to_float(), -ARG_INT_LIMIT, ARG_INT_LIMIT))
	return default_value


func _str_arg(args: Array, i: int) -> String:
	if i >= args.size() or args[i] == null:
		return ""
	return str(args[i])


func _translate(text: String) -> String:
	return tr(text) if text != "" else text


## "%d scripts" style texts: only formatted when the translation really has a placeholder (an untranslated key is not).
func _format_count(text: String, n: int) -> String:
	if text.contains("%d"):
		return text.replace("%d", str(n))
	if text.contains("%s"):
		return text.replace("%s", str(n))
	return "%s (%d)" % [text, n]


func _node(autoload_name: String) -> Node:
	return get_node_or_null("/root/" + autoload_name)


func _log_once(message: String) -> void:
	if _logged_once.has(message):
		return
	_logged_once[message] = true
	print("[Lua] ", message)
