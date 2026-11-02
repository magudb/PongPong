extends Node
## Central game state: player profile, calendar and clock, world flags, game phases + modal stack, run lifecycle.
##
## PHASES AND MODALS (PLAN 3.6, decision D7). `current_phase` is DERIVED:
##   PAUSED   when any open modal pauses the tree (get_tree().paused is true exactly then),
##   CUTSCENE when only non-pausing modals are open (dialogue),
##   else the BASE phase that change_phase() set at the last scene boundary (MENU, CHARACTER_SELECT, PLAYING).
## Every panel pushes its key on open and pops it on close (push_modal / pop_modal, exactly once each); the order of the
## pops does not matter, the phase is recomputed from the stack every time. change_phase(PAUSED | CUTSCENE) still works
## for legacy panels (it sets the base phase); new code uses modals only. change_phase(MENU | CHARACTER_SELECT) is a scene
## boundary and drops the whole stack. The mouse is never captured in the 2D game: nothing in this file touches
## Input.mouse_mode (core.no_mouse_capture lints scripts/autoload for it).
##
## CLOCK AND CALENDAR. One calendar, one source of truth: days per season, the season list and the clock hours come from
## lua/config time.* (LuaRuntime.get_config) with the literals below as defaults (days_per_season(), seasons(),
## day_start_hour(), day_end_hour(), minutes_per_real_second()). THE GAME DAY RUNS 06:00 TO 02:00 AT NIGHT (user answer 2026-10-14; the contract is
## docs/design/CLOCK_26_ADDENDUM.md). The clock is READ with a RAW hour:
##   `hour` is the raw game hour 6..25: the hours 24 and 25 belong to the SAME game day (same `day`, weekday, weather, shop opening day, festival
##     day) and are DISPLAYED 00:xx and 01:xx (TTFormat.clock / clock_hour_of_day(): hour % 24). The player passes out at game hour 26 = 02:00
##     (day_end_hour()). Hours of Lua tables are floats on the same axis (25.5 = 01:30); game_hour() maps an authored 1.5 onto it.
##   advance_time(minutes) is exact arithmetic. Crossing day_end_hour (26:00) rolls the day: the calendar steps and the clock restarts at
##     day_end_hour - 24 = 02:00 of the NEW date (00:00 when day_end_hour <= 24, the old behaviour), so the clock never jumps backwards (01:59
##     -> 02:00) and every calendar day is exactly 24 clock hours: 06:00 + 25 h is 07:00 of the next day and a 50 h skip crosses two rolls
##     (day_ended .. day_started per roll). time_of_day_changed carries the raw hour: 2..25 (6..25 in play, 2..5 only between the roll and the wake-up).
##   end_day() ends the current day NOW and starts the next morning at day_start_hour (bed, harness t.days()).
##   sleep_until_morning() is the helper for WorldRoot2D: the bed (any raw hour >= day_start_hour, so also 24:xx and 25:xx) and the pass-out
##     (the clock already crossed the roll, so the new day has begun and the raw hour is 2..5) both wake the player at day_start_hour; it
##     never skips a day twice.
##   WorldRoot2D detects the pass-out through EventBus.game_event(&"midnight_passed", {day, season}), emitted once per roll that
##     advance_time() crosses (after day_started; never by end_day or the bed). The id is kept from the 24:00 days: it means "the day-end
##     roll" (02:00); real midnight (raw 24:00) emits nothing. The clock hour is never 26.
## Weather for a new day is rolled by TimeManager BEFORE day_started is emitted (end_day and the midnight roll call it).
##
## NEW GAME (D15, reset contract 3.6): start_new_game() resets this node, then emits player_character_changed (skin final)
## and new_game_started LAST, so EconomyManager, QuestManager, TimeManager, ShopSystem, AnimalHusbandry, SaveManager and
## FarmGrid reset themselves from that one signal. It does NOT emit day_started (a new run has no "previous day").

enum CharacterType { ANIMAL, FAIRY, HOBBIT, GHOST }
enum GamePhase { MENU, CHARACTER_SELECT, PLAYING, PAUSED, CUTSCENE }

const SAVE_VERSION := 1

## Defaults of lua/config time.* (the live values are read through config_value()).
const DEFAULT_DAYS_PER_SEASON := 28
const DEFAULT_SEASONS: Array[StringName] = [&"foraar", &"sommer", &"efteraar", &"vinter"]
const DEFAULT_DAY_START_HOUR := 6
const DEFAULT_DAY_END_HOUR := 26
const DEFAULT_MINUTES_PER_REAL_SECOND := 2.0

## World flags with a contract (JSON-safe scalars, read with flag_int()).
## intro_pending: set by start_new_game, read by WorldRoot2D / IntroSequence, cleared by the intro.
## home_tier (default 1), home_building (0) and home_upgrade_done (0): HomeManager owns the values.
const FLAG_INTRO_PENDING := &"intro_pending"
const FLAG_HOME_TIER := &"home_tier"
const FLAG_HOME_BUILDING := &"home_building"
const FLAG_HOME_UPGRADE_DONE := &"home_upgrade_done"

## Phase of the running scene flow; always derived (see the header), assigned only by _refresh_phase().
var current_phase: GamePhase = GamePhase.MENU
var player_name: String = ""
var character_type: CharacterType = CharacterType.ANIMAL
var character_skin: StringName = &"default"
var farm_name: String = ""

var day: int = 1
var season: StringName = &"foraar"  # foraar, sommer, efteraar, vinter
var year: int = 1
var hour: int = 6
var minute: int = 0

## JSON-safe values only: bool, int, float, String (set_flag enforces it).
var world_flags: Dictionary = {}
var unlocked_zones: Array[StringName] = [&"farm", &"city"]
var discovered_locations: Array[StringName] = []

var play_time_seconds: float = 0.0
var is_single_player: bool = true

