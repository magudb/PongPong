extends Node
## JSON-based save/load. One folder per slot for easy debugging.

const SAVE_DIR := "user://saves"
const SAVE_FILE := "save_%d.json"
const BACKUP_FILE := "save_%d.bak.json"

var current_slot: int = 0
var auto_save_interval_seconds: float = 300.0
var _auto_save_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _process(delta: float) -> void:
	if GameManager.current_phase != GameManager.GamePhase.PLAYING:
		return
	_auto_save_timer += delta
	if _auto_save_timer >= auto_save_interval_seconds:
		_auto_save_timer = 0.0
		save_game(current_slot, true)


func save_game(slot: int = 0, is_auto: bool = false) -> bool:
	current_slot = slot
	var payload := _gather_state()
	var path := SAVE_DIR.path_join(SAVE_FILE % slot)
	var backup := SAVE_DIR.path_join(BACKUP_FILE % slot)

	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, backup)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Kunne ikke gemme spil: %s" % path)
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	EventBus.save_completed.emit(slot)

	if not is_auto:
		EventBus.notification_posted.emit(
			tr("NOTIF_SAVED_TITLE"),
			tr("NOTIF_SAVED_MSG") % (slot + 1),
			"save"
		)
	return true


func load_game(slot: int = 0) -> bool:
	current_slot = slot
	var path := SAVE_DIR.path_join(SAVE_FILE % slot)
	if not FileAccess.file_exists(path):
		push_warning("Ingen gemning i slot %d" % slot)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ugyldig gemfil")
		return false

	_apply_state(parsed as Dictionary)
	EventBus.load_completed.emit(slot)
	return true


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(SAVE_DIR.path_join(SAVE_FILE % slot))


func delete_save(slot: int = 0) -> void:
	var path := SAVE_DIR.path_join(SAVE_FILE % slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func get_save_summary(slot: int = 0) -> Dictionary:
	var path := SAVE_DIR.path_join(SAVE_FILE % slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d := parsed as Dictionary
	return {
		"player_name": d.get("game", {}).get("player_name", ""),
		"day": d.get("game", {}).get("day", 1),
		"season": d.get("game", {}).get("season", ""),
		"year": d.get("game", {}).get("year", 1),
		"gold": d.get("economy", {}).get("gold", 0),
		"play_time_seconds": d.get("game", {}).get("play_time_seconds", 0.0),
	}


func _gather_state() -> Dictionary:
	return {
		"meta": {
			"version": GameManager.SAVE_VERSION,
			"timestamp": Time.get_datetime_string_from_system(),
		},
		"game": GameManager.to_dict(),
		"economy": EconomyManager.to_dict(),
		"quests": QuestManager.to_dict(),
		"time": TimeManager.to_dict(),
	}


func _apply_state(data: Dictionary) -> void:
	GameManager.from_dict(data.get("game", {}))
	EconomyManager.from_dict(data.get("economy", {}))
	QuestManager.from_dict(data.get("quests", {}))
	TimeManager.from_dict(data.get("time", {}))
