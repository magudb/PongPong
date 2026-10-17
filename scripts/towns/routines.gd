class_name Routines
extends RefCounted
## The ROUTINE RESOLVER: where_is(npc, ctx) is a PURE function of (routine data, calendar, weather, flags). Nothing is simulated: parked areas do not tick, the clock only
## runs while PLAYING, and a sleep skips hours, so presence is recomputed from the data whenever somebody looks (area enter, minute tick, day start).
## Data: Lua registry `routines` (kind = "registry", one file per citizen: lua/routines/<npc>.lua):
##   routines.<npc> = { home, work?, priority, shelter, hero_twin?, gate?, plans = { <plan> = { blocks = { {from?, at, act, leave?, stay?} } } }, select = { {plan, when?} } }
##   block: `at` = anchor `area.name`, `nowhere`, or `away:<anchor>` (off stage behind that anchor: the citizen walks to it and leaves through it, e.g. the Skovlift);
##          `home.<post>` / `work.<post>` = a post of the citizen's own home / work room: when that room is not built (an EXTENDED package, or a data-only citizen without a room) the
##          citizen is "inside" at the building's door instead; a trailing `?` makes a place OPTIONAL: when the anchor does not exist the block is dropped (a visit to a room that is not there); `from` = arrive by this hour (omitted = as soon as the walk from the previous place is done);
##          `leave` = leave at this hour, `stay` = leave this many hours after arriving; both omitted = leave in time for the next block's `from`.
##   when:  weekday {0..6}, season {..}, weather {..}, festival "id"|true, flag "name", not_flag "name", min_hearts n (hearts with THIS citizen), done_quest "id",
##          day_min n (total_day >=), day_max n (total_day <=), not_hero "id".
## FESTIVAL DAYS: when the social track says a festival runs today (ctx.fest = {id, from, to, area, spot}) the resolver asks `ctx.override_fn(npc, total_day, from)` (production:
##   SocialManager.override_for) once per citizen: {area, post, state} puts the citizen on that post for [from, to) (he leaves in time and walks home afterwards); {} = the routine goes on.
## Time is in game HOURS (6.5 = 06:30). A move takes the baked walking time of RouteTable (door-to-door, through portals); the citizen leaves early enough to arrive by `from`.

const DAY_START := 6.0
const DWELL_MIN := 0.05

static func day_end() -> float:
	var gm := GameData.gm()
	return float(gm.call("day_end_hour")) if gm != null else 26.0

const RAIN_ACTS: Array[String] = ["sit", "tend", "play", "fish"]

static var _tl: Dictionary = {}
static var compile_problems: Array[String] = []
static var override_registry: Dictionary = {}    # tests: replaces the Lua registry
static var _fb: Dictionary = {}                  # "npc|day|festival" -> festival block (the social track is asked once per citizen and day)


static func registry() -> Dictionary:
	if not override_registry.is_empty():
		return override_registry
	var lr: Node = GameData.lua()
	return lr.call("get_registry", "routines") if lr != null and lr.has_method("get_registry") else {}


static func npc_ids() -> Array:
	var ids: Array = registry().keys()
	ids.sort()
	return ids


static func clear_cache() -> void:
	_tl.clear()
	_fb.clear()
	compile_problems.clear()


## A context for an explicit moment (tests, validators, the director).
static func make_ctx(weekday: int, hour: float, weather: String = "klart", extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"weekday": weekday, "hour": hour, "weather": weather, "season": "foraar", "total_day": 1, "hearts": {}, "flags": {}, "done": {}, "hero": "", "festival": ""}
	c.merge(extra, true)
	return c


