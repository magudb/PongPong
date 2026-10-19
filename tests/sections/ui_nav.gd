extends RefCounted
## Section ui_nav (package P28-ui-nav-foundation, docs/design/UI_NAVIGATION.md 3 and 4): the engine facts the input model is built on (F1 - F14, re-run on the live
## engine), UiNav (wire_*, hover focus, field Up / Down, WASD, no wrap on echo, set_enabled), TTScreen (lifecycle, initial focus and restore, the focus-loss guard,
## `_wants_focus`, Esc in `_input`, the focused Button pressing on Enter / Space / pad A, the closing press that never reaches the world, the text-field guard),
## UiHints / HintBar, UiConfirm, the shared widgets (toast stack, prompt pill, whisper line), TTSlider and the amended quantity_stepper.
##
## Named checks (the verify list of the work order): wire_helpers, hover_focus_lists, text_field_yields_updown, wasd_navigates, no_wrap_on_echo, disabled_not_focusable,
## screen_lifecycle, initial_focus_and_restore, focus_loss_guard, wants_focus_guard, esc_uses_input_not_unhandled, accept_presses_focused_button,
## closing_press_does_not_reach_the_world, text_field_typing_is_inert, hint_glyphs_follow_device, hint_bar_localized, prompt_prefix_glyph,
## confirm_default_focus_and_escape, confirm_traps_focus, confirm_ask_text, toast_stack_caps_and_rarity, prompt_pill_follows_device, whisper_line,
## stepper_one_stop_keys, engine_facts, slider_focus_ring (windowed, run_windowed). Evidence for the mutation checks lives in ui_conformance.
##
## The screens under test are small TTScreen subclasses defined below; every test builds its own host under the root and frees it again. The input is REAL events
## pushed into the root viewport (InputEventKey / InputEventJoypadButton, never only InputEventAction), because one key matches several actions (F9).
const SECTION := "ui_nav"
const TIMEOUT_S := 300.0

var _t                              # the harness object (untyped on purpose: tests/lib/t.gd is duck-typed)
var _host: Control
var _gm: Node
var _bus: Node


# ---------------------------------------------------------------------------------------------------- fixtures: screens and probes

## A modal made of three buttons, a text field and a close button. Everything a test wants to count is a public field.
class TestScreen extends TTScreen:
	var first: Button
	var second: Button
	var third: Button
	var field: LineEdit
	var close_button: Button
	var pressed_log: Array[String] = []
	var cancel_calls := 0
	var page_steps: Array[int] = []
	var wants := true
	var with_field := true

	func _ready() -> void:
		super()
		var column := VBoxContainer.new()
		column.position = Vector2(40, 40)
		add_child(column)
		first = _button("First", column)
		second = _button("Second", column)
		third = _button("Third", column)
		if with_field:
			field = LineEdit.new()
			field.name = "Field"
			column.add_child(field)
		close_button = _button("Close", column)
		close_button.pressed.connect(close)
		UiNav.wire_ring([first, second, third, close_button])

	func _button(label: String, parent: Node) -> Button:
		var b := Button.new()
		b.name = label
		b.text = label
		parent.add_child(b)
		b.pressed.connect(func() -> void: pressed_log.append(label))
		return b

	func _initial_focus() -> Control:
		return first

	func _wants_focus() -> bool:
		return wants

	func _on_cancel() -> void:
		cancel_calls += 1
		close()

	func _on_page(step: int) -> void:
		page_steps.append(step)


## Counts _refresh_texts: a language switch rebuilds an OPEN screen only (UIC-04).
class RefreshCountScreen extends TestScreen:
	var refreshes := 0

	func _refresh_texts() -> void:
		refreshes += 1


## A screen whose _input eats ui_accept: the mutation the foundation must catch (Enter / Space / pad A would press nothing).
class EatingScreen extends TestScreen:
	func _input(event: InputEvent) -> void:
		if _open and event.is_action_pressed(&"ui_accept"):
			get_viewport().set_input_as_handled()
			return
		super(event)


## A screen with the classic hotkey bug: it reads its key in `_input` without asking whether a text field has focus (typing "i" opens it).
class LeakyScreen extends TestScreen:
	func _input(event: InputEvent) -> void:
		if hotkey_action != &"" and event.is_action_pressed(hotkey_action):
			if _open:
				close()
			else:
				open()
			get_viewport().set_input_as_handled()
			return
		super(event)


## Counts what reaches the world: the `_unhandled_input` of a node that sits BEFORE the screen in the tree (like the player, which GameUI draws after).
class WorldProbe extends Node:
	var seen: Dictionary = {}

	func _unhandled_input(event: InputEvent) -> void:
		for a in [&"interact", &"jump", &"dodge", &"ui_accept", &"ui_cancel", &"pause"]:
			if event.is_action_pressed(a):
				seen[a] = int(seen.get(a, 0)) + 1


## Records the keys that reach _input and _unhandled_input.
class KeyRecorder extends Node:
	var in_keys: Array[int] = []
	var un_keys: Array[int] = []

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed:
			in_keys.append((event as InputEventKey).keycode)

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed:
			un_keys.append((event as InputEventKey).keycode)


## An Object that eats the event at one stage (the probes of F4).
class Eater extends Node:
	var stage := "off"
	var actions: Array[StringName] = [&"ui_accept", &"interact"]
	var seen := 0

	func _input(event: InputEvent) -> void:
		if stage == "input" and event.is_pressed() and not event.is_echo() and _match(event):
			seen += 1
			get_viewport().set_input_as_handled()

	func _unhandled_input(event: InputEvent) -> void:
		if stage == "unhandled" and event.is_pressed() and not event.is_echo() and _match(event):
			seen += 1
			get_viewport().set_input_as_handled()

	func _match(event: InputEvent) -> bool:
		for a in actions:
			if event.is_action(a):
				return true
		return false


## Counts reads of the three input stages for the order probes (F2, F14).
class OrderProbe extends Node:
	var tag := ""
	var log: Array
	var watch: Key = KEY_F5

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == watch:
			log.append("%s:input" % tag)

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == watch:
			log.append("%s:unhandled" % tag)


# ---------------------------------------------------------------------------------------------------- run

func _bind(t) -> bool:
	_t = t
	_bus = t.autoload("EventBus")
	_gm = t.autoload("GameManager")
	return _bus != null and _gm != null


func run(t) -> void:
	await t.clear_scene()
	if not _bind(t):
		return
	TranslationServer.set_locale("da")
	_reset_game_state()
	UiNav.watcher()
	await t.frames(3)
	await _disabled_not_focusable(t)
	await _wire_helpers(t)
	await _hover_focus_lists(t)
	await _text_field_yields_updown(t)
	await _no_wrap_on_echo(t)
	await _wasd_navigates(t)
	await _screen_lifecycle(t)
	await _language_refresh_only_when_open(t)
	await _initial_focus_and_restore(t)
	await _focus_loss_guard(t)
	await _wants_focus_guard(t)
	await _esc_uses_input_not_unhandled(t)
	await _accept_presses_focused_button(t)
	await _closing_press_does_not_reach_the_world(t)
	await _text_field_typing_is_inert(t)
	await _hint_glyphs_follow_device(t)
	await _hint_bar_localized(t)
	_prompt_prefix_glyph(t)
	await _confirm_default_focus_and_escape(t)
	await _confirm_traps_focus(t)
	await _confirm_ask_text(t)
	await _modal_disposal(t)
	await _toast_stack_caps_and_rarity(t)
	await _prompt_pill_follows_device(t)
	await _whisper_line(t)
	await _stepper_one_stop_keys(t)
	await _engine_facts(t)
	_reset_game_state()
	TranslationServer.set_locale("da")


# ---------------------------------------------------------------------------------------------------- helpers

func _modal_disposal(t) -> void:
	var host := _fresh(t)
	var parent := await _screen(t, host, &"nav_dispose")
	var nested := await _screen(t, host, &"nav_dispose_nested")
	nested.nested_under = &"nav_dispose"
	nested.pauses_tree = false
	parent.open()
	nested.open()
	nested.free()
	await t.frames(2)
	var keeps_parent: bool = t.tree.paused and (_gm.call("modal_stack") as Array) == [&"nav_dispose"]
	parent.free()
	await t.frames(2)
	var released: bool = not t.tree.paused and (_gm.call("modal_stack") as Array).is_empty()
	# The dialog is owned by its asker, but the request may be awaited elsewhere.
	var asker := Control.new()
	host.add_child(asker)
	var dialog := load("res://scenes/ui/components/ui_confirm.tscn").instantiate() as UiConfirm
	asker.add_child(dialog)
	var answers: Array = []
	dialog.answered.connect(func(value: Variant) -> void: answers.append(value))
	dialog.setup("NAV_OK", "NAV_CANCEL", "NAV_OK")
	dialog.begin()
	asker.free()
	await t.frames(2)
	t.check("freeing_modal_releases_stack", keeps_parent and released and not t.tree.paused and (_gm.call("modal_stack") as Array).is_empty() and answers == [false],
		"freeing a nested modal preserves the parent; freeing the last modal resumes play; removing a confirmation's asker cancels exactly once and clears its pause")
	await _finish_test(t)

func _reset_game_state() -> void:
	_gm.call("pop_all_modals")
	_t.tree.paused = false
	var playing: Variant = _t.phase_value(_gm, "PLAYING")
	if playing != null:
		_gm.call("change_phase", playing)


## A fresh full-rect host under the root (the previous one is freed); focus and the modal stack are reset.
func _fresh(t) -> Control:
	_drop_host()
	_reset_game_state()
	t.root.gui_release_focus()
	_host = Control.new()
	_host.name = "NavHost"
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	t.root.add_child(_host)
	return _host


func _drop_host() -> void:
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	_host = null


func _finish_test(t) -> void:
	_drop_host()
	_reset_game_state()
	t.root.gui_release_focus()
	await t.frames(2)


## A TestScreen under `host`, named for the modal stack (the world probe, when given, is added BEFORE it so it sees events after the screen).
func _screen(t, host: Control, modal: StringName, hotkey: StringName = &"", with_field := true, script: Variant = null) -> TestScreen:
	var s: TestScreen = (script.new() if script != null else TestScreen.new()) as TestScreen
	s.name = "Screen_%s" % modal
	s.screen_id = modal
	s.modal_name = modal
	s.hotkey_action = hotkey
	s.with_field = with_field
	host.add_child(s)
	await t.frames(1)
	return s


func _owner_name(t) -> String:
	var f: Control = t.root.gui_get_focus_owner()
	return str(f.name) if f != null else ""


func _key(code: int, pressed := true, echo := false, unicode := 0) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code as Key
	ev.physical_keycode = code as Key
	ev.pressed = pressed
	ev.echo = echo
	ev.unicode = unicode
	_t.root.push_input(ev)


func _tap(t, code: int, unicode := 0) -> void:
	_key(code, true, false, unicode)
	_key(code, false)
	await t.frames(1)


func _echo(t, code: int) -> void:
	_key(code, true, true)
	await t.frames(1)


func _pad(t, button: int) -> void:
	UiAudit.press_pad(t, button as JoyButton)
	await t.frames(1)


func _typed(t, text: String) -> void:
	for ch in text:
		var code := OS.find_keycode_from_string(ch.to_upper())
		_key(code if code != KEY_NONE else ch.unicode_at(0), true, false, ch.unicode_at(0))
		_key(code if code != KEY_NONE else ch.unicode_at(0), false)
		await t.frames(1)


func _button_at(host: Control, name: String, pos: Vector2, size := Vector2(120, 40)) -> Button:
	var b := Button.new()
	b.name = name
	b.text = name
	b.position = pos
	b.size = size
	host.add_child(b)
	return b


func _path_of(from: Control, p: NodePath) -> Control:
	return from.get_node_or_null(p) as Control if not p.is_empty() else null


# ---------------------------------------------------------------------------------------------------- task 1: UiNav

func _disabled_not_focusable(t) -> void:
	var host := _fresh(t)
	var b := _button_at(host, "B", Vector2(100, 100))
	await t.frames(1)
	UiNav.set_enabled(b, false)
	var off_ok: bool = b.disabled and b.focus_mode == Control.FOCUS_NONE and not UiNav.is_stop(b)
	UiNav.set_enabled(b, true)
	var on_ok: bool = not b.disabled and b.focus_mode == Control.FOCUS_ALL and UiNav.is_stop(b)
	var le := LineEdit.new()
	host.add_child(le)
	UiNav.set_enabled(le, false)
	var field_ok: bool = not le.editable and le.focus_mode == Control.FOCUS_NONE
	UiNav.set_enabled(b, false)
	var skipped := UiNav.first_enabled([b, le, b]) == null
	UiNav.set_enabled(b, true)
	var first_ok := UiNav.first_enabled([b]) == b
	t.check("disabled_not_focusable", off_ok and on_ok and field_ok and skipped and first_ok, "set_enabled(false) -> disabled + FOCUS_NONE, (true) restores it; a LineEdit goes read-only; first_enabled skips both")
	await _finish_test(t)


