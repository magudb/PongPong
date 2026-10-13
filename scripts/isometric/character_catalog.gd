class_name CharacterCatalog
extends RefCounted
## Read access to lua/config/characters.lua plus the ONE rule that turns it into a sprite folder:
## follow the fallback chain until an id has art (res://assets/isometric_characters/<id>/animations.json).
##
## Who looks like what is DATA (lua/config/characters.lua, package P05): skins -> visual id with fallbacks,
## species chips, races, farm animals, enemy visuals. Nothing in code names a stand-in character, so when the new art
## lands (P21 hobbits, squirrel, NPCs, animals; A2 wardrobe bases) no code changes: the first id of the chain
## that has a folder simply starts to win.
##
## Everything is static and reaches the Lua data through the LuaRuntime autoload by name, so this script compiles in -s
## drivers where autoloads do not exist yet (it then reads an empty configuration, never errors).

const CHARACTERS_DIR := "res://assets/isometric_characters/"
## Longest chain that is followed (a cycle in the data stops at the first repeated id anyway).
const MAX_CHAIN := 8

# Test hooks: an injected configuration and an injected "has art" predicate (see tests/sections/characters.gd).
static var _data_override: Dictionary = {}
static var _use_data_override: bool = false
static var _exists_override: Callable = Callable()


# ---------------------------------------------------------------- data access

## The whole `characters` table of lua/config/characters.lua ({} while the runtime is not up).
static func data() -> Dictionary:
	if _use_data_override:
		return _data_override
	var lua := _lua()
	if lua == null or not lua.has_method("get_config"):
		return {}
	return _dict(lua.call("get_config", "characters", {}))


static func _lua() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("LuaRuntime")
	return null


## Lua hands over empty tables as Arrays and never-set tables as null: normalise.
static func _dict(v: Variant) -> Dictionary:
	return v as Dictionary if v is Dictionary else {}


static func _arr(v: Variant) -> Array:
	return v as Array if v is Array else []


static func _section(name: String) -> Dictionary:
	return _dict(data().get(name, {}))


# ---------------------------------------------------------------- test hooks

## Replaces lua/config/characters.lua's `characters` table (tests only). `clear_overrides()` restores the real data.
static func set_data_override(d: Dictionary) -> void:
	_data_override = d
	_use_data_override = true


## Replaces the "does this id have art" test: Callable(id: String) -> bool (tests only).
static func set_exists_override(c: Callable) -> void:
	_exists_override = c


static func clear_overrides() -> void:
	_data_override = {}
	_use_data_override = false
	_exists_override = Callable()


# ---------------------------------------------------------------- art folders and fallback chains

## True when the id has a character folder (animations.json is what defines a character; ids are open, not an enum).
static func exists(id: String) -> bool:
	if not is_safe_id(id):
		return false
	if _exists_override.is_valid():
		return bool(_exists_override.call(id))
	return FileAccess.file_exists(CHARACTERS_DIR + id + "/animations.json")


## Ids become folder names: LOWERCASE letters, digits and underscores only (no path tricks). Every roster id is lowercase;
## an uppercase id would open the folder on a case-insensitive file system (macOS, Windows: engine "Case mismatch" warning,
## character_id "FOX") and fall back to the unknown-id warning on a Linux export, so it is refused everywhere alike.
static func is_safe_id(id: String) -> bool:
	return id != "" and id == id.to_lower() and id.is_valid_identifier()


## The id a missing id falls back to ("" = none). Data: characters.lua `fallbacks = { hobbit_pip = "raccoon", ... }`.
static func fallback_of(id: String) -> String:
	return str(_section("fallbacks").get(id, ""))


## [id, its fallback, the fallback's fallback, ...] (cycle-safe, at most MAX_CHAIN long).
static func fallback_chain(id: String) -> Array[String]:
	var chain: Array[String] = []
	var cur := id
	while cur != "" and not chain.has(cur) and chain.size() < MAX_CHAIN:
		chain.append(cur)
		cur = fallback_of(cur)
	return chain


## The first id of the chain that has art; "" when nothing in the chain does.
static func resolve(id: String) -> String:
	for candidate in fallback_chain(id):
		if exists(candidate):
			return candidate
	return ""


# ---------------------------------------------------------------- races and skins

## Race table row (name_key, perk_key, default_skin) of "animal" | "fairy" | "hobbit".
static func race(race_key: String) -> Dictionary:
	return _dict(_section("races").get(race_key, {}))


