extends RefCounted
const SECTION := "living_encounters"
const TIMEOUT_S := 180.0
const PAIR := "beekeeper_birk:smith_thorin"

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.day = 2
	gm.set_clock(18, 42)
	await t.world().travel(&"hyggebyen", &"default")
	await t.frames(6)
	var actor: Npc2D = NpcDirector.node_of("baker_maja")
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	var route: Dictionary = await load("res://tests/lib/town_loop/walker.gd").walk_to(t, actor.global_position, 65.0)
	t.check("encounter_walks_to_actual_actor", route.get("ok", false), str(route))
	actor.interact(t.player())
	await t.frames(3)
	var reached := await pick(t, screen, "living_pause")
	t.check("pilot_help_defer_decline_page_reachable_through_more", reached)
	if not reached:
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		gm.clear_config_overrides()
		return
	t.check("help_defer_decline_all_reachable", screen._choices.size() >= 3 and screen._choices.any(func(c): return c.get("action") == "living_help") and screen._choices.any(func(c): return c.get("action") == "living_defer") and screen._choices.any(func(c): return c.get("action") == "living_decline"))
	await pick(t, screen, "living_help")
	await t.frames(4)
	var response: Dictionary = sm.living_snapshot().get("responses", {}).get("p0", {})
	t.check("actual_terminal_help_is_intent_not_attendance", response.get("choice") == "help" and response.get("attended_day", 0) == 0, str(response))
	t.check("response_does_not_touch_other_player", not sm.living_snapshot().get("responses", {}).has("p1"))
	var eco: Node = t.autoload("EconomyManager")
	var gold: int = eco.gold
	var hearts: int = sm.points("baker_maja")
	for i in 9:
		gm.advance_time(1)
		await t.physics(8)
	response = sm.living_snapshot().get("responses", {}).get("p0", {})
	t.check("real_player_body_continuous_attendance_not_accept_alone", response.get("attended_day") == gm.total_day() and response.get("ack_day") == 0, str(response))
	actor.interact(t.player())
	await t.frames(3)
	await pick(t, screen, "living_pause")
	t.check("attendance_exposes_later_acknowledgement", await pick(t, screen, "living_ack"))
	t.check("actual_read_acknowledgement_terminal", sm.living_snapshot().get("responses", {}).get("p0", {}).get("ack_day") == gm.total_day())
	t.check("pilot_no_new_currency_or_hearts", eco.gold == gold and sm.points("baker_maja") == hearts)
	t.check("acknowledged_help_changes_later_visible_reply", load("res://scripts/social/living/living_dialogue.gd").pause_page("baker_maja", &"p0").lines[0].text_key == "LC_PAUSE_SUPPORTED")
	await _persistence(t, sm)
	await _responses(t, sm, gm, actor, screen)
	gm.clear_config_overrides()

func _persistence(t, sm: Node) -> void:
	var saves: Node = t.autoload("SaveManager")
	var old_dir: String = saves.save_dir
	saves.save_dir = "user://living_pair_pilot"
	saves.autosave_enabled = false
	var state: Dictionary = sm.living_snapshot()
	var healthy: Dictionary = sm.to_dict()
	t.check("pilot_real_primary_save", saves.save_game(0))
	t.check("pilot_real_second_save_creates_backup", saves.save_game(0))
	var primary := FileAccess.get_sha256(saves.slot_path(0))
	var backup := FileAccess.get_sha256(saves.backup_path(0))
	sm._living.world.pairs[PAIR]["status"] = "forged"
	t.allow("SaveManager: SocialManager.to_dict() did not return a Dictionary, the section 'social' is not saved")
	t.check("invalid_pair_refuses_actual_save_not_omission", not saves.save_game(0))
	t.check("invalid_pair_leaves_primary_backup_bytes_unchanged", primary == FileAccess.get_sha256(saves.slot_path(0)) and backup == FileAccess.get_sha256(saves.backup_path(0)))
	sm.from_dict(healthy) # rollback snapshot itself must be valid before a load
	var result: Dictionary = saves.try_load_game(0)
	t.check("pilot_actual_disk_load_restores_pair_and_private_response", result.get("ok", false) and sm.living_snapshot() == state, str(result))
	var codec := load("res://scripts/social/living/living_state.gd")
	for version in [1, 2]:
		var legacy := {"v": version, "world": {"pairs": {}}, "players": {}, "orphans": {"players": {}}}
		var decoded: Dictionary = codec.decode(legacy, SocialData.npcs())
		t.check("pilot_v%d_migrates_without_invented_pair" % version, decoded.ok and decoded.state.world.pairs.is_empty() and decoded.state.get("responses", {}).is_empty())
	var future: Dictionary = codec.empty()
	future["v"] = codec.VERSION + 1
	t.check("pilot_future_v4_is_rejected", not codec.decode(future, SocialData.npcs()).ok)
	saves.save_dir = old_dir

