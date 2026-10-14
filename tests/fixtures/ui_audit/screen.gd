extends Control
## Fixture screen of the UI audit section (tests/sections/ui_audit.gd): a menu-like screen built from the project theme and the real
## components, plus ONE planted defect chosen by `defect` (set it before add_child). defect "" is the conforming screen: every check of
## UiAudit must pass on it. `layout` picks the shape: menu | wrap_menu (wrap-around through focus_neighbor paths: a held key wraps too) |
## wrap_smart (wrap-around that a held key does not cross) | grid | tabs | hud | settings (check box, chips, sliders) | components (the real components) | list.
##
## THE TEXT-FIELD IDIOM (see _on_field_input): a LineEdit eats the arrow keys it gets from a real keyboard (ui_up / ui_down move the caret), so a
## player who typed a name could not leave the field with the arrow keys. A screen with a text field connects gui_input and moves focus itself.
##
## Texts are translation keys of localization/ui.csv (INV_TITLE, MENU_CONTINUE ...). The one live label, `Count`, re-labels itself on
## NOTIFICATION_TRANSLATION_CHANGED like a real screen must. Nothing in this file is a hard-coded literal assignment (the static copy scan
## reads this file); the hard-coded copy fixtures are bad_literal.tscn and bad_literal_script.gd.
##
## Planted defects (each is proven reported by the matching UiAudit check):
##   focus:   slider_no_ring (a plain HSlider), field_traps (the text field without the idiom), nothing_focusable, unfocusable_button, click_only, no_focus_style, focus_blue, no_initial_focus, initial_disabled, trap, focus_lost, tab_only,
##            window_option (settings layout: a drop-down), pad_eats, hover_grab, click_drops, custom_no_ring (components layout: a custom focusable row that never paints its ring), slider_eats, tab_eats, tab_bar_unfocusable, accept_eats, wrong_way, history, field_dead, hotkey_leak, mouse_only
##   hud:     hud_focus, hud_blocks
##   rules:   gold_decoration, red_label, number_body, no_outline, small_display, small_body, raw_key, hit_small, literal_flip, stale_label

const C = preload("res://scripts/ui/theme/tt_colors.gd")
const KeyHook = preload("res://tests/fixtures/ui_audit/key_hook.gd")
const HotkeyLeaker = preload("res://tests/fixtures/ui_audit/hotkey_leaker.gd")
const RingSlider = preload("res://tests/fixtures/ui_audit/ring_slider.gd")
const CustomFocus = preload("res://tests/fixtures/ui_audit/custom_focus.gd")
const Plants = preload("res://tests/fixtures/ui_audit/plants.gd")
const STEPPER := preload("res://scenes/ui/components/quantity_stepper.tscn")
const ABILITY := preload("res://scenes/ui/components/ability_slot.tscn")
const TOAST := preload("res://scenes/ui/components/notification_toast.tscn")
const HEARTS := preload("res://scripts/ui/components/tt_hearts.gd")
const ITEM_SLOT := preload("res://scenes/ui/components/item_slot.tscn")

var defect := ""
var layout := "menu"

var panel: PanelContainer
var vbox: VBoxContainer
var title: Label
var money: Label
var count_label: Label
var dynamic: Label
var buttons: Array[Button] = []
var field: LineEdit
var slider: HSlider
var tabs: TabContainer
var slots: Array = []
var check_box: CheckBox
var options: OptionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	match layout:
		"grid":
			_build_grid()
		"tabs":
			_build_tabs()
		"settings":
			_build_settings()
		"wrap_smart":
			_build_menu()
		"components":
			_build_components()
		"list":
			_build_list()
		"hud":
			_build_hud()
		"radio_tabs":
			_build_radio_tabs()
		_:
			_build_menu()
	_apply_defect()
	_refresh()
	var first := _first_focus()
	if first != null and defect != "no_initial_focus" and first.focus_mode == Control.FOCUS_ALL:
		first.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and defect != "stale_label":
		_refresh()


