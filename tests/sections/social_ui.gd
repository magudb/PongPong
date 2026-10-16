extends RefCounted
const SECTION := "social_ui"
const TIMEOUT_S := 180.0
const Fixture := preload("res://scripts/ui/social/social_fixtures.gd")
const Fixtures := preload("res://scripts/ui/dev/ui_fixtures.gd")
const Hud := preload("res://scripts/ui/social/social_hud.gd")

func _focus(t) -> Control:
	return t.root.gui_get_focus_owner()

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var ui: GameUI = t.tree.get_first_node_in_group("game_ui")
	var people: Control = ui.get_screen(&"people")
	var gift: Control = ui.get_screen(&"gift_ui")
	var journal: Control = ui.get_screen(&"quest_journal")
	var hud: Control = ui.get_screen(&"social_hud")
	t.check("all_four_screens_installed", people != null and gift != null and journal._calendar != null and hud != null)
	var glyph := SocialHearts.new()
	glyph.half_hearts = 15
	var plan := glyph.plan()
	t.check("glyph_is_not_health_hearts", plan.size() == 10 and plan.all(func(r): return r.sprout and not r.gold and r.outline == 2))
	t.check("glyph_half_heart_plan", plan[6].fill == "full" and plan[7].fill == "half_left" and plan[8].fill == "empty")
	glyph.free()
	Fixture.seed()
	people.last_talked = "gardener_hoppe"
	var started := Time.get_ticks_usec()
	people.open()
	var open_ms := (Time.get_ticks_usec() - started) / 1000.0
	await t.frames(4)
	t.check("people_initial_focus", _focus(t) == people._initial_focus() and people.selected_id == "gardener_hoppe")
	t.check("people_only_met_npcs", people.data == t.autoload("SocialManager").people_rows() and people.data.all(func(r): return t.autoload("SocialManager").met(r.id)))
	t.check("people_rows_nodes_max", people.list.get_child_count() <= 60 and people.list.get_children().all(func(r): return r.get_child_count() == 0))
	t.check("people_open_ms", open_ms <= 25.0, str(open_ms))
	t.check("glyph_in_people", not people.find_children("*", "SocialHearts", true, false).is_empty())
	for index in people.rows.size():
		var row: Button = people.rows[index]
		row.grab_focus()
		await t.frames(1)
		t.check("people_select_" + str(index), people.selected_id == row.row.id)
		t.check("people_up_link_" + str(index), row.get_node_or_null(row.focus_neighbor_top) == (people.tabs[0] if index == 0 else people.rows[index - 1]))
	t.tap(&"ui_page_down")
	await t.frames(3)
	t.check("people_tabs_page_actions", people.tab == 1 and people.rows.all(func(r): return int(r.row.hearts) >= 5))
	t.tap(&"ui_right")
	await t.frames(3)
	t.check("people_right_changes_tab", people.tab == 2)
	t.tap_key(KEY_P)
	await t.frames(3)
	t.check("people_p_closes", not people.is_open() and not gm.is_modal_open() and _focus(t) == null)
	t.tap_key(KEY_P)
	await t.frames(3)
	t.check("people_p_opens", people.is_open())
	UiAudit.press_pad(t, JOY_BUTTON_B)
	await t.frames(3)
	t.check("people_pad_closes", not people.is_open() and not gm.is_modal_open())
	people.tab = 0
	await _gifts(t, gift)
	await _gift_scroll(t, gift)
	await _live_transfer(t, gift)
	await _calendar(t, journal)
	await _hud(t, hud, ui)
	await t.clear_scene()
	for id in ["people", "gift", "calendar", "social_hud"]:
		var result: Dictionary = await UiAudit.audit_screen(t, id)
		t.check("registry_" + id, result.ok, str(result.defects))
	Fixture.cleanup()
	gm.clear_config_overrides()

