extends RefCounted
## Each alternative begins a separate fresh occurrence. No response/model reset
## inside any help, decline or next-day defer chain.
const SECTION := "renewed_living_continuity_choices"
const TIMEOUT_S := 180.0
const FLOW_PATH := "res://tests/sections/renewed_living_reconcile.gd"
const WALKER := preload("res://tests/lib/town_loop/walker.gd")
const UI := preload("res://tests/sections/living_encounters.gd")
const PAIR := "beekeeper_birk:smith_thorin"

func run(t) -> void:
	for mode in ["help", "defer", "decline"]:
		await _case(t, mode)

func _case(t, mode: String) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var eco: Node = t.autoload("EconomyManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("time.weather_chances.foraar", {"klart": 1.0})
	gm.day = 2
	gm.set_clock(18, 42)
	print("RENEWED_CHOICE_SETUP ", mode, " separate fresh dry Tuesday18:42 inactive farm; later calendar never reassigned")
	await t.world().travel(&"hyggebyen", &"default")
	await t.physics(16)
	if not await open_pause(t, mode + "_offer"):
		gm.clear_config_overrides()
		return
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	var gold: int = eco.gold
	var hearts: Dictionary = _hearts(sm)
	var day: int = gm.total_day()
	t.check(mode + "_real_ui_choice", await UI.new().pick(t, screen, "living_" + mode))
	var response: Dictionary = sm.living_snapshot().get("responses", {}).get("p0", {})
	t.check(mode + "_intent_only_not_attendance", response.get("choice") == mode and response.get("day") == day and response.get("attended_day", 0) == 0 and response.get("ack_day", 0) == 0, str(response))
	if mode == "defer": t.check("defer_explicit_next_day_boundary", response.get("not_before_day") == day + 1)
	# Actual reopened page immediately after the terminal, no model edit.
	if await open_pause(t, mode + "_same_day_reopen"):
		t.check(mode + "_actual_response_copy", screen._lines.any(func(line): return line.get("text_key") == "LC_PAUSE_" + mode.to_upper()), str(screen._lines))
		t.check(mode + "_no_same_day_resolicit", not screen._choices.any(func(choice): return choice.get("action") == "living_help"))
		await close(t)
	var flow: RefCounted = load(FLOW_PATH).new()
	for i in 10:
		await flow.minute(t)
	var pair: Dictionary = sm.living_snapshot().world.get("pairs", {}).get(PAIR, {})
	t.check(mode + "_actual_npcs_continue_to_attendance", pair.get("phase") == "attendance" and pair.get("day") == day, str(pair))
	response = sm.living_snapshot().get("responses", {}).get("p0", {})
	if mode == "help":
		t.check("help_continuous_real_body_attended", response.get("attended_day") == day and response.get("ack_day") == 0, str(response))
		if await open_pause(t, "help_attendance_reopen"):
			t.check("help_actual_ui_ack", await UI.new().pick(t, screen, "living_ack"))
			t.check("help_ack_terminal_recorded", sm.living_snapshot().responses.p0.ack_day == day)
		await flow.page(t, "baker_maja", "living_pause", "LC_PAUSE_SUPPORTED", "supported_actual_final_reopen")
	else:
		t.check(mode + "_no_unearned_player_attendance", response.get("attended_day", 0) == 0 and response.get("ack_day", 0) == 0, str(response))
		t.check(mode + "_no_automatic_resolicit_ui", not screen.is_open())
		# Another actual reopen after the NPC outcome is still quiet.
		if await open_pause(t, mode + "_post_attendance_reopen"):
			t.check(mode + "_still_no_same_day_help", not screen._choices.any(func(choice): return choice.get("action") == "living_help"))
			await close(t)
	t.check(mode + "_no_reward_or_punishment", eco.gold == gold and _hearts(sm) == hearts, str({"gold_before": gold, "gold_after": eco.gold, "hearts_before": hearts, "hearts_after": _hearts(sm)}))
	if mode == "defer":
		await t.world().travel(&"farm", &"default")
		await t.world().sleep()
		await t.physics(4)
		t.check("defer_genuine_next_day_sleep", gm.total_day() == day + 1)
		await flow.until_clock(t, 18, 42)
		await t.world().travel(&"hyggebyen", &"default")
		await t.physics(16)
		if await open_pause(t, "defer_next_calendar_day_reopen"):
			t.check("defer_next_day_legitimate_options_return", screen._choices.any(func(choice): return choice.get("action") == "living_help"))
			await close(t)
	gm.clear_config_overrides()

func _hearts(sm: Node) -> Dictionary:
	var out := {}
	for npc in ["baker_maja", "beekeeper_birk", "smith_thorin"]: out[npc] = sm.points(npc)
	return out

func open_pause(t, label: String) -> bool:
	var actor: Npc2D = NpcDirector.node_of("baker_maja")
	if not t.check(label + "_real_actor", is_instance_valid(actor) and actor.driven): return false
	var route: Dictionary = await WALKER.walk_to(t, actor.global_position, 65.0)
	t.check(label + "_real_input_walk", route.get("ok", false), str(route))
	if not route.get("ok", false): return false
	actor.interact(t.player())
	await t.frames(3)
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	var reached: bool = await UI.new().pick(t, screen, "living_pause")
	t.check(label + "_actual_pause_page", reached and screen.is_open(), str(screen._lines))
	return reached

func close(t) -> void:
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
