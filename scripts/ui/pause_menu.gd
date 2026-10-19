extends TTScreen
## Pause transfers close their modal before opening a peer; save/load/settings nest above it.
var _rows: Array[Button] = []
var _row_specs: Array = []
var _leaving := false

func _init() -> void:
	super._init()
	screen_id = &"pause_menu"
	modal_name = &"pause"
	hotkey_action = &"pause"

func _ready() -> void:
	super._ready()
	# Keep the title's menu face, font and gold focus while fitting the pause actions.
	var compact := theme.duplicate() as Theme
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := theme.get_stylebox(state, "MenuRow").duplicate() as StyleBox
		box.content_margin_top = 4.0
		box.content_margin_bottom = 4.0
		compact.set_stylebox(state, "MenuRow", box)
	theme = compact
	resized.connect(_fit_panel)
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("pause", Callable(get_script(), &"fixture_setup"))
	%HintBar.set_hints([{"pair": [&"ui_up", &"ui_down"], "key": "HINT_MOVE"}, {"action": &"ui_accept", "key": "HINT_OK"}, {"action": &"ui_cancel", "key": "HINT_RESUME"}])

func _initial_focus() -> Control:
	return get_node("%ResumeButton")

func _hotkey_open_allowed() -> bool:
	var world := get_tree().get_first_node_in_group("world_2d")
	return world != null and world.get("area") != null and world.get("player") != null and not bool(world.get("sleeping")) and not bool(world.get("traveling")) and int(world.get("player").get("state")) == 0

func _screen(id: StringName) -> Node:
	var game_ui := get_tree().get_first_node_in_group("game_ui")
	return game_ui.call("get_screen", id) if game_ui != null else null

func _specs() -> Array:
	var rows: Array = [["ResumeButton", "UI_RESUME", close]]
	var world := get_tree().get_first_node_in_group("world_2d")
	for spec in [["inventory_ui", "InventoryButton", "INV_TITLE"], ["map_ui", "MapButton", "MAP_TITLE"], ["quest_journal", "JournalButton", "QJ_TITLE"], ["people", "PeopleButton", "PAUSE_PEOPLE"], ["build_menu_ui", "BuildButton", "PAUSE_BUILD"], ["garderobe", "WardrobeButton", "PAUSE_WARDROBE"], ["samlerbog", "CollectionButton", "PAUSE_COLLECTION"]]:
		if _screen(StringName(spec[0])) == null:
			continue
		if spec[0] == "build_menu_ui" and (world == null or world.get("area").map.id != &"farm"):
			continue
		rows.append([spec[1], spec[2], _transfer.bind(StringName(spec[0]))])
	if _screen(&"cheat_menu") != null:
		rows.append(["CheatButton", "CHEAT_TITLE", _transfer.bind(&"cheat_menu")])
	rows.append_array([["SaveButton", "MENU_SAVE", _nested.bind(&"save_menu")], ["LoadButton", "MENU_LOAD_GAME", _nested.bind(&"load_menu")], ["SettingsButton", "MENU_SETTINGS", _nested.bind(&"settings")]])
	var floors: Variant = _floors()
	if floors is Object and floors.has_method("current_floor") and int(floors.call("current_floor")) > 0:
		rows.append(["LeaveDungeonButton", "DUNGEON_LEAVE", _leave_dungeon])
	rows.append_array([["QuitButton", "UI_TO_TITLE", _leave.bind(false)], ["QuitGameButton", "PAUSE_QUIT_GAME", _leave.bind(true)]])
	return rows

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	var specs := _specs()
	var names: Array = specs.map(func(row): return row[0])
	if names != _row_specs:
		for child in %MenuList.get_children():
			%MenuList.remove_child(child)
			child.queue_free()
		_rows.clear()
		_row_specs = names
		for spec in specs:
			var button := Button.new()
			button.name = spec[0]
			button.theme_type_variation = &"MenuRow"
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.set_meta(&"copy_key", spec[1])
			%MenuList.add_child(button)
			button.owner = self
			button.unique_name_in_owner = true
			button.pressed.connect(spec[2])
			_rows.append(button)
	for row in _rows:
		row.text = tr(str(row.get_meta(&"copy_key")))
	UiNav.wire_ring(_rows)
	UiNav.hover_focus(_rows)
	_fit_panel.call_deferred()

func _fit_panel() -> void:
	if not is_node_ready(): return
	var panel: PanelContainer = get_node("Panel")
	var body: VBoxContainer = get_node("Panel/Body")
	var hint_height: float = %HintBar.get_combined_minimum_size().y if %HintBar.visible else 0.0
	var gaps := 2 if %HintBar.visible else 1
	var desired: float = %TitleLabel.get_combined_minimum_size().y + %MenuList.get_combined_minimum_size().y + hint_height + gaps * body.get_theme_constant("separation") + panel.get_theme_stylebox("panel").get_minimum_size().y
	panel.size = Vector2(500, minf(desired, minf(630, maxf(1, size.y-48))))
	panel.position = (size-panel.size)*0.5

func _nested(panel: StringName) -> void:
	EventBus.ui_panel_toggled.emit(panel, true)

func _transfer(id: StringName) -> void:
	var target := _screen(id)
	if target == null:
		return
	close()
	if target.has_method("open"):
		target.call("open")
	else:
		EventBus.ui_panel_toggled.emit({&"inventory_ui": &"inventory", &"quest_journal": &"journal", &"build_menu_ui": &"build"}.get(id, id), true)

func _leave(quit_game: bool) -> void:
	if _leaving:
		return
	_leaving = true
	if not SaveManager.autosave():
		var accepted := await UiConfirm.ask(self, "NOTIF_SAVE_FAILED_TITLE", tr("PAUSE_SAVE_FAILED_CONFIRM"), "NAV_OK")
		if not accepted:
			_leaving = false
			return
	GameManager.pop_all_modals()
	GameManager.change_phase(GameManager.GamePhase.MENU)
	if quit_game:
		GameManager.quit_game()
	else:
		get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _floors() -> Variant:
	return Svc.static_call("res://scripts/dungeon/floors/dungeon_floors.gd", &"inst", [], null)

func _leave_dungeon() -> void:
	if await UiConfirm.ask(self, "DUNGEON_LEAVE", tr("DUNGEON_LEAVE_CONFIRM"), "NAV_OK"):
		var floors: Variant = _floors()
		GameManager.pop_all_modals()
		if floors is Object and is_instance_valid(floors):
			floors.call("leave")

static func fixture_setup(node: Node, _host: Node) -> void:
	(node as TTScreen).open()
