extends Node
## SaveManager: versioned, validated, atomic saves (PLAN 7.3 P15, D15; addendum 3.2 / 3.4 / 4.4).
##
## FILES (user://saves). save_0.json .. save_5.json are the six MANUAL slots, save_auto.json is the one AUTO slot
## (AUTO_SLOT = 6, an int so it travels through EventBus.save_completed(slot: int)). A manual save rolls the previous
## file of its slot to save_N.bak.json first (only when that file is a valid save payload); the auto slot has no backup.
## Every write goes to <file>.tmp, is read back and compared, and only then renamed over the real file: a crash or a
## full disk never leaves half a save behind and never replaces a good save with a bad one.
##
## AUTOSAVE writes ONLY the auto slot, never a manual one: every AUTOSAVE_INTERVAL_SECONDS real seconds while the phase
## is PLAYING, and once after every day end (EventBus.day_ended fires at the bed and at every crossed midnight). The day-end
## save is DEFERRED to the end of the frame: day_ended is emitted before the calendar steps and before the other
## day_started listeners (crops, shop stock, animals) have run, so the deferred save sees the finished new day.
##
## PAYLOAD v2 (meta.version = PAYLOAD_VERSION; GameManager.SAVE_VERSION is only the version of the "game" dict):
##   meta{version, timestamp, saved_at, summary}  game  time  economy  quests  husbandry  shops  <registered sections>  world
## game/time/economy/quests are REQUIRED, husbandry/shops/registered sections are optional (a section missing from a
## save has its reset() called, it is never left stale), world is an OPAQUE Dictionary (WorldRoot2D.to_dict: area,
## player_pos, farm, hotbar, placed items, area flags). Apply order (ascending `order`, then registration): game -60,
## time -50 (TimeManager.from_dict reads GameManager.total_day(), so the calendar goes first), economy -40, quests -30,
## husbandry -20, shops -10, then the feature sections: home 10, furniture 20, wardrobe 30, loot 40, collection 50,
## everything else 100.
##
## SECTION REGISTRY (addendum 3.2). A feature manager calls register_section("home", self, 10) in _ready and offers
## to_dict() -> Dictionary, from_dict(d) (may return false to reject the data) and reset(); each section carries its own
## "v" (the payload version stays 2). gather = {name: node.to_dict()}. An optional pure validate_dict(d) -> bool
## checks nested records during slot inspection, before any live state changes or a backup is rotated.
##
## LOADING. load_game(slot) VALIDATES first (root is an object, meta.version is a whole number <= PAYLOAD_VERSION,
## older versions go through the _migrate chain, required sections are objects with their required keys), then
## APPLIES atomically: the state of every section is snapshotted, from_dict runs under an error guard (a script error
## or a `false` result of any section), and a failure puts every section back and returns false. A failed load
## returns false, sets last_error {slot, code, detail} and posts NOTIF_LOAD_FAILED_* through EventBus.notification_posted;
## it never changes the phase or the scene, so a bad file cannot soft-lock the menu. When the file of a manual slot
## does not parse or validate, its .bak is tried (NOTIF_LOAD_BACKUP_* tells the player). Parsing uses JSON.new().parse()
## (no engine error for garbage; JSON.parse_string spams one).
## JSON has one number type: after parsing, every WHOLE float becomes an int (5.0 -> 5); sections that need a float
## call float(). Vectors are written as arrays by the sanitizer (JSON.stringify would write the STRING "(1.0, 2.0)").
##
## WORLD HAND-OFF. load_game() puts the "world" dictionary into pending_world and touches nothing else of the world;
## WorldRoot2D._ready builds its areas and player, then takes it with consume_pending_world() (or reads and clears
## pending_world) and applies it. continue_latest() / load_and_enter(slot) are the whole "load and go" flow for the
## title and the load screen: load_game, pop every modal, phase PLAYING, change to WORLD_SCENE.
##
## new_game_started -> reset(): current_slot = -1, timers zero, pending_world and last_error cleared.
## current_slot is the MANUAL slot of the running game (last manual save, last load of a manual slot) or NO_SLOT; it is never
## AUTO_SLOT, so save_game(current_slot) can only ever write a manual slot. Loading the auto slot (Continue after an
## autosave) leaves it as it was; a caller that finds NO_SLOT asks the player for a slot and never invents one (a guessed
## slot would silently overwrite somebody's manual save).
##
## PUBLIC API
##   save_game(slot = 0, is_auto = false) -> bool        autosave() -> bool          load_game(slot = 0) -> bool
##   continue_latest() -> bool                           load_and_enter(slot) -> bool   consume_pending_world() -> Dictionary
##   has_save(slot) has_any_save() delete_save(slot) get_latest_slot() -> int (NO_SLOT = -1)
##   get_save_summary(slot) -> Dictionary                describe_slots() -> [{slot, is_auto, state, summary}]   inspect_slot(slot)
##   register_section(name, node, order = 100) unregister_section(name) has_section(name) section_names() registered_section_names()
##   gather_payload() validate_payload(data) slot_path(slot) backup_path(slot)   constants MANUAL_SLOTS AUTO_SLOT NO_SLOT FEATURE_ORDERS
##   vars current_slot pending_world last_error autosave_enabled auto_save_interval_seconds save_dir clock_override world_scene
##
## TEST SEAMS (no behaviour of their own): save_dir, clock_override and world_scene are variables; _system_bias_minutes() (the time zone
## offset used to read a v1 local time stamp) and _store_text(file, text) (the one place where bytes go into the temp file)
## are methods that a test overrides in a subclass, to pin the time zone and to model a disk that loses bytes silently.

