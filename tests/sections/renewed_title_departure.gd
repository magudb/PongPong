extends RefCounted
const SECTION := "renewed_title_departure"
const TIMEOUT_S := 180.0
class Reject extends Node:
	func validate_dict(_data: Dictionary) -> bool: return true
	func to_dict() -> Dictionary: return {"reject":false}
	func reset() -> void: pass
	func from_dict(data: Dictionary) -> bool: return not data.get("reject",false)

class PhaseObserver extends Node:
	var callback: Callable
	func _notification(what: int) -> void:
		if what == NOTIFICATION_UNPAUSED and callback.is_valid():
			var once := callback
			callback = Callable()
			once.call()

func run(t) -> void:
	for mode in ["modal","phase","modal_confirm","ordinary","cancel","accept","queue","load","rollback"]:
		var path: String = ProjectSettings.globalize_path("user://renewed-title-"+mode+".json")
		var child: Dictionary = t.run_godot_script("res://tests/renewed_title_departure_driver.gd",["--mode="+mode,"--report="+path])
		var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		t.check("RT_"+mode+"_actual_child_completed_cleanly", child.code == 0 and report is Dictionary and report.get("completed",false) and report.get("finalized",false) and report.get("success",false))
		if report is Dictionary:
			for id in report.get("checks",{}): t.check("RT_"+mode+"_"+id,report.checks[id])

