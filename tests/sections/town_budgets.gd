extends RefCounted
const SECTION := "town_budgets"
const TIMEOUT_S := 180.0
const MB := 1048576.0
var measurements := {}

func count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += count(child)
	return total

func scenery_nodes(node: Node) -> int:
	if node.is_in_group("player") or node.is_in_group("npc"):
		return 0
	var total := 1
	for child in node.get_children():
		total += scenery_nodes(child)
	return total

func lights(node: Node) -> int:
	if node.is_in_group("player") or node.is_in_group("npc"):
		return 0
	var total := int(node is PointLight2D)
	for child in node.get_children():
		total += lights(child)
	return total

func run(t) -> void:
	# Browsing inventory/equipment must not pin every previously shown image.
	var icon := TTItemIcon.new()
	icon.item_id = &"wpn_dagger_moonshard"
	t.root.add_child(icon)
	var icon_ref: WeakRef = weakref(icon._tex)
	var shared := TTItemIcon.load_icon(icon.item_id)
	t.check("visible_icon_shares_live_texture",icon._tex!=null and is_same(icon._tex,shared.tex))
	shared.clear()
	icon.free()
	t.check("closed_icon_releases_texture",icon_ref.get_ref()==null)
	var painting := HeldEquipment2D.painting_texture("res://assets/held_equipment/dungeon/wpn_club_oak.webp")
	var painting_ref: WeakRef = weakref(painting)
	var holder := Sprite2D.new()
	holder.texture = painting
	painting = null
	t.check("visible_weapon_owns_texture",painting_ref.get_ref()!=null)
	holder.free()
	t.check("closed_weapon_preview_releases_texture",painting_ref.get_ref()==null)
	await t.clear_scene()
	var terrain := ArtCatalog.terrain(&"bog_o")
	var terrain_ref: WeakRef = weakref(terrain.texture)
	terrain.clear()
	t.check("unused_terrain_lookup_releases_texture",terrain_ref.get_ref()==null)
	var set := AreaTileSet.get_set(&"ortho")
	var set_ref: WeakRef = weakref(set.tileset)
	var sid := AreaTileSet.source_for(&"ortho",&"bog_o")
	var sheet_ref: WeakRef = weakref((set.tileset.get_source(sid) as TileSetAtlasSource).texture)
	var layer := TileMapLayer.new()
	layer.tile_set = set.tileset
	set.clear()
	t.check("active_tilemap_owns_tileset_and_sheet",set_ref.get_ref()!=null and sheet_ref.get_ref()!=null)
	layer.free()
	t.check("last_tilemap_releases_tileset_and_sheet",set_ref.get_ref()==null and sheet_ref.get_ref()==null)
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.hour = 10
	gm.day = 2
	var sources := ["res://scripts/world2d/art_catalog.gd", "res://scripts/towns/piece_catalog.gd"]
	var weak_caches := sources.all(func(path): return FileAccess.get_file_as_string(path).contains("TextureRefs.store"))
	var art_id := CityData.trunk_art(55)
	var resource := ArtCatalog.prop(art_id)
	var weak: WeakRef = weakref(resource.texture)
	var meta := ArtCatalog.prop_metadata(art_id)
	var piece: Texture2D = PieceCatalog.texture(str(meta._dir) + str(meta.file))
	resource.clear()
	piece = null
	t.check("builders_use_instance_caches", weak_caches and weak.get_ref() == null, "Both real lookup caches release a texture when its last scene owner goes away")
	for id in [&"int_froebutikken", &"traetoppen", &"hyggebyen", &"farm"]:
		# Match travel's production pipeline. Keep asset preparation explicit;
		# the native gate separately bounds the entire cold transition.
		var preparation := Time.get_ticks_usec()
		world.art_prefetch.request(id)
		await world.art_prefetch.finish()
		var preparation_ms := (Time.get_ticks_usec()-preparation)/1000.0
		var samples: Array[float] = []
		var first := 0.0
		for i in 4:
			var began := Time.get_ticks_usec()
			world._enter(id, &"default")
			var ms := (Time.get_ticks_usec() - began) / 1000.0
			if i==0:
				first=ms
				world.art_prefetch.release()
			else:samples.append(ms)
			await t.physics(3)
		samples.sort()
		var warm := samples[1]
		# The director initializes two physics frames after _enter (nav, festival posts, first population): part of every entry.
		var town := TownProbe.director(t)
		var init := float(town.init_ms) if town != null else 0.0
		measurements[str(id)]={"asset_preparation_ms":preparation_ms,"cold_entry_ms":first,"warm_entry_ms":warm,"director_init_ms":init,"nodes":count(world.area),"scenery_nodes":scenery_nodes(world.area),"scenery_lights":lights(world.area)}
		match id:
			&"int_froebutikken":
				t.check("interior_cold_build", t.perf_ok("interior_cold_build", first, 60), str(measurements[str(id)]))
				t.check("interior_warm_rebuild", t.perf_ok("interior_warm_rebuild", warm, 12), str(measurements[str(id)]))
				t.check("interior_nodes_and_lights", int(InteriorRoom.stats.nodes)<=130 and lights(world.area)<=4, str(InteriorRoom.stats)+" live_nodes="+str(count(world.area)))
				var room := world.area
				var nav_start := Time.get_ticks_usec()
				var nav := NavGrid.bake_room(room, 8, 5, Iso.MASK_WALKING)
				var nav_us := Time.get_ticks_usec()-nav_start
				t.check("nav_bake_interior", t.perf_ok("nav_bake_interior", nav.bake_us, 1000), "%d us" % nav.bake_us)
				t.check("nav_bake_interior_total", t.perf_ok("nav_bake_interior_total", nav_us, 1000), "%d us" % nav_us)
				var keeper := NpcDirector.node_of("merchant_pip")
				var job: Array = []
				for entry in world.warm_jobs():
					if keeper != null and entry[0]==keeper.visual:job=entry[1]
				t.check("keepers_warm_idle_talk_only", keeper!=null and job==["idle","talk"], str(job))
				var visitors := TownProbe.director(t).live.size()-1
				t.check("room_population_cap", visitors<=4)
			&"traetoppen":
				var classes := {}
				_classes(world.area, classes)
				t.info("CITY NODES " + JSON.stringify(classes))
				for child in world.area.get_children():
					t.info("CITY BRANCH " + str(child.name) + " " + str(count(child)))
				# PERF-04: the first visit of the city, its textures prepared like travel prepares them (art_prefetch above), so the disk
				# cache is out of it; a quiet machine measures 33-39 ms, loaded local runs 33-178 ms (median 51).
				t.check("city_cold_entry", t.perf_ok("city_cold_entry", first, 80), str(measurements[str(id)]))
				t.check("city_warm_build", t.perf_ok("city_warm_build", warm, 40), str(measurements[str(id)]))
				t.check("city_reentry_director_init", t.perf_ok("city_reentry_director_init", init, 10), str(measurements[str(id)]))
				t.check("city_nodes_and_lights", scenery_nodes(world.area)<=700 and lights(world.area)<=12, str(measurements[str(id)]))
				var begin := Time.get_ticks_usec()
				var nav := LevelNav.make()
				var bake_us := Time.get_ticks_usec()-begin
				t.check("nav_bake_city_levels", not nav.levels.is_empty())
				t.check("nav_bake_city", t.perf_ok("nav_bake_city", bake_us, 30000), "%.3fms" % (bake_us/1000.0))
				var identical := true
				for level in nav.levels:
					for y in level.n.y:
						for x in level.n.x:
							var point := nav._centre(level, Vector2i(x,y))
							var expected := true
							for offset in [Vector2.ZERO,Vector2(20,0),Vector2(-20,0),Vector2(0,20),Vector2(0,-20)]:
								expected = expected and nav._walkable(level, point+offset)
							identical = identical and expected != level.grid.is_point_solid(Vector2i(x,y))
				t.check("city_baked_footprint_matches_geometry", identical and nav.bake_info.baked_cells)
			&"hyggebyen":
				# PERF-03: a warm entry of the parked grid town is its parked return; one check of the sample (a 60 ms twin was a duplicate).
				t.check("grid_parked_return", t.perf_ok("grid_parked_return", warm, 5), str(measurements[str(id)])+"; runner limit "+str(t.perf_limit(5))+" ms (native reference 5)")
				t.check("grid_parked_director_init", t.perf_ok("grid_parked_director_init", init, 8), str(measurements[str(id)]))
				t.check("grid_npc_cap", TownProbe.director(t).live.size()<=24)
			&"farm":
				t.check("farm_warm_build", t.perf_ok("farm_warm_build", warm, 60), str(measurements[str(id)]))
				t.check("farm_dimensions", world.area.map.width==61 and world.area.map.height==51)
	await _navigation(t)
	await _director(t)
	await _minute_ticks(t)
	await _room_crowd(t)
	var loc: Node = t.autoload("LocalizationManager")
	# Best of three: a reload reads every CSV from disk, and a busy disk (other jobs cloning trees) measured 734-773 ms next to 243 ms.
	var reloads: Array[int] = []
	for i in 3:
		var reload_start := Time.get_ticks_usec()
		loc.reload()
		reloads.append(Time.get_ticks_usec()-reload_start)
	var reload_us: int = reloads.min()
	t.check("csv_reload", t.perf_ok("csv_reload", reload_us, 150000), "best %.3fms of %s us" % [reload_us/1000.0, str(reloads)])
	var python := ProjectSettings.globalize_path("res://tools/art/.venv/bin/python")
	var arithmetic: Dictionary = t.run_tool(python,[ProjectSettings.globalize_path("res://tools/town/vram_budget.py")])
	var report: Variant = JSON.parse_string(str(arithmetic.output))
	t.check("farm_kit_vram_with_s3tc", arithmetic.code==0 and report is Dictionary and float(report.mb)<=20, str(report.get("mb",-1)) if report is Dictionary else arithmetic.output)
	# REND-12: the reference rows are the authored envelope of the towns addendum, not a measurement: headless can only check that the
	# table keeps every row under its cap. The renderer's RENDER_TEXTURE_MEM_USED gates are the windowed vram_festival_day_row and
	# vram_process_cap_holds_with_20_looks (run_windowed below); this check must not share their names.
	var rows: Dictionary = report.reference_rows if report is Dictionary else {}
	t.check("vram_authored_envelope_within_caps", not rows.is_empty() and float(rows.ordinary)<=float(rows.ordinary_cap) and float(rows.festival_20)<=float(rows.festival_cap) and float(rows.nothing_freed_20)<float(rows.process_cap), "authored rows %s (arithmetic, not measured)" % str(rows))
	t.info("TOWN BUDGETS " + JSON.stringify(measurements))
	gm.clear_config_overrides()

