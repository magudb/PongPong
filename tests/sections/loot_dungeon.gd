extends RefCounted
const SECTION := "loot_dungeon"
const TIMEOUT_S := 180.0
func _request(loot: Node, key: String, overrides: Dictionary = {}) -> Dictionary:
	var req := {"cfg":loot._delegate_config(),"rng":DungeonRng.new(42),"uid":key,"zone":"skovkant","band":"skovkant","day":1,"luck":0.0,"ctx":{"floor":1},"container":"trae"}
	req.merge(overrides,true)
	return req
func run(t) -> void:
	await t.start_world()
	var loot: Node = t.autoload("LootService")
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	var req := _request(loot,"pure")
	var state := {"found":{},"claimed":{},"unique_day":0}
	var before := JSON.stringify(state)
	var plan := DungeonLootRules.roll_container(state,req)
	t.check("pure_plan_does_not_mutate_state",plan.ok and JSON.stringify(state) == before)
	var repeated := DungeonLootRules.roll_container(state,_request(loot,"pure"))
	t.check("same_seed_same_plan",JSON.stringify(plan) == JSON.stringify(repeated))
	t.check("depth_odds_first_floor",DungeonLootRules.depth_odds(req.cfg,"trae",1,0) == {"normal":7800.0,"uncommon":2100.0,"rare":100.0})
	var odds := DungeonLootRules.depth_odds(req.cfg,"fe",12,.2)
	t.check("depth_ladder_pinned_floor_twelve",odds.normal == 0 and absf(odds.rare/100-24.0374) < .02 and absf(odds.uncommon/100-75.9626) < .02,str(odds))
	var value := {"results":[{"id":"wood","amount":2},{"id":"wood","amount":4},{"id":"iron_sword","amount":1}]}
	t.check("aggregate_fit_rejects_two_new_stacks",not DungeonLootRules.fits(value,{"free_slots":0,"stack_room":{"wood":5},"max_stack":{"wood":99},"own_store":{"iron_sword":true}}))
	t.check("aggregate_fit_uses_one_slot_and_own_store",DungeonLootRules.fits(value,{"free_slots":1,"stack_room":{"wood":5},"max_stack":{"wood":99},"own_store":{"iron_sword":true}}))
	var packs := []
	for i in 24: packs.append({"id":"wood","amount":99})
	eco.from_dict({"v":1,"gold":1000,"inventory":packs,"equipment":{},"arsenal":{}})
	loot.reset()
	var cfg: Dictionary = loot.loot_cfg().duplicate(true)
	# A mixed own-store + backpack plan exercises the real transaction, not a fake delegate.
	cfg.containers.test_mixed = {"rolls":{"min":2,"max":2},"find_chance":1,"odds":{"normal":10000},"kinds":{"material":100}}
	cfg.zones.skovkant.pools.material.normal = [{"item":"copper_ore","w":1}]
	loot.set_loot_config(cfg)
	var snapshot := JSON.stringify([eco.to_dict(),loot.to_dict()])
	var context := {"dungeon":true,"floor":1,"band":"skovkant"}
	for i in 50:
		var result: Dictionary = loot.open_container("skovkant","test_mixed","dg:1:1:123",context)
		t.check("full_retry_%d" % i,not result.ok and result.reason == &"full" and result.results.is_empty())
	t.check("retry_after_full_changes_no_state",JSON.stringify([eco.to_dict(),loot.to_dict()]) == snapshot)
	eco.remove_item(&"wood",99)
	var opened: Dictionary = loot.open_container("skovkant","test_mixed","dg:1:1:123",context)
	t.check("free_slot_delivers_both_once",opened.ok and eco.count_item(&"copper_ore") == 2)
	loot.set_loot_config()
	loot.reset()
	eco.reset()
	eco.add_gold(1000)
	eco.add_item(&"rough_skovkant",2,true)
	var old_count: int = eco.count_item(&"rough_skovkant")
	var gold: int = eco.gold
	var appraised: Dictionary = loot.appraise("rough_skovkant",{"save":false})
	t.check("appraisal_counter_stone_fee_one_commit",appraised.ok and eco.count_item(&"rough_skovkant") == old_count-1 and eco.gold == gold-30 and int(loot.dungeon.get("appraise",{}).get("skovkant",0)) == 1)
	t.check("appraisal_unknown_rejected",not loot.appraise("wood",{"save":false}).ok)
	loot.reset()
	# Keep a real pre-existing stack; the appraisal above can also have awarded moonstone.
	eco.add_item(&"moonstone",7,true)
	var moonstone_before: int = eco.count_item(&"moonstone")
	var boss_ctx := {"dungeon":true,"floor":8,"band":"svampelunden","uid":"dg:1:8:boss"}
	var reward: Dictionary = loot.on_boss_defeated("snurresvamp_gloed",boss_ctx)
	t.check("boss_first_kill_shard_and_two_moonstone",reward.ok and eco.count_item(&"dng_rune_gloed") == 1 and eco.count_item(&"moonstone") == moonstone_before+2 and loot.dungeon.boss.snurresvamp_gloed.first_done)
	var prior: int = eco.count_item(&"moonstone")
	t.check("boss_idempotent_per_uid",loot.on_boss_defeated("snurresvamp_gloed",boss_ctx).ok and eco.count_item(&"moonstone") == prior)
	eco.add_item(&"dng_rune_snurre",1,true)
	eco.add_item(&"dng_rune_konge",1,true)
	var vault: Dictionary = loot.claim_spot("runehvaelvingen",{"dungeon":true,"floor":11,"band":"krystalgrotten","uid":"dg:1:11:vault"})
	t.check("rune_chain_consumes_three_shards_once",vault.ok and eco.count_item(&"gem_rune_heart") == 1 and not eco.has_item(&"dng_rune_snurre") and not eco.has_item(&"dng_rune_gloed") and not eco.has_item(&"dng_rune_konge"))
	t.check("vault_claimed_permanently",loot.spot_state("runehvaelvingen") == &"claimed" and loot.found("gem_rune_heart"))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(loot.to_dict()))
	loot.reset()
	t.check("save_roundtrip_found_and_claims",loot.from_dict(saved) and loot.found("gem_rune_heart") and loot.spot_state("runehvaelvingen") == &"claimed")
	_boss_stacks(t,loot,eco)
	await _more(t,loot,eco,gm)
	gm.set_flag(&"loot_test_finished",true)
