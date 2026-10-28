class_name MultiplayerSession
extends Node
## World-owned ENet control plane. Gameplay replication is intentionally absent.
var state: StringName = &"idle"
var role: StringName = &"offline"
var generation: int = 0
var packets_received: int = 0
var api: SceneMultiplayer
var peer: ENetMultiplayerPeer
const BUILD_ID := "mp4-admission-1"
const HELLO_BYTES := 1024
const HELLO_MS := 5000
var pending: Dictionary = {}
var active: Dictionary = {}
var _rates: Dictionary = {}
const CONTROL_QUOTA := 8
var _ticket := 0
var _staged: Array = []
var _host_generation := 0
var _guest_ticket := 0
var _saved_rows: Dictionary = {}
var _saved_fallback: PlayerState
var _projection_host: PlayerState
var _metadata := {"name": "Guest", "character_type": 0, "character_skin": "animal_fox"}
var _deadline: int = 0
var last_rejection: StringName = &""
var _closing := false
var _api_path: NodePath

func is_host() -> bool: return role == &"host"
func is_guest() -> bool: return role == &"guest"

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if is_host() and state == &"hosting":
		for id in pending.keys():
			if now >= int(pending[id].deadline): _reject(id, &"timeout")
	elif is_guest() and state == &"joining" and now >= _deadline:
		close(&"timeout")

func _ready() -> void:
	name = "MultiplayerSession"
	process_mode = Node.PROCESS_MODE_ALWAYS

func host(port: Variant = null, max_players: Variant = null, bind_address: Variant = "*") -> Error:
	if SaveManager.network_admission_blocked(): return ERR_BUSY
	if port == null: port = GameManager.config_value("multiplayer.default_port", 24565)
	if max_players == null: max_players = GameManager.config_value("multiplayer.max_players", 4)
	if not _whole(port, 1, 65535) or not _whole(max_players, 2, 4) or not bind_address is String: return ERR_INVALID_PARAMETER
	var world := get_parent() as WorldRoot2D
	if world == null or world.guest_bootstrap or not world.ready_for_play or world.roster == null or world.player_by_id(&"p0") == null or PlayerRegistry.peek_state(&"p0") == null: return ERR_UNCONFIGURED
	if get_tree().get_multiplayer(world.get_path()) != get_tree().get_multiplayer(): return ERR_ALREADY_IN_USE
	if _closing or is_guest() or not NetAuthority.can_write() or state not in [&"idle", &"ended"] or port < 1 or port > 65535 or max_players < 2 or max_players > 4: return ERR_INVALID_PARAMETER
	var transport := ENetMultiplayerPeer.new()
	if bind_address != "*" and not bind_address.is_valid_ip_address(): return ERR_INVALID_PARAMETER
	transport.set_bind_ip(bind_address)
	var error := transport.create_server(port, max_players - 1, 2, 262144, 262144)
	if error != OK:
		transport.close()
		return error
	role = &"host"
	state = &"hosting"
	generation += 1
	_install(transport)
	EventBus.net_session_changed.emit(state)
	return OK

func join(address: Variant, port: Variant = null, metadata: Variant = null) -> Error:
	if SaveManager.network_admission_blocked(): return ERR_BUSY
	if port == null: port = GameManager.config_value("multiplayer.default_port", 24565)
	if not address is String or not _whole(port, 1, 65535): return ERR_INVALID_PARAMETER
	if address.is_empty() or address.length() > 253 or address.strip_edges() != address: return ERR_INVALID_PARAMETER
	var world := get_parent() as WorldRoot2D
	if world == null or not world.guest_bootstrap or world.ready_for_play or world.area != null or not world.all_players().is_empty() or PlayerRegistry.world() != world or not NetAuthority.owns_guest(world): return ERR_UNCONFIGURED
	if get_tree().get_multiplayer(world.get_path()) != get_tree().get_multiplayer(): return ERR_ALREADY_IN_USE
	if metadata != null:
		if not profile_valid(metadata): return ERR_INVALID_PARAMETER
		_metadata = metadata.duplicate(true)
	if state != &"idle" or address.is_empty() or port < 1 or port > 65535: return ERR_INVALID_PARAMETER
	var transport := ENetMultiplayerPeer.new()
	var error := transport.create_client(address, port, 2)
	if error != OK:
		transport.close()
		return error
	role = &"guest"
	state = &"joining"
	_deadline = Time.get_ticks_msec() + HELLO_MS
	generation += 1
	_install(transport)
	return OK