const SAVE_DIR := "user://saves"
const SAVE_FILE := "save_%d.json"
const BACKUP_FILE := "save_%d.bak.json"
const AUTO_FILE := "save_auto.json"
const PAYLOAD_VERSION := 2
const MANUAL_SLOTS := 6
const AUTO_SLOT := 6
const NO_SLOT := -1
const AUTOSAVE_INTERVAL_SECONDS := 300.0
const WORLD_SCENE := "res://scenes/main/world.tscn"
const MAX_SAVE_BYTES := 8 * 1024 * 1024
const DEFAULT_SECTION_ORDER := 100
## Apply order of the feature sections (addendum 3.2): register_section("home", self, SaveManager.FEATURE_ORDERS["home"]).
## Furniture comes after the home (its room depends on the tier), the wardrobe and the loot after the stores they read.
const FEATURE_ORDERS := {"home": 10, "furniture": 20, "wardrobe": 30, "loot": 40, "collection": 50}

## Late-bound autoload lookup (an injected fake wins); a preload, not the class_name, so the autoload compiles before the class cache exists.
const SvcLib := preload("res://scripts/data/svc.gd")

## Built-in sections: [name, autoload, apply order, required, {key: type}]. Types: str, num, arr, dict, list (arr or dict).
const CORE_SECTIONS := [
	{"name": "game", "autoload": "GameManager", "order": -60, "required": true,
		"keys": {"player_name": "str", "day": "num", "season": "str", "year": "num", "character_type": "num"}},
	{"name": "time", "autoload": "TimeManager", "order": -50, "required": true, "keys": {"weather": "str"}},
	{"name": "economy", "autoload": "EconomyManager", "order": -40, "required": true, "keys": {"gold": "num", "inventory": "list"}},
	{"name": "quests", "autoload": "QuestManager", "order": -30, "required": true, "keys": {"active": "dict", "completed": "arr"}},
	{"name": "husbandry", "autoload": "AnimalHusbandry", "order": -20, "required": false, "keys": {}},
	{"name": "shops", "autoload": "ShopSystem", "order": -10, "required": false, "keys": {}},
]
## Names a registered section may not take: they are the payload's own keys.
const RESERVED_SECTION_NAMES: Array[String] = ["meta", "world"]

## Base directory of the save files (a test points it at a scratch directory; the game never changes it).
var save_dir: String = SAVE_DIR
## Manual slot (0..5) of the last manual save or of the last load from a manual slot, NO_SLOT (-1) after a new game.
## Autosaves and loads of the auto slot never change it, and it is never AUTO_SLOT.
var current_slot: int = NO_SLOT
## The world state of the loaded save, waiting for WorldRoot2D._ready (opaque: SaveManager never looks inside).
var pending_world: Dictionary = {}
var auto_save_interval_seconds: float = AUTOSAVE_INTERVAL_SECONDS
## Switch for BOTH autosave triggers (the timer and the day end); tests of other packages may turn it off.
var autosave_enabled: bool = true
## {slot, code, detail} of the last failed load or save, {} after a success. code: missing corrupt invalid version apply scene slot write.
var last_error: Dictionary = {}
## Test seam: a value >= 0 replaces Time.get_unix_time_from_system() as the time stamp of a save.
var clock_override: float = -1.0
## The scene load_and_enter / continue_latest change to (a test points it at a scene that does not exist; the game never changes it).
var world_scene: String = WORLD_SCENE

var _auto_save_timer: float = 0.0
var _autosave_queued: bool = false
var _sections: Array[Dictionary] = []     # registered sections: {name, node, order, seq}
var _section_seq: int = 0


## Counts the script/engine ERRORS that the main thread raises while sections apply a save (warnings are tolerated).
class ApplyGuard extends Logger:
	## Guards that exist right now: OS.add_logger keeps one alive until OS.remove_logger, so this is 0 whenever no load is
	## running (a guard that is never removed would hear every later engine error, for the rest of the session).
	static var alive: int = 0
	var errors: int = 0
	var first: String = ""
	var _main_thread: int = OS.get_main_thread_id()

	func _init() -> void:
		alive += 1

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			alive -= 1

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING or OS.get_thread_caller_id() != _main_thread:
			return
		errors += 1
		if first == "":
			first = "%s:%d in %s(): %s %s" % [file.get_file(), line, function, code, rationale]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_dir()
	_remove_stale_temp_files()
	EventBus.new_game_started.connect(reset)
	EventBus.day_ended.connect(_on_day_ended)


func _process(delta: float) -> void:
	if GameManager.current_phase != GameManager.GamePhase.PLAYING or not autosave_enabled:
		return
	_auto_save_timer += delta
	if _auto_save_timer >= auto_save_interval_seconds:
		autosave()


## New game (EventBus.new_game_started): no current slot, timers zero, nothing waits for a world, no stale error.
func reset() -> void:
	current_slot = NO_SLOT
	_auto_save_timer = 0.0
	_autosave_queued = false
	pending_world = {}
	last_error = {}


# ------------------------------------------------------------------ slots and paths

static func is_manual_slot(slot: int) -> bool:
	return slot >= 0 and slot < MANUAL_SLOTS


static func is_valid_slot(slot: int) -> bool:
	return is_manual_slot(slot) or slot == AUTO_SLOT


## [0, 1, 2, 3, 4, 5, AUTO_SLOT]
static func all_slots() -> Array[int]:
	var out: Array[int] = []
	for i in MANUAL_SLOTS:
		out.append(i)
	out.append(AUTO_SLOT)
	return out


func slot_path(slot: int) -> String:
	return save_dir.path_join(AUTO_FILE if slot == AUTO_SLOT else SAVE_FILE % slot)


