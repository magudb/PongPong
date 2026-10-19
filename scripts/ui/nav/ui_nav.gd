class_name UiNav
extends RefCounted
## Navigation helpers of every game screen (UI_NAVIGATION.md 4.1, written once so the screen owners do not re-implement the rules of
## section 3). Static API; a hidden UiNavWatcher node under the root is created on first use (device tracking, the echo guard of rings).
##
## What the helpers do and do not do:
##  * `wire_*` only set `focus_neighbor_*` and `focus_next / focus_previous` (and mark the edge controls with meta, see below). They never
##    connect to anything except the focus-memory signal of `wire_groups` and the hover signal of `hover_focus`. They need the controls to
##    be IN THE TREE (call them from `_ready` or after the screen is built); a control that is not in the tree is skipped.
##  * Neighbours point at controls, and Godot skips a neighbour that is hidden or FOCUS_NONE by following that control's own neighbour, but
##    only a few hops deep: call `wire_*` again after a row becomes enabled / disabled or a list is rebuilt (the wiring is idempotent).
##  * Cross-axis directions of a list / row are CONSUMED (they point at the control itself); a screen that lets a direction cross into
##    another group says so with `link()` AFTER the `wire_*` call (or lets `wire_groups` do it).
##  * Metas on the edge controls (read by wire_groups and by the echo guard of UiNavWatcher / TTScreen): `tt_edge_<dir>` (this control is at
##    the edge of its group in that direction) and `tt_wrap_<dir>` (a fresh press there wraps to the other end; an echo press does not).
##
## Pattern letters in the comments are the ones of the pattern table in UI_NAVIGATION.md 3.4 (L list, T tab / chip row, G grid, H hover).

const UP := &"up"
const DOWN := &"down"
const LEFT := &"left"
const RIGHT := &"right"
const KEYBOARD := &"keyboard"
const GAMEPAD := &"gamepad"
const SIDES := {&"up": SIDE_TOP, &"down": SIDE_BOTTOM, &"left": SIDE_LEFT, &"right": SIDE_RIGHT}
const WASD_MAP := {&"move_forward": &"ui_up", &"move_back": &"ui_down", &"move_left": &"ui_left", &"move_right": &"ui_right"}
## Meta on the ButtonGroup of a tab row whose tabs select on focus (pattern T): wire_groups enters such a row on its pressed tab (the
## CURRENT tab, UI_NAVIGATION.md 3.4), so leaving a list upwards or wrapping out of the footer never switches back to the first tab.
const TAB_ROW_META := &"tt_tab_row"

## scene-level opener memory (title -> select -> title): key -> node name
static var _remembered: Dictionary = {}
## the frame in which swallow() was last called (-1 = never)
static var _swallow_frame := -1
static var _watcher: Node = null


# ----------------------------------------------------------------------------------------------------------------- device and watcher

## The hidden watcher node (created on first use, a child of the root; the node enters the tree on the next idle step, so the first
## events after the very first call may be missed: callers that need the device early call watcher() in their own `_ready`).
static func watcher() -> Node:
	if _watcher != null and is_instance_valid(_watcher):
		return _watcher
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var existing := tree.root.get_node_or_null("UiNavWatcher")
	if existing != null:
		_watcher = existing
		return existing
	var w := UiNavWatcher.new()
	tree.root.add_child.call_deferred(w)
	_watcher = w
	return w


## &"keyboard" (also the mouse) or &"gamepad": the last REAL input device.
static func device() -> StringName:
	var w := watcher()
	return StringName(w.get("device")) if w != null else KEYBOARD


# ----------------------------------------------------------------------------------------------------------------- focus basics

static func _root() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


static func _vp(vp: Viewport = null) -> Viewport:
	return vp if vp != null else _root()


## True while a LineEdit / TextEdit that accepts text owns the keyboard focus: no hotkey of any screen acts then (3.6).
static func text_field_focused(vp: Viewport = null) -> bool:
	var v := _vp(vp)
	if v == null:
		return false
	var owner_ := v.gui_get_focus_owner()
	if owner_ is LineEdit:
		return (owner_ as LineEdit).editable
	if owner_ is TextEdit:
		return (owner_ as TextEdit).editable
	return false


## Leaves NO focus owner, so Space / Enter / the arrows act on the world again (a modal opened from the world gives focus back like this).
static func release_world_focus() -> void:
	var v := _vp()
	if v != null:
		v.gui_release_focus()


