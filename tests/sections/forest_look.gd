extends RefCounted
const SECTION := "forest_look"
const TIMEOUT_S := 180.0
const Perf := preload("res://tests/perf_world.gd")
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _fixture() -> AreaMap:
	var ground: Array[String] = []
	var objects: Array[String] = []
	for y in 41:
		ground.append("#".repeat(40) if y in [0,40] else "#"+"m".repeat(38)+"#")
		objects.append(".".repeat(40))
	var text := "@id _forest_look\n@projection ortho\n@ambient forest\n@theme forest\n@zone dark_forest\n@floor 2\n@depth 2\n@zoom 0.4\n@prop S crown_s_a\n@prop M crown_m_a\n@prop L crown_l_a\n@prop G glow_mushroom_cluster\n@prop R rock_grey\n@prop B bush_eyes_a\n@marker D forest_dress fireflies=14 mist=2 unshaded=1\n@marker K hulen_keeper npc=mapseller_natteblik\n@marker C chest tier=trae\n@marker U runestone id=rune_fixture\n@marker H warp to=moerkeskoven_f1 spawn=default label=LOOK_HULEN_NAME prop=cave_ring r=0\n@ground\n"+"\n".join(ground)+"\n@objects\n"+"\n".join(objects)
	var map := AreaMap.parse_text(text)
	for x in range(5,35): map.set_ground(Vector2i(x,20),"p")
	for y in range(6,36): map.set_ground(Vector2i(20,y),"x")
	for y in range(10,16):
		for x in range(25,32):
			if Vector2((x-28)/3.0,(y-13)/2.0).length_squared() <= 1: map.set_ground(Vector2i(x,y),"~")
	for at in [Vector2i(9,14),Vector2i(12,26),Vector2i(28,29),Vector2i(30,18)]:
		map.set_object(at,"G")
		for dy in range(-1,2):
			for dx in range(-1,2): map.set_ground(at+Vector2i(dx,dy),"g")
	for row in [["S",3,7],["S",9,4],["S",34,4],["S",36,33],["M",5,31],["M",32,36],["M",35,13],["L",2,17],["L",2,25],["L",10,37],["L",17,38],["L",27,3],["L",36,24],["L",19,2],["R",14,17],["R",23,28],["R",7,25],["B",12,11],["B",33,29],["B",24,8],["D",6,6],["K",31,23],["H",31,25],["C",24,21],["U",17,18],["@",20,20]]:
		map.set_object(Vector2i(row[1],row[2]),row[0])
	return map