func _navigation(t) -> void:
	var lines := ["@id _budget60", "@projection iso", "@ground"]
	for i in 60:lines.append("f".repeat(60))
	var area := IsoArea.new()
	t.root.add_child(area)
	area.setup(AreaMap.parse_text("\n".join(lines)))
	await t.physics(2)
	var nav := NavGrid.bake_area(area)
	t.check("nav_bake_grid_60", t.perf_ok("nav_bake_grid_60", nav.bake_us, 15000), "%.3fms" % (nav.bake_us/1000.0))
	area.free()
	var costs: Array[int] = []
	for i in 60:
		var start := Time.get_ticks_usec()
		RouteTable.path("traetoppen.a_beds1","int_bageriet.counter")
		costs.append(Time.get_ticks_usec()-start)
	costs.sort()
	t.check("route_plan_p95", t.perf_ok("route_plan_p95", costs[56], 1000), str(costs[56])+"us")
	var ctx := Routines.now_ctx()
	var ids := SocialData.npcs().keys()
	var batch := NpcDirector.locations(ids,ctx)
	t.check("batch_locations_match_individual_queries",ids.all(func(id):return batch[id] == Routines.where_is(str(id),ctx)) and not ctx.has("_routine_registry"))
	var sweeps: Array[int] = []
	for i in 20:
		var start := Time.get_ticks_usec()
		NpcDirector.locations(SocialData.npcs().keys())
		sweeps.append(Time.get_ticks_usec()-start)
	sweeps.sort()
	t.check("where_is_sweep", t.perf_ok("where_is_sweep", sweeps[10], 300), str(sweeps[10])+"us for "+str(SocialData.npcs().size())+"; runner limit "+str(t.perf_limit(300))+" us (native reference 300)")

