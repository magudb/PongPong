extends RefCounted
const SECTION := "operation_origin"
const TIMEOUT_S := 120.0

func run(t) -> void:
	var path := "res://scripts/player/operation_origin.gd"
	t.check("helper_present", ResourceLoader.exists(path), "pure operation origin comparator must exist")
	if not ResourceLoader.exists(path): return
	var helper: GDScript = load(path)
	var profile := RefCounted.new()
	var stamp: Array = ["run", 1, 2, 3, 4]
	var snapshot: Dictionary = helper.snapshot(&"p0", profile, stamp, &"offline", true, true)
	var origin: Dictionary = helper.capture(snapshot)
	t.check("current_values", not origin.is_empty() and helper.is_current(origin, snapshot))
	stamp[4] = 99
	t.check("stamp_value_snapshot", origin.stamp == ["run", 1, 2, 3, 4] and origin.is_read_only() and origin.stamp.is_read_only())
	var replacement := RefCounted.new()
	t.check("exact_source_identity", not helper.is_current(origin, helper.snapshot(&"p0", replacement, ["run", 1, 2, 3, 4], &"offline", true, true)))
	t.check("stamp_change", not helper.is_current(origin, helper.snapshot(&"p0", profile, stamp, &"offline", true, true)))
	t.check("role_change", not helper.is_current(origin, helper.snapshot(&"p0", profile, ["run", 1, 2, 3, 4], &"host", true, true)))
	t.check("guest_refusal", helper.capture(helper.snapshot(&"p0", profile, ["run", 1, 2, 3, 4], &"guest", false, true)).is_empty())
	t.check("barrier_denies", not helper.is_current(origin, helper.snapshot(&"p0", profile, ["run", 1, 2, 3, 4], &"offline", true, false)))
	t.check("barrier_does_not_latch", helper.is_current(origin, snapshot))
	t.check("barrier_cannot_capture", helper.capture(helper.snapshot(&"p0", profile, ["run", 1, 2, 3, 4], &"offline", true, false)).is_empty())
	for i in 5:
		var changed: Array = ["run", 1, 2, 3, 4]
		changed[i] = "other" if i == 0 else 10
		t.check("stamp_component_" + str(i), not helper.is_current(origin, helper.snapshot(&"p0", profile, changed, &"offline", true, true)))
	for key: String in ["player_id", "profile", "stamp", "role", "writable", "available"]:
		for invalid: Variant in [null, false, 1, 1.5, "bad", [], {}, Callable()]:
			var malformed := snapshot.duplicate()
			malformed[key] = invalid
			t.check("malformed_" + key + "_" + str(typeof(invalid)), helper.capture(malformed).is_empty() and not helper.is_current(origin, malformed))
	t.check("missing_profile", helper.capture(helper.snapshot(&"p0", null, ["run", 1, 2, 3, 4], &"offline", true, true)).is_empty())
	t.check("player_change", not helper.is_current(origin, helper.snapshot(&"p1", profile, ["run", 1, 2, 3, 4], &"offline", true, true)))
	for bad: Array in [[], ["run", 1], ["run", 1, 2, 3, []], ["run", 1, 2, 3, false], ["run", 1, 2, 3, 4.0]]:
		t.check("bad_stamp_" + str(bad), helper.snapshot(&"p0", profile, bad, &"offline", true, true).is_empty(), "snapshot must not retain mutable/object stamp values")
	var weak_origin: Dictionary
	var source_ref: WeakRef
	var ephemeral := RefCounted.new()
	source_ref = weakref(ephemeral)
	weak_origin = helper.capture(helper.snapshot(&"p0", ephemeral, ["run", 0, 0, 0, 0], &"offline", true, true))
	ephemeral = null
	t.check("expired_source", source_ref.get_ref() == null and not helper.is_current(weak_origin, weak_origin), "origin must not keep source alive or accept null==null")
	t.check("physical_api", helper.has_method("physical_snapshot") and helper.has_method("capture_physical") and helper.has_method("is_physical_current"))
	if not helper.has_method("physical_snapshot"): return
	_physical(t, helper, origin, snapshot)
	await _services(t, helper)

