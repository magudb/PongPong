extends RefCounted
## Section ui_audit_blind: the BLIND SPOTS of the UI audit library, each pinned by a planted screen (tests/sections/ui_audit.gd proves the codes of the catalogue; this section proves
## the places where an earlier version of the library said "clean" about a screen that breaks the guide, and the conforming screens it wrongly flagged). Every `blind_*` check asserts
## that the defect is reported; every `ok_*` check asserts zero findings on a conforming screen. A FAILED line here is a regression of the audit, not of a game screen.
##
## What is pinned (one block per letter, the names of the checks carry it):
##   A mouse-only controls          a Control that reads mouse buttons in _input, or connects its own gui_input, but cannot take focus; the ability slot (reads the mouse BINDINGS
##                                  only) stays clean
##   B radio tabs                   PillTab / Chip buttons in a ButtonGroup: the page behind the other tabs is walked, scanned and hit-target checked; select-on-focus screens are clean
##   C text fields                  typing Space / Tab / Shift / Backspace opens nothing; Enter is only pressed on request (it submits); a TextEdit is typed into too
##   D gold                         gold painted in _draw, a gold StyleBoxLine, gold text from a Theme resource, a gold TextureProgressBar, the script source scan (and its allow-list)
##   E grids                        the ragged last row of a wrapped grid is not "the other way"; a 56-slot screen is not truncated by the default budget
##   F modals                       a layer that rebuilds its opener, a bottom-first / wrong-panel close, a fade-out that needs real time (settle_seconds), "Esc does nothing" is pressed
##   G the keyboard                 FOCUS_ACCESSIBILITY is not a keyboard stop; a dialog created when a button is pressed is a Window; a modal that reads Esc in _unhandled_input
##   H hit targets                  32 px for everything, 20 px for the two guide tag plates, a lowered hit_min says so
##   I sliders                      a plain HSlider has no ring even when the theme has a `focus` style for it (windowed proof in run_windowed)
const SECTION := "ui_audit_blind"
const TIMEOUT_S := 240.0

const Rules = preload("res://tests/lib/ui_audit_rules.gd")
const C = preload("res://scripts/ui/theme/tt_colors.gd")
const ITEM_SLOT := preload("res://scenes/ui/components/item_slot.tscn")
const STEPPER := preload("res://scenes/ui/components/quantity_stepper.tscn")
const ABILITY := preload("res://scenes/ui/components/ability_slot.tscn")
const Screen = preload("res://tests/fixtures/ui_audit/screen.gd")
const GAME_FOCUS := {"forbid_windows": true, "forbid_disabled_focus": true}
const FIXTURE_REGISTRY := "res://tests/fixtures/ui_audit/ui_screens_fixture.json"

var _gm: Node


func run(t) -> void:
	await t.clear_scene()
	TranslationServer.set_locale("da")
	_gm = t.autoload("GameManager")
	await _a_mouse_only(t)
	await _b_radio_tabs(t)
	await _c_text_fields(t)
	await _d_gold(t)
	await _e_grids(t)
	await _f_modals(t)
	await _g_keyboard(t)
	await _h_hit_targets(t)
	await _i_registry_routes(t)


# ---------------------------------------------------------------------------------------------------- helpers

## A runtime script (a fixture that needs its own _input / _draw / gui_input handler without a file of its own).
func _script(src: String) -> GDScript:
	var s := GDScript.new()
	s.source_code = src
	if s.reload() != OK:
		push_error("ui_audit_blind: a fixture script does not compile")
	return s


func _host(t) -> Control:
	t.root.gui_release_focus()
	var host := Control.new()
	host.name = "BlindHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	t.root.add_child(host)
	return host


func _drop(t, host: Node) -> void:
	host.queue_free()
	await t.frames(3)
	t.root.gui_release_focus()


## A conforming base: a parchment panel with `n_buttons` buttons, the first one focused.
func _base(t, n_buttons := 3) -> Dictionary:
	var host := _host(t)
	var root := Control.new()
	root.name = "Screen"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(root)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"PanelParchment"
	panel.position = Vector2(380, 24)
	panel.custom_minimum_size = Vector2(520, 0)
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "V"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "INV_TITLE"
	title.theme_type_variation = &"Display28"
	vbox.add_child(title)
	var buttons: Array[Button] = []
	for i in n_buttons:
		var b := Button.new()
		b.name = "B%d" % (i + 1)
		b.text = ["MENU_CONTINUE", "MENU_SETTINGS", "MENU_QUIT", "SET_DONE"][i % 4]
		b.theme_type_variation = [&"ButtonPrimary", &"ButtonSecondary", &"ButtonTertiary", &"ButtonTertiary"][i % 4]
		b.custom_minimum_size = Vector2(0, 52)
		vbox.add_child(b)
		buttons.append(b)
	await t.frames(3)
	if not buttons.is_empty():
		buttons[0].grab_focus()
	await t.frames(2)
	return {"host": host, "root": root, "vbox": vbox, "buttons": buttons, "panel": panel}


func _codes(rep: Dictionary) -> String:
	var seen: Array[String] = []
	for d in rep.get("defects", []):
		if not seen.has(str(d["code"])):
			seen.append(str(d["code"]))
	return ",".join(seen) if not seen.is_empty() else "clean"


func _has(rep: Dictionary, code: String) -> bool:
	for d in rep.get("defects", []):
		if d["code"] == code:
			return true
	return false


func _count(rep: Dictionary, code: String) -> int:
	var n := 0
	for d in rep.get("defects", []):
		if d["code"] == code:
			n += 1
	return n


## The audit reports `code` for this planted screen.
func _blind(t, name: String, rep: Dictionary, code: String, why := "") -> bool:
	var ok := _has(rep, code)
	t.check("blind_" + name, ok, ("reported %s" % code) if ok else ("BLIND: %s was NOT reported (got: %s) %s" % [code, _codes(rep), why]))
	return ok


## The audit says nothing about this conforming screen.
func _ok(t, name: String, rep: Dictionary, detail := "") -> bool:
	var ok := bool(rep.get("ok", false)) and (rep.get("defects", []) as Array).is_empty()
	t.check("ok_" + name, ok, ("clean " + detail) if ok else ("FALSE POSITIVE: %s" % UiAudit.summary(rep)))
	if not ok:
		for l in UiAudit.lines(rep, 8):
			t.info("    " + l)
	return ok


func _tidy_modals(t) -> void:
	for m in _gm.call("modal_stack"):
		_gm.call("pop_modal", m)
	t.tree.paused = false


# ---------------------------------------------------------------------------------------------------- A: reachable only by the mouse

func _noop_input(_e: InputEvent) -> void:
	pass


func _a_mouse_only(t) -> void:
	var b := await _base(t)
	_ok(t, "base_focusable", UiAudit.focusable_report(b["root"], GAME_FOCUS))
	_ok(t, "base_walk", await UiAudit.focus_walk(t, b["root"], 300))
	await _drop(t, b["host"])
	# A1: a custom control that handles the mouse in _input (not _gui_input)
	b = await _base(t)
	var c1 := Control.new()
	c1.name = "CardClickedInInput"
	c1.set_script(_script("extends Control\nfunc _ready():\n\tcustom_minimum_size = Vector2(200, 48)\n\tmouse_filter = Control.MOUSE_FILTER_STOP\nfunc _input(event):\n\tif event is InputEventMouseButton and event.pressed and get_global_rect().has_point(event.position):\n\t\tprint('clicked')\n"))
	b["vbox"].add_child(c1)
	await t.frames(3)
	_blind(t, "mouse_only_input_handler", UiAudit.focusable_report(b["root"], GAME_FOCUS), "mouse_only_clickable", "(a Control that reads mouse buttons in _input)")
	await _drop(t, b["host"])
	# A2: a ColorRect with a gui_input signal connected to a method of a scripted object
	b = await _base(t)
	var c2 := ColorRect.new()
	c2.name = "SwatchClick"
	c2.color = C.PARCHMENT
	c2.custom_minimum_size = Vector2(200, 48)
	c2.mouse_filter = Control.MOUSE_FILTER_STOP
	c2.gui_input.connect(_noop_input)
	b["vbox"].add_child(c2)
	await t.frames(3)
	_blind(t, "mouse_only_signal_to_scripted_object", UiAudit.focusable_report(b["root"], GAME_FOCUS), "mouse_only_clickable")
	await _drop(t, b["host"])
	# A3: a Control whose own script connects its own gui_input to a handler (no _gui_input override)
	b = await _base(t)
	var c3 := Control.new()
	c3.name = "SelfConnected"
	c3.set_script(_script("extends Control\nfunc _ready():\n\tcustom_minimum_size = Vector2(200, 48)\n\tmouse_filter = Control.MOUSE_FILTER_STOP\n\tgui_input.connect(_on_gui)\nfunc _on_gui(_e):\n\tpass\n"))
	b["vbox"].add_child(c3)
	await t.frames(3)
	_blind(t, "mouse_only_self_connected_signal", UiAudit.focusable_report(b["root"], GAME_FOCUS), "mouse_only_clickable", "(a Control that connects its OWN gui_input signal)")
	await _drop(t, b["host"])
	# A4: a script that only READS the mouse bindings (the ability slot shows "Venstre klik") is not a click handler
	b = await _base(t)
	var c4 := Control.new()
	c4.name = "BindingReader"
	c4.set_script(_script("extends Control\nfunc _ready():\n\tcustom_minimum_size = Vector2(200, 48)\n\tmouse_filter = Control.MOUSE_FILTER_STOP\nfunc key_text(a):\n\tfor e in InputMap.action_get_events(a):\n\t\tif e is InputEventMouseButton:\n\t\t\treturn 'mouse'\n\treturn ''\n"))
	b["vbox"].add_child(c4)
	var ab: Control = ABILITY.instantiate()
	b["vbox"].add_child(ab)
	await t.frames(3)
	_ok(t, "mouse_binding_reader_and_the_real_ability_slot_are_not_click_handlers", UiAudit.focusable_report(b["root"], GAME_FOCUS))
	await _drop(t, b["host"])
	# A5: a Button the keyboard cannot reach through its neighbours is reported by the walk (a trap or unreachable)
	b = await _base(t, 4)
	var bs: Array = b["buttons"]
	bs[0].focus_neighbor_bottom = bs[0].get_path_to(bs[2])
	for side in ["top", "bottom", "left", "right"]:
		bs[1].set("focus_neighbor_" + side, bs[1].get_path_to(bs[1]))
	bs[0].grab_focus()
	await t.frames(3)
	var w4 := await UiAudit.focus_walk(t, b["root"], 300)
	t.check("blind_button_skipped_by_neighbour_wiring", _has(w4, "unreachable") or _has(w4, "only_via_tab") or _has(w4, "trap"), "a button whose every directional neighbour is itself: %s" % _codes(w4))
	await _drop(t, b["host"])


