extends RefCounted
const SECTION := "dungeon_floors"
const TIMEOUT_S := 180.0
func run(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var floors := DungeonFloors.inst()
	var save: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	t.check("floors.section_registered_order_45_and_resets",floors != null and save.has_section("dungeon") and floors.world_seed_text().is_valid_int())
	if floors == null: return
	var original_seed := floors.world_seed_text()
	floors.reset()
	t.check("floors.world_seed_made_on_new_game",floors.world_seed_text() != original_seed)
	await world.travel(&"moerkeskoven",&"from_traetoppen")
	await t.frames(3)
	t.check("floors.hub_registers_first_floor",WorldRoot2D.has_area(&"moerkeskoven_f1"))
	t.check("floors.unregistered_floor_refused",not WorldRoot2D.has_area(&"moerkeskoven_f12"))
	var rune: Runestone2D = world.area.find_markers("runestone")[0].node
	t.check("floors.hub_rune_always_lit",rune != null and rune.lit)
	rune.interact(world.player)
	await t.frames(3)
	var picker: TTScreen = world.game_ui.get_node_or_null("RunePicker")
	t.check("floors.rune_picker_lists_one_plus_stones",picker != null and picker.is_open() and picker.rows.get_child_count() == 1)
	picker.close()
	floors.enter(1)
	await t.until(func(): return world.area.map.id == &"moerkeskoven_f1" and not world.traveling,10.0)
	t.check("floors.enter_from_stone_starts_at_that_floor",floors.active and floors.floor == 1 and world.area.map.id == &"moerkeskoven_f1")
	var pinned: int = floors.seed_day
	gm.end_day()
	t.check("floors.seed_pinned_while_active",floors.seed_day == pinned)
	var first_text := floors.floor_text(1)
	# Use a real marker cell rather than a guessed location for consumption.
	var cell: Vector2i = world.area.find_markers("chest")[0].cell
	var uid := floors.uid_of(world.area,cell)
	var a := floors.rng_for(world.area,cell,"chest").next_u32()
	var b := floors.rng_for(world.area,cell,"chest").next_u32()
	t.check("floors.uid_and_rng_deterministic",uid.begins_with("dg:%d:1:" % pinned) and a == b)
	floors.mark_done_cell(world.area,cell)
	t.check("floors.done_cells_skip_consumed_markers",floors.is_done_cell(world.area,cell))
	var wire: Dictionary = JSON.parse_string(JSON.stringify(floors.to_dict()))
	t.check("floors.save_roundtrip_registers_floor_before_world",floors.from_dict(wire) and WorldRoot2D.has_area(&"moerkeskoven_f1") and floors.floor_text(1) == first_text)
	world.player.oil = 13
	await world.travel(&"moerkeskoven_f2",&"default")
	t.check("floors.oil_refill_first_visit_only",world.player.oil > world.player.max_oil - 1,"oil=%s area=%s floor=%s" % [world.player.oil,world.area.map.id,floors.floor])
	world.player.oil = 50
	await world.travel(&"moerkeskoven_f1",&"from_down")
	t.check("floors.reenter_does_not_farm_refill",world.player.oil < 51 and floors.floor_text(1) == first_text)
	await world.travel(&"moerkeskoven_f2",&"default")
	await t.until(func(): return WorldRoot2D.has_area(&"moerkeskoven_f3"),10.0)
	t.check("floors.register_ahead_neighbours_and_unregister_far",WorldRoot2D.has_area(&"moerkeskoven_f1") and WorldRoot2D.has_area(&"moerkeskoven_f3") and not WorldRoot2D.has_area(&"moerkeskoven_f5"),"area=%s floor=%s registered=%s tasks=%s texts=%s error=%s" % [world.area.map.id,floors.floor,floors._registered,floors._tasks.keys(),floors._texts.keys(),floors.last_error])
	var synchronous := DungeonGen.build_text(floors.cfg,3,floors.floor_seed(3),floors._context(3))
	t.check("floors.prefetch_equals_sync",synchronous.text == floors.floor_text(3))
	await world.travel(&"moerkeskoven_f3",&"default")
	t.check("floors.floor_three_has_runestone",world.area.find_markers("runestone").size() == 1,"area=%s error=%s" % [world.area.map.id,world.last_travel_error])
	if world.area.find_markers("runestone").is_empty(): return
	var stone: Runestone2D = world.area.find_markers("runestone")[0].node
	var activated: Array = []
	var record := func(name,payload):
		if name == &"dungeon_runestone_activated": activated.append(payload)
	EventBus.game_event.connect(record)
	world.player.half_hearts = 2
	world.player.oil = 0
	stone.interact(world.player)
	stone.interact(world.player)
	t.check("floors.stone_activation_effects",stone.lit and floors.stones.has(3) and world.player.half_hearts == world.player.max_half_hearts and world.player.oil == world.player.max_oil)
	t.check("floors.stone_activation_event_once",activated.size() == 1 and activated[0].floor == 3 and activated[0].level == 3)
	EventBus.game_event.disconnect(record)
	floors._ensure(4)
	await world.travel(&"moerkeskoven_f4",&"default")
	var gate: Dictionary = world.area.find_markers("warp").filter(func(m): return str(m.params.get("to","")) == "moerkeskoven_f5")[0]
	t.check("floors.boss_gate_starts_closed",not gate.node.armed)
	EventBus.enemy_defeated.emit(&"test_boss",&"snurresvamp",[])
	await t.frames(2)
	t.check("floors.boss_flag_opens_hulen_and_chest",gate.node.armed and bool(gm.get_flag(&"dg_boss_clear",false)))
	gm.push_modal(&"pause",true)
	floors.leave()
	await t.until(func(): return world.area.map.id == &"moerkeskoven" and not world.traveling,10.0)
	t.check("floors.leave_with_open_modals_travels",not gm.is_modal_open() and not floors.active and world.area.map.id == &"moerkeskoven")
	floors.reveal_floor(3)
	t.check("floors.reveal_is_explicit",floors.is_revealed(3) and not floors.is_revealed(4))
	gm.end_day()
	t.check("floors.new_day_clears_done_and_seen",floors.done.is_empty() and floors.seen.is_empty() and floors.reveal.is_empty() and floors.stones.has(3))
	t.check("floors.day_started_prunes_when_outside",not WorldRoot2D.has_area(&"moerkeskoven_f3"))
	floors.enter(3)
	await t.until(func(): return world.area.map.id == &"moerkeskoven_f3" and not world.traveling,10.0)
	t.check("floors.runestone_reentry_uses_authored_spawn",world.player.global_position.distance_to(world.area.get_spawn("rune")) < 2)
	# SAVE-08: a save during a run keeps the hearts, stamina and oil and the run statistics; Continue is no free heal and refuel
	var keep_dir: String = save.save_dir
	save.save_dir = "user://dungeon-floors-run"
	var watch: DungeonRunWatch = world.get_node("RunWatch")
	watch.kills = 4
	world.player.half_hearts = 3
	world.player.stamina = 40.0
	world.player.oil = 20.0
	var counted: Array = watch.floors.keys()
	var old_world := world.get_instance_id()
	var resumed: bool = save.save_game(0) and save.load_and_enter(0)
	resumed = resumed and await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_world and t.world().get("ready_for_play") == true, 20.0)
	world = t.world()
	var new_watch: DungeonRunWatch = world.get_node_or_null("RunWatch") if world != null else null
	t.check("floors.run_vitals_survive_continue", resumed and floors.active and world.player.half_hearts == 3 and world.player.stamina >= 39.9 and world.player.stamina < 60.0 and world.player.oil <= 20.0 and world.player.oil > 15.0,
		"after load_and_enter: hearts %s, stamina %s, oil %s (saved 3, 40, 20; stamina regrows and oil burns while the world settles)" % [world.player.half_hearts, world.player.stamina, world.player.oil])
	t.check("floors.run_statistics_survive_continue", new_watch != null and new_watch.active and new_watch.kills == 4 and new_watch.floors.size() == counted.size(), "kills %s, floors %s (saved 4, %s)" % [new_watch.kills if new_watch != null else "-", new_watch.floors.keys() if new_watch != null else "-", counted])
	save.delete_save(0)
	save.save_dir = keep_dir
	var payload: Dictionary = floors.to_dict()
	payload["spec"] = "old-layout"
	payload["deepest"] = 7
	t.check("floors.spec_or_gen_mismatch_drops_run_keeps_stones",floors.from_dict(payload) and not floors.active and floors.deepest == 7 and floors.stones.has(3) and floors.done.is_empty())
	var before: Dictionary = floors.to_dict()
	# floor 99 used to be "malformed" here (the depth was hard-coded to 12); since SAVE-07 only a floor no build can have is
	t.check("floors.malformed_load_is_atomic",not floors.from_dict({"active":true,"floor":5000}) and not floors.from_dict({"active":true,"floor":-1}) and floors.to_dict() == before)
	t.check("floors.deeper_saved_dungeon_is_not_damage",floors.validate_dict({"active":false,"floor":0,"deepest":40,"stones":[3,40]}))
	# The delta section stores consumed marker cells, never a generated map.
	var complete := before.duplicate(true)
	complete.done = {}
	for number in range(1,13):
		var map := AreaMap.parse_text(floors.floor_text(number))
		var values: Array = []
		for y in map.height:
			for x in map.width:
				var character := map.object_at(Vector2i(x,y))
				var marker: Dictionary = map.markers.get(character,{})
				if str(marker.get("marker","")) in ["node","chest","enemy","dig_spot","unique_spot"]:
					values.append(y * map.width+x)
		complete.done[str(number)] = values
	t.check("floors.section_size_worst_case_under_4kb",JSON.stringify(complete).to_utf8_buffer().size() < 4096)
	await world.travel(&"moerkeskoven",&"from_floor")
