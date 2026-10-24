extends RefCounted
## Section ui_conformance (package P28-ui-nav-foundation, docs/design/UI_NAVIGATION.md 2, 4.6, 4.8, 7): "do the menus and navigations follow our guide?" as checks.
##
##   theme          the theme builder's output against the guide's rules: no gold hover, no red, ink outline, the type scale, focus styles on every interactive type, the
##                  PillTab / Chip heights, the three calendar-cell variations, FocusProxy, Bold14 / Bold16, and the sliders of every scene being a TTSlider
##   guide crops    tests/checkpoints/guide_ref_ui is pinned (SHA256SUMS and a fresh crop of the render) and the `<screen>_guide` fixtures show only what the mock shows
##   sweep          U1 - U6 and U9 of 7.1 on every LIVE row of UiAudit.screens() (both locales; screens with radio tabs through the page-aware reports) and the legacy gate
##   mutants        eleven planted defects, each built on a clone of the foundation gallery (or a stand-in screen) that the matching check must CATCH
##   windowed       (run_windowed) ring / fill, panel edge and button underside pixels on the gallery and on every live screen
##
## Named checks: theme_no_gold_hover, theme_no_red, theme_ink_outline, theme_font_scale, theme_focus_styles, theme_calcell_variations, theme_label_variations_and_proxy,
## pill_heights, sliders_are_ttslider, guide_crops_pinned, fixtures_guide_focus_released, fixtures_guide_extras_hidden, fixtures_all_registry_fixtures_resolve,
## live_screens_sweep (+ one check per live row and check), no_legacy_screens_left, mutant_*, windowed_rings, windowed_panels, windowed_buttons, saveload_adjacent_autosave_rings.
const SECTION := "ui_conformance"
const TIMEOUT_S := 600.0

const Nav = preload("res://tests/sections/ui_nav.gd")
const Fixtures = preload("res://scripts/ui/dev/ui_fixtures.gd")
const Rules = preload("res://tests/lib/ui_audit_rules.gd")
const C = preload("res://scripts/ui/theme/tt_colors.gd")
const BoxStyle = preload("res://scripts/ui/theme/tt_box_style.gd")
const GALLERY := "res://scenes/ui/dev/components_gallery.tscn"
const CROP_DIR := "res://tests/checkpoints/guide_ref_ui"
## variations of the double-edge panel (4 px gold + 2 px ink outside the rect)
const PANEL_VARIATIONS: Array[StringName] = [&"PanelParchment", &"PanelParchmentL", &"PanelParchmentL24", &"PanelBook", &"PanelMenu", &"PanelHud", &"PanelHearts", &"PanelHotbar"]

var _t
var _host: Control
var _nav


# ---------------------------------------------------------------------------------------------------- run

func run(t) -> void:
	_t = t
	await t.clear_scene()
	TranslationServer.set_locale("da")
	_nav = Nav.new()
	_theme(t)
	_pill_heights(t)
	_sliders_are_ttslider(t)
	_guide_crops(t)
	await _fixtures(t)
	await _mutants(t)
	await _sweep(t)
	_legacy_gate(t)
	TranslationServer.set_locale("da")


# ---------------------------------------------------------------------------------------------------- helpers

func _theme_of(theme: Theme = null) -> Theme:
	return theme if theme != null else ThemeDB.get_project_theme()


func _fresh(t) -> Control:
	_drop_host()
	t.root.gui_release_focus()
	_host = Control.new()
	_host.name = "ConformanceHost"
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	t.root.add_child(_host)
	return _host


func _drop_host() -> void:
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	_host = null