# ---------------------------------------------------------------------------------------------------- B: radio tabs

## A shop-like screen: PillTab radio tabs (select-on-focus when `select_on_focus`) with a page behind each. `broken` makes the SECOND page full of defects.
func _pill_screen(t, tabs_n: int, select_on_focus: bool, broken: bool) -> Dictionary:
	var host := _host(t)
	var root := Control.new()
	root.name = "Screen"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(root)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelParchmentL"
	panel.position = Vector2(300, 30)
	panel.custom_minimum_size = Vector2(640, 0)
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	margin.add_child(vb)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	vb.add_child(tabs)
	var group := ButtonGroup.new()
	var tab_btns: Array[Button] = []
	var pages: Array[VBoxContainer] = []
	for i in tabs_n:
		var tb := Button.new()
		tb.name = "Tab%d" % i
		tb.text = ["SHOP_TAB_SEEDS", "SHOP_TAB_TOOLS", "SHOP_TAB_GOODS"][i]
		tb.theme_type_variation = &"PillTab"
		tb.toggle_mode = true
		tb.button_group = group
		tb.custom_minimum_size = Vector2(120, 36)
		tabs.add_child(tb)
		tab_btns.append(tb)
	for i in tabs_n:
		var page := VBoxContainer.new()
		page.name = "Page%d" % i
		vb.add_child(page)
		pages.append(page)
		for j in 2:
			var b := Button.new()
			b.name = "P%dB%d" % [i, j]
			b.text = "MENU_CONTINUE" if j == 0 else "MENU_QUIT"
			b.theme_type_variation = &"RowButton"
			b.custom_minimum_size = Vector2(0, 52)
			page.add_child(b)
		page.visible = i == 0
	if broken:
		(pages[1].get_node("P1B0") as Button).focus_mode = Control.FOCUS_NONE
		var red := Label.new()
		red.name = "Danger"
		red.text = "INV_TITLE"
		red.add_theme_color_override("font_color", Color("#d62828"))
		pages[1].add_child(red)
		var gold := ColorRect.new()
		gold.name = "GoldBar"
		gold.color = C.GOLD
		gold.custom_minimum_size = Vector2(0, 8)
		pages[1].add_child(gold)
	tab_btns[0].button_pressed = true
	for i in tabs_n:
		var idx := i
		var show := func() -> void:
			for k in pages.size():
				pages[k].visible = k == idx
		tab_btns[i].toggled.connect(func(on: bool) -> void:
			if on:
				show.call())
		if select_on_focus:
			tab_btns[i].focus_entered.connect(func() -> void: tab_btns[idx].button_pressed = true)
			tab_btns[i].focus_neighbor_bottom = tab_btns[i].get_path_to(pages[i].get_node("P%dB0" % i))
			pages[i].get_node("P%dB0" % i).focus_neighbor_top = pages[i].get_node("P%dB0" % i).get_path_to(tab_btns[i])
	await t.frames(3)
	tab_btns[0].grab_focus()
	await t.frames(2)
	return {"host": host, "root": root, "tabs": tab_btns, "pages": pages}


func _b_radio_tabs(t) -> void:
	# B0: the spec's pattern T (select on focus), three pages: conforming, every page walked, the selection restored
	var rs := await _pill_screen(t, 3, true, false)
	var rw := await UiAudit.focus_walk(t, rs["root"], 0)
	_ok(t, "radio_tabs_select_on_focus_walk", rw, "(%d of %d reached, %d presses)" % [int(rw["reached"]), int(rw["expected"]), int(rw["steps"])])
	t.check("ok_radio_tabs_all_nine_controls_reached", int(rw["expected"]) == 9 and int(rw["reached"]) == 9 and (rw["pages"] as Array).size() == 3, "3 tabs + 3 pages x 2 rows: %d of %d, pages %s" % [int(rw["reached"]), int(rw["expected"]), str((rw["pages"] as Array).map(func(p): return p["label"]))])
	t.check("ok_radio_tabs_selection_restored", (rs["tabs"][0] as Button).button_pressed and (rs["pages"][0] as Control).visible and not (rs["pages"][1] as Control).visible, "the walk leaves the first tab selected and its page open")
	_ok(t, "radio_tabs_select_on_focus_focusable", await UiAudit.focusable_report_pages(t, rs["root"], GAME_FOCUS))
	await _drop(t, rs["host"])
	# B1: the shop-style radio tabs whose SECOND page is full of defects (unfocusable button, red label, gold bar): invisible while the first tab is open
	var s := await _pill_screen(t, 2, false, true)
	var walk := await UiAudit.focus_walk(t, s["root"], 400)
	var foc := await UiAudit.focusable_report_pages(t, s["root"], GAME_FOCUS)
	var rules := await UiAudit.rule_report_pages(t, s["root"])
	var open_foc := UiAudit.focusable_report(s["root"], GAME_FOCUS)
	var open_rules := UiAudit.rule_report(s["root"])
	t.check("ok_radio_tab_other_page_is_invisible_to_the_single_page_reports", open_foc["ok"] and open_rules["ok"], "the plain reports only see the open page (%s / %s): the page-aware ones are what finds the rest" % [_codes(open_foc), _codes(open_rules)])
	_blind(t, "radio_tab_other_page_unfocusable_button", foc, "unfocusable_interactive")
	_blind(t, "radio_tab_other_page_red_label", rules, "r4_red")
	_blind(t, "radio_tab_other_page_gold_bar", rules, "r2_gold_decoration")
	_blind(t, "radio_tab_other_page_walk_unreachable", walk, "unreachable")
	var first_page_label := ""
	for d in rules["defects"]:
		if d["code"] == "r4_red":
			first_page_label = str(d.get("page", ""))
	t.check("blind_radio_tab_defects_name_their_page", first_page_label.contains("Tab1"), "the defect of the second page carries page = '%s'" % first_page_label)
	t.check("blind_radio_tab_walk_restored_the_selection", (s["tabs"][0] as Button).button_pressed and (s["pages"][0] as Control).visible, "after visiting the second page the screen is on its first tab again")
	# the same defects are found once the tab is opened by hand: the checks themselves work
	(s["tabs"][1] as Button).button_pressed = true
	await t.frames(3)
	_blind(t, "radio_tab_defects_visible_when_open_rules", UiAudit.rule_report(s["root"]), "r4_red")
	await _drop(t, s["host"])
	# B2: a stock TabContainer whose tab bar cannot take focus
	var host := _host(t)
	var tc := TabContainer.new()
	tc.position = Vector2(300, 100)
	tc.custom_minimum_size = Vector2(600, 320)
	host.add_child(tc)
	for pg in 2:
		var v := VBoxContainer.new()
		v.name = "Pg%d" % pg
		tc.add_child(v)
		var bt := Button.new()
		bt.name = "X%d" % pg
		bt.text = "MENU_CONTINUE"
		bt.theme_type_variation = &"ButtonPrimary"
		bt.custom_minimum_size = Vector2(0, 52)
		v.add_child(bt)
	tc.set_tab_title(0, "SHOP_TAB_SEEDS")
	tc.set_tab_title(1, "SHOP_TAB_TOOLS")
	await t.frames(3)
	var tb := tc.get_tab_bar()
	tb.focus_mode = Control.FOCUS_NONE
	var rep_bad := UiAudit.focusable_report(host, GAME_FOCUS)
	var walk_bad := await UiAudit.focus_walk(t, host, 200)
	t.check("blind_tabcontainer_tabbar_without_focus", _has(rep_bad, "unfocusable_interactive") or _has(walk_bad, "tab_keys_dead"), "tab bar focus NONE: focusable %s / walk %s" % [_codes(rep_bad), _codes(walk_bad)])
	await _drop(t, host)
	# B3: an explicit tab group (options.tab_groups) for buttons that are not in a ButtonGroup
	var eg := await _base(t, 2)
	var plain_a: Button = eg["buttons"][0]
	var plain_b: Button = eg["buttons"][1]
	plain_a.toggle_mode = true
	plain_b.toggle_mode = true
	var groups := UiAudit.radio_groups(eg["root"], {"tab_groups": [[str(eg["root"].get_path_to(plain_a)), str(eg["root"].get_path_to(plain_b)), "Nowhere"]]})
	t.check("radio_groups_explicit_set", groups.size() == 1 and (groups[0]["members"] as Array).size() == 2, "options.tab_groups names two buttons that no ButtonGroup describes: %d group(s)" % groups.size())
	await _drop(t, eg["host"])


