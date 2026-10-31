extends RefCounted
const SECTION := "ghostfam_continuations"
const TIMEOUT_S := 180.0
const LOST := &"ghostfam_hittegods"
const Rollback := preload("res://tests/sections/multiplayer_rollback.gd")
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func run(t) -> void:
	for mode in ["normal", "direct", "failed", "incomplete"]:
		await _gift(t, mode)
	await _flush(t)

func _freeze(t) -> void:
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))

func _gift(t, mode: String) -> void:
	if not await t.start_world(): return
	_freeze(t)
	GameManager.set_flag(&"ghostfam_kin_silke", true)
	SocialManager.debug_set_hearts("ghostfam_silke", 4)
	var saves: Node = t.autoload("SaveManager")
	var late := Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("ghostfam_late", late, 1000)
	t.check(mode + "_gift_real_accept", QuestManager.accept_quest(LOST))
	var rt: QuestManager.QuestRuntime = QuestManager.active_quests[LOST]
	var owner := str(rt.meta.lost_owner)
	var item := str(rt.meta.lost_item)
	var points := SocialManager.points(owner)
	var gold := EconomyManager.gold
	var winner: Dictionary = saves.gather_payload()
	var origin := EventBus.interaction_origin(&"p0")
	var family: Node = SocialManager.get_node("FamilyQuests")
	var observed: Array = []
	var notices: Array = []
	var barriers: Array = []
	late.callback = func(): barriers.append(not EventBus.interaction_current(origin))
	var early := func(id, _payload):
		if id != &"gift_given" or mode == "normal" or not observed.is_empty(): return
		observed.append(true)
		late.rejects = 1 if mode == "failed" else (2 if mode == "incomplete" else 0)
		observed.append(saves._apply_payload(winner).ok)
		observed.append(saves.gather_payload())
	var later := func(id, _payload):
		if id == &"gift_given": notices.append(true)
	EventBus.game_event.disconnect(family._event)
	EventBus.game_event.connect(early)
	EventBus.game_event.connect(family._event)
	EventBus.game_event.connect(later)
	var gift := GiftFlow.give_gift(owner, item)
	EventBus.game_event.disconnect(early)
	EventBus.game_event.disconnect(later)
	t.check(mode + "_gift_public_once_and_committed_return", bool(gift.ok) and notices == [true])
	if mode in ["direct", "incomplete"]:
		t.check(mode + "_gift_actual_replacement", observed.size() == 3 and observed[1] == (mode == "direct") and not EventBus.interaction_current(origin))
		t.check(mode + "_gift_no_old_completion_on_winner", not QuestManager.is_completed(LOST) and Compare.new()._same_payload(observed[2], saves.gather_payload()))
	else:
		t.check(mode + "_gift_earned_exact_once", QuestManager.is_completed(LOST) and EconomyManager.count_item(StringName(item)) == 0 and EconomyManager.gold == gold + 60 and SocialManager.points(owner) == points + int(gift.points) + 100)
		if mode == "failed": t.check(mode + "_gift_complete_rollback_barriers", observed[1] == false and barriers == [true, true] and late.calls == 2 and EventBus.interaction_current(origin))
	EventBus.game_event.emit(&"gift_given", {"npc":owner, "item":item})
	t.check(mode + "_raw_gift_notification_no_model_authority", not QuestManager.is_completed(LOST) if mode in ["direct", "incomplete"] else EconomyManager.gold == gold + 60)
	saves.unregister_section("ghostfam_late")
	late.free()
	await t.go_menu()

func _flush(t) -> void:
	var fixture := preload("res://tests/sections/ghostfam_seek.gd").new()
	await fixture._start(t)
	await fixture._stage(t, 8, 19)
	_freeze(t)
	GameManager.set_flag(&"ghostfam_seek_total", 80)
	var saves: Node = t.autoload("SaveManager")
	var winner: Dictionary = saves.gather_payload()
	var observed: Array = []
	var whispers: Array = []
	var first := func(_why):
		if not observed.is_empty(): return
		observed.append(true)
		observed.append(saves._apply_payload(winner).ok)
	var listen := func(text): whispers.append(str(text))
	EventBus.furniture_changed.connect(first)
	EventBus.whisper_requested.connect(listen)
	var reward: int = fixture.seek.claim_rewards()
	EventBus.furniture_changed.disconnect(first)
	EventBus.whisper_requested.disconnect(listen)
	t.check("flush_actual_five_step_committed_return", reward == 5 and observed == [true, true])
	t.check("flush_no_queued_old_keepsake_or_seek_toasts", whispers.is_empty(), str(whispers))
	t.check("flush_winner_exact_after_whole_loop", Compare.new()._same_payload(winner, saves.gather_payload()))
	t.check("flush_next_independent_claim_exact_once", fixture.seek.claim_rewards() == 5 and GameManager.flag_int(&"ghostfam_seek_claimed", 0) == 31 and fixture.seek.claim_rewards() == 0)
	await t.go_menu()