func _refresh() -> void:
	if dynamic != null:
		dynamic.text = tr("QJ_TAB_ACTIVE") % 3


func _first_focus() -> Control:
	if layout == "tabs":
		return (tabs.get_child(0).get_child(0) as Control) if tabs != null else null
	if layout == "settings":
		return check_box
	if layout == "components":
		return slots[0] if not slots.is_empty() else null
	if layout == "list" or layout == "radio_tabs":
		return buttons[0]
	if layout == "grid":
		return slots[0] if not slots.is_empty() else null
	if layout == "hud":
		return null
	return buttons[0] if not buttons.is_empty() else null


# ---------------------------------------------------------------------------------------------------- builders

func _label(key: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = key
	l.theme_type_variation = variation
	return l


func _button(key: String, variation: StringName) -> Button:
	var b := Button.new()
	b.text = key
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, 52)
	return b


func _panel(pos: Vector2, width: float) -> VBoxContainer:
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"PanelParchment"
	panel.position = pos
	panel.custom_minimum_size = Vector2(width, 0)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	return vbox


func _build_menu() -> void:
	var box := _panel(Vector2(380, 24), 520)
	title = _label("INV_TITLE", &"Display28")
	title.name = "Title"
	box.add_child(title)
	money = _label("1.250", &"MoneyDark")
	money.name = "Money"
	box.add_child(money)
	var counts := _label("18 / 24", &"Display22")
	counts.name = "Capacity"
	box.add_child(counts)
	dynamic = _label("QJ_TAB_ACTIVE", &"Body")
	dynamic.name = "Count"
	box.add_child(dynamic)
	count_label = dynamic
	var specs := [["MENU_CONTINUE", &"ButtonPrimary"], ["MENU_SETTINGS", &"ButtonSecondary"], ["MENU_QUIT", &"ButtonTertiary"]]
	for s in specs:
		var b := _button(s[0], s[1])
		b.name = "Button%d" % (buttons.size() + 1)
		box.add_child(b)
		buttons.append(b)
	field = LineEdit.new()
	field.name = "Name"
	field.placeholder_text = "CHAR_NAME_CAPTION"
	field.custom_minimum_size = Vector2(0, 48)
	if defect != "field_traps":
		field.gui_input.connect(_on_field_input)
	box.add_child(field)
	slider = _slider("Volume")
	slider.name = "Volume"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 10
	slider.value = 50
	slider.custom_minimum_size = Vector2(0, 48)
	box.add_child(slider)
	var done := _button("SET_DONE", &"ButtonTertiary")
	done.name = "Button4"
	box.add_child(done)
	buttons.append(done)
	if layout == "wrap_menu":
		buttons[0].focus_neighbor_top = buttons[0].get_path_to(buttons[3])
		buttons[3].focus_neighbor_bottom = buttons[3].get_path_to(buttons[0])
	elif layout == "wrap_smart":
		buttons[0].set_script(KeyHook)
		buttons[0].set("mode", "wrap_up")
		buttons[0].set("targets", [buttons[0].get_path_to(buttons[3])])
		buttons[3].set_script(KeyHook)
		buttons[3].set("mode", "wrap_down")
		buttons[3].set("targets", [buttons[3].get_path_to(buttons[0])])
		# the text field and the slider sit between the buttons: their vertical neighbours are the geometric ones


## The spec's pattern T: three PillTab toggle buttons in a ButtonGroup (a shop's tabs) and the page behind each one (two RowButtons); selecting a tab swaps the page. Moving focus onto a
## tab selects it (select-on-focus), Down from a tab enters its page, Up from the page's first row returns to the tab. Planted: radio_page_defects (the second page holds an
## unfocusable button, a red label and a gold stripe - invisible while the first tab is open), radio_select_dead (the third tab ignores ui_accept, so its page cannot be opened).
var pages: Array[VBoxContainer] = []
var tab_buttons: Array[Button] = []


