extends SceneTree
## Generates res://assets/ui/theme.tres from the Trætoppen style guide numbers.
##   godot --headless --path <project> -s res://tools/ui/build_theme.gd
## theme.tres is a normal resource afterwards (open it in the editor, tweak, diff it); this script
## exists so every number has ONE source (the style guide) and can be regenerated on a palette change.
## All sizes are DESIGN pixels (the guide's 1280x720 canvas). The project viewport is 1280x720
## and stretches to the window, so 22 here == 22 in the HTML.

const C = preload("res://scripts/ui/theme/tt_colors.gd")
const BoxStyle = preload("res://scripts/ui/theme/tt_box_style.gd")
## The rarity ladder (P10): fill / ring / label / pip colours of the five tiles. build_theme runs before the autoloads exist,
## so Rarity answers with its built-in table, which tests/sections/rarity.gd proves identical to lua/config/rarity.lua.
const RarityTable = preload("res://scripts/data/rarity.gd")
const OUT := "res://assets/ui/theme.tres"
## `-- --out=PATH` writes the theme somewhere else (tests/sections/ui_foundation.gd regenerates into user:// and compares with the committed file)

var t := Theme.new()
var f_body: Font
var f_bold: Font
var f_heavy: Font
var f_italic: Font
var f_display: Font
var f_mono: Font

## The hover of rows, chips and tabs is NEVER gold (UI_NAVIGATION.md 2.2 / 4.6, P28): a chalk wash (#fbf5e6 at 55 %, the RowButton hover).
const CHALK_WASH := Color(0.984, 0.961, 0.902, 0.55)
## a wash for a control that sits on a chalk field (the stepper buttons): a chalk wash would not show there
const PARCHMENT_WASH := Color(0.925, 0.863, 0.706, 0.8)
const RING_PANEL_COLORS := [C.GOLD, C.INK]
const RING_PANEL_W := [4.0, 2.0]
const RING_SEL_COLORS := [C.GOLD, C.INK]
const RING_SEL_W := [3.0, 2.0]


func _init() -> void:
	_fonts()
	_base()
	_labels()
	_panels()
	_buttons()
	_pills_rows_slots()
	_meters()
	_inputs_misc()
	var out := OUT
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	var err := ResourceSaver.save(t, out)
	print("theme saved: ", out, " err=", err)
	quit(0 if err == OK else 1)


# ------------------------------------------------------------------ fonts
## lining: Alegreya Sans defaults to OLD-STYLE figures ("0" reads like "o": "0t 0m" -> "ot om"). The browser mock shows
## old-style too, but money/time/counts must stay readable, so body fonts get OpenType 'lnum'. Delete the one line
## below to reproduce the HTML exactly.
func _fv(base: Font, fallbacks: Array, lining := false) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	if lining:
		f.opentype_features = {"lnum": 1}
	var fb: Array[Font] = []
	for x in fallbacks:
		fb.append(x)
	f.fallbacks = fb
	return f


func _fonts() -> void:
	var cap: Font = load("res://assets/fonts/Caprasimo-Regular.ttf")
	var med: Font = load("res://assets/fonts/AlegreyaSans-Medium.ttf")
	var bold: Font = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	var xbold: Font = load("res://assets/fonts/AlegreyaSans-ExtraBold.ttf")
	var ital: Font = load("res://assets/fonts/AlegreyaSans-MediumItalic.ttf")
	var mono: Font = load("res://assets/fonts/IBMPlexMono-Regular.ttf")
	var sym: Font = load("res://assets/fonts/TTSymbols-Regular.ttf")
	f_body = _fv(med, [sym], true)
	f_bold = _fv(bold, [sym], true)
	f_heavy = _fv(xbold, [sym], true)
	f_italic = _fv(ital, [sym], true)
	f_display = _fv(cap, [xbold, sym])      # Caprasimo lacks "·" and "−": fall back to Alegreya
	f_mono = _fv(mono, [sym])


func _base() -> void:
	t.default_font = f_body
	t.default_font_size = 20


# ------------------------------------------------------------------ helpers
func box(props: Dictionary, margins := Vector4(-1, -1, -1, -1)) -> StyleBox:
	var s: StyleBox = BoxStyle.new()
	for k in props:
		s.set(k, props[k])
	if margins.x >= 0.0:
		s.content_margin_left = margins.x
		s.content_margin_top = margins.y
		s.content_margin_right = margins.z
		s.content_margin_bottom = margins.w
	return s


func rings(colors: Array, widths: Array) -> Dictionary:
	return {"ring_colors": PackedColorArray(colors), "ring_widths": PackedFloat32Array(widths)}


func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var o := a.duplicate()
	o.merge(b, true)
	return o


func set_label_var(vname: String, font: Font, size: int, color: Color, extra_line := 0, base := "Label") -> void:
	t.set_type_variation(vname, base)
	t.set_font("font", vname, font)
	t.set_font_size("font_size", vname, size)
	t.set_color("font_color", vname, color)
	t.set_constant("line_spacing", vname, extra_line)


