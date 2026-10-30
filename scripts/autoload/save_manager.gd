extends Node
## SaveManager: versioned, validated, atomic saves (PLAN 7.3 P15, D15; addendum 3.2 / 3.4 / 4.4).
##
## FILES (user://saves). save_0.json .. save_5.json are the six MANUAL slots, save_auto.json is the one AUTO slot
## (AUTO_SLOT = 6, an int so it travels through EventBus.save_completed(slot: int)). A manual save rolls the previous
## file of its slot to save_N.bak.json first (only when that file is a valid save payload); the auto slot has no backup.
## RUNS. Every game has a run id (meta.run_id; a new one on new_game_started, the loaded save's on a load, a new one for a save
## written before run ids existed: its derived "legacy:" id cannot tell two runs of the same names and hero apart). Before an autosave
## replaces save_auto.json it looks at that file: the autosave of ANOTHER run moves to save_auto.prev.json (PREV_AUTO_SLOT, read
## only, listed by describe_slots() when it exists, never picked by Continue), so "New game" never destroys the only autosave of
## the run before it; a file that does not load (damaged, content drift, a newer build) is kept as save_auto.damaged-<unix>.json
## (the newest QUARANTINE_KEEP of them) instead of being overwritten, and the player is told the file name (NOTIF_AUTO_SET_ASIDE_*).
## Every write goes to <file>.tmp, is read back and compared, and only then renamed over the real file: a crash or a
## full disk never leaves half a save behind and never replaces a good save with a bad one (on Windows the old file is moved
## to <file>.old first, see _commit_temp; start-up finishes an interrupted replacement, see _recover_interrupted_writes).
##
## AUTOSAVE writes ONLY the auto slot, never a manual one: every AUTOSAVE_INTERVAL_SECONDS real seconds while the phase
## is PLAYING, and once after every day end (EventBus.day_ended fires at the bed and at every crossed day end, game hour 26 = 02:00). The day-end
## save is DEFERRED to the end of the frame: day_ended is emitted before the calendar steps and before the other
## day_started listeners (crops, shop stock, animals) have run, so the deferred save sees the finished new day.
##
## PAYLOAD v3 (meta.version = PAYLOAD_VERSION; GameManager.SAVE_VERSION is only the version of the "game" dict):
##   meta{version, timestamp, saved_at, run_id, summary{players}} game time players husbandry shops <registered sections> world
## game/time/players are REQUIRED. Economy and quests are read only as v1/v2 migration input.
## Apply order: game -60, time -50, husbandry -20, shops -10, home 10, players 15,
## furniture 20, wardrobe 30, loot 40, collection 50, social 60, other sections 100.
##
## SECTION REGISTRY (addendum 3.2). A feature manager calls register_section("home", self, 10) in _ready and offers
## to_dict() -> Dictionary, from_dict(d) (may return false to reject the data) and reset(); each section carries its own
## "v" (the payload version stays 2). gather = {name: node.to_dict()}. An optional pure validate_dict(d) -> bool
## checks nested records during slot inspection, before any live state changes or a backup is rotated.
## SECTION VERSIONS, one policy: a section's script declares its version as SECTION_VERSION (or SAVE_VERSION / SAVE_V), its data
## carries it as "v" ("version" in the game dict). Data NEWER than the running build's declaration makes the slot &"newer" at
## inspection (shown as such, never loaded half-way); older data is the section's own migration. A top-level key of a save that
## no section of this build owns (a feature of a newer or a removed build) is carried along unchanged into the next save.
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
##   gather_payload() validate_payload(data) slot_path(slot) backup_path(slot)   constants MANUAL_SLOTS AUTO_SLOT PREV_AUTO_SLOT NO_SLOT FEATURE_ORDERS
##   vars current_slot run_id pending_world last_error autosave_enabled auto_save_interval_seconds save_dir clock_override world_scene
##
## TEST SEAMS (no behaviour of their own): save_dir, clock_override, world_scene and replace_via_old are variables; _system_bias_minutes()
## (the time zone offset used to read a v1 local time stamp), _store_text(file, text) (the one place where bytes go into the temp file)
## and _replace_file(source, destination) are methods that a test overrides in a subclass, to pin the time zone, to model a disk
## that loses bytes silently and a move that fails.

const SAVE_DIR := "user://saves"
const SAVE_FILE := "save_%d.json"
const BACKUP_FILE := "save_%d.bak.json"
const AUTO_FILE := "save_auto.json"
const PREV_AUTO_FILE := "save_auto.prev.json"
const QUARANTINE_FILE := "save_auto.damaged-%d.json"
## The run id of a save written before run ids existed starts with this (see _run_id_of).
const LEGACY_RUN_PREFIX := "legacy:"
const QUARANTINE_KEEP := 3
const PAYLOAD_VERSION := 3
const MANUAL_SLOTS := 6
const AUTO_SLOT := 6
## The autosave of the run played before this one (read only: it is loaded, never written by save_game).
const PREV_AUTO_SLOT := 7
const NO_SLOT := -1
const AUTOSAVE_INTERVAL_SECONDS := 300.0
## A failed autosave is tried again this many seconds later, not a whole interval later.
const AUTOSAVE_RETRY_SECONDS := 30.0
const WORLD_SCENE := "res://scenes/main/world.tscn"
const MAX_SAVE_BYTES := 8 * 1024 * 1024
const DEFAULT_SECTION_ORDER := 100
## Apply order of the feature sections (addendum 3.2): register_section("home", self, SaveManager.FEATURE_ORDERS["home"]).
## Furniture comes after the home (its room depends on the tier), the wardrobe and the loot after the stores they read.
const FEATURE_ORDERS := {"home": 10, "players": 15, "furniture": 20, "wardrobe": 30, "loot": 40, "collection": 50}

## Late-bound autoload lookup (an injected fake wins); a preload, not the class_name, so the autoload compiles before the class cache exists.
const SvcLib := preload("res://scripts/data/svc.gd")

## Built-in sections: [name, autoload, apply order, required, {key: type}]. Types: str, num, arr, dict, list (arr or dict).
const CORE_SECTIONS := [
	{"name": "game", "autoload": "GameManager", "order": -60, "required": true,
		"keys": {"player_name": "str", "day": "num", "season": "str", "year": "num", "character_type": "num"}},
	{"name": "time", "autoload": "TimeManager", "order": -50, "required": true, "keys": {"weather": "str"}},
	{"name": "husbandry", "autoload": "AnimalHusbandry", "order": -20, "required": false, "keys": {}},
	{"name": "shops", "autoload": "ShopSystem", "order": -10, "required": false, "keys": {}},
]
## Names a registered section may not take: they are the payload's own keys.
const RESERVED_SECTION_NAMES: Array[String] = ["meta", "world", "economy", "quests"]
const LEGACY_PLAYER_SECTIONS := [
	{"name": "economy", "autoload": "EconomyManager", "order": -40, "required": true, "keys": {"gold": "num", "inventory": "list"}},
	{"name": "quests", "autoload": "QuestManager", "order": -30, "required": true, "keys": {"active": "dict", "completed": "arr"}},
]

