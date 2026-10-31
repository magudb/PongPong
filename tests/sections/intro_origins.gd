extends RefCounted
const SECTION := "intro_origins"
const TIMEOUT_S := 120.0
const Intro := preload("res://scripts/world2d/intro_sequence.gd")

func run(t) -> void:
	await _start_reentry(t)
	await _transient_start(t)
	await _read_reentry(t)
	await _king_skip(t)

func _transient_start(t) -> void:
	if not await t.start_world(): return
	var ui: Node = t.first(&"dialogue_ui")
	var done: Array = []
	var entered: Array = []
	var started := func(id, _module):
		if id != &"fairy_king" or not entered.is_empty(): return
		entered.append(true)
		var next: RefCounted = ui.request_lines({}, [{"text_key":"DLG_LYRA_HELLO"}], [])
		ui.close_request(next)
	EventBus.dialogue_started.connect(started)
	_launch(t.world(), done)
	EventBus.dialogue_started.disconnect(started)
	t.check("intro_transient_newer_page_does_not_revive_old_start", entered == [true] and not ui.is_open() and done == [true])
	ui.close()
	await t.go_menu()

func _start_reentry(t) -> void:
	if not await t.start_world(): return
	var ui: Node = t.first(&"dialogue_ui")
	var requests: Array = []
	var finished: Array = []
	var started := func(id, _module):
		if id != &"fairy_king" or not requests.is_empty(): return
		requests.append(ui.request_lines({"id":"mayor_lyra"}, [{"text_key":"DLG_LYRA_HELLO"}], []))
	EventBus.dialogue_started.connect(started)
	_launch(t.world(), finished)
	EventBus.dialogue_started.disconnect(started)
	t.check("intro_started_new_independent_page_wins", requests.size() == 1 and ui._request == requests[0] and requests[0].result.is_empty())
	ui.close()
	await t.frames(2)
	t.check("intro_start_reentry_waiter_unwinds", finished == [true])
	await t.go_menu()

func _launch(world: Node, finished: Array) -> void:
	await Intro.letter(world)
	finished.append(true)

func _read_reentry(t) -> void:
	if not await t.start_world("ghost"): return
	var ui: Node = t.first(&"dialogue_ui")
	var finished: Array = []
	_launch(t.world(), finished)
	var old: RefCounted = ui._request
	t.check("intro_actual_ghost_letter_before_completion", ui.is_open() and ui._lines.any(func(row): return row.get("text_key") == "DLG_KING_LETTER"))
	var newer: Array = []
	var entered: Array = []
	var closed := func():
		if not entered.is_empty(): return
		entered.append(true)
		newer.append(ui.request_lines({"id":"mayor_lyra"}, [{"text_key":"DLG_LYRA_HELLO"}], []))
	ui.closed.connect(closed)
	for i in 12:
		if ui._request != old or not ui.is_open(): break
		ui._typing = false
		ui._advance()
		await t.frames(2)
	ui.closed.disconnect(closed)
	t.check("intro_read_prefix_earned_despite_newer_page", bool(GameManager.get_flag(&"intro_letter_seen", false)) and finished == [true])
	t.check("intro_optional_reaction_cannot_replace_newer_page", newer.size() == 1 and ui._request == newer[0] and newer[0].result.is_empty())
	ui.close()
	await t.go_menu()

func _king_skip(t) -> void:
	await t.start_world("", "Mia", "Lillegren", "", true)
	var ui: Node = t.first(&"dialogue_ui")
	await t.until(func(): return ui.is_open(), 10)
	while ui.is_open() and ui._speaker.get("id") == "postman_pip":
		ui._typing = false
		ui._advance()
		await t.frames(2)
	await t.until(func(): return ui.is_open() and ui._speaker.get("id") == "fairy_king", 10)
	t.tap_key(KEY_ESCAPE)
	await t.frames(5)
	t.check("tutorial_escape_king_exact_request_finishes", not ui.is_open() and bool(GameManager.get_flag(&"first_morning_done", false)) and QuestManager.is_active(&"intro_lottery") and QuestManager.is_active(&"forste_dage"))
	await t.go_menu()
