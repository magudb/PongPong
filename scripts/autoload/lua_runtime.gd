extends Node
## Bridge to Lua for quests, dialogue, items, and game rules.
##
## Uses a pure-GDScript Lua-subset interpreter fallback so the game runs
## without GDExtension. When a real Lua GDExtension (e.g. GodotLuaAPI)
## is installed, swap `_lua_*` internals — the public API stays stable.
##
## Lua files are loaded from res://lua/** at boot and can be hot-reloaded
## with `reload_scripts()`.

const LUA_ROOT := "res://lua"
const API_VERSION := 1

var _scripts: Dictionary = {}          # script_id -> parsed script dict
var _quest_modules: Dictionary = {}    # quest_id -> script_id
var _dialogue_modules: Dictionary = {} # dialogue_id -> script_id
var _item_defs: Dictionary = {}        # item_id -> def
var _config: Dictionary = {}
var _env: Dictionary = {}              # shared Lua-visible globals
var _hot_reload_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload_scripts()
	if _hot_reload_enabled and OS.is_debug_build():
		_watch_for_changes()


## ---------------------------------------------------------------------------
## Public API used by GDScript
## ---------------------------------------------------------------------------

func reload_scripts() -> void:
	_scripts.clear()
	_quest_modules.clear()
	_dialogue_modules.clear()
	_item_defs.clear()
	_config.clear()
	_scan_dir(LUA_ROOT)
	_register_all()
	EventBus.notification_posted.emit(
		tr("NOTIF_LUA_RELOADED_TITLE"),
		tr("NOTIF_LUA_RELOADED_MSG") % _scripts.size(),
		"lua"
	)


func call_quest_event(quest_id: String, event: String, payload: Dictionary = {}) -> void:
	var sid: String = _quest_modules.get(quest_id, "")
	if sid == "":
		return
	_invoke_module_event(sid, event, payload)


func get_dialogue(dialogue_id: String, context: Dictionary = {}) -> Dictionary:
	var sid: String = _dialogue_modules.get(dialogue_id, "")
	if sid == "":
		return {}
	return _invoke_module_function(sid, "get_dialogue", [context])


func get_item_def(item_id: String) -> Dictionary:
	return _item_defs.get(item_id, {})


func get_config(path: String, default_value: Variant = null) -> Variant:
	var parts := path.split(".")
	var cur: Variant = _config
	for p in parts:
		if typeof(cur) == TYPE_DICTIONARY and cur.has(p):
			cur = cur[p]
		else:
			return default_value
	return cur


## Called from Lua scripts via bound helpers
func lua_log(msg: String) -> void:
	print("[Lua] ", msg)


func lua_emit(event_name: String, payload: Dictionary = {}) -> void:
	EventBus.emit_lua_event(StringName(event_name), payload)


func lua_get_flag(flag: String, default_value: Variant = false) -> Variant:
	return GameManager.get_flag(StringName(flag), default_value)


func lua_set_flag(flag: String, value: Variant) -> void:
	GameManager.set_flag(StringName(flag), value)


func lua_add_gold(amount: int) -> void:
	EconomyManager.add_gold(amount)


func lua_add_item(item_id: String, amount: int = 1) -> void:
	EconomyManager.add_item(StringName(item_id), amount)


func lua_remove_item(item_id: String, amount: int = 1) -> bool:
	return EconomyManager.remove_item(StringName(item_id), amount)


func lua_has_item(item_id: String, amount: int = 1) -> bool:
	return EconomyManager.has_item(StringName(item_id), amount)


func lua_notification(title: String, message: String) -> void:
	EventBus.notification_posted.emit(title, message, "lua")


func lua_unlock_zone(zone_id: String) -> void:
	GameManager.unlock_zone(StringName(zone_id))


## ---------------------------------------------------------------------------
## Script loading & registration
## ---------------------------------------------------------------------------

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_scan_dir(full)
		elif name.get_extension() == "lua":
			_load_script(full)
		name = dir.get_next()
	dir.list_dir_end()


