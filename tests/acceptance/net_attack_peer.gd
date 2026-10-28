extends "res://tests/acceptance/net_peer.gd"
## Adversarial packets originate in this separate real Godot client. Production
## RPC methods, sender IDs, reservation and timeout paths remain unchanged.
const CASE_REASON := {"malformed_json": "envelope", "forged_roster": "compatibility","build": "compatibility", "content": "compatibility", "envelope": "envelope", "profile_type": "profile", "missing_field": "profile", "claimed_peer": "profile", "claimed_id": "profile", "retired_skin": "profile", "long_name": "profile", "empty_name": "profile", "string_type": "profile", "protocol": "compatibility", "oversize": "size", "smuggle": "profile", "bool_type": "profile", "fraction": "profile", "control_name": "profile", "skin_path": "profile", "skin_mismatch": "profile", "duplicate": "duplicate_hello", "premature_ack": "ack", "stale_ack": "ack", "timeout": "timeout", "profiles_full": "profiles_full", "quota": "quota", "quota_replace": "quota", "guest_free_spawn": "", "free_spawn": "", "close_spawn": "", "close_join": "", "pending_disconnect": "", "prepared_disconnect": "", "commit_not_received": ""}

func _run() -> void:
	check("isolated_user_data", OS.get_user_data_dir().begins_with(OS.get_environment("HOME") + "/"))
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	var game := root.get_node("GameManager")
	var saves := root.get_node("SaveManager")
	var host := str(options.role) == "host"
	var world: Node = load("res://scripts/world2d/world_2d.gd").new()
	world.name = "World"
	world.guest_bootstrap = not host
	if host:
		game.start_new_game("Host", 0)
		game.set_flag(&"intro_pending", false)
	else:
		saves.pending_world = {"preserved_offline_marker": 17}
	var original_rows: Dictionary = registry._states.duplicate()
	var original_pending: Dictionary = saves.pending_world.duplicate(true)
	var original_files := save_hashes(saves.save_dir)
	root.add_child(world)
	var boot_deadline := Time.get_ticks_msec() + 15000
	while host and not world.ready_for_play and Time.get_ticks_msec() < boot_deadline: await process_frame
	var session: Node = world.session
	var replacement: Dictionary = {}
	if host and str(options.case) == "quota_replace":
		root.get_node("EventBus").player_left.connect(func(id, _reason):
			if id == &"p1": _replace_quota_transport(session, replacement), CONNECT_ONE_SHOT)
	var actual_peers: Array = []
	var owned_api: MultiplayerAPI
	var events := {"spawn": 0, "join": 0, "left": 0, "despawn": 0}
	if host and str(options.case) in ["free_spawn", "close_spawn", "close_join"]:
		root.get_node("EventBus").player_spawned.connect(func(body):
			if str(body.player_id) == "p1":
				events.spawn += 1
				if str(options.case) == "free_spawn":
					details["packets_received"] = session.packets_received
					world.free()
				elif str(options.case) == "close_spawn": session.close(&"observer_close"))
		root.get_node("EventBus").player_joined.connect(func(id, _peer, _profile):
			if str(id) == "p1":
				events.join += 1
				if str(options.case) == "close_join": session.close(&"observer_close"))
		root.get_node("EventBus").player_left.connect(func(id, _why):
			if str(id) == "p1": events.left += 1)
		root.get_node("EventBus").player_despawned.connect(func(id):
			if str(id) == "p1": events.despawn += 1)
	if not host and str(options.case) == "guest_free_spawn":
		root.get_node("EventBus").player_spawned.connect(func(_body):
			if is_instance_valid(world): world.free())
	var error: int
	if host:
		if str(options.case) == "profiles_full":
			for slot in range(1, 4):
				var row: RefCounted = load("res://scripts/player/player_state.gd").new(StringName("p%d" % slot), slot + 1)
				registry._states[row.player_id] = row
		error = session.host(int(options.port), 4, "127.0.0.1")
		session.api.peer_connected.connect(func(id): actual_peers.append(id))
		marker("hosting")
	else:
		error = session.join("127.0.0.1", int(options.port))
		session.api.connected_to_server.disconnect(session._connected)
		session.api.connected_to_server.connect(func(): _send_attack(session))
	owned_api = session.api
	check("transport_started", error == OK)
	var deadline := Time.get_ticks_msec() + 15000
	if host:
		while actual_peers.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		check("actual_transport_sender_seen", actual_peers.size() == 1 and int(actual_peers[0]) > 1)
		marker("host-connected")
		deadline = Time.get_ticks_msec() + 10000
		if str(options.case) == "free_spawn":
			while is_instance_valid(world) and Time.get_ticks_msec() < deadline: await process_frame
			check("reentrant_free_cleaned", not is_instance_valid(world) and not is_instance_valid(session) and owned_api.multiplayer_peer == null)
		elif str(options.case) in ["pending_disconnect", "prepared_disconnect", "commit_not_received", "guest_free_spawn"]:
			if str(options.case) == "prepared_disconnect":
				while not session.pending.values().any(func(record): return record.has("row")) and Time.get_ticks_msec() < deadline: await process_frame
				check("prepared_reservation_observed", session.pending.values().any(func(record): return record.has("row")))
				marker("host-prepared")
			if str(options.case) == "commit_not_received":
				while session.active.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
				check("host_commit_observed", session.active.size() == 1 and registry._states.size() == 2)
				marker("host-committed")
			deadline = Time.get_ticks_msec() + 5000
			while not session.api.get_peers().is_empty() and Time.get_ticks_msec() < deadline: await process_frame
			check("departure_cleaned", session.api.get_peers().is_empty() and session.pending.is_empty() and session.active.is_empty())
		elif str(options.case) in ["close_spawn", "close_join"]:
			while session.state != &"ended" and Time.get_ticks_msec() < deadline: await process_frame
			check("reentrant_close_once", session.state == &"ended" and events.spawn == 1 and events.join == (0 if str(options.case) == "close_spawn" else 1) and events.left == 1 and events.despawn == 1)
			details["events"] = events
		else:
			while session.last_rejection == &"" and Time.get_ticks_msec() < deadline: await process_frame
			check("named_rule_rejected", str(session.last_rejection) == str(CASE_REASON.get(str(options.case), "unknown")))
		if str(options.case) == "quota_replace":
			check("quota_replacement_bound", bool(replacement.get("bound", false)))
			check("quota_same_sender_connected", bool(replacement.get("connected", false)))
			var sender: int = int(replacement.get("sender", 0))
			check("quota_replacement_survives_old_continuation", sender > 1 and sender in session.api.get_peers() and session.peer.get_peer(sender).get_state() == ENetPacketPeer.STATE_CONNECTED)
		check("no_body_allocation", not is_instance_valid(world) if str(options.case) == "free_spawn" else world.all_players().size() == 1 and world.player_by_peer.size() == 1)
		check("no_profile_allocation", registry._states.size() == (4 if str(options.case) == "profiles_full" else 2 if str(options.case) in ["quota", "quota_replace", "free_spawn", "close_spawn", "close_join", "commit_not_received", "guest_free_spawn"] else 1))
		check("host_still_authoritative", not is_instance_valid(session) if str(options.case) == "free_spawn" else session.state == (&"ended" if str(options.case) in ["close_spawn", "close_join"] else &"hosting") and world.local_player() == world.player)
		details["actual_sender"] = actual_peers[0] if actual_peers.size() == 1 else 0
		if is_instance_valid(session):
			details["rejection"] = str(session.last_rejection)
			details["packets_received"] = session.packets_received
		marker("host-rejected")
	else:
		while is_instance_valid(session) and session.state != &"ended" and Time.get_ticks_msec() < deadline: await process_frame
		check("rejected_guest_ended", not is_instance_valid(session) or session.state == &"ended")
		if str(options.case) == "guest_free_spawn":
			check("guest_admission_then_freed", not is_instance_valid(world) and not is_instance_valid(session))
		else: check("guest_admission_then_revoked" if str(options.case) in ["quota", "quota_replace"] else "guest_never_admitted", world.all_players().is_empty() and world.player_by_peer.is_empty() and (bool(details.get("admitted", false)) if str(options.case) in ["quota", "quota_replace"] else true))
		check("offline_state_exact", registry._states == original_rows and saves.pending_world == original_pending)
		if str(options.case) == "guest_free_spawn": check("disposed_guest_never_saved", save_hashes(saves.save_dir) == original_files)
		else: check("rejected_guest_cannot_save", not saves.save_game(0))
		check("attack_packets_sent", int(details.get("sent", 0)) == (0 if str(options.case) in ["timeout", "pending_disconnect"] else 17 if str(options.case) in ["quota", "quota_replace"] else 2 if str(options.case) in ["duplicate", "stale_ack", "forged_roster"] else 1))
	marker(str(options.role) + "-done")
	deadline = Time.get_ticks_msec() + 10000
	while not everyone_done() and Time.get_ticks_msec() < deadline: await process_frame
	check("all_counterparts_done", everyone_done())
	if replacement.has("connection"): replacement.connection.destroy()
	if is_instance_valid(session): session.close()
	check("close_pending_empty", owned_api.multiplayer_peer == null and (not is_instance_valid(session) or session.pending.is_empty() and session.active.is_empty()))
	if is_instance_valid(world): world.queue_free()
	await process_frame
	await root.get_node("AudioManager").prepare_shutdown()
	_finish()

