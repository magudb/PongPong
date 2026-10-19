class_name LuaParser
extends RefCounted
## Parser of the Lua subset (plan 3.11): top-level assignments of literal tables, top-level functions with a small
## statement language. Pure code on top of LuaTokens (no autoload, no node) so it compiles in `-s` drivers; the
## interpreter that EXECUTES the parsed functions is LuaRuntime (it needs the game autoloads).
##
## parse_source(source, path) returns
##   kind, id          from `kind = "..."` / `id = "..."` (empty when absent)
##   table_assigns     top-level `name = <string|number|true|false>` literals
##   functions         name -> {params: Array[String], body: String (source text), line: int, body_line: int}; the runtime
##                     compiles the body with compile_body() when the function first runs and caches the statements as "ast"
##                     in that dictionary (parse_tokens() with a findings array compiles every body at once)
##   <table name>      every top-level `name = { ... }` table, parsed to Dictionary / Array / literals
##                     (so `objectives rewards items config lines choices meta shops recipes npcs ...` all arrive the same way)
##   source_path       the path argument
## Table rules (the same as the old regex reader, documented in docs/lua_api.md):
##   * `name = value` entries make a Dictionary, plain entries an Array; a table that mixes both keeps only the named
##     entries (the lint reports `mixed_table`); an EMPTY table `{}` arrives as an empty Dictionary (R.2),
##     LuaData.arr() / LuaData.dict() accept either;
##   * values are literals: string, number, true/false, nested table; anything else is kept as its SOURCE TEXT (a string)
##     and reported by the lint (`table_value`); `nil` is simply absent (as in Lua).
## A table constructor INSIDE a function is an expression: its values are evaluated when it runs (`{ text_key = key }`
## reads the local `key`), with the same rules for the table it builds (table_of); one whose keys and values are all
## literals is folded into a constant at parse time.
##
## AST (arrays, first element is the node kind)
##   expressions: [lit, v] [var, name] [field, e, key] [index, e, k] [call, "api.name"|"name", [args]] [tbl, const]
##                [ctor, [[kind, key, value_expr], ...]] (kind "name": key is the String, "expr": key is an expression,
##                "pos": key is null) [or, a, b] [and, a, b] [not, a] [neg, a] [cmp, op, a, b] [cat, a, b] [unsupported, why]
##   statements : [local, name, e] [assign, name, e] [call, call_expr] [if, [[cond, block], ...], else_block|null]
##                [return, e|null] [unsupported, why]        (a block is an Array of statements; the LAST element of
##                every statement is the source line it starts on)
##
## Grammar findings ({line, rule, token, message}, collected by parse_tokens() with a findings array; LuaLint reports them):
##   syntax            not Lua at all: `!=`, `if a = b then`, a misspelt keyword (`retrun x`), a statement after `return`,
##                     a missing `then` / `)` / `]` - real Lua refuses the file, the subset would silently run something else
##   local_list        `local a, b = ...`                   field_assignment   `t.x = v` / `t[k] = v`
##   function_value    a function defined inside a function, or used as a value (`local f = function() ... end`)
##   unsupported       valid Lua the interpreter does not evaluate (a call that is not `api.<name>(...)`)
##   top_level         a top-level statement the loader ignores (it reads `name = <literal or table>` and `function name(...)`)
## Constructs the token rules of LuaLint already name (loops, `local function`, `#`, arithmetic, method calls, the standard
## library ...) are not reported twice.

# preload, not the class name: the autoload LuaRuntime depends on this script, and an autoload must compile even when the
# global class cache is stale (a fresh clone before `godot --import`)
const _Tokens := preload("res://scripts/data/lua_tokens.gd")

const T_NAME := 0       # mirrors LuaTokens.NAME / NUMBER / STRING / OP (checked by tests/sections/data.gd)
const T_NUMBER := 1
const T_STRING := 2
const T_OP := 3

const _TERMINATORS := ["end", "else", "elseif", "until"]
const _STATEMENT_WORDS := ["local", "if", "return", "for", "while", "repeat", "function", "do", "break", "goto", "end", "else", "elseif", "until"]
const _ARITH := ["+", "-", "*", "/", "%", "^", "//", "&", "|", "<<", ">>"]
const _CMP := ["==", "~=", "<", "<=", ">", ">="]
const _RESERVED := ["functions", "table_assigns", "source_path", "kind", "id"]

