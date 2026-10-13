class_name ContentValidator
extends RefCounted
## The Lua-level content rules the Godot harness needs (package F1), checked against what the game ITSELF loaded: LuaRuntime item defs / config / shops / recipes and
## LocalizationManager - not against a second parser.  The big offline validator (tools/features/validate, real Lua 5.4 + this runtime + art tools, 102 rules, staged) proves the
## same data from outside; this class is the part that runs INSIDE the playtest harness on every `tests/run_playtest.sh`, so a content edit that breaks a contract fails the normal gate.
##
##   var v := ContentValidator.new(); v.run(); v.errors / v.stats
## Rule groups (each appends human-readable lines to `errors`, `stats` carries the counts the section prints):
##   items            the 258 ids (130 furniture + 96 clothing + 32 materials), rarity ids, loc keys da+en, price / keepsake rules, per-category fields
##   keepsakes        30 unique + 19 legendary pieces: exactly the fixed sources the loot tables list (spot / gift / tier gift / quest / set reward / boss / wanderer), both ways
##   finds_shops      random `find` sources == the loot pools, `shop` sources == the stock / rotation pools, no keepsake in a pool or a shop
##   recipes          outputs / ingredients exist, build cost between sell and buy price, no buy -> craft -> sell money loop
##   sets_home        furniture / wardrobe sets, ten home tiers, tier gift items == loot.tier_gifts, capacity == the room of the tier (A1)
##   starter_kit      lua/data/starter_kit.lua: ids exist, normal pieces, the kit PLACES in the room of tier 1 (tests/lib/features/room_model.gd)
##   hearts           every friendship gate / gift asks <= 10 hearts of an npc that can earn them (weekly chat flag or a quest that pays)
##   shop_schedule    open_weekdays (review F1 r1): weekday indices 0..6, distinct, only the flea market has any and they are exactly Saturday + Sunday (5, 6)
##   map_markers      data/features/map_markers.json == the loot tables per area (chests / digs, creatures, unique spots, boss)
##   dialogue shops   static dialogue_shop_problems(): the shop buttons of the three builder dialogues open real shops of their speaker (the section feeds it the flag states)
##   review F1 r2     spot_requirement_problems (loot.spots.*.requires), quest_reference_problems (friendship npcs, giver, objective npcs, reward items), stack_problems (furniture max_stack 9 / keepsakes 1),
##                    shop_stock_problems (stock / restock / rotation numbers), equip_slot_problems (distinct z), voice_key_problems (voice/<speaker>/<line id>), text_literal_problems (no Danish /
##                    English literal in the Lua of this package), creature_key_problems (loot creature name keys: defined or pending behind a CSV that has not landed)
## The review checks are static functions on plain data (no autoload): tests/sections/content_features.gd also runs each one on a deliberately broken copy and expects it to report.

const FEATURE_CATEGORIES := ["furniture", "clothing", "building_material", "gem", "blueprint"]
const PLACEMENTS := ["floor", "rug", "wall", "tabletop", "ceiling"]
const CLOTHING_SLOTS := ["hat", "shirt", "pants", "dress", "shoes", "jewellery"]
const PERK_KINDS := ["speed", "energy", "luck", "discount"]
const HEART_CAP := 10
const WEEKLY_CHAT_DAYS := 7

var errors: Array[String] = []
var stats: Dictionary = {}

var _lr: Node
var _loc: Node
var _items: Dictionary = {}              # id -> def of the feature items
var _shops: Dictionary = {}
var _recipes: Dictionary = {}
var _loot: Dictionary = {}
var _home: Dictionary = {}


func run() -> void:
	_lr = Svc.node("LuaRuntime")
	_loc = Svc.node("LocalizationManager")
	if _lr == null or _loc == null:
		errors.append("LuaRuntime and LocalizationManager must exist")
		return
	for id in declared_ids():
		var d: Dictionary = _lr.get_item_def(id)
		if d.is_empty():
			err("%s is declared in lua/items but LuaRuntime has no definition for it" % id)
		elif not (str(d.get("category", "")) in FEATURE_CATEGORIES):
			err("%s: category '%s' is not a feature category" % [id, d.get("category", "")])
		else:
			_items[id] = d
	_shops = LuaData.dict(_lr.get_shops())
	_recipes = LuaData.dict(_lr.get_recipes())
	_loot = LuaData.dict(_lr.get_config("loot", {}))
	_home = LuaData.dict(_lr.get_config("home", {}))
	_check_items()
	_check_keepsakes()
	_check_finds_and_shops()
	err_all(shop_schedule_problems(_shops))
	err_all(map_marker_problems(load_map_markers(), _loot))
	_check_recipes()
	_check_sets_and_home()
	_check_starter_kit()
	_check_hearts()
	_check_second_review()


func err(msg: String) -> void:
	errors.append(msg)


func err_all(msgs: Array[String]) -> void:
	errors.append_array(msgs)


## ids the three Lua files of this package declare (a text scan: the runtime merges all items of the game, other packages add materials too), sorted
static func declared_ids() -> Array[String]:
	var out: Array[String] = []
	var rx := RegEx.create_from_string("(?m)^  ([a-z0-9_]+) = \\{")
	for f in ["furniture", "clothing", "building_materials"]:
		for m in rx.search_all(FileAccess.get_file_as_string("res://lua/items/%s.lua" % f)):
			out.append(m.get_string(1))
	out.sort()
	return out


func has_text(key: String) -> bool:
	return _loc.has_key(key) and str(_loc.text_in(key, "da")) != "" and str(_loc.text_in(key, "en")) != ""


func ids_of(category: String, rarity: String = "") -> Array[String]:
	var out: Array[String] = []
	for id in _items:
		var d: Dictionary = _items[id]
		if str(d.get("category", "")) == category and (rarity == "" or str(d.get("rarity", "")) == rarity):
			out.append(str(id))
	out.sort()
	return out


# ---------------------------------------------------------------------------------------------------------- items

