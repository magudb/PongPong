extends RefCounted
const SECTION := "living_activity_safety"
const TIMEOUT_S := 180.0
const ACT := preload("res://scripts/social/living/living_activity.gd")
const CODEC := preload("res://scripts/social/living/living_state.gd")
const NPC := "smith_thorin"

func run(t) -> void:
	await load("res://tests/progression/living_delivery.gd").run(t)
	var sm: Node = t.autoload("SocialManager")
	var gm: Node = t.autoload("GameManager")
	var tm: Node = t.autoload("TimeManager")
	var sv: Node = t.autoload("SaveManager")
	var lr: Node = t.autoload("LuaRuntime")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	tm.set_weather(&"klart")
	var receipt: Dictionary = sm.to_dict()
	var private_before: Dictionary = receipt.living.players.duplicate(true)
	var source_day: int = gm.total_day()
	gm.day += 1 # Explicit clock fixture; lifecycle uses the real owner below.
	var before: Dictionary = sm._living.duplicate(true)
	var preflush: Dictionary = sv.gather_payload()
	var calls: Array = []
	var listen := func(id, payload):
		if id == &"living_schedule_changed": calls.append(payload)
	t.autoload("EventBus").game_event.connect(listen)
	sm._defer()
	for i in 4:
		sm.living_context(NPC, &"p1")
		sm.living_activity_snapshot()
		Routines.where_is(NPC, Routines.now_ctx())
		sm.to_dict()
	t.check("queries_and_preflush_save_do_not_settle", sm._living == before and calls.is_empty())
	sm.flush()
	var after: Dictionary = sm.to_dict()
	var snapshot: Dictionary = sm.living_activity_snapshot()
	t.check("one_committed_schedule_notification", calls.size() == 1 and calls[0].is_empty())
	t.check("small_snapshot_recursive_immutable_cached", snapshot.is_read_only() and snapshot.selected.is_read_only() and snapshot.selected.reasons.is_read_only() and is_same(snapshot, sm.living_activity_snapshot()) and JSON.stringify(snapshot).to_utf8_buffer().size() < 1024 and not JSON.stringify(snapshot).contains("p1"))
	t.check("history_and_pending_consumed_once", after.living.world.pilot.pending_day == source_day and after.living.world.pilot.consumed_day == source_day and after.living.world.pilot.cooldowns.get(ACT.PERSONAL) == source_day + 3 and after.living.players == private_before)
	t.check("preflush_payload_applies_purely", sv._apply_payload(preflush).ok and sm._living == before)
	await t.frames(3)
	t.check("apply_without_load_completed_no_stale_queue", sm._living == before)
	t.autoload("EventBus").load_completed.emit(0)
	await t.frames(3)
	t.check("preflush_committed_load_replays_exactly", sm.to_dict().living == after.living)
	if not await load("res://tests/progression/living_delivery.gd").resume_loaded_world(t, "preflush_apply"): return
	var directory: String = sv.save_dir
	sv.save_dir = "user://living-activity-latch"
	t.check("postflush_disk_roundtrip", sv.save_game(0) and sv.load_game(0) and sm.to_dict().living == after.living)
	await t.frames(3)
	t.check("postflush_load_does_not_reroll", sm.to_dict().living == after.living)
	if not await load("res://tests/progression/living_delivery.gd").resume_loaded_world(t, "postflush_disk"): return
	sv.save_dir = directory
	var reject: Node = load("res://tests/sections/living_memory.gd").LateReject.new()
	t.tree.root.add_child(reject)
	t.expect(sv.register_section("zz_activity_reject", reject, 900), "register selected-day rollback fixture")
	var rollback: Dictionary = sv.gather_payload()
	rollback.social.erase("living")
	rollback.zz_activity_reject = {"fail": true}
	var count_before := calls.size()
	sm._defer()
	t.check("selected_day_failed_load_rolls_back", not sv._apply_payload(rollback).ok and sm.to_dict().living == after.living)
	await t.frames(3)
	t.check("selected_day_failed_load_no_stale_settlement", sm.to_dict().living == after.living and calls.size() == count_before)
	sv.unregister_section("zz_activity_reject")
	reject.queue_free()
	var latch: Dictionary = sm._living.duplicate(true)
	tm.set_weather(&"regn")
	sm.flush()
	t.check("blocked_selected_day_retains_snapshot_no_reroll", sm._living == latch and sm.living_activity_snapshot() == snapshot)
	tm.set_weather(&"klart")
	_projection(t, snapshot)
	_dialogue_guards(t, sm)
	# Actual old v1 receipts migrate additively, without manufacturing new
	# shared knowledge from arbitrary private rows or legacy hearts.
	var v1: Dictionary = receipt.living.duplicate(true)
	v1.v = 1
	v1.world = {"pairs": {}}
	var migrated: Dictionary = CODEC.decode(v1, SocialData.npcs())
	t.check("v1_private_receipts_survive_without_trigger_inference", migrated.ok and migrated.state.players == private_before and migrated.state.world == {"pairs": {}})
	# An empty blocked day is itself a durable latch, not permission to retry
	# whenever weather/holds/availability change. Pending survives to day 3.
	sm.from_dict(receipt)
	tm.set_weather(&"regn")
	sm.flush()
	var blocked: Dictionary = sm.to_dict()
	t.check("unavailable_day_empty_latch_keeps_pending", blocked.living.world.pilot.attempt_day == source_day + 1 and blocked.living.world.pilot.selected.is_empty() and blocked.living.world.pilot.pending_day == source_day and int(blocked.living.world.pilot.get("consumed_day", 0)) == 0)
	t.check("empty_day_snapshot_recursively_immutable", sm.living_activity_snapshot().is_read_only() and sm.living_activity_snapshot().selected.is_read_only())
	tm.set_weather(&"klart")
	sm.flush()
	t.check("empty_day_does_not_retry", sm.to_dict().living == blocked.living)
	t.check("empty_day_latch_roundtrip", sm.from_dict(JSON.parse_string(JSON.stringify(blocked))))
	sm.flush()
	t.check("empty_day_after_load_still_not_retry", sm.to_dict().living == blocked.living)
	gm.day += 1
	sm.flush()
	t.check("pending_next_safe_day_selected", sm.living_activity_snapshot().selected.get("goal_id") == ACT.PERSONAL)
	# Suspend an unconsumed source with the actual content-retirement lifecycle.
	sm.from_dict(receipt)
	var known: Dictionary = SocialData.npcs().duplicate(true)
	known.erase(NPC)
	lr._config.npcs = known
	t.allow("SocialManager.from_dict: unknown NPC 'smith_thorin' kept in the orphans bucket")
	t.check("retired_source_load", sm.from_dict(sm.to_dict()))
	var retired_raw: Dictionary = sm._living.duplicate(true)
	sm.flush()
	var retired_latched: Dictionary = sm.living_snapshot()
	t.check("retired_empty_day_latch_keeps_pending", retired_latched.orphans.get("pilot", {}).get("attempt_day") == gm.total_day() and retired_latched.orphans.get("pilot", {}).get("pending_day") == source_day and sm.living_activity_snapshot().selected.is_empty())
	retired_raw = sm._living.duplicate(true)
	lr.reload_scripts()
	t.check("reappearance_queries_pure", sm._living == retired_raw and sm.living_snapshot().players == private_before)
	sm.flush()
	t.check("retired_day_does_not_reroll_on_reappearance", sm.living_activity_snapshot().selected.is_empty() and sm._living == retired_raw)
	gm.day += 1
	sm.flush()
	t.check("reappearance_preserves_pending_and_selects", sm.living_activity_snapshot().selected.get("goal_id") == ACT.PERSONAL and sm._living.world.get("pilot", {}).get("consumed_day") == source_day)
	# Removed goal hides the saved snapshot through every public presentation,
	# then restores it on content reload, without destructive reconciliation.
	sm.from_dict(after)
	gm.day = source_day + 1
	var original: Dictionary = sm._living.duplicate(true)
	var profiles: Dictionary = LivingData.profiles().duplicate(true)
	profiles[NPC].goals = profiles[NPC].goals.filter(func(g): return g.id != ACT.PERSONAL)
	lr._config.living_citizens = profiles
	t.check("retired_goal_hidden_from_activity_and_dialogue", sm.living_activity_snapshot().selected.is_empty() and load("res://scripts/social/living/living_dialogue.gd").choice(NPC).is_empty() and sm._living == original)
	lr.reload_scripts()
	t.check("retired_goal_reappears_without_reroll", sm.living_activity_snapshot().selected.get("goal_id") == ACT.PERSONAL and sm._living == original)
	# Offscreen skip-catchup is bounded in elapsed days: only today's attempt,
	# no historical goals/rewards/witness memories or notification storm.
	sm.from_dict(receipt)
	gm.year = 400
	gm.day = 2
	var start := Time.get_ticks_usec()
	var events_before := calls.size()
	sm.flush()
	var elapsed := Time.get_ticks_usec() - start
	var far: Dictionary = sm.to_dict().living
	t.check("offscreen_long_jump_one_latch_bounded_growth", far.world.pilot.attempt_day == gm.total_day() and far.players.p1.npcs[NPC].source_watermarks == private_before.p1.npcs[NPC].source_watermarks and JSON.stringify(far).to_utf8_buffer().size() < 4096 and calls.size() - events_before <= 1, "%d us incl legacy daily reducer (reported)" % elapsed)
	_codec(t, after.living)
	# Exercise malformed runtime data through both real facade callers, not
	# just the pure reducer. Reads must hide the saved selection, never erase it.
	sm.from_dict(after)
	var malformed_profiles: Dictionary = LivingData.profiles().duplicate(true)
	malformed_profiles[NPC].goals = [null]
	lr._config.living_citizens = malformed_profiles
	var before_malformed: Dictionary = sm._living.duplicate(true)
	t.check("malformed_profile_public_facade_pure_fail_closed", sm.living_activity_snapshot().selected.is_empty() and sm._living == before_malformed)
	gm.day += 1
	sm.flush()
	t.check("malformed_profile_lifecycle_empty_day_fail_closed", sm._living.world.pilot.attempt_day == gm.total_day() and sm._living.world.pilot.selected.is_empty())
	lr.reload_scripts()
	_reload_routes(t, after)
	_direct_route_reloads(t)
	await _unsupported_content(t, after)
	await _failed_snapshot(t, after)
	var peer := ENetMultiplayerPeer.new()
	if t.expect(peer.create_server(0) == OK, "activity network guard real peer"):
		var previous: MultiplayerPeer = sm.multiplayer.multiplayer_peer
		sm.multiplayer.multiplayer_peer = peer
		var unsupported: Dictionary = sm._living.duplicate(true)
		gm.day += 1
		sm.flush()
		t.check("unsupported_network_peer_cannot_settle_activity", sm._living == unsupported)
		sm.multiplayer.multiplayer_peer = previous
		peer.close()
	t.autoload("EventBus").game_event.disconnect(listen)
	gm.clear_config_overrides()

