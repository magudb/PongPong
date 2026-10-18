extends Node
## EconomyManager: gold, the 24-slot backpack, the equipped tools, and the one place every item enters or leaves the player.
##
## WHAT LIVES WHERE (addendum 3.2, ItemKinds.storage_of): ordinary items are in the BACKPACK (INVENTORY_SLOTS = 24, the guide's
## "18 / 24"; every def has a max_stack: 99 by default, tools and weapons 1). Furniture goes to the FurnitureManager store and
## clothing to the WardrobeManager store (own stores, never the backpack). add_item / remove_item / has_item / count_item route by
## category; the stores are looked up LATE (Svc.node), so nothing here needs them to exist: when a store is missing the item falls
## back to the backpack and is ADOPTED by the store the first time the store exists (adopt_misrouted(), also run before every
## routed call and every save) - it is never lost. The stores answer add(id, n) -> bool, remove(id, n) -> bool, count_total(id)
## (placed and worn copies still count as owned), and optionally owned_ids() / count_stock(id) for list_sellable().
##
## AMOUNTS are validated everywhere: an amount <= 0 is refused (false, no signal) - also through the Lua api (api.add_item(id, 0)).
## add_item(id, n, silent) is all-or-nothing: false when the backpack has no room (nothing was added, an "inventory full" toast
## is shown unless silent), so callers (harvest, loot, collect, quest rewards) must respect the answer and leave the source
## untouched. A second copy of a unique / legendary item is refused with false and NO warning (keepsakes are one per save).
##
## SIGNALS: item_gained(id, amount) exactly once per successful add (every kind of item); rare_item_found(id, rarity) as well for
## rank >= rare; both and the "item received" toast are skipped for silent adds (the starter kit, loading). player_inventory_changed
## (the backpack as {id: amount}) and gold_changed(gold, delta) keep the UI in sync. A NEW GAME (EventBus.new_game_started) calls
## reset(): starting gold from lua/config economy.starting_gold, an empty backpack and the starter kit given silently.
##
## TOOLS: the strongest tool of every type (hoe watering pickaxe axe scythe) and the strongest weapon are equipped automatically
## when they enter the backpack (by Lua `power` / `damage`); equip() lets the player choose another one (even a weaker one, or none)
## and that choice is saved and restored as it was; get_tool_power(type) answers the power of the equipped tool (0 = none).
## use_item(id) is the backpack's "Brug / Udstyr": blueprints set their unlock flag and are consumed (CraftingSystem reads the
## flag), tools and weapons are equipped, consumables heal / refill oil / restore energy THROUGH THE PLAYER (group `player`: it
## offers heal_half(n) and the properties half_hearts max_half_hearts oil max_oil stamina max_stamina), baby animals are adopted by
## AnimalHusbandry, a placeable asks the hotbar to take it (EventBus.hotbar_assign_requested(-1, id): -1 = first free slot).
##
## SAVE (SaveManager section "economy"): to_dict() {v, gold, inventory [{id, amount, meta}], equipment {slot: id}} holds ONLY the
## backpack; from_dict() rebuilds StringName ids and int amounts after the JSON round trip, splits stacks over max_stack, drops
## invalid slots and keeps at most INVENTORY_SLOTS of them. The saved equipment wins (a slot the save names is restored as it was,
## "" = deliberately empty); only slots the save does not decide get the best owned tool. GOLD never wraps around: add_gold
## saturates, total_of() prices a purchase without int64 overflow and a saved amount is clamped to 0..MAX_GOLD before it is an int.

const _Kinds := preload("res://scripts/data/item_kinds.gd")
const _Svc := preload("res://scripts/data/svc.gd")
const _Data := preload("res://scripts/data/lua_data.gd")
const _RarityScript := preload("res://scripts/data/rarity.gd")

const MAX_GOLD := 999_999
const INVENTORY_SLOTS := 24
const DEFAULT_MAX_STACK := 99
const DEFAULT_STARTING_GOLD := 500
const SAVE_VERSION := 1
## the first rarity rank that fires rare_item_found (3 = rare)
const RARE_RANK := 3
## item categories that no shop buys and no one can sell
const UNSELLABLE_CATEGORIES: Array[String] = ["quest", "special"]

## What a new game starts with, given silently (plan 7.3 P12 task 1): [item id, amount].
## Live source: lua/data/starter_kit.lua `starter_kit.tools` (id = amount). This literal is a
## load-failure fallback only (tests/sections/review_regressions.gd asserts the two are identical).
const STARTER_KIT: Array = [
	["hoe_wooden", 1], ["watering_can_copper", 1], ["axe_wooden", 1], ["pickaxe_wooden", 1], ["sword_rusty", 1], ["scythe", 1],
	["turnip_seeds", 5], ["lantern_oil", 2], ["health_tonic", 1],
]

