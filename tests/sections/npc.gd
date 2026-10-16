extends RefCounted
const SECTION := "npc"
const TIMEOUT_S := 240.0
var _actor: Npc2D

func run_windowed(t) -> void:
	await t.clear_scene()
	Fresh.new_game(t)
	for id in ["dialogue", "intro", "journal", "dialogue_guide", "journal_guide"]:
		var host := Control.new()
		host.process_mode = Node.PROCESS_MODE_ALWAYS
		t.tree.root.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var screen: Control = await preload("res://scripts/ui/dev/ui_fixtures.gd").make(id, host)
		await t.frames(4)
		await t.capture(id)
		if not id.ends_with("_guide"):
			var baseline: String = "res://docs/qa/ui_baseline/" + id + ".png"
			t.check(id + "_baseline_exists", FileAccess.file_exists(baseline))
			if FileAccess.file_exists(baseline):
				var result: Dictionary = t.run_tool(ProjectSettings.globalize_path("res://tools/art/.venv/bin/python"), PackedStringArray([ProjectSettings.globalize_path("res://tests/checkpoints/compare_guide.py"), t.out_dir.path_join("npc_" + id + ".png"), "--ref", ProjectSettings.globalize_path(baseline), "--no-frame-crop", "--max", "1.5", "--json"]))
				t.check(id + "_reviewed_baseline", result.code == 0, result.output)
		var panel: Control = screen.get_node("%Book") if id.begins_with("journal") else screen.get_node("%Box")
		var rect := panel.get_global_rect()
		if id == "dialogue_guide":
			var frame: Image = await t.capture()
			frame.get_region(Rect2i(Vector2i(rect.position) - Vector2i(10, 10), Vector2i(680, 300))).save_png(t.out_dir.path_join("npc_dialogue_crop.png"))
		t.check(id + "_fits_viewport", rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 1280 and rect.end.y <= 720, str(rect))
		UiAudit.expect(t, await UiAudit.panel_pixels(t, panel, {"shot": id + "_panel"}), id + "_panel_pixels")
		var focus := screen.get_viewport().gui_get_focus_owner()
		if id == "intro":
			t.check("intro_text_has_no_focus", focus == null)
		elif not id.ends_with("_guide"):
			UiAudit.expect(t, await UiAudit.ring_pixels(t, focus, {"focus": false, "shot": id + "_focus"}), id + "_focus_pixels")
		for locale in (["da"] if id.ends_with("_guide") else ["da", "en"]):
			t.autoload("LocalizationManager").set_locale(locale)
			await t.frames(3)
			var rules := UiAudit.rule_report(screen)
			t.check(id + "_native_rules_" + locale, rules.ok, str(rules.defects))
		t.autoload("LocalizationManager").set_locale("da")
		screen.close()
		host.free()
	var compared: Dictionary = t.run_tool(ProjectSettings.globalize_path("res://tools/art/.venv/bin/python"), PackedStringArray([ProjectSettings.globalize_path("res://tools/ui/compare_conversation.py"), "--shots", t.out_dir]))
	t.check("original_guide_conversations", compared.code == 0, compared.output)

func run(t) -> void:
	if OS.get_environment("TRAETOPPEN_BAKE_CONVERSATION") == "1":
		var built: Dictionary = t.run_godot_script("res://tools/ui/bake_conversation.gd")
		t.check("scenes_compile", built.code == 0 and not built.output.contains("ERROR:") and not built.output.contains("WARNING:"), built.output)
	await t.start_world()
	var ui: GameUI = t.tree.get_first_node_in_group("game_ui")
	var dialogue: Control = ui.get_screen(&"dialogue_ui")
	t.check("real_conversation_screens", dialogue != null and ui.has_screen(&"quest_journal"))
	if dialogue == null:
		return
	dialogue.chars_per_second = 100000
	await _roster(t, dialogue)
	await _context(t)
	await _input_and_actions(t, dialogue, ui)
	await _lifetime_and_schedule(t, dialogue)
	await _extensions(t, dialogue)
	await _quests(t, dialogue)
	await _journal(t, ui.get_screen(&"quest_journal"))
	await _turn_ins(t, dialogue)
	await _intro(t, dialogue)
	if is_instance_valid(_actor):
		_actor.free()

