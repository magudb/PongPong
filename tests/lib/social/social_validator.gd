class_name SocialValidator
extends RefCounted
## The validator of the social data (package S-core): the GDScript port of tools/social/core/validate_social.py, rules SV1..SV12 + SV14 (SV13 is S-marriage's gate
## rule), the festival attendance rules of the ghost family amendment (AGF17) and the clock rules (CLOCK_26: a festival window ends by day_end_hour - 1). Pure
## statics over a DATA dictionary (the shape of tests/lib/social/dump_social_json.gd and of tests/lib/social/fixtures/design_dump.json):
##
##   {social, citizens, gift_tastes, npcs{id:{friendship, role, home_area, shop_id}}, items{id:{category, rarity, sell_price, buy_price, furniture_type, slot, set,
##    protected, giftable}}, festivals{id:{meta, activities, scenes, rewards}}, events{id:{meta, steps, rewards}}, shops{id:{}}, time{days_per_season, seasons,
##    day_start_hour, day_end_hour}, towns{max_live_visuals_festival}}
##
##   validate(data, opts) -> {errors: Array[String], warnings: Array[String], skipped: Array[String], stats: Dictionary}
##   selftest(pristine) -> {pristine_errors, caught: [], missed: [], mutants: n}    every mutant of the pristine data must be caught by the rule it breaks
##
## opts (all optional): when_errors: Callable(spec) -> Array (the grammar check, default SocialManager.when_spec_errors), route_minutes: Callable(npc, area, spot) ->
## game minutes of the walk from the festival stage to the citizen's counter (-1 = unknown), shop_open_hour: Callable(shop_id, weekday) -> float opening hour (-1 = unknown).
## Without route_minutes the leave_early walk rule is NOT evaluated and says so in `skipped` (no silent pass).
##
## Messages start with the rule code: "SV3: ..." (errors) so a test and a person can grep for the rule.

const STEP_ACTS: Array[String] = ["fade", "stand", "walk", "face", "camera", "clip", "emote", "say", "choice", "give", "points", "flag", "wait", "time", "sfx", "end"]
const ACTIVITY_KINDS: Array[String] = ["contest", "potluck", "market", "feast", "wish", "dance", "scene"]
const NEVER_CATEGORIES: Array[String] = ["quest", "special", "animal", "building", "blueprint"]
const KEEPSAKE_RARITIES: Array[String] = ["unique", "legendary"]
const PRIZE_RARITIES: Array[String] = ["normal", "uncommon", "rare"]
const RARITY_RANK := {"normal": 0, "uncommon": 1, "rare": 2}
const FESTIVAL_AREAS: Array[String] = ["traetoppen", "hyggebyen", "farm"]
const CLASS_ORDER: Array[String] = ["hate", "dislike", "love", "like"]
const SAMPLE_MAX_SELL := 20
const FIRST_PRIZE_CAP_GOLD := 400.0
const FIRST_PRIZE_FACTOR := 2.0
const SECOND_FACTOR := 0.7
const THIRD_FACTOR := 0.4
const JITTER := 0.15                           # the contest jitter of S-events (score x (1 +- 0.15))
const LEAVE_WALK_FACTOR := 1.5
const LEAVE_WALK_MARGIN_MIN := 15.0
const DEFAULT_MAX_LIVE_FESTIVAL := 20
const DEFAULT_DAY_START := 6
const DEFAULT_DAY_END := 26
const DEFAULT_SEASONS: Array[String] = ["foraar", "sommer", "efteraar", "vinter"]


