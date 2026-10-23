extends RefCounted
## Section ui_audit (package: UI conformance audit library, plan 5.4 / R.14): proves tests/lib/ui_audit.gd (class UiAudit), the registry
## tests/lib/ui_screens.json and the planted-defect fixtures of tests/fixtures/ui_audit. It is ALSO the place that runs the audit over the screens
## of the registry (the foundation gallery today; the legacy title / select as visible KNOWN-GAP lines; every later screen as SKIP until its package flips it).
##
## WHAT THE AUDIT CHECKS ("does the menu / navigation follow the style guide?"), one stable defect code per finding (UiAudit.DEFECTS):
##   focus      initial_focus (the screen grabs focus by itself), focusable (every button / field / slider can take keyboard focus and shows the gold ring),
##              focus_walk (real ui_down/right/up/left presses: every control reachable, no trap, no focus loss, lists, grids, tab bars, sliders, text fields,
##              ui_accept), text_fields (typing never fires a hotkey), escape (Esc closes the TOP modal, focus returns to the opener, the game unpauses)
##   rules      R1 ink outline 2 px, R2 gold only on focus / selected, R3 numbers in Caprasimo, R4 no red, typography (Caprasimo >= 20, Alegreya >= 18),
##              copy (raw keys, hard-coded literals, text that does not change with the language), hit targets >= 32 px (20 px for the HintButton / VersionButton tag plates)
##   mouse      mouse_walk: hovering a control never takes keyboard focus (only list-like rows do), a click never drops it
##   windowed   ring_pixels (the gold ring + its ink band, or a gold fill, is really in the frame, with a negative control), panel_pixels (parchment / ink 2 / gold 4 /
##              ink 2 edge), button_pixels (ink border, face, band, ink border, 4 px underside) - run_windowed below
## Every code has a NEGATIVE test here: a planted fixture (tests/fixtures/ui_audit/screen.gd, modals.gd ...) that the audit must report, and the check
## ui_audit.every_defect_code_has_a_negative_test fails when a new code is added without one.
##
## RECIPE for the package that builds a screen (P16 menus, P17 HUD, P18 shop / backpack, F7 home, F8 wardrobe) - 10 lines:
##  1. Open tests/lib/ui_screens.json and find your screen's row (title, select_1, select_2, pause, hud, shop, inventory, husbyggeri ...: one row per screen of
##     UI_NAVIGATION.md 5.1; it is the same file as ui_screens.proposed.json). The rows have NO status: it is derived (no scene = pending, the old scaffold
##     main_menu / character_select = legacy, a scene = live), so landing your scene is what turns the row live - you edit the row only to add a check or an option.
##     A screen the spec table does not list (the town, social and farm packages: people, gift, calendar, social_hud, event_overlay, post ...) goes into YOUR OWN file
##     tests/lib/ui_screens.d/<name>.json, {"screens": [rows]} with the same row schema: UiAudit.screens() merges the folder (registry file first, then the folder
##     files in file-name order), so nobody edits a file it does not own. A screen id exists once: a duplicate id is a failure (ui_audit.screens_merge_dir_unique_ids).
##  2. Make the screen take focus itself when it opens (grab_focus() on the first ENABLED control, deferred if the layout is not ready); modals push_modal(name)
##     on open, pop_modal(name) on close, close on ui_cancel AND pause (set_input_as_handled), and give focus back to the control that opened them.
##  3. Build with theme variations only (PanelParchment, ButtonPrimary, Display28 ...), every number in Caprasimo, translation keys in the scene, no red,
##     no per-node gold, and a re-label on NOTIFICATION_TRANSLATION_CHANGED for text you set from code.
##  4. Library-shaped rows (the P07 gallery pages, a driver row of your own section) carry "status", "open" ({scene} | {fixture} | {driver, ctx}), "checks" and
##     "options"; a mistyped option name or value fails the row (UiAudit.validate_options) instead of silently switching a requirement off.
##  5. In YOUR section (tests/sections/<name>.gd) call `await UiAudit.audit_screen(t, "<id>")`: it opens the screen, runs every listed check and records
##     named harness checks "<your section>.<id>.<check>" (failures print one line per defect with the node path).
##  6. A screen that needs state (a shop with stock, a full backpack): give the entry a driver script (open(t, host, ctx) -> Node) or register the state with
##     UiFixtures.register_setup and use {"fixture": "shop"}.
##  7. Modals: list "escape": {"depth": N} and give the driver open_level(t, host, level): the audit presses Esc N times and checks order, focus and unpause.
##  8. Radio tabs and chips (PillTab / Chip in a ButtonGroup) are audited page by page automatically (options.pages / max_pages / tab_groups). Fix the SCREEN,
##     never the audit: a finding that is a genuine guide exception goes in "options" (ignore / hit_min / same_ok) or as node meta
##     (tt_audit_ignore, tt_gold_ok, tt_r1_ok, tt_r3_ok, tt_hit_ok, tt_text_same_ok = the reason); every exemption is listed in the report notes.
##  9. HUD screens use "kind": "hud": no control may take focus (plan R.14). Dev samples that must stay unfocusable: set_meta(&"tt_audit_ignore", "reason").
## 10. Windowed (tools/dev/run_windowed.sh --only=<name>): `await UiAudit.ring_pixels(t, control)` proves the gold ring is drawn (with a negative control), panel_pixels /
##     button_pixels the panel edge and the button profile; tests/checkpoints/compare_guide.py proves the look. Own checks: `UiAudit.expect(t, report, "name")`.
##     Spec-shaped registry rows (no status; scene / fixture / focus / esc_depth / kind) work too: the status is derived (no scene = pending, old scaffold = legacy).
## KEYBOARD FACTS this section proves against Godot 4.7.2 (the fixtures show the idiom for each):
##  - a focused LineEdit eats the Esc, Enter and arrow KEYS (they never reach _unhandled_input and the arrows move the caret): a modal with a name field reads
##    ui_cancel / pause in _input (modals.gd, field_focus_ok) and a screen connects field.gui_input and moves focus on ui_up / ui_down (screen.gd, _on_field_input);
##    walks run twice ("action" = gamepad D-pad, "key" = real arrow keys) so a text field the arrows cannot leave is reported (only_via_tab / trap, via = key);
##  - a plain HSlider draws no focus indicator at all, EVEN WHEN THE THEME HAS an HSlider/focus StyleBox (probed in 4.7.2 and looked at in a window:
##    ui_audit_blind run_windowed): use a slider that paints get_theme_stylebox("focus") itself and declares it with the meta tt_focus_style (ring_slider.gd, the
##    spec's TTSlider); without that the audit reports no_focus_style;
##  - focus navigation does not wrap by default and disabled buttons ARE focusable: "wrap": "required" in the entry's options asks for wrap-around, a disabled
##    button is never required to be reachable but must not be the initial focus;
##  - the project theme does not style TabBar / ItemList / Tree: use PillTab buttons (the guide's tabs); a TabBar reports focus_style_not_gold and hit_target_small.
## Exemptions that are the GUIDE's own and not defects: gold from the project theme (panel double edge, gold button, menu row), small guide tokens (Muted13-17, Heavy14-17,
## HotkeyDigit ..., the Caprasimo tokens Display15/16/19 and ButtonTertiaryS; a per-node size override is never exempt; options.strict_typography allows slot counts only),
## mono text, hit targets below 32 px on HintButton / VersionButton (20 px floor), dark plates and scrims without an ink outline, border segments
## (shop footer, journal sidebar). Everything else needs `options` or a node meta that says why. This section clears the booted scene first (a world would answer Esc).
## Evidence of today's problems: `UI_AUDIT_REPORT=/abs/path.txt tests/run_playtest.sh --only=ui_audit` also writes every finding of the legacy screens to that file.
##
## The sister sections: ui_audit_blind (the blind spots of the first version, each pinned by a planted screen) and ui_audit_pins (every threshold and branch of the rule
## scans with values on both sides of the line).
## Named checks: ui_audit.api_surface*, defect_catalog, registry_valid, guards_*, conforming_* (zero false positives on 10 conforming layouts), neg_* (one per planted
## defect), walk_*, escape_* (incl. internal layers, pre-opened rows, world probe), dialog_*, rules_*, registry_* (statuses, derived status of spec-shaped rows, tripwires,
## the merge of tests/lib/ui_screens.d: screens_merge_dir_unique_ids, registry_merge_*, neg_registry_duplicate_* / neg_registry_file_*,
## drivers through a spy), theme_*, mouse_walk_*, rule_report_* (spec groups, locale sweep), scene / script text scans, selftest_*, device_swap_*, reports_are_plain_json_data,
## foundation_gallery*, legacy_*, pending_entries_skip, every_defect_code_has_a_negative_test, fast_enough. Windowed (run_windowed): ring_*, panel_*, button_*, auto_pick*.
const SECTION := "ui_audit"
const TIMEOUT_S := 240.0

const Screen = preload("res://tests/fixtures/ui_audit/screen.gd")
const Modals = preload("res://tests/fixtures/ui_audit/modals.gd")
const FIXTURE_REGISTRY := "res://tests/fixtures/ui_audit/ui_screens_fixture.json"
## what a game screen must satisfy beyond the basics (spec U3): no disabled focus stop, no Window-based control
const GAME_FOCUS := {"forbid_windows": true, "forbid_disabled_focus": true}
const CHECK_NAMES: Array[String] = ["initial_focus", "focusable", "focus_walk", "text_fields", "escape", "rules", "r1", "r2", "r3", "r4", "typography", "overrides", "i18n",
	"hit_targets", "i18n_flip", "theme", "ring", "mouse_walk", "panel_pixels", "button_pixels", "compare_guide"]
const STATUSES: Array[String] = ["live", "pending", "legacy"]
const EnLabel = preload("res://tests/fixtures/ui_audit/en_label.gd")
const NoFocusMode = preload("res://tests/fixtures/ui_audit/no_focus_mode.gd")
const ClosedScreen = preload("res://tests/fixtures/ui_audit/closed_screen.gd")
const BoxStyle = preload("res://scripts/ui/theme/tt_box_style.gd")
const Colors = preload("res://scripts/ui/theme/tt_colors.gd")
const KINDS: Array[String] = ["screen", "modal", "hud", "gallery", "scene", "component", "surface", "fade"]

## [defect planted in tests/fixtures/ui_audit/screen.gd, layout, check, defect code the audit must report]
const NEGATIVES := [
	["nothing_focusable", "menu", "walk", "nothing_focusable"],
	["unfocusable_button", "menu", "focusable", "unfocusable_interactive"],
	["unfocusable_button", "menu", "walk", "unreachable"],
	["click_only", "menu", "focusable", "focus_click_only"],
	["click_only", "menu", "walk", "unreachable"],
	["no_focus_style", "menu", "focusable", "no_focus_style"],
	["focus_blue", "menu", "focusable", "focus_style_not_gold"],
	["slider_no_ring", "menu", "focusable", "no_focus_style"],
	["no_initial_focus", "menu", "initial", "no_initial_focus"],
	["initial_disabled", "menu", "initial", "initial_focus_disabled"],
	["initial_disabled", "menu", "focusable_game", "disabled_focusable"],
	["window_option", "settings", "focusable_game", "window_in_screen"],
	["pad_eats", "menu", "walk", "pad_mismatch"],
	["trap", "menu", "walk", "trap"],
	["field_traps", "menu", "walk", "only_via_tab"],
	["focus_lost", "menu", "walk", "focus_lost"],
	["tab_only", "menu", "walk", "only_via_tab"],
	["slider_eats", "menu", "walk", "slider_ignores_keys"],
	["tab_eats", "tabs", "walk", "tab_keys_dead"],
	["tab_bar_unfocusable", "tabs", "walk", "tab_keys_dead"],
	["tab_bar_unfocusable", "tabs", "focusable", "unfocusable_interactive"],
	["accept_eats", "menu", "walk_accept", "accept_dead"],
	["wrong_way", "menu", "walk", "nav_geometry"],
	["history", "menu", "walk", "walk_replay_mismatch"],
	["mouse_only", "menu", "focusable", "mouse_only_clickable"],
	["hud_focus", "hud", "hud", "hud_focusable"],
	["hud_blocks", "hud", "hud", "hud_blocks_mouse"],
	["field_dead", "menu", "text", "text_field_dead"],
	["hotkey_leak", "menu", "text", "typing_leaks_hotkey"],
	["gold_decoration", "menu", "rules", "r2_gold_decoration"],
	["red_label", "menu", "rules", "r4_red"],
	["number_body", "menu", "rules", "r3_number_not_display"],
	["no_outline", "menu", "rules", "r1_no_ink_outline"],
	["small_display", "menu", "rules", "font_too_small_display"],
	["small_body", "menu", "rules", "font_too_small_body"],
	["raw_key", "menu", "rules", "raw_key"],
	["hit_small", "menu", "rules", "hit_target_small"],
	["literal_flip", "menu", "flip", "not_localized"],
	["stale_label", "menu", "flip", "not_localized"],
	# per-node overrides are a defect of their own (plan 5.1), not only a side effect of the size rules
	["small_display", "menu", "rules", "theme_override"],
	["small_body", "menu", "rules", "theme_override"],
	["red_label", "menu", "rules", "theme_override"],
	# the pages behind radio tabs (PillTab / Chip in a ButtonGroup) are audited, not only the open one
	["radio_page_defects", "radio_tabs", "focusable_pages", "unfocusable_interactive"],
	["radio_page_defects", "radio_tabs", "rules_pages", "r4_red"],
	["radio_page_defects", "radio_tabs", "rules_pages", "r2_gold_decoration"],
	["radio_page_defects", "radio_tabs", "walk", "unreachable"],
	["radio_select_dead", "radio_tabs", "walk", "radio_select_dead"],
]
## [modal defect, code]
const ESCAPE_NEGATIVES := [
	["ignore", "esc_does_not_close"], ["field_focus", "esc_does_not_close"], ["wrong_order", "esc_wrong_order"], ["close_all", "esc_closes_several"], ["no_restore", "focus_not_restored"],
	["leak", "modal_stack_leak"], ["stays_paused", "game_stays_paused"], ["phase_changed", "phase_not_restored"], ["no_push", "opener_depth_mismatch"], ["no_focus", "modal_no_focus"],
	["opens_pause", "esc_opens_modal"],
]

var _seen: Dictionary = {}                    # defect code -> true once a negative test saw the audit report it
var _legacy: Array[Dictionary] = []             # findings of the legacy screens: {screen, check, code, path, msg}
var _t0 := 0


func run(t) -> void:
	_t0 = Time.get_ticks_msec()
	await t.clear_scene()                         # the booted world must not see the Esc / arrow presses of the audit
	TranslationServer.set_locale("da")
	_api_surface(t)
	_registry_valid(t)
	await _registry_merge(t)
	await _guards(t)
	await _conforming(t)
	await _focus_negatives(t)
	await _walk_features(t)
	await _walk_start_features(t)
	await _escape(t)
	await _options_and_pages(t)
	await _dialogs(t)
	await _rules(t)
	await _registry_semantics(t)
	_theme(t)
	await _tools(t)
	await _real_screens(t)
	_coverage(t)
	var ms := Time.get_ticks_msec() - _t0
	var audit_budget := 10000 + UiAudit.screens().size() * 3000
	t.check("fast_enough", t.perf_ok("fast_enough", ms, audit_budget), "the complete audit took %d ms; native reference %d ms, runner limit %d ms (10 s fixtures + 3 s per registered screen, including focus/i18n frame waits)" % [ms,audit_budget,t.perf_limit(audit_budget)])


# ---------------------------------------------------------------------------------------------------- helpers

func _host(t) -> Control:
	t.root.gui_release_focus()
	var host := Control.new()
	host.name = "AuditHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	t.root.add_child(host)
	return host


func _make(t, layout: String, defect := "") -> Control:
	var host := _host(t)
	var s := Screen.new()
	s.layout = layout
	s.defect = defect
	host.add_child(s)
	await t.frames(3)
	return s


func _drop(t, node: Node) -> void:
	var host := node.get_parent()
	if host != null and host.name == "AuditHost":
		host.queue_free()
	else:
		node.queue_free()
	await t.frames(2)


func _has(rep: Dictionary, code: String) -> bool:
	for d in rep.get("defects", []):
		if d["code"] == code:
			return true
	return false


func _neg(t, name: String, rep: Dictionary, code: String) -> bool:
	var ok := _has(rep, code)
	if ok:
		_seen[code] = true
	var detail := "reported %s: %s" % [code, UiAudit.summary(rep)] if ok else "the audit did NOT report %s (got: %s)" % [code, UiAudit.summary(rep)]
	return t.check(name, ok, detail)


func _clean(t, name: String, rep: Dictionary, detail := "") -> bool:
	var ok: bool = bool(rep.get("ok", false)) and (rep.get("defects", []) as Array).is_empty()
	t.check(name, ok, detail if ok and detail != "" else UiAudit.summary(rep))
	if not ok:
		for l in UiAudit.lines(rep, 6):
			t.info("    " + l)
	return ok


func _run_kind(t, kind: String, s: Control) -> Dictionary:
	match kind:
		"initial":
			return UiAudit.initial_focus_report(s)
		"focusable":
			return UiAudit.focusable_report(s)
		"focusable_game":
			return UiAudit.focusable_report(s, GAME_FOCUS)
		"hud":
			return UiAudit.focusable_report(s, {"forbid_focus": true})
		"walk":
			return await UiAudit.focus_walk(t, s, 300)
		"walk_accept":
			return await UiAudit.focus_walk(t, s, 300, {"accept": ["*/Button2"]})
		"text":
			return await UiAudit.text_field_audit(t, s)
		"rules":
			return UiAudit.rule_report(s)
		"rules_pages":
			return await UiAudit.rule_report_pages(t, s)
		"focusable_pages":
			return await UiAudit.focusable_report_pages(t, s, GAME_FOCUS)
		"flip":
			return await UiAudit.locale_flip_report(t, s)
	return {"ok": false, "defects": [{"code": "unknown_kind", "path": kind, "msg": kind}]}


# ---------------------------------------------------------------------------------------------------- API and registry

