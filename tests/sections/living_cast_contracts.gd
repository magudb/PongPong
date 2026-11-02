extends RefCounted
const SECTION := "living_cast_contracts"
const TIMEOUT_S := 180.0
const DATA := preload("res://scripts/social/living/living_data.gd")
const CAST := preload("res://scripts/social/living/living_cast.gd")
const ACTIONS := preload("res://scripts/social/living/living_actions.gd")
const CODEC := preload("res://scripts/social/living/living_state.gd")

func run(t) -> void:
	var errors := DATA.validate_actions()
	t.check("runtime_lua_bindings_all_declared_goals_and_copy_valid", errors.is_empty(), str(errors))
	var p := DATA.profile("carpenter_brumme").duplicate(true)
	var ordinary := ACTIONS.plan("carpenter_brumme", p, 2, {}, ["fairy_builder"])
	p.values["craft"] = 1
	p.values["listening"] = 5
	var changed := ACTIONS.plan("carpenter_brumme", p, 2, {}, ["fairy_builder"])
	t.check("value_counterfactual_changes_executable_reflection_to_connection", ordinary.get("executor") == "reflect" and changed.get("executor") == "connect", str([ordinary, changed]))
	t.check("missing_named_actor_cannot_be_replaced_by_player_listening", ACTIONS.plan("carpenter_brumme", p, 2, {}, []).get("executor") == "reflect")
	var inputs := {"day": 2, "available": true, "free_time": true, "protected": {"essential_work": false, "story": false, "festival": false, "home": false}, "eligible_goal_ids": []}
	t.check("explicit_empty_executor_allowlist_is_not_omitted", LivingGoals.select("carpenter_brumme", p, inputs).is_empty())
	var dense := CODEC.empty()
	dense["encounters"] = {}
	dense.world["citizens"] = {}
	for pid in ["p0", "p1", "p2", "p3"]:
		dense.encounters[pid] = {}
		for npc in DATA.AUDITED_IDS:
			var goal: String = DATA.profile(npc).goals[0].id
			dense.encounters[pid][npc] = {"day": 1000000, "goal": goal, "response": "clarify"}
	for npc in DATA.AUDITED_IDS:
		var cds := {}
		for goal in DATA.profile(npc).goals: cds[goal.id] = 1000014
		dense.world.citizens[npc] = {"day": 1000000, "goal": DATA.profile(npc).goals[0].id, "outcome": "reflection", "target": "", "closed_day": 1000000, "cooldowns": cds}
	var decoded := CODEC.decode(dense, SocialData.npcs())
	t.check("max_34_citizens_four_players_closed_codec_and_unchanged_byte_cap", decoded.ok and JSON.stringify(dense).to_utf8_buffer().size() < CODEC.MAX_BYTES, str(JSON.stringify(dense).to_utf8_buffer().size()))
	var retired := CODEC.decode(dense, {})
	t.check("allcast_retirement_bounded_orphans", retired.ok and retired.state.get("encounters", {}).is_empty() and retired.state.world.get("citizens", {}).is_empty() and JSON.stringify(retired.state.orphans).to_utf8_buffer().size() <= 65536)
	var restored := CODEC.decode(retired.get("state", {}), SocialData.npcs())
	t.check("allcast_reappearance_keeps_durable_response_and_terminal_stamps", restored.get("state", {}) == decoded.get("state", {}))
	var raw := dense.duplicate(true)
	var unchanged := raw.duplicate(true)
	CODEC.decode(raw, {})
	t.check("decode_is_pure_no_settlement_or_input_mutation", raw == unchanged)
	for version in [1, 2, 3]:
		var legacy := CODEC.empty()
		legacy["v"] = version
		t.check("legacy_v%d_no_invented_fullcast_actions" % version, CODEC.decode(legacy, SocialData.npcs()).ok)
	for malformed in [null, false, 0.5, "wrong", [], {"p9": {}}, {"p0": {"not_a_citizen": {}}}, {"p0": {"carpenter_brumme": {"day": 2, "goal": "lc_carpenter_brumme_personal", "response": StringName("listen")}}}]:
		var bad := CODEC.empty()
		bad["encounters"] = malformed
		t.check("closed_encounter_type_bound_" + str(malformed), not CODEC.decode(bad, SocialData.npcs()).ok)
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var sm: Node = t.autoload("SocialManager")
	var saves: Node = t.autoload("SaveManager")
	var old_dir: String = saves.save_dir
	saves.save_dir = "user://living_fullcast"
	saves.autosave_enabled = false
	var healthy: Dictionary = sm.to_dict()
	healthy["living"] = dense
	t.check("dense_fullcast_actual_social_apply", sm.from_dict(healthy))
	# A fresh scene naturally runs today's optional pilot reducer. Settle that
	# genuine lifecycle BEFORE freezing the dense whole-save baseline, so the
	# handoff's exact snapshot oracle does not mistake normal progress for loss.
	sm.flush()
	t.check("dense_settlement_preserves_all_original_cast_stamps", sm.living_snapshot().encounters == dense.encounters and sm.living_snapshot().world.citizens == dense.world.citizens)
	t.check("dense_fullcast_real_primary_save", saves.save_game(0))
	t.check("dense_fullcast_real_backup_save", saves.save_game(0))
	var expected: Dictionary = sm.living_snapshot()
	var result: Dictionary = saves.try_load_game(0)
	t.check("dense_fullcast_actual_primary_load_roundtrip", result.get("ok", false) and sm.living_snapshot() == expected, str(result))
	# The corruption oracle must reach Social serialization, not stale-World refusal.
	if not await load("res://tests/progression/living_delivery.gd").resume_loaded_world(t, "fullcast_primary"): return
	var primary := FileAccess.get_sha256(saves.slot_path(0))
	var backup := FileAccess.get_sha256(saves.backup_path(0))
	sm._living.encounters["p0"]["carpenter_brumme"]["response"] = "forged"
	t.allow("SaveManager: SocialManager.to_dict() did not return a Dictionary, the section 'social' is not saved")
	t.check("corrupt_new_state_refuses_real_save_not_silent_omission", not saves.save_game(0))
	t.check("corrupt_new_state_preserves_primary_and_backup_bytes", FileAccess.get_sha256(saves.slot_path(0)) == primary and FileAccess.get_sha256(saves.backup_path(0)) == backup)
	sm.from_dict(healthy)
	# Real backup fallback, not a helper-only codec roundtrip.
	var corrupt := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
	corrupt.store_string("invalid-json")
	corrupt.close()
	result = saves.try_load_game(0)
	t.check("allcast_real_backup_fallback_restores_stamps", result.get("ok", false) and sm.living_snapshot() == expected, str(result))
	if not await load("res://tests/progression/living_delivery.gd").resume_loaded_world(t, "fullcast_backup"): return
	saves.save_dir = old_dir
	gm.clear_config_overrides()