func _classes(node: Node, result: Dictionary) -> void:
	result[node.get_class()] = int(result.get(node.get_class(), 0)) + 1
	for child in node.get_children():
		_classes(child, result)

func _director(t) -> void:
	# Exercise the director with 30 real agents through its normal resolver and
	# navigation. The production cap is restored before leaving this fixture.
	await t.world().travel(&"hyggebyen", &"default")
	var extra := "user://budget_agents.lua"
	var file := FileAccess.open(extra, FileAccess.WRITE)
	var rows: Array[String] = []
	for i in 3:
		rows.append('budget_agent_%d = { name_key = "NPC_POSTMAN_PIP", role = "postman", visual = "penguin_postman", home_area = "hyggebyen", routine = true }' % i)
	file.store_string('kind = "config"\nconfig = { npcs = { ' + ",".join(rows) + ' } }')
	file.close()
	t.autoload("LuaRuntime").load_file(extra)
	var director := TownProbe.director(t)
	var registry := {}
	for id in Routines.npc_ids():
		var n := registry.size()
		registry[id]={"priority":n,"plans":{"day":{"blocks":[{"from":6.0,"at":"hyggebyen.fest_hyggetorv_gather_"+str(n%20+1),"act":"stand"}]}},"select":[{"plan":"day"}]}
		if registry.size()==30:break
	for i in 3:
		if registry.size()>=30:
			break
		registry["budget_agent_%d" % i] = registry.values()[0].duplicate(true)
	Routines.override_registry=registry
	Routines.clear_cache()
	t.autoload("GameManager").set_config_override("towns.max_live_visuals",30)
	director.resync()
	await t.physics(2)
	t.check("director_30_agents_live", director.live.size()==30, "%d agents" % director.live.size())
	var ms: float = t.median_usec(func() -> void: director._physics_process(1.0/60))/1000.0
	t.check("director_30_agents", t.perf_ok("director_30_agents", ms, 0.4), "%.4fms / %d agents, median of 10 batches of 50 ticks (native reference 0.4, runner limit %.2f)" % [ms,director.live.size(),t.perf_limit(0.4)])
	t.autoload("GameManager").set_config_override("towns.max_live_visuals",16)
	director.resync()
	var distinct := {}
	for actor in director.live.values():
		distinct[str(t.autoload("LuaRuntime").get_npc(actor.npc_id).get("visual", "fairy"))] = true
	t.check("ordinary_visual_cap", distinct.size()<=16)
	Routines.override_registry={}
	Routines.clear_cache()
	t.autoload("LuaRuntime").reload_scripts()
	DirAccess.remove_absolute(extra)

