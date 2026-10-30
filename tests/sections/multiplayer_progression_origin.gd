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
	var selected := OS.get_environment("MP4_ORIGIN_CASE")
	for kind: String in ["load", "same", "failed", "normal"]:
		if selected != "" and selected != "all" and selected != kind: continue
		await _quest(t, saves, kind)
	for kind: String in ["character", "modal", "welcome", "intro", "dropped"]:
		if selected != "" and selected != "all" and selected != "newgame" and selected != kind: continue
		await _newgame(t, saves, kind)

func _close(t) -> void:
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	if ui != null: ui.close()
	await t.go_menu()

func _quest(t, saves: Node, kind: String) -> void:
	if not await t.start_world(): return
	saves.save_dir = "user://mp4-progression-origin-" + kind
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	GameManager.set_clock(10, 0)
	TimeManager.set_weather(&"klart")
	await t.world().travel(&"traetoppen", &"default")
	NpcDirector.resync("guard_oak")
	await t.until(func(): return NpcDirector.node_of("guard_oak") != null, 10)
	var oak: Node = NpcDirector.node_of("guard_oak")
	if not t.expect(oak != null, kind + " installed GuardOak is present at authored guard hour"): return
	QuestManager.accept_quest(&"forest_patrol")
	QuestManager.accept_quest(&"night_flower")
	EconomyManager.add_item(&"moss", 6)
	EconomyManager.add_item(&"night_bloom", 1)
	QuestManager.refresh_objectives()
	EventBus.zone_entered.emit(&"dark_forest")
	t.check("quest_" + kind + "_eligible_saved", is_instance_valid(oak) and oak is Npc2D and PlayerRegistry.registered_id(t.player()) == &"p0" and _open_turnins() and saves.save_game(0 if kind == "failed" else 1), "actual GuardOak, shipped quests accepted in order, every after_others prerequisite met")
	var origin := PlayerRegistry.peek_state(&"p0")
	var first: Variant = QuestManager.active_quests[&"forest_patrol"]
	var entered: Array = []
	var winner: Dictionary = {}
	var late := Callback.Rollback.LateSection.new()
	if kind == "failed":
		t.tree.root.add_child(late)
		saves.register_section("mp4_origin_late", late, 1000)
		t.check("quest_failed_disk_saved", saves.save_game(1))
	var gold_before := EconomyManager.gold
	var observer := func(_pid, qid, oid, _current, _target):
		if qid != &"forest_patrol" or oid != &"return_to_oak" or not entered.is_empty(): return
		entered.append(true)
		if kind == "same": entered.append(saves.save_game(2))
		if kind == "failed": late.rejects = 1
		entered.append(saves.load_game(2 if kind == "same" else 1))
		entered.append((_open_turnins() if kind == "load" else first.objectives["return_to_oak"].done) and (PlayerRegistry.peek_state(&"p0") == origin if kind == "failed" else PlayerRegistry.peek_state(&"p0") != origin))
		winner.merge(Callback.new()._snapshot(saves))
	if kind != "normal": EventBus.quest_objective_updated.connect(observer)
	oak.interact(t.player())
	if kind != "normal": EventBus.quest_objective_updated.disconnect(observer)
	if kind in ["normal", "failed"]:
		if kind == "failed":
			t.check("quest_failed_authenticated_identity", entered == [true, false, true] and late.calls == 2 and not str(saves.last_error).contains("incomplete"), "%s %s" % [entered, saves.last_error])
		t.check("quest_" + kind + "_both_earned", QuestManager.is_completed(&"forest_patrol") and QuestManager.is_completed(&"night_flower") and EconomyManager.gold == gold_before + 570 and EconomyManager.count_item(&"moonflower_seeds") == 5 and EconomyManager.count_item(&"fairy_dust") == 1, "complete event continues both authored turn-ins and exact rewards")
		var paid := EconomyManager.gold
		EventBus.start_dialogue(&"guard_oak", &"guard_oak")
		t.check("quest_" + kind + "_no_replay", EconomyManager.gold == paid and saves.save_game(3))
		if kind == "failed": saves.unregister_section("mp4_origin_late")
		late.free()
		await _close(t)
		return
	late.free()
	if kind == "same":
		t.check("quest_same_success_identical_values", entered == [true, true, true, true] and not winner.is_empty() and Callback.new()._snapshot(saves) == winner and QuestManager.is_active(&"forest_patrol") and QuestManager.is_active(&"night_flower") and EconomyManager.gold == gold_before, "successful same-valued disk replacement revokes objective-completion and sibling suffix")
		QuestManager.complete_quest(&"forest_patrol")
		EventBus.start_dialogue(&"guard_oak", &"guard_oak")
		t.check("quest_same_current_progress_once", QuestManager.is_completed(&"forest_patrol") and QuestManager.is_completed(&"night_flower") and EconomyManager.gold == gold_before + 570 and EconomyManager.count_item(&"moonflower_seeds") == 5)
		await _close(t)
		return
	t.check("quest_origin_real_load_immediate", entered == [true, true, true], "genuine successful disk load before both turn-ins; %s" % [entered])
	t.check("quest_origin_winner_after_unwind", not winner.is_empty() and Callback.new()._snapshot(saves) == winner and _open_turnins(), "old conversation cannot advance next loaded quest or grant 350 gold/seeds/dust")
	t.check("quest_origin_first_commit_retained", first.objectives["return_to_oak"].current == 1 and first.objectives["return_to_oak"].done and origin != PlayerRegistry.peek_state(&"p0"), "already committed objective stays on origin, not erased or compensated")
	var gold := EconomyManager.gold
	var seeds := EconomyManager.count_item(&"moonflower_seeds")
	var dust := EconomyManager.count_item(&"fairy_dust")
	EventBus.start_dialogue(&"guard_oak", &"guard_oak")
	t.check("quest_origin_next_current_event_once", QuestManager.is_completed(&"forest_patrol") and QuestManager.is_completed(&"night_flower") and EconomyManager.gold == gold + 570 and EconomyManager.count_item(&"moonflower_seeds") == seeds + 5 and EconomyManager.count_item(&"fairy_dust") == dust + 1, "current event completes both and gives exact authored rewards")
	await _close(t)