# ---------------------------------------------------------------------------------------------------- C: text fields

class SubmitCounter extends Node:
	var submitted := 0

	func on_submit(_t: String) -> void:
		submitted += 1


func _c_text_fields(t) -> void:
	for spec in [["space", KEY_SPACE], ["tab", KEY_TAB], ["shift", KEY_SHIFT], ["backspace", KEY_BACKSPACE], ["ctrl", KEY_CTRL]]:
		var b := await _base(t)
		var le := LineEdit.new()
		le.name = "Name"
		le.placeholder_text = "CHAR_NAME_CAPTION"
		le.custom_minimum_size = Vector2(0, 48)
		b["vbox"].add_child(le)
		var leaker := Node.new()
		leaker.name = "Leaker"
		leaker.set_script(_script("extends Node\nvar key := 0\nfunc _input(event):\n\tif event is InputEventKey and event.pressed and event.keycode == key:\n\t\tget_node('/root/GameManager').push_modal(&'review_leak')\n"))
		leaker.set("key", spec[1])
		b["host"].add_child(leaker)
		await t.frames(3)
		le.grab_focus()
		await t.frames(2)
		var rep := await UiAudit.text_field_audit(t, b["root"])
		var bound := UiAudit._hotkey_specials(false).has(spec[1])
		if bound:
			_blind(t, "text_field_leaks_%s_hotkey" % spec[0], rep, "typing_leaks_hotkey", "(a _input handler on %s while the field has focus)" % spec[0])
		else:
			t.check("blind_text_field_%s_is_not_bound_in_this_project" % spec[0], not _has(rep, "typing_leaks_hotkey"), "%s is bound to no world action here, so typing it cannot leak (%s)" % [spec[0], _codes(rep)])
		_tidy_modals(t)
		await _drop(t, b["host"])
	t.check("text_field_specials_cover_the_bound_keys", UiAudit._hotkey_specials(false).has(KEY_SPACE) and UiAudit._hotkey_specials(false).has(KEY_TAB) and UiAudit._hotkey_specials(false).has(KEY_SHIFT) and not UiAudit._hotkey_specials(false).has(KEY_ENTER) and UiAudit._hotkey_specials(true).has(KEY_ENTER), "Space, Tab and Shift are bound by the project; Enter only with press_enter: %s / %s" % [str(UiAudit._hotkey_specials(false)), str(UiAudit._hotkey_specials(true))])
	# Enter submits a field and the screen may act on it: it is NOT pressed by default, and a leak is found when it is requested
	var b2 := await _base(t)
	var le2 := LineEdit.new()
	le2.name = "Name"
	le2.custom_minimum_size = Vector2(0, 48)
	var counter := SubmitCounter.new()
	b2["host"].add_child(counter)
	le2.text_submitted.connect(counter.on_submit)
	b2["vbox"].add_child(le2)
	var enter_leaker := Node.new()
	enter_leaker.set_script(_script("extends Node\nfunc _input(event):\n\tif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:\n\t\tget_node('/root/GameManager').push_modal(&'review_enter')\n"))
	b2["host"].add_child(enter_leaker)
	await t.frames(3)
	le2.grab_focus()
	await t.frames(2)
	var rep_default := await UiAudit.text_field_audit(t, b2["root"])
	t.check("ok_text_field_enter_is_not_pressed_by_default", counter.submitted == 0 and not _has(rep_default, "typing_leaks_hotkey") and (rep_default["notes"] as Array).any(func(n): return str(n["msg"]).contains("Enter was not pressed")), "no submit happened (%d), the note says why" % counter.submitted)
	_tidy_modals(t)
	le2.grab_focus()
	await t.frames(2)
	var rep_enter := await UiAudit.text_field_audit(t, b2["root"], {"press_enter": true})
	_blind(t, "text_field_leaks_enter_hotkey_on_request", rep_enter, "typing_leaks_hotkey")
	t.check("text_field_press_enter_really_submits", counter.submitted >= 1, "options.press_enter pressed Enter (%d submits)" % counter.submitted)
	_tidy_modals(t)
	await _drop(t, b2["host"])
	# a TextEdit is a field too
	var b3 := await _base(t)
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(0, 80)
	b3["vbox"].add_child(te)
	var leaker2 := Node.new()
	leaker2.set_script(_script("extends Node\nfunc _input(event):\n\tif event is InputEventKey and event.pressed and event.keycode == KEY_I:\n\t\tget_node('/root/GameManager').push_modal(&'review_leak2')\n"))
	b3["host"].add_child(leaker2)
	await t.frames(3)
	te.grab_focus()
	await t.frames(2)
	var rep_te := await UiAudit.text_field_audit(t, b3["root"])
	_blind(t, "text_edit_leaks_a_letter_hotkey", rep_te, "typing_leaks_hotkey")
	t.check("blind_text_edit_text_is_restored", te.text == "", "the audit puts the field's text back ('%s')" % te.text)
	_tidy_modals(t)
	await _drop(t, b3["host"])
	# a read-only field is not typed into
	var b4 := await _base(t)
	var ro := LineEdit.new()
	ro.editable = false
	ro.custom_minimum_size = Vector2(0, 48)
	b4["vbox"].add_child(ro)
	await t.frames(3)
	var rep_ro := await UiAudit.text_field_audit(t, b4["root"])
	t.check("ok_read_only_field_has_nothing_to_type_into", int(rep_ro["fields"]) == 0 and int(rep_ro["keys_tested"]) == 0, "%d field(s), %d keys" % [rep_ro["fields"], rep_ro["keys_tested"]])
	await _drop(t, b4["host"])


# ---------------------------------------------------------------------------------------------------- D: gold

func _gold_case(t, name: String, build: Callable, code := "r2_gold_decoration") -> void:
	var b := await _base(t)
	build.call(b["vbox"])
	await t.frames(3)
	_blind(t, name, UiAudit.rule_report(b["root"], {"rules": ["r4" if code == "r4_red" else "r2"]}), code)
	await _drop(t, b["host"])


