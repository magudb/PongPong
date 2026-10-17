extends RefCounted
const SECTION := "enemy_performance"
const Perf := preload("res://tests/perf_world.gd")
const TIMEOUT_S := 120.0
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size()/2])
func _run(t,native: bool) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	GameManager.set_config_override("time.minutes_per_real_second",0.0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	await world.travel(&"_fixture_ortho",&"from_iso")
	for node in t.tree.get_nodes_in_group("enemy"):node.queue_free()
	await t.frames(2)
	var area := world.area
	var player := world.player
	player.combat._iframes = 999
	var roster := DungeonEnemyRoster.of(area)
	roster.set_process(false)
	var actors: Array[Enemy2D] = []
	var kinds := ["bat","ugleoje","tornebusk","lysesvamp","mosfroe","sporesvamp","krystalugle"]
	for i in 48:
		var at := player.global_position+Iso.to_screen(Vector2.from_angle(TAU*i/48)*350)
		var actor: Enemy2D = Enemy2D.create_marker({"kind":kinds[i%kinds.size()],"tier":2,"persist":0},at,area.global_to_cell(at),area)
		actor.persist_cell = false
		area.objects.add_child(actor)
		actors.append(actor)
	t.check("alive_limit_48",actors.size()==48 and not roster.has_room() and Enemy2D.create_marker({"kind":"bat","persist":0},player.global_position,Vector2i.ZERO,area)==null)
	roster.refresh()
	var awake := actors.filter(func(actor):return actor.is_awake())
	t.check("awake_limit_24",awake.size()==24,"%d/48 awake" % awake.size())
	# Disabled nodes (and their animated children) receive no callback at all.
	for actor in actors:actor.set_awake(false)
	var clocks := actors.map(func(actor):return actor.clock)
	await t.physics(120)
	t.check("sleeping_callbacks_zero",actors.all(func(actor):return actor.process_mode==Node.PROCESS_MODE_DISABLED and is_equal_approx(actor.clock,clocks[actors.find(actor)])))
	# Actual FSM, terrain physics and visual-motion callback cost, measured in
	# batches to amortize the clock read; all seven behaviors are represented.
	roster.refresh()
	awake = actors.filter(func(actor):return actor.is_awake())
	for actor in actors:actor.set_physics_process(false)
	var samples := []
	for frame in 180:
		var began := Time.get_ticks_usec()
		for actor in awake:actor._physics_process(1.0/60)
		samples.append((Time.get_ticks_usec()-began)/1000.0/awake.size())
		await t.frames(1)
	var sorted := samples.duplicate()
	sorted.sort()
	var logic := {"median_ms_per_enemy":_median(samples),"p95_ms_per_enemy":sorted[floori(sorted.size()*.95)],"cap_ms":0.03,"samples":samples}
	t.check("awake_logic_budget",logic.p95_ms_per_enemy<=0.03,str(logic.p95_ms_per_enemy)+" ms p95 per enemy <=0.03")
	var report := {"engine":Engine.get_version_info(),"alive":48,"awake":24,"zoom":area.zoom_default,"logic":logic,"logic_method":"180 batches of 24 real FSM/move_and_slide/visual-motion callbacks, mixed seven kinds; clock overhead amortized; sleeping callbacks verified by unchanged clocks for 120 physics ticks"}
	if native:
		# Hold positions and keep normal sprite animation. Measure the renderer CPU and complete
		# frame deltas with the 24 visible animated actors versus the same nodes
		# hidden/disabled; the frame delta includes more than isolated drawing cost.
		for actor in actors:
			actor.set_awake(false)
			actor.visible = false
		player.set_zoom(area.zoom_default)
		t.check("native_uses_live_default_zoom",is_equal_approx(player.camera.zoom.x,area.zoom_default))
		player.camera.reset_smoothing()
		player.camera.force_update_scroll()
		var timing := Perf.uncap()
		var viewport: RID = t.tree.root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(viewport,true)
		var pairs := []
		var deltas := []
		for round_value in 3:
			for actor in awake:
				actor.visible = false
				actor.set_awake(false)
			await t.seconds(.25)
			var baseline: Dictionary = await Perf.measure_frames(t.tree,1.0,viewport)
			for actor in awake:
				actor.visible = true
				actor.set_awake(true)
				actor.set_physics_process(false)
			await t.seconds(.25)
			var enabled: Dictionary = await Perf.measure_frames(t.tree,1.0,viewport)
			var delta: float = (enabled.cpu_render_ms-baseline.cpu_render_ms)/24
			pairs.append({"baseline":baseline,"enabled":enabled,"render_cpu_delta_ms_per_enemy":delta,"whole_frame_delta_ms_per_enemy":(enabled.ms-baseline.ms)/24})
			deltas.append(delta)
		RenderingServer.viewport_set_measure_render_time(viewport,false)
		Perf.restore_cap(timing)
		var render := {"pairs":pairs,"median_render_cpu_delta_ms_per_enemy":_median(deltas),"cap_ms":0.018,"method":"median of three paired one-second RenderingServer CPU render-time deltas at the live default area zoom, 24 animated visible actors versus hidden/disabled; fixed positions, no FSM callbacks, vsync and FPS caps disabled; whole-frame deltas retained separately; GPU timing unavailable when reported as zero"}
		report["render"] = render
		t.check("render_timing_is_available",pairs.all(func(pair):return pair.baseline.cpu_render_ms>0 and pair.enabled.cpu_render_ms>0))
		t.check("animated_render_budget",render.median_render_cpu_delta_ms_per_enemy<=0.018,str(render.median_render_cpu_delta_ms_per_enemy)+" ms CPU render per enemy <=0.018")
		await t.capture("enemy_population_24")
	var out := ProjectSettings.globalize_path("res://docs/qa/mechanics/combat/enemy-performance-"+("native" if native else "headless")+".json")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var file := FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	for actor in actors:actor.queue_free()
	await t.frames(2)
	await world.travel(&"farm",&"default")
	GameManager.clear_config_overrides()
