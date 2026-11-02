extends RefCounted
## Real-input tracer. Only prerequisite mining collection/exploration is a
## fixture grant; delivery uses the loaded director-owned Thorin + E, not a
## replacement actor or LC setter. Keyboard/controller travel/UI are exercised.
const SECTION := "living_activity_journey"
const TIMEOUT_S := 180.0
const NPC := "smith_thorin"
const WALKER := preload("res://tests/lib/town_loop/walker.gd")
var shots := false

func run(t) -> void:
	await _journey(t)

func run_windowed(t) -> void:
	shots = true
	await _journey(t)

func _journey(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var sm: Node = t.autoload("SocialManager")
	var tm: Node = t.autoload("TimeManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("time.weather_chances.foraar", {&"klart": 1.0})
	gm.set_config_override("towns.curfew.enabled", false)
	gm.set_clock(19, 0)
	await t.world().travel(&"hyggebyen", &"default")
	await t.frames(5)
	var smith: Npc2D = NpcDirector.node_of(NPC)
	if not t.expect(smith != null and smith.driven, "journey real scheduled Thorin"): return
	t.check("journey_no_help_fountain", NpcDirector.where_is(NPC).place == "hyggebyen.torv_fountain_e")
	var route := await WALKER.walk_to(t, smith.global_position, 65.0)
	t.check("journey_walk_to_real_smith", route.get("ok", false), str(route))
	if not route.get("ok", false): return
	await t.physics(2)
	t.check("journey_physical_interaction_target", t.player().nearest_interactable() == smith)
	if shots: await t.capture("living_baseline_fountain")
	t.expect(qm.accept_quest(&"dark_forest_mining"), "journey fixture accepts mining quest")
	eco.add_item(&"iron_ore", 6)
	eco.add_item(&"amethyst", 2)
	qm.refresh_objectives()
	t.autoload("EventBus").zone_entered.emit(&"dark_forest")
	load("res://tests/progression/mining_deliveries.gd")._ready_delivery(t, qm, eco, &"dark_forest_mining", {"iron_ore": 6, "amethyst": 2}, "journey")
	var gold: int = eco.gold
	t.tap(&"interact")
	await t.frames(3)
	t.check("journey_real_E_commits_delivery_and_private_memory", smith.is_talking and qm.is_completed(&"dark_forest_mining") and eco.count_item(&"iron_ore") == 0 and eco.count_item(&"amethyst") == 0 and eco.gold == gold + 600 and sm.living_context(NPC, &"p0").get("memories", []).size() == 1)
	var pending: Dictionary = sm._living.duplicate(true)
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("journey_escape_after_committed_delivery_does_not_undo", sm._living == pending and not smith.is_talking)
	await t.world().travel(&"farm", &"default")
	await t.world().sleep()
	sm.flush()
	t.check("journey_sleep_selects_actual_goal", sm.living_activity_snapshot().selected.get("goal_id") == "lc_smith_thorin_personal")
	gm.set_clock(19, 0)
	await t.world().travel(&"hyggebyen", &"default")
	await t.frames(4)
	smith = NpcDirector.node_of(NPC)
	if not t.expect(smith != null, "journey Thorin returns after travel and sleep"): return
	var director: TownDirector = TownProbe.director(t)
	var start := smith.global_position
	var snaps: int = director.stats.snaps
	var moved := false
	for minute in 30:
		gm.advance_time(1)
		await t.physics(6)
		moved = moved or smith.global_position.distance_to(start) > 10.0
	var settled: bool = await t.until_game(func(): return Iso.to_ground(smith.global_position - director.area.to_global(Iso.to_screen(director._carrot(director.targets[NPC], director.game_hours)))).length() <= 5.0, 10.0)
	t.check("journey_actual_director_walk_and_bench_activity", moved and settled and director.targets[NPC].place == "hyggebyen.torv_bench2" and smith._act == &"sit", "moved=%s settled=%s target=%s snaps=%d->%d delta=%s" % [moved, settled, director.targets.get(NPC), snaps, director.stats.snaps, smith.global_position - start])
	var route2 := await WALKER.walk_to(t, smith.global_position, 65.0)
	t.check("journey_walk_to_changed_activity", route2.get("ok", false), str(route2))
	if not route2.get("ok", false): return
	await t.physics(2)
	t.check("journey_changed_activity_is_interactable", t.player().nearest_interactable() == smith)
	if shots: await t.capture("living_helped_bench")
	var before: Dictionary = sm._living.duplicate(true)
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	t.tap(&"interact")
	await t.frames(3)
	await t.page_to_choices(screen)
	var reached := false
	for i in 6:
		var chosen: Button
		for button in screen._buttons:
			if button.get_meta("choice", {}).get("action") == "living_activity": chosen = button; reached = true; break
		if chosen == null:
			for button in screen._buttons:
				if button.get_meta("choice", {}).get("action") == "social_more": chosen = button; break
		if chosen == null: break
		await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
		chosen.grab_focus()
		_joy(JOY_BUTTON_A)
		# The pressed row is freed with its page: remember its id, never capture the Node in a lambda.
		var pressed := chosen.get_instance_id()
		if reached:
			# The contextual reply is a new page the game opens after the pick: wait for it, bounded by game time.
			await t.until_game(func(): return not screen._buttons.any(func(b): return b.get_instance_id() == pressed) and smith.is_talking and screen._lines.any(func(l): return l.get("text_key") == "LC_SMITH_THORIN_ACTIVITY"), 2.0)
			break
		# "More" replaces the page: wait until the pressed row is gone and the next page is open.
		await t.until_game(func(): return not screen._buttons.any(func(b): return b.get_instance_id() == pressed) and screen.is_open(), 2.0)
		await t.page_to_choices(screen)
	t.check("journey_controller_context_choice_reaches_live_npc", reached and smith.is_talking and screen._lines.any(func(l): return l.get("text_key") == "LC_SMITH_THORIN_ACTIVITY"))
	if shots:
		# Capture the rendered full line, not the first typewriter characters.
		if screen._typing:
			_joy(JOY_BUTTON_A)
			await t.frames(2)
		t.check("journey_contextual_line_fully_visible", not screen._typing and screen.get_node("%TextLabel").text == tr("LC_SMITH_THORIN_ACTIVITY"))
		await t.capture("living_contextual_conversation")
	var held := smith.global_position
	gm.set_clock(20, 5)
	t.autoload("EventBus").game_event.emit(&"living_schedule_changed", {})
	await t.seconds(0.7)
	t.check("journey_full_hold_no_teleport_or_despawn", is_instance_valid(smith) and smith.is_talking and smith._held and smith.global_position == held)
	_joy(JOY_BUTTON_B)
	await t.frames(4)
	t.check("journey_controller_cancel_pure_releases_speaker", sm._living == before and not smith.is_talking and not smith._held)
	var return_start := smith.global_position
	var max_step := 0.0
	gm.set_clock(20, 10)
	for frame in 240:
		var previous := smith.global_position
		await t.physics(1)
		max_step = maxf(max_step, Iso.to_ground(smith.global_position - previous).length())
	var fountain := director.area.to_global(Iso.to_screen(RouteTable.position_of("hyggebyen.torv_fountain_e")))
	t.check("journey_observed_physical_return_no_snap", smith.global_position.distance_to(return_start) > 100.0 and Iso.to_ground(smith.global_position - fountain).length() < 10.0 and max_step < 40.0 and director.targets[NPC].place == "hyggebyen.torv_fountain_e" and sm._living == before, "max ground step %.2fpx; return error %.2fpx" % [max_step, Iso.to_ground(smith.global_position - fountain).length()])
	if shots: await t.capture("living_physical_return")
	gm.clear_config_overrides()

func _joy(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
