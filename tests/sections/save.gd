extends RefCounted
## Section save (package P15): SaveManager - payload v2, validation before apply, atomic apply, the section registry,
## manual slots + the auto slot, summaries, latest slot, Continue, the world hand-off.
##
## Named checks (plan 8.2 / 8.5 / addendum 4.4): save.roundtrip_all_systems, save.continue_from_menu,
## save.corrupt_and_foreign_saves, save.autosave_never_overwrites_manual, save.section_registry_order_and_reset,
## save.missing_section_resets, save.validate_before_apply, save.atomic_apply_rolls_back, save.world_dict_contract.
## Fix round 2 (review of wave 3): autosave_default_interval_five_minutes, autosave_disabled_day_end*, latest_sub_second_*,
## delete_save_*, load_auto_slot_keeps_*, summary_wrong_types_*, v1_time_stamp_is_local_time*, short_write_*.
## M1b fix round 0 (RT1): the registry checks (registry_*, feature_orders_*, section_registry_order_and_reset, missing_section_resets) run with
## the REAL feature sections (HomeManager ... SocialManager) detached and registered again afterwards, so they hold whatever feature manager
## exists: registry_tests_keep_real_sections (two stand-ins named like real sections, home and social, must come back unchanged).
##
## The section is a sandbox. Every file it writes goes to a scratch directory below user:// (SaveManager.save_dir is
## redirected, the real user://saves is compared before and after), and tests/run_playtest.sh runs it in a throwaway
## HOME on top of that. It drives the autoloads synchronously and leaves a fresh MENU state behind. The cross-system
## round trip of the crops, the placed items, the hotbar and the player is closed by farm.save_roundtrip (P06),
## animals.save_roundtrip (P20) and zz_acceptance (P27): here the world is an opaque dictionary.
const SECTION := "save"
const TIMEOUT_S := 150.0

## The summary a load screen formats: key -> kind ("str" String, "int" whole number, "num" any number). The test's own copy: it is
## the oracle of what a consumer needs, not a read-back of SaveManager's constant.
const SUMMARY_KINDS := {
	"player_name": "str", "farm_name": "str", "character": "str", "character_skin": "str", "day": "int", "season": "str", "year": "int",
	"total_day": "int", "gold": "int", "play_time_seconds": "num", "hour": "int", "minute": "int", "area": "str",
}

const SVC := "res://scripts/data/svc.gd"
const WORLD_SCENE := "res://scenes/main/world.tscn"

## Failure code -> the translation key SaveManager posts as the message.
const FAIL_KEYS := {
	"missing": "NOTIF_LOAD_FAILED_MISSING",
	"corrupt": "NOTIF_LOAD_FAILED_CORRUPT",
	"invalid": "NOTIF_LOAD_FAILED_CORRUPT",
	"version": "NOTIF_LOAD_FAILED_VERSION",
	"apply": "NOTIF_LOAD_FAILED_APPLY",
}


## A state-owning node as the feature managers will be: to_dict / from_dict / reset (+ switches to misbehave).
class FakeSection extends Node:
	var tag := ""
	var log: Array = []                       # shared with the test
	var data: Dictionary = {"v": 1, "n": 0}
	var mode := ""                            # "" | "error" (ONE script error in from_dict) | "reject" (from_dict returns false)
	var probe: Callable = Callable()          # evaluated when from_dict runs: what did the other sections look like by then?
	var apply_calls := 0
	var reset_calls := 0
	var seen_day := 0

	func to_dict() -> Dictionary:
		return data.duplicate(true)

	func from_dict(d: Dictionary) -> Variant:
		apply_calls += 1
		var note := "apply:" + tag
		if probe.is_valid():
			note += ":" + str(probe.call())
		log.append(note)
		if mode == "error":
			mode = ""                         # once: the rollback calls from_dict again and must not fail again
			push_error("fake section failure %s" % tag)
		if mode == "reject":
			return false
		data = d.duplicate(true)
		return true

	func reset() -> void:
		reset_calls += 1
		log.append("reset:" + tag)
		data = {"v": 1, "n": 0}

	## Emulates a manager that follows the reset contract: it connects its own reset() to new_game_started.
	func wire_new_game(bus: Node) -> void:
		bus.new_game_started.connect(reset)

	## Emulates a manager that follows the calendar (its state changes on day_started).
	func follow_days(bus: Node) -> void:
		bus.day_started.connect(_on_day_started)

	func _on_day_started(day: int, _season: StringName) -> void:
		seen_day = day
		data = {"v": 1, "n": day}


## SaveManager with two virtual seams pinned: the time zone (the offset of the machine the test runs on would otherwise decide
## the v1 time stamp checks) and the byte store (a disk that loses half of the bytes without reporting an error).
class ProbeManager extends "res://scripts/autoload/save_manager.gd":
	var bias_minutes := 0
	var lose_bytes := false

	func _system_bias_minutes() -> int:
		return bias_minutes

	func _store_text(file: FileAccess, text: String) -> void:
		file.store_string(text.substr(0, int(text.length() / 2.0)) if lose_bytes else text)


## A section whose to_dict() hands out its LIVE nested dictionary (no copy) and whose from_dict() changes it in place: the
## snapshot taken before a load has to be a deep copy for the rollback to put the old values back.
class AliasSection extends Node:
	var data: Dictionary = {"v": 1, "inner": {"n": 0}}

	func to_dict() -> Dictionary:
		return data

	func from_dict(d: Dictionary) -> bool:
		(data["inner"] as Dictionary)["n"] = (d["inner"] as Dictionary)["n"]
		return true

	func reset() -> void:
		data = {"v": 1, "inner": {"n": 0}}


## A section that breaks the contract: to_dict() does not return a Dictionary.
class BadSection extends Node:
	func to_dict() -> Variant:
		return [1, 2, 3]

	func from_dict(_d: Dictionary) -> bool:
		return true

	func reset() -> void:
		pass


var t
var sm: Node
var gm: Node
var tm: Node
var eco: Node
var qm: Node
var ah: Node
var shop: Node
var bus: Node
var svc                                         # the Svc script (static helpers)
var PH: Dictionary = {}

var _scratch := ""
var _fakes: Array = []
var _listeners: Array = []                      # [signal, callable]
var _log: Array = []
var _notes: Array = []                          # [title, message, icon] of notification_posted
var _saved_slots: Array = []                    # slot of every save_completed
var _loaded_slots: Array = []                   # slot of every load_completed


func run(p_t) -> void:
	t = p_t
	sm = t.autoload("SaveManager")
	gm = t.autoload("GameManager")
	tm = t.autoload("TimeManager")
	eco = t.autoload("EconomyManager")
	qm = t.autoload("QuestManager")
	ah = t.autoload("AnimalHusbandry")
	shop = t.autoload("ShopSystem")
	bus = t.autoload("EventBus")
	if sm == null or gm == null or tm == null or eco == null or qm == null or ah == null or shop == null or bus == null:
		return
	svc = load(SVC)
	PH = gm.GamePhase
	var keep_dir: String = sm.save_dir
	var keep_interval: float = sm.auto_save_interval_seconds
	var keep_enabled: bool = sm.autosave_enabled
	var keep_locale := TranslationServer.get_locale()
	var real_listing_before := _listing(sm.SAVE_DIR)
	await t.go_menu()                            # a clean sandbox: no world scene, only the autoloads
	_scratch = "user://save_test_%d" % Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(_scratch)
	sm.save_dir = _scratch
	sm.autosave_enabled = false                  # a test switches it on where it needs it
	_notes = _listen(bus.notification_posted)
	_saved_slots = _listen_first(bus.save_completed)
	_loaded_slots = _listen_first(bus.load_completed)

	_test_isolation_start()
	_test_api_surface()
	_test_autosave_defaults()
	_test_registry()
	_test_json_rules()
	_test_validation()
	_test_file_corruption()
	_test_atomic_apply()
	_test_sections_without_methods()
	_test_slots_and_backup()
	_test_backup_cache()
	_test_delete_save()
	_test_load_keeps_manual_slot()
	_test_write_failure()
	await _test_autosave()
	_test_summaries()
	_test_summary_types()
	_test_latest_slot()
	_test_world_contract()
	_test_v1_migration()
	_test_v1_time_zone()
	_test_roundtrip_all_systems()
	_test_feedback_locales()
	await _test_real_world()
	await _test_continue()
	await _test_new_game_after_continue()

	# leave everything as found
	_clear_fakes()
	svc.clear_overrides()
	_unlisten_all()
	_wipe()
	DirAccess.remove_absolute(_scratch)
	sm.save_dir = keep_dir
	sm.auto_save_interval_seconds = keep_interval
	sm.autosave_enabled = keep_enabled
	sm.clock_override = -1.0
	TranslationServer.set_locale(keep_locale)
	t.check("real_user_dir_untouched", _listing(sm.SAVE_DIR) == real_listing_before, "user://saves has the same files as before the section (%d)" % real_listing_before.size())
	gm.pop_all_modals()
	gm.start_new_game("Tester", gm.CharacterType.ANIMAL, "Testgaarden")
	gm.change_phase(PH.MENU)
	await t.go_menu()


# ================================================================ helpers

