extends RefCounted
const SECTION := "menus"
const TIMEOUT_S := 240.0
const SELECT := "res://scenes/ui/character_select.tscn"

func run(t) -> void:
	var save_manager: Node = t.autoload("SaveManager")
	var previous_save_dir: String = save_manager.save_dir
	save_manager.save_dir = "user://menus-pristine"
	UiNav.remember(&"title", "")
	if OS.get_environment("TRAETOPPEN_BAKE_MENUS") == "1":
		var built: Dictionary = t.run_godot_script("res://tools/ui/bake_menus.gd")
		t.check("scenes_compile", built.code == 0 and not built.output.contains("SCRIPT ERROR:") and not built.output.contains("ERROR:"), built.output)
		if built.code != 0 or built.output.contains("SCRIPT ERROR:"):
			return
	await t.go_menu()
	var title: Control = t.tree.current_scene
	await t.frames(3)
	t.check("initial_focus_title", title.get_viewport().gui_get_focus_owner() == title.get_node("%NewGameButton"))
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("title_esc_inert", t.tree.current_scene == title)
	t.tap_key(KEY_ENTER)
	await t.frames(4)
	t.check("keyboard_title_to_select", t.tree.current_scene.scene_file_path == SELECT)
	var select: Control = t.tree.current_scene
	for index in 4:
		select._select_type(index)
		await t.frames(2)
		t.expect(select._heroes.size() == 2 and select._chips.size() == 2, "Two authored heroes for race " + str(index))
		for hero in 2:
			select._select_hero(hero)
			await t.frames(2)
			t.expect(select.selected_skin == StringName(select._heroes[hero].skin), "Hero " + str(select.selected_skin))
			var blurb: Label = select.get_node("%HeroBlurb")
			t.expect(blurb.get_line_count() <= 2, "Hero blurb fits: " + str(select.selected_skin))
		var card: Control = select._cards[index]
		t.expect(card.size.is_equal_approx(Vector2(270, 434)) and is_equal_approx(card.global_position.x, 64.0 + index * 294.0) and card.position.y == -8, "Four-card geometry " + str(index))
	select._cards[3].grab_focus()
	t.tap_key(KEY_RIGHT)
	await t.frames(2)
	t.check("four_cards_wrap", select.selected_type == 0)
	t.tap_key(KEY_UP)
	await t.frames(2)
	t.check("card_up_reaches_selected_hero", select.get_viewport().gui_get_focus_owner() in select._chips)
	select._cards[0].grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	t.check("select_second_page", select._page == 2 and select.get_viewport().gui_get_focus_owner() == select.get_node("%NameInput"))
	select.get_node("%NameInput").text = "Måne"
	select.get_node("%FarmNameInput").text = "Min gård"
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	select._set_page(2)
	await t.frames(2)
	t.check("names_survive_back", select.get_node("%NameInput").text == "Måne" and select.get_node("%FarmNameInput").text == "Min gård")
	t.check("field_limits", select.get_node("%NameInput").max_length == 20 and select.get_node("%FarmNameInput").max_length == 24)
	for locale in ["da", "en"]:
		t.autoload("LocalizationManager").set_locale(locale)
		await t.frames(2)
		var rules := UiAudit.rule_report(select)
		t.check("select_rules_" + locale, rules.ok, str(rules.defects))
	select._set_page(1)
	await t.frames(2)
	t.tap_key(KEY_ESCAPE)
	await t.frames(4)
	t.check("back_restores_title_opener", t.tree.current_scene.get_viewport().gui_get_focus_owner() == t.tree.current_scene.get_node("%NewGameButton"))
	for path in ["settings_ui", "save_load_ui"]:
		var packed: PackedScene = load("res://scenes/ui/" + path + ".tscn")
		var screen: TTScreen = packed.instantiate()
		t.tree.root.add_child(screen)
		screen.open()
		await t.frames(2)
		t.check(path + "_screen_contract", screen.is_open() and screen.get_viewport().gui_get_focus_owner() != null)
		var rules := UiAudit.rule_report(screen)
		t.check(path + "_rules", rules.ok, str(rules.defects))
		if path == "settings_ui":
			await _settings(t, screen)
		screen.close()
		screen.free()
	await _real_new_games(t)
	t.autoload("EventBus").new_game_started.connect(func(): t.autoload("GameManager").set_flag(GameManager.FLAG_INTRO_PENDING, false), CONNECT_ONE_SHOT)
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var game_ui: GameUI = t.tree.get_first_node_in_group("game_ui")
	var pause: TTScreen = game_ui.get_screen(&"pause_menu")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("pause_opens", pause.is_open() and t.autoload("GameManager").top_modal() == &"pause")
	var pause_rules := UiAudit.rule_report(pause)
	t.check("pause_rules", pause_rules.ok, str(pause_rules.defects))
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("pause_second_esc_resumes", not pause.is_open() and not t.tree.paused)
	for flag in ["sleeping", "traveling"]:
		world.set(flag, true)
		t.tap_key(KEY_ESCAPE)
		await t.frames(2)
		t.expect(not pause.is_open() and not t.tree.paused, "Pause refused while " + flag)
		world.set(flag, false)
	await _all_pause_rows(t, pause, game_ui)
	await _save_flows(t, pause, game_ui)
	await _title_states(t)
	save_manager.save_dir = previous_save_dir

