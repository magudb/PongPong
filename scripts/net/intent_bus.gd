extends Node
## Host-only discrete gameplay. Transport sender, never payload, names the actor.
const MAX_BYTES := 512
const MAX_SEQUENCE := 2147483647
const QUOTA := 16
var _sequence := 0
var _watermarks := {}
var _rates := {}
var _cooldowns := {}
var _busy := false
var applied_received := 0
var responses_received := 0
var applied_count := 0
var last_result: Dictionary = {}

func _world() -> WorldRoot2D:
	return get_parent() as WorldRoot2D

func submit(op: StringName, cell: Vector2i, item: StringName = &"") -> bool:
	var world := _world()
	if world == null or world.session == null: return false
	var session := world.session
	if not session.is_guest() or session.state != &"connected" or _sequence >= MAX_SEQUENCE: return false
	_sequence += 1
	_request.rpc_id(1, JSON.stringify({"epoch": session._host_generation, "seq": _sequence, "op": str(op), "cell": [cell.x, cell.y], "item": str(item)}).to_utf8_buffer())
	return true

static func valid_request(v: Variant) -> bool:
	if not v is Dictionary or v.size() != 5: return false
	for key in ["epoch", "seq", "op", "cell", "item"]:
		if not v.has(key): return false
	if not MultiplayerSession._whole(v.epoch, 1, MAX_SEQUENCE) or not MultiplayerSession._whole(v.seq, 1, MAX_SEQUENCE): return false
	if not v.op is String or v.op not in ["till", "plant", "water", "harvest"]: return false
	if not v.item is String or v.item.length() > 64: return false
	if not v.cell is Array or v.cell.size() != 2: return false
	for n in v.cell:
		if not MultiplayerSession._whole(n, 0, 255): return false
	return true

@rpc("any_peer", "call_remote", "reliable", 0)
func _request(bytes: PackedByteArray) -> void:
	var world := _world()
	if world == null or world.session == null or not is_inside_tree() or is_queued_for_deletion(): return
	var session := world.session
	var sender := multiplayer.get_remote_sender_id()
	if not session.is_host() or session.state != &"hosting" or not session.active.has(sender) or not session._transport_live(sender) or not NetAuthority.can_write(): return
	var now := Time.get_ticks_msec()
	var rate: Dictionary = _rates.get(sender, {"start": now, "count": 0})
	if now - int(rate.start) >= 1000: rate = {"start": now, "count": 0}
	rate.count += 1
	_rates[sender] = rate
	if int(rate.count) > QUOTA: return
	var decoder := JSON.new()
	var v: Variant = null
	if bytes.size() <= MAX_BYTES and decoder.parse(bytes.get_string_from_utf8()) == OK: v = decoder.data
	if not valid_request(v):
		_reply(sender, 0, &"", false, "schema")
		return
	if int(v.epoch) != session.generation:
		_reply(sender, int(v.seq), &"", false, "epoch")
		return
	if int(v.seq) <= int(_watermarks.get(sender, 0)):
		_reply(sender, int(v.seq), StringName(session.active[sender]), false, "replay")
		return
	# Consume before any callback. Detail eviction cannot reopen an old sequence.
	_watermarks[sender] = int(v.seq)
	var id: StringName = session.active[sender]
	var body := world.player_by_peer_id(sender)
	var row := PlayerRegistry.peek_state(id)
	if body == null or PlayerRegistry.registered_id(body) != id or row == null or row.peer_id != sender or world.player_by_id(id) != body:
		_reply(sender, int(v.seq), id, false, "owner")
		return
	if _busy or now < int(_cooldowns.get(sender, 0)):
		_reply(sender, int(v.seq), id, false, "cooldown")
		return
	var life: WeakRef = weakref(self)
	var epoch := session.generation
	_busy = true
	var reason: String = PlayerRegistry.for_player(id, func() -> String: return _apply(world, body, row, v))
	if life.get_ref() == null: return
	_busy = false
	if not session._alive(epoch) or _world() != world or PlayerRegistry.peek_state(id) != row: return
	if reason == "":
		applied_count += 1
		_cooldowns[sender] = now + 340
	_reply(sender, int(v.seq), id, reason == "", reason)

