class_name PaintedShopArt
extends RefCounted
## Read-only art access for the gallery. PieceCatalog owns gameplay resolution.
const PACK := "res://assets/iso_props/shops/core/"
const FURNITURE := "res://assets/iso_props/furniture/"
const SPECIAL := "res://assets/iso_props/shops/special/"
static var _tables: Dictionary = {}

static func table(path: String) -> Dictionary:
	if not _tables.has(path):
		_tables[path] = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _tables[path]

static func pieces() -> Dictionary:
	return (table(PACK + "shops.json")["items"] as Dictionary).duplicate(true)

static func rooms() -> Dictionary:
	return (table("res://docs/art/shop-core/room-contracts.json")["rooms"] as Dictionary).duplicate(true)

static func special_pieces() -> Dictionary:
	return (table(SPECIAL + "shops.json")["items"] as Dictionary).duplicate(true)

static func piece(id: String, rotation: int = 0, stand_in: bool = false, specialist: bool = false) -> Dictionary:
	var items: Dictionary = table(PACK + "shops.json")["items"]
	var furniture: Dictionary = table(FURNITURE + "furniture.json")["items"]
	var definition: Dictionary = items.get(id, {})
	var original: Dictionary = definition
	var folder := PACK
	if specialist and table(SPECIAL + "shops.json")["items"].has(id):
		definition = table(SPECIAL + "shops.json")["items"][id]
		original = definition
		folder = SPECIAL
	elif stand_in and not definition.is_empty():
		definition = furniture.get(str(definition["fallback_id"]), {})
		folder = FURNITURE
	elif definition.is_empty():
		definition = furniture.get(id, {})
		folder = FURNITURE
	var rec: Dictionary = (definition.get("rot", {}) as Dictionary).get(str(rotation), {})
	if rec.is_empty():
		return {}
	var out := rec.duplicate(true)
	out["path"] = folder + str(rec["file"])
	if rec.has("night"):
		out["night_path"] = folder + str(rec["night"])
	out["layer"] = original.get("layer", definition.get("layer", "floor"))
	if stand_in and not original.is_empty():
		var fp: Array = original["footprint"].duplicate()
		if rotation % 2 == 1:
			fp.reverse()
		out["footprint"] = fp
		out["ysort"] = [-(fp[0] + fp[1]) * 32, (fp[1] - fp[0]) * 19]
	return out
