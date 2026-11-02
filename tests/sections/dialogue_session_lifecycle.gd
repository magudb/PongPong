extends RefCounted
## Actual registered-body/UI entrypoint tracers; no forged session state.
const SECTION := "dialogue_session_lifecycle"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await _run(t)

func run_windowed(t) -> void:
	await _run(t)

func _actor(t, id: String) -> Npc2D:
	var actor := Npc2D.create({"id": id, "wander": "0"})
	t.world().add_child(actor)
	return actor

func _replacement(actor: WeakRef, body: WeakRef, screen: WeakRef, seen: Array) -> void:
	var npc = actor.get_ref()
	var player = body.get_ref()
	var ui = screen.get_ref()
	if not is_instance_valid(npc) or not is_instance_valid(player) or not is_instance_valid(ui): return
	npc.interact(player)
	seen.append(npc.is_talking and ui.is_open())
	ui.close()
	seen.append(not npc.is_talking and not ui.is_open())

func _run(t) -> void:
	for kind in ["followup", "quizretry"]:
		for replace in [false, true]:
			await t.start_world()
			var gm: Node = t.autoload("GameManager")
			var bus: Node = t.autoload("EventBus")
			gm.set_config_override("time.minutes_per_real_second", 0.0)
			var actor := _actor(t, "mayor_lyra" if kind == "followup" else "baker_maja")
			var other := _actor(t, "smith_thorin")
			var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
			if kind == "quizretry":
				t.autoload("QuestManager").accept_quest(&"math_bakery_counts")
				t.check("quiz_accept_actual_quest_" + str(replace), t.autoload("QuestManager").is_active(&"math_bakery_counts") and gm.get_flag(&"math_bakery_active", false))
			actor.interact(t.player())
			await t.page_to_choices(screen)
			var wanted: Button
			for button in screen._buttons:
				var choice: Dictionary = button.get_meta("choice")
				if kind == "followup" and choice.get("action") == "social_more": wanted = button
				if kind == "quizretry" and choice.get("action") == "math_answer" and choice.get("answer") != choice.get("correct"): wanted = button
			var label: String = kind + ("_interposed" if replace else "_control")
			t.check(label + "_actual_offered_choice", actor.is_talking and screen.is_open() and wanted != null and PlayerRegistry.registered_id(t.player()) == &"p0")
			if wanted == null:
				screen.close()
				actor.free()
				other.free()
				continue
			var seen: Array = []
			var callback := func():
				if replace: _replacement.call_deferred(weakref(other), weakref(t.player()), weakref(screen), seen)
			bus.dialogue_ended.connect(callback, CONNECT_ONE_SHOT)
			await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
			wanted.grab_focus()
			t.tap_key(KEY_ENTER)
			await t.frames(4)
			t.check(label + "_replacement_opened_and_ended_before_dispatch", seen == ([true, true] if replace else []), str(seen))
			t.check(label + "_dispatch_origin", not actor.is_talking and not screen.is_open() if replace else actor.is_talking and screen.is_open(), "talk=%s open=%s" % [actor.is_talking, screen.is_open()])
			t.check(label + "_quiz_wrong_does_not_commit_answer", not gm.get_flag(&"math_maja_q1", false))
			if screen.is_open(): screen.close()
			actor.free()
			other.free()
			gm.clear_config_overrides()
	await _home(t)
	await _exit(t)

func _home(t) -> void:
	for replace in [false, true]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var bus: Node = t.autoload("EventBus")
		var actor := _actor(t, "smith_thorin")
		var builder := _actor(t, "fairy_builder")
		var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
		gm.set_flag(gm.FLAG_HOME_UPGRADE_DONE, 2)
		var seen: Array = []
		var observe := func(flag, _value):
			if flag != &"friend_last_smith_thorin": return
			seen.append("social_flag")
			if replace: builder.interact(t.player())
		bus.flag_changed.connect(observe)
		actor.interact(t.player())
		await t.page_to_choices(screen)
		var close_button: Button
		for button in screen._buttons:
			if button.get_meta("choice").get("action") == "close": close_button = button
		t.check("home_real_chat_control_" + str(replace), actor.is_talking and close_button != null and screen.is_open())
		await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
		close_button.grab_focus()
		t.tap_key(KEY_ENTER)
		await t.frames(3)
		t.check("home_social_observer_reached_" + str(replace), seen == ["social_flag"], str(seen))
		t.check("home_old_end_preserves_builder_flag_" + str(replace), gm.flag_int(gm.FLAG_HOME_UPGRADE_DONE) == 2)
		if replace:
			t.check("home_replacement_real_builder_open", builder.is_talking and screen.is_open() and screen._speaker.get("id") == "fairy_builder")
			screen.close()
			t.check("home_matching_builder_cancel_clears_own_snapshot", gm.flag_int(gm.FLAG_HOME_UPGRADE_DONE) == 0)
		bus.flag_changed.disconnect(observe)
		actor.free()
		builder.free()

func _exit(t) -> void:
	for replace in [false, true]:
		await t.start_world()
		var bus: Node = t.autoload("EventBus")
		var actor := _actor(t, "smith_thorin")
		var other := _actor(t, "baker_maja")
		var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
		var seen: Array = []
		actor.interact(t.player())
		t.check("exit_real_actor_open_" + str(replace), actor.is_talking and screen.is_open())
		var on_end := func():
			if not replace: return
			# Explicitly close A before fresh B input; old exit may not close B.
			screen.close()
			var request: RefCounted = other.interact(t.player())
			# Approved serialization reserves B here; activation follows A's bundle.
			seen.append(request != null and (not request.resolved or other.is_talking and screen.is_open()))
		bus.dialogue_ended.connect(on_end, CONNECT_ONE_SHOT)
		t.world().remove_child(actor)
		await t.frames(3)
		t.check("exit_observer_replacement_admitted_" + str(replace), seen == ([true] if replace else []), str(seen))
		t.check("exit_old_cleanup_does_not_close_replacement_" + str(replace), other.is_talking and screen.is_open() if replace else not screen.is_open())
		if screen.is_open(): screen.close()
		actor.free()
		other.free()