func _listing(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		out.append("%s:%d" % [f, FileAccess.get_file_as_bytes(dir.path_join(f)).size()])
	out.sort()
	return out


func _files() -> Array:
	return Array(DirAccess.get_files_at(_scratch))


func _wipe() -> void:
	if _scratch == "":
		return
	for d in DirAccess.get_directories_at(_scratch):
		DirAccess.remove_absolute(_scratch.path_join(d))
	for f in DirAccess.get_files_at(_scratch):
		DirAccess.remove_absolute(_scratch.path_join(f))


func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _write_json(path: String, data: Variant) -> void:
	_write_text(path, JSON.stringify(data, "\t", true, true))


func _read_json(path: String) -> Variant:
	var json := JSON.new()
	if json.parse(_read_text(path)) != OK:
		return null
	return json.data


## economy.gold of a save file, -1 when the file is missing, damaged or has no economy section.
func _gold_in(path: String) -> int:
	var doc: Variant = _read_json(path)
	if doc is Dictionary and (doc as Dictionary).get("economy") is Dictionary:
		return int(((doc as Dictionary)["economy"] as Dictionary).get("gold", -1))
	return -1


func _listen(sig: Signal) -> Array:
	var box: Array = []
	var cb := func(a = null, b = null, c = null) -> void: box.append([a, b, c])
	sig.connect(cb)
	_listeners.append([sig, cb])
	return box


## First argument of every emission (a slot number).
func _listen_first(sig: Signal) -> Array:
	var box: Array = []
	var cb := func(a = null) -> void: box.append(a)
	sig.connect(cb)
	_listeners.append([sig, cb])
	return box


func _unlisten_all() -> void:
	for pair in _listeners:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	_listeners.clear()


## Autoload state, scratch directory and listeners back to a known start. Phase is MENU, no fake sections.
func _fresh() -> void:
	_clear_fakes()
	svc.clear_overrides()
	gm.pop_all_modals()
	_wipe()
	sm.clock_override = -1.0
	sm.autosave_enabled = false
	sm.auto_save_interval_seconds = 300.0         # a known start; the shipped default is asserted by autosave_default_interval_five_minutes
	gm.start_new_game("Tester", gm.CharacterType.ANIMAL, "Testgaarden")
	gm.change_phase(PH.MENU)
	t.tree.paused = false
	# systems without a reset() yet (QuestManager P13, AnimalHusbandry P20) keep the previous test's state: clear it by hand
	_clear_quests()
	_clear_husbandry()
	_log = []
	_notes.clear()
	_saved_slots.clear()
	_loaded_slots.clear()
	sm.last_error = {}


func _fake(tag: String, order: int = -99999) -> FakeSection:
	var f := FakeSection.new()
	f.tag = tag
	f.log = _log
	if order == -99999:
		sm.register_section(tag, f)
	else:
		sm.register_section(tag, f, order)
	_fakes.append(f)
	return f


## A second SaveManager on the scratch directory with pinned time zone / byte store (see ProbeManager). Autosave is off; the
## caller frees it.
func _new_probe(bias: int = 0) -> ProbeManager:
	var probe := ProbeManager.new()
	probe.save_dir = _scratch                    # before add_child: its _ready sweeps and creates only this directory
	probe.autosave_enabled = false
	probe.bias_minutes = bias
	t.root.add_child(probe)
	return probe


func _clear_fakes() -> void:
	for f in _fakes:
		if is_instance_valid(f):
			sm.unregister_section(f.tag)
			f.free()
	_fakes.clear()


## |a - b| <= eps. NOT is_equal_approx: its tolerance is relative (1e-5 of the value), which is about FIVE HOURS for a unix time
## stamp of 1.79e9 seconds.
func _near(a: Variant, b: Variant, eps: float = 0.001) -> bool:
	return absf(float(a) - float(b)) <= eps


## Deep comparison that ignores int / float and String / StringName; "" when equal, else the path of the first difference.
func _diff(a: Variant, b: Variant, path: String = "") -> String:
	var a_num := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var b_num := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if a_num and b_num:
		return "" if _near(a, b, 1.0e-9 * maxf(1.0, absf(float(a)))) else "%s: %s vs %s" % [path, a, b]
	var a_str := typeof(a) == TYPE_STRING or typeof(a) == TYPE_STRING_NAME
	var b_str := typeof(b) == TYPE_STRING or typeof(b) == TYPE_STRING_NAME
	if a_str and b_str:
		return "" if str(a) == str(b) else "%s: '%s' vs '%s'" % [path, a, b]
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		var keys := {}
		for k in a:
			keys[str(k)] = true
		for k in b:
			keys[str(k)] = true
		var left := {}
		var right := {}
		for k in a:
			left[str(k)] = a[k]
		for k in b:
			right[str(k)] = b[k]
		for k in keys:
			if not left.has(k):
				return "%s/%s: only on the right" % [path, k]
			if not right.has(k):
				return "%s/%s: only on the left" % [path, k]
			var d := _diff(left[k], right[k], "%s/%s" % [path, k])
			if d != "":
				return d
		return ""
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			return "%s: array size %d vs %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := _diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	if typeof(a) != typeof(b):
		return "%s: type %s vs %s" % [path, type_string(typeof(a)), type_string(typeof(b))]
	return "" if a == b else "%s: %s vs %s" % [path, a, b]


## Quest and animal state back to empty: reset() when the system has one (P13 / P20), else its collections by hand.
func _clear_quests() -> void:
	if qm.has_method("reset"):
		qm.reset()
		return
	for field in ["active_quests", "completed_quests", "failed_quests", "offered_quests"]:
		if field in qm:
			qm.get(field).clear()


func _clear_husbandry() -> void:
	if ah.has_method("reset"):
		ah.reset()
		return
	for field in ["animals", "buildings"]:
		if field in ah:
			ah.get(field).clear()


## ids in a section list of the save (StringNames after a load, Strings in a file): always Strings.
func _names(list: Variant) -> Array[String]:
	var out: Array[String] = []
	if list is Array:
		for item in list:
			out.append(str(item))
	return out


## Is the Lua quest definition there? True when this QuestManager offers no way to ask.
func _quest_defined(quest_id: StringName) -> bool:
	if qm.has_method("get_quest_def"):
		return not (qm.get_quest_def(quest_id) as Dictionary).is_empty()
	return true


## Type-safe equality: false instead of a script error when the two values are of unrelated types.
func _eq(a: Variant, b: Variant) -> bool:
	return _diff(a, b) == ""


## What the game looks like to a player who just pressed a button: unchanged after a failed load.
func _sentinel() -> Dictionary:
	return {
		"gold": eco.gold, "day": gm.day, "name": gm.player_name, "phase": gm.current_phase, "paused": t.tree.paused,
		"weather": tm.weather, "pending": sm.pending_world.duplicate(true), "slot": sm.current_slot,
		"economy": eco.to_dict(), "game": gm.to_dict(), "quests": qm.to_dict(), "time": tm.to_dict(),
	}


func _set_state(gold: int, day: int, who: String = "Mia") -> void:
	gm.start_new_game(who, gm.CharacterType.FAIRY, "Farm " + who, &"fairy_stardust")
	gm.change_phase(PH.MENU)
	gm.day = day
	gm.season = &"sommer"
	gm.year = 2
	gm.hour = 14
	gm.minute = 5
	eco.gold = gold


## sm.gather_payload() as a parsed JSON dictionary (what a file would hold).
func _payload() -> Dictionary:
	return JSON.parse_string(JSON.stringify(sm.gather_payload()))


func _put(slot: int, payload: Variant) -> void:
	_write_json(sm.slot_path(slot), payload)


func _last_note() -> Array:
	return _notes[-1] if not _notes.is_empty() else ["", "", ""]


func _is_fail_note(code: String) -> bool:
	var note := _last_note()
	return str(note[0]) == sm.tr("NOTIF_LOAD_FAILED_TITLE") and str(note[1]) == sm.tr(str(FAIL_KEYS[code]))


# ================================================================ isolation, API

func _test_isolation_start() -> void:
	if OS.get_environment("PLAYTEST_ISOLATED") == "1":
		t.check("throwaway_home", true, "user:// is %s (a throwaway HOME)" % t.user_dir)
	else:
		t.skip("throwaway_home: this run is not isolated (use tests/run_playtest.sh); the section still writes only to its scratch directory %s" % _scratch)
	t.check("saves_go_to_scratch_dir", sm.save_dir == _scratch and DirAccess.dir_exists_absolute(_scratch) and sm.slot_path(3).begins_with(_scratch), sm.slot_path(3))


func _test_api_surface() -> void:
	var methods := ["save_game", "load_game", "continue_latest", "load_and_enter", "get_latest_slot", "get_save_summary", "has_save", "has_any_save",
		"delete_save", "register_section", "unregister_section", "consume_pending_world", "inspect_slot", "validate_payload", "gather_payload", "autosave", "reset", "describe_slots"]
	var missing: Array[String] = []
	for m in methods:
		if not sm.has_method(m):
			missing.append(m)
	t.check("api_surface", missing.is_empty(), "missing %s" % [missing])
	t.check("slot_constants", sm.MANUAL_SLOTS == 6 and sm.AUTO_SLOT == 6 and sm.NO_SLOT == -1 and sm.PAYLOAD_VERSION == 2 and sm.all_slots() == [0, 1, 2, 3, 4, 5, 6],
		"six manual slots 0..5, auto slot %d, payload version %d" % [sm.AUTO_SLOT, sm.PAYLOAD_VERSION])
	# reset() is wired to new_game_started (core.new_game_wires_SaveManager asserts the same from the other side)
	var wired := false
	for c in bus.new_game_started.get_connections():
		if (c["callable"] as Callable).get_object() == sm:
			wired = true
	t.check("reset_wired_to_new_game", wired, "SaveManager.reset() is connected to new_game_started")
	# no JSON.parse_string in the code (it prints an engine error for every damaged file)
	var offenders: Array[String] = []
	var n := 0
	for line in _read_text("res://scripts/autoload/save_manager.gd").split("\n"):
		n += 1
		var code: String = line.split("#")[0]
		if code.contains("parse_string(") or code.contains("Input.mouse_mode"):
			offenders.append("line %d" % n)
	t.check("no_parse_string", offenders.is_empty(), "JSON.new().parse() only: %s" % [offenders])
	# every feature manager that registered itself follows the reset contract (connects reset() to new_game_started): vacuous
	# until HomeManager / FurnitureManager / WardrobeManager / LootService exist, then it guards each of them
	var connected := {}
	for c in bus.new_game_started.get_connections():
		var target: Object = (c["callable"] as Callable).get_object()
		if target != null:
			connected[target] = true
	var forgetful: Array[String] = []
	var real_sections: Array[String] = sm.registered_section_names()
	for section_name in real_sections:
		var node: Node = sm.section_node(section_name)
		if node == null or not connected.has(node):
			forgetful.append(section_name)
	t.check("registered_sections_follow_reset_contract", forgetful.is_empty(), "%d registered feature section(s) %s; not wired to new_game_started: %s" % [real_sections.size(), real_sections, forgetful])
	_fresh()
	gm.start_new_game("A", gm.CharacterType.ANIMAL, "F")
	sm.current_slot = 3
	sm.pending_world = {"x": 1}
	sm._auto_save_timer = 99.0
	sm.last_error = {"code": "x"}
	gm.start_new_game("B", gm.CharacterType.ANIMAL, "F")
	t.check("reset_on_new_game", sm.current_slot == -1 and sm.pending_world.is_empty() and is_zero_approx(sm._auto_save_timer) and sm.last_error.is_empty(),
		"slot %d, pending %s, timer %s" % [sm.current_slot, sm.pending_world, sm._auto_save_timer])


## The shipped autosave settings, read from a SaveManager nobody has touched (every other check shortens the interval or
## switches autosave off for itself). Not in the tree: only the initial values of its variables are looked at.
func _test_autosave_defaults() -> void:
	var untouched := ProbeManager.new()
	var seconds: float = untouched.auto_save_interval_seconds
	var enabled: bool = untouched.autosave_enabled
	var queued_at_start: bool = untouched._autosave_queued
	untouched.free()
	t.check("autosave_nothing_queued_at_start", not queued_at_start, "a fresh SaveManager has no day-end save waiting (else the first day end of a session would never be saved)")
	t.check("slot_helpers_bounds", sm.is_manual_slot(0) and sm.is_manual_slot(5) and not sm.is_manual_slot(6) and not sm.is_manual_slot(-1) and sm.is_valid_slot(6) and not sm.is_valid_slot(7) and not sm.is_valid_slot(-1), "manual 0..5, valid 0..6")
	t.check("autosave_default_interval_five_minutes", sm.AUTOSAVE_INTERVAL_SECONDS == 300.0 and seconds == 300.0 and enabled,
		"the plan: every 5 real minutes (constant %s s, a fresh SaveManager starts with %s s, autosave on: %s)" % [sm.AUTOSAVE_INTERVAL_SECONDS, seconds, enabled])


# ================================================================ section registry (addendum 4.4)

## Real feature sections (HomeManager, FurnitureManager, WardrobeManager, LootService, CollectionLog, SocialManager, ...) register themselves on the
## live SaveManager in their _ready. The registry checks assert the EXACT list of registered names and the apply order of it, which must be the
## fakes of the test, so the real sections are detached for the duration of _test_registry_inner and registered again afterwards: same node, same
## order, and (found in apply order, re-registered in that order) equal orders keep their registration order. [[name, node, order], ...].
func _detach_real_sections() -> Array:
	var out: Array = []
	for section_name in sm.registered_section_names():
		var order: int = 100
		for entry in sm._sections:
			if entry["name"] == section_name:
				order = int(entry["order"])
		out.append([section_name, sm.section_node(section_name), order])
	for e in out:
		sm.unregister_section(e[0])
	return out


func _reattach_real_sections(detached: Array) -> void:
	for e in detached:
		if is_instance_valid(e[1]):
			sm.register_section(e[0], e[1], e[2])


## "name@order#node" of every registered (feature) section in apply order: what a detach / re-attach must leave unchanged.
func _registry_rows() -> Array[String]:
	var out: Array[String] = []
	for section_name in sm.registered_section_names():
		var order: int = -1
		for entry in sm._sections:
			if entry["name"] == section_name:
				order = int(entry["order"])
		out.append("%s@%d#%d" % [section_name, order, sm.section_node(section_name).get_instance_id()])
	return out


func _test_registry() -> void:
	# whatever the live tree registered is put aside first, then two stand-ins for real feature managers take its place so the
	# round trip is proven whatever is (not) installed: "home" has the NAME of a fake of the checks below (the fake replaces it,
	# and its cleanup unregisters the name: the real node would be lost), "social" sits behind every order of the addendum
	var installed := _detach_real_sections()
	var stand_home := FakeSection.new()
	stand_home.tag = "home"
	var stand_social := FakeSection.new()
	stand_social.tag = "social"
	sm.register_section("home", stand_home, 10)
	sm.register_section("social", stand_social, 60)
	var before := _registry_rows()
	var detached := _detach_real_sections()
	var seen_empty: bool = sm.registered_section_names().is_empty()
	_test_registry_inner()
	var emptied_after: bool = sm.registered_section_names().is_empty()
	_reattach_real_sections(detached)
	var after := _registry_rows()
	t.check("registry_tests_keep_real_sections", detached.size() == 2 and seen_empty and emptied_after and before.size() == 2 and after == before,
		"%d feature sections detached for the registry checks (registry empty before: %s, after: %s), then registered again unchanged: before %s, after %s" % [detached.size(), seen_empty, emptied_after, before, after])
	sm.unregister_section("home")
	sm.unregister_section("social")
	stand_home.free()
	stand_social.free()
	_reattach_real_sections(installed)


func _test_registry_inner() -> void:
	_fresh()
	_set_state(999, 9)
	tm.set_weather(&"klart")
	# probes: what has already been applied when a section in between runs?
	var p_game := _fake("p_game", -55)
	p_game.probe = func() -> String: return "day=%d" % gm.day
	var p_time := _fake("p_time", -45)
	p_time.probe = func() -> String: return "%s,gold=%d" % [tm.weather, eco.gold]
	var p_eco := _fake("p_eco", -35)
	p_eco.probe = func() -> String: return "gold=%d" % eco.gold
	# registered in a scrambled order on purpose
	var wardrobe := _fake("wardrobe", 30)
	var late := _fake("late")                                    # default order 100
	_fake("tie_a", 10)
	var furniture := _fake("furniture", 20)
	var home := _fake("home", 10)
	var valid_node := FakeSection.new()
	t.check("registry_valid_registration_returns_true", sm.register_section("valid_node", valid_node, 5) == true and sm.has_section("valid_node") and sm.register_section("valid_node", valid_node, 6) == true, "a good name and node: true, first time and again")
	sm.unregister_section("valid_node")
	valid_node.free()
	var expected: Array[String] = ["p_game", "p_time", "p_eco", "tie_a", "home", "furniture", "wardrobe", "late"]
	var registered: Array[String] = sm.registered_section_names()
	t.check("registry_names_in_apply_order", registered == expected, "%s" % [registered])
	var all_names: Array[String] = sm.section_names()
	t.check("registry_core_order", _is_subsequence(["game", "time", "economy", "quests", "husbandry", "shops"], all_names) and all_names.find("quests") < all_names.find("tie_a"),
		"game, time, economy, quests, husbandry, shops, then the features: %s" % [all_names])
	# data of every section distinct so a mix-up is visible
	for f in _fakes:
		f.data = {"v": 1, "n": f.tag.length(), "tag": f.tag}
	var payload := _payload()
	var has_all := true
	for f in _fakes:
		has_all = has_all and payload.has(f.tag) and payload[f.tag]["tag"] == f.tag
	t.check("registry_gather", has_all and payload.has("meta") and payload.has("world") and payload.has("game"), "gather = {name: node.to_dict()} for %d registered sections" % _fakes.size())
	# save in state S1, change to S2, load: ascending order, then registration order
	_set_state(321, 7)
	tm.set_weather(&"regn")
	for f in _fakes:
		f.data = {"v": 1, "n": 1, "tag": f.tag, "when": "saved"}
	t.check("registry_save_ok", sm.save_game(1), "saved S1 (gold 321, day 7, regn)")
	_set_state(999, 9)
	tm.set_weather(&"klart")
	for f in _fakes:
		f.data = {"v": 1, "n": 2, "tag": f.tag, "when": "changed"}
	_log.clear()
	var ok: bool = sm.load_game(1)
	var want_log := ["apply:p_game:day=7", "apply:p_time:regn,gold=999", "apply:p_eco:gold=321", "apply:tie_a", "apply:home", "apply:furniture", "apply:wardrobe", "apply:late"]
	t.check("section_registry_order_and_reset", ok and _log == want_log, "apply order %s (want %s)" % [_log, want_log])
	t.check("registry_core_applied_between_features", _log.size() >= 3 and _log[0] == "apply:p_game:day=7" and _log[1] == "apply:p_time:regn,gold=999" and _log[2] == "apply:p_eco:gold=321",
		"game before time before economy, each in front of the sections that sit between them")
	t.check("registry_data_arrives", home.data.get("when") == "saved" and wardrobe.data.get("when") == "saved" and typeof(home.data["n"]) == TYPE_INT, "from_dict got the saved dictionary, numbers as ints")
	# a section missing from the save is reset, never left stale
	var doc: Dictionary = _read_json(sm.slot_path(1))
	doc.erase("late")
	doc.erase("furniture")
	doc["ghost"] = {"v": 1, "x": 1}                                # a section of a build that is not installed here: ignored
	_put(1, doc)
	for f in _fakes:
		f.data = {"v": 1, "n": 3, "tag": f.tag, "when": "stale"}
		f.apply_calls = 0
		f.reset_calls = 0
	_log.clear()
	ok = sm.load_game(1)
	t.check("missing_section_resets", ok and late.reset_calls == 1 and furniture.reset_calls == 1 and late.apply_calls == 0 and furniture.apply_calls == 0 and late.data.get("when") == null and furniture.data.get("n") == 0
		and home.reset_calls == 0 and home.apply_calls == 1 and home.data.get("when") == "saved" and _log.has("reset:late") and _log.has("reset:furniture"),
		"late and furniture were reset (n=%s), home applied, ghost ignored: %s" % [late.data.get("n"), _log])
	# re-registering replaces the node and the order; unregister removes; a freed node disappears
	var home2 := FakeSection.new()
	home2.tag = "home"
	home2.log = _log
	_fakes.append(home2)
	t.check("registry_reregister_replaces", sm.register_section("home", home2, 99) and sm.registered_section_names().count("home") == 1 and sm.registered_section_names().find("home") > sm.registered_section_names().find("wardrobe") and sm.section_node("home") == home2,
		"home moved behind wardrobe: %s" % [sm.registered_section_names()])
	sm.unregister_section("tie_a")
	t.check("registry_unregister", not sm.has_section("tie_a") and sm.has_section("home"), "tie_a gone")
	late.free()
	_fakes.erase(late)
	t.check("registry_freed_node_skipped", not sm.has_section("late") and sm.load_game(1), "a freed node is pruned and the load still works")
	# bad registrations are refused with an error and change nothing
	t.allow("SaveManager.register_section")
	var before: Array[String] = sm.registered_section_names()
	var plain := Node.new()
	var refused: Array = [sm.register_section("Bad Name", home2), sm.register_section("world", home2), sm.register_section("game", home2),
		sm.register_section("nomethods", plain), sm.register_section("nullnode", null)]
	plain.free()
	t.check("registry_refuses_bad_input", refused == [false, false, false, false, false] and sm.registered_section_names() == before, "bad name, reserved name, built-in name, no methods, null: %s" % [refused])
	t.expect_allowed("SaveManager.register_section", 5, "the five refusals are reported")
	_clear_fakes()
	# the feature sections of the addendum keep their documented order whatever the autoload order is
	var o: Dictionary = sm.FEATURE_ORDERS
	t.check("feature_orders_constants", o == {"home": 10, "furniture": 20, "wardrobe": 30, "loot": 40, "collection": 50}, "home 10, furniture 20, wardrobe 30, loot 40, collection 50")
	for name in ["collection", "loot", "wardrobe", "home", "furniture"]:
		_fake(name, o[name])
	var names: Array[String] = sm.registered_section_names()
	t.check("feature_orders_apply_order", names == ["home", "furniture", "wardrobe", "loot", "collection"] and sm.section_names().find("quests") < sm.section_names().find("home"), "%s" % [names])
	_clear_fakes()
	# equal orders keep the registration order however many there are (a sort that is not stable would scramble 40 of them)
	var scrambled: Array[String] = []
	for i in 40:
		scrambled.append("tie_%02d" % ((i * 17) % 40))
	for section_name in scrambled:
		_fake(section_name, 50)
	t.check("registry_equal_orders_keep_registration_order", sm.registered_section_names() == scrambled, "40 sections at order 50, registered in the order tie_00, tie_17, tie_34, ...: %s" % [sm.registered_section_names().slice(0, 5)])
	_clear_fakes()
	# a registered section with the order of a built-in one comes AFTER it
	_fake("beside_game", -60)
	_fake("beside_quests", -30)
	var with_ties: Array[String] = sm.section_names()
	t.check("registry_built_in_sections_win_ties", with_ties.find("game") < with_ties.find("beside_game") and with_ties.find("quests") < with_ties.find("beside_quests") and with_ties.find("beside_game") < with_ties.find("time"),
		"game, beside_game, time, ... quests, beside_quests: %s" % [with_ties])
	_clear_fakes()


func _is_subsequence(wanted: Array, all: Array) -> bool:
	var at := -1
	for w in wanted:
		var i := all.find(w, at + 1)
		if i < 0:
			return false
		at = i
	return true


# ================================================================ JSON rules

func _test_json_rules() -> void:
	_fresh()
	var f := _fake("jsonrules")
	f.data = {
		"v": 1, "pos": Vector2(1.5, 2.0), "cell": Vector2i(3, 4), "v3": Vector3(1, 2, 3), "n": 7, "ratio": 0.25, "name": &"abc",
		"list": [Vector2(0.5, 0.5), &"x", 3], "color": Color(1, 0.5, 0, 1), "packed": PackedInt32Array([1, 2]), "rect": Rect2(1, 2, 3, 4),
		"nan": NAN, "inf": INF, "text": "Trætoppen æøå", "empty_array": [], "empty_dict": {}, "flag": true, 5: "int key", &"sn": "stringname key",
	}
	var gathered: Dictionary = sm.gather_payload()["jsonrules"]
	t.check("json_vectors_become_arrays", _eq(gathered["pos"], [1.5, 2.0]) and _eq(gathered["cell"], [3, 4]) and _eq(gathered["v3"], [1.0, 2.0, 3.0]) and _eq(gathered["rect"], [1.0, 2.0, 3.0, 4.0])
		and _eq(gathered["color"], [1.0, 0.5, 0.0, 1.0]) and _eq(gathered["packed"], [1, 2]) and _eq(gathered["list"][0], [0.5, 0.5]), "%s" % [gathered["pos"]])
	t.check("json_names_keys_and_nonfinite", typeof(gathered["name"]) == TYPE_STRING and _eq(gathered["list"][1], "x") and _eq(gathered["nan"], 0.0) and _eq(gathered["inf"], 0.0) and gathered.has("5") and gathered.has("sn"),
		"StringName -> String, int and StringName keys -> String keys, NaN/INF -> 0.0")
	t.check("json_save_ok", sm.save_game(0), "")
	var text := _read_text(sm.slot_path(0))
	t.check("json_no_stringified_vectors", not text.contains("(1.5") and not text.contains("\"(") and text.contains("æøå"), "no \"(1.5, 2.0)\" strings in the file, UTF-8 intact")
	f.data = {"v": 1, "n": -1}
	t.check("json_load_ok", sm.load_game(0), "")
	var d: Dictionary = f.data
	t.check("json_ints_recoerced", typeof(d["n"]) == TYPE_INT and _eq(d["n"], 7) and _eq(d["pos"], [1.5, 2]) and typeof(d["pos"][1]) == TYPE_INT and typeof(d["ratio"]) == TYPE_FLOAT and _eq(d["ratio"], 0.25)
		and typeof(d["cell"][0]) == TYPE_INT and _eq(d["text"], "Trætoppen æøå") and _eq(d["flag"], true) and _eq(d["empty_array"], []) and _eq(d["empty_dict"], {}),
		"whole numbers come back as int (JSON has one number type), fractions stay float: n %s pos %s" % [type_string(typeof(d["n"])), d["pos"]])
	# a section that returns an Object: written as null with a warning, never a crash
	f.data = {"v": 1, "node": Node.new()}
	t.allow("which cannot be saved")
	var with_object: Dictionary = sm.gather_payload()["jsonrules"]
	t.check("json_object_becomes_null", with_object["node"] == null, "an Object is written as null")
	t.expect_allowed("which cannot be saved", 1, "the Object is reported")
	(f.data["node"] as Node).free()
	_clear_fakes()
	# floats keep every digit (a stamp or a ratio must come back equal), keys are written sorted (stable, diffable files)
	var precise := _fake("precise")
	precise.data = {"v": 1, "zeta": 0.1 + 0.2, "alpha": 1.0 / 3.0, "stamp": 1791901594.123456, "big": 1.0e20, "edge": 9007199254740992.0, "whole": 2.0}
	sm.save_game(0)
	var precise_text := _read_text(sm.slot_path(0))
	precise.data = {"v": 1}
	sm.load_game(0)
	var pd: Dictionary = precise.data
	t.check("json_floats_keep_full_precision", pd["zeta"] == 0.1 + 0.2 and pd["alpha"] == 1.0 / 3.0 and pd["stamp"] == 1791901594.123456, "0.1 + 0.2 = %s, 1/3 = %s, stamp %s" % [pd["zeta"], pd["alpha"], pd["stamp"]])
	t.check("json_keys_are_sorted_in_the_file", precise_text.find("\"alpha\"") >= 0 and precise_text.find("\"alpha\"") < precise_text.find("\"stamp\"") and precise_text.find("\"stamp\"") < precise_text.find("\"zeta\""), "alpha, stamp, zeta in the text of the file")
	t.check("json_huge_numbers_stay_floats", typeof(pd["big"]) == TYPE_FLOAT and typeof(pd["edge"]) == TYPE_FLOAT and typeof(pd["whole"]) == TYPE_INT, "1e20 and 2^53 stay float, 2.0 becomes int 2")
	_clear_fakes()
	# a section whose to_dict() is not a Dictionary is left out of the gathered payload, with an error ...
	var bad := BadSection.new()
	sm.register_section("bad_dict", bad)
	t.allow("did not return a Dictionary")
	var payload_bad: Dictionary = sm.gather_payload()
	t.check("section_with_bad_to_dict_is_left_out", not payload_bad.has("bad_dict") and payload_bad.has("economy") and payload_bad.has("meta"), "gather skips it and keeps the other sections")
	t.expect_allowed("did not return a Dictionary", 1, "the bad to_dict() is reported once")
	# ... and save_game refuses such a payload (SAVE-11; it used to write it, and the next load reset the missing section to new-game
	# state): false, last_error "gather", the slot's file and .bak stay byte for byte, a manual save says so, an autosave writes nothing
	sm.unregister_section("bad_dict")
	sm.save_game(0)
	_set_state(4321, 7)
	sm.save_game(0)
	var file_before := _read_text(sm.slot_path(0))
	var bak_before := _read_text(sm.backup_path(0))
	sm.register_section("bad_dict", bad)
	_notes.clear()
	_saved_slots.clear()
	var refused: bool = not sm.save_game(0)
	var refused_auto: bool = not sm.autosave()
	t.expect_allowed("did not return a Dictionary", 3, "each refused save reports the bad to_dict() again")
	t.check("section_with_bad_to_dict_refuses_the_save", refused and refused_auto and sm.last_error.get("code") == "gather" and str(sm.last_error.get("detail", "")).contains("bad_dict")
		and _read_text(sm.slot_path(0)) == file_before and _read_text(sm.backup_path(0)) == bak_before and not sm.has_save(sm.AUTO_SLOT) and _saved_slots.is_empty(),
		"save_game(0) and autosave() return false (last_error %s); save_0.json and save_0.bak.json are unchanged, no auto slot, no save_completed" % sm.last_error)
	t.check("section_with_bad_to_dict_manual_feedback", _notes.size() >= 1 and str(_notes[0][0]) == sm.tr("NOTIF_SAVE_FAILED_TITLE"), "the manual save posts NOTIF_SAVE_FAILED (%d notes)" % _notes.size())
	sm.unregister_section("bad_dict")
	t.check("section_with_bad_to_dict_control", sm.save_game(0) and sm.load_game(0) and eco.gold == 4321, "without the broken section the same save is written and loads")
	bad.free()
	# nesting deeper than 64 levels is cut off with a warning, not a stack overflow
	var deep: Dictionary = {"v": 1}
	var cursor: Dictionary = deep
	for i in 70:
		var inner := {"depth": i}
		cursor["next"] = inner
		cursor = inner
	var deep_fake := _fake("deep")
	deep_fake.data = deep
	t.allow("nested deeper than 64")
	var payload_deep: Dictionary = sm.gather_payload()
	var walk: Variant = payload_deep["deep"]
	var levels := 0
	while walk is Dictionary and (walk as Dictionary).has("next"):
		walk = (walk as Dictionary)["next"]
		levels += 1
	t.check("json_depth_limit_cuts_with_a_warning", levels == 65 and walk == null, "70 nested levels: %d kept, then null (%s)" % [levels, walk])
	t.expect_allowed("nested deeper than 64", 1, "the cut is reported once")
	_clear_fakes()


# ================================================================ validation (task 1)

## Writes `payload` into slot 0 (text or parsed data), runs load_game and reports what happened.
func _try_load(payload: Variant, slot: int = 0) -> Dictionary:
	_wipe()
	if typeof(payload) == TYPE_STRING:
		_write_text(sm.slot_path(slot), payload)
	elif typeof(payload) == TYPE_PACKED_BYTE_ARRAY:
		var f := FileAccess.open(sm.slot_path(slot), FileAccess.WRITE)
		f.store_buffer(payload)
		f.close()
	else:
		_write_json(sm.slot_path(slot), payload)
	var before := _sentinel()
	var notes_before := _notes.size()
	var loaded_before := _loaded_slots.size()
	var apply_before := 0
	for fk in _fakes:
		apply_before += fk.apply_calls
	var ok: bool = sm.load_game(slot)
	var apply_after := 0
	for fk in _fakes:
		apply_after += fk.apply_calls
	return {
		"ok": ok, "code": str(sm.last_error.get("code", "")), "unchanged": _diff(before, _sentinel()) == "", "diff": _diff(before, _sentinel()),
		"notes": _notes.size() - notes_before, "completed": _loaded_slots.size() - loaded_before, "applied": apply_after - apply_before, "fail_note": _last_note(),
	}


func _edit(doc: Dictionary, path: Array, value: Variant) -> Dictionary:
	var copy: Dictionary = doc.duplicate(true)
	var at: Variant = copy
	for i in range(path.size() - 1):
		at = at[path[i]]
	if is_same(value, &"__erase__"):
		(at as Dictionary).erase(path[-1])
	else:
		at[path[-1]] = value
	return copy


func _test_validation() -> void:
	_fresh()
	var probe := _fake("probe", 50)                  # its from_dict must never run for a file that fails validation
	_set_state(555, 11)
	probe.data = {"v": 1, "n": 5}
	var good := _payload()
	var gone := &"__erase__"
	var cases: Array = [
		["game_missing", _edit(good, ["game"], gone), "invalid"],
		["economy_missing", _edit(good, ["economy"], gone), "invalid"],
		["quests_missing", _edit(good, ["quests"], gone), "invalid"],
		["time_missing", _edit(good, ["time"], gone), "invalid"],
		["economy_is_a_string", _edit(good, ["economy"], "oops"), "invalid"],
		["economy_gold_missing", _edit(good, ["economy", "gold"], gone), "invalid"],
		["economy_gold_is_text", _edit(good, ["economy", "gold"], "lots"), "invalid"],
		["game_day_is_text", _edit(good, ["game", "day"], "x"), "invalid"],
		["game_season_is_number", _edit(good, ["game", "season"], 4), "invalid"],
		["quests_completed_is_object", _edit(good, ["quests", "completed"], {}), "invalid"],
		["quests_active_is_array", _edit(good, ["quests", "active"], []), "invalid"],
		["quests_active_is_text", _edit(good, ["quests", "active"], "x"), "invalid"],
		["economy_inventory_is_text", _edit(good, ["economy", "inventory"], "x"), "invalid"],
		["economy_inventory_is_number", _edit(good, ["economy", "inventory"], 5), "invalid"],
		["economy_inventory_missing", _edit(good, ["economy", "inventory"], gone), "invalid"],
		["game_name_is_number", _edit(good, ["game", "player_name"], 7), "invalid"],
		["game_character_type_is_text", _edit(good, ["game", "character_type"], "fairy"), "invalid"],
		["time_weather_missing", _edit(good, ["time", "weather"], gone), "invalid"],
		["time_weather_is_number", _edit(good, ["time", "weather"], 5), "invalid"],
		["world_is_a_number", _edit(good, ["world"], 5), "invalid"],
		["registered_section_is_an_array", _edit(good, ["probe"], []), "invalid"],
		["husbandry_is_a_string", _edit(good, ["husbandry"], "x"), "invalid"],
		["meta_missing", _edit(good, ["meta"], gone), "corrupt"],
		["version_text", _edit(good, ["meta", "version"], "2"), "corrupt"],
		["version_null", _edit(good, ["meta", "version"], null), "corrupt"],
		["version_zero", _edit(good, ["meta", "version"], 0), "corrupt"],
		["version_negative", _edit(good, ["meta", "version"], -3), "corrupt"],
		["version_fraction", _edit(good, ["meta", "version"], 1.5), "corrupt"],
		["version_newer", _edit(good, ["meta", "version"], 3), "version"],
		["version_far_future", _edit(good, ["meta", "version"], 99), "version"],
	]
	var failures: Array[String] = []
	for c in cases:
		var r := _try_load(c[1])
		var expect_code: String = c[2]
		var ok: bool = (not r["ok"]) and r["code"] == expect_code and r["unchanged"] and r["applied"] == 0 and r["completed"] == 0 and r["notes"] == 1 and _is_fail_note(expect_code)
		if not ok:
			failures.append("%s -> ok=%s code=%s unchanged=%s (%s) applied=%d notes=%d" % [c[0], r["ok"], r["code"], r["unchanged"], r["diff"], r["applied"], r["notes"]])
	t.check("validate_before_apply", failures.is_empty(), "%d invalid payloads: refused with the right code, nothing applied, state untouched, one notification each%s" % [cases.size(), "" if failures.is_empty() else " - " + str(failures.slice(0, 3))])
	# the control: the unedited payload loads, and reaches the probe section
	_set_state(1, 1)
	var control := _try_load(good)
	t.check("validate_control_loads", control["ok"] and eco.gold == 555 and gm.day == 11 and control["applied"] == 1 and control["notes"] == 0 and control["completed"] == 1 and sm.last_error.is_empty(),
		"gold %d, day %d, probe applied %d, load_completed once" % [eco.gold, gm.day, control["applied"]])
	# validate_payload is pure: it does not touch the game and returns a migrated, int-coerced copy
	_set_state(42, 3)
	var verdict: Dictionary = sm.validate_payload(good)
	t.check("validate_payload_is_pure", verdict["ok"] and eco.gold == 42 and gm.day == 3 and typeof(verdict["payload"]["economy"]["gold"]) == TYPE_INT and verdict["payload"]["meta"]["version"] == 2,
		"gold %d day %d untouched" % [eco.gold, gm.day])
	t.check("validate_rejects_non_dictionary", not sm.validate_payload([1, 2])["ok"] and not sm.validate_payload("x")["ok"] and not sm.validate_payload(null)["ok"] and sm.validate_payload(5)["code"] == "corrupt", "")
	_clear_fakes()


# ================================================================ corrupt / empty / foreign / truncated files

func _test_file_corruption() -> void:
	_fresh()
	_set_state(555, 11)
	var good_text := JSON.stringify(sm.gather_payload(), "\t", true, true)
	var newer: Dictionary = _payload()
	newer["meta"]["version"] = 7
	var cut: String = good_text.substr(0, floori(good_text.length() / 2.0))
	var cases: Array = [
		["truncated_in_the_middle", cut, "corrupt"],
		["truncated_after_open_brace", "{", "corrupt"],
		["truncated_inside_string", '{"meta": {"version": 2}, "game": {"player_na', "corrupt"],
		["empty_file", "", "corrupt"],
		["only_whitespace", "  \n\t ", "corrupt"],
		["empty_object", "{}", "corrupt"],
		["array_root", "[1, 2, 3]", "corrupt"],
		["number_root", "42", "corrupt"],
		["not_json_at_all", "this is not a save", "corrupt"],
		["html_page", "<html><body>404</body></html>", "corrupt"],
		["binary_garbage", PackedByteArray([0xFF, 0xFE, 0x00, 0x80, 0x7B, 0xC3, 0x28, 0x00]), "corrupt"],
		["foreign_version_newer", newer, "version"],
		["utf8_bom_is_tolerated", "﻿" + good_text, ""],
		["leading_space_is_tolerated", " " + good_text, ""],
		["leading_tab_is_tolerated", "\t" + good_text, ""],
		["leading_newline_is_tolerated", "\n" + good_text, ""],
		["leading_carriage_return_is_tolerated", "\r\n" + good_text, ""],
		["leading_mixed_whitespace_is_tolerated", " \t\r\n " + good_text, ""],
		["leading_text_is_not", "x" + good_text, "corrupt"],
	]
	var failures: Array[String] = []
	for c in cases:
		_set_state(555, 11)
		var r := _try_load(c[1])
		var expect_code: String = c[2]
		var ok := false
		if expect_code == "":
			ok = r["ok"] and r["completed"] == 1
		else:
			ok = (not r["ok"]) and r["code"] == expect_code and r["unchanged"] and r["completed"] == 0 and r["notes"] == 1 and _is_fail_note(expect_code)
		if not ok:
			failures.append("%s -> ok=%s code=%s unchanged=%s (%s) notes=%d" % [c[0], r["ok"], r["code"], r["unchanged"], r["diff"], r["notes"]])
	t.check("corrupt_and_foreign_saves", failures.is_empty(), "%d damaged / empty / foreign files: load returns false with feedback, state unchanged%s" % [cases.size(), "" if failures.is_empty() else " - " + str(failures.slice(0, 3))])
	# the diagnostics (last_error.detail) say which kind of damage it was
	var details := {}
	for c in [["empty", ""], ["binary", PackedByteArray([0xFF, 0xFE, 0x00, 0x80])], ["oversize", "{" + " ".repeat(sm.MAX_SAVE_BYTES + 16) + "}"], ["truncated", cut], ["newer", newer]]:
		_try_load(c[1])
		details[c[0]] = str(sm.last_error.get("detail", ""))
	_try_load("{" + " ".repeat(sm.MAX_SAVE_BYTES - 2) + "}")
	var exact_detail := str(sm.last_error.get("detail", ""))
	t.check("corrupt_size_cap_is_exclusive", not exact_detail.contains("larger") and exact_detail != "", "a file of exactly %d bytes is read (and refused as no save): '%s'" % [sm.MAX_SAVE_BYTES, exact_detail.left(60)])
	t.check("corrupt_details", details["empty"].contains("empty") and details["binary"].contains("JSON object") and details["oversize"].contains("larger") and details["truncated"].contains("line") and details["newer"].contains("7"),
		"empty: '%s' | binary: '%s' | oversize: '%s' | truncated: '%s' | newer: '%s'" % [details["empty"], details["binary"], str(details["oversize"]).left(40), details["truncated"], str(details["newer"]).left(60)])
	# a file that exists but cannot be opened (no read permission) is a damaged slot: feedback, no crash
	_wipe()
	_put(0, _payload())
	var unreadable_path: String = ProjectSettings.globalize_path(sm.slot_path(0))
	var chmod_done: bool = OS.get_name() in ["macOS", "Linux"] and OS.execute("chmod", ["000", unreadable_path]) == 0
	if chmod_done and FileAccess.open(sm.slot_path(0), FileAccess.READ) == null:
		_set_state(555, 11)
		var unreadable_info: Dictionary = sm.inspect_slot(0)
		var unreadable_load: bool = sm.load_game(0)
		t.check("unreadable_file_is_a_damaged_slot", unreadable_info["state"] == &"corrupt" and str(unreadable_info["detail"]).contains("cannot open") and not unreadable_load and _is_fail_note("corrupt") and eco.gold == 555,
			"state %s, detail '%s', load false with feedback, the game untouched" % [unreadable_info["state"], unreadable_info["detail"]])
	else:
		t.skip("unreadable_file_is_a_damaged_slot: this platform / user cannot take away the read permission of a file")
	if chmod_done:
		OS.execute("chmod", ["644", unreadable_path])
	# no soft lock: a failed load leaves phase, pause and scene alone, and the next valid load works at once
	_set_state(555, 11)
	gm.change_phase(PH.MENU)
	var phase_before: int = gm.current_phase
	_try_load("{ broken")
	var no_lock: bool = gm.current_phase == phase_before and not t.tree.paused and t.scene_name() != "" and not gm.is_modal_open()
	_wipe()
	_put(0, _payload())
	t.check("failed_load_does_not_soft_lock", no_lock and sm.load_game(0), "phase %d unchanged, tree not paused, the next valid load works" % gm.current_phase)
	# empty and out-of-range slots
	_wipe()
	var gold_before: int = eco.gold
	t.check("load_empty_slot_gives_feedback", not sm.load_game(4) and sm.last_error.get("code") == "missing" and _is_fail_note("missing") and eco.gold == gold_before, "slot 4 has no file")
	t.check("load_bad_slots", not sm.load_game(-1) and not sm.load_game(7) and not sm.load_game(99) and sm.last_error.get("code") == "missing", "-1, 7, 99")
	# the state names the UI shows
	_wipe()
	_put(0, _payload())
	_write_text(sm.slot_path(1), "{ nope")
	_put(2, newer)
	t.check("slot_states", sm.inspect_slot(0)["state"] == &"ok" and sm.inspect_slot(1)["state"] == &"corrupt" and sm.inspect_slot(2)["state"] == &"newer" and sm.inspect_slot(3)["state"] == &"empty",
		"ok / corrupt / newer / empty")
	t.check("slot_from_backup_flags", sm.inspect_slot(0)["from_backup"] == false and sm.inspect_slot(1)["from_backup"] == false and sm.inspect_slot(2)["from_backup"] == false and sm.inspect_slot(3)["from_backup"] == false,
		"ok, corrupt, newer and empty slots do not claim to come from a .bak")
	t.check("slot_state_codes", sm.inspect_slot(0)["code"] == "" and sm.inspect_slot(1)["code"] == "corrupt" and sm.inspect_slot(2)["code"] == "version" and sm.inspect_slot(3)["code"] == "missing",
		"ok '', corrupt 'corrupt', newer 'version', empty 'missing': %s" % [[0, 1, 2, 3].map(func(i: int) -> String: return str(sm.inspect_slot(i)["code"]))])


# ================================================================ atomic apply (task 1)

func _test_atomic_apply() -> void:
	_fresh()
	var a := _fake("early_a", 1)
	var boom := _fake("boom", 5)
	var after := _fake("after", 9)
	# S1 is what the file holds
	_set_state(100, 3, "One")
	a.data = {"v": 1, "n": 1, "who": "saved"}
	boom.data = {"v": 1, "n": 1}
	after.data = {"v": 1, "n": 1}
	qm.accept_quest(&"lost_cat")
	t.check("atomic_setup_saved", sm.save_game(2), "")
	# S2 is the running game when the load goes wrong
	_set_state(999, 9, "Two")
	_clear_quests()
	a.data = {"v": 1, "n": 2, "who": "running"}
	after.data = {"v": 1, "n": 2}
	var s2 := _sentinel()
	var a_before: Dictionary = a.data.duplicate(true)
	t.allow("fake section failure")
	boom.mode = "error"
	_log.clear()
	var loaded_before := _loaded_slots.size()
	var ok: bool = sm.load_game(2)
	var s_after := _sentinel()
	t.check("atomic_apply_rolls_back", not ok and sm.last_error.get("code") == "apply" and _diff(s2, s_after) == "" and _diff(a.data, a_before) == "" and after.apply_calls == 0 and after.reset_calls == 0 and _loaded_slots.size() == loaded_before,
		"a script error in section 'boom' put game, economy, quests, time and 'early_a' back (gold %d, day %d, who %s): %s" % [eco.gold, gm.day, a.data.get("who"), _diff(s2, s_after)])
	t.check("atomic_apply_feedback", _is_fail_note("apply") and sm.current_slot != 2, "NOTIF_LOAD_FAILED_APPLY posted, current_slot not moved")
	t.expect_allowed("fake section failure", 1, "the provoked script error is reported once")
	# a section that answers false is a rejection with the same rollback
	boom.mode = "reject"
	_log.clear()
	ok = sm.load_game(2)
	t.check("atomic_apply_rejection_rolls_back", not ok and sm.last_error.get("code") == "apply" and _diff(s2, _sentinel()) == "" and _diff(a.data, a_before) == "", "from_dict returned false: %s" % [sm.last_error.get("detail")])
	# the control: the same file loads when nobody objects
	boom.mode = ""
	ok = sm.load_game(2)
	t.check("atomic_apply_control_loads", ok and eco.gold == 100 and gm.day == 3 and a.data.get("who") == "saved" and after.apply_calls == 1 and qm.is_active(&"lost_cat") and sm.current_slot == 2,
		"gold %d day %d, who %s" % [eco.gold, gm.day, a.data.get("who")])
	# a failed load must not move pending_world either
	sm.pending_world = {"keep": 1}
	boom.mode = "reject"
	sm.load_game(2)
	t.check("atomic_apply_keeps_pending_world", sm.pending_world == {"keep": 1}, "pending_world is only replaced by a successful load")
	# the error guard is taken off again after every load, failed or not (a guard left behind would hear every later engine error)
	var guard_class: Variant = sm.get_script().get_script_constant_map().get("ApplyGuard")
	var guards_alive: int = int((guard_class as Script).get("alive")) if guard_class is Script else -1
	t.check("apply_guard_is_removed_after_every_load", guards_alive == 0, "ApplyGuard instances alive after %d loads: %d" % [6, guards_alive])
	# the rollback restores a section that hands out its live nested dictionary and changes it in place
	_clear_fakes()
	var alias := AliasSection.new()
	sm.register_section("alias", alias, 2)
	var late_boom := _fake("late_boom", 7)
	_set_state(100, 3, "One")
	alias.data = {"v": 1, "inner": {"n": 1}}
	sm.save_game(3)
	alias.data = {"v": 1, "inner": {"n": 2}}
	t.allow("fake section failure")
	late_boom.mode = "error"
	var alias_loaded: bool = sm.load_game(3)
	t.check("atomic_apply_rollback_survives_live_references", not alias_loaded and int((alias.data["inner"] as Dictionary)["n"]) == 2, "the failed load put the running value back (n %s, not the saved 1)" % [(alias.data["inner"] as Dictionary)["n"]])
	t.expect_allowed("fake section failure", 1, "the provoked script error is reported once")
	sm.unregister_section("alias")
	alias.free()
	_clear_fakes()


## A built-in section whose autoload offers none of to_dict / from_dict / reset (a stand-in, or a manager that is not written
## yet): it is left out of the save and skipped on load, nothing is called on it.
func _test_sections_without_methods() -> void:
	_fresh()
	var bare := Node.new()
	svc.override("ShopSystem", bare)
	_set_state(321, 4)
	var gathered: Dictionary = sm.gather_payload()
	t.check("section_without_to_dict_is_left_out", not gathered.has("shops") and gathered.has("game") and gathered.has("economy"), "no 'shops' section for a stand-in without to_dict(); the others are saved")
	var doc := _payload()
	doc["shops"] = {"stock": {"x": 1}}
	_put(0, doc)
	_set_state(1, 1)
	var loaded: bool = sm.load_game(0)
	t.check("section_without_from_dict_is_skipped_on_load", loaded and eco.gold == 321 and gm.day == 4, "the save has a 'shops' section, the stand-in cannot take it: skipped, the rest loads (gold %d)" % eco.gold)
	svc.clear_overrides()
	bare.free()


# ================================================================ slots, auto slot, backup, atomic write (task 2)

func _test_slots_and_backup() -> void:
	_fresh()
	# six manual slots
	for i in 6:
		_set_state(100 * (i + 1), i + 1)
		sm.save_game(i)
	var files_ok := true
	for i in 6:
		files_ok = files_ok and FileAccess.file_exists(sm.slot_path(i)) and sm.has_save(i) and sm.slot_path(i).ends_with("save_%d.json" % i)
	t.check("slots_six_manual_files", files_ok and not sm.has_save(sm.AUTO_SLOT) and sm.current_slot == 5 and _saved_slots == [0, 1, 2, 3, 4, 5], "save_0..save_5.json, current_slot %d, save_completed %s" % [sm.current_slot, _saved_slots])
	var toast: Array = _last_note()
	t.check("slots_manual_save_toasts_slot_number", str(toast[1]).contains("6") and not str(toast[1]).contains("%") and str(toast[0]) == sm.tr("NOTIF_SAVED_TITLE"), "'%s' / '%s'" % [toast[0], toast[1]])
	# the auto slot is separate, silent, and does not move current_slot
	_notes.clear()
	_saved_slots.clear()
	_set_state(9000, 20)
	sm.current_slot = 2
	t.check("auto_slot_save", sm.autosave() and sm.has_save(sm.AUTO_SLOT) and sm.slot_path(sm.AUTO_SLOT).ends_with("save_auto.json") and sm.current_slot == 2 and _notes.is_empty() and _saved_slots == [6],
		"save_auto.json, silent, current_slot stays %d, save_completed %s" % [sm.current_slot, _saved_slots])
	# every write of the auto slot restarts the autosave countdown, also a direct save_game(AUTO_SLOT)
	sm._auto_save_timer = 100.0
	sm.save_game(sm.AUTO_SLOT)
	t.check("auto_slot_save_restarts_countdown", is_zero_approx(sm._auto_save_timer), "timer %s after save_game(AUTO_SLOT)" % sm._auto_save_timer)
	var nowhere: Dictionary = sm.inspect_slot(9)
	t.check("inspect_slot_invalid_slot", nowhere["state"] == &"empty" and str(nowhere["detail"]).contains("9") and sm.inspect_slot(-1)["state"] == &"empty", "slot 9: %s" % [nowhere["detail"]])
	# is_auto forces the auto slot whatever slot is passed (the old autosave overwrote the current manual slot)
	var slot2_before := _read_text(sm.slot_path(2))
	t.check("is_auto_never_writes_a_manual_slot", sm.save_game(2, true) and _read_text(sm.slot_path(2)) == slot2_before and not FileAccess.file_exists(sm.backup_path(2)), "save_game(2, true) wrote the auto slot only")
	# invalid slots
	var files_before := _listing(_scratch)
	t.check("save_invalid_slots", not sm.save_game(-1) and not sm.save_game(7) and not sm.save_game(99) and sm.last_error.get("code") == "slot" and _listing(_scratch) == files_before, "-1, 7, 99 create nothing")
	# .bak is rolled from manual saves only
	_wipe()
	_set_state(100, 1)
	sm.save_game(1)
	t.check("bak_not_created_by_first_save", not FileAccess.file_exists(sm.backup_path(1)), "no file to roll yet")
	_set_state(200, 2)
	sm.save_game(1)
	t.check("bak_rolled_from_manual_save", _gold_in(sm.backup_path(1)) == 100 and _gold_in(sm.slot_path(1)) == 200, "save_1.bak.json holds the previous save (gold 100), save_1.json the new one (200)")
	sm.autosave()
	_set_state(300, 3)
	sm.autosave()
	t.check("auto_slot_has_no_bak", sm.backup_path(sm.AUTO_SLOT) == "" and _files().filter(func(f: String) -> bool: return f.contains("auto") and f.contains("bak")).is_empty(), "two autosaves, no save_auto.bak.json")
	# a damaged primary never replaces a good .bak
	_write_text(sm.slot_path(1), "{ damaged")
	_set_state(400, 4)
	sm.save_game(1)
	t.check("bak_survives_a_damaged_primary", _gold_in(sm.backup_path(1)) == 100 and _gold_in(sm.slot_path(1)) == 400, "the unreadable file was not copied over save_1.bak.json")
	t.check("no_temp_files_left", _files().filter(func(f: String) -> bool: return f.ends_with(".tmp")).is_empty(), "%s" % [DirAccess.get_files_at(_scratch)])
	# recovery from the .bak
	_set_state(100, 1)
	sm.save_game(3)
	_set_state(200, 2)
	sm.save_game(3)                                # bak = gold 100, primary = gold 200
	_write_text(sm.slot_path(3), _prefix_of(_read_text(sm.slot_path(3))))
	var info: Dictionary = sm.inspect_slot(3)
	t.check("bak_state_and_summary", info["state"] == &"backup" and sm.get_save_summary(3).get("gold") == 100 and sm.get_save_summary(3).get("from_backup") == true, "damaged primary: state %s, summary from the .bak (gold %s)" % [info["state"], sm.get_save_summary(3).get("gold")])
	_set_state(1, 1)
	_notes.clear()
	var ok: bool = sm.load_game(3)
	t.check("bak_recovery_loads_backup", ok and eco.gold == 100 and sm.current_slot == 3 and _notes.size() == 1 and str(_notes[0][0]) == sm.tr("NOTIF_LOAD_BACKUP_TITLE"),
		"gold %d, one NOTIF_LOAD_BACKUP toast" % eco.gold)
	# a structurally invalid primary falls back as well; a newer-version primary does not
	var broken := _payload()
	broken.erase("economy")
	_put(3, broken)
	_set_state(1, 1)
	t.check("bak_recovery_from_invalid_primary", sm.load_game(3) and eco.gold == 100, "primary without 'economy' -> .bak")
	var newer := _payload()
	newer["meta"]["version"] = 9
	_put(3, newer)
	t.check("bak_not_used_for_newer_version", not sm.load_game(3) and sm.last_error.get("code") == "version" and _is_fail_note("version"), "a save of a newer build is refused, not silently replaced by an older .bak")
	# primary AND .bak damaged: a damaged slot, with feedback, never picked by Continue
	_write_text(sm.slot_path(3), "{ damaged")
	_write_text(sm.backup_path(3), "{ also damaged")
	var both_damaged: Dictionary = sm.inspect_slot(3)
	var both_loaded: bool = sm.load_game(3)
	t.check("bak_and_primary_both_damaged", both_damaged["state"] == &"corrupt" and not both_loaded and _is_fail_note("corrupt") and sm.get_save_summary(3).is_empty() and sm.get_latest_slot() != 3,
		"state %s, load false with feedback, no summary, never the latest slot" % both_damaged["state"])
	# delete
	sm.delete_save(3)
	t.check("delete_save_removes_all_files", not FileAccess.file_exists(sm.slot_path(3)) and not FileAccess.file_exists(sm.backup_path(3)) and not sm.has_save(3), "primary and .bak")
	sm.delete_save(77)
	# stale temp files of a crash are swept at start-up: a second SaveManager instance starts on the scratch directory
	_write_text(sm.save_dir.path_join("save_4.json.tmp"), "half")
	_write_text(sm.save_dir.path_join("save_4.json"), "keep me")
	var second: Node = load("res://scripts/autoload/save_manager.gd").new()
	second.save_dir = _scratch
	t.root.add_child(second)
	t.check("stale_temp_files_swept", not FileAccess.file_exists(sm.save_dir.path_join("save_4.json.tmp")) and _read_text(sm.save_dir.path_join("save_4.json")) == "keep me",
		"a crash leftover (.tmp) is removed when SaveManager starts, real saves stay")
	second.free()


## current_slot is a MANUAL slot or NO_SLOT, never the auto slot: a caller doing save_game(current_slot) after Continue /
## a load of the auto slot must not silently write the auto slot (nor, by a guessed slot, somebody's manual save).
func _test_load_keeps_manual_slot() -> void:
	_fresh()
	_set_state(10, 2, "Mia")
	sm.save_game(2)
	_set_state(20, 3, "Mia")
	sm.autosave()
	sm.current_slot = 2                              # this run was last saved to / loaded from the manual slot 2
	_loaded_slots.clear()
	var ok: bool = sm.load_game(sm.AUTO_SLOT)
	t.check("load_auto_slot_keeps_manual_slot", ok and _loaded_slots == [6] and eco.gold == 20 and sm.current_slot == 2, "the auto slot loaded (gold %d, load_completed %s), current_slot is still the manual slot %d" % [eco.gold, _loaded_slots, sm.current_slot])
	_set_state(30, 4, "Mia")                         # a new game: current_slot = -1
	ok = sm.load_game(sm.AUTO_SLOT)
	t.check("load_auto_slot_leaves_slot_unset", ok and sm.current_slot == sm.NO_SLOT and sm.current_slot != sm.AUTO_SLOT, "Continue from an autosave with no manual slot in this run: current_slot %d (NO_SLOT), not %d" % [sm.current_slot, sm.AUTO_SLOT])
	# save_game(current_slot) must never turn into a silent autosave
	var auto_bytes := _read_text(sm.slot_path(sm.AUTO_SLOT))
	var files := _listing(_scratch)
	_saved_slots.clear()
	var wrote: bool = sm.save_game(sm.current_slot)
	t.check("save_game_current_slot_after_auto_load_writes_nothing", not wrote and sm.last_error.get("code") == "slot" and _read_text(sm.slot_path(sm.AUTO_SLOT)) == auto_bytes and _listing(_scratch) == files and _saved_slots.is_empty(),
		"save_game(current_slot) with current_slot %d: refused as a bad slot, the auto file and the directory are unchanged" % sm.current_slot)
	# the control: a load of a manual slot still moves it, and a failed load of the auto slot does not
	ok = sm.load_game(2)
	t.check("load_manual_slot_sets_current_slot", ok and sm.current_slot == 2, "slot %d" % sm.current_slot)
	var good_auto := _read_text(sm.slot_path(sm.AUTO_SLOT))
	_write_text(sm.slot_path(sm.AUTO_SLOT), "{ broken")
	ok = sm.load_game(sm.AUTO_SLOT)
	t.check("failed_auto_load_keeps_current_slot", not ok and sm.current_slot == 2 and not sm.last_error.is_empty(), "slot %d, last_error %s" % [sm.current_slot, sm.last_error.get("code")])
	sm._auto_save_timer = 100.0
	ok = sm.load_game(2)
	t.check("successful_load_clears_last_error", ok and sm.last_error.is_empty(), "the failed load above left last_error behind, the good load after it clears it")
	t.check("load_restarts_autosave_countdown", is_zero_approx(sm._auto_save_timer), "a load starts the autosave countdown again (timer %s)" % sm._auto_save_timer)
	_write_text(sm.slot_path(sm.AUTO_SLOT), good_auto)


## delete_save(slot): every file of the slot (save, .bak, a crashed write's .tmp), only that slot, current_slot only when it was
## the deleted one, and nothing at all for a slot that does not exist.
func _test_delete_save() -> void:
	_fresh()
	for i in 4:
		_set_state(100 * (i + 1), i + 1)
		sm.clock_override = 100.0 * (i + 1)
		sm.save_game(i)
		sm.save_game(i)                              # primary + .bak
	sm.clock_override = 900.0
	sm.autosave()
	sm.clock_override = -1.0
	_write_text(sm.slot_path(2) + ".tmp", "half a write")
	var bytes_of := func(slot: int) -> Array:
		return [_read_text(sm.slot_path(slot)), _read_text(sm.backup_path(slot))]
	var keep0: Array = bytes_of.call(0)
	var keep3: Array = bytes_of.call(3)
	var keep_auto: String = _read_text(sm.slot_path(sm.AUTO_SLOT))
	sm.current_slot = 2
	sm.delete_save(1)
	t.check("delete_save_other_slot_keeps_current_slot", sm.current_slot == 2 and not FileAccess.file_exists(sm.slot_path(1)) and not FileAccess.file_exists(sm.backup_path(1)) and FileAccess.file_exists(sm.slot_path(2)) and FileAccess.file_exists(sm.backup_path(2)),
		"deleting slot 1 while slot 2 is current: current_slot %d, slot 2 and its .bak are still there" % sm.current_slot)
	sm.delete_save(2)
	t.check("delete_save_removes_every_file_of_the_slot", not FileAccess.file_exists(sm.slot_path(2)) and not FileAccess.file_exists(sm.backup_path(2)) and not FileAccess.file_exists(sm.slot_path(2) + ".tmp") and not sm.has_save(2),
		"save_2.json, save_2.bak.json and the leftover save_2.json.tmp are gone: %s" % [_files()])
	t.check("delete_save_resets_current_slot", sm.current_slot == sm.NO_SLOT, "slot 2 was the current slot: current_slot %d" % sm.current_slot)
	t.check("delete_save_touches_only_its_slot", _eq(bytes_of.call(0), keep0) and _eq(bytes_of.call(3), keep3) and _read_text(sm.slot_path(sm.AUTO_SLOT)) == keep_auto, "slots 0 and 3 with their .bak files and the auto slot are byte for byte what they were")
	sm.current_slot = 3
	sm.delete_save(sm.AUTO_SLOT)
	t.check("delete_save_auto_slot", not sm.has_save(sm.AUTO_SLOT) and not FileAccess.file_exists(sm.slot_path(sm.AUTO_SLOT)) and sm.current_slot == 3 and _eq(bytes_of.call(3), keep3), "the auto slot goes, the manual slots and current_slot stay")
	# a slot that does not exist deletes nothing, whatever its file name would be
	for decoy in ["save_7.json", "save_-1.json", "save_77.json", "save_77.bak.json", "save_7.json.tmp"]:
		_write_text(_scratch.path_join(decoy), "decoy " + decoy)
	var listing := _listing(_scratch)
	sm.delete_save(-1)
	sm.delete_save(7)
	sm.delete_save(77)
	t.check("delete_save_invalid_slots_delete_nothing", _listing(_scratch) == listing and sm.current_slot == 3, "-1, 7 and 77 leave every file (and current_slot) alone")
	sm.delete_save(5)                                # an empty slot: no error, nothing happens
	t.check("delete_save_empty_slot_is_harmless", _listing(_scratch) == listing and sm.current_slot == 3, "")
	# Continue follows what is on disk
	for decoy in ["save_7.json", "save_-1.json", "save_77.json", "save_77.bak.json", "save_7.json.tmp"]:
		DirAccess.remove_absolute(_scratch.path_join(decoy))
	t.check("delete_save_latest_follows", sm.get_latest_slot() == 3, "slot 0 @100 and slot 3 @400 are left: slot 3")
	sm.delete_save(3)
	t.check("delete_save_latest_follows_to_zero", sm.get_latest_slot() == 0 and sm.has_any_save(), "slot 3 deleted: slot 0")
	sm.delete_save(0)
	t.check("delete_save_all_gone", sm.get_latest_slot() == sm.NO_SLOT and not sm.has_any_save() and _files().is_empty(), "nothing left: %s" % [_files()])


## The first third of a JSON text: a truncated save.
func _prefix_of(text: String) -> String:
	return text.substr(0, floori(text.length() / 3.0))


func _test_write_failure() -> void:
	_fresh()
	_set_state(100, 1)
	sm.save_game(3)
	var before := _read_text(sm.slot_path(3))
	# a directory where the temp file must go makes the write impossible, deterministically
	DirAccess.make_dir_recursive_absolute(sm.slot_path(3) + ".tmp")
	_set_state(777, 5)
	_notes.clear()
	var ok: bool = sm.save_game(3)
	t.check("write_failure_keeps_old_save", not ok and _read_text(sm.slot_path(3)) == before and sm.last_error.get("code") == "write" and sm.current_slot != 3 and _saved_slots.count(3) == 1,
		"save returned false, save_3.json is byte for byte the old one, current_slot not moved, no second save_completed")
	t.check("write_failure_feedback", _notes.size() == 1 and str(_notes[0][0]) == sm.tr("NOTIF_SAVE_FAILED_TITLE"), "NOTIF_SAVE_FAILED posted for a manual save")
	_notes.clear()
	DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT) + ".tmp")
	sm._auto_save_timer = 100.0
	var auto_ok: bool = sm.autosave()
	t.check("write_failure_autosave_is_silent", not auto_ok and _notes.is_empty(), "no toast for a failed autosave")
	t.check("write_failure_autosave_restarts_countdown", is_zero_approx(sm._auto_save_timer), "a failed autosave does not retry every frame: the timer starts again (%s)" % sm._auto_save_timer)
	DirAccess.remove_absolute(sm.slot_path(3) + ".tmp")
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT) + ".tmp")
	t.check("write_recovers_after_failure", sm.save_game(3) and _gold_in(sm.slot_path(3)) == 777 and sm.last_error.is_empty(), "after a failed write the next good save clears last_error")
	# the rename itself fails (a directory with a file in it sits where the save belongs): reported, nothing left behind
	var blocked: String = sm.slot_path(2)
	DirAccess.make_dir_recursive_absolute(blocked)
	_write_text(blocked.path_join("keep.txt"), "x")
	_notes.clear()
	_saved_slots.clear()
	var blocked_ok: bool = sm.save_game(2)
	t.check("rename_failure_is_reported_and_cleaned_up", not blocked_ok and sm.last_error.get("code") == "write" and not FileAccess.file_exists(blocked + ".tmp") and _saved_slots.is_empty() and sm.current_slot != 2 and _notes.size() == 1,
		"save_game(2) with a directory in the way: false, no save_2.json.tmp left, no save_completed, one NOTIF_SAVE_FAILED toast (%d)" % _notes.size())
	DirAccess.remove_absolute(blocked.path_join("keep.txt"))
	DirAccess.remove_absolute(blocked)
	# a .bak that cannot be rolled (its temp name is taken by a directory) does not stop the save, and the leftover is cleaned up
	DirAccess.make_dir_recursive_absolute(sm.backup_path(4) + ".tmp")
	_set_state(1, 1)
	sm.save_game(4)
	_set_state(2, 2)
	t.allow("save_4.bak.json.tmp")                                  # the engine reports the failed copy itself
	var no_bak_ok: bool = sm.save_game(4)
	t.expect_allowed("save_4.bak.json.tmp", 1, "the engine's own report of the copy that cannot be made")
	t.check("bak_roll_failure_does_not_stop_the_save", no_bak_ok and _gold_in(sm.slot_path(4)) == 2 and not FileAccess.file_exists(sm.backup_path(4)) and not DirAccess.dir_exists_absolute(sm.backup_path(4) + ".tmp"),
		"the save is written (gold %d), no .bak, and the stuck save_4.bak.json.tmp is removed" % _gold_in(sm.slot_path(4)))
	# a disk that loses bytes WITHOUT reporting an error: only the read-back of the temp file can notice, and the old save survives
	var writer := _new_probe()
	var intact := _read_text(sm.slot_path(3))
	writer.lose_bytes = true
	_set_state(555, 9)
	_notes.clear()
	_saved_slots.clear()
	var short_ok: bool = writer.save_game(3)
	var temp_left := FileAccess.file_exists(sm.slot_path(3) + ".tmp")
	t.check("short_write_is_caught", not short_ok and _read_text(sm.slot_path(3)) == intact and _gold_in(sm.slot_path(3)) == 777 and writer.last_error.get("code") == "write" and not temp_left and writer.current_slot != 3 and _saved_slots.is_empty(),
		"half of the bytes were lost without an error: save returned false, save_3.json is the old save (gold %d), no .tmp left" % _gold_in(sm.slot_path(3)))
	t.check("short_write_feedback", _notes.size() == 1 and str(_notes[0][0]) == sm.tr("NOTIF_SAVE_FAILED_TITLE"), "the player is told (NOTIF_SAVE_FAILED)")
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))
	_notes.clear()
	var short_auto: bool = writer.autosave()
	t.check("short_write_autosave_leaves_no_file", not short_auto and not sm.has_save(sm.AUTO_SLOT) and _notes.is_empty() and not FileAccess.file_exists(sm.slot_path(sm.AUTO_SLOT) + ".tmp"), "a lossy autosave writes no auto slot at all (a half file would later be 'damaged') and says nothing")
	writer.lose_bytes = false
	var whole_ok: bool = writer.save_game(3)
	t.check("short_write_control_saves", whole_ok and _gold_in(sm.slot_path(3)) == 555 and _gold_in(sm.backup_path(3)) == 777, "the same probe with intact bytes saves (gold 555), the previous save is the .bak (777)")
	writer.free()
	# the saves folder deleted while the game runs: the next save makes it again
	_wipe()
	DirAccess.remove_absolute(_scratch)
	var made_again: bool = sm.save_game(1) and FileAccess.file_exists(sm.slot_path(1))
	DirAccess.make_dir_recursive_absolute(_scratch)                  # (a no-op when the save made it)
	t.check("save_recreates_missing_directory", made_again and _gold_in(sm.slot_path(1)) == 555, "the scratch directory was removed, save_game(1) wrote save_1.json anyway")


