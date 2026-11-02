extends RefCounted
const SECTION := "persistence_projection"
const TIMEOUT_S := 180.0
class CountSection extends Node:
	var reads := 0
	func to_dict() -> Dictionary:
		reads += 1
		return {"v":1}
	func from_dict(_d: Dictionary) -> bool: return true
	func reset() -> void: pass
func run(t) -> void:
	await t.start_world()
	var w: Node = t.world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://persistence_projection"
	var counter := CountSection.new()
	t.root.add_child(counter)
	sm.register_section("pb_counter", counter, 999)
	t.check("PB20_healthy_file_positive", sm.save_game(0))
	var digest: String = FileAccess.get_sha256(sm.slot_path(0))
	var reads: int = counter.reads
	var body: Node2D = w.player
	var parent: Node = body.get_parent()
	parent.remove_child(body)
	t.check("PB19_raw_detach_refuses_real_write", not sm.save_game(0))
	t.check("PB20_refusal_precedes_all_section_codecs", counter.reads == reads)
	t.check("PB20_refusal_preserves_primary_and_backup", FileAccess.get_sha256(sm.slot_path(0)) == digest and not FileAccess.file_exists(sm.backup_path(0)))
	parent.add_child(body)
	var profile: Variant = PlayerRegistry._states[&"p0"]
	PlayerRegistry._states.erase(&"p0")
	t.check("PB20_missing_profile_refuses_without_lazy_creation", not sm.autosave() and not PlayerRegistry._states.has(&"p0") and counter.reads == reads)
	PlayerRegistry._states[&"p0"] = profile
	t.check("PB20_healthy_save_after_refusal", sm.save_game(0))
	var saved: Dictionary = w.to_dict()
	var result: Dictionary = w.try_from_dict(saved)
	t.check("PB14_normal_body_present_restore_preserved", result.ok and w.to_dict() == saved)
	body.half_hearts = 3
	body.stamina = 28.0
	body.oil = 42.0
	w._unregister_player(body)
	await t.frames(2)
	var payload: Dictionary = sm.gather_payload()
	t.check("PB25_sampled_vitals_without_fake_healing", payload.players.rows.p0.half_hearts == 3 and payload.players.rows.p0.stamina == 28.0 and payload.players.rows.p0.oil == 42.0)
	profile.half_hearts = 4 # real model authority, not another body's vitals
	profile.stamina = 31.0
	var changed: Dictionary = sm.gather_payload()
	t.check("PB26_current_model_vitals_not_overwritten_by_cache", changed.players.rows.p0.half_hearts == 4 and changed.players.rows.p0.stamina == 31.0 and changed.players.rows.p0.oil == 42.0)
	var health := []
	var on_health := func(pid, hp, _max):
		if pid == &"p0": health.append(hp)
	t.autoload("EventBus").player_health_changed.connect(on_health)
	var rejoined: Node2D = w.rejoin_host()
	t.autoload("EventBus").player_health_changed.disconnect(on_health)
	t.check("PB07_rejoin_ready_never_publishes_fake_healing", rejoined != null and rejoined.half_hearts == 4 and rejoined.stamina == 31.0 and rejoined.oil == 42.0 and not health.is_empty() and health.all(func(hp): return hp == 4), str(health))
	sm.unregister_section("pb_counter")
	counter.free()
	await t.go_menu()
	sm.pending_world = {"opaque_pb":29}
	t.check("PB18_absent_world_keeps_opaque_pending", sm.gather_payload().world == {"opaque_pb":29} and sm.save_game(1))
	sm.pending_world = {}
	t.check("PB18_absent_empty_newgame_compatible", sm.gather_payload().world.is_empty())
	gm.clear_config_overrides()
