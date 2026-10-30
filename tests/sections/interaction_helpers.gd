extends RefCounted
const SECTION := "interaction_helpers"
const TIMEOUT_S := 120.0
const Callback := preload("res://tests/sections/multiplayer_callback_ownership.gd")

func run(t) -> void:
	var slice := OS.get_environment("B3A_SLICE")
	if slice in ["", "all", "mayor"]:
		for kind: String in ["normal", "direct", "failed"]:
			await _mayor(t, kind)
	if slice in ["", "all", "departure"]:
		for kind: String in ["body", "actor", "actor_free", "seen_body", "seen_actor", "profile"]:
			await _departure(t, kind)
	if slice in ["", "all", "math"]:
		for kind: String in ["normal", "flag", "objective", "failed"]:
			await _math(t, kind)
	if slice in ["", "all", "water"]:
		for kind: String in ["normal", "direct", "failed"]:
			await _water(t, kind)
	if slice in ["", "all", "story"]:
		for kind: String in ["mother_normal", "mother_direct", "mother_failed", "garden_normal", "garden_direct", "garden_failed"]:
			await _story(t, kind)
	if slice in ["", "all", "social"]:
		for kind: String in ["normal", "last", "points", "failed"]:
			await _social(t, kind)

func _departure(t, kind: String) -> void:
	if not await t.start_world(): return
	QuestManager.accept_quest(&"intro_lottery")
	var npc := Npc2D.create({"id": "mayor_lyra", "wander": "0"})
	t.world().area.objects.add_child(npc)
	var body: Node = t.player()
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	npc.interact(body)
	await t.page_to_choices(ui)
	var profile := PlayerRegistry.peek_state(&"p0")
	var origin := npc._talk_origin
	var entered: Array = []
	var ended: Array = []
	var on_end := func(): ended.append(true)
	var depart := func():
		if not entered.is_empty(): return
		entered.append(true)
		if kind.ends_with("body"): t.world()._unregister_player(body)
		elif kind == "actor_free": npc.free()
		elif kind.ends_with("actor"): npc.get_parent().remove_child(npc)
		else: PlayerRegistry.reset_states()
		entered.append(EventBus.interaction_current(origin))
	var on_choice := func(_action, _data):
		if not kind.begins_with("seen_"): depart.call()
	var on_flag := func(key, value):
		if kind.begins_with("seen_") and key == &"mayor_welcome_seen" and value == true: depart.call()
	t.check(kind + "_departure_read_page", npc.is_talking and ui.is_open() and ui._shown == ui._lines.size() and ui._lines.any(func(row): return row.get("text_key", "") == "DLG_LYRA_GREET_1"))
	EventBus.dialogue_ended.connect(on_end)
	ui.choice_selected.connect(on_choice)
	EventBus.flag_changed.connect(on_flag)
	ui._pick(ui._buttons[-1].get_meta("choice"))
	EventBus.flag_changed.disconnect(on_flag)
	ui.choice_selected.disconnect(on_choice)
	EventBus.dialogue_ended.disconnect(on_end)
	if kind == "profile":
		t.check("profile_only_departure_revokes_earned_effects", entered == [true, false] and PlayerRegistry.peek_state(&"p0") != profile and not bool(GameManager.get_flag(&"mayor_welcome_seen", false)) and bool(GameManager.get_flag(&"mayor_welcome_pending", false)))
	else:
		t.check(kind + "_departure_preserves_earned_page", entered == [true, true] and PlayerRegistry.peek_state(&"p0") == profile and bool(GameManager.get_flag(&"mayor_welcome_seen", false)) and not bool(GameManager.get_flag(&"mayor_welcome_pending", false)))
		t.check(kind + "_departure_weekly_accounting_once", SocialManager.points("mayor_lyra") == SocialData.cfg_int("chat_points", 100) and not SocialManager.chat_available("mayor_lyra"))
	t.check(kind + "_departure_cleanup_once", ended == [true] and (not is_instance_valid(npc) or not npc.is_talking and not npc._held) and not ui.is_open())
	if kind.ends_with("actor"): npc.queue_free()
	await t.frames(3)
	await t.go_menu()