func _codes(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for d in report.get("defects", []):
		if not out.has(str(d["code"])):
			out.append(str(d["code"]))
	return out


func _has_code(report: Dictionary, code: String) -> bool:
	return code in _codes(report)


func _variation_fill(theme: Theme, ty: String, state: String) -> Color:
	var sb := theme.get_stylebox(state, ty)
	return sb.get("fill") if sb != null and sb.get_script() == BoxStyle else Color(0, 0, 0, 0)


func _has_gold(sb: StyleBox) -> bool:
	for col in Rules.style_colors(sb):
		if Rules.is_gold(col):
			return true
	return false


# ---------------------------------------------------------------------------------------------------- theme

## Variations whose normal / hover / disabled styles may be gold are the guide's ornaments (GOLD_ORNAMENT of the audit library); everything else shows gold only when
## focused or selected. The scan is the library's own, in strict mode.
func gold_hover_hits(theme: Theme = null) -> Array:
	return Rules.theme_scan(_theme_of(theme), {"strict_gold_hover": true})["gold_hover"]


func _theme(t) -> void:
	var theme := _theme_of()
	# --- no gold hover (4.6 item 1, Appendix E): the library's strict scan, and the variations the debt list names
	var rep: Dictionary = UiAudit.theme_report(theme, {"strict_gold_hover": true})
	var named := {}
	var offenders: Array[String] = []
	for ty in ["MenuRow", "ChoiceRow", "Chip", "StepperButton", "HintButton", "PopupMenu", "PillTab", "RowButton", "CardButton"]:
		var hover := theme.get_stylebox("hover", ty)
		named[ty] = hover != null and not _has_gold(hover)
		if not bool(named[ty]):
			offenders.append(ty)
	# the gold that STAYS: the focus look and the selected (pressed) look of the rows, chips and tabs
	var stays_ok := true
	for ty in ["MenuRow", "ChoiceRow"]:
		stays_ok = stays_ok and _has_gold(theme.get_stylebox("focus", ty)) and _has_gold(theme.get_stylebox("pressed", ty))
	for ty in ["Chip", "PillTab"]:
		stays_ok = stays_ok and _has_gold(theme.get_stylebox("pressed", ty)) and _has_gold(theme.get_stylebox("focus", ty))
	# sliders: moss fill, a chalk grabber, scrollbar thumbs that are not gold
	var slider_ok: bool = not _has_gold(theme.get_stylebox("grabber_area", "HSlider")) and not _has_gold(theme.get_stylebox("grabber_area_highlight", "HSlider")) \
		and _variation_fill(theme, "HSlider", "grabber_area").is_equal_approx(C.MOSS) and theme.get_constant("center_grabber", "HSlider") == 0
	var scroll_ok := true
	for tn in ["VScrollBar", "HScrollBar"]:
		for st in ["grabber", "grabber_highlight", "grabber_pressed", "scroll"]:
			scroll_ok = scroll_ok and not _has_gold(theme.get_stylebox(st, tn))
		scroll_ok = scroll_ok and _variation_fill(theme, tn, "grabber").is_equal_approx(C.DIVIDER) and _variation_fill(theme, tn, "grabber_highlight").is_equal_approx(C.CHALK) \
			and _variation_fill(theme, tn, "grabber_pressed").is_equal_approx(C.MOSS_HOVER) and float(theme.get_stylebox("grabber", tn).get("border_width")) == 2.0 \
			and Rules.is_ink(theme.get_stylebox("grabber", tn).get("border_color"))
	# the grabber icons are chalk discs with an ink outline (no gold in the SVG)
	var svg := FileAccess.get_file_as_string("res://assets/ui/icons/slider_grabber.svg") + FileAccess.get_file_as_string("res://assets/ui/icons/slider_grabber_hi.svg")
	var svg_ok: bool = svg.to_lower().contains("#fbf5e6") and svg.to_lower().contains("#2b2340") and not svg.to_lower().contains("#e3c372") and not svg.to_lower().contains("#ecd189")
	t.check("theme_no_gold_hover", bool(rep["ok"]) and (rep["defects"] as Array).is_empty() and offenders.is_empty() and stays_ok and slider_ok and scroll_ok and svg_ok and gold_hover_hits().is_empty(),
		"strict theme scan clean (%s); the hover of %s is not gold (offenders %s); focus and pressed stay gold on rows, chips, tabs (%s); sliders are moss with a chalk grabber and center_grabber 0 (%s), scrollbar thumbs are divider / chalk / moss with a 2 px ink outline (%s), the grabber SVGs have no gold (%s)" % [UiAudit.summary(rep), named.keys(), str(offenders), stays_ok, slider_ok, scroll_ok, svg_ok])
	# --- no red
	var red: Dictionary = UiAudit.theme_report(theme)
	t.check("theme_no_red", (red["red"] as Array).is_empty() and not _has_code(red, "r4_red"), "no colour item or StyleBox of the theme has a red hue (%d types scanned)" % int(red.get("types", 0)))
	# --- ink outline on every body box outside the exempt list
	t.check("theme_ink_outline", (red["ink"] as Array).is_empty() and not _has_code(red, "r1_no_ink_outline"), "every opaque light body StyleBox outside R1_EXEMPT has a 2 px ink border: %s" % str(red["ink"]))
	# --- the type scale
	var scale: Dictionary = UiAudit.theme_report(theme, {"strict_font_scale": true})
	var bold_ok: bool = theme.get_type_variation_base("Bold16") == &"Label" and theme.get_font_size("font_size", "Bold16") == 16 and theme.get_type_variation_base("Bold14") == &"Label" and theme.get_font_size("font_size", "Bold14") == 14
	t.check("theme_font_scale", (scale["font_scale"] as Array).is_empty() and not _has_code(scale, "theme_font_scale") and bold_ok, "every Label / Button variation is on the scale (Caprasimo >= 15, Alegreya >= 11, mono >= 9) %s; Bold16 / Bold14 exist (%s)" % [str(scale["font_scale"]), bold_ok])
	# --- focus styles: every interactive type has a gold focus StyleBox (FocusProxy excepted); the HSlider entry is the ring TTSlider paints
	var focus: Dictionary = UiAudit.theme_report(theme, {"strict_focus_styles": true})
	var slider_focus: StyleBox = theme.get_stylebox("focus", "HSlider") if theme.has_stylebox("focus", "HSlider") else null
	var slider_ring: bool = slider_focus != null and slider_focus.get_script() == BoxStyle and (slider_focus.get("ring_colors") as PackedColorArray).size() == 2 and Rules.is_gold((slider_focus.get("ring_colors") as PackedColorArray)[0]) and Rules.is_ink((slider_focus.get("ring_colors") as PackedColorArray)[1]) and not bool(slider_focus.get("draw_body"))
	var field_focus: StyleBox = theme.get_stylebox("focus", "PanelField") if theme.has_stylebox("focus", "PanelField") else null
	var field_ring: bool = field_focus != null and _has_gold(field_focus)
	t.check("theme_focus_styles", (focus["focus_styles"] as Array).is_empty() and not _has_code(focus, "theme_focus_empty") and not _has_code(focus, "focus_style_not_gold") and slider_ring and field_ring,
		"every interactive theme type has a non-empty gold focus StyleBox %s; HSlider/focus is the selection ring (3 px gold + 2 px ink, ring only: %s) that TTSlider paints; PanelField/focus is the ring of the stepper (%s)" % [str(focus["focus_styles"]), slider_ring, field_ring])
	_calcell(t, theme)
	_label_variations_and_proxy(t, theme)


## RT10: the calendar tab's three cell looks, replacing the prototype's StyleBox overrides.
func _calcell(t, theme: Theme) -> void:
	var ok := true
	var notes: Array[String] = []
	for ty in ["CalCell", "CalCellFest", "CalCellToday"]:
		var exists: bool = ty in theme.get_type_list() and theme.get_type_variation_base(ty) == &"Button"
		ok = ok and exists
		if not exists:
			notes.append("%s missing or not a Button variation" % ty)
			continue
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			if not theme.has_stylebox(st, ty):
				ok = false
				notes.append("%s/%s missing" % [ty, st])
	if ok:
		var idle: StyleBox = theme.get_stylebox("normal", "CalCell")
		var fest: StyleBox = theme.get_stylebox("normal", "CalCellFest")
		var today: StyleBox = theme.get_stylebox("normal", "CalCellToday")
		# CalCell: the RowButton look, parchment-dark fill (the page shows through: alpha .9), radius 10, a 2 px divider border
		var idle_ok: bool = float(idle.get("border_width")) == 2.0 and (idle.get("border_color") as Color).is_equal_approx(C.DIVIDER) and float(idle.get("radius")) == 10.0 \
			and Rules.color_close(Color(idle.get("fill"), 1.0), C.PARCHMENT_DARK, 1.0) and Color(idle.get("fill")).a >= 0.85
		# CalCellFest: lavender-pale fill, ink border
		var fest_ok: bool = (fest.get("fill") as Color).is_equal_approx(C.LAVENDER_PALE) and Rules.is_ink(fest.get("border_color")) and float(fest.get("border_width")) >= 2.0 and float(fest.get("radius")) == 10.0
		# CalCellToday: a 3 px ink border, no gold
		var today_ok: bool = float(today.get("border_width")) == 3.0 and Rules.is_ink(today.get("border_color")) and float(today.get("radius")) == 10.0
		var gold_free := true
		for ty in ["CalCell", "CalCellFest", "CalCellToday"]:
			for st in ["normal", "hover", "disabled", "pressed", "hover_pressed"]:
				gold_free = gold_free and not _has_gold(theme.get_stylebox(st, ty))
			gold_free = gold_free and _has_gold(theme.get_stylebox("focus", ty))          # gold stays for FOCUS only
		ok = idle_ok and fest_ok and today_ok and gold_free
		if not ok:
			notes.append("idle %s, fest %s, today %s, gold only on focus %s" % [idle_ok, fest_ok, today_ok, gold_free])
	t.check("theme_calcell_variations", ok, "CalCell (RowButton look, parchment-dark, radius 10, 2 px divider), CalCellFest (lavender-pale, ink border), CalCellToday (3 px ink border) exist as Button variations with every state, no gold but the focus ring %s" % str(notes))


## Bold14 / Bold16 (the screens may use theme variations only), FocusProxy (five empty states + focus), PromptVerb (the prompt pill's chalk verb), and that the theme file is the builder's output.
func _label_variations_and_proxy(t, theme: Theme) -> void:
	var proxy_ok: bool = theme.get_type_variation_base("FocusProxy") == &"Button"
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		proxy_ok = proxy_ok and theme.has_stylebox(st, "FocusProxy") and theme.get_stylebox(st, "FocusProxy") is StyleBoxEmpty
	var verb_ok: bool = theme.get_type_variation_base("PromptVerb") == &"Label" and theme.get_font_size("font_size", "PromptVerb") == 18 and theme.get_color("font_color", "PromptVerb").is_equal_approx(C.CHALK)
	# a Button wearing the proxy draws nothing (no body, no ring) and still takes focus
	var host := _fresh(t)
	var b := Button.new()
	b.theme_type_variation = &"FocusProxy"
	host.add_child(b)
	var inert: bool = b.get_theme_stylebox("normal") is StyleBoxEmpty and b.get_theme_stylebox("focus") is StyleBoxEmpty and b.focus_mode == Control.FOCUS_ALL
	_drop_host()
	t.check("theme_label_variations_and_proxy", proxy_ok and verb_ok and inert, "FocusProxy: six empty StyleBoxes and still focusable (%s / %s), PromptVerb is Heavy 18 chalk (%s)" % [proxy_ok, inert, verb_ok])


func _pill_heights(t) -> void:
	var host := _fresh(t)
	var heights := {}
	for pair in [["PillTab", "Aktive · 4"], ["Chip", "Ræv"]]:
		var b := Button.new()
		b.theme_type_variation = StringName(pair[0])
		b.text = pair[1]
		host.add_child(b)
		heights[pair[0]] = b.get_combined_minimum_size().y
	_drop_host()
	var row_opts: Dictionary = UiAudit.screen("foundation_gallery").get("options", {})
	var ok: bool = float(heights["PillTab"]) >= 33.0 and float(heights["Chip"]) >= 37.0 and not row_opts.has("hit_min")
	t.check("pill_heights", ok, "PillTab %.0f px (>= 33), Chip %.0f px (>= 37) high: the guide's heights with the 2 px border; the gallery row's temporary hit_min is gone (%s)" % [heights["PillTab"], heights["Chip"], not row_opts.has("hit_min")])


# ---------------------------------------------------------------------------------------------------- sliders are TTSlider

## Every `HSlider` / `VSlider` node of a scene, and every `HSlider.new()` / `VSlider.new()` of a script under `scene_dir` / `script_dir` (recursive).
func slider_offenders(scene_dir: String, script_dir: String) -> Array[String]:
	var out: Array[String] = []
	for path in _files(scene_dir, ".tscn"):
		var text := FileAccess.get_file_as_string(path)
		var slider_scripts: Array[String] = []
		for line in text.split("\n"):
			if line.begins_with("[ext_resource ") and line.contains('path="res://scripts/ui/components/tt_slider.gd"'):
				slider_scripts.append(line.get_slice('id="', 1).get_slice('"', 0))
		# Godot serializes a scripted TTSlider as HSlider + its Script resource.
		for block in text.split("[node "):
			var header := block.get_slice("\n", 0)
			if not (header.contains('type="HSlider"') or header.contains('type="VSlider"')):
				continue
			var real_slider := false
			for id in slider_scripts:
				real_slider = real_slider or block.contains('script = ExtResource("%s")' % id)
			if not real_slider:
				out.append("%s: %s" % [path, header.get_slice('name="', 1).get_slice('"', 0)])
	for path in _files(script_dir, ".gd"):
		var text2 := FileAccess.get_file_as_string(path)
		for needle in ["HSlider.new()", "VSlider.new()"]:
			if text2.contains(needle):
				out.append("%s: %s" % [path, needle])
	return out


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_files(full, ext))
		elif name.ends_with(ext):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out


