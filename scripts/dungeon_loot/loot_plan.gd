class_name DungeonLootPlan
extends RefCounted
## Pure helpers. Runtime data and the keyed RNG are supplied in req; no service lookup here.
static func rules(req: Dictionary) -> Dictionary:
	return LuaData.dict(req.get("cfg",{}).get("_dungeon_rules",{}))
static func fact(req: Dictionary, id: Variant) -> Dictionary:
	return LuaData.dict(req.get("cfg",{}).get("_items",{}).get(str(id),{}))
static func row(req: Dictionary, id: Variant, amount: int = 1) -> Dictionary:
	var item := fact(req,id)
	if item.is_empty() or amount <= 0: return {}
	var category := str(item.get("category","material"))
	return {"id":str(id),"amount":amount,"rarity":str(item.get("rarity","normal")),"kind":category if category in ["weapon","gem","furniture","clothing"] else "material"}
static func below(rng: Object, n: int) -> int:
	if n <= 0: return 0
	return int(rng.below(n)) if rng.has_method("below") else int(rng.randi_range(0,n-1))
static func range_i(rng: Object, first: int, last: int) -> int:
	return first+below(rng,maxi(1,last-first+1))
static func chance(rng: Object, bp: int) -> bool:
	return below(rng,10000) < clampi(bp,0,10000)
static func weighted(rng: Object, weights: Dictionary) -> String:
	var total := 0.0
	for key in weights: total += maxf(0,float(weights[key]))
	if total <= 0: return ""
	var draw := below(rng,1000000)/1000000.0*total
	var last := ""
	for key in weights:
		if float(weights[key]) <= 0: continue
		last = str(key)
		draw -= float(weights[key])
		if draw < 0: return last
	return last
static func pool(rng: Object, rows: Array) -> String:
	var weights := {}
	for item in rows: weights[str(item.item)] = float(item.get("w",1))
	return weighted(rng,weights)
static func failure(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"results":[]}
static func unique_ready(state: Dictionary, day: int, cooldown: int = 7) -> bool:
	return int(state.get("unique_day",0)) <= 0 or day-int(state.get("unique_day",0)) >= cooldown
static func capped(state: Dictionary, req: Dictionary) -> bool:
	var day := LuaData.dict(state.get("day",{}))
	return int(day.get("day",0)) == int(req.day) and int(day.get("value",0)) >= int(rules(req).get("daily",{}).get("value_cap",1400))
static func success(state: Dictionary, req: Dictionary, rows: Array, delta: Dictionary = {}, counts_value: bool = true) -> Dictionary:
	var next := state.duplicate(true)
	for key in delta: next[key] = delta[key]
	var value := 0
	for item in rows: value += maxi(0,int(fact(req,item.id).get("sell_price",0)))*int(item.amount)
	if counts_value:
		var day := LuaData.dict(next.get("day",{}))
		var accumulated := int(day.get("value",0)) if int(day.get("day",0)) == int(req.day) else 0
		next["day"] = {"day":int(req.day),"value":mini(1000000000,accumulated+value),"capped":accumulated+value >= int(rules(req).get("daily",{}).get("value_cap",1400))}
	return {"ok":true,"reason":"","results":rows,"next":next,"value":value}
static func commit(state: Dictionary, plan: Dictionary) -> Dictionary:
	var next := LuaData.dict(plan.get("next",state)).duplicate(true)
	var found := LuaData.dict(next.get("found",{})).duplicate()
	found.merge(LuaData.dict(state.get("found",{})),true)
	next["found"] = found
	return next
static func fits(plan: Dictionary, view: Dictionary) -> bool:
	var slots := 0
	var needs := {}
	for row in LuaData.arr(plan.get("results",[])):
		var id := str(row.id)
		if bool(view.get("own_store",{}).get(id,false)): continue
		needs[id] = int(needs.get(id,0))+int(row.amount)
	for id in needs:
		var left := maxi(0,int(needs[id])-int(view.get("stack_room",{}).get(id,0)))
		var stack := maxi(1,int(view.get("max_stack",{}).get(id,1)))
		slots += ceili(float(left)/stack)
	return slots <= int(view.get("free_slots",0))
