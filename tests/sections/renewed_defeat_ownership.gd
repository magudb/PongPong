extends RefCounted
const SECTION := "renewed_defeat_ownership"
const TIMEOUT_S := 180.0
const Snapshot = preload("res://tests/sections/persistence_cleanup_rejoin_scope.gd")

func run(t) -> void:
	for route in ["single_natural", "rejoin_natural", "conflicting_natural", "labelled_fee", "bed", "passout"]:
		await _case(t, route)

func _case(t, route: String) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	sm.autosave_enabled = false
	sm.save_dir = "user://renewed_defeat_ownership"
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.hour = 19
	gm.set_flag(&"assist_last_spark", 0)
	var secondary: Node2D
	if route != "single_natural":
		secondary = w._make_player()
		w._register_player(secondary, 1, 2)
		PlayerRegistry.for_player(&"p1", func(): w.add_child(secondary))
		secondary.enter_area(w.area, w.area.get_spawn("default") + Vector2(100, 0))
		secondary.set_physics_process(false)
		# Prime real legacy loaders before the unrelated-row snapshot; no deferred reward is owed.
		PlayerRegistry.for_player(&"p1", func():
			t.autoload("EconomyManager").from_dict({"gold":907,"inventory":[]})
			t.autoload("QuestManager").to_dict())
		w._unregister_player(w.player)
		await t.frames(3)
		w.rejoin_host()
	await t.seconds(1.4) # Real enabled combat ticks expire the normal spawn/reset invulnerability.
	var body: Node2D = w.player
	var p0: PlayerState = PlayerRegistry._states[&"p0"]
	p0.gold = 321
	body.half_hearts = 2
	body.stamina = 31.0
	body.oil = 52.0
	var day: int = gm.total_day()
	var helpers := Snapshot.new()
	var p1: PlayerState = PlayerRegistry._states.get(&"p1")
	var values: Dictionary = helpers._values(p1) if p1 != null else {}
	var graph: Dictionary = helpers._graph(p1) if p1 != null else {}
	var states: Dictionary = PlayerRegistry._states
	var fallback: PlayerState = PlayerRegistry._fallback_state
	var observations := {"defeated":[], "gold":[], "day":[], "time":[], "notice":[]}
	var on_defeat := func(pid): observations.defeated.append(pid)
	var on_gold := func(pid, balance, delta): observations.gold.append([pid,balance,delta])
	var on_day := func(_day, _season): observations.day.append(PlayerRegistry.acting_id())
	var on_time := func(_hour, _minute): observations.time.append(PlayerRegistry.acting_id())
	var on_notice := func(_title, _text, _icon): observations.notice.append(PlayerRegistry.acting_id())
	bus.player_defeated.connect(on_defeat)
	bus.gold_changed.connect(on_gold)
	bus.day_ended.connect(on_day)
	bus.time_of_day_changed.connect(on_time)
	bus.notification_posted.connect(on_notice)
	var prefix := "RDO_"+route+"_"
	t.check(prefix+"eligible_actual_enabled_host_and_expected_group_local", w._host_live() and PlayerRegistry.registered_id(body) == &"p0" and body.is_physics_processing() and body.state == body.S.FREE and body.combat._iframes <= 0 and not w.traveling and not w.sleeping and not w._faint_pending and (PlayerRegistry.local_id() == &"p0" if p1 == null else PlayerRegistry.local_id() == &"p1"))
	if route == "labelled_fee":
		# Independent consumer control: does NOT claim to prove the combat producer.
		w._on_player_defeated(&"p0")
	elif route == "bed": w.sleep()
	elif route == "passout": w._on_game_event(&"midnight_passed", {})
	else:
		var accepted: bool
		if route == "conflicting_natural":
			accepted = PlayerRegistry.for_player(&"p1", func():
				var result: bool = body.take_damage(100)
				t.check(prefix+"synchronous_conflicting_caller_restored", PlayerRegistry._acting_id == &"p1")
				return result)
		else: accepted = body.take_damage(100)
		t.check(prefix+"accepted_fatal_real_combat_fainted_and_original_p0_label", accepted and body.half_hearts == 0 and body.state == body.S.FAINTED and observations.defeated == [&"p0"] and w._faint_pending, str(observations))
	# No manual state, timer, revive or heal repair: actual normal rescue/sleep must finish.
	await t.seconds(4.2)
	var defeat: bool = route not in ["bed", "passout"]
	var fee := floori(321.0 * clampf(float(GameData.cfg("dungeon.defeat.gold_loss_pct", 10)),0,100)/100.0) if defeat else 0
	t.check(prefix+"normal_recovery_full_cost_not_free_heal", body.state == body.S.FREE and body.half_hearts == body.max_half_hearts and body.stamina == body.max_stamina and body.oil == body.max_oil and gm.total_day() == day+1 and p0.gold == 321-fee and not w.traveling and not w.sleeping and not w._faint_pending and w._physical_operation.is_empty() and w._fade.color.a == 0.0, str({"hp":body.half_hearts,"state":body.state,"day":gm.total_day(),"gold":p0.gold,"obs":observations}))
	t.check(prefix+"exact_host_fee_and_scoped_notification_roots", observations.gold == [[&"p0",321-fee,-fee]] if defeat else observations.gold.is_empty(), str(observations))
	t.check(prefix+"calendar_and_notification_consumers_use_p0", not observations.day.is_empty() and not observations.time.is_empty() and observations.day.all(func(pid): return pid == &"p0") and observations.time.all(func(pid): return pid == &"p0") and (not observations.notice.is_empty() if defeat or route == "passout" else true) and observations.notice.all(func(pid): return pid == &"p0"), str(observations))
	if p1 != null:
		t.check(prefix+"complete_p1_values_aliases_and_registry_identity_preserved", PlayerRegistry._states[&"p1"] == p1 and is_same(PlayerRegistry._states, states) and PlayerRegistry._fallback_state == fallback and helpers._values(p1) == values and helpers._same_graph(p1, graph))
	bus.player_defeated.disconnect(on_defeat)
	bus.gold_changed.disconnect(on_gold)
	bus.day_ended.disconnect(on_day)
	bus.time_of_day_changed.disconnect(on_time)
	bus.notification_posted.disconnect(on_notice)
	t.check(prefix+"caller_scope_not_held_across_await", PlayerRegistry._acting_id == &"")
	# A nonhost label must not start rescue or charge either wallet.
	var gold_after: int = p0.gold
	var day_after: int = gm.total_day()
	w._on_player_defeated(&"p1")
	await t.frames(2)
	t.check(prefix+"nonhost_defeat_refused", not w._faint_pending and p0.gold == gold_after and gm.total_day() == day_after)
	var at: Vector2 = body.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check(prefix+"later_enabled_movement_and_actual_save", body.is_physics_processing() and body.global_position.distance_to(at) > 1.0 and sm.save_game(4))
	gm.clear_config_overrides()
	# Retire the test-owned group-local p1 body after its validation window. Left in the old World it stays
	# PlayerRegistry.local_id(), and the next new game's synchronous reset (character_changed -> refresh_stats ->
	# WardrobeManager.state()) lazily recreates a p1 row in the fresh registry of whatever section starts next.
	if secondary != null and is_instance_valid(secondary):
		var retired: WeakRef = weakref(secondary)
		w._unregister_player(secondary)
		secondary.queue_free()
		await t.until_game(func(): return retired.get_ref() == null, 1.0)
