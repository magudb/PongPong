class_name SpeciesPerks
extends RefCounted
## The SPECIES layer of the perks: THE ONLY PLACE where lua/config/species_perks.lua is resolved (package V1-cast-data).
## Callers: Player2D (P06: dig_speed, tool_cost_mult, harvest_bonus_chance), ClimbLane (V3: climb_speed_mult), CrownCache (V6: crown_caches),
## the chest handler of the dungeon (F4: chest_sense_px). Nobody reads `species_perks` through LuaRuntime directly.
##
## The ladder (first hit wins), for a SKIN id:
##   1. species_perks.<skin>.<key>          the species layer (Kiki the monkey overrides dig_speed, tool_cost_mult, harvest_bonus_chance
##                                          and adds climb_speed_mult, chest_sense_px, crown_caches)
##   2. race_perks.<race of the skin>.<key> the race layer (Rasmus the fox lists nothing: he IS the race baseline, dig 1.3, cost 0.75,
##                                          harvest +20 %; the ghost's whole perk layer is race_perks.ghost, reached through this step)
##   3. the `default` the caller passes     a key nobody lists (climb_speed_mult 1.0 for everybody but Kiki) and every skin the data does
##                                          not know (an NPC id, an empty id)
## Values keep the type the Lua reader gave them (700 is an int, 2.2 a float, true a bool); a caller that needs a float uses float().
##
## Everything is static and reaches LuaRuntime / GameManager late-bound through Svc, so the class compiles in `-s` drivers and answers the
## caller's default while the autoloads do not exist.

## `key` of one skin (see the ladder above). `skin_id` may be a String or a StringName.
static func value(skin_id: Variant, key: String, default_value: Variant = null) -> Variant:
	var skin := str(skin_id)
	if skin == "":
		return default_value
	var own: Dictionary = LuaData.dict(Svc.lua_config("species_perks.%s" % skin, {}))
	if own.has(key):
		return own[key]
	var race := race_of(skin)
	if race != "":
		var race_row: Dictionary = LuaData.dict(Svc.lua_config("race_perks.%s" % race, {}))
		if race_row.has(key):
			return race_row[key]
	return default_value


## `key` for the skin the player plays right now (GameManager.character_skin). A skin the data does not know (an old save, no game started
## yet) answers for the DEFAULT skin of the current race (GameManager.character_type), never for a different hero.
static func current(key: String, default_value: Variant = null) -> Variant:
	var gm: Node = Svc.node("GameManager")
	if gm == null:
		return default_value
	var skin := str(gm.get("character_skin"))
	if race_of(skin) == "":
		skin = _default_skin_of_type(gm.get("character_type"))
	return value(skin, key, default_value)


## The race id (animal fairy hobbit ghost) of a skin id of lua/config/characters.lua; "" for an unknown skin.
static func race_of(skin_id: Variant) -> String:
	var skin := str(skin_id)
	if skin == "":
		return ""
	return str(LuaData.dict(Svc.lua_config("characters.skins.%s" % skin, {})).get("race", ""))


## default_skin of the race that GameManager.CharacterType `type_index` names ("" when the data has no such race).
static func _default_skin_of_type(type_index: Variant) -> String:
	var race: String = Perks.RACE_KEYS[clampi(LuaData.int_of(type_index), 0, Perks.RACE_KEYS.size() - 1)]
	return str(Svc.lua_config("characters.races.%s.default_skin" % race, ""))
