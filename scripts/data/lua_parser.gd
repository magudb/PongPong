class_name LuaParser
extends RefCounted
## Parser of the Lua subset (plan 3.11): top-level assignments of literal tables, top-level functions with a small
## statement language. Pure code on top of LuaTokens (no autoload, no node) so it compiles in `-s` drivers; the
## interpreter that EXECUTES the parsed functions is LuaRuntime (it needs the game autoloads).
##
## parse_source(source, path) returns
##   kind, id          from `kind = "..."` / `id = "..."` (empty when absent)
##   table_assigns     top-level `name = <string|number|true|false>` literals
##   functions         name -> {params: Array[String], body: String (source text), line: int}; the runtime compiles the body
##                     with compile_body() when the function first runs and caches the statements as "ast" in that dictionary
##   <table name>      every top-level `name = { ... }` table, parsed to Dictionary / Array / literals
##                     (so `objectives rewards items config lines choices meta shops recipes npcs ...` all arrive the same way)
##   source_path       the path argument
## Table rules (the same as the old regex reader, documented in docs/lua_api.md):
##   * `name = value` entries make a Dictionary, plain entries an Array; a table that mixes both keeps only the named
##     entries (the lint reports `mixed_table`); an EMPTY table `{}` arrives as an empty Dictionary (R.2),
##     LuaData.arr() / LuaData.dict() accept either;
##   * values are literals: string, number, true/false, nested table; anything else is kept as its SOURCE TEXT (a string)
##     and reported by the lint (`table_value`); `nil` is simply absent (as in Lua).
##
## AST (arrays, first element is the node kind)
##   expressions: [lit, v] [var, name] [field, e, key] [index, e, k] [call, "api.name"|"name", [args]] [tbl, const]
##                [or, a, b] [and, a, b] [not, a] [neg, a] [cmp, op, a, b] [cat, a, b] [unsupported, why]
##   statements : [local, name, e] [assign, name, e] [call, call_expr] [if, [[cond, block], ...], else_block|null]
##                [return, e|null] [unsupported, why]        (a block is an Array of statements)

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


static func parse_source(source: String, path: String = "") -> Dictionary:
	return parse_tokens(source, _Tokens.tokenize(source), path)


## parse_source on the tokens of `source` the caller already has (LuaTokens.tokenize(source)): LuaRuntime tokenizes a file once
## for the lint and the parser.
static func parse_tokens(source: String, tk: Dictionary, path: String = "") -> Dictionary:
	var out := {"kind": "", "id": "", "functions": {}, "table_assigns": {}, "source_path": path}
	var p := LuaParser.new()
	p.setup_tokens(source, tk)
	p.parse_top_level(out)
	return out


## Compiles the body text of a function (what functions[name]["body"] holds) into the statement list of the AST.
static func compile_body(body: String) -> Array:
	var p := LuaParser.new()
	p.setup(body)
	return p.parse_block(p._count)


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
					_skip_function_like()
				else:
					_skip_statement()
				continue
			if t == "return":
				_pos = _count
				break
			if _pos + 1 < _count and _types[_pos + 1] == T_OP and _texts[_pos + 1] == "=":
				_parse_assignment(out)
				continue
			_skip_statement()
			continue
		_pos += 1


func _parse_assignment(out: Dictionary) -> void:
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
			_skip_statement()
			return
		assigns[key] = literal
		return
	_skip_statement()


func _parse_function_def(functions: Dictionary) -> void:
	var fn_line := _lines[_pos]
	_pos += 1
	var fname := ""
	while _pos < _count and (_types[_pos] == T_NAME or (_types[_pos] == T_OP and (_texts[_pos] == "." or _texts[_pos] == ":"))):
		fname += _texts[_pos]
		_pos += 1
	if fname == "" or not _op("("):
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
	# the statements are compiled lazily from `body` (compile_body) the first time the function runs
	functions[fname] = {
		"params": params,
		"body": _src.substr(body_from, maxi(body_to - body_from, 0)).strip_edges(),
		"line": fn_line,
	}
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
					dict[str(key)] = keyed
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

## Parses statements up to a block terminator (end else elseif until) or token index `limit`.
func parse_block(limit: int) -> Array:
	var stmts: Array = []
	while _pos < limit:
		if _types[_pos] == T_NAME and (_texts[_pos] in _TERMINATORS):
			break
		var before := _pos
		var s: Variant = _parse_statement(limit)
		if s != null:
			stmts.append(s)
		if _pos <= before:
			_pos = before + 1                  # never stall
	return stmts


func _parse_statement(limit: int) -> Variant:
	var ty := _types[_pos]
	var t := _texts[_pos]
	if ty == T_OP and t == ";":
		_pos += 1
		return null
	if ty != T_NAME:
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
			_skip_function_like()
			return ["unsupported", "function"]
		"do":
			_pos += 1
			var inner := parse_block(limit)
			if _kw("end"):
				_pos += 1
			return ["if", [[["lit", true], inner]], null]
		"break", "goto":
			_pos += 1
			return ["unsupported", t]
		"then", "in", "until", "end", "else", "elseif":
			_pos += 1
			return null
	# expression statement: a call or an assignment to a plain name
	var e2 := _parse_suffixed()
	if _op("="):
		_pos += 1
		var value := _checked(_parse_expr())
		if e2[0] == "var":
			return ["assign", e2[1], value]
		return ["unsupported", "assignment to a field"]
	if e2[0] == "call":
		return ["call", e2]
	_skip_statement()
	return ["unsupported", "statement"]


func _parse_local(_limit: int) -> Variant:
	_pos += 1
	if _kw("function"):
		_skip_function_like()
		return ["unsupported", "local function"]
	if _pos >= _count or _types[_pos] != T_NAME:
		_skip_statement()
		return ["unsupported", "local"]
	var lname := _texts[_pos]
	_pos += 1
	if _op(","):                               # `local a, b = ...`
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
	_pos += 1
	var branches: Array = []
	var cond := _checked(_parse_expr())
	if _kw("then"):
		_pos += 1
	var block := parse_block(limit)
	branches.append([cond, block])
	var else_block: Variant = null
	while true:
		if _kw("elseif"):
			_pos += 1
			var c2 := _checked(_parse_expr())
			if _kw("then"):
				_pos += 1
			branches.append([c2, parse_block(limit)])
		elif _kw("else"):
			_pos += 1
			else_block = parse_block(limit)
		else:
			break
	if _kw("end"):
		_pos += 1
	return ["if", branches, else_block]


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
		if t in _STATEMENT_WORDS or t == "then" or t == "and" or t == "or" or t == "not" or t == "in":
			return ["lit", null]               # not an expression start: the caller skips
		e = ["var", t]
		path = t
		_pos += 1
	elif ty == T_OP and t == "(":
		_pos += 1
		e = _parse_or()
		if _op(")"):
			_pos += 1
	elif ty == T_OP and t == "{":
		return ["tbl", parse_table()]
	else:
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
			_pos += 1
			var k := _parse_or()
			if _op("]"):
				_pos += 1
			e = ["index", e, k]
			path = ""
		elif op == "(":
			var args := _parse_args()
			if path != "":
				e = ["call", path, args]
			else:
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

func _kw(word: String) -> bool:
	return _pos < _count and _types[_pos] == T_NAME and _texts[_pos] == word


func _op(symbol: String) -> bool:
	return _pos < _count and _types[_pos] == T_OP and _texts[_pos] == symbol