func _boss_stacks(t, loot: Node, eco: Node) -> void:
	for owned in [0,7]:
		loot.reset()
		eco.reset()
		if owned > 0: eco.add_item(&"moonstone",owned,true)
		var context := {"dungeon":true,"floor":8,"band":"svampelunden","uid":"dg:1:8:stack_%d" % owned}
		var reward: Dictionary = loot.on_boss_defeated("snurresvamp_gloed",context)
		var amounts := {}
		for row in reward.results:
			amounts[str(row.id)] = int(row.amount)
		t.check("boss_exact_reward_rows_stack_%d" % owned,reward.ok and reward.results.size() == 2 and amounts == {"dng_rune_gloed":1,"moonstone":2})
		t.check("boss_exact_gain_stack_%d" % owned,eco.count_item(&"moonstone") == owned+2 and eco.count_item(&"dng_rune_gloed") == 1 and loot.dungeon.boss.snurresvamp_gloed.first_done)
		var before := JSON.stringify([eco.to_dict(),loot.to_dict()])
		var repeated: Dictionary = loot.on_boss_defeated("snurresvamp_gloed",context)
		t.check("boss_repeat_preserves_stack_%d" % owned,repeated.ok and repeated.results.is_empty() and JSON.stringify([eco.to_dict(),loot.to_dict()]) == before)
