extends RefCounted
const SECTION := "dungeon_performance"
const TIMEOUT_S := 120.0
const Perf := preload("res://tests/perf_world.gd")
const LookFixture := preload("res://tests/sections/forest_look.gd")
func run_windowed(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	var world: WorldRoot2D = t.world()
	var map := LookFixture.new()._fixture()
	map.id = &"_dungeon_busy"
	for y in map.height:
		for x in map.width:
			if map.object_at(Vector2i(x,y))=="U":map.set_object(Vector2i(x,y),".")
	WorldRoot2D.register_map(map.id,map)
	await world.travel(map.id,&"default")
	await t.frames(3)
	var area := world.area
	var look: ForestDress = area.get_node("ForestLook")
	var existing: Array[PointLight2D] = []
	look._collect_lights(area,existing)
	for light in existing:light.queue_free()
	await t.frames(2)
	var at: Vector2 = world.player.global_position
	for i in 200:
		var cell := Vector2i(11+i%20,15+i/20)
		area.place_prop(&"rock_grey",cell)
	var lights: Array[PointLight2D] = []
	for i in 12:
		var light := PointLight2D.new()
		light.texture = Glow.light_texture()
		light.texture_scale = 8
		light.energy = .12
		area.objects.add_child(light)
		light.global_position = at+Vector2.from_angle(TAU*i/12)*150
		lights.append(light)
	t.check("twelve_overlapping_map_lights",look.enforce_light_budget().is_empty() and lights.all(func(light):return light.enabled and light.is_visible_in_tree()))
	var actors: Array[Enemy2D] = []
	for i in 24:
		var point := at+Iso.to_screen(Vector2.from_angle(TAU*i/24)*300)
		var actor: Enemy2D = Enemy2D.create_marker({"kind":"ugleoje","tier":2,"persist":0},point,area.global_to_cell(point),area)
		actor.persist_cell = false
		area.objects.add_child(actor)
		actors.append(actor)
	DungeonEnemyRoster.of(area).refresh()
	for i in 8:actors[i].begin_windup({"shape":"line","length":350,"width":80,"direction":Vector2.from_angle(TAU*i/8)},30,"dash")
	for i in 15:LootDrop2D.spawn(area.objects,at+Iso.to_screen(Vector2.from_angle(TAU*i/15)*650),"stone",1)
	world.player.combat._iframes = 999
	world.player.set_zoom(.4)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.game_ui.get_screen(&"hud").toasts.clear()
	await t.frames(4)
	var rings: Node = area.ground_fx.get_node("TelegraphPool")
	var orbs := area.objects.get_children().filter(func(node):return node is LootDrop2D and not node.collected)
	t.check("busy_floor_population",actors.size()==24 and actors.all(func(actor):return actor.is_awake()) and area.prop_nodes.size()>=200 and rings.get_children().filter(func(ring):return ring.active).size()==8 and orbs.size()==15,"props=%d orbs=%d" % [area.prop_nodes.size(),orbs.size()])
	var visible_lights := area.find_children("*","PointLight2D",true,false).filter(func(light):return light.enabled and light.is_visible_in_tree() and light.energy>0)
	t.check("global_light_limit_16",visible_lights.size()<=16,"%d emitting lights" % visible_lights.size())
	var cap := Perf.uncap()
	var viewport: RID = t.tree.root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	await t.frames(15)
	var samples := []
	for i in 3:samples.append(await Perf.measure_frames(t.tree,.5,viewport))
	var cpu := []
	for sample in samples:cpu.append(sample.cpu_render_ms)
	cpu.sort()
	t.check("busy_floor_cpu_render_budget",float(cpu[1])>0 and float(cpu[1])<=12,str(samples))
	var hud: Control = world.game_ui.get_screen(&"forest_hud")
	var began := Time.get_ticks_usec()
	for i in 180:hud._process(1.0/60)
	var hud_ms := (Time.get_ticks_usec()-began)/180000.0
	t.check("forest_hud_logic_budget",hud_ms<=.4,"%.5f ms <=0.4" % hud_ms)
	await t.capture("busy_floor_24_enemies_12_lights")
	var reveal: CanvasLayer = t.tree.get_first_node_in_group("loot_reveal")
	EconomyManager.add_item(&"gem_rune_heart",1,true)
	EventBus.rare_item_found.emit(&"gem_rune_heart",&"legendary")
	await t.frames(3)
	began = Time.get_ticks_usec()
	for i in 180:reveal._process(.001)
	var reveal_ms := (Time.get_ticks_usec()-began)/180000.0
	t.check("reveal_logic_budget",not reveal.active.is_empty() and reveal_ms<=.3,"%.5f ms <=0.3" % reveal_ms)
	await t.capture("busy_floor_legendary_reveal")
	reveal.finish()
	RenderingServer.viewport_set_measure_render_time(viewport,false)
	Perf.restore_cap(cap)
	var report := {"engine":Engine.get_version_info(),"device":RenderingServer.get_video_adapter_name(),"viewport":[1280,720],"zoom":.4,"awake_enemies":24,"map_lights":12,"emitting_lights":visible_lights.size(),"props":area.prop_nodes.size(),"rings":8,"orbs":15,"render_samples":samples,"median_cpu_render_ms":cpu[1],"cpu_render_cap_ms":12,"hud_logic_mean_ms":hud_ms,"hud_logic_cap_ms":.4,"reveal_logic_mean_ms":reveal_ms,"reveal_logic_cap_ms":.3,"method":"native real forest fixture; 200 added painted rock props, 24 live enemy FSMs, eight held attack warnings, fifteen ordinary orbs and twelve overlapping map lights; three half-second uncapped renderer samples; 180 real HUD/reveal callbacks; GPU zero means unavailable, no low-end-device claim"}
	var file := FileAccess.open("res://docs/qa/mechanics/combat/busy-floor.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	await world.travel(&"farm",&"default")
	WorldRoot2D.unregister_map(&"_dungeon_busy")
	GameManager.clear_config_overrides()