# ------------------------------------------------------------------ labels
func _labels() -> void:
	t.set_color("font_color", "Label", C.INK)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_color("font_outline_color", "Label", C.INK)
	t.set_constant("line_spacing", "Label", 0)

	# Hero title: cream fill, ink outline, hard ink drop (text-shadow 0 6px 0 ink)
	set_label_var("HeroTitle", f_display, 132, C.CHALK)
	t.set_constant("outline_size", "HeroTitle", 9)
	t.set_color("font_shadow_color", "HeroTitle", C.INK)
	t.set_constant("shadow_offset_y", "HeroTitle", 7)
	t.set_constant("shadow_offset_x", "HeroTitle", 0)
	t.set_constant("shadow_outline_size", "HeroTitle", 9)

	# Caprasimo scale (design px): numbers, titles, buttons, money, time
	set_label_var("Display48", f_display, 48, C.INK)
	set_label_var("Display40", f_display, 40, C.INK)
	set_label_var("Display34", f_display, 34, C.INK)
	set_label_var("Display32", f_display, 32, C.INK)
	set_label_var("Display30", f_display, 30, C.INK)         # clock
	set_label_var("Display28", f_display, 28, C.INK)
	set_label_var("Display24", f_display, 24, C.INK)         # money in footers
	set_label_var("Display22", f_display, 22, C.INK)
	set_label_var("Display20", f_display, 20, C.INK)         # prices
	set_label_var("Display19", f_display, 19, C.INK)         # tracked quest title
	set_label_var("Display16", f_display, 16, C.INK)         # slot counts
	set_label_var("Display15", f_display, 15, C.INK)         # hotbar counts
	set_label_var("Display15Night", f_display, 15, RarityTable.ui(&"legendary")["icon_rim"])   # slot count on the night tile
	set_label_var("Display16Night", f_display, 16, RarityTable.ui(&"legendary")["icon_rim"])
	set_label_var("MoneyPill", f_display, 22, C.CHALK)       # "1.250" in the gold-ringed pill
	set_label_var("MoneyDark", f_display, 20, C.GOLD_DARK)
	set_label_var("DisplayCream24", f_display, 24, C.CHALK)  # boss name
	t.set_constant("outline_size", "DisplayCream24", 3)
	t.set_color("font_shadow_color", "DisplayCream24", C.INK)
	t.set_constant("shadow_offset_y", "DisplayCream24", 2)
	set_label_var("ToolName", f_display, 20, C.CHALK)        # "Vandkande" above hotbar
	t.set_constant("outline_size", "ToolName", 3)
	t.set_color("font_shadow_color", "ToolName", C.INK)
	t.set_constant("shadow_offset_y", "ToolName", 2)
	set_label_var("CooldownNumber", f_display, 22, C.CHALK)
	set_label_var("Display15Owl", f_display, 15, C.OWL_EYE)
	set_label_var("RequirementMet", f_body, 14, C.MOSS_DARK)
	set_label_var("RequirementMissing", f_body, 14, C.THORNBERRY)

	# Alegreya Sans
	set_label_var("BodyL", f_body, 22, C.INK, 10)            # 22px / 1.45
	set_label_var("Body", f_body, 20, C.INK, 9)              # dialogue text 20px / 1.45
	set_label_var("BodyM", f_body, 19, C.INK, 8)
	set_label_var("Subtitle", f_body, 20, C.TEXT_MUTED, 6)
	set_label_var("Muted17", f_body, 17, C.TEXT_MUTED, 7)    # perk text
	set_label_var("Muted16", f_body, 16, C.TEXT_MUTED, 6)
	set_label_var("Muted15", f_body, 15, C.TEXT_MUTED, 5)
	set_label_var("Muted14", f_body, 14, C.TEXT_MUTED, 4)
	set_label_var("Muted13", f_body, 13, C.TEXT_MUTED, 3)
	set_label_var("Heavy19", f_heavy, 19, C.INK)
	set_label_var("Heavy18", f_heavy, 18, C.INK)
	set_label_var("Heavy17", f_heavy, 17, C.INK)
	set_label_var("Heavy16", f_heavy, 16, C.INK)
	set_label_var("Heavy14", f_heavy, 14, C.INK)
	set_label_var("Bold19", f_bold, 19, C.INK)
	set_label_var("Bold16", f_bold, 16, C.INK)             # "18 / 24" of the backpack (P28, UI_NAVIGATION.md 4.6 item 3c)
	set_label_var("Bold14", f_bold, 14, C.INK)             # the recipe state "Kan laves"
	set_label_var("Bold18", f_bold, 18, C.INK)
	set_label_var("Bold17Muted", f_bold, 17, C.TEXT_MUTED)
	set_label_var("Bold15Mono", f_bold, 15, C.TEXT_MONO)   # "Dag 14" next to menu rows
	set_label_var("Bold15Gold", f_bold, 15, C.GOLD)        # "guldagern"
	set_label_var("HotkeyDigit", f_heavy, 11, C.TEXT_FAINT)
	set_label_var("Whisper", f_italic, 18, Color("#e6f5f1"), 4)
	set_label_var("Eyebrow", f_mono, 11, C.TEXT_MONO)       # "AKTIVE OPGAVER", "BELØNNING"
	set_label_var("EyebrowL", f_mono, 13, C.TEXT_MONO)
	set_label_var("HintOnDark", f_mono, 13, C.CHALK)        # HintBar words on the dark screen scrim (#3a3150): Eyebrow there is ~1.8:1
	set_label_var("FilePath", f_mono, 12, C.TEXT_FAINT)
	set_label_var("OwlEye15", f_heavy, 15, C.OWL_EYE)      # "Lygteolie"
	set_label_var("RareTag", f_body, 14, C.RARE_TEXT)
	# The rarity WORD ("Sjælden") in its label colour (>= 4.5:1 on parchment, tests/sections/ui_foundation.gd): detail cards, tooltips
	for rid in RarityTable.ids():
		var word_col: Color = RarityTable.ui(rid)["label"]
		set_label_var("RarityWord" + String(rid).capitalize(), f_heavy, 17, word_col)
		set_label_var("RarityWord15" + String(rid).capitalize(), f_heavy, 15, word_col)

	# Plates (Label + StyleBox): dialogue name plate, energy label, key caps, version tag, tagline
	set_label_var("NamePlate", f_display, 20, C.CHALK)
	t.set_stylebox("normal", "NamePlate", box({"fill": C.INK, "border_width": 0.0, "radius": 8.0,
		"soft_shadow_color": Color(0, 0, 0, 0), "ring_colors": PackedColorArray([C.GOLD]), "ring_widths": PackedFloat32Array([2.0])},
		Vector4(12, 2, 12, 2)))
	t.set_stylebox("normal", "Label", StyleBoxEmpty.new())

	set_label_var("EnergyTag", f_heavy, 14, C.CHALK)
	t.set_stylebox("normal", "EnergyTag", box({"fill": C.INK, "border_width": 0.0, "radius": 6.0}, Vector4(8, 0, 8, 0)))

	set_label_var("KeyCap", f_heavy, 13, C.CHALK)
	t.set_stylebox("normal", "KeyCap", box({"fill": C.INK, "border_color": C.GOLD, "border_width": 1.0, "radius": 6.0}, Vector4(9, 0, 9, 0)))

	set_label_var("VersionTag", f_bold, 15, C.INK)
	t.set_stylebox("normal", "VersionTag", box({"fill": Color(0.984, 0.961, 0.902, 0.85), "border_width": 0.0, "radius": 6.0}, Vector4(10, 3, 10, 3)))

	set_label_var("Tagline", f_display, 26, C.INK)
	t.set_stylebox("normal", "Tagline", box({"fill": C.GOLD, "border_color": C.INK, "border_width": 2.0, "radius": 10.0}, Vector4(18, 2, 18, 2)))

	set_label_var("ZoneChip", f_display, 16, C.INK)
	t.set_stylebox("normal", "ZoneChip", box({"fill": C.GOLD, "border_color": C.INK, "border_width": 2.0, "radius": 8.0}, Vector4(12, 0, 12, 0)))

	set_label_var("PromptVerb", f_heavy, 18, C.CHALK)     # the verb inside the prompt pill (the pill itself is a container wearing the PromptPill look)
	set_label_var("PromptPill", f_heavy, 18, C.CHALK)
	t.set_stylebox("normal", "PromptPill", box({"fill": C.INK, "border_color": C.GOLD, "border_width": 2.0, "radius": 999.0}, Vector4(16, 4, 16, 4)))

	set_label_var("ArtNote", f_mono, 13, C.INK)
	t.set_stylebox("normal", "ArtNote", box({"fill": Color(0.984, 0.961, 0.902, 0.92), "border_width": 0.0, "radius": 4.0}, Vector4(10, 5, 10, 5)))

	set_label_var("StepDone", f_bold, 19, C.TEXT_FAINT)
	set_label_var("StepOpen", f_bold, 19, C.INK)

	# Quest-book step text: Alegreya 700, 19px (strike-through handled with [s] in BBCode)
	t.set_type_variation("StepText", "RichTextLabel")
	t.set_font("normal_font", "StepText", f_bold)
	t.set_font_size("normal_font_size", "StepText", 19)
	t.set_constant("line_separation", "StepText", 4)
	set_label_var("StepCheck", f_heavy, 15, C.CHALK)

	# RichTextLabel (dialogue body, journal text)
	t.set_font("normal_font", "RichTextLabel", f_body)
	t.set_font("bold_font", "RichTextLabel", f_heavy)
	t.set_font("italics_font", "RichTextLabel", f_italic)
	t.set_font("bold_italics_font", "RichTextLabel", f_italic)
	t.set_font("mono_font", "RichTextLabel", f_mono)
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	t.set_font_size("italics_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_italics_font_size", "RichTextLabel", 20)
	t.set_font_size("mono_font_size", "RichTextLabel", 14)
	t.set_color("default_color", "RichTextLabel", C.INK)
	t.set_constant("line_separation", "RichTextLabel", 9)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())
	t.set_type_variation("DialogueText", "RichTextLabel")
	t.set_font_size("normal_font_size", "DialogueText", 20)
	t.set_constant("line_separation", "DialogueText", 9)


