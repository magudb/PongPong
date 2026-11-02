extends RefCounted
## Real UI await, deferred argument conversion and actual actor tree-exit seams.
const SECTION := "npc_owner_lifecycle"
const TIMEOUT_S := 90.0
const PAGE := {"lines": [{"text_key": "LC_SMITH_THORIN_ACTIVITY"}], "choices": [{"text_key": "DLG_CHOICE_CLOSE", "action": "close"}]}

func run(t) -> void:
	await _run(t)

func run_windowed(t) -> void:
	await _run(t)

func _snapshot(t) -> Dictionary:
	return {"social": t.autoload("SocialManager").to_dict().duplicate(true), "flags": t.autoload("GameManager").world_flags.duplicate(true), "p0": PlayerRegistry.for_player(&"p0", func(): return {"economy": t.autoload("EconomyManager").to_dict().duplicate(true), "quests": t.autoload("QuestManager").to_dict().duplicate(true)}), "p1": PlayerRegistry.for_player(&"p1", func(): return {"economy": t.autoload("EconomyManager").to_dict().duplicate(true), "quests": t.autoload("QuestManager").to_dict().duplicate(true)})}

func _body(t) -> Node2D:
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	return body

func _actor(t) -> Npc2D:
	var actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	t.world().add_child(actor)
	return actor

func _run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	for mode in ["resume", "cancel", "exit"]:
		var actor := _actor(t)
		var body := _body(t)
		var ended: Array = []
		var on_end := func(): ended.append(str(PlayerRegistry._acting_id))
		bus.dialogue_ended.connect(on_end)
		actor._begin_followup(body, PAGE.duplicate(true))
		await t.frames(3)
		t.check(mode + "_real_await_live_registered_owner", actor.is_talking and actor._held and actor._talk_player == body and screen._session and PlayerRegistry.registered_id(body) == &"p1" and PlayerRegistry._acting_id == &"")
		t.world()._unregister_player(body)
		await t.frames(3)
		t.check(mode + "_body_really_freed_while_awaiting", not is_instance_valid(body) and actor.is_talking and screen._session)
		var before := _snapshot(t)
		# A conflicting caller scope must survive every synchronous resumption.
		PlayerRegistry.for_player(&"p0", func():
			if mode == "exit":
				t.world().remove_child(actor)
			elif mode == "cancel":
				screen.close()
			else:
				screen._finish(true, {"action": "close"})
			t.check(mode + "_caller_scope_restored", PlayerRegistry._acting_id == &"p0"))
		await t.frames(3)
		t.check(mode + "_exactly_once_cleanup", not actor.is_talking and not actor._held and actor._talk_player == null and not screen._session and not screen.is_open() and not gm.is_modal_open(&"dialogue") and ended == ["p0"])
		t.check(mode + "_no_departed_owner_writes", _snapshot(t) == before and PlayerRegistry._acting_id == &"")
		bus.dialogue_ended.disconnect(on_end)
		# Do not let the unfixed RED strand the following diagnostic cases.
		if screen.is_open(): screen.close()
		actor.free()
		await t.frames(2)
	# Carry an actually freed argument through both production deferred entries.
	for method in [&"_begin_followup", &"interact"]:
		var actor := _actor(t)
		var body := _body(t)
		var before := _snapshot(t)
		if method == &"_begin_followup": actor.call_deferred(method, body, PAGE.duplicate(true))
		else: actor.call_deferred(method, body)
		t.world()._unregister_player(body)
		body.free()
		await t.frames(3)
		t.check(str(method) + "_freed_deferred_owner_refused", not actor.is_talking and not actor._held and actor._talk_player == null and not screen._session and _snapshot(t) == before and PlayerRegistry._acting_id == &"")
		actor.free()
	gm.clear_config_overrides()
	await _welcome_observers(t)