func _newgame(t, saves: Node, kind: String) -> void:
	if not await t.start_world(): return
	saves.save_dir = "user://mp4-newgame-origin-" + kind
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var world: Node = t.world()
	var entered: Array = []
	var winner: Dictionary = {}
	GameManager.set_flag(&"mp4_origin_dropped", true)
	if kind == "modal": GameManager.push_modal(&"mp4_prefix")
	var replace := func():
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
	var character := func(_pid, _skin):
		if kind == "character": replace.call()
	var modal := func(stack):
		if kind == "modal" and stack.is_empty(): replace.call()
	var flag := func(key, value):
		if (kind == "welcome" and key == &"mayor_welcome_pending" and value == true) or (kind == "intro" and key == GameManager.FLAG_INTRO_PENDING and value == true) or (kind == "dropped" and key == &"mp4_origin_dropped" and value == false): replace.call()
	EventBus.player_character_changed.connect(character)
	EventBus.modal_changed.connect(modal)
	EventBus.flag_changed.connect(flag)
	GameManager.start_new_game("OldPrefix", GameManager.CharacterType.ANIMAL)
	EventBus.flag_changed.disconnect(flag)
	EventBus.modal_changed.disconnect(modal)
	EventBus.player_character_changed.disconnect(character)
	t.check("newgame_origin_roster_replaced_immediate_" + kind, entered == [true, true, true, true], "live supported world.roster.reset changes profile without stamp and commits ordinary progress; %s" % [entered])
	t.check("newgame_origin_winner_after_unwind_" + kind, not winner.is_empty() and Callback.new()._snapshot(saves) == winner and EconomyManager.gold == 991 and EconomyManager.count_item(&"stone") == 23 and QuestManager.is_active(&"lost_cat"), "obsolete prefix may not authorize reset relay on replacement")
	t.check("newgame_origin_future_progress_" + kind, EconomyManager.add_item(&"stone", 1, true) and EconomyManager.count_item(&"stone") == 24 and saves.save_game(2) and saves.load_game(2) and not saves.network_admission_blocked())
	await t.go_menu()