# ================================================================ autosave (task 2)

func _test_autosave() -> void:
	_fresh()
	# six distinct manual saves, bytes remembered
	for i in 6:
		_set_state(100 * (i + 1), i + 1)
		sm.save_game(i)
		sm.save_game(i)                             # twice: every slot also has a .bak
	var manual_before := {}
	for i in 6:
		manual_before[i] = [_read_text(sm.slot_path(i)), _read_text(sm.backup_path(i))]
	var listing_manual: Array = _listing(_scratch).filter(func(s: String) -> bool: return not s.begins_with("save_auto"))
	_set_state(9999, 12)
	tm.pause_time()                                 # the clock must not move while the timers are measured
	gm.hour = 10
	sm.current_slot = 2                             # what the old autosave wrote into
	_saved_slots.clear()
	var unchanged := func() -> bool:
		for i in 6:
			if _read_text(sm.slot_path(i)) != manual_before[i][0] or _read_text(sm.backup_path(i)) != manual_before[i][1]:
				return false
		return true
	# (a) the timer, only while PLAYING
	sm.autosave_enabled = true
	sm.auto_save_interval_seconds = 0.15
	gm.change_phase(PH.MENU)
	await t.seconds(0.45)
	t.check("autosave_timer_idle_in_menu", not sm.has_save(sm.AUTO_SLOT), "phase MENU: nothing is written")
	gm.push_modal(&"save_test_pause", true)
	await t.seconds(0.45)
	t.check("autosave_timer_idle_when_paused", not sm.has_save(sm.AUTO_SLOT) and gm.current_phase == PH.PAUSED, "phase PAUSED: nothing is written")
	gm.pop_modal(&"save_test_pause")
	gm.change_phase(PH.PLAYING)
	await t.seconds(0.6)
	var auto_doc: Variant = _read_json(sm.slot_path(sm.AUTO_SLOT))
	t.check("autosave_timer_writes_auto_slot", sm.has_save(sm.AUTO_SLOT) and auto_doc != null and auto_doc["economy"]["gold"] == 9999 and sm.current_slot == 2 and _saved_slots.has(6) and not _saved_slots.any(func(s) -> bool: return s != 6),
		"while PLAYING the timer wrote save_auto.json (gold %s); save_completed %s; current_slot %d" % [auto_doc["economy"]["gold"] if auto_doc != null else "-", _saved_slots, sm.current_slot])
	t.check("autosave_timer_leaves_manual_slots_alone", unchanged.call(), "six manual files and six .bak files are byte for byte what they were")
	# (b) switched off
	sm.autosave_enabled = false
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))
	await t.seconds(0.45)
	t.check("autosave_disabled_switch", not sm.has_save(sm.AUTO_SLOT), "autosave_enabled = false stops the timer")
	# (c) day end: deferred, after the new day has begun and the other day_started listeners have run
	sm.autosave_enabled = true
	sm.auto_save_interval_seconds = 300.0
	sm._auto_save_timer = 0.0
	var follower := _fake("follower", 60)
	follower.follow_days(bus)
	follower.data = {"v": 1, "n": 0}
	gm.season = &"sommer"
	gm.day = 12
	gm.hour = 19
	var old_total: int = gm.total_day()
	_saved_slots.clear()
	gm.end_day()
	t.check("autosave_day_end_is_deferred", not sm.has_save(sm.AUTO_SLOT) and _saved_slots.is_empty(), "nothing is written inside the day_ended / day_started emissions")
	await t.frames(2)
	var day_doc: Variant = _read_json(sm.slot_path(sm.AUTO_SLOT))
	var day_ok: bool = day_doc != null and day_doc["game"]["day"] == 13 and day_doc["game"]["hour"] == gm.day_start_hour() and day_doc["game"]["total_day"] == old_total + 1 and day_doc["follower"]["n"] == 13
	t.check("autosave_on_day_end", day_ok and _saved_slots == [6] and sm.current_slot == 2, "one auto save of the NEW day (day %s, %02d:00, a day_started follower already at %s); save_completed %s" % [
		day_doc["game"]["day"] if day_doc != null else "-", gm.day_start_hour(), day_doc["follower"]["n"] if day_doc != null else "-", _saved_slots])
	# two midnights crossed by one advance_time = one save
	_saved_slots.clear()
	gm.advance_time(50 * 60)
	await t.frames(2)
	t.check("autosave_coalesces_midnights", _saved_slots == [6], "50 hours crossed two midnights, save_completed %s" % [_saved_slots])
	# the pass-out roll (02:00) is a day end too: ONE auto save, taken at the restart hour of the new date (the sleep sequence has not woken the player yet);
	# real midnight (raw 24:00) is NOT a day end: nothing is saved there (the 5 minute timer covers 00:00-02:00)
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))
	_saved_slots.clear()
	gm.hour = 23
	gm.minute = 55
	gm.advance_time(10)
	await t.frames(2)
	var no_save_at_midnight: bool = _saved_slots.is_empty() and not sm.has_save(sm.AUTO_SLOT) and gm.hour == 24
	gm.hour = gm.day_end_hour() - 1
	gm.minute = 55
	var roll_day: int = gm.day
	gm.advance_time(10)
	await t.frames(2)
	var roll_doc: Variant = _read_json(sm.slot_path(sm.AUTO_SLOT))
	t.check("autosave_on_the_day_end_roll", no_save_at_midnight and _saved_slots == [6] and roll_doc != null and roll_doc["game"]["day"] == roll_day + 1 and roll_doc["game"]["hour"] == gm.day_roll_restart_hour(),
		"23:55 + 10 min = raw 24:05: no save; 01:55 + 10 min = the day-end roll: one auto save of day %s at raw hour %s (restart hour %d); save_completed %s" % [roll_doc["game"]["day"] if roll_doc != null else "-", roll_doc["game"]["hour"] if roll_doc != null else "-", gm.day_roll_restart_hour(), _saved_slots])
	# the switch stops the DAY-END trigger as well as the timer: at the day end itself, and for a save that is already queued
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))
	_saved_slots.clear()
	var playing_here: bool = gm.current_phase == PH.PLAYING
	sm.autosave_enabled = false
	gm.end_day()
	await t.frames(2)
	t.check("autosave_disabled_day_end", playing_here and not sm.has_save(sm.AUTO_SLOT) and _saved_slots.is_empty(), "autosave_enabled = false: a day end while PLAYING writes nothing")
	sm.autosave_enabled = false
	gm.end_day()
	sm.autosave_enabled = true                     # switched on again within the frame: that day end happened while it was off
	await t.frames(2)
	t.check("autosave_disabled_day_end_is_not_queued", not sm.has_save(sm.AUTO_SLOT) and _saved_slots.is_empty(), "a day end that happened while autosave was off is not saved later")
	sm.autosave_enabled = true
	gm.end_day()
	sm.autosave_enabled = false                    # switched off after the day end, before the queued save runs
	await t.frames(2)
	t.check("autosave_switched_off_cancels_queued_day_end_save", not sm.has_save(sm.AUTO_SLOT) and _saved_slots.is_empty(), "the queued day-end save checks the switch again when it runs")
	sm.autosave_enabled = true
	gm.end_day()
	await t.frames(2)
	t.check("autosave_day_end_control_saves", sm.has_save(sm.AUTO_SLOT) and _saved_slots == [6], "the same day end with the switch on writes the auto slot once, so the three checks above are not vacuous")
	# a day-end save that is still queued when a new game begins is dropped: it would write the NEW game over the old run's autosave
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))
	_saved_slots.clear()
	gm.change_phase(PH.PLAYING)
	gm.end_day()
	gm.start_new_game("Neu", gm.CharacterType.ANIMAL, "Nygaard")      # new_game_started -> reset() inside the same frame
	var running_again: bool = gm.current_phase == PH.PLAYING
	await t.frames(2)
	t.check("autosave_queued_save_dropped_by_new_game", running_again and not sm.has_save(sm.AUTO_SLOT) and _saved_slots.is_empty(), "day end, then New Game in the same frame (phase %d): the queued save does not run" % gm.current_phase)
	gm.end_day()
	await t.frames(2)
	t.check("autosave_after_dropped_save_works", sm.has_save(sm.AUTO_SLOT) and _saved_slots == [6], "the next day end saves again (the drop did not wedge the queue)")
	# the phases of a run that is on (PAUSED, CUTSCENE) save on a day end, the menus do not
	var by_phase := {}
	for phase in [PH.PAUSED, PH.CUTSCENE, PH.CHARACTER_SELECT]:
		DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))
		gm.change_phase(phase)
		gm.end_day()
		await t.frames(2)
		by_phase[phase] = sm.has_save(sm.AUTO_SLOT)
	t.tree.paused = false
	t.check("autosave_day_end_by_phase", by_phase[PH.PAUSED] and by_phase[PH.CUTSCENE] and not by_phase[PH.CHARACTER_SELECT], "PAUSED %s, CUTSCENE %s, CHARACTER_SELECT %s" % [by_phase[PH.PAUSED], by_phase[PH.CUTSCENE], by_phase[PH.CHARACTER_SELECT]])
	# a day end in a menu, then play starts within the same frame: the day end happened in a menu, nothing is saved
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))
	gm.change_phase(PH.MENU)
	gm.end_day()
	gm.change_phase(PH.PLAYING)
	await t.frames(2)
	t.check("autosave_day_end_in_menu_is_not_queued", not sm.has_save(sm.AUTO_SLOT), "MENU day end, PLAYING a moment later in the same frame: no save")
	# no autosave from a menu
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))
	gm.change_phase(PH.MENU)
	gm.end_day()
	await t.frames(2)
	t.check("autosave_day_end_not_in_menu", not sm.has_save(sm.AUTO_SLOT), "phase MENU: a day end saves nothing")
	t.check("autosave_never_overwrites_manual", unchanged.call() and _listing(_scratch).filter(func(s: String) -> bool: return not s.begins_with("save_auto")) == listing_manual,
		"after the timer, the day end and a multi-day skip the manual files, their .bak files and the directory listing are unchanged")
	tm.resume_time()
	sm.autosave_enabled = false
	_clear_fakes()


