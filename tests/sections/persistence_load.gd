extends RefCounted
const SECTION := "persistence_load"
const TIMEOUT_S := 180.0
func _full(eco: Node) -> void:
	eco.inventory.clear()
	for i in eco.INVENTORY_SLOTS: eco.inventory.append({"id":&"wood", "amount":99, "meta":{}})
func run(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://persistence_load_fresh"
	var w: Node = t.world()
	var pose: Vector2 = w.player.global_position + Vector2(7, 2)
	w.player.set_physics_process(false)
	w.player.global_position = pose
	w.set_area_flag(w.area.map.id, "pb_loaded", 29)
	gm.set_flag(&"forest_mother_v1_map_account", gm.total_day())
	w._unregister_player(w.player)
	await t.frames(2)
	t.check("PB02_actual_hostless_file_written", sm.save_game(1))
	var old_id: int = w.get_instance_id()
	t.check("PB18_real_load_and_enter_admitted", sm.load_and_enter(1))
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_id and t.world().ready_for_play and not gm.lifecycle_busy(), 15.0)
	var fresh: Node = t.world()
	t.check("PB01_fresh_scene_restores_departed_host_pose", fresh.get_instance_id() != old_id and fresh.player != null and fresh.player.global_position.distance_to(pose) < 0.1)
	t.check("PB26_fresh_scene_restores_live_shared_flags", fresh.get_area_flag(fresh.area.map.id, "pb_loaded") == 29)
	t.check("PB18_pending_consumed_once", sm.pending_world.is_empty() and sm.consume_pending_world().is_empty())
	t.check("PB13_fresh_coherent_world_can_save", sm.save_game(2))
	for mode in ["primary", "backup", "direct", "raw", "primary_reset", "backup_reset", "direct_reset"]:
		await t.start_world()
		sm.autosave_enabled = false
		sm.save_dir = "user://persistence_load_receipt/"+mode
		DirAccess.make_dir_recursive_absolute(sm.save_dir)
		var eco: Node = t.autoload("EconomyManager")
		var qm: Node = t.autoload("QuestManager")
		var bus: Node = t.autoload("EventBus")
		_full(eco)
		qm.accept_quest(&"lost_cat")
		qm.complete_quest(&"lost_cat")
		eco.from_dict(eco.to_dict())
		t.autoload("LootService").from_dict(t.autoload("LootService").to_dict())
		await t.frames(4) # drain genuine setup tickets while capacity is full
		t.check("PB33_"+mode+"_earned_debt_before_trigger", qm.pending_rewards == {&"lost_cat":{"catnip_seeds":3}})
		eco.inventory.clear() # no notification authorizing another claim
		var payload: Dictionary = sm.gather_payload()
		var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
		var resets := []
		if mode.ends_with("_reset"):
			ui.request_page(null, {"id":"mayor_lyra"}, [{"text":"Committed load receipt"}], [{"action":"close"}], {"body":t.player()})
			ui.closed.connect(func():
				PlayerRegistry.reset_states()
				_full(eco)
				qm.accept_quest(&"intro_lottery")
				qm.complete_quest(&"intro_lottery")
				eco.inventory.clear()
				qm.to_dict()
				t.autoload("WardrobeManager").to_dict()
				resets.append(true), CONNECT_ONE_SHOT)
		var result := true
		if mode == "raw": bus.load_completed.emit(1)
		elif mode.begins_with("direct"): result = sm._apply_payload(payload).ok
		else:
			var f := FileAccess.open(sm.slot_path(0), FileAccess.WRITE)
			f.store_string("not json" if mode.begins_with("backup") else JSON.stringify(payload)); f.close()
			if mode.begins_with("backup"):
				var b := FileAccess.open(sm.backup_path(0), FileAccess.WRITE)
				b.store_string(JSON.stringify(payload)); b.close()
			result = sm.load_game(0)
		t.check("PB33_"+mode+"_actual_root_result", result and not gm.lifecycle_busy())
		await t.frames(4)
		if mode.ends_with("_reset"):
			t.check("PB33_"+mode+"_pre_ui_receipt_cannot_adopt_successor", resets == [true] and qm.pending_rewards == {&"intro_lottery":{"turnip_seeds":10}} and eco.count_item(&"turnip_seeds") == 0 and eco.count_item(&"catnip_seeds") == 0)
		elif mode == "raw":
			t.check("PB33_raw_slot_signal_mints_no_reward_ticket", eco.count_item(&"catnip_seeds") == 0 and qm.pending_rewards == {&"lost_cat":{"catnip_seeds":3}})
		else:
			t.check("PB33_"+mode+"_automatic_commit_reward_once", eco.count_item(&"catnip_seeds") == 3 and qm.pending_rewards.is_empty())
	await _social_receipts(t)

func _social_receipts(t) -> void:
	for mode in ["raw", "primary", "primary_reset"]:
		await t.start_world()
		var social: Node = t.autoload("SocialManager")
		var eco: Node = t.autoload("EconomyManager")
		var sm: Node = t.autoload("SaveManager")
		var bus: Node = t.autoload("EventBus")
		sm.autosave_enabled = false
		sm.save_dir = "user://persistence_social_receipts/"+mode
		DirAccess.make_dir_recursive_absolute(sm.save_dir)
		_full(eco)
		social.owe_event_items({"stone":2})
		await t.frames(4)
		t.check("PB33_social_"+mode+"_actual_owed_positive", social._event_owed == {"stone":2} and eco.count_item(&"stone") == 0)
		eco.inventory.clear()
		var payload: Dictionary = sm.gather_payload()
		var reset_observed := []
		if mode.ends_with("_reset"):
			var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
			ui.request_page(null, {"id":"mayor_lyra"}, [{"text":"Social committed receipt"}], [{"action":"close"}], {"body":t.player()})
			ui.closed.connect(func():
				PlayerRegistry.reset_states()
				social.reset()
				_full(eco)
				social.owe_event_items({"stone":3})
				eco.inventory.clear()
				reset_observed.append(true), CONNECT_ONE_SHOT)
		if mode == "raw": bus.load_completed.emit(0)
		else:
			var f := FileAccess.open(sm.slot_path(0), FileAccess.WRITE)
			f.store_string(JSON.stringify(payload)); f.close()
			t.check("PB33_social_"+mode+"_real_disk_success", sm.load_game(0))
		await t.frames(4)
		if mode == "primary": t.check("PB33_social_committed_owed_delivery_once", eco.count_item(&"stone") == 2 and social._event_owed.is_empty())
		elif mode == "raw": t.check("PB33_social_raw_slot_cannot_mint_earned_ticket", eco.count_item(&"stone") == 0 and social._event_owed == {"stone":2})
		else: t.check("PB33_social_pre_ui_ticket_cannot_adopt_new_debt", reset_observed == [true] and eco.count_item(&"stone") == 0 and social._event_owed == {"stone":3})