func _sliders_are_ttslider(t) -> void:
	var offenders := slider_offenders("res://scenes/ui", "res://scripts/ui")
	# TTSlider itself: an HSlider that paints the theme's focus ring and declares it
	var host := _fresh(t)
	var s := TTSlider.new()
	host.add_child(s)
	var declared: bool = s.has_meta(&"tt_focus_style") and s.get_meta(&"tt_focus_style") == s.get_theme_stylebox(&"focus") and s is HSlider
	var grown := s.focus_rect()
	var rect_ok: bool = grown == Rect2(Vector2.ZERO, s.size)                    # center_grabber 0 in the theme: the ring hugs the control
	s.add_theme_constant_override(&"center_grabber", 1)
	var wider := s.focus_rect()
	var grow_ok: bool = wider.size.x > s.size.x and absf(wider.position.x + s.get_theme_icon(&"grabber").get_width() * 0.5) < 0.01       # center_grabber 1: grown by half a grabber at both ends
	_drop_host()
	t.check("sliders_are_ttslider", offenders.is_empty() and declared and rect_ok and grow_ok, "no scene of scenes/ui and no script of scripts/ui makes a plain HSlider / VSlider %s; TTSlider declares tt_focus_style (%s), its ring hugs the control (%s) and grows by half a grabber when the grabber is centred on the ends (%s)" % [str(offenders), declared, rect_ok, grow_ok])


# ---------------------------------------------------------------------------------------------------- guide crops and the `_guide` fixtures

func _python() -> String:
	var venv := ProjectSettings.globalize_path("res://tools/art/.venv/bin/python")
	return venv if FileAccess.file_exists(venv) else ""


func _guide_crops(t) -> void:
	var sums := FileAccess.get_file_as_string(CROP_DIR + "/SHA256SUMS")
	var listed := {}
	for line in sums.split("\n", false):
		var parts := line.split("  ", false)
		if parts.size() == 2:
			listed[parts[1].strip_edges()] = parts[0].strip_edges()
	var drift: Array[String] = []
	for name in listed:
		var path := "%s/%s" % [CROP_DIR, name]
		if not FileAccess.file_exists(path):
			drift.append("%s missing" % name)
		elif FileAccess.get_sha256(path) != listed[name]:
			drift.append("%s differs from SHA256SUMS" % name)
	var pngs: Array[String] = []
	var d := DirAccess.open(CROP_DIR)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".png"):
				pngs.append(f)
	var unlisted: Array[String] = []
	for f in pngs:
		if not listed.has(f):
			unlisted.append(f)
	var ignore_ok := FileAccess.file_exists(CROP_DIR + "/.gdignore") and FileAccess.file_exists(CROP_DIR + "/README.md")
	var size_ok := true
	var img := Image.load_from_file(ProjectSettings.globalize_path(CROP_DIR + "/dialogue_box.png"))
	size_ok = img != null and img.get_size() == Vector2i(680, 300)
	# a fresh crop of the render is byte-identical (the tool's own --check, Pillow in the project venv)
	var py := _python()
	var regen := ""
	var regen_ok := true
	if py == "":
		t.skip("ui_conformance.guide_crops_pinned: the project venv (tools/art/.venv) is missing in this tree: the regeneration check is skipped, the hashes above are checked")
	else:
		var res: Dictionary = t.run_tool(py, PackedStringArray(["-I", ProjectSettings.globalize_path("res://tools/ui/crop_guide_refs.py"), "--check"]))
		regen_ok = int(res["code"]) == 0
		regen = str(res["output"]).strip_edges()
	t.check("guide_crops_pinned", listed.has("dialogue_box.png") and drift.is_empty() and unlisted.is_empty() and ignore_ok and size_ok and regen_ok,
		"%d crop(s) hash to SHA256SUMS %s, no unlisted PNG %s, 680 x 300 (%s), .gdignore + README (%s); fresh crop of the render: %s" % [listed.size(), str(drift), str(unlisted), size_ok, ignore_ok, regen if regen != "" else "skipped"])


## A stand-in screen with everything a guide fixture has to deal with: a HintBar, a toast stack, a %BackButton, ring controls and a gold-fill row.
func _fake_screen(t, host: Control) -> Dictionary:
	var screen := Nav.TestScreen.new()
	screen.name = "FakeScreen"
	screen.screen_id = &"fake_guide"
	screen.modal_name = &"fake_guide"
	screen.with_field = false
	host.add_child(screen)
	await t.frames(1)
	var bar: HintBar = (load("res://scenes/ui/components/hint_bar.tscn") as PackedScene).instantiate()
	screen.add_child(bar)
	bar.set_hints([{"action": &"ui_accept", "key": "HINT_OK"}])
	var stack: ToastStack = (load("res://scenes/ui/components/toast_stack.tscn") as PackedScene).instantiate()
	screen.add_child(stack)
	var back := Button.new()
	back.name = "BackButton"
	back.unique_name_in_owner = true
	screen.add_child(back)
	var card := Button.new()
	card.name = "Card"
	card.theme_type_variation = &"CardButton"
	card.position = Vector2(600, 100)
	screen.add_child(card)
	var row := Button.new()
	row.name = "Row"
	row.text = "MENU_CONTINUE"
	row.theme_type_variation = &"MenuRow"
	row.position = Vector2(600, 200)
	screen.add_child(row)
	await t.frames(2)
	var bus: Node = t.autoload("EventBus")
	bus.notification_posted.emit("NOTIF_SAVED_TITLE", "NOTIF_SAVED_MSG", "save")
	await t.frames(2)
	return {"screen": screen, "bar": bar, "stack": stack, "back": back, "card": card, "row": row}