func _api_surface(t) -> void:
	var methods := {}
	for m in (load("res://tests/lib/ui_audit.gd") as GDScript).get_script_method_list():
		methods[m["name"]] = (m["args"] as Array).map(func(a): return a["name"])
	var want := {
		"focusable_report": ["root"], "focus_walk": ["t", "root", "max_steps"], "initial_focus": ["root"], "escape_chain": ["t", "opener", "expected_depth"],
		"rule_report": ["root"], "ring_pixels": ["t", "control"], "screens": [], "audit_screen": ["t", "id"],
	}
	var bad: Array[String] = []
	for name in want:
		if not methods.has(name):
			bad.append("%s missing" % name)
			continue
		var args: Array = methods[name]
		for i in (want[name] as Array).size():
			if args.size() <= i or args[i] != want[name][i]:
				bad.append("%s argument %d is '%s', the contract says '%s'" % [name, i, args[i] if args.size() > i else "-", want[name][i]])
	t.check("api_surface", bad.is_empty(), "UiAudit has the eight names of the contract with their first arguments %s" % str(bad))
	var extras := {"rule_report_locales": ["t", "root"], "mouse_walk": ["t", "root"], "panel_pixels": ["t", "panel"], "button_pixels": ["t", "button"], "scene_text_report": ["scene_path"],
		"script_text_report": ["script_path"], "expect": ["t", "report", "name"], "open_screen": ["t", "id"], "close_screen": ["t", "id"], "theme_report": ["theme"],
		"initial_focus_report": ["root"], "text_field_audit": ["t", "root"], "locale_flip_report": ["t", "root"], "press_pad": ["t"]}
	var bad2: Array[String] = []
	for name2 in extras:
		if not methods.has(name2):
			bad2.append("%s missing" % name2)
			continue
		var args2: Array = methods[name2]
		for j in (extras[name2] as Array).size():
			if args2.size() <= j or args2[j] != extras[name2][j]:
				bad2.append("%s argument %d" % [name2, j])
	t.check("api_surface_extras", bad2.is_empty(), "the spec's helper tools exist with their documented first arguments %s" % str(bad2))
	var catalog_ok := true
	for code in UiAudit.DEFECTS:
		var entry: Array = UiAudit.DEFECTS[code]
		catalog_ok = catalog_ok and entry.size() == 2 and (str(entry[0]) in CHECK_NAMES or str(entry[0]) in ["registry", "visible", "mouse_walk", "panel_pixels", "button_pixels"])
	t.check("defect_catalog", catalog_ok and UiAudit.DEFECTS.size() >= 40, "%d defect codes, each with a check name and a meaning" % UiAudit.DEFECTS.size())


func _guards(t) -> void:
	var detached := Control.new()
	var bad: Array[Dictionary] = [
		UiAudit.focusable_report(null), UiAudit.focusable_report(detached), UiAudit.rule_report(null), UiAudit.initial_focus_report(null),
		await UiAudit.focus_walk(t, null), await UiAudit.text_field_audit(t, detached), await UiAudit.locale_flip_report(t, null), await UiAudit.ring_pixels(t, null),
	]
	var all_flagged := true
	for rep in bad:
		all_flagged = all_flagged and _has(rep, "no_root") and not rep["ok"]
	_neg(t, "neg_no_root", bad[0], "no_root")
	t.check("guards_null_and_detached", all_flagged and UiAudit.initial_focus(null) == null and UiAudit.initial_focus(detached) == null, "null and detached roots are reported (no_root), never a crash")
	var spy_bad := Spy.new(t)
	var bad_opener := await UiAudit.escape_chain(t, Callable(), 1)
	_neg(t, "neg_escape_invalid_opener", bad_opener, "opener_depth_mismatch")
	var zero := await UiAudit.escape_chain(t, func(_l: int) -> void: pass, 0)
	_clean(t, "escape_depth_zero_is_trivially_clean", zero)
	detached.free()
	var _unused := spy_bad


## The screen table of UI_NAVIGATION.md 5.1 / 7.2 as the registry must carry it: id -> [package, esc_depth]. A screen whose row is missing, or whose Esc depth drifted from the
## spec, is never audited the way the spec says when its package lands (the first library registry carried `select` / `select_page2` instead of select_1 / select_2, saveload 2
## instead of 3, husbyggeri and indretning 1 instead of 2, and no row for confirm, toasts, prompt, area_banner, minimap or intro). `language` and `sleep` have no scene of their own
## and no row (their proofs are named checks).
const SPEC_TABLE := {
	"title": ["P16-ui-menus", 0], "settings": ["P16-ui-menus", 1], "select_1": ["P16-ui-menus", 1], "select_2": ["P16-ui-menus", 2], "saveload": ["P16-ui-menus", 3],
	"pause": ["P16-ui-menus", 1], "confirm": ["P28-ui-nav-foundation", 1], "hud": ["P17-ui-hud", 0], "toasts": ["P28-ui-nav-foundation", 0], "prompt": ["P28-ui-nav-foundation", 0],
	"area_banner": ["P17-ui-hud", 0], "forest_hud": ["P19-forest-combat", 0], "minimap": ["P19-forest-combat", 0], "dialogue": ["P14-npc-dialogue", 1], "intro": ["P14-npc-dialogue", 1],
	"shop": ["P18-ui-shop-inventory", 1], "journal": ["P14-npc-dialogue", 1], "inventory": ["P18-ui-shop-inventory", 1], "animal_care": ["P20-animals-buildings", 1],
	"build_menu": ["P20-animals-buildings", 1], "husbyggeri": ["F7-home-ui", 2], "indretning": ["F7-home-ui", 2], "home_chest": ["F7-home-ui", 1], "garderobe": ["F8-wardrobe-ui", 1],
	"samlerbog": ["F9-collection", 1],
}


func _registry_valid(t) -> void:
	var problems: Array[String] = []
	var ids := {}
	var screens := UiAudit.screens()
	for d in UiAudit.registry_report()["defects"]:
		problems.append("registry files: %s" % str(d["msg"]))        # a duplicate or empty id, a file of tests/lib/ui_screens.d that does not parse
	for s in screens:
		var id := str(s.get("id", ""))
		if id == "" or ids.has(id):
			problems.append("duplicate or empty id '%s'" % id)
		ids[id] = true
		for key in ["status", "package", "kind", "open", "checks"]:
			if not s.has(key):
				problems.append("%s: key '%s' missing" % [id, key])
		var status := str(s.get("status", ""))
		if status not in STATUSES:
			problems.append("%s: status '%s'" % [id, status])
		if str(s.get("kind", "")) not in KINDS:
			problems.append("%s: kind '%s'" % [id, s.get("kind", "")])
		var checks: Array = UiAudit.entry_checks(s)                      # the audit's reading of the row (the spec's API names are aliases of the library's)
		for c in checks:
			if str(c) not in CHECK_NAMES:
				problems.append("%s: unknown check '%s'" % [id, c])
		for c in s.get("checks", []):
			if str(c) not in CHECK_NAMES and str(c) not in UiAudit.CHECK_ALIASES:
				problems.append("%s: check '%s' is neither a library check nor a spec alias" % [id, c])
		for msg in UiAudit.validate_options("registry", s.get("options", {})):
			problems.append("%s: %s" % [id, msg])
		var open: Dictionary = s.get("open", {})
		var routes := 0
		for r in ["scene", "fixture", "driver"]:
			if open.has(r):
				routes += 1
		if routes > 1 or (routes == 0 and status != "pending" and not s.has("tripwire")):
			problems.append("%s: open must name exactly one of scene / fixture / driver (%s)" % [id, str(open)])
		if status == "pending" and routes == 0 and not s.has("tripwire") and str(s.get("scene", "")) == "":
			problems.append("%s: a pending entry with no open route needs a scene or a tripwire file" % id)
		if status != "pending":
			if open.has("scene") and not ResourceLoader.exists(str(open["scene"])):
				problems.append("%s: scene %s does not exist" % [id, open["scene"]])
			if open.has("driver") and not FileAccess.file_exists(str(open["driver"])):
				problems.append("%s: driver %s does not exist" % [id, open["driver"]])
		if status == "live" and s.has("known_gaps"):
			problems.append("%s: a live entry has no known_gaps" % id)
		for gap in s.get("known_gaps", []):
			if not UiAudit.DEFECTS.has(str(gap)):
				problems.append("%s: known gap '%s' is not a defect code" % [id, gap])
		if "escape" in checks:
			var esc: Dictionary = s.get("escape", {})
			var depth := int(esc.get("depth", -1))
			if depth < 0 or (depth < 1 and not esc.has("pre_opened") and not esc.has("vias")):
				problems.append("%s: the escape check needs escape.depth >= 0 (a spec row gets it from esc_depth)" % id)
			if status == "live" and not open.has("driver") and not bool(esc.get("pre_opened", false)):
				problems.append("%s: a live escape check needs a driver with open_level (or a pre-opened spec row)" % id)
			if int(esc.get("depth", 1)) > 0 and (esc.has("vias") and (esc["vias"] as Array).size() > 1):
				problems.append("%s: several escape vias only make sense for an Esc-does-nothing row (esc_depth 0): a closed screen cannot be pressed twice" % id)
		if str(s.get("kind", "")) == "hud" and ("focus_walk" in checks or "initial_focus" in checks):
			problems.append("%s: a hud entry must not walk focus" % id)
	for sid in SPEC_TABLE:
		if not ids.has(sid):
			problems.append("registry has no row '%s' (UI_NAVIGATION.md 5.1)" % sid)
			continue
		var row := UiAudit.screen(sid)
		if str(row.get("package", "")) != SPEC_TABLE[sid][0]:
			problems.append("%s: package is %s, the spec says %s" % [sid, row.get("package", ""), SPEC_TABLE[sid][0]])
		if int(row.get("esc_depth", -99)) != int(SPEC_TABLE[sid][1]):
			problems.append("%s: esc_depth is %s, the spec table says %s" % [sid, row.get("esc_depth", "-"), SPEC_TABLE[sid][1]])
	for extra in ["foundation_gallery", "foundation_gallery_rarity"]:
		if not ids.has(extra):
			problems.append("registry has no row '%s'" % extra)
	for stale in ["select", "select_page2", "language", "sleep"]:
		if ids.has(stale):
			problems.append("row '%s' is not in the spec table (select_1 / select_2 replace select / select_page2; language and sleep have no scene)" % stale)
	if str(UiAudit.screen("title").get("escape", {}).get("vias", [])) != str(["key", "pad_b", "start"]):
		problems.append("title: Esc must do nothing on the title and is proved for the Esc key, gamepad B and gamepad Start (escape.vias)")
	for tw in ["intro", "minimap"]:
		if str(UiAudit.screen(tw).get("tripwire", "")) == "":
			problems.append("%s: a row that is part of another screen's scene needs a tripwire, or it stays pending forever" % tw)
	var live_ok := true
	for n in ["foundation_gallery", "foundation_gallery_rarity"]:
		live_ok = live_ok and str(UiAudit.screen(n).get("status", "")) == "live"
	t.check("registry_valid", problems.is_empty() and live_ok, "%d screens: every row is well formed, validated options, the gallery is live, the table of UI_NAVIGATION.md 5.1 / 7.2 (ids, packages, Esc depths) is carried exactly %s" % [screens.size(), str(problems.slice(0, 6))])
	t.check("registry_screens_api", UiAudit.screens().size() == screens.size() and UiAudit.screens_by_status("live").size() >= 2 and UiAudit.screen("nope").is_empty(), "screens() returns copies, screens_by_status('live'), screen('unknown') is empty")
	# the same rows through a hand-made registry: a typo in an option, an unknown check, a missing row, a drifted depth are all caught (the check is not vacuous)
	var drift := screens.duplicate(true)
	for row in drift:
		if row["id"] == "saveload":
			row["esc_depth"] = 2
		if row["id"] == "settings":
			(row["options"] as Dictionary)["wrap"] = "requierd"
	var caught := 0
	for row in drift:
		if row["id"] == "saveload" and int(row["esc_depth"]) != int(SPEC_TABLE["saveload"][1]):
			caught += 1
		if row["id"] == "settings" and not UiAudit.validate_options("registry", row["options"]).is_empty():
			caught += 1
	t.check("registry_valid_is_not_vacuous", caught == 2, "a drifted esc_depth and a mistyped option are both visible to the checks of registry_valid (%d of 2)" % caught)


# ---------------------------------------------------------------------------------------------------- the registry folder tests/lib/ui_screens.d (RT8)

const MERGE_DIR := "res://tests/fixtures/ui_audit/merge/"


## The ids of every row of one registry file, read here with a JSON parser of its own (the check must not trust the merge it audits).
func _raw_ids(path: String) -> Array[String]:
	var out: Array[String] = []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		out.append("<%s does not parse>" % path)
		return out
	for row in (json.data as Dictionary).get("screens", []):
		out.append(str((row as Dictionary).get("id", "")))
	return out


func _registry_merge(t) -> void:
	# 1. the REAL registry: tests/lib/ui_screens.json + every file of tests/lib/ui_screens.d. A screen id exists once across all of them, no file is broken, and the
	#    merge kept every row (nothing a package registered is silently dropped).
	var files := UiAudit.registry_files()
	var raw: Array[String] = []
	for f in files:
		raw.append_array(_raw_ids(f))
	var seen := {}
	var dups: Array[String] = []
	for id in raw:
		if seen.has(id) or id == "" or id.begins_with("<"):
			dups.append(id)
		seen[id] = true
	var merged_ids := UiAudit.screens().map(func(s: Dictionary) -> String: return str(s["id"]))
	var rep_real := UiAudit.registry_report()
	var folder_files := files.size() - 1
	# 2. the same rules proved against planted registries: a duplicate id across the registry file and a folder file is reported
	UiAudit.use_registry(MERGE_DIR + "dup_across/ui_screens.json")
	var rep_dup := UiAudit.registry_report()
	UiAudit.use_registry("")
	t.check("screens_merge_dir_unique_ids", files.size() >= 1 and files[0] == "res://tests/lib/ui_screens.json" and dups.is_empty() and bool(rep_real["ok"]) and merged_ids.size() == raw.size() and _has(rep_dup, "registry_error"),
		"%d registry file(s) (%d in tests/lib/ui_screens.d), %d rows: every screen id exists once (duplicate / empty / unreadable: %s), the merge kept all %d, and a planted duplicate is reported (%s)" % [files.size(), folder_files, raw.size(), str(dups), merged_ids.size(), UiAudit.summary(rep_dup)])
	t.check("registry_merge_real_rows_know_their_file", files.size() >= 1 and UiAudit.registry_file_of("title") == "res://tests/lib/ui_screens.json" and UiAudit.registry_file_of("nope") == "" and UiAudit.screens().all(func(s: Dictionary) -> bool: return UiAudit.registry_file_of(str(s["id"])) in files),
		"registry_file_of(id) names the file of every merged row of the real registry, '' for an unknown id")

	# 3. the folder is merged after the registry file, in file-name order, rows in file order; non-json files are ignored
	UiAudit.use_registry(MERGE_DIR + "ok/ui_screens.json")
	var ok_ids := UiAudit.screens().map(func(s: Dictionary) -> String: return str(s["id"]))
	t.check("registry_merge_order", ok_ids == ["mg_base", "mg_a1", "mg_b1", "mg_b2"], "registry file first, then a_first.json, then b_second.json (the folder is read by file name, not by creation order): %s" % str(ok_ids))
	t.check("registry_merge_files", UiAudit.registry_files() == [MERGE_DIR + "ok/ui_screens.json", MERGE_DIR + "ok/ui_screens.d/a_first.json", MERGE_DIR + "ok/ui_screens.d/b_second.json"], "the files read, in merge order: %s" % str(UiAudit.registry_files()))
	t.check("registry_merge_ignores_other_files", not ok_ids.has("mg_ignored"), "ui_screens.d/ignored.txt holds a screens object but is not a .json file: not merged")
	t.check("registry_merge_rows_know_their_file", UiAudit.registry_file_of("mg_a1") == MERGE_DIR + "ok/ui_screens.d/a_first.json" and UiAudit.registry_file_of("mg_b2") == MERGE_DIR + "ok/ui_screens.d/b_second.json" and UiAudit.registry_file_of("mg_base") == MERGE_DIR + "ok/ui_screens.json", "registry_file_of names the file a row came from")
	var folder_row := UiAudit.screen("mg_b1")
	t.check("registry_merge_rows_are_normalized_like_the_others", folder_row.get("package", "") == "MG-b" and folder_row.get("status", "") == "pending" and bool(folder_row.get("status_derived", false)) and folder_row.has("options") and folder_row.has("open") and UiAudit.screens_by_status("pending").size() == 4,
		"a row of a folder file is read like a row of the registry file (status derived, options, open): %s" % str(folder_row.get("status", "-")))
	_clean(t, "registry_merge_ok_is_clean", UiAudit.registry_report(), "the planted folder with distinct ids reports no defect")
	var sp_ok := Spy.new(t)
	var r_ok := await UiAudit.audit_screen(sp_ok, "mg_a1")
	t.check("registry_merge_audit_screen_reaches_a_folder_row", r_ok["skipped"] and sp_ok.failed_checks().is_empty() and sp_ok.log.size() == 1 and str(sp_ok.log[0].get("label", "")).contains("pending (MG-a)"), "audit_screen finds a row of a folder file: a pending row is one SKIP line with its package: %s" % str(sp_ok.log))

	# 4. a duplicate id: the first row wins, the second is dropped, and it is a failure (registry_report, audit_screen of the id)
	UiAudit.use_registry(MERGE_DIR + "dup_across/ui_screens.json")
	var d_ids := UiAudit.screens().map(func(s: Dictionary) -> String: return str(s["id"]))
	var d_defects: Array = rep_dup["defects"]
	_neg(t, "neg_registry_duplicate_id_across_files", rep_dup, "registry_error")
	t.check("registry_duplicate_is_named_with_its_files", d_defects.size() == 1 and str(d_defects[0]["path"]) == "mg_x" and str(d_defects[0]["msg"]).contains("ui_screens.d/dup.json") and str(d_defects[0]["msg"]).contains("duplicate screen id 'mg_x'") and str(d_defects[0]["msg"]).contains("tests/fixtures/ui_audit/merge/dup_across/ui_screens.json"),
		"one defect, for mg_x, naming the file with the second row and the file that keeps the first: %s" % str(d_defects.map(func(d: Dictionary) -> String: return str(d["msg"]))))
	t.check("registry_duplicate_keeps_the_first_row", d_ids == ["mg_x", "mg_y"] and UiAudit.screen("mg_x")["title"] == "the registry file's row" and UiAudit.registry_file_of("mg_x") == MERGE_DIR + "dup_across/ui_screens.json", "the registry file's row wins, the folder file's mg_y is merged: %s" % str(d_ids))
	var sp_dup := Spy.new(t)
	await UiAudit.audit_screen(sp_dup, "mg_x")
	var sp_dup_y := Spy.new(t)
	await UiAudit.audit_screen(sp_dup_y, "mg_y")
	t.check("registry_duplicate_fails_audit_screen_of_the_id", sp_dup.failed_checks() == ["mg_x.registry_unique_id"] and sp_dup_y.failed_checks().is_empty(), "audit_screen(mg_x) fails with its own check (a package's section goes red even without the full run), mg_y is fine: %s / %s" % [str(sp_dup.failed_checks()), str(sp_dup_y.failed_checks())])
	UiAudit.use_registry(MERGE_DIR + "dup_between/ui_screens.json")
	var rep_between := UiAudit.registry_report()
	_neg(t, "neg_registry_duplicate_id_between_folder_files", rep_between, "registry_error")
	t.check("registry_duplicate_between_folder_files_names_both", (rep_between["defects"] as Array).size() == 1 and str(rep_between["defects"][0]["msg"]).contains("ui_screens.d/b.json") and str(rep_between["defects"][0]["msg"]).contains("ui_screens.d/a.json") and UiAudit.registry_file_of("mg_z") == MERGE_DIR + "dup_between/ui_screens.d/a.json", "the second folder file (b.json) is blamed, the first (a.json) keeps the row: %s" % UiAudit.summary(rep_between))
	UiAudit.use_registry(MERGE_DIR + "dup_in_file/ui_screens.json")
	var rep_in := UiAudit.registry_report()
	_neg(t, "neg_registry_duplicate_id_in_one_file", rep_in, "registry_error")
	t.check("registry_duplicate_in_one_file_is_one_defect", (rep_in["defects"] as Array).size() == 1 and UiAudit.screens().size() == 1, "two rows of mg_x in the registry file: one defect, one row kept: %s" % UiAudit.summary(rep_in))

	# 5. files that are broken: every way is a registry_error naming the file; the good rows of the other files are still merged
	UiAudit.use_registry(MERGE_DIR + "bad/ui_screens.json")
	var rep_bad := UiAudit.registry_report()
	var bad_msgs: Array = (rep_bad["defects"] as Array).map(func(d: Dictionary) -> String: return str(d["msg"]))
	var bad_text := "\n".join(bad_msgs)
	_neg(t, "neg_registry_file_does_not_parse", {"defects": (rep_bad["defects"] as Array).filter(func(d: Dictionary) -> bool: return str(d["msg"]).contains("broken.json: does not parse"))}, "registry_error")
	t.check("registry_file_defects_name_each_problem", bad_msgs.size() == 5 and bad_text.contains("ui_screens.d/broken.json: does not parse (line") and bad_text.contains("ui_screens.d/noscreens.json: has no \"screens\" array") and bad_text.contains("ui_screens.d/notobject.json: is not a JSON object") and bad_text.contains("ui_screens.d/rows.json: a row that is not a JSON object: 7") and bad_text.contains("ui_screens.d/rows.json: a row without an id"),
		"five defects, each naming its file and its problem: %s" % bad_text.replace("\n", " | "))
	var bad_ids := UiAudit.screens().map(func(s: Dictionary) -> String: return str(s["id"]))
	t.check("registry_broken_files_do_not_hide_good_rows", bad_ids == ["mg_base", "mg_ok"], "the broken files add no rows, the good row of rows.json is merged: %s" % str(bad_ids))
	UiAudit.use_registry(MERGE_DIR + "nope/ui_screens.json")
	var rep_none := UiAudit.registry_report()
	_neg(t, "neg_registry_file_missing", rep_none, "registry_error")
	t.check("registry_missing_file_is_a_defect_not_a_crash", UiAudit.screens().is_empty() and str(rep_none["defects"][0]["msg"]).contains("does not exist"), "a registry file that does not exist: no rows, one defect: %s" % UiAudit.summary(rep_none))
	UiAudit.use_registry("")
	t.check("registry_merge_default_restored", UiAudit.registry_file_of("title") == "res://tests/lib/ui_screens.json" and UiAudit.screen("mg_base").is_empty(), "use_registry('') is the real registry again")


