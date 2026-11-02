extends RefCounted
## Approved BUSY policy. Original nested-success source/raw RED are archived in
## lifecycle-admission-implementation1/historical; three old policy assertions
## are explicitly replaced, not counted as unchanged passing coverage.
const SECTION := "dialogue_nested_lifecycle"
const TIMEOUT_S := 90.0
class LateReject extends Node:
	var data := {"v": 1, "reject": false}
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"v": 1, "reject": false}
	func from_dict(d: Dictionary) -> bool:
		if d.get("reject", false): return false
		data = d.duplicate(true)
		return true
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	saves.autosave_enabled = false
	saves.save_dir = "user://dialogue_nested_lifecycle"
	var late := LateReject.new()
	t.tree.root.add_child(late)
	saves.register_section("dialogue_nested_reject", late, 999)
	gm.set_flag(&"nested_load_probe", "saved")
	var payload: Dictionary = saves.gather_payload()
	payload.dialogue_nested_reject["reject"] = true
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	gm.player_name = "Pre-reset old run"
	gm.set_flag(&"nested_load_probe", "old")
	var actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	t.world().add_child(actor)
	var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
	actor.interact(t.player())
	await t.page_to_choices(ui)
	t.check("real_first_week_page_before_nested_load", actor.is_talking and sm.chat_available("smith_thorin") and not ui._buttons.is_empty())
	var resets: Array = []
	var loads: Array = []
	var on_flag := func(flag, value):
		if flag == &"friend_last_smith_thorin" and int(value) > 0 and loads.is_empty():
			loads.append({})
			loads[0]["ok"] = saves.load_game(0)
		elif flag == &"nested_load_probe" and typeof(value) == TYPE_STRING and value == "saved" and resets.is_empty():
			resets.append({})
			resets[0]["result"] = gm.try_start_new_game("Nested fresh run", gm.character_type, "Fresh")
			resets[0]["name"] = gm.player_name
			resets[0]["points"] = sm.points("smith_thorin", &"p0")
	bus.flag_changed.connect(on_flag)
	for button in ui._buttons:
		if button.get_meta("choice").get("action") == "close":
			button.pressed.emit()
			break
	bus.flag_changed.disconnect(on_flag)
	t.check("nested_newgame_refused_busy_before_mutation", resets.size() == 1 and resets[0].result.code == "busy" and not resets[0].result.ok and resets[0].name == "Tester" and loads == [{"ok": false}], "resets=" + str(resets) + "; loads=" + str(loads))
	t.check("failed_load_restores_original_run_under_busy_policy", gm.player_name == "Pre-reset old run" and gm.get_flag(&"nested_load_probe") == "old" and not sm.chat_available("smith_thorin"), "name=" + gm.player_name + "; available=" + str(sm.chat_available("smith_thorin")))
	t.check("first_earned_completion_survives_refused_nested_reset", sm.points("smith_thorin") == 100, "points=" + str(sm.points("smith_thorin")))
	actor.free()
	# A genuine eligible later-week page is also a normal-reward control. No
	# private guard is cleared, no compensating grant is used.
	gm.day = 8
	var next_actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	t.world().add_child(next_actor)
	next_actor.interact(t.player())
	await t.page_to_choices(ui)
	t.check("later_week_legitimate_completion_eligible", next_actor.is_talking and sm.chat_available("smith_thorin") and ui._shown > 0 and not ui._buttons.is_empty())
	for button in ui._buttons:
		if button.get_meta("choice").get("action") == "close":
			button.pressed.emit()
			break
	t.check("later_earned_completion_after_busy_rollback", sm.points("smith_thorin") == 200, "points=" + str(sm.points("smith_thorin")))
	next_actor.free()
	saves.unregister_section("dialogue_nested_reject")
	late.free()
	gm.clear_config_overrides()