func _physical(t, helper: GDScript, origin: Dictionary, snapshot: Dictionary) -> void:
	var world := Node.new()
	var actor := Node.new()
	var body := Node.new()
	var session := Node.new()
	t.tree.root.add_child(world)
	world.add_child(actor)
	world.add_child(body)
	world.add_child(session)
	var observed: Dictionary = helper.physical_snapshot(&"p0", body, actor, world, session, &"p0", body)
	var physical: Dictionary = helper.capture_physical(observed)
	t.check("physical_current", not physical.is_empty() and helper.is_physical_current(physical, observed))
	var other := Node.new()
	world.add_child(other)
	t.check("actor_replacement", not helper.is_physical_current(physical, helper.physical_snapshot(&"p0", body, other, world, session, &"p0", body)))
	t.check("world_replacement", not helper.is_physical_current(physical, helper.physical_snapshot(&"p0", body, actor, other, session, &"p0", body)))
	t.check("session_replacement", not helper.is_physical_current(physical, helper.physical_snapshot(&"p0", body, actor, world, other, &"p0", body)))
	var without_session: Dictionary = helper.physical_snapshot(&"p0", body, actor, world, null, &"p0", body)
	t.check("optional_session", helper.is_physical_current(helper.capture_physical(without_session), without_session) and not helper.is_physical_current(physical, without_session))
	t.check("empty_predicates_refuse", helper.capture({}).is_empty() and helper.capture_physical({}).is_empty() and not helper.is_physical_current({}, {}) and not helper.is_attachment_current({}, other, 0))
	for invalid: Variant in [null, false, 1, "body", [], {}]:
		t.check("invalid_body_" + str(typeof(invalid)), helper.physical_snapshot(&"p0", invalid, actor, world, session, &"p0", invalid).is_empty())
	t.check("membership_roundtrip", helper.physical_snapshot(&"p0", body, actor, world, session, &"p0", actor).is_empty())
	t.check("membership_id", helper.physical_snapshot(&"p0", body, actor, world, session, &"p1", body).is_empty())
	world.remove_child(body)
	t.check("body_departure_physical_denied", not helper.is_physical_current(physical, observed))
	t.check("body_departure_earned_effects", helper.is_current(origin, snapshot))
	body.free()
	t.check("body_free_physical_denied", not helper.is_physical_current(physical, observed))
	world.free()
	t.check("physical_weak_lifetimes", physical.body.get_ref() == null and physical.actor.get_ref() == null and physical.world.get_ref() == null and physical.session.get_ref() == null)
	t.check("attachment_api", helper.has_method("attachment") and helper.has_method("is_attachment_current"))
	if not helper.has_method("attachment"): return
	var request := RefCounted.new()
	var receipt: Dictionary = helper.attachment(request, 1)
	t.check("attachment_current", helper.is_attachment_current(receipt, request, 1))
	t.check("attachment_replaced", not helper.is_attachment_current(receipt, request, 2) and not helper.is_attachment_current(receipt, RefCounted.new(), 1))
	request = null
	t.check("attachment_weak_lifetime", not helper.is_attachment_current(receipt, null, 1))

func _observation(helper: GDScript, saves: Node, player_id: StringName = &"p0") -> Dictionary:
	var profile := PlayerRegistry.peek_state(player_id)
	var session := NetAuthority.session()
	var role: StringName = session.role if session != null else &"offline"
	return helper.snapshot(player_id, profile, saves._save_owner_stamp(), role, NetAuthority.can_write(), profile != null and saves.continuation_available(profile))

func _warm() -> void:
	Routines._fb = {"probe": 1}
	Routines._plans = {"probe": 2}
	Routines._plans_day = 99

func _warm_intact() -> bool:
	return Routines._fb == {"probe": 1} and Routines._plans == {"probe": 2} and Routines._plans_day == 99

