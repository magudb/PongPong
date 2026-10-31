extends RefCounted
const SECTION := "attack_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")
const H2 := preload("res://tests/sections/boss_inner_origins.gd")
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func run(t) -> void:
	var selected := OS.get_environment("H3_CASE")
	if selected in ["", "immediate"]: await _immediate(t)
	if selected in ["", "collision"]:
		for mode in ["direct", "normal", "failed", "dodge"]: await _collision(t,mode)
	if selected in ["", "child"]: await _child(t)
	if selected in ["", "buffer"]: await _buffer(t)

func _immediate(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var player: Player2D = t.player()
	var combat := player.combat
	player.global_position = boss.home + Vector2(-60,0)
	var enemy := Enemy2D.create_marker({"kind":"ugleoje", "persist":0}, boss.home + Vector2(30,0), boss.cell, boss.area) as Enemy2D
	boss.area.objects.add_child(enemy)
	enemy.set_awake(true)
	enemy.set_physics_process(false)
	EconomyManager.add_item(&"wpn_club_trunk", 1)
	var item: StringName = &"wpn_club_trunk"
	# Use the shipped quake cadence: the next real swing is its fourth.
	player.set_meta("weapon_swing_" + str(item), 3)
	var info := WeaponInfo.of(item)
	t.check("authored_quake_weapon_and_two_live_targets", str(info.get("effect",{}).get("id","")) == "quake" and boss.hp > 30 and enemy.hp > 0 and player.world_input_allowed())
	var saves: Node = t.autoload("SaveManager")
	var second_hp := enemy.hp
	var first_hp := boss.hp
	var notices: Array = []
	var seen: Array = []
	var receipt := EventBus.combat_receipt(EventBus.combat_origin(player))
	var observer := func(_name, _ratio, _shown):
		if not seen.is_empty(): return
		seen.append(true)
		var payload: Dictionary = saves.gather_payload()
		seen.append(saves.validate_payload(payload).ok and saves._apply_payload(payload).ok)
		seen.append(saves.gather_payload())
		seen.append(player._last_stats.duplicate(true))
		H2.new()._journal("attack_immediate", "callback", {"payload":seen[2],"body_cache":seen[3],"files":H1.new()._files(saves)})
	var drawn := func(id): notices.append(["drawn",id])
	var swung := func(at): notices.append(["swung",at])
	EventBus.boss_bar_changed.connect(observer)
	combat.weapon_drawn.connect(drawn)
	player.swung.connect(swung)
	var ok := combat.swing(item, boss.global_position)
	EventBus.boss_bar_changed.disconnect(observer)
	combat.weapon_drawn.disconnect(drawn)
	player.swung.disconnect(swung)
	t.check("immediate_real_swing_first_committed_hit_then_same_apply", ok and seen.size() == 4 and seen[1] and boss.hp < first_hp and not EventBus.combat_current(receipt))
	t.check("immediate_obsolete_second_target_refused", enemy.hp == second_hp)
	t.check("immediate_obsolete_pulse_and_uncommitted_notices_refused", notices.is_empty() and boss.area.ground_fx.get_children().filter(func(n): return n is LightRing2D).is_empty())
	var after: Dictionary = saves.gather_payload()
	H2.new()._journal("attack_immediate","unwind",{"payload":after,"body_cache":player._last_stats,"files":H1.new()._files(saves)})
	t.check("immediate_full_winner_exact_unwind",Compare.new()._same_payload(seen[2],after))
	# Later actual production ticks must not mint a new model owner for this swing.
	combat.tick(.08)
	await t.frames(3)
	combat.tick(.02)
	var queued: Dictionary = saves.gather_payload()
	H2.new()._journal("attack_immediate","three_frames",{"payload":queued,"body_cache":player._last_stats,"files":H1.new()._files(saves)})
	t.check("immediate_old_active_frames_cannot_damage",enemy.hp == second_hp)
	t.check("immediate_full_winner_exact_three_frames",Compare.new()._same_payload(seen[2],queued) and player._last_stats == seen[3])
	await t.go_menu()

func _collision(t, mode: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var player: Player2D = t.player()
	var combat := player.combat
	player.global_position = boss.home + Vector2(-60,0)
	var enemy := Enemy2D.create_marker({"kind":"ugleoje","persist":0},boss.home+Vector2(-20,0),boss.cell,boss.area) as Enemy2D
	boss.area.objects.add_child(enemy)
	enemy.set_awake(true)
	enemy.set_physics_process(false)
	EconomyManager.add_item(&"sword_rusty",1)
	await t.physics(2)
	var saves: Node = t.autoload("SaveManager")
	var keep: String = saves.save_dir
	saves.save_dir = "user://h3-collision-" + mode
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("h3_late",late,1000)
	t.check(mode+"_collision_primary_no_backup",saves.save_game(0) and not FileAccess.file_exists(saves.backup_path(0)))
	var files := H1.new()._files(saves)
	var hp := [boss.hp,enemy.hp]
	var seen: Array = []
	var origin := EventBus.combat_receipt(EventBus.combat_origin(player))
	var observer := func(name,payload):
		if name != &"audio_cue" or payload.get("cue") != "sfx/hit_soft" or not seen.is_empty(): return
		seen.append(true)
		seen.append([boss.hp,enemy.hp])
		if mode == "direct":
			seen.append(saves._apply_payload(saves.gather_payload()).ok)
			seen.append(saves.gather_payload())
			seen.append(player._last_stats.duplicate(true))
			H2.new()._journal("collision_"+mode,"callback",{"payload":seen[3],"body_cache":seen[4],"files":H1.new()._files(saves)})
		elif mode == "failed":
			late.rejects = 1
			seen.append(saves.load_game(0))
		elif mode == "dodge":
			seen.append(combat.dodge())
			seen.append(combat._remaining)
			seen.append(combat.cooldowns.duplicate())
	t.check(mode+"_collision_real_clock_window",await t.until(func(): return fmod(Time.get_unix_time_from_system(),1.0)<.2,2.0))
	EventBus.game_event.connect(observer)
	t.check(mode+"_collision_real_authored_swing_admitted",combat.swing(&"sword_rusty",boss.global_position))
	combat.tick(combat._swing_duration*.5)
	EventBus.game_event.disconnect(observer)
	t.check(mode+"_collision_real_query_reached_one_committed_target",seen.size() >= 2 and ((seen[1][0] < hp[0] and seen[1][1] == hp[1]) or (seen[1][1] < hp[1] and seen[1][0] == hp[0])))
	if mode == "direct":
		t.check("collision_direct_same_apply_revokes",seen.size() == 5 and seen[2] and not EventBus.combat_current(origin))
		t.check("collision_direct_second_target_and_hitstop_shake_refused",[boss.hp,enemy.hp] == seen[1] and combat.hit_stop == 0 and combat._shake == 0)
		var after: Dictionary = saves.gather_payload()
		H2.new()._journal("collision_direct","unwind",{"payload":after,"body_cache":player._last_stats,"files":H1.new()._files(saves)})
		t.check("collision_direct_full_winner_exact_unwind",Compare.new()._same_payload(seen[3],after))
		await t.frames(3)
		combat.tick(.02)
		var queued: Dictionary = saves.gather_payload()
		H2.new()._journal("collision_direct","three_frames",{"payload":queued,"body_cache":player._last_stats,"files":H1.new()._files(saves)})
		t.check("collision_direct_later_active_frame_refuses",[boss.hp,enemy.hp] == seen[1] and Compare.new()._same_payload(seen[3],queued) and player._last_stats == seen[4])
		# A genuinely independent action can progress after the stale one retires.
		combat.tick(1.0)
		t.check("collision_direct_future_current_root",combat.swing(&"sword_rusty",boss.global_position))
		combat.tick(combat._swing_duration*.5)
		t.check("collision_direct_new_root_hits_remaining_targets",boss.hp < seen[1][0] and enemy.hp < seen[1][1])
	elif mode == "dodge":
		t.check("collision_dodge_legitimate_new_action_admitted",seen.size()==5 and seen[2] and player.state == PlayerBody2D.S.DODGE)
		t.check("collision_dodge_exact_new_remaining_cooldowns_no_old_hitstop",combat._remaining == seen[3] and combat.cooldowns == seen[4] and combat.hit_stop == 0 and combat._shake == 0 and [boss.hp,enemy.hp] == seen[1])
		combat.tick(.03)
		t.check("collision_dodge_natural_next_tick_progress",player.state == PlayerBody2D.S.DODGE and combat._remaining < seen[3] and combat.extra_altitude > 0)
	else:
		t.check(mode+"_collision_original_origin_current",EventBus.combat_current(origin) and (seen == [true,seen[1],false] if mode == "failed" else seen.size()==2))
		t.check(mode+"_collision_both_targets_exact_authored_damage",boss.hp == hp[0]-int(GameData.item_def(&"sword_rusty").damage) and enemy.hp == hp[1]-int(GameData.item_def(&"sword_rusty").damage) and combat.hit_stop > 0, str({"before":hp,"after":[boss.hp,enemy.hp],"damage":GameData.item_def(&"sword_rusty").get("damage"),"hits":combat._hit.keys(),"positions":[player.global_position,boss.global_position,enemy.global_position],"radius":combat._swing_radius,"direction":combat.swing_direction(),"half":combat._swing_half}))
		var once := [boss.hp,enemy.hp]
		for i in 4: combat.tick(.005)
		t.check(mode+"_collision_active_repeat_once_per_target",[boss.hp,enemy.hp] == once)
	t.check(mode+"_collision_files_exact",H1.new()._files(saves)==files)
	saves.unregister_section("h3_late")
	late.free()
	saves.save_dir = keep
	await t.go_menu()

func _child(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var player: Player2D = t.player()
	EconomyManager.add_item(&"sword_rusty",1)
	var seen: Array = []
	var saves: Node = t.autoload("SaveManager")
	var observer := func(node):
		if not node is Slash2D or not seen.is_empty(): return
		seen.append(weakref(node))
		seen.append(saves._apply_payload(saves.gather_payload()).ok)
		seen.append(player.visual.current_clip)
	var notices: Array = []
	var notice := func(_id): notices.append(true)
	player.child_entered_tree.connect(observer)
	player.combat.weapon_drawn.connect(notice)
	t.check("child_real_swing_admitted",player.combat.swing(&"sword_rusty",boss.global_position))
	player.child_entered_tree.disconnect(observer)
	player.combat.weapon_drawn.disconnect(notice)
	t.check("child_pre_ready_real_apply_no_stale_visual_or_notices",seen.size()==3 and seen[1] and player.visual.current_clip == seen[2] and notices.is_empty())
	await t.frames(3)
	t.check("child_rejected_slash_ready_does_not_survive",not is_instance_valid(seen[0].get_ref()))
	await t.go_menu()

func _buffer(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var player: Player2D = t.player()
	var combat := player.combat
	EconomyManager.add_item(&"sword_rusty",1)
	var newer: Array = []
	var aim := player.global_position+Vector2(-200,0)
	var observer := func(_id):
		if not newer.is_empty(): return
		newer.append(true)
		combat.request(&"slash",&"sword_rusty",aim)
		newer.append(combat._buffer_time)
	combat.weapon_drawn.connect(observer)
	combat.request(&"slash",&"sword_rusty",boss.global_position)
	combat.weapon_drawn.disconnect(observer)
	t.check("buffer_callback_new_press_not_cleared_by_old_success",newer.size()==2 and combat._buffer==&"slash" and combat._buffer_aim==aim and combat._buffer_time==newer[1])
	# The callback press was made at swing start, so its .15s buffer may
	# legitimately expire before the .4s cycle. A new late press is eligible.
	combat.attack_held = false
	combat.tick(combat._swing_duration)
	combat.tick(.06)
	combat.request(&"slash",&"sword_rusty",aim)
	combat.attack_held = false
	combat.tick(float(combat.cooldowns.slash)+.001)
	t.check("buffer_real_next_dispatch_uses_original_click",combat._buffer==&"" and player.state==PlayerBody2D.S.SWING and combat.swing_direction().x < -.99)
	await t.go_menu()
