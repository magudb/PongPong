extends RefCounted
## Pure informational encounter, not a promise/reward/choice transaction.
const NPC := "smith_thorin"
const ACTION := "living_activity"
const PAIR := preload("res://scripts/social/living/living_pair.gd")

static func pause_choice(npc: String) -> Dictionary:
	if npc not in PAIR.IDS: return {}
	return {"id": "living_pause", "action": "living_pause", "text_key": "LC_PAUSE_ASK"}

static func pause_page(npc: String, pid: StringName) -> Dictionary:
	if npc not in PAIR.IDS: return {}
	var sm := Svc.node("SocialManager")
	var state: Dictionary = sm.call("living_snapshot")
	var response: Dictionary = state.get("responses", {}).get(str(pid), {})
	var day: int = sm.call("today")
	var options: Array = []
	var line := PAIR.reply(state)
	if response.get("day") == day:
		line = "LC_PAUSE_" + str(response.get("choice", "")).to_upper()
		if int(response.get("ack_day", 0)) == day: line = "LC_PAUSE_SUPPORTED"
		elif int(response.get("attended_day", 0)) == day: line = "LC_PAUSE_PRESENT"
		if response.get("choice") == "help" and int(response.get("attended_day", 0)) == day and int(response.get("ack_day", 0)) < day:
			options.append({"id": "living_ack", "action": "living_ack", "text_key": "LC_PAUSE_ACK"})
	elif int(response.get("not_before_day", 0)) <= day:
		for id in ["help", "defer", "decline"]:
			options.append({"id": "living_" + id, "action": "living_" + id, "text_key": "LC_PAUSE_CHOOSE_" + id.to_upper()})
	if PAIR.row(state).get("status") == "needs_clarification":
		options.append({"id": "living_clarify", "action": "living_clarify", "text_key": "LC_PAUSE_CLARIFY"})
	options.append({"id": "close", "action": "close", "text_key": "REL_TALK_GOODBYE"})
	return {"speaker": npc, "social": false, "living_pause_day": day,
		"lines": [{"text_key": line}, {"text_key": "LC_PAUSE_OPTIONAL"}], "choices": options}


static func choice(npc: String) -> Dictionary:
	var sm := Svc.node("SocialManager")
	if npc != NPC or sm == null or not sm.has_method("living_activity_snapshot"): return {}
	var snapshot: Dictionary = sm.call("living_activity_snapshot")
	if int(snapshot.get("day", 0)) != int(sm.call("today")) or snapshot.get("selected", {}).get("goal_id") != "lc_smith_thorin_personal": return {}
	# The durable selection is not a promise that survives a live interruption.
	# Use the same envelope as the schedule and re-run this at action time.
	var ctx := Routines.now_ctx()
	if float(ctx.hour) >= 20.0 or load("res://scripts/social/living/living_activity.gd").envelope(ctx).is_empty(): return {}
	return {"id": ACTION, "action": ACTION, "text_key": "LC_ACTIVITY_ASK"}

## Called only by the actual Npc2D page route while its live body/session still
## belongs to this registered player. No NPC/goal/player from a choice payload
## authorizes this route. Opening/reading/cancelling changes no LC state.
static func action(actor: Node, player: Node, page: Dictionary, result: Dictionary) -> Dictionary:
	if not actor is Npc2D or not actor.is_inside_tree() or actor.is_queued_for_deletion() or not actor.is_talking or actor._talk_player != player: return {}
	var pid := PlayerRegistry.registered_id(player)
	if pid == &"" or PlayerRegistry.acting_id() != pid or str(actor.npc_id) != NPC or result.get("completed") != true: return {}
	var picked: Dictionary = result.get("choice", {})
	if picked.get("action") != ACTION or picked.get("id") != ACTION: return {}
	if not page.get("choices", []).any(func(c): return c.get("id") == ACTION and c.get("action") == ACTION): return {}
	if choice(str(actor.npc_id)).is_empty(): return {}
	return {"speaker": NPC, "social": false, "lines": [{"text_key": "LC_SMITH_THORIN_ACTIVITY"}],
		"choices": [{"id": "close", "action": "close", "text_key": "REL_TALK_GOODBYE"}]}