# ================================================================ summaries (task 2)

func _test_summaries() -> void:
	_fresh()
	gm.start_new_game("Mia", gm.CharacterType.FAIRY, "Rosenhaven", &"fairy_stardust")
	gm.change_phase(PH.MENU)
	gm.day = 16
	gm.season = &"sommer"
	gm.year = 2
	gm.hour = 14
	gm.minute = 5
	gm.play_time_seconds = 3725.5
	eco.gold = 1250
	var world := _make_world({"area": "hyggebyen", "player_pos": [10.5, 20.5]})
	sm.save_game(0)
	world.free()
	var s: Dictionary = sm.get_save_summary(0)
	var want_total: int = gm.total_day_for(16, &"sommer", 2)
	t.check("summary_fields", s.get("farm_name") == "Rosenhaven" and s.get("character") == "fairy" and s.get("character_skin") == "fairy_stardust" and s.get("player_name") == "Mia" and s.get("day") == 16 and s.get("season") == "sommer"
		and s.get("year") == 2 and s.get("total_day") == want_total and s.get("gold") == 1250 and is_equal_approx(float(s.get("play_time_seconds")), 3725.5) and s.get("hour") == 14 and s.get("area") == "hyggebyen",
		"%s" % [s])
	t.check("summary_meta", s.get("slot") == 0 and s.get("is_auto") == false and str(s.get("timestamp")).length() >= 19 and float(s.get("saved_at")) > 1.0e9 and s.get("from_backup") == false, "slot, is_auto, timestamp, saved_at")
	t.check("summary_types", typeof(s["day"]) == TYPE_INT and typeof(s["gold"]) == TYPE_INT and typeof(s["total_day"]) == TYPE_INT and typeof(s["play_time_seconds"]) == TYPE_FLOAT, "ints after the JSON round trip")
	# the game day runs to 02:00: a save at raw 25:40 (01:40, the same game day) keeps hour 25 in the summary and loads back as 25:40 (the summary validator has no hour range);
	# a file that a build of the 24:00 days wrote right after its midnight roll (hour 0) loads as 02:00, not 24 h later; hours 6..23 of old saves are untouched (core.from_dict_* of clock26)
	gm.hour = 25
	gm.minute = 40
	sm.save_game(3)
	var late: Dictionary = sm.get_save_summary(3)
	gm.hour = 6
	gm.minute = 0
	var late_loaded: bool = sm.load_game(3)
	var late_back: bool = gm.hour == 25 and gm.minute == 40 and gm.day == 16
	var old_doc: Variant = _read_json(sm.slot_path(3))
	old_doc["game"]["hour"] = 0
	old_doc["meta"]["summary"]["hour"] = 0
	_put(3, old_doc)
	var old_loaded: bool = sm.load_game(3)
	t.check("save_late_hour_roundtrip_and_old_midnight_save", late.get("hour") == 25 and late.get("minute") == 40 and late_loaded and late_back and old_loaded and gm.hour == 2 and gm.day == 16,
		"raw 25:40 -> summary %s:%s, loads back %s; an old save at hour 0 loads at raw %02d:%02d (day %d)" % [late.get("hour"), late.get("minute"), late_back, gm.hour, gm.minute, gm.day])
	sm.delete_save(3)
	gm.play_time_seconds = 600.0                                     # a whole number of seconds is an int after the JSON load, the summary says float
	sm.save_game(2)
	t.check("summary_whole_play_time_is_float", typeof(sm.get_save_summary(2)["play_time_seconds"]) == TYPE_FLOAT and sm.get_save_summary(2)["play_time_seconds"] == 600.0, "600 s -> %s" % [type_string(typeof(sm.get_save_summary(2)["play_time_seconds"]))])
	t.check("inspect_slot_ok_has_no_error_code", sm.inspect_slot(2)["state"] == &"ok" and sm.inspect_slot(2)["code"] == "" and sm.inspect_slot(5)["code"] == "missing", "ok slot: code '%s', empty slot: '%s'" % [sm.inspect_slot(2)["code"], sm.inspect_slot(5)["code"]])
	sm.delete_save(2)
	# every character
	var kinds := {}
	for type_id in 4:
		gm.start_new_game("X", type_id, "F")
		sm.save_game(1)
		kinds[sm.get_save_summary(1).get("character")] = true
	t.check("summary_character_keys", kinds.has("animal") and kinds.has("fairy") and kinds.has("hobbit") and kinds.has("ghost"), "%s" % [kinds.keys()])
	sm.autosave()
	t.check("summary_auto_slot", sm.get_save_summary(sm.AUTO_SLOT).get("is_auto") == true and sm.get_save_summary(sm.AUTO_SLOT).get("slot") == 6, "")
	t.check("summary_empty_or_damaged_is_empty", sm.get_save_summary(5).is_empty() and sm.get_save_summary(9).is_empty(), "")
	_write_text(sm.slot_path(4), "{ nope")
	var newer := _payload()
	newer["meta"]["version"] = 5
	_put(3, newer)
	t.check("summary_damaged_and_newer_are_empty", sm.get_save_summary(4).is_empty() and sm.get_save_summary(3).is_empty(), "")
	var rows: Array[Dictionary] = sm.describe_slots()
	var states: Array = rows.map(func(r: Dictionary) -> String: return str(r["state"]))
	t.check("describe_slots", rows.size() == 7 and rows[6]["is_auto"] and states == ["ok", "ok", "empty", "newer", "corrupt", "empty", "ok"], "%s" % [states])
	# the legacy defaults still work
	t.check("legacy_default_arguments", sm.has_save() and not sm.get_save_summary().is_empty(), "has_save() / get_save_summary() read slot 0")
	t.check("summary_from_bare_payload_without_meta_summary", _summary_without_meta_summary(), "")


