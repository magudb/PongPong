class_name UiNavWatcher
extends Node
## The one hidden node under the root that UiNav.watcher() creates on first use (UI_NAVIGATION.md 4.1).
##
## It does three jobs and nothing else:
##  * tracks the LAST REAL input device (a key, a mouse button or a real mouse movement = `keyboard`; a pad button or a stick pushed
##    past 0.5 = `gamepad`; an InputEventAction is synthetic and never counts) and announces a change with `device_changed`, so key hints
##    (UiHints / HintBar / PromptPill) flip between "E" and "A"; the name of the last pad picks its button labels (`pad_name`);
##  * forwards focus moves and the accept / cancel presses as signals (P24 may play a sound from them);
##  * the echo guard of the rings (3.4): a held arrow key repeats (echo events) and Godot's focus navigation does not wrap on a fresh press
##    only, so an echo `ui_up/down/left/right` that would leave the control at a ring end the WRAPPING way is swallowed here. wire_ring /
##    wire_row / wire_grid / wire_groups mark such controls with the meta `tt_wrap_<dir>`.
##
## The device is read from the events that reach `_input` AND from the window's `window_input` signal: an event that another node marks as
## handled in its `_input` (a screen closing on Esc) never reaches this node's `_input`, but `window_input` is emitted before any of them.

signal device_changed(device: StringName)
signal focus_moved(control: Control)
signal accepted(control: Control)
signal cancelled()

const KEYBOARD := &"keyboard"
const GAMEPAD := &"gamepad"
## a stick has to be pushed this far to count as the player using it (drift and noise stay below)
const STICK_THRESHOLD := 0.5
## a mouse movement shorter than this (in design pixels) is jitter, not the player reaching for the mouse
const MOUSE_MOVE_MIN := 2.0
const WRAP_META := {&"ui_up": &"tt_wrap_up", &"ui_down": &"tt_wrap_down", &"ui_left": &"tt_wrap_left", &"ui_right": &"tt_wrap_right"}

var device: StringName = KEYBOARD
## The SDL name of the pad that was used last ("" before any): UiHints.pad_family() picks the button labels from it.
var pad_name: String = ""


func _init() -> void:
	name = "UiNavWatcher"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var vp := get_viewport()
	if vp != null and not vp.gui_focus_changed.is_connected(_on_focus_changed):
		vp.gui_focus_changed.connect(_on_focus_changed)
	var win := get_window()
	if win != null and not win.window_input.is_connected(_on_window_input):
		win.window_input.connect(_on_window_input)


func _on_window_input(event: InputEvent) -> void:
	_track_device(event)


func _on_focus_changed(node: Control) -> void:
	focus_moved.emit(node)


func _input(event: InputEvent) -> void:
	_track_device(event)
	if event is InputEventKey and (event as InputEventKey).echo:
		_echo_guard(event)
	if event.is_action_pressed(&"ui_accept"):
		accepted.emit(get_viewport().gui_get_focus_owner())
	elif event.is_action_pressed(&"ui_cancel"):
		cancelled.emit()


## Records the device behind an event; emits device_changed when it differs from the last one.
func _track_device(event: InputEvent) -> void:
	var now: StringName = &""
	if event is InputEventKey:
		if (event as InputEventKey).pressed:
			now = KEYBOARD
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			now = KEYBOARD
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() >= MOUSE_MOVE_MIN:
			now = KEYBOARD
	elif event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			now = GAMEPAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= STICK_THRESHOLD:
			now = GAMEPAD
	# Another pad family (a DualSense after an Xbox pad) relabels the hints just like a device change.
	var renamed := false
	if now == GAMEPAD and Input.get_joy_name(event.device) != pad_name:
		pad_name = Input.get_joy_name(event.device)
		renamed = true
	if now != &"" and (now != device or renamed):
		device = now
		device_changed.emit(device)


## An echo press of a ui_* direction at a ring end that WRAPS stops there (a fresh press wraps).
func _echo_guard(event: InputEvent) -> void:
	var vp := get_viewport()
	var owner_ := vp.gui_get_focus_owner() if vp != null else null
	if owner_ == null:
		return
	for action in WRAP_META:
		if event.is_action(action) and bool(owner_.get_meta(WRAP_META[action], false)):
			vp.set_input_as_handled()
			return