func _check_items() -> void:
	var counts := {"furniture": 0, "clothing": 0, "materials": 0}
	var by_rarity := {"furniture": {}, "clothing": {}}
	for id in _items:
		var d: Dictionary = _items[id]
		var cat := str(d.get("category", ""))
		var rar := str(d.get("rarity", ""))
		counts["furniture" if cat == "furniture" else ("clothing" if cat == "clothing" else "materials")] += 1
		if not (rar in ["normal", "uncommon", "rare", "unique", "legendary"]):
			err("%s: rarity '%s' is not one of the five ladder ids" % [id, rar])
			continue
		if by_rarity.has(cat):
			by_rarity[cat][rar] = int(by_rarity[cat].get(rar, 0)) + 1
		for k in ["name_key", "description_key"]:
			if not has_text(str(d.get(k, ""))):
				err("%s: loc key %s has no da+en text" % [id, d.get(k, "<none>")])
		if d.has("hint_key") and not has_text(str(d["hint_key"])):
			err("%s: hint_key %s has no da+en text" % [id, d["hint_key"]])
		var buy := LuaData.int_of(d.get("buy_price", 0))
		var sell := LuaData.int_of(d.get("sell_price", 0))
		if Rarity.is_one_of_a_kind(rar):
			if buy != 0 or sell != 0 or d.get("protected", false) != true or LuaData.int_of(d.get("max_stack", 1), 1) != 1:
				err("%s: a %s keepsake needs buy 0, sell 0, protected and max_stack 1" % [id, rar])
		elif cat in ["furniture", "clothing"]:
			if buy <= 0 or sell <= 0 or sell >= buy or sell > int(ceil(buy * Rarity.sell_ratio(rar))) + 1:
				err("%s: prices buy %d / sell %d break the ladder rule (0 < sell < buy, sell <= %d%% of buy)" % [id, buy, sell, int(Rarity.sell_ratio(rar) * 100)])
		match cat:
			"furniture":
				_check_furniture(str(id), d)
			"clothing":
				_check_clothing(str(id), d, rar)
	stats["furniture"] = counts["furniture"]
	stats["clothing"] = counts["clothing"]
	stats["materials"] = counts["materials"]
	stats["ids"] = _items.size()
	if counts["furniture"] != 130 or counts["clothing"] != 96 or counts["materials"] != 32 or _items.size() != 258:
		err("catalogue size is %d furniture / %d clothing / %d materials (expected 130 / 96 / 32 = 258)" % [counts["furniture"], counts["clothing"], counts["materials"]])
	if by_rarity["furniture"] != {"normal": 45, "uncommon": 33, "rare": 24, "unique": 17, "legendary": 11}:
		err("furniture rarity split is %s (expected 45/33/24/17/11)" % str(by_rarity["furniture"]))
	if by_rarity["clothing"] != {"normal": 33, "uncommon": 24, "rare": 18, "unique": 13, "legendary": 8}:
		err("clothing rarity split is %s (expected 33/24/18/13/8)" % str(by_rarity["clothing"]))
	for rep in LuaData.arr(_lr.data_report):
		var text := str(LuaData.dict(rep).get("message", rep))
		for id in _items:
			if text.contains("`%s`" % id):
				err("duplicate definition of %s: %s" % [id, text])


func _check_furniture(id: String, d: Dictionary) -> void:
	if str(d.get("placeable", "")) != "home":
		err("%s: furniture is placeable = \"home\" (found '%s')" % [id, d.get("placeable", "")])
	if not (str(d.get("placement", "")) in PLACEMENTS):
		err("%s: placement '%s' is not one of %s" % [id, d.get("placement", ""), str(PLACEMENTS)])
	var fp := LuaData.arr(d.get("footprint", []))
	if fp.size() != 2 or LuaData.int_of(fp[0]) < 1 or LuaData.int_of(fp[1]) < 1:
		err("%s: footprint must be two positive ints" % id)
	if LuaData.int_of(d.get("decor", 0)) < 1:
		err("%s: decor must be >= 1" % id)
	if str(LuaData.dict(d.get("art", {})).get("template", "")) == "":
		err("%s: art.template is missing" % id)
	if str(d.get("interact", "")) not in ["", "sleep", "sit", "storage", "warm", "play"]:
		err("%s: interact '%s' is unknown" % [id, d.get("interact", "")])


func _check_clothing(id: String, d: Dictionary, rar: String) -> void:
	if not (str(d.get("slot", "")) in CLOTHING_SLOTS):
		err("%s: slot '%s' is not one of the six clothing slots" % [id, d.get("slot", "")])
	if d.get("wearable", false) != true or LuaData.int_of(d.get("max_stack", 0)) != 1:
		err("%s: a garment is wearable = true and max_stack 1 (RV-P7)" % id)
	var pal := LuaData.strings(LuaData.dict(d.get("art", {})).get("palette", []))
	if pal.size() != 3:
		err("%s: art.palette needs three colours" % id)
	for c in pal:
		if c.length() != 6 or not c.is_valid_hex_number(false):
			err("%s: palette colour '%s' is not 6-digit hex" % [id, c])
	var perks := LuaData.dict(d.get("perks", {}))
	for k in perks:
		if not (str(k) in PERK_KINDS):
			err("%s: unknown perk '%s'" % [id, k])
	var want := {"normal": [0, 0], "uncommon": [1, 1], "rare": [1, 2], "unique": [2, 2], "legendary": [2, 2]}
	var n := perks.size()
	if n < int(want[rar][0]) or n > int(want[rar][1]):
		err("%s: %s garment carries %d perk kind(s), the ladder wants %d-%d" % [id, rar, n, want[rar][0], want[rar][1]])


# ---------------------------------------------------------------------------------------------------------- keepsakes

