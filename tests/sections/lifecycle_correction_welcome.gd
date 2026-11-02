extends RefCounted
const SECTION := "lifecycle_correction_welcome"
const TIMEOUT_S := 120.0
class RejectLate extends Node:
	var data := {"v":1,"reject":false}
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"v":1,"reject":false}
	func from_dict(d: Dictionary) -> bool:
		if d.get("reject",false): return false
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
	for mode in ["control","cancel","new_game","load","rollback"]:
		await t.start_world()
		saves.autosave_enabled = false
		saves.save_dir = "user://correction_welcome"
		gm.set_config_override("time.minutes_per_real_second",0.0)
		var late := RejectLate.new()
		t.root.add_child(late)
		saves.register_section("welcome_late",late,999)
		var payload: Dictionary = saves.gather_payload()
		# A loaded run still owes this welcome. The actual late refusal exercises
		# normal rollback, not a fabricated reset refusal or a cleared guard.
		payload.game.world_flags["mayor_welcome_pending"] = true
		payload.game.world_flags.erase("mayor_welcome_seen")
		if mode == "rollback": payload.welcome_late["reject"] = true
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		var f := FileAccess.open(saves.slot_path(0),FileAccess.WRITE)
		f.store_string(JSON.stringify(payload)); f.close()
		var actor := Npc2D.create({"id":"mayor_lyra","wander":"0"})
		t.world().add_child(actor)
		var body: Node = t.player()
		var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
		var ticket: RefCounted = actor.interact(body)
		var keys: Array = ui._lines.map(func(line):return str(line.get("text_key","")))
		if mode == "control": authored = keys.duplicate()
		t.check(mode+"_registered_real_welcome_same_page_eligible",PlayerRegistry.registered_id(body) == &"p0" and actor.is_talking and actor._held and ticket != null and keys == authored and keys.has("DLG_LYRA_GREET_1") and keys.has("DLG_LYRA_LOTTERY") and bool(gm.get_flag(&"mayor_welcome_pending",false)))
		await t.page_to_choices(ui)
		await t.until_game(func():return ui._choice_grace <= 0.0,1.0)
		var observed: Array = []
		var pending_after_return: Array = []
		var flags_after_return: Array = []
		var armed := [true]
		var on_flag := func(flag,value):
			if flag != &"mayor_welcome_seen" or value != true or not armed[0]: return
			armed[0] = false
			if mode == "new_game": observed.append(gm.try_start_new_game("Welcome reset",gm.character_type))
			elif mode in ["load","rollback"]: observed.append(saves.try_load_game(0))
			pending_after_return.append(bool(gm.get_flag(&"mayor_welcome_pending",false)))
			flags_after_return.append(gm.world_flags.duplicate(true))
		bus.flag_changed.connect(on_flag)
		if mode == "cancel": t.tap_key(KEY_ESCAPE)
		else:
			ui._buttons[-1].grab_focus()
			t.tap(&"ui_accept")
		await t.frames(3)
		bus.flag_changed.disconnect(on_flag)
		if mode in ["new_game","load"]:
			t.check(mode+"_first_flag_observer_real_operation_admitted",observed.size() == 1 and observed[0].ok and pending_after_return == [true] and not gm.lifecycle_busy(),str(observed))
			t.check(mode+"_new_run_unread_preserved_after_old_helper",bool(gm.get_flag(&"mayor_welcome_pending",false)) and not bool(gm.get_flag(&"mayor_welcome_seen",false)) and flags_after_return.size() == 1 and gm.world_flags == flags_after_return[0])
			t.check(mode+"_new_run_no_old_reward_or_progress",not social._accounting_suspended and not actor.is_talking and not ui._session and PlayerRegistry._acting_id == &"")
		elif mode == "rollback":
			t.check("rollback_real_late_rejection_preserves_first_flag",observed.size() == 1 and not observed[0].ok and observed[0].code == "apply" and pending_after_return == [true] and bool(gm.get_flag(&"mayor_welcome_seen",false)))
			t.check("rollback_same_run_read_completion_still_clears_pending",not bool(gm.get_flag(&"mayor_welcome_pending",false)) and not social._accounting_suspended and not gm.lifecycle_busy())
		elif mode == "control":
			t.check("normal_same_page_read_effects_preserved",pending_after_return == [true] and bool(gm.get_flag(&"mayor_welcome_seen",false)) and not bool(gm.get_flag(&"mayor_welcome_pending",false)))
		else:
			t.check("cancel_same_page_owes_unread_without_seen",pending_after_return.is_empty() and bool(gm.get_flag(&"mayor_welcome_pending",false)) and not bool(gm.get_flag(&"mayor_welcome_seen",false)))
		t.check(mode+"_exact_page_owner_cleanup",not actor.is_talking and not actor._held and not ui._session and not gm.is_modal_open(&"dialogue") and PlayerRegistry._acting_id == &"")
		saves.unregister_section("welcome_late")
		late.free(); actor.free()
	gm.clear_config_overrides()
