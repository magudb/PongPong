extends Control
## Title owns scene navigation; modal screens own their stack entries and focus return.
var _rows: Array = []
var _last_row: Control
var _updates_button: Button

func _ready() -> void:
	GameManager.pop_all_modals()
	GameManager.change_phase(GameManager.GamePhase.MENU)
	get_tree().paused = false
	SettingsUI.apply_saved()
	UiNav.watcher()
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("title_guide", Callable(get_script(), &"fixture_guide"))
	%NewGameButton.pressed.connect(_on_new_game)
	%ContinueButton.pressed.connect(_on_continue)
	%LoadButton.pressed.connect(func(): _remember(%LoadButton); EventBus.ui_panel_toggled.emit(&"load_menu", true))
	%SettingsButton.pressed.connect(func(): _remember(%SettingsButton); EventBus.ui_panel_toggled.emit(&"settings", true))
	%QuitButton.pressed.connect(func(): GameManager.quit_game())
	%LanguageButton.pressed.connect(_on_language)
	_updates_button = Button.new()
	_updates_button.name = "UpdatesButton"
	_updates_button.theme_type_variation = &"MenuRow"
	_updates_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	%QuitButton.get_parent().add_child(_updates_button)
	%QuitButton.get_parent().move_child(_updates_button, %QuitButton.get_index())
	_updates_button.pressed.connect(_open_updates)
	var updates := ReleaseUpdates.inst()
	updates.changed.connect(_refresh_labels)
	updates.check(true)
	for id in ["save_load_ui", "settings_ui"]:
		var screen: Node = load("res://scenes/ui/" + id + ".tscn").instantiate()
		add_child(screen)
		if screen is TTScreen:
			screen.closed.connect(func(): _refresh_labels.call_deferred())
	%HintBar.set_hints([{"pair": [&"ui_up", &"ui_down"], "key": "HINT_MOVE"}, {"action": &"ui_accept", "key": "HINT_OK"}])
	_refresh_labels()
	var remembered := UiNav.recall(&"title")
	var focus: Control = find_child(remembered, true, false) as Control if remembered != "" else null
	if not UiNav.is_stop(focus):
		focus = UiNav.first_enabled(_rows)
	await get_tree().process_frame
	if UiNav.is_stop(focus):
		focus.grab_focus()
	# Release templates disable --script overrides; the explicit headless probe
	# starts after the real title has finished its normal startup.
	if DisplayServer.get_name() == "headless" and "--release-smoke" in OS.get_cmdline_user_args():
		get_tree().root.add_child.call_deferred(load("res://scripts/release/export_smoke.gd").new())

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_labels()

func _refresh_labels() -> void:
	if not is_node_ready():
		return
	%LanguageButton.text = tr("MENU_VERSION_TAG")
	var rows: Array[Dictionary] = SaveManager.describe_slots()      # once per refresh: every value below comes from these rows
	var latest: int = SaveManager.latest_slot_of(rows)
	UiNav.set_enabled(%ContinueButton, latest != SaveManager.NO_SLOT)
	var loadable := 0
	var unreadable := false
	for descriptor in rows:
		if descriptor.state in ["ok", "backup"]:
			loadable += 1
		elif descriptor.state in ["newer", "corrupt"]:
			unreadable = true
	# A save that cannot be read is shown too (the load screen names its state): it must never look as if there were none.
	%LoadButton.visible = loadable >= 2 or unreadable
	UiNav.set_enabled(%LoadButton, %LoadButton.visible)
	var latest_summary: Dictionary = rows.filter(func(row: Dictionary) -> bool: return int(row.slot) == latest).front().summary if latest >= 0 else {}
	%ContinueInfo.text = tr("MENU_CONTINUE_DAY") % int(latest_summary.get("total_day", 1)) if latest >= 0 else ""
	_rows = [%ContinueButton, %LoadButton, %NewGameButton, %SettingsButton, %QuitButton]
	_updates_button.visible = ReleaseUpdates.inst().state in ["available", "ready"]
	_updates_button.text = tr("UPDATE_AVAILABLE") % str(ReleaseUpdates.inst().available.get("version", ""))
	if _updates_button.visible: _rows.insert(_rows.size() - 1, _updates_button)
	UiNav.wire_ring(_rows)
	UiNav.wire_row([%LanguageButton])
	UiNav.hover_focus(_rows + [%LanguageButton])
	for row in _rows:
		UiNav.link(row, &"left", %LanguageButton)
		UiNav.link(row, &"right", %LanguageButton)
		if not row.focus_entered.is_connected(_row_focused.bind(row)):
			row.focus_entered.connect(_row_focused.bind(row))
	_row_focused(_last_row if UiNav.is_stop(_last_row) else UiNav.first_enabled(_rows))
	var focused := get_viewport().gui_get_focus_owner()
	if not GameManager.is_modal_open() and (not UiNav.is_stop(focused) or not focused.is_visible_in_tree()):
		var fallback := UiNav.first_enabled(_rows)
		if fallback != null:
			fallback.grab_focus.call_deferred()

func _row_focused(row: Control) -> void:
	_last_row = row
	UiNav.link(%LanguageButton, &"left", row)
	UiNav.link(%LanguageButton, &"right", row)

func _input(event: InputEvent) -> void:
	if GameManager.is_modal_open():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
	else:
		UiNav.wasd_translate(get_viewport(), event)

func _remember(row: Control) -> void:
	UiNav.remember(&"title", row.name)

## A save already exists: ask first (Cancel is the default) and name the run, so nobody starts over by accident. The run is kept
## either way (its manual slot, or its autosave as SaveManager.PREV_AUTO_SLOT), which the question says.
func _on_new_game() -> void:
	_remember(%NewGameButton)
	var latest: int = SaveManager.get_latest_slot()
	if latest != SaveManager.NO_SLOT:
		var summary: Dictionary = SaveManager.get_save_summary(latest)
		var run_name := str(summary.get("farm_name", ""))
		if run_name == "":
			run_name = str(summary.get("player_name", ""))
		if not await UiConfirm.ask(self, "TITLE_NEW_GAME_TITLE", "TITLE_NEW_GAME_CONFIRM", "MENU_NEW_GAME", "NAV_CANCEL", &"cancel", [run_name, int(summary.get("total_day", 1))]):
			return
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_continue() -> void:
	SaveManager.continue_latest()

func _on_language() -> void:
	LocalizationManager.set_locale("en" if LocalizationManager.is_da() else "da")

func _open_updates() -> void:
	var screen := get_node_or_null("Updates")
	if screen == null:
		screen = load("res://scenes/ui/update_panel.tscn").instantiate()
		add_child(screen)
	screen.open(_updates_button)

static func fixture_guide(node: Node, _host: Node) -> void:
	var button := node.get_node("%ContinueButton") as Button
	UiNav.set_enabled(button, true)
	node.get_node("%ContinueInfo").text = TranslationServer.translate("MENU_CONTINUE_DAY") % 14
	UiNav.wire_ring(node.get("_rows"))
	button.grab_focus()
