class_name ShopRotation
extends RefCounted
## The rotating stock of the home shops (lua/shops/home_shops.lua: furniture_shop, tailor_shop, builder_yard, flea_market; package F4). Static and PURE: the same save sees
## the same shelf on the same day, on every load.
##
## CONTRACT with ShopSystem (P12), reached ONLY through Svc.static_call (a direct class reference would not compile before this file landed):
##     static func stock(shop_id: String) -> Array            rows {item, stock, slot}      (ShopSystem adds the fixed stock in front and de-duplicates)
## PriceCurve.final_price(shop_id, item_id, base_price) is the other half; it asks slot_of() / slot_def() for the slot's price_mult.
##
## THE RULE (shop def `rotation` = a list of slots {id, period, pick, qty, rarity|mixed, price_mult, season_boost, pool}):
##   epoch      = floor((total_day - 1) / period)                          the slot is the same all period long
##   seed       = stable hash(shop_id, slot_id, epoch) mixed with the WORLD SEED (LootService.world_seed: the per-save constant, 0 without the service)
##   candidates = pool minus the shop's FIXED stock (an item the shelf always holds is never offered twice), minus every item that cannot be sold in a shop at all
##                (no def, buy_price 0, protected, UNIQUE or LEGENDARY: keepsakes appear in no pool, validator R3 + this guard)
##   weight     = 1, or `season_boost` (>= 1; 1 = no boost) when the item's `seasons` contains the season of the epoch's FIRST day
##   pick       = `pick` DISTINCT items by weighted shuffle (sequential draws without replacement), each offered with `qty` units
## Slots are drawn longest period first: a weekly slot (3 rare pieces) is the same all week; the daily slot then skips the items the weekly one took, so one item is never
## listed twice and a long slot never changes because a short one did.
## Closed days are ShopSystem's (is_open: the def's `open_weekdays`, 0 = Monday; the flea market 5 and 6 = Saturday and Sunday); open_on() is the same test as a pure function.

const FNV_OFFSET := 2166136261
const FNV_PRIME := 16777619
const CACHE_LIMIT := 64

static var _cache: Dictionary = {}


## FNV-1a 32 bit of the UTF-8 bytes (stable across engine versions, unlike hash())
static func _fnv(text: String, salt: int = 0) -> int:
	var h: int = (FNV_OFFSET ^ salt) & 0xffffffff
	for b in text.to_utf8_buffer():
		h = ((h ^ int(b)) * FNV_PRIME) & 0xffffffff
	return h


## epoch of a total day for a period in days (>= 1)
static func epoch_of(total_day: int, period: int) -> int:
	return floori(float(total_day - 1) / float(maxi(period, 1)))


## The 64-bit seed of (world seed, shop, slot, epoch): two FNV hashes with different salts side by side, so two slots never share a stream by accident.
static func seed_for(shop_id: String, slot_id: String, epoch: int, world_seed: int) -> int:
	var text := "%d|%s|%s|%d" % [world_seed, shop_id, slot_id, epoch]
	return (_fnv(text, 0) << 32) | _fnv(text, 0x9e3779b9)


