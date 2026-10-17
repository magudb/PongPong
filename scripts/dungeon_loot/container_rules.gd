class_name DungeonContainerRules
extends RefCounted
const P := preload("res://scripts/dungeon_loot/loot_plan.gd")
static func depth_odds(cfg: Dictionary, tier: String, number: int, luck: float, override: Dictionary = {}) -> Dictionary:
	var base := override if not override.is_empty() else LuaData.dict(cfg.get("containers",{}).get(tier,{}).get("odds",{}))
	var depth := LuaData.dict(cfg.get("_dungeon_rules",{}).get("depth",{}))
	var step := 1+float(depth.get("rarity_step",.1))*(clampi(number,1,int(depth.get("cap_floor",12)))-1)
	var normal := float(base.get("normal",0))
	var uncommon := float(base.get("uncommon",0))*step
	var rare := float(base.get("rare",0))*step*step
	var total := maxf(1,normal+uncommon+rare)
	var mult := 1+float(depth.get("luck_mult",5))*clampf(luck,0,.2)
	uncommon = uncommon/total*10000*mult
	rare = rare/total*10000*mult
	if uncommon+rare > 10000:
		var scale := 10000/(uncommon+rare)
		uncommon *= scale
		rare *= scale
	return {"normal":10000-uncommon-rare,"uncommon":uncommon,"rare":rare}
static func ordinary(state: Dictionary, req: Dictionary, container: Dictionary) -> Dictionary:
	var rng: Object = req.rng
	if not P.chance(rng,roundi(float(container.get("find_chance",1))*10000)): return {}
	var cfg := LuaData.dict(req.cfg)
	var zone := str(req.get("band",req.get("zone","skovkant")))
	if zone == "": zone = str(req.get("zone","skovkant"))
	var pools := LuaData.dict(cfg.get("zones",{}).get(zone,{}).get("pools",{}))
	var ceiling := P.capped(state,req)
	var kinds := LuaData.dict(P.rules(req).get("daily",{}).get("kinds",{"material":70,"gem":30})) if ceiling else LuaData.dict(container.get("kinds",{}))
	var kind := P.weighted(rng,kinds)
	var floor_number := int(req.get("ctx",{}).get("floor",P.rules(req).get("bands",{}).get(zone,{}).get("from",1)))
	var odds := depth_odds(cfg,str(req.get("container","trae")),floor_number,float(req.get("luck",0)),LuaData.dict(container.get("odds",{})))
	var rarity := P.weighted(rng,odds)
	if ceiling and rarity == "rare": rarity = "normal"
	var rows := LuaData.arr(pools.get(kind,{}).get(rarity,[]))
	if kind != "gem" and rows.is_empty():
		var eligible := {}
		for candidate in kinds:
			if str(candidate) == "gem" or not LuaData.arr(pools.get(candidate,{}).get(rarity,[])).is_empty(): eligible[candidate] = kinds[candidate]
		kind = P.weighted(rng,eligible)
		rows = LuaData.arr(pools.get(kind,{}).get(rarity,[]))
	if kind == "gem": return P.row(req,P.rules(req).get("bands",{}).get(zone,{}).get("rough","rough_"+zone))
	rows = rows.filter(func(row): return str(P.fact(req,row.item).get("rarity","")) in ["normal","uncommon","rare"])
	return P.row(req,P.pool(rng,rows))
static func roll(state: Dictionary, req: Dictionary) -> Dictionary:
	var cfg := LuaData.dict(req.cfg)
	var zone := str(req.get("zone",req.get("band","skovkant")))
	var tier := str(req.get("container","trae"))
	var container := LootRules.container_cfg(cfg,zone,tier)
	if container.is_empty(): return P.failure("unknown_container")
	var rng: Object = req.rng
	var rolls := LuaData.dict(container.get("rolls",{}))
	var count := P.range_i(rng,int(rolls.get("min",1)),int(rolls.get("max",1)))
	var rows := []
	var delta := {}
	var wander := LuaData.dict(state.get("wander",{})).duplicate(true)
	var key := zone+":"+tier
	var record := LuaData.dict(wander.get(key,{}))
	var available := LuaData.arr(cfg.get("zones",{}).get(zone,{}).get("wanderers",[])).filter(func(row): return str(row.get("container","")) == tier and not state.get("found",{}).has(str(row.item)))
	if not available.is_empty() and int(container.get("wander_bp",0)) > 0 and P.unique_ready(state,int(req.day),int(P.rules(req).get("unique",{}).get("cooldown_days",7))):
		var success := P.chance(rng,roundi(float(container.wander_bp)*(1+5*clampf(float(req.get("luck",0)),0,.2))))
		var misses := int(record.get("misses",0))+1
		if success or (int(container.get("pity_opens",0)) > 0 and misses >= int(container.pity_opens)):
			rows.append(P.row(req,available[0].item))
			misses = 0
			delta.unique_day = int(req.day)
		record["misses"] = misses
		wander[key] = record
		delta.wander = wander
	for i in maxi(0,count-rows.size()):
		var row := ordinary(state,req,container)
		if not row.is_empty(): rows.append(row)
	var plan := P.success(state,req,rows,delta)
	if tier not in ["dig","konge"]: plan["surprise"] = surprise(state,req)
	return plan
static func surprise(state: Dictionary, req: Dictionary) -> Dictionary:
	var draw := P.range_i(req.rng,1,10000)
	for row in LuaData.arr(P.rules(req).get("surprises",[])):
		draw -= int(row.get("bp",0))
		if draw > 0: continue
		var result := {"id":str(row.id)}
		match str(row.id):
			"firefly_swarm": result.oil_s = int(row.get("oil_s",15))
			"acorn_purse": result.gold = P.range_i(req.rng,int(row.gold[0]),int(row.gold[1]))
			"cocoa_thermos": result.heal_half_hearts = int(row.get("heal_half_hearts",2))
			"pip_note":
				result.hint_key = "DTUT_RUNE"
				for id in req.cfg.get("spots",{}):
					var spot := LuaData.dict(req.cfg.spots[id])
					if str(spot.get("zone","")) == str(req.get("zone","")) and not state.get("claimed",{}).has(id):
						result.hint_key = str(spot.get("hint_key","DTUT_RUNE"))
						break
		return result
	return {}