func _check_keepsakes() -> void:
	var spots := LuaData.dict(_loot.get("spots", {}))
	var gifts := LuaData.arr(_loot.get("gifts", []))
	var tier_gifts := LuaData.arr(_loot.get("tier_gifts", []))
	var quest_rewards := LuaData.dict(_loot.get("quest_rewards", {}))
	var set_rewards := LuaData.arr(_loot.get("set_rewards", []))
	var boss := LuaData.dict(LuaData.dict(_loot.get("boss", {})).get("snurresvamp", {}))
	var boss_pool := LuaData.strings(boss.get("pool", []))
	var wanderers: Array = []
	for z in LuaData.dict(_loot.get("zones", {})):
		for w in LuaData.arr(LuaData.dict(LuaData.dict(_loot["zones"])[z]).get("wanderers", [])):
			wanderers.append([str(LuaData.dict(w).get("item", "")), str(z), str(LuaData.dict(w).get("container", ""))])
	var uniques := 0
	var legendaries := 0
	var claimed := {}                     # item id -> number of fixed sources found in the loot tables
	for id in _items:
		var d: Dictionary = _items[id]
		var rar := str(d.get("rarity", ""))
		if not (str(d.get("category", "")) in ["furniture", "clothing"]) or not Rarity.is_one_of_a_kind(rar):
			continue
		if rar == "unique":
			uniques += 1
		else:
			legendaries += 1
		var fixed := 0
		for s in LuaData.arr(d.get("sources", [])):
			var src := LuaData.dict(s)
			var ok := false
			match str(src.get("kind", "")):
				"spot":
					var sp := LuaData.dict(spots.get(str(src.get("spot", "")), {}))
					ok = str(sp.get("item", "")) == str(id) and str(sp.get("zone", "")) == str(src.get("zone", ""))
				"gift":
					for g in gifts:
						var gd := LuaData.dict(g)
						ok = ok or (str(gd.get("item", "")) == str(id) and str(gd.get("npc", "")) == str(src.get("npc", "")) and LuaData.int_of(gd.get("hearts", 0)) == LuaData.int_of(src.get("hearts", -1)))
				"tier_gift":
					for g in tier_gifts:
						var gd := LuaData.dict(g)
						ok = ok or (str(gd.get("item", "")) == str(id) and LuaData.int_of(gd.get("tier", 0)) == LuaData.int_of(src.get("tier", -1)))
				"quest":
					ok = str(id) in LuaData.strings(quest_rewards.get(str(src.get("quest", "")), []))
				"set_reward":
					for g in set_rewards:
						var gd := LuaData.dict(g)
						ok = ok or (str(gd.get("item", "")) == str(id) and str(gd.get("set", "")) == str(src.get("set", "")))
				"boss":
					if src.get("first_kill", false) == true:
						ok = str(src.get("quest", "")) == str(boss.get("first_kill_quest", "-")) and str(id) in LuaData.strings(quest_rewards.get(str(src.get("quest", "")), []))
					else:
						ok = str(id) in boss_pool
				"find":
					for w in wanderers:
						ok = ok or (w[0] == str(id) and w[1] == str(src.get("zone", "")) and w[2] == str(src.get("container", "")))
				_:
					err("%s: keepsakes have no %s source" % [id, src.get("kind", "?")])
					continue
			if not ok:
				err("%s: its %s source %s is not in the loot tables" % [id, src.get("kind", "?"), str(src)])
			else:
				fixed += 1
		claimed[str(id)] = fixed
		if fixed == 0:
			err("%s: a %s keepsake without a valid fixed source can never be found" % [id, rar])
	stats["unique"] = uniques
	stats["legendary"] = legendaries
	if uniques != 30 or legendaries != 19:
		err("keepsake counts are %d unique / %d legendary (expected 30 / 19)" % [uniques, legendaries])
	# the other direction: every loot-table entry points at an item that lists it
	for it in boss_pool:
		var back := false
		for s in LuaData.arr(LuaData.dict(_items.get(it, {})).get("sources", [])):
			back = back or str(LuaData.dict(s).get("kind", "")) == "boss"
		if not back or str(LuaData.dict(_items.get(it, {})).get("rarity", "")) != "legendary":
			err("boss pool entry %s is not a legendary piece that lists the boss as a source" % it)
	for sid in spots:
		var sp := LuaData.dict(spots[sid])
		var item := LuaData.dict(_items.get(str(sp.get("item", "")), {}))
		var back := false
		for s in LuaData.arr(item.get("sources", [])):
			back = back or (str(LuaData.dict(s).get("kind", "")) == "spot" and str(LuaData.dict(s).get("spot", "")) == str(sid))
		if not back:
			err("spot %s gives %s, which does not list the spot as a source" % [sid, sp.get("item", "?")])
	for g in tier_gifts:
		var gd := LuaData.dict(g)
		var item := LuaData.dict(_items.get(str(gd.get("item", "")), {}))
		var back := false
		for s in LuaData.arr(item.get("sources", [])):
			back = back or (str(LuaData.dict(s).get("kind", "")) == "tier_gift" and LuaData.int_of(LuaData.dict(s).get("tier", 0)) == LuaData.int_of(gd.get("tier", -1)))
		if not back:
			err("tier gift %s of tier %s does not list the tier gift as a source" % [gd.get("item", "?"), gd.get("tier", "?")])
	for q in quest_rewards:
		for it in LuaData.strings(quest_rewards[q]):
			if not _items.has(it):
				err("quest reward %s of %s is not an item" % [it, q])
				continue
			if not Rarity.is_one_of_a_kind(str(LuaData.dict(_items[it]).get("rarity", ""))):
				continue                                   # an ordinary piece may ALSO be a quest reward; only keepsakes must list every way to get them
			var back := false
			for s in LuaData.arr(LuaData.dict(_items[it]).get("sources", [])):
				back = back or str(LuaData.dict(s).get("quest", "")) == str(q)       # kind quest, or the boss's first kill that names the quest
			if not back:
				err("quest reward %s of %s is a keepsake that does not list the quest as a source" % [it, q])


# ---------------------------------------------------------------------------------------------------------- finds + shops

func _check_finds_and_shops() -> void:
	# random finds: a normal / uncommon / rare item's `find` zones == the zones whose pools hold it
	var pool_zones := {}
	for z in LuaData.dict(_loot.get("zones", {})):
		var pools := LuaData.dict(LuaData.dict(LuaData.dict(_loot["zones"])[z]).get("pools", {}))
		for kind in pools:
			var by_rarity := LuaData.dict(pools[kind])
			for rar in by_rarity:
				for ent in LuaData.arr(by_rarity[rar]):
					var item := str(LuaData.dict(ent).get("item", ""))
					if not _items.has(item):
						err("loot pool %s/%s/%s names %s, which is not an item" % [z, kind, rar, item])
						continue
					if str(LuaData.dict(_items[item]).get("rarity", "")) != str(rar):
						err("loot pool %s/%s/%s holds %s of rarity %s" % [z, kind, rar, item, LuaData.dict(_items[item]).get("rarity", "?")])
					if not pool_zones.has(item):
						pool_zones[item] = {}
					pool_zones[item][str(z)] = true
	for id in _items:
		var d: Dictionary = _items[id]
		var rar := str(d.get("rarity", ""))
		var zones := {}
		for s in LuaData.arr(d.get("sources", [])):
			var src := LuaData.dict(s)
			if str(src.get("kind", "")) == "find" and not src.has("container"):
				zones[str(src.get("zone", ""))] = true
		if Rarity.is_one_of_a_kind(rar):
			if pool_zones.has(str(id)):
				err("%s: a %s keepsake sits in a random loot pool" % [id, rar])
		elif zones.keys().size() != LuaData.dict(pool_zones.get(str(id), {})).keys().size() or not _same_keys(zones, LuaData.dict(pool_zones.get(str(id), {}))):
			err("%s: find zones %s differ from the loot pools %s" % [id, str(zones.keys()), str(LuaData.dict(pool_zones.get(str(id), {})).keys())])
	# shops
	var in_shop := {}                     # shop id -> {item: true}
	var npcs := LuaData.dict(_lr.get_config("npcs", {}))
	for sid in ["furniture_shop", "tailor_shop", "builder_yard", "flea_market"]:
		var shop := LuaData.dict(_shops.get(sid, {}))
		if shop.is_empty():
			err("shop %s does not exist" % sid)
			continue
		if not npcs.has(str(shop.get("keeper", ""))):
			err("shop %s: keeper %s is not an npc" % [sid, shop.get("keeper", "")])
		for k in ["name_key", "greeting_key"]:
			if not has_text(str(shop.get(k, ""))):
				err("shop %s: %s has no da+en text" % [sid, k])
		var members := {}
		for item in LuaData.dict(shop.get("stock", {})):
			members[str(item)] = true
		for slot in LuaData.arr(shop.get("rotation", [])):
			for item in LuaData.strings(LuaData.dict(slot).get("pool", [])):
				members[item] = true
		for item in members:
			if not _items.has(item):
				err("shop %s sells %s, which is not an item" % [sid, item])
			elif Rarity.is_one_of_a_kind(str(LuaData.dict(_items[item]).get("rarity", ""))):
				err("shop %s sells the keepsake %s" % [sid, item])
		in_shop[sid] = members
	for id in _items:
		for s in LuaData.arr(LuaData.dict(_items[id]).get("sources", [])):
			var src := LuaData.dict(s)
			if str(src.get("kind", "")) == "shop" and not LuaData.dict(in_shop.get(str(src.get("shop", "")), {})).has(str(id)):
				err("%s: lists shop %s as a source but the shop does not sell it" % [id, src.get("shop", "?")])
	for sid in in_shop:
		for item in in_shop[sid]:
			var back := false
			for s in LuaData.arr(LuaData.dict(_items.get(item, {})).get("sources", [])):
				back = back or (str(LuaData.dict(s).get("kind", "")) == "shop" and str(LuaData.dict(s).get("shop", "")) == str(sid))
			if not back:
				err("shop %s sells %s, which does not list the shop as a source" % [sid, item])
	stats["shops"] = in_shop.size()