## Base directory of the save files (a test points it at a scratch directory; the game never changes it).
var save_dir: String = SAVE_DIR
## Manual slot (0..5) of the last manual save or of the last load from a manual slot, NO_SLOT (-1) after a new game.
## Autosaves and loads of the auto slot never change it, and it is never AUTO_SLOT.
var current_slot: int = NO_SLOT
## Identity of the running game (meta.run_id): a new one per new game, the loaded save's after a load (a new one when the save has none).
var run_id: String = ""
## The world state of the loaded save, waiting for WorldRoot2D._ready (opaque: SaveManager never looks inside).
var pending_world: Dictionary = {}
var auto_save_interval_seconds: float = AUTOSAVE_INTERVAL_SECONDS
## Switch for BOTH autosave triggers (the timer and the day end); tests of other packages may turn it off.
var autosave_enabled: bool = true
## True from a failed save until the next successful one (the HUD shows it; only the first autosave failure of a streak toasts).
var save_failing: bool = false
## {slot, code, detail} of the last failed load or save, {} after a success. code: missing corrupt invalid version apply scene slot write gather event.
var last_error: Dictionary = {}
## How a verified temp file replaces its target (see _commit_temp): through <file>.old on Windows, a plain atomic rename elsewhere.
## A test seam too (a test runs the Windows protocol on any machine).
var replace_via_old: bool = OS.get_name() == "Windows"
## Test seam: a value >= 0 replaces Time.get_unix_time_from_system() as the time stamp of a save.
var clock_override: float = -1.0
## The scene load_and_enter / continue_latest change to (a test points it at a scene that does not exist; the game never changes it).
var world_scene: String = WORLD_SCENE

var _auto_save_timer: float = 0.0
var _autosave_queued: bool = false
var _staging_roster: PlayerRoster
var _sections: Array[Dictionary] = []     # registered sections: {name, node, order, seq}
## Backup validation is pure over the payload. Cache the exact file hash and
## a content fingerprint that excludes only the two unvalidated wall clocks.
## Section registration/reset invalidates every cached validator result.
var _backup_validation: Dictionary = {}
var _section_seq: int = 0
## Sections whose to_dict() failed during the last gather_payload() (save_game refuses to write such a payload).
var _gather_failures: Array[String] = []
## sha256 and run id of the auto file this session wrote last: the next autosave need not read it again to know whose it is.
var _auto_file_seen: Dictionary = {}
## slot -> {key, info}: the last inspect_slot() verdict and what it was made from (see inspect_slot).
var _inspect_cache: Dictionary = {}
## Top-level keys of the loaded save that no section of this build owns: written back unchanged by gather_payload().
var _carried_sections: Dictionary = {}


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
	run_id = _new_run_id()
	_ensure_dir()
	_recover_interrupted_writes()
	EventBus.reset_wave_started.connect(reset)
	EventBus.day_ended.connect(_on_day_ended)
	# Present before a world exists: Continue can validate/apply every profile at the title.
	_staging_roster = PlayerRoster.new()
	add_child(_staging_roster)
	register_section("players", _staging_roster, 15)


func _process(delta: float) -> void:
	if not NetAuthority.can_write(): return
	if GameManager.current_phase != GameManager.GamePhase.PLAYING or not autosave_enabled:
		return
	_auto_save_timer += delta
	if _auto_save_timer >= auto_save_interval_seconds:
		autosave()


## New game (EventBus.new_game_started): no current slot, timers zero, nothing waits for a world, no stale error.
func reset(origin: Dictionary = {}) -> void:
	if origin.is_empty(): origin = EventBus.reset_origin()
	if not EventBus.reset_current(origin): return
	if not NetAuthority.can_write(): return
	invalidate_lifecycle()
	_backup_validation.clear()
	_inspect_cache.clear()
	run_id = _new_run_id()
	current_slot = NO_SLOT
	_auto_save_timer = 0.0
	_autosave_queued = false
	pending_world = {}
	last_error = {}
	save_failing = false
	_carried_sections = {}
	origin["stamp"] = _save_owner_stamp()


# ------------------------------------------------------------------ slots and paths

static func is_manual_slot(slot: int) -> bool:
	return slot >= 0 and slot < MANUAL_SLOTS


## A slot save_game can write: a manual slot or the auto slot.
static func is_valid_slot(slot: int) -> bool:
	return is_manual_slot(slot) or slot == AUTO_SLOT


## A slot that can be inspected and loaded: every writable slot and PREV_AUTO_SLOT.
static func is_readable_slot(slot: int) -> bool:
	return is_valid_slot(slot) or slot == PREV_AUTO_SLOT


## [0, 1, 2, 3, 4, 5, AUTO_SLOT]
static func all_slots() -> Array[int]:
	var out: Array[int] = []
	for i in MANUAL_SLOTS:
		out.append(i)
	out.append(AUTO_SLOT)
	return out


func slot_path(slot: int) -> String:
	if slot == PREV_AUTO_SLOT:
		return save_dir.path_join(PREV_AUTO_FILE)
	return save_dir.path_join(AUTO_FILE if slot == AUTO_SLOT else SAVE_FILE % slot)


## The .bak file of a manual slot; "" for the auto slots (they have none).
func backup_path(slot: int) -> String:
	return "" if slot >= AUTO_SLOT else save_dir.path_join(BACKUP_FILE % slot)


func has_save(slot: int = 0) -> bool:
	return is_readable_slot(slot) and FileAccess.file_exists(slot_path(slot))


## True when at least one slot (manual or auto) can be loaded: the Continue button's enabled state.
func has_any_save() -> bool:
	return get_latest_slot() != NO_SLOT


func delete_save(slot: int = 0) -> void:
	if not NetAuthority.can_write(): return
	if not is_valid_slot(slot):
		return
	for path in [slot_path(slot), backup_path(slot), slot_path(slot) + ".tmp", slot_path(slot) + ".old"]:
		if path != "" and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if current_slot == slot:
		current_slot = NO_SLOT


# ------------------------------------------------------------------ saving

## Saves into `slot` (0..5, or AUTO_SLOT). `is_auto` forces the auto slot whatever `slot` says (the old autosave
## overwrote the current manual slot). Autosaves are silent and leave current_slot alone; a manual save toasts
## NOTIF_SAVED_* and becomes current_slot. Returns false when the file could not be written (see _save_failed); the old file
## of the slot is then untouched.
func save_game(slot: int = 0, is_auto: bool = false) -> bool:
	if not NetAuthority.can_write(): return false
	if GameManager.is_modal_open(&"event"):
		last_error = {"slot":slot,"code":"event","detail":"scene effects have not committed"}
		return false
	if is_auto:
		slot = AUTO_SLOT
	if not is_valid_slot(slot):
		last_error = {"slot": slot, "code": "slot", "detail": "slot %d does not exist" % slot}
		return false
	var silent := slot == AUTO_SLOT
	var delivery_owner := _save_owner_stamp()
	var payload := gather_payload()
	if not NetAuthority.can_write() or delivery_owner != _save_owner_stamp(): return false
	if not _gather_failures.is_empty():
		# A section that could not describe itself would be missing from the file and reset to new-game state on the next load:
		# nothing is written, the file of the slot (and its .bak) stays as it was.
		last_error = {"slot": slot, "code": "gather", "detail": "to_dict() failed for %s" % ", ".join(_gather_failures)}
		return _save_failed(slot, silent)
	var text := JSON.stringify(payload, "\t", true, true)
	_ensure_dir()
	if not silent:
		_roll_backup(slot)
	else:
		_keep_foreign_auto_file()
	# Validation and quarantine can synchronously replace the saving world/session.
	if not NetAuthority.can_write() or delivery_owner != _save_owner_stamp(): return false
	if not _write_atomic(slot_path(slot), text):
		last_error = {"slot": slot, "code": "write", "detail": "could not write %s" % slot_path(slot)}
		return _save_failed(slot, silent)
	last_error = {}
	save_failing = false
	if silent:
		_auto_save_timer = 0.0
		_auto_file_seen = {"hash": FileAccess.get_sha256(slot_path(slot)), "run": run_id}
	else:
		current_slot = slot
	EventBus.save_completed.emit(slot)
	if not silent:
		_toast(tr("NOTIF_SAVED_TITLE"), tr("NOTIF_SAVED_MSG"), slot + 1)
	return true


