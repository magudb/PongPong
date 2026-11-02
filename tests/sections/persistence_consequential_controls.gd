extends RefCounted
const SECTION := "persistence_consequential_controls"
const TIMEOUT_S := 180.0
class Reject extends Node:
	var restore_bad := false
	func validate_dict(_d: Dictionary) -> bool: return true
	func to_dict() -> Dictionary: return {"reject":false}
	func reset() -> void: pass
	func from_dict(d: Dictionary) -> bool: return not d.get("reject",false) and not restore_bad

func run(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var previous: String = sm.save_dir
	t.on_cleanup(func(): sm.save_dir = previous; gm.quit_seam = Callable())
	for mode in ["complete", "incomplete"]:
		await t.start_world()
		sm.autosave_enabled = false
		sm.save_dir = "user://consequential/rollback/"+mode
		var reject := Reject.new()
		t.root.add_child(reject)
		sm.register_section("consequential_reject",reject,999)
		var payload: Dictionary = sm.gather_payload()
		payload.consequential_reject.reject = true
		DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
		var codes := []
		gm.quit_seam = func(code): codes.append(code)
		var ended := []
		var ask := func():
			await gm.quit_game(61)
			ended.append(true)
		ask.call()
		await t.frames(3)
		var host: Node = t.root.find_child("QuitQuestion",true,false)
		var dialogs: Array = host.find_children("*","UiConfirm",true,false) if host != null else []
		t.check("CR01_"+mode+"_genuine_failed_save_question_pending", dialogs.size() == 1 and ended.is_empty() and not gm.lifecycle_busy())
		var original: Variant = PlayerRegistry._states[&"p0"]
		var social: Node = t.autoload("SocialManager")
		var run: Variant = social._accounting_world
		reject.restore_bad = mode == "incomplete"
		var applied: Dictionary = sm._apply_payload(payload)
		t.check("CR02_"+mode+"_real_failed_rollback_exact_identity_control", not applied.ok and (social._accounting_world == run) == (mode == "complete") and (PlayerRegistry._states[&"p0"] == original) == (mode == "complete") and not gm.lifecycle_busy())
		if dialogs.size() == 1: dialogs[0]._ok_button.pressed.emit()
		await t.frames(3)
		t.check("CR03_"+mode+"_only_authenticated_complete_rollback_keeps_old_decision", ended == [true] and codes == ([61] if mode == "complete" else []) and not gm._quit_asking and not gm._quitting)
		sm.unregister_section("consequential_reject")
		reject.free()
		DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	await t.start_world()
	sm.autosave_enabled = false
	sm.save_dir = "user://consequential/immutable-bool"
	var bus: Node = t.autoload("EventBus")
	var saved := []
	var replacement := func(_slot):
		saved.append(FileAccess.file_exists(sm.slot_path(sm.AUTO_SLOT)))
		PlayerRegistry.reset_states()
	bus.save_completed.connect(replacement)
	var committed: bool = sm.autosave()
	bus.save_completed.disconnect(replacement)
	t.check("CR04_real_postcommit_autosave_bool_still_TRUE_for_actual_original_bytes", committed and saved == [true] and sm._read_json_file(sm.slot_path(sm.AUTO_SLOT)).get("state") == "ok")
	await t.go_menu()
	var codes := []
	gm.quit_seam = func(code): codes.append(code)
	t.check("CR05_same_origin_menu_standalone_save_policy", await gm.save_before_quit())
	await gm.quit_game(62)
	t.check("CR06_same_origin_menu_quit_progresses_without_world", codes == [62] and t.world() == null and not gm._quit_asking and not gm._quitting)
	var keep: Dictionary = PlayerRegistry._states
	PlayerRegistry._states = {}
	var okay: bool = await gm.save_before_quit()
	await gm.quit_game(63)
	t.check("CR07_no_world_no_profile_bootstrap_quit_does_not_create_default_row", okay and codes == [62,63] and PlayerRegistry._states.is_empty())
	PlayerRegistry._states = keep
