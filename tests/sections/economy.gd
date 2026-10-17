extends RefCounted
## Section economy (package P12, plan 7.3 P12 + addendum 4.4): EconomyManager (gold, the 24-slot backpack, stacks, routing by
## category, keepsakes, tools, use_item, save), ShopSystem (shops from Lua, ONE price, closed days, rotation, stock, discount),
## CraftingSystem (recipes from Lua, stations, blueprints, bake bonus) and the item / shop / recipe data and their keys.
##
## Named checks (plan 8.2 / addendum 4.4): economy.no_key_collisions, economy.shops_from_lua, economy.routing_by_category,
## economy.one_of_a_kind_refused, economy.rare_item_found, economy.listed_equals_charged_with_rotation,
## economy.discount_single_owner_numeric, economy.shop_closed_weekdays, economy.stations_and_blueprints,
## economy.content_external_items_exist (+ the checks of task 6: gold clamp, 24 slots, new game, save round trip, item keys, recipes,
## craft, bake bonus, item_gained once per add) and the plan's own ids economy.listed_equals_charged (8.2 row 9: every buyable row of
## every shop bought for real, fox and hobbit) and economy.sell_min_one (8.5: no sellable item pays 0).
## FIX ROUND 2 (reviewer defects): economy.gold_saturates / total_of_saturates / buy_total_never_wraps / gold_load_clamped (no int64
## wrap-around), economy.equip_choice_survives_save / equip_empty_slot_survives_save (the player's tool choice is saved),
## economy.remove_matches_count (remove_item reaches everything count_item counts), economy.late_binding_via_svc /
## late_binding_real_scripts (ShopRotation / PriceCurve only through Svc.static_call), economy.restock_on_day_started_only.
##
## The section is a sandbox: it starts new games, injects fake stores / players / curves through Svc.override and the ShopSystem
## test seams, loads fixture Lua files from user:// and puts everything back (LuaRuntime.reload_scripts, Svc.clear_overrides,
## a fresh new game) before it ends.
const SECTION := "economy"
const TIMEOUT_S := 150.0

## files of this package (LuaRuntime script ids): their items must be complete; other packages' items are only reported
const MY_ITEM_SCRIPTS: Array[String] = ["items/tools", "items/crops", "items/magic", "items/resources", "items/consumables", "items/products", "items/crafted"]
const KNOWN_CATEGORIES: Array[String] = ["tool", "weapon", "seed", "crop", "farm", "resource", "forage", "mineral", "gem", "magic",
	"consumable", "food", "product", "material", "placeable", "quest", "special", "animal", "animal_care", "building",
	"building_material", "blueprint", "furniture", "clothing"]
## what a new game starts with
const STARTER := {"hoe_wooden": 1, "watering_can_copper": 1, "axe_wooden": 1, "pickaxe_wooden": 1, "sword_rusty": 1, "scythe": 1, "turnip_seeds": 5, "lantern_oil": 2, "health_tonic": 1}
## the guide's shop lines (Kloevermyntes Froe): item -> price in guldagern
const GUIDE_SHOP := {"carrot_seeds": 20, "pumpkin_seeds": 60, "strawberry_seeds": 45, "sunflower_seeds": 30, "catnip_seeds": 35, "moonflower_seeds": 120, "fertilizer": 15, "fairy_dust_water": 900}
const FIXTURE_ITEMS := "user://p12_fixture_items.lua"
const FIXTURE_SHOPS := "user://p12_fixture_shops.lua"
const FIXTURE_RECIPES := "user://p12_fixture_recipes.lua"


## stands in for the furniture / wardrobe store (the real ones land in waves 4-5): add / remove / count_total / count_stock / owned_ids
class FakeStore extends Node:
	var owned: Dictionary = {}
	var placed: Dictionary = {}
	var max_copies: int = 9
	func add(id: StringName, n: int) -> bool:
		if n <= 0 or int(owned.get(id, 0)) + n > max_copies:
			return false
		owned[id] = int(owned.get(id, 0)) + n
		return true
	func remove(id: StringName, n: int) -> bool:
		if n <= 0 or int(owned.get(id, 0)) - int(placed.get(id, 0)) < n:
			return false
		owned[id] = int(owned[id]) - n
		return true
	func count_total(id: StringName) -> int:
		return int(owned.get(id, 0))
	func count_stock(id: StringName) -> int:
		return int(owned.get(id, 0)) - int(placed.get(id, 0))
	func owned_ids() -> Array:
		return owned.keys()

## a store that is not there yet: a node without add / remove / count_total
class BareNode extends Node:
	pass

## the player as the economy sees it (group `player`): hearts, oil, energy
class FakePlayer extends Node:
	var half_hearts: int = 4
	var max_half_hearts: int = 10
	var oil: float = 50.0
	var max_oil: float = 150.0
	var stamina: float = 20.0
	var max_stamina: float = 100.0
	func heal_half(n: int) -> void:
		half_hearts = mini(half_hearts + n, max_half_hearts)

## a perk source (Perks reads WardrobeManager.gear_points): worn gear that gives a discount
class FakeGear extends Node:
	var discount: float = 0.0
	func gear_points(kind: String) -> float:
		return discount if kind == "discount" else 0.0

class FakeHusbandry extends Node:
	var adopted: Array = []
	func adopt_animal(id: StringName) -> bool:
		adopted.append(id)
		return true

var t
var eco: Node
var shop: Node
var gm: Node
var lr: Node
var bus: Node
var loc: Node
var _restore_character: int = 0
var _fixtures_loaded: bool = false
var _fakes: Array[Node] = []


func run(p_t) -> void:
	t = p_t
	eco = t.autoload("EconomyManager")
	shop = t.autoload("ShopSystem")
	gm = t.autoload("GameManager")
	lr = t.autoload("LuaRuntime")
	bus = t.autoload("EventBus")
	loc = t.autoload("LocalizationManager")
	if eco == null or shop == null or gm == null or lr == null or bus == null or loc == null:
		return
	_restore_character = int(gm.get("character_type"))
	# DT55: most of this section is about shop defs and prices, not about opening hours. The towns' hours rule (ShopHoursGate ->
	# Hours) would close every shop whose building is outside its hours at the test's clock, so the def's own fields decide alone.
	# The hours rule itself is proved in clock26 and the towns sections.
	gm.set_config_override("towns.hours_enabled", false)
	await t.go_menu()
	_gold()
	_item_defs()
	_backpack()
	_new_game_and_starter_kit()
	_signals()
	_tools()
	_save()
	_equipment_choice_saved()
	_routing()
	_remove_matches_count()
	_one_of_a_kind_and_rare()
	_use_item()
	_write_fixtures()
	_shops_from_lua()
	_prices_and_selling()
	_stock_and_days()
	_rotation_and_curve()
	_closed_weekdays()
	_garments_and_keepsakes_in_shops()
	_refund_and_lua_api()
	_discount_single_owner()
	_crafting()
	_stations_and_blueprints()
	_bake_bonus()
	_keys_and_copy()
	_content_external_items()
	_cleanup()


# ================================================================================================ helpers

func _fresh() -> void:
	_release_fakes()
	shop.set_rotation_source(Callable())
	shop.set_price_curve_source(Callable())
	gm.set("character_type", 0)
	t.new_game()
	gm.set("character_type", 0)


## A fake autoload / node that the section frees again (Svc overrides are cleared with it).
func _fake(node: Node) -> Node:
	_fakes.append(node)
	return node


func _release_fakes() -> void:
	Svc.clear_overrides()
	for n in _fakes:
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_fakes.clear()


## Forces the documented fallback path of ShopSystem (no ShopRotation rows, no PriceCurve), whatever F4 has landed by now.
func _force_fallback() -> void:
	shop.set_rotation_source(func(_shop_id: String) -> Array: return [])
	shop.set_price_curve_source(func(_shop_id: String, _item_id: String, _base: int) -> Variant: return null)


func _arity_of(sig_name: String) -> int:
	for s in bus.get_signal_list():
		if s["name"] == sig_name:
			return (s["args"] as Array).size()
	return 0


func _watch(signal_names: Array) -> Dictionary:
	var box := {"log": [], "cbs": {}}
	for n in signal_names:
		var sig_name := str(n)
		var arity := _arity_of(sig_name)
		var cb := func(a1 = null, a2 = null, a3 = null, a4 = null) -> void:
			(box["log"] as Array).append([sig_name, [a1, a2, a3, a4].slice(0, arity)])
		Signal(bus, sig_name).connect(cb)
		box["cbs"][sig_name] = cb
	return box


func _unwatch(box: Dictionary) -> void:
	for sig_name in box["cbs"]:
		var s := Signal(bus, str(sig_name))
		if s.is_connected(box["cbs"][sig_name]):
			s.disconnect(box["cbs"][sig_name])
	(box["cbs"] as Dictionary).clear()


func _count(box: Dictionary, sig_name: String) -> int:
	var n := 0
	for e in box["log"]:
		if e[0] == sig_name:
			n += 1
	return n


func _args(box: Dictionary, sig_name: String) -> Array:
	var out: Array = []
	for e in box["log"]:
		if e[0] == sig_name:
			out.append(e[1])
	return out


func _starter_backpack() -> Dictionary:
	var pack := STARTER.duplicate()
	pack.erase("sword_rusty")
	return pack

func _inv() -> Dictionary:
	var out := {}
	var raw: Dictionary = eco.get_inventory_dict()
	for k in raw:
		out[str(k)] = int(raw[k])
	return out


func _item_ids() -> Array:
	return lr.get_all_item_ids()


func _script_of(item_id: String) -> String:
	return str(lr._owner_of.get("items:" + item_id, ""))


func _my_ids() -> Array:
	var out: Array = []
	for id in _item_ids():
		if _script_of(str(id)) in MY_ITEM_SCRIPTS:
			out.append(str(id))
	return out


# ================================================================================================ gold

func _gold() -> void:
	_fresh()
	var w := _watch(["gold_changed"])
	var start: int = int(lr.get_config("economy.starting_gold", -1))
	t.check("starting_gold_from_config", start == 500 and eco.gold == start, "new game: %d guldagern (economy.starting_gold %d)" % [eco.gold, start])
	eco.add_gold(eco.MAX_GOLD + 500)
	t.expect_eq(eco.gold, eco.MAX_GOLD, "gold is clamped to MAX_GOLD")
	eco.add_gold(-3 * eco.MAX_GOLD)
	t.expect_eq(eco.gold, 0, "gold never goes below 0 (add_gold with a negative amount)")
	var n_events := (w["log"] as Array).size()
	eco.add_gold(0)
	t.expect_eq((w["log"] as Array).size(), n_events, "add_gold(0) changes nothing and fires nothing")
	eco.add_gold(100)
	t.expect(not eco.spend_gold(101) and eco.gold == 100, "spend_gold refuses more than the player has and changes nothing")
	t.expect(not eco.spend_gold(-5) and eco.gold == 100, "spend_gold refuses a negative amount")
	t.expect(eco.spend_gold(0) and eco.gold == 100, "spend_gold(0) is a free no-op")
	t.expect(eco.spend_gold(40) and eco.gold == 60, "spend_gold pays")
	var deltas: Array = []
	for a in _args(w, "gold_changed"):
		deltas.append(a[1])
	t.check("gold_clamp", deltas == [eco.MAX_GOLD - 500, -eco.MAX_GOLD, 100, -40] and eco.can_afford(60) and not eco.can_afford(61), "gold_changed deltas %s" % str(deltas))
	_unwatch(w)
	_gold_saturation()


## Gold arithmetic never wraps around int64: a huge reward ends at MAX_GOLD (it used to wrap negative and pin the wallet to 0),
## a huge price can never wrap into an affordable total, a huge saved amount is clamped before it becomes an int.
func _gold_saturation() -> void:
	var int_max := 9223372036854775807
	var int_min := -9223372036854775807 - 1
	var w := _watch(["gold_changed"])
	eco.add_gold(int_min)                      # 60 gold and a huge deduction: the wallet ends at 0, not below it
	var after_floor: int = eco.gold
	eco.add_gold(60)
	eco.add_gold(int_max)
	var after_max: int = eco.gold
	eco.add_gold(int_min)
	var after_min: int = eco.gold
	eco.add_gold(250)
	eco.add_gold(int_max - 100)
	var after_second: int = eco.gold
	eco.add_gold(-int_max)
	var after_neg: int = eco.gold
	var deltas: Array = []
	for a in _args(w, "gold_changed"):
		deltas.append(a[1])
	_unwatch(w)
	t.check("gold_saturates", after_floor == 0 and after_max == eco.MAX_GOLD and after_min == 0 and after_second == eco.MAX_GOLD and after_neg == 0 and deltas == [-60, 60, eco.MAX_GOLD - 60, -eco.MAX_GOLD, 250, eco.MAX_GOLD - 250, -eco.MAX_GOLD], "add_gold(INT64_MAX) ends at MAX_GOLD instead of wrapping to 0, add_gold(INT64_MIN) ends at 0 (%d, %d, %d, %d, %d); deltas %s" % [after_floor, after_max, after_min, after_second, after_neg, str(deltas)])
	var huge_amount := (1 << 62) + 1
	t.check("total_of_saturates", eco.total_of(7, 3) == 21 and eco.total_of(0, 5) == 0 and eco.total_of(5, 0) == 0 and eco.total_of(5, -2) == 0 and eco.total_of(eco.MAX_GOLD, 1) == eco.MAX_GOLD and eco.total_of(4, huge_amount) == eco.MAX_GOLD + 1 and eco.total_of(int_max, 2) == eco.MAX_GOLD + 1 and eco.total_of(1, eco.MAX_GOLD + 1) == eco.MAX_GOLD + 1, "total_of is unit x amount, 0 for nothing, and MAX_GOLD + 1 (never affordable) instead of an int64 wrap-around (4 x 2^62+1 would be 4)")
	# the wrap-around used to make this absurd purchase cost 4 gold
	var furniture := _fake(FakeStore.new()) as FakeStore
	furniture.max_copies = int_max
	Svc.override("FurnitureManager", furniture)
	eco.add_gold(500)
	var g: int = eco.gold
	t.check("buy_total_never_wraps", not eco.buy_item(&"chair_pine", huge_amount, 4) and eco.gold == g and not furniture.owned.has(&"chair_pine") and shop.get_buy_total("seed_shop", &"carrot_seeds", huge_amount) == eco.MAX_GOLD + 1 and shop.get_buy_total("seed_shop", &"carrot_seeds", 3) == 60 and not shop.buy_item("seed_shop", &"carrot_seeds", huge_amount), "4 gold x (2^62 + 1) chairs is refused, no gold moves; the shop's total saturates too (carrot seeds x 2^62+1 = %d)" % shop.get_buy_total("seed_shop", &"carrot_seeds", huge_amount))
	_release_fakes()
	# a saved amount: floats beyond the int64 range, strings, garbage
	eco.from_dict({"gold": 1e30})
	var loaded_big: int = eco.gold
	eco.from_dict({"gold": -1e30})
	var loaded_neg: int = eco.gold
	eco.from_dict({"gold": "1e30"})
	var loaded_text: int = eco.gold
	eco.from_dict({"gold": "lots"})
	t.check("gold_load_clamped", loaded_big == eco.MAX_GOLD and loaded_neg == 0 and loaded_text == eco.MAX_GOLD and eco.gold == 500, "a saved 1e30 loads as MAX_GOLD, -1e30 as 0, \"1e30\" as MAX_GOLD, text as the default 500 (%d, %d, %d, %d)" % [loaded_big, loaded_neg, loaded_text, eco.gold])


# ================================================================================================ item definitions