## A save that could not be written (last_error is set): EventBus.save_failed, save_failing, and feedback. A manual save toasts
## NOTIF_SAVE_FAILED_*; an autosave toasts only the first failure of a streak (the HUD keeps showing it) and is tried again after
## AUTOSAVE_RETRY_SECONDS instead of a whole interval. Always false.
func _save_failed(slot: int, silent: bool) -> bool:
	if silent:
		_auto_save_timer = maxf(0.0, auto_save_interval_seconds - AUTOSAVE_RETRY_SECONDS)
		if not save_failing:
			EventBus.notification_posted.emit(tr("NOTIF_SAVE_FAILED_TITLE"), tr("NOTIF_SAVE_FAILED_AUTO_MSG"), "save")
	else:
		_toast(tr("NOTIF_SAVE_FAILED_TITLE"), tr("NOTIF_SAVE_FAILED_MSG"), slot + 1)
	save_failing = true
	EventBus.save_failed.emit(slot, str(last_error.get("code", "")))
	return false


## Writes the auto slot (never a manual one) and restarts the autosave countdown.
func autosave() -> bool:
	if not NetAuthority.can_write(): return false
	_auto_save_timer = 0.0
	return save_game(AUTO_SLOT, true)


var _queued_autosave_owner: Array = []

func _save_owner_stamp() -> Array:
	var world := PlayerRegistry.world()
	var session: Node = world.get("session") if world != null else null
	return [run_id, world.get_instance_id() if world != null else 0, session.get_instance_id() if session != null else 0, session.generation if session != null else 0, _lifecycle_revision]

func _on_day_ended(_day: int, _season: StringName) -> void:
	if not NetAuthority.can_write(): return
	if not autosave_enabled or _autosave_queued or not _game_running():
		return
	_autosave_queued = true
	_queued_autosave_owner = _save_owner_stamp()
	_run_queued_autosave.call_deferred()


func _run_queued_autosave() -> void:
	if not _autosave_queued:                   # reset() (a new game began in the same frame) dropped it: nothing of the old run is saved
		return
	_autosave_queued = false
	var owner_matches := _queued_autosave_owner == _save_owner_stamp()
	_queued_autosave_owner = []
	if not NetAuthority.can_write() or not owner_matches: return
	if autosave_enabled and _game_running():
		autosave()


## A run exists (PLAYING, or paused / in a cutscene on top of it); the menus have nothing worth saving.
func _game_running() -> bool:
	var phase: int = GameManager.current_phase
	return phase == GameManager.GamePhase.PLAYING or phase == GameManager.GamePhase.PAUSED or phase == GameManager.GamePhase.CUTSCENE


# ------------------------------------------------------------------ loading

## An offline load owns admission until its complete synchronous call returns,
## including validators, rollback snapshots, mutators and completion observers.
## Depth preserves the existing nested facade/apply calls without choosing a new
## reset/load precedence policy. reset() must not release an in-flight owner.
var _offline_load_depth := 0
## Monotonic committed incarnation, independent of the persisted run id.
var _lifecycle_revision := 0

## Deny continuation of exact pre-operation profiles until lexical unwind. This
## cannot grant/adopt authority; it keeps a restored origin suspended through
## backup validation and final observers. Nested replacement rows remain usable.
class OriginBarrier extends RefCounted:
	var profiles: Array = []

var _origin_barriers: Array[OriginBarrier] = []

func _hold_origins() -> OriginBarrier:
	var barrier := OriginBarrier.new()
	barrier.profiles = PlayerRegistry._states.values()
	_origin_barriers.append(barrier)
	return barrier

func continuation_available(profile: RefCounted) -> bool:
	for barrier: OriginBarrier in _origin_barriers:
		if profile in barrier.profiles: return false
	return true

func invalidate_lifecycle() -> void:
	_lifecycle_revision += 1

func network_admission_blocked() -> bool:
	return _offline_load_depth > 0

## Validates, then applies atomically (see the header). Does not touch the phase or the scene: the caller (load screen,
## continue_latest) enters the world. Emits load_completed(slot) on success; a manual slot becomes current_slot, the auto slot
## does not (see current_slot).
func load_game(slot: int = 0) -> bool:
	_offline_load_depth += 1
	var barrier := _hold_origins()
	# Keep the whole operation lexical: no callable unfenced implementation entry.
	var operation := func() -> bool:
		if NetAuthority.owns_network_world(): return false
		last_error = {}
		if not is_readable_slot(slot):
			return _fail_load(slot, "missing", "slot %d does not exist" % slot)
		var inspected_owner := _rollback_owner_stamp()
		var info := inspect_slot(slot)
		if inspected_owner != _rollback_owner_stamp(): return false
		match info["state"]:
			&"empty":
				return _fail_load(slot, "missing", "no save in slot %d" % slot)
			&"newer":
				return _fail_load(slot, "version", str(info["detail"]))
			&"corrupt":
				return _fail_load(slot, str(info["code"]), str(info["detail"]))
		var applied := _apply_payload(info["payload"])
		if applied.get("superseded", false): return false
		if not applied["ok"] and applied.get("backup_safe", false) and not info["from_backup"]:
			# the file passed every check and still did not apply (a section refused it): its .bak is the next best thing
			var backup_owner := _rollback_owner_stamp()
			var backup := _inspect_backup(slot)
			if backup_owner != _rollback_owner_stamp(): return false
			if not backup.is_empty():
				applied = _apply_payload(backup["payload"])
				if applied.get("superseded", false): return false
				if applied["ok"]: info = backup
		if not applied["ok"]:
			return _fail_load(slot, "apply", str(applied["detail"]))
		if is_manual_slot(slot):                   # the auto slots are not places the player saves to: keep the manual slot of this run
			current_slot = slot
		run_id = _run_id_of(info["payload"])
		if run_id.begins_with(LEGACY_RUN_PREFIX):
			run_id = _new_run_id()                 # written into every later save of this run: one derived id must never join two runs for good
		if slot == AUTO_SLOT:
			_auto_file_seen = {"hash": FileAccess.get_sha256(slot_path(slot)), "run": run_id}   # the auto file IS this run
		_auto_save_timer = 0.0
		var committed_owner := _rollback_owner_stamp()
		if info["from_backup"]:
			_toast(tr("NOTIF_LOAD_BACKUP_TITLE"), tr("NOTIF_LOAD_BACKUP_MSG"), slot + 1)
			if committed_owner != _rollback_owner_stamp(): return false
		EventBus.load_completed.emit(slot)
		return committed_owner == _rollback_owner_stamp()
	var result: bool = operation.call()
	_origin_barriers.erase(barrier)
	_offline_load_depth -= 1
	return result