## The .bak file of a manual slot; "" for the auto slot (it has none).
func backup_path(slot: int) -> String:
	return "" if slot == AUTO_SLOT else save_dir.path_join(BACKUP_FILE % slot)


func has_save(slot: int = 0) -> bool:
	return is_valid_slot(slot) and FileAccess.file_exists(slot_path(slot))


## True when at least one slot (manual or auto) can be loaded: the Continue button's enabled state.
func has_any_save() -> bool:
	return get_latest_slot() != NO_SLOT


func delete_save(slot: int = 0) -> void:
	if not is_valid_slot(slot):
		return
	for path in [slot_path(slot), backup_path(slot), slot_path(slot) + ".tmp"]:
		if path != "" and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if current_slot == slot:
		current_slot = NO_SLOT


# ------------------------------------------------------------------ saving

## Saves into `slot` (0..5, or AUTO_SLOT). `is_auto` forces the auto slot whatever `slot` says (the old autosave
## overwrote the current manual slot). Autosaves are silent and leave current_slot alone; a manual save toasts
## NOTIF_SAVED_* and becomes current_slot. Returns false (and toasts NOTIF_SAVE_FAILED_* for a manual save) when the
## file could not be written; the old file of the slot is then untouched.
func save_game(slot: int = 0, is_auto: bool = false) -> bool:
	if is_auto:
		slot = AUTO_SLOT
	if not is_valid_slot(slot):
		last_error = {"slot": slot, "code": "slot", "detail": "slot %d does not exist" % slot}
		return false
	var silent := slot == AUTO_SLOT
	var text := JSON.stringify(gather_payload(), "\t", true, true)
	_ensure_dir()
	if not silent:
		_roll_backup(slot)
	if not _write_atomic(slot_path(slot), text):
		last_error = {"slot": slot, "code": "write", "detail": "could not write %s" % slot_path(slot)}
		if not silent:
			_toast(tr("NOTIF_SAVE_FAILED_TITLE"), tr("NOTIF_SAVE_FAILED_MSG"), slot + 1)
		return false
	last_error = {}
	if silent:
		_auto_save_timer = 0.0
	else:
		current_slot = slot
	EventBus.save_completed.emit(slot)
	if not silent:
		_toast(tr("NOTIF_SAVED_TITLE"), tr("NOTIF_SAVED_MSG"), slot + 1)
	return true


## Writes the auto slot (never a manual one) and restarts the autosave countdown.
func autosave() -> bool:
	_auto_save_timer = 0.0
	return save_game(AUTO_SLOT, true)


func _on_day_ended(_day: int, _season: StringName) -> void:
	if not autosave_enabled or _autosave_queued or not _game_running():
		return
	_autosave_queued = true
	_run_queued_autosave.call_deferred()


func _run_queued_autosave() -> void:
	if not _autosave_queued:                   # reset() (a new game began in the same frame) dropped it: nothing of the old run is saved
		return
	_autosave_queued = false
	if autosave_enabled and _game_running():
		autosave()


## A run exists (PLAYING, or paused / in a cutscene on top of it); the menus have nothing worth saving.
func _game_running() -> bool:
	var phase: int = GameManager.current_phase
	return phase == GameManager.GamePhase.PLAYING or phase == GameManager.GamePhase.PAUSED or phase == GameManager.GamePhase.CUTSCENE


# ------------------------------------------------------------------ loading

## Validates, then applies atomically (see the header). Does not touch the phase or the scene: the caller (load screen,
## continue_latest) enters the world. Emits load_completed(slot) on success; a manual slot becomes current_slot, the auto slot
## does not (see current_slot).
func load_game(slot: int = 0) -> bool:
	last_error = {}
	if not is_valid_slot(slot):
		return _fail_load(slot, "missing", "slot %d does not exist" % slot)
	var info := inspect_slot(slot)
	match info["state"]:
		&"empty":
			return _fail_load(slot, "missing", "no save in slot %d" % slot)
		&"newer":
			return _fail_load(slot, "version", str(info["detail"]))
		&"corrupt":
			return _fail_load(slot, str(info["code"]), str(info["detail"]))
	var applied := _apply_payload(info["payload"])
	if not applied["ok"]:
		return _fail_load(slot, "apply", str(applied["detail"]))
	if slot != AUTO_SLOT:                       # the auto slot is not a place the player saves to: keep the manual slot of this run
		current_slot = slot
	_auto_save_timer = 0.0
	if info["from_backup"]:
		_toast(tr("NOTIF_LOAD_BACKUP_TITLE"), tr("NOTIF_LOAD_BACKUP_MSG"), slot + 1)
	EventBus.load_completed.emit(slot)
	return true


## load_game(slot), then the whole way into the world: pop every modal, phase PLAYING, change to world_scene (WORLD_SCENE,
## whose WorldRoot2D takes pending_world). False (with feedback) leaves phase, scene AND the running game exactly as they were:
## a world scene that does not exist is refused before the save is applied.
func load_and_enter(slot: int) -> bool:
	if not ResourceLoader.exists(world_scene):          # checked BEFORE the save is applied: a load that cannot enter the world leaves no half-loaded game behind
		last_error = {}
		return _fail_load(slot, "scene", "%s does not exist" % world_scene)
	if not load_game(slot):
		return false
	var err := get_tree().change_scene_to_file(world_scene)
	if err != OK:
		return _fail_load(slot, "scene", "could not change to %s (error %d)" % [world_scene, err])
	GameManager.pop_all_modals()
	GameManager.change_phase(GameManager.GamePhase.PLAYING)
	return true


## The Continue button of the title screen: loads the newest save (get_latest_slot) and enters the world.
func continue_latest() -> bool:
	var slot := get_latest_slot()
	if slot == NO_SLOT:
		last_error = {}
		return _fail_load(NO_SLOT, "missing", "no loadable save in any slot")
	return load_and_enter(slot)