# ------------------------------------------------------------------ panels
func panel_var(vname: String, props: Dictionary, margins: Vector4) -> void:
	t.set_type_variation(vname, "PanelContainer")
	t.set_stylebox("panel", vname, box(props, margins))


func _panels() -> void:
	t.set_stylebox("panel", "PanelContainer", box({"fill": C.PARCHMENT, "radius": 16.0}, Vector4(16, 16, 16, 16)))
	t.set_stylebox("panel", "Panel", box({"fill": C.PARCHMENT, "radius": 16.0}))

	var panel_ring := rings(RING_PANEL_COLORS, RING_PANEL_W)
	var shadow_dlg := {"soft_shadow_color": C.SHADOW, "soft_shadow_blur": 28.0, "soft_shadow_offset": Vector2(0, 12)}
	var shadow_book := {"soft_shadow_color": Color(0.169, 0.137, 0.251, 0.35), "soft_shadow_blur": 36.0, "soft_shadow_offset": Vector2(0, 16)}

	# Dialogue box: radius 16, padding 20 (+2 border)
	panel_var("PanelParchment", merge(panel_ring, shadow_dlg), Vector4(22, 22, 22, 22))
	# Shop / quest book / inventory: radius 18
	panel_var("PanelParchmentL", merge(merge(panel_ring, shadow_book), {"radius": 18.0}), Vector4(2, 2, 2, 2))
	panel_var("PanelParchmentL24", merge(panel_ring, {"radius": 18.0}), Vector4(26, 26, 26, 26))
	# HUD date block: radius 14, ring, padding 10/18
	panel_var("PanelHud", merge(panel_ring, {"radius": 14.0}), Vector4(20, 12, 20, 12))
	# Quest tracker card: radius 14, soft shadow 0 8 20, padding 14/18
	panel_var("PanelCard", {"radius": 14.0, "soft_shadow_color": Color(0.169, 0.137, 0.251, 0.25), "soft_shadow_blur": 20.0, "soft_shadow_offset": Vector2(0, 8)}, Vector4(20, 16, 20, 16))
	# Speech bubble (chalk)
	panel_var("PanelBubble", {"fill": C.CHALK, "radius": 16.0}, Vector4(20, 16, 20, 16))
	# Money pill (ink + gold border) and lantern pill (night, gold border)
	panel_var("PillGold", {"fill": C.INK, "border_color": C.GOLD, "radius": 999.0}, Vector4(8, 6, 18, 6))
	panel_var("PillNight", {"fill": C.NIGHT_PANEL, "border_color": C.GOLD, "radius": 999.0}, Vector4(16, 6, 16, 6))
	# Whisper (forest hint)
	panel_var("PanelWhisper", {"fill": C.NIGHT_PANEL, "border_color": C.GLOWSHROOM, "radius": 12.0}, Vector4(16, 12, 16, 12))
	# Loot feed row
	panel_var("PanelLoot", {"radius": 10.0}, Vector4(8, 8, 14, 8))
	# Sidebar (journal), footer (shop), field (stepper), detail strip
	panel_var("PanelSidebar", {"fill": C.PARCHMENT_DARK, "radius": 16.0, "corners": Vector4(16, 0, 0, 16),
		"border_sides": Vector4(0, 0, 2, 0)}, Vector4(26, 26, 28, 26))
	panel_var("PanelFooter", {"fill": C.PARCHMENT_DARK, "radius": 16.0, "corners": Vector4(0, 0, 16, 16),
		"border_sides": Vector4(0, 2, 0, 0)}, Vector4(24, 16, 24, 16))
	panel_var("PanelHeader", {"fill": Color(0, 0, 0, 0), "radius": 0.0, "border_sides": Vector4(0, 0, 0, 2)}, Vector4(24, 18, 24, 18))
	panel_var("PanelField", {"fill": C.CHALK, "radius": 10.0}, Vector4(0, 0, 0, 0))
	# the stepper is ONE focus stop painted by its root: its ring is this style (quantity_stepper.gd draws it, like TTSlider)
	t.set_stylebox("focus", "PanelField", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 10.0})))
	panel_var("PanelDetail", {"fill": C.CHALK, "radius": 12.0}, Vector4(16, 16, 16, 16))
	panel_var("PanelRecipe", {"fill": C.CHALK, "radius": 12.0}, Vector4(18, 18, 18, 18))
	# Toast / notification
	panel_var("PanelToast", merge(rings([C.GOLD, C.INK], [3.0, 2.0]), {"radius": 14.0}), Vector4(18, 10, 18, 10))
	# Round minimap frame
	panel_var("PanelRound", merge(panel_ring, {"radius": 200.0, "fill": C.SHADOW_MOSS}), Vector4(0, 0, 0, 0))
	# Ability slot
	panel_var("PanelAbility", merge(rings([C.GOLD, C.INK], [3.0, 2.0]), {"radius": 14.0}), Vector4(0, 0, 0, 0))
	# Hotbar tray (ring, radius 16, padding 8, shadow 0 10 20)
	panel_var("PanelHotbar", merge(panel_ring, {"radius": 16.0, "soft_shadow_color": C.SHADOW, "soft_shadow_blur": 20.0, "soft_shadow_offset": Vector2(0, 10)}), Vector4(10, 10, 10, 10))

	# Coins (gold disc): money pill uses a cream rim, shop footer an ink rim
	panel_var("Coin", {"fill": C.GOLD, "border_color": C.CHALK, "radius": 999.0}, Vector4(0, 0, 0, 0))
	panel_var("CoinInk", {"fill": C.GOLD, "border_color": C.INK, "radius": 999.0}, Vector4(0, 0, 0, 0))
	# Stripe-less colour tags / key-art frame / plain ink-outlined frame (portraits, icon boxes)
	panel_var("FrameInk", {"fill": C.CHALK, "radius": 10.0}, Vector4(0, 0, 0, 0))
	panel_var("FramePortrait", {"fill": C.LAVENDER_PALE, "radius": 12.0}, Vector4(0, 0, 0, 0))
	panel_var("FramePortraitRound", merge(rings([C.GOLD], [3.0]), {"fill": C.LAVENDER_PALE, "radius": 999.0}), Vector4(0, 0, 0, 0))
	panel_var("ChipReward", {"fill": C.CHALK, "radius": 10.0}, Vector4(14, 6, 14, 6))
	panel_var("ChipRewardRose", {"fill": C.ROSE, "radius": 10.0}, Vector4(14, 6, 14, 6))
	panel_var("TagBox", {"fill": C.LAVENDER_PALE, "radius": 10.0}, Vector4(0, 0, 0, 0))
	panel_var("StepBox", {"fill": C.CHALK, "radius": 6.0}, Vector4(0, 0, 0, 0))
	panel_var("StepBoxDone", {"fill": C.MOSS, "radius": 6.0}, Vector4(0, 0, 0, 0))
	panel_var("CraftCard", {"fill": C.CHALK, "radius": 12.0}, Vector4(18, 18, 18, 18))
	panel_var("IngredientBox", {"fill": C.PARCHMENT_DARK, "radius": 10.0}, Vector4(0, 0, 0, 0))

	panel_var("PanelTooltip", {"fill": C.CHALK, "radius": 10.0, "soft_shadow_color": Color(0.169, 0.137, 0.251, 0.25), "soft_shadow_blur": 14.0, "soft_shadow_offset": Vector2(0, 6)}, Vector4(14, 10, 14, 10))
	panel_var("PanelMenu", merge(panel_ring, {"radius": 16.0, "soft_shadow_color": Color(0.169, 0.137, 0.251, 0.35), "soft_shadow_blur": 30.0, "soft_shadow_offset": Vector2(0, 14)}), Vector4(16, 16, 16, 16))
	# Plain parchment page frame with ring (quest book), shadow 0 20 40
	panel_var("PanelBook", merge(panel_ring, {"radius": 18.0, "soft_shadow_color": Color(0, 0, 0, 0.4), "soft_shadow_blur": 40.0, "soft_shadow_offset": Vector2(0, 20)}), Vector4(2, 2, 2, 2))
	panel_var("PanelHearts", merge(panel_ring, {"radius": 14.0}), Vector4(16, 10, 16, 10))
	panel_var("PanelAbilityBig", merge(rings([C.GOLD, C.INK], [3.0, 2.0]), {"radius": 14.0}), Vector4(2, 2, 2, 2))
	# Full-screen dim behind modals
	panel_var("PanelScrim", {"fill": Color(0.110, 0.129, 0.220, 0.62), "border_width": 0.0, "radius": 0.0}, Vector4(0, 0, 0, 0))

	# Godot's own tooltip
	t.set_stylebox("panel", "TooltipPanel", box({"fill": C.CHALK, "radius": 10.0, "soft_shadow_color": Color(0.169, 0.137, 0.251, 0.25), "soft_shadow_blur": 14.0, "soft_shadow_offset": Vector2(0, 6)}, Vector4(14, 10, 14, 10)))
	t.set_color("font_color", "TooltipLabel", C.INK)
	t.set_font("font", "TooltipLabel", f_body)
	t.set_font_size("font_size", "TooltipLabel", 17)

	# Popup menus (OptionButton drop-downs)
	t.set_stylebox("panel", "PopupMenu", box(merge(panel_ring, {"radius": 12.0}), Vector4(10, 10, 10, 10)))
	t.set_stylebox("hover", "PopupMenu", box({"fill": CHALK_WASH, "border_width": 0.0, "radius": 8.0}, Vector4(10, 4, 10, 4)))
	t.set_color("font_color", "PopupMenu", C.INK)
	t.set_color("font_hover_color", "PopupMenu", C.INK)
	t.set_font("font", "PopupMenu", f_heavy)
	t.set_font_size("font_size", "PopupMenu", 18)

	var sep := StyleBoxLine.new()
	sep.color = C.DIVIDER
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 8)
	var vsep := StyleBoxLine.new()
	vsep.color = C.DIVIDER
	vsep.thickness = 2
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)