func _spawn(t, id: String, params: Dictionary = {}) -> Npc2D:
	if is_instance_valid(_actor):
		_actor.free()
	params["id"] = id
	params["wander"] = params.get("wander", "0")
	_actor = Npc2D.create(params)
	_actor.area = t.world().area
	_actor.position = t.world().area.objects.to_local(t.player().target_global())
	t.world().area.objects.add_child(_actor)
	return _actor

func _to_choices(t, dialogue: Control) -> void:
	for i in 30:
		if not dialogue.is_open() or dialogue._wants_focus():
			return
		t.tap(&"interact")
		await t.frames(2)
	t.fail("Dialogue did not reach its choices")

func _roster(t, dialogue: Control) -> void:
	var roster: Dictionary = t.autoload("LuaRuntime").get_npcs()
	for id in roster:
		var npc := _spawn(t, str(id))
		await t.frames(3)
		t.tap(&"interact")
		await t.frames(3)
		t.check("talk_roster_" + str(id), npc.is_talking and dialogue.is_open() and t.player().state == PlayerBody2D.S.TALKING)
		t.check("portrait_" + str(id), dialogue.get_node("%PortraitTexture").texture != null)
		await _to_choices(t, dialogue)
		t.expect(dialogue._buttons.size() <= 5, "At most five choices: " + str(id))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		t.expect(not npc.is_talking and not t.autoload("GameManager").is_modal_open() and t.player().state == PlayerBody2D.S.FREE, "Esc releases " + str(id))
		var page := NpcDialogue.build(str(id), str(npc.dialogue_id), NpcDialogue.context(str(id), t.player()))
		for locale in ["da", "en"]:
			for line in LuaData.arr(page.get("lines", [])):
				var key := str(line.get("text_key", ""))
				t.expect(key != "" and t.autoload("LocalizationManager").has_key(key) and t.autoload("LocalizationManager").text_in(key, locale) != key, "Resolved line " + key + " in " + locale)
		t.expect(not npc.get_interaction_prompt().begins_with("E"), "Prompt owns the verb only")

