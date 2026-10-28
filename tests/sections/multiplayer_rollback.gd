extends RefCounted
## Real failed-apply continuation tracers; no authored reward changes.
const SECTION := "multiplayer_rollback"
const TIMEOUT_S := 120.0

class LateSection extends Node:
	var rejects := 0
	var value := 7
	var calls := 0
	var callback: Callable
	var validation_callback: Callable
	var reject_values: Array = []
	func reset() -> void: value = 7
	func to_dict() -> Dictionary: return {"value": value}
	func validate_dict(d: Dictionary) -> bool:
		if validation_callback.is_valid(): validation_callback.call()
		return d.get("value") is int
	func from_dict(d: Dictionary) -> bool:
		calls += 1
		value = int(d.get("value", 7))
		if callback.is_valid(): callback.call()
		if value in reject_values: return false
		if rejects > 0:
			rejects -= 1
			return false
		return true

func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	if not await t.start_world(): return
	saves.save_dir = "user://mp4-rollback-social"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	_social(t, saves)
	await t.go_menu()
	if OS.get_environment("MP4_ROLLBACK_CASE") == "social": return
	for mode: String in ["load", "reset"]:
		if not await t.start_world(): return
		saves.save_dir = "user://mp4-rollback-nested-" + mode
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		_nested_game(t, saves, mode)
		await t.go_menu()
	for mode: String in ["success", "both_fail"]:
		if not await t.start_world(): return
		saves.save_dir = "user://mp4-rollback-backup-" + mode
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		_backup(t, saves, mode)
		await t.go_menu()

func _complete() -> void:
	for objective: Dictionary in QuestManager.get_quest_def(&"lost_cat").get("objectives", []):
		QuestManager.update_objective(&"lost_cat", StringName(str(objective.id)), int(objective.target))

func _social(t, saves: Node) -> void:
	var reject := LateSection.new()
	t.tree.root.add_child(reject)
	saves.register_section("mp4_rollback_late", reject, 1000)
	QuestManager.active_quests.clear()
	QuestManager.accept_quest(&"lost_cat")
	var old := PlayerRegistry.peek_state(&"p0")
	var other := PlayerRegistry.state(&"p1")
	PlayerRegistry.for_player(&"p1", func():
		EconomyManager.from_dict(EconomyManager.to_dict())
		QuestManager.from_dict(QuestManager.to_dict()))
	var unrelated := other.to_dict().duplicate(true)
	var gold := EconomyManager.gold
	var npc := &"pippin_boegeknop"
	t.check("social_gift_eligible", QuestManager.is_active(&"lost_cat") and SocialManager.hearts(npc) == 0 and SocialManager.befriend_reason(npc) == "" and EconomyManager.can_add_item(&"painting_porthole", 1) and saves.save_game(0), "real authored two-heart painting recipient, valid disk save")
	var observed: Array = []
	var original_social: Array = []
	var callback := func(pid: StringName, friend: StringName, hearts: int):
		if friend != npc or not observed.is_empty(): return
		observed.append([pid, hearts])
		original_social.append(SocialManager._row_for(pid, str(npc), false))
		reject.rejects = 1
		observed.append(saves.load_game(0))
		observed.append(saves.last_error.get("code"))
		observed.append(reject.calls)
	EventBus.friend_changed.connect(callback)
	_complete()
	EventBus.friend_changed.disconnect(callback)
	t.check("social_genuine_failed_apply", observed == [[&"p0", 2], false, "apply", 2] and PlayerRegistry.peek_state(&"p0") == old and QuestManager.is_completed(&"lost_cat"), "actual late refusal + complete restoration, not missing-file control; %s %s" % [observed, saves.last_error])
	t.check("social_original_npc_identity", original_social.size() == 1 and is_same(original_social[0], SocialManager._row_for(&"p0", str(npc), false)), "restore actual NPC Dictionary captured inside grant")
	t.check("social_earned_gift_and_terminal", EconomyManager.gold == gold + 150 and SocialManager.hearts(npc) == 2 and EconomyManager.count_item(&"painting_porthole") == 1 and LootService.claimed.has("pippin_boegeknop:2") and QuestManager.pending_rewards.is_empty() and GameManager.get_flag(&"lost_cat_active") == false and GameManager.get_flag(&"cat_location_hidden") == false, "preserve committed quest plus essential in-callee gift and Lua continuation")
	QuestManager.complete_quest(&"lost_cat")
	LootService.check_friend_gifts(npc)
	t.check("social_once_unrelated_and_released", EconomyManager.gold == gold + 150 and EconomyManager.count_item(&"painting_porthole") == 1 and other.to_dict() == unrelated and PlayerRegistry.peek_state(&"p1") == other and not saves.network_admission_blocked() and saves.ApplyGuard.alive == 0, "no duplicate/other-row mutation or leaked guard/admission")
	t.check("social_next_current_operation", SocialManager.add_points(npc, 1).ok and SocialManager.points(npc) == SocialManager.points_per_heart() * 2 + 1 and saves.save_game(1), "independent next current-owner progress and actual save")
	saves.unregister_section("mp4_rollback_late")
	reject.free()

