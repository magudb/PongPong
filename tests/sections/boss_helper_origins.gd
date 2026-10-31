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
	if selected in ["", "controls"]:
		for mode in ["normal", "failed"]: await _reveal_control(t, mode)
		await _ordinary_death(t, false)
		await _ordinary_death(t, true)
	if selected in ["", "cancel_profile"]: await _death_cancel_profile(t)
	if selected in ["", "empty"]: await _empty_inherited(t)
	if selected in ["", "telegraph"]: await _telegraph_pool(t)
	if selected in ["", "birth_exit"]:
		await _birth(t)
		await _exit(t)
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
	enemy.take_hit(1,t.player().global_position,t.player())
	t.check("reveal_next_current_root_finishes_partial_reveal", enemy.hp == seen[3].hp - 1 and not enemy._eyes.visible and (not is_instance_valid(enemy._host) or enemy._host.is_queued_for_deletion()))
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

func _reveal_control(t, mode: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var enemy := _enemy(t,boss)
	var saves: Node = t.autoload("SaveManager")
	var keep: String = saves.save_dir
	saves.save_dir = "user://h2b-reveal-" + mode
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("h2b_late",late,1000)
	t.check(mode + "_reveal_real_primary_without_backup", saves.save_game(0) and not FileAccess.file_exists(saves.backup_path(0)))
	var files := H1.new()._files(saves)
	var receipt := EventBus.combat_receipt(EventBus.combat_origin(t.player()),enemy)
	var seen: Array = []
	var observer := func():
		if not enemy.visual.visible or not seen.is_empty(): return
		seen.append(true)
		if mode == "failed":
			late.rejects = 1
			seen.append(saves.load_game(0))
	var hp := enemy.hp
	enemy.visual.visibility_changed.connect(observer)
	enemy.take_hit(1,t.player().global_position,t.player())
	enemy.visual.visibility_changed.disconnect(observer)
	t.check(mode + "_reveal_ordinary_or_authentic_fullfailed", seen == ([true,false] if mode == "failed" else [true]) and EventBus.combat_current(receipt) and not saves.network_admission_blocked())
	t.check(mode + "_reveal_health_stun_host_complete", enemy.hp == hp - 1 and enemy.state == Enemy2D.S.STUN and enemy.stun_generation == 1 and not enemy._eyes.visible and (not is_instance_valid(enemy._host) or enemy._host.is_queued_for_deletion()))
	t.check(mode + "_reveal_files_exact", H1.new()._files(saves) == files)
	saves.unregister_section("h2b_late")
	late.free()
	saves.save_dir = keep
	await t.go_menu()

func _ordinary_death(t, replace_profile: bool) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var ref: WeakRef = weakref(boss)
	boss.take_hit(9999,t.player().global_position,t.player())
	await t.seconds(.12)
	t.check("ordinary_death_" + str(replace_profile) + "_normal_fade_scale_shutdown", boss.state == Enemy2D.S.DEAD and not boss.is_physics_processing() and not boss._hurtbox.monitorable and boss.visual.modulate.a > 0 and boss.visual.modulate.a < 1 and boss.visual.scale.x < 1 and boss.visual.scale.x > .8)
	if not replace_profile:
		boss._die() # a redundant supported terminal root is not a new owner
	if replace_profile:
		var saves: Node = t.autoload("SaveManager")
		t.check("ordinary_death_profile_replacement_valid", saves._apply_payload(saves.gather_payload()).ok)
	await t.seconds(.5)
	t.check("ordinary_death_" + str(replace_profile) + "_exact_old_physical_cleanup_completes", not is_instance_valid(ref.get_ref()))
	await t.go_menu()

func _birth(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var saves: Node = t.autoload("SaveManager")
	var seen: Array = []
	var observer := func(node):
		if not node is Enemy2D or not seen.is_empty(): return
		seen.append(true)
		seen.append(weakref(node))
		seen.append(saves._apply_payload(saves.gather_payload()).ok)
		seen.append(node.get_child_count())
	boss.area.objects.child_entered_tree.connect(observer)
	boss.take_hit(boss.hp - 1,t.player().global_position,t.player())
	boss.area.objects.child_entered_tree.disconnect(observer)
	var born: Variant = seen[1].get_ref()
	t.check("birth_actual_phase_child_before_ready_replaced", seen.size() == 4 and seen[2] and seen[3] == 0)
	t.check("birth_stale_ready_suffix_does_not_create_children", is_instance_valid(born) and born.get_child_count() == seen[3] and not born.is_in_group("enemy"))
	await t.go_menu()

func _exit(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	var original: WeakRef = weakref(boss.arena_ring)
	var replacement := Node2D.new()
	boss.area.ground_fx.add_child(replacement)
	var seen: Array = []
	var observer := func(_name, _ratio, _shown):
		if not seen.is_empty(): return
		seen.append(true)
		boss.arena_ring = replacement
	EventBus.boss_bar_changed.connect(observer)
	boss.get_parent().remove_child(boss)
	EventBus.boss_bar_changed.disconnect(observer)
	t.check("exit_actual_bar_new_resource_not_retired", seen == [true] and not replacement.is_queued_for_deletion())
	t.check("exit_exact_old_arena_ring_retired", is_instance_valid(original.get_ref()) and original.get_ref().is_queued_for_deletion())
	boss.free()
	await t.go_menu()

func _telegraph_pool(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var saves: Node = t.autoload("SaveManager")
	var fx := boss.area.ground_fx
	var seen: Array = []
	var observer := func(node):
		if node.name != &"TelegraphPool" or not seen.is_empty(): return
		seen.append(true)
		seen.append(saves._apply_payload(saves.gather_payload()).ok)
		seen.append(node.get_child_count())
	fx.child_entered_tree.connect(observer)
	boss.take_hit(boss.hp - 1,t.player().global_position,t.player())
	fx.child_entered_tree.disconnect(observer)
	var pool := fx.get_node_or_null("TelegraphPool")
	t.check("telegraph_actual_owned_phase_warm_replaced", seen.size() == 3 and seen[1])
	t.check("telegraph_stale_warm_callee_stops", pool != null and pool.get_child_count() == seen[2])
	var ring := TelegraphRing2D.play(fx,boss.global_position,{"radius":90})
	t.check("telegraph_current_root_repairs_partial_pool", ring != null and pool.get_child_count() == TelegraphRing2D.CAP and ring.active and ring.is_processing())
	ring.finish()
	var leases: Array = []
	var replace := func():
		if not ring.visible or not leases.is_empty(): return
		leases.append(true)
		ring.finish()
		var newer := TelegraphRing2D.play(fx,boss.global_position,{"radius":133})
		leases.append(newer == ring)
		newer.finish()
		leases.append(newer.serial)
	ring.visibility_changed.connect(replace)
	TelegraphRing2D.play(fx,boss.global_position,{"radius":80})
	ring.visibility_changed.disconnect(replace)
	t.check("telegraph_configure_newer_same_slot_completed", leases.size() == 3 and leases[1] and ring.serial == leases[2] and ring.radius == 133 and not ring.active and not ring.visible)
	t.check("telegraph_old_configure_cannot_restart_new_completed_slot", not ring.is_processing())
	await t.go_menu()

func _empty_inherited(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var receipt := EventBus.combat_receipt(EventBus.combat_origin(t.player()),boss)
	var serial: int = boss._combat_serial
	var notices: Array = []
	var observer := func(_name, _ratio, _shown): notices.append(true)
	EventBus.boss_bar_changed.connect(observer)
	boss._on_health_changed_owned(receipt,{})
	t.check("explicit_empty_owned_health_refuses_without_new_request", boss._combat_serial == serial and notices.is_empty())
	boss._die_owned(receipt,{})
	EventBus.boss_bar_changed.disconnect(observer)
	t.check("explicit_empty_owned_death_refuses_without_new_request", boss._combat_serial == serial and boss.state != Enemy2D.S.DEAD and notices.is_empty())
	await t.go_menu()

func _death_cancel_profile(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	boss.take_hit(boss.hp - 1,t.player().global_position,t.player())
	boss.start_pattern("cloud")
	boss.begin_windup({"radius":90},1.0,"puff")
	var ring: TelegraphRing2D = boss.warning
	var adds: Array = boss.summoned.duplicate()
	var sequences: Array = boss.get_children().filter(func(n): return n.get_script() == DungeonBoss2D.Sequence).map(func(n): return weakref(n))
	var saves: Node = t.autoload("SaveManager")
	var files := H1.new()._files(saves)
	var seen: Array = []
	var observer := func():
		if ring.visible or not seen.is_empty(): return
		seen.append(true)
		seen.append(saves._apply_payload(saves.gather_payload()).ok)
		seen.append(saves.gather_payload())
		H2.new()._journal("death_cancel_profile","callback",{"payload":seen[2],"files":H1.new()._files(saves)})
	ring.visibility_changed.connect(observer)
	t.check("death_cancel_profile_real_clock_window",await t.until(func(): return fmod(Time.get_unix_time_from_system(),1.0) < .2,2.0))
	boss._die()
	ring.visibility_changed.disconnect(observer)
	t.check("death_cancel_profile_actual_finish_replaced",seen.size() == 3 and seen[1] and adds.size() == boss.adds and sequences.size() == 1)
	t.check("death_cancel_profile_exact_old_resources_queued",(adds + sequences).all(func(r): return is_instance_valid(r.get_ref()) and r.get_ref().is_queued_for_deletion()))
	var after: Dictionary = saves.gather_payload()
	H2.new()._journal("death_cancel_profile","unwind",{"payload":after,"files":H1.new()._files(saves)})
	t.check("death_cancel_profile_winner_exact_unwind",Compare.new()._same_payload(seen[2],after),str(Compare.new()._changed(seen[2],after)))
	await t.frames(3)
	var queued: Dictionary = saves.gather_payload()
	H2.new()._journal("death_cancel_profile","three_frames",{"payload":queued,"files":H1.new()._files(saves)})
	t.check("death_cancel_profile_winner_exact_three_frames",Compare.new()._same_payload(seen[2],queued),str(Compare.new()._changed(seen[2],queued)))
	t.check("death_cancel_profile_resources_gone_files_exact",(adds + sequences).all(func(r): return not is_instance_valid(r.get_ref())) and H1.new()._files(saves) == files)
	await t.go_menu()
