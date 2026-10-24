class_name LivingGoals
extends RefCounted
## Pure optional-goal decision. No authority, schedule, transaction or state owner.

const MAX_DAY := 1000000
const DATA := preload("res://scripts/social/living/living_data.gd")
const HELP := "future_committed_mining_help"


static func select(npc: String, profile: Dictionary, inputs: Dictionary, previous: Dictionary = {}) -> Dictionary:
	if not _profile(npc, profile) or not _whole(inputs.get("day"), 1, MAX_DAY):
		return {}
	for field in ["available", "free_time"]:
		if typeof(inputs.get(field)) != TYPE_BOOL or inputs[field] != true:
			return {}
	if typeof(inputs.get("protected")) != TYPE_DICTIONARY:
		return {}
	for field in ["essential_work", "story", "festival", "home"]:
		if typeof(inputs.protected.get(field)) != TYPE_BOOL or inputs.protected[field] != false:
			return {}
	var day := int(inputs.day)
	var goals := {}
	for goal in profile.get("goals", []):
		goals[goal.id] = goal
	if not _maps(inputs, goals):
		return {}
	var prior := {}
	if not previous.is_empty():
		prior = _previous(npc, goals, previous, day)
		if prior.is_empty():
			return {}
		if prior.selected_day == day:
			return prior
	var best := {}
	for goal in goals.values():
		var until := int(inputs.get("cooldowns", {}).get(goal.id, 0))
		if prior.get("goal_id") == goal.id:
			until = maxi(until, prior.cooldown_until_day)
		if day < until:
			continue
		var trigger: String = goal.trigger
		if trigger != "none" and inputs.get("triggers", {}).get(trigger) != true:
			continue
		var reasons := {"value": goal.value, "value_weight": int(profile.values[goal.value]),
			"goal_weight": int(goal.weight), "weighted_value": int(profile.values[goal.value]) * int(goal.weight),
			"trigger_bonus": 1 if trigger != "none" else 0}
		var utility := int(reasons.weighted_value) + int(reasons.trigger_bonus)
		if best.is_empty() or utility > best.utility or (utility == best.utility and goal.id < best.goal_id):
			best = _record(npc, goal, day, day + int(goal.expires_days), day + int(goal.cooldown_days), reasons)
	return best


## Reconstruct only known bounded scalar fields; never duplicate arbitrary previous payloads.
static func _previous(npc: String, goals: Dictionary, raw: Dictionary, day: int) -> Dictionary:
	if not _text_is(raw.get("npc"), npc) or not _token(raw.get("goal_id")) or not goals.has(raw.goal_id):
		return {}
	var goal: Dictionary = goals[raw.goal_id]
	if not _text_is(raw.get("kind"), goal.kind) or not _text_is(raw.get("target", ""), goal.get("target", "")):
		return {}
	if not _whole(raw.get("selected_day"), 1, day):
		return {}
	var selected := int(raw.selected_day)
	if not _whole(raw.get("expiry_day"), selected + 1, selected + 7):
		return {}
	if not _whole(raw.get("cooldown_until_day"), selected + 1, selected + 14):
		return {}
	if typeof(raw.get("reasons")) != TYPE_DICTIONARY:
		return {}
	var r: Dictionary = raw.reasons
	if not _text_is(r.get("value"), goal.value) or not _whole(r.get("value_weight"), 1, 5) or not _whole(r.get("goal_weight"), 1, 5):
		return {}
	var weighted := int(r.value_weight) * int(r.goal_weight)
	var bonus := 1 if goal.trigger != "none" else 0
	if not _whole(r.get("weighted_value"), weighted, weighted) or not _whole(r.get("trigger_bonus"), bonus, bonus):
		return {}
	if not _whole(raw.get("utility"), weighted + bonus, weighted + bonus):
		return {}
	return _record(npc, goal, selected, int(raw.expiry_day), int(raw.cooldown_until_day),
		{"value": goal.value, "value_weight": int(r.value_weight), "goal_weight": int(r.goal_weight),
		"weighted_value": weighted, "trigger_bonus": bonus})


static func _record(npc: String, goal: Dictionary, day: int, expiry: int, cooldown: int, reasons: Dictionary) -> Dictionary:
	reasons.make_read_only()
	var record := {"npc": npc, "goal_id": goal.id, "kind": goal.kind, "selected_day": day,
		"expiry_day": expiry, "cooldown_until_day": cooldown,
		"utility": int(reasons.weighted_value) + int(reasons.trigger_bonus), "reasons": reasons}
	if goal.has("target"):
		record["target"] = goal.target
	record.make_read_only()
	return record


