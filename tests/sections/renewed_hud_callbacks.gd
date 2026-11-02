extends RefCounted
const SECTION := "renewed_hud_callbacks"
const TIMEOUT_S := 180.0
const MODEL := preload("res://tests/sections/renewed_hud_model.gd")
const GRAPH := preload("res://tests/sections/renewed_marker_refresh_model.gd")
const OLD := preload("res://tests/sections/persistence_marker_scope.gd")

# A declared callee boundary delegates the actual Social reader unchanged,
# recording its recipient and injecting only a post-read replacement callback.
class FeedbackBoundary extends Node:
	var actual: Node
	var observe: Callable
	var calls: Array = []
	var snapshots: Array = []
	func has_pending_feedback(npc: StringName) -> bool:
		calls.append([PlayerRegistry.acting_id(), PlayerRegistry._states.get(PlayerRegistry.acting_id())])
		snapshots.append({"stage":"before_read", "keys":PlayerRegistry._states.keys().duplicate()})
		var result: bool = actual.has_pending_feedback(npc)
		snapshots.append({"stage":"after_read", "keys":PlayerRegistry._states.keys().duplicate()})
		if observe.is_valid(): observe.call()
		snapshots.append({"stage":"after_observe", "keys":PlayerRegistry._states.keys().duplicate()})
		return result

func run(t) -> void:
	for seam in ["remove", "add", "nested_reset", "nested_load", "queue"]:
		await _replacement(t, seam)
	await _rejoin(t)
	await _reset_listener(t)
	await _friends(t)
	for successor in [false, true]: await _feedback_boundary(t, successor)

func _register(qm: Node, id: StringName) -> void:
	qm.register_quest_from_lua({"id":str(id), "title_key":"HUD_SAVED" if id == &"zz_hud_old" else "HUD_SAVE_FAILED", "objectives":[{"id":"work", "on":"manual", "target":2, "text_key":"HUD_SAVED"}], "rewards":{}, "meta":{}})

