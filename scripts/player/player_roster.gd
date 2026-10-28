class_name PlayerRoster
extends Node
## Registered save section (order 15). The world and title-screen staging node share
## session rows, so destroying a world never discards profiles loaded by the host.

const SECTION := "players"
const SECTION_VERSION := 1
const SECTION_ORDER := 15

var rows: Dictionary:
	get: return PlayerRegistry._states
	set(value):
		PlayerRegistry._states = value
		PlayerRegistry._fallback_state = value.get(&"p0", PlayerState.new())


func _ready() -> void:
	# GameManager clears all rows before the new-game signal; ensure the host exists.
	EventBus.new_game_started.connect(_on_new_game)


func _on_new_game() -> void:
	state()


func state(player_id: StringName = &"p0") -> PlayerState:
	return PlayerRegistry.state(player_id)


func local_state() -> PlayerState:
	return state(PlayerRegistry.local_id())


func reset() -> void:
	PlayerRegistry.reset_states()


func initialize_profile(id: StringName, peer_id: int, metadata: Dictionary) -> PlayerState:
	if not NetAuthority.can_write() or rows.has(id) or not MultiplayerSession.profile_valid(metadata): return null
	var row := PlayerState.new(id, peer_id)
	row.reset_profile(metadata.name, int(metadata.character_type), StringName(metadata.character_skin))
	var eco := Svc.node("EconomyManager")
	row.gold = eco._gold_of(GameManager.config_value("economy.starting_gold", 500), 500)
	row.equipment = eco._empty_equipment()
	for entry in eco._starter_kit():
		var item := StringName(str(entry[0]))
		var amount := int(entry[1])
		if amount <= 0: continue
		var def := ItemKinds.def(item)
		if str(def.get("category", "")) == "weapon":
			row.arsenal[item] = mini(amount, Arsenal.CAP)
		else:
			var remaining := amount
			while remaining > 0 and row.inventory.size() < eco.INVENTORY_SLOTS:
				var count := mini(remaining, eco.max_stack_of(item))
				row.inventory.append({"id": item, "amount": count, "meta": {}})
				remaining -= count
		var slot := str(eco.equip_slot_of(item))
		if slot != "" and slot != "accessory":
			var old: Variant = row.equipment.get(StringName(slot), &"")
			if old == &"" or eco.equip_rank_of(item) > eco.equip_rank_of(old): row.equipment[StringName(slot)] = item
	var wardrobe := Svc.node("WardrobeManager")
	var kit := LuaData.dict(GameManager.config_value("starter_kit.wardrobe", {}))
	var owned := {}
	var equipped := {}
	for item in LuaData.strings(kit.get("owned", [])) + LuaData.strings(kit.get("worn", [])):
		if wardrobe.slot_of(item) != "": owned[item] = 1
	for item in LuaData.strings(kit.get("worn", [])): equipped = wardrobe.preview_equipping(item, equipped)
	row.wardrobe = {"v": 1, "owned": owned, "equipped": equipped, "presets": {}}
	var slots: Array = []
	for entry in eco._starter_kit():
		if slots.size() < Hotbar.SIZE: slots.append(str(entry[0]))
	while slots.size() < Hotbar.SIZE: slots.append("")
	row.hotbar = {"slots": slots, "selected": 0}
	return row


func capture_live_bodies(world: Node) -> void:
	if not NetAuthority.can_write(): return
	for body in world.all_players():
		var row := PlayerRegistry.peek_state(body.player_id)
		if row == null: continue
		row.player_pos = body.global_position
		if body.area != null: row.area = body.area.map.id
		for key in ["half_hearts", "stamina", "oil"]:
			if key in body: row.set(key, body.get(key))
		if "hotbar" in body: row.hotbar = body.hotbar.to_dict()


func to_dict() -> Dictionary:
	# Facades normalize runtime-only quest records and preserve content-drift buckets.
	var local := state(&"p0")
	var game := Svc.node("GameManager")
	if game != null:
		local.name = str(game.get("player_name"))
		local.character_type = int(game.get("character_type"))
		local.character_skin = StringName(str(game.get("character_skin")))
	var economy := Svc.node("EconomyManager")
	if economy != null and economy.has_method("to_dict"):
		PlayerRegistry.for_player(local.player_id, func() -> void: economy.call("to_dict"))
	var out := {}
	for id in rows:
		out[str(id)] = (rows[id] as PlayerState).to_dict()
	return {"v": SECTION_VERSION, "rows": out}


