class_name PlayerInput
extends RefCounted
## Raw state must observe releases even while a modal pauses the body. This
## child captures only samples; gameplay handlers and visuals remain pausable.
class Capture extends Node:
	var owner_ref: WeakRef
	func _ready() -> void:
		Input.joy_connection_changed.connect(_joy_connection_changed)
	func _joy_connection_changed(device: int, connected: bool) -> void:
		var body: Node = owner_ref.get_ref() if owner_ref != null else null
		if is_instance_valid(body) and "controls" in body:
			body.get("controls").joy_connection_changed(device, connected)
	func _input(event: InputEvent) -> void:
		var body: Node = owner_ref.get_ref() if owner_ref != null else null
		if is_instance_valid(body) and "controls" in body:
			body.get("controls").handle_event(event)

## Per-body input, not network authority. Default owns keyboard/mouse and pad 0;
## bind_pad owns exactly that pad (including injected SDL events, never Action).
## Remote frames are passive offline samples, not RPCs or permission to use tools.
var _body: WeakRef
var _device := -1
var _attached := false
var _local := false
var _authority := false
var _held: Dictionary = {}
var _blocked_actions: Dictionary = {}
var _foreign_seen := false
var _mouse := Vector2.ZERO
var _mouse_seen := false
var _remote_move := Vector2.ZERO
var _remote_actions: Dictionary = {}
var _remote_aim := Vector2.ZERO
var _remote_sequence := -1
var _remote_until := 0
var revision := 0
const REMOTE_HOLD_MS := 250
const REMOTE_ACTIONS := ["run", "use_tool", "attack", "dodge", "interact", "jump", "fly_toggle", "fly_descend", "light", "drink", "zoom_in", "zoom_out"]

func attach(body: Node) -> void:
	_body = weakref(body)
	_attached = true
	_local = bool(body.get("is_local"))
	clear()
	# A pad held before this body existed must not enter the singleton fallback.
	for device in Input.get_connected_joypads():
		if device != 0:
			_foreign_seen = true
	refresh_sources()

func bind_pad(device: int) -> void:
	_device = device if device >= 0 else -2
	clear()
	refresh_sources()

func bind_default() -> void:
	_device = -1
	clear()
	refresh_sources()

func detach() -> void:
	_attached = false
	clear()
	refresh_sources()

func clear() -> void:
	revision += 1
	# Aggregate singleton holds have no owner. Rebinding/detachment/locality
	# changes require their release before the default compatibility poll resumes.
	for action in InputMap.get_actions():
		if Input.get_action_raw_strength(action) > 0.0:
			_blocked_actions[action] = true
	_held.clear()
	_mouse_seen = false
	_remote_move = Vector2.ZERO
	_remote_actions.clear()
	_remote_aim = Vector2.ZERO
	_remote_until = 0
	var body := _owner()
	if body != null and body.get("controls") == self and body.has_method("_input_revoked"):
		body.call("_input_revoked")

func _owner() -> Node:
	return _body.get_ref() as Node if _body != null else null

## Godot clears its device state on unplug but dispatches no neutral raw events.
## The Node-owned listener is freed with the capture child, including replacements.
func joy_connection_changed(device: int, connected: bool) -> void:
	if connected or device != (_device if _device >= 0 else 0) or _device == -2:
		return
	revision += 1
	_foreign_seen = true # aggregate state cannot resurrect a revoked pad sample
	for action in _held:
		var entries: Dictionary = _held[action]
		for token in entries.keys():
			if token.begins_with("axis:") or token.begins_with("button:"):
				entries.erase(token)
	var body := _owner()
	if body != null and body.get("controls") == self and body.has_method("_input_revoked"):
		body.call("_input_revoked")

## Lowest live registered slot wins the entire overlapping source. Default and
## explicit pad 0 overlap; explicit nonzero devices are disjoint. No couch mode.
## Inspect only the four roster slots, without per-poll global group/array builds.
func _has_authority() -> bool:
	var body := _owner()
	if not is_instance_valid(body) or not _attached or not body.is_inside_tree() or body.is_queued_for_deletion() or body.get("controls") != self or not bool(body.get("is_local")) or _device == -2:
		return false
	var w := PlayerRegistry.world(body.get_tree())
	if w == null:
		return true
	if not "players" in w:
		return false
	for slot in mini(w.players.size(), PlayerRegistry.MAX_PLAYERS):
		var candidate: Variant = w.players[slot]
		if not is_instance_valid(candidate) or not candidate.is_inside_tree() or candidate.is_queued_for_deletion():
			continue
		if candidate == body:
			return StringName(str(body.get("player_id"))) == StringName("p%d" % slot)
		if bool(candidate.get("is_local")) and "controls" in candidate:
			var source: PlayerInput = candidate.get("controls")
			if source._attached and source._device != -2 and maxi(0, source._device) == maxi(0, _device):
				return false
	return false

