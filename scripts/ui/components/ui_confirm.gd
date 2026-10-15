class_name UiConfirm
extends Control
## The ONLY dialog of the game (UI_NAVIGATION.md 4.5): a scrim and a parchment panel (the AcceptDialog look: 2 px ink, 4 + 2 px gold edge, radius 16) that is the
## LAST child of the control that asks, so it draws above that screen. Window-based dialogs (AcceptDialog, ConfirmationDialog, FileDialog, OptionButton popups)
## are banned from game UI: their focus lives in their own viewport (F12). Scene: scenes/ui/components/ui_confirm.tscn.
##
##   if await UiConfirm.ask(self, "CONFIRM", "UI_CONFIRM_OVERWRITE", "NAV_OK", "NAV_CANCEL", &"cancel", [slot]):      # -> bool
##   var name := await UiConfirm.ask_text(self, "UI_RENAME", old_name, 24)                                           # -> "" = cancelled
##
## Pattern C: Left / Right / Up / Down / Tab / Shift+Tab swap the two buttons, focus never leaves the dialog; `default` (&"cancel" or &"ok") picks the button
## that has focus first - the HARMLESS answer for every destructive question (overwrite, delete, load, build). Esc, Start and pad B cancel (read in `_input`,
## so a LineEdit being edited does not eat them); Enter / pad A press the focused button in the GUI stage; the closing press never reaches the world
## (UiNav.swallow). While it is open the modal stack carries `confirm` (pauses_tree = the CURRENT pause state: a confirm never changes it); it pops exactly
## once, hands focus back to the control that had it, and frees itself.
##
## `text` of ask() is a DISPLAY string; when it is a translation key (UPPER_CASE with an underscore) it is translated and formatted with `text_args`, and it
## re-labels on a language switch. Titles and button words are keys. ask_text() returns the text typed, strip_edges()ed; an empty text counts as "cancelled".

signal answered(result: Variant)

const SCENE_PATH := "res://scenes/ui/components/ui_confirm.tscn"
const MODAL := &"confirm"
const DEFAULT_OK := &"ok"
const DEFAULT_CANCEL := &"cancel"

var _text_mode := false
var _title_key := ""
var _text := ""
var _text_args: Array = []
var _ok_key := "NAV_OK"
var _cancel_key := "NAV_CANCEL"
var _default: StringName = DEFAULT_CANCEL
var _initial_text := ""
var _max_len := 24
var _open := false
var _prev_focus: Variant = null
var _wired := false

@onready var _panel: PanelContainer = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _text_label: Label = %TextLabel
@onready var _field: LineEdit = %Field
@onready var _cancel_button: Button = %CancelButton
@onready var _ok_button: Button = %OkButton


## Asks a yes / no question and waits for the answer. `asker` is the control that asks (the dialog becomes its last child).
static func ask(asker: Control, title_key: String, text: String, ok_key: String, cancel_key := "NAV_CANCEL", default := &"cancel", text_args: Array = []) -> bool:
	var dlg := _make(asker)
	if dlg == null:
		return false
	dlg.setup(title_key, text, ok_key, cancel_key, default, text_args)
	dlg.begin()
	var result: Variant = await dlg.answered
	return bool(result)


## Asks for one line of text (a rename). Returns the typed text, "" when cancelled (or empty).
static func ask_text(asker: Control, title_key: String, initial: String, max_len := 24, ok_key := "NAV_OK") -> String:
	var dlg := _make(asker)
	if dlg == null:
		return ""
	dlg.setup_text(title_key, initial, max_len, ok_key)
	dlg.begin()
	var result: Variant = await dlg.answered
	return str(result)


static func _make(asker: Control) -> UiConfirm:
	if asker == null or not is_instance_valid(asker) or not asker.is_inside_tree():
		return null
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var dlg := scene.instantiate() as UiConfirm
	asker.add_child(dlg)
	return dlg


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true                          # the scrim covers the whole window whatever the asker's rect is
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = _open
	set_process(_open)
	_wire()
	UiNav.watcher()


func _exit_tree() -> void:
	if not _open:
		return
	_open = false
	_prev_focus = null
	var gm := Svc.node("GameManager")
	if gm != null:
		gm.call("pop_modal", MODAL)
	# Removing the asker cancels the request and releases any surviving awaiter.
	answered.emit("" if _text_mode else false)


# ----------------------------------------------------------------------------------------------------------------- setup

func setup(title_key: String, text: String, ok_key: String, cancel_key := "NAV_CANCEL", default := &"cancel", text_args: Array = []) -> void:
	_text_mode = false
	_title_key = title_key
	_text = text
	_text_args = text_args
	_ok_key = ok_key
	_cancel_key = cancel_key
	_default = default if default == DEFAULT_OK else DEFAULT_CANCEL
	if is_node_ready():
		_apply_texts()


func setup_text(title_key: String, initial: String, max_len := 24, ok_key := "NAV_OK") -> void:
	_text_mode = true
	_title_key = title_key
	_text = ""
	_initial_text = initial
	_max_len = max_len
	_ok_key = ok_key
	_cancel_key = "NAV_CANCEL"
	_default = DEFAULT_OK
	if is_node_ready():
		_apply_texts()