func _run(t,native: bool) -> void:
	var config := LuaData.dict(Svc.lua_config("forest_look",{}))
	t.check("config_numbers_present",config.lantern.energy == .1 and config.lantern.color == "ffe9a8" and config.fireflies.cpu_particles == 40 and config.fireflies.per_1630_cells == 14 and config.mist.alpha == .06 and config.light_budget.map_lights_overlapping_max == 12 and config.light_budget.in_view_max == 16)
	t.check("lantern_ring_profile",is_equal_approx(ForestDress.lantern_texture().gradient.sample(.6).a,.31))
	for kind in ["forest_dress","hulen_keeper"]: t.check("registered_"+kind,IsoArea.resolve_handler(kind).mode == "create_marker")
	for key in ["LOOK_NATTEBLIK_SLEEPS","LOOK_MOONPOND_FISHING","LOOK_HULEN_NAME","LOOK_MOON_POND_NAME"]:
		t.check("localized_"+key,TranslationServer.translate(key) != key)
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var gm: Node = t.autoload("GameManager")
	var wardrobe: Node = t.autoload("WardrobeManager")
	gm.hour = 12
	gm.set_config_override("time.minutes_per_real_second",0.0)
	var ordinary_material: Material = world.player.visual.sprite.material
	t.check("farm_stays_ordinary",ForestDress.attach(world.area) == null and (not ordinary_material is ShaderMaterial or not "unshaded" in ordinary_material.shader.code))
	var fixture := _fixture()
	for character in fixture.props:
		var id: String = str(fixture.props[character].prop)
		var art_id := StringName(str(GameData.prop_def(id).get("art",id)))
		t.check("fixture_prop_%s_is_real" % character,ArtCatalog.has_real_prop(art_id) and bool(ArtCatalog.prop(art_id).get("real",false)),str(art_id))
	WorldRoot2D.register_map(&"_forest_look",fixture)
	await world.travel(&"_forest_look",&"default")
	await t.frames(3)
	var area := world.area
	var look := area.get_node_or_null("ForestLook") as ForestDress
	t.check("fixture_map_builds_with_every_marker",look != null and area.map.errors.is_empty() and area.prop_nodes.size() >= 24 and area.handled_count("chest") == 1 and area.handled_count("runestone") == 1,str(area.map.errors))
	if look == null: return
	t.check("attach_and_marker_are_equivalent",ForestDress.attach(area) == look and area.get_children().filter(func(node):return node is ForestDress).size() == 1)
	t.check("firefly_field_cost_free",look.fireflies.amount == 40 and look.mist.size() == 2 and look.fireflies.get_children().is_empty() and look.fireflies.material == Glow.additive_material())
	var original_grid := area.map.ground.duplicate()
	var masks_match := true
	for feature in SoftGround.FEATURES:
		var mask: Image = look.soft_ground.masks[feature]
		for y in area.map.height:
			for x in area.map.width:
				masks_match = masks_match and (mask.get_pixel(x,y).r > .5) == (area.map.ground_at(Vector2i(x,y)) in SoftGround.FEATURES[feature].chars)
	t.check("soft_ground_masks_follow_cells",masks_match and look.soft_ground.sprites.size() == 3)
	# each decal covers its feature's cells plus SoftGround.MARGIN, not the whole map, and keeps the painting anchored to the map corner (review REND-07)
	var cell_px := Vector2(Iso.ORTHO_W,Iso.ORTHO_H)
	var corner: Vector2 = area.ground_fx.to_local(area.cell_to_global(Vector2i.ZERO))-cell_px*.5
	var crops_ok := true
	var smaller := 0
	var crops := []
	for feature in SoftGround.FEATURES:
		var picture: Sprite2D = null
		for sprite in look.soft_ground.sprites:
			if sprite.name == str(feature).capitalize()+"Decal": picture = sprite
		if picture == null: continue
		var low := Vector2i(area.map.width,area.map.height)
		var high := Vector2i(-1,-1)
		for y in area.map.height:
			for x in area.map.width:
				if area.map.ground_at(Vector2i(x,y)) in SoftGround.FEATURES[feature].chars:
					low = low.min(Vector2i(x,y))
					high = high.max(Vector2i(x,y))
		var want := Rect2i(low-Vector2i.ONE*SoftGround.MARGIN,high-low+Vector2i.ONE*(1+2*SoftGround.MARGIN)).intersection(Rect2i(0,0,area.map.width,area.map.height))
		var got := Rect2((picture.position-corner)/cell_px,picture.texture.get_size()/8.0)
		var material := picture.material as ShaderMaterial
		var paint: Texture2D = material.get_shader_parameter("paint")
		var anchored: bool = ((material.get_shader_parameter("origin") as Vector2)*paint.get_size()).is_equal_approx(Vector2(want.position)*cell_px)
		crops_ok = crops_ok and got.is_equal_approx(Rect2(want)) and anchored
		smaller += 1 if want.get_area() < area.map.width*area.map.height else 0
		crops.append("%s %s" % [feature,want])
	t.check("soft_ground_decals_cover_only_their_features",crops_ok and smaller >= 1,"decal rects in cells: %s (map %dx%d)" % [crops,area.map.width,area.map.height])
	t.check("soft_ground_keeps_cells_walkable",area.map.ground == original_grid and area.is_walkable(Vector2i(20,20)) and not area.is_walkable(Vector2i(28,13)))
	await t.physics(2)
	var point := PhysicsPointQueryParameters2D.new()
	point.position = area.cell_to_global(Vector2i(28,13))
	point.collision_mask = Iso.LAYER_GROUND_BLOCK
	t.check("pond_blocks_walkers",not area.get_world_2d().direct_space_state.intersect_point(point).is_empty())
	var actor_light := world.player.get_node_or_null("ForestActorLight") as ForestActorLight
	var actual_body: Material = world.player.visual.sprite.material
	var body_lit: bool = "unshaded" in actual_body.shader.code if actual_body is ShaderMaterial else actual_body is CanvasItemMaterial and actual_body.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED
	t.check("wardrobe_material_identity_preserved",body_lit and actor_light != null and world.player.outfit_layers.occluder.material == world.player.outfit_layers.mask_material)
	wardrobe.equip("dress_sun_cream")
	await t.frames(2)
	actor_light.refresh()
	world.player.visual.play_loop(&"walk")
	world.player.visual._frame = 2
	world.player.visual._sync_sprite()
	world.player.outfit_layers.sync_pose()
	var animated: ShaderMaterial = world.player.outfit_layers.body_material
	var dress: Sprite2D = world.player.outfit_layers.layers.dress
	t.check("outfit_changes_keep_pose_and_occlusion",world.player.outfit_layers.current_outfit.has("dress") and "unshaded" in dress.material.shader.code and float(animated.get_shader_parameter("frame_phase")) > 0 and world.player.outfit_layers.occluder.material == world.player.outfit_layers.mask_material)
	var orb := LootDrop2D.spawn(area.objects,world.player.global_position+Vector2(2000,0),&"stone")
	look._refresh_actors()
	t.check("new_ground_loot_keeps_visible_pigment",orb.material is CanvasItemMaterial and orb.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED)
	orb.free()
	var whispers := []
	var record := func(key): whispers.append(key)
	EventBus.whisper_requested.connect(record)
	var sleeper := area.find_markers("hulen_keeper")[0].node as Interactable2D
	t.check("hulen_keeper_day",sleeper != null and sleeper.name == "SleepingNatteblik")
	sleeper.interact(world.player)
	t.check("sleeping_keeper_has_honest_hint",whispers.has("LOOK_NATTEBLIK_SLEEPS"))
	gm.hour = 22
	t.check("keeper_hour_frozen_for_visit",area.find_markers("hulen_keeper")[0].node == sleeper)
	t.check("one_trigger_per_connected_pond",look.soft_ground.ponds.size() == 1)
	whispers.clear()
	look.soft_ground.ponds[0]._entered(world.player)
	look.soft_ground.ponds[0]._entered(world.player)
	t.check("pond_whisper_once_per_floor",whispers == ["LOOK_MOONPOND_FISHING"])
	EventBus.whisper_requested.disconnect(record)
	_test_lights(t,look)
	if native: await _visual(t,world,look)
	await world.travel(&"farm",&"default")
	t.check("actors_unshaded_in_forest_only",not "unshaded" in animated.shader.code and (world.player.get_node_or_null("ForestActorLight") == null or world.player.get_node("ForestActorLight").is_queued_for_deletion()))
	await world.travel(&"_forest_look",&"default")
	await t.frames(3)
	var keeper: Node = world.area.find_markers("hulen_keeper")[0].node
	t.check("hulen_keeper_night_uses_real_npc",keeper is Npc2D and keeper.npc_id == &"mapseller_natteblik" and keeper.dialogue_id == &"mapseller_natteblik")
	t.check("pond_whisper_survives_reentry",world.area.get_node("ForestLook").soft_ground.ponds[0].done)
	t.check("lantern_energy_matches_sketch",is_equal_approx(world.player.lantern.energy,.1))
	if native:
		world.player.global_position = keeper.global_position+Vector2(160,100)
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		await t.frames(4)
		await t.capture("hulen_at_night")
	var skin: StringName = gm.character_skin
	var alternate: String = {"animal":"animal_monkey","fairy":"fairy_birk","hobbit":"hobbit_bodil","ghost":"ghost_hviske"}[t.character]
	gm.character_skin = StringName(alternate)
	EventBus.player_character_changed.emit(PlayerRegistry.local_id(), gm.character_skin)
	await t.frames(3)
	world.player.get_node("ForestActorLight").refresh()
	var layers: WardrobeLayers = world.player.outfit_layers
	var shade_ok := true
	for picture in layers.layers.values(): shade_ok = shade_ok and "unshaded" in picture.material.shader.code
	t.check("alternate_hero_clothing_keeps_shaders",shade_ok and not layers.layers.is_empty() and layers.occluder.material == layers.mask_material)
	gm.character_skin = skin
	EventBus.player_character_changed.emit(PlayerRegistry.local_id(), skin)
	if native:
		DungeonFloors.inst().enter(2)
		await t.until(func(): return world.area.map.id == &"moerkeskoven_f2" and not world.traveling,10)
		await t.frames(4)
		t.check("generated_floor_uses_same_dressing",world.area.get_node_or_null("ForestLook") is ForestDress and world.area.find_markers("hulen_keeper")[0].node is Npc2D and world.area.map.errors.is_empty(),str(world.area.map.errors))
		world.player.invulnerable = true
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		await t.frames(4)
		await t.capture("generated_floor_2")
	await world.travel(&"farm",&"default")