func _wire_helpers(t) -> void:
	var host := _fresh(t)
	var vb := VBoxContainer.new()
	host.add_child(vb)
	var col: Array = []
	for i in 4:
		col.append(_add(vb, "L%d" % i))
	await t.frames(1)
	UiNav.wire_ring(col)
	var ok_l := true
	for i in 4:
		var c: Control = col[i]
		ok_l = ok_l and _path_of(c, c.focus_neighbor_bottom) == col[(i + 1) % 4] and _path_of(c, c.focus_neighbor_top) == col[(i + 3) % 4]
		ok_l = ok_l and _path_of(c, c.focus_neighbor_left) == c and _path_of(c, c.focus_neighbor_right) == c        # the cross axis is consumed
		ok_l = ok_l and _path_of(c, c.focus_next) == col[(i + 1) % 4] and _path_of(c, c.focus_previous) == col[(i + 3) % 4]
	var first: Control = col[0]
	var last: Control = col[3]
	var marks_ok: bool = bool(first.get_meta(&"tt_wrap_up", false)) and bool(last.get_meta(&"tt_wrap_down", false)) and not bool((col[1] as Control).get_meta(&"tt_wrap_up", false))
	UiNav.wire_ring(col, &"v", false)
	var no_wrap_ok: bool = _path_of(first, first.focus_neighbor_top) == first and _path_of(last, last.focus_neighbor_bottom) == last and _path_of(first, first.focus_neighbor_bottom) == col[1]
	# pattern T: a horizontal row (Down / Up are consumed until wire_groups links them)
	var hb := HBoxContainer.new()
	hb.position = Vector2(0, 200)
	host.add_child(hb)
	var tabs: Array = []
	for i in 3:
		tabs.append(_add(hb, "T%d" % i))
	await t.frames(1)
	UiNav.wire_row(tabs)
	var row_ok: bool = _path_of(tabs[0], (tabs[0] as Control).focus_neighbor_left) == tabs[2] and _path_of(tabs[2], (tabs[2] as Control).focus_neighbor_right) == tabs[0] \
		and _path_of(tabs[1], (tabs[1] as Control).focus_neighbor_right) == tabs[2] and _path_of(tabs[1], (tabs[1] as Control).focus_neighbor_top) == tabs[1]
	# pattern G: 22 cells in 6 columns (the backpack): a short last row is clamped, rows wrap inside themselves
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(0, 300)
	host.add_child(grid)
	var cells: Array = []
	for i in 22:
		cells.append(_add(grid, "C%d" % i))
	await t.frames(1)
	UiNav.wire_grid(cells, 6)
	var grid_ok := true
	grid_ok = grid_ok and _path_of(cells[17], (cells[17] as Control).focus_neighbor_bottom) == cells[21]       # row 2, col 5 -> the last cell of the short row (col 3)
	grid_ok = grid_ok and _path_of(cells[3], (cells[3] as Control).focus_neighbor_bottom) == cells[9]            # keeps the column
	grid_ok = grid_ok and _path_of(cells[21], (cells[21] as Control).focus_neighbor_right) == cells[18]         # wraps inside the short row
	grid_ok = grid_ok and _path_of(cells[18], (cells[18] as Control).focus_neighbor_left) == cells[21]
	grid_ok = grid_ok and _path_of(cells[5], (cells[5] as Control).focus_neighbor_right) == cells[0]
	grid_ok = grid_ok and _path_of(cells[2], (cells[2] as Control).focus_neighbor_top) == cells[20]            # top row wraps to the bottom row, column kept
	grid_ok = grid_ok and _path_of(cells[21], (cells[21] as Control).focus_neighbor_bottom) == cells[3]        # bottom row wraps to the top, column kept
	grid_ok = grid_ok and bool((cells[0] as Control).get_meta(&"tt_edge_up", false)) and bool((cells[21] as Control).get_meta(&"tt_edge_down", false)) and not bool((cells[8] as Control).get_meta(&"tt_edge_up", false))
	# groups: tabs above the grid; Down from a tab lands on the grid's first stop, Up from the grid on the CURRENT tab (focus memory), the ring wraps
	UiNav.wire_groups([tabs, cells])
	var tab_down := _path_of(tabs[1], (tabs[1] as Control).focus_neighbor_bottom)
	var groups_ok: bool = tab_down == cells[0] and _path_of(cells[0], (cells[0] as Control).focus_neighbor_top) == tabs[0]
	groups_ok = groups_ok and _path_of(cells[21], (cells[21] as Control).focus_neighbor_bottom) == tabs[0]          # last group -> first group (the ring)
	(cells[8] as Control).grab_focus()
	(tabs[2] as Control).grab_focus()
	await t.frames(1)
	var memory_ok: bool = _path_of(tabs[0], (tabs[0] as Control).focus_neighbor_bottom) == cells[8] and _path_of(cells[3], (cells[3] as Control).focus_neighbor_top) == tabs[2]
	var wrap_marks_ok: bool = bool((cells[21] as Control).get_meta(&"tt_wrap_down", false)) and not bool((tabs[1] as Control).get_meta(&"tt_wrap_down", false)) and bool((tabs[0] as Control).get_meta(&"tt_wrap_up", false))
	var tab_order_ok: bool = _path_of(cells[21], (cells[21] as Control).focus_next) == tabs[0] and _path_of(tabs[2], (tabs[2] as Control).focus_next) == cells[0]      # Tab walks the groups in order (no memory)
	# re-wiring replaces the old wiring (no stacked connections, memory still works)
	UiNav.wire_groups([tabs, cells])
	(cells[10] as Control).grab_focus()
	await t.frames(1)
	var rewire_ok: bool = _path_of(tabs[2], (tabs[2] as Control).focus_neighbor_bottom) == cells[10]
	# real presses follow the wiring
	(tabs[1] as Control).grab_focus()
	await t.frames(1)
	await _tap(t, KEY_DOWN)
	var real_ok: bool = _owner_name(t) == "C10"
	t.check("wire_helpers", ok_l and marks_ok and no_wrap_ok and row_ok and grid_ok and groups_ok and memory_ok and wrap_marks_ok and tab_order_ok and rewire_ok and real_ok,
		"L ring %s, wrap marks %s, no-wrap %s, T row %s, G grid (22 in 6, clamped short row) %s, groups %s, focus memory %s, ring wrap marks %s, Tab order %s, re-wire %s, a real Down press lands on %s" % [ok_l, marks_ok, no_wrap_ok, row_ok, grid_ok, groups_ok, memory_ok, wrap_marks_ok, tab_order_ok, rewire_ok, _owner_name(t)])
	await _finish_test(t)


func _add(parent: Node, name: String) -> Button:
	var b := Button.new()
	b.name = name
	b.text = name
	b.custom_minimum_size = Vector2(60, 30)
	parent.add_child(b)
	return b


func _hover_focus_lists(t) -> void:
	var host := _fresh(t)
	var row := _button_at(host, "Row", Vector2(100, 100), Vector2(200, 40))
	var row2 := _button_at(host, "Row2", Vector2(100, 160), Vector2(200, 40))
	var chip := _button_at(host, "Chip", Vector2(100, 220), Vector2(200, 40))
	var field := LineEdit.new()
	field.name = "Field"
	field.position = Vector2(100, 280)
	field.size = Vector2(200, 40)
	host.add_child(field)
	await t.frames(2)
	UiNav.hover_focus([row, row2])
	UiNav.hover_focus([row])                                    # a second call must not connect twice
	t.move_mouse(Vector2(900, 600))
	await t.frames(1)
	t.move_mouse(Vector2(150, 120))
	await t.frames(2)
	var on_row := _owner_name(t) == "Row"
	t.move_mouse(Vector2(150, 180))
	await t.frames(2)
	var on_row2 := _owner_name(t) == "Row2"
	t.move_mouse(Vector2(150, 240))                           # a chip / tab / card is not in the list: hover only styles it
	await t.frames(2)
	var chip_ok := _owner_name(t) == "Row2" and not chip.has_focus()
	t.move_mouse(Vector2(150, 300))
	await t.frames(2)
	var field_ok := _owner_name(t) == "Row2" and not field.has_focus()
	row2.disabled = true
	t.move_mouse(Vector2(900, 600))
	await t.frames(1)
	t.move_mouse(Vector2(150, 180))
	row.grab_focus()
	await t.frames(2)
	var disabled_ok := _owner_name(t) == "Row"
	t.check("hover_focus_lists", on_row and on_row2 and chip_ok and field_ok and disabled_ok and row.get_signal_connection_list(&"mouse_entered").size() == 1,
		"mouse_entered grabs focus on the rows (%s / %s), not on a chip (%s) or a text field (%s), not on a disabled row (%s); one connection per row" % [on_row, on_row2, chip_ok, field_ok, disabled_ok])
	await _finish_test(t)


func _text_field_yields_updown(t) -> void:
	var host := _fresh(t)
	var vb := VBoxContainer.new()
	vb.position = Vector2(100, 100)
	host.add_child(vb)
	var above := _add(vb, "Above")
	var field := LineEdit.new()
	field.name = "Field"
	field.custom_minimum_size = Vector2(200, 36)
	vb.add_child(field)
	var below := _add(vb, "Below")
	var plain := LineEdit.new()
	plain.name = "Plain"
	plain.custom_minimum_size = Vector2(200, 36)
	vb.add_child(plain)
	await t.frames(2)
	field.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_DOWN)
	var baseline_stays := _owner_name(t) == "Field"                  # F7: without the helper a LineEdit keeps the Up / Down KEYS
	UiNav.yield_updown_from_fields(host)
	UiNav.yield_updown_from_fields(host)                              # idempotent
	await _tap(t, KEY_DOWN)
	var down_ok := _owner_name(t) == "Below"
	field.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_UP)
	var up_ok := _owner_name(t) == "Above"
	# Tab and Enter still work in a field
	field.grab_focus()
	await t.frames(1)
	var submitted := [0]
	field.text_submitted.connect(func(_s: String) -> void: submitted[0] += 1)
	await _tap(t, KEY_ENTER)
	var enter_ok: bool = submitted[0] == 1 and _owner_name(t) == "Field"
	await _tap(t, KEY_TAB)
	var tab_ok := _owner_name(t) != "Field"
	# typing is untouched and the caret keys still move the caret
	field.grab_focus()
	field.text = ""
	await t.frames(1)
	await _typed(t, "ab")
	await _tap(t, KEY_LEFT)
	var typed_ok: bool = field.text == "ab" and _owner_name(t) == "Field" and field.caret_column == 1
	t.check("text_field_yields_updown", baseline_stays and down_ok and up_ok and enter_ok and tab_ok and typed_ok and above != null and below != null and plain != null,
		"without the helper Down stays in the field (%s); with it Down -> Below (%s), Up -> Above (%s); Enter submits (%s), Tab leaves (%s), typing and the caret keys work (%s)" % [baseline_stays, down_ok, up_ok, enter_ok, tab_ok, typed_ok])
	await _finish_test(t)


func _no_wrap_on_echo(t) -> void:
	var host := _fresh(t)
	var vb := VBoxContainer.new()
	vb.position = Vector2(100, 100)
	host.add_child(vb)
	var col: Array = []
	for i in 3:
		col.append(_add(vb, "E%d" % i))
	await t.frames(2)
	UiNav.wire_ring(col)
	(col[2] as Control).grab_focus()
	await t.frames(1)
	await _echo(t, KEY_DOWN)
	var echo_stops := _owner_name(t) == "E2"
	await _tap(t, KEY_DOWN)
	var fresh_wraps := _owner_name(t) == "E0"
	await _echo(t, KEY_UP)
	var echo_up_stops := _owner_name(t) == "E0"
	await _echo(t, KEY_DOWN)
	var echo_inside_moves := _owner_name(t) == "E1"
	await _tap(t, KEY_UP)
	await _tap(t, KEY_UP)
	var fresh_up_wraps := _owner_name(t) == "E2"
	t.check("no_wrap_on_echo", echo_stops and fresh_wraps and echo_up_stops and echo_inside_moves and fresh_up_wraps,
		"a held Down (echo) stops at the last item (%s), a fresh press wraps (%s); same at the top (%s / %s); an echo inside the ring still moves (%s)" % [echo_stops, fresh_wraps, echo_up_stops, fresh_up_wraps, echo_inside_moves])
	await _finish_test(t)


func _wasd_navigates(t) -> void:
	var host := _fresh(t)
	var s := await _screen(t, host, &"nav_wasd")
	s.open()
	await t.frames(2)
	var start := _owner_name(t) == "First"
	await _tap(t, KEY_S)
	var down := _owner_name(t) == "Second"
	await _tap(t, KEY_W)
	var up := _owner_name(t) == "First"
	await _tap(t, KEY_S)
	await _tap(t, KEY_S)
	await _tap(t, KEY_S)
	await _tap(t, KEY_W)
	var ring_ok := _owner_name(t) == "Third"                         # S, S, S wraps back to First via Close... First -> Second -> Third -> Close; W goes back to Third
	# never in a field: the letters are typed there, focus stays
	s.field.grab_focus()
	await t.frames(1)
	await _typed(t, "wasd")
	var field_ok: bool = _owner_name(t) == "Field" and s.field.text == "wasd"
	# the arrows are untouched (they navigate by themselves, once)
	s.first.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_DOWN)
	var arrows_ok := _owner_name(t) == "Second"
	# a held S (echo) at a wrapping end is swallowed, a fresh one wraps
	s.close_button.grab_focus()
	await t.frames(1)
	await _echo(t, KEY_S)
	var echo_ok := _owner_name(t) == "Close"
	await _tap(t, KEY_S)
	var wrap_ok := _owner_name(t) == "First"
	# not on the free world: a closed screen leaves W A S D alone
	s.close()
	await t.frames(2)
	var lone := _button_at(host, "Lone", Vector2(600, 400))
	var lone2 := _button_at(host, "Lone2", Vector2(600, 460))
	await t.frames(1)
	lone.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_S)
	var world_ok := _owner_name(t) == "Lone" and lone2 != null
	# a scene that is not a TTScreen asks for it with wasd_as_arrows
	var plain := Control.new()
	plain.name = "PlainScene"
	host.add_child(plain)
	var pa := _button_at(plain, "PA", Vector2(300, 400))
	var pb := _button_at(plain, "PB", Vector2(300, 460))
	await t.frames(1)
	UiNav.wasd_as_arrows(plain)
	UiNav.wasd_as_arrows(plain)
	pa.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_S)
	var scene_ok := _owner_name(t) == "PB" and plain.get_children().filter(func(c: Node) -> bool: return c.name == "UiNavWasd").size() == 1 and pb != null
	t.check("wasd_navigates", start and down and up and ring_ok and field_ok and arrows_ok and echo_ok and wrap_ok and world_ok and scene_ok,
		"W / S move focus in an open screen (%s / %s / %s), never inside a text field (%s), the arrows still work once (%s), an echo S stops at a wrapping end and a fresh one wraps (%s / %s), a closed screen and the free world are left alone (%s), wasd_as_arrows serves a plain scene (%s)" % [down, up, ring_ok, field_ok, arrows_ok, echo_ok, wrap_ok, world_ok, scene_ok])
	await _finish_test(t)


# ---------------------------------------------------------------------------------------------------- task 2: TTScreen

