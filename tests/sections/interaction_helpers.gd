extends RefCounted
const SECTION := "interaction_helpers"
const TIMEOUT_S := 120.0
const Callback := preload("res://tests/sections/multiplayer_callback_ownership.gd")

func run(t) -> void:
	for kind: String in ["normal", "direct"]:
		await _mayor(t, kind)

func _mayor(t, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	QuestManager.accept_quest(&"intro_lottery")
	var mayor := Npc2D.create({"id": "mayor_lyra", "wander": "0"})
	mayor.area = t.world().area
	t.world().area.objects.add_child(mayor)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	mayor.interact(t.player())
	t.check(kind + "_mayor_authored_page", mayor.is_talking and ui.is_open() and ui._lines.any(func(row): return row.get("text_key", "") == "DLG_LYRA_GREET_1") and bool(GameManager.get_flag(&"mayor_welcome_pending", false)))
	await t.page_to_choices(ui)
	t.check(kind + "_mayor_read_to_choice", ui.is_open() and ui._buttons.size() > 0 and ui._shown == ui._lines.size())
	var saves: Node = t.autoload("SaveManager")
	var payload: Dictionary = saves.gather_payload()
	var original := PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var winner: Dictionary = {}
	var observer := func(key, value):
		if key != &"mayor_welcome_seen" or value != true or not observed.is_empty(): return
		observed.append(true)
		if kind == "direct":
			observed.append(saves._apply_payload(payload).ok)
			observed.append(PlayerRegistry.peek_state(&"p0") != original)
			observed.append(bool(GameManager.get_flag(&"mayor_welcome_pending", false)))
			winner.merge(Callback.new()._snapshot(saves))
	EventBus.flag_changed.connect(observer)
	ui._pick(ui._buttons[-1].get_meta("choice"))
	EventBus.flag_changed.disconnect(observer)
	if kind == "direct":
		t.check("direct_mayor_replacement_reached", observed == [true, true, true, true], "immediate replacement receipt: %s" % [observed])
		var after := Callback.new()._snapshot(saves)
		var delta := {}
		for key in winner:
			if winner[key] != after[key]: delta[key] = [winner[key], after[key]]
		t.check("direct_mayor_no_pending_clear_suffix", not winner.is_empty() and after == winner, "earned seen callback must not clear the replacement's unread obligation; delta=%s" % [delta])
	else:
		t.check("normal_mayor_earned_effects", observed == [true] and bool(GameManager.get_flag(&"mayor_welcome_seen", false)) and not bool(GameManager.get_flag(&"mayor_welcome_pending", false)))
	await t.frames(3)
	if kind == "direct": t.check("direct_mayor_deferred_winner_unchanged", Callback.new()._snapshot(saves) == winner)
	ui.close()
	await t.go_menu()