var _src := ""
var _types := PackedInt32Array()
var _texts := PackedStringArray()
var _lines := PackedInt32Array()
var _starts := PackedInt32Array()
var _ends := PackedInt32Array()
var _count := 0
var _pos := 0
## grammar findings of everything parsed so far (see the header)
var findings: Array[Dictionary] = []
var _fn_ranges: Array = []      # [name, first body token, token index of its `end`] per top-level function, in source order


static func parse_source(source: String, path: String = "") -> Dictionary:
	return parse_tokens(source, _Tokens.tokenize(source), path)


## parse_source on the tokens of `source` the caller already has (LuaTokens.tokenize(source)): LuaRuntime tokenizes a file once
## for the lint and the parser. With `grammar` (an Array) every function body is compiled now, from the same tokens (the
## statements land in functions[name]["ast"]), and the grammar findings of the whole file are appended to it.
static func parse_tokens(source: String, tk: Dictionary, path: String = "", grammar: Variant = null) -> Dictionary:
	var out := {"kind": "", "id": "", "functions": {}, "table_assigns": {}, "source_path": path}
	var p := LuaParser.new()
	p.setup_tokens(source, tk)
	p.parse_top_level(out)
	if grammar is Array:
		p.compile_functions(out["functions"])
		(grammar as Array).append_array(p.findings)
	return out


## Compiles the body text of a function (what functions[name]["body"] holds) into the statement list of the AST.
## `first_line` is the source line the body text starts on (functions[name]["body_line"]): the statements carry real lines.
static func compile_body(body: String, first_line: int = 1) -> Array:
	var p := LuaParser.new()
	p.setup(body)
	if first_line != 1:
		for i in p._count:
			p._lines[i] += first_line - 1
	return p._parse_body(p._count)


## Compiles every function body of the last parse_top_level() into functions[name]["ast"] (from the tokens already read).
func compile_functions(functions: Dictionary) -> void:
	for r in _fn_ranges:
		_pos = int(r[1])
		var ast := _parse_body(int(r[2]))
		if functions.has(r[0]):
			(functions[r[0]] as Dictionary)["ast"] = ast


func setup(source: String) -> void:
	setup_tokens(source, _Tokens.tokenize(source))


func setup_tokens(source: String, tk: Dictionary) -> void:
	_src = source
	_types = tk["type"]
	_texts = tk["text"]
	_lines = tk["line"]
	_starts = tk["start"]
	_ends = tk["end"]
	_count = int(tk["count"])
	_pos = 0


# ------------------------------------------------------------------------------------------------ top level

func parse_top_level(out: Dictionary) -> void:
	var functions: Dictionary = out["functions"]
	while _pos < _count:
		if _types[_pos] == T_NAME:
			var t := _texts[_pos]
			if t == "function":
				_parse_function_def(functions)
				continue
			if t == "local":
				_pos += 1
				if _kw("function"):
					_skip_function_like()          # the lint's local_function
				else:
					_top_level_finding(_pos - 1, "a top-level `local` is not read: write `name = <literal or table>`")
					_skip_statement()
				continue
			if t == "return":
				_top_level_finding(_pos, "a top-level `return` is not read (module-style files are not supported): everything after it is ignored")
				_pos = _count
				break
			if _pos + 1 < _count and _types[_pos + 1] == T_OP and _texts[_pos + 1] == "=":
				_parse_assignment(out)
				continue
			_top_level_finding(_pos, "only `name = <literal or table>` and `function name(...)` are read at the top level: this statement is ignored")
			_skip_statement()
			continue
		if not _op(";"):
			_finding(_pos, "syntax", "unexpected `%s` at the top level of the file" % _texts[_pos])
		_pos += 1


