class_name HomeData
extends RefCounted
## Read-only data of the home: the ten tiers of lua/data/home_tiers.lua (config key `home`), the asset contract of the home art
## (assets/iso_props/home/home.json, assets/data/home/rooms/room_tNN.json, assets/iso_props/furniture/furniture.json) and the iso cell maths
## that every home scene shares (HomeManager here, FurnitureManager / HomeRoom / HomeExterior2D / the Husbyggeri screen later).
##
## Everything is STATIC and late-bound (Svc.lua_config): it compiles in `-s` drivers, needs no autoload and never throws on a missing file or
## key (a missing JSON file is {}, a missing tier is {}), so a tool can ask before the game has booted.
##
## Lifted from the design proto's scripts/home/home_data.gd (FD) and ported to the content schema: the rarity colour accessors are gone (the static
## class Rarity of P10 owns them), the tier numbers come from the Lua config (cost.gold x economy.home_cost_scale, cost.materials, cost.days,
## requires.{quests,friendship,hygge}, perks.{max_energy_bonus,storage_slots,furniture_capacity,guest_visits_per_week,unlocks}, gift_items).

const HALF_W := 64.0           # TileSet tile_size 128 x 76 (diamond down)
const HALF_H := 38.0
const PX_PER_M_V := 70.44      # vertical pixels per metre = 87.074 * cos(36 deg)
const PROPS := "res://assets/iso_props/"
const ROOMS := "res://assets/data/home/rooms/"

const DEFAULT_MAX_TIER := 10
const DEFAULT_CHEST_STACK := 99
const WEEK := 7
## crafting station (recipe field `station`) -> the unlock of lua/data/home_tiers.lua that opens it (addendum 2.2: workbench T1, loom T3, forge bench T5)
const STATION_UNLOCKS := {"snedkerbord": "workbench", "vaev": "loom", "smedje": "forge_bench"}
const FESTIVAL_UNLOCK := "festival"
## what the Fe-fest costs and how often it may be held when lua/data/home_tiers.lua does not say (config home.festival_cost / home.festival_cooldown_days)
const DEFAULT_FESTIVAL_COST := 500
const DEFAULT_FESTIVAL_COOLDOWN_DAYS := 28
## the guest gifts: ONE container of this kind is opened in this zone (area id) per visit
const VISIT_ZONE := "farm"
const VISIT_CONTAINER := "trae"

static var _json: Dictionary = {}


# ---------------------------------------------------------------------------------------------------------------- iso cell maths

## fractional cell (cell centres are integers) -> local position; identical to TileMapLayer.map_to_local for integer cells
static func cell_to_local(c: Vector2) -> Vector2:
	return Vector2((c.x - c.y) * HALF_W, (c.x + c.y) * HALF_H)


static func local_to_cell(p: Vector2) -> Vector2:
	var a := p.x / HALF_W
	var b := p.y / HALF_H
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


static func rot_dims(fp: Array, rot: int) -> Vector2i:
	return Vector2i(int(fp[0]), int(fp[1])) if rot % 2 == 0 else Vector2i(int(fp[1]), int(fp[0]))


## same convention as the baker: (x,z) -> (x c + z s, -x s + z c) with c,s = cos/sin(90 degrees * rot); front (0,1) -> (1,0) for rot 1
static func rot_vec(v: Vector2, rot: int) -> Vector2:
	match posmod(rot, 4):
		0: return v
		1: return Vector2(v.y, -v.x)
		2: return Vector2(-v.x, -v.y)
		_: return Vector2(-v.y, v.x)


# ---------------------------------------------------------------------------------------------------------------- asset contract (json)

## A JSON file parsed once and cached; {} when the file is missing or malformed (no engine error: the parse goes through JSON.new()).
static func json(path: String) -> Dictionary:
	if not _json.has(path):
		var parsed: Dictionary = {}
		if FileAccess.file_exists(path):
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(path)) == OK and typeof(parser.data) == TYPE_DICTIONARY:
				parsed = parser.data
		_json[path] = parsed
	return _json[path]


static func clear_cache() -> void:
	_json.clear()


## A texture of the home art (ResourceLoader caches it; nothing is held here, so nothing leaks at quit).
static func tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## id -> definition of assets/iso_props/furniture/furniture.json
static func furniture() -> Dictionary:
	return LuaData.dict(json(PROPS + "furniture/furniture.json").get("items", {}))


static func home() -> Dictionary:
	return json(PROPS + "home/home.json")


## the art record of tier t (1..10) in home.json: exterior, footprint, interior, platform; {} for an unknown tier
static func tier(t: int) -> Dictionary:
	var tiers := LuaData.arr(home().get("tiers", []))
	return LuaData.dict(tiers[t - 1]) if t >= 1 and t <= tiers.size() else {}


static func interior() -> Dictionary:
	return json(PROPS + "interior/interior.json")


## assets/data/home/rooms/room_tNN.json of tier t: {tier, rows, cells, floor, wall_style, door, spawn_cell, windows, max_furniture, zoom_fit}
static func room(t: int) -> Dictionary:
	return json(ROOMS + "room_t%02d.json" % t)


# ---------------------------------------------------------------------------------------------------------------- the tiers (lua/data/home_tiers.lua)

## lua/config value by dotted path: GameManager.config_value when the game is up (it honours the test seam set_config_override), else the LuaRuntime
## directly, else `default_value` (a `-s` driver without autoloads)
static func cfg(path: String, default_value: Variant = null) -> Variant:
	var gm := Svc.node("GameManager")
	if gm != null and gm.has_method("config_value"):
		return gm.call("config_value", path, default_value)
	return Svc.lua_config(path, default_value)