func _build_radio_tabs() -> void:
	var box := _panel(Vector2(300, 30), 640)
	title = _label("INV_TITLE", &"Display28")
	box.add_child(title)
	var tab_row := HBoxContainer.new()
	tab_row.name = "TabRow"
	box.add_child(tab_row)
	var group := ButtonGroup.new()
	for i in 3:
		var tb := Button.new()
		tb.name = "Tab%d" % i
		tb.text = ["SHOP_TAB_SEEDS", "SHOP_TAB_TOOLS", "SHOP_TAB_GOODS"][i]
		tb.theme_type_variation = &"PillTab"
		tb.toggle_mode = true
		tb.button_group = group
		tb.custom_minimum_size = Vector2(120, 36)
		tab_row.add_child(tb)
		tab_buttons.append(tb)
		buttons.append(tb)
	for i in 3:
		var page := VBoxContainer.new()
		page.name = "Page%d" % i
		box.add_child(page)
		pages.append(page)
		for j in 2:
			var b := Button.new()
			b.name = "P%dB%d" % [i, j]
			b.text = "MENU_CONTINUE" if j == 0 else "MENU_QUIT"
			b.theme_type_variation = &"RowButton"
			b.custom_minimum_size = Vector2(0, 52)
			page.add_child(b)
		page.visible = i == 0
		var idx := i
		if not (defect == "radio_select_dead" and i == 2):                   # (the dead tab neither selects on focus nor on accept)
			tab_buttons[i].focus_entered.connect(func() -> void: _show_tab(idx))
		tab_buttons[i].toggled.connect(func(on: bool) -> void:
			if on:
				_show_tab(idx))
		tab_buttons[i].focus_neighbor_bottom = tab_buttons[i].get_path_to(page.get_node("P%dB0" % i))
		page.get_node("P%dB0" % i).focus_neighbor_top = page.get_node("P%dB0" % i).get_path_to(tab_buttons[i])
	tab_buttons[0].button_pressed = true


func _show_tab(idx: int) -> void:
	tab_buttons[idx].button_pressed = true
	for k in pages.size():
		pages[k].visible = k == idx


## A slider that shows the focus ring (a plain HSlider draws none: defect "slider_no_ring").
func _slider(nm: String) -> HSlider:
	var sl: HSlider = HSlider.new() if defect == "slider_no_ring" else RingSlider.new()
	sl.name = nm
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 10
	sl.value = 50
	sl.custom_minimum_size = Vector2(0, 48)
	return sl


## The idiom: the arrow keys the LineEdit would eat move focus to the neighbour instead (Enter / ui_accept would do the same for "next field").
func _on_field_input(event: InputEvent) -> void:
	if event.is_pressed() and (event.is_action("ui_down") or event.is_action("ui_up")):
		var nxt := field.find_valid_focus_neighbor(SIDE_BOTTOM if event.is_action("ui_down") else SIDE_TOP)
		if nxt != null:
			nxt.grab_focus()
			field.accept_event()


func _build_settings() -> void:
	var box := _panel(Vector2(380, 40), 520)
	title = _label("MENU_SETTINGS", &"Display28")
	box.add_child(title)
	check_box = CheckBox.new()
	check_box.name = "Fullscreen"
	check_box.text = "SET_FULLSCREEN"
	check_box.custom_minimum_size = Vector2(0, 48)
	box.add_child(check_box)
	if defect == "window_option":
		options = Plants.window_option(box)                    # a drop-down: its popup is a Window (banned in game screens)
	else:
		var chips := HBoxContainer.new()                       # window-size chips instead (the guide's pill language, one is selected)
		chips.name = "WindowSizes"
		chips.add_theme_constant_override("separation", 8)
		var group := ButtonGroup.new()
		for txt in ["1280 x 720", "1600 x 900", "1920 x 1080"]:
			var chip := Button.new()
			chip.text = txt
			chip.toggle_mode = true
			chip.button_group = group
			chip.button_pressed = txt == "1280 x 720"
			chip.theme_type_variation = &"Chip"
			chip.custom_minimum_size = Vector2(130, 36)
			chips.add_child(chip)
		box.add_child(chips)
	for spec in [["SET_MASTER", "Master"], ["SET_MUSIC", "Music"]]:
		var l := _label(spec[0], &"Body")
		box.add_child(l)
		var sl := _slider(spec[1])
		box.add_child(sl)
		if slider == null:
			slider = sl
	var done := _button("SET_DONE", &"ButtonPrimary")
	done.name = "Done"
	box.add_child(done)
	buttons.append(done)