func _math(t, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	QuestManager.accept_quest(&"math_bakery_counts")
	var npc := Npc2D.create({"id": "baker_maja", "wander": "0"})
	t.world().area.objects.add_child(npc)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	npc.interact(t.player())
	await t.page_to_choices(ui)
	var answer := {}
	for depth in 4:
		await t.page_to_choices(ui)
		var more := {}
		for button in ui._buttons:
			var choice: Dictionary = button.get_meta("choice")
			if choice.get("action") == "math_answer" and choice.get("answer") == choice.get("correct"): answer = choice
			if choice.get("action") == "social_more": more = choice
		if not answer.is_empty() or more.is_empty(): break
		ui._pick(more)
		await t.frames(2)
	t.check(kind + "_math_real_eligible_answer", ui.is_open() and not answer.is_empty() and ui._shown == ui._lines.size() and not QuestManager.get_objective_progress(&"math_bakery_counts", &"math_maja_q1").done, "actual choices=%s" % [ui._choices])
	var saves: Node = t.autoload("SaveManager")
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("math_late", late, 1000)
	var payload: Dictionary = saves.gather_payload()
	var original := PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var winner: Dictionary = {}
	var notices: Array = []
	var replace := func():
		if kind == "normal" or not observed.is_empty(): return
		observed.append(true)
		if kind == "failed": late.rejects = 1
		observed.append(saves._apply_payload(payload).ok)
		observed.append(PlayerRegistry.peek_state(&"p0") == original)
		winner.merge(Callback.new()._snapshot(saves))
	var on_flag := func(key, value):
		if key == &"math_maja_q1" and value == true and kind in ["flag", "failed"]: replace.call()
	var on_objective := func(_pid, qid, oid, _current, _target):
		if qid == &"math_bakery_counts" and oid == &"math_maja_q1" and kind == "objective": replace.call()
	var on_notice := func(title, _message, _icon):
		if title == TranslationServer.translate("MATH_CORRECT_TITLE"): notices.append(title)
	EventBus.flag_changed.connect(on_flag)
	EventBus.quest_objective_updated.connect(on_objective)
	EventBus.notification_posted.connect(on_notice)
	if not answer.is_empty(): ui._pick(answer)
	EventBus.flag_changed.disconnect(on_flag)
	EventBus.quest_objective_updated.disconnect(on_objective)
	EventBus.notification_posted.disconnect(on_notice)
	if kind in ["flag", "objective"]:
		t.check(kind + "_math_replacement_reached", observed == [true, true, false])
		t.check(kind + "_math_no_suffix", Callback.new()._snapshot(saves) == winner and notices.is_empty())
	else:
		t.check(kind + "_math_earned", (observed.is_empty() if kind == "normal" else observed == [true, false, true] and late.calls == 2) and QuestManager.get_objective_progress(&"math_bakery_counts", &"math_maja_q1").done and notices.size() == 1)
	await t.frames(3)
	if kind in ["flag", "objective"]:
		t.check(kind + "_math_no_deferred_followup", Callback.new()._snapshot(saves) == winner and not ui.is_open() and not npc.is_talking)
	ui.close()
	saves.unregister_section("math_late")
	late.free()
	await t.go_menu()

func _water(t, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	QuestManager.accept_quest(SecretGardenStory.QUEST)
	for index in 5: SecretGardenStory.advance(index)
	await t.world().travel(&"secret_garden", &"default")
	var marker: Node
	for node in t.world().area.objects.get_children():
		if node is SecretGardenMarker and node.kind == "beds":
			marker = node
			break
	var saves: Node = t.autoload("SaveManager")
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("water_late", late, 1000)
	var payload: Dictionary = saves.gather_payload()
	var original := PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var winner: Dictionary = {}
	var on_flag := func(key, _value):
		if key != SecretGardenStory.WATER_DAY or kind == "normal" or not observed.is_empty(): return
		observed.append(true)
		if kind == "failed": late.rejects = 1
		observed.append(saves._apply_payload(payload).ok)
		observed.append(PlayerRegistry.peek_state(&"p0") == original)
		winner.merge(Callback.new()._snapshot(saves))
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	t.check(kind + "_water_eligible", marker != null and SecretGardenStory.step() == 5 and saves.validate_payload(payload).ok)
	if marker != null: marker.interact(t.player())
	await t.page_to_choices(ui)
	var work := {}
	for button in ui._buttons:
		var choice: Dictionary = button.get_meta("choice")
		if choice.get("action") == "garden_work": work = choice
	t.check(kind + "_water_authored_choice", ui.is_open() and not work.is_empty() and ui._shown == ui._lines.size())
	EventBus.flag_changed.connect(on_flag)
	if not work.is_empty(): ui._pick(work)
	EventBus.flag_changed.disconnect(on_flag)
	if kind == "direct":
		t.check("water_replacement_reached", observed == [true, true, false])
		t.check("water_no_objective_suffix", Callback.new()._snapshot(saves) == winner and SecretGardenStory.step() == 5)
	else:
		t.check(kind + "_water_earned", (observed.is_empty() if kind == "normal" else observed == [true, false, true] and late.calls == 2) and SecretGardenStory.step() == 6 and GameManager.flag_int(SecretGardenStory.WATER_DAY) == GameManager.total_day())
	saves.unregister_section("water_late")
	late.free()
	ui.close()
	await t.go_menu()

func _story(t, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var mother := kind.begins_with("mother")
	var id := "mapseller_natteblik" if mother else "gardener_hoppe"
	if mother:
		GameManager.set_flags({"forest_mother_version": 1, "forest_mother_v1_marked_lamp": GameManager.total_day()})
		MotherStory.sync()
	else:
		QuestManager.accept_quest(SecretGardenStory.QUEST)
		SecretGardenStory.advance(0)
	var npc := Npc2D.create({"id": id, "wander": "0"})
	t.world().area.objects.add_child(npc)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	npc.interact(t.player())
	var selected: bool = await _select(t, ui, "mother_story" if mother else "garden_story")
	await t.frames(2)
	await t.page_to_choices(ui)
	var page: Dictionary = MotherStory.topic_page(id) if mother else SecretGardenStory.topic_page(id)
	t.check(kind + "_actual_authored_topic", selected and ui.is_open() and ui._shown == ui._lines.size() and (page.get("mother_evidence") == "map_account" if mother else page.get("garden_step") == 1))
	var saves: Node = t.autoload("SaveManager")
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("story_late", late, 1000)
	var payload: Dictionary = saves.gather_payload()
	var original := PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var winner: Dictionary = {}
	var evidence_events: Array = []
	var replace := func():
		if kind.ends_with("normal") or not observed.is_empty(): return
		observed.append(true)
		if kind.ends_with("failed"): late.rejects = 1
		observed.append(saves._apply_payload(payload).ok)
		observed.append(PlayerRegistry.peek_state(&"p0") == original)
		winner.merge(Callback.new()._snapshot(saves))
	var on_flag := func(key, _value):
		if mother and key == &"forest_mother_v1_map_account": replace.call()
	var on_objective := func(_pid, qid, oid, _current, _target):
		if not mother and qid == SecretGardenStory.QUEST and oid == &"ask_hoppe": replace.call()
	var on_event := func(event, data):
		if event == &"forest_mother_evidence": evidence_events.append(data.duplicate(true))
	EventBus.flag_changed.connect(on_flag)
	EventBus.quest_objective_updated.connect(on_objective)
	EventBus.game_event.connect(on_event)
	ui._pick(ui._buttons[-1].get_meta("choice"))
	EventBus.flag_changed.disconnect(on_flag)
	EventBus.quest_objective_updated.disconnect(on_objective)
	EventBus.game_event.disconnect(on_event)
	if kind.ends_with("direct"):
		t.check(kind + "_replacement_reached", observed == [true, true, false])
		t.check(kind + "_no_story_suffix", Callback.new()._snapshot(saves) == winner and evidence_events.is_empty(), "old sync/autosave/evidence cannot run for winner")
	else:
		t.check(kind + "_earned_evidence", (observed.is_empty() if kind.ends_with("normal") else observed == [true, false, true] and late.calls == 2) and (MotherStory.has("map_account") and QuestManager.get_objective_progress(MotherStory.quest_id("s03"), &"map_account").done and evidence_events.size() == 1 if mother else SecretGardenStory.step() == 2), "receipt=%s evidence=%s" % [observed, evidence_events])
	t.check(kind + "_sync_unwound", not MotherStory._syncing)
	await t.frames(3)
	if kind.ends_with("direct"):
		t.check(kind + "_deferred_story_winner", Callback.new()._snapshot(saves) == winner)
		npc.interact(t.player())
		var next_selected: bool = await _select(t, ui, "mother_story" if mother else "garden_story")
		await t.frames(2)
		await t.page_to_choices(ui)
		if ui.is_open(): ui._pick(ui._buttons[-1].get_meta("choice"))
		t.check(kind + "_next_story_progress", next_selected and (MotherStory.has("map_account") if mother else SecretGardenStory.step() == 2) and not MotherStory._syncing)
	saves.unregister_section("story_late")
	late.free()
	ui.close()
	await t.go_menu()

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
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("mayor_late", late, 1000)
	var payload: Dictionary = saves.gather_payload()
	var original := PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var winner: Dictionary = {}
	var observer := func(key, value):
		if key != &"mayor_welcome_seen" or value != true or not observed.is_empty(): return
		observed.append(true)
		if kind in ["direct", "failed"]:
			if kind == "failed": late.rejects = 1
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
		t.check(kind + "_mayor_earned_effects", (observed == [true] if kind == "normal" else observed == [true, false, false, true] and late.calls == 2) and bool(GameManager.get_flag(&"mayor_welcome_seen", false)) and not bool(GameManager.get_flag(&"mayor_welcome_pending", false)))
	await t.frames(3)
	if kind == "direct": t.check("direct_mayor_deferred_winner_unchanged", Callback.new()._snapshot(saves) == winner)
	ui.close()
	saves.unregister_section("mayor_late")
	late.free()
	await t.go_menu()