func _more(t, loot: Node, eco: Node, gm: Node) -> void:
	var req := _request(loot,"rates",{"zone":"krystalgrotten","band":"krystalgrotten","ctx":{"floor":12},"container":"fe"})
	var spec := LootRules.container_cfg(req.cfg,"krystalgrotten","fe")
	spec["kinds"] = {"material":100}
	var counts := {"normal":0,"uncommon":0,"rare":0}
	var keepsakes := 0
	for i in 20000:
		var row := DungeonContainerRules.ordinary({},req,spec)
		if row.is_empty(): continue
		if row.rarity in counts: counts[row.rarity] += 1
		else: keepsakes += 1
	var odds := DungeonLootRules.depth_odds(req.cfg,"fe",12,0)
	t.info("LOOT_MC "+JSON.stringify({"tier":"fe","floor":12,"luck":0,"n":20000,"counts":counts}))
	for rarity in counts:
		t.check("rates_20000_"+rarity,absf(float(counts[rarity])/20000-float(odds[rarity])/10000) <= .015,str(counts))
	t.check("legendary_never_from_ordinary_chests",keepsakes == 0)
	var bad_state := {"found":{"a":2.0},"claimed":{"b":3.0},"boss":{"x":{"first_done":true,"last_day":4.0,"pool_left":["gem_rune_heart"]}},"appraise":{"skovkant":7.0},"day":{"day":5.0,"value":100.0,"capped":true},"unique_day":6.0}
	var normalized := DungeonLootRules.from_dict(bad_state)
	t.check("state_normalizes_json_numbers",normalized.found.a is int and normalized.appraise.skovkant == 7 and normalized.boss.x.last_day == 4 and normalized.boss.x.first_done)
	loot.reset()
	eco.reset()
	eco.add_item(&"rough_skovkant",2,true)
	eco.add_item(&"rough_dybe_bregner",2,true)
	eco.add_gold(1000)
	var seed_state: Dictionary = loot.to_dict()
	var inventory: Dictionary = eco.to_dict()
	var first: Dictionary = loot.appraise("rough_skovkant",{"save":false})
	loot.from_dict(seed_state)
	eco.from_dict(inventory)
	loot.appraise("rough_dybe_bregner",{"save":false})
	var second: Dictionary = loot.appraise("rough_skovkant",{"save":false})
	t.check("appraisal_streams_independent_per_band",first.ok and second.ok and first.gem == second.gem and first.rarity == second.rarity)
	var sm: Node = t.autoload("SaveManager")
	var last: Dictionary = loot.appraise("rough_skovkant")
	var wire: Variant = JSON.parse_string(FileAccess.get_file_as_string(sm.slot_path(sm.AUTO_SLOT)))
	t.check("appraisal_saves_before_return",last.ok and wire is Dictionary and JSON.stringify(wire).contains('"skovkant":2'))
	loot.reset()
	eco.reset()
	var capped := {"day":{"day":gm.total_day(),"value":3200,"capped":true}}
	var cap_req := _request(loot,"cap",{"day":gm.total_day(),"zone":"krystalgrotten","band":"krystalgrotten","ctx":{"floor":12},"container":"fe","luck":.2})
	var cap_ok := true
	for i in 1000:
		var plan := DungeonLootRules.roll_container(capped,cap_req)
		for row in plan.results:
			if row.rarity in ["normal","uncommon"]: cap_ok = cap_ok and row.kind in ["material","gem"]
			elif row.rarity != "unique": cap_ok = false
	t.check("daily_cap_binds_ordinary_rolls",cap_ok)
	t.check("daily_cap_resets_next_day",not DungeonLootPlan.capped(capped,_request(loot,"tomorrow",{"day":gm.total_day()+1})))
	loot.reset()
	eco.add_item(&"ugle_noegle",1,true)
	var key_count: int = eco.count_item(&"ugle_noegle")
	var lake: Dictionary = loot.claim_spot("soeskatten_skov",{"dungeon":true,"floor":3,"band":"skovkant","uid":"dg:1:3:lake"})
	t.check("lake_key_consumed_first_gem_once",lake.ok and eco.count_item(&"ugle_noegle") == key_count-1 and eco.count_item(&"gem_dewdrop") == 1 and loot.spot_state("soeskatten_skov") == &"claimed")
	var cooldown: Dictionary = loot.claim_spot("lysstubben",{"dungeon":true,"floor":7,"band":"svampelunden","uid":"dg:1:7:candle"})
	t.check("hunted_unique_cooldown_does_not_consume",not cooldown.ok and cooldown.reason == &"cooldown" and not eco.has_item(&"wpn_sword_candle"))
	var good_node := true
	for i in 100:
		var node_req := _request(loot,"node",{"node_kind":"moonstone","band":"krystalgrotten","zone":"krystalgrotten"})
		node_req.rng = DungeonRng.new(i)
		var node := DungeonLootRules.roll_node({},node_req)
		good_node = good_node and node.ok and not node.results.is_empty()
	t.check("crystal_alias_always_yields_rough_or_dust",good_node)
	loot.reset()
	eco.reset()
	eco.add_item(&"wpn_club_oak",9,true)
	var gold_before: int = eco.gold
	var duplicate: Dictionary = loot.deliver("wpn_club_oak",1)
	t.check("duplicate_weapon_sold_at_store_cap",duplicate.ok and duplicate.sold and eco.count_item(&"wpn_club_oak") == 9 and eco.gold == gold_before+eco.sell_value("wpn_club_oak"))
	var boss_req := _request(loot,"weekly",{"boss":"snurresvamp_gloed","band":"svampelunden","zone":"svampelunden","day":1,"ctx":{"floor":8}})
	boss_req.cfg = boss_req.cfg.duplicate(true)
	boss_req.cfg.boss.snurresvamp_gloed.legendary_bp = 0
	boss_req.cfg.boss.snurresvamp_gloed.pity_kills = 3
	var first_boss := DungeonLootRules.boss_result({},boss_req)
	var boss_state := DungeonLootRules.commit({},first_boss)
	boss_req.day = 7
	boss_req.uid = "early"
	var early := DungeonLootRules.boss_result(boss_state,boss_req)
	t.check("boss_weekly_cooldown_keeps_state",early.ok and early.results.is_empty() and DungeonLootRules.commit(boss_state,early) == boss_state)
	var legendary := []
	for i in 3:
		boss_req.day = 8+i*7
		boss_req.uid = "repeat_%d" % i
		var paid := DungeonLootRules.boss_result(boss_state,boss_req)
		boss_state = DungeonLootRules.commit(boss_state,paid)
		legendary.append(paid.results.filter(func(row): return row.rarity == "legendary").size())
	t.check("boss_pool_pity_read_from_data",legendary == [0,0,1],str(legendary))
	var wander_req := _request(loot,"wander")
	wander_req.cfg = wander_req.cfg.duplicate(true)
	wander_req.cfg.containers.trae.wander_bp = 1
	wander_req.cfg.containers.trae.pity_opens = 2
	var wander_state := {}
	for i in 2:
		var paid := DungeonLootRules.roll_container(wander_state,wander_req)
		wander_state = DungeonLootRules.commit(wander_state,paid)
	t.check("wanderer_pity_and_cooldown",wander_state.unique_day == 1 and wander_state.wander["skovkant:trae"].misses == 0)
	var waiting := DungeonLootRules.roll_container(wander_state,wander_req)
	t.check("cooldown_does_not_advance_pity",waiting.next.wander["skovkant:trae"].misses == 0 and waiting.results.all(func(row): return row.rarity != "unique"))