## One bounded real ENet collision. The installed supported connection API's
## connect data is the ID the production ENet server assigns at EVENT_CONNECT.
## No generated-ID retries, fake peer or production hook is involved.
func _replace_quota_transport(session: Node, observed: Dictionary) -> void:
	var sender: int = int(details.get("actual_sender_for_replacement", 0))
	# Departure already erased active; retained p1 records its actual ENet sender.
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	sender = registry.peek_state(&"p1").peer_id
	var old_api: MultiplayerAPI = session.api
	var old_peer: ENetMultiplayerPeer = session.peer
	var epoch: int = session.generation
	session.close(&"quota_replace")
	observed["bound"] = session.host(int(options.port), 4, "127.0.0.1") == OK and session.generation != epoch and session.api != old_api and session.peer != old_peer
	observed["sender"] = sender
	var connection := ENetConnection.new()
	observed["connection"] = connection
	if not observed.bound or connection.create_host(1, 4) != OK: return
	var client := connection.connect_to_host("127.0.0.1", int(options.port), 4, sender)
	if client == null: return
	var deadline := Time.get_ticks_msec() + 1000
	while sender not in session.api.get_peers() and Time.get_ticks_msec() < deadline:
		connection.service()
		session.api.poll()
		OS.delay_msec(1)
	observed["connected"] = sender in session.api.get_peers() and client.get_state() == ENetPacketPeer.STATE_CONNECTED
	details["quota_collision"] = {"sender": sender, "bound": observed.bound, "connected": observed.connected}