## The context of "now" from the live game (autoloads reached through GameData so `-s` drivers compile).
static func now_ctx() -> Dictionary:
	var gm: Node = GameData.gm()
	var tm: Node = GameData.tm()
	var c: Dictionary = make_ctx(0, 6.0)
	if gm == null:
		return c
	c["hour"] = float(gm.get("hour")) + float(gm.get("minute")) / 60.0
	c["total_day"] = int(gm.call("total_day"))
	c["season"] = str(gm.get("season"))
	if tm != null:
		c["weekday"] = int(tm.call("weekday_index"))
		c["weather"] = str(tm.get("weather"))
	c["hero"] = str(gm.call("get_flag", &"hero_id", CharacterCatalog.hero_of_skin(StringName(str(gm.get("character_skin")))).get("id", "")))
	var qm := Svc.node("QuestManager")
	if qm != null and qm.has_method("get_completed_ids"):
		for quest in qm.call("get_completed_ids"):
			c["done"][str(quest)] = true
	c["_gm"] = gm
	var sm: Node = Svc.node("SocialManager")            # late-bound: the social track may not be built yet (no festival, no override, nothing closes)
	if sm != null and sm.has_method("festival_today"):
		var fid: String = str(sm.call("festival_today"))
		if fid != "":
			c["festival"] = fid
			var meta: Dictionary = GameData.dict_of(GameData.dict_of(_festival_def(fid)).get("meta", {}))
			c["fest"] = {"id": fid, "from": float(meta.get("from", 12)), "to": float(meta.get("to", 20)), "area": str(meta.get("area", "")), "spot": str(meta.get("spot", ""))}
			if sm.has_method("override_for"):
				c["override_fn"] = Callable(sm, "override_for")
			if sm.has_method("shop_closed_by_festival"):
				c["fest_closed_fn"] = Callable(sm, "shop_closed_by_festival")
	if sm != null and sm.has_method("home_routine_context"):c.merge(sm.call("home_routine_context"))
	return c


static func _festival_def(fid: String) -> Dictionary:
	return SocialData.festival(fid)


## true when the citizen is not part of the game for this player: the other hero's twin, or a gate (a quest / a day) that has not opened yet. NOT true for asleep / away / indoors.
static func is_unavailable(npc: String, ctx: Dictionary) -> bool:
	var def: Dictionary = registry().get(npc, {})
	if def.is_empty():
		return false
	var gate: Dictionary = def.get("gate", {}) as Dictionary
	if not gate.is_empty():
		var ok: bool = bool((ctx.get("done", {}) as Dictionary).get(str(gate.get("done_quest", "")), false)) or int(ctx.get("total_day", 1)) >= int(gate.get("or_day", 1 << 30))
		if not ok:
			return true
	return def.has("hero_twin") and str(def["hero_twin"]) == str(ctx.get("hero", ""))


## The festival block of one citizen today: {from, to, at, area, post} or {} (no festival, the routine goes on).
static func festival_block(npc: String, ctx: Dictionary) -> Dictionary:
	var fest: Dictionary = ctx.get("fest", {}) as Dictionary
	var fn: Variant = ctx.get("override_fn", null)
	if fest.is_empty() or not (fn is Callable) or not (fn as Callable).is_valid():
		return {}
	var ov: Variant = (fn as Callable).call(npc, int(ctx.get("total_day", 1)), int(floor(float(fest["from"]))))
	if not (ov is Dictionary) or str((ov as Dictionary).get("post", "")) == "" or str((ov as Dictionary).get("state", "stay")) in ["absent", "away"]:
		return {}
	var area: String = str((ov as Dictionary).get("area", fest.get("area", "")))
	return {"from": float(fest["from"]), "to": float((ov as Dictionary).get("until",fest["to"])), "at": "%s.%s" % [area, str((ov as Dictionary)["post"])], "area": area, "post": str((ov as Dictionary)["post"])}


static func hearts_of(ctx: Dictionary, npc: String) -> int:
	var h: Variant = (ctx.get("hearts", {}) as Dictionary).get(npc, null)
	if h != null:
		return int(h)
	var sm: Node = Svc.node("SocialManager")         # the social track's hearts (whole hearts); the flag mirror friend_<npc> is the fallback
	if sm != null and sm.has_method("hearts"):
		return int(sm.call("hearts", npc))
	var gm: Variant = ctx.get("_gm", null)
	return int((gm as Node).call("flag_int", StringName("friend_" + npc), 0)) if gm is Node else 0