# ---------------------------------------------------------------------------------------------------- the conforming fixtures: zero false positives

func _conforming(t) -> void:
	for layout in ["menu", "wrap_menu", "wrap_smart", "grid", "tabs", "hud", "settings", "components", "list", "radio_tabs"]:
		var s := await _make(t, layout)
		if layout == "hud":
			_clean(t, "conforming_hud_focusable", UiAudit.focusable_report(s, {"forbid_focus": true}), "every HUD control is FOCUS_NONE")
			_clean(t, "conforming_hud_rules", UiAudit.rule_report(s))
			_clean(t, "conforming_hud_flip", await UiAudit.locale_flip_report(t, s))
			await _drop(t, s)
			continue
		_clean(t, "conforming_%s_initial_focus" % layout, UiAudit.initial_focus_report(s))
		t.check("conforming_%s_initial_focus_control" % layout, UiAudit.initial_focus(s) != null, "initial_focus() returns %s" % str(UiAudit.initial_focus(s).name if UiAudit.initial_focus(s) != null else null))
		if layout != "tabs":
			_clean(t, "conforming_%s_focusable" % layout, UiAudit.focusable_report(s, GAME_FOCUS))
			_clean(t, "conforming_%s_rules" % layout, UiAudit.rule_report(s))
			_clean(t, "conforming_%s_flip" % layout, await UiAudit.locale_flip_report(t, s))
		var opts := {"wrap": "required"} if layout in ["wrap_menu", "wrap_smart"] else {}
		if layout == "wrap_smart":
			opts["echo"] = true                                    # a held key must stop at the end of the ring
		var w := await UiAudit.focus_walk(t, s, 300, opts)
		_clean(t, "conforming_%s_focus_walk" % layout, w)
		t.check("conforming_%s_walk_reaches_all" % layout, int(w["reached"]) == int(w["expected"]) and int(w["expected"]) >= 4, "%d of %d controls reached in %d presses (order %d, down chain %d)" % [w["reached"], w["expected"], w["steps"], (w["order"] as Array).size(), (w["down_chain"] as Array).size()])
		if layout == "menu":
			_clean(t, "conforming_menu_text_fields", await UiAudit.text_field_audit(t, s))
			var wk := await UiAudit.focus_walk(t, s, 300, {"via": "key"})
			_clean(t, "conforming_menu_focus_walk_arrow_keys", wk, "with real arrow-key events (the text field eats left / right, up / down still leave it)")
		if layout == "components":
			var fr := UiAudit.focusable_report(s)
			t.check("conforming_components_custom_focus_is_declared", (fr["controls"] as Array).any(func(c): return str(c["path"]).ends_with("FocusRow") and c["focus_verdict"] == "declared"), "a custom focusable control that declares tt_focus_style is listed as declared (windowed ring_pixels proves it)")
			t.check("conforming_components_covers_the_real_components", (w["expected"] as int) >= 5 and s.find_children("*", "RaritySlot", true, false).size() == 5 and s.find_children("*", "LadderRow", true, false).size() == 2, "item slots, stepper buttons, ability slots, rarity slots, ladder rows, meters, hearts, a toast, pills, plates: %d focus targets walked" % w["expected"])
		if layout == "grid":
			t.check("conforming_grid_down_chain", (w["down_chain"] as Array).size() == 3, "ui_down from the first slot walks the column: %s" % str((w["down_chain"] as Array).map(func(p): return str(p).get_file())))
		if layout == "tabs":
			t.check("conforming_tabs_pages", (w["pages"] as Array).size() == 2 and (w["order"] as Array).any(func(p): return str(p).ends_with("PageB/B1")), "both tab pages were walked (%s)" % str((w["pages"] as Array).map(func(pg): return pg["label"])))
			var tc: TabContainer = s.tabs
			t.check("conforming_tabs_state_restored", tc.current_tab == 0, "the audit left the tab it found")
		await _drop(t, s)
	# the 'accept' probe on a conforming button, and the arrow-key walk never changed the slider
	var s2 := await _make(t, "menu")
	var before: float = s2.slider.value
	var acc := await UiAudit.focus_walk(t, s2, 300, {"accept": ["*/Button1"]})
	_clean(t, "conforming_accept_works", acc)
	t.check("conforming_walk_restores_slider", s2.slider.value == before, "slider value %s before and after the walk" % str(before))
	await _drop(t, s2)


# ---------------------------------------------------------------------------------------------------- negatives: every defect is reported

func _focus_negatives(t) -> void:
	for spec in NEGATIVES:
		var s := await _make(t, spec[1], spec[0])
		var rep := await _run_kind(t, spec[2], s)
		_neg(t, "neg_%s_%s" % [spec[0], spec[3]], rep, spec[3])
		await _drop(t, s)
	# focus_escaped: a control outside the screen sits right below the last button
	var host := _host(t)
	var s := Screen.new()
	host.add_child(s)
	var behind := Button.new()
	behind.name = "BehindTheScreen"
	behind.text = "UI_NO"
	behind.theme_type_variation = &"ButtonPrimary"
	behind.custom_minimum_size = Vector2(300, 52)
	behind.position = Vector2(390, 660)
	host.add_child(behind)
	await t.frames(3)
	_neg(t, "neg_focus_escaped", await UiAudit.focus_walk(t, s, 300), "focus_escaped")
	await _drop(t, s)
	# dead_end: the plain menu does not wrap, the wrap_menu does
	var plain := await _make(t, "menu")
	_neg(t, "neg_dead_end_without_wrap", await UiAudit.focus_walk(t, plain, 300, {"wrap": "required"}), "dead_end")
	_neg(t, "neg_walk_truncated", await UiAudit.focus_walk(t, plain, 10), "walk_truncated")
	var grid := await _make(t, "grid")
	var gwrap := await UiAudit.focus_walk(t, grid, 400, {"wrap": "required", "wrap_axes": "vh"})
	var h_dead := (gwrap["dead_ends"] as Array).filter(func(d): return d["dir"] in ["left", "right"]).size()
	var v_dead := (gwrap["dead_ends"] as Array).filter(func(d): return d["dir"] in ["up", "down"]).size()
	t.check("walk_grid_wrap_axes", h_dead == 6 and v_dead == 8, "a 4x3 grid without wrap: 3 rows x 2 horizontal ends = %d, 4 columns x 2 vertical ends = %d dead ends" % [h_dead, v_dead])
	var gv := await UiAudit.focus_walk(t, grid, 400, {"wrap": "required", "wrap_axes": "v"})
	t.check("walk_grid_wrap_axes_v_only", (gv["dead_ends"] as Array).all(func(d): return d["dir"] in ["up", "down"]) and (gv["dead_ends"] as Array).size() == 8, "wrap_axes 'v' ignores the horizontal ends")
	await _drop(t, grid)
	var dflt := await UiAudit.focus_walk(t, plain)
	_clean(t, "walk_default_budget_runs", dflt, "default max_steps = 200: %d presses" % dflt["steps"])
	await _drop(t, plain)
	# initial_focus_outside: the screen did not take focus and something behind it has it
	var host2 := _host(t)
	var s2 := Screen.new()
	s2.defect = "no_initial_focus"
	host2.add_child(s2)
	var other := Button.new()
	other.text = "UI_NO"
	other.custom_minimum_size = Vector2(200, 52)
	other.position = Vector2(20, 640)
	host2.add_child(other)
	await t.frames(2)
	other.grab_focus()
	_neg(t, "neg_initial_focus_outside", UiAudit.initial_focus_report(s2), "initial_focus_outside")
	t.check("initial_focus_outside_is_null", UiAudit.initial_focus(s2) == null, "initial_focus() is null when the focus owner is outside the screen")
	await _drop(t, s2)


# ---------------------------------------------------------------------------------------------------- walk features: lists, grids, tabs, sliders, text fields, options

func _walk_features(t) -> void:
	var s := await _make(t, "menu")
	var w := await UiAudit.focus_walk(t, s, 300)
	var order: Array = (w["order"] as Array).map(func(p): return str(p).get_file())
	t.check("walk_list_order", order == ["Button1", "Button2", "Button3", "Name", "Volume", "Button4"], "a vertical list is walked top to bottom: %s" % str(order))
	t.check("walk_list_edges", w["edges"].size() >= 6 and (w["edges"] as Dictionary).values().all(func(e): return not (e as Dictionary).has("left") and not (e as Dictionary).has("right")), "a single column has only ui_up / ui_down edges")
	var vol: Control = s.slider
	var edges: Dictionary = (w["edges"] as Dictionary)[str(s.get_path_to(vol))]
	t.check("walk_slider_leaves_vertically", edges.has("up") and edges.has("down") and not edges.has("left"), "a slider is left with up / down, ui_left / ui_right change its value: %s" % str(edges.keys()))
	# the result keys the navigation spec reads (10.3) and the options it passes
	var b1 := str(s.get_path_to(s.buttons[0]))
	var b2 := str(s.get_path_to(s.buttons[1]))
	var b3 := str(s.get_path_to(s.buttons[2]))
	t.check("walk_spec_result_keys", w.has("start") and w.has("nodes") and w.has("order_down") and w.has("order_right") and w.has("cycle_down") and w.has("cycle_right") and w.has("focus_loss") and w.has("mismatches") \
		and w.has("echo_wraps") and bool(w["pad_matches_keyboard"]) and w["start"] == b1 and w["order_down"] == w["down_chain"] and not bool(w["cycle_down"]) and (w["nodes"] as Array).size() == 6, "start, nodes, order_down / order_right, cycle_down / cycle_right, focus_loss, mismatches, echo_wraps, pad_matches_keyboard (a plain list does not cycle)")
	var good_edges := await UiAudit.focus_walk(t, s, 300, {"expect_edges": {b1: {"down": b2}, b2: {"up": b1, "down": b3}}})
	_clean(t, "walk_expect_edges_match", good_edges, "the owner's declared neighbour table equals the measured one")
	var bad_edges := await UiAudit.focus_walk(t, s, 300, {"expect_edges": {b1: {"down": b3}}})
	_neg(t, "neg_edge_mismatch", bad_edges, "edge_mismatch")
	t.check("walk_expect_edges_report", (bad_edges["mismatches"] as Array).size() == 1 and bad_edges["mismatches"][0]["expected"] == b3 and bad_edges["mismatches"][0]["got"] == b2, "mismatches lists {from, dir, expected, got}: %s" % str(bad_edges["mismatches"]))
	var consumed := await UiAudit.focus_walk(t, s, 300, {"consumes": {b1: ["down"]}})
	t.check("walk_consumes_option", (_has(consumed, "unreachable") or _has(consumed, "only_via_tab")) and not (consumed["edges"] as Dictionary).get(b1, {}).has("down"), "a direction a control declares consumed is not probed from it (so what lies beyond becomes unreachable)")
	var started := await UiAudit.focus_walk(t, s, 300, {"start": b3})
	t.check("walk_start_option", started["start"] == b3 and (started["order"] as Array)[0] == b3, "options.start picks the control the walk starts from")
	var down_only := await UiAudit.focus_walk(t, s, 300, {"dirs": ["down"]})
	t.check("walk_dirs_option", (down_only["dead_ends"] as Array).size() == 1 and down_only["dead_ends"][0]["dir"] == "down", "options.dirs lists the primary directions: only the last row has no way down (%s)" % str(down_only["dead_ends"]))
	var skipped := await UiAudit.focus_walk(t, s, 300, {"skip": [b3]})
	_clean(t, "walk_skip_alias", skipped, "options.skip is the spec's name for ignore")
	await _drop(t, s)
	for layout in ["wrap_menu", "wrap_smart"]:
		var wm := await _make(t, layout)
		var ww := await UiAudit.focus_walk(t, wm, 300, {"wrap": "required"})
		t.check("walk_%s_cycles" % layout, bool(ww["cycle_down"]) and (ww["order_down"] as Array).size() == 6, "the ring comes back to its start with ui_down (%s)" % layout)
		var echo := await UiAudit.focus_walk(t, wm, 300, {"wrap": "required", "echo": true})
		if layout == "wrap_menu":
			_neg(t, "neg_echo_wraps", echo, "echo_wraps")
			t.check("walk_echo_report", (echo["echo_wraps"] as Array).size() >= 1 and echo["echo_wraps"][0].has("from") and echo["echo_wraps"][0].has("dir"), "echo_wraps lists {from, dir, to}: %s" % str(echo["echo_wraps"]))
		else:
			_clean(t, "walk_echo_safe_wrap", echo, "a wrap-around that a fresh press crosses and a held key does not")
		await _drop(t, wm)
	var g := await _make(t, "grid")
	var gw := await UiAudit.focus_walk(t, g, 300)
	var gedges: Dictionary = gw["edges"]
	var first: Dictionary = gedges[str(g.get_path_to(g.slots[0]))]
	var second: Dictionary = gedges[str(g.get_path_to(g.slots[5]))]
	t.check("walk_grid_edges", first.has("right") and first.has("down") and not first.has("left") and not first.has("up") and second.size() == 4, "a 4x3 grid: the corner has 2 neighbours, an inner cell 4 (%s / %s)" % [str(first.keys()), str(second.keys())])
	t.check("walk_grid_symmetric", _symmetric(gedges), "every grid edge has its way back (right then left, down then up)")
	await _drop(t, g)
	# an option: ignore skips a subtree and meta tt_audit_ignore does too
	var u := await _make(t, "menu", "unfocusable_button")
	var ignored := await UiAudit.focus_walk(t, u, 300, {"ignore": ["*/Button2"]})
	_clean(t, "walk_option_ignore", ignored, "options.ignore removes a control from the audit")
	u.buttons[1].set_meta(&"tt_audit_ignore", "dev sample")
	_clean(t, "walk_meta_ignore", await UiAudit.focus_walk(t, u, 300), "meta tt_audit_ignore does the same")
	_clean(t, "focusable_meta_ignore", UiAudit.focusable_report(u))
	await _drop(t, u)
	# the replay of the recorded keys has its own budget: a long list with a tight max_steps stops the replay with a note, not a failure
	var long_list := await _make(t, "list")
	var tight := await UiAudit.focus_walk(t, long_list, 62, {"via": "action"})
	var roomy := await UiAudit.focus_walk(t, long_list, 400, {"via": "action"})
	_clean(t, "walk_replay_budget_is_not_a_defect", tight, "12 rows, max_steps 62: probes fit, the replay stops at its budget")
	t.check("walk_replay_budget_note", (tight["notes"] as Array).any(func(n): return str(n["msg"]).contains("replay stopped")) and not (roomy["notes"] as Array).any(func(n): return str(n["msg"]).contains("replay stopped")), "the stopped replay is listed in the notes; with room it runs to the end")
	await _drop(t, long_list)
	# press helpers: the Esc key matches ui_cancel AND pause, gamepad B only ui_cancel, Start only pause
	var m := await _make(t, "menu")
	var seen: Array[String] = []
	var catcher := _Catcher.new()
	catcher.seen = seen
	t.root.add_child(catcher)
	UiAudit.press_cancel(t, "key")
	UiAudit.press_cancel(t, "action")
	UiAudit.press_cancel(t, "pause")
	t.check("press_cancel_variants", seen == ["key:ui_cancel+pause", "action:ui_cancel", "pause:pause"], "the Esc key matches ui_cancel and pause, gamepad B only ui_cancel, Start only pause: %s" % str(seen))
	catcher.queue_free()
	await _drop(t, m)


## the key walk of via "both" starts where the action walk started (the pad check moved focus around in between); a walk that starts ON a slider never presses
## ui_right through it
func _walk_start_features(t) -> void:
	var s := await _make(t, "menu")
	var both := await UiAudit.focus_walk(t, s, 300)
	t.check("walk_second_walk_starts_at_the_initial_focus", str(both.get("initial_keys", "?")) == str(both["initial"]) and both["initial"] != "", "the arrow-key walk starts at '%s' like the action walk ('%s')" % [both.get("initial_keys", "?"), both["initial"]])
	var v0: float = s.slider.value
	var from_slider := await UiAudit.focus_walk(t, s, 300, {"start": str(s.get_path_to(s.slider)), "via": "action"})
	t.check("walk_starting_on_a_slider_keeps_its_value", s.slider.value == v0 and not _has(from_slider, "slider_ignores_keys"), "slider %s -> %s: the chains do not press ui_right through the start control" % [v0, s.slider.value])
	await _drop(t, s)


func _symmetric(edges: Dictionary) -> bool:
	var opposite := {"down": "up", "up": "down", "left": "right", "right": "left"}
	for a in edges:
		for d in edges[a]:
			var b: String = edges[a][d]
			if edges.has(b) and (edges[b] as Dictionary).get(opposite[d], "") != a:
				return false
	return true