func _item_defs() -> void:
	var mine := _my_ids()
	t.expect(mine.size() >= 60, "%d items are defined by the 7 item files of the economy" % mine.size())
	var problems: Array[String] = []
	var no_icon_field := true
	for id in mine:
		var d: Dictionary = lr.get_item_def(id)
		var up := str(id).to_upper()
		if str(d.get("name_key", "")) != "ITEM_%s" % up or str(d.get("description_key", "")) != "ITEM_%s_DESC" % up:
			problems.append("%s: name_key / description_key" % id)
		if not (str(d.get("category", "")) in KNOWN_CATEGORIES):
			problems.append("%s: category %s" % [id, d.get("category", "")])
		if not Rarity.is_valid(d.get("rarity", "")) or str(d.get("rarity", "")) == "":
			problems.append("%s: rarity %s" % [id, d.get("rarity", "")])
		if not d.has("max_stack") or int(d["max_stack"]) < 1:
			problems.append("%s: max_stack" % id)
		if not d.has("buy_price") or not d.has("sell_price") or int(d["buy_price"]) < 0 or int(d["sell_price"]) < 0:
			problems.append("%s: prices" % id)
		if str(d.get("category", "")) in ["tool", "weapon"] and int(d.get("max_stack", 0)) != 1:
			problems.append("%s: a tool or weapon stacks to 1" % id)
		if d.has("icon"):
			no_icon_field = false
		if str(d.get("category", "")) in ["tool", "weapon", "seed", "farm", "placeable", "consumable"] and not d.has("stamina_cost"):
			problems.append("%s: stamina_cost (Player2D would charge its default of 4)" % id)
		if (d.has("heal_half_hearts") or d.has("oil_seconds") or d.has("stamina")) and float(d.get("stamina_cost", 4)) != 0.0:
			problems.append("%s: a consumable costs no energy to use" % id)
	t.check("item_defs_complete", problems.is_empty(), "name/description keys, category, rarity, max_stack, prices, stamina_cost of %d items; problems %s" % [mine.size(), str(problems.slice(0, 6))])
	t.expect(no_icon_field, "no def sets `icon`: every id has an icon of its own name (P23 bakes one per id)")
	t.expect(lr.data_report.is_empty(), "no item id is defined twice (fairy_dust only in magic.lua): %s" % str(lr.data_report.slice(0, 2)))
	t.expect(lr.get_item_def("fairy_dust").get("rarity") == "rare" and _script_of("fairy_dust") == "items/magic" and _script_of("teleport_stone") == "" and _script_of("enchanted_soil") == "", "fairy_dust lives in magic.lua only; teleport_stone and enchanted_soil (no 2D mechanic) are cut")
	# the guide
	var moon: Dictionary = lr.get_item_def("moonstone")
	t.check("guide_moonstone", moon.get("sell_price") == 220 and moon.get("rarity") == "rare" and str(loc.text_in("ITEM_MOONSTONE_DESC", "da")).begins_with("Lyser svagt i mørke"), "Månesten sells for 220, rare, 'Lyser svagt i mørke...'")
	t.expect(lr.get_item_def("copper_ore").get("buy_price") == 35 and lr.get_item_def("copper_ore").get("sell_price") == 14 and lr.get_item_def("wool").get("sell_price") == 12, "copper_ore 35 / 14 and wool 30 / 12 are the prices the content assumes")
	# every crop has a seed item and a harvest item at the balance price
	var crops: Dictionary = lr.get_config("crops", {})
	var bad: Array[String] = []
	for crop in crops:
		var seed_ok := false
		for id in _item_ids():
			if str(lr.get_item_def(id).get("crop_id", "")) == str(crop):
				seed_ok = true
		var harvest: Dictionary = lr.get_item_def(str(crop))
		if not seed_ok or harvest.is_empty() or int(harvest.get("sell_price", -1)) != int(crops[crop].get("sell_price", -2)):
			bad.append(str(crop))
	t.check("crop_prices_match_balance", bad.is_empty() and crops.size() == 9, "%d crops: a seed item with crop_id and a harvest item that sells at crops.<id>.sell_price; wrong %s" % [crops.size(), str(bad)])
	# Every advertised animal product must resolve, including the pet bond token.
	var missing: Array[String] = []
	for id in _item_ids():
		var produces := str(lr.get_item_def(id).get("produces", ""))
		if produces != "" and lr.get_item_def(produces).is_empty():
			missing.append("%s -> %s" % [id, produces])
	t.check("animal_products_defined", missing.is_empty(), "every animal product resolves to an item: "+str(missing))
	# a price never makes a loop: bought items sell for at most half; even the biggest discount leaves a loss
	var loop: Array[String] = []
	for id in mine:
		var d: Dictionary = lr.get_item_def(id)
		if int(d.get("buy_price", 0)) > 0 and int(d.get("sell_price", 0)) * 2 > int(d["buy_price"]):
			loop.append(str(id))
	t.check("sell_below_half_of_buy", loop.is_empty(), "every purchasable item of the economy sells for at most half its price; over: %s" % str(loop))


# ================================================================================================ the backpack

func _backpack() -> void:
	_fresh()
	t.check("slots_are_24", eco.INVENTORY_SLOTS == 24 and eco.used_slots() == STARTER.size() - 1, "INVENTORY_SLOTS %d, %d used after the starter kit" % [eco.INVENTORY_SLOTS, eco.used_slots()])
	t.expect(not eco.add_item(&"wood", 0) and not eco.add_item(&"wood", -3) and not eco.remove_item(&"wood", 0) and not eco.remove_item(&"wood", -1) and not eco.has_item(&"wood", 0), "an amount <= 0 is refused everywhere (add, remove, has)")
	t.expect(not eco.add_item(&"", 1) and not eco.has_items({"wood": 0}) and eco.has_items({}), "no id and amount 0 inside has_items are refused, an empty requirement is met")
	# stacking: 150 wood = 99 + 51
	t.expect(eco.add_item(&"wood", 150), "150 wood fit")
	var slots_of_wood := 0
	var wood_amounts: Array = []
	for s in eco.inventory:
		if s["id"] == &"wood":
			slots_of_wood += 1
			wood_amounts.append(int(s["amount"]))
	t.check("stacking_max_stack", slots_of_wood == 2 and wood_amounts == [99, 51] and eco.count_item(&"wood") == 150, "150 wood = %s (max_stack 99)" % str(wood_amounts))
	t.expect(eco.add_item(&"wood", 48) and eco.count_item(&"wood") == 198 and eco.used_slots() == STARTER.size() - 1 + 2, "the half-empty stack is filled first (198 wood in 2 slots)")
	t.expect(eco.max_stack_of(&"hoe_wooden") == 1 and eco.max_stack_of(&"wood") == 99 and eco.max_stack_of(&"scarecrow") == 20 and eco.max_stack_of(&"no_such_item_id") == 99, "max_stack: tools 1, default 99, the def's own number, unknown 99")
	# remove across stacks, last stack first
	t.expect(eco.remove_item(&"wood", 60) and eco.count_item(&"wood") == 138, "remove_item takes from several stacks")
	t.expect(not eco.remove_item(&"wood", 139) and eco.count_item(&"wood") == 138, "removing more than the player has changes nothing")
	# the 24-slot cap
	_fresh()
	var mark: int = t.log_mark()
	_empty_backpack()
	t.expect(eco.used_slots() == 0 and eco.add_item(&"wood", 99 * eco.INVENTORY_SLOTS, true) and eco.used_slots() == 24 and eco.free_slots() == 0, "the backpack can be filled to 24 slots")
	var w := _watch(["item_gained", "notification_posted"])
	t.expect(not eco.add_item(&"wood", 1), "wood does not fit into a full backpack of full stacks")
	t.expect(not eco.add_item(&"moss", 1) and eco.count_item(&"moss") == 0, "a new item has no slot")
	t.check("backpack_full_refused", _count(w, "item_gained") == 0 and _count(w, "notification_posted") == 2, "a refused add gives nothing and shows the inventory-full toast (no item_gained)")
	_unwatch(w)
	t.expect(eco.remove_item(&"wood", 1) and eco.add_item(&"wood", 1) and eco.used_slots() == 24, "one wood out, one wood in: still fits")
	t.expect(not eco.add_item(&"wood", 2), "all or nothing: two do not fit into the room of one")
	t.expect_clean_since(mark, "refusing items logs no engine warning")
	# a failed buy never takes gold when the backpack is full
	eco.add_gold(1000)
	var g: int = eco.gold
	t.expect(not eco.buy_item(&"moss", 1, 8) and eco.gold == g, "buy_item with a full backpack takes no gold")


func _empty_backpack() -> void:
	for id in STARTER:
		eco.remove_item(StringName(id), int(STARTER[id]))


func _new_game_and_starter_kit() -> void:
	_fresh()
	eco.add_gold(3000)
	eco.add_item(&"moonstone", 4)
	eco.add_item(&"wood", 120)
	var w := _watch(["item_gained", "rare_item_found", "gold_changed", "player_inventory_changed"])
	t.new_game()
	var inv := _inv()
	t.check("new_game_resets", eco.gold == 500 and inv == _starter_backpack() and eco.arsenal.count_total("sword_rusty") == 1, "after a new game: %d guldagern and %s" % [eco.gold, str(inv)])
	t.expect(_count(w, "item_gained") == 0 and _count(w, "rare_item_found") == 0, "the starter kit is given silently (no item_gained)")
	t.expect(_count(w, "gold_changed") >= 1 and _count(w, "player_inventory_changed") >= 1, "the new game tells the HUD about gold and backpack")
	_unwatch(w)
	t.expect(eco.used_slots() == 8 and eco.inventory[0]["id"] == &"hoe_wooden", "eight backpack slots; the starter sword lives in the arsenal")
	var eq: Dictionary = eco.equipment
	t.check("starter_equipment", eq.get("tool_hoe") == &"hoe_wooden" and eq.get("tool_watering") == &"watering_can_copper" and eq.get("tool_pickaxe") == &"pickaxe_wooden" and eq.get("tool_axe") == &"axe_wooden" and eq.get("tool_scythe") == &"scythe" and eq.get("weapon") == &"sword_rusty", "the kit's tools and the rusty sword are equipped: %s" % str(eq))
	# a second new game gives the same
	eco.remove_item(&"scythe", 1)
	eco.add_gold(-499)
	t.new_game()
	t.expect(_inv() == _starter_backpack() and eco.gold == 500 and eco.equipment.get("tool_scythe") == &"scythe", "every new game restores gold, backpack and equipment")
	t.expect(bus.new_game_started.get_connections().any(func(c: Dictionary) -> bool: return c["callable"].get_object() == eco), "reset() is connected to EventBus.new_game_started")


func _signals() -> void:
	_fresh()
	var w := _watch(["item_gained", "rare_item_found", "player_inventory_changed", "notification_posted"])
	t.expect(eco.add_item(&"wood", 150), "add 150 wood")
	t.check("item_gained_once_per_add", _count(w, "item_gained") == 1 and _args(w, "item_gained")[0] == [&"wood", 150] and _count(w, "rare_item_found") == 0, "one item_gained(wood, 150) for a two-stack add: %s" % str(_args(w, "item_gained")))
	t.expect(_count(w, "notification_posted") == 1 and _count(w, "player_inventory_changed") == 1, "one toast and one backpack update for it")
	t.expect(eco.add_item(&"moss", 3, true) and _count(w, "item_gained") == 1 and _count(w, "notification_posted") == 1 and _count(w, "player_inventory_changed") == 2, "a silent add fires neither item_gained nor a toast but still updates the backpack")
	t.expect(not eco.add_item(&"wood", 0) and _count(w, "item_gained") == 1, "a refused add fires nothing")
	_unwatch(w)


# ================================================================================================ tools

func _tools() -> void:
	_fresh()
	t.check("tool_power", eco.get_tool_power("hoe") == 1 and eco.get_tool_power("watering") == 1 and eco.get_tool_power("pickaxe") == 1 and eco.get_tool_power("axe") == 1 and eco.get_tool_power("scythe") == 1 and eco.get_tool_power("weapon") == 5 and eco.get_tool_power("nothing") == 0, "wooden tools power 1, the rusty sword 5")
	eco.add_item(&"hoe_iron", 1)
	t.expect(eco.equipment["tool_hoe"] == &"hoe_iron" and eco.get_tool_power("hoe") == 2, "a stronger tool is equipped automatically")
	eco.add_item(&"pickaxe_copper", 1)
	t.expect(eco.get_tool_power("pickaxe") == 2, "copper pickaxe: power 2")
	eco.add_item(&"pickaxe_iron", 1)
	t.expect(eco.get_tool_power("pickaxe") == 3 and eco.best_tool_id("pickaxe") == &"pickaxe_iron", "iron pickaxe: power 3")
	eco.add_item(&"pickaxe_wooden", 1)
	t.expect(eco.get_tool_power("pickaxe") == 3, "a weaker tool never replaces the better one")
	eco.add_item(&"iron_sword", 1)
	t.expect(eco.get_tool_power("weapon") == 12 and eco.get_weapon_damage() == 12, "the iron sword (damage 12) replaces the rusty one")
	eco.remove_item(&"pickaxe_iron", 1)
	t.expect(eco.get_tool_power("pickaxe") == 2 and eco.equipment["tool_pickaxe"] == &"pickaxe_copper", "selling the best tool equips the next best")
	t.expect(eco.equip(&"tool_pickaxe", &"pickaxe_wooden") and eco.get_tool_power("pickaxe") == 1, "equip() lets the player choose a weaker tool")
	t.expect(not eco.equip(&"tool_pickaxe", &"axe_wooden") and not eco.equip(&"tool_hoe", &"pickaxe_iron") and not eco.equip(&"tool_hoe", &"hoe_gold"), "equip() refuses a tool of the wrong type or one the player does not own")
	t.expect(eco.equip(&"tool_hoe", &"") and eco.get_tool_power("hoe") == 0, "equip with an empty id empties the slot")
	eco.remove_item(&"pickaxe_wooden", 2)
	eco.remove_item(&"pickaxe_copper", 1)
	t.expect(eco.get_tool_power("pickaxe") == 0, "no pickaxe left: power 0")


# ================================================================================================ save

