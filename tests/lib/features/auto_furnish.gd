class_name AutoFurnish
extends RefCounted
## Test helper: fills the home with real furniture THROUGH THE PUBLIC APIs until a hygge target is met:
##   EconomyManager.add_item(<furniture id>) -> (routed) FurnitureManager store -> FurnitureManager.place_from_stock(id, cell, rot) -> its grid decides (rules, capacity).
## Greedy by hygge per slot (then the cheaper piece) over the BUYABLE catalogue of the allowed rarities; for every piece it tries every cell of the room of the current home tier (A1's room json) and the four rotations
## and keeps the first position the manager accepts.  A piece that fits nowhere is taken out of the stock again (no stray copies).  Returns the number of pieces placed.
## Needs only: FurnitureManager.place_from_stock(id, cell, rot) -> {ok}, hygge_score() (the BINDING accessor of PLAN_FEATURES.md section 3 task 4 / RF16; the prototype's hygge_total() is NOT accepted),
## count_total(id) [+ item_hygge(id) for the ordering, else the item's `decor`]; a manager without hygge_score() places nothing (fill() returns 0, Grant reports the missing accessor);
## in wave 3 the manager is tests/lib/features/fake_furniture.gd (Svc.override), from wave 4 F3's real one with the real grid - the helper does not change.
## Lifted from the design prototype's tests/lib/auto_furnish.gd (ideas + the loop; the prototype ordered by hygge per gold, which runs out of slots before a high level is reached), re-written against the content ids and the public APIs only (no FurnitureGrid internals).

const MAX_COPIES_PER_ID := 3        # a fourth copy of one id adds little hygge and fills the room: stop after three rounds


## ids of the buyable furniture of the allowed rarities, the pieces with the most hygge per SLOT first (a room has few slots, the price is irrelevant for a test: the stock is free)
static func candidates(allowed: Array) -> Array:
	var out: Array = []
	for id in ItemKinds.all_ids("furniture"):
		var d := ItemKinds.def(id)
		if str(Rarity.normalize(d.get("rarity", "normal"))) in allowed and LuaData.int_of(d.get("buy_price", 0)) > 0:
			out.append(str(id))
	out.sort_custom(func(a, b):
		var ha := _hygge_of(a)
		var hb := _hygge_of(b)
		if ha != hb:
			return ha > hb
		var pa := LuaData.int_of(ItemKinds.def(a).get("buy_price", 0))
		var pb := LuaData.int_of(ItemKinds.def(b).get("buy_price", 0))
		return pa < pb if pa != pb else str(a) < str(b))
	return out


## [cell, rot] pairs worth trying for an item in the room of the current tier (wall pieces: the two back walls first)
static func positions(item_id: String, room: FeatureRoom) -> Array:
	var out: Array = []
	var order: Array[Vector2i] = []
	for c in room.cells:
		order.append(c)
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	if FeatureRoom.layer_of(item_id) == "wall":
		for c in order:
			if c.x == 0 or c.y == 0:
				for r in 4:
					out.append([c, r])
		return out
	for c in order:
		for r in 4:
			out.append([c, r])
	return out


## tries to place one copy that is ALREADY in the store (stock); true when the manager accepted a position
static func place_any(item_id: String) -> bool:
	var fm := Svc.node("FurnitureManager")
	if fm == null:
		return false
	var room := FeatureRoom.load_tier(current_tier())
	if room == null:
		return false
	for p in positions(item_id, room):
		if bool(fm.place_from_stock(StringName(item_id), p[0], int(p[1])).get("ok", false)):
			return true
	return false


## The score of the manager through the binding accessor hygge_score(); -1 when there is no manager or it has no such method (the helpers then report instead of calling a method that is not there).
static func hygge_score_of(fm: Object) -> int:
	if fm == null or not fm.has_method("hygge_score"):
		return -1
	return int(fm.call("hygge_score"))


## give + place copies (max MAX_COPIES_PER_ID per id) until hygge_score() >= target; returns the number of pieces placed
static func fill(target: int, allowed: Array = ["normal", "uncommon", "rare"]) -> int:
	var fm := Svc.node("FurnitureManager")
	var eco := Svc.node("EconomyManager")
	if fm == null or eco == null or hygge_score_of(fm) < 0:
		return 0
	var placed := 0
	for copy_round in MAX_COPIES_PER_ID:
		for id in candidates(allowed):
			if hygge_score_of(fm) >= target:
				return placed
			if int(fm.count_total(StringName(id))) > copy_round:
				continue
			if not bool(eco.add_item(StringName(id), 1, true)):
				continue
			if place_any(id):
				placed += 1
			else:
				eco.remove_item(StringName(id), 1)       # it did not fit anywhere: leave no stray stock behind
	return placed


static func current_tier() -> int:
	var gm := Svc.node("GameManager")
	return clampi(int(gm.flag_int(&"home_tier", 1)) if gm != null and gm.has_method("flag_int") else 1, 1, 10)


static func _hygge_of(item_id: Variant) -> int:
	var fm := Svc.node("FurnitureManager")
	if fm != null and fm.has_method("item_hygge"):
		return int(fm.call("item_hygge", item_id))
	return LuaData.int_of(ItemKinds.def(item_id).get("decor", 0))
