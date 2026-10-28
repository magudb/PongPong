extends RefCounted
## Standalone opt-in guard controls, deliberately outside automatic section discovery.
const SECTION := "scoped_input_control"
const TIMEOUT_S := 90.0
const HELPER := "res://tests/lib/scoped_input_observer.gd"
func run(t) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var p: Player2D = w.player
	p.set_physics_process(false)
	t.check("registered_production_body", PlayerRegistry.registered_id(p) == &"p0")
	var lease = null
	if FileAccess.file_exists(HELPER):
		lease = load(HELPER).new()
		t.root.add_child(lease)
		lease.begin(t, p, t.out_dir.path_join("foreign.jsonl"))
	var event := InputEventMouseMotion.new()
	event.position = Vector2(452, 1068)
	event.relative = Vector2(30, 0)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	t.check("foreign_reaches_production", p.controls.pointer_position(t.root) == event.position and p._cursor_screen == event.position)
	var result: Dictionary = lease.close() if lease != null else {}
	t.check("foreign_interval_rejected", result.get("accepted", true) == false, result)
	if lease != null:
		lease.queue_free()
	await _owned_route(t, p)
	await _lifetime(t)
	await t.start_world()
	p = t.world().player
	p.set_physics_process(false)
	await _driver_and_delivery(t, p)
	await _held(t, false)
	await _pause_and_markers(t)
	await _edges(t)
	await _startup_readonly(t)
	await _replacement_and_cleanup(t)

func _replacement_and_cleanup(t) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var p: Player2D = w.player
	p.set_physics_process(false)
	var lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, p, t.out_dir.path_join("same_id_old.jsonl"))
	_motion(lease)
	var replacement := Player2D.new()
	w._register_player(replacement, 0, 1)
	w.add_child(replacement)
	replacement.enter_area(w.area, p.global_position)
	replacement.set_physics_process(false)
	t.check("same_id_old_refused", not lease.close().get("accepted", true) and PlayerRegistry.registered_id(replacement) == &"p0")
	var next = load(HELPER).new()
	t.root.add_child(next)
	next.begin(t, replacement, t.out_dir.path_join("same_id_new.jsonl"))
	lease.close()
	_motion(next)
	t.check("same_id_new_positive", next.close().get("accepted", false) and replacement._cursor_screen == Vector2(240, 260))
	lease.queue_free()
	next.queue_free()
	p.queue_free()
	var context = load("res://tests/lib/t.gd").new()
	context.bind(t.tree)
	context.begin_section("cleanup_control")
	lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(context, replacement, t.out_dir.path_join("cleanup.jsonl"))
	_motion(lease)
	t.check("cleanup_registered_once", await context.run_cleanups() == 1)
	t.check("cleanup_closed_clean", lease.close().get("accepted", false) and not t.root.has_meta(&"_test_scoped_input_observer"))
	t.check("cleanup_idempotent", await context.run_cleanups() == 0)
	lease.queue_free()
	context.begin_section("timeout_control")
	lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(context, replacement, t.out_dir.path_join("detached_auto.jsonl"))
	_motion(lease)
	context.detached = true
	await t.frames(2)
	t.check("detached_auto_closed", lease._closed and not lease.close().get("accepted", true))
	lease.queue_free()
	lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, replacement, t.out_dir.path_join("queued_owner.jsonl"))
	_motion(lease)
	replacement.queue_free()
	t.check("queued_owner_refused", not lease.close().get("accepted", true))
	lease.queue_free()
	await t.frames(2)
	t.check("queued_owner_freed_without_callback_error", not is_instance_valid(replacement))
	await t.start_world()
	w = t.world()
	p = w.player
	p.set_physics_process(false)
	lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, p, t.out_dir.path_join("world_detached.jsonl"))
	_motion(lease)
	w.get_parent().remove_child(w)
	w.queue_free()
	await t.frames(2)
	t.check("world_detachment_closed", lease._closed and not lease.close().get("accepted", true))
	lease.queue_free()

