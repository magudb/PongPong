extends RefCounted
const SECTION := "persistence_consequential_cleanup"
const TIMEOUT_S := 180.0

func run(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var previous: String = sm.save_dir
	t.on_cleanup(func(): sm.save_dir = previous; gm.quit_seam = Callable())
	await _new_game(t)
	await _successor_question(t)
	await _pause_future(t)
	await _late_question(t)

func _late_question(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var pause: Control = t.world().game_ui.get_screen(&"pause_menu")
	pause.open()
	sm.autosave_enabled = false
	sm.save_dir = "user://consequential/late-question"
	DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	var additions := []
	var codes := []
	gm.quit_seam = func(code): codes.append(code)
	var observer := func(node):
		if not node is UiConfirm: return
		additions.append(weakref(node))
		if additions.size() == 1:
			PlayerRegistry.reset_states()
			gm.quit_game(82,true,pause)
	t.tree.node_added.connect(observer)
	gm.quit_game(81,true,pause)
	t.tree.node_added.disconnect(observer)
	await t.frames(3)
	var dialogs: Array = pause.find_children("*","UiConfirm",true,false)
	t.check("CQ05_add_child_callback_actual_successor_question_not_old_hidden_node", additions.size() == 2 and additions[0].get_ref() == null and dialogs.size() == 1 and dialogs[0].is_open() and gm._quit_asking and gm.is_modal_open(&"confirm") and codes.is_empty())
	for dialog in dialogs:
		if dialog.is_open(): dialog._cancel_button.pressed.emit()
	await t.frames(3)
	t.check("CQ06_late_old_acquisition_cannot_clobber_successor_cleanup", not gm._quit_asking and not gm._quitting and not gm.is_modal_open(&"confirm") and codes.is_empty())
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	pause.close()

func _pause_future(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var pause: Control = t.world().game_ui.get_screen(&"pause_menu")
	pause.open()
	sm.autosave_enabled = false
	sm.save_dir = "user://consequential/pause-future"
	DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	var codes := []
	gm.quit_seam = func(code): codes.append(code)
	pause._leave(true)
	await t.frames(3)
	var initial: Array = pause.find_children("*","UiConfirm",true,false)
	t.check("CP01_pause_real_quit_delegates_to_original_confirmation", initial.size() == 1 and pause._leaving and gm._quit_asking)
	var result: Dictionary = gm.try_start_new_game("Pause successor",gm.CharacterType.ANIMAL,"retained GameUI")
	pause.open()
	pause._leave(true)
	await t.frames(3)
	var current: Node = null
	for dialog in pause.find_children("*","UiConfirm",true,false):
		if dialog.is_open() and (initial.is_empty() or dialog != initial[0]): current = dialog
	t.check("CP02_new_pause_quit_not_locked_out_by_old_pending_coroutine", result.ok and current != null and gm._quit_asking and pause._leaving and codes.is_empty())
	if current != null: current._cancel_button.pressed.emit()
	elif initial.size() == 1 and is_instance_valid(initial[0]): initial[0]._cancel_button.pressed.emit()
	await t.frames(3)
	t.check("CP03_old_tail_does_not_clobber_new_pause_request_cleanup", not pause._leaving and not gm._quit_asking and not gm._quitting and codes.is_empty())
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	pause.close()

func _new_game(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var world: Node = t.world()
	sm.autosave_enabled = false
	sm.save_dir = "user://consequential/lc-r4"
	DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	var codes := []
	gm.quit_seam = func(code): codes.append(code)
	var done := []
	var ask := func():
		await gm.quit_game(41)
		done.append(true)
	ask.call()
	await t.frames(3)
	var host: Node = t.root.find_child("QuitQuestion",true,false)
	var dialogs: Array = host.find_children("*","UiConfirm",true,false) if host != null else []
	t.check("LC_R4_01_real_QuitQuestion_after_genuine_autosave_failure", dialogs.size() == 1 and gm._quit_asking and done.is_empty() and not gm.lifecycle_busy())
	var old: Variant = PlayerRegistry._states[&"p0"]
	var result: Dictionary = gm.try_start_new_game("LC-R4 replacement", gm.CharacterType.ANIMAL, "same scene")
	t.check("LC_R4_02_supported_model_only_new_game_preserves_actual_question_and_GameUI", result.ok and PlayerRegistry._states[&"p0"] != old and t.world() == world and host.is_inside_tree() and dialogs.size() == 1 and dialogs[0].is_open() and not gm.lifecycle_busy() and PlayerRegistry.acting_id() == &"p0")
	var answers := []
	if dialogs.size() == 1:
		dialogs[0].answered.connect(func(answer): answers.append(answer))
		dialogs[0]._ok_button.pressed.emit()
	await t.frames(3)
	t.check("LC_R4_03_original_answered_true_has_no_successor_terminal_or_shutdown", answers == [true] and done == [true] and codes.is_empty() and not gm._quit_asking and not gm._quitting and not t.autoload("AudioManager")._shutting_down and not gm.lifecycle_busy())
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	codes.clear()
	await t.start_world()
	sm.autosave_enabled = false
	sm.save_dir = "user://consequential/lc-r4-next"
	await gm.quit_game(42)
	t.check("LC_R4_04_later_healthy_actual_save_quit_progress", codes == [42] and sm.inspect_slot(sm.AUTO_SLOT).state == &"ok" and PlayerRegistry.acting_id() == &"p0")

func _successor_question(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var pause: Control = t.world().game_ui.get_screen(&"pause_menu")
	pause.open()
	sm.autosave_enabled = false
	sm.save_dir = "user://consequential/cleanup"
	DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	var codes := []
	gm.quit_seam = func(code): codes.append(code)
	gm.quit_game(51,true,pause)
	await t.frames(3)
	var dialogs: Array = pause.find_children("*","UiConfirm",true,false)
	t.check("CQ01_original_actual_confirmation", dialogs.size() == 1 and gm._quit_asking)
	if dialogs.size() != 1: return
	var old: Node = dialogs[0]
	var reached := []
	old.visibility_changed.connect(func():
		if old.visible or not reached.is_empty(): return
		reached.append(true)
		PlayerRegistry.reset_states()
		gm.quit_game(52,true,pause))
	old._ok_button.pressed.emit()
	await t.frames(3)
	dialogs = pause.find_children("*","UiConfirm",true,false)
	var current: Node = null
	for dialog in dialogs:
		if dialog.is_open(): current = dialog
	t.check("CQ02_old_visible_false_cleanup_cannot_pop_successor_confirm_or_quit_lock", reached == [true] and current != null and gm.is_modal_open(&"confirm") and gm._quit_asking and codes.is_empty() and not gm.lifecycle_busy())
	if current != null: current._cancel_button.pressed.emit()
	await t.frames(3)
	t.check("CQ03_successor_real_cancel_releases_only_its_resources", not gm._quit_asking and not gm._quitting and not gm.is_modal_open(&"confirm") and codes.is_empty())
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	await gm.quit_game(53,false)
	t.check("CQ04_new_request_after_nested_cleanup_progresses", codes == [53])
