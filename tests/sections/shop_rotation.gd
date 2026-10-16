extends RefCounted
## Section shop_rotation (package F4-loot-shops, wave M1b-1): ShopRotation (the rotating stock) and PriceCurve (the one price) of the four home shops, reached by ShopSystem ONLY through
## Svc.static_call, the way the contract of P12 says.
##
## Named checks: shop_rotation.deterministic, shop_rotation.pool_rules_no_unique, shop_rotation.price_curve, shop_rotation.discount_numeric_cap (the 1360 / 1280 / 1440 contract of RV-P5),
## shop_rotation.open_weekdays, plus the contract (static signatures, the real scripts reached by ShopSystem, listed price == charged price with the real rotation and curve), the cadence of the
## slots (a weekly slot is the same all week), the season boost, the repeat surcharge, the sale window and the friend term.
## The economy section's `economy.listed_equals_charged_with_rotation` and `economy.late_binding_real_scripts` run against these real scripts in the same harness run.
const SECTION := "shop_rotation"
const TIMEOUT_S := 120.0

## the numbers of the contract: a 1600-gold rare piece
const RARE_PIECE := 1600
## a piece that is in the FIXED stock of the furniture shop (no slot, no sale: the curve's clean case)
const FIXED_ITEM := "bed_pine"

class FakeGear extends Node:
	var discount: float = 0.0
	var luck: float = 0.0

	func gear_points(kind: String) -> float:
		return discount if kind == "discount" else (luck if kind == "luck" else 0.0)

var t
var gm: Node
var eco: Node
var shop: Node
var ls: Node
var tm: Node


func run(tt) -> void:
	t = tt
	gm = t.autoload("GameManager")
	eco = t.autoload("EconomyManager")
	shop = t.autoload("ShopSystem")
	ls = t.autoload("LootService")
	tm = t.autoload("TimeManager")
	_contract()
	_deterministic()
	_cadence()
	_pool_rules()
	_row_shapes()
	_season_boost()
	_price_pieces()
	_discount_contract()
	_weekdays()
	_through_shop_system()
	_cleanup()


func _fresh(seed_value: int = 424242) -> void:
	Svc.clear_overrides()
	gm.clear_config_overrides()
	gm.set_config_override("towns.hours_enabled", false)               # the opening hours of the towns track are not what this section is about
	shop.set_rotation_source(Callable())
	shop.set_price_curve_source(Callable())
	shop.set_late_scripts()
	# Base-curve fixtures use a neutral race. _discount_contract explicitly
	# exercises the Hobbit perk, gear, friendship and their combined cap.
	Fresh.new_game(t, "animal", "Tester", "Testgaarden", "", seed_value)
	ShopRotation.clear_cache()
	shop.reset()


func _rows(shop_id: String) -> Array:
	return ShopRotation.stock(shop_id)


func _items(rows: Array, slot: String = "") -> Array:
	var out: Array = []
	for r in rows:
		if slot == "" or str(r["slot"]) == slot:
			out.append(str(r["item"]))
	return out


func _z(k: float, n: float, p: float) -> float:
	return (k - n * p) / sqrt(n * p * (1.0 - p))


# ============================================================================================ the contract

func _contract() -> void:
	var rot: Script = load("res://scripts/economy/shop_rotation.gd")
	var curve: Script = load("res://scripts/economy/price_curve.gd")
	var stock_ok := false
	var price_ok := false
	for m in rot.get_script_method_list():
		if str(m["name"]) == "stock":
			stock_ok = (m["args"] as Array).size() == 1 and (int(m["flags"]) & METHOD_FLAG_STATIC) != 0
	for m in curve.get_script_method_list():
		if str(m["name"]) == "final_price":
			price_ok = (m["args"] as Array).size() == 3 and (int(m["flags"]) & METHOD_FLAG_STATIC) != 0
	t.check("contract_static_signatures", stock_ok and price_ok, "ShopRotation.stock(shop_id) -> Array and PriceCurve.final_price(shop_id, item_id, base_price) -> int are STATIC functions with exactly 1 and 3 arguments (P12's contract: a different arity is an engine error)")
	_fresh()
	var via_svc: Variant = Svc.static_call("res://scripts/economy/shop_rotation.gd", &"stock", ["furniture_shop"], null)
	var via_price: Variant = Svc.static_call("res://scripts/economy/price_curve.gd", &"final_price", ["furniture_shop", FIXED_ITEM, 150], null)
	t.expect(via_svc is Array and (via_svc as Array).size() > 0 and via_price is int and int(via_price) == 150, "Svc.static_call reaches both functions (stock rows %d, bed_pine 150 -> %s)" % [(via_svc as Array).size() if via_svc is Array else -1, str(via_price)])
	t.expect(shop.ROTATION_SCRIPT == "res://scripts/economy/shop_rotation.gd" and shop.CURVE_SCRIPT == "res://scripts/economy/price_curve.gd" and ResourceLoader.exists(shop.ROTATION_SCRIPT) and ResourceLoader.exists(shop.CURVE_SCRIPT), "ShopSystem's contract paths exist")
	t.expect(_rows("no_such_shop").is_empty() and _rows("seed_shop").is_empty() and PriceCurve.final_price("no_such_shop", "x", 77) == 77, "a shop without rotation (or an unknown one) has no rows; an unknown shop answers the base price")


