extends RefCounted
const SECTION := "persistence_world_variants"
const TIMEOUT_S := 180.0

class LateRefusal extends Node:
	var depart: Callable
	func to_dict() -> Dictionary: return {"reject":false}
	func reset() -> void: pass
	func from_dict(d: Dictionary) -> bool:
		if d.get("reject", false):
			depart.call()
			return false
		return true

func _setup(t, label: String) -> Node:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://persistence_world_variants/" + label
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
	return t.world()

func _mother(t, w: Node) -> Node:
	var gm: Node = t.autoload("GameManager")
	gm.set_flag(&"forest_mother_version", 1)
	gm.set_flag(&"forest_mother_v1_marked_lamp", gm.total_day())
	var actor := Npc2D.create({"id":"mapseller_natteblik", "wander":"0"})
	actor.area = w.area
	w.add_child(actor)
	return actor

func run(t) -> void:
	await _cancel_save(t)
	await _direct_restore(t)
	await _raw_attachments(t)
	for prior in ["no_save", "earlier_save", "stale_pending"]:
		await _fresh_attachment(t, prior)
	await _shared_models(t)
	await _rollback_and_successor(t)
	t.autoload("GameManager").clear_config_overrides()

func _cancel_save(t) -> void:
	for mode in ["unread", "cancel"]:
		var w: Node = await _setup(t, mode)
		var sm: Node = t.autoload("SaveManager")
		var actor := _mother(t, w)
		var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
		var ticket: RefCounted = actor._begin_followup(w.player, MotherStory.topic_page("mapseller_natteblik"))
		if mode == "cancel": await t.page_to_choices(ui)
		t.check("PB03_"+mode+"_real_page_before_input", ticket != null and ui.is_open() and (mode != "unread" or ui._shown == 1))
		var body: Node2D = w.player
		var departed := []
		ui.closed.connect(func(): departed.append(w._unregister_player(body)), CONNECT_ONE_SHOT)
		t.tap(&"ui_cancel")
		await t.frames(3)
		t.check("PB03_"+mode+"_real_cancel_no_earned_evidence", not ui.is_open() and not MotherStory.has("map_account") and departed == [&"p0"] and w.player == null)
		w.set_area_flag(w.area.map.id, "independent_after_cancel", mode)
		t.check("PB03_"+mode+"_same_world_independent_save", sm.save_game(0))
		var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sm.slot_path(0)))
		t.check("PB03_"+mode+"_persisted_later_world_not_unread_evidence", disk.world.area_flags[str(w.area.map.id)].independent_after_cancel == mode and not disk.game.world_flags.has("forest_mother_v1_map_account"))
		actor.free()

func _direct_restore(t) -> void:
	var w: Node = await _setup(t, "direct")
	var sm: Node = t.autoload("SaveManager")
	var applied := []
	w.state_applied.connect(func(): applied.append(true))
	var d: Dictionary = w.to_dict()
	d.area = "_fixture_ortho"
	d.player_pos = [200.0, 150.0]
	d.area_flags = {"_fixture_ortho":{"direct_cross":73}}
	t.check("PB14_cross_area_real_restore", w.try_from_dict(d).ok and w.area.map.id == &"_fixture_ortho" and w.area.is_ancestor_of(w.player) and w.player.global_position.distance_to(Vector2(200,150)) < 0.1 and applied.size() == 1)
	for damaged in [[null, 4], [INF, 2], [1], "bad"]:
		d.player_pos = damaged
		t.check("PB14_damaged_position_"+str(applied.size()), w.try_from_dict(d).ok and w.player.global_position == w.area.get_spawn("default"))
	var area_before: Node = w.area
	var spawn: Vector2 = w.area.get_spawn("default")
	d.area = "pb_missing_map"
	d.player_pos = [9000,9000]
	t.check("PB14_unknown_map_does_not_adopt_foreign_coordinates", w.try_from_dict(d).ok and w.area == area_before and w.player.global_position == spawn)
	WorldRoot2D._registry[&"pb_damaged_map"] = {"path":"res://data/maps/pb_does_not_exist.map", "fixture":true, "map":null}
	var before: Dictionary = w.to_dict()
	var count: int = applied.size()
	d.area = "pb_damaged_map"
	d.area_flags = {"forged":{"mutation":true}}
	t.check("PB14_registered_damaged_map_refuses_before_mutation", not w.try_from_dict(d).ok and w.to_dict() == before and applied.size() == count)
	WorldRoot2D._registry.erase(&"pb_damaged_map")
	w._unregister_player(w.player)
	await t.frames(3)
	before = w.to_dict()
	d.area = "farm"
	t.check("PB14_hostless_cross_area_refuses_exact_world", not w.try_from_dict(d).ok and w.area == area_before and w.to_dict() == before and applied.size() == count and sm.save_game(0))
	var p: Node2D = w.rejoin_host()
	await w.travel(&"home", &"default")
	var at: Vector2 = p.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("PB14_restore_refusal_then_natural_progress", p.is_physics_processing() and p.global_position.distance_to(at) > 1 and sm.save_game(1))

