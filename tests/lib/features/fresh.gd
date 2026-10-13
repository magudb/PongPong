class_name Fresh
extends RefCounted
## A clean new game for every section from wave 3 on (plan 6.5): the harness's own new-game helper + the reset() of every feature manager that exists.
## Wave-1/2 sections use the harness helper (`t.new_game`) alone - this class exists from wave 3 (package F1).
##
##   Fresh.new_game(t)                          t.new_game("animal"|"fairy"|"hobbit" per --character) then reset() of HomeManager FurnitureManager WardrobeManager LootService CollectionLog
##   Fresh.new_game(t, "fairy", "Ida", "Gaard", "fairy_stardust")
##   Fresh.new_game(null)                       without a harness object: GameManager.start_new_game (+ new_game_started) directly
## Autoloads are reached through Svc (late bound), so this compiles in `-s` drivers and before the feature managers exist; a manager that does not exist yet is skipped.
## Seeding: LootService is seeded when it offers set_seed(int) or an `rng` (F4); TimeManager weather is set to klart when it offers set_weather.

const FEATURE_NODES := ["HomeManager", "FurnitureManager", "WardrobeManager", "LootService", "CollectionLog"]
const DEFAULT_SEED := 424242


static func new_game(t = null, character: String = "", p_name: String = "Tester", farm: String = "Testgaarden", skin: String = "", rng_seed: int = DEFAULT_SEED) -> void:
	if t != null:
		t.new_game(character, p_name, farm, skin)
	else:
		var gm := Svc.node("GameManager")
		if gm != null:
			gm.start_new_game(p_name, _character_type(character), farm, StringName(skin))
	reset_quests()
	reset_features()
	seed_features(rng_seed)


## reset() of every feature manager that exists (new_game_started already does it for managers that listen; this makes a test independent of that wiring)
static func reset_features() -> Array[String]:
	var done: Array[String] = []
	for n in FEATURE_NODES:
		var node := Svc.node(n)
		if node != null and node.has_method("reset"):
			node.call("reset")
			done.append(n)
	return done


## QuestManager runtime state back to nothing.  PLAN 3.6 gives QuestManager.reset() on new_game_started to P13 (wave 4); until it exists the quest lists of the legacy manager are cleared here
## (otherwise a quest accepted by one test stays active for the next: reproduced in the section content_features).  Definitions are never touched.
static func reset_quests() -> void:
	var qm := Svc.node("QuestManager")
	if qm == null:
		return
	if qm.has_method("reset"):
		qm.call("reset")
		return
	for prop in ["active_quests", "completed_quests", "failed_quests", "offered_quests"]:
		var v: Variant = qm.get(prop)
		if v is Dictionary or v is Array:
			v.clear()


static func seed_features(rng_seed: int = DEFAULT_SEED) -> void:
	var loot := Svc.node("LootService")
	if loot != null:
		if loot.has_method("set_seed"):
			loot.call("set_seed", rng_seed)
		elif typeof(loot.get("rng")) == TYPE_OBJECT:
			(loot.get("rng") as RandomNumberGenerator).seed = rng_seed
	var tm := Svc.node("TimeManager")
	if tm != null and tm.has_method("set_weather"):
		tm.call("set_weather", &"klart")


## Moves the calendar to a total game day (1-based; 28 days per season, 4 seasons) without running the days: for tests that need `min_day` gates open.
static func jump_to_total_day(total_day: int) -> void:
	var gm := Svc.node("GameManager")
	if gm == null:
		return
	var d := maxi(total_day, 1) - 1
	var seasons: Array = ["foraar", "sommer", "efteraar", "vinter"]
	gm.year = floori(d / 112.0) + 1
	gm.season = StringName(seasons[floori((d % 112) / 28.0)])
	gm.day = d % 28 + 1


static func give(item_id: String, amount: int = 1) -> bool:
	var eco := Svc.node("EconomyManager")
	return eco != null and bool(eco.add_item(StringName(item_id), amount, true))


static func gold(amount: int) -> void:
	var eco := Svc.node("EconomyManager")
	if eco != null:
		eco.gold = amount


static func _character_type(character: String) -> int:
	return {"animal": 0, "fairy": 1, "hobbit": 2}.get(character, 0)
