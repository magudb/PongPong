class_name LootRules
extends RefCounted
## The pure draws of the container algorithm (SCHEMA section 6, addendum 2.3 / 2.5): no node, no autoload, no state of its own. LootService composes
## them; tests/sections/loot.gd runs them 40 000 times per container without delivering anything.
##
## DRAW of one ORDINARY roll (a chest, a dig, a creature drop):
##   1. find_chance      (1.0 for every chest tier; dig 0.12, the farm dig 0.06; creatures 0.02 - 0.04): a miss is an empty roll
##   2. kind             by the container's `kinds` weights (furniture clothing material; the dungeon adds weapon gem)
##   3. rarity           by `odds` in basis points {normal, uncommon, rare} AFTER luck (see luck_odds): UNIQUE AND LEGENDARY HAVE NO COLUMN, they never come from a chest
##   4. item             by `w` from zones.<zone>.pools.<kind>.<rarity>
## An EMPTY pool re-draws the KIND (statistically: the kind is drawn again among the kinds that have an item of the rarity already drawn, so the rarity
## distribution stays exactly the designed odds - the property the content validator's rule R10 measures).
## An item of a keepsake rarity (rank >= unique) that somebody put into a pool is skipped: a pool can never hand out a keepsake (validator R3 + the runtime guard).
##
## LUCK L = clamp(Perks.total("luck"), 0, 0.20): uncommon and rare odds x (1 + 5 L), `normal` absorbs the difference; when the two would exceed the whole (the
## king's chest at high luck) they are scaled down together and normal is 0. The wanderer chance is x (1 + 5 L) as well.

const LUCK_CAP := 0.20
const LUCK_FACTOR := 5.0
## the rarity columns of the odds tables: unique and legendary are NOT here on purpose
const ORDINARY: Array[String] = ["normal", "uncommon", "rare"]
const BASIS := 10000.0


## container uid of a marker = the area id + ":" + the marker cell ("farm:12,34"); a generated dungeon floor uses DungeonFloors.uid_of ("dg:...")
static func container_uid(area_id: Variant, cell: Vector2i) -> String:
	return "%s:%d,%d" % [str(area_id), cell.x, cell.y]


static func clamp_luck(luck: float) -> float:
	return clampf(luck, 0.0, LUCK_CAP)


## The odds {normal, uncommon, rare} (floats, basis points, summing to the base total) after luck. Unknown / keepsake keys of `odds` are ignored.
static func luck_odds(odds: Dictionary, luck: float) -> Dictionary:
	var n0 := maxf(LuaData.num(odds.get("normal", 0)), 0.0)
	var u0 := maxf(LuaData.num(odds.get("uncommon", 0)), 0.0)
	var r0 := maxf(LuaData.num(odds.get("rare", 0)), 0.0)
	var whole := n0 + u0 + r0
	if whole <= 0.0:
		return {"normal": 0.0, "uncommon": 0.0, "rare": 0.0}
	var f := 1.0 + LUCK_FACTOR * clamp_luck(luck)
	var u := u0 * f
	var r := r0 * f
	if u + r > whole:
		var s := whole / (u + r)
		u *= s
		r *= s
	return {"normal": whole - u - r, "uncommon": u, "rare": r}


## Index of the item pools of a loot config, built ONCE per config: {zone: {kind: {rarity: {items: Array[String], cum: PackedFloat64Array, total: float}}}}
## Entries of a keepsake rarity (rank >= unique), entries without an item id and entries with a weight <= 0 are left out. An empty pool has no slice.
static func build_index(cfg: Dictionary) -> Dictionary:
	var out := {}
	var zones := LuaData.dict(cfg.get("zones", {}))
	for zone in zones:
		var pools := LuaData.dict(LuaData.dict(zones[zone]).get("pools", {}))
		var by_kind := {}
		for kind in pools:
			var by_rarity := {}
			var rarities := LuaData.dict(pools[kind])
			for rarity in rarities:
				var items: Array[String] = []
				var cum := PackedFloat64Array()
				var total := 0.0
				for e in LuaData.arr(rarities[rarity]):
					var ed := LuaData.dict(e)
					var id := str(ed.get("item", ""))
					var w := LuaData.num(ed.get("w", 1.0), 1.0)
					if id == "" or w <= 0.0 or ItemKinds.is_one_of_a_kind(id):
						continue
					total += w
					items.append(id)
					cum.append(total)
				if not items.is_empty():
					by_rarity[str(rarity)] = {"items": items, "cum": cum, "total": total}
			by_kind[str(kind)] = by_rarity
		out[str(zone)] = by_kind
	return out


