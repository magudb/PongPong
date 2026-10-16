extends Node
## Owner compiler; the older style-guide builders remain immutable references.
const Kit := preload("res://tools/ui/scene_kit.gd")
const C := preload("res://scripts/ui/theme/tt_colors.gd")
func run() -> void:
	_banner()
	_hud()
	get_tree().quit()

func _theme() -> Theme:
	var theme := Theme.new()
	var base := load("res://assets/ui/theme.tres") as Theme
	theme.set_type_variation("HudDateLine", "Label")
	theme.set_font("font", "HudDateLine", load("res://assets/fonts/IBMPlexMono-Regular.ttf"))
	theme.set_font_size("font_size", "HudDateLine", 14)
	theme.set_color("font_color", "HudDateLine", C.TEXT_MUTED)
	theme.set_font("font", "HotkeyDigit", load("res://assets/fonts/IBMPlexMono-Regular.ttf"))
	theme.set_type_variation("HotkeyDigit", "Label")
	theme.set_font_size("font_size", "HotkeyDigit", 10)
	theme.set_color("font_color", "HotkeyDigit", C.TEXT_MONO)
	for variation in ["SlotEmpty", "SlotFilled"]:
		for state in ["normal", "disabled"]:
			var style := base.get_stylebox(state, variation).duplicate(false) as TTBoxStyle
			style.fill = Color("efe0bb")
			theme.set_stylebox(state, variation, style)
	theme.set_type_variation("HudEnergyTag", "Label")
	theme.set_font("font", "HudEnergyTag", base.get_font("font", "Heavy14"))
	theme.set_color("font_color", "HudEnergyTag", C.INK)
	theme.set_font_size("font_size", "HudEnergyTag", 15)
	for spec in [["AreaTitle", "Display30"], ["LandmarkTitle", "Display22"]]:
		theme.set_type_variation(spec[0], "Label")
		theme.set_font("font", spec[0], base.get_font("font", spec[1]))
		theme.set_font_size("font_size", spec[0], base.get_font_size("font_size", spec[1]))
		theme.set_color("font_color", spec[0], Color("fffdf6"))
		theme.set_color("font_outline_color", spec[0], C.INK)
		theme.set_constant("outline_size", spec[0], 10) # Calibrated to the mock's visible 3px stroke in native Godot captures.
	return theme

func _box(fill: Color, border: Color, radius: float, margins: Vector4) -> TTBoxStyle:
	var box := TTBoxStyle.new()
	box.fill = fill
	box.border_color = border
	box.radius = radius
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	return box

func _frame(k, parent: Node, name: String, margins: Vector4) -> PanelContainer:
	var panel: PanelContainer = k.panel(parent, name, "", {}, true)
	panel.add_theme_stylebox_override("panel", _box(C.PARCHMENT, C.INK, 12, Vector4(5, 5, 5, 5)))
	var inner: PanelContainer = k.panel(panel, "Keyline", "", {"ignore": true})
	inner.set_meta("tt_r1_ok", "Miljøer v2 inner gold keyline, enclosed by the parent's 2px ink outline")
	inner.set_meta("tt_gold_ok", "Miljøer v2 explicitly specifies a 2px inset gold keyline")
	inner.add_theme_stylebox_override("panel", _box(C.PARCHMENT, C.GOLD, 8, margins))
	return inner