func run_driver(d) -> void:
	load("res://scripts/ui/pause_menu.gd").auto_pause = false
	var gm: Node = d.root.get_node("GameManager")
	var sm: Node = d.root.get_node("SaveManager")
	var bus: Node = d.root.get_node("EventBus")
	var opened: Dictionary = gm.try_start_new_game_attached(d.root,"Title origin",gm.CharacterType.ANIMAL,"Title farm",&"",false,Callable(),true)
	var w: Node = opened.get("world")
	for frame in 1200:
		if is_instance_valid(w) and w.ready_for_play and not gm.lifecycle_busy(): break
		await d.process_frame
	d.check("01_real_origin_world_ready",opened.ok and is_instance_valid(w) and w.ready_for_play and not gm.lifecycle_busy())
	if not is_instance_valid(w) or not w.ready_for_play: return
	gm.set_flag(gm.FLAG_INTRO_PENDING,false)
	sm.autosave_enabled = false
	sm.save_dir = "user://renewed-title/"+d.mode
	var pause: Control = w.game_ui.get_screen(&"pause_menu")
	pause.open()
	await d.process_frame
	await d.process_frame
	var world_ref: WeakRef = weakref(w)
	var scene_ref: WeakRef = weakref(d.current_scene)
	var pause_ref: WeakRef = weakref(pause)
	var original: Variant = PlayerRegistry._states[&"p0"]
	var saved := []
	var save_observer := func(slot):
		if slot == sm.AUTO_SLOT: saved.append(sm._read_json_file(sm.slot_path(sm.AUTO_SLOT)).get("state") == "ok")
	bus.save_completed.connect(save_observer)
	var reached := []
	var successor := []
	var starting_gold := []
	var focus := []
	var replace := func():
		reached.append(true)
		PlayerRegistry.reset_states() # supported raw supersession; admitted new_game busy refusal is NOT this test
		starting_gold.append(PlayerRegistry._states[&"p0"].gold)
		EconomyManager.add_gold(37)
		successor.append(PlayerRegistry._states[&"p0"])
		pause.close()
		pause.open()
		focus.append(pause._focus_gen)
		if d.mode == "modal_confirm": UiConfirm.ask(pause,"NOTIF_SAVE_FAILED_TITLE","PAUSE_SAVE_FAILED_CONFIRM","NAV_OK")
	var modal_observer := func(stack):
		if stack.is_empty() and reached.is_empty(): replace.call()
	var watcher := PhaseObserver.new()
	watcher.process_mode = Node.PROCESS_MODE_PAUSABLE
	d.root.add_child(watcher)
	if d.mode in ["modal","modal_confirm"]: bus.modal_changed.connect(modal_observer)
	if d.mode == "phase": watcher.callback = replace
	if d.mode == "queue":
		bus.modal_changed.connect(func(stack):
			if stack.is_empty() and reached.is_empty():
				reached.append(true)
				pause.queue_free(),CONNECT_ONE_SHOT)
	var reject := Reject.new()
	var payload := {}
	var accounting: Variant = d.root.get_node("SocialManager")._accounting_world
	if d.mode == "load": d.check("12_real_same_valued_load_slot",sm.save_game(2))
	if d.mode == "rollback":
		d.root.add_child(reject)
		sm.register_section("renewed_title_reject",reject,999)
		payload = sm.gather_payload()
		payload.renewed_title_reject.reject = true
	if d.mode in ["cancel","accept","load","rollback"]: DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	pause._leave(false) # REAL original production entry, autosave and actual SceneTree departure
	if d.mode in ["cancel","accept","load","rollback"]:
		for frame in 3: await d.process_frame
		var dialogs: Array = pause.find_children("*","UiConfirm",true,false)
		d.check("02_genuine_failed_save_question",dialogs.size() == 1 and pause._leaving and not gm.lifecycle_busy() and saved.is_empty())
		if d.mode == "load":
			var loaded: bool = sm.load_game(2)
			d.check("13_successful_equal_load_is_replacement",loaded and PlayerRegistry._states[&"p0"] != original and d.root.get_node("SocialManager")._accounting_world != accounting)
		if d.mode == "rollback":
			var applied: Dictionary = sm._apply_payload(payload)
			d.check("14_complete_failed_rollback_restores_exact_origin",not applied.ok and PlayerRegistry._states[&"p0"] == original and d.root.get_node("SocialManager")._accounting_world == accounting)
		if dialogs.size() == 1:
			if d.mode in ["accept","load","rollback"]: dialogs[0]._ok_button.pressed.emit()
			else: dialogs[0]._cancel_button.pressed.emit()
		DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	if bus.modal_changed.is_connected(modal_observer): bus.modal_changed.disconnect(modal_observer)
	bus.save_completed.disconnect(save_observer)
	for frame in 8: await d.process_frame
	if d.mode in ["modal","phase","modal_confirm"]:
		d.check("02_callback_replaced_exact_row_and_earned_progress",reached == [true] and successor.size() == 1 and successor[0] != original and PlayerRegistry._states[&"p0"] == successor[0] and successor[0].gold == int(starting_gold[0]) + 37)
		d.check("03_old_stack_retains_world_scene_and_fresh_pause",world_ref.get_ref() != null and scene_ref.get_ref() == d.current_scene and pause_ref.get_ref() != null and pause_ref.get_ref().is_open() and gm.is_modal_open(&"pause") and d.paused)
		d.check("04_committed_save_stays_true_cleanup_is_exact",saved == [true] and not gm.lifecycle_busy() and (pause_ref.get_ref() == null or not pause_ref.get_ref()._leaving))
		if world_ref.get_ref() != null and pause_ref.get_ref() != null:
			d.check("05_fresh_focus_and_row_alias_preserved",pause_ref.get_ref()._focus_gen == focus[0] and PlayerRegistry._states[&"p0"] == successor[0])
			if d.mode == "modal_confirm":
				var questions: Array = pause_ref.get_ref().find_children("*","UiConfirm",true,false)
				d.check("09_fresh_real_confirm_survives_old_cleanup",questions.size() == 1 and questions[0].is_open() and gm.is_modal_open(&"confirm") and gm.top_modal() == &"confirm")
				if questions.size() == 1: questions[0]._cancel_button.pressed.emit()
				for frame in 3: await d.process_frame
				d.check("10_fresh_confirm_cancel_releases_only_itself",not gm.is_modal_open(&"confirm") and pause_ref.get_ref().is_open() and not pause_ref.get_ref()._leaving)
			# A genuine scene handoff attaches the successor model without resetting
			# its earned state. The obsolete World itself must remain unsaveable.
			EconomyManager.add_gold(5)
			d.check("06_later_successor_economic_progress",successor[0].gold == int(starting_gold[0]) + 42 and not w.persistence_ready())
			pause_ref.get_ref().close()
			var next: int = d.change_scene_to_file("res://scenes/main/world.tscn")
			for frame in 1200:
				var current: Node = PlayerRegistry.world(d)
				if current != null and current != world_ref.get_ref() and current.ready_for_play and not gm.lifecycle_busy(): break
				await d.process_frame
			var fresh: Node = PlayerRegistry.world(d)
			d.check("07_next_real_world_admitted",next == OK and fresh != null and fresh.ready_for_play and fresh.persistence_ready() and not gm.lifecycle_busy() and PlayerRegistry._states[&"p0"] == successor[0] and successor[0].gold == int(starting_gold[0]) + 42)
			if fresh != null:
				var next_pause: Control = fresh.game_ui.get_screen(&"pause_menu")
				next_pause.open()
				next_pause._leave(false)
				for frame in 8: await d.process_frame
				d.check("08_next_real_save_and_title_progress",d.current_scene != null and d.current_scene.scene_file_path == "res://scenes/main/main_menu.tscn" and not gm.lifecycle_busy() and sm.inspect_slot(sm.AUTO_SLOT).state == &"ok" and PlayerRegistry._states[&"p0"] == successor[0])
				var disk: Dictionary = sm._read_json_file(sm.slot_path(sm.AUTO_SLOT))
				d.check("11_successor_earned_progress_in_next_actual_save",disk.get("state") == "ok" and int(disk.get("data",{}).get("players",{}).get("rows",{}).get("p0",{}).get("gold",-1)) == int(starting_gold[0]) + 42)
	elif d.mode in ["ordinary","accept","rollback"]:
		d.check("03_actual_ordinary_title_scene_departure",world_ref.get_ref() == null and d.current_scene != null and d.current_scene.scene_file_path == "res://scenes/main/main_menu.tscn" and gm.current_phase == gm.GamePhase.MENU and not gm.lifecycle_busy() and not d.paused)
		if d.mode == "ordinary": d.check("04_real_original_autosave_committed",saved == [true] and sm.inspect_slot(sm.AUTO_SLOT).state == &"ok")
	elif d.mode == "load":
		d.check("15_loaded_replacement_not_departed_by_old_answer",world_ref.get_ref() != null and d.current_scene == scene_ref.get_ref() and not gm.lifecycle_busy() and not pause_ref.get_ref()._leaving)
	elif d.mode == "cancel":
		d.check("03_cancel_retains_original_world_and_pause",world_ref.get_ref() != null and d.current_scene == scene_ref.get_ref() and pause_ref.get_ref().is_open() and not pause_ref.get_ref()._leaving and gm.is_modal_open(&"pause") and not gm.lifecycle_busy())
	elif d.mode == "queue":
		d.check("03_queued_owner_cannot_depart_world_or_leak_admission",reached == [true] and world_ref.get_ref() != null and d.current_scene == scene_ref.get_ref() and pause_ref.get_ref() == null and not gm.lifecycle_busy())
	if d.mode == "rollback": sm.unregister_section("renewed_title_reject")
	reject.free()
	watcher.queue_free()
	gm.pop_all_modals()