func _install(transport: ENetMultiplayerPeer) -> void:
	api = SceneMultiplayer.new()
	api.allow_object_decoding = false
	api.server_relay = false
	_api_path = get_parent().get_path()
	get_tree().set_multiplayer(api, _api_path)
	api.peer_connected.connect(_peer_connected)
	api.peer_disconnected.connect(_peer_disconnected)
	api.connected_to_server.connect(_connected)
	api.connection_failed.connect(func(): close(&"connection_failed"))
	api.server_disconnected.connect(_server_lost)
	peer = transport
	api.multiplayer_peer = peer

func _server_lost() -> void:
	if not is_guest() or state not in [&"joining", &"connected"]: return
	var was_admitted := state == &"connected"
	var world_ref: WeakRef = weakref(get_parent())
	var lifetime: WeakRef = weakref(self)
	close(&"host_lost")
	if lifetime.get_ref() == null: return
	if was_admitted: _return_title.call_deferred(generation, world_ref)

func _return_title(epoch: int, world_ref: WeakRef) -> void:
	var world: Variant = world_ref.get_ref()
	if not is_instance_valid(world) or not is_guest() or state != &"ended" or generation != epoch or not is_inside_tree() or PlayerRegistry.world() != world or get_tree().current_scene != world: return
	var lifetime: WeakRef = weakref(self)
	var tree := get_tree()
	GameManager.pop_all_modals()
	if lifetime.get_ref() == null or not is_instance_valid(world) or tree.current_scene != world: return
	GameManager.change_phase(GameManager.GamePhase.MENU)
	if lifetime.get_ref() == null or not is_instance_valid(world) or tree.current_scene != world: return
	tree.change_scene_to_file("res://scenes/main/main_menu.tscn")

func _peer_connected(id: int) -> void:
	if is_host() and state == &"hosting" and id > 1:
		pending[id] = {"deadline": Time.get_ticks_msec() + HELLO_MS, "hello": false}

func _peer_disconnected(id: int) -> void:
	var lifetime: WeakRef = weakref(self)
	_rates.erase(id)
	pending.erase(id)
	if not is_host() or state != &"hosting" or not active.has(id): return
	var world := get_parent() as WorldRoot2D
	var epoch := generation
	var player_id: StringName = active[id]
	# Revoke membership before any public observer can reenter departure.
	active.erase(id)
	if world == null: return
	world.roster.capture_live_bodies(world)
	var body := world.player_by_peer_id(id)
	if body != null: world._unregister_player(body)
	if lifetime.get_ref() == null: return
	if not _alive(epoch): return
	EventBus.player_left.emit(player_id, &"disconnected")
	if lifetime.get_ref() == null: return
	if not _alive(epoch): return
	for other in active.keys():
		if _transport_live(other): _roster_update.rpc_id(other, epoch, _descriptor())

func _transport_live(id: int) -> bool:
	if api == null or peer == null or id not in api.get_peers(): return false
	var transport_peer := peer.get_peer(id)
	return transport_peer != null and transport_peer.get_state() == ENetPacketPeer.STATE_CONNECTED and transport_peer.get_channels() > 0

func _connected() -> void:
	if not is_guest() or state != &"joining": return
	_deadline = Time.get_ticks_msec() + HELLO_MS
	var envelope := {"protocol": GameManager.config_value("multiplayer.protocol", 1), "build": BUILD_ID, "content": GameManager.config_value("multiplayer.content_id", "traetoppen-mp4-1"), "profile": _metadata}
	_hello.rpc_id(1, JSON.stringify(envelope).to_utf8_buffer())