## Stands in for the world: counts the cancel presses that nobody handled (a modal must consume the press that closes it).
class _WorldProbe extends Node:
	var count := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_pressed() and (event.is_action("ui_cancel") or event.is_action("pause")):
			count += 1

	func counter() -> int:
		return count


class _DeviceCatcher extends Node:
	var seen: Array[String] = []

	func _input(event: InputEvent) -> void:
		var cn := event.get_class()
		if not seen.has(cn):
			seen.append(cn)


class _Catcher extends Node:
	var seen: Array[String] = []

	func _unhandled_input(event: InputEvent) -> void:
		if not event.is_pressed():
			return
		var kind := "key" if event is InputEventKey else ("action" if event.is_action("ui_cancel") else "pause")
		var names: Array[String] = []
		if event.is_action_pressed("ui_cancel"):
			names.append("ui_cancel")
		if event.is_action_pressed("pause"):
			names.append("pause")
		seen.append("%s:%s" % [kind, "+".join(names)])


# ---------------------------------------------------------------------------------------------------- the escape chain

func _escape(t) -> void:
	var gm: Node = t.autoload("GameManager")
	if gm == null:
		return
	var phase0: Variant = gm.get("current_phase")
	# conforming: depth 1, 2 and 3, with the Esc key, with ui_cancel alone (gamepad B) and with pause alone (gamepad Start)
	for spec in [[1, "key"], [2, "key"], [3, "key"], [2, "action"], [2, "pause"], [2, "pad_b"], [2, "start"]]:
		var host := _host(t)
		var world := _WorldProbe.new()
		host.add_child(world)
		var m := Modals.new()
		host.add_child(m)
		await t.frames(3)
		var rep := await UiAudit.escape_chain(t, func(level: int) -> void: m.open_level(level), spec[0], {"via": spec[1], "world_probe": world.counter})
		t.check("escape_conforming_%d_%s_steps" % spec, (rep["steps"] as Array).size() == spec[0] and (rep["steps"] as Array).all(func(st): return int(st["world_actions_fired"]) == 0) and int((rep["steps"] as Array)[-1]["depth_after"]) == 0 and int(rep["depth_open"]) == spec[0], "every press is recorded (depth after, stack, focus owner) and the world saw none of them")
		_clean(t, "escape_conforming_depth%d_%s" % spec, rep, "%s opened, closed top first with Esc (%s): %s" % [str(rep["opened"]), spec[1], str(rep["closed"])])
		t.check("escape_conforming_%d_%s_order" % spec, (rep["closed"] as Array) == _reversed(rep["opened"]), "closed in reverse order of opening")
		host.queue_free()
		await t.frames(2)
	var host_f := _host(t)
	var mf := Modals.new()
	mf.defect = "field_focus_ok"
	host_f.add_child(mf)
	await t.frames(3)
	var repf := await UiAudit.escape_chain(t, func(level: int) -> void: mf.open_level(level), 2)
	_clean(t, "escape_conforming_text_field_focused", repf, "Esc typed while a LineEdit has focus still closes the modal when the modal reads it in _input (a focused LineEdit eats the Esc key before _unhandled_input)")
	host_f.queue_free()
	await t.frames(2)
	t.check("escape_leaves_game_clean", not t.tree.paused and gm.call("modal_stack").is_empty(), "no modal left on the stack, the tree is unpaused")
	# negatives
	var leftovers: Array[String] = []
	for spec in ESCAPE_NEGATIVES:
		var host2 := _host(t)
		var m2 := Modals.new()
		m2.defect = spec[0]
		host2.add_child(m2)
		await t.frames(3)
		var rep2 := await UiAudit.escape_chain(t, func(level: int) -> void: m2.open_level(level), 3)
		_neg(t, "neg_escape_%s_%s" % [spec[0], spec[1]], rep2, spec[1])
		# what the AUDIT leaves behind is read right here, before this section tidies up after the fixture (a chain that forgot its own clean-up must not hide behind it)
		if not (gm.call("modal_stack") as Array).is_empty() or t.tree.paused or gm.get("current_phase") != phase0:
			leftovers.append("%s (stack %s, paused %s)" % [spec[0], str(gm.call("modal_stack")), str(t.tree.paused)])
		gm.call("change_phase", phase0)
		t.tree.paused = false
		host2.queue_free()
		await t.frames(2)
	t.check("escape_negatives_clean_up", leftovers.is_empty() and not t.tree.paused and gm.call("modal_stack").is_empty() and gm.get("current_phase") == phase0, "after every broken chain the audit itself leaves the stack empty, the tree unpaused and the phase as it was (read before the section tidies up) %s" % str(leftovers))
	# without a GameManager the chain cannot read the modal stack: reported, not a crash
	var nogm := Spy.new(t)
	var fake_root := Window.new()
	nogm.root = fake_root
	_neg(t, "neg_escape_no_game_manager", await UiAudit.escape_chain(nogm, func(_level: int) -> void: pass, 1), "no_game_manager")
	fake_root.free()
	# an opener without arguments is called ONCE and leaves the whole stack open (the way the player opens it: Esc on the world, then a pause row)
	var host3 := _host(t)
	var m3 := Modals.new()
	host3.add_child(m3)
	await t.frames(3)
	var rep3 := await UiAudit.escape_chain(t, func() -> void:
		m3.open_level(0)
		m3.open_level(1), 2)
	_clean(t, "escape_zero_argument_opener", rep3, "an opener without a level argument is called ONCE and leaves the whole stack open (depth %d, opened %s)" % [rep3["depth_open"], str(rep3["opened"])])
	t.check("escape_zero_argument_opener_depth", int(rep3["depth_open"]) == 2 and (rep3["stack_open"] as Array).size() == 2 and str(rep3["opener_focus"]).ends_with("OpenButton") and str(rep3["restored_focus"]).ends_with("OpenButton"), "result carries depth_open, stack_open, opener_focus and restored_focus")
	host3.queue_free()
	await t.frames(2)
	# a zero-argument opener that opens too little is a depth mismatch
	var host4 := _host(t)
	var m4 := Modals.new()
	host4.add_child(m4)
	await t.frames(3)
	_neg(t, "neg_escape_single_opener_depth", await UiAudit.escape_chain(t, func() -> void: m4.open_level(0), 2), "opener_depth_mismatch")
	host4.queue_free()
	await t.frames(2)
	# the world sees the press that closes the modal when the modal does not consume it
	var host5 := _host(t)
	var world5 := _WorldProbe.new()
	host5.add_child(world5)
	var m5 := Modals.new()
	m5.defect = "leak_to_world"
	host5.add_child(m5)
	await t.frames(3)
	_neg(t, "neg_escape_world_saw_press", await UiAudit.escape_chain(t, func(level: int) -> void: m5.open_level(level), 2, {"world_probe": world5.counter}), "world_saw_press")
	host5.queue_free()
	await t.frames(2)
	# internal layers: the screen's own pages close first, the modal stack does not move for them
	var host_i := _host(t)
	var world_i := _WorldProbe.new()
	host_i.add_child(world_i)
	var mi := Modals.new()
	host_i.add_child(mi)
	await t.frames(3)
	var opener_i := func(level: int) -> void:
		if level < 1:
			mi.open_level(level)
		else:
			mi.open_internal()
	var rep_i := await UiAudit.escape_chain(t, opener_i, 3, {"internal_layers": 2, "internal_depth": Callable(mi, "internal_depth"), "world_probe": world_i.counter})
	_clean(t, "escape_internal_layers_conforming", rep_i, "1 modal + 2 internal layers: the internal ones close first and the stack stays put (closed %s)" % str(rep_i["closed"]))
	t.check("escape_internal_layers_result", rep_i["closed"] == ["internal", "internal", "audit_modal_0"] and rep_i["depth_open"] == 3 and rep_i["internal_layers"] == 2 and (rep_i["steps"] as Array)[0].get("internal", false) and not (rep_i["steps"] as Array)[2].get("internal", false), "steps are flagged internal, depth_open counts every layer: %s" % str((rep_i["steps"] as Array).map(func(st): return st.get("internal", false))))
	var rep_i2 := await UiAudit.escape_chain(t, func() -> void:
		mi.open_level(0)
		mi.open_internal(), 2, {"internal_layers": 1})
	_clean(t, "escape_internal_layers_single_opener_without_probe", rep_i2, "a single opener, no internal_depth callable: the stack must not move for the internal press and the world must not see it")
	host_i.queue_free()
	await t.frames(2)
	for spec_i in [["internal_ignore", "esc_does_not_close"], ["internal_all", "esc_closes_several"], ["internal_wrong_order", "esc_wrong_order"], ["internal_leak", "world_saw_press"]]:
		var host_n := _host(t)
		var world_n := _WorldProbe.new()
		host_n.add_child(world_n)
		var mn := Modals.new()
		mn.defect = spec_i[0]
		host_n.add_child(mn)
		await t.frames(3)
		var opener_n := func(level: int) -> void:
			if level < 1:
				mn.open_level(level)
			else:
				mn.open_internal()
		var rep_n := await UiAudit.escape_chain(t, opener_n, 3, {"internal_layers": 2, "internal_depth": Callable(mn, "internal_depth"), "world_probe": world_n.counter})
		_neg(t, "neg_escape_internal_%s" % spec_i[0], rep_n, spec_i[1])
		var coded_path := ""
		for dn in rep_n["defects"]:
			if dn["code"] == spec_i[1] and coded_path == "":
				coded_path = str(dn["path"])
		t.check("neg_escape_internal_%s_is_about_the_internal_layer" % spec_i[0], coded_path.begins_with("internal layer") or spec_i[0] == "internal_wrong_order", "the %s defect names the internal layer, not a modal: '%s'" % [spec_i[1], coded_path])
		gm.call("change_phase", phase0)
		t.tree.paused = false
		host_n.queue_free()
		await t.frames(2)
	# a screen that was already open when the chain starts (pre_opened): the pause state and the phase of BEFORE it opened are the baseline
	var host_p := _host(t)
	var mp := Modals.new()
	mp.defect = "stays_paused"
	host_p.add_child(mp)
	await t.frames(3)
	var base_stack_p: Array = gm.call("modal_stack")
	mp.open_level(0)
	await t.frames(2)
	var pre_rep := await UiAudit.escape_chain(t, Callable(), 1, {"pre_opened": true, "base_stack": base_stack_p, "base_paused": false, "base_phase": phase0})
	_neg(t, "neg_escape_pre_opened_game_stays_paused", pre_rep, "game_stays_paused")
	gm.call("change_phase", phase0)
	t.tree.paused = false
	host_p.queue_free()
	await t.frames(2)
	var host_m := _host(t)
	var mm := Modals.new()
	host_m.add_child(mm)
	await t.frames(3)
	_neg(t, "neg_escape_internal_opener_pushes_a_modal", await UiAudit.escape_chain(t, func(level: int) -> void: mm.open_level(level), 2, {"internal_layers": 1}), "opener_depth_mismatch")
	gm.call("change_phase", phase0)
	t.tree.paused = false
	host_m.queue_free()
	await t.frames(2)
	# expect_focus / release_world_focus
	var host6 := _host(t)
	var m6 := Modals.new()
	host6.add_child(m6)
	await t.frames(3)
	var rep6 := await UiAudit.escape_chain(t, func(level: int) -> void: m6.open_level(level), 1, {"expect_focus": str(m6.base_button.get_path())})
	_clean(t, "escape_expect_focus_option", rep6, "options.expect_focus names the control that owns focus after the last layer")
	var rep6b := await UiAudit.escape_chain(t, func(level: int) -> void: m6.open_level(level), 1, {"release_world_focus": true})
	_neg(t, "escape_release_world_focus_option", rep6b, "focus_not_restored")
	_neg(t, "neg_escape_expect_focus_elsewhere", await UiAudit.escape_chain(t, func(level: int) -> void: m6.open_level(level), 1, {"expect_focus": "AuditHost/Nowhere"}), "focus_not_restored")
	host6.queue_free()
	await t.frames(2)
	var host7 := _host(t)
	var m7 := Modals.new()
	m7.defect = "no_focus"
	host7.add_child(m7)
	await t.frames(3)
	_neg(t, "neg_escape_single_opener_modal_no_focus", await UiAudit.escape_chain(t, func() -> void:
		m7.open_level(0)
		m7.open_level(1), 2), "modal_no_focus")
	_clean(t, "escape_declared_text_only_modal", await UiAudit.escape_chain(t, func() -> void:
		m7.open_level(0)
		m7.open_level(1), 2, {"require_focus": false}), "A declared text-only modal still consumes Esc, restores focus and pops one layer at a time")
	gm.call("change_phase", phase0)
	t.tree.paused = false
	host7.queue_free()
	await t.frames(2)


func _reversed(a: Array) -> Array:
	var out := a.duplicate()
	out.reverse()
	return out


# ---------------------------------------------------------------------------------------------------- options, radio pages, the missing theme

func _options_and_pages(t) -> void:
	var s := await _make(t, "menu")
	var bad_walks := [["wrap_value", {"wrap": "requierd"}], ["wrap_key", {"warp": "required"}], ["wrap_axes", {"wrap": "required", "wrap_axes": "x"}], ["via", {"via": "keyboard"}],
		["dirs", {"dirs": ["north"]}], ["flag", {"echo": "yes"}], ["count", {"max_pages": -1}], ["accept", {"accept": 5}], ["consumes", {"consumes": ["down"]}]]
	for spec in bad_walks:
		var rep := await UiAudit.focus_walk(t, s, 300, spec[1])
		_neg(t, "neg_bad_option_walk_%s" % spec[0], rep, "bad_option")
		var names_it := false
		for d in rep["defects"]:
			names_it = names_it or (d["code"] == "bad_option" and str(d["msg"]).contains(str((spec[1] as Dictionary).keys()[0])))
		t.check("bad_option_walk_%s_names_the_option" % spec[0], names_it, "the message names the offending option '%s'" % str((spec[1] as Dictionary).keys()[0]))
	# the typo that used to be silent: wrap 'requierd' on a list that does not wrap was CLEAN with 0 notes
	_neg(t, "neg_bad_option_typo_is_no_longer_silent", await UiAudit.focus_walk(t, s, 300, {"wrap": "requierd"}), "bad_option")
	_neg(t, "neg_bad_option_focusable", UiAudit.focusable_report(s, {"forbid_windos": true}), "bad_option")
	_neg(t, "neg_bad_option_rules_value", UiAudit.rule_report(s, {"rules": ["r9"]}), "bad_option")
	_neg(t, "neg_bad_option_rules_key", UiAudit.rule_report(s, {"hit_mn": 3}), "bad_option")
	_neg(t, "neg_bad_option_escape", await UiAudit.escape_chain(t, func(_l: int) -> void: pass, 0, {"setle": 3}), "bad_option")
	_neg(t, "neg_bad_option_flip", await UiAudit.locale_flip_report(t, s, {"same": []}), "bad_option")
	_neg(t, "neg_bad_option_text_fields", await UiAudit.text_field_audit(t, s, {"enter": true}), "bad_option")
	_neg(t, "neg_bad_option_mouse_walk", await UiAudit.mouse_walk(t, s, {"clicks": []}), "bad_option")
	var known := {"wrap": "required", "wrap_axes": "vh", "via": "action", "dirs": ["down"], "echo": true, "pages": false, "max_pages": 3, "accept": "all", "consumes": {}, "expect_edges": {}, "replay": true,
		"tabs": true, "pad_check": true, "ignore": [], "skip": [], "start": "x", "real_keys": false, "tab_groups": []}
	t.check("validate_options_accepts_every_known_walk_option", UiAudit.validate_options("focus_walk", known).is_empty(), "%s" % str(UiAudit.validate_options("focus_walk", known)))
	t.check("validate_options_numbers_from_json_are_whole_floats", UiAudit.validate_options("registry", {"max_steps": 300.0, "hit_min": 28}).is_empty() and not UiAudit.validate_options("registry", {"max_steps": 2.5}).is_empty()
		and not UiAudit.validate_options("registry", {"max_steps": -1}).is_empty(), "300.0 (a JSON number) is a whole number, 2.5 and -1 are not")
	await _drop(t, s)
	# a registry row with a typo fails ITS row, loudly (the options of a row are the owners' hand-edited surface)
	UiAudit.use_registry(FIXTURE_REGISTRY)
	var spo := Spy.new(t)
	var row_bad := await UiAudit.audit_screen(spo, "fx_live", {"options": {"wrap": "requierd"}})
	_neg(t, "neg_bad_option_registry_row", {"defects": row_bad["defects"]}, "bad_option")
	t.check("registry_row_with_a_typo_fails_its_options_check", spo.failed_checks() == ["fx_live.options"] and spo.checks().size() == 1, "one failing check fx_live.options and nothing else ran: %s" % str(spo.failed_checks()))
	var spo2 := Spy.new(t)
	var row_esc := await UiAudit.audit_screen(spo2, "fx_modal", {"escape": {"depth": 2, "vias": ["keyboard"]}})
	t.check("registry_row_escape_object_is_validated", spo2.failed_checks() == ["fx_modal.options"], "an unknown escape via fails the row: %s" % str(spo2.failed_checks()))
	UiAudit.use_registry("")
	var _unused_rows := [row_esc]
	# the theme that is not there
	_neg(t, "neg_theme_missing", UiAudit.Rules._theme_scan_of(null, {}), "no_theme")
	# the pages behind radio tabs: a conforming screen is clean and its selection is put back
	var rt := await _make(t, "radio_tabs")
	var w := await UiAudit.focus_walk(t, rt, 0)
	_clean(t, "radio_tabs_walk_is_clean", w, "%d of %d controls reached in %d presses" % [w["reached"], w["expected"], w["steps"]])
	var page_labels: Array = (w["pages"] as Array).map(func(p): return str(p["label"]))
	t.check("radio_tabs_walk_visits_every_page", int(w["expected"]) == 9 and int(w["reached"]) == 9 and page_labels.size() == 3 and page_labels[1].begins_with("page 'Tab") and page_labels[2].begins_with("page 'Tab"), "9 controls: the three tabs, the open page and the two pages behind the other tabs (%s)" % str(page_labels))
	var pressed_after: Array = rt.tab_buttons.filter(func(b): return b.button_pressed)
	t.check("radio_tabs_walk_restores_the_selection", pressed_after.size() == 1 and pressed_after[0] == rt.tab_buttons[0] and rt.pages[0].visible and not rt.pages[1].visible, "the screen is left on the tab it opened on: %s" % str(pressed_after.map(func(b): return b.name)))
	var fr := await UiAudit.focusable_report_pages(t, rt, GAME_FOCUS)
	var rr := await UiAudit.rule_report_pages(t, rt)
	_clean(t, "radio_tabs_focusable_pages_clean", fr)
	_clean(t, "radio_tabs_rules_pages_clean", rr)
	t.check("radio_tabs_pages_listed", (fr["pages"] as Array).size() == 3 and (rr["pages"] as Array).size() == 3, "three pages were checked: %s" % str(rr["pages"]))
	var one := await UiAudit.rule_report_pages(t, rt, {"pages": false})
	t.check("radio_tabs_pages_option_false_checks_only_the_open_page", (one["pages"] as Array).size() == 1, "options.pages = false: %s" % str(one["pages"]))
	var cap := await UiAudit.focusable_report_pages(t, rt, {"max_pages": 1})
	t.check("radio_tabs_max_pages_caps_the_visits", (cap["pages"] as Array).size() == 2, "options.max_pages = 1 visits one other page of the group: %s" % str(cap["pages"]))
	var groups := UiAudit.radio_groups(rt)
	t.check("radio_groups_lists_the_tab_set", groups.size() == 1 and (groups[0]["members"] as Array).size() == 3 and groups[0]["selected"] == rt.tab_buttons[0], "one group of three PillTab buttons, the first selected: %s" % str(groups.map(func(g): return g["label"])))
	var explicit := UiAudit.radio_groups(rt, {"tab_groups": [["Nope"]]})
	t.check("radio_groups_explicit_sets_need_two_buttons", explicit.size() == 1, "an explicit tab_groups set with no usable member adds nothing")
	await _drop(t, rt)
	# a screen that says it holds no focus owner in this mode (Indretning PLACE, a dialogue text line)
	var nf := await _make(t, "menu", "no_initial_focus")
	nf.set_script(NoFocusMode)
	await t.frames(2)
	_clean(t, "wants_focus_false_needs_no_initial_focus", UiAudit.initial_focus_report(nf), "a screen whose _wants_focus() is false is not asked for an initial focus")
	var nfw := await UiAudit.focus_walk(t, nf, 300)
	t.check("wants_focus_false_is_not_walked", nfw["ok"] and int(nfw["expected"]) == 0 and (nfw["notes"] as Array).any(func(n): return str(n["msg"]).contains("_wants_focus")), "the walk is skipped with a note, not failed: %s" % UiAudit.summary(nfw))
	nf.set("wants", true)
	_neg(t, "wants_focus_true_again_is_asked_for_focus", UiAudit.initial_focus_report(nf), "no_initial_focus")
	await _drop(t, nf)


