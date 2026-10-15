extends RefCounted
## The validator rules of the buildings registry (package T-towns-core; TOWNS addendum 4.5 `hours.consistency`, task 2 schema, CLOCK_26 CK-A-TC): pure functions over a registry
## Dictionary (building id -> row), so the real registry, the fixture town and the MUTANTS of tests/lib/towns/mutate.gd go through the same code. Reused by T-routes (TownsValidate) and T-ext-content.
##
## schema_problems   the row schema {area, kind, name_key BLD_<ID>, interior, size, shop, keeper, owner, post, emblem, hours {open, close, closed, overrides, short_ok}, wave}
## hours_problems    a shop, service, public building or stall MUST have hours; a shop is open >= 6 game hours a day unless short_ok (a night shop); close <= the end of the game day (26) and
##                   open >= the start (6) on the 6..26 axis, EVALUATED ON THE NORMALISED CLOSE (close < open = after midnight: 1 -> 25.0); closed weekdays are 0..6; every hours entry has a keeper
##                   with a routine (npcs row `routine = true`)
## shop_problems     a shop id must exist; the LATE ids (wave 4 like this package: no dependency edge is possible) are listed by name, never failed
## service rule      a service row has no `shop` field (Uglehulen's appraisal is a game_event, not a ShopSystem shop)

const KINDS: Array[String] = ["shop", "service", "public", "stall", "home", "decor"]
const NEEDS_HOURS: Array[String] = ["shop", "service", "public", "stall"]
const SIZES: Array[String] = ["S", "M", "L"]
const WAVES: Array[String] = ["core", "ext"]
const AREAS: Array[String] = ["traetoppen", "hyggebyen"]
const ROW_KEYS: Array[String] = ["area", "kind", "name_key", "interior", "size", "shop", "keeper", "owner", "post", "emblem", "hours", "wave"]
const HOURS_KEYS: Array[String] = ["open", "close", "closed", "overrides", "short_ok"]
## The shop ids that are defined by packages of the SAME wave: listed by name as skipped, never failed.
const LATE_SHOP_IDS := {"timber_yard": "V1-cast-data", "natteblik_maps": "DR7-dungeon-services"}
const MIN_OPEN_HOURS := 6.0