func _raw_attachments(t) -> void:
	for mode in ["free", "queue", "transfer", "forged_clone", "area_reparent"]:
		var w: Node = await _setup(t, "raw_"+mode)
		var sm: Node = t.autoload("SaveManager")
		t.check("PB19_"+mode+"_healthy_preimage", sm.save_game(0))
		var hash_before: String = FileAccess.get_sha256(sm.slot_path(0))
		var body: Node2D = w.player
		var foreign := Node2D.new()
		t.root.add_child(foreign)
		var clone: Node2D
		if mode == "free": body.free() # outside any emitting/executing body stack: legal synchronous destruction
		elif mode == "queue": body.queue_free()
		elif mode == "transfer": body.reparent(foreign)
		elif mode == "forged_clone":
			body.reparent(foreign)
			clone = w._make_player()
			clone.player_id = &"p0"
			w.add_child(clone)
			clone.enter_area(w.area, w.area.get_spawn("default"))
		else:
			t.check("PB19_ordinary_area_reparent_saves", w._enter(&"home", &"default") and w.area.is_ancestor_of(body) and sm.save_game(1))
		if mode != "area_reparent":
			t.check("PB19_"+mode+"_immediate_real_write_refuses", not sm.save_game(0) and FileAccess.get_sha256(sm.slot_path(0)) == hash_before and not FileAccess.file_exists(sm.backup_path(0)))
			await t.frames(3)
			if mode in ["free", "queue"]: t.check("PB19_"+mode+"_no_freed_local_alias", is_same(w.local_player(), null))
			t.check("PB19_"+mode+"_after_frames_still_refuses", not sm.save_game(0) and FileAccess.get_sha256(sm.slot_path(0)) == hash_before)
		if is_instance_valid(clone): clone.queue_free()
		if mode != "area_reparent":
			var replacement: Node2D = w._make_player()
			w._register_player(replacement, 0, 1)
			w.add_child(replacement)
			replacement.enter_area(w.area, w.area.get_spawn("default"))
			t.check("PB19_"+mode+"_legitimate_replacement_recovers_same_world", w.persistence_ready() and sm.save_game(1))
		foreign.queue_free()
		await t.frames(2)

func _fresh_attachment(t, prior: String) -> void:
	var w: Node = await _setup(t, prior)
	var sm: Node = t.autoload("SaveManager")
	var original: Dictionary = w.to_dict()
	if prior != "no_save": t.check("PB25_"+prior+"_earlier_actual_save", sm.save_game(0))
	if prior == "stale_pending": sm.pending_world = original.duplicate(true)
	var p: Node2D = w.player
	p.hotbar.assign(0, &"wood")
	p.hotbar.assign(6, &"stone")
	p.hotbar.select(6)
	p.global_position += Vector2(13, 5)
	p.half_hearts = 3
	p.stamina = 26.0
	p.oil = 47.0
	var pose: Vector2 = p.global_position
	var hb: Dictionary = p.hotbar.to_dict()
	t.check("PB25_"+prior+"_deliberate_hotbar_mutation", hb != original.hotbar and hb.slots[0] == "wood" and hb.slots[6] == "stone" and hb.selected == 6)
	var dead: WeakRef = weakref(p)
	w._unregister_player(p)
	await t.frames(3)
	var model: PlayerState = PlayerRegistry._states[&"p0"]
	model.half_hearts = 4
	var payload: Dictionary = sm.gather_payload()
	t.check("PB25_"+prior+"_hp_only_model_update", dead.get_ref() == null and payload.players.rows.p0.half_hearts == 4 and payload.players.rows.p0.stamina == 26.0 and payload.players.rows.p0.oil == 47.0)
	model.stamina = 31.0
	payload = sm.gather_payload()
	t.check("PB25_"+prior+"_stamina_only_model_update", payload.players.rows.p0.half_hearts == 4 and payload.players.rows.p0.stamina == 31.0 and payload.players.rows.p0.oil == 47.0)
	model.oil = 52.0
	payload = sm.gather_payload()
	t.check("PB25_"+prior+"_oil_only_model_update", payload.players.rows.p0.half_hearts == 4 and payload.players.rows.p0.stamina == 31.0 and payload.players.rows.p0.oil == 52.0)
	t.check("PB25_"+prior+"_fresh_checkpoint_not_pending", payload.world.player_pos == [pose.x,pose.y] and payload.world.hotbar == hb and sm.save_game(1))
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sm.slot_path(1)))
	t.check("PB25_"+prior+"_actual_disk_fresh_hotbar", disk.world.hotbar == JSON.parse_string(JSON.stringify(hb)) and disk.world.player_pos == [pose.x,pose.y])
	t.check("PB25_"+prior+"_hostless_actual_autosave", sm.autosave())
	var auto_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sm.slot_path(sm.AUTO_SLOT)))
	t.check("PB25_"+prior+"_hostless_autosave_exact_fresh_attachment", auto_disk.world.hotbar == JSON.parse_string(JSON.stringify(hb)) and auto_disk.world.player_pos == [pose.x,pose.y])
	var health := []
	var on_health := func(pid, hp, _max):
		if pid == &"p0": health.append(hp)
	t.autoload("EventBus").player_health_changed.connect(on_health)
	var joined: Node2D = w.rejoin_host()
	t.autoload("EventBus").player_health_changed.disconnect(on_health)
	t.check("PB07_"+prior+"_pre_ready_nondefault_hydration", joined != null and joined.hotbar.to_dict() == hb and joined.half_hearts == 4 and joined.stamina == 31.0 and joined.oil == 52.0 and not health.is_empty() and health.all(func(hp): return hp == 4))
	var actor := _mother(t, w)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	var ticket: RefCounted = actor._begin_followup(joined, MotherStory.topic_page("mapseller_natteblik"))
	await t.page_to_choices(ui)
	await t.until_game(func(): return ui._choice_grace <= 0.0, 1.0)
	ui._buttons[-1].grab_focus()
	t.check("PB07_"+prior+"_real_rejoined_story_open", ticket != null and ui.is_open())
	t.tap(&"interact")
	await t.frames(4)
	t.check("PB07_"+prior+"_real_input_dialogue_earned_once", not ui.is_open() and MotherStory.has("map_account") and FileAccess.file_exists(sm.slot_path(sm.AUTO_SLOT)))
	actor.free()
	var id: int = w.get_instance_id()
	t.check("PB25_"+prior+"_actual_fresh_scene_load", sm.load_and_enter(1))
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != id and t.world().ready_for_play and not t.autoload("GameManager").lifecycle_busy(), 15)
	var fresh: Node = t.world()
	t.check("PB25_"+prior+"_fresh_scene_restores_mutated_entries_selection", fresh.player.hotbar.to_dict() == hb and fresh.player.global_position.distance_to(pose) < 0.1 and sm.pending_world.is_empty())

