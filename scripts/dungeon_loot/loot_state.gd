class_name DungeonLootState
extends RefCounted
static func _number(value: Variant, fallback: int = 0) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return fallback
	return int(clampf(float(value),0,1000000000))
static func _map(raw: Variant) -> Dictionary:
	var out := {}
	for id in LuaData.dict(raw):
		if str(id).is_empty() or str(id).length() > 160: continue
		out[str(id)] = _number(raw[id])
	return out
static func from_dict(raw: Dictionary) -> Dictionary:
	if raw.is_empty(): return {}
	var out := {}
	for key in ["found","claimed","appraise"]:
		out[key] = _map(raw.get(key,{}))
	out.unique_day = _number(raw.get("unique_day",0))
	var day := LuaData.dict(raw.get("day",{}))
	out.day = {"day":_number(day.get("day",0)),"value":_number(day.get("value",0)),"capped":bool(day.get("capped",false)) if day.get("capped",false) is bool else false}
	out.wander = {}
	for key in LuaData.dict(raw.get("wander",{})):
		out.wander[str(key)] = {"misses":_number(LuaData.dict(raw.wander[key]).get("misses",0))}
	out.boss = {}
	for key in LuaData.dict(raw.get("boss",{})):
		var boss := LuaData.dict(raw.boss[key])
		var record := {}
		for field in ["kills","last_day","misses"]: record[field] = _number(boss.get(field,0))
		record["first_done"] = bool(boss.get("first_done",false)) if boss.get("first_done",false) is bool else false
		record["last_uid"] = str(boss.get("last_uid",""))
		record["pool_left"] = LuaData.strings(boss.get("pool_left",[]))
		out.boss[str(key)] = record
	return out