func _banner() -> void:
	var k = Kit.new()
	var r = k.begin("Control", "AreaBanner", "res://scripts/ui/components/area_banner.gd")
	k.full(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.theme = _theme()
	var body = k.vbox(r, "Body", 5, {"ignore": true})
	k.pin(body, "tc", 0, 24)
	k.lbl(body, "Title", "", "AreaTitle", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	k.lbl(body, "Landmark", "", "LandmarkTitle", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	k.save("res://scenes/ui/components/area_banner.tscn")

func _hud() -> void:
	var k = Kit.new()
	var root = k.begin("Control", "HUD", "res://scripts/ui/hud.gd")
	k.full(root)
	root.theme = _theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var date = _frame(k, root, "DatePanel", Vector4(16, 7, 16, 7))
	root.get_node("DatePanel").custom_minimum_size.x = 252
	k.pin(root.get_node("DatePanel"), "tl", 40, 40)
	var dv = k.vbox(date, "DateBody", 2, {"ignore": true})
	k.lbl(dv, "DayLabel", "", "Display22", {"ignore": true}, true)
	k.lbl(dv, "TimeLabel", "", "HudDateLine", {"ignore": true}, true)
	var right = k.vbox(root, "TopRight", 12, {"ignore": true})
	k.pin(right, "tr", 40, 40)
	var chip = _frame(k, right, "MoneyChip", Vector4(15, 9, 15, 9))
	right.get_node("MoneyChip").size_flags_horizontal = Control.SIZE_SHRINK_END
	var money = k.hbox(chip, "MoneyRow", 16, {"ignore": true})
	var gold = k.hbox(money, "Gold", 8, {"ignore": true})
	var coin = k.coin(gold, "Coin", true)
	coin.custom_minimum_size = Vector2(18, 18)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var amount = k.lbl(gold, "GoldLabel", "", "Heavy19", {"ignore": true, "shrink_center_v": true}, true)
	amount.custom_minimum_size.x = 42
	amount.set_meta("tt_r3_ok", "Miljøer v2 money chip explicitly uses the 19px heavy face")
	var energy = k.hbox(money, "Energy", 8, {"ignore": true})
	k.lbl(energy, "StaminaTag", "HUD_ENERGY", "HudEnergyTag", {"ignore": true, "shrink_center_v": true}, true)
	var stamina = k.add(energy, "ProgressBar", "StaminaBar", {"min": Vector2(110, 14), "show_percentage": false, "value": 100, "ignore": true, "shrink_center_v": true}, true)
	stamina.add_theme_stylebox_override("background", _box(Color("fffdf6"), C.INK, 7, Vector4.ZERO))
	var fill := _box(C.MOSS, Color.TRANSPARENT, 5, Vector4.ZERO)
	fill.border_width = 0
	fill.body_inset = Vector4(2, 2, 2, 2)
	stamina.add_theme_stylebox_override("fill", fill)
	k.add(right, "Control", "Hearts", {"script": "res://scripts/ui/components/tt_hearts.gd", "half_hearts": 10, "heart_size": Vector2(22, 20), "shrink_end_h": true, "ignore": true}, true)
	var qc = k.panel(right, "QuestCard", "PanelCard", {"min": Vector2(300, 0)}, true)
	var qv = k.vbox(qc, "QuestBody", 8, {"ignore": true})
	k.lbl(qv, "QuestHeader", "HUD_ACTIVE_QUESTS", "Eyebrow", {"ignore": true})
	k.vbox(qv, "QuestTracker", 8, {"ignore": true}, true)
	var construction = k.panel(root, "ConstructionChip", "PillGold", {}, true)
	k.pin(construction, "tl", 40, 140)
	k.lbl(construction, "ConstructionText", "", "Bold15Gold", {"ignore": true}, true)
	var inner = _frame(k, root, "HotbarTray", Vector4(7, 7, 7, 7))
	k.pin(root.get_node("HotbarTray"), "bc", 0, 30)
	var bar = k.hbox(inner, "Hotbar", 8, {}, true)
	var selected := _box(Color("fffdf6"), C.GOLD, 10, Vector4.ZERO)
	selected.border_width = 3
	selected.ring_colors = PackedColorArray([C.INK])
	selected.ring_widths = PackedFloat32Array([2.0])
	for i in 8:
		var slot = k.inst(bar, "res://scenes/ui/components/item_slot.tscn", "Slot%d" % (i + 1), {"focus_mode": Control.FOCUS_NONE})
		slot.set_meta("tt_r1_ok", "Miljøer v2 selected slot: 3px gold border enclosed by 2px ink ring")
		slot.add_theme_stylebox_override("pressed", selected)
		slot.add_theme_stylebox_override("hover_pressed", selected)
		# Reserve room for the digit/count; preserve the painted item's aspect.
		var icon: Control = slot.get_node("Icon")
		icon.offset_left = 9
		icon.offset_right = -9
		icon.offset_top = 9
		icon.offset_bottom = -9
	var tool = k.lbl(root, "ToolNameLabel", "", "ToolName", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	k.pin(tool, "bc", 0, 126)
	for spec in [["PromptPill", "prompt_pill"], ["WhisperLine", "whisper_line"], ["AreaBanner", "area_banner"], ["ToastStack", "toast_stack"]]:
		var c = k.inst(root, "res://scenes/ui/components/" + spec[1] + ".tscn", spec[0], {}, true)
		k.full(c)
		if spec[0] == "ToastStack":
			c.fifo = true
			c.max_visible = 4
			c.farm_only = true
	k.save("res://scenes/ui/hud.tscn")
