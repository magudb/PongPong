extends RefCounted
const SECTION := "persistence_physical"
const TIMEOUT_S := 180.0
func run(t) -> void:
	for route in ["travel", "sleep", "defeat"]:
		await t.start_world()
		var w: Node = t.world()
		var gm: Node = t.autoload("GameManager")
		var sm: Node = t.autoload("SaveManager")
		sm.autosave_enabled = false
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		gm.hour = 19
		var before_day: int = gm.total_day()
		var before_gold: int = PlayerRegistry._states[&"p0"].gold
		if route == "travel": w.travel(&"home", &"default")
		elif route == "sleep": w.sleep()
		else: w._on_player_defeated(&"p0")
		w._unregister_player(w.player)
		await t.seconds(3.2)
		t.check("PB17_"+route+"_old_physical_tail_retires", not w.traveling and not w.sleeping and not w._faint_pending)
		t.check("PB17_"+route+"_no_unearned_day_or_cost", gm.total_day() == before_day and PlayerRegistry._states[&"p0"].gold == before_gold)
		w.travel(&"home", &"default")
		w.sleep()
		w._on_player_defeated(&"p0")
		await t.frames(2)
		t.check("PB15_"+route+"_new_bodyless_routes_refuse", not w.traveling and not w.sleeping and not w._faint_pending)
		gm.clear_config_overrides()
	await _rebuild_and_successor(t)

func _rebuild_and_successor(t) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	t.autoload("SaveManager").autosave_enabled = false
	t.check("PB16_actual_builder_area_positive", w._enter(&"home", &"default") and w.area.map.is_builder())
	var old_area_id: int = w.area.get_instance_id()
	w._unregister_player(w.player)
	t.autoload("EventBus").furniture_changed.emit(&"placed")
	await t.frames(2)
	t.check("PB16_hostless_deferred_rebuild_remains_queued", w._rebuild_queued and w.area.get_instance_id() == old_area_id)
	var joined: Node2D = w.rejoin_host()
	t.check("PB16_rejoin_flushes_latest_rebuild_once", joined != null and not w._rebuild_queued and w.area.get_instance_id() != old_area_id and w.area.is_ancestor_of(joined))
	await t.start_world()
	w = t.world()
	t.autoload("SaveManager").autosave_enabled = false
	var original_area: StringName = w.area.map.id
	w.travel(&"home", &"default")
	w._unregister_player(w.player)
	var successor: Node2D = w.rejoin_host()
	var at: Vector2 = successor.global_position
	await t.seconds(0.6)
	t.check("PB15_old_travel_cannot_adopt_live_successor", w.player == successor and successor.global_position == at and w.area.map.id == original_area and not w.traveling)
	await w.travel(&"home", &"default")
	t.check("PB15_successor_next_real_travel_progresses", w.area.map.id == &"home" and not w.traveling)
	at = successor.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("PB07_rejoined_body_real_physics_movement", successor.is_physics_processing() and successor.global_position.distance_to(at) > 1.0)
	t.check("PB07_rejoined_body_next_save_usable", t.autoload("SaveManager").save_game(4))
	gm.clear_config_overrides()
