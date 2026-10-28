extends SceneTree
## One production ENet peer per process. No replacement transport.
var checks: Array = []
var options := {}
var details := {}
var offline_payload := {}
var offline_rows: Dictionary = {}
var offline_files := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var bits := arg.trim_prefix("--").split("=", true, 1)
		if bits.size() == 2: options[bits[0]] = bits[1]
	_run.call_deferred()

func check(id: String, ok: bool) -> void:
	checks.append({"ordinal": checks.size() + 1, "id": id, "ok": ok})
	print("NET_CHECK ", id, " ", ok)

func _run() -> void:
	if str(options.case) == "fifth_client":
		await _capacity_run()
		return
	check("isolated_user_data", OS.get_user_data_dir().begins_with(OS.get_environment("HOME") + "/"))
	check("production_session_available", ResourceLoader.exists("res://scripts/net/multiplayer_session.gd"))
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	var saves := root.get_node("SaveManager")
	if str(options.phase) == "lifetime" and str(options.role) != "host":
		check("offline_save_positive", saves.save_game(0))
		offline_payload = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(0)))
		offline_rows = registry._states
		offline_files = save_hashes(saves.save_dir)
		root.get_node("GameManager").change_phase(2)
		saves._on_day_ended(1, &"foraar") # Enqueued offline; delivery after guest pre-tree binding must refuse.
	if str(options.role) != "host": root.get_node("GameManager").character_skin = &"fairy_meadow" # Staged offline identity is NOT the host projection.
	var world: Node
	if str(options.get("phase", "transport")) != "transport":
		world = load("res://scripts/world2d/world_2d.gd").new()
		var supported := false
		for property in world.get_property_list():
			if property.name == "guest_bootstrap": supported = true
		check("inert_guest_boot_available", supported)
		if not supported:
			world.free()
			_finish()
			return
		world.guest_bootstrap = str(options.role) != "host"
		if str(options.role) == "host":
			get_root().get_node("GameManager").start_new_game("Host", 0)
			get_root().get_node("GameManager").set_flag(&"intro_pending", false)
	else:
		world = Node.new()
	world.name = "World"
	root.add_child(world)
	current_scene = world
	if str(options.get("phase", "transport")) != "transport":
		var ready_deadline := Time.get_ticks_msec() + 15000
		while str(options.role) == "host" and not world.ready_for_play and Time.get_ticks_msec() < ready_deadline:
			await process_frame
	var session: Node
	if world.get("session") != null:
		session = world.session
	else:
		session = load("res://scripts/net/multiplayer_session.gd").new()
		session.name = "MultiplayerSession"
		world.add_child(session)
	var host := str(options.role) == "host"
	var host_queued_files := {}
	if host and str(options.phase) == "lifetime":
		host_queued_files = save_hashes(saves.save_dir)
		saves._on_day_ended(1, &"foraar")
	var guest_type := int(str(options.role).trim_prefix("guest")) if not host else 0
	var metadata := {"name": "Guest", "character_type": guest_type, "character_skin": ["animal_fox", "fairy_meadow", "hobbit_pip", "ghost_bu"][guest_type]}
	if str(options.case) == "area_lifetime" and str(options.role) == "guest2":
		var late_deadline := Time.get_ticks_msec() + 15000
		while not FileAccess.file_exists(str(options.directory).path_join("area-travel-done")) and Time.get_ticks_msec() < late_deadline: await process_frame
	var error: int = session.host(int(options.port), 4, "127.0.0.1") if host else session.join("127.0.0.1", int(options.port), metadata)
	check("transport_started", error == OK)
	if host: marker("hosting")
	# The 5s hello deadline belongs to a connected peer. Initial process startup
	# and all admissions share the separate predeclared 15s admission budget.
	var admission_deadline := Time.get_ticks_msec() + 15000
	var deadline := admission_deadline
	while session.api.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	check("transport_connected", not session.api.get_peers().is_empty())
	deadline = admission_deadline
	while session.packets_received == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	check("production_packet_received", session.packets_received > 0)
	if host and str(options.phase) == "lifetime": check("old_offline_queue_cannot_save_new_session", save_hashes(saves.save_dir) == host_queued_files)
	if str(options.get("phase", "transport")) != "transport":
		if host and str(options.case) == "area_lifetime": await _area_lifetime_before(world, session, admission_deadline)
		deadline = admission_deadline
		while world.all_players().size() != int(options.count) and Time.get_ticks_msec() < deadline:
			await process_frame
		check("matching_roster", world.all_players().size() == int(options.count))
		check("application_admitted", session.state == (&"hosting" if host else &"connected"))
		marker(str(options.role) + "-admitted")
		var locals := 0
		var cameras := 0
		for body in world.all_players():
			if body.is_local: locals += 1
			if body.camera != null and body.camera.enabled: cameras += 1
		check("one_local_camera", locals == 1 and cameras == 1)
		check("p0_alias", world.player == world.player_by_id(&"p0"))
		var catalog: Script = load("res://scripts/isometric/character_catalog.gd")
		var visuals_owned := true
		var input_owned := true
		var passive := true
		var authority_one := true
		var initialized := true
		for body in world.all_players():
			var row: RefCounted = registry.peek_state(body.player_id)
			authority_one = authority_one and body.get_multiplayer_authority() == 1
			if body.player_id != &"p0": initialized = initialized and row.gold == int(root.get_node("GameManager").config_value("economy.starting_gold", 500)) and not row.equipment.is_empty() and not row.wardrobe.get("owned", {}).is_empty() and not row.inventory.is_empty()
			var skin: StringName = root.get_node("GameManager").character_skin if host and body.player_id == &"p0" else row.character_skin
			visuals_owned = visuals_owned and body.visual.character_id == catalog.visual_for_skin(skin)
			input_owned = input_owned and body.controls.local_active() == body.is_local
			if not body.is_local:
				var at: Vector2 = body.global_position
				passive = passive and body.controls.submit_remote_frame({"sequence": 1, "move": [1, 0], "aim": [1, 0], "actions": {"use_tool": true}})
				for tick in 10: body._physics_process(0.016)
				passive = passive and body.global_position == at
		check("all_profile_visuals_owned", visuals_owned)
		check("one_local_input", input_owned)
		check("remote_frames_passive", passive)
		check("server_rpc_authority_on_all_bodies", authority_one)
		check("host_configured_profiles_initialized", initialized)
		if not host: check("guest_parked_not_ready", world.area == null and world.farm == null and not world.ready_for_play)
		if str(options.phase) in ["save", "authority", "lifetime"]: _save_checks(world, host)
		if str(options.phase) in ["authority", "lifetime"]: _authority_checks(world, host)
		if str(options.phase) == "lifetime": await _lifetime_before(world, session, host)
		details["view"] = []
		for body in world.all_players():
			details.view.append({"id": str(body.player_id), "peer": body.peer_id, "local": body.is_local, "camera": body.camera != null and body.camera.enabled, "registered": registry.registered_id(body) == body.player_id})
		details["self_peer"] = session.api.get_unique_id() if session.peer != null else 0
		details["generation"] = session.generation
		details["packets_received"] = session.packets_received
	marker(str(options.role) + "-done")
	deadline = Time.get_ticks_msec() + 10000
	while not everyone_done() and Time.get_ticks_msec() < deadline: await process_frame
	check("all_counterparts_done", everyone_done())
	if str(options.phase) == "navigation":
		await _navigation(world, session, host)
	elif str(options.phase) == "lifetime":
		if host:
			deadline = Time.get_ticks_msec() + 5000
			while world.all_players().size() != 1 and Time.get_ticks_msec() < deadline: await process_frame
			check("disconnect_cleans_bodies", world.all_players().size() == 1 and world.player_by_peer.size() == 1)
			check("disconnect_retains_profiles", registry._states.size() == int(options.count))
			check("host_save_after_disconnect", saves.save_game(1))
		else:
			var teardown := {"consistent": true}
			root.get_node("EventBus").player_despawned.connect(func(_id):
				if is_instance_valid(world):
					for remaining in world.all_players():
						if registry.peek_state(remaining.player_id) == null: teardown.consistent = false)
			session.close(&"test_leave")
			check("guest_teardown_tables_consistent", teardown.consistent)
			check("guest_close_cleans_bodies", world.all_players().is_empty() and world.player_by_peer.is_empty())
			check("guest_close_restores_offline_rows", registry._states == offline_rows)
			check("guest_ended_save_refused", not saves.save_game(0))
			root.remove_child(world)
			check("guest_detached_save_refused", not saves.save_game(0))
			check("guest_rehost_refused", session.host(int(options.port), 4, "127.0.0.1") != OK)
		session.close()
		var closed_generation: int = session.generation
		session.close()
		check("close_idempotent", session.generation == closed_generation and session.pending.is_empty() and session.active.is_empty() and session.peer == null)
		if host:
			check("host_rebind_same_port", session.host(int(options.port), 4, "127.0.0.1") == OK)
			session.close()
			var saved_rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(1))).players.rows
			var loaded: bool = saves.load_game(1)
			var roundtrip: bool = loaded and registry._states.size() == saved_rows.size()
			details["roundtrip_load_error"] = saves.last_error.duplicate(true)
			details["roundtrip_loaded"] = loaded
			details["roundtrip_actual_rows"] = {}
			for id in saved_rows:
				var row: RefCounted = registry.peek_state(StringName(id))
				details.roundtrip_actual_rows[id] = JSON.parse_string(JSON.stringify(row.to_dict(), "", true, true)) if row != null else null
				roundtrip = roundtrip and row != null and details.roundtrip_actual_rows[id] == saved_rows[id]
			check("host_disk_load_roundtrip_all_rows", roundtrip)
			details["post_disconnect_saved_rows"] = saved_rows
	elif str(options.case) == "area_lifetime":
		if host:
			deadline = Time.get_ticks_msec() + 5000
			while world.all_players().size() != 1 and Time.get_ticks_msec() < deadline: await process_frame
			check("area_departure_consistent", world.all_players().size() == 1 and world.player_by_peer.size() == 1 and session.active.is_empty() and registry._states.size() == 3)
			check("area_retained_profiles_save", saves.save_game(1) and JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(1))).players.rows.size() == 3)
		session.close()
	else: session.close()
	if is_instance_valid(world): world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("prepare_shutdown"): await audio.prepare_shutdown()
	_finish()

