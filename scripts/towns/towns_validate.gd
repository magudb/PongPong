class_name TownsValidate
extends RefCounted
## The VALIDATORS of the town data (section tests/sections/towns_routines.gd + tools/towns/validate_towns.gd): every rule returns a list of problem strings (empty = pass).
## They only use the public API (Routines, Hours, RouteTable), so the same code runs on the shipped data and on mutated copies in the mutation checks.

const MAX_LIVE := 14          # = towns.plan_visual_peak (the hard cap towns.max_live_visuals is 16)
const ACTS := ["away", "eat", "fish", "guard", "inside", "patrol", "perch", "play", "sit", "sleep", "stand", "tend", "work", "hide", "walk", "lamp", "read", "chat", "bathe"]


## routines.feasible: every plan (clear + rainy) compiles: arrivals are on time, no leg is estimated, every place has a baked route.
static func routines_feasible() -> Array[String]:
	Routines.clear_cache()
	var out: Array[String] = []
	for npc in Routines.npc_ids():
		var def: Dictionary = Routines.registry()[npc]
		for plan in (def.get("plans", {}) as Dictionary):
			for block in LuaData.arr(LuaData.dict(def.plans[plan]).get("blocks", [])):
				if str(block.get("act", "stand")) not in ACTS:
					out.append("%s/%s: unknown act %s" % [npc, plan, block.get("act")])
			for rain in [false, true]:
				var segs: Array = Routines.timeline(npc, str(plan), rain)
				for s in segs:
					if str(s["kind"]) == "move":
						for l in (s["legs"] as Array):
							if bool((l as Dictionary).get("estimated", false)):
								out.append("%s/%s: no baked route %s -> %s" % [npc, plan, s["from"], s["to"]])
	out.append_array(Routines.compile_problems)
	var seen: Dictionary = {}
	var uniq: Array[String] = []
	for p in out:
		if not seen.has(p):
			seen[p] = true
			uniq.append(p)
	return uniq


## routines.places_exist: every `at` is an anchor of the route table (or nowhere), every home / work / shelter too. `home.` / `work.` places degrade to the door and `?` places drop
## when their room is missing: that is not a problem, it is counted in `degraded_info` (the section prints it).
static var degraded_info: Array[String] = []


static func places_exist() -> Array[String]:
	degraded_info = []
	var out: Array[String] = []
	for npc in Routines.npc_ids():
		var def: Dictionary = Routines.registry()[npc]
		var places: Array = [str(def.get("shelter", ""))]
		for plan in (def.get("plans", {}) as Dictionary):
			for b in ((def["plans"][plan] as Dictionary).get("blocks", []) as Array):
				places.append(str((b as Dictionary)["at"]))
		for p in places:
			if p == "" or p == "nowhere":
				continue
			var rp: Dictionary = Routines.resolve_place(npc, p)
			if bool(rp["dropped"]):
				degraded_info.append("%s: optional place %s dropped" % [npc, p])
				continue
			if bool(rp["inside"]):
				degraded_info.append("%s: %s degrades to the door (inside)" % [npc, p])
			var q: String = str(rp["at"]).trim_prefix("away:")
			if q != "nowhere" and not RouteTable.has_anchor(q):
				out.append("%s: place %s is not a baked anchor" % [npc, p])
		if not (def.get("plans", {}) as Dictionary).has(str(((def.get("select", []) as Array)[-1] as Dictionary).get("plan", ""))):
			out.append("%s: the last select rule names a plan that does not exist" % npc)
		for r in (def.get("select", []) as Array):
			if not (def.get("plans", {}) as Dictionary).has(str((r as Dictionary).get("plan", ""))):
				out.append("%s: select names the unknown plan %s" % [npc, (r as Dictionary).get("plan", "")])
		if not ((def.get("select", []) as Array)[-1] as Dictionary).get("when", {}).is_empty():
			out.append("%s: the last select rule must have no `when` (a day without a plan)" % npc)
	return out


## hours.keeper_covers_hours: on every open weekday the keeper stands at the building's post from open to close (clear and rainy weather).
static func keepers_cover_hours() -> Array[String]:
	var out: Array[String] = []
	var reg: Dictionary = Hours.registry()
	for bid in reg:
		var b: Dictionary = reg[bid]
		if not b.has("hours") or not b.has("keeper"):
			continue
		var hrs: Dictionary = b["hours"]
		var post: String = str(b.get("post", ""))
		for wd in 7:
			if wd in Hours.closed_days(b):
				continue
			var oc: Array = Hours.hours_on(b, wd)
			var o: float = float(oc[0])
			var c: float = float(oc[1])
			for weather in ["klart", "regn"]:
				var ctx: Dictionary = Routines.make_ctx(wd, 12.0, weather, {"hearts": {str(b["keeper"]): 10}, "done": {"lost_cat": true}, "total_day": 99})
				var npc: String = str(b["keeper"])
				var plan: String = Routines.plan_name(npc, ctx)
				var segs: Array = Routines.timeline(npc, plan, weather == "regn")
				var ok: bool = false
				for s in segs:
					if str(s["kind"]) == "stay" and str(s["place"]) == post and float(s["t0"]) <= o + 1e-6 and float(s["t1"]) >= c - 1e-6:
						ok = true
				if not ok:
					out.append("%s: keeper %s is not at %s for %s-%s on weekday %d (%s, plan %s)" % [bid, npc, post, Hours.format_hour(o), Hours.format_hour(c), wd, weather, plan])
	return out


