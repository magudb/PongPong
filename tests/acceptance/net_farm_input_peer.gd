extends "res://tests/acceptance/net_farm_peer.gd"
## Real queued raw events through Capture/_unhandled_input. Stationary action
## fixture only: WorldSync and body physics are disabled, not input processing.
var input_trace := []
var active_role := ""

func _movement(world: Node, host: bool) -> void:
	# Standalone headless SceneTree defaults to a 64x64 dummy window.
	# Match tests/playtest.gd so real mouse events can hit the designed viewport.
	root.size = Vector2i(1280, 720)
	world.sync.set_physics_process(false)
	for body in world.all_players(): body.set_physics_process(false)
	if host: root.get_node("TimeManager").pause_time()
	if not host:
		files_before = save_hashes(root.get_node("SaveManager").save_dir)
		root.get_node("EventBus").item_gained.connect(func(_id, _item, _amount): guest_events.item += 1)
		root.get_node("EventBus").crop_harvested.connect(func(_plot, _crop, _amount): guest_events.crop += 1)
	_write_json(path("input-identity-" + str(options.role)), {"id": str(world.local_player().player_id)})
	marker("input-ready-" + str(options.role))
	for i in range(1, int(options.count)): await _wait_file(path("input-ready-guest%d" % i), 10.0)
	for actor_index in range(1, int(options.count)):
		active_role = "guest%d" % actor_index
		farmer = StringName(_read_json(path("input-identity-" + active_role)).id)
		var body: Node = world.player_by_id(farmer)
		if host:
			cell = world.farm.farmable_cells()[actor_index * 5]
			body.global_position = world.area.cell_to_global(cell + Vector2i(1, 0))
			costs = {}
			for item in [&"hoe_wooden", &"turnip_seeds", &"watering_can_copper"]:
				costs[str(item)] = load("res://scripts/world2d/player_registry.gd").for_player(farmer, func() -> float:
					return float(load("res://scripts/world2d/game_data.gd").item_def(item).get("stamina_cost", 4.0)) * float(load("res://scripts/data/species_perks.gd").value(load("res://scripts/world2d/player_registry.gd").peek_state(farmer).character_skin, "tool_cost_mult", 1.0)))
			_write_json(path(active_role + "-fixture"), {"cell": [cell.x, cell.y], "costs": costs})
			marker(active_role + "-fixture-ready")
		else:
			await _wait_file(path(active_role + "-fixture-ready"), 10.0)
			var fixture := _read_json(path(active_role + "-fixture"))
			cell = Vector2i(int(fixture.cell[0]), int(fixture.cell[1]))
			costs = fixture.costs
			var end := Time.get_ticks_msec() + 2000
			while world.farm_replication.presentation_area == null and Time.get_ticks_msec() < end: await process_frame
			var view: Node = world.farm_replication.presentation_area
			body.global_position = view.cell_to_global(cell + Vector2i(1, 0))
			for facing in 8:
				if view.facing_step(facing) == Vector2i(-1, 0): body.facing8 = facing
			# Initial hotbar fixture only. Selections below are raw physical keys.
			body.hotbar.assign(0, &"hoe_wooden")
			body.hotbar.assign(1, &"turnip_seeds")
			body.hotbar.assign(2, &"watering_can_copper")
			if str(options.role) == active_role:
				body.camera.reset_smoothing()
				body.camera.force_update_scroll()
		for gate in ["modal", "paused_modal", "state", "flight", "event", "travel", "foreign", "ownership", "departure", "selection"]:
			await input_round(world, host, gate, KEY_1, KEY_X)
			var record: Dictionary = rounds[active_role + "-" + gate]
			check(active_role + "_input_gate_" + gate, record.before == record.after and record.unchanged_sequence and record.matched and record.selection_ok)
		await input_round(world, host, "till", KEY_1, KEY_X)
		var till: Dictionary = rounds[active_role + "-till"]
		check(active_role + "_input_till", int(till.after.farm.plots.get(key(cell), {}).get("state", -1)) == 1 and till.result.get("ok") == true and till.result.get("actor") == str(farmer))
		check(active_role + "_input_till_cost", cost_owner(till, float(costs.hoe_wooden), "", 0))
		check(active_role + "_input_till_projection", till.matched)
		await input_round(world, host, "plant", KEY_2, KEY_X)
		var plant: Dictionary = rounds[active_role + "-plant"]
		check(active_role + "_input_plant", int(plant.after.farm.plots.get(key(cell), {}).get("state", -1)) == 2 and plant.result.get("ok") == true)
		check(active_role + "_input_plant_cost", cost_owner(plant, float(costs.turnip_seeds), "turnip_seeds", -1))
		check(active_role + "_input_plant_projection", plant.matched)
		await input_round(world, host, "water", KEY_3, KEY_X)
		var water: Dictionary = rounds[active_role + "-water"]
		check(active_role + "_input_water", int(water.after.farm.plots.get(key(cell), {}).get("state", -1)) == 3 and water.result.get("ok") == true)
		check(active_role + "_input_water_cost", cost_owner(water, float(costs.watering_can_copper), "", 0))
		check(active_role + "_input_water_projection", water.matched)
		for day_index in range(4):
			if day_index > 0: await input_round(world, host, "grow-water-%d" % day_index, KEY_3, KEY_X)
			if host:
				root.get_node("GameManager").day += 1
				world.farm._on_day_started(root.get_node("GameManager").day, &"foraar")
				world.farm_replication.publish()
				marker(active_role + "-grown-%d" % day_index)
			else: await _wait_file(path(active_role + "-grown-%d" % day_index), 10.0)
		if host:
			var probe := RandomNumberGenerator.new()
			for seed_value in range(1, 100):
				probe.seed = seed_value
				if probe.randf() < 0.2:
					world.farm.rng.seed = seed_value
					break
		await input_round(world, host, "harvest", KEY_1, KEY_E)
		var harvest: Dictionary = rounds[active_role + "-harvest"]
		check(active_role + "_input_growth", int(harvest.before.farm.plots.get(key(cell), {}).get("state", -1)) == 4)
		check(active_role + "_input_harvest", int(harvest.after.farm.plots.get(key(cell), {}).get("state", -1)) == 1 and harvest.result.get("ok") == true and harvest.result.get("actor") == str(farmer))
		check(active_role + "_input_reward", cost_owner(harvest, 0.0, "turnip", 1))
		check(active_role + "_input_harvest_projection", harvest.matched)
		# Same input entry, now mouse targeting. Far clicks must not be silently
		# remapped to an adjacent tile; near clicks plant the clicked target.
		await input_round(world, host, "far-click", KEY_2, 0, "far")
		var far: Dictionary = rounds[active_role + "-far-click"]
		check(active_role + "_input_far_click", far.before == far.after and far.unchanged_sequence and far.matched)
		await input_round(world, host, "gui-click", KEY_2, 0, "gui")
		var gui: Dictionary = rounds[active_role + "-gui-click"]
		check(active_role + "_input_gui_occlusion", gui.before == gui.after and gui.unchanged_sequence and gui.matched and gui.mouse_gui)
		await input_round(world, host, "near-click", KEY_2, 0, "near")
		var near: Dictionary = rounds[active_role + "-near-click"]
		check(active_role + "_input_near_click", int(near.after.farm.plots.get(key(cell), {}).get("state", -1)) == 2 and near.result.get("ok") == true and cost_owner(near, float(costs.turnip_seeds), "turnip_seeds", -1) and near.matched)
	if not host:
		check("input_guest_projection_only", world.area == null and world.farm == null and not world.ready_for_play and world.local_player().area == null)
		check("input_no_economic_replay", guest_events.item == 0 and guest_events.crop == 0)
		check("input_guest_no_save", not root.get_node("SaveManager").save_game(0) and save_hashes(root.get_node("SaveManager").save_dir) == files_before)
	details["rounds"] = rounds
	details["input_trace"] = input_trace