## load_game(slot), then the whole way into the world: pop every modal, phase PLAYING, change to world_scene (WORLD_SCENE,
## whose WorldRoot2D takes pending_world). False (with feedback) leaves phase, scene AND the running game exactly as they were:
## a world scene that does not exist is refused before the save is applied.
func load_and_enter(slot: int) -> bool:
	_offline_load_depth += 1
	# Keep the whole operation lexical: no callable unfenced implementation entry.
	var operation := func() -> bool:
		if NetAuthority.owns_network_world(): return false
		if not ResourceLoader.exists(world_scene):          # checked BEFORE the save is applied: a load that cannot enter the world leaves no half-loaded game behind
			last_error = {}
			return _fail_load(slot, "scene", "%s does not exist" % world_scene)
		if not load_game(slot):
			return false
		var incarnation := _lifecycle_revision
		var err := get_tree().change_scene_to_file(world_scene)
		if err != OK:
			return _fail_load(slot, "scene", "could not change to %s (error %d)" % [world_scene, err])
		# An old save may contain the transient new-game opening flag. Continue/load
		# must never replay the letter or first morning when the new world enters.
		if incarnation != _lifecycle_revision: return false
		GameManager.set_flag(GameManager.FLAG_INTRO_PENDING, false)
		if incarnation != _lifecycle_revision: return false
		GameManager.pop_all_modals()
		if incarnation != _lifecycle_revision: return false
		GameManager.change_phase(GameManager.GamePhase.PLAYING)
		return incarnation == _lifecycle_revision
	var result: bool = operation.call()
	_offline_load_depth -= 1
	return result


## The Continue button of the title screen: loads the newest save (get_latest_slot) and enters the world.
func continue_latest() -> bool:
	_offline_load_depth += 1
	# Keep the whole operation lexical: no callable unfenced implementation entry.
	var operation := func() -> bool:
		if NetAuthority.owns_network_world(): return false
		var inspected_owner := _rollback_owner_stamp()
		var inspected_profiles := PlayerRegistry._states.duplicate()
		var slot := get_latest_slot()
		if inspected_owner != _rollback_owner_stamp() or not _profiles_current(inspected_profiles): return false
		if slot == NO_SLOT:
			last_error = {}
			return _fail_load(NO_SLOT, "missing", "no loadable save in any slot")
		return load_and_enter(slot)
	var result: bool = operation.call()
	_offline_load_depth -= 1
	return result


## The world dictionary of the loaded game, once: WorldRoot2D._ready calls it after its areas and player exist.
func consume_pending_world() -> Dictionary:
	if not NetAuthority.can_write(): return {}
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
## as ints) is set for ok and backup. The verdict is memoised by the sha256 of the slot's file and .bak, the section nodes that
## validated it and the time zone that dated a v1 stamp (_inspect_cache), so the title and the slot list do not parse and validate
## every file again on every refresh.
func inspect_slot(slot: int) -> Dictionary:
	if not is_readable_slot(slot):
		return _inspect_uncached(slot)
	var bak_path := backup_path(slot)
	var key := "%s|%s|%s|%d" % [_file_digest(slot_path(slot)), _file_digest(bak_path) if bak_path != "" else "", _validator_key(), _system_bias_minutes()]
	var cached: Dictionary = _inspect_cache.get(slot, {})
	if str(cached.get("key", "")) != key:
		cached = {"key": key, "info": _inspect_uncached(slot)}
		_inspect_cache[slot] = cached
	return (cached["info"] as Dictionary).duplicate(true)