## The world dictionary of the loaded game, once: WorldRoot2D._ready calls it after its areas and player exist.
func consume_pending_world() -> Dictionary:
	var world := pending_world
	pending_world = {}
	return world


func _fail_load(slot: int, code: String, detail: String) -> bool:
	last_error = {"slot": slot, "code": code, "detail": detail}
	EventBus.notification_posted.emit(tr("NOTIF_LOAD_FAILED_TITLE"), _load_fail_text(code), "save")
	return false


## The player-facing reason of a failed load (code: missing corrupt invalid version apply scene).
func _load_fail_text(code: String) -> String:
	match code:
		"missing":
			return tr("NOTIF_LOAD_FAILED_MISSING")
		"version":
			return tr("NOTIF_LOAD_FAILED_VERSION")
		"apply", "scene":
			return tr("NOTIF_LOAD_FAILED_APPLY")
	return tr("NOTIF_LOAD_FAILED_CORRUPT")


# ------------------------------------------------------------------ what is on disk

## State of one slot without loading it: {state, code, detail, payload, from_backup, saved_at}.
## state: &"empty" (no file), &"ok", &"backup" (the file is damaged but its .bak loads), &"newer" (written by a newer
## build), &"corrupt" (neither file loads; code corrupt or invalid). `payload` (validated, migrated, whole numbers
## as ints) is set for ok and backup.
func inspect_slot(slot: int) -> Dictionary:
	var out := {"state": &"empty", "code": "missing", "detail": "", "payload": {}, "from_backup": false, "saved_at": 0.0}
	if not is_valid_slot(slot):
		out["detail"] = "slot %d does not exist" % slot
		return out
	var primary := _read_json_file(slot_path(slot))
	var failure := {"code": "corrupt", "detail": str(primary.get("detail", ""))}
	if primary["state"] == "missing":
		return out
	if primary["state"] == "ok":
		var checked := validate_payload(primary["data"])
		if checked["ok"]:
			return _inspect_result(out, &"ok", checked["payload"], false)
		if checked["code"] == "version":
			out["state"] = &"newer"
			out["code"] = "version"
			out["detail"] = str(checked["detail"])
			return out
		failure = {"code": checked["code"], "detail": checked["detail"]}
	var bak_path := backup_path(slot)
	if bak_path != "" and FileAccess.file_exists(bak_path):
		var backup := _read_json_file(bak_path)
		if backup["state"] == "ok":
			var bak_checked := validate_payload(backup["data"])
			if bak_checked["ok"]:
				return _inspect_result(out, &"backup", bak_checked["payload"], true)
	out["state"] = &"corrupt"
	out["code"] = failure["code"]
	out["detail"] = failure["detail"]
	return out


func _inspect_result(out: Dictionary, state: StringName, payload: Dictionary, from_backup: bool) -> Dictionary:
	out["state"] = state
	out["code"] = ""
	out["payload"] = payload
	out["from_backup"] = from_backup
	out["saved_at"] = _saved_at_of(payload)
	return out


## What the slot list shows: {} for an empty, damaged or newer-version slot, else farm name, character, day, season,
## year, total_day, gold, play time, hour/minute, area, time stamp (+ slot, is_auto, from_backup). player_name, day,
## season, year, gold and play_time_seconds are the legacy keys. Works for v1 saves (no meta.summary) too. meta.summary is
## only a cache: when it lacks a key or holds a value of the wrong type (a hand-edited or half-written file) the summary is
## rebuilt from the sections, so the values always have the types SUMMARY_TYPES lists and a "%d" never meets a string.
func get_save_summary(slot: int = 0) -> Dictionary:
	return _summary_of(inspect_slot(slot), slot)


## The summary row of an already-inspected slot: {} when it is not loadable. Lets describe_slots() reuse the payload it
## just read instead of reading and validating the file a second time.
func _summary_of(info: Dictionary, slot: int) -> Dictionary:
	if info["state"] != &"ok" and info["state"] != &"backup":
		return {}
	var payload: Dictionary = info["payload"]
	var meta: Dictionary = _dict_of(payload.get("meta"))
	var summary: Dictionary = _dict_of(meta.get("summary"))
	if not _summary_valid(summary):
		summary = _summarize(payload)
	summary = summary.duplicate()
	summary["play_time_seconds"] = float(summary.get("play_time_seconds", 0.0))   # a whole 600.0 came back as the int 600
	summary["slot"] = slot
	summary["is_auto"] = slot == AUTO_SLOT
	summary["from_backup"] = info["from_backup"]
	summary["timestamp"] = str(meta.get("timestamp", ""))
	summary["saved_at"] = info["saved_at"]
	return summary


## Newest loadable save across the manual slots and the auto slot (NO_SLOT when there is none). The time stamp is
## meta.saved_at (meta.timestamp for v1 saves); a tie goes to the lower manual slot, then to the auto slot.
## Damaged slots without a usable .bak, and saves of a newer build, are skipped: Continue never picks them.
func get_latest_slot() -> int:
	var best := NO_SLOT
	var best_time := -INF
	for slot in all_slots():
		var info := inspect_slot(slot)
		if info["state"] != &"ok" and info["state"] != &"backup":
			continue
		var stamp := float(info["saved_at"])
		if stamp > best_time:
			best_time = stamp
			best = slot
	return best


## One row per slot, manual slots first and the auto slot last: [{slot, is_auto, state, summary}].
func describe_slots() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for slot in all_slots():
		var info := inspect_slot(slot)
		rows.append({"slot": slot, "is_auto": slot == AUTO_SLOT, "state": info["state"], "summary": _summary_of(info, slot)})
	return rows