## hours.consistency: every building with a keeper has hours or is a home; every shop id of a building exists; no building opens after it closes unless it wraps on purpose.
static func hours_consistency(shop_ids: Array) -> Array[String]:
	var out: Array[String] = []
	var reg: Dictionary = Hours.registry()
	for bid in reg:
		var b: Dictionary = reg[bid]
		var kind: String = str(b.get("kind", ""))
		if kind in ["shop", "service", "public", "stall"] and not b.has("hours"):
			out.append("%s: a %s needs hours" % [bid, kind])
		if b.has("shop") and not (str(b["shop"]) in shop_ids):
			out.append("%s: shop %s is not a shop id" % [bid, b["shop"]])
		if b.has("hours"):
			var h: Dictionary = b["hours"]
			if float(h["close"]) - float(h["open"]) < 6.0 and float(h["close"]) > float(h["open"]) and not bool(h.get("short_ok", false)):
				out.append("%s: open %.1f-%.1f is under 6 game hours (3 real minutes): too short to play" % [bid, h["open"], h["close"]])
			if not b.has("keeper"):
				out.append("%s: hours without a keeper" % bid)
			elif not Routines.registry().has(str(b["keeper"])):
				out.append("%s: keeper %s has no routine" % [bid, b["keeper"]])
	return out


## routines.post_capacity: at most one citizen at an anchor (counted when standing, every 10 game minutes, 7 weekdays x clear / rain).
static func post_capacity(step_min: int = 10) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for wd in 7:
		for weather in ["klart", "regn"]:
			for m in range(6 * 60, int(Routines.day_end()) * 60, step_min):
				var ctx: Dictionary = Routines.make_ctx(wd, float(m) / 60.0, weather, {"hearts": {}, "total_day": 99, "done": {"lost_cat": true}})
				var at: Dictionary = {}
				for npc in Routines.npc_ids():
					var w: Dictionary = Routines.where_is(npc, ctx)
					if str(w["state"]) == "stay":
						var p: String = str(w["place"])
						if not at.has(p):
							at[p] = []
						(at[p] as Array).append(npc)
						if (at[p] as Array).size() > RouteTable.capacity(p):
							var sk: String = "%s|%s" % [p, ",".join(at[p])]
							if not seen.has(sk):
								seen[sk] = true
								out.append("%s: %s at once, capacity %d (weekday %d %s %s)" % [p, ",".join(at[p]), RouteTable.capacity(p), wd, weather, Hours.format_hour(float(m) / 60.0)])
	return out


## towns.visual_budget: distinct sprite sheets live per area at any half hour <= max_live (interiors are separate areas). visuals: npc -> visual id.
static func visual_budget(visuals: Dictionary, max_live: int = MAX_LIVE, step_min: int = 5) -> Array[String]:
	var out: Array[String] = []
	var worst: Dictionary = {}
	for wd in 7:
		for m in range(6 * 60, int(Routines.day_end()) * 60, step_min):
			var ctx: Dictionary = Routines.make_ctx(wd, float(m) / 60.0, "klart", {"hearts": {}, "total_day": 99, "done": {"lost_cat": true}})
			var per: Dictionary = {}
			for npc in Routines.npc_ids():
				var w: Dictionary = Routines.where_is(npc, ctx)
				if str(w["state"]) in ["stay", "move"]:
					var area: String = str(w["area"])
					if not per.has(area):
						per[area] = {}
					(per[area] as Dictionary)[str(visuals.get(npc, npc))] = true
			for area in per:
				var n: int = (per[area] as Dictionary).size()
				if n > int((worst.get(area, {"n": 0}) as Dictionary)["n"]):
					worst[area] = {"n": n, "wd": wd, "hour": float(m) / 60.0}
				if n > max_live:
					out.append("%s: %d distinct visuals live on weekday %d at %s (max %d)" % [area, n, wd, Hours.format_hour(float(m) / 60.0), max_live])
	budget_worst = worst
	return out


static var budget_worst: Dictionary = {}