func _event(t, device: String, action: String) -> void:
	if device == "keyboard":
		var keys := {"right": KEY_RIGHT, "down": KEY_DOWN, "up": KEY_UP, "accept": KEY_ENTER}
		t.tap_key(keys[action])
	else:
		var buttons := {"right": JOY_BUTTON_DPAD_RIGHT, "down": JOY_BUTTON_DPAD_DOWN, "up": JOY_BUTTON_DPAD_UP, "accept": JOY_BUTTON_A}
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		event.pressed = true
		Input.parse_input_event(event)
		var release := InputEventJoypadButton.new()
		release.button_index = buttons[action]
		release.pressed = false
		Input.parse_input_event(release)
	await t.frames(2)

func _real_new_games(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var previous: String = sm.save_dir
	sm.save_dir = "user://menus-keypad-flows"
	for device in ["keyboard", "gamepad"]:
		for race in 4:
			for hero in 2:
				UiNav.remember(&"title", "")
				await t.go_menu()
				await t.frames(3)
				await _event(t, device, "accept")
				if t.tree.current_scene.scene_file_path != SELECT:
					t.fail("New game did not open select with " + device)
					continue
				for step in race:
					await _event(t, device, "right")
				await _event(t, device, "down")
				if hero == 1:
					await _event(t, device, "right")
				await _event(t, device, "up")
				await _event(t, device, "accept")
				await _event(t, device, "down")
				await _event(t, device, "down")
				await _event(t, device, "accept")
				var arrived: bool = await t.until(func(): return t.world() != null and t.player() != null, 10.0)
				var gm: Node = t.autoload("GameManager")
				var expected: Dictionary = CharacterCatalog.heroes(["animal", "fairy", "hobbit", "ghost"][race])[hero]
				t.check("%s_race_%d_hero_%d" % [device, race, hero], arrived and int(gm.character_type) == race and gm.character_skin == StringName(expected.skin), "expected " + str(expected.skin) + "; actual " + str(gm.character_skin))
				t.expect(gm.player_name == TranslationServer.translate("DEFAULT_PLAYER_NAME") and gm.farm_name == TranslationServer.translate("DEFAULT_FARM_NAME"), "Defaults accepted with " + device)
	sm.save_dir = previous

func _settings(t, settings: TTScreen) -> void:
	var config := ConfigFile.new()
	config.load(SettingsUI.PATH)
	config.set_value("other_owner", "kept", "unchanged")
	config.save(SettingsUI.PATH)
	for bus in SettingsUI.BUSES:
		var slider: TTSlider = settings.get_node("%" + bus + "Slider")
		slider.grab_focus()
		var before := slider.value
		t.tap_key(KEY_LEFT)
		await t.frames(2)
		t.expect(is_equal_approx(slider.value, before - 0.05), bus + " keyboard changes by five percent")
	var fullscreen: CheckBox = settings.get_node("%FullscreenCheck")
	fullscreen.grab_focus()
	t.tap_key(KEY_RIGHT)
	await t.frames(2)
	t.check("fullscreen_dims_size_chips", fullscreen.button_pressed and (settings.get_node("%Size0") as Button).disabled)
	t.tap_key(KEY_LEFT)
	await t.frames(2)
	t.check("window_mode_reenables_sizes", not fullscreen.button_pressed and not (settings.get_node("%Size0") as Button).disabled)
	settings.get_node("%Size0").grab_focus()
	t.tap_key(KEY_RIGHT)
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	settings.get_node("%LangDa").emit_signal("pressed")
	await t.frames(2)
	config.load(SettingsUI.PATH)
	t.check("settings_preserve_shared_file", config.get_value("other_owner", "kept") == "unchanged" and config.get_value("game", "locale") == "da" and is_equal_approx(float(config.get_value("audio", "master")), 0.75))
	var restarted: Dictionary = t.run_godot_script("res://tests/fixtures/ui_audit/settings_restart.gd")
	t.check("settings_persist_across_restart", restarted.code == 0 and restarted.output.contains("PASS menus.settings_persist_across_restart"), restarted.output)

func _save_flows(t, pause: TTScreen, game_ui: GameUI) -> void:
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var dir_before: String = sm.save_dir
	sm.save_dir = "user://menus-save-flow"
	pause.open()
	await t.frames(2)
	pause.get_node("%SaveButton").grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	var slots: TTScreen = game_ui.get_screen(&"save_load_ui")
	t.check("save_nests_under_pause", slots.is_open() and gm.modal_stack() == [&"pause", &"save_load"] and slots._rows.size() == 7)
	t.check("autosave_row_read_only", not UiNav.is_stop(slots._rows[6]) and not UiNav.is_stop(slots._deletes[6]))
	slots._rows[0].grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	t.check("empty_slot_saves_without_confirm", sm.has_save(0) and gm.modal_stack() == [&"pause", &"save_load"])
	var saved_gold: int = eco.gold
	eco.add_gold(77)
	slots._rows[0].grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	t.check("overwrite_asks_confirm", gm.modal_stack().size() == 3)
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("overwrite_cancel_keeps_file", int(sm.get_save_summary(0).gold) == saved_gold and gm.modal_stack() == [&"pause", &"save_load"])
	slots._rows[0].grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	t.tap_key(KEY_LEFT) # default Cancel -> OK
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	t.check("overwrite_accept_saves_once", int(sm.get_save_summary(0).gold) == saved_gold + 77 and gm.modal_stack() == [&"pause", &"save_load"])
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("save_close_returns_to_pause_opener", pause.get_viewport().gui_get_focus_owner() == pause.get_node("%SaveButton"))
	pause.get_node("%LoadButton").grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	slots._rows[0].grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	t.check("load_in_game_asks_confirm", gm.modal_stack().size() == 3)
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("load_cancel_keeps_game", eco.gold == saved_gold + 77)
	# Delete starts from the focused slot and defaults to Cancel.
	slots._rows[0].grab_focus()
	t.tap_key(KEY_DELETE)
	await t.frames(2)
	t.check("delete_key_asks_confirm", gm.modal_stack().size() == 3)
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("delete_cancel_keeps_file", sm.has_save(0))
	# A MacBook has no forward Delete: Backspace asks the same question (review UX-16).
	slots._rows[0].grab_focus()
	t.tap_key(KEY_BACKSPACE)
	await t.frames(2)
	t.check("backspace_key_asks_confirm", gm.modal_stack().size() == 3)
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("backspace_cancel_keeps_file", sm.has_save(0))
	sm.save_game(1)
	slots._refresh_texts()
	slots._rows[1].grab_focus()
	t.tap_key(KEY_DELETE)
	await t.frames(2)
	t.tap_key(KEY_LEFT)
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	t.check("delete_accept_removes_selected_only", not sm.has_save(1) and sm.has_save(0))
	slots._rows[0].grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(2)
	t.tap_key(KEY_LEFT)
	t.tap_key(KEY_ENTER)
	await t.frames(10)
	t.check("save_load_resume_roundtrip", t.world() != null and t.player() != null and not t.tree.paused and not gm.is_modal_open() and eco.gold == saved_gold + 77 and sm.current_slot == 0)
	sm.save_dir = dir_before

func run_windowed(t) -> void:
	const Fixtures := preload("res://scripts/ui/dev/ui_fixtures.gd")
	await t.clear_scene()
	for name in ["title_guide", "select_guide4", "select2", "settings", "saveload", "pause"]:
		var host := Control.new()
		host.process_mode = Node.PROCESS_MODE_ALWAYS
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.tree.root.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var screen: Node = await Fixtures.make(name, host)
		await t.frames(5)
		await t.capture(name)
		var refs := {"title_guide": "docs/qa/ui_baseline/title.png", "select_guide4": "tests/checkpoints/guide_ref_ghost/select_4cards.png", "select2": "docs/qa/ui_baseline/select_2.png", "settings": "docs/qa/ui_baseline/settings.png", "saveload": "docs/qa/ui_baseline/saveload.png", "pause": "docs/qa/ui_baseline/pause.png"}
		var shot: String = t.out_dir.path_join("menus_" + name + ".png")
		var result: Dictionary = t.run_tool(ProjectSettings.globalize_path("res://tools/art/.venv/bin/python"), PackedStringArray([ProjectSettings.globalize_path("res://tests/checkpoints/compare_guide.py"), shot, "--ref", ProjectSettings.globalize_path("res://" + refs[name]), "--no-frame-crop", "--max", "1.5", "--json"]))
		var parser := JSON.new()
		var parsed := parser.parse(result.output) == OK
		var compared: Variant = parser.data if parsed else null
		var comparisons: Array = compared.get("screens", {}).values() if compared is Dictionary else []
		t.check(name + "_reviewed_baseline", result.code == 0 and comparisons.size() == 1 and float(comparisons[0].get("mean", INF)) <= 1.5, result.output)
		var root := screen as Control
		var rect := root.get_global_rect()
		t.check(name + "_fits_viewport", rect.size == Vector2(1280, 720))
		if screen is TTScreen:
			var panel: Control = screen.get_node("Panel")
			t.check(name + "_panel_fits_720", panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 720, str(panel.get_global_rect()))
		host.free()
		t.autoload("GameManager").pop_all_modals()

	await t.start_world()
	var pause: TTScreen = t.world().game_ui.get_screen(&"pause_menu")
	pause.open()
	await t.frames(5)
	var panel: Control = pause.get_node("Panel")
	var names: Array = pause._rows.map(func(row):return str(row.name))
	t.check("full_game_pause_has_core_actions_and_test_menu",["ResumeButton","InventoryButton","MapButton","JournalButton","PeopleButton","BuildButton","WardrobeButton","CheatButton","SaveButton","LoadButton","SettingsButton","QuitButton","QuitGameButton"].all(func(id):return id in names) and pause._rows.size() in [13,14],str(names))
	t.check("full_game_pause_panel_fits",pause.get_global_rect().encloses(panel.get_global_rect()))
	pause._rows[-1].grab_focus()
	await t.frames(3)
	t.check("last_pause_row_visible_on_focus",pause.get_node("Panel/Body/MenuScroll").get_global_rect().encloses(pause._rows[-1].get_global_rect()))
	await t.capture("pause_full_game")
	pause.close()

func _title_states(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var previous: String = sm.save_dir
	var clock: float = sm.clock_override
	sm.save_dir = "user://menus-title-states"
	await t.go_menu()
	var title: Control = t.tree.current_scene
	t.check("title_no_saves", title.get_node("%ContinueButton").disabled and not title.get_node("%LoadButton").visible)
	sm.clock_override = 1000.0
	sm.save_game(0)
	title._refresh_labels()
	t.check("title_one_save", not title.get_node("%ContinueButton").disabled and not title.get_node("%LoadButton").visible)
	sm.clock_override = 1001.0
	gm.day = 7
	sm.save_game(1)
	title._refresh_labels()
	t.check("title_multiple_saves_and_latest_day", title.get_node("%LoadButton").visible and title.get_node("%ContinueInfo").text.contains("7"))
	# Files can disappear after the title enabled Continue. The failure needs visible feedback.
	sm.delete_save(0)
	sm.delete_save(1)
	title.get_node("%ContinueButton").grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	t.check("title_failure_toast_visible", t.tree.current_scene == title and title.get_node("%ToastStack")._entries.size() > 0)
	title._refresh_labels()
	await t.frames(2)
	t.check("title_returns_focus_after_save_removal", title.get_viewport().gui_get_focus_owner() == title.get_node("%NewGameButton"))
	sm.clock_override = clock
	sm.save_dir = previous

func _all_pause_rows(t, pause: TTScreen, game_ui: GameUI) -> void:
	var originals: Dictionary = game_ui._screens.duplicate()
	var stubs: Array[Node] = []
	for id in [&"inventory_ui", &"quest_journal", &"people", &"build_menu_ui", &"garderobe", &"samlerbog"]:
		if game_ui.get_screen(id) == null:
			var stub := Node.new()
			game_ui.add_child(stub)
			stubs.append(stub)
			game_ui._screens[id] = stub
	pause.open()
	await t.frames(3)
	var rect: Rect2 = pause.get_node("Panel").get_global_rect()
	t.check("all_pause_rows_fit_720", pause._rows.size() == 14 and rect.position.y >= 0 and rect.end.y <= 720, str(rect))
	game_ui._screens = originals
	for stub in stubs:
		stub.free()
	pause.close()