func _parse_assignment(out: Dictionary) -> void:
	var key_idx := _pos
	var key := _texts[_pos]
	_pos += 2
	if _pos >= _count:
		return
	var ty := _types[_pos]
	var t := _texts[_pos]
	var assigns: Dictionary = out["table_assigns"]
	if ty == T_OP and t == "{":
		var value: Variant = parse_table()
		if not (key in _RESERVED):
			out[key] = value
		return
	var literal: Variant = null
	var is_literal := false
	if ty == T_STRING:
		literal = t
		is_literal = true
		_pos += 1
	elif ty == T_NUMBER:
		literal = _number(t)
		is_literal = true
		_pos += 1
	elif ty == T_OP and t == "-" and _pos + 1 < _count and _types[_pos + 1] == T_NUMBER:
		var n: Variant = _number(_texts[_pos + 1])
		literal = -n if (typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT) else n
		is_literal = true
		_pos += 2
	elif ty == T_NAME and (t == "true" or t == "false"):
		literal = (t == "true")
		is_literal = true
		_pos += 1
	if is_literal:
		# `x = 5 * 2` is an expression, not a literal: keep nothing rather than a wrong number
		if _pos < _count and _types[_pos] == T_OP and _texts[_pos] != "," and _texts[_pos] != ";" and _lines[_pos] == _lines[_pos - 1] and _texts[_pos] != "}":
			_top_level_finding(key_idx, "`%s = ...` is an expression, not a literal: the loader ignores it" % key)
			_skip_statement()
			return
		assigns[key] = literal
		return
	_top_level_finding(key_idx, "the value of `%s` is not a literal or a table: the loader ignores it" % key)
	_skip_statement()


func _parse_function_def(functions: Dictionary) -> void:
	var fn_line := _lines[_pos]
	_pos += 1
	var fname := ""
	while _pos < _count and (_types[_pos] == T_NAME or (_types[_pos] == T_OP and (_texts[_pos] == "." or _texts[_pos] == ":"))):
		fname += _texts[_pos]
		_pos += 1
	if fname == "" or not _op("("):
		_finding(mini(_pos, _count - 1), "syntax", "`function` needs a name and `(` (only top-level `function name(...)` definitions are read)")
		_skip_statement()
		return
	_pos += 1
	var params: Array = []
	while _pos < _count and not _op(")"):
		if _types[_pos] == T_NAME:
			params.append(_texts[_pos])
		_pos += 1
	var rparen := _pos
	_pos += 1
	var end_idx := _find_block_end(_pos)
	var body_from := _ends[rparen] if rparen < _count else _src.length()
	var body_to := _starts[end_idx] if end_idx >= 0 else _src.length()
	# the statements are compiled lazily from `body` (compile_body) the first time the function runs; the body text starts
	# right after `)`, so its first line is the line of `)`
	functions[fname] = {
		"params": params,
		"body": _src.substr(body_from, maxi(body_to - body_from, 0)).strip_edges(false, true),
		"line": fn_line,
		"body_line": _lines[rparen] if rparen < _count else fn_line,
	}
	_fn_ranges.append([fname, _pos, _count if end_idx < 0 else end_idx])
	_pos = _count if end_idx < 0 else end_idx + 1


## index of the `end` that closes a block whose opener is already consumed (depth starts at 1), or -1
func _find_block_end(from: int) -> int:
	var depth := 1
	for j in range(from, _count):
		if _types[j] != T_NAME:
			continue
		var t := _texts[j]
		if t == "function" or t == "if" or t == "do":
			depth += 1
		elif t == "end":
			depth -= 1
			if depth == 0:
				return j
	return -1


## `local function f(...) ... end` / nested function: skip it completely. _pos is at `function`.
func _skip_function_like() -> void:
	_pos += 1
	var end_idx := _find_block_end(_pos)
	_pos = _count if end_idx < 0 else end_idx + 1


## Skips a statement that is not understood. Advances at least one token, then stops at the next statement start
## (a keyword that begins a statement, or a name that starts a new line) outside brackets.
func _skip_statement() -> void:
	var depth := 0
	_pos += 1
	while _pos < _count:
		var ty := _types[_pos]
		var t := _texts[_pos]
		if ty == T_OP:
			if t == "{" or t == "(" or t == "[":
				depth += 1
			elif t == "}" or t == ")" or t == "]":
				depth -= 1
		elif depth <= 0 and ty == T_NAME:
			if t in _STATEMENT_WORDS:
				return
			if _lines[_pos] > _lines[_pos - 1] and t != "and" and t != "or":
				return
		_pos += 1


# ------------------------------------------------------------------------------------------------ data tables

