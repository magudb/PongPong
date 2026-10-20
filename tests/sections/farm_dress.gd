extends RefCounted
const SECTION := "farm_dress"
const TIMEOUT_S := 180.0
const Perf := preload("res://tests/perf_world.gd")
const EXPECT := {"flower_box":3,"garden_arch":5,"fountain_small":8,"royal_banner":10}
var world: Node
func _start(t) -> void:
	await t.start_world()
	world = t.world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
func _dress() -> Array:
	return world.area.find_markers("dress").map(func(row):return row.node)
func _fx() -> FarmAmbientFx:
	return world.area.find_markers("ambient_fx")[0].node as FarmAmbientFx
func _season(id: StringName,hour := 12,weather := &"klart") -> void:
	GameManager.season = id
	GameManager.hour = hour
	GameManager.minute = 0
	TimeManager.weather = weather
	EventBus.season_changed.emit(id)
	EventBus.weather_changed.emit(weather)
	EventBus.time_of_day_changed.emit(hour,0)
	world.day_night.snap()
	(_fx().get_node("SeasonalFx") as SeasonalFarmFx).refresh()
func run(t) -> void:
	await _start(t)
	var markers := _dress()
	t.check("sixteen_markers_implemented",markers.size()==16 and markers.all(func(node):return node is FarmDress and node.valid),str(world.area.map.errors))
	var probe := IsoArea.new()
	probe.map = world.area.map
	t.check("reserve_complete_before_nodes_spawn",world.area.find_markers("building_slot").all(func(row):return FarmReserve.blocked(probe,row.cell)=="slot") and FarmReserve.blocked(probe,world.area.find_markers("greenhouse_slot")[0].cell)=="slot")
	probe.free()
	var starts := LuaData.arr(Svc.lua_config("farm_site.stages",[])).map(func(stage):return int(stage.tiers[0]))
	t.check("thresholds_are_stage_starts",markers.all(func(node):return not node.params.has("tier") or (int(node.params.tier) in starts and int(node.params.tier)==int(EXPECT.get(str(node.params.prop),-1)))))
	t.check("map_dress_ids_have_art",markers.all(func(node):return ArtCatalog.has_real_prop(StringName(str(node.params.prop)))))
	for tier in [1,2,3,4,5,7,8,9,10]:
		HomeManager.set_tier(tier)
		await t.frames(2)
		t.check("tier_"+str(tier)+"_dress_follows_home",markers.filter(func(node):return node.params.has("tier")).all(func(node):return is_instance_valid(node.prop)==(tier>=int(node.params.tier))))
	HomeManager.set_tier(1)
	for season in [&"foraar",&"sommer",&"efteraar",&"vinter"]:
		var old: WeakRef = weakref(_fx().leaves)
		_season(season)
		await t.frames(2)
		var emitter := _fx().leaves
		var maximum := int({"foraar":20,"sommer":14,"efteraar":16,"vinter":40}[str(season)])
		t.check(str(season)+"_dress_follows_season",markers.filter(func(node):return node.params.has("season")).all(func(node):return is_instance_valid(node.prop)==(str(node.params.season)==str(season))))
		t.check(str(season)+"_fx_caps",emitter.amount<=maximum and emitter.amount>=1)
		t.check(str(season)+"_one_family",t.tree.get_nodes_in_group("farm_seasonal_particles").filter(func(node):return node.is_inside_tree() and not node.is_queued_for_deletion()).size()==1)
		if str(season)!="foraar":t.check(str(season)+"_old_family_freed",old.get_ref()==null)
		var trees: Array = t.tree.get_nodes_in_group("resource_node").filter(func(node):return node.kind=="apple_tree")
		var expected := "apple_tree" if season==&"sommer" else "apple_tree_"+str(season)
		t.check(str(season)+"_tree_variant",not trees.is_empty() and trees.all(func(node):return node._picture.texture==ArtCatalog.prop(StringName(expected)).texture and node._picture.offset==-ArtCatalog.prop(StringName(expected)).pivot))
	_season(&"sommer",12)
	t.check("summer_day_has_no_fireflies",not _fx().leaves.emitting)
	_season(&"sommer",24)
	t.check("summer_raw_midnight_has_fireflies",_fx().leaves.emitting and _fx().leaves.amount<=14 and _fx().leaves.material==Glow.additive_material())
	_season(&"vinter",12,&"sne")
	t.check("snow_weather_stays_under_forty",_fx().leaves.amount==40)
	_season(&"vinter",12,&"klart")
	t.check("ordinary_winter_snow_is_lighter",_fx().leaves.amount==20)
	GameManager.clear_flag(&"festival_now")
	await t.frames(2)
	var flags := markers.filter(func(node):return node.params.has("event"))
	t.check("event_flag_absent_is_off",flags.size()==2 and flags.all(func(node):return not is_instance_valid(node.prop)))
	GameManager.set_flag(&"festival_now","bryllupsfesten")
	await t.frames(2)
	t.check("event_dress_follows_flag",flags.all(func(node):return is_instance_valid(node.prop)))
	GameManager.clear_flag(&"festival_now")
	await t.frames(2)
	t.check("event_dress_removed",flags.all(func(node):return not is_instance_valid(node.prop)))
	var reserves: Array = []
	for node in markers:
		if not node.valid:reserves.append(node.params)
	t.check("no_dress_in_reserve",reserves.is_empty(),str(reserves))
	var bad := FarmDress.create_marker({"prop":"flower_box","season":"foraar","tier":1},Vector2.ZERO,Vector2i.ZERO,world.area) as FarmDress
	var errors: int = world.area.map.errors.size()
	world.area.objects.add_child(bad)
	t.check("two_conditions_rejected",not bad.valid and bad.prop==null and world.area.map.errors.size()==errors+1)
	world.area.map.errors.resize(errors)
	bad.queue_free()
	var reserved: Vector2i = world.area.find_markers("home")[0].cell
	bad = FarmDress.create_marker({"prop":"flower_box","tier":1},Vector2.ZERO,reserved,world.area) as FarmDress
	world.area.objects.add_child(bad)
	t.check("home_reserve_mutant_rejected",not bad.valid and bad.prop==null)
	world.area.map.errors.resize(errors)
	bad.queue_free()
	var before: WeakRef = weakref(world.area)
	await world.travel(&"hyggebyen",&"default")
	GameManager.season = &"foraar"
	EventBus.season_changed.emit(&"foraar")
	await world.travel(&"farm",&"from_home")
	await t.frames(3)
	t.check("parked_farm_refreshes_on_return",before.get_ref()==world.area and (_fx().get_node("SeasonalFx") as SeasonalFarmFx).family=="foraar" and _dress().filter(func(node):return node.params.has("season")).all(func(node):return is_instance_valid(node.prop)==(str(node.params.season)=="foraar")))
	t.check("cosmetics_not_saved",not JSON.stringify(world.to_dict()).contains("blossom_cluster") and not JSON.stringify(world.to_dict()).contains("SeasonalParticles"))
	await t.go_menu()

