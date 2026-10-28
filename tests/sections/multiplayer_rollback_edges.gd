extends RefCounted
const SECTION := "multiplayer_rollback_edges"
const TIMEOUT_S := 120.0

class Section extends Node:
	var value := 7
	var calls := 0
	var rejects := 0
	var bad_snapshot := ""
	var snapshot_callback: Callable
	var validation_callback: Callable
	var apply_callback: Callable
	func reset() -> void: value = 7
	func to_dict() -> Variant:
		if snapshot_callback.is_valid(): snapshot_callback.call()
		if bad_snapshot == "null": return null
		if bad_snapshot == "false": return false
		if bad_snapshot == "invalid": return {"value": false}
		if bad_snapshot == "error": push_error("MP4 controlled snapshot error")
		return {"value": value}
	func validate_dict(d: Dictionary) -> bool:
		if validation_callback.is_valid(): validation_callback.call()
		return d.get("value") is int
	func from_dict(d: Dictionary) -> bool:
		calls += 1
		value = int(d.get("value", 7))
		if apply_callback.is_valid(): apply_callback.call()
		if rejects > 0:
			rejects -= 1
			return false
		return true

func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	for kind: String in ["untouched", "roster", "social", "snapshot_load", "validator_reset", "rollback_load", "partial", "null", "false", "invalid", "error", "direct", "repeat", "owed"]:
		if OS.get_environment("MP4_EDGE_CASE") != "" and OS.get_environment("MP4_EDGE_CASE") != kind: continue
		if not await t.start_world(): return
		saves.save_dir = "user://mp4-rollback-edge-" + kind
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		if kind == "untouched": _untouched(t, saves)
		elif kind == "roster": _roster(t, saves)
		elif kind == "social": _social_decoder(t, saves)
		elif kind in ["snapshot_load", "validator_reset", "rollback_load"]: _nested(t, saves, kind)
		elif kind in ["partial", "null", "false", "invalid", "error"]: _refusal(t, saves, kind)
		elif kind == "direct": _direct(t, saves)
		elif kind == "repeat": _repeat(t, saves)
		elif kind == "owed": _owed(t, saves)
		await t.go_menu()

func _add(t, saves: Node, label := "mp4_edge", order := 1000) -> Section:
	var section := Section.new()
	t.tree.root.add_child(section)
	saves.register_section(label, section, order)
	return section

func _remove(saves: Node, section: Section, label := "mp4_edge") -> void:
	saves.unregister_section(label)
	section.free()

func _released(saves: Node) -> bool:
	return not saves.network_admission_blocked() and saves.ApplyGuard.alive == 0 and saves.get("_origin_barriers").is_empty()

func _untouched(t, saves: Node) -> void:
	var first := _add(t, saves, "mp4_first", -100)
	var last := _add(t, saves)
	var payload: Dictionary = saves.gather_payload()
	var old := PlayerRegistry.peek_state(&"p0")
	first.rejects = 1
	first.apply_callback = func():
		if first.calls == 1: last.value = 99
	var result: Dictionary = saves._apply_payload(payload)
	t.check("untouched_callback_reached", first.calls == 2, "genuine early refusal and rollback callback")
	t.check("untouched_section_restored", not result.ok and not str(result.detail).contains("incomplete") and last.value == 7 and PlayerRegistry.peek_state(&"p0") == old and _released(saves), "restore callback-mutated section beyond touched prefix; %s last=%s" % [result, last.value])
	_remove(saves, first, "mp4_first")
	_remove(saves, last)

func _roster(t, saves: Node) -> void:
	var other := PlayerRegistry.state(&"p1")
	PlayerRegistry.for_player(&"p1", func():
		EconomyManager.from_dict(EconomyManager.to_dict())
		QuestManager.from_dict(QuestManager.to_dict()))
	QuestManager.quest_flags["mp4_decoder"] = false
	EconomyManager.gold = 111
	other.gold = 123
	var saved: bool = saves.save_game(0)
	QuestManager.quest_flags["mp4_decoder"] = true
	EconomyManager.gold = 222
	other.gold = 456
	t.check("roster_eligible", saved and saves.save_game(1), "two genuine profiles and distinct quest/economy winner")
	var entered: Array = []
	var winner: Array = []
	var callback := func(pid: StringName, _inventory: Dictionary):
		if pid != &"p0" or not entered.is_empty(): return
		entered.append("entered")
		entered.append(saves.load_game(1))
		winner.append(PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true))
		winner.append(PlayerRegistry.peek_state(&"p1").to_dict().duplicate(true))
	EventBus.player_inventory_changed.connect(callback)
	var loaded: bool = saves.load_game(0)
	EventBus.player_inventory_changed.disconnect(callback)
	t.check("roster_nested_boundary", entered == ["entered", true], "nested successful load inside p0 EconomyManager.from_dict notification")
	t.check("roster_no_stale_quest_or_p1_decode", not loaded and winner.size() == 2 and PlayerRegistry.peek_state(&"p0").to_dict() == winner[0] and PlayerRegistry.peek_state(&"p1").to_dict() == winner[1] and _released(saves), "old roster decoder cannot continue old p0 QuestManager or remaining p1 after replacement")