## The real components of scripts/ui/components in one screen (HUD-like pieces, a stepper, slots, a custom focusable row): no rule may fire on any of them.
func _build_components() -> void:
	var box := _panel(Vector2(30, 14), 820)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 12)
	box.add_child(money_row)
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"PillGold"
	var pill_row := HBoxContainer.new()
	pill.add_child(pill_row)
	pill_row.add_child(_label("1.250", &"MoneyPill"))
	pill_row.add_child(_label("UI_CURRENCY", &"Bold15Gold"))
	money_row.add_child(pill)
	money_row.add_child(_label("HUD_ENERGY", &"NamePlate"))
	money_row.add_child(_label("MENU_VERSION_TAG", &"Tagline"))
	money_row.add_child(_label("E", &"KeyCap"))
	var rarity_row := HBoxContainer.new()
	box.add_child(rarity_row)
	for id in Rarity.IDS:
		var rs := RaritySlot.new()
		rs.rarity = id
		rs.item_id = &"carrot"
		rs.selected = id == &"rare"
		rarity_row.add_child(rs)
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 8)
	box.add_child(slot_row)
	for i in 3:
		var sl: Button = ITEM_SLOT.instantiate()
		sl.custom_minimum_size = Vector2(72, 72)
		slot_row.add_child(sl)
		sl.setup(&"carrot", i + 1, str(i + 1), false, "", Rarity.IDS[i])
		slots.append(sl)
	var stepper: PanelContainer = STEPPER.instantiate()
	slot_row.add_child(stepper)
	stepper.get_node("%MinusButton").focus_mode = Control.FOCUS_NONE        # at its minimum the "-" is disabled: a disabled control is not a focus stop
	for ab in [[&"slash", &"attack", 78.0], [&"dodge", &"dodge", 64.0]]:
		var a: VBoxContainer = ABILITY.instantiate()
		a.setup(ab[0], ab[1], ab[2])
		slot_row.add_child(a)
	var hearts := Control.new()
	hearts.set_script(HEARTS)
	hearts.custom_minimum_size = Vector2(170, 30)
	box.add_child(hearts)
	for v in [["MeterGreen", 70.0], ["MeterRose", 60.0], ["MeterHoney", 45.0]]:
		var bar := ProgressBar.new()
		bar.theme_type_variation = StringName(v[0])
		bar.value = v[1]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 14)
		box.add_child(bar)
	var toast: PanelContainer = TOAST.instantiate()
	toast.setup("NOTIF_QUEST_ACCEPTED_TITLE", "", 600.0)
	box.add_child(toast)
	for i in 2:
		var lr := LadderRow.new()
		lr.number = i + 1
		lr.title = tr("GALLERY_LADDER_1")
		lr.chip = tr("GALLERY_CHIP_LOCKED")
		lr.state = &"done" if i == 0 else &"next"
		box.add_child(lr)
	var focus_row := CustomFocus.new()
	focus_row.name = "FocusRow"
	focus_row.draw_ring = defect != "custom_no_ring"
	box.add_child(focus_row)
	slots.append(focus_row)