func _load_script(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Kunne ikke indlæse Lua-fil: %s" % path)
		return
	var source := file.get_as_text()
	file.close()
	var parsed := parse_lua_source(source, path)
	if parsed.is_empty():
		push_error("Lua-parsing fejlede: %s" % path)
		return
	var sid := path.trim_prefix("res://lua/").trim_suffix(".lua")
	_scripts[sid] = parsed


func _register_all() -> void:
	for sid in _scripts:
		var script: Dictionary = _scripts[sid]
		var kind: String = script.get("kind", "")
		match kind:
			"quest":
				var qid: String = script.get("id", sid)
				_quest_modules[qid] = sid
				QuestManager.register_quest_from_lua(script)
			"dialogue":
				var did: String = script.get("id", sid)
				_dialogue_modules[did] = sid
			"items":
				var defs: Variant = script.get("items", {})
				if typeof(defs) == TYPE_DICTIONARY:
					for item_id in defs:
						_item_defs[item_id] = defs[item_id]
			"config":
				var cfg: Variant = script.get("config", {})
				if typeof(cfg) == TYPE_DICTIONARY:
					_merge_dict(_config, cfg)


## ---------------------------------------------------------------------------
## Minimal Lua-subset parser & evaluator
## Supports the syntax used in our quest/dialogue scripts.
## ---------------------------------------------------------------------------

func parse_lua_source(source: String, path: String = "") -> Dictionary:
	var out := {
		"kind": "",
		"id": "",
		"functions": {},
		"table_assigns": {},
		"source_path": path,
	}
	# Strip comments
	var lines := source.split("\n")
	var cleaned: Array[String] = []
	for line in lines:
		var comment_idx := _find_comment(line)
		if comment_idx >= 0:
			line = line.substr(0, comment_idx)
		cleaned.append(line)

	var text := "\n".join(cleaned)

	# Detect module style: return { ... } or local M = { ... } return M
	if text.contains("return {") or text.contains("return M"):
		out["kind"] = _detect_kind(text, path)

	# Extract top-level function definitions
	var func_regex := RegEx.new()
	func_regex.compile("function\\s+([\\w_%.:]+)\\s*\\(([^)]*)\\)\\s*\\n([\\s\\S]*?)\\nend\\b")
	for m in func_regex.search_all(text):
		var fname := m.get_string(1)
		var fparams := m.get_string(2)
		var fbody := m.get_string(3)
		out["functions"][fname] = {
			"params": _split_params(fparams),
			"body": fbody.strip_edges(),
		}

	# Extract simple top-level table field assignments like id = "quest_x"
	var field_regex := RegEx.new()
	field_regex.compile("(?m)^([\\w_]+)\\s*=\\s*(\"[^\"]*\"|'[^']*'|[\\d\\.]+|true|false)")
	for m in field_regex.search_all(text):
		var key := m.get_string(1)
		var raw := m.get_string(2)
		out["table_assigns"][key] = _parse_lua_literal(raw)

	# Promote well-known fields
	if out["table_assigns"].has("id"):
		out["id"] = str(out["table_assigns"]["id"])
	if out["table_assigns"].has("kind"):
		out["kind"] = str(out["table_assigns"]["kind"])
	if out["kind"] == "":
		out["kind"] = _detect_kind(text, path)

	# Extract objectives / rewards / items blocks as Lua tables (best-effort)
	_extract_named_table(text, "objectives", out)
	_extract_named_table(text, "rewards", out)
	_extract_named_table(text, "items", out)
	_extract_named_table(text, "config", out)
	_extract_named_table(text, "lines", out)
	_extract_named_table(text, "choices", out)
	_extract_named_table(text, "meta", out)

	return out


func _detect_kind(text: String, path: String) -> String:
	if path.contains("/quests/"):
		return "quest"
	if path.contains("/dialogue/"):
		return "dialogue"
	if path.contains("/items/"):
		return "items"
	if path.contains("/config/"):
		return "config"
	if text.contains("objectives"):
		return "quest"
	if text.contains("get_dialogue") or text.contains("lines"):
		return "dialogue"
	return "module"


func _extract_named_table(text: String, table_name: String, out: Dictionary) -> void:
	var regex := RegEx.new()
	regex.compile("\\b%s\\s*=" % table_name)
	var m := regex.search(text)
	if m == null:
		return
	# Locate the opening brace of the assigned table and match it with its
	# closing brace so nested tables don't terminate the block early.
	var open_pos := text.find("{", m.get_end())
	if open_pos == -1:
		return
	var block := _extract_balanced(text, open_pos)
	if block.is_empty():
		return
	out[table_name] = _parse_lua_table_body(block["body"])


## Returns {"body": inner_text, "end": closing_index} for the brace pair
## starting at open_pos, or {} if unbalanced. Strings are respected.
func _extract_balanced(text: String, open_pos: int) -> Dictionary:
	var depth := 0
	var in_str := false
	var quote := ""
	for i in range(open_pos, text.length()):
		var c := text[i]
		if in_str:
			if c == quote:
				in_str = false
		elif c == "\"" or c == "'":
			in_str = true
			quote = c
		elif c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				return {"body": text.substr(open_pos + 1, i - open_pos - 1), "end": i}
	return {}


## Splits on commas at brace depth 0, ignoring commas inside strings.
func _split_top_level(body: String) -> Array[String]:
	var out: Array[String] = []
	var depth := 0
	var in_str := false
	var quote := ""
	var start := 0
	for i in body.length():
		var c := body[i]
		if in_str:
			if c == quote:
				in_str = false
		elif c == "\"" or c == "'":
			in_str = true
			quote = c
		elif c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
		elif c == "," and depth == 0:
			out.append(body.substr(start, i - start))
			start = i + 1
	out.append(body.substr(start))
	return out


## Finds the first occurrence of ch at brace depth 0 outside strings.
func _find_top_level_char(text: String, ch: String) -> int:
	var depth := 0
	var in_str := false
	var quote := ""
	for i in text.length():
		var c := text[i]
		if in_str:
			if c == quote:
				in_str = false
		elif c == "\"" or c == "'":
			in_str = true
			quote = c
		elif c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
		elif c == ch and depth == 0:
			return i
	return -1


func _parse_lua_table_body(body: String) -> Variant:
	var dict := {}
	var positional: Array = []
	for entry in _split_top_level(body):
		entry = entry.strip_edges()
		if entry == "":
			continue
		var eq := _find_top_level_char(entry, "=")
		if eq > 0:
			var key := entry.substr(0, eq).strip_edges()
			key = key.trim_prefix("[").trim_suffix("]").strip_edges()
			if (key.begins_with("\"") and key.ends_with("\"")) or (key.begins_with("'") and key.ends_with("'")):
				key = key.substr(1, key.length() - 2)
			dict[key] = _parse_lua_value(entry.substr(eq + 1))
		elif entry.begins_with("{"):
			positional.append(_parse_lua_table_body(_outer_brace_content(entry)))
		else:
			positional.append(_parse_lua_literal(entry))
	if not dict.is_empty():
		return dict
	return positional


func _parse_lua_value(raw: String) -> Variant:
	raw = raw.strip_edges()
	if raw.begins_with("{"):
		return _parse_lua_table_body(_outer_brace_content(raw))
	return _parse_lua_literal(raw)


func _parse_lua_literal(raw: String) -> Variant:
	raw = raw.strip_edges()
	if raw.begins_with("\"") or raw.begins_with("'"):
		return raw.substr(1, raw.length() - 2)
	if raw == "true":
		return true
	if raw == "false":
		return false
	if raw.is_valid_int():
		return raw.to_int()
	if raw.is_valid_float():
		return raw.to_float()
	return raw


func _split_params(params: String) -> Array[String]:
	var out: Array[String] = []
	for p in params.split(","):
		var s := p.strip_edges()
		if s != "":
			out.append(s)
	return out


func _find_comment(line: String) -> int:
	var in_str := false
	var quote := ""
	for i in line.length():
		var c := line[i]
		if in_str:
			if c == quote:
				in_str = false
		elif c == "\"" or c == "'":
			in_str = true
			quote = c
		elif c == "-" and i + 1 < line.length() and line[i + 1] == "-":
			return i
	return -1


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


func _invoke_function(sid: String, fname: String, args: Array) -> Variant:
	var script: Dictionary = _scripts.get(sid, {})
	var func_def: Dictionary = script.get("functions", {}).get(fname, {})
	if func_def.is_empty():
		return null

	var body: String = func_def.get("body", "")
	var params: Array = func_def.get("params", [])

	# Build local scope
	var scope := {
		"self": script,
		"game": _env,
		"api": self,
	}
	for i in params.size():
		scope[params[i]] = args[i] if i < args.size() else null

	# Handle common Lua patterns used in our scripts
	return _eval_lua_body(body, scope, script)


func _eval_lua_body(body: String, scope: Dictionary, script: Dictionary) -> Variant:
	# Evaluate `local name = expr` declarations into the scope first.
	var local_re := RegEx.new()
	local_re.compile("(?m)^[ \\t]*local\\s+([\\w_]+)\\s*=\\s*(.+)$")
	for lm in local_re.search_all(body):
		scope[lm.get_string(1)] = _eval_expr(lm.get_string(2), scope)

	# Resolve `if cond then ... end` branches by evaluating the guard, then
	# recurse into the taken branch (or the code following the block).
	var if_re := RegEx.new()
	if_re.compile("\\bif\\s+(.+?)\\s*then\\s*\\n([\\s\\S]*?)\\n[ \\t]*end\\b")
	var im := if_re.search(body)
	if im != null:
		var branch := im.get_string(2) if _eval_condition(im.get_string(1), scope) else body.substr(im.get_end())
		return _eval_lua_body(branch, scope, script)

	# Run side-effect statements (api.* calls) — they precede any return.
	_exec_lua_statements(body, scope)

	# return <expr> pattern — tables, expressions, literals
	var return_regex := RegEx.new()
	return_regex.compile("return\\s+([\\s\\S]+)")
	var m := return_regex.search(body)
	if m:
		var raw := m.get_string(1).strip_edges()
		if raw.begins_with("{"):
			return _parse_lua_table_body(_outer_brace_content(raw))
		return _eval_expr(raw, scope)

	return null


func _outer_brace_content(raw: String) -> String:
	if raw.begins_with("{") and raw.ends_with("}"):
		return raw.substr(1, raw.length() - 2)
	return raw


func _exec_lua_statements(body: String, scope: Dictionary) -> void:
	var line_regex := RegEx.new()
	line_regex.compile("(?m)^[ \\t]*(api\\.[\\w_]+)\\s*\\(([^)]*)\\)")
	for m in line_regex.search_all(body):
		var method := m.get_string(1).trim_prefix("api.")
		var arg_str := m.get_string(2)
		var args := _parse_call_args(arg_str, scope)
		_call_api(method, args)


func _parse_call_args(arg_str: String, scope: Dictionary) -> Array:
	var out: Array = []
	for part in _split_top_level(arg_str):
		var s := part.strip_edges()
		if s == "":
			continue
		out.append(_eval_expr(s, scope))
	return out


func _eval_condition(cond: String, scope: Dictionary) -> bool:
	return bool(_eval_expr(cond.strip_edges(), scope))


## Finds the first occurrence of any token in `tokens` outside of string
## literals. Returns [index, token] or [-1, ""].
func _find_op_outside_strings(expr: String, tokens: Array) -> Array:
	var in_str := false
	var quote := ""
	var i := 0
	while i < expr.length():
		var c := expr[i]
		if in_str:
			if c == quote:
				in_str = false
			i += 1
			continue
		if c == "\"" or c == "'":
			in_str = true
			quote = c
			i += 1
			continue
		for t in tokens:
			if expr.substr(i, String(t).length()) == t:
				return [i, t]
		i += 1
	return [-1, ""]


## Evaluates a small Lua-subset expression: literals, scope vars, dotted paths
## (context.x), api.* calls, `..` concat, comparisons, `not`, `or`.
func _eval_expr(expr: String, scope: Dictionary) -> Variant:
	expr = expr.strip_edges()
	if expr == "":
		return null

	# `a or b` — first truthy operand wins, last is the fallback.
	var and_hit := _find_op_outside_strings(expr, [" and "])
	if and_hit[0] >= 0:
		var alv: Variant = _eval_expr(expr.substr(0, and_hit[0]), scope)
		if not alv:
			return false
		return _eval_expr(expr.substr(and_hit[0] + 5), scope)

	var or_hit := _find_op_outside_strings(expr, [" or "])
	if or_hit[0] >= 0:
		var lv: Variant = _eval_expr(expr.substr(0, or_hit[0]), scope)
		if lv:
			return lv
		return _eval_expr(expr.substr(or_hit[0] + 4), scope)

	if expr.begins_with("not "):
		return not _eval_expr(expr.substr(4), scope)

	# Comparisons (longest operators first so >= matches before >).
	var cmp_hit := _find_op_outside_strings(expr, ["==", "~=", ">=", "<=", ">", "<"])
	if cmp_hit[0] >= 0:
		var l: Variant = _eval_expr(expr.substr(0, cmp_hit[0]), scope)
		var r: Variant = _eval_expr(expr.substr(cmp_hit[0] + String(cmp_hit[1]).length()), scope)
		match cmp_hit[1]:
			"==": return l == r
			"~=": return l != r
			">=": return l >= r
			"<=": return l <= r
			">": return l > r
			"<": return l < r

	# String concatenation: "a" .. b
	var cat_hit := _find_op_outside_strings(expr, [" .. "])
	if cat_hit[0] >= 0:
		var lstr := str(_eval_expr(expr.substr(0, cat_hit[0]), scope))
		var rstr := str(_eval_expr(expr.substr(cat_hit[0] + 4), scope))
		return lstr + rstr

	# api.method(...) and bare query calls in expression position
	var call_re := RegEx.new()
	call_re.compile("^(?:api\\.)?([\\w_]+)\\s*\\((.*)\\)$")
	var cr := call_re.search(expr)
	if cr:
		var cargs := _parse_call_args(cr.get_string(2), scope)
		return _eval_query(cr.get_string(1), cargs)

	# Whole-expression literal: quoted string, number, boolean, nil.
	if (expr.begins_with("\"") and expr.ends_with("\"") and expr.length() > 1) \
			or (expr.begins_with("'") and expr.ends_with("'") and expr.length() > 1) \
			or expr.is_valid_int() or expr.is_valid_float() \
			or expr == "true" or expr == "false" or expr == "nil":
		return null if expr == "nil" else _parse_lua_literal(expr)

	# Dotted paths into dictionaries (context.lost_cat_active, self.x, ...)
	if expr.contains("."):
		var parts := expr.split(".")
		var cur: Variant = scope.get(parts[0], null)
		for i in range(1, parts.size()):
			if typeof(cur) != TYPE_DICTIONARY:
				return null
			cur = cur.get(parts[i])
		return cur

	if scope.has(expr):
		return scope[expr]
	if expr == "gold":
		return EconomyManager.gold
	if expr.is_valid_identifier():
		return GameManager.get_flag(StringName(expr), false)
	return _parse_lua_literal(expr)


## Read-only queries Lua expressions can use: has_flag, has_item, get_gold.
func _eval_query(method: String, args: Array) -> Variant:
	match method:
		"has_flag":
			return GameManager.get_flag(StringName(str(args[0])), false) if args.size() > 0 else false
		"has_item":
			return EconomyManager.has_item(StringName(str(args[0])), int(args[1]) if args.size() > 1 else 1) if args.size() > 0 else false
		"get_gold":
			return EconomyManager.gold
	return null


func _call_api(method: String, args: Array) -> void:
	match method:
		"add_gold": lua_add_gold(int(args[0]) if args.size() > 0 else 0)
		"add_item": lua_add_item(str(args[0]), int(args[1]) if args.size() > 1 else 1)
		"remove_item": lua_remove_item(str(args[0]), int(args[1]) if args.size() > 1 else 1)
		"set_flag": lua_set_flag(str(args[0]), args[1] if args.size() > 1 else true)
		"notification": lua_notification(str(args[0]) if args.size() > 0 else "", str(args[1]) if args.size() > 1 else "")
		"unlock_zone": lua_unlock_zone(str(args[0]) if args.size() > 0 else "")
		"emit": lua_emit(str(args[0]) if args.size() > 0 else "")
		"log": lua_log(str(args[0]) if args.size() > 0 else "")
		"offer_quest": QuestManager.offer_quest(StringName(str(args[0])))
		"complete_quest": QuestManager.complete_quest(StringName(str(args[0])))
		_:
			push_warning("Ukendt Lua API-kald: %s" % method)


func _merge_dict(target: Dictionary, source: Dictionary) -> void:
	for k in source:
		if typeof(source[k]) == TYPE_DICTIONARY and target.has(k) and typeof(target[k]) == TYPE_DICTIONARY:
			_merge_dict(target[k], source[k])
		else:
			target[k] = source[k]


func _watch_for_changes() -> void:
	# Lightweight poll — full FileSystemWatcher needs editor tooling
	pass


## Expose parsed scripts for tooling/debug
func get_all_script_ids() -> Array:
	return _scripts.keys()
