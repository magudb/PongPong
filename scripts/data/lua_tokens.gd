class_name LuaTokens
extends RefCounted
## Tokenizer of the Lua subset that LuaRuntime (the interpreter) and LuaLint (the load-time lint) share.
## Pure static code: no autoload, no node, so it compiles in `-s` drivers and runs without a booted game.
##
## tokenize(source) returns a Dictionary of parallel arrays (index = token index):
##   count   int                 number of tokens
##   type    PackedInt32Array    NAME / NUMBER / STRING / OP
##   text    PackedStringArray   NAME and OP: the token text; NUMBER: the raw text; STRING: the DECODED value
##   start   PackedInt32Array    first character of the token in the source
##   end     PackedInt32Array    character after the token
##   line    PackedInt32Array    1-based line of the first character
##   findings Array[Dictionary]  tokenizer-level lint findings {line, rule, token, message}:
##                               long brackets / block comments, escape sequences, unterminated strings, stray characters
##                               (also `!` `?` `@` `$` `\` and a backtick: they are not Lua outside a string)
## Comments (`-- ...` and `--[[ ... ]]`) are skipped, so they never reach a consumer.

const NAME := 0
const NUMBER := 1
const STRING := 2
const OP := 3

const _TWO_CHAR_OPS := ["==", "~=", "<=", ">=", "..", "//", "::", "<<", ">>"]


static func tokenize(src: String) -> Dictionary:
	var types := PackedInt32Array()
	var texts := PackedStringArray()
	var starts := PackedInt32Array()
	var ends := PackedInt32Array()
	var lines := PackedInt32Array()
	var findings: Array[Dictionary] = []
	var n := src.length()
	var i := 0
	var line := 1
	while i < n:
		var c := src.unicode_at(i)
		if c == 10:
			line += 1
			i += 1
			continue
		if c == 32 or c == 9 or c == 13:
			i += 1
			continue
		# ---- comments
		if c == 45 and i + 1 < n and src.unicode_at(i + 1) == 45:
			var lvl := _long_bracket_level(src, i + 2)
			if lvl >= 0:
				var close_at := _long_bracket_close(src, i + 2 + lvl + 2, lvl)
				var stop := n if close_at < 0 else close_at + lvl + 2
				findings.append(_finding(line, "long_bracket", "--[[", "block comments and long strings ([[ ]]) are not supported: use -- line comments"))
				line += _count_newlines(src, i, stop)
				i = stop
			else:
				while i < n and src.unicode_at(i) != 10:
					i += 1
			continue
		# ---- names
		if _is_name_start(c):
			var j := i + 1
			while j < n and _is_name_char(src.unicode_at(j)):
				j += 1
			types.append(NAME)
			texts.append(src.substr(i, j - i))
			starts.append(i)
			ends.append(j)
			lines.append(line)
			i = j
			continue
		# ---- numbers
		if _is_digit(c) or (c == 46 and i + 1 < n and _is_digit(src.unicode_at(i + 1))):
			var j := _read_number_end(src, i)
			types.append(NUMBER)
			texts.append(src.substr(i, j - i))
			starts.append(i)
			ends.append(j)
			lines.append(line)
			i = j
			continue
		# ---- strings
		if c == 34 or c == 39:
			var scanned := _read_string(src, i, c, line, findings)
			types.append(STRING)
			texts.append(String(scanned["value"]))
			starts.append(i)
			ends.append(int(scanned["end"]))
			lines.append(line)
			i = int(scanned["end"])
			continue
		# ---- long string  [[ ... ]]
		if c == 91:
			var lvl2 := _long_bracket_level(src, i)
			if lvl2 >= 0:
				var close2 := _long_bracket_close(src, i + lvl2 + 2, lvl2)
				var stop2 := n if close2 < 0 else close2 + lvl2 + 2
				findings.append(_finding(line, "long_bracket", "[[", "long strings ([[ ]]) are not supported: use quoted strings"))
				types.append(STRING)
				texts.append(src.substr(i + lvl2 + 2, maxi(stop2 - lvl2 - 2 - (i + lvl2 + 2), 0)))
				starts.append(i)
				ends.append(stop2)
				lines.append(line)
				line += _count_newlines(src, i, stop2)
				i = stop2
				continue
		# ---- operators and punctuation
		var op := ""
		if i + 2 < n and src.substr(i, 3) == "...":
			op = "..."
		elif i + 1 < n:
			var two := src.substr(i, 2)
			if two in _TWO_CHAR_OPS:
				op = two
		if op == "":
			op = char(c)
			if c == 33:
				findings.append(_finding(line, "stray_character", op, "`!` is not a Lua operator: not equal is `~=`, negation is `not`"))
			elif c > 126 or (c < 32 and c != 9) or c == 63 or c == 64 or c == 36 or c == 92 or c == 96:
				findings.append(_finding(line, "stray_character", op, "unexpected character `%s` outside a string" % op))
		types.append(OP)
		texts.append(op)
		starts.append(i)
		ends.append(i + op.length())
		lines.append(line)
		i += op.length()
	return {
		"count": types.size(), "type": types, "text": texts, "start": starts, "end": ends, "line": lines,
		"findings": findings,
	}