func _screen_lifecycle(t) -> void:
	var host := _fresh(t)
	var s := await _screen(t, host, &"nav_life")
	var hidden_always: bool = not s.visible and s.process_mode == Node.PROCESS_MODE_ALWAYS and not s.is_open()
	var opened := [0]
	var closed := [0]
	s.opened.connect(func() -> void: opened[0] += 1)
	s.closed.connect(func() -> void: closed[0] += 1)
	s.open()
	s.open()
	await t.frames(2)
	var stack: Array = _gm.call("modal_stack")
	var once: bool = s.visible and s.is_open() and stack.count(&"nav_life") == 1 and opened[0] == 1 and bool(_gm.call("is_modal_open", &"nav_life"))
	var paused_ok: bool = t.tree.paused and int(_gm.get("current_phase")) == int(t.phase_value(_gm, "PAUSED"))
	s.close()
	s.close()
	await t.frames(1)
	var gone: bool = not s.visible and not s.is_open() and not bool(_gm.call("is_modal_open", &"nav_life")) and closed[0] == 1 and not t.tree.paused
	# EventBus.ui_panel_toggled is answered as an open / close REQUEST
	_bus.ui_panel_toggled.emit(&"nav_life", true)
	_bus.ui_panel_toggled.emit(&"nav_life", true)
	await t.frames(1)
	var req_open: bool = s.is_open() and opened[0] == 2 and (_gm.call("modal_stack") as Array).count(&"nav_life") == 1
	_bus.ui_panel_toggled.emit(&"someone_else", false)
	await t.frames(1)
	var other_ignored := s.is_open()
	_bus.ui_panel_toggled.emit(&"nav_life", false)
	await t.frames(1)
	var req_close: bool = not s.is_open() and closed[0] == 2
	# a non-pausing screen does not pause the tree (the dialogue)
	s.pauses_tree = false
	s.open()
	await t.frames(1)
	var cutscene_ok: bool = not t.tree.paused and int(_gm.get("current_phase")) == int(t.phase_value(_gm, "CUTSCENE"))
	# the stack dropped under the screen (quit to the title, load): closed without ceremony
	_gm.call("pop_all_modals")
	await t.frames(1)
	var dropped_ok: bool = not s.is_open() and not s.visible and closed[0] == 3
	# siblings do not stack: opening is refused while another modal is open, unless the screen is nested under the one on top
	var a := await _screen(t, host, &"nav_a")
	var b := await _screen(t, host, &"nav_b")
	var n := await _screen(t, host, &"nav_nested")
	n.nested_under = &"nav_a"
	a.open()
	b.open()
	await t.frames(1)
	var refused: bool = a.is_open() and not b.is_open() and not bool(_gm.call("is_modal_open", &"nav_b"))
	n.open()
	await t.frames(1)
	var nested_ok: bool = n.is_open() and (_gm.call("modal_stack") as Array) == [&"nav_a", &"nav_nested"]
	t.check("screen_lifecycle", hidden_always and once and paused_ok and gone and req_open and other_ignored and req_close and cutscene_ok and dropped_ok and refused and nested_ok,
		"hidden + ALWAYS after _ready (%s); open() twice pushes ONCE (%s) and pauses (%s); close() twice pops once (%s); ui_panel_toggled is answered once per request (%s / %s / %s); a non-pausing screen is CUTSCENE (%s); a dropped stack closes it (%s); siblings refuse (%s), a nested screen opens (%s)" % [hidden_always, once, paused_ok, gone, req_open, other_ignored, req_close, cutscene_ok, dropped_ok, refused, nested_ok])
	await _finish_test(t)


func _language_refresh_only_when_open(t) -> void:
	var host := _fresh(t)
	var s = await _screen(t, host, &"nav_lang", &"", false, RefreshCountScreen)
	s.refreshes = 0
	TranslationServer.set_locale("en")
	await t.frames(2)
	var closed_skips: bool = s.refreshes == 0
	s.open()
	await t.frames(2)
	var open_catches_up: bool = s.refreshes == 1
	TranslationServer.set_locale("da")
	await t.frames(2)
	var open_follows: bool = s.refreshes == 2
	s.close()
	t.check("language_switch_rebuilds_open_screens_only", closed_skips and open_catches_up and open_follows,
		"a closed screen skips the rebuild (%s), open() catches up (%s), an open screen follows the switch (%s): %d refreshes" % [closed_skips, open_catches_up, open_follows, s.refreshes])
	await _finish_test(t)


func _initial_focus_and_restore(t) -> void:
	var host := _fresh(t)
	var opener := _button_at(host, "Opener", Vector2(700, 100))
	var s := await _screen(t, host, &"nav_focus")
	opener.grab_focus()
	await t.frames(1)
	s.open()
	var same_frame := _owner_name(t) == "Opener"                    # the focus moves one frame after open()
	await t.frames(1)
	var next_frame := _owner_name(t) == "First"
	s.close()
	await t.frames(1)
	var restored := _owner_name(t) == "Opener"
	# a world opener (nothing had focus): close leaves NO focus owner, so Space / Enter / the arrows act on the world again
	t.root.gui_release_focus()
	await t.frames(1)
	s.open()
	await t.frames(2)
	s.second.grab_focus()
	await t.frames(1)
	s.close()
	await t.frames(1)
	var world_ok: bool = t.root.gui_get_focus_owner() == null
	# an explicit opener wins over the focus owner; a freed opener falls back to the world
	var other := _button_at(host, "Other", Vector2(700, 200))
	var gone := _button_at(host, "Gone", Vector2(700, 300))
	await t.frames(1)
	other.grab_focus()
	s.open(opener)
	await t.frames(2)
	s.close()
	await t.frames(1)
	var explicit_ok := _owner_name(t) == "Opener"
	s.open(gone)
	await t.frames(2)
	gone.free()
	s.close()
	await t.frames(1)
	var freed_ok: bool = t.root.gui_get_focus_owner() == null
	t.check("initial_focus_and_restore", same_frame and next_frame and restored and world_ok and explicit_ok and freed_ok,
		"focus is still on the opener in the frame of open() (%s) and on _initial_focus() one frame later (%s); close() hands it back (%s); a world opener leaves no owner (%s); open(opener) wins (%s); a freed opener leaves no owner (%s)" % [same_frame, next_frame, restored, world_ok, explicit_ok, freed_ok])
	await _finish_test(t)


func _focus_loss_guard(t) -> void:
	var host := _fresh(t)
	var outside := _button_at(host, "Outside", Vector2(700, 100))
	var s := await _screen(t, host, &"nav_guard")
	s.open()
	await t.frames(3)
	s.second.grab_focus()
	await t.frames(1)
	s.second.hide()                                        # a hidden focus owner leaves focus NONE (E12) ...
	await t.frames(1)
	var hidden_ok: bool = t.root.gui_get_focus_owner() != null and s.is_ancestor_of(t.root.gui_get_focus_owner()) and t.root.gui_get_focus_owner().is_visible_in_tree()      # ... and the guard puts it back within one frame
	s.second.show()
	s.third.grab_focus()
	await t.frames(1)
	var third := s.third
	third.free()                                           # a freed focus owner (a list that refreshed)
	await t.frames(2)
	var freed_ok: bool = t.root.gui_get_focus_owner() != null and s.is_ancestor_of(t.root.gui_get_focus_owner())
	outside.grab_focus()                                   # focus outside the screen is pulled back
	await t.frames(2)
	var outside_ok: bool = t.root.gui_get_focus_owner() != null and s.is_ancestor_of(t.root.gui_get_focus_owner())
	# the guard returns to the LAST GOOD control, not always to the first one
	s.close_button.grab_focus()
	await t.frames(1)
	s.close_button.hide()
	await t.frames(2)
	var last_good_ok: bool = t.root.gui_get_focus_owner() != null and s.is_ancestor_of(t.root.gui_get_focus_owner())
	# a screen that is not on top does not touch the focus (the pause menu under settings)
	var top := await _screen(t, host, &"nav_top")
	top.nested_under = &"nav_guard"
	top.open()
	await t.frames(3)
	outside.grab_focus()
	await t.frames(2)
	var not_top_ok: bool = top.is_ancestor_of(t.root.gui_get_focus_owner()) or t.root.gui_get_focus_owner() == top.first
	# clicking empty space never drops focus (F10)
	t.click(Vector2(1100, 650))
	await t.frames(2)
	var click_ok: bool = t.root.gui_get_focus_owner() != null
	t.check("focus_loss_guard", hidden_ok and freed_ok and outside_ok and last_good_ok and not_top_ok and click_ok,
		"a hidden focus owner (%s), a freed one (%s) and focus outside the screen (%s) are replaced within a frame; hiding the last good control (%s); only the TOP screen guards (%s); an empty-space click keeps focus (%s)" % [hidden_ok, freed_ok, outside_ok, last_good_ok, not_top_ok, click_ok])
	await _finish_test(t)


func _wants_focus_guard(t) -> void:
	var host := _fresh(t)
	var s := await _screen(t, host, &"nav_nofocus")
	s.wants = false
	s.open()
	await t.frames(3)
	var no_initial: bool = t.root.gui_get_focus_owner() == null
	s.first.grab_focus()
	await t.frames(1)
	t.root.gui_release_focus()
	await t.frames(3)
	var not_refocused: bool = t.root.gui_get_focus_owner() == null
	var report: Dictionary = UiAudit.initial_focus_report(s)
	var audit_ok: bool = (report["defects"] as Array).is_empty() and "no initial focus is required" in str(report["notes"])
	var walk: Dictionary = await UiAudit.focus_walk(t, s, 50)
	var walk_ok: bool = (walk["defects"] as Array).is_empty() and "_wants_focus() = false" in str(walk["notes"])
	s.wants = true
	await t.frames(3)
	var back_ok: bool = t.root.gui_get_focus_owner() != null and s.is_ancestor_of(t.root.gui_get_focus_owner())
	t.check("wants_focus_guard", no_initial and not_refocused and audit_ok and walk_ok and back_ok,
		"_wants_focus() = false: no initial focus (%s), the guard does not refocus (%s), the audit asks for no initial focus (%s) and skips the walk (%s); true again -> focused (%s)" % [no_initial, not_refocused, audit_ok, walk_ok, back_ok])
	await _finish_test(t)


func _esc_uses_input_not_unhandled(t) -> void:
	var host := _fresh(t)
	var rec := KeyRecorder.new()                            # before the screen in the tree: its _input runs AFTER the screen's, its _unhandled_input after the GUI
	host.add_child(rec)
	var s := await _screen(t, host, &"nav_esc")
	s.open()
	await t.frames(2)
	s.field.grab_focus()
	await t.frames(1)
	await _typed(t, "x")                                    # being edited: the field owns the keyboard
	var typed_ok: bool = s.field.text == "x" and rec.un_keys.is_empty()          # typed letters never reach _unhandled_input (F3)
	rec.in_keys.clear()
	rec.un_keys.clear()
	var submitted := [0]
	s.field.text_submitted.connect(func(_x: String) -> void: submitted[0] += 1)
	await _tap(t, KEY_ENTER)
	var enter_in_input: bool = submitted[0] == 1 and rec.un_keys.is_empty()          # Enter in a LineEdit emits text_submitted and is consumed (F8)
	s.field.release_focus()                                    # a LineEdit that submitted (or got Esc) stops "editing"; focusing it again starts editing
	s.field.grab_focus()
	await t.frames(1)
	rec.in_keys.clear()
	rec.un_keys.clear()
	await _tap(t, KEY_ESCAPE)
	await t.frames(1)
	var esc_closed: bool = not s.is_open() and s.cancel_calls == 1                    # the screen's _input saw Esc although the field was being edited
	var esc_not_unhandled: bool = not (KEY_ESCAPE in rec.un_keys)                     # a handler that waited for _unhandled_input would never have seen it
	# the same for the pad: Start and B (ui_cancel / pause) close the top screen, A on a focused button does not
	s.open()
	await t.frames(2)
	await _pad(t, JOY_BUTTON_START)
	var start_ok: bool = not s.is_open()
	s.open()
	await t.frames(2)
	await _pad(t, JOY_BUTTON_B)
	var b_ok: bool = not s.is_open() and s.cancel_calls == 3
	# the page keys and the hotkey are read in _input as well
	s.open()
	await t.frames(2)
	await _tap(t, KEY_PAGEUP)
	await _pad(t, JOY_BUTTON_RIGHT_SHOULDER)
	var page_ok: bool = s.page_steps == [-1, 1]
	s.close()
	await t.frames(1)
	t.check("esc_uses_input_not_unhandled", typed_ok and enter_in_input and esc_closed and esc_not_unhandled and start_ok and b_ok and page_ok,
		"typed letters never reach _unhandled_input (%s), Enter in the field is consumed (%s); Esc closes the screen although the field is being edited, through _input (%s / %s); Start (%s) and B (%s) close it; PgUp / RB call _on_page(-1 / +1) (%s)" % [typed_ok, enter_in_input, esc_closed, esc_not_unhandled, start_ok, b_ok, page_ok])
	await _finish_test(t)


## What a screen of `script` (TestScreen or a mutant of it) does with the three ways of accepting: returns {buttons_ok, e_ok, world_ok, esc_ok, closed_ok, rows, ok}.
## Public: ui_conformance runs it on a mutant whose _input eats ui_accept and expects ok == false (mutant_accept_eaten_caught).
func accept_probe(t, script: Variant = null) -> Dictionary:
	_bind(t)
	var host := _fresh(t)
	var world := WorldProbe.new()
	host.add_child(world)                                   # before the screen: it sees the unhandled stage AFTER the screen, like Player2D after GameUI
	var s := await _screen(t, host, &"nav_accept", &"", false, script)
	s.open()
	await t.frames(2)
	var rows := {}
	for ev in ["enter", "space", "padA", "e"]:
		s.first.grab_focus()
		await t.frames(1)
		s.pressed_log.clear()
		world.seen.clear()
		match ev:
			"enter":
				await _tap(t, KEY_ENTER)
			"space":
				await _tap(t, KEY_SPACE)
			"padA":
				await _pad(t, JOY_BUTTON_A)
			"e":
				await _tap(t, KEY_E)
		rows[ev] = {"pressed": s.pressed_log.size(), "world": world.seen.duplicate()}
	var buttons_ok: bool = int(rows["enter"]["pressed"]) == 1 and int(rows["space"]["pressed"]) == 1 and int(rows["padA"]["pressed"]) == 1
	var e_ok: bool = int(rows["e"]["pressed"]) == 0                                  # E is `interact` only: it is not ui_accept, no Button presses
	var world_ok := true
	for ev in rows:
		world_ok = world_ok and (rows[ev]["world"] as Dictionary).is_empty()           # not interact, not jump, not dodge, not ui_accept reached the world
	# Esc closes (and the world never sees `pause`)
	await _tap(t, KEY_ESCAPE)
	var esc_ok: bool = not s.is_open() and not world.seen.has(&"pause") and not world.seen.has(&"ui_cancel")
	# a hidden modal (not top) does not eat the world's keys
	await t.frames(1)
	world.seen.clear()
	await _tap(t, KEY_E)
	var closed_ok: bool = int(world.seen.get(&"interact", 0)) == 1
	await _finish_test(t)
	return {"buttons_ok": buttons_ok, "e_ok": e_ok, "world_ok": world_ok, "esc_ok": esc_ok, "closed_ok": closed_ok, "rows": rows, "ok": buttons_ok and e_ok and world_ok and esc_ok and closed_ok}


