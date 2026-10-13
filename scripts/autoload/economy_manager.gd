extends Node
## Gold, inventory, and shop transactions.

const MAX_GOLD := 999_999
const INVENTORY_SLOTS := 40

var gold: int = 500  # starting gold — fairy king lottery winnings leftover
var inventory: Array[Dictionary] = []  # [{id, amount, meta}]
var equipment: Dictionary = {
	"tool_hoe": &"hoe_wooden",
	"tool_watering": &"watering_can_copper",
	"tool_pickaxe": &"pickaxe_wooden",
	"tool_axe": &"axe_wooden",
	"weapon": &"sword_rusty",
	"accessory": &"",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.quest_objective_updated.connect(_on_quest_objective)
	# Starter items
	add_item(&"hoe_wooden", 1)
	add_item(&"watering_can_copper", 1)
	add_item(&"pickaxe_wooden", 1)
	add_item(&"axe_wooden", 1)
	add_item(&"turnip_seeds", 5)
	add_item(&"hoe_wooden", 0)  # ensure structure exists


func add_gold(amount: int) -> void:
	var before := gold
	gold = clampi(gold + amount, 0, MAX_GOLD)
	EventBus.gold_changed.emit(gold, gold - before)


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold, -amount)
	return true


func can_afford(amount: int) -> bool:
	return gold >= amount


func add_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	for slot in inventory:
		if slot["id"] == item_id:
			slot["amount"] += amount
			EventBus.player_inventory_changed.emit(get_inventory_dict())
			_notify_item_gained(item_id, amount)
			return true

	if inventory.size() >= INVENTORY_SLOTS:
		EventBus.notification_posted.emit(
			tr("NOTIF_INVENTORY_FULL_TITLE"),
			tr("NOTIF_INVENTORY_FULL_MSG"),
			"inventory"
		)
		return false

	inventory.append({"id": item_id, "amount": amount, "meta": {}})
	EventBus.player_inventory_changed.emit(get_inventory_dict())
	_notify_item_gained(item_id, amount)
	return true


func remove_item(item_id: StringName, amount: int = 1) -> bool:
	for i in inventory.size():
		var slot := inventory[i]
		if slot["id"] != item_id:
			continue
		if slot["amount"] < amount:
			return false
		slot["amount"] -= amount
		if slot["amount"] <= 0:
			inventory.remove_at(i)
		EventBus.player_inventory_changed.emit(get_inventory_dict())
		return true
	return false


func has_item(item_id: StringName, amount: int = 1) -> bool:
	var total := 0
	for slot in inventory:
		if slot["id"] == item_id:
			total += slot["amount"]
	return total >= amount


func count_item(item_id: StringName) -> int:
	var total := 0
	for slot in inventory:
		if slot["id"] == item_id:
			total += slot["amount"]
	return total


func get_inventory_dict() -> Dictionary:
	var out := {}
	for slot in inventory:
		out[slot["id"]] = out.get(slot["id"], 0) + slot["amount"]
	return out


func buy_item(item_id: StringName, amount: int, unit_price: int) -> bool:
	var total := unit_price * amount
	if not spend_gold(total):
		EventBus.notification_posted.emit(
			tr("NOTIF_NO_GOLD_TITLE"),
			tr("NOTIF_NO_GOLD_MSG"),
			"gold"
		)
		return false
	if not add_item(item_id, amount):
		add_gold(total)  # refund
		return false
	EventBus.item_purchased.emit(item_id, amount, total)
	return true


func sell_item(item_id: StringName, amount: int, unit_price: int) -> bool:
	if not remove_item(item_id, amount):
		return false
	var total := unit_price * amount
	add_gold(total)
	EventBus.item_sold.emit(item_id, amount, total)
	return true


func equip(slot: StringName, item_id: StringName) -> void:
	equipment[slot] = item_id
	EventBus.player_inventory_changed.emit(get_inventory_dict())


func _notify_item_gained(item_id: StringName, amount: int) -> void:
	EventBus.notification_posted.emit(
		tr("NOTIF_ITEM_GAINED_TITLE"),
		"%s x%d" % [tr("ITEM_%s" % item_id.to_upper()), amount],
		"item"
	)


func _on_quest_objective(_q: StringName, _o: StringName, _p: int, _t: int) -> void:
	pass


func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	gold = data.get("gold", 500)
	inventory.clear()
	for slot in data.get("inventory", []):
		if typeof(slot) == TYPE_DICTIONARY:
			inventory.append(slot)
	equipment = data.get("equipment", equipment).duplicate()
	EventBus.player_inventory_changed.emit(get_inventory_dict())
	EventBus.gold_changed.emit(gold, 0)