func _fixtures(t) -> void:
	var host := _fresh(t)
	var gm: Node = t.autoload("GameManager")
	gm.call("pop_all_modals")
	var fx: Dictionary = await _fake_screen(t, host)
	var screen: Nav.TestScreen = fx["screen"]
	var bar: HintBar = fx["bar"]
	var stack: ToastStack = fx["stack"]
	var back: Button = fx["back"]
	var card: Button = fx["card"]
	var row: Button = fx["row"]
	# 1. title_guide: Fortsæt (a MenuRow) KEEPS its focus (the mock paints it gold), the HintBar and the toasts are hidden
	screen.open()
	await t.frames(2)
	var shown_before: bool = bar.is_visible_in_tree() and stack.is_visible_in_tree() and back.is_visible_in_tree() and stack.toasts().size() == 1
	row.grab_focus()
	await t.frames(1)
	Fixtures.apply_guide_rules("title_guide", host)
	await t.frames(2)
	var title_ok: bool = _focus_name(t) == "Row" and not bar.is_visible_in_tree() and not stack.is_visible_in_tree() and back.is_visible_in_tree()    # %BackButton is the SELECT page's extra
	# 2. select_guide: focus on a ring control (a card) is RELEASED (the mock draws no ring), %BackButton, HintBar and toasts are hidden, the screen's guard stays off
	card.grab_focus()
	await t.frames(1)
	Fixtures.apply_guide_rules("select_guide", host)
	await t.frames(3)
	var select_ok: bool = t.root.gui_get_focus_owner() == null and not back.is_visible_in_tree() and not bar.is_visible_in_tree() and not stack.is_visible_in_tree() and not screen.focus_guard
	# 3. a force-hidden bar stays hidden when the device changes
	await UiAudit.device_swap(t, "pad")
	await UiAudit.device_swap(t, "keyboard")
	var sticky_ok := not bar.visible
	# 4. every other ring control is released as well; a ChoiceRow keeps it (the dialogue's first choice)
	var choice := Button.new()
	choice.name = "Choice"
	choice.theme_type_variation = &"ChoiceRow"
	choice.position = Vector2(600, 300)
	screen.add_child(choice)
	await t.frames(1)
	choice.grab_focus()
	Fixtures.apply_guide_rules("dialogue_guide", host)
	await t.frames(2)
	var choice_ok: bool = _focus_name(t) == "Choice"
	var kinds_ok := true
	for variation in ["ButtonPrimary", "ButtonSecondary", "ButtonTertiary", "Chip", "PillTab", "CardButton", "SlotFilled", "RowButton"]:
		var b := Button.new()
		b.theme_type_variation = StringName(variation)
		b.name = "Ring%s" % variation
		screen.add_child(b)
		await t.frames(1)
		b.grab_focus()
		Fixtures.apply_guide_rules("hud_guide", host)
		await t.frames(1)
		kinds_ok = kinds_ok and t.root.gui_get_focus_owner() == null
	t.check("fixtures_guide_focus_released", title_ok and select_ok and choice_ok and kinds_ok,
		"`<screen>_guide` fixtures release focus for RING controls (cards, buttons, chips, tabs, slots, rows: %s) and keep it where the mock paints the focus look: Fortsæt (MenuRow) %s, the first ChoiceRow %s; the screen's focus guard is switched off so it does not put the focus back (%s)" % [kinds_ok, title_ok, choice_ok, not screen.focus_guard])
	t.check("fixtures_guide_extras_hidden", shown_before and title_ok and select_ok and sticky_ok,
		"the HintBar, any ToastStack and (select page) the %%BackButton are hidden in the guide fixtures, which have none of them in the mock (they were all visible before: %s); title_guide hides the bar and the toasts but has no %%BackButton to hide (%s), select_guide hides the %%BackButton too (%s); a hidden bar stays hidden when the device changes (%s)" % [shown_before, title_ok, select_ok, sticky_ok])
	_drop_host()
	gm.call("pop_all_modals")
	await t.frames(2)
	# every fixture the registry names resolves to a scene id, and the P28 components resolve and are available
	var unresolved: Array[String] = []
	var names := {}
	for row_def in UiAudit.screens():
		for key in [str(row_def.get("fixture", "")), str((row_def.get("compare", {}) as Dictionary).get("fixture", "")) if row_def.get("compare") != null else ""]:
			if key != "":
				names[key] = row_def["id"]
	for n in names:
		if not Fixtures.SCREENS.has(Fixtures.base_name(n)):
			unresolved.append("%s (row %s)" % [n, names[n]])
	var comps := true
	for n in ["confirm", "toasts", "prompt"]:
		comps = comps and Fixtures.available(n) and Fixtures.SCREENS.has(n)
	for n in ["area_banner", "animal_care", "build_menu", "intro", "minimap"]:
		comps = comps and Fixtures.SCREENS.has(n) and Fixtures.scene_path(n) == str(Fixtures.SCREENS[n])
	t.check("fixtures_all_registry_fixtures_resolve", unresolved.is_empty() and comps, "all %d fixture names of tests/lib/ui_screens.json (+ ui_screens.d) resolve through UiFixtures.SCREENS %s; confirm / toasts / prompt are available, area_banner / animal_care / build_menu / intro / minimap are mapped (%s)" % [names.size(), str(unresolved), comps])


func _focus_name(t) -> String:
	var f: Control = t.root.gui_get_focus_owner()
	return str(f.name) if f != null else ""


# ---------------------------------------------------------------------------------------------------- the mutation checks

## The foundation gallery in a fresh host (a CLONE: every mutant below changes this instance only).
func _gallery(t) -> Control:
	var host := _fresh(t)
	var g: Control = (load(GALLERY) as PackedScene).instantiate()
	host.add_child(g)
	await t.frames(4)
	return g


func _baseline_clean(t, g: Control) -> bool:
	var f: Dictionary = UiAudit.focusable_report(g, {"ignore": ["**/StatesRow/**"]})
	var r: Dictionary = UiAudit.rule_report(g, {"ignore": ["**/StatesRow/**"]})
	return (f["defects"] as Array).is_empty() and (r["defects"] as Array).is_empty()


