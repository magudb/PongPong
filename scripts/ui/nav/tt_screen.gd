class_name TTScreen
extends Control
## The base class of every modal screen (UI_NAVIGATION.md 4.2): the modal stack, initial focus, focus return, the focus-loss guard, Esc / Start / B,
## the page keys, the screen's own hotkey and the rule that makes Enter / Space / pad A press the focused Button and nothing else.
##
## A screen extends this class, names itself (`screen_id` = the GameUI.SCREEN_ORDER id, `modal_name` = the GameManager modal name) and overrides
## `_initial_focus()` (REQUIRED: the control the screen's card names) plus, where it has them, `_on_cancel()`, `_on_page(step)`, `_refresh_texts()`,
## `_wants_focus()`. A subclass that overrides `_ready()` or `_init()` calls `super()` first.
##
## Where the keys are read (F2 - F4, F8, F14 of section 3.1):
##  * `_input` (before the GUI stage): Esc / Start / pad B (`ui_cancel`, `pause`) close the TOP modal through `_on_cancel()`, `ui_page_up / down`
##    call `_on_page(-1 / +1)`, the screen's hotkey (`hotkey_action`) toggles it (never while a text field has focus), W A S D move focus like the
##    arrows. NEVER `ui_accept` / `interact`: a focused Button presses in the GUI stage, a modal that eats the key in `_input` makes Enter, Space and
##    pad A do nothing at all (probed).
##  * `_unhandled_input`: while this screen is the top modal it marks `ui_accept`, `interact`, `jump`, `dodge` (and `consumed_actions`) as handled,
##    so the focused Button has pressed already and the world never sees the press; and EVERY TTScreen (open or not) marks them handled while
##    `UiNav.swallowing()`, the flag `close()` arms: the press that CLOSED a modal must not reach the world's `interact` either.
##
## open() / close() push and pop the modal exactly once (both are idempotent); `EventBus.ui_panel_toggled(modal_name, is_open)` is answered as an
## open / close REQUEST (the modal stack, never that signal, is the state). Focus: set one frame after open(); the opener (the control that had focus,
## or the one passed in) gets it back on close(), a world opener leaves no focus owner; while the screen is open and on top a lost focus (a hidden or
## freed focus owner, focus outside the screen) is restored within one frame (`focus_guard`, `_wants_focus()`).

signal opened
signal closed

## The GameUI.SCREEN_ORDER id of the screen (scenes/ui/<screen_id>.tscn).
@export var screen_id: StringName = &""
## The GameManager.push_modal name ("pause", "inventory", "journal", ...). Empty = the screen is not on the modal stack.
@export var modal_name: StringName = &""
@export var pauses_tree := true
## open() while another modal is open is refused, unless this screen declares itself nested under the modal that is on top (pause > settings).
@export var nested_under: StringName = &""
## The input action whose key toggles the screen (&"inventory", &"journal", &"build_menu", &"pause" ...); empty = none.
@export var hotkey_action: StringName = &""
## W A S D navigate inside the screen like the arrows (never in a text field).
@export var wasd_navigation := true

## Extra actions this screen marks handled in `_unhandled_input` while it is the top modal. EMPTY by default (never ui_accept: F4).
var consumed_actions: Array[StringName] = []
## false: the focus-loss guard does nothing (the guide-compare fixtures release focus on purpose).
var focus_guard := true

const SWALLOWED: Array[StringName] = [&"ui_accept", &"interact", &"jump", &"dodge"]

var _open := false
var _opener: Variant = null              # untyped on purpose: a control freed while the screen is open must not trip a typed assignment
var _last_good: Variant = null
var _focus_gen := 0
var _bus_connected := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false                                  # a modal root hides itself in _ready, ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP         # while open, a click on the scrim never reaches the world (a hidden control gets no mouse at all)
	set_process(_open)                               # the focus-loss guard only runs while the screen is open
	UiNav.watcher()
	_connect_bus()


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null and vp.gui_focus_changed.is_connected(_on_gui_focus_changed):
		vp.gui_focus_changed.disconnect(_on_gui_focus_changed)
	if _open:
		_open = false
		_focus_gen += 1
		_opener = null
		_last_good = null
		var gm := Svc.node("GameManager")
		if gm != null and modal_name != &"":
			gm.call("pop_modal", modal_name)
		closed.emit()