func _native_season(t,id: StringName,hour := 12,weather := &"klart") -> void:
	GameManager.day = 2
	GameManager.year = 1
	_season(id,hour,weather)
	EventBus.day_started.emit(GameManager.day,id)
	SocialManager.flush()
	await t.frames(4)

func _focus(t,node: Node2D,zoom := 0.75) -> void:
	var placed := false
	for turn in 24:
		var point := node.global_position+Iso.to_screen(Vector2.from_angle(TAU*turn/24.0)*170.0)
		var query := PhysicsPointQueryParameters2D.new()
		query.position = point
		query.collision_mask = Iso.MASK_WALKING
		query.collide_with_areas = false
		query.exclude = [world.player.get_rid()]
		if world.area.is_walkable(world.area.global_to_cell(point)) and world.area.get_world_2d().direct_space_state.intersect_point(query).is_empty():
			world.player.global_position = point
			placed = true
			break
	t.check("native_safe_approach_"+str(node.name),placed)
	world.player.camera.reset_smoothing()
	await t.physics(4)
	await world.player.camera_focus(node,zoom,0.2)
	await t.seconds(4.5)

func run_windowed(t) -> void:
	await _start(t)
	HomeManager.set_tier(3)
	var targets := {"foraar":"blossom_cluster","sommer":"sunflower_row","efteraar":"leaf_pile","vinter":"snow_patch"}
	for season in [&"foraar",&"sommer",&"efteraar",&"vinter"]:
		await _native_season(t,season)
		var chosen: Array = _dress().filter(func(node):return str(node.params.get("prop",""))==str(targets[str(season)]) and is_instance_valid(node.prop))
		t.check("native_"+str(season)+"_painted_dress_present",not chosen.is_empty())
		if not chosen.is_empty():await _focus(t,chosen[0].prop)
		await t.capture("farm_season_"+str(season))
	await _native_season(t,&"sommer",24)
	await t.seconds(2.0)
	t.check("native_night_fireflies",_fx().leaves.emitting and _fx().leaves.amount<=14)
	await t.capture("farm_season_sommer_night")
	await _native_season(t,&"foraar")
	HomeManager.set_tier(10)
	EventBus.home_upgraded.emit(3,10)
	await t.frames(6)
	var banners: Array = _dress().filter(func(node):return str(node.params.get("prop",""))=="royal_banner" and is_instance_valid(node.prop))
	t.check("native_ten_has_two_royal_banners",banners.size()==2)
	if not banners.is_empty():await _focus(t,banners[0].prop,0.5)
	await t.capture("farm_t10")
	GameManager.day = 7
	GameManager.hour = 13
	EventBus.day_started.emit(7,GameManager.season)
	SocialManager.flush()
	await t.frames(4)
	var bunting: Array = _dress().filter(func(node):return str(node.params.get("prop",""))=="bunting_x" and is_instance_valid(node.prop))
	t.check("native_real_festival_flag_bunting",bunting.size()==2 and str(SocialManager.festival_active())=="blomsterfesten")
	if not bunting.is_empty():await _focus(t,bunting[0].prop)
	await t.capture("farm_festival_bunting")
	await _native_season(t,&"vinter",12,&"sne")
	await _measure_fx(t)
	await t.go_menu()

