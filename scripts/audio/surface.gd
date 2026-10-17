class_name Surface
extends RefCounted
static func at(area: IsoArea,position: Vector2) -> String:
	if area==null or area.map==null:return "grass"
	var resolver: Variant = area.get_meta("surface_fn") if area.has_meta("surface_fn") else null
	if resolver is Callable and resolver.is_valid():
		var surface := str(resolver.call(position))
		if surface in ["grass","dirt","wood","stone","rope"]:return surface
	var defaults := "interior" if str(area.map.id).begins_with("int_") else "moerkeskoven" if str(area.map.id).begins_with("moerkeskoven_f") else str(area.map.id)
	var fallback := str(Svc.lua_config("audio_map.areas."+defaults+".surface_default","grass"))
	var ground := area.map.ground_at(area.global_to_cell(position))
	return str(LuaData.dict(Svc.lua_config("audio_map.surfaces",{})).get(ground,fallback))