func _projection(t, snapshot: Dictionary) -> void:
	var ctx := Routines.make_ctx(1, 19.5, "klart", {"total_day": snapshot.day, "living_activity": snapshot})
	var base := Routines.timeline(NPC, "work", false)
	var over := ACT.timeline(NPC, ctx, base)
	t.check("safe_authored_excursion_positive_control", over.size() == base.size() + 4 and Routines._seg_at(over, 19.5).get("place") == ACT.POST)
	var untouched := base.filter(func(s): return s.get("place") != ACT.ORIGIN)
	t.check("every_nonleisure_commitment_exactly_preserved", untouched.all(func(s): return over.has(s)))
	var source: Dictionary = base.filter(func(s): return s.get("place") == ACT.ORIGIN)[0]
	var outbound: Dictionary = over.filter(func(s): return s.get("kind") == "move" and s.get("to") == ACT.POST)[0]
	var back: Dictionary = over.filter(func(s): return s.get("kind") == "move" and s.get("from") == ACT.POST)[0]
	t.check("entire_travel_dwell_return_inside_authored_slack", float(outbound.t0) >= float(source.t0) and float(back.t1) <= float(source.t1))
	for boundary in ["outbound", "return"]:
		var h := {"open": float(outbound.t0) - 0.01, "close": 19.25} if boundary == "outbound" else {"open": 20.0, "close": float(back.t1) + 0.01}
		Hours.override_registry = {"essential_keeper": {"keeper": NPC, "hours": h}}
		t.check("new_keeper_commitment_protects_" + boundary + "_not_only_dwell", ACT.timeline(NPC, ctx, base) == base)
	Hours.override_registry = {}
	ACT.clear_cache()
	for key in ["fest", "home_guests", "weather", "weekday"]:
		var blocked := ctx.duplicate(true)
		blocked[key] = {"fest": {"id": "test"}, "home_guests": [NPC], "weather": "regn", "weekday": 4}[key]
		t.check("projection_protects_" + key, ACT.timeline(NPC, blocked, base) == base)
	for boundary in ["outbound", "return", "work"]:
		var constrained := base.duplicate(true)
		var optional: Dictionary = constrained.filter(func(s): return s.get("place") == ACT.ORIGIN)[0]
		if boundary == "outbound": optional.t0 = 19.25
		if boundary == "return": optional.t1 = 20.0
		if boundary == "work": optional.act = "work"
		t.check("whole_envelope_refusal_" + boundary, ACT.timeline(NPC, ctx, constrained) == constrained)
	var reg := Routines.registry().duplicate(true)
	reg[NPC].gate = {"done_quest": "unknown", "or_day": 999999}
	Routines.override_registry = reg
	t.check("gate_unavailable_no_override", Routines.where_is(NPC, ctx).state == "absent" and ACT.timeline(NPC, ctx, base) == base)
	reg[NPC].erase("gate")
	reg[NPC].hero_twin = "fixture"
	ctx.hero = "fixture"
	t.check("hero_twin_no_override", Routines.where_is(NPC, ctx).state == "absent" and ACT.timeline(NPC, ctx, base) == base)
	Routines.override_registry = {}
	ACT.clear_cache()