func _send_attack(session: Node) -> void:
	details["self_peer"] = session.api.get_unique_id()
	details["sent"] = 0
	var payload := {"protocol": 1, "build": "mp4-admission-1", "content": "traetoppen-mp4-1", "profile": {"name": "Guest", "character_type": 0, "character_skin": "animal_fox"}}
	var case: String = str(options.case)
	if case == "forged_roster":
		session.rpc_id(1, "_roster_update", 1, "[]".to_utf8_buffer())
		details.sent = 1
	if case == "timeout":
		# A silent adversarial client must remain connected to observe the
		# HOST's unchanged 5s hello deadline, rather than racing its own
		# independent 5s guest timeout. This disables only this test client's
		# session timer, never polling or any production/host deadline.
		session.set_process(false)
		return
	if case == "pending_disconnect":
		_leave_pending.call_deferred(session)
		return
	if case == "premature_ack":
		session.rpc_id(1, "_ready_ack", 1, 9999)
		details.sent = 1
		return
	if case == "prepared_disconnect": session._staged = [{}]
	if case == "stale_ack": session._staged = [{}] # Suppress only this client's automatic ready; host reservation is real.
	match case:
		"build": payload.build = "wrong-build"
		"content": payload.content = "wrong-content"
		"envelope": payload["extra"] = 1
		"profile_type": payload.profile = []
		"missing_field": payload.profile.erase("name")
		"claimed_peer": payload.profile["peer"] = 1
		"claimed_id": payload.profile["id"] = "p0"
		"retired_skin": payload.profile.character_skin = "animal_rabbit"
		"long_name": payload.profile.name = "😀".repeat(33)
		"empty_name": payload.profile.name = "   "
		"string_type": payload.profile.character_type = "0"
		"protocol", "forged_roster": payload.protocol = 99
		"smuggle": payload.profile["gold"] = 99999
		"bool_type": payload.profile.character_type = true
		"fraction": payload.profile.character_type = 0.5
		"control_name": payload.profile.name = "bad\nname"
		"skin_path": payload.profile.character_skin = "../animal_fox"
		"skin_mismatch": payload.profile.character_skin = "fairy_meadow"
	var bytes := JSON.stringify(payload).to_utf8_buffer()
	if case == "malformed_json": bytes = "{\"protocol\":".to_utf8_buffer()
	if case == "oversize": bytes = (" ".repeat(1025) + JSON.stringify(payload)).to_utf8_buffer()
	session.rpc_id(1, "_hello", bytes)
	details.sent += 1
	if case in ["quota", "quota_replace"]: _flood_after_admission.call_deferred(session)
	if case == "prepared_disconnect": _leave_prepared.call_deferred(session)
	if case == "commit_not_received": _cut_commit.call_deferred(session)
	if case == "stale_ack": _stale_after_prepare.call_deferred(session)
	if case == "duplicate":
		session.rpc_id(1, "_hello", bytes)
		details.sent = 2