func _summary_without_meta_summary() -> bool:
	var doc := _payload()
	doc["meta"].erase("summary")
	_put(2, doc)
	var s: Dictionary = sm.get_save_summary(2)
	return s.get("day") == gm.day and s.get("gold") == eco.gold and s.has("farm_name")


## meta.summary is a cache: a value of the wrong type (hand-edited or half-written file) must not reach the load screen, whose
## "%d" / "%s" formatting would break. The summary is rebuilt from the sections instead, the slot stays loadable.
func _test_summary_types() -> void:
	_fresh()
	gm.start_new_game("Mia", gm.CharacterType.FAIRY, "Rosenhaven", &"fairy_stardust")
	gm.change_phase(PH.MENU)
	gm.day = 16
	gm.season = &"sommer"
	gm.year = 2
	gm.hour = 14
	gm.minute = 5
	gm.play_time_seconds = 3725.5
	eco.gold = 1250
	var good := _payload()
	var truth: Dictionary = (good["meta"]["summary"] as Dictionary).duplicate()
	t.check("summary_types_control", _put_and_summarize(good, 0).get("gold") == 1250 and truth.size() == SUMMARY_KINDS.size(), "an unedited save keeps its own summary (%d keys)" % truth.size())
	var bad_text: Array = [5, 1.5, true, null, [], {}, ["x"]]
	var bad_whole: Array = ["12", "", 1.5, true, null, [], {}, [3]]      # 1.5: a fractional day or gold is not a whole number
	var bad_number: Array = ["x", "3725.5", true, null, [], {}]
	var failures: Array[String] = []
	var tried := 0
	for key in SUMMARY_KINDS:
		var kind: String = SUMMARY_KINDS[key]
		var wrongs: Array = bad_text if kind == "str" else (bad_whole if kind == "int" else bad_number)
		if key == "character":
			wrongs = wrongs + ["dragon", ""]                        # a text, but not one of the heroes
		for wrong in wrongs:
			tried += 1
			var s: Dictionary = _put_and_summarize(_edit(good, ["meta", "summary", key], wrong), 1)
			var state: StringName = sm.inspect_slot(1)["state"]
			var d := _diff(truth, _without_slot_fields(s))
			if state != &"ok" or d != "" or not _summary_has_clean_types(s):
				failures.append("%s=%s -> state %s %s" % [key, wrong, state, d])
	t.check("summary_wrong_types_rebuilt", failures.is_empty(), "%d wrong values (one key at a time): the slot stays ok and the summary is rebuilt from the data%s" % [tried, "" if failures.is_empty() else " - " + str(failures.slice(0, 3))])
	# the summary as a whole is not an object, or has been cut down
	var whole_failures: Array[String] = []
	for wrong in ["oops", 7, [], null, {}, {"day": 3}]:
		var s: Dictionary = _put_and_summarize(_edit(good, ["meta", "summary"], wrong), 1)
		var d := _diff(truth, _without_slot_fields(s))
		if d != "" or not _summary_has_clean_types(s):
			whole_failures.append("%s -> %s" % [wrong, d])
	t.check("summary_not_an_object_rebuilt", whole_failures.is_empty(), "meta.summary a string, number, array, null, empty or cut down: rebuilt%s" % ["" if whole_failures.is_empty() else " - " + str(whole_failures.slice(0, 3))])
	# what the load screen does with it
	var shown: Dictionary = _put_and_summarize(_edit(_edit(good, ["meta", "summary", "day"], "sixteen"), ["meta", "summary", "gold"], [1250]), 1)
	var formattable := true
	for key in ["day", "gold", "year", "hour", "minute"]:
		formattable = formattable and typeof(shown.get(key)) == TYPE_INT
	var line: String = ("Dag %d, %d guld, %d. aar, %s, %d:%02d" % [shown["day"], shown["gold"], shown["year"], shown["player_name"], shown["hour"], shown["minute"]]) if formattable else "not formattable: %s" % [shown]
	t.check("summary_formats_with_percent_d", line == "Dag 16, 1250 guld, 2. aar, Mia, 14:05", line)
	# a valid summary of the right types is used as written (it is a cache, not recomputed every time)
	var cached := _edit(good, ["meta", "summary", "farm_name"], "Ikke Rosenhaven")
	t.check("summary_valid_cache_is_used", _put_and_summarize(cached, 1).get("farm_name") == "Ikke Rosenhaven", "right types: meta.summary wins over the sections")
	# the slot list shows the slot as ok
	_put(1, _edit(good, ["meta", "summary", "gold"], "lots"))
	var rows: Array[Dictionary] = sm.describe_slots()
	eco.gold = 5
	var loaded: bool = sm.load_game(1)
	t.check("summary_wrong_types_slot_row_ok", rows[1]["state"] == &"ok" and _eq(rows[1]["summary"].get("gold"), 1250) and loaded and eco.gold == 1250, "describe_slots row 1: ok, gold %s, and the slot loads (gold %d)" % [rows[1]["summary"].get("gold"), eco.gold])


