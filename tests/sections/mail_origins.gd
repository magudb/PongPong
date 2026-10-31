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
	for mode in ["failed", "incomplete", "same"]: await _rollback(t, mode)
	for seam in ["flag", "choice"]:
		for mode in ["unregister", "free", "detach"]: await _departure(t, seam, mode)
	await _busy(t)
	await _invalid(t)
	await _queued(t)
	await _hint_after_apply(t)

func _body(t) -> Node2D:
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	body.enter_area(t.world().area, t.player().global_position)
	PlayerRegistry.for_player(&"p1", func(): QuestManager.accept_quest(&"forste_dage"))
	return body

func _remove(t, body: Node, mode: String) -> void:
	if mode == "unregister": t.world()._unregister_player(body)
	else:
		body.get_parent().remove_child(body)
		if mode == "free": body.free()

func _departure(t, seam: String, mode: String) -> void:
	var box: Node = await _start(t)
	if box == null: return
	var body: Node2D = _body(t)
	var p0 := PlayerRegistry.peek_state(&"p0")
	var before := p0.to_dict().duplicate(true)
	var seen: Array = []
	var flag := func(key, _value):
		if key == &"post_read_day" and seam == "flag" and seen.is_empty():
			seen.append(true)
			_remove(t, body, mode)
	EventBus.flag_changed.connect(flag)
	box.interact(body)
	EventBus.flag_changed.disconnect(flag)
	var ui: Node = t.first(&"dialogue_ui")
	var label := seam + "_" + mode
	if seam == "choice":
		t.check(label + "_mail_real_offer_before_departure", ui.is_open())
		await t.page_to_choices(ui)
		var accept: Dictionary = ui._choices.filter(func(row): return row.get("action") == "quest_accept")[0]
		_remove(t, body, mode)
		ui._pick(accept)
	else: t.check(label + "_mail_no_optional_offer", seen == [true] and not ui.is_open())
	t.check(label + "_mail_earned_read_survives_body_only_loss", PlayerRegistry.for_player(&"p1", func(): return QuestManager.get_objective_progress(&"forste_dage", &"mail").get("current", 0)) == 1 and GameManager.flag_int(&"post_read_day") == GameManager.total_day())
	t.check(label + "_mail_no_accept_no_unrelated_mutation", not PlayerRegistry.for_player(&"p1", func(): return QuestManager.is_active(&"pips_runde")) and p0.to_dict() == before and not box._busy)
	if mode == "detach": body.queue_free()
	await t.frames(3)
	t.check(label + "_mail_earned_progress_after_unwind", PlayerRegistry.for_player(&"p1", func(): return QuestManager.get_objective_progress(&"forste_dage", &"mail").get("current", 0)) == 1)
	await t.go_menu()

func _rollback(t, mode: String) -> void:
	var box: Node = await _start(t)
	if box == null: return
	var saves: Node = t.autoload("SaveManager")
	var old_dir: String = saves.save_dir
	saves.save_dir = "user://mail-rollback-" + mode
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("mail_late", late, 1000)
	t.check(mode + "_mail_real_primary_no_backup", saves.save_game(0) and not FileAccess.file_exists(saves.save_dir + "/save_0.bak.json"))
	var origin := EventBus.interaction_origin(&"p0")
	var profile := PlayerRegistry.peek_state(&"p0")
	var stamp: Array = saves._save_owner_stamp()
	var seen: Array = []
	var decoder: Array = []
	var final: Array = []
	late.callback = func(): decoder.append(not EventBus.interaction_current(origin))
	var failed := func(title, _message, kind):
		if kind == "save" and title == TranslationServer.translate("NOTIF_LOAD_FAILED_TITLE"):
			final.append(PlayerRegistry.peek_state(&"p0") == profile and saves._save_owner_stamp() == stamp and not saves.continuation_available(profile) and not EventBus.interaction_current(origin))
	var flag := func(key, _value):
		if key != &"post_read_day" or not seen.is_empty(): return
		seen.append(true)
		late.rejects = 1 if mode == "failed" else (2 if mode == "incomplete" else 0)
		seen.append(saves._apply_payload(saves.gather_payload()).ok if mode == "same" else saves.load_game(0))
	EventBus.flag_changed.connect(flag)
	EventBus.notification_posted.connect(failed)
	box.interact(t.player())
	EventBus.flag_changed.disconnect(flag)
	EventBus.notification_posted.disconnect(failed)
	var ui: Node = t.first(&"dialogue_ui")
	if mode == "failed":
		t.check("failed_mail_same_origin_resumes_earned_prefix_once", seen == [true, false] and EventBus.interaction_current(origin) and QuestManager.get_objective_progress(&"forste_dage", &"mail").get("current", 0) == 1 and ui.is_open())
		t.check("failed_mail_decoder_and_final_barriers", decoder == [true, true] and final == [true])
	else:
		t.check(mode + "_mail_cannot_revive", seen == [true, mode == "same"] and not EventBus.interaction_current(origin) and QuestManager.get_objective_progress(&"forste_dage", &"mail").get("current", 0) == 0 and not ui.is_open())
	ui.close()
	saves.unregister_section("mail_late")
	late.free()
	saves.save_dir = old_dir
	await t.go_menu()

