extends "res://tests/acceptance/net_peer.gd"
## Legal public redraw close, complete offline value/reference graph, then a
## genuinely new connected World. No manual repair of the restored profiles.
var saved: Dictionary
var fallback: RefCounted
var graph := {}
var fired := false
var immediate := false
var notifications := 0

func _run() -> void:
	var host := str(options.role) == "host"
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	check("isolated_user_data", OS.get_user_data_dir().begins_with(OS.get_environment("HOME") + "/"))
	if host:
		root.get_node("GameManager").start_new_game("Host", 0)
		root.get_node("GameManager").set_flag(&"intro_pending", false)
	else:
		# Existing offline p0 plus an unrelated offline row; keep every original
		# field, array and nested dictionary reachable for identity assertions.
		var row: RefCounted = registry.peek_state(&"p0")
		row.gold = 827
		row.stamina = 37.0
		row.max_stamina = 83.0
		row.inventory.append({"id": &"turnip", "amount": 7, "meta": {"keepsake": ["offline", {"n": 2}]}})
		row.hotbar = [{"slot": [1, 2]}]
		var other: RefCounted = load("res://scripts/player/player_state.gd").new(&"p3", 4)
		other.gold = 913
		other.owed = [{"item": "wood", "meta": {"nested": [3]}}]
		registry._states[&"p3"] = other
		saved = registry._states
		fallback = registry._fallback_state
		for id in saved:
			var fields := {}
			for property in saved[id].get_property_list():
				if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
					fields[property.name] = capture(saved[id].get(property.name))
			graph[id] = {"row": saved[id], "fields": fields}
	var world: Node = await make_world(host)
	check("transport_started", start(world, host) == OK)
	if host: marker("hosting")
	check("application_admitted", await admitted(world, host))
	freeze_bodies(world)
	# Retain the actual initial admitted roster for the supervisor's existing
	# exact peer/slot/camera reconciliation, before the deliberate close.
	details["view"] = []
	for body in world.all_players():
		details.view.append({"id": str(body.player_id), "peer": body.peer_id, "local": body.is_local, "camera": body.camera != null and body.camera.enabled, "registered": registry.registered_id(body) == body.player_id})
	details["self_peer"] = world.session.api.get_unique_id()
	details["generation"] = world.session.generation
	details["packets_received"] = world.session.packets_received
	marker(str(options.role) + "-admitted")
	if host:
		root.get_node("TimeManager").pause_time()
		var cells: Array = world.farm.farmable_cells()
		world.farm.till(cells[0])
		world.farm.till(cells[1])
		await _wait_file(path("guest-prepare"), 10.0)
		world.farm_replication.publish()
		await _wait_file(path("guest-armed"), 10.0)
		world.farm_replication.publish()
		await _wait_file(path("guest-closed"), 10.0)
	else:
		marker("guest-prepare")
		var end := Time.get_ticks_msec() + 10000
		while world.farm_replication.projection == null and Time.get_ticks_msec() < end: await process_frame
		check("nonempty_projection_ready", world.farm_replication.projection != null and world.farm_replication.projection.plots.size() >= 2)
		if world.farm_replication.projection != null:
			world.farm_replication.projection.plot_changed.connect(func(_cell):
				notifications += 1
				if fired: return
				fired = true
				world.session.close()
				immediate = intact())
		marker("guest-armed")
		end = Time.get_ticks_msec() + 10000
		while not fired and Time.get_ticks_msec() < end: await process_frame
		check("close_callback_executed", fired and world.session.state == &"ended")
		check("offline_immediate_integrity", immediate)
		check("offline_unwound_integrity", intact())
		check("retired_snapshot_serial_zero", world.farm_replication.received == 0)
		check("retired_notifications_stop", notifications == 1)
		for tick in 3: await process_frame
		check("offline_late_integrity", intact())
		world.queue_free()
		await process_frame
		await process_frame
		world = await make_world(false)
		check("successor_transport_started", start(world, false) == OK)
		marker("guest-closed")
	# Host stays genuinely live; successor guest goes through ordinary admission
	# and receives a new authoritative farm snapshot without repaired state.
	if host:
		var end := Time.get_ticks_msec() + 15000
		while world.all_players().size() != 2 and Time.get_ticks_msec() < end: await process_frame
		await _wait_file(path("successor-admitted"), 15.0)
		world.farm_replication.publish()
		marker("successor-published")
		await _wait_file(path("successor-observed"), 10.0)
		check("successor_progress", world.session.state == &"hosting" and world.all_players().size() == 2)
		marker("successor-host-observed")
	else:
		check("successor_admitted", await admitted(world, false))
		freeze_bodies(world)
		marker("successor-admitted")
		await _wait_file(path("successor-published"), 10.0)
		var end := Time.get_ticks_msec() + 10000
		while world.farm_replication.received == 0 and Time.get_ticks_msec() < end: await process_frame
		check("successor_progress", world.session.state == &"connected" and world.farm_replication.received > 0 and world.farm_replication.projection != null and world.farm_replication.projection.plots.size() >= 2)
		marker("successor-observed")
		await _wait_file(path("successor-host-observed"), 10.0)
		world.session.close()
		check("successor_close_preserves_offline", intact())
	marker(str(options.role) + "-done")
	var deadline := Time.get_ticks_msec() + 10000
	while not everyone_done() and Time.get_ticks_msec() < deadline: await process_frame
	check("all_counterparts_done", everyone_done())
	world.session.close()
	world.queue_free()
	await process_frame
	await root.get_node("AudioManager").prepare_shutdown()
	_finish()

