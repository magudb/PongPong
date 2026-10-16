extends RefCounted
## Real player/collision probes of every boardwalk landing and both ladder ends.
## NPC collisions are disabled only in this fixture so the authored joins are
## measured independently of a citizen happening to stand in the doorway.
const SECTION := "walkway_transitions"
const TIMEOUT_S := 180.0
const MOVES := [&"move_left", &"move_right", &"move_forward", &"move_back"]

var world: WorldRoot2D
var stage: LevelStage
var registry: LevelRegistry
var player: Node2D


func _setup(t, skin := "") -> bool:
	if not await t.start_world("", "Tester", "Testgaarden", skin):
		return false
	world = t.world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.day = 2
	gm.hour = 10
	t.autoload("EventBus").day_started.emit(gm.day, gm.season)
	t.autoload("EventBus").time_of_day_changed.emit(gm.hour, 0)
	world._enter(&"traetoppen", &"default")
	await world.warm_clips()
	await t.physics(3)
	stage = LevelStage.of(world.area)
	registry = stage.registry
	player = world.player
	for actor in t.tree.get_nodes_in_group(&"npc"):
		if actor is CollisionObject2D:
			actor.collision_layer = 0
	return true


func _place(t, at: Vector2) -> void:
	_release(t)
	player.end_talk()
	player.global_position = at
	player.velocity = Vector2.ZERO
	player._gvel = Vector2.ZERO
	ActorLevel.unlock(player)
	stage.tracker.refresh(player)
	await t.physics(3)


func _steer(t, direction: Vector2) -> void:
	var strengths := [maxf(-direction.x, 0), maxf(direction.x, 0), maxf(-direction.y, 0), maxf(direction.y, 0)]
	for i in MOVES.size():
		if strengths[i] > 0.001:
			t.hold(MOVES[i], strengths[i])
		else:
			t.release(MOVES[i])


func _release(t) -> void:
	for action in MOVES:
		t.release(action)


func run(t) -> void:
	if not await _setup(t):
		return
	await _landings(t, false)
	await _climbs(t, false)
	await _cancel_on_reparent(t)
	await _blocked_entry(t)
	_cleanup(t)
	var alternate: String = {"animal": "animal_monkey", "fairy": "fairy_birk", "hobbit": "hobbit_bodil", "ghost": "ghost_hviske"}[t.character]
	if await _setup(t, alternate):
		await _climbs(t, false, "alternate_")
		_cleanup(t)


func _landings(t, capture: bool) -> void:
	var lanes := [0.0] if capture else [-0.6, 0.0, 0.6]
	var crossings := 0
	for bridge in registry.bridges:
		for end in 2:
			var gate: Vector2 = bridge.gate_path[0 if end == 0 else bridge.gate_path.size() - 1]
			var out: Vector2 = (bridge.path[1] - bridge.path[0]).normalized() if end == 0 else (bridge.path[bridge.path.size() - 2] - bridge.path[bridge.path.size() - 1]).normalized()
			var normal := Vector2(-out.y, out.x)
			var platform_id: StringName = bridge.from_id if end == 0 else bridge.to_id
			for lane in lanes:
				var offset: Vector2 = normal * float(lane) * maxf(bridge.width * 0.5 - 29.0, 0.0)
				for reverse in [false, true]:
					# Some authored ends meet a hut immediately inside the deck:
					# test the hand-over, not a straight walk into that obstacle.
					# city_map's physical city tour covers the onward turns.
					var start: Vector2 = gate + offset - out * 2.0
					var target: Vector2 = gate + offset + out * 72.0
					if reverse:
						var swap := start
						start = target
						target = swap
					var expected: StringName = platform_id if reverse else bridge.id
					await _place(t, start)
					var label := "%s_end%d_%s_lane%s" % [bridge.id, end, "in" if reverse else "out", str(lane)]
					var result: Dictionary = await _cross(t, target, gate, expected, label if capture else "")
					await t.physics(2)
					t.check("landing_" + label, result.ok and int(result.stalls) == 0 and ActorLevel.level_id(player) == expected,
						"%s -> %s, %d ticks, %d stalled ticks, %.2f ground px left; actual level %s; %s" % [platform_id if not reverse else bridge.id, expected, result.ticks, result.stalls, result.left, ActorLevel.level_id(player), result.blocked_by])
					crossings += 1
	t.check("all_boardwalk_landings_covered", crossings == (36 if capture else 108), "%d crossings: 9 bridges x 2 ends x both directions%s" % [crossings, " x 3 lateral approaches" if not capture else ""])


