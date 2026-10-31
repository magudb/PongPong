extends RefCounted
const SECTION := "mother_quest_origins"
const TIMEOUT_S := 120.0
const Rollback := preload("res://tests/sections/multiplayer_rollback.gd")

func run(t) -> void:
	for seam in ["objective", "completion"]:
		for mode in ["normal", "direct", "same_direct", "failed", "incomplete"]:
			await _quest(t, seam, mode)
	await _recipient(t)
	await _labelled(t)

func _quest(t, seam: String, mode: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var qm: Node = t.autoload("QuestManager")
	var saves: Node = t.autoload("SaveManager")
	var director: Node = t.world().get_node("MotherStory")
	var late := Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("mother_quest_late", late, 1000)
	var quest := SecretGardenStory.QUEST if seam == "objective" else &"math_wizard_quiz"
	qm.accept_quest(quest)
	if seam == "completion":
		qm.complete_manual(quest, &"math_wiz_q1")
		qm.complete_manual(quest, &"math_wiz_q2")
	GameManager.set_flag(&"forest_mother_version", 1)
	var payload: Dictionary = saves.gather_payload()
	var gold := EconomyManager.gold
	var original := PlayerRegistry.peek_state(&"p0")
	var origin := EventBus.interaction_origin(&"p0")
	var observed: Array = []
	var barriers: Array = []
	late.callback = func():
		barriers.append(not EventBus.interaction_current(origin))
		barriers.append(not qm.accept_quest_owned(MotherStory.quest_id("s03"), origin))
	var notices: Array = []
	var accepted: Array = []
	var tag := seam + "_" + mode
	var on_accept := func(pid, id):
		if id == MotherStory.quest_id("s03"): accepted.append(pid)
	var replace := func():
		if mode == "normal" or not observed.is_empty(): return
		observed.append(true)
		if mode == "failed": late.rejects = 1
		if mode == "incomplete": late.rejects = 2
		var incoming: Dictionary = saves.gather_payload() if mode == "same_direct" else payload
		observed.append(saves._apply_payload(incoming).ok)
		observed.append(PlayerRegistry.peek_state(&"p0") == original)
		observed.append(qm.is_active(MotherStory.quest_id("s03")))
	var early_objective := func(_pid, id, _oid, _value, _target):
		if id == quest: replace.call()
	var later_objective := func(pid, id, _oid, _value, _target):
		if id == quest: notices.append(pid)
	var early_completed := func(_pid, id):
		if id == quest: replace.call()
	var later_completed := func(pid, id):
		if id == quest: notices.append(pid)
	EventBus.quest_accepted.connect(on_accept)
	if seam == "objective":
		EventBus.quest_objective_updated.disconnect(director._objective)
		EventBus.quest_objective_updated.connect(early_objective)
		EventBus.quest_objective_updated.connect(director._objective)
		EventBus.quest_objective_updated.connect(later_objective)
	else:
		EventBus.quest_completed.disconnect(director._quest)
		EventBus.quest_completed.connect(early_completed)
		EventBus.quest_completed.connect(director._quest)
		EventBus.quest_completed.connect(later_completed)
	t.check(tag + "_real_eligible_unprojected", saves.validate_payload(payload).ok and MotherStory.enabled() and not qm.is_active(MotherStory.quest_id("s03")) and qm.can_complete_manual(quest, &"clear_path" if seam == "objective" else &"math_wiz_q3"))
	if seam == "objective": SecretGardenStory.advance(0)
	else: qm.complete_manual(quest, &"math_wiz_q3")
	if seam == "objective":
		EventBus.quest_objective_updated.disconnect(early_objective)
		EventBus.quest_objective_updated.disconnect(later_objective)
	else:
		EventBus.quest_completed.disconnect(early_completed)
		EventBus.quest_completed.disconnect(later_completed)
	t.check(tag + "_later_public_observer_once", notices == [&"p0"])
	if mode in ["direct", "same_direct", "incomplete"]:
		t.check(tag + "_real_replacement_before_director", observed.size() == 4 and observed[1] == (mode != "incomplete") and observed[3] == false and not EventBus.interaction_current(origin))
		t.check(tag + "_old_notification_cannot_project_winner", not qm.is_active(MotherStory.quest_id("s03")) and accepted.is_empty())
		if mode == "incomplete":
			late.rejects = 0
			late.callback = Callable()
			t.check(tag + "_new_valid_replacement", saves._apply_payload(payload).ok)
		MotherStory.sync()
	else:
		t.check(tag + "_normal_or_complete_rollback", observed.is_empty() if mode == "normal" else observed == [true, false, true, false] and late.calls == 2 and EventBus.interaction_current(origin))
		if mode == "failed": t.check(tag + "_all_decoder_barriers_then_released", barriers == [true, true, true, true] and EventBus.interaction_current(origin))
		if seam == "completion": t.check(tag + "_earned_rewards_and_lua_once", qm.is_completed(quest) and EconomyManager.gold == gold + 120 and EconomyManager.count_item(&"magic_scroll") == 1 and EconomyManager.count_item(&"fairy_dust") == 5 and GameManager.get_flag(&"math_quiz_done", false) == true and qm.pending_rewards.is_empty())
		else: t.check(tag + "_earned_manual_prefix_once", SecretGardenStory.step() == 1)
	t.check(tag + "_current_root_projects_once", qm.is_active(MotherStory.quest_id("s03")) and accepted == [&"p0"])
	MotherStory.sync()
	t.check(tag + "_stable_idempotent", accepted == [&"p0"])
	EventBus.quest_accepted.disconnect(on_accept)
	saves.unregister_section("mother_quest_late")
	late.free()
	await t.go_menu()

func _recipient(t) -> void:
	if not await t.start_world(): return
	var world: Node = t.world()
	var body: Node2D = world._make_player()
	world._register_player(body, 1, 2)
	world.add_child(body)
	body.enter_area(world.area, t.player().global_position + Vector2(20, 0))
	var p0 := PlayerRegistry.peek_state(&"p0")
	var p1 := PlayerRegistry.peek_state(&"p1")
	var original := p0.to_dict().duplicate(true)
	var origin := EventBus.interaction_origin(&"p1")
	var qm: Node = t.autoload("QuestManager")
	var notices: Array = []
	var listener := func(pid, id):
		if id == &"math_wizard_quiz" or id == MotherStory.quest_id("s03"): notices.append([pid, id])
	EventBus.quest_accepted.connect(listener)
	t.check("p1_owned_accept_conflicting_p0", PlayerRegistry.acting_id() == &"p0" and PlayerRegistry.registered_id(body) == &"p1" and qm.accept_quest_owned(&"math_wizard_quiz", origin))
	qm.complete_manual_owned(&"math_wizard_quiz", &"math_wiz_q1", {}, false, origin)
	qm.update_objective_owned(&"math_wizard_quiz", &"math_wiz_q2", 1, origin)
	GameManager.set_flag(&"forest_mother_version", 1)
	var before: int = PlayerRegistry.for_player(&"p1", func(): return EconomyManager.gold)
	NpcDialogue.action_owned("fairy_wizard", "quest_update", {"quest_id":"math_wizard_quiz", "objective_id":"math_wiz_q3"}, false, origin)
	qm.refresh_objectives_owned(origin)
	t.check("p1_manual_npc_completion_projection_and_rewards", PlayerRegistry.for_player(&"p1", func(): return qm.is_completed(&"math_wizard_quiz") and qm.is_active(MotherStory.quest_id("s03")) and EconomyManager.gold == before + 120 and EconomyManager.count_item(&"magic_scroll") == 1))
	t.check("p1_labelled_identity_and_caller_restored", notices == [[&"p1", &"math_wizard_quiz"], [&"p1", MotherStory.quest_id("s03")]] and PlayerRegistry.acting_id() == &"p0" and PlayerRegistry.peek_state(&"p1") == p1)
	t.check("p1_unrelated_p0_exactly_unchanged", PlayerRegistry.peek_state(&"p0") == p0 and p0.to_dict() == original)
	EventBus.quest_accepted.disconnect(listener)
	await t.go_menu()

func _labelled(t) -> void:
	if not await t.start_world(): return
	var director: Node = t.world().get_node("MotherStory")
	QuestManager.accept_quest(SecretGardenStory.QUEST)
	GameManager.set_flag(&"forest_mother_version", 1)
	var saves: Node = t.autoload("SaveManager")
	var payload: Dictionary = saves.gather_payload()
	var observed: Array = []
	var public: Array = []
	var later: Array = []
	var first := func(origin):
		if not observed.is_empty(): return
		observed.append(EventBus.interaction_current(origin))
		observed.append(public == [&"p0"])
		observed.append(saves._apply_payload(payload).ok)
		observed.append(EventBus.interaction_current(origin))
	var last := func(origin): later.append(EventBus.interaction_current(origin))
	var notice := func(pid, id, _oid, _value, _target):
		if id == SecretGardenStory.QUEST: public.append(pid)
	EventBus.mother_progressed.disconnect(director._progress_owned)
	EventBus.mother_progressed.connect(first)
	EventBus.mother_progressed.connect(director._progress_owned)
	EventBus.mother_progressed.connect(last)
	EventBus.quest_objective_updated.connect(notice)
	SecretGardenStory.advance(0)
	EventBus.quest_objective_updated.disconnect(notice)
	EventBus.mother_progressed.disconnect(first)
	EventBus.mother_progressed.disconnect(last)
	t.check("first_labelled_actual_replacement_public_first", observed == [true, true, true, false] and public == [&"p0"] and later == [false])
	t.check("later_same_labelled_director_refuses_winner", not QuestManager.is_active(MotherStory.quest_id("s03")))
	SecretGardenStory.advance(0)
	t.check("labelled_next_current_root_once", SecretGardenStory.step() == 1 and QuestManager.is_active(MotherStory.quest_id("s03")))
	await t.go_menu()