func _d_gold(t) -> void:
	# D1: a custom Control that DRAWS a gold rectangle in _draw: only the source scan can see it
	await _gold_case(t, "gold_drawn_in_draw", func(vb: Control) -> void:
		var d1 := Control.new()
		d1.name = "GoldStripeDraw"
		d1.set_script(_script("extends Control\nfunc _ready():\n\tcustom_minimum_size = Vector2(0, 10)\nfunc _draw():\n\tdraw_rect(Rect2(Vector2.ZERO, size), Color('#e3c372'))\n"))
		vb.add_child(d1))
	await _gold_case(t, "gold_constant_named_in_a_script", func(vb: Control) -> void:
		var d2 := Control.new()
		d2.name = "GoldByConstant"
		d2.set_script(_script("extends Control\nconst GOLD := Color(0.89, 0.76, 0.45)\nfunc _draw():\n\tdraw_rect(Rect2(Vector2.ZERO, size), GOLD)\n"))
		vb.add_child(d2))
	await _gold_case(t, "gold_hover_hex_in_a_script", func(vb: Control) -> void:
		var d3 := Control.new()
		d3.set_script(_script("extends Control\nfunc _draw():\n\tdraw_rect(Rect2(Vector2.ZERO, size), Color(\"#ECD189\"))\n"))
		vb.add_child(d3))
	# a script that names GOLD_DARK, mentions the hex in a comment or sits in the allow-list is NOT a gold decoration
	var b := await _base(t)
	var quiet := Control.new()
	quiet.name = "QuietScript"
	quiet.set_script(_script("extends Control\n# gold is e3c372 - this is a comment about it\nconst GOLD_DARK := Color(0.65, 0.47, 0.12)\nfunc _draw():\n\tdraw_rect(Rect2(Vector2.ZERO, size), GOLD_DARK) # no GOLD here\n"))
	b["vbox"].add_child(quiet)
	await t.frames(3)
	_ok(t, "gold_dark_comments_and_trailing_comments_are_not_hits", UiAudit.rule_report(b["root"], {"rules": ["r2"]}))
	var ladder := Control.new()
	ladder.set_script(load("res://scripts/ui/components/ladder_row.gd"))                   # (a draw-only component that paints its own gold: on the allow-list)
	b["vbox"].add_child(ladder)
	await t.frames(2)
	_ok(t, "gold_draw_allow_list_ladder_row", UiAudit.rule_report(b["root"], {"rules": ["r2"]}), "(the draw-only LadderRow paints its next-step chip itself)")
	var tagged := Control.new()
	tagged.set_script(_script("extends Control\nfunc _draw():\n\tdraw_rect(Rect2(Vector2.ZERO, size), Color('#e3c372'))\n"))
	tagged.set_meta(&"tt_gold_ok", "the selected ring of a draw-only component")
	b["vbox"].add_child(tagged)
	await t.frames(2)
	var ok_meta := UiAudit.rule_report(b["root"], {"rules": ["r2"]})
	_ok(t, "gold_source_scan_meta_exemption", ok_meta, "(meta tt_gold_ok on the node that runs the script)")
	tagged.remove_meta(&"tt_gold_ok")
	_blind(t, "gold_source_scan_without_the_meta", UiAudit.rule_report(b["root"], {"rules": ["r2"]}), "r2_gold_decoration")
	_ok(t, "gold_source_scan_option_off", UiAudit.rule_report(b["root"], {"rules": ["r2"], "gold_source": false}), "(options.gold_source = false keeps only the node scan)")
	var hits := Rules.gold_source_hits(b["root"])
	t.check("gold_source_hits_name_file_and_line", hits.size() == 1 and int(hits[0]["line"]) == 3 and str(hits[0]["file"]).contains("runtime script"), "one hit with its line: %s" % str(hits))
	await _drop(t, b["host"])
	# D2: a gold HSeparator through a StyleBoxLine override, and a theme that paints separators gold
	await _gold_case(t, "gold_separator_stylebox_line", func(vb: Control) -> void:
		var sep := HSeparator.new()
		sep.name = "GoldRule"
		var line := StyleBoxLine.new()
		line.color = C.GOLD
		line.thickness = 4
		sep.add_theme_stylebox_override("separator", line)
		vb.add_child(sep))
	await _gold_case(t, "gold_separator_from_a_theme_resource", func(vb: Control) -> void:
		var sep2 := HSeparator.new()
		var th0 := Theme.new()
		var line2 := StyleBoxLine.new()
		line2.color = C.GOLD
		th0.set_stylebox("separator", "HSeparator", line2)
		sep2.theme = th0
		vb.add_child(sep2))
	await _gold_case(t, "gold_tinted_texture_box", func(vb: Control) -> void:
		var pn := PanelContainer.new()
		var tex := StyleBoxTexture.new()
		tex.modulate_color = C.GOLD
		pn.add_theme_stylebox_override("panel", tex)
		pn.custom_minimum_size = Vector2(0, 20)
		vb.add_child(pn))
	# D3: gold text through a Theme resource on a plain label (not a per-node override), a button and a rich text
	await _gold_case(t, "gold_text_from_a_theme_resource", func(vb: Control) -> void:
		var gl := Label.new()
		gl.text = "INV_TITLE"
		var th := Theme.new()
		th.set_color("font_color", "Label", C.GOLD)
		gl.theme = th
		vb.add_child(gl))
	await _gold_case(t, "gold_button_text_from_a_theme_resource", func(vb: Control) -> void:
		var gb := Button.new()
		gb.text = "UI_YES"
		gb.theme_type_variation = &"ButtonTertiary"
		var thb := Theme.new()
		thb.set_color("font_color", "Button", C.GOLD)
		gb.theme = thb
		gb.custom_minimum_size = Vector2(0, 52)
		vb.add_child(gb))
	await _gold_case(t, "gold_rich_text_default_colour_from_a_theme_resource", func(vb: Control) -> void:
		var rt := RichTextLabel.new()
		rt.fit_content = true
		rt.text = "INV_TITLE"
		var thr := Theme.new()
		thr.set_color("default_color", "RichTextLabel", C.GOLD)
		rt.theme = thr
		vb.add_child(rt))
	# D4: TextureProgressBar tints
	for prop in ["tint_progress", "tint_under", "tint_over"]:
		await _gold_case(t, "gold_texture_progress_%s" % prop, func(vb: Control) -> void:
			var tp := TextureProgressBar.new()
			tp.custom_minimum_size = Vector2(200, 12)
			tp.set(prop, C.GOLD)
			vb.add_child(tp))
		await _gold_case(t, "red_texture_progress_%s" % prop, func(vb: Control) -> void:
			var tr := TextureProgressBar.new()
			tr.custom_minimum_size = Vector2(200, 12)
			tr.set(prop, Color("#d62828"))
			vb.add_child(tr), "r4_red")
	# D5: a gold rectangle one colour step off (hand-typed hex) is caught; a panel that is gold through a theme is caught
	await _gold_case(t, "gold_near_miss_one_step", func(vb: Control) -> void:
		var cr := ColorRect.new()
		cr.color = Color("#e4c373")
		cr.custom_minimum_size = Vector2(0, 8)
		vb.add_child(cr))
	await _gold_case(t, "gold_panel_by_theme", func(vb: Control) -> void:
		var gp := PanelContainer.new()
		var th2 := Theme.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = C.GOLD
		sb.set_border_width_all(2)
		sb.border_color = C.INK
		th2.set_stylebox("panel", "PanelContainer", sb)
		gp.theme = th2
		gp.custom_minimum_size = Vector2(0, 30)
		vb.add_child(gp))
	# the guide's own gold: a Bold15Gold label ("guldagern") and a toggled-on gold style are NOT decoration
	var g2 := await _base(t)
	var em := Label.new()
	em.text = "INV_TITLE"
	em.theme_type_variation = &"Bold15Gold"
	g2["vbox"].add_child(em)
	await t.frames(3)
	_ok(t, "gold_ornament_label_bold15gold", UiAudit.rule_report(g2["root"], {"rules": ["r2"]}))
	await _drop(t, g2["host"])


# ---------------------------------------------------------------------------------------------------- E: grids

func _grid_screen(t, cols: int, count: int, wire: String) -> Dictionary:
	var host := _host(t)
	var root := Control.new()
	root.name = "Screen"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(root)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelParchment"
	panel.position = Vector2(20, 20)
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	margin.add_child(grid)
	var slots: Array[Button] = []
	for i in count:
		var s: Button = ITEM_SLOT.instantiate()
		s.name = "S%d" % i
		s.custom_minimum_size = Vector2(66, 66)
		grid.add_child(s)
		s.setup(&"carrot", i + 1)
		slots.append(s)
	await t.frames(3)
	var rows := int(ceil(float(count) / float(cols)))
	if wire == "h" or wire == "vh":
		for r in rows:
			var first := r * cols
			var last := mini(first + cols, count) - 1
			slots[first].focus_neighbor_left = slots[first].get_path_to(slots[last])
			slots[last].focus_neighbor_right = slots[last].get_path_to(slots[first])
	if wire == "v" or wire == "vh":
		for c in cols:
			var top := c
			var bottom := c
			while bottom + cols < count:
				bottom += cols
			slots[top].focus_neighbor_top = slots[top].get_path_to(slots[bottom])
			slots[bottom].focus_neighbor_bottom = slots[bottom].get_path_to(slots[top])
	slots[0].grab_focus()
	await t.frames(2)
	return {"host": host, "root": root, "slots": slots}


