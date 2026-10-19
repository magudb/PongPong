extends RefCounted
## P01 input contract: PLAN 3.2 plus addendum 3.3 (decorate, wardrobe, collection, rotate_item,
## pickup_item), the towns addendum (people, fix round RT3), and N04's named hotbar cycle. Shared by print_inputmap.gd and
## check_project.gd; load it with preload(), it has no class_name on purpose (drivers run with -s
## before the global class cache is current).
##
## Per action: "keys" = PHYSICAL keycodes, "mouse" = mouse button indexes, "joy" = joypad buttons,
## "axes" = [axis, value] pairs. The comparison is EXACT: an extra event (F10 on inventory, a wheel
## binding on rotate_item) is as much an error as a missing one, and so is any event that only
## matches under a qualifier (a modifier key, a key location, one device): Shift+W is NOT the plain
## W the plan asks for, the action would not fire on W alone (see qualifiers()).
##
## The `ui_*` focus-navigation actions are Godot defaults, with four project overrides (PLAN 3.2
## last row, "Godot defaults + D-pad, joy A/B", and UI_NAVIGATION.md F10, pad paging on LB / RB):
## see UI_OVERRIDES, ui_errors() and ui_page_errors().

# Explicitly authorized development control, separate from the frozen P01 gameplay bindings.
const DEBUG_ACTIONS := {"cheat_menu": {"keys": [KEY_F8], "deadzone": 0.2}}
static func custom_actions() -> Dictionary:
	return ACTIONS.merged(DEBUG_ACTIONS)