# ---------------------------------------------------------------------------------------------------- dialogs (a Window has its own focus owner)

func _dialogs(t) -> void:
	for focus_cancel in [true, false]:
		var d := ConfirmationDialog.new()
		d.title = "UI_YES"
		d.dialog_text = "INV_TITLE"
		d.ok_button_text = "UI_YES"
		d.cancel_button_text = "UI_NO"
		t.root.add_child(d)
		d.popup_centered()
		await t.frames(3)
		if focus_cancel:
			d.get_cancel_button().grab_focus()
		await t.frames(2)
		var tag := "cancel" if focus_cancel else "default"
		t.check("dialog_%s_initial_focus_in_its_own_window" % tag, UiAudit.initial_focus(d) != null and (UiAudit.initial_focus(d) == d.get_cancel_button()) == focus_cancel, "a ConfirmationDialog is a Window: the audit reads the focus owner of the dialog's viewport (%s)" % str(UiAudit.initial_focus(d).name if UiAudit.initial_focus(d) != null else null))
		_clean(t, "dialog_%s_initial_report" % tag, UiAudit.initial_focus_report(d))
		_clean(t, "dialog_%s_focusable" % tag, UiAudit.focusable_report(d))
		var wk := await UiAudit.focus_walk(t, d)
		_clean(t, "dialog_%s_focus_walk" % tag, wk)
		t.check("dialog_%s_walk_reaches_both_buttons" % tag, int(wk["expected"]) == 2 and int(wk["reached"]) == 2, "OK and Cancel are reached with ui_left / ui_right inside the dialog: %s of %s" % [wk["reached"], wk["expected"]])
		_clean(t, "dialog_%s_rules" % tag, UiAudit.rule_report(d), "the dialog's own panel override is the theme's AcceptDialog style, not an ad-hoc gold decoration")
		d.queue_free()
		await t.frames(2)
	var hidden := ConfirmationDialog.new()
	t.root.add_child(hidden)
	await t.frames(2)
	t.check("dialog_hidden_is_not_scanned", Rules_nodes_count(hidden) == 0, "a hidden Window (an unopened dialog) hides its whole subtree from the scan")
	hidden.queue_free()
	await t.frames(2)


func Rules_nodes_count(root: Node) -> int:
	return UiAudit.Rules.nodes(root).size()


# ---------------------------------------------------------------------------------------------------- the rules

func _rules(t) -> void:
	var Rules = UiAudit.Rules
	var C = Rules.C
	# the palette itself: no colour of the guide is red, gold and ink are recognised
	var reds: Array[String] = []
	var n_colors := 0
	for k in C.get_script_constant_map():
		var v: Variant = C.get_script_constant_map()[k]
		if v is Color:
			n_colors += 1
			if Rules.is_red(v) and not str(k).begins_with("ZONE_"):
				reds.append(str(k))
	t.check("rules_palette_has_no_red", reds.is_empty() and n_colors > 30, "%d palette colours of tt_colors.gd, red ones: %s (thorn-berry hue %.0f is pink)" % [n_colors, str(reds), C.THORNBERRY.h * 360.0])
	t.check("rules_red_gold_ink_predicates", Rules.is_red(Color("#e02020")) and Rules.is_red(Color("#ff0000")) and Rules.is_red(Color("#cc1f1f")) and not Rules.is_red(C.THORNBERRY) and not Rules.is_red(C.ROSE) \
		and not Rules.is_red(C.BARK) and not Rules.is_red(Color(0.8, 0.1, 0.1, 0.0)) and Rules.is_gold(C.GOLD) and Rules.is_gold(C.GOLD_HOVER) and not Rules.is_gold(C.HONEY) \
		and not Rules.is_gold(C.GOLD_DARK) and Rules.is_ink(C.INK), "danger reds are caught; thorn-berry, rose, bark, honey, dark gold are not; gold / ink match")
	t.check("rules_number_text", Rules.is_number_text("1.250") and Rules.is_number_text("10:40") and Rules.is_number_text("12") and Rules.is_number_text("x3") and Rules.is_number_text("+5") \
		and not Rules.is_number_text("18 / 24") and not Rules.is_number_text("150 guldagern") and not Rules.is_number_text("I alt 300") and not Rules.is_number_text("Dag 14") \
		and not Rules.is_number_text("Aktive · 3") and not Rules.is_number_text("") and not Rules.is_number_text("E"), "purely numeric text (money, clock, count) is a number; the guide's own mixed texts ('18 / 24', 'I alt 300', 'Dag 14') are exempt by construction")
	# R1 details
	var s := await _make(t, "menu")
	var dis: Button = s.buttons[0]
	dis.disabled = true
	_clean(t, "rules_r1_dashed_disabled_ok", UiAudit.rule_report(s, {"rules": ["r1"]}), "the guide's dashed disabled button needs no ink outline")
	dis.disabled = false
	var bare_style := StyleBoxFlat.new()
	bare_style.bg_color = Color("#f4e6c4")
	var boxed := Button.new()
	boxed.text = "SET_DONE"
	boxed.custom_minimum_size = Vector2(0, 52)
	boxed.add_theme_stylebox_override("normal", bare_style)
	s.vbox.add_child(boxed)
	await t.frames(2)
	_neg(t, "rules_r1_button_without_outline", UiAudit.rule_report(s, {"rules": ["r1"]}), "r1_no_ink_outline")
	boxed.flat = true
	_clean(t, "rules_r1_flat_button_draws_no_box", UiAudit.rule_report(s, {"rules": ["r1"]}), "a flat button draws no box, so no outline is required")
	boxed.queue_free()
	var scrim := PanelContainer.new()
	scrim.theme_type_variation = &"PanelScrim"
	scrim.custom_minimum_size = Vector2(60, 60)
	s.vbox.add_child(scrim)
	var plate := Label.new()
	plate.text = "HUD_ENERGY"
	plate.theme_type_variation = &"NamePlate"
	s.vbox.add_child(plate)
	await t.frames(2)
	_clean(t, "rules_r1_dark_plates_and_scrims_ok", UiAudit.rule_report(s, {"rules": ["r1"]}), "a translucent scrim and an ink name plate are not parchment surfaces")
	var seg := PanelContainer.new()
	seg.custom_minimum_size = Vector2(120, 40)
	var seg_sb := StyleBoxFlat.new()
	seg_sb.bg_color = Color("#f4e6c4")
	seg_sb.border_width_top = 2
	seg_sb.border_color = Colors.INK
	seg.add_theme_stylebox_override("panel", seg_sb)
	s.vbox.add_child(seg)
	await t.frames(2)
	_clean(t, "rules_r1_partial_border_segment_ok", UiAudit.rule_report(s, {"rules": ["r1"]}), "a parchment segment with a line on one side only (shop footer, journal sidebar) is a piece of an outlined panel, not a box without outline")
	seg_sb.border_width_top = 0
	await t.frames(2)
	_neg(t, "rules_r1_panel_without_any_border", UiAudit.rule_report(s, {"rules": ["r1"]}), "r1_no_ink_outline")
	await _drop(t, s)
	# R2: state-based
	var g := await _make(t, "menu")
	var tog := Button.new()
	tog.toggle_mode = true
	tog.text = "SET_DONE"
	tog.theme_type_variation = &"ButtonTertiary"
	var gold_box := StyleBoxFlat.new()
	gold_box.bg_color = C.GOLD
	gold_box.set_border_width_all(2)
	gold_box.border_color = C.INK
	tog.add_theme_stylebox_override("normal", gold_box)
	tog.custom_minimum_size = Vector2(0, 52)
	g.vbox.add_child(tog)
	await t.frames(2)
	_neg(t, "rules_r2_gold_normal_style_unselected", UiAudit.rule_report(g, {"rules": ["r2"]}), "r2_gold_decoration")
	tog.button_pressed = true
	var sel := UiAudit.rule_report(g, {"rules": ["r2"]})
	_clean(t, "rules_r2_gold_on_selected_ok", sel, "the same gold style on a pressed (selected) toggle is allowed")
	t.check("rules_r2_selected_listed_in_notes", (sel["notes"] as Array).any(func(n): return str(n["msg"]).contains("focused / pressed / selected")), "the allowed use is listed in the report notes")
	tog.button_pressed = false
	tog.set_meta(&"tt_gold_ok", "the guide's coin icon")
	var ok_meta := UiAudit.rule_report(g, {"rules": ["r2"]})
	_clean(t, "rules_r2_meta_exemption", ok_meta, "meta tt_gold_ok exempts a node and says why")
	t.check("rules_r2_meta_in_notes", (ok_meta["notes"] as Array).any(func(n): return str(n["msg"]).contains("the guide's coin icon")), "the exemption reason is in the notes")
	await _drop(t, g)
	var gd := await _make(t, "menu", "gold_decoration")
	_clean(t, "rules_option_ignore_subtree", UiAudit.rule_report(gd, {"rules": ["r2"], "ignore": ["*/GoldStripe", "*/GoldTag"]}), "options.ignore (glob) skips planted gold")
	await _drop(t, gd)
	# strict layer (spec 2.2 b): a theme-provided style that is gold while the control is not focused / selected
	var gt := await _make(t, "menu")
	var trap := Button.new()
	trap.text = "MENU_NEW_GAME"
	trap.custom_minimum_size = Vector2(200, 50)
	var gtheme := Theme.new()
	var gtrap_sb := StyleBoxFlat.new()
	gtrap_sb.bg_color = Colors.GOLD
	gtrap_sb.border_color = Colors.INK
	gtrap_sb.set_border_width_all(2)
	gtheme.set_stylebox("normal", "Button", gtrap_sb)
	trap.theme = gtheme
	gt.vbox.add_child(trap)
	await t.frames(2)
	_neg(t, "rules_r2_theme_provided_gold_normal_style", UiAudit.rule_report(gt, {"rules": ["r2"]}), "r2_gold_decoration")
	_clean(t, "rules_r2_strict_gold_off_option", UiAudit.rule_report(gt, {"rules": ["r2"], "strict_gold": false}), "options.strict_gold = false keeps only the per-node override scan")
	trap.theme_type_variation = &"ButtonSecondary"
	trap.theme = null
	await t.frames(2)
	_clean(t, "rules_r2_guide_gold_button_is_an_ornament", UiAudit.rule_report(gt, {"rules": ["r2"]}), "the guide's own gold button (ButtonSecondary) is on the ornament list")
	await _drop(t, gt)
	# R3 / typography / hit targets: options and exemptions
	var r3 := await _make(t, "menu")
	var mono := Label.new()
	mono.text = "1 / 2"
	mono.theme_type_variation = &"EyebrowL"
	r3.vbox.add_child(mono)
	var keycap := Label.new()
	keycap.text = "1"
	keycap.theme_type_variation = &"HotkeyDigit"
	r3.vbox.add_child(keycap)
	var tok := Label.new()
	tok.text = "INV_TITLE"
	tok.theme_type_variation = &"Muted14"
	r3.vbox.add_child(tok)
	var mono_num := Label.new()
	mono_num.text = "12"
	mono_num.theme_type_variation = &"EyebrowL"
	r3.vbox.add_child(mono_num)
	await t.frames(2)
	var lenient := UiAudit.rule_report(r3, {"rules": ["r3", "typography"]})
	_clean(t, "rules_mono_keycap_and_guide_tokens_ok", lenient, "mono '1 / 2' and '12', the hotbar digit and a 14 px guide token (Muted14) are allowed")
	mono_num.add_to_group(&"tt_number")
	_neg(t, "rules_r3_tt_number_group_overrides_the_mono_exemption", UiAudit.rule_report(r3, {"rules": ["r3"]}), "r3_number_not_display")
	mono_num.remove_from_group(&"tt_number")
	t.check("rules_tokens_listed_in_notes", (lenient["notes"] as Array).any(func(n): return str(n["msg"]).contains("Muted14")), "the small guide token is listed in the notes")
	_neg(t, "rules_strict_typography_flags_tokens", UiAudit.rule_report(r3, {"rules": ["typography"], "strict_typography": true}), "font_too_small_body")
	var d19 := Label.new()
	d19.text = "INV_TITLE"
	d19.theme_type_variation = &"Display19"
	r3.vbox.add_child(d19)
	await t.frames(2)
	var lenient_d := UiAudit.rule_report(r3, {"rules": ["typography"]})
	t.check("rules_display_token_below_20_is_a_note", not _has(lenient_d, "font_too_small_display") and (lenient_d["notes"] as Array).any(func(n): return str(n["msg"]).contains("Display19")), "the guide's own 19 px Caprasimo token (the tracked quest title) is a note, not a defect")
	_neg(t, "rules_strict_typography_flags_display_tokens", UiAudit.rule_report(r3, {"rules": ["typography"], "strict_typography": true}), "font_too_small_display")
	d19.queue_free()
	tok.add_theme_font_size_override("font_size", 5)
	_neg(t, "rules_font_floor", UiAudit.rule_report(r3, {"rules": ["typography"]}), "font_below_floor")
	_neg(t, "rules_hit_min_option", UiAudit.rule_report(r3, {"rules": ["hit_targets"], "hit_min": 80}), "hit_target_small")
	await _drop(t, r3)
	# R4: thorn-berry is the damage colour
	var r4 := await _make(t, "menu")
	var dmg := Label.new()
	dmg.text = "INV_TITLE"
	dmg.theme_type_variation = &"Body"
	dmg.add_theme_color_override("font_color", C.THORNBERRY)
	r4.vbox.add_child(dmg)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.custom_minimum_size = Vector2(200, 30)
	rich.text = "[color=red]!![/color]"
	r4.vbox.add_child(rich)
	await t.frames(2)
	var r4rep := UiAudit.rule_report(r4, {"rules": ["r4"]})
	t.check("rules_r4_thornberry_ok_bbcode_red_caught", r4rep["defects"].size() == 1 and _has(r4rep, "r4_red") and str(r4rep["defects"][0]["path"]).contains("RichTextLabel"), "thorn-berry text passes, a [color=red] tag is caught: %s" % UiAudit.summary(r4rep))
	await _drop(t, r4)
	# R4 on modulate and a Polygon2D, R2 on modulate
	var mod := await _make(t, "menu")
	var tint := ColorRect.new()
	tint.color = Color.WHITE
	tint.self_modulate = Color("#d62828")
	tint.custom_minimum_size = Vector2(0, 6)
	mod.vbox.add_child(tint)
	var gtint := ColorRect.new()
	gtint.color = Color.WHITE
	gtint.modulate = C.GOLD
	gtint.custom_minimum_size = Vector2(0, 6)
	mod.vbox.add_child(gtint)
	await t.frames(2)
	_neg(t, "rules_r4_self_modulate", UiAudit.rule_report(mod, {"rules": ["r4"]}), "r4_red")
	_neg(t, "rules_r2_modulate", UiAudit.rule_report(mod, {"rules": ["r2"]}), "r2_gold_decoration")
	await _drop(t, mod)
	# the per-node exemptions each take one planted defect away
	for spec in [["no_outline", "r1", "Panel", "tt_r1_ok"], ["number_body", "r3", "Panel/*/*/Money", "tt_r3_ok"], ["hit_small", "hit_targets", "*/TinyClose", "tt_hit_ok"]]:
		var ex := await _make(t, "menu", spec[0])
		var before := UiAudit.rule_report(ex, {"rules": [spec[1]]})
		var target: Node = ex.panel if spec[3] == "tt_r1_ok" else (ex.money if spec[3] == "tt_r3_ok" else ex.find_child("TinyClose", true, false))
		target.set_meta(StringName(spec[3]), "the guide draws it so")
		var after := UiAudit.rule_report(ex, {"rules": [spec[1]]})
		t.check("rules_meta_%s" % spec[3], not before["ok"] and after["ok"], "%s: %s without the meta, %s with it" % [spec[3], UiAudit.summary(before), UiAudit.summary(after)])
		await _drop(t, ex)
	var keyed := await _make(t, "menu")
	var same_key := Label.new()
	same_key.text = "SETTINGS_EN"
	same_key.theme_type_variation = &"Body"
	keyed.vbox.add_child(same_key)
	await t.frames(2)
	t.check("rules_flip_equal_translations_of_a_key_are_fine", TranslationServer.translate("SETTINGS_EN") == "English", "SETTINGS_EN is 'English' in Danish and English")
	_clean(t, "rules_flip_key_with_equal_translations", await UiAudit.locale_flip_report(t, keyed), "a translation KEY whose da and en text happen to be equal is localized by definition (not a defect)")
	await _drop(t, keyed)
	var same := await _make(t, "menu", "literal_flip")
	_neg(t, "rules_flip_same_text", await UiAudit.locale_flip_report(t, same), "not_localized")
	_clean(t, "rules_flip_same_ok_option", await UiAudit.locale_flip_report(t, same, {"same_ok": ["Trætoppen", "Typed in code"]}), "options.same_ok lists texts that are legitimately equal in both languages")
	same.find_child("Typed", true, false).set_meta(&"tt_text_same_ok", "a proper name")
	_clean(t, "rules_flip_same_ok_meta", await UiAudit.locale_flip_report(t, same), "meta tt_text_same_ok does the same for one node")
	await _drop(t, same)
	var bare_host := _host(t)
	var bare := Control.new()
	var only_label := Label.new()
	only_label.text = "INV_TITLE"
	bare.add_child(only_label)
	bare_host.add_child(bare)
	await t.frames(2)
	_neg(t, "neg_nothing_to_walk", await UiAudit.focus_walk(t, bare), "nothing_to_walk")
	bare_host.queue_free()
	await t.frames(2)
	# a CanvasLayer that is hidden hides its screen from the scan
	var layer_host := _host(t)
	var layer := CanvasLayer.new()
	layer_host.add_child(layer)
	var hidden_screen := Screen.new()
	hidden_screen.defect = "red_label"
	layer.add_child(hidden_screen)
	await t.frames(3)
	t.check("rules_scan_sees_a_visible_canvas_layer", not UiAudit.rule_report(hidden_screen, {"rules": ["r4"]})["ok"], "a screen on a CanvasLayer is scanned")
	layer.visible = false
	await t.frames(2)
	_clean(t, "rules_scan_skips_a_hidden_canvas_layer", UiAudit.rule_report(layer, {"rules": ["r4"]}), "a hidden CanvasLayer hides the whole screen from the scan")
	layer_host.queue_free()
	await t.frames(2)
	# copy: the static scan of a .tscn and of a script, key-shaped strings are fine
	var host := _host(t)
	var lit_scene: Node = (load("res://tests/fixtures/ui_audit/bad_literal.tscn") as PackedScene).instantiate()
	host.add_child(lit_scene)
	var lit_script := Control.new()
	lit_script.set_script(load("res://tests/fixtures/ui_audit/bad_literal_script.gd"))
	host.add_child(lit_script)
	await t.frames(3)
	var scene_rep := UiAudit.rule_report(lit_scene, {"rules": ["i18n"]})
	var script_rep := UiAudit.rule_report(lit_script, {"rules": ["i18n"]})
	_neg(t, "neg_hardcoded_literal_scene", scene_rep, "hardcoded_literal")
	t.check("rules_literal_scan_scene_exact", scene_rep["defects"].size() == 2 and str(scene_rep["defects"][0]["msg"]).contains("Hard coded caption") and str(scene_rep["defects"][1]["msg"]).contains("hard coded tooltip"), "the scene scan finds the caption and the tooltip, not the keys: %s" % UiAudit.summary(scene_rep))
	_neg(t, "neg_hardcoded_literal_script", script_rep, "hardcoded_literal")
	t.check("rules_literal_scan_script_exact", script_rep["defects"].size() == 1 and str(script_rep["defects"][0]["msg"]).contains("Hard coded welcome"), "the script scan finds the assigned sentence, not the key: %s" % UiAudit.summary(script_rep))
	var flip_scene := await UiAudit.locale_flip_report(t, lit_scene)
	_neg(t, "rules_flip_sees_scene_literals", flip_scene, "not_localized")
	host.queue_free()
	await t.frames(2)
	_clean(t, "rules_conforming_scene_scan", UiAudit.rule_report(await _scene_instance(t, "res://tests/fixtures/ui_audit/conforming.tscn"), {"rules": ["i18n"]}), "the conforming .tscn has no hard-coded copy")
	await _free_scene(t)