## Twelve rows in one column (a long list: the replay of the recorded keys is longer than the probes).
func _build_list() -> void:
	var box := _panel(Vector2(380, 8), 520)
	box.add_theme_constant_override("separation", 6)
	for i in 12:
		var b := _button("MENU_CONTINUE", &"ButtonTertiary")
		b.custom_minimum_size = Vector2(0, 44)
		b.name = "Row%d" % i
		box.add_child(b)
		buttons.append(b)


func _build_grid() -> void:
	var box := _panel(Vector2(300, 40), 640)
	title = _label("INV_TITLE", &"Display28")
	box.add_child(title)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var ids: Array[StringName] = [&"carrot", &"moonstone", &"hoe", &"", &"carrot", &"", &"hoe", &"moonstone", &"", &"carrot", &"hoe", &""]
	for i in 12:
		var s: Button = ITEM_SLOT.instantiate()
		s.name = "Slot%d" % i
		s.custom_minimum_size = Vector2(72, 72)
		grid.add_child(s)
		s.setup(ids[i], 0 if ids[i] == &"" else i + 1)
		slots.append(s)


func _build_tabs() -> void:
	tabs = TabContainer.new()
	tabs.name = "Tabs"
	tabs.position = Vector2(300, 100)
	tabs.custom_minimum_size = Vector2(600, 320)
	add_child(tabs)
	for page in ["A", "B"]:
		var v := VBoxContainer.new()
		v.name = "Page" + page
		tabs.add_child(v)
		for i in 2:
			var b := _button("MENU_CONTINUE" if i == 0 else "MENU_QUIT", &"ButtonTertiary")
			b.name = "%s%d" % [page, i + 1]
			v.add_child(b)
			buttons.append(b)
	tabs.set_tab_title(0, "SHOP_TAB_SEEDS")
	tabs.set_tab_title(1, "SHOP_TAB_TOOLS")


func _build_hud() -> void:
	if defect != "hud_blocks":
		mouse_filter = Control.MOUSE_FILTER_IGNORE                 # the full-screen HUD root must let clicks through to the world
	var box := _panel(Vector2(24, 24), 360)
	money = _label("1.250", &"MoneyDark")
	box.add_child(money)
	var row := HBoxContainer.new()
	row.name = "Hotbar"
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for i in 4:
		var s: Button = ITEM_SLOT.instantiate()
		s.name = "Hot%d" % i
		s.custom_minimum_size = Vector2(58, 58)
		row.add_child(s)
		s.setup(&"carrot", i + 1, str(i + 1))
		slots.append(s)
	for n in find_children("*", "Control", true, false):
		(n as Control).focus_mode = Control.FOCUS_NONE
	focus_mode = Control.FOCUS_NONE


# ---------------------------------------------------------------------------------------------------- planted defects

