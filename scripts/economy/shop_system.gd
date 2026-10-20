extends Node
## ShopSystem: every shop is DATA (lua/shops/*.lua, kind = "shops": seed_shop bakery smithy magic_store animal_store and the four
## home shops of F1). This node holds the live stock, answers prices and runs buy / sell. Nothing about a shop is hard-coded here.
##
## SHOP DEF (read through LuaRuntime.get_shop): name_key, keeper (npc id), greeting_key, buy_multiplier, sell_multiplier,
## stock { item = { price?, stock, restock } } and the optional extras tabs, buys, open_weekdays, rotation, price_curve (they pass
## through untouched). `stock` is the most a shelf holds, `restock` the units that come back every morning (left out: the shelf
## is full again); `price` overrides the item's buy_price. An item that is not defined, or that no one may buy (price 0, unique,
## legendary), is never listed.
##
## ONE PRICE. get_buy_price(shop, item) is the only place that prices an item; the listed price of get_shop_inventory(), the
## total of get_buy_total() and what buy_item() charges all come out of it, so listed == charged always. The discount has ONE owner
## (RV-P5): Perks.total("discount") (gear + furniture sets + the hobbit's race 10 percent, capped at discount_total 0.20). This
## file never applies a hobbit factor of its own. With the F4 content landed the price is PriceCurve.final_price(shop_id, item_id,
## base_price) -> int (it applies buy_multiplier, the rotation slot's price_mult, the repeat surcharge, sales, the friend discount
## and Perks.total("discount") itself); without it the price is base x buy_multiplier x (1 - min(Perks.total("discount"), cap)).
## LATE BINDING (RV-P10): ShopRotation / PriceCurve are reached through Svc.static_call (res:// path, method, arguments, fallback),
## never by class name (a direct reference is a parse error until F4 landed and an --import ran). THE CONTRACT with F4:
##   res://scripts/economy/shop_rotation.gd   static func stock(shop_id: String) -> Array of {item, stock, price?, slot?}
##   res://scripts/economy/price_curve.gd     static func final_price(shop_id: String, item_id: String, base_price: int) -> int
## (base_price = the stock row's `price` or the def's buy_price, UNmultiplied). A script that is missing, or lacks the static
## function, answers the fallback (fixed stock, fallback price) without a message; a script whose function takes another number
## of arguments is a contract violation and fails LOUDLY (an engine error in the gate of the package that broke it).
##
## STOCK. Fixed stock refreshes on EventBus.day_started (+restock, never above `stock`); rotation rows (ShopRotation) are cached
## per game day and a bought count belongs to ONE run of a slot (slot id + epoch = floor((day - 1) / the slot's period)): it is kept all
## period long and forgotten when the item leaves the offer or the slot draws again, so an item redrawn next epoch comes back full. OPENING HOURS (RT5): is_open asks the towns track's rule
## first, through the helper ShopHoursGate (res://scripts/towns/hours.gd, buildings registry; true / false, or null = no building claims
## the shop, the config switch towns.hours_enabled is false, or the towns track is absent), then the def's own open_weekdays (0 = Monday).
## A closed shop: get_shop_info()["closed"] (+ closed_reason / opens_at / next_open_weekday when the hours rule closed it), buying and
## selling are refused (last_refusal = &"closed"), the UI shows SHOP_UI_CLOSED_TODAY. A festival closes a shop inside the hours rule
## (SocialManager.shop_closed_by_festival is asked there): this file knows no festival. A garment the player owns cannot be bought
## again (row.already_owned, last_refusal = &"owned": the UI shows SHOP_UI_ALREADY_OWNED).
##
## SELLING. get_sell_price(shop, item) = max(1, sell_value x sell_multiplier); 0 = this shop does not buy it (price 0, quest and
## special items, keepsakes, categories outside the shop's `buys`, a sell_multiplier of 0). The sell list is EconomyManager.list_sellable().
## Every refused buy / sell sets last_refusal: &"closed" &"unknown_shop" &"invalid_amount" &"not_offered" &"owned" &"no_stock"
## &"no_gold" &"no_room" (buying) and &"unsellable" &"not_owned" &"wallet_full" (selling: the pay would not fit below EconomyManager.MAX_GOLD,
## the toast STORE_WALLET_FULL_* names the cap; nothing is taken).
##
## SAVE (SaveManager section "shops"): to_dict() {v, stock {shop: {item: units}}, rotation_bought {shop: {item: {n, day, slot}}}} (day = the
## total day of the last purchase, slot = the slot that offered it); a plain number (older saves) is a count of the offer of the day loaded.

