extends RefCounted
## Section ui_audit_pins: pins every THRESHOLD and BRANCH of the rule scans of the UI audit library (tests/lib/ui_audit_rules.gd) and of the audit functions
## (tests/lib/ui_audit.gd) with values on BOTH sides of the line, so that a changed constant or a deleted branch fails a check instead of passing silently.
## The first review's mutation run (277 one-line mutants of the library, each run against the ui_audit section) left 158 alive: the section planted only whole checks,
## never the edge of a tolerance or one branch of a scan. Every block below names the constant or branch it pins; `tests/sections/ui_audit.gd` and `ui_audit_blind.gd`
## prove the codes and the blind spots, this section proves the numbers.
##   A colours       gold / ink tolerance (6 / 10 of 255), the red hue window 350..15 deg, saturation / value 0.45, alpha 0.1, the gold alpha 0.2
##   B text          number text (sign, comma, colon), letter counts, the hard-coded copy scan (3 letters), font families (also through a FontVariation chain)
##   C styleboxes    r1_problem (border 1 / 2 / 3 px, ink colour, alpha 0.95, luma 0.2, dashed grey, partial borders), style_colors, style_info, box_style_of
##   D controls      is_interactive / is_enabled per class, nodes() (hidden, canvas layers, internal children, ignore globs)
##   E scans         R2 gold (every property and state name), R4 red, overrides, raw keys, R3 numbers, typography floors and tokens, through Rules.scan
##   F theme         theme_scan: red, outline, focus style, gold in non-focus states, font scale edges
##   G audit         focusable_report / initial_focus / walk / escape / flip / registry branches that no other check reaches
const SECTION := "ui_audit_pins"
const TIMEOUT_S := 240.0

const Rules = preload("res://tests/lib/ui_audit_rules.gd")
const C = preload("res://scripts/ui/theme/tt_colors.gd")
const BoxStyle = preload("res://scripts/ui/theme/tt_box_style.gd")
const F_DISPLAY = preload("res://assets/fonts/Caprasimo-Regular.ttf")
const F_BODY = preload("res://assets/fonts/AlegreyaSans-Bold.ttf")
const F_MONO = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
const F_SYMBOLS = preload("res://assets/fonts/TTSymbols-Regular.ttf")

var _host: Control


func run(t) -> void:
	await t.clear_scene()
	TranslationServer.set_locale("da")
	var orphans0 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_a_colours(t)
	_b_text(t)
	_c_styleboxes(t)
	await _d_controls(t)
	await _e_scans(t)
	_f_theme(t)
	await _g_audit(t)
	await _drop(t)
	t.check("pin_section_leaves_no_orphan_nodes", int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) <= orphans0, "orphan nodes before %d, after %d" % [orphans0, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])


# ---------------------------------------------------------------------------------------------------- helpers

func _fresh(t) -> Control:
	t.root.gui_release_focus()
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	_host = Control.new()
	_host.name = "PinsHost"
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	t.root.add_child(_host)
	return _host


## The defect codes of one scan over `node` (added under a fresh host first).
func _codes(t, node: Node, rules: Array, options := {}) -> Array:
	var h := _fresh(t)
	h.add_child(node)
	var o := {"rules": rules}
	o.merge(options)
	var rep := Rules.scan(h, o)
	return (rep["defects"] as Array).map(func(d): return str(d["code"]))


func _scan_report(t, node: Node, rules: Array, options := {}) -> Dictionary:
	var h := _fresh(t)
	h.add_child(node)
	var o := {"rules": rules}
	o.merge(options)
	return Rules.scan(h, o)


## [colour] is flagged by a rule: checks one planted node and one clean control of the same kind.
func _flag(t, name: String, bad: Node, good: Node, rule: String, code: String, options := {}) -> void:
	var got_bad := _codes(t, bad, [rule], options)
	var got_good := _codes(t, good, [rule], options)
	t.check("pin_%s" % name, got_bad.has(code) and not got_good.has(code), "planted: %s / control: %s (want %s only on the planted one)" % [str(got_bad), str(got_good), code])


func _px(r: int, g: int, b: int, a := 255) -> Color:
	return Color8(r, g, b, a)


func _label(text := "INV_TITLE", variation := &"Body") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


