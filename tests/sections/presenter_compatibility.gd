extends RefCounted
const SECTION := "presenter_compatibility"
const TIMEOUT_S := 150.0
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	t.autoload("SaveManager").autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var home = load("res://tests/sections/home.gd").new()
	home._t = t
	home._bus = t.autoload("EventBus")
	home._gm = gm
	home._hm = t.autoload("HomeManager")
	home._lr = t.autoload("LuaRuntime")
	home._hm.set_tier(3)
	gm.set_flag(&"home_upgrade_done", 3)
	home._celebrate_and_check(t, 3)
	t.check("legacy_home_celebration_clears_earned_flag", gm.flag_int(&"home_upgrade_done", -1) == 0)
	home._eco = t.autoload("EconomyManager")
	home._qm = t.autoload("QuestManager")
	home._sm = t.autoload("SaveManager")
	home._lm = t.autoload("LocalizationManager")
	var home_script: GDScript = load("res://tests/sections/home.gd")
	home._rec = home_script.Rec.new()
	home._rec.attach(home._bus)
	home._ladder(t)
	# home._flag_mirror saves after a model-only new game (Fresh.new_game), the title-screen shape: this World would stay
	# bound to the previous profile and refuse that save, so it runs from the menu as in home, and the quest and delivery
	# drivers below get a real new World again.
	await t.go_menu()
	home._flag_mirror(t)
	home._rec.detach(home._bus)
	if is_instance_valid(home._dialogue_fixture): home._dialogue_fixture.free()
	await t.start_world()
	var quests = load("res://tests/sections/quests.gd").new()
	quests.t = t
	for pair in [["qm","QuestManager"],["gm","GameManager"],["eco","EconomyManager"],["bus","EventBus"],["lr","LuaRuntime"],["lm","LocalizationManager"]]: quests.set(pair[0], t.autoload(pair[1]))
	var result: Dictionary = await quests._drive("dark_forest_mining", {})
	t.check("legacy_quest_physical_driver_exact_payout", result.problems.is_empty(), str(result.problems))
	for producer in ["initial", "followup", "consumer"]:
		await preload("res://tests/progression/mining_deliveries.gd").invalid_owner(t, producer)
		for ambient in [&"", &"p2"]:
			for quest in [&"dark_forest_mining", &"crystal_cave"]:
				await preload("res://tests/progression/mining_deliveries.gd").owner_hand_in(t, quest, producer, ambient)
	await preload("res://tests/progression/mining_deliveries.gd").hand_in(t, &"dark_forest_mining", {"iron_ore":6, "amethyst":2})
	await preload("res://tests/progression/mining_deliveries.gd").hand_in(t, &"crystal_cave", {"crystal_shard":5}, true)
	await preload("res://tests/progression/mining_deliveries.gd").proof_items_stay_owned(t)
	for service in ["board", "post"]:
		for decision in ["cancel", "decline", "accept"]:
			await preload("res://tests/progression/mining_deliveries.gd").service_offer(t, &"dark_forest_mining", &"crystal_cave", service, decision)
			await preload("res://tests/progression/mining_deliveries.gd").service_offer(t, &"crystal_cave", &"dark_forest_mining", service, decision)
	gm.clear_config_overrides()
