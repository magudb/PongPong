extends RefCounted
const SECTION := "mother_quest_origins"
const TIMEOUT_S := 120.0
const Rollback := preload("res://tests/sections/multiplayer_rollback.gd")

func run(t) -> void:
	for seam in ["objective", "completion"]:
		for mode in ["normal", "direct", "failed"]:
			await _quest(t, seam, mode)

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
	var original := PlayerRegistry.peek_state(&"p0")
	var origin := EventBus.interaction_origin(&"p0")
	var observed: Array = []
	var notices: Array = []
	var accepted: Array = []
	var tag := seam + "_" + mode
	var on_accept := func(pid, id):
		if id == MotherStory.quest_id("s03"): accepted.append(pid)
	var replace := func():
		if mode == "normal" or not observed.is_empty(): return
		observed.append(true)
		if mode == "failed": late.rejects = 1
		observed.append(saves._apply_payload(payload).ok)
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
	if mode == "direct":
		t.check(tag + "_real_replacement_before_director", observed == [true, true, false, false] and not EventBus.interaction_current(origin))
		t.check(tag + "_old_notification_cannot_project_winner", not qm.is_active(MotherStory.quest_id("s03")) and accepted.is_empty())
		MotherStory.sync()
	else:
		t.check(tag + "_normal_or_complete_rollback", observed.is_empty() if mode == "normal" else observed == [true, false, true, false] and late.calls == 2 and EventBus.interaction_current(origin))
	t.check(tag + "_current_root_projects_once", qm.is_active(MotherStory.quest_id("s03")) and accepted == [&"p0"])
	MotherStory.sync()
	t.check(tag + "_stable_idempotent", accepted == [&"p0"])
	EventBus.quest_accepted.disconnect(on_accept)
	saves.unregister_section("mother_quest_late")
	late.free()
	await t.go_menu()