func _dialogue_guards(t, sm: Node) -> void:
	var bridge := load("res://scripts/social/talk/dialogue_bridge.gd")
	var before: Dictionary = sm._living.duplicate(true)
	var story := {"social": false, "lines": [{"text_key": "DLG_NEUTRAL"}], "choices": []}
	t.check("authored_social_false_never_decorated", bridge.decorate(NPC, story) == story)
	var services: Array = []
	for i in 14: services.append({"id": "service_%d" % i, "action": "shop_%d" % i, "text": "service"})
	var menu: Dictionary = bridge.decorate(NPC, {"lines": [], "choices": services})
	var actions: Array = []
	for page in 10:
		for c in menu.get("choices", []):
			if c.action != "social_more": actions.append(c.action)
		var more: Array = menu.get("choices", []).filter(func(c): return c.action == "social_more")
		if more.is_empty(): break
		menu = bridge.action(NPC, "social_more", more[0]).page
	t.check("all_service_choices_and_living_reachable_through_more", range(14).all(func(i): return actions.has("shop_%d" % i)) and actions.has("living_activity") and actions.count("close") >= 1)
	t.check("decorate_and_more_are_pure", sm._living == before)

func _reload_routes(t, saved: Dictionary) -> void:
	var sm: Node = t.autoload("SocialManager")
	var gm: Node = t.autoload("GameManager")
	var lr: Node = t.autoload("LuaRuntime")
	gm.year = 1
	gm.day = int(saved.living.world.pilot.attempt_day)
	sm.from_dict(saved)
	var ctx := Routines.make_ctx(1, 19.5, "klart", {"total_day": gm.total_day(), "living_activity": sm.living_activity_snapshot()})
	var latch: Dictionary = sm._living.duplicate(true)
	t.expect(Routines.where_is(NPC, ctx).place == ACT.POST and not ACT.envelope(ctx).is_empty() and not RouteTable.path(ACT.ORIGIN, ACT.POST).is_empty(), "all caches warm before real reload")
	var file := "res://lua/routines/core/smith_thorin.lua"
	var original := FileAccess.get_file_as_string(file)
	var changed := original.replace('at = "hyggebyen.torv_fountain_e", act = "sit"', 'at = "hyggebyen.torv_fountain_e", act = "work"')
	t.expect(changed != original, "real authored reload fixture changes leisure to protected work")
	FileAccess.open(file, FileAccess.WRITE).store_string(changed)
	lr.reload_scripts()
	var fresh := Routines.where_is(NPC, ctx)
	t.check("real_reload_new_protected_work_never_overridden", fresh.get("place") == ACT.ORIGIN and fresh.get("act") == "work" and ACT.envelope(ctx).is_empty() and sm._living == latch, str(fresh))
	FileAccess.open(file, FileAccess.WRITE).store_string(original)
	lr.reload_scripts()
	t.check("real_reload_preserves_same_day_activity_latch", sm._living == latch and sm.living_activity_snapshot().selected.get("goal_id") == ACT.PERSONAL)
	var routes := JSON.parse_string(FileAccess.get_file_as_string("res://data/towns/routes.json")) as Dictionary
	var area: Dictionary = routes.areas.hyggebyen
	var ix: int = area.names.find("torv_fountain_e")
	var iy: int = area.names.find("torv_bench2")
	ACT.envelope(ctx)
	area.d[ix][iy] = -1
	area.d[iy][ix] = -1
	var route_file := "user://living-disconnected-routes.json"
	FileAccess.open(route_file, FileAccess.WRITE).store_string(JSON.stringify(routes))
	RouteTable.load_table(route_file)
	var legs := RouteTable.path(ACT.ORIGIN, ACT.POST)
	t.expect(RouteTable.has_anchor(ACT.ORIGIN) and RouteTable.has_anchor(ACT.POST) and not legs.is_empty() and legs[0].get("estimated", false), "disconnected anchors nonempty estimated route positive control")
	t.check("route_generation_invalidates_warm_excursion_and_rejects_estimate", ACT.envelope(ctx).is_empty() and Routines.where_is(NPC, ctx).place != ACT.POST and sm._living == latch)
	RouteTable.load_table()
	t.check("restored_route_generation_restores_excursion", not ACT.envelope(ctx).is_empty() and Routines.where_is(NPC, ctx).place == ACT.POST and sm._living == latch)
	print("LIVING_FIX_PERF ", JSON.stringify({"selected_thorin_where_is_cached_us": t.median_usec(func(): Routines.where_is(NPC, ctx)), "envelope_cached_us": t.median_usec(func(): ACT.envelope(ctx)), "now_ctx_with_snapshot_us": t.median_usec(func(): Routines.now_ctx()), "snapshot_cached_us": t.median_usec(func(): sm.living_activity_snapshot()), "routine_native_reference_us": 20, "scale": OS.get_environment("TT_PERF_SCALE")}))