func _social_decoder(t, saves: Node) -> void:
	GameManager.set_flag(&"birthday_today", "mp4_not_today")
	t.check("social_decoder_saved", saves.save_game(0), "valid payload with derived flag requiring actual restoration")
	GameManager.clear_flag(&"birthday_today")
	var armed: Array = []
	var entered: Array = []
	var winner: Array = []
	var inventory := func(_pid, _items): armed.append(true)
	var callback := func(flag: StringName, _value: Variant):
		if flag != &"birthday_today" or armed.is_empty() or not entered.is_empty(): return
		entered.append("social_restore")
		GameManager.start_new_game("SocialWinner", GameManager.CharacterType.ANIMAL)
		GameManager.set_flag(&"festival_now", "mp4_winner_marker")
		winner.append(GameManager.to_dict().duplicate(true))
		winner.append(SocialManager.to_dict().duplicate(true))
	EventBus.player_inventory_changed.connect(inventory)
	EventBus.flag_changed.connect(callback)
	var loaded: bool = saves.load_game(0)
	EventBus.flag_changed.disconnect(callback)
	EventBus.player_inventory_changed.disconnect(inventory)
	t.check("social_decoder_actual_boundary", entered == ["social_restore"], "birthday callback occurs after players, inside real Social._restore_state")
	t.check("social_decoder_no_trailing_flags", not loaded and winner.size() == 2 and GameManager.to_dict() == winner[0] and SocialManager.to_dict() == winner[1] and _released(saves), "older derived-festival write must not clear newer reset marker")

func _nested(t, saves: Node, kind: String) -> void:
	var section := _add(t, saves)
	GameManager.play_time_seconds = 111
	var saved: bool = saves.save_game(0)
	GameManager.play_time_seconds = 222
	t.check(kind + "_eligible", saved and saves.save_game(1), "real primary/winner disk files")
	var entered: Array = []
	var winner: Array = []
	var callback := func():
		if not entered.is_empty(): return
		if kind == "rollback_load" and section.calls != 2: return
		entered.append(kind)
		if kind == "validator_reset":
			GameManager.start_new_game("ValidatorWinner", GameManager.CharacterType.ANIMAL)
			entered.append(GameManager.player_name == "ValidatorWinner")
		else: entered.append(saves.load_game(1))
		winner.append(GameManager.to_dict().duplicate(true))
		winner.append(PlayerRegistry.peek_state(&"p0"))
		winner.append(saves.pending_world.duplicate(true))
		winner.append(saves.run_id)
	if kind == "snapshot_load": section.snapshot_callback = callback
	elif kind == "validator_reset": section.validation_callback = callback
	else:
		section.rejects = 1
		section.apply_callback = callback
	var loaded: bool = saves.load_game(0)
	section.snapshot_callback = Callable()
	section.validation_callback = Callable()
	section.apply_callback = Callable()
	t.check(kind + "_reached", entered == [kind, true], "actual named snapshot/validator/rollback nested boundary")
	t.check(kind + "_winner_and_release", not loaded and winner.size() == 4 and GameManager.to_dict() == winner[0] and PlayerRegistry.peek_state(&"p0") == winner[1] and saves.pending_world == winner[2] and saves.run_id == winner[3] and _released(saves), "no older apply/rollback/facade overwrite; current next save follows")
	t.check(kind + "_next_operation", saves.save_game(2), "actual current-owner next operation")
	_remove(saves, section)

