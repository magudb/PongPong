extends Node
## Clothing ownership, exclusions and presets. EconomyManager routes garments
## here; the player and preview share one immutable equipped snapshot.
signal owned_changed
signal presets_changed
const PRESETS := ["work", "forest", "festival"]
var owned: Dictionary = {}
var equipped: Dictionary = {}
var presets: Dictionary = {}
var _checking_sets := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.register_section("wardrobe", self, SaveManager.FEATURE_ORDERS.wardrobe)
	EventBus.new_game_started.connect(reset)

func slots() -> Dictionary:
	return LuaData.dict(Svc.lua_config("wardrobe.equip_slots", {}))

func slot_of(id: Variant) -> String:
	var def := ItemKinds.def(id)
	if str(def.get("category", "")) != "clothing" or not bool(def.get("wearable", false)):
		return ""
	for slot in slots():
		var rule: Dictionary = slots()[slot]
		if str(rule.item_slot) == str(def.get("slot", "")) and str(rule.get("subslot", "")) == str(def.get("subslot", "")):
			return str(slot)
	return ""

func count_total(id: Variant) -> int:
	return int(owned.get(str(id), 0))

func count_stock(id: Variant) -> int:
	return count_total(id) if str(id) not in equipped.values() else 0

func owned_ids() -> Array:
	return owned.keys()

func can_add(id: Variant, amount := 1) -> bool:
	return amount == 1 and slot_of(id) != "" and count_total(id) == 0

func add(id: Variant, amount := 1) -> bool:
	if not can_add(id, amount):
		return false
	owned[str(id)] = 1
	owned_changed.emit()
	_check_sets.call_deferred()
	return true

func remove(id: Variant, amount := 1) -> bool:
	if amount != 1 or count_stock(id) < amount:
		return false
	owned.erase(str(id))
	owned_changed.emit()
	return true

func outfit() -> Dictionary:
	return equipped.duplicate()

## Resolve the entire change before publishing. Displaced pieces stay owned.
func preview_equipping(id: Variant, previous: Dictionary) -> Dictionary:
	var next := previous.duplicate()
	var slot := slot_of(id)
	if slot == "":
		return next
	for pair in LuaData.arr(Svc.lua_config("wardrobe.exclusive", [])):
		var members := LuaData.strings(pair)
		if slot in members:
			for other in members:
				if other != slot:
					next.erase(other)
	next[slot] = str(id)
	return next

func equip(id: Variant) -> bool:
	var slot := slot_of(id)
	if slot == "" or count_total(id) == 0:
		return false
	var next := preview_equipping(id, equipped)
	if next == equipped:
		return true
	equipped = next
	_publish()
	EventBus.garment_equipped.emit(StringName(str(id)), StringName(slot))
	EventBus.game_event.emit(&"garment_equipped", {"slot": slot, "item": str(id), "rarity": str(ItemKinds.rarity_of(id))})
	return true

func unequip(slot: Variant) -> bool:
	if not equipped.has(str(slot)):
		return false
	equipped.erase(str(slot))
	_publish()
	return true

func save_preset(key: String) -> bool:
	if key not in PRESETS:
		return false
	presets[key] = outfit()
	presets_changed.emit()
	return true

func load_preset(key: String) -> Dictionary:
	if key not in PRESETS or not presets.has(key):
		return {"ok": false, "missing": []}
	var next := {}
	var missing: Array[String] = []
	for slot in presets[key]:
		var id := str(presets[key][slot])
		if count_total(id) > 0 and slot_of(id) == str(slot):
			next = preview_equipping(id, next)
		else:
			missing.append(id)
	equipped = next
	_publish()
	return {"ok": true, "missing": missing}

func set_bonuses() -> Array:
	var result: Array = []
	var sets := LuaData.dict(Svc.lua_config("wardrobe_sets", {}))
	for key in sets:
		var count := 0
		for item in equipped.values():
			if str(item) in LuaData.strings(sets[key].get("members", [])):
				count += 1
		var best: Dictionary = {}
		for row in LuaData.arr(sets[key].get("bonuses", [])):
			if int(row.get("pieces", 0)) <= count and int(row.get("pieces", 0)) > int(best.get("pieces", 0)):
				best = row
		if not best.is_empty():
			result.append({"id": str(key), "count": count, "bonus": best.duplicate()})
	return result

func gear_points(kind: String) -> float:
	var total := 0.0
	for id in equipped.values():
		total += float(ItemKinds.def(id).get("perks", {}).get(kind, 0.0))
	var bonuses: Array = set_bonuses().map(func(row): return float(row.bonus.get(kind, 0.0)))
	bonuses.sort()
	bonuses.reverse()
	for index in mini(bonuses.size(), int(Svc.lua_config("wardrobe.max_sets_counted", 2))):
		total += bonuses[index]
	return total

func reset() -> void:
	owned.clear()
	equipped.clear()
	presets.clear()
	# A pre-wardrobe save may have genuine clothing in its backpack. Adopt it
	# before filling missing starter pieces, so no owned piece disappears.
	adopt_from_backpack()
	var kit := LuaData.dict(Svc.lua_config("starter_kit.wardrobe", {}))
	for id in LuaData.strings(kit.get("owned", [])) + LuaData.strings(kit.get("worn", [])):
		if slot_of(id) != "":
			owned[id] = 1
	for id in LuaData.strings(kit.get("worn", [])):
		equipped = preview_equipping(id, equipped)
	_publish()
	owned_changed.emit()
	presets_changed.emit()

func adopt_from_backpack() -> void:
	EconomyManager.adopt_misrouted(ItemKinds.CLOTHING)

func to_dict() -> Dictionary:
	return {"v": 1, "owned": owned.duplicate(), "equipped": outfit(), "presets": presets.duplicate(true)}

func from_dict(data: Dictionary) -> bool:
	if LuaData.int_of(data.get("v", 1), -1) != 1 or not data.get("owned", {}) is Dictionary or not data.get("equipped", {}) is Dictionary or not data.get("presets", {}) is Dictionary:
		return false
	var next_owned := {}
	for id in data.get("owned", {}):
		if slot_of(id) != "" and LuaData.int_of(data.owned[id]) > 0:
			next_owned[str(id)] = 1
	owned = next_owned
	equipped = _valid_outfit(data.get("equipped", {}), true)
	presets.clear()
	for key in PRESETS:
		if data.get("presets", {}).get(key) is Dictionary:
			presets[key] = _valid_outfit(data.presets[key], false)
	adopt_from_backpack()
	_publish()
	owned_changed.emit()
	presets_changed.emit()
	_check_sets.call_deferred()
	return true

func _valid_outfit(raw: Dictionary, require_owned: bool) -> Dictionary:
	var next := {}
	for slot in slots():
		var id := str(raw.get(slot, ""))
		if id != "" and slot_of(id) == str(slot) and (not require_owned or count_total(id) > 0):
			next = preview_equipping(id, next)
	return next

func _publish() -> void:
	EventBus.outfit_changed.emit(outfit())

func _check_sets() -> void:
	if _checking_sets:
		return
	_checking_sets = true
	var sets := LuaData.dict(Svc.lua_config("wardrobe_sets", {}))
	for key in sets:
		var capstone := str(sets[key].get("capstone", ""))
		if capstone == "" or count_total(capstone) > 0:
			continue
		var complete := true
		for id in LuaData.strings(sets[key].get("members", [])):
			if id != capstone and count_total(id) == 0:
				complete = false
		if complete:
			LootService.grant_set_capstone(str(key))
	_checking_sets = false
