class_name PriceCurve
extends RefCounted
## The ONE price of a good in the home shops (package F4; addendum 2.4 / 2.5, RV-P5 "one discount owner", DF23). Static and pure.
##
## CONTRACT with ShopSystem (P12), reached ONLY through Svc.static_call:
##     static func final_price(shop_id: String, item_id: String, base_price: int) -> int
## base_price is the stock row's `price` or the def's buy_price, UNmultiplied: THIS function applies buy_multiplier, the rotation slot's price_mult, the repeat surcharge, the
## sale, the friend discount and Perks.total("discount") capped by discount_total. ShopSystem.get_buy_price is the only place that asks, so the listed price is the charged price.
##
##   price = base x buy_multiplier x slot price_mult x (1 + min(step x copies owned, max)) x (1 - sale) x (1 - min(Perks.total("discount") + friend, discount_total))
##   rounded to whole guldagern (roundi).
##   * slot price_mult      the rotation slot that offers the item today (ShopRotation.slot_of); 1.0 for the fixed stock
##   * repeat surcharge     shop def price_curve.repeat_surcharge {step 0.08, max 0.32}: +8 % per copy the player owns anywhere (placed furniture counts), at most +32 %
##   * sale                 price_curve.sales [{from_day, to_day, discount, rarity[]}]: the day of the SEASON (GameManager.day) inside from..to and the item's rarity listed (none listed = all);
##                          the best sale wins (no stacking)
##   * friend               price_curve.friend_discount {per_heart 0.005, max_hearts 10}: the hearts of THE KEEPER of the shop (flag friend_<keeper>, keeper = the `keeper` field of the shop def;
##                          SocialManager mirrors every heart into that flag), at most max_hearts hearts: 0.05 at 10 hearts
##   * Perks.total("discount") ALREADY contains the gear (capped 0.15), the furniture sets / hygge and the race (hobbit 0.10) and EXCLUDES the friend term, so there is NO second hobbit
##     factor anywhere. The two are added here and clamped ONCE at perk_caps.discount_total (0.20).
## Numeric contract (tests/sections/shop_rotation.gd): a rare piece of 1600 costs a fox with gear 0.10 and 10 friend hearts 0.05 exactly 1360, the same hobbit 1280 (the cap), a hobbit
## with no gear and no friends 1440.
## A shop def without price_curve prices as base x buy_multiplier x slot price_mult x (1 - min(discount, cap)): the same as ShopSystem's own fallback.

const DEFAULT_CAP := 0.2


## The price of one unit, whole guldagern. An unknown shop answers the base price unchanged.
static func final_price(shop_id: String, item_id: String, base_price: int) -> int:
	return int(breakdown(shop_id, item_id, base_price)["price"])


## Every factor of final_price: {base, buy_multiplier, slot, slot_mult, copies, surcharge, sale, perk_discount, friend, hearts, discount, cap, price}.
static func breakdown(shop_id: String, item_id: String, base_price: int) -> Dictionary:
	var shop := ShopRotation.shop_def(shop_id)
	if shop.is_empty():
		return {"base": base_price, "buy_multiplier": 1.0, "slot": "", "slot_mult": 1.0, "copies": 0, "surcharge": 0.0, "sale": 0.0, "perk_discount": 0.0, "friend": 0.0, "hearts": 0,
			"discount": 0.0, "cap": DEFAULT_CAP, "price": base_price}
	var curve := LuaData.dict(shop.get("price_curve", {}))
	var slot_id := ShopRotation.slot_of(shop_id, item_id)
	var slot := ShopRotation.slot_def(shop_id, slot_id)
	var copies := _copies_owned(item_id) if not LuaData.dict(curve.get("repeat_surcharge", {})).is_empty() else 0
	var hearts := keeper_hearts(shop)
	return compute(base_price, LuaData.num(shop.get("buy_multiplier", 1.0), 1.0), LuaData.num(slot.get("price_mult", 1.0), 1.0), copies, curve, _season_day(), str(ItemKinds.rarity_of(item_id)),
		maxf(Perks.total("discount"), 0.0), hearts, float(Perks.caps().get("discount_total", DEFAULT_CAP)), slot_id)


## The formula on plain numbers (the numeric contract of the tests runs through it).
static func compute(base_price: int, buy_multiplier: float, slot_mult: float, copies: int, curve: Dictionary, day_of_season: int, rarity: String, perk_discount: float,
		hearts: int, cap: float, slot_id: String = "") -> Dictionary:
	var rs := LuaData.dict(curve.get("repeat_surcharge", {}))
	var surcharge := minf(LuaData.num(rs.get("step", 0.0)) * float(maxi(copies, 0)), LuaData.num(rs.get("max", 0.0))) if not rs.is_empty() else 0.0
	var sale := best_sale(curve, day_of_season, rarity)
	var fd := LuaData.dict(curve.get("friend_discount", {}))
	var counted := clampi(hearts, 0, maxi(LuaData.int_of(fd.get("max_hearts", 10), 10), 0)) if not fd.is_empty() else 0
	var friend := LuaData.num(fd.get("per_heart", 0.0)) * float(counted)
	var discount := minf(maxf(perk_discount, 0.0) + friend, cap)
	var price := roundi(float(base_price) * buy_multiplier * slot_mult * (1.0 + surcharge) * (1.0 - sale) * (1.0 - discount))
	return {"base": base_price, "buy_multiplier": buy_multiplier, "slot": slot_id, "slot_mult": slot_mult, "copies": copies, "surcharge": surcharge, "sale": sale,
		"perk_discount": perk_discount, "friend": friend, "hearts": counted, "discount": discount, "cap": cap, "price": price}


## The best sale that applies: price_curve.sales rows whose day window holds `day_of_season` and whose rarity list holds `rarity` (an empty list = every rarity). 0.0 = no sale.
static func best_sale(curve: Dictionary, day_of_season: int, rarity: String) -> float:
	var best := 0.0
	for s in LuaData.arr(curve.get("sales", [])):
		var sd := LuaData.dict(s)
		var from_day := LuaData.int_of(sd.get("from_day", 1), 1)
		var to_day := LuaData.int_of(sd.get("to_day", 28), 28)
		var rarities := LuaData.strings(sd.get("rarity", []))
		if day_of_season < from_day or day_of_season > to_day or (not rarities.is_empty() and not (rarity in rarities)):
			continue
		best = maxf(best, LuaData.num(sd.get("discount", 0.0)))
	return best


## The hearts the player has with the KEEPER of the shop: the flag friend_<keeper> (SocialManager mirrors every heart into it); 0 for a shop without a keeper.
static func keeper_hearts(shop: Dictionary) -> int:
	var keeper := str(shop.get("keeper", ""))
	var gm := Svc.node("GameManager")
	if keeper == "" or gm == null:
		return 0
	return int(gm.call("flag_int", StringName("friend_%s" % keeper), 0))


static func _copies_owned(item_id: String) -> int:
	var eco := Svc.node("EconomyManager")
	return int(eco.call("count_item", StringName(item_id))) if eco != null else 0


static func _season_day() -> int:
	var gm := Svc.node("GameManager")
	return int(gm.get("day")) if gm != null else 1
