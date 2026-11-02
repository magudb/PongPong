extends RefCounted
const SECTION := "consequential_save_callers"
const TIMEOUT_S := 180.0

func run(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var old_dir: String = sm.save_dir
	t.on_cleanup(func():
		sm.save_dir = old_dir
		gm.quit_seam = Callable())
	await _confirmation(t)
	await _committed(t)

func _confirmation(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var social: Node = t.autoload("SocialManager")
	var world: Node = t.world()
	var pause: Control = world.game_ui.get_screen(&"pause_menu")
	pause.open()
	sm.autosave_enabled = false
	sm.save_dir = "user://consequential/confirm"
	t.check("CC01_valid_same_valued_load_slot", sm.save_game(2))
	DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	var codes := []
	gm.quit_seam = func(code): codes.append(code)
	var done := []
	var quit := func():
		await gm.quit_game(21, true, pause)
		done.append(true)
	PlayerRegistry.for_player(&"p1", func(): quit.call())
	t.check("CC13_synchronous_caller_scope_restored_while_actual_confirmation_waits", PlayerRegistry._acting_id == &"" and not gm.lifecycle_busy())
	await t.frames(3)
	var dialogs: Array = pause.find_children("*", "UiConfirm", true, false)
	t.check("CC02_real_failed_autosave_surviving_question", dialogs.size() == 1 and gm._quit_asking and done.is_empty() and not gm.lifecycle_busy())
	var original: Variant = PlayerRegistry._states[&"p0"]
	var run: Variant = social._accounting_world
	var loaded: bool = sm.load_game(2)
	t.check("CC03_real_model_only_same_valued_load_replaces_origin_not_world_or_dialog", loaded and PlayerRegistry._states[&"p0"] != original and social._accounting_world != run and t.world() == world and dialogs.size() == 1 and is_instance_valid(dialogs[0]) and dialogs[0].is_open() and not gm.lifecycle_busy())
	if dialogs.size() == 1: dialogs[0]._ok_button.pressed.emit()
	await t.frames(3)
	t.check("CC04_old_actual_OK_cannot_quit_replacement", done == [true] and codes.is_empty() and not gm._quit_asking and not gm._quitting)
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	codes.clear() # independent future-progress control, not a cascade of CC04
	await gm.quit_game(22, false)
	t.check("CC05_fresh_request_after_stale_confirmation_progresses", codes == [22] and not gm._quit_asking and not gm._quitting)
	for accept in [false, true]:
		await t.start_world()
		sm.autosave_enabled = false
		sm.save_dir = "user://consequential/plain"+str(accept)
		DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
		var ended := []
		var ask := func():
			await gm.quit_game(23)
			ended.append(true)
		ask.call()
		await t.frames(3)
		var host: Node = t.root.find_child("QuitQuestion", true, false)
		var questions: Array = host.find_children("*", "UiConfirm", true, false) if host != null else []
		t.check("CC06_plain_"+str(accept)+"_real_question", questions.size() == 1 and ended.is_empty())
		var before: int = codes.size()
		if questions.size() == 1:
			(questions[0]._ok_button if accept else questions[0]._cancel_button).pressed.emit()
		await t.frames(3)
		t.check("CC07_plain_"+str(accept)+"_decision_preserved", ended == [true] and codes.size() == before + (1 if accept else 0) and not gm._quit_asking and not gm._quitting)
		DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")

func _committed(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	sm.autosave_enabled = false
	sm.save_dir = "user://consequential/commit"
	var codes := []
	gm.quit_seam = func(code): codes.append(code)
	var observations := []
	var supersede := func(slot):
		if slot != sm.AUTO_SLOT: return
		observations.append(FileAccess.file_exists(sm.slot_path(slot)))
		PlayerRegistry.reset_states()
	bus.save_completed.connect(supersede)
	await gm.quit_game(31)
	bus.save_completed.disconnect(supersede)
	t.check("CC08_real_postcommit_raw_replacement_has_actual_saved_bytes", observations == [true] and sm._read_json_file(sm.slot_path(sm.AUTO_SLOT)).get("state") == "ok")
	t.check("CC09_committed_original_bytes_do_not_authorize_successor_quit", codes.is_empty() and not gm._quitting and not gm._quit_asking and not gm.lifecycle_busy())
	codes.clear() # independent ordinary-success control
	await t.start_world()
	sm.autosave_enabled = false
	sm.save_dir = "user://consequential/fresh"
	await gm.quit_game(32)
	t.check("CC10_same_origin_fresh_success_saves_then_quits", codes == [32] and sm.inspect_slot(sm.AUTO_SLOT).state == &"ok" and not gm._quitting)
	var token: RefCounted = gm._begin_lifecycle(self, &"caller_control")
	await gm.quit_game(33, false)
	gm._finish_lifecycle(token,self)
	t.check("CC11_busy_quit_refuses_without_poisoning_next", codes == [32])
	await gm.quit_game(34, false)
	t.check("CC12_next_request_after_busy_progresses", codes == [32,34])