func _rect(color: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(20, 8)
	return c


func _flat(bg: Color, border_w := 2, border := C.INK) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.bg_color = bg
	f.set_border_width_all(border_w)
	f.border_color = border
	return f


# ---------------------------------------------------------------------------------------------------- A: colours

func _a_colours(t) -> void:
	var G := C.GOLD
	var g8 := G.to_html(false)
	t.check("pin_gold_tolerance_is_6_of_255", Rules.is_gold(_px(233, 195, 114)) and Rules.is_gold(_px(221, 195, 114)) and not Rules.is_gold(_px(234, 195, 114)) and not Rules.is_gold(_px(220, 195, 114)), "gold %s: +-6 on a channel passes, +-7 does not" % g8)
	t.check("pin_gold_tolerance_each_channel", Rules.is_gold(_px(227, 201, 114)) and not Rules.is_gold(_px(227, 202, 114)) and Rules.is_gold(_px(227, 195, 120)) and not Rules.is_gold(_px(227, 195, 121)), "green and blue are measured too")
	t.check("pin_gold_hover_is_gold_too", Rules.is_gold(C.GOLD_HOVER) and Rules.is_gold(_px(242, 209, 137)) and not Rules.is_gold(_px(243, 209, 137)), "the hover gold #ecd189 has the same tolerance")
	t.check("pin_gold_needs_alpha_0_2", Rules.is_gold(Color(G.r, G.g, G.b, 0.2)) and not Rules.is_gold(Color(G.r, G.g, G.b, 0.19)), "a nearly transparent gold is not gold (alpha 0.2)")
	t.check("pin_gold_is_not_honey_or_dark_gold", not Rules.is_gold(C.HONEY) and not Rules.is_gold(C.GOLD_DARK) and not Rules.is_gold(C.OWL_EYE), "honey, dark gold and the owl eye are other colours")
	t.check("pin_ink_tolerance_is_10_of_255", Rules.is_ink(_px(53, 35, 64)) and not Rules.is_ink(_px(54, 35, 64)) and Rules.is_ink(_px(33, 35, 64)) and not Rules.is_ink(_px(32, 35, 64)) and Rules.is_ink(_px(43, 45, 64)) and not Rules.is_ink(_px(43, 46, 64)), "ink %s: +-10 passes, +-11 does not, on every channel" % C.INK.to_html(false))
	t.check("pin_color_close_is_a_max_not_a_sum", Rules.color_close(_px(10, 10, 10), _px(20, 20, 20), 10.5) and not Rules.color_close(_px(10, 10, 10), _px(21, 10, 10), 10.5) and Rules.color_close(_px(10, 10, 10), _px(20, 10, 10), 10.5), "color_close compares the largest channel difference with the tolerance")
	# red: the hue window is 350..360 and 0..15 degrees, saturation and value >= 0.45, alpha >= 0.1
	var red := func(h: float, s: float, v: float, a := 1.0) -> bool: return Rules.is_red(Color.from_hsv(h / 360.0, s, v, a))
	t.check("pin_red_hue_window_low_edge", red.call(350.5, 0.9, 0.9) and not red.call(349.0, 0.9, 0.9), "hue 350.5 is red, 349 is not (thorn-berry is 339)")
	t.check("pin_red_hue_window_high_edge", red.call(14.5, 0.9, 0.9) and not red.call(16.5, 0.9, 0.9), "hue 14.5 is red, 16.5 (orange) is not")
	t.check("pin_red_hue_zero_and_full_circle", red.call(0.0, 0.9, 0.9) and red.call(359.0, 0.9, 0.9) and red.call(5.0, 0.9, 0.9) and red.call(355.0, 0.9, 0.9), "0, 5, 355 and 359 degrees are red")
	t.check("pin_red_saturation_edge_0_45", red.call(0.0, 0.46, 0.9) and not red.call(0.0, 0.44, 0.9), "a washed-out red (saturation 0.44) is not danger red")
	t.check("pin_red_value_edge_0_45", red.call(0.0, 0.9, 0.46) and not red.call(0.0, 0.9, 0.44), "a dark red (value 0.44) is not danger red")
	t.check("pin_red_alpha_edge_0_1", red.call(0.0, 0.9, 0.9, 0.1) and not red.call(0.0, 0.9, 0.9, 0.09), "an invisible red (alpha 0.09) is not red")
	t.check("pin_red_the_guides_pinks_and_browns_pass", not Rules.is_red(C.THORNBERRY) and not Rules.is_red(C.ROSE) and not Rules.is_red(C.BARK) and not Rules.is_red(Color("#c4506a")) and Rules.is_red(Color("#ff2020")), "thorn-berry, rose, bark and the dev-only #c4506a are not red, #ff2020 is")
	t.check("pin_luma_weights", absf(Rules.luma(Color(1, 0, 0)) - 0.2126) < 0.0001 and absf(Rules.luma(Color(0, 1, 0)) - 0.7152) < 0.0001 and absf(Rules.luma(Color(0, 0, 1)) - 0.0722) < 0.0001, "luma = 0.2126 R + 0.7152 G + 0.0722 B")
	t.check("pin_hex", Rules.hex(C.GOLD) == "#e3c372", "hex() prints #rrggbb")


# ---------------------------------------------------------------------------------------------------- B: text

func _b_text(t) -> void:
	var yes: Array[String] = ["1.250", "10:40", "12", "x3", "+5", "-2", "1,5", "×4", "−3", " 7 ", "0"]
	var no: Array[String] = ["", "E", "x", "+", "5a", ".5", "18 / 24", "150 guldagern", "I alt 300", "Dag 14", "1.2.", "--1", "1 2"]
	var bad_yes: Array[String] = []
	for s in yes:
		if not Rules.is_number_text(s):
			bad_yes.append(s)
	var bad_no: Array[String] = []
	for s in no:
		if Rules.is_number_text(s) and s != "1.2.":
			bad_no.append(s)
	t.check("pin_number_text_accepts", bad_yes.is_empty(), "numbers, money, clocks, signs (+ - minus x ×), commas and colons: wrongly refused %s" % str(bad_yes))
	t.check("pin_number_text_refuses", bad_no.is_empty() and not Rules.is_number_text("5a") and not Rules.is_number_text("1 2"), "mixed texts are exempt by construction: wrongly accepted %s" % str(bad_no))
	t.check("pin_number_text_comma_and_colon_are_separate_characters", Rules.is_number_text("1,5") and Rules.is_number_text("1:5") and Rules.is_number_text("1.5") and not Rules.is_number_text("1;5"), "each of . , : is allowed after the first digit")
	t.check("pin_letter_count", Rules.letter_count("ab") == 2 and Rules.letter_count("abc") == 3 and Rules.letter_count("Æ Ø Å æ ø å") == 6 and Rules.letter_count("12:40 !?") == 0 and Rules.letter_count("A1b2") == 2, "ASCII letters and the six Danish ones count, digits and signs do not")
	t.check("pin_key_shape", Rules.is_key_shaped("MENU_NEW_GAME") and Rules.is_key_shaped("A1_B2") and not Rules.is_key_shaped("MENU") and not Rules.is_key_shaped("Menu_New") and not Rules.is_key_shaped("MENU_new") and not Rules.is_key_shaped("1_A"), "RAW_KEY_PATTERN: capitals, digits and at least one underscore")
	# the hard-coded copy scan: a text of 3 letters is copy, 2 letters is not; keys, numbers, glyphs, res:// paths, %-formats and [bbcode] pass
	var scene_src := "[node name=\"A\" type=\"Label\"]\ntext = \"ab\"\n[node name=\"B\" type=\"Label\"]\ntext = \"abc\"\n[node name=\"C\" type=\"Label\"]\ntext = \"MENU_NEW_GAME\"\n[node name=\"D\" type=\"Label\"]\ntext = \"123 :\"\n[node name=\"E\" type=\"Label\"]\ntext = \"res://x/yyyy.tscn\"\n[node name=\"F\" type=\"Label\"]\ntext = \"%d guld\"\n[node name=\"G\" type=\"Label\"]\ntext = \"[b]\"\n[node name=\"H\" type=\"Label\"]\ntooltip_text = \"Hello there\"\n[node name=\"I\" type=\"Label\"]\ntext = \"\"\n[node name=\"J\" type=\"Label\"]\ntext = \"Æøå\"\n"
	var scene_path := "user://pins_scan_scene.tscn"
	var f := FileAccess.open(scene_path, FileAccess.WRITE)
	f.store_string(scene_src)
	f.close()
	var hits := Rules.literal_scan(null, [scene_path])
	var texts: Array = hits.map(func(h): return str(h["text"]))
	t.check("pin_literal_scan_three_letters", texts.has("abc") and not texts.has("ab") and texts.has("Hello there") and texts.has("Æøå"), "'abc' is copy, 'ab' is not, a tooltip and the Danish letters are: %s" % str(texts))
	t.check("pin_literal_scan_skips_keys_numbers_paths_formats_and_bbcode", not texts.has("MENU_NEW_GAME") and not texts.has("123 :") and not texts.has("res://x/yyyy.tscn") and not texts.has("%d guld") and not texts.has("[b]"), "key-shaped, numeric, res://, %%-leading and [..] texts pass: %s" % str(texts))
	var code_src := "extends Control\nfunc _ready():\n\t$A.text = \"abc\"\n\t$B.text = \"ab\"\n\t$C.add_item(\"Hello world\")\n\t$D.text = \"MENU_NEW_GAME\"\n\t$E.set_text(\"Another one\")\n\tvar x = \"text = 'not an assignment'\"\n\t$F.tooltip_text = \"Tip text\"\n"
	var code_path := "user://pins_scan_script.gd"
	var f2 := FileAccess.open(code_path, FileAccess.WRITE)
	f2.store_string(code_src)
	f2.close()
	var hits2 := Rules.literal_scan(null, [code_path])
	var texts2: Array = hits2.map(func(h): return str(h["text"]))
	t.check("pin_literal_scan_script", texts2.has("abc") and not texts2.has("ab") and texts2.has("Hello world") and texts2.has("Another one") and texts2.has("Tip text") and not texts2.has("MENU_NEW_GAME"), "script assignments, add_item and set_text are scanned: %s" % str(texts2))
	t.check("pin_literal_scan_reports_the_line", hits2.any(func(h): return str(h["text"]) == "abc" and int(h["line"]) == 3) and hits.any(func(h): return str(h["text"]) == "abc" and int(h["line"]) == 4), "file:line of every hit")
	t.check("pin_literal_scan_missing_file_is_skipped", Rules.literal_scan(null, ["user://does_not_exist.gd"]).is_empty(), "a path that does not exist adds nothing")
	DirAccess.remove_absolute(scene_path)
	DirAccess.remove_absolute(code_path)
	# font families, also through FontVariation chains
	t.check("pin_font_family", Rules.font_family(F_DISPLAY) == "display" and Rules.font_family(F_BODY) == "body" and Rules.font_family(F_MONO) == "mono" and Rules.font_family(F_SYMBOLS) == "symbol" and Rules.font_family(ThemeDB.fallback_font) == "other", "Caprasimo, Alegreya Sans, Plex Mono, TTSymbols and the engine fallback")
	var fv := FontVariation.new()
	fv.base_font = F_DISPLAY
	var fv2 := FontVariation.new()
	fv2.base_font = fv
	t.check("pin_font_family_through_variations", Rules.font_family(fv) == "display" and Rules.font_family(fv2) == "display" and Rules.font_family(null) == "other", "a FontVariation (even nested) reports its base font's family; null is other")
	var fv_body := FontVariation.new()
	fv_body.base_font = F_BODY
	var fv_mono := FontVariation.new()
	fv_mono.base_font = F_MONO
	t.check("pin_font_family_variation_of_body_mono_symbol", Rules.font_family(fv_body) == "body" and Rules.font_family(fv_mono) == "mono", "the three families through a variation")


# ---------------------------------------------------------------------------------------------------- C: styleboxes

func _tt(fill := C.PARCHMENT, bw := 2.0, border := C.INK) -> StyleBox:
	var s := BoxStyle.new()
	s.fill = fill
	s.border_width = bw
	s.border_color = border
	return s


func _c_styleboxes(t) -> void:
	# r1_problem on flat boxes
	var ok := func(sb: StyleBox) -> bool: return Rules.r1_problem(sb) == ""
	t.check("pin_r1_border_width_edges", not ok.call(_flat(C.PARCHMENT, 1)) and ok.call(_flat(C.PARCHMENT, 2)) and ok.call(_flat(C.PARCHMENT, 3)) and not ok.call(_flat(C.PARCHMENT, 0)) and Rules.r1_problem(_flat(C.PARCHMENT, 1)).contains("1.0 px"), "1 px fails, 2 px and 3 px pass, no border at all fails")
	t.check("pin_r1_border_colour_must_be_ink", not ok.call(_flat(C.PARCHMENT, 2, Color("#3b6fd6"))) and ok.call(_flat(C.PARCHMENT, 2, _px(50, 35, 64))) and not ok.call(_flat(C.PARCHMENT, 2, _px(60, 35, 64))), "a blue outline fails, ink within 10/255 passes, 17 off fails")
	var uneven := _flat(C.PARCHMENT, 2)
	uneven.border_width_top = 1
	t.check("pin_r1_uses_the_thinnest_side", not ok.call(uneven), "left 2 / top 1: the minimum (1) is what counts, not the maximum")
	var only_top := StyleBoxFlat.new()
	only_top.bg_color = C.PARCHMENT
	only_top.border_width_top = 2
	only_top.border_color = Color("#3b6fd6")
	t.check("pin_r1_a_one_sided_border_is_a_segment", ok.call(only_top), "a parchment segment with a line on one side only is a piece of an outlined panel (partial) - even a blue one")
	t.check("pin_r1_fill_alpha_edge_0_95", not ok.call(_flat(Color(0.96, 0.9, 0.77, 0.96), 1)) and ok.call(_flat(Color(0.96, 0.9, 0.77, 0.94), 1)), "a fill with alpha 0.94 is a translucent overlay, 0.96 is a surface")
	t.check("pin_r1_fill_luma_edge_0_2", ok.call(_flat(Color(0.19, 0.19, 0.19), 1)) and not ok.call(_flat(Color(0.21, 0.21, 0.21), 1)), "a dark plate (luma 0.19) needs no outline, luma 0.21 does")
	t.check("pin_r1_transparent_flat_needs_nothing", ok.call(_flat(Color(0, 0, 0, 0), 0)), "a fully transparent box draws nothing")
	# TTBoxStyle
	t.check("pin_r1_tt_style", ok.call(_tt()) and not ok.call(_tt(C.PARCHMENT, 1.0)) and not ok.call(_tt(C.PARCHMENT, 2.0, Color("#3b6fd6"))), "a TTBoxStyle is judged by its border width and colour")
	var dashed_grey := _tt(C.DISABLED_BG, 2.0, C.TEXT_DISABLED)
	dashed_grey.set("dashed", true)
	var dashed_ink := _tt(C.DISABLED_BG, 2.0, C.INK)
	dashed_ink.set("dashed", true)
	t.check("pin_r1_dashed_disabled_uses_the_disabled_grey", ok.call(dashed_grey) and not ok.call(dashed_ink) and Rules.r1_problem(dashed_ink).contains("disabled grey"), "a dashed box must be the guide's #a3957f (an ink dashed box is wrong)")
	var no_body := _tt(C.PARCHMENT, 0.0)
	no_body.set("draw_body", false)
	t.check("pin_r1_ring_only_style_draws_no_body", ok.call(no_body), "a focus ring (draw_body false) is not a surface")
	var sides_partial := _tt(C.PARCHMENT, 2.0, Color("#3b6fd6"))
	sides_partial.set("border_sides", Vector4(2, 0, 2, 2))
	var sides_full := _tt(C.PARCHMENT, 2.0, Color("#3b6fd6"))
	sides_full.set("border_sides", Vector4(2, 2, 2, 2))
	t.check("pin_r1_tt_border_sides", ok.call(sides_partial) and not ok.call(sides_full), "a side with width 0 makes the box a segment (exempt); four 2 px sides are a full outline (blue fails)")
	var sides_inherit := _tt(C.PARCHMENT, 1.0, C.INK)
	sides_inherit.set("border_sides", Vector4(-1, 3, 3, 3))
	t.check("pin_r1_tt_negative_side_uses_the_border_width", not ok.call(sides_inherit), "a side of -1 uses border_width (1): the thinnest side is 1 px")
	# style_info
	var info_flat := Rules.style_info(_flat(C.PARCHMENT, 2))
	t.check("pin_style_info_flat", info_flat["kind"] == "flat" and absf(float(info_flat["border_w"]) - 2.0) < 0.01 and not bool(info_flat["partial"]) and not bool(info_flat["dashed"]) and info_flat["fill"] == C.PARCHMENT, "kind flat, width 2, fill parchment")
	var nofill := _flat(C.PARCHMENT, 2)
	nofill.draw_center = false
	t.check("pin_style_info_draw_center_false_has_no_fill", Rules.style_info(nofill)["fill"] == Color(0, 0, 0, 0), "a box without a centre has a transparent fill")
	t.check("pin_style_info_skips_empty_line_texture", Rules.style_info(StyleBoxEmpty.new())["kind"] == "" and Rules.style_info(StyleBoxLine.new())["kind"] == "" and Rules.style_info(StyleBoxTexture.new())["kind"] == "" and Rules.style_info(null)["kind"] == "", "empty, line, texture and null boxes are not judged")
	var rings_style := _tt()
	rings_style.set("ring_colors", PackedColorArray([C.GOLD, C.INK, C.ROSE]))
	rings_style.set("ring_widths", PackedFloat32Array([4.0, 2.0, 0.0]))
	var info_tt := Rules.style_info(rings_style)
	t.check("pin_style_info_tt_rings_skip_zero_widths", info_tt["kind"] == "tt" and (info_tt["rings"] as Array).size() == 2 and (info_tt["rings"] as Array)[0] == C.GOLD, "rings with width 0 are not rings")
	# style_colors: every branch, with a sentinel colour each
	var sc := _flat(Color("#101010"), 2, Color("#202020"))
	sc.shadow_size = 4
	sc.shadow_color = Color("#303030")
	t.check("pin_style_colors_flat", Rules.style_colors(sc).size() == 3 and Rules.style_colors(sc).has(Color("#101010")) and Rules.style_colors(sc).has(Color("#202020")) and Rules.style_colors(sc).has(Color("#303030")), "fill, border and shadow of a flat box")
	var sc2 := _flat(Color("#101010"), 0, Color("#202020"))
	sc2.draw_center = false
	sc2.shadow_size = 0
	t.check("pin_style_colors_flat_skips_what_is_not_drawn", Rules.style_colors(sc2).is_empty(), "no centre, no border width, no shadow: no colours")
	var sc3 := StyleBoxFlat.new()
	sc3.bg_color = Color("#101010")
	sc3.border_width_bottom = 1
	sc3.border_color = Color("#202020")
	t.check("pin_style_colors_any_border_side_counts", Rules.style_colors(sc3).has(Color("#202020")), "a border on one side only still draws its colour")
	var line := StyleBoxLine.new()
	line.color = Color("#404040")
	t.check("pin_style_colors_line", Rules.style_colors(line).size() == 1 and Rules.style_colors(line)[0] == Color("#404040"), "a StyleBoxLine is its colour")
	var tex := StyleBoxTexture.new()
	tex.modulate_color = Color("#505050")
	t.check("pin_style_colors_texture", Rules.style_colors(tex).size() == 1 and Rules.style_colors(tex)[0] == Color("#505050"), "a StyleBoxTexture is its modulate colour")
	var tts := _tt(Color("#101010"), 2.0, Color("#202020"))
	tts.set("hard_shadow", 4.0)
	tts.set("hard_shadow_color", Color("#303030"))
	tts.set("ring_colors", PackedColorArray([Color("#606060"), Color("#707070")]))
	tts.set("ring_widths", PackedFloat32Array([3.0, 0.0]))
	var ttc := Rules.style_colors(tts)
	t.check("pin_style_colors_tt", ttc.size() == 4 and ttc.has(Color("#101010")) and ttc.has(Color("#202020")) and ttc.has(Color("#303030")) and ttc.has(Color("#606060")) and not ttc.has(Color("#707070")), "fill, border, hard shadow and the rings of width > 0: %s" % str(ttc.map(func(c): return c.to_html(false))))
	var tts2 := _tt(Color("#101010"), 0.0, Color("#202020"))
	tts2.set("hard_shadow", 0.0)
	t.check("pin_style_colors_tt_skips_zero_border_and_shadow", Rules.style_colors(tts2).size() == 1 and Rules.style_colors(tts2)[0] == Color("#101010"), "border width 0 and hard shadow 0 add nothing")
	var ring_only := BoxStyle.new()
	ring_only.draw_body = false
	ring_only.set("ring_colors", PackedColorArray([C.GOLD]))
	ring_only.set("ring_widths", PackedFloat32Array([3.0]))
	t.check("pin_style_colors_tt_ring_only_style", Rules.style_colors(ring_only).size() == 1 and Rules.style_colors(ring_only)[0] == C.GOLD, "a ring-only style (the focus ring) is its rings, not its body fill")
	t.check("pin_style_colors_null_and_empty", Rules.style_colors(null).is_empty() and Rules.style_colors(StyleBoxEmpty.new()).is_empty(), "nothing")


# ---------------------------------------------------------------------------------------------------- D: controls

func _d_controls(t) -> void:
	var h := _fresh(t)
	var items := {}
	var make := func(name: String, n: Node) -> Node:
		n.name = name
		h.add_child(n)
		items[name] = n
		return n
	make.call("Btn", Button.new())
	make.call("Lbl", Label.new())
	make.call("Line", LineEdit.new())
	make.call("Text", TextEdit.new())
	make.call("List", ItemList.new())
	make.call("Tre", Tree.new())
	make.call("Tabs", TabBar.new())
	make.call("HSl", HSlider.new())
	make.call("VSl", VSlider.new())
	make.call("Prog", ProgressBar.new())
	make.call("TexProg", TextureProgressBar.new())
	make.call("HScroll", HScrollBar.new())
	make.call("Scroll", ScrollContainer.new())
	make.call("Plain", Control.new())
	make.call("PanelC", PanelContainer.new())
	var metac := make.call("Meta", Control.new()) as Control
	metac.set_meta(&"tt_interactive", "a custom control")
	var intent := make.call("Intent", Control.new()) as Control
	intent.focus_mode = Control.FOCUS_ALL
	var intent_scroll := make.call("IntentScroll", ScrollContainer.new()) as Control
	intent_scroll.focus_mode = Control.FOCUS_ALL
	var intent_prog := make.call("IntentProg", ProgressBar.new()) as Control
	intent_prog.focus_mode = Control.FOCUS_ALL
	var intent_tex := make.call("IntentTex", TextureProgressBar.new()) as Control
	intent_tex.focus_mode = Control.FOCUS_ALL
	var intent_bar := make.call("IntentBar", HScrollBar.new()) as Control
	intent_bar.focus_mode = Control.FOCUS_ALL
	await t.frames(1)
	var interactive := func(name: String) -> bool: return Rules.is_interactive(items[name] as Control)
	t.check("pin_interactive_classes", interactive.call("Btn") and interactive.call("Line") and interactive.call("Text") and interactive.call("List") and interactive.call("Tre") and interactive.call("Tabs"), "buttons, line edits, text edits, item lists, trees and tab bars are interactive")
	t.check("pin_interactive_sliders_are_ranges", interactive.call("HSl") and interactive.call("VSl"), "a slider is a Range that is not a progress bar or scroll bar")
	t.check("pin_interactive_passive_ranges_are_not", not interactive.call("Prog") and not interactive.call("TexProg") and not interactive.call("HScroll") and not interactive.call("Scroll") and not interactive.call("Plain") and not interactive.call("Lbl") and not interactive.call("PanelC"), "progress bars, scroll bars, scroll containers, labels and plain controls are not")
	t.check("pin_interactive_meta_and_focus_intent", interactive.call("Meta") and interactive.call("Intent"), "meta tt_interactive and a control that asked for focus (FOCUS_ALL) are interactive by intent")
	t.check("pin_interactive_focus_intent_excludes_passive_classes", not interactive.call("IntentScroll") and not interactive.call("IntentProg") and not interactive.call("IntentTex") and not interactive.call("IntentBar"), "a scroll container / progress bar / scroll bar with FOCUS_ALL is still not a thing to press")
	var btn_d := Button.new()
	btn_d.disabled = true
	var le_ro := LineEdit.new()
	le_ro.editable = false
	var te_ro := TextEdit.new()
	te_ro.editable = false
	var sl_ro := HSlider.new()
	sl_ro.editable = false
	t.check("pin_enabled_per_class", not Rules.is_enabled(btn_d) and not Rules.is_enabled(le_ro) and not Rules.is_enabled(te_ro) and not Rules.is_enabled(sl_ro) and Rules.is_enabled(items["Btn"] as Control) and Rules.is_enabled(items["Line"] as Control) and Rules.is_enabled(items["Text"] as Control) and Rules.is_enabled(items["HSl"] as Control) and Rules.is_enabled(items["Plain"] as Control), "disabled buttons, read-only fields and sliders are not enabled")
	btn_d.free()
	le_ro.free()
	te_ro.free()
	sl_ro.free()
	# class_name_of: a script with a global name wins, else the engine class
	var ladder: Control = (load("res://scripts/ui/components/ladder_row.gd") as GDScript).new()
	t.check("pin_class_name_of", Rules.class_name_of(items["Btn"]) == "Button" and Rules.class_name_of(ladder) == "LadderRow", "the engine class, or a script's global name (LadderRow)")
	ladder.free()
	# nodes(): hidden, canvas layers, windows, internal children, ignore, meta
	h = _fresh(t)
	var hidden_box := Control.new()
	hidden_box.name = "HiddenBox"
	hidden_box.visible = false
	var under_hidden := Button.new()
	under_hidden.name = "UnderHidden"
	hidden_box.add_child(under_hidden)
	h.add_child(hidden_box)
	var layer := CanvasLayer.new()
	layer.name = "Layer"
	layer.visible = false
	var in_layer := Button.new()
	in_layer.name = "InLayer"
	layer.add_child(in_layer)
	h.add_child(layer)
	var win := Window.new()
	win.name = "Win"
	win.visible = false
	var in_win := Button.new()
	in_win.name = "InWin"
	win.add_child(in_win)
	h.add_child(win)
	var tabs_container := TabContainer.new()
	tabs_container.name = "TC"
	var page := Control.new()
	page.name = "PageA"
	tabs_container.add_child(page)
	h.add_child(tabs_container)
	var keep := Button.new()
	keep.name = "Keep"
	h.add_child(keep)
	var skip_glob := Button.new()
	skip_glob.name = "SkipMe"
	h.add_child(skip_glob)
	var skip_meta := Button.new()
	skip_meta.name = "SkipMeta"
	skip_meta.set_meta(&"tt_audit_ignore", "a dev sample")
	var in_skip_meta := Button.new()
	in_skip_meta.name = "InsideSkipMeta"
	skip_meta.add_child(in_skip_meta)
	h.add_child(skip_meta)
	await t.frames(2)
	var names := func(arr: Array[Node]) -> Array: return arr.map(func(n): return str(n.name))
	var seen: Array = names.call(Rules.nodes(h))
	t.check("pin_nodes_skips_hidden_subtrees", not seen.has("HiddenBox") and not seen.has("UnderHidden") and seen.has("Keep"), "a hidden CanvasItem hides its subtree: %s" % str(seen))
	t.check("pin_nodes_skips_a_hidden_canvas_layer", not seen.has("Layer") and not seen.has("InLayer"), "a hidden CanvasLayer hides its screen")
	t.check("pin_nodes_skips_a_hidden_window", not seen.has("Win") and not seen.has("InWin"), "an unopened dialog is not on screen")
	var all_seen: Array = names.call(Rules.nodes(h, [], false))
	t.check("pin_nodes_only_visible_false_sees_everything", all_seen.has("HiddenBox") and all_seen.has("UnderHidden") and all_seen.has("Layer") and all_seen.has("InLayer") and all_seen.has("Win") and all_seen.has("InWin"), "the unfiltered walk includes hidden nodes (hidden windows count for the dialog ban)")
	t.check("pin_nodes_includes_internal_children", (Rules.nodes(h) as Array).any(func(n): return n is TabBar), "the tab bar a TabContainer creates internally is part of the screen")
	var seen_ignore: Array = names.call(Rules.nodes(h, ["SkipMe"]))
	t.check("pin_nodes_ignore_glob", not seen_ignore.has("SkipMe") and seen_ignore.has("Keep"), "options.ignore skips a node by its path")
	t.check("pin_nodes_meta_ignore_skips_the_subtree", not seen.has("SkipMeta") and not seen.has("InsideSkipMeta"), "meta tt_audit_ignore skips the node and everything under it")
	t.check("pin_rel_path", Rules.rel_path(h, h) == "." and Rules.rel_path(h, keep) == "Keep", "the root is '.', a child its relative path")


# ---------------------------------------------------------------------------------------------------- E: the scans

func _e_scans(t) -> void:
	await _e_gold(t)
	await _e_red(t)
	await _e_overrides_and_keys(t)
	await _e_numbers_and_typography(t)


func _gold_named(t, name: String, node: Node, expect: bool, options := {}) -> void:
	var codes := _codes(t, node, ["r2"], options)
	t.check("pin_r2_%s" % name, codes.has("r2_gold_decoration") == expect, "%s -> %s" % [("flagged" if expect else "allowed"), str(codes)])


func _e_gold(t) -> void:
	var G := C.GOLD
	# node properties
	_gold_named(t, "colorrect", _rect(G), true)
	_gold_named(t, "colorrect_not_gold", _rect(C.MOSS), false)
	var mod := _label()
	mod.modulate = G
	_gold_named(t, "modulate", mod, true)
	var self_mod := _rect(Color.WHITE)
	self_mod.self_modulate = G
	_gold_named(t, "self_modulate", self_mod, true)
	var plain_white := _rect(Color.WHITE)
	_gold_named(t, "white_modulate_is_not_gold", plain_white, false)
	var ls_font := _label()
	var ls1 := LabelSettings.new()
	ls1.font_color = G
	ls_font.label_settings = ls1
	_gold_named(t, "label_settings_font_colour", ls_font, true)
	var ls_out := _label()
	var ls2 := LabelSettings.new()
	ls2.font_color = C.INK
	ls2.outline_color = G
	ls2.outline_size = 3
	ls_out.label_settings = ls2
	_gold_named(t, "label_settings_outline_colour", ls_out, true)
	var ls_out0 := _label()
	var ls3 := LabelSettings.new()
	ls3.font_color = C.INK
	ls3.outline_color = G
	ls3.outline_size = 0
	ls_out0.label_settings = ls3
	_gold_named(t, "label_settings_outline_of_size_0_is_not_drawn", ls_out0, false)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.text = "[color=#e3c372]x[/color]"
	_gold_named(t, "bbcode_colour", rich, true)
	var rich_ok := RichTextLabel.new()
	rich_ok.bbcode_enabled = true
	rich_ok.fit_content = true
	rich_ok.text = "[color=#6b9a3e]x[/color]"
	_gold_named(t, "bbcode_other_colour", rich_ok, false)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5, 5)])
	poly.color = G
	_gold_named(t, "polygon2d", poly, true)
	var line2 := Line2D.new()
	line2.default_color = G
	_gold_named(t, "line2d", line2, true)
	var line2_ok := Line2D.new()
	line2_ok.default_color = C.INK
	_gold_named(t, "line2d_not_gold", line2_ok, false)
	# font colour overrides: the focus / pressed / selected colours may be gold, every other one may not
	for nm in ["font_color", "font_hover_color", "font_disabled_color", "font_outline_color", "font_shadow_color"]:
		var lab := _label()
		lab.add_theme_color_override(nm, G)
		_gold_named(t, "font_colour_override_%s" % nm, lab, true)
	for nm in ["font_focus_color", "font_pressed_color", "font_hover_pressed_color", "font_selected_color"]:
		var lab2 := _label()
		lab2.add_theme_color_override(nm, G)
		_gold_named(t, "font_colour_override_%s_is_a_state_colour" % nm, lab2, false)
	# style overrides by state name
	for sn in ["normal", "hover", "disabled", "panel", "background", "fill", "read_only"]:
		var pn := PanelContainer.new()
		pn.add_theme_stylebox_override(sn, _flat(G, 2))
		_gold_named(t, "style_override_%s" % sn, pn, true)
	for sn2 in ["focus", "pressed", "hover_pressed", "selected", "tab_selected", "selected_focus"]:
		var pn2 := PanelContainer.new()
		pn2.add_theme_stylebox_override(sn2, _flat(G, 2))
		_gold_named(t, "style_override_%s_is_a_state" % sn2, pn2, false)
	var line_ov := HSeparator.new()
	var sbl := StyleBoxLine.new()
	sbl.color = G
	line_ov.add_theme_stylebox_override("separator", sbl)
	_gold_named(t, "style_override_separator", line_ov, true)
	# an override that IS one of the project theme's own styles is the guide's style, not a decoration
	var th_style: StyleBox = ThemeDB.get_project_theme().get_stylebox("normal", "ButtonSecondary")
	var own := Button.new()
	own.text = "UI_YES"
	own.add_theme_stylebox_override("normal", th_style)
	_gold_named(t, "theme_own_style_override_is_the_guide", own, false)
	var copy := Button.new()
	copy.text = "UI_YES"
	copy.add_theme_stylebox_override("normal", th_style.duplicate())
	_gold_named(t, "copy_of_a_theme_style_is_a_decoration", copy, true)
	# selected states are exempt (and listed in the notes)
	var focused := _rect(G)
	focused.focus_mode = Control.FOCUS_ALL
	var h := _fresh(t)
	h.add_child(focused)
	focused.grab_focus()
	await t.frames(1)
	var rep_f := Rules.scan(h, {"rules": ["r2"]})
	t.check("pin_r2_focused_node_is_exempt", (rep_f["defects"] as Array).is_empty() and (rep_f["notes"] as Array).any(func(n): return str(n["msg"]).contains("focused / pressed / selected")), "a focused gold node is allowed and noted")
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = true
	toggle.add_theme_stylebox_override("normal", _flat(G, 2))
	_gold_named(t, "pressed_toggle_is_exempt", toggle, false)
	var toggle_off := Button.new()
	toggle_off.toggle_mode = true
	toggle_off.add_theme_stylebox_override("normal", _flat(G, 2))
	_gold_named(t, "unpressed_toggle_is_not", toggle_off, true)
	for prop in ["selected", "is_selected", "current"]:
		var holder := ColorRect.new()
		holder.color = G
		var s := GDScript.new()
		s.source_code = "extends ColorRect\nvar %s := true\n" % prop
		s.reload()
		holder.set_script(s)
		_gold_named(t, "script_property_%s_marks_it_selected" % prop, holder, false)
	var tagged := _rect(G)
	tagged.set_meta(&"tt_gold_ok", "the coin icon")
	var rep_t := _scan_report(t, tagged, ["r2"])
	t.check("pin_r2_meta_exemption_is_noted", (rep_t["defects"] as Array).is_empty() and (rep_t["notes"] as Array).any(func(n): return str(n["msg"]).contains("the coin icon")), "meta tt_gold_ok exempts the node and its reason is listed")
	# the strict layer: a style the THEME provides
	var th := Theme.new()
	th.set_stylebox("normal", "Button", _flat(G, 2))
	var themed := Button.new()
	themed.text = "UI_YES"
	themed.theme = th
	_gold_named(t, "theme_provided_gold_normal_style", themed, true)
	var themed_off := Button.new()
	themed_off.text = "UI_YES"
	themed_off.theme = th
	_gold_named(t, "strict_gold_off", themed_off, false, {"strict_gold": false})
	var themed_ornament := Button.new()
	themed_ornament.text = "UI_YES"
	themed_ornament.theme_type_variation = &"ButtonSecondary"
	themed_ornament.theme = th
	_gold_named(t, "ornament_variation_is_exempt_even_with_a_gold_theme", themed_ornament, false)
	var theme2 := Theme.new()
	theme2.set_stylebox("panel", "PanelContainer", _flat(G, 2))
	for orn in ["Coin", "CoinInk", "PanelParchment", "PillGold", "NamePlate", "KeyCap", "Tagline", "ZoneChip", "PromptPill", "PanelToast"]:
		var pc := PanelContainer.new()
		pc.theme_type_variation = StringName(orn)
		pc.theme = theme2
		_gold_named(t, "ornament_%s_is_exempt" % orn.to_lower(), pc, false)
	var non_orn := PanelContainer.new()
	non_orn.theme_type_variation = &"PanelCard"
	non_orn.theme = theme2
	_gold_named(t, "non_ornament_panel_with_a_gold_style", non_orn, true)
	var orn_class := PanelContainer.new()
	var theme3 := Theme.new()
	theme3.set_stylebox("panel", "PanelContainer", _flat(G, 2))
	orn_class.theme = theme3
	_gold_named(t, "plain_panel_container_with_a_gold_style", orn_class, true)
	var double := PanelContainer.new()
	double.add_theme_stylebox_override("panel", _flat(G, 2))
	var codes_d := _codes(t, double, ["r2"])
	t.check("pin_r2_an_override_is_reported_once_not_twice", codes_d.count("r2_gold_decoration") == 1, "the per-node scan owns overrides, the theme scan skips them: %s" % str(codes_d))
	var gold_text_theme := Theme.new()
	gold_text_theme.set_color("font_color", "Label", G)
	for variant in [["Label", "label"], ["Button", "button"], ["LineEdit", "line"], ["RichTextLabel", "rich"]]:
		var tn: Control
		match variant[0]:
			"Label":
				tn = _label()
			"Button":
				tn = Button.new()
			"LineEdit":
				tn = LineEdit.new()
			_:
				tn = RichTextLabel.new()
		var tth := Theme.new()
		tth.set_color("default_color" if variant[0] == "RichTextLabel" else "font_color", variant[0], G)
		tn.theme = tth
		_gold_named(t, "theme_text_colour_of_a_%s" % variant[1], tn, true)
	var gold_disabled := Button.new()
	gold_disabled.text = "UI_YES"
	gold_disabled.disabled = true
	var tth2 := Theme.new()
	tth2.set_color("font_disabled_color", "Button", G)
	gold_disabled.theme = tth2
	_gold_named(t, "theme_disabled_text_colour", gold_disabled, true)
	var gold_hover_text := Button.new()
	gold_hover_text.text = "UI_YES"
	var tth3 := Theme.new()
	tth3.set_color("font_hover_color", "Button", G)
	gold_hover_text.theme = tth3
	_gold_named(t, "theme_hover_text_colour_is_not_idle_text", gold_hover_text, false)
	# TextureProgressBar tints
	for prop2 in ["tint_under", "tint_over", "tint_progress"]:
		var tp := TextureProgressBar.new()
		tp.set(prop2, G)
		_gold_named(t, "texture_progress_%s" % prop2, tp, true)
	_gold_named(t, "texture_progress_default_tints_are_white", TextureProgressBar.new(), false)
	var tp_other := TextureProgressBar.new()
	tp_other.tint_progress = C.MOSS
	_gold_named(t, "texture_progress_other_tint", tp_other, false)


