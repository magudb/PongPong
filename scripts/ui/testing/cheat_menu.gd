extends TTScreen
## F8 and pause-menu access; all state changes use gameplay owners.
const L := preload("res://scripts/ui/social/social_layout.gd")
const Actions := preload("res://scripts/ui/testing/cheat_actions.gd")
const TABS := ["CHEAT_PLAYER", "CHEAT_TRAVEL", "CHEAT_ITEMS", "CHEAT_CLOCK"]
const DESTINATIONS := [["ZONE_FARM", "farm", "default"], ["ZONE_TRAETOPPEN", "traetoppen", "default"], ["CHEAT_TOWN_SQUARE", "traetoppen", "from_skovlift"], ["ZONE_CITY", "hyggebyen", "default"], ["ZONE_DARK_FOREST", "moerkeskoven", "from_traetoppen"], ["CHEAT_HOME", "home", "default"], ["FARMSITE_GREENHOUSE", "greenhouse", "default"]]
var tabs: Array[Button] = []
var content: VBoxContainer
var status: Label
var heading: Label
var notice: Label
var close_button: Button
var search: LineEdit
var item_picker: ItemList
var grant_button: Button
var quantity: Control
var item_ids: Array[String] = []
var tab := 0
var _rows: Array[Control] = []

func _init() -> void:
	super._init()
	screen_id = &"cheat_menu"
	modal_name = &"cheats"
	hotkey_action = &"cheat_menu"

func _ready() -> void:
	super._ready()
	var menu_theme := theme.duplicate() as Theme
	menu_theme.set_type_variation(&"CheatItemList", &"ItemList")
	menu_theme.set_stylebox("panel", "CheatItemList", theme.get_stylebox("panel", "PanelField"))
	menu_theme.set_stylebox("focus", "CheatItemList", theme.get_stylebox("focus", "LineEdit"))
	menu_theme.set_stylebox("selected", "CheatItemList", theme.get_stylebox("pressed", "ButtonSecondaryS"))
	menu_theme.set_stylebox("selected_focus", "CheatItemList", theme.get_stylebox("pressed", "ButtonSecondaryS"))
	menu_theme.set_color("font_color", "CheatItemList", Color("2b2340"))
	menu_theme.set_color("font_selected_color", "CheatItemList", Color("2b2340"))
	menu_theme.set_font("font", "CheatItemList", theme.get_font("font", "LineEdit"))
	menu_theme.set_font_size("font_size", "CheatItemList", 20)
	theme = menu_theme
	L.scrim(self)
	var book := L.panel(self, "PanelBook", Rect2(100, 45, 1080, 630))
	var body := L.box(L.margin(book, 24), true, 12)
	heading = L.label(body, "", "Display34")
	notice = L.label(body, "", "Body", true)
	var strip := L.box(body, false, 8)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var button := L.button(strip, "", "ButtonSecondaryS")
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_set_tab.bind(i))
		tabs.append(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	content = L.box(scroll, true, 10) as VBoxContainer
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = L.label(body, "", "Body", true)
	close_button = L.button(body, "", "ButtonPrimaryS")
	close_button.pressed.connect(close)

func _hotkey_open_allowed() -> bool:
	return Actions.available()

func open(opener: Control = null) -> void:
	if Actions.available(): super.open(opener)

func _initial_focus() -> Control:
	return tabs[tab]

func _on_page(step: int) -> void:
	_set_tab(posmod(tab + step, TABS.size()))
	tabs[tab].grab_focus()

func _set_tab(index: int) -> void:
	tab = index
	_refresh_texts()

func _refresh_texts() -> void:
	if not is_node_ready(): return
	heading.text = tr("CHEAT_TITLE")
	notice.text = tr("CHEAT_NOTICE")
	close_button.text = tr("CHEAT_CLOSE")
	for i in tabs.size():
		tabs[i].text = tr(TABS[i])
		tabs[i].set_pressed_no_signal(i == tab)
	L.clear(content)
	_rows.clear()
	search = null
	item_picker = null
	quantity = null
	match tab:
		0:
			_button("CHEAT_RECOVER", Actions.recover)
			_button("CHEAT_GOLD", Actions.gold)
			_button("CHEAT_WARDROBE", Actions.wardrobe)
			_button("CHEAT_DRESS", _dress)
		1:
			for dest in DESTINATIONS:
				if WorldRoot2D.has_area(StringName(dest[1])):
					_button(dest[0], _travel.bind(StringName(dest[1]), StringName(dest[2])))
			if Actions.world() != null and Actions.world().area.map.id == &"traetoppen":
				for level in LevelStage.of(Actions.world().area).registry.platforms:
					var button := _button("CHEAT_PLATFORM", _platform.bind(level.id))
					button.text = tr("CHEAT_PLATFORM") % level.id
		2: _items()
		3:
			_button("CHEAT_HOUR", Actions.advance.bind(60))
			_button("CHEAT_NEXT_DAY", Actions.next_day)
			var freeze := CheckButton.new()
			freeze.text = tr("CHEAT_FREEZE")
			freeze.button_pressed = TimeManager.is_paused
			freeze.toggled.connect(func(on: bool): TimeManager.is_paused = on)
			content.add_child(freeze)
			_rows.append(freeze)
			for weather in ["klart", "regn", "taage", "sne", "torden"]:
				var button := _button("CHEAT_WEATHER", _weather.bind(weather))
				button.text = tr("CHEAT_WEATHER") % tr("UI_WEATHER_" + weather.to_upper())
	var controls: Array = []
	controls.append_array(tabs)
	controls.append_array(_rows)
	controls.append(close_button)
	UiNav.wire_row(tabs)
	UiNav.wire_ring(_rows)
	UiNav.wire_ring([close_button])
	UiNav.wire_groups([tabs, _rows, [close_button]], true, false)
	UiNav.hover_focus(controls)

func _button(key: String, action: Callable) -> Button:
	var button := L.button(content, tr(key), "ButtonSecondaryS")
	button.name = key.trim_prefix("CHEAT_") + str(_rows.size()) + "Button"
	button.owner = self
	button.unique_name_in_owner = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func():
		var ok: Variant = action.call()
		if is_open(): status.text = tr("CHEAT_DONE" if ok == true else "CHEAT_FAILED"))
	_rows.append(button)
	return button

