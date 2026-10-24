extends RefCounted
## Real ShopSystem policy/transaction checks; no grants of construction materials.
## Transaction fixtures have finite funds; earned lifetime acceptance is in test_balance_supply.py.
static func run(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var shop: Node = t.autoload("ShopSystem")
	var eco: Node = t.autoload("EconomyManager")
	var lr: Node = t.autoload("LuaRuntime")
	var bus: Node = t.autoload("EventBus")
	Fresh.new_game(t, "animal", "Supply", "Supply", "", 424242)
	gm.set_config_override("towns.hours_enabled", false)
	var yard: Dictionary = lr.get_shop("builder_yard")
	var fixed: Dictionary = LuaData.dict(yard.stock)
	var problems: Array[String] = []
	for id in fixed:
		if int(fixed[id].stock) != 40 or int(fixed[id].restock) != 40:
			problems.append("%s: %s" % [id, fixed[id]])
	for slot in LuaData.arr(yard.rotation):
		if int(slot.pick) != LuaData.arr(slot.pool).size() or int(slot.qty) != 40:
			problems.append("slot %s: pick %s qty %s" % [slot.id, slot.pick, slot.qty])
	t.check("builder_bounded_supply_policy", problems.is_empty(), str(problems))
	# A full shelf still cannot be oversold; the real transaction pays the listed price.
	eco.add_gold(20000)
	var before: int = eco.gold
	var price: int = shop.get_buy_price("builder_yard", "stone_block")
	t.check("builder_real_shelf_exhaustion", shop.buy_item("builder_yard", "stone_block", 40) and eco.gold == before - 40 * price and eco.count_item("stone_block") == 40)
	var exhausted: Dictionary = shop.to_dict().duplicate(true)
	before = eco.gold
	t.check("builder_no_oversell", not shop.buy_item("builder_yard", "stone_block", 1) and shop.last_refusal == &"no_stock" and eco.gold == before and shop.to_dict() == exhausted and eco.count_item("stone_block") == 40)
	# JSON restore of an exhausted shelf must not mint stock.
	shop.from_dict(JSON.parse_string(JSON.stringify(exhausted)))
	t.check("builder_exhaustion_survives_save", not shop.buy_item("builder_yard", "stone_block", 1) and shop.last_refusal == &"no_stock")
	gm.end_day()
	t.check("builder_full_dawn_replenishment", shop.buy_item("builder_yard", "stone_block", 40) and eco.count_item("stone_block") == 80)
	# Each fine material is present for every save, but exhausted until NEXT weekly epoch.
	var marble_rows: Array = shop.get_shop_inventory("builder_yard").filter(func(row): return str(row.item_id) == "marble_block")
	t.check("builder_marble_guaranteed", marble_rows.size() == 1 and int(marble_rows[0].stock) == 40, str(marble_rows))
	if marble_rows.size() == 1 and int(marble_rows[0].stock) == 40:
		t.check("builder_marble_exhaustion", shop.buy_item("builder_yard", "marble_block", 40) and not shop.buy_item("builder_yard", "marble_block", 1) and shop.last_refusal == &"no_stock")
		var saved: Dictionary = JSON.parse_string(JSON.stringify(shop.to_dict()))
		shop.from_dict(saved)
		Fresh.jump_to_total_day(7)
		bus.day_started.emit(gm.day, gm.season)
		t.check("builder_weekly_not_daily_refill", not shop.buy_item("builder_yard", "marble_block", 1) and shop.last_refusal == &"no_stock")
		Fresh.jump_to_total_day(8)
		bus.day_started.emit(gm.day, gm.season)
		t.check("builder_next_epoch_refills", shop.buy_item("builder_yard", "marble_block", 1))
	# No-gold refusal leaves both the shelf and inventory unchanged.
	eco.spend_gold(eco.gold)
	var state: Dictionary = shop.to_dict().duplicate(true)
	var inventory: Dictionary = eco.get_inventory_dict().duplicate(true)
	t.check("builder_failed_payment_rolls_back", not shop.buy_item("builder_yard", "nails", 1) and shop.last_refusal == &"no_gold" and eco.gold == 0 and shop.to_dict() == state and eco.get_inventory_dict() == inventory)
	# An affordable order that cannot enter the real backpack must also roll back.
	eco.add_gold(100)
	for _slot in range(eco.INVENTORY_SLOTS):
		if not eco.add_item("wood", 99, true):
			break
	before = eco.gold
	state = shop.to_dict().duplicate(true)
	inventory = eco.get_inventory_dict().duplicate(true)
	t.check("builder_full_backpack_rolls_back", not shop.buy_item("builder_yard", "nails", 1) and shop.last_refusal == &"no_room" and eco.gold == before and shop.to_dict() == state and eco.get_inventory_dict() == inventory)
	# Keep the stock-aware model and earned late-tier acceptance in the normal
	# shop_rotation harness/CI path, not as an unregistered standalone test file.
	var model: Dictionary = t.run_tool(t.python(), ["-B", "-I", ProjectSettings.globalize_path("res://tools/features/sim/test_balance_supply.py")])
	t.check("builder_stock_model_source_acceptance", int(model.code) == 0, str(model.output))
