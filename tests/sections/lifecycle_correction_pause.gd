extends RefCounted
const SECTION := "lifecycle_correction_pause"
const TIMEOUT_S := 120.0
func run(t) -> void:
	await _exercise(t)
func run_windowed(t) -> void:
	await _exercise(t)
	await t.capture("return_title_controls")
func _exercise(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	saves.autosave_enabled = false
	saves.save_dir = "user://correction_pause"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var pause: Control = t.world().game_ui.get_screen(&"pause_menu")
	var token: RefCounted = gm._begin_lifecycle(self,&"pause_busy")
	var before: Dictionary = _state(gm,saves,pause)
	pause._leave(false) # Direct production handler must refuse too, not just its opener.
	t.check("busy_direct_title_no_status_ui_model_or_file_effects",before == _state(gm,saves,pause) and not pause._leaving and gm.top_modal() != UiConfirm.MODAL)
	if gm.top_modal() == UiConfirm.MODAL:
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
	t.check("busy_pause_opening_guards",not pause._hotkey_open_allowed() and not UiNav.world_is_free() and not pause.auto_open())
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("busy_real_pause_hotkey_refused",not pause.is_open() and not gm.is_modal_open())
	if pause.is_open(): pause.close()
	gm._finish_lifecycle(token,self)
	t.world().ready_for_play = false
	t.check("unready_pause_opening_guards",not pause._hotkey_open_allowed() and not UiNav.world_is_free())
	t.world().ready_for_play = true
	await t.frames(2)
	# Genuine disk refusal still asks. Cancel is harmless and permits a later try.
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var blocked: String = saves.slot_path(saves.AUTO_SLOT) + ".tmp"
	DirAccess.make_dir_recursive_absolute(blocked)
	pause.open()
	await t.frames(3)
	_press_title(t,pause)
	await t.frames(3)
	t.check("idle_disk_failure_still_confirms_cancel_default",gm.top_modal() == UiConfirm.MODAL and pause._leaving and PlayerRegistry.acting_id() == &"p0")
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	t.check("idle_disk_failure_cancel_keeps_world_and_menu",t.world() != null and pause.is_open() and not pause._leaving and gm.top_modal() == &"pause")
	_press_title(t,pause)
	await t.frames(3)
	t.check("confirmation_resume_fixture_is_real_disk_failure",gm.top_modal() == UiConfirm.MODAL and pause._leaving)
	var old_world: WeakRef = weakref(t.world())
	var old_pause: WeakRef = weakref(pause)
	token = gm._begin_lifecycle(self,&"confirmation_busy")
	t.tap_key(KEY_LEFT)
	t.tap_key(KEY_ENTER)
	await t.frames(4)
	t.check("confirmation_accept_while_busy_cannot_leave",old_world.get_ref() == t.world() and t.world() != null and old_pause.get_ref() != null and gm.top_modal() == &"pause" and gm.current_phase == gm.GamePhase.PAUSED)
	t.check("confirmation_refusal_retires_only_pending_intent",old_pause.get_ref() != null and not old_pause.get_ref()._leaving and gm.lifecycle_busy() and PlayerRegistry.acting_id() == &"p0")
	gm._finish_lifecycle(token,self)
	DirAccess.remove_absolute(blocked)
	if t.world() == null:
		await t.start_world()
		pause = t.world().game_ui.get_screen(&"pause_menu")
	else:
		pause = old_pause.get_ref()
	# A departed physical body cannot authorize a title transition after the await.
	DirAccess.make_dir_recursive_absolute(blocked)
	pause.open()
	await t.frames(3)
	_press_title(t,pause)
	await t.frames(3)
	t.check("departed_body_confirm_fixture",gm.top_modal() == UiConfirm.MODAL)
	var body: Node = t.player()
	var parent: Node = body.get_parent()
	parent.remove_child(body)
	t.tap_key(KEY_LEFT)
	t.tap_key(KEY_ENTER)
	await t.frames(4)
	t.check("confirmation_departed_body_cannot_leave",t.world() != null and gm.top_modal() == &"pause")
	if is_instance_valid(parent): parent.add_child(body)
	else: body.free()
	DirAccess.remove_absolute(blocked)
	if t.world() == null:
		await t.start_world()
	pause = t.world().game_ui.get_screen(&"pause_menu")
	# A separate deliberate idle action still works, through the actual menu row.
	pause.open()
	await t.frames(3)
	_press_title(t,pause)
	await t.frames(5)
	t.check("next_deliberate_idle_title_saves_and_enters_menu",t.tree.current_scene.scene_file_path == "res://scenes/main/main_menu.tscn" and saves.has_save(saves.AUTO_SLOT) and not gm.is_modal_open() and not gm.lifecycle_busy())
	await t.start_world()
	pause = t.world().game_ui.get_screen(&"pause_menu")
	DirAccess.make_dir_recursive_absolute(blocked)
	pause.open()
	await t.frames(3)
	_press_title(t,pause)
	await t.frames(3)
	t.check("idle_disk_accept_fixture",gm.top_modal() == UiConfirm.MODAL)
	t.tap_key(KEY_LEFT)
	t.tap_key(KEY_ENTER)
	await t.frames(5)
	t.check("idle_disk_failure_accept_still_enters_title",t.tree.current_scene.scene_file_path == "res://scenes/main/main_menu.tscn" and not gm.is_modal_open())
	DirAccess.remove_absolute(blocked)
func _press_title(t,pause: Control) -> void:
	var button: Button = pause._rows.filter(func(row):return row.name == &"QuitButton").front()
	button.grab_focus()
	t.tap_key(KEY_ENTER)
func _state(gm: Node,saves: Node,pause: Control) -> Dictionary:
	return {"game":gm.to_dict(),"phase":gm.current_phase,"modals":gm.modal_stack(),"paused":gm.get_tree().paused,"leaving":pause._leaving,"open":pause.is_open(),"error":saves.last_error.duplicate(true),"timer":saves._auto_save_timer,"run":saves.run_id,"failing":saves.save_failing,"files":DirAccess.get_files_at(saves.save_dir)}