static func problems(registry: Dictionary, opts: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	out.append_array(schema_problems(registry, opts))
	out.append_array(hours_problems(registry, opts))
	out.append_array(shop_problems(registry, opts)["problems"])
	return out


static func schema_problems(registry: Dictionary, opts: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var areas: Array = opts.get("areas", AREAS)
	var emblems: Array = opts.get("emblem_ids", [])
	for id in registry:
		var row: Variant = registry[id]
		if not (row is Dictionary):
			out.append("%s: the row is not a table" % id)
			continue
		var r: Dictionary = row
		for k in r:
			if not (str(k) in ROW_KEYS):
				out.append("%s: unknown field `%s`" % [id, k])
		for need in ["area", "kind", "name_key", "wave"]:
			if not r.has(need):
				out.append("%s: missing `%s`" % [id, need])
		var kind: String = str(r.get("kind", ""))
		if not (kind in KINDS):
			out.append("%s: kind `%s` is not one of %s" % [id, kind, str(KINDS)])
		if not (str(r.get("area", "")) in areas):
			out.append("%s: area `%s` is not one of %s" % [id, r.get("area", ""), str(areas)])
		if not (str(r.get("wave", "")) in WAVES):
			out.append("%s: wave `%s` is not core | ext" % [id, r.get("wave", "")])
		if str(r.get("name_key", "")) != "BLD_%s" % str(id).to_upper():
			out.append("%s: name_key must be BLD_%s, got `%s`" % [id, str(id).to_upper(), r.get("name_key", "")])
		var interior: String = str(r.get("interior", ""))
		if interior != "":
			if interior != "int_%s" % id:
				out.append("%s: interior must be int_%s, got `%s`" % [id, id, interior])
			if not (str(r.get("size", "")) in SIZES):
				out.append("%s: a building with an interior needs size S | M | L" % id)
			if kind in ["stall", "decor"]:
				out.append("%s: a %s has no interior" % [id, kind])
		elif r.has("size"):
			out.append("%s: size without an interior" % id)
		if kind in ["shop", "service", "public"] and interior == "":
			out.append("%s: a %s needs a room (interior)" % [id, kind])
		if kind in NEEDS_HOURS and str(r.get("keeper", "")) == "":
			out.append("%s: a %s needs a keeper" % [id, kind])
		if kind == "home" and str(r.get("owner", "")) == "":
			out.append("%s: a home needs an owner" % id)
		if kind in ["shop", "stall"] and str(r.get("shop", "")) == "":
			out.append("%s: a %s needs a shop id" % [id, kind])
		if kind == "service" and r.has("shop"):
			out.append("%s: a service row has NO shop id (its appraisal / bath / post are game events, not ShopSystem shops)" % id)
		if r.has("post") and not str(r["post"]).contains("."):
			out.append("%s: post `%s` must read <area or room>.<post>" % [id, r["post"]])
		if r.has("emblem") and not emblems.is_empty() and not (str(r["emblem"]) in emblems):
			out.append("%s: emblem `%s` is not one of the 15 plates" % [id, r["emblem"]])
		var h: Variant = r.get("hours", null)
		if h is Dictionary:
			for k in (h as Dictionary):
				if not (str(k) in HOURS_KEYS):
					out.append("%s: unknown hours field `%s`" % [id, k])
	return out


static func hours_problems(registry: Dictionary, opts: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var day_start: float = float(opts.get("day_start", 6.0))
	var day_end: float = float(opts.get("day_end", 26.0))
	var npcs: Dictionary = opts.get("npcs", {}) as Dictionary
	var check_keepers: bool = bool(opts.get("check_keepers", not npcs.is_empty()))
	for id in registry:
		var row: Variant = registry[id]
		if not (row is Dictionary):
			continue
		var r: Dictionary = row
		var kind: String = str(r.get("kind", ""))
		var h: Variant = r.get("hours", null)
		if kind in NEEDS_HOURS and not (h is Dictionary and not (h as Dictionary).is_empty()):
			out.append("%s: a %s must have opening hours" % [id, kind])
			continue
		if not (h is Dictionary) or (h as Dictionary).is_empty():
			continue
		var hd: Dictionary = h
		var short_ok: bool = bool(hd.get("short_ok", false))
		var spans: Array = [[hd.get("open", null), hd.get("close", null), "hours"]]
		var ov: Variant = hd.get("overrides", [])
		if ov is Array:
			for entry in (ov as Array):
				if entry is Dictionary:
					spans.append([(entry as Dictionary).get("open", null), (entry as Dictionary).get("close", null), "an override"])
					for wd in _list((entry as Dictionary).get("weekday", [])):
						if not _weekday_ok(wd):
							out.append("%s: override weekday %s is not 0..6" % [id, str(wd)])
		for s in spans:
			if not _num(s[0]) or not _num(s[1]):
				out.append("%s: %s need numeric open and close" % [id, s[2]])
				continue
			var o: float = _norm(float(s[0]), day_start)
			var c: float = _norm(float(s[1]), day_start)
			var c2: float = c + 24.0 if c < o else c
			if c2 > day_end:
				out.append("%s: %s close %s (normalised %s) is after the end of the game day (%s)" % [id, s[2], str(s[1]), str(c2), str(day_end)])
			if c2 - o <= 0.0:
				out.append("%s: %s are empty (open %s close %s)" % [id, s[2], str(s[0]), str(s[1])])
			elif c2 - o < MIN_OPEN_HOURS and not short_ok:
				out.append("%s: %s are open only %s game hours (< %s) and the row is not short_ok" % [id, s[2], str(c2 - o), str(MIN_OPEN_HOURS)])
		var closed: Array = _list(hd.get("closed", []))
		var seen: Dictionary = {}
		for wd in closed:
			if not _weekday_ok(wd):
				out.append("%s: closed weekday %s is not 0..6" % [id, str(wd)])
			if seen.has(int(wd)):
				out.append("%s: closed weekday %s is listed twice" % [id, str(wd)])
			seen[int(wd)] = true
		if closed.size() >= 7:
			out.append("%s: closed on all seven weekdays: it never opens" % id)
		if check_keepers:
			var keeper: String = str(r.get("keeper", ""))
			if keeper == "":
				out.append("%s: an hours entry needs a keeper" % id)
			elif not npcs.has(keeper):
				out.append("%s: keeper `%s` is not a citizen" % [id, keeper])
			elif not bool((npcs[keeper] as Dictionary).get("routine", false)):
				out.append("%s: keeper `%s` has no routine" % [id, keeper])
	return out


## {problems: Array[String], late_missing: Array[String]}: shop ids that no shop file defines are problems, the LATE ids are only listed when missing.
static func shop_problems(registry: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var known: Array = opts.get("known_shops", [])
	var late: Dictionary = opts.get("late", LATE_SHOP_IDS) as Dictionary
	var problems: Array[String] = []
	var late_missing: Array[String] = []
	if not bool(opts.get("check_shops", not known.is_empty())):
		return {"problems": problems, "late_missing": late_missing}
	for id in registry:
		var row: Variant = registry[id]
		if not (row is Dictionary) or not (row as Dictionary).has("shop"):
			continue
		var shop: String = str((row as Dictionary)["shop"])
		if shop in known:
			continue
		if late.has(shop):
			if not (shop in late_missing):
				late_missing.append(shop)
			continue
		problems.append("%s: shop id `%s` is defined by no shop file" % [id, shop])
	late_missing.sort()
	return {"problems": problems, "late_missing": late_missing}


static func _num(v: Variant) -> bool:
	return v is int or v is float


static func _norm(h: float, day_start: float) -> float:
	return h + 24.0 if h < day_start else h


static func _list(v: Variant) -> Array:
	return v as Array if v is Array else []


static func _weekday_ok(v: Variant) -> bool:
	return (v is int or v is float) and int(v) >= 0 and int(v) <= 6