var _base_phase: GamePhase = GamePhase.MENU
var _modals: Array[Dictionary] = []          # [{name: StringName, pauses: bool}] in push order
var _config_overrides: Dictionary = {}       # path -> value; tests and the debug console only, never saved
var _quitting := false
var _quit_asking := false                    # compatibility observation, owned by _quit_request
var _quit_request: Dictionary = {}           # exact consequential root, never lifecycle admission
## Test seam (no behaviour of its own): when valid, quit_game calls it with the exit code instead of ending the process, after
## everything quit_game decides (the save, the question); the game keeps running.
var quit_seam: Callable = Callable()

# Transient, main-thread admission. Tokens never enter model/save data or public results.
var _lifecycle_token: RefCounted
var _lifecycle_owner: Object
var _lifecycle_kind: StringName
var _lifecycle_stage: StringName
var _lifecycle_handoff: Dictionary = {}


func lifecycle_busy() -> bool:
	return _lifecycle_token != null


func _begin_lifecycle(owner: Object, kind: StringName) -> RefCounted:
	if lifecycle_busy() or owner == null: return null
	_lifecycle_token = RefCounted.new()
	_lifecycle_owner = owner
	_lifecycle_kind = kind
	_lifecycle_stage = &"admitted"
	return _lifecycle_token


func _owns_lifecycle(token: Variant, owner: Object, stage: StringName) -> bool:
	return token != null and token is RefCounted and token == _lifecycle_token and owner == _lifecycle_owner and stage == _lifecycle_stage


func _stage_lifecycle(token: Variant, owner: Object, before: StringName, after: StringName) -> bool:
	if not _owns_lifecycle(token, owner, before): return false
	_lifecycle_stage = after
	return true


func _finish_lifecycle(token: Variant, owner: Object) -> void:
	if token == null or not token is RefCounted or token != _lifecycle_token or owner != _lifecycle_owner: return
	if not _lifecycle_handoff.is_empty():
		_lifecycle_handoff["tail"] = true
		_settle_lifecycle_scene(token, owner)
		return
	_release_lifecycle(token, owner)


func _release_lifecycle(token: RefCounted, owner: Object) -> void:
	if token != _lifecycle_token or owner != _lifecycle_owner: return
	if not _lifecycle_handoff.is_empty():
		var callback: Callable = _lifecycle_handoff["callback"]
		if callback.is_valid() and get_tree().scene_changed.is_connected(callback): get_tree().scene_changed.disconnect(callback)
	_lifecycle_handoff = {}
	_lifecycle_token = null
	_lifecycle_owner = null
	_lifecycle_kind = &""
	_lifecycle_stage = &""


# Godot 4.7.2 change_scene_to_node retains this exact instance, installs it
# before add_child/_ready, then emits scene_changed. Bind before scheduling;
# readiness can complete synchronously before that engine acknowledgement.
func _request_lifecycle_world_node(token: RefCounted, owner: Object, world: Node, parent: Node = null, make_current := false) -> Error:
	if not _owns_lifecycle(token, owner, &"scene_request") or not _lifecycle_handoff.is_empty(): return ERR_BUSY
	if not world.has_method("_bind_lifecycle_bootstrap"): return ERR_INVALID_DATA
	var ref: WeakRef = weakref(world)
	var callback := _lifecycle_scene_changed.bind(token, owner, ref) if parent == null else Callable()
	if not world.call("_bind_lifecycle_bootstrap", _lifecycle_world_done.bind(token, owner, ref), _lifecycle_world_exited.bind(token, owner, ref)): return ERR_INVALID_DATA
	_lifecycle_handoff = {"world":ref,"callback":callback,"tail":false,"done":false,"ack":false,"exited":false}
	if parent != null:
		parent.add_child(world)
		if make_current: get_tree().current_scene = world
		_lifecycle_handoff["ack"] = true
		return OK
	get_tree().scene_changed.connect(callback)
	var err := get_tree().change_scene_to_node(world)
	if err != OK:
		get_tree().scene_changed.disconnect(callback)
		_lifecycle_handoff = {}
	return err


func _request_lifecycle_world(token: RefCounted, owner: Object, path: String) -> Error:
	if not _owns_lifecycle(token, owner, &"scene_request"): return ERR_BUSY
	var packed := load(path) as PackedScene
	if packed == null: return ERR_CANT_OPEN
	var world := packed.instantiate()
	var err := _request_lifecycle_world_node(token, owner, world)
	if err != OK: world.free()
	return err


func _matching_lifecycle_world(token: RefCounted, owner: Object, ref: WeakRef) -> bool:
	return _owns_lifecycle(token, owner, &"scene_request") and not _lifecycle_handoff.is_empty() and _lifecycle_handoff["world"] == ref


func _lifecycle_scene_changed(token: RefCounted, owner: Object, ref: WeakRef) -> void:
	if not _matching_lifecycle_world(token,owner,ref) or get_tree().current_scene != ref.get_ref(): return
	_lifecycle_handoff["ack"] = true
	# Hold through every synchronous scene_changed/ready listener, not just ours.
	_settle_lifecycle_scene.call_deferred(token,owner)


func _lifecycle_world_done(success: bool, token: RefCounted, owner: Object, ref: WeakRef) -> void:
	if not _matching_lifecycle_world(token,owner,ref): return
	var world: Variant = ref.get_ref()
	if not is_instance_valid(world): return
	if success and (not world.ready_for_play or not world.is_inside_tree()): return
	if not success and not _lifecycle_handoff["exited"]: return
	_lifecycle_handoff["done"] = true
	if not success: _lifecycle_handoff["ack"] = true
	_settle_lifecycle_scene.call_deferred(token,owner)


