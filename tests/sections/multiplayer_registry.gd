extends RefCounted
## Section multiplayer_registry (package MP1-player-registry): player identity fields, WorldRoot2D
## player slots and lookup helpers, and the lint that keeps get_first_node_in_group("player") out of
## scripts/ (group `player` stays for physics / area queries only).
##
## Named checks: multiplayer_registry.body_defaults, .alias_is_players0, .helpers, .no_first_player_group,
## .spawn_despawn, .multi_body_slots, .is_local_camera.
const SECTION := "multiplayer_registry"
const TIMEOUT_S := 90.0

const LOOKUP_RE := r'get_first_node_in_group\(\s*(?:"player"|&"player")\s*\)'


func run(t) -> void:
	var bus: Node = t.autoload("EventBus")
	if bus == null:
		return
	await t.ensure_world()
	var w: Node = t.world()
	if w == null:
		t.check("world_up", false, "world scene did not come up")
		return

	_test_body_defaults(t, w)
	_test_alias(t, w)
	_test_helpers(t, w)
	_test_lint(t)
	_test_spawn_despawn(t, w, bus)
	await _test_multi_body(t, w)
	_test_is_local_camera(t, w)


func _test_body_defaults(t, w: Node) -> void:
	var p: Node = t.player()
	t.check("body_defaults", p != null
		and StringName(str(p.get("player_id"))) == &"p0"
		and int(p.get("peer_id")) == 1
		and bool(p.get("is_local")) == true
		and int(p.get("player_slot")) == 0,
		"player_id=%s peer_id=%s is_local=%s slot=%s" % [p.get("player_id") if p else null, p.get("peer_id") if p else null, p.get("is_local") if p else null, p.get("player_slot") if p else null])


func _test_alias(t, w: Node) -> void:
	var players: Variant = w.get("players")
	var alias: Variant = w.get("player")
	t.check("alias_is_players0", players is Array and (players as Array).size() >= 1
		and alias == (players as Array)[0] and alias == t.player(),
		"player alias == players[0] == registry local")


func _test_helpers(t, w: Node) -> void:
	var p: Node = t.player()
	var by_id: Node = w.player_by_id(&"p0")
	var by_peer: Node = w.player_by_peer_id(1)
	var local: Node = w.local_player()
	var all: Array = w.all_players()
	var reg_local: Node = PlayerRegistry.local_player(t.tree)
	var reg_by_id: Node = PlayerRegistry.by_id(&"p0", t.tree)
	t.check("helpers", by_id == p and by_peer == p and local == p and reg_local == p and reg_by_id == p
		and all.size() >= 1 and all[0] == p
		and w.player_by_id(&"nope") == null
		and w.player_by_peer_id(99) == null
		and PlayerRegistry.for_event(null, t.tree) == p,
		"player_by_id/peer/local/all + PlayerRegistry")


func _test_lint(t) -> void:
	var rx := RegEx.new()
	var err := rx.compile(LOOKUP_RE)
	t.check("lint_regex_compiles", err == OK, "error %s" % err)
	if err != OK:
		return
	var hits: Array[String] = []
	var files := _gd_files("res://scripts")
	for path in files:
		if path == "res://scripts/world2d/player_registry.gd":
			continue
		var text := FileAccess.get_file_as_string(path)
		if text == "":
			continue
		for m in rx.search_all(text):
			var line := text.substr(0, m.get_start()).count("\n") + 1
			hits.append("%s:%d" % [path, line])
	t.check("no_first_player_group", hits.is_empty(),
		"%d scripts scanned, %d leftover lookup(s) %s" % [files.size(), hits.size(), hits.slice(0, 5)])


func _test_spawn_despawn(t, w: Node, bus: Node) -> void:
	var spawned: Array = []
	var despawned: Array = []
	var on_s := func(p) -> void: spawned.append(p)
	var on_d := func(id) -> void: despawned.append(id)
	bus.player_spawned.connect(on_s)
	bus.player_despawned.connect(on_d)
	var extra: Node2D = PlayerStub2D.new()
	extra.name = "ProbePlayer"
	w._register_player(extra, 1, 2)
	w.add_child(extra)
	EventBus.player_spawned.emit(extra)
	t.check("register_second", w.player_by_id(&"p1") == extra and w.player_by_peer_id(2) == extra
		and bool(extra.get("is_local")) == false and int(extra.get("peer_id")) == 2,
		"slot 1 / peer 2 registered")
	var pid: StringName = w._unregister_player(extra)
	t.check("spawn_despawn", pid == &"p1" and despawned == [&"p1"]
		and w.player_by_id(&"p1") == null and w.player_by_peer_id(2) == null,
		"player_despawned(%s) despawned=%s" % [pid, despawned])
	bus.player_spawned.disconnect(on_s)
	bus.player_despawned.disconnect(on_d)
	# single-player slot 0 still intact
	t.check("slot0_intact", w.player_by_id(&"p0") == t.player(), "p0 survives a despawn of p1")


func _test_multi_body(t, w: Node) -> void:
	# slots 1..3 join around the real hero (slot 0 stays the local p0)
	var made: Array = []
	for i in range(1, 4):
		var b: Node2D = PlayerStub2D.new()
		b.name = "Slot%d" % i
		w._register_player(b, i, i + 1)
		w.add_child(b)
		made.append(b)
	t.check("multi_body_slots", w.all_players().size() == 4
		and w.player_by_id(&"p0") == t.player()
		and w.player_by_id(&"p2") == made[1]
		and w.player_by_peer_id(4) == made[2]
		and bool(t.player().get("is_local")) == true
		and bool(made[2].get("is_local")) == false
		and StringName(str(made[2].get("player_id"))) == &"p3",
		"hero + 3 guests registered")
	for b in made:
		w._unregister_player(b)
	t.check("slots_cleared", w.all_players().size() == 1 and w.player_by_id(&"p0") == t.player(),
		"only the real hero remains")


func _test_is_local_camera(t, w: Node) -> void:
	var p: Node = t.player()
	var cam: Variant = p.get("camera") if p != null else null
	t.check("is_local_camera", cam is Camera2D and (cam as Camera2D).is_current(),
		"the local body's camera is current")
	# a remote body must not steal the camera
	var remote: Node2D = PlayerStub2D.new()
	remote.name = "RemoteCam"
	w._register_player(remote, 1, 2)
	w.add_child(remote)
	var rcam: Variant = remote.get("camera")
	t.check("remote_camera_not_current", rcam == null or not (rcam as Camera2D).is_current(),
		"a non-local body does not make_current")
	w._unregister_player(remote)


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var stack: Array[String] = [dir]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var dd := DirAccess.open(d)
		if dd == null:
			continue
		dd.list_dir_begin()
		var name := dd.get_next()
		while name != "":
			if name.begins_with("."):
				name = dd.get_next()
				continue
			var path := d.path_join(name)
			if dd.current_is_dir():
				stack.append(path)
			elif name.ends_with(".gd"):
				out.append(path)
			name = dd.get_next()
		dd.list_dir_end()
	return out
