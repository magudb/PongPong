extends RefCounted
## Real quest definitions and transactions, entered through the real NPC.

static func hand_in(t, quest: StringName, needs: Dictionary, cave := false) -> void:
	await t.start_world()
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	var label := str(quest) + "_"
	var reward_items := LuaData.int_map(LuaData.dict(qm.get_quest_def(quest).get("rewards", {})).get("items", {}))
	var reward_before := _counts(eco, reward_items)
	t.expect(qm.accept_quest(quest), "Accept delivery " + str(quest))
	for item in needs:
		eco.add_item(StringName(item), int(needs[item]) + 2)
	qm.refresh_objectives()
	var stock := {}
	for item in needs:
		stock[item] = eco.count_item(StringName(item))
	t.check(label + "collection_does_not_consume", stock.values().all(func(n): return int(n) > 2) and qm.is_active(quest))
	var saves: Node = t.autoload("SaveManager")
	var directory: String = saves.save_dir
	saves.save_dir = "user://delivery-" + str(quest)
	t.check(label + "collected_progress_survives_save_load", saves.save_game(0) and saves.load_game(0) and qm.is_active(quest) and _counts(eco, needs) == stock)
	saves.save_dir = directory
	var gold: int = eco.gold
	var smith := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	smith.area = t.world().area
	t.world().area.objects.add_child(smith)
	smith.interact(t.player())
	t.check(label + "materials_wait_for_exploration_and_smith", qm.is_active(quest) and _counts(eco, needs) == stock and eco.gold == gold)
	await _close(t)
	t.autoload("GameManager").unlock_zone(&"dark_forest")
	bus.zone_entered.emit(&"dark_forest")
	if cave:
		bus.zone_entered.emit(&"crystal_cave")
	var baker := Npc2D.create({"id": "baker_maja", "wander": "0"})
	baker.area = t.world().area
	t.world().area.objects.add_child(baker)
	baker.interact(t.player())
	t.check(label + "wrong_npc_cannot_take_materials", qm.is_active(quest) and _counts(eco, needs) == stock and eco.gold == gold)
	await _close(t)
	baker.queue_free()
	# Every have objective is now done. Selling the last requirement must still
	# block the hand-in, with no partial deduction of the earlier requirements.
	var last: StringName = StringName(needs.keys()[-1])
	eco.remove_item(last, 3)
	var before: Dictionary = eco.get_inventory_dict().duplicate(true)
	smith.interact(t.player())
	t.check(label + "missing_material_blocks_reward_and_progress", qm.is_active(quest) and not qm.is_completed(quest) and eco.gold == gold and not bool(qm.get_objective_progress(quest, &"return_to_smith").get("done", false)))
	t.check(label + "missing_material_grants_no_reward_items", _counts(eco, reward_items) == reward_before and qm.pending_rewards.is_empty())
	t.check(label + "missing_last_material_is_atomic_no_loss", eco.get_inventory_dict() == before, "%s -> %s" % [before, eco.get_inventory_dict()])
	await _close(t)
	eco.add_item(last, 3)
	var observations: Array = []
	var observe := func(_pid, q, objective, _current, _target):
		if q == quest and objective == &"return_to_smith":
			var counts := {}
			for item in needs:
				counts[item] = eco.count_item(StringName(item))
			observations.append(counts)
	bus.quest_objective_updated.connect(observe)
	var completions: Array = []
	var reenter := func(_pid, q):
		if q == quest:
			completions.append(q)
			bus.start_npc_meeting(smith)
	bus.quest_completed.connect(reenter)
	smith.interact(t.player())
	var expected := {}
	for item in needs:
		expected[item] = int(stock[item]) - int(needs[item])
	t.check(label + "real_smith_handin_consumes_atomically", observations == [expected], "observed=%s expected=%s" % [observations, expected])
	t.check(label + "handin_completes_and_rewards", qm.is_completed(quest) and not qm.is_active(quest) and eco.gold == gold + 600)
	var reward_expected := reward_before.duplicate()
	for item in reward_items:
		reward_expected[item] = int(reward_before[item]) + int(reward_items[item])
	t.check(label + "handin_grants_exact_reward_items", _counts(eco, reward_items) == reward_expected and qm.pending_rewards.is_empty())
	t.check(label + "reentrant_observer_cannot_double_handin", completions == [quest] and observations == [expected])
	bus.quest_objective_updated.disconnect(observe)
	bus.quest_completed.disconnect(reenter)
	await _close(t)
	smith.interact(t.player())
	var after := {}
	for item in needs:
		after[item] = eco.count_item(StringName(item))
	t.check(label + "second_talk_cannot_charge_or_reward_again", after == expected and eco.gold == gold + 600 and _counts(eco, reward_items) == reward_expected)
	await _close(t)
	var gm: Node = t.autoload("GameManager")
	Fresh.jump_to_total_day(gm.total_day() + 6)
	t.check(label + "seven_day_cooldown_preserved", not qm.is_offerable(quest) and not qm.accept_quest(quest))
	Fresh.jump_to_total_day(gm.total_day() + 1)
	var offered: bool = qm.is_offerable(quest)
	var accepted: bool = qm.accept_quest(quest)
	t.check(label + "repeat_available_after_seven_days", offered and accepted, "offer=%s accept=%s day=%s completed=%s flags=%s" % [offered, accepted, gm.total_day(), qm.completed_days, gm.world_flags])
	bus.zone_entered.emit(&"dark_forest")
	if cave:
		bus.zone_entered.emit(&"crystal_cave")
	var repeat_gold: int = eco.gold
	var repeat_stock := _counts(eco, needs)
	smith.interact(t.player())
	t.check(label + "repeat_requires_fresh_materials", qm.is_active(quest) and eco.gold == repeat_gold and _counts(eco, needs) == repeat_stock)
	await _close(t)
	for item in needs:
		var shortfall: int = int(needs[item]) - eco.count_item(StringName(item))
		if shortfall > 0:
			eco.add_item(StringName(item), shortfall)
	qm.refresh_objectives()
	smith.interact(t.player())
	t.check(label + "fresh_repeat_consumes_and_rewards_once", not qm.is_active(quest) and eco.gold == repeat_gold + 600 and _counts(eco, needs).values().all(func(n): return int(n) == 0) and qm.completed_quests.count(quest) == 1)
	await _close(t)
	smith.queue_free()