# ---------------------------------------------------------------------------------------------------------- recipes

func _check_recipes() -> void:
	var loops := 0
	var builds := 0
	for rid in _recipes:
		var r := LuaData.dict(_recipes[rid])
		var out := LuaData.dict(r.get("output", {}))
		var out_id := str(out.get("item", ""))
		var def: Dictionary = _lr.get_item_def(out_id)
		if def.is_empty():
			err("recipe %s: output %s is not an item" % [rid, out_id])
			continue
		if not _items.has(out_id):
			continue                                    # a recipe of another package (P12's own recipes)
		var cost := 0
		var ok := true
		for ing in LuaData.int_map(r.get("ingredients", {})):
			var idef: Dictionary = _lr.get_item_def(str(ing))
			if idef.is_empty():
				err("recipe %s: ingredient %s is not an item" % [rid, ing])
				ok = false
				continue
			cost += LuaData.int_of(idef.get("buy_price", 0)) * int(LuaData.int_map(r["ingredients"])[ing])
		if not ok:
			continue
		if Rarity.is_one_of_a_kind(str(def.get("rarity", ""))):
			err("recipe %s crafts the keepsake %s" % [rid, out_id])
		var sell := LuaData.int_of(def.get("sell_price", 0))
		var buy := LuaData.int_of(def.get("buy_price", 0))
		if str(rid).begins_with("build_"):
			builds += 1
			var ratio := float(cost) / float(maxi(buy, 1))
			if not (sell < cost and cost < buy) or ratio < 0.45 or ratio > 0.87:
				err("recipe %s: cost %d vs sell %d / buy %d (ratio %.2f) - a craft-and-sell money loop or a pointless recipe" % [rid, cost, sell, buy, ratio])
				loops += 1
		elif sell * LuaData.int_of(out.get("amount", 1), 1) >= cost and cost > 0 and _ingredients_buyable(r):
			err("recipe %s: processing beats its inputs (sell %d >= cost %d)" % [rid, sell * LuaData.int_of(out.get("amount", 1), 1), cost])
			loops += 1
		if str(def.get("rarity", "")) == "rare" and str(def.get("category", "")) == "furniture" and str(r.get("unlock_flag", "")) == "":
			err("recipe %s: a rare furniture recipe needs a blueprint flag" % rid)
	stats["build_recipes"] = builds
	stats["recipe_loops"] = loops


func _ingredients_buyable(r: Dictionary) -> bool:
	for ing in LuaData.int_map(r.get("ingredients", {})):
		var def: Dictionary = _lr.get_item_def(str(ing))
		var shop_src := false
		for s in LuaData.arr(def.get("sources", [])):
			shop_src = shop_src or str(LuaData.dict(s).get("kind", "")) == "shop"
		if not shop_src and not (str(ing) in ["wood", "stone", "moss"]):
			return false
	return true


# ---------------------------------------------------------------------------------------------------------- sets + home

func _check_sets_and_home() -> void:
	for kind in ["furniture_sets", "wardrobe_sets"]:
		var sets := LuaData.dict(_lr.get_config(kind, {}))
		for sid in sets:
			var s := LuaData.dict(sets[sid])
			var members := LuaData.strings(s.get("members", []))
			if members.size() < 4:
				err("%s %s has only %d members" % [kind, sid, members.size()])
			for m in members:
				if not _items.has(m) or str(LuaData.dict(_items[m]).get("set", "")) != str(sid):
					err("%s %s: member %s is not tagged with the set" % [kind, sid, m])
			for k in ["name_key", "description_key"]:
				if not has_text(str(s.get(k, ""))):
					err("%s %s: %s has no da+en text" % [kind, sid, k])
	var tiers := LuaData.arr(_home.get("tiers", []))
	if tiers.size() != 10:
		err("home.tiers has %d entries (expected 10)" % tiers.size())
		return
	var last_gold := 0
	var tg := LuaData.arr(_loot.get("tier_gifts", []))
	for i in tiers.size():
		var t := LuaData.dict(tiers[i])
		var cost := LuaData.dict(t.get("cost", {}))
		var gold := LuaData.int_of(cost.get("gold", 0))
		if i >= 2 and gold <= last_gold:
			err("tier %d: gold %d does not rise above %d" % [i + 1, gold, last_gold])
		last_gold = gold if i >= 1 else 0
		for m in LuaData.int_map(cost.get("materials", {})):
			if _lr.get_item_def(str(m)).is_empty():
				err("tier %d: material %s is not an item" % [i + 1, m])
		for k in ["name_key", "description_key"]:
			if not has_text(str(t.get(k, ""))):
				err("tier %d: %s has no da+en text" % [i + 1, k])
		var gifts := LuaData.strings(t.get("gift_items", []))
		var want: Array[String] = []
		for g in tg:
			if LuaData.int_of(LuaData.dict(g).get("tier", 0)) == i + 1:
				want.append(str(LuaData.dict(g).get("item", "")))
		gifts.sort()
		want.sort()
		if gifts != want:
			err("tier %d: gift_items %s differ from loot.tier_gifts %s" % [i + 1, str(gifts), str(want)])
		var room := FeatureRoom.load_tier(i + 1)
		if room == null:
			err("tier %d: no room json (A1)" % [i + 1])
		elif room.max_furniture != LuaData.int_of(LuaData.dict(t.get("perks", {})).get("furniture_capacity", -1)):
			err("tier %d: furniture_capacity %s != room max_furniture %d" % [i + 1, LuaData.dict(t.get("perks", {})).get("furniture_capacity", "?"), room.max_furniture])
		for q in LuaData.arr(LuaData.dict(t.get("requires", {})).get("quests", [])):
			if not _lr.has_script("quests/" + str(q)):
				err("tier %d requires quest %s, which does not exist" % [i + 1, q])
	stats["tiers"] = tiers.size()


# ---------------------------------------------------------------------------------------------------------- starter kit

func _check_starter_kit() -> void:
	var kit := LuaData.dict(_lr.get_config("starter_kit", {}))
	if kit.is_empty():
		err("config starter_kit is missing (lua/data/starter_kit.lua)")
		return
	var wardrobe := LuaData.dict(kit.get("wardrobe", {}))
	var furniture := LuaData.dict(kit.get("furniture", {}))
	var worn := LuaData.strings(wardrobe.get("worn", []))
	var owned := LuaData.strings(wardrobe.get("owned", []))
	var placed := LuaData.strings(furniture.get("placed", []))
	var stock := LuaData.int_map(furniture.get("stock", {}))
	for id in worn + owned:
		if not _items.has(id) or str(LuaData.dict(_items[id]).get("category", "")) != "clothing":
			err("starter kit: garment %s does not exist" % id)
	var furniture_ids: Array = []
	furniture_ids.append_array(placed)
	furniture_ids.append_array(stock.keys())
	for id in furniture_ids:
		if not _items.has(str(id)) or str(LuaData.dict(_items[str(id)]).get("category", "")) != "furniture":
			err("starter kit: furniture %s does not exist" % id)
	# the kit PLACES: first the `placed` pieces in order, then every stock piece, into the room of tier 1 under the data-level rules
	var room := FeatureRoom.load_tier(1)
	if room == null:
		err("starter kit: no room json for tier 1")
		return
	var all_ids: Array[String] = []
	all_ids.append_array(placed)
	for id in stock:
		for _n in int(stock[id]):
			all_ids.append(str(id))
	var count := 0
	for id in all_ids:
		var spot := room.find_spot(id)
		if spot.is_empty():
			err("starter kit: %s finds no place in the room of tier 1 (%d of %d placed)" % [id, count, all_ids.size()])
			break
		room.place(id, spot["cell"], int(spot["rot"]))
		count += 1
	stats["starter_pieces"] = count
	stats["starter_decor"] = room.decor_total()
	var levels := LuaData.arr(_home.get("hygge_levels", []))
	if levels.size() > 1 and room.decor_total() >= LuaData.int_of(LuaData.dict(levels[1]).get("min_decor", 0)):
		err("starter kit: the whole kit (decor %d) already reaches the first hygge level" % room.decor_total())