func path(id: String) -> String: return str(options.directory).path_join(id)

func make_world(host: bool) -> Node:
	var world: Node = load("res://scripts/world2d/world_2d.gd").new()
	world.name = "World"
	world.guest_bootstrap = not host
	root.add_child(world)
	current_scene = world
	var deadline := Time.get_ticks_msec() + 15000
	while host and not world.ready_for_play and Time.get_ticks_msec() < deadline: await process_frame
	world.farm_replication.set_process(false)
	return world

func start(world: Node, host: bool) -> int:
	return world.session.host(int(options.port), 4, "127.0.0.1") if host else world.session.join("127.0.0.1", int(options.port), {"name": "Guest", "character_type": 1, "character_skin": "fairy_meadow"})

func admitted(world: Node, host: bool) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while (world.session.state != (&"hosting" if host else &"connected") or world.all_players().size() != 2) and Time.get_ticks_msec() < deadline: await process_frame
	return world.session.state == (&"hosting" if host else &"connected") and world.all_players().size() == 2

func freeze_bodies(world: Node) -> void:
	world.sync.set_physics_process(false)
	for body in world.all_players(): body.set_physics_process(false)

func capture(value: Variant) -> Dictionary:
	var out := {"value": value}
	if value is Array:
		out["children"] = []
		for entry in value: out.children.append(capture(entry))
	elif value is Dictionary:
		out["children"] = {}
		for key in value: out.children[key] = capture(value[key])
	return out

func matches(value: Variant, before: Dictionary) -> bool:
	if typeof(value) != typeof(before.value): return false
	if value is Array:
		if not is_same(value, before.value) or value.size() != before.children.size(): return false
		for i in value.size():
			if not matches(value[i], before.children[i]): return false
	elif value is Dictionary:
		if not is_same(value, before.value) or value.size() != before.children.size(): return false
		for key in before.children:
			if not value.has(key) or not matches(value[key], before.children[key]): return false
	elif value != before.value: return false
	return true

func intact() -> bool:
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	if not is_same(registry._states, saved) or registry._fallback_state != fallback or saved.size() != graph.size(): return false
	for id in graph:
		if not saved.has(id) or saved[id] != graph[id].row: return false
		for field in graph[id].fields:
			if not matches(saved[id].get(field), graph[id].fields[field]): return false
	return true
