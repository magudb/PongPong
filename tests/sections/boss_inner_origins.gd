extends RefCounted
const SECTION := "boss_inner_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func run(t) -> void:
	for mode in ["normal", "direct"]: await _health(t, mode)
	for seam in ["drop", "add"]: await _phase(t, seam)
	for effect in ["heart", "oil"]: await _onkill(t, effect)
	await _death(t)
	for mode in ["direct", "detach", "queued", "free_deferred"]: await _death_lifetime(t, mode)

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

func _onkill(t, effect: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	body.enter_area(t.world().area, t.player().global_position)
	body.set_physics_process(false)
	var id := "wpn_dagger_bee" if effect == "heart" else "wpn_sword_forest_steel"
	body.combat._weapon = WeaponInfo.of(id)
	body.half_hearts = 2
	body.oil = 10
	body._emit_stats_on_bus()
	if effect == "heart":
		for i in 3:
			var target: Enemy2D = Enemy2D.create_marker({"kind":"bat", "persist":0}, boss.home + Vector2(400,0), boss.cell, boss.area)
			boss.area.objects.add_child(target)
			target.set_physics_process(false)
			target.take_hit(9999, body.global_position, body)
		await t.frames(40)
		t.check("heart_three_actual_kills_no_early_heal", body.half_hearts == 2 and body.get_meta("weapon_kill_" + id, 0) == 3)
	var saves: Node = t.autoload("SaveManager")
	var origin := EventBus.combat_receipt(EventBus.combat_origin(body), boss)
	var seen: Array = []
	var suffix: Array = []
	var files := H1.new()._files(saves)
	# A global Save payload is gathered/applied in its actual p0 facade scope;
	# the enclosing hit and its on-kill effect still belong to registered p1.
	saves.gather_payload()
	var unrelated := PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true)
	var replace := func():
		if not seen.is_empty(): return
		seen.append(true)
		PlayerRegistry.for_player(&"p0", func():
			var payload: Dictionary = saves.gather_payload()
			seen.append(saves.validate_payload(payload).ok and saves._apply_payload(payload).ok)
			seen.append(saves.gather_payload()))
		seen.append(body._last_stats.duplicate(true))
		_journal(effect, "callback", {"payload":seen[2], "body_cache":seen[3], "files":H1.new()._files(saves)})
	var health := func(pid, hearts, _max):
		if effect == "heart" and pid == &"p1" and hearts == 3: replace.call()
	var oil := func(pid, seconds, _max):
		if effect == "oil" and pid == &"p1" and seconds == 12: replace.call()
	var stats := func(pid, _values):
		if pid == &"p1" and not seen.is_empty(): suffix.append(pid)
	EventBus.player_health_changed.connect(health)
	EventBus.player_oil_changed.connect(oil)
	EventBus.player_stats_changed.connect(stats)
	var clock_window: bool = await t.until(func(): return fmod(Time.get_unix_time_from_system(), 1.0) < .2, 2.0)
	t.check(effect + "_real_clock_window", clock_window)
	PlayerRegistry.for_player(&"p0", func(): boss.take_hit(9999, body.global_position, body))
	EventBus.player_health_changed.disconnect(health)
	EventBus.player_oil_changed.disconnect(oil)
	EventBus.player_stats_changed.disconnect(stats)
	t.check(effect + "_real_registered_recipient_effect_committed", seen.size() == 4 and seen[1] and not EventBus.combat_current(origin) and (body.half_hearts == 3 if effect == "heart" else body.oil == 12))
	t.check(effect + "_no_stale_cache_stats_suffix", body._last_stats == seen[3] and suffix.is_empty())
	t.check(effect + "_unrelated_profile_and_scope_exact", PlayerRegistry.peek_state(&"p0").to_dict() == unrelated and PlayerRegistry.acting_id() == &"p0")
	t.check(effect + "_no_uncommitted_death_into_winner", boss.state != Enemy2D.S.DEAD and DungeonRun.hearts_bonus() == 0)
	var after: Dictionary = saves.gather_payload()
	_journal(effect, "unwind", {"payload":after, "body_cache":body._last_stats, "files":H1.new()._files(saves)})
	t.check(effect + "_full_winner_exact_unwind", Compare.new()._same_payload(seen[2], after), str(Compare.new()._changed(seen[2], after)))
	await t.frames(3)
	var queued: Dictionary = saves.gather_payload()
	_journal(effect, "three_frames", {"payload":queued, "body_cache":body._last_stats, "files":H1.new()._files(saves)})
	t.check(effect + "_full_winner_exact_three_frames", Compare.new()._same_payload(seen[2], queued), str(Compare.new()._changed(seen[2], queued)))
	t.check(effect + "_files_exact", H1.new()._files(saves) == files)
	await t.go_menu()