# ------------------------------------------------------------------ buttons
## Build the five states for a classic guide button.
##   face/hover: fill; band: lower band colour alpha (0 = none); pad: Vector2(h, v) in CSS padding terms
func _btn_state(face: Color, band: Color, off: float, hard: float, pad: Vector2, dashed := false, border_col: Color = C.INK) -> StyleBox:
	var props := {
		"fill": face, "border_color": border_col, "border_width": 2.0, "radius": 12.0,
		"body_inset": Vector4(0, 2, 0, 4), "y_offset": off, "hard_shadow": hard,
		"dashed": dashed,
	}
	if band.a > 0.0:
		props["band_side"] = BoxStyle.BandSide.BOTTOM
		props["band_size"] = 5.0 if off < 3.0 else 2.0
		props["band_color"] = band
	var top := 2.0 + off + 2.0 + pad.y
	var bottom := 4.0 + 2.0 + pad.y - off
	return box(props, Vector4(2.0 + pad.x, top, 2.0 + pad.x, bottom))


func _btn_focus(pad: Vector2) -> StyleBox:
	var props := merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 12.0, "body_inset": Vector4(0, 2, 0, 4)})
	return box(props, Vector4(2.0 + pad.x, 2.0 + 2.0 + pad.y, 2.0 + pad.x, 4.0 + 2.0 + pad.y))


func button_kind(vname: String, face: Color, face_hover: Color, text: Color, band: Color, pad: Vector2, font_size: int) -> void:
	t.set_type_variation(vname, "Button")
	t.set_font("font", vname, f_display)
	t.set_font_size("font_size", vname, font_size)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, vname, text)
	t.set_color("font_disabled_color", vname, C.TEXT_DISABLED)
	t.set_stylebox("normal", vname, _btn_state(face, band, 0.0, 4.0, pad))
	t.set_stylebox("hover", vname, _btn_state(face_hover, band, -2.0, 4.0, pad))
	t.set_stylebox("pressed", vname, _btn_state(face_hover, band, 3.0, 1.0, pad))
	t.set_stylebox("hover_pressed", vname, _btn_state(face_hover, band, 3.0, 1.0, pad))
	t.set_stylebox("disabled", vname, _btn_state(C.DISABLED_BG, Color(0, 0, 0, 0), 0.0, 0.0, pad, true, C.TEXT_DISABLED))
	t.set_stylebox("focus", vname, _btn_focus(pad))
	t.set_constant("h_separation", vname, 8)
	t.set_constant("outline_size", vname, 0)


