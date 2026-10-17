class_name DungeonCombatRules
extends RefCounted
static func expected_weapon(floor_number: int) -> int:
	var curve := LuaData.arr(DungeonRulesData.cfg("expected_weapon",[5,6,8,10,12,13,15,16,18,20,22,24]))
	if curve.is_empty(): return 5
	var number := maxi(floor_number,1)
	if number > curve.size(): return int(curve.back())+int(DungeonRulesData.cfg("deep_step",2))*(number-curve.size())
	return int(curve[number-1])
static func weapon_family(id: String) -> Dictionary:
	return LuaData.dict(DungeonRulesData.cfg("weapon_families."+id,{})).duplicate(true)
static func weapon_rating(item: Variant) -> float:
	var rating: Variant = Svc.static_call("res://scripts/combat/weapon_info.gd",&"sword_equivalent",[item],null)
	if rating != null: return maxf(float(rating),0)
	var def := ItemKinds.def(item)
	var family := weapon_family(str(def.get("weapon_family","sword")))
	var period := float(family.get("time",0.28))+float(family.get("cooldown",0.12))
	return float(def.get("damage",0))*0.4/maxf(period,0.01)
static func weapon_ratio(item: Variant, floor_number: int) -> float:
	return weapon_rating(item)/float(maxi(expected_weapon(floor_number),1))
static func weapon_range(item: Variant) -> Vector2i:
	var last := 1
	for number in range(1,13):
		if expected_weapon(number) <= weapon_rating(item)/0.9: last = number
	return Vector2i(1,last)
static func enemy_class(kind: String) -> String:
	var row := LuaData.dict(DungeonRulesData.value("enemies."+kind,{}))
	return str(row.get("class",{"bat":"light","tornebusk":"heavy","sporesvamp":"heavy","lysesvamp":"critter"}.get(kind,"standard")))
static func enemy_hp(kind: String, floor_number: int) -> int:
	var row := LuaData.dict(DungeonRulesData.value("enemies."+kind,{}))
	var hits := int(row.get("hits_x10",LuaData.dict(DungeonRulesData.cfg("class_hits_x10",{})).get(enemy_class(kind),16)))
	return maxi(1,roundi(float(hits)*expected_weapon(floor_number)/10.0))
static func enemy_damage(kind: String, tier: int, assist_level := 0) -> int:
	var ladder := LuaData.arr(DungeonRulesData.cfg("damage."+enemy_class(kind),[1,2,2,2]))
	var damage := int(ladder[clampi(tier-1,0,ladder.size()-1)]) if not ladder.is_empty() else 1
	return 1 if assist_level >= 2 else maxi(1,damage-maxi(assist_level,0))
static func boss_hp(kind: String) -> int:
	return int(LuaData.dict(DungeonRulesData.value("bosses."+kind,{})).get("hp",{"snurresvamp":80,"snurresvamp_gloed":176,"snurresvamp_konge":288}.get(kind,80)))