# ============================================================================================ determinism

func _deterministic() -> void:
	_fresh(11)
	Fresh.jump_to_total_day(10)
	var a := _rows("furniture_shop")
	var b := _rows("furniture_shop")
	ShopRotation.clear_cache()
	var c := _rows("furniture_shop")
	t.check("deterministic", a == b and a == c and a.size() > 0 and JSON.stringify(a) == JSON.stringify(c), "same save seed + same day = the same %d rows, from the cache and recomputed from scratch" % a.size())
	Fresh.jump_to_total_day(11)
	var next_day := _rows("furniture_shop")
	t.expect(_items(a, "dagens_nye") != _items(next_day, "dagens_nye"), "the daily slot changes from day 10 to day 11")
	Fresh.jump_to_total_day(10)
	ls.set_seed(12)
	var other_seed := _rows("furniture_shop")
	t.expect(_items(a, "dagens_nye") != _items(other_seed, "dagens_nye"), "another save (world seed) sees another selection on the same day")
	ls.set_seed(11)
	t.expect(_rows("furniture_shop") == a, "...and the first save sees the original again (the seed is a per-save constant)")
	# pinned vectors: the stable hash (FNV-1a 32 bit x 2) never changes between engine versions; a changed seed would reshuffle every shop of every old save
	t.expect(ShopRotation.seed_for("furniture_shop", "dagens_nye", 3, 12345) == ShopRotation.seed_for("furniture_shop", "dagens_nye", 3, 12345) and ShopRotation.seed_for("furniture_shop", "dagens_nye", 3, 12345) != ShopRotation.seed_for("furniture_shop", "dagens_nye", 4, 12345) and ShopRotation.seed_for("furniture_shop", "dagens_nye", 3, 12345) != ShopRotation.seed_for("tailor_shop", "dagens_nye", 3, 12345) and ShopRotation.seed_for("furniture_shop", "dagens_nye", 3, 12345) != ShopRotation.seed_for("furniture_shop", "dagens_nye", 3, 12346),
		"the seed depends on shop, slot, epoch and world seed")
	t.expect(ShopRotation.seed_for("furniture_shop", "dagens_nye", 3, 12345) == PINNED_SEED, "pinned vector: seed_for(furniture_shop, dagens_nye, 3, 12345) = %d" % ShopRotation.seed_for("furniture_shop", "dagens_nye", 3, 12345))
	t.expect(ShopRotation.epoch_of(1, 7) == 0 and ShopRotation.epoch_of(7, 7) == 0 and ShopRotation.epoch_of(8, 7) == 1 and ShopRotation.epoch_of(1, 1) == 0 and ShopRotation.epoch_of(2, 1) == 1 and ShopRotation.epoch_of(3, 3) == 0 and ShopRotation.epoch_of(4, 3) == 1,
		"epoch = floor((total_day - 1) / period): day 1..7 are week 0, day 8 starts week 1; period 3 flips on day 4")


const PINNED_SEED := 54368717105101276


# ============================================================================================ the cadence of the slots

