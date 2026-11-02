extends RefCounted
const SECTION := "persistence_boundary"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await _mother(t)
	await t.start_world()
	await _write_ownership(t)

func _mother(t) -> void:
	await t.start_world()
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	sm.autosave_enabled = false
	sm.save_dir = "user://persistence_boundary"
	DirAccess.make_dir_recursive_absolute(sm.save_dir)
	var body: Node2D = w.player
	body.set_physics_process(false)
	body.global_position += Vector2(17, 9)
	var pose := body.global_position
	var hotbar: Dictionary = body.hotbar.to_dict()
	var p1: Node2D = w._make_player()
	w._register_player(p1, 1, 2)
	w.add_child(p1)
	p1.set_physics_process(false)
	PlayerRegistry.for_player(&"p1", func():
		var economy: Node = t.autoload("EconomyManager")
		economy.from_dict(economy.to_dict()))
	PlayerRegistry._states[&"p1"].name = "secondary"
	PlayerRegistry._states[&"p1"].gold = 123
	var p1_before: Dictionary = PlayerRegistry._states[&"p1"].to_dict()
	gm.set_flag(&"forest_mother_version", 1)
	gm.set_flag(&"forest_mother_v1_marked_lamp", gm.total_day())
	var page := MotherStory.topic_page("mapseller_natteblik")
	var actor := Npc2D.create({"id":"mapseller_natteblik", "wander":"0"})
	actor.area = w.area
	w.add_child(actor)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	var ticket: RefCounted = actor._begin_followup(body, page)
	await t.page_to_choices(ui)
	t.check("PB01_real_host_story_page", ticket != null and ui.is_open() and not page.is_empty())
	var departed := []
	var evidence_events := []
	var on_evidence := func(event, data):
		if event == &"forest_mother_evidence" and data.get("id") == "map_account": evidence_events.append(true)
	bus.game_event.connect(on_evidence)
	var weak_body: WeakRef = weakref(body)
	var close_observer := func():
		if departed.is_empty():
			departed.append(w._unregister_player(body))
	ui.closed.connect(close_observer)
	ui._pick({"action":"close"})
	ui.closed.disconnect(close_observer)
	t.check("PB01_earned_completion_survives_host_departure", MotherStory.has("map_account") and departed == [&"p0"])
	t.check("PB01_actual_autosave_bytes", FileAccess.file_exists(sm.slot_path(sm.AUTO_SLOT)))
	t.check("PB24_full_secondary_profile_unchanged", PlayerRegistry._states[&"p1"].to_dict() == p1_before)
	t.check("PB24_group_local_contract_unchanged", PlayerRegistry.local_id() == &"p1")
	await t.frames(3)
	t.check("PB02_actual_deferred_destruction", weak_body.get_ref() == null)
	w.set_area_flag(w.area.map.id, "pb_after_departure", 41)
	var payload: Dictionary = PlayerRegistry.for_player(&"p1", func(): return sm.gather_payload())
	t.check("PB25_departure_pose_not_defaults", payload.get("world", {}).get("player_pos") == [pose.x, pose.y])
	t.check("PB25_departure_hotbar_not_defaults", payload.get("world", {}).get("hotbar") == hotbar)
	t.check("PB26_shared_world_still_live", payload.get("world", {}).get("area_flags", {}).get(str(w.area.map.id), {}).get("pb_after_departure") == 41)
	t.check("PB24_payload_host_is_p0", payload.get("players", {}).get("rows", {}).get("p0", {}).get("player_pos") == [pose.x, pose.y])
	t.check("PB24_secondary_graph_after_gather", PlayerRegistry._states[&"p1"].to_dict() == p1_before)
	t.check("PB02_second_real_save_after_destruction", sm.save_game(1))
	var shared_before: Dictionary = w.area_flags.duplicate(true)
	var applied := []
	var on_applied := func(): applied.append(true)
	w.state_applied.connect(on_applied)
	w.from_dict({"area":str(w.area.map.id), "area_flags":{}})
	w.state_applied.disconnect(on_applied)
	t.check("PB14_hostless_direct_restore_refuses_before_mutation", w.area_flags == shared_before and applied.is_empty())
	if w.has_method("rejoin_host"):
		var joined: Node2D = w.rejoin_host()
		t.check("PB07_explicit_rejoin_hydrates_before_ready", joined != null and joined.global_position == pose and joined.hotbar.to_dict() == hotbar)
		if joined != null:
			joined.set_physics_process(false)
			var successor: Node2D = w._make_player()
			w._register_player(successor, 0, 1)
			w.add_child(successor)
			successor.enter_area(w.area, pose + Vector2(8, 3))
			successor.set_physics_process(false)
			var departures := []
			var observe_departure := func(pid): departures.append(pid)
			bus.player_despawned.connect(observe_departure)
			w._unregister_player(joined)
			bus.player_despawned.disconnect(observe_departure)
			t.check("PB06_old_cleanup_preserves_successor", w.player == successor and w.player_by_peer_id(1) == successor and departures.is_empty())
			var next_payload: Dictionary = sm.gather_payload()
			t.check("PB05_successor_projection_wins", next_payload.world.player_pos == [successor.global_position.x, successor.global_position.y])
			var same: Dictionary = w.roster.to_dict()
			w.roster.from_dict(same)
			var bytes_before: String = FileAccess.get_sha256(sm.slot_path(1))
			t.check("PB13_equal_model_replacement_old_world_refuses", not sm.save_game(1) and FileAccess.get_sha256(sm.slot_path(1)) == bytes_before)
	else:
		t.check("PB07_explicit_rejoin_hydrates_before_ready", false, "World has no rejoin_host entry")
	actor.free()
	var old_world_id: int = w.get_instance_id()
	var entered: bool = sm.load_and_enter(1)
	t.check("PB01_actual_earned_file_load_and_enter", entered)
	if entered:
		await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_world_id and t.world().ready_for_play and not gm.lifecycle_busy(), 15.0)
	t.check("PB01_fresh_load_preserves_real_earned_evidence_once", MotherStory.has("map_account") and MotherStory.topic_page("mapseller_natteblik").get("mother_evidence") == "" and not MotherStory.record("map_account") and evidence_events == [true])
	var loaded_world: Node = t.world()
	t.check("PB25_real_earned_file_restores_fresh_pose_hotbar", entered and loaded_world != null and is_instance_valid(loaded_world.player) and loaded_world.player.global_position.distance_to(pose) < 0.1 and loaded_world.player.hotbar.to_dict() == hotbar)
	bus.game_event.disconnect(on_evidence)
	gm.clear_config_overrides()

