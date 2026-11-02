extends RefCounted
const SECTION := "persistence_save_receipts"
const TIMEOUT_S := 180.0

func _full(eco: Node) -> void:
	eco.inventory.clear()
	for i in eco.INVENTORY_SLOTS: eco.inventory.append({"id":&"wood", "amount":99, "meta":{}})

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text); file.close()

# Entire script-variable/container graph, not just gold or quest outcomes.
func _graph(value: Variant) -> Dictionary:
	var children := {}
	if value is Dictionary:
		for key in value: children[key] = _graph(value[key])
	elif value is Array:
		for i in value.size(): children[i] = _graph(value[i])
	elif value is RefCounted:
		for prop in value.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: children[prop.name] = _graph(value.get(prop.name))
	return {"ref":value, "children":children}

func _same_graph(value: Variant, captured: Dictionary) -> bool:
	if not is_same(value, captured.ref): return false
	if value is Dictionary or value is Array:
		if value.size() != captured.children.size(): return false
		for key in captured.children:
			if value is Dictionary and not value.has(key): return false
			if not _same_graph(value[key], captured.children[key]): return false
	elif value is RefCounted:
		for key in captured.children:
			if not _same_graph(value.get(key), captured.children[key]): return false
	return true

func _diff(actual: Dictionary, expected: Dictionary) -> Dictionary:
	var out := {}
	for key in expected:
		if actual.get(key) != expected[key]: out[key] = [actual.get(key), expected[key]]
	return out