func _gifts(t, gift: Control) -> void:
	var sm: Node = t.autoload("SocialManager")
	var gm: Node = t.autoload("GameManager")
	Fixture.seed()
	gift.open_for("gardener_hoppe")
	await t.frames(4)
	t.check("gift_initial_focus", _focus(t) == gift.slots[0])
	t.check("gift_options_from_api", gift.options == sm.gift_options("gardener_hoppe"))
	t.check("gift_grid_24_cells", gift.slots.size() == 24 and gift.grid.columns == 6)
	t.check("glyph_in_gift", gift.hearts.plan().all(func(r): return r.sprout))
	var index := -1
	for i in gift.options.size():
		if gift.options[i].id == "carrot":
			index = i
	t.check("cheap_live_gift_available", index >= 0)
	if index >= 0:
		gift.slots[index].grab_focus()
		await t.frames(2)
		t.check("gift_chip_text_not_colour_only", gift.taste.visible and gift.taste.text.contains(tr("REL_TASTE_LOVE")) and gift.taste.text.contains("♥"))
		t.tap(&"ui_accept")
		await t.frames(2)
		t.check("gift_accept_selects_then_gives", _focus(t) == gift.give and gift.is_open())
		var eco: Node = t.autoload("EconomyManager")
		var before: int = eco.count_item(&"carrot")
		var hearts: int = sm.row_of("gardener_hoppe").p
		t.tap(&"ui_accept")
		await t.frames(3)
		var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
		t.check("gift_picker_closes_before_reaction", not gift.is_open() and screen.is_open() and gm.top_modal() == &"dialogue")
		t.check("gift_removes_once_and_pays_love", eco.count_item(&"carrot") == before - 1 and sm.row_of("gardener_hoppe").p == hearts + 40, str(sm.row_of("gardener_hoppe")))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		t.check("reaction_escape_no_weekly_heart", sm.row_of("gardener_hoppe").p == hearts + 40 and not gm.is_modal_open())
	gift.open_for("gardener_hoppe")
	await t.frames(3)
	t.check("gift_limits_disable_give_with_reason", gift.give.disabled and gift.give.focus_mode == Control.FOCUS_NONE and gift.reason.text != "")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("gift_esc_restores_world", not gm.is_modal_open() and _focus(t) == null)
	Fixture.seed()
	var eco: Node = t.autoload("EconomyManager")
	var valuable := ""
	for id in t.autoload("LuaRuntime").get_all_item_ids():
		if GiftRules.giftable(id, eco.item_def(id), eco.sell_value(id)).ok and GiftRules.needs_confirm(id, eco.item_def(id), eco.sell_value(id)) and GiftFlow.protection(id, eco.item_def(id)) == "":
			valuable = str(id)
			break
	t.check("valuable_fixture_exists", valuable != "")
	if valuable != "":
		eco.add_item(valuable, 1)
		gift.open_for("gardener_hoppe")
		await t.frames(2)
		for i in gift.options.size():
			if gift.options[i].id == valuable:
				gift._activate(i)
		t.tap(&"ui_accept")
		await t.frames(3)
		var confirm: Control = gift.get_children().filter(func(n): return n is UiConfirm)[0]
		t.check("gift_confirm_for_valuable_default_fortryd", _focus(t) == confirm.get_node("%CancelButton"))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		t.check("gift_confirm_cancel_retains_item", eco.count_item(valuable) >= 1 and gift.is_open())
		gift.close()
		await t.frames(2)

func _calendar(t, journal: Control) -> void:
	Fixture.seed()
	Fixture.festival()
	journal.open()
	journal._set_tab(2)
	var calendar: Control = journal._calendar
	await t.frames(3)
	t.check("calendar_28_cells", calendar.cells.size() == 28)
	t.check("calendar_only_known_birthdays", calendar.entries.all(func(row): return row.kind != "birthday" or row.known))
	t.check("calendar_festivals_always_shown", calendar.entries.any(func(row): return row.kind == "festival" and row.id == "social_ui_fixture"))
	t.check("calendar_today_marked", calendar.cells[8].theme_type_variation == &"CalCellToday" and calendar.today_markers[8].text == tr("REL_CAL_TODAY"))
	t.check("calendar_uses_theme_variations_only", calendar.cells.all(func(cell): return not cell.has_theme_stylebox_override("normal") and str(cell.theme_type_variation).begins_with("CalCell")))
	for index in 3:
		journal._tabs[1].grab_focus()
		await t.frames(1)
		journal._tabs[2].grab_focus()
		await t.frames(1)
		t.tap(&"ui_down")
		await t.frames(2)
		t.check("calendar_focus_switch_keeps_new_navigation_" + str(index), _focus(t) == calendar.chips[0])
	for index in 4:
		calendar._season(index)
		journal._tabs[2].grab_focus()
		t.tap(&"ui_down")
		await t.frames(2)
		t.check("calendar_header_reaches_season_" + str(index), _focus(t) == calendar.chips[0], str(_focus(t)))
		t.tap(&"ui_left")
		await t.frames(2)
		t.check("calendar_season_ring_" + str(index), _focus(t) == calendar.chips[3], str(_focus(t)))
	calendar._season(2)
	for i in calendar.cells.size():
		var cell: Button = calendar.cells[i]
		t.check("calendar_grid_right_" + str(i), i % 7 == 6 or cell.get_node_or_null(cell.focus_neighbor_right) == calendar.cells[i + 1])
	calendar.cells[27].grab_focus()
	t.tap(&"ui_right")
	await t.frames(3)
	t.check("calendar_season_walks_over_month_edge", calendar.season_index == 3 and _focus(t) == calendar.cells[0])
	t.tap(&"ui_left")
	await t.frames(3)
	t.check("calendar_walks_back_over_edge", calendar.season_index == 2 and _focus(t) == calendar.cells[27])
	calendar.year = 1
	calendar.season_index = 0
	calendar.refresh()
	calendar.cells[0].grab_focus()
	t.tap(&"ui_left")
	await t.frames(3)
	t.check("calendar_year_one_floor", calendar.year == 1 and calendar.season_index == 0 and _focus(t) == calendar.cells[0])
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("calendar_journal_escape", not journal.is_open())
	Fixture.cleanup()

