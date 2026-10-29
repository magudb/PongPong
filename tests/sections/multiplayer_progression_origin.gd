extends RefCounted
const SECTION := "multiplayer_progression_origin"
const TIMEOUT_S := 120.0
const Callback := preload("res://tests/sections/multiplayer_callback_ownership.gd")

func _open_turnins() -> bool:
	for id: StringName in [&"forest_patrol", &"night_flower"]:
		if not QuestManager.is_active(id) or QuestManager.is_completed(id): return false
		var rt: Dictionary = QuestManager.get_quest_progress(id)
		if rt.objectives["return_to_oak"].current != 0: return false
		for oid in rt.objectives:
			if oid != "return_to_oak" and not rt.objectives[oid].done: return false
	return true

func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	if OS.get_environment("MP4_ORIGIN_CASE") == "newgame":
		await _newgame(t, saves)
		return
	if not await t.start_world(): return
	saves.save_dir = "user://mp4-progression-origin"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	GameManager.set_clock(10, 0)
	TimeManager.set_weather(&"klart")
	await t.world().travel(&"traetoppen", &"default")
	NpcDirector.resync("guard_oak")
	await t.until(func(): return NpcDirector.node_of("guard_oak") != null, 10)
	var oak: Node = NpcDirector.node_of("guard_oak")
	if not t.expect(oak != null, "installed GuardOak is present at authored guard hour"): return
	QuestManager.accept_quest(&"forest_patrol")
	QuestManager.accept_quest(&"night_flower")
	EconomyManager.add_item(&"moss", 6)
	EconomyManager.add_item(&"night_bloom", 1)
	QuestManager.refresh_objectives()
	EventBus.zone_entered.emit(&"dark_forest")
	t.check("quest_origin_eligible_saved", is_instance_valid(oak) and oak is Npc2D and PlayerRegistry.registered_id(t.player()) == &"p0" and _open_turnins() and saves.save_game(1), "actual GuardOak, shipped quests accepted in order, every after_others prerequisite met")
	var origin := PlayerRegistry.peek_state(&"p0")
	var first: Variant = QuestManager.active_quests[&"forest_patrol"]
	var entered: Array = []
	var winner: Dictionary = {}
	var observer := func(_pid, qid, oid, _current, _target):
		if qid != &"forest_patrol" or oid != &"return_to_oak" or not entered.is_empty(): return
		entered.append(true)
		entered.append(saves.load_game(1))
		entered.append(_open_turnins() and PlayerRegistry.peek_state(&"p0") != origin)
		winner.merge(Callback.new()._snapshot(saves))
	EventBus.quest_objective_updated.connect(observer)
	oak.interact(t.player())
	EventBus.quest_objective_updated.disconnect(observer)
	t.check("quest_origin_real_load_immediate", entered == [true, true, true], "genuine successful disk load before both turn-ins; %s" % [entered])
	t.check("quest_origin_winner_after_unwind", not winner.is_empty() and Callback.new()._snapshot(saves) == winner and _open_turnins(), "old conversation cannot advance next loaded quest or grant 350 gold/seeds/dust")
	t.check("quest_origin_first_commit_retained", first.objectives["return_to_oak"].current == 1 and first.objectives["return_to_oak"].done and origin != PlayerRegistry.peek_state(&"p0"), "already committed objective stays on origin, not erased or compensated")
	var screen: Node = t.tree.get_first_node_in_group("dialogue_ui")
	if screen != null: screen.close()
	var gold := EconomyManager.gold
	var seeds := EconomyManager.count_item(&"moonflower_seeds")
	var dust := EconomyManager.count_item(&"fairy_dust")
	EventBus.dialogue_started.emit(&"guard_oak", &"guard_oak")
	t.check("quest_origin_next_current_event_once", QuestManager.is_completed(&"forest_patrol") and QuestManager.is_completed(&"night_flower") and EconomyManager.gold == gold + 570 and EconomyManager.count_item(&"moonflower_seeds") == seeds + 5 and EconomyManager.count_item(&"fairy_dust") == dust + 1, "real current conversation completes both and gives exact authored rewards")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	await t.go_menu()

func _newgame(t, saves: Node) -> void:
	if not await t.start_world(): return
	saves.save_dir = "user://mp4-newgame-origin"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var world: Node = t.world()
	var entered: Array = []
	var winner: Dictionary = {}
	var callback := func(_pid, _skin):
		if not entered.is_empty(): return
		entered.append(true)
		var stamp: Array = saves._save_owner_stamp()
		var installed := PlayerRegistry.peek_state(&"p0")
		world.roster.reset()
		EconomyManager.gold = 991
		EconomyManager.add_item(&"stone", 23, true)
		entered.append(QuestManager.accept_quest(&"lost_cat"))
		entered.append(PlayerRegistry.peek_state(&"p0") != installed and saves._save_owner_stamp() == stamp)
		entered.append(EconomyManager.gold == 991 and EconomyManager.count_item(&"stone") == 23 and QuestManager.is_active(&"lost_cat"))
		winner.merge(Callback.new()._snapshot(saves))
	EventBus.player_character_changed.connect(callback)
	GameManager.start_new_game("OldPrefix", GameManager.CharacterType.ANIMAL)
	EventBus.player_character_changed.disconnect(callback)
	t.check("newgame_origin_roster_replaced_immediate", entered == [true, true, true, true], "live supported world.roster.reset changes profile without stamp and commits ordinary progress; %s" % [entered])
	t.check("newgame_origin_winner_after_unwind", not winner.is_empty() and Callback.new()._snapshot(saves) == winner and EconomyManager.gold == 991 and EconomyManager.count_item(&"stone") == 23 and QuestManager.is_active(&"lost_cat"), "obsolete prefix may not authorize reset relay on replacement")
	t.check("newgame_origin_future_progress", EconomyManager.add_item(&"stone", 1, true) and EconomyManager.count_item(&"stone") == 24 and saves.save_game(2) and saves.load_game(2) and not saves.network_admission_blocked())
	await t.go_menu()
