extends Node
## Shop inventory, buy/sell, stock refresh. Shops are data-driven.

signal shop_transaction(shop_id: StringName, item_id: StringName, amount: int, is_buy: bool)

const SHOPS := {
	"general_store": {
		"name_key": "SHOP_GENERAL_STORE",
		"npc_id": "merchant_pip",
		"description_key": "SHOP_GENERAL_STORE_DESC",
		"currency": "gold",
		"buy_multiplier": 1.0,
		"sell_multiplier": 0.5,
		"stock": {
			"turnip_seeds": {"price": 20, "stock": 25},
			"carrot_seeds": {"price": 30, "stock": 20},
			"moonflower_seeds": {"price": 80, "stock": 8},
			"pumpkin_seeds": {"price": 50, "stock": 15},
			"hoe_wooden": {"price": 50, "stock": 5},
			"hoe_iron": {"price": 400, "stock": 2},
			"watering_can_copper": {"price": 80, "stock": 5},
			"watering_can_gold": {"price": 600, "stock": 1},
			"pickaxe_wooden": {"price": 60, "stock": 5},
			"pickaxe_iron": {"price": 500, "stock": 2},
			"axe_wooden": {"price": 60, "stock": 5},
			"cookie": {"price": 25, "stock": 15},
			"wood": {"price": 5, "stock": 50},
			"stone": {"price": 4, "stock": 50},
		},
	},
	"magic_store": {
		"name_key": "SHOP_MAGIC_STORE",
		"npc_id": "fairy_wizard",
		"description_key": "SHOP_MAGIC_STORE_DESC",
		"currency": "gold",
		"buy_multiplier": 1.1,
		"sell_multiplier": 0.55,
		"stock": {
			"fairy_dust": {"price": 320, "stock": 5},
			"moonflower_seeds": {"price": 75, "stock": 12},
			"rare_mushroom": {"price": 90, "stock": 8},
			"lucky_clover": {"price": 65, "stock": 8},
			"crystal_shard": {"price": 130, "stock": 5},
			"amethyst": {"price": 220, "stock": 3},
			"emerald": {"price": 480, "stock": 2},
			"magic_scroll": {"price": 250, "stock": 3},
			"mana_potion": {"price": 120, "stock": 10},
			"teleport_stone": {"price": 400, "stock": 3},
			"enchanted_soil": {"price": 180, "stock": 6},
			"glow_berry_seeds": {"price": 95, "stock": 8},
		},
	},
	"animal_store": {
		"name_key": "SHOP_ANIMAL_STORE",
		"npc_id": "farmer_rosa",
		"description_key": "SHOP_ANIMAL_STORE_DESC",
		"currency": "gold",
		"buy_multiplier": 1.0,
		"sell_multiplier": 0.6,
		"stock": {
			"baby_chick": {"price": 150, "stock": 5},
			"baby_bunny": {"price": 180, "stock": 5},
			"baby_duck": {"price": 200, "stock": 4},
			"baby_kitten": {"price": 350, "stock": 3},
			"baby_puppy": {"price": 350, "stock": 3},
			"baby_lamb": {"price": 400, "stock": 3},
			"baby_calf": {"price": 500, "stock": 2},
			"baby_fawn": {"price": 600, "stock": 2},
			"baby_fox": {"price": 750, "stock": 1},
			"baby_owl": {"price": 800, "stock": 1},
			"chicken_feed": {"price": 15, "stock": 30},
			"animal_treats": {"price": 25, "stock": 20},
			"brush": {"price": 40, "stock": 5},
			"milking_pail": {"price": 60, "stock": 3},
			"coop_kit": {"price": 500, "stock": 2},
			"barn_kit": {"price": 1200, "stock": 1},
		},
	},
	"bakery": {
		"name_key": "SHOP_BAKERY",
		"npc_id": "baker_maja",
		"description_key": "SHOP_BAKERY_DESC",
		"currency": "gold",
		"buy_multiplier": 1.0,
		"sell_multiplier": 0.5,
		"stock": {
			"cookie": {"price": 25, "stock": 12},
			"turnip_seeds": {"price": 25, "stock": 8},
			"carrot_seeds": {"price": 35, "stock": 5},
		},
	},
	"smithy": {
		"name_key": "SHOP_SMITHY",
		"npc_id": "smith_thorin",
		"description_key": "SHOP_SMITHY_DESC",
		"currency": "gold",
		"buy_multiplier": 1.0,
		"sell_multiplier": 0.5,
		"stock": {
			"sword_rusty": {"price": 100, "stock": 3},
			"iron_sword": {"price": 750, "stock": 1},
			"pickaxe_iron": {"price": 500, "stock": 2},
			"hoe_iron": {"price": 400, "stock": 2},
			"axe_wooden": {"price": 70, "stock": 5},
		},
	},
}

