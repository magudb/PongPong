class_name LanternGem
extends RefCounted
static func equipped() -> StringName:
	var eco := Svc.node("EconomyManager")
	return eco.equipped_item(&"accessory") if eco != null else &""
static func can_equip(id: Variant) -> bool:
	return not definition(id).is_empty()
static func definition(id: Variant) -> Dictionary:
	var item := ItemKinds.def(id)
	if str(item.get("category","")) != "gem": return {}
	return LuaData.dict(item.get("lantern",Svc.lua_config("dungeon_loot.lantern_gem.existing."+str(id),{})))
static func effects(id: Variant) -> Dictionary:
	var out := {"tint":"ffe9a8","oil_mult":1.0,"radius_mult":1.0,"light_cd_minus_s":0.0,"chest_sense_cells":0,"ambush_mult":1.0,"pickup_mult":1.0}
	var gem := definition(id)
	if gem.is_empty(): return out
	out.tint = str(gem.get("tint","ffe9a8"))
	var rarity := str(ItemKinds.rarity_of(id))
	var steps := LuaData.dict(Svc.lua_config("dungeon_loot.lantern_gem.steps",{"normal":0,"uncommon":1,"rare":2,"unique":3,"legendary":4}))
	var units := LuaData.dict(Svc.lua_config("dungeon_loot.lantern_gem.unit",{"oil":.04,"radius":.04,"light_cd":.5,"chest_sense":3,"ambush":.2,"pickup":.2}))
	var step := float(steps.get(rarity,0))
	for theme in LuaData.strings(gem.get("themes",[])):
		var value := step*float(units.get(theme,0))
		match theme:
			"oil": out.oil_mult = maxf(.1,1-value)
			"radius": out.radius_mult = 1+value
			"light_cd": out.light_cd_minus_s = value
			"chest_sense": out.chest_sense_cells = mini(int(value),int(Svc.lua_config("dungeon_loot.limits.chest_sense_max_cells",12)))
			"ambush": out.ambush_mult = 1+value
			"pickup": out.pickup_mult = 1+value
	return out