func _items() -> void:
	search = LineEdit.new()
	search.placeholder_text = tr("CHEAT_SEARCH")
	search.custom_minimum_size.y = 42
	content.add_child(search)
	_rows.append(search)
	item_picker = ItemList.new()
	item_picker.focus_mode = Control.FOCUS_ALL
	item_picker.theme_type_variation = &"CheatItemList"
	item_picker.custom_minimum_size.y = 150
	content.add_child(item_picker)
	_rows.append(item_picker)
	quantity = preload("res://scenes/ui/components/quantity_stepper.tscn").instantiate()
	quantity.min_value = 1
	quantity.max_value = 999
	quantity.value = 1
	content.add_child(quantity)
	_rows.append(quantity)
	item_picker.gui_input.connect(_item_input)
	item_picker.item_activated.connect(func(_index: int): quantity.grab_focus())
	search.text_changed.connect(_filter_items)
	_filter_items("")
	grant_button = _button("CHEAT_GRANT", _grant)

func _filter_items(query: String) -> void:
	item_picker.clear()
	item_ids.clear()
	var ids: Array = LuaRuntime.get_all_item_ids()
	ids.sort()
	for id in ids:
		var definition: Dictionary = LuaRuntime.get_item_def(str(id))
		var label := tr(str(definition.get("name_key", "ITEM_" + str(id).to_upper())))
		if query.is_empty() or query.to_lower() in label.to_lower() or query.to_lower() in str(id).to_lower():
			item_ids.append(str(id))
			item_picker.add_item("%s (%s)" % [label, id])
	if not item_ids.is_empty(): item_picker.select(0)
	if is_instance_valid(grant_button): grant_button.disabled = item_ids.is_empty()

func _grant() -> bool:
	var selection := item_picker.get_selected_items()
	var index := int(selection[0]) if not selection.is_empty() else -1
	return index >= 0 and index < item_ids.size() and Actions.grant(item_ids[index], int(quantity.value))

func _weather(id: String) -> bool:
	TimeManager.set_weather(StringName(id))
	return true

func _dress() -> bool:
	close()
	get_tree().get_first_node_in_group("game_ui").get_screen(&"garderobe").open()
	return true

func _travel(id: StringName, spawn: StringName) -> bool:
	close()
	return Actions.travel(id, spawn)

func _platform(id: StringName) -> bool:
	var w := Actions.world()
	var stage := LevelStage.of(w.area)
	var candidate: Variant = stage.registry.safe_point(id)
	if not candidate is Vector2: return false
	var at: Vector2 = candidate
	close()
	w.player.global_position = at
	stage.tracker.refresh(w.player)
	return true


func _item_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right"):
		quantity.grab_focus()
		item_picker.accept_event()
	elif event.is_action_pressed(&"ui_left"):
		search.grab_focus()
		item_picker.accept_event()


func _input(event: InputEvent) -> void:
	if is_open() and is_top() and event.is_pressed():
		if event.is_action_pressed(&"cheat_menu"):
			close()
			get_viewport().set_input_as_handled()
			return
		var focus := get_viewport().gui_get_focus_owner()
		var step := 1 if event.is_action_pressed(&"ui_down") else -1 if event.is_action_pressed(&"ui_up") else 0
		if step != 0:
			if focus == item_picker:
				var selected := item_picker.get_selected_items()
				var index := int(selected[0]) if not selected.is_empty() else -1
				if step > 0 and index < item_ids.size()-1 or step < 0 and index > 0:
					return # The list owns selection within its bounds.
			var stops: Array = []
			stops.append(tabs[tab])
			stops.append_array(_rows)
			stops.append(close_button)
			stops = stops.filter(func(c): return UiNav.is_stop(c))
			var index := 0 if focus is Button and focus in tabs else stops.find(focus)
			if index >= 0:
				(stops[posmod(index+step,stops.size())] as Control).grab_focus()
				get_viewport().set_input_as_handled()
				return
	super._input(event)
