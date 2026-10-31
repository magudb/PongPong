extends RefCounted
const SECTION := "boss_terminal_origins"
const TIMEOUT_S := 180.0
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func run(t) -> void:
	var selected := OS.get_environment("H1_CASE")
	for seam in ([selected] if selected != "" else ["event", "flag", "atomic", "enemy", "hearts", "health", "stats"]):
		for mode in ["normal", "direct"]: await _terminal(t, seam, mode)
	if selected != "": return
	for mode in ["failed", "incomplete", "same"]: await _rollback(t, mode)
	for departed in [false, true]: await _recipient(t, departed)

func _start(t) -> DungeonBoss2D:
	if not await t.start_world(): return null
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var floors := DungeonFloors.inst()
	floors.enter(4)
	await t.until(func(): return t.world().area.map.id == &"moerkeskoven_f4" and not t.world().traveling, 15.0)
	await t.frames(4)
	var found: Array = t.world().area.find_markers("enemy").filter(func(marker): return marker.node is DungeonBoss2D)
	t.check("actual_floor4_authored_boss", floors.active and floors.floor == 4 and found.size() == 1)
	if found.size() != 1: return null
	DungeonEnemyRoster.of(t.world().area).set_process(false)
	for enemy in t.tree.get_nodes_in_group("enemy"): enemy.set_physics_process(false)
	var boss: DungeonBoss2D = found[0].node
	boss.set_awake(true)
	# Freeze physical simulation, not public/model observers, for exact queued state.
	t.player().set_physics_process(false)
	GameManager.set_flag(&"forest_mother_version", 1)
	return boss

func _terminal(t, seam: String, mode: String) -> void:
	var boss := await _start(t)
	if boss == null: return
	var saves: Node = t.autoload("SaveManager")
	var qm: Node = t.autoload("QuestManager")
	var floors := DungeonFloors.inst()
	var director: Node = t.world().get_node("MotherStory")
	var origin := EventBus.interaction_origin(&"p0")
	var observed: Array = []
	var notices: Array = []
	var accepted: Array = []
	var tag := seam + "_" + mode
	var stale_stats: Array = []
	var replace := func():
		if mode == "normal" or not observed.is_empty(): return
		observed.append(true) # arm before evaluating the nested real apply
		var incoming: Dictionary = saves.gather_payload()
		observed.append(saves.validate_payload(incoming).ok)
		observed.append(saves._apply_payload(incoming).ok)
		observed.append(saves.gather_payload())
		observed.append(qm.is_active(MotherStory.quest_id("s03")))
		observed.append(t.player()._last_stats.duplicate(true))
	var early := func(name, _payload):
		if (name == &"dungeon_boss_defeated" and seam == "event") or (name == &"skovhjerte_grown" and seam == "hearts"): replace.call()
	var flag := func(key, _value):
		if key == (&"dg_boss_clear" if seam == "flag" else &"dungeon_boss_snurresvamp") and seam in ["flag", "atomic"]: replace.call()
	var enemy := func(_uid, _kind, _loot):
		if seam == "enemy": replace.call()
	var later := func(name, payload):
		if name == &"dungeon_boss_defeated": notices.append(payload.duplicate(true))
	var accept := func(pid, id):
		if id == MotherStory.quest_id("s03"): accepted.append(pid)
	var health := func(_pid, _hearts, maximum):
		if seam == "health" and maximum == 12: replace.call()
	var stats := func():
		if seam == "stats" and t.player().max_half_hearts == 12: replace.call()
	var bus_stats := func(pid, _values):
		if observed.size() >= 6: stale_stats.append(pid)
	EventBus.player_stats_changed.connect(bus_stats)
	EventBus.player_health_changed.connect(health)
	t.player().stats_changed.connect(stats)
	EventBus.flag_changed.connect(flag)
	EventBus.enemy_defeated.connect(enemy)
	EventBus.game_event.disconnect(director._event)
	EventBus.game_event.connect(early)
	EventBus.game_event.connect(director._event)
	EventBus.game_event.connect(later)
	EventBus.quest_accepted.connect(accept)
	t.check(tag + "_enabled_unprojected_outside_sync", MotherStory.enabled() and not qm.is_active(MotherStory.quest_id("s03")) and EventBus.interaction_current(origin))
	var cell := boss.cell
	boss.take_hit(9999, t.player().global_position, t.player())
	EventBus.player_stats_changed.disconnect(bus_stats)
	EventBus.player_health_changed.disconnect(health)
	t.player().stats_changed.disconnect(stats)
	EventBus.flag_changed.disconnect(flag)
	EventBus.enemy_defeated.disconnect(enemy)
	EventBus.game_event.disconnect(early)
	EventBus.game_event.disconnect(later)
	t.check(tag + "_public_once_original_payload", (notices.is_empty() if mode == "direct" and seam != "event" else notices.size() == 1 and notices[0] == {"boss":"snurresvamp", "kind":"snurresvamp", "floor":4, "level":4, "first_kill":true}))
	if mode == "direct":
		t.check(tag + "_healthy_real_apply_immediate_unprojected", observed.size() == 6 and observed[1] == true and observed[2] == true and observed[4] == false and not EventBus.interaction_current(origin))
		t.check(tag + "_inside_body_cache_stats_suffix_stopped", t.player()._last_stats == observed[5] and stale_stats.is_empty())
		var after: Dictionary = saves.gather_payload()
		t.check(tag + "_winner_exact_whole_unwind", Compare.new()._same_payload(observed[3], after), str(Compare.new()._changed(observed[3], after)))
		t.check(tag + "_old_director_cannot_project_winner", not qm.is_active(MotherStory.quest_id("s03")) and accepted.is_empty())
		await t.frames(3)
		var queued: Dictionary = saves.gather_payload()
		t.check(tag + "_winner_exact_three_frames", Compare.new()._same_payload(observed[3], queued), str(Compare.new()._changed(observed[3], queued)))
		MotherStory.sync()
	else:
		t.check(tag + "_earned_real_terminal_once", floors.is_done_cell(t.world().area, cell) and GameManager.flag_int(&"dungeon_boss_snurresvamp") > 0 and DungeonRun.hearts_bonus() == 2)
	t.check(tag + "_genuine_current_mother_root", qm.is_active(MotherStory.quest_id("s03")) and accepted == [&"p0"])
	MotherStory.sync()
	t.check(tag + "_current_root_idempotent", accepted == [&"p0"])
	EventBus.quest_accepted.disconnect(accept)
	await t.go_menu()