## Weighted pick of a key of {key: weight}; "" when every weight is <= 0. Consumes exactly one rng draw.
static func pick_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += maxf(LuaData.num(weights[k]), 0.0)
	if total <= 0.0:
		return ""
	var x := rng.randf() * total
	var acc := 0.0
	var last := ""
	for k in weights:
		var w := maxf(LuaData.num(weights[k]), 0.0)
		if w <= 0.0:
			continue
		acc += w
		last = str(k)
		if x < acc:
			return last
	return last


## One item of a pool slice by weight (one rng draw).
static func pick_item(rng: RandomNumberGenerator, slice: Dictionary) -> String:
	var items: Array = slice["items"]
	var cum: PackedFloat64Array = slice["cum"]
	var x := rng.randf() * float(slice["total"])
	for i in cum.size():
		if x < cum[i]:
			return str(items[i])
	return str(items[items.size() - 1])


static func slice_of(index: Dictionary, zone: String, kind: String, rarity: String) -> Dictionary:
	return LuaData.dict(LuaData.dict(LuaData.dict(index.get(zone, {})).get(kind, {})).get(rarity, {}))


## The container `container_id` as played in `zone`: the base row of loot.containers with the zone's own override
## (zones.<zone>.containers.<id>: odds, kinds, find_chance, rolls ... ; `count` is map data and dropped). {} when the container does not exist.
static func container_cfg(cfg: Dictionary, zone: String, container_id: String) -> Dictionary:
	var base := LuaData.dict(LuaData.dict(cfg.get("containers", {})).get(container_id, {}))
	if base.is_empty():
		return {}
	var out := base.duplicate(true)
	var over := LuaData.dict(LuaData.dict(LuaData.dict(LuaData.dict(cfg.get("zones", {})).get(zone, {})).get("containers", {})).get(container_id, {}))
	for k in over:
		if str(k) != "count":
			out[k] = over[k]
	return out


## A container (or creature) row COMPILED for one zone and one luck: the weights as flat arrays, the pools of the zone resolved. Compiling is the only expensive part of a draw; a caller
## that rolls several times (an opening with 3 rolls, 40 000 statistical openings) compiles once and calls roll_plan(). The plan is bound to the row and the luck it was made from:
## compile again after either changes.
class Plan extends RefCounted:
	var find_chance: float = 1.0
	var kinds: Array[String] = []                  # the kinds with a weight > 0, in declaration order
	var kind_w := PackedFloat64Array()
	var kind_total: float = 0.0
	var rarities: Array[String] = []               # the rarities with odds > 0 after luck (normal, uncommon, rare)
	var rarity_w := PackedFloat64Array()
	var rarity_total: float = 0.0
	var pools: Dictionary = {}                     # {kind: {rarity: slice}} of the zone (a reference into the index)


## The row `cc` of zone `zone` at `luck` (clamped), ready for roll_plan().
static func compile(index: Dictionary, zone: String, cc: Dictionary, luck: float) -> Plan:
	var p := Plan.new()
	p.find_chance = LuaData.num(cc.get("find_chance", 1.0), 1.0)
	var kinds := LuaData.dict(cc.get("kinds", {}))
	for k in kinds:
		var w := maxf(LuaData.num(kinds[k]), 0.0)
		if w > 0.0:
			p.kinds.append(str(k))
			p.kind_w.append(w)
			p.kind_total += w
	var odds := luck_odds(LuaData.dict(cc.get("odds", {})), luck)
	for r in ORDINARY:
		var w2 := maxf(LuaData.num(odds[r]), 0.0)
		if w2 > 0.0:
			p.rarities.append(r)
			p.rarity_w.append(w2)
			p.rarity_total += w2
	p.pools = LuaData.dict(index.get(zone, {}))
	return p


## the same draw as pick_weighted over flat arrays of the POSITIVE weights (one rng draw, none when the total is 0)
static func _pick(rng: RandomNumberGenerator, keys: Array[String], weights: PackedFloat64Array, total: float) -> String:
	if total <= 0.0:
		return ""
	var x := rng.randf() * total
	var acc := 0.0
	for i in keys.size():
		acc += weights[i]
		if x < acc:
			return keys[i]
	return keys[keys.size() - 1]


