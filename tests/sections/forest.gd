extends RefCounted
const SECTION := "forest"
const TIMEOUT_S := 180.0
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _node(area: IsoArea, kind: String, cell: Vector2i, at: Vector2) -> ResourceNode2D:
	var node := ResourceNode2D.create_marker({"kind":kind},at,cell,area)
	if node != null: area.objects.add_child(node)
	return node
func _run(t, native: bool) -> void:
	var cfg := LuaData.dict(Svc.lua_config("dungeon",{}))
	var resources := LuaData.dict(Svc.lua_config("resource_nodes",{}))
	var tally := {"checks":{},"bad":{},"first":{}}
	var generated := true
	ArtCatalog.clear_missing()
	for row in resources.values(): ArtCatalog.prop(StringName(str(row.art)))
	for n in range(1,13):
		var spec := DungeonSpec.spec_for(cfg,n)
		for kind in spec.nodes: t.check("node_row_f%d_%s" % [n,kind],resources.has(str(kind)))
		for day in range(1,6):
			var seed_value := DungeonRng.hash_key("resource-coverage",day,n)
			var ctx := {"next_id":"moerkeskoven_f%d" % (n+1),"prev_id":"moerkeskoven_f%d" % (n-1),"day":day,"seed_text":str(seed_value),"gen_version":1,"spec_hash":"0"}
			var result := DungeonGen.build_text(cfg,n,seed_value,ctx)
			generated = generated and result.ok
			if not result.ok: continue
			var map := AreaMap.parse_text(result.text)
			DungeonVerify.verify(map,spec,cfg,ctx,tally)
			var chars := {}
			for line in map.ground:
				for ch in line: chars[ch] = true
			for ch in chars:
				var id := IsoArea.terrain_id(ch,map.projection,map.theme)
				if id != &"": ArtCatalog.terrain(id)
			for value in map.props.values(): ArtCatalog.prop(StringName(str(value.get("prop",""))))
	t.check("generated_floors_parse_and_connect",generated and tally.bad.is_empty(),str(tally.first))
	t.check("maps_art_complete",ArtCatalog.missing().is_empty(),str(ArtCatalog.missing()))
	t.check("no_legacy_files",not DirAccess.dir_exists_absolute("res://scripts/world") and not DirAccess.dir_exists_absolute("res://scenes/forest"))
	await t.start_world()
	var world: WorldRoot2D = t.world()
	await world.travel(&"_fixture_ortho",&"from_iso")
	var player := world.player
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var qm: Node = t.autoload("QuestManager")
	var area := world.area
	var at := player.global_position+Vector2(800,0)
	var ore := _node(area,"iron_ore",Vector2i(2,2),at)
	t.check("handler_entry_has_cell_and_area",IsoArea.resolve_handler("node").mode == "create_marker" and IsoArea.resolve_handler("whisper").mode == "create_marker")
	var hp := ore.hp
	t.check("wrong_or_weak_tool_refused",not ore.tool_hit("axe",9) and not ore.tool_hit("pickaxe",0) and ore.hp == hp)
	qm.register_quest_from_lua({"id":"zz_forest_collect","objectives":[{"id":"collect_iron_ore","target":999},{"id":"gate","target":1,"on":"manual"}],"rewards":{},"meta":{}})
	qm.accept_quest(&"zz_forest_collect")
	var before: int = eco.count_item(&"iron_ore")
	for i in hp: ore.tool_hit("pickaxe",1)
	t.check("tool_depletes_to_ground_once",ore.depleted and not ore.tool_hit("pickaxe",1) and eco.count_item(&"iron_ore") == before)
	t.check("ground_loot_does_not_progress_collection",qm.get_objective_progress(&"zz_forest_collect",&"collect_iron_ore").current == 0)
	for orb in area.objects.get_children():
		if orb is LootDrop2D: orb.collect()
	var gained: int = eco.count_item(&"iron_ore")-before
	t.check("collection_counts_once_on_actual_pickup",gained >= 1 and gained <= 3 and qm.get_objective_progress(&"zz_forest_collect",&"collect_iron_ore").current == gained)
	qm.reset()
	qm.quest_defs.erase(&"zz_forest_collect")
	var saved: Dictionary = gm.to_dict()
	ore._refresh()
	t.check("static_node_depletion_survives_refresh",ore.depleted)
	gm.end_day()
	gm.end_day()
	t.check("ore_not_yet_respawned",ore.depleted)
	gm.end_day()
	await t.frames(2)
	t.check("ore_respawns_on_its_third_day",not ore.depleted and ore.hp == hp)
	gm.from_dict(saved)
	for kind in ["planter_herb","planter_berry","apple_tree"]:
		var node := _node(area,kind,Vector2i(3,3),at+Vector2(100,0))
		node.deplete()
		t.check("daily_node_depletes_"+kind,node.depleted)
		gm.end_day()
		await t.frames(2)
		t.check("planter_nodes_respawn_daily_"+kind,not node.depleted)
		node.queue_free()
	var forage := _node(area,"glow_mushroom",Vector2i(4,4),at)
	forage.interact(player)
	await t.seconds(.3)
	t.check("forage_still_picking_at_half_time",forage.picking and not forage.depleted)
	await t.seconds(.35)
	t.check("forage_pick_with_e",not forage.picking and forage.depleted and player.state != Player2D.S.TALKING)
	var disabled := _node(area,"night_bloom",Vector2i(5,5),at)
	disabled.interact(player)
	disabled.set_enabled(false)
	gm.end_day()
	await t.frames(2)
	t.check("hidden_node_cancels_pick_and_stays_disabled",not disabled.picking and not disabled.depleted and disabled._area.collision_layer == 0 and not disabled.deplete())
	var whispers := []
	var record := func(key): whispers.append(key)
	EventBus.whisper_requested.connect(record)
	var zone: WhisperZone = WhisperZone.create_marker({"text":"DUNGEON_WHISPER_SKOVKANT_1","r":2},at,Vector2i(6,6),area)
	area.objects.add_child(zone)
	zone._entered(player)
	zone._entered(player)
	t.check("whisper_once_per_visit",zone.done and whispers == ["DUNGEON_WHISPER_SKOVKANT_1"])
	EventBus.whisper_requested.disconnect(record)
	var floors := DungeonFloors.inst()
	floors.enter(1)
	await t.until(func(): return world.area.map.id == &"moerkeskoven_f1" and not world.traveling,10.0)
	area = world.area
	var markers := area.find_markers("node")
	t.check("handlers_build_on_generated_floor",not markers.is_empty() and markers.all(func(row): return row.node is ResourceNode2D))
	if not markers.is_empty():
		var node: ResourceNode2D = markers[0].node
		var ctx := node.context.duplicate()
		ctx["deliver"] = "orbs"
		var expected: Dictionary = t.autoload("LootService").node_loot(node.kind,node.uid,ctx)
		t.check("node_loot_through_loot_service",expected.ok and node.deplete() and floors.is_done_cell(area,node.cell))
		t.check("done_cells_skip_consumed_nodes",ResourceNode2D.create_marker({"kind":node.kind},node.position,node.cell,area) == null)
		var actual := []
		for orb in area.objects.get_children():
			if orb is LootDrop2D: actual.append({"id":str(orb.item_id),"amount":orb.amount})
		var wanted := []
		for row in expected.results: wanted.append({"id":str(row.id),"amount":int(row.amount)})
		t.check("generated_yields_have_no_extra_static_roll",actual == wanted,str({"actual":actual,"expected":wanted}))
	var cell := Vector2i(1,1)
	var floor_zone: WhisperZone = WhisperZone.create_marker({"text":"DUNGEON_WHISPER_SKOVKANT_1"},at,cell,area)
	area.objects.add_child(floor_zone)
	floor_zone._entered(world.player)
	t.check("whisper_consumption_persists_on_generated_floor",floors.is_done_cell(area,cell) and WhisperZone.create_marker({"text":"DUNGEON_WHISPER_SKOVKANT_1"},at,cell,area) == null)
	if native:
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		await t.frames(4)
		await t.capture("resource_nodes_in_generated_forest")
	await world.travel(&"farm",&"default")
