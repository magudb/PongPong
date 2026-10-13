extends "res://tests/lib/asserts.gd"
## Driving helpers of the `t` object: time (frames / physics / seconds / until), input (tap / hold / press),
## node lookup and autoload access. Second layer of asserts -> drive -> flow -> t.
##
## Rules this layer keeps for every section author:
##  * Autoloads are reached with t.autoload("Name") (root.get_node). Never reference an autoload by its global
##    name in a section: sections compile while other packages' autoloads may not exist yet.
##  * Physics-driven asserts (CharacterBody2D movement, areas, collisions) need `await t.physics(n)`;
##    several process frames can pass inside one physics tick, so t.frames() is NOT enough for them.
##  * t.tap(action) sends a press+release InputEventAction pair in the same frame (event handlers see both,
##    Input.is_action_just_pressed() polling does not). Use `await t.tap_held(action)` for polling code.

## The SceneTree the harness runs in and its root window (set by bind()).
var tree: SceneTree
var root: Window
## Hero the run was started with: "animal" | "fairy" | "hobbit" (--character=).
var character: String = "animal"
## True in --windowed runs (real window, run_windowed sections).
var windowed: bool = false
## Directory screenshots are written to (--out=DIR); "" = none requested.
var out_dir: String = ""
## Throwaway user dir of the run (user://), see tests/run_playtest.sh.
var user_dir: String = ""
## Deterministic RNG for tests (seeded from --seed=, default 424242).
var rng := RandomNumberGenerator.new()
## The Logger capture (tests/lib/error_catcher.gd), set by the harness (untyped: duck-typed, loaded at runtime).
var catcher

var _held: Dictionary = {}     # action -> true while held through t.hold()


func bind(p_tree: SceneTree) -> void:
	tree = p_tree
	root = p_tree.root


# ---------------------------------------------------------------- autoloads and nodes

## Autoload node by name ("GameManager"). Records a failure and returns null when it does not exist.
func autoload(autoload_name: String) -> Node:
	var n := tree.root.get_node_or_null(NodePath(autoload_name))
	if n == null:
		fail("autoload %s does not exist (not registered yet?)" % autoload_name)
	return n


func has_autoload(autoload_name: String) -> bool:
	return tree.root.get_node_or_null(NodePath(autoload_name)) != null


## Node in the current scene: "%UniqueName", a relative path, or (fallback) a name found anywhere under root.
## Returns null when nothing matches (no error is logged, use press()/set_text() for checked access).
func node(path: String) -> Node:
	var cs := tree.current_scene
	if cs != null:
		var n := cs.get_node_or_null(path)
		if n != null:
			return n
	if path.begins_with("%"):
		return tree.root.find_child(path.substr(1), true, false)
	return tree.root.get_node_or_null(path)


## First node of a group (e.g. t.first("player")); null when the group is empty.
func first(group: StringName) -> Node:
	return tree.get_first_node_in_group(group)


## The player node (group "player"); null before the world is up.
func player() -> Node:
	return tree.get_first_node_in_group(&"player")


# ---------------------------------------------------------------- time

