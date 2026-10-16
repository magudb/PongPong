class_name DialogueBridge
extends RefCounted
## Pure dialogue decoration; topics commit only after their page is read.
const TALK := preload("res://scripts/social/talk/social_talk.gd")

static func decorate(npc: String, dialogue: Dictionary, context: Dictionary = {}) -> Dictionary:
	var out := dialogue.duplicate(true)
	if out.get("social", true) == false:
		return out
	var sm := Svc.node("SocialManager")
	if sm == null or not bool(sm.call("can_befriend", npc)):
		return out
	out["speaker"] = npc
	out["speaker_name_key"] = SocialData.npc_row(npc).get("name_key", "")
	var ctx: Dictionary = context if not context.is_empty() else sm.call("dialogue_context", npc)
	var lines := LuaData.arr(out.get("lines", [])).duplicate()
	if not bool(sm.call("met", npc)):
		var key := TALK.pick(npc, "FIRST", ctx)
		if key != "":
			lines.push_front(TALK.line(npc, key))
	elif not bool(ctx.get("talked_today", false)):
		var key := TALK.pick(npc, "GREET", ctx)
		if key != "":
			lines.push_front(TALK.line(npc, key))
	# A data-only citizen always has something to say, even on a repeat visit.
	if lines.is_empty():
		var key := TALK.pick(npc, "GREET", ctx)
		if key != "":
			lines.append(TALK.line(npc, key))
	out["lines"] = lines
	var choices: Array = []
	var close := {"id": "goodbye", "text_key": "REL_TALK_GOODBYE", "action": "close"}
	for c in LuaData.arr(out.get("choices", [])):
		if str(c.get("action", "")) == "close":
			close = c
		else:
			choices.append(c)
	var limits: Dictionary = sm.call("gift_limits", npc)
	if int(limits.left_today) > 0 and (int(limits.left_week) > 0 or str(sm.call("birthday_state", npc)) != "") and not LuaData.arr(sm.call("gift_options", npc)).is_empty():
		choices.append({"id": "give_gift", "text_key": "REL_TALK_GIFT", "action": "give_gift"})
	if not topics(npc).is_empty():
		choices.append({"id": "topic", "text_key": "REL_TALK_TOPIC", "action": "social_topic"})
	var events: Array = sm.call("events_ready", npc)
	if not events.is_empty():
		choices.append({"id": "event", "text_key": "REL_TALK_EVENT", "action": "start_event", "event_id": str(events[0])})
	if choices.size() > 4:
		var extra := choices.slice(3)
		choices = choices.slice(0, 3)
		choices.append({"id": "social_more", "text_key": "REL_TALK_MORE", "action": "social_more", "choices": extra})
	choices.append(close)
	out["choices"] = choices
	return out

static func topics(npc: String) -> Array[Dictionary]:
	var sm := Svc.node("SocialManager")
	if sm == null or not bool(sm.call("can_befriend", npc)):
		return []
	var row: Dictionary = sm.call("row_of", npc, false)
	if int(row.get("tp", 0)) == int(sm.call("today")):
		return []
	var h := int(sm.call("hearts", npc))
	var out: Array[Dictionary] = []
	for topic in LuaData.arr(Svc.lua_config("social_topics." + npc, [])):
		if h >= int(topic.get("hearts", 0)):
			out.append(LuaData.dict(topic))
	return out

static func topic_page(npc: String) -> Dictionary:
	var options := topics(npc)
	if options.is_empty():
		return {}
	var sm := Svc.node("SocialManager")
	var row: Dictionary = sm.call("row_of", npc)
	var chosen := mini(int(float(sm.call("roll", [npc, "topic", sm.call("today")])) * options.size()), options.size() - 1)
	# Reveal each of the three loved items before rotating known topics.
	var all: Array = Svc.lua_config("social_topics." + npc, [])
	for i in options.size():
		var index := all.find(options[i])
		if (int(row.get("rv", 0)) & (1 << index)) == 0:
			chosen = i
			break
	var topic := options[chosen]
	return {"speaker": npc, "speaker_name_key": SocialData.npc_row(npc).get("name_key", ""), "social": false,
		"lines": [TALK.line(npc, str(topic.answer_key))], "choices": [{"id": "close", "text_key": "REL_TALK_GOODBYE", "action": "close"}],
		"topic": topic, "topic_index": all.find(topic)}

static func finish_topic(npc: String, page: Dictionary, completed: bool, lines_shown: int) -> bool:
	var sm := Svc.node("SocialManager")
	if sm == null or not completed or lines_shown <= 0 or not page.has("topic"):
		return false
	var row: Dictionary = sm.call("row_of", npc)
	if int(row.get("tp", 0)) == int(sm.call("today")):
		return false
	row["tp"] = sm.call("today")
	var index := int(page.get("topic_index", -1))
	if index >= 0:
		row["rv"] = int(row.get("rv", 0)) | (1 << index)
	var item := str(page.topic.get("item", ""))
	var known := LuaData.dict(row.get("kn", {}))
	known.erase(item)
	known[item] = "love"
	while known.size() > SocialData.cfg_int("gifts.known_cap", 40):
		known.erase(known.keys()[0])
	row["kn"] = known
	return true

## Npc2D calls this after ending a page, so child modals never overlap the old page.
## Unknown actions still reach EventBus; this layer supplies the shared action data.
static func action(npc: String, action_id: String, data: Dictionary) -> Dictionary:
	match action_id:
		"social_more":
			var choices := LuaData.arr(data.get("choices", [])).duplicate(true)
			if choices.size() > 4:
				var remaining := choices.slice(3)
				choices = choices.slice(0, 3)
				choices.append({"id": "social_more", "text_key": "REL_TALK_MORE", "action": "social_more", "choices": remaining})
			choices.append({"id": "close", "text_key": "REL_TALK_GOODBYE", "action": "close"})
			return {"handled": true, "page": {"speaker": npc, "social": false, "lines": [], "choices": choices}}
		"social_topic":
			return {"handled": true, "page": topic_page(npc)}
		"give_gift":
			var bus := Svc.node("EventBus")
			if bus != null:
				bus.emit_signal("game_event", &"open_gift_picker", {"npc": npc})
			return {"handled": true}
		"start_event":
			var bus := Svc.node("EventBus")
			if bus != null:
				bus.emit_signal("game_event", &"start_heart_event", {"npc": npc, "id": str(data.get("event_id", ""))})
			return {"handled": true}
	return {"handled": false}