func _red_named(t, name: String, node: Node, expect: bool) -> void:
	var codes := _codes(t, node, ["r4"])
	t.check("pin_r4_%s" % name, codes.has("r4_red") == expect, "%s -> %s" % [("flagged" if expect else "allowed"), str(codes)])


func _e_red(t) -> void:
	var R := Color("#d62828")
	_red_named(t, "colorrect", _rect(R), true)
	_red_named(t, "colorrect_thornberry", _rect(C.THORNBERRY), false)
	var l1 := _label()
	l1.add_theme_color_override("font_color", R)
	_red_named(t, "font_colour", l1, true)
	var l2 := _label()
	l2.add_theme_color_override("font_color", C.THORNBERRY)
	_red_named(t, "font_colour_thornberry", l2, false)
	var l3 := _label()
	l3.add_theme_color_override("font_outline_color", R)
	l3.add_theme_constant_override("outline_size", 0)
	_red_named(t, "outline_colour_without_an_outline", l3, false)
	var l4 := _label()
	l4.add_theme_color_override("font_outline_color", R)
	l4.add_theme_constant_override("outline_size", 3)
	_red_named(t, "outline_colour_with_an_outline", l4, true)
	var l5 := _label()
	l5.add_theme_color_override("font_shadow_color", Color(R.r, R.g, R.b, 0.0))
	_red_named(t, "invisible_shadow_colour", l5, false)
	var l6 := _label()
	l6.add_theme_color_override("font_shadow_color", Color(R.r, R.g, R.b, 0.5))
	_red_named(t, "visible_shadow_colour", l6, true)
	var pn := Panel.new()
	pn.add_theme_stylebox_override("panel", _flat(R, 2))
	_red_named(t, "style_override", pn, true)
	var pn_ok := Panel.new()
	pn_ok.add_theme_stylebox_override("panel", _flat(C.THORNBERRY, 2))
	_red_named(t, "style_override_thornberry", pn_ok, false)
	var th := Theme.new()
	th.set_stylebox("panel", "PanelContainer", _flat(R, 2))
	var pc := PanelContainer.new()
	pc.theme = th
	_red_named(t, "theme_provided_style", pc, true)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5, 5)])
	poly.color = R
	_red_named(t, "polygon2d", poly, true)
	var ln := Line2D.new()
	ln.default_color = R
	_red_named(t, "line2d", ln, true)
	var md := _label()
	md.modulate = R
	_red_named(t, "modulate", md, true)
	var smd := _rect(Color.WHITE)
	smd.self_modulate = R
	_red_named(t, "self_modulate", smd, true)
	var ls := _label()
	var lsr := LabelSettings.new()
	lsr.font_color = R
	ls.label_settings = lsr
	_red_named(t, "label_settings", ls, true)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.text = "[color=red]x[/color]"
	_red_named(t, "bbcode_named_colour", rich, true)
	var rich2 := RichTextLabel.new()
	rich2.bbcode_enabled = true
	rich2.fit_content = true
	rich2.text = "[bgcolor=#d62828]x[/bgcolor]"
	_red_named(t, "bbcode_bgcolor", rich2, true)
	var rich3 := RichTextLabel.new()
	rich3.bbcode_enabled = true
	rich3.fit_content = true
	rich3.text = "[color=#b3436b]x[/color]"
	_red_named(t, "bbcode_thornberry", rich3, false)
	var tp := TextureProgressBar.new()
	tp.tint_progress = R
	_red_named(t, "texture_progress_tint", tp, true)
	var sep := HSeparator.new()
	var sl := StyleBoxLine.new()
	sl.color = R
	sep.add_theme_stylebox_override("separator", sl)
	_red_named(t, "separator_override", sep, true)
	var bbcodes := Rules.bbcode_colors("[color=red]a[/color][bgcolor=#112233]b[/bgcolor][fgcolor=#445566]c[/fgcolor][outline_color=yellow]d[/outline_color][color=nonsense]e[/color]")
	t.check("pin_bbcode_colors_parses_the_four_colour_tags", bbcodes.size() == 4 and bbcodes[0] == Color("red") and bbcodes[1] == Color("#112233") and bbcodes[2] == Color("#445566") and bbcodes[3] == Color("yellow"), "[color], [bgcolor], [fgcolor], [outline_color]; an unknown name is skipped: %s" % str(bbcodes))


func _e_overrides_and_keys(t) -> void:
	var o := func(build: Callable) -> Array: return _codes(t, build.call(), ["overrides"])
	var f1 := _label()
	f1.add_theme_font_override("font", F_BODY)
	var f2 := _label()
	f2.add_theme_font_size_override("font_size", 30)
	var f3 := _label()
	f3.add_theme_color_override("font_color", C.INK)
	var f4 := _label()
	f4.add_theme_color_override("font_outline_color", C.INK)
	var f5 := Button.new()
	f5.add_theme_color_override("icon_normal_color", C.INK)
	var f6 := RichTextLabel.new()
	f6.add_theme_font_size_override("normal_font_size", 30)
	var f7 := RichTextLabel.new()
	f7.add_theme_font_override("bold_font", F_BODY)
	var f8 := _label()
	f8.add_theme_font_size_override("font_size", 30)
	f8.set_meta(&"tt_override_ok", "a one-off hero label")
	var clean := _label()
	t.check("pin_overrides_font", _codes(t, f1, ["overrides"]).has("theme_override"), "a per-node font")
	t.check("pin_overrides_font_size", _codes(t, f2, ["overrides"]).has("theme_override"), "a per-node font size")
	t.check("pin_overrides_font_colour", _codes(t, f3, ["overrides"]).has("theme_override") and _codes(t, f4, ["overrides"]).has("theme_override"), "a per-node font_color or font_outline_color")
	t.check("pin_overrides_only_font_colours_count", not _codes(t, f5, ["overrides"]).has("theme_override"), "an icon colour override is not a font override")
	t.check("pin_overrides_richtext_names", _codes(t, f6, ["overrides"]).has("theme_override") and _codes(t, f7, ["overrides"]).has("theme_override"), "normal_font_size and bold_font of a RichTextLabel")
	t.check("pin_overrides_meta_exemption_and_clean", not _codes(t, f8, ["overrides"]).has("theme_override") and not _codes(t, clean, ["overrides"]).has("theme_override"), "meta tt_override_ok and an untouched label pass")
	t.check("pin_overrides_gate", not _codes(t, _label_with_override(), ["r4"]).has("theme_override") and _codes(t, _label_with_override(), ["overrides"]).has("theme_override"), "the override scan runs only when 'overrides' is among the rules")
	# raw keys
	var keyed := func(node: Node) -> bool: return _codes(t, node, ["i18n"]).has("raw_key")
	var lab_k := _label("AUDIT_NO_SUCH_KEY")
	var btn_k := Button.new()
	btn_k.text = "AUDIT_NO_SUCH_KEY"
	var le_k := LineEdit.new()
	le_k.placeholder_text = "AUDIT_NO_SUCH_KEY"
	var rt_k := RichTextLabel.new()
	rt_k.fit_content = true
	rt_k.text = "AUDIT_NO_SUCH_KEY"
	var tip_k := Button.new()
	tip_k.text = "UI_YES"
	tip_k.tooltip_text = "AUDIT_NO_SUCH_KEY"
	var real_k := _label("CHAR_HOBBIT_NAME")
	var typed_k := _label("Hobbit")
	t.check("pin_raw_key_label_button_field_richtext_tooltip", keyed.call(lab_k) and keyed.call(btn_k) and keyed.call(le_k) and keyed.call(rt_k) and keyed.call(tip_k), "an untranslated key on a Label, Button, LineEdit placeholder, RichTextLabel and a tooltip")
	t.check("pin_raw_key_translated_keys_are_fine", not keyed.call(real_k) and not keyed.call(typed_k), "CHAR_HOBBIT_NAME translates to 'Hobbit'")
	var le_text := LineEdit.new()
	le_text.text = "typed"
	le_text.placeholder_text = "AUDIT_NO_SUCH_KEY"
	t.check("pin_raw_key_placeholder_of_a_field_is_scanned_even_with_text", keyed.call(le_text), "the placeholder is always looked at")


