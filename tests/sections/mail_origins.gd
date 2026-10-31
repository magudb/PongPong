extends RefCounted
const SECTION := "mail_origins"
const TIMEOUT_S := 150.0
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func _start(t) -> Node:
	if not await t.start_world(): return null
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	GameManager.day = 2
	QuestManager.accept_quest(&"forste_dage")
	return t.world().area.find_markers("mailbox")[0].node

func run(t) -> void:
	await _p1(t)
	for seam in ["toast", "read", "public"]: await _replace(t, seam)

func _p1(t) -> void:
	var box: Node = await _start(t)
	if box == null: return
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	body.enter_area(t.world().area, t.player().global_position)
	PlayerRegistry.for_player(&"p1", func(): QuestManager.accept_quest(&"forste_dage"))
	var p0 := PlayerRegistry.peek_state(&"p0")
	var before := p0.to_dict().duplicate(true)
	var notices: Array = []
	var listen := func(id, payload):
		if id == &"post_read": notices.append(payload.duplicate(true))
	EventBus.game_event.connect(listen)
	box.interact(body)
	var ui: Node = t.first(&"dialogue_ui")
	t.check("p1_mail_real_offer_under_p0", ui.is_open())
	if ui.is_open():
		await t.page_to_choices(ui)
		var rows: Array = ui._choices.filter(func(row): return row.get("action") == "quest_accept")
		if not rows.is_empty(): ui._pick(rows[0])
	t.check("p1_mail_earned_objective", PlayerRegistry.for_player(&"p1", func(): return QuestManager.get_objective_progress(&"forste_dage", &"mail").get("current", 0)) == 1)
	t.check("p1_mail_unrelated_profile_exact", p0.to_dict() == before and PlayerRegistry.acting_id() == &"p0")
	t.check("p1_mail_shared_read_day_once", GameManager.flag_int(&"post_read_day") == GameManager.total_day() and notices.size() == 1)
	box.interact(t.player())
	t.check("p1_mail_shared_letter_not_duplicated", notices.size() == 1 and not ui.is_open() and not box._busy)
	EventBus.game_event.disconnect(listen)
	ui.close()
	await t.go_menu()

func _replace(t, seam: String) -> void:
	var box: Node = await _start(t)
	if box == null: return
	var saves: Node = t.autoload("SaveManager")
	var winner: Dictionary = saves.gather_payload()
	var seen: Array = []
	var notices: Array = []
	var whispers: Array = []
	var replace := func():
		if not seen.is_empty(): return
		seen.append(true)
		seen.append(saves._apply_payload(winner).ok)
		seen.append(saves.gather_payload())
	var flag := func(key, _value):
		if key == (&"post_toast_day" if seam == "toast" else &"post_read_day") and seam != "public": replace.call()
	var event := func(id, payload):
		if id == &"post_read":
			notices.append(payload.duplicate(true))
			if seam == "public": replace.call()
	var whisper := func(key):
		if key == "LIFE_POST_TOAST": whispers.append(key)
	EventBus.flag_changed.connect(flag)
	# Reach an ordinary public observer before the actual mutating listener.
	if seam == "public": EventBus.game_event.disconnect(QuestManager._on_game_event)
	EventBus.game_event.connect(event)
	if seam == "public": EventBus.game_event.connect(QuestManager._on_game_event)
	EventBus.whisper_requested.connect(whisper)
	if seam == "toast": box.refresh()
	else: box.interact(t.player())
	EventBus.flag_changed.disconnect(flag)
	EventBus.game_event.disconnect(event)
	EventBus.whisper_requested.disconnect(whisper)
	t.check(seam + "_mail_actual_healthy_apply", seen.size() == 3 and seen[1] == true)
	t.check(seam + "_mail_winner_exact_whole_unwind", seen.size() == 3 and Compare.new()._same_payload(seen[2], saves.gather_payload()))
	t.check(seam + "_mail_no_old_presentation", not t.first(&"dialogue_ui").is_open() and not box._busy and (seam != "toast" or whispers.is_empty()))
	await t.frames(3)
	t.check(seam + "_mail_winner_exact_queued_frames", seen.size() == 3 and Compare.new()._same_payload(seen[2], saves.gather_payload()))
	await t.go_menu()
