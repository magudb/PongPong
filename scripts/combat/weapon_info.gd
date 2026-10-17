class_name WeaponInfo
extends RefCounted
static var _config: Dictionary = {}
static func set_config_for_tests(config: Dictionary = {}) -> void:
	_config = config.duplicate(true)
static func of(id: Variant) -> Dictionary:
	var item := ItemKinds.def(id)
	if str(item.get("category","")) != "weapon": return {}
	var family := str(item.get("weapon_family","sword"))
	var families := _config if not _config.is_empty() else LuaData.dict(Svc.lua_config("dungeon_run.weapon_families",{}))
	var swing := LuaData.dict(families.get(family,{})).duplicate(true)
	if swing.is_empty(): swing = {"time":.28,"cooldown":.12,"radius":197,"half_angle":62,"knockback":433}
	swing.merge(LuaData.dict(item.get("swing",{})),true)
	var cycle := maxf(.01,float(swing.get("time",.28))+float(swing.get("cooldown",.12)))
	var damage := int(item.get("damage",0))
	return {"id":str(id),"family":family,"damage":damage,"cycle":cycle,"rating":damage/cycle,"sword_equiv":damage*.4/cycle,"swing":swing,"effect":LuaData.dict(item.get("effect",{})).duplicate(true)}
static func rating(id: Variant) -> float:
	return float(of(id).get("rating",0))
static func sword_equivalent(id: Variant) -> float:
	return float(of(id).get("sword_equiv",0))