func _cadence() -> void:
	_fresh(21)
	var weekly := {}
	var tri := {}
	var daily := {}
	for day in range(1, 15):
		Fresh.jump_to_total_day(day)
		var rows := _rows("furniture_shop")
		weekly[day] = _items(rows, "ugens_sjaeldenhed")
		tri[day] = _items(rows, "tre_dages_udvalg")
		daily[day] = _items(rows, "dagens_nye")
	var week_ok := true
	for day in range(2, 8):
		week_ok = week_ok and weekly[day] == weekly[1]
	for day in range(9, 15):
		week_ok = week_ok and weekly[day] == weekly[8]
	t.expect(week_ok and weekly[1] != weekly[8] and (weekly[1] as Array).size() == 3, "the weekly rare slot is the SAME all seven days and changes with the week (days 1-7 / 8-14)")
	var tri_ok: bool = tri[1] == tri[2] and tri[2] == tri[3] and tri[4] == tri[5] and tri[5] == tri[6] and tri[1] != tri[4] and tri[7] != tri[4]
	t.expect(tri_ok, "the three-day slot holds for three days (1-3, 4-6) and then changes")
	var daily_changes := 0
	for day in range(2, 15):
		daily_changes += 1 if daily[day] != daily[day - 1] else 0
	t.expect(daily_changes == 13, "the daily slot changes every single day (%d of 13 changes)" % daily_changes)
	var shortest_first_ok := true
	for day in range(1, 15):
		var seen := {}
		for slot_items in [weekly[day], tri[day], daily[day]]:
			for id in slot_items:
				shortest_first_ok = shortest_first_ok and not seen.has(id)
				seen[id] = true
	t.expect(shortest_first_ok, "an item is never offered by two slots on the same day (the longer slots are drawn first, the shorter ones skip their items)")
	t.check("cadence_follows_the_period", week_ok and tri_ok and daily_changes == 13, "weekly 7 days, three-day 3 days, daily 1 day")
	# the season of an epoch is the season of ITS first day: a 3-day slot that straddles the end of a season keeps one weighting all period
	var asked: Array = []
	var shop_def: Dictionary = {"rotation": [{"id": "x", "period": 3, "pick": 1, "qty": 1, "pool": ["bed_pine", "chair_pine"]}], "stock": {}}
	var ask := func(day_asked: int) -> String:
		asked.append(day_asked)
		return "vinter"
	ShopRotation.rows_for("zz", shop_def, 29, ask, 0)
	t.expect(asked == [28], "a slot of period 3 asks the calendar for the first day of its epoch (total day 29 is in epoch 9: day 28) - got %s" % str(asked))


# ============================================================================================ pool rules

func _pool_rules() -> void:
	_fresh(31)
	var rotating := ["furniture_shop", "tailor_shop", "builder_yard", "flea_market"]
	var violations: Array[String] = []
	var pools_total := 0
	var dropped: Array[String] = []
	for sid in rotating:
		var def: Dictionary = ShopRotation.shop_def(sid)
		var fixed: Dictionary = def.get("stock", {})
		for slot in ShopRotation.slots_of(def):
			var cands := ShopRotation.candidates(def, slot)
			for id in slot["pool"]:
				pools_total += 1
				var d := ItemKinds.def(str(id))
				if d.is_empty() or ItemKinds.is_one_of_a_kind(str(id)) or Rarity.rank(ItemKinds.rarity_of(str(id))) >= 4 or bool(d.get("protected", false)):
					violations.append("%s/%s/%s" % [sid, slot["id"], id])
				if not (str(id) in cands) and not fixed.has(str(id)):
					dropped.append("%s/%s/%s" % [sid, slot["id"], id])
			for id in cands:
				if fixed.has(id):
					violations.append("fixed:%s/%s" % [sid, id])
	t.check("pool_rules_no_unique", violations.is_empty() and pools_total > 100, "%d pool entries of the four shops: no unique / legendary / protected item in any pool, no candidate that is in the fixed stock (%s)" % [pools_total, str(violations.slice(0, 5))])
	t.expect(dropped.is_empty(), "every pool entry can be sold in its shop (def exists, buy_price > 0): %s" % str(dropped.slice(0, 5)))
	# the days: rows never hold a keepsake or a fixed-stock item, over a whole season
	var bad_rows := 0
	for sid in rotating:
		var fixed2: Dictionary = ShopRotation.shop_def(sid).get("stock", {})
		for day in range(1, 29):
			Fresh.jump_to_total_day(day)
			var seen := {}
			for r in _rows(sid):
				var id := str(r["item"])
				bad_rows += 1 if (ItemKinds.is_one_of_a_kind(id) or fixed2.has(id) or seen.has(id)) else 0
				seen[id] = true
	t.expect(bad_rows == 0, "28 days x 4 shops: no row is a keepsake, a fixed-stock item or listed twice")
	# a poisoned pool: a legendary, a protected item, an item without price and the fixed stock are all skipped by the guard
	var legendary := "throne_root"
	var poisoned := {"stock": {"bed_pine": {"stock": 1}}, "rotation": [{"id": "p", "period": 1, "pick": 20, "qty": 1, "pool": [legendary, "bed_pine", "no_such_item_xyz", "chair_pine", "chair_birch"]}]}
	var season_fn := func(_d: int) -> String: return "foraar"
	var rows := ShopRotation.rows_for("poison", poisoned, 5, season_fn, 7)
	var got := _items(rows)
	got.sort()
	t.expect(got == ["chair_birch", "chair_pine"] and Rarity.rank(ItemKinds.rarity_of(legendary)) >= 4, "a legendary, a fixed-stock item and an unknown id in a pool are never offered (%s): the runtime guard of the validator's rule" % str(got))
	t.expect(ShopRotation.open_on({"open_weekdays": [5, 6]}, 5) and ShopRotation.open_on({"open_weekdays": [5, 6]}, 6) and not ShopRotation.open_on({"open_weekdays": [5, 6]}, 4) and ShopRotation.open_on({}, 2), "open_on: no list = open every day")


