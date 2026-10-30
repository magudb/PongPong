extends RefCounted
const SECTION := "interaction_helpers"
const TIMEOUT_S := 120.0
const Callback := preload("res://tests/sections/multiplayer_callback_ownership.gd")

func run(t) -> void:
	var slice := OS.get_environment("B3A_SLICE")
	if slice in ["", "all", "mayor"]:
		for kind: String in ["normal", "direct"]:
			await _mayor(t, kind)
	if slice in ["", "all", "social"]:
		for kind: String in ["normal", "last", "points", "failed"]:
			await _social(t, kind)

func _social(t, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var npc := Npc2D.create({"id": "baker_maja", "wander": "0"})
	t.world().area.objects.add_child(npc)
	SocialManager.debug_set_hearts("baker_maja", 1)
	var other := PlayerRegistry.state(&"p1")
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	var saves: Node = t.autoload("SaveManager")
	saves.register_section("helpers_late", late, 1000)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	npc.interact(t.player())
	await t.page_to_choices(ui)
	var points := SocialManager.points("baker_maja")
	var cookies := EconomyManager.count_item(&"cookie")
	var original := PlayerRegistry.peek_state(&"p0")
	PlayerRegistry.for_player(&"p1", func():
		EconomyManager.from_dict(EconomyManager.to_dict())
		QuestManager.from_dict(QuestManager.to_dict()))
	SocialManager.debug_set_hearts("baker_maja", 2)
	var payload: Dictionary = saves.gather_payload()
	SocialManager.row_of("baker_maja")["p"] = points
	SocialManager._mirror("baker_maja")
	var unrelated := other.to_dict().duplicate(true)
	t.check(kind + "_social_eligible_real_baker", npc.is_talking and ui.is_open() and ui._buttons.size() > 0 and SocialManager.chat_available("baker_maja") and SocialManager.hearts("baker_maja") == 1 and SocialData.sample_of("baker_maja").item == "cookie" and saves.validate_payload(payload).ok)
	var observed: Array = []
	var winner: Dictionary = {}
	var replace := func():
		if not observed.is_empty() or kind == "normal": return
		observed.append(true)
		if kind == "failed": late.rejects = 1
		observed.append(saves._apply_payload(payload).ok)
		observed.append(PlayerRegistry.peek_state(&"p0") == original)
		winner.merge(Callback.new()._snapshot(saves))
	var on_flag := func(key, _value):
		if key == &"friend_last_baker_maja" and kind == "last": replace.call()
	var on_friend := func(_pid, friend, _hearts):
		if friend == &"baker_maja" and kind in ["points", "failed"]: replace.call()
	EventBus.flag_changed.connect(on_flag)
	EventBus.friend_changed.connect(on_friend)
	ui._pick(ui._buttons[-1].get_meta("choice"))
	EventBus.flag_changed.disconnect(on_flag)
	EventBus.friend_changed.disconnect(on_friend)
	if kind in ["last", "points"]:
		t.check(kind + "_social_successful_replacement", observed == [true, true, false])
		t.check(kind + "_social_no_winner_suffix", Callback.new()._snapshot(saves) == winner and EconomyManager.count_item(&"cookie") == cookies, "old weekly completion must not award winner points/sample")
	else:
		t.check(kind + "_social_earned_once", (observed.is_empty() if kind == "normal" else observed == [true, false, true] and late.calls == 2) and SocialManager.points("baker_maja") == points + SocialData.cfg_int("chat_points", 100) and EconomyManager.count_item(&"cookie") == cookies + 1, "receipt=%s calls=%s points=%s cookies=%s" % [observed, late.calls, SocialManager.points("baker_maja"), EconomyManager.count_item(&"cookie")])
	t.check(kind + "_social_unrelated_player", (PlayerRegistry.peek_state(&"p1") == other if kind in ["normal", "failed"] else true) and PlayerRegistry.peek_state(&"p1").to_dict() == unrelated and PlayerRegistry.acting_id() == &"p0")
	await t.frames(3)
	if kind in ["last", "points"]: t.check(kind + "_social_deferred_winner", Callback.new()._snapshot(saves) == winner)
	var before_next := SocialManager.points("baker_maja")
	var available := SocialManager.chat_available("baker_maja")
	npc.interact(t.player())
	await t.page_to_choices(ui)
	ui._pick(ui._buttons[-1].get_meta("choice"))
	t.check(kind + "_social_next_live_once", SocialManager.points("baker_maja") == before_next + (SocialData.cfg_int("chat_points", 100) if available else 0) and EconomyManager.count_item(&"cookie") == cookies + 1)
	npc.interact(t.player())
	var selected: bool = await _select(t, ui, "social_topic")
	await t.frames(2)
	await t.page_to_choices(ui)
	var topic: Dictionary = {} if not ui.is_open() else {"shown": ui._shown, "lines": ui._lines.size()}
	t.check(kind + "_actual_topic_page", selected and ui.is_open() and ui._lines.size() == 1 and str(ui._lines[0].text_key).begins_with("SOC_") and int(topic.get("shown", 0)) == int(topic.get("lines", -1)))
	if ui.is_open(): ui._pick(ui._buttons[-1].get_meta("choice"))
	t.check(kind + "_actual_topic_earned_once", int(SocialManager.row_of("baker_maja").tp) == SocialManager.today() and not SocialManager.row_of("baker_maja").kn.is_empty() and EconomyManager.count_item(&"cookie") == cookies + 1)
	saves.unregister_section("helpers_late")
	late.free()
	ui.close()
	await t.go_menu()

func _select(t, ui: Node, action: String) -> bool:
	for depth in 4:
		await t.page_to_choices(ui)
		if not ui.is_open(): return false
		for button in ui._buttons:
			var choice: Dictionary = button.get_meta("choice")
			if str(choice.get("action", "")) == action:
				ui._pick(choice)
				return true
		var more := {}
		for button in ui._buttons:
			var choice: Dictionary = button.get_meta("choice")
			if str(choice.get("action", "")) == "social_more": more = choice
		if more.is_empty(): return false
		ui._pick(more)
		await t.frames(2)
	return false

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