func _warm_timelines() -> void:
	Routines.timeline(NPC, "work", false)
	Routines.timeline(NPC, "sun", false)
	Routines.timeline(NPC, "work", true)
	Routines.timeline(NPC, "work", false, {"at": ACT.POST, "from": 13.0, "to": 14.0})

func _direct_route_reloads(t) -> void:
	var sm: Node = t.autoload("SocialManager")
	var ctx := Routines.now_ctx()
	var plan := Routines.daily_plan(NPC, ctx)
	var commitments := Routines._plans.duplicate(true)
	var festivals := Routines._fb.duplicate(true)
	var living: Dictionary = sm._living.duplicate(true)
	var data := JSON.parse_string(FileAccess.get_file_as_string("res://data/towns/routes.json")) as Dictionary
	var area: Dictionary = data.areas.hyggebyen
	var a: int = area.names.find("forge_front")
	var b: int = area.names.find("torv_fountain_e")
	var path := "user://living-direct-reload.json"
	_warm_timelines()
	var fresh_results := true
	var bounded := true
	var previous := -1.0
	for i in 12:
		area.d[a][b] = 100 + i * 100
		area.d[b][a] = area.d[a][b]
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(data))
		fresh_results = RouteTable.load_table(path) and fresh_results
		_warm_timelines()
		var moves := Routines.timeline(NPC, "work", false).filter(func(s): return s.get("from") == "hyggebyen.forge_front" and s.get("to") == ACT.ORIGIN)
		var duration := float(moves[0].t1) - float(moves[0].t0) if moves.size() == 1 else -1.0
		fresh_results = fresh_results and duration > previous and is_equal_approx(duration, float(area.d[a][b]) / RouteTable.speed * RouteTable.game_min_per_s / 60.0)
		previous = duration
		bounded = bounded and Routines._tl.size() == 4
	t.check("repeated_direct_reload_uses_changed_routes", fresh_results)
	t.check("repeated_direct_reload_obsolete_timelines_evicted_bounded", bounded, "%d retained after 12 reloads (4 warmed variants)" % Routines._tl.size())
	t.check("direct_reload_keeps_daily_plan_and_persisted_selection", sm._living == living and Routines._plans == commitments and Routines._fb == festivals and Routines.daily_plan(NPC, ctx) == plan)
	# Failed loads clear the route table and advance its generation too. The
	# next timeline read must not reuse old baked legs (there is no auto retry).
	var failed := not RouteTable.load_table("user://no-such-living-routes.json")
	_warm_timelines()
	t.check("failed_direct_reload_invalidates_timelines", failed and not RouteTable.is_loaded() and Routines._tl.size() == 4 and Routines.timeline(NPC, "work", false).any(func(s): return s.get("legs", []).any(func(l): return l.get("estimated", false))))
	RouteTable.load_table()
	_warm_timelines()
	t.check("restored_direct_reload_bounded_without_session_reset", RouteTable.is_loaded() and Routines._tl.size() == 4 and sm._living == living and Routines._plans == commitments)