signal shop_transaction(shop_id: StringName, item_id: StringName, amount: int, is_buy: bool)

const _Svc := preload("res://scripts/data/svc.gd")
const _HoursGate := preload("res://scripts/economy/shop_hours_gate.gd")     # the towns track's opening-hours rule, asked in ONE place (RT5)
const _Data := preload("res://scripts/data/lua_data.gd")
const _Kinds := preload("res://scripts/data/item_kinds.gd")
const _Perks := preload("res://scripts/data/perks.gd")
const _Economy := preload("res://scripts/autoload/economy_manager.gd")     # static total_of(): shop totals without int64 wrap-around
const _Fmt := preload("res://scripts/ui/theme/tt_format.gd")

const ROTATION_SCRIPT := "res://scripts/economy/shop_rotation.gd"
const CURVE_SCRIPT := "res://scripts/economy/price_curve.gd"
const SAVE_VERSION := 1
## dialogue files of the first waves still say general_store; the shop is seed_shop now
const LEGACY_SHOP_IDS := {"general_store": "seed_shop"}
## default tabs of a shop without `tabs`: item category -> tab id (anything else is "goods")
const TAB_OF_CATEGORY := {"seed": "seed", "farm": "seed", "tool": "tool", "weapon": "tool"}
## tab id -> translation key (ui.csv owns SHOP_TAB_*; the sell tab is the UI_SELL button text)
const TAB_NAME_KEYS := {"seed": "SHOP_TAB_SEEDS", "tool": "SHOP_TAB_TOOLS", "goods": "SHOP_TAB_GOODS", "sell": "UI_SELL"}
const TAB_ORDER: Array[String] = ["seed", "tool", "goods"]

## Why the last buy_item / sell_item / open_shop was refused (&"" after a success).
var last_refusal: StringName = &""
var _transaction_active := false

var _stock: Dictionary = {}           # shop id -> {item id (String) -> units left of the fixed stock}
var _bought_rot: Dictionary = {}      # shop id -> {item id -> {n: units bought, day: total day bought, slot: slot id}} of a rotation offer
var _rotation_cache: Dictionary = {}  # shop id -> {day: int, rows: Array}
var _rotation_source: Callable = Callable()   # test seam, see set_rotation_source()
var _curve_source: Callable = Callable()      # test seam, see set_price_curve_source()
var _rotation_script: String = ROTATION_SCRIPT   # test seam, see set_late_scripts()
var _curve_script: String = CURVE_SCRIPT
var _logged: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.new_game_started.connect(reset)
	EventBus.day_started.connect(_on_day_started)
	EventBus.lua_reloaded.connect(_on_lua_reloaded)


## The shop defs were re-read (F9): today's rotation rows are rebuilt from them and the messages may come again. The units
## left on the shelves are run state and stay.
func _on_lua_reloaded() -> void:
	_rotation_cache.clear()
	_logged.clear()


## A new run: every shelf is full again, rotation counts are forgotten.
func reset() -> void:
	_stock.clear()
	_bought_rot.clear()
	_rotation_cache.clear()
	last_refusal = &""


## TEST SEAMS (the production path is the late-bound static call). A valid Callable replaces ShopRotation.stock(shop_id) /
## PriceCurve.final_price(shop_id, item_id, base_price); an invalid one (Callable()) restores the production path.
func set_rotation_source(source: Callable) -> void:
	_rotation_source = source
	_rotation_cache.clear()


