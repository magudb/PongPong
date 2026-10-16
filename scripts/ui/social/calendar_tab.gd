extends Control
const L := preload("res://scripts/ui/social/social_layout.gd")
var cells: Array[Button] = []
var chips: Array[Button] = []
var captions: Array[Label] = []
var numbers: Array[Label] = []
var today_markers: Array[Label] = []
var weekdays: Array[Label] = []
var today: VBoxContainer
var heading: Label
var year_label: Label
var season_index := -1
var year := 1
var entries: Array[Dictionary] = []
var _tabs: Array[Button] = []

func _ready() -> void:
	theme = preload("res://scripts/ui/social/calendar_theme.gd").make()
	var paper := ColorRect.new()
	paper.color = preload("res://scripts/ui/theme/tt_colors.gd").PARCHMENT
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	var columns := L.box(self, false, 28)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := L.panel(columns, "PanelDetail")
	card.custom_minimum_size.x = 240
	today = L.box(L.margin(card, 18), true, 14) as VBoxContainer
	var body := L.box(columns, true, 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := L.box(body, false, 12)
	heading = L.label(top, "", "Display28")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	year_label = L.label(top, "", "Subtitle")
	var seasons := L.box(body, false, 8)
	var group := ButtonGroup.new()
	for i in CalendarUtil.seasons().size():
		var chip := L.button(seasons, "")
		chip.toggle_mode = true
		chip.button_group = group
		chip.pressed.connect(_season.bind(i))
		chips.append(chip)
	var header := GridContainer.new()
	header.columns = 7
	header.add_theme_constant_override("h_separation", 8)
	body.add_child(header)
	for i in 7:
		var label := L.label(header, "", "Muted14")
		label.custom_minimum_size.x = 98
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weekdays.append(label)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for i in 28:
		var cell := L.button(grid, "", "CalCell")
		cell.name = "Day%d" % (i + 1)
		cell.custom_minimum_size = Vector2(98, 70)
		var number := L.label(cell, str(i + 1), "Display20")
		number.position = Vector2(7, 2)
		number.set_meta("tt_text_same_ok", "Calendar numerals are shared between languages")
		numbers.append(number)
		var marker := L.label(cell, "", "Muted14")
		marker.position = Vector2(36, 4)
		today_markers.append(marker)
		var caption := L.label(cell, "", "Muted14")
		caption.position = Vector2(7, 25)
		caption.size = Vector2(84, 44)
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.set_meta("tt_text_same_ok", "Calendar dates and canonical citizen names are shared between languages")
		captions.append(caption)
		cells.append(cell)
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("calendar", Callable(get_script(), &"fixture_setup"))
	refresh()

func _season(index: int) -> void:
	season_index = index
	refresh()

func refresh() -> void:
	if not is_node_ready():
		return
	if season_index < 0:
		season_index = CalendarUtil.season_index(GameManager.season)
		year = maxi(1, GameManager.year)
	var season := CalendarUtil.seasons()[season_index]
	heading.text = tr("UI_SEASON_" + str(season).to_upper())
	year_label.text = tr("REL_CAL_YEAR") % year
	for i in chips.size():
		chips[i].text = tr("UI_SEASON_" + str(CalendarUtil.seasons()[i]).to_upper())
		chips[i].set_pressed_no_signal(i == season_index)
	for i in weekdays.size():
		weekdays[i].text = tr("UI_WEEKDAY_" + str(posmod(i + CalendarUtil.first_weekday(), 7) + 1)).left(3)
	entries = SocialManager.calendar_entries(season, year).filter(func(row): return row.kind != "birthday" or bool(row.known))
	var market := LuaData.arr(LuaRuntime.get_shop("flea_market").get("open_weekdays", []))
	for i in cells.size():
		var items := entries.filter(func(row): return int(row.day) == i + 1)
		var lines: Array[String] = []
		var festival := false
		for item in items:
			if str(item.kind) == "birthday":
				lines.append("♥ " + L.npc_name(item.id))
			else:
				festival = true
				lines.append(tr(str(SocialData.festival(item.id).get("meta", {}).get("name_key", "FEST_" + str(item.id).to_upper() + "_NAME"))))
		var td := CalendarUtil.total_day(i + 1, season, year)
		if CalendarUtil.weekday_of(td) in market:
			lines.append(tr("SHOP_FLEA_MARKET"))
		var is_today := td == SocialManager.today()
		cells[i].theme_type_variation = &"CalCellToday" if is_today else (&"CalCellFest" if festival else &"CalCell")
		cells[i].text = ""
		cells[i].set_meta("tt_text_same_ok", "Calendar numerals are shared by both languages")
		today_markers[i].text = tr("REL_CAL_TODAY") if is_today else ""
		captions[i].text = "\n".join(lines)
		cells[i].tooltip_text = L.Fmt.date_text(i + 1, season) + "\n" + "\n".join(lines)
		cells[i].accessibility_name = cells[i].tooltip_text
	L.clear(today)
	L.label(today, tr("REL_CAL_TODAY").to_upper(), "Eyebrow")
	L.label(today, L.Fmt.date_text(), "Heavy19", true)
	for id in SocialManager.birthdays_today():
		if SocialManager.birthday_known(id):
			L.hearts(today, 2, 18).max_hearts = 1
			L.label(today, L.npc_name(id), "Heavy20", true)
	var fid := str(SocialManager.festival_today())
	if fid != "":
		L.label(today, tr(str(SocialData.festival(fid).get("meta", {}).get("name_key", "FEST_" + fid.to_upper() + "_NAME"))), "Body", true)
	wire_navigation(_tabs)

func initial_focus() -> Control:
	return cells[clampi(GameManager.day - 1, 0, 27)]

func wire_navigation(tabs: Array) -> void:
	var copy: Array[Button] = []
	copy.assign(tabs)
	_tabs = copy
	UiNav.wire_row(_tabs)
	UiNav.wire_row(chips)
	UiNav.wire_grid(cells, 7, false)
	UiNav.wire_groups([_tabs, chips, cells] if is_visible_in_tree() else [chips, cells], true, false)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == cells[27] and event.is_action_pressed(&"ui_right"):
		_shift(1)
		cells[0].grab_focus()
		get_viewport().set_input_as_handled()
	elif focused == cells[0] and event.is_action_pressed(&"ui_left"):
		if _shift(-1):
			cells[27].grab_focus()
		get_viewport().set_input_as_handled()

func _shift(step: int) -> bool:
	var count := chips.size()
	var index := (year - 1) * count + season_index + step
	if index < 0:
		return false
	year = floori(index / float(count)) + 1
	season_index = posmod(index, count)
	refresh()
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_visible_in_tree():
		refresh()

static func fixture_setup(node: Node, host: Node) -> void:
	preload("res://scripts/ui/social/social_fixtures.gd").seed(true)
	preload("res://scripts/ui/social/social_fixtures.gd").festival()
	node.tree_exited.connect(Callable(preload("res://scripts/ui/social/social_fixtures.gd"), &"cleanup"), CONNECT_ONE_SHOT)
	var book := L.panel(host, "PanelBook", Rect2(80, 50, 1120, 620))
	host.move_child(book, node.get_index())
	var head := Control.new()
	book.add_child(head)
	L.label(head, TranslationServer.translate("DLG_JOURNAL_CALENDAR"), "Display34").position = Vector2(28, 24)
	node.position = Vector2(108, 190)
	node.size = Vector2(1064, 440)
	node.season_index = -1
	node.refresh()
	node.initial_focus().grab_focus()
