class_name Rarity
extends RefCounted
## The one rarity ladder of furniture, clothing and materials: normal < uncommon < rare < unique < legendary
## (addendum 2.1, DF2). Data: lua/config/rarity.lua (`config.rarity_tiers`); a built-in copy of the SAME numbers is the
## fallback so tools and tests without the Lua config agree (tests/sections/rarity.gd checks both are identical).
##
## rank 1..5 (content numbering); pips = rank - 1 (0..4); pip shapes leaf, diamond, sparkle, star.
## Policy (code, not data): unique and legendary are keepsakes - one per save, never bought, sold or crafted.
## `common` is an alias of normal, `epic` is NOT a rarity (the Lua lint reports it).
## Colour rules (the guide): gold e3c372 is for focus/selection ONLY; no red anywhere (Tornebaer b3436b is the damage colour);
## legendary is the only dark tile (night 2f3654), its icons use the pale `_night` rim.

const IDS: Array[StringName] = [&"normal", &"uncommon", &"rare", &"unique", &"legendary"]
const ALIASES := {"common": "normal"}
const PIP_SHAPES := ["none", "leaf", "diamond", "sparkle", "star"]
## first rank that is a keepsake (unique)
const KEEPSAKE_FROM_RANK := 4
## the focus / selection gold of the guide; no rarity ring may use it
const FOCUS_GOLD := "e3c372"
## Tornebaer: damage, "too dear", missing ingredient. Rarity labels keep their distance from it (CIEDE2000 >= 10)
const DAMAGE_COLOUR := "b3436b"
## the ink of icons and borders
const INK := "2b2340"

const _FALLBACK := {
	"order": ["normal", "uncommon", "rare", "unique", "legendary"],
	"normal": {
		"rank": 1, "name_key": "RARITY_NORMAL", "ui": {"fill": "fbf5e6", "ring": "2b2340", "label": "4c4058"},
		"weapon_price": 100, "gem_price": 45, "material_price": 12, "weapon_sell_ratio": 0.15, "gem_sell_ratio": 0.44,
		"furniture_price": 150, "clothing_price": 60, "sell_ratio": 0.4, "decor": 2, "find_weight": 100,
	},
	"uncommon": {
		"rank": 2, "name_key": "RARITY_UNCOMMON", "ui": {"fill": "e3efd2", "ring": "6b9a3e", "label": "3f6b22"},
		"weapon_price": 750, "gem_price": 150, "material_price": 55, "weapon_sell_ratio": 0.12, "gem_sell_ratio": 0.44,
		"furniture_price": 450, "clothing_price": 220, "sell_ratio": 0.4, "decor": 5, "find_weight": 40,
	},
	"rare": {
		"rank": 3, "name_key": "RARITY_RARE", "ui": {"fill": "e2d8f4", "ring": "9b86d6", "label": "5d4fa3"},
		"weapon_price": 1800, "gem_price": 450, "material_price": 160, "weapon_sell_ratio": 0.1, "gem_sell_ratio": 0.44,
		"furniture_price": 1600, "clothing_price": 800, "sell_ratio": 0.38, "decor": 11, "find_weight": 12,
	},
	"unique": {
		"rank": 4, "name_key": "RARITY_UNIQUE", "ui": {"fill": "f9e0e7", "ring": "e58fa6", "label": "7d2e59"},
		"weapon_price": 5000, "gem_price": 1500, "material_price": 600, "weapon_sell_ratio": 0.0, "gem_sell_ratio": 0.0,
		"furniture_price": 5000, "clothing_price": 2600, "sell_ratio": 0.0, "decor": 24, "find_weight": 3,
	},
	"legendary": {
		"rank": 5, "name_key": "RARITY_LEGENDARY",
		"ui": {"fill": "2f3654", "ring": "a9d3e0", "label": "2b2340", "pip": "f2c14e", "icon_rim": "e4eff5"},
		"weapon_price": 12000, "gem_price": 4500, "material_price": 2500, "weapon_sell_ratio": 0.0, "gem_sell_ratio": 0.0,
		"furniture_price": 12000, "clothing_price": 7000, "sell_ratio": 0.0, "decor": 42, "find_weight": 1,
	},
}


## The `rarity_tiers` table: from the Lua config, or the built-in copy when the config is missing / empty.
static func tiers() -> Dictionary:
	var c: Variant = Svc.lua_config("rarity_tiers", null)
	return c if typeof(c) == TYPE_DICTIONARY and not (c as Dictionary).is_empty() else _FALLBACK


## The built-in copy (tests compare it with the Lua file).
static func builtin_tiers() -> Dictionary:
	return _FALLBACK


## "common" -> normal; "" and unknown ids -> normal (use is_valid() first where an unknown id must be rejected).
static func normalize(id: Variant) -> StringName:
	var s := str(id)
	if s == "":
		return &"normal"
	s = str(ALIASES.get(s, s))
	return StringName(s) if _FALLBACK.has(s) and s != "order" else &"normal"


static func is_valid(id: Variant) -> bool:
	var s := str(ALIASES.get(str(id), str(id)))
	return s != "order" and _FALLBACK.has(s)


