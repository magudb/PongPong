extends RefCounted
const SECTION := "lifecycle_unavailable"
const TIMEOUT_S := 30.0
func run(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	saves.autosave_enabled = false
	var before: Dictionary = saves.last_error.duplicate(true)
	var run: String = saves.run_id
	t.root.remove_child(gm)
	var loaded: Dictionary = saves.try_load_game(-999)
	var reset: Dictionary = saves.try_reset_metadata()
	t.root.add_child(gm)
	t.check("missing_owner_load_fails_closed_without_status_write",not loaded.ok and loaded.code == "unavailable" and saves.last_error == before)
	t.check("missing_owner_metadata_reset_cannot_run_unlocked",not reset.ok and reset.code == "unavailable" and saves.run_id == run)
	t.check("restored_owner_next_operation_accepted",gm.try_start_new_game("Restored owner",gm.character_type).ok and not gm.lifecycle_busy())
