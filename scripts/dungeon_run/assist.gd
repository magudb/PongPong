class_name DungeonAssist
extends RefCounted
static func defaults() -> Dictionary:
	return LuaData.dict(DungeonRulesData.cfg("assist.defaults",{}))
static func get_value(key: String) -> Variant:
	var fallback: Variant = defaults().get(key,0)
	return DungeonRulesData.flag(key,fallback)
static func set_value(key: String, value: Variant) -> bool:
	var baseline := defaults()
	var gm := Svc.node("GameManager")
	if gm == null or not baseline.has(key) or key == "assist_preset" or not (value is bool or value is int or value is float): return false
	if value is float and (not is_finite(value) or value != floorf(value)): return false
	var limit := 2 if key in ["assist_dmg","assist_telegraph","assist_hearts","assist_arc","assist_dodge","assist_oil"] else 1
	var n := clampi(int(value),0,limit)
	gm.set_flags({key:n,"assist_preset":"custom"})
	Svc.node("EventBus").game_event.emit(&"assist_changed",{"preset":"custom"})
	return true
static func apply_preset(id: String) -> bool:
	if id not in ["none","light","cozy"]: return false
	var gm := Svc.node("GameManager")
	if gm == null: return false
	var next := defaults().duplicate(true)
	if id != "none": next.merge(LuaData.dict(DungeonRulesData.cfg("assist."+id,{})),true)
	next["assist_preset"] = id
	gm.set_flags(next)
	Svc.node("EventBus").game_event.emit(&"assist_changed",{"preset":id})
	return true
static func _ladder(name: String, key: String, fallback: Array) -> float:
	var rows := LuaData.arr(DungeonRulesData.cfg("assist."+name,fallback))
	return float(rows[clampi(int(get_value(key)),0,rows.size()-1)]) if not rows.is_empty() else 0.0
static func windup_mult() -> float:
	return _ladder("windup_x100","assist_telegraph",[100,120,140])/100.0
static func hearts() -> int:
	return int(_ladder("hearts_half","assist_hearts",[0,2,4]))
static func arc_pct() -> int:
	return int(_ladder("arc_pct","assist_arc",[0,5,10]))
static func dodge_bonus() -> float:
	return _ladder("dodge_bonus_ms","assist_dodge",[0,50,100])/1000.0