func _lifecycle_world_exited(token: RefCounted, owner: Object, ref: WeakRef) -> void:
	if not _matching_lifecycle_world(token,owner,ref): return
	_lifecycle_handoff["exited"] = true
	_settle_lifecycle_scene.call_deferred(token,owner)


func _settle_lifecycle_scene(token: RefCounted, owner: Object) -> void:
	if token != _lifecycle_token or owner != _lifecycle_owner or _lifecycle_handoff.is_empty(): return
	# A retained exited coroutine must acknowledge its cancellation at its tail.
	# A freed script cannot resume; defer until its destruction actually finished.
	if _lifecycle_handoff["exited"] and _lifecycle_handoff["world"].get_ref() == null:
		_lifecycle_handoff["done"] = true
		_lifecycle_handoff["ack"] = true
	if _lifecycle_handoff["tail"] and _lifecycle_handoff["done"] and _lifecycle_handoff["ack"]:
		_release_lifecycle(token,owner)


func _lifecycle_result(ok: bool, code := "", detail := "") -> Dictionary:
	return {"ok": ok, "code": code, "detail": detail}


func _lifecycle_busy_result() -> Dictionary:
	return _lifecycle_result(false, "busy", "Another run operation is still finishing.")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.zone_entered.connect(_on_zone_entered)
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(quit_game)

## Noncreating consequential origin, independent of a write's immutable committed
## bool. Empty bootstrap/menu models are valid; equal-valued replacement is not.
## This is lexical bookkeeping, never an acting-player or lifecycle permit.
func capture_consequential_origin() -> Dictionary:
	var rows := {}
	for pid in PlayerRegistry._states:
		rows[pid] = weakref(PlayerRegistry._states[pid])
	var social := get_node_or_null("/root/SocialManager")
	var world := get_tree().get_first_node_in_group("world_2d")
	var scene := get_tree().current_scene
	return {"rows":rows, "run":social._accounting_world if social != null else null,
		"world":weakref(world) if world != null else null, "scene":weakref(scene) if scene != null else null}


func consequential_origin_current(origin: Dictionary) -> bool:
	return not lifecycle_busy() and _consequential_model_current(origin)


## A title departure must retain its original model through its own admitted
## modal/phase teardown. This exact token does not authorize any other caller.
func _consequential_origin_current_owned(origin: Dictionary, token: RefCounted, owner: Object) -> bool:
	return _lifecycle_kind == &"return_title" and _owns_lifecycle(token, owner, &"admitted") and _consequential_model_current(origin)


func _consequential_model_current(origin: Dictionary) -> bool:
	if origin.is_empty(): return false
	var social := get_node_or_null("/root/SocialManager")
	if social != null and (social._accounting_suspended or social._accounting_world != origin.run): return false
	if PlayerRegistry._states.size() != origin.rows.size(): return false
	for pid in origin.rows:
		var row: Variant = origin.rows[pid].get_ref()
		if row == null or PlayerRegistry._states.get(pid) != row: return false
	var world := get_tree().get_first_node_in_group("world_2d")
	if origin.world == null:
		if world != null: return false
	elif not is_instance_valid(origin.world.get_ref()) or world != origin.world.get_ref() or not world.is_inside_tree() or world.is_queued_for_deletion(): return false
	var scene := get_tree().current_scene
	return (scene == null if origin.scene == null else is_instance_valid(origin.scene.get_ref()) and scene == origin.scene.get_ref() and not scene.is_queued_for_deletion())


func _quit_current(request: Dictionary) -> bool:
	return not _quit_request.is_empty() and _quit_request.id == request.id and consequential_origin_current(request.origin)


func _begin_quit() -> Dictionary:
	if lifecycle_busy(): return {}
	if not _quit_request.is_empty():
		if _quit_current(_quit_request): return {}
		_finish_quit(_quit_request)
		# Cleanup can synchronously start a different, legitimate quit.
		if not _quit_request.is_empty() or lifecycle_busy(): return {}
	var request := {"id":RefCounted.new(), "origin":capture_consequential_origin(), "stage":&"admitted"}
	if not consequential_origin_current(request.origin): return {}
	_quit_request = request
	return request


func _finish_quit(request: Dictionary) -> void:
	# A stale stack may acquire its last UI node during add_child/_ready after a
	# successor has already retired it. Always release exact local resources;
	# only the matching request may touch the global flags.
	if not _quit_request.is_empty() and _quit_request.id == request.id:
		_quit_request = {}
		_quit_asking = false
		_quitting = false
	var audio: Variant = request.get("audio")
	var dialog: Variant = request.get("dialog")
	var host: Variant = request.get("host")
	request.erase("audio")
	request.erase("dialog")
	request.erase("host")
	if audio != null and is_instance_valid(audio.get_ref()): audio.get_ref().cancel_shutdown(request.id)
	if dialog != null and is_instance_valid(dialog.get_ref()):
		if dialog.get_ref().is_open(): dialog.get_ref()._finish(false)
		if is_instance_valid(dialog.get_ref()): dialog.get_ref().queue_free()
	if host != null and is_instance_valid(host.get_ref()): host.get_ref().queue_free()
	pop_modal_owned(&"quit_shutdown", request.id)


## All entrypoints share one request from before save through every await. The
## updater forwards its ORIGINAL origin instead of minting authority after handoff.
func quit_game(code := 0, save := true, asker: Control = null, origin: Dictionary = {}) -> void:
	await try_quit_game(code, save, asker, origin)

