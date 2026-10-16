extends RefCounted
const SECTION := "dungeon_pickups"
class DeliverySpy extends Node:
	var calls := 0
	var allow := true
	func deliver(_item, _amount) -> Dictionary:
		calls += 1
		return {"ok":allow}
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _run(t, native: bool) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var parent := Node2D.new()
	world.area.objects.add_child(parent)
	var at := world.player.global_position+Vector2(900,0)
	var spy := DeliverySpy.new()
	world.add_child(spy)
	Svc.override("LootService",spy)
	var orb := LootDrop2D.spawn(parent,at,"wood",1)
	t.check("pickup_layer_and_delay",orb.collision_layer == Iso.LAYER_PICKUP and orb.age < .25 and not orb.collected)
	var start := orb.global_position
	orb.age = .6
	orb.global_position = world.player.global_position+Vector2(150,0)
	start = orb.global_position
	orb._process(.01)
	t.check("orb_magnet_and_pickup",orb.global_position.distance_to(world.player.global_position) < start.distance_to(world.player.global_position) and orb.collect())
	t.check("pickup_goes_through_loot_deliver_when_present",spy.calls == 1)
	spy.allow = false
	var blocked := LootDrop2D.spawn(parent,at,"wood",1)
	var warnings := []
	var record := func(key): warnings.append(key)
	EventBus.whisper_requested.connect(record)
	blocked.collect()
	blocked.collect()
	t.check("full_pack_retains_drop_and_warns_once",not blocked.collected and warnings.count("DEXP_BACKPACK_FULL") == 1)
	EventBus.whisper_requested.disconnect(record)
	spy.allow = true
	t.check("full_pack_can_retry",blocked.collect())
	await t.frames(2)
	var before_hearts: int = world.player.half_hearts
	world.player.half_hearts = world.player.max_half_hearts-2
	var berry := LootDrop2D.spawn(parent,at,"tornebaer",1)
	var before := spy.calls
	t.check("berry_heals_when_hurt",berry.collect() and world.player.half_hearts == world.player.max_half_hearts and spy.calls == before)
	world.player.half_hearts = before_hearts
	await t.frames(2)
	for i in 51: LootDrop2D.spawn(parent,at+Vector2(i,0),"wood",1)
	var alive := parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected)
	t.check("orb_cap_50_auto_collects",alive.size() == 50 and spy.calls == before+1)
	spy.allow = false
	LootDrop2D.spawn(parent,at,"stone",2)
	t.check("cap_full_pack_queues_without_loss",LootDrop2D.queue_for(parent).rows.size() == 1 and parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected).size() == 50)
	spy.allow = true
	LootDrop2D.queue_for(parent)._process(.6)
	t.check("cap_pending_drop_retries",LootDrop2D.queue_for(parent).rows.is_empty())
	Svc.clear_overrides()
	for node in parent.get_children():
		if node is LootDrop2D: node.queue_free()
	await t.frames(2)
	TelegraphRing2D.warm(parent)
	var ring := TelegraphRing2D.play(parent,at,{"radius":100,"duration":1})
	t.check("telegraph_ring_matches_hit_area",ring.hit_area().radius == 100 and ring.contains_ground(Vector2(99,0)) and not ring.contains_ground(Vector2(101,0)))
	var line := TelegraphRing2D.play(parent,at,{"shape":"line","direction":Vector2.UP,"length":300,"width":60,"duration":1})
	t.check("telegraph_line_matches_hit_area",line.contains_ground(Vector2(0,-299)) and not line.contains_ground(Vector2(31,-150)) and line.polygon().size() == 4)
	for i in 9: TelegraphRing2D.play(parent,at,{"radius":90+i})
	t.check("telegraph_pool_cap_8",parent.get_node("TelegraphPool").get_child_count() == 8)
	DungeonSpark2D.warm(parent)
	var count := parent.get_node("SparkPool").get_child_count()
	for i in 100:
		HitSpark2D.play(parent,at,"rare")
		HealSparkle2D.play(parent,at)
	t.check("fx_pool_reuse",parent.get_node("SparkPool").get_child_count() == count and count == DungeonSpark2D.CAP)
	for node in parent.get_node("SparkPool").get_children(): node._process(1)
	t.check("fx_idle_process_disabled",parent.get_node("SparkPool").get_children().all(func(n): return not n.active and not n.is_processing()))
	if native:
		for node in parent.get_node("TelegraphPool").get_children(): node.finish()
		var center := world.player.global_position
		world.player.camera.zoom = Vector2(.7,.7)
		for i in 6:
			var node := LootDrop2D.spawn(parent,center+Vector2((i-3)*90,-150),"wood",1)
			node.tint = Color(["b9c3e3","e3c372","6fd6c4","c4bad6","e8863a","fbf5e6"][i])
			node.set_process(false)
		TelegraphRing2D.play(parent,center+Vector2(-200,100),{"radius":120,"duration":30})
		TelegraphRing2D.play(parent,center+Vector2(100,100),{"shape":"line","width":60,"length":250,"duration":30})
		await t.frames(4)
		await t.capture("orb_and_ring_shot")
	parent.queue_free()
	spy.queue_free()
	await t.frames(2)