func _mutants(t) -> void:
	# the unmutated clone is clean, so every catch below is the mutation's doing
	var g := await _gallery(t)
	var base_clean := _baseline_clean(t, g)
	t.check("mutants_baseline_gallery_is_clean", base_clean, "the unmutated gallery clone passes focusable_report and rule_report (%s)" % UiAudit.summary(UiAudit.focusable_report(g, {"ignore": ["**/StatesRow/**"]})))
	# 1. a gold hover StyleBox on Chip (the theme, deep-copied)
	var th := (ThemeDB.get_project_theme().duplicate(true)) as Theme
	var gold_box: StyleBox = BoxStyle.new()
	gold_box.set("fill", C.GOLD)
	th.set_stylebox("hover", "Chip", gold_box)
	var strict_rep: Dictionary = UiAudit.theme_report(th, {"strict_gold_hover": true})
	var hits := gold_hover_hits(th)
	var chip_flagged := false
	for h in hits:
		chip_flagged = chip_flagged or (h["variation"] == "Chip" and h["state"] == "hover")
	t.check("mutant_gold_hover_caught", chip_flagged and _has_code(strict_rep, "theme_gold_hover") and gold_hover_hits().is_empty(), "a gold hover on Chip is reported by the strict theme scan (%s) while the real theme is clean" % UiAudit.summary(strict_rep))
	# 2. a button set to FOCUS_NONE
	var victim: Button = g.find_child("OtherButton", true, false)
	victim.focus_mode = Control.FOCUS_NONE
	var f2: Dictionary = UiAudit.focusable_report(g, {"ignore": ["**/StatesRow/**"]})
	t.check("mutant_focus_none_caught", _has_code(f2, "unfocusable_interactive"), "an enabled Button with FOCUS_NONE: %s" % UiAudit.summary(f2))
	victim.focus_mode = Control.FOCUS_ALL
	# 3. a per-node font size override on a label
	var label := g.find_child("TotalLabel", true, false) as Label
	label.add_theme_font_size_override("font_size", 40)
	var r3: Dictionary = UiAudit.rule_report(g, {"ignore": ["**/StatesRow/**"]})
	t.check("mutant_override_caught", _has_code(r3, "theme_override"), "add_theme_font_size_override on a label: %s" % UiAudit.summary(r3))
	label.remove_theme_font_size_override("font_size")
	# 4. a #ff2020 label colour
	label.add_theme_color_override("font_color", Color("#ff2020"))
	var r4: Dictionary = UiAudit.rule_report(g, {"ignore": ["**/StatesRow/**"]})
	t.check("mutant_red_caught", _has_code(r4, "r4_red"), "a label coloured #ff2020: %s" % UiAudit.summary(r4))
	label.remove_theme_color_override("font_color")
	# 9. a plain HSlider in a screen (it paints no ring: Godot's Slider never draws a theme focus style)
	var plain := HSlider.new()
	plain.name = "PlainSlider"
	plain.custom_minimum_size = Vector2(300, 36)
	g.get_node("%Margin").add_child(plain)
	await t.frames(2)
	var f9: Dictionary = UiAudit.focusable_report(g, {"ignore": ["**/StatesRow/**"]})
	var tmp := "user://p28_mutant_slider"
	DirAccess.make_dir_recursive_absolute(tmp)
	var scene_text := "[gd_scene format=3]\n\n[node name=\"Root\" type=\"Control\"]\n\n[node name=\"Volume\" type=\"HSlider\" parent=\".\"]\n"
	var tmp_file := FileAccess.open(tmp + "/mutant.tscn", FileAccess.WRITE)
	tmp_file.store_string(scene_text)
	tmp_file.close()
	var scan := slider_offenders(tmp, tmp)
	DirAccess.remove_absolute(tmp + "/mutant.tscn")
	DirAccess.remove_absolute(tmp)
	t.check("mutant_plain_slider_caught", _has_code(f9, "no_focus_style") and scan.size() == 1, "a plain HSlider: focusable_report says %s and the scene scan finds %s" % [UiAudit.summary(f9), str(scan)])
	plain.queue_free()
	# 7. an AcceptDialog inside a screen
	var dialog := AcceptDialog.new()
	g.add_child(dialog)
	var f7: Dictionary = UiAudit.focusable_report(g, {"ignore": ["**/StatesRow/**"], "forbid_windows": true})
	t.check("mutant_window_dialog_caught", _has_code(f7, "window_in_screen"), "an AcceptDialog in a screen: %s" % UiAudit.summary(f7))
	dialog.queue_free()
	_drop_host()
	await t.frames(2)
	# 5. a focusable control in the HUD (P17's hud.all_controls_focus_none runs this library check on its scene; the HUD scene does not exist yet)
	var hud_host := _fresh(t)
	var hud := Control.new()
	hud.name = "FakeHud"
	hud_host.add_child(hud)
	var slot := Button.new()
	slot.text = "1"
	slot.focus_mode = Control.FOCUS_ALL
	hud.add_child(slot)
	await t.frames(2)
	var f5: Dictionary = UiAudit.focusable_report(hud, {"forbid_focus": true})
	t.check("mutant_hud_focus_caught", _has_code(f5, "hud_focusable"), "a focusable control in a HUD: %s (P17's hud.all_controls_focus_none will use the same report: its scene does not exist in this tree)" % UiAudit.summary(f5))
	_drop_host()
	# 6. a screen whose _initial_focus returns null
	var host6 := _fresh(t)
	var mutant6 := NoFocusScreen.new()
	mutant6.screen_id = &"mutant_nofocus"
	mutant6.modal_name = &"mutant_nofocus"
	host6.add_child(mutant6)
	await t.frames(1)
	mutant6.open()
	await t.frames(3)
	var f6: Dictionary = UiAudit.initial_focus_report(mutant6)
	t.check("mutant_no_initial_focus_caught", _has_code(f6, "no_initial_focus"), "a screen whose _initial_focus() returns null: %s" % UiAudit.summary(f6))
	mutant6.close()
	_drop_host()
	t.autoload("GameManager").call("pop_all_modals")
	await t.frames(2)
	# 8. a hotkey that fires while a text field has focus
	var r8: Dictionary = await _nav.typing_probe(t, Nav.LeakyScreen)
	var good8: Dictionary = await _nav.typing_probe(t)
	t.check("mutant_hotkey_in_field_caught", not bool(r8["ok"]) and not bool(r8["audit_ok"]) and bool(good8["ok"]), "a screen without the text-field guard: the library's typing audit finds the leak (audit %s, typed %s, closed %s), the guarded screen is clean (%s)" % [r8["audit_ok"], r8["typed_ok"], r8["closed_ok"], good8["ok"]])
	# 10. a red label on the SECOND page behind a PillTab group (the page-aware report sees it, the plain one does not)
	var host10 := _fresh(t)
	var pages := Control.new()
	pages.name = "TwoPages"
	host10.add_child(pages)
	var tabs := HBoxContainer.new()
	pages.add_child(tabs)
	var group := ButtonGroup.new()
	var tab_a := Button.new()
	tab_a.text = "UI_JOURNAL"
	tab_a.theme_type_variation = &"PillTab"
	tab_a.toggle_mode = true
	tab_a.button_group = group
	tab_a.button_pressed = true
	tabs.add_child(tab_a)
	var tab_b := Button.new()
	tab_b.text = "UI_INVENTORY"
	tab_b.theme_type_variation = &"PillTab"
	tab_b.toggle_mode = true
	tab_b.button_group = group
	tabs.add_child(tab_b)
	var page_a := VBoxContainer.new()
	page_a.position = Vector2(0, 80)
	pages.add_child(page_a)
	var label_a := Label.new()
	label_a.text = "UI_JOURNAL"
	page_a.add_child(label_a)
	var page_b := VBoxContainer.new()
	page_b.position = Vector2(0, 80)
	page_b.visible = false
	pages.add_child(page_b)
	var label_b := Label.new()
	label_b.text = "UI_INVENTORY"
	label_b.add_theme_color_override("font_color", Color("#ff2020"))
	page_b.add_child(label_b)
	tab_a.toggled.connect(func(on: bool) -> void: page_a.visible = on)
	tab_b.toggled.connect(func(on: bool) -> void: page_b.visible = on)
	await t.frames(3)
	var single: Dictionary = UiAudit.rule_report(pages)
	var paged: Dictionary = await UiAudit.rule_report_pages(t, pages)
	t.check("mutant_tab_page_defect_caught", not _has_code(single, "r4_red") and _has_code(paged, "r4_red"), "a red label behind the second PillTab: the single-page report misses it (%s), the page-aware report finds it (%s)" % [UiAudit.summary(single), UiAudit.summary(paged)])
	_drop_host()
	await t.frames(2)
	# 11. a screen whose _input marks ui_accept handled: Enter / Space / pad A press nothing
	var eaten: Dictionary = await _nav.accept_probe(t, Nav.EatingScreen)
	var fine: Dictionary = await _nav.accept_probe(t)
	t.check("mutant_accept_eaten_caught", not bool(eaten["ok"]) and not bool(eaten["buttons_ok"]) and bool(fine["ok"]), "an _input that marks ui_accept handled leaves the focused Button unpressed (buttons %s, rows %s); the unmutated screen presses once per Enter / Space / pad A (%s)" % [eaten["buttons_ok"], str(eaten["rows"]), fine["ok"]])