func _e_grids(t) -> void:
	var g := await _grid_screen(t, 4, 12, "")
	_blind(t, "grid_no_wrap", await UiAudit.focus_walk(t, g["root"], 400, {"wrap": "required", "wrap_axes": "vh"}), "dead_end")
	await _drop(t, g["host"])
	g = await _grid_screen(t, 4, 12, "h")
	var rep: Dictionary = await UiAudit.focus_walk(t, g["root"], 400, {"wrap": "required", "wrap_axes": "vh"})
	var v_dead := (rep["dead_ends"] as Array).filter(func(d): return d["dir"] in ["up", "down"]).size()
	var h_dead := (rep["dead_ends"] as Array).filter(func(d): return d["dir"] in ["left", "right"]).size()
	t.check("blind_grid_wraps_h_only", v_dead == 8 and h_dead == 0, "horizontal ring present, vertical missing: %d vertical / %d horizontal dead ends (want 8 / 0)" % [v_dead, h_dead])
	await _drop(t, g["host"])
	g = await _grid_screen(t, 4, 12, "vh")
	_ok(t, "grid_full_wrap", await UiAudit.focus_walk(t, g["root"], 400, {"wrap": "required", "wrap_axes": "vh"}))
	await _drop(t, g["host"])
	# the ragged last row: 10 cells in 4 columns, wrapped per row and per column: the wrap-around of a short column goes "the other way" and is legitimate
	g = await _grid_screen(t, 4, 10, "vh")
	_ok(t, "grid_ragged_wrapped", await UiAudit.focus_walk(t, g["root"], 400, {"wrap": "required", "wrap_axes": "vh"}), "(10 cells / 4 columns, row and column wrap wired)")
	await _drop(t, g["host"])
	g = await _grid_screen(t, 4, 10, "")
	_ok(t, "grid_ragged_plain", await UiAudit.focus_walk(t, g["root"], 400), "(Godot's own neighbours)")
	await _drop(t, g["host"])
	# but a REAL wrong way in the same band is still reported: ui_down from a slot jumps to the slot ABOVE it while a slot lies below it in its column
	g = await _grid_screen(t, 4, 12, "")
	var sl: Array = g["slots"]
	sl[5].focus_neighbor_bottom = sl[5].get_path_to(sl[1])
	var wrong := await UiAudit.focus_walk(t, g["root"], 400)
	_blind(t, "grid_down_that_goes_up_in_the_same_column", wrong, "nav_geometry")
	await _drop(t, g["host"])
	# the default budget scales with the screen: a 56-slot screen (backpack + chest + hotbar) is walked completely
	g = await _grid_screen(t, 8, 56, "")
	var big := await UiAudit.focus_walk(t, g["root"])
	_ok(t, "grid_56_slots_default_budget", big, "(%d of %d reached, %d presses)" % [int(big["reached"]), int(big["expected"]), int(big["steps"])])
	t.check("ok_grid_56_slots_not_truncated", not bool(big["truncated"]) and int(big["reached"]) == 56 and int(big["steps"]) > 200, "%d of %d reached in %d presses (the old fixed budget of 200 truncated at 53)" % [int(big["reached"]), int(big["expected"]), int(big["steps"])])
	var small := await UiAudit.focus_walk(t, g["root"], 200)
	_blind(t, "grid_56_slots_explicit_200_is_truncated", small, "walk_truncated")
	t.check("auto_steps_scales", UiAudit.auto_steps(0) == 200 and UiAudit.auto_steps(10) == 200 and UiAudit.auto_steps(56) == 508 and UiAudit.auto_steps(10000) == 4000, "auto_steps: 8 per control + 60, at least 200, at most 4000 (%d, %d, %d)" % [UiAudit.auto_steps(10), UiAudit.auto_steps(56), UiAudit.auto_steps(10000)])
	await _drop(t, g["host"])


# ---------------------------------------------------------------------------------------------------- F: modals

## Two stacked modals. defect: "" (conforming) | "wrong_panel" (the stack entry of the TOP modal is popped but the panel of the BOTTOM modal is freed) | "fade" (the pop
## happens after `fade_s` seconds, like a closing animation) | "focus_to_base" (focus jumps to the base screen's button) | "rebuild" (conforming, but the base screen rebuilds its
## opener) | "bottom_first" (Esc closes the BOTTOM layer)
class TwoModals extends Control:
	var defect := ""
	var fade_s := 0.2
	var base_button: Button
	var panels: Array[PanelContainer] = []
	var names: Array[StringName] = []
	var openers: Array[Control] = []

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		process_mode = Node.PROCESS_MODE_ALWAYS
		base_button = Button.new()
		base_button.name = "Base"
		base_button.text = "MENU_SETTINGS"
		base_button.theme_type_variation = &"ButtonPrimary"
		base_button.custom_minimum_size = Vector2(260, 52)
		base_button.position = Vector2(60, 60)
		add_child(base_button)
		base_button.grab_focus()

	func open_level(level: int) -> void:
		var opener := get_viewport().gui_get_focus_owner()
		var p := PanelContainer.new()
		p.name = "Modal%d" % level
		p.theme_type_variation = &"PanelParchment"
		p.position = Vector2(300 + 60 * level, 120 + 40 * level)
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		var v := VBoxContainer.new()
		var next := Button.new()
		next.name = "Next"
		next.text = "UI_YES"
		next.theme_type_variation = &"ButtonPrimary"
		next.custom_minimum_size = Vector2(240, 52)
		v.add_child(next)
		p.add_child(v)
		add_child(p)
		panels.append(p)
		openers.append(opener)
		var nm := StringName("review_modal_%d" % level)
		names.append(nm)
		get_node("/root/GameManager").push_modal(nm)
		next.grab_focus()

	func _input(event: InputEvent) -> void:
		if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")) or names.is_empty():
			return
		get_viewport().set_input_as_handled()
		match defect:
			"wrong_panel":
				get_node("/root/GameManager").pop_modal(names.pop_back())
				openers.pop_back()
				var gone := panels[0]
				panels.remove_at(0)
				gone.queue_free()
			"fade":
				var nm: StringName = names.pop_back()
				var pnl: PanelContainer = panels.pop_back()
				var opener: Control = openers.pop_back()
				var tw := create_tween()
				tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				tw.tween_property(pnl, "modulate:a", 0.0, fade_s)
				tw.tween_callback(func() -> void:
					get_node("/root/GameManager").pop_modal(nm)
					pnl.queue_free()
					if opener != null and is_instance_valid(opener):
						opener.grab_focus())
			"rebuild":
				get_node("/root/GameManager").pop_modal(names.pop_back())
				panels.pop_back().queue_free()
				var old: Control = openers.pop_back()
				if old != null and is_instance_valid(old) and old.get_parent() == self and old == base_button:
					var nb := Button.new()
					nb.name = "Base"
					nb.text = "MENU_SETTINGS"
					nb.theme_type_variation = &"ButtonPrimary"
					nb.custom_minimum_size = Vector2(260, 52)
					nb.position = Vector2(60, 60)
					old.queue_free()
					add_child(nb)
					base_button = nb
					nb.grab_focus.call_deferred()
				elif old != null and is_instance_valid(old):
					old.grab_focus()
			"bottom_first":
				get_node("/root/GameManager").pop_modal(names.pop_front())
				panels.pop_front().queue_free()
				openers.pop_front()
			"focus_to_base":
				get_node("/root/GameManager").pop_modal(names.pop_back())
				panels.pop_back().queue_free()
				openers.pop_back()
				base_button.grab_focus()
			_:
				get_node("/root/GameManager").pop_modal(names.pop_back())
				panels.pop_back().queue_free()
				var o: Control = openers.pop_back()
				if o != null and is_instance_valid(o):
					o.grab_focus()


func _chain(t, defect: String, options := {}, fade_s := 0.2) -> Dictionary:
	var phase0: Variant = _gm.get("current_phase")
	var host := _host(t)
	var m := TwoModals.new()
	m.defect = defect
	m.fade_s = fade_s
	host.add_child(m)
	await t.frames(3)
	var rep: Dictionary = await UiAudit.escape_chain(t, func(level: int) -> void: m.open_level(level), 2, options)
	var left := (_gm.call("modal_stack") as Array).size()
	rep["_modal_stack_left"] = left
	_tidy_modals(t)
	_gm.call("change_phase", phase0)
	await _drop(t, host)
	return rep


func _f_modals(t) -> void:
	var good := await _chain(t, "")
	_ok(t, "two_modals_conforming", good)
	# the base screen rebuilds its opener while the layer closes (an ordinary list refresh): this used to die with a SCRIPT ERROR and return an empty Dictionary
	var rebuild := await _chain(t, "rebuild")
	t.check("ok_two_modals_rebuild_does_not_crash", not rebuild.is_empty() and rebuild.has("defects"), "the chain returned a report (keys %s)" % str(rebuild.keys()))
	_ok(t, "two_modals_rebuild", rebuild)
	t.check("ok_two_modals_rebuild_notes_the_unchecked_focus", (rebuild.get("notes", []) as Array).any(func(n): return str(n["msg"]).contains("no longer exists")), "the freed opener is a NOTE (options.expect_focus checks it), not a crash and not a defect")
	_blind(t, "two_modals_bottom_first", await _chain(t, "bottom_first"), "esc_wrong_order")
	var wrong := await _chain(t, "wrong_panel")
	t.check("blind_two_modals_wrong_panel_does_not_crash", not wrong.is_empty() and wrong.has("defects"), "the chain returned a report")
	_blind(t, "two_modals_wrong_panel", wrong, "focus_not_restored")
	_blind(t, "two_modals_focus_to_base", await _chain(t, "focus_to_base"), "focus_not_restored")
	# a layer that fades out before it pops: real time, not a frame count
	_ok(t, "two_modals_fade_within_the_default_settle_seconds", await _chain(t, "fade", {}, 0.1), "(0.1 s fade, default 0.25 s)")
	_blind(t, "two_modals_fade_longer_than_the_default", await _chain(t, "fade", {}, 0.6), "esc_does_not_close")
	_ok(t, "two_modals_fade_with_settle_seconds", await _chain(t, "fade", {"settle_seconds": 1.2}, 0.6), "(0.6 s fade, options.settle_seconds 1.2)")
	_blind(t, "two_modals_settle_seconds_zero_is_frames_only", await _chain(t, "fade", {"settle_seconds": 0.0}, 0.1), "esc_does_not_close")
	var started := Time.get_ticks_msec()
	_ok(t, "two_modals_conforming_does_not_wait_for_the_timeout", await _chain(t, "", {"settle_seconds": 5.0}))
	t.check("two_modals_settle_returns_as_soon_as_the_stack_moves", Time.get_ticks_msec() - started < 3000, "a conforming chain with settle_seconds 5 took %d ms" % (Time.get_ticks_msec() - started))
	# a modal that reads Esc in _unhandled_input while a LineEdit has focus (the field eats it)
	for spec in [["unhandled", false, false], ["input", true, true]]:
		var host := _host(t)
		var m := FieldModal.new()
		m.read_in_input = spec[1]
		host.add_child(m)
		await t.frames(3)
		var rep: Dictionary = await UiAudit.escape_chain(t, func(level: int) -> void: m.open_level(level), 1)
		if spec[2]:
			_ok(t, "field_modal_reads_esc_in_input", rep)
		else:
			_blind(t, "field_modal_reads_esc_in_unhandled", rep, "esc_does_not_close")
		_tidy_modals(t)
		await _drop(t, host)
	# Esc does nothing (esc_depth 0): the audit PRESSES it
	var b := await _base(t)
	var esc_node := Node.new()
	esc_node.set_script(_script("extends Node\nfunc _input(event):\n\tif event.is_action_pressed('pause'):\n\t\tget_node('/root/GameManager').push_modal(&'review_pause')\n"))
	b["host"].add_child(esc_node)
	await t.frames(3)
	var phase0: Variant = _gm.get("current_phase")
	var rep_zero: Dictionary = await UiAudit.escape_chain(t, Callable(), 0, {"pre_opened": true, "base_stack": [], "base_paused": false})
	_blind(t, "esc_depth_zero_on_a_screen_that_opens_pause", rep_zero, "esc_opens_modal")
	t.check("blind_esc_depth_zero_cleans_up", (_gm.call("modal_stack") as Array).is_empty() and not t.tree.paused and _gm.get("current_phase") == phase0, "the audit pops what the planted handler pushed, unpauses and keeps the phase")
	_tidy_modals(t)
	await _drop(t, b["host"])
	var inert := await _base(t)
	var rep_inert: Dictionary = await UiAudit.escape_chain(t, Callable(), 0, {"pre_opened": true, "base_stack": [], "base_paused": false})
	_ok(t, "esc_depth_zero_on_a_screen_that_ignores_esc", rep_inert)
	t.check("esc_depth_zero_records_the_press", (rep_inert["steps"] as Array).size() == 1 and (rep_inert["steps"] as Array)[0]["press"] == "key", "one recorded press: %s" % str(rep_inert["steps"]))
	for via in ["pad_b", "start", "action", "pause"]:
		var rv: Dictionary = await UiAudit.escape_chain(t, Callable(), 0, {"pre_opened": true, "base_stack": [], "base_paused": false, "via": via})
		_ok(t, "esc_depth_zero_via_%s" % via, rv)
	await _drop(t, inert["host"])