## Additive checked handoff: true only after dispatching this request's terminal
## effect. Legacy quit_game stays void; disk durability remains SaveManager's bool.
func try_quit_game(code := 0, save := true, asker: Control = null, origin: Dictionary = {}) -> bool:
	if not origin.is_empty() and not consequential_origin_current(origin): return false
	var request := _begin_quit()
	if request.is_empty(): return false
	if not origin.is_empty(): request.origin = origin
	if save and not await _save_before_quit(request, asker):
		_finish_quit(request)
		return false
	if not _quit_current(request):
		_finish_quit(request)
		return false
	if quit_seam.is_valid():
		var terminal := quit_seam
		_finish_quit(request)
		if not _quit_request.is_empty() or not consequential_origin_current(request.origin): return false
		terminal.call(code)
		return true
	request.stage = &"shutdown"
	_quitting = true
	push_modal_owned(&"quit_shutdown", true, request.id)
	if not _quit_current(request):
		_finish_quit(request)
		return false
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("prepare_shutdown"):
		request.audio = weakref(audio)
		await audio.prepare_shutdown(request.id, func(): return _quit_current(request))
	if not _quit_current(request):
		_finish_quit(request)
		return false
	get_tree().quit(code)
	return true


## Standalone policy facade keeps its own exact root too, without a token over UI.
func save_before_quit(asker: Control = null) -> bool:
	var request := _begin_quit()
	if request.is_empty(): return false
	var accepted := await _save_before_quit(request, asker)
	var current := _quit_current(request)
	_finish_quit(request)
	return accepted and current and consequential_origin_current(request.origin)


func _save_before_quit(request: Dictionary, asker: Control) -> bool:
	if not _quit_current(request) or request.stage != &"admitted": return false
	request.stage = &"saving" # consume before serializers/status/confirmation callbacks
	if get_tree().get_first_node_in_group("world_2d") == null or is_modal_open(&"event"): return true
	var saves := get_node_or_null("/root/SaveManager")
	var committed := saves == null or not saves.has_method("autosave") or bool(saves.call("autosave"))
	if not _quit_current(request): return false
	if committed: return true
	_quit_asking = true
	if not is_instance_valid(asker) or not asker.is_inside_tree() or not asker.is_visible_in_tree():
		var host := Control.new()
		host.name = "QuitQuestion"
		host.process_mode = Node.PROCESS_MODE_ALWAYS
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		request.host = weakref(host)
		var layer := get_tree().get_first_node_in_group("game_ui")
		(layer if layer != null else get_tree().root).add_child(host)
		if not _quit_current(request): return false
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		asker = host
	var confirm: Script = load("res://scripts/ui/components/ui_confirm.gd")
	var dialog: Variant = confirm.call("_make", asker)
	if dialog == null: return false
	request.dialog = weakref(dialog)
	if not _quit_current(request): return false
	dialog.setup("NOTIF_SAVE_FAILED_TITLE", "PAUSE_SAVE_FAILED_CONFIRM", "NAV_OK")
	var answers := []
	dialog.answered.connect(func(result): answers.append(bool(result)), CONNECT_ONE_SHOT)
	dialog.begin()
	if not _quit_current(request): return false
	if answers.is_empty(): await dialog.answered
	return _quit_current(request) and not answers.is_empty() and answers[0]


func _process(delta: float) -> void:
	if current_phase == GamePhase.PLAYING:
		play_time_seconds += delta


# ------------------------------------------------------------------ configuration (single source of truth)

## Memo of config_value lookups that hit LuaRuntime: the dotted path is split and walked on every call, and
## hot paths (TimeManager.tick, DayNight.target_color, the player's interact query) ask for the same handful
## of keys every frame. Overrides and Lua reloads clear the cache; a miss is never cached negatively, so a
## key that appears later still resolves.
var _config_cache: Dictionary = {}

## lua/config value by dotted path ("time.days_per_season"); `default_value` when LuaRuntime or the key is missing.
## LuaRuntime is looked up lazily: it is autoload #7 and does not exist yet while this node's _ready() runs.
func config_value(path: String, default_value: Variant = null) -> Variant:
	if _config_overrides.has(path):
		return _config_overrides[path]
	if _config_cache.has(path):
		return _config_cache[path]
	var lua := get_node_or_null("/root/LuaRuntime")
	if lua != null and lua.has_method("get_config"):
		var v: Variant = lua.get_config(path, null)
		if v != null:
			_config_cache[path] = v
			return v
	return default_value


## Test / debug seam: makes config_value(path) return `value` until clear_config_overrides().
func set_config_override(path: String, value: Variant) -> void:
	_config_overrides[path] = value
	_config_cache.erase(path)


func clear_config_overrides() -> void:
	_config_overrides.clear()
	_config_cache.clear()


## Drops memoised Lua config (LuaRuntime.reload_scripts calls it after the tables are rebuilt).
func invalidate_config_cache() -> void:
	_config_cache.clear()


func days_per_season() -> int:
	return maxi(int(config_value("time.days_per_season", DEFAULT_DAYS_PER_SEASON)), 1)


func seasons() -> Array[StringName]:
	var out: Array[StringName] = []
	var configured: Variant = config_value("time.seasons", null)
	if configured is Array:
		for entry in configured:
			if str(entry) != "":
				out.append(StringName(str(entry)))
	if out.is_empty():
		out.assign(DEFAULT_SEASONS)
	return out


func day_start_hour() -> int:
	var start := clampi(int(config_value("time.day_start_hour", DEFAULT_DAY_START_HOUR)), 0, 23)
	return start


## The raw game hour at which the day rolls and the player passes out (26 = 02:00 by default; 24 = midnight, the old value).
## Valid: day_start_hour < value < 24 + day_start_hour (the restart hour after the roll must stay BEFORE the wake-up hour, or
## sleep_until_morning() could not tell the pass-out from the bed). Anything else falls back to the default 26 or, when 26 itself breaks the
## range for a modded day start of 0..2 (26 >= 24 + start), to the largest valid value 23 + day_start_hour (24 at start 1, 25 at start 2).
## (A day start of 0 has no hour below it: there the pass-out can not be told from the bed in ANY version, the 24 hour one included.)
func day_end_hour() -> int:
	var fallback := mini(DEFAULT_DAY_END_HOUR, 23 + day_start_hour())
	var end_hour := int(config_value("time.day_end_hour", DEFAULT_DAY_END_HOUR))
	if end_hour <= day_start_hour() or end_hour >= 24 + day_start_hour():
		return fallback
	return end_hour


