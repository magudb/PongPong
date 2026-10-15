extends RefCounted
## D0: gentle defeat and the 02:00 wake location, exercised through the live world.
const SECTION := "dungeon_defeat"
const TIMEOUT_S := 120.0

func run(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	var save: Node = t.autoload("SaveManager")
	var old_auto: bool = save.autosave_enabled
	var old_speed := Engine.time_scale
	save.autosave_enabled = false
	Engine.time_scale = 8.0
	for gold in [0, 9, 10, 99, 100, 1999, 999999]:
		gm.hour = 12
		gm.minute = 0
		eco.add_gold(gold - int(eco.gold))
		var inventory: Dictionary = eco.get_inventory_dict().duplicate(true)
		var equipment: Dictionary = eco.equipment.duplicate(true)
		var day: int = gm.total_day()
		world.call("_enter", &"_fixture_ortho", &"default")
		world.player.set("half_hearts", 1)
		bus.player_defeated.emit()
		bus.player_defeated.emit()
		await t.until(func() -> bool: return not world._faint_pending, 10.0)
		t.check("gold_%d" % gold, eco.gold == gold - floori(float(gold) * 0.1), "10 percent rounded down, with duplicate defeat requests guarded")
		t.expect(gm.total_day() == day + 1 and gm.hour == gm.day_start_hour(), "defeat advances exactly one morning")
		t.expect(world.area.map.id == &"farm" and world.player.global_position.distance_to(world.area.get_spawn("from_home")) < 1.0, "wake at the farmhouse door")
		t.expect(eco.get_inventory_dict() == inventory and eco.equipment == equipment, "items and equipment survive defeat")
		t.expect(world.player.get("half_hearts") == world.player.get("max_half_hearts"), "health restored")
	# Day-end pass-out moves the player home without charging gold.
	gm.hour = gm.day_end_hour() - 1
	gm.minute = 50
	var before: int = eco.gold
	world.call("_enter", &"hyggebyen", &"default")
	gm.advance_time(20)
	await t.until(func() -> bool: return not world.sleeping, 10.0)
	t.check("passout_wakes_at_home_without_fee", world.area.map.id == &"farm" and eco.gold == before and world.player.global_position.distance_to(world.area.get_spawn("from_home")) < 1.0, "02:00 pass-out returns home without defeat penalties")
	var qm: Node = t.autoload("QuestManager")
	qm.accept_quest(&"snurresvampen")
	bus.area_changed.emit(&"moerkeskoven_f4")
	bus.enemy_defeated.emit(&"boss", &"snurresvamp", [])
	bus.dialogue_started.emit(&"guard_oak", &"guard_oak")
	t.check("boss_quest_binds_floor_four", qm.is_completed(&"snurresvampen"), "real floor, boss and turn-in signals complete the quest")
	Engine.time_scale = old_speed
	save.autosave_enabled = old_auto
	gm.clear_config_overrides()