func _save() -> void:
	_fresh()
	eco.add_item(&"wood", 150, true)
	eco.add_item(&"moonstone", 2, true)
	eco.add_item(&"hoe_iron", 1, true)
	eco.add_gold(277)
	var before_inv := _inv()
	var before_slots: Array = []
	for s in eco.inventory:
		before_slots.append([str(s["id"]), int(s["amount"])])
	var d: Dictionary = eco.to_dict()
	var parsed: Variant = SaveCodec.through_json(d)
	t.new_game()
	t.expect(_inv() == _starter_backpack(), "setup: a new game in between")
	t.expect(eco.from_dict(parsed as Dictionary), "from_dict accepts the saved dictionary")
	var after_slots: Array = []
	for s in eco.inventory:
		after_slots.append([str(s["id"]), int(s["amount"])])
	t.check("save_round_trip", eco.gold == 777 and _inv() == before_inv and after_slots == before_slots and eco.equipment["tool_hoe"] == &"hoe_iron" and typeof(eco.inventory[0]["id"]) == TYPE_STRING_NAME, "gold %d, %d slots, equipment kept, ids are StringName again" % [eco.gold, after_slots.size()])
	t.expect(typeof(eco.inventory[0]["amount"]) == TYPE_INT and typeof(eco.gold) == TYPE_INT, "amounts and gold are ints after the JSON round trip")
	t.expect((d["inventory"] as Array).all(func(s: Dictionary) -> bool: return typeof(s["id"]) == TYPE_STRING and s.has("amount") and s.has("meta")), "to_dict writes plain Strings and keeps the slot meta")
	# garbage in: invalid slots are dropped, big stacks are split, tools stay one per slot
	var junk := {"gold": 12.0, "inventory": [{"id": "wood", "amount": 3.0}, {"id": "", "amount": 2}, {"id": "stone", "amount": -5}, "oops", 17, {"id": "carrot", "amount": 250}, {"id": "hoe_wooden", "amount": 3}, {"id": "moss"}], "equipment": {"tool_hoe": "axe_wooden", "weapon": "ghost_sword"}}
	t.expect(eco.from_dict(junk), "from_dict never throws on bad data")
	var inv := _inv()
	var carrot_slots := 0
	var hoe_slots := 0
	for s in eco.inventory:
		carrot_slots += 1 if s["id"] == &"carrot" else 0
		hoe_slots += 1 if s["id"] == &"hoe_wooden" else 0
	t.check("save_drops_invalid_slots", eco.gold == 12 and inv.get("wood") == 3 and inv.get("carrot") == 250 and carrot_slots == 3 and hoe_slots == 3 and inv.size() == 3 and eco.used_slots() == 7, "gold 12, wood 3, carrot 250 in 3 slots, 3 hoes in 3 slots, the 5 invalid entries dropped: %s" % str(inv))
	t.expect(eco.equipment["tool_hoe"] == &"hoe_wooden" and eco.equipment["weapon"] == &"", "an equipment entry that is not owned or does not fit is ignored")
	var many: Array = []
	for i in 40:
		many.append({"id": "item_%d" % i, "amount": 1})
	eco.from_dict({"gold": 5, "inventory": many})
	t.expect(eco.used_slots() == 24 and eco.get_inventory_dict().size() == 24, "a save with more than 24 slots keeps the first 24")
	eco.from_dict({"gold": 999999999, "inventory": {"wood": 7.0, "stone": 0}})
	t.expect(eco.gold == eco.MAX_GOLD and _inv() == {"wood": 7}, "gold is clamped on load and {id: amount} dictionaries are accepted")
	t.expect(eco.from_dict({}) and eco.used_slots() == 0, "an empty dictionary loads as an empty backpack")
	# the section SaveManager reads
	t.new_game()
	var d2: Dictionary = eco.to_dict()
	t.expect(d2.has("gold") and d2.get("inventory") is Array and d2.get("v") == 1, "to_dict has gold, inventory (a list) and its own version")


## The player's own choice of tool survives save and load: a weaker tool picked on purpose (equip() or use_item) and a slot emptied
## on purpose come back as they were; only slots the save does not decide get the best tool (an old save without `equipment`).
func _equipment_choice_saved() -> void:
	_fresh()
	eco.add_item(&"hoe_iron", 1, true)
	eco.add_item(&"pickaxe_copper", 1, true)
	eco.add_item(&"pickaxe_iron", 1, true)
	eco.add_item(&"iron_sword", 1, true)
	t.expect(eco.equipment["tool_hoe"] == &"hoe_iron" and eco.equipment["tool_pickaxe"] == &"pickaxe_iron" and eco.equipment["weapon"] == &"iron_sword", "setup: the strongest tools and the iron sword are equipped automatically")
	t.expect(eco.use_item(&"hoe_wooden") and eco.equip(&"weapon", &"sword_rusty") and eco.equip(&"tool_pickaxe", &"pickaxe_copper") and eco.equip(&"tool_watering", &""), "setup: the player picks the wooden hoe (use_item), the rusty sword and the copper pickaxe (equip) and empties the watering can slot")
	var parsed: Variant = SaveCodec.through_json(eco.to_dict())
	t.new_game()
	t.expect(eco.equipment["tool_hoe"] == &"hoe_wooden" and eco.equipment["tool_watering"] == &"watering_can_copper", "setup: a new game in between equips the kit's tools")
	t.expect(eco.from_dict(parsed as Dictionary), "from_dict accepts the save")
	t.check("equip_choice_survives_save", eco.equipment["tool_hoe"] == &"hoe_wooden" and eco.equipment["weapon"] == &"sword_rusty" and eco.equipment["tool_pickaxe"] == &"pickaxe_copper" and eco.get_tool_power("pickaxe") == 2 and eco.get_tool_power("hoe") == 1 and eco.get_weapon_damage() == 5, "the weaker hoe, sword and pickaxe the player chose are NOT replaced by the best tools on load: %s" % str(eco.equipment))
	t.check("equip_empty_slot_survives_save", eco.equipment["tool_watering"] == &"" and eco.get_tool_power("watering") == 0 and eco.equipment["tool_axe"] == &"axe_wooden" and eco.equipment["tool_scythe"] == &"scythe", "a slot the player emptied stays empty (its tool is still in the backpack), the others are as saved")
	t.expect(eco.equipment["tool_hoe"] is StringName and eco.count_item(&"hoe_iron") == 1, "the equipped ids are StringNames again and the better tools are still owned")
	# an old save knows no equipment: every slot gets the best tool the player owns
	var old_save := {"gold": 40, "inventory": [{"id": "hoe_wooden", "amount": 1}, {"id": "hoe_iron", "amount": 1}, {"id": "sword_rusty", "amount": 1}, {"id": "iron_sword", "amount": 1}, {"id": "axe_wooden", "amount": 1}]}
	t.expect(eco.from_dict(old_save) and eco.equipment["tool_hoe"] == &"hoe_iron" and eco.equipment["weapon"] == &"iron_sword" and eco.equipment["tool_axe"] == &"axe_wooden" and eco.equipment["tool_pickaxe"] == &"", "a save without `equipment` equips the best owned tool of every slot")
	# an entry that is not owned any more does not decide its slot: the best tool is equipped instead
	var stale := {"gold": 40, "inventory": [{"id": "hoe_wooden", "amount": 1}, {"id": "hoe_iron", "amount": 1}], "equipment": {"tool_hoe": "hoe_gold", "tool_axe": "hoe_wooden"}}
	t.expect(eco.from_dict(stale) and eco.equipment["tool_hoe"] == &"hoe_iron" and eco.equipment["tool_axe"] == &"", "an equipment entry that is not owned or does not fit its slot is ignored: the slot gets the best tool (or stays empty)")
	# the saved choice is written for every slot (the empty ones as "")
	var written: Dictionary = eco.to_dict()["equipment"]
	t.expect(written.size() == 7 and written["tool_hoe"] == "hoe_iron" and written["accessory"] == "", "to_dict writes all 7 slots, empty ones as an empty string (so `deliberately empty` can be told from `not saved`)")


# ================================================================================================ routing

func _routing() -> void:
	_fresh()
	# 1. the stores do not exist yet: furniture and clothing fall back to the backpack
	Svc.override("FurnitureManager", _fake(BareNode.new()))
	Svc.override("WardrobeManager", _fake(BareNode.new()))
	t.expect(ItemKinds.storage_of(&"chair_pine") == &"furniture" and ItemKinds.storage_of(&"shirt_linen_cream") == &"clothing" and ItemKinds.storage_of(&"wood") == &"backpack" and ItemKinds.storage_of(&"plank_pine") == &"backpack" and ItemKinds.storage_of(&"blueprint_kongelig") == &"backpack", "storage_of: furniture -> furniture store, clothing -> wardrobe store, materials and blueprints stay in the backpack")
	var w := _watch(["item_gained"])
	t.expect(eco.add_item(&"chair_pine", 2) and eco.add_item(&"shirt_linen_cream", 1), "without the stores both items are added (to the backpack)")
	t.expect(eco.count_item(&"chair_pine") == 2 and eco.has_item(&"chair_pine", 2) and eco.get_inventory_dict().get(&"chair_pine") == 2, "the fallback copies are counted and visible")
	t.expect(_count(w, "item_gained") == 2, "item_gained fires for every kind of item")
	# 2. the stores appear: the items are adopted without a second item_gained and without being lost
	var furniture := _fake(FakeStore.new()) as FakeStore
	var wardrobe := _fake(FakeStore.new()) as FakeStore
	wardrobe.max_copies = 1
	Svc.override("FurnitureManager", furniture)
	Svc.override("WardrobeManager", wardrobe)
	eco.adopt_misrouted()
	t.check("routing_adopts_fallback", furniture.owned.get(&"chair_pine") == 2 and wardrobe.owned.get(&"shirt_linen_cream") == 1 and not _inv().has("chair_pine") and not _inv().has("shirt_linen_cream") and _count(w, "item_gained") == 2, "the backpack copies moved into the stores: %s / %s" % [str(furniture.owned), str(wardrobe.owned)])
	t.expect(eco.count_item(&"chair_pine") == 2 and eco.count_item(&"shirt_linen_cream") == 1, "count_item reads the stores")
	# 3. routed add / remove / has / count
	t.expect(eco.add_item(&"chair_pine", 1) and furniture.owned[&"chair_pine"] == 3 and not _inv().has("chair_pine"), "furniture goes to the furniture store, not the backpack")
	t.expect(eco.add_item(&"plank_pine", 5) and _inv().get("plank_pine") == 5 and eco.add_item(&"blueprint_kongelig", 1) and _inv().get("blueprint_kongelig") == 1, "building materials and blueprints go to the backpack")
	furniture.placed[&"chair_pine"] = 2
	t.expect(eco.count_item(&"chair_pine") == 3 and eco.has_item(&"chair_pine", 3), "placed copies still count as owned")
	t.expect(not eco.remove_item(&"chair_pine", 2) and furniture.owned[&"chair_pine"] == 3, "remove_item never touches placed copies (only 1 of 3 is free)")
	t.expect(eco.remove_item(&"chair_pine", 1) and furniture.owned[&"chair_pine"] == 2, "the free copy can be removed")
	t.expect(not eco.add_item(&"shirt_linen_cream", 1) and wardrobe.owned[&"shirt_linen_cream"] == 1, "a second copy of a garment the wardrobe refuses is refused (false)")
	furniture.owned[&"chair_pine"] = 9
	t.expect(not eco.add_item(&"chair_pine", 1) and furniture.owned[&"chair_pine"] == 9, "furniture beyond the store's 9 copies is refused (false)")
	furniture.owned[&"chair_pine"] = 2
	_unwatch(w)
	# 4. list_sellable: backpack + the furniture stock that is not placed; nothing that cannot be sold
	eco.add_item(&"wood", 3, true)
	eco.add_item(&"friendship_token", 2, true)
	furniture.owned[&"table_round_pine"] = 1
	furniture.placed[&"chair_pine"] = 1
	var rows: Array = eco.list_sellable()
	var by_id := {}
	for r in rows:
		by_id[str(r["id"])] = r
	t.check("list_sellable_aggregates", by_id.has("wood") and by_id["wood"]["amount"] == 3 and by_id.has("hoe_wooden") and by_id.has("chair_pine") and by_id["chair_pine"]["amount"] == 1 and by_id["chair_pine"]["kind"] == &"furniture" and by_id.has("table_round_pine") and not by_id.has("friendship_token") and not by_id.has("shirt_linen_cream"), "backpack plus unplaced furniture (chair 2 owned, 1 placed = 1), no special items, no garments: %s" % str(by_id.keys()))
	var last_rank := 99
	var sorted_ok := true
	for r in rows:
		sorted_ok = sorted_ok and Rarity.rank(r["rarity"]) <= last_rank
		last_rank = Rarity.rank(r["rarity"])
	t.expect(sorted_ok, "list_sellable is sorted by rarity, highest first")
	# 5. the backpack part of the save holds only backpack items once a store exists
	eco.add_item(&"scarecrow", 1, true)
	var saved: Dictionary = eco.to_dict()
	var ids: Array = []
	for s in saved["inventory"]:
		ids.append(s["id"])
	t.check("routing_by_category", not ids.has("chair_pine") and not ids.has("shirt_linen_cream") and ids.has("wood") and ids.has("plank_pine"), "economy.inventory keeps ONLY backpack items: %s" % str(ids.slice(0, 12)))
	_release_fakes()


## Everything count_item() / has_item() counts can be removed: the store gives its free copies first, the rest comes from the copies
## that sit in the backpack because the store refused them (its cap); placed copies are never touched; all or nothing.
func _remove_matches_count() -> void:
	_fresh()
	Svc.override("FurnitureManager", _fake(BareNode.new()))
	t.expect(eco.add_item(&"chair_pine", 3, true) and _inv().get("chair_pine") == 3, "setup: the furniture store is missing, 3 chairs wait in the backpack")
	var furniture := _fake(FakeStore.new()) as FakeStore          # cap 9 copies
	furniture.owned[&"chair_pine"] = 8
	Svc.override("FurnitureManager", furniture)
	eco.adopt_misrouted()
	t.expect(furniture.owned[&"chair_pine"] == 8 and _inv().get("chair_pine") == 3, "setup: the store (8 of 9) refuses the 3 leftovers, they stay in the backpack")
	t.expect(eco.count_item(&"chair_pine") == 11 and eco.has_item(&"chair_pine", 11), "count_item and has_item count the store AND the leftovers: 11")
	var snapshot := [furniture.owned[&"chair_pine"], _inv().get("chair_pine")]
	t.expect(not eco.remove_item(&"chair_pine", 12) and [furniture.owned[&"chair_pine"], _inv().get("chair_pine")] == snapshot, "more than owned: refused, store and backpack unchanged (all or nothing)")
	var w := _watch(["player_inventory_changed"])
	t.check("remove_matches_count", eco.remove_item(&"chair_pine", 10) and furniture.owned[&"chair_pine"] == 0 and _inv().get("chair_pine") == 1 and eco.count_item(&"chair_pine") == 1 and _count(w, "player_inventory_changed") == 1, "remove 10 of 11 = 8 from the store, then 2 of the 3 backpack leftovers (store %d, backpack %s)" % [furniture.owned[&"chair_pine"], str(_inv().get("chair_pine"))])
	_unwatch(w)
	t.expect(eco.remove_item(&"chair_pine", 1) and eco.count_item(&"chair_pine") == 0 and not eco.has_item(&"chair_pine", 1), "the last copy goes too")
	# placed copies: 8 in the store, 2 of them placed (6 free) + 3 leftovers = 9 removable of 11 owned
	furniture.owned[&"chair_pine"] = 8
	furniture.placed[&"chair_pine"] = 2
	_inv_set(&"chair_pine", 3)
	t.expect(eco.count_item(&"chair_pine") == 11 and not eco.remove_item(&"chair_pine", 10) and furniture.owned[&"chair_pine"] == 8 and _inv().get("chair_pine") == 3, "10 of 11 owned, but 2 are placed: refused, nothing changes")
	t.expect(eco.remove_item(&"chair_pine", 9) and furniture.owned[&"chair_pine"] == 2 and not _inv().has("chair_pine") and eco.count_item(&"chair_pine") == 2, "9 = the 6 free store copies + the 3 leftovers; the 2 placed copies stay")
	# selling goes through the same path: a leftover can be sold
	_inv_set(&"chair_pine", 1)
	furniture.owned[&"chair_pine"] = 9
	furniture.placed[&"chair_pine"] = 9
	var g: int = eco.gold
	t.expect(eco.sell_item(&"chair_pine", 1, 30) and eco.gold == g + 30 and not _inv().has("chair_pine") and furniture.owned[&"chair_pine"] == 9, "a leftover copy can be sold while every copy in the store is placed")
	_release_fakes()


## Puts `amount` of an item straight into a backpack slot (a store that refused it earlier): the state add_item cannot make once the
## store exists. Test helper only.
func _inv_set(item_id: StringName, amount: int) -> void:
	for i in range(eco.inventory.size() - 1, -1, -1):
		if eco.inventory[i]["id"] == item_id:
			eco.inventory.remove_at(i)
	if amount > 0:
		eco.inventory.append({"id": item_id, "amount": amount, "meta": {}})
	eco._misrouted = true


