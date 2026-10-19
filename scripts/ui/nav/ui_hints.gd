class_name UiHints
extends RefCounted
## Device-aware key glyphs for hints and prompts (UI_NAVIGATION.md 4.3, Appendix A). The glyph is read from the LIVE InputMap (the first event of
## the action that matches the device), so a rebinding in a later version changes the hint with no text change:
##   keyboard / mouse   the first InputEventKey  (physical keys resolved through the keyboard layout), else the first mouse button
##   gamepad            the first InputEventJoypadButton (A B X Y LB RB Start Back, the D-pad as "D-pad"), else the first trigger / right stick
##                      axis (LT RT, "RS↑"); the labels follow the family of the pad in use (Xbox, PlayStation, Nintendo: `pad_family()`)
## Words (Enter, Esc, Tab, Mellemrum / Space, Venstre klik ...) come from the CSVs (nav.csv, ui.csv); the letters of the keys, the arrows and
## the pad letters are symbols and stay here. An action with no event for the device answers "" and the HintBar leaves that hint out
## (a hint never shows a key that is not live, 3.9).

const KEYBOARD := &"keyboard"
const GAMEPAD := &"gamepad"
## engine key -> localization key of its short name
const KEY_WORDS := {
	KEY_ENTER: "NAV_KEY_ENTER", KEY_KP_ENTER: "NAV_KEY_ENTER", KEY_ESCAPE: "NAV_KEY_ESC", KEY_TAB: "NAV_KEY_TAB", KEY_BACKTAB: "NAV_KEY_TAB",
	KEY_PAGEUP: "NAV_KEY_PGUP", KEY_PAGEDOWN: "NAV_KEY_PGDN", KEY_DELETE: "NAV_KEY_DELETE", KEY_SPACE: "KEY_SPACE",
}
const KEY_ARROWS := {KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→"}
const XBOX := &"xbox"
const PLAYSTATION := &"playstation"
const NINTENDO := &"nintendo"
## Button labels per pad family (review UX-18). Godot names the face buttons by POSITION (JOY_BUTTON_A is the bottom one), so a
## Nintendo pad shows B there. Letters are symbols and stay here; a value that looks like a key is a word of nav.csv (the PlayStation
## shapes have no glyph in the game fonts, so they are words too).
const PAD_LABELS := {
	XBOX: {
		JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_START: "NAV_PAD_START", JOY_BUTTON_BACK: "NAV_PAD_BACK",
	},
	PLAYSTATION: {
		JOY_BUTTON_A: "NAV_PAD_PS_CROSS", JOY_BUTTON_B: "NAV_PAD_PS_CIRCLE", JOY_BUTTON_X: "NAV_PAD_PS_SQUARE", JOY_BUTTON_Y: "NAV_PAD_PS_TRIANGLE",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_START: "NAV_PAD_PS_OPTIONS", JOY_BUTTON_BACK: "NAV_PAD_PS_CREATE",
	},
	NINTENDO: {
		JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X", JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
		JOY_BUTTON_START: "+", JOY_BUTTON_BACK: "−",
	},
}
## Triggers and the right stick (run, flight, zoom on a pad, review UX-04); the left stick is movement and never named.
const PAD_AXES := {
	XBOX: {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT", JOY_AXIS_RIGHT_X: "RS", JOY_AXIS_RIGHT_Y: "RS"},
	PLAYSTATION: {JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2", JOY_AXIS_RIGHT_X: "R", JOY_AXIS_RIGHT_Y: "R"},
	NINTENDO: {JOY_AXIS_TRIGGER_LEFT: "ZL", JOY_AXIS_TRIGGER_RIGHT: "ZR", JOY_AXIS_RIGHT_X: "RS", JOY_AXIS_RIGHT_Y: "RS"},
}
const STICK_ARROWS := {JOY_AXIS_RIGHT_X: ["←", "→"], JOY_AXIS_RIGHT_Y: ["↑", "↓"]}
const PAD_DPAD: Array[int] = [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
const MOUSE_WORDS := {MOUSE_BUTTON_LEFT: "KEY_MOUSE_LEFT", MOUSE_BUTTON_RIGHT: "KEY_MOUSE_RIGHT"}
## separators of a prompt that carries its key in the text: "E: Sov", "E · Tal med Pippin"
const PROMPT_SEPARATORS: Array[String] = [": ", " · "]


static var _key_rx: RegEx = null


## Does the text look like a translation key (UPPER_CASE with at least one underscore, the pattern of the harness's raw-key scan)? Widgets that get
## either a key or a ready display string (toasts, whispers, prompts, UiConfirm) translate only the first kind.
static func is_key(text: String) -> bool:
	if _key_rx == null:
		_key_rx = RegEx.new()
		_key_rx.compile("^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$")
	return _key_rx.search(text) != null


static func _dev(dev: StringName) -> StringName:
	return dev if dev != &"" else UiNav.device()


## The family of the pad in use, read from its SDL name (Input.get_joy_name): "DualSense Wireless Controller" -> playstation,
## "Nintendo Switch Pro Controller" -> nintendo, anything else (and no pad at all) -> xbox.
static func pad_family() -> StringName:
	var w := UiNav.watcher()
	var joy_name := str(w.get("pad_name")) if w != null else ""
	if joy_name == "" and not Input.get_connected_joypads().is_empty():
		joy_name = Input.get_joy_name(Input.get_connected_joypads()[0])
	return pad_family_of(joy_name)


static func pad_family_of(joy_name: String) -> StringName:
	var n := joy_name.to_lower()
	for word in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if n.contains(word):
			return PLAYSTATION
	for word in ["nintendo", "switch", "joy-con", "joycon"]:
		if n.contains(word):
			return NINTENDO
	return XBOX


## The short label of the key / button an action has on the device ("E", "Enter", "Esc", "Mellemrum", "A", "RB", "D-pad" ...); "" = none.
## `family` picks the pad labels (default: the pad in use).
static func glyph(action: StringName, dev: StringName = &"", family: StringName = &"") -> String:
	var d := _dev(dev)
	if not InputMap.has_action(action):
		return ""
	var events := InputMap.action_get_events(action)
	if d == GAMEPAD:
		var f := family if PAD_LABELS.has(family) else pad_family()
		for ev in events:
			if ev is InputEventJoypadButton:
				return _pad_name((ev as InputEventJoypadButton).button_index, f)
		for ev in events:
			if ev is InputEventJoypadMotion:
				var label := _axis_name(ev as InputEventJoypadMotion, f)
				if label != "":
					return label
		return ""
	for ev in events:
		if ev is InputEventKey:
			return _key_name(ev as InputEventKey)
	for ev in events:
		if ev is InputEventMouseButton:
			var word: String = MOUSE_WORDS.get((ev as InputEventMouseButton).button_index, "")
			if word != "":
				return TranslationServer.translate(word)
	return ""


## Every binding of the action on the device, joined: "E / Enter", "X / Venstre klik", "X / RS↑" (the controls page lists them all;
## a hint shows only glyph()). "" = none.
static func glyph_all(action: StringName, dev: StringName = &"") -> String:
	var d := _dev(dev)
	if not InputMap.has_action(action):
		return ""
	var family := pad_family()
	var parts: Array[String] = []
	for ev in InputMap.action_get_events(action):
		var label := ""
		if d == GAMEPAD:
			if ev is InputEventJoypadButton:
				label = _pad_name((ev as InputEventJoypadButton).button_index, family)
			elif ev is InputEventJoypadMotion:
				label = _axis_name(ev as InputEventJoypadMotion, family)
		elif ev is InputEventKey:
			label = _key_name(ev as InputEventKey)
		elif ev is InputEventMouseButton and MOUSE_WORDS.has((ev as InputEventMouseButton).button_index):
			label = str(TranslationServer.translate(str(MOUSE_WORDS[(ev as InputEventMouseButton).button_index])))
		if label != "" and label not in parts:
			parts.append(label)
	return " / ".join(parts)


## One label for two or more actions: "↑↓" (the arrows run together), "PgUp PgDn" / "LB RB" (words and pad letters are separated by a space), "D-pad" when every
## action of the set is a D-pad button.
static func glyph_set(actions: Array, dev: StringName = &"") -> String:
	var d := _dev(dev)
	var parts: Array[String] = []
	var all_dpad := true
	for a in actions:
		var g := glyph(StringName(a), d)
		if g == "":
			return ""
		parts.append(g)
		if d == GAMEPAD and not _is_dpad(StringName(a)):
			all_dpad = false
	if d == GAMEPAD and all_dpad:
		return str(TranslationServer.translate("NAV_PAD_DPAD"))
	var arrows := true
	for g in parts:
		arrows = arrows and g in KEY_ARROWS.values()
	return "".join(parts) if arrows else " ".join(parts)               # "↑↓" stays one token, words and pad letters are told apart: "PgUp PgDn", "LB RB"


static func glyph_pair(a: StringName, b: StringName, dev: StringName = &"") -> String:
	return glyph_set([a, b], dev)


## tr(key) with %s := the glyph of the action: format("HINT_CONTINUE", &"interact") -> "E for at fortsætte".
static func format(key: String, action: StringName) -> String:
	var text: String = str(TranslationServer.translate(key))
	return text % glyph(action) if text.contains("%s") else text


## A prompt that carries its key in the text ("E: Sov", "E · Tal med Pippin") -> {key: true, token: "E", rest: "Sov"}. The leading token is
## ONE character (a letter or a digit); anything else ("Sov: i sengen") is just text -> {key: false, token: "", rest: text}.
static func split_prompt(text: String) -> Dictionary:
	for sep in PROMPT_SEPARATORS:
		var at := text.find(sep)
		if at == 1:
			var token := text.substr(0, 1)
			if token.to_upper() == token and (token.is_valid_int() or token.unicode_at(0) != token.to_lower().unicode_at(0)):
				return {"key": true, "token": token, "rest": text.substr(at + sep.length())}
	return {"key": false, "token": "", "rest": text}


static func _is_dpad(action: StringName) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and int((ev as InputEventJoypadButton).button_index) in PAD_DPAD:
			return true
	return false


static func _pad_name(button: int, family: StringName = XBOX) -> String:
	var labels: Dictionary = PAD_LABELS.get(family, PAD_LABELS[XBOX])
	if labels.has(button):
		var label := str(labels[button])
		return str(TranslationServer.translate(label)) if is_key(label) else label
	if button in PAD_DPAD:
		return TranslationServer.translate("NAV_PAD_DPAD")
	return ""


## "LT" for a trigger, "RS↑" for a right-stick direction; "" for the left stick (movement) and unknown axes.
static func _axis_name(ev: InputEventJoypadMotion, family: StringName = XBOX) -> String:
	var axes: Dictionary = PAD_AXES.get(family, PAD_AXES[XBOX])
	if not axes.has(ev.axis):
		return ""
	var label := str(axes[ev.axis])
	if STICK_ARROWS.has(ev.axis):
		label += str(STICK_ARROWS[ev.axis][0 if ev.axis_value < 0.0 else 1])
	return label


## The label of a key event: the arrows, the words of KEY_WORDS, else the engine's name of the (layout-resolved) key.
static func _key_name(ev: InputEventKey) -> String:
	var code: int = int(ev.keycode)
	if ev.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":      # the headless display server cannot map a physical key (it logs an error)
		code = int(DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode))
	elif ev.physical_keycode != KEY_NONE:
		code = int(ev.physical_keycode)
	if KEY_ARROWS.has(code):
		return str(KEY_ARROWS[code])
	if KEY_WORDS.has(code):
		return TranslationServer.translate(str(KEY_WORDS[code]))
	return OS.get_keycode_string(code as Key)


## Localized dialogue/hint rows can name action groups for a device. The group
## expresses cycling the hotbar on a pad instead of pretending it has digit keys.
static func format_line(row: Dictionary) -> String:
	var key := str(row.get("text_key", row.get("key", "")))
	var text := str(TranslationServer.translate(key)) if key != "" else str(row.get("text", ""))
	var values := LuaData.arr(row.get("format_values",[]))
	if not values.is_empty():return text % values
	if not text.contains("%s"):
		return text
	var groups := LuaData.arr(row.get("format_action_groups_gamepad", [])) if UiNav.device() == GAMEPAD else []
	values = []
	if not groups.is_empty():
		for group in groups:
			values.append(glyph_set(LuaData.arr(group)))
	else:
		var actions := LuaData.arr(row.get("format_actions", []))
		if actions.is_empty() and str(row.get("glyph", "")) != "":
			actions.append(str(row.glyph))
		for action in actions:
			values.append(glyph(StringName(str(action))))
	return text % values if not values.is_empty() else text
