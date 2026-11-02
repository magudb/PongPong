extends RefCounted
## One bounded Thorin tracer, not a whole-cast autonomous actor system.
const NPC := "smith_thorin"
const PERSONAL := "lc_smith_thorin_personal"
const GOALS := preload("res://scripts/social/living/living_goals.gd")
const DATA := preload("res://scripts/social/living/living_data.gd")
const MAX_DAY := 1000000
const IDS := ["lc_smith_thorin_role", PERSONAL, "lc_smith_thorin_connect", "lc_smith_thorin_reconcile"]
const ORIGIN := "hyggebyen.torv_fountain_e"
const POST := "hyggebyen.torv_bench2"
static var _cache: Dictionary = {}

static func _whole(v: Variant, lo: int, hi: int) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) == floorf(float(v)) and float(v) >= lo and float(v) <= hi

static func _keys(d: Dictionary, allowed: Array) -> bool:
	for k in d:
		if k not in allowed: return false
	return true

static func _row(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not _keys(raw, ["pending_day", "consumed_day", "attempt_day", "selected", "cooldowns"]): return {"ok": false}
	if raw.is_empty(): return {"ok": true, "row": {}}
	var row := {}
	for key in ["pending_day", "consumed_day", "attempt_day"]:
		if raw.has(key):
			if not _whole(raw[key], 0, MAX_DAY): return {"ok": false}
			row[key] = int(raw[key])
	if int(row.get("consumed_day", 0)) > int(row.get("pending_day", 0)): return {"ok": false}
	var cooldowns: Variant = raw.get("cooldowns", {})
	if not cooldowns is Dictionary or cooldowns.size() > 4: return {"ok": false}
	row["cooldowns"] = {}
	for id in cooldowns:
		if id not in IDS or not _whole(cooldowns[id], 1, MAX_DAY + 14): return {"ok": false}
		row.cooldowns[id] = int(cooldowns[id])
	var selected: Variant = raw.get("selected", {})
	if not selected is Dictionary: return {"ok": false}
	row["selected"] = {}
	if not selected.is_empty():
		if not _keys(selected, ["npc", "goal_id", "kind", "target", "selected_day", "expiry_day", "cooldown_until_day", "utility", "reasons"]): return {"ok": false}
		if selected.get("goal_id") not in IDS or not selected.get("reasons") is Dictionary: return {"ok": false}
		if not _keys(selected.reasons, ["value", "value_weight", "goal_weight", "weighted_value", "trigger_bonus"]): return {"ok": false}
		var kind: String = str(selected.goal_id).trim_prefix("lc_smith_thorin_")
		var value := "quiet" if kind in ["role", "connect"] else "craft"
		var goal := {"id": selected.goal_id, "kind": kind, "value": value, "trigger": GOALS.HELP if kind == "personal" else "none"}
		if kind in ["connect", "reconcile"]: goal["target"] = "baker_maja"
		var checked := GOALS._previous(NPC, {selected.goal_id: goal}, selected, int(row.get("attempt_day", 0)))
		if checked.is_empty() or checked.selected_day != row.get("attempt_day") or int(row.cooldowns.get(checked.goal_id, 0)) < checked.cooldown_until_day: return {"ok": false}
		row.selected = checked
	return {"ok": true, "row": row}

## Pure codec, including bounded retired world state. Never reward or settle here.
static func decode(active: Variant, orphan: Variant) -> Dictionary:
	var a := _row(active)
	var b := _row(orphan)
	if not a.ok or not b.ok: return {"ok": false}
	if a.row.is_empty(): return b
	if b.row.is_empty(): return a
	if a.row.get("attempt_day", 0) == b.row.get("attempt_day", 0) and a.row.get("selected", {}) != b.row.get("selected", {}): return {"ok": false}
	var row: Dictionary = (a.row if int(a.row.get("attempt_day", 0)) >= int(b.row.get("attempt_day", 0)) else b.row).duplicate(true)
	for key in ["pending_day", "consumed_day"]:
		row[key] = maxi(int(a.row.get(key, 0)), int(b.row.get(key, 0)))
	for id in IDS:
		var until := maxi(int(a.row.cooldowns.get(id, 0)), int(b.row.cooldowns.get(id, 0)))
		if until > 0: row.cooldowns[id] = until
	return {"ok": true, "row": row}

## The pilot codec is deliberately closed, unlike the general LC3 selector.
## Check every authored goal before an attempt: even an unchosen incompatible
## goal must not consume pending help or grow historical cooldown slots.
static func _pilot_profile(profile: Dictionary) -> bool:
	if not GOALS._profile(NPC, profile): return false
	for g in profile.goals:
		if g.id not in IDS: return false
		var kind: String = str(g.id).trim_prefix("lc_smith_thorin_")
		if g.kind != kind or g.value != ("quiet" if kind in ["role", "connect"] else "craft") or g.trigger != (GOALS.HELP if kind == "personal" else "none"): return false
		if g.get("target", "") != ("baker_maja" if kind in ["connect", "reconcile"] else ""): return false
	return true

static func inputs(day: int) -> Dictionary:
	return {"day": day, "available": true, "free_time": true, "protected": {"essential_work": false, "story": false, "festival": false, "home": false}}

## Small immutable public projection: never contains private cause owner/receipt.
## A retired/changed goal is suspended, not erased or silently reselected.
static func snapshot(state: Dictionary, profile: Dictionary, known: bool) -> Dictionary:
	var checked := decode(state.world.get("pilot", {}), state.orphans.get("pilot", {}))
	var row: Dictionary = checked.get("row", {})
	var selected := {}
	if known and _pilot_profile(profile) and not row.get("selected", {}).is_empty():
		selected = GOALS.select(NPC, profile, inputs(int(row.get("attempt_day", 0))), row.selected)
	# Empty/retired/blocked views are cached too: their empty selection must
	# not be a mutable back door into the public shared projection.
	selected.make_read_only()
	var out := {"day": int(row.get("attempt_day", 0)), "selected": selected}
	out.make_read_only()
	return out

## Exactly one day attempt, including an empty day. Skip-catchup is O(1) for
## this one citizen, never a loop over elapsed days or private player rows.
static func settle(state: Dictionary, ctx: Dictionary, profile: Dictionary, blocked: bool) -> bool:
	var day := int(ctx.get("total_day", 0))
	if day < 1 or day > MAX_DAY: return false
	var checked := decode(state.world.get("pilot", {}), state.orphans.get("pilot", {}))
	if not checked.ok: return false
	var row: Dictionary = checked.row
	if day <= int(row.get("attempt_day", 0)): return false
	row["attempt_day"] = day
	row["selected"] = {}
	var cooldowns: Dictionary = row.get("cooldowns", {})
	row["cooldowns"] = cooldowns
	# Unknown historical goal slots remain saved, but cannot enter the selector.
	var current := {}
	var valid_profile := _pilot_profile(profile)
	for g in (profile.get("goals", []) if valid_profile else []):
		if cooldowns.has(g.id): current[g.id] = cooldowns[g.id]
	if valid_profile and not blocked and not Routines.is_unavailable(NPC, ctx) and not envelope(ctx).is_empty():
		var i := inputs(day)
		i["cooldowns"] = current
		var pending := int(row.get("pending_day", 0))
		i["triggers"] = {GOALS.HELP: pending > int(row.get("consumed_day", 0)) and pending < day}
		var chosen := GOALS.select(NPC, profile, i)
		if not chosen.is_empty():
			row.selected = chosen
			cooldowns[chosen.goal_id] = chosen.cooldown_until_day
			if chosen.goal_id == PERSONAL: row["consumed_day"] = pending
	state.world["pilot"] = row
	state.orphans.erase("pilot")
	return true

## Reuse Thorin's authored sit posts/clip. Only an entire excursion contained
## INSIDE his ordinary fountain leisure stay can replace anything. Every move,
## work/service, home, sleep and other authored interval remains byte-for-byte.
## No festival-overlay tail, guessed anchor, spawn fallback or new animation.
static func envelope(ctx: Dictionary, supplied: Array = []) -> Array:
	if not ctx.get("fest", {}).is_empty() or str(ctx.get("festival", "")) != "" or NPC in ctx.get("home_guests", []) or Routines.is_unavailable(NPC, ctx) or Routines.is_rainy(ctx): return []
	var plan := Routines.daily_plan(NPC, ctx)
	if plan not in ["work", "work_mon"]: return []
	var base := supplied if not supplied.is_empty() else Routines._timeline(NPC, plan, false, {}, float(ctx.get("_day_end", 26.0)))
	var target_authored := Routines.plan_blocks(NPC, "sun").any(func(b): return b.get("at") == POST and b.get("act") == "sit")
	if not target_authored or not RouteTable.has_anchor(POST) or not RouteTable.has_anchor(ORIGIN): return []
	var key := "%s|%s|%s|%s" % [plan, ctx.get("weekday", 0), ctx.get("_day_end", 26.0), RouteTable.generation]
	var hours := Hours.registry()
	if _cache.has(key) and is_same(_cache[key].base, base) and is_same(_cache[key].hours, hours): return _cache[key].out
	var out: Array = []
	for s in base:
		if s.get("kind") != "stay" or s.get("place") != ORIGIN or s.get("act") != "sit":
			out.append(s)
			continue
		var go := Routines._move_seg(ORIGIN, POST, 0.0, NPC)
		var back := Routines._move_seg(POST, ORIGIN, 20.0, NPC)
		if go.legs.is_empty() or back.legs.is_empty() or go.legs.any(func(l): return l.get("estimated", false)) or back.legs.any(func(l): return l.get("estimated", false)): return []
		go = Routines._move_seg(ORIGIN, POST, 19.25 - float(go.t1), NPC)
		if float(go.t0) < float(s.t0) + Routines.DWELL_MIN or float(back.t1) + Routines.DWELL_MIN > float(s.t1): return []
		# Keeper hours protect the outbound AND return legs, not only the sit.
		for bid in Hours.registry():
			var b := Hours.building(str(bid))
			if b.get("keeper") != NPC or not b.has("hours") or int(ctx.weekday) in Hours.closed_days(b): continue
			var h := Hours.hours_on(b, int(ctx.weekday))
			if float(go.t0) < float(h[1]) and float(back.t1) > float(h[0]): return []
		out.append({"kind": "stay", "place": ORIGIN, "act": "sit", "t0": s.t0, "t1": go.t0})
		out.append(go)
		out.append({"kind": "stay", "place": POST, "act": "sit", "t0": go.t1, "t1": 20.0})
		out.append(back)
		out.append({"kind": "stay", "place": ORIGIN, "act": "sit", "t0": back.t1, "t1": s.t1})
	if out.size() != base.size() + 4: return []
	if _cache.size() >= 64: _cache.clear()
	_cache[key] = {"base": base, "out": out, "hours": hours}
	return out

static func timeline(npc: String, ctx: Dictionary, base: Array) -> Array:
	if npc != NPC: return base
	var snapshot: Dictionary = ctx.get("living_activity", {})
	if int(snapshot.get("day", 0)) != int(ctx.get("total_day", 1)) or snapshot.get("selected", {}).get("goal_id") != PERSONAL: return base
	var out := envelope(ctx, base)
	return base if out.is_empty() else out

static func clear_cache() -> void:
	_cache.clear()