func _accept_presses_focused_button(t) -> void:
	var r: Dictionary = await accept_probe(t)
	t.check("accept_presses_focused_button", bool(r["ok"]),
		"Enter, Space and pad A press the focused Button exactly once (%s) and the world sees none of interact / jump / dodge / ui_accept (%s); E presses nothing (%s); Esc closes without a world reaction (%s); a closed screen leaves E to the world (%s)" % [r["buttons_ok"], r["world_ok"], r["e_ok"], r["esc_ok"], r["closed_ok"]])


func _closing_press_does_not_reach_the_world(t) -> void:
	var host := _fresh(t)
	var world := WorldProbe.new()
	host.add_child(world)
	var s := await _screen(t, host, &"nav_closing", &"", false)
	s.open()
	await t.frames(2)
	s.close_button.grab_focus()
	await t.frames(1)
	world.seen.clear()
	await _tap(t, KEY_ENTER)                                 # Enter presses "Close": the modal is gone before the unhandled stage
	var enter_closed: bool = not s.is_open() and world.seen.is_empty() and UiNav.swallowing() == false
	s.open()
	await t.frames(2)
	s.close_button.grab_focus()
	await t.frames(1)
	await _pad(t, JOY_BUTTON_A)
	var pad_closed: bool = not s.is_open() and world.seen.is_empty()
	# the same press WITHOUT the swallow reaches the world: the finding behind UiNav.swallow (F4)
	var b := _button_at(host, "Naive", Vector2(600, 300))
	b.pressed.connect(func() -> void: b.get_viewport().set_input_as_handled())     # set_input_as_handled() inside a pressed handler does not stop the unhandled stage
	b.grab_focus()
	await t.frames(1)
	world.seen.clear()
	await _tap(t, KEY_ENTER)
	var naive_leaks: bool = int(world.seen.get(&"interact", 0)) == 1
	# swallowing() is a one-frame flag
	UiNav.swallow(t.root)
	var armed := UiNav.swallowing()
	await t.frames(2)
	var expired := not UiNav.swallowing()
	# the flag also covers a screen that is NOT open: a TTScreen that closed earlier in the same frame is not on top any more
	var s2 := await _screen(t, host, &"nav_closing_two", &"", false)
	await t.frames(1)
	world.seen.clear()
	UiNav.swallow(t.root)
	_key(KEY_E, true)
	_key(KEY_E, false)
	await t.frames(1)
	var closed_screen_swallows: bool = world.seen.is_empty() and s2 != null
	t.check("closing_press_does_not_reach_the_world", enter_closed and pad_closed and naive_leaks and armed and expired and closed_screen_swallows,
		"the Enter / pad A that presses a row CLOSING the last modal never reaches the world (%s / %s); without the swallow it does (%s: set_input_as_handled() in a pressed handler is not enough); the flag lasts one frame (%s / %s) and every TTScreen honours it, open or not (%s)" % [enter_closed, pad_closed, naive_leaks, armed, expired, closed_screen_swallows])
	await _finish_test(t)


# ---------------------------------------------------------------------------------------------------- task 3: the text-field guard

## Typing into a screen's text field and pressing its hotkey: returns {audit_ok, typed_ok, closed_ok, opens_ok, toggles_ok, keys, ok}. `script` is TestScreen or a mutant
## of it (ui_conformance: a hotkey that fires while a field has focus must make `ok` false: mutant_hotkey_in_field_caught).
func typing_probe(t, script: Variant = null) -> Dictionary:
	_bind(t)
	var host := _fresh(t)
	var s := await _screen(t, host, &"nav_typing", &"inventory", true, script)
	var other := LineEdit.new()
	other.name = "OtherField"
	other.position = Vector2(700, 100)
	other.size = Vector2(200, 36)
	host.add_child(other)
	await t.frames(1)
	# 1. the library's text-field audit on the open screen: every letter / digit / Space / Tab ... a world action is bound to
	s.open()
	await t.frames(2)
	s.field.grab_focus()
	await t.frames(1)
	var rep: Dictionary = await UiAudit.text_field_audit(t, s)
	var audit_ok: bool = (rep["defects"] as Array).is_empty() and int(rep.get("keys_tested", 0)) >= 20
	var still_open: bool = s.is_open()
	if not still_open:
		s.open()
		await t.frames(2)
	# 2. the named keys, in one go: nothing opens, no slot is selected, no focus moves, the text is exactly what was typed
	s.field.grab_focus()
	s.field.text = ""
	await t.frames(1)
	await _typed(t, "ijehgcb10wasd")
	var typed_ok: bool = s.field.text == "ijehgcb10wasd" and _owner_name(t) == "Field" and s.is_open() and s.cancel_calls == 0
	# 3. a CLOSED screen with a hotkey does not open while another field has focus
	s.close()
	await t.frames(2)
	_gm.call("pop_all_modals")
	other.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_I)
	await _tap(t, KEY_TAB)
	var closed_ok: bool = not s.is_open() and not bool(_gm.call("is_modal_open"))
	# 4. the same key opens it when no field has focus (the guard is the only difference)
	if s.is_open():
		s.close()
	_gm.call("pop_all_modals")
	other.release_focus()
	t.root.gui_release_focus()
	await t.frames(1)
	await _tap(t, KEY_I)
	var opens_ok: bool = s.is_open()
	await _tap(t, KEY_I)
	var toggles_ok: bool = not s.is_open()
	var keys := int(rep.get("keys_tested", 0))
	await _finish_test(t)
	return {"audit_ok": audit_ok, "still_open": still_open, "typed_ok": typed_ok, "closed_ok": closed_ok, "opens_ok": opens_ok, "toggles_ok": toggles_ok, "keys": keys,
		"ok": audit_ok and still_open and typed_ok and closed_ok and opens_ok and toggles_ok}


func _text_field_typing_is_inert(t) -> void:
	var r: Dictionary = await typing_probe(t)
	t.check("text_field_typing_is_inert", bool(r["ok"]),
		"text_field_audit (%d keys) finds no leak (%s); typing i j e h g c b 1 0 w a s d opens nothing and moves no focus (%s); a closed screen does not open its hotkey while a field has focus (%s); without a field the hotkey opens (%s) and closes (%s) it" % [int(r["keys"]), r["audit_ok"], r["typed_ok"], r["closed_ok"], r["opens_ok"], r["toggles_ok"]])


# ---------------------------------------------------------------------------------------------------- task 4: UiHints, HintBar

func _hint_glyphs_follow_device(t) -> void:
	await UiAudit.device_swap(t, "keyboard")
	var start_keyboard := UiNav.device() == &"keyboard"
	var kb := {"interact": UiHints.glyph(&"interact"), "ui_accept": UiHints.glyph(&"ui_accept"), "ui_cancel": UiHints.glyph(&"ui_cancel"), "pause": UiHints.glyph(&"pause"),
		"jump": UiHints.glyph(&"jump"), "page": UiHints.glyph_pair(&"ui_page_up", &"ui_page_down"), "updown": UiHints.glyph_pair(&"ui_up", &"ui_down"),
		"leftright": UiHints.glyph_pair(&"ui_left", &"ui_right"), "dirs": UiHints.glyph_set([&"ui_up", &"ui_down", &"ui_left", &"ui_right"]), "use_tool": UiHints.glyph(&"use_tool")}
	var kb_ok: bool = kb["interact"] == "E" and kb["ui_accept"] == "Enter" and kb["ui_cancel"] == "Esc" and kb["pause"] == "Esc" and kb["page"] == "Q E" \
		and kb["updown"] == "↑↓" and kb["leftright"] == "←→" and kb["dirs"] == "↑↓←→" and kb["jump"] == TranslationServer.translate("KEY_SPACE") and kb["use_tool"] == "X"
	await UiAudit.device_swap(t, "pad")
	var flipped := UiNav.device() == &"gamepad"
	var pad := {"interact": UiHints.glyph(&"interact"), "ui_accept": UiHints.glyph(&"ui_accept"), "ui_cancel": UiHints.glyph(&"ui_cancel"), "pause": UiHints.glyph(&"pause"),
		"page": UiHints.glyph_pair(&"ui_page_up", &"ui_page_down"), "updown": UiHints.glyph_pair(&"ui_up", &"ui_down"), "dirs": UiHints.glyph_set([&"ui_up", &"ui_down", &"ui_left", &"ui_right"]),
		"focus_next": UiHints.glyph(&"ui_focus_next"), "dodge": UiHints.glyph(&"dodge"), "light": UiHints.glyph(&"light")}
	var pad_ok: bool = pad["interact"] == "A" and pad["ui_accept"] == "A" and pad["ui_cancel"] == "B" and pad["pause"] == TranslationServer.translate("NAV_PAD_START") \
		and pad["page"] == "LB RB" and pad["updown"] == "D-pad" and pad["dirs"] == "D-pad" and pad["focus_next"] == "" and pad["dodge"] == "B" and pad["light"] == "Y"
	await UiAudit.device_swap(t, "keyboard")
	var back := UiNav.device() == &"keyboard" and UiHints.glyph(&"interact") == "E"
	# stick noise below 0.5 and a mouse jitter do not flip it; a real stick push and a real mouse move do
	await UiAudit.device_swap(t, "pad")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.3
	t.root.push_input(stick)
	var jitter := InputEventMouseMotion.new()
	jitter.position = Vector2(10, 10)
	jitter.relative = Vector2(1, 0)
	t.root.push_input(jitter)
	await t.frames(1)
	var noise_ok := UiNav.device() == &"gamepad"
	var move := InputEventMouseMotion.new()
	move.position = Vector2(20, 10)
	move.relative = Vector2(8, 0)
	t.root.push_input(move)
	await t.frames(1)
	var mouse_ok := UiNav.device() == &"keyboard"
	var push := InputEventJoypadMotion.new()
	push.axis = JOY_AXIS_LEFT_Y
	push.axis_value = 0.9
	t.root.push_input(push)
	await t.frames(1)
	var stick_ok := UiNav.device() == &"gamepad"
	# an InputEventAction is synthetic: it never counts
	var act := InputEventAction.new()
	act.action = &"ui_accept"
	act.pressed = true
	t.root.push_input(act)
	await t.frames(1)
	var action_ok := UiNav.device() == &"gamepad"
	# a click counts as the keyboard side (mouse)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(50, 50)
	t.root.push_input(click)
	await t.frames(1)
	var click_ok := UiNav.device() == &"keyboard"
	# the explicit device argument ignores the live device; the watcher announces changes
	var explicit_ok := UiHints.glyph(&"interact", &"gamepad") == "A" and UiHints.glyph(&"interact", &"keyboard") == "E"
	var seen: Array[StringName] = []
	UiNav.watcher().device_changed.connect(func(d: StringName) -> void: seen.append(d))
	await UiAudit.device_swap(t, "pad")
	await UiAudit.device_swap(t, "pad")
	await UiAudit.device_swap(t, "keyboard")
	var signal_ok: bool = seen == [&"gamepad", &"keyboard"]
	# format: tr(key) with %s := the glyph (the replacement of the literal-E DIALOGUE_CONTINUE_HINT)
	var fmt := UiHints.format("HINT_CONTINUE", &"interact")
	var fmt_ok: bool = fmt == "E for at fortsætte"
	TranslationServer.set_locale("en")
	var fmt_en := UiHints.format("HINT_CONTINUE", &"interact")
	TranslationServer.set_locale("da")
	t.check("hint_glyphs_follow_device", start_keyboard and kb_ok and flipped and pad_ok and back and noise_ok and mouse_ok and stick_ok and action_ok and click_ok and explicit_ok and signal_ok and fmt_ok and fmt_en == "E to continue",
		"keyboard E / Enter / Esc %s -> pad A / A / B %s -> keyboard %s; stick < 0.5 and a mouse jitter do not flip (%s), a real mouse move (%s) and stick push (%s) do, an action never does (%s), a click does (%s); device_changed fires once per change (%s); format: %s / %s" % [kb_ok, pad_ok, back, noise_ok, mouse_ok, stick_ok, action_ok, click_ok, signal_ok, fmt, fmt_en])
	await UiAudit.device_swap(t, "keyboard")