func is_open() -> bool:
	return _open


func _wire() -> void:
	if _wired:
		return
	_wired = true
	_cancel_button.pressed.connect(_finish.bind(false))
	_ok_button.pressed.connect(_finish.bind(true))
	_field.text_submitted.connect(func(_t: String) -> void: _finish(true))
	_field.focus_mode = Control.FOCUS_ALL
	# pattern C: the two buttons swap in every direction (and with Tab), nothing leads out of the dialog
	for b in [_cancel_button, _ok_button]:
		var other: Button = _ok_button if b == _cancel_button else _cancel_button
		for dir in [UiNav.LEFT, UiNav.RIGHT]:
			UiNav.link(b, dir, other)
		b.focus_next = b.get_path_to(other)
		b.focus_previous = b.get_path_to(other)
	_wire_vertical()


## Up / Down: the other button (confirm); with a text field the order is field -> OK -> field and the buttons lead back up to the field.
func _wire_vertical() -> void:
	if _text_mode:
		UiNav.link(_field, UiNav.DOWN, _ok_button)
		UiNav.link(_field, UiNav.UP, _ok_button)
		UiNav.link(_field, UiNav.LEFT, _field)
		UiNav.link(_field, UiNav.RIGHT, _field)
		for b in [_cancel_button, _ok_button]:
			UiNav.link(b, UiNav.UP, _field)
			UiNav.link(b, UiNav.DOWN, _field)
		_field.focus_next = _field.get_path_to(_cancel_button)
		_field.focus_previous = _field.get_path_to(_ok_button)
		_cancel_button.focus_previous = _cancel_button.get_path_to(_field)
		_cancel_button.focus_next = _cancel_button.get_path_to(_ok_button)
		_ok_button.focus_previous = _ok_button.get_path_to(_cancel_button)
		_ok_button.focus_next = _ok_button.get_path_to(_field)
		UiNav.yield_updown_from_fields(self)
	else:
		for b in [_cancel_button, _ok_button]:
			var other: Button = _ok_button if b == _cancel_button else _cancel_button
			UiNav.link(b, UiNav.UP, other)
			UiNav.link(b, UiNav.DOWN, other)


# ----------------------------------------------------------------------------------------------------------------- running

## Shows the dialog, pushes the modal, focuses the default answer.
func begin() -> void:
	if _open:
		return
	_open = true
	visible = true
	set_process(true)
	var vp := get_viewport()
	_prev_focus = vp.gui_get_focus_owner() if vp != null else null
	var gm := Svc.node("GameManager")
	if gm != null:
		gm.call("push_modal", MODAL, get_tree().paused)      # a confirm never changes the pause state
	if _text_mode:
		_field.max_length = _max_len
		_field.select_all_on_focus = true
		_field.text = _initial_text.substr(0, _max_len)
	_apply_texts()
	_wire_vertical()
	_focus_default()
	_focus_default.call_deferred()


func _focus_default() -> void:
	if not _open or not is_inside_tree():
		return
	var target: Control = _field if _text_mode else (_ok_button if _default == DEFAULT_OK else _cancel_button)
	if target.is_visible_in_tree():
		target.grab_focus()
		if _text_mode:
			_field.select_all()


func _apply_texts() -> void:
	_title_label.text = str(TranslationServer.translate(_title_key)) if _title_key != "" else ""
	_ok_button.text = TranslationServer.translate(_ok_key)
	_cancel_button.text = TranslationServer.translate(_cancel_key)
	_field.visible = _text_mode
	_text_label.visible = not _text_mode
	if not _text_mode:
		_text_label.text = _display_text()


func _display_text() -> String:
	if UiHints.is_key(_text):
		var tr_text: String = str(TranslationServer.translate(_text))
		return tr_text % _text_args if not _text_args.is_empty() and tr_text.contains("%") else tr_text
	return _text


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_texts()


func _process(_delta: float) -> void:
	if not _open:
		return
	var vp := get_viewport()
	var f := vp.gui_get_focus_owner() if vp != null else null
	if f == null or not is_ancestor_of(f) or not f.is_visible_in_tree():
		_focus_default()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		_finish(false)
		get_viewport().set_input_as_handled()


## ui_accept / interact never reach the world while the dialog is up (the focused button has pressed in the GUI stage already).
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	for a in [&"ui_accept", &"interact", &"jump", &"dodge"]:
		if event.is_action_pressed(a, true):
			get_viewport().set_input_as_handled()
			return


func _finish(accepted: bool) -> void:
	if not _open:
		return
	_open = false
	visible = false
	var result: Variant = accepted
	if _text_mode:
		result = _field.text.strip_edges() if accepted else ""
	var gm := Svc.node("GameManager")
	if gm != null:
		gm.call("pop_modal", MODAL)
	UiNav.swallow(get_viewport())
	var prev: Variant = _prev_focus
	_prev_focus = null
	if UiNav.is_stop(prev) and prev.is_visible_in_tree():
		prev.grab_focus()
	else:
		UiNav.release_world_focus()
	answered.emit(result)
	queue_free()
