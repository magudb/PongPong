extends RefCounted
const SECTION := "boss_helper_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")
const H2 := preload("res://tests/sections/boss_inner_origins.gd")
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func run(t) -> void:
	var selected := OS.get_environment("H2B_CASE")
	if selected in ["", "reveal"]: await _reveal(t, "direct")
	if selected in ["", "tween"]: await _running_tween(t)
	if selected in ["", "pool"]: await _pool_warm(t)
	if selected in ["", "leases"]: await _pool_leases(t)
	if selected in ["", "review"]:
		await _physics_revival(t)
		await _dead_health(t)

func _enemy(t, boss: DungeonBoss2D) -> Enemy2D:
	var enemy := Enemy2D.create_marker({"kind":"ugleoje", "ambush":1, "persist":0}, boss.home + Vector2(300,0), boss.cell, boss.area) as Enemy2D
	boss.area.objects.add_child(enemy)
	enemy.set_physics_process(false)
	t.check("authored_ambush_hidden_host", enemy.ambush and enemy.ambush_state == "hidden" and not enemy.visual.visible and is_instance_valid(enemy._host))
	return enemy

func _state(enemy: Enemy2D) -> Dictionary:
	return {"hp":enemy.hp, "state":enemy.state, "remaining":enemy.remaining, "cooldown":enemy.cooldown, "stun":enemy.stun_generation, "eyes":enemy._eyes.visible, "host_queued":not is_instance_valid(enemy._host) or enemy._host.is_queued_for_deletion(), "props":enemy.area.prop_nodes.map(func(r): return [r.id, r.nodes.map(func(n): return n.get_instance_id())]), "objects":enemy.area.objects.get_children().map(func(n): return n.get_instance_id()), "fx":enemy.area.ground_fx.get_children().map(func(n): return n.get_instance_id())}

