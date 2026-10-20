class_name LuaLint
extends RefCounted
## Load-time lint of the Lua subset the project interprets (LuaRuntime, plan 3.11 / R.2 / addendum 3.8).
## Pure static code on top of LuaTokens: no autoload, no engine warnings, usable from `-s` drivers (tools/lua/lint.gd)
## and from tests. LuaRuntime runs it on every file it loads and keeps the result in LuaRuntime.lint_report.
##
## A finding is {path, line, rule, token, message}. "Lint clean" means lint() returned an empty array.
## Rules (rule id: what it flags):
##   loop             `for` `while` `repeat` `goto` `break`   (`if ... elseif ... else ... end` is part of the subset)
##   long_bracket     `[[ ]]` long strings and `--[[ ]]` block comments
##   local_function   `local function f`          module_function  `function M.f` / `function obj:m`
##   escape           a backslash inside a string (escaped quotes, \n ...)
##   length           the `#` operator             stdlib     `string.` `math.` `table.` `os.` ... and library functions
##   method_call      `obj:method(...)`            vararg     `...`
##   arithmetic       binary `+ - * / % ^ //`      bitwise    `& | ~ << >>`
##   mixed_table      a table with `name = value` AND positional entries (the positional ones are silently dropped)
##   reserved_key     a Lua reserved word as a table key (`{ until = 18 }`: real Lua rejects it; routines use leave / stay / from)
##   table_value      a value of a DATA table (outside a function) that is not a literal (identifier, call, expression:
##                    it is NOT evaluated); a table built inside a function evaluates its values (LuaParser's ctor)
##   nil_value        `nil` as a table value (leave the key out)
##   kind_missing / kind_unknown   the `kind = "..."` header (config items quest dialogue recipes shops registry)
##   unbalanced       `if` / `function` / `do` not closed by `end`, or a stray `end`
##   unterminated_string, stray_character   tokenizer level (`!` `?` `@` `$` and a backslash are stray outside strings)
##   unknown_function a call that is not one of the api functions (API_FUNCTIONS), as `api.name(...)` or bare: a typo answers nil
##   syntax local_list field_assignment function_value unsupported top_level
##                    the grammar findings of LuaParser (see its header): what the parser could not use, so that a file
##                    the subset would run differently from real Lua is never lint clean
## The lint is a DENY-list over the tokens plus the parser's grammar findings; tests/sections/data.gd also runs real Lua's
## `luac -p` over res://lua (data.lua_real_syntax) as an independent gate.

# preload, not the class name: LuaRuntime (an autoload) depends on this script and must compile with a stale class cache
const _Tokens := preload("res://scripts/data/lua_tokens.gd")
const _Parser := preload("res://scripts/data/lua_parser.gd")

const KINDS := ["config", "items", "quest", "quests", "dialogue", "recipes", "shops", "registry"]
const _STDLIB_TABLES := ["string", "math", "table", "os", "io", "utf8", "coroutine", "debug", "package"]
const _STDLIB_FUNCS := [
	"tostring", "tonumber", "ipairs", "pairs", "type", "select", "setmetatable", "getmetatable", "require", "dofile",
	"loadfile", "load", "pcall", "xpcall", "error", "assert", "rawget", "rawset", "rawequal", "next", "unpack", "print",
]
## keywords after which a `-` or `(` is NOT a binary operator position
const _KEYWORDS := [
	"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil",
	"not", "or", "repeat", "return", "then", "true", "until", "while",
]
## what Lua can call (LuaRuntime._call_api): `api.<name>(...)` or the bare name
const API_FUNCTIONS := [
	"add_gold", "add_item", "remove_item", "set_flag", "get_flag", "has_flag", "has_item", "get_gold", "notification",
	"unlock_zone", "emit", "log", "offer_quest", "complete_quest", "get_hearts", "add_hearts", "is_birthday", "festival",
]
const _BINARY_ARITH := ["+", "*", "/", "%", "^", "//"]
const _BITWISE := ["&", "|", "<<", ">>"]