# ============================================================================================ rows

func _row_shapes() -> void:
	_fresh(41)
	Fresh.jump_to_total_day(5)
	var spec := {"furniture_shop": [["dagens_nye", 8, 3], ["tre_dages_udvalg", 7, 2], ["ugens_sjaeldenhed", 3, 1], ["ugens_tegning", 1, 1]],
		"tailor_shop": [["dagens_nye", 6, 3], ["tre_dages_udvalg", 6, 2], ["ugens_sjaeldenhed", 3, 1]],
		"builder_yard": [["dagens_tomme", 3, 30], ["ugens_fine_varer", 4, 12]],
		"flea_market": [["weekend_fund", 7, 1], ["weekend_skat", 1, 1]]}
	var shapes_ok := true
	var report: Array[String] = []
	for sid in spec:
		var rows := _rows(sid)
		for entry in spec[sid]:
			var of_slot: Array = []
			for r in rows:
				if str(r["slot"]) == entry[0]:
					of_slot.append(r)
			var qty_ok := true
			for r in of_slot:
				qty_ok = qty_ok and int(r["stock"]) == int(entry[2])
			shapes_ok = shapes_ok and of_slot.size() == int(entry[1]) and qty_ok
			report.append("%s/%s %d x%d" % [sid, entry[0], of_slot.size(), int(entry[2])])
	t.expect(shapes_ok, "every slot offers `pick` DISTINCT items with `qty` units each: %s" % ", ".join(report))
	var rare_ok := true
	for r in _rows("furniture_shop"):
		if str(r["slot"]) == "ugens_sjaeldenhed":
			rare_ok = rare_ok and str(ItemKinds.rarity_of(str(r["item"]))) == "rare"
		if str(r["slot"]) == "tre_dages_udvalg":
			rare_ok = rare_ok and str(ItemKinds.rarity_of(str(r["item"]))) == "uncommon"
		if str(r["slot"]) == "dagens_nye":
			rare_ok = rare_ok and str(ItemKinds.rarity_of(str(r["item"]))) == "normal"
	t.expect(rare_ok, "the rarity of a slot is the rarity of its pool: daily normal, three-day uncommon, weekly rare")
	t.expect(_rows("seed_shop") == [] and (_rows("furniture_shop")[0] as Dictionary).keys().size() == 3, "a row has exactly {item, stock, slot}")


# ============================================================================================ the season boost