var _scene_host: Control


func _scene_instance(t, path: String) -> Node:
	_scene_host = _host(t)
	var n: Node = (load(path) as PackedScene).instantiate()
	_scene_host.add_child(n)
	await t.frames(3)
	return n


func _free_scene(t) -> void:
	if _scene_host != null:
		_scene_host.queue_free()
		_scene_host = null
	await t.frames(2)


# ---------------------------------------------------------------------------------------------------- the registry through a spy (statuses, routes, tripwires)

## Records what audit_screen asks of the harness without touching its counters.
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

	func move_mouse(position: Vector2) -> void:
		real.move_mouse(position)

	func has_window() -> bool:
		return real.has_window()

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

	func infos(prefix: String) -> Array[String]:
		var out: Array[String] = []
		for e in log:
			if e["kind"] == "info" and str(e["msg"]).begins_with(prefix):
				out.append(str(e["msg"]))
		return out


func _registry_semantics(t) -> void:
	UiAudit.use_registry(FIXTURE_REGISTRY)
	var sp := Spy.new(t)
	var r_live := await UiAudit.audit_screen(sp, "fx_live")
	var live_fail := sp.failed_checks()
	t.check("registry_live_screen_all_checks_pass", r_live["ok"] and live_fail.is_empty() and sp.checks().size() == 8, "fx_live runs 8 checks (visible + 7 listed) through a driver, all green: %s %s" % [str(sp.checks().map(func(c): return c["name"])), str(live_fail)])
	var sp2 := Spy.new(t)
	var r_scene := await UiAudit.audit_screen(sp2, "fx_scene")
	t.check("registry_scene_route_and_rule_subchecks", r_scene["ok"] and sp2.failed_checks().is_empty() and sp2.checks().size() == 9, "fx_scene (a .tscn): visible + initial_focus + r1 r2 r3 r4 typography i18n hit_targets, all green: %s" % str(sp2.failed_checks()))
	var sp3 := Spy.new(t)
	var r_hud := await UiAudit.audit_screen(sp3, "fx_hud")
	t.check("registry_hud_kind", r_hud["ok"] and sp3.checks().size() == 4 and sp3.failed_checks().is_empty(), "a hud entry runs visible + focusable (forbid focus) + rules + i18n_flip: %s" % str(sp3.failed_checks()))
	var sp4 := Spy.new(t)
	var r_modal := await UiAudit.audit_screen(sp4, "fx_modal")
	var sp5 := Spy.new(t)
	var r_pad := await UiAudit.audit_screen(sp5, "fx_modal_pad")
	t.check("registry_modal_escape_via_driver", r_modal["ok"] and r_pad["ok"] and sp4.failed_checks().is_empty() and sp5.failed_checks().is_empty() and sp4.checks().size() == 3, "a driver with open_level: depth 2 closed with the Esc key and with gamepad B: %s %s" % [str(sp4.failed_checks()), str(sp5.failed_checks())])
	var sp6 := Spy.new(t)
	var r_broken := await UiAudit.audit_screen(sp6, "fx_broken")
	var broken_failed := sp6.failed_checks()
	t.check("registry_live_failure_is_reported", not r_broken["ok"] and broken_failed == ["fx_broken.rules"] and sp6.log.any(func(e): return e["kind"] == "info" and str(e["msg"]).contains("r4_red")), "a live entry with a defect fails its check and prints the defect line: %s" % str(broken_failed))
	var sp7 := Spy.new(t)
	var r_mb := await UiAudit.audit_screen(sp7, "fx_modal_broken")
	t.check("registry_live_modal_failure", not r_mb["ok"] and sp7.failed_checks() == ["fx_modal_broken.escape"], "a live modal that ignores Esc fails its escape check: %s" % str(sp7.failed_checks()))
	var sph := Spy.new(t)
	var r_hidden := await UiAudit.audit_screen(sph, "fx_hidden")
	_neg(t, "neg_screen_not_visible", {"defects": r_hidden["defects"]}, "screen_not_visible")
	t.check("registry_hidden_screen_fails_visible_check", not r_hidden["ok"] and sph.failed_checks().has("fx_hidden.visible"), "a live entry whose screen is hidden fails 'visible' instead of passing on nothing: %s" % str(sph.failed_checks()))
	var spu := Spy.new(t)
	var r_unopen := await UiAudit.audit_screen(spu, "fx_unopenable")
	_neg(t, "neg_opens_failed", {"defects": r_unopen["defects"]}, "opens_failed")
	t.check("registry_unopenable_live_entry_fails", not r_unopen["ok"] and spu.failed_checks() == ["fx_unopenable.opens"], "a live entry whose scene is missing FAILS (a SKIP would be a silent green): %s" % str(spu.failed_checks()))
	var sp8 := Spy.new(t)
	var r_leg := await UiAudit.audit_screen(sp8, "fx_legacy")
	t.check("registry_legacy_known_gap_visible", r_leg["ok"] and sp8.infos("KNOWN-GAP fx_legacy").size() == 1 and sp8.failed_checks().is_empty() and sp8.checks().size() == 1 and sp8.checks()[0]["name"] == "fx_legacy.legacy_gap_no_initial_focus" and sp8.checks()[0]["ok"], "a legacy entry prints a KNOWN-GAP line and its listed gap is a passing check: %s" % str(sp8.infos("KNOWN-GAP")))
	var sp9 := Spy.new(t)
	var r_stale := await UiAudit.audit_screen(sp9, "fx_legacy_stale")
	t.check("registry_legacy_stale_tripwire", sp9.failed_checks() == ["fx_legacy_stale.legacy_gap_no_initial_focus"] and str(sp9.checks()[0]["detail"]).contains("flip"), "a legacy entry whose gap is gone fails and says to flip it to live: %s" % str(sp9.checks()[0]["detail"] if not sp9.checks().is_empty() else ""))
	var sp10 := Spy.new(t)
	var r_pend := await UiAudit.audit_screen(sp10, "fx_pending")
	t.check("registry_pending_is_skip_with_package", r_pend["skipped"] and sp10.log.size() == 1 and sp10.log[0]["kind"] == "skip" and str(sp10.log[0]["label"]).contains("pending (FX-package)") and str(sp10.log[0]["label"]).contains("fx_pending"), "a pending entry is one SKIP line with the package id: %s" % str(sp10.log[0]["label"] if not sp10.log.is_empty() else ""))
	var sp11 := Spy.new(t)
	var r_land := await UiAudit.audit_screen(sp11, "fx_pending_landed")
	t.check("registry_pending_scene_landed_tripwire", sp11.failed_checks() == ["fx_pending_landed.pending_scene_exists"] and str(sp11.checks()[0]["detail"]).contains("FX-package"), "a pending entry whose scene exists fails and names the package: %s" % str(sp11.checks()[0]["detail"] if not sp11.checks().is_empty() else ""))
	var sp12 := Spy.new(t)
	await UiAudit.audit_screen(sp12, "no_such_screen")
	t.check("registry_unknown_id_fails", sp12.log.size() == 1 and sp12.log[0]["kind"] == "fail", "audit_screen of an unknown id is a failure, not a silent pass")
	var sp13 := Spy.new(t)
	var all := await UiAudit.audit_all(sp13, ["live"])
	t.check("registry_audit_all", all.size() == UiAudit.screens_by_status("live").size() and all.size() >= 20 and all.has("fx_live") and not all.has("fx_legacy"), "audit_all(t, [live]) runs the live entries only (%d of %d live rows)" % [all.size(), UiAudit.screens_by_status("live").size()])
	var gm: Node = t.autoload("GameManager")
	gm.call("push_modal", &"audit_base")
	var sp_base := Spy.new(t)
	var r_base := await UiAudit.audit_screen(sp_base, "fx_modal")
	t.check("registry_restores_the_callers_modal_state", r_base["ok"] and gm.call("modal_stack") == [&"audit_base"] and t.tree.paused, "an audit run while the caller has a modal open (and the tree paused) leaves exactly that modal open and the tree paused: %s" % str(gm.call("modal_stack")))
	gm.call("pop_modal", &"audit_base")
	t.tree.paused = false
	# the navigation spec's rows (no status, scene / fixture / focus / esc_depth fields, check names = the API names)
	var sps := UiAudit.screen("sp_live")
	t.check("registry_spec_rows_derive_live", sps["status"] == "live" and sps["open"] == {"scene": "res://tests/fixtures/ui_audit/conforming.tscn"} and sps["kind"] == "scene" and sps["checks"] == ["initial_focus", "focusable_report", "rule_report"] and UiAudit.entry_checks(sps) == ["initial_focus", "focusable", "rules"], "a row without status whose scene exists is live; the row is returned as written (kind scene, checks focusable_report / rule_report) and the audit reads them as focusable / rules: %s" % str(UiAudit.entry_checks(sps)))
	t.check("registry_spec_rows_derive_pending_and_legacy", UiAudit.screen("sp_pending")["status"] == "pending" and UiAudit.screen("sp_legacy")["status"] == "legacy" and UiAudit.entry_kind(UiAudit.screen("sp_nofocus")) == "hud" and UiAudit.entry_kind(UiAudit.screen("sp_pending")) == "surface" and UiAudit.entry_kind(sps) == "screen", "no scene = pending, the old scaffold title = legacy, focus none = read as a hud row, kind scene = screen")
	t.check("registry_spec_row_prefers_its_fixture", UiAudit.screen("sp_fixture")["open"] == {"fixture": "components"} and UiAudit.screen("sp_fixture")["status"] == "live" and UiAudit.screen("sp_live")["open"].has("scene"), "a row whose fixture exists opens through the fixture (the owners' state set-up), otherwise through its scene: %s" % str(UiAudit.screen("sp_fixture")["open"]))
	var spl := Spy.new(t)
	var r_sp := await UiAudit.audit_screen(spl, "sp_live")
	t.check("registry_spec_row_runs", r_sp["ok"] and spl.failed_checks().is_empty() and spl.checks().size() == 4, "a derived-live spec row runs visible + its three checks: %s" % str(spl.failed_checks()))
	var spn := Spy.new(t)
	var r_nf := await UiAudit.audit_screen(spn, "sp_nofocus")
	t.check("registry_focus_none_row_is_audited_like_a_hud", not r_nf["ok"] and spn.failed_checks() == ["sp_nofocus.focusable"], "focus: none on a screen with focusable buttons fails: %s" % str(spn.failed_checks()))
	var spp := Spy.new(t)
	var r_spp := await UiAudit.audit_screen(spp, "sp_pending")
	t.check("registry_derived_pending_skips", r_spp["skipped"] and str(spp.log[0]["label"]).contains("FX-spec"), "a derived pending row is a SKIP line with its package")
	var sple := Spy.new(t)
	await UiAudit.audit_screen(sple, "sp_legacy")
	t.check("registry_derived_legacy_prints_known_gap", sple.infos("KNOWN-GAP sp_legacy").size() == 1, "a derived legacy row prints KNOWN-GAP lines: %s" % str(sple.infos("KNOWN-GAP")))
	var spm := Spy.new(t)
	var r_spm := await UiAudit.audit_screen(spm, "sp_modal")
	t.check("registry_spec_row_escape_without_driver", r_spm["ok"] and spm.failed_checks().is_empty() and spm.checks().any(func(c): return c["name"] == "sp_modal.escape" and c["ok"]), "a spec row (esc_depth 1, no driver): the screen opens its own layer, the audit presses Esc on it: %s %s" % [str(spm.failed_checks()), str(spm.checks().map(func(c): return c["name"]))])
	var spd := Spy.new(t)
	var r_spd := await UiAudit.audit_screen(spd, "sp_modal_two_layers")
	t.check("neg_registry_spec_row_escape_depth_claim", not r_spd["ok"] and spd.failed_checks() == ["sp_modal_two_layers.escape"], "esc_depth 1 on a scene that opens two layers fails the escape check: %s" % str(spd.failed_checks()))
	var seen_mismatch := _has({"defects": r_spd["defects"]}, "opener_depth_mismatch")
	t.check("neg_registry_spec_row_reports_depth_mismatch", seen_mismatch, "the defect is opener_depth_mismatch")
	if seen_mismatch:
		_seen["opener_depth_mismatch"] = true
	for skip_id in ["sp_modal_owner", "sp_scene_back"]:
		var spo := Spy.new(t)
		var r_spo := await UiAudit.audit_screen(spo, skip_id)
		t.check("registry_spec_row_%s_needs_the_owners_opener" % skip_id, r_spo["ok"] and spo.failed_checks().is_empty() and (r_spo["checks"]["escape"] as Dictionary).get("skipped", false) and str((r_spo["checks"]["escape"] as Dictionary)["notes"][0]["msg"]).contains("owner"), "esc_depth > 1 or a scene-back row cannot be proved without the owner's opener: skipped with a note: %s" % str((r_spo["checks"]["escape"] as Dictionary).get("notes", [])))
	var spi := Spy.new(t)
	var r_spi := await UiAudit.audit_screen(spi, "sp_esc_inert")
	t.check("registry_spec_row_esc_depth_zero_is_clean", r_spi["ok"] and spi.failed_checks().is_empty(), "esc_depth 0 with escape_chain listed runs the zero-depth chain: %s" % str(spi.failed_checks()))
	var spf := Spy.new(t)
	var r_spf := await UiAudit.audit_screen(spf, "sp_pending_fx")
	t.check("registry_derived_pending_has_no_tripwire", r_spf["skipped"] and spf.failed_checks().is_empty() and UiAudit.screen("sp_pending_fx")["status"] == "pending", "a derived pending row stays a SKIP even when its fixture's scene exists (no one edits the row to flip it)")
	var spx := Spy.new(t)
	var r_spx := await UiAudit.audit_screen(spx, "sp_pixels")
	t.check("registry_spec_row_pixel_checks_skip_headless", r_spx["ok"] and spx.failed_checks().is_empty(), "ring_pixels / panel_pixels / button_pixels / compare_guide of a row run without options (headless: skipped with a note): %s" % str(spx.failed_checks()))
	var sp14 := Spy.new(t)
	await UiAudit.audit_screen(sp14, "fx_live", {"checks": ["initial_focus"]})
	t.check("registry_overrides", sp14.checks().size() == 2, "audit_screen(t, id, overrides) can narrow the check list (visible + initial_focus)")
	var sp15 := Spy.new(t)
	var bad_check := await UiAudit.audit_screen(sp15, "fx_live", {"checks": ["nonsense"]})
	_neg(t, "neg_registry_unknown_check", {"defects": bad_check["defects"]}, "registry_error")
	var sp16 := Spy.new(t)
	var no_driver := await UiAudit.audit_screen(sp16, "fx_scene", {"checks": ["escape"]})
	_neg(t, "neg_registry_escape_without_driver", {"defects": no_driver["defects"]}, "registry_error")
	UiAudit.use_registry("")
	t.check("registry_default_restored", not UiAudit.screen("title").is_empty() and UiAudit.screen("fx_live").is_empty(), "use_registry('') switches back to tests/lib/ui_screens.json")
	var _unused := [r_land, r_stale]


# ---------------------------------------------------------------------------------------------------- the project theme

func _names(items: Array, key: String) -> Array:
	var out: Array = []
	for i in items:
		var v := str(i[key])
		if not out.has(v):
			out.append(v)
	return out