func run(t) -> void:
	var original_sm: Node = t.autoload("SaveManager")
	var previous_dir: String = original_sm.save_dir
	t.on_cleanup(func(): original_sm.save_dir = previous_dir)
	for mode in ["primary", "backup", "raw", "backup_toast_reset", "backup_ui_reset"]:
		await t.start_world()
		var sm: Node = t.autoload("SaveManager")
		var gm: Node = t.autoload("GameManager")
		var eco: Node = t.autoload("EconomyManager")
		var qm: Node = t.autoload("QuestManager")
		var social: Node = t.autoload("SocialManager")
		var bus: Node = t.autoload("EventBus")
		var w: Node = t.world()
		sm.autosave_enabled = false
		sm.save_dir = "user://persistence_save_receipts/"+mode
		DirAccess.make_dir_recursive_absolute(sm.save_dir)
		var secondary: Node2D = w._make_player()
		w._register_player(secondary, 1, 2)
		w.add_child(secondary)
		secondary.set_physics_process(false)
		PlayerRegistry.for_player(&"p1", func():
			_full(eco)
			qm.accept_quest(&"lost_cat")
			qm.complete_quest(&"lost_cat")
			qm.accept_quest(&"intro_lottery")
			qm.to_dict()
			social.add_points(&"baker_maja", 27)
			t.autoload("WardrobeManager").to_dict()
			eco.from_dict(eco.to_dict())
			var row: PlayerState = PlayerRegistry._states[&"p1"]
			row.name = "surviving-secondary"
			row.flags["pb_unrelated"] = 37
			row.player_pos = Vector2(123, 456)
			row.area = &"secondary-area"
			row.gold = 177
			row.hotbar = secondary.hotbar.to_dict())
		PlayerRegistry.for_player(&"p0", func():
			_full(eco)
			qm.accept_quest(&"intro_lottery")
			qm.complete_quest(&"intro_lottery")
			social.add_points(&"baker_maja", 13)
			social.owe_event_items({"stone":2})
			qm.to_dict()
			t.autoload("WardrobeManager").to_dict())
		await t.frames(4) # drain every genuine setup ticket with BOTH packs full
		t.check("PB33_"+mode+"_genuine_quest_social_and_secondary_debts", PlayerRegistry._states[&"p0"].quests.pending_rewards == {&"intro_lottery":{"turnip_seeds":10}} and social._event_owed == {"stone":2} and PlayerRegistry._states[&"p1"].quests.pending_rewards == {&"lost_cat":{"catnip_seeds":3}})
		PlayerRegistry._states[&"p0"].inventory.clear()
		PlayerRegistry._states[&"p1"].inventory.clear()
		var p1_before: Dictionary = PlayerRegistry._states[&"p1"].to_dict()
		var graph_before := _graph(PlayerRegistry._states[&"p1"])
		var social_before: Dictionary = social._rows[&"p1"].duplicate(true)
		var social_graph_before := _graph(social._rows[&"p1"])
		var body: Node2D = w.player
		body.set_physics_process(false)
		body.global_position += Vector2(12, 7)
		var pose := body.global_position
		w._unregister_player(body)
		await t.frames(2)
		t.check("PB24_"+mode+"_surviving_p1_group_local_not_host", PlayerRegistry.local_id() == &"p1" and w.player == null and PlayerRegistry.by_id(&"p1") == secondary)
		var saved: bool = PlayerRegistry.for_player(&"p1", func(): return sm.save_game(0))
		var disk: Dictionary = sm._read_json_file(sm.slot_path(0)).data
		t.check("PB24_"+mode+"_real_disk_host_p0_secondary_complete_graph", saved and disk.players.rows.p0.player_pos == [pose.x, pose.y] and sm._coerce_numbers(disk.players.rows.p1) == sm._coerce_numbers(sm._json_safe(p1_before, "test")) and PlayerRegistry._states[&"p1"].to_dict() == p1_before and _same_graph(PlayerRegistry._states[&"p1"], graph_before), str({"saved":saved,"pose":disk.players.rows.p0.player_pos,"expected_pose":[pose.x,pose.y],"disk_diff":_diff(disk.players.rows.p1,sm._json_safe(p1_before,"test")),"live_diff":_diff(PlayerRegistry._states[&"p1"].to_dict(),p1_before),"graph_same":_same_graph(PlayerRegistry._states[&"p1"],graph_before)}))
		t.check("PB24_"+mode+"_explicit_legacy_social_is_host_not_group_local", disk.social.npcs.get("baker_maja",{}).get("p") == 13 and disk.social.by_player.p1.get("baker_maja",{}).get("p") == 27 and social._rows[&"p1"] == social_before and _same_graph(social._rows[&"p1"], social_graph_before))
		if mode.begins_with("backup"):
			t.check("PB24_"+mode+"_real_backup_created", PlayerRegistry.for_player(&"p1", func(): return sm.save_game(0)) and FileAccess.file_exists(sm.backup_path(0)))
			_write(sm.slot_path(0), "actual damaged primary")
		var resets := []
		var notification_scopes := []
		var replace_model := func():
			PlayerRegistry.reset_states()
			social.reset()
			PlayerRegistry.for_player(&"p0", func():
				_full(eco)
				# No wardrobe/friendship reward that could independently authorize a retry.
				qm.accept_quest(&"intro_lottery")
				qm.complete_quest(&"intro_lottery")
				social.owe_event_items({"stone":3})
				eco.inventory.clear())
			resets.append(true)
		var on_notice := func(title, _message, _icon):
			if title != TranslationServer.translate("NOTIF_LOAD_BACKUP_TITLE"): return
			notification_scopes.append([PlayerRegistry.acting_id(), gm.lifecycle_busy(), sm.save_game(3)])
			if mode == "backup_toast_reset": replace_model.call()
		if mode == "backup_ui_reset":
			var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
			ui.request_page(null, {"id":"mayor_lyra"}, [{"text":"Backup Social/Quest receipt before UI close"}], [{"action":"close"}], {"body":secondary})
			ui.closed.connect(replace_model, CONNECT_ONE_SHOT)
		bus.notification_posted.connect(on_notice)
		var loads := []
		var on_loaded := func(slot): loads.append([slot, PlayerRegistry.acting_id(), gm.lifecycle_busy()])
		bus.load_completed.connect(on_loaded)
		var result: bool = PlayerRegistry.for_player(&"p1", func():
			if mode == "raw":
				bus.load_completed.emit(0)
				return true
			return sm.load_game(0))
		bus.notification_posted.disconnect(on_notice)
		bus.load_completed.disconnect(on_loaded)
		t.check("PB24_"+mode+"_root_result_and_caller_restoration", result and PlayerRegistry._acting_id == &"" and not gm.lifecycle_busy() and loads == [[0, &"p1", mode != "raw"]])
		if mode.begins_with("backup"):
			t.check("PB33_"+mode+"_actual_backup_toast_inside_root", notification_scopes == [[&"p1", true, false]])
		if mode.ends_with("_reset"):
			await t.frames(5)
			t.check("PB33_"+mode+"_old_quest_and_social_receipts_cannot_adopt_new_debt", resets == [true] and PlayerRegistry._states[&"p0"].quests.pending_rewards == {&"intro_lottery":{"turnip_seeds":10}} and social._event_owed == {"stone":3} and PlayerRegistry.for_player(&"p0", func(): return eco.count_item(&"catnip_seeds") == 0 and eco.count_item(&"turnip_seeds") == 0 and eco.count_item(&"stone") == 0), str({"resets":resets,"p0":PlayerRegistry._states[&"p0"].to_dict(),"social":social._event_owed}))
		else:
			var loaded_p1: PlayerState = PlayerRegistry._states[&"p1"]
			var loaded_graph := _graph(loaded_p1)
			var loaded_social_graph := _graph(social._rows[&"p1"])
			var loaded_values: Dictionary = loaded_p1.to_dict()
			t.check("PB24_"+mode+"_immediate_secondary_values_before_reward_flush", loaded_values == p1_before, str(_diff(loaded_values,p1_before)))
			await t.frames(5)
			t.check("PB24_"+mode+"_complete_unrelated_secondary_graph_survives_receipt_and_notification_flush", loaded_p1.to_dict() == p1_before and _same_graph(PlayerRegistry._states[&"p1"], loaded_graph) and social._rows[&"p1"] == social_before and _same_graph(social._rows[&"p1"], loaded_social_graph) and PlayerRegistry._states.size() == 2)
			var delivered: bool = PlayerRegistry.for_player(&"p0", func(): return eco.count_item(&"turnip_seeds") == 10 and eco.count_item(&"stone") == 2 and qm.pending_rewards.is_empty())
			if mode == "raw":
				t.check("PB33_raw_p1_notification_has_no_quest_or_social_commit_authority", not delivered and social._event_owed == {"stone":2} and PlayerRegistry.for_player(&"p0", func(): return eco.count_item(&"turnip_seeds") == 0 and eco.count_item(&"stone") == 0 and qm.pending_rewards == {&"intro_lottery":{"turnip_seeds":10}}))
			else:
				t.check("PB33_"+mode+"_actual_host_quest_social_delivery_once", delivered and social._event_owed.is_empty())
				await t.frames(4)
				t.check("PB33_"+mode+"_no_duplicate_host_delivery", PlayerRegistry.for_player(&"p0", func(): return eco.count_item(&"turnip_seeds") == 10 and eco.count_item(&"stone") == 2))
		if mode == "raw" or mode.ends_with("_reset"):
			# A real subsequent inventory transaction is independently authorized.
			PlayerRegistry.for_player(&"p0", func(): eco.add_item(&"wood",1))
			await t.frames(4)
			var stone_count: int = 3 if mode.ends_with("_reset") else 2
			t.check("PB33_"+mode+"_new_independent_inventory_qualification_delivers_both_debts", social._event_owed.is_empty() and PlayerRegistry.for_player(&"p0", func(): return qm.pending_rewards.is_empty() and eco.count_item(&"turnip_seeds") == 10 and eco.count_item(&"stone") == stone_count))
			PlayerRegistry.for_player(&"p0", func(): eco.add_item(&"wood",1))
			await t.frames(3)
			t.check("PB33_"+mode+"_independent_delivery_still_exactly_once", PlayerRegistry.for_player(&"p0", func(): return eco.count_item(&"turnip_seeds") == 10 and eco.count_item(&"stone") == stone_count))
		await t.start_world()
		sm.autosave_enabled = false
		t.check("PB33_"+mode+"_subsequent_healthy_save", sm.save_game(2))
