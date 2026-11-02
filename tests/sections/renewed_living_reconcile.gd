extends RefCounted
## Controlled inactive-entry setup only: dry Tuesday 18:42. Everything after
## entry uses real directors, consecutive single minutes, farm sleep and disk load.
const SECTION := "renewed_living_reconcile"
const TIMEOUT_S := 180.0
const ACTIONS := preload("res://scripts/social/living/living_actions.gd")
const DATA := preload("res://scripts/social/living/living_data.gd")
const WALKER := preload("res://tests/lib/town_loop/walker.gd")
const UI := preload("res://tests/sections/living_encounters.gd")

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("time.weather_chances.foraar", {"klart": 1.0})
	gm.day = 2
	gm.set_clock(18, 42)
	print("RENEWED_SETUP inactive farm; Tuesday18:42, frozen automatic clock; initial clear weather from fresh game")
	await t.world().travel(&"hyggebyen", &"default")
	await t.physics(16)
	for i in 14:
		await minute(t)
	var connected: Dictionary = sm.living_snapshot().world.get("citizens", {}).get("baker_maja", {})
	t.check("natural_director_produces_named_connection", connected.get("outcome") == "connection" and connected.get("target") == "beekeeper_birk" and connected.get("closed_day") == gm.total_day(), str(connected))
	if connected.get("outcome") != "connection":
		gm.clear_config_overrides()
		return
	await page(t, "baker_maja", "living_motivation", "LC_BAKER_MAJA_CONNECTED", "connected_actual_reopen")
	var first_day: int = gm.total_day()
	await t.world().travel(&"farm", &"default")
	await t.world().sleep()
	await t.physics(4)
	t.check("real_sleep_advances_connection_calendar", gm.total_day() == first_day + 1)
	await roundtrip(t, "connection_after_sleep")
	t.check("real_disk_load_retains_produced_connection", sm.living_snapshot().world.get("citizens", {}).get("baker_maja", {}) == connected)
	# Do not visit town before its meeting: reflection may legitimately latch first.
	await until_clock(t, 18, 42)
	await t.world().travel(&"hyggebyen", &"default")
	await t.physics(16)
	for i in 14:
		await minute(t)
	var director: TownDirector = TownProbe.director(t)
	var ctx := Routines.now_ctx()
	t.check("later_authenticated_named_meeting_is_safe", director != null and not ACTIONS.safe(director, director.live.get("baker_maja"), ctx).is_empty() and not ACTIONS.safe(director, director.live.get("beekeeper_birk"), ctx).is_empty(), str(ctx))
	var repaired: Dictionary = sm.living_snapshot().world.get("citizens", {}).get("baker_maja", {})
	print("RENEWED_NATURAL_ENDPOINT ", {"prior": connected, "later": repaired, "ctx": Routines.now_ctx()})
	t.check("natural_saved_connection_continues_as_general_clarification", repaired.get("outcome") == "clarification" and repaired.get("target") == connected.target and repaired.get("closed_day") == first_day + 1, str(repaired))
	await page(t, "baker_maja", "living_motivation", "LC_BAKER_MAJA_CLARIFIED", "general_clarified_actual_reopen")
	# Separate diagnostic unit cases; these dictionaries are NOT world producers.
	for npc in ["baker_maja", "beekeeper_birk", "smith_thorin"]:
		var profile: Dictionary = DATA.profile(npc)
		var reconcile: Dictionary = {}
		for goal in profile.goals:
			if goal.id == "lc_" + npc + "_reconcile": reconcile = goal
		var prior := {"day": 2, "goal": "lc_" + npc + "_connect", "outcome": "connection", "target": reconcile.target, "closed_day": 2, "cooldowns": {"lc_" + npc + "_connect": 4}}
		var selected: Dictionary = ACTIONS.plan(npc, profile, 3, prior, [reconcile.target])
		t.check("unit_" + npc + "_pending_followup_phase", selected.get("executor") == "clarify" and selected.get("target") == reconcile.target, str(selected))
	gm.clear_config_overrides()

func minute(t, physics_frames: int = 8) -> void:
	t.autoload("GameManager").advance_time(1)
	await t.physics(physics_frames)

func until_clock(t, hour: int, minute_value: int) -> void:
	var gm: Node = t.autoload("GameManager")
	var remaining: int = hour * 60 + minute_value - gm.hour * 60 - gm.minute
	t.check("forward_clock_only_" + str(gm.total_day()), remaining >= 0)
	for i in maxi(0, remaining):
		await minute(t, 2)

func roundtrip(t, label: String) -> void:
	var saves: Node = t.autoload("SaveManager")
	var sm: Node = t.autoload("SocialManager")
	var gm: Node = t.autoload("GameManager")
	var state: Dictionary = sm.living_snapshot()
	var day: int = gm.total_day()
	var old_dir: String = saves.save_dir
	saves.save_dir = "user://renewed_living_" + label
	t.check(label + "_real_save", saves.save_game(0))
	var result: Dictionary = saves.try_load_game(0)
	await t.physics(4)
	t.check(label + "_real_load_exact_social_and_day", result.get("ok", false) and sm.living_snapshot() == state and gm.total_day() == day, str(result))
	# A disk model load revokes the old physical projection. Resume the actual
	# pending World scene without resetting/reloading any social or calendar row.
	await load("res://tests/progression/living_delivery.gd").resume_loaded_world(t, label)
	saves.save_dir = old_dir

func page(t, npc: String, action: String, key: String, label: String) -> bool:
	var actor: Npc2D = NpcDirector.node_of(npc)
	if not t.check(label + "_live_director_actor", is_instance_valid(actor) and actor.driven): return false
	var route: Dictionary = await WALKER.walk_to(t, actor.global_position, 65.0)
	t.check(label + "_actual_input_walk", route.get("ok", false), str(route))
	if not route.get("ok", false): return false
	actor.interact(t.player())
	await t.frames(3)
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	var reached: bool = await UI.new().pick(t, screen, action)
	var found: bool = reached and screen.is_open() and screen._lines.any(func(line): return line.get("text_key") == key)
	t.check(label + "_actual_visible_outcome", found, str(screen._lines))
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	return found
