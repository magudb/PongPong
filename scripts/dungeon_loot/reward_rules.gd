class_name DungeonRewardRules
extends RefCounted
const P := preload("res://scripts/dungeon_loot/loot_plan.gd")
static func boss_result(state: Dictionary, req: Dictionary) -> Dictionary:
	var id := str(req.get("boss",""))
	var cfg := LuaData.dict(req.cfg.get("boss",{}).get(id,{}))
	if cfg.is_empty(): return P.failure("unknown_boss")
	var bosses := LuaData.dict(state.get("boss",{})).duplicate(true)
	var record := LuaData.dict(bosses.get(id,{})).duplicate(true)
	var uid := str(req.get("uid",""))
	if uid != "" and uid == str(record.get("last_uid","")): return P.success(state,req,[],{},false)
	var rows := []
	var first := not bool(record.get("first_done",false))
	if first:
		for item in LuaData.strings(cfg.get("first_kill_items",[])): rows.append(P.row(req,item))
		for item in LuaData.dict(cfg.get("first_kill_extra",{})): rows.append(P.row(req,item,int(cfg.first_kill_extra[item])))
		record["first_done"] = true
		record["pool_left"] = LuaData.strings(cfg.get("pool",[]))
		record["misses"] = 0
	else:
		if int(req.day)-int(record.get("last_day",0)) < int(cfg.get("respawn_days",7)): return P.success(state,req,[],{},false)
		var chest_req := req.duplicate()
		chest_req["container"] = str(cfg.get("chest","konge"))
		var chest := LootRules.container_cfg(req.cfg,str(req.get("zone","")),str(chest_req.container))
		for i in P.range_i(req.rng,int(chest.get("rolls",{}).get("min",2)),int(chest.get("rolls",{}).get("max",2))):
			var row := DungeonContainerRules.ordinary({},chest_req,chest)
			if not row.is_empty(): rows.append(row)
		var left := LuaData.strings(record.get("pool_left",cfg.get("pool",[])))
		left = left.filter(func(item): return not state.get("found",{}).has(item))
		if left.is_empty(): rows.append(P.row(req,str(cfg.get("exhausted_item","dng_glimmer_dust")),int(cfg.get("exhausted_amount",2))))
		else:
			var misses := int(record.get("misses",0))+1
			if P.chance(req.rng,int(cfg.get("legendary_bp",0))) or misses >= int(cfg.get("pity_kills",10)):
				var item := left[P.below(req.rng,left.size())]
				rows.append(P.row(req,item))
				left.erase(item)
				misses = 0
			record["misses"] = misses
			record["pool_left"] = left
	record["last_day"] = int(req.day)
	record["last_uid"] = uid
	record["kills"] = int(record.get("kills",0))+1
	bosses[id] = record
	return P.success(state,req,rows,{"boss":bosses},false)
static func spot_state(state: Dictionary, req: Dictionary) -> StringName:
	var id := str(req.get("spot",""))
	var spec := LuaData.dict(req.cfg.get("spots",{}).get(id,{}))
	if spec.is_empty(): return &"locked"
	if state.get("claimed",{}).has(id) or state.get("found",{}).has(str(spec.get("item",""))): return &"claimed"
	if not P.rules(req).get("bands",{}).has(str(spec.get("zone",""))): return &"open"
	return &"open" if P.unique_ready(state,int(req.day),int(P.rules(req).get("unique",{}).get("cooldown_days",7))) else &"cooldown"
static func roll_spot(state: Dictionary, req: Dictionary) -> Dictionary:
	var status := spot_state(state,req)
	if status != &"open": return P.failure(str(status))
	var id := str(req.spot)
	var claimed := LuaData.dict(state.get("claimed",{})).duplicate()
	claimed[id] = int(req.day)
	return P.success(state,req,[P.row(req,str(req.cfg.spots[id].item))],{"claimed":claimed,"unique_day":int(req.day)},false)
static func appraisal_quote(cfg: Dictionary, rough: String) -> Dictionary:
	var band := rough.trim_prefix("rough_")
	var fees := LuaData.dict(cfg.get("_dungeon_rules",{}).get("appraisal",{}).get("fee",{}))
	return {"band":band,"fee":int(fees[band])} if rough.begins_with("rough_") and fees.has(band) else {"band":"","fee":0}
static func roll_appraisal(state: Dictionary, req: Dictionary) -> Dictionary:
	var band := str(req.get("band",""))
	var config := LuaData.dict(P.rules(req).get("appraisal",{}))
	var odds := LuaData.dict(config.get("odds",{}).get(band,{}))
	if odds.is_empty(): return P.failure("unknown_stone")
	if P.capped(state,req):
		odds = odds.duplicate()
		odds["normal"] = float(odds.get("normal",0))+float(odds.get("rare",0))
		odds["rare"] = 0
	var rarity := P.weighted(req.rng,LootRules.luck_odds(odds,float(req.get("luck",0))))
	var item := P.pool(req.rng,LuaData.arr(config.get("pools",{}).get(rarity,[])))
	if item == "": return P.failure("empty_pool")
	var counters := LuaData.dict(state.get("appraise",{})).duplicate()
	counters[band] = int(counters.get(band,0))+1
	return P.success(state,req,[P.row(req,item)],{"appraise":counters})