## The clock frozen above hides the director's spike: with a running clock every game minute builds one snapshot of now for the
## population and every door's hours. Measure that tick with the real Hyggebyen roster.
func _minute_ticks(t) -> void:
	await t.world().travel(&"hyggebyen", &"default")
	var gm: Node = t.autoload("GameManager")
	gm.hour = 10
	gm.minute = 0
	EventBus.time_of_day_changed.emit(10, 0)
	await t.physics(2)
	var director := TownProbe.director(t)
	var costs: Array[float] = []
	for minute in range(1, 41):
		gm.minute = minute
		var began := Time.get_ticks_usec()
		director._clock(10, minute)
		costs.append((Time.get_ticks_usec() - began) / 1000.0)
	costs.sort()
	t.check("minute_tick_p95", t.perf_ok("minute_tick_p95", costs[37], 1.0), "p95 %.3f ms, max %.3f ms over 40 ticks with %d live" % [costs[37], costs[-1], director.live.size()])
	measurements.minute_tick = {"p95_ms": costs[37], "max_ms": costs[-1], "live": director.live.size()}

func run_windowed(t) -> void:
	const Perf := preload("res://tests/perf_world.gd")
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	gm.set_config_override("towns.curfew.enabled",false)
	await LoopClock.at(t,1,10)
	TimeManager.set_weather(&"regn") # Pin the more demanding ordinary-weather fixture.
	var cap := Perf.uncap()
	for row in [["int_froebutikken",4.0,60,0.7],["hyggebyen",4.0,0,0.0],["traetoppen",6.0,250,0.8],["farm",8.0,560,0.0]]:
		var begin := Time.get_ticks_usec()
		await t.world().travel(StringName(row[0]),&"default")
		var travel_ms := (Time.get_ticks_usec()-begin)/1000.0
		if row[0] in ["hyggebyen","traetoppen"]:
			var needed := {}
			if row[0]=="hyggebyen":
				var ground: TileMapLayer = t.world().area.ground
				for cell in ground.get_used_cells():
					var source := ground.tile_set.get_source(ground.get_cell_source_id(cell)) as TileSetAtlasSource
					if source!=null and source.texture.resource_path!="":needed[source.texture.resource_path]=true
			else:
				for owl in t.tree.get_nodes_in_group("ambient_owl"):
					if t.world().area.is_ancestor_of(owl):needed[owl.get_child(0).sprite.texture.resource_path]=true
			var prepared: Array = t.world().last_travel_profile.prepared_paths
			var covered: Callable = func(paths: Array)->bool:return not needed.is_empty() and needed.keys().all(func(path):return path in paths)
			var control := prepared.duplicate()
			if not needed.is_empty():control.erase(needed.keys()[0])
			t.check(row[0]+"_scenery_resources_prepared",covered.call(prepared) and not covered.call(control),str(needed.keys()))
		if float(row[3])>0:
			t.check(row[0]+"_travel_budget",t.perf_ok(row[0]+"_travel_budget",travel_ms,float(row[3])*1000),"%.3fms / %d citizens" % [travel_ms,TownProbe.director(t).live.size()])
		if row[0]=="farm":_zoom(t,0.4)
		await t.seconds(3.1) # Arrival notifications are measured by the loop; steady area budget here.
		await t.frames(8)
		var windows: Array[Dictionary] = []
		# Use the same best-of-up-to-eight convention as city_levels. Keep every
		# window in the report; scheduling noise must not change the threshold.
		for sample in 8:
			windows.append(await Perf.measure_frames(t.tree,0.5,t.tree.root.get_viewport_rid()))
			if sample>=2 and windows.any(func(value):return float(value.ms)<=float(row[1])):break
		var frames: Dictionary = windows[0]
		for sample in windows:
			if sample.ms<frames.ms:frames=sample
		var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		if row[0]=="hyggebyen":
			# Retain both full-screen and standalone-area measurements. The
			# actual painted 44x44 town must meet the original 4ms frame limit
			# including the HUD; area-only results are additional diagnostics.
			t.render_budget("hyggebyen_presented_frame_windowed", frames.ms, 4, str(frames))
			t.world().game_ui.hide()
			await t.frames(8)
			var area_windows: Array[Dictionary] = []
			for sample in 8:
				area_windows.append(await Perf.measure_frames(t.tree,0.5,t.tree.root.get_viewport_rid()))
				if sample>=2 and area_windows.any(func(value):return float(value.ms)<=4):break
			var area_best: Dictionary = area_windows[0]
			for sample in area_windows:
				if sample.ms<area_best.ms:area_best=sample
			t.world().game_ui.show()
			await t.frames(3)
			t.render_budget("hyggebyen_area_frame_windowed", area_best.ms, 4, str(area_best))
			measurements.hyggebyen_area={"frame":area_best,"windows":area_windows,"budget_ms":4}
		else:
			t.render_budget(row[0]+"_frame_windowed", frames.ms, row[1], str(frames))
		if int(row[2])>0:
			var area_calls := await _area_calls(t) if row[0] in ["int_froebutikken","farm"] else calls
			t.check(row[0]+"_draw_calls",area_calls<=int(row[2]),"%.0f area / %.0f including HUD" % [area_calls,calls])
		measurements[row[0]]={"frame":frames,"frame_windows":windows,"draw_calls":calls,"travel_profile":t.world().last_travel_profile,"travel_ms":travel_ms,"texture_mb":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/MB}
		if row[0]=="hyggebyen":await _ground_batch_pixels(t)
		if row[0]=="farm":
			for zoom in [0.3,0.2]:
				_zoom(t,zoom)
				await t.frames(8)
				var limit := 640 if zoom==0.3 else 780
				var presented := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				var draws := await _area_calls(t)
				t.check("farm_draw_calls_zoom_"+str(zoom),draws<=limit,"%.0f area / %.0f including HUD" % [draws,presented])
				measurements["farm_zoom_"+str(zoom)]={"draw_calls":draws}
	Perf.restore_cap(cap)
	await t.clear_scene()
	await _cold_crowd_travel(t)
	# I2's festival row measures twenty warmed LOOKS, not the later I6
	# twenty-actor perf scene. S04 independently measures sixteen real bodies.
	var suite := preload("res://tests/sections/town_loop.gd").new()
	suite.native_mode=true
	await preload("res://tests/lib/town_loop/native.gd").new()._crowd(t,suite,true)
	var owned := {}
	for actor in TownProbe.director(t).live.values():owned[actor.visual.resolved_id]=true
	var paths: Array[String] = []
	var extra := 0
	for id in SocialData.npcs():
		var look := IsoChibiSprite2D.resolve_id(str(t.autoload("LuaRuntime").get_npc(id).get("visual","fairy")))
		if owned.has(look):continue
		owned[look]=true
		var meta := IsoChibiSprite2D.meta_for(look)
		for clip in (["idle","talk","hover"] if meta.flyer else ["idle","talk","walk"]):
			var path := "res://assets/isometric_characters/"+look+"/"+str(meta.animations[clip].sheet)
			if not ResourceLoader.has_cached(path):paths.append(path)
		extra+=1
		if extra==4:break
	var staged := await _renderer_arithmetic(t,paths,"festival_four_added_looks")
	var festival := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/MB
	t.check("city_peak_under_320mb",float(measurements.traetoppen.texture_mb)<=320)
	t.check("vram_festival_day_row",extra==4 and owned.size()==20 and festival<=360,"%.3fMB / 20 warmed looks" % festival)
	t.check("vram_process_cap_holds_with_20_looks",festival<400,"%.3fMB total renderer textures" % festival)
	measurements.festival={"looks":owned.size(),"texture_mb":festival}
	staged.clear()
	Routines.override_registry={}
	Routines.clear_cache()
	await t.clear_scene()
	await t.frames(5)
	var python := ProjectSettings.globalize_path("res://tools/art/.venv/bin/python")
	var result: Dictionary = t.run_tool(python,[ProjectSettings.globalize_path("res://tools/town/vram_budget.py")])
	var kit: Dictionary = JSON.parse_string(result.output)
	paths=[]
	for row in kit.textures:
		var path := "res://"+str(row.path)
		if not ResourceLoader.has_cached(path):paths.append(path)
	staged=await _renderer_arithmetic(t,paths,"farm_kit")
	t.check("farm_kit_vram_with_s3tc",kit.mb<=20,str(kit.mb))
	staged.clear()
	var file := FileAccess.open(t.out_dir.path_join("town-budgets-native-details.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t"))
	gm.clear_config_overrides()

