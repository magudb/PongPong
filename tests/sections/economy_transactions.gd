extends RefCounted
## Observe committed state through the same synchronous signals that UI and saves use.
const SECTION := "economy_transactions"
const TIMEOUT_S := 90.0
func run(t) -> void:
	await t.go_menu()
	Fresh.new_game(t, "animal")
	var eco: Node = t.autoload("EconomyManager")
	var shop: Node = t.autoload("ShopSystem")
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	gm.set_config_override("towns.hours_enabled", false)
	eco.gold = 10000
	var id := &"carrot_seeds"
	var owned: int = eco.count_item(id)
	var stock: int = _row(shop, id).stock
	var price: int = shop.get_buy_price(&"seed_shop", id)
	var observations: Array = []
	var observe := func() -> void:
		observations.append([eco.gold, eco.count_item(id), _row(shop, id).stock, shop.buy_item(&"seed_shop", id, 1), shop.sell_item(&"seed_shop", id, 1)])
	var gold := func(_amount, _delta): observe.call()
	var inventory := func(_inventory): observe.call()
	var gained := func(_id, _amount): observe.call()
	var purchased := func(_id, _amount, _cost): observe.call()
	var transacted := func(_shop, _id, _amount, _buy): observe.call()
	bus.gold_changed.connect(gold)
	bus.player_inventory_changed.connect(inventory)
	bus.item_gained.connect(gained)
	bus.item_purchased.connect(purchased)
	shop.shop_transaction.connect(transacted)
	var bought: bool = shop.buy_item(&"seed_shop", id, 1)
	t.check("purchase_state_committed_before_every_observer", bought and observations.size() >= 5 and observations.all(func(row): return row == [10000 - price, owned + 1, stock - 1, false, false]), str(observations))
	t.check("purchase_reentry_does_not_replace_outer_result", shop.last_refusal == &"" and eco.count_item(id) == owned + 1)
	bus.item_gained.disconnect(gained)
	bus.item_purchased.disconnect(purchased)
	var sold := func(_id, _amount, _price): observe.call()
	bus.item_sold.connect(sold)
	observations.clear()
	var sell_price: int = shop.get_sell_price(&"seed_shop", id)
	var sale: bool = shop.sell_item(&"seed_shop", id, 1)
	t.check("sale_committed_before_inventory_and_gold_observers", sale and observations.size() >= 4 and observations.all(func(row): return row == [10000 - price + sell_price, owned, stock - 1, false, false]), str(observations))
	bus.gold_changed.disconnect(gold)
	bus.player_inventory_changed.disconnect(inventory)
	bus.item_sold.disconnect(sold)
	shop.shop_transaction.disconnect(transacted)
	# Failure notifications are also guarded: an observer cannot recursively buy.
	eco.gold = 0
	var failures: Array = []
	var refused := func(_title, _text, _icon): failures.append(shop.buy_item(&"seed_shop", id, 1))
	bus.notification_posted.connect(refused)
	var cannot_buy: bool = not shop.buy_item(&"seed_shop", id, 1)
	bus.notification_posted.disconnect(refused)
	t.check("failed_purchase_guard_and_reason", cannot_buy and failures == [false] and shop.last_refusal == &"no_gold" and eco.gold == 0 and eco.count_item(id) == owned and int(_row(shop, id).stock) == stock - 1)
	await _craft(t)
	_blueprint(t)
	gm.clear_config_overrides()
	Fresh.new_game(t)

func _row(shop: Node, id: StringName) -> Dictionary:
	for row in shop.get_shop_inventory(&"seed_shop"):
		if row.item_id == id:
			return row
	return {}

func _craft(t) -> void:
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	eco.inventory.clear()
	eco.add_item(&"copper_ore", 6, true)
	eco.add_item(&"wood", 4, true)
	var observations: Array = []
	var observe := func() -> void:
		observations.append([eco.count_item(&"copper_ore"), eco.count_item(&"wood"), eco.count_item(&"pickaxe_copper"), CraftingSystem.craft("pickaxe_copper")])
	var inventory := func(_inventory): observe.call()
	var gained := func(_id, _amount): observe.call()
	var crafted := func(_id, _amount): observe.call()
	bus.player_inventory_changed.connect(inventory)
	bus.item_gained.connect(gained)
	bus.recipe_crafted.connect(crafted)
	var ok := CraftingSystem.craft("pickaxe_copper")
	bus.player_inventory_changed.disconnect(inventory)
	bus.item_gained.disconnect(gained)
	bus.recipe_crafted.disconnect(crafted)
	t.check("craft_committed_before_every_observer_and_reentry_blocked", ok and observations.size() >= 5 and observations.all(func(row): return row == [3, 2, 1, false]), str(observations))
	t.check("craft_guard_releases_for_next_action", CraftingSystem.craft("pickaxe_copper") and eco.count_item(&"copper_ore") == 0 and eco.count_item(&"wood") == 0 and eco.count_item(&"pickaxe_copper") == 2)

func _blueprint(t) -> void:
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	var item := &"blueprint_kongelig"
	gm.set_flag(&"bp_kongelig", false)
	eco.add_item(item, 1, true)
	var observed: Array = []
	var on_flag := func(flag, value):
		if flag == &"bp_kongelig" and value:
			observed.append([eco.count_item(item), eco.use_item(item)])
	bus.flag_changed.connect(on_flag)
	var learned: bool = eco.use_item(item)
	bus.flag_changed.disconnect(on_flag)
	t.check("blueprint_consumed_before_unlock_observers", learned and observed == [[0, false]] and eco.count_item(item) == 0 and bool(gm.get_flag(&"bp_kongelig", false)), str(observed))