## Parses the table constructor at _pos ("{"): Dictionary, Array, or the empty Dictionary. See the header for the rules.
func parse_table() -> Variant:
	_pos += 1
	var dict := {}
	var arr: Array = []
	while _pos < _count:
		var ty := _types[_pos]
		var t := _texts[_pos]
		if ty == T_OP and t == "}":
			_pos += 1
			break
		if ty == T_OP and (t == "," or t == ";"):
			_pos += 1
			continue
		if ty == T_NAME and _pos + 1 < _count and _types[_pos + 1] == T_OP and _texts[_pos + 1] == "=":
			_pos += 2
			var named: Variant = parse_data_value()
			if named != null:
				dict[t] = named
		elif ty == T_OP and t == "[":
			_pos += 1
			var key: Variant = _key_value()
			if _op("]"):
				_pos += 1
			if _op("="):
				_pos += 1
				var keyed: Variant = parse_data_value()
				if keyed != null:
					dict[key_text(key)] = keyed
			elif key != null:
				arr.append(key)
		else:
			var item: Variant = parse_data_value()
			if item != null:
				arr.append(item)
	if not dict.is_empty():
		return dict
	if not arr.is_empty():
		return arr
	return {}


## The table a constructor builds from its evaluated [key, value] pairs (key null = a positional value), by the rules of a
## data table: named entries make a Dictionary (positional ones next to them are dropped, the lint's mixed_table),
## positional ones an Array, a nil value is absent, and no entry at all is the empty Dictionary.
static func table_of(pairs: Array) -> Variant:
	var dict := {}
	var arr: Array = []
	for pair in pairs:
		if pair[1] == null:
			continue
		if pair[0] == null:
			arr.append(pair[1])
		else:
			dict[key_text(pair[0])] = pair[1]
	if not dict.is_empty():
		return dict
	if not arr.is_empty():
		return arr
	return {}


## A table key as the String the tables use; an integral number is its integer (Lua's t[2.0] is t[2]).
static func key_text(key: Variant) -> String:
	if typeof(key) == TYPE_FLOAT and is_finite(key) and absf(key) < 1.0e15 and float(key) == floorf(key):
		return str(int(key))
	return str(key)


## The single token of a `[key] = value` entry: string, number or true/false (anything else: null).
func _key_value() -> Variant:
	if _pos >= _count:
		return null
	var ty := _types[_pos]
	var t := _texts[_pos]
	var key: Variant = null
	if ty == T_STRING:
		key = t
	elif ty == T_NUMBER:
		key = _number(t)
	elif ty == T_NAME and (t == "true" or t == "false"):
		key = (t == "true")
	_pos += 1
	return key


## One value of a data table (string, number, true/false/nil, nested table, or the source text of anything else).
func parse_data_value() -> Variant:
	if _pos >= _count:
		return null
	var start := _pos
	var ty := _types[_pos]
	var t := _texts[_pos]
	if ty == T_OP and t == "{":
		return parse_table()
	var value: Variant = null
	var next := -1                             # token index after a plain literal
	if ty == T_STRING:
		value = t
		next = _pos + 1
	elif ty == T_NUMBER:
		value = _number(t)
		next = _pos + 1
	elif ty == T_OP and t == "-" and _pos + 1 < _count and _types[_pos + 1] == T_NUMBER:
		var n: Variant = _number(_texts[_pos + 1])
		value = -n if (typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT) else n
		next = _pos + 2
	elif ty == T_NAME and (t == "true" or t == "false"):
		value = (t == "true")
		next = _pos + 1
	elif ty == T_NAME and t == "nil":
		value = null
		next = _pos + 1
	if next >= 0 and (next >= _count or (_types[next] == T_OP and (_texts[next] == "," or _texts[next] == ";" or _texts[next] == "}"))):
		_pos = next
		return value
	# not a plain literal: keep the source text up to the end of the value
	return _raw_value(start)


## Source text of the value that starts at token `first`; leaves _pos at the "," ";" "}" that ends it.
func _raw_value(first: int) -> String:
	var depth := 0
	var j := first
	var last := first
	while j < _count:
		var ty := _types[j]
		var t := _texts[j]
		if ty == T_OP:
			if t == "(" or t == "[" or t == "{":
				depth += 1
			elif t == ")" or t == "]":
				depth -= 1
			elif t == "}":
				if depth <= 0:
					break
				depth -= 1
			elif (t == "," or t == ";") and depth <= 0:
				break
		last = j
		j += 1
	_pos = maxi(j, first + 1)
	if first >= _count:
		return ""
	return _src.substr(_starts[first], _ends[mini(last, _count - 1)] - _starts[first]).strip_edges()


static func _number(text: String) -> Variant:
	if text.begins_with("0x") or text.begins_with("0X"):
		return text.hex_to_int()
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text