func _hint_bar_localized(t) -> void:
	var host := _fresh(t)
	var bar: HintBar = (load("res://scenes/ui/components/hint_bar.tscn") as PackedScene).instantiate()
	host.add_child(bar)
	await t.frames(2)
	var empty_hidden := not bar.visible
	bar.set_hints([{"pair": [&"ui_up", &"ui_down"], "key": "HINT_MOVE"}, {"action": &"ui_accept", "key": "HINT_OK"}, {"action": &"ui_cancel", "key": "HINT_BACK"}, {"action": &"ui_focus_next", "key": "HINT_NEXT_FIELD"}])
	await t.frames(1)
	var da := bar.shown()
	var da_ok: bool = bar.visible and da.size() == 4 and str(da) == str([{"glyph": "↑↓", "text": "Vælg"}, {"glyph": "Enter", "text": "OK"}, {"glyph": "Esc", "text": "Tilbage"}, {"glyph": "Tab", "text": "Næste felt"}])
	if not da_ok:
		t.info("hint bar shows %s" % str(da))
	var caps_ok: bool = bar.get_child_count() == 4 * 2 + 3 and (bar.get_child(0) as Label).theme_type_variation == &"KeyCap" and (bar.get_child(1) as Label).theme_type_variation == &"Eyebrow" and (bar.get_child(2) as Label).text == "·"
	var da_raw: Array = t.find_raw_keys(bar)
	TranslationServer.set_locale("en")
	await t.frames(2)
	var en := bar.shown()
	var en_ok: bool = en[0]["text"] == "Select" and en[2]["text"] == "Back" and (bar.get_child(1) as Label).text == "Select"
	var en_raw: Array = t.find_raw_keys(bar)
	TranslationServer.set_locale("da")
	await t.frames(2)
	await UiAudit.device_swap(t, "pad")
	var pad := bar.shown()
	var pad_ok: bool = pad.size() == 3 and pad[0]["glyph"] == "D-pad" and pad[1]["glyph"] == "A" and pad[2]["glyph"] == "B" and bar.get_child_count() == 8 and (bar.get_child(0) as Label).text == "D-pad"   # Tab has no pad button: that hint is left out
	if not pad_ok:
		t.info("hint bar on a pad shows %s (%d children)" % [str(pad), bar.get_child_count()])
	await UiAudit.device_swap(t, "keyboard")
	var back_ok: bool = bar.shown().size() == 4 and bar.get_child_count() == 11 and (bar.get_child(0) as Label).text == "↑↓"
	var passive: bool = bar.mouse_filter == Control.MOUSE_FILTER_IGNORE and bar.focus_mode == Control.FOCUS_NONE
	for c in bar.get_children():
		passive = passive and (c as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE and (c as Control).focus_mode == Control.FOCUS_NONE
	bar.force_hidden = true
	await UiAudit.device_swap(t, "pad")
	await UiAudit.device_swap(t, "keyboard")
	var forced_ok := not bar.visible                                  # a device change must not bring a fixture-hidden bar back
	bar.force_hidden = false
	bar.set_hints([])
	var cleared_ok := not bar.visible
	# no signal is connected twice by re-entering the tree
	host.remove_child(bar)
	host.add_child(bar)
	await t.frames(1)
	var conns: int = UiNav.watcher().device_changed.get_connections().filter(func(c: Dictionary) -> bool: return c["callable"].get_object() == bar).size()
	t.check("hint_bar_localized", empty_hidden and da_ok and caps_ok and da_raw.is_empty() and en_ok and en_raw.is_empty() and pad_ok and back_ok and passive and forced_ok and cleared_ok and conns == 1,
		"empty bar hidden (%s); da glyph + word pairs (%s), KeyCap + Eyebrow labels with a separator (%s); a language switch re-renders it, no raw keys in either locale (%s / %s); a pad swap re-renders and leaves out the key that has no pad button (%s / %s); passive controls (%s); force_hidden sticks (%s); empty list hides (%s); one device connection (%d)" % [empty_hidden, da_ok, caps_ok, en_ok, da_raw.is_empty() and en_raw.is_empty(), pad_ok, back_ok, passive, forced_ok, cleared_ok, conns])
	await _finish_test(t)


func _prompt_prefix_glyph(t) -> void:
	var a := UiHints.split_prompt("E: Sov")
	var b := UiHints.split_prompt("E · Tal med Pippin")
	var c := UiHints.split_prompt("Sov: i sengen")
	var d := UiHints.split_prompt("Sov")
	var e := UiHints.split_prompt("e: lowercase is no key")
	var f := UiHints.split_prompt("")
	var g := UiHints.split_prompt("1: Vælg")
	var h := UiHints.split_prompt("EE: two letters")
	var ok: bool = a == {"key": true, "token": "E", "rest": "Sov"} and b == {"key": true, "token": "E", "rest": "Tal med Pippin"} and c == {"key": false, "token": "", "rest": "Sov: i sengen"} \
		and d["key"] == false and d["rest"] == "Sov" and e["key"] == false and f["key"] == false and g["key"] == true and g["rest"] == "Vælg" and h["key"] == false
	# the real prompt strings of the game keep their key in the text and split cleanly in both languages
	var real_ok := true
	for key in ["UI_SLEEP", "WORLD_PROMPT_USE", "UI_READ"]:
		for loc in ["da", "en"]:
			TranslationServer.set_locale(loc)
			var sp := UiHints.split_prompt(TranslationServer.translate(key))
			real_ok = real_ok and sp["key"] == true and str(sp["rest"]) != "" and not str(sp["rest"]).begins_with(":")
	TranslationServer.set_locale("da")
	var key_ok: bool = UiHints.is_key("NOTIF_QUEST_ACCEPTED_TITLE") and UiHints.is_key("UI_SLEEP") and not UiHints.is_key("E: Sov") and not UiHints.is_key("OK") and not UiHints.is_key("Ny opgave!")
	t.check("prompt_prefix_glyph", ok and real_ok and key_ok, "split_prompt: 'E: Sov' / 'E · Tal med X' -> key token + verb, a plain 'Sov: i sengen', a lower-case or two-letter prefix and an empty text are not keys (%s); UI_SLEEP, WORLD_PROMPT_USE and UI_READ split in da and en (%s); is_key (%s)" % [ok, real_ok, key_ok])


# ---------------------------------------------------------------------------------------------------- task 5: UiConfirm

## Runs UiConfirm.ask in the background: the result lands in box["result"] when the dialog is answered.
func _ask_bg(asker: Control, box: Dictionary, title := "UI_CONFIRM_TITLE", text := "UI_CONFIRM_OVERWRITE", ok := "NAV_OK", default := &"cancel") -> void:
	box["done"] = false
	box["result"] = await UiConfirm.ask(asker, title, text, ok, "NAV_CANCEL", default, [2])
	box["done"] = true


func _ask_text_bg(asker: Control, box: Dictionary, initial: String, max_len: int) -> void:
	box["done"] = false
	box["result"] = await UiConfirm.ask_text(asker, "UI_CONFIRM_TITLE", initial, max_len)
	box["done"] = true


func _dialog(host: Control) -> UiConfirm:
	for c in host.get_children():
		if c is UiConfirm:
			return c as UiConfirm
	return null


func _confirm_default_focus_and_escape(t) -> void:
	var host := _fresh(t)
	var world := WorldProbe.new()
	host.add_child(world)
	var asker := _button_at(host, "Asker", Vector2(100, 100))
	await t.frames(1)
	asker.grab_focus()
	await t.frames(1)
	var box := {}
	_ask_bg(asker.get_parent(), box)
	await t.frames(2)
	var dlg := _dialog(host)
	var last_child: bool = dlg != null and host.get_child(host.get_child_count() - 1) == dlg and dlg.top_level
	var on_cancel: bool = dlg != null and _owner_name(t) == "CancelButton"
	var stack: Array = _gm.call("modal_stack")
	var pushed: bool = stack == [&"confirm"] and not t.tree.paused                          # the pause state is the CURRENT one: not paused -> not paused
	var texts_ok: bool = dlg != null and (dlg.get_node("%TitleLabel") as Label).text == "Bekræft" and (dlg.get_node("%TextLabel") as Label).text == "Overskriv slot 2?" \
		and (dlg.get_node("%OkButton") as Button).text == "OK" and (dlg.get_node("%CancelButton") as Button).text == "Fortryd"
	await _tap(t, KEY_ESCAPE)
	await t.frames(1)
	var esc_ok: bool = bool(box["done"]) and box["result"] == false and _dialog(host) == null and (_gm.call("modal_stack") as Array).is_empty() and _owner_name(t) == "Asker" and not world.seen.has(&"pause")
	# default OK; Enter on the focused default answers yes; the closing Enter never reaches the world
	box = {}
	_ask_bg(asker.get_parent(), box, "UI_CONFIRM_TITLE", "UI_CONFIRM_LOAD", "NAV_OK", &"ok")
	await t.frames(2)
	var on_ok := _owner_name(t) == "OkButton"
	world.seen.clear()
	await _tap(t, KEY_ENTER)
	await t.frames(1)
	var enter_yes: bool = bool(box["done"]) and box["result"] == true and world.seen.is_empty()
	# Enter on the harmless default says no; the buttons swap with Left / Right
	box = {}
	_ask_bg(asker.get_parent(), box)
	await t.frames(2)
	await _tap(t, KEY_RIGHT)
	var swapped := _owner_name(t) == "OkButton"
	await _tap(t, KEY_LEFT)
	var swapped_back := _owner_name(t) == "CancelButton"
	await _tap(t, KEY_ENTER)
	await t.frames(1)
	var enter_no: bool = bool(box["done"]) and box["result"] == false
	# the gamepad: B and Start cancel, A presses the focused one
	box = {}
	_ask_bg(asker.get_parent(), box, "UI_CONFIRM_TITLE", "UI_CONFIRM_DELETE", "NAV_OK", &"ok")
	await t.frames(2)
	await _pad(t, JOY_BUTTON_B)
	await t.frames(1)
	var b_no: bool = bool(box["done"]) and box["result"] == false
	box = {}
	_ask_bg(asker.get_parent(), box)
	await t.frames(2)
	await _pad(t, JOY_BUTTON_START)
	await t.frames(1)
	var start_no: bool = bool(box["done"]) and box["result"] == false
	box = {}
	_ask_bg(asker.get_parent(), box, "UI_CONFIRM_TITLE", "UI_CONFIRM_LOAD", "NAV_OK", &"ok")
	await t.frames(2)
	await _pad(t, JOY_BUTTON_A)
	await t.frames(1)
	var a_yes: bool = bool(box["done"]) and box["result"] == true
	# a click on the buttons works, a click on the scrim does nothing
	box = {}
	_ask_bg(asker.get_parent(), box)
	await t.frames(3)
	dlg = _dialog(host)
	t.click(Vector2(20, 20))
	await t.frames(2)
	var scrim_ok: bool = not bool(box["done"]) and dlg != null
	var ok_btn: Button = dlg.get_node("%OkButton")
	t.click(ok_btn.get_global_rect().get_center())
	await t.frames(2)
	var click_yes: bool = bool(box["done"]) and box["result"] == true
	# inside a paused tree (a pausing modal under it): it pushes `confirm` as pausing, and the tree stays paused afterwards
	_gm.call("push_modal", &"nav_under", true)
	await t.frames(1)
	var paused_before: bool = t.tree.paused
	box = {}
	_ask_bg(asker.get_parent(), box)
	await t.frames(2)
	var still_paused: bool = t.tree.paused and (_gm.call("modal_stack") as Array) == [&"nav_under", &"confirm"]
	await _tap(t, KEY_ESCAPE)
	await t.frames(1)
	var after_paused: bool = t.tree.paused and (_gm.call("modal_stack") as Array) == [&"nav_under"] and bool(box["done"])
	_gm.call("pop_modal", &"nav_under")
	# language switch re-labels an open dialog
	box = {}
	_ask_bg(asker.get_parent(), box)
	await t.frames(2)
	dlg = _dialog(host)
	TranslationServer.set_locale("en")
	await t.frames(2)
	var en_ok: bool = (dlg.get_node("%TitleLabel") as Label).text == "Confirm" and (dlg.get_node("%CancelButton") as Button).text == "Cancel" and (dlg.get_node("%TextLabel") as Label).text == "Overwrite slot 2?"
	TranslationServer.set_locale("da")
	await _tap(t, KEY_ESCAPE)
	await t.frames(1)
	var cleared := _dialog(host) == null and (_gm.call("modal_stack") as Array).is_empty()
	t.check("confirm_default_focus_and_escape", last_child and on_cancel and pushed and texts_ok and esc_ok and on_ok and enter_yes and swapped and swapped_back and enter_no and b_no and start_no and a_yes and scrim_ok and click_yes and paused_before and still_paused and after_paused and en_ok and cleared,
		"last child of the asker (%s), default answer focused (%s / %s), pushes `confirm` without changing the pause state (%s / %s / %s), texts (%s); Esc cancels and focus returns (%s); Enter yes / no, swap, B, Start, A (%s %s %s %s %s %s %s); scrim click inert, button click answers (%s / %s); language switch (%s); stack clean (%s)" % [last_child, on_cancel, on_ok, pushed, still_paused, after_paused, texts_ok, esc_ok, enter_yes, enter_no, swapped and swapped_back, b_no, start_no, a_yes, paused_before, scrim_ok, click_yes, en_ok, cleared])
	await _finish_test(t)


func _confirm_traps_focus(t) -> void:
	var host := _fresh(t)
	var asker := _button_at(host, "Asker", Vector2(100, 100))
	await t.frames(1)
	asker.grab_focus()
	var box := {}
	_ask_bg(host, box)
	await t.frames(2)
	var dlg := _dialog(host)
	var codes := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB, KEY_W, KEY_S, KEY_A, KEY_D]
	var inside := 0
	var left_dialog := 0
	for i in 50:
		var code: int = codes[t.rng.randi() % codes.size()]
		if code == KEY_TAB and t.rng.randi() % 2 == 0:
			var ev := InputEventKey.new()
			ev.keycode = KEY_TAB
			ev.physical_keycode = KEY_TAB
			ev.shift_pressed = true
			ev.pressed = true
			t.root.push_input(ev)
			ev = ev.duplicate() as InputEventKey
			ev.pressed = false
			t.root.push_input(ev)
			await t.frames(1)
		else:
			await _tap(t, code)
		var f: Control = t.root.gui_get_focus_owner()
		if f != null and (f.name == &"CancelButton" or f.name == &"OkButton") and dlg.is_ancestor_of(f):
			inside += 1
		else:
			left_dialog += 1
	# the audit's own definition of a trap: focusable inventory, walk
	var focusable := UiAudit.focusable_report(dlg)
	var walk: Dictionary = await UiAudit.focus_walk(t, dlg, 100)
	var walk_ok: bool = (walk["traps"] as Array).is_empty() and (walk["unreachable"] as Array).is_empty() and bool(walk.get("cycle_down", true))
	await _tap(t, KEY_ESCAPE)
	await t.frames(1)
	t.check("confirm_traps_focus", left_dialog == 0 and inside == 50 and walk_ok and (focusable["defects"] as Array).is_empty() and bool(box["done"]),
		"50 random Up / Down / Left / Right / Tab / Shift+Tab / WASD presses never leave the two buttons (%d inside, %d outside); the audit walk finds no trap and no unreachable control (%s), the focusable report no defect" % [inside, left_dialog, walk_ok])
	await _finish_test(t)