## "" for a missing file, else its sha256.
func _file_digest(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""


## Which nodes validate a payload right now (a section registered, replaced or overridden changes the verdict of the same bytes).
func _validator_key() -> String:
	var ids: Array[String] = []
	for entry in _ordered_entries():
		var node := _node_of(entry)
		ids.append("%s:%d" % [entry["name"], node.get_instance_id() if node != null else 0])
	return ",".join(ids)


func _inspect_uncached(slot: int) -> Dictionary:
	var out := {"state": &"empty", "code": "missing", "detail": "", "payload": {}, "from_backup": false, "saved_at": 0.0}
	if not is_readable_slot(slot):
		out["detail"] = "slot %d does not exist" % slot
		return out
	var primary := _read_json_file(slot_path(slot))
	var failure := {"code": "corrupt", "detail": str(primary.get("detail", ""))}
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
	var backup := _inspect_backup(slot)
	if not backup.is_empty():
		return backup
	if primary["state"] == "missing" and (bak_path == "" or not FileAccess.file_exists(bak_path)):
		return out
	out["state"] = &"corrupt"
	out["code"] = failure["code"]
	out["detail"] = failure["detail"]
	return out


## inspect_slot's verdict for the .bak of a manual slot alone (state &"backup"), {} when there is none that loads.
func _inspect_backup(slot: int) -> Dictionary:
	var bak_path := backup_path(slot)
	if bak_path == "" or not FileAccess.file_exists(bak_path):
		return {}
	var backup := _read_json_file(bak_path)
	if backup["state"] != "ok":
		return {}
	var checked := validate_payload(backup["data"])
	if not checked["ok"]:
		return {}
	var out := {"state": &"empty", "code": "missing", "detail": "", "payload": {}, "from_backup": false, "saved_at": 0.0}
	return _inspect_result(out, &"backup", checked["payload"], true)


func _inspect_result(out: Dictionary, state: StringName, payload: Dictionary, from_backup: bool) -> Dictionary:
	out["state"] = state
	out["code"] = ""
	out["payload"] = payload
	out["from_backup"] = from_backup
	out["saved_at"] = _saved_at_of(payload)
	return out


## What the slot list shows: {} for an empty, damaged or newer-version slot, else farm name, character, day, season,
## year, total_day, gold, play time, hour/minute, area, time stamp (+ slot, is_auto, is_previous, from_backup). player_name, day,
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
	summary["is_auto"] = slot >= AUTO_SLOT
	summary["is_previous"] = slot == PREV_AUTO_SLOT
	summary["from_backup"] = info["from_backup"]
	summary["timestamp"] = str(meta.get("timestamp", ""))
	summary["saved_at"] = info["saved_at"]
	return summary


## Newest loadable save across the manual slots and the auto slot (NO_SLOT when there is none). The time stamp is
## meta.saved_at (meta.timestamp for v1 saves); a tie goes to the lower manual slot, then to the auto slot.
## Damaged slots without a usable .bak, and saves of a newer build, are skipped: Continue never picks them.
func get_latest_slot() -> int:
	return latest_slot_of(describe_slots())


## get_latest_slot() over rows of describe_slots() that the caller already has (the title reads the slots once per refresh).
static func latest_slot_of(rows: Array[Dictionary]) -> int:
	var best := NO_SLOT
	var best_time := -INF
	for row in rows:
		var slot := int(row["slot"])
		if not is_valid_slot(slot) or (row["state"] != &"ok" and row["state"] != &"backup"):
			continue
		var stamp := float((row["summary"] as Dictionary).get("saved_at", 0.0))
		if stamp > best_time:
			best_time = stamp
			best = slot
	return best


## One row per slot, manual slots first, then the auto slot, then PREV_AUTO_SLOT when its file exists:
## [{slot, is_auto, is_previous, state, summary}].
func describe_slots() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var slots := all_slots()
	if has_save(PREV_AUTO_SLOT):
		slots.append(PREV_AUTO_SLOT)
	for slot in slots:
		var info := inspect_slot(slot)
		rows.append({"slot": slot, "is_auto": slot >= AUTO_SLOT, "is_previous": slot == PREV_AUTO_SLOT, "state": info["state"], "summary": _summary_of(info, slot)})
	return rows


# ------------------------------------------------------------------ section registry

## Registers a state-owning node (addendum 3.2): `node` offers to_dict() -> Dictionary, from_dict(d) and reset().
## Sections apply in ascending `order`, equal orders in registration order. Registering a name again replaces the node and
## order. Returns false (with an error) for a bad name, a node without the three methods, or a built-in/reserved name.
func register_section(section_name: String, node: Node, order: int = DEFAULT_SECTION_ORDER) -> bool:
	_backup_validation.clear()
	_inspect_cache.clear()
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
	_backup_validation.clear()
	_inspect_cache.clear()
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
## the world. `quests` carries no Lua definitions. A section whose to_dict() does not return a Dictionary is left out and
## named in _gather_failures, which makes save_game() refuse to write the payload.
func gather_payload() -> Dictionary:
	if not NetAuthority.can_write(): return {}
	var gather_owner := _save_owner_stamp()
	var live_world := PlayerRegistry.world()
	_gather_failures.clear()
	# Refuse this incomplete live-world case before codecs can create/default
	# a missing host profile. No body means no authoritative final pose/hotbar.
	if live_world != null and live_world.has_method("save_body_available") and not live_world.call("save_body_available"):
		_gather_failures.append("world")
		return {}
	if live_world != null and live_world.get("roster") != null: live_world.roster.capture_live_bodies(live_world)
	var payload: Dictionary = {}
	for entry in _ordered_entries():
		var node := _node_of(entry)
		if node == null or not node.has_method("to_dict"):
			continue
		var data: Variant = node.call("to_dict")
		if not NetAuthority.can_write() or gather_owner != _save_owner_stamp(): return {}
		if typeof(data) != TYPE_DICTIONARY:
			push_error("SaveManager: %s.to_dict() did not return a Dictionary, the section '%s' is not saved" % [node.name, entry["name"]])
			_gather_failures.append(str(entry["name"]))
			continue
		payload[entry["name"]] = _json_safe(data, str(entry["name"]))
	if not payload.has("players"): payload["players"] = _json_safe(_staging_roster.to_dict(), "players")
	_strip_quest_defs(payload)
	for key in _carried_sections:
		if not payload.has(key):
			payload[key] = (_carried_sections[key] as Variant)
	var world_data: Variant = _gather_world()
	if not NetAuthority.can_write() or gather_owner != _save_owner_stamp(): return {}
	if not world_data is Dictionary:
		_gather_failures.append("world")
		return {}
	payload["world"] = _json_safe(world_data, "world")
	if payload.get("players") is Dictionary:
		var rows: Dictionary = payload.players.get("rows", {})
		var local: Dictionary = rows.get(str(PlayerRegistry.local_id()), {})
		for key in ["area", "player_pos", "hotbar"]:
			if payload.world.has(key): local[key] = payload.world[key]
		var body := PlayerRegistry.local_player()
		if body != null:
			for key in ["half_hearts", "stamina", "oil"]:
				if key in body: local[key] = body.get(key)
	var stamp := clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()
	payload["meta"] = {
		"version": PAYLOAD_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"saved_at": stamp,
		"run_id": run_id,
		"summary": _summarize(payload),
	}
	return payload


## The live world's to_dict(); without a world (title screen, world not built yet after a load) the state that is still
## waiting in pending_world, so a save made in between does not lose the world.
## A live serializer's refusal must propagate, never fall back to stale pending data.
func _gather_world() -> Variant:
	if not NetAuthority.can_write(): return null
	var tree := get_tree()
	var world: Node = tree.get_first_node_in_group(&"world_2d") if tree != null else null
	if world != null and world.has_method("to_dict"):
		return world.call("to_dict")
	return pending_world.duplicate(true)


## Quest definitions are Lua, never saved. QuestManager of the first waves kept them in quest_flags as "def_<id>".
func _strip_quest_defs(payload: Dictionary) -> void:
	var logs: Array = [_dict_of(payload.get("quests"))]
	for row in _dict_of(_dict_of(payload.get("players")).get("rows")).values():
		if row is Dictionary: logs.append(_dict_of(row.get("quests")))
	for log in logs:
		var flags: Dictionary = _dict_of(log.get("flags"))
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
	if version < 3:
		for entry in LEGACY_PLAYER_SECTIONS:
			var section: Variant = payload.get(entry.name)
			if not section is Dictionary: return _verdict(false, "invalid", "legacy section '%s' is missing or invalid" % entry.name)
			for key in entry.keys:
				if not section.has(key) or not _has_type(section[key], entry.keys[key]): return _verdict(false, "invalid", "legacy section '%s' lacks valid '%s'" % [entry.name, key])
			var declared := _declared_version(SvcLib.node(entry.autoload))
			var written: Variant = section.get("v", 1)
			if declared > 0 and _is_number(written) and float(written) > declared:
				return _verdict(false, "version", "legacy section '%s' is newer than this build" % entry.name)
	payload = _migrate(payload, version)
	if not payload.get("players") is Dictionary: return _verdict(false, "invalid", "section 'players' is missing or invalid")
	# Always validate profiles, including while no WorldRoot2D exists or a test detaches sections.
	var profiles := PlayerRoster.new()
	var profiles_valid := profiles.validate_dict(payload.players)
	profiles.free()
	for row in _dict_of(payload.players.get("rows")).values():
		if not row is Dictionary: continue
		for field in ["quests", "wardrobe"]:
			var manager := SvcLib.node("QuestManager" if field == "quests" else "WardrobeManager")
			var declared := _declared_version(manager)
			var written: Variant = _dict_of(row.get(field)).get("v", 1)
			if declared > 0 and _is_number(written) and float(written) > declared:
				return _verdict(false, "version", "player %s section is newer than this build" % field)
	if not profiles_valid: return _verdict(false, "invalid", "section 'players' contains invalid records")
	if _is_number(payload.players.get("v", 1)) and float(payload.players.get("v", 1)) > 1: return _verdict(false, "version", "players section is newer than this build")
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
			var declared := _declared_version(node)
			var written: Variant = (section as Dictionary).get("v", (section as Dictionary).get("version"))
			if declared > 0 and _is_number(written) and float(written) > float(declared):
				return _verdict(false, "version", "section '%s' has version %s, this build reads up to %d" % [section_name, str(written), declared])
			if node != null and node.has_method("validate_dict") and not bool(node.call("validate_dict", section)):
				return _verdict(false, "invalid", "section '%s' contains invalid records" % section_name)
		elif entry.get("required", false):
			return _verdict(false, "invalid", "section '%s' is missing" % section_name)
	if payload.has("world") and typeof(payload["world"]) != TYPE_DICTIONARY:
		return _verdict(false, "invalid", "world is not an object")
	var saved_world: Dictionary = payload.get("world", {})
	if saved_world.has("farm") and not SvcLib.static_call("res://scripts/world2d/farm_grid.gd", &"validate_dict", [saved_world.farm], true):
		return _verdict(false, "invalid", "world contains invalid crop records")
	if saved_world.has("greenhouse_farm") and not SvcLib.static_call("res://scripts/world2d/farm_grid.gd", &"validate_dict", [saved_world.greenhouse_farm], true):
		return _verdict(false, "invalid", "world contains invalid greenhouse crops")
	if not SvcLib.static_call("res://scripts/farm/farm_equipment.gd", &"validate_placed", [saved_world.get("placed", [])], true):
		return _verdict(false, "invalid", "world contains invalid farm equipment")
	return _verdict(true, "", "", payload)


## The section version a node's script declares (SECTION_VERSION, SAVE_VERSION or SAVE_V), 0 when it declares none.
func _declared_version(node: Node) -> int:
	var script: Script = node.get_script() if node != null else null
	if script == null:
		return 0
	var constants := script.get_script_constant_map()
	for name in ["SECTION_VERSION", "SAVE_VERSION", "SAVE_V"]:
		if constants.get(name) is int:
			return int(constants[name])
	return 0


func _verdict(ok: bool, code: String, detail: String, payload: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "code": code, "detail": detail, "payload": payload}


## Brings an older payload up to PAYLOAD_VERSION one step at a time: _migrate_<from>_to_<from + 1>.
func _migrate(payload: Dictionary, from_version: int) -> Dictionary:
	var version := from_version
	while version < PAYLOAD_VERSION:
		match version:
			1:
				payload = _migrate_1_to_2(payload)
			2:
				payload = _migrate_2_to_3(payload)
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


## v2 -> v3 (RM5): the single implicit player becomes players.rows.p0. gold / inventory / equipment come from
## economy, the quest log from quests, the wardrobe from wardrobe, travel from world. The old sections stay.
func _migrate_2_to_3(payload: Dictionary) -> Dictionary:
	if payload.has("players"):
		return payload
	var game: Dictionary = _dict_of(payload.get("game"))
	var economy: Dictionary = _dict_of(payload.get("economy"))
	var quests: Dictionary = _dict_of(payload.get("quests"))
	var wardrobe: Dictionary = _dict_of(payload.get("wardrobe"))
	var world: Dictionary = _dict_of(payload.get("world"))
	var row := {
		"id": "p0",
		"peer_ordinal": 1,
		"name": str(game.get("player_name", "")),
		"character_type": int(game.get("character_type", 0)),
		"character_skin": str(game.get("character_skin", "")),
		"gold": economy.get("gold", 0),
		"inventory": economy.get("inventory", []),
		"owed": economy.get("owed", []),
		"equipment": economy.get("equipment", {}) if economy.get("equipment") is Dictionary else {},
		"arsenal": economy.get("arsenal", {}) if economy.get("arsenal") is Dictionary else {},
		"quests": quests.duplicate(true) if not quests.is_empty() else {},
		"wardrobe": wardrobe.duplicate(true) if not wardrobe.is_empty() else {},
		"hotbar": world.get("hotbar", {}) if world.get("hotbar") is Array or world.get("hotbar") is Dictionary else {},
		"area": str(world.get("area", "")),
		"player_pos": world.get("player_pos", [0.0, 0.0]) if world.get("player_pos") is Array else [0.0, 0.0],
		"half_hearts": 10,
		"stamina": 100.0,
		"oil": 150.0,
	}
	# v2 also allowed id -> count backpacks.
	if row.inventory is Dictionary:
		var slots := []
		for id in row.inventory: slots.append({"id": str(id), "amount": row.inventory[id], "meta": {}})
		row.inventory = slots
	row["flags"] = {}
	var flags: Dictionary = _dict_of(game.get("world_flags"))
	for key in flags.keys():
		if str(key).begins_with("friend_"):
			row.flags[str(key)] = flags[key]
			flags.erase(key)
	payload["players"] = {"v": 1, "rows": {"p0": row}}
	var meta: Dictionary = _dict_of(payload.get("meta"))
	if not meta.has("migrated_from"):
		meta["migrated_from"] = 2
	meta["summary"] = _summarize(payload)
	payload["meta"] = meta
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
	if not summary.get("players") is Array or summary.players.is_empty(): return false
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
	var player_rows: Dictionary = _dict_of(_dict_of(payload.get("players")).get("rows"))
	var primary: Dictionary = _dict_of(player_rows.get("p0"))
	var players := []
	for id in ["p0", "p1", "p2", "p3"]:
		if not player_rows.has(id): continue
		var row: Dictionary = player_rows[id]
		players.append({"id": id, "name": str(row.get("name", "")), "character_type": _int_of(row.get("character_type")), "character_skin": str(row.get("character_skin", "")), "gold": _int_of(row.get("gold"))})
	var type_keys: Array = GameManager.CharacterType.keys()
	var character_type := clampi(_int_of(primary.get("character_type", game.get("character_type", 0))), 0, type_keys.size() - 1)
	var season := StringName(str(game.get("season", "")))
	var day := _int_of(game.get("day", 1), 1)
	var year := _int_of(game.get("year", 1), 1)
	return {
		"players": players,
		"player_name": str(primary.get("name", game.get("player_name", ""))),
		"farm_name": str(game.get("farm_name", "")),
		"character": str(type_keys[character_type]).to_lower(),
		"character_skin": str(primary.get("character_skin", game.get("character_skin", ""))),
		"day": day,
		"season": str(season),
		"year": year,
		"total_day": _int_of(game.get("total_day", GameManager.total_day_for(day, season, year)), 1),
		"gold": _int_of(primary.get("gold", economy.get("gold", 0))),
		"play_time_seconds": float(game.get("play_time_seconds", 0.0)) if _is_number(game.get("play_time_seconds", 0.0)) else 0.0,
		"hour": _int_of(game.get("hour", 0)),
		"minute": _int_of(game.get("minute", 0)),
		"area": str(world.get("area", "")),
	}


# ------------------------------------------------------------------ payload: apply

func _profiles_current(expected: Dictionary) -> bool:
	for id in expected:
		if PlayerRegistry.peek_state(id) != expected[id]: return false
	return true

func _superseded_apply(owner: Array, detail: String) -> Dictionary:
	# A departed body/replaced codec/profile is not necessarily a successful
	# nested load. Revoke the unsafe old run without changing a newer winner.
	if owner[0] == _save_owner_stamp(): invalidate_lifecycle()
	return {"ok": false, "detail": detail, "superseded": true}

func _rollback_owner_stamp() -> Array:
	var bodies: Array = []
	for body in PlayerRegistry.all_players():
		bodies.append([body.get_instance_id(), PlayerRegistry.registered_id(body)])
	return [_save_owner_stamp(), bodies, _validator_key()]

## Applies a validated payload to the sections, all or nothing. {ok, detail}. See the header (LOADING).
func _apply_payload(payload: Dictionary) -> Dictionary:
	_offline_load_depth += 1
	var barrier := _hold_origins()
	# Keep the whole operation lexical: no callable unfenced implementation entry.
	var operation := func() -> Dictionary:
		if NetAuthority.owns_network_world(): return {"ok": false, "detail": "network world owns lifecycle"}
		if not payload.has("wardrobe") and payload.get("players") is Dictionary:
			payload = payload.duplicate(true)
			payload["wardrobe"] = payload.players.rows.p0.get("wardrobe", {})
		var entries := _ordered_entries()
		if not has_section("players") and is_instance_valid(_staging_roster):
			entries.append({"name": "players", "node": _staging_roster, "order": 15, "seq": -1})
			entries.sort_custom(_entry_before)
		var snapshot: Dictionary = {}
		var identities: Array[Callable] = []
		var owner := _rollback_owner_stamp()
		var profiles := PlayerRegistry._states.duplicate()
		var guard := ApplyGuard.new()
		OS.add_logger(guard)
		var apply := func() -> Dictionary:
			# Preflight every mutating section before the first write. A failed
			# snapshot is not an empty preimage and cannot authorize restoration.
			for entry in entries:
				var node := _node_of(entry)
				if node == null: continue
				if not node.has_method("from_dict") and not node.has_method("reset"): continue
				if not node.has_method("to_dict") or not node.has_method("from_dict"):
					return {"ok": false, "detail": "section '%s' lacks rollback codec" % entry.name}
				var before: Variant = node.call("to_dict")
				if owner != _rollback_owner_stamp() or not _profiles_current(profiles):
					return _superseded_apply(owner, "snapshot owner superseded")
				if guard.errors > 0 or not before is Dictionary:
					return {"ok": false, "detail": "section '%s' snapshot failed" % entry.name}
				var valid := not node.has_method("validate_dict") or bool(node.call("validate_dict", before))
				if owner != _rollback_owner_stamp() or not _profiles_current(profiles):
					return _superseded_apply(owner, "snapshot validator superseded")
				if guard.errors > 0:
					return {"ok": false, "detail": "section '%s' snapshot validator failed" % entry.name}
				if not valid:
					return {"ok": false, "detail": "section '%s' snapshot invalid" % entry.name}
				snapshot[entry.name] = before.duplicate(true)
			for entry in entries:
				var node := _node_of(entry)
				if node != null and node.has_method("capture_rollback_identity"):
					identities.append(node.call("capture_rollback_identity"))
			var failure := ""
			var backup_safe := false
			var touched: Array[Dictionary] = []
			for entry in entries:
				var node := _node_of(entry)
				if node == null: continue
				var section_name: String = entry.name
				if payload.has(section_name):
					if not node.has_method("from_dict"): continue
					touched.append(entry)
					var result: Variant = node.call("from_dict", (payload[section_name] as Dictionary).duplicate(true))
					if section_name == "players": profiles = PlayerRegistry._states.duplicate()
					if typeof(result) == TYPE_BOOL and not result:
						failure = "section '%s' rejected its data" % section_name
				elif node.has_method("reset"):
					touched.append(entry)
					node.call("reset")
				if owner != _rollback_owner_stamp() or not _profiles_current(profiles):
					return _superseded_apply(owner, "apply owner superseded")
				if failure == "" and guard.errors > 0:
					failure = "section '%s' raised an error: %s" % [section_name, guard.first]
				if failure != "": break
			if failure == "":
				invalidate_lifecycle()
				pending_world = _dict_of(payload.get("world")).duplicate(true)
				var known := section_names()
				_carried_sections = {}
				for key in payload:
					if not (str(key) in known) and not (str(key) in RESERVED_SECTION_NAMES):
						_carried_sections[str(key)] = payload[key].duplicate(true) if payload[key] is Dictionary or payload[key] is Array else payload[key]
			else:
				var restored := true
				var values_restored := true
				var rollback_errors := guard.errors
				# A callback can mutate a section beyond the applied prefix.
				# Restore every certified preimage, not only direct mutator calls.
				for entry in entries:
					if not snapshot.has(entry.name): continue
					var node := _node_of(entry)
					if node == null:
						restored = false
						continue
					if not touched.has(entry):
						var current_data: Variant = node.call("to_dict")
						if owner != _rollback_owner_stamp() or not _profiles_current(profiles):
							return _superseded_apply(owner, failure + "; rollback superseded")
						if current_data is Dictionary and JSON.stringify(current_data, "", true, true) == JSON.stringify(snapshot[entry.name], "", true, true): continue
					var result: Variant = node.call("restore_rollback" if node.has_method("restore_rollback") else "from_dict", snapshot[entry.name].duplicate(true))
					if entry.name == "players": profiles = PlayerRegistry._states.duplicate()
					if owner != _rollback_owner_stamp() or not _profiles_current(profiles):
						return _superseded_apply(owner, failure + "; rollback superseded")
					if typeof(result) == TYPE_BOOL and not result: restored = false
				for entry in entries:
					if not snapshot.has(entry.name): continue
					var node := _node_of(entry)
					if node == null:
						values_restored = false
						continue
					var after: Variant = node.call("to_dict")
					if owner != _rollback_owner_stamp() or not _profiles_current(profiles):
						return _superseded_apply(owner, failure + "; rollback verification superseded")
					if not after is Dictionary or JSON.stringify(after, "", true, true) != JSON.stringify(snapshot[entry.name], "", true, true):
						values_restored = false
				if guard.errors != rollback_errors or owner != _rollback_owner_stamp(): values_restored = false
				backup_safe = values_restored
				restored = restored and values_restored
				if restored:
					# The operation, not an error code or equal run id, owns this
					# callback-free publication of its authenticated preimage.
					for restore: Callable in identities: restore.call()
				else:
					failure += "; rollback incomplete"
					invalidate_lifecycle()
			return {"ok": failure == "", "detail": failure, "revision": _lifecycle_revision, "backup_safe": backup_safe}
		var applied: Dictionary = apply.call()
		OS.remove_logger(guard)
		return applied
	var result: Dictionary = operation.call()
	_origin_barriers.erase(barrier)
	_offline_load_depth -= 1
	return result


# ------------------------------------------------------------------ runs and the auto file

func _new_run_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


## meta.run_id of a payload; a save written before run ids existed gets LEGACY_RUN_PREFIX + who played it (name, farm, hero). That
## derived id never equals the id of a running game (load_game gives such a run a new one), so an old auto file is only ever
## overwritten without a copy when this session loaded that very file (_auto_file_seen).
func _run_id_of(payload: Dictionary) -> String:
	var meta: Dictionary = _dict_of(payload.get("meta"))
	if meta.get("run_id") is String and str(meta["run_id"]) != "":
		return str(meta["run_id"])
	var game: Dictionary = _dict_of(payload.get("game"))
	return LEGACY_RUN_PREFIX + "%s|%s|%s" % [str(game.get("player_name", "")), str(game.get("farm_name", "")), str(game.get("character_type", ""))]


## Before an autosave replaces save_auto.json (see RUNS in the header): the autosave of another run becomes save_auto.prev.json,
## a file that does not load is quarantined. Neither ever stops the autosave itself.
func _keep_foreign_auto_file() -> void:
	var delivery_owner := _save_owner_stamp()
	var path := slot_path(AUTO_SLOT)
	if not FileAccess.file_exists(path):
		return
	if str(_auto_file_seen.get("run", "")) == run_id and str(_auto_file_seen.get("hash", "")) == FileAccess.get_sha256(path):
		return                                 # the file this session wrote last for this run
	var parsed := _read_json_file(path)
	var checked := validate_payload(parsed["data"]) if parsed["state"] == "ok" else {"ok": false}
	if not NetAuthority.can_write() or delivery_owner != _save_owner_stamp(): return
	if not checked["ok"]:
		_quarantine_auto_file(path)
		return
	if _run_id_of(checked["payload"]) == run_id:
		return
	var temp := slot_path(PREV_AUTO_SLOT) + ".tmp"
	if DirAccess.copy_absolute(path, temp) != OK:
		DirAccess.remove_absolute(temp)
		return
	_commit_temp(temp, slot_path(PREV_AUTO_SLOT))


## Moves an auto file that does not load to save_auto.damaged-<unix>.json and keeps only the newest QUARANTINE_KEEP of those.
func _quarantine_auto_file(path: String) -> void:
	var delivery_owner := _save_owner_stamp()
	var stamp := int(clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system())
	var target := save_dir.path_join(QUARANTINE_FILE % stamp)
	while FileAccess.file_exists(target):
		stamp += 1
		target = save_dir.path_join(QUARANTINE_FILE % stamp)
	if _replace_file(path, target) != OK:
		return
	print("[Save] the auto file did not load; it was kept as %s" % ProjectSettings.globalize_path(target))
	EventBus.notification_posted.emit(tr("NOTIF_AUTO_SET_ASIDE_TITLE"), tr("NOTIF_AUTO_SET_ASIDE_MSG") % target.get_file(), "save")
	if not NetAuthority.can_write() or delivery_owner != _save_owner_stamp(): return
	var kept: Array[String] = []
	for file_name in DirAccess.get_files_at(save_dir):
		if file_name.begins_with("save_auto.damaged-") and file_name.ends_with(".json"):
			kept.append(file_name)
	kept.sort_custom(func(a: String, b: String) -> bool: return _quarantine_stamp(a) > _quarantine_stamp(b))
	for i in range(QUARANTINE_KEEP, kept.size()):
		DirAccess.remove_absolute(save_dir.path_join(kept[i]))


static func _quarantine_stamp(file_name: String) -> int:
	return int(file_name.trim_prefix("save_auto.damaged-").trim_suffix(".json"))


# ------------------------------------------------------------------ files

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)


