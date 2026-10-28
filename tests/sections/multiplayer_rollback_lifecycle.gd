extends RefCounted
const SECTION := "multiplayer_rollback_lifecycle"
const TIMEOUT_S := 120.0
const Edges := preload("res://tests/sections/multiplayer_rollback_edges.gd")

class NoRollback extends Node:
	var calls := 0
	func to_dict() -> Dictionary: return {"weather": "sunny"}
	func reset() -> void: calls += 1

func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	for kind: String in ["validation_error", "missing_codec", "body_depart", "section_replace", "freed_section", "rollback_error", "nested_failed", "load_completed", "failure_notice", "backup_toast", "enter_finish", "continue_validation"]:
		if OS.get_environment("MP4_LIFE_CASE") != "" and OS.get_environment("MP4_LIFE_CASE") != kind: continue
		if not await t.start_world(): return
		saves.save_dir = "user://mp4-rollback-life-" + kind
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		if kind == "validation_error": _validation_error(t, saves)
		elif kind == "missing_codec": _missing_codec(t, saves)
		elif kind in ["body_depart", "section_replace", "freed_section", "rollback_error"]: _revoked(t, saves, kind)
		elif kind == "nested_failed": _nested_failed(t, saves)
		elif kind == "continue_validation": await _continue_validation(t, saves)
		else: await _final_observer(t, saves, kind)
		await t.go_menu()

func _released(saves: Node) -> bool:
	return not saves.network_admission_blocked() and saves.ApplyGuard.alive == 0 and saves.get("_origin_barriers").is_empty()

func _add(t, saves: Node):
	var section = Edges.Section.new()
	t.tree.root.add_child(section)
	saves.register_section("mp4_life", section, 1000)
	return section

func _remove(saves: Node, section: Node) -> void:
	saves.unregister_section("mp4_life")
	section.free()

func _validation_error(t, saves: Node) -> void:
	var section = _add(t, saves)
	var payload: Dictionary = saves.gather_payload()
	var notifications: Array = []
	var callback := func(_pid, _skin): notifications.append(true)
	EventBus.player_character_changed.connect(callback)
	section.validation_callback = func(): push_error("MP4 controlled snapshot validator error")
	t.allow("MP4 controlled snapshot validator error")
	var result: Dictionary = saves._apply_payload(payload)
	section.validation_callback = Callable()
	EventBus.player_character_changed.disconnect(callback)
	t.expect_allowed("MP4 controlled snapshot validator error", 1, "actual snapshot validator error guarded")
	t.check("validator_error_before_mutation", not result.ok and str(result.detail).contains("snapshot") and notifications.is_empty() and section.calls == 0 and _released(saves), "a last snapshot validator error must abort before even GameManager emits; %s callbacks=%s" % [result, notifications])
	_remove(saves, section)

func _continue_validation(t, saves: Node) -> void:
	var section = _add(t, saves)
	t.check("continue_validation_saved", saves.save_game(0), "genuine latest-slot source")
	await t.go_menu()
	var entered: Array = []
	var winner: Array = []
	section.validation_callback = func():
		if not entered.is_empty(): return
		entered.append("latest_validation")
		entered.append(saves.get("_offline_load_depth"))
		GameManager.start_new_game("ContinueWinner", GameManager.CharacterType.ANIMAL)
		winner.append(GameManager.to_dict().duplicate(true))
		winner.append(PlayerRegistry.peek_state(&"p0"))
		winner.append(saves.run_id)
	saves.get("_inspect_cache").clear()
	var loaded: bool = saves.continue_latest()
	section.validation_callback = Callable()
	t.check("continue_validation_reached", entered == ["latest_validation", 1], "actual latest-slot validator superseded the facade")
	t.check("continue_validation_no_old_entry", not loaded and winner.size() == 3 and GameManager.to_dict() == winner[0] and PlayerRegistry.peek_state(&"p0") == winner[1] and saves.run_id == winner[2] and section.calls == 0 and saves.last_error.is_empty() and _released(saves), "old Continue must not load or enter after validator reset; loaded=%s calls=%s error=%s" % [loaded, section.calls, saves.last_error])
	_remove(saves, section)

func _missing_codec(t, saves: Node) -> void:
	var payload: Dictionary = saves.gather_payload()
	var fake := NoRollback.new()
	var previous: Variant = Svc._overrides.get("TimeManager")
	Svc.override("TimeManager", fake)
	var old := PlayerRegistry.peek_state(&"p0")
	var result: Dictionary = saves._apply_payload(payload)
	if previous != null: Svc.override("TimeManager", previous)
	else: Svc._overrides.erase("TimeManager")
	t.check("mutable_missing_codec_preflight", not result.ok and str(result.detail).contains("lacks rollback codec") and fake.calls == 0 and PlayerRegistry.peek_state(&"p0") == old and _released(saves), "real core mutating section without rollback codec is not an inert stand-in")
	fake.free()

