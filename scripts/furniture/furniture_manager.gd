extends Node
## Owns furniture stock and the pure placement grid. A placement transaction
## commits ownership before publishing events, so observers always see one copy.
const NUDGE_RADIUS := 4
var stock: Dictionary = {}
var grid: FurnitureGrid
var _grid_tier := 0
var last_rebuild: Dictionary = {}
var _last_hygge := -1
var _last_level := -1
var decorate_mode := false:
	set(value):
		if decorate_mode != value:
			decorate_mode = value
			EventBus.decorate_mode_changed.emit(value)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.register_section("furniture", self, SaveManager.FEATURE_ORDERS.furniture)
	EventBus.new_game_started.connect(reset)
	EventBus.home_upgraded.connect(func(_old, _new): rebuild_for_tier())

func max_stack_of(id: Variant) -> int:
	return 1 if ItemKinds.is_one_of_a_kind(id) else maxi(LuaData.int_of(ItemKinds.def(id).get("max_stack", 9), 9), 1)

func can_add(id: Variant, amount := 1) -> bool:
	return FurnitureCatalog.contains(id) and amount > 0 and amount <= max_stack_of(id) - count_total(id)

func add(id: Variant, amount := 1) -> bool:
	if not can_add(id, amount):
		return false
	stock[str(id)] = count_stock(id) + amount
	_changed(&"stock")
	return true

func remove(id: Variant, amount := 1) -> bool:
	if amount <= 0 or count_stock(id) < amount:
		return false
	_take_stock(str(id), amount)
	_changed(&"stock")
	return true

func _take_stock(id: String, amount: int) -> void:
	stock[id] = count_stock(id) - amount
	if stock[id] <= 0:
		stock.erase(id)

func count_stock(id: Variant) -> int:
	return int(stock.get(str(id), 0))

func count_placed(id: Variant) -> int:
	var n := 0
	if grid != null:
		for p in grid.placements.values():
			if str(p.item_id) == str(id):
				n += 1
	return n

func count_total(id: Variant) -> int:
	return count_stock(id) + count_placed(id)

func owned_ids() -> Array:
	var ids := stock.duplicate()
	if grid != null:
		for p in grid.placements.values():
			ids[str(p.item_id)] = true
	return ids.keys()

func ensure_grid() -> FurnitureGrid:
	if grid == null:
		_build_grid()
	elif _grid_tier != HomeManager.tier:
		rebuild_for_tier()
	return grid

func _build_grid() -> void:
	grid = FurnitureGrid.new()
	var room := HomeData.room(HomeManager.tier).duplicate(true)
	room["max_furniture"] = HomeManager.furniture_capacity()
	grid.setup(room, HomeData.furniture())
	_grid_tier = HomeManager.tier

func place_from_stock(id: Variant, cell: Vector2i, rot := 0) -> Dictionary:
	ensure_grid()
	if count_stock(id) < 1:
		return {"ok": false, "reason": "not_in_stock", "text_key": "FURNI_REJECT_UNKNOWN_ITEM"}
	var result := grid.can_place(str(id), cell, rot)
	if not result.ok:
		return result
	var uid := grid.place(str(id), cell, rot)
	_take_stock(str(id), 1)
	_changed(&"placed")
	EventBus.furniture_placed.emit(StringName(str(id)), uid)
	EventBus.game_event.emit(&"furniture_placed", {"item": str(id), "rarity": str(ItemKinds.rarity_of(id))})
	return {"ok": true, "uid": uid, "reason": "ok", "text_key": ""}

func pickup(uid: int) -> Array:
	ensure_grid()
	if not grid.placements.has(uid):
		return []
	var returned: Array = [str(grid.placements[uid].item_id)]
	for p in grid.placements.values():
		if p.get("host", -1) == uid:
			returned.append(str(p.item_id))
	grid.remove(uid)
	for id in returned:
		stock[id] = count_stock(id) + 1
	_changed(&"removed")
	for id in returned:
		EventBus.furniture_picked_up.emit(StringName(id), uid)
	return returned

func rebuild_for_tier() -> Array:
	var previous: Array = grid.to_save() if grid != null else []
	_build_grid()
	var rejected := grid.load_save(previous)
	var moved: Array = []
	var nudged := 0
	for entry in rejected:
		var spot := _nearest_valid(str(entry.item), Vector2i(entry.cell[0], entry.cell[1]), int(entry.rot))
		if spot.is_empty():
			stock[entry.item] = count_stock(entry.item) + 1
			moved.append(entry.item)
		else:
			grid.place(entry.item, spot.cell, spot.rot)
			nudged += 1
	last_rebuild = {"kept": previous.size() - rejected.size(), "nudged": nudged, "stored": moved.size()}
	_changed(&"tier")
	if not moved.is_empty():
		EventBus.whisper_requested.emit(&"INDRET_MOVED_TO_STORAGE")
	return moved

