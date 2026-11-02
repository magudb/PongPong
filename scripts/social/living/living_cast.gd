extends RefCounted
## Request-local conversation model. No economics, quest or identity overrides.
const DATA := preload("res://scripts/social/living/living_data.gd")
const GOALS := preload("res://scripts/social/living/living_goals.gd")
const MODES := ["listen", "space", "clarify"]
const MAX_DAY := 1000000

static func binding(npc: String) -> Dictionary:
	return LuaData.dict(Svc.lua_config("living_actions." + npc, {}))

static func eligible(npc: String) -> bool:
	return not DATA.profile(npc).is_empty() and not binding(npc).is_empty() and SocialData.npcs().has(npc) and not Routines.is_unavailable(npc, Routines.now_ctx())

static func choice(npc: String) -> Dictionary:
	return {"id": "living_motivation", "action": "living_motivation", "text_key": "LC_MOTIVATION_ASK"} if eligible(npc) else {}

static func selection(npc: String, day: int) -> Dictionary:
	return GOALS.select(npc, DATA.profile(npc), {"day": day, "available": true, "free_time": true,
		"protected": {"essential_work": false, "story": false, "festival": false, "home": false}})

static func page(npc: String, pid: StringName, correction := false) -> Dictionary:
	if not eligible(npc): return {}
	var sm := Svc.node("SocialManager")
	var day: int = sm.call("today")
	if day < 1 or day > MAX_DAY: return {}
	var b := binding(npc)
	var p := DATA.profile(npc)
	var state: Dictionary = sm.call("living_snapshot")
	var prior: Dictionary = state.get("encounters", {}).get(str(pid), {}).get(npc, {})
	var selected := selection(npc, day)
	if selected.is_empty(): return {}
	var lines: Array = []
	for key in [p.purpose_key, p.aspiration_key, p.ties[0].reason_key]: lines.append({"text_key": key})
	for goal in p.goals:
		if goal.id == selected.goal_id: lines.append({"text_key": goal.text_key})
	if not prior.is_empty(): lines.append({"text_key": b["reply_" + str(prior.response)]})
	var public_row: Dictionary = state.world.get("citizens", {}).get(npc, {})
	if public_row.get("outcome") in ["reflection", "connection", "clarification"]:
		lines.append({"text_key": b["reply_clarify" if public_row.outcome == "clarification" else "reply_" + str(public_row.outcome)]})
	var options: Array = []
	if correction:
		lines.append({"text_key": b.correction_key})
		options.append({"id": "living_confirm", "action": "living_confirm", "text_key": b.repeat_key})
	else:
		lines.append({"text_key": b.explanation_key})
		if int(prior.get("day", 0)) < day:
			options.append({"id": "living_listen", "action": "living_listen", "text_key": b.repeat_key})
			options.append({"id": "living_space", "action": "living_space", "text_key": "LC_MOTIVATION_SPACE"})
		if prior.get("response") != "clarify" or int(prior.get("day", 0)) < day:
			options.append({"id": "living_correct", "action": "living_correct", "text_key": "LC_MOTIVATION_CORRECT"})
	options.append({"id": "close", "action": "close", "text_key": "REL_TALK_GOODBYE"})
	return {"speaker": npc, "social": false, "living_cast_day": day, "living_cast_goal": selected.goal_id,
		"living_cast_correction": correction, "lines": lines, "choices": options}

## Already validated private producer calls this before any public callback.
static func respond(state: Dictionary, npc: String, pid: StringName, day: int, page_data: Dictionary, action: String) -> bool:
	var mode := {"living_listen": "listen", "living_space": "space", "living_confirm": "clarify"}.get(action, "") as String
	if mode == "" or not eligible(npc) or page_data.get("living_cast_day") != day: return false
	if mode == "clarify" and page_data.get("living_cast_correction") != true: return false
	var selected := selection(npc, day)
	if selected.is_empty() or selected.goal_id != page_data.get("living_cast_goal"): return false
	var all: Dictionary = state.get("encounters", {})
	var rows: Dictionary = all.get(str(pid), {})
	var prior: Dictionary = rows.get(npc, {})
	if int(prior.get("day", 0)) > day: return false
	if int(prior.get("day", 0)) == day and (mode != "clarify" or prior.get("response") == "clarify"): return false
	rows[npc] = {"day": day, "goal": selected.goal_id, "response": mode}
	all[str(pid)] = rows
	state["encounters"] = all
	return true

static func decode_encounters(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size() > 4: return {"ok": false}
	var out := {}
	for pid in raw:
		if typeof(pid) != TYPE_STRING or pid not in ["p0", "p1", "p2", "p3"] or not raw[pid] is Dictionary or raw[pid].size() > 34: return {"ok": false}
		var rows := {}
		for npc in raw[pid]:
			if typeof(npc) != TYPE_STRING or npc not in DATA.AUDITED_IDS: return {"ok": false}
			var r: Variant = raw[pid][npc]
			if not r is Dictionary or r.size() != 3: return {"ok": false}
			for k in r:
				if typeof(k) != TYPE_STRING or k not in ["day", "goal", "response"]: return {"ok": false}
			# Fixed canonical suffix vocabulary also preserves retired content.
			if not _day(r.get("day")) or typeof(r.get("goal")) != TYPE_STRING or r.goal not in ["lc_" + npc + "_role", "lc_" + npc + "_personal", "lc_" + npc + "_connect", "lc_" + npc + "_reconcile"]: return {"ok": false}
			if typeof(r.get("response")) != TYPE_STRING or r.response not in MODES: return {"ok": false}
			rows[npc] = {"day": int(r.day), "goal": r.goal, "response": r.response}
		out[pid] = rows
	return {"ok": true, "rows": out}

static func _day(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) == floorf(float(v)) and float(v) >= 1 and float(v) <= MAX_DAY