func _confirm_ask_text(t) -> void:
	var host := _fresh(t)
	var asker := _button_at(host, "Asker", Vector2(100, 100))
	await t.frames(1)
	asker.grab_focus()
	var box := {}
	_ask_text_bg(host, box, "Fido", 6)
	await t.frames(2)
	var dlg := _dialog(host)
	var field: LineEdit = dlg.get_node("%Field")
	var shape_ok: bool = field.visible and not (dlg.get_node("%TextLabel") as Label).visible and field.text == "Fido" and field.max_length == 6 and _owner_name(t) == "Field" and field.select_all_on_focus
	await _typed(t, "Rex")                                       # the text is selected: typing replaces it
	var typed_ok: bool = field.text == "Rex"
	await _tap(t, KEY_ENTER)
	await t.frames(1)
	var enter_ok: bool = bool(box["done"]) and box["result"] == "Rex" and _owner_name(t) == "Asker" and _dialog(host) == null
	# Esc cancels with ""
	box = {}
	_ask_text_bg(host, box, "Fido", 6)
	await t.frames(2)
	await _typed(t, "Ab")
	await _tap(t, KEY_ESCAPE)
	await t.frames(1)
	var esc_ok: bool = bool(box["done"]) and box["result"] == "" and (_gm.call("modal_stack") as Array).is_empty()
	# the length cap
	box = {}
	_ask_text_bg(host, box, "", 6)
	await t.frames(2)
	await _typed(t, "abcdefghij")
	dlg = _dialog(host)
	var cap_ok: bool = (dlg.get_node("%Field") as LineEdit).text == "abcdef"
	# OK by button (Down from the field -> OK, Enter), the text is stripped
	(dlg.get_node("%Field") as LineEdit).text = "  Rex "
	await _tap(t, KEY_DOWN)
	var down_ok := _owner_name(t) == "OkButton"
	await _tap(t, KEY_ENTER)
	await t.frames(1)
	var strip_ok: bool = bool(box["done"]) and box["result"] == "Rex" and down_ok
	# an empty text counts as cancelled; the Cancel button too
	box = {}
	_ask_text_bg(host, box, "", 6)
	await t.frames(2)
	await _tap(t, KEY_ENTER)
	await t.frames(1)
	var empty_ok: bool = bool(box["done"]) and box["result"] == ""
	box = {}
	_ask_text_bg(host, box, "Fido", 6)
	await t.frames(2)
	dlg = _dialog(host)
	(dlg.get_node("%CancelButton") as Button).grab_focus()
	await t.frames(1)
	await _tap(t, KEY_ENTER)
	await t.frames(1)
	var cancel_ok: bool = bool(box["done"]) and box["result"] == ""
	# Up / Down leave the field (F7) and come back; Tab walks field -> Fortryd -> OK -> field
	box = {}
	_ask_text_bg(host, box, "Fido", 6)
	await t.frames(2)
	await _tap(t, KEY_TAB)
	var tab1 := _owner_name(t) == "CancelButton"
	await _tap(t, KEY_TAB)
	var tab2 := _owner_name(t) == "OkButton"
	await _tap(t, KEY_TAB)
	var tab3 := _owner_name(t) == "Field"
	await _tap(t, KEY_ESCAPE)
	await t.frames(1)
	t.check("confirm_ask_text", shape_ok and typed_ok and enter_ok and esc_ok and cap_ok and strip_ok and empty_ok and cancel_ok and tab1 and tab2 and tab3,
		"ask_text shows the field with the initial text selected, max length and the field focused (%s); typing + Enter returns the text (%s / %s); Esc returns \"\" (%s); the cap holds (%s); OK by button strips (%s); an empty text and the Cancel button return \"\" (%s / %s); Tab ring field -> Fortryd -> OK -> field (%s %s %s)" % [shape_ok, typed_ok, enter_ok, esc_ok, cap_ok, strip_ok, empty_ok, cancel_ok, tab1, tab2, tab3])
	await _finish_test(t)


# ---------------------------------------------------------------------------------------------------- task 6: the shared widgets

func _toast_stack(t, host: Control) -> ToastStack:
	var stack: ToastStack = (load("res://scenes/ui/components/toast_stack.tscn") as PackedScene).instantiate()
	host.add_child(stack)
	await t.frames(2)
	return stack


func _toast_texts(stack: ToastStack) -> Array[String]:
	var out: Array[String] = []
	for toast in stack.toasts():
		out.append("%s | %s" % [toast.title_label.text, toast.message_label.text])
	return out


func _toast_stack_caps_and_rarity(t) -> void:
	var host := _fresh(t)
	var stack := await _toast_stack(t, host)
	var focus_free: bool = UiAudit.focusable_report(stack, {"forbid_focus": true})["defects"].is_empty() and stack.mouse_filter == Control.MOUSE_FILTER_IGNORE
	for i in 5:
		_bus.notification_posted.emit("Titel %d" % i, "Besked %d" % i, "farm")
	await t.frames(3)
	var texts := _toast_texts(stack)
	var cap_ok: bool = texts.size() == 3 and texts[0] == "Titel 4 | Besked 4" and texts[2] == "Titel 2 | Besked 2"                   # at most 3, the NEWEST ON TOP, the oldest dropped
	var order_ok: bool = (stack.get_node("%Stack") as Control).get_child_count() == 3 and (stack.get_node("%Stack").get_child(0) as Control).get_global_rect().position.y < (stack.get_node("%Stack").get_child(2) as Control).get_global_rect().position.y
	var top_y := (stack.get_node("%Stack").get_child(0) as Control).get_global_rect().position.y
	var centre_x := (stack.get_node("%Stack").get_child(0) as Control).get_global_rect().get_center().x
	var place_ok: bool = absf(top_y - 96.0) <= 2.0 and absf(centre_x - 640.0) <= 4.0                                                   # the top centre, from y = 96
	# stacked counts: item gains with the same title and the same item add up, plain repeats count
	_drop_host()
	host = _fresh(t)
	stack = await _toast_stack(t, host)
	for n in [1, 2, 3]:
		_bus.notification_posted.emit("Fået genstand", "Månesten x%d" % n, "item")
	_bus.notification_posted.emit("Fået genstand", "Gulerod x1", "item")
	_bus.notification_posted.emit("Spil gemt", "Slot 1", "save")
	_bus.notification_posted.emit("Spil gemt", "Slot 1", "save")
	await t.frames(2)
	var stacked := _toast_texts(stack)
	var stack_ok: bool = stacked == ["Spil gemt ×2 | Slot 1", "Fået genstand | Gulerod x1", "Fået genstand | Månesten x6"]
	# a repeated toast moves back on top and restarts its fade (one node, not a new one)
	var carrot_toast: Node = stack.toasts()[1]
	_bus.notification_posted.emit("Fået genstand", "Gulerod x4", "item")
	await t.frames(2)
	var moved_ok: bool = stack.toasts()[0] == carrot_toast and _toast_texts(stack)[0] == "Fået genstand | Gulerod x5" and stack.toasts().size() == 3
	# loc keys run tr() (quest toasts of Lua), follow the language, and are shown as they are otherwise
	_drop_host()
	host = _fresh(t)
	stack = await _toast_stack(t, host)
	_bus.notification_posted.emit("NOTIF_QUEST_ACCEPTED_TITLE", "QUEST_LOST_CAT_TITLE", "quest")
	_bus.notification_posted.emit("Ny opgave!", "Fint nok", "quest")
	await t.frames(2)
	var tr_da := _toast_texts(stack)
	TranslationServer.set_locale("en")
	await t.frames(2)
	var tr_en := _toast_texts(stack)
	TranslationServer.set_locale("da")
	await t.frames(1)
	TranslationServer.set_locale("en")
	var cat_en := str(TranslationServer.translate("QUEST_LOST_CAT_TITLE"))
	var accepted_en := str(TranslationServer.translate("NOTIF_QUEST_ACCEPTED_TITLE"))
	TranslationServer.set_locale("da")
	var cat_da := str(TranslationServer.translate("QUEST_LOST_CAT_TITLE"))
	var accepted_da := str(TranslationServer.translate("NOTIF_QUEST_ACCEPTED_TITLE"))
	var loc_ok: bool = cat_da != cat_en and accepted_da != accepted_en and tr_da == ["Ny opgave! | Fint nok", "%s | %s" % [accepted_da, cat_da]] and tr_en == ["Ny opgave! | Fint nok", "%s | %s" % [accepted_en, cat_en]]
	if not loc_ok:
		t.info("toast texts da %s en %s" % [str(tr_da), str(tr_en)])
	var raw_ok: bool = t.find_raw_keys(stack).is_empty()
	# rarity: the item picture sits on the tile of Rarity.ui(rarity); the item's rarity comes from the item_gained that EconomyManager emits just before the "item" notification
	var best := &""
	var best_rank := 0
	for id in ItemKinds.all_ids():
		var r := ItemKinds.rarity_of(id)
		if Rarity.rank(r) > best_rank:
			best = StringName(id)
			best_rank = Rarity.rank(r)
	_drop_host()
	host = _fresh(t)
	stack = await _toast_stack(t, host)
	_bus.item_gained.emit(best, 1)
	_bus.notification_posted.emit("Fået genstand", "Fund x1", "item")
	await t.frames(2)
	var rare_toast: Node = stack.toasts()[0]
	var tile := rare_toast.get_node_or_null("%IconFrame/RarityTile") as RaritySlot
	var rarity_ok: bool = best != &"" and best_rank >= 4 and tile != null and tile.rarity == ItemKinds.rarity_of(best) and tile.item_id == best and tile.current_plan()["state"] == "filled" and not (rare_toast.get_node("%Icon") as Control).visible
	var ring_ok: bool = tile != null and (tile.current_plan()["fill"] as Color).is_equal_approx(Rarity.ui(tile.rarity)["fill"])
	# an item id as the icon works as well; a kind of notification ("farm") has no tile; an "item" notification NOT paired with item_gained has none either
	_bus.notification_posted.emit("Fund", "Til dig", String(best))
	_bus.notification_posted.emit("Fået genstand", "Ukendt x1", "item")
	_bus.notification_posted.emit("Gården", "Hej", "farm")
	await t.frames(2)
	var ts := stack.toasts()
	var kinds_ok: bool = ts.size() == 3 and ts[0].get_node_or_null("%IconFrame/RarityTile") == null and ts[1].get_node_or_null("%IconFrame/RarityTile") == null and ts[2].get_node_or_null("%IconFrame/RarityTile") != null
	# the forest HUD leaves item notifications to the loot feed
	stack.item_toasts = false
	var before := stack.toasts().size()
	_bus.item_gained.emit(best, 1)
	_bus.notification_posted.emit("Fået genstand", "Fund x1", "item")
	_bus.notification_posted.emit("Fund", "Id", String(best))
	await t.frames(1)
	var forest_ok: bool = stack.toasts().size() == before
	# the second setup of a toast replaces its fade (ui_foundation.toast_second_setup): the stack relies on it, one tween per toast
	t.check("toast_stack_caps_and_rarity", focus_free and cap_ok and order_ok and place_ok and stack_ok and moved_ok and loc_ok and raw_ok and rarity_ok and ring_ok and kinds_ok and forest_ok,
		"IGNORE / FOCUS_NONE (%s); five posts leave 3, newest on top (%s / %s), at the top centre y = 96 (%s: y %.0f, centre %.0f); counts stack (%s: %s), a repeat moves back on top (%s); keys run tr() and follow the language (%s), no raw keys (%s); a %s item shows its tile of Rarity.ui (%s / %s), kinds without an item have none (%s); item_toasts = false leaves them to the loot feed (%s)" % [focus_free, cap_ok, order_ok, place_ok, top_y, centre_x, stack_ok, str(stacked), moved_ok, loc_ok, raw_ok, str(best), rarity_ok, ring_ok, kinds_ok, forest_ok])
	await _finish_test(t)


func _prompt_pill_follows_device(t) -> void:
	await UiAudit.device_swap(t, "keyboard")
	var host := _fresh(t)
	var pill: PromptPill = (load("res://scenes/ui/components/prompt_pill.tscn") as PackedScene).instantiate()
	host.add_child(pill)
	await t.frames(2)
	var hidden_ok: bool = not pill.shown()["visible"]
	_bus.interaction_prompt_changed.emit("E: Sov")
	await t.frames(2)
	var kb := pill.shown()
	var kb_ok: bool = kb["visible"] and kb["key"] and kb["cap"] == "E" and kb["verb"] == "Sov"
	var placed := (pill.get_node("%Pill") as Control).get_global_rect()
	var place_ok: bool = absf(placed.end.y - (720.0 - 160.0)) <= 2.0 and absf(placed.get_center().x - 640.0) <= 2.0         # centred, 160 above the bottom
	await UiAudit.device_swap(t, "pad")
	var pad := pill.shown()
	var pad_ok: bool = pad["cap"] == "A" and pad["verb"] == "Sov" and (pill.get_node("%KeyCap") as Label).text == "A"
	await UiAudit.device_swap(t, "keyboard")
	var back_ok: bool = pill.shown()["cap"] == "E"
	# the verb keeps its text; a verb-only prompt gets the cap of `interact` as well; "E · Tal med X" splits too
	_bus.interaction_prompt_changed.emit("E · Tal med Pippin")
	await t.frames(1)
	var talk_ok: bool = pill.shown()["verb"] == "Tal med Pippin" and pill.shown()["cap"] == "E"
	_bus.interaction_prompt_changed.emit("Sov")
	await t.frames(1)
	var verb_only: bool = pill.shown()["verb"] == "Sov" and pill.shown()["key"] and pill.shown()["cap"] == "E"
	# a translation key is translated and follows the language
	_bus.interaction_prompt_changed.emit("UI_SLEEP")
	await t.frames(1)
	var key_da: bool = pill.shown()["verb"] == "Sov"
	TranslationServer.set_locale("en")
	await t.frames(2)
	var key_en: bool = pill.shown()["verb"] == "Sleep"
	TranslationServer.set_locale("da")
	await t.frames(1)
	# an empty text hides the pill
	_bus.interaction_prompt_changed.emit("")
	await t.frames(1)
	var cleared: bool = not pill.shown()["visible"]
	# not focusable, not clickable; the look is the theme's PromptPill (ink pill, 2 px gold border)
	var inert: bool = UiAudit.focusable_report(pill, {"forbid_focus": true})["defects"].is_empty() and pill.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var look: StyleBox = (pill.get_node("%Pill") as Control).get_theme_stylebox("panel")
	var look_ok: bool = look != null and look == pill.get_theme_stylebox("normal", "PromptPill")
	var conns: int = _bus.interaction_prompt_changed.get_connections().filter(func(c: Dictionary) -> bool: return c["callable"].get_object() == pill).size()
	t.check("prompt_pill_follows_device", hidden_ok and kb_ok and place_ok and pad_ok and back_ok and talk_ok and verb_only and key_da and key_en and cleared and inert and look_ok and conns == 1,
		"hidden at first (%s); 'E: Sov' -> cap E + verb Sov at the bottom centre (%s / %s); a pad swap flips the cap to A and back (%s / %s); 'E · Tal med Pippin' (%s), a verb-only prompt gets the cap (%s); a key is translated (%s) and follows the language (%s); empty hides (%s); inert (%s); the theme look (%s); one connection (%d)" % [hidden_ok, kb_ok, place_ok, pad_ok, back_ok, talk_ok, verb_only, key_da, key_en, cleared, inert, look_ok, conns])
	await _finish_test(t)