func _one_of_a_kind_and_rare() -> void:
	_fresh()
	var legend_furniture := ""
	var unique_garment := ""
	var legend_garment := ""
	var unique_furniture := ""
	for id in _item_ids():
		var d: Dictionary = lr.get_item_def(id)
		match [str(d.get("category", "")), str(d.get("rarity", ""))]:
			["furniture", "legendary"]:
				if legend_furniture == "":
					legend_furniture = str(id)
			["furniture", "unique"]:
				if unique_furniture == "":
					unique_furniture = str(id)
			["clothing", "unique"]:
				if unique_garment == "":
					unique_garment = str(id)
			["clothing", "legendary"]:
				if legend_garment == "":
					legend_garment = str(id)
	t.expect(legend_furniture != "" and unique_garment != "" and legend_garment != "" and unique_furniture != "", "the content has unique and legendary furniture and clothing (%s %s %s %s)" % [legend_furniture, unique_furniture, unique_garment, legend_garment])
	var furniture := _fake(FakeStore.new()) as FakeStore
	var wardrobe := _fake(FakeStore.new()) as FakeStore
	Svc.override("FurnitureManager", furniture)
	Svc.override("WardrobeManager", wardrobe)
	var mark: int = t.log_mark()
	var w := _watch(["item_gained", "rare_item_found"])
	t.expect(eco.add_item(StringName(legend_furniture), 1) and not eco.add_item(StringName(legend_furniture), 1), "a legendary piece: the first copy is added, the second refused (false)")
	t.expect(eco.add_item(StringName(unique_garment), 1) and not eco.add_item(StringName(unique_garment), 1) and not eco.add_item(StringName(legend_garment), 2), "a unique garment: second copy refused; two legendary pieces at once are refused too")
	t.expect(furniture.owned[StringName(legend_furniture)] == 1 and wardrobe.owned[StringName(unique_garment)] == 1 and not wardrobe.owned.has(StringName(legend_garment)), "the refused copies never reached the stores")
	t.check("one_of_a_kind_refused", _count(w, "item_gained") == 2 and eco.count_item(StringName(legend_furniture)) == 1, "item_gained only for the two accepted adds")
	t.expect_clean_since(mark, "a refused keepsake logs no warning and no error (no warning in the refusal)")
	# the same rule when the store is missing (backpack fallback)
	Svc.override("FurnitureManager", _fake(BareNode.new()))
	t.expect(eco.add_item(StringName(unique_furniture), 1) and not eco.add_item(StringName(unique_furniture), 1) and eco.count_item(StringName(unique_furniture)) == 1, "a keepsake in the backpack fallback is refused the second time too")
	t.expect(not eco.is_sellable(StringName(legend_furniture)) and eco.sell_value(StringName(unique_garment)) == 0 and eco.buy_value(StringName(legend_furniture)) == 0, "keepsakes have no sell value and no buy value")
	_unwatch(w)
	# rare_item_found for rank >= rare
	Svc.override("FurnitureManager", furniture)
	furniture.owned.clear()
	wardrobe.owned.clear()
	var w2 := _watch(["rare_item_found", "item_gained"])
	eco.add_item(&"wood", 1)
	eco.add_item(&"amethyst", 1)
	t.expect(_count(w2, "rare_item_found") == 0, "common and uncommon finds do not fire rare_item_found")
	eco.add_item(&"moonstone", 1)
	eco.add_item(&"emerald", 1, true)
	eco.add_item(StringName(legend_garment), 1)
	var rare_args := _args(w2, "rare_item_found")
	t.check("rare_item_found", rare_args == [[&"moonstone", &"rare"], [StringName(legend_garment), &"legendary"]], "rare_item_found(id, rarity) for rank >= rare, once per add, not for silent adds: %s" % str(rare_args))
	t.expect(_count(w2, "item_gained") == 4, "item_gained still fires for every successful non-silent add")
	_unwatch(w2)
	_release_fakes()


# ================================================================================================ use_item

func _use_item() -> void:
	_fresh()
	var player := _fake(FakePlayer.new()) as FakePlayer
	player.add_to_group(&"player")
	t.root.add_child(player)
	# hearts
	t.expect(eco.use_item(&"health_tonic") and player.half_hearts == 8 and eco.count_item(&"health_tonic") == 0, "a health tonic gives 4 half hearts through the player and is used up")
	eco.add_item(&"health_tonic", 1, true)
	player.half_hearts = 10
	t.expect(not eco.use_item(&"health_tonic") and eco.count_item(&"health_tonic") == 1, "at full health the tonic is not used up")
	# oil and energy
	t.expect(eco.use_item(&"lantern_oil") and is_equal_approx(player.oil, 110.0) and eco.count_item(&"lantern_oil") == 1, "lantern oil adds 60 seconds")
	eco.add_item(&"lantern_oil", 1, true)
	eco.use_item(&"lantern_oil")
	t.expect(is_equal_approx(player.oil, 150.0) and eco.count_item(&"lantern_oil") == 1, "the oil is capped at max_oil")
	t.expect(not eco.use_item(&"lantern_oil") and eco.count_item(&"lantern_oil") == 1, "with a full lantern the oil stays in the backpack")
	eco.add_item(&"cookie", 2, true)
	eco.add_item(&"honey_cake", 1, true)
	eco.add_item(&"apple", 1, true)
	t.expect(eco.use_item(&"cookie") and is_equal_approx(player.stamina, 35.0), "a cookie restores 15 energy")
	t.expect(eco.use_item(&"honey_cake") and is_equal_approx(player.stamina, 75.0), "a honey cake restores 40 energy")
	player.stamina = 95.0
	t.expect(eco.use_item(&"apple") and is_equal_approx(player.stamina, 100.0), "energy is capped at max_stamina")
	t.expect(not eco.use_item(&"cookie") and eco.count_item(&"cookie") == 1, "with full energy a cookie stays in the backpack")
	player.half_hearts = 2
	t.check("use_item_effects", eco.use_item(&"health_tonic") and player.half_hearts == 6, "heal, oil and energy are applied through the player (group player)")
	t.root.remove_child(player)
	eco.add_item(&"health_tonic", 1, true)
	t.expect(not eco.use_item(&"health_tonic") and eco.count_item(&"health_tonic") == 1, "no player in the scene: the tonic is not used")
	# tools and weapons
	t.expect(eco.add_item(&"hoe_iron", 1, true) and eco.use_item(&"hoe_wooden") and eco.equipment["tool_hoe"] == &"hoe_wooden" and eco.use_item(&"hoe_iron") and eco.equipment["tool_hoe"] == &"hoe_iron", "use_item on a tool equips it")
	# placeables go to the hotbar
	eco.add_item(&"scarecrow", 1, true)
	var w := _watch(["hotbar_assign_requested", "game_event"])
	t.expect(eco.use_item(&"scarecrow") and _args(w, "hotbar_assign_requested") == [[-1, &"scarecrow"]] and eco.count_item(&"scarecrow") == 1, "a placeable asks the hotbar to take it (slot -1 = first free) and stays in the backpack")
	# animals
	var husbandry := _fake(FakeHusbandry.new()) as FakeHusbandry
	Svc.override("AnimalHusbandry", husbandry)
	eco.add_item(&"baby_chick", 1, true)
	t.expect(eco.use_item(&"baby_chick") and husbandry.adopted == [&"baby_chick"], "a baby animal is adopted by AnimalHusbandry")
	eco.add_item(&"chicken_feed", 1, true)
	t.expect(not eco.use_item(&"chicken_feed") and _args(w, "game_event") == [[&"animal_care_item_used", {"item": "chicken_feed"}]], "animal feed raises animal_care_item_used (the care screen feeds an animal)")
	_release_fakes()
	t.expect(not eco.use_item(&"wood") and not eco.use_item(&"no_such_item") and not eco.use_item(&"moonstone"), "items without a use do nothing")
	_unwatch(w)


# ================================================================================================ fixtures

func _write_fixtures() -> void:
	_release_fakes()
	var items := """kind = "items"

items = {
  fixture_rare = {
    name_key = "ITEM_FIXTURE_RARE",
    description_key = "ITEM_FIXTURE_RARE_DESC",
    category = "gem",
    rarity = "rare",
    max_stack = 9,
    buy_price = 1600,
    sell_price = 640,
  },
  fixture_sell_one = {
    name_key = "ITEM_FIXTURE_SELL_ONE",
    description_key = "ITEM_FIXTURE_SELL_ONE_DESC",
    category = "resource",
    rarity = "normal",
    max_stack = 99,
    buy_price = 3,
    sell_price = 1,
  },
  fixture_no_sell_price = {
    name_key = "ITEM_FIXTURE_NO_SELL_PRICE",
    description_key = "ITEM_FIXTURE_NO_SELL_PRICE_DESC",
    category = "resource",
    rarity = "normal",
    buy_price = 40,
  },
  fixture_worthless = {
    name_key = "ITEM_FIXTURE_WORTHLESS",
    description_key = "ITEM_FIXTURE_WORTHLESS_DESC",
    category = "resource",
    rarity = "normal",
    max_stack = 99,
    buy_price = 5,
    sell_price = 0,
  },
}
"""
	var shops := """kind = "shops"

shops = {
  fixture_curve_shop = {
    name_key = "SHOP_FIXTURE_CURVE_SHOP",
    keeper = "merchant_pip",
    greeting_key = "SHOP_FIXTURE_CURVE_SHOP_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 1.0,
    stock = {
      fixture_rare = { stock = 5, restock = 5 },
      fixture_sell_one = { stock = 5, restock = 5 },
    },
  },
  fixture_weekend = {
    name_key = "SHOP_FIXTURE_WEEKEND",
    keeper = "merchant_pip",
    buy_multiplier = 1.0,
    sell_multiplier = 1.0,
    open_weekdays = { 5, 6 },
    stock = {
      wood = { price = 7, stock = 4, restock = 2 },
    },
  },
  fixture_rotating = {
    name_key = "SHOP_FIXTURE_ROTATING",
    keeper = "merchant_pip",
    buy_multiplier = 2.0,
    sell_multiplier = 0.1,
    buys = { "resource", "forage" },
    stock = {
      lantern_oil = { stock = 3, restock = 1 },
    },
    rotation = {
      { id = "daily", period = 1, pick = 2, qty = 2, rarity = "normal", price_mult = 1.0, pool = { "cookie", "wood" } },
    },
  },
  fixture_nobuy = {
    name_key = "SHOP_FIXTURE_NOBUY",
    keeper = "merchant_pip",
    sell_multiplier = 0.0,
    stock = {},
  },
  fixture_legend_shop = {
    name_key = "SHOP_FIXTURE_LEGEND_SHOP",
    keeper = "merchant_pip",
    stock = {
      wood = { stock = 2 },
__LEGEND__
    },
  },
}
"""
	var recipes := """kind = "recipes"

recipes = {
  fixture_station_only = {
    name_key = "RECIPE_FIXTURE_STATION_ONLY",
    category = "craft",
    station = "vaev",
    ingredients = { wood = 1 },
    output = { item = "fence", amount = 1 },
  },
  fixture_tier_and_flag = {
    name_key = "RECIPE_FIXTURE_TIER_AND_FLAG",
    category = "craft",
    min_home_tier = 4,
    unlock_flag = "bp_fixture",
    ingredients = { wood = 1 },
    output = { item = "fence", amount = 1 },
  },
}
"""
	# a legendary item in a shop's stock: any real legendary id (found, not hard-coded)
	var legend := ""
	for id in _item_ids():
		if str(lr.get_item_def(id).get("rarity", "")) == "legendary":
			legend = str(id)
			break
	shops = shops.replace("__LEGEND__", "      %s = { stock = 1 }," % legend if legend != "" else "")
	for pair in [[FIXTURE_ITEMS, items], [FIXTURE_SHOPS, shops], [FIXTURE_RECIPES, recipes]]:
		var f := FileAccess.open(pair[0], FileAccess.WRITE)
		f.store_string(pair[1])
		f.close()
	for p in [FIXTURE_ITEMS, FIXTURE_SHOPS, FIXTURE_RECIPES]:
		lr.load_file(p)
	_fixtures_loaded = true
	t.expect(not lr.get_shop("fixture_curve_shop").is_empty() and not lr.get_item_def("fixture_rare").is_empty() and not lr.get_recipe("fixture_station_only").is_empty(), "the fixture items, shops and recipes are loaded")


# ================================================================================================ shops from Lua

func _shops_from_lua() -> void:
	_fresh()
	var source := FileAccess.get_file_as_string("res://scripts/economy/shop_system.gd")
	var constants: Dictionary = shop.get_script().get_script_constant_map()
	t.check("shops_from_lua", not constants.has("SHOPS") and not source.contains("\"general_store\": {") and not source.contains("\"stock\": {\"turnip_seeds\""), "the hard-coded SHOPS table is gone from shop_system.gd")
	var ids: Array = []
	for id in lr.get_shops():
		ids.append(str(id))
	for expected in ["seed_shop", "bakery", "smithy", "magic_store", "animal_store"]:
		t.expect(ids.has(expected) and shop.has_shop(expected), "shop %s is defined in lua/shops and ShopSystem knows it" % expected)
	# keepers: the roster's shop owners
	var keepers_ok := true
	for npc_id in lr.get_npcs():
		var n: Dictionary = lr.get_npc(str(npc_id))
		if n.has("shop_id") and lr.get_shop(str(n["shop_id"])).get("keeper") != npc_id:
			keepers_ok = false
	t.expect(keepers_ok, "every shop of npcs.lua names its NPC as keeper")
	# stock: every stocked id has a def; no one-of-a-kind item is stocked
	var bad: Array[String] = []
	for sid in lr.get_shops():
		var def: Dictionary = lr.get_shop(str(sid))
		if str(sid).begins_with("fixture_"):
			continue
		for item_id in def.get("stock", {}):
			var d: Dictionary = lr.get_item_def(str(item_id))
			if d.is_empty() or Rarity.is_one_of_a_kind(d.get("rarity", "normal")):
				bad.append("%s.%s" % [sid, item_id])
	t.expect(bad.is_empty(), "every stocked item of every shop exists and none is a unique / legendary keepsake: %s" % str(bad))
	# the guide's Froe shop
	var seed_lines: Dictionary = {}
	for row in shop.get_shop_inventory("seed_shop"):
		seed_lines[str(row["item_id"])] = row
	var guide_ok := true
	for item_id in GUIDE_SHOP:
		guide_ok = guide_ok and seed_lines.has(item_id) and int(seed_lines[item_id]["price"]) == int(GUIDE_SHOP[item_id])
	t.check("seed_shop_guide_lines", guide_ok, "Kløvermyntes Frø lists the guide's 8 lines at the guide's prices: %s" % str(GUIDE_SHOP))
	var order: Array = []
	for row in shop.get_shop_inventory("seed_shop"):
		order.append(str(row["item_id"]))
	t.expect(order.slice(0, 8) == ["carrot_seeds", "pumpkin_seeds", "strawberry_seeds", "sunflower_seeds", "catnip_seeds", "moonflower_seeds", "fertilizer", "fairy_dust_water"], "the guide's eight lines come first, in the guide's order: %s" % str(order.slice(0, 8)))
	t.expect(loc.text_in("SHOP_SEED_SHOP", "da") == "Kløvermyntes Frø" and loc.text_in("SHOP_SEED_SHOP_GREETING", "da") == "Frisk fra regnbuen i morges! Græskarfrø giver gode penge til høstfesten.", "name and greeting of the seed shop are the guide's Danish text")
	# tabs: Froe / Redskaber / Saelg
	var tabs: Array = []
	for tb in shop.get_shop_tabs("seed_shop"):
		tabs.append(str(tb["id"]))
	t.expect(tabs == ["seed", "tool", "sell"], "the seed shop's tabs: Frø, Redskaber and the sell tab (%s)" % str(tabs))
	var in_seed_tab := 0
	var seed_tab: Dictionary = shop.get_shop_tabs("seed_shop")[0]
	for row in shop.get_shop_inventory("seed_shop"):
		if shop.item_in_tab(seed_tab, row["item_id"]):
			in_seed_tab += 1
	t.expect(in_seed_tab == 10 and shop.item_in_tab(seed_tab, &"fertilizer") and not shop.item_in_tab(seed_tab, &"scythe"), "seeds, fertilizer and fairy dust water are in the Frø tab, tools are not (%d)" % in_seed_tab)
	# the other four
	var smithy: Array = []
	for row in shop.get_shop_inventory("smithy"):
		if str(row.get("source","fixed")) == "fixed": smithy.append(str(row["item_id"]))
	t.expect(smithy == ["hoe_iron", "pickaxe_iron", "watering_can_gold", "iron_sword"], "the smithy sells exactly the iron tools and the iron sword (%s)" % str(smithy))
	var animal: Array = []
	for row in shop.get_shop_inventory("animal_store"):
		animal.append(str(row["item_id"]))
	var animals_ok := animal.size() == 14 and not animal.has("coop_kit") and not animal.has("barn_kit")
	for id in animal:
		animals_ok = animals_ok and lr.get_item_def(id).has("name_key") and _script_of(id) == "items/animals"
	t.check("animal_store_ids", animals_ok, "the animal store stocks 14 ids that exist in animals.lua (baby_*, feed, treats, brush, pail), no kits: %s" % str(animal))
	var magic: Array = []
	for row in shop.get_shop_inventory("magic_store"):
		magic.append(str(row["item_id"]))
	t.expect(magic.has("fairy_dust") and magic.has("lantern_oil") and magic.has("health_tonic") and magic.has("amethyst") and magic.has("crystal_shard") and magic.has("emerald"), "the magic store: fairy dust, gems, lantern oil, health tonic")
	var bakery: Array = []
	for row in shop.get_shop_inventory("bakery"):
		bakery.append(str(row["item_id"]))
	t.expect(bakery == ["flour", "honey", "cookie"], "the bakery sells flour, honey and cookies (%s)" % str(bakery))
	# every Lua shop is complete
	for sid in ["seed_shop", "bakery", "smithy", "magic_store", "animal_store"]:
		var def: Dictionary = lr.get_shop(sid)
		t.expect(loc.text_in(str(def["name_key"]), "da") != "" and loc.text_in(str(def["name_key"]), "en") != "" and loc.text_in(str(def["greeting_key"]), "da") != "" and loc.text_in(str(def["greeting_key"]), "en") != "", "shop %s: name and greeting resolve in da and en" % sid)
	# the legacy id still opens the seed shop
	var w := _watch(["shop_opened", "shop_closed"])
	t.expect(shop.open_shop("general_store") and _args(w, "shop_opened") == [[&"seed_shop"]], "open_shop emits shop_opened (the legacy id general_store opens seed_shop)")
	shop.close_shop(&"seed_shop")
	t.expect(_args(w, "shop_closed") == [[&"seed_shop"]] and not shop.open_shop("no_such_shop") and _count(w, "shop_opened") == 1, "close_shop emits shop_closed; an unknown shop opens nothing")
	_unwatch(w)
	var info: Dictionary = shop.get_shop_info("seed_shop")
	t.expect(info["npc_id"] == "merchant_pip" and info["keeper"] == "merchant_pip" and info["closed"] == false and info["id"] == "seed_shop", "get_shop_info: id, keeper (npc_id), open state")