var _live_stock: Dictionary = {}  # shop_id -> {item_id -> remaining_stock}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_all_stock()
	EventBus.day_started.connect(_on_day_started)


func _reset_all_stock() -> void:
	for shop_id in SHOPS:
		_live_stock[shop_id] = {}
		var shop: Dictionary = SHOPS[shop_id]
		for item_id in shop["stock"]:
			_live_stock[shop_id][item_id] = shop["stock"][item_id]["stock"]


func get_shop_inventory(shop_id: StringName) -> Array:
	var out: Array = []
	if not SHOPS.has(str(shop_id)):
		return out
	var shop: Dictionary = SHOPS[str(shop_id)]
	var live: Dictionary = _live_stock.get(str(shop_id), {})
	for item_id in shop["stock"]:
		var entry: Dictionary = shop["stock"][item_id]
		out.append({
			"item_id": item_id,
			"price": entry["price"],
			"stock": live.get(item_id, 0),
			"name_key": "ITEM_%s" % item_id.to_upper(),
		})
	return out


func get_shop_info(shop_id: StringName) -> Dictionary:
	return SHOPS.get(str(shop_id), {})


func buy_item(shop_id: StringName, item_id: StringName, amount: int = 1) -> bool:
	var shop_key := str(shop_id)
	if not SHOPS.has(shop_key):
		return false
	var shop: Dictionary = SHOPS[shop_key]
	if not shop["stock"].has(str(item_id)):
		return false

	var live: Dictionary = _live_stock.get(shop_key, {})
	var remaining: int = live.get(str(item_id), 0)
	if remaining < amount:
		EventBus.notification_posted.emit(
			tr("NOTIF_NO_STOCK_TITLE"),
			tr("NOTIF_NO_STOCK_MSG"),
			"shop"
		)
		return false

	var price: int = int(shop["stock"][str(item_id)]["price"] * shop["buy_multiplier"])
	if not EconomyManager.buy_item(item_id, amount, price):
		return false

	live[str(item_id)] = remaining - amount
	shop_transaction.emit(shop_id, item_id, amount, true)
	return true


func sell_item(shop_id: StringName, item_id: StringName, amount: int = 1) -> bool:
	var shop_key := str(shop_id)
	if not SHOPS.has(shop_key):
		return false
	var shop: Dictionary = SHOPS[shop_key]

	var item_def: Dictionary = LuaRuntime.get_item_def(str(item_id))
	var base_price: int = item_def.get("sell_price", item_def.get("buy_price", 10))
	var price: int = int(base_price * shop["sell_multiplier"])

	if not EconomyManager.sell_item(item_id, amount, price):
		return false
	shop_transaction.emit(shop_id, item_id, amount, false)
	return true


func get_sell_price(shop_id: StringName, item_id: StringName) -> int:
	var shop_key := str(shop_id)
	if not SHOPS.has(shop_key):
		return 0
	var shop: Dictionary = SHOPS[shop_key]
	var item_def: Dictionary = LuaRuntime.get_item_def(str(item_id))
	var base_price: int = item_def.get("sell_price", item_def.get("buy_price", 10))
	return int(base_price * shop["sell_multiplier"])


func get_buy_price(shop_id: StringName, item_id: StringName) -> int:
	var shop_key := str(shop_id)
	if not SHOPS.has(shop_key):
		return 0
	var shop: Dictionary = SHOPS[shop_key]
	if not shop["stock"].has(str(item_id)):
		return 0
	return int(shop["stock"][str(item_id)]["price"] * shop["buy_multiplier"])


func _on_day_started(_day: int, _season: StringName) -> void:
	_reset_all_stock()


func open_shop(shop_id: StringName) -> void:
	EventBus.shop_opened.emit(shop_id)


func close_shop(shop_id: StringName) -> void:
	EventBus.shop_closed.emit(shop_id)
