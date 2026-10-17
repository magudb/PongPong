class_name DungeonOilRules
extends RefCounted
static func step(oil: float, dt: float, context: Dictionary) -> float:
	if bool(context.get("paused",false)) or not bool(context.get("on_floor",false)): return maxf(oil,0)
	var assist_level := clampi(int(context.get("assist_oil",0)),0,2)
	var assist_mult: float = [1.0,0.5,0.0][assist_level]
	var multiplier := maxf(float(context.get("race_mult",1)),0)*maxf(float(context.get("gem_mult",1)),0)*float(assist_mult)
	return maxf(0,oil-maxf(dt,0)*multiplier)
static func light_ratio(oil: float) -> float:
	var maximum := maxf(float(DungeonRulesData.value("combat.oil_seconds",150)),1)
	return clampf(maxf(oil/maximum,float(DungeonRulesData.cfg("oil.min_light_x100",35))/100.0),0,1)
static func bite_due(oil: float, hearts_half: int, elapsed: float) -> bool:
	var interval := float(DungeonRulesData.value("adventure.oil_empty_hurt_interval",12))
	return oil <= 0 and hearts_half > int(DungeonRulesData.cfg("oil.hurt_floor_half_hearts",2)) and interval > 0 and elapsed >= interval
static func auto_refuel_item(oil: float, owned: Dictionary) -> StringName:
	if not bool(DungeonAssist.get_value("assist_auto_refuel")) or oil > float(DungeonRulesData.cfg("oil.auto_refuel_at",15)): return &""
	for id in [str(DungeonRulesData.cfg("oil.lantern_oil_item","lantern_oil")),str(DungeonRulesData.cfg("oil.elixir_item","lysdraabe"))]:
		if int(owned.get(id,0)) > 0: return StringName(id)
	return &""