func _services(t, helper: GDScript) -> void:
	if not await t.start_world(): return
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	var origin: Dictionary = helper.capture(_observation(helper, saves))
	t.check("real_current", helper.is_current(origin, _observation(helper, saves)))
	var rows := PlayerRegistry._states.duplicate()
	var stamp: Array = saves._save_owner_stamp()
	for i in 3:
		t.check("missing_row_noncreating_" + str(i), helper.capture(_observation(helper, saves, &"missing")).is_empty() and PlayerRegistry._states == rows and saves._save_owner_stamp() == stamp)
	var reset: Dictionary = bus.reset_origin()
	_warm()
	Routines._end_session(reset)
	t.check("real_reset_current", Routines._fb.is_empty() and Routines._plans.is_empty() and Routines._plans_day == -1)
	_warm()
	var stale := reset.duplicate()
	stale.stamp = reset.stamp.duplicate()
	stale.stamp[4] += 1
	Routines._end_session(stale)
	t.check("real_reset_stale_stamp", _warm_intact())
	var old := PlayerRegistry.peek_state(&"p0")
	PlayerRegistry._states[&"p0"] = PlayerState.new()
	Routines._end_session(reset)
	t.check("profile_only_replacement", _warm_intact() and not helper.is_current(origin, _observation(helper, saves)))
	PlayerRegistry._states.erase(&"p0")
	Routines._end_session(reset)
	t.check("real_reset_missing_profile", _warm_intact() and not helper.is_current(origin, _observation(helper, saves)) and not PlayerRegistry._states.has(&"p0"))
	var null_origin: Dictionary = bus.reset_origin()
	Routines._end_session(null_origin)
	t.check("existing_null_profile_policy", bus.reset_current(null_origin) and Routines._fb.is_empty() and not PlayerRegistry._states.has(&"p0"), "loader delegates existing null/null facade policy; pure effect origins still require a profile")
	PlayerRegistry._states[&"p0"] = old
	t.check("same_original_resumes", helper.is_current(origin, _observation(helper, saves)))
	var edge: GDScript = load("res://tests/sections/multiplayer_rollback_edges.gd")
	var section: Node = edge.Section.new()
	t.tree.root.add_child(section)
	saves.register_section("operation_origin_probe", section, 1000)
	var payload: Dictionary = saves.gather_payload()
	section.rejects = 1
	var during: Array = []
	section.apply_callback = func():
		if section.calls == 2:
			during.append(helper.is_current(origin, _observation(helper, saves)))
	var result: Dictionary = saves._apply_payload(payload)
	section.apply_callback = Callable()
	t.check("authentic_failed_rollback", not result.ok and not str(result.detail).contains("incomplete") and section.calls == 2 and PlayerRegistry.peek_state(&"p0") == old, "real late section refusal, complete certified original graph restored")
	t.check("rollback_barrier_until_unwind", during == [false] and helper.is_current(origin, _observation(helper, saves)) and saves._origin_barriers.is_empty())
	var prior_dir: String = saves.save_dir
	saves.save_dir = "user://operation-origin-facade"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	t.check("real_disk_rollback_eligible", saves.save_game(0) and saves.has_save(0) and not FileAccess.file_exists(saves.backup_path(0)), "first manual save has no healthy fallback backup")
	section.rejects = 1
	var final_observer: Array = []
	var notified := func(_title: String, _message: String, icon: String):
		if icon != "save" or saves.last_error.get("code") != "apply": return
		final_observer.append([PlayerRegistry.peek_state(&"p0") == old, saves._save_owner_stamp() == origin.stamp, saves.continuation_available(old), helper.is_current(origin, _observation(helper, saves))])
	bus.notification_posted.connect(notified)
	var loaded: bool = saves.load_game(0)
	bus.notification_posted.disconnect(notified)
	t.check("restored_identity_still_barred_in_final_observer", not loaded and final_observer == [[true, true, false, false]], "loaded=%s final=%s error=%s calls=%s" % [loaded, final_observer, saves.last_error, section.calls])
	t.check("same_origin_after_complete_load_unwind", helper.is_current(origin, _observation(helper, saves)) and saves._origin_barriers.is_empty() and not saves.network_admission_blocked())
	saves.save_dir = prior_dir
	var original_values: Dictionary = old.to_dict().duplicate(true)
	result = saves._apply_payload(payload)
	t.check("same_valued_success_revokes", result.ok and PlayerRegistry.peek_state(&"p0").to_dict() == original_values and not helper.is_current(origin, _observation(helper, saves)), "result=%s values_equal=%s current=%s" % [result, PlayerRegistry.peek_state(&"p0").to_dict() == original_values, helper.is_current(origin, _observation(helper, saves))])
	var next_origin: Dictionary = helper.capture(_observation(helper, saves))
	var gold: int = EconomyManager.gold
	if helper.is_current(next_origin, _observation(helper, saves)): EconomyManager.add_gold(1)
	t.check("next_current_progress", EconomyManager.gold == gold + 1 and helper.is_current(next_origin, _observation(helper, saves)))
	saves.unregister_section("operation_origin_probe")
	section.free()
	# Real hook/load invalidation, without rewriting the producer or raw signals.
	Routines.now_ctx()
	_warm()
	bus.load_completed.emit(0)
	t.check("existing_load_cache_invalidation", Routines._fb.is_empty() and Routines._plans.is_empty())
	await t.go_menu()
	var guest := Node.new()
	t.check("detached_guest_bound", NetAuthority.bind_guest(guest))
	reset = bus.reset_origin()
	_warm()
	Routines._end_session(reset)
	t.check("detached_guest_refusal", not NetAuthority.can_write() and _warm_intact() and helper.capture(_observation(helper, saves)).is_empty())
	Routines.clear_cache()
	t.check("guest_explicit_clear_local", Routines._fb.is_empty() and Routines._plans.is_empty())
	guest.free()
	t.check("future_authority_after_guest_destruction", NetAuthority.can_write() and not helper.capture(_observation(helper, saves)).is_empty())