# ------------------------------------------------------------------ section registry

## Registers a state-owning node (addendum 3.2): `node` offers to_dict() -> Dictionary, from_dict(d) and reset().
## Sections apply in ascending `order`, equal orders in registration order. Registering a name again replaces the node and
## order. Returns false (with an error) for a bad name, a node without the three methods, or a built-in/reserved name.
func register_section(section_name: String, node: Node, order: int = DEFAULT_SECTION_ORDER) -> bool:
	var rx := RegEx.new()
	rx.compile("^[a-z][a-z0-9_]{0,31}$")
	if rx.search(section_name) == null:
		push_error("SaveManager.register_section: '%s' is not a valid section name (a-z, 0-9, _)" % section_name)
		return false
	if section_name in RESERVED_SECTION_NAMES or _core_entry(section_name) != null:
		push_error("SaveManager.register_section: '%s' is a built-in name" % section_name)
		return false
	if node == null or not is_instance_valid(node):
		push_error("SaveManager.register_section('%s'): the node is null or freed" % section_name)
		return false
	for method in ["to_dict", "from_dict", "reset"]:
		if not node.has_method(method):
			push_error("SaveManager.register_section('%s'): the node has no %s()" % [section_name, method])
			return false
	var clamped := clampi(order, -1000, 1000)
	for entry in _sections:
		if entry["name"] == section_name:
			entry["node"] = node
			entry["order"] = clamped
			return true
	_section_seq += 1
	_sections.append({"name": section_name, "node": node, "order": clamped, "seq": _section_seq})
	return true


func unregister_section(section_name: String) -> void:
	for i in range(_sections.size() - 1, -1, -1):
		if _sections[i]["name"] == section_name:
			_sections.remove_at(i)


func has_section(section_name: String) -> bool:
	for entry in _ordered_entries():
		if entry["name"] == section_name:
			return true
	return false


## Names in gather / apply order, built-in sections first (they have negative orders): game, time, economy, ...
func section_names() -> Array[String]:
	var out: Array[String] = []
	for entry in _ordered_entries():
		out.append(str(entry["name"]))
	return out


## The node behind a section name (built-in sections: the autoload), null when unknown.
func section_node(section_name: String) -> Node:
	for entry in _ordered_entries():
		if entry["name"] == section_name:
			return _node_of(entry)
	return null


## Only the registered (feature) sections, in apply order.
func registered_section_names() -> Array[String]:
	var out: Array[String] = []
	for entry in _ordered_entries():
		if not entry.get("core", false):
			out.append(str(entry["name"]))
	return out


## Built-in entries followed by the live registered ones, sorted by (order, registration).
func _ordered_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in CORE_SECTIONS.size():
		var core: Dictionary = (CORE_SECTIONS[i] as Dictionary).duplicate()
		core["core"] = true
		core["seq"] = i - 1000
		out.append(core)
	for i in range(_sections.size() - 1, -1, -1):
		if not is_instance_valid(_sections[i]["node"]):
			_sections.remove_at(i)             # a freed node is simply gone
	out.append_array(_sections)
	out.sort_custom(_entry_before)
	return out


static func _entry_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["order"]) != int(b["order"]):
		return int(a["order"]) < int(b["order"])
	return int(a["seq"]) < int(b["seq"])


func _core_entry(section_name: String) -> Variant:
	for core in CORE_SECTIONS:
		if core["name"] == section_name:
			return core
	return null


## The node behind an entry: a registered node, or the built-in section's autoload (late bound, an injected fake wins).
func _node_of(entry: Dictionary) -> Node:
	if entry.get("core", false):
		return SvcLib.node(entry["autoload"])
	var node: Node = entry["node"]
	return node if is_instance_valid(node) else null


# ------------------------------------------------------------------ payload: gather

## The save as a dictionary: meta, every section's to_dict() (sanitized: arrays instead of vectors, plain Strings) and
## the world. `quests` carries no Lua definitions.
func gather_payload() -> Dictionary:
	var payload: Dictionary = {}
	for entry in _ordered_entries():
		var node := _node_of(entry)
		if node == null or not node.has_method("to_dict"):
			continue
		var data: Variant = node.call("to_dict")
		if typeof(data) != TYPE_DICTIONARY:
			push_error("SaveManager: %s.to_dict() did not return a Dictionary, the section '%s' is not saved" % [node.name, entry["name"]])
			continue
		payload[entry["name"]] = _json_safe(data, str(entry["name"]))
	_strip_quest_defs(payload)
	payload["world"] = _json_safe(_gather_world(), "world")
	var stamp := clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()
	payload["meta"] = {
		"version": PAYLOAD_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"saved_at": stamp,
		"summary": _summarize(payload),
	}
	return payload


## The live world's to_dict(); without a world (title screen, world not built yet after a load) the state that is still
## waiting in pending_world, so a save made in between does not lose the world.
func _gather_world() -> Dictionary:
	var tree := get_tree()
	var world: Node = tree.get_first_node_in_group(&"world_2d") if tree != null else null
	if world != null and world.has_method("to_dict"):
		var data: Variant = world.call("to_dict")
		if typeof(data) == TYPE_DICTIONARY:
			return data
	return pending_world.duplicate(true)


## Quest definitions are Lua, never saved. QuestManager of the first waves kept them in quest_flags as "def_<id>".
func _strip_quest_defs(payload: Dictionary) -> void:
	var quests: Dictionary = _dict_of(payload.get("quests"))
	var flags: Dictionary = _dict_of(quests.get("flags"))
	for key in flags.keys():
		if str(key).begins_with("def_"):
			flags.erase(key)