func refresh_authority() -> bool:
	var active := _has_authority()
	if active != _authority:
		if not active and _attached and _owner() != null and bool(_owner().get("is_local")):
			_foreign_seen = true
		_authority = active
		clear()
		var body := _owner()
		if body != null and body.get("controls") == self and body.get("camera") != null:
			# Re-enable a returning owner without stealing another current camera.
			body.get("camera").enabled = active
	return active

## Binding/locality/attachment changes revoke losers synchronously, even if no
## input poll happens before the previous owner leaves again.
func refresh_sources() -> void:
	var body := _owner()
	var w := PlayerRegistry.world(body.get_tree()) if body != null and body.is_inside_tree() else null
	if w != null and "players" in w:
		for slot in mini(w.players.size(), PlayerRegistry.MAX_PLAYERS):
			var candidate: Variant = w.players[slot]
			if is_instance_valid(candidate) and "controls" in candidate:
				candidate.get("controls").refresh_authority()
	else:
		refresh_authority()

func local_active() -> bool:
	var body := _owner()
	if body == null or not _attached or not body.is_inside_tree() or body.is_queued_for_deletion():
		return false
	var now := bool(body.get("is_local"))
	if now != _local:
		_local = now
		clear()
		# On ownership changes old singleton-held edges cannot transfer owners.
		_foreign_seen = true
	return now and refresh_authority()

func accepts_event(event: InputEvent) -> bool:
	if event == null or not local_active():
		return false
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device == (_device if _device >= 0 else 0) and _device != -2
	if _device != -1:
		return false
	# Synthetic Action carries no physical identity. Legacy single-player only.
	if event is InputEventAction:
		return event.device == 0 and not _foreign_seen
	return event is InputEventKey or event is InputEventMouse or event is InputEventGesture

## Capture in _input, even when GUI consumes the press/release. Foreign pads only
## revoke the legacy programmatic Input.action_press fallback; never feed _held.
func handle_event(event: InputEvent) -> bool:
	if event == null:
		return false
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device != (_device if _device >= 0 else 0):
		_foreign_seen = true
	if not accepts_event(event):
		return false
	# Action is the legacy *discrete* test/automation route. Its held state is
	# owned by Input.action_press/release, not a physical device latch.
	if event is InputEventAction:
		return true
	if event is InputEventMouse:
		_mouse = event.position
		_mouse_seen = true
	for action in InputMap.get_actions():
		if not event.is_action(action):
			continue
		var token := _token(event)
		var entries: Dictionary = _held.get(action, {})
		entries[token] = _raw_strength(event, action)
		if entries[token] == 0.0:
			_blocked_actions.erase(action)
		_held[action] = entries
	return true

func _raw_strength(event: InputEvent, action: StringName) -> float:
	if event is InputEventJoypadMotion:
		for binding in InputMap.action_get_events(action):
			if binding is InputEventJoypadMotion and binding.axis == event.axis and signf(binding.axis_value) == signf(event.axis_value):
				return absf(event.axis_value)
		return 0.0
	return event.get_action_strength(action)

