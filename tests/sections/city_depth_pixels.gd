extends RefCounted
## Independent native evidence: legacy ranks vs join ranks, and a floor-hidden
## control at each mouth. Captures only the unoccluded centre of the ghost head.
const SECTION := "city_depth_pixels"
const TIMEOUT_S := 120.0
func run_windowed(t) -> void:
	await t.start_world("ghost","Tester","Testgaarden","ghost_bu")
	var w: WorldRoot2D = t.world()
	w._enter(&"traetoppen",&"default")
	var p: Player2D = w.player
	p.set_physics_process(false)
	p.visual.set_process(false)
	p.camera.position_smoothing_enabled = false
	t.autoload("TimeManager").is_paused = true
	var stage := LevelStage.of(w.area)
	var sheet := Image.create(480,18*180,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("f3e8ce"))
	var row := 0
	var exposed_bug := 0
	for bridge in stage.registry.bridges:
		for end in 2:
			var platform := stage.registry.get_level(bridge.from_id if end == 0 else bridge.to_id)
			var mouth: Vector2 = bridge.gate_path[0 if end == 0 else bridge.gate_path.size()-1]
			var tangent := (bridge.gate_path[1]-bridge.gate_path[0]).normalized()
			if end == 1: tangent = (bridge.gate_path[bridge.gate_path.size()-2]-bridge.gate_path[bridge.gate_path.size()-1]).normalized()
			p.global_position = mouth + tangent * (30 if bridge.rank < platform.rank else -30)
			stage.tracker.refresh(p)
			var level := stage.registry.level_at(p.global_position)
			ActorLevel.lock(p,level.id)
			ActorLevel.set_draw_rank(p, maxi(platform.rank,bridge.rank))
			p.camera.reset_smoothing()
			await t.physics(2) # Let the camera settle before mapping canvas pixels.
			await t.frames(3)
			var name := "%s_%d" % [bridge.id,end]
			var fixed: Image = await t.capture("join_"+name)
			var foot: Vector2 = p.get_global_transform_with_canvas().origin
			var crop := Rect2i(Vector2i(foot)-Vector2i(120,140),Vector2i(240,180))
			var head: Vector2 = p.visual.sprite.get_global_transform_with_canvas() * (p.visual.sprite.get_rect().position+Vector2(128,103))
			var face := Rect2i(Vector2i(head)-Vector2i(2,2),Vector2i(4,4))
			var light := Vector3.ZERO
			for y in 4:
				for x in 4:
					var color := fixed.get_pixel(face.position.x+x,face.position.y+y)
					light += Vector3(color.r,color.g,color.b)/16.0
			t.check("face_visible_"+name, minf(light.x,minf(light.y,light.z)) > 0.72, "head patch RGB %s" % light)
			stage.floors.visible = false
			await t.frames(2)
			var control: Image = await t.capture("control_"+name)
			var delta: float = t.mean_abs_diff(fixed.get_region(face),control.get_region(face))
			t.check("face_clear_"+name, delta < 0.015, "face difference with decks hidden: %.5f" % delta)
			stage.floors.visible = true
			ActorLevel.set_draw_rank(p,level.rank)
			await t.frames(2)
			var legacy: Image = await t.capture("legacy_"+name)
			if t.mean_abs_diff(fixed.get_region(crop),legacy.get_region(crop)) > 0.002: exposed_bug += 1
			sheet.blit_rect(legacy,crop,Vector2i(0,row*180))
			sheet.blit_rect(fixed,crop,Vector2i(240,row*180))
			row += 1
			ActorLevel.unlock(p)
			stage.tracker.refresh(p)
			for prefix in ["join_","control_","legacy_"]:
				DirAccess.remove_absolute(t.out_dir.path_join(SECTION+"_"+prefix+name+".png"))
	sheet.save_png(t.out_dir.path_join("city-depth-before-after.png"))
	t.check("legacy_control_exposes_reported_depth_bug", exposed_bug >= 1, "%d of 18 mouth crops change when legacy rank is restored" % exposed_bug)
	p.set_physics_process(true)
	p.visual.set_process(true)
	t.autoload("TimeManager").is_paused = false