func _connect_bus() -> void:
	if _bus_connected:
		return
	var bus := Svc.node("EventBus")
	if bus == null:
		return
	_bus_connected = true
	bus.connect(&"ui_panel_toggled", _on_panel_toggled)
	bus.connect(&"modal_changed", _on_modal_changed)


# ----------------------------------------------------------------------------------------------------------------- the API of a screen

func is_open() -> bool:
	return _open


## True when this screen is the topmost modal (or is not on the modal stack at all).
func is_top() -> bool:
	var gm := Svc.node("GameManager")
	return gm == null or modal_name == &"" or StringName(gm.call("top_modal")) == modal_name


## Shows the screen, pushes the modal ONCE, remembers the opener (the control that had focus, unless one is passed in), focuses
## `_initial_focus()` next frame. Refused (nothing happens) while another modal is open, unless `nested_under` names the modal on top.
func open(opener: Control = null) -> void:
	if _open or not is_inside_tree() or not _may_open():
		return
	var vp := get_viewport()
	_opener = opener if opener != null else (vp.gui_get_focus_owner() if vp != null else null)
	_last_good = null
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	if vp != null and not vp.gui_focus_changed.is_connected(_on_gui_focus_changed):
		vp.gui_focus_changed.connect(_on_gui_focus_changed)
	var gm := Svc.node("GameManager")
	if gm != null and modal_name != &"":
		gm.call("push_modal", modal_name, pauses_tree)
	_refresh_texts()
	_focus_next_frame()
	opened.emit()


## Hides the screen, pops the modal ONCE, swallows the closing press, hands focus back to the opener (or to nobody, for a world opener).
func close() -> void:
	if not _open:
		return
	_open = false
	_focus_gen += 1
	var opener: Variant = _opener
	_opener = null
	_last_good = null
	visible = false
	set_process(false)
	var vp := get_viewport()
	if vp != null and vp.gui_focus_changed.is_connected(_on_gui_focus_changed):
		vp.gui_focus_changed.disconnect(_on_gui_focus_changed)
	var gm := Svc.node("GameManager")
	if gm != null and modal_name != &"":
		gm.call("pop_modal", modal_name)
	UiNav.swallow(vp)
	_restore_focus(opener)
	closed.emit()


## REQUIRED override: the control the screen's card names. The default only keeps an owner who forgot it playable and says so.
func _initial_focus() -> Control:
	push_warning("TTScreen %s does not override _initial_focus(): the first enabled control is focused" % name)
	return _first_stop(self)


## Esc / Start / B on this screen while it is the top modal. Overridden for inner layers (Indretning PLACE, Husbyggeri confirm).
func _on_cancel() -> void:
	close()


## ui_page_up (-1) / ui_page_down (+1): tabs, pages, filters. Default nothing.
func _on_page(_step: int) -> void:
	pass


## Called on open() and on NOTIFICATION_TRANSLATION_CHANGED while the screen is open (a closed screen catches up on its next open()): rebuild
## texts that code assembles. Never reconnect signals here.
func _refresh_texts() -> void:
	pass


## A mode that holds no focus owner on purpose (Indretning PLACE, a dialogue text line) returns false: the focus-loss guard then does nothing and
## the audit asks for no initial focus.
func _wants_focus() -> bool:
	return true


## May the screen's HOTKEY open it now (on top of the free-world rule of UiNav.world_is_free())? Default yes.
func _hotkey_open_allowed() -> bool:
	return true


# ----------------------------------------------------------------------------------------------------------------- opening rules

