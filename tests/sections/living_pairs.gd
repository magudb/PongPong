extends RefCounted
## Loaded ordinary fountain stays, not schedule-only or synthetic pair receipts.
const SECTION := "living_pairs"
const TIMEOUT_S := 180.0
const CAST := ["baker_maja", "beekeeper_birk", "smith_thorin"]
const PAIR := "beekeeper_birk:smith_thorin"

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.day = 2
	gm.set_clock(18, 40)
	await t.world().travel(&"hyggebyen", &"default")
	await t.frames(8)
	var director: TownDirector = TownProbe.director(t)
	for id in CAST:
		var actor: Variant = director.live.get(id)
		t.check("pair_loaded_" + id, is_instance_valid(actor), str(director.live.keys()))
		print("PILOT_FIT ", id, " ", Routines.where_is(id, Routines.now_ctx()), " actor=", actor.global_position if is_instance_valid(actor) else Vector2.ZERO)
		print("PILOT_TIMELINE ", id, " ", Routines._timeline(id, Routines.daily_plan(id, Routines.now_ctx()), false, {}, 26.0))
	var before: Dictionary = sm.living_snapshot()
	for minute in 10:
		gm.advance_time(1)
		await t.physics(8)
	var pair: Dictionary = sm.living_snapshot().get("world", {}).get("pairs", {}).get(PAIR, {})
	t.check("loaded_autonomous_pair_shared_pause_at_ease", pair.get("status") == "at_ease", str(pair))
	t.check("autonomous_pair_not_private_mining_knowledge", sm.living_context("smith_thorin", &"p0").is_empty())
	var page := NpcDialogue.build("beekeeper_birk", "beekeeper_birk", NpcDialogue.context("beekeeper_birk", t.player()))
	t.check("pair_outcome_changes_later_visible_reply", page.get("lines", []).any(func(l): return l.get("text_key") == "LC_PAIR_AT_EASE"), str(page))
	print("PILOT_BEFORE ", before)
	await _controls(t, sm, gm, director, before)
	gm.clear_config_overrides()

func _tick(t, gm: Node, minutes: int) -> void:
	for i in minutes:
		gm.advance_time(1)
		await t.physics(8)

func _controls(t, sm: Node, gm: Node, director: TownDirector, before: Dictionary) -> void:
	var section: Dictionary = sm.to_dict()
	section["living"] = before
	t.check("pair_restore_preincident_control", sm.from_dict(section))
	gm.set_clock(18, 53)
	await t.physics(20)
	await _tick(t, gm, 4)
	var mismatch: Dictionary = sm.living_snapshot().world.pairs.get(PAIR, {})
	t.check("actual_late_invitation_communicates_mismatch", mismatch.get("status") == "needs_clarification" and mismatch.get("phase") == "mismatch", str(mismatch))
	t.check("mismatch_has_visible_reachable_context", sm.living_pair_reply("smith_thorin") == "LC_PAIR_MISMATCH")
	var mismatch_save: Dictionary = sm.to_dict()
	var maja: Npc2D = director.live["baker_maja"]
	await load("res://tests/lib/town_loop/walker.gd").walk_to(t, maja.global_position, 65.0)
	var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
	var helper: RefCounted = load("res://tests/sections/living_encounters.gd").new()
	maja.interact(t.player())
	await t.frames(3)
	t.check("mismatch_real_ui_clarification_page", await helper.pick(t, ui, "living_pause"))
	t.check("mismatch_real_ui_clarification_choice", await helper.pick(t, ui, "living_clarify"))
	print("PILOT_CLARIFY ", {"pair": sm.living_snapshot().world.pairs[PAIR], "source": maja.area.get_node_or_null("TownDirector"), "window": load("res://scripts/social/living/living_pair.gd").window(Routines.now_ctx()), "actors": load("res://scripts/social/living/living_pair.gd").actors(director, Routines.now_ctx(), maja).size(), "clock": Routines.now_ctx().hour, "distance": Iso.to_ground(t.player().global_position - maja.global_position).length()})
	t.check("player_suggestion_not_bilateral_completion", sm.living_snapshot().world.pairs[PAIR].phase == "clarification_pending")
	await _tick(t, gm, 2)
	t.check("player_facilitated_loaded_bilateral_clarification", sm.living_snapshot().world.pairs[PAIR].phase == "clarification")
	sm.from_dict(mismatch_save)
	gm.day = 3
	gm.set_clock(18, 42)
	await t.physics(20)
	await _tick(t, gm, 3)
	var repaired: Dictionary = sm.living_snapshot().world.pairs.get(PAIR, {})
	t.check("autonomous_bilateral_clarification_next_copresence", repaired.get("phase") == "clarification" and repaired.get("status") == "at_ease" and repaired.get("pause_minutes") == 2, str(repaired))
	t.check("clarification_changes_later_visible_response", sm.living_pair_reply("beekeeper_birk") == "LC_PAIR_CLARIFIED")
	gm.day = 4
	gm.set_clock(18, 42)
	await t.physics(20)
	await _tick(t, gm, 6)
	var shorter: Dictionary = sm.living_snapshot().world.pairs.get(PAIR, {})
	t.check("repaired_pair_next_safe_choice_really_shorter", shorter.get("phase") == "attendance" and shorter.get("day") == 4 and shorter.get("pause_minutes") == 2, str(shorter))
	# Identical schedules are insufficient when the actual recipient is held.
	gm.day = 2
	sm.from_dict(section)
	gm.set_clock(18, 42)
	await t.physics(20)
	var birk: Npc2D = director.live["beekeeper_birk"]
	birk.hold(true)
	await _tick(t, gm, 8)
	t.check("held_actor_cannot_consent_or_attend", sm.living_snapshot().world.pairs.is_empty())
	birk.hold(false)
	# A discontinuous clock jump cannot supply the absent dwell.
	sm.from_dict(section)
	gm.set_clock(18, 42)
	await t.physics(20)
	await _tick(t, gm, 3)
	gm.set_clock(18, 55)
	await t.physics(8)
	t.check("timejump_does_not_complete_continuous_dwell", sm.living_snapshot().world.pairs.get(PAIR, {}).get("phase") != "attendance")
	# Nor may a burst of minute notifications in a single physics frame.
	sm.from_dict(section)
	gm.set_clock(18, 42)
	await t.physics(20)
	gm.advance_time(9)
	t.check("minute_burst_without_physics_is_not_dwell", sm.living_snapshot().world.pairs.get(PAIR, {}).get("phase") != "attendance")
	await t.world().travel(&"farm", &"default")
	sm.from_dict(section)
	gm.set_clock(18, 42)
	await _tick(t, gm, 10)
	t.check("scheduled_but_unloaded_does_not_create_pair", sm.living_snapshot().world.pairs.is_empty())