## Lua tool_type -> equipment slot. Weapons (category weapon) use the slot "weapon", "accessory" is reserved.
const TOOL_SLOTS := {
	"hoe": "tool_hoe", "watering": "tool_watering", "pickaxe": "tool_pickaxe", "axe": "tool_axe", "scythe": "tool_scythe",
}
const WEAPON_SLOT := "weapon"
const ACCESSORY_SLOT := "accessory"

var gold: int = DEFAULT_STARTING_GOLD
## The backpack: [{id: StringName, amount: int, meta: Dictionary}], at most INVENTORY_SLOTS entries, never an amount <= 0.
var inventory: Array[Dictionary] = []
## slot -> item id (&"" = nothing): tool_hoe tool_watering tool_pickaxe tool_axe tool_scythe weapon accessory
var equipment: Dictionary = {}

var _misrouted: bool = false          # a furniture / clothing item may sit in the backpack (its store did not exist yet)
var _consuming: bool = false
var _logged: Dictionary = {}
var arsenal: Arsenal


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	equipment = _empty_equipment()
	arsenal = Arsenal.new()
	arsenal.name = "Arsenal"
	add_child(arsenal)
	EventBus.new_game_started.connect(reset)


# ================================================================================================ new game

## A new run: starting gold, empty backpack, starter kit (silent), nothing equipped but the kit's best tools.
func reset() -> void:
	gold = _gold_of(_Svc.lua_config("economy.starting_gold", DEFAULT_STARTING_GOLD), DEFAULT_STARTING_GOLD)
	inventory.clear()
	if arsenal != null: arsenal.reset()
	equipment = _empty_equipment()
	_misrouted = false
	for entry in _starter_kit():
		add_item(StringName(entry[0]), int(entry[1]), true)
	_publish(&"player_inventory_changed", [get_inventory_dict()])
	_publish(&"gold_changed", [gold, 0])


## The starter tools of lua/data/starter_kit.lua `starter_kit.tools` as [[id, amount], ...];
## the STARTER_KIT literal when the config is missing or empty.
func _starter_kit() -> Array:
	var tools: Variant = _Svc.lua_config("starter_kit.tools", null)
	if tools is Dictionary and not (tools as Dictionary).is_empty():
		var out: Array = []
		for id in tools:
			out.append([str(id), int((tools as Dictionary)[id])])
		return out
	return STARTER_KIT


static func _empty_equipment() -> Dictionary:
	var out := {}
	for slot in TOOL_SLOTS.values():
		out[slot] = &""
	out[WEAPON_SLOT] = &""
	out[ACCESSORY_SLOT] = &""
	return out


var _notification_depth := 0
var _deferred_notifications: Array[Callable] = []


## Execute an already-validated multi-item transaction before observers can save or
## re-enter it. This batches notifications, not validation or rollback. Nested calls
## share the outer transaction; normal calls keep their existing synchronous events.
func defer_notifications(action: Callable) -> void:
	_notification_depth += 1
	action.call()
	_notification_depth -= 1
	if _notification_depth == 0:
		var queued := _deferred_notifications
		_deferred_notifications = []
		for notification in queued:
			notification.call()


func after_transaction(action: Callable) -> void:
	if _notification_depth > 0:
		_deferred_notifications.append(action)
	else:
		action.call()


func _publish(event_name: StringName, args: Array) -> void:
	after_transaction(func() -> void: EventBus.emit_signal.callv([event_name] + args))


# ================================================================================================ gold

## Adds (or, negative, takes) gold, clamped to 0..MAX_GOLD. gold_changed(gold, delta) fires when the amount really changed.
## SATURATING: gold is 0..MAX_GOLD, so any addend beyond +-MAX_GOLD already ends at a bound; it is clamped BEFORE the addition, a
## plain `gold + amount` would wrap around int64 for a huge reward (INT64_MAX) and the clamp would then pin the wallet to 0.
func add_gold(amount: int) -> void:
	var before := gold
	gold = clampi(gold + clampi(amount, -MAX_GOLD, MAX_GOLD), 0, MAX_GOLD)
	if gold != before:
		_publish(&"gold_changed", [gold, gold - before])


## unit_price x amount WITHOUT int64 wrap-around (0 for a price or amount <= 0): a total that no wallet can hold (above MAX_GOLD)
## comes out as MAX_GOLD + 1, so can_afford() refuses it. Every shop total goes through here (buy_item, sell_item, ShopSystem).
static func total_of(unit_price: int, amount: int) -> int:
	if unit_price <= 0 or amount <= 0:
		return 0
	return MAX_GOLD + 1 if float(unit_price) * float(amount) > float(MAX_GOLD) else unit_price * amount