func _season_boost() -> void:
	_fresh(51)
	var autumn: Array[String] = []
	var plain: Array[String] = []
	for id in ItemKinds.all_ids("furniture"):
		var d := ItemKinds.def(id)
		if Rarity.rank(ItemKinds.rarity_of(id)) >= 4:
			continue
		var seasons := LuaData.strings(d.get("seasons", []))
		if "efteraar" in seasons and autumn.size() < 6:
			autumn.append(id)
		elif seasons.is_empty() and plain.size() < 6:
			plain.append(id)
	var pool: Array[String] = []
	pool.append_array(autumn)
	pool.append_array(plain)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var hits3 := 0
	var hits1 := 0
	var n := 20000
	for _i in n:
		if ShopRotation.pick_distinct(r, pool, 1, "efteraar", 3.0)[0] in autumn:
			hits3 += 1
		if ShopRotation.pick_distinct(r, pool, 1, "efteraar", 1.0)[0] in autumn:
			hits1 += 1
	var z3 := _z(hits3, n, 0.75)
	var z1 := _z(hits1, n, 0.5)
	var spring_hits := 0
	for _i in n:
		if ShopRotation.pick_distinct(r, pool, 1, "foraar", 3.0)[0] in autumn:
			spring_hits += 1
	t.check("season_boost", autumn.size() == 6 and plain.size() == 6 and absf(z3) < 3.0 and absf(z1) < 3.0 and absf(_z(spring_hits, n, 0.5)) < 3.0,
		"6 autumn pieces vs 6 plain ones, 20 000 single draws: season_boost 3 in the autumn picks an autumn piece %.3f of the time (want 0.75, z %.2f), boost 1 = no boost %.3f (z %.2f), the same boost in the spring does nothing %.3f" % [hits3 / float(n), z3, hits1 / float(n), z1, spring_hits / float(n)])
	# a pick of more items than the pool holds returns the whole pool once each, distinct
	var all: Array[String] = ShopRotation.pick_distinct(r, pool, 50, "efteraar", 3.0)
	var sorted_all := all.duplicate()
	sorted_all.sort()
	var sorted_pool := pool.duplicate()
	sorted_pool.sort()
	t.expect(sorted_all == sorted_pool, "pick above the pool size returns every item once (distinct)")


# ============================================================================================ the pieces of the price

