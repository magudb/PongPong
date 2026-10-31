extends RefCounted
const SECTION := "travel_origins"
const TIMEOUT_S := 120.0

func _start(t) -> Node:
	if not await t.start_world(): return null
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	GameManager.set_flag(&"ft_torv", 1)
	var signpost := Rejsestolpe2D.new()
	signpost.area = t.world().area
	signpost.stop = "farm"
	t.world().area.objects.add_child(signpost)
	signpost.set_process(false)
	return signpost

func _body(t) -> Node2D:
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	body.enter_area(t.world().area, t.player().global_position)
	return body

func run(t) -> void:
	for mode in ["normal", "later", "escape", "unregister", "free", "detach", "area"]: await _choice(t, mode)
	await _invalid(t)
	await _busy(t)
	for mode in ["failed", "incomplete", "same"]: await _rollback(t, mode)

func _choice(t, mode: String) -> void:
	var signpost: Node = await _start(t)
	if signpost == null: return
	var body: Node2D = _body(t)
	var p0 := PlayerRegistry.peek_state(&"p0")
	var before := p0.to_dict().duplicate(true)
	var labels: Array = []
	var starts := func(origin, _id, _module, _attachment): labels.append(origin.recipient.player_id)
	var travels: Array = []
	var moved := func(id, spawn): travels.append([id, spawn])
	EventBus.interaction_started.connect(starts)
	EventBus.area_change_requested.connect(moved)
	signpost.interact(body)
	var ui: Node = t.first(&"dialogue_ui")
	t.check(mode + "_travel_registered_p1_origin_under_p0", ui.is_open() and labels == [&"p1"])
	await t.page_to_choices(ui)
	var choices: Array = ui._choices.filter(func(row): return row.get("action") == "travel")
	t.check(mode + "_travel_authored_destination_reached", choices.size() == 1 and choices[0].spawn == "default")
	var area: Node = t.world().area
	var parent: Node = area.get_parent()
	if mode == "unregister": t.world()._unregister_player(body)
	elif mode == "free":
		body.get_parent().remove_child(body)
		body.free()
	elif mode == "detach": body.get_parent().remove_child(body)
	elif mode == "area": parent.remove_child(area)
	if mode == "escape": ui.close()
	elif mode == "later": ui._pick(ui._choices.filter(func(row): return row.get("action") == "close")[0])
	elif not choices.is_empty(): ui._pick(choices[0])
	EventBus.interaction_started.disconnect(starts)
	EventBus.area_change_requested.disconnect(moved)
	t.check(mode + "_travel_exact_emission_and_busy_cleanup", travels.size() == (1 if mode == "normal" else 0) and not signpost._busy)
	if mode == "area": parent.add_child(area)
	if mode == "detach": body.queue_free()
	await t.until(func(): return not t.world().traveling, 10)
	await t.frames(3)
	t.check(mode + "_travel_unrelated_profile_and_caller", p0.to_dict() == before and PlayerRegistry.acting_id() == &"p0")
	signpost.interact(t.player())
	t.check(mode + "_travel_next_current_root", ui.is_open())
	ui.close()
	await t.go_menu()

func _rollback(t, mode: String) -> void:
	var signpost: Node = await _start(t)
	if signpost == null: return
	var saves: Node = t.autoload("SaveManager")
	var old_dir: String = saves.save_dir
	saves.save_dir = "user://travel-rollback-" + mode
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("travel_late", late, 1000)
	t.check(mode + "_travel_real_primary_no_backup", saves.save_game(0) and not FileAccess.file_exists(saves.save_dir + "/save_0.bak.json"))
	var origin := EventBus.interaction_origin(&"p0")
	var profile := PlayerRegistry.peek_state(&"p0")
	var stamp: Array = saves._save_owner_stamp()
	var seen: Array = []
	var decoder: Array = []
	var final: Array = []
	var travels: Array = []
	var moved := func(id, spawn): travels.append([id, spawn])
	late.callback = func(): decoder.append(not EventBus.interaction_current(origin))
	var failed := func(title, _message, kind):
		if kind == "save" and title == TranslationServer.translate("NOTIF_LOAD_FAILED_TITLE"):
			final.append(PlayerRegistry.peek_state(&"p0") == profile and saves._save_owner_stamp() == stamp and not saves.continuation_available(profile) and not EventBus.interaction_current(origin))
	var ended := func():
		if not seen.is_empty(): return
		seen.append(true)
		late.rejects = 1 if mode == "failed" else (2 if mode == "incomplete" else 0)
		seen.append(saves._apply_payload(saves.gather_payload()).ok if mode == "same" else saves.load_game(0))
	signpost.interact(t.player())
	var ui: Node = t.first(&"dialogue_ui")
	await t.page_to_choices(ui)
	var selected: Dictionary = ui._choices.filter(func(row): return row.get("action") == "travel")[0]
	EventBus.dialogue_ended.connect(ended)
	EventBus.notification_posted.connect(failed)
	EventBus.area_change_requested.connect(moved)
	ui._pick(selected)
	EventBus.dialogue_ended.disconnect(ended)
	EventBus.notification_posted.disconnect(failed)
	EventBus.area_change_requested.disconnect(moved)
	if mode == "failed":
		t.check("failed_travel_same_origin_continues_once", seen == [true, false] and EventBus.interaction_current(origin) and travels.size() == 1)
		t.check("failed_travel_decoder_and_final_barriers", decoder == [true, true] and final == [true])
	else:
		t.check(mode + "_travel_cannot_revive", seen == [true, mode == "same"] and not EventBus.interaction_current(origin) and travels.is_empty())
	await t.until(func(): return not t.world().traveling, 10)
	saves.unregister_section("travel_late")
	late.free()
	saves.save_dir = old_dir
	await t.go_menu()

func _invalid(t) -> void:
	var signpost: Node = await _start(t)
	if signpost == null: return
	var ui: Node = t.first(&"dialogue_ui")
	var stranger := Node2D.new()
	t.world().add_child(stranger)
	for body in [null, stranger]:
		signpost.interact(body)
		t.check("travel_invalid_" + ("null" if body == null else "unregistered"), not ui.is_open() and not signpost._busy)
		ui.close()
	stranger.queue_free()
	var registered: Node2D = _body(t)
	PlayerRegistry.reset_states()
	signpost.interact(registered)
	t.check("travel_missing_profile_not_materialized", PlayerRegistry.peek_state(&"p1") == null and not ui.is_open() and not signpost._busy)
	ui.close()
	await t.go_menu()

func _busy(t) -> void:
	var signpost: Node = await _start(t)
	if signpost == null: return
	var saves: Node = t.autoload("SaveManager")
	var winner: Dictionary = saves.gather_payload()
	var ui: Node = t.first(&"dialogue_ui")
	signpost.interact(t.player())
	var entered: Array = []
	var ended := func():
		if not entered.is_empty(): return
		entered.append(true)
		entered.append(saves._apply_payload(winner).ok)
		signpost.interact(t.player())
	EventBus.dialogue_ended.connect(ended)
	ui.close()
	EventBus.dialogue_ended.disconnect(ended)
	t.check("travel_old_unwind_preserves_new_busy", entered == [true, true] and ui.is_open() and signpost._busy)
	ui.close()
	t.check("travel_new_busy_own_cleanup", not signpost._busy)
	await t.go_menu()
