extends RefCounted
## One saved calendar chain: no SocialManager reset/from_dict, day assignment,
## clock jump or scene replacement except the real post-load pending handoff.
const SECTION := "renewed_living_continuity_calendar"
const TIMEOUT_S := 180.0
const FLOW_PATH := "res://tests/sections/renewed_living_reconcile.gd"
const PAIR := "beekeeper_birk:smith_thorin"

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("time.weather_chances.foraar", {"klart": 1.0})
	gm.day = 2
	gm.set_clock(18, 53)
	print("RENEWED_CALENDAR_SETUP dry Tuesday18:53 inactive farm, frozen automatic clock and dry subsequent weather; no later setup rewrites")
	var flow: RefCounted = load(FLOW_PATH).new()
	await t.world().travel(&"hyggebyen", &"default")
	await t.physics(20)
	for i in 4:
		await flow.minute(t)
	var mismatch: Dictionary = sm.living_snapshot().world.get("pairs", {}).get(PAIR, {})
	t.check("late_real_meeting_produces_mismatch", mismatch.get("phase") == "mismatch" and mismatch.get("status") == "needs_clarification" and mismatch.get("day") == 2, str(mismatch))
	await flow.page(t, "baker_maja", "living_pause", "LC_PAIR_MISMATCH", "mismatch_actual_reopen")
	await t.world().travel(&"farm", &"default")
	await flow.roundtrip(t, "calendar_mismatch")
	t.check("saved_mismatch_retained_before_sleep", sm.living_snapshot().world.get("pairs", {}).get(PAIR, {}) == mismatch)
	await t.world().sleep()
	await t.physics(4)
	t.check("mismatch_to_repair_real_sleep_day3", gm.total_day() == 3)
	await flow.until_clock(t, 18, 42)
	await t.world().travel(&"hyggebyen", &"default")
	await t.physics(20)
	for i in 3:
		await flow.minute(t)
	var repaired: Dictionary = sm.living_snapshot().world.get("pairs", {}).get(PAIR, {})
	t.check("saved_calendar_actual_bilateral_repair", repaired.get("day") == 3 and repaired.get("phase") == "clarification" and repaired.get("status") == "at_ease" and repaired.get("pause_minutes") == 2, str(repaired))
	await flow.page(t, "baker_maja", "living_pause", "LC_PAIR_CLARIFIED", "pair_clarified_actual_reopen")
	await t.world().travel(&"farm", &"default")
	await flow.roundtrip(t, "calendar_repaired")
	t.check("saved_repair_retains_shorter_duration", sm.living_snapshot().world.get("pairs", {}).get(PAIR, {}) == repaired)
	await t.world().sleep()
	await t.physics(4)
	t.check("repaired_to_short_pause_real_sleep_day4", gm.total_day() == 4)
	await flow.until_clock(t, 18, 42)
	await t.world().travel(&"hyggebyen", &"default")
	await t.physics(20)
	# At most three ordinary sample minutes to reach actual consent. This is a
	# single bounded occurrence, not restarting or filling an absent dwell.
	for i in 3:
		if sm.living_snapshot().world.get("pairs", {}).get(PAIR, {}).get("phase") == "accepted": break
		await flow.minute(t)
	var accepted: Dictionary = sm.living_snapshot().world.get("pairs", {}).get(PAIR, {})
	t.check("later_real_consent_uses_two_minute_pause", accepted.get("day") == 4 and accepted.get("phase") == "accepted" and accepted.get("pause_minutes") == 2, str(accepted))
	await flow.minute(t)
	var one_minute: Dictionary = sm.living_snapshot().world.get("pairs", {}).get(PAIR, {})
	t.check("one_minute_is_not_two_minute_attendance", one_minute.get("phase") == "accepted", str(one_minute))
	await flow.minute(t)
	var attended: Dictionary = sm.living_snapshot().world.get("pairs", {}).get(PAIR, {})
	t.check("second_actual_minute_completes_shorter_pause", attended.get("day") == 4 and attended.get("phase") == "attendance" and attended.get("pause_minutes") == 2 and attended.get("outcome_day") == 4, str(attended))
	t.check("autonomy_has_no_unoffered_private_player_attendance", sm.living_snapshot().get("responses", {}).is_empty())
	await flow.page(t, "baker_maja", "living_pause", "LC_PAIR_AT_EASE", "pair_at_ease_actual_reopen")
	print("RENEWED_CALENDAR_ENDPOINTS ", {"mismatch": mismatch, "repaired": repaired, "accepted": accepted, "one_minute": one_minute, "attended": attended})
	gm.clear_config_overrides()
