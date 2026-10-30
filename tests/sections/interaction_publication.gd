extends RefCounted
const SECTION := "interaction_publication"
const TIMEOUT_S := 120.0
const Callback := preload("res://tests/sections/multiplayer_callback_ownership.gd")

func _open() -> bool:
	for id: StringName in [&"sword_upgrade", &"dark_forest_mining"]:
		if not QuestManager.is_active(id) or QuestManager.is_completed(id): return false
		var rt: Dictionary = QuestManager.get_quest_progress(id)
		var turn := "deliver_to_smith" if id == &"sword_upgrade" else "return_to_smith"
		if rt.objectives[turn].current != 0: return false
		for oid in rt.objectives:
			if oid != turn and not rt.objectives[oid].done: return false
	return true

func run(t) -> void:
	if not await t.start_world(): return
	var saves: Node = t.autoload("SaveManager")
	GameManager.set_clock(10, 0)
	TimeManager.set_weather(&"klart")
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	await t.world().travel(&"int_smedjen", &"default")
	NpcDirector.resync("smith_thorin")
	await t.until(func(): return NpcDirector.node_of("smith_thorin") != null, 10)
	var smith: Node = NpcDirector.node_of("smith_thorin")
	if not t.expect(smith is Npc2D, "installed shipped Smith at authored opening hour"): return
	QuestManager.accept_quest(&"sword_upgrade")
	QuestManager.accept_quest(&"dark_forest_mining")
	for pair in [[&"iron_ingot", 3], [&"fairy_dust", 1], [&"iron_ore", 6], [&"amethyst", 2]]:
		EconomyManager.add_item(pair[0], pair[1])
	QuestManager.refresh_objectives()
	EventBus.zone_entered.emit(&"dark_forest")
	var payload: Dictionary = saves.gather_payload()
	# A genuine healthy direct apply, not an invented decoder/fixture replacement.
	t.check("smith_eligible", _open() and saves.validate_payload(payload).ok and PlayerRegistry.registered_id(t.player()) == &"p0")
	var origin := PlayerRegistry.peek_state(&"p0")
	var first: Variant = QuestManager.active_quests[&"sword_upgrade"]
	var entered: Array = []
	var winner: Dictionary = {}
	var observer := func(npc, _dialogue):
		if npc != &"smith_thorin" or not entered.is_empty(): return
		t.check("public_before_model_effects", _open(), "public observers see eligible ordinary and physical quests BEFORE any labelled mutation")
		entered.append(bool(saves._apply_payload(payload).get("ok", false)))
		entered.append(PlayerRegistry.peek_state(&"p0") != origin and _open())
		winner.merge(Callback.new()._snapshot(saves))
	EventBus.dialogue_started.connect(observer)
	smith.interact(t.player())
	EventBus.dialogue_started.disconnect(observer)
	t.check("smith_actual_apply_immediate", entered == [true, true], "healthy distinguishable winner immediately installed; %s" % [entered])
	t.check("smith_whole_event_pair", not winner.is_empty() and Callback.new()._snapshot(saves) == winner and _open(), "obsolete physical second event must not deduct winner ore/amethyst or reward")
	t.check("smith_committed_origin", not first.objectives["deliver_to_smith"].done and origin != PlayerRegistry.peek_state(&"p0"), "public supersession prevents even first labelled effect")
	var immediate_ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	t.check("superseded_start_does_not_present_page", immediate_ui != null and not immediate_ui.is_open() and (not is_instance_valid(smith) or not smith.is_talking))
	await t.frames(3)
	var after := Callback.new()._snapshot(saves)
	var delta: Dictionary = {}
	for key in winner:
		if winner[key] != after[key]: delta[key] = [winner[key], after[key]]
	t.check("smith_deferred_unwind", after == winner and _open(), "no stale deferred progression; delta=%s" % [delta])
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	if ui != null: ui.close()
	await t.go_menu()
	await _home(t)
	await _service(t)
	await _intro(t)

func _intro(t) -> void:
	if not await t.start_world(): return
	GameManager.clear_flag(&"intro_letter_seen")
	var saves: Node = t.autoload("SaveManager")
	var payload: Dictionary = saves.gather_payload()
	var applied: Array = []
	var observer := func(npc, _dialogue):
		if npc == &"fairy_king" and applied.is_empty(): applied.append(saves._apply_payload(payload).ok)
	EventBus.dialogue_started.connect(observer)
	preload("res://scripts/world2d/intro_sequence.gd").letter(t.world())
	EventBus.dialogue_started.disconnect(observer)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	t.check("intro_public_supersession_before_ui", applied == [true] and not ui.is_open())
	ui.close()
	t.check("intro_supersession_no_seen_flag", not bool(GameManager.get_flag(&"intro_letter_seen", false)))
	await t.go_menu()

func _service_result(world: Node, results: Array) -> void:
	results.append(await LifeFlow.ask(world, "smith_thorin", [{"text_key": "DLG_NEUTRAL"}], []))

func _service(t) -> void:
	if not await t.start_world(): return
	var saves: Node = t.autoload("SaveManager")
	var payload: Dictionary = saves.gather_payload()
	var applied: Array = []
	var results: Array = []
	var observer := func(npc, _dialogue):
		if npc == &"smith_thorin" and applied.is_empty(): applied.append(saves._apply_payload(payload).ok)
	EventBus.dialogue_started.connect(observer)
	_service_result(t.world(), results)
	EventBus.dialogue_started.disconnect(observer)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	t.check("service_public_supersession_before_ui", applied == [true] and not ui.is_open() and results.size() == 1)
	ui.close()
	await t.go_menu()

func _home(t) -> void:
	if not await t.start_world(): return
	GameManager.set_flag(GameManager.FLAG_HOME_UPGRADE_DONE, 3)
	var old := EventBus.start_dialogue(&"fairy_builder", &"fairy_builder")
	var current := EventBus.start_dialogue(&"fairy_builder", &"fairy_builder")
	EventBus.end_dialogue(old)
	t.check("home_old_end_cannot_clear_current", GameManager.flag_int(GameManager.FLAG_HOME_UPGRADE_DONE) == 3)
	EventBus.dialogue_ended.emit()
	t.check("home_raw_end_notification_only", GameManager.flag_int(GameManager.FLAG_HOME_UPGRADE_DONE) == 3)
	EventBus.end_dialogue(current)
	t.check("home_current_end_preserved", GameManager.flag_int(GameManager.FLAG_HOME_UPGRADE_DONE) == 0)
	GameManager.set_flag(GameManager.FLAG_HOME_UPGRADE_DONE, 4)
	var cancel := EventBus.start_dialogue(&"fairy_builder", &"fairy_builder")
	EventBus.end_dialogue(cancel)
	t.check("home_current_cancel_preserved", GameManager.flag_int(GameManager.FLAG_HOME_UPGRADE_DONE) == 0, "terminal ownership does not introduce a read-only completion requirement")
	await t.go_menu()
