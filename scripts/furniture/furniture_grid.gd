class_name FurnitureGrid
extends RefCounted
## Pure-logic furniture placement grid (no nodes): footprints, 4 rotations, snapping, overlap/collision rejection and the five layers.
##   floor     blocks cells (walking + other floor items)          rug      flat, under everything, one per cell, never blocks
##   wall      hangs on the two back walls (segment index along the wall), clearance vs. tall floor items, windows keep their segments
##   tabletop  sits on a host's surface slot (host: floor item with `surface`)      ceiling  hangs above a cell, one per cell
## Cell convention: (x, z) integer cells; the placement `cell` is the MIN-x / MIN-z corner cell of the footprint.  Rotation r: front faces +z, +x, -z, -x.
## Reject reasons are stable strings (UI maps them to Danish text).

const REASONS := ["ok", "out_of_room", "overlap", "door_blocked", "blocks_window", "too_tall", "needs_wall", "blocks_path", "full", "wall_orientation", "wall_taken", "needs_window", "window_taken", "needs_surface", "slot_taken", "unknown_item"]

var items: Dictionary = {}                 # item_id -> meta (furniture.json "items")
var floor_cells: Dictionary = {}           # Vector2i -> true
var rows: Array = []
var door_cell := Vector2i.ZERO
var spawn_cell := Vector2i.ZERO
var window_z: Dictionary = {}              # x -> true   (segments of the z-wall = back-right wall, indexed by x)
var window_x: Dictionary = {}              # z -> true   (segments of the x-wall = back-left wall, indexed by z)
var max_items := 999
var placements: Dictionary = {}            # uid -> {uid,item_id,cell,rot,layer,host,slot}
var occ_floor: Dictionary = {}             # Vector2i -> uid
var occ_rug: Dictionary = {}
var occ_wall: Dictionary = {}              # "z:3" / "x:2" -> uid
var occ_ceiling: Dictionary = {}
var occ_slot: Dictionary = {}              # "hostuid:slotindex" -> uid
var _next_uid := 1
var _why := ""
const BLOCKS_WINDOW := ["wardrobe", "bookshelf", "fireplace", "clock", "throne", "bed", "piano"]


func setup(room: Dictionary, furniture_items: Dictionary) -> void:
	items = furniture_items
	placements.clear()
	occ_floor.clear()
	occ_rug.clear()
	occ_wall.clear()
	occ_ceiling.clear()
	occ_slot.clear()
	_next_uid = 1
	rows = room["rows"]
	floor_cells.clear()
	for c in room["cells"]:
		floor_cells[Vector2i(int(c[0]), int(c[1]))] = true
	door_cell = Vector2i(int(room["door"]["cell"][0]), int(room["door"]["cell"][1]))
	spawn_cell = Vector2i(int(room["spawn_cell"][0]), int(room["spawn_cell"][1]))
	window_z.clear()
	window_x.clear()
	for x in room["windows"]["z"]:
		window_z[int(x)] = true
	for z in room["windows"]["x"]:
		window_x[int(z)] = true
	max_items = int(room.get("max_furniture", 999))


# ------------------------------------------------------------------------------------------------------------------------------
func footprint_cells(item_id: String, cell: Vector2i, rot: int) -> Array[Vector2i]:
	var m: Dictionary = items[item_id]
	var d := HomeData.rot_dims(m["footprint"], rot)
	var out: Array[Vector2i] = []
	if m["layer"] == "wall":
		return out
	for dz in d.y:
		for dx in d.x:
			out.append(cell + Vector2i(dx, dz))
	return out


func footprint_center(item_id: String, cell: Vector2i, rot: int) -> Vector2:
	var d := HomeData.rot_dims(items[item_id]["footprint"], rot)
	return Vector2(cell) + Vector2((d.x - 1) * 0.5, (d.y - 1) * 0.5)


func wall_segments(item_id: String, cell: Vector2i, rot: int) -> Array:
	## [axis, [indices]] for a wall item: rot 0 hangs on the z-wall (indexed by x), rot 1 on the x-wall (indexed by z)
	var fx := int(items[item_id]["footprint"][0])
	if rot == 0:
		return ["z", range(cell.x, cell.x + fx)]
	if rot == 1:
		return ["x", range(cell.y, cell.y + fx)]
	return []


func _seg_count(axis: String) -> int:
	return int(rows[0]) if axis == "z" else rows.size()


func _is_window(axis: String, i: int) -> bool:
	return window_z.has(i) if axis == "z" else window_x.has(i)


func _floor_item_at(c: Vector2i) -> Dictionary:
	if occ_floor.has(c):
		return placements[occ_floor[c]]
	return {}