func _buttons() -> void:
	var band30 := C.INK_SOFT_30
	var band20 := C.INK_SOFT_20
	var none := Color(0, 0, 0, 0)
	var sizes := {"": [Vector2(26, 10), 22], "S": [Vector2(26, 8), 22], "L": [Vector2(30, 12), 24]}
	for sz in sizes:
		var pad: Vector2 = sizes[sz][0]
		var fs: int = sizes[sz][1]
		button_kind("ButtonPrimary" + sz, C.MOSS, C.MOSS_HOVER, C.CHALK, band30, pad, fs)
		button_kind("ButtonSecondary" + sz, C.GOLD, C.GOLD_HOVER, C.INK, band20, pad, fs)
		button_kind("ButtonTertiary" + sz, C.CHALK, C.CHALK, C.INK, none, pad, fs)
	# the plain "Button" type is the cream tertiary
	t.set_font("font", "Button", f_display)
	t.set_font_size("font_size", "Button", 22)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, "Button", C.INK)
	t.set_color("font_disabled_color", "Button", C.TEXT_DISABLED)
	var pad0 := Vector2(26, 10)
	t.set_stylebox("normal", "Button", _btn_state(C.CHALK, none, 0.0, 4.0, pad0))
	t.set_stylebox("hover", "Button", _btn_state(C.CHALK, none, -2.0, 4.0, pad0))
	t.set_stylebox("pressed", "Button", _btn_state(C.CHALK, none, 3.0, 1.0, pad0))
	t.set_stylebox("hover_pressed", "Button", _btn_state(C.CHALK, none, 3.0, 1.0, pad0))
	t.set_stylebox("disabled", "Button", _btn_state(C.DISABLED_BG, none, 0.0, 0.0, pad0, true, C.TEXT_DISABLED))
	t.set_stylebox("focus", "Button", _btn_focus(pad0))
	t.set_constant("h_separation", "Button", 8)
	t.set_color("icon_normal_color", "Button", C.INK)
	t.set_color("icon_hover_color", "Button", C.INK)
	t.set_color("icon_pressed_color", "Button", C.INK)
	t.set_color("icon_focus_color", "Button", C.INK)

	# Row-height small variants used in dense headers
	t.set_type_variation("ButtonTertiaryS", "ButtonTertiary")
	t.set_font_size("font_size", "ButtonTertiaryS", 18)
	var padS := Vector2(14, 4)
	t.set_stylebox("normal", "ButtonTertiaryS", _btn_state(C.CHALK, Color(0, 0, 0, 0), 0.0, 3.0, padS))
	t.set_stylebox("hover", "ButtonTertiaryS", _btn_state(C.CHALK, Color(0, 0, 0, 0), -2.0, 3.0, padS))
	t.set_stylebox("pressed", "ButtonTertiaryS", _btn_state(C.CHALK, Color(0, 0, 0, 0), 3.0, 1.0, padS))
	t.set_stylebox("hover_pressed", "ButtonTertiaryS", _btn_state(C.CHALK, Color(0, 0, 0, 0), 3.0, 1.0, padS))
	t.set_stylebox("disabled", "ButtonTertiaryS", _btn_state(C.DISABLED_BG, Color(0, 0, 0, 0), 0.0, 0.0, padS, true, C.TEXT_DISABLED))
	t.set_stylebox("focus", "ButtonTertiaryS", _btn_focus(padS))

	# Title-screen menu row: transparent until hovered/focused, then gold with ink outline
	t.set_type_variation("MenuRow", "Button")
	t.set_font("font", "MenuRow", f_display)
	t.set_font_size("font_size", "MenuRow", 24)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, "MenuRow", C.INK)
	t.set_color("font_disabled_color", "MenuRow", C.TEXT_DISABLED)
	var mr_m := Vector4(18, 12, 18, 12)
	var clear := Color(0, 0, 0, 0)
	t.set_stylebox("normal", "MenuRow", box({"fill": clear, "border_color": clear, "radius": 10.0}, mr_m))
	t.set_stylebox("hover", "MenuRow", box({"fill": CHALK_WASH, "border_color": clear, "radius": 10.0}, mr_m))
	t.set_stylebox("pressed", "MenuRow", box({"fill": C.GOLD_HOVER, "radius": 10.0}, mr_m))
	t.set_stylebox("hover_pressed", "MenuRow", box({"fill": C.GOLD_HOVER, "radius": 10.0}, mr_m))
	t.set_stylebox("disabled", "MenuRow", box({"fill": clear, "border_color": clear, "radius": 10.0}, mr_m))
	t.set_stylebox("focus", "MenuRow", box({"fill": C.GOLD, "radius": 10.0}, mr_m))
	t.set_constant("h_separation", "MenuRow", 8)

	# Version tag / language switch on the title screen (translucent chalk plate)
	t.set_type_variation("VersionButton", "Button")
	t.set_font("font", "VersionButton", f_bold)
	t.set_font_size("font_size", "VersionButton", 15)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, "VersionButton", C.INK)
	var vm := Vector4(10, 3, 10, 3)
	var plate := Color(0.984, 0.961, 0.902, 0.85)
	t.set_stylebox("normal", "VersionButton", box({"fill": plate, "border_width": 0.0, "radius": 6.0}, vm))
	t.set_stylebox("hover", "VersionButton", box({"fill": C.CHALK, "border_width": 0.0, "radius": 6.0}, vm))
	t.set_stylebox("pressed", "VersionButton", box({"fill": C.GOLD, "border_width": 0.0, "radius": 6.0}, vm))
	t.set_stylebox("hover_pressed", "VersionButton", box({"fill": C.GOLD, "border_width": 0.0, "radius": 6.0}, vm))
	t.set_stylebox("focus", "VersionButton", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 6.0}), vm))

	# Flat mono hint ("E for at fortsætte") that is also a clickable Next button
	t.set_type_variation("HintButton", "Button")
	t.set_font("font", "HintButton", f_mono)
	t.set_font_size("font_size", "HintButton", 11)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, "HintButton", C.TEXT_MONO)
	t.set_stylebox("normal", "HintButton", box({"fill": clear, "border_width": 0.0, "radius": 6.0}, Vector4(6, 2, 6, 2)))
	t.set_stylebox("hover", "HintButton", box({"fill": CHALK_WASH, "border_width": 0.0, "radius": 6.0}, Vector4(6, 2, 6, 2)))
	t.set_stylebox("pressed", "HintButton", box({"fill": C.GOLD, "border_width": 0.0, "radius": 6.0}, Vector4(6, 2, 6, 2)))
	t.set_stylebox("focus", "HintButton", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 6.0}), Vector4(6, 2, 6, 2)))
	t.set_color("icon_normal_color", "HintButton", C.TEXT_MONO)
	t.set_constant("h_separation", "HintButton", 6)
	t.set_constant("icon_max_width", "HintButton", 14)

	# Dialogue choice: a leading caret icon (transparent until hovered/focused)
	t.set_type_variation("ChoiceRow", "Button")
	t.set_font("font", "ChoiceRow", f_bold)
	t.set_font_size("font_size", "ChoiceRow", 18)
	t.set_color("font_color", "ChoiceRow", C.TEXT_MUTED)
	for k in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, "ChoiceRow", C.INK)
	var ch_m := Vector4(16, 8, 16, 8)
	t.set_stylebox("normal", "ChoiceRow", box({"fill": clear, "border_color": clear, "radius": 8.0}, ch_m))
	t.set_stylebox("hover", "ChoiceRow", box({"fill": CHALK_WASH, "border_color": clear, "radius": 8.0}, ch_m))
	t.set_stylebox("pressed", "ChoiceRow", box({"fill": C.GOLD_HOVER, "radius": 8.0}, ch_m))
	t.set_stylebox("hover_pressed", "ChoiceRow", box({"fill": C.GOLD_HOVER, "radius": 8.0}, ch_m))
	t.set_stylebox("focus", "ChoiceRow", box({"fill": C.GOLD, "radius": 8.0}, ch_m))
	t.set_color("icon_normal_color", "ChoiceRow", clear)
	t.set_color("icon_hover_color", "ChoiceRow", C.INK)
	t.set_color("icon_focus_color", "ChoiceRow", C.INK)
	t.set_color("icon_pressed_color", "ChoiceRow", C.INK)
	t.set_constant("h_separation", "ChoiceRow", 10)
	t.set_constant("icon_max_width", "ChoiceRow", 14)


