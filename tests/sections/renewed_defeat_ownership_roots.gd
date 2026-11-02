extends RefCounted
const SECTION := "renewed_defeat_ownership_roots"
const TIMEOUT_S := 180.0
const Snapshot = preload("res://tests/sections/persistence_cleanup_rejoin_scope.gd")

func run(t) -> void:
	for night in [false, true]: await _active_run(t, night)

func _active_run(t, night: bool) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	var old_dir: String = sm.save_dir
	t.on_cleanup(func(): sm.save_dir = old_dir)
	sm.autosave_enabled = false
	sm.save_dir = "user://renewed_defeat_roots"
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.hour = 19
	gm.set_flag(&"assist_last_spark", 0)
	var p1_body: Node2D = w._make_player()
	w._register_player(p1_body, 1, 2)
	PlayerRegistry.for_player(&"p1", func():
		w.add_child(p1_body)
		t.autoload("EconomyManager").from_dict({"gold":907,"inventory":[]})
		t.autoload("QuestManager").to_dict())
	p1_body.enter_area(w.area, w.area.get_spawn("default") + Vector2(100, 0))
	p1_body.set_physics_process(false)
	w._unregister_player(w.player)
	await t.frames(3)
	var body: Node2D = w.rejoin_host()
	await t.seconds(1.4)
	var floors := DungeonFloors.inst()
	var started: bool = PlayerRegistry.for_player(&"p0", func(): return floors.start_run(1))
	var p0: PlayerState = PlayerRegistry._states[&"p0"]
	var p1: PlayerState = PlayerRegistry._states[&"p1"]
	p0.gold = 321
	body.half_hearts = 2
	body.stamina = 31
	body.oil = 52
	var snap := Snapshot.new()
	var values: Dictionary = snap._values(p1)
	var graph: Dictionary = snap._graph(p1)
	var day: int = gm.total_day()
	var count: int = gm.flag_int(&"dungeon_defeats", 0)
	var losses: int = gm.flag_int(&"dungeon_gold_lost", 0)
	var obs := {"run":[],"defeat":[],"gold":[],"day":[],"notice":[],"area":[]}
	var on_run := func(id, data):
		if id == &"dungeon_run_ended": obs.run.append([PlayerRegistry.acting_id(),data.reason])
	var on_defeat := func(pid): obs.defeat.append(pid)
	var on_gold := func(pid, total, delta): obs.gold.append([pid,total,delta])
	var on_day := func(_d,_s): obs.day.append(PlayerRegistry.acting_id())
	var on_notice := func(_title,_text,_icon): obs.notice.append(PlayerRegistry.acting_id())
	var on_area := func(_id): obs.area.append(PlayerRegistry.acting_id())
	bus.game_event.connect(on_run)
	bus.player_defeated.connect(on_defeat)
	bus.gold_changed.connect(on_gold)
	bus.day_ended.connect(on_day)
	bus.notification_posted.connect(on_notice)
	bus.area_changed.connect(on_area)
	var prefix := "RDR_"+("night" if night else "charged")+"_"
	t.check(prefix+"real_run_and_original_host_eligible", started and floors.active and floors.floor == 1 and w._host_live() and body.is_physics_processing() and body.combat._iframes <= 0 and body.state == body.S.FREE and PlayerRegistry.local_id() == &"p1")
	if night: w.sleep()
	var accepted: bool = body.take_damage(100)
	t.check(prefix+"natural_fatal_accepted_with_original_label", accepted and body.state == body.S.FAINTED and body.half_hearts == 0 and obs.defeat == [&"p0"] and w._faint_pending, str(obs))
	await t.seconds(4.2)
	var fee: int = 0 if night else floori(321.0 * clampf(float(GameData.cfg("dungeon.defeat.gold_loss_pct", 10)),0,100)/100.0)
	t.check(prefix+"real_end_run_and_all_reached_root_scopes", not floors.active and obs.run == [[&"p0","defeated"]] and obs.day == [&"p0"] and obs.notice.all(func(pid): return pid == &"p0") and (obs.area.is_empty() if night else obs.area == [&"p0"]), str(obs))
	t.check(prefix+"one_wake_precise_cost_and_earned_defeat_accounting", gm.total_day() == day+1 and p0.gold == 321-fee and (obs.gold.is_empty() if night else obs.gold == [[&"p0",321-fee,-fee]]) and gm.flag_int(&"dungeon_defeats",0) == count+(0 if night else 1) and gm.flag_int(&"dungeon_gold_lost",0) == losses+fee, str(obs))
	t.check(prefix+"normal_fatal_recovery_no_manual_timer_or_state_repair", body.state == body.S.FREE and body.half_hearts == body.max_half_hearts and body.stamina == body.max_stamina and body.oil == body.max_oil and not w._faint_pending and not w.traveling and not w.sleeping and w._fade.color.a == 0)
	t.check(prefix+"full_secondary_values_and_aliases_survive_complete_chain", snap._values(p1) == values and snap._same_graph(p1, graph))
	bus.game_event.disconnect(on_run)
	bus.player_defeated.disconnect(on_defeat)
	bus.gold_changed.disconnect(on_gold)
	bus.day_ended.disconnect(on_day)
	bus.notification_posted.disconnect(on_notice)
	bus.area_changed.disconnect(on_area)
	await w.travel(&"home", &"default")
	var at: Vector2 = body.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check(prefix+"successor_free_enabled_travel_movement_and_save", body.is_physics_processing() and body.global_position.distance_to(at) > 1 and sm.save_game(4) and PlayerRegistry._acting_id == &"")
	gm.clear_config_overrides()
