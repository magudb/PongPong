class_name CraftingSystem
extends RefCounted
## The Vaerksted: crafting recipes as DATA (lua/recipes/*.lua, kind = "recipes"; read through LuaRuntime.get_recipes). Static API,
## no autoload names (autoloads are reached through Svc, so the class compiles in tool drivers too).
##
## RECIPE: name_key (RECIPE_<ID>), category craft | bake | forge, ingredients { item = amount }, output { item, amount } and the
## optional gates of the home recipes: station (snedkerbord | vaev | smedje), min_home_tier, unlock_flag (a blueprint flag such as
## bp_kongelig). get_recipes(category?, station?) lists them in declaration order, each with its id.
##
## can_craft(id) -> {ok, missing: [{item, have, need}], locked: {} | {reason: "tier" | "flag", need}, unknown}
##   missing  every ingredient the player has too few of (have counts every copy owned, wherever it is stored)
##   locked   the home is below the recipe's tier (need = the tier) or the blueprint flag is not set (need = the flag name)
##            - tier before flag; a recipe with a station and no min_home_tier needs the tier that unlocks the station
##   ok       nothing missing, nothing locked, recipe known
## craft(id) -> bool consumes the ingredients and gives the output through EconomyManager (so furniture lands in the furniture
## store), emits EventBus.recipe_crafted(id, produced) once, and is all or nothing: when the output does not fit, the
## ingredients come back. Category bake: the hobbit's bake_bonus (lua/config/race_perks.lua, 0.25) is the chance of ONE more
## output; the draw uses CraftingSystem.rng (seed_rng() makes it repeatable) and is only made when a chance exists.

## station -> the unlock id of lua/data/home_tiers.lua (perks.unlocks) and the tier used when the config is missing
const STATION_UNLOCKS := {"snedkerbord": "workbench", "vaev": "loom", "smedje": "forge_bench"}
const STATION_DEFAULT_TIER := {"snedkerbord": 1, "vaev": 3, "smedje": 5}

static var rng := RandomNumberGenerator.new()


static func seed_rng(seed_value: int) -> void:
	rng.seed = seed_value


## Every recipe (declaration order), optionally of one category and / or one station. Shallow copies, each with its `id`.
static func get_recipes(category: String = "", station: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lr := Svc.node("LuaRuntime")
	if lr == null:
		return out
	var all: Dictionary = lr.get_recipes(category)
	for id in all:
		var r: Dictionary = all[id]
		if station != "" and str(r.get("station", "")) != station:
			continue
		var copy := r.duplicate()
		copy["id"] = str(id)
		out.append(copy)
	return out


static func get_recipe(recipe_id: Variant) -> Dictionary:
	var lr := Svc.node("LuaRuntime")
	if lr == null:
		return {}
	var r: Dictionary = lr.get_recipe(str(recipe_id))
	if r.is_empty():
		return {}
	var copy := r.duplicate()
	copy["id"] = str(recipe_id)
	return copy


## The home tier (world flag home_tier, 1 until the home is upgraded).
static func home_tier() -> int:
	var gm := Svc.node("GameManager")
	return int(gm.call("flag_int", &"home_tier", 1)) if gm != null and gm.has_method("flag_int") else 1


## The tier that unlocks a station: the first tier of config home.tiers whose perks.unlocks lists it, else the default.
static func station_tier(station: String) -> int:
	var unlock := str(STATION_UNLOCKS.get(station, ""))
	var tiers := LuaData.arr(Svc.lua_config("home.tiers", []))
	for i in tiers.size():
		var t := LuaData.dict(tiers[i])
		if unlock in LuaData.strings(LuaData.dict(t.get("perks", {})).get("unlocks", [])):
			return LuaData.int_of(t.get("tier", i + 1), i + 1)
	return int(STATION_DEFAULT_TIER.get(station, 1))


## The home tier a recipe needs: its min_home_tier, else the tier of its station, else 1.
static func required_tier(recipe: Dictionary) -> int:
	if recipe.has("min_home_tier"):
		return maxi(LuaData.int_of(recipe["min_home_tier"], 1), 1)
	var station := str(recipe.get("station", ""))
	return station_tier(station) if station != "" else 1


static func can_craft(recipe_id: Variant) -> Dictionary:
	var r := get_recipe(recipe_id)
	if r.is_empty():
		return {"ok": false, "missing": [], "locked": {}, "unknown": true}
	var eco := Svc.node("EconomyManager")
	var missing: Array = []
	var ingredients := LuaData.int_map(r.get("ingredients", {}))
	for item_id in ingredients:
		var need: int = ingredients[item_id]
		var have := int(eco.call("count_item", StringName(item_id))) if eco != null else 0
		if have < need:
			missing.append({"item": item_id, "have": have, "need": need})
	var locked := {}
	var tier := required_tier(r)
	if home_tier() < tier:
		locked = {"reason": "tier", "need": tier}
	else:
		var flag := str(r.get("unlock_flag", ""))
		if flag != "":
			var gm := Svc.node("GameManager")
			var is_set := gm != null and bool(gm.call("get_flag", StringName(flag), false))
			if not is_set:
				locked = {"reason": "flag", "need": flag}
	return {"ok": missing.is_empty() and locked.is_empty(), "missing": missing, "locked": locked, "unknown": false}


## The chance of one more output when baking: race_perks.<race>.bake_bonus of the current character (hobbit 0.25, others 0).
static func bake_bonus_chance() -> float:
	var gm := Svc.node("GameManager")
	if gm == null:
		return 0.0
	var race := clampi(LuaData.int_of(gm.get("character_type")), 0, Perks.RACE_KEYS.size() - 1)
	return clampf(LuaData.num(Svc.lua_config("race_perks.%s.bake_bonus" % Perks.RACE_KEYS[race], 0.0)), 0.0, 1.0)


## Crafts a recipe once. False (nothing changed) when it is unknown, missing something, locked, or the output does not fit.
static func craft(recipe_id: Variant) -> bool:
	var r := get_recipe(recipe_id)
	var eco := Svc.node("EconomyManager")
	if r.is_empty() or eco == null or not bool(can_craft(recipe_id)["ok"]):
		return false
	var ingredients := LuaData.int_map(r.get("ingredients", {}))
	var output := LuaData.dict(r.get("output", {}))
	var out_id := str(output.get("item", ""))
	var out_amount := LuaData.int_of(output.get("amount", 1), 1)
	if out_id == "" or out_amount <= 0:
		return false
	var produced := out_amount
	if str(r.get("category", "")) == "bake":
		var chance := bake_bonus_chance()
		if chance > 0.0 and rng.randf() < chance:
			produced += 1
	if not bool(eco.call("remove_items", ingredients)):
		return false
	if not bool(eco.call("add_item", StringName(out_id), produced)):
		for item_id in ingredients:                      # the output did not fit: everything comes back
			eco.call("add_item", StringName(item_id), int(ingredients[item_id]), true)
		return false
	var bus := Svc.node("EventBus")
	if bus != null:
		bus.emit_signal("recipe_crafted", StringName(str(recipe_id)), produced)
	return true