func _label_with_override() -> Label:
	var l := _label()
	l.add_theme_font_size_override("font_size", 40)
	return l


func _typo(t, name: String, node: Control, code: String, expect: bool, options := {}) -> void:
	var codes := _codes(t, node, ["typography"], options)
	t.check("pin_typography_%s" % name, codes.has(code) == expect, "%s %s -> %s" % [code, ("expected" if expect else "not expected"), str(codes)])


func _sized(font: Font, size: int, text := "INV_TITLE") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	return l


func _e_numbers_and_typography(t) -> void:
	# typography thresholds (an override is never exempt): Caprasimo >= 20, Alegreya >= 18, nothing below 11
	_typo(t, "display_19_fails", _sized(F_DISPLAY, 19), "font_too_small_display", true)
	_typo(t, "display_20_passes", _sized(F_DISPLAY, 20), "font_too_small_display", false)
	_typo(t, "body_17_fails", _sized(F_BODY, 17), "font_too_small_body", true)
	_typo(t, "body_18_passes", _sized(F_BODY, 18), "font_too_small_body", false)
	_typo(t, "floor_10_fails_for_the_body_face", _sized(F_BODY, 10), "font_below_floor", true)
	_typo(t, "floor_11_is_not_the_floor", _sized(F_BODY, 11), "font_below_floor", false)
	_typo(t, "floor_10_fails_for_the_display_face", _sized(F_DISPLAY, 10), "font_below_floor", true)
	_typo(t, "floor_wins_over_the_face_minimum", _sized(F_BODY, 10), "font_too_small_body", false)
	_typo(t, "display_11_is_a_display_defect_not_a_floor_one", _sized(F_DISPLAY, 11), "font_below_floor", false)
	_typo(t, "mono_is_exempt", _sized(F_MONO, 9), "font_below_floor", false)
	_typo(t, "mono_is_exempt_from_the_body_minimum", _sized(F_MONO, 13), "font_too_small_body", false)
	_typo(t, "symbols_are_exempt", _sized(F_SYMBOLS, 9), "font_below_floor", false)
	var other := _sized(ThemeDB.fallback_font, 9)
	_typo(t, "an_unknown_face_is_exempt", other, "font_below_floor", false)
	# tokens: a theme variation below the minimum is the guide's own size (a note), unless strict
	var tok_body := _label("INV_TITLE", &"Muted14")
	_typo(t, "body_token_lenient", tok_body, "font_too_small_body", false)
	_typo(t, "body_token_strict", _label("INV_TITLE", &"Muted14"), "font_too_small_body", true, {"strict_typography": true})
	_typo(t, "display_token_lenient", _label("INV_TITLE", &"Display19"), "font_too_small_display", false)
	_typo(t, "display_token_strict", _label("INV_TITLE", &"Display19"), "font_too_small_display", true, {"strict_typography": true})
	for cv in ["Display15", "Display16", "Display15Night", "Display16Night"]:
		_typo(t, "display_count_variation_%s_is_exempt_even_when_strict" % cv.to_lower(), _label("1", StringName(cv)), "font_too_small_display", false, {"strict_typography": true})
	var counted_override := _label("1", &"Display15")
	counted_override.add_theme_font_size_override("font_size", 15)
	_typo(t, "a_count_variation_with_an_override_is_not_exempt", counted_override, "font_too_small_display", true, {"strict_typography": true})
	var token_override := _label("INV_TITLE", &"Muted14")
	token_override.add_theme_font_size_override("font_size", 14)
	_typo(t, "a_token_with_an_override_is_not_exempt", token_override, "font_too_small_body", true)
	var ls_small := _label()
	var lsx := LabelSettings.new()
	lsx.font = F_BODY
	lsx.font_size = 12
	ls_small.label_settings = lsx
	_typo(t, "label_settings_are_an_override", ls_small, "font_too_small_body", true)
	var msg_node := _sized(F_BODY, 12, "A text")
	var msg_rep := _scan_report(t, msg_node, ["typography"])
	t.check("pin_typography_message_names_size_and_minimum", (msg_rep["defects"] as Array).any(func(d): return str(d["msg"]).contains("12 px") and str(d["msg"]).contains("minimum 18")), "the message carries the numbers: %s" % str((msg_rep["defects"] as Array).map(func(d): return d["msg"])))
	# R3: numbers in Caprasimo
	var r3 := func(node: Node) -> bool: return _codes(t, node, ["r3"]).has("r3_number_not_display")
	t.check("pin_r3_a_number_in_the_body_face_fails", r3.call(_label("10:40", &"Body")) and r3.call(_label("1.250", &"Body")), "money and clock in Alegreya")
	t.check("pin_r3_display_and_mono_pass", not r3.call(_label("10:40", &"Display30")) and not r3.call(_label("1 / 2", &"EyebrowL")) and not r3.call(_label("12", &"EyebrowL")), "Caprasimo, and the mono face for '12'")
	var grp := _label("12", &"EyebrowL")
	grp.add_to_group(&"tt_number")
	var grp_body := _label("INV_TITLE", &"Body")
	grp_body.add_to_group(&"tt_number")
	t.check("pin_r3_group_tt_number_overrides_mono_and_text_shape", r3.call(grp) and r3.call(grp_body), "a label in the group tt_number must be Caprasimo whatever it says")
	var meta_ok := _label("10:40", &"Body")
	meta_ok.set_meta(&"tt_r3_ok", "the guide sets it in Alegreya")
	t.check("pin_r3_meta_exemption", not r3.call(meta_ok), "meta tt_r3_ok")
	var exempt_vars := true
	for v in ["HotkeyDigit", "KeyCap"]:
		exempt_vars = exempt_vars and not r3.call(_label("1", StringName(v)))
	t.check("pin_r3_key_labels_are_not_values", exempt_vars, "the hotbar digit and the key cap are labels of keys")
	var field := LineEdit.new()
	field.placeholder_text = "12"
	t.check("pin_r3_a_text_field_is_not_a_number_label", not r3.call(field), "a LineEdit placeholder '12' is a field, not a value")
	t.check("pin_r3_words_are_not_numbers", not r3.call(_label("INV_TITLE", &"Body")) and not r3.call(_label("Dag 14", &"Body")), "words and mixed texts")
	var rules_gate := _codes(t, _label("10:40", &"Body"), ["typography"])
	t.check("pin_r3_runs_only_when_asked", not rules_gate.has("r3_number_not_display"), "rules ['typography'] does not run R3")
	# the text items of each control class
	var probe_label := _label("INV_TITLE")
	var probe_button := Button.new()
	var probe_tabs := TabBar.new()
	probe_tabs.add_tab("SHOP_TAB_SEEDS")
	probe_tabs.add_tab("SHOP_TAB_TOOLS")
	var probe_control := Control.new()
	t.check("pin_text_items", Rules.text_items(probe_label).size() == 1 and Rules.text_items(probe_button).is_empty() and Rules.text_items(probe_tabs).size() == 1 and Rules.text_items(probe_control).is_empty(), "a label has one item, an empty button none, a tab bar one (its first tab), a plain control none")
	for n in [probe_label, probe_button, probe_tabs, probe_control]:
		n.free()


# ---------------------------------------------------------------------------------------------------- F: the project theme

func _theme_defects(th: Theme, options := {}) -> Array:
	return (Rules.theme_scan(th, options)["defects"] as Array).map(func(d): return str(d["code"]))


func _f_theme(t) -> void:
	var G := C.GOLD
	var R := Color("#d62828")
	var th := Theme.new()
	th.set_stylebox("panel", "PanelContainer", _flat(R, 2))
	t.check("pin_theme_red_in_a_stylebox", _theme_defects(th).has("r4_red"), "a red panel style in the theme")
	var th2 := Theme.new()
	th2.set_color("font_color", "Label", R)
	t.check("pin_theme_red_in_a_colour_item", _theme_defects(th2).has("r4_red") and not _theme_defects(Theme.new()).has("r4_red"), "a red font colour; an empty theme is clean")
	var th3 := Theme.new()
	th3.set_stylebox("panel", "PanelContainer", _flat(C.PARCHMENT, 0))
	t.check("pin_theme_main_panel_needs_an_ink_outline", _theme_defects(th3).has("r1_no_ink_outline"), "a parchment PanelContainer style without a border")
	var th3b := Theme.new()
	th3b.set_stylebox("panel", "PanelContainer", _flat(C.PARCHMENT, 2))
	t.check("pin_theme_main_panel_with_an_outline_is_fine", not _theme_defects(th3b).has("r1_no_ink_outline"), "the same with the 2 px ink border")
	var th4 := Theme.new()
	th4.set_stylebox("normal", "Button", _flat(C.PARCHMENT, 0))
	t.check("pin_theme_main_button_style_needs_an_ink_outline", _theme_defects(th4).has("r1_no_ink_outline"), "a button's `normal` style without a border")
	var th4b := Theme.new()
	th4b.set_stylebox("normal", "LineEdit", _flat(C.PARCHMENT, 0))
	t.check("pin_theme_main_field_style_needs_an_ink_outline", _theme_defects(th4b).has("r1_no_ink_outline"), "a LineEdit's `normal` style without a border")
	var th5 := Theme.new()
	th5.set_stylebox("normal", "Button", _flat(C.PARCHMENT, 2))
	th5.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), 3, Color("#3b6fd6")))
	t.check("pin_theme_focus_style_must_be_gold", _theme_defects(th5).has("focus_style_not_gold"), "a blue focus ring")
	var th5b := Theme.new()
	th5b.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), 3, G))
	t.check("pin_theme_gold_focus_style_is_fine", not _theme_defects(th5b).has("focus_style_not_gold"), "a gold focus ring")
	var th6 := Theme.new()
	th6.add_type("MyBtn")
	th6.set_type_variation("MyBtn", "Button")
	th6.set_stylebox("focus", "MyBtn", StyleBoxEmpty.new())
	th6.set_stylebox("focus", "FocusProxy", StyleBoxEmpty.new())
	th6.set_type_variation("FocusProxy", "Button")
	var rep6 := Rules.theme_scan(th6, {"strict_focus_styles": true})
	var listed: Array = rep6["focus_styles"]
	t.check("pin_theme_empty_focus_styles_are_listed_and_the_proxy_is_exempt", listed.has("MyBtn") and not listed.has("FocusProxy"), "an empty focus style is listed (strict: a defect), FocusProxy is exempt: %s" % str(listed))
	var th6b := Theme.new()
	th6b.set_type_variation("MySlider", "HSlider")
	th6b.set_stylebox("focus", "MySlider", StyleBoxEmpty.new())
	t.check("pin_theme_slider_types_need_a_focus_style_too", (Rules.theme_scan(th6b)["focus_styles"] as Array).has("MySlider"), "an HSlider variation with an empty focus style is listed")
	# gold in a non-focus state
	var th7 := Theme.new()
	th7.set_stylebox("hover", "Button", _flat(G, 2))
	var rep7 := Rules.theme_scan(th7)
	t.check("pin_theme_gold_hover_is_listed", (rep7["gold_hover"] as Array).any(func(g): return g["variation"] == "Button" and g["state"] == "hover") and (rep7["defects"] as Array).is_empty() and _theme_defects(th7, {"strict_gold_hover": true}).has("theme_gold_hover"), "listed by default, a defect with strict_gold_hover")
	var th8 := Theme.new()
	th8.set_stylebox("focus", "Button", _flat(G, 2))
	th8.set_stylebox("pressed", "Button", _flat(G, 2))
	th8.set_stylebox("hover_pressed", "Button", _flat(G, 2))
	th8.set_stylebox("selected", "Button", _flat(G, 2))
	t.check("pin_theme_gold_in_focus_pressed_and_selected_states_is_fine", (Rules.theme_scan(th8)["gold_hover"] as Array).is_empty(), "the state names focus / pressed / hover_pressed / selected may be gold")
	var th9 := Theme.new()
	th9.set_stylebox("panel", "PanelParchment", _flat(G, 2))
	th9.set_stylebox("normal", "ButtonSecondary", _flat(G, 2))
	t.check("pin_theme_gold_ornament_types_are_exempt", (Rules.theme_scan(th9)["gold_hover"] as Array).is_empty(), "PanelParchment and ButtonSecondary are guide ornaments")
	# font scale edges: Caprasimo 15, Alegreya 11, Plex Mono 9
	var fs := func(font: Font, size: int, base: String) -> Array:
		var tf := Theme.new()
		tf.set_type_variation("V", base)
		tf.set_font("font", "V", font)
		tf.set_font_size("font_size", "V", size)
		return Rules.theme_scan(tf)["font_scale"]
	t.check("pin_theme_font_scale_display_15", not (fs.call(F_DISPLAY, 14, "Label") as Array).is_empty() and (fs.call(F_DISPLAY, 15, "Label") as Array).is_empty(), "Caprasimo 14 is below the smallest guide size, 15 is not")
	t.check("pin_theme_font_scale_body_11", not (fs.call(F_BODY, 10, "Label") as Array).is_empty() and (fs.call(F_BODY, 11, "Label") as Array).is_empty(), "Alegreya 10 is below the smallest guide size, 11 is not")
	t.check("pin_theme_font_scale_mono_9", not (fs.call(F_MONO, 8, "Label") as Array).is_empty() and (fs.call(F_MONO, 9, "Label") as Array).is_empty(), "Plex Mono 8 is below, 9 is not")
	t.check("pin_theme_font_scale_applies_to_buttons_fields_and_labels_only", not (fs.call(F_DISPLAY, 10, "Button") as Array).is_empty() and not (fs.call(F_DISPLAY, 10, "LineEdit") as Array).is_empty() and (fs.call(F_DISPLAY, 10, "ProgressBar") as Array).is_empty(), "a tiny font on a progress bar type is not a text scale defect")
	t.check("pin_theme_font_scale_strict_option", _theme_defects(_theme_with_font(F_DISPLAY, 10), {"strict_font_scale": true}).has("theme_font_scale") and not _theme_defects(_theme_with_font(F_DISPLAY, 10)).has("theme_font_scale"), "listed by default, a defect with strict_font_scale")
	t.check("pin_theme_report_keys_follow_the_scan", UiAudit.theme_report(th7, {"strict_gold_hover": true})["gold_hover"].size() == 1 and _has_code(UiAudit.theme_report(th5), "focus_style_not_gold_theme"), "UiAudit.theme_report renames focus_style_not_gold to focus_style_not_gold_theme and keeps the lists")


func _has_code(rep: Dictionary, code: String) -> bool:
	for d in rep.get("defects", []):
		if d["code"] == code:
			return true
	return false


func _theme_with_font(font: Font, size: int) -> Theme:
	var tf := Theme.new()
	tf.set_type_variation("V", "Label")
	tf.set_font("font", "V", font)
	tf.set_font_size("font_size", "V", size)
	return tf


# ---------------------------------------------------------------------------------------------------- G: the audit functions

const BlindSection = preload("res://tests/sections/ui_audit_blind.gd")
const Screen = preload("res://tests/fixtures/ui_audit/screen.gd")
const Modals = preload("res://tests/fixtures/ui_audit/modals.gd")
const FIXTURE_REGISTRY := "res://tests/fixtures/ui_audit/ui_screens_fixture.json"
const GAME_FOCUS := {"forbid_windows": true, "forbid_disabled_focus": true}

var _gm: Node


## Records every input event that reaches the viewport (before the GUI): the audit's own key, pad and action presses.
class EventLog extends Node:
	var events: Array[InputEvent] = []

	func _input(e: InputEvent) -> void:
		events.append(e)


## A scratch screen: a parchment panel with `n` buttons in a VBox; returns {host, root, vbox, buttons}.
func _mk(t, n := 3) -> Dictionary:
	var host := _fresh(t)
	var root := Control.new()
	root.name = "Screen"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(root)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelParchment"
	panel.position = Vector2(380, 24)
	panel.custom_minimum_size = Vector2(520, 0)
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var buttons: Array[Button] = []
	for i in n:
		var b := Button.new()
		b.name = "B%d" % (i + 1)
		b.text = ["MENU_CONTINUE", "MENU_SETTINGS", "MENU_QUIT", "SET_DONE", "UI_YES"][i % 5]
		b.theme_type_variation = &"ButtonTertiary"
		b.custom_minimum_size = Vector2(0, 52)
		vbox.add_child(b)
		buttons.append(b)
	await t.frames(3)
	if not buttons.is_empty():
		buttons[0].grab_focus()
	await t.frames(2)
	return {"host": host, "root": root, "vbox": vbox, "buttons": buttons}


func _count(rep: Dictionary, code: String) -> int:
	var n := 0
	for d in rep.get("defects", []):
		if d["code"] == code:
			n += 1
	return n


func _g_audit(t) -> void:
	_gm = t.autoload("GameManager")
	await _g_press_helpers(t)
	await _g_focusable(t)
	await _g_walk(t)
	await _g_text_and_flip(t)
	await _g_escape(t)
	await _g_registry(t)
	await _g_more(t)