static func service_offer(t, ready: StringName, offered: StringName, service: String, decision: String) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("traetoppen." + service + ".givers", ["smith_thorin"])
	gm.day = 2
	gm.unlock_zone(&"dark_forest")
	# The mailbox prioritizes Pip's introduction until it is accepted.
	qm.accept_quest(&"pips_runde")
	qm.accept_quest(&"sword_upgrade")
	t.expect(qm.accept_quest(ready), service + " accepts ready delivery " + str(ready))
	var needs := {"iron_ore": 6, "amethyst": 2} if ready == &"dark_forest_mining" else {"crystal_shard": 5}
	for item in needs:
		eco.add_item(StringName(item), int(needs[item]))
	qm.refresh_objectives()
	bus.zone_entered.emit(&"dark_forest")
	bus.zone_entered.emit(&"crystal_cave")
	var before: Dictionary = qm.to_dict().duplicate(true)
	var economy: Dictionary = eco.to_dict().duplicate(true)
	var label := service + "_" + str(ready) + "_" + decision
	_ready_delivery(t, qm, eco, ready, needs, label)
	var screen: Node = t.tree.get_first_node_in_group("dialogue_ui")
	var owner: Node
	if service == "board":
		owner = NoticeBoard2D.new()
		t.world().area.objects.add_child(owner)
		owner.interact(t.player())
		await t.page_to_choices(screen)
		var index: int = screen._choices.find_custom(func(row): return str(row.get("quest_id", "")) == str(offered))
		if not t.expect(index >= 0, label + " actual board offers other smith quest"):
			await _close(t)
			owner.queue_free()
			gm.clear_config_overrides()
			return
		screen._buttons[index].pressed.emit()
		await t.frames(3)
	else:
		owner = t.world().area.find_markers("mailbox")[0].node
		owner.refresh()
		t.expect(str(owner.letter.get("quest_id", "")) == str(offered), label + " actual mailbox selects other smith quest")
		owner.interact(t.player())
	t.check(label + "_offer_is_synthetic_smith_dialogue", screen.is_open() and str(screen._speaker.id) == "smith_thorin" and screen._lines.any(func(row): return row.get("text_key", "") == "QUEST_%s_OFFER" % str(offered).to_upper()))
	t.check(label + "_opening_offer_cannot_hand_in", qm.to_dict() == before and eco.to_dict() == economy)
	# Neither a borrowed NPC id nor a service node nor an idle real smith owns
	# a physical meeting. Exercise the consumer's source/ownership boundary.
	bus.start_dialogue(&"smith_thorin", &"smith_thorin")
	bus.start_npc_meeting(owner)
	var idle := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	idle.area = t.world().area
	t.world().area.objects.add_child(idle)
	bus.start_npc_meeting(idle)
	idle.queue_free()
	t.check(label + "_unowned_sources_cannot_hand_in", qm.to_dict() == before and eco.to_dict() == economy)
	if decision == "cancel":
		await _close(t)
	else:
		await t.page_to_choices(screen)
		screen._buttons[0 if decision == "accept" else 1].pressed.emit()
		await t.frames(3)
	var after: Dictionary = qm.to_dict().duplicate(true)
	if decision == "accept":
		t.check(label + "_accepts_only_offered_quest", qm.is_active(offered))
		# Acceptance legitimately adds only this quest; the ready hand-in and
		# every pre-existing objective, completion and deferred reward must stay.
		after.active.erase(str(offered))
	t.check(label + "_decision_cannot_hand_in", after == before and eco.to_dict() == economy, "%s -> %s" % [before, after])
	if service == "board":
		owner.queue_free()
	gm.clear_config_overrides()