static func matches(when: Dictionary, ctx: Dictionary, npc: String) -> bool:
	for k in when:
		var v: Variant = when[k]
		match str(k):
			"weekday":
				if not (int(ctx["weekday"]) in _ints(v)):
					return false
			"season":
				if not (str(ctx["season"]) in _strs(v)):
					return false
			"weather":
				if not (str(ctx["weather"]) in _strs(v)):
					return false
			"festival":
				var f: String = str(ctx.get("festival", ""))
				if (v is bool and (v as bool) != (f != "")) or (v is String and f != str(v)):
					return false
			"flag":
				if not _flag(ctx, str(v)):
					return false
			"not_flag":
				if _flag(ctx, str(v)):
					return false
			"min_hearts":
				if hearts_of(ctx, npc) < int(v):
					return false
			"done_quest":
				if not bool((ctx.get("done", {}) as Dictionary).get(str(v), false)):
					return false
			"day_min":
				if int(ctx.get("total_day", 1)) < int(v):
					return false
			"day_max":
				if int(ctx.get("total_day", 1)) > int(v):
					return false
			"not_hero":
				if str(ctx.get("hero", "")) == str(v):
					return false
			_:
				push_warning("Routines: unknown `when` key %s" % k)
				return false
	return true


static func _flag(ctx: Dictionary, name: String) -> bool:
	var fl: Dictionary = ctx.get("flags", {})
	if fl.has(name):
		return bool(fl[name])
	var gm: Variant = ctx.get("_gm", null)
	return gm is Node and bool((gm as Node).call("get_flag", StringName(name), false))


static func _ints(v: Variant) -> Array:
	var out: Array = []
	for x in (v as Array if v is Array else [v]):
		out.append(int(x))
	return out


static func _strs(v: Variant) -> Array:
	var out: Array = []
	for x in (v as Array if v is Array else [v]):
		out.append(str(x))
	return out


## One `at` of a block, resolved against the route table: {at, inside: bool (degraded to the door), dropped: bool (optional and missing), alias: bool}.
static func resolve_place(npc: String, at: String) -> Dictionary:
	var def: Dictionary = registry().get(npc, {})
	var optional: bool = at.ends_with("?")
	var p: String = at.trim_suffix("?")
	var away: bool = p.begins_with("away:")
	p = p.trim_prefix("away:")
	var degraded: bool = false
	var alias: bool = false
	for role in ["home", "work"]:
		if p.begins_with(role + "."):
			alias = true
			var b: String = str(def.get(role, ""))
			var room: String = "int_%s.%s" % [b, p.substr(role.length() + 1)]
			if b != "" and RouteTable.has_anchor(room):
				p = room
			else:
				p = "%s.door_%s" % [str(def.get(role + "_area", def.get("home_area", ""))), b]
				degraded = true
			break
	if optional and p != "nowhere" and not RouteTable.has_anchor(p):
		return {"at": p, "inside": false, "dropped": true, "alias": alias}
	return {"at": ("away:" if away else "") + p, "inside": degraded, "dropped": false, "alias": alias}


## The blocks of one plan with every place resolved (the validators and the compiler read this, never the raw data).
static func plan_blocks(npc: String, plan: String) -> Array:
	var def: Dictionary = registry().get(npc, {})
	var out: Array = []
	var plan_def: Dictionary = ((def.get("plans", {}) as Dictionary).get(plan, {}) as Dictionary)
	for b in (plan_def.get("blocks", []) as Array):
		var nb: Dictionary = (b as Dictionary).duplicate()
		var rp: Dictionary = resolve_place(npc, str(nb["at"]))
		if bool(rp["dropped"]):
			continue
		nb["at"] = rp["at"]
		if bool(rp["inside"]):
			nb["act"] = "inside"
		out.append(nb)
	return out


static func plan_name(npc: String, ctx: Dictionary, definition: Dictionary = {}) -> String:
	var def: Dictionary = definition if not definition.is_empty() else registry().get(npc, {})
	for r in (def.get("select", []) as Array):
		var rd: Dictionary = r
		if matches(rd.get("when", {}) as Dictionary, ctx, npc):
			return str(rd.get("plan", ""))
	return ""


static func is_rainy(ctx: Dictionary) -> bool:
	return str(ctx.get("weather", "klart")) in ["regn", "torden"]


