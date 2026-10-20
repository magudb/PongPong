extends RefCounted
const SECTION := "combat_acceptance"
# All 180 boss duels and 100 ambush trials run with fixed 60 Hz physics in CI.
const TIMEOUT_S := 1200.0
func run(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	GameManager.set_config_override("time.minutes_per_real_second",0.0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	var ground := PackedStringArray()
	var objects := PackedStringArray()
	for y in 28:
		ground.append("#".repeat(40) if y==0 or y==27 else "#"+"m".repeat(38)+"#")
		objects.append(".".repeat(40) if y!=14 else ".".repeat(20)+"@"+".".repeat(19))
	var map := AreaMap.parse_text("@id _combat_acceptance\n@projection ortho\n@ambient forest\n@theme forest\n@floor 4\n@band skovkant\n@ground\n"+"\n".join(ground)+"\n@objects\n"+"\n".join(objects)+"\n")
	WorldRoot2D.register_map(&"_combat_acceptance",map)
	await world.travel(&"_combat_acceptance",&"default")
	DungeonRun.apply_preset("none")
	EconomyManager.add_item(&"iron_sword",1,true)
	EconomyManager.equip(&"weapon",&"iron_sword")
	var weapon: Dictionary = LuaRuntime.get_item_def("iron_sword")
	var original_damage: int = weapon.damage
	var spawn := world.area.get_spawn("default")
	var report := {"bosses":{},"profile":"normal movement, swing after 0.22 s in range, windup reaction N(0.40,0.13) clamped 0.12–0.65 s; boss profile clears windup/lunge telegraphs and attacks recovery; no assist; live adds and berry orbs; gross damage before healing"}
	var count := 60
	# [kind, floor, tier, min mean s, max mean s]. The windows bracket the combat model's 18 / 30 / 39 s for an average player at the
	# curve weapon (docs/design/dungeon_v2_workpackages.json, DR4). The daze lengths in lua/config/bosses.lua are tuned to them: after
	# review fixes DUN-08 (a hit keeps the full daze) and DUN-01 (no hits outside the drawn band) the model's 1.8 / 1.7 s dazes made
	# boss 1 take 38.9 s and boss 2 43.0 s with six 90 s leash resets; 2.4 / 2.0 s bring them to about 21 and 30 s.
	for spec in [["snurresvamp",4,1,12,30],["snurresvamp_gloed",8,2,20,50],["snurresvamp_konge",12,3,25,70]]:
		map.extra["floor"] = spec[1]
		GameManager.set_flag(&"dungeon_hearts_bonus",(int(spec[2])-1)*2)
		weapon["damage"] = DungeonRun.expected_weapon(int(spec[1]))
		t.check("curve_weapon_"+spec[0],is_equal_approx(DungeonRun.weapon_ratio("iron_sword",spec[1]),1.0))
		var results := []
		var good := 0
		var total := 0.0
		for value in count:
			world.player.revive(spawn)
			var at := spawn+Vector2(320,0)
			var boss: DungeonBoss2D = Enemy2D.create_marker({"kind":spec[0],"tier":spec[2],"persist":0},at,world.area.global_to_cell(at),world.area)
			boss.persist_cell = false
			boss.rng.seed = value
			world.area.objects.add_child(boss)
			var result: Dictionary = await DungeonFightBot.duel(t,world.player,boss,value,90,true)
			results.append(result)
			if (value+1)%15==0:t.info("%s: %d/%d seeded duels completed" % [spec[0],value+1,count])
			total += result.seconds
			if result.won and result.gross_lost<=12:good += 1
			await cleanup(t,world)
		var mean := total/count
		report.bosses[spec[0]] = {"mean_seconds":mean,"wins_within_12_gross_half_hearts":good,"count":count,"results":results}
		t.check("bot_beats_"+spec[0]+"_in_window",mean>=spec[3] and mean<=spec[4] and good>=ceili(count*.9),"mean %.3fs, %d/%d wins losing <=12 gross half hearts" % [mean,good,count])
	weapon["damage"] = original_damage
	GameManager.set_flag(&"dungeon_hearts_bonus",0)
	# The first ambush attack must really complete; attacking/revealing it
	# early would only test cancellation, not whether its leap can be dodged.
	var dodged := 0
	var trials := []
	for value in 100:
		world.player.revive(spawn)
		var at := spawn+Vector2(280,0)
		var enemy: Enemy2D = Enemy2D.create_marker({"kind":"ugleoje","tier":1,"ambush":1,"persist":0},at,world.area.global_to_cell(at),world.area)
		enemy.persist_cell = false
		world.area.objects.add_child(enemy)
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var reaction := clampf(rng.randfn(.4,.13),.12,.65)
		var lost := [0]
		var damage := func(amount):lost[0] += amount
		world.player.damaged.connect(damage)
		enemy.set_awake(true)
		await t.until(func():return enemy.state==Enemy2D.S.WINDUP,1)
		await t.seconds(reaction)
		DungeonFightBot.steer(Vector2(-enemy.aim.y,enemy.aim.x))
		var began: bool = world.player.combat.dodge()
		await t.until(func():return enemy.state==Enemy2D.S.RECOVER,2)
		DungeonFightBot.release()
		world.player.damaged.disconnect(damage)
		var ok: bool = began and enemy.ambush_state=="revealed" and enemy.state==Enemy2D.S.RECOVER and lost[0]==0
		if ok:dodged += 1
		trials.append({"seed":value,"reaction":reaction,"dodged":ok,"gross_lost":lost[0]})
		await cleanup(t,world)
	t.check("ambush_leap_dodgeable_85_percent",dodged>=85,"%d/100" % dodged)
	report["ambush"] = {"dodged":dodged,"count":100,"results":trials}
	var out := ProjectSettings.globalize_path("res://docs/qa/mechanics/combat/bot.json")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var file := FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	await world.travel(&"farm",&"default")
	WorldRoot2D.unregister_map(&"_combat_acceptance")
	GameManager.clear_config_overrides()
func cleanup(t,world: WorldRoot2D) -> void:
	for node in world.area.objects.get_children():
		if node is Enemy2D or node is LootDrop2D:node.queue_free()
	for node in world.area.ground_fx.get_children():
		if node is EnemyHazard2D:node.queue_free()
	await t.frames(2)