# ================================================================================================ prices and selling

func _prices_and_selling() -> void:
	_fresh()
	_force_fallback()
	eco.add_gold(5000)
	# a buy charges exactly the listed price
	var carrot: Dictionary = {}
	for row in shop.get_shop_inventory("seed_shop"):
		if row["item_id"] == &"carrot_seeds":
			carrot = row
	var g: int = eco.gold
	t.expect(shop.get_buy_price("seed_shop", &"carrot_seeds") == 20 and int(carrot["price"]) == 20 and shop.get_buy_total("seed_shop", &"carrot_seeds", 3) == 60, "carrot seeds are listed at 20, three cost 60")
	var w := _watch(["item_purchased", "item_gained", "gold_changed"])
	t.expect(shop.buy_item("seed_shop", &"carrot_seeds", 3) and g - eco.gold == 60 and eco.count_item(&"carrot_seeds") == 3, "buying three takes 60 and gives three")
	t.expect(_args(w, "item_purchased") == [[&"carrot_seeds", 3, 60]] and _count(w, "item_gained") == 1, "item_purchased(item, 3, 60) and one item_gained")
	_unwatch(w)
	t.expect(not shop.buy_item("seed_shop", &"carrot_seeds", 0) and shop.last_refusal == &"invalid_amount" and not shop.buy_item("seed_shop", &"carrot_seeds", -2), "an amount <= 0 is refused")
	t.expect(not shop.buy_item("seed_shop", &"wood", 1) and shop.last_refusal == &"not_offered" and not shop.buy_item("no_such_shop", &"wood", 1) and shop.last_refusal == &"unknown_shop", "an item the shop does not sell and an unknown shop are refused")
	# gold: refused, nothing changes
	eco.spend_gold(eco.gold - 10)
	var inv_before := _inv()
	t.expect(not shop.buy_item("seed_shop", &"pumpkin_seeds", 1) and shop.last_refusal == &"no_gold" and eco.gold == 10 and _inv() == inv_before, "not enough gold: refused, gold and backpack unchanged")
	# sell: min 1, special / quest / keepsakes refused
	eco.add_gold(5000)
	eco.add_item(&"fern", 3, true)
	eco.add_item(&"turnip", 4, true)
	var gold_before: int = eco.gold
	t.expect(shop.get_sell_price("seed_shop", &"turnip") == 45 and shop.get_sell_price("seed_shop", &"fern") == 1, "sell prices: a turnip 45, a fern 1")
	var sw := _watch(["item_sold"])
	t.expect(shop.sell_item("seed_shop", &"turnip", 4) and eco.gold - gold_before == 180 and eco.count_item(&"turnip") == 0 and _args(sw, "item_sold") == [[&"turnip", 4, 180]], "selling 4 turnips pays 180 and fires item_sold(turnip, 4, 180)")
	_unwatch(sw)
	t.expect(not shop.sell_item("seed_shop", &"turnip", 1) and shop.last_refusal == &"not_owned", "selling what you do not have is refused (not_owned)")
	t.expect(not shop.sell_item("seed_shop", &"fern", 4) and eco.count_item(&"fern") == 3 and shop.last_refusal == &"not_owned", "selling more than you have is refused and takes nothing")
	var special_ok := true
	eco.add_item(&"friendship_token", 1, true)
	eco.add_item(&"flower_necklace", 1, true)
	for id in [&"friendship_token", &"flower_necklace", &"fixture_worthless", &"no_such_item"]:
		special_ok = special_ok and shop.get_sell_price("seed_shop", id) == 0 and not shop.can_sell("seed_shop", id)
	t.check("sell_unsellable", special_ok and not shop.sell_item("seed_shop", &"friendship_token", 1) and eco.count_item(&"friendship_token") == 1, "special and quest items and items with sell price 0 cannot be sold")
	# min 1 with a tiny multiplier; buys filter
	var zero_pay: Array[String] = []
	for sid in lr.get_shops():
		if str(sid).begins_with("fixture_"):
			continue
		var shop_def: Dictionary = lr.get_shop(str(sid))
		var buys: Array = LuaData.strings(shop_def.get("buys", []))
		if LuaData.num(shop_def.get("sell_multiplier", 1.0), 1.0) <= 0.0:
			continue
		for id in _item_ids():
			var category := str(lr.get_item_def(id).get("category", ""))
			if eco.sell_value(StringName(str(id))) > 0 and (buys.is_empty() or category in buys) and shop.get_sell_price(str(sid), StringName(str(id))) < 1:
				zero_pay.append("%s sells %s for 0" % [sid, id])
	t.check("sell_min_one", shop.get_sell_price("fixture_rotating", &"fern") == 1 and shop.get_sell_price("fixture_rotating", &"fixture_sell_one") == 1 and shop.get_sell_price("fixture_rotating", &"moonstone") == 0 and shop.get_sell_price("seed_shop", &"stone") >= 1 and shop.get_sell_price("seed_shop", &"friendship_token") == 0 and zero_pay.is_empty(), "a sell multiplier of 0.1 still pays at least 1 (fern 1 x 0.1, a 1-gold item), the stone is never worth 0, no shop pays 0 for a sellable item (%s), the shop's `buys` (resource, forage) excludes gems (%d / %d / %d)" % [str(zero_pay.slice(0, 3)), shop.get_sell_price("fixture_rotating", &"fern"), shop.get_sell_price("fixture_rotating", &"fixture_sell_one"), shop.get_sell_price("fixture_rotating", &"moonstone")])
	t.expect(shop.get_sell_price("fixture_rotating", &"wood") == 1 and shop.get_sell_price("seed_shop", &"fixture_sell_one") == 1, "wood (sell 2 x 0.1) and an item that sells for 1 both pay 1")
	t.expect(eco.sell_value(&"fixture_no_sell_price") == 20 and shop.get_sell_price("seed_shop", &"fixture_no_sell_price") == 20, "an item without sell_price sells for buy_price x economy.sell_price_ratio (40 x 0.5 = 20)")
	t.expect(shop.get_sell_price("fixture_nobuy", &"turnip") == 0 and not shop.sell_item("fixture_nobuy", &"turnip", 1), "a shop with sell_multiplier 0 buys nothing")
	t.expect(shop.get_sell_price("builder_yard", &"wood") == 0 and shop.get_sell_price("builder_yard", &"amethyst") > 0, "builder_yard buys materials and gems only: wood no, amethyst yes")
	# the sell list is the backpack seen through the shop
	eco.add_item(&"amethyst", 2, true)
	eco.add_item(&"wood", 3, true)
	var list: Array = shop.get_sell_list("builder_yard")
	var ids: Array = []
	for r in list:
		ids.append(str(r["item_id"]))
	var amethyst_row: Dictionary = {}
	for r in list:
		if r["item_id"] == &"amethyst":
			amethyst_row = r
	t.expect(not ids.has("wood") and not ids.has("friendship_token") and ids.has("amethyst") and amethyst_row["amount"] == 2 and amethyst_row["price"] == 90 and eco.count_item(&"wood") > 0, "get_sell_list filters EconomyManager.list_sellable by the shop: wood is in the backpack but not on the builder yard's list, amethyst is (%s)" % str(ids))
	t.expect(shop.get_sell_list("seed_shop").size() > ids.size() and shop.get_sell_list("no_such_shop").is_empty(), "the seed shop buys more of the backpack than the builder yard; an unknown shop buys nothing")
	# the equip rule: selling the equipped tool re-equips
	eco.add_item(&"axe_wooden", 1, true)
	t.expect(shop.sell_item("seed_shop", &"axe_wooden", 1) and shop.get_sell_price("seed_shop", &"axe_wooden") == 25, "a spare axe sells for 25")
	# no loop even at the biggest discount: the best price of every stocked item is above the sell price
	var loop: Array[String] = []
	var gear := _fake(FakeGear.new()) as FakeGear
	gear.discount = 0.15
	Svc.override("WardrobeManager", gear)
	gm.set("character_type", 2)
	for sid in lr.get_shops():
		if str(sid).begins_with("fixture_"):
			continue
		for row in shop.get_shop_inventory(str(sid)):
			var sell := int(shop.get_sell_price(str(sid), row["item_id"]))
			if sell > 0 and int(row["price"]) <= sell:
				loop.append("%s.%s %d <= %d" % [sid, row["item_id"], row["price"], sell])
	_release_fakes()
	gm.set("character_type", 0)
	t.check("no_buy_sell_loop", loop.is_empty(), "with the largest discount (20 percent) every shop still sells dearer than it buys back: %s" % str(loop.slice(0, 4)))


func _stock_and_days() -> void:
	_fresh()
	_force_fallback()
	eco.add_gold(20000)
	t.expect(shop.buy_item("seed_shop", &"moonflower_seeds", 8) and eco.count_item(&"moonflower_seeds") == 8, "the shelf of moonflower seeds (8) can be emptied")
	t.expect(not shop.buy_item("seed_shop", &"moonflower_seeds", 1) and shop.last_refusal == &"no_stock", "sold out: refused with no_stock")
	var row := _row("seed_shop", &"moonflower_seeds")
	t.expect(int(row["stock"]) == 0 and not bool(row["buyable"]) and int(row["max_stock"]) == 8, "the row says stock 0, not buyable")
	gm.end_day()
	t.expect(int(_row("seed_shop", &"moonflower_seeds")["stock"]) == 4, "the next morning 4 are back (restock 4)")
	gm.end_day()
	gm.end_day()
	t.check("stock_refreshes_on_day_started", int(_row("seed_shop", &"moonflower_seeds")["stock"]) == 8 and int(_row("seed_shop", &"fertilizer")["stock"]) == 30, "after two more mornings the shelf is full again and never above its maximum (8, fertilizer 30)")
	# a shelf without restock is full again every morning
	t.expect(shop.buy_item("seed_shop", &"fertilizer", 30) and int(_row("seed_shop", &"fertilizer")["stock"]) == 0, "fertilizer sold out")
	gm.end_day()
	t.expect(int(_row("seed_shop", &"fertilizer")["stock"]) == 30, "fertilizer is back at 30 (restock = full)")
	# shop save round trip
	shop.buy_item("seed_shop", &"pumpkin_seeds", 5)
	var saved: Dictionary = shop.to_dict()
	var parsed: Variant = SaveCodec.through_json(saved)
	t.new_game()
	t.expect(int(_row("seed_shop", &"pumpkin_seeds")["stock"]) == 15, "a new game fills every shelf")
	t.expect(shop.from_dict(parsed as Dictionary) and int(_row("seed_shop", &"pumpkin_seeds")["stock"]) == 10 and int(_row("seed_shop", &"moonflower_seeds")["stock"]) == 8, "the shelves come back from a save (pumpkin seeds 10)")
	shop.from_dict({"stock": {"seed_shop": {"pumpkin_seeds": 999, "ghost": 3}, "no_shop": {"x": 1}}})
	t.check("shop_save_validated", int(_row("seed_shop", &"pumpkin_seeds")["stock"]) == 15 and int(_row("seed_shop", &"carrot_seeds")["stock"]) == 25 and not shop.to_dict()["stock"].has("no_shop") and not shop.to_dict()["stock"]["seed_shop"].has("ghost"), "counts are clamped to the shelf, unknown shops and items are dropped, missing shelves are full")

	# the order's behaviour: shelves restock on day_started and on nothing else; the first plan's knob `economy.shop_refresh_hour`
	# ("restock when this hour is reached") is read by no code, so it is a dead tuning knob that P10 deletes (handoff)
	eco.add_gold(5000)
	shop.buy_item("seed_shop", &"moonflower_seeds", 8)
	gm.set("hour", 5)
	bus.time_of_day_changed.emit(5, 0)
	gm.set("hour", 8)
	bus.time_of_day_changed.emit(8, 0)
	gm.advance_time(60)
	var still_empty: bool = int(_row("seed_shop", &"moonflower_seeds")["stock"]) == 0
	gm.end_day()
	var back: bool = int(_row("seed_shop", &"moonflower_seeds")["stock"]) == 4
	var reads: Array[String] = []
	for path in ["res://scripts/economy/shop_system.gd", "res://scripts/autoload/economy_manager.gd", "res://scripts/economy/crafting_system.gd"]:
		var n := 1
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.strip_edges().begins_with("#") and line.contains("shop_refresh_hour"):
				reads.append("%s:%d" % [path.get_file(), n])
			n += 1
	var wired: bool = bus.day_started.get_connections().any(func(c: Dictionary) -> bool: return c["callable"].get_object() == shop)
	t.check("restock_on_day_started_only", still_empty and back and wired and reads.is_empty(), "passing hour 8 (the knob's value) restocks nothing, the next day_started brings the restock back (4 moonflower seeds); ShopSystem is connected to day_started and no code reads economy.shop_refresh_hour %s" % str(reads))
	if lr.get_config("economy.shop_refresh_hour", null) != null:
		t.skip("lua/config/game_balance.lua (P10) still defines economy.shop_refresh_hour, which nothing reads: the lead deletes it together with its name in tests/sections/data.gd (handoff of P12 fix round 2)")



