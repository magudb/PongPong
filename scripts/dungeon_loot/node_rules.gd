class_name DungeonNodeRules
extends RefCounted
const P := preload("res://scripts/dungeon_loot/loot_plan.gd")
static func _amount(rng: Object, raw: Variant) -> int:
	var bounds := LuaData.arr(raw)
	return P.range_i(rng,int(bounds[0]),int(bounds[1])) if bounds.size() >= 2 else 1
static func roll_node(state: Dictionary, req: Dictionary) -> Dictionary:
	var yields := LuaData.dict(P.rules(req).get("node_yields",{}))
	var kind := str(req.get("node_kind",""))
	var spec := LuaData.dict(yields.get(kind,{}))
	if spec.has("alias"): spec = LuaData.dict(yields.get(str(spec.alias),{}))
	if spec.is_empty(): return P.failure("unknown_node")
	var band := str(req.get("band","skovkant"))
	var rows := []
	if P.chance(req.rng,int(spec.get("chance_bp",10000))):
		var id := str(P.rules(req).get("bands",{}).get(band,{}).get("rough","rough_"+band)) if spec.get("rough",false) else str(spec.get("item",""))
		var row := P.row(req,id,_amount(req.rng,spec.get("amount",[])))
		if not row.is_empty(): rows.append(row)
	else:
		var fallback := LuaData.dict(spec.get("fallback",{}))
		if not fallback.is_empty(): rows.append(P.row(req,str(fallback.item),_amount(req.rng,fallback.get("amount",[]))))
	for extra in LuaData.arr(spec.get("extra",[])):
		var bands := LuaData.strings(extra.get("bands",[]))
		if (bands.is_empty() or band in bands) and P.chance(req.rng,int(extra.get("bp",0))): rows.append(P.row(req,str(extra.item),_amount(req.rng,extra.get("amount",[]))))
	return P.success(state,req,rows,{},false)
static func roll_drop(state: Dictionary, req: Dictionary) -> Dictionary:
	var kind := str(req.get("creature",""))
	var rows := []
	var spec := LuaData.dict(req.cfg.get("creatures",{}).get(kind,{}))
	if not spec.is_empty():
		var row := DungeonContainerRules.ordinary(state,req,spec)
		if not row.is_empty(): rows.append(row)
	for drop in LuaData.arr(P.rules(req).get("drops",{}).get(kind,[])):
		if P.chance(req.rng,int(drop.get("bp",0))): rows.append(P.row(req,str(drop.item),_amount(req.rng,drop.get("amount",[]))))
	return P.success(state,req,rows,{},false)