func _edges(t) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var p: Player2D = w.player
	p.set_physics_process(false)
	var lease = load(HELPER).new()
	t.root.add_child(lease)
	t.check("begin_owned_lease", lease.begin(t, p, t.out_dir.path_join("first.jsonl")))
	_motion(lease)
	var sibling = load(HELPER).new()
	t.root.add_child(sibling)
	t.check("overlap_refused", not sibling.begin(t, p, t.out_dir.path_join("overlap.jsonl")))
	t.check("failed_start_rejected", not sibling.close().get("accepted", true))
	sibling.queue_free()
	var result: Dictionary = lease.close()
	t.check("close_idempotent", result == lease.close() and result.accepted)
	var next = load(HELPER).new()
	t.root.add_child(next)
	next.begin(t, p, t.out_dir.path_join("next.jsonl"))
	lease.close()
	t.tap_key(KEY_F10)
	Input.flush_buffered_events()
	t.check("old_close_keeps_new_lease", next.close().get("accepted", false))
	next.queue_free()
	lease.queue_free()
	lease = load(HELPER).new()
	t.root.add_child(lease)
	t.check("invalid_owner_refused", not lease.begin(t, null, t.out_dir.path_join("invalid.jsonl")))
	t.check("invalid_owner_rejected", not lease.close().get("accepted", true))
	lease.queue_free()
	lease = load(HELPER).new()
	t.root.add_child(lease)
	t.check("stream_open_refused", not lease.begin(t, p, t.out_dir.path_join("missing-dir/stream.jsonl")))
	t.check("stream_open_rejected", not lease.close().get("accepted", true))
	lease.queue_free()
	lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, p, t.out_dir.path_join("closed_stream.jsonl"))
	_motion(lease)
	lease._file.close()
	result = lease.close()
	t.check("closed_stream_rejected", not result.get("accepted", true), result)
	lease.queue_free()
	lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, p, t.out_dir.path_join("bounded.jsonl"))
	for i in 2100:
		_motion(lease)
	result = lease.close()
	t.check("ledger_bound_rejected", not result.get("accepted", true) and result.first_failure == "stream_bound_exceeded" and lease._rows == lease.MAX_ROWS, result)
	lease.queue_free()

func _pause_and_markers(t) -> void:
	await t.start_world()
	var p: Player2D = t.world().player
	p.set_physics_process(false)
	p.controls.bind_pad(2)
	var lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, p, t.out_dir.path_join("paused.jsonl"))
	var axis := InputEventJoypadMotion.new()
	axis.device = 2
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	lease.tag(axis)
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	t.check("paused_pad_live_positive", p.controls.move_vector() == Vector2.RIGHT)
	var gm: Node = t.autoload("GameManager")
	gm.push_modal(&"scoped_input_pause", true)
	axis = axis.duplicate()
	axis.axis_value = 0.0
	lease.tag(axis)
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	await t.frames(1)
	t.check("paused_raw_release", t.tree.paused and p.controls.move_vector() == Vector2.ZERO and p.process_mode != Node.PROCESS_MODE_ALWAYS)
	gm.pop_modal(&"scoped_input_pause")
	var result: Dictionary = lease.close()
	t.check("paused_observer_clean", result.get("accepted", false), result)
	lease.queue_free()
	p.controls.bind_default()
	for mode in ["wrong", "lost", "replayed"]:
		lease = load(HELPER).new()
		t.root.add_child(lease)
		lease.begin(t, p, t.out_dir.path_join(mode + ".jsonl"))
		_motion(lease)
		var event := InputEventMouseMotion.new()
		event.position = Vector2(452, 1068)
		event.relative = Vector2(30, 0)
		lease.tag(event)
		match mode:
			"wrong": event.set_meta(&"_test_input_provenance", {"lease": -1, "sequence": 2})
			"lost": event.remove_meta(&"_test_input_provenance")
			"replayed": event.set_meta(&"_test_input_provenance", {"lease": lease.get_instance_id(), "sequence": 1})
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		t.check(mode + "_still_reaches_body", p._cursor_screen == event.position)
		result = lease.close()
		t.check(mode + "_unowned_rejected", not result.get("accepted", true) and result.get("unowned", 0) > 0, result)
		lease.queue_free()

func _driver_and_delivery(t, p: Player2D) -> void:
	var lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, p, t.out_dir.path_join("driver.jsonl"))
	var button := Button.new()
	button.position = Vector2(24, 24)
	button.size = Vector2(120, 40)
	button.text = "Guard GUI"
	var layer := CanvasLayer.new()
	layer.layer = 200
	t.root.add_child(layer)
	layer.add_child(button)
	var presses := [0]
	button.pressed.connect(func(): presses[0] += 1)
	t.root.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	await t.frames(1)
	t.click(Vector2(70, 40))
	t.check("shared_driver_real_gui", presses[0] == 1)
	layer.queue_free()
	t.move_mouse(Vector2(320, 280))
	t.tap_key(KEY_F10)
	Input.flush_buffered_events()
	var result: Dictionary = lease.close()
	t.check("shared_driver_owned", result.get("accepted", false) and result.get("owned", 0) > 0, result)
	lease.queue_free()
	lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, p, t.out_dir.path_join("lost_delivery.jsonl"))
	var event := InputEventMouseMotion.new()
	lease.tag(event, "parse")
	# Tagged but never delivered is not a clean tested interval.
	result = lease.close()
	t.check("lost_delivery_rejected", not result.get("accepted", true), result)
	lease.queue_free()