func _theme(t) -> void:
	var rep := UiAudit.theme_report()
	_clean(t, "theme_clean", rep, "%d theme types: no red, ink outlines on every light panel / button / field, a gold focus style on every focusable type" % rep["types"])
	# negative: a theme with a red colour and a flat parchment panel
	var th := Theme.new()
	th.set_color("font_color", "Label", Color("#d62828"))
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color("#f4e6c4")
	th.set_stylebox("panel", "PanelContainer", flat)
	var blue := StyleBoxFlat.new()
	blue.draw_center = false
	blue.border_color = Color("#3b6fd6")
	blue.set_border_width_all(2)
	th.set_stylebox("focus", "Button", blue)
	th.set_stylebox("normal", "Button", flat)
	var bad := UiAudit.theme_report(th)
	_neg(t, "neg_theme_red", bad, "r4_red")
	_neg(t, "neg_theme_r1", bad, "r1_no_ink_outline")
	_neg(t, "neg_theme_focus_not_gold", bad, "focus_style_not_gold_theme")
	# the lists the spec asks for are always there; the strict_* options turn them into defects (the committed theme still has the gaps of spec Appendix E)
	var strict := UiAudit.theme_report(null, {"strict_gold_hover": true, "strict_focus_styles": true, "strict_font_scale": true})
	var keys_ok := true
	for k in ["gold_hover", "red", "ink", "font_scale", "focus_styles"]:
		keys_ok = keys_ok and rep.has(k) and rep[k] is Array
	t.check("theme_report_spec_keys", keys_ok and (strict["defects"] as Array).size() >= (rep["defects"] as Array).size(), "gold_hover / red / ink / font_scale / focus_styles are arrays; strict mode only ever adds defects (%d -> %d)" % [(rep["defects"] as Array).size(), (strict["defects"] as Array).size()])
	t.info("theme known gaps (strict options): %d gold hover / grabber styles %s, no focus style on %s" % [(rep["gold_hover"] as Array).size(), str(_names(rep["gold_hover"], "variation")), str(rep["focus_styles"])])
	var th2 := Theme.new()
	var gold_fill := StyleBoxFlat.new()
	gold_fill.bg_color = load("res://scripts/ui/theme/tt_colors.gd").GOLD
	gold_fill.border_color = load("res://scripts/ui/theme/tt_colors.gd").INK
	gold_fill.set_border_width_all(2)
	th2.set_stylebox("normal", "Button", gold_fill)
	th2.set_stylebox("hover", "MenuRow", gold_fill)
	th2.set_type_variation("MenuRow", "Button")
	var lenient := UiAudit.theme_report(th2)
	t.check("theme_gold_hover_is_a_list_by_default", not _has(lenient, "theme_gold_hover") and (lenient["gold_hover"] as Array).size() >= 1, "default: the gold hover styles are listed, not failed: %s" % str(lenient["gold_hover"]))
	_neg(t, "neg_theme_gold_hover", UiAudit.theme_report(th2, {"strict_gold_hover": true}), "theme_gold_hover")
	var th3 := Theme.new()
	th3.set_stylebox("normal", "Button", gold_fill)
	th3.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	_neg(t, "neg_theme_focus_empty", UiAudit.theme_report(th3, {"strict_focus_styles": true}), "theme_focus_empty")
	t.check("theme_focus_empty_is_a_list_by_default", (UiAudit.theme_report(th3)["focus_styles"] as Array).has("Button") and not _has(UiAudit.theme_report(th3), "theme_focus_empty"), "an empty focus style is listed by default and fails with options.strict_focus_styles")
	var th4 := Theme.new()
	th4.set_font("font", "Label", load("res://assets/fonts/Caprasimo-Regular.ttf"))
	th4.set_font_size("font_size", "Label", 12)
	_neg(t, "neg_theme_font_scale", UiAudit.theme_report(th4, {"strict_font_scale": true}), "theme_font_scale")
	t.check("theme_font_scale_is_a_list_by_default", not (UiAudit.theme_report(th4)["font_scale"] as Array).is_empty() and not _has(UiAudit.theme_report(th4), "theme_font_scale"), "a 12 px Caprasimo label is listed in font_scale and fails only with strict_font_scale")


# ---------------------------------------------------------------------------------------------------- the spec's helper tools

## The first value inside a report that is not plain JSON data (bool / int / float / String / Array / Dictionary with String keys / null); "" when all of it is.
func _json_violation(v: Variant, path := "report") -> String:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return ""
		TYPE_ARRAY:
			var i := 0
			for e in v:
				var bad := _json_violation(e, "%s[%d]" % [path, i])
				if bad != "":
					return bad
				i += 1
			return ""
		TYPE_DICTIONARY:
			for k in v:
				if typeof(k) != TYPE_STRING:
					return "%s has a key of type %d: %s" % [path, typeof(k), str(k)]
				var bad2 := _json_violation(v[k], "%s.%s" % [path, k])
				if bad2 != "":
					return bad2
			return ""
	return "%s is a %s (type %d): %s" % [path, type_string(typeof(v)), typeof(v), str(v)]


func _tools(t) -> void:
	# every report is plain JSON data (spec 10: "a plain Dictionary / Array of Strings and numbers"), so a package can print it, diff it or save it
	var js := await _make(t, "menu")
	var json_reports := {
		"focusable_report": UiAudit.focusable_report(js),
		"initial_focus_report": UiAudit.initial_focus_report(js),
		"focus_walk": await UiAudit.focus_walk(t, js, 300),
		"rule_report": UiAudit.rule_report(js),
		"locale_flip_report": await UiAudit.locale_flip_report(t, js),
		"text_field_audit": await UiAudit.text_field_audit(t, js),
		"mouse_walk": await UiAudit.mouse_walk(t, js),
		"theme_report": UiAudit.theme_report(),
		"scene_text_report": UiAudit.scene_text_report("res://tests/fixtures/ui_audit/bad_literal.tscn"),
		"script_text_report": UiAudit.script_text_report("res://tests/fixtures/ui_audit/bad_literal_script.gd"),
	}
	var json_bad: Array[String] = []
	for rname in json_reports:
		var why := _json_violation(json_reports[rname], rname)
		if why != "":
			json_bad.append(why)
	t.check("reports_are_plain_json_data", json_bad.is_empty(), "no Rect2 / Vector2 / StringName / Node inside any report: %s" % str(json_bad))
	t.check("reports_survive_a_json_round_trip", JSON.parse_string(JSON.stringify(json_reports["focusable_report"])) is Dictionary and JSON.parse_string(JSON.stringify(json_reports["focus_walk"])) is Dictionary, "JSON.stringify -> parse_string works on focusable_report and focus_walk")
	await _drop(t, js)
	# mouse_walk: hovering a control must not take keyboard focus (only list-like rows do); a click must not drop it
	var m := await _make(t, "menu")
	var mw := await UiAudit.mouse_walk(t, m, {"click": ["*Button1"]})
	_clean(t, "mouse_walk_conforming", mw, "hover over %d focusable controls grabs nothing, a click on Button1 keeps focus" % (mw["hover_focus"] as Array).size())
	var rows := await UiAudit.mouse_walk(t, m, {"list_like": ["*Button1"]})
	_neg(t, "neg_mouse_walk_missing_grab", rows, "hover_no_focus")
	await _drop(t, m)
	var mh := await _make(t, "menu", "hover_grab")
	_neg(t, "neg_mouse_walk_hover_grabs_focus", await UiAudit.mouse_walk(t, mh), "hover_grabs_focus")
	var rows_ok := await UiAudit.mouse_walk(t, mh, {"list_like": ["*Button2"]})
	t.check("mouse_walk_list_like_row_may_grab", not _has(rows_ok, "hover_grabs_focus"), "a control named as list-like may take focus on hover: %s" % UiAudit.summary(rows_ok))
	await _drop(t, mh)
	var mc := await _make(t, "menu", "click_drops")
	_neg(t, "neg_mouse_walk_click_drops_focus", await UiAudit.mouse_walk(t, mc, {"click": ["*Button1"]}), "click_drops_focus")
	await _drop(t, mc)
	# rule_report: the spec's group keys, built from the defects
	var g := await _make(t, "menu", "red_label")
	var rr := UiAudit.rule_report(g)
	var group_ok := true
	for k in ["r1_ink", "r2_gold", "r3_numbers", "r4_red", "typography", "overrides", "raw_keys", "hard_coded", "hit_targets"]:
		group_ok = group_ok and rr.has(k) and rr[k] is Array
	var cnt: Dictionary = rr["counts"]
	t.check("rule_report_spec_groups", group_ok and not (rr["r4_red"] as Array).is_empty() and (rr["r4_red"][0] as Dictionary).has("path") and (rr["r4_red"][0] as Dictionary).has("variation") and (rr["r4_red"][0] as Dictionary).has("detail"), "every group is an Array of {path, variation, detail}; the planted red label is in r4_red: %s" % str(rr["r4_red"]))
	t.check("rule_report_counts", int(cnt.get("controls", 0)) > 3 and int(cnt.get("labels", 0)) >= 1 and cnt.has("styleboxes"), "counts: %s" % str(cnt))
	await _drop(t, g)
	var gl := await _make(t, "menu", "raw_key")
	var sweep := await UiAudit.rule_report_locales(t, gl, ["da", "en"])
	_neg(t, "rule_report_locales_finds_raw_key", sweep, "raw_key")
	t.check("rule_report_locales_restores_locale", TranslationServer.get_locale().begins_with("da"), "the locale sweep restores the caller's language (%s)" % TranslationServer.get_locale())
	await _drop(t, gl)
	var en_only := Control.new()
	en_only.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var en_label := Label.new()
	en_label.set_script(EnLabel)
	en_only.add_child(en_label)
	var host_en := _host(t)
	host_en.add_child(en_only)
	await t.frames(3)
	_clean(t, "rule_report_in_danish_misses_the_english_key", UiAudit.rule_report(en_only, {"rules": ["i18n"]}), "a single-locale scan (da) sees nothing: the label only shows a raw key in English")
	var sweep_en := await UiAudit.rule_report_locales(t, en_only, ["da", "en"], {"rules": ["i18n"]})
	_neg(t, "neg_rule_report_locales_english_only_key", sweep_en, "raw_key")
	t.check("rule_report_locales_tags_the_locale", (sweep_en["defects"] as Array).any(func(d): return d.get("locale", "") == "en"), "the defect found only in English carries locale = en")
	var red_screen := await _make(t, "menu", "red_label")
	var red_sweep := UiAudit.rule_report(red_screen, {"rules": ["r4"], "locale_sweep": ["da", "en"]})
	var red_n := (red_sweep["defects"] as Array).filter(func(d): return d["code"] == "r4_red").size()
	var red_single := UiAudit.rule_report(red_screen, {"rules": ["r4"]})
	t.check("rule_report_locale_sweep_does_not_repeat_a_defect", red_n >= 1 and red_n == (red_single["defects"] as Array).filter(func(d): return d["code"] == "r4_red").size(), "a defect that exists in both languages is reported once (%d, the single-locale scan has %d)" % [red_n, (red_single["defects"] as Array).size()])
	await _drop(t, red_screen)
	var sync_sweep := UiAudit.rule_report(en_only, {"rules": ["i18n"], "locale_sweep": ["da", "en"]})
	_neg(t, "neg_rule_report_locale_sweep_option_is_synchronous", sync_sweep, "raw_key")
	t.check("rule_report_locale_sweep_tags_and_restores", (sync_sweep["defects"] as Array).any(func(d): return d.get("locale", "") == "en") and TranslationServer.get_locale().begins_with("da") and en_label.text == "Hej", "the sweep option (no await) finds the key that exists only in English, tags it locale = en and puts the caller's language back (%s, label '%s')" % [TranslationServer.get_locale(), en_label.text])
	await _drop(t, host_en)
	# the library's own health check (spec 10.11: UiAudit.selftest ships with the library)
	var st := await UiAudit.selftest(t)
	var st_bad: Array = (st["controls"] as Array).filter(func(c): return not c["ok"])
	t.check("selftest_every_control_behaves", st["ok"] and (st["controls"] as Array).size() >= 10 and st_bad.is_empty(), "%d controls (planted defects found, conforming ones clean): %s" % [(st["controls"] as Array).size(), str(st_bad)])
	t.check("selftest_is_plain_data", _json_violation(st, "selftest") == "", "the selftest report is JSON data")
	var blind := {"defects": [] as Array, "ok": true, "controls": [] as Array}
	UiAudit._selftest_control(blind, "planted", "r4_red", {"defects": []})
	t.check("neg_selftest_blind", _has(blind, "selftest_blind") and not blind["controls"][0]["ok"], "a planted control that the report does not contain is selftest_blind")
	var dirty := {"defects": [] as Array, "ok": true, "controls": [] as Array}
	UiAudit._selftest_clean(dirty, "conforming", {"defects": [{"code": "r4_red"}]})
	t.check("neg_selftest_false_positive", _has(dirty, "selftest_false_positive") and not dirty["controls"][0]["ok"], "a conforming control that the report flags is selftest_false_positive")
	# device_swap: one real event of the device, never an action
	var catcher := _DeviceCatcher.new()
	t.root.add_child(catcher)
	for dev in ["keyboard", "pad", "mouse"]:
		catcher.seen.clear()
		await UiAudit.device_swap(t, dev)
		var want_class: String = {"keyboard": "InputEventKey", "pad": "InputEventJoypadButton", "mouse": "InputEventMouseMotion"}[dev]
		t.check("device_swap_%s_sends_a_real_event" % dev, catcher.seen.has(want_class) and not catcher.seen.has("InputEventAction"), "device_swap(%s) -> %s" % [dev, str(catcher.seen)])
	catcher.queue_free()
	# a screen that says it is not open
	var closed := Control.new()
	closed.set_script(ClosedScreen)
	var host_c := _host(t)
	host_c.add_child(closed)
	await t.frames(2)
	_neg(t, "neg_screen_not_open", UiAudit.initial_focus_report(closed), "screen_not_open")
	await _drop(t, host_c)
	# the text scans
	var scn := UiAudit.scene_text_report("res://tests/fixtures/ui_audit/bad_literal.tscn")
	t.check("scene_text_report_finds_literals", not scn["ok"] and (scn["hard_coded"] as Array).size() >= 1 and (scn["hard_coded"][0] as Dictionary).has("node") and (scn["hard_coded"][0] as Dictionary).has("text"), "the planted .tscn: %s" % str(scn["hard_coded"]))
	var scn_ok := UiAudit.scene_text_report("res://tests/fixtures/ui_audit/conforming.tscn")
	t.check("scene_text_report_conforming", scn_ok["ok"], "the conforming .tscn has no hard-coded copy (keys: %s)" % str(scn_ok["keys"]))
	var scr := UiAudit.script_text_report("res://tests/fixtures/ui_audit/bad_literal_script.gd")
	t.check("script_text_report_finds_literals", not scr["ok"] and (scr["literals"] as Array).size() >= 1 and (scr["literals"][0] as Dictionary).has("line"), "the planted script: %s" % str(scr["literals"]))
	t.check("script_text_report_conforming", UiAudit.script_text_report("res://tests/fixtures/ui_audit/modals.gd")["ok"], "a script with no UI copy is clean")
	# expect(): a report becomes one harness check
	var spy_ok := Spy.new(t)
	var ok_rep := UiAudit.focusable_report(await _make(t, "menu"))
	var passed := UiAudit.expect(spy_ok, ok_rep, "tool_expect_ok")
	t.check("expect_passes_a_clean_report", passed and spy_ok.checks().size() == 1 and spy_ok.failed_checks().is_empty(), "expect() records one passing check")
	var spy_bad := Spy.new(t)
	var bad_rep := UiAudit.focusable_report(await _make(t, "menu", "no_focus_style"))
	var failed := UiAudit.expect(spy_bad, bad_rep, "tool_expect_bad")
	t.check("expect_fails_a_defective_report", not failed and spy_bad.failed_checks() == ["tool_expect_bad"], "expect() records one failing check carrying the defects: %s" % str(spy_bad.failed_checks()))
	for h in t.root.get_children():
		if h.name == "AuditHost":
			h.queue_free()
	await t.frames(2)
	# open_screen / close_screen
	UiAudit.use_registry("res://tests/fixtures/ui_audit/ui_screens_fixture.json")
	var opened: Node = await UiAudit.open_screen(t, "fx_live")
	t.check("open_screen_returns_the_root", opened != null and opened.is_inside_tree() and opened.is_visible_in_tree(), "open_screen opens a registry screen and returns its live root")
	if opened != null:
		_clean(t, "open_screen_root_is_auditable", UiAudit.focusable_report(opened), "the opened root can be audited by hand")
	await UiAudit.close_screen(t, "fx_live")
	t.check("close_screen_frees_the_root", opened == null or not is_instance_valid(opened) or opened.is_queued_for_deletion() or not opened.is_inside_tree(), "close_screen removes the opened screen")
	UiAudit.use_registry("")


# ---------------------------------------------------------------------------------------------------- the real registry: gallery (live), legacy title / select (KNOWN-GAP), the rest (SKIP)

func _real_screens(t) -> void:
	var gal := await UiAudit.audit_screen(t, "foundation_gallery")
	t.check("foundation_gallery_live", gal["status"] == "live" and gal["ok"] and not gal["skipped"], "the P07 components gallery (guide page) passes every listed check: %s" % [gal["checks"].keys()])
	var rar := await UiAudit.audit_screen(t, "foundation_gallery_rarity")
	t.check("foundation_gallery_rarity_live", rar["status"] == "live" and rar["ok"], "the rarity page passes too: %s" % [rar["checks"].keys()])
	var gw: Dictionary = (gal["checks"] as Dictionary).get("focus_walk", {})
	t.check("foundation_gallery_walk_depth", int(gw.get("expected", 0)) >= 15 and int(gw.get("reached", 0)) == int(gw.get("expected", 0)), "the real gallery walk: %s of %s controls reached in %s presses" % [gw.get("reached"), gw.get("expected"), gw.get("steps")])
	# Production menus are live; preserved legacy scenes still exercise every old defect.
	for id in ["title", "select_1"]:
		var out := await UiAudit.audit_screen(t, id)
		t.check("production_%s_live" % id, out["status"] == "live" and out["ok"], UiAudit.summary(out))
	UiAudit.use_registry("res://tests/fixtures/ui_audit/ui_screens_fixture.json")
	for id in ["archive_title", "archive_select"]:
		var spy := Spy.new(t)
		var out := await UiAudit.audit_screen(spy, id)
		var codes := {}
		for defect in out["defects"]:
			codes[str(defect["code"])] = true
		t.check("legacy_%s_detected" % id, out["status"] == "legacy" and codes.has("no_initial_focus") and codes.has("hardcoded_literal") and codes.has("not_localized"), str(codes.keys()))
		t.check("legacy_%s_is_not_silent_green" % id, not out["defects"].is_empty() and not spy.infos("KNOWN-GAP").is_empty())
	UiAudit.use_registry("")
	# every other entry: pending, one SKIP line each with the package id
	var pending := UiAudit.screens_by_status("pending")
	var skipped := 0
	for s in pending:
		var o := await UiAudit.audit_screen(t, str(s["id"]))
		if o["skipped"]:
			skipped += 1
	t.check("pending_entries_skip", skipped == pending.size() and pending.size() + UiAudit.screens_by_status("live").size() + UiAudit.screens_by_status("legacy").size() == UiAudit.screens().size(), "%d pending screens are SKIP lines naming their package (a package that lands a scene must flip its entry)" % pending.size())
	var path := OS.get_environment("UI_AUDIT_REPORT")
	if path != "":
		_write_report(t, path)


## Evidence for "the keyboard cannot start navigating": open the legacy scene, press ui_down (nothing moves), press Tab (the first button wakes up).
func _legacy_keyboard_probe(t, id: String) -> void:
	var entry := UiAudit.screen(id)
	var host := _host(t)
	var node: Node = (load(str((entry["open"] as Dictionary)["scene"])) as PackedScene).instantiate()
	host.add_child(node)
	await t.frames(3)
	var vp: Viewport = t.root
	var at_open := vp.gui_get_focus_owner()
	UiAudit.press(t, &"ui_down")
	await t.frames(1)
	var after_down := vp.gui_get_focus_owner()
	UiAudit.press(t, &"ui_focus_next")
	await t.frames(1)
	var after_tab := vp.gui_get_focus_owner()
	var line := "%s: focus owner when the screen opens = %s; after ui_down = %s; after Tab (ui_focus_next) = %s" % [id, at_open.name if at_open != null else "NONE", after_down.name if after_down != null else "NONE", after_tab.name if after_tab != null else "NONE"]
	_legacy.append({"screen": id, "check": "probe", "code": "keyboard_start", "path": id, "msg": line})
	t.check("legacy_%s_keyboard_cannot_start" % id, at_open == null and after_down == null, line)
	host.queue_free()
	await t.frames(2)


