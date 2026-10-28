extends Node
## Read-only test observer. Never filters or consumes input; not OS exclusivity.
## Metadata is trusted internal harness evidence, not an anti-forgery boundary.
const ACTIVE := &"_test_scoped_input_observer"
const MARK := &"_test_input_provenance"
const MAX_ROWS := 4096
var _file: FileAccess
var _path := ""
var _closed := false
var _started := false
var _first_failure := ""
var _rows := 0
var _unowned := 0
var _owned := 0
var _window: Window
var _result: Dictionary = {}
var _sequence := 0
var _retired := 0
var _pending: Dictionary = {}
var _context: WeakRef
var _body: WeakRef
var _world: WeakRef
var _controls: WeakRef
var _profile: WeakRef
var _section_name := ""
var _section_row: Dictionary = {}
var _registered_id: StringName = &""
var _tools := 0
var _source_revision := -1
static func tag_if_active(event: InputEvent, route: String = "parse") -> InputEvent:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_meta(ACTIVE):
		return event
	var ref: Variant = tree.root.get_meta(ACTIVE)
	var lease: Variant = ref.get_ref() if ref is WeakRef else null
	if is_instance_valid(lease) and lease._physical(event):
		return lease.tag(event, route)
	return event
func _snapshot() -> Dictionary:
	var body: Variant = _body.get_ref() if _body != null else null
	if not is_instance_valid(body) or not body.is_inside_tree():
		return {"owner_live": false}
	var gm := get_tree().root.get_node_or_null("GameManager")
	return {"owner_live": true, "body": body.get_instance_id(), "registered_id": str(_registered_id), "section": _section_name,
		"feet": str(body.global_position), "canvas": str(body.get_viewport_transform()), "camera_zoom": str(body.camera.zoom),
		"camera_center": str(body.camera.get_screen_center_position()), "viewport": str(_window.get_visible_rect()),
		"gui": str(_window.gui_get_hovered_control().get_path()) if _window.gui_get_hovered_control() != null else "",
		"paused": get_tree().paused, "modal": gm.is_modal_open() if gm != null else false, "state": body.state,
		"cursor": str(body._cursor_screen), "raw_mouse": str(body.controls._mouse), "held": body.controls._held.duplicate(true),
		"farm_hold": body._farm_use_held, "physics_frame": Engine.get_physics_frames()}
func _tool_used(item: StringName, cell: Vector2i, ok: bool) -> void:
	if _closed:
		return
	if not _valid():
		close()
		return
	_tools += 1
	_write({"kind": "tool", "item": str(item), "cell": [cell.x, cell.y], "ok": ok, "state": _snapshot()})
func _valid() -> bool:
	var t: Variant = _context.get_ref() if _context != null else null
	var body: Variant = _body.get_ref() if _body != null else null
	var world: Variant = _world.get_ref() if _world != null else null
	if not is_instance_valid(t) or t.detached or t.section != _section_name or not is_same(t.stats.get(_section_name), _section_row):
		_fail("section_lifetime_lost")
		return false
	if not is_instance_valid(body) or not (body is Node) or not body.is_inside_tree() or body.is_queued_for_deletion():
		_fail("owner_lifetime_lost")
		return false
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion() or PlayerRegistry.world(get_tree()) != world:
		_fail("world_lifetime_lost")
		return false
	if PlayerRegistry.registered_id(body) != _registered_id or PlayerRegistry.by_id(_registered_id, get_tree()) != body or not body.is_local:
		_fail("owner_registration_lost")
		return false
	if not is_instance_valid(body.controls) or not is_instance_valid(_profile.get_ref()) or body.controls != _controls.get_ref() or body.controls.revision != _source_revision or not body.controls._attached or PlayerRegistry._states.get(_registered_id) != _profile.get_ref():
		_fail("source_or_profile_replaced")
		return false
	return true
func _process(_delta: float) -> void:
	if _started and not _closed and not _valid():
		close()
func _owner_exiting() -> void:
	_fail("owner_exited")
	close()
func _world_exiting() -> void:
	_fail("world_exited")
	close()
func tag(event: InputEvent, route: String = "parse") -> InputEvent:
	if not _started or _closed or not _valid() or route not in ["parse", "push"] or not _physical(event):
		_fail("invalid_tag_request")
		return event
	if _pending.size() >= 128:
		_fail("pending_bound_exceeded")
		return event
	_sequence += 1
	var marker := {"lease": get_instance_id(), "sequence": _sequence}
	event.set_meta(MARK, marker)
	_pending[_sequence] = {"route": route, "class": event.get_class(), "device": event.device, "window": false, "input": false}
	return event