static func invalid_owner(t, producer: String) -> void:
	await t.start_world()
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	var quest := &"dark_forest_mining"
	t.expect(qm.accept_quest(quest), "Invalid-owner fixture accepts ready quest")
	eco.add_item(&"iron_ore", 8)
	eco.add_item(&"amethyst", 4)
	qm.refresh_objectives()
	bus.zone_entered.emit(&"dark_forest")
	_ready_delivery(t, qm, eco, quest, {"iron_ore": 6, "amethyst": 2}, "invalid_" + producer)
	var fake := PlayerStub2D.new()
	fake.player_id = &"p0" # Claiming the local identity is not roster membership.
	t.world().add_child(fake)
	var before := _owner_state(t, &"p0")
	var smith := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	smith.area = t.world().area
	t.world().area.objects.add_child(smith)
	if producer == "initial":
		smith.interact(fake)
	elif producer == "followup":
		smith._begin_followup(fake, {"lines": [{"text_key": "DLG_NEUTRAL"}], "choices": [{"text_key": "REL_TALK_GOODBYE", "action": "close"}]})
	else:
		# Independently exercise the consumer: even a live actor's claimed
		# conversation owner must resolve to the registered body, not its id.
		smith.is_talking = true
		smith._talk_player = fake
		bus.start_npc_meeting(smith)
	t.check("invalid_" + producer + "_unregistered_owner_refused", _owner_state(t, &"p0") == before)
	if producer != "consumer":
		t.check("invalid_" + producer + "_cannot_open_conversation", not smith.is_talking and not t.tree.get_first_node_in_group("dialogue_ui").is_open())
		if t.tree.get_first_node_in_group("dialogue_ui").is_open():
			await _close(t)
	# Null and a live ordinary Node also fail closed, without creating a row.
	smith.is_talking = false
	smith._talk_player = null
	var ordinary := Node.new()
	t.world().add_child(ordinary)
	for invalid in [null, ordinary]:
		if producer == "initial":
			smith.interact(invalid)
		elif producer == "followup":
			smith._begin_followup(invalid, {})
		else:
			smith.is_talking = true
			smith._talk_player = invalid
			bus.start_npc_meeting(smith)
		t.check("invalid_" + producer + "_null_or_nonplayer_refused", _owner_state(t, &"p0") == before and not t.tree.get_first_node_in_group("dialogue_ui").is_open())
	ordinary.queue_free()
	smith._talk_player = null
	smith.is_talking = false
	smith.queue_free()
	fake.queue_free()

static func _ready_delivery(t, qm: Node, eco: Node, quest: StringName, needs: Dictionary, label: String) -> void:
	t.check(label + "_ready_quest_is_active", qm.is_active(quest) and not qm.is_completed(quest))
	for objective in LuaData.arr(qm.get_quest_def(quest).get("objectives", [])):
		var id := StringName(str(objective.id))
		var done := bool(qm.get_objective_progress(quest, id).get("done", false))
		t.check(label + "_precondition_" + str(id), not done if id == &"return_to_smith" else done)
	t.check(label + "_required_stock_is_owned", needs.keys().all(func(item): return eco.count_item(StringName(item)) >= int(needs[item])))

static func _owner_state(t, pid: StringName) -> Dictionary:
	return PlayerRegistry.for_player(pid, func():
		return {"quests": t.autoload("QuestManager").to_dict().duplicate(true), "economy": t.autoload("EconomyManager").to_dict().duplicate(true),
			"flags": PlayerRegistry.state().flags.duplicate(true), "social": t.autoload("SocialManager").row_of("smith_thorin", false).duplicate(true)})