## The raw clock hour the new calendar day starts with right after the roll: day_end_hour() - 24 (02:00 at 26), never negative.
func day_roll_restart_hour() -> int:
	return maxi(day_end_hour() - 24, 0)


## The hour as the player reads it: the raw hours 24 and 25 (the same game day) read 0 and 1. Default: the current hour.
func clock_hour_of_day(raw_hour: int = -1) -> int:
	return posmod(hour if raw_hour < 0 else raw_hour, 24)


## An hour as AUTHORED (a Lua value, a window end, a person typing 1.5 for 01:30) mapped onto the raw game-hour axis: everything below the
## day start is after midnight of the SAME game day and gets +24 (1.5 -> 25.5, 0.0 -> 24.0); 6.0 and up stay. The ONE normaliser of the
## opening-hours rule, the routine compiler and the when= hour selectors: nothing re-implements the wrap.
func game_hour(clock_hour: float) -> float:
	return clock_hour + 24.0 if clock_hour < float(day_start_hour()) else clock_hour


func minutes_per_real_second() -> float:
	return maxf(float(config_value("time.minutes_per_real_second", DEFAULT_MINUTES_PER_REAL_SECOND)), 0.01)


# ------------------------------------------------------------------ run lifecycle

## Starts a fresh run: resets this node's state, then announces it. `p_skin` empty selects the default skin of the race.
func start_new_game(p_name: String, p_type: CharacterType, p_farm: String = "", p_skin: StringName = &"") -> void:
	try_start_new_game(p_name, p_type, p_farm, p_skin)


func try_start_new_game(p_name: String, p_type: CharacterType, p_farm: String = "", p_skin: StringName = &"") -> Dictionary:
	var token := _begin_lifecycle(self, &"new_game")
	if token == null: return _lifecycle_busy_result()
	_stage_lifecycle(token, self, &"admitted", &"new_game_ready")
	_start_new_game_owned(token, p_name, p_type, p_farm, p_skin)
	_finish_lifecycle(token, self)
	return _lifecycle_result(true)


func _start_new_game_owned(token: RefCounted, p_name: String, p_type: CharacterType, p_farm: String, p_skin: StringName, on_admitted: Callable = Callable()) -> void:
	# Consume the issuer's one entry before ANY callback, including admission.
	# An observer can see the exact token but cannot borrow this whole body.
	if not _stage_lifecycle(token, self, &"new_game_ready", &"new_game"): return
	if on_admitted.is_valid(): on_admitted.call()
	var social := get_node_or_null("/root/SocialManager")
	if social != null: social.invalidate_accounting()
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue != null: dialogue.begin_reset()
	player_name = p_name.strip_edges() if p_name.strip_edges() != "" else tr("DEFAULT_PLAYER_NAME")
	character_type = p_type
	character_skin = p_skin if p_skin != &"" else _default_skin_for(p_type)
	farm_name = p_farm.strip_edges() if p_farm.strip_edges() != "" else tr("DEFAULT_FARM_NAME")
	var first_season := seasons()[0]
	day = 1
	season = first_season
	year = 1
	hour = day_start_hour()
	minute = 0
	PlayerRegistry.reset_states()
	var dropped: Array = world_flags.keys()
	world_flags.clear()
	# Current runs owe Lyra's authored welcome even if a service portrait
	# completes the lottery before the first physical meeting. Loaded legacy
	# saves do not pass here, so genuinely completed old records stay final.
	set_flag(&"mayor_welcome_pending", true)
	set_flag(FLAG_INTRO_PENDING, true)
	for key in dropped:
		if key not in [FLAG_INTRO_PENDING, &"mayor_welcome_pending"]:
			EventBus.flag_changed.emit(StringName(str(key)), false)   # the new run resets a flag
	unlocked_zones.assign(_default_zones())
	discovered_locations.clear()
	play_time_seconds = 0.0
	_base_phase = GamePhase.PLAYING
	_drop_modals()
	# the skin is final here; the reset wave of every other system comes last
	EventBus.player_character_changed.emit(PlayerRegistry.local_id(), character_skin)
	# SaveManager was the first reset listener. Preserve its visibility/order,
	# but explicitly authorize exactly one metadata reset before the reset wave.
	var saves := get_node_or_null("/root/SaveManager")
	if saves != null: saves._reset_metadata_owned(token, self)
	EventBus.new_game_started.emit()
	if is_instance_valid(dialogue): dialogue.end_reset()
	_stage_lifecycle(token, self, &"new_game", &"new_game_done")


func try_start_new_game_and_enter(p_name: String, p_type: CharacterType, p_farm: String = "", p_skin: StringName = &"", play_intro := true, on_admitted: Callable = Callable()) -> Dictionary:
	var token := _begin_lifecycle(self, &"new_game_enter")
	if token == null: return _lifecycle_busy_result()
	var path := "res://scenes/main/world.tscn"
	if not ResourceLoader.exists(path):
		_finish_lifecycle(token,self)
		return _lifecycle_result(false,"scene","World scene is unavailable.")
	_stage_lifecycle(token,self,&"admitted",&"new_game_ready")
	_start_new_game_owned(token,p_name,p_type,p_farm,p_skin,on_admitted)
	if not play_intro: set_flag(FLAG_INTRO_PENDING,false)
	_stage_lifecycle(token,self,&"new_game_done",&"scene_request")
	var err := _request_lifecycle_world(token,self,path)
	var result := _lifecycle_result(err == OK,"" if err == OK else "scene","" if err == OK else "Could not enter the world.")
	_finish_lifecycle(token,self)
	return result