## The compiled day of one citizen: [{kind: "stay", place, act, t0, t1} | {kind: "move", from, to, t0, t1, legs: [{kind, area, from, to, t0, t1}]}], hours of the day.
static func timeline(npc: String, plan: String, rain: bool, fb: Dictionary = {}) -> Array:
	var key: String = "%s|%s|%s|%s|%s" % [npc, plan, rain, day_end(), "" if fb.is_empty() else "%s@%s-%s" % [fb["at"], fb["from"], fb["to"]]]
	if _tl.has(key):
		return _tl[key]
	if not fb.is_empty():
		var over: Array = _overlay(timeline(npc, plan, rain), fb, "%s/%s" % [npc, plan])
		_tl[key] = over
		return over
	var def: Dictionary = registry().get(npc, {})
	var blocks: Array = plan_blocks(npc, plan)
	if rain:
		var sh: Dictionary = resolve_place(npc, str(def.get("shelter", "")))
		var shelter: String = "" if bool(sh["dropped"]) else str(sh["at"])
		for b2 in blocks:
			var at: String = str(b2["at"])
			var t0: float = float(b2.get("from", 12.0))
			var outdoor: bool = at != "nowhere" and not at.begins_with("int_") and not at.contains(".door_") and not at.begins_with("farm.") and not at.begins_with("away:")
			if shelter != "" and outdoor and t0 >= 8.0 and t0 <= 19.0 and str(b2.get("act", "")) in RAIN_ACTS:
				b2["at"] = shelter
				b2["act"] = "inside" if bool(sh["inside"]) else "sit"
	var segs: Array = _compile(npc, plan, blocks)
	_tl[key] = segs
	return segs


static func _seg_at(segs: Array, t: float) -> Dictionary:
	for s in segs:
		if float((s as Dictionary)["t0"]) <= t and t < float((s as Dictionary)["t1"]):
			return s
	return {}


static func speed_mult(npc: String) -> float:
	return clampf(LuaData.num(LuaData.dict(registry().get(npc, {})).get("speed_mult", 1.0)), 0.25, 1.6)


static func _legs(npc: String, from: String, to: String) -> Array:
	var legs := RouteTable.path(from, to).duplicate(true)
	var pace := speed_mult(npc)
	for leg in legs:
		if str(leg.get("kind", "")) == "walk":
			leg["seconds"] = float(leg["seconds"]) / pace
	return legs


static func _move_seg(from: String, to: String, t0: float, npc: String = "") -> Dictionary:
	var legs: Array = _legs(npc, from, to)
	var t: float = t0
	var sub: Array = []
	for l in legs:
		var dt: float = float(l["seconds"]) * RouteTable.game_min_per_s / 60.0
		sub.append({"kind": l["kind"], "area": l["area"], "from": l["from"], "to": l["to"], "t0": t, "t1": t + dt, "estimated": l.get("estimated", false)})
		t += dt
	return {"kind": "move", "from": from, "to": to, "t0": t0, "t1": t, "legs": sub}