const ACTIONS: Dictionary = {
	"move_forward": {"keys": [KEY_W, KEY_UP], "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	"move_back": {"keys": [KEY_S, KEY_DOWN], "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	"move_left": {"keys": [KEY_A, KEY_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"interact": {"keys": [KEY_E, KEY_ENTER], "joy": [JOY_BUTTON_A]},
	"jump": {"keys": [KEY_SPACE], "joy": [JOY_BUTTON_A]},
	"dodge": {"keys": [KEY_SPACE], "joy": [JOY_BUTTON_B]},
	# The pad runs and descends on LT, takes off on Y (light only acts in action areas, where nobody flies) and
	# zooms with the right stick (review UX-04: a pad player could not run, fly or zoom)
	"run": {"keys": [KEY_SHIFT], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	"fly_toggle": {"keys": [KEY_F], "joy": [JOY_BUTTON_Y]},
	# Shift, not Ctrl: Ctrl + arrows switches Spaces on macOS (review UX-16). Running is off while flying, so Shift is free there.
	"fly_descend": {"keys": [KEY_SHIFT], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	# X is the keyboard tool / attack key (review UX-03: mouse-free play), the same letter as the pad button
	"use_tool": {"keys": [KEY_X], "mouse": [MOUSE_BUTTON_LEFT], "joy": [JOY_BUTTON_X]},
	"attack": {"keys": [KEY_X], "mouse": [MOUSE_BUTTON_LEFT], "joy": [JOY_BUTTON_X]},
	"light": {"keys": [KEY_Q], "joy": [JOY_BUTTON_Y]},
	"drink": {"keys": [KEY_R], "joy": [JOY_BUTTON_RIGHT_SHOULDER]},
	"slot_1": {"keys": [KEY_1]},
	"slot_2": {"keys": [KEY_2]},
	"slot_3": {"keys": [KEY_3]},
	"slot_4": {"keys": [KEY_4]},
	"slot_5": {"keys": [KEY_5]},
	"slot_6": {"keys": [KEY_6]},
	"slot_7": {"keys": [KEY_7]},
	"slot_8": {"keys": [KEY_8]},
	"slot_9": {"keys": [KEY_9]},
	"slot_10": {"keys": [KEY_0]},
	"inventory": {"keys": [KEY_I, KEY_TAB]},
	"map": {"keys": [KEY_M]},
	"journal": {"keys": [KEY_J]},
	"pause": {"keys": [KEY_ESCAPE], "joy": [JOY_BUTTON_START]},
	"build_menu": {"keys": [KEY_B]},
	"zoom_in": {"mouse": [MOUSE_BUTTON_WHEEL_UP], "axes": [[JOY_AXIS_RIGHT_Y, -1.0]]},
	"zoom_out": {"mouse": [MOUSE_BUTTON_WHEEL_DOWN], "axes": [[JOY_AXIS_RIGHT_Y, 1.0]]},
	# addendum 3.3 (features); no mouse wheel binding: Indretning consumes the wheel itself
	"decorate": {"keys": [KEY_H], "joy": [JOY_BUTTON_BACK]},
	"wardrobe": {"keys": [KEY_G]},
	"collection": {"keys": [KEY_C]},
	"rotate_item": {"keys": [KEY_R], "joy": [JOY_BUTTON_RIGHT_SHOULDER]},
	"pickup_item": {"keys": [KEY_X], "mouse": [MOUSE_BUTTON_RIGHT], "joy": [JOY_BUTTON_X]},
	# towns addendum (RT3): the People book. P is free (the used keys are W A S D arrows E Enter Space
	# Shift F Q R 0-9 I Tab J Esc B H G C X M); no pad button: the pause menu has a row "Folk"
	"people": {"keys": [KEY_P]},
	# N04: name the existing eight-slot D-pad cycle so dialogue/hints use
	# the same binding contract as the production player.
	"hotbar_previous": {"joy": [JOY_BUTTON_DPAD_LEFT]},
	"hotbar_next": {"joy": [JOY_BUTTON_DPAD_RIGHT]},
}

## The five actions the feature addendum adds on top of PLAN 3.2.
const ADDENDUM: Array = ["decorate", "wardrobe", "collection", "rotate_item", "pickup_item"]

## One town action, two named N04 hotbar actions and the area map: 30 + 5 + 1 + 2 + 1 = 39.
const TOWN: Array = ["people"]
const HOTBAR: Array = ["hotbar_previous", "hotbar_next"]
const NAVIGATION: Array = ["map"]

## The `ui_*` overrides that give a pad the paging keys (UI_NAVIGATION.md F10): the tab / page
## actions of every screen (`ui_page_up` = LB, `ui_page_down` = RB), plus Q / E for keyboards without PgUp / PgDn (a MacBook,
## review UX-16; UiNav.page_pressed() leaves the letters to a focused text field).
const UI_PAGE_ACTIONS: Array = ["ui_page_up", "ui_page_down"]

const DEADZONE: float = 0.2

## InputEvent.device of a binding that answers every device (what the editor writes).
const ANY_DEVICE: int = -1

## The four ui_* actions project.godot overrides. Godot 4.7.2's defaults carry the D-pad on
## ui_up/down/left/right but NOT joy A on ui_accept, joy B on ui_cancel nor LB / RB on
## ui_page_up / ui_page_down (probed), so a pad could not activate, cancel or page a focused
## screen. Every override is the engine default plus the pad button: "logical" = LOGICAL keycodes,
## exactly like the engine's own defaults (PageUp / PageDown stay on the page actions). 39 contract
## actions + these four overrides = 43 project actions, plus the separate cheat action.
const UI_OVERRIDES: Dictionary = {
	"ui_accept": {"logical": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], "joy": [JOY_BUTTON_A]},
	"ui_cancel": {"logical": [KEY_ESCAPE], "joy": [JOY_BUTTON_B]},
	"ui_page_up": {"keys": [KEY_Q], "logical": [KEY_PAGEUP], "joy": [JOY_BUTTON_LEFT_SHOULDER]},
	"ui_page_down": {"keys": [KEY_E], "logical": [KEY_PAGEDOWN], "joy": [JOY_BUTTON_RIGHT_SHOULDER]},
}

## The D-pad button the engine defaults of the focus-walk actions must keep.
const UI_DPAD: Dictionary = {
	"ui_up": JOY_BUTTON_DPAD_UP,
	"ui_down": JOY_BUTTON_DPAD_DOWN,
	"ui_left": JOY_BUTTON_DPAD_LEFT,
	"ui_right": JOY_BUTTON_DPAD_RIGHT,
}


## Events that intentionally trigger more than one action (the player reads the one that matches
## the area projection or modal; PLAN 3.2 text and addendum 3.3). Anything else shared is a clash.
static func expected_shared() -> Dictionary:
	return {
		"key:%d" % KEY_SPACE: ["dodge", "jump"],
		"mouse:%d" % MOUSE_BUTTON_LEFT: ["attack", "use_tool"],
		"joy:%d" % JOY_BUTTON_A: ["interact", "jump"],
		"joy:%d" % JOY_BUTTON_X: ["attack", "pickup_item", "use_tool"],
		"key:%d" % KEY_X: ["attack", "pickup_item", "use_tool"],
		"key:%d" % KEY_SHIFT: ["fly_descend", "run"],
		"axis:%d:+" % JOY_AXIS_TRIGGER_LEFT: ["fly_descend", "run"],
		"joy:%d" % JOY_BUTTON_Y: ["fly_toggle", "light"],
		"key:%d" % KEY_R: ["drink", "rotate_item"],
		"joy:%d" % JOY_BUTTON_RIGHT_SHOULDER: ["drink", "rotate_item"],
	}


## Everything besides the code that decides WHEN an event matches an action: the modifier flags
## (an action bound to Shift+W only fires while Shift is held), the key location (left Shift only)
## and the device (device 0 only; keyboard events carry another device id). Empty string = the
## plain form every contract binding must have, anything else is appended to the signature so the
## exact comparison fails.
static func qualifiers(ev: InputEvent) -> String:
	var q: String = ""
	if ev is InputEventWithModifiers:
		var m: InputEventWithModifiers = ev
		if m.alt_pressed:
			q += "+alt"
		if m.shift_pressed:
			q += "+shift"
		if m.ctrl_pressed:
			q += "+ctrl"
		if m.meta_pressed:
			q += "+meta"
		if m.command_or_control_autoremap:
			q += "+cmdorctrl"
	if ev is InputEventKey:
		var k: InputEventKey = ev
		if k.location != KEY_LOCATION_UNSPECIFIED:
			q += "+loc%d" % int(k.location)
	if ev.device != ANY_DEVICE:
		q += "@dev%d" % ev.device
	return q


## Stable signature of one InputEvent: code plus qualifiers() ("other:<class>" when the event type
## is not part of the contract).
static func signature(ev: InputEvent) -> String:
	var base: String = ""
	if ev is InputEventKey:
		var k: InputEventKey = ev
		if k.physical_keycode != 0:
			base = "key:%d" % k.physical_keycode
		else:
			base = "logicalkey:%d" % k.keycode
	elif ev is InputEventMouseButton:
		var m: InputEventMouseButton = ev
		base = "mouse:%d" % m.button_index
	elif ev is InputEventJoypadButton:
		var jb: InputEventJoypadButton = ev
		base = "joy:%d" % jb.button_index
	elif ev is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = ev
		base = "axis:%d:%s" % [jm.axis, "+" if jm.axis_value > 0.0 else "-"]
	else:
		base = "other:%s" % ev.get_class()
	return base + qualifiers(ev)


## Signatures the contract expects for one action (a contract action or one of UI_OVERRIDES).
static func expected_signatures(action: String) -> Array:
	var spec: Dictionary = ACTIONS.get(action, DEBUG_ACTIONS.get(action, UI_OVERRIDES.get(action, {})))
	var out: Array = []
	for code: int in spec.get("keys", []):
		out.append("key:%d" % code)
	for code: int in spec.get("logical", []):
		out.append("logicalkey:%d" % code)
	for code: int in spec.get("mouse", []):
		out.append("mouse:%d" % code)
	for code: int in spec.get("joy", []):
		out.append("joy:%d" % code)
	for pair: Array in spec.get("axes", []):
		out.append("axis:%d:%s" % [int(pair[0]), "+" if float(pair[1]) > 0.0 else "-"])
	out.sort()
	return out


## Signatures actually present in the live InputMap for one action.
static func actual_signatures(action: String) -> Array:
	var out: Array = []
	for ev: InputEvent in InputMap.action_get_events(action):
		out.append(signature(ev))
	out.sort()
	return out


## Events of the contract actions (and the two ui overrides) that only match under a qualifier.
## One readable message per offending event; empty = every binding is the plain form.
static func qualifier_errors() -> Array:
	var errors: Array = []
	var names: Array = custom_actions().keys() + UI_OVERRIDES.keys()
	for action: String in names:
		if not InputMap.has_action(action):
			continue
		for ev: InputEvent in InputMap.action_get_events(action):
			var q: String = qualifiers(ev)
			if q != "":
				errors.append("%s: event '%s' only matches under the qualifier '%s' (not the plain binding the contract asks for)" % [action, ev.as_text(), q])
	return errors


## The behaviour table of the focus-navigation contract: [label, event, action, must it trigger,
## group]. Real events, matched by the engine's own InputMap.event_is_action (the call every Control
## makes), so the rows do not rely on how the events are stored. Group "nav" = ui_accept / ui_cancel
## / the D-pad (PLAN 3.2 last row), group "page" = the pad paging of UI_NAVIGATION.md F10: LB pages
## up, RB pages down, and RB keeps its gameplay meaning (drink, rotate_item: the screens consume the
## event on top, see UI_NAVIGATION.md "Shared bindings are intentional").
static func ui_probes() -> Array:
	return [
		["joy A", _joy_event(JOY_BUTTON_A), "ui_accept", true, "nav"],
		["joy B", _joy_event(JOY_BUTTON_B), "ui_cancel", true, "nav"],
		["joy B", _joy_event(JOY_BUTTON_B), "ui_accept", false, "nav"],
		["joy A", _joy_event(JOY_BUTTON_A), "ui_cancel", false, "nav"],
		["joy X", _joy_event(JOY_BUTTON_X), "ui_accept", false, "nav"],
		["joy X", _joy_event(JOY_BUTTON_X), "ui_cancel", false, "nav"],
		["D-pad up", _joy_event(JOY_BUTTON_DPAD_UP), "ui_up", true, "nav"],
		["D-pad down", _joy_event(JOY_BUTTON_DPAD_DOWN), "ui_down", true, "nav"],
		["D-pad left", _joy_event(JOY_BUTTON_DPAD_LEFT), "ui_left", true, "nav"],
		["D-pad right", _joy_event(JOY_BUTTON_DPAD_RIGHT), "ui_right", true, "nav"],
		["Enter", _key_event(KEY_ENTER), "ui_accept", true, "nav"],
		["Kp Enter", _key_event(KEY_KP_ENTER), "ui_accept", true, "nav"],
		["Space", _key_event(KEY_SPACE), "ui_accept", true, "nav"],
		["Escape", _key_event(KEY_ESCAPE), "ui_cancel", true, "nav"],
		["LB", _joy_event(JOY_BUTTON_LEFT_SHOULDER), "ui_page_up", true, "page"],
		["RB", _joy_event(JOY_BUTTON_RIGHT_SHOULDER), "ui_page_down", true, "page"],
		["LB", _joy_event(JOY_BUTTON_LEFT_SHOULDER), "ui_page_down", false, "page"],
		["RB", _joy_event(JOY_BUTTON_RIGHT_SHOULDER), "ui_page_up", false, "page"],
		["PageUp", _key_event(KEY_PAGEUP), "ui_page_up", true, "page"],
		["PageDown", _key_event(KEY_PAGEDOWN), "ui_page_down", true, "page"],
		["PageUp", _key_event(KEY_PAGEUP), "ui_page_down", false, "page"],
		["PageDown", _key_event(KEY_PAGEDOWN), "ui_page_up", false, "page"],
		["Q", _key_event(KEY_Q), "ui_page_up", true, "page"],
		["E", _key_event(KEY_E), "ui_page_down", true, "page"],
		["Q", _key_event(KEY_Q), "ui_page_down", false, "page"],
		["E", _key_event(KEY_E), "ui_page_up", false, "page"],
		# the letter paging keeps the world meaning of the keys (a modal consumes the press on top)
		["Q", _key_event(KEY_Q), "light", true, "page"],
		["E", _key_event(KEY_E), "interact", true, "page"],
		["joy A", _joy_event(JOY_BUTTON_A), "ui_page_up", false, "page"],
		["joy A", _joy_event(JOY_BUTTON_A), "ui_page_down", false, "page"],
		["joy X", _joy_event(JOY_BUTTON_X), "ui_page_up", false, "page"],
		["joy X", _joy_event(JOY_BUTTON_X), "ui_page_down", false, "page"],
		# the pad paging must not take the shoulder buttons away from the game actions
		["RB", _joy_event(JOY_BUTTON_RIGHT_SHOULDER), "drink", true, "page"],
		["RB", _joy_event(JOY_BUTTON_RIGHT_SHOULDER), "rotate_item", true, "page"],
		["LB", _joy_event(JOY_BUTTON_LEFT_SHOULDER), "drink", false, "page"],
		["LB", _joy_event(JOY_BUTTON_LEFT_SHOULDER), "rotate_item", false, "page"],
		["LB", _joy_event(JOY_BUTTON_LEFT_SHOULDER), "ui_accept", false, "page"],
		["LB", _joy_event(JOY_BUTTON_LEFT_SHOULDER), "ui_cancel", false, "page"],
		["RB", _joy_event(JOY_BUTTON_RIGHT_SHOULDER), "ui_accept", false, "page"],
		["RB", _joy_event(JOY_BUTTON_RIGHT_SHOULDER), "ui_cancel", false, "page"],
	]


## Structure of the given ui overrides: exactly the engine default plus the pad button.
static func _override_errors(actions: Array) -> Array:
	var errors: Array = []
	for action: String in actions:
		if not InputMap.has_action(action):
			errors.append("missing action %s" % action)
			continue
		var want: Array = expected_signatures(action)
		var got: Array = actual_signatures(action)
		if want != got:
			errors.append("%s: expected events %s but found %s" % [action, want, got])
	return errors


## Behaviour: what a pad or keyboard really sends, device id included, for the probe rows of the
## given group ("" = every row). A row naming an action that does not exist cannot trigger it.
static func _probe_errors(group: String) -> Array:
	var errors: Array = []
	for p: Array in ui_probes():
		if group != "" and String(p[4]) != group:
			continue
		var hit: bool = InputMap.has_action(String(p[2])) and InputMap.event_is_action(p[1], String(p[2]), true)
		if hit != bool(p[3]):
			errors.append("%s %s %s" % [p[0], "does not trigger" if p[3] else "wrongly triggers", p[2]])
	return errors


## The four focus-walk actions keep the D-pad button of the engine defaults.
static func _dpad_errors() -> Array:
	var errors: Array = []
	for action: String in UI_DPAD:
		if not InputMap.has_action(action) or not actual_signatures(action).has("joy:%d" % int(UI_DPAD[action])):
			errors.append("%s lost its D-pad button (joy:%d)" % [action, int(UI_DPAD[action])])
	return errors


## ui_accept / ui_cancel and the four D-pad carrying actions (PLAN 3.2 last row): ui_accept and
## ui_cancel are exactly engine default plus the pad button, the four focus-walk actions keep their
## D-pad button, and the "nav" probe rows hold.
static func ui_nav_errors() -> Array:
	var errors: Array = _override_errors(["ui_accept", "ui_cancel"])
	errors.append_array(_dpad_errors())
	errors.append_array(_probe_errors("nav"))
	return errors


## Pad paging (UI_NAVIGATION.md F10, task UI.1): ui_page_up = Q + PageUp + LB (joy 9) and nothing else,
## ui_page_down = E + PageDown + RB (joy 10) and nothing else; LB pages up, RB pages down, neither the
## other way round, and RB still triggers drink and rotate_item.
static func ui_page_errors() -> Array:
	var errors: Array = _override_errors(UI_PAGE_ACTIONS)
	errors.append_array(_probe_errors("page"))
	return errors


## Verifies the whole focus-navigation contract (PLAN 3.2 last row plus the pad paging): the
## structure of every UI_OVERRIDES action, the D-pad and every probe row.
static func ui_errors() -> Array:
	return ui_nav_errors() + ui_page_errors()


static func _joy_event(button: int) -> InputEventJoypadButton:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button as JoyButton
	ev.pressed = true
	return ev


static func _key_event(code: int) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code as Key
	ev.physical_keycode = code as Key
	ev.pressed = true
	return ev


## Verifies the live InputMap against the contract; returns a list of error strings (empty = OK).
static func verify() -> Array:
	var errors: Array = []
	# 1. every contract action exists with exactly the contract events and the contract deadzone
	for action: String in custom_actions():
		if not InputMap.has_action(action):
			errors.append("missing action %s" % action)
			continue
		var want: Array = expected_signatures(action)
		var got: Array = actual_signatures(action)
		if want != got:
			errors.append("%s: expected events %s but found %s" % [action, want, got])
		var deadzone: float = float(custom_actions()[action].get("deadzone", DEADZONE))
		if not is_equal_approx(InputMap.action_get_deadzone(action), deadzone):
			errors.append("%s: deadzone %.2f, expected %.2f" % [action, InputMap.action_get_deadzone(action), deadzone])
	# 2. no custom (non ui_) action outside the contract
	for action: StringName in InputMap.get_actions():
		var s: String = String(action)
		if s.begins_with("ui_") or custom_actions().has(s):
			continue
		errors.append("unexpected custom action %s (new actions go through P01's owner)" % s)
	# 3. no clash: the events shared between actions are exactly the intended ones
	var shared: Dictionary = shared_bindings()
	var expected: Dictionary = expected_shared()
	for sig: String in shared:
		if not expected.has(sig):
			errors.append("clash: %s is bound to %s" % [sig, shared[sig]])
		elif expected[sig] != shared[sig]:
			errors.append("clash: %s is shared by %s, expected %s" % [sig, shared[sig], expected[sig]])
	for sig: String in expected:
		if not shared.has(sig):
			errors.append("intended shared binding %s (%s) is gone" % [sig, expected[sig]])
	# 4. no qualified (modifier / location / device bound) event, and the focus-navigation contract
	errors.append_array(qualifier_errors())
	errors.append_array(ui_errors())
	return errors


## Shared bindings found in the live map (contract actions only), for printing and the clash check.
static func shared_bindings() -> Dictionary:
	var by_sig: Dictionary = {}
	for action: String in custom_actions():
		if not InputMap.has_action(action):
			continue
		for sig: String in actual_signatures(action):
			if not by_sig.has(sig):
				by_sig[sig] = []
			by_sig[sig].append(action)
	var out: Dictionary = {}
	for sig: String in by_sig:
		var list: Array = by_sig[sig]
		if list.size() > 1:
			list.sort()
			out[sig] = list
	return out
