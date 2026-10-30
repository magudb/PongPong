class_name NpcDialogue
extends RefCounted
## Context and actions are shared by permanent citizens, room keepers and temporary actors.
const BRIDGE := "res://scripts/social/talk/dialogue_bridge.gd"
const REACTIONS := "res://scripts/reactions/race_reactions.gd"

static func context(npc: String, player: Node = null) -> Dictionary:
	return context_owned(npc, player, EventBus.interaction_origin())

static func context_owned(npc: String, player: Node, origin: Dictionary) -> Dictionary:
	if not EventBus.interaction_current(origin): return {}
	var ctx := GameManager.world_flags.duplicate(true)
	ctx.merge({"hour": GameManager.hour, "day": GameManager.day, "season": str(GameManager.season),
		"weekday": TimeManager.weekday_index(), "total_day": GameManager.total_day(), "weather": str(TimeManager.weather),
		"race": ["animal", "fairy", "hobbit", "ghost"][clampi(GameManager.character_type, 0, 3)],
		"hero": str(CharacterCatalog.hero_of_skin(GameManager.character_skin).get("id", "")), "stamina_ratio": 1.0}, true)
	if player != null and player.get("stamina") != null and player.get("max_stamina") != null:
		ctx["stamina_ratio"] = clampf(float(player.stamina) / maxf(float(player.max_stamina), 1), 0, 1)
	var world := _tree().get_first_node_in_group("world_2d")
	ctx["zone"] = str(world.current_zone()) if world != null else ""
	for id in QuestManager.quest_defs:
		ctx["quest_active_" + str(id)] = QuestManager.is_active(StringName(str(id)))
		ctx["quest_done_" + str(id)] = QuestManager.is_completed(StringName(str(id)))
		ctx["quest_offer_" + str(id)] = QuestManager.is_offerable(StringName(str(id)))
		if not EventBus.interaction_current(origin): return {}
	for id in LuaRuntime.get_npcs():
		if not EventBus.interaction_current(origin): return {}
		ctx["friend_" + str(id)] = SocialManager.hearts(str(id))
	for id in LuaRuntime.get_shops():
		ctx["shop_" + str(id)] = true
	if not EventBus.interaction_current(origin): return {}
	ctx.merge(SocialManager.dialogue_context(npc), true)
	if not EventBus.interaction_current(origin): return {}
	# Service actions and V7 compare the monotonic clock, not the season day.
	ctx["total_day"] = GameManager.total_day()
	ctx["hour"] = GameManager.hour
	# The current counter's opening rules also drive its keeper's dialogue.
	# A data-only keeper/building addition automatically receives this context.
	var counter_building := ""
	for id in Hours.registry():
		var building := Hours.building(str(id))
		if str(building.get("keeper", "")) != npc or not building.has("hours"):
			continue
		if counter_building == "" or (world != null and world.area != null and str(building.get("interior", "")) == str(world.area.map.id)):
			counter_building = str(id)
	if counter_building != "":
		var state := Hours.state(counter_building)
		var window := Hours.hours_on(Hours.building(counter_building), int(ctx.weekday))
		ctx["shop_opens_at"] = float(window[0])
		ctx["shop_closes_at"] = float(window[1])
		ctx["shop_closed_reason"] = str(state.reason)
	if not EventBus.interaction_current(origin): return {}
	var decorated: Dictionary = Svc.static_call("res://scripts/ghostfam/hook/ghostfam_hook.gd",&"dialogue_context",[npc,ctx],ctx)
	return decorated if EventBus.interaction_current(origin) else {}

static func build(npc: String, module: String, ctx: Dictionary, guest := false) -> Dictionary:
	return build_owned(npc, module, ctx, guest, EventBus.interaction_origin())