func _refusal(t, saves: Node, kind: String) -> void:
	var section := _add(t, saves)
	var payload: Dictionary = saves.gather_payload()
	var old := PlayerRegistry.peek_state(&"p0")
	var before: Dictionary = old.to_dict().duplicate(true)
	if kind == "partial": section.rejects = 2
	else: section.bad_snapshot = kind
	if kind == "error": t.allow("MP4 controlled snapshot error")
	var result: Dictionary = saves._apply_payload(payload)
	if kind == "error": t.expect_allowed("MP4 controlled snapshot error", 1, "real guarded snapshot error, not silently empty")
	t.check(kind + "_honest_refusal", not result.ok and (str(result.detail).contains("incomplete") if kind == "partial" else str(result.detail).contains("snapshot")), "actual refusal before mutation or explicit incomplete rollback; %s" % result)
	t.check(kind + "_no_unauthenticated_revival", (PlayerRegistry.peek_state(&"p0") != old if kind == "partial" else PlayerRegistry.peek_state(&"p0") == old and section.calls == 0) and old.to_dict() == before and _released(saves), "no minted restoration after failed rollback, and no mutation on invalid snapshot")
	section.rejects = 0
	section.bad_snapshot = ""
	t.check(kind + "_future_progress", saves._apply_payload(payload).ok and _released(saves), "independent legitimate direct apply succeeds")
	_remove(saves, section)

func _direct(t, saves: Node) -> void:
	var old := PlayerRegistry.peek_state(&"p0")
	var payload: Dictionary = saves.gather_payload()
	var rid: String = saves.run_id
	var result: Dictionary = saves._apply_payload(payload)
	t.check("same_value_direct_success_revokes", result.ok and saves.run_id == rid and PlayerRegistry.peek_state(&"p0") != old and _released(saves), "genuine identical-valued direct apply is still a new physical incarnation")

func _repeat(t, saves: Node) -> void:
	var section := _add(t, saves)
	var payload: Dictionary = saves.gather_payload()
	var old := PlayerRegistry.peek_state(&"p0")
	var flags: Dictionary = old.flags
	var inventory: Array = old.inventory
	var all_ok := true
	for i in 3:
		section.rejects = 1
		var result: Dictionary = saves._apply_payload(payload)
		all_ok = all_ok and not result.ok and not str(result.detail).contains("incomplete") and PlayerRegistry.peek_state(&"p0") == old and is_same(flags, old.flags) and is_same(inventory, old.inventory) and _released(saves)
	t.check("repeat_original_graph_retained", all_ok and section.calls == 6, "three complete actual rollbacks, same original row and nested collection references")
	_remove(saves, section)

func _owed(t, saves: Node) -> void:
	var section := _add(t, saves)
	var quests: Node = t.autoload("QuestManager")
	var old := PlayerRegistry.peek_state(&"p0")
	quests.pending_rewards[&"mp4_owed"] = {"wood": 2, "stone": 3}
	var owed: Dictionary = quests.pending_rewards[&"mp4_owed"]
	var wood: int = EconomyManager.count_item(&"wood")
	var stone: int = EconomyManager.count_item(&"stone")
	t.check("owed_eligible", EconomyManager.can_add_item(&"wood", 2) and EconomyManager.can_add_item(&"stone", 3) and saves.save_game(0), "real two-item pending reward, genuine disk save")
	var entered: Array = []
	var callback := func(pid: StringName, _inventory: Dictionary):
		if pid != &"p0" or not entered.is_empty(): return
		entered.append("first_committed")
		section.rejects = 1
		entered.append(saves.load_game(0))
	EventBus.player_inventory_changed.connect(callback)
	var claimed: bool = quests.claim_rewards()
	EventBus.player_inventory_changed.disconnect(callback)
	t.check("owed_real_failed_load_inside_claim", entered == ["first_committed", false] and section.calls == 2 and PlayerRegistry.peek_state(&"p0") == old, "actual _claim_pass suspends inside first delivery and genuine full rollback")
	t.check("owed_graph_and_remaining_delivery", claimed and owed.is_empty() and quests.pending_rewards.is_empty() and EconomyManager.count_item(&"wood") == wood + 2 and EconomyManager.count_item(&"stone") == stone + 3, "local owed Dictionary still live; no lost later grant, detached remainder or duplicate")
	quests.claim_rewards()
	t.check("owed_exactly_once_and_release", EconomyManager.count_item(&"wood") == wood + 2 and EconomyManager.count_item(&"stone") == stone + 3 and _released(saves), "independent next claim is idempotent")
	_remove(saves, section)
