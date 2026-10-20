extends RefCounted
const SECTION := "dungeon_fights"
# One hundred real fights may each use the full eight-second bot limit (CI runs this with --fast).
# At normal wall-clock pacing that is a long Monte Carlo, so the smoke sample still exercises the bot
# without simulating the full hundred (tools/ci/sections.py SIMULATIONS).
const TIMEOUT_S := 960.0
func run(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var full: bool = t.fixed_fps()
	var fights: int = 100 if full else 4
	t.info("dungeon_fights pacing: %s (fights %d)" % ["fixed-fps simulation" if full else "normal wall-clock smoke", fights])
	var ground := PackedStringArray()
	var objects := PackedStringArray()
	for y in 24:
		ground.append("#".repeat(36) if y == 0 or y == 23 else "#"+"m".repeat(34)+"#")
		objects.append(".".repeat(36) if y != 12 else ".".repeat(18)+"@"+".".repeat(17))
	var map := AreaMap.parse_text("@id _fight_lab\n@projection ortho\n@ambient forest\n@theme forest\n@floor 5\n@band dybe_bregner\n@ground\n"+"\n".join(ground)+"\n@objects\n"+"\n".join(objects)+"\n")
	WorldRoot2D.register_map(&"_fight_lab",map)
	await world.travel(&"_fight_lab",&"default")
	var eco: Node = t.autoload("EconomyManager")
	eco.add_item(&"iron_sword",1,true)
	eco.equip(&"weapon",&"iron_sword")
	DungeonRun.apply_preset("none")
	var player := world.player
	var results := []
	var good := 0
	var spawn := world.area.get_spawn("default")
	DungeonEnemyRoster.of(world.area).set_process(false)
	for seed_value in fights:
		player.global_position = spawn
		player.revive(spawn)
		player.combat._iframes = 0
		var enemy: Enemy2D = Enemy2D.create_marker({"kind":"ugleoje","tier":2,"persist":0},spawn+Vector2(350,0),world.area.global_to_cell(spawn+Vector2(350,0)),world.area)
		enemy.persist_cell = false
		world.area.objects.add_child(enemy)
		var result: Dictionary = await DungeonFightBot.duel(t,player,enemy,seed_value)
		results.append(result)
		if result.won and result.seconds <= 6.5 and result.lost <= 2: good += 1
		enemy.queue_free()
		for node in world.area.objects.get_children():
			if node is LootDrop2D: node.queue_free()
		await t.frames(2)
	if full:
		t.check("bot_fight_matches_model_90_percent_of_100",good >= 90,"%d/100 fights won within 6.5 s and at most 2 half hearts lost" % good)
	else:
		t.check("bot_fight_matches_model_smoke",good >= maxi(1,fights-1),"%d/%d fights won within 6.5 s and at most 2 half hearts lost" % [good,fights])
	t.info("fight results: "+JSON.stringify(results))
	for row in [["bat",1],["tornebusk",3]]:
		player.revive(spawn)
		player.combat._iframes = 0
		var enemy: Enemy2D = Enemy2D.create_marker({"kind":row[0],"tier":2,"persist":0},spawn+Vector2(130,0),world.area.global_to_cell(spawn+Vector2(130,0)),world.area)
		enemy.persist_cell = false
		world.area.objects.add_child(enemy)
		var result: Dictionary = await DungeonFightBot.duel(t,player,enemy,42)
		t.check("curve_swings_"+row[0],result.won and result.swings == row[1],JSON.stringify(result))
		enemy.queue_free()
		await t.frames(2)
	await world.travel(&"farm",&"default")
	WorldRoot2D.unregister_map(&"_fight_lab")