## Finishes or undoes a write that a crash (or a failed move) interrupted, at start-up. <file>.tmp next to an intact <file> is
## garbage (the crash came before the rename) and is removed. A <file>.tmp WITHOUT <file> is a verified write whose move failed
## (or a Windows replacement cut off after the old file was moved aside): when it parses as a JSON object it becomes the file.
## A <file>.old (the file a Windows replacement moved aside) is put back when nothing better took its place, else removed.
func _recover_interrupted_writes() -> void:
	var files := DirAccess.get_files_at(save_dir)
	for file_name in files:
		if not file_name.ends_with(".tmp"):
			continue
		var temp := save_dir.path_join(file_name)
		var target := temp.trim_suffix(".tmp")
		if not FileAccess.file_exists(target) and _read_json_file(temp)["state"] == "ok" and _replace_file(temp, target) == OK:
			continue
		DirAccess.remove_absolute(temp)
	for file_name in files:
		if not file_name.ends_with(".old"):
			continue
		var old := save_dir.path_join(file_name)
		var target := old.trim_suffix(".old")
		if FileAccess.file_exists(target) or _replace_file(old, target) != OK:
			DirAccess.remove_absolute(old)


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


## Temp file, read back and compared, then moved over the target (_commit_temp). False leaves the target as it was.
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
	return _commit_temp(temp, path)


