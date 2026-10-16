class_name NpcDialogue
extends RefCounted
## Context and actions are shared by permanent citizens, room keepers and temporary actors.
const BRIDGE := "res://scripts/social/talk/dialogue_bridge.gd"
const REACTIONS := "res://scripts/reactions/race_reactions.gd"

static func context(npc: String, player: Node = null) -> Dictionary:
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
	for id in LuaRuntime.get_npcs():
		ctx["friend_" + str(id)] = SocialManager.hearts(str(id))
	for id in LuaRuntime.get_shops():
		ctx["shop_" + str(id)] = true
	ctx.merge(SocialManager.dialogue_context(npc), true)
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
	return ctx

static func build(npc: String, module: String, ctx: Dictionary, guest := false) -> Dictionary:
	var page := LuaRuntime.get_dialogue(module, ctx)
	page["speaker"] = npc
	page["speaker_name_key"] = str(LuaRuntime.get_npc(npc).get("name_key", ""))
	page["lines"] = LuaData.arr(page.get("lines", []))
	var choices := LuaData.arr(page.get("choices", [])).duplicate(true)
	choices = choices.filter(func(choice): return str(choice.get("action", "")) not in ["quest_accept", "quest_offer"] or QuestManager.is_offerable(StringName(str(choice.get("quest_id", "")))))
	if not guest:
		# The quest definition owns availability; adding a new giver quest needs no UI branch.
		for id in QuestManager.offerable(npc):
			if not choices.any(func(choice): return str(choice.get("quest_id", "")) == str(id)):
				var key := "QUEST_%s_CHOICE" % str(id).to_upper()
				choices.push_front({"id": "accept_" + str(id), "action": "quest_accept", "quest_id": str(id),
					"text_key": key if TranslationServer.translate(key) != key else "DLG_QUEST_ACCEPT_FMT", "title_quest": str(id)})
	else:
		choices = choices.filter(func(choice): return not str(choice.get("action", "")).begins_with("quest_") and str(choice.get("action", "")) != "open_shop")
	page["choices"] = choices
	page = Svc.static_call(BRIDGE, &"decorate", [npc, page, ctx], page)
	page = Svc.static_call(REACTIONS, &"apply", [npc, ctx, page], page)
	if LuaData.arr(page.get("lines", [])).is_empty() and LuaData.arr(page.get("choices", [])).is_empty():
		page["lines"] = [{"text_key": "DLG_NEUTRAL"}]
		page["choices"] = [{"text_key": "REL_TALK_GOODBYE", "action": "close"}]
	return page

## Called after the dialogue's modal has ended. Returns whether to ask the next quiz question.
static func action(npc: String, action_id: String, data: Dictionary, guest := false) -> bool:
	if guest and (action_id.begins_with("quest_") or action_id == "open_shop"):
		return false
	match action_id:
		"close", "":
			pass
		"quest_accept", "quest_offer":
			var id := StringName(str(data.get("quest_id", "")))
			if QuestManager.is_offerable(id):
				QuestManager.accept_quest(id)
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
			QuestManager.complete_manual(StringName(str(data.get("quest_id", ""))), StringName(str(data.get("objective_id", ""))), LuaData.dict(data.get("needs", {})), bool(data.get("consume", false)))
		"math_answer":
			if int(data.get("answer", -9999)) == int(data.get("correct", -1)):
				GameManager.set_flag(StringName(str(data.get("result_flag", ""))), true)
				QuestManager.update_objective(StringName(str(data.get("quest_id", ""))), StringName(str(data.get("objective_id", ""))))
				EventBus.notification_posted.emit(TranslationServer.translate("MATH_CORRECT_TITLE"), TranslationServer.translate("MATH_CORRECT_MSG"), "success")
			else:
				EventBus.notification_posted.emit(TranslationServer.translate("MATH_WRONG_TITLE"), TranslationServer.translate("MATH_WRONG_MSG"), "info")
			return true
		_:
			EventBus.game_event.emit(&"dialogue_action", {"npc": npc, "action": action_id, "data": data.duplicate(true)})
	return false

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