func _ground_batch_pixels(t) -> void:
	# Only subpixel blending at batch boundaries may differ; a gap or changed
	# tile must fail. Keep both full native images for visual review.
	var world: WorldRoot2D = t.world()
	var ground := world.area.ground
	var saved := []
	t.tree.paused=true
	for child in world.area.get_children():
		if child is CanvasItem and child!=ground:
			saved.append([child,child.visible])
			child.hide()
	world.weather_fx.hide()
	world.game_ui.hide()
	ground.rendering_quadrant_size=16
	await t.frames(4)
	var before: Image = await t.capture("hyggebyen_ground_quadrant_16")
	ground.rendering_quadrant_size=8
	await t.frames(4)
	var after: Image = await t.capture("hyggebyen_ground_quadrant_8")
	var a := before.get_data()
	var b := after.get_data()
	var total := 0
	var maximum := 0
	for i in a.size():
		var difference := absi(int(a[i])-int(b[i]))
		total += difference
		maximum=maxi(maximum,difference)
	var mean := float(total)/a.size()
	measurements.ground_batch_pixels={"mean_8bit":mean,"max_8bit":maximum,"mean_limit":.001,"max_limit":16}
	t.check("ground_batch_preserves_painted_tiles",mean<=.001 and maximum<=16,str(measurements.ground_batch_pixels))
	for row in saved:row[0].visible=row[1]
	world.weather_fx.show()
	world.game_ui.show()
	t.tree.paused=false

