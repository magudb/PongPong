extends RefCounted
const SECTION := "renewed_defeat_ownership_successor"
const TIMEOUT_S := 120.0
const Legacy = preload("res://tests/sections/persistence_physical_cleanup_ownership.gd")

func _travel(w: Node, receipt: Dictionary) -> void:
	await w.travel(&"hyggebyen", &"default")
	receipt.done = true

func run(t) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	sm.autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.hour = 19
	gm.set_flag(&"assist_last_spark", 0)
	var secondary: Node2D = w._make_player()
	w._register_player(secondary, 1, 2)
	PlayerRegistry.for_player(&"p1", func(): w.add_child(secondary))
	secondary.enter_area(w.area, w.area.get_spawn("default") + Vector2(100, 0))
	secondary.set_physics_process(false)
	w._unregister_player(w.player)
	await t.frames(3)
	var old: Node2D = w.rejoin_host()
	await t.seconds(1.4)
	var model: PlayerState = PlayerRegistry._states[&"p0"]
	model.gold = 321
	old.half_hearts = 2
	old.oil = 52
	var day: int = gm.total_day()
	var original_area: StringName = w.area.map.id
	var previous: Node = w.art_prefetch
	var prefetch = Legacy.PrefetchBoundary.new()
	prefetch.world = w
	w.add_child(prefetch)
	w.art_prefetch = prefetch
	previous.free()
	var successor := {"body":null,"travel_done":false}
	var events: Array = []
	var on_defeat := func(pid): events.append(pid)
	bus.player_defeated.connect(on_defeat)
	# Real callback boundary BEFORE combat's EventBus emission. Sanctioned
	# unregister/rejoin replaces the emitter, then real successor travel owns B.
	var replace := func():
		w._unregister_player(old)
		successor.body = w.rejoin_host()
		_travel(w, successor)
	old.fainted.connect(replace)
	t.check("RDS_original_rejoined_combat_eligible", w._host_live() and PlayerRegistry.local_id() == &"p1" and old.is_physics_processing() and old.state == old.S.FREE and old.combat._iframes <= 0)
	var accepted: bool = old.take_damage(100)
	t.check("RDS_real_fatal_callback_installed_successor_without_stale_defeat", accepted and successor.body != null and w.player == successor.body and PlayerRegistry.by_id(&"p0") == successor.body and events.is_empty() and not w._faint_pending, str(events))
	var reached: bool = await t.until(func(): return prefetch.visits == 1, 5)
	await t.seconds(1.6)
	t.check("RDS_original_stack_cannot_borrow_successor_B_busy_fade_or_resources", reached and w.traveling and not w.sleeping and not w._faint_pending and w._fade.color.a == 1 and prefetch._target == &"hyggebyen" and not prefetch.staged.is_empty() and w.area.map.id == original_area and gm.total_day() == day and model.gold == 321)
	var requests: Array = prefetch.requests.duplicate()
	await w.travel(&"home", &"default")
	t.check("RDS_third_travel_still_refused", w.traveling and prefetch.requests == requests and w.area.map.id == original_area)
	prefetch.held = false
	await t.seconds(3.0)
	t.check("RDS_successor_B_completes_without_unearned_rescue_day_or_fee", not w.traveling and not w.sleeping and not w._faint_pending and w.area.map.id == &"hyggebyen" and w.player == successor.body and gm.total_day() == day and model.gold == 321 and successor.body.half_hearts == 0 and successor.body.oil == 52 and w._fade.color.a == 0)
	bus.player_defeated.disconnect(on_defeat)
	await w.travel(&"home", &"default")
	var body: Node2D = successor.body
	var at: Vector2 = body.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("RDS_successor_later_enabled_movement_and_save", body.is_physics_processing() and body.global_position.distance_to(at) > 1 and sm.save_game(4))
	gm.clear_config_overrides()