# ------------------------------------------------------------------------------------------------ blocks and statements

## Parses statements up to a block terminator (end else elseif until) or token index `limit`. Every statement gets its
## source line appended (the last element).
func parse_block(limit: int) -> Array:
	var stmts: Array = []
	var returned := false
	while _pos < limit:
		if _types[_pos] == T_NAME and (_texts[_pos] in _TERMINATORS):
			break
		if returned and not _op(";"):
			_finding(_pos, "syntax", "`return` must be the last statement of its block: real Lua refuses `%s` after it" % _texts[_pos])
			returned = false
		var before := _pos
		var line := _lines[_pos]
		var s: Variant = _parse_statement(limit)
		if s != null:
			(s as Array).append(line)
			stmts.append(s)
			returned = returned or str(s[0]) == "return"
		if _pos <= before:
			_pos = before + 1                  # never stall
	return stmts


## A whole function body up to `limit`: a block, and a terminator that closes nothing (`else`, `elseif`, `until`) is a
## syntax finding (a stray `end` cannot be inside: it would have ended the function, the lint's `unbalanced`).
func _parse_body(limit: int) -> Array:
	var stmts := parse_block(limit)
	while _pos < limit:
		_finding(_pos, "syntax", "`%s` without an open `if`" % _texts[_pos])
		_pos += 1
		stmts.append_array(parse_block(limit))
	return stmts


func _parse_statement(limit: int) -> Variant:
	var ty := _types[_pos]
	var t := _texts[_pos]
	if ty == T_OP and t == ";":
		_pos += 1
		return null
	if ty != T_NAME:
		_finding(_pos, "syntax", "unexpected `%s`: a statement starts with local, if, return, do, an api call or `name = value`" % t)
		_skip_statement()
		return ["unsupported", t]
	match t:
		"local":
			return _parse_local(limit)
		"if":
			return _parse_if(limit)
		"return":
			_pos += 1
			if _pos >= limit or (_types[_pos] == T_NAME and (_texts[_pos] in _TERMINATORS)):
				return ["return", null]
			var e := _checked(_parse_expr())
			while _op(","):                    # `return a, b`: only the first value is used
				_pos += 1
				_parse_expr()
			return ["return", e]
		"for", "while":
			_skip_loop()
			return ["unsupported", t]
		"repeat":
			_skip_repeat()
			return ["unsupported", t]
		"function":
			_finding(_pos, "function_value", "a function can only be defined at the top level of the file (`function name(...)`), not inside another one")
			_skip_function_like()
			return ["unsupported", "function"]
		"do":
			var do_at := _pos
			_pos += 1
			var inner := parse_block(limit)
			_expect_end(do_at)
			return ["if", [[["lit", true], inner]], null]
		"break", "goto":
			_pos += 1
			return ["unsupported", t]
		"then", "in", "until", "end", "else", "elseif":
			_finding(_pos, "syntax", "unexpected `%s`" % t)
			_pos += 1
			return null
	# expression statement: a call or an assignment to a plain name
	var first := _pos
	var e2 := _parse_suffixed()
	if _op("="):
		_pos += 1
		var value := _checked(_parse_expr())
		if e2[0] == "var":
			return ["assign", e2[1], value]
		_finding(first, "field_assignment", "assigning to a field (`t.x = v`, `t[k] = v`) is not supported: keep the value in a local, or store it with api.set_flag")
		return ["unsupported", "assignment to a field"]
	if e2[0] == "call":
		return ["call", e2]
	if e2[0] == "unsupported" and _pos > first + 1:
		return e2                              # a call the subset does not evaluate (reported where it was parsed)
	_finding(first, "syntax", "`%s` is neither a call nor an assignment (a misspelt keyword?)" % _texts[first])
	if _pos < limit and _pos > first and _lines[_pos] == _lines[_pos - 1]:
		_skip_statement()
	return ["unsupported", "statement"]


func _parse_local(_limit: int) -> Variant:
	_pos += 1
	if _kw("function"):
		_skip_function_like()                  # the lint's local_function
		return ["unsupported", "local function"]
	if _pos >= _count or _types[_pos] != T_NAME:
		_finding(mini(_pos, _count - 1), "syntax", "a name is expected after `local`")
		_skip_statement()
		return ["unsupported", "local"]
	var lname := _texts[_pos]
	_pos += 1
	if _op(","):                               # `local a, b = ...`
		_finding(_pos - 2, "local_list", "`local a, b` declares several names at once: write one `local name = value` per name")
		_skip_statement()
		return ["unsupported", "local list"]
	if _op("="):
		_pos += 1
		var e := _checked(_parse_expr())
		while _op(","):
			_pos += 1
			_parse_expr()
		return ["local", lname, e]
	return ["local", lname, ["lit", null]]


