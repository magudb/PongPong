class_name SocialData
extends RefCounted
## Typed, tolerant readers of the social data (lua/social/*.lua, the registries `festivals` and `events`) with the DERIVED defaults that make "a new NPC =
## one row in npcs.lua" true: an NPC with friendship = true and no row in `citizens` still gets hearts, gifts and a birthday (tier C, archetype from
## `social.role_archetype[role]`, birthday from the id alone). Pure statics, late bound through Svc: nothing here names an autoload, so the class
## compiles in `-s` drivers and nothing is required to boot (an absent LuaRuntime, config key or registry reads as "no data").
##
## DEFAULTS is the code twin of lua/social/social.lua (social.config_defaults_equal_lua proves they are equal): cfg(path) falls back to it, so a
## missing Lua key never breaks anything.

const TIERS := ["A", "B", "C"]

const DEFAULTS := {
	"points_per_heart": 100,
	"heart_cap": 10,
	"chat_points": 100,
	"chat_min_lines": 1,
	"toast_gap_s": 1.5,
	"gifts": {
		"per_day": 1, "per_week": 2, "love": 40, "like": 20, "neutral": 8, "dislike": 0, "hate": 0,
		"rarity_uncommon": 1.25, "rarity_rare": 1.5, "birthday_mult": 4.0, "belated_mult": 2.0, "belated_days": 1,
		"repeat_days": 14, "repeat_mult": 0.5, "max_points": 160, "known_cap": 40,
	},
	"purchase": {"gold_per_point": 100, "weekly_cap": 10},
	"festival": {"attend_points": 20, "max_attendees": 15},
	"rs_stages": ["hjertven", "forlovet", "gift"],
	"stage_order": ["fremmed", "bekendt", "nabo", "ven", "god_ven", "bedste_ven"],
	"stage_hearts": {"fremmed": 0, "bekendt": 1, "nabo": 2, "ven": 4, "god_ven": 6, "bedste_ven": 8},
	"role_archetype": {
		"mayor": "fairy", "baker": "shopkeeper", "shopkeeper": "shopkeeper", "villager": "wanderer", "king": "elder", "child": "child",
		"smith": "craftsman", "guard": "watcher", "animal_keeper": "gardener", "wizard": "elder", "elder": "elder", "postman": "wanderer",
		"builder": "craftsman", "furnisher": "fairy", "tailor": "fairy", "gardener": "gardener", "carpenter": "craftsman",
		"bathkeeper": "elder", "appraiser": "elder", "mapseller": "watcher", "beekeeper": "gardener",
		"innkeeper": "shopkeeper", "clerk": "watcher", "musician": "wanderer", "apprentice": "wanderer", "lamplighter": "wanderer", "baker_helper": "shopkeeper",
	},
}

## Friend list cache: the answer only depends on the live `npcs` and `citizens` tables, so it is kept for as long as BOTH are the same objects
## (a Lua reload builds new ones; a test fake brings its own).
static var _friends_npcs: Variant = null
static var _friends_citizens: Variant = null
static var _friends_cache: Array[String] = []

## The ONE empty table every reader hands out for "no data": a missing config key or registry would otherwise answer a NEW `{}` on every call and defeat the
## identity checks of the caches above and of SocialManager (the friend list and the birthday index were rebuilt on every call until citizens.lua exists:
## birthday: terms cost 475 microseconds instead of 4). Read it, never write to it.
static var _none: Dictionary = {}


# ================================================================================================ config

static func _walk(root: Variant, path: String) -> Variant:
	var cur: Variant = root
	for part in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not (cur as Dictionary).has(part):
			return null
		cur = (cur as Dictionary)[part]
	return cur


## Memo of the config readers: valid while the live `social` table is the same object (a Lua reload or a test fake brings a new one). The merged tables handed out
## by cfg_dict() are shared: read them, never write to them.
static var _cfg_src: Variant = null
static var _cfg_valid: bool = false
static var _cfg_cache: Dictionary = {}


static func _cfg_check() -> void:
	var root: Variant = Svc.lua_config("social", null)
	if not _cfg_valid or not is_same(root, _cfg_src):
		_cfg_cache.clear()
		_cfg_src = root
		_cfg_valid = true


## `social.<path>` from lua/social/social.lua, the code default when the key is missing, `default_value` when the default does not know it either.
static func cfg(path: String, default_value: Variant = null) -> Variant:
	_cfg_check()
	if _cfg_cache.has(path):
		var hit: Variant = _cfg_cache[path]
		return hit if hit != null else default_value
	var v: Variant = null
	if typeof(_cfg_src) == TYPE_DICTIONARY:
		v = _walk(_cfg_src, path)
	if v == null:
		v = _walk(DEFAULTS, path)
	_cfg_cache[path] = v
	return v if v != null else default_value


static func cfg_int(path: String, default_value: int) -> int:
	return LuaData.int_of(cfg(path, default_value), default_value)


static func cfg_num(path: String, default_value: float) -> float:
	return LuaData.num(cfg(path, default_value), default_value)