func _default_zones() -> Array[StringName]:
	return [&"farm", &"city"]


# Explicit release/art/test adapter: attach a fresh world without deleting its
# driver scene. All setup is synchronous; the same finite bootstrap owns release.
func try_start_new_game_attached(parent: Node, p_name: String, p_type: CharacterType, p_farm: String = "", p_skin: StringName = &"", play_intro := true, after_reset: Callable = Callable(), make_current := false) -> Dictionary:
	var token := _begin_lifecycle(self,&"new_game_attached")
	if token == null: return _lifecycle_busy_result()
	if not is_instance_valid(parent) or not parent.is_inside_tree() or (make_current and parent != get_tree().root):
		_finish_lifecycle(token,self)
		return _lifecycle_result(false,"scene","World parent is unavailable.")
	var packed := load("res://scenes/main/world.tscn") as PackedScene
	if packed == null:
		_finish_lifecycle(token,self)
		return _lifecycle_result(false,"scene","World scene is unavailable.")
	_stage_lifecycle(token,self,&"admitted",&"new_game_ready")
	_start_new_game_owned(token,p_name,p_type,p_farm,p_skin)
	if not play_intro: set_flag(FLAG_INTRO_PENDING,false)
	if after_reset.is_valid(): after_reset.call()
	_stage_lifecycle(token,self,&"new_game_done",&"scene_request")
	var world := packed.instantiate()
	var err := _request_lifecycle_world_node(token,self,world,parent,make_current)
	var result := _lifecycle_result(err == OK,"" if err == OK else "scene","" if err == OK else "Could not attach the world.")
	if err == OK: result["world"] = world
	else: world.free()
	_finish_lifecycle(token,self)
	return result


func _default_skin_for(type: CharacterType) -> StringName:
	match type:
		CharacterType.ANIMAL:
			return &"animal_fox"
		CharacterType.FAIRY:
			return &"fairy_meadow"
		CharacterType.HOBBIT:
			return &"hobbit_pip"
		CharacterType.GHOST:
			return &"ghost_bu"
	return &"default"


# ------------------------------------------------------------------ phases and the modal stack

## Scene boundaries only: the menu, the character select and the world start. Panels use push_modal() instead.
func change_phase(phase: GamePhase) -> void:
	_base_phase = phase
	if phase == GamePhase.MENU or phase == GamePhase.CHARACTER_SELECT:
		_drop_modals()
	else:
		_refresh_phase()


## Opens a modal. A name that is already open only updates its pause behaviour (a panel pushes exactly once).
func push_modal(modal_name: StringName, pauses_tree: bool = true) -> void:
	push_modal_owned(modal_name, pauses_tree, RefCounted.new())

## The caller retains its receipt before callback-producing phase publication.
func push_modal_owned(modal_name: StringName, pauses_tree: bool, receipt: RefCounted) -> void:
	if modal_name == &"":
		push_error("GameManager.push_modal: a modal needs a name")
		return
	var idx := _modal_index(modal_name)
	if idx >= 0:
		_modals[idx]["receipt"] = receipt
		if bool(_modals[idx]["pauses"]) == pauses_tree:
			return
		_modals[idx]["pauses"] = pauses_tree
	else:
		_modals.append({"name": modal_name, "pauses": pauses_tree, "receipt": receipt})
	_apply_modal_state()


func pop_modal_owned(modal_name: StringName, receipt: RefCounted) -> void:
	var idx := _modal_index(modal_name)
	if idx < 0 or receipt == null or _modals[idx].get("receipt") != receipt: return
	_modals.remove_at(idx)
	_apply_modal_state()


## Closes a modal wherever it sits in the stack (pop order may differ from push order). Unknown names are ignored.
func pop_modal(modal_name: StringName) -> void:
	var idx := _modal_index(modal_name)
	if idx < 0:
		return
	_modals.remove_at(idx)
	_apply_modal_state()


## Pops every modal (quit to menu, load game).
func pop_all_modals() -> void:
	_drop_modals()


## Is the named modal open? With no name: is any modal open?
func is_modal_open(modal_name: StringName = &"") -> bool:
	if modal_name == &"":
		return not _modals.is_empty()
	return _modal_index(modal_name) >= 0


## Open modals, bottom first (the payload of EventBus.modal_changed).
func modal_stack() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in _modals:
		out.append(entry["name"])
	return out


func top_modal() -> StringName:
	return _modals[-1]["name"] if not _modals.is_empty() else &""


func _modal_index(modal_name: StringName) -> int:
	for i in _modals.size():
		if _modals[i]["name"] == modal_name:
			return i
	return -1


func _apply_modal_state() -> void:
	_refresh_phase()
	EventBus.modal_changed.emit(modal_stack())


## Empties the stack (scene boundaries, new game, quit to menu); modal_changed fires only when something was open.
func _drop_modals() -> void:
	var had_modals := not _modals.is_empty()
	_modals.clear()
	_refresh_phase()
	if had_modals:
		EventBus.modal_changed.emit(modal_stack())


func _refresh_phase() -> void:
	var any_pausing := false
	for entry in _modals:
		if bool(entry["pauses"]):
			any_pausing = true
			break
	if any_pausing:
		current_phase = GamePhase.PAUSED
	elif not _modals.is_empty():
		current_phase = GamePhase.CUTSCENE
	else:
		current_phase = _base_phase
	var tree := get_tree()
	if tree != null:
		tree.paused = current_phase == GamePhase.PAUSED


# ------------------------------------------------------------------ world flags

## Sentinel for set_flag's "did the value change" compare: stored values are never null, so an absent key compares different.
const _UNSET: Variant = null