static func profile_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3: return false
	for key in ["name", "character_type", "character_skin"]:
		if not value.has(key): return false
	var nick: Variant = value.name
	if not nick is String or nick.strip_edges().is_empty() or nick.length() > 32 or nick.to_utf8_buffer().size() > 128: return false
	for index in nick.length():
		if nick.unicode_at(index) < 32 or (nick.unicode_at(index) >= 127 and nick.unicode_at(index) <= 159): return false
	var type: Variant = value.character_type
	if typeof(type) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(type)) or float(type) != floorf(float(type)) or type < 0 or type > 3: return false
	var skin: Variant = value.character_skin
	if not skin is String or skin.is_empty() or skin.length() > 64: return false
	for ch in skin:
		if not ch in "abcdefghijklmnopqrstuvwxyz0123456789_": return false
	var row := CharacterCatalog.skin(skin)
	return not row.is_empty() and not bool(row.get("retired", false)) and str(row.get("race", "")) == ["animal", "fairy", "hobbit", "ghost"][int(type)]

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(bytes: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _control_allowed(sender) or not pending.has(sender): return
	packets_received += 1
	if bool(pending[sender].hello):
		_reject(sender, &"duplicate_hello")
		return
	pending[sender].hello = true
	if bytes.size() > HELLO_BYTES:
		_reject(sender, &"size")
		return
	# Malformed untrusted JSON is a protocol refusal, not an engine error.
	var decoder := JSON.new()
	var value: Variant = null
	if decoder.parse(bytes.get_string_from_utf8()) == OK: value = decoder.data
	if not value is Dictionary or value.size() != 4:
		_reject(sender, &"envelope")
		return
	for key in ["protocol", "build", "content", "profile"]:
		if not value.has(key):
			_reject(sender, &"envelope")
			return
	if typeof(value.protocol) not in [TYPE_INT, TYPE_FLOAT] or value.protocol != GameManager.config_value("multiplayer.protocol", 1) or not value.build is String or value.build != BUILD_ID or not value.content is String or value.content != GameManager.config_value("multiplayer.content_id", "traetoppen-mp4-1"):
		_reject(sender, &"compatibility")
		return
	if not profile_valid(value.profile):
		_reject(sender, &"profile")
		return
	_receipt.rpc_id(sender)
	if get_parent() is WorldRoot2D: _prepare(sender, value.profile)

func _prepare(sender: int, metadata: Dictionary) -> void:
	var world := get_parent() as WorldRoot2D
	if world == null or not world.ready_for_play or world.player_by_id(&"p0") == null:
		_reject(sender, &"host_not_ready")
		return
	var slot := 0
	for candidate in range(1, PlayerRegistry.MAX_PLAYERS):
		var reserved := false
		for record in pending.values():
			if int(record.get("slot", -1)) == candidate: reserved = true
		if not PlayerRegistry._states.has(StringName("p%d" % candidate)) and not reserved:
			slot = candidate
			break
	if slot == 0:
		_reject(sender, &"profiles_full")
		return
	var row := world.roster.initialize_profile(StringName("p%d" % slot), sender, metadata)
	if row == null:
		_reject(sender, &"profile_init")
		return
	row.area = world.area.map.id
	row.player_pos = world.player.global_position + Vector2(32 * slot, 0)
	_ticket += 1
	pending[sender]["slot"] = slot
	pending[sender]["row"] = row
	pending[sender]["ticket"] = _ticket
	_prepared.rpc_id(sender, generation, _ticket, _descriptor(row))

func _descriptor(extra: PlayerState = null) -> PackedByteArray:
	var records: Array = []
	var world := get_parent() as WorldRoot2D
	for body in world.all_players():
		var row := PlayerRegistry.peek_state(body.player_id)
		var profile := row.to_dict()
		if body.player_id == &"p0":
			profile["name"] = GameManager.player_name
			profile["character_type"] = GameManager.character_type
			profile["character_skin"] = str(GameManager.character_skin)
		records.append({"slot": body.player_slot, "peer": body.peer_id, "profile": profile, "position": [body.global_position.x, body.global_position.y]})
	if extra != null:
		records.append({"slot": int(str(extra.player_id).trim_prefix("p")), "peer": extra.peer_id, "profile": extra.to_dict(), "position": [extra.player_pos.x, extra.player_pos.y]})
	return JSON.stringify(records).to_utf8_buffer()

func _decode_descriptor(bytes: PackedByteArray) -> Array:
	if bytes.size() > 65536: return []
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Array or data.is_empty() or data.size() > 4: return []
	var slots := {}
	var peers := {}
	for record: Variant in data:
		if not record is Dictionary or record.size() != 4: return []
		for key in ["slot", "peer", "profile", "position"]:
			if not record.has(key): return []
		if not _whole(record.slot, 0, 3) or not _whole(record.peer, 1, 2147483647): return []
		if slots.has(int(record.slot)) or peers.has(int(record.peer)): return []
		slots[int(record.slot)] = true
		peers[int(record.peer)] = true
		if (int(record.slot) == 0) != (int(record.peer) == 1): return []
		if not record.profile is Dictionary or record.profile.get("id") != "p%d" % int(record.slot): return []
		var profile: Dictionary = record.profile
		if not profile_valid({"name": profile.get("name"), "character_type": profile.get("character_type"), "character_skin": profile.get("character_skin")}): return []
		if not record.position is Array or record.position.size() != 2: return []
		for value: Variant in record.position:
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or absf(float(value)) > 1000000: return []
	return data if slots.has(0) and peers.has(api.get_unique_id()) else []

static func _whole(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

@rpc("authority", "call_remote", "reliable", 0)
func _prepared(host_generation: int, ticket: int, bytes: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 or not is_guest() or state != &"joining" or not _staged.is_empty(): return
	packets_received += 1
	var data := _decode_descriptor(bytes)
	if data.is_empty():
		close(&"invalid_descriptor")
		return
	_staged = data
	_host_generation = host_generation
	_guest_ticket = ticket
	_ready_ack.rpc_id(1, host_generation, ticket)

@rpc("any_peer", "call_remote", "reliable", 0)
func _ready_ack(host_generation: Variant, ticket: Variant) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _control_allowed(sender) or not pending.has(sender): return
	packets_received += 1
	var record: Dictionary = pending[sender]
	if not _whole(host_generation, 1, 2147483647) or not _whole(ticket, 1, 2147483647) or host_generation != generation or ticket != record.get("ticket", -1) or not record.has("row"):
		_reject(sender, &"ack")
		return
	var world := get_parent() as WorldRoot2D
	var row := record.row as PlayerState
	if world == null or world.is_queued_for_deletion() or not world.ready_for_play or world.player_by_id(&"p0") == null or PlayerRegistry.peek_state(row.player_id) != null or sender not in api.get_peers():
		_reject(sender, &"reservation_lost")
		return
	var epoch := generation
	pending.erase(sender)
	active[sender] = row.player_id
	PlayerRegistry._states[row.player_id] = row
	var body := _install_body(row, row.player_pos)
	if not _alive(epoch) or not is_instance_valid(body): return
	# Commit is irrevocable on the host; a lost final packet still retains this row.
	_committed.rpc_id(sender, epoch, int(ticket), _descriptor())
	for id in active.keys():
		if id != sender: _roster_update.rpc_id(id, epoch, _descriptor())
	_publish_body(body, epoch)

func _install_body(row: PlayerState, at: Vector2) -> Node2D:
	var world := get_parent() as WorldRoot2D
	var body := world._make_player()
	body.name = "Player_%s" % row.player_id
	body.set("admission_only", true)
	body.process_mode = Node.PROCESS_MODE_PAUSABLE
	world._register_player(body, int(str(row.player_id).trim_prefix("p")), row.peer_id)
	# Admission-only bodies belong to the World, not its cached/rebuilt area.
	# Leave area null: these passive projections retain their admitted profile
	# location without borrowing the host's travel or a freed IsoArea reference.
	world.add_child(body)
	body.global_position = at
	return body

func _publish_body(body: Node2D, epoch: int) -> void:
	if not _alive(epoch) or not is_instance_valid(body): return
	var id := PlayerRegistry.registered_id(body)
	if id == &"": return
	var lifetime: WeakRef = weakref(self)
	var body_lifetime: WeakRef = weakref(body)
	var row := PlayerRegistry.peek_state(id)
	EventBus.player_spawned.emit(body)
	# Observers may synchronously free this World and its session. Do not even
	# call a method on self after the signal until the WeakRef proves it alive.
	if lifetime.get_ref() == null: return
	var live_body: Variant = body_lifetime.get_ref()
	if not is_instance_valid(live_body) or not _alive(epoch) or PlayerRegistry.registered_id(live_body) != id or row == null or PlayerRegistry.peek_state(id) != row: return
	EventBus.player_joined.emit(id, int(live_body.get("peer_id")), row.to_dict())

func _alive(epoch: int) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and generation == epoch and state in [&"hosting", &"joining", &"connected"] and is_instance_valid(get_parent()) and not get_parent().is_queued_for_deletion()

@rpc("authority", "call_remote", "reliable", 0)
func _committed(host_generation: int, ticket: int, bytes: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 or not is_guest() or state != &"joining" or host_generation != _host_generation or ticket != _guest_ticket or _staged.is_empty(): return
	packets_received += 1
	var data := _decode_descriptor(bytes)
	if data.is_empty():
		close(&"invalid_commit")
		return
	_saved_rows = PlayerRegistry._states
	_saved_fallback = PlayerRegistry._fallback_state
	PlayerRegistry._states = {}
	state = &"connected"
	_staged.clear()
	var lifetime: WeakRef = weakref(self)
	_apply_view(data)
	if lifetime.get_ref() == null: return
	if state == &"connected": EventBus.net_session_changed.emit(state)

@rpc("authority", "call_remote", "reliable", 0)
func _roster_update(host_generation: int, bytes: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 or not is_guest() or state != &"connected" or host_generation != _host_generation: return
	packets_received += 1
	var data := _decode_descriptor(bytes)
	if data.is_empty():
		close(&"invalid_roster")
		return
	_apply_view(data)

func _apply_view(data: Array) -> void:
	var lifetime: WeakRef = weakref(self)
	var world := get_parent() as WorldRoot2D
	var epoch := generation
	var additions: Array = []
	var present := {}
	for record: Dictionary in data:
		var id := StringName("p%d" % int(record.slot))
		present[id] = true
		if world.player_by_id(id) != null: continue
		var row := PlayerState.new(id, int(record.peer))
		row.from_dict(record.profile)
		row.peer_id = int(record.peer)
		PlayerRegistry._states[id] = row
		if id == &"p0": _projection_host = row
		additions.append([row, Vector2(float(record.position[0]), float(record.position[1]))])
	var bodies: Array = []
	for pair in additions:
		bodies.append(_install_body(pair[0], pair[1]))
	for body in world.all_players():
		if not present.has(body.player_id):
			var id: StringName = body.player_id
			world._unregister_player(body)
			if lifetime.get_ref() == null: return
			if not _alive(epoch): return
			EventBus.player_left.emit(id, &"disconnected")
			if lifetime.get_ref() == null: return
			if not _alive(epoch): return
	for body in bodies:
		if not _alive(epoch): return
		_publish_body(body, epoch)
		if lifetime.get_ref() == null: return

@rpc("authority", "call_remote", "reliable", 0)
func _receipt() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 1 and is_guest() and state == &"joining": packets_received += 1

func _control_allowed(sender: int) -> bool:
	if not is_host() or state != &"hosting" or sender <= 1 or (not pending.has(sender) and not active.has(sender)): return false
	var now := Time.get_ticks_msec()
	var rate: Dictionary = _rates.get(sender, {"start": now, "count": 0})
	if now - int(rate.start) >= 1000: rate = {"start": now, "count": 0}
	rate.count += 1
	_rates[sender] = rate
	if int(rate.count) <= CONTROL_QUOTA: return true
	last_rejection = &"quota"
	var lifetime: WeakRef = weakref(self)
	var epoch := generation
	var origin_api := api
	var origin_peer := peer
	_peer_disconnected(sender)
	if lifetime.get_ref() == null: return false
	if not _alive(epoch) or api != origin_api or peer != origin_peer: return false
	if origin_peer != null and sender in origin_api.get_peers(): origin_peer.disconnect_peer(sender)
	return false

func _reject(id: int, reason: StringName) -> void:
	if id <= 1 or not pending.has(id): return
	last_rejection = reason
	pending.erase(id)
	if peer != null: peer.disconnect_peer(id)

## Predict only the existing close restoration, before its public observers.
func navigation_row_after_close() -> RefCounted:
	var current := PlayerRegistry.peek_state(&"p0")
	if is_guest() and _projection_host != null and current == _projection_host and not _saved_rows.is_empty():
		return _saved_rows.get(&"p0")
	return current

func close(reason: StringName = &"left") -> void:
	if role == &"offline": return
	if state == &"ended" or _closing: return
	var lifetime: WeakRef = weakref(self)
	_closing = true
	state = &"ended"
	generation += 1
	pending.clear()
	_rates.clear()
	active.clear()
	_staged.clear()
	var world := get_parent() as WorldRoot2D
	if world != null and is_host(): world.roster.capture_live_bodies(world)
	if api != null:
		for signal_name in [&"peer_connected", &"peer_disconnected", &"connected_to_server", &"connection_failed", &"server_disconnected"]:
			for connection in api.get_signal_connection_list(signal_name):
				var callback: Callable = connection.callable
				if callback.get_object() == self: api.disconnect(signal_name, callback)
	if peer != null: peer.close()
	if api != null:
		api.multiplayer_peer = null
		if is_inside_tree() and get_tree().get_multiplayer(_api_path) == api:
			get_tree().set_multiplayer(null, _api_path)
	peer = null
	var departed: Array[StringName] = []
	if world != null: departed = world._retire_session_bodies(self)
	else: _restore_offline_rows()
	if lifetime.get_ref() == null: return
	for id in departed:
		EventBus.player_despawned.emit(id)
		if lifetime.get_ref() == null: return
		EventBus.player_left.emit(id, reason)
		if lifetime.get_ref() == null: return
	_closing = false
	if is_instance_valid(world) and world.session == self: EventBus.net_session_changed.emit(state)

## Only the exact guest projection this session installed can restore its staged
## offline identities. An old, replaced session cannot roll a newer row set back.
func _restore_offline_rows() -> void:
	if not is_guest() or state != &"ended" or _saved_rows.is_empty(): return
	if _projection_host != null and PlayerRegistry.peek_state(&"p0") == _projection_host:
		PlayerRegistry._states = _saved_rows
		PlayerRegistry._fallback_state = _saved_fallback
	_saved_rows = {}
	_projection_host = null

func _exit_tree() -> void:
	close(&"detached")