# ---------------------------------------------------------------------------------------------------------- hearts

func _check_hearts() -> void:
	var npcs := LuaData.dict(_lr.get_config("npcs", {}))
	var asks: Array = []
	for t in LuaData.arr(_home.get("tiers", [])):
		var td := LuaData.dict(t)
		var fr := LuaData.int_map(LuaData.dict(td.get("requires", {})).get("friendship", {}))
		for npc in fr:
			asks.append(["tier %s gate" % td.get("tier", "?"), str(npc), int(fr[npc])])
	for g in LuaData.arr(_loot.get("gifts", [])):
		var gd := LuaData.dict(g)
		asks.append(["gift %s" % gd.get("item", "?"), str(gd.get("npc", "")), LuaData.int_of(gd.get("hearts", 0))])
	var worst_days := 0
	for a in asks:
		var npc := LuaData.dict(npcs.get(a[1], {}))
		if npc.is_empty() or npc.get("friendship", false) != true:
			err("%s asks %d hearts of %s, who cannot earn hearts (npcs.lua friendship is not true)" % [a[0], a[2], a[1]])
		if int(a[2]) < 1 or int(a[2]) > HEART_CAP:
			err("%s asks %d hearts (the cap is %d)" % [a[0], a[2], HEART_CAP])
		worst_days = maxi(worst_days, int(a[2]) * WEEKLY_CHAT_DAYS)
	stats["heart_asks"] = asks.size()
	stats["weekly_chat_days_for_the_most_hearts"] = worst_days
	if worst_days > 112:
		err("the most hearts any gate asks need %d days of weekly chats (more than one 112 day year)" % worst_days)


func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		if not b.has(k):
			return false
	for k in b:
		if not a.has(k):
			return false
	return true


# ---------------------------------------------------------------------------------------------------------- review F1 r1: shop days, dialogue shop buttons, map markers

## PLAN_FEATURES section 3: Pippins Loppemarked is open Saturday + Sunday; weekday index 0 = Monday (TimeManager.weekday_index); every other shop is open daily (no open_weekdays)
const SHOP_OPEN_DAYS := {"flea_market": [5, 6]}
const MAP_MARKERS_PATH := "res://data/features/map_markers.json"


static func _is_weekday(v: Variant) -> bool:
	var t := typeof(v)
	return (t == TYPE_INT or (t == TYPE_FLOAT and float(v) == floorf(float(v)))) and int(v) >= 0 and int(v) <= 6


## {5, 7} names a weekday that does not exist and would close the market on Sunday without a message; a missing list opens it every day.
static func shop_schedule_problems(shops: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for sid in shops:
		var shop := LuaData.dict(shops[sid])
		var want: Array = SHOP_OPEN_DAYS.get(str(sid), [])
		if not shop.has("open_weekdays"):
			if not want.is_empty():
				out.append("shop %s: open_weekdays is missing, the shop would be open every day (expected %s)" % [sid, str(want)])
			continue
		var days: Variant = shop["open_weekdays"]
		if typeof(days) != TYPE_ARRAY or (days as Array).is_empty():
			out.append("shop %s: open_weekdays must be a non-empty list of weekday indices" % sid)
			continue
		var ints: Array = []
		var bad: Array = []
		for d in days:
			if _is_weekday(d):
				ints.append(int(d))
			else:
				bad.append(d)
		if not bad.is_empty():
			out.append("shop %s: open_weekdays has entries that are not a weekday index 0..6 (0 = Monday): %s" % [sid, str(bad)])
			continue
		var seen := {}
		for d in ints:
			seen[d] = true
		if seen.size() != ints.size():
			out.append("shop %s: open_weekdays lists a day twice: %s" % [sid, str(ints)])
		if want.is_empty():
			out.append("shop %s: only the flea market has opening days, this shop is open daily (%s)" % [sid, str(ints)])
		else:
			ints.sort()
			if ints != want:
				out.append("shop %s: opening days %s differ from the plan %s" % [sid, str(ints), str(want)])
	return out


## states = [{npc, label, choices = [{action, shop_id}]}]: every flag state the project interpreter produced; texts = {file: Lua source}.
## Every state offers a shop button and every button names a real shop whose keeper is the speaker (a typo made the Materials button open nothing).
## The Lua text is scanned too, so a branch that no flag state reaches cannot hide a wrong shop id: one shop_id literal per open_shop action, each an existing shop.
static func dialogue_shop_problems(shops: Dictionary, states: Array, texts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for st in states:
		var s := LuaData.dict(st)
		var npc := str(s.get("npc", ""))
		var opens := 0
		for c in LuaData.arr(s.get("choices", [])):
			var cd := LuaData.dict(c)
			if str(cd.get("action", "")) != "open_shop":
				continue
			opens += 1
			var sid := str(cd.get("shop_id", ""))
			if not shops.has(sid):
				out.append("%s / %s: open_shop names the shop '%s', which does not exist" % [npc, s.get("label", "?"), sid])
			elif str(LuaData.dict(shops[sid]).get("keeper", "")) != npc:
				out.append("%s / %s: open_shop opens '%s', whose keeper is %s" % [npc, s.get("label", "?"), sid, LuaData.dict(shops[sid]).get("keeper", "?")])
		if opens == 0:
			out.append("%s / %s: the dialogue has no open_shop choice" % [npc, s.get("label", "?")])
	var rx_action := RegEx.create_from_string("action\\s*=\\s*\"open_shop\"")
	var rx_literal := RegEx.create_from_string("shop_id\\s*=\\s*\"([^\"]*)\"")
	for f in texts:
		var text := str(texts[f])
		var literals := rx_literal.search_all(text)
		if rx_action.search_all(text).size() != literals.size():
			out.append("%s: %d open_shop actions but %d shop_id literals" % [f, rx_action.search_all(text).size(), literals.size()])
		for m in literals:
			if not shops.has(m.get_string(1)):
				out.append("%s: shop_id '%s' is not a shop" % [f, m.get_string(1)])
	return out


static func load_map_markers() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_MARKERS_PATH))
	return LuaData.dict(parsed)


