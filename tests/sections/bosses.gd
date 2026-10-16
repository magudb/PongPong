extends RefCounted
const SECTION := "bosses"
const TIMEOUT_S := 180.0
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _run(t, native: bool) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var floors := DungeonFloors.inst()
	var gm: Node = t.autoload("GameManager")
	var bars := []
	var kills := []
	var record_bar := func(key,ratio,shown): bars.append([key,ratio,shown])
	var record_kill := func(uid,kind,loot): kills.append([uid,kind,loot])
	EventBus.boss_bar_changed.connect(record_bar)
	EventBus.enemy_defeated.connect(record_kill)
	for row in [[4,"snurresvamp",80,4],[8,"snurresvamp_gloed",176,6],[12,"snurresvamp_konge",288,8]]:
		floors.ensure_registered(row[0])
		await world.travel(StringName("moerkeskoven_f%d" % row[0]),&"default")
		var found := world.area.find_markers("enemy").filter(func(marker): return marker.node is DungeonBoss2D)
		t.check("spawn_"+row[1],found.size() == 1)
		if found.size() != 1: continue
		var boss: DungeonBoss2D = found[0].node
		DungeonEnemyRoster.of(world.area).set_process(false)
		for node in t.tree.get_nodes_in_group("enemy"):
			node.set_physics_process(false)
		boss.set_awake(true)
		t.check("hp_and_kind_"+row[1],boss.hp == row[2] and boss.kind == row[1] and boss.armor and boss.is_boss)
		world.player.global_position = boss.home+Vector2(850,0)
		boss._physics_process(.016)
		t.check("sleep_until_520_"+row[1],not boss.awake and boss.hp == row[2])
		world.player.global_position = boss.home+Vector2(450,0)
		boss._physics_process(.016)
		t.check("bar_and_wake_"+row[1],boss.awake and bars.any(func(bar): return bar[0] == str(boss.cfg.name_key) and bar[2]))
		boss.start_pattern("dash")
		t.check("dash_telegraph_"+row[1],boss.state == Enemy2D.S.WINDUP and boss.warning.hit_area().shape == "line" and boss.warning.width == 90 and is_equal_approx(boss.remaining,float(boss.cfg.windup)*DungeonRun.windup_mult()))
		boss.remaining = 0
		boss._windup(Vector2.RIGHT)
		t.check("dash_speed_"+row[1],boss.state == Enemy2D.S.LUNGE and is_equal_approx(boss.ground_velocity.length(),float(boss.cfg.patterns.dash_speed)))
		boss._recover()
		t.check("dazed_window_"+row[1],boss.state == Enemy2D.S.RECOVER and is_equal_approx(boss.remaining,float(boss.cfg.dazed)))
		boss.hp = floori(boss.max_hp*.65)
		boss._on_health_changed()
		t.check("first_wave_"+row[1],boss.phase == 1 and boss.summoned.size() == int(row[3])/2)
		boss.hp = floori(boss.max_hp*.32)
		boss._on_health_changed()
		t.check("second_wave_"+row[1],boss.phase == 2 and boss.summoned.size() == row[3])
		boss._on_health_changed()
		t.check("phase_berries_once_"+row[1],world.area.objects.get_children().filter(func(n): return n is LootDrop2D and n.item_id == &"tornebaer").size() == 2 and boss.summoned.size() == row[3])
		if row[0] > 4:
			boss.start_pattern("quake")
			t.check("quake_radius_"+row[1],boss.warning.radius == 260)
			boss.start_pattern("cloud")
			var sequences := boss.get_children().filter(func(n): return n.get_script() == DungeonBoss2D.Sequence)
			t.check("two_clouds_"+row[1],sequences.size() == 1 and sequences[0].rows.size() == 2)
		if row[0] == 12:
			boss.start_pattern("rain")
			var sequence: Node = boss.get_children().filter(func(n): return n.get_script() == DungeonBoss2D.Sequence).back()
			t.check("nine_staggered_rain_marks",sequence.rows.size() == 9 and sequence.rows[8].delay == 8*.35 and sequence.rows[0].radius == 120 and sequence.rows[0].windup == DungeonRun.windup_mult())
		boss.reset_fight()
		t.check("reset_no_rewards_"+row[1],boss.hp == boss.max_hp and not boss.awake and boss.phase == 0 and int(gm.get_flag(StringName("dungeon_boss_"+row[1]),0)) == 0)
		await t.frames(2)
		boss.set_awake(true)
		boss.take_hit(9999,world.player.global_position,world.player)
		boss.take_hit(9999,world.player.global_position,world.player)
		t.check("death_once_"+row[1],kills.filter(func(entry): return entry[1] == row[1]).size() == 1)
		t.check("real_floor_chain_"+row[1],gm.flag_int(StringName("dungeon_boss_"+row[1]),0) > 0 and gm.flag_int(&"dungeon_hearts_bonus",0) == (row[0]/4)*2 and floors.is_done_cell(world.area,boss.cell) and gm.get_flag(&"dg_boss_clear",false))
		await t.frames(40)
	EventBus.boss_bar_changed.disconnect(record_bar)
	EventBus.enemy_defeated.disconnect(record_kill)
	if native:
		floors.done.erase(4)
		await world.travel(&"moerkeskoven",&"from_floor")
		floors.ensure_registered(4)
		await world.travel(&"moerkeskoven_f4",&"default")
		var bosses := world.area.find_markers("enemy").filter(func(marker): return marker.node is DungeonBoss2D)
		if not bosses.is_empty():
			var boss: DungeonBoss2D = bosses[0].node
			boss.set_awake(true)
			boss.set_physics_process(false)
			world.player.global_position = boss.home+Vector2(350,100)
			world.player.camera.zoom = Vector2(.55,.55)
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			boss._physics_process(.016)
			boss.begin_windup({"shape":"line","width":90,"length":310,"direction":Vector2.RIGHT},30,"dash")
			await t.frames(4)
			await t.capture("boss_telegraph_shot")
	await t.frames(2)