## A gold amount from a save or from Lua config, whatever its type: clamped to 0..MAX_GOLD BEFORE it becomes an int (a float above
## the int64 range converts to a platform-dependent value), NaN and non-numbers give `default_value`.
static func _gold_of(value: Variant, default_value: int) -> int:
	var f := _Data.num(value, float(default_value))
	return default_value if is_nan(f) else int(clampf(f, 0.0, float(MAX_GOLD)))


## Pays `amount` (>= 0). False without any change when the player has less.
func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	if amount == 0:
		return true
	gold -= amount
	_publish(&"gold_changed", [gold, -amount])
	return true


func can_afford(amount: int) -> bool:
	return amount >= 0 and gold >= amount


# ================================================================================================ item facts

func item_def(item_id: Variant) -> Dictionary:
	return _Kinds.def(item_id)


## Most units of one item in one backpack slot: the def's max_stack, else 1 for tools and weapons, else 99.
func max_stack_of(item_id: Variant) -> int:
	var d := item_def(item_id)
	if d.has("max_stack"):
		return maxi(_Data.int_of(d["max_stack"], DEFAULT_MAX_STACK), 1)
	return 1 if str(d.get("category", "")) in ["tool", "weapon"] else DEFAULT_MAX_STACK


## What a shop pays for ONE unit before its sell multiplier (0 = cannot be sold): the def's sell_price (or buy_price x
## economy.sell_price_ratio when the def has none). Quest and special items, protected items and keepsakes (unique /
## legendary) are never sellable.
func sell_value(item_id: Variant) -> int:
	var d := item_def(item_id)
	if d.is_empty() or str(d.get("category", "")) in UNSELLABLE_CATEGORIES or bool(d.get("protected", false)):
		return 0
	if _Kinds.is_one_of_a_kind(item_id):
		return 0
	if d.has("sell_price"):
		return maxi(_Data.int_of(d["sell_price"]), 0)
	var ratio := _Data.num(_Svc.lua_config("economy.sell_price_ratio", 0.5), 0.5)
	return maxi(roundi(float(_Data.int_of(d.get("buy_price", 0))) * ratio), 0)


func is_sellable(item_id: Variant) -> bool:
	return sell_value(item_id) > 0


## What a shop charges for ONE unit before its buy multiplier and discounts (0 = never sold; keepsakes are never sold).
func buy_value(item_id: Variant) -> int:
	var d := item_def(item_id)
	if d.is_empty() or bool(d.get("protected", false)) or _Kinds.is_one_of_a_kind(item_id):
		return 0
	return maxi(_Data.int_of(d.get("buy_price", 0)), 0)


# ================================================================================================ the backpack

## The backpack as {item id: amount}, stacks added up (what the HUD and the backpack screen show).
func get_inventory_dict() -> Dictionary:
	var out := {}
	for slot in inventory:
		out[slot["id"]] = int(out.get(slot["id"], 0)) + int(slot["amount"])
	return out


func used_slots() -> int:
	return inventory.size()


func free_slots() -> int:
	return INVENTORY_SLOTS - inventory.size()


## How many more units of this item the BACKPACK could take: the room left in its stacks plus the empty slots.
func backpack_room_for(item_id: Variant) -> int:
	var id := StringName(str(item_id))
	var ms := max_stack_of(id)
	var room := free_slots() * ms
	for slot in inventory:
		if slot["id"] == id:
			room += maxi(ms - int(slot["amount"]), 0)
	return room


## True when add_item(item_id, amount) would succeed right now (room in the backpack or a store that takes it).
func can_add_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or item_id == &"":
		return false
	if _Kinds.is_one_of_a_kind(item_id) and (amount > 1 or count_item(item_id) >= 1):
		return false
	var kind := _Kinds.storage_of(item_id)
	if kind != _Kinds.BACKPACK:
		var store := _store_for(kind)
		if store != null:
			return not store.has_method("can_add") or bool(store.call("can_add", item_id, amount))
	return backpack_room_for(item_id) >= amount


## Gives the player `amount` of an item. False when nothing was added: amount <= 0, no room, or a second copy of a keepsake.
## `silent` (the starter kit, loading) skips item_gained, rare_item_found and the toast.
func add_item(item_id: StringName, amount: int = 1, silent: bool = false) -> bool:
	if amount <= 0 or item_id == &"":
		return false
	adopt_misrouted()
	if _Kinds.is_one_of_a_kind(item_id) and (amount > 1 or count_item(item_id) >= 1):
		return false
	var kind := _Kinds.storage_of(item_id)
	if kind != _Kinds.BACKPACK:
		var store := _store_for(kind)
		if store != null and store.has_method("add"):
			if not bool(store.call("add", item_id, amount)):
				return false
			_auto_equip(item_id,not silent)
			_gained(item_id, amount, silent)
			return true
	if item_def(item_id).is_empty():
		_log_once("unknown item `%s` entered the backpack: no Lua def, no name and no price" % item_id)
	if backpack_room_for(item_id) < amount:
		if not silent:
			_publish(&"notification_posted", [tr("NOTIF_INVENTORY_FULL_TITLE"), tr("NOTIF_INVENTORY_FULL_MSG"), "inventory"])
		return false
	if kind != _Kinds.BACKPACK:
		_misrouted = true                 # its store does not exist yet: the item waits in the backpack to be adopted
	_stack_into_backpack(item_id, amount)
	_auto_equip(item_id,not silent)
	_gained(item_id, amount, silent)
	return true


