extends Node
## Read-only guest presentation. Never uses a save loader or economic events.
const MAX_BYTES := 262144
const MAX_PLOTS := 2048
const MAX_SLOTS := 128
var revision := 0
var received := 0
var _elapsed := 0.0
var _last_bytes := PackedByteArray()
var projection: FarmGrid
var presentation_area: IsoArea
var _view: FarmView
var _stop_serial := 0

class PresentationArea extends IsoArea:
	func _enter_tree() -> void: pass
	func _exit_tree() -> void: pass

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.2: return
	_elapsed = 0.0
	publish()

func publish() -> void:
	var world := get_parent() as WorldRoot2D
	if world == null or world.session == null or not world.session.is_host() or world.session.state != &"hosting" or world.farm == null or not NetAuthority.can_write(): return
	var rows := {}
	for body in world.all_players():
		var id := PlayerRegistry.registered_id(body)
		var row := PlayerRegistry.peek_state(id)
		if row == null or row.inventory.size() > MAX_SLOTS: return
		rows[str(id)] = {"peer": body.peer_id, "inventory": row.to_dict().inventory, "gold": row.gold, "stamina": body.stamina, "max_stamina": body.max_stamina}
	var model: Dictionary = world.farm.to_dict()
	if model.plots.size() > MAX_PLOTS: return
	var content := JSON.stringify({"farm": model, "rows": rows}).to_utf8_buffer()
	if content.size() > MAX_BYTES: return
	# New admissions also need an unchanged snapshot. Bounded periodic snapshots
	# are deliberately honest full state, not synthetic delta/reward events.
	_last_bytes = content
	revision += 1
	for peer in world.session.active.keys():
		if world.session._transport_live(peer): _snapshot.rpc_id(peer, world.session.generation, revision, content)

