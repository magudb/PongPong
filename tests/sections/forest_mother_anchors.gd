extends RefCounted
const SECTION := "forest_mother_anchors"
const TIMEOUT_S := 240.0
func run(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var gm: Node = t.autoload("GameManager")
	gm.set_flag(&"forest_mother_version",1)
	gm.set_config_override("time.minutes_per_real_second",0)
	gm.set_config_override("towns.curfew.enabled",false)
	var floors := DungeonFloors.inst()
	floors.world_seed = "1431765519"
	var expected := {1:1,5:4,7:1,9:1,10:1,11:1,12:1}
	for day in [1,17,53]:
		await world.travel(&"farm",&"default")
		gm.day = posmod(day-1,28)+1
		gm.season = gm.seasons()[floori((day-1)/28.0)]
		for number in expected:
			floors.enter(number)
			await t.until(func():return DungeonFloors.floor_of(world.area) == number and not world.traveling,12)
			await t.physics(4)
			await t.frames(3)
			var director: MotherStoryDirector = world.get_node("MotherStory")
			var nav := NavGrid.bake_area(world.area)
			var start := nav.nearest_free(world.area.global_to_cell(world.area.get_spawn("default")))
			var valid: bool = director.anchors.size() == expected[number]
			for anchor in director.anchors:
				valid = valid and not nav.astar.get_id_path(start,anchor.cell).is_empty() and not director._under_canopy(world.area,anchor.cell)
			t.check("reachable_clear_anchors_day_%d_floor_%d" % [day,number],valid and world.area.map.errors.is_empty(),"anchors=%d wanted=%d errors=%s" % [director.anchors.size(),expected[number],world.area.map.errors])
	await world.travel(&"secret_garden",&"default")
	await t.physics(4)
	await t.frames(3)
	var count := world.area.objects.get_children().filter(func(node):return node is MotherEvidenceMarker).size()
	await world.travel(&"farm",&"default")
	await world.travel(&"secret_garden",&"default")
	await t.physics(4)
	await t.frames(3)
	t.check("parked_garden_reentry_never_duplicates_story_props",count == 2 and world.area.objects.get_children().filter(func(node):return node is MotherEvidenceMarker).size() == count)