## Takes `amount` of an item away. False (nothing changed) when the player has fewer free copies; placed furniture and worn
## clothing are never touched (the stores only hand out copies that are not in use). All or nothing, and it mirrors count_item:
## a furniture or clothing item is taken from its STORE first and the rest from the copies that sit in the backpack because the
## store refused them (its cap, a partial adopt_misrouted()), so everything that has_item() / count_item() counts can be removed.
func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or item_id == &"":
		return false
	adopt_misrouted()
	var from_store := 0
	var kind := _Kinds.storage_of(item_id)
	if kind != _Kinds.BACKPACK:
		var store := _store_for(kind)
		if store != null and store.has_method("remove"):
			from_store = _remove_from_store(store, item_id, amount)
			if from_store < 0:
				return false
	if amount > from_store:
		if not _take_from_backpack(item_id, amount - from_store):
			return false
	_publish(&"player_inventory_changed", [get_inventory_dict()])
	return true


## Asks a store for as many of `amount` as it can give, the most first, but never less than what the backpack leftovers cannot
## cover: returns the number the store handed out (0 = all of it comes from the backpack), or -1 with nothing changed. The stores'
## remove(id, n) is all or nothing, so a store that holds fewer than `amount` is asked for one unit less each round.
func _remove_from_store(store: Node, item_id: StringName, amount: int) -> int:
	var spare := mini(_backpack_count(item_id), amount)
	for take in range(amount, amount - spare - 1, -1):
		if take == 0:
			return 0
		if bool(store.call("remove", item_id, take)):
			return take
	return -1


## Removes `amount` copies from the backpack slots, last slot first. False (nothing changed) when it holds fewer.
func _take_from_backpack(item_id: StringName, amount: int) -> bool:
	if _backpack_count(item_id) < amount:
		return false
	var left := amount
	var i := inventory.size() - 1
	while i >= 0 and left > 0:
		if inventory[i]["id"] == item_id:
			var take := mini(int(inventory[i]["amount"]), left)
			inventory[i]["amount"] = int(inventory[i]["amount"]) - take
			left -= take
			if int(inventory[i]["amount"]) <= 0:
				inventory.remove_at(i)
		i -= 1
	_revalidate_equipment()
	return true


## The player owns at least `amount` (> 0) copies, wherever they are (placed furniture and worn clothing count).
func has_item(item_id: StringName, amount: int = 1) -> bool:
	return amount > 0 and count_item(item_id) >= amount


## Every entry of {item id: amount} is owned (an amount <= 0 makes it false; an empty dictionary is true).
func has_items(needs: Dictionary) -> bool:
	for id in needs:
		if not has_item(StringName(str(id)), _Data.int_of(needs[id])):
			return false
	return true


## Takes every entry of {item id: amount} or nothing at all.
func remove_items(needs: Dictionary) -> bool:
	if not has_items(needs):
		return false
	var taken: Array = []
	for id in needs:
		var n := _Data.int_of(needs[id])
		if remove_item(StringName(str(id)), n):
			taken.append([StringName(str(id)), n])
		else:
			for t in taken:                  # roll back (the copies were free a moment ago)
				add_item(t[0], t[1], true)
			return false
	return true


## Backpack transaction for quest costs, adoption and home construction. All deductions
## (including optional gold) precede the caller's state commit and observer signals.
func consume_backpack_items(needs: Dictionary, commit: Callable, gold_cost: int = 0) -> bool:
	if not commit.is_valid() or not can_afford(gold_cost):
		return false
	for id in needs:
		var amount := _Data.int_of(needs[id])
		var item_id := StringName(str(id))
		if amount <= 0 or _Kinds.storage_of(item_id) != _Kinds.BACKPACK or _backpack_count(item_id) < amount:
			return false
	for id in needs:
		_take_from_backpack(StringName(str(id)), _Data.int_of(needs[id]))
	gold -= gold_cost
	commit.call()
	if gold_cost > 0:
		_publish(&"gold_changed", [gold, -gold_cost])
	if not needs.is_empty():
		_publish(&"player_inventory_changed", [get_inventory_dict()])
	return true


## Silent chest withdrawal: credit the backpack and commit the source deduction
## before equipment/inventory listeners can save or request another transfer.
func receive_backpack_item(item_id: StringName, amount: int, commit: Callable, silent: bool = true) -> bool:
	if not commit.is_valid() or _Kinds.storage_of(item_id) != _Kinds.BACKPACK or not can_add_item(item_id, amount):
		return false
	_stack_into_backpack(item_id, amount)
	commit.call()
	_auto_equip(item_id,not silent)
	_gained(item_id, amount, silent)
	return true


