extends TTScreen
## Quest definitions own the book's content. The optional calendar joins as its third tab.
const QText := preload("res://scripts/ui/theme/tt_quest_text.gd")
const Portraits := preload("res://scripts/ui/theme/tt_portraits.gd")
const Details := preload("res://scripts/ui/components/quest_details.gd")
const CALENDAR := "res://scenes/ui/social/calendar_tab.tscn"
var _tab := 0
var _selected: StringName = &""
var _rows: Array[Button] = []
var _cache: Dictionary = {}
var _tabs: Array[Button] = []
var _calendar: Control
var _mother_journal: MotherJournal
var _mother_tab: Button
var _group := ButtonGroup.new()
## the quest rows are their own radio group: one shared group would un-press the current tab whenever a quest is selected
var _row_group := ButtonGroup.new()
var _refresh_pending := false

func _init() -> void:
	super._init()
	screen_id = &"quest_journal"
	modal_name = &"journal"
	hotkey_action = &"journal"

func _ready() -> void:
	super._ready()
	_tabs = [%ActiveTab, %CompletedTab]
	_group.set_meta(UiNav.TAB_ROW_META, true)
	if ResourceLoader.exists(CALENDAR):
		_calendar = load(CALENDAR).instantiate()
		%CalendarHost.add_child(_calendar)
		%TabCalendar.visible = true
		_tabs.append(%TabCalendar)
	_mother_tab = Button.new()
	_mother_tab.theme_type_variation = &"PillTab"
	_mother_tab.toggle_mode = true
	%ActiveTab.get_parent().add_child(_mother_tab)
	_tabs.append(_mother_tab)
	_mother_journal = MotherJournal.new()
	%CalendarHost.add_child(_mother_journal)
	for i in _tabs.size():
		_tabs[i].button_group = _group
		_tabs[i].pressed.connect(_set_tab.bind(i))
		_tabs[i].focus_entered.connect(_set_tab.bind(i))
	%CloseButton.pressed.connect(close)
	EventBus.quest_accepted.connect(func(_id): _schedule_refresh())
	EventBus.quest_completed.connect(func(_id): _schedule_refresh())
	EventBus.quest_failed.connect(func(_id): _schedule_refresh())
	EventBus.quest_objective_updated.connect(func(_q, _o, _p, _t): _schedule_refresh())
	%HintBar.set_hints([{"pair": [&"ui_up", &"ui_down"], "key": "HINT_MOVE"}, {"action": &"ui_cancel", "key": "HINT_BACK"}])
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("journal", Callable(get_script(), &"fixture_setup"))
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("journal_guide", Callable(get_script(), &"fixture_guide"))

func _initial_focus() -> Control:
	if _tab == 3: return _mother_journal.initial_focus()
	if _tab == 2 and _calendar != null:
		return _calendar.initial_focus()
	return _rows[0] if not _rows.is_empty() and _tab < 2 else _tabs[_tab]

func _on_page(step: int) -> void:
	_set_tab(posmod(_tab + step, _tabs.size()))
	_initial_focus().grab_focus()

func _input(event: InputEvent) -> void:
	if is_open() and is_top() and event.is_pressed() and not event.is_echo():
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Button and focus in _rows and (event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right")):
			_on_page(1 if event.is_action_pressed(&"ui_right") else -1)
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _set_tab(index: int) -> void:
	if index == _tab:
		return
	_tab = index
	_selected = &""
	if _tab == 2 and _calendar != null:
		_calendar.season_index = -1
	_refresh_texts()

func _schedule_refresh() -> void:
	if not is_open() or _refresh_pending:
		return
	_refresh_pending = true
	_flush.call_deferred()

func _flush() -> void:
	_refresh_pending = false
	if is_inside_tree() and is_open():
		_refresh_texts()

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	%SidebarTitle.text = tr("QJ_TITLE")
	%ActiveTab.text = tr("QJ_TAB_ACTIVE") % QuestManager.get_active_count()
	%CompletedTab.text = tr("QJ_TAB_DONE") % QuestManager.get_completed_count()
	%TabCalendar.text = tr("DLG_JOURNAL_CALENDAR")
	_mother_tab.text = tr("FM_TAB")
	%RewardHeader.text = tr("QJ_REWARD")
	%EmptyLabel.text = tr("QJ_EMPTY")
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(i == _tab)
	%CalendarHost.visible = _tab in [2,3]
	%DetailMargin.visible = _tab < 2
	%QuestScroll.visible = _tab < 2
	_mother_journal.visible = _tab == 3
	if _calendar != null: _calendar.visible = _tab == 2
	if _tab == 3: _mother_journal.refresh()
	if _calendar != null and _tab == 2 and _calendar.has_method("refresh"):
		_calendar.refresh()
	for button in _cache.values():
		button.visible = false
		button.focus_mode = Control.FOCUS_NONE
	_rows.clear()
	var ids: Array = QuestManager.get_active_ids() if _tab == 0 else (QuestManager.get_completed_ids() if _tab == 1 else [])
	if _selected not in ids:
		_selected = ids[0] if not ids.is_empty() else &""
	for id in ids:
		var row: Button = _cache.get(id)
		if row == null:
			row = _make_row(id)
			%QuestList.add_child(row)
			_cache[id] = row
		row.visible = true
		row.focus_mode = Control.FOCUS_ALL
		row.get_node("Margin/Row/Texts/Title").text = QText.title(id)
		row.get_node("Margin/Row/Texts/Giver").text = QText.giver_name(id)
		row.get_node("Margin/Row/Tag/Text").text = QText.tag_text(id)
		row.set_pressed_no_signal(id == _selected)
		%QuestList.move_child(row, _rows.size())
		_rows.append(row)
	_show_details(_selected)
	_wire()

func _make_row(id: StringName) -> Button:
	var row := Button.new()
	row.name = "Quest_" + str(id)
	row.theme_type_variation = &"RowButton"
	row.toggle_mode = true
	row.button_group = _row_group
	row.custom_minimum_size = Vector2(0, 68)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.pressed.connect(_select.bind(id))
	row.focus_entered.connect(_select.bind(id))
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	row.add_child(margin)
	var h := HBoxContainer.new()
	h.name = "Row"
	h.add_theme_constant_override("separation", 12)
	margin.add_child(h)
	var tag := PanelContainer.new()
	tag.name = "Tag"
	tag.theme_type_variation = &"TagBox"
	tag.custom_minimum_size = Vector2(54, 44)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := load("res://assets/ui/theme.tres").get_stylebox("panel", "TagBox").duplicate() as StyleBox
	style.set("fill", QText.tag_color(id))
	# Long tags such as VENSKAB need the same breathing room as short tags.
	style.content_margin_left = 8
	style.content_margin_right = 8
	tag.add_theme_stylebox_override("panel", style)
	h.add_child(tag)
	var label := Label.new()
	label.name = "Text"
	label.theme_type_variation = &"Heavy14"
	label.set_meta("tt_text_same_ok", "The FIND tag has the same spelling in Danish and English")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_child(label)
	var texts := VBoxContainer.new()
	texts.name = "Texts"
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texts)
	for spec in [["Title", "Heavy18"], ["Giver", "Muted14"]]:
		var text := Label.new()
		text.name = spec[0]
		text.theme_type_variation = StringName(spec[1])
		if spec[0] == "Giver":
			text.set_meta("tt_text_same_ok", "Canonical citizen names are shared by both languages")
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texts.add_child(text)
	_mouse_ignore(margin)
	return row

