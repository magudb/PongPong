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
##  * t.press(path) is a real click on the button's centre: it fails when the button is hidden, disabled, outside the window
##    or covered by another control. t.press_unchecked(path) only emits `pressed` (for the few cases that need that).
##  * State a section changes for its own checks (a locale, a config override, a fixture path) is put back with
##    t.on_cleanup(func): the harness runs those after the section, also when a script error or a timeout ended it early.

## The SceneTree the harness runs in and its root window (set by bind()).
var tree: SceneTree
var root: Window
## Hero the run was started with: "animal" | "fairy" | "hobbit" | "ghost" (--character=).
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

## Set by the harness when the section that holds this `t` timed out (tests/playtest.gd): a coroutine cannot be cancelled in
## GDScript, so from then on every wait helper of this `t` parks the stuck section for good instead of returning, and it cannot
## run on into the sections after it. The harness hands the next sections a fresh `t`.
var detached: bool = false

var _held: Dictionary = {}     # action -> true while held through t.hold()
var _cleanups: Array[Callable] = []

## Never emitted: what a detached `t` parks its section on.
signal _parked


func bind(p_tree: SceneTree) -> void:
	tree = p_tree
	root = p_tree.root


## Registers `fn` (a Callable without arguments; it may await) to run when the current section ends, after its last check, also
## when a script error or a timeout ended it early. Cleanups run last-registered first, and only once.
##   var before: String = t.autoload("LocalizationManager").current_locale
##   t.on_cleanup(func() -> void: t.autoload("LocalizationManager").set_locale(before, false))
func on_cleanup(fn: Callable) -> void:
	_cleanups.append(fn)


## Runs and forgets the cleanups of the section (called by the harness). Returns how many ran.
func run_cleanups() -> int:
	var n := 0
	while not _cleanups.is_empty():
		var fn: Callable = _cleanups.pop_back()
		if fn.is_valid():
			await fn.call()
			n += 1
	return n


func _park_if_detached() -> void:
	if detached:
		await _parked


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
	await _park_if_detached()
	for i in n:
		await tree.process_frame
		await _park_if_detached()


## `n` physics ticks. Required before asserting anything driven by _physics_process.
func physics(n: int) -> void:
	await _park_if_detached()
	for i in n:
		await tree.physics_frame
		await _park_if_detached()


## Game seconds (Engine.time_scale applies; the timer keeps running while the tree is paused).
func seconds(s: float) -> void:
	await _park_if_detached()
	await tree.create_timer(s, true, false, false).timeout
	await _park_if_detached()


## Game time in seconds since the engine started: physics ticks / ticks per second, the clock the game animates by. Measure a duration with this, not with
## Time.get_ticks_msec(): the result is the same in a normal run and under `run_playtest.sh --fast` (--fixed-fps 60), where the wall clock runs far behind.
func game_seconds() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


## Seconds of unscaled frame time (Engine.time_scale does not apply). That is the wall clock in a normal run; under `run_playtest.sh --fast` (--fixed-fps 60)
## every frame counts 1/60 s whatever it costs, so the wait runs ahead of the wall clock like everything else the engine animates. A wait for something
## outside the engine loop (a thread, a child process) is `until(cond, timeout)`, which counts the wall clock.
func real_seconds(s: float) -> void:
	await _park_if_detached()
	await tree.create_timer(s, true, false, true).timeout
	await _park_if_detached()


## Polls `cond` once per process frame until it returns true or `timeout` WALL-CLOCK seconds pass (also under --fast). Returns whether it became true.
func until(cond: Callable, timeout: float = 5.0) -> bool:
	await _park_if_detached()
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if float(Time.get_ticks_msec() - t0) / 1000.0 > timeout:
			return false
		await tree.process_frame
		await _park_if_detached()
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


## A real click on a button, with the checks a player's click implies: fails when the node is missing, is not a button, is
## disabled, is hidden (not visible in the tree), has its centre outside the window, or is covered there by another control
## (the click went elsewhere: the failure names what is on top). Toggle buttons flip and `pressed` fires as for a user, through
## the GUI (focus and hover move as well); the mouse is parked outside the window afterwards. `tolerate_disabled` turns the
## disabled case into a quiet no-op (the legacy select screen disables the race button that is already selected). A button that
## does not react to a click a player can make (a pressed member of a ButtonGroup) passes: it was reached, which is the check.
func press(path: String, tolerate_disabled: bool = false) -> bool:
	var n := node(path)
	if not (n is BaseButton):
		fail("button %s not found in %s" % [path, scene_name()])
		return false
	return press_button(n as BaseButton, path, tolerate_disabled)


## press() for a button node already at hand (a choice row, a dialog's own button). `label` names it in a failure.
func press_button(b: BaseButton, label: String = "", tolerate_disabled: bool = false) -> bool:
	var what := label if label != "" else str(b.get_path())
	if b.disabled:
		if tolerate_disabled:
			return true
		fail("button %s is disabled" % what)
		return false
	if not b.is_visible_in_tree():
		fail("button %s is hidden: a player cannot click it (t.press_unchecked() emits pressed without the checks)" % what)
		return false
	var pos := button_center(b)
	if not Rect2(Vector2.ZERO, Vector2(root.size)).has_point(pos):
		fail("button %s is outside the window (centre %s, window %s)" % [what, pos, root.size])
		return false
	var reached := [false]
	var probe := func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			reached[0] = true
	b.gui_input.connect(probe)
	click(pos)
	var on_top := root.gui_get_hovered_control()
	if is_instance_valid(b) and b.gui_input.is_connected(probe):
		b.gui_input.disconnect(probe)
	move_mouse(Vector2(-16, -16))
	if not reached[0]:
		fail("button %s did not get the click at %s: %s is on top of it" % [what, pos, str(on_top.get_path()) if on_top != null else "nothing that takes the mouse"])
		return false
	return true


## Emits `pressed` (toggle buttons flip first) without any of the checks of press(): no visibility, hit test or window bounds.
## Only for a button that a player reaches some other way in the state under test (say so in a comment at the call).
func press_unchecked(path: String, tolerate_disabled: bool = false) -> bool:
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


## The centre of a control in root viewport coordinates (what click() takes), through CanvasLayers and the canvas transform.
func button_center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


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