func validate_dict(d: Dictionary) -> bool:
	if typeof(d.get("v", 1)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(d.get("v", 1))) or float(d.get("v", 1)) != floorf(float(d.get("v", 1))): return false
	if not d.get("rows") is Dictionary or d.rows.size() < 1 or d.rows.size() > PlayerRegistry.MAX_PLAYERS or not d.rows.has("p0"):
		return false
	for key in d.rows:
		var row: Variant = d.rows[key]
		if not str(key) in ["p0", "p1", "p2", "p3"] or not row is Dictionary or row.get("id") != str(key):
			return false
		if not row.has("gold") or not row.has("inventory") or not row.has("quests"): return false
		for field in ["name", "character_skin", "area"]:
			if row.has(field) and not row[field] is String: return false
		for field in ["gold", "character_type", "peer_ordinal", "half_hearts", "stamina", "oil"]:
			if row.has(field) and (typeof(row[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(row[field]))): return false
		for field in ["equipment", "arsenal", "quests", "wardrobe", "flags"]:
			if row.has(field) and not row[field] is Dictionary: return false
		for field in ["inventory", "owed", "player_pos"]:
			if row.has(field) and not row[field] is Array: return false
		if row.has("hotbar") and not row.hotbar is Dictionary and not row.hotbar is Array: return false
		if row.has("player_pos") and (row.player_pos.size() != 2 or typeof(row.player_pos[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(row.player_pos[1]) not in [TYPE_INT, TYPE_FLOAT]): return false
		for slot in row.inventory:
			if not slot is Dictionary or not slot.get("id") is String or str(slot.id) == "" or typeof(slot.get("amount")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(slot.amount)): return false
		for value in row.get("flags", {}).values():
			if typeof(value) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]: return false
		for field in ["quests", "wardrobe"]:
			var version: Variant = row.get(field, {}).get("v", 1)
			if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(version)) or float(version) != floorf(float(version)): return false
		var qm := Svc.node("QuestManager")
		if qm != null and qm.has_method("validate_dict") and not qm.call("validate_dict", row.get("quests", {})): return false
	return true


## Private runtime identity checkpoint, never a save codec or load permit.
## Only the enclosing verified rollback may publish these original references.
func capture_rollback_identity() -> Callable:
	var checkpoint := preload("res://scripts/player/rollback_identity.gd").new()
	var original := rows
	checkpoint.keep_value(original)
	for profile: PlayerState in original.values():
		checkpoint.keep_script_fields(profile)
		for runtime in profile.quests.get("active", {}).values():
			if runtime is RefCounted:
				checkpoint.keep_script_fields(runtime)
	var quests := Svc.node("QuestManager")
	var restore_queue: Callable = quests.call("capture_rollback_identity") if quests != null and quests.has_method("capture_rollback_identity") else Callable()
	return func() -> void:
		checkpoint.restore()
		rows = original
		if restore_queue.is_valid(): restore_queue.call()

func from_dict(d: Dictionary) -> bool:
	if not validate_dict(d): return false
	var lifecycle_owner := SaveManager._save_owner_stamp()
	var restored := {}
	for key in d.rows:
		var profile := PlayerState.new()
		if not profile.from_dict(d.rows[key]): return false
		restored[profile.player_id] = profile
	rows = restored
	var installed := restored.duplicate()
	var host := state()
	var game := Svc.node("GameManager")
	if game != null:
		game.set("player_name", host.name)
		game.set("character_type", host.character_type)
		game.set("character_skin", host.character_skin)
	# Rebuild typed quest runtimes and route saved items through the existing loaders.
	for id in rows:
		PlayerRegistry.for_player(id, func() -> void:
			var row: Dictionary = d.rows[str(id)]
			for pair in [["EconomyManager", row], ["QuestManager", row.get("quests", {})]]:
				if lifecycle_owner != SaveManager._save_owner_stamp() or PlayerRegistry.peek_state(id) != installed[id]: return
				var manager := Svc.node(pair[0])
				if manager != null and manager.has_method("from_dict"): manager.call("from_dict", pair[1].duplicate(true))
		)
		if not SaveManager._profiles_current(installed):
			if lifecycle_owner == SaveManager._save_owner_stamp(): SaveManager.invalidate_lifecycle()
			return false
		if lifecycle_owner != SaveManager._save_owner_stamp(): return false
	return true
