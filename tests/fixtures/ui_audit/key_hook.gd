extends Control
## Planted misbehaviour for the UI audit fixtures (tests/sections/ui_audit.gd): attach this script to a node and set `mode`.
##   eat_lr        swallows ui_left / ui_right (a slider or tab bar that ignores the keyboard)
##   release_down  releases focus on ui_down (a control that loses focus)
##   eat_accept    swallows ui_accept (a button that does nothing from the keyboard)
##   hover_grab    takes keyboard focus on mouse hover
##   click_drops   drops keyboard focus when it is clicked
##   eat_pad       swallows gamepad button events (the D-pad does not lead where the keyboard led)
##   wrap_up / wrap_down  ui_up / ui_down wrap to targets[0] on a fresh press, but a held key (echo) stops at the end
##   eat_keys      swallows printable keys (a text field that cannot be typed into)
##   toggle_down   ui_down goes to targets[0] the first time, targets[1] the second time, ... (navigation that depends on history)
##   click         a custom mouse-only clickable (handles mouse buttons, never takes focus)
## It extends Control, so it can be put on any Control (HSlider, TabBar, Button) with set_script().

var mode := "eat_lr":
	set(v):
		mode = v
		if v == "hover_grab" and not mouse_entered.is_connected(grab_focus):
			mouse_entered.connect(grab_focus)                      # a control that takes keyboard focus when the mouse only hovers it
var clicked := 0
var targets: Array = []                            # NodePaths (relative to this node) for toggle_down
var _presses := 0


func _gui_input(event: InputEvent) -> void:
	match mode:
		"eat_lr":
			if event.is_pressed() and (event.is_action("ui_left") or event.is_action("ui_right")):
				accept_event()
		"release_down":
			if event.is_pressed() and event.is_action("ui_down"):
				release_focus()
				accept_event()
		"eat_accept":
			if event.is_pressed() and event.is_action("ui_accept"):
				accept_event()
		"click_drops":
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				release_focus()
		"eat_pad":
			if event is InputEventJoypadButton:
				accept_event()
		"wrap_up", "wrap_down":
			var act := "ui_up" if mode == "wrap_up" else "ui_down"
			if event.is_pressed() and event.is_action(act) and targets.size() == 1:
				if not event.is_echo():
					(get_node(targets[0]) as Control).grab_focus()
				accept_event()
		"eat_keys":
			if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).unicode >= 32:
				accept_event()
		"toggle_down":
			if event.is_pressed() and event.is_action("ui_down") and targets.size() == 2:
				var tgt := get_node(targets[_presses % 2]) as Control
				_presses += 1
				tgt.grab_focus()
				accept_event()
		"click":
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				clicked += 1
				accept_event()