@rpc("authority", "call_remote", "reliable", 0)
func _snapshot(epoch: int, serial: int, bytes: PackedByteArray) -> void:
	var world := get_parent() as WorldRoot2D
	if world == null or world.session == null or not world.guest_bootstrap or not NetAuthority.owns_guest(world) or multiplayer.get_remote_sender_id() != 1 or world.session.state != &"connected" or epoch != world.session._host_generation or serial <= received or bytes.size() > MAX_BYTES: return
	# Keep authority from admission through construction/readiness and redraws.
	# Weak Nodes avoid retaining freed callback owners; rows are exact model refs.
	var origin := {"world": weakref(world), "session": weakref(world.session), "generation": world.session.generation, "epoch": epoch, "api": world.session.api, "peer": world.session.peer, "stop": _stop_serial, "rows": [], "grid": weakref(projection) if projection != null else null, "area": weakref(presentation_area) if presentation_area != null else null, "view": weakref(_view) if _view != null else null}
	var decoder := JSON.new()
	if decoder.parse(bytes.get_string_from_utf8()) != OK: return
	var value: Variant = decoder.data
	if not value is Dictionary or value.size() != 2 or not value.get("rows") is Dictionary or not FarmGrid.validate_dict(value.get("farm")): return
	if value.farm.plots.size() > MAX_PLOTS or value.rows.size() < 1 or value.rows.size() > 4: return
	for id in value.rows:
		var row := PlayerRegistry.peek_state(StringName(id))
		var body := world.player_by_id(StringName(id))
		var v: Variant = value.rows[id]
		if row == null or body == null or not v is Dictionary or v.size() != 5 or not MultiplayerSession._whole(v.get("peer"), 1, 2147483647) or int(v.peer) != body.peer_id: return
		if typeof(v.get("max_stamina")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(v.max_stamina)) or float(v.max_stamina) <= 0 or float(v.max_stamina) > 10000: return
		if not MultiplayerSession._whole(v.get("gold"), 0, 2147483647) or typeof(v.get("stamina")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(v.stamina)) or float(v.stamina) < 0 or float(v.stamina) > float(v.max_stamina): return
		if not v.get("inventory") is Array or v.inventory.size() > MAX_SLOTS: return
		for slot in v.inventory:
			if not slot is Dictionary or slot.size() != 3 or not slot.get("id") is String or slot.id.length() > 64 or not MultiplayerSession._whole(slot.get("amount"), 1, 2147483647) or not slot.get("meta") is Dictionary: return
		origin.rows.append({"id": StringName(id), "row": row, "body": weakref(body), "peer": int(v.peer), "value": v})
	if not _snapshot_current(origin): return
	if projection == null:
		var grid := FarmGrid.new()
		grid.presentation_only = true
		projection = grid
		origin.grid = weakref(grid)
		add_child(grid)
		if not _snapshot_current(origin): return
		var area := PresentationArea.new()
		presentation_area = area
		origin.area = weakref(area)
		add_child(area)
		if not _snapshot_current(origin): return
		# Deliberately no normal area/world setup: no NPCs, services, markers,
		# clock, story hooks, pending saves, or autonomous farm simulation.
		area.map = grid.map
		area.projection = &"iso"
		area._make_skeleton()
		if not _snapshot_current(origin): return
		area._paint_ground()
		if not _snapshot_current(origin): return
		area.set_process(false)
		var view := FarmView.new()
		_view = view
		origin.view = weakref(view)
		add_child(view)
		if not _snapshot_current(origin): return
		view.setup(grid, area)
		if not _snapshot_current(origin): return
	# All setters below are plain fields/containers, not callback-producing
	# body apply APIs. Commit the complete projection before any plot observer.
	var committed := projection.commit_presentation(value.farm)
	if committed.is_empty(): return
	for record in origin.rows:
		var row: PlayerState = record.row
		var body: PlayerBody2D = record.body.get_ref()
		var v: Dictionary = record.value
		row.inventory.clear()
		for slot in v.inventory: row.inventory.append({"id": StringName(slot.id), "amount": int(slot.amount), "meta": slot.meta.duplicate(true)})
		row.gold = int(v.gold)
		row.stamina = float(v.stamina)
		row.max_stamina = float(v.max_stamina)
		body.max_stamina = row.max_stamina
		body.stamina = row.stamina
	received = serial
	origin["serial"] = serial
	for cell in committed.dirty:
		if not _snapshot_current(origin): return
		var grid: FarmGrid = origin.grid.get_ref()
		grid.plot_changed.emit(cell)

func _snapshot_current(origin: Dictionary) -> bool:
	var world: WorldRoot2D = origin.world.get_ref()
	var session: MultiplayerSession = origin.session.get_ref()
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion() or get_parent() != world or world.farm_replication != self or not world.guest_bootstrap or not NetAuthority.owns_guest(world): return false
	if not is_instance_valid(session) or world.session != session or session.get_parent() != world or not session._alive(origin.generation) or session.state != &"connected" or session._host_generation != origin.epoch or session.api != origin.api or session.peer != origin.peer or _stop_serial != origin.stop: return false
	if origin.has("serial") and received != origin.serial: return false
	for key in ["grid", "area", "view"]:
		var current: Node = projection if key == "grid" else (presentation_area if key == "area" else _view)
		var retained: Node = origin[key].get_ref() if origin[key] != null else null
		if current != retained: return false
		if origin[key] != null and (not is_instance_valid(retained) or not retained.is_inside_tree() or retained.is_queued_for_deletion() or retained.get_parent() != self): return false
	for record in origin.rows:
		var body: Node = record.body.get_ref()
		if not is_instance_valid(body) or world.player_by_id(record.id) != body or world.player_by_peer_id(record.peer) != body or PlayerRegistry.registered_id(body) != record.id or PlayerRegistry.peek_state(record.id) != record.row: return false
	return true

func stop() -> void:
	_stop_serial += 1
	if is_instance_valid(presentation_area): presentation_area.queue_free()
	if is_instance_valid(projection): projection.queue_free()
	if is_instance_valid(_view): _view.queue_free()
	presentation_area = null
	projection = null
	_view = null
	received = 0
	revision = 0
	_last_bytes.clear()
