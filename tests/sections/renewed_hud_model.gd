extends RefCounted
const SECTION := "renewed_hud_model"
const TIMEOUT_S := 180.0
const GRAPH := preload("res://tests/sections/renewed_marker_refresh_model.gd")
const OLD := preload("res://tests/sections/persistence_marker_scope.gd")

func run(t) -> void:
	for populated in [false, true]:
		await _roots(t, populated)

func _roots(t, populated: bool) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var qm: Node = t.autoload("QuestManager")
	var sm: Node = t.autoload("SaveManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	sm.autosave_enabled = false
	sm.save_dir = "user://renewed_hud_model"
	var hud: Control = t.tree.get_first_node_in_group("game_ui").get_screen(&"hud")
	var host: PlayerState = PlayerRegistry._states[&"p0"]
	host.gold = 1234
	qm.register_quest_from_lua({"id":"zz_hud_model", "title_key":"HUD_SAVED", "objectives":[{"id":"work", "on":"manual", "target":2, "text_key":"HUD_SAVED"}], "rewards":{}, "meta":{}})
	t.check(_tag(populated)+"_real_p0_quest", qm.accept_quest(&"zz_hud_model"))
	var other: PlayerState
	if populated:
		other = PlayerRegistry.state(&"p1")
		PlayerRegistry.for_player(&"p1", func():
			eco.from_dict(eco.to_dict())
			qm.accept_quest(&"zz_hud_model")
			eco.add_item(&"wood", 7, true))
		other.name = "HUD unrelated complete profile"
		other.gold = 98765
		other.max_half_hearts = 38
		other.max_stamina = 137.0
		other.max_oil = 211.0
	var registry: Dictionary = PlayerRegistry._states
	var values: Dictionary = other.to_dict().duplicate(true) if populated else {}
	var graph: Array = []
	if populated: GRAPH.new()._retain(other, graph)
	t.check(_tag(populated)+"_authenticated_unrelated_preconditions", PlayerRegistry._states.size() == (2 if populated else 1) and (not populated or (other.gold == 98765 and other.inventory.size() > 0 and other.quests.active.has(&"zz_hud_model"))))
	for root in ["all", "translation", "quest", "objective", "ready"]:
		var spawned: Array = []
		var caller: Array = []
		var dispatches: Array = []
		PlayerRegistry.for_player(&"p1", func():
			match root:
				"all": hud._refresh_all()
				"translation": hud.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
				"quest": dispatches.append(_hud_signal(hud, EventBus.quest_accepted, [&"p0", &"zz_hud_model"]))
				"objective": dispatches.append(_hud_signal(hud, EventBus.quest_objective_updated, [&"p0", &"zz_hud_model", &"work", 0, 2]))
				"ready":
					var fresh: Control = load("res://scenes/ui/hud.tscn").instantiate()
					t.root.add_child(fresh)
					spawned.append(fresh)
			caller.append(PlayerRegistry._acting_id))
		var target: Control = spawned[0] if not spawned.is_empty() else hud
		if root in ["quest", "objective"]: t.check(_tag(populated)+"_"+root+"_exact_registered_HUD_listener", dispatches == [1])
		t.check(_tag(populated)+"_"+root+"_p0_gold_and_real_quest", target.gold_label.text == "1.234" and target.quest_tracker.get_child_count() >= 1 and _titles(target).has(qm.get_title(&"zz_hud_model")))
		t.check(_tag(populated)+"_"+root+"_whole_unrelated_graph", OLD.new()._unchanged(populated, other, values, graph, registry))
		t.check(_tag(populated)+"_"+root+"_caller_restored", caller == [&"p1"] and PlayerRegistry._acting_id == &"")
		for fresh in spawned: fresh.free()
	# Public p0 payloads remain presentation data; p1-labelled updates cannot
	# retarget the stable p0 HUD even when the group-local body later is p1.
	EventBus.gold_changed.emit(&"p0", 2345, 0)
	EventBus.player_stats_changed.emit(&"p0", {"stamina":61, "max_stamina":120, "half_hearts":7, "max_half_hearts":10})
	EventBus.hotbar_changed.emit(&"p0", [{"id":"wood", "amount":7}], 2)
	t.check(_tag(populated)+"_public_p0_payloads", hud.gold_label.text == "2.345" and hud.hearts.half_hearts == 7 and hud.stamina_bar.value == 61 and hud._selected == 2 and hud._entries == [{"id":"wood", "amount":7}])
	var before: Array = [hud.gold_label.text, hud.hearts.half_hearts, hud.stamina_bar.value, hud._entries.duplicate(true), hud._selected]
	EventBus.gold_changed.emit(&"p1", 999, 0)
	EventBus.player_stats_changed.emit(&"p1", {"stamina":1, "max_stamina":20, "half_hearts":1, "max_half_hearts":2})
	EventBus.player_health_changed.emit(&"p1", 2, 8)
	EventBus.hotbar_changed.emit(&"p1", [{"id":"stone", "amount":99}], 7)
	t.check(_tag(populated)+"_irrelevant_player_payloads_refused", before == [hud.gold_label.text, hud.hearts.half_hearts, hud.stamina_bar.value, hud._entries, hud._selected])
	var rows: Array = hud.quest_tracker.get_children()
	var dispatches: Array = []
	PlayerRegistry.for_player(&"p1", func():
		dispatches.append(_hud_signal(hud, EventBus.quest_accepted, [&"p1", &"zz_hud_model"]))
		dispatches.append(_hud_signal(hud, EventBus.quest_objective_updated, [&"p1", &"zz_hud_model", &"work", 1, 2])))
	t.check(_tag(populated)+"_irrelevant_quest_listeners_preserve_exact_rows", dispatches == [1,1] and rows == hud.quest_tracker.get_children())
	qm.update_objective(&"zz_hud_model", &"work", 1)
	t.check(_tag(populated)+"_real_later_p0_progress", qm.get_objective_progress(&"zz_hud_model", &"work").get("current") == 1)
	t.player()._emit_hotbar()
	t.check(_tag(populated)+"_actual_current_body_hotbar", hud._entries == t.player().hotbar.entries() and hud._selected == t.player().hotbar.selected)
	t.check(_tag(populated)+"_real_healthy_save", sm.save_game(0))
	t.check(_tag(populated)+"_final_unrelated_values_aliases", OLD.new()._unchanged(populated, other, values, graph, registry))
	gm.clear_config_overrides()

func _tag(populated: bool) -> String:
	return "existing" if populated else "absent"

# Exact independent HUD subscriber only. Broader raw map fanout is retained
# separately in renewed_hud_fanout_trace and OUTSIDE-HUD-SCOPE.md, not hidden.
func _hud_signal(hud: Control, event: Signal, args: Array) -> int:
	var count := 0
	for connection in event.get_connections():
		var callback: Callable = connection.callable
		if callback.get_object() == hud:
			count += 1
			callback.callv(args)
	return count

func _titles(hud: Control) -> Array:
	var result: Array = []
	for row in hud.quest_tracker.get_children():
		if row.get_child_count() > 0: result.append(row.get_child(0).text)
	return result