func _row(shop_id: String, item_id: StringName) -> Dictionary:
	for row in shop.get_shop_inventory(shop_id):
		if row["item_id"] == item_id:
			return row
	return {}


# ================================================================================================ rotation and the price curve

## ShopSystem reaches ShopRotation / PriceCurve through Svc.static_call and nothing else (RV-P10, the order's wording): no helper of
## its own that loads scripts. Against REAL probe scripts under user:// (set_late_scripts): a static stock() / final_price() with the
## contract's arguments drives the offer and the price (listed == charged), a missing script, a missing method and an instance
## method all answer the fallback without an engine message. A static function with ANOTHER number of arguments is a contract
## violation and is deliberately not guarded (it is F4's loud failure), so it is not probed here.
func _late_binding() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/economy/shop_system.gd")
	var code_lines: Array[String] = []
	for line in source.split("\n"):
		var text := line.strip_edges()
		if not text.begins_with("#") and not text.begins_with("##"):
			code_lines.append(text)
	var code := "\n".join(code_lines)
	var bare := code.replace("preload(", "")
	var calls := 0
	for line in code_lines:
		calls += 1 if line.contains("static_call(") else 0
	t.check("late_binding_via_svc", calls == 2 and code.contains("static_call(_rotation_script, &\"stock\"") and code.contains("static_call(_curve_script, &\"final_price\"") and not code.contains("ResourceLoader") and not bare.contains("load(") and not code.contains("get_script_method_list") and not code.contains("callv(") and not source.contains("_static_checked") and not source.contains("_signature_fits"), "shop_system.gd calls ShopRotation.stock and PriceCurve.final_price through Svc.static_call (%d call sites), with no load / ResourceLoader / callv / signature helper of its own" % calls)
	var rotation_path := "user://p12_probe_rotation.gd"
	var curve_path := "user://p12_probe_curve.gd"
	var instance_path := "user://p12_probe_instance.gd"
	var files := {
		rotation_path: "extends RefCounted\nstatic func stock(shop_id: String) -> Array:\n\treturn [{\"item\": \"cookie\", \"stock\": 2, \"slot\": \"daily\"}, {\"item\": \"wood\", \"stock\": 1, \"price\": 8}]\n",
		curve_path: "extends RefCounted\nstatic func final_price(shop_id: String, item_id: String, base_price: int) -> int:\n\treturn base_price * 3 + 1\n",
		instance_path: "extends RefCounted\nfunc stock(shop_id: String) -> Array:\n\treturn [{\"item\": \"cookie\", \"stock\": 9}]\nfunc final_price(shop_id: String, item_id: String, base_price: int) -> int:\n\treturn 1\n",
	}
	for path in files:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(files[path])
		f.close()
	_fresh()
	eco.add_gold(50000)
	var mark: int = t.log_mark()
	# 1. real static functions with the contract's signatures
	shop.set_late_scripts(rotation_path, curve_path)
	var rows: Array = shop.get_shop_inventory("fixture_rotating")
	var by := {}
	for r in rows:
		by[str(r["item_id"])] = r
	var cookie_listed: int = int(by["cookie"]["price"]) if by.has("cookie") else -1
	t.check("late_binding_real_scripts", rows.size() == 3 and by.has("cookie") and by["cookie"]["source"] == "rotation" and by["cookie"]["slot"] == "daily" and by.has("wood") and by["wood"]["source"] == "rotation" and cookie_listed == 25 * 3 + 1 and int(by["wood"]["price"]) == 8 * 3 + 1 and int(by["lantern_oil"]["price"]) == 25 * 3 + 1, "stock(shop_id) adds the rotation rows (cookie, wood at the row's price 8) to the fixed stock; final_price(shop_id, item_id, base_price) decides every price (cookie 25 -> %d)" % cookie_listed)
	var every_ok := true
	var report: Array[String] = []
	for item_id in ["cookie", "wood", "lantern_oil"]:
		var listed: int = int(_row("fixture_rotating", StringName(item_id))["price"])
		var g: int = eco.gold
		var ok: bool = shop.buy_item("fixture_rotating", StringName(item_id), 1)
		report.append("%s %d/%d" % [item_id, listed, g - eco.gold])
		every_ok = every_ok and ok and g - eco.gold == listed
	t.expect(every_ok and shop.get_buy_total("fixture_rotating", &"cookie", 1) == 76 and int(_row("fixture_rotating", &"cookie")["stock"]) == 1, "listed == charged through the real static functions (%s); the rotation row's stock counts down" % ", ".join(report))
	# 2. a script that does not exist: the fixed stock and the fallback price
	shop.set_late_scripts("user://p12_no_such_rotation.gd", "user://p12_no_such_curve.gd")
	t.expect(shop.get_shop_inventory("fixture_rotating").size() == 1 and shop.get_buy_price("fixture_rotating", &"lantern_oil") == 50, "a missing ShopRotation / PriceCurve script: only the fixed stock, base x buy_multiplier (25 x 2.0 = 50)")
	# 3. a script that has the function as an INSTANCE method (not callable on the script): the same fallback
	shop.set_late_scripts(instance_path, instance_path)
	t.expect(shop.get_shop_inventory("fixture_rotating").size() == 1 and shop.get_buy_price("fixture_rotating", &"lantern_oil") == 50, "an instance method instead of a static one is not called: fixed stock and fallback price")
	# 4. a script without the method (the curve file has no stock(), the rotation file no final_price())
	shop.set_late_scripts(curve_path, rotation_path)
	t.expect(shop.get_shop_inventory("fixture_rotating").size() == 1 and shop.get_buy_price("fixture_rotating", &"lantern_oil") == 50, "scripts that lack the method answer the fallback")
	t.expect_clean_since(mark, "no engine message from any of the late-bound lookups")
	# 5. the contract's own paths again
	shop.set_late_scripts()
	t.expect(shop._rotation_script == shop.ROTATION_SCRIPT and shop._curve_script == shop.CURVE_SCRIPT and shop.ROTATION_SCRIPT == "res://scripts/economy/shop_rotation.gd" and shop.CURVE_SCRIPT == "res://scripts/economy/price_curve.gd", "set_late_scripts() without arguments restores the contract's paths (shop_rotation.gd, price_curve.gd)")
	for path in files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _force_curve_off() -> void:
	shop.set_price_curve_source(func(_shop_id: String, _item_id: String, _base: int) -> Variant: return null)


func _rotation_and_curve() -> void:
	_fresh()
	eco.add_gold(50000)
	# without any rotation row only the fixed stock is listed, at the fallback price
	_force_fallback()
	var rows_none: Array = shop.get_shop_inventory("fixture_rotating")
	t.expect(rows_none.size() == 1 and rows_none[0]["item_id"] == &"lantern_oil" and rows_none[0]["source"] == "fixed", "without ShopRotation only the fixed stock is listed")
	t.expect(int(rows_none[0]["price"]) == 50 and shop.get_buy_price("fixture_rotating", &"lantern_oil") == 50, "lantern oil (25) x buy_multiplier 2.0 = 50")
	# a rotation source: two more rows, one with a base price override
	shop.set_rotation_source(func(shop_id: String) -> Array:
		return [{"item": "cookie", "stock": 2, "slot": "daily"}, {"item": "wood", "stock": 3, "price": 8, "slot": "daily"}, {"item": "lantern_oil", "stock": 9}, {"item": "ghost_item", "stock": 1}])
	var rows: Array = shop.get_shop_inventory("fixture_rotating")
	var by := {}
	for r in rows:
		by[str(r["item_id"])] = r
	t.check("rotation_rows_listed", rows.size() == 3 and by.has("cookie") and by.has("wood") and by["cookie"]["source"] == "rotation" and by["cookie"]["slot"] == "daily" and by["lantern_oil"]["source"] == "fixed" and by["lantern_oil"]["max_stock"] == 3, "fixed stock, then the rotation rows; an item in both is listed once (fixed), unknown ids are not listed: %s" % str(by.keys()))
	t.expect(int(by["cookie"]["price"]) == 50 and int(by["wood"]["price"]) == 16, "rotation prices: cookie 25 x 2.0 = 50, wood with the row's price 8 x 2.0 = 16")
	# listed == charged: through the fallback and through a curve that depends on the copies owned
	_force_curve_off()
	var every_ok := true
	var report: Array[String] = []
	for item_id in ["cookie", "wood", "lantern_oil"]:
		var listed: int = int(_row("fixture_rotating", StringName(item_id))["price"])
		var g: int = eco.gold
		var ok: bool = shop.buy_item("fixture_rotating", StringName(item_id), 1)
		var charged: int = g - eco.gold
		report.append("%s %d/%d" % [item_id, listed, charged])
		if not ok or charged != listed:
			every_ok = false
	t.check("listed_equals_charged_with_rotation", every_ok, "the fallback price: listed == charged for every fixed and rotation row, rotation rows are bought too (%s)" % ", ".join(report))
	# the curve seam (PriceCurve.final_price): +10 per copy owned, listed and charged agree and the next listing moves
	shop.set_price_curve_source(func(shop_id: String, item_id: String, base: int) -> int:
		return base + 10 * int(eco.count_item(StringName(item_id))))
	var cookies: int = eco.count_item(&"cookie")
	var listed_before: int = int(_row("fixture_rotating", &"cookie")["price"])
	var g2: int = eco.gold
	t.expect(listed_before == 25 + 10 * cookies and shop.buy_item("fixture_rotating", &"cookie", 1) and g2 - eco.gold == listed_before, "with a price curve the charge is the listed price (%d)" % listed_before)
	t.expect(int(_row("fixture_rotating", &"cookie")["price"]) == listed_before + 10 and shop.get_buy_total("fixture_rotating", &"cookie", 2) == 2 * (listed_before + 10), "the next listing already shows the surcharge; the total of two is two listed prices")
	# stock of rotation rows: 2 cookies on offer, the first run bought one, one more is left, then sold out
	t.expect(int(_row("fixture_rotating", &"cookie")["stock"]) == 0 and not shop.buy_item("fixture_rotating", &"cookie", 1) and shop.last_refusal == &"no_stock", "the rotation row had 2 cookies: both gone, the third is refused")
	# a curve that answers nothing falls back
	_force_curve_off()
	t.expect(shop.get_buy_price("fixture_rotating", &"lantern_oil") == 50, "a curve source that answers null falls back to base x multiplier x discount")
	# counts of rotation rows survive the day while the item stays on offer and vanish when it leaves
	gm.end_day()
	t.expect(int(_row("fixture_rotating", &"cookie")["stock"]) == 0, "an item that is still on offer keeps its bought count over the day change")
	shop.set_rotation_source(func(_s: String) -> Array: return [{"item": "wood", "stock": 3, "price": 8}])
	gm.end_day()
	shop.set_rotation_source(func(_s: String) -> Array: return [{"item": "cookie", "stock": 2}])
	t.expect(int(_row("fixture_rotating", &"cookie")["stock"]) == 2, "an item that left the offer comes back with its full count")
	# the production path: no scripts of F4, or scripts with another signature, never break a price or a listing
	shop.set_rotation_source(Callable())
	shop.set_price_curve_source(Callable())
	var mark: int = t.log_mark()
	var natural: Array = shop.get_shop_inventory("fixture_rotating")
	t.expect(natural.size() >= 1 and shop.get_buy_price("fixture_rotating", &"lantern_oil") > 0, "the production path (late-bound ShopRotation / PriceCurve, or their absence) lists and prices the shop (%d rows)" % natural.size())
	t.expect_clean_since(mark, "the late-bound call logs no engine message")
	_late_binding()


# ================================================================================================ closed days

func _closed_weekdays() -> void:
	_fresh()
	eco.add_gold(500)
	var flea: Dictionary = lr.get_shop("flea_market")
	t.expect(not flea.is_empty() and flea.get("open_weekdays") == [5, 6], "F1's flea market is open on Saturday and Sunday only (open_weekdays 5, 6)")
	var results: Array = []
	for day in [1, 2, 3, 4, 5, 6, 7, 8]:
		gm.set("day", day)
		var info: Dictionary = shop.get_shop_info("fixture_weekend")
		results.append([day, info["closed"], shop.is_open("flea_market")])
	var expect_closed := {1: true, 2: true, 3: true, 4: true, 5: true, 6: false, 7: false, 8: true}
	var days_ok := true
	for r in results:
		days_ok = days_ok and r[1] == expect_closed[r[0]] and r[2] == (not expect_closed[r[0]])
	t.check("shop_closed_weekdays", days_ok, "day 6 (Saturday) and 7 (Sunday) open, every other weekday closed: %s" % str(results))
	gm.set("day", 3)
	var inv := _inv()
	var g: int = eco.gold
	t.expect(not shop.buy_item("fixture_weekend", &"wood", 1) and shop.last_refusal == &"closed" and eco.gold == g and _inv() == inv, "a closed shop refuses to sell (last_refusal closed) and changes nothing")
	eco.add_item(&"moss", 2, true)
	t.expect(not shop.sell_item("fixture_weekend", &"moss", 1) and shop.last_refusal == &"closed" and eco.count_item(&"moss") == 2, "a closed shop refuses to buy")
	var rows: Array = shop.get_shop_inventory("fixture_weekend")
	t.expect(rows.size() == 1 and not bool(rows[0]["buyable"]), "the closed shop still lists its stock, but nothing is buyable")
	gm.set("day", 6)
	t.expect(shop.buy_item("fixture_weekend", &"wood", 2) and eco.count_item(&"wood") >= 2 and int(_row("fixture_weekend", &"wood")["price"]) == 7, "on Saturday the same shop sells (price override 7)")
	t.expect(shop.sell_item("fixture_weekend", &"moss", 1) and eco.count_item(&"moss") == 1, "and buys")
	gm.set("day", 1)
	t.expect(shop.open_shop("fixture_weekend"), "open_shop still emits shop_opened on a closed day: the screen shows SHOP_UI_CLOSED_TODAY itself")


# ================================================================================================ garments and keepsakes in shops

