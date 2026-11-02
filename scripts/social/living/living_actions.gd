extends RefCounted
## Lowest-priority loaded local moments; ordinary routines still own every pose/post.
const CAST := preload("res://scripts/social/living/living_cast.gd")
const DATA := preload("res://scripts/social/living/living_data.gd")
const GOALS := preload("res://scripts/social/living/living_goals.gd")
const CODEC := "res://scripts/social/living/living_state.gd"
const MAX_DAY := 1000000
const FIELDS := ["day", "goal", "outcome", "target", "closed_day", "cooldowns"]

static func decode(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() > 34: return {"ok": false}
	var rows := {}
	for npc in raw:
		if typeof(npc) != TYPE_STRING or npc not in DATA.AUDITED_IDS: return {"ok": false}
		var r: Variant = raw[npc]
		if not r is Dictionary or r.size() != FIELDS.size(): return {"ok": false}
		for k in r:
			if typeof(k) != TYPE_STRING or k not in FIELDS: return {"ok": false}
		if not CAST._day(r.get("day")) or typeof(r.get("goal")) != TYPE_STRING or not _goal_id(npc, r.goal): return {"ok": false}
		if typeof(r.get("outcome")) != TYPE_STRING or r.outcome not in ["pending", "interrupted", "reflection", "connection", "clarification"]: return {"ok": false}
		if typeof(r.get("target")) != TYPE_STRING or (r.target != "" and (r.target not in DATA.AUDITED_IDS or r.target == npc)): return {"ok": false}
		if not _whole(r.get("closed_day"), 0, MAX_DAY) or int(r.closed_day) != (0 if r.outcome == "pending" else int(r.day)): return {"ok": false}
		if r.outcome in ["connection", "clarification"] and r.target == "": return {"ok": false}
		if not r.get("cooldowns") is Dictionary or r.cooldowns.size() > 4: return {"ok": false}
		var cooldowns := {}
		for goal in r.cooldowns:
			if typeof(goal) != TYPE_STRING or not _goal_id(npc, goal) or not _whole(r.cooldowns[goal], 1, MAX_DAY + 14): return {"ok": false}
			cooldowns[goal] = int(r.cooldowns[goal])
		rows[npc] = {"day": int(r.day), "goal": r.goal, "outcome": r.outcome, "target": r.target, "closed_day": int(r.closed_day), "cooldowns": cooldowns}
	return {"ok": true, "rows": rows}

static func _goal_id(npc: String, id: String) -> bool:
	return id in ["lc_" + npc + "_role", "lc_" + npc + "_personal", "lc_" + npc + "_connect", "lc_" + npc + "_reconcile"]

static func _whole(v: Variant, lo: int, hi: int) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) == floorf(float(v)) and float(v) >= lo and float(v) <= hi

## Pure capability gate before scoring. Named attendance is never player listening.
static func plan(npc: String, profile: Dictionary, day: int, prior: Dictionary, targets: Array) -> Dictionary:
	var b := CAST.binding(npc)
	if b.is_empty(): return {}
	var eligible: Array = []
	var followups: Array = []
	for goal in profile.get("goals", []):
		var executor: String = b.get("goals", {}).get(goal.id, "")
		if executor == "clarify" and prior.get("outcome") == "connection" and prior.get("target") == goal.get("target") and goal.get("target", "") in targets:
			followups.append(goal.id)
			eligible.append(goal.id)
		elif executor == "reflect" or (executor == "connect" and goal.get("target", "") in targets): eligible.append(goal.id)
	var inputs := {"day": day, "available": true, "free_time": true, "protected": {"essential_work": false, "story": false, "festival": false, "home": false}, "cooldowns": prior.get("cooldowns", {}), "eligible_goal_ids": followups}
	# Finish an authored connection's bounded follow-up at its next eligible
	# named meeting before starting unrelated optional activity. Scoring and
	# cooldowns still govern each phase; an unavailable follow-up falls back.
	var chosen: Dictionary = GOALS.select(npc, profile, inputs) if not followups.is_empty() else {}
	if chosen.is_empty():
		inputs.eligible_goal_ids = eligible
		chosen = GOALS.select(npc, profile, inputs)
	if chosen.is_empty(): return {}
	return {"goal": chosen.goal_id, "executor": b.goals[chosen.goal_id], "target": chosen.get("target", ""), "cooldown": chosen.cooldown_until_day}

