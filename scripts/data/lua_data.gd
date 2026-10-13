class_name LuaData
extends RefCounted
## Tolerant readers for tables that came through the Lua reader or through JSON (a save).
## Facts (verified in Godot 4.7.2, tests/sections/data.gd):
##  * An EMPTY Lua table `{}` arrives as an empty Dictionary from LuaRuntime (older code paths produced an empty Array):
##    dict() and arr() accept both, so a consumer never depends on which one it got.
##  * A table with any `name = value` field arrives as a Dictionary and silently loses its positional entries (the lint reports it).
##  * JSON (saves) returns EVERY number as float (5 -> 5.0): int_of() / int_map() give the ints back.
## Every consumer of Lua data reads through these helpers instead of assuming a type.

static func dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func arr(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


static func int_of(v: Variant, default_value: int = 0) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(v)
		TYPE_BOOL:
			return default_value
		TYPE_STRING, TYPE_STRING_NAME:
			var s := str(v)
			if s.is_valid_int():
				return s.to_int()
			return int(s.to_float()) if s.is_valid_float() else default_value
	return default_value


static func num(v: Variant, default_value: float = 0.0) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_STRING, TYPE_STRING_NAME:
			var s := str(v)
			return s.to_float() if s.is_valid_float() else default_value
	return default_value


## Every entry as a String: { "a", "b" } -> ["a", "b"] (numbers and names are stringified).
static func strings(v: Variant) -> Array[String]:
	var out: Array[String] = []
	for x in arr(v):
		out.append(str(x))
	return out


## { a = 2, b = 5 } -> {"a": 2, "b": 5} with the counts coerced to int (also after a JSON round trip); `{}` gives {}.
static func int_map(v: Variant) -> Dictionary:
	var out := {}
	var d := dict(v)
	for k in d:
		out[str(k)] = int_of(d[k])
	return out