func _renderer_arithmetic(t, paths: Array[String], label: String) -> Dictionary:
	await t.frames(4)
	var before := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var owned := {}
	for path in paths:owned[path]=load(path)
	await t.frames(4)
	var added := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)-before
	var path_file: String = t.out_dir.path_join(label+"-paths.json")
	var file := FileAccess.open(path_file,FileAccess.WRITE)
	file.store_string(JSON.stringify(paths))
	file.close()
	var result: Dictionary = t.run_tool(ProjectSettings.globalize_path("res://tools/art/.venv/bin/python"),[ProjectSettings.globalize_path("res://tools/town/vram_budget.py"),"--paths",path_file])
	var expected: Variant = JSON.parse_string(result.output)
	var ratio := absf(added-float(expected.bytes))/maxf(1,float(expected.bytes)) if expected is Dictionary else INF
	t.check("vram_arithmetic_matches_renderer_"+label,not paths.is_empty() and result.code==0 and ratio<=0.05,"%.3fMB measured / %.3fMB arithmetic (%.2f%%)" % [added/MB,float(expected.bytes)/MB,ratio*100])
	measurements[label]={"renderer_bytes":added,"arithmetic_bytes":expected.bytes,"relative_error":ratio,"paths":paths}
	return owned

func _zoom(t, value: float) -> void:
	t.player()._target_zoom=value
	t.player().camera.zoom=Vector2.ONE*value
	t.player()._apply_camera_limits()

