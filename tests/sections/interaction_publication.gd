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
	var later_public: Array = []
	var later_observer := func(npc, _dialogue):
		if npc == &"smith_thorin": later_public.append(not entered.is_empty())
	EventBus.dialogue_started.connect(observer)
	EventBus.dialogue_started.connect(later_observer)
	smith.interact(t.player())
	EventBus.dialogue_started.disconnect(later_observer)
	EventBus.dialogue_started.disconnect(observer)
	t.check("already_emitted_public_fanout_once", later_public == [true], "successful first observer load must not suppress later public notification")
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
	await _meeting(t)
	await _home(t)
	await _service(t)
	await _intro(t)
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	for kind: String in ["same_direct", "same_disk", "same_backup", "model_replace", "failed_direct", "failed_disk", "failed_backup", "incomplete"]:
		await _continuation(t, saves, kind)

## Real shipped ordinary turn-ins feed the first labelled Quest mutator; Home
## is a later real subscriber of that SAME emission. No disconnect/reorder seam.
func _continuation(t, saves: Node, kind: String) -> void:
	if not await t.start_world(): return
	saves.save_dir = "user://publication-" + kind
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("publication_late", late, 1000)
	QuestManager.accept_quest(&"forest_patrol")
	QuestManager.accept_quest(&"night_flower")
	EconomyManager.add_item(&"moss", 6)
	EconomyManager.add_item(&"night_bloom", 1)
	QuestManager.refresh_objectives()
	EventBus.zone_entered.emit(&"dark_forest")
	var payload: Dictionary = saves.gather_payload()
	var ready: bool = preload("res://tests/sections/multiplayer_progression_origin.gd").new()._open_turnins()
	if kind == "failed_backup": late.value = 8
	var disk: bool = saves.save_game(0)
	if kind == "failed_backup": late.value = 9
	if kind.ends_with("backup"): disk = saves.save_game(0) and disk
	late.value = 7
	t.check(kind + "_healthy_eligible", ready and disk and saves.validate_payload(payload).ok)
	var original := EventBus.interaction_origin()
	var attachment := RefCounted.new()
	var profile := PlayerRegistry.peek_state(&"p0")
	var first: Variant = QuestManager.active_quests[&"forest_patrol"]
	var gold := EconomyManager.gold
	var entered: Array = []
	var barriers: Array = []
	var winner: Dictionary = {}
	var home_at_return: Array = []
	var apply_details: Array = []
	var replace := func():
		if not entered.is_empty(): return
		entered.append(true)
		if kind.begins_with("failed"): late.rejects = 1
		if kind == "failed_backup":
			late.rejects = 0
			late.reject_values = [9, 8]
		if kind == "incomplete": late.rejects = 2
		var ok: bool
		if kind in ["same_direct", "model_replace", "failed_direct", "incomplete"]:
			var applied: Dictionary = saves._apply_payload(payload)
			ok = applied.ok
			apply_details.append(str(applied.get("detail", "")))
		else: ok = saves.load_game(0)
		entered.append(ok)
		entered.append(PlayerRegistry.peek_state(&"p0") == profile)
		entered.append(EventBus.interaction_current(original))
		winner.merge(Callback.new()._snapshot(saves))
		home_at_return.append(HomeManager._dialogue_attachment)
	# Probe the retained origin only AFTER rollback decoder restoration, while
	# the enclosing disk facade still owns backup validation/final observers.
	late.validation_callback = func():
		if late.calls != 2 or kind != "failed_backup" or not barriers.is_empty(): return
		var before := Callback.new()._snapshot(saves)
		var before_home: Variant = HomeManager._dialogue_attachment
		barriers.append(not EventBus.interaction_current(original))
		barriers.append(not EventBus.publish_dialogue_started(original, &"guard_oak", &"guard_oak", attachment))
		barriers.append(before == Callback.new()._snapshot(saves) and before_home == HomeManager._dialogue_attachment)
	var final_observer := func(_title, _message, icon):
		if icon != "save" or kind not in ["failed_disk", "failed_backup"]: return
		var before := Callback.new()._snapshot(saves)
		barriers.append(not EventBus.interaction_current(original))
		barriers.append(not EventBus.publish_dialogue_started(original, &"guard_oak", &"guard_oak", attachment))
		barriers.append(before == Callback.new()._snapshot(saves))
	var public_observer := func(npc, _dialogue):
		if npc == &"guard_oak" and kind.begins_with("same_"): replace.call()
	var model_observer := func(_pid, qid, oid, _current, _target):
		if qid == &"forest_patrol" and oid == &"return_to_oak" and not kind.begins_with("same_"): replace.call()
	if kind == "same_backup":
		var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
		file.store_string("{invalid-json")
		file.close()
	EventBus.notification_posted.connect(final_observer)
	EventBus.dialogue_started.connect(public_observer)
	EventBus.quest_objective_updated.connect(model_observer)
	var completed := EventBus.publish_dialogue_started(original, &"guard_oak", &"guard_oak", attachment)
	EventBus.quest_objective_updated.disconnect(model_observer)
	EventBus.dialogue_started.disconnect(public_observer)
	EventBus.notification_posted.disconnect(final_observer)
	late.validation_callback = Callable()
	if kind.begins_with("failed"):
		t.check(kind + "_certified_restoration", entered == [true, false, true, true] and completed and late.calls == (4 if kind == "failed_backup" else 2) and not str(saves.last_error).contains("incomplete"), "%s calls=%s error=%s" % [entered, late.calls, saves.last_error])
		t.check(kind + "_earned_remaining_effects", QuestManager.is_completed(&"forest_patrol") and QuestManager.is_completed(&"night_flower") and EconomyManager.gold == gold + 570 and EconomyManager.count_item(&"moonflower_seeds") == 5 and EconomyManager.count_item(&"fairy_dust") == 1 and HomeManager._dialogue_attachment == attachment)
		if kind != "failed_direct":
			t.check(kind + "_barrier_until_facade_unwind", barriers.size() == (6 if kind == "failed_backup" else 3) and not barriers.has(false), "temporary denial must not borrow/rebind or latch; %s" % [barriers])
		EventBus.start_dialogue(&"guard_oak", &"guard_oak")
		t.check(kind + "_next_root_once", EconomyManager.gold == gold + 570 and EconomyManager.count_item(&"moonflower_seeds") == 5 and saves.save_game(2))
	else:
		var incomplete := kind == "incomplete"
		t.check(kind + "_revoked", entered.size() == 4 and entered[1] == not incomplete and not entered[3] and not completed and (apply_details.size() == 1 and apply_details[0].contains("incomplete") if incomplete else not entered[2]), "%s %s" % [entered, saves.last_error])
		t.check(kind + "_same_signal_later_mutator_refused", not winner.is_empty() and Callback.new()._snapshot(saves) == winner and home_at_return.size() == 1 and HomeManager._dialogue_attachment == home_at_return[0], "Home cannot capture a winner attachment from an old labelled emission")
		if not kind.begins_with("same_"):
			t.check(kind + "_first_committed_origin", first.objectives["return_to_oak"].done, "already-earned old objective is not erased/compensated")
		if incomplete:
			late.rejects = 0
			t.check("incomplete_next_valid_replacement", saves._apply_payload(payload).ok)
		EventBus.start_dialogue(&"guard_oak", &"guard_oak")
		t.check(kind + "_next_independent_root_progress_once", QuestManager.is_completed(&"forest_patrol") and QuestManager.is_completed(&"night_flower") and EconomyManager.gold == gold + 570 and EconomyManager.count_item(&"moonflower_seeds") == 5 and EconomyManager.count_item(&"fairy_dust") == 1)
		EventBus.start_dialogue(&"guard_oak", &"guard_oak")
		t.check(kind + "_no_replay_released", EconomyManager.gold == gold + 570 and saves.save_game(2) and not saves.network_admission_blocked())
	saves.unregister_section("publication_late")
	late.free()
	await t.go_menu()

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