## The festival day of one citizen as an OVERLAY on his compiled day: he leaves the place he is at (or finishes the walk he is on) in time to stand on the festival post at `from`, stays
## until `to`, and then walks to the first place of his normal day that is still going on when he gets there; everything after that is his normal day again.
## A citizen who is not in the world when he would have to leave (asleep, away, a hero twin) skips the festival: nobody pops out of nowhere.
static func _overlay(base: Array, fb: Dictionary, tag: String) -> Array:
	var f0: float = float(fb["from"])
	var f1: float = float(fb["to"])
	var post: String = str(fb["at"])
	var t: float = f0 - 0.5
	var origin: String = ""
	var start: float = 0.0
	for _i in 3:
		var s: Dictionary = _seg_at(base, t)
		if s.is_empty():
			return base
		if str(s["kind"]) == "stay":
			origin = str(s["place"])
			start = maxf(t, float(s["t0"]))
		else:
			origin = str(s["to"])
			start = float(s["t1"])
		if origin == "nowhere":
			return base
		t = f0 - float(_move_seg(origin, post, 0.0, tag.get_slice("/", 0))["t1"])
	var duration := float(_move_seg(origin, post, 0.0, tag.get_slice("/", 0))["t1"])
	var go: Dictionary = _move_seg(origin, post, maxf(start, f0 - duration), tag.get_slice("/", 0))
	if float(go["t1"]) > f0 + 0.25:
		compile_problems.append("%s: festival: arrives at %s %d game min after the start" % [tag, post, roundi((float(go["t1"]) - f0) * 60.0)])
	if float(go["t1"]) >= f1 - 0.25:
		return base
	var out: Array = []
	for s2 in base:
		var sd: Dictionary = s2
		if float(sd["t1"]) <= float(go["t0"]) + 1e-6:
			out.append(sd)
		elif float(sd["t0"]) < float(go["t0"]) - 1e-6:
			var clipped: Dictionary = sd.duplicate()
			clipped["t1"] = go["t0"]
			out.append(clipped)
			break
		else:
			break
	if not (go["legs"] as Array).is_empty():
		out.append(go)
	out.append({"kind": "stay", "place": post, "act": "stand", "t0": go["t1"], "t1": f1})
	var tail_from: int = -1
	var back: Dictionary = {}
	for i in base.size():
		var sb: Dictionary = base[i]
		if str(sb["kind"]) != "stay" or float(sb["t1"]) <= f1 + 0.25:
			continue
		if str(sb["place"]) == "nowhere":
			continue
		var mv: Dictionary = _move_seg(post, str(sb["place"]), f1, tag.get_slice("/", 0))
		if float(mv["t1"]) + 0.05 < float(sb["t1"]):
			back = mv
			tail_from = i
			break
	if tail_from < 0:
		out.append({"kind": "stay", "place": post, "act": "stand", "t0": f1, "t1": day_end()})       # nothing of his day is left to go to: he stays on the green
		return out
	if not (back["legs"] as Array).is_empty():
		out.append(back)
	var sbase: Dictionary = base[tail_from]
	out.append({"kind": "stay", "place": sbase["place"], "act": sbase["act"], "t0": back["t1"], "t1": sbase["t1"]})
	for k in range(tail_from + 1, base.size()):
		out.append(base[k])
	return out


static func _compile(npc: String, plan: String, blocks: Array) -> Array:
	var segs: Array = []
	var arr: float = DAY_START
	var tag: String = "%s/%s" % [npc, plan]
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		if i > 0:
			var pb: Dictionary = blocks[i - 1]
			var pplace: String = str(pb["at"]).trim_prefix("away:")
			var place: String = str(b["at"]).trim_prefix("away:")
			var travel: float = 0.0
			var legs: Array = []
			if pplace != "nowhere" and place != "nowhere":
				legs = _legs(npc, pplace, place)
				for l in legs:
					travel += float(l["seconds"]) * RouteTable.game_min_per_s / 60.0
			var leave: float
			if pb.has("stay"):
				leave = arr + float(pb["stay"])
			elif pb.has("leave"):
				leave = float(pb["leave"])
			elif b.has("from"):
				leave = float(b["from"]) - travel
			else:
				compile_problems.append("%s: block %d after %s has neither `from` nor a previous `leave` / `stay`" % [tag, i, pplace])
				leave = arr + DWELL_MIN
			if leave < arr + DWELL_MIN - 1e-9:
				compile_problems.append("%s: leaves %s at %.2f but arrived %.2f (dwell under %.2f h)" % [tag, pplace, leave, arr, DWELL_MIN])
				leave = arr + DWELL_MIN
			segs.append({"kind": "stay", "place": "nowhere" if str(pb["at"]).begins_with("away:") else pplace, "act": str(pb.get("act", "stand")), "t0": arr, "t1": leave})
			if travel > 0.0:
				var t: float = leave
				var sub: Array = []
				for l2 in legs:
					var dt: float = float(l2["seconds"]) * RouteTable.game_min_per_s / 60.0
					sub.append({"kind": l2["kind"], "area": l2["area"], "from": l2["from"], "to": l2["to"], "t0": t, "t1": t + dt, "estimated": l2.get("estimated", false)})
					t += dt
				segs.append({"kind": "move", "from": pplace, "to": place, "t0": leave, "t1": leave + travel, "legs": sub})
			arr = leave + travel
			if b.has("from") and arr > float(b["from"]) + 1e-6:
				compile_problems.append("%s: arrives at %s %.2f but `from` says %.2f (late by %d game min)" % [tag, place, arr, float(b["from"]), roundi((arr - float(b["from"])) * 60.0)])
	if not blocks.is_empty():
		var last: Dictionary = blocks[blocks.size() - 1]
		segs.append({"kind": "stay", "place": "nowhere" if str(last["at"]).begins_with("away:") else str(last["at"]), "act": str(last.get("act", "stand")), "t0": arr, "t1": day_end()})
	return segs