# ------------------------------------------------------------------ pills, rows, slots, cards
func _pills_rows_slots() -> void:
	var clear := Color(0, 0, 0, 0)
	var rm_zero := Vector4(0, 0, 0, 0)

	# Tab pill (shop tabs, quest tabs): transparent, gold when active (toggle pressed)
	t.set_type_variation("PillTab", "Button")
	t.set_font("font", "PillTab", f_heavy)
	t.set_font_size("font_size", "PillTab", 16)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, "PillTab", C.INK)
	var pm := Vector4(16, 7, 16, 7)          # +2 px each side: the 2 px border is outside the guide's 5 px padding -> 33 px high (P28, 4.6 item 3b)
	t.set_stylebox("normal", "PillTab", box({"fill": clear, "radius": 999.0}, pm))
	t.set_stylebox("hover", "PillTab", box({"fill": C.CHALK, "radius": 999.0}, pm))
	t.set_stylebox("pressed", "PillTab", box({"fill": C.GOLD, "radius": 999.0}, pm))
	t.set_stylebox("hover_pressed", "PillTab", box({"fill": C.GOLD_HOVER, "radius": 999.0}, pm))
	t.set_stylebox("focus", "PillTab", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 999.0}), pm))

	# Species chip: cream, gold when selected
	t.set_type_variation("Chip", "PillTab")
	t.set_font_size("font_size", "Chip", 17)
	var cm := Vector4(18, 8, 18, 8)          # +2 px each side -> 37 px high
	t.set_stylebox("normal", "Chip", box({"fill": C.CHALK, "radius": 999.0}, cm))
	# Disabled chips keep their pill geometry; disabled text and the caller's dim remain intact.
	t.set_stylebox("disabled", "Chip", box({"fill": C.CHALK, "radius": 999.0}, cm))
	t.set_stylebox("hover", "Chip", box({"fill": Color("#fffdf6"), "radius": 999.0}, cm))      # a lighter face (idle is chalk already: a chalk wash would not show)
	t.set_stylebox("pressed", "Chip", box({"fill": C.GOLD, "radius": 999.0}, cm))
	t.set_stylebox("hover_pressed", "Chip", box({"fill": C.GOLD_HOVER, "radius": 999.0}, cm))
	t.set_stylebox("focus", "Chip", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 999.0}), cm))

	# List row (shop item, quest): divider border, selected = chalk + ink border. Children live in a child container.
	t.set_type_variation("RowButton", "Button")
	var rm := Vector4(0, 0, 0, 0)
	t.set_stylebox("normal", "RowButton", box({"fill": clear, "border_color": C.DIVIDER, "radius": 12.0}, rm))
	t.set_stylebox("hover", "RowButton", box({"fill": Color(0.984, 0.961, 0.902, 0.55), "border_color": C.DIVIDER, "radius": 12.0}, rm))
	t.set_stylebox("pressed", "RowButton", box({"fill": C.CHALK, "radius": 12.0}, rm))
	t.set_stylebox("hover_pressed", "RowButton", box({"fill": C.CHALK, "radius": 12.0}, rm))
	t.set_stylebox("disabled", "RowButton", box({"fill": clear, "border_color": C.DIVIDER, "radius": 12.0}, rm))
	t.set_stylebox("focus", "RowButton", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 12.0}), rm))

	# Race card (Vælg figur): parchment, 2px ink, r18; selected = sel ring
	t.set_type_variation("CardButton", "Button")
	t.set_stylebox("normal", "CardButton", box({"fill": C.PARCHMENT, "radius": 18.0}, rm))
	t.set_stylebox("hover", "CardButton", box({"fill": Color("#f8edd0"), "radius": 18.0}, rm))
	t.set_stylebox("pressed", "CardButton", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"fill": C.PARCHMENT, "radius": 18.0}), rm))
	t.set_stylebox("hover_pressed", "CardButton", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"fill": Color("#f8edd0"), "radius": 18.0}), rm))
	t.set_stylebox("focus", "CardButton", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 18.0}), rm))

	# Inventory / hotbar slots: Empty, Filled (= normal rarity) and one tile per rarity (fill + 3 px ring from Rarity.ui()).
	# Gold = focus only: the pressed (selected) state REPLACES the rarity ring by the selection ring, fill stays.
	var sel := rings(RING_SEL_COLORS, RING_SEL_W)
	var slot_focus := box(merge(sel, {"draw_body": false, "radius": 10.0}), rm)
	var kinds := {"Empty": "", "Filled": "normal", "Uncommon": "uncommon", "Rare": "rare", "Unique": "unique", "Legendary": "legendary"}
	for kind in kinds:
		var vn: String = "Slot" + kind
		t.set_type_variation(vn, "Button")
		var base: Dictionary = {"radius": 10.0}
		var hover_fill := Color("#fffdf6")
		var text_col := C.INK
		if kind == "Empty":
			base["fill"] = C.PARCHMENT_DARK
			base["band_side"] = BoxStyle.BandSide.TOP
			base["band_size"] = 3.0
			base["band_color"] = C.INK_SOFT_15
			hover_fill = Color("#f1e3bd")
		else:
			var ui: Dictionary = RarityTable.ui(kinds[kind])
			base["fill"] = ui["fill"]
			if bool(ui["has_ring"]):
				base.merge(rings([ui["ring"]], [float(ui["ring_w"])]), true)
			hover_fill = (ui["fill"] as Color).lerp(Color.WHITE, 0.35)
			if kind == "Filled":
				hover_fill = Color("#fffdf6")        # the guide's own hover fills of the two lifted tiles
			elif kind == "Rare":
				hover_fill = Color("#ece4f8")
			if bool(ui["night"]):
				hover_fill = (ui["fill"] as Color).lerp(Color.WHITE, 0.10)
				text_col = ui["icon_rim"]
		t.set_stylebox("normal", vn, box(base, rm))
		t.set_stylebox("hover", vn, box(merge(base, {"fill": hover_fill}), rm))
		var sel_base := merge(base, sel)
		t.set_stylebox("pressed", vn, box(sel_base, rm))
		t.set_stylebox("hover_pressed", vn, box(merge(sel_base, {"fill": hover_fill}), rm))
		t.set_stylebox("disabled", vn, box(base, rm))
		t.set_stylebox("focus", vn, slot_focus)
		t.set_font("font", vn, f_display)
		t.set_font_size("font_size", vn, 16)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
			t.set_color(k, vn, text_col)

	# Recipe row (workshop): like RowButton but tighter
	t.set_type_variation("RecipeRow", "RowButton")
	t.set_stylebox("pressed", "RecipeRow", box({"fill": C.CHALK, "radius": 10.0}, rm))
	t.set_stylebox("hover_pressed", "RecipeRow", box({"fill": C.CHALK, "radius": 10.0}, rm))
	t.set_stylebox("normal", "RecipeRow", box({"fill": clear, "border_color": C.DIVIDER, "radius": 10.0}, rm))
	t.set_stylebox("hover", "RecipeRow", box({"fill": Color(0.984, 0.961, 0.902, 0.55), "border_color": C.DIVIDER, "radius": 10.0}, rm))
	t.set_stylebox("focus", "RecipeRow", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 10.0}), rm))

	# Stepper cell: "−" and "+" (flat buttons inside PanelField)
	t.set_type_variation("StepperButton", "Button")
	t.set_font("font", "StepperButton", f_heavy)
	t.set_font_size("font_size", "StepperButton", 20)
	var sm := Vector4(12, 4, 12, 4)
	t.set_stylebox("normal", "StepperButton", box({"fill": clear, "radius": 8.0, "border_width": 0.0}, sm))
	t.set_stylebox("hover", "StepperButton", box({"fill": PARCHMENT_WASH, "radius": 8.0, "border_width": 0.0}, sm))
	t.set_stylebox("pressed", "StepperButton", box({"fill": C.GOLD_HOVER, "radius": 8.0, "border_width": 0.0}, sm))
	t.set_stylebox("hover_pressed", "StepperButton", box({"fill": C.GOLD_HOVER, "radius": 8.0, "border_width": 0.0}, sm))
	t.set_stylebox("disabled", "StepperButton", box({"fill": clear, "radius": 8.0, "border_width": 0.0}, sm))
	t.set_stylebox("focus", "StepperButton", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 8.0}), sm))
	t.set_color("font_disabled_color", "StepperButton", C.TEXT_DISABLED)

	# Round close "x"
	t.set_type_variation("CloseButton", "ButtonTertiary")
	t.set_font_size("font_size", "CloseButton", 20)
	t.set_stylebox("focus", "CloseButton", t.get_stylebox("focus", "ButtonTertiary"))     # every interactive type names its own focus ring (ui_conformance.theme_focus_styles)

	# Focus proxy (P28, UI_NAVIGATION.md 4.6 item 3): a Button that draws NOTHING in any state. A draw-only component (RaritySlot, LadderRow,
	# RarityPips) is wrapped in one so the keyboard can reach it; the wrapped component paints the ring from `selected = proxy.has_focus()`.
	t.set_type_variation("FocusProxy", "Button")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(st, "FocusProxy", StyleBoxEmpty.new())

	# Calendar day cells (RT10, the calendar tab of the quest book): the RowButton look with a parchment-dark fill; festival days lavender with an ink
	# border; today a 3 px ink border. No gold anywhere but the focus ring: today is ringed in INK, gold stays for focus (the guide's rule).
	# The idle cell is a ROW look like RowButton (2 px #cdb98f divider, the page shows through): its fill is parchment-dark at alpha .9, so it is a
	# translucent row and not an opaque light box (UiAudit R1 asks an ink outline of those only; the guide's own list rows carry the divider).
	var cal_idle_fill := Color(C.PARCHMENT_DARK, 0.9)
	var cal_focus := box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 10.0}), rm_zero)
	t.set_type_variation("CalCell", "Button")
	t.set_stylebox("normal", "CalCell", box({"fill": cal_idle_fill, "border_color": C.DIVIDER, "border_width": 2.0, "radius": 10.0}, rm_zero))
	t.set_stylebox("hover", "CalCell", box({"fill": C.PARCHMENT_DARK.lerp(C.CHALK, 0.55), "border_color": C.DIVIDER, "border_width": 2.0, "radius": 10.0}, rm_zero))
	t.set_stylebox("pressed", "CalCell", box({"fill": C.CHALK, "radius": 10.0}, rm_zero))
	t.set_stylebox("hover_pressed", "CalCell", box({"fill": C.CHALK, "radius": 10.0}, rm_zero))
	t.set_stylebox("disabled", "CalCell", box({"fill": cal_idle_fill, "border_color": C.DIVIDER, "border_width": 2.0, "radius": 10.0}, rm_zero))
	t.set_stylebox("focus", "CalCell", cal_focus)
	t.set_type_variation("CalCellFest", "Button")
	t.set_stylebox("normal", "CalCellFest", box({"fill": C.LAVENDER_PALE, "radius": 10.0}, rm_zero))
	t.set_stylebox("hover", "CalCellFest", box({"fill": C.LAVENDER_PALE2, "radius": 10.0}, rm_zero))
	t.set_stylebox("pressed", "CalCellFest", box({"fill": C.LAVENDER_PALE2, "radius": 10.0}, rm_zero))
	t.set_stylebox("hover_pressed", "CalCellFest", box({"fill": C.LAVENDER_PALE2, "radius": 10.0}, rm_zero))
	t.set_stylebox("disabled", "CalCellFest", box({"fill": C.LAVENDER_PALE, "radius": 10.0}, rm_zero))
	t.set_stylebox("focus", "CalCellFest", cal_focus)
	t.set_type_variation("CalCellToday", "Button")
	t.set_stylebox("normal", "CalCellToday", box({"fill": C.PARCHMENT_DARK, "border_width": 3.0, "radius": 10.0}, rm_zero))
	t.set_stylebox("hover", "CalCellToday", box({"fill": C.PARCHMENT_DARK.lerp(C.CHALK, 0.55), "border_width": 3.0, "radius": 10.0}, rm_zero))
	t.set_stylebox("pressed", "CalCellToday", box({"fill": C.CHALK, "border_width": 3.0, "radius": 10.0}, rm_zero))
	t.set_stylebox("hover_pressed", "CalCellToday", box({"fill": C.CHALK, "border_width": 3.0, "radius": 10.0}, rm_zero))
	t.set_stylebox("disabled", "CalCellToday", box({"fill": C.PARCHMENT_DARK, "border_width": 3.0, "radius": 10.0}, rm_zero))
	t.set_stylebox("focus", "CalCellToday", cal_focus)