## Same authored page and real input in the control and callback-departure cases.
## No expected engine-error allowance: stale typed dispatch must fail the audit.
func _welcome_observers(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	var authored: Array = []
	for mode in ["control", "remove", "free", "reentrant_end", "reentrant_restart"]:
		await t.start_world()
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		var body := _body(t)
		var actor := Npc2D.create({"id": "mayor_lyra", "wander": "0"})
		t.world().add_child(actor)
		var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
		var observed: Array = []
		var ended: Array = []
		var on_end := func(): ended.append(str(PlayerRegistry._acting_id))
		bus.dialogue_ended.connect(on_end)
		actor.interact(body)
		var keys: Array = screen._lines.map(func(row): return str(row.get("text_key", "")))
		if mode == "control": authored = keys.duplicate()
		t.check(mode + "_welcome_actual_registered_p1_authored_await", actor.is_talking and actor._held and actor._talk_player == body and PlayerRegistry.registered_id(body) == &"p1" and screen._session and keys == authored and keys.has("DLG_LYRA_GREET_1") and keys.has("DLG_LYRA_LOTTERY") and not bool(gm.get_flag(&"mayor_welcome_seen", false)))
		await t.page_to_choices(screen)
		await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
		var before := _snapshot(t)
		var body_ref: WeakRef = weakref(body)
		var observe := func(flag, value):
			if flag != &"mayor_welcome_seen" or value != true: return
			observed.append({"scope": str(PlayerRegistry._acting_id), "pending": bool(gm.get_flag(&"mayor_welcome_pending", false)), "session": actor.is_talking})
			if mode == "remove" or mode == "free":
				var owned: Node2D = body_ref.get_ref()
				t.world()._unregister_player(owned)
				if mode == "free": owned.free()
				observed.append({"departed": not is_instance_valid(owned) or not owned.is_inside_tree(), "freed": not is_instance_valid(owned)})
			elif mode in ["reentrant_end", "reentrant_restart"]:
				actor._end_talk(0, false)
				if mode == "reentrant_restart": actor.interact(body_ref.get_ref())
		bus.flag_changed.connect(observe)
		screen._buttons[-1].grab_focus()
		if mode == "reentrant_end":
			for button in screen._buttons:
				if button.get_meta("choice").get("action") == "quest_accept": button.grab_focus()
		PlayerRegistry.for_player(&"p0", func():
			t.tap(&"ui_accept")
			t.check(mode + "_welcome_input_restores_caller_scope", PlayerRegistry._acting_id == &"p0"))
		await t.frames(3)
		if mode == "reentrant_restart":
			t.check("welcome_old_completion_preserves_reentrant_new_session", actor.is_talking and actor._held and actor._talk_player == body and screen._session and screen.is_open() and ended == ["p1"])
			t.tap_key(KEY_ESCAPE)
			await t.frames(3)
		t.check(mode + "_welcome_synchronous_observer_before_return", not observed.is_empty() and observed[0] == {"scope": "p1", "pending": true, "session": true} and (mode not in ["remove", "free"] or observed.size() == 2 and observed[1] == {"departed": true, "freed": mode == "free"}), str(observed))
		t.check(mode + "_welcome_authored_effects_preserved", bool(gm.get_flag(&"mayor_welcome_seen", false)) and not bool(gm.get_flag(&"mayor_welcome_pending", false)))
		t.check(mode + "_welcome_exactly_once_cleanup", not actor.is_talking and not actor._held and actor._talk_player == null and not screen._session and not screen.is_open() and not gm.is_modal_open(&"dialogue") and ended == (["p1", "p1"] if mode == "reentrant_restart" else ["p1"]), str(ended))
		var after := _snapshot(t)
		t.check(mode + "_welcome_no_quest_or_reward_cross_writes", after.p0 == before.p0 and after.p1 == before.p1 and PlayerRegistry._acting_id == &"")
		bus.flag_changed.disconnect(observe)
		bus.dialogue_ended.disconnect(on_end)
		if screen.is_open(): screen.close()
		actor.free()
		if is_instance_valid(body) and body.is_inside_tree(): t.world()._unregister_player(body)
		await t.frames(2)
	gm.clear_config_overrides()
	await _begin_observers(t)

func _begin_observers(t) -> void:
	for entry in ["interact", "followup"]:
		await t.start_world()
		var body := _body(t)
		var body_ref: WeakRef = weakref(body)
		var actor := _actor(t)
		var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
		var bus: Node = t.autoload("EventBus")
		var ended: Array = []
		var started: Array = []
		var on_end := func(): ended.append(str(PlayerRegistry._acting_id))
		var on_start := func(_npc, _dialogue):
			started.append(str(PlayerRegistry._acting_id))
			var owned: Node2D = body_ref.get_ref()
			t.world()._unregister_player(owned)
			owned.free()
		bus.dialogue_ended.connect(on_end)
		bus.dialogue_started.connect(on_start, CONNECT_ONE_SHOT)
		if entry == "interact": actor.interact(body)
		else: actor._begin_followup(body, PAGE.duplicate(true))
		await t.frames(3)
		t.check(entry + "_start_observer_really_freed_owner", started == ["p1"] and not is_instance_valid(body))
		t.check(entry + "_start_observer_no_stranded_ui_or_hold", not actor.is_talking and not actor._held and actor._talk_player == null and not screen._session and not screen.is_open() and ended == [""], str(ended))
		bus.dialogue_ended.disconnect(on_end)
		actor.free()
		await t.frames(2)