func _area_lifetime_before(world: Node, session: Node, deadline: int) -> void:
	while session.active.size() != 1 and Time.get_ticks_msec() < deadline: await process_frame
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	var body: Node = world.player_by_id(&"p1")
	check("area_initial_admission", body != null and session.active.size() == 1)
	if body == null:
		marker("area-travel-done")
		return
	var row: RefCounted = registry.peek_state(&"p1")
	var peer_id: int = body.peer_id
	var at: Vector2 = body.global_position
	var saved_area: StringName = row.area
	var transitions := true
	var live := true
	var projection := true
	for destination in [&"home", &"farm", &"home", &"home"]:
		transitions = world._enter(destination, &"default") and transitions
		await process_frame
		live = live and is_instance_valid(body) and body.is_inside_tree() and world.player_by_id(&"p1") == body and world.player_by_peer_id(peer_id) == body and registry.registered_id(body) == &"p1" and registry.peek_state(&"p1") == row and session.active.get(peer_id) == &"p1"
		world.roster.capture_live_bodies(world)
		projection = projection and row.area == saved_area and row.player_pos == at and JSON.parse_string(session._descriptor().get_string_from_utf8()).size() == 2
	check("area_cached_rebuilt_transition_positive", transitions and world.is_parked(&"farm") and not world.is_parkable(world.area))
	check("area_body_membership_preserved", live)
	check("area_passive_profile_descriptor_preserved", projection)
	marker("area-travel-done")

