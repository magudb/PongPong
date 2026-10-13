class_name FakeFurnitureManager
extends Node
## Stand-in for the FurnitureManager autoload of F3 (wave 4) so that the helpers of F1 (AutoFurnish, Grant) and the section content_features can be proven in wave 3, with the REAL
## EconomyManager in front of it: `Svc.override("FurnitureManager", FakeFurnitureManager.new(1))` and EconomyManager.add_item(<furniture id>) lands in this store, exactly as it will in F3.
## It offers the two APIs the rest of the code base already relies on:
##   the STORE contract of P12's EconomyManager:  add(id, n) -> bool, remove(id, n) -> bool, can_add(id, n), count_total(id) (stock + placed), count_stock(id), owned_ids()
##   the PLACEMENT API that F3 lifts:  place_from_stock(id, cell, rot) -> {ok, reason}, hygge_score(), item_hygge(id), hygge_level_index(), reset()
##   hygge_score() is the BINDING accessor (PLAN_FEATURES.md section 3 task 4: "hygge_score() = sum of item.decor of PLACED pieces"; RF16 names FurnitureManager.hygge_score).  The prototype called it
##   hygge_total(); that name survives here only as an ALIAS of the stand-in - the shared helpers (Grant, AutoFurnish) call hygge_score() and nothing else (review F1 r2).
## The placement rules are the data-level rules of FeatureRoom (tests/lib/features/room_model.gd).  F3's tests prove the real grid; this class never claims to be it.

var room: FeatureRoom
var stock: Dictionary = {}          # item id -> copies in the store that are not placed
var tier: int = 1


func _init(p_tier: int = 1) -> void:
	tier = p_tier
	room = FeatureRoom.load_tier(p_tier)


func set_tier(p_tier: int) -> void:
	tier = p_tier
	var kept: Array[Dictionary] = []
	if room != null:
		kept.assign(room.pieces)
	room = FeatureRoom.load_tier(p_tier)
	for p in kept:                                   # a bigger room keeps every piece (never lost); a piece that no longer fits goes back to the stock
		if room == null or not bool(room.place(p["id"], p["cell"], int(p["rot"]))["ok"]):
			stock[str(p["id"])] = int(stock.get(str(p["id"]), 0)) + 1


func reset() -> void:
	stock.clear()
	tier = 1
	room = FeatureRoom.load_tier(1)


# ---------------------------------------------------------------------------------------------- the store contract (EconomyManager)

func max_stack_of(item_id: Variant) -> int:
	return 1 if ItemKinds.is_one_of_a_kind(item_id) else LuaData.int_of(ItemKinds.def(item_id).get("max_stack", 9), 9)


func can_add(item_id: Variant, amount: int) -> bool:
	return amount > 0 and count_total(item_id) + amount <= max_stack_of(item_id)


func add(item_id: Variant, amount: int) -> bool:
	if not can_add(item_id, amount):
		return false
	stock[str(item_id)] = int(stock.get(str(item_id), 0)) + amount
	return true


func remove(item_id: Variant, amount: int) -> bool:
	if amount <= 0 or count_stock(item_id) < amount:
		return false                                 # placed copies are never handed out
	stock[str(item_id)] = count_stock(item_id) - amount
	if int(stock[str(item_id)]) <= 0:
		stock.erase(str(item_id))
	return true


func count_stock(item_id: Variant) -> int:
	return int(stock.get(str(item_id), 0))


func count_placed(item_id: Variant) -> int:
	return room.count_of(item_id) if room != null else 0


func count_total(item_id: Variant) -> int:
	return count_stock(item_id) + count_placed(item_id)


func owned_ids() -> Array:
	var ids: Dictionary = {}
	for k in stock:
		ids[k] = true
	if room != null:
		for p in room.pieces:
			ids[str(p["id"])] = true
	return ids.keys()


# ---------------------------------------------------------------------------------------------- placement

func place_from_stock(item_id: Variant, cell: Vector2i, rot: int = 0) -> Dictionary:
	if room == null:
		return {"ok": false, "reason": "no_room"}
	if count_stock(item_id) < 1:
		return {"ok": false, "reason": "not_in_stock"}
	var r := room.place(item_id, cell, rot)
	if bool(r["ok"]):
		remove(item_id, 1)
	return r


## the sum of `decor` of the PLACED pieces (the content formula: no duplicate falloff, capacity and max_stack are the brakes)
func hygge_score() -> int:
	return room.decor_total() if room != null else 0


## alias of hygge_score() for the prototype's old name; nothing in tests/lib/features calls it
func hygge_total() -> int:
	return hygge_score()


func item_hygge(item_id: Variant) -> int:
	return LuaData.int_of(ItemKinds.def(item_id).get("decor", 0))


## index into home.hygge_levels (0..5) of the current score
func hygge_level_index() -> int:
	var levels := LuaData.arr(Svc.lua_config("home.hygge_levels", []))
	var score := hygge_score()
	var idx := 0
	for i in levels.size():
		if score >= LuaData.int_of(LuaData.dict(levels[i]).get("min_decor", 0)):
			idx = i
	return idx