## One roll of a compiled row: {id, amount: 1, rarity, kind}, or {} for a roll that found nothing (find_chance missed, or no kind has an item of the drawn rarity).
## The draws, in this order: find_chance (only when < 1), kind, rarity, [kind again for an empty pool], item.
static func roll_plan(p: Plan, rng: RandomNumberGenerator) -> Dictionary:
	if p.find_chance < 1.0 and rng.randf() >= p.find_chance:
		return {}
	var kind := _pick(rng, p.kinds, p.kind_w, p.kind_total)
	var rarity := _pick(rng, p.rarities, p.rarity_w, p.rarity_total)
	if kind == "" or rarity == "":
		return {}
	var slice: Dictionary = (p.pools.get(kind, {}) as Dictionary).get(rarity, {})
	if slice.is_empty():
		# an EMPTY pool re-draws the kind among the kinds that have an item of this rarity
		var open_kinds: Array[String] = []
		var open_w := PackedFloat64Array()
		var open_total := 0.0
		for i in p.kinds.size():
			if not ((p.pools.get(p.kinds[i], {}) as Dictionary).get(rarity, {}) as Dictionary).is_empty():
				open_kinds.append(p.kinds[i])
				open_w.append(p.kind_w[i])
				open_total += p.kind_w[i]
		kind = _pick(rng, open_kinds, open_w, open_total)
		if kind == "":
			return {}
		slice = (p.pools[kind] as Dictionary)[rarity]
	return {"id": pick_item(rng, slice), "amount": 1, "rarity": rarity, "kind": kind}


## One ordinary roll: {id, amount: 1, rarity, kind}, or {} for a roll that found nothing. `cc` is a container (or creature) row; `luck` is applied here (clamped).
## A caller with several rolls compiles once: roll_plan(compile(...), rng).
static func roll_ordinary(index: Dictionary, zone: String, cc: Dictionary, luck: float, rng: RandomNumberGenerator) -> Dictionary:
	return roll_plan(compile(index, zone, cc, luck), rng)


## The number of rolls of one opening (rolls.min .. rolls.max, one rng draw when they differ).
static func roll_count(cc: Dictionary, rng: RandomNumberGenerator) -> int:
	var rolls := LuaData.dict(cc.get("rolls", {}))
	var lo := maxi(LuaData.int_of(rolls.get("min", 1), 1), 1)
	var hi := maxi(LuaData.int_of(rolls.get("max", lo), lo), lo)
	return lo if hi == lo else rng.randi_range(lo, hi)


## The unique wanderers of (zone, container) that are still unfound: [{item, container}] in declaration order.
static func unfound_wanderers(cfg: Dictionary, zone: String, container_id: String, found: Array, owned_test: Callable = Callable()) -> Array:
	var out: Array = []
	for w in LuaData.arr(LuaData.dict(LuaData.dict(cfg.get("zones", {})).get(zone, {})).get("wanderers", [])):
		var wd := LuaData.dict(w)
		var id := str(wd.get("item", ""))
		if id == "" or str(wd.get("container", "")) != container_id or id in found:
			continue
		if owned_test.is_valid() and bool(owned_test.call(id)):
			continue
		out.append({"item": id, "container": container_id})
	return out


## The wanderer chance of an opening in basis points after luck: wander_bp x (1 + 5 L), at most 10 000.
static func wander_chance_bp(cc: Dictionary, luck: float) -> float:
	return minf(LuaData.num(cc.get("wander_bp", 0)) * (1.0 + LUCK_FACTOR * clamp_luck(luck)), BASIS)


## The wanderer decision of one opening: true = the first roll is the wanderer. `misses` = openings of this (zone, container) since the last wanderer
## (or the start) that found none. The pity: the opening number `pity_opens` is certain, i.e. `misses + 1 >= pity_opens` (0 = no pity).
static func wanderer_due(cc: Dictionary, luck: float, misses: int, rng: RandomNumberGenerator) -> bool:
	var bp := wander_chance_bp(cc, luck)
	if bp <= 0.0:
		return false
	var pity := LuaData.int_of(cc.get("pity_opens", 0))
	if pity > 0 and misses + 1 >= pity:
		return true
	return rng.randf() * BASIS < bp


## The legendary decision of one repeat boss kill: true = a legendary from the pool. `misses` = repeat kills since the last one that paid a legendary.
## p = legendary_bp / 10 000; the kill number `pity_kills` is certain (`misses + 1 >= pity_kills`).
static func boss_legendary_due(bcfg: Dictionary, misses: int, rng: RandomNumberGenerator) -> bool:
	var pity := LuaData.int_of(bcfg.get("pity_kills", 0))
	if pity > 0 and misses + 1 >= pity:
		return true
	return rng.randf() * BASIS < LuaData.num(bcfg.get("legendary_bp", 0))


## "furniture" | "clothing" | the item's category: the `kind` of a result row for an item that was not drawn from a kind table (wanderer, spot, gift, capstone).
static func kind_of_item(item_id: String) -> String:
	var cat := str(ItemKinds.def(item_id).get("category", ""))
	return cat if cat != "" else "material"
