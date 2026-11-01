class_name WorldSync
extends Node
## World child (alongside MultiplayerSession): same-farm authoritative movement
## replication over the session's real ENet (MP5 slice 1).
##
## Wire (all RPCs run on the world's scoped SceneMultiplayer):
##   _input_frame  guest -> host, unreliable channel 1: one closed input/position
##                 frame per guest physics tick.
##   _state_frame  host -> guests, unreliable channel 1: authoritative body state.
##   _sync_open    host -> guest, reliable channel 0: movement bootstrap.
## Server authority (peer 1) owns every body's movement, including the guest's
## own body (prediction only). The host validates each frame's sender against
## its registered roster, advances the authoritative movement with the same
## movement-only tick the guest predicts with, and broadcasts state; guests
## apply/interpolate remote bodies only, never their own predicted body.
## Schemas are closed and strictly typed (whole bounded integers, finite bounded
## pairs); anything else is dropped, never coerced.
const STATE_MAX := 4
const POS_BOUND := 1000000.0
## A claimed input position further than this from the authoritative body is a
## teleport/cheat probe: the frame is dropped, the body stays authoritative.
const RECONCILE_BOUND := 512.0
## Small course correction toward the stepped frame's claimed position (below
## the gross-desync refusal): bounded disagreement is ordinary drift the host
## simulation accumulates where the guest's prediction cannot (host-only
## geometry and timing), so the authoritative body converges back. Range and
## per-tick rate are capped and the nudge is collision-checked, so host
## collision stays authoritative: a blocked body is never dragged through what
## stops it. Above this distance no correction is offered at all.
const COURSE_BOUND := 64.0
const COURSE_RATE := 0.2
const COURSE_STEP_MAX := 6.0
## Per-sender input queue bound and per-tick advance budget: bounds hostile
## bursts without stalling honest drift (drops cost one movement step each).
const QUEUE_MAX := 8
const STEP_BUDGET := 4
## Remote-body blend per physics tick on a guest (settles within ~5 ticks).
const INTERP := 0.6

var frames_sent := 0
var frames_received := 0
var state_sent := 0
var state_received := 0
var last_reject: StringName = &""

var _active := false
var _seq_out := 0
var _last_seq := {}
var _queues := {}
var _targets := {}

func _world() -> WorldRoot2D:
	return get_parent() as WorldRoot2D

static func _step() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)

## Guest: admission committed; local prediction and input frames begin.
func start_sync() -> void:
	_active = true

## Host: a guest's body was admitted. Open movement sync with a reliable
## bootstrap snapshot (channel 0) and reset its per-sender state.
func peer_committed(sender: int, body: Node2D) -> void:
	_active = true
	_last_seq.erase(sender)
	_queues.erase(sender)
	var world := _world()
	if world == null or not is_instance_valid(body):
		return
	var typed := body as PlayerBody2D
	if typed != null:
		typed.net_sync_driven = true
	var session: Variant = world.session
	if session != null and session.api != null and sender in session.api.get_peers():
		_sync_open.rpc_id(sender, _state_payload(world))

## A guest departed: drop its input state with its body.
func peer_left(sender: int) -> void:
	_last_seq.erase(sender)
	_queues.erase(sender)

## Movement sync stops with the session: bodies return to their own physics.
func stop_sync() -> void:
	_active = false
	_seq_out = 0
	_last_seq.clear()
	_queues.clear()
	_targets.clear()
	var world := _world()
	if world != null:
		for body in world.all_players():
			var typed := body as PlayerBody2D
			if typed != null and typed.net_sync_driven:
				typed.net_sync_driven = false

func _physics_process(_delta: float) -> void:
	var world := _world()
	if world == null or world.session == null or not _active:
		return
	var session: Variant = world.session
	if session.is_host() and session.state == &"hosting":
		_host_tick(world, session)
	elif session.is_guest() and session.state == &"connected":
		_guest_tick(world, session)

## Exactly one transform writer per body: everything but the host's own local
## body is driven here while sync runs.
func _claim(world: WorldRoot2D, session: Variant) -> void:
	for body in world.all_players():
		var typed := body as PlayerBody2D
		if typed == null:
			continue
		var driven: bool = not (session.is_host() and typed.is_local)
		if typed.net_sync_driven != driven:
			typed.net_sync_driven = driven

func _host_tick(world: WorldRoot2D, session: Variant) -> void:
	_claim(world, session)
	for sender in _queues.keys():
		var body := world.player_by_peer_id(int(sender)) as PlayerBody2D
		if not session.active.has(sender) or body == null:
			_queues.erase(sender)
			continue
		var queue: Array = _queues[sender]
		var steps := 0
		var claimed: Variant = null
		while not queue.is_empty() and steps < STEP_BUDGET and is_instance_valid(body):
			var entry: Dictionary = queue.pop_front()
			steps += 1
			body.host_movement_tick(_step(), entry.frame)
			claimed = entry.pos
		if claimed != null and is_instance_valid(body):
			_course_correct(body, claimed)
	for peer in session.active.keys():
		if session.api != null and peer in session.api.get_peers():
			_state_frame.rpc_id(int(peer), _state_payload(world))
			state_sent += 1

