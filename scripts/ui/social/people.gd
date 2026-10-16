extends TTScreen
## Read-only friendship book. Only SocialManager.people_rows decides who is visible.
const L := preload("res://scripts/ui/social/social_layout.gd")
const Row := preload("res://scripts/ui/social/people_row.gd")
var book: PanelContainer
var list: VBoxContainer
var detail: VBoxContainer
var title: Label
var footer: Label
var tabs: Array[Button] = []
var rows: Array[Button] = []
var data: Array[Dictionary] = []
var selected_id := ""
var last_talked := ""
var tab := 0
var _cache := {}
var _row_group := ButtonGroup.new()
var _portraits: Dictionary = {}

func _init() -> void:
	super._init()
	screen_id = &"people"
	modal_name = &"people"
	hotkey_action = &"people"

func _ready() -> void:
	super._ready()
	_row_group.set_meta("tt_value_selection", true)
	L.scrim(self)
	book = L.panel(self, "PanelBook", Rect2(80, 50, 1120, 620))
	var columns := L.box(book, false, 0)
	var side := L.panel(columns, "PanelSidebar")
	side.custom_minimum_size.x = 430
	var body := L.box(side)
	title = L.label(body, "", "Display34")
	var strip := L.box(body, false, 6)
	var group := ButtonGroup.new()
	for i in 3:
		var button := L.button(strip, "")
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_set_tab.bind(i))
		button.focus_entered.connect(_set_tab.bind(i))
		tabs.append(button)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var margin := L.margin(scroll, 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list = L.box(margin, true, 6) as VBoxContainer
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer = L.label(body, "", "Muted14")
	var inset := L.margin(columns, 28)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details := ScrollContainer.new()
	details.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inset.add_child(details)
	detail = L.box(details, true, 12) as VBoxContainer
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size.x = 560
	EventBus.dialogue_started.connect(func(npc, _module):
		last_talked = str(npc)
		_warm_portrait(last_talked))
	EventBus.game_event.connect(_event)
	# Meeting a citizen already needs their portrait for dialogue. Retain that
	# small texture for the book; Continue warms known faces behind the world fade.
	for entry in SocialManager.people_rows():
		_warm_portrait(str(entry.id))
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("people", Callable(get_script(), &"fixture_setup"))

func _warm_portrait(id: String) -> void:
	if id != "" and not _portraits.has(id):
		_portraits[id] = L.Portraits.portrait(StringName(id))

func _event(id: StringName, payload: Dictionary) -> void:
	if id == &"open_people":
		open()
	elif id == &"social_points":
		_warm_portrait(str(payload.get("npc", "")))

func open(opener: Control = null) -> void:
	selected_id = last_talked
	super.open(opener)

func _initial_focus() -> Control:
	for row in rows:
		if row.row.id == selected_id:
			return row
	return rows[0] if not rows.is_empty() else tabs[tab]

func _set_tab(index: int) -> void:
	if tab == index:
		return
	tab = index
	_refresh_texts()

func _on_page(step: int) -> void:
	_set_tab(posmod(tab + step, 3))
	_initial_focus().grab_focus()

func _input(event: InputEvent) -> void:
	if is_open() and is_top() and event.is_pressed():
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Button and focus in rows and (event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right")):
			if not event.is_echo():
				_on_page(1 if event.is_action_pressed(&"ui_right") else -1)
			get_viewport().set_input_as_handled()
			return
		if focus is Button and focus in rows and (event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down")):
			# ScrollContainer clips off-screen neighbours before its deferred
			# follow-focus update. Select the logical row for both devices so
			# a fast press cannot skip the row just outside the viewport.
			var index := rows.find(focus) + (1 if event.is_action_pressed(&"ui_down") else -1)
			if event.is_echo() and (index < 0 or index >= rows.size()):
				get_viewport().set_input_as_handled()
				return
			var target: Control = rows[index] if index >= 0 and index < rows.size() else tabs[tab]
			target.grab_focus()
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	title.text = tr("PAUSE_PEOPLE")
	data = SocialManager.people_rows()
	var groups: Array = [data, data.filter(func(r): return int(r.hearts) >= 5), data.filter(func(r): return not r.next_birthday.is_empty() and int(r.next_birthday.days) == 0)]
	for i in tabs.size():
		tabs[i].text = tr(["REL_PEOPLE_ALL", "REL_PEOPLE_NEAR", "REL_PEOPLE_TODAY"][i]) % groups[i].size()
		tabs[i].set_pressed_no_signal(i == tab)
	footer.text = tr("REL_PEOPLE_MET") % [data.size(), SocialData.friend_ids().filter(func(id): return not NpcDirector.is_absent(id)).size()]
	for row in _cache.values():
		row.hide()
		row.focus_mode = Control.FOCUS_NONE
	rows.clear()
	for entry in groups[tab]:
		var row: Button = _cache.get(entry.id)
		if row == null:
			row = Row.new()
			row.name = "Citizen_" + str(entry.id)
			row.theme_type_variation = &"RowButton"
			row.toggle_mode = true
			row.button_group = _row_group
			row.custom_minimum_size = Vector2(0, 58)
			row.pressed.connect(_select.bind(str(entry.id)))
			row.focus_entered.connect(_select.bind(str(entry.id)))
			list.add_child(row)
			_cache[entry.id] = row
		_warm_portrait(str(entry.id))
		row.setup(entry, _portraits.get(entry.id))
		row.show()
		row.focus_mode = Control.FOCUS_ALL
		list.move_child(row, rows.size())
		rows.append(row)
	if not groups[tab].any(func(r): return r.id == selected_id):
		selected_id = str(groups[tab][0].id) if not groups[tab].is_empty() else ""
	_select(selected_id, true)
	UiNav.wire_row(tabs)
	UiNav.wire_ring(rows)
	UiNav.wire_groups([tabs, rows], true, false)
	UiNav.hover_focus(rows)

func _select(id: String, force := false) -> void:
	if id == selected_id and not force and detail.get_child_count() > 0:
		return
	selected_id = id
	for row in rows:
		row.set_pressed_no_signal(str(row.row.id) == id)
	L.clear(detail)
	if id == "":
		L.label(detail, tr("REL_PEOPLE_EMPTY"), "Body", true)
		return
	var entry: Dictionary = data.filter(func(r): return str(r.id) == id)[0]
	var meta := SocialData.npc_row(id)
	var header := L.box(detail, false, 16)
	L.portrait(header, id, 96)
	var names := L.box(header, true, 4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	L.label(names, L.npc_name(id), "Display40", true)
	L.label(names, L.stage_name(entry.stage) + " · " + tr("ZONE_" + str(meta.get("home_area", "")).to_upper()), "Subtitle", true)
	L.label(detail, tr(str(meta.get("bio_key", "SOC_" + id.to_upper() + "_BIO_1"))), "Body", true)
	var hearts := L.box(detail, false, 12)
	L.hearts(hearts, int(entry.half_hearts), 28)
	L.label(hearts, tr("REL_PEOPLE_HEARTS") % _heart_count(int(entry.half_hearts)), "Display20")
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	detail.add_child(chips)
	if entry.chat_done:
		L.chip(chips, tr("REL_PEOPLE_CHAT"))
	L.chip(chips, tr("REL_PEOPLE_GIFTS") % entry.gifts_left)
	if not entry.birthday.is_empty():
		var date := "%d. %s" % [int(entry.birthday.day), tr("UI_SEASON_" + str(entry.birthday.season).to_upper())]
		L.chip(chips, tr("REL_PEOPLE_BIRTHDAY") % [date, int(entry.next_birthday.days)])
	L.label(detail, tr("REL_PEOPLE_FAVORITES"), "Eyebrow")
	var tastes := HFlowContainer.new()
	tastes.add_theme_constant_override("h_separation", 6)
	tastes.add_theme_constant_override("v_separation", 6)
	detail.add_child(tastes)
	for item in entry.tastes:
		L.chip(tastes, tr("REL_TASTE_" + str(entry.tastes[item]).to_upper()) + ": " + L.item_name(item), "ChipRewardRose" if str(entry.tastes[item]) == "love" else "Chip")
	if entry.tastes.is_empty():
		L.label(tastes, tr("REL_PEOPLE_EMPTY"), "Body")
	L.label(detail, tr("REL_PEOPLE_EVENTS"), "Eyebrow")
	L.label(detail, tr("REL_PEOPLE_EVENT_COUNT") % [entry.events_seen, entry.events_ready], "Body", true)

static func _heart_count(halves: int) -> String:
	return str(floori(halves / 2.0)) + ("½" if halves % 2 else "")

static func fixture_setup(node: Node, _host: Node) -> void:
	preload("res://scripts/ui/social/social_fixtures.gd").seed(true)
	node.last_talked = "gardener_hoppe"
	var started := Time.get_ticks_usec()
	node.open()
	node.set_meta("open_ms", (Time.get_ticks_usec() - started) / 1000.0)
