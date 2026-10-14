extends RefCounted
## The static rule scans behind UiAudit.rule_report (see tests/lib/ui_audit.gd and the header of tests/sections/ui_audit.gd).
## Nothing here awaits or touches the input system: every function reads a node tree (or the project theme) and returns data.
##
## The five guide rules and what "conforming" means here (each one has a planted-defect fixture in tests/fixtures/ui_audit):
##   R1 ink outline    every opaque, light box that is drawn (panel, field, button, slot) has a 2 px ink (#2b2340) border; dashed
##                     "disabled" boxes use the guide's #a3957f. Dark plates (ink / night fill) and translucent overlays are not
##                     "parchment surfaces": no outline is required on them (guide: name plates, pills, scrims), nor on a segment of an outlined
##                     panel that carries the line on some sides only (shop footer, journal sidebar).
##   R2 gold           gold (#e3c372, hover #ecd189) that does NOT come from the project theme (a per-node style / colour override, a
##                     ColorRect, a modulate, a tint of a TextureProgressBar, a StyleBoxLine separator, a [color] tag) is only allowed in a focus / pressed /
##                     selected state; an override that is one of the theme's own StyleBox resources (an AcceptDialog panel) is the theme. What a Theme
##                     RESOURCE assigned to a control provides (a gold panel, gold idle text) is judged too, unless the variation is a guide ornament. The
##                     project theme itself is the guide's own source of gold (panel double edge, gold button, menu row) and is not scanned per node.
##                     Gold that a SCRIPT paints (`draw_rect(..., GOLD)` in `_draw`) is invisible to every node property: the source of the scripts the screen runs
##                     is scanned for the constant GOLD / GOLD_HOVER and the hex values (gold_source_hits; allow-list GOLD_DRAW_OK_SCRIPTS, meta tt_gold_ok).
##   R3 numbers        a label that is nothing but a number, a count, money or a time (1.250, 10:40, 12, x3, 3 / 5, 150 guldagern)
##                     is set in Caprasimo (display). The mono face is exempt (the guide sets "1 / 2" and hex codes in mono).
##   R4 no red         no colour in use is a danger red: hue within 15 degrees of red (350..15), saturation >= 0.5, value >= 0.4.
##                     Thorn-berry (#b3436b, hue 339) is the guide's damage colour and passes.
##   hit targets       interactive controls are at least 32 x 32 px (spec 10.6, options.hit_min: the guide's tab pill is 33 px high, its species chip about 37 px, so a
##                     44 px rule would contradict the guide). Two guide plates are smaller by design and keep a 20 px floor (HIT_EXEMPT_VARIATIONS): the translucent
##                     HintButton (a text hint) and VersionButton (the version / language tag). The BUILT PillTab is 29 px high, 4 px short of the guide (spec Appendix E:
##                     P28 adds 2 px of vertical margin on each side); until then a registry row for a screen that carries one lowers options.hit_min for itself.
##   typography        Caprasimo >= 20 px, Alegreya Sans >= 18 px. Exempt: slot counts (Display15/16...), the mono face, and (unless
##                     options.strict_typography) a named theme type variation, because the guide itself sets secondary text at 13-17 px
##                     (Muted*, Heavy14 ...) and the theme carries two Caprasimo tokens under 20 px (Display19 = the tracked quest title, ButtonTertiaryS
##                     = 18 px). A per-node font size override below the minimum is never exempt. Floor: 11 px.
## Escape hatches (documented, visible in the report notes): node meta `tt_audit_ignore` (the node and its subtree are skipped),
## `tt_gold_ok`, `tt_r1_ok`, `tt_hit_ok`, `tt_text_same_ok` (value = the reason), and options.ignore (glob patterns of node paths
## relative to the audited root).

const C = preload("res://scripts/ui/theme/tt_colors.gd")
const BoxStyleScript = preload("res://scripts/ui/theme/tt_box_style.gd")

const RAW_KEY_PATTERN := "^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$"
const GOLD_TOL := 6.0                  # 0..255 per channel
const INK_TOL := 10.0
const RED_HUE_MAX := 15.0
const RED_HUE_MIN := 350.0
const RED_SAT_MIN := 0.45
const RED_VAL_MIN := 0.45
const DISPLAY_MIN := 20
const BODY_MIN := 18
const TYPO_FLOOR := 11
const HIT_MIN := 32.0                  # every interactive control (spec 10.6: 32 x 32 design px)
const HIT_FLOOR := 20.0                # the two guide tag plates of HIT_EXEMPT_VARIATIONS
## Caprasimo counts inside slots / hotbar (guide: slot counts 15-16 px)
const DISPLAY_COUNT_VARIATIONS: Array[String] = ["Display15", "Display16", "Display15Night", "Display16Night"]
## key caps are labels of keys ("1" .. "0", "E"), not values: the guide sets the hotbar digit in Alegreya (HotkeyDigit)
const R3_EXEMPT_VARIATIONS: Array[String] = ["HotkeyDigit", "KeyCap"]
## the guide's two tag plates that are smaller than 32 px by design (the dialogue hint ~20 px, the version tag ~24 px); every other control meets HIT_MIN
const HIT_EXEMPT_VARIATIONS: Array[String] = ["HintButton", "VersionButton"]
## Scripts that draw gold themselves on purpose: the draw-only components paint the guide's selected / next-step ring from their `selected` / `state` (never as decoration).
## Any other script of a screen that names the gold constant or hex is reported by the source scan (R2) unless one of its nodes carries the meta tt_gold_ok (the reason).
const GOLD_DRAW_OK_SCRIPTS: Array[String] = ["res://scripts/ui/components/ladder_row.gd", "res://scripts/ui/components/rarity_slot.gd"]
## variations the guide itself draws without an ink outline on a light box (the rest is exempt by rule: transparent / dark / translucent / partial borders)
const R1_EXEMPT_VARIATIONS: Array[String] = ["Coin", "NamePlate", "VersionTag", "VersionButton", "HintButton", "StepperButton", "PanelScrim", "PanelSidebar", "PanelHeader",
	"PanelFooter", "KeyCap", "FocusProxy", "MenuRow", "ChoiceRow", "RowButton", "RecipeRow"]
## Gold that is NOT focus / selected but is in the guide's own mocks (spec 2.2 "ornament whitelist"): the panel edge, the ability / toast ring, name plates, the
## boss meter ring, key caps, money pills, the gold zone chip / tagline / coin and the gold button, the "guldagern" unit text.
const GOLD_ORNAMENT: Array[String] = ["PanelParchment", "PanelParchmentL", "PanelParchmentL24", "PanelBook", "PanelMenu", "PanelHud", "PanelHearts", "PanelHotbar",
	"PanelRound", "AcceptDialog", "PopupMenu", "PanelAbility", "PanelAbilityBig", "PanelToast", "FramePortraitRound", "NamePlate", "MeterBoss", "KeyCap", "PillGold",
	"PillNight", "PromptPill", "Tagline", "ZoneChip", "Coin", "CoinInk", "ButtonSecondary", "ButtonSecondaryL", "ButtonSecondaryS", "Bold15Gold"]