func _cross(t, target: Vector2, gate: Vector2, expected: StringName, shot_name: String) -> Dictionary:
	var ticks := 0
	var stalls := 0
	var previous: Vector2 = player.global_position
	var captured := false
	var blocked_by := ""
	var direction := Iso.to_ground(target - player.global_position).normalized()
	var stable := 0
	var arrived := false
	var onto_platform := registry.get_level(expected).kind == &"platform"
	# Keep walking through the seam: steering back at a nearby goal can create
	# a false oscillation across the boundary while the player decelerates.
	while ticks < 150:
		_steer(t, direction)
		await t.physics(1)
		ticks += 1
		stable = stable + 1 if registry.level_id_at(player.global_position) == expected and ActorLevel.level_id(player) == expected else 0
		if stable >= 2 and (onto_platform or Iso.to_ground(target - player.global_position).dot(direction) <= 6.0):
			arrived = true
			break
		if ticks > 6 and player.global_position.distance_to(previous) < 0.1:
			stalls += 1
			if blocked_by == "" and player.get_slide_collision_count() > 0:
				blocked_by = str(player.get_last_slide_collision().get_collider().get_path()) + " at " + str(player.global_position) + " toward " + str(target) + " (target level " + str(registry.level_id_at(target)) + ")"
		previous = player.global_position
		if shot_name != "" and not captured and player.global_position.distance_to(gate) < 16.0:
			await t.capture("join_" + shot_name)
			captured = true
	_release(t)
	return {"ok": arrived, "ticks": ticks, "stalls": stalls, "left": Iso.ground_dist(player.global_position, target), "blocked_by": blocked_by}


func _climbs(t, capture: bool, prefix := "") -> void:
	for from_id in [&"torvet", &"upper"]:
		var lane: ClimbLane
		for candidate in stage.lanes:
			if not candidate.perk_only and candidate.from_id == from_id:
				lane = candidate
		var label: String = prefix + ("ladder_up" if from_id == &"torvet" else "ladder_down")
		var at: Vector2 = lane.start_pos + Vector2(35, 12 if from_id == &"torvet" else 0)
		await _place(t, at)
		t.check(label + "_approach_on_boardwalk", ActorLevel.level_id(player) == from_id)
		var before_climb: Vector2 = player.global_position
		var landing := {}
		var on_land := func(actor: Node, _from: StringName, to: StringName) -> void:
			landing.applied = ActorLevel.is_applied(actor, registry.get_level(to))
			landing.unlocked = not ActorLevel.is_locked(actor)
			landing.distance = (actor as Node2D).global_position.distance_to(lane.finish_pos)
			landing.clip = player.visual.current_clip
		lane.climbed.connect(on_land, CONNECT_ONE_SHOT)
		var direction := Vector2(0, -1 if from_id == &"torvet" else 1)
		_steer(t, direction)
		var started := lane.climb(player)
		t.check(label + "_no_entry_snap", started and player.global_position.distance_to(before_climb) < 0.01,
			"interaction displacement %.2f world px" % player.global_position.distance_to(before_climb))
		t.check(label + "_approach_keeps_boardwalk_level", ActorLevel.is_applied(player, registry.get_level(from_id)))
		t.check(label + "_animation_starts", player.visual.current_clip == &"walk", str(player.visual.current_clip))
		var previous: Vector2 = player.global_position
		var previous_time: float = t.game_seconds()
		var peak_speed := 0.0
		var frames := {}
		var recording: Array[Dictionary] = []
		var sample_at: float = t.game_seconds()
		var mid_captured := false
		var deadline: float = previous_time + 8.0
		while lane.climbing and t.game_seconds() < deadline:
			await t.physics(1)
			var now: float = t.game_seconds()
			if now > previous_time:
				peak_speed = maxf(peak_speed, Iso.ground_dist(previous, player.global_position) / (now - previous_time))
			previous = player.global_position
			previous_time = now
			frames[player.visual.sprite.region_rect.position.x] = true
			if capture and now >= sample_at:
				var frame_name := "%s_frame_%02d" % [label, recording.size()]
				await t.capture(frame_name)
				recording.append({"file": SECTION + "_" + frame_name + ".png", "time": t.game_seconds()})
				sample_at = t.game_seconds() + 0.025
			if capture and not mid_captured and absf(player.global_position.y - (lane.start_pos.y + lane.finish_pos.y) * 0.5) < 35:
				await t.capture(label + "_mid")
				mid_captured = true
		var limit := maxf(285.0, Iso.ground_dist(lane.start_pos, lane.finish_pos) / lane.last_duration) * 1.15
		t.check(label + "_continuous_motion", not lane.climbing and peak_speed <= limit,
			"peak %.1f ground px/s <= %.1f" % [peak_speed, limit])
		t.check(label + "_animation_advances", frames.size() >= 3, "%d distinct animation frames" % frames.size())
		# Capture the commit itself: a viewport readback may span the finish,
		# after which held input is correctly already moving the player onward.
		t.check(label + "_lands_on_boardwalk", bool(landing.get("applied", false)) and bool(landing.get("unlocked", false)) and float(landing.get("distance", INF)) < 0.01,
			"level %s, %.2f world px at landing event" % [ActorLevel.level_id(player), float(landing.get("distance", INF))])
		if lane.climbed.is_connected(on_land):
			lane.climbed.disconnect(on_land)
		t.check(label + "_stride_survives_landing", landing.get("clip", &"") == &"walk", str(landing.get("clip", &"")))
		t.check(label + "_facing_survives_landing", player.facing8 == Iso.dir8_of(direction) and player.visual.direction_index == player.facing8)
		if capture:
			await t.capture(label + "_landing")
			recording.append({"file": SECTION + "_" + label + "_landing.png", "time": t.game_seconds()})
		var landed: Vector2 = player.global_position
		await t.physics(12)
		t.check(label + "_held_input_continues", not lane.climbing and int(player.state) == 0 and Iso.ground_dist(landed, player.global_position) > 15.0,
			"%.2f ground px on held input after landing" % Iso.ground_dist(landed, player.global_position))
		if capture and t.out_dir != "":
			await t.capture(label + "_exit")
			recording.append({"file": SECTION + "_" + label + "_exit.png", "time": t.game_seconds()})
			var file := FileAccess.open(t.out_dir.path_join(SECTION + "_" + label + "_timeline.json"), FileAccess.WRITE)
			t.check(label + "_timeline_saved", file != null)
			if file != null:
				file.store_string(JSON.stringify(recording, "\t"))
		_release(t)


