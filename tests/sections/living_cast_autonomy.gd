extends RefCounted
const SECTION := "living_cast_autonomy"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.day = 2
	gm.set_clock(16, 40)
	await t.world().travel(&"traetoppen", &"default")
	await t.physics(20)
	var sm: Node = t.autoload("SocialManager")
	var actor: Npc2D = NpcDirector.node_of("carpenter_brumme")
	t.check("real_loaded_brumme_present_at_optional_stay", is_instance_valid(actor) and Routines.where_is("carpenter_brumme", Routines.now_ctx()).get("act") == "sit")
	for i in 5:
		gm.advance_time(1)
		await t.physics(12)
	var row: Dictionary = sm.living_snapshot().world.get("citizens", {}).get("carpenter_brumme", {})
	t.check("loaded_npc_reflects_without_any_player_conversation", row.get("outcome") == "reflection" and row.get("closed_day") == gm.total_day(), str(row))
	if is_instance_valid(actor):
		t.player().global_position = actor.global_position + Vector2(25, 0)
		actor.interact(t.player())
		await t.frames(3)
		var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
		await load("res://tests/sections/living_encounters.gd").new().pick(t, screen, "living_motivation")
		t.check("actual_later_page_reports_only_completed_reflection", screen._lines.any(func(l): return l.get("text_key") == "LC_CARPENTER_BRUMME_REFLECTED"))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
	await _boundaries(t, gm, sm)
	await _value_execution(t)
	gm.clear_config_overrides()

func _boundaries(t, gm: Node, sm: Node) -> void:
	# Matched actual actor interruption: a brief departure cannot be filled by endpoint presence.
	var base: Dictionary = sm.to_dict()
	base.living.world.erase("citizens")
	for mode in ["brief_absence", "time_jump"]:
		sm.from_dict(base)
		gm.set_clock(16, 40)
		await t.physics(16)
		gm.advance_time(1)
		await t.physics(8)
		var actor: Npc2D = NpcDirector.node_of("carpenter_brumme")
		t.check(mode + "_starts_real_optional_dwell", sm._living_cast_runs.has("carpenter_brumme"))
		if mode == "brief_absence":
			var pos: Vector2 = actor.global_position
			actor.global_position += Vector2(2000, 0)
			await t.physics(2)
			actor.global_position = pos
			await t.physics(2)
			for i in 4:
				gm.advance_time(1)
				await t.physics(8)
		else:
			gm.advance_time(5)
			await t.physics(8)
		var row: Dictionary = sm.living_snapshot().world.get("citizens", {}).get("carpenter_brumme", {})
		t.check(mode + "_no_fabricated_completed_reflection", row.get("outcome") == "interrupted" and row.get("closed_day") == gm.total_day(), str(row))
	gm.set_clock(20, 0)
	await t.physics(16)
	for i in 4:
		gm.advance_time(1)
		await t.physics(8)
	t.check("natteblik_service_perch_never_mints_leisure_completion", not sm.living_snapshot().world.get("citizens", {}).has("mapseller_natteblik") and not sm._living_cast_runs.has("mapseller_natteblik"))

func _value_execution(t) -> void:
	var lr: Node = t.autoload("LuaRuntime")
	var original: Dictionary = lr._config.living_citizens.baker_maja
	for mode in ["ordinary", "welcome_priority"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		gm.day = 2
		gm.set_clock(18, 42)
		# Controlled authored value counterfactual, same real actors/routes/executor.
		var variant := original.duplicate(true)
		if mode == "welcome_priority":
			variant.values.quiet = 1
			variant.values.welcome = 5
		lr._config.living_citizens["baker_maja"] = variant
		await t.world().travel(&"hyggebyen", &"default")
		await t.physics(16)
		for i in 12:
			gm.advance_time(1)
			await t.physics(12)
		var sm: Node = t.autoload("SocialManager")
		var row: Dictionary = sm.living_snapshot().world.get("citizens", {}).get("baker_maja", {})
		t.check(mode + "_values_change_actual_loaded_execution", row.get("outcome") == ("connection" if mode == "ordinary" else "reflection"), str(row))
		if mode == "ordinary": t.check("connection_has_actual_named_npc_not_player_proxy", row.get("target") == "beekeeper_birk")
		gm.clear_config_overrides()
	lr._config.living_citizens["baker_maja"] = original