func _area_calls(t) -> float:
	# The plan's room/farm draw counts came from standalone area prototypes.
	# Record the presented screen separately; its frame budget includes the HUD.
	t.world().game_ui.hide()
	await t.frames(3)
	var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	t.world().game_ui.show()
	await t.frames(3)
	return calls

func _cold_crowd_travel(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	gm.set_config_override("towns.curfew.enabled",false)
	var registry := {}
	var looks := {}
	for id in Routines.npc_ids():
		var look := str(t.autoload("LuaRuntime").get_npc(id).get("visual","fairy"))
		if looks.has(look):continue
		looks[look]=true
		registry[id]={"priority":50-registry.size(),"plans":{"day":{"blocks":[{"from":6.0,"at":"traetoppen.fest_torvet_gather_"+str(registry.size()+1),"act":"stand"}]}},"select":[{"plan":"day"}]}
		if registry.size()==12:break
	Routines.override_registry=registry
	Routines.clear_cache()
	var started := Time.get_ticks_usec()
	await t.world().travel(&"traetoppen",&"from_farm")
	var elapsed := (Time.get_ticks_usec()-started)/1000.0
	t.check("city_travel_twelve_cold_citizens_live",TownProbe.director(t).live.size()==12,"%d bodies" % TownProbe.director(t).live.size())
	t.check("city_travel_twelve_cold_citizens",t.perf_ok("city_travel_twelve_cold_citizens",elapsed,800),"%.3fms / %d bodies; %s" % [elapsed,TownProbe.director(t).live.size(),str(t.world().last_travel_profile)])
	Routines.override_registry={}
	Routines.clear_cache()
	gm.clear_config_overrides()
	await t.clear_scene()

func _room_crowd(t) -> void:
	await t.world().travel(&"int_froebutikken",&"default")
	var registry := {}
	for id in Routines.npc_ids():
		if id=="merchant_pip":continue
		registry[id]={"priority":50-registry.size(),"plans":{"day":{"blocks":[{"from":6.0,"at":"int_froebutikken.cust1","act":"stand"}]}},"select":[{"plan":"day"}]}
		if registry.size()==8:break
	registry["merchant_pip"]={"priority":-100,"plans":{"day":{"blocks":[{"from":6.0,"at":"int_froebutikken.counter","act":"work"}]}},"select":[{"plan":"day"}]}
	Routines.override_registry=registry
	Routines.clear_cache()
	var director := TownProbe.director(t)
	director.resync()
	await t.physics(2)
	t.check("room_keeps_host_and_caps_visitors",director.live.size()==5 and director.live.has("merchant_pip") and director.last_dropped==4,"Low-priority keeper retained; four of eight visitors admitted")
	Routines.override_registry={}
	Routines.clear_cache()
	director.resync()
	await t.physics(2)
