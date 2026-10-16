extends RefCounted
const SECTION := "farm_first_morning"
const TIMEOUT_S := 180.0

func _screen(t) -> Control:
	return t.tree.get_first_node_in_group("dialogue_ui")

func _opening(t, check_glyphs := false) -> void:
	var gm: Node = t.autoload("GameManager")
	var end := Time.get_ticks_msec() + 60000
	var checked := false
	while not bool(gm.get_flag(&"intro_done", false)) and Time.get_ticks_msec() < end:
		var screen := _screen(t)
		if screen != null and screen.is_open():
			if check_glyphs and not checked and screen._line >= 0 and screen._line < screen._lines.size():
				var row: Dictionary = screen._lines[screen._line]
				if str(row.get("text_key", "")) == "DLG_FARMINTRO_PIP_BYE_1":
					UiAudit.press_pad(t, JOY_BUTTON_X)
					await t.frames(2)
					var text: String = screen.get_node("%TextLabel").text
					t.check("dialogue_glyphs_follow_pad", text.contains("D-pad") and text.contains("X") and not text.contains("%s"), text)
					t.tap_key(KEY_SHIFT)
					await t.frames(2)
					text = screen.get_node("%TextLabel").text
					t.check("dialogue_glyphs_return_to_keyboard", text.contains("1") and text.contains(UiHints.glyph(&"use_tool", &"keyboard")) and not text.contains("%s"), text)
					checked = true
			t.tap(&"ui_accept" if screen._wants_focus() else &"interact")
			await t.frames(2)
		else:
			await t.physics(2)
	t.check("opening_finishes", bool(gm.get_flag(&"intro_done", false)))
	await t.frames(4)