## Copies the player owns (placed and worn pieces count: they are still the player's).
func count_item(item_id: StringName) -> int:
	var n := _backpack_count(item_id)
	var kind := _Kinds.storage_of(item_id)
	if kind != _Kinds.BACKPACK:
		var store := _store_for(kind)
		if store != null and store.has_method("count_total"):
			n += int(store.call("count_total", item_id))
	return n


## What the player can SELL right now: the backpack plus the unplaced furniture of the store (garment spares cannot exist: every
## garment is max_stack 1, loot sells duplicates and the tailor refuses a second copy). [{id, amount, kind, rarity, value}],
## rarity descending, then id. Items that no shop buys at all (quest, special, keepsakes, price 0) are left out.
func list_sellable() -> Array[Dictionary]:
	adopt_misrouted()
	var rows: Array[Dictionary] = []
	var inv := get_inventory_dict()
	for id in inv:
		var item_id := StringName(str(id))
		if is_sellable(item_id):
			rows.append({"id": item_id, "amount": int(inv[id]), "kind": _Kinds.storage_of(item_id), "rarity": _Kinds.rarity_of(item_id), "value": sell_value(item_id)})
	for kind in [_Kinds.FURNITURE,_Kinds.WEAPON]:
		var store := _store_for(kind)
		if store == null or not store.has_method("owned_ids") or not store.has_method("count_stock"): continue
		for id in store.call("owned_ids"):
			var item_id := StringName(str(id))
			var free := int(store.call("count_stock", item_id))
			if free > 0 and is_sellable(item_id):
				rows.append({"id": item_id, "amount": free, "kind": kind, "rarity": _Kinds.rarity_of(item_id), "value": sell_value(item_id)})
	var order: Array = []
	for i in rows.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra := _RarityScript.rank(rows[a]["rarity"])
		var rb := _RarityScript.rank(rows[b]["rarity"])
		if ra != rb:
			return ra > rb
		return str(rows[a]["id"]) < str(rows[b]["id"]))
	var sorted: Array[Dictionary] = []
	for i in order:
		sorted.append(rows[i])
	return sorted


## Moves furniture and clothing that fell back into the backpack (their store did not exist yet) into the stores. Items are moved
## with the stores' own add(); no item_gained is fired again (they were counted when they arrived). Runs by itself before every
## routed call and before every save, a store may also call it from its own load.
func adopt_misrouted(only_kind: StringName = &"") -> void:
	if not _misrouted:
		return
	var still := false
	var moved := false
	var i := inventory.size() - 1
	while i >= 0:
		var slot := inventory[i]
		var kind := _Kinds.storage_of(slot["id"])
		if kind != _Kinds.BACKPACK:
			# A store adopts only its own rows while loading. Another store may
			# still be waiting for reset/from_dict and would erase an early gift.
			if only_kind != &"" and kind != only_kind:
				still = true
				i -= 1
				continue
			var store := _store_for(kind)
			if store != null and store.has_method("add") and bool(store.call("add", slot["id"], int(slot["amount"]))):
				inventory.remove_at(i)
				moved = true
			else:
				still = true
		i -= 1
	_misrouted = still
	if moved:
		_publish(&"player_inventory_changed", [get_inventory_dict()])


## The legacy shop primitive: pays unit_price x amount and adds the item. All or nothing: no room -> nothing is spent.
func buy_item(item_id: StringName, amount: int, unit_price: int) -> bool:
	if amount <= 0 or unit_price < 0:
		return false
	var total := total_of(unit_price, amount)       # saturating: an absurd amount can never wrap into an affordable total
	if not can_afford(total):
		_publish(&"notification_posted", [tr("NOTIF_NO_GOLD_TITLE"), tr("NOTIF_NO_GOLD_MSG"), "gold"])
		return false
	if not can_add_item(item_id, amount):
		if backpack_room_for(item_id) < amount and _Kinds.storage_of(item_id) == _Kinds.BACKPACK:
			_publish(&"notification_posted", [tr("NOTIF_INVENTORY_FULL_TITLE"), tr("NOTIF_INVENTORY_FULL_MSG"), "inventory"])
		return false
	spend_gold(total)
	if not add_item(item_id, amount):
		add_gold(total)                   # refund: the add failed after the gold was taken
		return false
	_publish(&"item_purchased", [item_id, amount, total])
	return true


## The legacy shop primitive: takes the items and pays unit_price x amount. Nothing happens when the items cannot be taken.
func sell_item(item_id: StringName, amount: int, unit_price: int) -> bool:
	if amount <= 0 or unit_price <= 0:
		return false
	if not has_item(item_id, amount) or not remove_item(item_id, amount):
		return false
	var total := total_of(unit_price, amount)
	add_gold(total)
	_publish(&"item_sold", [item_id, amount, total])
	return true