func _test_lights(t,look: ForestDress) -> void:
	var made: Array[PointLight2D] = []
	for index in 13:
		var light := PointLight2D.new()
		light.name = "BudgetProbe%d" % index
		light.texture = Glow.light_texture()
		light.position = Vector2(1500,1500)
		look.area.add_child(light)
		made.append(light)
	var errors := look.enforce_light_budget()
	t.check("light_budget_enforced",errors.size() == 1 and made.slice(0,12).all(func(light):return light.enabled) and not made[12].enabled and errors[0].begins_with("forest_light_budget:"),str(errors))
	for index in made.size():
		made[index].position.x += index*1000
		made[index].enabled = true
	t.check("nonoverlapping_lights_allowed",look.enforce_light_budget().is_empty())
	for light in made: light.free()
	made.clear()
	for index in 9:
		var light := PointLight2D.new()
		light.name = "MushroomProbe%d" % index
		light.set_meta("prop_id","glow_mushroom_cluster")
		light.texture = Glow.light_texture()
		light.position.x = index*1000
		look.area.add_child(light)
		made.append(light)
	t.check("glow_mushroom_light_cap",look.enforce_light_budget().size() == 1 and not made[8].enabled)
	for light in made: light.free()
	look.area.map.errors.assign(look.area.map.errors.filter(func(error):return not error.begins_with("forest_light_budget:")))