func _files(saves: Node) -> Dictionary:
	var out := {}
	for name in DirAccess.get_files_at(saves.save_dir): out[name] = FileAccess.get_sha256(saves.save_dir.path_join(name))
	return out

func _rollback(t, mode: String) -> void:
	var boss := await _start(t)
	if boss == null: return
	var saves: Node = t.autoload("SaveManager")
	var keep: String = saves.save_dir
	saves.save_dir = "user://boss-terminal-" + mode
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("boss_terminal_late", late, 1000)
	t.check(mode + "_real_primary_no_backup", saves.save_game(0) and not FileAccess.file_exists(saves.backup_path(0)))
	var files := _files(saves)
	var origin := EventBus.interaction_origin(&"p0")
	var profile := PlayerRegistry.peek_state(&"p0")
	var stamp: Array = saves._save_owner_stamp()
	var generation: int = DungeonFloors.inst()._generation
	var seen: Array = []
	var barriers: Array = []
	var finals: Array = []
	late.callback = func(): barriers.append(not EventBus.interaction_current(origin))
	var failure := func(title, _message, kind):
		if kind == "save" and title == TranslationServer.translate("NOTIF_LOAD_FAILED_TITLE"):
			finals.append(PlayerRegistry.peek_state(&"p0") == profile and saves._save_owner_stamp() == stamp and not EventBus.interaction_current(origin) and not saves.continuation_available(profile) and _files(saves) == files)
	var flag := func(key, value):
		if key != &"dg_boss_clear" or value != true or not seen.is_empty(): return
		seen.append(true)
		late.rejects = 1 if mode == "failed" else (2 if mode == "incomplete" else 0)
		seen.append(saves._apply_payload(saves.gather_payload()).ok if mode == "same" else saves.load_game(0))
	EventBus.flag_changed.connect(flag)
	EventBus.notification_posted.connect(failure)
	boss.take_hit(9999, t.player().global_position, t.player())
	EventBus.flag_changed.disconnect(flag)
	EventBus.notification_posted.disconnect(failure)
	t.check(mode + "_real_nested_outcome_files_exact", seen == [true, mode == "same"] and _files(saves) == files and DungeonFloors.inst()._generation > generation)
	if mode == "failed":
		t.check("failed_final_barriers_then_same_origin_resumes", barriers == [true, true] and finals == [true] and EventBus.interaction_current(origin))
		t.check("failed_exact_earned_terminal_batch_once", GameManager.get_flag(&"dg_boss_clear") == true and DungeonRun.hearts_bonus() == 2 and GameManager.flag_int(&"dungeon_boss_snurresvamp") > 0 and DungeonFloors.inst().is_done_cell(t.world().area, boss.cell) and t.world().get_node("RunWatch").kills == 1 and QuestManager.is_active(MotherStory.quest_id("s03")))
	else:
		t.check(mode + "_cannot_adopt_equal_descriptors", not EventBus.interaction_current(origin) and DungeonRun.hearts_bonus() == 0 and GameManager.flag_int(&"dungeon_boss_snurresvamp") == 0 and not QuestManager.is_active(MotherStory.quest_id("s03")))
		if mode == "incomplete":
			late.rejects = 0
			late.callback = Callable()
			t.check("incomplete_fresh_valid_recovery", saves._apply_payload(saves.gather_payload()).ok)
	var next := DungeonRun.boss_killed("snurresvamp_gloed", 8)
	t.check(mode + "_next_genuine_boss_root", next.first and next.hearts_bonus == (4 if mode == "failed" else 2))
	await t.frames(3)
	t.check(mode + "_files_unchanged_after_queued", _files(saves) == files and not saves.network_admission_blocked())
	saves.unregister_section("boss_terminal_late")
	late.free()
	saves.save_dir = keep
	await t.go_menu()