func _shared_models(t) -> void:
	var w: Node = await _setup(t, "shared")
	var sm: Node = t.autoload("SaveManager")
	var eco: Node = t.autoload("EconomyManager")
	var p1: Node2D = w._make_player()
	w._register_player(p1, 1, 2)
	w.add_child(p1)
	PlayerRegistry.for_player(&"p1", func(): eco.from_dict(eco.to_dict()))
	var secondary: PlayerState = PlayerRegistry._states[&"p1"]
	secondary.name = "PB whole secondary"
	secondary.gold = 123
	secondary.flags["pb_sentinel"] = "unchanged"
	secondary.inventory.append({"id":&"wood", "amount":2, "meta":{"array":[1,{"sentinel":"unchanged"}]}})
	var secondary_before: Dictionary = secondary.to_dict().duplicate(true)
	var old: Dictionary = w.to_dict()
	w._unregister_player(w.player)
	await t.frames(3)
	var outdoor: Vector2i = w.farm.farmable_cells()[0]
	var indoor: Vector2i = w.greenhouse_farm.farmable_cells()[0]
	PlayerRegistry.for_player(&"p0", func():
		eco.add_item(&"turnip_seeds", 2, true)
		eco.add_item(&"snow_turnip_seeds", 2, true))
	var planted_out: bool = PlayerRegistry.for_player(&"p0", func(): return w.farm.till(outdoor) and w.farm.plant(outdoor, &"turnip_seeds") == "" and w.farm.water(outdoor))
	var planted_in: bool = PlayerRegistry.for_player(&"p0", func(): return w.greenhouse_farm.till(indoor) and w.greenhouse_farm.plant(indoor, &"snow_turnip_seeds") == "" and w.greenhouse_farm.water(indoor))
	w.placed_items.append({"item":"scarecrow", "cell":[4,5]})
	w.placed_orphans.append({"item":"pb_missing_placeable", "cell":[6,7]})
	w.set_area_flag(&"farm", "pb_shared_live", 87)
	t.check("PB26_distinct_postdeparture_crop_greenhouse_placed_orphan_mutations", planted_out and planted_in and w.farm.to_dict() != old.farm and w.greenhouse_farm.to_dict() != old.greenhouse_farm and w.placed_items != old.placed and w.placed_orphans.size() == 1)
	var payload: Dictionary = PlayerRegistry.for_player(&"p1", func(): return sm.gather_payload())
	var expected: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	t.check("PB26_live_shared_gather_not_cached_world", JSON.parse_string(JSON.stringify(payload.world)) == expected)
	t.check("PB24_shared_mutations_whole_secondary_untouched", is_same(secondary, PlayerRegistry._states[&"p1"]) and secondary.to_dict() == secondary_before)
	t.check("PB26_hostless_actual_shared_write", PlayerRegistry.for_player(&"p1", func(): return sm.save_game(0)))
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sm.slot_path(0)))
	t.check("PB26_real_persisted_all_shared_fields", disk.world == expected)
	var id: int = w.get_instance_id()
	t.check("PB26_actual_fresh_scene_load", sm.load_and_enter(0))
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != id and t.world().ready_for_play and not t.autoload("GameManager").lifecycle_busy(), 15)
	var fresh: Node = t.world()
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(fresh.to_dict()))
	t.check("PB26_fresh_scene_all_shared_models_restored", loaded.farm == expected.farm and loaded.greenhouse_farm == expected.greenhouse_farm and loaded.placed == expected.placed and loaded.placed_orphans == expected.placed_orphans and loaded.area_flags == expected.area_flags, "expected="+str(expected)+" loaded="+str(loaded))
	t.check("PB24_fresh_scene_secondary_complete_profile", PlayerRegistry._states[&"p1"].to_dict() == secondary_before)
	t.check("PB26_next_independent_save_healthy", sm.save_game(1))