class CallbackSection extends Node:
	var observe: Callable
	var inside := false
	func to_dict() -> Dictionary:
		if observe.is_valid() and not inside:
			inside = true
			observe.call()
			inside = false
		return {"v":1}
	func reset() -> void: pass
	func from_dict(_d: Dictionary) -> bool: return true

func _write_ownership(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	sm.autosave_enabled = false
	sm.save_dir = "user://persistence_write_ownership"
	DirAccess.make_dir_recursive_absolute(sm.save_dir)
	var section := CallbackSection.new()
	t.root.add_child(section)
	sm.register_section("pb_callback", section, 999)
	var nested := []
	section.observe = func():
		nested.append(sm.autosave())
		nested.append(sm.load_game(5))
		nested.append(gm.try_start_new_game("nested", 0).get("ok"))
	var outer: bool = sm.save_game(0)
	t.check("PB27_first_save_root_wins", outer and nested == [false, false, false])
	t.check("PB27_busy_autosave_no_file", not FileAccess.file_exists(sm.slot_path(sm.AUTO_SLOT)))
	section.observe = func():
		var observed: Dictionary = sm.gather_payload()
		t.check("PB28_observational_gather_remains_dictionary", observed.has("players") and observed.has("world"))
	t.check("PB28_nested_gather_does_not_clobber_write", sm.save_game(0))
	section.observe = Callable()
	var tails := []
	var on_saved := func(_slot):
		tails.append(gm.lifecycle_busy())
		tails.append(sm.save_game(2))
		PlayerRegistry.reset_states()
	var notifications := []
	var on_notice := func(_a, _b, _c): notifications.append(true)
	bus.save_completed.connect(on_saved)
	bus.notification_posted.connect(on_notice)
	var committed: bool = sm.save_game(0)
	bus.save_completed.disconnect(on_saved)
	bus.notification_posted.disconnect(on_notice)
	t.check("PB30_committed_bool_survives_raw_tail_replacement", committed and FileAccess.file_exists(sm.slot_path(0)))
	t.check("PB30_root_occupied_through_notification", tails == [true, false])
	t.check("PB30_no_stale_success_toast", notifications.is_empty())
	t.check("PB27_root_released", not gm.lifecycle_busy())
	sm.unregister_section("pb_callback")
	section.free()
