extends RefCounted
const SECTION := "persistence_write_callbacks"
const TIMEOUT_S := 180.0
class Probe extends "res://scripts/autoload/save_manager.gd":
	var at := ""
	var callback: Callable
	func _store_text(file: FileAccess, text: String) -> void:
		super._store_text(file, text)
		if at == "store" and callback.is_valid(): callback.call()
	func _replace_file(source: String, destination: String) -> Error:
		var result: Error = super._replace_file(source, destination)
		if at == "commit" and source.ends_with(".tmp") and callback.is_valid(): callback.call()
		return result
class Validator extends Node:
	var callback: Callable
	func to_dict() -> Dictionary: return {"v":1}
	func from_dict(_d: Dictionary) -> bool: return true
	func reset() -> void: pass
	func validate_dict(_d: Dictionary) -> bool:
		if callback.is_valid(): callback.call()
		return true
func run(t) -> void:
	for mode in ["store", "commit", "validator"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		t.autoload("SaveManager").autosave_enabled = false
		var p := Probe.new()
		p.save_dir = "user://persistence_write_callbacks/"+mode
		p.autosave_enabled = false
		t.root.add_child(p)
		var validator := Validator.new()
		t.root.add_child(validator)
		p.register_section("pb_validator", validator, 999)
		if mode == "validator": t.check("PB29_valid_primary_before_validation_probe", p.save_game(0))
		var old_hash: String = FileAccess.get_sha256(p.slot_path(0)) if FileAccess.file_exists(p.slot_path(0)) else ""
		var reached := []
		var trigger := func():
			if not reached.is_empty(): return
			reached.append(gm.lifecycle_busy())
			reached.append(p.save_game(2))
			PlayerRegistry.reset_states()
		p.at = mode
		p.callback = trigger
		if mode == "validator": validator.callback = trigger
		var saved: bool = p.save_game(0)
		t.check("PB29_"+mode+"_real_callback_busy_refusal", reached == [true, false])
		t.check("PB30_"+mode+"_durability_bool", saved == (mode == "commit"))
		if mode != "commit":
			var after_hash: String = FileAccess.get_sha256(p.slot_path(0)) if FileAccess.file_exists(p.slot_path(0)) else ""
			t.check("PB29_"+mode+"_no_obsolete_primary_or_backup", after_hash == old_hash and not FileAccess.file_exists(p.backup_path(0)))
		else: t.check("PB30_commit_raw_callback_keeps_actual_bytes", FileAccess.file_exists(p.slot_path(0)))
		t.check("PB29_"+mode+"_root_released_and_no_stale_status", not gm.lifecycle_busy() and p.current_slot == (-1 if mode != "validator" else 0) and p.last_error.is_empty())
		p.free(); validator.free()