## JSON-safe flag store: bool, int, float and String (a StringName is stored as String); null clears the flag.
## Anything else (Array, Dictionary, Vector2, Object ...) is refused with an error: it would not survive a save.
func _flag_store(flag: StringName) -> Dictionary:
	return PlayerRegistry.state().flags if str(flag).begins_with("friend_") else world_flags


func set_flag(flag: StringName, value: Variant) -> void:
	var store := _flag_store(flag)
	if value == null:
		if store.erase(flag):
			EventBus.flag_changed.emit(flag, false)
		return
	var safe: Variant = _json_safe(value)
	if safe == null:
		push_error("GameManager.set_flag(%s): %s is not JSON-safe (use bool, int, float or String)" % [flag, type_string(typeof(value))])
		return
	var prev: Variant = store.get(flag, _UNSET)
	if prev != null and typeof(prev) == typeof(safe) and prev == safe:
		return                                          # writing the same value changes nothing
	store[flag] = safe
	EventBus.flag_changed.emit(flag, safe)


## Commit related progression flags before notifying synchronous observers.
## Invalid input is refused atomically; the single-flag API retains its errors.
func set_flags(changes: Dictionary) -> bool:
	var next := {}
	for key in changes:
		if not (key is String or key is StringName) or str(key) == "": return false
		var value: Variant = changes[key]
		var safe: Variant = _json_safe(value) if value != null else null
		if value != null and safe == null: return false
		next[StringName(str(key))] = safe
	var published: Array = []
	for key in next:
		var value: Variant = next[key]
		if value == null:
			if _flag_store(key).erase(key): published.append([key,false])
		else:
			var previous: Variant = _flag_store(key).get(key,_UNSET)
			if typeof(previous) != typeof(value) or previous != value:
				_flag_store(key)[key] = value
				published.append([key,value])
	for pair in published: EventBus.flag_changed.emit(pair[0],pair[1])
	return true


func get_flag(flag: StringName, default_value: Variant = false) -> Variant:
	return _flag_store(flag).get(flag, default_value)


func clear_flag(flag: StringName) -> void:
	if _flag_store(flag).erase(flag):
		EventBus.flag_changed.emit(flag, false)


## Integer flag. Saves come back from JSON with every number as float (home_tier 3 loads as 3.0): this coerces it.
## Booleans count as 1 / 0, numeric strings are parsed, anything else returns `default_value`.
func flag_int(flag: StringName, default_value: int = 0) -> int:
	if not _flag_store(flag).has(flag):
		return default_value
	var value: Variant = _flag_store(flag)[flag]
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return roundi(value)
		TYPE_BOOL:
			return 1 if value else 0
		TYPE_STRING, TYPE_STRING_NAME:
			var text := str(value)
			if text.is_valid_int():
				return text.to_int()
			if text.is_valid_float():
				return roundi(text.to_float())
	return default_value


func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL, TYPE_INT:
			return value
		TYPE_FLOAT:
			return value if is_finite(value) else null
		TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return String(value)
	return null


# ------------------------------------------------------------------ zones

func is_zone_unlocked(zone_id: StringName) -> bool:
	return zone_id in unlocked_zones


## Unlocks a zone once: zone_unlocked and the unlock toast. Never emits zone_entered (WorldRoot2D owns that signal).
func unlock_zone(zone_id: StringName) -> void:
	if zone_id == &"" or zone_id in unlocked_zones:
		return
	unlocked_zones.append(zone_id)
	EventBus.zone_unlocked.emit(zone_id)
	var zone_label := tr("ZONE_%s" % String(zone_id).to_upper())
	EventBus.notification_posted.emit(tr("NOTIF_ZONE_UNLOCKED_TITLE"), _format_one(tr("NOTIF_ZONE_UNLOCKED_MSG"), zone_label), "zone")


func _on_zone_entered(zone_id: StringName) -> void:
	if zone_id not in discovered_locations:
		discovered_locations.append(zone_id)


## `template % arg` only when the template really has a placeholder (an untranslated key must never reach the formatter).
func _format_one(template: String, arg: String) -> String:
	if template.contains("%s"):
		return template % arg
	return template


# ------------------------------------------------------------------ clock and calendar

## Advances the clock by `minutes` with exact arithmetic (see the header): crossing day_end_hour rolls the day and carries
## the overflow, as often as needed. Each roll puts the clock back by one calendar day (24 h; E h when day_end_hour E < 24), so
## the clock restarts at day_roll_restart_hour(). time_of_day_changed fires once at the end with the settled raw hour (2..25).
func advance_time(minutes: int) -> void:
	if minutes < 0:
		return
	var end_minutes := day_end_hour() * 60
	var restart_minutes := day_roll_restart_hour() * 60
	var day_minutes := end_minutes - restart_minutes
	var total := hour * 60 + minute + minutes
	var rolls := 0
	if total >= end_minutes:
		rolls = floori(float(total - restart_minutes) / float(day_minutes))
		total -= rolls * day_minutes
	for i in rolls:
		hour = floori(float(restart_minutes) / 60.0)
		minute = 0
		_roll_day()
	hour = floori(float(total) / 60.0)
	minute = total - hour * 60
	EventBus.time_of_day_changed.emit(hour, minute)


## Puts the clock at hour:minute of the same day (clamped to the day's hours) and announces it; no time passes, nothing grows. The one way
## a scene sets the clock (the first-morning tutorial), so time_of_day_changed is only ever emitted here.
func set_clock(p_hour: int, p_minute: int) -> void:
	hour = clampi(p_hour, day_start_hour(), day_end_hour() - 1)
	minute = clampi(p_minute, 0, 59)
	EventBus.time_of_day_changed.emit(hour, minute)


## Ends the current day now and starts the next morning at day_start_hour: day_ended, then day_started.
func end_day() -> void:
	EventBus.day_ended.emit(day, season)
	_step_calendar()
	hour = day_start_hour()
	minute = 0
	_announce_new_day()
	EventBus.time_of_day_changed.emit(hour, minute)