class FieldModal extends Control:
	var read_in_input := false
	var layer: PanelContainer
	var field: LineEdit
	var opener: Control
	var base_button: Button

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		process_mode = Node.PROCESS_MODE_ALWAYS
		base_button = Button.new()
		base_button.name = "Base"
		base_button.text = "MENU_SETTINGS"
		base_button.theme_type_variation = &"ButtonPrimary"
		base_button.custom_minimum_size = Vector2(260, 52)
		base_button.position = Vector2(60, 60)
		add_child(base_button)
		base_button.grab_focus()

	func open_level(_level: int) -> void:
		opener = get_viewport().gui_get_focus_owner()
		layer = PanelContainer.new()
		layer.theme_type_variation = &"PanelParchment"
		layer.position = Vector2(300, 120)
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		var v := VBoxContainer.new()
		field = LineEdit.new()
		field.name = "Field"
		field.custom_minimum_size = Vector2(240, 48)
		field.gui_input.connect(_swallow)
		v.add_child(field)
		var ok := Button.new()
		ok.text = "UI_YES"
		ok.theme_type_variation = &"ButtonPrimary"
		ok.custom_minimum_size = Vector2(240, 52)
		v.add_child(ok)
		layer.add_child(v)
		add_child(layer)
		get_node("/root/GameManager").push_modal(&"review_field_modal")
		field.grab_focus()

	func _swallow(event: InputEvent) -> void:
		if event.is_pressed() and (event.is_action("ui_cancel") or event.is_action("pause")):
			field.accept_event()                      # "Esc clears / leaves the field": the text field keeps the key

	func _close() -> void:
		get_node("/root/GameManager").pop_modal(&"review_field_modal")
		layer.queue_free()
		layer = null
		if opener != null and is_instance_valid(opener):
			opener.grab_focus()

	func _input(event: InputEvent) -> void:
		if read_in_input and layer != null and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
			get_viewport().set_input_as_handled()
			_close()

	func _unhandled_input(event: InputEvent) -> void:
		if not read_in_input and layer != null and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
			get_viewport().set_input_as_handled()
			_close()


# ---------------------------------------------------------------------------------------------------- G: the keyboard

func _g_keyboard(t) -> void:
	# a Button with focus_mode FOCUS_ACCESSIBILITY (screen readers only): the keyboard cannot reach it
	var b := await _base(t)
	var acc := Button.new()
	acc.name = "AccessibilityOnly"
	acc.text = "UI_YES"
	acc.theme_type_variation = &"ButtonPrimary"
	acc.custom_minimum_size = Vector2(0, 52)
	acc.focus_mode = Control.FOCUS_ACCESSIBILITY
	b["vbox"].add_child(acc)
	await t.frames(3)
	var rep_acc := UiAudit.focusable_report(b["root"], GAME_FOCUS)
	_blind(t, "focus_accessibility_only_button", rep_acc, "unfocusable_interactive")
	t.check("blind_focus_accessibility_message_names_the_mode", (rep_acc["defects"] as Array).any(func(d): return str(d["msg"]).contains("focus_mode %d" % Control.FOCUS_ACCESSIBILITY)), "the message says which focus mode it found")
	await _drop(t, b["host"])
	# a dialog that is created when a button is pressed does not exist in the tree at open time: the script scan sees it
	b = await _base(t)
	var opener: Button = b["buttons"][0]
	opener.set_script(_script("extends Button\nfunc _ready():\n\tpressed.connect(_open)\nfunc _open():\n\tvar d := ConfirmationDialog.new()\n\td.dialog_text = 'INV_TITLE'\n\tget_parent().add_child(d)\n\td.popup_centered()\n"))
	await t.frames(3)
	var before := UiAudit.focusable_report(b["root"], GAME_FOCUS)
	_blind(t, "lazy_window_dialog_seen_before_it_exists", before, "window_in_screen")
	t.check("blind_lazy_window_is_listed_in_windows", (before["windows"] as Array).size() >= 1, "the report lists it in `windows`: %s" % str(before["windows"]))
	var allowed := UiAudit.focusable_report(b["root"], {"forbid_windows": false})
	t.check("ok_lazy_window_only_matters_for_game_screens", not _has(allowed, "window_in_screen"), "forbid_windows false: %s" % _codes(allowed))
	await _drop(t, b["host"])
	for spec in [["option_button", "var o := OptionButton.new()"], ["popup_menu", "var o := PopupMenu.new()"], ["accept_dialog", "var o := AcceptDialog.new()"], ["popup_call", "var o = get_viewport()\n\to.popup_centered()"]]:
		b = await _base(t)
		var n := Control.new()
		n.name = "Maker"
		n.set_script(_script("extends Control\nfunc make():\n\t%s\n" % spec[1]))
		b["vbox"].add_child(n)
		await t.frames(2)
		_blind(t, "lazy_window_%s" % spec[0], UiAudit.focusable_report(b["root"], GAME_FOCUS), "window_in_screen")
		await _drop(t, b["host"])
	b = await _base(t)
	var commented := Control.new()
	commented.set_script(_script("extends Control\n# ConfirmationDialog.new() is banned: use UiConfirm\nfunc ok():\n\tvar x := 1 # Window.new() would be wrong\n"))
	b["vbox"].add_child(commented)
	await t.frames(2)
	_ok(t, "lazy_window_comments_are_not_hits", UiAudit.focusable_report(b["root"], GAME_FOCUS))
	await _drop(t, b["host"])
	# a CanvasLayer root (the HUD / modal pattern)
	var host := _host(t)
	var layer := CanvasLayer.new()
	host.add_child(layer)
	var ctl := Control.new()
	ctl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ctl)
	var bt := Button.new()
	bt.text = "MENU_CONTINUE"
	bt.theme_type_variation = &"ButtonPrimary"
	bt.custom_minimum_size = Vector2(240, 52)
	ctl.add_child(bt)
	await t.frames(3)
	bt.grab_focus()
	await t.frames(2)
	_ok(t, "canvaslayer_root_focusable", UiAudit.focusable_report(layer, GAME_FOCUS))
	_ok(t, "canvaslayer_root_initial", UiAudit.initial_focus_report(layer))
	_ok(t, "canvaslayer_root_walk", await UiAudit.focus_walk(t, layer, 100))
	await _drop(t, host)
	# determinism: two walks of the same screen give the same JSON, and the locale is what it was
	b = await _base(t, 4)
	var w1 := await UiAudit.focus_walk(t, b["root"], 300)
	b["buttons"][0].grab_focus()
	await t.frames(2)
	var w2 := await UiAudit.focus_walk(t, b["root"], 300)
	t.check("walk_is_deterministic", JSON.stringify(w1) == JSON.stringify(w2), "two walks of the same screen give the same JSON")
	t.check("walk_leaves_the_locale", TranslationServer.get_locale().begins_with("da"), "locale after the walk: %s" % TranslationServer.get_locale())
	await _drop(t, b["host"])


