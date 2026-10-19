extends RefCounted
const SECTION := "enemies"
const TIMEOUT_S := 180.0
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _spawn(area: IsoArea, kind: String, at: Vector2, params: Dictionary = {}) -> Enemy2D:
	params = params.duplicate()
	params["kind"] = kind
	var enemy: Enemy2D = Enemy2D.create_marker(params,at,area.global_to_cell(at),area)
	if enemy != null:
		area.objects.add_child(enemy)
		enemy.set_awake(true)
		enemy.set_physics_process(false)
	return enemy
func _run(t, native: bool) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	await world.travel(&"_fixture_ortho",&"from_iso")
	for node in t.tree.get_nodes_in_group("enemy"): node.queue_free()
	await t.frames(2)
	var area := world.area
	var player := world.player
	var at := player.global_position+Vector2(140,0)
	DungeonRun.apply_preset("none")
	var killed := []
	var record := func(uid,kind,loot): killed.append([uid,kind,loot])
	EventBus.enemy_defeated.connect(record)
	t.check("create_marker_is_picked_entry",IsoArea.resolve_handler("enemy").mode == "create_marker")
	for kind in ["bat","ugleoje","tornebusk","lysesvamp","mosfroe","sporesvamp","krystalugle"]:
		var enemy := _spawn(area,kind,at,{"tier":2})
		t.check("spawns_"+kind,enemy != null and enemy.visual != null and enemy.visual.scale == Vector2.ONE and enemy.tier == 2)
		if enemy == null: continue
		t.check("hp_ladder_"+kind,enemy.max_hp == DungeonRun.enemy_hp(kind,4))
		t.check("damage_ladder_"+kind,enemy.hit_damage() == (0 if enemy.critter else DungeonRun.enemy_damage(kind,2)))
		enemy.take_hit(999,player.global_position,player)
		enemy.take_hit(999,player.global_position,player)
		t.check("dies_and_emits_once_"+kind,enemy.state == Enemy2D.S.DEAD and killed.filter(func(row): return row[0] == enemy.uid and row[1] == kind).size() == 1)
		await t.frames(40)
	var normal := _spawn(area,"ugleoje",at)
	var armoured := _spawn(area,"tornebusk",at+Vector2(80,0))
	for enemy in [normal,armoured]:
		enemy.begin_windup({"shape":"line","width":80,"length":200,"direction":Vector2.LEFT},.5,"dash")
		t.check("telegraph_"+enemy.kind,enemy.warning.active and is_equal_approx(enemy.remaining,.5))
		enemy.take_hit(1,player.global_position)
	t.check("stagger_cancels_windup",normal.state == Enemy2D.S.STUN and (not normal._warning_valid() or not normal.warning.active) and normal.visual.modulate == Color.WHITE)
	t.check("armor_keeps_windup",armoured.state == Enemy2D.S.WINDUP and armoured.warning.active)
	DungeonRun.apply_preset("cozy")
	normal.begin_windup({"radius":100},.5,"contact")
	t.check("assist_scales_windup_and_damage",is_equal_approx(normal.remaining,.7) and normal.hit_damage() == 1)
	DungeonRun.apply_preset("none")
	var ambusher := _spawn(area,"ugleoje",at,{"ambush":1})
	t.check("ambush_starts_hidden",ambusher.ambush and not ambusher.visual.visible and ambusher.ambush_state == "hidden")
	ambusher._physics_process(.016)
	t.check("ambush_rustle_then_leap",ambusher.ambush_state == "rustle" and ambusher.state == Enemy2D.S.WINDUP and is_equal_approx(ambusher.remaining,.6))
	ambusher.remaining = 0
	ambusher._windup(Vector2.LEFT)
	t.check("ambush_leaps_once",ambusher.ambush_state == "revealed" and ambusher.visual.visible and ambusher.state == Enemy2D.S.LUNGE)
	var fallback := _spawn(area,"lysesvamp",at,{"ambush":1})
	t.check("ambush_kind_fallback",not fallback.ambush and fallback.visual.visible and fallback.critter)
	var reveal := _spawn(area,"bat",at,{"ambush":1})
	player.combat.cooldowns.light = 0
	player.combat.fairy_light()
	t.check("fairy_light_reveals_stuns",reveal.ambush_state == "revealed" and reveal.state == Enemy2D.S.STUN)
	var replay := _spawn(area,"ugleoje",at)
	t.check("rng_seeded_replay",normal.rng.seed == replay.rng.seed and normal.rng.randi() == replay.rng.randi())
	normal.set_awake(false)
	t.check("sleeping_enemy_cost_zero",normal.process_mode == Node.PROCESS_MODE_DISABLED)
	var stone := Runestone2D.new()
	stone.area = area
	stone.cell = area.global_to_cell(player.global_position)
	stone.hub = true
	area.objects.add_child(stone)
	stone.global_position = player.global_position
	stone.add_to_group("runestone")
	replay._physics_process(.016)
	t.check("runestone_leash_blocks_aggro",replay.state == Enemy2D.S.IDLE and not replay._attack.monitorable)
	stone.queue_free()
	player.combat._iframes = 1
	var hearts: int = player.half_hearts
	t.check("no_damage_during_dodge_iframes",not player.take_damage(2,at) and player.half_hearts == hearts)
	for ring in area.ground_fx.get_node("TelegraphPool").get_children():ring.finish()
	var warnings: Array[TelegraphRing2D] = []
	for i in 8:warnings.append(TelegraphRing2D.play(area.ground_fx,at,{"radius":100,"duration":10}))
	normal.state = Enemy2D.S.CHASE
	var delayed := not normal.begin_windup({"radius":100},.5,"contact")
	t.check("saturation_delays_attack_without_invisible_windup",delayed and normal.state==Enemy2D.S.CHASE and warnings.all(func(ring):return ring.active))
	warnings[0].finish()
	t.check("attack_retries_with_full_visible_warning",normal.begin_windup({"radius":100},.5,"contact") and normal.warning.active and is_equal_approx(normal.remaining,.5))
	var warning := normal.warning
	var serial := warning.serial
	normal.hit_stop(60)
	await t.seconds(.6)
	t.check("warning_survives_hit_stop_and_modal_delay",warning.active and warning.serial==serial and normal.state==Enemy2D.S.WINDUP)
	normal._cancel_attack()
	t.check("owner_cancellation_releases_warning",not warning.active)
	for ring in warnings:ring.finish()
	for node in [normal,armoured,ambusher,fallback,reveal,replay]: node.queue_free()
	EventBus.enemy_defeated.disconnect(record)
	await t.frames(2)
	# DUN-03: a frog that starts its wind-up mid-hop lands and holds still until the lunge. Velocity, not position:
	# a manual tick outside the physics step moves the body by the process delta, which differs with --fast.
	var frog := _spawn(area,"mosfroe",player.global_position+Vector2(220,0))
	frog.state = Enemy2D.S.CHASE
	frog.clock = .1
	frog._physics_process(1.0/60)
	var started := frog.state == Enemy2D.S.WINDUP
	var drift := frog.ground_velocity.length()
	var lift := absf(frog.hop_altitude)
	while frog.state == Enemy2D.S.WINDUP:
		frog._physics_process(1.0/60)
		if frog.state == Enemy2D.S.WINDUP:
			drift = maxf(drift,frog.ground_velocity.length())
			lift = maxf(lift,absf(frog.hop_altitude))
	t.check("hop_windup_holds_still",started and drift == 0 and lift == 0 and frog.state == Enemy2D.S.LUNGE,"started %s speed %.0f altitude %.0f state %d" % [started,drift,lift,frog.state])
	frog.queue_free()
	await t.frames(2)
	if native:
		await world.travel(&"_fixture_forest_fight",&"default")
		area = world.area
		player = world.player
		player.combat.cooldowns.light = 0
		var enemy := _spawn(area,"ugleoje",player.global_position+Vector2(260,0))
		enemy.begin_windup({"shape":"line","width":80,"length":300,"direction":Vector2.LEFT},30,"dash")
		player.camera.zoom = Vector2(.7,.7)
		player.camera.reset_smoothing()
		player.camera.force_update_scroll()
		await t.frames(4)
		await t.capture("telegraph_ring_readable")
		enemy.queue_free()
		var eyes := _spawn(area,"ugleoje",player.global_position+Vector2(700,0),{"ambush":1})
		eyes._eyes.visible = true
		player.camera.zoom = Vector2(.4,.4)
		player.camera.reset_smoothing()
		player.camera.force_update_scroll()
		await t.frames(3)
		await t.capture("ambush_eyes_visible_outside_lantern")
		eyes.queue_free()
	await t.frames(2)