## routines.no_short_visits: nobody enters a room for less than 6 game minutes (door ping-pong), and nobody enters the same room twice within 20 game minutes.
static func no_short_visits() -> Array[String]:
	var out: Array[String] = []
	for npc in Routines.npc_ids():
		var def: Dictionary = Routines.registry()[npc]
		for plan in (def.get("plans", {}) as Dictionary):
			for rain in [false, true]:
				var segs: Array = Routines.timeline(npc, str(plan), rain)
				var visits: Array = []        # [area, t_in, t_out] maximal runs of segments in one interior area
				for s in segs:
					var a_in: String = ""
					var t_in: float = float(s["t0"])
					var t_out: float = float(s["t1"])
					if str(s["kind"]) == "stay":
						var pl: String = str(s["place"])
						if pl.begins_with("int_"):
							a_in = pl.get_slice(".", 0)
					else:
						for l in (s["legs"] as Array):
							if str((l as Dictionary)["kind"]) == "walk" and str((l as Dictionary)["area"]).begins_with("int_"):
								a_in = str((l as Dictionary)["area"])
								t_in = float((l as Dictionary)["t0"])
								t_out = float((l as Dictionary)["t1"])
					if a_in == "":
						continue
					if not visits.is_empty() and str((visits[-1] as Array)[0]) == a_in and absf(float((visits[-1] as Array)[2]) - t_in) < 0.02:
						(visits[-1] as Array)[2] = t_out
					else:
						visits.append([a_in, t_in, t_out])
				var last_out: Dictionary = {}
				for vis in visits:
					var dur: float = float(vis[2]) - float(vis[1])
					if dur < 0.1 and float(vis[2]) < Routines.day_end() - 0.1:
						out.append("%s/%s: only %d game min in %s" % [npc, plan, roundi(dur * 60.0), vis[0]])
					if last_out.has(vis[0]) and float(vis[1]) - float(last_out[vis[0]]) < 20.0 / 60.0:
						out.append("%s/%s: enters %s again %d game min after leaving it" % [npc, plan, vis[0], roundi((float(vis[1]) - float(last_out[vis[0]])) * 60.0)])
					last_out[vis[0]] = float(vis[2])
	return out


## routines.day_wrap: a citizen wakes up where he went to sleep: the first block of every plan and the last block of every plan are in the same room (or the same
## door anchor, or both `nowhere`). Without this the first minute of the morning would teleport the citizen.
static func day_wrap() -> Array[String]:
	var out: Array[String] = []
	for npc in Routines.npc_ids():
		var def: Dictionary = Routines.registry()[npc]
		var homes: Dictionary = {}
		for plan in (def.get("plans", {}) as Dictionary):
			var blocks: Array = Routines.plan_blocks(npc, str(plan))
			if blocks.is_empty():
				out.append("%s/%s: empty plan" % [npc, plan])
				continue
			for end in [0, blocks.size() - 1]:
				var at: String = str((blocks[end] as Dictionary)["at"]).trim_prefix("away:")
				homes[at.get_slice(".", 0) if at.begins_with("int_") else at] = true
		if homes.size() > 1:
			out.append("%s: the plans start / end in different rooms %s" % [npc, str(homes.keys())])
	return out


## hours.visits_inside_hours: a citizen who is a CUSTOMER of a shop or service (any post of its room that is not the keeper's or the staff's) is only there when it is open.
static func visits_inside_hours() -> Array[String]:
	var out: Array[String] = []
	var reg: Dictionary = Hours.registry()
	var by_interior: Dictionary = {}
	for bid in reg:
		var b: Dictionary = reg[bid]
		if b.has("interior") and b.has("hours"):
			by_interior[str(b["interior"])] = bid
	for npc in Routines.npc_ids():
		var def: Dictionary = Routines.registry()[npc]
		for plan in (def.get("plans", {}) as Dictionary):
			for rain in [false, true]:
				var segs: Array = Routines.timeline(npc, str(plan), rain)
				for s in segs:
					if str(s["kind"]) != "stay":
						continue
					var place: String = str(s["place"])
					if not place.begins_with("int_"):
						continue
					var area: String = place.get_slice(".", 0)
					if not by_interior.has(area):
						continue
					var post: String = place.get_slice(".", 1)
					var b2: Dictionary = reg[by_interior[area]]
					if post in ["counter", "work", "tub", "throne", "bed", "perch", "mayor_desk"] or str(b2.get("keeper", "")) == npc:
						continue
					# the plan applies on some weekdays: find them through the select rules
					var days: Array = []
					for wd in 7:
						if Routines.plan_name(npc, Routines.make_ctx(wd, 12.0, "regn" if rain else "klart", {"hearts": {npc: 10}, "total_day": 99, "done": {"lost_cat": true}})) == str(plan):
							days.append(wd)
					for wd in days:
						var oc2: Array = Hours.hours_on(b2, wd)
						if wd in Hours.closed_days(b2) or float(s["t0"]) < float(oc2[0]) - 1e-6 or float(s["t1"]) > float(oc2[1]) + 1e-6:
							out.append("%s/%s: customer in %s %s-%s but %s is open %s-%s (weekday %d)" % [npc, plan, area, Hours.format_hour(float(s["t0"])), Hours.format_hour(float(s["t1"])), by_interior[area], Hours.format_hour(float(oc2[0])), Hours.format_hour(float(oc2[1])), wd])
							break
	return out
