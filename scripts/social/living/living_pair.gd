extends RefCounted
## Bounded, loaded fountain pilot. The existing routes own movement and seats.
const IDS := ["baker_maja", "beekeeper_birk", "smith_thorin"]
const KEY := "beekeeper_birk:smith_thorin"
const POSTS := {"baker_maja": "hyggebyen.torv_fountain_e", "beekeeper_birk": "hyggebyen.torv_fountain_s", "smith_thorin": "hyggebyen.torv_fountain_e"}
const MAX_DAY := 1000000
const RADIUS := 360.0 # adjacent existing fountain posts, in ground pixels
const SEAT_RADIUS := 24.0

static func decode(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() > 1: return {"ok": false}
	if raw.is_empty(): return {"ok": true, "pairs": {}}
	if not raw.has(KEY) or not raw[KEY] is Dictionary: return {"ok": false}
	var r: Dictionary = raw[KEY]
	var keys := ["day", "status", "phase", "outcome_day", "pause_minutes"]
	if r.size() != keys.size(): return {"ok": false}
	for k in r:
		if typeof(k) != TYPE_STRING or k not in keys: return {"ok": false}
	if not _day(r.get("day"), 1) or not _day(r.get("outcome_day"), 0) or r.outcome_day > r.day: return {"ok": false}
	if typeof(r.get("status")) != TYPE_STRING or r.status not in ["neutral", "at_ease", "needs_clarification"]: return {"ok": false}
	if typeof(r.get("phase")) != TYPE_STRING or r.phase not in ["invited", "accepted", "attendance", "mismatch", "clarification_pending", "clarification"]: return {"ok": false}
	if typeof(r.get("pause_minutes")) not in [TYPE_INT, TYPE_FLOAT] or r.pause_minutes not in [2, 5]: return {"ok": false}
	if (r.phase in ["mismatch", "clarification_pending"]) != (r.status == "needs_clarification"): return {"ok": false}
	if r.phase in ["attendance", "clarification"] and (r.status != "at_ease" or r.outcome_day != r.day): return {"ok": false}
	return {"ok": true, "pairs": {KEY: {"day": int(r.day), "status": r.status, "phase": r.phase, "outcome_day": int(r.outcome_day), "pause_minutes": int(r.pause_minutes)}}}

static func decode_responses(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() > 4: return {"ok": false}
	var rows := {}
	for pid in raw:
		if typeof(pid) != TYPE_STRING or pid not in ["p0", "p1", "p2", "p3"] or not raw[pid] is Dictionary: return {"ok": false}
		var r: Dictionary = raw[pid]
		if r.size() != 5: return {"ok": false}
		for k in r:
			if typeof(k) != TYPE_STRING or k not in ["day", "choice", "not_before_day", "attended_day", "ack_day"]: return {"ok": false}
		for k in ["day", "not_before_day", "attended_day", "ack_day"]:
			if not _day(r.get(k), 0): return {"ok": false}
		if r.day < 1 or typeof(r.choice) != TYPE_STRING or r.choice not in ["help", "defer", "decline"] or r.attended_day > r.day or r.ack_day > r.attended_day: return {"ok": false}
		if r.choice != "help" and (r.attended_day != 0 or r.ack_day != 0): return {"ok": false}
		if int(r.not_before_day) != (int(r.day) + 1 if r.choice == "defer" else 0): return {"ok": false}
		rows[pid] = {"day": int(r.day), "choice": r.choice, "not_before_day": int(r.not_before_day), "attended_day": int(r.attended_day), "ack_day": int(r.ack_day)}
	return {"ok": true, "rows": rows}

static func _day(v: Variant, lo: int) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) == floorf(float(v)) and float(v) >= lo and float(v) <= MAX_DAY

## Exact compiled ordinary stay intersection: no route override and no bench
## overlap assumption. Work, travel, weather, guests and festivals win.
static func window(ctx: Dictionary) -> Dictionary:
	if not ctx.get("fest", {}).is_empty() or str(ctx.get("festival", "")) != "" or Routines.is_rainy(ctx): return {}
	var start := 0.0
	var end := 26.0
	for id in IDS:
		if not SocialData.npcs().has(id) or Routines.is_unavailable(id, ctx) or id in ctx.get("home_guests", []): return {}
		var found := false
		var plan := Routines.daily_plan(id, ctx)
		for s in Routines._timeline(id, plan, false, {}, float(ctx.get("_day_end", 26.0))):
			if s.get("kind") == "stay" and s.get("place") == POSTS[id] and s.get("act") == "sit":
				start = maxf(start, float(s.t0))
				end = minf(end, float(s.t1))
				found = true
				break
		if not found: return {}
		for bid in Hours.registry():
			var b := Hours.building(str(bid))
			if b.get("keeper") != id or not b.has("hours") or int(ctx.weekday) in Hours.closed_days(b): continue
			var h := Hours.hours_on(b, int(ctx.weekday))
			if start < float(h[1]) and end > float(h[0]): start = maxf(start, float(h[1]))
	return {} if end - start < 2.0 / 60.0 else {"start": start, "end": end}

static func director_of(actor: Variant) -> Variant:
	if not is_instance_valid(actor) or not actor is Npc2D: return null
	for source in NpcDirector._active:
		if is_instance_valid(source) and source is TownDirector and source.area == actor.area and source.live.get(str(actor.npc_id)) == actor: return source
	return null

## No schedules or public event dictionaries constitute physical evidence.
static func actors(source: Variant, ctx: Dictionary, speaker: Variant = null) -> Array:
	if not is_instance_valid(source) or not source is TownDirector or not source.is_inside_tree() or source.is_queued_for_deletion() or not source.running or not source.ready_for_population or source.area_id != "hyggebyen" or not NpcDirector._active.has(source): return []
	if not is_instance_valid(source.area) or not source.area.is_inside_tree() or source.area.is_queued_for_deletion(): return []
	var out: Array = []
	for id in IDS:
		var actor: Variant = source.live.get(id)
		if not is_instance_valid(actor) or not actor is Npc2D or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.area != source.area or not actor.driven or str(actor.npc_id) != id or ((actor.is_talking or actor._held) and actor != speaker): return []
		var row := Routines.where_is(id, ctx)
		if row.get("state") != "stay" or row.get("place") != POSTS[id] or row.get("act") != "sit" or source.targets.get(id, {}).get("place") != POSTS[id]: return []
		var seat: Vector2 = source.area.to_global(Iso.to_screen(source._carrot(source.targets[id], float(ctx.hour))))
		if Iso.to_ground(actor.global_position - seat).length() > SEAT_RADIUS: return []
		out.append(actor)
	for a in out:
		for b in out:
			if Iso.to_ground(a.global_position - b.global_position).length() > RADIUS: return []
	return out

static func row(state: Dictionary) -> Dictionary:
	return state.get("world", {}).get("pairs", {}).get(KEY, {})

static func reply(state: Dictionary) -> String:
	var r := row(state)
	if r.get("status") == "needs_clarification": return "LC_PAIR_MISMATCH"
	if r.get("phase") == "clarification": return "LC_PAIR_CLARIFIED"
	if r.get("status") == "at_ease": return "LC_PAIR_AT_EASE"
	if r.get("phase") in ["invited", "accepted"]: return "LC_PAIR_INVITED"
	return "LC_PAIR_WISH"

static func _participants(state: Dictionary, bodies: Array, day: int) -> Dictionary:
	var out := {}
	for pid in state.get("responses", {}):
		var r: Dictionary = state.responses[pid]
		if r.get("day") != day or r.get("choice") != "help": continue
		var body: Variant = PlayerRegistry.by_id(StringName(pid))
		if not _near(body, bodies) or PlayerRegistry._states.get(StringName(pid)) == null: continue
		out[pid] = {"body": weakref(body), "profile": PlayerRegistry._states.get(StringName(pid))}
	return out

static func _near(body: Variant, bodies: Array) -> bool:
	if not is_instance_valid(body) or not body is Node2D or not body.is_inside_tree() or body.is_queued_for_deletion(): return false
	var pid := PlayerRegistry.registered_id(body)
	if pid == &"" or PlayerRegistry.by_id(pid) != body: return false
	return bodies.all(func(a): return Iso.to_ground(a.global_position - body.global_position).length() <= RADIUS)

static func _retain_participants(run: Dictionary, bodies: Array) -> void:
	for pid in run.get("players", {}).keys():
		var p: Dictionary = run.players[pid]
		var body: Variant = p.body.get_ref()
		if not _near(body, bodies) or PlayerRegistry._states.get(StringName(pid)) != p.profile:
			run.players.erase(pid)

## A bounded active-ticket guard runs on this director only. It does no route,
## catalogue or whole-world search; even a brief physical departure breaks dwell.
static func guard(sm: Node, source: Variant) -> void:
	var run: Dictionary = sm._living_pair_run
	if run.is_empty() or run.director.get_ref() != source: return
	if run.world != sm._accounting_world or not is_same(run.model, sm._living) or run.day != GameManager.total_day() or not is_instance_valid(run.area.get_ref()) or run.area.get_ref() != source.area:
		sm._living_pair_run = {}
		return
	var bodies: Array = []
	for i in IDS.size():
		var actor: Variant = run.actors[i].get_ref()
		if not is_instance_valid(actor) or not actor is Npc2D or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor._held or actor.is_talking or actor.area != source.area or source.live.get(IDS[i]) != actor:
			sm._living_pair_run = {}
			return
		var target: Dictionary = source.targets.get(IDS[i], {})
		if target.get("place") != POSTS[IDS[i]] or target.get("state") != "stay":
			sm._living_pair_run = {}
			return
		var seat: Vector2 = source.area.to_global(Iso.to_screen(source._carrot(target, source.game_hours)))
		if Iso.to_ground(actor.global_position - seat).length() > SEAT_RADIUS:
			sm._living_pair_run = {}
			return
		bodies.append(actor)
	_retain_participants(run, bodies)

## Transient ticket captures exact model/director/area/actors before facing.
## Every minute must be consecutive; load/leave/hold/time jump loses dwell.
static func observe(sm: Node, source: Variant) -> void:
	if not sm.living_can_simulate() or sm._accounting_suspended or GameManager.is_modal_open():
		sm._living_pair_run = {}
		return
	var ctx := Routines.now_ctx()
	var day := int(ctx.total_day)
	var slot := window(ctx)
	var bodies := actors(source, ctx) if not slot.is_empty() and float(ctx.hour) >= float(slot.start) and float(ctx.hour) < float(slot.end) else []
	if bodies.is_empty() or day < 1 or day > MAX_DAY:
		sm._living_pair_run = {}
		return
	var now := GameManager.hour * 60 + GameManager.minute
	var current := row(sm._living)
	if int(current.get("day", 0)) > day or (int(current.get("day", 0)) == day and current.get("phase") in ["attendance", "mismatch", "clarification"]): return
	var run: Dictionary = sm._living_pair_run
	var valid: bool = not run.is_empty() and run.day == day and run.world == sm._accounting_world and is_same(run.model, sm._living) and run.director.get_ref() == source and run.area.get_ref() == source.area and now == int(run.minute) + 1
	if valid:
		for i in bodies.size():
			if run.actors[i].get_ref() != bodies[i]: valid = false
	if not valid:
		run = {"day": day, "world": sm._accounting_world, "model": sm._living, "director": weakref(source), "area": weakref(source.area), "actors": bodies.map(func(a): return weakref(a)), "minute": now, "elapsed": 0, "stage": "clarify" if current.get("status") == "needs_clarification" else "invite"}
		sm._living_pair_run = run
		return
	run.minute = now
	run.elapsed += 1
	_retain_participants(run, bodies)
	var next := current.duplicate(true)
	var stage: String = run.stage
	if stage == "clarify" and run.elapsed >= 1:
		next = {"day": day, "status": "at_ease", "phase": "clarification", "outcome_day": day, "pause_minutes": 2}
	elif stage == "invite" and run.elapsed >= 1:
		var duration := int(current.get("pause_minutes", 5))
		next = {"day": day, "status": current.get("status", "neutral"), "phase": "invited", "outcome_day": int(current.get("outcome_day", 0)), "pause_minutes": duration}
		run.stage = "consent"
		run.elapsed = 0
	elif stage == "consent" and run.elapsed >= 1:
		# Both hear Birk's actual departure boundary before agreeing/declining.
		if float(ctx.hour) + float(next.pause_minutes) / 60.0 >= float(slot.end):
			next.status = "needs_clarification"
			next.phase = "mismatch"
		else:
			next.phase = "accepted"
			run.stage = "pause"
			run.players = _participants(sm._living, bodies, day)
			run.elapsed = 0
	elif stage == "pause" and run.elapsed >= int(current.get("pause_minutes", 5)):
		next.status = "at_ease"
		next.phase = "attendance"
		next.outcome_day = day
	else: return
	var checked := decode({KEY: next})
	if not checked.ok: return
	# Callback-free terminal commit, then optional existing actor presentation.
	sm._living.world.pairs = checked.pairs
	if next.phase == "attendance":
		for pid in run.get("players", {}):
			sm._living.responses[pid]["attended_day"] = day
	for i in bodies.size():
		bodies[i].visual.set_facing_direction(bodies[(i + 1) % bodies.size()].global_position - bodies[i].global_position)
	if next.phase in ["attendance", "mismatch", "clarification"]: sm._living_pair_run = {}
