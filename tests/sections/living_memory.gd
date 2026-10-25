extends RefCounted
const SECTION := "living_memory"
const TIMEOUT_S := 180.0

class ForgedSource extends Node:
	var actor: Node
	var day: int
	var receipt_owner: StringName
	func living_delivery_context(_consumer: Node) -> Dictionary:
		return {"actor": actor, "day": day, "owner": receipt_owner, "source": "dark_forest_mining/return_to_smith"}

class LateReject extends Node:
	func to_dict() -> Dictionary: return {"fail": false}
	func from_dict(d: Dictionary) -> bool: return not d.get("fail", false)
	func reset() -> void: pass

func run(t) -> void:
	# Actual board/mail entrypoints; their button seam is a synthetic UI
	# callback check, not keyboard acceptance. Both quests already eligible.
	for service in ["board", "post"]:
		await load("res://tests/progression/mining_deliveries.gd").service_offer(t, &"dark_forest_mining", &"crystal_cave", service, "accept")
		t.check(service + "_not_physical_help", t.autoload("SocialManager").living_snapshot().players.is_empty())
	for producer in ["initial", "followup", "consumer"]:
		await load("res://tests/progression/mining_deliveries.gd").invalid_owner(t, producer)
		t.check(producer + "_invalid_body_not_help", t.autoload("SocialManager").living_snapshot().players.is_empty())
	await load("res://tests/progression/living_delivery.gd").run(t)
	await _codec(t)

func _retirement_reads(t, codec) -> void:
	var sm: Node = t.autoload("SocialManager")
	var lr: Node = t.autoload("LuaRuntime")
	var day: int = t.autoload("GameManager").total_day()
	var saved: Dictionary = sm.to_dict()
	var receipt: Dictionary = codec.empty()
	codec.record(receipt, &"p1", "smith_thorin", day)
	# Model content retirement in the live Lua table; restore through the real
	# supported reload, not a second social load/save or an authorized write.
	var retired: Dictionary = SocialData.npcs().duplicate(true)
	retired.erase("smith_thorin")
	lr._config.npcs = retired
	t.check("facade_load_while_retired", sm.from_dict({"v": 2, "living": receipt}))
	var raw: Dictionary = sm._living.duplicate(true)
	var hidden: Dictionary = sm.living_snapshot()
	t.check("facade_retired_reads_suspend_private_receipt", hidden.players.is_empty() and hidden.orphans.players.p1.npcs.smith_thorin == receipt.players.p1.npcs.smith_thorin and sm.living_context("smith_thorin", &"p1").is_empty())
	lr.reload_scripts()
	var projected: Dictionary = sm.living_snapshot()
	var context: Dictionary = sm.living_context("smith_thorin", &"p1")
	t.check("facade_reappearance_snapshot_restores_without_write", projected == receipt)
	t.check("facade_reappearance_context_matches_snapshot_without_write", context == projected.players.p1.npcs.smith_thorin, str(context))
	t.check("facade_reappearance_repeated_reads_agree", sm.living_context("smith_thorin", &"p1") == context and sm.living_snapshot() == projected)
	t.check("facade_reappearance_private_owner_no_new_rows", sm.living_context("smith_thorin", &"p0").is_empty() and sm.living_context("smith_thorin", &"p2").is_empty() and sm.living_context("smith_thorin", &"p3").is_empty() and sm.living_context("smith_thorin", &"p4").is_empty() and sm.living_context("baker_maja", &"p1").is_empty())
	t.check("facade_reappearance_watermark_dedup", not codec.record(projected, &"p1", "smith_thorin", day).ok and projected == receipt)
	context.get("memories", []).clear()
	hidden.orphans.players.clear()
	projected.players.clear()
	t.check("facade_retirement_reappearance_reads_copy_only", sm._living == raw and sm.living_snapshot() == receipt and sm.living_context("smith_thorin", &"p1") == receipt.players.p1.npcs.smith_thorin)
	sm.from_dict(saved)