static func _same_counts(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or int(a[k]) != int(b[k]):
			return false
	return true


## data/features/map_markers.json (what the map authors P11 / P19 place) must equal the loot tables, per area: chests + digging spots per container id == zones.<area>.containers.<id>.count,
## creatures per visit == zones.<area>.creatures, unique spots == the loot.spots of that zone, every boss placed once in an area that has the boss chest tier.
static func map_marker_problems(markers: Dictionary, loot: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var areas := LuaData.dict(markers.get("areas", {}))
	var zones := LuaData.dict(loot.get("zones", {}))
	var spots_by_zone := {}
	var spots := LuaData.dict(loot.get("spots", {}))
	for sid in spots:
		var sz := str(LuaData.dict(spots[sid]).get("zone", ""))
		if not spots_by_zone.has(sz):
			spots_by_zone[sz] = []
		(spots_by_zone[sz] as Array).append(str(sid))
	var known := {}                                   # the loot zones + the zones of the loot spots (Hyggebyen has a spot but no zone: no chests, no creatures there)
	for z in zones:
		known[str(z)] = true
	for z in spots_by_zone:
		known[str(z)] = true
	for a in areas:
		if not known.has(str(a)):
			out.append("map_markers area %s is neither a loot zone nor the zone of a loot spot" % a)
	for z in known:
		if not areas.has(z):
			out.append("loot zone / spot zone %s has no map_markers area" % z)
	var boss_areas := {}
	for z in known:
		if not areas.has(z):
			continue
		var area := LuaData.dict(areas[z])
		var zd := LuaData.dict(zones.get(z, {}))
		var want_c := {}
		for cid in LuaData.dict(zd.get("containers", {})):
			want_c[str(cid)] = LuaData.int_of(LuaData.dict(LuaData.dict(zd["containers"])[cid]).get("count", 0))
		var got_c := LuaData.int_map(area.get("containers", {}))
		if not _same_counts(got_c, want_c):
			out.append("%s: chests / digging spots %s differ from loot.zones containers %s" % [z, str(got_c), str(want_c)])
		var want_cr := LuaData.int_map(zd.get("creatures", {}))
		var got_cr := LuaData.int_map(area.get("creatures", {}))
		if not _same_counts(got_cr, want_cr):
			out.append("%s: creatures per visit %s differ from loot.zones creatures %s" % [z, str(got_cr), str(want_cr)])
		var got_sp: Array = LuaData.strings(area.get("unique_spots", []))
		var want_sp: Array = (spots_by_zone.get(str(z), []) as Array).duplicate()
		got_sp.sort()
		want_sp.sort()
		if got_sp != want_sp:
			out.append("%s: unique spots %s differ from loot.spots %s" % [z, str(got_sp), str(want_sp)])
		for cid in got_c:
			if not LuaData.dict(loot.get("containers", {})).has(cid):
				out.append("%s: container %s is not in loot.containers" % [z, cid])
		for cid in got_cr:
			if not LuaData.dict(loot.get("creatures", {})).has(cid):
				out.append("%s: creature %s is not in loot.creatures" % [z, cid])
		if str(area.get("boss", "")) != "":
			if not boss_areas.has(str(area["boss"])):
				boss_areas[str(area["boss"])] = []
			(boss_areas[str(area["boss"])] as Array).append(str(z))
	var bosses := LuaData.dict(loot.get("boss", {}))
	for b in bosses:
		var placed: Array = boss_areas.get(str(b), [])
		if placed.size() != 1:
			out.append("boss %s is placed in %d areas (expected exactly one)" % [b, placed.size()])
			continue
		if not LuaData.dict(LuaData.dict(zones.get(placed[0], {})).get("containers", {})).has(str(LuaData.dict(bosses[b]).get("chest", ""))):
			out.append("boss %s: its chest tier %s is not a container of area %s" % [b, LuaData.dict(bosses[b]).get("chest", "?"), placed[0]])
	for b in boss_areas:
		if not bosses.has(b):
			out.append("map_markers places the boss %s, which is not in loot.boss" % b)
	return out


# ---------------------------------------------------------------------------------------------------------- review F1 r2 (fix round 2): references and numbers that no rule looked at

const SPOT_REQUIRES_KEYS := ["quests", "day_min", "home_tier_min"]
const FEATURE_DIALOGUES := ["fairy_builder", "fairy_furnisher", "fairy_tailor"]


static func _whole(v: Variant) -> bool:
	var t := typeof(v)
	return t == TYPE_INT or (t == TYPE_FLOAT and float(v) == floorf(float(v)))


## the runtime data this package declares, checked by the rules below (instance part; the rules themselves are static and work on plain data)
func _check_second_review() -> void:
	var spots := LuaData.dict(_loot.get("spots", {}))
	var source_quest := {}
	for id in _items:
		for s in LuaData.arr(LuaData.dict(_items[id]).get("sources", [])):
			var src := LuaData.dict(s)
			if str(src.get("kind", "")) == "spot":
				source_quest[str(src.get("spot", ""))] = str(src.get("quest", ""))
	err_all(spot_requirement_problems(spots, func(q: String) -> bool: return _lr.has_script("quests/" + q), source_quest))
	err_all(stack_problems(_items))
	err_all(shop_stock_problems(_shops))
	var wardrobe := LuaData.dict(_lr.get_config("wardrobe", {}))
	err_all(equip_slot_problems(LuaData.dict(wardrobe.get("equip_slots", {}))))
	var npcs := LuaData.dict(_lr.get_config("npcs", {}))
	var quests := {}
	var texts := {}
	for q in ["bogtraeet", "moonstone_crown", "snurresvampen", "slotsdroemmen"]:
		var path := "res://lua/quests/%s.lua" % q
		var parsed: Dictionary = _lr.parse_lua_source(FileAccess.get_file_as_string(path), path)
		quests[q] = {"rewards": LuaData.dict(parsed.get("rewards", {})), "objectives": LuaData.arr(parsed.get("objectives", [])), "meta": LuaData.dict(parsed.get("meta", {}))}
	err_all(quest_reference_problems(quests, npcs, func(i: String) -> bool: return not _lr.get_item_def(i).is_empty()))
	var dlg := {}
	for f in FEATURE_DIALOGUES:
		dlg["lua/dialogue/%s.lua" % f] = FileAccess.get_file_as_string("res://lua/dialogue/%s.lua" % f)
	err_all(voice_key_problems(dlg))
	texts.merge(dlg)
	for f in ["lua/items/furniture.lua", "lua/items/clothing.lua", "lua/items/building_materials.lua", "lua/recipes/furniture.lua", "lua/recipes/materials.lua", "lua/shops/home_shops.lua",
			"lua/data/home_tiers.lua", "lua/data/loot_tables.lua", "lua/data/sets.lua", "lua/data/wardrobe_rules.lua", "lua/data/starter_kit.lua",
			"lua/quests/bogtraeet.lua", "lua/quests/moonstone_crown.lua", "lua/quests/snurresvampen.lua", "lua/quests/slotsdroemmen.lua"]:
		texts[f] = FileAccess.get_file_as_string("res://" + f)
	err_all(text_literal_problems(texts))
	var owners: Dictionary = _loc.load_owners("res://")
	var res := creature_key_problems(LuaData.dict(_loot.get("creatures", {})), func(k: String) -> bool: return has_text(k), func(k: String) -> String: return _loc.owner_of(k, owners),
			func(file: String) -> bool: return FileAccess.file_exists("res://localization/" + file))
	err_all(res["problems"])
	stats["creature_keys_pending"] = (res["pending"] as Array).size()
	stats["creature_keys_pending_list"] = res["pending"]


## loot.spots.<id>.requires = { quests = {..}, day_min = n, home_tier_min = n }: the keepsake is handed out only when ALL hold.  An unknown quest id makes it unobtainable for ever, day_min < 1 or a tier outside
## 1..10 is a typo, any other key is read by nobody; the item's own `spot` source names the same quest (source_quest = {spot id: quest or ""}).  quest_exists = Callable(String) -> bool.
static func spot_requirement_problems(spots: Dictionary, quest_exists: Callable, source_quest: Dictionary, tiers: int = 10) -> Array[String]:
	var out: Array[String] = []
	for sid in spots:
		var sp := LuaData.dict(spots[sid])
		var src_q := str(source_quest.get(str(sid), ""))
		if not sp.has("requires"):
			if src_q != "":
				out.append("spot %s: its item source names the quest %s but the spot has no requires.quests" % [sid, src_q])
			continue
		var req: Variant = sp["requires"]
		if typeof(req) != TYPE_DICTIONARY or (req as Dictionary).is_empty():
			out.append("spot %s: requires must be a non-empty table" % sid)
			continue
		var r := req as Dictionary
		for k in r:
			if not (str(k) in SPOT_REQUIRES_KEYS):
				out.append("spot %s: unknown requirement '%s' (the loot service reads quests, day_min and home_tier_min only)" % [sid, k])
		var has_quests := false
		if r.has("quests"):
			var qs: Variant = r["quests"]
			if typeof(qs) != TYPE_ARRAY or (qs as Array).is_empty():
				out.append("spot %s: requires.quests must be a non-empty list of quest ids" % sid)
			else:
				has_quests = true
				for q in qs:
					if typeof(q) != TYPE_STRING or not bool(quest_exists.call(str(q))):
						out.append("spot %s: requires.quests names '%s', a quest that does not exist: the keepsake could never be found" % [sid, q])
				if not (src_q in LuaData.strings(qs)):
					out.append("spot %s: the spot source of the item names '%s', not one of requires.quests %s" % [sid, src_q, str(qs)])
		if not has_quests and src_q != "":
			out.append("spot %s: its item source names the quest %s but the spot has no requires.quests" % [sid, src_q])
		if r.has("day_min") and (not _whole(r["day_min"]) or int(r["day_min"]) < 1):
			out.append("spot %s: requires.day_min must be an integer >= 1 (found %s)" % [sid, str(r["day_min"])])
		if r.has("home_tier_min") and (not _whole(r["home_tier_min"]) or int(r["home_tier_min"]) < 1 or int(r["home_tier_min"]) > tiers):
			out.append("spot %s: requires.home_tier_min must be an integer 1..%d (found %s)" % [sid, tiers, str(r["home_tier_min"])])
	return out


## quests = {id: {rewards, objectives, meta}}: every npc a quest pays hearts to, names as giver or as an objective target must exist in lua/config/npcs.lua (a reward `friendship = { fairy_kingx = 2 }`
## pays nobody and nothing says so), hearts are integers 1..10, reward items exist (item_exists = Callable(String) -> bool), gold is an integer >= 0.
static func quest_reference_problems(quests: Dictionary, npcs: Dictionary, item_exists: Callable) -> Array[String]:
	var out: Array[String] = []
	for qid in quests:
		var q := LuaData.dict(quests[qid])
		var rw := LuaData.dict(q.get("rewards", {}))
		var friendship := LuaData.dict(rw.get("friendship", {}))
		for npc in friendship:
			if not npcs.has(str(npc)):
				out.append("quest %s: rewards.friendship names the npc '%s', who does not exist" % [qid, npc])
			if not _whole(friendship[npc]) or int(friendship[npc]) < 1 or int(friendship[npc]) > HEART_CAP:
				out.append("quest %s: rewards.friendship hearts of %s must be an integer 1..%d (found %s)" % [qid, npc, HEART_CAP, str(friendship[npc])])
		var items := LuaData.dict(rw.get("items", {}))
		for item in items:
			if not bool(item_exists.call(str(item))):
				out.append("quest %s: rewards.items names '%s', which is not an item" % [qid, item])
			if not _whole(items[item]) or int(items[item]) < 1:
				out.append("quest %s: rewards.items amount of %s must be an integer >= 1 (found %s)" % [qid, item, str(items[item])])
		if rw.has("gold") and (not _whole(rw["gold"]) or int(rw["gold"]) < 0):
			out.append("quest %s: rewards.gold must be an integer >= 0 (found %s)" % [qid, str(rw["gold"])])
		var giver := str(LuaData.dict(q.get("meta", {})).get("giver", ""))
		if giver != "" and not npcs.has(giver):
			out.append("quest %s: meta.giver '%s' is not an npc" % [qid, giver])
		for o in LuaData.arr(q.get("objectives", [])):
			var od := LuaData.dict(o)
			if od.has("npc") and not npcs.has(str(od["npc"])):
				out.append("quest %s: objective %s names the npc '%s', who does not exist" % [qid, od.get("id", "?"), od["npc"]])
	return out


## defs = id -> item def of this package.  max_stack: ordinary furniture 9 (loot.duplicates and the furniture store assume it), keepsakes 1; blueprints 1, other materials 1..99; garments 1.
static func stack_problems(defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in defs:
		var d := LuaData.dict(defs[id])
		var cat := str(d.get("category", ""))
		var rar := str(d.get("rarity", ""))
		var ms: Variant = d.get("max_stack", null)
		if not _whole(ms):
			out.append("%s: max_stack must be an integer (found %s)" % [id, str(ms)])
			continue
		var n := int(ms)
		if cat == "furniture" and n != (1 if (rar == "unique" or rar == "legendary") else 9):
			out.append("%s: a %s furniture piece has max_stack %d (expected %d)" % [id, rar, n, 1 if (rar == "unique" or rar == "legendary") else 9])
		elif cat == "clothing" and n != 1:
			out.append("%s: a garment has max_stack %d (expected 1)" % [id, n])
		elif cat == "blueprint" and n != 1:
			out.append("%s: a blueprint has max_stack %d (expected 1)" % [id, n])
		elif (cat == "building_material" or cat == "gem") and (n < 1 or n > 99):
			out.append("%s: a material has max_stack %d (expected 1..99)" % [id, n])
	return out


## Fixed stock rows `{ stock = n, restock = n }` (ShopSystem: `stock` the most a shelf holds, `restock` the units back every morning, never above `stock`) and the numbers of the rotation rows.
static func shop_stock_problems(shops: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for sid in shops:
		var shop := LuaData.dict(shops[sid])
		var stock := LuaData.dict(shop.get("stock", {}))
		for item in stock:
			var row := LuaData.dict(stock[item])
			if not _whole(row.get("stock", null)) or int(row["stock"]) < 1:
				out.append("shop %s: %s stock must be an integer >= 1 (found %s)" % [sid, item, str(row.get("stock", "<none>"))])
			elif row.has("restock") and (not _whole(row["restock"]) or int(row["restock"]) < 0 or int(row["restock"]) > int(row["stock"])):
				out.append("shop %s: %s restock must be an integer 0..stock (found %s of %s)" % [sid, item, str(row["restock"]), str(row["stock"])])
			if row.has("price") and (not _whole(row["price"]) or int(row["price"]) < 0):
				out.append("shop %s: %s price must be an integer >= 0 (found %s)" % [sid, item, str(row["price"])])
		for slot in LuaData.arr(shop.get("rotation", [])):
			var sd := LuaData.dict(slot)
			if not _whole(sd.get("period", null)) or int(sd["period"]) < 1:
				out.append("shop %s: rotation %s period must be an integer >= 1 (found %s)" % [sid, sd.get("id", "?"), str(sd.get("period", "<none>"))])
			var pm: Variant = sd.get("price_mult", null)
			if not (typeof(pm) == TYPE_INT or typeof(pm) == TYPE_FLOAT) or float(pm) <= 0.0:
				out.append("shop %s: rotation %s price_mult must be a number > 0 (found %s)" % [sid, sd.get("id", "?"), str(pm)])
			var sb: Variant = sd.get("season_boost", 1)
			if not (typeof(sb) == TYPE_INT or typeof(sb) == TYPE_FLOAT) or float(sb) < 1.0:
				out.append("shop %s: rotation %s season_boost must be a number >= 1 (found %s)" % [sid, sd.get("id", "?"), str(sb)])
	return out


## wardrobe.equip_slots: `z` is the draw order above the body and must be a distinct integer per slot; item_slot + subslot is unique; every slot has a name key.
static func equip_slot_problems(slots: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var seen_z := {}
	var seen_key := {}
	for sid in slots:
		var e := LuaData.dict(slots[sid])
		if not _whole(e.get("z", null)):
			out.append("equip slot %s: z must be an integer (found %s)" % [sid, str(e.get("z", "<none>"))])
		elif seen_z.has(int(e["z"])):
			out.append("equip slot %s: z %d equals the z of %s" % [sid, int(e["z"]), seen_z[int(e["z"])]])
		else:
			seen_z[int(e["z"])] = str(sid)
		var key := "%s/%s" % [e.get("item_slot", ""), e.get("subslot", "")]
		if seen_key.has(key):
			out.append("equip slot %s: item_slot + subslot %s equals the slot %s" % [sid, key, seen_key[key]])
		seen_key[key] = str(sid)
		if str(e.get("name_key", "")) == "":
			out.append("equip slot %s: name_key is missing" % sid)
	return out


## The voiced lines of the three feature dialogues (texts = {file: Lua source}): every spoken line (`text_key = "DLG_..."`, not a DLG_CHOICE_ button) has a voice_key, the key is
## `voice/<speaker>/<line id>`, the line id matches the text key (DLG_<NPC>_<ID>), and one voice key never serves two different texts.
static func voice_key_problems(texts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var rx_line := RegEx.create_from_string("id\\s*=\\s*\"([^\"]+)\"\\s*,\\s*text_key\\s*=\\s*\"([A-Z0-9_]+)\"\\s*,\\s*voice_key\\s*=\\s*\"([^\"]*)\"")
	var rx_speaker := RegEx.create_from_string("speaker\\s*=\\s*\"([^\"]+)\"")
	var rx_spoken := RegEx.create_from_string("text_key\\s*=\\s*\"DLG_(?!CHOICE_)")
	var by_voice := {}
	for f in texts:
		var text := str(texts[f])
		var speakers := rx_speaker.search_all(text)
		var blocks := rx_line.search_all(text)
		if rx_spoken.search_all(text).size() != blocks.size():
			out.append("%s: a spoken line without voice_key (or a block that is not  id, text_key, voice_key  in this order): %d lines, %d voiced" % [f, rx_spoken.search_all(text).size(), blocks.size()])
		for m in blocks:
			var speaker := ""
			for sp in speakers:
				if sp.get_start() < m.get_start():
					speaker = sp.get_string(1)
			var line_id := m.get_string(1)
			var text_key := m.get_string(2)
			var voice := m.get_string(3)
			if speaker == "":
				out.append("%s: line %s has no speaker before it" % [f, line_id])
				continue
			if voice != "voice/%s/%s" % [speaker, line_id]:
				out.append("%s: voice_key '%s' must be voice/%s/%s" % [f, voice, speaker, line_id])
			var want_text := "DLG_%s_%s" % [speaker.trim_prefix("fairy_").to_upper(), line_id.to_upper()]
			if text_key != want_text:
				out.append("%s: line id %s does not match its text key %s (expected %s)" % [f, line_id, text_key, want_text])
			if not by_voice.has(voice):
				by_voice[voice] = {}
			by_voice[voice][text_key] = true
	for v in by_voice:
		if (by_voice[v] as Dictionary).size() > 1:
			out.append("voice key %s serves different texts: %s" % [v, str((by_voice[v] as Dictionary).keys())])
	return out


## Working rule 3: Danish / English text lives in the localization CSVs, never as a literal in Lua.  A text literal = a string with a space and a run of 3 letters (ids, keys, colours, paths have no
## spaces); comments are skipped.  (The quests carried ten `description = "Sæt 6 unikke ..."` copies next to their description_key.)
static func text_literal_problems(texts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var rx_letters := RegEx.create_from_string("[A-Za-zæøåÆØÅ]{3}")
	for f in texts:
		var text := str(texts[f])
		var i := 0
		var n := text.length()
		while i < n:
			var c := text[i]
			if c == "-" and text.substr(i, 2) == "--":
				var j := text.find("\n", i)
				i = n if j < 0 else j
				continue
			if c == "\"" or c == "'":
				var buf := ""
				var k := i + 1
				while k < n and text[k] != c and text[k] != "\n":
					if text[k] == "\\" and k + 1 < n:
						buf += text.substr(k, 2)
						k += 2
						continue
					buf += text[k]
					k += 1
				if buf.contains(" ") and rx_letters.search(buf) != null:
					out.append("%s: text literal \"%s\" (Danish / English text belongs in a CSV)" % [f, buf.substr(0, 60)])
				i = k + 1
				continue
			i += 1
	return out


## loot.creatures.<id>.name_key (the name the loot feed shows): the key is DEFINED (defined = Callable(String) -> bool), or its owner CSV (owner_of = Callable(String) -> String, from
## tools/loc/key_owners.json) has not landed yet (owner_exists = Callable(String) -> bool): a documented PENDING key, else a defect (no owner = typo / unclaimed family; owner exists without the row).
## Returns {problems: Array[String], pending: Array of "creature:KEY:file"}.
static func creature_key_problems(creatures: Dictionary, defined: Callable, owner_of: Callable, owner_exists: Callable) -> Dictionary:
	var problems: Array[String] = []
	var pending: Array = []
	for cid in creatures:
		var k := str(LuaData.dict(creatures[cid]).get("name_key", ""))
		var rx := RegEx.create_from_string("^[A-Z0-9_]+$")
		if rx.search(k) == null:
			problems.append("creature %s: name_key '%s' is not a localisation key" % [cid, k])
		elif bool(defined.call(k)):
			continue
		else:
			var ow := str(owner_of.call(k))
			if ow == "":
				problems.append("creature %s: %s is owned by no CSV in tools/loc/key_owners.json (typo, or add the key family there)" % [cid, k])
			elif bool(owner_exists.call(ow)):
				problems.append("creature %s: %s exists but has no row for %s" % [cid, ow, k])
			else:
				pending.append("%s:%s:%s" % [cid, k, ow])
	return {"problems": problems, "pending": pending}