func _apply_defect() -> void:
	match defect:
		"nothing_focusable":
			for n in find_children("*", "Control", true, false):
				(n as Control).focus_mode = Control.FOCUS_NONE
		"unfocusable_button":
			buttons[1].focus_mode = Control.FOCUS_NONE
		"click_only":
			buttons[1].focus_mode = Control.FOCUS_CLICK
		"no_focus_style":
			for b in buttons:
				b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		"focus_blue":
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.set_border_width_all(3)
			sb.border_color = Color("#3b6fd6")
			buttons[0].add_theme_stylebox_override("focus", sb)
		"initial_disabled":
			buttons[0].disabled = true
		"trap":
			var me := buttons[1]
			me.focus_neighbor_left = NodePath(".")
			me.focus_neighbor_right = NodePath(".")
			me.focus_neighbor_top = NodePath(".")
			me.focus_neighbor_bottom = NodePath(".")
		"focus_lost":
			buttons[1].set_script(KeyHook)
			buttons[1].set("mode", "release_down")
		"tab_only":
			# nothing points at Button3 with a directional key: Button2 skips it, the field's way up skips it
			buttons[1].focus_neighbor_bottom = buttons[1].get_path_to(field)
			field.focus_neighbor_top = field.get_path_to(buttons[1])
		"slider_eats":
			slider.set_script(KeyHook)
			slider.set("mode", "eat_lr")
		"tab_eats":
			var bar := tabs.get_tab_bar()
			bar.set_script(KeyHook)
			bar.set("mode", "eat_lr")
		"tab_bar_unfocusable":
			tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE
		"wrong_way":
			buttons[1].focus_neighbor_bottom = buttons[1].get_path_to(buttons[0])
		"history":
			buttons[1].set_script(KeyHook)
			buttons[1].set("mode", "toggle_down")
			buttons[1].set("targets", [buttons[1].get_path_to(buttons[2]), buttons[1].get_path_to(field)])
		"field_dead":
			field.set_script(KeyHook)
			field.set("mode", "eat_keys")
		"hotkey_leak":
			add_child(HotkeyLeaker.new())
		"accept_eats":
			buttons[1].set_script(KeyHook)
			buttons[1].set("mode", "eat_accept")
		"hover_grab":
			buttons[1].set_script(KeyHook)
			buttons[1].set("mode", "hover_grab")
		"click_drops":
			buttons[0].set_script(KeyHook)
			buttons[0].set("mode", "click_drops")
		"pad_eats":
			buttons[1].set_script(KeyHook)
			buttons[1].set("mode", "eat_pad")
		"mouse_only":
			var p := Panel.new()
			p.name = "ClickMe"
			p.custom_minimum_size = Vector2(200, 48)
			p.set_script(KeyHook)
			p.set("mode", "click")
			p.mouse_filter = Control.MOUSE_FILTER_STOP
			vbox.add_child(p)
		"hud_focus":
			slots[2].focus_mode = Control.FOCUS_ALL
		"gold_decoration":
			Plants.gold_decoration(vbox)                               # (in plants.gd: the audit's script scan reads the scripts of the screen's own nodes)
		"red_label":
			var warn := _label("INV_TITLE", &"Body")
			warn.name = "Danger"
			warn.add_theme_color_override("font_color", Color("#d62828"))
			vbox.add_child(warn)
			var bar2 := ColorRect.new()
			bar2.name = "RedBar"
			bar2.color = Color("#cc1f1f")
			bar2.custom_minimum_size = Vector2(0, 8)
			vbox.add_child(bar2)
		"number_body":
			money.theme_type_variation = &"BodyL"
		"no_outline":
			var flat := StyleBoxFlat.new()
			flat.bg_color = C.PARCHMENT
			panel.add_theme_stylebox_override("panel", flat)
		"small_display":
			title.add_theme_font_size_override("font_size", 14)
		"small_body":
			var small := _label("INV_TITLE", &"Body")
			small.name = "Small"
			small.add_theme_font_size_override("font_size", 13)
			vbox.add_child(small)
		"raw_key":
			var raw := Label.new()
			raw.name = "Raw"
			raw.text = "AUDIT_FIXTURE_NO_SUCH_KEY"
			vbox.add_child(raw)
		"hit_small":
			var tiny := TextureButton.new()
			tiny.name = "TinyClose"
			tiny.custom_minimum_size = Vector2(28, 28)
			tiny.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			vbox.add_child(tiny)
		"literal_flip":
			var parts := PackedStringArray(["Typed", " in ", "code"])
			var lit := _label("", &"Body")
			lit.name = "Typed"
			lit.text = "".join(parts)
			vbox.add_child(lit)
		"stale_label":
			pass                                                       # `dynamic` is set once in _ready and never re-labelled (see _notification)
		"radio_page_defects":
			(pages[1].get_node("P1B0") as Button).focus_mode = Control.FOCUS_NONE
			var danger := _label("INV_TITLE", &"Body")
			danger.name = "Danger"
			danger.add_theme_color_override("font_color", Color("#d62828"))
			pages[1].add_child(danger)
			Plants.gold_stripe(pages[1])
		"radio_select_dead":
			tab_buttons[2].set_script(KeyHook)
			tab_buttons[2].set("mode", "eat_accept")