## Lints a source text. `path` is only copied into the findings.
static func lint(source: String, path: String = "") -> Array[Dictionary]:
	var tk := _Tokens.tokenize(source)
	var grammar: Array[Dictionary] = []
	_Parser.parse_tokens(source, tk, path, grammar)
	return lint_tokens(tk, path, grammar)


## lint() on the tokens of a source the caller already has (LuaTokens.tokenize) and the grammar findings the parser collected
## from them (LuaParser.parse_tokens with a findings array): LuaRuntime tokenizes and parses a file once for both.
static func lint_tokens(tk: Dictionary, path: String = "", grammar: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in tk["findings"] as Array:
		out.append(_mk(path, int(f["line"]), str(f["rule"]), str(f["token"]), str(f["message"])))
	for f in grammar:
		out.append(_mk(path, int(f["line"]), str(f["rule"]), str(f["token"]), str(f["message"])))
	_token_rules(tk, path, out)
	_table_rules(tk, path, out)
	_structure_rules(tk, path, out)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["line"] != b["line"]:
			return int(a["line"]) < int(b["line"])
		return str(a["rule"]) < str(b["rule"]))
	return out


## "res://lua/x.lua:12 [else] message" - one line per finding for logs and tools.
static func format(finding: Dictionary) -> String:
	return "%s:%d [%s] %s" % [str(finding.get("path", "")), int(finding.get("line", 0)), str(finding.get("rule", "")), str(finding.get("message", ""))]


## Rule ids of a findings array (unique, sorted) - handy in tests.
static func rules_of(findings: Array) -> Array[String]:
	var seen := {}
	for f in findings:
		seen[str((f as Dictionary).get("rule", ""))] = true
	var out: Array[String] = []
	for k in seen:
		out.append(str(k))
	out.sort()
	return out


static func _mk(path: String, line: int, rule: String, token: String, message: String) -> Dictionary:
	return {"path": path, "line": line, "rule": rule, "token": token, "message": message}


# ------------------------------------------------------------------------------------------------ token rules

static func _token_rules(tk: Dictionary, path: String, out: Array[Dictionary]) -> void:
	var count: int = tk["count"]
	var types: PackedInt32Array = tk["type"]
	var texts: PackedStringArray = tk["text"]
	var lines: PackedInt32Array = tk["line"]
	for i in count:
		var t := texts[i]
		var ty := types[i]
		var ln := lines[i]
		if ty == _Tokens.NAME:
			match t:
				"for", "while", "repeat", "goto", "break":
					out.append(_mk(path, ln, "loop", t, "`%s` is not supported: Lua data files have no loops or jumps" % t))
				"local":
					if i + 1 < count and types[i + 1] == _Tokens.NAME and texts[i + 1] == "function":
						out.append(_mk(path, ln, "local_function", "local function", "`local function` is not supported: use a top-level `function name(...)` or inline the logic"))
				"function":
					if i + 2 < count and types[i + 1] == _Tokens.NAME and types[i + 2] == _Tokens.OP and (texts[i + 2] == "." or texts[i + 2] == ":"):
						out.append(_mk(path, ln, "module_function", "function %s%s" % [texts[i + 1], texts[i + 2]], "module-style `function M.f` / `function obj:m` is not supported: use top-level `function name(...)`"))
				_:
					if (t in _STDLIB_TABLES) and i + 1 < count and types[i + 1] == _Tokens.OP and (texts[i + 1] == "." or texts[i + 1] == ":") and not _after_dot(types, texts, i):
						out.append(_mk(path, ln, "stdlib", t + ".", "`%s.` (Lua standard library) is not available in the interpreted subset" % t))
					elif (t in _STDLIB_FUNCS) and i + 1 < count and types[i + 1] == _Tokens.OP and texts[i + 1] == "(" and not _after_dot(types, texts, i) and not _after_function_kw(types, texts, i):
						out.append(_mk(path, ln, "stdlib", t, "`%s(...)` (Lua standard library) is not available in the interpreted subset" % t))
					elif i + 1 < count and types[i + 1] == _Tokens.OP and texts[i + 1] == "(" and not (t in _KEYWORDS):
						_call_rule(types, texts, i, path, ln, out)
		elif ty == _Tokens.OP:
			if t == "#":
				out.append(_mk(path, ln, "length", "#", "the length operator `#` is not supported"))
			elif t == "..." :
				out.append(_mk(path, ln, "vararg", "...", "varargs are not supported"))
			elif t in _BINARY_ARITH:
				out.append(_mk(path, ln, "arithmetic", t, "arithmetic (`%s`) is not supported in statements: compute the value into the data instead" % t))
			elif t == "-":
				if i > 0 and _ends_operand(types, texts, i - 1):
					out.append(_mk(path, ln, "arithmetic", "-", "arithmetic (`-`) is not supported in statements: compute the value into the data instead"))
			elif t in _BITWISE or t == "~":
				out.append(_mk(path, ln, "bitwise", t, "bitwise operators are not supported"))
			elif t == ":":
				# obj:method(...) call (function definitions are reported by module_function)
				if i > 0 and i + 2 < count and types[i + 1] == _Tokens.NAME and texts[i + 2] == "(" and (types[i - 1] == _Tokens.NAME or types[i - 1] == _Tokens.STRING or texts[i - 1] == ")" or texts[i - 1] == "]") and not _after_function_kw(types, texts, i - 1):
					out.append(_mk(path, ln, "method_call", ":" + texts[i + 1], "method calls (`obj:method(...)`) are not supported"))