const STYLE_NAMES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed", "panel", "background", "fill", "read_only", "slider", "separator",
	"grabber_area", "grabber_area_highlight", "scroll", "grabber", "tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus",
	"tabbar_background", "selected", "selected_focus", "hovered", "cursor", "cursor_unfocused", "title_button_normal"]
const FONT_COLOR_NAMES: Array[String] = ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color",
	"font_disabled_color", "font_outline_color", "font_shadow_color", "font_selected_color", "font_hovered_color", "default_color", "caret_color",
	"selection_color", "icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_focus_color", "icon_disabled_color", "font_placeholder_color",
	"font_uneditable_color", "font_unselected_color"]
## script property / state names that mean "this node is the selected one"
const SELECTED_PROPS: Array[String] = ["selected", "is_selected", "current"]


# ---------------------------------------------------------------------------------------------------- colours

static func color_close(a: Color, b: Color, tol: float) -> bool:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0 <= tol


static func is_gold(c: Color) -> bool:
	return c.a >= 0.2 and (color_close(c, C.GOLD, GOLD_TOL) or color_close(c, C.GOLD_HOVER, GOLD_TOL))


static func is_ink(c: Color) -> bool:
	return color_close(c, C.INK, INK_TOL)


## Danger red (rule R4). Hue in degrees: red is 350..360 and 0..15.
static func is_red(c: Color) -> bool:
	if c.a < 0.1:
		return false
	var hue := c.h * 360.0
	return (hue >= RED_HUE_MIN or hue <= RED_HUE_MAX) and c.s >= RED_SAT_MIN and c.v >= RED_VAL_MIN


static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)


# ---------------------------------------------------------------------------------------------------- tree helpers

static func rel_path(root: Node, node: Node) -> String:
	if node == root:
		return "."
	return str(root.get_path_to(node))


## Every node under `root` (root included, internal children included) in tree order. Hidden CanvasItems are skipped together with their
## subtree (a screen's hidden pages are not on screen), and so is everything under a node with meta `tt_audit_ignore` or whose relative
## path matches one of `ignore` (glob patterns, String.match).
static func nodes(root: Node, ignore: Array = [], only_visible := true) -> Array[Node]:
	var out: Array[Node] = []
	_collect(root, root, ignore, only_visible, out)
	return out


static func _collect(root: Node, n: Node, ignore: Array, only_visible: bool, out: Array[Node]) -> void:
	if n.has_meta(&"tt_audit_ignore"):
		return
	if n != root:
		var rp := rel_path(root, n)
		for pat in ignore:
			if rp.match(str(pat)):
				return
	if only_visible and n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if only_visible and n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	if only_visible and n is Window and not (n as Window).visible:
		return
	out.append(n)
	for c in n.get_children(true):
		_collect(root, c, ignore, only_visible, out)


## Interactive (clickable / typeable / adjustable) controls: what a player expects to reach with the keyboard.
static func is_interactive(c: Control) -> bool:
	if c.has_meta(&"tt_interactive"):
		return true
	if c is BaseButton or c is LineEdit or c is TextEdit or c is ItemList or c is Tree or c is TabBar:
		return true
	if c.focus_mode == Control.FOCUS_ALL and not (c is ScrollContainer or c is ScrollBar or c is ProgressBar or c is TextureProgressBar):
		return true                                  # a custom control that asked for keyboard focus is interactive by intent
	if c is Range and not (c is ProgressBar or c is TextureProgressBar or c is ScrollBar):
		return true
	return false


## Interactive and able to react right now.
static func is_enabled(c: Control) -> bool:
	if c is BaseButton:
		return not (c as BaseButton).disabled
	if c is LineEdit:
		return (c as LineEdit).editable
	if c is TextEdit:
		return (c as TextEdit).editable
	if c is Slider:
		return (c as Slider).editable
	return true


static func class_name_of(n: Node) -> String:
	var s: Script = n.get_script()
	if s != null and s is GDScript:
		var gn := String((s as GDScript).get_global_name())
		if gn != "":
			return gn
	return n.get_class()


# ---------------------------------------------------------------------------------------------------- fonts and text

static func font_family(f: Font) -> String:
	var cur: Font = f
	for _i in 8:
		if cur == null:
			break
		if cur is FontVariation:
			cur = (cur as FontVariation).base_font
			continue
		var p := cur.resource_path.get_file().to_lower()
		var n := cur.get_font_name().to_lower()
		if p.contains("caprasimo") or n.contains("caprasimo"):
			return "display"
		if p.contains("alegreya") or n.contains("alegreya"):
			return "body"
		if p.contains("plexmono") or n.contains("plex mono") or n.contains("plexmono"):
			return "mono"
		if p.contains("symbols") or n.contains("symbols"):
			return "symbol"
		break
	return "other"