func _death(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var bars: Array = []
	var seen: Array = []
	var notices: Array = []
	var died: Array = []
	var finished: Array = []
	var bar := func(_name, ratio, shown):
		if ratio != 0 or shown or not seen.is_empty(): return
		bars.append(true)
		if bars.size() != 2: return # actual health bar, then actual death bar
		seen.append(true)
		boss.reset_fight()
		boss.start_pattern("cloud")
		boss.take_hit(1, t.player().global_position, t.player())
		seen.append(boss.hp)
		seen.append(boss.state)
		seen.append(boss.get_children().filter(func(n): return n.get_script() == DungeonBoss2D.Sequence).map(func(n): return weakref(n)))
	var enemy := func(_id, _kind, _loot): notices.append(true)
	var death := func(_enemy): died.append(true)
	var finish := func(victory): finished.append(victory)
	EventBus.boss_bar_changed.connect(bar)
	EventBus.enemy_defeated.connect(enemy)
	boss.died.connect(death)
	EventBus.combat_finished.connect(finish)
	boss.take_hit(9999, t.player().global_position, t.player())
	EventBus.boss_bar_changed.disconnect(bar)
	EventBus.enemy_defeated.disconnect(enemy)
	boss.died.disconnect(death)
	EventBus.combat_finished.disconnect(finish)
	t.check("death_reentrant_new_root_reached", seen.size() == 4 and seen[3].size() == 1)
	t.check("death_old_cleanup_preserves_new_state", boss.hp == seen[1] and boss.state == seen[2] and boss.state != Enemy2D.S.DEAD)
	t.check("death_old_cleanup_preserves_exact_new_sequence", is_instance_valid(seen[3][0].get_ref()) and not seen[3][0].get_ref().is_queued_for_deletion())
	t.check("death_committed_notifications_once", notices == [true] and died == [true] and finished == [true])
	await t.seconds(.7)
	t.check("death_old_tween_cannot_free_new_request", is_instance_valid(boss) and not boss.is_queued_for_deletion() and boss.hp == seen[1])
	await t.go_menu()

func _death_lifetime(t, mode: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var ref: WeakRef = weakref(boss)
	var saves: Node = t.autoload("SaveManager")
	var seen: Array = []
	var notices: Array = []
	var deaths: Array = []
	var finishes: Array = []
	var files := H1.new()._files(saves)
	var bar := func(_name, ratio, shown):
		if ratio != 0 or shown or not seen.is_empty(): return
		seen.append(true)
		var old: Variant = ref.get_ref()
		if mode == "direct":
			var payload: Dictionary = saves.gather_payload()
			seen.append(saves.validate_payload(payload).ok and saves._apply_payload(payload).ok)
			seen.append(saves.gather_payload())
			_journal("death_" + mode, "callback", {"payload":seen[2], "files":H1.new()._files(saves)})
		elif mode == "queued": old.queue_free()
		else:
			old.get_parent().remove_child(old)
			if mode == "free_deferred": old.call_deferred("free")
	var notice := func(_id, _kind, _loot): notices.append(true)
	var death := func(_enemy): deaths.append(true)
	var finish := func(victory): finishes.append(victory)
	EventBus.boss_bar_changed.connect(bar)
	EventBus.enemy_defeated.connect(notice)
	boss.died.connect(death)
	EventBus.combat_finished.connect(finish)
	var clock_window: bool = await t.until(func(): return fmod(Time.get_unix_time_from_system(), 1.0) < .2, 2.0)
	t.check("death_" + mode + "_real_clock_window", clock_window)
	boss._die() # independent supported current death root, before any fatal bar
	EventBus.boss_bar_changed.disconnect(bar)
	EventBus.enemy_defeated.disconnect(notice)
	EventBus.combat_finished.disconnect(finish)
	var old: Variant = ref.get_ref()
	if is_instance_valid(old): old.died.disconnect(death)
	t.check("death_" + mode + "_committed_terminal_notifications_once", seen.size() > 0 and notices == [true] and finishes == [true] and deaths == [true])
	if mode == "direct":
		t.check("death_direct_model_suffix_revoked", seen.size() == 3 and seen[1] and t.world().get_node("RunWatch").kills == 0 and DungeonRun.hearts_bonus() == 0)
		var after: Dictionary = saves.gather_payload()
		_journal("death_" + mode, "unwind", {"payload":after, "files":H1.new()._files(saves)})
		t.check("death_direct_winner_exact_unwind", Compare.new()._same_payload(seen[2], after), str(Compare.new()._changed(seen[2], after)))
		await t.frames(3)
		var queued: Dictionary = saves.gather_payload()
		_journal("death_" + mode, "three_frames", {"payload":queued, "files":H1.new()._files(saves)})
		t.check("death_direct_winner_exact_three_frames", Compare.new()._same_payload(seen[2], queued), str(Compare.new()._changed(seen[2], queued)))
	else:
		t.check("death_" + mode + "_earned_model_survives_source_departure", t.world().get_node("RunWatch").kills == 1 and DungeonRun.hearts_bonus() == 2)
		if mode == "detach" and is_instance_valid(old): old.free()
		await t.frames(3)
		t.check("death_" + mode + "_actual_source_destroyed", not is_instance_valid(ref.get_ref()))
	t.check("death_" + mode + "_files_exact", H1.new()._files(saves) == files)
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
