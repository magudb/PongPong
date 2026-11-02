extends RefCounted
const SECTION := "persistence_terminal"
const TIMEOUT_S := 180.0
class Late extends Node:
	var fail_restore := false
	func to_dict() -> Dictionary: return {"reject":false}
	func reset() -> void: pass
	func from_dict(d: Dictionary) -> bool: return not fail_restore and not d.get("reject", false)
func run(t) -> void:
	for mode in ["unread", "cancel", "depart_failed", "depart_partial", "depart_same", "successor"]:
		await t.start_world()
		var sm: Node = t.autoload("SaveManager")
		var gm: Node = t.autoload("GameManager")
		var w: Node = t.world()
		sm.autosave_enabled = false
		sm.save_dir = "user://persistence_terminal/"+mode
		DirAccess.make_dir_recursive_absolute(sm.save_dir)
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		gm.set_flag(&"forest_mother_version", 1)
		gm.set_flag(&"forest_mother_v1_marked_lamp", gm.total_day())
		var late := Late.new()
		t.root.add_child(late)
		sm.register_section("pb_terminal_late", late, 999)
		var body: Node2D = w.player
		var actor := Npc2D.create({"id":"mapseller_natteblik", "wander":"0"})
		actor.area = w.area
		w.add_child(actor)
		var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
		var ticket: RefCounted = actor._begin_followup(body, MotherStory.topic_page("mapseller_natteblik"))
		if mode != "unread": await t.page_to_choices(ui)
		t.check("PB03_"+mode+"_actual_page_positive", ticket != null and ui.is_open())
		var outcomes := []
		var close_observer := func():
			if not outcomes.is_empty(): return
			outcomes.append(w._unregister_player(body))
			if mode in ["depart_failed", "depart_partial", "depart_same"]:
				var payload: Dictionary = sm.gather_payload()
				payload.pb_terminal_late.reject = mode != "depart_same"
				late.fail_restore = mode == "depart_partial"
				outcomes.append(sm._apply_payload(payload).ok)
			elif mode == "successor":
				var successor: Node2D = w._make_player()
				w._register_player(successor, 0, 1)
				w.add_child(successor)
				successor.enter_area(w.area, w.area.get_spawn("default") + Vector2(9, 2))
		ui.closed.connect(close_observer)
		if mode in ["unread", "cancel"]: ui.close()
		else: ui._pick({"action":"close"})
		ui.closed.disconnect(close_observer)
		var earned: bool = mode in ["depart_failed", "successor"]
		t.check("PB03_"+mode+"_only_authenticated_earned_completion", MotherStory.has("map_account") == earned, str(outcomes))
		t.check("PB09_"+mode+"_no_ui_or_lifecycle_leak", not gm.lifecycle_busy() and not ui._suspended and ui._barrier == 0 and ui._records.is_empty())
		if mode in ["depart_failed", "successor"]: t.check("PB09_"+mode+"_earned_autosave_committed", FileAccess.file_exists(sm.slot_path(sm.AUTO_SLOT)))
		sm.unregister_section("pb_terminal_late")
		actor.free(); late.free()
		gm.clear_config_overrides()