## Bounded server-side course correction: after the host advanced the guest's
## body with the very frame the guest predicted from, the body should sit at
## that frame's claimed position. Anything left is drift the two simulations
## legitimately accumulated apart (host-only geometry the guest's prediction
## cannot see, or stepped-count timing). Nudge a fraction of the gap per tick,
## capped in range (COURSE_BOUND refuses anything suspiciously larger) and step
## size, and always through move_and_collide: the host's collision stays
## authoritative and a blocked body is never dragged through what stops it.
func _course_correct(body: PlayerBody2D, claimed: Vector2) -> void:
	var gap: Vector2 = claimed - body.global_position
	var dist := gap.length()
	if dist == 0.0 or dist > COURSE_BOUND:
		return
	var pull := gap * COURSE_RATE
	if pull.length() > COURSE_STEP_MAX:
		pull = pull.limit_length(COURSE_STEP_MAX)
	body.move_and_collide(pull)

func _guest_tick(world: WorldRoot2D, session: Variant) -> void:
	_claim(world, session)
	var body := world.local_player() as PlayerBody2D
	if body != null and body.net_sync_driven:
		_seq_out += 1
		var frame: Dictionary = body.controls.sample_frame(_seq_out)
		body.predict_movement_tick(_step(), frame)
		frames_sent += 1
		_input_frame.rpc_id(1, frame, [body.global_position.x, body.global_position.y])
	for id in _targets.keys():
		var replica := world.player_by_id(id) as PlayerBody2D
		if replica == null or replica == body:
			continue
		var target: Dictionary = _targets[id]
		replica.global_position = replica.global_position.lerp(target.pos, INTERP)
		replica.facing8 = target.dir8
		replica.facing_vec = Iso.dir8_vector(target.dir8)

func _state_payload(world: WorldRoot2D) -> Array:
	var out: Array = []
	for body in world.all_players():
		out.append([int(body.player_slot), body.global_position.x, body.global_position.y, int(body.facing8)])
	return out

## Closed state schema: 1..STATE_MAX unique slots, whole dir8, finite bounded
## positions. Static so a hostile payload can be judged without a live session.
static func valid_state(payload: Variant) -> bool:
	if typeof(payload) != TYPE_ARRAY or payload.is_empty() or payload.size() > STATE_MAX:
		return false
	var slots := {}
	for entry in payload:
		if typeof(entry) != TYPE_ARRAY or entry.size() != 4:
			return false
		if not MultiplayerSession._whole(entry[0], 0, 3) or not MultiplayerSession._whole(entry[3], 0, 7):
			return false
		if slots.has(int(entry[0])):
			return false
		slots[int(entry[0])] = true
		for value in [entry[1], entry[2]]:
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or absf(float(value)) > POS_BOUND:
				return false
	return true

static func _valid_pos(pos: Variant) -> bool:
	if typeof(pos) != TYPE_ARRAY or pos.size() != 2:
		return false
	for value in pos:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or absf(float(value)) > POS_BOUND:
			return false
	return true

## One guest movement frame: closed PlayerInput sample + claimed position.
@rpc("any_peer", "call_remote", "unreliable", 1)
func _input_frame(payload: Variant, pos: Variant) -> void:
	var world := _world()
	if world == null or world.session == null or not _active:
		return
	var session: Variant = world.session
	if not session.is_host() or session.state != &"hosting":
		return
	var sender := multiplayer.get_remote_sender_id()
	if not session.active.has(sender):
		last_reject = &"sender"
		return
	if not PlayerInput.valid_frame(payload) or not _valid_pos(pos):
		last_reject = &"schema"
		return
	var sequence := int(payload.get("sequence"))
	if sequence <= int(_last_seq.get(sender, -1)):
		last_reject = &"replay"
		return
	var body := world.player_by_peer_id(sender) as PlayerBody2D
	if body == null or body.player_id != StringName(str(session.active[sender])):
		last_reject = &"body"
		return
	var claimed := Vector2(float(pos[0]), float(pos[1]))
	if claimed.distance_to(body.global_position) > RECONCILE_BOUND:
		last_reject = &"desync"
		return
	_last_seq[sender] = sequence
	frames_received += 1
	var queue: Array = []
	if _queues.has(sender):
		queue = _queues[sender]
	else:
		_queues[sender] = queue
	if queue.size() < QUEUE_MAX:
		queue.append({"frame": payload, "pos": claimed})

## Authoritative body state to interpolate toward (host -> guests).
@rpc("authority", "call_remote", "unreliable", 1)
func _state_frame(payload: Variant) -> void:
	var world := _world()
	if world == null or world.session == null:
		return
	var session: Variant = world.session
	if not session.is_guest() or session.state != &"connected":
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	if not valid_state(payload):
		last_reject = &"state"
		return
	state_received += 1
	_apply_state(payload)

## Reliable movement bootstrap (channel 0): the authoritative snapshot a guest
## starts interpolating from.
@rpc("authority", "call_remote", "reliable", 0)
func _sync_open(payload: Variant) -> void:
	var world := _world()
	if world == null or world.session == null:
		return
	var session: Variant = world.session
	if not session.is_guest() or session.state != &"connected":
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	if not valid_state(payload):
		last_reject = &"open"
		return
	_targets.clear()
	_apply_state(payload)
	_active = true

func _apply_state(payload: Array) -> void:
	for entry in payload:
		_targets[StringName("p%d" % int(entry[0]))] = {"pos": Vector2(float(entry[1]), float(entry[2])), "dir8": int(entry[3])}