## Disabled controls are also non-focusable (Godot lets focus land on a disabled Button, F5).
static func set_enabled(c: Control, on: bool) -> void:
	if c == null or not is_instance_valid(c):
		return
	if c is BaseButton:
		(c as BaseButton).disabled = not on
	elif c is LineEdit:
		(c as LineEdit).editable = on
	elif c is TextEdit:
		(c as TextEdit).editable = on
	elif c is Slider:
		(c as Slider).editable = on
	c.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	if not on and c.is_inside_tree() and c.has_focus():
		c.release_focus()


## Can the keyboard land on this control right now (own visibility only: an ancestor may be hidden while the screen is still closed)?
static func is_stop(c: Variant) -> bool:
	if c == null or not is_instance_valid(c) or not (c is Control):
		return false
	var ctrl := c as Control
	if not ctrl.visible or ctrl.focus_mode != Control.FOCUS_ALL:
		return false
	if ctrl is BaseButton and (ctrl as BaseButton).disabled:
		return false
	return true


## The first control of `items` that is a focus stop (null when none is).
static func first_enabled(items: Array) -> Control:
	for c in items:
		if is_stop(c):
			return c as Control
	return null


static func _stops(items: Array) -> Array[Control]:
	var out: Array[Control] = []
	for c in items:
		if is_stop(c) and (c as Control).is_inside_tree():
			out.append(c as Control)
	return out


# ----------------------------------------------------------------------------------------------------------------- neighbours

## One focus neighbour: `dir` is up | down | left | right. Both controls must be in the tree.
static func link(a: Control, dir: StringName, b: Control) -> void:
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b) or not a.is_inside_tree() or not b.is_inside_tree():
		return
	var path := a.get_path_to(b)
	match dir:
		UP:
			a.focus_neighbor_top = path
		DOWN:
			a.focus_neighbor_bottom = path
		LEFT:
			a.focus_neighbor_left = path
		RIGHT:
			a.focus_neighbor_right = path


static func _clear_edge_metas(c: Control) -> void:
	for d in [UP, DOWN, LEFT, RIGHT]:
		c.remove_meta(StringName("tt_edge_%s" % d))
		c.remove_meta(StringName("tt_wrap_%s" % d))


static func _mark(c: Control, dir: StringName, edge: bool, wraps: bool) -> void:
	if edge:
		c.set_meta(StringName("tt_edge_%s" % dir), true)
	if wraps:
		c.set_meta(StringName("tt_wrap_%s" % dir), true)


## Pattern L (axis v) or T (axis h): neighbours along the axis, wrapping at the ends when `wrap` (a fresh press wraps, an echo press does not),
## the cross axis consumed; Tab / Shift+Tab follow the same order.
static func wire_ring(items: Array, axis: StringName = &"v", wrap := true) -> void:
	var list := _stops(items)
	var n := list.size()
	if n == 0:
		return
	var vertical := axis != &"h"
	var prev_dir: StringName = UP if vertical else LEFT
	var next_dir: StringName = DOWN if vertical else RIGHT
	var cross_a: StringName = LEFT if vertical else UP
	var cross_b: StringName = RIGHT if vertical else DOWN
	for i in n:
		var c := list[i]
		_clear_edge_metas(c)
		var prev := list[(i - 1 + n) % n] if (i > 0 or wrap) else c
		var next := list[(i + 1) % n] if (i < n - 1 or wrap) else c
		link(c, prev_dir, prev)
		link(c, next_dir, next)
		link(c, cross_a, c)
		link(c, cross_b, c)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(next)
		_mark(c, cross_a, true, false)
		_mark(c, cross_b, true, false)
		_mark(c, prev_dir, i == 0, wrap and i == 0)
		_mark(c, next_dir, i == n - 1, wrap and i == n - 1)


## Pattern T horizontal (tabs, chips, radio groups): wire_ring along the horizontal axis. Moving onto a member SELECTS it (a screen
## connects `focus_entered` for that, or uses the radio helpers of its own); that is the screen's business, not a neighbour's.
static func wire_row(items: Array, wrap := true) -> void:
	wire_ring(items, &"h", wrap)