## `name(` at token `i`: an api function (`api.name(` or bare `name(`) is fine; a definition (`function name(`), a method call
## and the standard library have their own rules; every other call is unknown_function (the runtime would answer nil).
static func _call_rule(types: PackedInt32Array, texts: PackedStringArray, i: int, path: String, ln: int, out: Array[Dictionary]) -> void:
	var t := texts[i]
	if _after_function_kw(types, texts, i) or (i > 0 and types[i - 1] == _Tokens.OP and texts[i - 1] == ":"):
		return
	if not _after_dot(types, texts, i):
		if not (t in API_FUNCTIONS):
			out.append(_mk(path, ln, "unknown_function", t, "`%s(...)` is not an api function: it answers nil (the api functions: %s)" % [t, " ".join(API_FUNCTIONS)]))
		return
	# a dotted call: only api.<name>, and only a two-part path (`a.b.c(` and `x.api.f(` are not api calls)
	var base := texts[i - 2] if i >= 2 and types[i - 2] == _Tokens.NAME else ""
	if base in _STDLIB_TABLES or (i >= 3 and _after_function_kw(types, texts, i - 2)):
		return                                 # the stdlib / module_function rules
	if base == "api" and not _after_dot(types, texts, i - 2):
		if not (t in API_FUNCTIONS):
			out.append(_mk(path, ln, "unknown_function", "api." + t, "`api.%s` is not an api function: it answers nil (the api functions: %s)" % [t, " ".join(API_FUNCTIONS)]))
		return
	out.append(_mk(path, ln, "unknown_function", t, "only `api.<name>(...)` can be called, not `...%s(...)`: it answers nil" % t))


static func _after_dot(types: PackedInt32Array, texts: PackedStringArray, i: int) -> bool:
	return i > 0 and types[i - 1] == _Tokens.OP and (texts[i - 1] == "." or texts[i - 1] == ":")


static func _after_function_kw(types: PackedInt32Array, texts: PackedStringArray, i: int) -> bool:
	return i > 0 and types[i - 1] == _Tokens.NAME and texts[i - 1] == "function"


## true when token `i` ends an operand, so a following `-` is a binary minus (not a sign)
static func _ends_operand(types: PackedInt32Array, texts: PackedStringArray, i: int) -> bool:
	match types[i]:
		_Tokens.NUMBER, _Tokens.STRING:
			return true
		_Tokens.NAME:
			var t := texts[i]
			return t == "true" or t == "false" or t == "nil" or not (t in _KEYWORDS)
		_Tokens.OP:
			return texts[i] == ")" or texts[i] == "]" or texts[i] == "}"
	return false