func _whisper_line(t) -> void:
	var host := _fresh(t)
	var whisper: WhisperLine = (load("res://scenes/ui/components/whisper_line.tscn") as PackedScene).instantiate()
	host.add_child(whisper)
	await t.frames(2)
	var hidden_ok := not whisper.is_showing()
	_bus.whisper_requested.emit("WHISPER_TOO_EARLY")
	await t.frames(3)
	var panel := whisper.get_node("%Panel") as PanelContainer
	var da_text := TranslationServer.translate("WHISPER_TOO_EARLY")
	var shows: bool = whisper.is_showing() and whisper.shown_text() == da_text and panel.theme_type_variation == &"PanelWhisper" and (whisper.get_node("%Text") as Label).theme_type_variation == &"Whisper"
	var rect := panel.get_global_rect()
	var place_ok: bool = absf(rect.position.x - 40.0) <= 2.0 and absf(rect.end.y - (720.0 - 40.0)) <= 2.0 and rect.size.x <= 360.5          # left 40, bottom 40, at most 360 wide
	var long_ok: bool = da_text.length() > 40 and (whisper.get_node("%Text") as Label).autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
	# a short whisper hugs its text
	_bus.whisper_requested.emit("NAV_OK")
	await t.frames(3)
	var short_ok: bool = whisper.shown_text() == "OK" and panel.get_global_rect().size.x < 140.0
	_bus.whisper_requested.emit("WHISPER_FAINT")
	await t.frames(3)
	var replaced: bool = whisper.shown_text() == TranslationServer.translate("WHISPER_FAINT")
	TranslationServer.set_locale("en")
	await t.frames(2)
	var en_ok: bool = whisper.shown_text() == TranslationServer.translate("WHISPER_FAINT") and whisper.shown_text() != da_text
	TranslationServer.set_locale("da")
	await t.frames(1)
	var inert: bool = UiAudit.focusable_report(whisper, {"forbid_focus": true})["defects"].is_empty() and whisper.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var raw_ok: bool = t.find_raw_keys(whisper).is_empty()
	# 3.5 s, then it fades (0.4 s) and goes
	await t.seconds(3.0)
	var still_there := whisper.is_showing()
	await t.seconds(1.3)
	var gone := not whisper.is_showing()
	var conns: int = _bus.whisper_requested.get_connections().filter(func(c: Dictionary) -> bool: return c["callable"].get_object() == whisper).size()
	t.check("whisper_line", hidden_ok and shows and place_ok and long_ok and short_ok and replaced and en_ok and inert and raw_ok and still_there and gone and conns == 1,
		"hidden at first (%s); whisper_requested(key) shows tr(key) in a PanelWhisper with the Whisper italic (%s) at left 40 / bottom 40, at most 360 wide (%s) and wraps a long text (%s), a short one hugs its text (%s); a second whisper replaces it (%s) and it follows the language (%s); inert (%s), no raw keys (%s); still there after 3 s (%s) and gone after 3.5 s + fade (%s); one connection (%d)" % [hidden_ok, shows, place_ok, long_ok, short_ok, replaced, en_ok, inert, raw_ok, still_there, gone, conns])
	await _finish_test(t)


# ---------------------------------------------------------------------------------------------------- task 8: the amended stepper

func _stepper_one_stop_keys(t) -> void:
	var host := _fresh(t)
	var row := HBoxContainer.new()
	row.position = Vector2(100, 100)
	host.add_child(row)
	var left := _add(row, "Left")
	var stepper: PanelContainer = (load("res://scenes/ui/components/quantity_stepper.tscn") as PackedScene).instantiate()
	row.add_child(stepper)
	var right := _add(row, "Right")
	await t.frames(3)
	stepper.set_range(1, 9)
	var committed: Array[int] = []
	stepper.committed.connect(func(v: int) -> void: committed.append(v))
	var seen: Array[int] = []
	stepper.value_changed.connect(func(v: int) -> void: seen.append(v))
	var minus: Button = stepper.minus_button
	var plus: Button = stepper.plus_button
	# ONE focus stop: the root takes focus, the buttons are mouse-only (also the disabled "-"), the audit sees one stop
	var shape_ok: bool = stepper.focus_mode == Control.FOCUS_ALL and minus.focus_mode == Control.FOCUS_NONE and plus.focus_mode == Control.FOCUS_NONE and minus.disabled and stepper.has_meta(&"tt_focus_style")
	var rep := UiAudit.focusable_report(stepper)
	var audit_ok: bool = (rep["defects"] as Array).is_empty() and (rep["focusable"] as Array) == ["."] or (rep["focusable"] as Array) == [str(stepper.get_path_to(stepper))]
	audit_ok = (rep["defects"] as Array).is_empty() and (rep["focusable"] as Array).size() == 1
	var fixture := UiAudit.focusable_report(row)
	var row_ok: bool = (fixture["defects"] as Array).is_empty() and (fixture["focusable"] as Array).size() == 3          # Left, the stepper, Right: nothing inside the stepper
	stepper.grab_focus()
	await t.frames(1)
	# Left / Right: -1 / +1, a held key (echo) repeats
	await _tap(t, KEY_RIGHT)
	await _tap(t, KEY_RIGHT)
	var plus2: bool = stepper.value == 3
	await _tap(t, KEY_LEFT)
	var minus1: bool = stepper.value == 2
	await _echo(t, KEY_RIGHT)
	await _echo(t, KEY_RIGHT)
	var echo_ok: bool = stepper.value == 4
	# PageUp / PageDown +5 / -5 (clamped)
	await _tap(t, KEY_PAGEUP)
	var page_up: bool = stepper.value == 9
	await _tap(t, KEY_PAGEDOWN)
	var page_down: bool = stepper.value == 4
	await _tap(t, KEY_PAGEDOWN)
	var page_clamp: bool = stepper.value == 1
	# accept commits (Enter, Space and pad A), and does not change the value
	await _tap(t, KEY_ENTER)
	await _tap(t, KEY_SPACE)
	await _pad(t, JOY_BUTTON_A)
	var commit_ok: bool = committed == [1, 1, 1] and stepper.value == 1
	# the owner's keys stay in the stepper: it keeps focus
	var focused := stepper.has_focus()
	# pad: the D-pad moves the value, LB / RB are the page keys of the screen (not read here), A commits
	await _pad(t, JOY_BUTTON_DPAD_RIGHT)
	var dpad_ok: bool = stepper.value == 2
	# the disabled "-" is never a stop; the buttons still work with the mouse (they go through step_by)
	stepper.value = 1
	await t.frames(1)
	var disabled_ok: bool = minus.disabled and minus.focus_mode == Control.FOCUS_NONE and not minus.has_focus()
	t.click(plus.get_global_rect().get_center())
	await t.frames(2)
	var click_ok: bool = stepper.value == 2 and stepper.has_focus() == false or stepper.value == 2
	# at the end of the range a FRESH press goes on to focus navigation (a stepper in a row is no dead end), a held key does not
	stepper.value = 9
	stepper.grab_focus()
	await t.frames(1)
	await _echo(t, KEY_RIGHT)
	var echo_stays: bool = stepper.has_focus() and stepper.value == 9
	await _tap(t, KEY_RIGHT)
	var pass_right: bool = _owner_name(t) == "Right"
	stepper.value = 1
	stepper.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_LEFT)
	var pass_left: bool = _owner_name(t) == "Left"
	# the ring: the root paints PanelField/focus while it has focus (the guide's selection ring) and declares it
	var style: StyleBox = stepper.get_meta(&"tt_focus_style")
	var ring_ok: bool = style != null and style.get_script() == load("res://scripts/ui/theme/tt_box_style.gd") and (style.ring_colors as PackedColorArray).size() == 2 and (style.ring_colors as PackedColorArray)[0].is_equal_approx(Color("#e3c372"))
	t.check("stepper_one_stop_keys", shape_ok and audit_ok and row_ok and plus2 and minus1 and echo_ok and page_up and page_down and page_clamp and commit_ok and focused and dpad_ok and disabled_ok and click_ok and echo_stays and pass_right and pass_left and ring_ok and left != null and right != null and not seen.is_empty(),
		"one focus stop (%s), the audit sees one focusable and no defect (%s / %s); Right x2 / Left (%s / %s), a held key repeats (%s); PgUp +5 / PgDn -5 clamped (%s / %s / %s); Enter, Space and pad A commit (%s); D-pad (%s); the disabled '-' is no stop and the mouse buttons work (%s / %s); at the end of the range a held key stays (%s) and a fresh press moves on (%s / %s); the ring is PanelField/focus (%s)" % [shape_ok, audit_ok, row_ok, plus2, minus1, echo_ok, page_up, page_down, page_clamp, commit_ok, dpad_ok, disabled_ok, click_ok, echo_stays, pass_right, pass_left, ring_ok])
	await _finish_test(t)


# ---------------------------------------------------------------------------------------------------- task 10: the engine facts F1 - F14