## Writes `doc` into `slot`, returns get_save_summary(slot).
func _put_and_summarize(doc: Dictionary, slot: int) -> Dictionary:
	_put(slot, doc)
	return sm.get_save_summary(slot)


## A summary without the keys get_save_summary adds (slot, is_auto, timestamp, saved_at, from_backup).
func _without_slot_fields(summary: Dictionary) -> Dictionary:
	var out := summary.duplicate()
	for key in ["slot", "is_auto", "timestamp", "saved_at", "from_backup"]:
		out.erase(key)
	return out


## Every summary value has the type its consumers format it with.
func _summary_has_clean_types(summary: Dictionary) -> bool:
	for key in SUMMARY_KINDS:
		var kind: String = SUMMARY_KINDS[key]
		var value: Variant = summary.get(key)
		if kind == "str" and typeof(value) != TYPE_STRING:
			return false
		if kind == "int" and typeof(value) != TYPE_INT:
			return false
		if kind == "num" and typeof(value) != TYPE_FLOAT:
			return false
	return typeof(summary.get("slot")) == TYPE_INT and typeof(summary.get("is_auto")) == TYPE_BOOL and typeof(summary.get("saved_at")) == TYPE_FLOAT and typeof(summary.get("timestamp")) == TYPE_STRING


## A Node2D in group world_2d whose to_dict() returns `content` (the real WorldRoot2D lands in P04).
class WorldStub extends Node2D:
	var content: Dictionary = {}
	var from_dict_calls := 0
	func to_dict() -> Dictionary:
		return content.duplicate(true)
	func from_dict(_d: Dictionary) -> void:
		from_dict_calls += 1


func _make_world(content: Dictionary) -> WorldStub:
	var w := WorldStub.new()
	w.content = content
	w.add_to_group(&"world_2d")
	t.root.add_child(w)
	return w


# ================================================================ latest slot (task 2)

func _test_latest_slot() -> void:
	_fresh()
	t.check("latest_none", sm.get_latest_slot() == -1 and not sm.has_any_save(), "an empty directory")
	_set_state(10, 1)
	sm.clock_override = 1000.0
	sm.save_game(3)
	t.check("latest_single_manual", sm.get_latest_slot() == 3 and sm.has_any_save(), "")
	sm.clock_override = 1500.0
	sm.save_game(0)
	sm.clock_override = 2000.0
	sm.autosave()
	t.check("latest_auto_when_newest", sm.get_latest_slot() == sm.AUTO_SLOT, "slot 3 @1000, slot 0 @1500, auto @2000")
	sm.clock_override = 3000.0
	sm.save_game(5)
	t.check("latest_manual_newer_than_auto", sm.get_latest_slot() == 5, "a manual save at 3000 beats the auto save at 2000")
	# newest damaged: the next newest, not the damaged one
	_write_text(sm.slot_path(5), "{ damaged")
	t.check("latest_skips_damaged", sm.get_latest_slot() == sm.AUTO_SLOT, "slot 5 is damaged and has no .bak: Continue picks the auto slot")
	# ... unless a .bak rescues it (its own time stamp counts)
	sm.clock_override = 2500.0
	sm.save_game(5)
	sm.clock_override = 3500.0
	sm.save_game(5)                                  # bak @2500, primary @3500
	_write_text(sm.slot_path(5), "{ damaged again")
	t.check("latest_uses_bak_stamp", sm.get_latest_slot() == 5 and sm.get_save_summary(5).get("saved_at") == 2500.0, "damaged primary, .bak @2500 -> slot 5 (saved_at %s)" % sm.get_save_summary(5).get("saved_at"))
	var newer := _payload()
	newer["meta"]["version"] = 9
	newer["meta"]["saved_at"] = 9999.0
	_put(4, newer)
	t.check("latest_skips_newer_version", sm.get_latest_slot() == 5, "a save of a newer build is never picked")
	# ties
	_wipe()
	sm.clock_override = 777.0
	sm.save_game(4)
	sm.save_game(2)
	sm.autosave()
	t.check("latest_tie_goes_to_lowest_manual_slot", sm.get_latest_slot() == 2, "slot 4, slot 2 and auto at the same time: slot 2")
	_wipe()
	sm.save_game(sm.AUTO_SLOT)
	sm.save_game(5)
	t.check("latest_tie_manual_beats_auto", sm.get_latest_slot() == 5, "")
	# a clock override of exactly 0 is an override (the switch is "< 0 = off")
	_wipe()
	sm.clock_override = 0.0
	sm.save_game(1)
	var zero_doc: Variant = _read_json(sm.slot_path(1))
	t.check("clock_override_zero_is_used", zero_doc is Dictionary and zero_doc["meta"]["saved_at"] == 0, "saved_at %s" % [zero_doc["meta"]["saved_at"] if zero_doc is Dictionary else "-"])
	sm.clock_override = -1.0
	# saves inside one second are ordered by their fractions: the stamp is a float all the way (file, summary, comparison)
	_wipe()
	sm.clock_override = 5000.25
	sm.save_game(1)
	sm.clock_override = 5000.75
	sm.save_game(4)
	var in_file: Variant = _read_json(sm.slot_path(4))
	t.check("latest_sub_second_order", sm.get_latest_slot() == 4 and in_file is Dictionary and in_file["meta"]["saved_at"] == 5000.75 and sm.get_save_summary(1).get("saved_at") == 5000.25 and sm.get_save_summary(4).get("saved_at") == 5000.75,
		"slot 1 @5000.25, slot 4 @5000.75: slot 4 is newer (file saved_at %s)" % [in_file["meta"]["saved_at"] if in_file is Dictionary else "-"])
	_wipe()
	sm.clock_override = 7000.25
	sm.save_game(5)
	sm.clock_override = 7000.75
	sm.autosave()
	t.check("latest_sub_second_auto_beats_manual", sm.get_latest_slot() == sm.AUTO_SLOT, "manual @7000.25, auto @7000.75: the auto slot is newer, not a tie that the manual slot would win")
	_wipe()
	sm.clock_override = 7000.75
	sm.save_game(5)
	sm.clock_override = 7000.25
	sm.autosave()
	t.check("latest_sub_second_manual_beats_older_auto", sm.get_latest_slot() == 5, "manual @7000.75, auto @7000.25: the manual slot")
	sm.clock_override = -1.0
	_wipe()
	sm.save_game(2)
	sm.save_game(5)                                  # a few milliseconds later, the same second
	var first_stamp := float(sm.get_save_summary(2).get("saved_at"))
	var second_stamp := float(sm.get_save_summary(5).get("saved_at"))
	t.check("latest_real_clock_orders_saves_of_one_second", sm.get_latest_slot() == 5 and second_stamp > first_stamp and absf(second_stamp - Time.get_unix_time_from_system()) < 30.0,
		"two real saves back to back: %.4f then %.4f" % [first_stamp, second_stamp])
	# a v1 file has no saved_at: its time stamp string is used, as LOCAL time (see v1_time_stamp_is_local_time)
	_wipe()
	sm.clock_override = 5.0
	_put(1, _v1_payload("2026-10-13T12:00:00"))
	_put(2, _v1_payload("2026-10-13T12:00:01"))
	var local_offset := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	t.check("latest_reads_v1_time_stamp", sm.get_latest_slot() == 2 and _near(sm.get_save_summary(2).get("saved_at"), float(Time.get_unix_time_from_datetime_string("2026-10-13T12:00:01")) - local_offset), "slot 2 is one second newer")
	sm.clock_override = -1.0


# ================================================================ world hand-off (task 2/3)

func _test_world_contract() -> void:
	_fresh()
	var opaque := {
		"area": "farm", "player_pos": [512.5, 300], "flag": true, "nothing": null, "text": "Trætoppen æøå",
		"farm": {"plots": {"3,4": {"crop": "turnip", "growth_days": 2, "watered": true}}, "unlocked": ["a", "b"], "ratio": 0.375},
		"hotbar": {"slots": ["hoe_wooden", "", "watering_can_copper"], "selected": 2},
		"placed": [{"item": "scarecrow", "cell": [7, 9]}], "area_flags": {"bridge_seen": 1}, "empty_list": [], "empty_dict": {}, "negative": -12.25,
	}
	var world := _make_world(opaque)
	var payload: Dictionary = sm.gather_payload()
	t.check("world_gathered_from_group", payload["world"] == opaque and payload["meta"]["summary"]["area"] == "farm", "the node in group world_2d supplies the 'world' section")
	_set_state(5, 2)
	t.check("world_save_ok", sm.save_game(4), "")
	var text := _read_text(sm.slot_path(4))
	world.free()
	sm.pending_world = {"stale": true}
	t.check("world_load_ok", sm.load_game(4), "")
	t.check("world_dict_contract", sm.pending_world == opaque, "the opaque dictionary came back unchanged through the file: %s" % _diff(sm.pending_world, opaque))
	var taken: Dictionary = sm.consume_pending_world()
	t.check("world_consume_once", taken == opaque and sm.pending_world.is_empty() and sm.consume_pending_world().is_empty(), "consume_pending_world() hands it over once and clears it")
	# SaveManager never applies the world itself
	var applier := _make_world(opaque)
	_put(1, _payload())
	sm.load_game(1)
	t.check("world_not_applied_by_save_manager", applier.from_dict_calls == 0 and not sm.pending_world.is_empty(), "WorldRoot2D applies it in _ready, SaveManager only hands it over")
	applier.free()
	# a load clears an unconsumed older world, a save without a world section gives {}
	var bare := _payload()
	bare.erase("world")
	_put(1, bare)
	sm.pending_world = {"old": 1}
	t.check("world_absent_gives_empty", sm.load_game(1) and sm.pending_world.is_empty(), "a save without a world section -> pending_world == {}")
	# a save made while a loaded world is still waiting keeps it (no live world node yet)
	sm.pending_world = {"area": "hyggebyen", "waiting": 1}
	t.check("world_waiting_survives_a_save", sm.gather_payload()["world"] == {"area": "hyggebyen", "waiting": 1}, "")
	# vectors inside the world are sanitized like everywhere else
	var vec_world := _make_world({"pos": Vector2(1.5, 2.5)})
	t.check("world_vectors_become_arrays", sm.gather_payload()["world"] == {"pos": [1.5, 2.5]}, "")
	vec_world.free()
	# the text of the file is plain JSON a human can read
	t.check("world_file_is_readable_json", text.contains("\"area\": \"farm\"") and text.begins_with("{"), "pretty-printed JSON")
	sm.pending_world = {}


# ================================================================ v1 saves and the migration chain