func _garments_and_keepsakes_in_shops() -> void:
	_fresh()
	eco.add_gold(20000)
	_force_fallback()
	var wardrobe := _fake(FakeStore.new()) as FakeStore
	wardrobe.max_copies = 1
	Svc.override("WardrobeManager", wardrobe)
	var tailor: Dictionary = lr.get_shop("tailor_shop")
	t.expect(not tailor.is_empty() and tailor["stock"].has("shirt_linen_cream"), "F1's tailor stocks shirt_linen_cream")
	var row := _row("tailor_shop", &"shirt_linen_cream")
	t.expect(not row.is_empty() and not bool(row["already_owned"]) and bool(row["buyable"]), "an unowned garment is buyable")
	t.expect(shop.buy_item("tailor_shop", &"shirt_linen_cream", 1) and wardrobe.owned[&"shirt_linen_cream"] == 1, "buying a garment puts it into the wardrobe")
	row = _row("tailor_shop", &"shirt_linen_cream")
	var g: int = eco.gold
	t.check("garment_owned_not_buyable", bool(row["already_owned"]) and not bool(row["buyable"]) and not shop.buy_item("tailor_shop", &"shirt_linen_cream", 1) and shop.last_refusal == &"owned" and eco.gold == g, "a garment the player owns cannot be bought again (row.already_owned, last_refusal owned, no gold taken)")
	# the shops keep unique and legendary pieces out of every list and price
	var legend := ""
	for id in _item_ids():
		if str(lr.get_item_def(id).get("rarity", "")) == "legendary":
			legend = str(id)
			break
	var legend_rows: Array = shop.get_shop_inventory("fixture_legend_shop")
	var listed: Array = []
	for r in legend_rows:
		listed.append(str(r["item_id"]))
	t.check("keepsakes_not_in_shops", legend != "" and not listed.has(legend) and shop.get_buy_price("fixture_legend_shop", StringName(legend)) == 0 and not shop.buy_item("fixture_legend_shop", StringName(legend), 1) and shop.get_sell_price("fixture_legend_shop", StringName(legend)) == 0, "a legendary item put into a shop's stock is never listed, priced, bought or sold (%s)" % legend)
	var bad: Array[String] = []
	for sid in lr.get_shops():
		for r in shop.get_shop_inventory(str(sid)):
			if Rarity.is_one_of_a_kind(r["rarity"]):
				bad.append("%s.%s" % [sid, r["item_id"]])
	t.expect(bad.is_empty(), "no shop lists a unique or legendary item: %s" % str(bad))
	# tabs of the home shops pass through and filter
	var furniture_tabs: Array = shop.get_shop_tabs("furniture_shop")
	var sleep_tab: Dictionary = {}
	var hat_tab: Dictionary = {}
	for tb in furniture_tabs:
		if tb["id"] == "sleep":
			sleep_tab = tb
	for tb in shop.get_shop_tabs("tailor_shop"):
		if tb["id"] == "hat":
			hat_tab = tb
	t.check("tabs_pass_through", not sleep_tab.is_empty() and shop.item_in_tab(sleep_tab, &"bed_pine") and not shop.item_in_tab(sleep_tab, &"chair_pine") and not hat_tab.is_empty() and shop.item_in_tab(hat_tab, &"hat_cap_brown") and not shop.item_in_tab(hat_tab, &"shirt_linen_cream") and furniture_tabs[furniture_tabs.size() - 1]["sell"], "furniture_types and slots tabs of the home shops filter items; the sell tab comes last")
	_release_fakes()


func _refund_and_lua_api() -> void:
	_fresh()
	_force_fallback()
	eco.add_gold(5000)
	# a store that refuses the piece AFTER the gold was taken: the gold comes back, nothing is bought
	var furniture := _fake(FakeStore.new()) as FakeStore
	furniture.max_copies = 0
	Svc.override("FurnitureManager", furniture)
	var g: int = eco.gold
	var stock_before: int = int(_row("furniture_shop", &"bed_pine")["stock"])
	var w := _watch(["item_purchased", "item_gained"])
	t.check("buy_refund_on_failure", not shop.buy_item("furniture_shop", &"bed_pine", 1) and eco.gold == g and _count(w, "item_purchased") == 0 and _count(w, "item_gained") == 0 and int(_row("furniture_shop", &"bed_pine")["stock"]) == stock_before and shop.last_refusal == &"no_room", "the furniture store takes no more: gold %d unchanged, the shelf unchanged, no item_purchased, last_refusal no_room" % eco.gold)
	_unwatch(w)
	# the same through EconomyManager.buy_item itself (what a refunded add looks like to the HUD)
	var g2: int = eco.gold
	t.expect(not eco.buy_item(&"bed_pine", 1, 150) and eco.gold == g2, "EconomyManager.buy_item refunds when the add fails")
	_release_fakes()
	# Lua's api goes through the same validation: api.add_item(id, 0) / (id, -2) do nothing, api.remove_item(id, 0) is false
	var before := _inv()
	lr.lua_add_item("wood", 0)
	lr.lua_add_item("wood", -4)
	t.check("lua_amounts_validated", _inv() == before and not lr.lua_remove_item("wood", 0) and not lr.lua_remove_item("wood", -1) and not lr.lua_has_item("wood", 0), "the Lua api refuses amounts <= 0 (add, remove, has)")
	lr.lua_add_item("wood", 3)
	t.expect(lr.lua_has_item("wood", 3) and lr.lua_remove_item("wood", 2) and eco.count_item(&"wood") == 1, "and works with real amounts")


# ================================================================================================ the discount

func _discount_single_owner() -> void:
	_fresh()
	_force_fallback()
	var gear := _fake(FakeGear.new()) as FakeGear
	Svc.override("WardrobeManager", gear)
	var price := func() -> int: return int(shop.get_buy_price("fixture_curve_shop", &"fixture_rare"))
	# the fallback path (no PriceCurve): base x (1 - Perks.total(discount))
	t.expect(price.call() == 1600, "a fox without gear pays the full 1600")
	gear.discount = 0.10
	t.expect(price.call() == 1440, "fox with gear .10: 1440")
	gm.set("character_type", 2)
	t.expect(price.call() == 1280, "hobbit with the same gear: 1280 (race .10 + gear .10 = the .20 cap)")
	gear.discount = 0.0
	t.expect(price.call() == 1440 and price.call() != 1296, "hobbit alone: 1440 - the hobbit's 10 percent is counted ONCE (not 1296)")
	gear.discount = 0.15
	t.expect(price.call() == 1280, "hobbit + gear .15 stays at the .20 cap: 1280")
	# the PriceCurve contract: the same discount owner plus 10 friend hearts (.05)
	shop.set_price_curve_source(func(_s: String, _i: String, base: int) -> int: return Perks.discounted_price(base, 0.05))
	gm.set("character_type", 0)
	gear.discount = 0.10
	var fox := int(price.call())
	gm.set("character_type", 2)
	var hobbit_with_gear := int(price.call())
	gear.discount = 0.0
	var hobbit_alone := int(price.call())
	shop.set_price_curve_source(func(_s: String, _i: String, base: int) -> int: return Perks.discounted_price(base, 0.0))
	var hobbit_alone_no_friends := int(price.call())
	t.check("discount_single_owner_numeric", fox == 1360 and hobbit_with_gear == 1280 and hobbit_alone_no_friends == 1440 and hobbit_alone == 1360, "1600-gold rare piece: fox gear .10 + 10 hearts .05 pays %d (1360), the same hobbit %d (1280), hobbit alone %d (1440)" % [fox, hobbit_with_gear, hobbit_alone_no_friends])
	_force_fallback()
	# structural: no code line of the shop or the economy applies a hobbit / shop_discount factor of its own
	var offenders: Array[String] = []
	for path in ["res://scripts/economy/shop_system.gd", "res://scripts/autoload/economy_manager.gd", "res://scripts/economy/crafting_system.gd"]:
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			if code.contains("shop_discount") or code.to_lower().contains("hobbit"):
				offenders.append("%s:%d" % [path.get_file(), n])
			n += 1
	t.expect(offenders.is_empty(), "no code line of shop_system.gd / economy_manager.gd / crafting_system.gd names a hobbit or shop_discount factor: %s" % str(offenders))
	# the price listed in every shop equals the price charged, for a fox and for a hobbit
	var all_races_ok := true
	var all_tested := 0
	for race in [0, 2]:
		gm.set("character_type", race)
		eco.reset()
		eco.add_gold(900000)
		var mismatches: Array[String] = []
		var closed: int = 0
		var tested: int = 0
		for sid in lr.get_shops():
			if str(sid).begins_with("fixture_"):
				continue
			shop.reset()
			for r in shop.get_shop_inventory(str(sid)):
				if not bool(r["buyable"]):
					if not bool(r["already_owned"]):
						closed += 1
					continue
				var id: StringName = r["item_id"]
				var before: int = eco.gold
				var ok: bool = shop.buy_item(str(sid), id, 1)
				tested += 1
				if ok:
					if before - eco.gold != int(r["price"]):
						mismatches.append("%s.%s listed %d charged %d" % [sid, id, r["price"], before - eco.gold])
					eco.remove_item(id, 1)
				elif shop.last_refusal != &"no_room":
					mismatches.append("%s.%s refused: %s" % [sid, id, shop.last_refusal])
		var race_ok: bool = mismatches.is_empty() and tested >= 80
		all_races_ok = all_races_ok and race_ok
		all_tested += tested
		t.check("listed_equals_charged_race_%d" % race, race_ok, "every item of every shop: listed price == charged price (%s; %d rows bought, %d not buyable today); %s" % ["fox" if race == 0 else "hobbit", tested, closed, str(mismatches.slice(0, 4))])
	# the plan's name (8.2 row 9, the legacy `shop price mismatch` bug): one verdict over both races and every shop
	t.check("listed_equals_charged", all_races_ok, "shop buy works: every buyable row of every shop was bought for real as a fox and as a hobbit, and the gold taken was the listed price each time (%d purchases)" % all_tested)
	gm.set("character_type", 0)
	shop.set_price_curve_source(Callable())
	shop.set_rotation_source(Callable())
	_release_fakes()


# ================================================================================================ crafting

func _crafting() -> void:
	_fresh()
	var recipes: Array = CraftingSystem.get_recipes()
	var ids: Array = []
	for r in recipes:
		ids.append(str(r["id"]))
	for expected in ["mushroom_lantern", "scarecrow", "honey_cake", "pickaxe_copper", "lantern_post", "fence", "iron_ingot", "flower_necklace"]:
		t.expect(ids.has(expected), "recipe %s is loaded from lua/recipes" % expected)
	t.expect(CraftingSystem.get_recipes("bake").size() >= 1 and CraftingSystem.get_recipes("forge").size() >= 1 and CraftingSystem.get_recipes("craft").size() >= 6 and CraftingSystem.get_recipes("nothing").is_empty(), "get_recipes(category) filters (craft, bake, forge)")
	# every recipe's ingredients and outputs are defined items; names resolve
	var undefined: Array[String] = []
	var unnamed: Array[String] = []
	for r in recipes:
		for item_id in r.get("ingredients", {}):
			if lr.get_item_def(str(item_id)).is_empty():
				undefined.append("%s needs %s" % [r["id"], item_id])
		if lr.get_item_def(str(r.get("output", {}).get("item", ""))).is_empty():
			undefined.append("%s makes %s" % [r["id"], r.get("output", {}).get("item", "")])
		if str(r["category"]) not in ["craft", "bake", "forge"]:
			unnamed.append("%s category %s" % [r["id"], r["category"]])
	t.check("recipes_use_defined_items", undefined.is_empty() and unnamed.is_empty(), "%d recipes: every ingredient and output is a defined item, categories valid; %s %s" % [recipes.size(), str(undefined.slice(0, 4)), str(unnamed.slice(0, 3))])
	# the guide: honey cake, "Mangler mel"; copper pickaxe, "Mangler 2 kobber"
	var cake: Dictionary = CraftingSystem.can_craft("honey_cake")
	t.expect(not cake["ok"] and cake["missing"].size() == 3 and cake["locked"].is_empty() and not cake["unknown"], "honey cake with nothing in the backpack: three ingredients missing")
	eco.add_item(&"honey", 1, true)
	eco.add_item(&"egg", 1, true)
	eco.add_item(&"flour", 1, true)
	cake = CraftingSystem.can_craft("honey_cake")
	t.check("missing_flour", cake["missing"] == [{"item": "flour", "have": 1, "need": 2}], "'Mangler mel': %s" % str(cake["missing"]))
	eco.add_item(&"copper_ore", 1, true)
	eco.add_item(&"wood", 2, true)
	var pick: Dictionary = CraftingSystem.can_craft("pickaxe_copper")
	t.expect(pick["missing"] == [{"item": "copper_ore", "have": 1, "need": 3}] and (pick["missing"][0]["need"] - pick["missing"][0]["have"]) == 2, "'Mangler 2 kobber': the copper pickaxe needs 3 copper ore, 1 is there")
	t.expect(not CraftingSystem.craft("pickaxe_copper") and eco.count_item(&"copper_ore") == 1 and eco.count_item(&"wood") == 2, "crafting without everything changes nothing")
	t.expect(CraftingSystem.can_craft("no_such_recipe")["unknown"] and not CraftingSystem.craft("no_such_recipe"), "an unknown recipe cannot be crafted")
	# craft consumes and produces exactly
	eco.add_item(&"copper_ore", 4, true)
	eco.add_item(&"wood", 3, true)
	var w := _watch(["recipe_crafted", "item_gained"])
	t.expect(CraftingSystem.craft("pickaxe_copper"), "the copper pickaxe is crafted")
	t.check("craft_exact", eco.count_item(&"copper_ore") == 2 and eco.count_item(&"wood") == 3 and eco.count_item(&"pickaxe_copper") == 1 and _args(w, "recipe_crafted") == [[&"pickaxe_copper", 1]] and _count(w, "item_gained") == 1, "3 ore and 2 wood gone, one pickaxe in, recipe_crafted(pickaxe_copper, 1) once, one item_gained")
	t.expect(eco.get_tool_power("pickaxe") == 2, "the crafted pickaxe is equipped by its power")
	eco.add_item(&"wood", 4, true)
	t.expect(CraftingSystem.craft("fence") and eco.count_item(&"fence") == 4 and eco.count_item(&"wood") == 3, "fence: 4 wood make 4 fences (output amount 4)")
	t.expect(_args(w, "recipe_crafted").back() == [&"fence", 4], "recipe_crafted carries the amount produced")
	_unwatch(w)
	# all or nothing: no room for the output -> the ingredients come back
	_fresh()
	_empty_backpack()
	eco.add_item(&"copper_ore", 99, true)
	eco.add_item(&"wood", 99, true)
	eco.add_item(&"stone", 99 * 22, true)
	t.expect(eco.free_slots() == 0, "setup: a full backpack whose ingredient stacks stay occupied")
	var w2 := _watch(["recipe_crafted"])
	t.check("craft_full_rolls_back", not CraftingSystem.craft("pickaxe_copper") and eco.count_item(&"copper_ore") == 99 and eco.count_item(&"wood") == 99 and _count(w2, "recipe_crafted") == 0, "no room for the pickaxe: ingredients restored (99 / 99), nothing crafted")
	_unwatch(w2)