func _apply(world: WorldRoot2D, body: Node, row: PlayerState, v: Dictionary) -> String:
	var farm: FarmGrid = world.farm as FarmGrid
	if farm == null or world.area == null or world.traveling or world.sleeping or row.area != &"farm" or world.area.map.id != farm.map.id: return "area"
	if body.state != 0 or body.is_flying or body.half_hearts <= 0: return "eligibility"
	var cell := Vector2i(int(v.cell[0]), int(v.cell[1]))
	var feet := world.area.global_to_cell(body.global_position)
	if absi(cell.x - feet.x) > 1 or absi(cell.y - feet.y) > 1: return "range"
	var item := StringName(v.item)
	var def := GameData.item_def(item)
	if v.op == "harvest":
		if item != &"": return "item"
		if farm.state_of(cell) != FarmGrid.State.READY: return "no_effect"
		return "" if farm.harvest(cell) > 0 else "inventory_full"
	if not GameData.eco().has_item(item): return "ownership"
	if not farm.can_till(cell): return "no_effect"
	match v.op:
		"till":
			if str(def.get("tool_type", "")) != "hoe": return "item"
			if farm.state_of(cell) != FarmGrid.State.EMPTY: return "no_effect"
		"plant":
			var crop := StringName(str(def.get("crop_id", "")))
			if str(def.get("category", "")) != "seed" or not farm.crop_defs.has(String(crop)): return "item"
			if farm.state_of(cell) != FarmGrid.State.TILLED or cell == feet: return "no_effect"
			if not farm.in_season(crop): return "season"
			if GameData.eco()._backpack_count(item) < 1: return "ownership"
		"water":
			if str(def.get("tool_type", "")) != "watering": return "item"
			var plot := farm.get_plot(cell)
			if plot == null or plot.state in [FarmGrid.State.EMPTY, FarmGrid.State.WITHERED]: return "no_effect"
			if plot.watered and (plot.eligible_water or not farm.in_water_window(float(GameData.gm().hour), plot.crop_id)): return "no_effect"
	var cost := maxf(0.0, float(def.get("stamina_cost", 4.0)) * float(SpeciesPerks.value(row.character_skin, "tool_cost_mult", 1.0)))
	if not is_finite(cost) or body.stamina < cost: return "stamina"
	# Debit before the existing farm's observer-producing mutation.
	body._spend_stamina(cost)
	row.stamina = body.stamina
	var ok := false
	match v.op:
		"till": ok = farm.till(cell)
		"plant": ok = farm.plant(cell, item) == ""
		"water": ok = farm.water(cell)
	if not ok and is_instance_valid(body):
		body.stamina += cost
		row.stamina = body.stamina
	return "" if ok else "no_effect"

func _reply(_sender: int, seq: int, actor: StringName, ok: bool, reason: String) -> void:
	var world := _world()
	if world == null or world.session.state != &"hosting": return
	var bytes := JSON.stringify({"seq": seq, "actor": str(actor), "ok": ok, "reason": reason}).to_utf8_buffer()
	last_result = {"seq": seq, "actor": str(actor), "ok": ok, "reason": reason}
	last_result.make_read_only()
	for peer in world.session.active.keys():
		if world.session._transport_live(peer): _result.rpc_id(peer, world.session.generation, bytes)
	if ok and world.get("farm_replication") != null: world.farm_replication.publish()

@rpc("authority", "call_remote", "reliable", 0)
func _result(epoch: int, bytes: PackedByteArray) -> void:
	var world := _world()
	if world == null or multiplayer.get_remote_sender_id() != 1 or not world.session.is_guest() or world.session.state != &"connected" or epoch != world.session._host_generation or bytes.size() > 256: return
	var decoder := JSON.new()
	if decoder.parse(bytes.get_string_from_utf8()) != OK: return
	var value: Variant = decoder.data
	if not value is Dictionary or value.size() != 4 or not value.get("ok") is bool or not value.get("reason") is String or not value.get("actor") is String or not MultiplayerSession._whole(value.get("seq"), 0, MAX_SEQUENCE): return
	last_result = value.duplicate(true)
	last_result.make_read_only()
	responses_received += 1
	if value.ok: applied_received += 1

func peer_left(sender: int) -> void:
	# Never erase watermarks during a live generation (peer IDs may reappear).
	_rates.erase(sender)
	_cooldowns.erase(sender)

func stop() -> void:
	_watermarks.clear()
	_rates.clear()
	_cooldowns.clear()
	_sequence = 0