static func default_skin(race_key: String) -> String:
	return str(race(race_key).get("default_skin", ""))


## Skin row (race, name_key, visual, fallback, wardrobe_body).
static func skin(skin_id: Variant) -> Dictionary:
	return _dict(_section("skins").get(str(skin_id), {}))


static func skin_ids() -> Array[String]:
	var out: Array[String] = []
	for k in _section("skins").keys():
		out.append(str(k))
	return out


## The id the player body asks for first (the wardrobe-ready base, e.g. "fox_base"); the chain behind it is `skin_chain`.
## An unknown skin falls back to the default skin of `race_key`, then to nothing ("").
static func visual_for_skin(skin_id: Variant, race_key: String = "animal") -> String:
	var row := skin(skin_id)
	if row.is_empty():
		row = skin(default_skin(race_key))
	return str(row.get("visual", ""))


## visual -> fallbacks, e.g. animal_squirrel: [squirrel_base, squirrel, monkey].
static func skin_chain(skin_id: Variant, race_key: String = "animal") -> Array[String]:
	return fallback_chain(visual_for_skin(skin_id, race_key))


## The sprite folder that really draws this skin right now ("" only when not even the pack stand-in exists).
static func resolved_visual_for_skin(skin_id: Variant, race_key: String = "animal") -> String:
	return resolve(visual_for_skin(skin_id, race_key))


## The stock sprite of a skin (the chain WITHOUT its wardrobe base): what screens show where no WardrobeLayers dresses the
## body, e.g. the character-select card. The wardrobe bases are undressed bodies, so a select screen that asked for
## `visual_for_skin` would show a body without its starter outfit as soon as the base art lands.
static func stock_visual_for_skin(skin_id: Variant, race_key: String = "animal") -> String:
	var head := visual_for_skin(skin_id, race_key)
	var next := fallback_of(head)
	return resolve(next if next != "" else head)


## bodies.json hero id of the wardrobe (fox, rabbit, hedgehog, squirrel, hobbit_pip|moss|bramble, fairy, fairy_stardust, fairy_dusk).
static func wardrobe_body(skin_id: Variant, race_key: String = "animal") -> String:
	var row := skin(skin_id)
	if row.is_empty():
		row = skin(default_skin(race_key))
	return str(row.get("wardrobe_body", ""))


## The four species chips of the animal card: [{id, name_key, skin}].
static func species() -> Array:
	return _arr(data().get("species", []))


# ---------------------------------------------------------------- farm animals and enemies

## Farm animal row (baby, adult, baby_scale, adult_scale) of a species id (chicken rabbit duck cat dog sheep cow deer fox owl).
static func animal(species_id: String) -> Dictionary:
	return _dict(_section("animals").get(species_id, {}))


## Visual id and scale of one stage: stage "baby" | "adult". {visual, scale}; {} for an unknown species.
static func animal_look(species_id: String, stage: String = "adult") -> Dictionary:
	var row := animal(species_id)
	if row.is_empty():
		return {}
	var vis := str(row.get(stage, row.get("adult", "")))
	var sc := float(row.get(stage + "_scale", 1.0))
	return {"visual": vis, "scale": sc}


## Enemy row (visual) of an enemy kind (bat, ugleoje, tornebusk, lysesvamp, snurresvamp).
static func enemy(kind: String) -> Dictionary:
	return _dict(_section("enemies").get(kind, {}))


static func enemy_visual(kind: String) -> String:
	return str(enemy(kind).get("visual", ""))


# ---------------------------------------------------------------- audit helper

## Every character id the data mentions (visuals, bases, fallback keys and targets, animals, enemies): the set that must
## resolve (tests/sections/characters.gd).
static func all_ids() -> Array[String]:
	var seen := {}
	for row in _section("skins").values():
		seen[str(_dict(row).get("visual", ""))] = true
		seen[str(_dict(row).get("fallback", ""))] = true
	for k in _section("fallbacks").keys():
		seen[str(k)] = true
		seen[str(_section("fallbacks")[k])] = true
	for row in _section("animals").values():
		seen[str(_dict(row).get("baby", ""))] = true
		seen[str(_dict(row).get("adult", ""))] = true
	for row in _section("enemies").values():
		seen[str(_dict(row).get("visual", ""))] = true
	seen.erase("")
	var out: Array[String] = []
	for k in seen.keys():
		out.append(str(k))
	out.sort()
	return out