## Presence of one citizen at ctx.hour: {npc, state: "stay"|"move"|"inside"|"absent", plan, place, act, area, leg?}.
##   stay   standing / sitting at an anchor of `area`           move   walking: leg = {kind, area, from, to, frac, t0, t1}
##   inside in a building without a modelled room (door anchor) absent  not in the world (asleep in a bat house, away, gated, hero twin)
static func where_is(npc: String, ctx: Dictionary) -> Dictionary:
	var def: Dictionary = registry().get(npc, {})
	var out: Dictionary = {"npc": npc, "state": "absent", "plan": "", "place": "nowhere", "act": "", "area": ""}
	if def.is_empty():
		return out
	var gate: Dictionary = def.get("gate", {}) as Dictionary
	if not gate.is_empty():
		var ok: bool = bool((ctx.get("done", {}) as Dictionary).get(str(gate.get("done_quest", "")), false)) or int(ctx.get("total_day", 1)) >= int(gate.get("or_day", 1 << 30))
		if not ok:
			return out
	if def.has("hero_twin") and str(def["hero_twin"]) == str(ctx.get("hero", "")):
		return out
	var plan: String = plan_name(npc, ctx, def)
	out["plan"] = plan
	var fb: Dictionary = {}
	if ctx.has("fest"):
		var fk: String = "%s|%d|%s" % [npc, int(ctx.get("total_day", 1)), str((ctx["fest"] as Dictionary).get("id", ""))]
		if not _fb.has(fk):
			_fb[fk] = festival_block(npc, ctx)
		fb = _fb[fk]
	var segs: Array = timeline(npc, plan, is_rainy(ctx), fb)
	if npc in ctx.get("home_guests",[]):segs = Svc.static_call("res://scripts/social/relationships/farm_visits.gd",&"timeline",[npc,ctx,segs],segs)
	if segs.is_empty():
		return out
	var t: float = float(ctx["hour"])
	if t < DAY_START:
		t = day_end() - 0.0001
	var lo: int = 0
	var hi: int = segs.size() - 1
	while lo < hi:                                   # binary search: the segment with t0 <= t < t1
		var mid: int = (lo + hi + 1) / 2
		if float(segs[mid]["t0"]) <= t:
			lo = mid
		else:
			hi = mid - 1
	var s: Dictionary = segs[lo]
	if str(s["kind"]) == "stay":
		var place: String = str(s["place"])
		out["place"] = place
		out["act"] = str(s["act"])
		if place == "nowhere":
			return out
		out["area"] = place.get_slice(".", 0)
		out["state"] = "inside" if str(s["act"]) in ["inside","home"] else "stay"
		return out
	for l in (s["legs"] as Array):
		var ld: Dictionary = l
		if t < float(ld["t1"]) or l == (s["legs"] as Array)[-1]:
			out["state"] = "move"
			out["place"] = str(s["to"])
			out["act"] = "walk"
			var span: float = maxf(float(ld["t1"]) - float(ld["t0"]), 1e-6)
			out["leg"] = {"kind": ld["kind"], "area": ld["area"], "from": ld["from"], "to": ld["to"], "frac": clampf((t - float(ld["t0"])) / span, 0.0, 1.0), "t0": ld["t0"], "t1": ld["t1"]}
			out["area"] = str(ld["area"]) if str(ld["kind"]) == "walk" else str(ld["to"]).get_slice(".", 0)
			return out
	return out


## Everyone whose body is in `area_id` right now (stay or walking inside it), highest priority first (the live-visual cap keeps the head of this list).
static func present_in(area_id: String, ctx: Dictionary) -> Array:
	var out: Array = []
	var reg: Dictionary = registry()
	for npc in npc_ids():
		var w: Dictionary = where_is(npc, ctx)
		if str(w["state"]) in ["stay", "move"] and str(w["area"]) == area_id:
			w["priority"] = int((reg[npc] as Dictionary).get("priority", 3)) + (10 if str(w["place"]).contains(".fest_") else 0)     # the crowd of a festival outranks the passers-by when the cap bites
			out.append(w)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) > int(b["priority"])
		return str(a["npc"]) < str(b["npc"]))
	return out