## A table of the config with the code defaults UNDER the Lua values (a Lua table that lacks one key still answers it). Shared and memoised: do not modify it.
static func cfg_dict(path: String) -> Dictionary:
	_cfg_check()
	var key := "dict:" + path
	if _cfg_cache.has(key):
		return _cfg_cache[key]
	var out: Dictionary = LuaData.dict(_walk(DEFAULTS, path)).duplicate(true)
	var lua: Dictionary = LuaData.dict(_walk(_cfg_src, path)) if typeof(_cfg_src) == TYPE_DICTIONARY else {}
	for k in lua:
		out[k] = lua[k]
	_cfg_cache[key] = out
	return out


## The friendship stages in order as [[stage id (StringName), hearts needed (int)], ...] (social.stage_order / stage_hearts), memoised: stage() runs for every `stage:` term.
static func stage_table() -> Array:
	_cfg_check()
	if _cfg_cache.has("stage_table"):
		return _cfg_cache["stage_table"]
	var table: Array = []
	var by_hearts := cfg_dict("stage_hearts")
	for s in LuaData.arr(cfg("stage_order", ["fremmed"])):
		table.append([StringName(str(s)), LuaData.int_of(by_hearts.get(s, 0))])
	_cfg_cache["stage_table"] = table
	return table


## (points per heart, heart cap) in ONE memoised read: hearts() is on the hot path of every `hearts:` marker, so it pays one config check instead of two.
static func heart_scale() -> Vector2i:
	_cfg_check()
	if _cfg_cache.has("scale"):
		return _cfg_cache["scale"]
	var scale := Vector2i(maxi(cfg_int("points_per_heart", 100), 1), clampi(cfg_int("heart_cap", 10), 1, 20))
	_cfg_cache["scale"] = scale
	return scale


# ================================================================================================ roster

static func npcs() -> Dictionary:
	var v: Variant = Svc.lua_config("npcs", null)
	return v as Dictionary if typeof(v) == TYPE_DICTIONARY else _none


static func citizens() -> Dictionary:
	var v: Variant = Svc.lua_config("citizens", null)
	return v as Dictionary if typeof(v) == TYPE_DICTIONARY else _none


static func npc_row(npc: String) -> Dictionary:
	return LuaData.dict(npcs().get(npc, {}))


## ids of every NPC that can reach hearts (npcs.lua friendship = true, or a citizens row with an `unlock`), SORTED (every daily loop and every
## ordering of the social layer runs in this order).
static func friend_ids() -> Array[String]:
	var n := npcs()
	var cz := citizens()
	if _friends_npcs != null and is_same(_friends_npcs, n) and is_same(_friends_citizens, cz):
		return _friends_cache
	var out: Array[String] = []
	for id in n:
		var row := LuaData.dict(n[id])
		if bool(row.get("friendship", false)) or LuaData.dict(LuaData.dict(cz.get(id, {})).get("unlock", {})).size() > 0:
			out.append(str(id))
	out.sort()
	_friends_npcs = n
	_friends_citizens = cz
	_friends_cache = out
	return out


static func is_friend_id(npc: String) -> bool:
	return npc in friend_ids()


## The `unlock` of a citizen ({quest, day} of Morfar Mis) or {}.
static func unlock_of(npc: String) -> Dictionary:
	return LuaData.dict(LuaData.dict(citizens().get(npc, {})).get("unlock", {}))


## The citizens row of an NPC with every derived default filled in: {tier, archetype, birthday{season,day}, partner, derived: bool, ...the authored fields}.
static func citizen(npc: String) -> Dictionary:
	var rows := citizens()
	var authored: Dictionary = LuaData.dict(rows.get(npc, {}))
	var row: Dictionary = authored.duplicate()
	var derived := authored.is_empty()
	if not row.has("tier") or str(row["tier"]) not in TIERS:
		row["tier"] = "C"
	if not row.has("archetype"):
		var role := str(npc_row(npc).get("role", ""))
		row["archetype"] = str(cfg_dict("role_archetype").get(role, "wanderer"))
	if not row.has("birthday"):
		row["birthday"] = derived_birthday(npc)
		derived = true
	row["partner"] = bool(row.get("partner", false))
	row["derived"] = derived
	return row


## A stable birthday from the id alone (never from the other NPCs: adding an NPC must not move anybody's birthday).
static func derived_birthday(npc: String) -> Dictionary:
	var season_list := CalendarUtil.seasons()
	var dps := CalendarUtil.days_per_season()
	var h := SocialRng.fmix32(SocialRng.fnv1a32("birthday|" + npc))
	var idx := h % (season_list.size() * dps)
	return {"season": str(season_list[floori(float(idx) / float(dps))]), "day": idx % dps + 1}


## The birthday of an NPC as {season: String, day: int} (the numbers of the Lua table arrive as floats).
static func birthday_of(npc: String) -> Dictionary:
	var b := LuaData.dict(citizen(npc)["birthday"])
	return {"season": str(b.get("season", "")), "day": LuaData.int_of(b.get("day", 1), 1)}