func _recipient(t, departed: bool) -> void:
	var boss := await _start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	body.enter_area(t.world().area, t.player().global_position)
	body.set_physics_process(false)
	var q := &"zz_boss_terminal_owner"
	QuestManager.register_quest_from_lua({"id":str(q), "objectives":[{"id":"kill", "on":"enemy_defeated", "kind":"snurresvamp", "target":1}, {"id":"heart", "on":"game_event", "event":"skovhjerte_grown", "target":1}, {"id":"boss", "on":"game_event", "event":"dungeon_boss_defeated", "target":1}, {"id":"report", "on":"manual", "target":1}]})
	QuestManager.accept_quest(q)
	PlayerRegistry.for_player(&"p1", func(): QuestManager.accept_quest(q))
	GameManager.set_flag(&"forest_mother_version", 1)
	var p0 := PlayerRegistry.peek_state(&"p0")
	var before := p0.to_dict().duplicate(true)
	var observed: Array = []
	var updates: Array = []
	var on_enemy := func(uid, kind, drops):
		observed.append([uid, kind, drops.duplicate(true), PlayerRegistry.for_player(&"p1", func(): return QuestManager.get_objective_progress(q, &"kill").get("current", 0)), t.world().get_node("RunWatch").kills])
		if departed: t.world()._unregister_player(body)
	var on_progress := func(pid, id, oid, _value, _target):
		if id == q: updates.append([pid, oid])
	EventBus.enemy_defeated.connect(on_enemy)
	EventBus.quest_objective_updated.connect(on_progress)
	var uid := boss.uid
	PlayerRegistry.for_player(&"p0", func(): boss.take_hit(9999, t.player().global_position, body))
	boss.take_hit(9999, t.player().global_position, body)
	EventBus.enemy_defeated.disconnect(on_enemy)
	EventBus.quest_objective_updated.disconnect(on_progress)
	var tag := "departed" if departed else "p1"
	t.check(tag + "_registered_owner_public_first_once", observed.size() == 1 and observed[0][0] == uid and observed[0][1] == &"snurresvamp" and observed[0][3] == 0 and observed[0][4] == 0)
	t.check(tag + "_earned_quest_names_and_kill", PlayerRegistry.for_player(&"p1", func(): return QuestManager.get_objective_progress(q, &"kill").get("current", 0) == 1 and QuestManager.get_objective_progress(q, &"heart").get("current", 0) == 1 and QuestManager.get_objective_progress(q, &"boss").get("current", 0) == 1))
	t.check(tag + "_owner_labels_caller_restored", updates == [[&"p1", &"kill"], [&"p1", &"heart"], [&"p1", &"boss"]] and PlayerRegistry.acting_id() == &"p0")
	t.check(tag + "_unrelated_profile_exact", p0.to_dict() == before)
	t.check(tag + "_all_original_eligible_bodies_refreshed", t.player().max_half_hearts == 12 and (departed or body.max_half_hearts == 12) and t.world().get_node("RunWatch").kills == 1)
	t.check(tag + "_oak_report_still_required", PlayerRegistry.for_player(&"p1", func(): return QuestManager.is_active(q) and not QuestManager.is_completed(q)))
	await t.frames(3)
	t.check(tag + "_no_duplicate_after_unwind", DungeonRun.hearts_bonus() == 2 and t.world().get_node("RunWatch").kills == 1)
	await t.go_menu()