func _unsupported_content(t, saved: Dictionary) -> void:
	var sm: Node = t.autoload("SocialManager")
	var gm: Node = t.autoload("GameManager")
	var lr: Node = t.autoload("LuaRuntime")
	var sv: Node = t.autoload("SaveManager")
	var old_dir: String = sv.save_dir
	sv.save_dir = "user://living-fix-unsupported"
	var fixture := saved.duplicate(true)
	gm.year = 1
	for id in ACT.IDS:
		if not fixture.living.world.pilot.cooldowns.has(id): fixture.living.world.pilot.cooldowns[id] = 1
	for field in ["id", "kind", "value", "target", "trigger"]:
		lr.reload_scripts()
		var profiles := LivingData.profiles().duplicate(true)
		var goal: Dictionary = profiles[NPC].goals[1]
		if field == "id": goal.id = "lc_smith_thorin_new_personal"
		if field == "kind": goal.kind = "role"; goal.trigger = "none"
		if field == "value": goal.value = "quiet"
		if field == "trigger": goal.trigger = "none"
		if field == "target":
			goal = profiles[NPC].goals[2]
			profiles[NPC].ties.append({"target": "bodil", "provenance": "proposed", "source": LivingData.PROPOSAL_PATH, "reason_key": "LC_FIX_TIE"})
			goal.target = "bodil"
		t.check("unsupported_%s_structurally_valid_control" % field, LivingGoals._profile(NPC, profiles[NPC]))
		sm.from_dict(fixture)
		gm.day = int(fixture.living.world.pilot.attempt_day) + 1
		lr._config.living_citizens = profiles
		sm.flush()
		var projected: Dictionary = sm.to_dict()
		var row: Dictionary = projected.get("living", {}).get("world", {}).get("pilot", {})
		t.check("unsupported_%s_safe_empty_preserves_history_private" % field, row.get("attempt_day") == gm.total_day() and row.get("selected", {"bad": true}).is_empty() and row.get("cooldowns") == fixture.living.world.pilot.cooldowns and row.get("pending_day") == fixture.living.world.pilot.pending_day and row.get("consumed_day") == fixture.living.world.pilot.consumed_day and projected.get("living", {}).get("players") == fixture.living.players)
		t.check("unsupported_%s_actual_save_reload" % field, sv.save_game(0) and sv.load_game(0) and sm.to_dict().get("living", {}).get("players") == fixture.living.players and sm.to_dict().get("living", {}).get("world", {}).get("pilot") == row)
		if not await load("res://tests/progression/living_delivery.gd").resume_loaded_world(t, "unsupported_" + field): return
	lr.reload_scripts()
	sm.from_dict(saved)
	var newer: Dictionary = saved.living.world.pilot.duplicate(true)
	newer.attempt_day += 1
	newer.selected = {}
	newer.pending_day += 1
	sm._living.orphans["pilot"] = newer
	sm._living_invalidate()
	var mixed: Dictionary = sm._living.duplicate(true)
	var reconciled: Dictionary = CODEC.decode(mixed, SocialData.npcs(), gm.total_day())
	t.check("active_orphan_facades_share_pure_latest_projection", reconciled.ok and sm.living_snapshot() == reconciled.state and sm.to_dict().living == reconciled.state and sm.living_activity_snapshot().day == newer.attempt_day and sm.living_activity_snapshot().selected.is_empty() and sm._living == mixed, "decoded=%s snapshot=%s expected_day=%s pure=%s projected=%s expected=%s" % [reconciled.ok, sm.living_activity_snapshot(), newer.attempt_day, sm._living == mixed, sm.living_snapshot(), reconciled.get("state", {})])
	sm._living.orphans.pilot.attempt_day = sm._living.world.pilot.attempt_day
	sm._living_invalidate()
	var conflict: Dictionary = sm._living.duplicate(true)
	gm.day += 1
	sm.flush()
	t.check("conflicting_active_orphan_cannot_present_settle_or_save", sm.living_activity_snapshot().selected.is_empty() and sm.to_dict() == null and sm._living == conflict)
	sm.from_dict(saved)
	t.expect(sv.save_game(0), "valid disk file before internal corruption")
	var path: String = sv.slot_path(0)
	var hash_before := FileAccess.get_sha256(path)
	var backup_before := FileAccess.get_sha256(sv.backup_path(0))
	sm._living.world.pilot.selected = sm._living.world.pilot.selected.duplicate(true)
	sm._living.world.pilot.selected.goal_id = "lc_smith_thorin_unknown"
	var corrupt: Dictionary = sm._living.duplicate(true)
	t.allow("SaveManager: SocialManager.to_dict() did not return a Dictionary")
	t.check("internal_decode_failure_refuses_atomic_save", not sv.save_game(0) and sv.last_error.get("code") == "gather" and FileAccess.get_sha256(path) == hash_before and FileAccess.get_sha256(sv.backup_path(0)) == backup_before and sm._living == corrupt)
	sm.from_dict(saved)
	sv.save_dir = old_dir