## Sleep helper for WorldRoot2D (bed and pass-out). Wakes at day_start_hour: while the raw hour is still >= day_start_hour (also
## 24:xx and 25:xx) the day ends first (end_day), after the roll (the pass-out: advance_time already rolled the day, the raw hour
## is 2..5) only the rest of the night is skipped.
## Returns the number of calendar days that passed (1 or 0).
func sleep_until_morning() -> int:
	var wake_hour := day_start_hour()
	if hour < wake_hour:
		hour = wake_hour
		minute = 0
		EventBus.time_of_day_changed.emit(hour, minute)
		return 0
	end_day()
	return 1


## Days played so far, counted from 1 ("Dag N" on the title): year, season and day folded into one number.
func total_day() -> int:
	return total_day_for(day, season, year)


## total_day() for any date (summaries of saved games read it without loading the save).
func total_day_for(p_day: int, p_season: StringName, p_year: int) -> int:
	var per_season := days_per_season()
	var season_list := seasons()
	var season_idx := maxi(season_list.find(p_season), 0)
	return ((maxi(p_year, 1) - 1) * season_list.size() + season_idx) * per_season + clampi(p_day, 1, per_season)


## One day-end roll of advance_time: the clock is at the restart hour (02:00) here, the calendar steps, the weather is rolled, a new day starts.
func _roll_day() -> void:
	EventBus.day_ended.emit(day, season)
	_step_calendar()
	_announce_new_day()
	EventBus.game_event.emit(&"midnight_passed", {"day": day, "season": String(season)})


func _step_calendar() -> void:
	day += 1
	if day > days_per_season():
		day = 1
		_advance_season()


func _advance_season() -> void:
	var season_list := seasons()
	var idx := season_list.find(season)
	season = season_list[(idx + 1) % season_list.size()]
	if season == season_list[0]:
		year += 1
	EventBus.season_changed.emit(season)


## Weather first, then day_started: every listener sees the new day's weather already rolled.
func _announce_new_day() -> void:
	var time_manager := get_node_or_null("/root/TimeManager")
	if time_manager != null and time_manager.has_method("roll_weather_for_day"):
		time_manager.roll_weather_for_day()
	EventBus.day_started.emit(day, season)


# ------------------------------------------------------------------ save / load

func to_dict() -> Dictionary:
	var zones: Array[String] = []
	for zone in unlocked_zones:
		zones.append(String(zone))
	var discovered: Array[String] = []
	for place in discovered_locations:
		discovered.append(String(place))
	return {
		"version": SAVE_VERSION,
		"player_name": player_name,
		"character_type": int(character_type),
		"character_skin": String(character_skin),
		"farm_name": farm_name,
		"day": day,
		"season": String(season),
		"year": year,
		"hour": hour,
		"minute": minute,
		"total_day": total_day(),
		"world_flags": world_flags.duplicate(),
		"unlocked_zones": zones,
		"discovered_locations": discovered,
		"play_time_seconds": play_time_seconds,
	}


## Applies a saved game. Does not touch the phase (the scene flow sets it: loading from the menu must not start the clock
## and loading from the pause menu must not drop the pause) and announces the skin like a new game does.
func from_dict(data: Dictionary) -> void:
	player_name = str(data.get("player_name", ""))
	character_type = clampi(int(data.get("character_type", CharacterType.ANIMAL)), 0, CharacterType.size() - 1) as CharacterType
	character_skin = StringName(str(data.get("character_skin", _default_skin_for(character_type))))
	farm_name = str(data.get("farm_name", tr("DEFAULT_FARM_NAME")))
	day = clampi(int(data.get("day", 1)), 1, days_per_season())
	season = StringName(str(data.get("season", seasons()[0])))
	year = maxi(int(data.get("year", 1)), 1)
	# a saved raw hour below the restart hour (an old save taken at 00:xx / 01:xx right after the old midnight roll) is the same night:
	# it is lifted to the restart hour (02:00) instead of being read as 24 h later; 24 and 25 are valid (a save at 01:40 of the same game day)
	hour = clampi(int(data.get("hour", day_start_hour())), day_roll_restart_hour(), day_end_hour() - 1)
	minute = clampi(int(data.get("minute", 0)), 0, 59)
	var new_flags := _sanitized_flags(data.get("world_flags", {}))
	var personal := PlayerRegistry.state().flags
	for key in new_flags.keys():
		if str(key).begins_with("friend_"):
			personal[key] = new_flags[key]
			new_flags.erase(key)
	var old_flags := world_flags
	world_flags = new_flags                          # assign first: a listener that reads get_flag sees the new state
	for key in old_flags.keys():
		if not new_flags.has(key):
			EventBus.flag_changed.emit(StringName(str(key)), false)   # the load dropped a flag
	for key in new_flags:
		if not old_flags.has(key) or old_flags[key] != new_flags[key]:
			EventBus.flag_changed.emit(StringName(str(key)), new_flags[key])
	unlocked_zones.assign(_string_names(data.get("unlocked_zones", _default_zones())))
	discovered_locations.assign(_string_names(data.get("discovered_locations", [])))
	play_time_seconds = float(data.get("play_time_seconds", 0.0))
	EventBus.player_character_changed.emit(PlayerRegistry.local_id(), character_skin)


func _sanitized_flags(source: Variant) -> Dictionary:
	var out := {}
	if not (source is Dictionary):
		return out
	for key in source:
		if source[key] == null:
			continue
		var safe: Variant = _json_safe(source[key])
		if safe == null:
			push_warning("GameManager.from_dict: world flag '%s' is not JSON-safe and was dropped" % str(key))
			continue
		out[key] = safe
	return out


func _string_names(source: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if source is Array:
		for entry in source:
			out.append(StringName(str(entry)))
	return out