func run(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var sm: Node = t.autoload("SocialManager")
	var bus: Node = t.autoload("EventBus")
	var starts: Array = []
	var endings: Array = []
	var steps: Array = []
	var start := func(npc, _module): starts.append(str(npc))
	var ending := func(): endings.append(true)
	var step := func(id, payload):
		if id == &"tutorial_step":
			steps.append(str(payload.kind))
	bus.dialogue_started.connect(start)
	bus.dialogue_ended.connect(ending)
	bus.game_event.connect(step)
	await t.start_world("", "Mia", "Lillegren", "", true)
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	await t.until(func(): return _screen(t).is_open(), 10)
	var courier: Npc2D
	var count := 0
	for actor in t.tree.get_nodes_in_group("npc"):
		if str(actor.get("npc_id")) == "postman_pip":
			courier = actor
			count += 1
	t.check("one_temporary_pip_at_mailbox", count == 1 and courier != null and courier.guest)
	var ref: WeakRef = weakref(courier)
	t.check("first_page_is_pip", _screen(t)._speaker.id == "postman_pip" and _screen(t)._lines.size() == 3)
	t.check("scripted_pages_opt_out_of_social_decoration", t.autoload("LuaRuntime").get_dialogue("farm_intro_pip", {}).get("social", true) == false)
	await _opening(t, true)
	t.check("sequence_order", starts == ["postman_pip", "fairy_king", "postman_pip"], str(starts))
	t.check("dialogue_ended_exactly_once_per_conversation", endings.size() == 3, str(endings.size()))
	var configured: Array = LuaData.arr(gm.config_value("farm_tutorial.first_morning.steps", [])).map(func(row): return str(row.kind))
	t.check("steps_are_data_driven", steps == configured, str(steps))
	t.check("both_starter_quests_active", qm.is_active(&"intro_lottery") and qm.is_active(&"forste_dage"))
	t.check("pip_is_met_and_weekly_heart_paid_once", sm.met("postman_pip") and sm.hearts("postman_pip") == 1)
	t.check("pip_freed_after_leaving", ref.get_ref() == null)
	t.check("player_free_after_sequence", t.player().state == PlayerBody2D.S.FREE and gm.current_phase == gm.GamePhase.PLAYING and not gm.is_modal_open())
	var snapshot := starts.size()
	await preload("res://scripts/world2d/intro_sequence.gd").run(t.world())
	t.check("opening_runs_once", starts.size() == snapshot and not _screen(t).is_open())
	bus.dialogue_started.disconnect(start)
	bus.dialogue_ended.disconnect(ending)
	bus.game_event.disconnect(step)
	await _hints_and_quest(t)
	await _continue(t)
	await _extension_and_fallback(t)
	await _skip_and_dispose(t)
	var validation: Dictionary = t.run_tool("python3", ["-B", "-I", ProjectSettings.globalize_path("res://tools/farm_tutorial/tutorial_check.py"), "--selftest"])
	t.check("installed_references_and_five_mutants", validation.code == 0, validation.output)
	var csv := FileAccess.open("res://localization/farm_tutorial.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() != 3 or row[0] == "":
			continue
		for i in [1, 2]:
			t.autoload("LocalizationManager").set_locale("da" if i == 1 else "en")
			t.check("copy_" + row[0] + str(i), tr(row[0]) == row[i])
	t.autoload("LocalizationManager").set_locale("da")
	gm.clear_config_overrides()

func _hints_and_quest(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var bus: Node = t.autoload("EventBus")
	var engine: TutorialHints = t.world().get_node("FarmTutorialHints")
	engine.set_process(false)
	engine.queued.clear()
	engine.last_shown = -1000
	for row in engine.hints:
		gm.clear_flag(StringName("tut_hint_" + str(row.id)))
	var shown: Array = []
	var listen := func(id, payload):
		if id == &"tutorial_hint_shown":
			shown.append(payload.id)
	bus.game_event.connect(listen)
	engine.request("hoe")
	engine.request("seeds")
	engine.tick(0)
	engine.tick(11.99)
	t.check("hints_wait_twelve_seconds", shown == ["hoe"])
	engine.tick(12)
	t.check("next_hint_after_gap", shown == ["hoe", "seeds"])
	engine.request("hoe")
	engine.tick(24)
	t.check("hint_once_per_save", shown.count("hoe") == 1)
	gm.push_modal(&"hint_probe", false)
	engine.request("can")
	engine.tick(36)
	t.check("hints_wait_for_modals", shown.size() == 2)
	gm.pop_modal(&"hint_probe")
	engine.tick(36)
	t.check("hints_resume_after_modal", shown.back() == "can")
	var seed_hint: Dictionary = engine.hints.filter(func(row): return row.id == "seeds")[0]
	t.check("starter_seed_slot_is_seven", seed_hint.glyph == "slot_7" and t.player().hotbar.slots[6] == &"turnip_seeds")
	t.check("pad_has_real_hotbar_actions", InputMap.has_action(&"hotbar_previous") and InputMap.has_action(&"hotbar_next") and UiHints.glyph_pair(&"hotbar_previous", &"hotbar_next", &"gamepad") == "D-pad")
	var before: int = t.player().hotbar.selected
	UiAudit.press_pad(t, JOY_BUTTON_DPAD_RIGHT)
	await t.frames(2)
	t.check("pad_cycles_real_hotbar", t.player().hotbar.selected == posmod(before + 1, 8))
	t.tap_key(KEY_SHIFT)
	for locale in ["da", "en"]:
		t.autoload("LocalizationManager").set_locale(locale)
		var bridge := tr("TUT_HINT_BRIDGE")
		t.check("bridge_names_home_builder_" + locale, bridge.contains("Hasselnød") and bridge.contains("Hyggebyen") and bridge.length() <= 90)
	t.autoload("LocalizationManager").set_locale("da")
	var box: PostBox2D = t.world().area.find_markers("mailbox")[0].node
	box.interact(t.player())
	t.check("day_one_mail_objective_stays_empty", int(qm.get_objective_progress(&"forste_dage", &"mail").current) == 0)
	for i in 3:
		bus.game_event.emit(&"plot_tilled", {"plot_id": str(i)})
		bus.crop_planted.emit(StringName(str(i)), &"turnip")
		bus.crop_watered.emit(StringName(str(i)))
	bus.crop_harvested.emit(&"0", &"turnip", 1)
	for id in ["till", "plant", "water", "harvest"]:
		t.check("quest_event_" + id, bool(qm.get_objective_progress(&"forste_dage", StringName(id)).done))
	gm.end_day()
	await t.physics(3)
	box.interact(t.player())
	await t.frames(3)
	if _screen(t).is_open():
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
	t.check("day_two_mail_completes_tutorial", qm.is_completed(&"forste_dage") and bool(gm.get_flag(&"tut_done", false)))
	var total := shown.size()
	engine.request("expand")
	engine.tick(100)
	t.check("hints_stop_after_quest", shown.size() == total)
	bus.game_event.disconnect(listen)

func _continue(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var directory: String = saves.save_dir
	saves.save_dir = "user://first-morning-roundtrip"
	t.expect(saves.save_game(0), "Save completed first morning")
	var old_id: int = t.world().get_instance_id()
	t.expect(saves.load_and_enter(0), "Continue after first morning")
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_id and t.player() != null, 10)
	await t.physics(6)
	t.check("continue_never_replays_opening", not _screen(t).is_open() and bool(t.autoload("GameManager").get_flag(&"intro_done", false)))
	t.check("hints_attach_on_continue", t.world().has_node("FarmTutorialHints"))
	saves.save_dir = directory

func _skip_and_dispose(t) -> void:
	await t.start_world("", "Mia", "Lillegren", "", true)
	await t.until(func(): return _screen(t).is_open(), 10)
	t.tap_key(KEY_ESCAPE)
	await t.frames(6)
	var gm: Node = t.autoload("GameManager")
	t.check("escape_skips_whole_sequence", bool(gm.get_flag(&"intro_done", false)) and not _screen(t).is_open())
	t.check("escape_still_accepts_both_quests", t.autoload("QuestManager").is_active(&"intro_lottery") and t.autoload("QuestManager").is_active(&"forste_dage"))
	var actor := Npc2D.create({"id": "postman_pip", "wander": "0"})
	actor.area = t.world().area
	t.world().area.objects.add_child(actor)
	var ticket := actor.event_walk_to(actor.global_position + Vector2(1000, 0), 1)
	var results: Array = []
	var waiter := func(): results.append(await ticket)
	waiter.call()
	actor.queue_free()
	await t.frames(3)
	t.check("disposing_walker_resolves_await_without_engine_error", results == [false])
	await t.start_world("", "Mia", "Lillegren", "", true)
	await t.until(func(): return _screen(t).is_open(), 10)
	await t.clear_scene()
	await t.frames(5)
	t.check("disposing_opening_releases_modal", not gm.is_modal_open())


func _extension_and_fallback(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var lr: Node = t.autoload("LuaRuntime")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var path := "user://tutorial-extra.lua"
	var source := FileAccess.get_file_as_string("res://lua/farm/farm_tutorial.lua")
	source = source.replace('hints = {', 'hints = { { id = "extra", key = "TUT_HINT_EXTRA", glyph = "", on = "step_done" },')
	source = source.replace('{ kind = "hint", id = "hoe" },', '{ kind = "hint", id = "hoe" }, { kind = "wait", seconds = 0.01 }, { kind = "hint", id = "extra" },')
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	var dir := "user://tutorial-extra-copy"
	DirAccess.make_dir_recursive_absolute(dir)
	file = FileAccess.open(dir + "/farm_tutorial.csv", FileAccess.WRITE)
	file.store_string("keys,da,en\nTUT_HINT_EXTRA,En lille pause er også gårdarbejde.,A little rest is farm work too.\n")
	file.close()
	var parsed: Dictionary = preload("res://scripts/autoload/localization_manager.gd").parse_dir(dir)
	var translations: Array[Translation] = []
	for locale in ["da", "en"]:
		var translation := Translation.new()
		translation.locale = locale
		translation.add_message(&"TUT_HINT_EXTRA", parsed.rows.TUT_HINT_EXTRA.text[locale])
		TranslationServer.add_translation(translation)
		translations.append(translation)
	t.check("extra_copy_uses_real_csv_parser", parsed.rows.has("TUT_HINT_EXTRA"))
	t.expect(lr.load_file(path) != "", "Load additional tutorial data through real LuaRuntime")
	var hints: TutorialHints = t.world().get_node("FarmTutorialHints")
	hints.refresh_data()
	var waits: Array = []
	var listener := func(id, payload):
		if id == &"tutorial_step" and str(payload.kind) == "wait":
			waits.append(true)
	t.autoload("EventBus").game_event.connect(listener)
	preload("res://scripts/world2d/intro_sequence.gd").run(t.world())
	await _opening(t)
	t.autoload("EventBus").game_event.disconnect(listener)
	hints.set_process(false)
	hints.tick(float(Time.get_ticks_msec()) / 1000.0 + 12.1)
	t.check("extend_with_eleventh_hint_and_extra_step_by_data", hints.hints.size() == 11 and waits.size() == 1 and bool(gm.get_flag(&"tut_hint_extra", false)))
	for locale in ["da", "en"]:
		t.autoload("LocalizationManager").set_locale(locale)
		t.check("extra_copy_resolves_" + locale, tr("TUT_HINT_EXTRA") == parsed.rows.TUT_HINT_EXTRA.text[locale])
	for translation in translations:
		TranslationServer.remove_translation(translation)
	lr.reload_scripts()
	t.autoload("LocalizationManager").set_locale("da")
	await t.start_world()
	gm.set_config_override("farm_tutorial.first_morning.enabled", false)
	var done: Array = []
	var launch := func():
		await preload("res://scripts/world2d/intro_sequence.gd").run(t.world())
		done.append(true)
	launch.call()
	await t.frames(3)
	t.check("disabled_falls_back_to_letter_only", _screen(t).is_open() and _screen(t)._speaker.id == "fairy_king")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("fallback_accepts_only_original_quest", done.size() == 1 and t.autoload("QuestManager").is_active(&"intro_lottery") and not t.autoload("QuestManager").is_active(&"forste_dage") and not bool(gm.get_flag(&"intro_done", false)))
	gm.clear_config_overrides()


func run_windowed(t) -> void:
	await t.start_world("", "Mia", "Lillegren", "", true)
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var captured := {}
	var deadline := Time.get_ticks_msec() + 60000
	while not bool(gm.get_flag(&"intro_done", false)) and Time.get_ticks_msec() < deadline:
		var screen := _screen(t)
		if screen != null and screen.is_open():
			var key := str(screen._lines[0].get("text_key", "")) if not screen._lines.is_empty() else ""
			screen.chars_per_second = 100000.0
			if key != "" and not captured.has(key):
				await t.frames(5)
				await t.capture(key.to_lower())
				UiAudit.expect(t, await UiAudit.panel_pixels(t, screen.get_node("%Box")), "opening_panel_" + key)
				captured[key] = true
			if screen._wants_focus() and not captured.has("choices"):
				await t.frames(3)
				UiAudit.expect(t, await UiAudit.ring_pixels(t, screen._buttons[0], {"focus": false, "shot": "pip_choice_focus"}), "pip_choice_focus")
				captured["choices"] = true
			t.tap(&"ui_accept" if screen._wants_focus() else &"interact")
			await t.frames(2)
		else:
			await t.physics(2)
	t.check("native_complete_opening", bool(gm.get_flag(&"intro_done", false)) and captured.size() >= 4 and not gm.is_modal_open())
	await t.frames(5)
	await t.capture("player_free")
	gm.clear_config_overrides()