# ================================================================================================ tools and weapons

## Slot name for an item def: tool_<type> for tools, weapon for weapons, "" for everything else.
func equip_slot_of(item_id: Variant) -> String:
	var d := item_def(item_id)
	match str(d.get("category", "")):
		"tool":
			return str(TOOL_SLOTS.get(str(d.get("tool_type", "")), ""))
		"weapon":
			return WEAPON_SLOT
		"gem":
			if LanternGem.can_equip(item_id): return ACCESSORY_SLOT
	return ""


## The number that ranks tools and weapons: Lua `power` (tools, default 1) or `damage` (weapons).
func equip_rank_of(item_id: Variant) -> int:
	var d := item_def(item_id)
	if str(d.get("category", "")) == "weapon":
		return _Data.int_of(d.get("damage", 0))
	return _Data.int_of(d.get("power", 1), 1)


## Puts an owned tool / weapon into its slot, or empties the slot with &"". False when the item is not owned or does not fit.
func equip(slot: StringName, item_id: StringName) -> bool:
	if not equipment.has(slot):
		return false
	if item_id != &"" and (count_item(item_id) <= 0 or equip_slot_of(item_id) != str(slot)):
		return false
	var changed := str(equipment[slot])!=str(item_id)
	equipment[slot] = item_id
	_publish(&"player_inventory_changed", [get_inventory_dict()])
	if changed and item_id!=&"":
		after_transaction(func() -> void:EventBus.game_event.emit(&"equipment_changed",{"slot":str(slot),"item":str(item_id)}))
	return true


func equipped_item(slot: StringName) -> StringName:
	return StringName(str(equipment.get(slot, &"")))


## Power of the equipped tool of a type (hoe watering pickaxe axe scythe; "weapon" answers its damage). 0 = none equipped.
func get_tool_power(tool_type: Variant) -> int:
	var t := str(tool_type)
	var slot := WEAPON_SLOT if t == "weapon" else str(TOOL_SLOTS.get(t, ""))
	if slot == "":
		return 0
	var id := equipped_item(StringName(slot))
	return equip_rank_of(id) if id != &"" else 0


func get_weapon_damage() -> int:
	return get_tool_power("weapon")


## The strongest owned tool of a type (or weapon): &"" when there is none.
func best_tool_id(tool_type: Variant) -> StringName:
	var t := str(tool_type)
	var slot := WEAPON_SLOT if t == "weapon" else str(TOOL_SLOTS.get(t, ""))
	var best := &""
	var best_rank := -1.0
	for id in loadout_ids():
		if equip_slot_of(id) == slot and slot != "":
			var r := _weapon_rating(id) if t == "weapon" else float(equip_rank_of(id))
			if r > best_rank:
				best = StringName(str(id))
				best_rank = r
	return best

func loadout_ids() -> Array:
	var ids := get_inventory_dict().keys()
	if arsenal != null:
		for id in arsenal.owned_ids():
			if id not in ids: ids.append(id)
	return ids

func _weapon_rating(id: Variant) -> float:
	return float(_Svc.static_call("res://scripts/combat/weapon_info.gd",&"rating",[id],equip_rank_of(id)))


func _auto_equip(item_id: StringName, show_better: bool = true) -> void:
	var slot := equip_slot_of(item_id)
	if slot == "":
		return
	var current := equipped_item(StringName(slot))
	if slot == WEAPON_SLOT:
		if current == &"" or (str(item_def(current).get("weapon_family","sword")) == str(item_def(item_id).get("weapon_family","sword")) and _weapon_rating(item_id) > _weapon_rating(current)):
			equipment[&"weapon"] = item_id
		elif show_better and item_id != current and _weapon_rating(item_id) > _weapon_rating(current):
			_publish(&"notification_posted",[tr(str(item_def(item_id).get("name_key",""))),tr("WSTAT_BETTER"),"item"])
		return
	if slot == ACCESSORY_SLOT: return # Gem changes are always deliberate.
	if current == &"" or equip_rank_of(item_id) > equip_rank_of(current):
		equipment[StringName(slot)] = item_id


## After items left the backpack: an equipped tool that is gone is replaced by the best one that is left.
func _revalidate_equipment() -> void:
	for slot in equipment.keys():
		var id := StringName(str(equipment[slot]))
		if id != &"" and count_item(id) <= 0:
			var tool_type := ""
			for t in TOOL_SLOTS:
				if TOOL_SLOTS[t] == str(slot):
					tool_type = t
			if str(slot) == WEAPON_SLOT:
				tool_type = "weapon"
			equipment[slot] = best_tool_id(tool_type) if tool_type != "" else &""