func _gift_scroll(t, gift: Control) -> void:
	Fixture.seed()
	var eco: Node = t.autoload("EconomyManager")
	var inventory: Array = eco.inventory.duplicate(true)
	# A future wardrobe or migrated stock can expose more stacks than the
	# backpack's 24 cells. Stress the real API with distinct live item defs.
	eco.inventory.clear()
	for id in t.autoload("LuaRuntime").get_all_item_ids():
		if GiftRules.giftable(id, eco.item_def(id), eco.sell_value(id)).ok and GiftFlow.protection(id, eco.item_def(id)) == "":
			eco.inventory.append({"id": StringName(str(id)), "amount": 2})
			if eco.inventory.size() >= 36:
				break
	gift.open_for("gardener_hoppe")
	await t.frames(3)
	t.check("gift_grid_scrolls_over_24_stacks", gift.options.size() > 24 and gift.slots.size() >= 30 and gift.slots.size() % 6 == 0)
	gift.slots.back().grab_focus()
	await t.frames(4)
	var scroll: ScrollContainer = gift.grid.get_parent().get_parent()
	t.check("gift_scroll_follows_last_row", scroll.scroll_vertical > 0 and _focus(t) == gift.slots.back())
	UiAudit.press_pad(t, JOY_BUTTON_A)
	await t.frames(3)
	t.check("gift_pad_accept_selects_then_give", _focus(t) == gift.give)
	gift.close()
	eco.inventory.assign(inventory)
	await t.frames(3)

func _live_transfer(t, gift: Control) -> void:
	Fixture.seed()
	var gm: Node = t.autoload("GameManager")
	gm.hour = 10
	await t.world().travel(&"traetoppen", &"default")
	var actor: Node = NpcDirector.node_of("gardener_hoppe")
	t.check("live_gift_citizen_present", actor != null)
	if actor == null:
		return
	actor.interact(t.player())
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	screen.chars_per_second = 100000
	for i in 30:
		if screen._wants_focus():
			break
		t.tap(&"interact")
		await t.frames(2)
	var transferred := false
	for i in screen._choices.size():
		if str(screen._choices[i].get("action", "")) == "give_gift":
			screen._buttons[i].pressed.emit()
			transferred = true
			break
	await t.frames(3)
	t.check("live_dialogue_transfers_to_picker", transferred and not screen.is_open() and gift.is_open() and not actor.is_talking)
	t.check("live_actor_held_by_picker", actor._held)
	if gift.is_open():
		var index: int = gift.options.find_custom(func(row): return str(row.id) == "carrot")
		t.check("live_carrot_available", index >= 0)
		if index >= 0:
			gift._activate(index)
			UiAudit.press_pad(t, JOY_BUTTON_A)
			await t.frames(3)
			t.check("live_actor_held_during_reaction", not gift.is_open() and screen.is_open() and actor._held)
			t.tap_key(KEY_ESCAPE)
			await t.frames(3)
			t.check("live_reaction_releases_actor_and_player", not actor._held and t.player().state == PlayerBody2D.S.FREE and not gm.is_modal_open())
	else:
		screen.close()
		await t.frames(3)
	await t.world().travel(&"farm", &"from_traetoppen")