func _flood_after_admission(session: Node) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while session.state == &"joining" and Time.get_ticks_msec() < deadline: await process_frame
	details["admitted"] = session.state == &"connected"
	if session.state != &"connected": return
	for index in 16:
		session.rpc_id(1, "_ready_ack", session._host_generation, session._guest_ticket)
		details.sent += 1

func _stale_after_prepare(session: Node) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while session.packets_received == 0 and session.state == &"joining" and Time.get_ticks_msec() < deadline: await process_frame
	if session.state != &"joining" or session.packets_received == 0: return
	session.rpc_id(1, "_ready_ack", 0, 9999)
	details.sent += 1

func _leave_pending(session: Node) -> void:
	# A pending-disconnect test must first establish that the HOST observed the
	# real connection; client connected_to_server can otherwise fire before the
	# host publishes peer_connected, making immediate close an inert attempt.
	var deadline := Time.get_ticks_msec() + 5000
	while not FileAccess.file_exists(str(options.directory).path_join("host-connected")) and Time.get_ticks_msec() < deadline: await process_frame
	details["pending_host_observed"] = FileAccess.file_exists(str(options.directory).path_join("host-connected"))
	session.close(&"pending_disconnect")

func _leave_prepared(session: Node) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not FileAccess.file_exists(str(options.directory).path_join("host-prepared")) and Time.get_ticks_msec() < deadline: await process_frame
	session.close(&"prepared_disconnect")

func _cut_commit(session: Node) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while session._guest_ticket == 0 and session.state == &"joining" and Time.get_ticks_msec() < deadline: await process_frame
	if session._guest_ticket == 0: return
	# Deliberate bounded loss injection in this test client only. Production keeps
	# automatic polling; the host must commit without trusting a final client ack.
	multiplayer_poll = false
	session.peer.host.flush()
	details["commit_delivery_cut"] = true
	while not FileAccess.file_exists(str(options.directory).path_join("host-committed")) and Time.get_ticks_msec() < deadline: await process_frame
	session.close(&"commit_delivery_cut")
	multiplayer_poll = true