func _save_checks(world: Node, host: bool) -> void:
	var saves := root.get_node("SaveManager")
	if host:
		var expected := {}
		for body in world.all_players():
			# Exercise every host profile through its actual quest facade before
			# exact disk roundtrip comparison: a never-read {} quest log is
			# intentionally expanded by the existing load codec. Keep that
			# representation precondition explicit, not a lossy comparator.
			var registry: Script = load("res://scripts/world2d/player_registry.gd")
			registry.for_player(body.player_id, root.get_node("QuestManager").to_dict)
			body.global_position += Vector2(11 + body.player_slot, 9)
			body.half_hearts = 3 + body.player_slot
			body.stamina = 31.0 + body.player_slot
			body.oil = 41.0 + body.player_slot
			expected[str(body.player_id)] = {"position": [body.global_position.x, body.global_position.y], "hearts": body.half_hearts}
		check("host_save_positive", saves.save_game(0))
		var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(0)))
		var matched: bool = payload is Dictionary and payload.get("players", {}).get("rows", {}).size() == int(options.count)
		for id in expected:
			var row: Dictionary = payload.get("players", {}).get("rows", {}).get(id, {})
			matched = matched and row.get("player_pos") == expected[id].position and row.get("half_hearts") == expected[id].hearts
		check("host_saved_all_live_rows", matched)
		details["saved_payload"] = payload
		details["host_file_hashes"] = save_hashes(saves.save_dir)
	else:
		var before := save_hashes(saves.save_dir)
		check("guest_save_refused", not saves.save_game(0))
		check("guest_autosave_refused", not saves.autosave())
		check("guest_gather_refused", saves.gather_payload().is_empty())
		check("guest_world_files_unchanged", save_hashes(saves.save_dir) == before)
		details["guest_file_hashes_before"] = before
		details["guest_file_hashes_after"] = save_hashes(saves.save_dir)