func _parse_if(limit: int) -> Variant:
	var if_at := _pos
	_pos += 1
	var branches: Array = []
	var cond := _checked(_parse_expr())
	_expect_then(limit, if_at)
	var block := parse_block(limit)
	branches.append([cond, block])
	var else_block: Variant = null
	while true:
		if _kw("elseif"):
			var elseif_at := _pos
			_pos += 1
			var c2 := _checked(_parse_expr())
			_expect_then(limit, elseif_at)
			branches.append([c2, parse_block(limit)])
		elif _kw("else"):
			_pos += 1
			else_block = parse_block(limit)
		else:
			break
	_expect_end(if_at)
	return ["if", branches, else_block]


## `then` after the condition of `if` / `elseif` (token `opener`). Anything else is a syntax finding, and the parser resumes
## after the `then` of the statement, so `if a != b then` is one finding, not one per token.
func _expect_then(limit: int, opener: int) -> void:
	if _kw("then"):
		_pos += 1
		return
	_finding(mini(_pos, _count - 1), "syntax", "`then` expected after the condition of the `%s` on line %d, not `%s`" % [_texts[opener], _lines[opener], _tok(_pos)])
	var j := _pos
	while j < limit:
		if _types[j] == T_NAME:
			if _texts[j] == "then":
				_pos = j + 1
				return
			if _texts[j] in _STATEMENT_WORDS:
				return
		j += 1


## `end` closing the block opened by token `opener` (`if` / `do`). At the end of the input the lint's `unbalanced` says it.
func _expect_end(opener: int) -> void:
	if _kw("end"):
		_pos += 1
	elif _pos < _count:
		_finding(_pos, "syntax", "`end` expected to close the `%s` on line %d, not `%s`" % [_texts[opener], _lines[opener], _texts[_pos]])


func _skip_loop() -> void:
	_pos += 1
	while _pos < _count and not _kw("do"):
		_pos += 1
	if _pos < _count:
		_pos += 1
		var end_idx := _find_block_end(_pos)
		_pos = _count if end_idx < 0 else end_idx + 1


func _skip_repeat() -> void:
	_pos += 1
	var depth := 1
	while _pos < _count:
		if _types[_pos] == T_NAME:
			var t := _texts[_pos]
			if t == "repeat":
				depth += 1
			elif t == "until":
				depth -= 1
				if depth == 0:
					_pos += 1
					_skip_statement()
					return
		_pos += 1


## If an arithmetic / bitwise operator follows the expression just parsed, the value would be wrong: drop the rest of
## the statement and answer an `unsupported` node (evaluates to nil) instead of a silently wrong partial value.
func _checked(e: Array) -> Array:
	if _pos < _count and _types[_pos] == T_OP and (_texts[_pos] in _ARITH):
		_skip_statement()
		return ["unsupported", "arithmetic"]
	return e


# ------------------------------------------------------------------------------------------------ expressions

func _parse_expr() -> Array:
	return _parse_or()


func _parse_or() -> Array:
	var left := _parse_and()
	while _kw("or"):
		_pos += 1
		left = ["or", left, _parse_and()]
	return left


func _parse_and() -> Array:
	var left := _parse_cmp()
	while _kw("and"):
		_pos += 1
		left = ["and", left, _parse_cmp()]
	return left


func _parse_cmp() -> Array:
	var left := _parse_cat()
	while _pos < _count and _types[_pos] == T_OP and (_texts[_pos] in _CMP):
		var op := _texts[_pos]
		_pos += 1
		left = ["cmp", op, left, _parse_cat()]
	return left


func _parse_cat() -> Array:
	var left := _parse_unary()
	if _op(".."):
		_pos += 1
		return ["cat", left, _parse_cat()]
	return left


func _parse_unary() -> Array:
	if _kw("not"):
		_pos += 1
		return ["not", _parse_unary()]
	if _op("-"):
		_pos += 1
		var operand := _parse_unary()
		if operand[0] == "lit" and (typeof(operand[1]) == TYPE_INT or typeof(operand[1]) == TYPE_FLOAT):
			return ["lit", -operand[1]]
		return ["neg", operand]
	if _op("#"):
		_pos += 1
		_parse_unary()
		return ["unsupported", "#"]
	return _parse_suffixed()