func _cancel_on_reparent(t) -> void:
	var lane: ClimbLane = stage.lanes[0]
	await _place(t, lane.start_pos + Vector2(35, 8))
	player.forced_clip = &"idle"
	var started := lane.climb(player)
	await t.physics(2)
	player.reparent(world)
	var stopped: Vector2 = player.global_position
	t.check("reparent_cancels_transition", started and not lane.climbing and not ActorLevel.is_locked(player) and int(player.state) == 0)
	t.check("cancel_restores_forced_clip", player.forced_clip == &"idle")
	await t.physics(90)
	t.check("cancel_has_no_late_motion", player.global_position.distance_to(stopped) < 0.01)
	player.forced_clip = &""
	player.reparent(world.area.objects)
	await t.physics(2)


func _blocked_entry(t) -> void:
	var lane: ClimbLane = stage.lanes[0]
	await _place(t, lane.start_pos + Vector2(-80, 16))
	var wall := StaticBody2D.new()
	wall.collision_layer = Iso.LAYER_NPC
	wall.collision_mask = 0
	wall.position = lane.start_pos + Vector2(-40, 8)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 100)
	collision.shape = shape
	wall.add_child(collision)
	world.area.colliders.add_child(wall)
	await t.physics(2)
	var events := [0]
	var cb := func(name: StringName, _payload: Dictionary) -> void:
		if name == &"ladder_climbed":
			events[0] += 1
	t.autoload("EventBus").game_event.connect(cb)
	var started := lane.climb(player)
	await t.until(func() -> bool: return not lane.climbing, 3.0)
	t.check("blocked_approach_does_not_jump_through_obstacle", started and not lane.climbing and not ActorLevel.is_locked(player) and player.global_position.x < wall.position.x and events[0] == 0,
		"%d climb events; stayed %.2f world px before the lane" % [events[0], player.global_position.distance_to(lane.start_pos)])
	t.autoload("EventBus").game_event.disconnect(cb)
	wall.queue_free()
	await t.physics(2)


func _cleanup(t) -> void:
	_release(t)
	t.autoload("GameManager").clear_config_overrides()
	player = null
	registry = null
	stage = null
	world = null


func run_windowed(t) -> void:
	if not await _setup(t):
		return
	player.camera.position_smoothing_enabled = false
	player._target_zoom = 0.7
	player.camera.zoom = Vector2.ONE * 0.7
	player._apply_camera_limits()
	world.day_night.override_hour = 11.0
	world.day_night.snap()
	await _landings(t, true)
	await _climbs(t, true)
	_cleanup(t)