## The keeper sample of a shopkeeper (S-data: citizens.<npc>.sample = {item, from_hearts}) or {}.
static func sample_of(npc: String) -> Dictionary:
	return LuaData.dict(LuaData.dict(citizens().get(npc, {})).get("sample", {}))


## The NPC that keeps `shop_id` (npcs.lua shop_id), "" when nobody does.
static func keeper_of(shop_id: String) -> String:
	var n := npcs()
	var ids: Array = n.keys()
	ids.sort()
	for id in ids:
		if str(LuaData.dict(n[id]).get("shop_id", "")) == shop_id:
			return str(id)
	return ""


# ================================================================================================ registries (kind = registry, the towns track's P10 carve-out)

## `registry = "festivals"` / `registry = "events"`: the KEY of the top-level table is the id. Late bound: no LuaRuntime or no registry kind -> {} (nothing is
## ever required to boot). The returned dictionary is the live registry: read-only.
static func registry(registry_name: String) -> Dictionary:
	var lr := Svc.node("LuaRuntime")
	if lr != null and lr.has_method("get_registry"):
		var reg: Dictionary = LuaData.dict(lr.call("get_registry", registry_name))
		return reg if not reg.is_empty() else _none
	return _none


static func festivals() -> Dictionary:
	return registry("festivals")


static func festival(id: String) -> Dictionary:
	if id == "bryllupsfesten": return Svc.static_call("res://scripts/social/relationships/relationship_flow.gd",&"wedding_definition",[],{})
	return LuaData.dict(festivals().get(id, {}))


## id -> def of every event; `npc` filters by meta.npc.
static func events(npc: String = "") -> Dictionary:
	var all := registry("events")
	if npc == "":
		return all
	var out := {}
	for eid in all:
		if str(LuaData.dict(LuaData.dict(all[eid]).get("meta", {})).get("npc", "")) == npc:
			out[eid] = all[eid]
	return out


static func event(id: String) -> Dictionary:
	return LuaData.dict(registry("events").get(id, {}))


# ================================================================================================ festival roster (ordering rule of the ghost family amendment AGF17)

## Who attends a festival and in which order they take the gather posts. A pure function of the festival's meta, the world seed and the NPC rows, so the
## routine layer, the festival runtime and the validator all get the same list:
##   (1) the host (never skipped by a shop; absent when he is a hero twin);
##   (2) meta.first in the given order, deduplicated, kept OUTSIDE the cap (a first member is a home citizen of the area: he is removed from the ordered pool);
##   (3) the other home citizens of the area ordered by SocialRng.roll(seed, [festival, npc]), the first `max_attendees` of them;
##   (4) meta.guests (citizens of ANOTHER area), outside the cap.
## Absent hero twins and keepers of a `stays_open` shop (they stay at their counter) are never part of it (the host excepted). The crowd is at most
## max_attendees + 1 + len(first) + len(guests). `gather` = first + pool + guests (the order of fest_<spot>_gather_<n>).
## Returns {host, first, pool, guests, gather} (Arrays of ids; host "" when there is none).
static func festival_roster(festival_id: String, meta: Dictionary, world_seed: int, npc_rows: Dictionary, absent: Array, max_attendees: int) -> Dictionary:
	var area := str(meta.get("area", ""))
	var stays := LuaData.strings(meta.get("stays_open", []))
	var host := str(meta.get("host", ""))
	var skip := {}
	for a in absent:
		skip[str(a)] = true
	for id in npc_rows:
		if str(LuaData.dict(npc_rows[id]).get("shop_id", "")) in stays:
			skip[str(id)] = true
	var out := {"host": "", "first": [], "pool": [], "guests": [], "gather": []}
	var taken := {}
	if host != "" and npc_rows.has(host) and not absent.has(host):
		out["host"] = host
		taken[host] = true
	var named_first := {}
	for f in LuaData.strings(meta.get("first", [])):
		named_first[f] = true
		if not taken.has(f) and not skip.has(f) and npc_rows.has(f):
			(out["first"] as Array).append(f)
			taken[f] = true
	var ids: Array = npc_rows.keys()
	ids.sort()
	var ordered: Array = []
	for id in ids:
		var sid := str(id)
		if str(LuaData.dict(npc_rows[id]).get("home_area", "")) != area or sid == host or taken.has(sid) or named_first.has(sid) or skip.has(sid):
			continue
		ordered.append([SocialRng.roll(world_seed, [festival_id, sid]), sid])
	ordered.sort_custom(func(a: Array, b: Array) -> bool:
		return str(a[1]) < str(b[1]) if is_equal_approx(float(a[0]), float(b[0])) else float(a[0]) < float(b[0]))
	for i in mini(ordered.size(), maxi(max_attendees, 0)):
		(out["pool"] as Array).append(str((ordered[i] as Array)[1]))
		taken[str((ordered[i] as Array)[1])] = true
	for g in LuaData.strings(meta.get("guests", [])):
		if not taken.has(g) and not skip.has(g) and npc_rows.has(g):
			(out["guests"] as Array).append(g)
			taken[g] = true
	out["gather"] = (out["first"] as Array) + (out["pool"] as Array) + (out["guests"] as Array)
	return out