static func validate(data: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var v := _Run.new()
	v.data = data
	v.opts = opts
	v.go()
	return {"errors": v.errors, "warnings": v.warnings, "skipped": v.skipped, "stats": v.stats}


## The rule codes ("SV3") of the errors of a result, de-duplicated and sorted.
static func codes_of(result: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e in result["errors"]:
		var code := str(e).get_slice(":", 0)
		if code not in out:
			out.append(code)
	out.sort()
	return out


static func giftable(def: Dictionary) -> bool:
	if str(def.get("rarity", "normal")) in KEEPSAKE_RARITIES or bool(def.get("protected", false)):
		return false
	if def.has("giftable"):
		return bool(def["giftable"])
	if str(def.get("category", "")) in NEVER_CATEGORIES:
		return false
	return LuaData.num(def.get("sell_price", 0)) > 0.0


## The cheapest entry of a contest category that can still WIN first place (see SV14): the entry score is sell value x (1 + 0.5 x rarity rank); the first NPC bar is
## the best score of the category; with the jitter at its worst for the bar and its best for the entrant an item wins when score x (1 + JITTER) >= best x (1 - JITTER).
## Returns the sell value of the cheapest such entry, 0 when the category has no giftable entry.
static func cheapest_winning_entry(items: Dictionary, select: String) -> float:
	var best := 0.0
	var entries: Array = []
	for id in items:
		var def := LuaData.dict(items[id])
		if giftable(def) and _selector_matches(items, select, str(id)):
			var sell := LuaData.num(def.get("sell_price", 0))
			var score := sell * (1.0 + 0.5 * float(RARITY_RANK.get(str(def.get("rarity", "normal")), 0)))
			entries.append([sell, score])
			best = maxf(best, score)
	var cheapest := 0.0
	for e in entries:
		if float(e[1]) * (1.0 + JITTER) >= best * (1.0 - JITTER) and (cheapest == 0.0 or float(e[0]) < cheapest):
			cheapest = float(e[0])
	return cheapest


static func _selector_matches(items: Dictionary, selector: String, item_id: String) -> bool:
	var sels := selectors_of(item_id, LuaData.dict(items.get(item_id, {})))
	return sels.has(selector)


## The selectors an item answers to and their specificity: item id (4) > ftype: / slot: / set: (3) > category: (2) > rarity: (1).
static func selectors_of(item_id: String, def: Dictionary) -> Dictionary:
	var s := {item_id: 4}
	if str(def.get("furniture_type", "")) != "":
		s["ftype:" + str(def["furniture_type"])] = 3
	if str(def.get("slot", "")) != "":
		s["slot:" + str(def["slot"])] = 3
	if str(def.get("set", "")) != "":
		s["set:" + str(def["set"])] = 3
	if str(def.get("category", "")) != "":
		s["category:" + str(def["category"])] = 2
	s["rarity:" + str(def.get("rarity", "normal"))] = 1
	return s


## love / like / dislike / hate / neutral of an NPC for an item: the most specific selector wins, a tie goes to hate > dislike > love > like; NPC row > archetype row
## > universal (the same resolution as S-gifts' GiftRules and the Monte Carlo).
static func taste(data: Dictionary, npc: String, item_id: String) -> String:
	var tastes := LuaData.dict(data.get("gift_tastes", {}))
	var sels := selectors_of(item_id, LuaData.dict(LuaData.dict(data.get("items", {})).get(item_id, {})))
	var archetype := str(LuaData.dict(LuaData.dict(data.get("citizens", {})).get(npc, {})).get("archetype", "wanderer"))
	for row in [LuaData.dict(LuaData.dict(tastes.get("npcs", {})).get(npc, {})), LuaData.dict(LuaData.dict(tastes.get("archetypes", {})).get(archetype, {})), LuaData.dict(tastes.get("universal", {}))]:
		var best := ""
		var best_spec := 0
		var best_rank := 99
		for ci in CLASS_ORDER.size():
			for e in LuaData.arr((row as Dictionary).get(CLASS_ORDER[ci], [])):
				if sels.has(str(e)):
					var spec := int(sels[str(e)])
					if spec > best_spec or (spec == best_spec and ci < best_rank):
						best = CLASS_ORDER[ci]
						best_spec = spec
						best_rank = ci
		if best != "":
			return best
	return "neutral"


## The ordered pool of a festival's ordinary attendees, computed HERE (independently of SocialData.festival_roster, so the two can be compared): the home citizens of the
## festival's area without the host, without the keepers of stays_open shops and - when `remove_first` - without the `first` members, ordered by
## SocialRng.roll(seed, [festival, npc]) (a tie by id), the first social.festival.max_attendees of them. `remove_first` false is the NAIVE pool a regression would build.
static func ordered_pool(data: Dictionary, festival_id: String, world_seed: int, remove_first: bool = true) -> Array[String]:
	var meta := LuaData.dict(LuaData.dict(LuaData.dict(data.get("festivals", {})).get(festival_id, {})).get("meta", {}))
	var npcs := LuaData.dict(data.get("npcs", {}))
	var cap := LuaData.int_of(LuaData.dict(LuaData.dict(data.get("social", {})).get("festival", {})).get("max_attendees", 15), 15)
	var first := LuaData.strings(meta.get("first", []))
	var stays := LuaData.strings(meta.get("stays_open", []))
	var scored: Array = []
	var ids: Array = npcs.keys()
	ids.sort()
	for id in ids:
		var row := LuaData.dict(npcs[id])
		var sid := str(id)
		if str(row.get("home_area", "")) != str(meta.get("area", "")) or sid == str(meta.get("host", "")) or str(row.get("shop_id", "")) in stays or (remove_first and sid in first):
			continue
		scored.append([SocialRng.roll(world_seed, [festival_id, sid]), sid])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		return str(a[1]) < str(b[1]) if is_equal_approx(float(a[0]), float(b[0])) else float(a[0]) < float(b[0]))
	var out: Array[String] = []
	for i in mini(scored.size(), maxi(cap, 0)):
		out.append(str((scored[i] as Array)[1]))
	return out


# ================================================================================================ the mutant self-test

## Applies every mutant to a copy of the pristine data and checks that the validator reports an error with the RULE the mutant breaks. The pristine data itself must
## validate with no error (a pristine run that fails would make every "caught" meaningless). Returns {pristine_errors: Array, caught: Array, missed: Array, mutants: int}.
static func selftest(pristine: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var base := validate(pristine, opts)
	var caught: Array[String] = []
	var missed: Array[String] = []
	for m in mutants(pristine):
		var copy := pristine.duplicate(true)
		(m["apply"] as Callable).call(copy)
		var run_opts := opts.duplicate()
		if m.has("opts"):
			run_opts.merge(m["opts"], true)
		var got := validate(copy, run_opts)
		var codes := codes_of(got)
		if str(m["code"]) in codes:
			caught.append("%s %s" % [m["code"], m["label"]])
		else:
			missed.append("%s %s (reported %s)" % [m["code"], m["label"], str(codes)])
	return {"pristine_errors": base["errors"], "caught": caught, "missed": missed, "mutants": caught.size() + missed.size()}


## The mutants: {code, label, apply: Callable(data), opts?}. Each breaks exactly one rule of the pristine design data.
static func mutants(pristine: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fest_ids: Array = LuaData.dict(pristine.get("festivals", {})).keys()
	fest_ids.sort()
	var f0 := str(fest_ids[0]) if not fest_ids.is_empty() else ""
	var f1 := str(fest_ids[1]) if fest_ids.size() > 1 else f0
	out.append({"code": "SV1", "label": "citizens row of an unknown NPC", "apply": func(d: Dictionary) -> void: (d["citizens"] as Dictionary)["nobody_here"] = {"tier": "C", "archetype": "wanderer", "birthday": {"season": "sommer", "day": 3}}})
	out.append({"code": "SV1", "label": "gift_tastes row of an unknown NPC", "apply": func(d: Dictionary) -> void: ((d["gift_tastes"] as Dictionary)["npcs"] as Dictionary)["nobody_here"] = {"love": ["carrot"]}})
	out.append({"code": "SV2", "label": "tier X", "apply": func(d: Dictionary) -> void: (((d["citizens"] as Dictionary)["baker_maja"]) as Dictionary)["tier"] = "X"})
	out.append({"code": "SV2", "label": "archetype without a taste row", "apply": func(d: Dictionary) -> void: (((d["citizens"] as Dictionary)["baker_maja"]) as Dictionary)["archetype"] = "pirate"})
	out.append({"code": "SV3", "label": "birthday on a festival day", "apply": func(d: Dictionary) -> void: _move_birthday_to_festival(d, f0, 0)})
	out.append({"code": "SV3", "label": "birthday beside a festival", "apply": func(d: Dictionary) -> void: _move_birthday_to_festival(d, f1, 1)})
	out.append({"code": "SV3", "label": "two birthdays on one day", "apply": func(d: Dictionary) -> void: _same_birthday(d)})
	out.append({"code": "SV3", "label": "birthday on day 31", "apply": func(d: Dictionary) -> void: (((d["citizens"] as Dictionary)["baker_maja"] as Dictionary)["birthday"] as Dictionary).merge({"day": 31}, true)})
	out.append({"code": "SV5", "label": "taste selector that resolves to nothing", "apply": func(d: Dictionary) -> void: _list_of(((d["gift_tastes"] as Dictionary)["universal"]) as Dictionary, "love").append("category:no_such_category")})
	out.append({"code": "SV6", "label": "selector in two classes of one row", "apply": func(d: Dictionary) -> void: _selector_twice(d)})
	out.append({"code": "SV7", "label": "a friend with no giftable loved item", "apply": func(d: Dictionary) -> void: _starve_loves(d)})
	out.append({"code": "SV8", "label": "keeper sample that is not cheap", "apply": func(d: Dictionary) -> void: _bad_sample(d)})
	out.append({"code": "SV9", "label": "festival window ending after day_end_hour - 1", "apply": func(d: Dictionary) -> void: _festival(d, f0)["to"] = 26.0})
	out.append({"code": "SV9", "label": "festival host that is no NPC", "apply": func(d: Dictionary) -> void: _festival(d, f0)["host"] = "nobody_here"})
	out.append({"code": "SV9", "label": "stays_open names an unknown shop", "apply": func(d: Dictionary) -> void: _festival(d, f0)["stays_open"] = ["no_such_shop"]})
	out.append({"code": "SV9", "label": "activity kind outside the vocabulary", "apply": func(d: Dictionary) -> void: _first_activity(d, f0)["kind"] = "race"})
	out.append({"code": "SV10", "label": "event step outside the vocabulary", "apply": func(d: Dictionary) -> void: _first_event_steps(d).append({"act": "teleport"})})
	out.append({"code": "SV10", "label": "event reward above one heart", "apply": func(d: Dictionary) -> void: _first_event(d)["rewards"] = {"points": 150}})
	out.append({"code": "SV10", "label": "choice with four options", "apply": func(d: Dictionary) -> void: _first_event_steps(d).append({"act": "choice", "options": [{}, {}, {}, {}]})})
	out.append({"code":"SV10","label":"unknown event prerequisite","apply":func(d: Dictionary) -> void: _first_event(d)["meta"]["after"] = "missing_event"})
	out.append({"code":"SV10","label":"cyclic event prerequisite","apply":func(d: Dictionary) -> void: d["events"]["test_cycle_event"] = {"meta":{"after":"test_cycle_event"},"steps":[]}})
	out.append({"code": "SV11", "label": "first member that is no home citizen of the area", "apply": func(d: Dictionary) -> void: _festival(d, f0)["first"] = [_outsider_of(d, f0)]})
	out.append({"code": "SV11", "label": "guest that is a home citizen of the area", "apply": func(d: Dictionary) -> void: _festival(d, f0)["guests"] = [_insider_of(d, f0)]})
	out.append({"code": "SV11", "label": "a citizen twice in the roster", "apply": func(d: Dictionary) -> void: _festival(d, f0)["first"] = [_insider_of(d, f0), _insider_of(d, f0)]})
	out.append({"code": "SV11", "label": "crowd above towns.max_live_visuals_festival", "apply": func(d: Dictionary) -> void: (d["towns"] as Dictionary)["max_live_visuals_festival"] = 10})
	out.append({"code": "SV11", "label": "leave_early names an unknown citizen", "apply": func(d: Dictionary) -> void: _festival(d, f0)["leave_early"] = {"nobody_here": 1.0}})
	out.append({"code": "SV11", "label": "leave_early shorter than 1.5 x the walk + 15 minutes", "apply": func(d: Dictionary) -> void: _leave_too_short(d, f0), "opts": {"route_minutes": func(_n: String, _a: String, _s: String) -> float: return 40.0}})
	out.append({"code": "SV12", "label": "event when= with an unknown kind", "apply": func(d: Dictionary) -> void: (_first_event(d)["meta"] as Dictionary)["when"] = "moonphase:full"})
	out.append({"code":"SV12","label":"conditional step with an unknown kind","apply":func(d: Dictionary) -> void: _first_event(d)["steps"].append({"act":"wait","when":"moonphase:full"})})
	out.append({"code": "SV14", "label": "first prize above 2 x the cheapest winning entry", "apply": func(d: Dictionary) -> void: _contest(d, f0, {"item": "carrot", "amount": 100000}, "", "")})
	out.append({"code": "SV14", "label": "second prize above 0.7 x the first", "apply": func(d: Dictionary) -> void: _contest_ladder(d, f0, 1.0, 0.9, 0.2)})
	out.append({"code": "SV14", "label": "third prize above 0.4 x the first", "apply": func(d: Dictionary) -> void: _contest_ladder(d, f0, 1.0, 0.5, 0.6)})
	out.append({"code": "SV14", "label": "a keepsake as a prize", "apply": func(d: Dictionary) -> void: _contest(d, f0, _keepsake_id(d), "", "")})
	out.append({"code": "SV14", "label": "a prize that does not exist", "apply": func(d: Dictionary) -> void: _contest(d, f0, "no_such_item", "", "")})
	return out


static func _festival(d: Dictionary, fid: String) -> Dictionary:
	return (((d["festivals"] as Dictionary)[fid] as Dictionary)["meta"]) as Dictionary


static func _first_activity(d: Dictionary, fid: String) -> Dictionary:
	return ((((d["festivals"] as Dictionary)[fid] as Dictionary)["activities"]) as Array)[0] as Dictionary


static func _first_event(d: Dictionary) -> Dictionary:
	var ids: Array = (d["events"] as Dictionary).keys()
	ids.sort()
	return (d["events"] as Dictionary)[ids[0]] as Dictionary


static func _first_event_steps(d: Dictionary) -> Array:
	return _first_event(d)["steps"] as Array


static func _day_of(season: String, day: int, seasons: Array) -> int:
	return seasons.find(season) * 28 + day


static func _from_day(total: int, seasons: Array) -> Dictionary:
	var z := ((total - 1) % (seasons.size() * 28)) + 1
	return {"season": seasons[floori(float(z - 1) / 28.0)], "day": (z - 1) % 28 + 1}


static func _move_birthday_to_festival(d: Dictionary, fid: String, offset: int) -> void:
	var meta := _festival(d, fid)
	var seasons: Array = (d["time"] as Dictionary).get("seasons", DEFAULT_SEASONS)
	var date := _from_day(_day_of(str(meta["season"]), int(meta["day"]), seasons) + offset, seasons)
	((d["citizens"] as Dictionary)["baker_maja"] as Dictionary)["birthday"] = date


static func _same_birthday(d: Dictionary) -> void:
	var citizens := d["citizens"] as Dictionary
	(citizens["baker_maja"] as Dictionary)["birthday"] = (citizens["mayor_lyra"] as Dictionary)["birthday"]


static func _list_of(row: Dictionary, cls: String) -> Array:
	if not row.has(cls):
		row[cls] = []
	return row[cls] as Array


static func _selector_twice(d: Dictionary) -> void:
	var row := ((d["gift_tastes"] as Dictionary)["universal"]) as Dictionary
	var liked: Array = _list_of(row, "like")
	if not liked.is_empty():
		_list_of(row, "hate").append(liked[0])


static func _starve_loves(d: Dictionary) -> void:
	var tastes := d["gift_tastes"] as Dictionary
	for k in ["universal"]:
		(tastes[k] as Dictionary)["love"] = []
	for k in (tastes["archetypes"] as Dictionary):
		((tastes["archetypes"] as Dictionary)[k] as Dictionary)["love"] = []
	for k in (tastes["npcs"] as Dictionary):
		((tastes["npcs"] as Dictionary)[k] as Dictionary)["love"] = []


static func _bad_sample(d: Dictionary) -> void:
	var items := d["items"] as Dictionary
	var rare_id := ""
	for id in items:
		if str((items[id] as Dictionary).get("rarity", "normal")) == "rare":
			rare_id = str(id)
			break
	((d["citizens"] as Dictionary)["baker_maja"] as Dictionary)["sample"] = {"item": rare_id, "from_hearts": 2}


static func _home_citizens(d: Dictionary, fid: String) -> Array[String]:
	var area := str(_festival(d, fid).get("area", ""))
	var out: Array[String] = []
	for id in (d["npcs"] as Dictionary):
		if str(((d["npcs"] as Dictionary)[id] as Dictionary).get("home_area", "")) == area:
			out.append(str(id))
	out.sort()
	return out


static func _insider_of(d: Dictionary, fid: String) -> String:
	var host := str(_festival(d, fid).get("host", ""))
	for id in _home_citizens(d, fid):
		if id != host:
			return id
	return ""


static func _outsider_of(d: Dictionary, fid: String) -> String:
	var area := str(_festival(d, fid).get("area", ""))
	for id in (d["npcs"] as Dictionary):
		if str(((d["npcs"] as Dictionary)[id] as Dictionary).get("home_area", "")) != area:
			return str(id)
	return ""


static func _leave_too_short(d: Dictionary, fid: String) -> void:
	var who := _insider_of(d, fid)
	_festival(d, fid)["leave_early"] = {who: 0.25}


## A prize list for the SV14 mutants: the festival f gets a contest activity on category:crop and the rewards the caller built. The pristine data of the selftest gets a
## LEGAL ladder first (so SV14 is meaningful), then the mutation breaks one rung.
static func _contest(d: Dictionary, fid: String, first: Variant, second: Variant, third: Variant) -> void:
	var f := (d["festivals"] as Dictionary)[fid] as Dictionary
	f["activities"] = [{"id": "test_contest", "kind": "contest", "post": "fest_x_judge", "select": "category:crop"}]
	var rewards := {"first": first}
	if str(second) != "":
		rewards["second"] = second
	if str(third) != "":
		rewards["third"] = third
	f["rewards"] = {"contest": rewards}


static func _keepsake_id(d: Dictionary) -> String:
	for id in (d["items"] as Dictionary):
		if str(((d["items"] as Dictionary)[id] as Dictionary).get("rarity", "normal")) in KEEPSAKE_RARITIES:
			return str(id)
	return "carrot"


## A three prize ladder with the given VALUE ratios (first : second : third) built from `amount` of an item with a known sell value.
static func _contest_ladder(d: Dictionary, fid: String, a: float, b: float, c: float) -> void:
	var cap := minf(FIRST_PRIZE_FACTOR * cheapest_winning_entry(d["items"] as Dictionary, "category:crop"), FIRST_PRIZE_CAP_GOLD)
	var unit := LuaData.num(((d["items"] as Dictionary)["carrot"] as Dictionary).get("sell_price", 1), 1.0)
	var base := maxi(floori(cap / unit), 1)
	_contest(d, fid, {"item": "carrot", "amount": base}, {"item": "carrot", "amount": maxi(int(roundf(float(base) * b / a)), 1)}, {"item": "carrot", "amount": maxi(int(roundf(float(base) * c / a)), 1)})


# ================================================================================================ the run

class _Run extends RefCounted:
	var data: Dictionary
	var opts: Dictionary
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var skipped: Array[String] = []
	var stats: Dictionary = {}
	var items: Dictionary
	var npcs: Dictionary
	var citizens: Dictionary
	var tastes: Dictionary
	var festivals: Dictionary
	var events: Dictionary
	var shops: Dictionary
	var seasons: Array = []
	var dps := 28
	var day_start := 6
	var day_end := 26
	var cats := {}
	var ftypes := {}
	var slots := {}
	var sets := {}
	var friends: Array[String] = []
	var giftable_ids: Array[String] = []
	var no_tastes := false

	func e(code: String, msg: String) -> void:
		errors.append("%s: %s" % [code, msg])

	func w(code: String, msg: String) -> void:
		warnings.append("%s: %s" % [code, msg])

	func go() -> void:
		items = LuaData.dict(data.get("items", {}))
		npcs = LuaData.dict(data.get("npcs", {}))
		citizens = LuaData.dict(data.get("citizens", {}))
		tastes = LuaData.dict(data.get("gift_tastes", {}))
		festivals = LuaData.dict(data.get("festivals", {}))
		events = LuaData.dict(data.get("events", {}))
		shops = LuaData.dict(data.get("shops", {}))
		var time := LuaData.dict(data.get("time", {}))
		for s in LuaData.arr(time.get("seasons", SocialValidator.DEFAULT_SEASONS)):
			seasons.append(str(s))
		dps = LuaData.int_of(time.get("days_per_season", 28), 28)
		day_start = LuaData.int_of(time.get("day_start_hour", SocialValidator.DEFAULT_DAY_START), SocialValidator.DEFAULT_DAY_START)
		day_end = LuaData.int_of(time.get("day_end_hour", SocialValidator.DEFAULT_DAY_END), SocialValidator.DEFAULT_DAY_END)
		for id in items:
			var d := LuaData.dict(items[id])
			if str(d.get("category", "")) != "":
				cats[str(d["category"])] = true
			if str(d.get("furniture_type", "")) != "":
				ftypes[str(d["furniture_type"])] = true
			if str(d.get("slot", "")) != "":
				slots[str(d["slot"])] = true
			if str(d.get("set", "")) != "":
				sets[str(d["set"])] = true
			if SocialValidator.giftable(d):
				giftable_ids.append(str(id))
		giftable_ids.sort()
		for id in npcs:
			var row := LuaData.dict(npcs[id])
			if bool(row.get("friendship", false)) or not LuaData.dict(LuaData.dict(citizens.get(id, {})).get("unlock", {})).is_empty():
				friends.append(str(id))
		friends.sort()
		stats["friends"] = friends.size()
		stats["citizens"] = citizens.size()
		stats["festivals"] = festivals.size()
		stats["events"] = events.size()
		stats["giftable_items"] = giftable_ids.size()
		no_tastes = LuaData.dict(tastes.get("universal", {})).is_empty() and LuaData.dict(tastes.get("archetypes", {})).is_empty() and LuaData.dict(tastes.get("npcs", {})).is_empty()
		if no_tastes:
			skipped.append("SV2 / SV5 / SV6 / SV7: no gift_tastes data in the tree (lua/social/gift_tastes.lua is S-data's, wave 5): the archetype, selector and loved-item rules were NOT evaluated")
		_sv1_sv2_sv4()
		_sv3()
		if not no_tastes:
			_sv5_sv6()
			_sv7()
		_sv8()
		_sv9()
		_sv10()
		_sv11()
		_sv12()
		_sv14()

	# ---------------------------------------------------------------- SV1 / SV2 / SV4

	func _sv1_sv2_sv4() -> void:
		var arch := LuaData.dict(tastes.get("archetypes", {}))
		for n in citizens:
			if not npcs.has(n):
				e("SV1", "citizens row %s has no npcs.lua row" % n)
			var r := LuaData.dict(citizens[n])
			if str(r.get("tier", "")) not in SocialData.TIERS:
				e("SV2", "%s: tier %s" % [n, str(r.get("tier", ""))])
			if not no_tastes and not arch.has(str(r.get("archetype", ""))):
				e("SV2", "%s: archetype %s has no taste row" % [n, str(r.get("archetype", ""))])
		for n in friends:
			if not citizens.has(n):
				w("SV4", "%s can reach hearts but has no citizens row (derived defaults apply)" % n)
		for n in LuaData.dict(tastes.get("npcs", {})):
			if not npcs.has(n):
				e("SV1", "gift_tastes.npcs.%s is no NPC" % n)
		for role in LuaData.dict(LuaData.dict(data.get("social", {})).get("role_archetype", {})):
			var a := str(LuaData.dict(LuaData.dict(data.get("social", {})).get("role_archetype", {}))[role])
			if not no_tastes and not arch.is_empty() and not arch.has(a):
				e("SV2", "social.role_archetype.%s = %s has no taste row" % [role, a])

	# ---------------------------------------------------------------- SV3 birthdays

	func _td(season: String, day: int) -> int:
		return seasons.find(season) * dps + day

	func _festival_days() -> Dictionary:
		var out := {}
		for fid in festivals:
			var m := LuaData.dict(LuaData.dict(festivals[fid]).get("meta", {}))
			out[_td(str(m.get("season", "")), LuaData.int_of(m.get("day", 0)))] = str(fid)
		return out

	func _sv3() -> void:
		var fdays := _festival_days()
		var year := seasons.size() * dps
		var by_day := {}
		for n in citizens:
			var b: Variant = LuaData.dict(citizens[n]).get("birthday", null)
			if typeof(b) != TYPE_DICTIONARY:
				w("SV3", "%s: no birthday (derived)" % n)
				continue
			var season := str((b as Dictionary).get("season", ""))
			var day := LuaData.int_of((b as Dictionary).get("day", 0))
			if seasons.find(season) < 0 or day < 1 or day > dps:
				e("SV3", "%s: bad date %s" % [n, str(b)])
				continue
			var t := _td(season, day)
			if not by_day.has(t):
				by_day[t] = []
			(by_day[t] as Array).append(str(n))
			for off in [-1, 0, 1]:
				var raw: int = t + off
				var other := posmod(raw - 1, year) + 1
				if fdays.has(other):
					var where := "on" if off == 0 else "beside"
					if raw >= 1 and raw <= year:
						e("SV3", "%s: birthday %s %d is %s the day of %s" % [n, season, day, where, str(fdays[other])])
					else:
						w("SV3", "%s: birthday %s %d is %s the day of %s across the new year (the planner did not wrap)" % [n, season, day, where, str(fdays[other])])
		var days: Array = by_day.keys()
		days.sort()
		for t in days:
			if (by_day[t] as Array).size() > 1:
				e("SV3", "two birthdays on day %d: %s" % [t, str(by_day[t])])
		for i in days.size():
			var nxt := int(days[(i + 1) % days.size()])
			var gap := posmod(nxt - int(days[i]), year) if days.size() > 1 else year
			if days.size() > 1 and gap < 2 and gap > 0:
				var msg := "birthdays only %d day(s) apart (%s and %s)" % [gap, str(by_day[days[i]]), str(by_day[nxt])]
				if nxt > int(days[i]):
					e("SV3", msg)
				else:
					w("SV3", msg + " across the new year")

	# ---------------------------------------------------------------- SV5 / SV6 tastes

	func _sel_ok(sel: String) -> bool:
		if ":" in sel:
			var kind := sel.get_slice(":", 0)
			var value := sel.substr(sel.find(":") + 1)
			match kind:
				"category":
					return cats.has(value)
				"ftype":
					return ftypes.has(value)
				"slot":
					return slots.has(value)
				"set":
					return sets.has(value)
				"rarity":
					return value in ["normal", "uncommon", "rare"]
			return false
		return items.has(sel)

	func _rows() -> Array:
		var out: Array = [["universal", LuaData.dict(tastes.get("universal", {}))]]
		for k in LuaData.dict(tastes.get("archetypes", {})):
			out.append(["arch:" + str(k), LuaData.dict(LuaData.dict(tastes["archetypes"])[k])])
		for k in LuaData.dict(tastes.get("npcs", {})):
			out.append(["npc:" + str(k), LuaData.dict(LuaData.dict(tastes["npcs"])[k])])
		return out

	func _sv5_sv6() -> void:
		for pair in _rows():
			var name := str(pair[0])
			var row := pair[1] as Dictionary
			var seen := {}
			for cls in ["love", "like", "dislike", "hate"]:
				for s in LuaData.arr(row.get(cls, [])):
					var sel := str(s)
					if not _sel_ok(sel):
						e("SV5", "%s.%s: selector %s resolves to nothing" % [name, cls, sel])
					if seen.has(sel) and seen[sel] != cls:
						e("SV6", "%s: %s stands in %s and %s" % [name, sel, str(seen[sel]), cls])
					seen[sel] = cls
					if ":" not in sel and items.has(sel) and not SocialValidator.giftable(LuaData.dict(items[sel])) and cls in ["love", "like"]:
						w("SV5", "%s.%s: %s can never be given (not giftable)" % [name, cls, sel])

	# ---------------------------------------------------------------- SV7 reachable loves

	func _sv7() -> void:
		for n in friends:
			var loved := 0
			var liked := 0
			for i in giftable_ids:
				var t := SocialValidator.taste(data, n, i)
				if t == "love":
					loved += 1
				elif t == "like":
					liked += 1
			if loved < 3:
				e("SV7", "%s: only %d giftable loved items" % [n, loved])
			if liked < 6:
				w("SV7", "%s: only %d giftable liked items" % [n, liked])

	# ---------------------------------------------------------------- SV8 citizen extras (unlock, sample)

	func _sv8() -> void:
		for n in citizens:
			var r := LuaData.dict(citizens[n])
			if r.has("unlock"):
				var u := LuaData.dict(r["unlock"])
				if u.is_empty() or (not u.has("quest") and not u.has("day")):
					e("SV8", "%s: unlock needs a quest and / or a day" % n)
			if r.has("sample"):
				var s := LuaData.dict(r["sample"])
				var item := str(s.get("item", ""))
				var def := LuaData.dict(items.get(item, {}))
				if not items.has(item):
					e("SV8", "%s: sample item %s does not exist" % [n, item])
				else:
					if str(def.get("rarity", "normal")) != "normal":
						e("SV8", "%s: sample %s is %s, samples are normal items" % [n, item, str(def.get("rarity"))])
					if LuaData.num(def.get("sell_price", 0)) > SocialValidator.SAMPLE_MAX_SELL:
						e("SV8", "%s: sample %s sells for %s g, samples are <= %d g" % [n, item, str(def.get("sell_price")), SocialValidator.SAMPLE_MAX_SELL])
				var fh := LuaData.int_of(s.get("from_hearts", 0))
				if fh < 1 or fh > 10:
					e("SV8", "%s: sample from_hearts %d is not 1..10" % [n, fh])
				if str(LuaData.dict(npcs.get(n, {})).get("shop_id", "")) == "":
					w("SV8", "%s: a sample without a shop_id never reaches the player" % n)

	# ---------------------------------------------------------------- SV9 festivals

	func _window_end_limit() -> float:
		return float(day_end - 1)

	func _sv9() -> void:
		var used := {}
		for fid in festivals:
			var f := LuaData.dict(festivals[fid])
			var m := LuaData.dict(f.get("meta", {}))
			var season := str(m.get("season", ""))
			var day := LuaData.int_of(m.get("day", 0))
			if seasons.find(season) < 0 or day < 1 or day > dps:
				e("SV9", "%s: bad date %s %d" % [fid, season, day])
			var key := "%s:%d" % [season, day]
			if used.has(key):
				e("SV9", "%s and %s on the same day %s" % [fid, str(used[key]), key])
			used[key] = fid
			if (day - 1) % 7 < 5:
				w("SV9", "%s falls on a weekday (%d)" % [fid, (day - 1) % 7])
			var from_h := LuaData.num(m.get("from", 0))
			var to_h := LuaData.num(m.get("to", 0))
			# the window ends by day_end_hour - 1 (25.0 on the 26 hour day: the bed hold keeps one hour before the pass-out); the shipped data still ends by 23:00
			if not (float(day_start) <= from_h and from_h < to_h and to_h <= _window_end_limit()):
				e("SV9", "%s: window %s-%s must lie inside %d:00..%s (day_end_hour %d, the bed hold keeps one hour before the pass-out)" % [fid, str(from_h), str(to_h), day_start, str(_window_end_limit()), day_end])
			if to_h - from_h < 5.0:
				w("SV9", "%s: window shorter than 5 game hours" % fid)
			if not npcs.has(str(m.get("host", ""))):
				e("SV9", "%s: host %s is no NPC" % [fid, str(m.get("host", ""))])
			if str(m.get("area", "")) not in SocialValidator.FESTIVAL_AREAS:
				e("SV9", "%s: area %s" % [fid, str(m.get("area", ""))])
			if str(m.get("spot", "")) == "":
				e("SV9", "%s: no spot (fest_<spot>_host)" % fid)
			if str(m.get("closes", "all")) not in ["all", "none"]:
				e("SV9", "%s: closes must be all or none" % fid)
			for a in LuaData.arr(f.get("activities", [])):
				var act := LuaData.dict(a)
				if str(act.get("kind", "")) not in SocialValidator.ACTIVITY_KINDS:
					e("SV9", "%s.%s: kind %s" % [fid, str(act.get("id", "?")), str(act.get("kind", ""))])
				if str(act.get("kind", "")) in ["contest", "potluck"] and not _sel_ok(str(act.get("select", ""))):
					e("SV9", "%s.%s: select %s" % [fid, str(act.get("id", "?")), str(act.get("select", ""))])
				if str(act.get("kind", "")) == "market" and not shops.has(str(act.get("shop", ""))):
					w("SV9", "%s.%s: market shop %s is not defined yet (the activity stays hidden)" % [fid, str(act.get("id", "?")), str(act.get("shop", ""))])
			for s in LuaData.arr(m.get("stays_open", [])):
				if not shops.has(str(s)):
					e("SV9", "%s: stays_open names unknown shop %s" % [fid, str(s)])
			var sc := LuaData.dict(f.get("scenes", {}))
			for k in ["opening", "finale"]:
				if str(sc.get(k, "")) != "" and not events.has(str(sc[k])):
					w("SV9", "%s: scene %s is not authored yet (the generic scene is used)" % [fid, str(sc[k])])
			var host := str(m.get("host", ""))
			for s in LuaData.arr(m.get("stays_open", [])):
				if str(LuaData.dict(npcs.get(host, {})).get("shop_id", "")) == str(s):
					w("SV9", "%s: the host %s keeps the shop %s that stays open (he stands on the stage: the shop would have no keeper)" % [fid, host, str(s)])

	# ---------------------------------------------------------------- SV10 events

	func _sv10() -> void:
		var key_rx := RegEx.new()
		key_rx.compile("^[A-Z0-9_]+$")
		for eid in events:
			var ev := LuaData.dict(events[eid])
			var m := LuaData.dict(ev.get("meta", {}))
			var chain := {}
			var cursor := str(eid)
			while cursor != "":
				if not events.has(cursor):
					e("SV10", "%s: unknown prerequisite %s" % [eid,cursor])
					break
				if chain.has(cursor):
					e("SV10", "%s: cyclic event prerequisite %s" % [eid,cursor])
					break
				chain[cursor] = true
				cursor = str(LuaData.dict(LuaData.dict(events[cursor]).get("meta",{})).get("after",""))
			if str(m.get("npc", "")) != "" and not npcs.has(str(m["npc"])):
				e("SV10", "%s: npc %s" % [eid, str(m["npc"])])
			if m.has("hearts") and (LuaData.int_of(m["hearts"]) < 1 or LuaData.int_of(m["hearts"]) > 10):
				e("SV10", "%s: hearts %s" % [eid, str(m["hearts"])])
			for st in LuaData.arr(ev.get("steps", [])):
				var s := LuaData.dict(st)
				var act := str(s.get("act", ""))
				if act not in SocialValidator.STEP_ACTS:
					e("SV10", "%s: unknown step %s" % [eid, act])
				if act == "say":
					if str(s.get("who", "")) != "player" and not npcs.has(str(s.get("who", ""))):
						e("SV10", "%s: speaker %s" % [eid, str(s.get("who", ""))])
					if key_rx.search(str(s.get("text_key", ""))) == null:
						e("SV10", "%s: key %s" % [eid, str(s.get("text_key", ""))])
				if act == "choice":
					var n := LuaData.arr(s.get("options", [])).size()
					if n < 1 or n > 3:
						e("SV10", "%s: choice with %d options" % [eid, n])
				if act == "give" and not items.has(str(s.get("item", ""))):
					e("SV10", "%s: give %s" % [eid, str(s.get("item", ""))])
			if LuaData.int_of(LuaData.dict(ev.get("rewards", {})).get("points", 0)) > 100:
				e("SV10", "%s: reward points %s > one heart" % [eid, str(LuaData.dict(ev["rewards"])["points"])])

	# ---------------------------------------------------------------- SV11 the festival roster (ghost family amendment AGF17)

	func _home_citizens_of(area: String) -> Array[String]:
		var out: Array[String] = []
		for id in npcs:
			if str(LuaData.dict(npcs[id]).get("home_area", "")) == area:
				out.append(str(id))
		out.sort()
		return out

	func _sv11() -> void:
		var cap := LuaData.int_of(LuaData.dict(LuaData.dict(data.get("social", {})).get("festival", {})).get("max_attendees", 15), 15)
		var max_live := LuaData.int_of(LuaData.dict(data.get("towns", {})).get("max_live_visuals_festival", SocialValidator.DEFAULT_MAX_LIVE_FESTIVAL), SocialValidator.DEFAULT_MAX_LIVE_FESTIVAL)
		var route_fn: Variant = opts.get("route_minutes", null)
		var open_fn: Variant = opts.get("shop_open_hour", null)
		var walked := 0
		var needs_routes := false
		for fid in festivals:
			var m := LuaData.dict(LuaData.dict(festivals[fid]).get("meta", {}))
			var area := str(m.get("area", ""))
			var host := str(m.get("host", ""))
			var home := _home_citizens_of(area)
			var first: Array[String] = []
			var guests: Array[String] = []
			var seen := {host: "host"}
			for f in LuaData.strings(m.get("first", [])):
				first.append(f)
				if not npcs.has(f):
					e("SV11", "%s: first member %s is no NPC" % [fid, f])
				elif f not in home:
					e("SV11", "%s: first member %s is not a home citizen of %s (a first member is removed from the ordered pool of the area)" % [fid, f, area])
				if seen.has(f):
					e("SV11", "%s: %s appears twice in the roster (%s and first)" % [fid, f, str(seen[f])])
				seen[f] = "first"
			for g in LuaData.strings(m.get("guests", [])):
				guests.append(g)
				if not npcs.has(g):
					e("SV11", "%s: guest %s is no NPC" % [fid, g])
				elif g in home:
					e("SV11", "%s: guest %s IS a home citizen of %s (a guest comes from another area)" % [fid, g, area])
				if seen.has(g):
					e("SV11", "%s: %s appears twice in the roster (%s and guests)" % [fid, g, str(seen[g])])
				seen[g] = "guests"
			var crowd := cap + 1 + first.size() + guests.size()
			if crowd > max_live:
				e("SV11", "%s: crowd %d (max_attendees %d + host + %d first + %d guests) is above towns.max_live_visuals_festival %d" % [fid, crowd, cap, first.size(), guests.size(), max_live])
			# the ordered pool exactly like SocialManager.festival_roster builds it: the first members are REMOVED from the pool, the host and the keepers of stays_open shops are not in it
			var stays: Array[String] = []
			for s in LuaData.strings(m.get("stays_open", [])):
				stays.append(s)
			var pool_candidates: Array[String] = []
			for c in home:
				if c == host or c in first or str(LuaData.dict(npcs.get(c, {})).get("shop_id", "")) in stays:
					continue
				pool_candidates.append(c)
			stats["pool_%s" % fid] = pool_candidates.size()
			var leave := LuaData.dict(m.get("leave_early", {}))
			var from_h := LuaData.num(m.get("from", 0))
			var to_h := LuaData.num(m.get("to", 0))
			for who in leave:
				var hours := LuaData.num(leave[who])
				if not npcs.has(str(who)):
					e("SV11", "%s: leave_early names %s, who is no NPC" % [fid, str(who)])
					continue
				if hours <= 0.0 or hours > to_h - from_h:
					e("SV11", "%s: leave_early %s = %s is not within the window (%s hours)" % [fid, str(who), str(hours), str(to_h - from_h)])
					continue
				if not (str(who) in first or str(who) in guests or str(who) in home or str(who) == host):
					w("SV11", "%s: leave_early names %s who is not in the roster at all" % [fid, str(who)])
				# the walk: leaving `hours` before the window end, the keeper must stand at his counter 15 min before the deadline even when every walk takes 1.5 x as long
				if route_fn == null:
					needs_routes = true
					continue
				var shop := str(LuaData.dict(npcs.get(str(who), {})).get("shop_id", ""))
				var minutes := float((route_fn as Callable).call(str(who), area, str(m.get("spot", ""))))
				if minutes < 0.0:
					w("SV11", "%s: no route from the %s stage to the counter of %s: leave_early not measured" % [fid, str(m.get("spot", "")), str(who)])
					continue
				var deadline := to_h
				if str(m.get("closes", "all")) == "none" or shop in stays:
					var open_h := float((open_fn as Callable).call(shop, 0)) if open_fn != null else -1.0
					if open_h >= 0.0:
						deadline = minf(to_h, SocialValidator._norm(open_h, day_start))
				var need_hours := (SocialValidator.LEAVE_WALK_FACTOR * minutes + SocialValidator.LEAVE_WALK_MARGIN_MIN) / 60.0 + (to_h - deadline)
				walked += 1
				if hours + 1e-9 < need_hours:
					e("SV11", "%s: leave_early %s = %s h is shorter than 1.5 x the %s min walk + 15 min measured from the deadline %s (needs %s h)" % [fid, str(who), str(hours), str(minutes), str(deadline), str(snappedf(need_hours, 0.01))])
		stats["leave_early_measured"] = walked
		if needs_routes:
			skipped.append("SV11: leave_early walk rule not evaluated (no route_minutes: the route table of the towns track, T-routes, is not available to this run)")

	# ---------------------------------------------------------------- SV12 when= specs

	func _sv12() -> void:
		var fn: Variant = opts.get("when_errors", null)
		if fn == null:
			var sm := Svc.node("SocialManager")
			if sm != null and sm.has_method("when_spec_errors"):
				fn = Callable(sm, "when_spec_errors")
		if fn == null:
			skipped.append("SV12: when= specs not checked (no SocialManager.when_spec_errors available)")
			return
		for eid in events:
			var event := LuaData.dict(events[eid])
			var guarded: Array = [LuaData.dict(event.get("meta",{}))]+LuaData.arr(event.get("steps",[]))
			for row in guarded:
				var spec := str(LuaData.dict(row).get("when",""))
				if spec != "":
					for msg in (fn as Callable).call(spec):
						e("SV12", "%s: when=%s: %s" % [eid, spec, str(msg)])

	# ---------------------------------------------------------------- SV14 contest reward caps

	func _prize_of(entry: Variant) -> Dictionary:
		## {ids: [item ids], value: total sell value} of a reward entry: "item_id", {item, amount} or {items = {id = n}}.
		var ids: Array[String] = []
		var value := 0.0
		if typeof(entry) == TYPE_STRING or typeof(entry) == TYPE_STRING_NAME:
			ids.append(str(entry))
			value = LuaData.num(LuaData.dict(items.get(str(entry), {})).get("sell_price", 0))
		elif typeof(entry) == TYPE_DICTIONARY:
			var d := entry as Dictionary
			if d.has("item"):
				ids.append(str(d["item"]))
				value = LuaData.num(LuaData.dict(items.get(str(d["item"]), {})).get("sell_price", 0)) * float(maxi(LuaData.int_of(d.get("amount", 1), 1), 1))
			for k in LuaData.dict(d.get("items", {})):
				ids.append(str(k))
				value += LuaData.num(LuaData.dict(items.get(str(k), {})).get("sell_price", 0)) * float(LuaData.int_of(LuaData.dict(d["items"])[k], 1))
		return {"ids": ids, "value": value}

	func _sv14() -> void:
		var checked := 0
		for fid in festivals:
			var f := LuaData.dict(festivals[fid])
			var contests: Array[Dictionary] = []
			for a in LuaData.arr(f.get("activities", [])):
				if str(LuaData.dict(a).get("kind", "")) == "contest":
					contests.append(LuaData.dict(a))
			if contests.is_empty():
				continue
			for act in contests:
				var rewards := LuaData.dict(act.get("rewards", LuaData.dict(f.get("rewards", {})).get("contest", {})))
				if rewards.is_empty():
					w("SV14", "%s.%s: a contest without rewards.contest first / second / third" % [fid, str(act.get("id", "?"))])
					continue
				checked += 1
				var values := {}
				for place in ["first", "second", "third"]:
					if not rewards.has(place):
						if place == "first":
							e("SV14", "%s.%s: no first prize" % [fid, str(act.get("id", "?"))])
						continue
					var prize := _prize_of(rewards[place])
					var prize_ids: Array = prize["ids"]
					if prize_ids.is_empty():
						e("SV14", "%s.%s: %s prize names no item" % [fid, str(act.get("id", "?")), place])
					for pid in prize_ids:
						var def := LuaData.dict(items.get(str(pid), {}))
						if not items.has(str(pid)):
							e("SV14", "%s.%s: %s prize %s does not exist" % [fid, str(act.get("id", "?")), place, str(pid)])
							continue
						if str(def.get("rarity", "normal")) in SocialValidator.KEEPSAKE_RARITIES or bool(def.get("protected", false)):
							e("SV14", "%s.%s: %s prize %s is a keepsake" % [fid, str(act.get("id", "?")), place, str(pid)])
						elif str(def.get("rarity", "normal")) not in SocialValidator.PRIZE_RARITIES:
							e("SV14", "%s.%s: %s prize %s has rarity %s (at most rare)" % [fid, str(act.get("id", "?")), place, str(pid), str(def.get("rarity"))])
					values[place] = float(prize["value"])
				if not values.has("first"):
					continue
				var cheapest := SocialValidator.cheapest_winning_entry(items, str(act.get("select", "")))
				if cheapest <= 0.0:
					e("SV14", "%s.%s: the contest category %s has no giftable entry" % [fid, str(act.get("id", "?")), str(act.get("select", ""))])
					continue
				var cap := minf(SocialValidator.FIRST_PRIZE_FACTOR * cheapest, SocialValidator.FIRST_PRIZE_CAP_GOLD)
				var first_v := float(values["first"])
				if first_v > cap + 1e-6:
					e("SV14", "%s.%s: first prize %s g is above min(2 x the cheapest winning entry %s g, %s g) = %s g" % [fid, str(act.get("id", "?")), str(first_v), str(cheapest), str(SocialValidator.FIRST_PRIZE_CAP_GOLD), str(cap)])
				if values.has("second") and float(values["second"]) > SocialValidator.SECOND_FACTOR * first_v + 1e-6:
					e("SV14", "%s.%s: second prize %s g is above 0.7 x the first (%s g)" % [fid, str(act.get("id", "?")), str(values["second"]), str(first_v)])
				if values.has("third") and float(values["third"]) > SocialValidator.THIRD_FACTOR * first_v + 1e-6:
					e("SV14", "%s.%s: third prize %s g is above 0.4 x the first (%s g)" % [fid, str(act.get("id", "?")), str(values["third"]), str(first_v)])
		stats["contests_checked"] = checked


## An authored hour onto the raw game-hour axis (everything below the day start is after midnight: +24).
static func _norm(h: float, day_start: int) -> float:
	return h + 24.0 if h < float(day_start) else h