func _token(event: InputEvent) -> String:
	if event is InputEventJoypadMotion:
		return "axis:%d" % event.axis
	if event is InputEventJoypadButton:
		return "button:%d" % event.button_index
	if event is InputEventKey:
		return "key:%d" % (event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	return "action"

func action_strength(action: StringName) -> float:
	return _strength(action, false)

func action_raw_strength(action: StringName) -> float:
	return _strength(action, true)

func _strength(action: StringName, raw: bool) -> float:
	if not local_active():
		return float(_remote_actions.get(action, false)) if _remote_current() else 0.0
	var value := 0.0
	var entries: Dictionary = _held.get(action, {})
	for token in entries:
		var strength := float(entries[token])
		if not raw and token.begins_with("axis:"):
			var deadzone := InputMap.action_get_deadzone(action)
			strength = 0.0 if strength <= deadzone else (strength - deadzone) / (1.0 - deadzone)
		value = maxf(value, strength)
	# Preserve the existing single-player programmatic hold contract. Once ANY
	# foreign pad is observed, global action state is unusable for device routing.
	if _device == -1 and not _foreign_seen:
		var aggregate := Input.get_action_raw_strength(action)
		if aggregate == 0.0:
			_blocked_actions.erase(action)
		if not _blocked_actions.has(action):
			value = maxf(value, aggregate if raw else Input.get_action_strength(action))
	return value

func is_action_pressed(action: StringName) -> bool:
	if action == &"fly_descend" and hotbar_modifier():
		return false
	return action_raw_strength(action) > InputMap.action_get_deadzone(action)

func is_action_released(action: StringName) -> bool:
	return not is_action_pressed(action)

func move_vector() -> Vector2:
	if not local_active():
		return _remote_move if _remote_current() else Vector2.ZERO
	var v := Vector2(action_raw_strength(&"move_right") - action_raw_strength(&"move_left"), action_raw_strength(&"move_back") - action_raw_strength(&"move_forward"))
	var deadzone := (InputMap.action_get_deadzone(&"move_left") + InputMap.action_get_deadzone(&"move_right") + InputMap.action_get_deadzone(&"move_forward") + InputMap.action_get_deadzone(&"move_back")) / 4.0
	var length := v.length()
	return Vector2.ZERO if length <= deadzone else v.normalized() * minf(1.0, (length - deadzone) / (1.0 - deadzone))

func aim_position(world: Node2D) -> Vector2:
	if not local_active():
		return _remote_aim if _remote_current() else Vector2.ZERO
	var screen: Vector2 = _owner().get("_cursor_screen") if "_cursor_screen" in _owner() else _mouse
	return world.get_canvas_transform().affine_inverse() * screen

## Captured mouse events remain fresh over a pausing modal. The native viewport
## may still report its pre-modal pointer for an injected or GUI-consumed event.
func pointer_position(viewport: Viewport) -> Vector2:
	if not local_active() or _device != -1:
		return Vector2.ZERO
	return _mouse if _mouse_seen else viewport.get_mouse_position()

## LB is a modifier, never a world action. Hold LB FIRST, optionally RB for the
## second bank; up/right/down/left selects slots 1..4 or 5..8. Bare left/right
## retains cycling. RB alone retains drink; LB+RB never drinks.
func hotbar_modifier() -> bool:
	return local_active() and float(_held.get(&"ui_page_up", {}).get("button:%d" % JOY_BUTTON_LEFT_SHOULDER, 0.0)) > 0.5

func hotbar_slot(event: InputEvent) -> int:
	if not accepts_event(event) or not hotbar_modifier() or not event is InputEventJoypadButton or not event.pressed:
		return -1
	var index := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT].find(event.button_index)
	var second := float(_held.get(&"ui_page_down", {}).get("button:%d" % JOY_BUTTON_RIGHT_SHOULDER, 0.0)) > 0.5
	return index + (4 if second else 0) if index >= 0 else -1

## Latest-only, copied, short-lived OFFLINE sample. Deliberately no RPC/peer or
## world-write entry here. MP6 must validate sender, range, inventory, cooldown,
## replay and world authority before ever applying a consequential intent.
func submit_remote_frame(frame: Variant) -> bool:
	if local_active() or not _attached or _owner() == null or bool(_owner().get("is_local")) or PlayerRegistry.registered_id(_owner()) == &"":
		return false
	if typeof(frame) != TYPE_DICTIONARY or frame.size() != 4:
		return false
	for key in frame:
		if typeof(key) != TYPE_STRING or key not in ["sequence", "move", "aim", "actions"]:
			return false
	var sequence: Variant = frame.get("sequence")
	if typeof(sequence) != TYPE_INT or sequence < 0 or sequence > 2147483647 or sequence <= _remote_sequence:
		return false
	if not _valid_pair(frame.get("move"), 1.0) or not _valid_pair(frame.get("aim"), 10000000.0):
		return false
	var actions: Variant = frame.get("actions")
	if typeof(actions) != TYPE_DICTIONARY or actions.size() > REMOTE_ACTIONS.size():
		return false
	var copied := {}
	for action in actions:
		if typeof(action) != TYPE_STRING or action not in REMOTE_ACTIONS or typeof(actions[action]) != TYPE_BOOL:
			return false
		copied[StringName(action)] = actions[action]
	_remote_sequence = sequence
	_remote_move = Vector2(frame.move[0], frame.move[1]).limit_length()
	_remote_aim = Vector2(frame.aim[0], frame.aim[1])
	_remote_actions = copied
	_remote_until = Time.get_ticks_msec() + REMOTE_HOLD_MS
	return true

func _valid_pair(value: Variant, bound: float) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return false
	for scalar in value:
		if typeof(scalar) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not is_finite(float(scalar)) or absf(float(scalar)) > bound:
			return false
	return true

func _remote_current() -> bool:
	var body := _owner()
	return _attached and body != null and body.is_inside_tree() and not body.is_queued_for_deletion() and not bool(body.get("is_local")) and PlayerRegistry.registered_id(body) != &"" and Time.get_ticks_msec() < _remote_until

func consume_if_handled(handled: bool = true) -> void:
	if handled and local_active():
		_owner().get_viewport().set_input_as_handled()
