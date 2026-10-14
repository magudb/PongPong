extends Control
## Fixture of the escape-chain check (tests/sections/ui_audit.gd): a base screen with an "open" button and up to N nested modals that follow
## the GameManager contract (push_modal on open, pop_modal on close, PROCESS_MODE_ALWAYS, Esc closes the TOP one, focus returns to the opener).
## `defect` plants one broken behaviour (set it before add_child):
##   ignore       Esc / ui_cancel never closes anything
##   wrong_order  Esc closes the BOTTOM modal instead of the top one
##   close_all    one Esc closes every open modal
##   no_restore   closes correctly but focus does not return to the opener
##   leak         the last modal to close leaves an extra pausing modal behind
##   stays_paused the last modal to close pauses the tree again (a panel that sets get_tree().paused by hand)
##   phase_changed the last modal to close switches GameManager's base phase (legacy change_phase use)
##   no_push      opening a modal never calls push_modal (the stack does not grow)
##   leak_to_world  Esc closes the top modal but the event is not marked handled (the world below would see the same press)
##   no_focus     a modal that never takes focus (the keyboard keeps acting on the screen behind it)
##   focus_released  a modal that RELEASES focus when it opens (no focus owner at all while it is open)
##   hides_opener    (conforming) the control that opened the first modal is hidden while it is open and never comes back: its focus cannot be restored, and the audit must not ask for it
##   opens_pause  Esc opens another modal on top instead of closing
##   internal_ignore  (with open_internal()) Esc never closes the screen's internal layer
##   internal_all     one Esc closes every internal layer
##   internal_leak    Esc closes the internal layer but does not mark the event handled (the world below would see the same press)
##   internal_wrong_order  Esc closes the top MODAL while an internal layer of the screen is still open
##   field_focus  the first focus of every modal is a LineEdit and Esc is read in _unhandled_input: a focused LineEdit eats the Esc KEY (Godot 4.7:
##                the event never reaches _unhandled_input), so Esc does not close the modal while the player types
##   field_focus_ok  (conforming) the same, with the idiom: the modal reads ui_cancel / pause in _input, before the text field sees the key
## open_level(level) is what a registry driver / an escape_chain opener calls.

const PANEL_NAME := "ModalPanel"

var defect := ""
var base_button: Button
var _levels: Array[Dictionary] = []                # [{name, panel, opener, first}]
var _internal := 0                                  # layers INSIDE the screen (a second page, a drawer): Esc closes them, the modal stack never moves


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	base_button = Button.new()
	base_button.name = "OpenButton"
	base_button.text = "MENU_SETTINGS"
	base_button.theme_type_variation = &"ButtonPrimary"
	base_button.custom_minimum_size = Vector2(260, 52)
	base_button.position = Vector2(100, 100)
	add_child(base_button)
	base_button.grab_focus()


func _gm() -> Node:
	return get_node("/root/GameManager")


func depth() -> int:
	return _levels.size()


## One more internal layer (the screen's own page 2): not a GameManager modal.
func open_internal() -> void:
	_internal += 1


func internal_depth() -> int:
	return _internal


## Opens modal number `level` (0 = the first). Must be called with focus on the control that "opens" it.
func open_level(level: int) -> void:
	var opener := get_viewport().gui_get_focus_owner()
	var mname := StringName("audit_modal_%d" % level)
	var p := PanelContainer.new()
	p.name = "%s%d" % [PANEL_NAME, level]
	p.theme_type_variation = &"PanelParchment"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.position = Vector2(300 + 60 * level, 120 + 40 * level)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var next := Button.new()
	next.name = "Next"
	next.text = "UI_YES"
	next.theme_type_variation = &"ButtonPrimary"
	next.custom_minimum_size = Vector2(240, 52)
	var close := Button.new()
	close.name = "Close"
	close.text = "UI_NO"
	close.theme_type_variation = &"ButtonTertiary"
	close.custom_minimum_size = Vector2(240, 52)
	var first: Control = next
	if defect == "field_focus" or defect == "field_focus_ok":
		var le := LineEdit.new()
		le.name = "Field"
		le.custom_minimum_size = Vector2(240, 48)
		v.add_child(le)
		first = le
	v.add_child(next)
	v.add_child(close)
	margin.add_child(v)
	p.add_child(margin)
	add_child(p)
	_levels.append({"name": mname, "panel": p, "opener": opener, "first": first})
	if defect != "no_push":
		_gm().push_modal(mname)
	if defect == "focus_released":
		get_viewport().gui_release_focus()
	elif defect != "no_focus":
		first.grab_focus()
	if defect == "hides_opener" and opener != null and level == 0:
		(opener as Control).visible = false


## The idiom for screens with text fields: _input runs before the focused control sees the event.
func _input(event: InputEvent) -> void:
	if defect == "field_focus_ok":
		_on_cancel(event)


func _unhandled_input(event: InputEvent) -> void:
	if defect != "field_focus_ok":
		_on_cancel(event)


func _on_cancel(event: InputEvent) -> void:
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		return
	if _internal > 0 and defect != "ignore":
		match defect:
			"internal_ignore":
				return
			"internal_all":
				_internal = 0
			"internal_wrong_order":
				if not _levels.is_empty():
					_close(_levels.size() - 1)
			_:
				_internal -= 1
		if defect != "leak_to_world" and defect != "internal_leak":
			get_viewport().set_input_as_handled()
		return
	if _levels.is_empty() or defect == "ignore":
		return
	match defect:
		"wrong_order":
			_close(0)
		"close_all":
			for i in range(_levels.size() - 1, -1, -1):
				_close(i)
		"opens_pause":
			_gm().push_modal(&"audit_pause")
		_:
			_close(_levels.size() - 1)
	if defect != "leak_to_world":
		get_viewport().set_input_as_handled()


func _close(index: int) -> void:
	var lv: Dictionary = _levels[index]
	_levels.remove_at(index)
	_gm().pop_modal(lv["name"])
	(lv["panel"] as Node).queue_free()
	if defect != "no_restore":
		var opener_v: Variant = lv["opener"]                         # (the screen may have rebuilt the opener while the layer was open: a freed node cannot be the typed variable)
		if is_instance_valid(opener_v) and (opener_v as Control).is_visible_in_tree():
			(opener_v as Control).grab_focus()
	if _levels.is_empty():
		if defect == "leak":
			_gm().push_modal(&"audit_leak")
		elif defect == "stays_paused":
			get_tree().paused = true
		elif defect == "phase_changed":
			_gm().change_phase(4)                                     # GamePhase.CUTSCENE