# ---------------------------------------------------------------------------------------------------- H: hit targets

## A bare interactive control of an exact height: a Button with an empty `normal` style (the theme's padding would make every button taller than the number under test).
func _target(parent: Node, name: String, variation: StringName, w: float, h: float) -> Button:
	var bt := Button.new()
	bt.name = name
	bt.text = ""
	bt.theme_type_variation = variation
	bt.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	bt.custom_minimum_size = Vector2(w, h)
	bt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(bt)
	return bt


func _hits(root: Node, options := {}) -> Array:
	var o := {"rules": ["hit_targets"]}
	o.merge(options)
	return (UiAudit.rule_report(root, o)["defects"] as Array).map(func(d): return str(d["path"]).get_file())


func _h_hit_targets(t) -> void:
	var b := await _base(t)
	_target(b["vbox"], "Edge31", &"", 120.0, 31.0)
	_target(b["vbox"], "Edge32", &"", 120.0, 32.0)
	_target(b["vbox"], "Wide31", &"", 31.0, 60.0)
	_target(b["vbox"], "Wide32", &"", 32.0, 60.0)
	await t.frames(3)
	var named := _hits(b["root"])
	t.check("hit_target_edge_32", named.has("Edge31") and not named.has("Edge32") and named.has("Wide31") and not named.has("Wide32"), "31 px fails, 32 px passes, in height and in width: %s" % str(named))
	t.check("hit_target_option_hit_min_lowers_the_floor", not _hits(b["root"], {"hit_min": 28.0}).has("Edge31"), "options.hit_min 28 lets the 31 px control pass")
	t.check("hit_target_option_hit_min_raises_the_floor", _hits(b["root"], {"hit_min": 40.0}).has("Edge32"), "options.hit_min 40 fails the 32 px control")
	var msg_ok := (UiAudit.rule_report(b["root"], {"rules": ["hit_targets"]})["defects"] as Array).any(func(d): return str(d["msg"]).contains("minimum hit target is 32 px"))
	t.check("hit_target_message_names_the_minimum", msg_ok, "the defect says 32 px")
	await _drop(t, b["host"])
	# the guide's two tag plates keep a 20 px floor (HintButton ~20 px, VersionButton ~24 px); a PillTab and a Chip do not
	b = await _base(t)
	for spec in [["HintButton", 19.0], ["HintButton", 20.0], ["VersionButton", 20.0], ["VersionButton", 24.0], ["PillTab", 24.0], ["Chip", 31.0], ["Chip", 32.0]]:
		_target(b["vbox"], "%s%d" % [spec[0], int(spec[1])], StringName(spec[0]), 120.0, spec[1])
	await t.frames(3)
	var names2 := _hits(b["root"])
	t.check("hit_target_tag_plates_have_a_20px_floor", names2.has("HintButton19") and not names2.has("HintButton20") and names2.has("PillTab24") and names2.has("Chip31") and not names2.has("Chip32") and not names2.has("VersionButton20") and not names2.has("VersionButton24"), "19 px HintButton fails, 20 passes, VersionButton 20 / 24 pass, a 24 px PillTab and a 31 px Chip fail, a 32 px Chip passes: %s" % str(names2))
	t.check("hit_target_floor_follows_a_lowered_hit_min", not _hits(b["root"], {"hit_min": 10.0}).has("HintButton19"), "with hit_min 10 the floor of the tag plates is min(20, hit_min)")
	await _drop(t, b["host"])
	# a mouse-ignored decoration and a control without a size are not targets; a scaled control is measured at its drawn size
	b = await _base(t)
	var passive := _target(b["vbox"], "Passive", &"", 30.0, 30.0)
	passive.mouse_filter = Control.MOUSE_FILTER_IGNORE
	passive.focus_mode = Control.FOCUS_NONE
	var focusable_ignore := _target(b["vbox"], "FocusableIgnore", &"", 30.0, 30.0)
	focusable_ignore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clickable_nofocus := _target(b["vbox"], "ClickableNoFocus", &"", 30.0, 30.0)
	clickable_nofocus.focus_mode = Control.FOCUS_NONE
	var big := _target(b["root"], "Big", &"", 40.0, 40.0)                       # (a container resets the scale of its children: this one sits directly under the screen root)
	big.position = Vector2(20, 600)
	big.scale = Vector2(0.5, 0.5)
	var meta_ok := _target(b["vbox"], "MetaOk", &"", 30.0, 30.0)
	meta_ok.set_meta(&"tt_hit_ok", "a decoration")
	await t.frames(3)
	var names3 := _hits(b["root"])
	t.check("hit_target_mouse_ignored_and_unfocusable_is_not_a_target", not names3.has("Passive") and names3.has("FocusableIgnore") and names3.has("ClickableNoFocus"), "only a control that ignores the mouse AND cannot take focus is exempt: %s" % str(names3))
	t.check("hit_target_is_measured_at_the_drawn_size", names3.has("Big"), "a 40 px button scaled by 0.5 is a 20 px target: %s" % str(names3))
	t.check("hit_target_meta_exemption", not names3.has("MetaOk"), "meta tt_hit_ok exempts a control")
	await _drop(t, b["host"])


# ---------------------------------------------------------------------------------------------------- I: the registry routes (Esc does nothing with several vias, a screen that opens Pause on Esc)

func _i_registry_routes(t) -> void:
	UiAudit.use_registry(FIXTURE_REGISTRY)
	var sp1 := Spy.new(t)
	var r1 := await UiAudit.audit_screen(sp1, "fx_esc_inert_vias")
	t.check("registry_esc_depth_zero_vias_all_pass", r1["ok"] and sp1.failed_checks().is_empty() and sp1.checks().any(func(c): return c["name"] == "fx_esc_inert_vias.escape" and c["ok"]), "Esc, gamepad B and Start do nothing on a conforming screen: %s" % str(sp1.failed_checks()))
	var rep_vias: Dictionary = (r1["checks"] as Dictionary).get("escape", {})
	t.check("registry_esc_depth_zero_vias_press_three_times", (rep_vias.get("steps", []) as Array).size() == 3, "one recorded press per via: %s" % str((rep_vias.get("steps", []) as Array).map(func(s): return s["press"])))
	var sp2 := Spy.new(t)
	var r2 := await UiAudit.audit_screen(sp2, "fx_esc_opens_pause")
	var esc_rep: Dictionary = (r2["checks"] as Dictionary).get("escape", {})
	t.check("blind_registry_esc_depth_zero_row_that_opens_pause", sp2.failed_checks() == ["fx_esc_opens_pause.escape"] and _has(esc_rep, "esc_opens_modal"), "a title that opens Pause on Esc fails its row: %s / %s" % [str(sp2.failed_checks()), _codes(esc_rep)])
	t.check("blind_registry_esc_depth_zero_row_cleans_up", (_gm.call("modal_stack") as Array).is_empty() and not t.tree.paused, "the modal the planted screen pushed is gone")
	_tidy_modals(t)
	var sp3 := Spy.new(t)
	var r3 := await UiAudit.audit_screen(sp3, "fx_pages_row")
	t.check("registry_row_audits_the_pages_behind_its_tabs", not r3["ok"] and sp3.failed_checks().has("fx_pages_row.focusable") and sp3.failed_checks().has("fx_pages_row.rules"), "a live row whose second tab page is full of defects fails focusable and rules: %s" % str(sp3.failed_checks()))
	var sp4 := Spy.new(t)
	await UiAudit.audit_screen(sp4, "fx_pages_row", {"options": {"pages": false}})
	t.check("registry_row_option_pages_false_audits_only_the_open_page", sp4.failed_checks().is_empty(), "options.pages = false: %s" % str(sp4.failed_checks()))
	UiAudit.use_registry("")


## Records what audit_screen asks of the harness without touching its counters (the same spy as ui_audit.gd).
class Spy extends RefCounted:
	var real
	var root: Window
	var tree: SceneTree
	var log: Array[Dictionary] = []

	func _init(p_real) -> void:
		real = p_real
		root = p_real.root
		tree = p_real.tree

	func frames(n: int) -> void:
		await real.frames(n)

	func has_window() -> bool:
		return real.has_window()

	func move_mouse(pos: Vector2) -> void:
		real.move_mouse(pos)

	func click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
		real.click(pos, button)

	func capture(shot := "") -> Image:
		return await real.capture(shot)

	func check(name: String, cond: Variant, detail: Variant = "") -> bool:
		log.append({"kind": "check", "name": name, "ok": bool(cond), "detail": str(detail)})
		return bool(cond)

	func skip(label: Variant) -> void:
		log.append({"kind": "skip", "label": str(label)})

	func info(msg: Variant) -> void:
		log.append({"kind": "info", "msg": str(msg)})

	func fail(label: Variant) -> void:
		log.append({"kind": "fail", "label": str(label)})

	func checks() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for e in log:
			if e["kind"] == "check":
				out.append(e)
		return out

	func failed_checks() -> Array[String]:
		var out: Array[String] = []
		for e in log:
			if e["kind"] == "check" and not e["ok"]:
				out.append(str(e["name"]))
		return out