func _held(t, foreign: bool) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var p: Player2D = w.player
	var mouse = load("res://tests/sections/mouse_targeting.gd").new()
	p.set_physics_process(false)
	mouse._free(p)
	var centre: Vector2i = mouse._open_field(w, p)
	t.check("held_fixture_open", centre != Vector2i(-1, -1))
	p.global_position = w.area.cell_to_global(centre)
	p.camera.reset_smoothing()
	await t.physics(2)
	t.root.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	var lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, p, t.out_dir.path_join("held_foreign.jsonl" if foreign else "held_owned.jsonl"))
	if foreign:
		_replay_after_hold(t)
	await mouse._hold_repeats(t, w, p, centre)
	var result: Dictionary = lease.close()
	t.check("held_guard_rejects" if foreign else "held_guard_accepts", not result.get("accepted", true) if foreign else result.get("accepted", false), result)
	t.check("held_real_tool_ledger", result.get("tools", 0) >= 3, result)
	lease.queue_free()

func _replay_after_hold(t) -> void:
	# Thirty ticks to the second intended cell, then twenty ticks into that hold.
	await t.physics(50)
	# Explicit injected replay, NOT hardware. Normal production/GUI/singleton route.
	var event := InputEventMouseMotion.new()
	event.position = Vector2(452, 1068)
	event.global_position = event.position
	event.relative = Vector2(44, -12)
	event.velocity = Vector2(-859.0035, 139.8378)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _motion(lease, pos := Vector2(240, 260)) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.relative = Vector2(30, 0)
	lease.tag(event, "parse")
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _lifetime(t) -> void:
	for kind in ["detached", "same_section_replaced", "wrong_section", "source_replaced", "source_null", "source_detached", "source_rebound", "profile_replaced", "owner_unregistered", "owner_detached", "owner_freed"]:
		await t.start_world()
		var w: WorldRoot2D = t.world()
		var p: Player2D = w.player
		p.set_physics_process(false)
		# A real helper `t` with actual begin_section calls, never fabricated generations.
		var context = load("res://tests/lib/t.gd").new()
		context.bind(t.tree)
		context.begin_section("lease_lifetime")
		var lease = load(HELPER).new()
		t.root.add_child(lease)
		lease.begin(context, p, t.out_dir.path_join(kind + ".jsonl"))
		_motion(lease)
		t.check(kind + "_live_positive", PlayerRegistry.registered_id(p) == &"p0" and p._cursor_screen == Vector2(240, 260))
		var controls = p.controls
		var states: Dictionary = PlayerRegistry._states.duplicate()
		match kind:
			"detached": context.detached = true
			"same_section_replaced": context.begin_section("lease_lifetime")
			"wrong_section": context.begin_section("a_different_section")
			"source_replaced": p.controls = PlayerInput.new()
			"source_null":
				p.controls = null
				controls = null
			"source_detached": p.controls.detach()
			"source_rebound": p.controls.bind_pad(2)
			"owner_freed": p.free()
			"profile_replaced": PlayerRegistry._states[&"p0"] = PlayerState.new(&"p0", 1)
			"owner_unregistered": w._unregister_player(p)
			"owner_detached": p.get_parent().remove_child(p)
		var result: Dictionary = lease.close()
		t.check(kind + "_rejects", not result.get("accepted", true), result)
		if is_instance_valid(p):
			p.controls = controls if controls != null else PlayerInput.new()
			if controls == null:
				p.controls.attach(p)
		PlayerRegistry._states = states
		if kind == "owner_detached":
			p.queue_free()
		lease.queue_free()

func _roster_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for id in PlayerRegistry._states:
		var row: PlayerState = PlayerRegistry._states[id]
		var properties: Dictionary = {}
		for property in row.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				properties[str(property.name)] = var_to_str(row.get(property.name))
		snapshot[str(id)] = {"instance": row.get_instance_id(), "contents": row.to_dict().duplicate(true), "properties": properties}
	return snapshot

