extends RefCounted
const SECTION := "home_world"
const TIMEOUT_S := 180.0
var native := false
func run(t) -> void:
	await _run(t)
func run_windowed(t) -> void:
	native = true
	await _run(t)
func _run(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var fm: Node = t.autoload("FurnitureManager")
	var home: Node = t.autoload("HomeManager")
	var gm: Node = t.autoload("GameManager")
	t.check("home_map_registered", world.has_area(&"home"))
	t.check("real_farm_house_and_tent_handlers", world.area.handled_count("home") == 1 and world.area.handled_count("tent") == 1)
	for tier in range(1,11):
		home.tier = tier
		gm.set_flag(&"home_tier",tier)
		EventBus.home_upgraded.emit(maxi(tier-1,1),tier)
		fm.from_dict({})
		AutoFurnish.fill(120,["normal","uncommon","rare","unique","legendary"])
		await world.travel(&"home",&"default")
		await t.frames(3)
		var room: HomeRoom = world.area.get_node_or_null("HomeRoom")
		t.check("tier_%d_builds_without_error" % tier, room != null and world.area.builder_error == "")
		if room == null: return
		t.check("tier_%d_floor_matches_cells" % tier, world.area.ground.get_used_cells().size() == fm.grid.floor_cells.size())
		t.check("tier_%d_spawn_coordinates_match" % tier, world.player.global_position.is_equal_approx(world.area.cell_to_global(fm.grid.spawn_cell)))
		t.check("tier_%d_camera_uses_authored_zoom" % tier, is_equal_approx(world.area.zoom_default,float(HomeData.room(tier).zoom_fit)))
		t.check("tier_%d_every_placement_has_painted_node" % tier, room.nodes.size() == fm.grid.placements.size() and room.nodes.values().all(func(n): return n.get_node("Sprite").texture != null))
		t.check("tier_%d_boundary_is_solid" % tier, world.area.get_node("RoomBoundary").get_child_count() >= 14)
		t.check("tier_%d_interaction_points_exist" % tier, world.area.objects.get_children().any(func(n): return n is Interactable2D))
		var mapped := true
		for c in fm.grid.floor_cells:
			mapped = mapped and world.area.global_to_cell(world.area.cell_to_global(c)) == c
		t.check("tier_%d_room_uses_world_coordinate_contract" % tier,mapped)
		if native and tier in [1,5,10]:
			world.game_ui.get_screen(&"hud").toasts.clear()
			gm.hour = 12
			EventBus.time_of_day_changed.emit(gm.hour,gm.minute)
			await t.frames(3)
			await t.capture("room_t%02d_day" % tier)
			gm.hour = 21
			EventBus.time_of_day_changed.emit(gm.hour,gm.minute)
			await t.frames(3)
			await t.capture("room_t%02d_night" % tier)
		await world.travel(&"farm",&"from_home")
		await t.frames(2)
		t.check("tier_%d_returns_to_farm_door" % tier,world.area.map.id == &"farm" and world.player.global_position.is_equal_approx(world.area.get_spawn("from_home")))
		var exterior: Node = world.area.find_markers("home")[0].node
		t.check("tier_%d_exterior_uses_fixed_door_anchor" % tier,exterior._tier == tier and exterior._visuals[0].get_node("Sprite").texture != null)
		if native and tier in [1,5,10]:
			await t.capture("farm_house_t%02d" % tier)
	home.tier = 1
	home.construction = {"target":2,"start_day":gm.total_day(),"ready_day":gm.total_day()+1}
	EventBus.home_upgrade_started.emit(1,2,gm.total_day()+1)
	await world.travel(&"hyggebyen",&"default")
	await world.travel(&"farm",&"from_home")
	var exterior: Node = world.area.find_markers("home")[0].node
	t.check("construction_keeps_old_house_and_scaffold",exterior._tier == 1 and exterior._target == 2 and exterior._visuals.size() == 4)
	t.check("construction_tent_appears",world.area.find_markers("tent")[0].node._picture != null)
	if native: await t.capture("farm_house_construction")
	t.check("construction_refuses_entry",not home.can_enter_home())
	home.construction = {}
	home.tier = 1
	fm.reset()
