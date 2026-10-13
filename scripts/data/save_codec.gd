class_name SaveCodec
extends RefCounted
## JSON-safe encode/decode helpers for the save sections. Facts verified in Godot 4.7.2 (tests/sections/data.gd):
##  * JSON.parse returns EVERY number as float (5 -> 5.0): a typed `var x: int = v` converts, but dictionary values stay float
##    and print as "5.0" -> int_counts() / to_int() restore ints.
##  * StringName and String are interchangeable as Dictionary keys and in ==, but JSON writes a StringName as a plain String
##    and reads it back as String -> names_to_json() / names_from_json() make the round trip explicit.
##  * Vector2i / Vector2 stringify as the STRING "(3, 4)" (a silent data change) -> cells are stored as [x, z] arrays.
##  * numbers above 2^53 lose precision -> RandomNumberGenerator seed/state (uint64) are stored as decimal STRINGS.

static func to_int(v: Variant, default_value: int = 0) -> int:
	return LuaData.int_of(v, default_value)


## {"id": 3.0, "b": 0, "c": -2, "d": "4"} -> {"id": 3, "d": 4}: ints, plain String keys, non-positive and non-numeric entries dropped
static func int_counts(v: Variant) -> Dictionary:
	var out := {}
	var d := LuaData.dict(v)
	for k in d:
		var n := to_int(d[k], 0)
		if n > 0:
			out[str(k)] = n
	return out


static func cell_to_json(c: Vector2i) -> Array:
	return [c.x, c.y]


static func cell_from_json(v: Variant) -> Vector2i:
	var a := LuaData.arr(v)
	return Vector2i(to_int(a[0]), to_int(a[1])) if a.size() >= 2 else Vector2i.ZERO


## [Vector2i, ...] -> [[x, z], ...]
static func cells_to_json(cells: Array) -> Array:
	var out: Array = []
	for c in cells:
		out.append(cell_to_json(c))
	return out


## [[x, z], ...] -> Array[Vector2i]; malformed entries are skipped
static func cells_from_json(v: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e in LuaData.arr(v):
		var a := LuaData.arr(e)
		if a.size() >= 2:
			out.append(Vector2i(to_int(a[0]), to_int(a[1])))
	return out


## seed and state of a RandomNumberGenerator as decimal strings
static func rng_to_json(rng: RandomNumberGenerator) -> Dictionary:
	return {"seed": str(rng.seed), "state": str(rng.state)}


## Restores the exact stream position: seed first (setting the seed resets the state), then the state. An empty or
## missing dictionary randomizes.
static func rng_from_json(rng: RandomNumberGenerator, d: Variant) -> void:
	var dd := LuaData.dict(d)
	if dd.is_empty():
		rng.randomize()
		return
	rng.seed = str(dd.get("seed", "0")).to_int()
	rng.state = str(dd.get("state", "0")).to_int()


## [&"a", &"b"] -> ["a", "b"]
static func names_to_json(names: Array) -> Array:
	var out: Array = []
	for n in names:
		out.append(str(n))
	return out


## ["a", "b"] -> Array[StringName]
static func names_from_json(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	for n in LuaData.arr(v):
		out.append(StringName(str(n)))
	return out


## A full JSON round trip (stringify + parse): what a value looks like after a save and a load.
static func through_json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))