func _nearest_valid(id: String, cell: Vector2i, rot: int) -> Dictionary:
	# Distance first, then original rotation before alternatives. Deterministic
	# for identical saves; tabletop pieces may return to any valid host nearby.
	var rotations: Array = [rot]
	for r in 4:
		if r != rot:
			rotations.append(r)
	for distance in range(NUDGE_RADIUS + 1):
		for r in rotations:
			for dz in range(-distance, distance + 1):
				for dx in range(-distance, distance + 1):
					if absi(dx) + absi(dz) != distance:
						continue
					var c := cell + Vector2i(dx, dz)
					if grid.can_place(id, c, r).ok:
						return {"cell": c, "rot": r}
	return {}

func item_hygge(id: Variant) -> int:
	return LuaData.int_of(ItemKinds.def(id).get("decor", 0))

func hygge_score() -> int:
	var score := 0
	if grid != null:
		for p in grid.placements.values():
			score += item_hygge(p.item_id)
	return score

func hygge_total() -> int:
	return hygge_score()

func hygge_level_index() -> int:
	var result := 0
	var score := hygge_score()
	var levels := HomeData.hygge_levels()
	for i in levels.size():
		if score >= LuaData.int_of(levels[i].get("min_decor", 0)):
			result = i
	return result

func count_placed_by_rarity(rarities: Variant) -> int:
	var requested: Array = rarities if rarities is Array else Array(str(rarities).split(",",false))
	var wanted: Array = requested.map(func(r): return Rarity.normalize(str(r).strip_edges()))
	var count := 0
	if grid != null:
		for p in grid.placements.values():
			if ItemKinds.rarity_of(p.item_id) in wanted:
				count += 1
	return count

func active_sets() -> Dictionary:
	var result := {}
	var sets := LuaData.dict(Svc.lua_config("furniture_sets", {}))
	for id in sets:
		var row := LuaData.dict(sets[id])
		var n := 0
		for item in LuaData.strings(row.get("members", [])):
			if count_placed(item) > 0:
				n += 1
		var best := {}
		for raw in LuaData.arr(row.get("bonuses", [])):
			var bonus := LuaData.dict(raw)
			if n >= LuaData.int_of(bonus.get("pieces", 999)) and int(bonus.get("pieces", 0)) > int(best.get("pieces", 0)):
				best = bonus
		result[id] = {"pieces": n, "bonus": best}
	return result

func perk_points(kind: String) -> float:
	var total := float(HomeData.hygge_level(hygge_level_index()).get(kind, 0.0))
	for row in active_sets().values():
		total += float(row.bonus.get(kind, 0.0))
	return total

func adopt_from_backpack() -> void:
	EconomyManager.adopt_misrouted()

func reset() -> void:
	stock.clear()
	_build_grid()
	decorate_mode = false
	_last_hygge = -1
	_last_level = -1
	adopt_from_backpack()
	var kit := LuaData.dict(Svc.lua_config("starter_kit.furniture", {}))
	for id in LuaData.strings(kit.get("placed", [])):
		if count_total(id) == 0:
			stock[id] = 1
		if count_stock(id) > 0:
			var spot := _nearest_any(id)
			if not spot.is_empty():
				grid.place(id, spot.cell, spot.rot)
				_take_stock(id, 1)
	for id in LuaData.dict(kit.get("stock", {})):
		stock[str(id)] = maxi(count_stock(id), LuaData.int_of(kit.stock[id]))
	_changed(&"load")

func _nearest_any(id: String) -> Dictionary:
	for cell in grid.floor_cells:
		for r in 4:
			if grid.can_place(id, cell, r).ok:
				return {"cell": cell, "rot": r}
	return {}

func to_dict() -> Dictionary:
	ensure_grid()
	return {"v": 1, "stock": stock.duplicate(), "placed": grid.to_save()}

func from_dict(data: Dictionary) -> bool:
	if LuaData.int_of(data.get("v", 1), -1) != 1 or not data.get("stock", {}) is Dictionary or not data.get("placed", []) is Array:
		return false
	var next_stock := {}
	for id in data.get("stock", {}):
		if FurnitureCatalog.contains(id):
			var amount := LuaData.int_of(data.stock[id])
			if amount > 0:
				next_stock[str(id)] = mini(amount, max_stack_of(id))
	stock = next_stock
	_build_grid()
	var entries: Array = []
	var totals := stock.duplicate()
	for raw in data.get("placed", []):
		if not raw is Dictionary or not FurnitureCatalog.contains(raw.get("item", "")):
			continue
		var id := str(raw.item)
		if int(totals.get(id, 0)) >= max_stack_of(id):
			continue
		totals[id] = int(totals.get(id, 0)) + 1
		entries.append(raw)
	for entry in grid.load_save(entries):
		stock[str(entry.item)] = count_stock(entry.item) + 1
	decorate_mode = false
	adopt_from_backpack()
	_changed(&"load")
	return true

func _changed(reason: StringName) -> void:
	EventBus.furniture_changed.emit(reason)
	var score := hygge_score()
	var level := hygge_level_index()
	if score != _last_hygge or level != _last_level:
		var gained := level > _last_level
		_last_hygge = score
		_last_level = level
		EventBus.hygge_changed.emit(score, StringName(str(HomeData.hygge_level(level).get("id", "koldt"))))
		if gained:
			EventBus.game_event.emit(&"hygge_level", {"level": level})