func _authority_checks(world: Node, host: bool) -> void:
	var game := root.get_node("GameManager")
	var time := root.get_node("TimeManager")
	game.change_phase(game.GamePhase.PLAYING)
	time.is_paused = false
	var clock_before := [game.day, game.hour, game.minute]
	game.advance_time(10)
	check("host_clock_positive" if host else "guest_clock_refused", ([game.day, game.hour, game.minute] != clock_before) == host)
	var before: Dictionary = time.to_dict()
	time.set_weather(&"regn")
	check("host_weather_positive" if host else "guest_weather_refused", (time.to_dict() != before) == host)
	var farm: Node = world.farm if host else load("res://scripts/world2d/farm_grid.gd").new()
	if not host: world.add_child(farm)
	var cells: Array = farm.farmable_cells()
	check("eligible_farm_fixture", cells.size() >= 4)
	if cells.size() < 4: return
	var cell: Vector2i = cells[0]
	check("eligible_empty_till", farm.can_till(cell) and farm.state_of(cell) == 0)
	check("host_till_positive" if host else "guest_till_refused", bool(farm.till(cell)) == host)
	# Otherwise eligible planted/water fixtures, with real configured seed inventory.
	var farm_script: Script = load("res://scripts/world2d/farm_grid.gd")
	var soil: RefCounted = farm_script.PlotData.new()
	farm.plots[cells[1]] = soil
	var eco := root.get_node("EconomyManager")
	check("eligible_seed_inventory", eco.count_item(&"turnip_seeds") > 0)
	check("host_plant_positive" if host else "guest_plant_refused", (farm.plant(cells[1], &"turnip_seeds") == "") == host)
	var dry: RefCounted = farm_script.PlotData.new()
	farm.plots[cells[2]] = dry
	check("host_water_positive" if host else "guest_water_refused", bool(farm.water(cells[2])) == host)
	if not host:
		var snapshot: Dictionary = farm.to_dict()
		check("guest_farm_load_refused", not farm.from_dict({"plots": {}}))
		farm._on_day_started(game.day + 1, game.season)
		farm._on_time_changed(12, 0)
		farm._on_weather_changed(&"regn")
		check("guest_autonomous_farm_unchanged", farm.to_dict() == snapshot)
		var exact := [game.day, game.hour, game.minute, time.to_dict()]
		time.tick(120.0)
		game.set_clock(20, 0)
		game.end_day()
		game.sleep_until_morning()
		time.pause_time()
		check("guest_pause_time_refused", not time.is_paused)
		time.is_paused = true
		time.resume_time()
		check("guest_resume_time_refused", time.is_paused)
		time.is_paused = false
		time.set_time_scale(4.0)
		time.roll_weather(0.0)
		time.from_dict({"weather": "regn", "time_scale": 9})
		check("guest_all_clock_paths_refused", [game.day, game.hour, game.minute, time.to_dict()] == exact)