func _may_open() -> bool:
	var gm := Svc.node("GameManager")
	if gm == null or modal_name == &"":
		return true
	var stack: Array = gm.call("modal_stack")
	if stack.is_empty() or (modal_name in stack and stack.size() == 1):
		return true
	return nested_under != &"" and StringName(gm.call("top_modal")) == nested_under


func _focus_next_frame() -> void:
	_focus_gen += 1
	var gen := _focus_gen
	await get_tree().process_frame
	if gen != _focus_gen or not _open or not is_inside_tree():
		return
	_apply_initial_focus()


func _apply_initial_focus() -> void:
	if not _wants_focus():
		return
	var c := _initial_focus()
	if UiNav.is_stop(c) and c.is_visible_in_tree():
		c.grab_focus()


func _restore_focus(opener: Variant) -> void:
	if UiNav.is_stop(opener) and opener.is_inside_tree() and opener.is_visible_in_tree() and not is_ancestor_of(opener):
		opener.grab_focus()
	else:
		UiNav.release_world_focus()


func _first_stop(root: Node) -> Control:
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if UiNav.is_stop(c) and c.is_visible_in_tree():
			return c
	return null


func _on_gui_focus_changed(node: Control) -> void:
	if node != null and is_ancestor_of(node):
		_last_good = node


## The focus-loss guard (3.4): while the screen is open, on top and wants focus, a focus owner that is NONE, outside the screen or no longer
## visible is replaced by the last good control (or the initial one) within one frame.
func _process(_delta: float) -> void:
	if not _open or not focus_guard or not is_top() or not _wants_focus():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var f := vp.gui_get_focus_owner()
	if f != null and is_ancestor_of(f) and f.is_visible_in_tree():
		return
	var target: Variant = _last_good
	if not (UiNav.is_stop(target) and target.is_visible_in_tree()):
		target = _initial_focus()
	if UiNav.is_stop(target) and target.is_visible_in_tree():
		target.grab_focus()


# ----------------------------------------------------------------------------------------------------------------- input

func _is_press(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)


func _input(event: InputEvent) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	if _open:
		if not is_top():
			return
		if wasd_navigation and UiNav.wasd_translate(vp, event):
			return
		if _is_press(event, &"ui_cancel") or _is_press(event, &"pause"):
			_on_cancel()
			vp.set_input_as_handled()
		elif UiNav.page_pressed(event, &"ui_page_up", vp):
			_on_page(-1)
			vp.set_input_as_handled()
		elif UiNav.page_pressed(event, &"ui_page_down", vp):
			_on_page(1)
			vp.set_input_as_handled()
		elif hotkey_action != &"" and _is_press(event, hotkey_action) and not UiNav.text_field_focused(vp):
			close()
			vp.set_input_as_handled()
	elif hotkey_action != &"" and _is_press(event, hotkey_action) and not UiNav.text_field_focused(vp):
		if UiNav.world_is_free() and _hotkey_open_allowed():
			open()
			vp.set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var swallow := UiNav.swallowing()
	var mine := _open and is_top()
	if not swallow and not mine:
		return
	for a in SWALLOWED:
		if _is_press_echo(event, a):
			vp.set_input_as_handled()
			return
	if mine:
		for a in consumed_actions:
			if _is_press_echo(event, a):
				vp.set_input_as_handled()
				return


func _is_press_echo(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action, true)


func _notification(what: int) -> void:
	# Many screens rebuild rows and data in _refresh_texts (save slots, the wardrobe grid, shop rows); a closed screen does that when it opens.
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _open:
		_refresh_texts()


# ----------------------------------------------------------------------------------------------------------------- bus

func _on_panel_toggled(panel_name: StringName, is_open_: bool) -> void:
	if modal_name == &"" or panel_name != modal_name:
		return
	if is_open_:
		open()
	else:
		close()


## The stack was dropped under the screen (quit to the title, load, new game): it is closed without ceremony.
func _on_modal_changed(stack: Array) -> void:
	if _open and modal_name != &"" and not (modal_name in stack):
		_open = false
		_focus_gen += 1
		_opener = null
		_last_good = null
		visible = false
		set_process(false)
		closed.emit()
