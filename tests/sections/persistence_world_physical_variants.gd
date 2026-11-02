extends RefCounted
const SECTION := "persistence_world_physical_variants"
const TIMEOUT_S := 180.0

# Headless prefetch completes synchronously. Retain real request/staging/finish,
# then expose one deterministic ordinary-frame await through production dispatch.
# This is a boundary tracer, not evidence of headless threaded texture loading.
class PrefetchBoundary extends AreaArtPrefetch:
	signal finished_staging
	var visits := 0
	func finish() -> void:
		await super.finish()
		visits += 1
		finished_staging.emit()
		await get_tree().process_frame

func _setup(t, label: String) -> Node:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://persistence_world_physical/"+label
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
	return t.world()

func run(t) -> void:
	for seam in ["prefetch", "post_swap", "warm"]:
		for successor in [false, true]: await _travel(t, seam, successor)
	await _rebuild(t)
	for seam in ["sleep_day", "passout_day", "defeat_day", "defeat_fee"]:
		for successor in [false, true]: await _night(t, seam, successor)
	t.autoload("GameManager").clear_config_overrides()

func _depart(w: Node, box: Dictionary, successor: bool) -> void:
	if box.has("departed"): return
	box.departed = w._unregister_player(w.player)
	box.area = w.area.map.id
	if successor:
		var p: Node2D = w.rejoin_host()
		p.hotbar.assign(6, &"stone")
		p.hotbar.select(6)
		p.half_hearts = 4
		p.stamina = 37.0
		p.oil = 59.0
		box.physics = Engine.get_physics_frames()
		box.body = weakref(p)
		box.pos = p.global_position
		box.hotbar = p.hotbar.to_dict()

func _natural_stamina(p: Node2D, box: Dictionary) -> bool:
	# Enabled physics earns ordinary regeneration; a physical suffix must not
	# replace it with full sleep healing. Include the currently executing tick.
	var ticks: int = Engine.get_physics_frames() - int(box.physics) + 1
	var natural_max: float = 37.0 + ticks * p.get_physics_process_delta_time() * float(GameData.player_cfg("stamina_regen_per_second",12))
	return p.stamina >= 37.0 and p.stamina <= natural_max + 0.001 and p.stamina < p.max_stamina

func _during_warm(t, w: Node, box: Dictionary, successor: bool) -> void:
	# Registered from area_ready BEFORE travel enters warm_clips. The next real
	# physics signal occurs while warm_clips waits for the real town population.
	await t.tree.physics_frame
	box.in_warm = w.last_travel_profile.has("entered_ms") and not w.last_travel_profile.has("warmed_ms")
	box.population_pending = false
	for director in t.tree.get_nodes_in_group("town_director"):
		if w.area.is_ancestor_of(director) and not director.ready_for_population: box.population_pending = true
	_depart(w, box, successor)

func _travel(t, seam: String, successor: bool) -> void:
	var label := seam + ("_successor" if successor else "_depart")
	var w: Node = await _setup(t, label)
	var sm: Node = t.autoload("SaveManager")
	var before: StringName = w.area.map.id
	var box := {}
	var destination: StringName = &"hyggebyen" if seam == "warm" else &"home"
	if seam == "prefetch":
		var previous: Node = w.art_prefetch
		var prefetch := PrefetchBoundary.new()
		prefetch.world = w
		w.add_child(prefetch)
		w.art_prefetch = prefetch
		previous.free()
		prefetch.finished_staging.connect(func():
			box.before_swap = w.area.map.id == before and w.traveling
			_depart(w, box, successor), CONNECT_ONE_SHOT)
	else:
		w.area_ready.connect(func(id):
			if id != destination: return
			if seam == "warm": _during_warm(t, w, box, successor)
			else: _depart(w, box, successor), CONNECT_ONE_SHOT)
	w.travel(destination, &"default")
	var reached: bool = await t.until(func(): return box.has("departed") and not w.traveling, 15)
	t.check("PB15_"+label+"_actual_named_boundary", reached and box.get("departed") == &"p0" and (box.get("before_swap", false) if seam == "prefetch" else (box.get("in_warm",false) and box.get("population_pending",false) if seam == "warm" else box.get("area") == destination)), str(box))
	await t.frames(5)
	t.check("PB15_"+label+"_old_holds_retired", not w.traveling and not w.sleeping and not w._faint_pending and w._fade.color.a == 0.0 and w.art_prefetch.staged.is_empty())
	if successor:
		var p: Node2D = box.body.get_ref()
		t.check("PB15_"+label+"_no_successor_adoption", p == w.player and p.global_position == box.pos and p.hotbar.to_dict() == box.hotbar and p.half_hearts == 4 and _natural_stamina(p, box) and p.oil == 59.0)
	else:
		t.check("PB15_"+label+"_bodyless_new_travel_refused", w.player == null and w.persistence_ready() and sm.save_game(0))
		w.travel(&"farm", &"default")
		await t.frames(2)
		t.check("PB15_"+label+"_still_no_bodyless_physical_route", not w.traveling)
		w.rejoin_host()
	await w.travel(&"home", &"default")
	var p: Node2D = w.player
	var at: Vector2 = p.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("PB15_"+label+"_next_natural_physics_travel_save", p.is_physics_processing() and p.global_position.distance_to(at) > 1.0 and not w.traveling and sm.save_game(1))

func _place_one(fm: Node) -> Dictionary:
	var grid: FurnitureGrid = fm.ensure_grid()
	for id in grid.items:
		for cell in grid.floor_cells:
			if grid.can_place(str(id), cell, 0).ok:
				fm.add(id, 1)
				return fm.place_from_stock(id, cell, 0)
	return {"ok":false}