static func source_valid(source: Variant) -> bool:
	return is_instance_valid(source) and source is TownDirector and source.is_inside_tree() and not source.is_queued_for_deletion() and source.running and source.ready_for_population and NpcDirector._active.has(source) and is_instance_valid(source.area) and source.area.is_inside_tree() and not source.area.is_queued_for_deletion()

static func safe(source: Variant, actor: Variant, ctx: Dictionary) -> Dictionary:
	if not source_valid(source) or not is_instance_valid(actor) or not actor is Npc2D or not actor.is_inside_tree() or actor.is_queued_for_deletion(): return {}
	var npc := str(actor.npc_id)
	if source.live.get(npc) != actor or actor.area != source.area or not actor.driven or actor.is_talking or actor._held or actor._event or not actor.is_enabled(): return {}
	var b := CAST.binding(npc)
	if b.is_empty() or b.get("safe_posts", []).is_empty() or Routines.is_unavailable(npc, ctx) or npc in ctx.get("home_guests", []) or not ctx.get("fest", {}).is_empty() or ctx.get("festival", "") != "": return {}
	var at := Routines.where_is(npc, ctx)
	if at.get("state") != "stay" or at.get("place") not in b.safe_posts or at.get("act") not in b.safe_acts: return {}
	for id in Hours.registry():
		var building := Hours.building(str(id))
		if building.get("keeper") != npc or not building.has("hours") or int(ctx.weekday) in Hours.closed_days(building): continue
		var hours := Hours.hours_on(building, int(ctx.weekday))
		if float(ctx.hour) >= float(hours[0]) and float(ctx.hour) < float(hours[1]): return {}
	var target: Dictionary = source.targets.get(npc, {})
	if target.get("place") != at.place or target.get("act") != at.act: return {}
	var seat: Vector2 = source.area.to_global(Iso.to_screen(source._carrot(target, float(ctx.hour))))
	if Iso.to_ground(actor.global_position - seat).length() > 24.0: return {}
	return {"place": at.place, "act": at.act}

static func guard(sm: Node, source: Variant) -> void:
	if not source_valid(source): return
	for npc in sm._living_cast_runs.keys():
		var run: Dictionary = sm._living_cast_runs[npc]
		if run.source.get_ref() != source: continue
		var valid: bool = not sm._accounting_suspended and is_same(run.world, sm._accounting_world) and run.day == sm.today()
		# Exact active refs/retained seats only: NO route/catalogue/hour scans per frame.
		for participant in run.participants:
			var actor: Variant = participant.actor.get_ref()
			if not is_instance_valid(actor) or not actor is Npc2D or not actor.is_inside_tree() or actor.is_queued_for_deletion():
				valid = false
				continue
			if actor.area != source.area or source.live.get(participant.npc) != actor or actor._held or actor.is_talking or not actor.is_enabled() or source.targets.get(participant.npc, {}).get("place") != participant.place or Iso.to_ground(actor.global_position - participant.seat).length() > 24.0: valid = false
		if not valid: _interrupt(sm, npc, run)

static func _valid(sm: Node, run: Dictionary, ctx: Dictionary) -> bool:
	if sm._accounting_suspended or not sm.living_can_simulate() or not is_same(run.world, sm._accounting_world) or int(ctx.total_day) != run.day: return false
	var source: Variant = run.source.get_ref()
	var actor: Variant = run.actor.get_ref()
	var at := safe(source, actor, ctx)
	if at.is_empty() or at.place != run.place: return false
	if run.target != "":
		var partner: Variant = run.partner.get_ref()
		if safe(source, partner, ctx).is_empty() or Iso.to_ground(actor.global_position - partner.global_position).length() > 360.0: return false
	var row: Dictionary = sm._living.get("world", {}).get("citizens", {}).get(run.npc, {})
	return row.get("day") == run.day and row.get("goal") == run.goal and row.get("outcome") == "pending"

static func _install(sm: Node, next: Dictionary) -> bool:
	var decoded: Dictionary = Svc.static_call(CODEC, &"decode", [next, SocialData.npcs(), sm.today()], {"ok": false})
	if not decoded.get("ok", false): return false
	# Preserve the existing pair/mining root identity while atomically installing
	# this validated field; unrelated active pair tickets must not be displaced.
	sm._living["v"] = 4
	sm._living.world["citizens"] = decoded.state.world.get("citizens", {})
	return true