func _lifetime_before(_world: Node, session: Node, host: bool) -> void:
	var game := root.get_node("GameManager")
	var saves := root.get_node("SaveManager")
	check("network_is_not_single_player", not game.is_single_player)
	await _reward_checks(_world, host)
	if not host:
		check("queued_offline_autosave_cancelled", save_hashes(saves.save_dir) == offline_files)
		saves._on_day_ended(1, &"foraar")
		check("guest_autosave_producer_refused", not saves._autosave_queued)
		var before := save_hashes(saves.save_dir)
		check("guest_load_refused", not saves.load_game(0))
		check("guest_load_and_enter_refused", not saves.load_and_enter(0))
		check("guest_continue_refused", not saves.continue_latest())
		var timer_before: float = saves._auto_save_timer
		saves._process(100000.0)
		check("guest_timer_refused", saves._auto_save_timer == timer_before)
		check("guest_apply_refused", not bool(saves._apply_payload(offline_payload).get("ok", true)))
		saves.delete_save(0)
		check("guest_delete_refused", save_hashes(saves.save_dir) == before)
		var played: float = game.play_time_seconds
		for frame in 3: await process_frame
		check("guest_playtime_stopped", game.play_time_seconds == played)
		var pause_before: bool = paused
		game.push_modal(&"net_test_pause", true)
		check("guest_modal_nonpausing", paused == pause_before)
		game.pop_modal(&"net_test_pause")
		var quit_result := {"done": false, "ok": false}
		_probe_quit.call_deferred(game, quit_result)
		var quit_deadline := Time.get_ticks_msec() + 5000
		while not quit_result.done and Time.get_ticks_msec() < quit_deadline: await process_frame
		check("guest_save_before_quit_no_prompt", quit_result.done and quit_result.ok and not game._quit_asking)
		var question := root.get_node_or_null("QuitQuestion")
		if question != null:
			for child in question.get_children():
				if child.has_method("_finish"): child._finish(false)
	var old_name: String = game.player_name
	game.start_new_game("Forbidden replacement", 3)
	check("network_new_game_refused", game.player_name == old_name and session.state == (&"hosting" if host else &"connected"))