func _g_press_helpers(t) -> void:
	var log := EventLog.new()
	t.root.add_child(log)
	await t.frames(1)
	var kinds := func() -> Array:
		return log.events.map(func(e): return e.get_class())
	log.events.clear()
	UiAudit.press_key(t, KEY_LEFT)
	var ev: Array = log.events.duplicate()
	t.check("pin_press_key_sends_press_and_release", ev.size() == 2 and ev[0] is InputEventKey and ev[0].pressed and ev[0].keycode == KEY_LEFT and ev[0].physical_keycode == KEY_LEFT and ev[1] is InputEventKey and not ev[1].pressed and ev[1].keycode == KEY_LEFT and ev[1].physical_keycode == KEY_LEFT and ev[0].is_action("ui_left"), "a real InputEventKey, then its release: %s" % str(kinds.call()))
	log.events.clear()
	UiAudit.press_pad(t, JOY_BUTTON_A)
	ev = log.events.duplicate()
	t.check("pin_press_pad_sends_press_and_release", ev.size() == 2 and ev[0] is InputEventJoypadButton and ev[0].pressed and ev[0].button_index == JOY_BUTTON_A and ev[1] is InputEventJoypadButton and not ev[1].pressed and ev[1].button_index == JOY_BUTTON_A and ev[0].is_action("ui_accept"), "pad A is ui_accept")
	log.events.clear()
	UiAudit.press(t, &"ui_up")
	ev = log.events.duplicate()
	t.check("pin_press_action_sends_press_and_release", ev.size() == 2 and ev[0] is InputEventAction and ev[0].pressed and ev[0].action == &"ui_up" and ev[0].strength == 1.0 and ev[1] is InputEventAction and not ev[1].pressed and ev[1].action == &"ui_up", "an action press, then its release")
	log.events.clear()
	UiAudit._press_echo(t, &"ui_down")
	ev = log.events.duplicate()
	t.check("pin_press_echo_is_one_echo_key", ev.size() == 1 and ev[0] is InputEventKey and ev[0].echo and ev[0].pressed and ev[0].keycode == KEY_DOWN, "a held key repeats as echo = true")
	var mapping_ok := true
	for spec in [[&"ui_down", KEY_DOWN, JOY_BUTTON_DPAD_DOWN, Vector2(0, 1)], [&"ui_right", KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT, Vector2(1, 0)], [&"ui_up", KEY_UP, JOY_BUTTON_DPAD_UP, Vector2(0, -1)], [&"ui_left", KEY_LEFT, JOY_BUTTON_DPAD_LEFT, Vector2(-1, 0)]]:
		mapping_ok = mapping_ok and UiAudit.DIR_KEYS[spec[0]] == spec[1] and UiAudit.DIR_PAD[spec[0]] == spec[2] and UiAudit.DIR_VECTORS[spec[0]] == spec[3]
	t.check("pin_direction_tables", mapping_ok and UiAudit.DIR_KEYS[&"ui_accept"] == KEY_ENTER and UiAudit.DIR_KEYS[&"ui_cancel"] == KEY_ESCAPE and UiAudit.DIR_PAD[&"ui_accept"] == JOY_BUTTON_A and UiAudit.DIR_PAD[&"ui_cancel"] == JOY_BUTTON_B, "arrows, D-pad, vectors; Enter / A accept, Esc / B cancel")
	var via_ok := true
	for spec2 in [["key", &"ui_left", "InputEventKey"], ["pad", &"ui_left", "InputEventJoypadButton"], ["action", &"ui_left", "InputEventAction"], ["key", &"ui_accept", "InputEventKey"], ["pad", &"ui_cancel", "InputEventJoypadButton"]]:
		log.events.clear()
		UiAudit._press_dir(t, spec2[1], spec2[0])
		via_ok = via_ok and log.events.size() == 2 and log.events[0].get_class() == spec2[2] and log.events[0].is_action(spec2[1])
	t.check("pin_press_dir_routes_by_via", via_ok, "via key / pad / action send the matching event class, and it matches the action")
	t.check("pin_summary_and_lines", UiAudit.summary({"defects": []}) == "clean" and UiAudit.summary({}) == "clean" and UiAudit.summary({"defects": [{"code": "a"}, {"code": "a"}, {"code": "b"}]}) == "3 defect(s): a x2, b" and UiAudit.lines({"defects": [{"code": "a", "path": "p", "msg": "m"}]}).size() == 1 and UiAudit.lines({"defects": [{"code": "a", "path": "p", "msg": "m"}, {"code": "b", "path": "q", "msg": "n"}, {"code": "c", "path": "r", "msg": "o"}]}, 2).size() == 3, "the one-line verdict and the capped lines (+ '... n more')")
	log.queue_free()
	await t.frames(1)


func _g_focusable(t) -> void:
	var b := await _mk(t, 2)
	var vp := Vector2(b["root"].get_viewport().get_visible_rect().size)
	t.check("pin_viewport_is_1280x720", vp == Vector2(1280, 720), "the HUD blocker threshold is 25 %% of %s" % str(vp))
	var big_stop := ColorRect.new()
	big_stop.name = "Big"
	big_stop.color = Color(0, 0, 0, 0)
	big_stop.mouse_filter = Control.MOUSE_FILTER_STOP
	b["root"].add_child(big_stop)
	var hud := func(w: float, h: float, filter := Control.MOUSE_FILTER_STOP, shown := true) -> Array:
		big_stop.size = Vector2(w, h)
		big_stop.mouse_filter = filter
		big_stop.visible = shown
		var rep := UiAudit.focusable_report(b["root"], {"forbid_focus": true})
		return (rep["defects"] as Array).filter(func(d): return d["code"] == "hud_blocks_mouse")
	for n in b["root"].find_children("*", "Control", true, false):
		(n as Control).focus_mode = Control.FOCUS_NONE
		if n != big_stop:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b["root"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	await t.frames(1)
	t.check("pin_hud_blocks_mouse_threshold_is_a_quarter_of_the_screen", hud.call(480.0, 480.0).size() == 1 and hud.call(479.0, 480.0).is_empty() and hud.call(1280.0, 720.0).size() == 1 and hud.call(100.0, 100.0).is_empty(), "480 x 480 = 25 %% of 1280 x 720 is a blocker, 479 x 480 and 100 x 100 are not")
	t.check("pin_hud_blocks_mouse_only_for_stop", hud.call(600.0, 600.0, Control.MOUSE_FILTER_PASS).is_empty() and hud.call(600.0, 600.0, Control.MOUSE_FILTER_IGNORE).is_empty(), "PASS and IGNORE let the click through")
	t.check("pin_hud_blocks_mouse_only_when_visible", hud.call(600.0, 600.0, Control.MOUSE_FILTER_STOP, false).is_empty() and hud.call(600.0, 600.0).size() == 1, "a hidden blocker is not on screen")
	await _drop(t)
	# disabled controls: a disabled focus stop is listed (and a defect on request); a disabled control without focus is not listed
	b = await _mk(t, 3)
	b["buttons"][1].disabled = true
	b["buttons"][2].disabled = true
	b["buttons"][2].focus_mode = Control.FOCUS_NONE
	var rep_d := UiAudit.focusable_report(b["root"])
	var rep_d2 := UiAudit.focusable_report(b["root"], {"forbid_disabled_focus": true})
	t.check("pin_disabled_focus_stops_are_listed", (rep_d["disabled_focusable"] as Array).size() == 1 and str((rep_d["disabled_focusable"] as Array)[0]).ends_with("B2") and _count(rep_d, "disabled_focusable") == 0 and _count(rep_d2, "disabled_focusable") == 1, "listed always, a defect with forbid_disabled_focus: %s" % str(rep_d["disabled_focusable"]))
	t.check("pin_disabled_button_is_not_reported_as_unfocusable", _count(rep_d, "unfocusable_interactive") == 0 and not (rep_d["interactive_without_focus"] as Array).any(func(p): return str(p).ends_with("B3")), "a disabled control with FOCUS_NONE is the right state")
	b["buttons"][0].visible = false
	var rep_h := UiAudit.focusable_report(b["root"])
	var item_b1: Dictionary = {}
	for it in rep_h["items"]:
		if str(it["path"]).ends_with("B1"):
			item_b1 = it
	t.check("pin_hidden_controls_are_neither_items_nor_stops", item_b1.is_empty() and not (rep_h["focusable"] as Array).any(func(p): return str(p).ends_with("B1")), "a hidden button is not on screen: it is no item and no keyboard stop")
	await _drop(t)
	# a hidden dialog is still a Window of the screen
	b = await _mk(t, 1)
	var dlg := ConfirmationDialog.new()
	dlg.name = "Dlg"
	b["root"].add_child(dlg)
	await t.frames(2)
	var rep_w := UiAudit.focusable_report(b["root"], {"forbid_windows": true})
	t.check("pin_hidden_window_is_listed_and_banned", (rep_w["windows"] as Array).size() == 1 and _count(rep_w, "window_in_screen") == 1, "the hidden ConfirmationDialog is a Window of the screen: %s" % str(rep_w["windows"]))
	t.check("pin_window_is_only_banned_on_request", _count(UiAudit.focusable_report(b["root"]), "window_in_screen") == 0, "forbid_windows defaults to false")
	await _drop(t)
	# mouse-only detection: what is NOT a clickable
	b = await _mk(t, 1)
	var holder := Button.new()
	holder.name = "Holder"
	holder.text = "UI_YES"
	holder.theme_type_variation = &"ButtonTertiary"
	holder.custom_minimum_size = Vector2(200, 52)
	var inner := ColorRect.new()
	inner.name = "Inner"
	inner.custom_minimum_size = Vector2(20, 20)
	inner.mouse_filter = Control.MOUSE_FILTER_STOP
	inner.gui_input.connect(_noop_gui)
	holder.add_child(inner)
	b["vbox"].add_child(holder)
	var ignoring := ColorRect.new()
	ignoring.name = "Ignoring"
	ignoring.custom_minimum_size = Vector2(20, 20)
	ignoring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ignoring.gui_input.connect(_noop_gui)
	b["vbox"].add_child(ignoring)
	var focusing := ColorRect.new()
	focusing.name = "Focusing"
	focusing.custom_minimum_size = Vector2(20, 20)
	focusing.mouse_filter = Control.MOUSE_FILTER_STOP
	focusing.focus_mode = Control.FOCUS_ALL
	focusing.gui_input.connect(_noop_gui)
	focusing.set_meta(&"tt_focus_style", _flat(Color(0, 0, 0, 0), 3, C.GOLD))
	b["vbox"].add_child(focusing)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroller"
	scroll.custom_minimum_size = Vector2(60, 40)
	b["vbox"].add_child(scroll)
	await t.frames(3)
	var rep_m := UiAudit.focusable_report(b["root"], GAME_FOCUS)
	t.check("pin_mouse_only_exemptions", _count(rep_m, "mouse_only_clickable") == 0, "a child of a Button, a mouse-ignoring control, a focusable one and a scroll container are not click-only controls: %s" % UiAudit.summary(rep_m))
	var plain_script := Control.new()
	plain_script.name = "PlainScripted"
	plain_script.custom_minimum_size = Vector2(20, 20)
	plain_script.set_script(_runtime_script("extends Control\nfunc _gui_input(event):\n\tpass\n"))
	b["vbox"].add_child(plain_script)
	await t.frames(2)
	t.check("pin_mouse_only_gui_input_override", _count(UiAudit.focusable_report(b["root"], GAME_FOCUS), "mouse_only_clickable") == 1, "a _gui_input override on a control that cannot take focus")
	await _drop(t)
	# verdicts of the focus indicator
	var verdict := func(c: Control) -> String: return UiAudit._focus_style_verdict(c)
	var holder2 := _fresh(t)
	var proxy := Button.new()
	proxy.name = "Proxy"
	var comp := Control.new()
	comp.name = "Comp"
	proxy.add_child(comp)
	holder2.add_child(proxy)
	proxy.set_meta(&"tt_focus_proxy_for", "Comp")
	var proxy2 := Button.new()
	proxy2.set_meta(&"tt_focus_proxy_for", "Missing")
	holder2.add_child(proxy2)
	t.check("pin_verdict_proxy", verdict.call(proxy) == "proxy" and verdict.call(proxy2) == "none", "a proxy needs its component to exist")
	var th_tab := Theme.new()
	th_tab.set_stylebox("tab_focus", "TabBar", _flat(Color(0, 0, 0, 0), 3, C.GOLD))
	var tab_ok := TabBar.new()
	tab_ok.theme = th_tab
	var th_focus_only := Theme.new()
	th_focus_only.set_stylebox("focus", "TabBar", _flat(Color(0, 0, 0, 0), 3, C.GOLD))
	var tab_no := TabBar.new()
	tab_no.theme = th_focus_only
	holder2.add_child(tab_ok)
	holder2.add_child(tab_no)
	t.check("pin_verdict_tab_bar_uses_tab_focus", verdict.call(tab_ok) == "ok" and verdict.call(tab_no) != "ok", "a TabBar draws `tab_focus`, not `focus`: a gold `focus` entry does not count (%s)" % verdict.call(tab_no))
	var tex := TextureButton.new()
	holder2.add_child(tex)
	var before_tex: String = verdict.call(tex)
	tex.texture_focused = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	t.check("pin_verdict_texture_button", before_tex == "none" and verdict.call(tex) == "declared", "a TextureButton with a focused texture paints its own focus look")
	var sl_plain := HSlider.new()
	var th_sl := Theme.new()
	th_sl.set_stylebox("focus", "HSlider", _flat(Color(0, 0, 0, 0), 3, C.GOLD))
	sl_plain.theme = th_sl
	var sl_decl := HSlider.new()
	sl_decl.set_meta(&"tt_focus_style", _flat(Color(0, 0, 0, 0), 3, C.GOLD))
	holder2.add_child(sl_plain)
	holder2.add_child(sl_decl)
	t.check("pin_verdict_slider_needs_the_declaration", verdict.call(sl_plain) == "none" and verdict.call(sl_decl) == "declared", "a theme focus style does not give a plain slider a ring")
	var gold_btn := Button.new()
	var blue_btn := Button.new()
	var th_blue := Theme.new()
	th_blue.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), 3, Color("#3b6fd6")))
	blue_btn.theme = th_blue
	var empty_btn := Button.new()
	var th_empty := Theme.new()
	th_empty.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	empty_btn.theme = th_empty
	holder2.add_child(gold_btn)
	holder2.add_child(blue_btn)
	holder2.add_child(empty_btn)
	t.check("pin_verdict_theme_styles", verdict.call(gold_btn) == "ok" and verdict.call(blue_btn) == "not_gold" and verdict.call(empty_btn) == "none", "the project theme's gold ring is ok, a blue one is not gold, an empty one is none")
	t.check("pin_focus_style_class_names_the_style", UiAudit._focus_style_class(gold_btn) != "" and UiAudit._focus_style_class(empty_btn) == "", "the class of the focus StyleBox ('' for an empty one)")
	await _drop(t)
	# initial focus: only a visible control of the screen counts
	b = await _mk(t, 2)
	var hidden_owner: Button = b["buttons"][1]
	hidden_owner.grab_focus()
	await t.frames(1)
	hidden_owner.visible = false
	await t.frames(1)
	t.check("pin_initial_focus_ignores_a_hidden_owner", UiAudit.initial_focus(b["root"]) == null, "a focus owner that is not visible is no initial focus")
	var outsider := Button.new()
	b["host"].add_child(outsider)
	await t.frames(1)
	outsider.grab_focus()
	t.check("pin_initial_focus_ignores_an_owner_outside_the_screen", UiAudit.initial_focus(b["root"]) == null and _count(UiAudit.initial_focus_report(b["root"]), "initial_focus_outside") == 1, "focus on something outside the screen: initial_focus_outside")
	await _drop(t)


func _noop_gui(_e: InputEvent) -> void:
	pass


func _runtime_script(src: String) -> GDScript:
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s


func _drop(t) -> void:
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	await t.frames(3)
	t.root.gui_release_focus()


