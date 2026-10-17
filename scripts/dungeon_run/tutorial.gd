class_name DungeonTutorial
extends RefCounted
static var _last_say_ms := -1000000
static func say(id: String) -> bool:
	var gm := Svc.node("GameManager")
	if gm == null or not bool(DungeonAssist.get_value("assist_hints")): return false
	if id not in LuaData.strings(DungeonRulesData.cfg("tutorial.ids",[])): return false
	var seen := str(gm.get_flag(&"dungeon_tut","")).split(",",false)
	if id in seen: return false
	if seen.is_empty(): _last_say_ms = -1000000
	if Time.get_ticks_msec()-_last_say_ms < int(float(DungeonRulesData.cfg("tutorial.spacing",20))*1000): return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		for boss in tree.get_nodes_in_group("boss"):
			if boss.get("awake") == true: return false
	seen.append(id)
	gm.set_flag(&"dungeon_tut",",".join(seen))
	_last_say_ms = Time.get_ticks_msec()
	Svc.node("EventBus").whisper_requested.emit("DTUT_"+id.to_upper())
	Svc.node("EventBus").game_event.emit(&"dungeon_hint",{"id":id})
	return true