func _parse_suffixed() -> Array:
	if _pos >= _count:
		return ["lit", null]
	var ty := _types[_pos]
	var t := _texts[_pos]
	var e: Array
	var path := ""
	if ty == T_NUMBER:
		_pos += 1
		return ["lit", _number(t)]
	elif ty == T_STRING:
		_pos += 1
		return ["lit", t]
	elif ty == T_NAME:
		if t == "true" or t == "false":
			_pos += 1
			return ["lit", t == "true"]
		if t == "nil":
			_pos += 1
			return ["lit", null]
		if t == "function":
			_finding(_pos, "function_value", "functions are not values in the subset (`function() ... end` inside a function): define a top-level `function name(...)`")
			_skip_function_like()
			return ["unsupported", "function"]
		if t in _STATEMENT_WORDS or t == "then" or t == "and" or t == "or" or t == "not" or t == "in":
			_finding(_pos, "syntax", "an expression is expected before `%s`" % t)
			return ["lit", null]               # not an expression start: the caller skips
		e = ["var", t]
		path = t
		_pos += 1
	elif ty == T_OP and t == "(":
		var open_at := _pos
		_pos += 1
		e = _parse_or()
		if _op(")"):
			_pos += 1
		else:
			_finding(mini(_pos, _count - 1), "syntax", "`)` expected to close the `(` on line %d, not `%s`" % [_lines[open_at], _tok(_pos)])
	elif ty == T_OP and t == "{":
		return _parse_ctor()
	else:
		if t != "..." and t != "~":            # the lint's vararg / bitwise
			_finding(_pos, "syntax", "an expression is expected, not `%s`" % t)
		_pos += 1
		return ["unsupported", t]
	while _pos < _count and _types[_pos] == T_OP:
		var op := _texts[_pos]
		if op == "." and _pos + 1 < _count and _types[_pos + 1] == T_NAME:
			var key := _texts[_pos + 1]
			e = ["field", e, key]
			path = (path + "." + key) if path != "" else ""
			_pos += 2
		elif op == "[":
			var bracket_at := _pos
			_pos += 1
			var k := _parse_or()
			if _op("]"):
				_pos += 1
			else:
				_finding(mini(_pos, _count - 1), "syntax", "`]` expected to close the `[` on line %d, not `%s`" % [_lines[bracket_at], _tok(_pos)])
			e = ["index", e, k]
			path = ""
		elif op == "(":
			var call_at := _pos
			var args := _parse_args()
			if path != "":
				e = ["call", path, args]
			else:
				_finding(call_at, "unsupported", "only `api.<name>(...)` calls are evaluated: this call answers nil")
				e = ["unsupported", "call"]
			path = ""
		elif op == ":" and _pos + 1 < _count and _types[_pos + 1] == T_NAME:
			_pos += 2
			if _op("("):
				_parse_args()
			e = ["unsupported", "method call"]
			path = ""
		else:
			break
	return e


## A table constructor in a function (_pos at "{"): [ctor, entries], or [tbl, constant] when every key and value is a
## literal (the constant is copied on every evaluation, as before).
func _parse_ctor() -> Array:
	var open_at := _pos
	_pos += 1
	var entries: Array = []
	var constant := true
	var closed := false
	while _pos < _count:
		if _op("}"):
			_pos += 1
			closed = true
			break
		if _op(",") or _op(";"):
			_pos += 1
			continue
		var entry: Array
		if _types[_pos] == T_NAME and _pos + 1 < _count and _types[_pos + 1] == T_OP and _texts[_pos + 1] == "=":
			var key := _texts[_pos]
			_pos += 2
			entry = ["name", key, _ctor_value()]
		elif _op("["):
			var bracket_at := _pos
			_pos += 1
			var k := _parse_or()
			if _op("]"):
				_pos += 1
			else:
				_finding(mini(_pos, _count - 1), "syntax", "`]` expected to close the `[` on line %d, not `%s`" % [_lines[bracket_at], _tok(_pos)])
			if _op("="):
				_pos += 1
			else:
				_finding(mini(_pos, _count - 1), "syntax", "`=` expected after the `[key]` of a table entry, not `%s`" % _tok(_pos))
			entry = ["expr", k, _ctor_value()]
			constant = constant and k[0] == "lit"
		else:
			entry = ["pos", null, _ctor_value()]
		var value: Array = entry[2]
		constant = constant and (value[0] == "lit" or value[0] == "tbl")
		entries.append(entry)
		if not (_op(",") or _op(";") or _op("}")) and _pos < _count:
			_finding(_pos, "syntax", "`,` or `}` expected in the table of line %d, not `%s`" % [_lines[open_at], _texts[_pos]])
			_raw_value(_pos)                   # resume at the next `,` / `}`
	if not closed:
		_finding(open_at, "syntax", "the table of line %d is not closed by `}`" % _lines[open_at])
	if not constant:
		return ["ctor", entries]
	var pairs: Array = []
	for entry in entries:
		var value_node: Array = entry[2]
		match str(entry[0]):
			"pos":
				pairs.append([null, value_node[1]])
			"name":
				pairs.append([entry[1], value_node[1]])
			_:
				if (entry[1] as Array)[1] != null:
					pairs.append([(entry[1] as Array)[1], value_node[1]])
	return ["tbl", table_of(pairs)]