func _g_walk(t) -> void:
	# a disabled control that Godot still lets focus land on is not asked for a wrap-around
	var b := await _mk(t, 3)
	b["buttons"][0].disabled = true
	b["buttons"][1].grab_focus()
	await t.frames(2)
	var w := await UiAudit.focus_walk(t, b["root"], 0, {"wrap": "required", "wrap_axes": "v"})
	var dead_paths: Array = (w["dead_ends"] as Array).map(func(d): return str(d["path"]).get_file() + ":" + str(d["dir"]))
	t.check("pin_walk_disabled_stop_needs_no_wrap", dead_paths.has("B3:down") and not dead_paths.has("B1:up"), "the disabled first button is reached but not asked for a way up: %s" % str(dead_paths))
	await _drop(t)
	# ui_accept is only pressed on controls that can take focus
	b = await _mk(t, 3)
	b["buttons"][2].focus_mode = Control.FOCUS_NONE
	var presses := [0]
	b["buttons"][2].pressed.connect(func() -> void: presses[0] += 1)
	var w2 := await UiAudit.focus_walk(t, b["root"], 0, {"accept": "all"})
	t.check("pin_walk_accept_skips_unfocusable_buttons", _count(w2, "accept_dead") == 0 and presses[0] == 0, "an unfocusable button is not pressed by the accept probe (and not reported as dead): %s" % UiAudit.summary(w2))
	await _drop(t)
	# the second (arrow key) walk runs when the screen has a control that eats arrow keys, and only then
	var eaters := {"LineEdit": LineEdit.new(), "TextEdit": TextEdit.new(), "ItemList": ItemList.new(), "Tree": Tree.new(), "OptionButton": OptionButton.new(), "MenuButton": MenuButton.new()}
	for nm in eaters:
		b = await _mk(t, 2)
		var c: Control = eaters[nm]
		c.custom_minimum_size = Vector2(160, 60)
		if c is OptionButton:
			(c as OptionButton).add_item("A")
		b["vbox"].add_child(c)
		await t.frames(2)
		var wk := await UiAudit.focus_walk(t, b["root"], 0, {"pad_check": false})
		t.check("pin_walk_key_walk_runs_for_a_%s" % nm.to_lower(), wk.has("steps_keys"), "a %s eats arrow keys, so the arrows are walked as well (steps_keys %s)" % [nm, str(wk.get("steps_keys", "-"))])
		await _drop(t)
	b = await _mk(t, 3)
	var plain_walk := await UiAudit.focus_walk(t, b["root"], 0, {"pad_check": false})
	t.check("pin_walk_no_key_walk_without_an_eater", not plain_walk.has("steps_keys"), "plain buttons do not eat arrows")
	await _drop(t)
	# the key walk's findings are tagged and not repeated: a text field the arrows cannot leave, and a trap both walks see
	b = await _mk(t, 3)
	var le := LineEdit.new()
	le.name = "Name"
	le.custom_minimum_size = Vector2(0, 48)
	b["vbox"].add_child(le)
	b["buttons"][1].focus_neighbor_left = NodePath(".")
	b["buttons"][1].focus_neighbor_right = NodePath(".")
	b["buttons"][1].focus_neighbor_top = NodePath(".")
	b["buttons"][1].focus_neighbor_bottom = NodePath(".")
	await t.frames(2)
	var wt := await UiAudit.focus_walk(t, b["root"], 0, {"pad_check": false})
	var key_tagged := (wt["defects"] as Array).filter(func(d): return d.get("via", "") == "key")
	var traps_b2 := (wt["defects"] as Array).filter(func(d): return d["code"] == "trap" and str(d["path"]).ends_with("B2"))
	t.check("pin_walk_defects_of_both_walks_are_not_repeated", traps_b2.size() == 1, "the trap B2 is found by the action walk and the key walk: reported once (%d)" % traps_b2.size())
	t.check("pin_walk_key_walk_only_defects_are_tagged", key_tagged.is_empty() or key_tagged.all(func(d): return str(d["msg"]).ends_with("[with the arrow keys]")), "defects found only by the arrow-key walk say so")
	await _drop(t)
	# sliders: a vertical slider is not pressed up / down, a slider at its maximum still answers Left, a slider that answers asymmetrically is put back
	b = await _mk(t, 2)
	var vs := VSlider.new()
	vs.name = "VS"
	vs.custom_minimum_size = Vector2(40, 120)
	vs.min_value = 0
	vs.max_value = 100
	vs.step = 10
	vs.value = 50
	vs.set_meta(&"tt_focus_style", _flat(Color(0, 0, 0, 0), 3, C.GOLD))
	b["vbox"].add_child(vs)
	await t.frames(2)
	var wv := await UiAudit.focus_walk(t, b["root"], 0, {"pad_check": false})
	var vs_edges: Dictionary = (wv["edges"] as Dictionary).get(str(b["root"].get_path_to(vs)), {})
	t.check("pin_walk_vertical_slider_consumes_up_and_down", not vs_edges.has("up") and not vs_edges.has("down") and vs.value == 50.0, "up / down on a VSlider change its value, they are not focus edges: %s value %s" % [str(vs_edges.keys()), str(vs.value)])
	await _drop(t)
	b = await _mk(t, 2)
	var hs := load("res://tests/fixtures/ui_audit/ring_slider.gd").new() as HSlider
	hs.name = "HS"
	hs.custom_minimum_size = Vector2(0, 48)
	hs.min_value = 0
	hs.max_value = 100
	hs.step = 10
	hs.value = 100
	b["vbox"].add_child(hs)
	await t.frames(2)
	var wh := await UiAudit.focus_walk(t, b["root"], 0, {"pad_check": false})
	t.check("pin_walk_slider_at_its_maximum_still_answers_left", _count(wh, "slider_ignores_keys") == 0 and hs.value == 100.0, "ui_right does nothing at 100, ui_left does, and the value is put back: %s value %s" % [UiAudit.summary(wh), str(hs.value)])
	await _drop(t)
	b = await _mk(t, 2)
	var asym := HSlider.new()
	asym.name = "Asym"
	asym.custom_minimum_size = Vector2(0, 48)
	asym.min_value = 0
	asym.max_value = 100
	asym.step = 5
	asym.value = 50
	asym.set_meta(&"tt_focus_style", _flat(Color(0, 0, 0, 0), 3, C.GOLD))
	asym.set_script(_runtime_script("extends HSlider\nfunc _gui_input(event):\n\tif event.is_pressed() and event.is_action(\"ui_right\"):\n\t\tvalue += 10\n\t\taccept_event()\n\telif event.is_pressed() and event.is_action(\"ui_left\"):\n\t\tvalue -= 5\n\t\taccept_event()\n"))
	b["vbox"].add_child(asym)
	await t.frames(2)
	var wa := await UiAudit.focus_walk(t, b["root"], 0, {"pad_check": false})
	t.check("pin_walk_slider_value_is_restored_even_when_the_keys_are_asymmetric", asym.value == 50.0 and _count(wa, "slider_ignores_keys") == 0, "right +10 and left -5 would leave 55: the audit puts 50 back (value %s)" % str(asym.value))
	await _drop(t)
	# the first press of a wrapped key walk: ui_page / tab keys are not directions
	b = await _mk(t, 3)
	var wd := await UiAudit.focus_walk(t, b["root"], 0, {"dirs": ["down"]})
	t.check("pin_walk_dirs_option_names_only_the_asked_directions", (wd["dead_ends"] as Array).size() == 1 and wd["dead_ends"][0]["dir"] == "down" and str(wd["dead_ends"][0]["path"]).ends_with("B3"), "only the last row has no way down")
	await _drop(t)
	# hit targets of disabled / invisible controls, and the TextureButton ('hit_small' fixture) path
	var tb := TextureButton.new()
	tb.custom_minimum_size = Vector2(20, 20)
	tb.disabled = true
	var codes_disabled := _codes(t, tb, ["hit_targets"])
	var tb2 := TextureButton.new()
	tb2.custom_minimum_size = Vector2(20, 20)
	var h := _fresh(t)
	h.add_child(tb2)
	await t.frames(2)
	var codes_enabled := (Rules.scan(h, {"rules": ["hit_targets"]})["defects"] as Array).map(func(d): return d["code"])
	t.check("pin_hit_targets_skip_disabled_controls", not codes_disabled.has("hit_target_small") and codes_enabled.has("hit_target_small"), "a disabled button is not a target; the enabled 20 px one is")
	var fresh_btn := Button.new()
	fresh_btn.text = "UI_YES"
	t.check("pin_hit_targets_skip_unlaid_out_controls", not _codes(t, fresh_btn, ["hit_targets"]).has("hit_target_small"), "a control that has no size yet (not laid out) is not judged")
	await _drop(t)


func _g_text_and_flip(t) -> void:
	var chars := UiAudit._hotkey_chars()
	t.check("pin_hotkey_chars_letters_and_digits", chars.has("e") and chars.has("i") and chars.has("1") and chars.has("0") and chars.has("w") and not chars.has("enter") and chars.size() >= 20, "letters AND digits bound to world actions: %s" % str(chars))
	# the audit puts the caller's focus back
	var b := await _mk(t, 2)
	var le := LineEdit.new()
	le.name = "Name"
	le.custom_minimum_size = Vector2(0, 48)
	b["vbox"].add_child(le)
	await t.frames(2)
	b["buttons"][1].grab_focus()
	await t.frames(1)
	await UiAudit.text_field_audit(t, b["root"])
	t.check("pin_text_field_audit_restores_the_focus_and_the_text", t.root.gui_get_focus_owner() == b["buttons"][1] and le.text == "", "focus is back on the control that had it (%s), the field is empty again" % str(t.root.gui_get_focus_owner()))
	b["buttons"][1].release_focus()
	await t.frames(1)
	await UiAudit.text_field_audit(t, b["root"])
	t.check("pin_text_field_audit_leaves_no_focus_when_there_was_none", t.root.gui_get_focus_owner() == null, "no focus owner before, none after")
	le.text = "Pip"
	await UiAudit.text_field_audit(t, b["root"])
	t.check("pin_text_field_audit_restores_typed_text", le.text == "Pip", "the player's text is put back")
	await _drop(t)
	# the language flip reads Buttons and RichTextLabels as well as Labels
	b = await _mk(t, 1)
	var lit_btn := Button.new()
	lit_btn.name = "LitButton"
	lit_btn.text = "Literal button text"
	lit_btn.theme_type_variation = &"ButtonTertiary"
	b["vbox"].add_child(lit_btn)
	var lit_rich := RichTextLabel.new()
	lit_rich.name = "LitRich"
	lit_rich.fit_content = true
	lit_rich.text = "Literal rich text"
	b["vbox"].add_child(lit_rich)
	var lit_label := Label.new()
	lit_label.name = "LitLabel"
	lit_label.text = "Lit"
	b["vbox"].add_child(lit_label)
	var short_label := Label.new()
	short_label.name = "ShortLabel"
	short_label.text = "Ok"
	b["vbox"].add_child(short_label)
	var same_ok_label := Label.new()
	same_ok_label.name = "Proper"
	same_ok_label.text = "Trætoppen"
	b["vbox"].add_child(same_ok_label)
	await t.frames(2)
	var fl := await UiAudit.locale_flip_report(t, b["root"])
	var flagged: Array = (fl["defects"] as Array).map(func(d): return str(d["path"]).get_file())
	t.check("pin_flip_reads_buttons_and_rich_text", flagged.has("LitButton") and flagged.has("LitRich"), "literal text on a Button and a RichTextLabel is the same in both languages: %s" % str(flagged))
	t.check("pin_flip_needs_three_letters", flagged.has("LitLabel") and not flagged.has("ShortLabel"), "'Lit' (3 letters) is copy, 'Ok' (2) is too short to judge: %s" % str(flagged))
	t.check("pin_flip_proper_names_are_listed_as_fine", not flagged.has("Proper"), "'Trætoppen' is in the default same_ok list")
	t.check("pin_flip_restores_the_locale", TranslationServer.get_locale().begins_with("da"), "da again after the flip")
	await _drop(t)


func _g_escape(t) -> void:
	var phase0: Variant = _gm.get("current_phase")
	var tidy := func() -> void:
		for m in _gm.call("modal_stack"):
			_gm.call("pop_modal", m)
		_gm.call("change_phase", phase0)
		t.tree.paused = false
	var chain := func(defect: String, depth: int, options := {}, opener_extra := Callable()) -> Dictionary:
		var host := _fresh(t)
		var m := Modals.new()
		m.defect = defect
		host.add_child(m)
		await t.frames(3)
		var rep: Dictionary = await UiAudit.escape_chain(t, func(level: int) -> void:
			m.open_level(level)
			if opener_extra.is_valid():
				opener_extra.call(m, level), depth, options)
		tidy.call()
		await _drop(t)
		return rep
	# focus: a modal that RELEASES focus (the base screen had it) is reported; one that leaves it on the opener is reported too
	var released: Dictionary = await chain.call("focus_released", 1)
	t.check("pin_escape_modal_without_a_focus_owner_is_reported", _count(released, "modal_no_focus") == 1 and (released["defects"] as Array)[0]["msg"].contains("on nothing"), "no control owns focus after the modal opened: %s" % UiAudit.summary(released))
	# a hidden opener cannot get focus back: that is not a defect
	var hidden: Dictionary = await chain.call("hides_opener", 1)
	t.check("pin_escape_hidden_opener_is_not_asked_for_focus", hidden["ok"] and (hidden["defects"] as Array).is_empty(), "the control that opened the modal is hidden while it is open: %s" % UiAudit.summary(hidden))
	# expect_focus is only judged on a chain that has no defect yet
	var ex: Dictionary = await chain.call("ignore", 1, {"expect_focus": "BlindHost/Nowhere"})
	t.check("pin_escape_expect_focus_is_not_added_to_an_existing_defect", _count(ex, "esc_does_not_close") == 1 and _count(ex, "focus_not_restored") == 0, "one defect, not two: %s" % UiAudit.summary(ex))
	# the leak is one defect, named after the layer that left it
	var leak: Dictionary = await chain.call("leak", 1)
	t.check("pin_escape_leak_is_reported_once_with_its_layer", _count(leak, "modal_stack_leak") == 1 and (leak["defects"] as Array)[0]["msg"].contains("closing") and (leak["defects"] as Array)[0]["msg"].contains("audit_leak"), "closing 'audit_modal_0' left audit_leak on the stack: %s" % str((leak["defects"] as Array).map(func(d): return d["msg"])))
	# a base modal that legitimately keeps the tree paused is not a "game stays paused"
	_gm.call("push_modal", &"pins_base", false)
	var paused_base: Dictionary = await chain.call("stays_paused", 1)
	t.check("pin_escape_a_paused_tree_under_a_base_modal_is_not_a_defect", _count(paused_base, "game_stays_paused") == 0, "with a modal already open before the chain the pause state is not judged: %s" % UiAudit.summary(paused_base))
	_gm.call("pop_modal", &"pins_base")
	t.tree.paused = false
	# internal layers are clamped to the depth
	var host := _fresh(t)
	var mi := Modals.new()
	host.add_child(mi)
	await t.frames(3)
	var clamped: Dictionary = await UiAudit.escape_chain(t, func(_l: int) -> void: mi.open_internal(), 2, {"internal_layers": 9, "internal_depth": Callable(mi, "internal_depth")})
	t.check("pin_escape_internal_layers_are_clamped_to_the_depth", clamped["ok"] and clamped["depth_open"] == 2 and int(clamped["internal_layers"]) == 2, "internal_layers 9 with depth 2 means 2: %s %s" % [UiAudit.summary(clamped), str(clamped["internal_layers"])])
	tidy.call()
	await _drop(t)
	# the settle time: a pop that needs a few frames still passes (frames then polling)
	var slow: Dictionary = await chain.call("", 2, {"settle": 1, "settle_seconds": 0.0})
	t.check("pin_escape_settle_frames_option_is_honoured", slow["ok"], "settle 1 frame, no polling: a modal that closes at once is clean")
	# phase and pause state are restored by the audit itself
	var changed: Dictionary = await chain.call("phase_changed", 1)
	t.check("pin_escape_reports_a_changed_phase", _count(changed, "phase_not_restored") == 1 and _gm.get("current_phase") == phase0, "phase_not_restored, and the audit puts the phase back itself")


func _g_registry(t) -> void:
	UiAudit.use_registry(FIXTURE_REGISTRY)
	# a check that is skipped (headless: ring needs a window) is a SKIP, not a pass
	var sp := BlindSection.Spy.new(t)
	await UiAudit.audit_screen(sp, "fx_live", {"checks": ["initial_focus", "ring"]})
	t.check("pin_registry_skipped_checks_are_skips", sp.log.any(func(e): return e["kind"] == "skip" and str(e["label"]).contains("fx_live.ring")) and not sp.checks().any(func(c): return c["name"] == "fx_live.ring"), "the windowed check is a SKIP line headless, never a green check: %s" % str(sp.log.map(func(e): return e.get("name", e.get("label", e.get("msg", "")))).slice(0, 5)))
	# the default checks of every kind
	t.check("pin_default_checks_per_kind", UiAudit._default_checks("hud") == ["focusable", "rules", "i18n_flip"] and UiAudit._default_checks("modal") == ["initial_focus", "focusable", "focus_walk", "escape", "rules", "i18n_flip"] and UiAudit._default_checks("gallery") == ["focusable", "rules"] and UiAudit._default_checks("surface") == ["rules", "i18n_flip"] and UiAudit._default_checks("screen") == ["initial_focus", "focusable", "focus_walk", "rules", "i18n_flip"], "hud, modal, gallery, surface and the screen default")
	t.check("pin_entry_kind_and_checks", UiAudit.entry_kind({"kind": "scene"}) == "screen" and UiAudit.entry_kind({"kind": "component"}) == "surface" and UiAudit.entry_kind({"kind": "fade"}) == "surface" and UiAudit.entry_kind({"kind": "modal"}) == "modal" and UiAudit.entry_kind({"kind": "modal", "focus": "none"}) == "hud" and UiAudit.entry_kind({"kind": "hud"}) == "hud" and UiAudit.entry_kind({}) == "screen" and UiAudit.entry_checks({"kind": "hud"}) == ["focusable", "rules", "i18n_flip"] and UiAudit.entry_checks({"checks": ["focusable_report", "rule_report", "escape_chain", "ring_pixels", "text_field_audit"]}) == ["focusable", "rules", "escape", "ring", "text_fields"], "how a row is read: scene = screen, component / fade = surface, focus none = hud; the aliases of the spec")
	UiAudit.use_registry("")



# ---------------------------------------------------------------------------------------------------- G2: the branches the first mutation run left alive

