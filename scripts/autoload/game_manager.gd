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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.zone_entered.connect(_on_zone_entered)


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
	world_flags.clear()
	world_flags[FLAG_INTRO_PENDING] = true
	unlocked_zones.assign(_default_zones())
	discovered_locations.clear()
	play_time_seconds = 0.0
	_base_phase = GamePhase.PLAYING
	_drop_modals()
	# the skin is final here; the reset wave of every other system comes last
	EventBus.player_character_changed.emit(character_skin)
	EventBus.new_game_started.emit()


func _default_zones() -> Array[StringName]:
	return [&"farm", &"city"]


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
	if modal_name == &"":
		push_error("GameManager.push_modal: a modal needs a name")
		return
	var idx := _modal_index(modal_name)
	if idx >= 0:
		if bool(_modals[idx]["pauses"]) == pauses_tree:
			return
		_modals[idx]["pauses"] = pauses_tree
	else:
		_modals.append({"name": modal_name, "pauses": pauses_tree})
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

## JSON-safe flag store: bool, int, float and String (a StringName is stored as String); null clears the flag.
## Anything else (Array, Dictionary, Vector2, Object ...) is refused with an error: it would not survive a save.
func set_flag(flag: StringName, value: Variant) -> void:
	if value == null:
		world_flags.erase(flag)
		return
	var safe: Variant = _json_safe(value)
	if safe == null:
		push_error("GameManager.set_flag(%s): %s is not JSON-safe (use bool, int, float or String)" % [flag, type_string(typeof(value))])
		return
	world_flags[flag] = safe


func get_flag(flag: StringName, default_value: Variant = false) -> Variant:
	return world_flags.get(flag, default_value)


func clear_flag(flag: StringName) -> void:
	world_flags.erase(flag)


## Integer flag. Saves come back from JSON with every number as float (home_tier 3 loads as 3.0): this coerces it.
## Booleans count as 1 / 0, numeric strings are parsed, anything else returns `default_value`.
func flag_int(flag: StringName, default_value: int = 0) -> int:
	if not world_flags.has(flag):
		return default_value
	var value: Variant = world_flags[flag]
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
	world_flags = _sanitized_flags(data.get("world_flags", {}))
	unlocked_zones.assign(_string_names(data.get("unlocked_zones", _default_zones())))
	discovered_locations.assign(_string_names(data.get("discovered_locations", [])))
	play_time_seconds = float(data.get("play_time_seconds", 0.0))
	EventBus.player_character_changed.emit(character_skin)


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
