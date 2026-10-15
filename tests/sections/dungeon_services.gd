extends RefCounted
## DR7 data through the real registries, crafting and quest runtime.
const SECTION := "dungeon_services"
const SUPPLIES := ["tornebaer", "lysdraabe", "svampe_eliksir", "etagekort", "ugle_noegle"]
const QUESTS := ["skovlift_intro", "rune_vandring", "ugles_noegle", "bossernes_vej"]

func run(t) -> void:
	await t.go_menu()
	t.new_game()
	var lr: Node = t.autoload("LuaRuntime")
	var eco: Node = t.autoload("EconomyManager")
	var qm: Node = t.autoload("QuestManager")
	var loc: Node = t.autoload("LocalizationManager")
	var defs_ok := true
	var keys: Array[String] = []
	for id in SUPPLIES:
		var d: Dictionary = lr.get_item_def(id)
		defs_ok = defs_ok and not d.is_empty() and d.get("rarity") == "normal" and int(d.get("max_stack", 0)) > 0
		defs_ok = defs_ok and int(d.get("sell_price", 0)) <= int(d.get("buy_price", 0)) / 2 and int(d.get("stamina_cost", -1)) == 0
		keys.append(str(d.get("name_key", "")))
		keys.append(str(d.get("description_key", "")))
	t.check("supplies_defs_valid", defs_ok and lr.get_item_def("tornebaer").get("heal_on_pickup") == true and lr.get_item_def("etagekort").get("reveal_next_floor") == true and lr.get_item_def("ugle_noegle").get("key_for") == "ugle_noegle")
	eco.add_item(&"glow_mushroom", 5)
	eco.add_item(&"moss", 1)
	t.check("elixir_recipes_craftable", CraftingSystem.craft("lysdraabe") and CraftingSystem.craft("svampe_eliksir") and eco.count_item(&"glow_mushroom") == 0 and eco.count_item(&"moss") == 0 and eco.count_item(&"lysdraabe") == 1 and eco.count_item(&"svampe_eliksir") == 1, "Both station-free recipes consume exact ingredients and produce their supplies")
	var shop: Dictionary = lr.get_shop("natteblik_maps")
	var stock := LuaData.dict(LuaData.dict(shop.get("stock", {})).get("etagekort", {}))
	t.check("shops_valid", shop.get("keeper") == "mapseller_natteblik" and int(stock.get("price", 0)) == 40 and int(stock.get("stock", 0)) == 5 and int(stock.get("restock", 0)) == 5 and not LuaData.dict(lr.get_config("npcs.mapseller_natteblik", {})).has("shop_id"))
	var quests_ok := true
	for id in QUESTS:
		var d: Dictionary = qm.get_quest_def(StringName(id))
		quests_ok = quests_ok and not d.is_empty() and not LuaData.arr(d.get("objectives", [])).is_empty()
		for suffix in ["TITLE", "DESC", "OFFER", "CHOICE", "REMIND"]:
			keys.append("QUEST_%s_%s" % [id.to_upper(), suffix])
		for o in LuaData.arr(d.get("objectives", [])):
			keys.append(str(o.get("description_key", "")))
	t.check("quests_load_and_bind", quests_ok, "The table-driven quests section additionally completes all four through real EventBus signals")
	var ugle: Dictionary = lr.get_config("npcs.appraiser_fru_ugle", {})
	t.expect("ugles_noegle" in LuaData.strings(ugle.get("quests_offered", [])) and "rune_vandring" in LuaData.strings(ugle.get("quests_offered", [])), "Fru Ugle owns the two quests")
	var oak_source := FileAccess.get_file_as_string("res://lua/dialogue/guard_oak.lua")
	if not oak_source.contains('quest_id = "skovlift_intro"'):
		t.skip("dialogue_hooks_present: P14-npc-dialogue installs Oak’s gated quest choices; V7 installs Fru Ugle’s choices")
	else:
		t.check("dialogue_hooks_present", oak_source.contains('quest_id = "bossernes_vej"'))
	keys.append_array(["RECIPE_LYSDRAABE", "RECIPE_SVAMPE_ELIKSIR", "SHOP_NATTEBLIK_MAPS", "SHOP_NATTEBLIK_MAPS_GREETING"])
	var missing: Array[String] = []
	for key in keys:
		for language in ["da", "en"]:
			if loc.text_in(key, language) in ["", key]:
				missing.append(key + ":" + language)
	t.check("keys_defined_da_en", missing.is_empty(), str(missing))
	t.check("section_clean", lr.lint_report.is_empty(), str(lr.lint_report))
	t.new_game()
