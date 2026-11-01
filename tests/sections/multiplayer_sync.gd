extends RefCounted
## Section multiplayer_sync (package MP5-net-sync, movement slice): the
## movement-only simulation step shared by prediction and host authority, the
## closed frame/state schemas on the wire, and the WorldSync lifecycle contract
## (one transform writer per body; offline worlds are never claimed). The real
## ENet movement loop (host + guest over actual UDP) is tests/run_net_loop.py
## --phase movement; this section is its fast single-process leg.
const SECTION := "multiplayer_sync"
const TIMEOUT_S := 90.0

func run(t) -> void:
	_test_frame_schema(t)
	_test_state_schema(t)
	if not await t.start_world():
		return
	await _test_sync_child(t)
	await _test_movement_parity(t)


func _frame(move: Array, sequence: int = 1, run := false) -> Dictionary:
	return {"sequence": sequence, "move": move, "aim": [0.0, 0.0], "actions": {"run": run}}


func _test_frame_schema(t) -> void:
	var input := PlayerInput.new()
	var sample: Dictionary = input.sample_frame(7)
	t.check("frame_sample_valid", PlayerInput.valid_frame(sample), "sample_frame() is wire-valid: %s" % str(sample))
	var rejects := {}
	for value in [null, 3, "frame", [], {}]:
		rejects[str(value)] = not PlayerInput.valid_frame(value)
	for bad in [
		{"sequence": 1, "move": [1, 0], "aim": [0, 0]},
		{"sequence": 1, "move": [1, 0], "aim": [0, 0], "actions": {}, "pos": [0, 0]},
		{"sequence": 1.5, "move": [1, 0], "aim": [0, 0], "actions": {}},
		{"sequence": -1, "move": [1, 0], "aim": [0, 0], "actions": {}},
		{"sequence": 2147483648, "move": [1, 0], "aim": [0, 0], "actions": {}},
		_frame([2.0, 0.0]),
		_frame([NAN, 0.0]),
		_frame([0.0, INF]),
		{"sequence": 1, "move": "move", "aim": [0.0, 0.0], "actions": {}},
		_frame([0.0]),
		{"sequence": 1, "move": [1, 0], "aim": [10000001.0, 0], "actions": {}},
		{"sequence": 1, "move": [1, 0], "aim": [0, 0], "actions": {"run": 1}},
		{"sequence": 1, "move": [1, 0], "aim": [0, 0], "actions": {"smuggled": true}},
		{"sequence": 1, "move": [1, 0], "aim": [0, 0], "actions": "run"},
		{"sequence": 1, "move": [1, 0], "aim": [0, 0], "actions": {"run": true, "attack": true, "dodge": true, "jump": true, "interact": true, "use_tool": true, "light": true, "drink": true, "fly_toggle": true, "fly_descend": true, "zoom_in": true, "smuggled": true}}
	]:
		rejects[str(bad)] = not PlayerInput.valid_frame(bad)
	var all_rejected := true
	for key in rejects:
		all_rejected = all_rejected and rejects[key]
	t.check("frame_schema_strict", all_rejected, "closed/typed/bounded: %d hostile frames refused" % rejects.size())


func _test_state_schema(t) -> void:
	var valid := [[0, 1.5, -2.25, 7], [3, 0, 0, 0]]
	t.check("state_schema_accepts", WorldSync.valid_state(valid), str(valid))
	var rejects := {}
	for bad in [
		null, 3, "state", {},
		[],
		[[0, 0, 0]],
		[[0, 0, 0, 0, 0]],
		[[4, 0, 0, 0]],
		[[0, 0, 0, 8]],
		[[0, 0, 0, 0.5]],
		[[0, NAN, 0, 0]],
		[[0, INF, 0, 0]],
		[[0, 1000001, 0, 0]],
		[[0, "x", 0, 0]],
		[[0, 0, 0, 0], [0, 0, 0, 0]],
		[[0, 0, 0, 0], [1, 0, 0, 0], [2, 0, 0, 0], [3, 0, 0, 0], [1, 0, 0, 0]]
	]:
		rejects[str(bad)] = not WorldSync.valid_state(bad)
	var all_rejected := true
	for key in rejects:
		all_rejected = all_rejected and rejects[key]
	t.check("state_schema_strict", all_rejected, "closed/typed/bounded: %d hostile state payloads refused" % rejects.size())


func _test_sync_child(t) -> void:
	var world: Node = t.world()
	var sync: Node = world.get("sync")
	t.check("sync_child_attached", sync != null and sync.get_parent() == world and sync.name == "WorldSync", "World child alongside MultiplayerSession")
	var player: Node = t.player()
	await t.physics(5)
	t.check("offline_body_not_claimed", player != null and not bool(player.get("net_sync_driven")), "offline movement stays with the body's own physics")
	if sync == null:
		return
	var before: Vector2 = player.global_position
	for payload in [[], [[0, NAN, 0, 0]], "junk", [[0, 0, 0, 0], [0, 0, 0, 0]]]:
		sync.call("_state_frame", payload)
	sync.call("_sync_open", [[0, 99999, 99999, 0]])
	await t.physics(5)
	t.check("hostile_state_no_effect", player.global_position == before and int(sync.get("state_received")) == 0
		and not bool(player.get("net_sync_driven")), "offline sync drops hostile state without moving or claiming bodies")


## host_movement_tick and predict_movement_tick are the same physics: two
## identical bodies stepped with identical frames must land on the same spot.
func _test_movement_parity(t) -> void:
	var world: Node = t.world()
	var anchor: Vector2 = t.player().global_position
	var predicted := PlayerStub2D.new()
	var authoritative := PlayerStub2D.new()
	predicted.name = "SyncPredicted"
	authoritative.name = "SyncAuthoritative"
	world.add_child(predicted)
	world.add_child(authoritative)
	t.on_cleanup(func() -> void:
		if is_instance_valid(predicted): predicted.queue_free()
		if is_instance_valid(authoritative): authoritative.queue_free())
	predicted.global_position = anchor
	authoritative.global_position = anchor
	await t.physics(2)
	for step in 30:
		var frame := _frame([1.0, 0.0], step + 1)
		predicted.predict_movement_tick(1.0 / 60.0, frame)
		authoritative.host_movement_tick(1.0 / 60.0, frame)
	var moved: Vector2 = predicted.global_position - anchor
	t.check("movement_advances", moved.length() >= 40.0 and moved.x > 0.0, "30 walk steps moved %.1f px" % moved.length())
	t.check("movement_parity", predicted.global_position.is_equal_approx(authoritative.global_position),
		"predict %s vs host %s" % [predicted.global_position, authoritative.global_position])