## Makes a to_dict() result JSON-safe and plain: String keys, StringName -> String, vectors / colors / rects -> arrays,
## packed arrays -> arrays, NaN and infinity -> 0.0, objects -> null (with a warning).
func _json_safe(value: Variant, where: String, depth: int = 0) -> Variant:
	if depth > 64:
		push_warning("SaveManager: '%s' is nested deeper than 64 levels, the rest is dropped" % where)
		return null
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_FLOAT:
			return value if is_finite(value) else 0.0
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return String(value)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [value.x, value.y, value.z]
		TYPE_VECTOR4, TYPE_VECTOR4I:
			return [value.x, value.y, value.z, value.w]
		TYPE_COLOR:
			return [value.r, value.g, value.b, value.a]
		TYPE_RECT2, TYPE_RECT2I:
			return [value.position.x, value.position.y, value.size.x, value.size.y]
		TYPE_DICTIONARY:
			var out_dict := {}
			for key in value:
				out_dict[str(key)] = _json_safe(value[key], where, depth + 1)
			return out_dict
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			var out_array: Array = []
			for item in value:
				out_array.append(_json_safe(item, where, depth + 1))
			return out_array
	push_warning("SaveManager: '%s' holds a %s, which cannot be saved (written as null)" % [where, type_string(typeof(value))])
	return null


# ------------------------------------------------------------------ payload: validate, migrate

