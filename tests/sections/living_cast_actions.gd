extends RefCounted
## Controlled placed canonical actors, one at a time; NOT authored-map presence acceptance.
const SECTION := "living_cast_actions"
const TIMEOUT_S := 480.0
const DATA := preload("res://scripts/social/living/living_data.gd")
const CAST := preload("res://scripts/social/living/living_cast.gd")
var picker: RefCounted = load("res://tests/sections/living_encounters.gd").new()

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.year = 2
	gm.day = 2 # beyond the real cat gate's day alternative, no forged quest completion
	gm.set_clock(20, 0)
	var sm: Node = t.autoload("SocialManager")
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	for npc in DATA.AUDITED_IDS:
		if Routines.is_unavailable(npc, Routines.now_ctx()):
			t.check(npc + "_actual_hero_or_unlock_absence_preserved", CAST.choice(npc).is_empty())
			continue
		var actor := Npc2D.create({"id": npc, "wander": "0"})
		actor.area = t.player().area
		actor.position = t.player().position + Vector2(25, 0)
		t.player().get_parent().add_child(actor)
		# Ghost kin introductions are protected authored scenes, not ordinary social pages.
		# Read and close them through the real UI before exercising the unchanged route.
		if gm.character_type == gm.CharacterType.GHOST and npc in ["ghostfam_blund", "ghostfam_dyne", "ghostfam_gnist", "ghostfam_silke"]:
			actor.interact(t.player())
			await t.frames(3)
			var intro_ticket: RefCounted = actor._lease
			var intro_line_count: int = screen._lines.size()
			t.check(npc + "_authored_kin_intro_wins_first_talk", screen.is_open() and actor._talk_pages[intro_ticket].page.get("social", true) == false and intro_line_count > 0 and screen._lines.all(func(l): return str(l.get("text_key", "")).begins_with("DLG_" + npc.to_upper() + "_KIN_1_")) and screen._choices.any(func(c): return c.get("action") == "close") and not screen._choices.any(func(c): return str(c.get("action", "")).begins_with("living_") or c.get("action") == "social_more"))
			var intro_closed: bool = await picker.pick(t, screen, "close")
			t.check(npc + "_authored_kin_intro_read_and_closed_through_real_ui", intro_closed and not screen.is_open() and intro_ticket.resolved and intro_ticket._result.get("completed", false) and intro_ticket._result.get("lines_shown", 0) == intro_line_count and intro_ticket._result.get("choice", {}).get("action") == "close")
		actor.interact(t.player())
		await t.frames(3)
		var reached: bool = await picker.pick(t, screen, "living_motivation")
		t.check(npc + "_actual_npc_ui_semantic_motivation_reachable", reached)
		if not reached:
			t.tap_key(KEY_ESCAPE)
			await t.frames(3)
			actor.queue_free()
			await t.frames(2)
			continue
		await t.page_to_choices(screen)
		var p := DATA.profile(npc)
		t.check(npc + "_purpose_aspiration_weighted_goal_and_tie_visible", screen._lines.any(func(l): return l.get("text_key") == p.purpose_key) and screen._lines.any(func(l): return l.get("text_key") == p.aspiration_key) and screen._lines.any(func(l): return l.get("text_key") == p.ties[0].reason_key))
		var before: Dictionary = sm.living_snapshot()
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		t.check(npc + "_matched_cancel_has_no_response", sm.living_snapshot() == before)
		var no_response: Dictionary = sm.to_dict()
		actor.interact(t.player())
		await t.frames(3)
		await picker.pick(t, screen, "living_motivation")
		var spaced: bool = await picker.pick(t, screen, "living_space")
		t.check(npc + "_deliberate_space_terminal", spaced and sm.living_snapshot().get("encounters", {}).get("p0", {}).get(npc, {}).get("response") == "space")
		actor.interact(t.player())
		await t.frames(3)
		await picker.pick(t, screen, "living_motivation")
		t.check(npc + "_later_space_respected_no_same_day_resolicitation", screen._lines.any(func(line): return line.get("text_key") == "LC_" + npc.to_upper() + "_SPACED") and not screen._choices.any(func(c): return c.get("action") == "living_listen"))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		sm.from_dict(no_response) # matched alternative, not a fabricated response receipt
		actor.interact(t.player())
		await t.frames(3)
		await picker.pick(t, screen, "living_motivation")
		var chosen: bool = await picker.pick(t, screen, "living_listen")
		t.check(npc + "_real_read_repeatback_terminal", chosen and sm.living_snapshot().get("encounters", {}).get("p0", {}).get(npc, {}).get("response") == "listen")
		actor.interact(t.player())
		await t.frames(3)
		await picker.pick(t, screen, "living_motivation")
		t.check(npc + "_later_actual_page_uses_earned_reply", screen._lines.any(func(line): return line.get("text_key") == "LC_" + npc.to_upper() + "_LISTENED"))
		await picker.pick(t, screen, "living_correct")
		var correction_before: Dictionary = sm.living_snapshot()
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		t.check(npc + "_unread_correction_cannot_complete", sm.living_snapshot() == correction_before)
		actor.interact(t.player())
		await t.frames(3)
		await picker.pick(t, screen, "living_motivation")
		await picker.pick(t, screen, "living_correct")
		var confirmed: bool = await picker.pick(t, screen, "living_confirm")
		t.check(npc + "_actual_corrected_explanation_acknowledged", confirmed and sm.living_snapshot().get("encounters", {}).get("p0", {}).get(npc, {}).get("response") == "clarify")
		actor.interact(t.player())
		await t.frames(3)
		await picker.pick(t, screen, "living_motivation")
		t.check(npc + "_later_actual_page_uses_clarified_reply", screen._lines.any(func(line): return line.get("text_key") == "LC_" + npc.to_upper() + "_CLARIFIED"))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		actor.queue_free()
		await t.frames(2)
	t.check("allcast_private_response_does_not_touch_p1", not sm.living_snapshot().get("encounters", {}).has("p1"))
	gm.clear_config_overrides()