static func rng_for(shop_id: String, slot_id: String, epoch: int, world_seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_for(shop_id, slot_id, epoch, world_seed)
	return r


static func shop_def(shop_id: String) -> Dictionary:
	var lr := Svc.node("LuaRuntime")
	return lr.get_shop(shop_id) if lr != null else {}


static func slots_of(shop: Dictionary) -> Array:
	var out: Array = []
	for s in LuaData.arr(shop.get("rotation", [])):
		if typeof(s) == TYPE_DICTIONARY:
			out.append(s)
	return out


## The slot's items that can be offered: the pool minus the fixed stock, minus everything a shop cannot sell (see the header). Sorted: a stable order before the seeded draw.
static func candidates(shop: Dictionary, slot: Dictionary) -> Array[String]:
	var fixed := LuaData.dict(shop.get("stock", {}))
	var out: Array[String] = []
	for raw in LuaData.arr(slot.get("pool", [])):
		var id := str(raw)
		if id == "" or fixed.has(id) or id in out:
			continue
		var def := ItemKinds.def(id)
		if def.is_empty() or LuaData.int_of(def.get("buy_price", 0)) <= 0 or bool(def.get("protected", false)) or ItemKinds.is_one_of_a_kind(id):
			continue
		out.append(id)
	out.sort()
	return out


## `count` DISTINCT items of `cands` by weighted shuffle: weight 1, `boost` for the items whose `seasons` contain `season`.
static func pick_distinct(r: RandomNumberGenerator, cands: Array[String], count: int, season: String, boost: float) -> Array[String]:
	var pool: Array[String] = cands.duplicate()
	var out: Array[String] = []
	while out.size() < count and not pool.is_empty():
		var weights := PackedFloat64Array()
		var total := 0.0
		for id in pool:
			var w := 1.0
			if boost > 1.0 and season in LuaData.strings(ItemKinds.def(id).get("seasons", [])):
				w = boost
			weights.append(w)
			total += w
		var x := r.randf() * total
		var acc := 0.0
		var at := pool.size() - 1
		for i in pool.size():
			acc += weights[i]
			if x < acc:
				at = i
				break
		out.append(pool[at])
		pool.remove_at(at)
	return out


## Every row of a shop for a day: [{item, stock, slot}] in slot order. Pure: (shop def, total day, season id of the epoch start, world seed) -> rows.
static func rows_for(shop_id: String, shop: Dictionary, total_day: int, season_of_day: Callable, world_seed: int) -> Array:
	var slots := slots_of(shop)
	if slots.is_empty():
		return []
	var order: Array = range(slots.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var pa := maxi(LuaData.int_of((slots[a] as Dictionary).get("period", 1), 1), 1)
		var pb := maxi(LuaData.int_of((slots[b] as Dictionary).get("period", 1), 1), 1)
		return pa > pb or (pa == pb and a < b))
	var picks := {}
	var taken := {}
	for i in order:
		var slot: Dictionary = slots[i]
		var period := maxi(LuaData.int_of(slot.get("period", 1), 1), 1)
		var epoch := epoch_of(total_day, period)
		var season := str(season_of_day.call(epoch * period + 1))
		var cands: Array[String] = []
		for id in candidates(shop, slot):
			if not taken.has(id):
				cands.append(id)
		var r := rng_for(shop_id, str(slot.get("id", "")), epoch, world_seed)
		var chosen := pick_distinct(r, cands, maxi(LuaData.int_of(slot.get("pick", 1), 1), 0), season, LuaData.num(slot.get("season_boost", 1.0), 1.0))
		for id in chosen:
			taken[id] = true
		picks[i] = chosen
	var rows: Array = []
	for i in slots.size():
		var slot2: Dictionary = slots[i]
		for id in picks[i]:
			rows.append({"item": id, "stock": maxi(LuaData.int_of(slot2.get("qty", 1), 1), 1), "slot": str(slot2.get("id", ""))})
	return rows


## What ShopSystem calls: today's rotation rows of `shop_id`; [] for a shop without a rotation (or an unknown one). Cached per (shop, day, world seed, rotation).
static func stock(shop_id: String) -> Array:
	var shop := shop_def(shop_id)
	if slots_of(shop).is_empty():
		return []
	var day := _total_day()
	var seed_value := _world_seed()
	var key := "%s|%d|%d|%d" % [shop_id, day, seed_value, hash(shop.get("rotation", []))]
	if _cache.has(key):
		return (_cache[key] as Array).duplicate(true)
	var rows := rows_for(shop_id, shop, day, _season_of_total_day, seed_value)
	if _cache.size() >= CACHE_LIMIT:
		_cache.clear()
	_cache[key] = rows
	return rows.duplicate(true)


static func clear_cache() -> void:
	_cache.clear()


## The slot id that offers `item_id` in `shop_id` today ("" = the fixed stock or not offered).
static func slot_of(shop_id: String, item_id: String) -> String:
	for row in stock(shop_id):
		if str((row as Dictionary).get("item", "")) == item_id:
			return str((row as Dictionary).get("slot", ""))
	return ""


## The slot row of the shop def with this id ({} when none): price_mult, period, qty ...
static func slot_def(shop_id: String, slot_id: String) -> Dictionary:
	if slot_id == "":
		return {}
	for s in slots_of(shop_def(shop_id)):
		if str((s as Dictionary).get("id", "")) == slot_id:
			return s
	return {}


## Is the shop open on this weekday (0 = Monday)? A shop without `open_weekdays` is open every day.
static func open_on(shop: Dictionary, weekday: int) -> bool:
	var days := LuaData.arr(shop.get("open_weekdays", []))
	if days.is_empty():
		return true
	for d in days:
		if LuaData.int_of(d, -1) == weekday:
			return true
	return false


static func _total_day() -> int:
	var gm := Svc.node("GameManager")
	return int(gm.call("total_day")) if gm != null and gm.has_method("total_day") else 1


## the season id (foraar sommer efteraar vinter) of a total day: the calendar of GameManager
static func _season_of_total_day(total_day: int) -> String:
	var gm := Svc.node("GameManager")
	if gm == null:
		return "foraar"
	var list: Array = gm.call("seasons")
	var per := maxi(int(gm.call("days_per_season")), 1)
	return str(list[floori(float(total_day - 1) / float(per)) % list.size()]) if not list.is_empty() else "foraar"


static func _world_seed() -> int:
	var loot := Svc.node("LootService")
	return int(loot.get("world_seed")) if loot != null and loot.get("world_seed") != null else 0
