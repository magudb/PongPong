class_name GameData
extends RefCounted
## Thin typed accessors over the Lua-driven data (LuaRuntime config + item defs) and the autoloads, for scripts that must
## also compile in `-s` drivers (autoloads are reached through the scene tree root, never by their global name).
## Nothing here is hard-coded game balance: defaults only apply when the Lua file lacks the key.
##
## Config goes through GameManager.config_value() when GameManager exists, so tests can inject values with
## GameManager.set_config_override(path, value) (the same seam the clock uses).

## Fallback only: the race keys really come from lua/config/characters.lua `races` (CharacterCatalog.race()).
const RACE_KEYS := {0: "animal", 1: "fairy", 2: "hobbit", 3: "ghost"}


static func _root() -> Window:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root if loop is SceneTree else null


static func autoload(autoload_name: String) -> Node:
	var r: Window = _root()
	return r.get_node_or_null(NodePath(autoload_name)) if r != null else null


static func lua() -> Node:
	return autoload("LuaRuntime")


static func eco() -> Node:
	return autoload("EconomyManager")


static func tm() -> Node:
	return autoload("TimeManager")


static func gm() -> Node:
	return autoload("GameManager")


## A value of the merged lua/config tables by dotted path ("player.walk_speed", "ambient.presets.farm").
static func cfg(path: String, default_value: Variant = null) -> Variant:
	var g: Node = gm()
	if g != null and g.has_method("config_value"):
		return g.call("config_value", path, default_value)
	var l: Node = lua()
	if l != null and l.has_method("get_config"):
		return l.call("get_config", path, default_value)
	return default_value


## Lua hands over empty tables as Arrays and never-set tables as null: always a Dictionary.
static func dict_of(v: Variant) -> Dictionary:
	return v as Dictionary if v is Dictionary else {}


static func array_of(v: Variant) -> Array:
	return v as Array if v is Array else []


# ----------------------------------------------------------------------------- race, perks, combat, player

## "animal" | "fairy" | "hobbit" | "ghost": the enum name of GameManager.character_type, checked against lua/config/characters.lua `races`.
static func race_key() -> String:
	var g: Node = gm()
	if g == null:
		return "animal"
	var idx: int = int(g.get("character_type"))
	var named: String = ""
	var script: Script = g.get_script()
	if script != null:
		var enum_dict: Variant = script.get_script_constant_map().get("CharacterType", null)
		if enum_dict is Dictionary:
			for k in (enum_dict as Dictionary):
				if int((enum_dict as Dictionary)[k]) == idx:
					named = str(k).to_lower()
					break
	if named != "" and not CharacterCatalog.race(named).is_empty():
		return named
	return str(RACE_KEYS.get(idx, "animal"))


static func perk(key: String, default_value: Variant = null) -> Variant:
	return cfg("race_perks.%s.%s" % [race_key(), key], default_value)


static func combat(key: String, default_value: Variant = null) -> Variant:
	return cfg("combat.%s" % key, default_value)


static func player_cfg(key: String, default_value: Variant = null) -> Variant:
	return cfg("player.%s" % key, default_value)


static func item_def(item_id: StringName) -> Dictionary:
	var l: Node = lua()
	return l.call("get_item_def", String(item_id)) if l != null and l.has_method("get_item_def") else {}


# ----------------------------------------------------------------------------- characters (through CharacterCatalog, P05)

## Pack stand-ins the hero falls back to when characters.lua knows neither the skin nor its race (ids of the 12 pack characters;
## the real chains live in lua/config/characters.lua and CharacterCatalog follows them, this is only the last resort).
const FALLBACK_VISUALS := {"animal": "fox", "fairy": "fairy", "hobbit": "raccoon", "ghost": "rabbit"}


## The id the player body asks for first (head of the skin's chain, e.g. "fox_base"): IsoChibiSprite2D.create(...) of it
## walks the fallback chain of lua/config/characters.lua until an art folder exists.
static func visual_for_skin(skin: StringName) -> String:
	var race: String = race_key()
	var v: String = CharacterCatalog.visual_for_skin(skin, race)
	return v if v != "" else str(FALLBACK_VISUALS.get(race, "fox"))


## The art folder that really draws the skin right now (the first id of the chain that has an animations.json).
static func resolved_visual_for_skin(skin: StringName) -> String:
	var v: String = CharacterCatalog.resolved_visual_for_skin(skin, race_key())
	return v if v != "" else str(FALLBACK_VISUALS.get(race_key(), "fox"))


## The stock sprite of a skin without its wardrobe base (what select screens show).
static func stock_visual_for_skin(skin: StringName) -> String:
	return CharacterCatalog.stock_visual_for_skin(skin, race_key())


# ----------------------------------------------------------------------------- props and markers (lua/config)

## Gameplay definition of a prop id: lua/config/props.lua, then props_extra.lua (P22), then props_features.lua (A1) merged
## over each other key by key (later wins). {} when no file knows the id. Keys: art (art id, default = the id itself),
## footprint {x, z}, solid {shape circle|footprint|none, radius, pad}, strips (y-sort slices, 0 = one key), group, glow, light.
static func prop_def(prop_id: String) -> Dictionary:
	var out: Dictionary = {}
	for table in ["props", "props_extra", "props_features"]:
		var all: Dictionary = dict_of(cfg(table, {}))
		var d: Variant = all.get(prop_id, null)
		if d is Dictionary:
			out.merge(d as Dictionary, true)
	return out


## Every prop id any of the three files defines.
static func prop_ids() -> Array[String]:
	var seen: Dictionary = {}
	for table in ["props", "props_extra", "props_features"]:
		for k in dict_of(cfg(table, {})).keys():
			seen[str(k)] = true
	var out: Array[String] = []
	for k in seen.keys():
		out.append(str(k))
	out.sort()
	return out


## Footprint {x, z} of a prop id in cells (the def, else 1 x 1).
static func footprint_of(prop_id: String) -> Vector2i:
	var fp: Array = array_of(prop_def(prop_id).get("footprint", []))
	if fp.size() >= 2:
		return Vector2i(maxi(int(fp[0]), 1), maxi(int(fp[1]), 1))
	return Vector2i(1, 1)


## lua/config/marker_handlers.lua (F4): marker type -> script path, merged OVER the built-in table by IsoArea.
static func marker_handlers() -> Dictionary:
	return dict_of(cfg("marker_handlers", {}))
