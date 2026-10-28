extends RefCounted
## Admission-only contracts; actual transport is exercised by run_net_loop.py.
const SECTION := "multiplayer_session"
const TIMEOUT_S := 90.0

class SwitchOnGather extends Node:
	var work: Callable
	func to_dict() -> Dictionary:
		if work.is_valid():
			var once := work
			work = Callable()
			once.call()
		return {"v": 1}
	func from_dict(_data: Dictionary) -> bool: return true
	func reset() -> void: work = Callable()

func run(t) -> void:
	var session_script: Script = load("res://scripts/net/multiplayer_session.gd")
	var game: Node = t.autoload("GameManager")
	t.check("lua_defaults", game.config_value("multiplayer.default_port", null) == 24565 and game.config_value("multiplayer.max_players", null) == 4 and game.config_value("multiplayer.protocol", null) == 1 and game.config_value("multiplayer.content_id", null) == "traetoppen-mp4-1", "actual LuaRuntime config, not fallback text")
	var valid := {"name": "Åse", "character_type": 0, "character_skin": "animal_fox"}
	t.check("metadata_valid", session_script.profile_valid(valid), "live catalogue")
	var json: Variant = JSON.parse_string(JSON.stringify(valid))
	t.check("metadata_json_whole_float", session_script.profile_valid(json), "JSON integer tokens decode as whole floats")
	for value in [null, true, false, "0", 0.5, NAN, INF, -1, 4, {}, []]:
		var bad := valid.duplicate(true)
		bad["character_type"] = value
		t.check("type_refused_%s" % str(value), not session_script.profile_valid(bad), "no coercion")
	for value in [null, true, "", "   ", "bad\nname", "x".repeat(33), "\u0085"]:
		var bad := valid.duplicate(true)
		bad["name"] = value
		t.check("name_refused_%s" % str(value).replace("\n", "newline"), not session_script.profile_valid(bad), "UTF-8/name/control bound")
	for value in [null, true, "", "../animal_fox", "fairy_meadow", "missing_skin", "a".repeat(65)]:
		var bad := valid.duplicate(true)
		bad["character_skin"] = value
		t.check("skin_refused_%s" % str(value), not session_script.profile_valid(bad), "catalogue/type/id bound")
	for field in ["id", "peer", "gold", "inventory", "position", "vitals", "equipment"]:
		var bad := valid.duplicate(true)
		bad[field] = "smuggled"
		t.check("extra_refused_%s" % field, not session_script.profile_valid(bad), "metadata-only exact allowlist")
	if not await t.start_world(): return
	var world: Node = PlayerRegistry.world(t.tree)
	var session: Node = world.session
	var before: Dictionary = PlayerRegistry._states.duplicate()
	for invalid in [true, false, "24564", 0, -1, 65536, 1.5, INF, NAN]:
		t.check("host_port_refused_%s" % str(invalid), session.host(invalid, 4, "127.0.0.1") == ERR_INVALID_PARAMETER, "typed port bounds before bind")
	for invalid in [true, "4", 1, 5, 2.5]:
		t.check("host_capacity_refused_%s" % str(invalid), session.host(24564, invalid, "127.0.0.1") == ERR_INVALID_PARAMETER, "typed capacity bounds before bind")
	for invalid in [true, 123, "bad-bind"]:
		t.check("host_bind_refused_%s" % str(invalid), session.host(24564, 4, invalid) == ERR_INVALID_PARAMETER, "explicit bind address")
	var body_before: Node = world.player
	var pending_before: Dictionary = t.autoload("SaveManager").pending_world.duplicate(true)
	var blocker := ENetMultiplayerPeer.new()
	blocker.set_bind_ip("127.0.0.1")
	var blocked: int = blocker.create_server(0, 1)
	t.check("bind_blocker_positive", blocked == OK, "own ephemeral loopback socket")
	if blocked == OK:
		t.allow("Couldn't create an ENet host.")
		var conflict: int = session.host(blocker.host.get_local_port(), 4, "127.0.0.1")
		t.check("bind_failure_exact_diagnostic", t.allowed_count("Couldn't create an ENet host.") == 1, "exactly one expected socket conflict; no other allowance")
		t.check("bind_failure_preserves_offline", conflict != OK and session.state == &"idle" and session.role == &"offline" and session.peer == null and PlayerRegistry._states == before and world.player == body_before and t.autoload("SaveManager").pending_world == pending_before, "no partial ownership on failed bind")
	blocker.close()
	for invalid_sender in [0, 1, 2147483647]:
		session._reject(invalid_sender, &"forged")
		session._peer_disconnected(invalid_sender)
	t.check("invalid_disconnect_no_authority", PlayerRegistry._states == before and world.player == body_before, "no public client disconnect-target RPC exists")
	t.check("offline_world_cannot_join", session.join("127.0.0.1", 24564) != OK, "guest bootstrap must precede tree insertion")
	t.check("join_refusal_keeps_profiles", PlayerRegistry._states == before, "no creating refusal")
	session.close()
	t.check("offline_close_preserves_body", world.all_players().size() == 1 and world.player_by_id(&"p0") == world.player, "idle session cannot tear down an offline world")
	var default_api: MultiplayerAPI = t.tree.get_multiplayer()
	var foreign := SceneMultiplayer.new()
	t.tree.set_multiplayer(foreign, world.get_path())
	var result: int = session.host(24564, 4, "127.0.0.1")
	t.check("foreign_world_api_refused", result == ERR_ALREADY_IN_USE and t.tree.get_multiplayer(world.get_path()) == foreign, "never clobber someone else's subtree API")
	t.check("default_api_preserved", t.tree.get_multiplayer() == default_api, "default SceneTree API untouched")
	session.close()
	t.tree.set_multiplayer(null, world.get_path())
	var saves: Node = t.autoload("SaveManager")
	var switcher := SwitchOnGather.new()
	t.tree.root.add_child(switcher)
	t.check("serializer_fixture_registered", saves.register_section("net_guard_fixture", switcher, 999), "real SaveManager serializer")
	t.check("offline_save_positive", saves.save_game(0), "positive control before role transition")
	var before_files := _files(saves.save_dir)
	switcher.work = func():
		world.free()
		var guest: Node = load("res://scripts/world2d/world_2d.gd").new()
		guest.guest_bootstrap = true
		guest.name = "World"
		t.tree.root.add_child(guest)
		t.tree.current_scene = guest
	var saved: bool = saves.save_game(0)
	t.check("role_changed_during_gather_refused", not saved and not NetAuthority.can_write(), "guest must be denied at disk delivery, not just at producer entry")
	t.check("role_changed_gather_keeps_all_files", _files(saves.save_dir) == before_files, "primary/backup/auto/tmp/old byte hashes unchanged")
	saves.unregister_section("net_guard_fixture")
	switcher.queue_free()
	var guest: Node = PlayerRegistry.world(t.tree)
	var staged_rows: Dictionary = PlayerRegistry._states.duplicate()
	var staged_pending: Dictionary = saves.pending_world.duplicate(true)
	for invalid in [null, true, 1, "", " 127.0.0.1", "x".repeat(254)]:
		t.check("join_address_refused_%s" % str(invalid), guest.session.join(invalid, 24564) == ERR_INVALID_PARAMETER, "no address coercion")
	for invalid in [true, "24564", 0, 65536, 0.5]:
		t.check("join_port_refused_%s" % str(invalid), guest.session.join("127.0.0.1", invalid) == ERR_INVALID_PARAMETER, "no port coercion")
	var vacant := ENetMultiplayerPeer.new()
	vacant.set_bind_ip("127.0.0.1")
	var vacant_error: int = vacant.create_server(0, 1)
	t.check("vacant_port_fixture", vacant_error == OK, "bounded unreachable loopback destination")
	if vacant_error == OK:
		var vacant_port: int = vacant.host.get_local_port()
		vacant.close()
		t.check("unreachable_join_started", guest.session.join("127.0.0.1", vacant_port) == OK, "actual ENet connection attempt")
		var deadline := Time.get_ticks_msec() + 6000
		while guest.session.state != &"ended" and Time.get_ticks_msec() < deadline: await t.tree.process_frame
		t.check("unreachable_join_preserves_offline", guest.session.state == &"ended" and guest.all_players().is_empty() and PlayerRegistry._states == staged_rows and saves.pending_world == staged_pending, "original 5s production deadline; no retry")
		t.check("unreachable_guest_sticky_refusal", not saves.save_game(0) and _files(saves.save_dir) == before_files, "transport loss is not offline writer authority")
	await t.go_menu()
	var bootstrap: Node = load("res://scripts/world2d/world_2d.gd").new()
	bootstrap.name = "World"
	bootstrap.guest_bootstrap = true
	t.tree.root.add_child(bootstrap)
	t.tree.current_scene = bootstrap
	var bootstrap_rows: Dictionary = PlayerRegistry._states.duplicate()
	var bootstrap_pending: Dictionary = saves.pending_world.duplicate(true)
	t.check("bootstrap_join_started", bootstrap.session.join("127.0.0.1", 24564) == OK, "actual production transport before detach")
	var detached_session: Node = bootstrap.session
	var detached_api: MultiplayerAPI = detached_session.api
	t.tree.root.remove_child(bootstrap)
	var ended_epoch: int = detached_session.generation
	detached_session._process(100000.0)
	detached_session.close(&"repeated_detach")
	t.check("detached_bootstrap_revokes_transport", detached_session.state == &"ended" and detached_session.generation == ended_epoch and detached_session.peer == null and detached_api.multiplayer_peer == null and bootstrap.all_players().is_empty(), "no admission or stale timer after tree exit")
	t.check("detached_bootstrap_preserves_offline", PlayerRegistry._states == bootstrap_rows and saves.pending_world == bootstrap_pending and not saves.save_game(0), "retained detached guest cannot become writer")
	bootstrap.free()
	t.check("disposed_bootstrap_releases_original_offline", NetAuthority.can_write() and PlayerRegistry._states == bootstrap_rows, "restored original offline rows, no guest projection persisted")
	await t.go_menu()

func _files(directory: String) -> Dictionary:
	var out := {}
	for name in DirAccess.get_files_at(directory): out[name] = FileAccess.get_sha256(directory.path_join(name))
	return out