func _context(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var race: int = gm.character_type
	var skin: StringName = gm.character_skin
	var hour: int = gm.hour
	for i in 4:
		gm.character_type = i
		var hero: Dictionary = CharacterCatalog.heroes(["animal", "fairy", "hobbit", "ghost"][i])[0]
		gm.character_skin = StringName(hero.skin)
		for raw in [24, 25]:
			gm.hour = raw
			var ctx := NpcDialogue.context("mayor_lyra", t.player())
			t.check("context_race_%d_hour_%d" % [i, raw], ctx.race == ["animal", "fairy", "hobbit", "ghost"][i] and ctx.hero == hero.id and ctx.hour == raw and ctx.daypart == "nat" and ctx.total_day == gm.total_day() and ctx.has("weather") and ctx.has("weekday") and ctx.has("gifts_left") and ctx.shop_seed_shop == true, str(ctx))
	gm.character_type = race
	gm.character_skin = skin
	gm.hour = hour
	var npc := _spawn(t, "mapseller_natteblik", {"when": "night", "reach": 420})
	for raw in [24, 25]:
		gm.hour = raw
		npc._clock()
		t.expect(npc.is_enabled() and npc._interact.collision_layer == Iso.LAYER_INTERACTABLE, "Night citizen after midnight")
	gm.hour = 12
	npc._clock()
	t.check("when_night_hides_collider", not npc.visible and npc.collision_layer == 0 and npc._interact.collision_layer == 0)
	gm.hour = hour

func _input_and_actions(t, dialogue: Control, ui: GameUI) -> void:
	var npc := _spawn(t, "merchant_pip")
	var bus: Node = t.autoload("EventBus")
	var ends: Array = []
	var counter := func(): ends.append(true)
	bus.dialogue_ended.connect(counter)
	npc.interact(t.player())
	await t.frames(2)
	t.check("text_has_no_focus", dialogue.is_open() and dialogue.get_viewport().gui_get_focus_owner() == null)
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("esc_first_line_no_heart", ends.size() == 1 and t.autoload("SocialManager").hearts("merchant_pip") == 0)
	npc.interact(t.player())
	await t.frames(2)
	await _to_choices(t, dialogue)
	t.check("choice_focus", dialogue.get_viewport().gui_get_focus_owner() == dialogue._buttons[0])
	dialogue._buttons[-1].grab_focus()
	t.tap_key(KEY_DOWN)
	await t.frames(2)
	t.check("choice_wrap", dialogue.get_viewport().gui_get_focus_owner() == dialogue._buttons[0])
	for button in dialogue._buttons:
		if str(button.get_meta("choice").get("action", "")) == "open_shop":
			button.grab_focus()
	t.tap(&"interact")
	await t.frames(4)
	var shop: Control = ui.get_screen(&"shop_ui")
	t.check("action_transfers_to_shop", shop.is_open() and not dialogue.is_open() and ends.size() == 2 and t.autoload("GameManager").modal_stack() == [&"shop"])
	shop.close()
	await t.frames(2)
	var hearts: int = t.autoload("SocialManager").hearts("merchant_pip")
	t.check("weekly_heart", hearts == 1)
	npc.interact(t.player())
	await t.frames(2)
	await _to_choices(t, dialogue)
	dialogue._buttons[-1].grab_focus()
	UiAudit.press_pad(t, JOY_BUTTON_A)
	await t.frames(3)
	t.check("pad_close_no_duplicate_heart", ends.size() == 3 and t.autoload("SocialManager").hearts("merchant_pip") == hearts and not dialogue.is_open())
	npc.set_driven(true)
	npc.interact(t.player())
	await t.frames(2)
	t.check("talk_holds_driven", npc.driven and npc._held)
	npc.free()
	await t.frames(3)
	t.check("temporary_actor_disposal_ends_once", ends.size() == 4 and not dialogue.is_open() and t.player().state == PlayerBody2D.S.FREE)
	bus.dialogue_ended.disconnect(counter)

func _quests(t, dialogue: Control) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	gm.unlock_zone(&"dark_forest")
	for flag in ["math_bakery_done", "math_harvest_done", "math_quiz_done"]:
		gm.set_flag(StringName(flag), true)
	gm.set_flag(&"home_tier", 10)
	for pair in [["guard_oak", "snurresvampen"], ["fairy_wizard", "bogtraeet"], ["fairy_king", "moonstone_crown"], ["fairy_king", "slotsdroemmen"], ["pippin_boegeknop", "lost_cat"], ["baker_maja", "cookie_delivery"], ["mayor_lyra", "fix_roof"], ["guard_oak", "skovlift_intro"]]:
		var npc := _spawn(t, pair[0])
		npc.interact(t.player())
		await t.frames(2)
		await _to_choices(t, dialogue)
		var found := await _choose_quest(t, dialogue, pair[1])
		t.check("accept_dialogue_" + pair[1], found and qm.is_active(StringName(pair[1])))
		if dialogue.is_open():
			dialogue.close()
		await t.frames(2)

func _choose_quest(t, dialogue: Control, id: String, depth := 0) -> bool:
	if depth > 8:
		return false
	for button in dialogue._buttons:
		if str(button.get_meta("choice").get("quest_id", "")) == id:
			button.pressed.emit()
			await t.frames(3)
			return true
	for button in dialogue._buttons:
		if str(button.get_meta("choice").get("action", "")) == "social_more":
			button.pressed.emit()
			await t.frames(3)
			return await _choose_quest(t, dialogue, id, depth + 1)
	return false

func _journal(t, journal: Control) -> void:
	t.tap_key(KEY_J)
	await t.frames(3)
	t.check("journal_toggle_j", journal.is_open() and t.tree.paused and not journal._rows.is_empty())
	journal._select(&"lost_cat")
	t.check("journal_reads_lua", journal.get_node("%DetailTitle").text == t.autoload("QuestManager").get_title(&"lost_cat") and journal.get_node("%StepList").get_child_count() == 4 and journal.get_node("%RewardRow").get_child_count() == 4)
	for locale in ["da", "en"]:
		t.autoload("LocalizationManager").set_locale(locale)
		await t.frames(3)
		var rules := UiAudit.rule_report(journal)
		t.check("journal_rules_" + locale, rules.ok, str(rules.defects))
	t.autoload("LocalizationManager").set_locale("da")
	journal._rows[0].grab_focus()
	t.tap_key(KEY_RIGHT)
	await t.frames(3)
	t.check("journal_list_right_changes_tab", journal._tab == 1)
	t.tap_key(KEY_J)
	await t.frames(3)
	t.check("journal_j_closes_in_gui", not journal.is_open() and not t.tree.paused)

func _intro(t, dialogue: Control) -> void:
	var gm: Node = t.autoload("GameManager")
	gm.set_flag(&"intro_letter_seen", false)
	gm.set_config_override("farm_tutorial.first_morning.enabled", false)
	var result: Array = []
	var start := func():
		await preload("res://scripts/world2d/intro_sequence.gd").run(t.world())
		result.append(true)
	start.call()
	await t.frames(3)
	t.check("intro_uses_real_dialogue", dialogue.is_open() and dialogue.get_node("%TextLabel").text.contains("lotteri"))
	t.tap_key(KEY_ESCAPE)
	await t.frames(4)
	t.check("intro_skip_accepts_quest", result.size() == 1 and gm.get_flag(&"intro_letter_seen", false) and t.autoload("QuestManager").is_active(&"intro_lottery"))
	await preload("res://scripts/world2d/intro_sequence.gd").run(t.world())
	t.check("intro_once", not dialogue.is_open())
	gm.clear_config_overrides()

func _lifetime_and_schedule(t, dialogue: Control) -> void:
	var outcomes: Array = []
	var show_page := func(index: int):
		var result: Dictionary = await dialogue.show_lines({"id": "fairy_king", "name_key": "NPC_FAIRY_KING"}, [{"text_key": "DLG_KING_GREET"}], [])
		outcomes.append({"index": index, "result": result})
	show_page.call(1)
	await t.frames(2)
	show_page.call(2)
	await t.frames(2)
	t.check("dialogue_reentrant_cancels_previous_await", outcomes.size() == 1 and outcomes[0].index == 1 and not outcomes[0].result.completed and dialogue.is_open())
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("dialogue_reentrant_second_result", outcomes.size() == 2 and outcomes[1].index == 2 and not dialogue.is_open())
	var npc := _spawn(t, "mapseller_natteblik", {"reach": 420})
	npc.global_position += Vector2(350, 0)
	await t.frames(3)
	t.tap(&"interact")
	await t.frames(3)
	t.check("reach_override", dialogue.is_open() and npc.is_talking)
	dialogue.close()
	await t.frames(2)
	var gm: Node = t.autoload("GameManager")
	var original_hour: int = gm.hour
	gm.hour = 12
	npc = _spawn(t, "mayor_lyra", {"wander": "1"})
	npc.wander_radius = 100
	npc._wait = 0
	var safe := true
	for i in 3600:
		npc._physics_process(1.0 / 60)
		safe = safe and npc._can_stand(npc.global_position)
	t.check("wander_sixty_seconds_walkable", safe and Iso.to_ground(npc.global_position - npc._home).length() <= 100)
	gm.hour = 24
	for i in 3600:
		npc._physics_process(1.0 / 60)
	t.check("night_schedule_home_and_sleep", npc.global_position.distance_to(npc._home) < 6 and npc._act == &"sleep" and npc.visual.current_clip == (&"sleep" if npc.visual.has_clip(&"sleep") else &"idle"), "home distance %s, requested %s, rendered %s" % [npc.global_position.distance_to(npc._home), npc._act, npc.visual.current_clip])
	gm.hour = original_hour
	npc = _spawn(t, "pippin_boegeknop")
	var walk_path: String = npc.visual._sheet_path(&"walk")
	t.check("unused_npc_clips_have_no_abandoned_thread_requests", walk_path != "" and ResourceLoader.load_threaded_get_status(walk_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)

func _turn_ins(t, dialogue: Control) -> void:
	var eco: Node = t.autoload("EconomyManager")
	var qm: Node = t.autoload("QuestManager")
	eco.add_item(&"carrot", 12, true)
	await t.frames(2)
	var carrots: int = eco.count_item(&"carrot")
	var npc := _spawn(t, "baker_maja")
	npc.interact(t.player())
	await t.frames(3)
	t.check("cookie_delivery_dialogue_turn_in", qm.is_completed(&"cookie_delivery") and eco.count_item(&"carrot") == carrots - 12)
	dialogue.close()
	await t.frames(2)
	for id in ["merchant_pip", "mayor_lyra"]:
		npc = _spawn(t, id)
		npc.interact(t.player())
		await t.frames(2)
		dialogue.close()
		await t.frames(2)
	var trail := false
	for marker in t.world().area.find_markers("quest_spot"):
		if str(marker.params.get("quest", "")) == "lost_cat":
			marker.node.interact(t.player())
			trail = true
	t.check("lost_cat_real_pawprint_marker", trail and qm.get_objective_progress(&"lost_cat", &"follow_pawprints").get("done", false))
	npc = _spawn(t, "cat_morfar_mis")
	npc.interact(t.player())
	await t.frames(2)
	dialogue.close()
	await t.frames(2)
	npc = _spawn(t, "pippin_boegeknop")
	npc.interact(t.player())
	await t.frames(2)
	t.check("lost_cat_dialogue_turn_in", qm.is_completed(&"lost_cat"))
	dialogue.close()
	await t.frames(2)
	# Repair progress uses the same transactional action as an authored quest spot.
	eco.add_item(&"wood", 8, true)
	eco.add_item(&"moss", 4, true)
	await t.frames(2)
	var wood: int = eco.count_item(&"wood")
	var moss: int = eco.count_item(&"moss")
	npc = _spawn(t, "mayor_lyra")
	npc.handle_choice("give_item", {"quest_id": "fix_roof", "objective_id": "repair_roof", "needs": {"wood": 8, "moss": 4}, "consume": true})
	t.check("fix_roof_transactional_action", qm.is_completed(&"fix_roof") and eco.count_item(&"wood") == wood - 8 and eco.count_item(&"moss") == moss - 4)

func _extensions(t, dialogue: Control) -> void:
	var bus: Node = t.autoload("EventBus")
	var events: Array = []
	var listener := func(event, payload):
		if event in [&"npc_extension_probe", &"dialogue_action"]:
			events.append({"event": event, "payload": payload.duplicate(true), "modal": t.autoload("GameManager").top_modal()})
	bus.game_event.connect(listener)
	var npc := _spawn(t, "merchant_pip")
	npc._begin_followup(t.player(), {"lines": [{"text_key": "DLG_NEUTRAL"}], "choices": [{"text_key": "DLG_CHOICE_GOODBYE", "action": "emit_event", "event": "npc_extension_probe", "payload": {"answer": 42}}]})
	await t.frames(2)
	# A click advances text without firing a world interaction or a choice twice.
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = Vector2(640, 200)
		event.pressed = pressed
		Input.parse_input_event(event)
	await t.frames(3)
	await _to_choices(t, dialogue)
	dialogue._buttons[0].pressed.emit()
	await t.frames(3)
	t.check("emit_event_after_modal_closed", events.size() == 1 and events[0].event == &"npc_extension_probe" and events[0].payload == {"answer": 42} and events[0].modal == &"" and not npc.is_talking, str(events))
	npc.handle_choice("future_extension", {"id": "future", "number": 7})
	t.check("unknown_action_forwarded", events.size() == 2 and events[1].payload.npc == "merchant_pip" and events[1].payload.action == "future_extension" and events[1].payload.data.number == 7)
	bus.game_event.disconnect(listener)
	var guest := _spawn(t, "merchant_pip", {"guest": true})
	guest.set_driven(true)
	var page := NpcDialogue.build("merchant_pip", "merchant_pip", NpcDialogue.context("merchant_pip", t.player()), true)
	t.check("guest_has_social_but_no_shop_quest_or_routine", not guest.driven and LuaData.arr(page.choices).all(func(choice): return str(choice.get("action", "")) != "open_shop" and not str(choice.get("action", "")).begins_with("quest_")))
	var many: Array = []
	for i in 15:
		many.append({"id": str(i), "text_key": "DLG_CHOICE_GOODBYE", "action": "close"})
	var seen: Array = []
	var next := {"choices": many}
	for step in 10:
		var menu: Dictionary = DialogueBridge.action("merchant_pip", "social_more", next).page
		t.expect(menu.choices.size() <= 5, "Every overflow page fits five rows")
		next = {}
		for choice in menu.choices:
			if choice.get("action", "") == "social_more":
				next = choice
			elif choice.get("id", "") != "close":
				seen.append(choice.id)
		if next.is_empty():
			break
	t.check("overflow_keeps_all_choices_once", seen.size() == 15 and seen == many.map(func(choice): return choice.id))