static func _finding(line: int, rule: String, token: String, message: String) -> Dictionary:
	return {"line": line, "rule": rule, "token": token, "message": message}


static func _is_name_start(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95


static func _is_name_char(c: int) -> bool:
	return _is_name_start(c) or _is_digit(c)


static func _is_digit(c: int) -> bool:
	return c >= 48 and c <= 57


static func _count_newlines(src: String, from: int, to: int) -> int:
	var count := 0
	for k in range(from, mini(to, src.length())):
		if src.unicode_at(k) == 10:
			count += 1
	return count


## "[" "="* "[" starting at `at`: returns the number of "=" (0 for "[["), or -1 when there is no long bracket at `at`.
static func _long_bracket_level(src: String, at: int) -> int:
	if at >= src.length() or src.unicode_at(at) != 91:
		return -1
	var j := at + 1
	var level := 0
	while j < src.length() and src.unicode_at(j) == 61:
		level += 1
		j += 1
	if j < src.length() and src.unicode_at(j) == 91:
		return level
	return -1


## index of the "]" that starts the closing long bracket of `level`, searching from `from`; -1 when unterminated.
static func _long_bracket_close(src: String, from: int, level: int) -> int:
	var closer := "]" + "=".repeat(level) + "]"
	return src.find(closer, from)


static func _read_number_end(src: String, at: int) -> int:
	var n := src.length()
	var j := at
	var hex := at + 1 < n and src.unicode_at(at) == 48 and (src.unicode_at(at + 1) == 120 or src.unicode_at(at + 1) == 88)
	while j < n:
		var c := src.unicode_at(j)
		if _is_name_char(c):
			j += 1
		elif c == 46:
			if j + 1 < n and src.unicode_at(j + 1) == 46:
				break                      # `1..x` is a concatenation, not a number
			j += 1
		elif (c == 43 or c == 45) and not hex and j > at and (src.unicode_at(j - 1) == 101 or src.unicode_at(j - 1) == 69):
			j += 1
		else:
			break
	return j


## Reads a quoted string that starts at `at` (the quote character is `quote`). Returns {value, end}.
static func _read_string(src: String, at: int, quote: int, line: int, findings: Array[Dictionary]) -> Dictionary:
	var n := src.length()
	var j := at + 1
	var has_escape := false
	while j < n:
		var c := src.unicode_at(j)
		if c == quote:
			break
		if c == 92:
			has_escape = true
			j += 2
			continue
		if c == 10:
			findings.append(_finding(line, "unterminated_string", src.substr(at, 12), "string is not closed before the end of the line"))
			return {"value": src.substr(at + 1, j - at - 1), "end": j}
		j += 1
	if j >= n:
		findings.append(_finding(line, "unterminated_string", src.substr(at, 12), "string is not closed before the end of the file"))
		return {"value": src.substr(at + 1), "end": n}
	if not has_escape:
		return {"value": src.substr(at + 1, j - at - 1), "end": j + 1}
	var buf := PackedStringArray()
	var k := at + 1
	var flagged := false
	while k < j:
		var ch := src.unicode_at(k)
		if ch == 92 and k + 1 < j:
			var e := src.unicode_at(k + 1)
			match e:
				110: buf.append("\n")
				116: buf.append("\t")
				114: buf.append("\r")
				_: buf.append(char(e))
			if not flagged:
				flagged = true
				var shown := "\\" + char(e)
				var what := "escaped quote" if (e == 34 or e == 39) else "escape sequence"
				findings.append(_finding(line, "escape", shown, "%s in a string is not supported: avoid backslashes and quote characters inside texts (texts live in the CSV files)" % what))
			k += 2
		else:
			buf.append(char(ch))
			k += 1
	return {"value": "".join(buf), "end": j + 1}