# ------------------------------------------------------------------------------------------------ table rules

## Every table constructor; one inside a function body is an expression whose values are evaluated (no table_value there).
static func _table_rules(tk: Dictionary, path: String, out: Array[Dictionary]) -> void:
	var count: int = tk["count"]
	var types: PackedInt32Array = tk["type"]
	var texts: PackedStringArray = tk["text"]
	var blocks: Array[bool] = []               # every open function / if / do: true for a function
	var functions := 0
	var i := 0
	while i < count:
		if types[i] == _Tokens.OP and texts[i] == "{":
			i = _table(tk, i, path, out, functions > 0)
			continue
		if types[i] == _Tokens.NAME:
			var t := texts[i]
			if t == "function":
				blocks.append(true)
				functions += 1
			elif t == "if" or t == "do":
				blocks.append(false)
			elif t == "end" and not blocks.is_empty() and blocks.pop_back():
				functions -= 1
		i += 1


## Checks one table constructor that starts at token `i` ("{"); returns the index after its closing "}". `evaluated`: the
## table is built inside a function, so a value may be any expression.
static func _table(tk: Dictionary, i: int, path: String, out: Array[Dictionary], evaluated: bool = false) -> int:
	var count: int = tk["count"]
	var types: PackedInt32Array = tk["type"]
	var texts: PackedStringArray = tk["text"]
	var lines: PackedInt32Array = tk["line"]
	var named := 0
	var positional := 0
	var j := i + 1
	while j < count:
		if types[j] == _Tokens.OP:
			if texts[j] == "}":
				j += 1
				break
			if texts[j] == "," or texts[j] == ";":
				j += 1
				continue
		if types[j] == _Tokens.NAME and j + 1 < count and types[j + 1] == _Tokens.OP and texts[j + 1] == "=":
			if texts[j] in _KEYWORDS:
				out.append(_mk(path, lines[j], "reserved_key", texts[j], _reserved_key_message(texts[j])))
			named += 1
			j = _value(tk, j + 2, path, out, evaluated)
		elif types[j] == _Tokens.OP and texts[j] == "[":
			var close := _matching(tk, j)
			if close > 0 and close + 1 < count and types[close + 1] == _Tokens.OP and texts[close + 1] == "=":
				named += 1
				j = _value(tk, close + 2, path, out, evaluated)
			else:
				positional += 1
				j = _value(tk, j, path, out, evaluated)
		else:
			positional += 1
			j = _value(tk, j, path, out, evaluated)
	if named > 0 and positional > 0:
		out.append(_mk(path, lines[i], "mixed_table", "{", "table mixes `name = value` and positional entries: the positional entries are silently dropped"))
	return j


static func _reserved_key_message(word: String) -> String:
	var hint := " (routine blocks use leave / stay / from)" if word == "until" else ""
	return "`%s` is a reserved word of Lua and cannot name a table field (real Lua rejects `%s = ...`): pick another name%s or write `[\"%s\"] = ...`" % [word, word, hint, word]


## Checks the value that starts at token `j`; returns the index of the token that ends it ("," ";" or "}", not consumed).
static func _value(tk: Dictionary, j: int, path: String, out: Array[Dictionary], evaluated: bool = false) -> int:
	var count: int = tk["count"]
	if j >= count:
		return count
	var types: PackedInt32Array = tk["type"]
	var texts: PackedStringArray = tk["text"]
	var lines: PackedInt32Array = tk["line"]
	var ty := types[j]
	var t := texts[j]
	var k := j
	var literal := false
	if ty == _Tokens.OP and t == "{":
		k = _table(tk, j, path, out, evaluated)
		literal = true
	elif ty == _Tokens.STRING or ty == _Tokens.NUMBER:
		k = j + 1
		literal = true
	elif ty == _Tokens.OP and t == "-" and j + 1 < count and types[j + 1] == _Tokens.NUMBER:
		k = j + 2
		literal = true
	elif ty == _Tokens.NAME and (t == "true" or t == "false"):
		k = j + 1
		literal = true
	elif ty == _Tokens.NAME and t == "nil":
		out.append(_mk(path, lines[j], "nil_value", "nil", "`nil` as a table value is not supported: leave the key out"))
		return _skip_value(tk, j + 1)
	if literal and (k >= count or (types[k] == _Tokens.OP and (texts[k] == "," or texts[k] == ";" or texts[k] == "}"))):
		return k
	if evaluated:
		return _skip_value(tk, k)              # an expression: the token rules and the parser check it
	out.append(_mk(path, lines[j], "table_value", t, "table values must be literals (string, number, true, false, table): identifiers, calls and expressions are not evaluated"))
	return _skip_value(tk, k)