func _v1_payload(stamp: String = "2026-10-13T12:00:00") -> Dictionary:
	return {
		"meta": {"version": 1, "timestamp": stamp},
		"game": {"version": 1, "player_name": "Old", "character_type": 2, "character_skin": "hobbit_pip", "farm_name": "Gamle Gaard", "day": 9, "season": "efteraar", "year": 3, "hour": 17, "minute": 30,
			"world_flags": {"intro_done": true, "tier": 2.0}, "unlocked_zones": ["farm", "city"], "discovered_locations": ["farm"], "play_time_seconds": 600.0},
		"economy": {"gold": 1234, "inventory": [{"id": "wood", "amount": 12.0, "meta": {}}], "equipment": {"weapon": "sword_rusty"}},
		"quests": {"active": {}, "completed": ["intro_lottery"], "failed": [], "offered": [], "flags": {"def_lost_cat": {"id": "lost_cat"}, "def_fix_roof": {"id": "fix_roof"}, "runtime_flag": 1}},
		"time": {"time_scale": 1.0, "weather": "regn", "weather_duration_hours": 4},
	}


func _test_v1_migration() -> void:
	_fresh()
	var husb := FakeSection.new()
	husb.tag = "husbandry"
	husb.log = _log
	var shops := FakeSection.new()
	shops.tag = "shops"
	shops.log = _log
	svc.override("AnimalHusbandry", husb)
	svc.override("ShopSystem", shops)
	_fakes.append(husb)
	_fakes.append(shops)
	husb.data = {"stale": true}
	_put(0, _v1_payload())
	var verdict: Dictionary = sm.validate_payload(_read_json(sm.slot_path(0)))
	t.check("v1_validates_and_migrates", verdict["ok"] and verdict["payload"]["meta"]["version"] == 2 and verdict["payload"]["meta"].get("migrated_from") == 1 and not verdict["payload"]["quests"]["flags"].has("def_lost_cat")
		and verdict["payload"]["quests"]["flags"].get("runtime_flag") == 1 and float(verdict["payload"]["meta"]["saved_at"]) > 1.0e9, "meta.version 1 -> 2, quest definitions dropped, runtime flags kept, saved_at from the time stamp")
	var migrated_summary: Variant = verdict["payload"]["meta"].get("summary")
	t.check("v1_migration_writes_the_summary", migrated_summary is Dictionary and (migrated_summary as Dictionary).get("gold") == 1234 and (migrated_summary as Dictionary).get("day") == 9 and (migrated_summary as Dictionary).get("character") == "hobbit",
		"the migrated payload carries meta.summary like a v2 save: %s" % [migrated_summary])
	_set_state(1, 1)
	_log.clear()
	var ok: bool = sm.load_game(0)
	t.check("v1_loads", ok and eco.gold == 1234 and gm.day == 9 and gm.season == &"efteraar" and gm.player_name == "Old" and gm.character_type == gm.CharacterType.HOBBIT and tm.weather == &"regn" and qm.is_completed(&"intro_lottery"),
		"gold %d, day %d, %s, %s" % [eco.gold, gm.day, gm.season, gm.player_name])
	t.check("v1_missing_sections_reset", ok and _log.has("reset:husbandry") and _log.has("reset:shops") and husb.data.get("stale") == null, "husbandry and shops were not in a v1 save: reset(), not stale: %s" % [_log])
	t.check("v1_world_empty_and_ints", sm.pending_world.is_empty() and typeof(gm.get_flag(&"tier")) == TYPE_INT and gm.flag_int(&"tier") == 2, "no world in a v1 save, flags back as ints")
	var s: Dictionary = sm.get_save_summary(0)
	t.check("v1_summary", s.get("day") == 9 and s.get("gold") == 1234 and s.get("farm_name") == "Gamle Gaard" and s.get("character") == "hobbit" and s.get("total_day") == gm.total_day_for(9, &"efteraar", 3), "%s" % [s])
	# after a load the quest definitions are still there (audit T1): accept a quest that was never started
	t.check("quest_defs_survive_load", _quest_defined(&"lost_cat") and qm.accept_quest(&"fix_roof"), "loading a save does not wipe the Lua definitions")
	# a v2 save without quest 'flags' at all must not wipe them either
	var doc := _payload()
	doc["quests"].erase("flags")
	_put(1, doc)
	t.check("quest_defs_survive_save_without_flags", sm.load_game(1) and _quest_defined(&"lost_cat"), "audit T1")
	# and a save never contains them
	var fresh_doc := _payload()
	var def_keys: Array = fresh_doc["quests"].get("flags", {}).keys().filter(func(k) -> bool: return str(k).begins_with("def_"))
	t.check("save_has_no_quest_defs", def_keys.is_empty(), "no def_ entries in quests.flags (%d)" % def_keys.size())
	svc.clear_overrides()
	_clear_fakes()


## A v1 time stamp is LOCAL time (the 3D build wrote Time.get_datetime_string_from_system()): saved_at is the same instant in
## UTC, so a v1 slot is ordered correctly against v2 saves. The time zone is pinned through ProbeManager.
func _test_v1_time_zone() -> void:
	_fresh()
	var stamp := "2026-10-13T12:00:00"
	var naive := float(Time.get_unix_time_from_datetime_string(stamp))      # the engine reads the string as UTC
	_put(1, _v1_payload(stamp))
	var probe := _new_probe(120)                                            # Denmark in summer: local = UTC + 2 h
	var verdict: Dictionary = probe.validate_payload(_read_json(sm.slot_path(1)))
	var migrated: float = float(verdict["payload"]["meta"]["saved_at"])
	var inspected: float = float(probe.inspect_slot(1)["saved_at"])
	var summarized: float = float(probe.get_save_summary(1)["saved_at"])
	t.check("v1_time_stamp_is_local_time", _near(migrated, naive - 7200.0) and _near(inspected, naive - 7200.0) and _near(summarized, naive - 7200.0),
		"12:00 local at UTC+2 is 10:00 UTC: migrated %s, inspected %s, summary %s, wanted %s" % [migrated, inspected, summarized, naive - 7200.0])
	var zones := {-300: naive + 18000.0, 0: naive, 330: naive - 19800.0, 765: naive - 45900.0}
	var zone_failures: Array[String] = []
	for bias in zones:
		probe.bias_minutes = bias
		var at: float = float(probe.inspect_slot(1)["saved_at"])
		if not _near(at, float(zones[bias])):
			zone_failures.append("%d min: %s want %s" % [bias, at, zones[bias]])
	t.check("v1_time_stamp_other_time_zones", zone_failures.is_empty(), "UTC-5, UTC, UTC+5:30, UTC+12:45%s" % ["" if zone_failures.is_empty() else " - " + str(zone_failures)])
	# Continue: the v1 slot (12:00 local = 10:00 UTC at UTC+2) against a v2 autosave made half an hour after it
	probe.bias_minutes = 120
	sm.clock_override = naive - 7200.0 + 1800.0
	sm.autosave()
	t.check("v1_slot_is_older_than_a_later_autosave", probe.get_latest_slot() == sm.AUTO_SLOT, "v1 slot at 10:00 UTC, autosave at 10:30 UTC: the autosave is the latest, not the v1 slot (which was read as 12:00 UTC)")
	sm.clock_override = naive - 7200.0 - 1800.0
	sm.autosave()
	t.check("v1_slot_is_newer_than_an_earlier_autosave", probe.get_latest_slot() == 1, "autosave at 09:30 UTC: the v1 slot at 10:00 UTC is the latest")
	probe.bias_minutes = -300                                               # west of Greenwich the same mistake goes the other way
	sm.clock_override = naive + 18000.0 - 1800.0
	sm.autosave()
	t.check("v1_slot_west_of_greenwich_is_newer_than_an_earlier_autosave", probe.get_latest_slot() == 1, "12:00 local at UTC-5 is 17:00 UTC, the autosave is from 16:30 UTC: the v1 slot")
	sm.clock_override = -1.0
	# a damaged time stamp: no engine error (the harness fails on one), the slot counts as unknown / oldest and stays loadable
	probe.bias_minutes = 120
	var bad_failures: Array[String] = []
	for bad in ["", "garbage", "2026-13-45T99:99:99", "2026-00-10T12:00:00", "2026-10-00T12:00:00", "2026-02-30T12:00:00", "2023-02-29T12:00:00", "2100-02-29T12:00:00", "2026-10-13T24:00:00", "2026-10-13T12:60:00", "2026-10-13T12:00:60", "2026-10-13", "12:00:00", "1969-12-31T23:59:59", "0000-10-13T12:00:00", "2026-10-13T12:00:00Z"]:
		_put(2, _v1_payload(bad))
		var info: Dictionary = probe.inspect_slot(2)
		if info["state"] != &"ok" or float(info["saved_at"]) != 0.0:
			bad_failures.append("'%s' -> %s %s" % [bad, info["state"], info["saved_at"]])
	t.check("v1_damaged_time_stamp_is_oldest_without_engine_error", bad_failures.is_empty(), "16 stamps that are not a real date and time: saved_at 0.0, state ok%s" % ["" if bad_failures.is_empty() else " - " + str(bad_failures.slice(0, 3))])
	var real_failures: Array[String] = []
	for good_stamp in ["2024-02-29T12:00:00", "2000-02-29T00:00:00", "2026-12-31T23:59:59", "2026-10-13 12:00:00", "1970-01-02T00:00:00", "2026-03-01T00:00:00", "2026-01-31T00:00:00", "2026-05-01T23:00:00", "2026-04-30T00:59:00", "1970-01-01T00:00:00"]:
		_put(2, _v1_payload(good_stamp))
		var want := float(Time.get_unix_time_from_datetime_string(good_stamp)) - 7200.0
		var got: float = float(probe.inspect_slot(2)["saved_at"])
		if not _near(got, want):
			real_failures.append("'%s' -> %s want %s" % [good_stamp, got, want])
	t.check("v1_real_time_stamps_are_read", real_failures.is_empty(), "a leap day, the last second of a year, a space as separator%s" % ["" if real_failures.is_empty() else " - " + str(real_failures)])
	# a v2 save whose saved_at was lost or damaged (hand-edited file) falls back to its time stamp, local time as well
	var lost := _payload()
	lost["meta"].erase("saved_at")
	lost["meta"]["timestamp"] = stamp
	_put(3, lost)
	var lost_at: float = float(probe.inspect_slot(3)["saved_at"])
	lost["meta"]["saved_at"] = "soon"
	_put(3, lost)
	var wrong_at: float = float(probe.inspect_slot(3)["saved_at"])
	t.check("v2_lost_saved_at_falls_back_to_local_time_stamp", _near(lost_at, naive - 7200.0) and _near(wrong_at, naive - 7200.0) and probe.inspect_slot(3)["state"] == &"ok",
		"saved_at missing: %s, saved_at a string: %s, wanted %s" % [lost_at, wrong_at, naive - 7200.0])
	probe.free()


# ================================================================ round trip of every system of this wave (task 3)

func _test_roundtrip_all_systems() -> void:
	_fresh()
	# the systems with a fake store where the real one has no save API yet are listed in the report (ShopSystem: P12)
	var husb_real: bool = ah.has_method("to_dict") and ah.has_method("from_dict")
	var shop_real: bool = shop.has_method("to_dict") and shop.has_method("from_dict")
	var fake_shop: FakeSection = null
	if not shop_real:
		fake_shop = FakeSection.new()
		fake_shop.tag = "shops"
		fake_shop.log = _log
		fake_shop.data = {"general_store": {"turnip_seeds": 17, "wood": 3}, "bakery": {"cookie": 2}}
		svc.override("ShopSystem", fake_shop)
		_fakes.append(fake_shop)
		t.skip("roundtrip shops: ShopSystem has no to_dict/from_dict in this tree (P12 handoff): the section is exercised with a stand-in")
	# ---- build a rich state
	gm.start_new_game("Mia", gm.CharacterType.FAIRY, "Rosenhaven", &"fairy_stardust")
	gm.change_phase(PH.MENU)
	gm.day = 16
	gm.season = &"sommer"
	gm.year = 2
	gm.hour = 14
	gm.minute = 5
	gm.play_time_seconds = 1234.5
	gm.set_flag(&"home_tier", 3)
	gm.set_flag(&"ratio", 0.5)
	gm.set_flag(&"nickname", "Mia æøå")
	gm.unlock_zone(&"dark_forest")
	tm.set_weather(&"regn")
	tm.set_time_scale(1.5)
	eco.gold = 5000
	eco.add_item(&"wood", 100)
	eco.add_item(&"stone", 100)
	eco.add_item(&"carrot_seeds", 3)
	var built: bool = ah.build_building(&"coop") if ah.has_method("build_building") else false
	eco.add_item(&"baby_chick", 2)
	var adopted: bool = ah.adopt_animal(&"baby_chick") if ah.has_method("adopt_animal") else false
	var animal_fields: bool = adopted and "animals" in ah and not ah.animals.is_empty()
	if animal_fields:
		var first = ah.animals.values()[0]
		first.happiness = 77.5
		first.bond_level = 2
		first.products_ready = 1
	var bought_item := &""
	var bought_stock := -1
	if shop_real:                                   # a purchase at the seed shop: the shelf is one of the saved things
		for row in shop.get_shop_inventory(&"seed_shop"):
			if row["buyable"] and int(row["stock"]) >= 2 and shop.buy_item(&"seed_shop", row["item_id"], 2):
				bought_item = row["item_id"]
				bought_stock = int(((shop.to_dict()["stock"] as Dictionary).get("seed_shop", {}) as Dictionary).get(str(bought_item), -1))
				break
	qm.accept_quest(&"intro_lottery")
	qm.accept_quest(&"lost_cat")
	var progress: Dictionary = qm.get_quest_progress(&"lost_cat")
	if not progress.is_empty() and not (progress["objectives"] as Dictionary).is_empty():
		qm.update_objective(&"lost_cat", (progress["objectives"] as Dictionary).keys()[0], 1)
	qm.offer_quest(&"fix_roof")
	qm.accept_quest(&"cookie_delivery")
	qm.complete_quest(&"cookie_delivery")
	qm.accept_quest(&"supply_run")
	qm.fail_quest(&"supply_run")
	# intro_done must arrive AFTER intro_lottery is active: the Lua is_available gate refuses it otherwise
	# (the flag is set before the save so the loaded state still shows an active quest beside it).
	gm.set_flag(&"intro_done", true)
	eco.gold = 777                                   # after every purchase and quest reward
	var world := _make_world({"area": "farm", "player_pos": [100.5, 200], "farm": {"plots": {}}})
	var before := {"game": gm.to_dict(), "time": tm.to_dict(), "economy": eco.to_dict(), "quests": qm.to_dict(), "husbandry": ah.to_dict()}
	if shop_real:
		before["shops"] = shop.to_dict()
	var before_n: Dictionary = JSON.parse_string(JSON.stringify(sm.gather_payload()))
	var wood_before: int = eco.count_item(&"wood")
	var seeds_before: int = eco.count_item(&"carrot_seeds")
	var animals_before: int = (ah.to_dict().get("animals", {}) as Dictionary).size()
	var buildings_before: int = (ah.to_dict().get("buildings", {}) as Dictionary).size()
	var completed_before: int = _names(qm.to_dict().get("completed")).size()
	t.check("roundtrip_save_ok", sm.save_game(1), "")
	world.free()
	# ---- trash everything
	gm.start_new_game("Other", gm.CharacterType.ANIMAL, "X")
	gm.change_phase(PH.MENU)
	eco.gold = 1
	eco.inventory.clear()
	_clear_quests()
	tm.set_weather(&"klart")
	tm.set_time_scale(1.0)
	_clear_husbandry()
	if fake_shop != null:
		fake_shop.data = {"scribble": 1}
	gm.day = 2
	# ---- load
	_loaded_slots.clear()
	var ok: bool = sm.load_game(1)
	t.check("roundtrip_load_ok", ok and _loaded_slots == [1] and sm.current_slot == 1, "load_completed(1)")
	var after_n: Dictionary = JSON.parse_string(JSON.stringify(sm.gather_payload()))
	# gold, items
	t.check("roundtrip_gold_items", eco.gold == 777 and eco.count_item(&"wood") == wood_before and eco.count_item(&"carrot_seeds") == seeds_before and _diff(before["economy"], eco.to_dict()) == "",
		"gold %d, wood %d, carrot_seeds %d, economy dictionary %s" % [eco.gold, eco.count_item(&"wood"), eco.count_item(&"carrot_seeds"), _diff(before["economy"], eco.to_dict())])
	var slot_types_ok := true
	for slot in eco.inventory:
		if typeof(slot) == TYPE_DICTIONARY and typeof(slot.get("amount")) != TYPE_INT:
			slot_types_ok = false
	t.check("roundtrip_inventory_amounts_are_ints", slot_types_ok and typeof(eco.gold) == TYPE_INT, "no 3.0 in the backpack")
	# quests
	var quest_diff := _diff(before["quests"]["active"], qm.to_dict()["active"])
	var quest_parts := {"intro_active": qm.is_active(&"intro_lottery"), "cat_active": qm.is_active(&"lost_cat"), "cookie_done": qm.is_completed(&"cookie_delivery"), "completed_size": _names(qm.to_dict().get("completed")).size() == completed_before,
		"failed": _names(qm.to_dict().get("failed")).has("supply_run"), "offered": _names(qm.to_dict().get("offered")).has("fix_roof"), "progress_equal": quest_diff == ""}
	t.check("roundtrip_quests", not quest_parts.values().has(false), "active, completed, failed, offered, objective progress: %s %s" % [quest_parts, quest_diff])
	# time and calendar
	t.check("roundtrip_time_calendar", gm.day == 16 and gm.season == &"sommer" and gm.year == 2 and gm.hour == 14 and gm.minute == 5 and is_equal_approx(gm.play_time_seconds, 1234.5) and gm.total_day() == before["game"]["total_day"]
		and tm.weather == &"regn" and is_equal_approx(tm.time_scale, 1.5) and gm.flag_int(&"home_tier") == 3 and gm.get_flag(&"intro_done") == true and gm.get_flag(&"ratio") == 0.5 and gm.get_flag(&"nickname") == "Mia æøå"
		and gm.is_zone_unlocked(&"dark_forest") and gm.player_name == "Mia" and gm.farm_name == "Rosenhaven" and gm.character_skin == &"fairy_stardust" and gm.character_type == gm.CharacterType.FAIRY and tm.weekday_index() == (16 - 1) % 7,
		"%s day %d, %s, weather %s, weekday %d, flags, zones, name, skin" % [gm.season, gm.day, gm.player_name, tm.weather, tm.weekday_index()])
	t.check("roundtrip_calendar_types", typeof(gm.day) == TYPE_INT and typeof(gm.year) == TYPE_INT and typeof(gm.hour) == TYPE_INT and typeof(gm.season) == TYPE_STRING_NAME and typeof(gm.character_skin) == TYPE_STRING_NAME and typeof(gm.world_flags.get(&"home_tier")) == TYPE_INT,
		"int and StringName typed again")
	# husbandry
	var husb_diff := _diff(before["husbandry"], ah.to_dict())
	if built or adopted:
		var animals_now: int = (ah.to_dict().get("animals", {}) as Dictionary).size()
		var buildings_now: int = (ah.to_dict().get("buildings", {}) as Dictionary).size()
		t.check("roundtrip_husbandry", husb_real and animals_now == animals_before and buildings_now == buildings_before and husb_diff == "" and (animals_before > 0 or buildings_before > 0), "animals %d, buildings %d, dictionary %s" % [animals_now, buildings_now, husb_diff])
		if animal_fields and "animals" in ah and not ah.animals.is_empty():
			var back = ah.animals.values()[0]
			t.check("roundtrip_husbandry_animal_fields", is_equal_approx(float(back.happiness), 77.5) and int(back.bond_level) == 2 and int(back.products_ready) == 1, "happiness %s, bond %s" % [back.happiness, back.bond_level])
	else:
		t.check("roundtrip_husbandry", husb_real and husb_diff == "", "AnimalHusbandry could not be filled through its API in this tree (%s): empty state round-trips" % ["no coop built" if not built else "no animal adopted"])
	# shops
	if shop_real:
		var stock_back := int(((shop.to_dict()["stock"] as Dictionary).get("seed_shop", {}) as Dictionary).get(str(bought_item), -1))
		t.check("roundtrip_shops", _diff(before["shops"], shop.to_dict()) == "", "ShopSystem stock: %s" % _diff(before["shops"], shop.to_dict()))
		if bought_item != &"":
			t.check("roundtrip_shop_stock_persists", stock_back == bought_stock and bought_stock >= 0, "%s: %d on the shelf before the save, %d after the load" % [bought_item, bought_stock, stock_back])
		else:
			t.skip("roundtrip_shop_stock_persists: nothing could be bought at seed_shop in this tree")
	else:
		t.check("roundtrip_shops", fake_shop.data == {"general_store": {"turnip_seeds": 17, "wood": 3}, "bakery": {"cookie": 2}}, "the 'shops' section carries the stand-in's stock (the real ShopSystem has no save API yet)")
	# the world travels along, opaque
	t.check("roundtrip_world_handed_over", sm.pending_world == {"area": "farm", "player_pos": [100.5, 200], "farm": {"plots": {}}}, "")
	# and the whole payload is identical (sections, meta aside)
	var whole := ""
	for key in before_n:
		if key == "meta":
			continue
		var d := _diff(before_n[key], after_n.get(key), key)
		if d != "":
			whole = d
			break
	t.check("roundtrip_all_systems", whole == "" and ok, "gather -> JSON -> load -> gather: every section equal (%s)" % ("identical" if whole == "" else whole))
	# the state a player would notice if a section were lost: nothing of the trashed state is left
	t.check("roundtrip_nothing_stale", eco.gold != 1 and gm.day != 2 and gm.player_name != "Other", "")
	sm.pending_world = {}
	svc.clear_overrides()
	_clear_fakes()