func _price_pieces() -> void:
	_fresh(61)
	var curve := {"repeat_surcharge": {"step": 0.08, "max": 0.32}, "friend_discount": {"per_heart": 0.005, "max_hearts": 10},
		"sales": [{"id": "s", "from_day": 22, "to_day": 28, "discount": 0.15, "rarity": ["uncommon"]}]}
	var base := 1000
	var prices: Array = []
	for copies in 7:
		prices.append(int(PriceCurve.compute(base, 1.0, 1.0, copies, curve, 5, "normal", 0.0, 0, 0.2)["price"]))
	t.expect(prices == [1000, 1080, 1160, 1240, 1320, 1320, 1320], "repeat surcharge: +8 %% per copy owned, at most +32 %%: %s" % str(prices))
	var days: Array = []
	for d in [21, 22, 25, 28]:
		days.append(int(PriceCurve.compute(base, 1.0, 1.0, 0, curve, d, "uncommon", 0.0, 0, 0.2)["price"]))
	var other_rarity := int(PriceCurve.compute(base, 1.0, 1.0, 0, curve, 25, "rare", 0.0, 0, 0.2)["price"])
	t.expect(days == [1000, 850, 850, 850] and other_rarity == 1000, "the season-end sale: -15 %% for uncommon pieces on days 22-28 of the season only (%s), a rare piece pays full (%d)" % [str(days), other_rarity])
	var hearts: Array = []
	for h in [0, 1, 5, 10, 14]:
		hearts.append(int(PriceCurve.compute(base, 1.0, 1.0, 0, curve, 5, "normal", 0.0, h, 0.2)["price"]))
	t.expect(hearts == [1000, 995, 975, 950, 950], "friend discount 0.5 %% per heart, at most 10 hearts: %s" % str(hearts))
	var mult := int(PriceCurve.compute(base, 1.5, 1.1, 0, curve, 5, "normal", 0.0, 0, 0.2)["price"])
	t.expect(mult == 1650, "buy_multiplier 1.5 x slot price_mult 1.1 = 1650 (%d)" % mult)
	var cap := int(PriceCurve.compute(base, 1.0, 1.0, 0, curve, 5, "normal", 0.18, 10, 0.2)["price"])
	t.expect(cap == 800, "discount (0.18 perks + 0.05 friends) is capped at discount_total 0.20: %d" % cap)
	var no_curve := int(PriceCurve.compute(base, 2.0, 1.0, 5, {}, 25, "uncommon", 0.1, 10, 0.2)["price"])
	t.expect(no_curve == 1800, "a shop def without price_curve: base x buy_multiplier x (1 - perks): no surcharge, no sale, no friend term (%d)" % no_curve)
	var best := PriceCurve.best_sale({"sales": [{"from_day": 1, "to_day": 28, "discount": 0.05}, {"from_day": 10, "to_day": 12, "discount": 0.25}]}, 11, "normal")
	t.expect(is_equal_approx(best, 0.25) and is_equal_approx(PriceCurve.best_sale({"sales": []}, 11, "normal"), 0.0), "overlapping sales: the best one wins, they do not stack")
	var rounded := int(PriceCurve.compute(333, 1.0, 1.0, 0, curve, 5, "normal", 0.0, 3, 0.2)["price"])
	t.expect(rounded == 328, "rounded to whole guldagern: 333 x 0.985 = 328.005 -> %d" % rounded)
	# the slot's price_mult reaches the real price: the flea market sells its weekend finds at x0.9, the weekly rare of the furniture shop at x1.1
	Fresh.jump_to_total_day(3)
	var flea_row: Dictionary = (_rows("flea_market")[0] as Dictionary)
	var flea_item := str(flea_row["item"])
	var flea_base: int = int(ItemKinds.def(flea_item).get("buy_price", 0))
	var flea_price := PriceCurve.final_price("flea_market", flea_item, flea_base)
	var rare_row: Dictionary = {}
	for r in _rows("furniture_shop"):
		if str(r["slot"]) == "ugens_sjaeldenhed":
			rare_row = r
	var rare_base: int = int(ItemKinds.def(str(rare_row["item"])).get("buy_price", 0))
	var rare_price := PriceCurve.final_price("furniture_shop", str(rare_row["item"]), rare_base)
	t.check("price_curve", prices == [1000, 1080, 1160, 1240, 1320, 1320, 1320] and days == [1000, 850, 850, 850] and hearts == [1000, 995, 975, 950, 950] and flea_price == roundi(flea_base * 0.9) and rare_price == roundi(rare_base * 1.1),
		"base x buy_multiplier x slot price_mult x (1 + surcharge) x (1 - sale) x (1 - min(perks + friend, cap)): surcharge, sale window, friend term, cap and rounding above; slot price_mult in the real shops: flea %s %d -> %d (x0.9), weekly rare %s %d -> %d (x1.1)" % [flea_item, flea_base, flea_price, str(rare_row["item"]), rare_base, rare_price])
	# the surcharge counts the copies the player owns anywhere, placed furniture included
	var store := FakeFurnitureManager.new(1)
	Svc.override("FurnitureManager", store)
	var item := "chair_pine"
	var base_chair: int = int(ItemKinds.def(item).get("buy_price", 0))
	var p0 := PriceCurve.final_price("furniture_shop", item, base_chair)
	store.add(item, 2)
	var p2 := PriceCurve.final_price("furniture_shop", item, base_chair)
	store.add(item, 4)
	var p6 := PriceCurve.final_price("furniture_shop", item, base_chair)
	t.expect(p0 == base_chair and p2 == roundi(base_chair * 1.16) and p6 == roundi(base_chair * 1.32), "the real furniture shop: chair_pine %d owned 0 -> %d, 2 -> %d (+16 %%), 6 -> %d (+32 %% cap)" % [base_chair, p0, p2, p6])
	var yard_base := int(ItemKinds.def("nails").get("buy_price", 0))
	eco.add_item(&"nails", 10, true)
	t.expect(PriceCurve.final_price("builder_yard", "nails", yard_base) == yard_base, "the builder's yard has no surcharge (step 0): materials stay at their price however many you own")
	Svc.clear_overrides()
	store.free()


# ============================================================================================ the discount contract (RV-P5)