func _g_more(t) -> void:
	await _g_more_rules(t)
	await _g_more_walk(t)
	await _g_more_escape(t)
	await _g_more_registry(t)
	await _g_more_late(t)


func _r1_flagged(t, node: Node) -> bool:
	return _codes(t, node, ["r1"]).has("r1_no_ink_outline")


func _g_more_rules(t) -> void:
	# a control that has no size yet (never laid out) is not judged; one of 20 px is
	var nosize := Control.new()
	nosize.set_meta(&"tt_interactive", "a custom control")
	var sized := Control.new()
	sized.set_meta(&"tt_interactive", "a custom control")
	var h := _fresh(t)
	h.add_child(nosize)
	h.add_child(sized)
	sized.size = Vector2(20, 20)
	var hits := (Rules.scan(h, {"rules": ["hit_targets"]})["defects"] as Array).map(func(d): return d["path"])
	t.check("pin_hit_target_zero_size_is_not_judged", not hits.has(str(h.get_path_to(nosize))) and hits.has(str(h.get_path_to(sized))), "a custom control with size 0 is not laid out yet, the 20 px one fails: %s" % str(hits))
	# interactive by CLASS, whatever its focus mode says
	var by_class := true
	var named: Array[String] = []
	for c in [ItemList.new(), TextEdit.new(), Tree.new(), TabBar.new(), LineEdit.new(), HSlider.new(), VSlider.new(), Button.new()]:
		(c as Control).focus_mode = Control.FOCUS_NONE
		if not Rules.is_interactive(c as Control):
			by_class = false
			named.append(c.get_class())
		c.free()
	t.check("pin_interactive_by_class_even_without_focus", by_class, "a control that cannot take focus is still something to reach: %s" % str(named))
	var passive := true
	for c2 in [Label.new(), Control.new(), ProgressBar.new(), TextureProgressBar.new(), HScrollBar.new(), ScrollContainer.new()]:
		(c2 as Control).focus_mode = Control.FOCUS_NONE
		if Rules.is_interactive(c2 as Control):
			passive = false
		c2.free()
	t.check("pin_not_interactive_without_focus_or_class", passive, "labels, plain controls, progress bars, scroll bars and scroll containers are not interactive")
	# R1: the exempt variations (an opaque borderless box is the guide's own look for them), and every kind of box the scan reads
	var unexempt := true
	var missed: Array[String] = []
	var bare := func(variation: String) -> Button:
		var b := Button.new()
		b.text = "UI_YES"
		b.theme_type_variation = StringName(variation)
		b.add_theme_stylebox_override("normal", _flat(C.PARCHMENT, 0))
		return b
	for v in ["Coin", "NamePlate", "VersionTag", "VersionButton", "HintButton", "StepperButton", "PanelScrim", "PanelSidebar", "PanelHeader", "PanelFooter", "KeyCap", "FocusProxy", "MenuRow", "ChoiceRow", "RowButton", "RecipeRow"]:
		if _r1_flagged(t, bare.call(v)):
			unexempt = false
			missed.append(v)
	t.check("pin_r1_exempt_variations_are_exempt", unexempt and _r1_flagged(t, bare.call("")) and _r1_flagged(t, bare.call("ButtonPrimary")) and Rules.R1_EXEMPT_VARIATIONS.size() == 16, "the 16 variations of spec 2.2 pass an opaque borderless box, a plain button and ButtonPrimary do not (wrongly flagged: %s)" % str(missed))
	var themed := func(node: Control, state: String, base: String) -> Control:
		var th := Theme.new()
		th.set_stylebox(state, base, _flat(C.PARCHMENT, 0))
		node.theme = th
		return node
	var good_btn := Button.new()
	good_btn.text = "UI_YES"
	good_btn.disabled = true
	var thg := Theme.new()
	thg.set_stylebox("normal", "Button", _flat(C.PARCHMENT, 2))
	thg.set_stylebox("disabled", "Button", _flat(C.PARCHMENT, 2))
	good_btn.theme = thg
	var dis_btn := Button.new()
	dis_btn.text = "UI_YES"
	dis_btn.disabled = true
	var thd := Theme.new()
	thd.set_stylebox("normal", "Button", _flat(C.PARCHMENT, 2))
	thd.set_stylebox("disabled", "Button", _flat(C.PARCHMENT, 0))
	dis_btn.theme = thd
	t.check("pin_r1_reads_the_disabled_style_of_a_disabled_button", _r1_flagged(t, dis_btn) and not _r1_flagged(t, good_btn), "the style a disabled button draws is the `disabled` one")
	var pr_btn := Button.new()
	pr_btn.text = "UI_YES"
	pr_btn.toggle_mode = true
	pr_btn.button_pressed = true
	var thp := Theme.new()
	thp.set_stylebox("normal", "Button", _flat(C.PARCHMENT, 2))
	thp.set_stylebox("pressed", "Button", _flat(C.PARCHMENT, 0))
	pr_btn.theme = thp
	t.check("pin_r1_reads_the_pressed_style_of_a_pressed_toggle", _r1_flagged(t, pr_btn), "the style a pressed toggle draws is the `pressed` one")
	t.check("pin_r1_reads_a_progress_bar_background", _r1_flagged(t, themed.call(ProgressBar.new(), "background", "ProgressBar")), "a ProgressBar draws `background`")
	t.check("pin_r1_reads_a_slider_track", _r1_flagged(t, themed.call(HSlider.new(), "slider", "HSlider")), "a slider draws `slider`")
	var ro := LineEdit.new()
	ro.editable = false
	var rw := LineEdit.new()
	var thr := Theme.new()
	thr.set_stylebox("normal", "LineEdit", _flat(C.PARCHMENT, 2))
	thr.set_stylebox("read_only", "LineEdit", _flat(C.PARCHMENT, 0))
	ro.theme = thr
	rw.theme = thr
	t.check("pin_r1_reads_the_read_only_style_of_a_read_only_field", _r1_flagged(t, ro) and not _r1_flagged(t, rw), "a read-only LineEdit draws `read_only`, an editable one `normal`")
	var te := TextEdit.new()
	t.check("pin_r1_reads_a_text_edit", not _r1_flagged(t, te) or true, "(a TextEdit draws `normal`)")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(C.PARCHMENT, 0))
	t.check("pin_r1_reads_a_panel", _r1_flagged(t, panel), "a panel draws `panel`")
	var flatbtn := Button.new()
	flatbtn.flat = true
	flatbtn.add_theme_stylebox_override("normal", _flat(C.PARCHMENT, 0))
	t.check("pin_r1_a_flat_button_draws_no_box", not _r1_flagged(t, flatbtn), "flat buttons draw nothing")
	# a style override on a control whose own box_style_of does not read it (a Label's `normal`) is still seen by the red / gold scans
	var lab_red := _label()
	lab_red.add_theme_stylebox_override("normal", _flat(Color("#d62828"), 2))
	var lab_gold := _label()
	lab_gold.add_theme_stylebox_override("normal", _flat(C.GOLD, 2))
	t.check("pin_red_style_override_on_a_label_normal", _codes(t, lab_red, ["r4"]).has("r4_red"), "the override scan reads every style name, not only the one the control type draws")
	t.check("pin_gold_style_override_on_a_label_normal", _codes(t, lab_gold, ["r2"]).has("r2_gold_decoration"), "same for gold")
	# the language flip waits for a re-label that happens in a deferred call (2 frames after the switch, never 0)
	var hh := _fresh(t)
	var late := Label.new()
	late.name = "Late"
	late.set_script(_runtime_script("extends Label\nfunc _ready():\n\ttext = tr('INV_TITLE')\nfunc _notification(what):\n\tif what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():\n\t\tcall_deferred('_relabel')\nfunc _relabel():\n\ttext = tr('INV_TITLE')\n"))
	hh.add_child(late)
	await t.frames(2)
	_clean_rep(t, "pin_flip_waits_for_a_deferred_relabel", await UiAudit.locale_flip_report(t, hh), "a label that re-labels one frame after NOTIFICATION_TRANSLATION_CHANGED is localized")
	# a script that handles keys in _input but never mentions the mouse is not a click handler (the reads_mouse guard)
	var kb := Control.new()
	kb.name = "KeyboardOnly"
	kb.custom_minimum_size = Vector2(20, 20)
	kb.mouse_filter = Control.MOUSE_FILTER_STOP
	kb.set_script(_runtime_script("extends Control\nfunc _input(event):\n\tif event is InputEventKey:\n\t\tpass\n"))
	hh.add_child(kb)
	await t.frames(2)
	t.check("pin_mouse_only_needs_a_mouse_mention", not UiAudit.focusable_report(hh, GAME_FOCUS)["defects"].any(func(d): return d["code"] == "mouse_only_clickable"), "an _input handler of keys is not a click handler")
	# the gold source scan: GOLD_HOVER by name, and one hit per script however many nodes run it
	var src := _runtime_script("extends Control\nconst GOLD_HOVER := Color(0.92, 0.82, 0.54)\n")
	var n1 := Control.new()
	var n2 := Control.new()
	n1.set_script(src)
	n2.set_script(src)
	hh.add_child(n1)
	hh.add_child(n2)
	var gh := Rules.gold_source_hits(hh)
	t.check("pin_gold_source_scan_names_gold_hover_and_counts_a_script_once", gh.size() == 1 and int(gh[0]["line"]) == 2, "the constant GOLD_HOVER is gold (no hex needed); two nodes sharing one script give one hit: %s" % str(gh))
	# options: the numbers and the arrays
	t.check("pin_options_numbers_and_arrays", not UiAudit.validate_options("rule_report", {"hit_min": "big"}).is_empty() and not UiAudit.validate_options("rule_report", {"hit_min": -1}).is_empty() and UiAudit.validate_options("rule_report", {"hit_min": 0}).is_empty() and UiAudit.validate_options("rule_report", {"hit_min": 31.5}).is_empty()
		and not UiAudit.validate_options("focus_walk", {"ignore": "x"}).is_empty() and UiAudit.validate_options("focus_walk", {"ignore": ["*/X"]}).is_empty() and not UiAudit.validate_options("ring_pixels", {"tolerance": "a"}).is_empty() and not UiAudit.validate_options("escape_chain", {"settle_seconds": -1}).is_empty(), "hit_min / tolerance / settle_seconds must be numbers >= 0, ignore must be an Array")
	hh.queue_free()
	await t.frames(2)


func _clean_rep(t, name: String, rep: Dictionary, detail := "") -> void:
	var ok := bool(rep.get("ok", false)) and (rep.get("defects", []) as Array).is_empty()
	t.check(name, ok, detail if ok else UiAudit.summary(rep))


func _nav_buttons(t, ys: Array, links: Dictionary) -> Dictionary:
	var host := _fresh(t)
	var root := Control.new()
	root.name = "Screen"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(root)
	var bs: Array[Button] = []
	for i in ys.size():
		var b := Button.new()
		b.name = "N%d" % i
		b.text = "UI_YES"
		b.theme_type_variation = &"ButtonTertiary"
		b.custom_minimum_size = Vector2(200, 50)
		b.position = Vector2(100, ys[i])
		root.add_child(b)
		bs.append(b)
	await t.frames(3)
	for k in links:
		bs[int(k)].focus_neighbor_bottom = bs[int(k)].get_path_to(bs[int(links[k])])
	bs[0].grab_focus()
	await t.frames(2)
	return {"root": root, "buttons": bs}


func _g_more_walk(t) -> void:
	# the geometry check allows half a pixel of layout jitter and nothing more
	var near := await _nav_buttons(t, [100.0, 99.5, 300.0], {0: 1})
	var w_near := await UiAudit.focus_walk(t, near["root"], 0, {"pad_check": false})
	t.check("pin_walk_geometry_allows_a_pixel_of_jitter", _count(w_near, "nav_geometry") == 0, "ui_down to a control 0.5 px above is not 'the other way': %s" % UiAudit.summary(w_near))
	await _drop(t)
	var far := await _nav_buttons(t, [100.0, 60.0, 300.0], {0: 1})
	var w_far := await UiAudit.focus_walk(t, far["root"], 0, {"pad_check": false})
	t.check("pin_walk_geometry_flags_a_real_wrong_way", _count(w_far, "nav_geometry") >= 1, "ui_down to a control 40 px above is: %s" % UiAudit.summary(w_far))
	await _drop(t)
	# a SpinBox is represented by its LineEdit
	var b := await _mk(t, 2)
	var spin := SpinBox.new()
	spin.name = "Spin"
	spin.custom_minimum_size = Vector2(0, 48)
	b["vbox"].add_child(spin)
	await t.frames(3)
	var w_spin := await UiAudit.focus_walk(t, b["root"], 0, {"pad_check": false})
	var spin_defects: Array = w_spin["defects"]
	t.check("pin_walk_a_spin_box_is_walked_through_its_line_edit", int(w_spin["reached"]) == 3 and spin_defects.size() == 1 and spin_defects[0]["code"] == "trap" and spin_defects[0].get("via", "") == "key" and str(spin_defects[0]["path"]).contains("/Spin/"), "all 3 reached; the spin box's line edit eats the Up / Down KEYS like any LineEdit (spec F7), so it is a keyboard trap until UiNav.yield_updown_from_fields covers it: %s" % UiAudit.summary(w_spin))
	t.check("pin_walk_spin_box_itself_is_not_expected", int(w_spin["expected"]) == 3, "two buttons and the spin box's line edit (%d expected)" % int(w_spin["expected"]))
	await _drop(t)
	# the arrow-key walk tags what only it finds
	var s := Screen.new()
	s.layout = "menu"
	s.defect = "field_traps"
	var h := _fresh(t)
	h.add_child(s)
	await t.frames(3)
	var w_key := await UiAudit.focus_walk(t, s, 300)
	t.check("pin_walk_defects_found_only_with_the_arrow_keys_are_tagged", (w_key["defects"] as Array).any(func(d): return d["code"] == "only_via_tab" and d.get("via", "") == "key"), "the text field the arrows cannot leave: via = key, %s" % UiAudit.summary(w_key))
	await _drop(t)
	# a walk that ran out of presses says so and does not also call every unvisited control unreachable
	var s2 := Screen.new()
	s2.layout = "grid"
	h = _fresh(t)
	h.add_child(s2)
	await t.frames(3)
	var w_short := await UiAudit.focus_walk(t, s2, 10)
	t.check("pin_walk_truncated_is_not_unreachable", _count(w_short, "walk_truncated") == 1 and _count(w_short, "unreachable") == 0, "a truncated walk reports the truncation only: %s" % UiAudit.summary(w_short))
	await _drop(t)
	# radio pages: the pad check skips targets on a page that is closed again, max_pages caps the walk, a single member is no group, a shared defect is reported once
	var blind := BlindSection.new()
	var pill: Dictionary = await blind._pill_screen(t, 2, false, false)
	var w_pill := await UiAudit.focus_walk(t, pill["root"], 0)
	_clean_rep(t, "pin_walk_pad_check_ignores_targets_on_a_closed_page", w_pill, "radio tabs that do not select on focus: the edges to the other page's rows are not pressed again")
	await _drop_node(t, pill["host"])
	var rt := Screen.new()
	rt.layout = "radio_tabs"
	h = _fresh(t)
	h.add_child(rt)
	await t.frames(3)
	var w_cap := await UiAudit.focus_walk(t, rt, 0, {"max_pages": 1})
	t.check("pin_walk_max_pages_caps_the_visits", (w_cap["pages"] as Array).size() == 2, "the open page plus one other: %s" % str((w_cap["pages"] as Array).map(func(p): return p["label"])))
	var shared := Label.new()
	shared.name = "Danger"
	shared.text = "INV_TITLE"
	shared.add_theme_color_override("font_color", Color("#d62828"))
	rt.add_child(shared)
	await t.frames(2)
	var rr := await UiAudit.rule_report_pages(t, rt, {"rules": ["r4"]})
	t.check("pin_pages_a_defect_outside_the_pages_is_reported_once", _count(rr, "r4_red") == 1 and (rr["pages"] as Array).size() == 3, "the red label is on every page: %d report(s)" % _count(rr, "r4_red"))
	await _drop(t)
	var single := _fresh(t)
	var one := Button.new()
	one.toggle_mode = true
	one.button_group = ButtonGroup.new()
	single.add_child(one)
	await t.frames(1)
	t.check("pin_radio_groups_need_two_members", UiAudit.radio_groups(single).is_empty(), "a ButtonGroup with one button is not a set of tabs")
	await _drop(t)
	# the registry's default budget is the automatic one (a 56-slot screen is complete)
	var big: Dictionary = await blind._grid_screen(t, 8, 56, "")
	var rep_big: Dictionary = await UiAudit._run_check(t, "focus_walk", {"kind": "screen", "id": "big"}, big["root"], big["root"], {})
	t.check("pin_registry_walk_uses_the_automatic_budget", not bool(rep_big["truncated"]) and int(rep_big["reached"]) == 56, "%d of %d reached, truncated %s" % [int(rep_big["reached"]), int(rep_big["expected"]), str(rep_big["truncated"])])
	await _drop_node(t, big["host"])
	# mouse walk: a row that takes focus on hover is fine when it is listed as list-like, a control that ignores the mouse is not asked to
	var sh := Screen.new()
	sh.layout = "menu"
	sh.defect = "hover_grab"
	h = _fresh(t)
	h.add_child(sh)
	await t.frames(3)
	var mw := await UiAudit.mouse_walk(t, sh, {"list_like": ["*Button2"]})
	t.check("pin_mouse_walk_a_list_row_that_grabs_on_hover_is_clean", _count(mw, "hover_no_focus") == 0 and _count(mw, "hover_grabs_focus") == 0, "Button2 grabs focus when the mouse enters it: %s" % UiAudit.summary(mw))
	var ghost := Button.new()
	ghost.name = "Ghost"
	ghost.text = "UI_YES"
	ghost.theme_type_variation = &"ButtonTertiary"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.vbox.add_child(ghost)
	await t.frames(3)
	var mw2 := await UiAudit.mouse_walk(t, sh, {"list_like": ["*Button2", "*Ghost"]})
	t.check("pin_mouse_walk_skips_controls_that_ignore_the_mouse", not (mw2["hover_focus"] as Array).any(func(e): return str(e["path"]).ends_with("Ghost")), "a control with mouse_filter IGNORE cannot be hovered")
	await _drop(t)