func _visual(t,world: WorldRoot2D,look: ForestDress) -> void:
	var player := world.player
	player.set_physics_process(false)
	player.visual.set_process(false)
	player.visual.play_loop(&"idle")
	player.visual._frame = 0
	player.visual._sync_sprite()
	player.outfit_layers.sync_pose()
	player.camera.zoom = Vector2.ONE*.4
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()
	world.game_ui.get_screen(&"forest_hud").toasts.clear()
	await t.seconds(3.1)
	await t.capture("sketch_layout")
	var timing := Perf.uncap()
	RenderingServer.viewport_set_measure_render_time(t.tree.root.get_viewport_rid(),true)
	await t.frames(15)
	var windows := []
	for sample in 3: windows.append(await Perf.measure_frames(t.tree,.5,t.tree.root.get_viewport_rid()))
	var best: Dictionary = windows[0]
	for window in windows:
		if window.ms < best.ms: best = window
	t.render_budget("frame_budget", best.ms, 6, str(windows))
	var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	t.check("draw_call_budget",calls <= 450,str(calls))
	var average: float = t.median_usec(func() -> void: look._process(1.0/60),20,50)/1000.0
	t.check("dressing_update_under_point_three_ms",t.perf_ok("dressing_update_under_point_three_ms",average,.3),"%.4f ms/frame (median of 20 batches of 50; native reference 0.3); masks built once in %.3f ms" % [average,look.soft_ground.build_usec/1000.0])
	DisplayServer.window_set_vsync_mode(timing.vsync)
	Engine.max_fps = timing.fps
	# Isolate lighting from the vignette and HUD for a direct same-pixel check.
	world.game_ui.hide()
	world._vignette.hide()
	player.lantern.enabled = false
	await t.frames(3)
	var lit_actor: Image = await t.capture("unshaded_actor")
	var tint := world.day_night.color
	world.day_night.set_process(false)
	world.day_night.color = Color.WHITE
	await t.frames(3)
	var base_actor: Image = await t.capture("base_actor")
	var transform: Transform2D = player.visual.sprite.get_global_transform_with_canvas()
	var center := Vector2i(transform*Vector2(0,-95))
	var difference := 0.0
	var samples := 0
	for y in range(center.y-8,center.y+8):
		for x in range(center.x-8,center.x+8):
			var a := lit_actor.get_pixel(x,y)
			var b := base_actor.get_pixel(x,y)
			difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
			samples += 3
	t.check("actor_pigment_unchanged_by_grade",difference/maxi(1,samples) < .01,"mean RGB difference %.5f" % (difference/maxi(1,samples)))
	world.day_night.color = tint
	world.day_night.set_process(true)
	player.lantern.enabled = true
	await t.frames(3)
	var lantern_on: Image = await t.capture("lantern_profile")
	var profile := []
	for distance in [160,240,320,480]:
		var patch: Vector2i = Vector2i(world.get_viewport().get_canvas_transform()*(player.global_position+Vector2(distance,0)))
		var off_value := 0.0
		var on_value := 0.0
		for y in range(patch.y-5,patch.y+5):
			for x in range(patch.x-5,patch.x+5):
				var off := lit_actor.get_pixel(x,y)
				var on := lantern_on.get_pixel(x,y)
				off_value += off.r*.2126+off.g*.7152+off.b*.0722
				on_value += on.r*.2126+on.g*.7152+on.b*.0722
		profile.append(on_value/maxf(off_value,.001))
	t.check("lantern_inner_path_lift",profile[0] >= 1.15 and profile[0] <= 1.35,"luminance ratios at 160/240/320/480 ground px: "+str(profile))
	t.check("lantern_lift_falls_toward_edge",profile[0] > profile[1] and profile[1] > profile[2] and profile[2] > profile[3] and profile[3] >= 1,str(profile))
	world._vignette.show()
	world.game_ui.show()
	player.set_physics_process(true)
	player.visual.set_process(true)