## A screen whose _initial_focus() returns null (the mutation of check 6).
class NoFocusScreen extends Nav.TestScreen:
	func _initial_focus() -> Control:
		return null


# ---------------------------------------------------------------------------------------------------- the sweep over every live screen

func _sweep(t) -> void:
	var live := UiAudit.screens_by_status("live")
	var failures: Array[String] = []
	var swept: Array[String] = []
	var skipped_rows: Array[String] = []
	for row in live:
		var id := str(row["id"])
		var res: Dictionary = await UiAudit.audit_screen(t, id)                         # U1 focus, U2 walk, U3 focusables, U4 rules (page-aware), U5 escape, U6 language: the checks of the row
		swept.append(id)
		if not bool(res["ok"]):
			failures.append("%s: %s" % [id, str((res["defects"] as Array).slice(0, 2))])
		# both locales: the guide rules once in Danish and once in English (raw keys, over-long text, a label that did not re-label)
		var node: Node = await UiAudit.open_screen(t, id)
		if node != null:
			var opts: Dictionary = {"ignore": (row.get("options", {}) as Dictionary).get("ignore", []), "hit_min": float((row.get("options", {}) as Dictionary).get("hit_min", 32.0))}
			var both: Dictionary = await UiAudit.rule_report_locales(t, node, ["da", "en"], opts)
			if not (both["defects"] as Array).is_empty():
				failures.append("%s (da + en): %s" % [id, UiAudit.summary(both)])
			# U5 for a modal that opened itself: Esc, Start and B close exactly the top layer (esc_depth 1 rows without an explicit escape check)
			if str(row.get("kind", "")) == "component" and int(row.get("esc_depth", 0)) == 1 and str(row.get("modal", "")) != "":
				for via in ["key", "pad_b", "start"]:
					if via != "key":
						await UiAudit.close_screen(t, id)
						node = await UiAudit.open_screen(t, id)
					var opened_host: Node = node.get_parent()
					var esc_opts := {"pre_opened": true, "base_stack": opened_host.get_meta(&"ui_audit_base_stack", []), "base_paused": opened_host.get_meta(&"ui_audit_base_paused", false), "via": via, "release_world_focus": true}
					if opened_host.get_meta(&"ui_audit_base_phase", null) != null:
						esc_opts["base_phase"] = opened_host.get_meta(&"ui_audit_base_phase")
					var esc: Dictionary = await UiAudit.escape_chain(t, Callable(), 1, esc_opts)
					if not (esc["defects"] as Array).is_empty():
						failures.append("%s Esc via %s: %s" % [id, via, UiAudit.summary(esc)])
			await UiAudit.close_screen(t, id)
		else:
			skipped_rows.append(id)
	t.check("live_screens_sweep", failures.is_empty() and swept.size() >= 5 and skipped_rows.is_empty(),
		"U1 - U6 and U9 on %d live row(s) of UiAudit.screens() in da and en: %s; failures %s, unopenable %s" % [swept.size(), str(swept), str(failures), str(skipped_rows)])
	# the P28 rows are live (their scenes are P28's): confirm, toasts and prompt
	var p28_live := true
	for id in ["confirm", "toasts", "prompt"]:
		p28_live = p28_live and str(UiAudit.screen(id).get("status", "")) == "live"
	t.check("p28_rows_are_live", p28_live and "confirm" in swept and "toasts" in swept and "prompt" in swept, "confirm, toasts and prompt are live rows with their own scenes and fixtures")


func _legacy_gate(t) -> void:
	var legacy := UiAudit.screens_by_status("legacy")
	if legacy.is_empty():
		t.check("no_legacy_screens_left", true, "no row of UiAudit.screens() is still the legacy scaffold")
		return
	var ids: Array[String] = []
	var owners := {}
	for r in legacy:
		ids.append(str(r["id"]))
		owners[str(r["package"])] = true
	t.skip("ui_conformance.no_legacy_screens_left: %s are still the legacy scaffold scenes (the old main_menu / character_select are not on the guide theme): %s lands them; the check becomes a hard gate the moment their scenes carry theme_type_variation" % [", ".join(ids), ", ".join(owners.keys())])


# ---------------------------------------------------------------------------------------------------- windowed pixels

