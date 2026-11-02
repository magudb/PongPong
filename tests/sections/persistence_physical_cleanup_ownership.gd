extends RefCounted
const SECTION := "persistence_physical_cleanup_ownership"
const TIMEOUT_S := 180.0

# Deterministic boundary tracer: the actual production request and superclass
# finish run first. The hold is virtual-dispatch pacing, NOT threaded headless art.
class PrefetchBoundary extends AreaArtPrefetch:
	var held := true
	var visits := 0
	var requests: Array[StringName] = []
	func request(id: StringName) -> void:
		requests.append(id)
		super.request(id)
	func finish() -> void:
		await super.finish()
		visits += 1
		while held:
			await get_tree().process_frame

func _travel(w: Node, destination: StringName, receipt: Dictionary) -> void:
	await w.travel(destination, &"default")
	receipt.done = true

func run(t) -> void:
	await _defeat_overlap(t)
	for route in ["travel_fade_in", "sleep_fade_out", "defeat_fade_out"]:
		await _fade_replacement(t, route)

func _defeat_overlap(t) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://physical_cleanup_ownership"
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.hour = 19
	var model: PlayerState = PlayerRegistry._states[&"p0"]
	var day: int = gm.total_day()
	var gold: int = model.gold
	var original_area: StringName = w.area.map.id
	w._on_player_defeated(&"p0") # A: real 1.3-second production defeat timer.
	t.check("PCO_A_real_defeat_wait_has_no_travel", w._faint_pending and not w.traveling)
	w._unregister_player(w.player)
	var successor: Node2D = w.rejoin_host()
	t.check("PCO_sanctioned_same_model_successor", successor != null and w._host_live() and PlayerRegistry._states[&"p0"] == model and successor.is_physics_processing())
	var previous: Node = w.art_prefetch
	var prefetch := PrefetchBoundary.new()
	prefetch.world = w
	w.add_child(prefetch)
	w.art_prefetch = prefetch
	previous.free()
	var b := {"done":false}
	_travel(w, &"hyggebyen", b)
	var reached: bool = await t.until(func(): return prefetch.visits == 1, 5)
	t.check("PCO_B_real_request_staged_before_swap", reached and w.traveling and w.area.map.id == original_area and prefetch._target == &"hyggebyen" and not prefetch.staged.is_empty() and not b.done)
	var staged: Array = prefetch.staged.keys()
	# A must have woken by this point, while B still awaits our boundary.
	await t.seconds(1.6)
	t.check("PCO_stale_A_preserves_active_B_exclusion", w.traveling and not w.sleeping and not b.done)
	t.check("PCO_stale_A_preserves_B_fade_and_prefetch", w._fade.color.a == 1.0 and prefetch._target == &"hyggebyen" and prefetch.staged.keys() == staged)
	t.check("PCO_stale_A_no_calendar_fee_or_body_adoption", gm.total_day() == day and model.gold == gold and w.player == successor and w.area.map.id == original_area)
	var requests_before: Array = prefetch.requests.duplicate()
	var c := {"done":false}
	_travel(w, &"home", c)
	await t.seconds(0.35)
	t.check("PCO_third_real_travel_refused_while_B_active", c.done and not b.done and prefetch.requests == requests_before and w.traveling and w.area.map.id == original_area)
	prefetch.held = false
	var settled: bool = await t.until(func(): return b.done and c.done and not w.traveling, 10)
	t.check("PCO_B_completes_without_hanging", settled and w.area.map.id == &"hyggebyen" and not w.sleeping and not w._faint_pending and not w._pass_out_pending and w._fade.color.a == 0.0)
	await w.travel(&"home", &"default")
	t.check("PCO_successor_next_real_travel_progresses", w.area.map.id == &"home" and not w.traveling)
	var at: Vector2 = successor.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("PCO_enabled_physics_next_movement_and_save", successor.is_physics_processing() and successor.global_position.distance_to(at) > 1.0 and sm.save_game(4))
	gm.clear_config_overrides()

func _old_route(w: Node, route: String, receipt: Dictionary) -> void:
	if route == "travel_fade_in": await w.travel(&"home", &"default")
	elif route == "sleep_fade_out": await w.sleep()
	else: await w._on_player_defeated(&"p0")
	receipt.done = true

func _fade_replacement(t, route: String) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	sm.autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.hour = 19
	var day: int = gm.total_day()
	var gold: int = PlayerRegistry._states[&"p0"].gold
	var old := {"done":false}
	_old_route(w, route, old)
	var fading: bool = await t.until(func(): return w.traveling and not old.done and w._fade.color.a > 0.0 and w._fade.color.a < 1.0 and (w.last_travel_profile.has("warmed_ms") if route == "travel_fade_in" else true), 5)
	t.check("PCO_"+route+"_actual_old_tween_active", fading and not old.done and w._fade.color.a > 0.0 and w._fade.color.a < 1.0)
	w._unregister_player(w.player)
	var p: Node2D = w.rejoin_host()
	var previous: Node = w.art_prefetch
	var prefetch := PrefetchBoundary.new()
	prefetch.world = w
	w.add_child(prefetch)
	w.art_prefetch = prefetch
	previous.free()
	var b := {"done":false}
	_travel(w, &"hyggebyen", b)
	var reached: bool = await t.until(func(): return prefetch.visits == 1, 5)
	await t.seconds(0.8)
	t.check("PCO_"+route+"_killed_old_tween_await_settles", old.done)
	t.check("PCO_"+route+"_successor_busy_fade_resources_owned", reached and not b.done and w.traveling and not w.sleeping and w._fade.color.a == 1.0 and prefetch._target == &"hyggebyen" and not prefetch.staged.is_empty())
	var requests: Array = prefetch.requests.duplicate()
	w.sleep() # A valid host still cannot begin a second presentation.
	var c := {"done":false}
	_travel(w, &"home", c)
	await t.frames(3)
	t.check("PCO_"+route+"_current_B_rejects_other_physical_roots", c.done and not b.done and w.traveling and not w.sleeping and prefetch.requests == requests)
	t.check("PCO_"+route+"_no_obsolete_day_fee_or_adoption", gm.total_day() == day and PlayerRegistry._states[&"p0"].gold == gold and w.player == p)
	prefetch.held = false
	var settled: bool = await t.until(func(): return b.done and not w.traveling, 10)
	t.check("PCO_"+route+"_real_successor_completes", settled and w.area.map.id == &"hyggebyen" and w._fade.color.a == 0.0)
	await w.travel(&"home", &"default")
	var at: Vector2 = p.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("PCO_"+route+"_next_enabled_physics_travel_save", p.is_physics_processing() and p.global_position.distance_to(at) > 1.0 and w.area.map.id == &"home" and sm.save_game(4))
	gm.clear_config_overrides()
