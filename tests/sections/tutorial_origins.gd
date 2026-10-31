extends RefCounted
const SECTION := "tutorial_origins"
const TIMEOUT_S := 120.0
const Runner := preload("res://scripts/farm/steading/tutorial/tutorial_runner.gd")
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func _freeze(t) -> void:
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))

func run(t) -> void:
	for seam in ["weather", "clock", "step", "accepted", "seen"]:
		await _suffix(t, seam)
	await _exact_skip(t)
	for mode in ["failed", "incomplete", "same"]: await _continuation(t, mode)
	await _normal(t)

func _normal(t) -> void:
	GameManager.clear_config_overrides()
	var starts: Array = []
	var start := func(id, _module): starts.append(str(id))
	EventBus.dialogue_started.connect(start)
	await t.start_world("", "Mia", "Lillegren", "", true)
	await preload("res://tests/sections/farm_first_morning.gd").new()._opening(t)
	EventBus.dialogue_started.disconnect(start)
	t.check("normal_actual_opening_order_quests_and_release", starts == ["postman_pip", "fairy_king", "postman_pip"] and QuestManager.is_active(&"intro_lottery") and QuestManager.is_active(&"forste_dage") and t.player().state == PlayerBody2D.S.FREE and not GameManager.is_modal_open())
	await t.go_menu()

func _continuation(t, mode: String) -> void:
	GameManager.clear_config_overrides()
	if not await t.start_world(): return
	_freeze(t)
	var saves: Node = t.autoload("SaveManager")
	var old_dir: String = saves.save_dir
	saves.save_dir = "user://tutorial-owned-" + mode
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("tutorial_late", late, 1000)
	t.check(mode + "_tutorial_real_primary_no_backup", saves.save_game(0) and not FileAccess.file_exists(saves.save_dir + "/save_0.bak.json"))
	var session := Runner.new()
	session.world = t.world()
	session.origin = EventBus.interaction_origin(&"p0")
	session.skipped = true
	var origin: Dictionary = session.origin
	var profile := PlayerRegistry.peek_state(&"p0")
	var stamp: Array = saves._save_owner_stamp()
	var entered: Array = []
	var decoder: Array = []
	var final: Array = []
	late.callback = func(): decoder.append(not EventBus.interaction_current(origin))
	var failed := func(title, _message, kind):
		if kind == "save" and title == TranslationServer.translate("NOTIF_LOAD_FAILED_TITLE"):
			final.append(PlayerRegistry.peek_state(&"p0") == profile and saves._save_owner_stamp() == stamp and not saves.continuation_available(profile) and not EventBus.interaction_current(origin))
	var flag := func(key, _value):
		if key != &"intro_letter_seen" or not entered.is_empty(): return
		entered.append(true)
		late.rejects = 1 if mode == "failed" else (2 if mode == "incomplete" else 0)
		entered.append(saves._apply_payload(saves.gather_payload()).ok if mode == "same" else saves.load_game(0))
	EventBus.flag_changed.connect(flag)
	EventBus.notification_posted.connect(failed)
	await session.play()
	EventBus.flag_changed.disconnect(flag)
	EventBus.notification_posted.disconnect(failed)
	if mode == "failed":
		t.check("failed_tutorial_same_origin_resumes_earned_prefix_once", entered == [true, false] and EventBus.interaction_current(origin) and bool(GameManager.get_flag(&"first_morning_done", false)) and QuestManager.is_active(&"intro_lottery") and QuestManager.is_active(&"forste_dage"))
		t.check("failed_tutorial_decoder_and_outer_final_barriers", decoder == [true, true] and final == [true])
	else:
		t.check(mode + "_tutorial_replacement_revokes_next_flag", entered == [true, mode == "same"] and not EventBus.interaction_current(origin) and not bool(GameManager.get_flag(&"first_morning_done", false)))
	saves.unregister_section("tutorial_late")
	late.free()
	saves.save_dir = old_dir
	await t.go_menu()

func _suffix(t, seam: String) -> void:
	if not await t.start_world(): return
	_freeze(t)
	TimeManager.set_weather(&"regn")
	GameManager.set_clock(13, 17)
	GameManager.set_config_override("farm_tutorial.first_morning.steps", [
		{"kind":"quest_accept", "quest":"intro_lottery"},
		{"kind":"quest_accept", "quest":"forste_dage"}])
	var session := Runner.new()
	session.world = t.world()
	session.origin = EventBus.interaction_origin(&"p0")
	if seam == "accepted": session.skipped = true
	var saves: Node = t.autoload("SaveManager")
	var winner: Dictionary = saves.gather_payload()
	t.check(seam + "_healthy_valid_winner", saves.validate_payload(winner).ok)
	var seen: Array = []
	var finished: Array = []
	var replace := func():
		if not seen.is_empty(): return
		seen.append(true)
		seen.append(saves._apply_payload(winner).ok)
		seen.append(saves.gather_payload())
	var weather := func(_value):
		if seam == "weather": replace.call()
	var clock := func(_hour, _minute):
		if seam == "clock": replace.call()
	var event := func(id, _payload):
		if id == &"tutorial_step" and seam == "step": replace.call()
		if id == &"tutorial_finished": finished.append(true)
	var accepted := func(_pid, _id):
		if seam == "accepted": replace.call()
	var flag := func(key, _value):
		if key == &"intro_letter_seen" and seam == "seen": replace.call()
	EventBus.weather_changed.connect(weather)
	EventBus.time_of_day_changed.connect(clock)
	EventBus.game_event.connect(event)
	EventBus.quest_accepted.connect(accepted)
	EventBus.flag_changed.connect(flag)
	await session.play()
	EventBus.weather_changed.disconnect(weather)
	EventBus.time_of_day_changed.disconnect(clock)
	EventBus.game_event.disconnect(event)
	EventBus.quest_accepted.disconnect(accepted)
	EventBus.flag_changed.disconnect(flag)
	t.check(seam + "_actual_apply_reached", seen.size() == 3 and seen[1] == true)
	t.check(seam + "_winner_exact_whole_unwind", seen.size() == 3 and Compare.new()._same_payload(seen[2], saves.gather_payload()))
	t.check(seam + "_no_stale_finished", finished.is_empty())
	await t.frames(3)
	t.check(seam + "_winner_exact_queued_frames", seen.size() == 3 and Compare.new()._same_payload(seen[2], saves.gather_payload()))
	await t.go_menu()

func _exact_skip(t) -> void:
	GameManager.clear_config_overrides()
	await t.start_world("", "Mia", "Lillegren", "", true)
	var ui: Node = t.first(&"dialogue_ui")
	await t.until(func(): return ui.is_open(), 10)
	var gate: Node = t.world().get_node("FirstMorningInput")
	var session: RefCounted = gate.session
	var newer: RefCounted = ui.request_lines({"id":"mayor_lyra"}, [{"text_key":"DLG_LYRA_HELLO"}], [])
	session.skip()
	t.check("old_skip_does_not_close_replacement_request", ui.is_open() and newer.result.is_empty())
	await t.frames(3)
	t.check("old_skip_unwind_preserves_replacement_request", ui.is_open() and newer.result.is_empty())
	ui.close_request(newer)
	await t.go_menu()