## Checks a parsed save WITHOUT touching the game: {ok, code, detail, payload}. `payload` is a migrated copy with whole
## floats turned into ints. code: corrupt (not a save at all), invalid (a section is missing or has the wrong shape),
## version (written by a newer build).
func validate_payload(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return _verdict(false, "corrupt", "the save is not a JSON object")
	var meta: Variant = (data as Dictionary).get("meta")
	if typeof(meta) != TYPE_DICTIONARY:
		return _verdict(false, "corrupt", "meta is missing")
	var raw_version: Variant = (meta as Dictionary).get("version")
	if not _is_number(raw_version) or float(raw_version) != floorf(float(raw_version)) or float(raw_version) < 1.0:
		return _verdict(false, "corrupt", "meta.version is not a whole number >= 1")
	var version := int(raw_version)
	if version > PAYLOAD_VERSION:
		return _verdict(false, "version", "the save has version %d, this build reads up to %d" % [version, PAYLOAD_VERSION])
	var payload: Dictionary = _coerce_numbers(data)
	payload = _migrate(payload, version)
	for entry in _ordered_entries():
		var section_name: String = entry["name"]
		if payload.has(section_name):
			var section: Variant = payload[section_name]
			if typeof(section) != TYPE_DICTIONARY:
				return _verdict(false, "invalid", "section '%s' is not an object" % section_name)
			var keys: Dictionary = entry.get("keys", {})
			for key in keys:
				if not (section as Dictionary).has(key):
					return _verdict(false, "invalid", "section '%s' lacks '%s'" % [section_name, key])
				if not _has_type((section as Dictionary)[key], str(keys[key])):
					return _verdict(false, "invalid", "section '%s': '%s' should be %s" % [section_name, key, keys[key]])
			var node := _node_of(entry)
			if node != null and node.has_method("validate_dict") and not bool(node.call("validate_dict", section)):
				return _verdict(false, "invalid", "section '%s' contains invalid records" % section_name)
		elif entry.get("required", false):
			return _verdict(false, "invalid", "section '%s' is missing" % section_name)
	if payload.has("world") and typeof(payload["world"]) != TYPE_DICTIONARY:
		return _verdict(false, "invalid", "world is not an object")
	return _verdict(true, "", "", payload)


func _verdict(ok: bool, code: String, detail: String, payload: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "code": code, "detail": detail, "payload": payload}


## Brings an older payload up to PAYLOAD_VERSION one step at a time: _migrate_<from>_to_<from + 1>.
func _migrate(payload: Dictionary, from_version: int) -> Dictionary:
	var version := from_version
	while version < PAYLOAD_VERSION:
		match version:
			1:
				payload = _migrate_1_to_2(payload)
			_:
				break
		version += 1
	var meta: Dictionary = _dict_of(payload.get("meta"))
	meta["version"] = PAYLOAD_VERSION
	payload["meta"] = meta
	return payload


## v1 (the 3D build): quest definitions were stored in quests.flags as def_<id>; saved_at comes from the time stamp
## string (LOCAL time, see _unix_of_local_stamp), summary from the sections. husbandry / shops / world were never saved: they
## stay absent (reset on load).
func _migrate_1_to_2(payload: Dictionary) -> Dictionary:
	_strip_quest_defs(payload)
	var meta: Dictionary = _dict_of(payload.get("meta"))
	meta["migrated_from"] = 1
	if not meta.has("saved_at"):
		meta["saved_at"] = _unix_of_local_stamp(str(meta.get("timestamp", "")))
	payload["meta"] = meta
	meta["summary"] = _summarize(payload)
	return payload


func _saved_at_of(payload: Dictionary) -> float:
	var meta: Dictionary = _dict_of(payload.get("meta"))
	if _is_number(meta.get("saved_at")):
		return float(meta["saved_at"])
	return _unix_of_local_stamp(str(meta.get("timestamp", "")))


## Unix seconds (UTC) of meta.timestamp, "YYYY-MM-DDTHH:MM:SS" as Time.get_datetime_string_from_system() wrote it: LOCAL time.
## Time.get_unix_time_from_datetime_string() reads such a string as UTC, which would make an old save look as many hours
## newer as the machine's offset (two in Denmark in summer) and put it in front of a later save in get_latest_slot();
## the offset is taken off again. The offset is today's: a stamp on the other side of a daylight-saving change is up to one
## hour off, the order of two stamps from the same side is exact. No stamp, or one that is not a real date and time (a
## damaged file; the engine would print an ERROR for it every time the slot is inspected), is 0.0: unknown, oldest.
func _unix_of_local_stamp(stamp: String) -> float:
	if not _is_real_stamp(stamp):
		return 0.0
	return float(Time.get_unix_time_from_datetime_string(stamp)) - float(_system_bias_minutes()) * 60.0


## "YYYY-MM-DDTHH:MM:SS" (or with a space) naming a date that exists, year 1970 or later.
func _is_real_stamp(stamp: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^(\\d{4})-(\\d{2})-(\\d{2})[T ](\\d{2}):(\\d{2}):(\\d{2})$")
	var found := rx.search(stamp)
	if found == null:
		return false
	var year := int(found.get_string(1))
	var month := int(found.get_string(2))
	var day := int(found.get_string(3))
	if year < 1970 or month < 1 or month > 12 or day < 1 or int(found.get_string(4)) > 23 or int(found.get_string(5)) > 59 or int(found.get_string(6)) > 59:
		return false
	var days_in_month := [31, 29 if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day <= int(days_in_month[month - 1])


## Offset of the local time zone from UTC in minutes, positive east of Greenwich (+120 = Denmark in summer). A method of its
## own so that a test can pin the time zone instead of depending on the machine it runs on.
func _system_bias_minutes() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


## Whole floats -> ints, recursively (JSON gives every number as float). Floats with a fraction, huge floats and
## everything else stay as they are.
func _coerce_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			return int(f) if is_finite(f) and f == floorf(f) and absf(f) < 9007199254740992.0 else f
		TYPE_DICTIONARY:
			var out_dict := {}
			for key in value:
				out_dict[key] = _coerce_numbers(value[key])
			return out_dict
		TYPE_ARRAY:
			var out_array: Array = []
			for item in value:
				out_array.append(_coerce_numbers(item))
			return out_array
	return value


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _has_type(value: Variant, kind: String) -> bool:
	match kind:
		"str":
			return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
		"num":
			return _is_number(value)
		"arr":
			return typeof(value) == TYPE_ARRAY
		"dict":
			return typeof(value) == TYPE_DICTIONARY
		"list":
			return typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY
	return true


func _dict_of(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _int_of(value: Variant, default_value: int = 0) -> int:
	return int(value) if _is_number(value) else default_value


# ------------------------------------------------------------------ payload: summary

## The keys of a summary and the type of each value: "str" a String, "int" a whole number (int after the JSON load), "num" any number.
const SUMMARY_TYPES := {
	"player_name": "str", "farm_name": "str", "character": "str", "character_skin": "str", "day": "int", "season": "str", "year": "int",
	"total_day": "int", "gold": "int", "play_time_seconds": "num", "hour": "int", "minute": "int", "area": "str",
}


## True when meta.summary has every key of SUMMARY_TYPES with a value of the listed type and `character` is a known hero.
func _summary_valid(summary: Dictionary) -> bool:
	for key in SUMMARY_TYPES:
		if not summary.has(key):
			return false
		var value: Variant = summary[key]
		var kind: String = SUMMARY_TYPES[key]
		if kind == "str" and typeof(value) != TYPE_STRING:
			return false
		if kind == "int" and typeof(value) != TYPE_INT:
			return false
		if kind == "num" and not _is_number(value):
			return false
	for hero in GameManager.CharacterType.keys():
		if str(summary["character"]) == str(hero).to_lower():
			return true
	return false


## The slot-list facts of a payload (meta.summary of a new save; derived on the fly for v1 saves).
func _summarize(payload: Dictionary) -> Dictionary:
	var game: Dictionary = _dict_of(payload.get("game"))
	var economy: Dictionary = _dict_of(payload.get("economy"))
	var world: Dictionary = _dict_of(payload.get("world"))
	var type_keys: Array = GameManager.CharacterType.keys()
	var character_type := clampi(_int_of(game.get("character_type", 0)), 0, type_keys.size() - 1)
	var season := StringName(str(game.get("season", "")))
	var day := _int_of(game.get("day", 1), 1)
	var year := _int_of(game.get("year", 1), 1)
	return {
		"player_name": str(game.get("player_name", "")),
		"farm_name": str(game.get("farm_name", "")),
		"character": str(type_keys[character_type]).to_lower(),
		"character_skin": str(game.get("character_skin", "")),
		"day": day,
		"season": str(season),
		"year": year,
		"total_day": _int_of(game.get("total_day", GameManager.total_day_for(day, season, year)), 1),
		"gold": _int_of(economy.get("gold", 0)),
		"play_time_seconds": float(game.get("play_time_seconds", 0.0)) if _is_number(game.get("play_time_seconds", 0.0)) else 0.0,
		"hour": _int_of(game.get("hour", 0)),
		"minute": _int_of(game.get("minute", 0)),
		"area": str(world.get("area", "")),
	}


# ------------------------------------------------------------------ payload: apply

## Applies a validated payload to the sections, all or nothing. {ok, detail}. See the header (LOADING).
func _apply_payload(payload: Dictionary) -> Dictionary:
	var entries := _ordered_entries()
	var snapshot: Dictionary = {}
	for entry in entries:
		var node := _node_of(entry)
		if node != null and node.has_method("to_dict"):
			var before: Variant = node.call("to_dict")
			snapshot[entry["name"]] = (before as Dictionary).duplicate(true) if typeof(before) == TYPE_DICTIONARY else {}
	var legacy_defs := _legacy_quest_defs()
	var guard := ApplyGuard.new()
	OS.add_logger(guard)
	var failure := ""
	var touched: Array[Dictionary] = []          # the sections that ran from_dict / reset (the failing one included)
	for entry in entries:
		var node := _node_of(entry)
		if node == null:
			continue
		var section_name: String = entry["name"]
		if payload.has(section_name):
			if not node.has_method("from_dict"):
				continue
			touched.append(entry)
			var result: Variant = node.call("from_dict", (payload[section_name] as Dictionary).duplicate(true))
			if typeof(result) == TYPE_BOOL and not result:
				failure = "section '%s' rejected its data" % section_name
		elif node.has_method("reset"):
			touched.append(entry)
			node.call("reset")
		if failure == "" and guard.errors > 0:
			failure = "section '%s' raised an error: %s" % [section_name, guard.first]
		if failure != "":
			break
	if failure == "":
		_restore_legacy_quest_defs(legacy_defs)
		pending_world = _dict_of(payload.get("world")).duplicate(true)
	else:
		for entry in touched:                      # sections that were never reached still hold their own state
			var node := _node_of(entry)
			if node != null and node.has_method("from_dict") and snapshot.has(entry["name"]):
				node.call("from_dict", (snapshot[entry["name"]] as Dictionary).duplicate(true))
	OS.remove_logger(guard)
	return {"ok": failure == "", "detail": failure}


## QuestManager of the first waves keeps the Lua definitions inside quest_flags ("def_<id>") and its from_dict replaces
## quest_flags wholesale, which would drop them (audit T1). The definitions are never in a save, so they are carried over.
## A QuestManager with separate quest_defs (P13) has no def_ flags and this does nothing.
func _legacy_quest_defs() -> Dictionary:
	var defs := {}
	var quest_manager := SvcLib.node("QuestManager")
	var flags: Variant = quest_manager.get("quest_flags") if quest_manager != null else null
	if typeof(flags) == TYPE_DICTIONARY:
		for key in flags:
			if str(key).begins_with("def_"):
				defs[key] = flags[key]
	return defs


func _restore_legacy_quest_defs(defs: Dictionary) -> void:
	if defs.is_empty():
		return
	var flags: Variant = SvcLib.node("QuestManager").get("quest_flags")
	if typeof(flags) == TYPE_DICTIONARY:
		for key in defs:
			if not (flags as Dictionary).has(key):
				flags[key] = defs[key]


# ------------------------------------------------------------------ files

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)


## A crash between the temp write and the rename leaves a .tmp behind; it is garbage, the real file is intact.
func _remove_stale_temp_files() -> void:
	for file_name in DirAccess.get_files_at(save_dir):
		if file_name.ends_with(".tmp"):
			DirAccess.remove_absolute(save_dir.path_join(file_name))


## {state: missing | unreadable | corrupt | ok, data, detail}. The first byte of a save must be '{' (a binary file is
## rejected before it is decoded: decoding invalid UTF-8 makes the engine print a message).
func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": "missing", "detail": "no file"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"state": "unreadable", "detail": "cannot open (error %d)" % FileAccess.get_open_error()}
	var length := file.get_length()
	if length <= 0:
		file.close()
		return {"state": "corrupt", "detail": "the file is empty"}
	if length > MAX_SAVE_BYTES:
		file.close()
		return {"state": "corrupt", "detail": "the file is larger than %d bytes" % MAX_SAVE_BYTES}
	var bytes := file.get_buffer(length)
	file.close()
	var first := 0
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		first = 3
	while first < bytes.size() and (bytes[first] == 0x20 or bytes[first] == 0x09 or bytes[first] == 0x0A or bytes[first] == 0x0D):
		first += 1
	if first >= bytes.size() or bytes[first] != 0x7B:
		return {"state": "corrupt", "detail": "the file does not start with a JSON object"}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return {"state": "corrupt", "detail": "JSON error at line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"state": "corrupt", "detail": "the root is not an object"}
	return {"state": "ok", "data": json.data, "detail": ""}


## The one place where the bytes of a save go into the temp file. A method of its own so that a test can model a disk that
## loses bytes WITHOUT reporting an error, which the read-back in _write_atomic must catch.
func _store_text(file: FileAccess, text: String) -> void:
	file.store_string(text)


## Temp file, read back and compared, rename over the target. False leaves the target as it was.
func _write_atomic(path: String, text: String) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	_store_text(file, text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_bytes(temp) != text.to_utf8_buffer():
		DirAccess.remove_absolute(temp)
		return false
	var rename_error := DirAccess.rename_absolute(temp, path)
	if rename_error != OK and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)            # a platform whose rename does not replace
		rename_error = DirAccess.rename_absolute(temp, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp)
		return false
	return true


## A manual save keeps the file it replaces as save_N.bak.json, but only when that file is a valid payload, so a damaged
## file never replaces a good .bak.
func _roll_backup(slot: int) -> void:
	var path := slot_path(slot)
	var backup := backup_path(slot)
	if backup == "" or not FileAccess.file_exists(path):
		return
	var previous := _read_json_file(path)
	if previous["state"] != "ok" or not validate_payload(previous["data"])["ok"]:
		return
	var temp := backup + ".tmp"
	if DirAccess.copy_absolute(path, temp) != OK:
		DirAccess.remove_absolute(temp)
		return
	if DirAccess.rename_absolute(temp, backup) != OK:
		DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(temp, backup) != OK:
			DirAccess.remove_absolute(temp)


# ------------------------------------------------------------------ feedback

## A toast of two translated texts; `arg` fills a %d / %s in the message (a missing translation returns the raw key, which
## has no placeholder and must not reach the formatter).
func _toast(title: String, message: String, arg: int) -> void:
	if message.contains("%d") or message.contains("%s"):
		message = message % arg
	EventBus.notification_posted.emit(title, message, "save")