# ================================================================ the real world scene (WorldRoot2D, P04)

## A fresh game in the real world scene: its to_dict() ends up in the save, and load_and_enter() brings the area and the
## player back through pending_world (taken by WorldRoot2D._ready). The crops, the hotbar and the placed items inside the
## world dictionary are asserted by farm.save_roundtrip (P06), animals.save_roundtrip (P20) and zz_acceptance (P27).
func _test_real_world() -> void:
	_fresh()
	var started: bool = await t.start_world("fairy")
	var world: Node = t.first(&"world_2d")
	if not started or world == null or not world.has_method("to_dict"):
		t.skip("real_world: the world scene is not a WorldRoot2D (group world_2d with to_dict) in this tree")
		await t.go_menu()
		return
	await t.frames(20)
	var player: Node = t.player()
	var world_before: Dictionary = world.to_dict()
	var spot: Vector2 = player.global_position + Vector2(96, 48)
	player.global_position = spot
	await t.physics(3)
	spot = player.global_position                         # wherever physics left the player
	var saved: bool = sm.save_game(2)
	var doc: Variant = _read_json(sm.slot_path(2))
	var saved_world: Dictionary = doc["world"] if doc is Dictionary and (doc as Dictionary).has("world") else {}
	t.check("real_world_in_save", saved and str(saved_world.get("area", "")) == str(world_before.get("area", "?")) and saved_world.has("player_pos") and doc["meta"]["summary"]["area"] == str(world_before.get("area", "?")),
		"the live WorldRoot2D supplied the 'world' section: area %s, player_pos %s" % [saved_world.get("area"), saved_world.get("player_pos")])
	var old_id := world.get_instance_id()
	player.global_position = spot + Vector2(400, 300)
	sm.pending_world = {}
	var entered: bool = sm.load_and_enter(2)
	var pending_at_once: bool = not sm.pending_world.is_empty()
	var fresh_world: bool = await t.until(func() -> bool: return t.first(&"world_2d") != null and t.first(&"world_2d").get_instance_id() != old_id and t.player() != null, 15.0)
	await t.frames(15)
	var world_after: Node = t.first(&"world_2d")
	var player_after: Node = t.player()
	var moved: float = player_after.global_position.distance_to(spot) if player_after != null else 9999.0
	t.check("real_world_hand_off", entered and pending_at_once and fresh_world and sm.pending_world.is_empty(), "load_and_enter left the world in pending_world, the new WorldRoot2D took it in _ready (pending now %s)" % [sm.pending_world])
	t.check("real_world_restored", fresh_world and world_after != null and str(world_after.to_dict().get("area", "")) == str(world_before.get("area", "?")) and moved < 60.0, "same area, the player is %.1f px from the saved spot" % moved)
	t.check("real_world_phase_playing", gm.current_phase == PH.PLAYING and not t.tree.paused and sm.current_slot == 2, "phase %d, slot %d" % [gm.current_phase, sm.current_slot])
	await t.go_menu()


# ================================================================ feedback in both languages

func _test_feedback_locales() -> void:
	_fresh()
	_set_state(5, 5)
	var all_ok := true
	var detail: Array[String] = []
	for locale in ["da", "en"]:
		TranslationServer.set_locale(locale)
		_notes.clear()
		sm.save_game(0)                                      # NOTIF_SAVED_* exist in the CSVs: real text with the slot number
		var saved_toast: Array = _last_note()
		var saved_ok := str(saved_toast[1]).contains("1") and not str(saved_toast[1]).contains("%") and str(saved_toast[0]) == sm.tr("NOTIF_SAVED_TITLE") and str(saved_toast[0]) != "NOTIF_SAVED_TITLE"
		_write_text(sm.slot_path(1), "{ nope")
		_notes.clear()
		sm.load_game(1)
		var fail_ok := _is_fail_note("corrupt") and _notes.size() == 1
		all_ok = all_ok and saved_ok and fail_ok
		detail.append("%s: saved '%s' / failed '%s'" % [locale, saved_toast[1], _last_note()[1]])
	TranslationServer.set_locale("da")
	t.check("feedback_follows_locale", all_ok, "; ".join(detail))
	# every message key SaveManager can post, listed for the localization owner (P16 menus.csv)
	var raw: Array[String] = []
	for key in ["NOTIF_LOAD_FAILED_TITLE", "NOTIF_LOAD_FAILED_MISSING", "NOTIF_LOAD_FAILED_CORRUPT", "NOTIF_LOAD_FAILED_VERSION", "NOTIF_LOAD_FAILED_APPLY", "NOTIF_LOAD_BACKUP_TITLE", "NOTIF_LOAD_BACKUP_MSG", "NOTIF_SAVE_FAILED_TITLE", "NOTIF_SAVE_FAILED_MSG"]:
		if sm.tr(key) == key:
			raw.append(key)
	if raw.is_empty():
		t.check("feedback_keys_defined", true, "all nine NOTIF_LOAD_* / NOTIF_SAVE_FAILED_* keys resolve in da and en")
	else:
		t.skip("feedback_keys_defined: %d key(s) are still raw because no CSV defines them yet (handoff to P16 menus.csv / P03 key_owners.json): %s" % [raw.size(), ", ".join(raw)])
	_wipe()


# ================================================================ Continue from the menu (task 2/3)

func _test_continue() -> void:
	_fresh()
	await t.go_menu()
	# nothing to continue
	_notes.clear()
	var none: bool = sm.continue_latest()
	t.check("continue_without_save", not none and sm.last_error.get("code") == "missing" and _is_fail_note("missing") and t.scene_path() == t.MENU_SCENE and gm.current_phase == PH.MENU and not t.tree.paused,
		"false, feedback, still on the title (scene %s, phase %d)" % [t.scene_name(), gm.current_phase])
	# two saves: an older manual one and a newer autosave
	_set_state(777, 5, "Mia")
	sm.clock_override = 1000.0
	sm.save_game(2)
	_set_state(888, 6, "Mia")
	sm.clock_override = 2000.0
	sm.autosave()
	sm.clock_override = -1.0
	# change the running state so Continue has something to overwrite
	_set_state(1, 1, "Other")
	_loaded_slots.clear()
	var started: bool = sm.continue_latest()
	var phase_at_once: int = gm.current_phase                       # before the world scene had a frame: SaveManager itself puts the game into PLAYING
	var entered: bool = await t.until(func() -> bool: return t.scene_path() == WORLD_SCENE, 15.0)
	await t.frames(5)
	t.check("continue_from_menu", started and entered and eco.gold == 888 and gm.day == 6 and gm.player_name == "Mia" and _loaded_slots == [6] and sm.current_slot == sm.NO_SLOT,
		"Continue loaded the newest save (the auto slot: gold %d day %d), load_completed %s, scene %s, current_slot %d (an autosave is no manual slot)" % [eco.gold, gm.day, _loaded_slots, t.scene_name(), sm.current_slot])
	t.check("continue_enters_playing", gm.current_phase == PH.PLAYING and phase_at_once == PH.PLAYING and not t.tree.paused and not gm.is_modal_open(), "phase %d (%d right after the call), tree not paused, no modal left" % [gm.current_phase, phase_at_once])
	t.check("continue_does_not_replay_new_game_opening", not bool(gm.get_flag(GameManager.FLAG_INTRO_PENDING, false)))
	t.check("continue_world_hand_off", sm.pending_world.is_empty() or sm.pending_world == {}, "pending_world is empty: the world scene took it (or the save had none)")
	# load_and_enter from a pause menu: the modal stack goes, the tree runs
	await t.go_menu()
	_set_state(1, 1, "Other")
	gm.push_modal(&"pause", true)
	var paused_before: bool = t.tree.paused
	var enter_ok: bool = sm.load_and_enter(2)
	var entered2: bool = await t.until(func() -> bool: return t.scene_path() == WORLD_SCENE, 15.0)
	await t.frames(5)
	t.check("load_and_enter_from_pause", paused_before and enter_ok and entered2 and eco.gold == 777 and gm.day == 5 and not gm.is_modal_open() and gm.current_phase == PH.PLAYING and not t.tree.paused and sm.current_slot == 2,
		"slot 2 (gold %d, day %d), modals popped, phase %d, tree running" % [eco.gold, gm.day, gm.current_phase])
	# a failing load_and_enter changes neither scene nor phase
	await t.go_menu()
	_write_text(sm.slot_path(3), "{ broken")
	var phase_before: int = gm.current_phase
	var failed: bool = sm.load_and_enter(3)
	await t.frames(3)
	t.check("load_and_enter_failure_stays_put", not failed and t.scene_path() == t.MENU_SCENE and gm.current_phase == phase_before and not t.tree.paused and _is_fail_note("corrupt"), "scene %s, phase %d" % [t.scene_name(), gm.current_phase])
	# the newest save damaged: Continue takes the next one (the damaged file is not 'latest')
	_wipe()
	_set_state(10, 2, "Mia")
	sm.clock_override = 100.0
	sm.save_game(0)
	_set_state(20, 3, "Mia")
	sm.clock_override = 200.0
	sm.save_game(1)
	_write_text(sm.slot_path(1), "{ broken")
	sm.clock_override = -1.0
	_set_state(1, 1, "Other")
	var fallback: bool = sm.continue_latest()
	var entered3: bool = await t.until(func() -> bool: return t.scene_path() == WORLD_SCENE, 15.0)
	await t.frames(3)
	t.check("continue_skips_damaged_newest", fallback and entered3 and eco.gold == 10 and sm.current_slot == 0, "the damaged slot 1 is skipped, slot 0 loads (gold %d)" % eco.gold)
	# a world scene that does not exist is refused BEFORE the save is applied: no half-loaded game, nothing changes
	await t.go_menu()
	_wipe()
	_set_state(10, 2, "Mia")
	sm.save_game(0)
	_set_state(1, 1, "Other")
	var before_refusal := _sentinel()
	var notes_before := _notes.size()
	sm.world_scene = "res://scenes/main/no_such_world.tscn"
	var refused: bool = sm.load_and_enter(0)
	sm.world_scene = sm.WORLD_SCENE
	await t.frames(3)
	t.check("load_and_enter_missing_world_scene_changes_nothing", not refused and sm.last_error.get("code") == "scene" and _diff(before_refusal, _sentinel()) == "" and eco.gold == 1 and t.scene_path() == t.MENU_SCENE and _notes.size() == notes_before + 1 and str(_last_note()[1]) == sm.tr("NOTIF_LOAD_FAILED_APPLY"),
		"the scene is missing: false, code 'scene', the running game is unchanged (gold %d), still on the title, one notification" % eco.gold)
	# a damaged primary rescued by its .bak
	await t.go_menu()
	_wipe()
	_set_state(30, 4, "Mia")
	sm.save_game(4)
	_set_state(40, 5, "Mia")
	sm.save_game(4)
	_write_text(sm.slot_path(4), "{ broken")
	_set_state(1, 1, "Other")
	_notes.clear()
	var rescued: bool = sm.continue_latest()
	var entered4: bool = await t.until(func() -> bool: return t.scene_path() == WORLD_SCENE, 15.0)
	await t.frames(3)
	t.check("continue_uses_bak_with_feedback", rescued and entered4 and eco.gold == 30 and _notes.any(func(n) -> bool: return str(n[0]) == sm.tr("NOTIF_LOAD_BACKUP_TITLE")), "gold %d from the .bak, a NOTIF_LOAD_BACKUP toast" % eco.gold)


# ================================================================ New Game after Continue is clean

func _test_new_game_after_continue() -> void:
	# we are in a world that Continue just entered
	t.check("new_game_after_continue_start", sm.current_slot == 4 and t.scene_path() == WORLD_SCENE, "slot %d, scene %s" % [sm.current_slot, t.scene_name()])
	await t.go_menu()                                  # the real route: quit to the title, then New Game
	t.check("new_game_after_continue_keeps_slot_until_new_game", sm.current_slot == 4, "going to the menu does not reset the slot")
	var counted := _fake("counted", 30)
	counted.wire_new_game(bus)
	counted.data = {"v": 1, "n": 99}
	sm.pending_world = {"leftover": true}
	sm._auto_save_timer = 120.0
	var slot_files := _listing(_scratch)
	gm.start_new_game("Neu", gm.CharacterType.HOBBIT, "Nygaard")
	t.check("new_game_after_continue_clean", sm.current_slot == -1 and sm.pending_world.is_empty() and is_zero_approx(sm._auto_save_timer) and sm.last_error.is_empty(), "current_slot %d, pending %s, timer %s" % [sm.current_slot, sm.pending_world, sm._auto_save_timer])
	t.check("new_game_resets_sections_once", counted.reset_calls == 1 and counted.data.get("n") == 0, "a section that follows the reset contract is reset by new_game_started exactly once (SaveManager does not reset it a second time): %d" % counted.reset_calls)
	t.check("new_game_state_is_new", gm.day == 1 and gm.player_name == "Neu" and gm.character_type == gm.CharacterType.HOBBIT and gm.farm_name == "Nygaard" and _listing(_scratch) == slot_files, "day 1, the new character, no save file touched")
	# the real systems that already follow the contract come back clean as well
	var clean_notes: Array[String] = []
	if eco.has_method("reset"):
		t.check("new_game_after_continue_gold_reset", eco.gold != 888 and eco.gold != 30, "gold %d" % eco.gold)
	else:
		clean_notes.append("EconomyManager")
	if qm.has_method("reset"):
		t.check("new_game_after_continue_quests_reset", _names(qm.to_dict().get("completed")).is_empty() and (qm.to_dict().get("active", {}) as Dictionary).is_empty(), "")
	else:
		clean_notes.append("QuestManager")
	if ah.has_method("reset"):
		t.check("new_game_after_continue_husbandry_reset", (ah.to_dict().get("animals", {}) as Dictionary).is_empty() and (ah.to_dict().get("buildings", {}) as Dictionary).is_empty(), "")
	else:
		clean_notes.append("AnimalHusbandry")
	if not clean_notes.is_empty():
		t.skip("new_game_after_continue: %s have no reset() yet (P12 / P13 / P20, asserted by core.new_game_wires_*)" % ", ".join(clean_notes))
	# an autosave after the new game goes to the auto slot only, and never into the slot Continue came from
	var manual_bytes := _read_text(sm.slot_path(4))
	gm.change_phase(PH.PLAYING)
	t.check("autosave_after_new_game_is_auto_only", sm.autosave() and _read_text(sm.slot_path(4)) == manual_bytes and sm.current_slot == -1, "slot 4 untouched, current_slot still -1")
	await t.go_menu()
	_clear_fakes()

func _test_backup_cache() -> void:
	_wipe()
	_set_state(800, 2)
	sm.save_game(1)
	sm.save_game(1)
	var payload: Dictionary = JSON.parse_string(_read_text(sm.slot_path(1)))
	payload.meta.saved_at=float(payload.meta.saved_at)+1.25
	payload.meta.timestamp="2026-10-16T12:34:56"
	_write_json(sm.slot_path(1),payload)
	var saved: bool = sm.save_game(1)
	t.check("backup_cache_accepts_clock_only_change",saved and _gold_in(sm.backup_path(1))==800)
	var good_backup := _read_text(sm.backup_path(1))
	payload.meta.version=99
	_write_json(sm.slot_path(1),payload)
	sm.save_game(1)
	t.check("backup_cache_rechecks_changed_version",_read_text(sm.backup_path(1))==good_backup)
	payload.meta.version=2
	payload.economy.gold="invalid gold"
	_write_json(sm.slot_path(1),payload)
	sm.save_game(1)
	t.check("backup_cache_rechecks_changed_state",_read_text(sm.backup_path(1))==good_backup)