func _startup_readonly(t) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	w.player.set_physics_process(false)
	var p := Player2D.new()
	w._register_player(p, 1, 1)
	w.add_child(p)
	p.enter_area(w.area, w.player.global_position)
	p.set_physics_process(false)
	p.controls.bind_pad(2)
	# Legitimate fixture setup, before the reset under test. Never call state after reset.
	var profile: PlayerState = PlayerRegistry.state(&"p1", t.tree)
	var states: Dictionary = PlayerRegistry._states.duplicate()
	var fallback: PlayerState = PlayerRegistry._fallback_state
	var controls = p.controls
	var revision: int = controls.revision
	var axis := InputEventJoypadMotion.new()
	axis.device = 2
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	t.check("startup_registered_p1_positive", PlayerRegistry.registered_id(p) == &"p1" and PlayerRegistry.by_id(&"p1", t.tree) == p and p.is_local)
	t.check("startup_p1_controls_positive", controls._attached and controls.local_active() and controls.accepts_event(axis) and controls.move_vector() == Vector2.RIGHT)
	t.check("startup_p1_profile_positive", PlayerRegistry._states.get(&"p1") == profile)
	axis = axis.duplicate()
	axis.axis_value = 0.0
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	for missing in [false, true]:
		for mode in ["normal", "overlap", "stream_open", "invalid_owner", "invalid_start"]:
			PlayerRegistry._states = states.duplicate()
			var holder = null
			var prefix: String = "startup_" + ("missing_" if missing else "existing_") + mode
			if mode == "overlap":
				holder = load(HELPER).new()
				t.root.add_child(holder)
				holder.begin(t, w.player, t.out_dir.path_join(prefix + "_holder.jsonl"))
				_motion(holder)
			if missing:
				PlayerRegistry.reset_states()
				# Keep every other row and the physical/control incarnation exact: only p1 is absent.
				PlayerRegistry._fallback_state = fallback
				for id in states:
					if id != &"p1":
						PlayerRegistry._states[id] = states[id]
			var before: Dictionary = _roster_snapshot()
			t.check(prefix + "_precondition", PlayerRegistry.registered_id(p) == &"p1" and PlayerRegistry.by_id(&"p1", t.tree) == p and p.is_local and p.controls == controls and controls.revision == revision and controls._attached and controls.local_active() and PlayerRegistry._states.has(&"p1") == (not missing))
			var lease = load(HELPER).new()
			if mode != "invalid_start":
				t.root.add_child(lease)
			var path: String = t.out_dir.path_join("missing-dir/" + prefix + ".jsonl" if mode == "stream_open" else prefix + ".jsonl")
			var started: bool = lease.begin(t, null if mode == "invalid_owner" else p, path)
			var after_begin: Dictionary = _roster_snapshot()
			var expected := ""
			if mode == "invalid_start": expected = "invalid_start"
			elif mode == "invalid_owner": expected = "invalid_owner"
			elif missing: expected = "missing_profile"
			elif mode == "overlap": expected = "overlapping_lease"
			elif mode == "stream_open": expected = "stream_open_failed"
			t.check(prefix + "_start_result", started == (expected == "") and lease._first_failure == expected, {"started": started, "reason": lease._first_failure, "expected": expected})
			t.check(prefix + "_begin_roster_unchanged", before == after_begin, {"before": before, "after": after_begin})
			if started and expected == "":
				var button := InputEventJoypadButton.new()
				button.device = 2
				button.button_index = JOY_BUTTON_BACK
				lease.tag(button)
				Input.parse_input_event(button)
				Input.flush_buffered_events()
			var result: Dictionary = lease.close()
			var after_close: Dictionary = _roster_snapshot()
			t.check(prefix + "_close_result", result.accepted == (expected == "") and result.first_failure == expected, result)
			t.check(prefix + "_close_roster_unchanged", before == after_close, {"before": before, "after": after_close})
			print("STARTUP_READONLY_SNAPSHOT " + JSON.stringify({"variant": prefix, "before": before, "after_begin": after_begin, "after_close": after_close, "result": result}))
			lease.free()
			if holder != null:
				t.check(prefix + "_holder_positive", holder.close().accepted)
				holder.queue_free()
	PlayerRegistry._states = states
	PlayerRegistry._fallback_state = fallback
	w._unregister_player(p)

func _owned_route(t, p: Player2D) -> void:
	var lease = load(HELPER).new()
	t.root.add_child(lease)
	lease.begin(t, p, t.out_dir.path_join("owned.jsonl"))
	var event := InputEventMouseMotion.new()
	event.position = Vector2(240, 260)
	event.relative = Vector2(30, 0)
	if lease.has_method("tag"):
		lease.tag(event, "parse")
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	t.check("owned_reaches_production", p.controls.pointer_position(t.root) == event.position and p._cursor_screen == event.position)
	var result: Dictionary = lease.close()
	t.check("owned_interval_accepted", result.get("accepted", false) and result.get("owned", 0) == 2, result)
	lease.queue_free()