func begin(t, body: Variant, path: String) -> bool:
	if _started or _closed or not is_inside_tree():
		_fail("invalid_start")
		return false
	if not is_instance_valid(body) or not (body is Player2D) or PlayerRegistry.registered_id(body) == &"" or not body.is_local or not is_instance_valid(body.controls):
		_fail("invalid_owner")
		return false
	var existing_profile: Variant = PlayerRegistry._states.get(PlayerRegistry.registered_id(body))
	if not is_instance_valid(existing_profile) or not (existing_profile is PlayerState):
		_fail("missing_profile")
		return false
	_context = weakref(t)
	_body = weakref(body)
	_world = weakref(PlayerRegistry.world(get_tree()))
	_controls = weakref(body.controls)
	_source_revision = body.controls.revision
	_registered_id = PlayerRegistry.registered_id(body)
	_profile = weakref(existing_profile)
	_section_name = t.section
	_section_row = t.stats.get(t.section, {})
	process_mode = Node.PROCESS_MODE_ALWAYS
	_window = get_tree().root
	_path = path
	if _window.has_meta(ACTIVE):
		var ref: Variant = _window.get_meta(ACTIVE)
		var previous: Variant = ref.get_ref() if ref is WeakRef else null
		if is_instance_valid(previous) and not previous._closed:
			_fail("overlapping_lease")
			return false
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		_fail("stream_open_failed")
		return false
	_started = true
	_window.set_meta(ACTIVE, weakref(self))
	body.tool_used.connect(_tool_used)
	body.tree_exiting.connect(_owner_exiting)
	_world.get_ref().tree_exiting.connect(_world_exiting)
	t.on_cleanup(close)
	_window.window_input.connect(_window_input)
	_write({"kind": "begin", "mode": DisplayServer.get_name(), "lease": get_instance_id(), "state": _snapshot()})
	return true
func _write(row: Dictionary) -> void:
	if _file == null or not _file.is_open():
		_fail("stream_unavailable")
		return
	if _rows >= MAX_ROWS:
		_fail("stream_bound_exceeded")
		return
	_rows += 1
	row["row"] = _rows
	row["usec"] = Time.get_ticks_usec()
	_file.store_line(JSON.stringify(row))
	_file.flush()
	if _file.get_error() != OK:
		_fail("stream_flush_failed")
func _fail(reason: String) -> void:
	if _first_failure == "":
		_first_failure = reason
func _physical(e: InputEvent) -> bool:
	return e is InputEventMouse or e is InputEventKey or e is InputEventJoypadButton or e is InputEventJoypadMotion or e is InputEventGesture
func _window_input(e: InputEvent) -> void:
	_observe(e, "window")
func _input(e: InputEvent) -> void:
	_observe(e, "input")
func _observe(e: InputEvent, stage: String) -> void:
	if not _started or _closed or not _physical(e):
		return
	if not _valid():
		close()
		return
	var marker: Variant = e.get_meta(MARK) if e.has_meta(MARK) else null
	var seq := 0
	if marker is Dictionary and marker.get("lease") == get_instance_id() and typeof(marker.get("sequence")) == TYPE_INT:
		seq = marker.sequence
	var owned := false
	if seq > _retired and _pending.has(seq):
		var pending: Dictionary = _pending[seq]
		owned = pending["class"] == e.get_class() and pending.device == e.device and not pending[stage]
		if owned:
			pending[stage] = true
			if pending.input and (pending.window or pending.route == "push"):
				_pending.erase(seq)
				_retired = maxi(_retired, seq)
	if owned:
		_owned += 1
	else:
		_unowned += 1
		_fail("unowned_physical_event")
	_write({"kind": "event", "stage": stage, "class": e.get_class(), "device": e.device, "owned": owned, "sequence": seq, "event_text": e.as_text(), "state": _snapshot()})
func close() -> Dictionary:
	if _closed:
		return _result.duplicate(true)
	if _started:
		_valid()
	if not _pending.is_empty():
		_fail("owned_delivery_missing")
	if _owned == 0:
		_fail("no_owned_observation")
	_closed = true
	if is_instance_valid(_window) and _window.has_meta(ACTIVE):
		var ref: Variant = _window.get_meta(ACTIVE)
		if ref is WeakRef and ref.get_ref() == self:
			_window.remove_meta(ACTIVE)
	var body: Variant = _body.get_ref() if _body != null else null
	if is_instance_valid(body) and body.tool_used.is_connected(_tool_used):
		body.tool_used.disconnect(_tool_used)
	for pair in [[_body, _owner_exiting], [_world, _world_exiting]]:
		var object: Variant = pair[0].get_ref() if pair[0] != null else null
		if is_instance_valid(object) and object.tree_exiting.is_connected(pair[1]):
			object.tree_exiting.disconnect(pair[1])
	if is_instance_valid(_window) and _window.window_input.is_connected(_window_input):
		_window.window_input.disconnect(_window_input)
	_result = {"kind": "close", "closed": true, "accepted": _started and _first_failure == "", "first_failure": _first_failure, "owned": _owned, "unowned": _unowned, "tools": _tools, "sequence": _sequence, "retired": _retired, "pending": _pending.size()}
	_write(_result.duplicate())
	if _first_failure != "":
		_result.accepted = false
		_result.first_failure = _first_failure
	if _file != null:
		_file.close()
	return _result.duplicate(true)
func _exit_tree() -> void:
	if _started and not _closed:
		_fail("observer_exited_before_close")
		close()