## `n` process frames.
func frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## `n` physics ticks. Required before asserting anything driven by _physics_process.
func physics(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Game seconds (Engine.time_scale applies; the timer keeps running while the tree is paused).
func seconds(s: float) -> void:
	await tree.create_timer(s, true, false, false).timeout


## Wall-clock seconds (Engine.time_scale does not apply).
func real_seconds(s: float) -> void:
	await tree.create_timer(s, true, false, true).timeout


## Polls `cond` once per process frame until it returns true or `timeout` real seconds pass. Returns whether it became true.
func until(cond: Callable, timeout: float = 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if float(Time.get_ticks_msec() - t0) / 1000.0 > timeout:
			return false
		await tree.process_frame
	return true


## Waits for `sig` to fire (e.g. t.autoload("EventBus").day_started) for at most `timeout` seconds.
## Returns the emitted arguments as an Array ([] for a signal without arguments) or null on timeout.
func wait_signal(sig: Signal, timeout: float = 5.0) -> Variant:
	var arity := 0
	var source := sig.get_object()
	if source != null:
		for info in source.get_signal_list():
			if info["name"] == sig.get_name():
				arity = (info["args"] as Array).size()
				break
	var box := {"fired": false, "args": []}
	var cb := func(a1 = null, a2 = null, a3 = null, a4 = null, a5 = null, a6 = null, a7 = null, a8 = null) -> void:
		box["args"] = [a1, a2, a3, a4, a5, a6, a7, a8].slice(0, arity)
		box["fired"] = true
	sig.connect(cb, CONNECT_ONE_SHOT)
	var ok := await until(func() -> bool: return box["fired"], timeout)
	if not ok and sig.is_connected(cb):
		sig.disconnect(cb)
	return box["args"] if ok else null


## Number of nodes in a group.
func count_group(group: StringName) -> int:
	return tree.get_nodes_in_group(group).size()


# ---------------------------------------------------------------- input

## One InputEventAction press + release pair (same frame). Unknown actions are a failure, not a silent no-op.
func tap(action: StringName) -> void:
	if not InputMap.has_action(action):
		fail("tap(%s): no such input action" % action)
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## Press, wait `n` frames (default 2), release. For code that polls Input.is_action_just_pressed().
func tap_held(action: StringName, n: int = 2) -> void:
	if not InputMap.has_action(action):
		fail("tap_held(%s): no such input action" % action)
		return
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)


## Keep an action pressed until release() / release_all() (movement).
func hold(action: StringName, strength: float = 1.0) -> void:
	if not InputMap.has_action(action):
		fail("hold(%s): no such input action" % action)
		return
	_held[action] = true
	Input.action_press(action, strength)


func release(action: StringName) -> void:
	_held.erase(action)
	if InputMap.has_action(action):
		Input.action_release(action)


## Releases every action that t.hold() pressed (the harness also calls this between sections).
func release_all() -> void:
	for a in _held.keys():
		if InputMap.has_action(a):
			Input.action_release(a)
	_held.clear()


## One key press + release (InputEventKey pair), for UI code that looks at key events instead of actions.
func tap_key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)


## Moves the mouse to a position of the root viewport (hover effects, tooltips, focus). Mouse events are pushed
## straight into the root viewport (Viewport.push_input), so they reach the GUI in headless runs too; the
## Input singleton's mouse state (Input.is_mouse_button_pressed ...) is not updated by them.
func move_mouse(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	tree.root.push_input(ev)


## A real click at a viewport position: motion, press, release (GUI hit-testing, focus and `pressed` all behave as
## for a user). Await a frame afterwards before asserting.
func click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	move_mouse(pos)
	var down := InputEventMouseButton.new()
	down.position = pos
	down.global_position = pos
	down.button_index = button
	down.pressed = true
	down.button_mask = 1 << (button - 1)
	tree.root.push_input(down)
	var up := InputEventMouseButton.new()
	up.position = pos
	up.global_position = pos
	up.button_index = button
	up.pressed = false
	tree.root.push_input(up)


## What a click on a button does: toggle buttons flip, then `pressed` fires. Fails when the node is missing,
## is not a button, or is disabled (a real click would do nothing). `tolerate_disabled` turns the disabled case
## into a quiet no-op (the legacy select screen disables the race button that is already selected).
func press(path: String, tolerate_disabled: bool = false) -> bool:
	var n := node(path)
	if not (n is BaseButton):
		fail("button %s not found in %s" % [path, scene_name()])
		return false
	var b := n as BaseButton
	if b.disabled:
		if tolerate_disabled:
			return true
		fail("button %s is disabled" % path)
		return false
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	b.pressed.emit()
	return true


## Types into a LineEdit / TextEdit (fires text_changed like typing does).
func set_text(path: String, text: String) -> bool:
	var n := node(path)
	if n is LineEdit:
		(n as LineEdit).text = text
		(n as LineEdit).text_changed.emit(text)
		return true
	if n is TextEdit:
		(n as TextEdit).text = text
		(n as TextEdit).text_changed.emit()
		return true
	fail("text field %s not found in %s" % [path, scene_name()])
	return false


# ---------------------------------------------------------------- scene info (also used by the flow layer)

func scene_name() -> String:
	return tree.current_scene.name if tree.current_scene != null else "<none>"


func scene_path() -> String:
	return tree.current_scene.scene_file_path if tree.current_scene != null else ""