func _codec(t) -> void:
	var codec = load("res://scripts/social/living/living_state.gd")
	if not t.expect(codec.has_method("decode"), "bounded living codec exists"):
		return
	_retirement_reads(t, codec)
	var state: Dictionary = codec.empty()
	for day in range(1, 22):
		codec.record(state, &"p1", "smith_thorin", day)
	var raw := state.duplicate(true)
	var known := SocialData.npcs()
	var decoded: Dictionary = codec.decode(state, known, 21)
	t.check("codec_does_not_mutate_input", state == raw)
	t.check("memory_ring_16", decoded.ok and decoded.state.players.p1.npcs.smith_thorin.memories.size() == 16)
	var expired: Dictionary = codec.decode(JSON.parse_string(JSON.stringify(decoded.state)), known, 100)
	var single: Dictionary = codec.empty()
	codec.record(single, &"p0", "smith_thorin", 1)
	t.check("ttl_exact_28_boundary", codec.decode(single, known, 28).state.players.p0.npcs.smith_thorin.memories.size() == 1 and codec.decode(single, known, 29).state.players.p0.npcs.smith_thorin.memories.is_empty())
	t.check("ttl_28_keeps_watermark", expired.ok and expired.state.players.p1.npcs.smith_thorin.memories.is_empty() and expired.state.players.p1.npcs.smith_thorin.source_watermarks[codec.SOURCE] == 21)
	t.check("replay_after_eviction_refused", not codec.record(expired.state, &"p1", "smith_thorin", 1).ok and not codec.record(expired.state, &"p1", "smith_thorin", 21).ok)
	var retired_known := known.duplicate()
	retired_known.erase("smith_thorin")
	var retired: Dictionary = codec.decode(raw, retired_known, 21)
	t.check("retired_npc_suspended", retired.ok and retired.state.players.is_empty() and retired.state.orphans.players.p1.npcs.has("smith_thorin"))
	var restored: Dictionary = codec.decode(retired.state, known, 21)
	t.check("retired_npc_restores_exactly", restored.ok and restored.state == decoded.state)
	# Both duplicate buckets may be present in a save: neither precedence nor
	# content retirement is allowed to lower permanent dedup authority.
	for high_bucket in ["active", "orphan"]:
		var low: Dictionary = codec.empty()
		codec.record(low, &"p1", "smith_thorin", 1)
		var conflict: Dictionary = codec.empty()
		conflict.players = (raw if high_bucket == "active" else low).players.duplicate(true)
		conflict.orphans.players = (raw if high_bucket == "orphan" else low).players.duplicate(true)
		var conflict_before := conflict.duplicate(true)
		var suspended_conflict: Dictionary = codec.decode(conflict, retired_known, 21)
		var restored_conflict: Dictionary = codec.decode(suspended_conflict.state, known, 21)
		var active_conflict: Dictionary = codec.decode(conflict, known, 21)
		t.check("conflicting_buckets_keep_higher_" + high_bucket, conflict == conflict_before and suspended_conflict.ok and restored_conflict.ok and active_conflict.ok and active_conflict.state == decoded.state and restored_conflict.state == decoded.state and suspended_conflict.state.orphans.players.p1.npcs.smith_thorin.source_watermarks[codec.SOURCE] == 21)
		t.check("conflicting_buckets_dedup_" + high_bucket, not codec.record(restored_conflict.state, &"p1", "smith_thorin", 1).ok and not codec.record(restored_conflict.state, &"p1", "smith_thorin", 21).ok and restored_conflict.state == decoded.state)
	var clone: Dictionary = codec.context(decoded.state, "smith_thorin", &"p1", 21)
	clone.memories.clear()
	t.check("context_copy_no_new_rows", decoded.state == raw and codec.context(decoded.state, "baker_maja", &"p3", 21).is_empty() and not decoded.state.players.has("p3"))
	for invalid in ["", "p4", "p13", "p01", "remote"]:
		t.check("invalid_slot_" + invalid, not codec.record(state, StringName(invalid), "smith_thorin", 22).ok)
	for pid in [&"p0", &"p2", &"p3"]:
		t.check("explicit_slot_" + str(pid), codec.record(state, pid, "smith_thorin", 22).ok)
	var bad_cases: Array = [null, [], {"v": 2}, {"v": 0}, {"v": "1"}, {"v": 1, "players": []}, {"v": 1, "players": {"p99": {}}}, {"v": 1, "world": {"pairs": {"b|a": {}}}}, {"v": 1, "junk": "x".repeat(262145)}]
	for i in bad_cases.size():
		t.check("invalid_codec_case_%d" % i, not codec.decode(bad_cases[i], known, 21).ok)
	var object_case: Dictionary = codec.empty()
	object_case.players.p0 = {"npcs": {"smith_thorin": {"memories": [t.autoload("GameManager")]}}}
	t.check("runtime_objects_never_decoded", not codec.decode(object_case, known, 21).ok)
	var cyclic: Dictionary = codec.empty()
	cyclic.players = cyclic
	var refused_cycle: bool = not codec.decode(cyclic, known, 21).ok
	cyclic.erase("players") # Break the test-only reference cycle after the probe.
	t.check("cyclic_dictionary_refused_before_copy", refused_cycle)
	var cyclic_array: Array = []
	cyclic_array.append(cyclic_array)
	refused_cycle = not codec.decode({"v": 1, "players": cyclic_array}, known, 21).ok
	cyclic_array.clear()
	t.check("cyclic_array_refused_before_copy", refused_cycle)
	var over: Dictionary = codec.empty()
	over.players.p1 = {"npcs": {"smith_thorin": raw.players.p1.npcs.smith_thorin.duplicate(true)}}
	for i in 1000:
		over.players.p1.npcs.smith_thorin.memories.append(raw.players.p1.npcs.smith_thorin.memories[0])
	t.check("oversize_array_refused_before_apply", not codec.decode(over, known, 21).ok)
	for field in {"source": "cookie_delivery/deliver_to_baker", "subject": "baker_maja", "kind": "promise", "visibility": "public", "event_id": "forged", "day": NAN}:
		var malformed := raw.duplicate(true)
		malformed.players.p1.npcs.smith_thorin.memories[0][field] = {"source": "cookie_delivery/deliver_to_baker", "subject": "baker_maja", "kind": "promise", "visibility": "public", "event_id": "forged", "day": NAN}[field]
		t.check("malformed_memory_" + field, not codec.decode(malformed, known, 21).ok)
	var max_state: Dictionary = codec.empty()
	for pid in [&"p0", &"p1", &"p2", &"p3"]:
		for day in range(1, 22): codec.record(max_state, pid, "smith_thorin", day)
	var started := Time.get_ticks_usec()
	for i in 10: codec.decode(max_state, known, 21)
	var micros := float(Time.get_ticks_usec() - started) / 10.0
	var bytes := JSON.stringify(max_state).to_utf8_buffer().size()
	t.check("bounded_current_source_maximum", bytes < 262144 and codec.decode(max_state, known, 21).ok, "4 players x 16 details: %d bytes; pure decode mean %.1f us (reported, no performance gate)" % [bytes, micros])
	var sm: Node = t.autoload("SocialManager")
	var sv: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var saved: Dictionary = sm.to_dict()
	var legacy := saved.duplicate(true)
	legacy.v = 1
	legacy.erase("living")
	t.check("social_v1_empty_living_preserves_legacy", sm.from_dict(legacy) and sm.living_snapshot() == codec.empty() and sm.to_dict().npcs == legacy.npcs)
	legacy.v = 2
	t.check("social_v2_missing_living_empty", sm.from_dict(legacy) and sm.living_snapshot() == codec.empty())
	sm.from_dict(saved)
	var before: Dictionary = sm.living_snapshot()
	var forged := ForgedSource.new()
	t.tree.root.add_child(forged)
	var live_actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	live_actor.area = t.world().area
	t.world().area.objects.add_child(live_actor)
	live_actor.is_talking = true
	live_actor._talk_player = t.player()
	forged.actor = live_actor
	forged.receipt_owner = PlayerRegistry.registered_id(t.player())
	forged.day = gm.total_day()
	PlayerRegistry.for_player(forged.receipt_owner, func():
		var offered: Dictionary = forged.living_delivery_context(sm)
		t.check("forged_source_control_otherwise_valid", offered.actor is Npc2D and offered.actor.is_inside_tree() and not offered.actor.is_queued_for_deletion() and offered.actor.is_talking and str(offered.actor.npc_id) == "smith_thorin" and SocialData.npcs().has("smith_thorin") and offered.owner == &"p0" and PlayerRegistry.registered_id(offered.actor._talk_player) == offered.owner and PlayerRegistry.acting_id() == offered.owner and offered.day == gm.total_day() and offered.day >= 1)
		var refused: Dictionary = sm.living_record_delivery(forged)
		t.check("forged_commit_source_identity_refused", not refused.ok and refused.get("reason") == "untrusted_source" and sm.living_snapshot() == before))
	live_actor.queue_free()
	forged.queue_free()
	var future := saved.duplicate(true)
	future.living.v = 2
	t.check("future_living_fail_before_mutation", not sm.validate_dict(future) and not sm.from_dict(future) and sm.living_snapshot() == before)
	var payload: Dictionary = sv.gather_payload()
	payload.social = future
	t.check("future_nested_save_preflight_refused", not sv.validate_payload(payload).ok)
	payload.social = saved.duplicate(true)
	payload.social.v = 3
	t.check("future_social_save_version_refused", sv.validate_payload(payload).get("code") == "version")
	var peer := ENetMultiplayerPeer.new()
	t.expect(peer.create_server(0) == OK, "network guard fixture starts real peer")
	var previous: MultiplayerPeer = sm.multiplayer.multiplayer_peer
	sm.multiplayer.multiplayer_peer = peer
	t.check("active_network_fails_closed", not sm.living_can_simulate() and not sm.living_record_delivery(t.autoload("QuestManager")).ok and sm.living_snapshot() == before)
	sm.multiplayer.multiplayer_peer = previous
	peer.close()
	sm.reset()
	await t.frames(3)
	t.check("reset_deferred_does_not_resurrect_living", sm.living_snapshot() == codec.empty())
	sm.from_dict(saved)
	t.check("load_restores_receipt_without_grants", sm.living_snapshot() == before and not before.players.is_empty())
	var late := LateReject.new()
	t.tree.root.add_child(late)
	t.expect(sv.register_section("zz_living_reject", late, 900), "register late rollback fixture")
	var processing: bool = gm.is_processing()
	gm.set_process(false) # Freeze only the real-time play counter across frames.
	var baseline: Dictionary = sv.gather_payload()
	var failed_payload := baseline.duplicate(true)
	failed_payload.social.erase("living")
	failed_payload.zz_living_reject = {"fail": true}
	sm._defer()
	t.check("failed_later_section_rolls_back_living", not sv._apply_payload(failed_payload).ok and sm.living_snapshot() == before)
	await t.frames(3)
	var after_rollback: Dictionary = sv.gather_payload()
	t.check("rollback_deferred_no_living_resurrection", sm.living_snapshot() == before)
	for section in ["players", "home", "game"]:
		t.check("rollback_preserves_legacy_" + section, baseline.get(section) == after_rollback.get(section), load("res://tests/progression/living_delivery.gd")._differences(baseline.get(section), after_rollback.get(section)))
	gm.set_process(processing)
	sv.unregister_section("zz_living_reject")
	late.queue_free()
	var raw_before: Dictionary = sm._living.duplicate(true)
	var view: Dictionary = sm.living_snapshot()
	view.players.clear()
	sm.living_context("baker_maja", &"p3")
	sm.to_dict()
	t.check("all_living_reads_pure_copies", sm._living == raw_before and sm.living_snapshot() == before)
	gm.start_new_game("LC", gm.CharacterType.FAIRY, "LC")
	await t.frames(3)
	t.check("actual_new_game_clears_receipts", sm.living_snapshot() == codec.empty())
	gm.clear_config_overrides()

