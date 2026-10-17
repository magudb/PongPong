extends RefCounted
## Exercise every production bridge in both directions with the real player physics.
const SECTION := "city_walkthrough"
const TIMEOUT_S := 220.0
var native := false
func run(t) -> void: await _run(t)
func run_windowed(t) -> void:
	native = true
	await _run(t)
func _run(t) -> void:
	await t.start_world("ghost", "Tester", "Testgaarden", "ghost_bu")
	var w: WorldRoot2D = t.world()
	w._enter(&"traetoppen", &"default")
	var stage := LevelStage.of(w.area)
	var p: Player2D = w.player
	var logical_events: Array = []
	stage.tracker.level_changed.connect(func(actor: Node, from_id: StringName, to_id: StringName):
		if actor == p: logical_events.append([from_id,to_id]))
	t.autoload("TimeManager").is_paused = true
	await t.physics(3)
	for bridge in stage.registry.bridges:
		for end in 2:
			var mouth: Vector2 = bridge.gate_path[0 if end == 0 else bridge.gate_path.size()-1]
			var platform := stage.registry.get_level(bridge.from_id if end == 0 else bridge.to_id)
			var tangent := (bridge.gate_path[1]-bridge.gate_path[0]).normalized()
			if end == 1: tangent = (bridge.gate_path[bridge.gate_path.size()-2]-bridge.gate_path[bridge.gate_path.size()-1]).normalized()
			var at := mouth-tangent*30
			var lv := stage.registry.level_at(at)
			t.check("join_rank_%s_%d" % [bridge.id,end], lv != null and stage.registry.draw_rank(at,lv) >= maxi(platform.rank,bridge.rank))
		for reverse in 2:
			var a: Vector2 = bridge.path[0 if reverse == 0 else bridge.path.size()-1]
			var b: Vector2 = bridge.path[bridge.path.size()-1 if reverse == 0 else 0]
			var dir := (b-a).normalized()
			var start := a-dir*65
			var finish := b+dir*65
			# Insets at both mouths exercise the platform -> bridge -> platform handoff.
			p.global_position = start
			p.velocity = Vector2.ZERO
			p._gvel = Vector2.ZERO
			stage.tracker.refresh(p)
			var seen: Array[StringName] = []
			var clean := true
			for frame in 650:
				var delta := finish-p.global_position
				if delta.length() < 20: break
				var input := Iso.to_ground(delta).normalized()
				_set_input(input)
				await t.tree.physics_frame
				var level := stage.registry.level_at(p.global_position)
				if level != null:
					if not level.id in seen: seen.append(level.id)
					clean = clean and p.z_index == stage.registry.draw_rank(p.global_position, level)
			_set_input(Vector2.ZERO)
			await t.physics(2)
			var label := "%s_%s" % [bridge.id,"back" if reverse else "out"]
			t.check("walk_"+label, p.global_position.distance_to(finish) < 35 and seen.has(bridge.id), "levels %s; remaining %.1f px" % [seen,p.global_position.distance_to(finish)])
			t.check("depth_"+label, clean, "all moving frames use the connected deck draw rank")
			if native and reverse == 0:
				p.global_position = a+dir*30
				stage.tracker.refresh(p)
				p.camera.position_smoothing_enabled = false
				p.camera.reset_smoothing()
				await t.frames(3)
				await t.capture("city_join_"+str(bridge.id))
	for lane in stage.lanes:
		if lane.perk_only: continue
		p.global_position = lane.start_pos
		p._gvel = Vector2.ZERO
		p.velocity = Vector2.ZERO
		stage.tracker.refresh(p)
		var began := lane.climb(p)
		await t.until(func(): return not lane.climbing, 5.0)
		await t.physics(2)
		t.check("stairs_"+str(lane.from_id), began and p.global_position.distance_to(lane.finish_pos) < 3 and ActorLevel.level_id(p) == lane.to_id and not ActorLevel.is_locked(p) and p.state == Player2D.S.FREE)
		if native: await t.capture("stairs_"+str(lane.from_id))

	# All platform front walkways remain reachable and recoverable from the test menu.
	for level in stage.registry.platforms:
		var at: Variant = stage.registry.safe_point(level.id)
		t.check("platform_"+str(level.id), at is Vector2 and stage.registry.level_id_at(at) == level.id)
	t.check("draw_handoffs_do_not_emit_false_level_changes", logical_events.all(func(event): return event[0] != event[1]))
	t.autoload("TimeManager").is_paused = false
	_set_input(Vector2.ZERO)
func _set_input(v: Vector2) -> void:
	for pair in [[&"move_right",v.x],[&"move_left",-v.x],[&"move_back",v.y],[&"move_forward",-v.y]]:
		if pair[1] > 0: Input.action_press(pair[0],pair[1])
		else: Input.action_release(pair[0])