# ================================================================================================ using an item

## The backpack's "Brug / Udstyr" (see the header). True when the item did something; consumed items are removed.
func use_item(item_id: StringName) -> bool:
	if item_id == &"" or not has_item(item_id, 1):
		return false
	var d := item_def(item_id)
	if d.is_empty():
		return false
	var category := str(d.get("category", ""))
	# a blueprint: the flag unlocks the recipes that name it, the item is used up (consumed defaults to true)
	if d.has("unlock_flag"):
		var gm := _Svc.node("GameManager")
		if gm == null:
			return false
		var flag := str(d["unlock_flag"])
		if bool(d.get("consumed", true)):
			if not consume_backpack_items({item_id: 1}, func(): gm.call("set_flag", StringName(flag), true)):
				return false
		else:
			gm.call("set_flag", StringName(flag), true)
		_publish(&"game_event", [&"blueprint_learned", {"item": str(item_id), "flag": flag}])
		_publish(&"notification_posted", [tr("ITEM_BLUEPRINT_LEARNED_TITLE"), tr("ITEM_BLUEPRINT_LEARNED_MSG"), "item"])
		return true
	var slot := equip_slot_of(item_id)
	if slot != "":
		return equip(StringName(slot), item_id)
	var heal := _Data.int_of(d.get("heal_half_hearts", 0))
	var oil := _Data.num(d.get("oil_seconds", 0.0))
	var energy := _Data.num(d.get("stamina", 0.0))
	if heal > 0 or oil > 0.0 or energy > 0.0:
		return _consume(item_id, heal, oil, energy)
	if category == "animal":
		var husbandry := _Svc.node("AnimalHusbandry")
		return husbandry != null and husbandry.has_method("adopt_animal") and bool(husbandry.call("adopt_animal", item_id))
	if category == "animal_care":
		_publish(&"game_event", [&"animal_care_item_used", {"item": str(item_id)}])
		return false                      # feeding needs an animal: the animal care screen handles the event
	if str(d.get("placeable", "")) == "farm":
		_publish(&"hotbar_assign_requested", [-1, item_id])
		return true
	return false


## Applies heal / oil / energy through the player; the item is used up when at least one effect had room to work.
func _consume(item_id: StringName, heal: int, oil: float, energy: float) -> bool:
	var player := PlayerRegistry.local_player(get_tree()) if get_tree() != null else null
	if player == null or _consuming:
		return false
	if player.has_method("apply_consumable"):
		var has_room := (heal > 0 and int(player.get("half_hearts")) < int(player.get("max_half_hearts"))) or (oil > 0 and float(player.get("oil")) < float(player.get("max_oil"))) or (energy > 0 and float(player.get("stamina")) < float(player.get("max_stamina")))
		if not has_room:
			return false
		_consuming = true
		var ok := consume_backpack_items({item_id: 1}, func() -> void:
			player.call("apply_consumable", heal, oil, energy)
		)
		_consuming = false
		return ok
	var used := false
	if heal > 0 and "half_hearts" in player and "max_half_hearts" in player and int(player.get("half_hearts")) < int(player.get("max_half_hearts")):
		if player.has_method("heal_half"):
			player.call("heal_half", heal)
			used = true
	if oil > 0.0 and "oil" in player and "max_oil" in player and float(player.get("oil")) < float(player.get("max_oil")):
		if player.has_method("add_oil"):
			player.call("add_oil", oil)
		else:
			var now := minf(float(player.get("oil")) + oil, float(player.get("max_oil")))
			player.set("oil", now)
			_publish(&"player_oil_changed", [now, float(player.get("max_oil"))])
		used = true
	if energy > 0.0 and "stamina" in player and "max_stamina" in player and float(player.get("stamina")) < float(player.get("max_stamina")):
		if player.has_method("restore_stamina"):
			player.call("restore_stamina", energy)
		else:
			player.set("stamina", minf(float(player.get("stamina")) + energy, float(player.get("max_stamina"))))
		used = true
	if used:
		remove_item(item_id, 1)
	return used


# ================================================================================================ save

func to_dict() -> Dictionary:
	adopt_misrouted()
	var slots: Array = []
	for slot in inventory:
		slots.append({"id": str(slot["id"]), "amount": int(slot["amount"]), "meta": (slot["meta"] as Dictionary).duplicate(true) if typeof(slot.get("meta")) == TYPE_DICTIONARY else {}})
	var equipped := {}
	for key in equipment:
		equipped[str(key)] = str(equipment[key])
	return {"v": SAVE_VERSION, "gold": gold, "inventory": slots, "equipment": equipped, "arsenal":arsenal.to_dict() if arsenal != null else {}}