func set_price_curve_source(source: Callable) -> void:
	_curve_source = source


## TEST SEAM: where the late-bound static functions are looked up (a probe script under user://). No arguments = the contract's
## paths again. The call itself is the production one (Svc.static_call).
func set_late_scripts(rotation_path: String = ROTATION_SCRIPT, curve_path: String = CURVE_SCRIPT) -> void:
	_rotation_script = rotation_path
	_curve_script = curve_path
	_rotation_cache.clear()


# ================================================================================================ shops

func resolve_shop_id(shop_id: Variant) -> StringName:
	var key := str(shop_id)
	return StringName(str(LEGACY_SHOP_IDS.get(key, key)))


func get_shop_ids() -> Array:
	var lr := _Svc.node("LuaRuntime")
	return lr.get_shops().keys() if lr != null else []


func has_shop(shop_id: Variant) -> bool:
	return not _def(shop_id).is_empty()


## The shop def plus id, npc_id (= keeper, the name the first UI used), open and closed (today's opening hours).
func get_shop_info(shop_id: Variant) -> Dictionary:
	var d := _def(shop_id)
	if d.is_empty():
		return {}
	var info := d.duplicate()
	info["id"] = str(resolve_shop_id(shop_id))
	info["npc_id"] = str(d.get("keeper", ""))
	info["open"] = is_open(shop_id)
	info["closed"] = not info["open"]
	if info["closed"]:
		info.merge(_HoursGate.closed_info(str(info["id"])), true)       # closed_reason / opens_at / next_open_weekday, when the hours rule closed it
	return info


## The towns track's opening hours decide first (ShopHoursGate: true / false; null = no building claims the shop, the switch
## towns.hours_enabled is off, or scripts/towns is absent). Then: shops without open_weekdays are always open; else today's weekday
## (0 = Monday) has to be listed.
func is_open(shop_id: Variant) -> bool:
	var rule: Variant = _HoursGate.open_override(str(resolve_shop_id(shop_id)))
	if rule != null:
		return bool(rule)
	var days := _Data.arr(_def(shop_id).get("open_weekdays", []))
	if days.is_empty():
		return true
	var time_manager := _Svc.node("TimeManager")
	if time_manager == null or not time_manager.has_method("weekday_index"):
		return true
	var today := int(time_manager.call("weekday_index"))
	for d in days:
		if _Data.int_of(d, -1) == today:
			return true
	return false


## The tabs of a shop: its own `tabs` (id, name_key, furniture_types | slots | groups | categories) or the default ones built
## from the categories of the stock (seed + farm = "seed", tool + weapon = "tool", the rest "goods"), and the sell tab last.
## Every tab: {id, name_key, categories, slots, furniture_types, groups, sell}; item_in_tab() applies the criteria.
func get_shop_tabs(shop_id: Variant) -> Array[Dictionary]:
	var d := _def(shop_id)
	var out: Array[Dictionary] = []
	if d.is_empty():
		return out
	var own := _Data.arr(d.get("tabs", []))
	if not own.is_empty():
		for t in own:
			var td := _Data.dict(t)
			var id := str(td.get("id", ""))
			out.append({
				"id": id, "name_key": str(td.get("name_key", TAB_NAME_KEYS.get(id, ""))), "sell": false,
				"categories": _Data.strings(td.get("categories", [])), "slots": _Data.strings(td.get("slots", [])),
				"furniture_types": _Data.strings(td.get("furniture_types", [])), "groups": _Data.strings(td.get("groups", [])),
			})
	else:
		var cats := {}
		for item_id in _Data.dict(d.get("stock", {})):
			var category := str(_Kinds.def(item_id).get("category", ""))
			var tab := str(TAB_OF_CATEGORY.get(category, "goods"))
			if not cats.has(tab):
				cats[tab] = []
			if not (category in cats[tab]):
				cats[tab].append(category)
		for tab in TAB_ORDER:
			if cats.has(tab):
				out.append({"id": tab, "name_key": TAB_NAME_KEYS[tab], "sell": false, "categories": cats[tab], "slots": [], "furniture_types": [], "groups": []})
	out.append({"id": "sell", "name_key": TAB_NAME_KEYS["sell"], "sell": true, "categories": [], "slots": [], "furniture_types": [], "groups": []})
	return out


