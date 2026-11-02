extends RefCounted
const SECTION := "persistence_cleanup_registry_roundtrip"
const TIMEOUT_S := 180.0
class CodecProbe extends Node:
	var visits := 0
	func to_dict() -> Dictionary:
		visits += 1
		return {"v":1}
	func reset() -> void: pass
	func from_dict(_data: Dictionary) -> bool: return true

func run(t) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://cleanup_registry_roundtrip"
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var probe := CodecProbe.new()
	t.root.add_child(probe)
	sm.register_section("lc3_codec_probe", probe, 1)
	t.check("LC3_real_healthy_save_and_codec_positive", sm.save_game(0) and probe.visits == 1 and w.persistence_ready() and PlayerRegistry.registered_id(w.player) == &"p0")
	var hash_before: String = FileAccess.get_sha256(sm.slot_path(0))
	var body: Node2D = w.player
	w._register_player(body, 1, 2) # Existing public registration, no forged fields.
	t.check("LC3_actual_conflicting_host_alias_precondition", w.players[0] == body and w.player_by_peer[1] == body and body.player_id == &"p1" and body.player_slot == 1 and body.peer_id == 2 and PlayerRegistry.by_id(&"p0") == null and PlayerRegistry.registered_id(body) == &"p1")
	var row: PlayerState = PlayerRegistry._states[&"p0"]
	row.name = "must_not_normalize_on_refusal"
	var values: Dictionary = row.to_dict()
	var states: Dictionary = PlayerRegistry._states
	var keys: Array = states.keys()
	var inventory: Array = row.inventory
	var equipment: Dictionary = row.equipment
	var visits: int = probe.visits
	t.check("LC3_noncreating_host_preflight_refuses_alias", not w.persistence_ready())
	var saved: bool = sm.save_game(0)
	t.check("LC3_real_save_refuses_before_codec_or_normalization", not saved and probe.visits == visits and row.to_dict() == values and is_same(row.inventory, inventory) and is_same(row.equipment, equipment) and is_same(PlayerRegistry._states, states) and PlayerRegistry._states.keys() == keys and PlayerRegistry._states[&"p0"] == row)
	t.check("LC3_refusal_preserves_exact_disk_no_backup_or_temp", FileAccess.get_sha256(sm.slot_path(0)) == hash_before and not FileAccess.file_exists(sm.backup_path(0)) and not FileAccess.file_exists(sm.slot_path(0)+".tmp"))
	# A configured same-model successor repairs the actual p0 attachment; the
	# old body remains an ordinary p1, not a retained p0 cleanup authority.
	var successor: Node2D = w._make_player()
	w._register_player(successor, 0, 1)
	PlayerRegistry.for_player(&"p0", func(): w.add_child(successor))
	successor.enter_area(w.area, w.area.get_spawn("default"))
	t.check("LC3_same_model_configured_successor_positive", w._host_profile == row and PlayerRegistry.by_id(&"p0") == successor and PlayerRegistry.by_peer(1) == successor and w.persistence_ready() and sm.save_game(1))
	await w.travel(&"home", &"default")
	t.check("LC3_ordinary_area_reparent_roundtrip_positive", w.area.map.id == &"home" and w.area.is_ancestor_of(successor) and PlayerRegistry.registered_id(successor) == &"p0" and w.persistence_ready() and sm.save_game(2))
	var at: Vector2 = successor.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("LC3_successor_enabled_physics_next_progress", successor.is_physics_processing() and successor.global_position.distance_to(at) > 1.0)
	sm.unregister_section("lc3_codec_probe")
	probe.queue_free()
	gm.clear_config_overrides()
