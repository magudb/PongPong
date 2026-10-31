extends RefCounted
const SECTION := "service_origins"
const TIMEOUT_S := 150.0
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func _freeze(t) -> void:
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))

func run(t) -> void:
	await _bodies(t)
	await _board_p1(t)
	await _query(t)
	await _transient_start(t)
	await _busy_reentry(t)
	for mode in ["unregister", "free", "detach"]: await _departure(t, mode)

func _ask_record(world: Node, done: Array) -> void:
	done.append(await LifeFlow.ask(world, "mayor_lyra", [{"text_key":"DLG_LYRA_HELLO"}], []))

func _transient_start(t) -> void:
	if not await t.start_world(): return
	var ui: Node = t.first(&"dialogue_ui")
	var done: Array = []
	var entered: Array = []
	var started := func(id, _module):
		if id != &"mayor_lyra" or not entered.is_empty(): return
		entered.append(true)
		var next: RefCounted = ui.request_lines({}, [{"text_key":"DLG_LYRA_HELLO"}], [])
		ui.close_request(next)
	EventBus.dialogue_started.connect(started)
	_ask_record(t.world(), done)
	EventBus.dialogue_started.disconnect(started)
	t.check("service_transient_newer_page_does_not_revive_old_start", entered == [true] and not ui.is_open() and done.size() == 1)
	ui.close()
	await t.go_menu()

func _busy_reentry(t) -> void:
	if not await t.start_world(): return
	_freeze(t)
	var board: Node = _board(t)
	var ui: Node = t.first(&"dialogue_ui")
	var saves: Node = t.autoload("SaveManager")
	var winner: Dictionary = saves.gather_payload()
	board.interact(t.player())
	var entered: Array = []
	var replaced := func():
		if not entered.is_empty(): return
		entered.append(true)
		entered.append(saves._apply_payload(winner).ok)
		board.interact(t.player())
	EventBus.dialogue_ended.connect(replaced)
	ui.close()
	EventBus.dialogue_ended.disconnect(replaced)
	t.check("old_service_unwind_cannot_clear_new_busy", entered == [true, true] and ui.is_open() and board._busy)
	ui.close()
	t.check("new_service_busy_own_cleanup", not board._busy)
	await t.go_menu()

func _departure(t, mode: String) -> void:
	if not await t.start_world(): return
	_freeze(t)
	var board: Node = _board(t)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	body.enter_area(t.world().area, t.player().global_position)
	board.interact(body)
	var ui: Node = t.first(&"dialogue_ui")
	var offered: Dictionary = ui._choices.filter(func(row): return row.get("action") == "offer")[0]
	var id := StringName(str(offered.quest_id))
	ui._pick(offered)
	if mode == "unregister": t.world()._unregister_player(body)
	elif mode == "free":
		body.get_parent().remove_child(body)
		body.free()
	else: body.get_parent().remove_child(body)
	ui._pick(ui._choices.filter(func(row): return row.get("action") == "quest_accept")[0])
	t.check(mode + "_service_old_selection_cannot_accept", not PlayerRegistry.for_player(&"p1", func(): return QuestManager.is_active(id)) and not board._busy and PlayerRegistry.acting_id() == &"p0")
	board.interact(t.player())
	t.check(mode + "_service_next_registered_body_not_deadlocked", ui.is_open())
	ui.close()
	if mode == "detach": body.queue_free()
	await t.go_menu()

func _board(t) -> Node:
	var board := NoticeBoard2D.new()
	t.world().area.objects.add_child(board)
	return board

func _bodies(t) -> void:
	if not await t.start_world(): return
	_freeze(t)
	var board: Node = _board(t)
	var ui: Node = t.first(&"dialogue_ui")
	var p0 := PlayerRegistry.peek_state(&"p0")
	var before := p0.to_dict().duplicate(true)
	var stranger := Node2D.new()
	t.world().add_child(stranger)
	for body in [null, stranger]:
		board.interact(body)
		t.check("invalid_registered_service_root_" + ("null" if body == null else "stranger"), not ui.is_open() and not board._busy and p0.to_dict() == before)
		ui.close()
	stranger.queue_free()
	var registered: Node2D = t.world()._make_player()
	t.world()._register_player(registered, 1, 2)
	t.world().add_child(registered)
	registered.enter_area(t.world().area, t.player().global_position)
	PlayerRegistry.reset_states()
	board.interact(registered)
	t.check("registered_missing_service_profile_is_not_materialized", PlayerRegistry.peek_state(&"p1") == null and not ui.is_open() and not board._busy)
	await t.go_menu()

func _board_p1(t) -> void:
	if not await t.start_world(): return
	_freeze(t)
	var board: Node = _board(t)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	body.enter_area(t.world().area, t.player().global_position)
	var p0 := PlayerRegistry.peek_state(&"p0")
	var before := p0.to_dict().duplicate(true)
	board.interact(body)
	var ui: Node = t.first(&"dialogue_ui")
	t.check("p1_board_real_rows_under_p0", ui.is_open() and not ui._choices.is_empty())
	var selected: Dictionary = ui._choices.filter(func(row): return row.get("action") == "offer")[0]
	ui._pick(selected)
	t.check("p1_board_actual_offer", ui.is_open() and ui._choices.any(func(row): return row.get("action") == "quest_accept"))
	ui._pick(ui._choices.filter(func(row): return row.get("action") == "quest_accept")[0])
	var id := StringName(str(selected.quest_id))
	t.check("p1_board_owned_quest_accept_and_caller_restored", PlayerRegistry.acting_id() == &"p0" and PlayerRegistry.for_player(&"p1", func(): return QuestManager.is_active(id)))
	t.check("p1_board_unrelated_profile_exact", p0.to_dict() == before)
	await t.frames(2)
	t.check("p1_board_unwind_busy_released", not board._busy)
	await t.go_menu()

func _query(t) -> void:
	if not await t.start_world(): return
	_freeze(t)
	var board: Node = _board(t)
	var available: Array = board.rows()
	t.check("query_real_authored_offer_exists", not available.is_empty())
	var saves: Node = t.autoload("SaveManager")
	var winner: Dictionary = saves.gather_payload()
	var seen: Array = []
	var target := StringName(str(available[0].quest_id))
	var gate := func():
		if seen.is_empty():
			seen.append(true)
			seen.append(saves._apply_payload(winner).ok)
			seen.append(saves.gather_payload())
		return true
	var later: Array = []
	var second := StringName(str(available[1].quest_id))
	QuestManager.register_offer_gate(second, func():
		if not seen.is_empty(): later.append(true)
		return true)
	QuestManager.register_offer_gate(target, gate)
	board.interact(t.player())
	QuestManager.register_offer_gate(target, Callable())
	QuestManager.register_offer_gate(second, Callable())
	t.check("query_inside_callee_no_next_winner_gate", later.is_empty())
	var ui: Node = t.first(&"dialogue_ui")
	t.check("query_callback_actual_healthy_apply", seen.size() == 3 and seen[1] == true)
	t.check("query_callback_no_old_ui_or_winner_mutation", not ui.is_open() and seen.size() == 3 and Compare.new()._same_payload(seen[2], saves.gather_payload()))
	ui.close()
	board.interact(t.player())
	t.check("query_next_current_root_not_deadlocked", ui.is_open())
	ui.close()
	await t.go_menu()
