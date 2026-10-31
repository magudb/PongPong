extends RefCounted
const SECTION := "boss_inner_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func run(t) -> void:
	for mode in ["normal", "direct"]: await _health(t, mode)
	for seam in ["drop", "add"]: await _phase(t, seam)

func _health(t, mode: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var saves: Node = t.autoload("SaveManager")
	var origin := EventBus.combat_receipt(EventBus.combat_origin(t.player()), boss)
	var files := H1.new()._files(saves)
	var seen: Array = []
	var notices: Array = []
	var clock_window: bool = await t.until(func(): return fmod(Time.get_unix_time_from_system(), 1.0) < .2, 2.0)
	var bar := func(_name, ratio, shown):
		if ratio >= .33 or not seen.is_empty(): return
		seen.append(true) # arm BEFORE the nested validated apply
		seen.append(boss.phase)
		if mode == "direct":
			var payload: Dictionary = saves.gather_payload()
			seen.append(saves.validate_payload(payload).ok and saves._apply_payload(payload).ok)
			seen.append(saves.gather_payload())
			seen.append(_attachments(boss))
			seen.append(t.player()._last_stats.duplicate(true))
			_journal(mode, "callback", {"payload":seen[3], "attachments":seen[4], "body_cache":seen[5], "files":H1.new()._files(saves)})
	var enemy := func(_id, _kind, _loot): notices.append(true)
	EventBus.boss_bar_changed.connect(bar)
	EventBus.enemy_defeated.connect(enemy)
	t.check(mode + "_real_clock_window", clock_window)
	t.check(mode + "_original_model_current", EventBus.combat_current(origin) and boss.phase == 0 and boss.hp == boss.max_hp)
	boss.take_hit(boss.hp - 1, t.player().global_position, t.player())
	EventBus.boss_bar_changed.disconnect(bar)
	EventBus.enemy_defeated.disconnect(enemy)
	t.check(mode + "_actual_hit_committed_before_bar", seen.size() >= 2 and seen[1] == 0 and boss.hp == 1 and notices.is_empty())
	if mode == "normal":
		t.check("normal_both_thresholds_exact_adds_drops", boss.phase == 2 and boss.summoned.size() == boss.adds and t.world().area.objects.get_children().filter(func(n): return n is LootDrop2D and n.item_id == &"tornebaer").size() == 2)
	else:
		t.check("direct_validated_same_value_replacement", seen.size() == 6 and seen[2] and not EventBus.combat_current(origin))
		t.check("direct_bar_stops_inner_phase_add_drop", boss.phase == 0 and _attachments(boss) == seen[4])
		var after: Dictionary = saves.gather_payload()
		_journal(mode, "unwind", {"payload":after, "attachments":_attachments(boss), "body_cache":t.player()._last_stats, "files":H1.new()._files(saves)})
		t.check("direct_full_winner_exact_unwind", Compare.new()._same_payload(seen[3], after), str(Compare.new()._changed(seen[3], after)))
		t.check("direct_body_cache_exact", t.player()._last_stats == seen[5])
		await t.frames(3)
		var queued: Dictionary = saves.gather_payload()
		_journal(mode, "three_frames", {"payload":queued, "attachments":_attachments(boss), "body_cache":t.player()._last_stats, "files":H1.new()._files(saves)})
		t.check("direct_full_winner_exact_three_frames", Compare.new()._same_payload(seen[3], queued), str(Compare.new()._changed(seen[3], queued)))
		boss._on_health_changed()
		t.check("direct_next_current_health_root_progresses", boss.phase == 2 and boss.summoned.size() == boss.adds)
	t.check(mode + "_files_exact", H1.new()._files(saves) == files)
	await t.go_menu()

func _phase(t, seam: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var saves: Node = t.autoload("SaveManager")
	var seen: Array = []
	var files := H1.new()._files(saves)
	var origin := EventBus.combat_receipt(EventBus.combat_origin(t.player()), boss)
	var clock_window: bool = await t.until(func(): return fmod(Time.get_unix_time_from_system(), 1.0) < .2, 2.0)
	var child := func(node):
		if not seen.is_empty() or not ((seam == "drop" and node is LootDrop2D) or (seam == "add" and node is Enemy2D)): return
		seen.append(true)
		seen.append(weakref(node))
		var payload: Dictionary = saves.gather_payload()
		seen.append(saves.validate_payload(payload).ok and saves._apply_payload(payload).ok)
		seen.append(saves.gather_payload())
		seen.append(_attachments(boss))
		seen.append(node.global_position)
		seen.append(node.stun_generation if node is Enemy2D else 0)
		_journal(seam, "callback", {"payload":seen[3], "attachments":seen[4], "position":seen[5], "stun_generation":seen[6], "files":H1.new()._files(saves)})
	t.world().area.objects.child_entered_tree.connect(child)
	t.check(seam + "_real_clock_window", clock_window)
	boss.take_hit(boss.hp - 1, t.player().global_position, t.player())
	t.world().area.objects.child_entered_tree.disconnect(child)
	t.check(seam + "_actual_first_phase_prefix_and_apply", seen.size() == 7 and seen[2] and not EventBus.combat_current(origin) and seen[4].phase == 1)
	t.check(seam + "_no_later_phase_add_drop", _attachments(boss) == seen[4])
	var node: Variant = seen[1].get_ref()
	t.check(seam + "_callee_position_stun_suffix_stopped", is_instance_valid(node) and node.global_position == seen[5] and (not node is Enemy2D or node.stun_generation == seen[6]))
	var after: Dictionary = saves.gather_payload()
	_journal(seam, "unwind", {"payload":after, "attachments":_attachments(boss), "position":node.global_position, "files":H1.new()._files(saves)})
	t.check(seam + "_full_winner_exact_unwind", Compare.new()._same_payload(seen[3], after), str(Compare.new()._changed(seen[3], after)))
	await t.frames(3)
	var queued: Dictionary = saves.gather_payload()
	_journal(seam, "three_frames", {"payload":queued, "attachments":_attachments(boss), "files":H1.new()._files(saves)})
	t.check(seam + "_full_winner_exact_three_frames", Compare.new()._same_payload(seen[3], queued), str(Compare.new()._changed(seen[3], queued)))
	t.check(seam + "_files_exact", H1.new()._files(saves) == files)
	await t.go_menu()

func _attachments(boss: DungeonBoss2D) -> Dictionary:
	return {"phase":boss.phase, "summoned":boss.summoned.map(func(r): return r.get_ref().get_instance_id() if is_instance_valid(r.get_ref()) else 0), "objects":boss.area.objects.get_children().map(func(n): return n.get_instance_id()), "ground_fx":boss.area.ground_fx.get_children().map(func(n): return n.get_instance_id())}

func _journal(tag: String, endpoint: String, state: Dictionary) -> void:
	var path := OS.get_environment("H2_STATE_JOURNAL")
	if path == "": return
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
	file.seek_end()
	file.store_line(JSON.stringify({"tag":tag, "endpoint":endpoint, "state":state}, "", true, true))
	file.close()