## Rebuilds the state after the JSON round trip (every number is a float or an int, ids are plain Strings). Invalid slots
## (not a dictionary, no id, an amount <= 0 after coercion) are dropped, a slot above max_stack is split, more than
## INVENTORY_SLOTS slots keep the first ones. Returns true.
func from_dict(data: Dictionary) -> bool:
	_misrouted = false
	if arsenal != null: arsenal.from_dict(_Data.dict(data.get("arsenal",{})))
	gold = _gold_of(data.get("gold", DEFAULT_STARTING_GOLD), DEFAULT_STARTING_GOLD)
	inventory.clear()
	var raw: Variant = data.get("inventory", [])
	var entries: Array = []
	if typeof(raw) == TYPE_ARRAY:
		entries = raw
	elif typeof(raw) == TYPE_DICTIONARY:                 # {id: amount} is accepted too
		for id in (raw as Dictionary):
			entries.append({"id": id, "amount": (raw as Dictionary)[id]})
	var dropped := 0
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			dropped += 1
			continue
		var id := StringName(str((entry as Dictionary).get("id", "")).strip_edges())
		var amount := _Data.int_of((entry as Dictionary).get("amount", 0))
		if id == &"" or amount <= 0:
			dropped += 1
			continue
		var meta: Dictionary = (entry as Dictionary).get("meta", {}) if typeof((entry as Dictionary).get("meta", {})) == TYPE_DICTIONARY else {}
		var ms := max_stack_of(id)
		while amount > 0:
			if inventory.size() >= INVENTORY_SLOTS:
				dropped += 1
				amount = 0
				break
			var take := mini(amount, ms)
			inventory.append({"id": id, "amount": take, "meta": meta.duplicate(true)})
			amount -= take
	if dropped > 0:
		_log_once("from_dict dropped %d invalid or surplus slot(s)" % dropped)
	# The player's own choice wins: a slot the save names (a weaker tool picked on purpose, or "" = deliberately empty) is restored
	# as it was. Only a slot the save does not decide (an old save without `equipment`, an entry that is not owned any more or
	# does not fit the slot) gets the best tool the player owns.
	equipment = _empty_equipment()
	var decided := {}
	var saved: Variant = data.get("equipment", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for key in (saved as Dictionary):
			var slot := StringName(str(key))
			if not equipment.has(slot):
				continue
			var id := StringName(str((saved as Dictionary)[key]).strip_edges())
			if id == &"" or (count_item(id) > 0 and equip_slot_of(id) == str(slot)):
				equipment[slot] = id
				decided[slot] = true
	for id in loadout_ids():
		var slot_of_entry := equip_slot_of(id)
		if slot_of_entry != "" and not decided.has(StringName(slot_of_entry)):
			_auto_equip(StringName(str(id)),false)
	_misrouted = true                          # a save made before a store existed may hold its items in the backpack
	adopt_misrouted(_Kinds.WEAPON)
	_publish(&"player_inventory_changed", [get_inventory_dict()])
	_publish(&"gold_changed", [gold, 0])
	return true


# ================================================================================================ internals

func _store_for(kind: StringName) -> Node:
	if kind == _Kinds.WEAPON:
		return arsenal
	if kind == _Kinds.FURNITURE:
		return _Svc.node("FurnitureManager")
	if kind == _Kinds.CLOTHING:
		return _Svc.node("WardrobeManager")
	return null


func _backpack_count(item_id: StringName) -> int:
	var n := 0
	for slot in inventory:
		if slot["id"] == item_id:
			n += int(slot["amount"])
	return n


## Fills the half-empty stacks of the item first, then opens new slots. The caller checked the room.
func _stack_into_backpack(item_id: StringName, amount: int) -> void:
	var ms := max_stack_of(item_id)
	var left := amount
	for slot in inventory:
		if left <= 0:
			break
		if slot["id"] == item_id and int(slot["amount"]) < ms:
			var take := mini(ms - int(slot["amount"]), left)
			slot["amount"] = int(slot["amount"]) + take
			left -= take
	while left > 0:
		var take := mini(ms, left)
		inventory.append({"id": item_id, "amount": take, "meta": {}})
		left -= take


## One successful add: the backpack signal always, the rest unless silent.
func _gained(item_id: StringName, amount: int, silent: bool) -> void:
	_publish(&"player_inventory_changed", [get_inventory_dict()])
	if silent:
		return
	_publish(&"item_gained", [item_id, amount])
	var rarity := _Kinds.rarity_of(item_id)
	if _RarityScript.rank(rarity) >= RARE_RANK:
		_publish(&"rare_item_found", [item_id, rarity])
	var name_key := str(_Kinds.def(item_id).get("name_key", "ITEM_%s" % str(item_id).to_upper()))
	_publish(&"notification_posted", [tr("NOTIF_ITEM_GAINED_TITLE"), "%s x%d" % [tr(name_key), amount], "item"])


func _log_once(message: String) -> void:
	if _logged.has(message):
		return
	_logged[message] = true
	print("[Economy] ", message)
