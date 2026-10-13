class_name FeatureRoom
extends RefCounted
## Content-level model of one home room (tier 1..10) for the feature tests of package F1.  It is NOT the game's placement grid (F3's FurnitureGrid is, wave 4):
## it implements the handful of rules that only need the DATA - the room cells of A1 (assets/data/home/rooms/room_tNN.json), the footprint / placement layer / interaction
## of the item definitions (lua/items/furniture.lua) - so that wave 3 can prove "the starter kit places", "the kit fits every later tier" and can stand in as the backend of a
## fake FurnitureManager (tests/lib/features/fake_furniture.gd) for AutoFurnish / Grant.  F3's own tests prove the real grid; the two must agree on these rules:
##   inside the room cells, no overlap on one layer (floor pieces block each other, rugs are one per cell on their own layer, one wall piece / tabletop piece / ceiling piece per cell),
##   the door cell and the cell before it (spawn) stay free of floor pieces, every interactive floor piece has a free neighbour cell reachable from the door (BFS),
##   wall pieces only on the two back walls (cells with x == 0 or z == 0), tabletop pieces only on a cell covered by a floor piece that offers a surface (table, storage, shelf, hearth),
##   capacity = max_furniture of the tier.

const ROOM_DIR := "res://assets/data/home/rooms/"
const INTERACTIVE := ["sleep", "sit", "storage", "warm", "play"]
const SURFACE_TYPES := ["table", "storage", "shelf", "hearth", "grand", "instrument"]

var tier: int = 1
var cells: Dictionary = {}                 # Vector2i -> true
var door: Vector2i = Vector2i.ZERO
var spawn: Vector2i = Vector2i.ZERO
var max_furniture: int = 0
var pieces: Array[Dictionary] = []         # {id, cell, rot, layer}


## Room of a home tier from A1's room json; null when the file is missing or malformed.
static func load_tier(n: int) -> FeatureRoom:
	var path := "%sroom_t%02d.json" % [ROOM_DIR, n]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = parsed
	var room := FeatureRoom.new()
	room.tier = int(n)
	for c in d.get("cells", []):
		room.cells[Vector2i(int(c[0]), int(c[1]))] = true
	var dc: Array = d.get("door", {}).get("cell", [0, 0])
	room.door = Vector2i(int(dc[0]), int(dc[1]))
	var sc: Array = d.get("spawn_cell", [0, 0])
	room.spawn = Vector2i(int(sc[0]), int(sc[1]))
	room.max_furniture = int(d.get("max_furniture", 0))
	return room


## [w, d] of an item, swapped for the odd rotations.
static func footprint_of(item_id: Variant, rot: int = 0) -> Vector2i:
	var def := ItemKinds.def(item_id)
	var fp := LuaData.arr(def.get("footprint", [1, 1]))
	var w := LuaData.int_of(fp[0], 1) if fp.size() > 0 else 1
	var dd := LuaData.int_of(fp[1], 1) if fp.size() > 1 else 1
	return Vector2i(dd, w) if (rot % 2) != 0 else Vector2i(w, dd)


static func layer_of(item_id: Variant) -> String:
	return str(ItemKinds.def(item_id).get("placement", "floor"))


func covered_cells(item_id: Variant, cell: Vector2i, rot: int) -> Array[Vector2i]:
	var fp := footprint_of(item_id, rot)
	var out: Array[Vector2i] = []
	for dx in fp.x:
		for dz in fp.y:
			out.append(cell + Vector2i(dx, dz))
	return out


