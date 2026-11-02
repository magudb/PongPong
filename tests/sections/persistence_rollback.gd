extends RefCounted
const SECTION := "persistence_rollback"
const TIMEOUT_S := 180.0
class Reject extends Node:
	var data := {"reject":false}
	var action: Callable
	var restore_bad := false
	var validation_action: Callable
	var calls := 0
	func validate_dict(_d: Dictionary) -> bool:
		if validation_action.is_valid(): validation_action.call()
		return true
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"reject":false}
	func from_dict(d: Dictionary) -> bool:
		calls += 1
		if d.get("reject", false):
			if action.is_valid(): action.call()
			return false
		if restore_bad: return false
		data = d.duplicate(true)
		return true
func run(t) -> void:
	for mode in ["complete", "depart", "world_changed", "partial"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var sm: Node = t.autoload("SaveManager")
		var social: Node = t.autoload("SocialManager")
		sm.autosave_enabled = false
		var w: Node = t.world()
		var late := Reject.new()
		t.root.add_child(late)
		sm.register_section("pb_late", late, 999)
		var payload: Dictionary = sm.gather_payload()
		if mode == "depart":
			w.player.half_hearts = 3
			w.player.stamina = 28.0
			w.player.oil = 42.0
		payload.pb_late.reject = true
		var original: Variant = PlayerRegistry._states[&"p0"]
		var accounting: Variant = social._accounting_world
		var world_before: Dictionary = w.to_dict()
		if mode == "depart": late.action = func(): w._unregister_player(w.player)
		if mode == "world_changed": late.action = func(): w.set_area_flag(w.area.map.id, "pb_unrestored", true)
		late.restore_bad = mode == "partial"
		var result: Dictionary = sm._apply_payload(payload)
		t.check("PB09_"+mode+"_actual_late_refusal", not result.ok)
		var complete: bool = mode in ["complete", "depart"]
		t.check("PB11_"+mode+"_accounting_requires_world_proof", (social._accounting_world == accounting) == complete)
		if complete:
			t.check("PB09_"+mode+"_exact_original_profile", PlayerRegistry._states[&"p0"] == original)
			t.check("PB09_"+mode+"_world_projection_restored", w.to_dict() == world_before)
		if mode == "depart":
			await t.frames(2)
			t.check("PB09_depart_no_node_resurrection", w.player == null and w.persistence_ready())
			var gathered: Dictionary = sm.gather_payload()
			t.check("PB09_depart_rollback_does_not_restore_stale_profile_vitals", gathered.players.rows.p0.half_hearts == 3 and gathered.players.rows.p0.stamina == 28.0 and gathered.players.rows.p0.oil == 42.0)
			original.half_hearts = 10 # explicit later model write, equal to old predeparture value
			gathered = sm.gather_payload()
			t.check("PB26_post_rollback_equal_valued_model_vital_write_wins", gathered.players.rows.p0.half_hearts == 10)
		t.check("PB10_"+mode+"_no_barrier_or_logger_leak", not gm.lifecycle_busy() and not social._accounting_suspended and sm.ApplyGuard.alive == 0)
		sm.unregister_section("pb_late")
		late.free()
	await _disk_root_controls(t)

func _disk_root_controls(t) -> void:
	for mode in ["complete", "validation_world_changed", "primary_incomplete"]:
		await t.start_world()
		var sm: Node = t.autoload("SaveManager")
		var social: Node = t.autoload("SocialManager")
		var gm: Node = t.autoload("GameManager")
		var w: Node = t.world()
		sm.autosave_enabled = false
		sm.save_dir = "user://persistence_root/"+mode
		DirAccess.make_dir_recursive_absolute(sm.save_dir)
		var late := Reject.new()
		t.root.add_child(late)
		sm.register_section("pb_root_late", late, 999)
		var payload: Dictionary = sm.gather_payload()
		payload.pb_root_late.reject = true
		for path in [sm.slot_path(0), sm.backup_path(0)]:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(JSON.stringify(payload)); f.close()
		var accounting: Variant = social._accounting_world
		var validations := []
		var probes := []
		late.validation_action = func():
			validations.append(true)
			var calls_before: int = late.calls
			var attempted: Dictionary = sm._dispatch_apply(payload, gm._lifecycle_token, &"load")
			probes.append(attempted.get("code") == "authority" and late.calls == calls_before)
			if mode == "validation_world_changed": w.set_area_flag(w.area.map.id, "pb_root_drift", true)
		late.restore_bad = mode == "primary_incomplete"
		t.check("PB12_"+mode+"_both_real_attempts_fail", not sm.load_game(0) and validations.size() >= 2)
		t.check("PB12_"+mode+"_only_original_root_can_revive", (social._accounting_world == accounting) == (mode == "complete"))
		t.check("PB27_"+mode+"_exact_root_token_not_borrowable_during_validation", probes.size() >= 2 and probes.all(func(value): return value))
		t.check("PB12_"+mode+"_root_and_accounting_released", not gm.lifecycle_busy() and not social._accounting_suspended)
		sm.unregister_section("pb_root_late")
		late.free()