func _invalid(t) -> void:
	var box: Node = await _start(t)
	if box == null: return
	var ui: Node = t.first(&"dialogue_ui")
	var stranger := Node2D.new()
	t.world().add_child(stranger)
	for body in [null, stranger]:
		box.interact(body)
		t.check("mail_invalid_" + ("null" if body == null else "unregistered"), not ui.is_open() and not box._busy and GameManager.flag_int(&"post_read_day") == 0)
		ui.close()
	stranger.queue_free()
	var registered: Node2D = _body(t)
	PlayerRegistry.reset_states()
	box.interact(registered)
	t.check("mail_missing_profile_not_materialized", PlayerRegistry.peek_state(&"p1") == null and not ui.is_open() and not box._busy)
	ui.close()
	await t.go_menu()

func _queued(t) -> void:
	var box: Node = await _start(t)
	if box == null: return
	var saves: Node = t.autoload("SaveManager")
	box._queue_refresh()
	var incoming: Dictionary = saves.gather_payload()
	t.check("mail_queued_real_same_area_replacement", saves._apply_payload(incoming).ok)
	box.letter = {"winner": true}
	await t.frames(3)
	t.check("mail_old_queued_refresh_does_not_borrow_winner", box.letter == {"winner": true} and GameManager.flag_int(&"post_toast_day") == 0)
	box.refresh()
	t.check("mail_current_independent_refresh_catches_up", box.letter.has("quest_id") and GameManager.flag_int(&"post_toast_day") == GameManager.total_day())
	await t.go_menu()

func _busy(t) -> void:
	var box: Node = await _start(t)
	if box == null: return
	var saves: Node = t.autoload("SaveManager")
	var winner: Dictionary = saves.gather_payload()
	var ui: Node = t.first(&"dialogue_ui")
	box.interact(t.player())
	var seen: Array = []
	var ended := func():
		if not seen.is_empty(): return
		seen.append(true)
		seen.append(saves._apply_payload(winner).ok)
		box.interact(t.player())
	EventBus.dialogue_ended.connect(ended)
	ui.close()
	EventBus.dialogue_ended.disconnect(ended)
	t.check("mail_old_unwind_preserves_new_busy", seen == [true, true] and ui.is_open() and box._busy)
	ui.close()
	t.check("mail_new_busy_own_cleanup", not box._busy)
	await t.go_menu()

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

