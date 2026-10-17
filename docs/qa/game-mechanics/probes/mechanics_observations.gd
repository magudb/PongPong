extends RefCounted
## Review probes: passing means an observation is reproduced, not that it is desirable.
const SECTION := "mechanics_observations"
const TIMEOUT_S := 120.0

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var lr: Node = t.autoload("LuaRuntime")
	var shops: Node = t.autoload("ShopSystem")
	var ah: Node = t.autoload("AnimalHusbandry")
	gm.set_config_override("time.minutes_per_real_second", 0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.set_flag(&"intro_pending", false)
	var items := {}
	var prices := {}
	var sell_values := {}
	for id in lr.get_all_item_ids():
		items[str(id)] = lr.get_item_def(str(id)).duplicate(true)
		var offers := {}
		var highest_sell := 0
		for shop in shops.get_shop_ids():
			var buy: int = shops.get_buy_price(shop, id)
			var sell: int = shops.get_sell_price(shop, id)
			highest_sell = maxi(highest_sell, sell)
			if buy > 0: offers[str(shop)] = {"buy": buy, "sell": sell}
		prices[str(id)] = offers
		sell_values[str(id)] = highest_sell
	var data := {"base_commit": "abec447", "items": items, "prices": prices, "sell_values": sell_values,
		"shops": lr.get_shops(), "recipes": lr.get_recipes(), "crops": lr.get_config("crops", {}),
		"husbandry": lr.get_config("husbandry", {}), "home_tiers": lr.get_config("home.tiers", []),
		"race_perks": lr.get_config("race_perks", {})}
	var ui: GameUI = t.world().game_ui
	await t.tap(&"collection")
	await t.frames(3)
	data["collection"] = {"input_exists": InputMap.has_action(&"collection"),
		"scene_exists": ResourceLoader.exists("res://scenes/ui/samlerbog.tscn"),
		"screen_loaded": ui.get_screen(&"samlerbog") != null, "modal_after_input": gm.is_modal_open()}
	t.check("advertised_collection_input_has_no_screen", InputMap.has_action(&"collection") and ui.get_screen(&"samlerbog") == null and not gm.is_modal_open())
	eco.add_gold(3000)
	for entry in {"wood": 30, "stone": 20, "brush": 1, "baby_chick": 1}:
		eco.add_item(StringName(entry), {"wood": 30, "stone": 20, "brush": 1, "baby_chick": 1}[entry], true)
	t.check("paid_coop_built", ah.build_building(&"coop"))
	t.check("chick_adopted_through_normal_api", ah.adopt_animal(&"baby_chick"))
	var animal: Variant = ah.animals.values()[0]
	var trace: Array = []
	var hungry_eggs := 0
	var total_eggs := 0
	seed(20261017)
	for index in 30:
		var brushed: bool = ah.brush_animal(animal.id)
		var played: bool = ah.play_with_animal(animal.id)
		gm.end_day()
		var amount: int = ah.collect_product(animal.id)
		total_eggs += amount
		if animal.hunger == 0.0: hungry_eggs += amount
		trace.append({"day": gm.total_day(), "hunger": animal.hunger, "happiness": animal.happiness,
			"brushed": brushed, "played": played, "eggs": amount, "last_fed_day": animal.last_fed_day})
	data["unfed_chicken"] = {"trace": trace, "eggs": total_eggs, "eggs_at_zero_hunger": hungry_eggs,
		"feed_owned": eco.count_item(&"chicken_feed"), "last_fed_day": animal.last_fed_day}
	t.check("unfed_zero_hunger_chicken_keeps_producing", hungry_eggs > 0 and animal.last_fed_day == 0 and eco.count_item(&"chicken_feed") == 0, "%d eggs; %d at zero food" % [total_eggs, hungry_eggs])
	eco.add_item(&"wood", 40, true)
	eco.add_item(&"stone", 25, true)
	eco.add_item(&"baby_calf", 1, true)
	t.check("paid_barn_built", ah.build_building(&"barn"))
	t.check("calf_adopted_through_normal_api", ah.adopt_animal(&"baby_calf"))
	var cow: Variant = ah.get_animals_by_species(&"cow")[0]
	var milk := 0
	for index in 9:
		ah.brush_animal(cow.id)
		ah.play_with_animal(cow.id)
		gm.end_day()
		milk += int(ah.collect_product(cow.id))
	data["milking_pail"] = {"pail_owned": eco.count_item(&"milking_pail"), "milk_collected": milk}
	t.check("milk_collected_without_pail", milk > 0 and eco.count_item(&"milking_pail") == 0, str(data.milking_pail))
	var boss_def: Dictionary = t.autoload("QuestManager").get_quest_def(&"bossernes_vej")
	data["guardian_objectives"] = boss_def.get("objectives", [])
	t.check("meet_guardians_copy_binds_to_kills", LuaData.arr(boss_def.get("objectives", []))[0].get("on") == "enemy_defeated")
	var file := FileAccess.open("res://docs/qa/game-mechanics/runtime-data.json", FileAccess.WRITE)
	t.check("runtime_data_written", file != null)
	if file != null: file.store_string(JSON.stringify(data, "\t") + "\n")
