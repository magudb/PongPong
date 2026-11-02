extends RefCounted
## BUSY policy regression. Separate identities from the archived nested-success policy.
const SECTION := "lifecycle_admission"
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
	saves.save_dir = "user://lifecycle_admission"
	var late := LateReject.new()
	t.tree.root.add_child(late)
	saves.register_section("admission_reject", late, 999)
	gm.set_flag(&"admission_load_probe", "saved")
	var payload: Dictionary = saves.gather_payload()
	payload.admission_reject["reject"] = true
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	gm.player_name = "Original run"
	gm.set_flag(&"admission_load_probe", "old")
	var actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	t.world().add_child(actor)
	var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
	actor.interact(t.player())
	await t.page_to_choices(ui)
	var balance: int = sm.points("smith_thorin", &"p0")
	var reward: int = SocialData.cfg_int("chat_points", 100)
	t.check("earned_page_eligible_before_nested_load", actor.is_talking and sm.chat_available("smith_thorin") and not ui._buttons.is_empty())
	var resets: Array = []
	var loads: Array = []
	var on_flag := func(flag, value):
		if flag == &"friend_last_smith_thorin" and int(value) > 0 and loads.is_empty():
			loads.append({})
			loads[0]["ok"] = saves.load_game(0)
		elif flag == &"admission_load_probe" and typeof(value) == TYPE_STRING and value == "saved" and resets.is_empty():
			resets.append({})
			var before: Dictionary = gm.to_dict()
			var status: Dictionary = saves.last_error.duplicate(true)
			var result: Dictionary = {}
			if gm.has_method("try_start_new_game"):
				result = gm.try_start_new_game("Refused run", gm.character_type, "Refused")
			else:
				# Baseline exercises the real observer path, not a missing-method error.
				gm.start_new_game("Refused run", gm.character_type, "Refused")
				result = {"ok": true, "code": "legacy_accepted"}
			resets[0] = {"result": result, "model_unchanged": gm.to_dict() == before, "status_unchanged": saves.last_error == status}
	bus.flag_changed.connect(on_flag)
	_close(ui)
	bus.flag_changed.disconnect(on_flag)
	t.check("load_apply_observer_newgame_returns_busy", resets.size() == 1 and resets[0].result.get("code") == "busy" and not resets[0].result.get("ok", true), str(resets))
	t.check("busy_observer_does_not_mutate_model_or_status", resets.size() == 1 and resets[0].model_unchanged and resets[0].status_unchanged, str(resets))
	t.check("late_failure_restores_original_run", loads == [{"ok": false}] and gm.player_name == "Original run" and gm.get_flag(&"admission_load_probe") == "old" and not saves._applying)
	t.check("first_earned_completion_survives_busy_and_rollback", sm.points("smith_thorin", &"p0") == balance + reward, "balance=%d delta=%d reward=%d" % [balance, sm.points("smith_thorin", &"p0") - balance, reward])
	actor.free()
	gm.day = 8
	var next_actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	t.world().add_child(next_actor)
	next_actor.interact(t.player())
	await t.page_to_choices(ui)
	t.check("later_week_real_page_eligible", next_actor.is_talking and sm.chat_available("smith_thorin") and ui._shown > 0 and not ui._buttons.is_empty())
	_close(ui)
	t.check("later_earned_completion_exact_configured_delta", sm.points("smith_thorin", &"p0") == balance + 2 * reward, "points=" + str(sm.points("smith_thorin", &"p0")))
	next_actor.free()
	saves.unregister_section("admission_reject")
	late.free()
	gm.clear_config_overrides()
func _close(ui: Control) -> void:
	for button in ui._buttons:
		if button.get_meta("choice").get("action") == "close":
			button.pressed.emit()
			return