## Moves a verified temp file over `path`. A POSIX rename replaces the target atomically. The engine's Windows rename deletes the
## target and THEN moves (DirAccessWindows::rename), so a move that fails there (an antivirus or backup tool holding the temp)
## would leave no file at all: with replace_via_old the old file is first moved aside to <path>.old, the temp moved in, the .old
## removed, and a failed move puts the .old back. A verified temp is never deleted while the target is missing; whatever a
## failure leaves behind, _recover_interrupted_writes() sorts out at the next start.
func _commit_temp(temp: String, path: String) -> bool:
	if not replace_via_old:
		if _replace_file(temp, path) == OK:
			return true
		if _occupied(path):                    # the old file is still there: the temp is only garbage
			DirAccess.remove_absolute(temp)
		return false
	var old := path + ".old"
	var had_target := FileAccess.file_exists(path)
	if had_target:
		if FileAccess.file_exists(old):
			DirAccess.remove_absolute(old)
		if _replace_file(path, old) != OK:     # nothing was moved: the target is as it was
			DirAccess.remove_absolute(temp)
			return false
	if _replace_file(temp, path) != OK:
		if had_target and _replace_file(old, path) == OK:
			DirAccess.remove_absolute(temp)
		return false
	if had_target:
		DirAccess.remove_absolute(old)
	return true