func _reward_checks(world: Node, host: bool) -> void:
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	var eco := root.get_node("EconomyManager")
	var quests := root.get_node("QuestManager")
	var target: Node = world.player_by_id(&"p1") if host else world.local_player()
	var row: RefCounted = registry.peek_state(target.player_id)
	row.owed = [{"id": &"wood", "amount": 1, "meta": {}}]
	var original_inventory: Array = row.inventory.duplicate(true)
	var host_inventory: Array = registry.peek_state(&"p0").inventory.duplicate(true)
	root.get_node("EventBus").player_spawned.emit(target)
	check("host_spawn_owed_targeted" if host else "guest_spawn_owed_suppressed", (row.inventory != original_inventory and row.owed.is_empty()) if host else (row.inventory == original_inventory and row.owed.size() == 1))
	if host:
		check("spawn_never_borrows_host_inventory", registry.peek_state(&"p0").inventory == host_inventory)
		var primary: RefCounted = registry.peek_state(&"p0")
		primary.quests["pending_rewards"] = {"other_owner": {"wood": 7}}
		row.quests["pending_rewards"] = {"signal_owner": {"wood": 2}}
		var before_target: Array = row.inventory.duplicate(true)
		var before_primary: Array = primary.inventory.duplicate(true)
		var owned_inventory: Dictionary = registry.for_player(target.player_id, eco.get_inventory_dict)
		root.get_node("EventBus").player_inventory_changed.emit(target.player_id, owned_inventory)
		for frame in 3: await process_frame
		check("host_deferred_reward_keeps_signal_owner", row.inventory != before_target)
		check("host_deferred_reward_does_not_borrow_host", primary.inventory == before_primary)
	var local: Node = world.local_player()
	var local_row: RefCounted = registry.peek_state(local.player_id)
	local_row.quests["pending_rewards"] = {"net_fixture": {"wood": 1}}
	var before: Array = local_row.inventory.duplicate(true)
	registry.for_player(local.player_id, func(): quests._queue_reward_claim())
	for frame in 3: await process_frame
	check("host_deferred_reward_positive" if host else "guest_deferred_reward_suppressed", (local_row.inventory != before) == host)

func _navigation(world: Node, session: Node, host: bool) -> void:
	var game := root.get_node("GameManager")
	var saves := root.get_node("SaveManager")
	if str(options.case) == "host_loss":
		var before_loss := save_hashes(saves.save_dir)
		if host:
			session.close(&"host_loss_test")
			check("host_loss_closed", session.state == &"ended")
		else:
			var loss_deadline := Time.get_ticks_msec() + 5000
			while is_instance_valid(world) and Time.get_ticks_msec() < loss_deadline: await process_frame
			check("guest_host_loss_returns_title", not is_instance_valid(world) and game.current_phase == game.GamePhase.MENU)
			check("guest_leave_no_disk_change", save_hashes(saves.save_dir) == before_loss)
		return
	if host:
		var deadline := Time.get_ticks_msec() + 10000
		while world.all_players().size() != 1 and Time.get_ticks_msec() < deadline: await process_frame
		check("navigation_peer_removed", world.all_players().size() == 1)
		session.close()
		return
	var before := save_hashes(saves.save_dir)
	var menu: Node = load("res://scenes/ui/pause_menu.tscn").instantiate()
	world.add_child(menu)
	var result := {"done": false}
	_probe_leave.call_deferred(menu, result)
	var deadline := Time.get_ticks_msec() + 5000
	while not result.done and not game.is_modal_open(&"confirm") and Time.get_ticks_msec() < deadline: await process_frame
	check("guest_return_title_no_prompt", result.done and not game.is_modal_open(&"confirm"))
	if is_instance_valid(menu) and game.is_modal_open(&"confirm"):
		for child in menu.find_children("*", "Control", true, false):
			if child.get_script() != null and child.get_script().resource_path == "res://scripts/ui/components/ui_confirm.gd": child._finish(false)
	for frame in 3: await process_frame
	check("guest_leave_disposed_world", not is_instance_valid(world) and game.current_phase == game.GamePhase.MENU)
	check("guest_leave_no_disk_change", save_hashes(saves.save_dir) == before)
	if is_instance_valid(session): session.close()