## Pattern G: `cells` row-major in `cols` columns. Left / Right stay in the row (wrapping to the other end of THE SAME ROW when `wrap_h`),
## Up / Down keep the column and are clamped to the last existing cell of a short last row; past the top / bottom row they wrap to the other
## end (a lone grid has no dead end; wire_groups turns those edges into group crossings).
static func wire_grid(cells: Array, cols: int, wrap_h := true) -> void:
	var list := _stops(cells)
	var n := list.size()
	if n == 0 or cols < 1:
		return
	var rows := int(ceil(float(n) / float(cols)))
	for i in n:
		var c := list[i]
		_clear_edge_metas(c)
		@warning_ignore("integer_division")
		var r := i / cols
		var col := i % cols
		var row_len := mini(cols, n - r * cols)
		var left_i := i - 1 if col > 0 else (i + row_len - 1 if wrap_h else i)
		var right_i := i + 1 if col < row_len - 1 else (r * cols if wrap_h else i)
		var up_i := (r - 1) * cols + col if r > 0 else mini((rows - 1) * cols + col, n - 1)
		var down_i := mini((r + 1) * cols + col, n - 1) if r < rows - 1 else col
		link(c, LEFT, list[left_i])
		link(c, RIGHT, list[right_i])
		link(c, UP, list[up_i])
		link(c, DOWN, list[down_i])
		var next_i := (i + 1) % n
		var prev_i := (i - 1 + n) % n
		c.focus_next = c.get_path_to(list[next_i])
		c.focus_previous = c.get_path_to(list[prev_i])
		_mark(c, LEFT, col == 0, wrap_h and col == 0)
		_mark(c, RIGHT, col == row_len - 1, wrap_h and col == row_len - 1)
		_mark(c, UP, r == 0, r == 0 and rows > 1)
		_mark(c, DOWN, r == rows - 1, r == rows - 1 and rows > 1)


## Links the groups of a screen (each group an Array of Controls already wired with wire_ring / wire_row / wire_grid) into one ring:
## Down / Up past the edge of a group LEAVES to the next / previous group and lands on that group's focus memory (the member that had focus
## last, else the current tab of a TAB_ROW_META row, else its first stop); from the last group it wraps to the first when `ring` (a fresh press wraps, an echo press does not).
## Tab / Shift+Tab walk the groups in order. Left / Right crossings between groups are declared with link(). Calling it again with the
## same (or rebuilt) groups replaces the old wiring.
static func wire_groups(groups: Array, ring := true, remember_focus := true) -> void:
	var nav := _GroupNav.new()
	nav.ring = ring
	nav.remember_focus = remember_focus
	for g in groups:
		var members: Array[Control] = []
		for c in (g as Array):
			if c is Control and is_instance_valid(c):
				members.append(c as Control)
		if not members.is_empty():
			nav.groups.append(members)
	nav.attach()
	nav.relink()


## Pattern H: moving the mouse onto one of these list-like rows moves keyboard focus there (never for cards, chips, tabs, text fields,
## sliders: the caller passes only rows). The gold row the player sees is then always the focused one.
static func hover_focus(items: Array) -> void:
	for c in items:
		if c is Control and is_instance_valid(c) and not bool((c as Control).get_meta(&"tt_hover_focus", false)):
			(c as Control).set_meta(&"tt_hover_focus", true)
			(c as Control).mouse_entered.connect(_on_hover.bind(c as Control))