## The five ids in ladder order (from the config's `order`, else IDS).
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for x in LuaData.arr(tiers().get("order", [])):
		if is_valid(x):
			out.append(StringName(str(x)))
	return out if out.size() == IDS.size() else IDS


static func _row(id: Variant) -> Dictionary:
	var key := str(normalize(id))
	return LuaData.dict(tiers().get(key, _FALLBACK[key]))


static func rank(id: Variant) -> int:
	return LuaData.int_of(_row(id).get("rank", 1), 1)


## pip count of the tile: rank - 1 (normal has none)
static func pips(id: Variant) -> int:
	return maxi(rank(id) - 1, 0)


## "none" | "leaf" | "diamond" | "sparkle" | "star": colour is never the only cue
static func shape(id: Variant) -> String:
	return str(PIP_SHAPES[clampi(pips(id), 0, PIP_SHAPES.size() - 1)])


static func sell_ratio(id: Variant, kind: String = "") -> float:
	var row := _row(id)
	return LuaData.num(row.get(kind+"_sell_ratio",row.get("sell_ratio",0.4)))


## relative find weight in loot rolls (100 / 40 / 12 / 3 / 1)
static func find_weight(id: Variant) -> float:
	return LuaData.num(_row(id).get("find_weight", 1.0))


## alias of find_weight (the design prototype called it drop_weight)
static func drop_weight(id: Variant) -> float:
	return find_weight(id)


## "furniture" | "clothing": the reference buy price of a piece of that rarity
static func base_price(id: Variant, kind: String) -> int:
	return LuaData.int_of(_row(id).get("%s_price" % kind, 0))


## hygge points a placed piece of that rarity is worth (before the size factor)
static func decor(id: Variant) -> int:
	return LuaData.int_of(_row(id).get("decor", 0))


## unique and legendary: one per save, refused a second time, never in a shop pool
static func is_one_of_a_kind(id: Variant) -> bool:
	return rank(id) >= KEEPSAKE_FROM_RANK


static func sellable(id: Variant) -> bool:
	return not is_one_of_a_kind(id)


static func buyable(id: Variant) -> bool:
	return not is_one_of_a_kind(id)


static func craftable(id: Variant) -> bool:
	return not is_one_of_a_kind(id)


## translation key of the rarity word ("Almindelig" ... "Legendarisk"); the keys live in finds.csv (F1)
static func label_key(id: Variant) -> String:
	return str(_row(id).get("name_key", "RARITY_%s" % str(normalize(id)).to_upper()))


## UI colours of a rarity as Colors: fill, ring, label, pip, icon_rim (alpha 0 when the rarity has none) and
## has_ring (false for normal: its tile has the ink border only), ring_w (px; 0 without a ring), night (the tile is dark:
## only legendary). NEVER the focus gold: a selected slot REPLACES the ring by the selection ring.
static func ui(id: Variant) -> Dictionary:
	var u := LuaData.dict(_row(id).get("ui", {}))
	var r := rank(id)
	var ring := Color.html(str(u.get("ring", INK)))
	var label := Color.html(str(u.get("label", "4c4058")))
	var pip_hex := str(u.get("pip", ""))
	var rim_hex := str(u.get("icon_rim", ""))
	var fill := Color.html(str(u.get("fill", "fbf5e6")))
	return {
		"fill": fill,
		"ring": ring,
		"has_ring": r > 1,
		"ring_w": 3 if r > 1 else 0,
		"label": label,
		"pip": Color.html(pip_hex) if pip_hex != "" else (ring if r > 1 else label),
		"icon_rim": Color.html(rim_hex) if rim_hex != "" else Color(0, 0, 0, 0),
		"night": fill.get_luminance() < 0.4,
	}


## -1 when `a` ranks higher than `b` (comes first in a descending list), 1 when lower, 0 when equal. Arguments are rarity ids.
static func compare(a: Variant, b: Variant) -> int:
	var ra := rank(a)
	var rb := rank(b)
	if ra != rb:
		return -1 if ra > rb else 1
	return 0


## Sorts `items` by rarity (default: highest first), ties by `name_fn(item)` ascending (default: the item itself as text).
## `rarity_fn(item)` returns the rarity id of an item.
static func sorted(items: Array, rarity_fn: Callable, name_fn: Callable = Callable(), descending: bool = true) -> Array:
	var out := items.duplicate()
	out.sort_custom(func(x: Variant, y: Variant) -> bool:
		var rx := rank(rarity_fn.call(x))
		var ry := rank(rarity_fn.call(y))
		if rx != ry:
			return rx > ry if descending else rx < ry
		var nx := str(name_fn.call(x)) if name_fn.is_valid() else str(x)
		var ny := str(name_fn.call(y)) if name_fn.is_valid() else str(y)
		return nx < ny)
	return out


## Item ids sorted by the rarity of their definition (rarity descending, then id) - the order of backpack, Garderobe, shops, Indretning.
static func sorted_ids(item_ids: Array, descending: bool = true) -> Array:
	return sorted(item_ids, func(id: Variant) -> Variant: return ItemKinds.rarity_of(id), Callable(), descending)
