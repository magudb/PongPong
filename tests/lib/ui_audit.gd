class_name UiAudit
extends RefCounted
## UI conformance audit library: "do the menus and navigations follow the Trætoppen style guide?" as code.
## The recipe for a package that builds a screen is in the header of tests/sections/ui_audit.gd; the screen registry is tests/lib/ui_screens.json.
## Everything here is static; the audits that press keys are coroutines (`await`) and take the harness object `t` (tests/lib/t.gd).
##
## API (names are fixed, the navigation spec is written against them; every function has an optional last `options` Dictionary):
##   UiAudit.focusable_report(root)                 -> Dictionary   every interactive control, its focus mode and focus style (gold ring or not)
##   await UiAudit.focus_walk(t, root, max_steps)   -> Dictionary   real ui_* presses (D-pad actions AND arrow keys): order, unreachable, traps, focus loss,
##                                                                  dead ends, wrap, geometry, replay, sliders, tab bars, radio tabs (the page behind every PillTab / Chip
##                                                                  of a ButtonGroup), ui_accept. max_steps 0 (default) = automatic: 8 per control + 60, 200 .. 4000
##   UiAudit.initial_focus(root)                    -> Control      the control that owns focus after the screen opened (null = defect)
##   await UiAudit.escape_chain(t, opener, depth)   -> Dictionary   Esc closes the TOP modal first, focus returns to the opener, the game unpauses
##   UiAudit.rule_report(root)                      -> Dictionary   R1 ink, R2 gold, R3 numbers, R4 red, typography, copy, hit targets
##   await UiAudit.ring_pixels(t, control)          -> Dictionary   windowed: the gold focus ring is really in the frame (with a negative control)
##   UiAudit.screens() / await UiAudit.audit_screen(t, id)           the registry and "run every check listed for the screen" (live / legacy / pending)
## Extras: initial_focus_report (the check behind initial_focus), text_field_audit, locale_flip_report, rule_report_locales (the rule scan once per language),
## rule_report_pages / focusable_report_pages / radio_groups (the same reports on the page behind every radio tab or chip: N-1 of N pages would otherwise never be
## scanned), validate_options (every option name and value is checked: a typo is the defect `bad_option`, never a silent switch-off),
## theme_report (+ strict_gold_hover / strict_focus_styles / strict_font_scale), mouse_walk (hover / click focus), panel_pixels / button_pixels (windowed profiles),
## scene_text_report / script_text_report (hard-coded copy in a .tscn / .gd), expect (a report as one harness check), open_screen / close_screen (a registry screen by
## hand), selftest (planted controls built in code: proves the library on this machine), device_swap (one real event of the keyboard / pad / mouse), press /
## press_key / press_pad / press_cancel / accept_works (input helpers for the packages' own tests), audit_all, screen / screens_by_status, entry_kind / entry_checks
## (how a registry row is read), use_registry, summary / lines (printing).
## escape_chain options beyond the contract: internal_layers + internal_depth (pages inside a screen close first, the modal stack does not move), pre_opened +
## base_stack / base_phase / base_paused (the screen opened itself: a registry row), world_probe, expect_focus, release_world_focus, key / via, settle_seconds
## (real time for a modal that fades out before it pops). Depth 0 with pre_opened presses the key once ("Esc does nothing": the title, the sleep fade).
##
## Every report is a Dictionary with `ok` (bool), `defects` (Array of {code, path, msg, ...}) and `notes` (exemptions used, tokens, hints). `path` is relative to
## the audited root. A defect `code` is stable: DEFECTS below lists all of them with the check that raises them, and tests/sections/ui_audit.gd proves each
## one against a planted fixture (and a mutation of the code against the section). Screens that are Windows (ConfirmationDialog) are audited in their own
## viewport. Guide exemptions are explicit (see tests/lib/ui_audit_rules.gd): node meta tt_audit_ignore / tt_gold_ok / tt_r1_ok / tt_r3_ok / tt_hit_ok /
## tt_text_same_ok / tt_override_ok / tt_focus_style / tt_focus_proxy_for, and registry options (ignore globs, hit_min, strict_typography, same_ok, wrap, max_steps,
## accept, pages, tab_groups).
## KNOWN LIMITS (what the audit does not see; the windowed pixel checks and the guide diffs cover it): gold or red that a script builds at run time from numbers (the
## source scan reads the constant GOLD and the hex values), a control that changes its look after the audit returned, and anything inside a SubViewport. A Window
## (ConfirmationDialog ...) is only seen when it is in the tree or when a script names it (`X.new()`, `.popup_centered()`).

const Rules = preload("res://tests/lib/ui_audit_rules.gd")
const REGISTRY_PATH := "res://tests/lib/ui_screens.json"
const FIXTURES = preload("res://scripts/ui/dev/ui_fixtures.gd")

const DIR_ACTIONS: Array[StringName] = [&"ui_down", &"ui_right", &"ui_up", &"ui_left"]
const DIR_VECTORS := {&"ui_down": Vector2(0, 1), &"ui_right": Vector2(1, 0), &"ui_up": Vector2(0, -1), &"ui_left": Vector2(-1, 0)}
const DIR_KEYS := {&"ui_down": KEY_DOWN, &"ui_right": KEY_RIGHT, &"ui_up": KEY_UP, &"ui_left": KEY_LEFT, &"ui_accept": KEY_ENTER, &"ui_cancel": KEY_ESCAPE}
const SETTLE_FRAMES := 2

## Every defect code, the check that raises it and what it means. The section asserts that each one has a planted-defect test.
const DEFECTS := {
	"unfocusable_interactive": ["focusable", "a visible, enabled button / field / slider has focus_mode NONE: the keyboard and the gamepad cannot reach it"],
	"focus_click_only": ["focusable", "focus_mode CLICK: the control takes focus from the mouse only"],
	"no_focus_style": ["focusable", "the control has no visible focus indicator (empty focus stylebox; a Slider has none unless a script draws its focus style)"],
	"focus_style_not_gold": ["focusable", "the focus indicator exists but is not the guide's gold ring"],
	"mouse_only_clickable": ["focusable", "a custom control handles mouse input (gui_input) but cannot take focus"],
	"hud_focusable": ["focusable", "a HUD control can take focus (HUD controls must be FOCUS_NONE, plan R.14)"],
	"window_in_screen": ["focusable", "a Window-based control (ConfirmationDialog, OptionButton popup ...) is part of a game screen (options.forbid_windows)"],
	"disabled_focusable": ["focusable", "a disabled control is a keyboard focus stop (options.forbid_disabled_focus; Godot lets focus land on disabled buttons)"],
	"hud_blocks_mouse": ["focusable", "a large HUD control (>= 25 % of the screen) that is not a button stops mouse clicks: the world below it (use_tool / attack on LMB) is unreachable; set mouse_filter IGNORE"],
	"screen_not_open": ["initial_focus", "the screen's is_open() is false: it was not opened (or has closed) before the audit asked for its focus"],
	"no_initial_focus": ["initial_focus", "nothing under the screen owns focus when it opens: the keyboard cannot start navigating"],
	"initial_focus_disabled": ["initial_focus", "the initial focus sits on a disabled control (it should be the first enabled one)"],
	"initial_focus_outside": ["initial_focus", "focus is on a control outside the screen (the screen did not take it)"],
	"nothing_to_walk": ["focus_walk", "the screen has no interactive control: drop focus_walk from its checks, or open it in a state that has controls"],
	"nothing_focusable": ["focus_walk", "the screen has interactive controls but none can take keyboard focus"],
	"unreachable": ["focus_walk", "a control is never reached by ui_up/down/left/right from the initial focus"],
	"only_via_tab": ["focus_walk", "a control is reachable with Tab (ui_focus_next) only, not with the directional keys or a gamepad"],
	"trap": ["focus_walk", "focus can enter this control but the directional keys never lead back to the initial focus"],
	"focus_lost": ["focus_walk", "a directional press leaves no focus owner at all"],
	"focus_escaped": ["focus_walk", "a directional press moves focus out of the screen (behind a modal, onto the world)"],
	"dead_end": ["focus_walk", "a direction has no neighbour although the screen requires wrapping (options.wrap = required)"],
	"nav_geometry": ["focus_walk", "a direction moves focus the wrong way (ui_down goes up ...) although a control lies that way"],
	"walk_replay_mismatch": ["focus_walk", "pressing the recorded keys from the initial focus does not land where the probe landed (navigation depends on history)"],
	"accept_dead": ["focus_walk", "ui_accept does not activate a focused button (options.accept lists the buttons that were pressed)"],
	"slider_ignores_keys": ["focus_walk", "ui_left / ui_right do not change a focused slider"],
	"tab_keys_dead": ["focus_walk", "ui_left / ui_right do not switch tabs of a focused tab bar"],
	"edge_mismatch": ["focus_walk", "a neighbour differs from the owner's declared table (options.expect_edges)"],
	"echo_wraps": ["focus_walk", "a held key (echo press) crossed a wrap-around edge: holding a direction must stop at the ring's end (options.echo)"],
	"pad_mismatch": ["focus_walk", "a D-pad press does not lead where the keyboard / action press led (the gamepad cannot follow the keyboard's map)"],
	"walk_truncated": ["focus_walk", "max_steps ran out before every control was explored (raise max_steps)"],
	"text_field_dead": ["text_fields", "a text field does not take typed keys"],
	"typing_leaks_hotkey": ["text_fields", "typing in a text field also fires a game hotkey (inventory, journal ...) or a modal opens"],
	"world_saw_press": ["escape", "the world reacted to a press that was meant for the top modal (options.world_probe): the top layer must consume the event"],
	"modal_no_focus": ["escape", "after opening, focus did not move into the new modal (the keyboard would act on the screen behind it)"],
	"opener_depth_mismatch": ["escape", "opening a modal did not add exactly one entry to the GameManager modal stack"],
	"esc_does_not_close": ["escape", "Esc / ui_cancel does not close the top modal"],
	"esc_wrong_order": ["escape", "Esc closed a modal that is not the top one"],
	"esc_closes_several": ["escape", "one Esc closed more than one modal"],
	"esc_opens_modal": ["escape", "Esc opened another modal on top instead of closing the top one"],
	"focus_not_restored": ["escape", "after the modal closed, focus did not return to the control that opened it"],
	"modal_stack_leak": ["escape", "modals are left on the stack after the chain closed"],
	"game_stays_paused": ["escape", "the tree is still paused after the last modal closed"],
	"phase_not_restored": ["escape", "GameManager.current_phase is not what it was before the chain"],
	"no_game_manager": ["escape", "the GameManager autoload is missing"],
	"r1_no_ink_outline": ["r1", "an opaque light box has no 2 px ink outline (guide rule 'Blæk omkring alt')"],
	"r2_gold_decoration": ["r2", "gold is used outside focus / selected (guide rule 'Guld betyder valgt')"],
	"r3_number_not_display": ["r3", "a number, count, money or time is not set in Caprasimo (guide rule 'Tal i Caprasimo')"],
	"r4_red": ["r4", "a red colour is in use (guide rule 'Ingen rød fare': thorn-berry pink instead)"],
	"font_below_floor": ["typography", "text below the 11 px floor"],
	"font_too_small_display": ["typography", "Caprasimo below 20 px"],
	"font_too_small_body": ["typography", "Alegreya Sans below 18 px (not a theme token)"],
	"raw_key": ["i18n", "a raw translation key is shown on screen"],
	"hardcoded_literal": ["i18n", "Danish / English copy is written into the scene or script instead of a translation key"],
	"not_localized": ["i18n_flip", "text did not change when the language changed (a literal, or a screen that does not re-label on NOTIFICATION_TRANSLATION_CHANGED)"],
	"hit_target_small": ["hit_targets", "an interactive control is smaller than 32 px (spec 10.6; options.hit_min; the guide's HintButton / VersionButton tags keep a 20 px floor)"],
	"theme_override": ["overrides", "a node carries a per-node font / font size / font colour override: a screen uses theme type variations only (plan 5.1)"],
	"no_theme": ["theme", "no project theme is loaded, so the theme scan has nothing to read"],
	"bad_option": ["registry", "an option name or value is not one the audit knows: a typo would silently switch a requirement off (UiAudit.validate_options)"],
	"radio_select_dead": ["focus_walk", "a member of a radio group (a tab, a chip) does not become selected when it is focused and accepted: the page behind it is never audited and the player cannot open it"],
	"screen_not_visible": ["visible", "the screen is hidden after opening (modal roots hide in _ready): the entry needs a driver that opens it"],
	"no_root": ["registry", "the audit was given no screen: a null, freed or detached node"],
	"hover_grabs_focus": ["mouse_walk", "a control took keyboard focus on mouse hover although it is not a list-like row"],
	"hover_no_focus": ["mouse_walk", "a list-like row did not take focus when the mouse entered it"],
	"click_drops_focus": ["mouse_walk", "after a click no control owns keyboard focus"],
	"opens_failed": ["registry", "a live or legacy registry entry could not be opened (missing scene, driver returned null)"],
	"registry_error": ["registry", "a registry entry is inconsistent (unknown check name, an escape check without a driver)"],
	"theme_gold_hover": ["theme", "gold in a normal / hover / disabled style of a variation that is not a guide ornament (options.strict_gold_hover)"],
	"theme_focus_empty": ["theme", "an interactive theme type has no focus StyleBox (options.strict_focus_styles)"],
	"theme_font_scale": ["theme", "a text variation is below the smallest guide size (options.strict_font_scale)"],
	"focus_style_not_gold_theme": ["theme", "a theme type's focus style has no gold ring"],
	"ring_missing": ["ring", "(windowed) the focused control shows no gold ring in the frame"],
	"ring_always_on": ["ring", "(windowed) the negative control: the ring pixels are gold although the control is not focused"],
	"ring_ink_missing": ["ring", "(windowed) the gold ring has no ink band 4-5 px outside it"],
	"panel_edge_wrong": ["panel_pixels", "(windowed) the panel edge is not parchment / ink 2 / gold 4 / ink 2"],
	"button_profile_wrong": ["button_pixels", "(windowed) the button profile (ink border, face, band, ink border, 4 px hard underside) is not the guide's"],
}
## Defect codes that only a windowed run can raise (the headless section lists them as SKIP).
const WINDOWED_ONLY: Array[String] = ["ring_missing", "ring_always_on", "ring_ink_missing", "panel_edge_wrong", "button_profile_wrong"]

static var _registry: Dictionary = {}
static var _registry_path := REGISTRY_PATH
## The viewport the presses go to while an audit runs: the audited screen's own (a ConfirmationDialog is a Window with its own focus owner), else t.root.
static var _vp: Viewport = null


# ---------------------------------------------------------------------------------------------------- input helpers