static func _on_hover(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree() or not c.is_visible_in_tree():
		return
	if c.focus_mode != Control.FOCUS_ALL or (c is BaseButton and (c as BaseButton).disabled):
		return
	if not c.has_focus():
		c.grab_focus()


## F7: a single-line LineEdit eats the Up / Down KEYS; with this the keys leave the field for the control its `focus_neighbor_top /
## bottom` names (or the geometric neighbour), like the D-pad and the stick already do. Covers the LineEdits under `root` right now.
static func yield_updown_from_fields(root: Node) -> void:
	for n in root.find_children("*", "LineEdit", true, false):
		var le := n as LineEdit
		if bool(le.get_meta(&"tt_yield_updown", false)):
			continue
		le.set_meta(&"tt_yield_updown", true)
		le.gui_input.connect(_on_field_gui_input.bind(le))


static func _on_field_gui_input(event: InputEvent, le: LineEdit) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var side := -1
	if event.is_action(&"ui_up"):
		side = SIDE_TOP
	elif event.is_action(&"ui_down"):
		side = SIDE_BOTTOM
	if side < 0:
		return
	var next := le.find_valid_focus_neighbor(side as Side)
	if next != null and next != le:
		next.grab_focus()
		le.accept_event()


# ----------------------------------------------------------------------------------------------------------------- WASD

## W / A / S / D as the arrows inside `root` (a title, a select page, a modal): a physical W / A / S / D press becomes the matching ui_* action
## event, the original is handled; never in a text field, never while a modal that is not `root` is on top, never when `root` is hidden.
## (A TTScreen does the same by itself in its `_input`; this is for scenes that are not a TTScreen.)
static func wasd_as_arrows(root: Node) -> void:
	if root == null or root.get_node_or_null("UiNavWasd") != null:
		return
	var hook := _WasdHook.new()
	hook.name = "UiNavWasd"
	hook.target = root
	root.add_child(hook)


## Translates one W / A / S / D key press of `event` (see wasd_as_arrows); true when the event was consumed. Echo presses translate too (a held key
## scrolls a list), except the ones that would cross a WRAPPING ring edge: those are swallowed (no wrap on echo).
static func wasd_translate(vp: Viewport, event: InputEvent) -> bool:
	if vp == null or not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or text_field_focused(vp):
		return false
	for move in WASD_MAP:
		var ui: StringName = WASD_MAP[move]
		if key.is_action(move) and not key.is_action(ui):                 # W A S D (the arrows are move_* AND ui_*: they navigate by themselves)
			if key.echo and _at_wrap_edge(vp, ui):
				vp.set_input_as_handled()
				return true
			for pressed in [true, false]:
				var ev := InputEventAction.new()
				ev.action = ui
				ev.pressed = pressed
				ev.strength = 1.0 if pressed else 0.0
				vp.push_input(ev)
			vp.set_input_as_handled()
			return true
	return false


static func _at_wrap_edge(vp: Viewport, ui_action: StringName) -> bool:
	var f := vp.gui_get_focus_owner()
	if f == null:
		return false
	return bool(f.get_meta(StringName("tt_wrap_%s" % String(ui_action).trim_prefix("ui_")), false))


# ----------------------------------------------------------------------------------------------------------------- opener memory

## Scene-level opener memory: the title remembers the row that opened the select scene, the re-created title focuses it again.
static func remember(key: StringName, node_name: String) -> void:
	_remembered[key] = node_name


static func recall(key: StringName) -> String:
	return str(_remembered.get(key, ""))


# ----------------------------------------------------------------------------------------------------------------- the closing press

## Handles the current event AND arms a flag for the rest of this frame that every TTScreen._unhandled_input honours: `set_input_as_handled()`
## alone does not stop the unhandled stage when it is called from a Button's `pressed` handler (probed, F4), so the press that CLOSED a modal
## would reach the world's `interact` (the modal is gone by then, is_modal_open() is false).
static func swallow(vp: Viewport) -> void:
	if vp != null:
		vp.set_input_as_handled()
	_swallow_frame = Engine.get_process_frames()


## True from swallow() until the end of that frame.
static func swallowing() -> bool:
	return _swallow_frame >= 0 and _swallow_frame == Engine.get_process_frames()


# ----------------------------------------------------------------------------------------------------------------- world state

## Is the game on the free world (phase PLAYING, no modal open, not in a sleep / travel fade)? The pause menu and every hotkey opener ask this.
static func world_is_free() -> bool:
	var gm := Svc.node("GameManager")
	if gm == null:
		return false
	if bool(gm.call("is_modal_open")):
		return false
	var phases: Variant = (gm.get_script() as Script).get_script_constant_map().get("GamePhase", {})
	var playing: Variant = (phases as Dictionary).get("PLAYING", 2) if phases is Dictionary else 2
	if int(gm.get("current_phase")) != int(playing):
		return false
	var tree := Engine.get_main_loop() as SceneTree
	var world: Node = tree.current_scene if tree != null else null
	if world != null:
		if bool(world.get("sleeping")) or bool(world.get("traveling")):
			return false
	return true


# ----------------------------------------------------------------------------------------------------------------- helpers (inner classes)

## The focus memory and the group crossings of wire_groups.
class _GroupNav extends RefCounted:
	var groups: Array = []                 # Array[Array[Control]]
	var ring := true
	var remember_focus := true
	var memory: Dictionary = {}            # group index -> Control
	var _connections: Array = []           # [{control, callable}]

	func attach() -> void:
		for gi in groups.size():
			for c in (groups[gi] as Array):
				var ctrl := c as Control
				if ctrl.has_meta(&"tt_nav_groups"):
					var old: Variant = ctrl.get_meta(&"tt_nav_groups")
					if old is _GroupNav and old != self:
						(old as _GroupNav).detach(ctrl)
				ctrl.set_meta(&"tt_nav_groups", self)
				if remember_focus and ctrl.has_focus():
					memory[gi] = ctrl
				var cb := _on_focus.bind(gi, ctrl)
				ctrl.focus_entered.connect(cb)
				_connections.append({"control": ctrl, "callable": cb})

	func detach(ctrl: Control) -> void:
		var keep: Array = []
		for e in _connections:
			if e["control"] == ctrl:
				if is_instance_valid(ctrl) and ctrl.focus_entered.is_connected(e["callable"]):
					ctrl.focus_entered.disconnect(e["callable"])
			else:
				keep.append(e)
		_connections = keep

	func _on_focus(gi: int, ctrl: Control) -> void:
		# A focus callback can rebuild the page before this callback resumes.
		# Disconnection does not revoke a signal emission already in progress.
		if ctrl.get_meta(&"tt_nav_groups", null) != self:
			return
		if remember_focus:
			memory[gi] = ctrl
		relink()

	## the control a move INTO group `gi` lands on: its memory when that is still a stop, else its current tab (the pressed member of a
	## ButtonGroup marked TAB_ROW_META: a tab row that selects on focus must never be entered on its first tab), else its first stop
	func entry(gi: int) -> Control:
		var m: Variant = memory.get(gi) if remember_focus else null
		if UiNav.is_stop(m) and (m as Control).is_inside_tree():
			return m as Control
		for c in (groups[gi] as Array):
			var b := c as BaseButton
			if b != null and b.button_pressed and b.button_group != null and b.button_group.has_meta(UiNav.TAB_ROW_META) \
					and UiNav.is_stop(b) and b.is_inside_tree():
				return b
		for c in (groups[gi] as Array):
			if UiNav.is_stop(c) and (c as Control).is_inside_tree():
				return c as Control
		return null

	func _last_stop(gi: int) -> Control:
		var arr: Array = groups[gi]
		for i in range(arr.size() - 1, -1, -1):
			if UiNav.is_stop(arr[i]) and (arr[i] as Control).is_inside_tree():
				return arr[i] as Control
		return null

	func relink() -> void:
		var n := groups.size()
		if n == 0:
			return
		for gi in n:
			var down_gi := gi + 1
			var up_gi := gi - 1
			var wrap_down := false
			var wrap_up := false
			if down_gi >= n:
				down_gi = 0 if ring else -1
				wrap_down = ring
			if up_gi < 0:
				up_gi = n - 1 if ring else -1
				wrap_up = ring
			for c in (groups[gi] as Array):
				var ctrl := c as Control
				if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
					continue
				if ctrl.get_meta(&"tt_nav_groups", null) != self:
					continue
				if n > 1 or not ring:
					if bool(ctrl.get_meta(&"tt_edge_down", false)):
						_leave(ctrl, UiNav.DOWN, down_gi, wrap_down)
					if bool(ctrl.get_meta(&"tt_edge_up", false)):
						_leave(ctrl, UiNav.UP, up_gi, wrap_up)
			# Tab order across the groups: the last stop of a group -> the first stop of the next one
			var first_here := UiNav.first_enabled(groups[gi])
			var last_here := _last_stop(gi)
			var nxt := UiNav.first_enabled(groups[(gi + 1) % n]) if (gi + 1 < n or ring) else null
			var prv := _last_stop((gi - 1 + n) % n) if (gi > 0 or ring) else null
			if last_here != null and nxt != null and last_here.is_inside_tree() and nxt.is_inside_tree() and last_here.get_meta(&"tt_nav_groups", null) == self:
				last_here.focus_next = last_here.get_path_to(nxt)
			if first_here != null and prv != null and first_here.is_inside_tree() and prv.is_inside_tree() and first_here.get_meta(&"tt_nav_groups", null) == self:
				first_here.focus_previous = first_here.get_path_to(prv)

	func _leave(ctrl: Control, dir: StringName, target_group: int, wraps: bool) -> void:
		var target: Control = entry(target_group) if target_group >= 0 else ctrl
		if target == null:
			target = ctrl
		UiNav.link(ctrl, dir, target)
		var wrap_key := StringName("tt_wrap_%s" % dir)
		if wraps and target != ctrl:
			ctrl.set_meta(wrap_key, true)
		else:
			ctrl.remove_meta(wrap_key)


## The input hook of wasd_as_arrows for a scene that is not a TTScreen.
class _WasdHook extends Node:
	var target: Node

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if target == null or not is_instance_valid(target) or not (target is CanvasItem) or not (target as CanvasItem).is_visible_in_tree():
			return
		var gm := Svc.node("GameManager")
		if gm != null and bool(gm.call("is_modal_open")) and not (target is TTScreen and (target as TTScreen).is_open() and (target as TTScreen).is_top()):
			return                                   # a modal that is not this screen is on top: it navigates
		UiNav.wasd_translate(get_viewport(), event)