func _discount_contract() -> void:
	_fresh(71)
	Fresh.jump_to_total_day(2)
	var gear := FakeGear.new()
	Svc.override("WardrobeManager", gear)
	var price := func() -> int: return PriceCurve.final_price("furniture_shop", FIXED_ITEM, RARE_PIECE)
	gm.set("character_type", 0)
	gear.discount = 0.10
	gm.set_flag(&"friend_fairy_furnisher", 10)
	var fox: int = price.call()
	gm.set("character_type", 2)
	var hobbit: int = price.call()
	gear.discount = 0.0
	gm.set_flag(&"friend_fairy_furnisher", null)
	var hobbit_alone: int = price.call()
	t.check("discount_numeric_cap", fox == 1360 and hobbit == 1280 and hobbit_alone == 1440,
		"a rare piece of 1600: a fox with gear 0.10 and 10 friend hearts (0.05) pays %d (1360), the same hobbit %d (1280, the 0.20 cap), a hobbit with no gear and no friends %d (1440)" % [fox, hobbit, hobbit_alone])
	gear.discount = 0.15
	gm.set_flag(&"friend_fairy_furnisher", 10)
	t.expect(int(price.call()) == 1280, "hobbit + gear 0.15 + 10 hearts stays at the 0.20 cap: 1280")
	gm.set_flag(&"friend_fairy_furnisher", null)
	gm.set("character_type", 0)
	gear.discount = 0.0
	t.expect(int(price.call()) == 1600, "a fox without gear and without friends pays the full 1600")
	var breakdown := PriceCurve.breakdown("furniture_shop", FIXED_ITEM, RARE_PIECE)
	t.expect(float(breakdown["perk_discount"]) == 0.0 and float(breakdown["friend"]) == 0.0 and int(breakdown["price"]) == 1600 and str(breakdown["slot"]) == "", "breakdown() names every factor (no slot for the fixed stock)")
	# the hobbit's 10 % is counted ONCE: no code line of the curve names a hobbit or a race
	var offenders: Array[String] = []
	for path in ["res://scripts/economy/price_curve.gd", "res://scripts/economy/shop_rotation.gd"]:
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := line.split("##")[0]
			if code.strip_edges().begins_with("#"):
				continue
			if code.to_lower().contains("hobbit") or code.contains("shop_discount"):
				offenders.append("%s:%d" % [path.get_file(), n])
	t.expect(offenders.is_empty(), "no hobbit factor in price_curve.gd / shop_rotation.gd: Perks.total(discount) is the one owner of the race 10 %% (%s)" % str(offenders))
	gm.set("character_type", 0)
	Svc.clear_overrides()
	gear.free()


# ============================================================================================ opening days

func _weekdays() -> void:
	_fresh(81)
	var flea_open: Array = []
	var others_open := true
	for day in range(1, 8):
		Fresh.jump_to_total_day(day)
		var wd: int = tm.weekday_index()
		flea_open.append([wd, bool(shop.is_open("flea_market"))])
		for sid in ["furniture_shop", "tailor_shop", "builder_yard", "seed_shop"]:
			others_open = others_open and bool(shop.is_open(sid))
	var only_weekend := true
	for pair in flea_open:
		only_weekend = only_weekend and (bool(pair[1]) == (int(pair[0]) in [5, 6]))
	t.check("open_weekdays", only_weekend and others_open and flea_open.size() == 7, "the flea market is open on weekday 5 and 6 (Saturday, Sunday) and closed on the other five; the furniture shop, the tailor, the yard and the seed shop are open every day: %s" % str(flea_open))
	var def: Dictionary = ShopRotation.shop_def("flea_market")
	t.expect(def.get("open_weekdays", []) == [5, 6] and ShopRotation.open_on(def, 5) and ShopRotation.open_on(def, 6) and not ShopRotation.open_on(def, 0), "the flea market's def lists exactly weekdays 5 and 6 (0 = Monday)")
	Fresh.jump_to_total_day(3)
	var gold_before: int = eco.gold
	var rows_closed: Array = shop.get_shop_inventory("flea_market")
	var buyable_closed := false
	for row in rows_closed:
		buyable_closed = buyable_closed or bool(row["buyable"])
	var item := str(rows_closed[0]["item_id"]) if not rows_closed.is_empty() else ""
	var refused: bool = not shop.buy_item("flea_market", item, 1)
	t.expect(rows_closed.size() > 0 and not buyable_closed and refused and shop.last_refusal == &"closed" and eco.gold == gold_before, "on a Wednesday the flea market lists its finds but nothing is buyable and buying is refused as closed (%d rows)" % rows_closed.size())
	Fresh.jump_to_total_day(6)
	shop.reset()
	var rows_open: Array = shop.get_shop_inventory("flea_market")
	var buyable_open := false
	for row in rows_open:
		buyable_open = buyable_open or bool(row["buyable"])
	t.expect(buyable_open and bool(shop.get_shop_info("flea_market")["open"]), "on Saturday the same shop sells")