## One InputEventAction press + release pushed into the root viewport (the whole GUI pipeline: _input, focus navigation, _unhandled_input).
static func press(t, action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.strength = 1.0
	_viewport(t).push_input(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	_viewport(t).push_input(up)


static func _viewport(t) -> Viewport:
	return _vp if _vp != null and is_instance_valid(_vp) and _vp.is_inside_tree() else t.root


## A real key press (arrow, Enter, Esc) as the keyboard sends it: text fields consume the caret keys, Esc matches ui_cancel AND pause.
static func press_key(t, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	_viewport(t).push_input(ev)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	_viewport(t).push_input(up)


## One held-key repeat: an InputEventKey with echo = true (what the OS sends while the key stays down).
static func _press_echo(t, action: StringName) -> void:
	var ev := InputEventKey.new()
	ev.keycode = DIR_KEYS[action]
	ev.physical_keycode = DIR_KEYS[action]
	ev.pressed = true
	ev.echo = true
	_viewport(t).push_input(ev)


## One gamepad button press + release (InputEventJoypadButton), e.g. JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START.
static func press_pad(t, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	_viewport(t).push_input(ev)
	var up := InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	_viewport(t).push_input(up)


## Sends ONE harmless event of an input device so a device tracker (UiNav.device()) flips to it: dev = "keyboard" (Shift pressed and released, no action),
## "pad" (the left-stick click, pressed and released), "mouse" (a 3 px motion). Real events through the root viewport, never an InputEventAction.
static func device_swap(t, dev: String) -> void:
	var vp := _viewport(t)
	match dev:
		"keyboard":
			for pressed in [true, false]:
				var ev := InputEventKey.new()
				ev.keycode = KEY_SHIFT
				ev.physical_keycode = KEY_SHIFT
				ev.pressed = pressed
				vp.push_input(ev)
		"pad":
			for pressed in [true, false]:
				var ev := InputEventJoypadButton.new()
				ev.button_index = JOY_BUTTON_LEFT_STICK
				ev.pressed = pressed
				vp.push_input(ev)
		"mouse":
			var mv := InputEventMouseMotion.new()
			var at := Vector2(vp.get_visible_rect().size) * 0.5
			mv.position = at + Vector2(3, 0)
			mv.global_position = mv.position
			mv.relative = Vector2(3, 0)
			vp.push_input(mv)
	await t.frames(1)


## Esc the way a player does it. via: "key" (the Esc key: matches ui_cancel AND pause), "action" (ui_cancel alone), "pause" (pause alone), "pad_b" (joypad B =
## ui_cancel), "start" (joypad Start = pause).
static func press_cancel(t, via := "key") -> void:
	match via:
		"action":
			press(t, &"ui_cancel")
		"pause":
			press(t, &"pause")
		"pad_b":
			press_pad(t, JOY_BUTTON_B)
		"start":
			press_pad(t, JOY_BUTTON_START)
		_:
			press_key(t, KEY_ESCAPE)


const DIR_PAD := {&"ui_down": JOY_BUTTON_DPAD_DOWN, &"ui_right": JOY_BUTTON_DPAD_RIGHT, &"ui_up": JOY_BUTTON_DPAD_UP, &"ui_left": JOY_BUTTON_DPAD_LEFT,
	&"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B}


static func _press_dir(t, action: StringName, via: String) -> void:
	if via == "key" and DIR_KEYS.has(action):
		press_key(t, DIR_KEYS[action])
	elif via == "pad" and DIR_PAD.has(action):
		press_pad(t, DIR_PAD[action])
	else:
		press(t, action)


## Does ui_accept activate this button / toggle? (presses it: only call it on a control whose action is harmless in a test).
static func accept_works(t, control: Control, via := "action") -> bool:
	if not (control is BaseButton) or control.focus_mode != Control.FOCUS_ALL:
		return false
	var hits := [0]
	var cb := func(_a = null) -> void: hits[0] += 1
	var b := control as BaseButton
	var prev_vp := _vp
	_vp = control.get_viewport()
	b.pressed.connect(cb)
	control.grab_focus()
	await t.frames(1)
	_press_dir(t, &"ui_accept", via)
	await t.frames(1)
	b.pressed.disconnect(cb)
	_vp = prev_vp
	return hits[0] > 0


static func _owner(t) -> Control:
	return _viewport(t).gui_get_focus_owner()


static func _inside(root: Node, c: Node) -> bool:
	return c != null and (c == root or root.is_ancestor_of(c))


static func _rel(root: Node, n: Node) -> String:
	return Rules.rel_path(root, n) if n != null else ""


static func _usable(root: Node) -> bool:
	return root != null and is_instance_valid(root) and root.is_inside_tree()


static func _no_root(what: String) -> Dictionary:
	var r := {"ok": false, "defects": [] as Array, "notes": [] as Array}
	_defect(r, "no_root", "", "%s was given no usable screen (null, freed or not in the tree)" % what)
	return r


static func _report() -> Dictionary:
	return {"ok": true, "defects": [] as Array, "notes": [] as Array}


static func _defect(report: Dictionary, code: String, path: String, msg: String, extra: Dictionary = {}) -> void:
	var d := {"code": code, "path": path, "msg": msg}
	d.merge(extra)
	(report["defects"] as Array).append(d)
	report["ok"] = false


static func _note(report: Dictionary, msg: String, path := "") -> void:
	(report["notes"] as Array).append({"path": path, "msg": msg})


## "3 defects: unreachable x2, trap" - the one-line verdict of a report.
static func summary(report: Dictionary) -> String:
	var defects: Array = report.get("defects", [])
	if defects.is_empty():
		return "clean"
	var counts := {}
	for d in defects:
		counts[d["code"]] = int(counts.get(d["code"], 0)) + 1
	var parts: Array[String] = []
	for k in counts:
		parts.append("%s x%d" % [k, counts[k]] if int(counts[k]) > 1 else str(k))
	return "%d defect(s): %s" % [defects.size(), ", ".join(parts)]


## One printable line per defect (at most `max_lines`).
static func lines(report: Dictionary, max_lines := 12) -> Array[String]:
	var out: Array[String] = []
	var defects: Array = report.get("defects", [])
	for i in mini(defects.size(), max_lines):
		var d: Dictionary = defects[i]
		out.append("%s %s: %s" % [d["code"], d.get("path", ""), d.get("msg", "")])
	if defects.size() > max_lines:
		out.append("... %d more" % (defects.size() - max_lines))
	return out


# ---------------------------------------------------------------------------------------------------- options (a typo must not switch a requirement off)

## The option names every function accepts. `registry` is the `options` object of a registry row (the union a row may carry).
const OPTION_KEYS := {
	"focus_walk": ["wrap", "wrap_axes", "ignore", "skip", "via", "replay", "tabs", "accept", "consumes", "expect_edges", "echo", "pad_check", "dirs", "start", "real_keys", "pages", "max_pages", "tab_groups"],
	"focusable_report": ["ignore", "forbid_focus", "forbid_disabled_focus", "forbid_windows", "pages", "max_pages", "tab_groups", "via"],
	"rule_report": ["rules", "ignore", "strict_typography", "strict_gold", "gold_source", "hit_min", "literal_files", "locale_sweep", "pages", "max_pages", "tab_groups", "via"],
	"escape_chain": ["key", "via", "vias", "settle", "settle_seconds", "world_probe", "expect_focus", "release_world_focus", "pre_opened", "base_stack", "base_phase", "base_paused", "internal_layers", "internal_depth", "depth"],
	"text_field_audit": ["ignore", "press_enter"],
	"locale_flip_report": ["ignore", "same_ok"],
	"mouse_walk": ["ignore", "list_like", "click"],
	"ring_pixels": ["tolerance", "other", "style", "shot", "focus", "expect", "allow_missing_sides"],
	"panel_pixels": ["shot", "tolerance"],
	"button_pixels": ["shot", "tolerance", "underside"],
	"theme_report": ["strict_gold_hover", "strict_focus_styles", "strict_font_scale"],
	"registry": ["ignore", "max_steps", "wrap", "wrap_axes", "via", "tabs", "replay", "accept", "consumes", "expect_edges", "echo", "pad_check", "dirs", "start", "pages", "max_pages", "tab_groups",
		"strict_typography", "strict_gold", "gold_source", "hit_min", "same_ok", "forbid_disabled_focus", "forbid_windows", "list_like", "click", "panel", "button", "strict_gold_hover",
		"strict_focus_styles", "strict_font_scale", "settle_seconds"],
}
const BOOL_OPTIONS: Array[String] = ["replay", "tabs", "echo", "pad_check", "pages", "real_keys", "forbid_focus", "forbid_disabled_focus", "forbid_windows", "strict_typography", "strict_gold",
	"gold_source", "release_world_focus", "pre_opened", "focus", "underside", "press_enter", "strict_gold_hover", "strict_focus_styles", "strict_font_scale"]
const RULE_NAMES: Array[String] = ["r1", "r2", "r3", "r4", "typography", "overrides", "i18n", "hit_targets"]


## The problems with an options Dictionary for `fn` (one text each): an unknown name, a value outside the vocabulary, a wrong type. Empty = fine. The registry check
## (tests/sections/ui_audit.gd registry_valid) runs this on every row's `options` with fn "registry"; every audit function runs it on its own options and reports `bad_option`.
static func validate_options(fn: String, options: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var allowed: Array = OPTION_KEYS.get(fn, [])
	if allowed.is_empty():
		return out
	for k in options:
		var key := str(k)
		if not allowed.has(key):
			out.append("unknown option '%s' for %s (known: %s)" % [key, fn, ", ".join(allowed)])
			continue
		out.append_array(_option_problems(fn, key, options[k]))
	return out


## The problems with ONE option value (empty = fine).
static func _option_problems(fn: String, key: String, v: Variant) -> Array[String]:
	var out: Array[String] = []
	if key in BOOL_OPTIONS and typeof(v) != TYPE_BOOL:
		out.append("option '%s' must be true or false, not %s" % [key, str(v)])
	match key:
		"wrap":
			if str(v) not in ["any", "required"]:
				out.append("option 'wrap' must be \"any\" or \"required\", not '%s'" % str(v))
		"wrap_axes":
			var ax := str(v)
			var bad_ax := ax == ""
			for ch in ax:
				bad_ax = bad_ax or ch not in ["v", "h"]
			if bad_ax:
				out.append("option 'wrap_axes' must be made of v and h (\"v\", \"h\", \"vh\"), not '%s'" % ax)
		"via":
			var vias: Array = ["both", "action", "key"] if fn in ["focus_walk", "registry"] else (["key", "action", "pause", "pad_b", "start"] if fn == "escape_chain" else ["both", "action", "key", "pad"])
			if str(v) not in vias:
				out.append("option 'via' must be one of %s for %s, not '%s'" % [str(vias), fn, str(v)])
		"vias":
			if not (v is Array) or (v as Array).is_empty():
				out.append("option 'vias' must be a non-empty Array of key / action / pause / pad_b / start")
			else:
				for e in v:
					if str(e) not in ["key", "action", "pause", "pad_b", "start"]:
						out.append("option 'vias' lists '%s': use key, action, pause, pad_b or start" % str(e))
		"dirs":
			if not (v is Array):
				out.append("option 'dirs' must be an Array of up / down / left / right")
			else:
				for e in v:
					if str(e) not in ["up", "down", "left", "right"]:
						out.append("option 'dirs' lists '%s': use up, down, left or right" % str(e))
		"accept":
			if not (v is Array or str(v) == "all"):
				out.append("option 'accept' must be \"all\" or an Array of glob patterns")
		"rules":
			if not (v is Array):
				out.append("option 'rules' must be an Array of rule names")
			else:
				for e in v:
					if str(e) not in RULE_NAMES:
						out.append("option 'rules' lists '%s': use %s" % [str(e), ", ".join(RULE_NAMES)])
		"ignore", "skip", "same_ok", "list_like", "click", "literal_files", "locale_sweep", "tab_groups":
			if not (v is Array):
				out.append("option '%s' must be an Array" % key)
		"consumes", "expect_edges":
			if not (v is Dictionary):
				out.append("option '%s' must be a Dictionary {path: ...}" % key)
		"max_steps", "max_pages", "settle", "internal_layers", "allow_missing_sides":
			var whole := typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and floorf(float(v)) == float(v))      # (a number read from JSON is a float)
			if not whole or int(v) < 0:
				out.append("option '%s' must be a whole number >= 0, not %s" % [key, str(v)])
		"hit_min", "tolerance", "settle_seconds":
			if (typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT) or float(v) < 0.0:
				out.append("option '%s' must be a number >= 0, not %s" % [key, str(v)])
	return out


## `options` without what validate_options rejects (the unknown names and the values of the wrong kind): the audit reports those as `bad_option` and runs on the rest, so a mistyped
## value (echo: "yes") can neither crash a check nor silently change it.
static func _sane(fn: String, options: Dictionary) -> Dictionary:
	var allowed: Array = OPTION_KEYS.get(fn, [])
	if allowed.is_empty():
		return options
	var out := {}
	for k in options:
		if allowed.has(str(k)) and _option_problems(fn, str(k), options[k]).is_empty():
			out[k] = options[k]
	return out


static func _option_defects(fn: String, options: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for msg in validate_options(fn, options):
		out.append({"code": "bad_option", "path": fn, "msg": msg})
	return out


static func _merge_option_defects(report: Dictionary, defects: Array[Dictionary]) -> void:
	for d in defects:
		(report["defects"] as Array).append(d)
		report["ok"] = false


# ---------------------------------------------------------------------------------------------------- initial focus

## The control that owns keyboard focus after the screen has opened, if it is the screen's own (root or a descendant) and on screen; else null.
## A null result is the defect: a screen must grab focus by itself when it opens. Call it after the screen had a frame or two.
static func initial_focus(root: Node) -> Control:
	if not _usable(root):
		return null
	var vp := root.get_viewport()
	if vp == null:
		return null
	var owner_ := vp.gui_get_focus_owner()
	if owner_ != null and _inside(root, owner_) and owner_.is_visible_in_tree():
		return owner_
	return null


## A screen that holds no focus owner in some mode (Indretning PLACE, a dialogue text line) says so with a `_wants_focus() -> bool` method (spec 4.2): while it returns false the audit
## asks for no initial focus and does not walk the screen. A screen without the method always wants focus.
static func _wants_focus(root: Node) -> bool:
	return not (root.has_method("_wants_focus") and not bool(root.call("_wants_focus")))


## initial_focus as a report: no_initial_focus / initial_focus_outside / initial_focus_disabled.
static func initial_focus_report(root: Node) -> Dictionary:
	if not _usable(root):
		return _no_root("initial_focus_report")
	var r := _report()
	if root.has_method("is_open") and not bool(root.call("is_open")):
		_defect(r, "screen_not_open", _rel(root, root), "%s.is_open() is false: open the screen (and wait two frames) before auditing its focus" % root.name)
		r["control"] = ""
		return r
	if not _wants_focus(root):
		r["control"] = ""
		_note(r, "%s declares _wants_focus() = false (a mode that holds no focus owner on purpose: Indretning PLACE, a dialogue text line): no initial focus is required" % root.name)
		return r
	var c := initial_focus(root)
	var vp := root.get_viewport()
	var any := vp.gui_get_focus_owner() if vp != null else null
	r["control"] = _rel(root, c)
	if c == null:
		if any != null:
			_defect(r, "initial_focus_outside", _rel(root, root), "focus is on %s, outside the screen" % any.get_path())
		else:
			_defect(r, "no_initial_focus", _rel(root, root), "no control of the screen owns focus when it opens (grab_focus() on the first enabled control, deferred if needed)")
		return r
	if not Rules.is_enabled(c):
		_defect(r, "initial_focus_disabled", _rel(root, c), "initial focus is on the disabled %s: focus the first enabled control" % Rules.class_name_of(c))
	return r


# ---------------------------------------------------------------------------------------------------- focusable report

## Static: every interactive control under `root`, its focus mode and whether its focus indicator is a gold ring. options: ignore (glob patterns),
## forbid_focus (HUD screens: no control may take focus at all), forbid_disabled_focus (a disabled control must not be a focus stop: Godot lets the
## keyboard land on disabled buttons, F5 of the spec), forbid_windows (no Window-based control in a game screen: ConfirmationDialog, OptionButton popups).
## Result: {ok, defects, notes, items: [{path, class, variation, focus_mode, disabled, mouse_filter, visible, rect, focus_visual ("stylebox" | "proxy" | "none"),
## focus_style (class name of the focus StyleBox or ""), focus_verdict, proxy_for, interactive, enabled}], focusable: [path], interactive_without_focus: [path],
## disabled_focusable: [path], windows: [path], interactive, controls (= items)}.
static func focusable_report(root: Node, options: Dictionary = {}) -> Dictionary:
	if not _usable(root):
		return _no_root("focusable_report")
	var bad := _option_defects("focusable_report", options)
	options = _sane("focusable_report", options)
	var r := _report()
	var forbid := bool(options.get("forbid_focus", false))
	var items: Array[Dictionary] = []
	var focusable: Array[String] = []
	var without_focus: Array[String] = []
	var disabled_focusable: Array[String] = []
	var windows: Array[String] = []
	for wn in Rules.nodes(root, options.get("ignore", []), false):       # hidden windows count too: an OptionButton's popup exists while it is closed
		if wn is Window and wn != root:
			windows.append(_rel(root, wn))
			if bool(options.get("forbid_windows", false)):
				_defect(r, "window_in_screen", _rel(root, wn), "%s is a Window: its focus lives in its own viewport and the audit / the player's keyboard model sees only the root viewport (use a Control dialog, chips instead of OptionButton)" % Rules.class_name_of(wn))
	if bool(options.get("forbid_windows", false)):                       # a dialog that is created when a button is pressed does not exist in the tree at open time: read the scripts
		for h in Rules.window_source_hits(root, options.get("ignore", [])):
			windows.append("%s:%d" % [h["file"], h["line"]])
			_defect(r, "window_in_screen", "%s:%d" % [h["file"], h["line"]], "the script creates a Window-based control (%s): its focus would live in its own viewport (use UiConfirm / chips instead)" % h["text"])
	for n in Rules.nodes(root, options.get("ignore", []), not forbid):
		if not (n is Control):
			continue
		var c := n as Control
		var rp := _rel(root, c)
		var interactive := Rules.is_interactive(c)
		var enabled := Rules.is_enabled(c)
		var visible := c.is_visible_in_tree()
		var item := {"path": rp, "class": Rules.class_name_of(c), "variation": String(c.theme_type_variation), "focus_mode": c.focus_mode, "disabled": interactive and not enabled,
			"mouse_filter": c.mouse_filter, "visible": visible, "rect": _rect_data(c.get_global_rect()), "interactive": interactive, "enabled": enabled,
			"focus_visual": "none", "focus_style": "", "focus_verdict": "n/a", "proxy_for": ""}
		if c.has_meta(&"tt_focus_proxy_for"):
			item["proxy_for"] = str(c.get_meta(&"tt_focus_proxy_for"))
		if c.focus_mode == Control.FOCUS_ALL and interactive and visible:
			focusable.append(rp)
		if forbid:
			if c.focus_mode != Control.FOCUS_NONE:
				_defect(r, "hud_focusable", rp, "%s has focus_mode %d: HUD controls are FOCUS_NONE" % [item["class"], c.focus_mode])
			if not interactive and visible and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				var vsz := Vector2(c.get_viewport().get_visible_rect().size)
				if c.size.x * c.size.y >= 0.25 * vsz.x * vsz.y:
					_defect(r, "hud_blocks_mouse", rp, "%s (%dx%d) has mouse_filter STOP: clicks on the world below the HUD are swallowed (use IGNORE or PASS)" % [item["class"], int(c.size.x), int(c.size.y)])
			items.append(item)
			continue
		if interactive and visible:
			var verdict := _focus_style_verdict(c)
			item["focus_verdict"] = verdict
			item["focus_style"] = _focus_style_class(c)
			item["focus_visual"] = "proxy" if verdict == "proxy" else ("none" if verdict == "none" else "stylebox")
			if not enabled:
				if c.focus_mode != Control.FOCUS_NONE:
					disabled_focusable.append(rp)
					if bool(options.get("forbid_disabled_focus", false)):
						_defect(r, "disabled_focusable", rp, "disabled %s is a keyboard focus stop (Godot lets focus land on it): set focus_mode NONE while it is disabled" % item["class"])
			else:
				if c.focus_mode == Control.FOCUS_NONE:
					without_focus.append(rp)
					_defect(r, "unfocusable_interactive", rp, "%s is interactive but has focus_mode NONE: the keyboard cannot reach it" % item["class"])
				elif c.focus_mode == Control.FOCUS_CLICK:
					without_focus.append(rp)
					_defect(r, "focus_click_only", rp, "%s has focus_mode CLICK: it takes focus from the mouse only" % item["class"])
				elif c.focus_mode != Control.FOCUS_ALL:
					without_focus.append(rp)
					_defect(r, "unfocusable_interactive", rp, "%s has focus_mode %d, which the keyboard does not use (only FOCUS_ALL is a keyboard stop; ACCESSIBILITY is for screen readers)" % [item["class"], c.focus_mode])
				else:
					if verdict == "none":
						_defect(r, "no_focus_style", rp, "%s has no visible focus indicator (a theme focus StyleBox, meta tt_focus_style for a control that paints its own ring, or meta tt_focus_proxy_for)" % item["class"])
					elif verdict == "not_gold":
						_defect(r, "focus_style_not_gold", rp, "%s focus indicator is not the guide's gold ring" % item["class"])
					elif verdict == "declared":
						_note(r, "%s paints its own focus ring (meta tt_focus_style): prove it windowed with UiAudit.ring_pixels" % rp, rp)
		elif not interactive and visible and _is_custom_clickable(c):
			_defect(r, "mouse_only_clickable", rp, "%s handles mouse input but cannot take focus: make it a Button or give it focus_mode ALL" % item["class"])
		items.append(item)
	r["items"] = items
	r["controls"] = items
	r["focusable"] = focusable
	r["interactive_without_focus"] = without_focus
	r["disabled_focusable"] = disabled_focusable
	r["windows"] = windows
	var n_inter := 0
	for i in items:
		if bool(i["interactive"]) and bool(i["visible"]):
			n_inter += 1
	r["interactive"] = n_inter
	_merge_option_defects(r, bad)
	return r


static func _is_custom_clickable(c: Control) -> bool:
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE or c.focus_mode != Control.FOCUS_NONE:
		return false
	if c is ScrollContainer or c is ScrollBar or c is BaseButton or c is Range or c is LineEdit or c is TextEdit:
		return false
	var a: Node = c.get_parent()
	while a != null:
		if a is BaseButton:
			return false
		a = a.get_parent()
	var script: Script = c.get_script()
	if script != null and c.has_method("_gui_input"):
		return true
	if script is GDScript and Rules.reads_mouse_in_input(script as GDScript):
		return true                                                # reads mouse buttons in _input / _unhandled_input instead of _gui_input
	for conn in c.gui_input.get_connections():
		var cb: Callable = conn["callable"]
		var target := cb.get_object() as Object                    # a handler of its own script (the control connects itself) counts as well as one of another scripted object
		if target != null and target.get_script() != null:
			return true
	return false


## "ok" | "none" | "not_gold" | "declared" | "proxy" for the focus indicator of an interactive control: a gold theme focus StyleBox ("ok"), an empty or missing one
## ("none"), one without gold ("not_gold"), a control that paints its own ring and says so with meta tt_focus_style ("declared"), a draw-only component stood in for
## by a focusable proxy with meta tt_focus_proxy_for ("proxy"). Godot's Slider draws no focus indicator at all: it needs a script that paints get_theme_stylebox("focus").
## A Rect2 as plain JSON data: {x, y, w, h} in the root viewport's design pixels (every report is JSON-serialisable).
static func _rect_data(rc: Rect2) -> Dictionary:
	return {"x": rc.position.x, "y": rc.position.y, "w": rc.size.x, "h": rc.size.y}


static func _focus_style_verdict(c: Control) -> String:
	if c.has_meta(&"tt_focus_proxy_for"):
		var proxy := c.get_node_or_null(NodePath(str(c.get_meta(&"tt_focus_proxy_for"))))
		return "proxy" if proxy != null else "none"
	if c.has_meta(&"tt_focus_style"):
		return "declared"
	if c is Slider:
		# Godot's Slider never draws a `focus` StyleBox, so an entry in the theme is not a ring (probed in 4.7.2 and looked at): only a slider that paints the
		# style itself and says so (meta tt_focus_style, set by TTSlider) has one
		return "none"
	var name_ := "tab_focus" if c is TabBar else "focus"
	if c is TextureButton and (c as TextureButton).texture_focused != null:
		return "declared"
	if not c.has_theme_stylebox(name_):
		return "none"
	var sb := c.get_theme_stylebox(name_)
	if sb == null or sb is StyleBoxEmpty:
		return "none"
	return "ok" if _style_has_gold(sb) else "not_gold"


static func _focus_style_class(c: Control) -> String:
	var name_ := "tab_focus" if c is TabBar else "focus"
	if c.has_theme_stylebox(name_):
		var sb := c.get_theme_stylebox(name_)
		return sb.get_class() if not (sb is StyleBoxEmpty) else ""
	return ""


static func _style_has_gold(sb: StyleBox) -> bool:
	for col in Rules.style_colors(sb):
		if Rules.is_gold(col):
			return true
	return false


# ---------------------------------------------------------------------------------------------------- focus walk

## Interactive, enabled, visible controls the keyboard must reach (SpinBox is represented by its inner LineEdit).
static func _expected(root: Node, ignore: Array) -> Array[Control]:
	var out: Array[Control] = []
	for n in Rules.nodes(root, ignore):
		if n is Control and not (n is SpinBox) and Rules.is_interactive(n as Control) and Rules.is_enabled(n as Control):
			out.append(n as Control)
	return out


const SHORT_DIRS := {&"ui_down": "down", &"ui_right": "right", &"ui_up": "up", &"ui_left": "left"}


static func _skip_dirs(c: Control, consumes: Array = []) -> Array[StringName]:
	var out: Array[StringName] = []
	if c is HSlider or c is TabBar:
		out.append_array([&"ui_left", &"ui_right"])
	elif c is VSlider:
		out.append_array([&"ui_up", &"ui_down"])
	for d in consumes:                                         # directions a control declares as consumed (options.consumes: {path: ["left", "right"]})
		var long_name := StringName("ui_" + str(d))
		if long_name in SHORT_DIRS and not out.has(long_name):
			out.append(long_name)
	return out


## Explores the focus graph from `start` with real presses (a probe teleports with grab_focus() and presses one direction).
static func _walk_page(t, root: Node, start: Control, budget: Dictionary, options: Dictionary, report: Dictionary) -> Dictionary:
	var via: String = options.get("via", "action")
	var nodes_by_path := {}
	var edges := {}
	var parent := {}
	var order: Array[String] = []
	var queue: Array[Control] = [start]
	var start_path := _rel(root, start)
	nodes_by_path[start_path] = start
	order.append(start_path)
	var qi := 0
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		await _ensure_page(t, budget, options)
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		var cp := _rel(root, c)
		if _is_other_radio_member(budget, c):
			continue                                           # reached (it is an edge of the page's tab) but not probed: moving onto it would swap the page under the walk
		c.grab_focus()
		if _owner(t) != c:
			_note(report, "%s cannot take focus (focus_mode %d)" % [cp, c.focus_mode], cp)
			continue
		edges[cp] = {}
		var skip := _skip_dirs(c, (options.get("consumes", {}) as Dictionary).get(cp, []))
		for dir in DIR_ACTIONS:
			if dir in skip:
				continue
			if int(budget["steps"]) >= int(budget["max"]):
				budget["truncated"] = true
				break
			if _owner(t) != c:
				await _ensure_page(t, budget, options)
				c.grab_focus()
			budget["steps"] = int(budget["steps"]) + 1
			_press_dir(t, dir, via)
			await t.frames(1)
			var nxt := _owner(t)
			if nxt == null:
				_defect(report, "focus_lost", cp, "%s from %s leaves no control focused" % [dir, cp], {"dir": str(dir)})
				(report["focus_loss"] as Array).append({"from": cp, "dir": SHORT_DIRS[dir], "to": ""})
				continue
			if nxt == c:
				continue
			if not _inside(root, nxt):
				_defect(report, "focus_escaped", cp, "%s from %s moves focus out of the screen to %s" % [dir, cp, nxt.get_path()], {"dir": str(dir)})
				(report["focus_loss"] as Array).append({"from": cp, "dir": SHORT_DIRS[dir], "to": str(nxt.get_path())})
				continue
			var np := _rel(root, nxt)
			edges[cp][str(dir)] = np
			if not nodes_by_path.has(np):
				nodes_by_path[np] = nxt
				parent[np] = {"from": cp, "dir": str(dir)}
				order.append(np)
				queue.append(nxt)
		if bool(budget["truncated"]):
			break
	return {"nodes": nodes_by_path, "edges": edges, "parent": parent, "order": order, "start": start_path}


## While the walk visits the page behind a radio member, a probe that moves focus onto ANOTHER member of the group selects that one (select-on-focus screens) and swaps the page: put
## the member back before the next probe.
static func _ensure_page(t, budget: Dictionary, options: Dictionary) -> void:
	var pm: Variant = budget.get("page_member", null)
	if pm != null and is_instance_valid(pm) and not (pm as BaseButton).button_pressed:
		await _select_member(t, pm as BaseButton, budget, options)


static func _is_other_radio_member(budget: Dictionary, c: Control) -> bool:
	var pm: Variant = budget.get("page_member", null)
	return pm != null and is_instance_valid(pm) and c != pm and c is BaseButton and (c as BaseButton).button_group != null and (c as BaseButton).button_group == (pm as BaseButton).button_group


static func _first_focusable(list: Array[Control]) -> Control:
	for c in list:
		if c.focus_mode == Control.FOCUS_ALL:
			return c
	return null


## Walks the screen with real ui_* presses and reports the focus graph. options:
##   wrap: "any" (default) | "required" with wrap_axes "v" (default) | "h" | "vh"    ignore: [globs]
##   via: "both" (default) | "action" | "key". "action" presses InputEventAction ui_down ... (gamepad D-pad, the abstract contract); "key" presses the arrow
##        keys the way a keyboard sends them: a LineEdit eats ui_up / ui_down / ui_left / ui_right as caret moves, so a text field the player cannot leave
##        with the arrow keys shows up only there. "both" runs the action walk, and a second key walk when the screen has a key-eating control (text field,
##        option button, list, tree); defects of the second walk carry via = "key".
##   replay: true (re-press the recorded keys from the initial focus to prove every control)    tabs: true (visit the pages of every TabBar)
##   accept: "all" | [glob patterns of buttons]: also press ui_accept on those buttons and check that they activate (runs their action: list harmless ones)
## Result: {ok, defects, notes, initial, expected, reached, order, down_chain, edges, unreachable, traps, dead_ends, steps, truncated, pages}.
static func focus_walk(t, root: Node, max_steps := 0, options: Dictionary = {}) -> Dictionary:
	if not _usable(root):
		return _no_root("focus_walk")
	var bad := _option_defects("focus_walk", options)
	options = _sane("focus_walk", options)
	if not _wants_focus(root):
		var skipped := _walk_shell()
		_note(skipped, "%s declares _wants_focus() = false: it holds no focus owner in this mode, so there is nothing to walk" % root.name)
		_merge_option_defects(skipped, bad)
		return skipped
	_vp = root.get_viewport()
	var r := await _focus_walk_modes(t, root, max_steps, options)
	_vp = null
	_merge_option_defects(r, bad)
	return r


static func _focus_walk_modes(t, root: Node, max_steps: int, options: Dictionary) -> Dictionary:
	var mode := str(options.get("via", "key" if bool(options.get("real_keys", false)) else "both"))
	if options.has("skip") and not options.has("ignore"):
		options = options.duplicate()
		options["ignore"] = options["skip"]                   # spec name for the same thing: paths / glob patterns to leave out
	var first_via := "key" if mode == "key" else "action"
	var o1 := options.duplicate()
	o1["via"] = first_via
	var focus_at_start := initial_focus(root)
	var r := await _walk_once(t, root, max_steps, o1)
	r["via"] = first_via
	r["pad_matches_keyboard"] = true
	if mode != "key" and bool(options.get("pad_check", true)) and not (r["edges"] as Dictionary).is_empty() and not bool(r["truncated"]):
		await _pad_check(t, root, r)
		if focus_at_start != null and is_instance_valid(focus_at_start):
			focus_at_start.grab_focus()                        # the second walk must start from the screen's own initial focus, not where the pad check stopped
		else:
			_viewport(t).gui_release_focus()
		await t.frames(1)
	if mode == "both":
		var eater := false
		for c in _expected(root, options.get("ignore", [])):
			if c is LineEdit or c is TextEdit or c is ItemList or c is Tree or c is OptionButton or c is MenuButton:
				eater = true
		if eater:
			var o2 := options.duplicate()
			o2["via"] = "key"
			o2["accept"] = []
			var r2 := await _walk_once(t, root, max_steps, o2)
			r["steps_keys"] = r2["steps"]
			r["initial_keys"] = r2["initial"]
			for d in r2["defects"]:
				var dup := false
				for d1 in r["defects"]:
					dup = dup or (d1["code"] == d["code"] and d1["path"] == d["path"])
				if not dup:
					var dd: Dictionary = (d as Dictionary).duplicate()
					dd["via"] = "key"
					dd["msg"] = str(dd["msg"]) + " [with the arrow keys]"
					(r["defects"] as Array).append(dd)
					r["ok"] = false
	return r


## The D-pad leads where the action / keyboard walk led: for every recorded edge, press the D-pad button (InputEventJoypadButton) and compare.
static func _pad_check(t, root: Node, r: Dictionary) -> void:
	var edges: Dictionary = r["edges"]
	var bad := 0
	for pth in edges:
		var c: Node = root if pth == "." else root.get_node_or_null(NodePath(str(pth)))
		if not (c is Control) or not is_instance_valid(c) or (c as Control).focus_mode != Control.FOCUS_ALL or not (c as Control).is_visible_in_tree():
			continue                                           # (a control of another tab page is hidden again by now)
		for d in edges[pth]:
			var long_name := StringName("ui_" + str(d))
			if not DIR_PAD.has(long_name):
				continue
			var target_node: Node = root if str(edges[pth][d]) == "." else root.get_node_or_null(NodePath(str(edges[pth][d])))
			if target_node == null or not (target_node as CanvasItem).is_visible_in_tree():
				continue
			(c as Control).grab_focus()
			await t.frames(1)
			press_pad(t, DIR_PAD[long_name])
			await t.frames(1)
			var landed := _owner(t)
			var want: String = str(edges[pth][d])
			var got := _rel(root, landed) if landed != null and _inside(root, landed) else ""
			if got != want:
				bad += 1
				_defect(r, "pad_mismatch", str(pth), "D-pad %s from %s leads to '%s', the action / keyboard press led to '%s'" % [d, pth, got, want], {"dir": str(d)})
	r["pad_matches_keyboard"] = bad == 0
	r["steps_pad"] = edges.size()


## The result dictionary of a walk with every key present and nothing found.
static func _walk_shell() -> Dictionary:
	var r := _report()
	r["expected"] = 0
	r["initial"] = ""
	r["order"] = [] as Array
	r["down_chain"] = [] as Array
	r["edges"] = {}
	r["unreachable"] = [] as Array
	r["traps"] = [] as Array
	r["dead_ends"] = [] as Array
	r["reached"] = 0
	r["pages"] = [] as Array
	r["focus_loss"] = [] as Array
	r["mismatches"] = [] as Array
	r["echo_wraps"] = [] as Array
	r["order_down"] = [] as Array
	r["order_right"] = [] as Array
	r["cycle_down"] = false
	r["cycle_right"] = false
	r["start"] = ""
	r["nodes"] = [] as Array
	r["steps"] = 0
	r["truncated"] = false
	r["pad_matches_keyboard"] = true
	return r


## Presses a walk may use when the caller asks for none (max_steps 0): 8 per control plus 60, never below 200 (a 56-slot backpack + chest screen needs ~450).
static func auto_steps(control_count: int) -> int:
	return clampi(8 * control_count + 60, 200, 4000)


static func _walk_once(t, root: Node, max_steps: int, options: Dictionary) -> Dictionary:
	var r := _walk_shell()
	var ignore: Array = options.get("ignore", [])
	var expected := _expected(root, ignore)
	if max_steps <= 0:
		max_steps = auto_steps(expected.size())
	var budget := {"steps": 0, "max": max_steps, "truncated": false}
	if expected.is_empty():
		_defect(r, "nothing_to_walk", _rel(root, root), "no visible, enabled interactive control under the screen: there is nothing to walk")
		r["steps"] = 0
		r["truncated"] = false
		return r
	var init := initial_focus(root)
	r["initial"] = _rel(root, init) if init != null else ""
	var start: Control = init if init != null else _first_focusable(expected)
	var forced: Variant = options.get("start", null)
	if forced != null and str(forced) != "":
		var fc: Node = forced if forced is Node else root.get_node_or_null(NodePath(str(forced)))
		if fc is Control and (fc as Control).focus_mode == Control.FOCUS_ALL:
			start = fc as Control
		else:
			_note(r, "options.start '%s' is not a focusable control of the screen: the walk starts elsewhere" % str(forced))
	if init == null:
		_note(r, "no initial focus: the walk starts on the first focusable control (a defect of its own, see initial_focus)")
	if start == null:
		r["expected"] = expected.size()
		_defect(r, "nothing_focusable", _rel(root, root), "%d interactive control(s), none can take keyboard focus" % expected.size())
		for c in expected:
			(r["unreachable"] as Array).append(_rel(root, c))
		r["steps"] = 0
		r["truncated"] = false
		return r
	var tab_bars: Array[TabBar] = []
	if bool(options.get("tabs", true)):
		for n in Rules.nodes(root, ignore):
			if n is TabBar and (n as TabBar).tab_count > 1:
				tab_bars.append(n as TabBar)
	var tab_state: Array = []
	for tb in tab_bars:
		tab_state.append({"bar": tb, "tab": tb.current_tab})
	var radios: Array[Dictionary] = radio_groups(root, options) if bool(options.get("pages", true)) else ([] as Array[Dictionary])   # taken BEFORE the walk: moving focus onto a tab may select it
	# page 0: the screen as it opened
	var covered := {}
	await _analyze_page(t, root, start, expected, budget, options, r, "", covered)
	# one page per other tab of every tab bar
	for st in tab_state:
		var tb: TabBar = st["bar"]
		if not is_instance_valid(tb):
			continue
		for j in tb.tab_count:
			if j == int(st["tab"]):
				continue
			var ok_keys := await _switch_tab_by_keys(t, tb, j, budget, options)
			if not ok_keys:
				_defect(r, "tab_keys_dead", _rel(root, tb), "ui_left / ui_right do not switch the tabs of %s (tab %d -> %d)" % [_rel(root, tb), int(st["tab"]), j])
				tb.current_tab = j
				await t.frames(1)
			var page_expected := _expected(root, ignore)
			var page_start: Control = tb if tb.focus_mode == Control.FOCUS_ALL else _first_focusable(page_expected)
			if page_start != null:
				await _analyze_page(t, root, page_start, page_expected, budget, options, r, "tab %d of %s" % [j, _rel(root, tb)], covered)
			# back to the tab it opened on
			tb.current_tab = int(st["tab"])
			await t.frames(1)
	# one page per member of every radio group (tabs and chips that swap the content below: PillTab / Chip in a ButtonGroup)
	for g in radios:
		var visited := 0
		for m in (g["members"] as Array):
			if visited >= int(options.get("max_pages", 12)) or not is_instance_valid(m) or m == g["selected"] or not (m as Control).is_visible_in_tree() or (m as Control).focus_mode != Control.FOCUS_ALL:
				continue
			if not await _select_member(t, m, budget, options):
				_defect(r, "radio_select_dead", _rel(root, m), "%s (a member of the radio group %s) does not become selected when it is focused and accepted: the page behind it cannot be opened" % [_rel(root, m), str(g["label"])])
				continue
			visited += 1
			budget["page_member"] = m
			budget["page_anchors"] = (g["members"] as Array).map(func(x): return _rel(root, x))
			await _analyze_page(t, root, m, _expected(root, ignore), budget, options, r, "page '%s' of %s" % [m.name, str(g["label"])], covered)
			budget.erase("page_member")
			budget.erase("page_anchors")
		await _restore_member(t, g, budget, options)
	# sliders answer the keyboard
	for c in expected:
		if c is Slider and is_instance_valid(c):
			await _slider_probe(t, root, c as Slider, budget, options, r)
	# ui_accept activates the buttons the screen lists (options.accept = "all" | [glob patterns]; pressing runs the button's own action: list harmless ones)
	var accept: Variant = options.get("accept", [])
	if (accept is String and accept == "all") or (accept is Array and not (accept as Array).is_empty()):
		for c in expected:
			if not (c is BaseButton) or not is_instance_valid(c) or int(budget["steps"]) + 2 > int(budget["max"]):
				continue
			var cp := _rel(root, c)
			var wanted := accept is String
			if accept is Array:
				for pat in accept:
					wanted = wanted or cp.match(str(pat))
			if wanted and c.focus_mode == Control.FOCUS_ALL:
				budget["steps"] = int(budget["steps"]) + 1
				if not await accept_works(t, c, str(options.get("via", "action"))):
					_defect(r, "accept_dead", cp, "ui_accept on the focused %s does not activate it" % cp)
	# restore the screen's own focus
	if init != null and is_instance_valid(init):
		init.grab_focus()
	elif init == null:
		_viewport(t).gui_release_focus()
	r["steps"] = budget["steps"]
	r["truncated"] = budget["truncated"]
	if bool(budget["truncated"]):
		_defect(r, "walk_truncated", _rel(root, root), "max_steps %d ran out before every control was explored" % max_steps)
	r["start"] = _rel(root, start)
	r["nodes"] = (r["order"] as Array).duplicate()
	# edges with the spec's short direction names {path: {up, down, left, right}}
	var short_edges := {}
	for pth in (r["edges"] as Dictionary):
		short_edges[pth] = {}
		for d in (r["edges"] as Dictionary)[pth]:
			short_edges[pth][str(d).trim_prefix("ui_")] = (r["edges"] as Dictionary)[pth][d]
	r["edges"] = short_edges
	# the declared neighbour table of the screen's owner (options.expect_edges: {path: {dir: path}})
	var declared: Dictionary = options.get("expect_edges", {})
	for pth in declared:
		for d in declared[pth]:
			var got: String = str((short_edges.get(pth, {}) as Dictionary).get(str(d), ""))
			if got != str(declared[pth][d]):
				(r["mismatches"] as Array).append({"from": pth, "dir": str(d), "expected": str(declared[pth][d]), "got": got})
				_defect(r, "edge_mismatch", str(pth), "%s %s should lead to '%s' but leads to '%s'" % [pth, d, declared[pth][d], got], {"dir": str(d)})
	return r


## Probes the graph of one page (the start state or one tab) and appends what it finds to the report.
static func _analyze_page(t, root: Node, start: Control, expected: Array[Control], budget: Dictionary, options: Dictionary, r: Dictionary, label: String, covered: Dictionary) -> void:
	var via: String = options.get("via", "action")
	var g := await _walk_page(t, root, start, budget, options, r)
	var nodes_by_path: Dictionary = g["nodes"]
	var edges: Dictionary = g["edges"]
	var parent: Dictionary = g["parent"]
	var start_path: String = g["start"]
	var tag := "" if label == "" else " (%s)" % label
	# merge the page into the report
	for p in g["order"]:
		if not (r["order"] as Array).has(p):
			(r["order"] as Array).append(p)
	(r["edges"] as Dictionary).merge(edges)
	(r["pages"] as Array).append({"label": label, "start": start_path, "reached": (g["order"] as Array).size()})
	# reachability
	var exp_paths: Array[String] = []
	for c in expected:
		var p := _rel(root, c)
		if not covered.has(p):
			exp_paths.append(p)
			covered[p] = true
	var missing: Array[String] = []
	for p in exp_paths:
		if not nodes_by_path.has(p):
			missing.append(p)
	var tab_set := {}
	if not missing.is_empty() and not bool(budget["truncated"]):
		start.grab_focus()
		await t.frames(1)
		for _i in mini(exp_paths.size() + 4, 80):
			if int(budget["steps"]) >= int(budget["max"]):
				break
			budget["steps"] = int(budget["steps"]) + 1
			press(t, &"ui_focus_next")
			await t.frames(1)
			var o := _owner(t)
			if o == null or not _inside(root, o):
				break
			var op := _rel(root, o)
			if tab_set.has(op):
				break
			tab_set[op] = true
	for p in missing:
		if tab_set.has(p):
			_defect(r, "only_via_tab", p, "%s%s is reachable with Tab only; the directional keys and the gamepad never reach it" % [p, tag])
		else:
			(r["unreachable"] as Array).append(p)
			if not bool(budget["truncated"]):
				_defect(r, "unreachable", p, "%s%s is never reached by ui_up/down/left/right from %s" % [p, tag, start_path])
	r["reached"] = int(r["reached"]) + (exp_paths.size() - missing.size())
	r["expected"] = int(r["expected"]) + exp_paths.size()
	# traps: nodes that cannot get back to the start
	var rev := {}
	for a in edges:
		for d in edges[a]:
			var b: String = edges[a][d]
			if not rev.has(b):
				rev[b] = []
			(rev[b] as Array).append(a)
	var back := {start_path: true}
	var stack: Array[String] = [start_path]
	for anchor in budget.get("page_anchors", []):                  # the page behind a radio member: focus may come back to ANY member of the group (the vertical neighbour of a chip row is the nearest chip)
		if not back.has(anchor):
			back[anchor] = true
			stack.append(anchor)
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for prev in rev.get(cur, []):
			if not back.has(prev):
				back[prev] = true
				stack.append(prev)
	if not bool(budget["truncated"]):
		for p in g["order"]:
			if not back.has(p) and p != start_path and edges.has(p):
				(r["traps"] as Array).append(p)
				_defect(r, "trap", p, "%s%s: focus enters here but no ui_* press leads back to %s" % [p, tag, start_path])
	# wrap / geometry
	var rects := {}
	for p in nodes_by_path:
		var c: Control = nodes_by_path[p]
		if is_instance_valid(c):
			rects[p] = c.get_global_rect().get_center()
	var all_rects: Array[Rect2] = []
	for c in expected:
		if is_instance_valid(c):
			all_rects.append(c.get_global_rect())
	var check_dirs: Array[StringName] = []
	if options.has("dirs"):                                    # the primary directions of the screen's groups (spec 10.3): each must lead somewhere (wrap)
		for d in options["dirs"]:
			check_dirs.append(StringName("ui_" + str(d)))
	elif str(options.get("wrap", "any")) == "required":
		var axes := str(options.get("wrap_axes", "v"))
		for d in DIR_ACTIONS:
			var vertical := d == &"ui_down" or d == &"ui_up"
			if (vertical and axes.contains("v")) or (not vertical and axes.contains("h")):
				check_dirs.append(d)
	var wrap_edges: Array[Dictionary] = []
	for p in edges:
		var c2: Control = nodes_by_path.get(p)
		if c2 == null or not is_instance_valid(c2) or not Rules.is_enabled(c2):
			continue
		var skip := _skip_dirs(c2, (options.get("consumes", {}) as Dictionary).get(p, []))
		for dir in DIR_ACTIONS:
			if dir in skip:
				continue
			var has: bool = (edges[p] as Dictionary).has(str(dir))
			if not has:
				if dir in check_dirs and not bool(budget["truncated"]):
					(r["dead_ends"] as Array).append({"path": p, "from": p, "dir": SHORT_DIRS[dir]})
					_defect(r, "dead_end", p, "%s%s has no neighbour for %s (wrap is required)" % [p, tag, dir], {"dir": str(dir)})
				continue
			var target: String = edges[p][str(dir)]
			var dv: Vector2 = rects.get(target, rects[p]) - rects[p]
			if dv.dot(DIR_VECTORS[dir]) < -1.0:
				var beyond := false
				var pr: Rect2 = c2.get_global_rect()
				var vertical_dir := dir == &"ui_down" or dir == &"ui_up"
				for q in all_rects:
					# only a control in the moving control's own column (up / down) or row (left / right) counts as "lies that way": the ragged last row of a grid has controls
					# elsewhere that are lower or further right, and a wrap-around off the end of a row or column is legitimate
					var in_band := (q.position.x < pr.end.x and q.end.x > pr.position.x) if vertical_dir else (q.position.y < pr.end.y and q.end.y > pr.position.y)
					if in_band and (q.get_center() - rects[p]).dot(DIR_VECTORS[dir]) > 1.0:
						beyond = true
						break
				if beyond:
					_defect(r, "nav_geometry", p, "%s%s: %s moves focus to %s, which lies the other way" % [p, tag, dir, target], {"dir": str(dir)})
				else:
					wrap_edges.append({"from": p, "dir": dir, "to": target})
	# a held key (echo press) must stop at the end of a ring, not cross it (spec 3.4: a fresh press wraps, an echo press does not)
	if bool(options.get("echo", false)) and not bool(budget["truncated"]):
		for we in wrap_edges:
			var cw: Control = nodes_by_path.get(we["from"])
			if cw == null or not is_instance_valid(cw):
				continue
			cw.grab_focus()
			await t.frames(1)
			_press_echo(t, we["dir"])
			await t.frames(1)
			var after_echo := _owner(t)
			if after_echo != cw:
				(r["echo_wraps"] as Array).append({"from": we["from"], "dir": SHORT_DIRS[we["dir"]], "to": _rel(root, after_echo) if after_echo != null and _inside(root, after_echo) else ""})
				_defect(r, "echo_wraps", we["from"], "%s%s: a held %s (echo press) wrapped from %s to %s" % [we["from"], tag, we["dir"], we["from"], we["to"]], {"dir": str(we["dir"])})
	# the chains a player gets by pressing ui_down / ui_right repeatedly from the start (cycle = the chain returns to the start: a wrap-around ring)
	if label == "" and not bool(budget["truncated"]):
		for dir in [&"ui_down", &"ui_right"]:
			if dir in _skip_dirs(start, (options.get("consumes", {}) as Dictionary).get(start_path, [])):
				continue                                       # the start control consumes this direction (a slider changes its value, a tab bar switches tabs)
			start.grab_focus()
			await t.frames(1)
			var chain: Array[String] = [start_path]
			var cycled := false
			for _i in mini(nodes_by_path.size() + 2, 60):
				if int(budget["steps"]) >= int(budget["max"]):
					break
				var holder := _owner(t)
				if holder != null and dir in _skip_dirs(holder, (options.get("consumes", {}) as Dictionary).get(_rel(root, holder), [])):
					break                                  # the focused control consumes this direction (a slider changes its value): the chain ends here, it is not pressed through
				budget["steps"] = int(budget["steps"]) + 1
				_press_dir(t, dir, via)
				await t.frames(1)
				var o2 := _owner(t)
				if o2 == null or not _inside(root, o2):
					break
				var o2p := _rel(root, o2)
				if chain.has(o2p):
					cycled = o2p == start_path and chain.size() > 1
					break
				chain.append(o2p)
			if dir == &"ui_down":
				r["down_chain"] = chain
				r["order_down"] = chain
				r["cycle_down"] = cycled
			else:
				r["order_right"] = chain
				r["cycle_right"] = cycled
	# replay: from the start press the recorded keys and land on the same control
	if bool(options.get("replay", true)) and not bool(budget["truncated"]):
		var replay_budget := int(budget["max"])
		var used := 0
		for p in g["order"]:
			if p == start_path or not parent.has(p):
				continue
			var path_dirs: Array[String] = []
			var cur2: String = p
			while parent.has(cur2):
				path_dirs.push_front(parent[cur2]["dir"])
				cur2 = parent[cur2]["from"]
			if used + path_dirs.size() > replay_budget:
				_note(r, "replay stopped at %d presses (budget); %s and later were not replayed" % [used, p])
				break
			start.grab_focus()
			await t.frames(1)
			for d in path_dirs:
				_press_dir(t, StringName(d), via)
				await t.frames(1)
			used += path_dirs.size()
			var landed := _owner(t)
			if landed != nodes_by_path[p]:
				_defect(r, "walk_replay_mismatch", p, "pressing %s from %s lands on %s, the probe landed on %s" % [", ".join(path_dirs), start_path, _rel(root, landed) if landed != null and _inside(root, landed) else "something else", p])


static func _switch_tab_by_keys(t, tb: TabBar, target: int, budget: Dictionary, options: Dictionary) -> bool:
	var via: String = options.get("via", "action")
	if tb.focus_mode != Control.FOCUS_ALL:
		return false                                          # a tab bar the keyboard cannot focus cannot switch tabs either
	tb.grab_focus()
	await t.frames(1)
	var guard := 0
	while tb.current_tab != target and guard < tb.tab_count + 1:
		if int(budget["steps"]) >= int(budget["max"]):
			return false
		var before := tb.current_tab
		budget["steps"] = int(budget["steps"]) + 1
		_press_dir(t, &"ui_right" if target > before else &"ui_left", via)
		await t.frames(1)
		if tb.current_tab == before:
			return false
		guard += 1
	return tb.current_tab == target


static func _slider_probe(t, root: Node, s: Slider, budget: Dictionary, options: Dictionary, r: Dictionary) -> void:
	var via: String = options.get("via", "action")
	if not s.is_visible_in_tree() or s.focus_mode != Control.FOCUS_ALL or s.max_value <= s.min_value:        # (the caller walks enabled sliders only: a read-only one is not in `expected`)
		return
	if int(budget["steps"]) + 4 > int(budget["max"]):
		return
	var fwd := &"ui_right" if s is HSlider else &"ui_up"
	var back := &"ui_left" if s is HSlider else &"ui_down"
	var v0 := s.value
	s.grab_focus()
	await t.frames(1)
	budget["steps"] = int(budget["steps"]) + 1
	_press_dir(t, fwd, via)
	await t.frames(1)
	var moved_dir := fwd
	if s.value == v0:
		budget["steps"] = int(budget["steps"]) + 1
		_press_dir(t, back, via)
		await t.frames(1)
		moved_dir = back
	if s.value == v0:
		_defect(r, "slider_ignores_keys", _rel(root, s), "%s did not change with ui_left / ui_right (value %s)" % [_rel(root, s), str(v0)])
		return
	# put the value back with the opposite key (the audit must not leave a setting changed)
	budget["steps"] = int(budget["steps"]) + 1
	_press_dir(t, back if moved_dir == fwd else fwd, via)
	await t.frames(1)
	if s.value != v0:
		s.set_value_no_signal(v0)


# ---------------------------------------------------------------------------------------------------- radio groups (tabs and chips that swap a page)

## The radio groups of a screen: toggle buttons that share a ButtonGroup (PillTab tabs, Chip chips, race cards ...) and swap the content below them. Returns
## [{label, members: [BaseButton], selected: BaseButton}] for every group of two or more enabled members. options.tab_groups adds sets a ButtonGroup does not describe
## ([[node path, ...], ...] relative to root), options.ignore skips controls. The walk, rule_report_pages and focusable_report_pages visit the page behind every member.
static func radio_groups(root: Node, options: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_group := {}
	var order: Array = []
	for n in Rules.nodes(root, options.get("ignore", [])):
		if n is BaseButton and (n as BaseButton).toggle_mode and (n as BaseButton).button_group != null and Rules.is_enabled(n as Control):
			var g: ButtonGroup = (n as BaseButton).button_group
			if not by_group.has(g):
				by_group[g] = []
				order.append(g)
			(by_group[g] as Array).append(n)
	for g in order:
		var members: Array = by_group[g]
		if members.size() >= 2:
			var pressed: BaseButton = (g as ButtonGroup).get_pressed_button()
			out.append({"label": "group %s" % ", ".join(members.map(func(m): return str(m.name))), "members": members, "selected": pressed})
	for paths in options.get("tab_groups", []):
		var members2: Array = []
		var pressed2: BaseButton = null
		for pth in paths:
			var m: Node = root.get_node_or_null(NodePath(str(pth)))
			if m is BaseButton and Rules.is_enabled(m as Control):
				members2.append(m)
				if (m as BaseButton).button_pressed and pressed2 == null:
					pressed2 = m as BaseButton
		if members2.size() >= 2:
			out.append({"label": "group %s" % ", ".join(members2.map(func(m): return str(m.name))), "members": members2, "selected": pressed2})
	return out


## Selects a radio member the way a player does: focus it and press accept (a screen that selects on focus is selected already). True when it is pressed afterwards.
static func _select_member(t, m: BaseButton, budget: Dictionary, options: Dictionary) -> bool:
	m.grab_focus()
	await t.frames(1)
	if not m.button_pressed:
		budget["steps"] = int(budget["steps"]) + 1
		_press_dir(t, &"ui_accept", str(options.get("via", "action")))
		await t.frames(2)
	await t.frames(1)
	return m.button_pressed


## Puts a radio group back to the member it had before the audit (a screen must not be left on another tab).
static func _restore_member(t, g: Dictionary, budget: Dictionary, options: Dictionary) -> void:
	var want: BaseButton = g["selected"]
	if want == null or not is_instance_valid(want) or want.button_pressed:
		return
	if not await _select_member(t, want, budget, options):
		want.button_pressed = true
		await t.frames(1)


## Runs `check` (a Callable that returns a report) on the screen as it is and on the page behind every other member of every radio group, then restores the selections.
## Returns [{label, report}] (label "" = the screen as it opened). options: pages (false = only the open page), max_pages (per group, default 12), tab_groups, ignore, via.
static func each_page(t, root: Node, check: Callable, options: Dictionary = {}) -> Array[Dictionary]:
	var pages: Array[Dictionary] = [{"label": "", "report": check.call()}]
	if not bool(options.get("pages", true)) or not _usable(root):
		return pages
	var prev_vp := _vp
	_vp = root.get_viewport()
	var budget := {"steps": 0, "max": 100000, "truncated": false}
	for g in radio_groups(root, options):
		var visited := 0
		for m in (g["members"] as Array):
			if visited >= int(options.get("max_pages", 12)) or not is_instance_valid(m) or m == g["selected"] or not (m as Control).is_visible_in_tree() or (m as Control).focus_mode != Control.FOCUS_ALL:
				continue
			if await _select_member(t, m, budget, options):
				visited += 1
				pages.append({"label": "page '%s' of %s" % [m.name, str(g["label"])], "report": check.call()})
			else:
				var dead := _report()
				_defect(dead, "radio_select_dead", _rel(root, m), "%s (a member of the radio group %s) does not become selected when it is focused and accepted: the page behind it cannot be opened" % [_rel(root, m), str(g["label"])])
				pages.append({"label": "page '%s' of %s" % [m.name, str(g["label"])], "report": dead})
		await _restore_member(t, g, budget, options)
	_vp = prev_vp
	return pages


## rule_report on every page behind a radio group (spec: the content of N-1 of N tabs would otherwise never be scanned). The defects of the other pages carry `page`.
static func rule_report_pages(t, root: Node, options: Dictionary = {}) -> Dictionary:
	if root == null or not is_instance_valid(root):
		return _no_root("rule_report_pages")
	var opts := options.duplicate()
	var pages := await each_page(t, root, func() -> Dictionary: return rule_report(root, opts), opts)
	return _union_pages(pages)


## focusable_report on every page behind a radio group (the buttons of the other tabs must be keyboard stops too).
static func focusable_report_pages(t, root: Node, options: Dictionary = {}) -> Dictionary:
	if not _usable(root):
		return _no_root("focusable_report_pages")
	var opts := options.duplicate()
	var pages := await each_page(t, root, func() -> Dictionary: return focusable_report(root, opts), opts)
	return _union_pages(pages)


static func _union_pages(pages: Array[Dictionary]) -> Dictionary:
	var union: Dictionary = {}
	var labels: Array[String] = []
	for p in pages:
		labels.append(str(p["label"]))
		_merge_page_report(union, p["report"], str(p["label"]))
	union["pages"] = labels
	union["ok"] = (union["defects"] as Array).is_empty()
	return union


## Adds `rep` to `union` (the first report becomes the union): a defect already there (same code, path and message) is not repeated; a new one carries `page`.
static func _merge_page_report(union: Dictionary, rep: Dictionary, label: String) -> void:
	if union.is_empty():
		for k in rep:
			union[k] = rep[k]
		return
	for d in rep.get("defects", []):
		var dup := false
		for d0 in union["defects"]:
			dup = dup or (d0["code"] == d["code"] and d0["path"] == d["path"] and d0.get("detail", d0.get("msg", "")) == d.get("detail", d.get("msg", "")))
		if not dup:
			var dd: Dictionary = (d as Dictionary).duplicate()
			dd["page"] = label
			(union["defects"] as Array).append(dd)
			var grp: String = RULE_GROUPS.get(dd["code"], "")
			if grp != "" and union.has(grp):
				(union[grp] as Array).append({"path": dd["path"], "variation": dd.get("variation", ""), "detail": dd.get("detail", dd.get("msg", "")), "code": dd["code"], "page": label})
	for nt in rep.get("notes", []):
		(union["notes"] as Array).append(nt)
	if rep.has("interactive") and union.has("interactive"):
		union["interactive"] = maxi(int(union["interactive"]), int(rep["interactive"]))
	for k in ["focusable", "windows", "interactive_without_focus", "disabled_focusable"]:
		if union.has(k) and rep.has(k):
			for v in rep[k]:
				if not (union[k] as Array).has(v):
					(union[k] as Array).append(v)


# ---------------------------------------------------------------------------------------------------- text fields

## Typing in a text field must not fire the game's hotkeys. For every LineEdit / TextEdit of the screen the audit types the printable keys that
## are bound to game actions (I, J, E, B, H, G, F, Q, R, W, A, S, D, 1..0) and checks: the key is typed into the field, it is not left over for
## _unhandled_input, and no modal opened.
static func text_field_audit(t, root: Node, options: Dictionary = {}) -> Dictionary:
	if not _usable(root):
		return _no_root("text_field_audit")
	var bad := _option_defects("text_field_audit", options)
	options = _sane("text_field_audit", options)
	var r := _report()
	var fields: Array[Control] = []
	for n in Rules.nodes(root, options.get("ignore", [])):
		if (n is LineEdit and (n as LineEdit).editable and n.get_parent() is not SpinBox) or (n is TextEdit and (n as TextEdit).editable):
			fields.append(n as Control)
	r["fields"] = fields.size()
	r["keys_tested"] = 0
	if fields.is_empty():
		return r
	_vp = root.get_viewport()
	var gm: Node = t.root.get_node_or_null("GameManager")
	var prior_focus := _owner(t)
	var probe := _LeakProbe.new()
	root.get_viewport().add_child(probe)
	var keys := _hotkey_chars()
	for f in fields:
		if not f.is_visible_in_tree() or f.focus_mode != Control.FOCUS_ALL:
			continue
		var saved_text: String = f.text
		f.grab_focus()
		await t.frames(1)
		var stack_before: Array = gm.call("modal_stack") if gm != null else []
		var leaked: Array[String] = []
		var untyped: Array[String] = []
		for ch in keys:
			probe.seen.clear()
			f.text = ""
			var before_len: int = 0
			var keycode := OS.find_keycode_from_string(ch.to_upper())
			var ev := InputEventKey.new()
			ev.keycode = keycode if keycode != KEY_NONE else (ch.unicode_at(0) as Key)
			ev.physical_keycode = ev.keycode
			ev.unicode = ch.unicode_at(0)
			ev.pressed = true
			_viewport(t).push_input(ev)
			var up := InputEventKey.new()
			up.keycode = ev.keycode
			up.physical_keycode = ev.keycode
			up.pressed = false
			_viewport(t).push_input(up)
			r["keys_tested"] = int(r["keys_tested"]) + 1
			await t.frames(1)
			if not probe.seen.is_empty():
				leaked.append(ch)
			if f.text.length() <= before_len:
				untyped.append(ch)
		# keys the world binds that are NOT letters or digits (Space = jump / dodge, Tab = inventory, Shift = run, Ctrl, Backspace ...): a handler in _input sees them before the field
		# does, so typing a space in a name, or pressing Tab in the field, must not open a modal. (Enter submits the field and its screen may act on it - the select page presses
		# Start - so Enter is only pressed with options.press_enter.)
		for sk in _hotkey_specials(bool(options.get("press_enter", false))):
			var st0: Array = gm.call("modal_stack") if gm != null else []
			var sev := InputEventKey.new()
			sev.keycode = sk
			sev.physical_keycode = sk
			sev.unicode = 32 if sk == KEY_SPACE else 0
			sev.pressed = true
			_viewport(t).push_input(sev)
			var sup := InputEventKey.new()
			sup.keycode = sk
			sup.physical_keycode = sk
			sup.pressed = false
			_viewport(t).push_input(sup)
			r["keys_tested"] = int(r["keys_tested"]) + 1
			await t.frames(1)
			var st1: Array = gm.call("modal_stack") if gm != null else []
			if st0 != st1:
				leaked.append(OS.get_keycode_string(sk))
				for m2 in st1:
					if not st0.has(m2):
						gm.call("pop_modal", m2)
			f.grab_focus()
			await t.frames(1)
		var stack_after: Array = gm.call("modal_stack") if gm != null else []
		if not leaked.is_empty() or stack_before != stack_after:
			if gm != null and stack_before != stack_after:
				for m in stack_after:
					if not stack_before.has(m):
						gm.call("pop_modal", m)
			_defect(r, "typing_leaks_hotkey", _rel(root, f), "typing %s into %s also reaches the game (unhandled key events %s%s)" % [str(keys), _rel(root, f), str(leaked), ", a modal opened" if stack_before != stack_after else ""])
		elif not untyped.is_empty():
			_defect(r, "text_field_dead", _rel(root, f), "%s did not take the keys %s as text" % [_rel(root, f), str(untyped)])
		f.text = saved_text
	probe.queue_free()
	if prior_focus != null and is_instance_valid(prior_focus):
		prior_focus.grab_focus()
	else:
		_viewport(t).gui_release_focus()
	_vp = null
	await t.frames(1)
	if not bool(options.get("press_enter", false)):
		_note(r, "Enter was not pressed: it submits the field and its screen may act on it (options.press_enter = true for a screen whose submit is harmless)")
	_merge_option_defects(r, bad)
	return r


## Non-alphanumeric keys that a world action is bound to (Space, Tab, Shift, Ctrl, Alt, Backspace, Delete; Enter, KP Enter on request): what a player presses while typing a name.
static func _hotkey_specials(with_enter := false) -> Array[int]:
	var out: Array[int] = []
	var wanted: Array[int] = [KEY_SPACE, KEY_TAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_BACKSPACE, KEY_DELETE]
	if with_enter:
		wanted.append_array([KEY_ENTER, KEY_KP_ENTER])
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_") or action == &"pause":
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				var code: int = k.keycode if k.keycode != KEY_NONE else k.physical_keycode
				if code in wanted and not out.has(code):
					out.append(code)
	return out


static func _hotkey_chars() -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				var code: int = k.keycode if k.keycode != KEY_NONE else k.physical_keycode
				if code >= KEY_A and code <= KEY_Z or code >= KEY_0 and code <= KEY_9:
					var ch := String.chr(code).to_lower()
					if not seen.has(ch):
						seen[ch] = true
						out.append(ch)
	out.sort()
	return out


## Counts printable key events that nobody handled (the text field did not take them).
class _LeakProbe extends Node:
	var seen: Array[String] = []

	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).unicode >= 32:
			seen.append(String.chr((event as InputEventKey).unicode))


# ---------------------------------------------------------------------------------------------------- escape chain

## Opens `expected_depth` modals through `opener` and closes them with Esc (or a pad button), checking the whole contract of a modal stack. `opener` is a Callable
## (a coroutine is fine): with ONE argument it is called once per level with the level number 0..depth-1 and every call must add exactly ONE entry to GameManager's
## modal stack; with NO argument it is called once and must leave `expected_depth` new entries (it opens the way the player does: press Esc on the free world, press
## the Settings row ...). Then the audit presses Esc `expected_depth` times and checks after each press: exactly the TOP modal closed, the world saw nothing
## (options.world_probe), focus is back on the control that owned it before that modal opened (or options.expect_focus / release_world_focus), and at depth 0
## the tree is unpaused, the stack is empty and GameManager.current_phase is what it was.
## options: key / via ("key" default = the Esc key: ui_cancel AND pause; "action" = ui_cancel alone; "pause"; "pad_b" = joypad B; "start" = joypad Start), settle (frames
## after each press, default 3), settle_seconds (after the frames, keep waiting up to this many SECONDS for the stack - or the internal depth - to change, default 0.25: a modal
## that fades out before it pops needs real time, not a frame count; 0 = frames only), world_probe (Callable returning an int counter of world reactions: pause re-opened, interact fired, tool used; it must not grow),
## expect_focus (node path that owns focus after the last press), release_world_focus (true: after the last press NO control owns focus, the world gets the keys back),
## pre_opened + base_stack / base_phase / base_paused (the layers are ALREADY open - a registry row's screen opens itself: the opener is not called and `base_stack` is the modal stack from before the
## screen opened; the registry gives a spec row `esc_depth: N` this mode when it has no driver).
## expected_depth 0 with pre_opened is the "Esc does nothing" chain (the title, the sleep fade): the key is pressed ONCE and the modal stack and the phase must not move.
## Result: {ok, defects, notes, opened, closed, depth_open, stack_open, steps: [{press, depth_after, stack, focus_owner, world_actions_fired}], opener_focus,
## restored_focus, errors}.
static func escape_chain(t, opener: Callable, expected_depth: int, options: Dictionary = {}) -> Dictionary:
	var bad := _option_defects("escape_chain", options)
	var res := await _escape_chain(t, opener, expected_depth, _sane("escape_chain", options))
	_merge_option_defects(res, bad)
	return res


const DEFAULT_SETTLE_SECONDS := 0.25


## After a press: `settle` frames, then (up to `seconds`) until the modal stack - or the screen's internal depth - differs from what it was before the press.
static func _settle_press(t, gm: Node, before: Array, settle: int, seconds: float, internal_depth: Callable, internal_before: int) -> void:
	await t.frames(settle)
	if seconds <= 0.0:
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		var changed: bool = (gm.call("modal_stack") as Array) != before
		if not changed and internal_depth.is_valid() and internal_before >= 0:
			changed = int(internal_depth.call()) != internal_before
		if changed:
			return
		await t.frames(1)


static func _escape_chain(t, opener: Callable, expected_depth: int, options: Dictionary) -> Dictionary:
	var r := _report()
	r["opened"] = [] as Array
	r["closed"] = [] as Array
	r["steps"] = [] as Array
	r["errors"] = [] as Array
	r["depth_open"] = 0
	r["stack_open"] = [] as Array
	r["opener_focus"] = ""
	r["restored_focus"] = ""
	var gm: Node = t.root.get_node_or_null("GameManager")
	if gm == null:
		_defect(r, "no_game_manager", "", "the GameManager autoload is missing: the modal stack cannot be read")
		return r
	var pre_opened := bool(options.get("pre_opened", false))      # the screen opened itself before the chain started (a registry row: the audit opened it)
	if not pre_opened and not opener.is_valid():
		_defect(r, "opener_depth_mismatch", "", "the opener is not a valid Callable (its object was freed?)")
		return r
	var internal := clampi(int(options.get("internal_layers", 0)), 0, maxi(expected_depth, 0))   # layers INSIDE a screen (a page, a drawer): Esc closes them but the modal stack does not move
	var internal_depth: Callable = options.get("internal_depth", Callable())                    # returns the screen's current internal layer count (each internal press must lower it by one)
	var stack_depth := expected_depth - internal
	var via: String = str(options.get("key", options.get("via", "key")))
	var settle: int = int(options.get("settle", 3))
	var settle_seconds: float = float(options.get("settle_seconds", DEFAULT_SETTLE_SECONDS))
	var world_probe: Callable = options.get("world_probe", Callable())
	var base: Array = options.get("base_stack", gm.call("modal_stack")) if pre_opened else gm.call("modal_stack")
	var phase0: Variant = options.get("base_phase", gm.get("current_phase")) if pre_opened else gm.get("current_phase")
	var paused0: bool = bool(options.get("base_paused", t.tree.paused)) if pre_opened else t.tree.paused
	var focus_before: Array = []
	if not pre_opened and opener.get_argument_count() >= 1:
		for level in expected_depth:
			focus_before.append(_owner(t))
			await opener.call(level)
			await t.frames(settle)
			var stack: Array = gm.call("modal_stack")
			var want_size := base.size() + mini(level + 1, stack_depth)         # the internal levels (the last `internal`) do not touch the stack
			if stack.size() != want_size:
				_defect(r, "opener_depth_mismatch", "level %d" % level, "opening level %d left %d modal(s) on the stack, expected %d (%s)" % [level, stack.size(), want_size, str(stack)])
				_cleanup_modals(gm, base, phase0)
				return r
			if level >= stack_depth:
				continue
			(r["opened"] as Array).append(str(stack[-1]))
			var got_focus := _owner(t)
			if got_focus == null or got_focus == focus_before[level]:
				_defect(r, "modal_no_focus", str(stack[-1]), "after opening '%s', focus is %s: the modal must take focus (first enabled control) so the keyboard acts on it" % [str(stack[-1]), "on nothing" if got_focus == null else "still on " + str(got_focus.name)])
	else:
		focus_before.append(null if pre_opened else _owner(t))
		if not pre_opened:
			await opener.call()
		await t.frames(settle)
		var stack1: Array = gm.call("modal_stack")
		if stack1.size() != base.size() + stack_depth:
			_defect(r, "opener_depth_mismatch", "opener", "the opener left %d modal(s) on the stack, expected %d (%s)" % [stack1.size() - base.size(), stack_depth, str(stack1)])
			_cleanup_modals(gm, base, phase0)
			return r
		for i in stack_depth:
			(r["opened"] as Array).append(str(stack1[base.size() + i]))
		var got_focus1 := _owner(t)
		if stack_depth > 0 and (got_focus1 == null or got_focus1 == focus_before[0]):          # an internal-only layer has no modal on the stack: its focus is the screen's own business
			_defect(r, "modal_no_focus", str(stack1[-1]), "after the opener ran, focus is %s: the top modal must take focus" % ("on nothing" if got_focus1 == null else "still on " + str(got_focus1.name)))
	r["depth_open"] = (r["opened"] as Array).size() + internal
	r["internal_layers"] = internal
	r["stack_open"] = (gm.call("modal_stack") as Array).duplicate()
	r["opener_focus"] = str((focus_before[0] as Node).get_path()) if not focus_before.is_empty() and is_instance_valid(focus_before[0]) else ""
	if expected_depth == 0 and pre_opened:
		# "Esc does nothing" (the title, the sleep fade: esc_depth 0): press it once and prove that nothing happened
		var stack_zero: Array = gm.call("modal_stack")
		var phase_zero: Variant = gm.get("current_phase")
		var paused_zero: bool = t.tree.paused
		press_cancel(t, via)
		await _settle_press(t, gm, stack_zero, settle, settle_seconds, Callable(), -1)
		var stack_zero_after: Array = gm.call("modal_stack")
		(r["steps"] as Array).append({"press": via, "depth_after": maxi(stack_zero_after.size() - base.size(), 0), "stack": stack_zero_after.duplicate(), "focus_owner": "", "world_actions_fired": 0})
		if stack_zero_after != stack_zero or gm.get("current_phase") != phase_zero or t.tree.paused != paused_zero:
			_defect(r, "esc_opens_modal", "", "Esc (%s) on a screen that must ignore it changed the game (modal stack %s -> %s, phase %s -> %s, paused %s -> %s)" % [via, str(stack_zero), str(stack_zero_after), _phase_name(gm, phase_zero), _phase_name(gm, gm.get("current_phase")), str(paused_zero), str(t.tree.paused)])
	for k in expected_depth:
		var level2: int = expected_depth - 1 - k
		var before: Array = gm.call("modal_stack")
		var probe_before := int(world_probe.call()) if world_probe.is_valid() else 0
		var internal_before := int(internal_depth.call()) if internal_depth.is_valid() else -1
		press_cancel(t, via)
		await _settle_press(t, gm, before, settle, settle_seconds, internal_depth, internal_before)
		var after: Array = gm.call("modal_stack")
		if k < internal:
			# an internal layer (the top of the screen): the press closes it, the modal stack must not move, the world must not see the press
			var internal_after := int(internal_depth.call()) if internal_depth.is_valid() else -1
			var owner_i := _owner(t)
			(r["steps"] as Array).append({"press": via, "internal": true, "depth_after": maxi(after.size() - base.size(), 0), "stack": after.duplicate(), "focus_owner": str(owner_i.get_path()) if owner_i != null else "", "world_actions_fired": (int(world_probe.call()) - probe_before) if world_probe.is_valid() else 0, "internal_depth_after": internal_after})
			if world_probe.is_valid() and int(world_probe.call()) - probe_before > 0:
				_defect(r, "world_saw_press", "internal layer %d" % k, "the world reacted to the press that was meant for an internal layer of the screen: consume the event (set_input_as_handled)")
			if after != before:
				_defect(r, "esc_wrong_order", str(before[-1]) if not before.is_empty() else "", "Esc changed the modal stack (%s -> %s) while %d internal layer(s) of the screen were still open: the internal layer must close first" % [str(before), str(after), internal - k])
				break
			if internal_depth.is_valid() and internal_after >= internal_before:
				_defect(r, "esc_does_not_close", "internal layer %d" % k, "Esc (%s) did not close the screen's internal layer (internal depth %d -> %d)" % [via, internal_before, internal_after])
				break
			if internal_depth.is_valid() and internal_before - internal_after >= 2:
				_defect(r, "esc_closes_several", "internal layer %d" % k, "one Esc closed %d internal layers (internal depth %d -> %d)" % [internal_before - internal_after, internal_before, internal_after])
				break
			(r["closed"] as Array).append("internal")
			continue
		var top_name := str(before[-1]) if not before.is_empty() else ""
		var probe_delta := (int(world_probe.call()) - probe_before) if world_probe.is_valid() else 0
		var owner_now := _owner(t)
		(r["steps"] as Array).append({"press": via, "depth_after": maxi(after.size() - base.size(), 0), "stack": after.duplicate(), "focus_owner": str(owner_now.get_path()) if owner_now != null else "", "world_actions_fired": probe_delta})
		var opened_new: Array = []
		var removed: Array = []
		for m in after:
			if not before.has(m):
				opened_new.append(m)
		for m in before:
			if not after.has(m):
				removed.append(m)
		if probe_delta > 0:
			_defect(r, "world_saw_press", top_name, "the world reacted %d time(s) to the press that was meant for '%s': the top layer must consume the event (set_input_as_handled)" % [probe_delta, top_name])
		if after == before:
			_defect(r, "esc_does_not_close", top_name, "Esc (%s) did not close the top modal '%s' (stack %s)" % [via, top_name, str(before)])
			break
		if not opened_new.is_empty() and removed.is_empty():
			_defect(r, "esc_opens_modal", top_name, "Esc opened %s on top of '%s' instead of closing it" % [str(opened_new), top_name])
			break
		if not opened_new.is_empty():
			_defect(r, "modal_stack_leak", top_name, "closing '%s' left %s on the stack (%s -> %s)" % [str(removed), str(opened_new), str(before), str(after)])
			break
		if removed.size() >= 2:
			_defect(r, "esc_closes_several", top_name, "one Esc closed %d modals: %s -> %s" % [removed.size(), str(before), str(after)])
			break
		if str(removed[0]) != top_name:
			_defect(r, "esc_wrong_order", str(removed[0]), "Esc closed '%s' but the top modal is '%s' (stack %s -> %s)" % [str(removed[0]), top_name, str(before), str(after)])
			break
		(r["closed"] as Array).append(top_name)
		var want_v: Variant = focus_before[level2] if focus_before.size() > level2 else null      # a per-level opener has one entry per level; a single opener has ONE entry, so only the last press hands focus back to whoever opened the first layer
		var want: Control = (want_v as Control) if is_instance_valid(want_v) else null      # the screen may have rebuilt the opener while the layer closed (a refreshed list): a freed node cannot be the typed variable
		if typeof(want_v) == TYPE_OBJECT and want == null:
			_note(r, "the control that opened '%s' no longer exists after it closed: focus restoration was not checked (use options.expect_focus)" % top_name)
		if want != null and is_instance_valid(want) and want.is_visible_in_tree() and not want.is_queued_for_deletion():
			if owner_now != want:
				_defect(r, "focus_not_restored", top_name, "after '%s' closed, focus is on %s, not on %s that opened it" % [top_name, str(owner_now.get_path()) if owner_now != null else "nothing", str(want.get_path())])
	r["restored_focus"] = str(_owner(t).get_path()) if _owner(t) != null else ""
	var expect_focus := str(options.get("expect_focus", ""))
	if expect_focus != "" and (r["defects"] as Array).is_empty():
		var want_node: Node = t.root.get_node_or_null(NodePath(expect_focus))
		if want_node == null or _owner(t) != want_node:
			_defect(r, "focus_not_restored", expect_focus, "after the last layer closed, focus should be on %s but is on %s" % [expect_focus, r["restored_focus"] if r["restored_focus"] != "" else "nothing"])
	if bool(options.get("release_world_focus", false)) and _owner(t) != null and (r["defects"] as Array).is_empty():
		_defect(r, "focus_not_restored", "", "after the last layer closed a control still owns focus (%s): the world must get the keys back (release the focus)" % r["restored_focus"])
	var final_stack: Array = gm.call("modal_stack")
	if final_stack.size() > base.size() and (r["defects"] as Array).is_empty():
		_defect(r, "modal_stack_leak", "", "modals left on the stack after the chain: %s" % str(final_stack))
	if final_stack.size() <= base.size() and base.is_empty() and t.tree.paused and not paused0:
		_defect(r, "game_stays_paused", "", "the tree is still paused after the last modal closed")
	if gm.get("current_phase") != phase0 and (r["defects"] as Array).is_empty():              # (a leaked modal above the base already is a defect, so "the stack is back" needs no test of its own)
		_defect(r, "phase_not_restored", "", "GameManager.current_phase is %s, it was %s before the chain" % [_phase_name(gm, gm.get("current_phase")), _phase_name(gm, phase0)])
	for dd in r["defects"]:
		(r["errors"] as Array).append("%s: %s" % [dd["code"], dd["msg"]])
	_cleanup_modals(gm, base, phase0)
	return r


static func _phase_name(gm: Node, value: Variant) -> String:
	var script: Script = gm.get_script()
	if script != null:
		var e: Variant = script.get_script_constant_map().get("GamePhase", null)
		if e is Dictionary:
			for k in (e as Dictionary):
				if (e as Dictionary)[k] == value:
					return str(k)
	return str(value)


## Leaves the game as the chain found it (a failed chain must not poison the sections after it).
static func _cleanup_modals(gm: Node, base: Array, phase0: Variant = null) -> void:
	var now: Array = gm.call("modal_stack")
	for m in now:
		if not base.has(m):
			gm.call("pop_modal", m)
	if base.is_empty():
		var tree := gm.get_tree()
		if tree != null:
			tree.paused = false
		if phase0 != null and gm.get("current_phase") != phase0:
			gm.call("change_phase", phase0)                          # a modal that changed the phase must not poison the sections after it


# ---------------------------------------------------------------------------------------------------- rules

## R1-R4, typography, overrides, copy and hit targets in one scan (static: reads the live node tree, presses nothing).
## options: rules (subset of ["r1","r2","r3","r4","typography","overrides","i18n","hit_targets"]), ignore, strict_typography, strict_gold (default true), hit_min,
## literal_files. Result (spec 10.6): {ok, defects, notes, counts: {controls, labels, styleboxes, ...}, r1_ink, r2_gold, r3_numbers, r4_red, typography, overrides,
## raw_keys, hard_coded, hit_targets} where every group is an Array of {path, variation, detail, code}; `defects` holds the same entries (with rule, msg).
const RULE_GROUPS := {"r1_no_ink_outline": "r1_ink", "r2_gold_decoration": "r2_gold", "r3_number_not_display": "r3_numbers", "r4_red": "r4_red", "font_below_floor": "typography",
	"font_too_small_display": "typography", "font_too_small_body": "typography", "theme_override": "overrides", "raw_key": "raw_keys", "hardcoded_literal": "hard_coded",
	"hit_target_small": "hit_targets"}


static func rule_report(root: Node, options: Dictionary = {}) -> Dictionary:
	if root == null or not is_instance_valid(root):
		return _no_root("rule_report")
	var sweep: Array = options.get("locale_sweep", [])
	if not sweep.is_empty():
		return _rule_report_swept(root, options, sweep)
	var bad_rule_options := _option_defects("rule_report", options)
	var scan := Rules.scan(root, _sane("rule_report", options))
	var r := _report()
	for d in scan["defects"]:
		(r["defects"] as Array).append(d)
	for d in bad_rule_options:
		(r["defects"] as Array).append(d)
	r["ok"] = (r["defects"] as Array).is_empty()
	r["notes"] = scan["notes"]
	r["counts"] = scan["counts"]
	for k in RULE_GROUPS.values():
		if not r.has(k):
			r[k] = [] as Array
	for d in r["defects"]:
		(r[RULE_GROUPS.get(d["code"], "typography")] as Array).append({"path": d["path"], "variation": d.get("variation", ""), "detail": d.get("detail", d["msg"]), "code": d["code"]})
	return r


## options.locale_sweep (spec 10.6), synchronous: the scan once per listed language - the language is switched (Godot tells every node at once with
## NOTIFICATION_TRANSLATION_CHANGED, no frames are awaited), the defects are unioned and tagged with `locale`, then the caller's language is restored. For a screen that re-labels
## in a deferred call use `await rule_report_locales(t, root)`, which waits two frames per language.
static func _rule_report_swept(root: Node, options: Dictionary, sweep: Array) -> Dictionary:
	var prev := TranslationServer.get_locale()
	var opts := options.duplicate()
	opts.erase("locale_sweep")
	var union: Dictionary = {}
	for loc in sweep:
		TranslationServer.set_locale(str(loc))                 # (TranslationServer.set_locale tells every node at once: NOTIFICATION_TRANSLATION_CHANGED is synchronous)
		var rep := rule_report(root, opts)
		_merge_locale_report(union, rep, str(loc))
	TranslationServer.set_locale(prev if prev != "" else "da")
	union["ok"] = (union["defects"] as Array).is_empty()
	return union


## Adds `rep` to `union` (the first report becomes the union): a defect already there (same code, path and detail) is not repeated; new ones carry `locale`.
static func _merge_locale_report(union: Dictionary, rep: Dictionary, loc: String) -> void:
	if union.is_empty():
		for k in rep:
			union[k] = rep[k]
		for d in union["defects"]:
			d["locale"] = loc
		return
	for d in rep["defects"]:
		var dup := false
		for d0 in union["defects"]:
			dup = dup or (d0["code"] == d["code"] and d0["path"] == d["path"] and d0["detail"] == d["detail"])
		if not dup:
			d["locale"] = loc
			(union["defects"] as Array).append(d)
			(union[RULE_GROUPS.get(d["code"], "typography")] as Array).append({"path": d["path"], "variation": d.get("variation", ""), "detail": d.get("detail", d["msg"]), "code": d["code"], "locale": loc})


## The same scan once per locale (spec 10.6 `locale_sweep`): switches the language, waits two frames, runs rule_report and unions the defects (raw keys and
## untranslated text differ per language), then restores the locale. Defects carry `locale`.
static func rule_report_locales(t, root: Node, locales: Array = ["da", "en"], options: Dictionary = {}) -> Dictionary:
	if not _usable(root):
		return _no_root("rule_report_locales")
	var prev := TranslationServer.get_locale()
	var union: Dictionary = {}
	var opts := options.duplicate()
	opts.erase("locale_sweep")
	for loc in locales:
		TranslationServer.set_locale(str(loc))
		await t.frames(SETTLE_FRAMES)
		_merge_locale_report(union, rule_report(root, opts), str(loc))
	TranslationServer.set_locale(prev if prev != "" else "da")
	await t.frames(1)
	union["ok"] = (union["defects"] as Array).is_empty()
	return union


## The project theme as a whole: no red colour, R1 outlines on the main styles, a gold focus ring on every focusable type. Also lists (informational unless the
## strict_* options turn them into defects): gold_hover, font_scale, focus_styles - see Rules.theme_scan. Result adds {gold_hover, red, ink, font_scale, focus_styles}.
static func theme_report(theme: Theme = null, options: Dictionary = {}) -> Dictionary:
	var s := Rules.theme_scan(theme, options)
	var r := _report()
	for d in s["defects"]:
		var dd: Dictionary = d.duplicate()
		if dd["code"] == "focus_style_not_gold":
			dd["code"] = "focus_style_not_gold_theme"
		(r["defects"] as Array).append(dd)
	r["ok"] = (r["defects"] as Array).is_empty()
	r["types"] = s["types"]
	for k in ["gold_hover", "red", "ink", "font_scale", "focus_styles"]:
		r[k] = s[k]
	return r


## Flips the language da -> en (and back) and checks that every non-key text of the screen changes: a text that stays the same is a literal in
## the scene or script, or a screen that does not re-label itself on NOTIFICATION_TRANSLATION_CHANGED (plan 5.4). Texts that are translation
## keys are localized by definition and are not compared. options: ignore, same_ok (Array of texts that are legitimately the same).
static func locale_flip_report(t, root: Node, options: Dictionary = {}) -> Dictionary:
	if not _usable(root):
		return _no_root("locale_flip_report")
	var r := _report()
	var bad := _option_defects("locale_flip_report", options)
	options = _sane("locale_flip_report", options)
	var prev_locale := TranslationServer.get_locale()
	var same_ok: Array = options.get("same_ok", ["Trætoppen"])
	TranslationServer.set_locale("da")
	await t.frames(SETTLE_FRAMES)
	var da := _flip_snapshot(root, options)
	TranslationServer.set_locale("en")
	await t.frames(SETTLE_FRAMES)
	var en := _flip_snapshot(root, options)
	TranslationServer.set_locale(prev_locale if prev_locale != "" else "da")
	await t.frames(1)
	var compared := 0
	for p in da:
		if not en.has(p):
			continue
		var a: Dictionary = da[p]
		var b: Dictionary = en[p]
		if bool(a["key"]) or bool(a["ok_same"]):
			continue
		compared += 1
		if a["text"] == b["text"] and Rules.letter_count(str(a["text"])) >= 3 and str(a["text"]) not in same_ok:
			_defect(r, "not_localized", p, "'%s' is the same in Danish and English: a literal, or the screen does not re-label on NOTIFICATION_TRANSLATION_CHANGED" % str(a["text"]).left(40))
	r["compared"] = compared
	_merge_option_defects(r, bad)
	return r


static func _flip_snapshot(root: Node, options: Dictionary) -> Dictionary:
	var out := {}
	for n in Rules.nodes(root, options.get("ignore", [])):
		var raw := ""
		if n is Label:
			raw = (n as Label).text
		elif n is RichTextLabel:
			raw = (n as RichTextLabel).text
		elif n is Button:
			raw = (n as Button).text
		if raw == "":
			continue
		var shown := ""
		for it in Rules.text_items(n):
			shown = str(it["text"])
			break
		out[_rel(root, n)] = {"text": shown, "key": Rules.is_key_shaped(raw), "ok_same": n.has_meta(&"tt_text_same_ok")}
	return out


# ---------------------------------------------------------------------------------------------------- windowed: the ring in the frame

## WINDOWED only: focuses `control`, grabs the frame and verifies the guide's gold ring around it (gold 1-3 px outside the body, ink 4-5 px outside); then releases
## focus and verifies that the SAME pixels are no longer gold (the negative control). A control whose focus look is a gold FILL (menu row, chip) is sampled inside.
## Returns {ok, skipped, defects, kind ("ring" | "fill"), sampled: [{side, offset, got, want, ok}], gold_ok, ink_ok, focused_hits, unfocused_hits, samples}.
## Headless: {skipped: true}. options: tolerance (0..255 per channel, default 24), other (a second, unfocused control that must show nothing), style (the StyleBox the
## control paints its ring with; a control that paints its own ring declares it with the meta `tt_focus_style` instead of a theme "focus" entry), shot (screenshot name),
## focus (false: sample without focusing, for a selected / persistent ring), expect ("ring" default | "fill" | "none": none asserts that neither a ring nor a fill is
## there, e.g. an unfocused sibling), allow_missing_sides (default 0: EVERY sampled pixel of the ring - gold on four sides, ink on four sides - must be there, because a ring cut
## off at one side of a clipping list is a real defect; a deliberate edge case may allow N).
static func ring_pixels(t, control: Control, options: Dictionary = {}) -> Dictionary:
	var bad := _option_defects("ring_pixels", options)
	var res := await _ring_pixels(t, control, _sane("ring_pixels", options))
	_merge_option_defects(res, bad)
	return res


static func _ring_pixels(t, control: Control, options: Dictionary) -> Dictionary:
	if control == null or not is_instance_valid(control) or not control.is_inside_tree():
		return _no_root("ring_pixels")
	var r := _report()
	if not t.has_window():
		r["skipped"] = true
		_note(r, "ring_pixels needs a window: run it from run_windowed(t) (tests/run_playtest.sh --windowed)")
		return r
	r["skipped"] = false
	var tol := float(options.get("tolerance", 24.0))
	var expect_what := str(options.get("expect", "ring"))
	var do_focus := bool(options.get("focus", true))
	if do_focus:
		if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree():
			_defect(r, "ring_missing", str(control.get_path()), "%s cannot take keyboard focus, so it can show no ring" % control.name)
			return r
		control.grab_focus()
		await t.frames(3)
	var plan := _ring_plan(control, options.get("style", null))
	var samples: Array[Vector2i] = []
	for e in plan["points"]:
		samples.append(e["pos"])
	r["samples"] = samples.size()
	r["kind"] = plan["kind"]
	if samples.is_empty():
		if expect_what != "none":
			_defect(r, "ring_missing", control.name, "%s has no focus style to sample" % control.name)
		return r
	var img: Image = await t.capture(str(options.get("shot", "")))
	if img == null:
		_defect(r, "ring_missing", control.name, "no frame could be grabbed")
		return r
	var sampled: Array[Dictionary] = []
	var gold_hits := 0
	var gold_n := 0
	var ink_hits := 0
	var ink_n := 0
	var bounds := Rect2i(Vector2i.ZERO, img.get_size())
	for e in plan["points"]:
		var px := img.get_pixelv(e["pos"]) if bounds.has_point(e["pos"]) else Color(0, 0, 0, 0)
		var want: Color = e["want"]
		var good := Rules.color_close(px, want, tol) or (str(e["role"]) == "gold" and Rules.color_close(px, Rules.C.GOLD_HOVER, tol))
		sampled.append({"side": e["side"], "offset": e["offset"], "got": Rules.hex(px), "want": Rules.hex(want), "ok": good})
		if e["role"] == "gold":
			gold_n += 1
			gold_hits += 1 if good else 0
		else:
			ink_n += 1
			ink_hits += 1 if good else 0
	var allow := int(options.get("allow_missing_sides", 0))
	r["sampled"] = sampled
	r["focused_hits"] = gold_hits
	r["gold_samples"] = gold_n
	r["ink_hits"] = ink_hits
	r["ink_samples"] = ink_n
	r["gold_ok"] = gold_hits >= maxi(gold_n - allow, 1)
	r["ink_ok"] = ink_n == 0 or ink_hits >= maxi(ink_n - allow, 1)
	if expect_what == "none":
		if gold_hits >= maxi(gold_n - 1, 1):
			_defect(r, "ring_always_on", str(control.get_path()), "%s shows a gold ring / fill although none is expected (an unfocused sibling)" % control.name)
		return r
	if not bool(r["gold_ok"]):
		_defect(r, "ring_missing", str(control.get_path()), "only %d of %d gold sample pixels around %s are the guide's gold %s (every side must show it: a ring cut off by a clipping parent is a defect)" % [gold_hits, gold_n, control.name, Rules.hex(Rules.C.GOLD)])
	elif not bool(r["ink_ok"]):
		_defect(r, "ring_ink_missing", str(control.get_path()), "the gold ring of %s has no ink band 4-5 px outside it (%d of %d ink pixels)" % [control.name, ink_hits, ink_n])
	# negative control: the same pixels once focus is gone
	if do_focus:
		control.release_focus()
		await t.frames(3)
		var img2: Image = await t.capture((str(options.get("shot", "")) + "_unfocused") if str(options.get("shot", "")) != "" else "")
		if img2 != null:
			var hits2 := 0
			for e2 in plan["points"]:
				if e2["role"] == "gold" and bounds.has_point(e2["pos"]):
					var px2 := img2.get_pixelv(e2["pos"])
					if Rules.color_close(px2, Rules.C.GOLD, tol) or Rules.color_close(px2, Rules.C.GOLD_HOVER, tol):
						hits2 += 1
			r["unfocused_hits"] = hits2
			if hits2 >= maxi(gold_n - 1, 1):
				_defect(r, "ring_always_on", str(control.get_path()), "the %d ring pixels around %s are gold although it is not focused" % [hits2, control.name])
		var other: Control = options.get("other", null)
		if other != null and other.is_visible_in_tree() and img2 != null:
			var oplan := _ring_plan(other)
			var oh := 0
			var on := 0
			for e3 in oplan["points"]:
				if e3["role"] == "gold" and bounds.has_point(e3["pos"]):
					on += 1
					if Rules.color_close(img2.get_pixelv(e3["pos"]), Rules.C.GOLD, tol):
						oh += 1
			r["other_hits"] = oh
			if on > 0 and oh >= maxi(on - 1, 1):
				_defect(r, "ring_always_on", str(other.get_path()), "the unfocused control %s shows a gold ring" % other.name)
	return r


## Where the focus style paints: {kind: "ring" | "fill", points: [{pos, want, role: gold | ink, side, offset}]}. The ring is sampled at the middle of each band on the four
## edge midpoints (gold 1-3 px outside the body, ink 4-5 px outside); a StyleBoxFlat border is sampled inside; a gold fill is sampled in two interior corners.
static func _ring_plan(c: Control, style: StyleBox = null) -> Dictionary:
	var plan := {"kind": "ring", "points": [] as Array}
	var sb: StyleBox = style
	if sb == null and c.has_meta(&"tt_focus_style"):
		sb = c.get_meta(&"tt_focus_style") as StyleBox
	if sb == null:
		sb = c.get_theme_stylebox("tab_focus" if c is TabBar else "focus")
	if sb == null or sb is StyleBoxEmpty:
		return plan
	var xf := c.get_viewport().get_final_transform() * c.get_global_transform_with_canvas()
	var rect := xf * Rect2(Vector2.ZERO, c.size)
	var body := rect
	var gold_mid := 1.5                                    # distance of the gold band's middle from the body edge (negative = inside)
	var ink_mid := -999.0                                  # distance of the ink band's middle (none = not sampled)
	var fill_mode := false
	if sb.get_script() == Rules.BoxStyleScript:
		var inset: Vector4 = sb.get("body_inset")
		body = Rect2(rect.position + Vector2(inset.x, inset.y), rect.size - Vector2(inset.x + inset.z, inset.y + inset.w))
		var rc: PackedColorArray = sb.get("ring_colors")
		var rw: PackedFloat32Array = sb.get("ring_widths")
		var found := false
		var off := 0.0
		var gold_end := 0.0
		for i in mini(rc.size(), rw.size()):
			if Rules.is_gold(rc[i]) and not found:
				gold_mid = off + rw[i] * 0.5
				gold_end = off + rw[i]
				found = true
			elif found and Rules.is_ink(rc[i]) and ink_mid == -999.0:
				ink_mid = off + rw[i] * 0.5
			off += rw[i]
		if found and ink_mid == -999.0:
			ink_mid = gold_end + 1.0                       # the guide's ring is gold + ink: a gold-only ring is expected to show ink just outside it and fails
		if not found and bool(sb.get("draw_body")) and Rules.is_gold(sb.get("fill")):
			fill_mode = true
	elif sb is StyleBoxFlat:
		var f := sb as StyleBoxFlat
		gold_mid = -float(maxi(f.border_width_left, 1)) * 0.5
		if f.draw_center and Rules.is_gold(f.bg_color):
			fill_mode = true
	var pts: Array = plan["points"]
	if fill_mode:
		plan["kind"] = "fill"
		var a := body.position + Vector2(8, 8)
		var b := body.end - Vector2(8, 8)
		pts.append({"pos": Vector2i(int(a.x), int(a.y)), "want": Rules.C.GOLD, "role": "gold", "side": "top-left", "offset": 8.0})
		pts.append({"pos": Vector2i(int(b.x), int(b.y)), "want": Rules.C.GOLD, "role": "gold", "side": "bottom-right", "offset": 8.0})
		return plan
	var cx := body.get_center()
	var sides := {
		"top": Vector2(cx.x, body.position.y), "bottom": Vector2(cx.x, body.end.y),
		"left": Vector2(body.position.x, cx.y), "right": Vector2(body.end.x, cx.y)}
	var outward := {"top": Vector2(0, -1), "bottom": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
	for side in sides:
		var g: Vector2 = sides[side] + outward[side] * gold_mid
		pts.append({"pos": Vector2i(int(g.x), int(g.y)), "want": Rules.C.GOLD, "role": "gold", "side": side, "offset": gold_mid})
		if ink_mid != -999.0:
			var k: Vector2 = sides[side] + outward[side] * ink_mid
			pts.append({"pos": Vector2i(int(k.x), int(k.y)), "want": Rules.C.INK, "role": "ink", "side": side, "offset": ink_mid})
	return plan


# ---------------------------------------------------------------------------------------------------- windowed: panel edge and button profile (spec 2.6)

## WINDOWED: the guide's parchment panel edge seen from the left mid-edge walking outward: parchment, ink x2 (the border, inside the rect), gold x4, ink x2, then
## the backdrop (tolerance 8 per channel). Returns {ok, skipped, defects, profile: [{role, width, color, ok}]}. options: shot, tolerance.
static func panel_pixels(t, panel: Control, options: Dictionary = {}) -> Dictionary:
	if panel == null or not is_instance_valid(panel) or not panel.is_inside_tree():
		return _no_root("panel_pixels")
	var r := _report()
	if not t.has_window():
		r["skipped"] = true
		_note(r, "panel_pixels needs a window")
		return r
	r["skipped"] = false
	await t.frames(2)
	var img: Image = await t.capture(str(options.get("shot", "")))
	if img == null:
		_defect(r, "panel_edge_wrong", panel.name, "no frame could be grabbed")
		return r
	var tol := float(options.get("tolerance", 8.0))
	var xf := panel.get_viewport().get_final_transform() * panel.get_global_transform_with_canvas()
	var rect := xf * Rect2(Vector2.ZERO, panel.size)
	var y := int(rect.get_center().y)
	var x0 := int(round(rect.position.x))
	var psb := panel.get_theme_stylebox("panel")
	if psb != null and psb.get_script() == Rules.BoxStyleScript:
		x0 += int((psb.get("body_inset") as Vector4).x)                    # the body starts inside the control rect when the style insets it
	# roles from the inside out: [role, expected colour, pixel x offsets from the rect's left edge]
	var spec := [["parchment", Rules.C.PARCHMENT, [6, 7]], ["ink", Rules.C.INK, [0, 1]], ["gold", Rules.C.GOLD, [-1, -2, -3, -4]], ["ink_outer", Rules.C.INK, [-5, -6]]]
	var profile: Array[Dictionary] = []
	var bad: Array[String] = []
	for e in spec:
		var ok := true
		var got := Color(0, 0, 0, 0)
		for dx in e[2]:
			var p := Vector2i(x0 + int(dx), y)
			if not Rect2i(Vector2i.ZERO, img.get_size()).has_point(p):
				ok = false
				continue
			got = img.get_pixelv(p)
			if not Rules.color_close(got, e[1], tol):
				ok = false
		profile.append({"role": e[0], "width": (e[2] as Array).size(), "color": Rules.hex(got), "ok": ok})
		if not ok:
			bad.append("%s (%s, want %s)" % [e[0], Rules.hex(got), Rules.hex(e[1])])
	r["profile"] = profile
	if not bad.is_empty():
		_defect(r, "panel_edge_wrong", str(panel.get_path()), "the edge of %s is not parchment / ink 2 / gold 4 / ink 2: %s" % [panel.name, ", ".join(bad)])
	return r


## WINDOWED: the guide's button seen along a vertical line near the left side (away from the label): ink border at the top, the face, the inner bottom band (primary
## and secondary), the ink border at the bottom and the 4 px hard ink underside. Positions come from the button's own `normal` TTBoxStyle (inset, border, band,
## hard_shadow); the button must be neither focused nor hovered. Returns {ok, skipped, defects, profile: [{role, y, got, want, ok}]}.
static func button_pixels(t, button: Control, options: Dictionary = {}) -> Dictionary:
	if button == null or not is_instance_valid(button) or not button.is_inside_tree():
		return _no_root("button_pixels")
	var r := _report()
	if not t.has_window():
		r["skipped"] = true
		_note(r, "button_pixels needs a window")
		return r
	r["skipped"] = false
	if button.has_focus():
		button.release_focus()
	await t.frames(3)
	var img: Image = await t.capture(str(options.get("shot", "")))
	if img == null:
		_defect(r, "button_profile_wrong", button.name, "no frame could be grabbed")
		return r
	var tol := float(options.get("tolerance", 14.0))
	var sb := button.get_theme_stylebox("normal")
	if sb == null or sb.get_script() != Rules.BoxStyleScript:
		_defect(r, "button_profile_wrong", str(button.get_path()), "%s has no TTBoxStyle 'normal' style: it is not one of the guide's buttons" % button.name)
		return r
	var xf := button.get_viewport().get_final_transform() * button.get_global_transform_with_canvas()
	var rect := xf * Rect2(Vector2.ZERO, button.size)
	var inset: Vector4 = sb.get("body_inset")
	var body := Rect2(rect.position + Vector2(inset.x, inset.y), rect.size - Vector2(inset.x + inset.z, inset.y + inset.w))
	var bw := float(sb.get("border_width"))
	var fill: Color = sb.get("fill")
	var x := int(body.position.x + 14.0)
	var rows: Array[Dictionary] = [
		{"role": "ink_top", "y": int(body.position.y), "want": Rules.C.INK},
		{"role": "face", "y": int(body.position.y + bw + 3.0), "want": fill}]
	var band_color: Color = sb.get("band_color")
	if int(sb.get("band_side")) == 1 and band_color.a > 0.0:         # BandSide.BOTTOM
		rows.append({"role": "band", "y": int(body.end.y - bw - 2.0), "want": fill.lerp(Color(band_color.r, band_color.g, band_color.b, 1.0), band_color.a)})
	rows.append({"role": "ink_bottom", "y": int(body.end.y - 1.0), "want": Rules.C.INK})
	var hard := float(sb.get("hard_shadow"))
	if hard > 0.0:
		rows.append({"role": "underside", "y": int(body.end.y + hard * 0.5), "want": sb.get("hard_shadow_color")})
	var want_underside := bool(options.get("underside", true))
	if want_underside and hard < 4.0:
		rows.append({"role": "underside", "y": int(body.end.y + 2.0), "want": Rules.C.INK})        # the guide's button stands on a 4 px hard ink underside: this style draws none
	var profile: Array[Dictionary] = []
	var bad: Array[String] = []
	for row in rows:
		var p := Vector2i(x, int(row["y"]))
		var got := img.get_pixelv(p) if Rect2i(Vector2i.ZERO, img.get_size()).has_point(p) else Color(0, 0, 0, 0)
		var ok := Rules.color_close(got, row["want"], tol)
		profile.append({"role": row["role"], "y": row["y"], "got": Rules.hex(got), "want": Rules.hex(row["want"]), "ok": ok})
		if not ok:
			bad.append("%s %s (want %s)" % [row["role"], Rules.hex(got), Rules.hex(row["want"])])
	r["profile"] = profile
	if not bad.is_empty():
		_defect(r, "button_profile_wrong", str(button.get_path()), "%s does not have the guide's button profile (ink border, face, band, ink border, 4 px underside): %s" % [button.name, ", ".join(bad)])
	return r


# ---------------------------------------------------------------------------------------------------- static text scans

## Hard-coded copy in a scene file (spec 10.10): {hard_coded: [{node, property, text, line}], keys: [text of every key-shaped value], ok}. Reads the .tscn text:
## every text / title / placeholder_text / tooltip_text value that is not empty, not a translation key and not numeric / format-only.
static func scene_text_report(scene_path: String) -> Dictionary:
	var hits := Rules.literal_scan(null, [scene_path])
	var src := FileAccess.get_file_as_string(scene_path)
	var out := {"hard_coded": [] as Array, "keys": [] as Array, "ok": true}
	var node_rx := RegEx.new()
	node_rx.compile("(?m)^\\[node name=\"([^\"]+)\"")
	var headers := node_rx.search_all(src)
	for h in hits:
		var name_ := ""
		for m in headers:
			if src.left(m.get_start()).count("\n") + 1 <= int(h["line"]):
				name_ = m.get_string(1)
		(out["hard_coded"] as Array).append({"node": name_, "property": h["prop"], "text": h["text"], "line": h["line"]})
	var key_rx := RegEx.new()
	key_rx.compile("(?m)^(?:text|title|placeholder_text|tooltip_text)\\s*=\\s*\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	for m in key_rx.search_all(src):
		(out["keys"] as Array).append(m.get_string(1))
	out["ok"] = (out["hard_coded"] as Array).is_empty()
	return out


## Hard-coded copy in a script (spec 10.10): {literals: [{line, text, property}], ok}: `.text = "..."` / add_item("...") with a real word (key-shaped strings, numbers and
## glyph-only strings pass).
static func script_text_report(script_path: String) -> Dictionary:
	var out := {"literals": [] as Array, "ok": true}
	for h in Rules.literal_scan(null, [script_path]):
		(out["literals"] as Array).append({"line": h["line"], "text": h["text"], "property": h["prop"]})
	out["ok"] = (out["literals"] as Array).is_empty()
	return out


# ---------------------------------------------------------------------------------------------------- helpers for the packages' own sections

## Turns a report into ONE harness check named `name` (spec 10.11): the detail carries the first five defects. Returns ok.
static func expect(t, report: Dictionary, name: String) -> bool:
	var ok := bool(report.get("ok", false)) and (report.get("defects", []) as Array).is_empty()
	var detail := _ok_detail(report) if ok else "%s: %s" % [summary(report), " | ".join(lines(report, 5))]
	return t.check(name, ok, detail)


static var _opened_screens: Dictionary = {}


## Opens a registry screen the way audit_screen does (scene / fixture / driver, two frames) and returns its root; null when it cannot be opened.
## close_screen(t, id) closes it again (frees the host, restores the modal stack, the pause state and the language).
static func open_screen(t, id: String) -> Node:
	var entry := screen(id)
	if entry.is_empty():
		t.fail("ui_audit: no screen '%s' in the registry" % id)
		return null
	var opened := await _open_screen(t, _normalize_entry(entry))
	if opened.is_empty():
		return null
	_opened_screens[id] = opened
	return opened["node"]


static func close_screen(t, id: String) -> void:
	if _opened_screens.has(id):
		var opened: Dictionary = _opened_screens[id]
		_opened_screens.erase(id)
		await _close_screen(t, opened)


## Hover and click audit (spec 10.11, section 3.4 H): moves the mouse over every focusable control and records which one grabbed focus (a list-like row should,
## a card / chip / tab / field should not), then clicks the controls named in options.click (non-destructive ones) and checks that focus never drops.
## options: list_like (glob patterns of rows that must take focus on hover), click (glob patterns), ignore.
## Result: {ok, defects, hover_focus: [{path, grabbed}], unexpected_grabs: [path], missing_grabs: [path], click_focus_lost: [path]}.
static func mouse_walk(t, root: Node, options: Dictionary = {}) -> Dictionary:
	if not _usable(root):
		return _no_root("mouse_walk")
	var r := _report()
	var bad := _option_defects("mouse_walk", options)
	options = _sane("mouse_walk", options)
	r["hover_focus"] = [] as Array
	r["unexpected_grabs"] = [] as Array
	r["missing_grabs"] = [] as Array
	r["click_focus_lost"] = [] as Array
	var list_like: Array = options.get("list_like", [])
	var clicks: Array = options.get("click", [])
	var controls: Array[Control] = []
	for n in Rules.nodes(root, options.get("ignore", [])):
		if n is Control and Rules.is_interactive(n as Control) and (n as Control).focus_mode == Control.FOCUS_ALL and Rules.is_enabled(n as Control) and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			controls.append(n as Control)
	var far := Vector2(2.0, 2.0)
	for c in controls:
		var rp := _rel(root, c)
		t.root.gui_release_focus()
		t.move_mouse(far)
		await t.frames(1)
		t.move_mouse(c.get_global_rect().get_center())
		await t.frames(2)
		var grabbed := _owner(t) == c
		(r["hover_focus"] as Array).append({"path": rp, "grabbed": grabbed})
		var should := false
		for pat in list_like:
			should = should or rp.match(str(pat))
		if grabbed and not should:
			(r["unexpected_grabs"] as Array).append(rp)
			_defect(r, "hover_grabs_focus", rp, "%s took keyboard focus when the mouse only hovered it (only list-like rows do that, spec 3.4 H)" % rp)
		if should and not grabbed:
			(r["missing_grabs"] as Array).append(rp)
			_defect(r, "hover_no_focus", rp, "%s is a list-like row but did not take focus when the mouse entered it" % rp)
	for c in controls:
		var rp2 := _rel(root, c)
		var go := false
		for pat in clicks:
			go = go or rp2.match(str(pat))
		if not go:
			continue
		c.grab_focus()
		await t.frames(1)
		t.click(c.get_global_rect().get_center())
		await t.frames(2)
		if _owner(t) == null:
			(r["click_focus_lost"] as Array).append(rp2)
			_defect(r, "click_drops_focus", rp2, "after a click on %s no control owns focus: the keyboard is dead until the next Tab" % rp2)
	t.move_mouse(far)
	await t.frames(1)
	_merge_option_defects(r, bad)
	return r


# ---------------------------------------------------------------------------------------------------- selftest

## A modal pair for the selftest: `all_at_once` = one Esc pops both layers (the defect); otherwise Esc pops the top one.
class _SelftestModals extends Node:
	var gm: Node
	var all_at_once := false
	var names: Array[StringName] = []
	var _layers: Array[Dictionary] = []                    # [{button, opener}]

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func open(level: int) -> void:
		var opener := get_viewport().gui_get_focus_owner()
		var mname := StringName("selftest_modal_%d" % level)
		names.append(mname)
		gm.call("push_modal", mname)
		var b := Button.new()
		b.name = "B%d" % level
		b.text = "UI_YES"
		add_child(b)
		_layers.append({"button": b, "opener": opener})
		b.grab_focus()

	func _input(event: InputEvent) -> void:
		if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")) or names.is_empty():
			return
		var count := names.size() if all_at_once else 1
		for _i in count:
			gm.call("pop_modal", names.pop_back())
			var layer: Dictionary = _layers.pop_back()
			(layer["button"] as Node).queue_free()
			var opener: Control = layer["opener"]
			if opener != null and is_instance_valid(opener) and opener.is_visible_in_tree():
				opener.grab_focus()
		get_viewport().set_input_as_handled()


## Proves the library on the machine that runs it: builds one small planted defect per report in code (no fixture files) and checks that the report finds it, plus
## one conforming control that it must NOT flag. Returns {ok, controls: [{name, expect, found, ok}], defects}; a package's own section can call
## `UiAudit.expect(t, await UiAudit.selftest(t), "my_section.ui_audit_selftest")`. Controls: a button with FOCUS_NONE, a button that takes focus from the mouse only,
## a gold hover in a theme, a red label, hard-coded Label.text, and a modal pair where one Esc pops twice (plus a conforming button, theme and modal).
## Meta codes of the library's own health check (not UI defects, so not in DEFECTS): selftest_blind = a planted control was not reported, selftest_false_positive =
## a conforming control was flagged.
const META_DEFECTS := ["selftest_blind", "selftest_false_positive"]


static func selftest(t) -> Dictionary:
	var r := _report()
	r["controls"] = [] as Array
	var host := Control.new()
	host.name = "UiAuditSelftest"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	t.root.add_child(host)
	var box := VBoxContainer.new()
	host.add_child(box)
	var good := Button.new()
	good.name = "Good"
	good.text = "UI_YES"
	good.theme_type_variation = &"ButtonPrimary"
	good.custom_minimum_size = Vector2(260, 52)
	var none := Button.new()
	none.name = "FocusNone"
	none.text = "UI_NO"
	none.focus_mode = Control.FOCUS_NONE
	none.custom_minimum_size = Vector2(260, 52)
	var click_only := Button.new()
	click_only.name = "ClickOnly"
	click_only.text = "UI_NO"
	click_only.focus_mode = Control.FOCUS_CLICK
	click_only.custom_minimum_size = Vector2(260, 52)
	var red := Label.new()
	red.name = "RedLabel"
	red.text = "HUD_ENERGY"
	red.add_theme_color_override("font_color", Color("#d62828"))
	var literal := Label.new()
	literal.name = "Literal"
	literal.text = "Hej fra koden"
	for c in [good, none, click_only, red, literal]:
		box.add_child(c)
	await t.frames(3)
	var foc := focusable_report(host)
	_selftest_control(r, "focus_none_button", "unfocusable_interactive", foc)
	_selftest_control(r, "click_only_button", "focus_click_only", foc)
	_selftest_clean(r, "conforming_button_has_a_focus_ring", focusable_report(host, {"ignore": ["**/FocusNone", "**/ClickOnly"]}))
	_selftest_control(r, "red_label", "r4_red", rule_report(host, {"rules": ["r4"]}))
	_selftest_clean(r, "conforming_button_has_no_red", rule_report(host, {"rules": ["r4"], "ignore": ["**/RedLabel"]}))
	_selftest_control(r, "hard_coded_label_text", "not_localized", await locale_flip_report(t, host))
	var th := Theme.new()
	var gold := StyleBoxFlat.new()
	gold.bg_color = Rules.C.GOLD
	gold.border_color = Rules.C.INK
	gold.set_border_width_all(2)
	th.set_stylebox("hover", "Button", gold)
	th.set_stylebox("focus", "Button", gold)
	_selftest_control(r, "gold_hover_in_a_theme", "theme_gold_hover", theme_report(th, {"strict_gold_hover": true}))
	_selftest_clean(r, "project_theme_has_no_red", {"defects": (theme_report().get("defects", []) as Array).filter(func(d): return d["code"] == "r4_red")})
	host.queue_free()
	await t.frames(2)
	var gm: Node = t.root.get_node_or_null("GameManager")
	if gm == null:
		_note(r, "selftest: no GameManager autoload, the modal controls were skipped")
	else:
		for all_at_once in [true, false]:
			var mh := Control.new()
			mh.process_mode = Node.PROCESS_MODE_ALWAYS
			t.root.add_child(mh)
			var m := _SelftestModals.new()
			m.gm = gm
			m.all_at_once = all_at_once
			mh.add_child(m)
			await t.frames(2)
			var rep := await escape_chain(t, func(level: int) -> void: m.open(level), 2)
			if all_at_once:
				_selftest_control(r, "modal_that_pops_twice", "esc_closes_several", rep)
			else:
				_selftest_clean(r, "conforming_modal_pair", rep)
			mh.queue_free()
			await t.frames(2)
	r["ok"] = (r["defects"] as Array).is_empty()
	return r


static func _selftest_control(r: Dictionary, name: String, code: String, report: Dictionary) -> void:
	var found := false
	for d in report.get("defects", []):
		found = found or d["code"] == code
	(r["controls"] as Array).append({"name": name, "expect": code, "found": found, "ok": found})
	if not found:
		_defect(r, "selftest_blind", name, "the planted control '%s' was NOT reported as %s: the audit is blind to it" % [name, code])


static func _selftest_clean(r: Dictionary, name: String, report: Dictionary) -> void:
	var clean := (report.get("defects", []) as Array).is_empty()
	(r["controls"] as Array).append({"name": name, "expect": "", "found": not clean, "ok": clean})
	if not clean:
		_defect(r, "selftest_false_positive", name, "the conforming control '%s' was flagged: %s" % [name, str((report["defects"] as Array)[0].get("code", ""))])


# ---------------------------------------------------------------------------------------------------- the registry

## The screen registry (tests/lib/ui_screens.json): an Array of screen entries (Dictionaries), in file order, each normalized (see _normalize_entry) and with a
## `status` ("live" | "pending" | "legacy"): the one written in the file, or - when the row has none (the navigation spec's rows, D17) - DERIVED: pending = no scene,
## legacy = the scene exists but is one of the two old scaffold scenes that is not on the guide theme yet, live = the rest.
static func screens() -> Array:
	var out: Array = []
	for e in _load_registry().get("screens", []):
		out.append(_normalize_entry((e as Dictionary).duplicate(true)))
	return out


static func screens_by_status(status: String) -> Array:
	var out: Array = []
	for s in screens():
		if str(s.get("status", "")) == status:
			out.append(s)
	return out


static func screen(id: String) -> Dictionary:
	for s in _load_registry().get("screens", []):
		if str(s.get("id", "")) == id:
			return _normalize_entry((s as Dictionary).duplicate(true))
	return {}


## Accepts both row shapes (the row is returned as written plus `open`, `options`, `status`, `escape` when they were derived). Spec shape: {id, title, kind: scene|modal|hud|component|surface|fade, scene, fixture, package, guide, focus: initial|none, modal, esc_depth,
## compare, checks: [focusable_report, rule_report, escape_chain, ring_pixels ...]} with no status. Library shape: {open: {scene | fixture | driver}, status, escape: {depth}}.
static func _normalize_entry(e: Dictionary) -> Dictionary:
	if not e.has("open"):
		var open := {}
		if str(e.get("fixture", "")) != "" and FIXTURES.available(str(e["fixture"])):
			open["fixture"] = str(e["fixture"])                # the owners' state set-up (UiFixtures.register_setup) and the stand-in backdrop
		elif str(e.get("scene", "")) != "":
			open["scene"] = str(e["scene"])
		e["open"] = open
	if e.has("esc_depth"):
		var esc: Dictionary = (e["escape"] as Dictionary).duplicate() if e.has("escape") else {}
		if not esc.has("depth"):
			esc["depth"] = int(e["esc_depth"])
		if not esc.has("via") and not esc.has("vias"):
			esc["via"] = "key"
		if not esc.has("pre_opened"):
			esc["pre_opened"] = true
		e["escape"] = esc                                         # a spec row's `escape` object (vias, settle_seconds) only adds to what esc_depth implies
	if not e.has("options"):
		e["options"] = {}
	if not e.has("status"):
		e["status"] = _derive_status(e)
		e["status_derived"] = true                            # nobody edits the row to flip it, so there is no pending tripwire for it
	return e                                                  # `kind` and `checks` stay as written: entry_kind / entry_checks give the audit's reading of them


## How the audit reads a row's `kind`: scene -> screen, component / fade -> surface, and a row with focus: none is audited like a HUD (no control may take focus).
static func entry_kind(e: Dictionary) -> String:
	var kind: String = {"scene": "screen", "component": "surface", "fade": "surface"}.get(str(e.get("kind", "screen")), str(e.get("kind", "screen")))
	if str(e.get("focus", "initial")) == "none" and kind in ["screen", "modal"]:
		return "hud"
	return kind


## The check names to run for a row: its `checks` (the spec's API names are accepted: focusable_report, rule_report, escape_chain, ring_pixels ...) or the defaults of its kind.
static func entry_checks(e: Dictionary) -> Array:
	var out: Array = []
	for c in e.get("checks", _default_checks(entry_kind(e))):
		out.append(CHECK_ALIASES.get(str(c), str(c)))
	return out


const CHECK_ALIASES := {"focusable_report": "focusable", "rule_report": "rules", "escape_chain": "escape", "ring_pixels": "ring", "initial_focus": "initial_focus",
	"focus_walk": "focus_walk", "theme_report": "theme", "text_field_audit": "text_fields", "locale_flip_report": "i18n_flip"}


static func _derive_status(e: Dictionary) -> String:
	# a spec row: pending = no scene (spec 10.1), whatever its fixture says; a row that is a part of another screen's scene (the intro, the minimap) has no scene of its own and
	# names the file whose appearance means it can be audited as `tripwire`
	var path: String = str(e["scene"]) if e.has("scene") and str(e["scene"]) != "" else (str(e["tripwire"]) if e.has("tripwire") else (_tripwire_path(e) if not e.has("scene") else ""))
	if path == "":
		return "pending"
	var exists := ResourceLoader.exists(path) or FileAccess.file_exists(path)
	if not exists:
		return "pending"
	if path in LEGACY_SCENES and not FileAccess.get_file_as_string(path).contains("theme_type_variation"):
		return "legacy"                                      # the scaffold scene is still the old one (the same rule as UiFixtures.available)
	return "live"


## The two scaffold scenes the legacy 3D flow shares with the new screens (scripts/ui/dev/ui_fixtures.gd LEGACY_SHARED).
const LEGACY_SCENES: Array[String] = ["res://scenes/main/main_menu.tscn", "res://scenes/ui/character_select.tscn"]


static func _load_registry() -> Dictionary:
	if not _registry.is_empty():
		return _registry
	var txt := FileAccess.get_file_as_string(_registry_path)
	var parsed: Variant = JSON.parse_string(txt)
	_registry = parsed if parsed is Dictionary else {"screens": [], "error": "tests/lib/ui_screens.json does not parse"}
	return _registry


## Drops the cached registry (a test that edits the file, or a section that wants a fresh read).
static func reload_registry() -> void:
	_registry = {}


## Reads the registry from another file (the section's own fixture registry); use_registry("") switches back to tests/lib/ui_screens.json.
static func use_registry(path := "") -> void:
	_registry_path = path if path != "" else REGISTRY_PATH
	_registry = {}


static func _default_checks(kind: String) -> Array:
	match kind:
		"hud":
			return ["focusable", "rules", "i18n_flip"]
		"modal":
			return ["initial_focus", "focusable", "focus_walk", "escape", "rules", "i18n_flip"]
		"gallery":
			return ["focusable", "rules"]
		"surface":
			return ["rules", "i18n_flip"]
		_:
			return ["initial_focus", "focusable", "focus_walk", "rules", "i18n_flip"]


static func _pending_scene_exists(entry: Dictionary) -> bool:
	var trip := _tripwire_path(entry)
	if trip != "":
		return ResourceLoader.exists(trip) or FileAccess.file_exists(trip)
	var open: Dictionary = entry.get("open", {})
	if open.has("fixture"):
		return FIXTURES.available(str(open["fixture"]))
	return false


## The file whose appearance means a pending screen landed: entry.tripwire, else the scene of entry.open.
static func _tripwire_path(entry: Dictionary) -> String:
	if entry.has("tripwire"):
		return str(entry["tripwire"])
	var open: Dictionary = entry.get("open", {})
	if open.has("scene"):
		return str(open["scene"])
	if open.has("fixture"):
		return FIXTURES.scene_path(str(open["fixture"]))
	return ""


## Runs every check listed for the screen in tests/lib/ui_screens.json and records them on `t`:
##   live     every check is a harness check named "<section>.<id>.<check>"; a defect fails the run.
##   legacy   the old scaffold screen: the checks run, every finding is a visible "KNOWN-GAP" line, never silently green; each gap listed in
##            `known_gaps` is a check that passes while the defect still exists (and fails when it is gone: flip the entry to live).
##   pending  the screen does not exist yet: one SKIP line with the package id (and a failing check when its scene appeared but the entry was not flipped).
## Returns {id, status, ok, skipped, checks: {name: report}, defects: [{check, code, path, msg}]}.
static func audit_screen(t, id: String, overrides: Dictionary = {}) -> Dictionary:
	var entry := screen(id)
	var out := {"id": id, "status": "unknown", "ok": false, "skipped": false, "checks": {}, "defects": [] as Array}
	if entry.is_empty():
		t.fail("ui_audit: no screen '%s' in tests/lib/ui_screens.json" % id)
		return out
	entry.merge(overrides, true)
	var status := str(entry.get("status", "pending"))
	var pkg := str(entry.get("package", "?"))
	out["status"] = status
	var opt_problems := validate_options("registry", entry.get("options", {}))
	var esc_probe: Dictionary = (entry.get("escape", {}) as Dictionary).duplicate()
	for ek in ["depth", "pre_opened"]:
		esc_probe.erase(ek)
	opt_problems.append_array(validate_options("escape_chain", esc_probe))
	if not opt_problems.is_empty():
		t.check("%s.options" % id, false, "the registry row's options are not ones the audit knows (a typo would silently switch a requirement off): %s" % "; ".join(opt_problems))
		out["defects"] = [{"check": "options", "code": "bad_option", "path": id, "msg": "; ".join(opt_problems)}]
		return out
	if status == "pending":
		if not bool(entry.get("status_derived", false)) and _pending_scene_exists(entry):
			t.check("%s.pending_scene_exists" % id, false, "%s now exists: package %s must flip '%s' to \"live\" in tests/lib/ui_screens.json so its checks run" % [_tripwire_path(entry), pkg, id])
			return out
		t.skip("ui_audit %s: pending (%s): %s" % [id, pkg, str(entry.get("note", "the screen does not exist yet"))])
		out["skipped"] = true
		out["ok"] = true
		return out
	var opened := await _open_screen(t, entry)
	if opened.is_empty():
		t.check("%s.opens" % id, false, "the %s screen could not be opened with %s (missing scene, or the driver returned null): fix the registry entry" % [status, str(entry.get("open", {}))])
		var rep_open := _report()
		_defect(rep_open, "opens_failed", id, "could not open %s" % str(entry.get("open", {})))
		out["defects"] = [{"check": "opens", "code": "opens_failed", "path": id, "msg": "could not open"}]
		return out
	var node: Node = opened["node"]
	var host: Node = opened["host"]
	var opts: Dictionary = entry.get("options", {})
	var checks: Array = entry_checks(entry)
	var all_defects: Array[Dictionary] = []
	# precondition: the screen is on screen (a hidden modal root would make every scan pass on nothing)
	var shown: bool = not (node is CanvasItem) or (node as CanvasItem).is_visible_in_tree()
	var vis := _report()
	if not shown:
		_defect(vis, "screen_not_visible", _rel(node, node), "%s is hidden after opening: give the registry entry a driver whose open() shows it (modal roots hide in _ready)" % node.name)
	(out["checks"] as Dictionary)["visible"] = vis
	for d in vis["defects"]:
		var dv: Dictionary = (d as Dictionary).duplicate()
		dv["check"] = "visible"
		all_defects.append(dv)
	checks = ["visible"] + checks
	var opening_focus := initial_focus(node)
	for check in checks:
		if opening_focus != null and is_instance_valid(opening_focus):
			opening_focus.grab_focus()
		elif opening_focus == null:
			t.root.gui_release_focus()
		if str(check) == "visible":
			continue
		var rep := await _run_check(t, str(check), entry, node, host, opts)
		(out["checks"] as Dictionary)[str(check)] = rep
		for d in rep.get("defects", []):
			var dd: Dictionary = (d as Dictionary).duplicate()
			dd["check"] = str(check)
			all_defects.append(dd)
	out["defects"] = all_defects
	if status == "live":
		for check in checks:
			var rep2: Dictionary = out["checks"][str(check)]
			if bool(rep2.get("skipped", false)):
				t.skip("ui_audit %s.%s: %s" % [id, check, str((rep2.get("notes", [{"msg": "skipped"}])[0] as Dictionary).get("msg", "skipped"))])
				continue
			var ok := bool(rep2.get("ok", false))
			t.check("%s.%s" % [id, check], ok, summary(rep2) if not ok else _ok_detail(rep2))
			if not ok:
				for line in lines(rep2, 10):
					t.info("  %s" % line)
		out["ok"] = all_defects.is_empty()
	else:
		# legacy: visible KNOWN-GAP lines, and a tripwire per listed gap
		for check in checks:
			var rep3: Dictionary = out["checks"][str(check)]
			if not bool(rep3.get("ok", true)) and not bool(rep3.get("skipped", false)):
				t.info("KNOWN-GAP %s (legacy, replaced by %s) %s: %s" % [id, pkg, check, summary(rep3)])
				for line2 in lines(rep3, 8):
					t.info("    %s" % line2)
		var present := {}
		for d2 in all_defects:
			present[str(d2["code"])] = true
		for gap in entry.get("known_gaps", []):
			t.check("%s.legacy_gap_%s" % [id, gap], present.has(str(gap)), "the legacy screen still has '%s'; when %s fixes it, flip '%s' to live in tests/lib/ui_screens.json" % [gap, pkg, id] if present.has(str(gap)) else "'%s' is gone from the legacy screen: flip '%s' to \"live\" in tests/lib/ui_screens.json" % [gap, id])
		out["ok"] = true
	await _close_screen(t, opened)
	return out


static func _ok_detail(rep: Dictionary) -> String:
	if rep.has("reached"):
		return "%d of %d controls reached in %d presses" % [rep["reached"], rep.get("expected", 0), rep.get("steps", 0)]
	if rep.has("items") and rep.has("interactive"):
		return "%d interactive, %d keyboard-focusable" % [rep["interactive"], (rep.get("focusable", []) as Array).size()]
	if rep.has("counts"):
		var c: Dictionary = rep["counts"]
		return "%d nodes, %d text, %d boxes, %d interactive scanned" % [c.get("nodes", 0), c.get("text_nodes", 0), c.get("boxes", 0), c.get("interactive", 0)]
	if rep.has("opened"):
		return "%d modal(s) opened and closed with Esc in order" % (rep["opened"] as Array).size()
	return "clean"


## Runs `audit_screen` for every registry entry with one of `statuses` (default: live) and returns {id: result}.
static func audit_all(t, statuses: Array = ["live"]) -> Dictionary:
	var out := {}
	for s in screens():
		if str(s.get("status", "")) in statuses:
			out[str(s["id"])] = await audit_screen(t, str(s["id"]))
	return out


## The control a registry row's panel_pixels / button_pixels samples when the row names none: the largest visible double-edge panel, or the first visible enabled
## raised button (its `normal` style is a TTBoxStyle with a hard underside).
static func _auto_pick(root: Node, want_panel: bool) -> Control:
	var best: Control = null
	var best_area := 0.0
	for n in Rules.nodes(root, []):
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var c := n as Control
		if want_panel:
			if (c is PanelContainer or c is Panel) and String(c.theme_type_variation) in ["PanelParchment", "PanelParchmentL", "PanelParchmentL24", "PanelBook", "PanelMenu"]:
				var a := c.size.x * c.size.y
				if a > best_area:
					best = c
					best_area = a
		elif c is Button and Rules.is_enabled(c):
			var sb := c.get_theme_stylebox("normal")
			if sb != null and sb.get_script() == Rules.BoxStyleScript and float(sb.get("hard_shadow")) >= 4.0 and not (c as Button).flat:
				return c
	return best


## The radio-page options a registry row may carry (pages, max_pages, tab_groups) in the shape the page-aware reports take.
static func _page_options(opts: Dictionary) -> Dictionary:
	var out := {}
	for k in ["pages", "max_pages", "tab_groups"]:
		if opts.has(k):
			out[k] = opts[k]
	return out


static func _run_check(t, check: String, entry: Dictionary, node: Node, host: Node, opts: Dictionary) -> Dictionary:
	var ignore: Array = opts.get("ignore", [])
	var kind := entry_kind(entry)
	var rule_opts := {"ignore": ignore, "strict_typography": bool(opts.get("strict_typography", false)), "strict_gold": bool(opts.get("strict_gold", true)), "gold_source": bool(opts.get("gold_source", true)), "hit_min": float(opts.get("hit_min", Rules.HIT_MIN))}
	match check:
		"initial_focus":
			return initial_focus_report(node)
		"focusable":
			var game_screen := kind in ["screen", "modal"]                                  # a game screen: no disabled focus stop, no Window-based control
			var fo := {"ignore": ignore, "forbid_focus": kind == "hud", "forbid_disabled_focus": bool(opts.get("forbid_disabled_focus", game_screen)),
				"forbid_windows": bool(opts.get("forbid_windows", game_screen))}
			fo.merge(_page_options(opts))
			return await focusable_report_pages(t, node, fo)             # the page behind every tab / chip as well (one page when the screen has no radio group)
		"focus_walk":
			var walk_opts := {"ignore": ignore, "wrap": str(opts.get("wrap", "any")), "wrap_axes": str(opts.get("wrap_axes", "v")), "via": str(opts.get("via", "both")), "tabs": bool(opts.get("tabs", true)),
				"replay": bool(opts.get("replay", true)), "accept": opts.get("accept", []), "consumes": opts.get("consumes", {}), "expect_edges": opts.get("expect_edges", {}),
				"echo": bool(opts.get("echo", false)), "pad_check": bool(opts.get("pad_check", true))}
			for k in ["dirs", "start"]:
				if opts.has(k):
					walk_opts[k] = opts[k]
			walk_opts.merge(_page_options(opts))
			return await focus_walk(t, node, int(opts.get("max_steps", 0)), walk_opts)
		"text_fields":
			return await text_field_audit(t, node, {"ignore": ignore})
		"escape":
			var esc: Dictionary = entry.get("escape", {"depth": 1})
			var drv: Variant = host.get_meta(&"ui_audit_driver") if host.has_meta(&"ui_audit_driver") else null
			if (drv == null or not drv.has_method("open_level")) and bool(esc.get("pre_opened", false)):
				# a spec row (esc_depth N, no driver): the screen opened itself with the audit's open route; its layers must be on the modal stack now.
				# Only a row that is ONE modal layer (esc_depth 1 and a `modal` name) can be proved without an opener: a deeper chain (pause > save > confirm) or a
				# scene-back (select) needs the owner's own call UiAudit.escape_chain(t, opener, depth, {internal_layers ...}) in the owner's section.
				if int(esc.get("depth", 1)) > 1 or (int(esc.get("depth", 1)) == 1 and str(entry.get("modal", "x")) == ""):
					var own := _report()
					own["skipped"] = true
					_note(own, "escape_chain of '%s' (esc_depth %d%s) needs the owner's opener: call UiAudit.escape_chain(t, opener, %d) from the owner's section (options.internal_layers for pages inside the screen)" % [str(entry.get("id", "")), int(esc.get("depth", 1)), ", no modal layer" if str(entry.get("modal", "x")) == "" else "", int(esc.get("depth", 1))])
					return own
				var vias: Array = esc.get("vias", [esc.get("via", "key")])
				var pre := {"via": str(vias[0]), "pre_opened": true, "base_stack": host.get_meta(&"ui_audit_base_stack", []), "base_paused": host.get_meta(&"ui_audit_base_paused", false)}
				if host.get_meta(&"ui_audit_base_phase", null) != null:
					pre["base_phase"] = host.get_meta(&"ui_audit_base_phase")
				for k in ["expect_focus", "release_world_focus", "settle_seconds"]:
					if esc.has(k):
						pre[k] = esc[k]
				if int(esc.get("depth", 1)) == 0 and vias.size() > 1:
					# "Esc does nothing" is proved with every way of pressing it (the Esc key, gamepad B, gamepad Start): the screen stays as it was, so the chain can run again
					var all_vias: Dictionary = {}
					for v in vias:
						pre["via"] = str(v)
						var rep_v := await escape_chain(t, Callable(), 0, pre)
						if all_vias.is_empty():
							all_vias = rep_v.duplicate(true)
						else:
							_merge_page_report(all_vias, rep_v, str(v))
							(all_vias["steps"] as Array).append_array(rep_v["steps"])
					all_vias["ok"] = (all_vias["defects"] as Array).is_empty()
					return all_vias
				return await escape_chain(t, Callable(), int(esc.get("depth", 1)), pre)
			if drv == null or not drv.has_method("open_level"):
				var bad := _report()
				_defect(bad, "registry_error", str(entry.get("id", "")), "the registry entry lists the 'escape' check but has no driver with open_level(t, host, level)")
				return bad
			var opener := func(level: int) -> void: await drv.open_level(t, host, level)
			var merged: Dictionary = {"via": str(esc.get("via", "key"))}
			for k in ["expect_focus", "release_world_focus", "settle_seconds"]:
				if esc.has(k):
					merged[k] = esc[k]
			return await escape_chain(t, opener, int(esc.get("depth", 1)), merged)
		"rules":
			rule_opts.merge(_page_options(opts))
			return await rule_report_pages(t, node, rule_opts)
		"r1", "r2", "r3", "r4", "typography", "overrides", "i18n", "hit_targets":
			rule_opts["rules"] = [check]
			rule_opts.merge(_page_options(opts))
			return await rule_report_pages(t, node, rule_opts)
		"i18n_flip":
			return await locale_flip_report(t, node, {"ignore": ignore, "same_ok": opts.get("same_ok", ["Trætoppen"])})
		"theme":
			return theme_report(null, {"strict_gold_hover": bool(opts.get("strict_gold_hover", false)), "strict_focus_styles": bool(opts.get("strict_focus_styles", false)), "strict_font_scale": bool(opts.get("strict_font_scale", false))})
		"mouse_walk":
			return await mouse_walk(t, node, {"ignore": ignore, "list_like": opts.get("list_like", []), "click": opts.get("click", [])})
		"ring", "panel_pixels", "button_pixels":
			if not t.has_window():
				var sk := _report()
				sk["skipped"] = true
				_note(sk, "%s needs a window (run_windowed)" % check)
				return sk
			var shot := "%s_%s" % [check, str(entry.get("id", ""))]
			if check == "ring":
				var target := initial_focus(node)
				if target == null:
					var miss := _report()
					_defect(miss, "ring_missing", "", "no initial focus to sample")
					return miss
				return await ring_pixels(t, target, {"shot": shot})
			var which: Variant = opts.get("panel" if check == "panel_pixels" else "button", "")
			var tn: Node = null
			if which != null and str(which) != "":
				tn = node.get_node_or_null(NodePath(str(which))) if not str(which).begins_with("%") else node.find_child(str(which).substr(1), true, false)
				if tn == null:
					var none := _report()
					_defect(none, "panel_edge_wrong" if check == "panel_pixels" else "button_profile_wrong", str(which), "the registry option '%s' does not name a control of the screen" % ("panel" if check == "panel_pixels" else "button"))
					return none
			else:
				tn = _auto_pick(node, check == "panel_pixels")
				if tn == null:
					var nothing := _report()
					_note(nothing, "%s: no %s of the guide's kind on this screen (name one with options.%s to make the check strict)" % [check, "double-edge panel (PanelParchment / PanelBook / PanelMenu ...)" if check == "panel_pixels" else "raised button (a TTBoxStyle with a 4 px underside)", "panel" if check == "panel_pixels" else "button"])
					return nothing
			if check == "panel_pixels":
				return await panel_pixels(t, tn as Control, {"shot": shot})
			return await button_pixels(t, tn as Control, {"shot": shot})
		"compare_guide":
			var cg := _report()
			cg["skipped"] = true
			_note(cg, "compare_guide is the windowed python tool: tests/checkpoints/compare_guide.py (see the entry's compare field)")
			return cg
		_:
			var unk := _report()
			_defect(unk, "registry_error", check, "the registry lists a check named '%s' that UiAudit does not know" % check)
			return unk


# ---------------------------------------------------------------------------------------------------- opening and closing a registry screen

## Opens the screen of a registry entry under a full-rect host Control. entry.open: {scene} | {fixture} (scripts/ui/dev/ui_fixtures.gd) | {driver}
## (a script with open(t, host, ctx) -> Node, optional close(t, node, host), optional open_level(t, host, level) for the escape check).
## Returns {node, host, driver} or {} when the screen cannot be opened (the caller reports SKIP).
static func _open_screen(t, entry: Dictionary) -> Dictionary:
	var open: Dictionary = entry.get("open", {})
	var locale0 := TranslationServer.get_locale()
	var paused0: bool = t.tree.paused
	var gm0: Node = t.root.get_node_or_null("GameManager")
	var base_stack: Array = gm0.call("modal_stack") if gm0 != null else []
	var phase0: Variant = gm0.get("current_phase") if gm0 != null else null
	TranslationServer.set_locale("da")
	var host := Control.new()
	host.name = "UiAuditHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	t.root.add_child(host)
	var node: Node = null
	var driver: Object = null
	if open.has("scene"):
		var path := str(open["scene"])
		if not ResourceLoader.exists(path):
			host.queue_free()
			return {}
		node = (load(path) as PackedScene).instantiate()
		host.add_child(node)
		await t.frames(3)
	elif open.has("fixture"):
		node = await FIXTURES.make(str(open["fixture"]), host)
		if node == null:
			host.queue_free()
			return {}
		await t.frames(2)
	elif open.has("driver"):
		var script := load(str(open["driver"])) as GDScript
		if script == null:
			host.queue_free()
			return {}
		driver = script.new()
		host.set_meta(&"ui_audit_driver", driver)
		node = await driver.open(t, host, open.get("ctx", {}))
		await t.frames(2)
		if node == null:
			host.queue_free()
			return {}
	else:
		host.queue_free()
		return {}
	host.set_meta(&"ui_audit_base_stack", base_stack)
	host.set_meta(&"ui_audit_base_paused", paused0)
	host.set_meta(&"ui_audit_base_phase", phase0)
	return {"node": node, "host": host, "driver": driver, "base_stack": base_stack, "paused0": paused0, "locale0": locale0}


static func _close_screen(t, opened: Dictionary) -> void:
	var host: Node = opened["host"]
	var driver: Object = opened.get("driver")
	if driver != null and driver.has_method("close"):
		await driver.close(t, opened["node"], host)
	var gm: Node = t.root.get_node_or_null("GameManager")
	if gm != null:
		_cleanup_modals(gm, opened["base_stack"])
	t.tree.paused = bool(opened["paused0"])
	if is_instance_valid(host):
		host.queue_free()
	await t.frames(2)
	TranslationServer.set_locale(str(opened["locale0"]) if str(opened["locale0"]) != "" else "da")