func _capacity_run() -> void:
	check("isolated_user_data", OS.get_user_data_dir().begins_with(OS.get_environment("HOME") + "/"))
	var host := str(options.role) == "host"
	var outsider := str(options.role) == "guest4"
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	var saves := root.get_node("SaveManager")
	var game := root.get_node("GameManager")
	var world: Node = load("res://scripts/world2d/world_2d.gd").new()
	world.name = "World"
	world.guest_bootstrap = not host
	if host:
		game.start_new_game("Host", 0)
		game.set_flag(&"intro_pending", false)
	else: saves.pending_world = {"capacity_offline": 19}
	var old_rows: Dictionary = registry._states.duplicate()
	var old_pending: Dictionary = saves.pending_world.duplicate(true)
	var files := save_hashes(saves.save_dir)
	root.add_child(world)
	var deadline := Time.get_ticks_msec() + 15000
	while host and not world.ready_for_play and Time.get_ticks_msec() < deadline: await process_frame
	var session: Node = world.session
	if outsider:
		while not FileAccess.file_exists(str(options.directory).path_join("capacity-full")) and Time.get_ticks_msec() < deadline: await process_frame
		check("full_before_fifth", FileAccess.file_exists(str(options.directory).path_join("capacity-full")))
	check("transport_started", (session.host(int(options.port), 4, "127.0.0.1") if host else session.join("127.0.0.1", int(options.port))) == OK)
	if host: marker("hosting")
	deadline = Time.get_ticks_msec() + 15000
	if outsider:
		while session.state != &"ended" and Time.get_ticks_msec() < deadline: await process_frame
		check("fifth_refused", session.state == &"ended" and world.all_players().is_empty())
		check("offline_state_exact", registry._states == old_rows and saves.pending_world == old_pending)
		check("guest_world_files_unchanged", save_hashes(saves.save_dir) == files and not saves.save_game(0))
		marker("fifth-refused")
	else:
		while world.all_players().size() != 4 and Time.get_ticks_msec() < deadline: await process_frame
		check("four_admitted", world.all_players().size() == 4 and registry._states.size() == 4)
		if host: marker("capacity-full")
		while not FileAccess.file_exists(str(options.directory).path_join("fifth-refused")) and Time.get_ticks_msec() < deadline: await process_frame
		check("fifth_cannot_disturb_roster", FileAccess.file_exists(str(options.directory).path_join("fifth-refused")) and world.all_players().size() == 4 and registry._states.size() == 4 and session.state == (&"hosting" if host else &"connected"))
		if not host: check("guest_world_files_unchanged", save_hashes(saves.save_dir) == files)
	marker(str(options.role) + "-admitted") # Finished positive/negative capacity barrier, not admission of guest4.
	marker(str(options.role) + "-done")
	deadline = Time.get_ticks_msec() + 10000
	while not everyone_done() and Time.get_ticks_msec() < deadline: await process_frame
	check("all_counterparts_done", everyone_done())
	details["self_peer"] = session.api.get_unique_id() if session.peer != null else 0
	details["packets_received"] = session.packets_received
	session.close()
	check("close_pending_empty", session.pending.is_empty() and session.active.is_empty() and session.peer == null)
	world.queue_free()
	await process_frame
	await root.get_node("AudioManager").prepare_shutdown()
	_finish()

func _probe_leave(menu: Node, result: Dictionary) -> void:
	await menu._leave(false)
	result.done = true

func _probe_quit(game: Node, result: Dictionary) -> void:
	result.ok = await game.save_before_quit()
	result.done = true

func everyone_done() -> bool:
	if not FileAccess.file_exists(str(options.directory).path_join("host-done")): return false
	for i in range(1, int(options.count)):
		if not FileAccess.file_exists(str(options.directory).path_join("guest%d-done" % i)): return false
	return true

func save_hashes(directory: String) -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at(directory):
		out[file] = FileAccess.get_sha256(directory.path_join(file))
	return out

func marker(id: String) -> void:
	var file := FileAccess.open(str(options.directory).path_join(id), FileAccess.WRITE)
	file.store_string("ready")
	file.close()

func _finish() -> void:
	var ok := not checks.is_empty()
	for row in checks: ok = ok and row.ok
	var file := FileAccess.open(str(options.report), FileAccess.WRITE)
	file.store_string(JSON.stringify({"role": options.get("role", "host"), "checks": checks, "details": details, "source_pin": OS.get_environment("NET_SOURCE_PIN"), "count": int(options.count), "phase": str(options.phase), "case": str(options.case), "home": OS.get_environment("HOME"), "platform": OS.get_name(), "display": DisplayServer.get_name(), "user_data": OS.get_user_data_dir(), "engine": Engine.get_version_info().string, "ok": ok}, "", true, true))
	file.close()
	quit(0 if ok else 1)