static func build_owned(npc: String, module: String, ctx: Dictionary, guest: bool, origin: Dictionary) -> Dictionary:
	if not EventBus.interaction_current(origin): return {}
	var page := LuaRuntime.get_dialogue(module, ctx)
	if not EventBus.interaction_current(origin): return {}
	page["speaker"] = npc
	page["speaker_name_key"] = str(LuaRuntime.get_npc(npc).get("name_key", ""))
	page["lines"] = LuaData.arr(page.get("lines", []))
	var choices := LuaData.arr(page.get("choices", [])).duplicate(true)
	var filtered: Array = []
	for choice in choices:
		if not EventBus.interaction_current(origin): return {}
		if str(choice.get("action", "")) not in ["quest_accept", "quest_offer"] or QuestManager.is_offerable(StringName(str(choice.get("quest_id", "")))):
			filtered.append(choice)
		if not EventBus.interaction_current(origin): return {}
	choices = filtered
	if not guest:
		# The quest definition owns availability; adding a new giver quest needs no UI branch.
		for id in QuestManager.offerable(npc):
			if not EventBus.interaction_current(origin): return {}
			if not choices.any(func(choice): return str(choice.get("quest_id", "")) == str(id)):
				var key := "QUEST_%s_CHOICE" % str(id).to_upper()
				choices.push_front({"id": "accept_" + str(id), "action": "quest_accept", "quest_id": str(id),
					"text_key": key if TranslationServer.translate(key) != key else "DLG_QUEST_ACCEPT_FMT", "title_quest": str(id)})
	else:
		choices = choices.filter(func(choice): return not str(choice.get("action", "")).begins_with("quest_") and str(choice.get("action", "")) != "open_shop")
	if not EventBus.interaction_current(origin): return {}
	page["choices"] = choices
	page = Svc.static_call(BRIDGE, &"decorate", [npc, page, ctx], page)
	if not EventBus.interaction_current(origin): return {}
	page = Svc.static_call(REACTIONS, &"apply", [npc, ctx, page], page)
	if not EventBus.interaction_current(origin): return {}
	if LuaData.arr(page.get("lines", [])).is_empty() and LuaData.arr(page.get("choices", [])).is_empty():
		page["lines"] = [{"text_key": "DLG_NEUTRAL"}]
		page["choices"] = [{"text_key": "REL_TALK_GOODBYE", "action": "close"}]
	return page

## Persist ownership of unread current-run content before the meeting event can
## complete the lottery. Absence preserves genuinely completed legacy saves.
static func begin(npc: String, page: Dictionary) -> void:
	begin_owned(npc, page, EventBus.interaction_origin())

static func begin_owned(npc: String, page: Dictionary, origin: Dictionary) -> void:
	if not EventBus.interaction_current(origin): return
	if npc == "mayor_lyra" and bool(page.get("mayor_welcome", false)):
		GameManager.set_flag(&"mayor_welcome_pending", true)

## Record the authored welcome only after it was read. Legacy active mayor-talk
## progress alone cannot prove this: the old tutorial flag hid that very page.
static func finish(npc: String, page: Dictionary, result: Dictionary) -> void:
	finish_owned(npc, page, result, EventBus.interaction_origin())

## A completing page retains profile authority independently of its body.
static func finish_owned(npc: String, page: Dictionary, result: Dictionary, origin: Dictionary) -> void:
	if not EventBus.interaction_current(origin): return
	if npc == "mayor_lyra" and bool(page.get("mayor_welcome", false)) and bool(result.get("completed", false)) and int(result.get("lines_shown", 0)) >= LuaData.arr(page.get("lines", [])).size():
		GameManager.set_flag(&"mayor_welcome_seen", true)
		if not EventBus.interaction_current(origin): return
		GameManager.clear_flag(&"mayor_welcome_pending")

## Called after the dialogue's modal has ended. Returns whether to ask the next quiz question.
static func action(npc: String, action_id: String, data: Dictionary, guest := false) -> bool:
	return action_owned(npc, action_id, data, guest, EventBus.interaction_origin())

static func action_owned(npc: String, action_id: String, data: Dictionary, guest: bool, origin: Dictionary) -> bool:
	if not EventBus.interaction_current(origin): return false
	if guest and (action_id.begins_with("quest_") or action_id == "open_shop"):
		return false
	match action_id:
		"close", "":
			pass
		"quest_accept", "quest_offer":
			var id := StringName(str(data.get("quest_id", "")))
			if QuestManager.is_offerable(id):
				if not EventBus.interaction_current(origin): return false
				QuestManager.accept_quest_owned(id, origin)
		"open_shop":
			ShopSystem.open_shop(StringName(str(data.get("shop_id", ""))))
		"open_journal":
			EventBus.ui_panel_toggled.emit(&"journal", true)
		"home_upgrade":
			EventBus.game_event.emit(&"open_home_builder", {"tier": data.get("tier", 1)})
		"emit_event":
			var payload := LuaData.dict(data.get("payload", {})).duplicate(true)
			for key in data:
				if key not in ["id", "text_key", "action", "event", "payload"]:
					payload[key] = data[key]
			EventBus.game_event.emit(StringName(str(data.get("event", ""))), payload)
		"show_info":
			EventBus.notification_posted.emit(TranslationServer.translate("UI_INFO"), TranslationServer.translate(str(data.get("info_key", ""))), "info")
		"quest_update", "give_item":
			QuestManager.complete_manual_owned(StringName(str(data.get("quest_id", ""))), StringName(str(data.get("objective_id", ""))), LuaData.dict(data.get("needs", {})), bool(data.get("consume", false)), origin)
		"math_answer":
			if int(data.get("answer", -9999)) == int(data.get("correct", -1)):
				GameManager.set_flag(StringName(str(data.get("result_flag", ""))), true)
				if not EventBus.interaction_current(origin): return false
				QuestManager.update_objective_owned(StringName(str(data.get("quest_id", ""))), StringName(str(data.get("objective_id", ""))), 1, origin)
				if not EventBus.interaction_current(origin): return false
				EventBus.notification_posted.emit(TranslationServer.translate("MATH_CORRECT_TITLE"), TranslationServer.translate("MATH_CORRECT_MSG"), "success")
			else:
				EventBus.notification_posted.emit(TranslationServer.translate("MATH_WRONG_TITLE"), TranslationServer.translate("MATH_WRONG_MSG"), "info")
			return true
		_:
			EventBus.game_event.emit(&"dialogue_action", {"npc": npc, "action": action_id, "data": data.duplicate(true)})
	return false