func _replacement(t, seam: String) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var sm: Node = t.autoload("SaveManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	sm.autosave_enabled = false
	sm.save_dir = "user://renewed_hud_callbacks"
	var hud: Control = t.tree.get_first_node_in_group("game_ui").get_screen(&"hud")
	_register(qm, &"zz_hud_old")
	_register(qm, &"zz_hud_fresh")
	t.check(seam+"_real_old_quest_admitted", qm.accept_quest(&"zz_hud_old"))
	var previous: PlayerState = PlayerRegistry._states[&"p0"]
	previous.gold = 1234
	hud._refresh_all()
	t.check(seam+"_authentic_old_rows_and_model", hud.quest_tracker.get_child_count() == 1 and t.world()._host_live() and not PlayerRegistry._states.has(&"p1"))
	if seam == "nested_load": t.check(seam+"_real_healthy_save", sm.save_game(0))
	var state := {"fired":0, "loaded":false}
	var fresh: Array = []
	var callback := func():
		if state.fired != 0: return
		state.fired += 1
		if seam == "queue":
			hud.queue_free()
			var replacement: Control = load("res://scenes/ui/hud.tscn").instantiate()
			t.root.add_child(replacement)
			fresh.append(replacement)
		elif seam == "nested_load":
			state.loaded = sm.load_game(0)
		else:
			PlayerRegistry.reset_states()
			PlayerRegistry._states[&"p0"].gold = 5678
			if seam == "nested_reset":
				t.check(seam+"_genuine_nested_quest_admitted", qm.accept_quest(&"zz_hud_fresh"))
				hud._refresh_all()
	var observer: Callable
	if seam == "remove":
		observer = func(_child: Node): callback.call()
		hud.quest_tracker.child_exiting_tree.connect(observer)
	elif seam == "add":
		observer = func(_child: Node): callback.call()
		hud.quest_tracker.child_entered_tree.connect(observer)
	else:
		hud.quest_card.visible = false
		observer = callback
		hud.quest_card.visibility_changed.connect(observer)
	# A valid original p0 reader reaches the callback in both versions. This
	# is a continuation tracer, not a synthetic raw p0 notification fanout.
	var calls: Array = []
	PlayerRegistry.for_player(&"p1", func():
		PlayerRegistry.for_player(&"p0", func(): hud._refresh_quests())
		calls.append(PlayerRegistry._acting_id))
	if seam == "remove": hud.quest_tracker.child_exiting_tree.disconnect(observer)
	elif seam == "add": hud.quest_tracker.child_entered_tree.disconnect(observer)
	else: hud.quest_card.visibility_changed.disconnect(observer)
	t.check(seam+"_actual_synchronous_boundary_and_caller_restoration", state.fired == 1 and calls == [&"p1"] and PlayerRegistry._acting_id == &"")
	if seam == "queue":
		t.check(seam+"_queued_old_owner_has_no_new_rows", hud.is_queued_for_deletion() and hud.quest_tracker.get_child_count() == 0)
		t.check(seam+"_fresh_display_survives_old_tail", fresh.size() == 1 and fresh[0].gold_label.text == "1.234" and fresh[0].quest_tracker.get_child_count() == 1)
	else:
		var current: PlayerState = PlayerRegistry._states[&"p0"]
		t.check(seam+"_actual_model_replacement_without_body_rebind", current != previous and t.world()._host_profile == previous and not t.world()._host_live())
		if seam in ["remove", "add"]:
			t.check(seam+"_old_tail_never_queries_successor_quest_containers", current.quests.is_empty(), str(current.quests))
			t.check(seam+"_later_real_new_quest_admitted", qm.accept_quest(&"zz_hud_fresh"))
			hud._refresh_all()
		else:
			t.check(seam+"_loaded_or_nested_root_succeeded", state.loaded if seam == "nested_load" else qm.is_active(&"zz_hud_fresh"))
		var id: StringName = &"zz_hud_old" if seam == "nested_load" else &"zz_hud_fresh"
		t.check(seam+"_exact_fresh_rows_not_appended_or_cleared_by_old_tail", hud.quest_tracker.get_child_count() == 1 and MODEL.new()._titles(hud) == [qm.get_title(id)], str(MODEL.new()._titles(hud)))
		t.check(seam+"_current_p0_gold_and_health", hud.gold_label.text == ("1.234" if seam == "nested_load" else "5.678") and hud.hearts.half_hearts == 10)
		qm.update_objective(id, &"work", 1)
		t.check(seam+"_later_real_objective_progress", qm.get_objective_progress(id, &"work").get("current") == 1 and hud.quest_tracker.get_child(0).get_child(1).text.contains("1 / 2"))
	t.check(seam+"_no_phantom_player", PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1"))
	await t.frames(3)
	for replacement in fresh: replacement.free()
	gm.clear_config_overrides()

func _rejoin(t) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var sm: Node = t.autoload("SaveManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	sm.autosave_enabled = false
	sm.save_dir = "user://renewed_hud_rejoin"
	var hud: Control = t.tree.get_first_node_in_group("game_ui").get_screen(&"hud")
	var secondary: Node2D = w._make_player()
	w._register_player(secondary, 1, 2)
	PlayerRegistry.for_player(&"p1", func():
		w.add_child(secondary)
		secondary.enter_area(w.area, w.area.get_spawn("default") + Vector2(100, 0))
		eco.from_dict(eco.to_dict())
		qm.to_dict())
	secondary.set_physics_process(false)
	var p1: PlayerState = PlayerRegistry._states[&"p1"]
	p1.gold = 98765
	p1.max_half_hearts = 38
	p1.max_stamina = 137.0
	p1.max_oil = 211.0
	var p0: PlayerState = PlayerRegistry._states[&"p0"]
	p0.gold = 1234
	w.player.half_hearts = 6
	w.player.stamina = 39
	PlayerRegistry.for_player(&"p0", func(): eco.add_item(&"wood", 7, true))
	w.player.hotbar.assign(0, &"wood")
	var old_body: Node = w.player
	w._unregister_player(old_body)
	old_body.free()
	var registry: Dictionary = PlayerRegistry._states
	var values: Dictionary = p1.to_dict().duplicate(true)
	var graph: Array = []
	GRAPH.new()._retain(p1, graph)
	t.check("rejoin_complete_p1_preimage_authenticated", OLD.new()._unchanged(true, p1, values, graph, registry))
	t.check("rejoin_authentic_group_local_p1_and_no_host_body", PlayerRegistry.local_id() == &"p1" and PlayerRegistry.by_id(&"p0") == null and PlayerRegistry.by_id(&"p1") == secondary)
	var admitted: Array = []
	PlayerRegistry.for_player(&"p1", func(): admitted.append(w.rejoin_host()))
	var body: Node2D = admitted[0]
	t.check("rejoin_real_current_enabled_host_under_group_local_p1", body != null and w._host_live() and body.is_physics_processing() and PlayerRegistry.local_id() == &"p1")
	var expected: Array = PlayerRegistry.for_player(&"p0", func(): return body.hotbar.entries())
	var caller: Array = []
	PlayerRegistry.for_player(&"p1", func():
		hud._refresh_all()
		caller.append(PlayerRegistry._acting_id))
	t.check("rejoin_p0_gold_health_hotbar_not_group_local_p1", hud.gold_label.text == "1.234" and hud.hearts.half_hearts == 6 and hud._entries == expected and hud._selected == body.hotbar.selected)
	t.check("rejoin_complete_p1_values_and_aliases", OLD.new()._unchanged(true, p1, values, graph, registry))
	t.check("rejoin_caller_restored", caller == [&"p1"] and PlayerRegistry._acting_id == &"")
	t.check("rejoin_real_later_healthy_save", sm.save_game(0))
	await t.frames(3)
	t.check("rejoin_later_enabled_host_and_p1_graph", body.is_physics_processing() and w._host_live() and OLD.new()._unchanged(true, p1, values, graph, registry))
	w._unregister_player(secondary)
	secondary.free()
	gm.clear_config_overrides()

func _reset_listener(t) -> void:
	await t.start_world()
	var hud: Control = t.tree.get_first_node_in_group("game_ui").get_screen(&"hud")
	var previous: PlayerState = PlayerRegistry._states[&"p0"]
	PlayerRegistry.reset_states()
	var current: PlayerState = PlayerRegistry._states[&"p0"]
	current.gold = 8765
	var receipts: Array = []
	PlayerRegistry.for_player(&"p1", func():
		receipts.append(MODEL.new()._hud_signal(hud, EventBus.new_game_started, []))
		receipts.append(PlayerRegistry._acting_id))
	t.check("reset_listener_genuine_replacement_and_exact_target", current != previous and receipts == [1, &"p1"])
	t.check("reset_listener_current_p0_model_not_ambient_or_old_body", hud.gold_label.text == "8.765" and not hud.quest_card.visible and hud._entries.all(func(entry): return entry.id == "") and hud.hearts.half_hearts == 10)
	t.check("reset_listener_genuinely_absent_p1_and_caller_restoration", not PlayerRegistry._states.has(&"p1") and PlayerRegistry._acting_id == &"")
	# Ordinary real whole new-game fanout stays distinct from the isolated
	# conflicting HUD target; other managers still own their reset producers.
	var gm: Node = t.autoload("GameManager")
	gm.start_new_game("HUD new run", gm.character_type)
	t.check("ordinary_actual_new_game_HUD_progress", PlayerRegistry._states[&"p0"] != current and hud.gold_label.text == str(PlayerRegistry._states[&"p0"].gold) and not hud.quest_card.visible)

func _friends(t) -> void:
	await t.start_world()
	var hud: Control = t.tree.get_first_node_in_group("game_ui").get_screen(&"hud")
	var gm: Node = t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	hud.toasts.clear()
	EventBus.friend_changed.emit(&"p0", &"baker_maja", 2)
	t.check("friend_old_entry_really_pending", hud._pending_friends.has(&"baker_maja"))
	PlayerRegistry.reset_states()
	PlayerRegistry.for_player(&"p1", func():
		MODEL.new()._hud_signal(hud, EventBus.friend_changed, [&"p0", &"baker_maja", 3]))
	var entry: Variant = hud._pending_friends.get(&"baker_maja")
	t.check("friend_fresh_same_npc_entry_replaces_old", entry != null)
	await t.frames(3)
	t.check("friend_exactly_one_fresh_message_and_no_phantom_profile", hud.toasts.toasts().size() == 1 and hud._pending_friends.is_empty() and not PlayerRegistry._states.has(&"p1"))
	hud.toasts.clear()
	EventBus.friend_changed.emit(&"p0", &"baker_maja", 4)
	PlayerRegistry.reset_states()
	await t.frames(3)
	t.check("friend_stale_entry_does_not_publish_or_erase_other_work", hud.toasts.toasts().is_empty() and hud._pending_friends.is_empty())
	MODEL.new()._hud_signal(hud, EventBus.friend_changed, [&"p1", &"baker_maja", 4])
	t.check("friend_irrelevant_label_never_queues", hud._pending_friends.is_empty())
	gm.clear_config_overrides()

func _feedback_boundary(t, successor: bool) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var hud: Control = t.tree.get_first_node_in_group("game_ui").get_screen(&"hud")
	var secondary: Node2D = w._make_player()
	w._register_player(secondary, 1, 2)
	PlayerRegistry.for_player(&"p1", func():
		w.add_child(secondary)
		secondary.enter_area(w.area, w.area.get_spawn("default") + Vector2(100, 0)))
	secondary.set_physics_process(false)
	var old_body: Node = w.player
	w._unregister_player(old_body)
	old_body.free()
	var original: PlayerState = PlayerRegistry._states[&"p0"]
	var label := "feedback_successor" if successor else "feedback_reset_only"
	t.check(label+"_real_hostless_group_local_p1_precondition", PlayerRegistry.local_id() == &"p1" and PlayerRegistry.by_id(&"p0") == null and PlayerRegistry._states.size() == 2)
	var boundary := FeedbackBoundary.new()
	boundary.actual = t.autoload("SocialManager")
	var previous: Variant = Svc._overrides.get("SocialManager")
	Svc.override("SocialManager", boundary)
	var replaced := {"done":false}
	boundary.observe = func():
		if replaced.done: return
		replaced.done = true
		PlayerRegistry.reset_states()
		if successor: MODEL.new()._hud_signal(hud, EventBus.friend_changed, [&"p0", &"baker_maja", 5])
	hud.toasts.clear()
	MODEL.new()._hud_signal(hud, EventBus.friend_changed, [&"p0", &"baker_maja", 4])
	t.check(label+"_actual_original_entry_queued", hud._pending_friends.has(&"baker_maja"))
	var on_toast := func(_node: Node): boundary.snapshots.append({"stage":"toast_added", "keys":PlayerRegistry._states.keys().duplicate()})
	hud.toasts.get_node("%Stack").child_entered_tree.connect(on_toast)
	await t.frames(4)
	hud.toasts.get_node("%Stack").child_entered_tree.disconnect(on_toast)
	if previous == null: Svc._overrides.erase("SocialManager")
	else: Svc._overrides["SocialManager"] = previous
	t.check(label+"_actual_deferred_Social_reader_and_raw_replacement", replaced.done and boundary.calls.size() == (2 if successor else 1) and boundary.calls[0][1] == original and PlayerRegistry._states[&"p0"] != original)
	t.check(label+"_retained_p0_recipient_not_deferred_ambient_p1", boundary.calls.all(func(pair): return pair[0] == &"p0") and (not successor or boundary.calls[1][1] == PlayerRegistry._states[&"p0"]))
	t.check(label+"_only_own_pending_cleanup_and_exact_fresh_publication", hud._pending_friends.is_empty() and hud.toasts.toasts().size() == (1 if successor else 0))
	t.check(label+"_no_phantom_profile_or_scope_leak", PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1") and PlayerRegistry._acting_id == &"", str({"snapshots":boundary.snapshots, "keys":PlayerRegistry._states.keys(), "p1":PlayerRegistry._states[&"p1"].to_dict() if PlayerRegistry._states.has(&"p1") else {}}))
	boundary.free()
	w._unregister_player(secondary)
	secondary.free()
	gm.clear_config_overrides()