func _reveal(t, mode: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var enemy := _enemy(t, boss)
	var saves: Node = t.autoload("SaveManager")
	var files := H1.new()._files(saves)
	var origin := EventBus.combat_receipt(EventBus.combat_origin(t.player()), enemy)
	var seen: Array = []
	var observer := func():
		if not enemy.visual.visible or not seen.is_empty(): return
		seen.append(true)
		var payload: Dictionary = saves.gather_payload()
		seen.append(saves.validate_payload(payload).ok and saves._apply_payload(payload).ok)
		seen.append(saves.gather_payload())
		seen.append(_state(enemy))
		seen.append(t.player()._last_stats.duplicate(true))
		H2.new()._journal("reveal_" + mode, "callback", {"payload":seen[2], "attachments":seen[3], "body_cache":seen[4], "files":H1.new()._files(saves)})
	enemy.visual.visibility_changed.connect(observer)
	t.check("reveal_real_clock_window", await t.until(func(): return fmod(Time.get_unix_time_from_system(), 1.0) < .2, 2.0))
	enemy.take_hit(1, t.player().global_position, t.player())
	enemy.visual.visibility_changed.disconnect(observer)
	t.check("reveal_actual_visibility_apply_revokes_original", seen.size() == 5 and seen[1] and not EventBus.combat_current(origin))
	t.check("reveal_inner_host_eyes_timers_exact_unwind", _state(enemy) == seen[3])
	var after: Dictionary = saves.gather_payload()
	H2.new()._journal("reveal_" + mode, "unwind", {"payload":after, "attachments":_state(enemy), "body_cache":t.player()._last_stats, "files":H1.new()._files(saves)})
	t.check("reveal_full_winner_exact_unwind", Compare.new()._same_payload(seen[2], after), str(Compare.new()._changed(seen[2], after)))
	await t.frames(3)
	var queued: Dictionary = saves.gather_payload()
	H2.new()._journal("reveal_" + mode, "three_frames", {"payload":queued, "attachments":_state(enemy), "body_cache":t.player()._last_stats, "files":H1.new()._files(saves)})
	t.check("reveal_full_winner_exact_three_frames", Compare.new()._same_payload(seen[2], queued), str(Compare.new()._changed(seen[2], queued)))
	t.check("reveal_files_and_cache_exact", H1.new()._files(saves) == files and t.player()._last_stats == seen[4])
	await t.go_menu()

func _running_tween(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var notices: Array = []
	var finish: Array = []
	var deaths: Array = []
	var on_enemy := func(_id, _kind, _drops): notices.append(true)
	var on_finish := func(v): finish.append(v)
	var on_death := func(_enemy): deaths.append(true)
	EventBus.enemy_defeated.connect(on_enemy)
	EventBus.combat_finished.connect(on_finish)
	boss.died.connect(on_death)
	boss.take_hit(9999, t.player().global_position, t.player())
	await t.seconds(.12)
	t.check("running_tween_actually_advanced_before_replacement", boss.visual.modulate.a < .99 and boss.visual.scale.x < .999 and boss.state == Enemy2D.S.DEAD)
	t.check("running_tween_earned_terminal_once", notices == [true] and finish == [true] and deaths == [true] and DungeonRun.hearts_bonus() == 2 and t.world().get_node("RunWatch").kills == 1)
	boss.reset_fight()
	boss.set_physics_process(false)
	boss.start_pattern("cloud")
	boss.visual.scale = Vector2(1.17, 1.23)
	boss.visual.modulate = Color(.7,.8,.9,.87)
	var visual_scale := boss.visual.scale
	var tint := boss.visual.modulate
	var hp := boss.hp
	var state := boss.state
	var sequences: Array = boss.get_children().filter(func(n): return n.get_script() == DungeonBoss2D.Sequence).map(func(n): return weakref(n))
	await t.frames(3)
	t.check("running_tween_new_art_exact_three_frames", boss.visual.scale == visual_scale and boss.visual.modulate == tint)
	await t.seconds(.6)
	t.check("running_tween_cannot_free_or_repaint_new_request", is_instance_valid(boss) and not boss.is_queued_for_deletion() and boss.visual.scale == visual_scale and boss.visual.modulate == tint and boss.hp == hp and boss.state == state)
	t.check("running_tween_exact_new_sequence_survives", sequences.size() == 1 and is_instance_valid(sequences[0].get_ref()) and not sequences[0].get_ref().is_queued_for_deletion())
	EventBus.enemy_defeated.disconnect(on_enemy)
	EventBus.combat_finished.disconnect(on_finish)
	boss.died.disconnect(on_death)
	await t.go_menu()

func _pool_warm(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var saves: Node = t.autoload("SaveManager")
	var seen: Array = []
	var observer := func(node):
		if node.name != &"SparkPool" or not seen.is_empty(): return
		seen.append(true)
		var payload: Dictionary = saves.gather_payload()
		seen.append(saves._apply_payload(payload).ok)
		seen.append(node.get_child_count())
		seen.append(saves.gather_payload())
	var objects := boss.area.objects
	t.check("pool_actual_hit_cold_parent", objects.get_node_or_null("SparkPool") == null)
	objects.child_entered_tree.connect(observer)
	t.check("pool_real_clock_window", await t.until(func(): return fmod(Time.get_unix_time_from_system(), 1.0) < .2, 2.0))
	boss.take_hit(1, t.player().global_position, t.player())
	objects.child_entered_tree.disconnect(observer)
	var pool := objects.get_node_or_null("SparkPool")
	t.check("pool_real_add_child_replacement", seen.size() == 4 and seen[1])
	t.check("pool_stale_warm_and_play_suffix_stopped", pool != null and pool.get_child_count() == seen[2])
	var after: Dictionary = saves.gather_payload()
	t.check("pool_winner_exact_unwind", Compare.new()._same_payload(seen[3], after), str(Compare.new()._changed(seen[3], after)))
	var spark := HitSpark2D.play(objects, boss.global_position, "normal") as DungeonSpark2D
	t.check("pool_next_current_root_repairs_partial_warm", pool.get_child_count() == DungeonSpark2D.CAP and spark != null and spark.active and spark.visible and spark.is_processing())
	await t.go_menu()

func _pool_leases(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var spark := HitSpark2D.play(boss.area.objects, boss.global_position, "normal") as DungeonSpark2D
	var newer: Array = []
	var observer := func():
		if spark.visible or not newer.is_empty(): return
		newer.append(true)
		newer.append(HitSpark2D.play(boss.area.objects, boss.global_position + Vector2(20,0), "rare"))
		newer.append(spark.serial)
	spark.visibility_changed.connect(observer)
	spark.finish()
	spark.visibility_changed.disconnect(observer)
	t.check("spark_finish_reenters_same_slot_new_lease", newer.size() == 3 and newer[1] == spark and spark.serial == newer[2] and spark.active and spark.visible)
	t.check("spark_old_finish_cannot_disable_new_lease", spark.is_processing())
	# Boss armor intentionally resists stagger during windup. Use the authored
	# unarmored enemy for the actual hit -> stun -> warning cancellation path.
	var target := _enemy(t, boss)
	target.begin_windup({"radius":80}, .8, "puff")
	var ring: TelegraphRing2D = target.warning
	var seen: Array = []
	var replace := func():
		if ring.visible or not seen.is_empty(): return
		seen.append(true)
		target.begin_windup({"radius":123}, 1.1, "quake")
		seen.append(target.warning_serial)
		seen.append(target.remaining)
	ring.visibility_changed.connect(replace)
	target.take_hit(1, t.player().global_position, t.player())
	ring.visibility_changed.disconnect(replace)
	t.check("warning_cancel_reenters_new_same_node_action", seen.size() == 3 and target.warning == ring and target.warning_serial == seen[1] and target.state == Enemy2D.S.WINDUP and target.remaining == seen[2] and ring.radius == 123 and ring.active and ring.visible)
	t.check("warning_old_finish_cannot_disable_new_lease", ring.is_processing())
	await t.go_menu()

func _physics_revival(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	t.player().global_position = boss.home + Vector2(0,100)
	boss.set_physics_process(true)
	await t.until(func(): return boss.awake, 2.0)
	t.check("R1_enabled_physics_healthy_live_preconditions", boss.is_physics_processing() and boss.is_awake() and boss.awake and boss.state != Enemy2D.S.DEAD and not GameManager.is_modal_open() and boss.player == t.player() and Iso.ground_dist(t.player().global_position,boss.home) < 520, str({"physics":boss.is_physics_processing(), "process_mode":boss.process_mode,"awake":boss.awake,"state":boss.state,"modal":GameManager.is_modal_open(),"player":boss.player == t.player(),"distance":Iso.ground_dist(t.player().global_position,boss.home)}))
	t.check("R1_actual_combat_point_query_before", t.player().combat.enemy_at(boss.global_position + Vector2(0,-10)) == boss and boss._hurtbox.monitorable)
	var seen: Array = []
	var observer := func(_name, _ratio, _shown):
		if boss.state != Enemy2D.S.DEAD or not seen.is_empty(): return
		seen.append(true)
		boss.reset_fight()
		boss.start_pattern("cloud")
		boss.take_hit(1,t.player().global_position,t.player())
		seen.append(boss.remaining)
		seen.append(boss.state)
	EventBus.boss_bar_changed.connect(observer)
	boss.take_hit(9999,t.player().global_position,t.player())
	EventBus.boss_bar_changed.disconnect(observer)
	t.check("R1_new_fight_physics_enabled_after_unwind", seen.size() == 3 and boss.is_physics_processing() and boss.state == seen[2] and boss.hp == boss.max_hp - 1)
	await t.frames(3)
	t.check("R1_deferred_old_hurtbox_cannot_disable_revival", boss._hurtbox.monitorable)
	t.check("R1_actual_combat_point_query_after", t.player().combat.enemy_at(boss.global_position + Vector2(0,-10)) == boss)
	await t.seconds(.12)
	t.check("R1_ordinary_physics_advances_new_timer", boss.is_physics_processing() and boss.remaining < seen[1] - .04 and boss.state != Enemy2D.S.DEAD)
	await t.go_menu()

func _dead_health(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	boss.take_hit(boss.hp - 1,t.player().global_position,t.player())
	boss.start_pattern("cloud")
	var old_sequences: Array = boss.get_children().filter(func(n): return n.get_script() == DungeonBoss2D.Sequence).map(func(n): return weakref(n))
	var old_adds: Array = boss.summoned.duplicate()
	t.check("R2_actual_live_phase2_resources", boss.phase == 2 and boss.hp == 1 and old_sequences.size() == 1 and old_adds.size() == boss.adds)
	var ref: WeakRef = weakref(boss)
	var seen: Array = []
	var notices: Array = []
	var deaths: Array = []
	var finishes: Array = []
	var observer := func(_name, _ratio, _shown):
		if boss.state != Enemy2D.S.DEAD or not seen.is_empty(): return
		seen.append(true)
		boss._on_health_changed()
		seen.append(boss.state)
	var enemy := func(_id, _kind, _loot): notices.append(true)
	var death := func(_enemy): deaths.append(true)
	var finish := func(v): finishes.append(v)
	EventBus.boss_bar_changed.connect(observer)
	EventBus.enemy_defeated.connect(enemy)
	boss.died.connect(death)
	EventBus.combat_finished.connect(finish)
	boss.take_hit(9999,t.player().global_position,t.player())
	EventBus.boss_bar_changed.disconnect(observer)
	EventBus.enemy_defeated.disconnect(enemy)
	EventBus.combat_finished.disconnect(finish)
	boss.died.disconnect(death)
	t.check("R2_terminal_health_notification_not_revival", seen == [true,Enemy2D.S.DEAD] and not boss.is_physics_processing())
	t.check("R2_terminal_notices_once", notices == [true] and deaths == [true] and finishes == [true])
	await t.seconds(.7)
	t.check("R2_eventual_exact_corpse_retired", not is_instance_valid(ref.get_ref()))
	t.check("R2_exact_old_sequence_and_adds_retired", (old_sequences + old_adds).all(func(r): return not is_instance_valid(r.get_ref())))
	await t.go_menu()