func _saveload_autosave_rings(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var previous_dir: String = saves.save_dir
	saves.save_dir = "user://conformance-autosave-rings"
	t.on_cleanup(func() -> void: saves.save_dir = previous_dir)
	if not await t.start_world():
		return
	var saved: bool = saves.save_game(saves.AUTO_SLOT, true)
	if saved:
		var previous := FileAccess.open(saves.slot_path(saves.PREV_AUTO_SLOT), FileAccess.WRITE)
		previous.store_string(FileAccess.get_file_as_string(saves.slot_path(saves.AUTO_SLOT)))
		previous.close()
	await t.clear_scene()
	var screen: Node = await UiAudit.open_screen(t, "saveload")
	var reports: Array[Dictionary] = []
	if screen != null:
		for slot in [saves.AUTO_SLOT, saves.PREV_AUTO_SLOT]:
			var button := screen.get_node_or_null("%%Slot%d" % slot) as Control
			reports.append(await UiAudit.ring_pixels(t, button, {"shot": "autosave_ring_%d" % slot}))
		await UiAudit.close_screen(t, "saveload")
	t.check("saveload_adjacent_autosave_rings", saved and reports.size() == 2 and reports.all(func(report: Dictionary) -> bool: return report.ok),
		"current and previous autosave rows retain every gold and ink edge: %s" % str(reports.map(func(report: Dictionary) -> String: return UiAudit.summary(report))))
	saves.save_dir = previous_dir


func run_windowed(t) -> void:
	await t.clear_scene()
	await _saveload_autosave_rings(t)
	TranslationServer.set_locale("da")
	var ring_reports: Array[Dictionary] = []
	var ring_notes: Array[String] = []
	var panel_reports: Array[Dictionary] = []
	var panel_notes: Array[String] = []
	var button_reports: Array[Dictionary] = []
	var button_notes: Array[String] = []
	for row in UiAudit.screens_by_status("live"):
		var id := str(row["id"])
		var node: Node = await UiAudit.open_screen(t, id)
		if node == null:
			continue
		await t.frames(3)
		# rings and fills: the control that has focus when the screen opens (a gold ring, or a gold fill for a MenuRow / ChoiceRow), and an unfocused sibling shows nothing
		var target := UiAudit.initial_focus(node)
		if str(row.get("focus", "initial")) != "none" and target != null:
			var sibling := _sibling(node, target)
			# A screen focus guard restores focus, and a selected radio card retains its ring. Sample these AS opened (focus: false), with the
			# unfocused sibling is sampled separately (expect none); screens without a guard get the full probe with the negative control on the target itself
			var guarded: bool = node is UiConfirm or (node is TTScreen and node.focus_guard) or (target is BaseButton and target.toggle_mode and target.button_pressed)
			var rep: Dictionary = await UiAudit.ring_pixels(t, target, {"shot": "ring_%s" % id, "focus": false} if guarded else ({"shot": "ring_%s" % id, "other": sibling} if sibling != null else {"shot": "ring_%s" % id}))
			ring_reports.append(rep)
			ring_notes.append("%s %s: %s" % [id, target.name, UiAudit.summary(rep)])
			if guarded and sibling != null:
				var nrep: Dictionary = await UiAudit.ring_pixels(t, sibling, {"shot": "ring_%s_sibling" % id, "focus": false, "expect": "none"})
				ring_reports.append(nrep)
				ring_notes.append("%s %s unfocused: %s" % [id, sibling.name, UiAudit.summary(nrep)])
		# panels: every double-edge panel of the screen
		for n in Rules.nodes(node, []):
			if not is_instance_valid(n):
				continue
			if n is PanelContainer and (n as Control).is_visible_in_tree() and StringName((n as Control).theme_type_variation) in PANEL_VARIATIONS and (n as Control).size.x > 60.0:
				var prep: Dictionary = await UiAudit.panel_pixels(t, n as Control, {"shot": "panel_%s_%s" % [id, n.name]})
				panel_reports.append(prep)
				panel_notes.append("%s %s: %s" % [id, n.name, UiAudit.summary(prep)])
		# buttons: the guide's raised buttons (primary / secondary / tertiary) of the screen
		var seen_variations := {}
		for n in Rules.nodes(node, []):
			if not is_instance_valid(n):
				continue
			if n is Button and (n as Control).is_visible_in_tree() and not (n as Button).disabled and not (n as Button).flat:
				var v := str((n as Control).theme_type_variation)
				var sb := (n as Control).get_theme_stylebox("normal")
				if v.begins_with("Button") and sb != null and sb.get_script() == BoxStyle and not seen_variations.has(v) and float(sb.get("hard_shadow")) >= 4.0:
					seen_variations[v] = true
					if (n as Control).has_focus():
						(n as Control).release_focus()
						await t.frames(3)
					if not is_instance_valid(n):
						continue
					if (n as Control).has_focus():
						button_notes.append("%s %s (%s): skipped, the screen keeps focus on it" % [id, n.name, v])       # UiConfirm's guard: the focused default answer is ring-sampled instead
						seen_variations.erase(v)
						continue
					var brep: Dictionary = await UiAudit.button_pixels(t, n as Control, {"shot": "button_%s_%s" % [id, n.name]})
					button_reports.append(brep)
					button_notes.append("%s %s (%s): %s" % [id, n.name, v, UiAudit.summary(brep)])
					if not bool(brep.ok):
						for detail in UiAudit.lines(brep):
							t.info(detail)
		await UiAudit.close_screen(t, id)
	# the fill look of the gold rows (MenuRow / ChoiceRow focused), a ring on a chip / tab / card, and the disabled button's dashed edge on a plain sheet
	var sheet := await _pixel_sheet(t)
	ring_reports.append_array(sheet["rings"])
	ring_notes.append_array(sheet["ring_notes"])
	var ring_ok := true
	for r in ring_reports:
		ring_ok = ring_ok and bool(r.get("ok", false)) and (r.get("defects", []) as Array).is_empty()
	t.check("windowed_rings", ring_ok and ring_reports.size() >= 8, "%d focus looks sampled (gold ring 1-3 px + ink 4-5 px on all four edges, or the gold fill; the unfocused sibling shows none): %s" % [ring_reports.size(), "; ".join(ring_notes)])
	var panel_ok := true
	for r in panel_reports:
		panel_ok = panel_ok and (r.get("defects", []) as Array).is_empty()
	panel_reports.append_array(sheet["panels"])
	panel_notes.append_array(sheet["panel_notes"])
	for r in sheet["panels"]:
		panel_ok = panel_ok and (r.get("defects", []) as Array).is_empty()
	t.check("windowed_panels", panel_ok and panel_reports.size() >= 3, "%d double-edge panels (parchment, ink 2, gold 4, ink 2): %s" % [panel_reports.size(), "; ".join(panel_notes)])
	var button_ok := true
	for r in button_reports:
		button_ok = button_ok and (r.get("defects", []) as Array).is_empty()
	button_reports.append_array(sheet["buttons"])
	button_notes.append_array(sheet["button_notes"])
	for r in sheet["buttons"]:
		button_ok = button_ok and (r.get("defects", []) as Array).is_empty()
	t.check("windowed_buttons", button_ok and bool(sheet["disabled_ok"]) and button_reports.size() >= 4, "%d raised buttons (ink border, face, band, ink border, 4 px hard underside) %s; the disabled button has the dashed grey edge and no underside (%s)" % [button_reports.size(), "; ".join(button_notes), sheet["disabled_ok"]])
	await _acceptance_shots(t)


## The acceptance captures of the order, kept as a repeatable check (a person LOOKS at them, `--out=DIR` keeps them): the foundation gallery's guide page with its focused
## control, the amended stepper focused, the rarity page with a focused slot of a rarity row, and a UiConfirm over the gallery. Each focus look is also pixel-proven.
func _acceptance_shots(t) -> void:
	var host := _fresh(t)
	var gm: Node = t.autoload("GameManager")
	gm.call("pop_all_modals")
	var g: Control = (load(GALLERY) as PackedScene).instantiate()
	host.add_child(g)
	await t.frames(5)
	var notes: Array[String] = []
	var ok := true
	# 1. the guide page: the gallery grabs focus on its FocusedButton (the gold ring), the other button of the row stays plain
	var focused: Button = g.find_child("FocusedButton", true, false)
	var r1: Dictionary = await UiAudit.ring_pixels(t, focused, {"shot": "accept_gallery_guide_focus", "other": g.find_child("OtherButton", true, false)})
	ok = ok and (r1["defects"] as Array).is_empty()
	notes.append("guide page, %s: %s" % [focused.name, UiAudit.summary(r1)])
	# 2. the amended stepper: one focus stop with its own ring (the gallery keeps it in the right-hand column)
	var stepper: Control = g.find_child("Stepper", true, false)
	if stepper != null:
		var r2: Dictionary = await UiAudit.ring_pixels(t, stepper, {"shot": "accept_gallery_guide_stepper"})
		ok = ok and (r2["defects"] as Array).is_empty()
		notes.append("guide page, stepper: %s" % UiAudit.summary(r2))
	else:
		ok = false
		notes.append("the gallery has no Stepper node")
	# 3. the rarity page: a themed slot of a rarity row focused (RING_SEL replaces the rarity ring), its neighbours keep theirs
	g.call("show_page", &"rarity")
	await t.frames(4)
	var slot: Control = g.find_child("ThemedSlot_rare", true, false)
	if slot != null:
		var r3: Dictionary = await UiAudit.ring_pixels(t, slot, {"shot": "accept_gallery_rarity_focus", "other": g.find_child("ThemedSlot_uncommon", true, false)})
		ok = ok and (r3["defects"] as Array).is_empty()
		notes.append("rarity page, %s: %s" % [slot.name, UiAudit.summary(r3)])
	else:
		ok = false
		notes.append("the rarity page has no ThemedSlot_rare")
	# 4. a UiConfirm over the gallery (guide page): Fortryd focused, the gallery stays visible behind the scrim
	g.call("show_page", &"guide")
	t.root.gui_release_focus()
	await t.frames(3)
	var dlg := (load(UiConfirm.SCENE_PATH) as PackedScene).instantiate() as UiConfirm
	g.add_child(dlg)
	dlg.setup("UI_CONFIRM_TITLE", "UI_CONFIRM_OVERWRITE", "NAV_OK", "NAV_CANCEL", &"cancel", [3])
	dlg.begin()
	await t.frames(4)
	var cancel: Control = dlg.get_node("%CancelButton")
	var r4: Dictionary = await UiAudit.ring_pixels(t, cancel, {"shot": "accept_gallery_confirm", "focus": false})
	var stack_ok: bool = (gm.call("modal_stack") as Array).has(&"confirm") and t.root.gui_get_focus_owner() == cancel
	ok = ok and (r4["defects"] as Array).is_empty() and stack_ok
	notes.append("UiConfirm over the gallery, Fortryd (modal confirm on the stack, focus on it: %s): %s" % [stack_ok, UiAudit.summary(r4)])
	dlg.call("_finish", false)
	await t.frames(3)
	_drop_host()
	gm.call("pop_all_modals")
	t.check("windowed_acceptance_shots", ok, "the foundation gallery (guide page, rarity page) with a focused control, the stepper's own ring, a focused rarity-row slot and a UiConfirm over the gallery are captured and show their gold rings: %s" % "; ".join(notes))


## The first sibling control that is focusable and not `target` (the negative control of ring_pixels: it must show no ring).
func _sibling(root: Node, target: Control) -> Control:
	for n in Rules.nodes(root, []):
		if n is Control and n != target and (n as Control).is_visible_in_tree() and (n as Control).focus_mode == Control.FOCUS_ALL and Rules.is_interactive(n as Control) and (n as Control).size.x > 20:
			if n is BaseButton and not (n as BaseButton).disabled and not target.get_global_rect().intersects((n as Control).get_global_rect()):
				return n as Control
	return null


## A plain sheet of the controls the live screens do not have yet (rows, chips, tabs, cards, the three raised buttons, a disabled one, a panel) so the pixel profiles are proven
## for every look the foundation owns, whatever screens exist in this tree.
func _pixel_sheet(t) -> Dictionary:
	var host := _fresh(t)
	var bg := ColorRect.new()
	bg.color = Color("#a9c97a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var out := {"rings": [] as Array[Dictionary], "ring_notes": [] as Array[String], "panels": [] as Array[Dictionary], "panel_notes": [] as Array[String], "buttons": [] as Array[Dictionary], "button_notes": [] as Array[String], "disabled_ok": false}
	var panel := PanelContainer.new()
	panel.name = "SheetPanel"
	panel.theme_type_variation = &"PanelMenu"
	panel.position = Vector2(60, 40)
	panel.custom_minimum_size = Vector2(420, 0)
	host.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var side := VBoxContainer.new()                                          # a second column: the controls that would not fit under the panel
	side.name = "SheetSide"
	side.position = Vector2(620, 120)
	side.custom_minimum_size = Vector2(420, 0)
	side.add_theme_constant_override("separation", 40)
	host.add_child(side)
	var controls := {}
	for spec in [["MenuRow", "MENU_CONTINUE", &"MenuRow"], ["ChoiceRow", "MENU_NEW_GAME", &"ChoiceRow"], ["Chip", "MENU_SETTINGS", &"Chip"], ["PillTab", "UI_JOURNAL", &"PillTab"], ["CardButton", "CHAR_ANIMAL_NAME", &"CardButton"],
			["Primary", "MENU_CONTINUE", &"ButtonPrimary"], ["Secondary", "MENU_NEW_GAME", &"ButtonSecondary"], ["Tertiary", "MENU_QUIT", &"ButtonTertiary"], ["Disabled", "MENU_SETTINGS", &"ButtonTertiary"]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.theme_type_variation = spec[2]
		if spec[0] == "CardButton":
			b.custom_minimum_size = Vector2(200, 70)
		col.add_child(b)
		controls[spec[0]] = b
	(controls["Disabled"] as Button).disabled = true
	(controls["Chip"] as Button).toggle_mode = true
	(controls["PillTab"] as Button).toggle_mode = true
	var slider := TTSlider.new()
	slider.name = "SheetSlider"
	slider.custom_minimum_size = Vector2(300, 36)
	side.add_child(slider)
	var field := LineEdit.new()
	field.name = "SheetField"
	side.add_child(field)
	await t.frames(5)
	var rows := ["MenuRow", "ChoiceRow", "Chip", "PillTab", "CardButton", "Primary", "Secondary", "Tertiary"]
	for name in rows:
		var c: Control = controls[name]
		var rep: Dictionary = await UiAudit.ring_pixels(t, c, {"shot": "sheet_ring_%s" % name, "other": controls["Tertiary"] if name != "Tertiary" else controls["Primary"]})
		(out["rings"] as Array).append(rep)
		(out["ring_notes"] as Array).append("sheet %s %s: %s" % [name, rep.get("kind", "?"), UiAudit.summary(rep)])
	var srep: Dictionary = await UiAudit.ring_pixels(t, slider, {"shot": "sheet_ring_slider", "other": controls["Tertiary"]})
	(out["rings"] as Array).append(srep)
	(out["ring_notes"] as Array).append("sheet slider: %s" % UiAudit.summary(srep))
	var frep: Dictionary = await UiAudit.ring_pixels(t, field, {"shot": "sheet_ring_field", "other": controls["Tertiary"]})
	(out["rings"] as Array).append(frep)
	(out["ring_notes"] as Array).append("sheet field: %s" % UiAudit.summary(frep))
	t.root.gui_release_focus()
	await t.frames(2)
	var prep: Dictionary = await UiAudit.panel_pixels(t, panel, {"shot": "sheet_panel"})
	(out["panels"] as Array).append(prep)
	(out["panel_notes"] as Array).append("sheet panel: %s" % UiAudit.summary(prep))
	for name in ["Primary", "Secondary", "Tertiary"]:
		var brep: Dictionary = await UiAudit.button_pixels(t, controls[name], {"shot": "sheet_button_%s" % name})
		(out["buttons"] as Array).append(brep)
		(out["button_notes"] as Array).append("sheet %s: %s" % [name, UiAudit.summary(brep)])
	# the disabled button: a dashed grey edge (#a3957f alternating with the fill) and NO hard underside: below the body the backdrop shows, not ink
	var img: Image = await t.capture("sheet_disabled")
	var d: Control = controls["Disabled"]
	var rect := d.get_global_rect()
	var sb := d.get_theme_stylebox("disabled")
	var inset: Vector4 = sb.get("body_inset")
	var top := int(rect.position.y + inset.y)
	var greys := 0
	var fills := 0
	var x0 := int(rect.position.x + 24)
	for dx in 40:
		var px := img.get_pixel(x0 + dx, top)
		if Rules.color_close(px, C.TEXT_DISABLED, 14.0):
			greys += 1
		elif Rules.color_close(px, C.DISABLED_BG, 14.0):
			fills += 1
	var below := img.get_pixel(int(rect.get_center().x), int(rect.end.y - inset.w + 2))
	var no_underside: bool = not Rules.is_ink(below)
	out["disabled_ok"] = greys >= 10 and fills >= 5 and no_underside
	_drop_host()
	await t.frames(2)
	return out