## LC1 structural validation only: no runtime/file/localization/service reads.
## Catalogue authoring validation remains LivingData.validate's separate responsibility.
static func _profile(npc: String, p: Dictionary) -> bool:
	if npc not in DATA.AUDITED_IDS or not _text_is(p.get("id"), npc) or not _text_is(p.get("authorship"), "original_proposal"):
		return false
	if typeof(p.get("retired", false)) != TYPE_BOOL or p.get("retired", false) != false:
		return false
	for field in ["role", "age", "family", "twin", "unlock", "routine", "name_key", "home_area", "partner", "hearts"]:
		if p.has(field):
			return false
	for field in ["purpose_key", "aspiration_key"]:
		if not _token(p.get(field)):
			return false
	for field in ["identity_source", "availability_source"]:
		if not _source(p.get(field)):
			return false
	if typeof(p.get("values")) != TYPE_DICTIONARY or p.values.size() < 2 or p.values.size() > 4:
		return false
	for value in p.values:
		if not _token(value) or not _whole(p.values[value], 1, 5):
			return false
	if typeof(p.get("ties")) != TYPE_ARRAY or p.ties.size() < 1 or p.ties.size() > 8:
		return false
	var targets := {}
	for tie in p.ties:
		if typeof(tie) != TYPE_DICTIONARY:
			return false
		var target: Variant = tie.get("target")
		if typeof(target) != TYPE_STRING or target not in DATA.AUDITED_IDS or target == npc or targets.has(target):
			return false
		targets[target] = true
		if typeof(tie.get("provenance")) != TYPE_STRING or tie.provenance not in ["established", "proposed"] or not _source(tie.get("source")) or not _token(tie.get("reason_key")):
			return false
		if tie.provenance == "proposed" and tie.source != DATA.PROPOSAL_PATH:
			return false
	if typeof(p.get("goals")) != TYPE_ARRAY or p.goals.size() < 1 or p.goals.size() > 4:
		return false
	var ids := {}
	for goal in p.goals:
		if typeof(goal) != TYPE_DICTIONARY or not _goal(npc, goal, p.values, targets):
			return false
		if ids.has(goal.id):
			return false
		ids[goal.id] = true
	return true


static func _goal(npc: String, g: Dictionary, values: Dictionary, targets: Dictionary) -> bool:
	if not _token(g.get("id")) or not g.id.begins_with("lc_" + npc + "_"):
		return false
	if typeof(g.get("kind")) != TYPE_STRING or g.kind not in DATA.GOAL_KINDS or not _token(g.get("value")) or not values.has(g.value):
		return false
	if not _whole(g.get("weight"), 1, 5) or not _whole(g.get("cooldown_days"), 1, 14) or not _whole(g.get("expires_days"), 1, 7):
		return false
	if typeof(g.get("eligible")) != TYPE_DICTIONARY or g.eligible != {"free_time": true, "existing_availability": true}:
		return false
	if not _token(g.get("text_key")) or typeof(g.get("trigger")) != TYPE_STRING or g.trigger not in ["none", HELP]:
		return false
	if g.trigger == HELP and (npc != "smith_thorin" or g.kind != "personal"):
		return false
	if g.kind in ["connect", "reconcile"]:
		if not _token(g.get("target")) or not targets.has(g.target):
			return false
	elif g.has("target"):
		return false
	if not _whole(g.get("currency"), 0, 0) or typeof(g.get("resources")) != TYPE_DICTIONARY or g.resources.size() > 4:
		return false
	for item in g.resources:
		if not _token(item) or not _whole(g.resources[item], 1, 4):
			return false
	if npc in ["baker_maja", "beekeeper_birk", "smith_thorin"] and not g.resources.is_empty():
		return false
	if typeof(g.get("resolutions")) != TYPE_ARRAY or g.resolutions.size() < 2 or g.resolutions.size() > 3:
		return false
	var resolutions := {}
	for r in g.resolutions:
		if typeof(r) != TYPE_DICTIONARY or not _token(r.get("id")) or resolutions.has(r.id):
			return false
		if typeof(r.get("kind")) != TYPE_STRING or r.kind not in DATA.RESOLUTION_KINDS or not _token(r.get("text_key")):
			return false
		resolutions[r.id] = r.kind
	return _token(g.get("fallback")) and _token(g.get("reconciliation")) and resolutions.get(g.fallback) == "autonomous" and resolutions.get(g.reconciliation) == "clarification"


static func _maps(inputs: Dictionary, goals: Dictionary) -> bool:
	var triggers: Variant = inputs.get("triggers", {})
	if typeof(triggers) != TYPE_DICTIONARY or triggers.size() > 1:
		return false
	for key in triggers:
		if typeof(key) != TYPE_STRING or key != HELP or typeof(triggers[key]) != TYPE_BOOL:
			return false
	var cooldowns: Variant = inputs.get("cooldowns", {})
	if typeof(cooldowns) != TYPE_DICTIONARY or cooldowns.size() > 4:
		return false
	for id in cooldowns:
		if not _token(id) or not goals.has(id) or not _whole(cooldowns[id], 1, MAX_DAY + 14):
			return false
	return true


static func _text_is(value: Variant, expected: String) -> bool:
	return typeof(value) == TYPE_STRING and value == expected


static func _token(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and value.length() >= 1 and value.length() <= 128 and value.is_valid_identifier()


static func _source(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and value.length() <= 256 and value.begins_with("res://") and value.length() > 6


static func _whole(value: Variant, low: int, high: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= low and number <= high
