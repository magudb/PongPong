extends RefCounted
const SECTION := "lifecycle_public_admission"
const TIMEOUT_S := 90.0
class CountingSaves extends "res://scripts/autoload/save_manager.gd":
	var discoveries := 0
	var validations := 0
	func get_latest_slot() -> int:
		discoveries += 1
		return NO_SLOT
	func inspect_slot(slot: int) -> Dictionary:
		validations += 1
		return super.inspect_slot(slot)
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	saves.autosave_enabled = false
	saves.save_dir = "user://admission_public"
	t.check("idle_manual_save_control", saves.save_game(0) and saves.save_game(0))
	var probe := CountingSaves.new()
	probe.save_dir = "user://admission_probe"
	probe.autosave_enabled = false
	probe.world_scene = "res://missing-admission-world.tscn"
	t.root.add_child(probe)
	var messages: Array = []
	var notify := func(a, b, c): messages.append([a,b,c])
	bus.notification_posted.connect(notify)
	var observed: Array = []
	var before_run: String = saves.run_id
	var on_new := func():
		var before: Dictionary = _state(gm, saves)
		var count: int = messages.size()
		var results := []
		results.append(_result(saves, "try_load_game", "load_game", [-999]))
		results.append(_result(probe, "try_load_and_enter", "load_and_enter", [-999]))
		results.append(_result(probe, "try_continue_latest", "continue_latest", []))
		results.append(saves.try_reset_metadata())
		results.append(gm.try_start_new_game("Refused", gm.character_type))
		gm.start_new_game("Refused void", gm.character_type)
		saves.reset()
		var manual: bool = saves.save_game(0)
		var auto: bool = saves.autosave()
		saves.delete_save(0)
		saves._on_day_ended(1, &"foraar")
		saves._process(1.0)
		var after: Dictionary = _state(gm, saves)
		observed.append({"before":before,"after":after,"results":results,"manual":manual,"auto":auto,"notifications":messages.size()-count,"discoveries":probe.discoveries,"validations":probe.validations})
	bus.new_game_started.connect(on_new, CONNECT_ONE_SHOT)
	var reset_result: Dictionary = gm.try_start_new_game("Accepted", gm.character_type)
	bus.notification_posted.disconnect(notify)
	t.check("normal_reset_synchronous_and_metadata_bridge_once", reset_result.ok and gm.player_name == "Accepted" and saves.run_id != before_run and observed.size() == 1 and observed[0].before.run_id == saves.run_id and not gm.lifecycle_busy())
	t.check("terminal_observer_all_roots_busy", observed[0].results.all(func(r): return not r.ok and r.code == "busy"), str(observed[0].results))
	t.check("busy_before_scene_validation_and_continue_discovery", observed[0].discoveries == 0 and observed[0].validations == 0)
	t.check("refused_writes_no_file_status_timer_or_model_effects", observed[0].before == observed[0].after and not observed[0].manual and not observed[0].auto and observed[0].notifications == 0, str(observed[0]))
	# A pre-existing queued system tick retires only its queue bit while busy.
	var token: RefCounted = gm._begin_lifecycle(self, &"tick_control")
	saves._autosave_queued = true
	var before_tick: Dictionary = _state(gm,saves)
	saves._run_queued_autosave()
	before_tick["queued"] = false
	t.check("queued_tick_dropped_without_write_or_retry", not saves._autosave_queued and before_tick == _state(gm,saves))
	var quit_ok: bool = await gm.save_before_quit()
	t.check("busy_quit_not_disk_failure_confirmation", not quit_ok and not gm._quit_asking and t.root.find_child("QuitQuestion",true,false) == null)
	gm._finish_lifecycle(token,self)
	t.check("idle_load_next_deliberate_operation", saves.try_load_game(0).ok and not gm.lifecycle_busy())
	probe.free()
func _result(node: Node, sibling: String, legacy: String, args: Array) -> Dictionary:
	if node.has_method(sibling): return node.callv(sibling,args)
	return {"ok":bool(node.callv(legacy,args)),"code":"legacy"}
func _state(gm: Node, saves: Node) -> Dictionary:
	var paths := {}
	for slot in saves.all_slots():
		for path in [saves.slot_path(slot),saves.backup_path(slot),saves.slot_path(slot)+".tmp",saves.slot_path(slot)+".old"]:
			if path != "": paths[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return {"model":gm.to_dict(),"phase":gm.current_phase,"modals":gm.modal_stack(),"paused":gm.get_tree().paused,"slot":saves.current_slot,"run_id":saves.run_id,"error":saves.last_error.duplicate(true),"pending":saves.pending_world.duplicate(true),"timer":saves._auto_save_timer,"queued":saves._autosave_queued,"failing":saves.save_failing,"paths":paths}