func _responses(t, sm: Node, gm: Node, actor: Npc2D, screen: Control) -> void:
	var baseline: Dictionary = sm.to_dict()
	baseline.living.erase("responses")
	baseline.living.world.pairs = {}
	for mode in ["cancel", "decline", "defer", "help_absent", "help_brief_absence"]:
		sm.from_dict(baseline)
		gm.set_clock(18, 42)
		await t.physics(16)
		actor.interact(t.player())
		await t.frames(3)
		t.check(mode + "_reaches_actual_pause_page", await pick(t, screen, "living_pause"))
		if mode == "cancel":
			t.tap_key(KEY_ESCAPE)
			await t.frames(3)
			t.check("cancel_pause_has_no_response", sm.living_snapshot().get("responses", {}).is_empty())
			continue
		await pick(t, screen, "living_help" if mode.begins_with("help_") else "living_" + mode)
		var r: Dictionary = sm.living_snapshot().get("responses", {}).get("p0", {})
		t.check(mode + "_commits_only_selected_intent", r.get("choice") == ("help" if mode.begins_with("help_") else mode) and r.get("attended_day", 0) == 0, str(r))
		if mode == "defer": t.check("defer_has_quiet_next_day_boundary", r.get("not_before_day") == gm.total_day() + 1)
		var position: Vector2 = t.player().global_position
		if mode == "help_absent": t.player().global_position += Vector2(2000, 0)
		for i in 9:
			gm.advance_time(1)
			await t.physics(8)
			if mode == "help_brief_absence" and i == 3:
				t.player().global_position += Vector2(2000, 0)
				await t.physics(2)
				t.player().global_position = position
				await t.physics(2)
		t.check(mode + "_npcs_continue_without_player", sm.living_snapshot().world.pairs.get(PAIR, {}).get("phase") == "attendance")
		t.check(mode + "_does_not_award_absent_or_declining_player", sm.living_snapshot().get("responses", {}).get("p0", {}).get("attended_day", 0) == 0)
		t.player().global_position = position
		if mode in ["decline", "defer"]:
			actor.interact(t.player())
			await t.frames(3)
			await pick(t, screen, "living_pause")
			t.check(mode + "_quiet_no_same_day_resolicitation", not screen._choices.any(func(c): return c.get("action") == "living_help"))
			t.tap_key(KEY_ESCAPE)
			await t.frames(3)
	var before: Dictionary = sm.living_snapshot()
	actor.handle_choice("living_help", {"npc": "baker_maja", "player_id": "p1", "reward": 999})
	t.check("forged_public_choice_cannot_mint_response", sm.living_snapshot() == before)

func pick(t, screen: Control, action: String) -> bool:
	for i in 8:
		await t.page_to_choices(screen)
		if not screen.is_open(): return false
		var wanted: Button
		var more: Button
		for button in screen._buttons:
			if button.get_meta("choice", {}).get("action") == action: wanted = button
			if button.get_meta("choice", {}).get("action") == "social_more": more = button
		var found := wanted != null
		if wanted == null: wanted = more
		if wanted == null: return false
		await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
		wanted.grab_focus()
		t.tap_key(KEY_ENTER)
		await t.frames(4)
		if found: return true
	return false