func _select(id: StringName) -> void:
	_selected = id
	for button in _rows:
		button.set_pressed_no_signal(button.name == "Quest_" + str(id))
	_show_details(id)

func _show_details(id: StringName) -> void:
	%EmptyLabel.visible = id == &"" and _tab != 2
	%DetailBody.visible = id != &""
	if id == &"":
		return
	%DetailTitle.text = QText.title(id)
	%DetailFrom.text = QText.from_line(id)
	%DetailText.text = QText.description(id)
	var giver := StringName(QText.giver_id(id))
	%GiverPortrait.texture = Portraits.portrait(giver) if giver != &"" else null
	for node in [%StepList, %RewardRow]:
		for child in node.get_children():
			node.remove_child(child)
			child.queue_free()
	for step in QText.steps(id):
		%StepList.add_child(Details.step(step))
	for reward in QText.rewards(id):
		%RewardRow.add_child(Details.reward(reward))

func _wire() -> void:
	UiNav.wire_row(_tabs + [%CloseButton])
	if _tab == 3:
		_mother_journal.wire_navigation(_tabs+[%CloseButton])
		return
	if _tab == 2 and _calendar != null:
		_calendar.wire_navigation(_tabs + [%CloseButton])
		return
	UiNav.wire_ring(_rows)
	UiNav.wire_groups([_tabs + [%CloseButton], _rows], true, false)

static func _mouse_ignore(root: Control) -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		if child is Control:
			_mouse_ignore(child)

static func fixture_setup(node: Node, _host: Node) -> void:
	if not QuestManager.is_active(&"lost_cat") and not QuestManager.is_completed(&"lost_cat"):
		QuestManager.accept_quest(&"lost_cat")
	node.open()

static func fixture_guide(node: Node, _host: Node) -> void:
	# The immutable mock has three cat steps and three rewards. Only the visual
	# fixture projects that historical content; production always reads the real Lua.
	var mock: Array = preload("res://scripts/ui/dev/ui_fixtures.gd").guide_data().get("quests", [])
	var ids := [&"lost_cat", &"cookie_delivery", &"fix_roof", &"moonstone_crown"]
	var definitions := {}
	var progress := {}
	for i in ids.size():
		var def: Dictionary = mock[i].duplicate(true)
		def["meta"]["giver"] = ["pippin_boegeknop", "baker_maja", "mayor_lyra", "fairy_king"][i]
		def["meta"]["tag"] = ["FIND", "HØST", "BYG", "SKOV"][i]
		if i == 0:
			def["rewards"] = {"gold": 150, "items": {"catnip_seeds": 3}, "friendship": {"pippin_boegeknop": 1}}
		definitions[ids[i]] = def
		var state := {"objectives": {}}
		for objective in LuaData.arr(def.get("objectives", [])):
			var done: bool = str(objective.id) in LuaData.arr(def.get("done", []))
			state.objectives[str(objective.id)] = {"current": int(objective.target) if done else 0, "done": done}
		progress[ids[i]] = state
	QText.set_providers(func(id): return definitions.get(id, {}), func(id): return progress.get(id, {}), func(_id): return false)
	node.closed.connect(func(): QText.clear_providers(), CONNECT_ONE_SHOT)
	for id in [&"lost_cat", &"cookie_delivery", &"fix_roof", &"moonstone_crown"]:
		if not QuestManager.is_active(id) and not QuestManager.is_completed(id):
			QuestManager.accept_quest(id)
	QuestManager.update_objective(&"lost_cat", &"ask_neighbours", 3)
	QuestManager.complete_manual(&"lost_cat", &"follow_pawprints")
	node.open()
	node._select(&"lost_cat")
	# The immutable original mock predates the calendar. Its fixture keeps the
	# two historical tabs; the production book exposes all three.
	node.get_node("%TabCalendar").hide()
	node._mother_tab.hide()
