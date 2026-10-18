extends RefCounted
const SECTION := "weapons"
class EnemyStub extends Node2D:
	var armor := false
	var rng := RandomNumberGenerator.new()
	var stun_time := 0.0
	var revealed := false
	var damage := 0
	func stun(seconds: float) -> void: stun_time = seconds
	func reveal() -> void: revealed = true
	func take_hit(amount: int, _from: Vector2, _player: Node) -> void: damage += amount
func run(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var player := world.player
	var eco: Node = t.autoload("EconomyManager")
	for id in ["sword_rusty","iron_sword","wpn_dagger_flint","wpn_club_oak","wpn_spear_iron","wpn_staff_hazel"]:
		var info := WeaponInfo.of(id)
		t.check("weapon_info_"+id,info.damage > 0 and info.cycle > 0 and is_equal_approx(info.rating,info.damage/info.cycle))
		t.check("sword_equivalent_"+id,is_equal_approx(WeaponInfo.sword_equivalent(id),info.damage*.4/info.cycle))
	t.check("unknown_weapon_safe",WeaponInfo.of("wood").is_empty())
	for rarity in ["normal","uncommon","rare","unique","legendary"]:
		var expected := {"normal":5,"uncommon":12,"rare":22,"unique":30,"legendary":42}
		for id in ItemKinds.all_ids("weapon"):
			var item := ItemKinds.def(id)
			if str(item.rarity) != rarity: continue
			var ratio := WeaponInfo.rating(id)/(float(expected[rarity])/.4)
			var family := str(item.get("weapon_family","sword"))
			t.check("dps_parity_"+str(id),ratio >= (.88 if family == "staff" else .9) and ratio <= 1.1,str(ratio))
	var enemy := EnemyStub.new()
	world.area.objects.add_child(enemy)
	enemy.add_to_group("enemy")
	enemy.global_position = player.global_position+Vector2(100,0)
	var supplied := {"id":"test","damage":10,"effect":{"id":"stun_chance","p":1.0,"s":.6}}
	WeaponFx.on_hit(player,enemy,supplied)
	t.check("stun_chance",enemy.stun_time == .6)
	enemy.armor = true
	enemy.stun_time = 0
	WeaponFx.on_hit(player,enemy,supplied)
	t.check("stun_respects_armor",enemy.stun_time == 0)
	WeaponFx.on_swing(player,{"id":"test","effect":{"id":"light_arc","radius_mult":1}})
	t.check("light_arc_reveals",enemy.revealed)
	player.combat._weapon = {"id":"test_oil","effect":{"id":"oil_on_kill","s":4}}
	player.oil = 10
	WeaponFx.on_kill(player,enemy)
	t.check("oil_on_kill",player.oil == 14)
	player.combat._weapon = {"id":"test_heart","effect":{"id":"heart_on_kill","every":4}}
	player.half_hearts = player.max_half_hearts-2
	for i in 4: WeaponFx.on_kill(player,enemy)
	t.check("heart_on_kill",player.half_hearts == player.max_half_hearts-1)
	for id in ["moon_wave","quake"]:
		enemy.damage = 0
		player.event_face(Vector2.RIGHT)
		player.mouse_aim = false
		for i in 4: WeaponFx.on_swing(player,{"id":"test_"+id,"damage":10,"effect":{"id":id,"every":4,"mult":.6,"radius":160,"range":360}})
		t.check(id+"_every_four_swings",enemy.damage == 6,str(enemy.damage))
	var light := WeaponFx.on_light(player,{"cooldown":1,"radius":100,"stun":1,"weapon":{"effect":{"id":"light_boost","cd_minus_s":2,"radius_mult":1.3,"stun_bonus_s":.8}}})
	t.check("light_boost_and_minimum",light.cooldown == 3 and light.radius == 130 and light.stun == 1.8)
	for id in ["gem_rock_crystal","gem_thornberry_stone","gem_night_sapphire","gem_sunset_stone","gem_rune_heart","emerald"]:
		var effects := LanternGem.effects(id)
		t.check("gem_effects_"+id,effects.oil_mult <= 1 and effects.radius_mult >= 1 and effects.pickup_mult >= 1 and effects.chest_sense_cells <= 12 and LanternGem.can_equip(id))
	var rune := LanternGem.effects("gem_rune_heart")
	t.check("legendary_gem_all_six_themes",is_equal_approx(rune.oil_mult,.84) and is_equal_approx(rune.radius_mult,1.16) and rune.light_cd_minus_s == 2 and rune.chest_sense_cells == 12 and is_equal_approx(rune.ambush_mult,1.8) and is_equal_approx(rune.pickup_mult,1.8))
	eco.add_item(&"gem_rune_heart",1,true)
	eco.add_item(&"wpn_spear_root",1,true)
	eco.equip(&"weapon",&"wpn_spear_root")
	t.check("gem_equip_slot",eco.equip_slot_of("gem_rune_heart") == "accessory" and eco.equip(&"accessory",&"gem_rune_heart") and LanternGem.equipped() == &"gem_rune_heart")
	t.check("chest_sense_is_max_not_sum",DungeonRun.chest_sense_cells() == 12)
	t.check("real_player_gem_wiring",is_equal_approx(player._gem_effects().oil_mult,.84))
	eco.add_item(&"wpn_staff_star",1,true)
	eco.equip(&"weapon",&"wpn_staff_star")
	player.combat.cooldowns.light = 0
	player.combat.fairy_light()
	t.check("real_player_light_boost_and_gem_cooldown",player.combat.durations.light == 3 and enemy.stun_time >= 2.3)
	var info: Dictionary = player.combat._read_weapon(&"wpn_staff_star")
	t.check("real_player_family_swing_parameters",info.swing_time == .34 and info.swing_cooldown == .16 and info.swing_half_angle_deg == 48)
	eco.add_item(&"moonstone",1,true)
	t.check("existing_gem_can_equip",eco.equip(&"accessory",&"moonstone"))
	enemy.queue_free()
	player.combat._weapon = {}
	await t.frames(2)