func _write_report(t, path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		t.info("UI_AUDIT_REPORT: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	f.store_line("LEGACY UI AUDIT - what UiAudit (tests/lib/ui_audit.gd) reports today for the old scaffold screens that package P16-ui-menus replaces.")
	f.store_line("Produced by: UI_AUDIT_REPORT=<this file> tests/run_playtest.sh --only=ui_audit   (section tests/sections/ui_audit.gd, run in an APFS clone of the ui-audit worktree)")
	f.store_line("Screens: title = scenes/main/main_menu.tscn, select_1 (and select_2, the same scene today) = scenes/ui/character_select.tscn (registry tests/lib/ui_screens.json, status legacy; hit targets are judged at 32 px, spec 10.6).")
	f.store_line("In the harness every one of these findings prints as a KNOWN-GAP line (never green), and each listed gap is a check that fails once it disappears.")
	f.store_line("")
	for id in ["title", "select_1"]:
		var counts := {}
		for e in _legacy:
			if e["screen"] == id:
				counts[e["code"]] = int(counts.get(e["code"], 0)) + 1
		f.store_line("== %s: %d findings" % [id, _count_of(id)])
		for code in counts:
			var what := "with no initial focus the keyboard cannot start: ui_down moves nothing, only Tab wakes the first control" if code == "keyboard_start" else str((UiAudit.DEFECTS.get(code, ["", ""]) as Array)[1])
			f.store_line("   %-22s x%d   (%s)" % [code, counts[code], what])
	f.store_line("")
	f.store_line("== all findings (screen / check / defect code / node path or file:line / message)")
	for e in _legacy:
		f.store_line("%-7s %-12s %-22s %s : %s" % [e["screen"], e["check"], e["code"], e["path"], e["msg"]])
	f.store_line("")
	f.store_line("== screens with NO scene today (status pending: one SKIP line each, a failing check the day their scene appears without the entry being flipped to live)")
	for s in UiAudit.screens_by_status("pending"):
		f.store_line("   %-14s %-38s %s" % [s["id"], s["package"], str(s.get("note", "-"))])
	f.store_line("   (the farm shows NO HUD today: scripts/ui/hud.gd has no scene; pause_menu.gd and save_load_ui.gd have none either)")
	f.store_line("")
	f.store_line("== what this audit does NOT see (pixels, windowed): the flat dark background, the dark-on-dark title text, the plain pills, the missing key art / panel /")
	f.store_line("   double gold edge / 'Dag N', the missing race cards, ring, chips and preview. Those are measured by tests/checkpoints/compare_guide.py (title 7.5, select 14.7")
	f.store_line("   in the UI spike must not regress) and by LOOKING at the windowed screenshots.")
	f.close()
	t.info("UI_AUDIT_REPORT: %d legacy findings written to %s" % [_legacy.size(), path])


func _count_of(id: String) -> int:
	var n := 0
	for e in _legacy:
		if e["screen"] == id:
			n += 1
	return n


# ---------------------------------------------------------------------------------------------------- coverage of the negative tests

func _coverage(t) -> void:
	# every code the library RAISES is in the catalogue (so that it also needs a negative test): derived from the source, a new code cannot dodge the check
	var raised: Array[String] = []
	var rx := RegEx.new()
	rx.compile("(?:_defect\\([A-Za-z_]+,\\s*|\"code\":\\s*)\"([a-z][a-z0-9_]+)\"")
	for path in ["res://tests/lib/ui_audit.gd", "res://tests/lib/ui_audit_rules.gd"]:
		for m in rx.search_all(FileAccess.get_file_as_string(path)):
			if not raised.has(m.get_string(1)):
				raised.append(m.get_string(1))
	var uncatalogued: Array[String] = []
	for code in raised:
		if not UiAudit.DEFECTS.has(code) and code not in UiAudit.META_DEFECTS:
			uncatalogued.append(code)
	t.check("every_raised_code_is_catalogued", uncatalogued.is_empty() and raised.size() >= 60, "%d codes found in the library source, each in UiAudit.DEFECTS (or a selftest meta code); missing %s" % [raised.size(), str(uncatalogued)])
	var missing: Array[String] = []
	for code in UiAudit.DEFECTS:
		if code in UiAudit.WINDOWED_ONLY:
			continue
		if not _seen.has(code):
			missing.append(code)
	t.check("every_defect_code_has_a_negative_test", missing.is_empty(), "%d of %d defect codes were reported against a planted defect, windowed-only %s; missing %s" % [_seen.size(), UiAudit.DEFECTS.size(), str(UiAudit.WINDOWED_ONLY), str(missing)])
	t.skip("ui_audit ring_pixels (ring_missing, ring_always_on): windowed only, see run_windowed")


# ---------------------------------------------------------------------------------------------------- windowed: the ring is in the frame

func run_windowed(t) -> void:
	TranslationServer.set_locale("da")
	var host := _host(t)
	var s := Screen.new()
	host.add_child(s)
	await t.frames(4)
	# a conforming screen: the gold ring of a focused button, a focused field, and the negative controls
	var b2: Button = s.buttons[1]
	var rep := await UiAudit.ring_pixels(t, s.buttons[0], {"shot": "ring_button", "other": b2})
	_clean(t, "ring_focused_button", rep, "gold ring around the focused button: %s of %s sample pixels gold, %s when it is not focused" % [rep.get("focused_hits"), rep.get("samples"), rep.get("unfocused_hits")])
	t.check("ring_negative_control_not_gold", int(rep.get("unfocused_hits", 99)) <= 1 and int(rep.get("other_hits", 99)) <= 1, "the same pixels are not gold once focus is gone (%s), and an unfocused sibling shows none (%s)" % [rep.get("unfocused_hits"), rep.get("other_hits")])
	_clean(t, "ring_focused_field", await UiAudit.ring_pixels(t, s.field, {"shot": "ring_field"}), "the LineEdit's focus style draws the gold ring too")
	_clean(t, "ring_focused_button3", await UiAudit.ring_pixels(t, s.buttons[2], {"shot": "ring_button3"}))
	var rs := await UiAudit.ring_pixels(t, s.slider, {"shot": "ring_slider"})
	_clean(t, "ring_focused_slider", rs, "the ring slider paints the focus style itself: %s of %s sample pixels gold, %s when not focused" % [rs.get("focused_hits"), rs.get("samples"), rs.get("unfocused_hits")])
	var img: Image = await t.capture("ring_fixture_screen")
	if img != null:
		t.expect_not_blank(img, Rect2i(0, 0, 1280, 720), "the fixture screen renders")
	await _drop(t, s)
	# planted: the focus style is blue (not the guide's gold): ring_missing; an always-drawn gold frame: ring_always_on
	var s2 := await _make(t, "menu", "focus_blue")
	var blue := await UiAudit.ring_pixels(t, s2.buttons[0], {"shot": "ring_blue"})
	_neg(t, "ring_neg_blue_style_is_ring_missing", blue, "ring_missing")
	await _drop(t, s2)
	var s3 := await _make(t, "menu", "no_focus_style")
	var none := await UiAudit.ring_pixels(t, s3.buttons[0], {"shot": "ring_none"})
	_neg(t, "ring_neg_empty_style_is_ring_missing", none, "ring_missing")
	await _drop(t, s3)
	var cs := await _make(t, "components")
	var focus_row: Control = cs.find_child("FocusRow", true, false)
	var custom := await UiAudit.ring_pixels(t, focus_row, {"shot": "ring_custom"})
	_clean(t, "ring_custom_control_declared_style", custom, "a custom focusable control declares its ring with the meta tt_focus_style: %s of %s sample pixels gold" % [custom.get("focused_hits"), custom.get("samples")])
	var shot: Image = await t.capture("components_screen")
	if shot != null:
		t.expect_not_blank(shot, Rect2i(0, 0, 1280, 720), "the components fixture screen (real components, no rule fires) renders")
	await _drop(t, cs)
	var cn := await _make(t, "components", "custom_no_ring")
	_neg(t, "ring_neg_custom_control_never_draws_its_ring", await UiAudit.ring_pixels(t, cn.find_child("FocusRow", true, false), {"shot": "ring_custom_missing"}), "ring_missing")
	await _drop(t, cn)
	var s_plain := await _make(t, "menu", "slider_no_ring")
	var plain_ring := await UiAudit.ring_pixels(t, s_plain.slider, {"shot": "ring_plain_slider"})
	_neg(t, "ring_neg_plain_slider_is_ring_missing", plain_ring, "ring_missing")
	await _drop(t, s_plain)
	var s4 := await _make(t, "menu")
	var target: Button = s4.buttons[1]
	var frame := Panel.new()
	frame.name = "AlwaysGold"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", target.get_theme_stylebox("focus"))
	s4.add_child(frame)
	frame.global_position = target.global_position
	frame.size = target.size
	await t.frames(3)
	var always := await UiAudit.ring_pixels(t, target, {"shot": "ring_always_on"})
	_neg(t, "ring_neg_always_drawn_is_ring_always_on", always, "ring_always_on")
	var via_other := await UiAudit.ring_pixels(t, s4.buttons[0], {"shot": "ring_other_always_on", "other": target})
	t.check("ring_neg_other_control_always_on", _has(via_other, "ring_always_on") and not (via_other["defects"] as Array).is_empty() and str(via_other["defects"][0]["path"]).ends_with(str(target.name)), "options.other: the unfocused sibling that shows a ring is reported by name: %s" % UiAudit.summary(via_other))
	if _has(via_other, "ring_always_on"):
		_seen["ring_always_on"] = true
	await _drop(t, s4)
	await _windowed_profiles(t)
	# the real foundation gallery: a focused chip, a pill tab, the primary button
	var ghost := _host(t)
	var gallery: Control = (load("res://scenes/ui/dev/components_gallery.tscn") as PackedScene).instantiate()
	ghost.add_child(gallery)
	await t.frames(4)
	var buy: Button = gallery.get_node("%BuyButton")
	var gr := await UiAudit.ring_pixels(t, buy, {"shot": "ring_gallery_buy"})
	_clean(t, "ring_gallery_primary_button", gr, "the gallery's primary button: %s of %s gold when focused" % [gr.get("focused_hits"), gr.get("samples")])
	var chip := gallery.find_child("Chip0", true, false) as Button
	if chip != null:
		_clean(t, "ring_gallery_chip", await UiAudit.ring_pixels(t, chip, {"shot": "ring_gallery_chip"}))
	var res := await UiAudit.audit_screen(t, "foundation_gallery")
	t.check("ring_gallery_audit_screen_windowed", res["status"] == "live" and res["ok"], "audit_screen of the gallery also passes in a window")
	ghost.queue_free()
	await t.frames(2)
	var spy_ring := Spy.new(t)
	UiAudit.use_registry(FIXTURE_REGISTRY)
	await UiAudit.audit_screen(spy_ring, "fx_live", {"checks": ["initial_focus", "ring"]})
	UiAudit.use_registry("")
	t.check("ring_registry_check", spy_ring.failed_checks().is_empty() and spy_ring.checks().size() == 3, "the 'ring' registry check passes on the conforming fixture: %s" % str(spy_ring.checks()))
	# a spec row names the windowed checks only: the audit picks the panel / button itself (or notes there is none) and compare_guide is the python tool's business
	var spy_px := Spy.new(t)
	UiAudit.use_registry(FIXTURE_REGISTRY)
	var px := await UiAudit.audit_screen(spy_px, "sp_pixels")
	UiAudit.use_registry("")
	t.check("registry_spec_row_pixel_checks_windowed", px["ok"] and spy_px.failed_checks().is_empty() and spy_px.checks().size() == 4, "visible + ring + panel_pixels + button_pixels on a spec row (compare_guide is the python tool: noted, no check): %s" % str(spy_px.checks().map(func(c): return "%s=%s" % [c["name"], c["ok"]])))
	# a live gallery screen: the auto-picked panel and raised button match the guide (the pixel proof for a row nobody configured)
	var gal_host := _host(t)
	var gal: Control = (load("res://scenes/ui/dev/components_gallery.tscn") as PackedScene).instantiate()
	gal_host.add_child(gal)
	await t.frames(4)
	var pn := UiAudit._auto_pick(gal, true)
	var bn := UiAudit._auto_pick(gal, false)
	t.check("auto_pick_finds_gallery_controls", bn != null, "the auto-pick finds a raised button on the gallery (%s) and %s" % [str(bn.name) if bn != null else "none", "a double-edge panel (%s)" % pn.name if pn != null else "no double-edge panel"])
	if bn != null:
		_clean(t, "auto_picked_button_matches_the_guide", await UiAudit.button_pixels(t, bn, {"shot": "button_gallery_auto"}), "the gallery's first raised button has the guide profile")
	if pn != null:
		_clean(t, "auto_picked_panel_matches_the_guide", await UiAudit.panel_pixels(t, pn, {"shot": "panel_gallery_auto"}), "the gallery's largest double-edge panel has the guide edge")
	await _drop(t, gal_host)


## ring kinds, the ink band, expect none, the panel edge and the button profile (windowed negatives and positives)
func _windowed_profiles(t) -> void:
	var host := _host(t)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 8)
	box.add_theme_constant_override("separation", 6)
	host.add_child(box)
	var row := Button.new()
	row.theme_type_variation = &"MenuRow"
	row.text = "MenuRow"
	row.custom_minimum_size = Vector2(300, 52)
	var row2 := Button.new()
	row2.theme_type_variation = &"MenuRow"
	row2.text = "MenuRow 2"
	row2.custom_minimum_size = Vector2(300, 52)
	var gold_only := Button.new()
	gold_only.text = "Gold only"
	gold_only.custom_minimum_size = Vector2(300, 52)
	var sb := BoxStyle.new()
	sb.draw_body = false
	sb.body_inset = Vector4(0, 2, 0, 4)
	sb.ring_colors = PackedColorArray([Colors.GOLD])
	sb.ring_widths = PackedFloat32Array([3.0])
	gold_only.add_theme_stylebox_override("focus", sb)
	var primary := Button.new()
	primary.theme_type_variation = &"ButtonPrimary"
	primary.text = "Primary"
	primary.custom_minimum_size = Vector2(300, 60)
	var flat := Button.new()
	flat.text = "Flat"
	flat.custom_minimum_size = Vector2(300, 60)
	var flat_sb := StyleBoxFlat.new()
	flat_sb.bg_color = Colors.GOLD
	flat.add_theme_stylebox_override("normal", flat_sb)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelParchment"
	panel.custom_minimum_size = Vector2(300, 90)
	var panel_flat := PanelContainer.new()
	panel_flat.custom_minimum_size = Vector2(300, 90)
	var pf := StyleBoxFlat.new()
	pf.bg_color = Color("#f4e6c4")
	panel_flat.add_theme_stylebox_override("panel", pf)
	for c in [row, row2, gold_only, primary, flat, panel, panel_flat]:
		box.add_child(c)
	await t.frames(4)
	var fill := await UiAudit.ring_pixels(t, row, {"shot": "ring_menu_row_fill"})
	t.check("ring_fill_kind_is_sampled_inside", fill["kind"] == "fill" and fill["ok"], "a gold-fill focus look (menu row) is sampled inside the body: kind %s, %s" % [fill.get("kind"), UiAudit.summary(fill)])
	var ring := await UiAudit.ring_pixels(t, primary, {"shot": "ring_primary_kind"})
	t.check("ring_kind_is_ring_for_buttons", ring["kind"] == "ring" and ring["ok"] and ring["gold_ok"] and ring["ink_ok"], "a button's focus look is a ring with an ink band: gold_ok %s ink_ok %s of %s sampled" % [ring.get("gold_ok"), ring.get("ink_ok"), (ring.get("sampled", []) as Array).size()])
	_neg(t, "ring_neg_gold_only_ring_has_no_ink_band", await UiAudit.ring_pixels(t, gold_only, {"shot": "ring_gold_only"}), "ring_ink_missing")
	row2.release_focus()
	await t.frames(2)
	_clean(t, "ring_expect_none_on_an_unfocused_row", await UiAudit.ring_pixels(t, row2, {"focus": false, "expect": "none"}), "an unfocused row shows neither ring nor fill")
	row2.grab_focus()
	await t.frames(3)
	_neg(t, "ring_neg_expect_none_on_a_focused_row", await UiAudit.ring_pixels(t, row2, {"focus": false, "expect": "none"}), "ring_always_on")
	_clean(t, "ring_focus_false_samples_a_persistent_ring", await UiAudit.ring_pixels(t, row2, {"focus": false}), "focus:false samples the control as it is (a selected row's persistent look)")
	row2.release_focus()
	var pr := await UiAudit.panel_pixels(t, panel, {"shot": "panel_parchment"})
	_clean(t, "panel_pixels_guide_panel", pr, "the guide panel edge reads parchment / ink / gold / ink: %s" % str(pr.get("profile")))
	_neg(t, "panel_neg_flat_panel", await UiAudit.panel_pixels(t, panel_flat, {"shot": "panel_flat"}), "panel_edge_wrong")
	var th_real := ThemeDB.get_project_theme()
	var inset_sb: StyleBox = th_real.get_stylebox("panel", "PanelParchment").duplicate()
	inset_sb.set("body_inset", Vector4(10, 10, 10, 10))
	var panel_inset := PanelContainer.new()
	panel_inset.custom_minimum_size = Vector2(300, 110)
	panel_inset.add_theme_stylebox_override("panel", inset_sb)
	box.add_child(panel_inset)
	var no_underside := Button.new()
	no_underside.text = "No underside"
	no_underside.custom_minimum_size = Vector2(300, 60)
	var nu_sb: StyleBox = th_real.get_stylebox("normal", "ButtonPrimary").duplicate()
	nu_sb.set("hard_shadow", 0.0)
	no_underside.add_theme_stylebox_override("normal", nu_sb)
	box.add_child(no_underside)
	await t.frames(3)
	_clean(t, "panel_pixels_follows_the_style_body_inset", await UiAudit.panel_pixels(t, panel_inset, {"shot": "panel_inset"}), "a panel whose style insets its body is measured from the body edge, not the control rect")
	var bp := await UiAudit.button_pixels(t, primary, {"shot": "button_primary"})
	_clean(t, "button_pixels_guide_button", bp, "the primary button reads ink border / face / band / ink border / underside: %s" % str(bp.get("profile")))
	_neg(t, "button_neg_flat_button", await UiAudit.button_pixels(t, flat, {"shot": "button_flat"}), "button_profile_wrong")
	_neg(t, "button_neg_missing_underside", await UiAudit.button_pixels(t, no_underside, {"shot": "button_no_underside"}), "button_profile_wrong")
	_clean(t, "button_underside_false_option", await UiAudit.button_pixels(t, no_underside, {"underside": false}), "options.underside = false: a button that has none is measured without it")
	await _drop(t, box)