# Commit the authored day-two prefix through the real current-world hint root.
# Never manufacture its flag/queue/cooldown or suppress polling after apply.
func _mail_hint_prefix(t, label: String, process_only := false) -> bool:
	var hints: Node = t.world().get_node_or_null("FarmTutorialHints")
	var eligible: bool = hints is TutorialHints and hints.world == t.world() and hints.is_processing() and hints._active() and QuestManager.is_active(&"forste_dage") and GameManager.total_day() == 2 and GameManager.current_phase == GameManager.GamePhase.PLAYING and str(t.world().area.map.id) == "farm"
	t.check(label + "_hint_current_authored_eligible", eligible and hints.hints == LuaData.arr(GameManager.config_value("farm_tutorial.hints", [])) and hints.hints.any(func(row): return str(row.get("id", "")) == "mail" and str(row.get("on", "")) == "day_at_least" and int(row.get("day", 0)) == 2) and GameManager.flag_int(&"tut_hint_mail") == 0)
	if not eligible: return false
	var shown: Array = []
	var whispers: Array = []
	var event := func(id, payload):
		if id == &"tutorial_hint_shown": shown.append(str(payload.get("id", "")))
	var whisper := func(line): whispers.append(line)
	EventBus.game_event.connect(event)
	EventBus.whisper_requested.connect(whisper)
	# If another genuine hint owns the gap, wait real finite time. Earlier pending
	# hints remain visible and use their normal authored ordering and cooldown.
	var deadline := float(Time.get_ticks_msec()) / 1000.0 + 60.0
	while GameManager.flag_int(&"tut_hint_mail") == 0 and float(Time.get_ticks_msec()) / 1000.0 < deadline:
		if not process_only: hints.tick(float(Time.get_ticks_msec()) / 1000.0)
		if GameManager.flag_int(&"tut_hint_mail") == 0: await t.frames(1)
	var mail_rows: Array = hints.hints.filter(func(row): return str(row.get("id", "")) == "mail")
	var committed: bool = GameManager.flag_int(&"tut_hint_mail") == 1 and shown.count("mail") == 1 and mail_rows.size() == 1 and whispers.count(UiHints.format_line(mail_rows[0])) == 1
	t.check(label + "_hint_real_commit_public_once", committed)
	var before := shown.duplicate()
	hints.tick(float(Time.get_ticks_msec()) / 1000.0)
	t.check(label + "_hint_normal_idempotence_polling_enabled", shown == before and GameManager.flag_int(&"tut_hint_mail") == 1 and hints.is_processing())
	EventBus.game_event.disconnect(event)
	EventBus.whisper_requested.disconnect(whisper)
	return committed

func _hint_after_apply(t) -> void:
	var box: Node = await _start(t)
	if box == null: return
	GameManager.day = 1
	var saves: Node = t.autoload("SaveManager")
	var incoming: Dictionary = saves.gather_payload()
	t.check("hint_normal_healthy_apply_before_eligibility", GameManager.flag_int(&"tut_hint_mail") == 0 and saves._apply_payload(incoming).ok and GameManager.flag_int(&"tut_hint_mail") == 0)
	GameManager.day = 2
	# No manual tick until after commit: actual _process must still run after apply.
	await _mail_hint_prefix(t, "hint_after_apply_process", true)
	await t.go_menu()

func _replace(t, seam: String) -> void:
	var box: Node = await _start(t)
	if box == null: return
	if not await _mail_hint_prefix(t, seam):
		await t.go_menu()
		return
	var saves: Node = t.autoload("SaveManager")
	var winner: Dictionary = saves.gather_payload()
	var missing_hint := winner.duplicate(true)
	missing_hint.game.world_flags.erase("tut_hint_mail")
	t.check(seam + "_hint_remains_judged_snapshot_field", winner.game.world_flags.get("tut_hint_mail") == 1 and not Compare.new()._same_payload(winner, missing_hint))
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
	var whole_unwind: Dictionary = saves.gather_payload()
	t.check(seam + "_mail_winner_exact_whole_unwind", seen.size() == 3 and Compare.new()._same_payload(seen[2], whole_unwind), JSON.stringify({"changed": Compare.new()._changed(seen[2], whole_unwind), "expected": seen[2], "actual": whole_unwind}, "", true, true) if seen.size() == 3 else "observer absent")
	t.check(seam + "_mail_no_old_presentation", not t.first(&"dialogue_ui").is_open() and not box._busy and (seam != "toast" or whispers.is_empty()))
	await t.frames(3)
	var queued_frames: Dictionary = saves.gather_payload()
	t.check(seam + "_mail_winner_exact_queued_frames", seen.size() == 3 and Compare.new()._same_payload(seen[2], queued_frames), JSON.stringify({"changed": Compare.new()._changed(seen[2], queued_frames), "expected": seen[2], "actual": queued_frames}, "", true, true) if seen.size() == 3 else "observer absent")
	await t.go_menu()