func _stations_and_blueprints() -> void:
	_fresh()
	var mark: int = t.log_mark()
	# the station tiers come from lua/data/home_tiers.lua (workbench 1, loom 3, forge bench 5)
	t.expect(CraftingSystem.station_tier("snedkerbord") == 1 and CraftingSystem.station_tier("vaev") == 3 and CraftingSystem.station_tier("smedje") == 5, "the stations unlock with the home: workbench tier 1, loom tier 3, forge bench tier 5")
	var forge: Dictionary = CraftingSystem.get_recipe("forge_copper_plate")
	t.expect(not forge.is_empty() and forge["station"] == "smedje" and CraftingSystem.required_tier(forge) == 5 and CraftingSystem.get_recipes("", "smedje").size() >= 2, "F1's forge recipes carry station smedje and tier 5; get_recipes(station) filters")
	t.expect(CraftingSystem.required_tier(CraftingSystem.get_recipe("fixture_station_only")) == 3, "a recipe with a station and no min_home_tier needs the station's tier (loom: 3)")
	eco.add_item(&"copper_ore", 6, true)
	gm.set_flag(&"home_tier", 1)
	var low: Dictionary = CraftingSystem.can_craft("forge_copper_plate")
	t.check("stations_locked_by_tier", not low["ok"] and low["locked"] == {"reason": "tier", "need": 5} and low["missing"].is_empty() and not CraftingSystem.craft("forge_copper_plate"), "home tier 1: the forge recipe is locked {reason: tier, need: 5}")
	gm.set_flag(&"home_tier", 4)
	t.expect(CraftingSystem.can_craft("forge_copper_plate")["locked"] == {"reason": "tier", "need": 5}, "tier 4 is still too low")
	gm.set_flag(&"home_tier", 5)
	t.expect(CraftingSystem.can_craft("forge_copper_plate")["ok"] and CraftingSystem.craft("forge_copper_plate") and eco.count_item(&"copper_plate") == 1 and eco.count_item(&"copper_ore") == 3, "tier 5: copper plate is forged (3 ore -> 1 plate)")
	# tier AND flag: tier is reported first
	gm.set_flag(&"home_tier", 1)
	t.expect(CraftingSystem.can_craft("fixture_tier_and_flag")["locked"] == {"reason": "tier", "need": 4}, "a recipe with tier and blueprint lock reports the tier first")
	gm.set_flag(&"home_tier", 4)
	t.expect(CraftingSystem.can_craft("fixture_tier_and_flag")["locked"] == {"reason": "flag", "need": "bp_fixture"}, "then the blueprint flag")
	# a real rare recipe: walnut bed needs tier 5 and bp_kongelig
	var bed: Dictionary = CraftingSystem.get_recipe("build_bed_walnut")
	t.expect(not bed.is_empty() and bed.get("unlock_flag") == "bp_kongelig" and bed.get("min_home_tier") == 5, "F1's walnut bed: tier 5, blueprint bp_kongelig")
	gm.set_flag(&"home_tier", 5)
	for need in bed["ingredients"]:
		eco.add_item(StringName(need), int(bed["ingredients"][need]), true)
	var before: Dictionary = CraftingSystem.can_craft("build_bed_walnut")
	t.expect(before["missing"].is_empty() and before["locked"] == {"reason": "flag", "need": "bp_kongelig"} and not before["ok"], "everything in the backpack but no blueprint: locked by the flag")
	# the blueprint item: using it sets the flag and uses it up; the output goes through add_item into the furniture store
	var furniture := _fake(FakeStore.new()) as FakeStore
	Svc.override("FurnitureManager", furniture)
	t.expect(eco.add_item(&"blueprint_kongelig", 1) and eco.has_item(&"blueprint_kongelig", 1), "a blueprint is an ordinary backpack item")
	var w := _watch(["game_event", "notification_posted", "recipe_crafted"])
	t.expect(eco.use_item(&"blueprint_kongelig") and bool(gm.get_flag(&"bp_kongelig", false)) and eco.count_item(&"blueprint_kongelig") == 0, "use_item on a blueprint sets its unlock_flag and consumes it")
	t.expect(_args(w, "game_event") == [[&"blueprint_learned", {"item": "blueprint_kongelig", "flag": "bp_kongelig"}]] and _count(w, "notification_posted") == 1, "a game_event and a toast tell the player")
	var after: Dictionary = CraftingSystem.can_craft("build_bed_walnut")
	t.check("stations_and_blueprints", after["ok"] and CraftingSystem.craft("build_bed_walnut") and furniture.owned.get(&"bed_walnut") == 1 and not _inv().has("bed_walnut") and _args(w, "recipe_crafted") == [[&"build_bed_walnut", 1]], "with the flag the rare bed is crafted; the output lands in the furniture store: %s" % str(furniture.owned))
	_unwatch(w)
	# the rare recipe refuses a second craft when the ingredients are gone
	t.expect(not CraftingSystem.can_craft("build_bed_walnut")["ok"] and not CraftingSystem.can_craft("build_bed_walnut")["missing"].is_empty(), "the second one needs new ingredients")
	t.expect_clean_since(mark, "locked recipes and blueprints log no engine message")
	gm.clear_flag(&"home_tier")
	gm.clear_flag(&"bp_kongelig")
	_release_fakes()


func _bake_bonus() -> void:
	_fresh()
	gm.set("character_type", 2)
	t.expect(is_equal_approx(CraftingSystem.bake_bonus_chance(), 0.25), "the hobbit's bake_bonus is 0.25")
	CraftingSystem.seed_rng(20261013)
	var w := _watch(["recipe_crafted"])
	var runs := 2000
	var doubles := 0
	for i in runs:
		eco.add_item(&"flour", 2, true)
		eco.add_item(&"honey", 1, true)
		eco.add_item(&"egg", 1, true)
		if not CraftingSystem.craft("honey_cake"):
			t.fail("honey cake craft %d failed" % i)
			break
		eco.remove_item(&"honey_cake", eco.count_item(&"honey_cake"))
	for a in _args(w, "recipe_crafted"):
		doubles += 1 if int(a[1]) == 2 else 0
	var share := float(doubles) / float(runs)
	var sigma := sqrt(0.25 * 0.75 / float(runs))
	t.check("bake_bonus_statistical", absf(share - 0.25) <= 3.5 * sigma and _count(w, "recipe_crafted") == runs, "hobbit: %d of %d honey cakes came out doubled = %.3f (want 0.25 +/- %.3f)" % [doubles, runs, share, 3.5 * sigma])
	_unwatch(w)
	# the same seed gives the same sequence
	CraftingSystem.seed_rng(7)
	var first: Array = []
	for i in 12:
		eco.add_item(&"flour", 2, true)
		eco.add_item(&"honey", 1, true)
		eco.add_item(&"egg", 1, true)
		CraftingSystem.craft("honey_cake")
		first.append(eco.count_item(&"honey_cake"))
		eco.remove_item(&"honey_cake", eco.count_item(&"honey_cake"))
	CraftingSystem.seed_rng(7)
	var second: Array = []
	for i in 12:
		eco.add_item(&"flour", 2, true)
		eco.add_item(&"honey", 1, true)
		eco.add_item(&"egg", 1, true)
		CraftingSystem.craft("honey_cake")
		second.append(eco.count_item(&"honey_cake"))
		eco.remove_item(&"honey_cake", eco.count_item(&"honey_cake"))
	t.expect(first == second, "seed_rng makes the bake bonus repeatable")
	# other races and other categories get nothing
	gm.set("character_type", 0)
	var plain := 0
	for i in 200:
		eco.add_item(&"flour", 2, true)
		eco.add_item(&"honey", 1, true)
		eco.add_item(&"egg", 1, true)
		CraftingSystem.craft("honey_cake")
		plain += eco.count_item(&"honey_cake") - 1
		eco.remove_item(&"honey_cake", eco.count_item(&"honey_cake"))
	t.expect(plain == 0 and CraftingSystem.bake_bonus_chance() == 0.0, "an animal or a fairy never gets the bonus")
	gm.set("character_type", 2)
	var non_bake := 0
	for i in 200:
		eco.add_item(&"wood", 4, true)
		CraftingSystem.craft("fence")
		non_bake += eco.count_item(&"fence") - 4
		eco.remove_item(&"fence", eco.count_item(&"fence"))
	t.expect(non_bake == 0, "the bonus is for the category bake only (a hobbit's fence recipe never doubles)")
	gm.set("character_type", 0)


# ================================================================================================ keys and copy

func _keys_and_copy() -> void:
	# every item of this package has its two texts in Danish and English; other packages' items are reported
	var missing_mine: Array[String] = []
	var missing_other: Array[String] = []
	for id in _item_ids():
		if str(id).begins_with("fixture_"):
			continue
		var d: Dictionary = lr.get_item_def(id)
		for key in [str(d.get("name_key", "")), str(d.get("description_key", ""))]:
			if key == "":
				continue
			for locale in ["da", "en"]:
				if loc.text_in(key, locale) == "":
					(missing_mine if _script_of(str(id)) in MY_ITEM_SCRIPTS else missing_other).append("%s(%s)" % [key, locale])
	t.check("item_keys_resolve", missing_mine.is_empty(), "every item of the economy files has ITEM_<ID> and ITEM_<ID>_DESC in da and en; missing %s" % str(missing_mine.slice(0, 6)))
	if not missing_other.is_empty():
		t.skip("items of other packages whose keys are not defined yet (animals.lua: P20's animals.csv, wave 5): %s" % str(missing_other.slice(0, 6)))
	# recipes and shops resolve
	var missing_recipes: Array[String] = []
	for r in CraftingSystem.get_recipes():
		var key := str(r.get("name_key", ""))
		if loc.text_in(key, "da") == "" or loc.text_in(key, "en") == "":
			if not (str(r["id"]).begins_with("fixture_")):
				missing_recipes.append(key)
	t.expect(missing_recipes.is_empty(), "every recipe name resolves in da and en: %s" % str(missing_recipes.slice(0, 5)))
	var guide := {"RECIPE_MUSHROOM_LANTERN": "Lygte med svampelys", "RECIPE_SCARECROW": "Fugleskræmsel", "RECIPE_HONEY_CAKE": "Honningkage", "RECIPE_PICKAXE_COPPER": "Kobberhakke"}
	var guide_ok := true
	for k in guide:
		guide_ok = guide_ok and loc.text_in(k, "da") == guide[k]
	t.expect(guide_ok, "the four guide recipes carry the guide's Danish names")
	var seeds_ok: bool = loc.text_in("ITEM_CARROT_SEEDS_DESC", "da") == "Høst efter 4 dage" and loc.text_in("ITEM_PUMPKIN_SEEDS_DESC", "da") == "Høst efter 10 dage" and loc.text_in("ITEM_STRAWBERRY_SEEDS_DESC", "da") == "Bær hele foråret" and loc.text_in("ITEM_SUNFLOWER_SEEDS_DESC", "da") == "Høst efter 7 dage" and loc.text_in("ITEM_CATNIP_SEEDS_DESC", "da") == "Elskes af katte" and loc.text_in("ITEM_MOONFLOWER_SEEDS", "da") == "Månebønne" and loc.text_in("ITEM_MOONFLOWER_SEEDS_DESC", "da") == "Gror kun om natten" and loc.text_in("ITEM_FERTILIZER_DESC", "da") == "Bedre høst" and loc.text_in("ITEM_FAIRY_DUST_WATER_DESC", "da") == "Vand ét felt i 3 dage"
	t.expect(seeds_ok, "the shop lines carry the guide's names and one-line descriptions")
	# the CSV: economy.csv is the only owner of ITEM_*, RECIPE_*, SHOP_* it defines, no collisions, no RARITY keys
	var report: Dictionary = loc.lint()
	var mine: Array[String] = []
	for issue in report["errors"]:
		if str(issue["file"]) == "economy.csv":
			mine.append("%s %s" % [issue["cat"], issue["key"]])
	var foreign_files: Array[String] = []
	var rarity_keys := 0
	var own_keys := 0
	for key in loc.all_keys():
		if loc.file_of(key) == "economy.csv":
			own_keys += 1
			if not (key.begins_with("ITEM_") or key.begins_with("RECIPE_") or key.begins_with("SHOP_")):
				foreign_files.append(key)
			if key.begins_with("RARITY_"):
				rarity_keys += 1
	var overridden: Array[String] = []
	for id in _my_ids():
		for key in [str(lr.get_item_def(id).get("name_key")), str(lr.get_item_def(id).get("description_key"))]:
			if loc.file_of(key) != "economy.csv":
				overridden.append("%s in %s" % [key, loc.file_of(key)])
	t.check("no_key_collisions", mine.is_empty() and foreign_files.is_empty() and rarity_keys == 0 and overridden.is_empty() and own_keys >= 140, "economy.csv: %d keys, 0 lint errors %s, only ITEM_/RECIPE_/SHOP_, no RARITY_, none of its item keys redefined elsewhere %s" % [own_keys, str(mine), str(overridden.slice(0, 3))])
	t.expect(FileAccess.file_exists("res://localization/economy.csv.import") and FileAccess.get_file_as_string("res://localization/economy.csv.import").contains("importer=\"keep\""), "economy.csv ships its keep-import")
	var ui_keys: Array[String] = []
	for key in ["RECIPE_MUSHROOM_LANTERN", "RECIPE_SCARECROW", "RECIPE_HONEY_CAKE", "ITEM_MUSHROOM_LANTERN", "ITEM_SCARECROW", "ITEM_HONEY_CAKE", "SHOP_BAKERY_GREETING", "SHOP_SEED_SHOP_GREETING"]:
		if loc.file_of(key) != "economy.csv":
			ui_keys.append("%s in %s" % [key, loc.file_of(key)])
	t.expect(ui_keys.is_empty(), "the rows the UI spike put into ui.csv are owned by economy.csv now: %s" % str(ui_keys))


# ================================================================================================ content that others assume

func _content_external_items() -> void:
	var must := ["copper_ore", "moonstone", "wool", "wood", "stone", "moss", "iron_ore", "gold_ore", "amethyst", "fairy_dust", "cookie", "friendship_token", "lucky_clover", "rare_mushroom", "magic_scroll"]
	var absent: Array[String] = []
	for id in must:
		if lr.get_item_def(id).is_empty():
			absent.append(id)
	# every item id named by recipes, shops, loot, home tiers and quest rewards exists
	var named := {}
	for r in CraftingSystem.get_recipes():
		if str(r["id"]).begins_with("fixture_"):
			continue
		for item_id in r.get("ingredients", {}):
			named[str(item_id)] = "recipe %s" % r["id"]
		named[str(r.get("output", {}).get("item", ""))] = "recipe %s" % r["id"]
	for sid in lr.get_shops():
		if str(sid).begins_with("fixture_"):
			continue
		for item_id in lr.get_shop(str(sid)).get("stock", {}):
			named[str(item_id)] = "shop %s" % sid
	for tier in LuaData.arr(lr.get_config("home.tiers", [])):
		var td := LuaData.dict(tier)
		for item_id in LuaData.dict(LuaData.dict(td.get("cost", {})).get("materials", {})):
			named[str(item_id)] = "home tier %s" % td.get("tier")
		for item_id in LuaData.arr(td.get("gift_items", [])):
			named[str(item_id)] = "home tier %s gift" % td.get("tier")
	_walk_item_fields(lr.get_config("loot", {}), named, "loot")
	_walk_item_fields(lr.get_config("starter_kit", {}), named, "starter kit")
	for sid in lr.get_all_script_ids():
		var script: Dictionary = lr._scripts[sid]
		if str(script.get("kind", "")) == "quest":
			var rewards := LuaData.dict(script.get("rewards", {}))
			for item_id in LuaData.dict(rewards.get("items", {})):
				named[str(item_id)] = "quest %s" % sid
	var undefined: Array[String] = []
	for id in named:
		if id != "" and lr.get_item_def(id).is_empty():
			undefined.append("%s (%s)" % [id, named[id]])
	t.check("content_external_items_exist", absent.is_empty() and undefined.is_empty(), "the %d ids the content assumes exist; %d ids named by recipes, shops, loot, home tiers and quest rewards all resolve; absent %s undefined %s" % [must.size(), named.size(), str(absent), str(undefined.slice(0, 6))])


## Every `item = "id"` string anywhere inside a nested Lua table (the loot pools, wanderers and spots) and every list of ids
## named `stock` / `placed` / `worn` / `owned` of the starter kit.
func _walk_item_fields(node: Variant, named: Dictionary, where: String) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for k in node:
			if str(k) == "item" and typeof(node[k]) == TYPE_STRING and str(node[k]) != "":
				named[str(node[k])] = where
			elif str(k) in ["stock", "owned", "placed", "worn"] and typeof(node[k]) in [TYPE_DICTIONARY, TYPE_ARRAY]:
				for item_id in node[k]:                  # a dictionary yields its ids, an array its entries
					named[str(item_id)] = where
			else:
				_walk_item_fields(node[k], named, where)
	elif typeof(node) == TYPE_ARRAY:
		for v in node:
			_walk_item_fields(v, named, where)


# ================================================================================================ cleanup

func _cleanup() -> void:
	_release_fakes()
	shop.set_rotation_source(Callable())
	shop.set_price_curve_source(Callable())
	gm.set("character_type", _restore_character)
	gm.clear_flag(&"home_tier")
	gm.clear_config_overrides()
	if _fixtures_loaded:
		lr.reload_scripts()
		for p in [FIXTURE_ITEMS, FIXTURE_SHOPS, FIXTURE_RECIPES]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	t.new_game()
	t.expect(not lr.get_all_script_ids().any(func(s: String) -> bool: return s.contains("p12_fixture")) and _inv() == _starter_backpack(), "the section leaves the real data and a fresh new game behind")