func _revoked(t, saves: Node, kind: String) -> void:
	var section = _add(t, saves)
	var later = Edges.Section.new()
	t.tree.root.add_child(later)
	saves.register_section("mp4_later", later, 1100)
	var payload: Dictionary = saves.gather_payload()
	var old := PlayerRegistry.peek_state(&"p0")
	var entered: Array = []
	var replacement = Edges.Section.new()
	t.tree.root.add_child(replacement)
	var world := PlayerRegistry.world()
	var body := PlayerRegistry.local_player()
	section.rejects = 1
	section.apply_callback = func():
		if not entered.is_empty(): return
		if kind == "rollback_error" and section.calls != 2: return
		entered.append(kind)
		if kind == "body_depart": world._unregister_player(body)
		elif kind == "section_replace": saves.register_section("mp4_life", replacement, 1000)
		elif kind == "freed_section": later.free()
		elif kind == "rollback_error": push_error("MP4 controlled rollback error")
	if kind == "rollback_error": t.allow("MP4 controlled rollback error")
	var result: Dictionary = saves._apply_payload(payload)
	if kind == "rollback_error": t.expect_allowed("MP4 controlled rollback error", 1, "actual restoration error, never a certificate")
	t.check(kind + "_actual_boundary", entered == [kind] and not result.ok, "real named application/restoration callback")
	t.check(kind + "_no_revival_and_release", PlayerRegistry.peek_state(&"p0") != old and (str(result.detail).contains("incomplete") if kind == "rollback_error" else result.get("superseded", false)) and _released(saves), "obsolete origin never republished after owner/codec loss or incomplete rollback")
	if kind == "section_replace": t.check("replacement_codec_untouched", saves.section_node("mp4_life") == replacement and replacement.calls == 0 and replacement.value == 7)
	saves.unregister_section("mp4_later")
	if is_instance_valid(later): later.free()
	saves.unregister_section("mp4_life")
	section.free()
	replacement.free()

func _nested_failed(t, saves: Node) -> void:
	var section = _add(t, saves)
	var payload: Dictionary = saves.gather_payload()
	t.check("nested_failed_saved", saves.save_game(1), "valid nested disk source")
	var old := PlayerRegistry.peek_state(&"p0")
	var entered: Array = []
	section.apply_callback = func():
		if not entered.is_empty(): return
		entered.append("outer_apply")
		section.rejects = 1
		entered.append(saves.load_game(1))
		section.rejects = 1
	var result: Dictionary = saves._apply_payload(payload)
	t.check("nested_failed_both_genuine_restores", entered == ["outer_apply", false] and section.calls == 4 and not result.ok and not str(result.detail).contains("incomplete") and PlayerRegistry.peek_state(&"p0") == old and _released(saves), "failed nested load is not successful supersession; outer certified rollback still restores origin")
	_remove(saves, section)

func _final_observer(t, saves: Node, kind: String) -> void:
	var section = _add(t, saves)
	GameManager.set_flag(GameManager.FLAG_INTRO_PENDING, true)
	var saved: bool = saves.save_game(0)
	if kind == "backup_toast": saved = saved and saves.save_game(0)
	GameManager.play_time_seconds = 222
	t.check(kind + "_eligible", saved and saves.save_game(1), "real earlier and winning saved payloads")
	# Exercise the real title entry facade without retaining a detached World UI
	# as a synthetic listener during the queued scene request.
	if kind == "enter_finish": await t.go_menu()
	var entered: Array = []
	var winner: Array = []
	var replace := func():
		if not entered.is_empty(): return
		entered.append(kind)
		section.rejects = 0
		entered.append(saves.load_game(1))
		if kind == "enter_finish": GameManager.change_phase(GameManager.GamePhase.PAUSED)
		winner.append(GameManager.to_dict().duplicate(true))
		winner.append(PlayerRegistry.peek_state(&"p0"))
		winner.append(saves.run_id)
		winner.append(saves.current_slot)
		winner.append(GameManager.current_phase)
	var loaded_callback := func(slot: int):
		if kind == "load_completed" and slot == 0: replace.call()
	var notice := func(title: String, _message: String, _icon: String):
		if kind == "failure_notice" and title == saves.tr("NOTIF_LOAD_FAILED_TITLE"): replace.call()
		if kind == "backup_toast" and title == saves.tr("NOTIF_LOAD_BACKUP_TITLE"): replace.call()
	var flag := func(id: StringName, value: Variant):
		if kind == "enter_finish" and id == GameManager.FLAG_INTRO_PENDING and value == false: replace.call()
	EventBus.load_completed.connect(loaded_callback)
	EventBus.notification_posted.connect(notice)
	EventBus.flag_changed.connect(flag)
	if kind in ["failure_notice", "backup_toast"]: section.rejects = 1
	var loaded: bool = saves.load_and_enter(0) if kind == "enter_finish" else saves.load_game(0)
	EventBus.flag_changed.disconnect(flag)
	EventBus.notification_posted.disconnect(notice)
	EventBus.load_completed.disconnect(loaded_callback)
	t.check(kind + "_real_boundary", entered == [kind, true], "actual final public observer starts successful nested disk load")
	t.check(kind + "_winner_after_unwind", not loaded and winner.size() == 5 and GameManager.to_dict() == winner[0] and PlayerRegistry.peek_state(&"p0") == winner[1] and saves.run_id == winner[2] and saves.current_slot == winner[3] and GameManager.current_phase == winner[4] and _released(saves), "no older facade finalization over winner; synchronous boundary only for scene request")
	_remove(saves, section)