## The text a node shows (translated) and its font / size. [{text, font, size, family, override, prop}] - empty when the node shows no text.
static func text_items(n: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if n is Label:
		var l := n as Label
		var font := l.get_theme_font("font")
		var size := l.get_theme_font_size("font_size")
		var ov := l.has_theme_font_size_override("font_size") or l.has_theme_font_override("font")
		if l.label_settings != null:
			var ls := l.label_settings
			font = ls.font if ls.font != null else font
			size = ls.font_size
			ov = true
		out.append({"text": l.atr(l.text), "font": font, "size": size, "override": ov, "prop": "text"})
	elif n is RichTextLabel:
		var r := n as RichTextLabel
		var font2 := r.get_theme_font("normal_font")
		var size2 := r.get_theme_font_size("normal_font_size")
		var ov2 := r.has_theme_font_size_override("normal_font_size") or r.has_theme_font_override("normal_font")
		out.append({"text": r.get_parsed_text(), "font": font2, "size": size2, "override": ov2, "prop": "text"})
	elif n is Button:
		var b := n as Button
		if b.text != "":
			out.append({"text": b.atr(b.text), "font": b.get_theme_font("font"), "size": b.get_theme_font_size("font_size"),
				"override": b.has_theme_font_size_override("font_size") or b.has_theme_font_override("font"), "prop": "text"})
	elif n is LineEdit:
		var le := n as LineEdit
		out.append({"text": le.atr(le.placeholder_text) if le.text == "" else "", "font": le.get_theme_font("font"), "size": le.get_theme_font_size("font_size"),
			"override": le.has_theme_font_size_override("font_size") or le.has_theme_font_override("font"), "prop": "placeholder_text", "field": true})
	elif n is TextEdit:
		var te := n as TextEdit
		out.append({"text": "", "font": te.get_theme_font("font"), "size": te.get_theme_font_size("font_size"),
			"override": te.has_theme_font_size_override("font_size") or te.has_theme_font_override("font"), "prop": "text", "field": true})
	elif n is TabBar:
		var tb := n as TabBar
		for i in tb.tab_count:
			out.append({"text": tb.atr(tb.get_tab_title(i)), "font": tb.get_theme_font("font"), "size": tb.get_theme_font_size("font_size"),
				"override": tb.has_theme_font_size_override("font_size"), "prop": "tab_title"})
			break
	return out


static func is_key_shaped(s: String) -> bool:
	var rx := RegEx.new()
	rx.compile(RAW_KEY_PATTERN)
	return rx.search(s) != null


static func letter_count(s: String) -> int:
	var n := 0
	for i in s.length():
		var ch := s.unicode_at(i)
		if (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch in [0xC6, 0xD8, 0xC5, 0xE6, 0xF8, 0xE5]:
			n += 1
	return n


## True for text that is only a number, money amount or a clock: "1.250", "10:40", "12", "x3", "+5" (spec 2.3: ^[+-x]?\d[\d.,:]*$). Mixed texts
## ("I alt 300", "18 / 24", "150 guldagern", "Dag 14") are exempt by construction (the guide sets several of them in Alegreya); mark a label of that kind that
## MUST be Caprasimo with the group `tt_number`.
static func is_number_text(text: String) -> bool:
	var s := text.strip_edges()
	if s == "":
		return false
	var i := 0
	if s[0] in ["+", "-", "−", "×", "x"]:
		i = 1
	if i >= s.length() or s[i] < "0" or s[i] > "9":
		return false
	for j in range(i, s.length()):
		var ch := s[j]
		if not ((ch >= "0" and ch <= "9") or ch in [".", ",", ":"]):
			return false
	return true


# ---------------------------------------------------------------------------------------------------- styleboxes

## Describes a StyleBox for the rules: {kind, fill, border_w (min over the sides), border_color, dashed, body, rings: Array[Color]} - null kinds are skipped.
static func style_info(sb: StyleBox) -> Dictionary:
	var info := {"kind": "", "fill": Color(0, 0, 0, 0), "border_w": 0.0, "border_color": Color(0, 0, 0, 0), "dashed": false, "body": true, "rings": [] as Array, "partial": false}
	if sb == null:
		return info                                           # (an empty / line / texture style has no kind below: the rules skip it)
	if sb is StyleBoxFlat:
		var f := sb as StyleBoxFlat
		info["kind"] = "flat"
		info["fill"] = f.bg_color if f.draw_center else Color(0, 0, 0, 0)
		info["border_w"] = float(mini(mini(f.border_width_left, f.border_width_top), mini(f.border_width_right, f.border_width_bottom)))
		info["partial"] = float(info["border_w"]) <= 0.0 and maxi(maxi(f.border_width_left, f.border_width_top), maxi(f.border_width_right, f.border_width_bottom)) > 0
		info["border_color"] = f.border_color
	elif sb.get_script() == BoxStyleScript:
		info["kind"] = "tt"
		info["body"] = bool(sb.get("draw_body"))
		info["fill"] = sb.get("fill")
		var bw := float(sb.get("border_width"))
		var sides: Vector4 = sb.get("border_sides")
		var m := bw
		var mx := 0.0
		for v in [sides.x, sides.y, sides.z, sides.w]:
			var w := bw if v < 0.0 else float(v)
			m = minf(m, w)
			mx = maxf(mx, w)
		info["border_w"] = m
		info["partial"] = m <= 0.0 and mx > 0.0                      # a segment of an outlined panel (footer, sidebar): only some sides carry the line
		info["border_color"] = sb.get("border_color")
		info["dashed"] = bool(sb.get("dashed"))
		var rc: PackedColorArray = sb.get("ring_colors")
		var rw: PackedFloat32Array = sb.get("ring_widths")
		var rings: Array = []
		for i in mini(rc.size(), rw.size()):
			if rw[i] > 0.0:
				rings.append(rc[i])
		info["rings"] = rings
	return info


## Every colour a style draws (fill, border, rings, TTBoxStyle shadow / band colours): the input of the gold and red scans.
static func style_colors(sb: StyleBox) -> Array[Color]:
	var out: Array[Color] = []
	if sb == null:
		return out
	if sb is StyleBoxFlat:
		var f := sb as StyleBoxFlat
		if f.draw_center:
			out.append(f.bg_color)
		if f.border_width_left + f.border_width_top + f.border_width_right + f.border_width_bottom > 0:
			out.append(f.border_color)
		if f.shadow_size > 0:
			out.append(f.shadow_color)
	elif sb is StyleBoxLine:
		out.append((sb as StyleBoxLine).color)                       # a separator rule (HSeparator / VSeparator `separator`)
	elif sb is StyleBoxTexture:
		out.append((sb as StyleBoxTexture).modulate_color)           # a tinted texture box
	elif sb.get_script() == BoxStyleScript:
		if bool(sb.get("draw_body")):
			out.append(sb.get("fill"))
			if float(sb.get("border_width")) > 0.0:
				out.append(sb.get("border_color"))
			if float(sb.get("hard_shadow")) > 0.0:
				out.append(sb.get("hard_shadow_color"))
		var rc: PackedColorArray = sb.get("ring_colors")
		var rw: PackedFloat32Array = sb.get("ring_widths")
		for i in mini(rc.size(), rw.size()):
			if rw[i] > 0.0:
				out.append(rc[i])
	return out


## "" when the box satisfies R1, else the reason.
static func r1_problem(sb: StyleBox) -> String:
	var info := style_info(sb)
	if info["kind"] == "" or not bool(info["body"]) or bool(info["partial"]):
		return ""
	var fill: Color = info["fill"]
	if fill.a < 0.95 or luma(fill) < 0.2:
		return ""                                    # translucent overlay / dark plate: not a parchment surface
	var bc: Color = info["border_color"]
	if bool(info["dashed"]):
		return "" if color_close(bc, C.TEXT_DISABLED, INK_TOL) else "dashed border %s is not the guide's disabled grey %s" % [hex(bc), hex(C.TEXT_DISABLED)]
	var w: float = info["border_w"]
	if w < 2.0:
		return "outline is %s px, the guide wants 2 px of ink" % str(snappedf(w, 0.1))
	if not is_ink(bc):
		return "outline colour %s is not ink %s" % [hex(bc), hex(C.INK)]
	return ""


## The stylebox a control draws its box with right now (panel / normal / pressed / disabled / read_only / background) and its theme name.
static func box_style_of(c: Control) -> Array:
	if c is PanelContainer or c is Panel:
		return ["panel", c.get_theme_stylebox("panel")]
	if c is BaseButton:
		var b := c as BaseButton
		if b is Button and (b as Button).flat:
			return []                                 # a flat button draws no box
		var nm := "normal"
		if b.disabled:
			nm = "disabled"
		elif b.button_pressed:
			nm = "pressed"
		return [nm, b.get_theme_stylebox(nm)]
	if c is LineEdit:
		var le := c as LineEdit
		var nm2 := "normal" if le.editable else "read_only"
		return [nm2, le.get_theme_stylebox(nm2)]
	if c is TextEdit:
		return ["normal", c.get_theme_stylebox("normal")]
	if c is ProgressBar:
		return ["background", c.get_theme_stylebox("background")]
	if c is Slider:
		return ["slider", c.get_theme_stylebox("slider")]
	if c is HSeparator or c is VSeparator:
		return ["separator", c.get_theme_stylebox("separator")]
	return []


# ---------------------------------------------------------------------------------------------------- the scan

## options: ignore (glob patterns), rules (Array of "r1","r2","r3","r4","typography","overrides","i18n","hit_targets"; default all), strict_typography,
## strict_gold (default true: spec 2.2 layer b - a Control whose CURRENT style shows gold must be focused / selected / in GOLD_ORNAMENT), gold_source (default true: the script
## source scan of R2), hit_min (default 32),
## literal_files (Array of res:// files to scan for hard-coded copy; default: the screen's own scene + scripts).
## Returns {ok, defects: [{rule, code, path, msg, variation, detail}], notes: [{rule, path, msg}], counts: {nodes, controls, labels, styleboxes, text_nodes, boxes, interactive}}.
static func scan(root: Node, options: Dictionary = {}) -> Dictionary:
	var ignore: Array = options.get("ignore", [])
	var want: Array = options.get("rules", ["r1", "r2", "r3", "r4", "typography", "overrides", "i18n", "hit_targets"])
	var all := nodes(root, ignore)
	var defects: Array[Dictionary] = []
	var notes: Array[Dictionary] = []
	var counts := {"nodes": all.size(), "controls": 0, "labels": 0, "styleboxes": 0, "text_nodes": 0, "boxes": 0, "interactive": 0}
	var seen_small: Dictionary = {}
	var theme_ids := _theme_style_ids()
	for n in all:
		var rp := rel_path(root, n)
		var ctrl: Control = n as Control
		var items: Array[Dictionary] = text_items(n)
		if ctrl != null:
			counts["controls"] = int(counts["controls"]) + 1
		if not items.is_empty():
			counts["text_nodes"] = int(counts["text_nodes"]) + 1
			counts["labels"] = int(counts["labels"]) + 1
		if "r1" in want and ctrl != null:
			var bs := box_style_of(ctrl)
			if not bs.is_empty():
				counts["boxes"] = int(counts["boxes"]) + 1
				counts["styleboxes"] = int(counts["styleboxes"]) + 1
				var exempt := ctrl.has_meta(&"tt_r1_ok") or String(ctrl.theme_type_variation) in R1_EXEMPT_VARIATIONS
				var why := r1_problem(bs[1])
				if why != "" and not exempt:
					defects.append({"rule": "r1", "code": "r1_no_ink_outline", "path": rp, "msg": "%s '%s' style: %s" % [class_name_of(n), bs[0], why]})
		if "r2" in want:
			_scan_gold(root, n, rp, defects, notes, theme_ids)
			if bool(options.get("strict_gold", true)) and ctrl != null:
				_scan_gold_current(ctrl, rp, defects, notes)
		if "overrides" in want and ctrl != null:
			_scan_overrides(ctrl, rp, defects)
		if "r4" in want:
			_scan_red(n, rp, defects)
		if ("r3" in want or "typography" in want) and not items.is_empty():
			for it in items:
				_scan_text_item(n, rp, it, want, bool(options.get("strict_typography", false)), defects, notes)
		if "i18n" in want:
			_scan_raw_keys(n, rp, defects)
		if "hit_targets" in want and ctrl != null and is_interactive(ctrl) and is_enabled(ctrl):
			counts["interactive"] = int(counts["interactive"]) + 1
			_scan_hit_target(ctrl, rp, float(options.get("hit_min", HIT_MIN)), defects, seen_small)
	if "i18n" in want:
		for f in literal_scan(root, options.get("literal_files", [])):
			defects.append({"rule": "i18n", "code": "hardcoded_literal", "path": "%s:%d" % [f["file"], f["line"]], "msg": "%s = \"%s\" is copy in the source: use a translation key from a CSV" % [f["prop"], f["text"]]})
	if "r2" in want and bool(options.get("gold_source", true)):
		for h in gold_source_hits(root, ignore):
			defects.append({"rule": "r2", "code": "r2_gold_decoration", "path": "%s:%d" % [h["file"], h["line"]], "msg": "the script paints or names gold by itself (%s): gold is for focus and selection only (guide rule 'Guld betyder valgt'); a draw-only component that shows `selected` marks the node with tt_gold_ok" % h["text"]})
	for d in defects:
		if not d.has("variation"):
			var dn: Node = root if str(d["path"]) == "." else root.get_node_or_null(NodePath(str(d["path"])))
			d["variation"] = String((dn as Control).theme_type_variation) if dn is Control else ""
		if not d.has("detail"):
			d["detail"] = d["msg"]
	counts["styleboxes"] = counts["boxes"]
	return {"ok": defects.is_empty(), "defects": defects, "notes": notes, "counts": counts}


# ---------------------------------------------------------------------------------------------------- R2 (gold)

static func _node_is_selected(n: Node) -> bool:
	if n is Control and (n as Control).has_focus():
		return true
	if n is BaseButton and (n as BaseButton).button_pressed:
		return true
	for p in SELECTED_PROPS:
		if p in n and bool(n.get(p)):
			return true
	return false


static func _gold_state_name(style_name: String) -> bool:
	return style_name.contains("focus") or style_name.contains("pressed") or style_name.contains("selected")


## Instance ids of every StyleBox of the project theme: an override that IS one of them is the guide's own style (AcceptDialog copies its theme panel
## into a per-node override), not an ad-hoc decoration.
static func _theme_style_ids() -> Dictionary:
	var ids := {}
	var th := ThemeDB.get_project_theme()
	if th == null:
		return ids
	for ty in th.get_type_list():
		for nm in th.get_stylebox_list(ty):
			ids[th.get_stylebox(nm, ty).get_instance_id()] = true
	return ids


static func _scan_gold(root: Node, n: Node, rp: String, defects: Array[Dictionary], notes: Array[Dictionary], theme_ids: Dictionary) -> void:
	if n.has_meta(&"tt_gold_ok"):
		notes.append({"rule": "r2", "path": rp, "msg": "gold allowed by tt_gold_ok: %s" % str(n.get_meta(&"tt_gold_ok"))})
		return
	var selected := _node_is_selected(n)
	var found: Array[String] = []
	if n is Control:
		var c := n as Control
		for sn in STYLE_NAMES:
			if c.has_theme_stylebox_override(sn):
				if _gold_state_name(sn) or theme_ids.has(c.get_theme_stylebox(sn).get_instance_id()):
					continue
				for col in style_colors(c.get_theme_stylebox(sn)):
					if is_gold(col):
						found.append("style override '%s' draws gold %s" % [sn, hex(col)])
						break
		for cn in FONT_COLOR_NAMES:
			if c.has_theme_color_override(cn) and not _gold_state_name(cn) and is_gold(c.get_theme_color(cn)):
				found.append("colour override '%s' is gold" % cn)
		if c is ColorRect and is_gold((c as ColorRect).color):
			found.append("ColorRect.color is gold")
	elif n is Polygon2D and is_gold((n as Polygon2D).color):
		found.append("Polygon2D.color is gold")
	elif n is Line2D and is_gold((n as Line2D).default_color):
		found.append("Line2D.default_color is gold")
	if n is CanvasItem:
		var ci := n as CanvasItem
		if is_gold(ci.modulate) and ci.modulate != Color.WHITE:
			found.append("modulate is gold")
		if is_gold(ci.self_modulate) and ci.self_modulate != Color.WHITE:
			found.append("self_modulate is gold")
	if n is Label and (n as Label).label_settings != null:
		var ls := (n as Label).label_settings
		if is_gold(ls.font_color) or (ls.outline_size > 0 and is_gold(ls.outline_color)):
			found.append("label_settings colour is gold")
	if n is RichTextLabel:
		for col in bbcode_colors((n as RichTextLabel).text):
			if is_gold(col):
				found.append("[color] tag is gold")
	if n is TextureProgressBar:
		for tn in TINT_PROPS:
			var tint: Color = n.get(tn)
			if tint != Color.WHITE and is_gold(tint):
				found.append("%s is gold" % tn)
	if found.is_empty():
		return
	if selected:
		notes.append({"rule": "r2", "path": rp, "msg": "gold on a focused / pressed / selected node: %s" % "; ".join(found)})
		return
	for f in found:
		defects.append({"rule": "r2", "code": "r2_gold_decoration", "path": rp, "msg": "%s %s: gold is for focus and selection only (guide rule 'Guld betyder valgt')" % [class_name_of(n), f]})


## Spec 2.2 layer (b): the style a Control draws RIGHT NOW shows gold (a gold fill, a gold ring, a gold rule) or its text is gold although the control is not focused,
## pressed or selected and its variation is not in GOLD_ORNAMENT. Per-node overrides are handled by _scan_gold; this covers what the THEME provides - the project theme and a
## Theme resource assigned to the control (Control.theme).
static func _scan_gold_current(c: Control, rp: String, defects: Array[Dictionary], notes: Array[Dictionary]) -> void:
	if c.has_meta(&"tt_gold_ok") or _node_is_selected(c):
		return
	var variation := String(c.theme_type_variation)
	if variation in GOLD_ORNAMENT:
		return
	var bs := box_style_of(c)
	if not bs.is_empty():
		var st: StyleBox = bs[1]
		if st != null and not c.has_theme_stylebox_override(str(bs[0])):
			for col in style_colors(st):
				if is_gold(col):
					defects.append({"rule": "r2", "code": "r2_gold_decoration", "path": rp, "msg": "%s (%s): its '%s' style is gold although the control is not focused or selected and the variation is not a guide ornament (GOLD_ORNAMENT)" % [class_name_of(c), variation if variation != "" else "default", bs[0]]})
					return
	for cn in _text_colour_names(c):
		if not c.has_theme_color_override(cn) and c.has_theme_color(cn) and is_gold(c.get_theme_color(cn)):
			defects.append({"rule": "r2", "code": "r2_gold_decoration", "path": rp, "msg": "%s (%s): its theme colour '%s' is gold although the control is not focused or selected and the variation is not a guide ornament (GOLD_ORNAMENT)" % [class_name_of(c), variation if variation != "" else "default", cn]})
			return


## The colour items that paint the text a control shows while it is idle or disabled (hover / focus / pressed colours belong to the states gold may be used in).
static func _text_colour_names(c: Control) -> Array[String]:
	if c is RichTextLabel:
		return ["default_color"]
	if c is Button:
		return ["font_color", "font_disabled_color"]
	if c is Label or c is LineEdit:
		return ["font_color"]
	return []


const TINT_PROPS: Array[String] = ["tint_under", "tint_over", "tint_progress"]
const GOLD_SOURCE_RX := "\\bGOLD(?:_HOVER)?\\b"


## The distinct scripts of the nodes under `root` (hidden nodes included) as [{path, source, node}]: a script file once, a script built at runtime (no resource path) by its source.
static func node_scripts(root: Node, ignore: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for n in nodes(root, ignore, false):
		var s: Script = n.get_script()
		if s == null or not (s is GDScript):
			continue
		var key: String = s.resource_path if s.resource_path != "" else "runtime:%d" % s.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		var src: String = (s as GDScript).source_code
		out.append({"path": s.resource_path if s.resource_path != "" else "(runtime script of %s)" % n.name, "source": src, "node": n})
	return out


## R2 source scan: gold that a script of the screen paints by itself (a `_draw` that fills gold, a Color("#e3c372")) - invisible to the node scan, which only reads properties.
## Every line that names the constant GOLD / GOLD_HOVER or the hex e3c372 / ecd189 outside a comment is a hit, unless the script is in GOLD_DRAW_OK_SCRIPTS or a node that runs it
## carries the meta tt_gold_ok (the reason). Returns [{file, line, text}].
static func gold_source_hits(root: Node, ignore: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var word := RegEx.new()
	word.compile(GOLD_SOURCE_RX)
	for sc in node_scripts(root, ignore):
		if str(sc["path"]) in GOLD_DRAW_OK_SCRIPTS or (sc["node"] as Node).has_meta(&"tt_gold_ok"):
			continue
		var lines := str(sc["source"]).split("\n")
		for i in lines.size():
			var raw: String = lines[i]
			if raw.strip_edges().begins_with("#"):
				continue
			var low := raw.to_lower()
			var code := raw.split("#")[0]
			if low.contains("e3c372") or low.contains("ecd189") or word.search(code) != null:
				out.append({"file": str(sc["path"]), "line": i + 1, "text": raw.strip_edges().left(80)})
	return out


const WINDOW_SOURCE_RX := "\\b(?:ConfirmationDialog|AcceptDialog|FileDialog|PopupMenu|PopupPanel|Popup|Window|OptionButton|MenuButton|ColorPickerButton)\\.new\\s*\\(|\\.(?:popup|popup_centered|popup_centered_ratio|popup_centered_clamped|popup_on_parent)\\s*\\("


## Window-based controls that a script of the screen creates (ConfirmationDialog.new(), OptionButton.new(), .popup_centered()): a dialog made when a button is pressed does not exist
## in the tree at open time, so the tree scan cannot see it. Returns [{file, line, text}] (comments skipped).
static func window_source_hits(root: Node, ignore: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rx := RegEx.new()
	rx.compile(WINDOW_SOURCE_RX)
	for sc in node_scripts(root, ignore):
		var lines := str(sc["source"]).split("\n")
		for i in lines.size():
			var raw: String = lines[i]
			if rx.search(raw.split("#")[0]) != null:                   # (the part before the first # : a comment line has none)
				out.append({"file": str(sc["path"]), "line": i + 1, "text": raw.strip_edges().left(80)})
	return out


## True when a script handles mouse buttons in an input callback (`_input`, `_unhandled_input`, `_shortcut_input`): it names InputEventMouseButton AND defines one of them
## (a script that only READS the mouse bindings of an action, like the ability slot's key text, does not).
static func reads_mouse_in_input(script: GDScript) -> bool:
	var src := script.source_code
	if not src.contains("InputEventMouseButton"):
		return false
	var rx := RegEx.new()
	rx.compile("(?m)^func\\s+_(?:input|unhandled_input|shortcut_input)\\s*\\(")
	return rx.search(src) != null


const FONT_OVERRIDE_NAMES: Array[String] = ["font", "normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font", "title_font"]
const FONT_SIZE_OVERRIDE_NAMES: Array[String] = ["font_size", "normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size", "title_font_size"]


## Plan 5.1 / spec 2.5: a screen uses theme type variations only - no per-node font, font size or font colour override (node meta tt_override_ok = the reason).
static func _scan_overrides(c: Control, rp: String, defects: Array[Dictionary]) -> void:
	if c.has_meta(&"tt_override_ok"):
		return
	var found: Array[String] = []
	for nm in FONT_OVERRIDE_NAMES:
		if c.has_theme_font_override(nm):
			found.append("font '%s'" % nm)
	for nm in FONT_SIZE_OVERRIDE_NAMES:
		if c.has_theme_font_size_override(nm):
			found.append("font size '%s' = %d" % [nm, c.get_theme_font_size(nm)])
	for nm in FONT_COLOR_NAMES:
		if nm.begins_with("font_") and c.has_theme_color_override(nm):
			found.append("colour '%s'" % nm)
	if not found.is_empty():
		defects.append({"rule": "overrides", "code": "theme_override", "path": rp, "msg": "%s has per-node overrides (%s): use a theme type variation (plan 5.1)" % [class_name_of(c), ", ".join(found)]})


# ---------------------------------------------------------------------------------------------------- R4 (red)

static func bbcode_colors(bb: String) -> Array[Color]:
	var out: Array[Color] = []
	var rx := RegEx.new()
	rx.compile("\\[(?:color|bgcolor|fgcolor|outline_color)=([^\\]\\s]+)")
	for m in rx.search_all(bb):
		var s := m.get_string(1)
		var col := Color.from_string(s, Color(0, 0, 0, 0))
		if col.a > 0.0:
			out.append(col)
	return out


static func _scan_red(n: Node, rp: String, defects: Array[Dictionary]) -> void:
	var hits: Array[String] = []
	if n is Control:
		var c := n as Control
		for cn in FONT_COLOR_NAMES:
			if c.has_theme_color(cn):
				var col := c.get_theme_color(cn)
				if cn == "font_outline_color" and c.has_theme_constant("outline_size") and c.get_theme_constant("outline_size") <= 0:
					continue
				if is_red(col):
					hits.append("%s %s" % [cn, hex(col)])
		var bs := box_style_of(c)
		if not bs.is_empty():
			for col2 in style_colors(bs[1]):
				if is_red(col2):
					hits.append("style '%s' draws %s" % [bs[0], hex(col2)])
					break
		for sn in STYLE_NAMES:
			if c.has_theme_stylebox_override(sn):
				for col3 in style_colors(c.get_theme_stylebox(sn)):
					if is_red(col3):
						hits.append("style override '%s' draws %s" % [sn, hex(col3)])
						break
		if c is ColorRect and is_red((c as ColorRect).color):
			hits.append("ColorRect.color %s" % hex((c as ColorRect).color))
	elif n is Polygon2D and is_red((n as Polygon2D).color):
		hits.append("Polygon2D.color %s" % hex((n as Polygon2D).color))
	elif n is Line2D and is_red((n as Line2D).default_color):
		hits.append("Line2D.default_color %s" % hex((n as Line2D).default_color))
	if n is CanvasItem:
		var ci := n as CanvasItem
		if is_red(ci.modulate):
			hits.append("modulate %s" % hex(ci.modulate))
		if is_red(ci.self_modulate):
			hits.append("self_modulate %s" % hex(ci.self_modulate))
	if n is Label and (n as Label).label_settings != null:
		var ls := (n as Label).label_settings
		if is_red(ls.font_color):
			hits.append("label_settings font colour %s" % hex(ls.font_color))
	if n is TextureProgressBar:
		for tn in TINT_PROPS:
			var tint: Color = n.get(tn)
			if is_red(tint):
				hits.append("%s %s" % [tn, hex(tint)])
	if n is RichTextLabel:
		for col4 in bbcode_colors((n as RichTextLabel).text):
			if is_red(col4):
				hits.append("[color] tag %s" % hex(col4))
	for h in hits:
		defects.append({"rule": "r4", "code": "r4_red", "path": rp, "msg": "%s %s: red is not in the palette, damage and 'too dear' are thorn-berry pink %s" % [class_name_of(n), h, hex(C.THORNBERRY)]})


# ---------------------------------------------------------------------------------------------------- text: R3, typography, raw keys

static func _scan_text_item(n: Node, rp: String, it: Dictionary, want: Array, strict: bool, defects: Array[Dictionary], notes: Array[Dictionary]) -> void:
	var font: Font = it["font"]
	var size: int = int(it["size"])
	var fam := font_family(font) if font != null else "other"
	var txt: String = str(it["text"])
	var variation := ""
	if n is Control:
		variation = String((n as Control).theme_type_variation)
	if "r3" in want and txt != "" and not bool(it.get("field", false)) and fam != "display" and (fam != "mono" or n.is_in_group(&"tt_number")):
		if (is_number_text(txt) or n.is_in_group(&"tt_number")) and not n.has_meta(&"tt_r3_ok") and variation not in R3_EXEMPT_VARIATIONS:
			defects.append({"rule": "r3", "code": "r3_number_not_display", "path": rp, "msg": "'%s' is a number / money / time but is set in the %s face (guide rule 'Tal i Caprasimo')" % [txt, fam]})
	if "typography" in want and fam != "mono" and fam != "other" and fam != "symbol":
		if size < TYPO_FLOOR:
			defects.append({"rule": "typography", "code": "font_below_floor", "path": rp, "msg": "%d px %s text is below the %d px floor ('%s')" % [size, fam, TYPO_FLOOR, txt.left(24)]})
		elif fam == "display" and size < DISPLAY_MIN:
			var counts_ok := variation in DISPLAY_COUNT_VARIATIONS and not bool(it["override"])
			var token_ok := variation != "" and not bool(it["override"]) and not strict
			if counts_ok or token_ok:
				notes.append({"rule": "typography", "path": rp, "msg": "%d px Caprasimo from the theme variation %s (a guide token below %d px)" % [size, variation, DISPLAY_MIN]})
			else:
				defects.append({"rule": "typography", "code": "font_too_small_display", "path": rp, "msg": "Caprasimo at %d px (minimum %d%s; only the slot-count variations %s are exempt in strict mode): '%s'" % [size, DISPLAY_MIN, ", from a per-node override" if bool(it["override"]) else "", str(DISPLAY_COUNT_VARIATIONS), txt.left(24)]})
		elif fam == "body" and size < BODY_MIN:
			var token := variation != "" and not bool(it["override"]) and not strict
			if token:
				notes.append({"rule": "typography", "path": rp, "msg": "%d px body text from the theme variation %s (a guide token below %d px)" % [size, variation, BODY_MIN]})
			else:
				defects.append({"rule": "typography", "code": "font_too_small_body", "path": rp, "msg": "Alegreya Sans at %d px (minimum %d%s): '%s'" % [size, BODY_MIN, ", from a per-node override" if bool(it["override"]) else (", strict: no variation exemption" if strict and variation != "" else ""), txt.left(24)]})


static func _scan_raw_keys(n: Node, rp: String, defects: Array[Dictionary]) -> void:
	var shown: Array[String] = []
	if n is Label:
		shown.append((n as Label).atr((n as Label).text))
	elif n is RichTextLabel:
		shown.append((n as RichTextLabel).get_parsed_text())
	elif n is Button:
		shown.append((n as Button).atr((n as Button).text))
	elif n is LineEdit:
		shown.append((n as LineEdit).atr((n as LineEdit).placeholder_text))
	if n is Control and (n as Control).tooltip_text != "":
		shown.append((n as Control).atr((n as Control).tooltip_text))
	for s in shown:
		if s != "" and is_key_shaped(s):
			defects.append({"rule": "i18n", "code": "raw_key", "path": rp, "msg": "%s shows the raw translation key '%s' (no translation exists)" % [class_name_of(n), s]})


# ---------------------------------------------------------------------------------------------------- hit targets

static func _scan_hit_target(c: Control, rp: String, hit_min: float, defects: Array[Dictionary], _seen: Dictionary) -> void:
	if c.has_meta(&"tt_hit_ok") or (c.mouse_filter == Control.MOUSE_FILTER_IGNORE and c.focus_mode == Control.FOCUS_NONE):
		return
	var sz := c.size * c.get_global_transform().get_scale().abs()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return                                       # not laid out (a zero-size control cannot be judged)
	var guide_small := String(c.theme_type_variation) in HIT_EXEMPT_VARIATIONS
	var minimum := minf(HIT_FLOOR, hit_min) if guide_small else hit_min
	if sz.x < minimum or sz.y < minimum:
		defects.append({"rule": "hit_targets", "code": "hit_target_small", "path": rp, "msg": "%s is %dx%d px, the minimum hit target is %d px%s" % [class_name_of(c), int(sz.x), int(sz.y), int(minimum), " (the guide's small components may be down to %d px)" % int(HIT_FLOOR) if guide_small else ""]})


# ---------------------------------------------------------------------------------------------------- hard-coded copy (source scan)

const TEXT_PROPS := "text|placeholder_text|tooltip_text|title|ok_button_text|cancel_button_text|dialog_text|button_text"


## Hard-coded Danish / English copy in the source of a screen: `text = "..."` lines of its .tscn files and `.text = "..."` / add_item("...")
## assignments of its GDScript files. Key-shaped strings (MENU_NEW_GAME), numbers, glyphs and strings with fewer than 3 letters pass.
## files: explicit res:// paths, else the root's scene file (+ the sub-scenes it names in scenes/ui, not components / dev) and the root's script
## plus the scripts next to it. Returns [{file, line, prop, text}].
static func literal_scan(root: Node, files: Array = []) -> Array[Dictionary]:
	var paths: Array[String] = []
	if not files.is_empty():
		for f in files:
			paths.append(str(f))
	else:
		paths = own_source_files(root)
	var out: Array[Dictionary] = []
	var scene_rx := RegEx.new()
	scene_rx.compile("(?m)^(%s)\\s*=\\s*\"((?:[^\"\\\\]|\\\\.)*)\"" % TEXT_PROPS)
	var code_rx := RegEx.new()
	code_rx.compile("\\.(%s)\\s*=\\s*\"((?:[^\"\\\\]|\\\\.)*)\"|\\.(add_item|add_tab|set_text)\\(\\s*\"((?:[^\"\\\\]|\\\\.)*)\"" % TEXT_PROPS)
	for p in paths:
		if not FileAccess.file_exists(p):
			continue
		var src := FileAccess.get_file_as_string(p)
		if p.ends_with(".tscn"):
			for m in scene_rx.search_all(src):
				_literal_hit(out, p, src, m.get_start(), m.get_string(1), m.get_string(2))
		elif p.ends_with(".gd"):
			for m in code_rx.search_all(src):
				var prop := m.get_string(1) if m.get_string(1) != "" else m.get_string(3)
				var text := m.get_string(2) if m.get_string(1) != "" else m.get_string(4)
				_literal_hit(out, p, src, m.get_start(), prop, text)
	return out


static func _literal_hit(out: Array[Dictionary], file: String, src: String, at: int, prop: String, text: String) -> void:
	var t := text.replace("\\n", " ").strip_edges()
	if t == "" or is_key_shaped(t) or letter_count(t) < 3:
		return
	if t.begins_with("res://") or t.begins_with("%") or t.begins_with("[") and t.ends_with("]"):
		return
	out.append({"file": file, "line": src.left(at).count("\n") + 1, "prop": prop, "text": t.left(60)})


## The source files that belong to a screen (see literal_scan).
static func own_source_files(root: Node) -> Array[String]:
	var out: Array[String] = []
	var scripts_dirs: Array[String] = []
	var rs: Script = root.get_script()
	if rs != null and rs.resource_path != "":
		out.append(rs.resource_path)
		scripts_dirs.append(rs.resource_path.get_base_dir())
	if root.scene_file_path != "":
		_scene_files(root.scene_file_path, out, 0)
	for n in root.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s != null and s.resource_path != "" and s.resource_path.get_base_dir() in scripts_dirs and not out.has(s.resource_path):
			out.append(s.resource_path)
	return out


static func _scene_files(path: String, out: Array[String], depth: int) -> void:
	if out.has(path) or depth > 3 or not FileAccess.file_exists(path):
		return
	out.append(path)
	var src := FileAccess.get_file_as_string(path)
	var rx := RegEx.new()
	rx.compile("\\[ext_resource type=\"PackedScene\"[^\\]]*path=\"([^\"]+)\"")
	for m in rx.search_all(src):
		var sub := m.get_string(1)
		if sub.begins_with("res://scenes/") and not sub.contains("/components/") and not sub.contains("/dev/"):
			_scene_files(sub, out, depth + 1)


# ---------------------------------------------------------------------------------------------------- the project theme

## Static scan of a Theme (default: the project theme). Result: {ok, defects: [{rule, code, path, msg}], types, gold_hover: [{variation, state}], red: [{variation, item}],
## ink: [{variation, state, detail}], font_scale: [{variation, detail}], focus_styles: [variation]}.
##  red          a red colour in any colour item or StyleBox (always a defect, R4)
##  ink          a main style (panel / normal) of a panel, button or field that is a light, opaque, outline-less box (always a defect, R1)
##  gold_hover   gold (fill or ring) in a normal / hover / disabled / panel / slider style of a variation outside GOLD_ORNAMENT (spec 2.2 layer a); a defect only with
##               options.strict_gold_hover (the committed theme still has some: spec Appendix E)
##  font_scale   a Label / Button variation below the smallest guide size (Caprasimo 15, Alegreya 11); a defect only with options.strict_font_scale
##  focus_styles interactive types (Button family, LineEdit, CheckBox, HSlider) whose focus StyleBox is empty or missing (not FocusProxy); a defect only with
##               options.strict_focus_styles. A focus style that exists but has no gold is always a defect (focus_style_not_gold). An HSlider / VSlider entry is only the
##               style a TTSlider paints: Godot's Slider never draws it (probed in 4.7.2), so its presence in the theme proves nothing about a plain slider.
static func theme_scan(theme: Theme = null, options: Dictionary = {}) -> Dictionary:
	return _theme_scan_of(theme if theme != null else ThemeDB.get_project_theme(), options)


## theme_scan of an explicit theme; null (no project theme is loaded) is the defect `no_theme`.
static func _theme_scan_of(th: Theme, options: Dictionary) -> Dictionary:
	var defects: Array[Dictionary] = []
	var gold_hover: Array[Dictionary] = []
	var red: Array[Dictionary] = []
	var ink: Array[Dictionary] = []
	var font_scale: Array[Dictionary] = []
	var focus_styles: Array[String] = []
	if th == null:
		return {"ok": false, "defects": [{"rule": "theme", "code": "no_theme", "path": "", "msg": "no project theme is loaded"}], "types": 0, "gold_hover": gold_hover, "red": red, "ink": ink, "font_scale": font_scale, "focus_styles": focus_styles}
	var types := th.get_type_list()
	types.sort()
	for ty in types:
		var base := _root_type(th, ty)
		for nm in th.get_stylebox_list(ty):
			var sb := th.get_stylebox(nm, ty)
			var gold_seen := false
			for col in style_colors(sb):
				if is_red(col):
					red.append({"variation": ty, "item": nm})
					defects.append({"rule": "r4", "code": "r4_red", "path": "theme:%s/%s" % [ty, nm], "msg": "theme style draws red %s" % hex(col)})
					break
			if not (str(nm).contains("focus") or str(nm).contains("pressed") or str(nm).contains("selected")) and str(ty) not in GOLD_ORNAMENT:
				for col2 in style_colors(sb):
					gold_seen = gold_seen or is_gold(col2)
				if gold_seen:
					gold_hover.append({"variation": ty, "state": nm})
		for nm2 in th.get_color_list(ty):
			if is_red(th.get_color(nm2, ty)):
				red.append({"variation": ty, "item": nm2})
				defects.append({"rule": "r4", "code": "r4_red", "path": "theme:%s/%s" % [ty, nm2], "msg": "theme colour is red %s" % hex(th.get_color(nm2, ty))})
		var main := ""
		if base in ["PanelContainer", "Panel"]:
			main = "panel"
		elif base in ["Button", "OptionButton", "CheckBox", "LineEdit"]:
			main = "normal"
		if main != "" and th.has_stylebox(main, ty) and ty not in R1_EXEMPT_VARIATIONS:
			var why := r1_problem(th.get_stylebox(main, ty))
			if why != "":
				ink.append({"variation": ty, "state": main, "detail": why})
				defects.append({"rule": "r1", "code": "r1_no_ink_outline", "path": "theme:%s/%s" % [ty, main], "msg": why})
		if base in ["Button", "OptionButton", "CheckBox", "LineEdit", "HSlider", "VSlider"] and ty != "FocusProxy":
			var has_focus := th.has_stylebox("focus", ty) and not (th.get_stylebox("focus", ty) is StyleBoxEmpty)
			if not has_focus:
				focus_styles.append(ty)
			else:
				var gold_there := false
				for col3 in style_colors(th.get_stylebox("focus", ty)):
					gold_there = gold_there or is_gold(col3)
				if not gold_there:
					defects.append({"rule": "focus", "code": "focus_style_not_gold", "path": "theme:%s/focus" % ty, "msg": "the focus style of %s has no gold ring" % ty})
		if (base in ["Label", "Button", "OptionButton", "CheckBox", "LineEdit"]) and th.has_font("font", ty) and th.has_font_size("font_size", ty):
			var fam := font_family(th.get_font("font", ty))
			var size := th.get_font_size("font_size", ty)
			if (fam == "display" and size < 15) or (fam == "body" and size < 11) or (fam == "mono" and size < 9):
				font_scale.append({"variation": ty, "detail": "%s %d px is below the smallest guide size" % [fam, size]})
	if bool(options.get("strict_gold_hover", false)):
		for g in gold_hover:
			defects.append({"rule": "r2", "code": "theme_gold_hover", "path": "theme:%s/%s" % [g["variation"], g["state"]], "msg": "gold in the %s style of %s: only focus, selected and the guide's ornaments (GOLD_ORNAMENT) are gold" % [g["state"], g["variation"]]})
	if bool(options.get("strict_focus_styles", false)):
		for f in focus_styles:
			defects.append({"rule": "focus", "code": "theme_focus_empty", "path": "theme:%s/focus" % f, "msg": "%s has no focus StyleBox: a focused %s shows no ring" % [f, f]})
	if bool(options.get("strict_font_scale", false)):
		for fs in font_scale:
			defects.append({"rule": "typography", "code": "theme_font_scale", "path": "theme:%s" % fs["variation"], "msg": fs["detail"]})
	return {"ok": defects.is_empty(), "defects": defects, "types": types.size(), "gold_hover": gold_hover, "red": red, "ink": ink, "font_scale": font_scale, "focus_styles": focus_styles}


static func _root_type(th: Theme, ty: StringName) -> String:
	var cur := String(ty)
	for _i in 8:
		var b := String(th.get_type_variation_base(cur))
		if b == "":
			return cur
		cur = b
	return cur