static func _interrupt(sm: Node, npc: String, run: Dictionary) -> void:
	sm._living_cast_runs.erase(npc)
	if not is_same(run.world, sm._accounting_world): return
	var next: Dictionary = sm.living_snapshot()
	if next.is_empty(): return
	var row: Dictionary = next.world.get("citizens", {}).get(npc, {})
	if row.get("day") != run.day or row.get("outcome") != "pending": return
	row["outcome"] = "interrupted"
	row["closed_day"] = run.day
	_install(sm, next)

static func _reserved(sm: Node, npc: String) -> bool:
	for run in sm._living_cast_runs.values():
		if run.npc == npc or run.target == npc: return true
	return false

static func observe(sm: Node, source: Variant) -> void:
	if not source_valid(source) or not sm.living_can_simulate() or sm._accounting_suspended or GameData.gm().is_modal_open(): return
	var ctx := Routines.now_ctx()
	var day := int(ctx.total_day)
	if day < 1 or day > MAX_DAY: return
	# Only currently loaded actors; no roster spawning or offscreen/history scan.
	for npc in source.live.keys():
		if npc not in DATA.AUDITED_IDS: continue
		# The connected pilot has priority over this general optional observer.
		if npc in ["baker_maja", "beekeeper_birk", "smith_thorin"] and not sm._living_pair_run.is_empty(): continue
		var actor: Variant = source.live[npc]
		var at := safe(source, actor, ctx)
		var run: Dictionary = sm._living_cast_runs.get(npc, {})
		if not run.is_empty():
			if not _valid(sm, run, ctx) or float(ctx.hour) - float(run.last_hour) > 1.01 / 60.0 or float(ctx.hour) < float(run.last_hour):
				_interrupt(sm, npc, run)
				continue
			run.last_hour = float(ctx.hour)
			if float(ctx.hour) + 0.000001 < float(run.start_hour) + float(run.minutes) / 60.0: continue
			var next: Dictionary = sm.living_snapshot()
			if next.is_empty(): return
			var row: Dictionary = next.world.citizens[npc]
			row.outcome = {"reflect": "reflection", "connect": "connection", "clarify": "clarification"}[run.executor]
			row.closed_day = day
			_install(sm, next)
			sm._living_cast_runs.erase(npc)
			continue
		if at.is_empty() or _reserved(sm, npc): continue
		var next: Dictionary = sm.living_snapshot()
		if next.is_empty(): return
		var citizens: Dictionary = next.world.get("citizens", {})
		var prior: Dictionary = citizens.get(npc, {})
		if int(prior.get("day", 0)) >= day: continue
		var targets: Array = []
		for tie in DATA.profile(npc).get("ties", []):
			var other: Variant = source.live.get(tie.target)
			if not _reserved(sm, tie.target) and not safe(source, other, ctx).is_empty() and Iso.to_ground(actor.global_position - other.global_position).length() <= 360.0: targets.append(tie.target)
		var action := plan(npc, DATA.profile(npc), day, prior, targets)
		if action.is_empty(): continue
		var cooldowns: Dictionary = prior.get("cooldowns", {}).duplicate()
		cooldowns[action.goal] = action.cooldown
		citizens[npc] = {"day": day, "goal": action.goal, "outcome": "pending", "target": action.target, "closed_day": 0, "cooldowns": cooldowns}
		next.world["citizens"] = citizens
		if not _install(sm, next): return
		var partner: Variant = source.live.get(action.target)
		var ticket := {"npc": npc, "day": day, "goal": action.goal, "executor": action.executor, "target": action.target, "world": sm._accounting_world, "source": weakref(source), "actor": weakref(actor), "partner": weakref(partner) if is_instance_valid(partner) else null, "place": at.place, "start_hour": float(ctx.hour), "last_hour": float(ctx.hour), "minutes": 2 if action.executor == "reflect" else 1}
		ticket["participants"] = [{"npc": npc, "actor": weakref(actor), "place": at.place, "seat": actor.global_position}]
		if is_instance_valid(partner):
			ticket.participants.append({"npc": str(partner.npc_id), "actor": weakref(partner), "place": source.targets.get(str(partner.npc_id), {}).get("place", ""), "seat": partner.global_position})
		sm._living_cast_runs[npc] = ticket
		if is_instance_valid(partner):
			actor.visual.set_facing_direction(partner.global_position - actor.global_position)
			partner.visual.set_facing_direction(actor.global_position - partner.global_position)