func _rebuild(t) -> void:
	var w: Node = await _setup(t, "latest_rebuild")
	var fm: Node = t.autoload("FurnitureManager")
	t.check("PB16_real_builder_before_mutation", w._enter(&"home", &"default") and w.area.map.is_builder())
	var old: int = w.area.get_instance_id()
	w._unregister_player(w.player)
	var first := _place_one(fm)
	var first_state: Array = fm.grid.to_save()
	if first.ok: fm.pickup(first.uid)
	var second := _place_one(fm)
	var third := _place_one(fm)
	var latest: Array = fm.grid.to_save()
	await t.frames(4)
	t.check("PB16_real_latest_content_queued_hostless", first.ok and second.ok and third.ok and latest != first_state and w._rebuild_queued and w.area.get_instance_id() == old)
	var rebuilds := []
	var ready := func(id): rebuilds.append([id, w.area.get_instance_id()])
	w.area_ready.connect(ready)
	var p: Node2D = w.rejoin_host()
	var rebuilt: int = w.area.get_instance_id()
	var view: Node = w.area.get_node("HomeRoom")
	t.check("PB16_rejoin_builds_latest_actual_placed_nodes_once", rebuilt != old and not w._rebuild_queued and rebuilds == [[&"home",rebuilt]] and view.grid.to_save() == latest and view.nodes.has(second.uid) and view.nodes.has(third.uid) and w.area.is_ancestor_of(p))
	await t.frames(10)
	t.check("PB16_subsequent_frames_no_duplicate_rebuild", rebuilds == [[&"home",rebuilt]] and w.area.get_instance_id() == rebuilt and not w._rebuild_queued)
	w.area_ready.disconnect(ready)
	var at: Vector2 = p.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("PB16_latest_room_enabled_natural_progress_save", p.is_physics_processing() and p.global_position.distance_to(at) > 1 and t.autoload("SaveManager").save_game(0))

func _night(t, seam: String, successor: bool) -> void:
	var label := seam + ("_successor" if successor else "_depart")
	var w: Node = await _setup(t, label)
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	var model: PlayerState = PlayerRegistry._states[&"p0"]
	gm.hour = 19
	model.gold = 1000
	w.player.half_hearts = 3
	w.player.stamina = 29.0
	var day: int = gm.total_day()
	var gold: int = model.gold
	var fee: int = floori(float(gold) * clampf(float(GameData.cfg("dungeon.defeat.gold_loss_pct",10)),0,100)/100.0)
	var box := {}
	var day_events := []
	var gold_events := []
	var on_day := func(_d, _s): day_events.append(gm.total_day())
	var on_gold := func(pid, amount, delta):
		if pid != &"p0": return
		gold_events.append([amount,delta])
		if seam == "defeat_fee" and delta < 0:
			box.committed_gold = model.gold
			box.committed_day = gm.total_day()
			_depart(w, box, successor)
	var on_clock := func(hour, _minute):
		if seam == "defeat_fee" or hour != gm.day_start_hour() or gm.total_day() <= day or box.has("departed"): return
		box.committed_gold = model.gold
		box.committed_day = gm.total_day()
		_depart(w, box, successor)
	bus.day_started.connect(on_day)
	bus.gold_changed.connect(on_gold)
	bus.time_of_day_changed.connect(on_clock)
	if seam == "sleep_day": w.sleep()
	elif seam == "passout_day":
		gm.hour = gm.day_end_hour() - 1
		gm.minute = 59
		gm.advance_time(1) # real calendar roll and midnight_passed producer
	else: bus.player_defeated.emit(&"p0")
	var retired: bool = await t.until(func(): return box.has("departed") and not w.traveling and not w.sleeping and not w._faint_pending, 12)
	await t.seconds(0.3)
	bus.day_started.disconnect(on_day)
	bus.gold_changed.disconnect(on_gold)
	bus.time_of_day_changed.disconnect(on_clock)
	var expected_gold: int = gold - fee if seam == "defeat_fee" else gold
	t.check("PB17_"+label+"_departure_after_real_committed_effect", retired and box.get("committed_day") == day+1 and box.get("committed_gold") == expected_gold, str(box))
	t.check("PB17_"+label+"_no_replay_refund_or_duplicate_day", gm.total_day() == day+1 and model.gold == expected_gold and day_events == [day+1] and gold_events == ([[expected_gold,-fee]] if seam == "defeat_fee" else []), str([day_events,gold_events]))
	t.check("PB17_"+label+"_physical_holds_and_lifecycle_clean", not gm.lifecycle_busy() and not w.traveling and not w.sleeping and not w._faint_pending and not w._pass_out_pending and w._fade.color.a == 0)
	if successor:
		var p: Node2D = box.body.get_ref()
		t.check("PB17_"+label+"_no_successor_heal_pose_hotbar_adoption", p == w.player and p.global_position == box.pos and p.half_hearts == 4 and _natural_stamina(p, box) and p.oil == 59 and p.hotbar.to_dict() == box.hotbar)
	else:
		t.check("PB17_"+label+"_hostless_persistence_after_effects", sm.save_game(0) and w.player == null)
		w.rejoin_host()
	var p: Node2D = w.player
	var at: Vector2 = p.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("PB17_"+label+"_enabled_natural_subsequent_movement", p.is_physics_processing() and p.global_position.distance_to(at) > 1)
	gm.hour = 19
	await w.sleep()
	t.check("PB17_"+label+"_future_real_sleep_and_save", gm.total_day() == day+2 and model.gold == expected_gold and not w.traveling and not w.sleeping and sm.save_game(1))