class ApplyProbe extends Node:
	var calls := 0
	var reject := false
	func to_dict() -> Dictionary: return {"reject": false}
	func from_dict(d: Dictionary) -> bool:
		calls += 1
		return not (reject and d.get("reject", false))
	func reset() -> void: calls += 1

func _social_raw(sm: Node) -> Dictionary:
	var out := {}
	for key in ["_living", "_rows", "_orphans", "_seen", "_fest_year", "_partner", "_event_owed", "world_seed", "_last_day"]:
		var value: Variant = sm.get(key)
		out[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return out

func _save_raw(sv: Node) -> Dictionary:
	return {"pending": sv.pending_world.duplicate(true), "carried": sv._carried_sections.duplicate(true), "run": sv.run_id, "slot": sv.current_slot, "auto": sv._auto_file_seen.duplicate(true), "timer": sv._auto_save_timer}

func _other_sections(sv: Node) -> Dictionary:
	var out := {}
	for entry in sv._ordered_entries():
		var node: Node = sv._node_of(entry)
		if entry.name != "social" and node != null and node.has_method("to_dict"):
			var value: Variant = node.to_dict()
			out[entry.name] = value.duplicate(true) if value is Dictionary else value
	return out

func _failed_snapshot(t, saved: Dictionary) -> void:
	var sm: Node = t.autoload("SocialManager")
	var sv: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	# Drain earlier successful-load work before freezing this failure fixture.
	await t.frames(3)
	t.autoload("GameManager").day = int(saved.living.world.pilot.attempt_day)
	var early := ApplyProbe.new()
	var late := ApplyProbe.new()
	late.reject = true
	t.tree.root.add_child(early)
	t.tree.root.add_child(late)
	t.expect(sv.register_section("snapshot_early", early, -1000) and sv.register_section("snapshot_late", late, 1000), "snapshot probes registered across real sections")
	var old_dir: String = sv.save_dir
	sv.save_dir = "user://living-snapshot-preflight"
	sm.from_dict(saved)
	var incoming: Dictionary = sv.gather_payload()
	incoming.social.erase("living") # Valid legacy incoming social would clear the live receipts.
	incoming.snapshot_late = {"reject": true}
	t.expect(sv.validate_payload(incoming).ok, "incoming social plus late rejection passes real validation")
	DirAccess.make_dir_recursive_absolute(sv.save_dir)
	FileAccess.open(sv.slot_path(0), FileAccess.WRITE).store_string(JSON.stringify(incoming))
	FileAccess.open(sv.backup_path(0), FileAccess.WRITE).store_string(JSON.stringify(incoming))
	var files := {"primary": FileAccess.get_sha256(sv.slot_path(0)), "backup": FileAccess.get_sha256(sv.backup_path(0))}
	var events: Array = []
	var on_load := func(slot): events.append(slot)
	bus.load_completed.connect(on_load)
	for entrypoint in ["apply", "load"]:
		sm.from_dict(saved)
		sm._living.world.pilot.selected = sm._living.world.pilot.selected.duplicate(true)
		sm._living.world.pilot.selected.goal_id = "lc_smith_thorin_unknown"
		sm._living_invalidate()
		var raw := _social_raw(sm)
		var others := _other_sections(sv)
		var manager := _save_raw(sv)
		var generation: int = sm._living_epoch
		early.calls = 0
		late.calls = 0
		t.expect(sm.to_dict() == null and not raw._living.players.is_empty() and raw._living.world.pilot.has("pending_day") and raw._living.world.pilot.has("cooldowns") and not raw._rows.is_empty(), entrypoint + " corrupt snapshot retains nonempty private and legacy state")
		var result: Dictionary = sv._apply_payload(incoming) if entrypoint == "apply" else {"ok": sv.load_game(0), "detail": sv.last_error.get("detail", "")}
		t.check(entrypoint + "_failed_snapshot_preflight_no_apply", not result.ok and str(result.detail).contains("snapshot") and str(result.detail).contains("social") and early.calls == 0 and late.calls == 0, str(result))
		t.check(entrypoint + "_failed_snapshot_exact_all_state", _social_raw(sm) == raw and _other_sections(sv) == others and _save_raw(sv) == manager and sm._living_epoch == generation and events.is_empty())
		await t.frames(3)
		t.check(entrypoint + "_failed_snapshot_deferred_and_files_unchanged", _social_raw(sm) == raw and sm._living_epoch == generation and events.is_empty() and FileAccess.get_sha256(sv.slot_path(0)) == files.primary and FileAccess.get_sha256(sv.backup_path(0)) == files.backup)
	# A healthy snapshot still permits late rejection + rollback, and normal load.
	sm.from_dict(saved)
	var healthy: Dictionary = sm.to_dict()
	t.check("healthy_snapshot_late_rejection_rollback", not sv._apply_payload(incoming).ok and sm.to_dict() == healthy and early.calls > 0 and late.calls > 0)
	late.reject = false
	t.check("healthy_snapshot_normal_load", sv.load_game(0) and not sm.to_dict().has("living") and events == [0])
	bus.load_completed.disconnect(on_load)
	sv.unregister_section("snapshot_early")
	sv.unregister_section("snapshot_late")
	early.queue_free()
	late.queue_free()
	sm.from_dict(saved)
	sv.save_dir = old_dir

func _codec(t, actual: Dictionary) -> void:
	var high: Dictionary = CODEC.empty()
	t.check("original_private_receipt_day_range_preserved", CODEC.record(high, &"p1", NPC, 1000001).ok and CODEC.decode(high, SocialData.npcs()).ok and high.players.p1.npcs[NPC].source_watermarks[CODEC.SOURCE] == 1000001 and not high.world.has("pilot"))
	for day in [1000000, 1000001, CODEC.MAX_DAY]:
		var boundary: Dictionary = CODEC.empty()
		t.check("private_day_boundary_%d" % day, CODEC.record(boundary, &"p1", NPC, day).ok and CODEC.decode(boundary, SocialData.npcs()).ok and boundary.world.has("pilot") == (day <= ACT.MAX_DAY))
	var overflow: Dictionary = CODEC.empty()
	t.check("private_day_overflow_refused_without_mutation", not CODEC.record(overflow, &"p1", NPC, CODEC.MAX_DAY + 1).ok and overflow == CODEC.empty())
	var profile := LivingData.profile(NPC).duplicate(true)
	profile.goals = [null]
	var malformed: Dictionary = CODEC.empty()
	t.check("malformed_live_profile_empty_day_fail_closed", ACT.settle(malformed, Routines.make_ctx(1, 6.0, "klart", {"total_day": 2}), profile, false) and malformed.world.pilot.selected.is_empty())
	for field in ["attempt_day", "pending_day", "consumed_day"]:
		for value in [-1, NAN, "2", true, 1000001]:
			var bad := actual.duplicate(true)
			bad.world.pilot[field] = value
			t.check("closed_world_codec_%s_%s" % [field, str(value)], not CODEC.decode(bad, SocialData.npcs()).ok)
	var deep := actual.duplicate(true)
	deep.world.pilot["cause_player_payload"] = {"p0": "private"}
	t.check("no_arbitrary_shared_payload", not CODEC.decode(deep, SocialData.npcs()).ok)
	var bytes := JSON.stringify(actual).to_utf8_buffer().size()
	t.check("extended_codec_actual_size_bound", bytes < 262144 and CODEC.decode(JSON.parse_string(JSON.stringify(actual)), SocialData.npcs()).ok, "%d bytes" % bytes)
