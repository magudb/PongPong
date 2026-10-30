extends RefCounted
const SECTION := "dialogue_receipts"
const TIMEOUT_S := 60.0

func _show(ui: Node, lines: Array, choices: Array, out: Array) -> void:
	out.append(await ui.show_lines({"id": "mayor_lyra", "name_key": "NPC_MAYOR_LYRA"}, lines, choices))

func run(t) -> void:
	if not await t.start_world(): return
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	var old: Array = []
	var nested: Array = []
	var notices: Array = []
	var chosen: Array = []
	var notification := func(result): notices.append(result)
	var choice := {"action": "receipt_old", "text_key": "REL_TALK_GOODBYE", "nested": {"proof": 7}}
	var on_choice := func(action, _data):
		chosen.append(action)
		_show(ui, [{"text_key": "DLG_LYRA_HELLO"}, {"text_key": "DLG_LYRA_HELLO"}], [], nested)
		ui.close()
	ui.session_finished.connect(notification)
	ui.choice_selected.connect(on_choice)
	_show(ui, [{"text_key": "DLG_LYRA_HELLO"}], [choice], old)
	ui._typing = false
	ui._advance()
	t.check("actual_choice_visible", ui.is_open() and ui._buttons.size() == 1 and old.is_empty())
	ui._pick(choice)
	ui.choice_selected.disconnect(on_choice)
	ui.session_finished.disconnect(notification)
	t.check("old_waiter_exact_result", old.size() == 1 and old[0].completed and old[0].lines_shown == 1 and old[0].choice == choice, "old waiter must not receive nested cancellation; %s" % [old])
	t.check("nested_waiter_exact_result", nested.size() == 1 and not nested[0].completed and nested[0].lines_shown == 1 and nested[0].choice.is_empty())
	t.check("public_notifications_once", notices.size() == 2 and chosen == ["receipt_old"], "each terminal notice still delivered, including nested close")
	t.check("receipt_recursive_immutable", old[0].is_read_only() and old[0].choice.is_read_only() and old[0].choice.nested.is_read_only())
	await _close_reentry(t, ui)
	await _refusal(t, ui)
	await _line_reentry(t, ui)
	await _actor_exit(t, ui)
	await _screen_exit(t, ui)
	await t.go_menu()

func _screen_exit(t, ui: Node) -> void:
	var out: Array = []
	_show(ui, [{"text_key": "DLG_LYRA_HELLO"}], [], out)
	var parent: Node = ui.get_parent()
	parent.remove_child(ui)
	t.check("screen_exit_resolves_exact_waiter", out.size() == 1 and not out[0].completed and out[0].lines_shown == 1 and not ui._session and not GameManager.is_modal_open(&"dialogue"))
	parent.add_child(ui)
	var future: Array = []
	_show(ui, [{"text_key": "DLG_LYRA_HELLO"}], [], future)
	ui.close()
	t.check("screen_exit_future_request", future.size() == 1 and not future[0].completed and future[0].lines_shown == 1)

func _refusal(t, ui: Node) -> void:
	GameManager.push_modal(&"receipt_blocker")
	var notices: Array = []
	var out: Array = []
	var on_finished := func(result): notices.append(result)
	ui.session_finished.connect(on_finished)
	_show(ui, [{"text_key": "DLG_LYRA_HELLO"}], [], out)
	ui.session_finished.disconnect(on_finished)
	t.check("refusal_private_result", out.size() == 1 and out[0].get("refused", false) and not out[0].completed and out[0].lines_shown == 0 and not ui.is_open())
	t.check("refusal_keeps_public_contract", notices.is_empty(), "legacy refused show_lines returns without public session_finished")
	GameManager.pop_modal(&"receipt_blocker")

func _close_reentry(t, ui: Node) -> void:
	var lines := [{"text_key": "DLG_LYRA_HELLO"}]
	var old: RefCounted = ui.request_lines({}, lines)
	var nested: Array = []
	var middle: Array = []
	var entered: Array = []
	var on_closed := func():
		if not entered.is_empty(): return
		entered.append(true)
		_show(ui, lines, [], nested)
	ui.closed.connect(on_closed)
	_show(ui, lines, [], middle)
	ui.closed.disconnect(on_closed)
	t.check("pending_request_reserved_before_callbacks", not old.result.completed and old.result.lines_shown == 1 and middle.size() == 1 and not middle[0].completed and middle[0].lines_shown == 0 and nested.is_empty() and ui.is_open(), "nested close callback wins over a reserved but not-yet-displayed request")
	ui.close_request(old)
	t.check("stale_request_close_refused", ui.is_open() and nested.is_empty())
	ui.close()
	t.check("replacement_cancel_once", nested.size() == 1 and not nested[0].completed and nested[0].lines_shown == 1)
	ui.close()
	t.check("repeat_close_inert", nested.size() == 1)

func _actor_exit(t, ui: Node) -> void:
	var npc := Npc2D.create({"id": "mayor_lyra"})
	t.world().add_child(npc)
	var replacement: Array = []
	var ended: Array = []
	npc.interact(t.player())
	t.check("actor_exit_real_request", npc.is_talking and ui.is_open())
	var on_end := func():
		ended.append(true)
		if ended.size() == 1:
			_show(ui, [{"text_key": "DLG_LYRA_HELLO"}], [], replacement)
	EventBus.dialogue_ended.connect(on_end)
	npc.queue_free()
	await t.frames(2)
	EventBus.dialogue_ended.disconnect(on_end)
	t.check("actor_exit_exact_cleanup", ui.is_open() and replacement.is_empty() and ended == [true], "departing actor may retire only its own request, not terminal-observer replacement")
	ui.close()
	t.check("actor_exit_replacement_receipt", replacement.size() == 1 and not replacement[0].completed and replacement[0].lines_shown == 1)

func _line_reentry(t, ui: Node) -> void:
	var old: Array = []
	var next: Array = []
	var entered: Array = []
	var replacing := func(_speaker, _text, _voice):
		if not entered.is_empty(): return
		entered.append(true)
		_show(ui, [], [{"action": "replacement", "text_key": "REL_TALK_GOODBYE"}], next)
	var lines := [{"text_key": "DLG_LYRA_HELLO"}]
	EventBus.dialogue_line_shown.connect(replacing)
	_show(ui, lines, [], old)
	EventBus.dialogue_line_shown.disconnect(replacing)
	t.check("line_callback_old_receipt", old.size() == 1 and not old[0].completed and old[0].lines_shown == 1)
	t.check("line_callback_replacement_focus", ui.is_open() and next.is_empty() and ui._buttons.size() == 1 and ui.get_viewport().gui_get_focus_owner() == ui._buttons[0], "old line suffix cannot release replacement choice focus")
	ui._on_cancel()
	t.check("line_callback_replacement_cancel", next.size() == 1 and not next[0].completed and next[0].lines_shown == 0)