## The UI receipt, not the optional NPC Node, owns already-earned page work.
## The async static continuation never retains an acting-player scope or uses a
## Node-typed argument after a callback without resolving its weak identity.
static func present_owned(actor: Variant, page: Dictionary, origin: Dictionary, attachment: RefCounted, screen: Node, request: RefCounted) -> void:
	if not is_instance_valid(actor) or not EventBus.interaction_physical_current(origin, actor): return
	var npc := str(actor.npc_id)
	var guest: bool = actor.guest
	var speaker := {"id": npc, "name_key": str(actor.display_name_key)}
	var actor_ref: WeakRef = weakref(actor)
	var body: Variant = actor._talk_player
	var body_ref: Variant = weakref(body) if is_instance_valid(body) else null
	actor = null
	body = null
	screen.request_lines(speaker, LuaData.arr(page.get("lines", [])), LuaData.arr(page.get("choices", [])), request)
	var result: Dictionary = await screen.wait_request(request)
	var current_actor: Variant = actor_ref.get_ref()
	var attached: bool = is_instance_valid(current_actor) and current_actor._ui_request == request and current_actor._attached(attachment)
	if attached: current_actor._ui_request = null
	if EventBus.interaction_current(origin):
		PlayerRegistry.for_player(origin.recipient.player_id, func(): finish_owned(npc, page, result, origin))
	# Finishing a flag can itself destroy/detach the actor. Cleanup and weekly
	# accounting are distinct: detached cleanup already published its end, but
	# a completed read still owes its profile-bound accounting exactly once.
	current_actor = actor_ref.get_ref()
	if is_instance_valid(current_actor) and current_actor._attached(attachment):
		current_actor._end_talk(int(result.get("lines_shown", 0)), bool(result.get("completed", false)), attachment)
	elif bool(result.get("completed", false)) and EventBus.interaction_current(origin):
		PlayerRegistry.for_player(origin.recipient.player_id, func():
			SocialManager.conversation_finished_owned(npc, int(result.get("lines_shown", 0)), bool(result.get("completed", false)), origin))
	if not EventBus.interaction_current(origin): return
	PlayerRegistry.for_player(origin.recipient.player_id, func():
		Svc.static_call(BRIDGE, &"finish_topic_owned", [npc, page, bool(result.get("completed", false)), int(result.get("lines_shown", 0)), origin], false))
	if not attached or not EventBus.interaction_current(origin): return
	PlayerRegistry.for_player(origin.recipient.player_id, func():
		var live_actor: Variant = actor_ref.get_ref()
		var live_body: Variant = body_ref.get_ref() if body_ref is WeakRef else null
		if not EventBus.interaction_body_current(origin, live_actor, live_body): return
		var choice := LuaData.dict(result.get("choice", {}))
		var action_id := str(choice.get("action", "close"))
		var social: Dictionary = Svc.static_call(BRIDGE, &"action_owned", [npc, action_id, choice, origin], {})
		live_actor = actor_ref.get_ref()
		live_body = body_ref.get_ref() if body_ref is WeakRef else null
		if not EventBus.interaction_body_current(origin, live_actor, live_body): return
		if bool(social.get("handled", false)):
			if not LuaData.dict(social.get("page", {})).is_empty(): live_actor._owned_followup.call_deferred(body_ref, social.page, origin)
		elif action_owned(npc, action_id, choice, guest, origin):
			live_actor = actor_ref.get_ref()
			live_body = body_ref.get_ref() if body_ref is WeakRef else null
			if EventBus.interaction_body_current(origin, live_actor, live_body): live_actor._interact_owned.call_deferred(body_ref, origin))

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
