class_name DungeonRulesData
extends RefCounted
static func cfg(path: String, fallback: Variant = null) -> Variant:
	return value("dungeon_run" + ("."+path if path != "" else ""),fallback)
static func value(path: String, fallback: Variant = null) -> Variant:
	var gm := Svc.node("GameManager")
	return gm.config_value(path,fallback) if gm != null else Svc.lua_config(path,fallback)
static func flag(key: String, fallback: Variant = 0) -> Variant:
	var gm := Svc.node("GameManager")
	return gm.get_flag(StringName(key),fallback) if gm != null else fallback
static func player() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return PlayerRegistry.local_player(tree) if tree != null else null