## The facts probe Tab with no focus owner, with nothing focusable and so on: a screen another section left under the root (the audit's fixture screens do) would answer
## them. Every Control that already exists and can take focus is parked (focus_mode NONE) for the length of the facts and restored afterwards; the facts build their own.
func _park_foreign_stops(t) -> Array:
	var parked: Array = []
	var stack: Array[Node] = [t.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Control and (n as Control).focus_mode != Control.FOCUS_NONE:
			parked.append([n, (n as Control).focus_mode])
			(n as Control).focus_mode = Control.FOCUS_NONE
	t.root.gui_release_focus()
	return parked


func _restore_parked(parked: Array) -> void:
	for e in parked:
		if is_instance_valid(e[0]):
			(e[0] as Control).focus_mode = e[1]


func _facts_fail(facts: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	for k in facts:
		if not bool(facts[k]):
			bad.append(str(k))
	return bad


func _engine_facts(t) -> void:
	var facts := {}
	var parked := _park_foreign_stops(t)
	# ---- F1 / F2 / F3: focus without an owner, Tab, the order of the stages, letters
	var host := _fresh(t)
	var rec := KeyRecorder.new()
	host.add_child(rec)
	var col := VBoxContainer.new()
	col.position = Vector2(100, 100)
	host.add_child(col)
	var a := _add(col, "A")
	var b := _add(col, "B")
	var c := _add(col, "C")
	var dis := _add(col, "Dis")
	dis.disabled = true
	var le := LineEdit.new()
	le.name = "Edit"
	le.custom_minimum_size = Vector2(200, 36)
	col.add_child(le)
	await t.frames(3)
	t.root.gui_release_focus()
	await t.frames(1)
	UiAudit.press(t, &"ui_down")
	await t.frames(1)
	facts["F1_arrows_without_owner_do_nothing"] = t.root.gui_get_focus_owner() == null
	rec.in_keys.clear()
	rec.un_keys.clear()
	await _tap(t, KEY_TAB)
	facts["F1_tab_without_owner_focuses_the_first_and_is_consumed"] = _owner_name(t) == "A" and KEY_TAB in rec.in_keys and not (KEY_TAB in rec.un_keys)
	a.grab_focus()
	await t.frames(1)
	rec.in_keys.clear()
	rec.un_keys.clear()
	await _tap(t, KEY_TAB)
	facts["F2_gui_stage_consumes_tab_after_input_saw_it"] = _owner_name(t) == "B" and KEY_TAB in rec.in_keys and not (KEY_TAB in rec.un_keys)
	a.grab_focus()
	await t.frames(1)
	rec.in_keys.clear()
	rec.un_keys.clear()
	await _tap(t, KEY_I)
	facts["F3_letters_are_not_consumed_by_a_focused_button"] = KEY_I in rec.in_keys and KEY_I in rec.un_keys
	le.grab_focus()
	await t.frames(1)
	rec.in_keys.clear()
	rec.un_keys.clear()
	await _typed(t, "ije1")
	facts["F3_a_typing_lineedit_consumes_letters"] = le.text == "ije1" and rec.un_keys.is_empty() and not rec.in_keys.is_empty()
	# F1: a hidden focus owner leaves focus NONE; every control FOCUS_NONE lets Tab, arrows, Space, Enter and Esc reach _unhandled_input
	b.grab_focus()
	await t.frames(1)
	b.visible = false
	await t.frames(2)
	facts["F1_a_hidden_focus_owner_leaves_none"] = t.root.gui_get_focus_owner() == null
	b.visible = true
	for n in [a, b, c, dis, le]:
		(n as Control).focus_mode = Control.FOCUS_NONE
	t.root.gui_release_focus()
	await t.frames(1)
	rec.un_keys.clear()
	for k in [KEY_TAB, KEY_DOWN, KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		await _tap(t, k)
	facts["F1_with_nothing_focusable_every_key_reaches_unhandled_input"] = rec.un_keys == [KEY_TAB, KEY_DOWN, KEY_SPACE, KEY_ENTER, KEY_ESCAPE]
	for n in [a, b, c, dis, le]:
		(n as Control).focus_mode = Control.FOCUS_ALL
	# ---- F5 / F6: disabled buttons take focus, focus does not wrap
	dis.grab_focus()
	await t.frames(1)
	facts["F5_a_disabled_button_takes_focus"] = _owner_name(t) == "Dis"
	await _finish_test(t)
	host = _fresh(t)
	var vb2 := VBoxContainer.new()
	vb2.position = Vector2(500, 100)
	host.add_child(vb2)
	var l1 := _add(vb2, "L1")
	var l2 := _add(vb2, "L2")
	await t.frames(2)
	l2.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_DOWN)
	facts["F6_focus_does_not_wrap_at_the_end"] = _owner_name(t) == "L2" and l1 != null
	await _finish_test(t)
	host = _fresh(t)
	rec = KeyRecorder.new()
	host.add_child(rec)
	col = VBoxContainer.new()
	col.position = Vector2(100, 100)
	host.add_child(col)
	le = LineEdit.new()
	le.name = "Edit"
	le.custom_minimum_size = Vector2(200, 36)
	col.add_child(le)
	# ---- F7 / F8: a LineEdit keeps the Up / Down KEYS, the pad and the actions leave; Esc is seen by _input only; Enter submits
	var below := _add(col, "Below")
	await t.frames(2)
	le.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_DOWN)
	var key_stays := _owner_name(t) == "Edit"
	UiAudit.press(t, &"ui_down")
	await t.frames(1)
	var action_leaves := _owner_name(t) == "Below"
	le.grab_focus()
	await t.frames(1)
	await _pad(t, JOY_BUTTON_DPAD_DOWN)
	var dpad_leaves := _owner_name(t) == "Below"
	le.grab_focus()
	await t.frames(1)
	var stick := InputEventJoypadMotion.new()                  # the stick goes through the Input singleton, like the hardware (the probe of the spec did the same)
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await t.frames(2)
	stick = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await t.frames(2)
	var stick_leaves := _owner_name(t) == "Below"
	facts["F7_the_up_down_KEYS_stay_in_a_lineedit"] = key_stays
	facts["F7_the_ui_down_action_leaves_a_lineedit"] = action_leaves
	facts["F7_the_dpad_leaves_a_lineedit"] = dpad_leaves
	facts["F7_the_left_stick_leaves_a_lineedit"] = stick_leaves and below != null
	le.release_focus()                                          # a LineEdit that submitted or got Esc stops "editing": focus it again to start editing
	le.grab_focus()
	await t.frames(1)
	rec.in_keys.clear()
	rec.un_keys.clear()
	await _tap(t, KEY_ESCAPE)
	facts["F8_esc_in_an_edited_lineedit_reaches_input_not_unhandled"] = KEY_ESCAPE in rec.in_keys and not (KEY_ESCAPE in rec.un_keys)
	var submitted := [0]
	le.text_submitted.connect(func(_s: String) -> void: submitted[0] += 1)
	le.release_focus()
	le.grab_focus()
	await t.frames(1)
	rec.in_keys.clear()
	rec.un_keys.clear()
	await _tap(t, KEY_ENTER)
	facts["F8_enter_in_a_lineedit_submits_and_is_consumed"] = submitted[0] == 1 and KEY_ENTER in rec.in_keys and not (KEY_ENTER in rec.un_keys)
	rec.un_keys.clear()
	await _tap(t, KEY_ESCAPE)                                  # after a submit the field is not editing any more: Esc passes (T3d)
	facts["F8_esc_after_a_submit_passes_through"] = KEY_ESCAPE in rec.un_keys
	# ---- F9: one key matches several actions
	var matches := {}
	for pair in [[KEY_ESCAPE, ["pause", "ui_cancel"]], [KEY_ENTER, ["interact", "ui_accept"]], [KEY_SPACE, ["jump", "dodge", "ui_accept"]], [KEY_TAB, ["inventory", "ui_focus_next"]]]:
		var ev := InputEventKey.new()
		ev.keycode = pair[0] as Key
		ev.physical_keycode = pair[0] as Key
		ev.pressed = true
		var all := true
		for act in pair[1]:
			all = all and ev.is_action(act)
		matches[pair[0]] = all
	facts["F9_one_key_matches_several_actions"] = not matches.values().has(false)
	await _finish_test(t)
	host = _fresh(t)
	rec = KeyRecorder.new()
	host.add_child(rec)
	col = VBoxContainer.new()
	col.position = Vector2(100, 100)
	host.add_child(col)
	a = _add(col, "A")
	b = _add(col, "B")
	c = _add(col, "C")
	await t.frames(3)
	# ---- F10: page keys have PageUp / PageDown AND LB / RB (the P01 amendment), the ui_* directions carry the D-pad and the left stick, echo navigates, a paused tree navigates
	var pad_events := func(action: String) -> Array:
		return InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton).map(func(e: InputEvent) -> int: return (e as InputEventJoypadButton).button_index)
	facts["F10_page_actions_carry_pageup_pagedown_and_lb_rb"] = pad_events.call("ui_page_up") == [JOY_BUTTON_LEFT_SHOULDER] and pad_events.call("ui_page_down") == [JOY_BUTTON_RIGHT_SHOULDER] \
		and InputMap.action_get_events("ui_page_up").any(func(e: InputEvent) -> bool: return e is InputEventKey and (e as InputEventKey).keycode == KEY_PAGEUP)
	facts["F10_directions_carry_the_dpad_and_the_left_stick"] = pad_events.call("ui_down") == [JOY_BUTTON_DPAD_DOWN] and InputMap.action_get_events("ui_down").any(func(e: InputEvent) -> bool: return e is InputEventJoypadMotion)
	a.grab_focus()
	await t.frames(1)
	await _echo(t, KEY_DOWN)
	facts["F10_echo_events_navigate"] = _owner_name(t) == "B"
	a.grab_focus()
	t.click(Vector2(1100, 650))
	await t.frames(2)
	facts["F10_a_click_on_empty_space_does_not_drop_focus"] = _owner_name(t) == "A"
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	t.tree.paused = true
	a.grab_focus()
	await t.frames(1)
	UiAudit.press(t, &"ui_down")
	await t.frames(1)
	facts["F10_navigation_works_in_a_paused_tree_for_ALWAYS_nodes"] = _owner_name(t) == "B"
	t.tree.paused = false
	# ---- F11: with the 1280x720 root a click grabs focus and mouse_entered fires
	var hover := [0]
	c.mouse_entered.connect(func() -> void: hover[0] += 1)
	t.root.gui_release_focus()
	await t.frames(1)
	t.move_mouse(Vector2(900, 600))
	await t.frames(1)
	t.move_mouse(c.get_global_rect().get_center())
	t.click(c.get_global_rect().get_center())
	await t.frames(2)
	facts["F11_click_grabs_focus_and_mouse_entered_fires"] = _owner_name(t) == "C" and hover[0] >= 1 and Vector2(t.root.size) == Vector2(1280, 720)
	await _finish_test(t)
	# ---- F4: who sees ui_accept / interact, and does a Button still press (the probe of final_probe_accept)
	host = _fresh(t)
	var world := WorldProbe.new()
	host.add_child(world)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(ui)
	var button := _button_at(ui, "X", Vector2(50, 50), Vector2(100, 40))
	var presses := [0]
	button.pressed.connect(func() -> void: presses[0] += 1)
	var eater := Eater.new()
	ui.add_child(eater)
	await t.frames(2)
	var f4 := {}
	for stage in ["off", "input", "unhandled"]:
		for dev in ["enter", "space", "padA", "e"]:
			eater.stage = stage
			eater.actions = [&"ui_accept", &"interact"]
			world.seen.clear()
			presses[0] = 0
			button.grab_focus()
			await t.frames(1)
			match dev:
				"enter":
					await _tap(t, KEY_ENTER)
				"space":
					await _tap(t, KEY_SPACE)
				"padA":
					await _pad(t, JOY_BUTTON_A)
				"e":
					await _tap(t, KEY_E)
			f4["%s/%s" % [stage, dev]] = {"pressed": presses[0], "interact": int(world.seen.get(&"interact", 0))}
	var f4_nothing: bool = f4["off/enter"]["pressed"] == 1 and f4["off/space"]["pressed"] == 1 and f4["off/padA"]["pressed"] == 1 and f4["off/e"]["pressed"] == 0 \
		and f4["off/enter"]["interact"] == 1 and f4["off/padA"]["interact"] == 1 and f4["off/e"]["interact"] == 1 and f4["off/space"]["interact"] == 0    # the double fire: Enter presses AND is `interact`
	var f4_input: bool = f4["input/enter"]["pressed"] == 0 and f4["input/space"]["pressed"] == 0 and f4["input/padA"]["pressed"] == 0 and f4["input/e"]["interact"] == 0 and f4["input/enter"]["interact"] == 0
	var f4_unhandled: bool = f4["unhandled/enter"]["pressed"] == 1 and f4["unhandled/space"]["pressed"] == 1 and f4["unhandled/padA"]["pressed"] == 1 and f4["unhandled/enter"]["interact"] == 0 and f4["unhandled/padA"]["interact"] == 0 and f4["unhandled/e"]["interact"] == 0
	eater.stage = "off"
	button.pressed.connect(func() -> void: button.get_viewport().set_input_as_handled())
	world.seen.clear()
	presses[0] = 0
	button.grab_focus()
	await t.frames(1)
	await _tap(t, KEY_ENTER)
	var f4_handled_in_pressed: bool = presses[0] == 1 and int(world.seen.get(&"interact", 0)) == 1
	facts["F4_an_input_eater_stops_the_button_an_unhandled_eater_does_not"] = f4_nothing and f4_input and f4_unhandled
	facts["F4_set_input_as_handled_inside_pressed_does_not_stop_the_world"] = f4_handled_in_pressed
	await _finish_test(t)
	# ---- F12: Window-based controls split focus ownership
	host = _fresh(t)
	var behind := _button_at(host, "Behind", Vector2(100, 100))
	await t.frames(1)
	behind.grab_focus()
	var dialog := ConfirmationDialog.new()
	host.add_child(dialog)
	dialog.popup_centered()
	await t.frames(3)
	facts["F12_a_confirmation_dialog_is_a_window_with_its_own_focus"] = dialog is Window and dialog.get_viewport() != t.root and t.root.gui_get_focus_owner() == behind
	dialog.hide()
	dialog.queue_free()
	var option := OptionButton.new()
	option.add_item("x")
	option.position = Vector2(400, 100)
	host.add_child(option)
	await t.frames(1)
	facts["F12_an_option_button_popup_is_a_window"] = option.get_popup() is Window
	await _finish_test(t)
	# ---- F13: glyph coverage
	var alegreya: Font = load("res://assets/fonts/AlegreyaSans-ExtraBold.ttf")
	var alegreya_med: Font = load("res://assets/fonts/AlegreyaSans-Medium.ttf")
	var mono: Font = load("res://assets/fonts/IBMPlexMono-Regular.ttf")
	var symbols: Font = load("res://assets/fonts/TTSymbols-Regular.ttf")
	var caprasimo: Font = load("res://assets/fonts/Caprasimo-Regular.ttf")
	var arrows := "↑↓←→"
	var arrows_ok := true
	var caprasimo_has := false
	for ch in arrows:
		arrows_ok = arrows_ok and alegreya.has_char(ch.unicode_at(0)) and alegreya_med.has_char(ch.unicode_at(0)) and mono.has_char(ch.unicode_at(0))
		caprasimo_has = caprasimo_has or caprasimo.has_char(ch.unicode_at(0))
	var syms_ok := true
	for ch in "▸◂▴▾♥★✓✗":
		syms_ok = syms_ok and symbols.has_char(ch.unicode_at(0))
	facts["F13_arrows_come_from_alegreya_and_plex_mono_symbols_from_ttsymbols_caprasimo_has_no_arrow"] = arrows_ok and syms_ok and not caprasimo_has
	# ---- F14: input reaches sibling nodes in REVERSE tree order, in both stages
	host = _fresh(t)
	var order_log: Array = []
	for tag in ["first", "second", "third"]:
		var p := OrderProbe.new()
		p.tag = tag
		p.log = order_log
		host.add_child(p)
	await t.frames(1)
	await _tap(t, KEY_F5)
	facts["F14_input_and_unhandled_input_reach_siblings_in_reverse_tree_order"] = order_log == ["third:input", "second:input", "first:input", "third:unhandled", "second:unhandled", "first:unhandled"]
	await _finish_test(t)
	_restore_parked(parked)
	var bad := _facts_fail(facts)
	for k in facts:
		if not bool(facts[k]):
			t.info("engine fact FAILED: %s" % k)
	t.check("engine_facts", bad.is_empty() and facts.size() >= 25, "%d engine facts of UI_NAVIGATION.md 3.1 (F1 - F14) hold on this engine (%s); failed: %s" % [facts.size(), Engine.get_version_info()["string"], str(bad)])


# ---------------------------------------------------------------------------------------------------- windowed: the slider ring

func run_windowed(t) -> void:
	await t.clear_scene()
	TranslationServer.set_locale("da")
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.root.add_child(host)
	var bg := ColorRect.new()
	bg.color = Color("#f4e6c4")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var ringed := TTSlider.new()
	ringed.name = "Ringed"
	ringed.position = Vector2(300, 200)
	ringed.custom_minimum_size = Vector2(420, 36)
	ringed.size = Vector2(420, 36)
	ringed.step = 5
	ringed.value = 40
	host.add_child(ringed)
	var sibling := TTSlider.new()
	sibling.name = "Sibling"
	sibling.position = Vector2(300, 300)
	sibling.custom_minimum_size = Vector2(420, 36)
	sibling.size = Vector2(420, 36)
	host.add_child(sibling)
	var plain := HSlider.new()
	plain.name = "Plain"
	plain.position = Vector2(300, 400)
	plain.custom_minimum_size = Vector2(420, 36)
	plain.size = Vector2(420, 36)
	host.add_child(plain)
	await t.frames(4)
	var rep: Dictionary = await UiAudit.ring_pixels(t, ringed, {"shot": "slider_ring", "other": sibling})
	UiAudit.expect(t, rep, "slider_focus_ring")
	# the finding behind TTSlider: a PLAIN HSlider with the very same theme style draws no ring at all
	var plain_rep: Dictionary = await UiAudit.ring_pixels(t, plain, {"shot": "slider_plain", "style": ringed.get_theme_stylebox(&"focus")})
	var plain_missing := false
	for d in plain_rep["defects"]:
		plain_missing = plain_missing or d["code"] == "ring_missing"
	t.check("slider_plain_hslider_shows_no_ring", plain_missing, "a plain HSlider with the theme's focus style paints no ring (ring_missing): %s" % UiAudit.summary(plain_rep))
	# the grabber stays inside the rect (center_grabber 0) at the extremes, so the ring hugs the control
	ringed.value = ringed.min_value
	await t.frames(2)
	var rep_min: Dictionary = await UiAudit.ring_pixels(t, ringed, {"shot": "slider_ring_min"})
	ringed.value = ringed.max_value
	await t.frames(2)
	var rep_max: Dictionary = await UiAudit.ring_pixels(t, ringed, {"shot": "slider_ring_max"})
	t.check("slider_ring_at_both_ends", bool(rep_min["ok"]) and bool(rep_max["ok"]) and (rep_min["defects"] as Array).is_empty() and (rep_max["defects"] as Array).is_empty(), "the ring is complete with the grabber at 0 (%s) and at the maximum (%s)" % [UiAudit.summary(rep_min), UiAudit.summary(rep_max)])
	# the amended quantity_stepper is ONE focus stop that paints its own ring (PanelField/focus, declared with tt_focus_style), like TTSlider: the same pixel proof
	var stepper: Control = (load("res://scenes/ui/components/quantity_stepper.tscn") as PackedScene).instantiate()
	stepper.name = "RingedStepper"
	stepper.position = Vector2(300, 520)
	host.add_child(stepper)
	var stepper_sibling: Control = (load("res://scenes/ui/components/quantity_stepper.tscn") as PackedScene).instantiate()
	stepper_sibling.name = "SiblingStepper"
	stepper_sibling.position = Vector2(560, 520)
	host.add_child(stepper_sibling)
	await t.frames(4)
	var srep: Dictionary = await UiAudit.ring_pixels(t, stepper, {"shot": "stepper_ring", "other": stepper_sibling})
	UiAudit.expect(t, srep, "stepper_focus_ring")
	host.queue_free()
	await t.frames(2)
