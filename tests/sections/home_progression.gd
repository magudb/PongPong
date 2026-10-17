extends RefCounted
const SECTION := "home_progression"
const TIMEOUT_S := 180.0
func run(t) -> void:
	await t.start_world()
	var home: Node = t.autoload("HomeManager")
	var furniture: Node = t.autoload("FurnitureManager")
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	for tier in range(2,11):
		var grant := Grant.requirements(tier)
		t.check("tier_%d_requirements_reachable_with_real_grid" % tier,grant.ok,str(grant.missing))
		t.check("tier_%d_gate_accepts" % tier,home.can_start_upgrade().ok,str(home.can_start_upgrade()))
		if not home.can_start_upgrade().ok: return
		var owned := {}
		for id in furniture.owned_ids(): owned[id] = furniture.count_total(id)
		var start_gold: int = eco.gold
		var result: Dictionary = home.start_upgrade()
		t.check("tier_%d_payment_commits" % tier,result.ok and eco.gold == start_gold - home.gold_cost(tier))
		var wire: Dictionary = JSON.parse_string(JSON.stringify(saves.gather_payload()))
		var load_result: Dictionary = saves._apply_payload(wire)
		t.check("tier_%d_mid_construction_roundtrip" % tier,load_result.ok and home.construction.target == tier)
		for _day in home.build_days(tier): gm.end_day()
		await t.frames(2)
		t.check("tier_%d_completes_in_absolute_days" % tier,home.tier == tier and not home.is_under_construction())
		var conserved := true
		for id in owned: conserved = conserved and furniture.count_total(id) >= owned[id]
		t.check("tier_%d_preserves_every_owned_piece" % tier,conserved)
		t.check("tier_%d_storage_capacity_live" % tier,furniture.ensure_grid().max_items == home.furniture_capacity())
		t.check("tier_%d_hygge_perks_reach_shared_caps" % tier,Perks.total("energy") >= home.max_energy_bonus() and Perks.total("energy") <= 60.0)
	t.check("castle_and_final_gifts_real",home.tier == 10 and furniture.count_total("bed_moon") == 1 and furniture.count_total("chandelier_star") == 1)