func raw_key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		# parse_input_event queues dispatch; never judge synchronous scope here.
		for tick in 2: await process_frame
	input_trace.append({"physical_keycode": code})

func raw_click(body: Node, view: Node, mode: String) -> bool:
	var at := cell + Vector2i(5, 0) if mode == "far" else cell
	var screen: Vector2 = body.get_canvas_transform() * view.cell_to_global(at)
	var panel: Control
	var layer: CanvasLayer
	if mode == "gui":
		layer = CanvasLayer.new()
		layer.layer = 100
		root.add_child(layer)
		panel = Control.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		layer.add_child(panel)
		panel.position = Vector2.ZERO
		panel.size = root.size
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.relative = Vector2(10, 10)
	Input.parse_input_event(motion)
	for tick in 3: await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = screen
		event.global_position = screen
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
		for tick in 2: await process_frame
	input_trace.append({"mouse": mode, "route": "parse_input_event", "screen": [screen.x, screen.y], "gui": root.gui_get_hovered_control() != null})
	var hit_gui := root.gui_get_hovered_control() == panel and panel != null
	if layer != null:
		layer.queue_free()
		for tick in 2: await process_frame
	return hit_gui

func input_round(world: Node, host: bool, name: String, slot_key: int, action_key: int, mouse := "") -> void:
	var label := active_role + "-" + name
	for tick in 24: await physics_frame
	if host:
		_write_json(path(label + "-before"), state(world, true))
		marker(label + "-go")
	else:
		await _wait_file(path(label + "-go"), 10.0)
		if str(options.role) == active_role:
			var previous: int = world.intents._sequence
			var body: Node = world.local_player()
			var gm := root.get_node("GameManager")
			var parent: Node = body.get_parent()
			var mouse_gui := false
			var selection_ok := true
			await raw_key(slot_key)
			match name:
				"modal": gm.push_modal(&"input_fixture", false)
				"paused_modal": gm.push_modal(&"input_fixture", true)
				"state": body.state = load("res://scripts/world2d/player_body_2d.gd").S.HURT
				"flight": body.is_flying = true
				"event": body._event_active = true
				"travel": world.traveling = true
				"ownership": body.controls.bind_pad(2)
				"departure": parent.remove_child(body)
			if name in ["foreign", "selection"]:
				if name == "selection": await raw_key(KEY_3)
				for pressed in [true, false]:
					var event := InputEventJoypadButton.new()
					event.device = 7 if name == "foreign" else 0
					event.button_index = JOY_BUTTON_X if name == "foreign" else JOY_BUTTON_DPAD_RIGHT
					event.pressed = pressed
					Input.parse_input_event(event)
					for tick in 2: await process_frame
				if name == "selection": selection_ok = body.hotbar.selected == 3
			elif mouse == "": await raw_key(action_key)
			else: mouse_gui = await raw_click(body, world.farm_replication.presentation_area, mouse)
			match name:
				"modal", "paused_modal": gm.pop_modal(&"input_fixture")
				"state": body.state = load("res://scripts/world2d/player_body_2d.gd").S.FREE
				"flight": body.is_flying = false
				"event": body._event_active = false
				"travel": world.traveling = false
				"ownership": body.controls.bind_default()
				"departure": parent.add_child(body)
			var end := Time.get_ticks_msec() + 700
			while name in ["till", "plant", "water", "harvest", "near-click", "grow-water-1", "grow-water-2", "grow-water-3"] and world.intents.last_result.get("seq", -1) <= previous and Time.get_ticks_msec() < end: await process_frame
			for tick in 3: await physics_frame
			_write_json(path(label + "-result"), {"result": world.intents.last_result, "unchanged_sequence": world.intents._sequence == previous, "selected": str(world.local_player().hotbar.current()), "selection_ok": selection_ok, "mouse_gui": mouse_gui})
			marker(label + "-sent")
	if host:
		await _wait_file(path(label + "-sent"), 10.0)
		_write_json(path(label + "-after"), state(world, true))
		world.farm_replication.publish()
		marker(label + "-checked")
	else: await _wait_file(path(label + "-checked"), 10.0)
	var expected := _read_json(path(label + "-after"))
	var end := Time.get_ticks_msec() + 1000
	while not host and state(world, false) != expected and Time.get_ticks_msec() < end: await process_frame
	var result := _read_json(path(label + "-result"))
	rounds[label] = {"before": _read_json(path(label + "-before")), "after": expected, "result": result.result, "matched": state(world, host) == expected, "unchanged_sequence": result.unchanged_sequence, "selected": result.selected, "selection_ok": result.selection_ok, "mouse_gui": result.mouse_gui}
	marker(label + "-observed-" + str(options.role))
	for i in range(1, int(options.count)): await _wait_file(path(label + "-observed-guest%d" % i), 10.0)