func _rollback_and_successor(t) -> void:
	var w: Node = await _setup(t, "rollback_successor")
	var sm: Node = t.autoload("SaveManager")
	var social: Node = t.autoload("SocialManager")
	var model: PlayerState = PlayerRegistry._states[&"p0"]
	var nested: Dictionary = {"array":[{"sentinel":"exact alias"}]}
	model.inventory[0].meta = nested
	var inventory: Array = model.inventory
	var row: Dictionary = model.inventory[0]
	var nested_array: Array = nested.array
	var writes: Dictionary = model._vital_writes.duplicate()
	var accounting: Variant = social._accounting_world
	var late := LateRefusal.new()
	t.root.add_child(late)
	sm.register_section("pb_world_identity", late, 999)
	var payload: Dictionary = sm.gather_payload()
	payload.pb_world_identity.reject = true
	w.player.half_hearts = 3
	w.player.stamina = 28.0
	w.player.oil = 42.0
	var projection: Dictionary = w.to_dict()
	var dead: WeakRef = weakref(w.player)
	late.depart = func(): w._unregister_player(w.player)
	var result: Dictionary = sm._apply_payload(payload)
	t.check("PB09_actual_complete_rollback_exact_nested_model_identity", not result.ok and is_same(PlayerRegistry._states[&"p0"],model) and is_same(model.inventory,inventory) and is_same(model.inventory[0],row) and is_same(model.inventory[0].meta,nested) and is_same(model.inventory[0].meta.array,nested_array) and social._accounting_world == accounting)
	var tokens_exact := true
	for key in ["half_hearts", "stamina", "oil"]:
		tokens_exact = tokens_exact and is_same(model._vital_writes.get(key),writes.get(key))
	t.check("PB09_complete_rollback_exact_per_field_provenance", tokens_exact and w.to_dict() == projection and w.persistence_vitals() == {"half_hearts":3,"stamina":28.0,"oil":42.0})
	await t.frames(3)
	t.check("PB09_complete_rollback_no_body_resurrection_save_healthy", dead.get_ref() == null and w.player == null and sm.save_game(0))
	var old_generation: int = w._host_generation
	var successor: Node2D = w._make_player()
	# Deliberate configured replacement, NOT rejoin hydration; same model wins.
	w._register_player(successor, 0, 1)
	w.add_child(successor)
	successor.enter_area(w.area, w.area.get_spawn("default") + Vector2(9,3))
	successor.hotbar.assign(0, &"stone")
	successor.hotbar.assign(7, &"wood")
	successor.hotbar.select(7)
	successor.half_hearts = 5
	successor.stamina = 39.0
	successor.oil = 61.0
	var at: Vector2 = successor.global_position
	var hb: Dictionary = successor.hotbar.to_dict()
	var selected: Dictionary = sm.gather_payload()
	t.check("PB05_eligible_same_model_successor_all_fields_win", is_same(PlayerRegistry._states[&"p0"],model) and w._host_generation > old_generation and selected.world.player_pos == [at.x,at.y] and selected.world.hotbar == hb and selected.players.rows.p0.half_hearts == 5 and selected.players.rows.p0.stamina == 39.0 and selected.players.rows.p0.oil == 61.0)
	w._unregister_player(successor)
	await t.frames(3)
	t.check("PB06_successor_own_later_departure_remains_selected", w.to_dict().hotbar == hb and w.to_dict().player_pos == [at.x,at.y] and sm.save_game(1))
	sm.unregister_section("pb_world_identity")
	late.free()
