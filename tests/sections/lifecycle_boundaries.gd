extends RefCounted
const SECTION := "lifecycle_boundaries"
const TIMEOUT_S := 90.0
class Section extends Node:
	var hook: Callable
	var data := {"v":1,"reject":false}
	func to_dict() -> Dictionary:
		if hook.is_valid(): hook.call("snapshot")
		return data.duplicate(true)
	func validate_dict(_d: Dictionary) -> bool:
		if hook.is_valid(): hook.call("validation")
		return true
	func from_dict(d: Dictionary) -> bool:
		if hook.is_valid(): hook.call("apply" if d.get("reject",false) else "rollback_or_success")
		if d.get("reject",false): return false
		data = d.duplicate(true)
		return true
	func reset() -> void:
		if hook.is_valid(): hook.call("section_reset")
		data = {"v":1,"reject":false}
class Saves extends "res://scripts/autoload/save_manager.gd":
	var backup_hook: Callable
	func _inspect_backup(slot: int) -> Dictionary:
		if backup_hook.is_valid(): backup_hook.call("primary_backup_gap")
		return super._inspect_backup(slot)
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	var social: Node = t.autoload("SocialManager")
	saves.autosave_enabled = false
	saves.save_dir = "user://admission_boundaries"
	var section := Section.new()
	t.root.add_child(section)
	saves.register_section("admission_boundaries",section,999)
	var payload: Dictionary = saves.gather_payload()
	var incoming: Dictionary = payload.duplicate(true)
	incoming.admission_boundaries["reject"] = true
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	_write(saves.slot_path(0),incoming)
	_write(saves.backup_path(0),payload)
	var actor := Npc2D.create({"id":"smith_thorin","wander":"0"})
	t.world().add_child(actor)
	actor.interact(t.player())
	var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
	await t.page_to_choices(ui)
	t.check("boundary_real_registered_page_ready",actor.is_talking and actor._held and not ui._buttons.is_empty())
	var seen := {}
	var callback := func(label):
		if not seen.has(label): seen[label] = []
		seen[label].append(_busy_probe(gm,saves,social))
	section.hook = callback
	var notices := func(_a,_b,_c):callback.call("notification")
	var completed := func(_slot):callback.call("load_completed")
	var finished := func(_result):callback.call("ui_finish")
	bus.notification_posted.connect(notices)
	bus.load_completed.connect(completed)
	ui.session_finished.connect(finished)
	var loaded: Dictionary = saves.try_load_game(0)
	section.hook = Callable()
	bus.notification_posted.disconnect(notices)
	bus.load_completed.disconnect(completed)
	ui.session_finished.disconnect(finished)
	actor.free()
	for label in ["validation","snapshot","apply","rollback_or_success","notification","load_completed","ui_finish"]:
		t.check(label + "_root_refusal_has_zero_effects",seen.has(label) and seen[label].all(func(x):return x),str(seen.get(label)))
	t.check("primary_late_failure_good_backup_success_cleanup",loaded.ok and not gm.lifecycle_busy() and not saves._applying and not social._accounting_suspended)
	var probe := Saves.new()
	probe.save_dir = saves.save_dir
	probe.autosave_enabled = false
	t.root.add_child(probe)
	probe.register_section("admission_boundaries",section,999)
	var gaps: Array = []
	probe.backup_hook = func(_label):gaps.append(_busy_probe(gm,probe,social))
	loaded = probe.try_load_game(0)
	t.check("primary_backup_gap_same_unreleased_root",loaded.ok and not gaps.is_empty() and gaps.all(func(x):return x) and not gm.lifecycle_busy())
	probe.free()
	# Missing optional sections still use the trusted reset codec while admitted.
	payload.erase("admission_boundaries")
	section.hook = callback
	loaded = saves._apply_payload(payload)
	section.hook = Callable()
	t.check("trusted_missing_section_reset_inside_root",loaded.ok and seen.has("section_reset") and seen.section_reset.all(func(x):return x))
	var tokens: Array = [null,false,1,"forged",{},[],RefCounted.new()]
	for index in tokens.size():
		var before: Dictionary = gm.to_dict()
		var denied: Dictionary = saves._apply_payload_owned(payload,tokens[index])
		t.check("invalid_participant_variant_%d" % index,not denied.ok and denied.code == "authority" and gm.to_dict() == before and not gm.lifecycle_busy())
	var reset_seen := {}
	var on_flag := func(_flag,_value):
		if gm.lifecycle_busy(): reset_seen["flag"] = _busy_probe(gm,saves,social)
	var on_character := func(_pid,_skin): reset_seen["character"] = _busy_probe(gm,saves,social)
	var on_reset := func(): reset_seen["reset"] = _busy_probe(gm,saves,social)
	bus.flag_changed.connect(on_flag)
	bus.player_character_changed.connect(on_character)
	bus.new_game_started.connect(on_reset)
	gm.try_start_new_game("Root positives",gm.character_type)
	bus.flag_changed.disconnect(on_flag)
	bus.player_character_changed.disconnect(on_character)
	bus.new_game_started.disconnect(on_reset)
	for label in ["flag","character","reset"]:
		t.check("newgame_" + label + "_observer_load_and_reset_busy",reset_seen.get(label,false))
	# Terminal ordinary failure must retain its own error even if a listener recurses.
	var failures: Array = []
	var on_failure := func(_a,_b,_c): failures.append(_busy_probe(gm,saves,social))
	bus.notification_posted.connect(on_failure)
	loaded = saves.try_load_game(-999)
	bus.notification_posted.disconnect(on_failure)
	t.check("ordinary_failure_result_detached_and_terminal_busy",not loaded.ok and loaded.code == "missing" and failures == [true] and not gm.lifecycle_busy())
	loaded["code"] = "edited_copy"
	t.check("result_mutation_never_clobbers_status",saves.last_error.code == "missing")
	saves.unregister_section("admission_boundaries")
	section.free()
func _busy_probe(gm: Node,saves: Node,social: Node) -> bool:
	var token: RefCounted = gm.get("_lifecycle_token") # Internal test seam only.
	var before: Dictionary = _state(gm,saves,social)
	var results := [gm.try_start_new_game("Refused",gm.character_type),gm.try_start_new_game_and_enter("Refused",gm.character_type),gm.try_start_new_game_attached(null,"Refused",gm.character_type),saves.try_load_game(-999),saves.try_load_and_enter(-999),saves.try_continue_latest(),saves.try_reset_metadata(),saves._apply_payload({})]
	var legacy: bool = saves.load_game(-999) or saves.load_and_enter(-999) or saves.continue_latest()
	gm.start_new_game("Refused void",gm.character_type)
	saves.reset()
	return not legacy and results.all(func(r):return not r.ok and r.code == "busy") and before == _state(gm,saves,social) and token == gm.get("_lifecycle_token")
func _state(gm: Node,saves: Node,social: Node) -> Dictionary:
	var ui: Node = saves.get_tree().get_first_node_in_group("dialogue_ui")
	return {"game":gm.to_dict(),"phase":gm.current_phase,"modal":gm.modal_stack(),"paused":gm.get_tree().paused,"error":saves.last_error.duplicate(true),"slot":saves.current_slot,"run":saves.run_id,"pending":saves.pending_world.duplicate(true),"timer":saves._auto_save_timer,"queue":saves._autosave_queued,"applying":saves._applying,"account":social._accounting_world,"suspended":social._accounting_suspended,"reset":social._accounting_reset_serial,"ui":[ui._active,ui._pending,ui._shown,ui._line,ui._suspended,ui._resetting] if ui != null else []}
func _write(path: String,data: Dictionary) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