## {ok: bool, reason: String}; reason is a short id (no text: texts live in CSVs).
func can_place(item_id: Variant, cell: Vector2i, rot: int = 0) -> Dictionary:
	var def := ItemKinds.def(item_id)
	if def.is_empty() or str(def.get("category", "")) != "furniture":
		return {"ok": false, "reason": "not_furniture"}
	if pieces.size() >= max_furniture:
		return {"ok": false, "reason": "capacity"}
	var layer := layer_of(item_id)
	var covered := covered_cells(item_id, cell, rot)
	for c in covered:
		if not cells.has(c):
			return {"ok": false, "reason": "outside"}
	match layer:
		"floor":
			for c in covered:
				if c == door or c == spawn:
					return {"ok": false, "reason": "door"}
				if _layer_blocks("floor", c):
					return {"ok": false, "reason": "overlap"}
			var probe := _with(item_id, cell, rot, layer)
			if not _paths_ok(probe):
				return {"ok": false, "reason": "path"}
		"rug":
			for c in covered:
				if _layer_blocks("rug", c):
					return {"ok": false, "reason": "overlap"}
		"wall":
			for c in covered:
				if c.x != 0 and c.y != 0:
					return {"ok": false, "reason": "not_on_wall"}
				if _layer_blocks("wall", c):
					return {"ok": false, "reason": "overlap"}
		"tabletop":
			for c in covered:
				if not _surface_at(c):
					return {"ok": false, "reason": "needs_table"}
				if _layer_blocks("tabletop", c):
					return {"ok": false, "reason": "overlap"}
		"ceiling":
			for c in covered:
				if _layer_blocks("ceiling", c):
					return {"ok": false, "reason": "overlap"}
		_:
			return {"ok": false, "reason": "unknown_layer"}
	return {"ok": true, "reason": ""}


func place(item_id: Variant, cell: Vector2i, rot: int = 0) -> Dictionary:
	var r := can_place(item_id, cell, rot)
	if bool(r["ok"]):
		pieces.append({"id": str(item_id), "cell": cell, "rot": rot, "layer": layer_of(item_id)})
	return r


func remove_at(index: int) -> void:
	if index >= 0 and index < pieces.size():
		pieces.remove_at(index)


func count_of(item_id: Variant) -> int:
	var n := 0
	for p in pieces:
		if str(p["id"]) == str(item_id):
			n += 1
	return n


## Sum of `decor` of everything placed (what FurnitureManager.hygge_score() is, without set bonuses).
func decor_total() -> int:
	var sum := 0
	for p in pieces:
		sum += LuaData.int_of(ItemKinds.def(p["id"]).get("decor", 0))
	return sum


## First position in scan order (back row first, left to right, rotation 0..3) where the item can be placed; {} when there is none.
func find_spot(item_id: Variant) -> Dictionary:
	var order: Array[Vector2i] = []
	for c in cells:
		order.append(c)
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c in order:
		for rot in 4:
			if bool(can_place(item_id, c, rot)["ok"]):
				return {"cell": c, "rot": rot}
	return {}


# ----------------------------------------------------------------------------------------------------------------- internals

func _layer_blocks(layer: String, c: Vector2i) -> bool:
	for p in pieces:
		if str(p["layer"]) == layer and c in covered_cells(p["id"], p["cell"], int(p["rot"])):
			return true
	return false


func _surface_at(c: Vector2i) -> bool:
	for p in pieces:
		if str(p["layer"]) == "floor" and c in covered_cells(p["id"], p["cell"], int(p["rot"])):
			if str(ItemKinds.def(p["id"]).get("furniture_type", "")) in SURFACE_TYPES:
				return true
	return false


func _with(item_id: Variant, cell: Vector2i, rot: int, layer: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(pieces)
	out.append({"id": str(item_id), "cell": cell, "rot": rot, "layer": layer})
	return out


## Every interactive floor piece must have a free neighbour cell that the player can reach from the door; the spawn cell must stay reachable.
func _paths_ok(all_pieces: Array[Dictionary]) -> bool:
	var blocked: Dictionary = {}
	for p in all_pieces:
		if str(p["layer"]) == "floor":
			for c in covered_cells(p["id"], p["cell"], int(p["rot"])):
				blocked[c] = true
	var seen: Dictionary = {spawn: true}
	var queue: Array[Vector2i] = [spawn]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + step
			if cells.has(nxt) and not blocked.has(nxt) and not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	for p in all_pieces:
		if str(p["layer"]) != "floor":
			continue
		if str(ItemKinds.def(p["id"]).get("interact", "")) not in INTERACTIVE:
			continue
		var covered := covered_cells(p["id"], p["cell"], int(p["rot"]))
		var reachable := false
		for c in covered:
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = c + step
				if seen.has(nb) and not (nb in covered):
					reachable = true
		if not reachable:
			return false
	return true