# ------------------------------------------------------------------ meters
func _meter(vname: String, fill: Color, highlight: Color, vertical := false, radius := 10.0, track_fill := C.DISABLED_BG, track_border := true, extra_track: Dictionary = {}) -> void:
	if vname != "ProgressBar":
		t.set_type_variation(vname, "ProgressBar")
	var tr_props := {"fill": track_fill, "radius": radius, "border_width": 2.0 if track_border else 0.0}
	tr_props.merge(extra_track, true)
	t.set_stylebox("background", vname, box(tr_props))
	var inset := 2.0 if track_border else 0.0
	var fp := {"fill": fill, "border_width": 0.0, "radius": maxf(0.0, radius - inset), "body_inset": Vector4(inset, inset, inset, inset)}
	if highlight.a > 0.0:
		fp["band_side"] = BoxStyle.BandSide.LEFT if vertical else BoxStyle.BandSide.TOP
		fp["band_size"] = 4.0
		fp["band_color"] = highlight
	t.set_stylebox("fill", vname, box(fp))
	t.set_color("font_color", vname, C.INK)


func _meters() -> void:
	var white35 := Color(1, 1, 1, 0.35)
	var white30 := Color(1, 1, 1, 0.30)
	_meter("ProgressBar", C.MOSS, white35)
	_meter("MeterGreen", C.MOSS, white35)
	_meter("MeterRose", C.ROSE, white35)
	_meter("MeterHoney", C.HONEY, white35)
	_meter("MeterVertical", C.MOSS, white30, true, 15.0)
	_meter("MeterNight", C.OWL_EYE, Color(0, 0, 0, 0), false, 6.0, C.NIGHT_TRACK, true)
	_meter("MeterBoss", C.THORNBERRY, Color(0, 0, 0, 0), false, 8.0, C.NIGHT_TRACK, true,
		rings([C.GOLD], [2.0]))
	for n in ["ProgressBar", "MeterGreen", "MeterRose", "MeterHoney", "MeterVertical", "MeterNight", "MeterBoss"]:
		t.set_font_size("font_size", n, 12)
		t.set_constant("outline_size", n, 0)