## Does an item belong to a tab? (category, slot or subslot, furniture_type, group; a tab with no criteria takes everything.)
func item_in_tab(tab: Dictionary, item_id: Variant) -> bool:
	var cats := _Data.strings(tab.get("categories", []))
	var slots := _Data.strings(tab.get("slots", []))
	var types := _Data.strings(tab.get("furniture_types", []))
	var groups := _Data.strings(tab.get("groups", []))
	if cats.is_empty() and slots.is_empty() and types.is_empty() and groups.is_empty():
		return true
	var d := _Kinds.def(item_id)
	return str(d.get("category", "")) in cats or str(d.get("slot", "")) in slots or str(d.get("subslot", "")) in slots \
		or str(d.get("furniture_type", "")) in types or str(d.get("group", "")) in groups


# ================================================================================================ stock and offers

## Everything the shop offers today (fixed stock, then the rotation): [{item_id, price, base_price, stock, max_stock, name_key,
## category, rarity, source ("fixed" | "rotation"), slot, owned, already_owned, buyable}], in declaration order (rarity
## ordering is the screen's job: Rarity.sorted_ids). price is get_buy_price: what is listed is what is charged.
func get_shop_inventory(shop_id: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := _def(shop_id)
	if d.is_empty():
		return out
	var open := is_open(shop_id)
	var key := str(resolve_shop_id(shop_id))
	for offer in _offers(shop_id):
		var item_id := StringName(str(offer["item"]))
		var price := _price_of(key, offer)
		if price <= 0:
			continue
		var def := _Kinds.def(item_id)
		var owned := _owned(item_id)
		var already := str(def.get("category", "")) == "clothing" and owned >= 1
		var left := _remaining(shop_id, offer)
		out.append({
			"item_id": item_id, "price": price, "base_price": int(offer["base"]), "stock": left, "max_stock": int(offer["max"]),
			"name_key": str(def.get("name_key", "ITEM_%s" % str(item_id).to_upper())), "category": str(def.get("category", "")),
			"rarity": _Kinds.rarity_of(item_id), "source": offer["source"], "slot": offer["slot"], "owned": owned,
			"already_owned": already, "buyable": open and left > 0 and not already,
		})
	return out


## What one unit costs right now (0 = this shop does not sell it). THE ONE PRICE FUNCTION (see the header).
func get_buy_price(shop_id: Variant, item_id: Variant) -> int:
	var offer := _find_offer(shop_id, item_id)
	return 0 if offer.is_empty() else _price_of(str(resolve_shop_id(shop_id)), offer)


## The price of one offer (get_buy_price and the inventory listing both end here).
func _price_of(shop_key: String, offer: Dictionary) -> int:
	if int(offer["base"]) <= 0 or _Kinds.is_one_of_a_kind(offer["item"]):
		return 0
	var curved: Variant = _curve_price(shop_key, str(offer["item"]), int(offer["base"]))
	if curved != null:
		return maxi(int(curved), 1)
	var mult := _Data.num(_def(shop_key).get("buy_multiplier", 1.0), 1.0)
	var cap := float(_Perks.caps().get("discount_total", 0.2))
	var discount := minf(_Perks.total("discount"), cap)
	return maxi(roundi(float(offer["base"]) * mult * (1.0 - discount)), 1)


## amount x get_buy_price: the total the screen shows and buy_item charges.
func get_buy_total(shop_id: Variant, item_id: Variant, amount: int = 1) -> int:
	return _Economy.total_of(get_buy_price(shop_id, item_id), amount)


## What the shop pays for ONE unit (0 = it does not buy this item): max(1, sell_value x sell_multiplier).
func get_sell_price(shop_id: Variant, item_id: Variant) -> int:
	var d := _def(shop_id)
	var eco := _Svc.node("EconomyManager")
	if d.is_empty() or eco == null:
		return 0
	var base := int(eco.call("sell_value", item_id))
	if base <= 0:
		return 0
	var buys := _Data.strings(d.get("buys", []))
	if not buys.is_empty() and not (str(_Kinds.def(item_id).get("category", "")) in buys):
		return 0
	var mult := _Data.num(d.get("sell_multiplier", 1.0), 1.0)
	return 0 if mult <= 0.0 else maxi(roundi(float(base) * mult), 1)


func can_sell(shop_id: Variant, item_id: Variant) -> bool:
	return get_sell_price(shop_id, item_id) > 0


## What the player can sell to this shop: [{item_id, amount, price, rarity, kind}] (EconomyManager.list_sellable filtered by the shop).
func get_sell_list(shop_id: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var eco := _Svc.node("EconomyManager")
	if eco == null or _def(shop_id).is_empty():
		return out
	for row in eco.call("list_sellable"):
		var price := get_sell_price(shop_id, row["id"])
		if price > 0:
			out.append({"item_id": row["id"], "amount": int(row["amount"]), "price": price, "rarity": row["rarity"], "kind": row["kind"]})
	return out


# ================================================================================================ buy and sell

## Buys `amount` units. All or nothing; false with last_refusal set when the shop is closed, does not sell the item, is out of
## stock, the player owns the garment, the gold or the room is missing. Charges exactly amount x get_buy_price.
func buy_item(shop_id: Variant, item_id: Variant, amount: int = 1) -> bool:
	if _transaction_active:
		return _refuse(&"busy")
	_transaction_active = true
	var result := _buy(shop_id, item_id, amount)
	_transaction_active = false
	return result


func _buy(shop_id: Variant, item_id: Variant, amount: int) -> bool:
	last_refusal = &""
	var key := resolve_shop_id(shop_id)
	var id := StringName(str(item_id))
	if amount <= 0:
		return _refuse(&"invalid_amount")
	if not has_shop(key):
		return _refuse(&"unknown_shop")
	if not is_open(key):
		return _refuse(&"closed")
	var offer := _find_offer(key, id)
	if offer.is_empty():
		return _refuse(&"not_offered")
	var unit := get_buy_price(key, id)
	if unit <= 0:
		return _refuse(&"not_offered")
	if str(_Kinds.def(id).get("category", "")) == "clothing" and _owned(id) >= 1:
		return _refuse(&"owned")
	if _remaining(key, offer) < amount:
		EventBus.notification_posted.emit(tr("NOTIF_NO_STOCK_TITLE"), tr("NOTIF_NO_STOCK_MSG"), "shop")
		return _refuse(&"no_stock")
	var eco := _Svc.node("EconomyManager")
	if eco == null:
		return _refuse(&"unknown_shop")
	var affordable := bool(eco.call("can_afford", _Economy.total_of(unit, amount)))
	var result := [false]
	eco.call("defer_notifications", func() -> void:
		if not bool(eco.call("buy_item", id, amount, unit)):
			_refuse(&"no_room" if affordable else &"no_gold")
			return
		_take_from_stock(key, offer, amount)
		result[0] = true
		eco.call("after_transaction", func(): shop_transaction.emit(key, id, amount, true)))
	if result[0]:
		last_refusal = &""
		return true
	return _refuse(&"no_room" if affordable else &"no_gold")


## Sells `amount` units for amount x get_sell_price. False (nothing changes) when the shop does not buy the item or the player
## has fewer free copies.
func sell_item(shop_id: Variant, item_id: Variant, amount: int = 1) -> bool:
	if _transaction_active:
		return _refuse(&"busy")
	_transaction_active = true
	var result := _sell(shop_id, item_id, amount)
	_transaction_active = false
	return result


func _sell(shop_id: Variant, item_id: Variant, amount: int) -> bool:
	last_refusal = &""
	var key := resolve_shop_id(shop_id)
	var id := StringName(str(item_id))
	if amount <= 0:
		return _refuse(&"invalid_amount")
	if not has_shop(key):
		return _refuse(&"unknown_shop")
	if not is_open(key):
		return _refuse(&"closed")
	var unit := get_sell_price(key, id)
	if unit <= 0:
		return _refuse(&"unsellable")
	var eco := _Svc.node("EconomyManager")
	if eco == null:
		return _refuse(&"unknown_shop")
	if not bool(eco.call("has_item", id, amount)):
		return _refuse(&"not_owned")
	if _Economy.total_of(unit, amount) > _Economy.MAX_GOLD - int(eco.get("gold")):
		EventBus.notification_posted.emit(tr("STORE_WALLET_FULL_TITLE"), tr("STORE_WALLET_FULL_FMT") % _Fmt.thousands(_Economy.MAX_GOLD), "gold")
		return _refuse(&"wallet_full")
	var result := [false]
	eco.call("defer_notifications", func() -> void:
		if not bool(eco.call("sell_item", id, amount, unit)):
			_refuse(&"not_owned")
			return
		result[0] = true
		eco.call("after_transaction", func(): shop_transaction.emit(key, id, amount, false)))
	if result[0]:
		last_refusal = &""
		return true
	return _refuse(&"not_owned")


## Opens the shop screen: EventBus.shop_opened (the screen shows the closed state itself). False for an unknown shop.
func open_shop(shop_id: Variant) -> bool:
	var key := resolve_shop_id(shop_id)
	if not has_shop(key):
		_log_once("open_shop(%s): no such shop in lua/shops" % key)
		return false
	EventBus.shop_opened.emit(key)
	return true


func close_shop(shop_id: Variant) -> void:
	EventBus.shop_closed.emit(resolve_shop_id(shop_id))


# ================================================================================================ day change and save

## Every morning: the fixed shelves get their restock, rotation counts of offers that ended (the item left, or its slot drew again) are forgotten.
func _on_day_started(_day: int, _season: StringName) -> void:
	for shop_id in _stock.keys():
		var d := _def(shop_id)
		if d.is_empty():
			continue
		var stock_defs := _Data.dict(d.get("stock", {}))
		for item_id in (_stock[shop_id] as Dictionary).keys():
			if not stock_defs.has(item_id):
				continue
			var entry := _Data.dict(stock_defs[item_id])
			var most := _Data.int_of(entry.get("stock", 0))
			var back := _Data.int_of(entry.get("restock", most))
			_stock[shop_id][item_id] = clampi(int(_stock[shop_id][item_id]) + maxi(back, 0), 0, most)
	_rotation_cache.clear()
	for shop_id in _bought_rot.keys():
		var offered := {}
		for offer in _offers(shop_id):
			if offer["source"] == "rotation":
				offered[offer["item"]] = offer
		for item_id in (_bought_rot[shop_id] as Dictionary).keys():
			if not offered.has(item_id) or not _same_run(shop_id, offered[item_id], _bought_rot[shop_id][item_id]):
				(_bought_rot[shop_id] as Dictionary).erase(item_id)


func to_dict() -> Dictionary:
	var stock := {}
	for shop_id in _stock:
		stock[str(shop_id)] = (_stock[shop_id] as Dictionary).duplicate()
	var rotation := {}
	for shop_id in _bought_rot:
		rotation[str(shop_id)] = (_bought_rot[shop_id] as Dictionary).duplicate(true)
	return {"v": SAVE_VERSION, "stock": stock, "rotation_bought": rotation}


## Restores the shelves after the JSON round trip: ints, unknown shops and items dropped, every count clamped to the shelf.
func from_dict(data: Dictionary) -> bool:
	_stock.clear()
	_bought_rot.clear()
	_rotation_cache.clear()
	var saved := _Data.dict(data.get("stock", {}))
	for shop_id in saved:
		var d := _def(shop_id)
		if d.is_empty():
			continue
		var defs := _Data.dict(d.get("stock", {}))
		var live := {}
		for item_id in _Data.dict(saved[shop_id]):
			if defs.has(item_id):
				live[str(item_id)] = clampi(_Data.int_of(saved[shop_id][item_id]), 0, _Data.int_of(_Data.dict(defs[item_id]).get("stock", 0)))
		_stock[str(shop_id)] = live
	var bought := _Data.dict(data.get("rotation_bought", {}))
	for shop_id in bought:
		if _def(shop_id).is_empty():
			continue
		var counts := {}
		for item_id in _Data.dict(bought[shop_id]):
			var raw: Variant = bought[shop_id][item_id]
			# an older save kept a plain number: the count of whatever offers the item on the day it is loaded
			var entry := _Data.dict(raw) if typeof(raw) == TYPE_DICTIONARY else {"n": raw, "day": _today(), "slot": ""}
			var n := _Data.int_of(entry.get("n", 0))
			if n > 0:
				counts[str(item_id)] = {"n": n, "day": _Data.int_of(entry.get("day", 0)), "slot": str(entry.get("slot", ""))}
		_bought_rot[str(shop_id)] = counts
	return true


# ================================================================================================ internals

func _refuse(reason: StringName) -> bool:
	last_refusal = reason
	return false


func _def(shop_id: Variant) -> Dictionary:
	var lr := _Svc.node("LuaRuntime")
	return lr.get_shop(str(resolve_shop_id(shop_id))) if lr != null else {}


func _owned(item_id: Variant) -> int:
	var eco := _Svc.node("EconomyManager")
	return int(eco.call("count_item", StringName(str(item_id)))) if eco != null else 0


## The live fixed-stock counts of a shop, created and kept in step with the def (a reload may add or drop items).
func _live(shop_id: Variant) -> Dictionary:
	var key := str(resolve_shop_id(shop_id))
	var defs := _Data.dict(_def(key).get("stock", {}))
	if not _stock.has(key):
		_stock[key] = {}
	var live: Dictionary = _stock[key]
	for item_id in defs:
		if not live.has(str(item_id)):
			live[str(item_id)] = maxi(_Data.int_of(_Data.dict(defs[item_id]).get("stock", 0)), 0)
	for item_id in live.keys():
		if not defs.has(item_id):
			live.erase(item_id)
	return live


## Everything offered: [{item, base, max, source, slot}] - fixed stock first, then the rotation rows (an item that is in the
## fixed stock is not offered twice).
func _offers(shop_id: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := _def(shop_id)
	if d.is_empty():
		return out
	var seen := {}
	var stock_defs := _Data.dict(d.get("stock", {}))
	for item_id in stock_defs:
		var item_def := _Kinds.def(item_id)
		if item_def.is_empty():
			_log_once("shop %s stocks %s, which has no Lua def: it is not listed" % [shop_id, item_id])
			continue
		var entry := _Data.dict(stock_defs[item_id])
		var base := _Data.int_of(entry["price"]) if entry.has("price") else _Data.int_of(item_def.get("buy_price", 0))
		out.append({"item": str(item_id), "base": base, "max": maxi(_Data.int_of(entry.get("stock", 0)), 0), "source": "fixed", "slot": ""})
		seen[str(item_id)] = true
	for row in _rotation_rows(shop_id):
		var item_id := str(row.get("item", row.get("item_id", "")))
		if item_id == "" or seen.has(item_id):
			continue
		var item_def := _Kinds.def(item_id)
		if item_def.is_empty():
			continue
		var base := _Data.int_of(row["price"]) if row.has("price") else _Data.int_of(item_def.get("buy_price", 0))
		out.append({"item": item_id, "base": base, "max": maxi(_Data.int_of(row.get("stock", 1), 1), 0), "source": "rotation", "slot": str(row.get("slot", row.get("section", "")))})
		seen[item_id] = true
	return out


func _find_offer(shop_id: Variant, item_id: Variant) -> Dictionary:
	var want := str(item_id)
	for offer in _offers(shop_id):
		if offer["item"] == want:
			return offer
	return {}


func _remaining(shop_id: Variant, offer: Dictionary) -> int:
	var key := str(resolve_shop_id(shop_id))
	if offer["source"] == "fixed":
		return int(_live(key).get(offer["item"], 0))
	return maxi(int(offer["max"]) - _bought_of(key, offer), 0)


func _take_from_stock(shop_id: Variant, offer: Dictionary, amount: int) -> void:
	var key := str(resolve_shop_id(shop_id))
	if offer["source"] == "fixed":
		var live := _live(key)
		live[offer["item"]] = maxi(int(live.get(offer["item"], 0)) - amount, 0)
	else:
		if not _bought_rot.has(key):
			_bought_rot[key] = {}
		_bought_rot[key][offer["item"]] = {"n": _bought_of(key, offer) + amount, "day": _today(), "slot": offer["slot"]}


## Units bought of this rotation offer; a count of an earlier run of the slot (or of another slot) is 0 (SYS-02).
func _bought_of(key: String, offer: Dictionary) -> int:
	var entry: Variant = _Data.dict(_bought_rot.get(key, {})).get(offer["item"], null)
	if typeof(entry) != TYPE_DICTIONARY or not _same_run(key, offer, entry):
		return 0
	return _Data.int_of((entry as Dictionary).get("n", 0))


## Was this bought count taken from the offer listed today: the same slot ("" = an older save: any slot) and the same epoch of its period?
func _same_run(shop_id: Variant, offer: Dictionary, entry: Dictionary) -> bool:
	var slot := str(entry.get("slot", ""))
	if slot != "" and slot != str(offer["slot"]):
		return false
	var period := _slot_period(shop_id, str(offer["slot"]))
	return floori(float(_Data.int_of(entry.get("day", 0)) - 1) / period) == floori(float(_today() - 1) / period)


## The period in days of a rotation slot of the def (1 for a slot the def does not name: a row of the test seam).
func _slot_period(shop_id: Variant, slot_id: String) -> int:
	for s in _Data.arr(_def(shop_id).get("rotation", [])):
		if typeof(s) == TYPE_DICTIONARY and str((s as Dictionary).get("id", "")) == slot_id:
			return maxi(_Data.int_of((s as Dictionary).get("period", 1), 1), 1)
	return 1


func _today() -> int:
	var gm := _Svc.node("GameManager")
	return int(gm.call("total_day")) if gm != null and gm.has_method("total_day") else 1


## The rotation rows of today: [{item, stock, price?, slot?}] from the test seam or ShopRotation.stock(shop_id); cached per game day.
func _rotation_rows(shop_id: Variant) -> Array:
	var key := str(resolve_shop_id(shop_id))
	var has_rotation := not _Data.arr(_def(key).get("rotation", [])).is_empty()
	if not has_rotation and not _rotation_source.is_valid():
		return []
	var day := _today()
	var cached: Variant = _rotation_cache.get(key, null)
	if cached != null and int((cached as Dictionary)["day"]) == day:
		return (cached as Dictionary)["rows"]
	var raw: Variant = _rotation_source.call(key) if _rotation_source.is_valid() else _Svc.static_call(_rotation_script, &"stock", [key])
	var rows: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for r in raw:
			if typeof(r) == TYPE_DICTIONARY:
				rows.append(r)
	_rotation_cache[key] = {"day": day, "rows": rows}
	return rows


## PriceCurve.final_price(shop_id, item_id, base_price) or null (not landed / the seam says nothing / not a non-negative number).
func _curve_price(shop_id: String, item_id: String, base: int) -> Variant:
	var raw: Variant = _curve_source.call(shop_id, item_id, base) if _curve_source.is_valid() else _Svc.static_call(_curve_script, &"final_price", [shop_id, item_id, base])
	return int(raw) if (typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT) and float(raw) >= 0.0 else null


## A data or contract error (an unknown shop, a stocked item without a def), once per message, as an engine warning.
func _log_once(message: String) -> void:
	if _logged.has(message):
		return
	_logged[message] = true
	push_warning("ShopSystem: " + message)
