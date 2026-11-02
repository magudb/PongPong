extends RefCounted
const SECTION := "dialogue_request_isolation"
const TIMEOUT_S := 90.0

func run(t) -> void:
	for seam in ["closed", "choice", "line"]:
		await t.start_world()
		var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
		var bus: Node = t.autoload("EventBus")
		var a: Array = []
		var b: Array = []
		var entered: Array = []
		var callback := func(_action = null, _data = null, _voice = null):
			entered.append(seam)
			_show(screen, "baker_maja", [{"text_key": "DLG_MAJA_MATH_Q1"}], b)
		if seam == "closed": screen.closed.connect(callback, CONNECT_ONE_SHOT)
		elif seam == "choice": screen.choice_selected.connect(callback, CONNECT_ONE_SHOT)
		else: bus.dialogue_line_shown.connect(callback, CONNECT_ONE_SHOT)
		_show(screen, "smith_thorin", [{"text_key": "LC_SMITH_THORIN_ACTIVITY"}, {"text_key": "DLG_NEUTRAL"}], a)
		if seam != "line":
			await t.page_to_choices(screen)
			await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
			t.check(seam + "_a_real_two_line_page", screen._shown == 2 and screen._speaker.get("id") == "smith_thorin" and not screen._buttons.is_empty())
			screen._buttons[0].grab_focus()
			t.tap_key(KEY_ENTER)
		await t.frames(2)
		t.check(seam + "_reentrant_request_entered", entered == [seam])
		t.check(seam + "_a_result_is_own_snapshot", a.size() == 1 and a[0].get("lines_shown") == (1 if seam == "line" else 2) and a[0].get("completed") == (seam != "line"), str(a))
		t.check(seam + "_b_waiter_not_woken_by_a", b.is_empty() and screen.is_open() and screen._speaker.get("id") == "baker_maja", str(b))
		await t.page_to_choices(screen)
		if not screen._buttons.is_empty():
			await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
			screen._buttons[0].grab_focus()
			t.tap_key(KEY_ENTER)
		await t.frames(2)
		t.check(seam + "_b_result_is_own_snapshot", b.size() == 1 and b[0].get("completed") == true and b[0].get("lines_shown") == 1 and not screen.is_open(), str(b))

func _show(screen: Node, npc: String, lines: Array, answers: Array) -> void:
	answers.append(await screen.show_lines({"id": npc, "name_key": "NPC_" + npc.to_upper()}, lines, [{"action": "close", "text_key": "DLG_CHOICE_CLOSE"}]))
