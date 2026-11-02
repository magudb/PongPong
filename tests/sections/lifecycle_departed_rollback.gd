extends RefCounted
const SECTION := "lifecycle_departed_rollback"
const TIMEOUT_S := 120.0
class RejectLate extends Node:
	var data := {"v":1,"reject":false}
	var refuse_restore := false
	var rejected := false
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"v":1,"reject":false}
	func from_dict(d: Dictionary) -> bool:
		if d.get("reject",false):
			rejected = true
			return false
		if rejected and refuse_restore: return false
		data = d.duplicate(true)
		return true
func run(t) -> void:
	await _exercise(t)
func run_windowed(t) -> void:
	await _exercise(t)
func _exercise(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	var social: Node = t.autoload("SocialManager")
	var authored: Array = []
	for mode in ["control","depart_rollback","free_rollback","depart_partial","depart_load_same","depart_new_game"]:
		await t.start_world()
		saves.autosave_enabled = false
		saves.save_dir = "user://correction_welcome"
		gm.set_config_override("time.minutes_per_real_second",0.0)
		var late := RejectLate.new()
		t.root.add_child(late)
		saves.register_section("welcome_late",late,999)
		var body: Node2D = t.world()._make_player()
		t.world()._register_player(body,1,2)
		t.world().add_child(body)
		# Establish codec-canonical empty equipment before exact rollback checks;
		# a brand-new secondary profile otherwise gains empty slot keys on decode.
		PlayerRegistry.for_player(&"p1",func():
			var economy: Node = t.autoload("EconomyManager")
			economy.from_dict(economy.to_dict()))
		late.refuse_restore = mode == "depart_partial"
		var payload: Dictionary = saves.gather_payload()
		# A loaded run still owes this welcome. The actual late refusal exercises
		# normal rollback, not a fabricated reset refusal or a cleared guard.
		payload.game.world_flags["mayor_welcome_pending"] = true
		payload.game.world_flags.erase("mayor_welcome_seen")
		if mode in ["depart_rollback","free_rollback","depart_partial"]: payload.welcome_late["reject"] = true
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		var f := FileAccess.open(saves.slot_path(0),FileAccess.WRITE)
		f.store_string(JSON.stringify(payload)); f.close()
		var actor := Npc2D.create({"id":"mayor_lyra","wander":"0"})
		t.world().add_child(actor)
		var body_ref: WeakRef = weakref(body)
		var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
		var ticket: RefCounted = actor.interact(body)
		var keys: Array = ui._lines.map(func(line):return str(line.get("text_key","")))
		if mode == "control": authored = keys.duplicate()
		t.check(mode+"_registered_real_welcome_same_page_eligible",PlayerRegistry.registered_id(body) == &"p1" and actor.is_talking and actor._held and ticket != null and keys == authored and keys.has("DLG_LYRA_GREET_1") and keys.has("DLG_LYRA_LOTTERY") and bool(gm.get_flag(&"mayor_welcome_pending",false)))
		await t.page_to_choices(ui)
		await t.until_game(func():return ui._choice_grace <= 0.0,1.0)
		var before: Dictionary = PlayerRegistry.for_player(&"p0",func():return {"economy":t.autoload("EconomyManager").to_dict().duplicate(true),"quests":t.autoload("QuestManager").to_dict().duplicate(true)})
		var owner_before: Dictionary = PlayerRegistry.for_player(&"p1",func():return {"economy":t.autoload("EconomyManager").to_dict().duplicate(true),"quests":t.autoload("QuestManager").to_dict().duplicate(true)})
		var authority: Array = []
		var observed: Array = []
		var pending_after_return: Array = []
		var flags_after_return: Array = []
		var armed := [true]
		var on_flag := func(flag,value):
			if flag != &"mayor_welcome_seen" or value != true or not armed[0]: return
			armed[0] = false
			if mode.begins_with("depart_") or mode == "free_rollback":
				var owned: Variant = body_ref.get_ref()
				if is_instance_valid(owned):
					t.world()._unregister_player(owned)
					if mode == "free_rollback": owned.free()
			if mode == "depart_load_same":
				# Exact same-valued current model, including the first earned flag,
				# remains a successful replacement and cannot revive old authority.
				payload.game.world_flags = gm.world_flags.duplicate(true)
				var same := FileAccess.open(saves.slot_path(0),FileAccess.WRITE)
				same.store_string(JSON.stringify(payload)); same.close()
			if mode == "depart_new_game": observed.append(gm.try_start_new_game("Welcome reset",gm.character_type))
			elif mode != "control": observed.append(saves.try_load_game(0))
			authority.append({"essential":ui.completion_effects_current(ticket),"optional":ui.optional_allowed(ticket),"departed":not is_instance_valid(body_ref.get_ref()) or PlayerRegistry.registered_id(body_ref.get_ref()) == &""})
			pending_after_return.append(bool(gm.get_flag(&"mayor_welcome_pending",false)))
			flags_after_return.append(gm.world_flags.duplicate(true))
		bus.flag_changed.connect(on_flag)
		if mode == "cancel": t.tap_key(KEY_ESCAPE)
		else:
			ui._buttons[-1].grab_focus()
			t.tap(&"ui_accept")
		await t.frames(3)
		bus.flag_changed.disconnect(on_flag)
		if mode in ["depart_rollback","free_rollback"]:
			t.check(mode+"_genuine_late_failed_load",observed.size() == 1 and not observed[0].ok and observed[0].code == "apply" and late.rejected and pending_after_return == [true],str(observed))
			t.check(mode+"_essential_restored_without_optional_body_authority",authority == [{"essential":true,"optional":false,"departed":true}],str(authority))
			t.check(mode+"_earned_read_clears_pending_after_full_unwind",bool(gm.get_flag(&"mayor_welcome_seen",false)) and not bool(gm.get_flag(&"mayor_welcome_pending",false)))
		elif mode == "depart_partial":
			t.check("partial_rollback_never_revives_essential",observed.size() == 1 and not observed[0].ok and late.rejected and authority == [{"essential":false,"optional":false,"departed":true}] and bool(gm.get_flag(&"mayor_welcome_pending",false)),str(authority))
		elif mode in ["depart_load_same","depart_new_game"]:
			t.check(mode+"_real_replacement_revokes_old_essential",observed.size() == 1 and observed[0].ok and authority == [{"essential":false,"optional":false,"departed":true}] and bool(gm.get_flag(&"mayor_welcome_pending",false)),str(authority))
		else:
			t.check("normal_same_page_read_effects_preserved",pending_after_return == [true] and bool(gm.get_flag(&"mayor_welcome_seen",false)) and not bool(gm.get_flag(&"mayor_welcome_pending",false)))
		var after: Dictionary = PlayerRegistry.for_player(&"p0",func():return {"economy":t.autoload("EconomyManager").to_dict().duplicate(true),"quests":t.autoload("QuestManager").to_dict().duplicate(true)})
		var owner_after: Dictionary = PlayerRegistry.for_player(&"p1",func():return {"economy":t.autoload("EconomyManager").to_dict().duplicate(true),"quests":t.autoload("QuestManager").to_dict().duplicate(true)})
		if mode != "depart_new_game": t.check(mode+"_no_optional_rewards_or_unrelated_owner_writes",before == after and owner_before == owner_after,str({"p0_before":before,"p0_after":after,"p1_before":owner_before,"p1_after":owner_after}))
		t.check(mode+"_no_accounting_lifecycle_or_barrier_leak",not social._accounting_suspended and not gm.lifecycle_busy() and not ui._suspended and ui._barrier == 0 and ui._records.is_empty())
		t.check(mode+"_exact_page_owner_cleanup",not actor.is_talking and not actor._held and not ui._session and not gm.is_modal_open(&"dialogue") and PlayerRegistry._acting_id == &"")
		saves.unregister_section("welcome_late")
		late.free(); actor.free()
		if is_instance_valid(body) and body.is_inside_tree(): t.world()._unregister_player(body)
		await t.frames(2)
	gm.clear_config_overrides()