func _height(item_id: String) -> float:
	return float(items[item_id]["height_m"])


# ------------------------------------------------------------------------------------------------------------------------------
func can_place(item_id: String, cell: Vector2i, rot: int, ignore_uid: int = -1) -> Dictionary:
	if not items.has(item_id) or rot < 0 or rot > 3:
		return _res("unknown_item")
	var m: Dictionary = items[item_id]
	var layer: String = m["layer"]
	if placements.size() - int(placements.has(ignore_uid)) >= max_items:
		return _res("full")
	match layer:
		"floor": return _can_floor(item_id, m, cell, rot, ignore_uid)
		"rug": return _can_rug(item_id, cell, rot, ignore_uid)
		"wall": return _can_wall(item_id, m, cell, rot, ignore_uid)
		"tabletop": return _can_tabletop(item_id, m, cell, rot, ignore_uid)
		"ceiling": return _can_ceiling(item_id, cell, ignore_uid)
	return _res("unknown_item")


func floor_count(ignore_uid: int = -1) -> int:
	var n := 0
	for uid in placements:
		if placements[uid]["layer"] == "floor" and uid != ignore_uid:
			n += 1
	return n


func _res(reason: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": reason == "ok", "reason": reason, "text_key": "" if reason == "ok" else "FURNI_REJECT_" + reason.to_upper()}
	d.merge(extra)
	return d


func _can_floor(item_id: String, m: Dictionary, cell: Vector2i, rot: int, ignore_uid: int) -> Dictionary:
	var cells := footprint_cells(item_id, cell, rot)
	for c in cells:
		if not floor_cells.has(c):
			return _res("out_of_room", {"cells": cells})
	for c in cells:
		if occ_floor.has(c) and occ_floor[c] != ignore_uid:
			return _res("overlap", {"cells": cells})
	for c in cells:
		if c == door_cell or c == spawn_cell:
			return _res("door_blocked", {"cells": cells})
	if m["template"] in BLOCKS_WINDOW:
		for c in cells:
			if (c.y == 0 and window_z.has(c.x)) or (c.x == 0 and window_x.has(c.y)):
				return _res("blocks_window", {"cells": cells})
	for c in cells:                                   # wall items already hanging behind must stay clear of this piece
		var keys: Array[String] = []
		if c.y == 0:
			keys.append("z:%d" % c.x)
		if c.x == 0:
			keys.append("x:%d" % c.y)
		for k in keys:
			if occ_wall.has(k) and occ_wall[k] != ignore_uid:
				var wi: Dictionary = placements[occ_wall[k]]
				if float(items[wi["item_id"]].get("hang_m", 9.0)) < float(m["height_m"]) and float(m["height_m"]) > 1.0:
					return _res("too_tall", {"cells": cells})
	if m.get("wall_back", false) or m["template"] == "fireplace":
		var ok := (rot == 0 and cell.y == 0) or (rot == 1 and cell.x == 0)
		if not ok:
			return _res("needs_wall", {"cells": cells})
	# the door must still reach the spawn tile and the 'front' of every interactive piece
	_why = ""
	if not _path_ok(cells, item_id, cell, rot, ignore_uid):
		return _res("blocks_path", {"cells": cells, "why": _why})
	return _res("ok", {"cells": cells})


func _can_rug(item_id: String, cell: Vector2i, rot: int, ignore_uid: int) -> Dictionary:
	var cells := footprint_cells(item_id, cell, rot)
	for c in cells:
		if not floor_cells.has(c):
			return _res("out_of_room", {"cells": cells})
		if occ_rug.has(c) and occ_rug[c] != ignore_uid:
			return _res("overlap", {"cells": cells})
	return _res("ok", {"cells": cells})


func _can_ceiling(item_id: String, cell: Vector2i, ignore_uid: int) -> Dictionary:
	var cells: Array[Vector2i] = [cell]
	if not floor_cells.has(cell):
		return _res("out_of_room", {"cells": cells})
	if occ_ceiling.has(cell) and occ_ceiling[cell] != ignore_uid:
		return _res("overlap", {"cells": cells})
	return _res("ok", {"cells": cells})


func _can_wall(item_id: String, m: Dictionary, cell: Vector2i, rot: int, ignore_uid: int) -> Dictionary:
	var seg := wall_segments(item_id, cell, rot)
	if seg.is_empty():
		return _res("wall_orientation")
	var axis: String = seg[0]
	if (axis == "z" and cell.y != 0) or (axis == "x" and cell.x != 0):
		return _res("needs_wall")
	var idxs: Array = seg[1]
	var needs_window: bool = m["template"] == "curtain"
	for i in idxs:
		if i < 0 or i >= _seg_count(axis):
			return _res("out_of_room")
		var k := "%s:%d" % [axis, i]
		if occ_wall.has(k) and occ_wall[k] != ignore_uid:
			return _res("wall_taken")
		if needs_window and not _is_window(axis, i):
			return _res("needs_window")
		if (not needs_window) and _is_window(axis, i):
			return _res("window_taken")
		var fc := Vector2i(i, 0) if axis == "z" else Vector2i(0, i)
		if occ_floor.has(fc):
			var fi: Dictionary = placements[occ_floor[fc]]
			if float(items[fi["item_id"]]["height_m"]) > float(m.get("hang_m", 1.0)) and float(items[fi["item_id"]]["height_m"]) > 1.0:
				return _res("too_tall")
	return _res("ok", {"segments": idxs, "axis": axis})


func surface_slot_cells(host_uid: int) -> Array:
	## absolute cell of every surface slot of a floor host
	var p: Dictionary = placements[host_uid]
	var meta: Dictionary = items[p["item_id"]]
	var out: Array = []
	if not meta.has("surface"):
		return out
	var ent: Dictionary = meta["rot"][str(int(((meta["rot_map"] as Array)[p["rot"]] as Array)[0]))]
	var slots: Array = ent.get("surface_slots", meta["surface"]["slots"])
	var ctr := footprint_center(p["item_id"], p["cell"], p["rot"])
	for s in slots:
		out.append(Vector2i((ctr + Vector2(s[0], s[1])).round()))
	return out


func _can_tabletop(item_id: String, m: Dictionary, cell: Vector2i, rot: int, ignore_uid: int) -> Dictionary:
	if not occ_floor.has(cell):
		return _res("needs_surface")
	var host := int(occ_floor[cell])
	if not items[placements[host]["item_id"]].has("surface"):
		return _res("needs_surface")
	var slots := surface_slot_cells(host)
	var si := slots.find(cell)
	if si < 0:
		return _res("needs_surface")
	var k := "%d:%d" % [host, si]
	if occ_slot.has(k) and occ_slot[k] != ignore_uid:
		return _res("slot_taken")
	return _res("ok", {"host": host, "slot": si, "cells": [cell]})


# ---- reachability ---------------------------------------------------------------------------------------------------------------
func front_cells(item_id: String, cell: Vector2i, rot: int) -> Array[Vector2i]:
	## cells a person can use to reach the piece: the FRONT side for warm/play/storage pieces, any free neighbour for sit/sleep pieces
	var m: Dictionary = items[item_id]
	var out: Array[Vector2i] = []
	if not m.has("interact"):
		return out
	var cells := footprint_cells(item_id, cell, rot)
	var mn := Vector2i(999, 999)
	var mx := Vector2i(-999, -999)
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var typ := String((m["interact"] as Dictionary).get("type", ""))
	if typ == "sit" or typ == "sleep":
		for x in range(mn.x, mx.x + 1):
			out.append(Vector2i(x, mn.y - 1)); out.append(Vector2i(x, mx.y + 1))
		for z in range(mn.y, mx.y + 1):
			out.append(Vector2i(mn.x - 1, z)); out.append(Vector2i(mx.x + 1, z))
		return out
	var fr: Array = (m["interact"] as Dictionary).get("from", [0, 1])
	var f: Vector2 = HomeData.rot_vec(Vector2(fr[0], fr[1]), rot)
	if f.y > 0.5:
		for x in range(mn.x, mx.x + 1): out.append(Vector2i(x, mx.y + 1))
	elif f.y < -0.5:
		for x in range(mn.x, mx.x + 1): out.append(Vector2i(x, mn.y - 1))
	elif f.x > 0.5:
		for z in range(mn.y, mx.y + 1): out.append(Vector2i(mx.x + 1, z))
	else:
		for z in range(mn.y, mx.y + 1): out.append(Vector2i(mn.x - 1, z))
	return out


func is_walkable(c: Vector2i, extra_blocked: Array = []) -> bool:
	return floor_cells.has(c) and not occ_floor.has(c) and not (c in extra_blocked)


func reachable(extra_blocked: Array = []) -> Dictionary:
	var seen: Dictionary = {door_cell: true}
	var q: Array[Vector2i] = [door_cell]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and is_walkable(n, extra_blocked):
				seen[n] = true
				q.append(n)
	return seen


func _path_ok(cells: Array[Vector2i], item_id: String, cell: Vector2i, rot: int, ignore_uid: int) -> bool:
	# temporarily treat the new footprint (and not the ignored piece) as blocked
	var saved: Dictionary = {}
	if ignore_uid in placements:
		for c in footprint_cells(placements[ignore_uid]["item_id"], placements[ignore_uid]["cell"], placements[ignore_uid]["rot"]):
			if occ_floor.get(c, -1) == ignore_uid:
				saved[c] = ignore_uid
				occ_floor.erase(c)
	var seen := reachable(cells)
	var ok := seen.has(spawn_cell)
	if ok:
		for uid in placements:
			var p: Dictionary = placements[uid]
			if p["layer"] != "floor" or uid == ignore_uid or not items[p["item_id"]].has("interact"):
				continue
			var fr := front_cells(p["item_id"], p["cell"], p["rot"])
			var any := false
			for f in fr:
				if seen.has(f):
					any = true
			if not any:
				ok = false
				_why = "%s@%s" % [p["item_id"], p["cell"]]
				break
	if ok and items[item_id].has("interact"):
		var any2 := false
		for f in front_cells(item_id, cell, rot):
			if seen.has(f):
				any2 = true
		ok = any2 or front_cells(item_id, cell, rot).is_empty()
		if not ok: _why = "self"
	for c in saved:
		occ_floor[c] = saved[c]
	return ok


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var prev: Dictionary = {from: from}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not prev.has(n) and (is_walkable(n) or n == to) and floor_cells.has(n):
				prev[n] = c
				q.append(n)
	var path: Array[Vector2i] = []
	if not prev.has(to):
		return path
	var cur := to
	while cur != from:
		path.push_front(cur)
		cur = prev[cur]
	return path


# ---- mutation -------------------------------------------------------------------------------------------------------------------
func place(item_id: String, cell: Vector2i, rot: int) -> int:
	var r := can_place(item_id, cell, rot)
	if not r["ok"]:
		return -1
	var m: Dictionary = items[item_id]
	var uid := _next_uid
	_next_uid += 1
	var p := {"uid": uid, "item_id": item_id, "cell": cell, "rot": rot, "layer": m["layer"]}
	match m["layer"]:
		"floor":
			for c in footprint_cells(item_id, cell, rot): occ_floor[c] = uid
		"rug":
			for c in footprint_cells(item_id, cell, rot): occ_rug[c] = uid
		"wall":
			for i in r["segments"]: occ_wall["%s:%d" % [r["axis"], i]] = uid
			p["axis"] = r["axis"]
			p["segments"] = r["segments"]
		"tabletop":
			occ_slot["%d:%d" % [r["host"], r["slot"]]] = uid
			p["host"] = r["host"]
			p["slot"] = r["slot"]
		"ceiling":
			occ_ceiling[cell] = uid
	placements[uid] = p
	return uid


func remove(uid: int) -> void:
	if not placements.has(uid):
		return
	var p: Dictionary = placements[uid]
	for k in occ_floor.keys():
		if occ_floor[k] == uid: occ_floor.erase(k)
	for k in occ_rug.keys():
		if occ_rug[k] == uid: occ_rug.erase(k)
	for k in occ_wall.keys():
		if occ_wall[k] == uid: occ_wall.erase(k)
	for k in occ_ceiling.keys():
		if occ_ceiling[k] == uid: occ_ceiling.erase(k)
	for k in occ_slot.keys():
		if occ_slot[k] == uid: occ_slot.erase(k)
	if p["layer"] == "floor":                     # things standing on it go with it (they would float otherwise)
		for k in occ_slot.keys():
			if k.begins_with("%d:" % uid):
				var t: int = occ_slot[k]
				occ_slot.erase(k)
				placements.erase(t)
	placements.erase(uid)


func to_save() -> Array:
	var out: Array = []
	for uid in placements:
		var p: Dictionary = placements[uid]
		out.append({"item": p["item_id"], "cell": [p["cell"].x, p["cell"].y], "rot": p["rot"]})
	return out


func load_save(arr: Array) -> Array:
	# Restore hosts before their tabletop pieces. Unknown or malformed records
	# are rejected explicitly; the owner decides whether to retain them in stock.
	var rejected: Array = []
	var valid: Array = []
	for entry in arr:
		if not entry is Dictionary or not items.has(str(entry.get("item", ""))):
			rejected.append(entry)
			continue
		var c: Variant = entry.get("cell")
		var r: Variant = entry.get("rot", 0)
		if not c is Array or c.size() != 2 or not _integer(c[0]) or not _integer(c[1]) or not _integer(r):
			rejected.append(entry)
			continue
		valid.append(entry)
	for layer in ["rug", "floor", "wall", "tabletop", "ceiling"]:
		for e in valid:
			if items[e.item].layer == layer:
				if place(e.item, Vector2i(int(e.cell[0]), int(e.cell[1])), int(e.get("rot", 0))) < 0:
					rejected.append(e)
	return rejected

static func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value) and abs(value) < 1000000)
