class_name CheatActions
extends RefCounted
## Test conveniences call the same owners as gameplay. No alternate inventory/save schema.
static func world() -> WorldRoot2D:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("world_2d") as WorldRoot2D if tree != null else null

static func available() -> bool:
	var w := world()
	return w != null and w.ready_for_play and w.player != null and w.area != null and not w.traveling and not w.sleeping and int(w.player.get("state")) == 0

static func recover() -> bool:
	if not available(): return false
	world().player.call("restore_after_sleep")
	return true

static func grant(id: String, count: int) -> bool:
	if not available() or count < 1 or count > 999 or GameData.eco().call("item_def", id).is_empty(): return false
	return bool(GameData.eco().call("add_item", StringName(id), count))

static func gold() -> bool:
	if not available(): return false
	GameData.eco().call("add_gold", 10000)
	return true

static func wardrobe() -> bool:
	if not available(): return false
	var lua := GameData.lua()
	var eco := GameData.eco()
	for id in lua.call("get_all_item_ids"):
		var def: Dictionary = eco.call("item_def", id)
		if str(def.get("category", "")) == "clothing" and int(eco.call("count_item", StringName(id))) == 0:
			eco.call("add_item", StringName(id), 1, true)
	return true

static func advance(minutes: int) -> bool:
	if not available() or minutes < 1 or minutes > 1440: return false
	GameData.gm().call("advance_time", minutes)
	return true

static func next_day() -> bool:
	if not available(): return false
	GameData.gm().call("end_day")
	return recover()

static func travel(area_id: StringName, spawn: StringName = &"default") -> bool:
	if not available() or not WorldRoot2D.has_area(area_id): return false
	world().travel(area_id, spawn)
	return true