static func owner_hand_in(t, quest: StringName, producer: String, ambient: StringName) -> void:
	await t.start_world()
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var label := "owner_" + str(quest) + "_" + producer + "_" + (str(ambient) if ambient != &"" else "outside")
	var players: Array = []
	for slot in [1, 2]:
		var body := PlayerStub2D.new()
		t.world()._register_player(body, slot, slot + 1)
		t.world().add_child(body)
		players.append(body)
	var ordinary := &"zz_p13_owner_talk"
	qm.register_quest_from_lua({"id": ordinary, "objectives": [{"id": "talk", "target": 1, "on": "dialogue_started", "npc": "smith_thorin"}, {"id": "reply", "target": 1, "on": "manual"}], "rewards": {}, "meta": {}})
	var needs := {"iron_ore": 6, "amethyst": 2} if quest == &"dark_forest_mining" else {"crystal_shard": 5}
	var reward_items := LuaData.int_map(LuaData.dict(qm.get_quest_def(quest).get("rewards", {})).get("items", {}))
	for slot in [0, 1, 2]:
		var pid := StringName("p%d" % slot)
		# Crystal's shipped availability flag is world-wide, so other rows
		# use the equally ready mining quest rather than bypassing that gate.
		var row_quest: StringName = quest if slot == 1 else &"dark_forest_mining"
		var row_needs: Dictionary = needs if slot == 1 else {"iron_ore": 6, "amethyst": 2}
		PlayerRegistry.for_player(pid, func():
			t.expect(qm.accept_quest(row_quest), label + " accepted for " + str(pid))
			t.expect(qm.accept_quest(ordinary), label + " ordinary accepted for " + str(pid))
			eco.gold = 1000 + slot * 100
			for item in row_needs:
				eco.add_item(StringName(item), int(row_needs[item]) + slot + 2)
			qm.refresh_objectives()
			bus.zone_entered.emit(&"dark_forest")
			bus.zone_entered.emit(&"crystal_cave")
			_ready_delivery(t, qm, eco, row_quest, row_needs, label + "_" + str(pid)))
	await t.frames(3)
	var before := {}
	for pid in [&"p0", &"p1", &"p2"]:
		before[pid] = _owner_state(t, pid)
	var owner_stock: Dictionary = PlayerRegistry.for_player(&"p1", func(): return _counts(eco, needs))
	var smith := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	smith.area = t.world().area
	t.world().area.objects.add_child(smith)
	var observations: Array = []
	var observe := func(pid, q, objective, _current, _target):
		if q == quest and objective == &"return_to_smith":
			observations.append({"pid": pid, "stock": _counts(eco, needs)})
	var completions: Array = []
	var reenter := func(pid, q):
		if q == quest:
			completions.append(pid)
			bus.start_npc_meeting(smith)
	bus.quest_objective_updated.connect(observe)
	bus.quest_completed.connect(reenter)
	var inventory_players: Array = []
	var gained := {}
	var gold_signals: Array = []
	var inventory_observer := func(pid, _inventory): inventory_players.append(pid)
	var item_observer := func(pid, item, amount):
		inventory_players.append(pid)
		gained[str(item)] = int(gained.get(str(item), 0)) + int(amount)
	var gold_observer := func(pid, _balance, delta): gold_signals.append([pid, delta])
	bus.player_inventory_changed.connect(inventory_observer)
	bus.item_gained.connect(item_observer)
	bus.gold_changed.connect(gold_observer)
	var start := func():
		var prior_scope := PlayerRegistry._acting_id
		if producer == "initial":
			smith.interact(players[0])
		elif producer == "consumer":
			smith.is_talking = true
			smith._talk_player = players[0]
			bus.start_npc_meeting(smith)
		else:
			smith._begin_followup(players[0], {"lines": [{"text_key": "DLG_NEUTRAL"}], "choices": [{"text_key": "REL_TALK_GOODBYE", "action": "close"}]})
		t.check(label + "_restores_callers_scope", PlayerRegistry._acting_id == prior_scope)
	if ambient == &"":
		start.call()
	else:
		PlayerRegistry.for_player(ambient, start)
	t.check(label + "_scope_restored_before_await", PlayerRegistry._acting_id == &"")
	var expected := {}
	for item in needs:
		expected[item] = int(owner_stock[item]) - int(needs[item])
	t.check(label + "_owner_atomic_handin_signal", observations == [{"pid": &"p1", "stock": expected}], str(observations))
	if producer == "consumer":
		# Standalone consumer verification must not be masked by a producer's
		# own scope. Only after checking it, enter the real UI/read path.
		smith._end_talk(0, false)
		smith._begin_followup(players[0], {"lines": [{"text_key": "DLG_NEUTRAL"}], "choices": [{"text_key": "REL_TALK_GOODBYE", "action": "close"}]})
	PlayerRegistry.for_player(&"p1", func():
		t.check(label + "_owner_only_completed_with_exact_reward", qm.is_completed(quest) and eco.gold == int(before[&"p1"].economy.gold) + 600 and qm.pending_rewards.is_empty())
		for item in reward_items:
			t.check(label + "_exact_reward_" + str(item), eco.count_item(StringName(item)) == int(reward_items[item]))
		t.check(label + "_ordinary_dialogue_bound_to_owner", bool(qm.get_objective_progress(ordinary, &"talk").get("done", false))))
	t.check(label + "_reentrant_completion_exactly_once", completions == [&"p1"])
	t.check(label + "_inventory_reward_signals_identify_owner", not inventory_players.is_empty() and inventory_players.all(func(pid): return pid == &"p1") and gained == reward_items and gold_signals == [[&"p1", 600]], "%s %s %s" % [inventory_players, gained, gold_signals])
	bus.player_inventory_changed.disconnect(inventory_observer)
	bus.item_gained.disconnect(item_observer)
	bus.gold_changed.disconnect(gold_observer)
	bus.quest_objective_updated.disconnect(observe)
	bus.quest_completed.disconnect(reenter)
	# Complete, rather than Escape, so real SocialManager friendship flags must
	# also belong to this owner after the await has restored the outer scope.
	var screen: Node = t.tree.get_first_node_in_group("dialogue_ui")
	await t.page_to_choices(screen)
	PlayerRegistry.for_player(&"p2", func(): screen._buttons[-1].pressed.emit())
	await t.frames(3)
	t.check(label + "_read_social_flags_belong_to_owner", int(PlayerRegistry.state(&"p1").flags.get(&"friend_smith_thorin", 0)) > 0)
	# The real post-await action handler must not complete p0/p2's identical
	# manual objective when a remote owner chooses a synchronous quest reply.
	smith._begin_followup(players[0], {"lines": [{"text_key": "DLG_NEUTRAL"}], "choices": [{"text_key": "REL_TALK_GOODBYE", "action": "quest_update", "quest_id": str(ordinary), "objective_id": "reply"}]})
	await t.page_to_choices(screen)
	PlayerRegistry.for_player(&"p2", func(): screen._buttons[0].pressed.emit())
	await t.frames(3)
	t.check(label + "_post_await_action_and_scope_belong_to_owner", PlayerRegistry.for_player(&"p1", func(): return qm.is_completed(ordinary)) and PlayerRegistry._acting_id == &"")
	for pid in [&"p0", &"p2"]:
		t.check(label + "_unrelated_" + str(pid) + "_unchanged", _owner_state(t, pid) == before[pid])
	var paid := _owner_state(t, &"p1")
	start.call()
	t.check(label + "_retry_no_second_charge_or_reward", _owner_state(t, &"p1").economy == paid.economy and _owner_state(t, &"p1").quests == paid.quests)
	if producer == "consumer":
		smith._end_talk(0, false)
	else:
		await _close(t)
	smith.queue_free()
	for body in players:
		t.world()._unregister_player(body)
	qm.quest_defs.erase(ordinary)
	gm.clear_config_overrides()

static func _counts(eco: Node, needs: Dictionary) -> Dictionary:
	var out := {}
	for item in needs:
		out[item] = eco.count_item(StringName(item))
	return out

static func _close(t) -> void:
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)

static func proof_items_stay_owned(t) -> void:
	await t.start_world()
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	qm.accept_quest(&"forest_patrol")
	qm.accept_quest(&"night_flower")
	eco.add_item(&"moss", 6)
	eco.add_item(&"night_bloom", 1)
	qm.refresh_objectives()
	bus.zone_entered.emit(&"dark_forest")
	var oak := Npc2D.create({"id": "guard_oak", "wander": "0"})
	oak.area = t.world().area
	t.world().area.objects.add_child(oak)
	oak.interact(t.player())
	t.check("intentional_show_and_proof_repeatables_do_not_consume", qm.is_completed(&"forest_patrol") and qm.is_completed(&"night_flower") and eco.count_item(&"moss") == 6 and eco.count_item(&"night_bloom") == 1)
	await _close(t)
	oak.queue_free()