# ------------------------------------------------------------------ inputs, scroll bars
func _inputs_misc() -> void:
	var le_m := Vector4(14, 8, 14, 8)
	t.set_stylebox("normal", "LineEdit", box({"fill": C.CHALK, "radius": 10.0}, le_m))
	t.set_stylebox("focus", "LineEdit", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"fill": C.CHALK, "radius": 10.0}), le_m))
	t.set_stylebox("read_only", "LineEdit", box({"fill": C.PARCHMENT_DARK, "radius": 10.0}, le_m))
	t.set_color("font_color", "LineEdit", C.INK)
	t.set_color("font_placeholder_color", "LineEdit", C.TEXT_DISABLED)
	t.set_color("caret_color", "LineEdit", C.INK)
	t.set_color("selection_color", "LineEdit", Color(C.GOLD, 0.6))
	t.set_font("font", "LineEdit", f_bold)
	t.set_font_size("font_size", "LineEdit", 20)
	t.set_constant("caret_width", "LineEdit", 2)

	# OptionButton looks like a tertiary button
	t.set_type_variation("OptionButtonTT", "OptionButton")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(st, "OptionButton", t.get_stylebox(st, "Button"))
	t.set_stylebox("focus", "OptionButtonTT", t.get_stylebox("focus", "Button"))
	t.set_font("font", "OptionButton", f_display)
	t.set_font_size("font_size", "OptionButton", 20)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, "OptionButton", C.INK)

	# Sliders (settings), UI_NAVIGATION.md 4.6 item 2: the inked track, a MOSS fill with the 4 px highlight band (the Energi meter: gold is for focus / selected
	# only), a chalk grabber disc with an ink outline. Godot's Slider never draws a theme `focus` StyleBox: HSlider/focus below is the ring that TTSlider
	# (scripts/ui/components/tt_slider.gd) paints itself while it has focus. center_grabber = 0 keeps the grabber INSIDE the control rect, so the ring hugs the slider.
	var trk := box({"fill": C.DISABLED_BG, "radius": 8.0}, Vector4(0, 8, 0, 8))   # content margins give the track its 16 px height
	t.set_stylebox("slider", "HSlider", trk)
	var fill := box({"fill": C.MOSS, "border_width": 0.0, "radius": 6.0, "body_inset": Vector4(2, 2, 2, 2),
		"band_side": BoxStyle.BandSide.TOP, "band_size": 4.0, "band_color": Color(1, 1, 1, 0.35)}, Vector4(0, 8, 0, 8))
	var fill_hi := box({"fill": C.MOSS_HOVER, "border_width": 0.0, "radius": 6.0, "body_inset": Vector4(2, 2, 2, 2),
		"band_side": BoxStyle.BandSide.TOP, "band_size": 4.0, "band_color": Color(1, 1, 1, 0.35)}, Vector4(0, 8, 0, 8))
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	t.set_stylebox("focus", "HSlider", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 999.0})))
	t.set_icon("grabber", "HSlider", load("res://assets/ui/icons/slider_grabber.svg"))
	t.set_icon("grabber_highlight", "HSlider", load("res://assets/ui/icons/slider_grabber_hi.svg"))
	t.set_icon("grabber_disabled", "HSlider", load("res://assets/ui/icons/slider_grabber.svg"))
	t.set_constant("center_grabber", "HSlider", 0)
	t.set_constant("grabber_offset", "HSlider", 0)
	t.set_stylebox("slider", "HSlider", trk)
	# Check boxes (full-screen toggle): ink-outlined square, moss when on
	t.set_icon("checked", "CheckBox", load("res://assets/ui/icons/tick_on.svg"))
	t.set_icon("unchecked", "CheckBox", load("res://assets/ui/icons/tick_off.svg"))
	t.set_icon("checked_disabled", "CheckBox", load("res://assets/ui/icons/tick_on.svg"))
	t.set_icon("unchecked_disabled", "CheckBox", load("res://assets/ui/icons/tick_off.svg"))
	t.set_font("font", "CheckBox", f_heavy)
	t.set_font_size("font_size", "CheckBox", 19)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, "CheckBox", C.INK)
	t.set_constant("h_separation", "CheckBox", 12)
	for st in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckBox", box({"fill": Color(0, 0, 0, 0), "border_width": 0.0, "radius": 8.0}, Vector4(6, 4, 6, 4)))
	t.set_stylebox("focus", "CheckBox", box(merge(rings(RING_SEL_COLORS, RING_SEL_W), {"draw_body": false, "radius": 8.0}), Vector4(6, 4, 6, 4)))

	# Modal windows (ConfirmationDialog in save/load). Embedded window chrome (title bar, close x) is NOT themeable
	# enough, so dialogs are created borderless (dialog.borderless = true) and the AcceptDialog panel carries the look.
	# The ring must fit INSIDE the window rect (the window clips), hence body_inset = ring width (4 + 2).
	t.set_stylebox("panel", "AcceptDialog", box(merge(rings(RING_PANEL_COLORS, RING_PANEL_W), {"radius": 16.0, "body_inset": Vector4(6, 6, 6, 6)}), Vector4(30, 26, 30, 26)))
	t.set_font("title_font", "Window", f_display)
	t.set_font_size("title_font_size", "Window", 22)
	t.set_color("title_color", "Window", C.INK)
	t.set_font("font", "AcceptDialog", f_body)
	t.set_font_size("font_size", "AcceptDialog", 20)

	# Scrollbars: slim parchment track, a divider-coloured thumb with a 2 px ink outline (hover chalk, pressed moss): gold is for focus / selected only
	for tn in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", tn, box({"fill": Color(0.804, 0.725, 0.561, 0.45), "border_width": 0.0, "radius": 6.0}, Vector4(0, 0, 0, 0)))
		t.set_stylebox("scroll_focus", tn, box({"fill": Color(0.804, 0.725, 0.561, 0.45), "border_width": 0.0, "radius": 6.0}))
		t.set_stylebox("grabber", tn, box({"fill": C.DIVIDER, "radius": 6.0}, Vector4(6, 6, 6, 6)))
		t.set_stylebox("grabber_highlight", tn, box({"fill": C.CHALK, "radius": 6.0}, Vector4(6, 6, 6, 6)))
		t.set_stylebox("grabber_pressed", tn, box({"fill": C.MOSS_HOVER, "radius": 6.0}, Vector4(6, 6, 6, 6)))
	t.set_constant("scrollbar_margin_top", "ScrollContainer", 0)