func _nested_game(t, saves: Node, mode: String) -> void:
	var key := &"mp4_nested_apply_trigger"
	GameManager.set_flag(key, false)
	GameManager.play_time_seconds = 111.0
	GameManager.unlocked_zones.assign([&"forest"])
	t.check("nested_" + mode + "_outer_saved", saves.save_game(0), "real earlier disk source")
	GameManager.set_flag(key, true)
	GameManager.play_time_seconds = 222.0
	GameManager.unlocked_zones.assign([&"town"])
	t.check("nested_" + mode + "_winner_saved", saves.save_game(1), "real distinct winner disk source")
	var observed: Array = []
	var winner: Array = []
	var callback := func(flag: StringName, value: Variant):
		if flag != key or value != false or not observed.is_empty(): return
		observed.append("entered")
		if mode == "load": observed.append(saves.load_game(1))
		else:
			GameManager.start_new_game("NestedWinner", GameManager.CharacterType.ANIMAL, "WinnerFarm", &"animal_fox")
			observed.append(GameManager.player_name == "NestedWinner")
		winner.append(GameManager.to_dict().duplicate(true))
		winner.append(PlayerRegistry.peek_state(&"p0"))
		winner.append(saves.pending_world.duplicate(true))
		winner.append(saves.run_id)
	EventBus.flag_changed.connect(callback)
	var outer: bool = saves.load_game(0)
	EventBus.flag_changed.disconnect(callback)
	t.check("nested_" + mode + "_real_boundary", observed == ["entered", true], "nested successful lifecycle reached from first GameManager decoder flag")
	t.check("nested_" + mode + "_winner_survives", not outer and winner.size() == 4 and GameManager.to_dict() == winner[0] and PlayerRegistry.peek_state(&"p0") == winner[1] and saves.pending_world == winner[2] and saves.run_id == winner[3], "older decoder trailing zones/playtime/character, rollback and facade must not overwrite winner")
	t.check("nested_" + mode + "_future_released", not saves.network_admission_blocked() and saves.ApplyGuard.alive == 0 and saves.save_game(2), "real next save after nested unwind")

func _files(saves: Node) -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at(saves.save_dir):
		out[file] = FileAccess.get_sha256(saves.save_dir.path_join(file))
	return out

func _backup(t, saves: Node, mode: String) -> void:
	var late := LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("mp4_rollback_late", late, 1000)
	QuestManager.active_quests.clear()
	QuestManager.accept_quest(&"lost_cat")
	late.value = 8
	var saved_backup: bool = saves.save_game(0)
	late.value = 9
	t.check("backup_" + mode + "_eligible", saved_backup and saves.save_game(0) and FileAccess.file_exists(saves.backup_path(0)), "genuine valid primary and rotated backup, distinct late values")
	late.value = 7
	var old := PlayerRegistry.peek_state(&"p0")
	var files := _files(saves)
	var observed: Array = []
	var validations: Array = []
	var callback := func(flag: StringName, value: Variant):
		if flag != &"lost_cat_active" or value != false or not observed.is_empty(): return
		observed.append("entered")
		late.reject_values = [9] if mode == "success" else [9, 8]
		observed.append(saves.load_game(0))
		observed.append(late.calls)
	late.validation_callback = func():
		if late.calls != 2 or not validations.is_empty(): return
		validations.append("backup")
		var before: Variant = GameManager.get_flag(&"cat_location_hidden")
		LuaRuntime.call_quest_event("lost_cat", "quest_completed")
		validations.append(before == true and GameManager.get_flag(&"cat_location_hidden") == before)
	EventBus.flag_changed.connect(callback)
	_complete()
	EventBus.flag_changed.disconnect(callback)
	late.validation_callback = Callable()
	t.check("backup_" + mode + "_actual_attempts", observed == ["entered", mode == "success", 3 if mode == "success" else 4], "primary late refusal/restore followed by real backup attempt; %s %s" % [observed, saves.last_error])
	t.check("backup_" + mode + "_no_midoperation_borrow", validations == ["backup", true], "restored original cannot run old authored effects while backup validator is executing")
	if mode == "success":
		t.check("backup_success_revokes_origin", PlayerRegistry.peek_state(&"p0") != old and QuestManager.is_active(&"lost_cat") and GameManager.get_flag(&"lost_cat_active") == true and GameManager.get_flag(&"cat_location_hidden") == true and late.value == 8, "backup success is a fresh incarnation even with identical run_id")
	else:
		t.check("backup_both_fail_preserve_earned", PlayerRegistry.peek_state(&"p0") == old and QuestManager.is_completed(&"lost_cat") and GameManager.get_flag(&"lost_cat_active") == false and GameManager.get_flag(&"cat_location_hidden") == false and late.value == 7, "composed genuine rollbacks retain original ownership and both essential effects")
	t.check("backup_" + mode + "_inventory_release", _files(saves) == files and not saves.network_admission_blocked() and saves.ApplyGuard.alive == 0, "all save files byte-identical; no pending guard")
	late.reject_values = []
	t.check("backup_" + mode + "_future_load", saves.load_game(0) and PlayerRegistry.peek_state(&"p0") != old, "next legitimate actual load succeeds")
	saves.unregister_section("mp4_rollback_late")
	late.free()