func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size()/2])
func _measure_fx(t) -> void:
	var emitter := _fx().leaves
	var timing := Perf.uncap()
	var pairs: Array = []
	var deltas: Array = []
	for _round in 3:
		emitter.emitting = false
		emitter.visible = false
		emitter.process_mode = Node.PROCESS_MODE_DISABLED
		await t.seconds(0.25)
		var baseline: Dictionary = await Perf.measure_frames(t.tree,1.0)
		emitter.process_mode = Node.PROCESS_MODE_INHERIT
		emitter.emitting = true
		emitter.visible = true
		emitter.restart()
		await t.seconds(0.25)
		var enabled: Dictionary = await Perf.measure_frames(t.tree,1.0)
		pairs.append({"baseline":baseline,"enabled":enabled,"delta_ms":enabled.ms-baseline.ms})
		deltas.append(enabled.ms-baseline.ms)
	var delta := _median(deltas)
	Perf.restore_cap(timing)
	var path := "res://docs/qa/mechanics/farm/seasonal-performance.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var handle := FileAccess.open(path,FileAccess.WRITE)
	handle.store_string(JSON.stringify({"method":"median delta of three paired one-second native frame-time means after 0.25 second settling; vsync/fps caps disabled; emitter disabled versus 40 winter particles; whole-engine wall frame time, not isolated CPU or GPU time","pairs":pairs,"median_delta_ms":delta,"cap_ms":0.5,"particles":emitter.amount,"engine":Engine.get_version_info()},"  "))
	handle.close()
	t.check("fx_cost_under_half_ms",t.perf_ok("fx_cost_under_half_ms",delta,0.5),str(delta)+" ms median incremental frame time; "+str(pairs))