## Skips the rest of a value expression: stops at "," ";" or "}" outside any ( [ { nesting.
static func _skip_value(tk: Dictionary, from: int) -> int:
	var count: int = tk["count"]
	var types: PackedInt32Array = tk["type"]
	var texts: PackedStringArray = tk["text"]
	var depth := 0
	var j := from
	while j < count:
		if types[j] == _Tokens.OP:
			var t := texts[j]
			if t == "(" or t == "[" or t == "{":
				depth += 1
			elif t == ")" or t == "]":
				depth -= 1
			elif t == "}":
				if depth == 0:
					return j
				depth -= 1
			elif (t == "," or t == ";") and depth <= 0:
				return j
		j += 1
	return count


## index of the bracket that closes the "[" / "(" / "{" at token `i`, or -1
static func _matching(tk: Dictionary, i: int) -> int:
	var count: int = tk["count"]
	var types: PackedInt32Array = tk["type"]
	var texts: PackedStringArray = tk["text"]
	var depth := 0
	for j in range(i, count):
		if types[j] != _Tokens.OP:
			continue
		var t := texts[j]
		if t == "[" or t == "(" or t == "{":
			depth += 1
		elif t == "]" or t == ")" or t == "}":
			depth -= 1
			if depth == 0:
				return j
	return -1


# ------------------------------------------------------------------------------------------------ structure rules

static func _structure_rules(tk: Dictionary, path: String, out: Array[Dictionary]) -> void:
	var count: int = tk["count"]
	var types: PackedInt32Array = tk["type"]
	var texts: PackedStringArray = tk["text"]
	var lines: PackedInt32Array = tk["line"]
	var stack: Array[int] = []              # line of every open if / function / do
	var brace := 0
	var kind_value := ""
	var kind_line := 0
	var kind_seen := false
	for i in count:
		var ty := types[i]
		var t := texts[i]
		if ty == _Tokens.NAME:
			if t == "function" or t == "if" or t == "do":
				stack.append(lines[i])
			elif t == "end":
				if stack.is_empty():
					out.append(_mk(path, lines[i], "unbalanced", "end", "`end` without an open `if` / `function` / `do`"))
				else:
					stack.pop_back()
			elif t == "kind" and not kind_seen and stack.is_empty() and brace == 0 and i + 2 < count and types[i + 1] == _Tokens.OP and texts[i + 1] == "=" and types[i + 2] == _Tokens.STRING and not _after_dot(types, texts, i):
				kind_seen = true
				kind_value = texts[i + 2]
				kind_line = lines[i]
		elif ty == _Tokens.OP:
			if t == "{":
				brace += 1
			elif t == "}":
				brace -= 1
	for open_line in stack:
		out.append(_mk(path, open_line, "unbalanced", "if/function/do", "this block is not closed by `end`"))
	if not kind_seen:
		out.append(_mk(path, 1, "kind_missing", "kind", "no top-level `kind = \"...\"` header (config, items, quest, dialogue, recipes, shops or registry)"))
	elif not (kind_value in KINDS):
		out.append(_mk(path, kind_line, "kind_unknown", kind_value, "unknown kind \"%s\" (expected one of: config, items, quest, dialogue, recipes, shops, registry)" % kind_value))
