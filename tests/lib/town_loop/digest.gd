class_name LoopDigest
extends RefCounted
## Canonical digest of the game state: SaveManager.gather_payload() with sorted keys, floats snapped to 1e-4, minus the volatile paths (digest_volatile.json), SHA-256.
static func canon(v: Variant) -> Variant:
	if v is Vector2 or v is Vector2i:
		return [canon(v.x), canon(v.y)]
	if v is Dictionary:
		var out := {}
		var keys: Array = (v as Dictionary).keys()
		keys.sort()
		for k in keys:
			out[str(k)] = canon(v[k])
		return out
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(canon(x))
		return a
	if v is float:
		var rounded := snappedf(v, 0.0001)
		return int(rounded) if rounded == floorf(rounded) else rounded
	return v


static func volatile() -> Array:
	var f := FileAccess.get_file_as_string("res://tests/lib/town_loop/digest_volatile.json")
	var d: Variant = JSON.parse_string(f)
	return (d as Dictionary).get("paths", []) if d is Dictionary else []


static func drop(c: Dictionary, paths: Array) -> void:
	for path in paths:
		var parts: PackedStringArray = String(path).trim_prefix("/").split("/")
		var cur: Variant = c
		for i in parts.size() - 1:
			cur = cur.get(parts[i]) if cur is Dictionary else null
		if cur is Dictionary:
			(cur as Dictionary).erase(parts[parts.size() - 1])


static func of_payload(payload: Dictionary, extra_drop: Array = []) -> String:
	var c: Dictionary = canon(payload)
	drop(c, volatile() + extra_drop)
	return JSON.stringify(c, "", false).sha256_text()