## A file or a directory sits at `path`.
func _occupied(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


## Replacement failure must preserve the existing file; also a seam for disk-failure probes.
func _replace_file(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(source, destination)


## A manual save keeps the file it replaces as save_N.bak.json, but only when that file is a valid payload, so a damaged
## file never replaces a good .bak.
func _roll_backup(slot: int) -> void:
	var delivery_owner := _save_owner_stamp()
	var path := slot_path(slot)
	var backup := backup_path(slot)
	if backup == "" or not FileAccess.file_exists(path):
		return
	var digest := FileAccess.get_sha256(path)
	var validated: Dictionary = _backup_validation.get(path, {})
	if digest == "" or str(validated.get("hash", "")) != digest:
		var previous := _read_json_file(path)
		var signature := _backup_signature(previous["data"]) if previous["state"] == "ok" else ""
		var same_content := signature!="" and signature==str(validated.get("content", ""))
		var valid: bool = bool(validated.get("valid", false)) if same_content else (previous["state"] == "ok" and bool(validate_payload(previous["data"])["ok"]))
		validated = {"hash": digest, "content": signature, "valid": valid}
		_backup_validation[path] = validated
	if not NetAuthority.can_write() or delivery_owner != _save_owner_stamp(): return
	if not bool(validated.get("valid", false)):
		return
	var temp := backup + ".tmp"
	if DirAccess.copy_absolute(path, temp) != OK:
		DirAccess.remove_absolute(temp)
		return
	_commit_temp(temp, backup)


# ------------------------------------------------------------------ feedback

## A toast of two translated texts; `arg` fills a %d / %s in the message (a missing translation returns the raw key, which
## has no placeholder and must not reach the formatter).
func _toast(title: String, message: String, arg: int) -> void:
	if message.contains("%d") or message.contains("%s"):
		message = message % arg
	EventBus.notification_posted.emit(title, message, "save")

## validate_payload checks meta.version and every state section; these two
## informational real clocks never affect its verdict. All other bytes,
## including economy/flags/version/unknown metadata, remain in the signature.
func _backup_signature(payload: Dictionary) -> String:
	var content := payload.duplicate()
	if content.get("meta") is Dictionary:
		var meta: Dictionary = content.meta.duplicate()
		meta.erase("saved_at")
		meta.erase("timestamp")
		content.meta=meta
	return JSON.stringify(content,"",true,true).sha256_text()
