class_name LuaLint
extends RefCounted
## Load-time lint of the Lua subset the project interprets (LuaRuntime, plan 3.11 / R.2 / addendum 3.8).
## Pure static code on top of LuaTokens: no autoload, no engine warnings, usable from `-s` drivers (tools/lua/lint.gd)
## and from tests. LuaRuntime runs it on every file it loads and keeps the result in LuaRuntime.lint_report.
##
## A finding is {path, line, rule, token, message}. "Lint clean" means lint() returned an empty array.
## Rules (rule id: what it flags):
##   else elseif      `else` / `elseif`            loop       `for` `while` `repeat` `goto`
##   long_bracket     `[[ ]]` long strings and `--[[ ]]` block comments
##   local_function   `local function f`          module_function  `function M.f` / `function obj:m`
##   escape           a backslash inside a string (escaped quotes, \n ...)
##   length           the `#` operator             stdlib     `string.` `math.` `table.` `os.` ... and library functions
##   method_call      `obj:method(...)`            vararg     `...`
##   arithmetic       binary `+ - * / % ^ //`      bitwise    `& | ~ << >>`
##   mixed_table      a table with `name = value` AND positional entries (the positional ones are silently dropped)
##   table_value      a table value that is not a literal (identifier, call, expression: it is NOT evaluated)
##   nil_value        `nil` as a table value (leave the key out)
##   kind_missing / kind_unknown   the `kind = "..."` header
##   unbalanced       `if` / `function` / `do` not closed by `end`, or a stray `end`
##   unterminated_string, stray_character   tokenizer level

# preload, not the class name: LuaRuntime (an autoload) depends on this script and must compile with a stale class cache
const _Tokens := preload("res://scripts/data/lua_tokens.gd")

const KINDS := ["config", "items", "quest", "quests", "dialogue", "recipes", "shops"]
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
const _BINARY_ARITH := ["+", "*", "/", "%", "^", "//"]
const _BITWISE := ["&", "|", "<<", ">>"]


## Lints a source text. `path` is only copied into the findings.
static func lint(source: String, path: String = "") -> Array[Dictionary]:
	var tk := _Tokens.tokenize(source)
	var out: Array[Dictionary] = []
	for f in tk["findings"] as Array:
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
				"else":
					out.append(_mk(path, ln, "else", t, "`else` is not part of the supported Lua subset: write separate `if ... then return ... end` blocks"))
				"elseif":
					out.append(_mk(path, ln, "elseif", t, "`elseif` is not part of the supported Lua subset: write separate `if ... then return ... end` blocks"))
				"for", "while", "repeat", "goto":
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

static func _table_rules(tk: Dictionary, path: String, out: Array[Dictionary]) -> void:
	var count: int = tk["count"]
	var types: PackedInt32Array = tk["type"]
	var texts: PackedStringArray = tk["text"]
	var i := 0
	while i < count:
		if types[i] == _Tokens.OP and texts[i] == "{":
			i = _table(tk, i, path, out)
		else:
			i += 1


## Checks one table constructor that starts at token `i` ("{"); returns the index after its closing "}".
static func _table(tk: Dictionary, i: int, path: String, out: Array[Dictionary]) -> int:
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
			named += 1
			j = _value(tk, j + 2, path, out)
		elif types[j] == _Tokens.OP and texts[j] == "[":
			var close := _matching(tk, j)
			if close > 0 and close + 1 < count and types[close + 1] == _Tokens.OP and texts[close + 1] == "=":
				named += 1
				j = _value(tk, close + 2, path, out)
			else:
				positional += 1
				j = _value(tk, j, path, out)
		else:
			positional += 1
			j = _value(tk, j, path, out)
	if named > 0 and positional > 0:
		out.append(_mk(path, lines[i], "mixed_table", "{", "table mixes `name = value` and positional entries: the positional entries are silently dropped"))
	return j


## Checks the value that starts at token `j`; returns the index of the token that ends it ("," ";" or "}", not consumed).
static func _value(tk: Dictionary, j: int, path: String, out: Array[Dictionary]) -> int:
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
		k = _table(tk, j, path, out)
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
		out.append(_mk(path, 1, "kind_missing", "kind", "no top-level `kind = \"...\"` header (config, items, quest, dialogue, recipes or shops)"))
	elif not (kind_value in KINDS):
		out.append(_mk(path, kind_line, "kind_unknown", kind_value, "unknown kind \"%s\" (expected one of: config, items, quest, dialogue, recipes, shops)" % kind_value))