# ============================================================================================ through ShopSystem

func _through_shop_system() -> void:
	_fresh(91)
	Fresh.jump_to_total_day(9)
	eco.gold = 999999
	var inv: Array[Dictionary] = shop.get_shop_inventory("furniture_shop")
	var from_rotation := 0
	var fixed := 0
	var slots := {}
	for row in inv:
		if str(row["source"]) == "rotation":
			from_rotation += 1
			slots[str(row["slot"])] = true
		else:
			fixed += 1
	t.expect(fixed == 22 and from_rotation == 19 and slots.size() == 4, "ShopSystem lists the 22 fixed pieces and the 19 rotation rows of today (4 slots) through the real ShopRotation (%d + %d)" % [fixed, from_rotation])
	t.check("shop_system_uses_the_real_scripts", shop._rotation_script == shop.ROTATION_SCRIPT and shop._curve_script == shop.CURVE_SCRIPT and from_rotation > 0, "no test seam is active: the rows come from scripts/economy/shop_rotation.gd and the prices from price_curve.gd")
	# listed == charged, for every row of the day, for a fox and for a hobbit, with a sale, a surcharge, friends and gear
	var gear := FakeGear.new()
	Svc.override("WardrobeManager", gear)
	var store := FakeFurnitureManager.new(1)
	Svc.override("FurnitureManager", store)
	var all_ok := true
	var checked := 0
	var distinct_prices := {}
	for race in [0, 2]:
		gm.set("character_type", race)
		for scenario in [[0, 0.0], [7, 0.10]]:
			gm.set_flag(&"friend_fairy_furnisher", scenario[0] if scenario[0] > 0 else null)
			gear.discount = scenario[1]
			shop.reset()
			store.stock.clear()
			store.add("chair_pine", 3)
			for row in shop.get_shop_inventory("furniture_shop"):
				var id: StringName = row["item_id"]
				if not bool(row["buyable"]) or int(row["stock"]) <= 0:
					continue
				var listed: int = row["price"]
				var again: int = shop.get_buy_price("furniture_shop", id)
				var before: int = eco.gold
				var ok: bool = shop.buy_item("furniture_shop", id, 1)
				var charged: int = before - eco.gold
				all_ok = all_ok and ok and listed == again and charged == listed and listed > 0
				distinct_prices[listed] = true
				checked += 1
				if checked > 60:
					break
	t.check("listed_equals_charged", all_ok and checked > 40 and distinct_prices.size() > 8, "%d purchases over a fox and a hobbit, with 0 / 7 friend hearts and gear 0 / 0.10 and 3 owned chairs: listed == get_buy_price == gold charged for every row (%d distinct prices)" % [checked, distinct_prices.size()])
	# the rotation's stock counts down when bought
	shop.reset()
	gm.set_flag(&"friend_fairy_furnisher", null)
	gear.discount = 0.0
	gm.set("character_type", 0)
	var first_rot: Dictionary = {}
	for row in shop.get_shop_inventory("furniture_shop"):
		if str(row["source"]) == "rotation" and int(row["stock"]) >= 2:
			first_rot = row
			break
	var ok1: bool = shop.buy_item("furniture_shop", first_rot["item_id"], 1)
	var left_after := 0
	for row in shop.get_shop_inventory("furniture_shop"):
		if row["item_id"] == first_rot["item_id"]:
			left_after = int(row["stock"])
	t.expect(ok1 and left_after == int(first_rot["stock"]) - 1, "a rotation row sells `qty` units: %d -> %d after one purchase" % [int(first_rot["stock"]), left_after])
	Svc.clear_overrides()
	gear.free()
	store.free()
	gm.set("character_type", 0)


func _cleanup() -> void:
	Svc.clear_overrides()
	gm.clear_config_overrides()
	gm.set_flag(&"friend_fairy_furnisher", null)
	gm.set("character_type", 0)
	shop.set_rotation_source(Callable())
	shop.set_price_curve_source(Callable())
	shop.set_late_scripts()
	shop.reset()
	ShopRotation.clear_cache()
	Fresh.new_game(t)