func _hud(t, hud: Control, ui: GameUI) -> void:
	var gm: Node = t.autoload("GameManager")
	t.check("hud_focus_none", UiAudit.focusable_report(hud, {"forbid_focus": true}).ok and hud.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	t.check("hud_no_polling", not hud.is_processing())
	var raw := Hud.ribbon_text("Test", {"from": 12, "to": 25}, 24.5)
	t.check("hud_festival_ribbon_raw_25", raw.contains("01:00") and not raw.contains("25:00"), raw)
	t.check("hud_festival_before_open", Hud.ribbon_text("Test", {"from": 12, "to": 25}, 10).contains("12:00"))
	var birthday := SocialData.birthday_of("gardener_hoppe")
	gm.season = StringName(birthday.season)
	gm.day = int(birthday.day)
	t.autoload("EventBus").day_started.emit(gm.day, gm.season)
	t.check("hud_birthday_chips", hud.birthday_chips.get_child_count() >= 1)
	t.check("glyph_in_social_hud", not hud.birthday_chips.find_children("*", "SocialHearts", true, false).is_empty())
	ui.set_mode(&"action")
	t.check("hud_hidden_in_action_mode", not hud.visible)
	ui.set_mode(&"farm")
	gm.push_modal(&"event", false)
	t.check("hud_hidden_in_event", not hud.visible)
	gm.push_modal(&"confirm", false)
	t.check("hud_hidden_behind_event_confirmation", not hud.visible)
	gm.pop_modal(&"confirm")
	gm.pop_modal(&"event")
	t.check("hud_returns_to_farm", hud.visible)

func run_windowed(t) -> void:
	await t.clear_scene()
	Fresh.new_game(t)
	for id in ["people", "gift", "calendar", "social_hud"]:
		var host := Control.new()
		host.process_mode = Node.PROCESS_MODE_ALWAYS
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.tree.root.add_child(host)
		var node: Control = await Fixtures.make(id, host)
		await t.frames(5)
		await t.capture(id)
		if id == "people":
			t.check("people_native_open_ms", float(node.get_meta("open_ms")) <= 25, str(node.get_meta("open_ms")))
		for locale in ["da", "en"]:
			t.autoload("LocalizationManager").set_locale(locale)
			await t.frames(3)
			var report := UiAudit.rule_report(node)
			t.check(id + "_rules_" + locale, report.ok, str(report.defects))
		t.autoload("LocalizationManager").set_locale("da")
		if id in ["people", "gift"]:
			UiAudit.expect(t, await UiAudit.panel_pixels(t, node.book if id == "people" else node.panel), id + "_panel")
		if id != "social_hud":
			UiAudit.expect(t, await UiAudit.ring_pixels(t, _focus(t), {"focus": false, "shot": id + "_ring"}), id + "_focus")
		if node.has_method("close"):
			node.close()
		host.free()
	Fixture.cleanup()
	var compared: Dictionary = t.run_tool(ProjectSettings.globalize_path("res://tools/art/.venv/bin/python"), [ProjectSettings.globalize_path("res://tools/ui/compare_social.py"), "--shots", t.out_dir, "--report", t.out_dir.path_join("comparison.json")])
	t.check("reviewed_screen_baselines", compared.code == 0, compared.output)
	await t.start_world()
	var ui: GameUI = t.tree.get_first_node_in_group("game_ui")
	var hud: Control = ui.get_screen(&"social_hud")
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
	Fixture.seed()
	var birthday := SocialData.birthday_of("gardener_hoppe")
	t.autoload("GameManager").season = StringName(birthday.season)
	t.autoload("GameManager").day = int(birthday.day)
	Fixture.festival()
	t.autoload("QuestManager").accept_quest(&"lost_cat")
	t.autoload("EventBus").day_started.emit(t.autoload("GameManager").day, t.autoload("GameManager").season)
	t.autoload("EventBus").time_of_day_changed.emit(t.autoload("GameManager").hour, t.autoload("GameManager").minute)
	hud.refresh()
	await t.frames(5)
	var farm_hud: Control = ui.get_screen(&"hud")
	farm_hud.toasts.clear()
	for child in farm_hud.find_children("*", "Control", true, false):
		if child.has_method("shown_text") and child.has_method("_hide"):
			child._hide()
	await t.frames(2)
	await t.capture("farm_social_hud")
	t.check("birthday_chips_leave_space_for_quests", not hud.birthday_chips.get_global_rect().intersects(farm_hud.quest_card.get_global_rect()))
	var journal: Control = ui.get_screen(&"quest_journal")
	journal.open()
	journal._set_tab(2)
	await t.frames(4)
	await t.capture("journal_calendar")
	t.check("calendar_in_real_journal", journal._calendar.is_visible_in_tree() and journal._tabs.size() == 3)
	journal.close()
	Fixture.cleanup()
	t.autoload("GameManager").clear_config_overrides()