## One value of a constructor: a literal followed by `,` `;` `}` directly (the bulk of every dialogue page), a nested
## constructor, or an expression. Arithmetic is the lint's: the value becomes [unsupported] and the parser resumes at the
## end of the entry.
func _ctor_value() -> Array:
	if _pos >= _count:
		return ["lit", null]
	var ty := _types[_pos]
	var t := _texts[_pos]
	if ty == T_OP and t == "{":
		return _parse_ctor()
	var next := _pos + 1
	var value: Variant = null
	var literal := true
	if ty == T_STRING:
		value = t
	elif ty == T_NUMBER:
		value = _number(t)
	elif ty == T_NAME and (t == "true" or t == "false"):
		value = t == "true"
	elif ty == T_NAME and t == "nil":
		value = null
	elif ty == T_OP and t == "-" and _pos + 1 < _count and _types[_pos + 1] == T_NUMBER:
		var n: Variant = _number(_texts[_pos + 1])
		value = -n if (typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT) else n
		next = _pos + 2
	else:
		literal = false
	if literal and (next >= _count or (_types[next] == T_OP and (_texts[next] == "," or _texts[next] == ";" or _texts[next] == "}"))):
		_pos = next
		return ["lit", value]
	var e := _parse_expr()
	if _pos < _count and _types[_pos] == T_OP and (_texts[_pos] in _ARITH):
		_raw_value(_pos)
		return ["unsupported", "arithmetic"]
	return e


func _parse_args() -> Array:
	var args: Array = []
	_pos += 1                                  # "("
	if _op(")"):
		_pos += 1
		return args
	while _pos < _count:
		var before := _pos
		args.append(_parse_or())
		if _op(","):
			_pos += 1
		elif _op(")"):
			_pos += 1
			break
		elif _pos == before:
			_pos += 1
		else:
			# unexpected tokens inside the argument list (arithmetic ...): skip to the closing bracket
			if not (_types[_pos] == T_OP and (_texts[_pos] in _ARITH or _texts[_pos] == ":")):     # the lint's arithmetic / method_call
				_finding(_pos, "syntax", "`,` or `)` expected in the argument list, not `%s`" % _texts[_pos])
			var depth := 1
			while _pos < _count and depth > 0:
				if _types[_pos] == T_OP:
					if _texts[_pos] == "(":
						depth += 1
					elif _texts[_pos] == ")":
						depth -= 1
				_pos += 1
			break
	return args


# ------------------------------------------------------------------------------------------------ helpers

func _finding(at: int, rule: String, message: String) -> void:
	findings.append({"line": _lines[at] if at >= 0 and at < _count else (_lines[_count - 1] if _count > 0 else 1), "rule": rule, "token": _tok(at), "message": message})


func _top_level_finding(at: int, message: String) -> void:
	_finding(at, "top_level", message)


## the text of token `at`, or a readable stand-in past the end
func _tok(at: int) -> String:
	return _texts[at] if at >= 0 and at < _count else "<end of file>"


func _kw(word: String) -> bool:
	return _pos < _count and _types[_pos] == T_NAME and _texts[_pos] == word


func _op(symbol: String) -> bool:
	return _pos < _count and _types[_pos] == T_OP and _texts[_pos] == symbol