static func config() -> Dictionary:
	return LuaData.dict(cfg("home", {}))


static func tiers() -> Array:
	return LuaData.arr(config().get("tiers", []))


## the last tier (10 = Slottet): home.max_tier, never more than the tiers the data defines
static func last_tier() -> int:
	var defined := tiers().size()
	if defined == 0:
		return DEFAULT_MAX_TIER
	return clampi(LuaData.int_of(config().get("max_tier", defined), defined), 1, defined)


## the Lua record of tier n (1..10), {} for anything else
static func tier_def(n: int) -> Dictionary:
	var t := tiers()
	return LuaData.dict(t[n - 1]) if n >= 1 and n <= t.size() else {}


static func tier_name_key(n: int) -> String:
	return str(tier_def(n).get("name_key", "HOME_TIER_%d" % n))


static func perks(n: int) -> Dictionary:
	return LuaData.dict(tier_def(n).get("perks", {}))


static func perk_int(n: int, key: String, default_value: int = 0) -> int:
	return LuaData.int_of(perks(n).get(key, default_value), default_value)


## the price of tier n in guldagern: cost.gold x economy.home_cost_scale (P10 knob, default 1.0), rounded to whole guldagern
static func gold_cost(n: int) -> int:
	var scale := LuaData.num(cfg("economy.home_cost_scale", 1.0), 1.0)
	return maxi(roundi(LuaData.int_of(LuaData.dict(tier_def(n).get("cost", {})).get("gold", 0)) * scale), 0)


## {item id: amount} the builder needs for tier n
static func material_cost(n: int) -> Dictionary:
	return LuaData.int_map(LuaData.dict(tier_def(n).get("cost", {})).get("materials", {}))


## construction days of tier n (cost.days, at least 1) - RV-P11
static func build_days(n: int) -> int:
	return maxi(LuaData.int_of(LuaData.dict(tier_def(n).get("cost", {})).get("days", 1), 1), 1)


## the housewarming pieces of tier n (ids)
static func gift_items(n: int) -> Array[String]:
	return LuaData.strings(tier_def(n).get("gift_items", []))


static func requires(n: int) -> Dictionary:
	return LuaData.dict(tier_def(n).get("requires", {}))


## home.hygge_levels: [{id, min_decor, energy, luck, name_key}] indexed 0..5 (the index is what requires.hygge means)
static func hygge_levels() -> Array:
	return LuaData.arr(config().get("hygge_levels", []))


static func hygge_level(index: int) -> Dictionary:
	var levels := hygge_levels()
	return LuaData.dict(levels[index]) if index >= 0 and index < levels.size() else {}


## the unlocks tier n lists itself (not the earlier ones)
static func unlocks_of(n: int) -> Array[String]:
	return LuaData.strings(perks(n).get("unlocks", []))


## every unlock the data lists, in the data's order (home.unlocks)
static func unlock_ids() -> Array[String]:
	return LuaData.strings(config().get("unlocks", []))


## real | partial | stub (home.unlock_status); an unknown unlock is "stub": nothing is promised for it
static func unlock_status(unlock_name: String) -> String:
	return str(LuaData.dict(config().get("unlock_status", {})).get(unlock_name, "stub"))


## the lowest tier whose perks list `unlock_name` (0 when no tier does)
static func unlock_tier(unlock_name: String) -> int:
	for n in range(1, tiers().size() + 1):
		if unlock_name in unlocks_of(n):
			return n
	return 0


static func festival_cost() -> int:
	return maxi(LuaData.int_of(cfg("home.festival_cost", DEFAULT_FESTIVAL_COST), DEFAULT_FESTIVAL_COST), 0)


static func festival_cooldown_days() -> int:
	return maxi(LuaData.int_of(cfg("home.festival_cooldown_days", DEFAULT_FESTIVAL_COOLDOWN_DAYS), DEFAULT_FESTIVAL_COOLDOWN_DAYS), 1)


## most units of one item in one chest slot: the item's max_stack, else config home.chest_stack, else 99
static func chest_stack(item_id: Variant) -> int:
	var fallback := LuaData.int_of(cfg("home.chest_stack", DEFAULT_CHEST_STACK), DEFAULT_CHEST_STACK)
	return maxi(LuaData.int_of(ItemKinds.def(item_id).get("max_stack", fallback), fallback), 1)


# ---------------------------------------------------------------------------------------------------------------- the calendar of the weekly guests

## weekday of a total day, 0 = Monday (the same rule as TimeManager.weekday_index and the social calendar: day 1 of every season has weekday time.first_weekday)
static func weekday_of(total_day: int) -> int:
	return posmod(total_day - 1 + _first_weekday(), WEEK)


## calendar week of a total day, 0-based from day 1 (the key of every "once per week" rule)
static func week_of(total_day: int) -> int:
	return floori(float(total_day - 1 + _first_weekday()) / float(WEEK))


static func _first_weekday() -> int:
	return posmod(LuaData.int_of(cfg("time.first_weekday", 0), 0), WEEK)


## The weekdays (0 = Monday) on which the `per_week` guest visits of a week happen: spread evenly over DISTINCT weekdays,
## visit i on floor((i + 0.5) x 7 / n): 1 -> [3], 2 -> [1, 5], 3 -> [1, 3, 5], 4 -> [0, 2, 4, 6], 5 -> [0, 2, 3, 4, 6]. More than 7 counts as 7.
static func visit_weekdays(per_week: int) -> Array[int]:
	var out: Array[int] = []
	var n := clampi(per_week, 0, WEEK)
	for i in n:
		out.append(floori((float(i) + 0.5) * float(WEEK) / float(n)))
	return out
