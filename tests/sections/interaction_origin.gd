extends RefCounted
const SECTION := "interaction_origin"
const TIMEOUT_S := 120.0
const Callback := preload("res://tests/sections/multiplayer_callback_ownership.gd")

func _open() -> bool:
	for id: StringName in [&"sword_upgrade", &"dark_forest_mining"]:
		if not QuestManager.is_active(id) or QuestManager.is_completed(id): return false
		var rt: Dictionary = QuestManager.get_quest_progress(id)
		var turn := "deliver_to_smith" if id == &"sword_upgrade" else "return_to_smith"
		if rt.objectives[turn].current != 0: return false
		for oid in rt.objectives:
			if oid != turn and not rt.objectives[oid].done: return false
	return true

func run(t) -> void:
	if not await t.start_world(): return
	var saves: Node = t.autoload("SaveManager")
	GameManager.set_clock(10, 0)
	TimeManager.set_weather(&"klart")
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	await t.world().travel(&"int_smedjen", &"default")
	NpcDirector.resync("smith_thorin")
	await t.until(func(): return NpcDirector.node_of("smith_thorin") != null, 10)
	var smith: Node = NpcDirector.node_of("smith_thorin")
	if not t.expect(smith is Npc2D, "installed shipped Smith at authored opening hour"): return
	QuestManager.accept_quest(&"sword_upgrade")
	QuestManager.accept_quest(&"dark_forest_mining")
	for pair in [[&"iron_ingot", 3], [&"fairy_dust", 1], [&"iron_ore", 6], [&"amethyst", 2]]:
		EconomyManager.add_item(pair[0], pair[1])
	QuestManager.refresh_objectives()
	EventBus.zone_entered.emit(&"dark_forest")
	var payload: Dictionary = saves.gather_payload()
	# A genuine healthy direct apply, not an invented decoder/fixture replacement.
	t.check("smith_eligible", _open() and saves.validate_payload(payload).ok and PlayerRegistry.registered_id(t.player()) == &"p0")
	var origin := PlayerRegistry.peek_state(&"p0")
	var first: Variant = QuestManager.active_quests[&"sword_upgrade"]
	var entered: Array = []
	var winner: Dictionary = {}
	var observer := func(_pid, qid, oid, _n, _target):
		if qid != &"sword_upgrade" or oid != &"deliver_to_smith" or not entered.is_empty(): return
		entered.append(bool(saves._apply_payload(payload).get("ok", false)))
		entered.append(PlayerRegistry.peek_state(&"p0") != origin and _open())
		winner.merge(Callback.new()._snapshot(saves))
	EventBus.quest_objective_updated.connect(observer)
	smith.interact(t.player())
	EventBus.quest_objective_updated.disconnect(observer)
	t.check("smith_actual_apply_immediate", entered == [true, true], "healthy distinguishable winner immediately installed; %s" % [entered])
	t.check("smith_whole_event_pair", not winner.is_empty() and Callback.new()._snapshot(saves) == winner and _open(), "obsolete physical second event must not deduct winner ore/amethyst or reward")
	t.check("smith_committed_origin", first.objectives["deliver_to_smith"].done and origin != PlayerRegistry.peek_state(&"p0"), "first committed objective remains on original runtime")
	await t.frames(3)
	var after := Callback.new()._snapshot(saves)
	var delta: Dictionary = {}
	for key in winner:
		if winner[key] != after[key]: delta[key] = [winner[key], after[key]]
	t.check("smith_deferred_unwind", after == winner and _open(), "no stale deferred progression; delta=%s" % [delta])
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	if ui != null: ui.close()
	await t.go_menu()