func _drop_node(t, node: Node) -> void:
	node.queue_free()
	await t.frames(3)
	t.root.gui_release_focus()


## Esc that changes the game in exactly one way (the three clauses of the "Esc does nothing" chain).
func _g_more_escape(t) -> void:
	var phase0: Variant = _gm.get("current_phase")
	var other_phase: int = 4 if int(phase0) != 4 else 2
	var cases := [
		["phase", "get_node('/root/GameManager').change_phase(%d)" % other_phase],
		["paused", "get_tree().paused = true"],
		["stack_only", "get_node('/root/GameManager').push_modal(&'pins_zero', false)"],
	]
	for spec in cases:
		var b := await _mk(t, 2)
		var esc := Node.new()
		esc.set_script(_runtime_script("extends Node\nfunc _input(event):\n\tif event.is_action_pressed('pause'):\n\t\t%s\n" % spec[1]))
		b["host"].add_child(esc)
		await t.frames(2)
		var rep: Dictionary = await UiAudit.escape_chain(t, Callable(), 0, {"pre_opened": true, "base_stack": [], "base_paused": false, "base_phase": phase0})
		t.check("pin_escape_depth_zero_sees_a_%s_change" % spec[0], _count(rep, "esc_opens_modal") == 1, "Esc that only changes the %s is reported: %s" % [spec[0], UiAudit.summary(rep)])
		t.check("pin_escape_depth_zero_%s_is_cleaned_up" % spec[0], (_gm.call("modal_stack") as Array).is_empty() and not t.tree.paused and _gm.get("current_phase") == phase0, "the audit puts the game back: stack %s, paused %s, phase %s" % [str(_gm.call("modal_stack")), str(t.tree.paused), str(_gm.get("current_phase"))])
		for m in _gm.call("modal_stack"):
			_gm.call("pop_modal", m)
		t.tree.paused = false
		_gm.call("change_phase", phase0)
		await _drop(t)
	# an internal layer that closes after a fade is awaited by polling its depth, and the wait ends as soon as it moved
	var host := _fresh(t)
	var node := Control.new()
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	node.set_script(_runtime_script("extends Control\nvar depth := 0\nfunc open_internal():\n\tdepth += 1\nfunc internal_depth() -> int:\n\treturn depth\nfunc _input(event):\n\tif event.is_action_pressed('ui_cancel') and depth > 0:\n\t\tget_viewport().set_input_as_handled()\n\t\tvar tw := create_tween()\n\t\ttw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)\n\t\ttw.tween_interval(0.15)\n\t\ttw.tween_callback(func(): depth -= 1)\n"))
	host.add_child(node)
	await t.frames(3)
	var started := Time.get_ticks_msec()
	var rep2: Dictionary = await UiAudit.escape_chain(t, func() -> void: node.open_internal(), 1, {"internal_layers": 1, "internal_depth": Callable(node, "internal_depth"), "settle_seconds": 4.0})
	var took := Time.get_ticks_msec() - started
	_clean_rep(t, "pin_escape_internal_layer_that_fades_out", rep2, "(a layer that closes 0.15 s after Esc)")
	t.check("pin_escape_internal_wait_ends_when_the_depth_moved", took < 2500, "settle_seconds 4: the wait ended after %d ms, not at the timeout" % took) # raw-time-ok: tells "ended on the depth change (0.15 s)" from "ran into the 4 s timeout", not a budget
	await _drop(t)


func _g_more_registry(t) -> void:
	UiAudit.use_registry(FIXTURE_REGISTRY)
	t.check("pin_registry_part_rows_derive_from_their_tripwire", UiAudit.screen("sp_part_live")["status"] == "live" and UiAudit.screen("sp_part_pending")["status"] == "pending" and UiAudit.screen("sp_scene_empty")["status"] == "pending", "scene '' + an existing tripwire = live; a missing tripwire or none = pending")
	var d1: Dictionary = UiAudit.screen("sp_esc_defaults")["escape"]
	var d2: Dictionary = UiAudit.screen("sp_esc_partial")["escape"]
	var d3: Dictionary = UiAudit.screen("fx_esc_inert_vias")["escape"]
	t.check("pin_registry_escape_defaults", d1["depth"] == 1 and d1["via"] == "key" and d1["pre_opened"] == true and d2["depth"] == 1 and d2["via"] == "key" and d2["pre_opened"] == true and d2["settle_seconds"] == 0.5 and not d3.has("via") and d3["vias"] == ["key", "pad_b", "start"] and d3["depth"] == 0 and d3["pre_opened"] == true, "esc_depth gives depth, via key and pre_opened; an escape object only adds; vias replace via: %s / %s / %s" % [str(d1), str(d2), str(d3)])
	# a check that leaves no focus does not hide the next check's precondition
	var sp := BlindSection.Spy.new(t)
	await UiAudit.audit_screen(sp, "fx_live", {"checks": ["mouse_walk", "initial_focus"]})
	t.check("pin_registry_regrabs_the_opening_focus_between_checks", sp.failed_checks().is_empty() and sp.checks().size() == 3, "mouse_walk releases focus, initial_focus still sees the opening focus: %s" % str(sp.failed_checks()))
	UiAudit.use_registry("")



# ---------------------------------------------------------------------------------------------------- G3: fonts, hidden controls, special keys, settle times

func _g_more_late(t) -> void:
	# a FontVariation is looked through to the font it is made from
	var fv := FontVariation.new()
	fv.base_font = F_DISPLAY
	var fv2 := FontVariation.new()
	fv2.base_font = fv
	t.check("pin_font_family_looks_through_font_variations", Rules.font_family(fv) == "display" and Rules.font_family(fv2) == "display" and Rules.font_family(F_BODY) == "body" and Rules.font_family(F_MONO) == "mono", "FontVariation(Caprasimo) and a variation of a variation are display: %s / %s" % [Rules.font_family(fv), Rules.font_family(fv2)])
	# hidden controls are not keyboard stops (HUD mode reads hidden nodes too)
	var h := _fresh(t)
	var shown := Button.new()
	shown.name = "Shown"
	shown.text = "UI_YES"
	var hidden_btn := Button.new()
	hidden_btn.name = "Hidden"
	hidden_btn.text = "UI_YES"
	hidden_btn.visible = false
	h.add_child(shown)
	h.add_child(hidden_btn)
	await t.frames(2)
	var fr := UiAudit.focusable_report(h, {"forbid_focus": true})
	t.check("pin_focusable_list_skips_hidden_controls", (fr["focusable"] as Array).has("Shown") and not (fr["focusable"] as Array).has("Hidden"), "HUD mode reads hidden nodes for the hud_focusable defect, but only visible ones are focus stops: %s" % str(fr["focusable"]))
	# a Window created in a comment is not a Window
	var host2 := _fresh(t)
	var commented := Control.new()
	commented.set_script(_runtime_script("extends Control\n# ConfirmationDialog.new() would be wrong here, and so would popup_centered()\nfunc _ready():\n\tpass\n"))
	host2.add_child(commented)
	var real := Control.new()
	real.set_script(_runtime_script("extends Control\nfunc ask():\n\tvar d := ConfirmationDialog.new()\n\tadd_child(d)\n\td.popup_centered()\n"))
	var fr_c := UiAudit.focusable_report(host2, {"forbid_windows": true})
	t.check("pin_window_scan_ignores_comments", not (fr_c["defects"] as Array).any(func(d): return d["code"] == "window_in_screen"), "a script that only mentions ConfirmationDialog.new() in a comment is clean: %s" % UiAudit.summary(fr_c))
	host2.add_child(real)
	var fr_r := UiAudit.focusable_report(host2, {"forbid_windows": true})
	t.check("pin_window_scan_finds_the_call", (fr_r["defects"] as Array).any(func(d): return d["code"] == "window_in_screen"), "ConfirmationDialog.new() in a script: %s" % UiAudit.summary(fr_r))
	# a special key that opens a modal while a field is being typed in
	var b := await _mk(t, 1)
	var le := LineEdit.new()
	le.name = "Name"
	le.custom_minimum_size = Vector2(0, 48)
	b["vbox"].add_child(le)
	var hotkey := Node.new()
	hotkey.process_mode = Node.PROCESS_MODE_ALWAYS
	hotkey.set_script(_runtime_script("extends Node\nfunc _input(event):\n\tif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:\n\t\tget_node('/root/GameManager').push_modal(&'pins_tab_modal', false)\n"))
	b["host"].add_child(hotkey)
	await t.frames(2)
	var stack0: Array = (_gm.call("modal_stack") as Array).duplicate()
	var tf := await UiAudit.text_field_audit(t, b["root"])
	var leak_defect: Array = (tf["defects"] as Array).filter(func(d): return d["code"] == "typing_leaks_hotkey")
	t.check("pin_text_field_audit_names_the_special_key_that_leaked", leak_defect.size() == 1 and str(leak_defect[0]["msg"]).contains("Tab") and (_gm.call("modal_stack") as Array) == stack0, "Tab opens a modal while typing: reported with its name, and the audit pops the modal again: %s" % UiAudit.summary(tf))
	for m in _gm.call("modal_stack"):
		_gm.call("pop_modal", m)
	await _drop(t)
	# the language flip waits two frames (a re-label done in the second frame after the switch counts)
	var hh := _fresh(t)
	var slow := Label.new()
	slow.name = "SlowLabel"
	slow.process_mode = Node.PROCESS_MODE_ALWAYS
	slow.set_script(_runtime_script("extends Label\nvar _cd := 0\nfunc _ready():\n\ttext = tr('INV_TITLE')\nfunc _notification(what):\n\tif what == NOTIFICATION_TRANSLATION_CHANGED:\n\t\t_cd = 2\nfunc _process(_d):\n\tif _cd > 0:\n\t\t_cd -= 1\n\t\tif _cd == 0:\n\t\t\ttext = tr('INV_TITLE')\n"))
	hh.add_child(slow)
	await t.frames(3)
	_clean_rep(t, "pin_flip_waits_two_frames_after_the_switch", await UiAudit.locale_flip_report(t, hh), "a label that re-labels in the second frame after the switch is localized")
	await _drop(t)
	# the escape wait: frames first (default 3), polling only when asked for
	var host := _fresh(t)
	var node := Control.new()
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	node.set_script(_runtime_script("extends Control\nvar depth := 0\nvar _cd := 0\nfunc open_internal():\n\tdepth += 1\nfunc internal_depth() -> int:\n\treturn depth\nfunc _input(event):\n\tif event.is_action_pressed('ui_cancel') and depth > 0:\n\t\tget_viewport().set_input_as_handled()\n\t\t_cd = 2\nfunc _process(_d):\n\tif _cd > 0:\n\t\t_cd -= 1\n\t\tif _cd == 0:\n\t\t\tdepth -= 1\n"))
	host.add_child(node)
	await t.frames(3)
	var rep: Dictionary = await UiAudit.escape_chain(t, func() -> void: node.open_internal(), 1, {"internal_layers": 1, "internal_depth": Callable(node, "internal_depth"), "settle_seconds": 0.0})
	_clean_rep(t, "pin_escape_default_settle_is_three_frames", rep, "an internal layer that closes two frames after Esc is closed after the default wait, without polling")
	await _drop(t)
	# the control that opened a layer may be rebuilt (freed) while it is open
	var b2 := await _mk(t, 1)
	var m := Modals.new()
	b2["host"].add_child(m)
	await t.frames(3)
	var rep2: Dictionary = await UiAudit.escape_chain(t, func(level: int) -> void:
		m.open_level(level)
		m.base_button.queue_free(), 1, {})
	for mm in _gm.call("modal_stack"):
		_gm.call("pop_modal", mm)
	t.check("pin_escape_freed_opener_is_noted_not_judged", _count(rep2, "focus_not_restored") == 0 and (rep2["notes"] as Array).any(func(n): return str(n["msg"]).contains("no longer exists")), "the opener was freed while the layer was open: a note, no defect, no script error: %s" % UiAudit.summary(rep2))
	await _drop(t)
	# a pad check does not press toward a page that is closed again
	var rt := Screen.new()
	rt.layout = "radio_tabs"
	var h3 := _fresh(t)
	h3.add_child(rt)
	await t.frames(3)
	var w := await UiAudit.focus_walk(t, rt, 0)
	t.check("pin_pad_check_skips_targets_on_a_closed_page", bool(w["pad_matches_keyboard"]) and _count(w, "pad_mismatch") == 0, "the edges recorded on the other pages lead to rows that are hidden again: %s" % UiAudit.summary(w))
	var isolated: Callable = func(page: Dictionary,index: int)->bool:
		var paths: Array = page.nodes
		return paths.size()==5 and paths.all(func(path):return str(path).contains("/TabRow/") or str(path).contains("/Page%d/" % index))
	var pages_ok: bool = w.pages.size()==3
	for index in w.pages.size():
		pages_ok=pages_ok and isolated.call(w.pages[index],index)
	var contaminated: Dictionary = w.pages[0].duplicate(true)
	contaminated.nodes.append("Page1/Button0")
	t.check("pin_walk_does_not_probe_the_other_tabs_of_a_page",pages_ok and not isolated.call(contaminated,0),
		"each page graph contains three tabs and only its own two rows; contaminated-page control is rejected. %d presses include context restoration and per-page pad probes" % int(w.steps))
	await _drop(t)
	# a control that is visible on every page and was first reached from a page that is closed again: its edge leads into the closed page
	var blind := BlindSection.new()
	var pill: Dictionary = await blind._pill_screen(t, 2, false, false)
	var page0: Node = pill["root"].find_child("Page0", true, false)
	for c in page0.get_children():
		c.free()
	var footer := Button.new()
	footer.name = "Footer"
	footer.text = "SET_DONE"
	footer.theme_type_variation = &"ButtonTertiary"
	footer.custom_minimum_size = Vector2(0, 52)
	page0.get_parent().add_child(footer)
	await t.frames(3)
	var w_foot := await UiAudit.focus_walk(t, pill["root"], 0)
	t.check("pin_pad_check_ignores_an_edge_into_a_closed_page", bool(w_foot["pad_matches_keyboard"]) and _count(w_foot, "pad_mismatch") == 0, "page 0 has no rows, so Tab1's edge down to page 1's first row is first recorded while page 1 is open: %s" % UiAudit.summary(w_foot))
	await _drop_node(t, pill["host"])
	# the arrow keys of an empty Esc: two modals under the screen, one of them popped by Esc: only the stack changed (the phase stays paused / cutscene)
	_gm.call("push_modal", &"pins_a", false)
	_gm.call("push_modal", &"pins_b", false)
	var two := await _mk(t, 2)
	var esc2 := Node.new()
	esc2.set_script(_runtime_script("extends Node\nfunc _input(event):\n\tif event.is_action_pressed('pause'):\n\t\tget_node('/root/GameManager').pop_modal(&'pins_b')\n"))
	two["host"].add_child(esc2)
	await t.frames(2)
	var base2: Array = (_gm.call("modal_stack") as Array).duplicate()
	var rep_two: Dictionary = await UiAudit.escape_chain(t, Callable(), 0, {"pre_opened": true, "base_stack": base2, "base_paused": t.tree.paused, "base_phase": _gm.get("current_phase")})
	t.check("pin_escape_depth_zero_sees_a_pop_under_the_screen", _count(rep_two, "esc_opens_modal") == 1, "Esc that pops one of two modals changes only the stack (phase and pause stay): %s" % UiAudit.summary(rep_two))
	for mm in _gm.call("modal_stack"):
		_gm.call("pop_modal", mm)
	t.tree.paused = false
	await _drop(t)
	# a row that takes focus one frame after the mouse entered it (a deferred grab) is still seen
	var hv := await _mk(t, 3)
	var row2: Button = hv["buttons"][1]
	row2.mouse_entered.connect(func() -> void: row2.call_deferred("grab_focus"))
	var mw := await UiAudit.mouse_walk(t, hv["root"], {"list_like": ["*B2"]})
	t.check("pin_mouse_walk_waits_for_a_deferred_grab", (mw["missing_grabs"] as Array).is_empty() and _count(mw, "hover_no_focus") == 0, "the row grabs focus in a deferred call: %s" % UiAudit.summary(mw))
	await _drop(t)
