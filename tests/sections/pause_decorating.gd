extends RefCounted
const SECTION := "pause_decorating"
const TIMEOUT_S := 90.0

func run(t) -> void:
	await _exercise(t)

func run_windowed(t) -> void:
	await _exercise(t, true)

func _press(t, device: String, action: String) -> void:
	if device == "keyboard":
		t.tap_key({"down": KEY_DOWN, "accept": KEY_ENTER, "back": KEY_ESCAPE}[action])
	else:
		UiAudit.press_pad(t, {"down": JOY_BUTTON_DPAD_DOWN, "accept": JOY_BUTTON_A, "back": JOY_BUTTON_B}[action])
	await t.frames(3)

func _exercise(t, native: bool = false) -> void:
	var previous_locale := TranslationServer.get_locale()
	t.on_cleanup(func(): t.autoload("LocalizationManager").set_locale(previous_locale))
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var pause: TTScreen = world.game_ui.get_screen(&"pause_menu")
	var decorate: TTScreen = world.game_ui.get_screen(&"indretning")
	var gm: Node = t.autoload("GameManager")
	var furniture: Node = t.autoload("FurnitureManager")
	for area in [&"farm", &"traetoppen"]:
		if world.area.map.id != area:
			await world.travel(area, &"default")
		pause.open()
		await t.frames(3)
		t.check("no_decorating_entry_in_" + str(area), pause.get_node_or_null("%DecorateButton") == null)
		pause.close()
	await world.travel(&"home", &"default")
	pause.open()
	await t.frames(3)
	var button := pause.get_node_or_null("%DecorateButton") as Button
	t.check("home_has_primary_decorating_entry", button != null and button.is_visible_in_tree() and not button.disabled)
	if button == null:
		pause.close()
		return
	for locale in ["da", "en"]:
		t.autoload("LocalizationManager").set_locale(locale)
		await t.frames(3)
		t.check("decorating_entry_translated_" + locale, button.text == TranslationServer.translate("INDRET_TITLE") and button.text != "INDRET_TITLE")
		if native:
			# Fixture travel and locale changes post temporary banners over the menu.
			world.game_ui.get_screen(&"hud").toasts.clear()
			await t.capture("home_pause_" + locale)
	var rules := UiAudit.rule_report(pause)
	t.check("home_pause_layout_and_navigation_rules", rules.ok, str(rules.defects))
	for device in ["keyboard", "gamepad"]:
		if not pause.is_open():
			pause.open()
		await t.frames(3)
		button = pause.get_node_or_null("%DecorateButton") as Button
		var visited := 0
		while pause.get_viewport().gui_get_focus_owner() != button and visited < pause._rows.size():
			await _press(t, device, "down")
			visited += 1
		var reached: bool = button != null and pause.get_viewport().gui_get_focus_owner() == button
		t.check(device + "_navigates_to_decorating", reached)
		var position: Vector2 = world.player.global_position
		await _press(t, device, "accept")
		t.check(device + "_opens_real_decorating_screen", reached and decorate.is_open() and not pause.is_open() and gm.top_modal() == &"indretning" and furniture.decorate_mode)
		t.check(device + "_transfer_does_not_move_player", world.player.global_position.is_equal_approx(position))
		await _press(t, device, "back")
		t.check(device + "_closes_decorating_to_world", not decorate.is_open() and not pause.is_open() and not furniture.decorate_mode and not gm.is_modal_open() and not t.tree.paused)
	await world.travel(&"farm", &"default")
	pause.open()
	await t.frames(3)
	t.check("entry_removed_after_leaving_home", pause.get_node_or_null("%DecorateButton") == null)
	pause.close()