# ---------------------------------------------------------------------------------------------------- windowed: the ring in real layouts, and the slider

func run_windowed(t) -> void:
	await t.clear_scene()
	TranslationServer.set_locale("da")
	# W1: the first button of a clipping ScrollContainer: its ring is cut off by the container's edge on up to three sides
	var host := _host(t)
	var bg := ColorRect.new()
	bg.color = Color("#efe9df")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.position = Vector2(300, 100)
	sc.size = Vector2(300, 400)
	sc.clip_contents = true
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	var btns: Array[Button] = []
	for i in 4:
		var b := Button.new()
		b.name = "B%d" % i
		b.text = "MENU_CONTINUE"
		b.theme_type_variation = &"ButtonPrimary"
		b.custom_minimum_size = Vector2(0, 56)
		vb.add_child(b)
		btns.append(b)
	await t.frames(4)
	var rep: Dictionary = await UiAudit.ring_pixels(t, btns[0], {"shot": "blind_ring_clipped_first_row"})
	_blind(t, "ring_clipped_by_scroll_container", rep, "ring_missing")
	# (the list has no side margin: EVERY row's ring is cut off at the left and right edge of the container, not only the first row's)
	var rep2: Dictionary = await UiAudit.ring_pixels(t, btns[2], {"shot": "blind_ring_inner_row"})
	_blind(t, "ring_clipped_at_the_sides_for_every_row_of_a_marginless_list", rep2, "ring_missing")
	t.check("blind_ring_inner_row_keeps_top_and_bottom", int(rep2.get("gold_samples", 0)) == 4 and int(rep2.get("focused_hits", 9)) == 2, "an inner row loses its left and right sides only: gold %s of %s" % [rep2.get("focused_hits"), rep2.get("gold_samples")])
	# W2: the same list with a side margin: only the TOP of the first row's ring is clipped (used to pass with 'gold_hits >= n - 1')
	host.queue_free()
	await t.frames(3)
	host = _host(t)
	var bgm := ColorRect.new()
	bgm.color = Color("#efe9df")
	bgm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bgm)
	var scm := ScrollContainer.new()
	scm.position = Vector2(300, 100)
	scm.size = Vector2(340, 400)
	scm.clip_contents = true
	scm.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(scm)
	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_theme_constant_override("margin_left", 16)
	mc.add_theme_constant_override("margin_right", 16)
	mc.add_theme_constant_override("margin_bottom", 16)
	scm.add_child(mc)
	var vbm := VBoxContainer.new()
	mc.add_child(vbm)
	var first_btn: Button = null
	for i in 3:
		var b2 := Button.new()
		b2.name = "M%d" % i
		b2.text = "MENU_CONTINUE"
		b2.theme_type_variation = &"ButtonPrimary"
		b2.custom_minimum_size = Vector2(0, 56)
		vbm.add_child(b2)
		if first_btn == null:
			first_btn = b2
	await t.frames(4)
	var repm: Dictionary = await UiAudit.ring_pixels(t, first_btn, {"shot": "blind_ring_top_clipped_only"})
	# the gold band is still there above the first row, the ink band outside it is cut off by the container: ring_ink_missing (the old tolerance of one missing side let it pass)
	_blind(t, "ring_clipped_on_one_side", repm, "ring_ink_missing")
	t.check("blind_ring_clipped_on_one_side_counts_every_sample", int(repm.get("gold_samples", 0)) == 4 and int(repm.get("focused_hits", 0)) == 4 and int(repm.get("ink_samples", 0)) == 4 and int(repm.get("ink_hits", 9)) == 3, "gold %s of %s, ink %s of %s (the top ink band is cut off)" % [repm.get("focused_hits"), repm.get("gold_samples"), repm.get("ink_hits"), repm.get("ink_samples")])
	var repm_inner: Dictionary = await UiAudit.ring_pixels(t, vbm.get_child(1) as Control, {"shot": "blind_ring_inner_row_with_margin"})
	_ok(t, "ring_inner_row_of_a_list_with_side_margins", repm_inner, "(the second row has all four sides)")
	var repm2: Dictionary = await UiAudit.ring_pixels(t, first_btn, {"shot": "blind_ring_top_allowed", "allow_missing_sides": 1})
	_ok(t, "ring_allow_missing_sides_option", repm2, "(options.allow_missing_sides = 1 for a deliberate edge case)")
	# W3: a ring of the right colour covered on two sides by opaque siblings
	host.queue_free()
	await t.frames(3)
	host = _host(t)
	var bg2 := ColorRect.new()
	bg2.color = Color("#efe9df")
	bg2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg2)
	var fb := Button.new()
	fb.name = "Focused"
	fb.text = "MENU_CONTINUE"
	fb.theme_type_variation = &"ButtonPrimary"
	fb.position = Vector2(400, 300)
	fb.custom_minimum_size = Vector2(240, 56)
	host.add_child(fb)
	for spec in [[Vector2(380, 340), Vector2(300, 60)], [Vector2(300, 280), Vector2(110, 120)]]:
		var cover := ColorRect.new()
		cover.color = Color("#efe9df")
		cover.position = spec[0]
		cover.size = spec[1]
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(cover)
	await t.frames(4)
	_blind(t, "ring_covered_on_two_sides", await UiAudit.ring_pixels(t, fb, {"shot": "blind_ring_covered"}), "ring_missing")
	host.queue_free()
	await t.frames(3)
	# W4: an UNFOCUSED control that shows a gold frame on three of its four sides is still "always on" (a frame cut off on one side is a frame)
	host = _host(t)
	var bg4 := ColorRect.new()
	bg4.color = Color("#efe9df")
	bg4.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg4)
	for spec in [[Vector2(388, 288), Vector2(264, 24)], [Vector2(388, 300), Vector2(24, 56)], [Vector2(628, 300), Vector2(24, 56)]]:       # drawn first: the button covers the part under it
		var bar := ColorRect.new()
		bar.color = C.GOLD
		bar.position = spec[0]
		bar.size = spec[1]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(bar)
	var half := Button.new()
	half.name = "Half"
	half.text = "MENU_CONTINUE"
	half.theme_type_variation = &"ButtonPrimary"
	half.position = Vector2(400, 300)
	half.custom_minimum_size = Vector2(240, 56)
	host.add_child(half)
	await t.frames(4)
	var half_rep: Dictionary = await UiAudit.ring_pixels(t, half, {"shot": "blind_half_frame", "focus": false, "expect": "none"})
	_blind(t, "ring_always_on_with_one_side_missing", half_rep, "ring_always_on")
	t.check("blind_ring_always_on_counts_three_of_four", int(half_rep.get("gold_samples", 0)) == 4 and int(half_rep.get("focused_hits", 0)) == 3, "three gold sides drawn, the bottom is not: gold %s of %s" % [half_rep.get("focused_hits"), half_rep.get("gold_samples")])
	host.queue_free()
	await t.frames(3)
	# I: Godot's HSlider never draws its theme `focus` StyleBox: a plain slider shows no ring even when the theme HAS one (the finding behind TTSlider)
	host = _host(t)
	var bg3 := ColorRect.new()
	bg3.color = Color("#efe9df")
	bg3.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg3)
	var plain := HSlider.new()
	plain.name = "Plain"
	plain.position = Vector2(300, 200)
	plain.custom_minimum_size = Vector2(400, 48)
	plain.size = Vector2(400, 48)
	var th := Theme.new()
	var ring_sb: StyleBox = ThemeDB.get_project_theme().get_stylebox("focus", "Button")
	th.set_stylebox("focus", "HSlider", ring_sb)
	plain.theme = th
	host.add_child(plain)
	var ringed := load("res://tests/fixtures/ui_audit/ring_slider.gd").new() as HSlider
	ringed.name = "Ringed"
	ringed.position = Vector2(300, 320)
	ringed.custom_minimum_size = Vector2(400, 48)
	ringed.size = Vector2(400, 48)
	host.add_child(ringed)
	await t.frames(4)
	t.check("slider_theme_focus_entry_is_present_but_a_plain_slider_has_no_ring_verdict", plain.has_theme_stylebox("focus") and UiAudit.focusable_report(host)["defects"].any(func(d): return d["code"] == "no_focus_style" and str(d["path"]).ends_with("Plain")), "a theme that defines HSlider/focus does NOT make the audit accept a plain HSlider: %s" % UiAudit.summary(UiAudit.focusable_report(host)))
	var plain_ring: Dictionary = await UiAudit.ring_pixels(t, plain, {"shot": "blind_plain_slider_with_theme_focus", "style": ring_sb})
	_blind(t, "plain_slider_shows_no_ring_even_with_a_theme_focus_style", plain_ring, "ring_missing")
	var ringed_ring: Dictionary = await UiAudit.ring_pixels(t, ringed, {"shot": "blind_painting_slider"})
	_ok(t, "painting_slider_shows_the_ring", ringed_ring, "(a slider that paints the style itself and declares it with tt_focus_style)")
	host.queue_free()
	await t.frames(3)
