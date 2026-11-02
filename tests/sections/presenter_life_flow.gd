extends RefCounted
const SECTION := "presenter_life_flow"
const TIMEOUT_S := 90.0
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var quests: Node = t.autoload("QuestManager")
	var bus: Node = t.autoload("EventBus")
	saves.autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	var owner := Node.new()
	t.world().add_child(owner)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	var offers: Array = PlayerRegistry.for_player(&"p1", func(): return LifeFlow.offers("board"))
	t.check("actual_p1_offer_available", not offers.is_empty())
	if offers.is_empty(): return
	var row: Dictionary = offers[0]
	var qid := StringName(str(row.quest_id))
	var started: Array = []
	var ended: Array = []
	var start := func(_npc, _module): started.append(PlayerRegistry._acting_id)
	var end := func(): ended.append(PlayerRegistry._acting_id)
	bus.dialogue_started.connect(start)
	bus.dialogue_ended.connect(end)
	# Legacy entry remains usable; local physical body is p0, never the ambient p1.
	PlayerRegistry.for_player(&"p1", func(): LifeFlow.offer(owner, row))
	await t.page_to_choices(ui)
	ui._pick({"action": "quest_accept", "quest_id": str(qid)})
	await t.frames(2)
	t.check("local_body_not_ambient_receives_offer", PlayerRegistry.for_player(&"p0", func(): return quests.is_active(qid)) and not PlayerRegistry.for_player(&"p1", func(): return quests.is_active(qid)))
	t.check("public_notifications_once_original_owner", started == [&"p0"] and ended == [&"p0"], str([started, ended]))
	t.check("scope_restored_and_no_shared_page", PlayerRegistry._acting_id == &"" and not ui.is_open())
	bus.dialogue_started.disconnect(start)
	bus.dialogue_ended.disconnect(end)
	var board := NoticeBoard2D.new()
	t.world().add_child(board)
	var board_rows: Array = PlayerRegistry.for_player(&"p1", func(): return board.rows())
	# p0 already accepted qid in the first independent control. Select another
	# otherwise-offerable row so the unrelated-profile negative starts absent.
	board_rows = board_rows.filter(func(r): return str(r.quest_id) != str(qid))
	var board_id := StringName(str(board_rows[0].quest_id))
	PlayerRegistry.for_player(&"p0", func(): board.interact(body))
	await t.page_to_choices(ui)
	ui._pick({"action": "offer", "quest_id": str(board_id), "giver": str(board_rows[0].giver)})
	await t.frames(3)
	await t.page_to_choices(ui)
	ui._pick({"action": "quest_accept", "quest_id": str(board_id)})
	await t.frames(2)
	t.check("actual_board_explicit_p1_not_conflicting_p0", PlayerRegistry.for_player(&"p1", func(): return quests.is_active(board_id)) and not PlayerRegistry.for_player(&"p0", func(): return quests.is_active(board_id)))
	board.free()
	owner.free()
	t.world()._unregister_player(body)
	gm.clear_config_overrides()