func _meeting(t) -> void:
	if not await t.start_world(): return
	GameManager.set_clock(10, 0)
	TimeManager.set_weather(&"klart")
	await t.world().travel(&"int_smedjen", &"default")
	NpcDirector.resync("smith_thorin")
	await t.until(func(): return NpcDirector.node_of("smith_thorin") != null, 10)
	var smith: Node = NpcDirector.node_of("smith_thorin")
	if not t.expect(smith is Npc2D, "physical fanout uses shipped Smith"): return
	QuestManager.accept_quest(&"dark_forest_mining")
	EconomyManager.add_item(&"iron_ore", 6)
	EconomyManager.add_item(&"amethyst", 2)
	QuestManager.refresh_objectives()
	EventBus.zone_entered.emit(&"dark_forest")
	var rt: Dictionary = QuestManager.get_quest_progress(&"dark_forest_mining")
	var ready: bool = QuestManager.is_active(&"dark_forest_mining") and not rt.objectives.return_to_smith.done
	for key in rt.objectives:
		if key != "return_to_smith": ready = ready and rt.objectives[key].done
	var saves: Node = t.autoload("SaveManager")
	var payload: Dictionary = saves.gather_payload()
	t.check("meeting_eligible_before_public", ready and saves.validate_payload(payload).ok and PlayerRegistry.registered_id(t.player()) == &"p0")
	var entered: Array = []
	var later: Array = []
	var winner: Dictionary = {}
	var observer := func(actor):
		if actor != smith or not entered.is_empty(): return
		entered.append(saves._apply_payload(payload).ok)
		winner.merge(Callback.new()._snapshot(saves))
	var later_observer := func(actor):
		if actor == smith: later.append(entered == [true])
	EventBus.npc_meeting_started.connect(observer)
	EventBus.npc_meeting_started.connect(later_observer)
	smith.interact(t.player())
	EventBus.npc_meeting_started.disconnect(later_observer)
	EventBus.npc_meeting_started.disconnect(observer)
	t.check("meeting_public_observers_once", entered == [true] and later == [true])
	t.check("meeting_public_replacement_refuses_costs", not winner.is_empty() and Callback.new()._snapshot(saves) == winner and QuestManager.is_active(&"dark_forest_mining") and EconomyManager.count_item(&"iron_ore") == 6 and EconomyManager.count_item(&"amethyst") == 2)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	t.check("meeting_superseded_no_page", not ui.is_open() and not smith.is_talking)
	var gold := EconomyManager.gold
	var reward := int(QuestManager.get_quest_def(&"dark_forest_mining").get("rewards", {}).get("gold", 0))
	smith.interact(t.player())
	t.check("meeting_next_real_root_progress", reward > 0 and QuestManager.is_completed(&"dark_forest_mining") and EconomyManager.count_item(&"iron_ore") == 0 and EconomyManager.count_item(&"amethyst") == 0 and EconomyManager.gold == gold + reward)
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
	GameManager.set_flag(GameManager.FLAG_HOME_UPGRADE_DONE, 5)
	var ending := EventBus.start_dialogue(&"fairy_builder", &"fairy_builder")
	var saves: Node = t.autoload("SaveManager")
	var payload: Dictionary = saves.gather_payload()
	var first: Array = []
	var later: Array = []
	var observer := func():
		if first.is_empty(): first.append(saves._apply_payload(payload).ok)
	var later_observer := func(): later.append(first == [true])
	EventBus.dialogue_ended.connect(observer)
	EventBus.dialogue_ended.connect(later_observer)
	EventBus.end_dialogue(ending)
	EventBus.dialogue_ended.disconnect(later_observer)
	EventBus.dialogue_ended.disconnect(observer)
	t.check("terminal_public_fanout_once", first == [true] and later == [true])
	t.check("terminal_stale_end_no_winner_clear", GameManager.flag_int(GameManager.FLAG_HOME_UPGRADE_DONE) == 5)
	var next := EventBus.start_dialogue(&"fairy_builder", &"fairy_builder")
	EventBus.end_dialogue(next)
	t.check("terminal_next_root_normal", GameManager.flag_int(GameManager.FLAG_HOME_UPGRADE_DONE) == 0)
	await t.go_menu()
