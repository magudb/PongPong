extends Node
## In-game clock tick, calendar names and weather (PLAN 3.9, D16). GameManager owns the date and the clock arithmetic;
## this node feeds it real time, names the calendar and rolls the weather.
##
## CALENDAR. Weeks start on Monday on day 1 of every season: weekday_index(day) = (day - 1 + first_weekday) % 7 with
## `time.first_weekday` from lua/config (default 0 = Monday). date_text() reads "Tirsdag 16. Blomstermåned" /
## "Tuesday 16. Month of Blooms" from the translation keys UI_WEEKDAY_1..7 and UI_MONTH_<SEASON> (they live in ui.csv).
##
## WEATHER. Ids klart regn taage sne torden. One roll per new day, made BEFORE day_started is emitted
## (GameManager.end_day / the midnight roll call roll_weather_for_day(); the day_started handler below is only a guarded
## safety net, so a day is never rolled twice). The odds are `time.weather_chances.<season>` in game_balance.lua: WEIGHTS
## per weather id, normalised here; a season without a klart weight gets klart as the remainder up to 1.0; snow only ever
## happens in vinter. The old literals are the default when the config has no entry. EventBus.weather_changed fires
## whenever the weather is (re)determined: daily roll, set_weather(), reset and load. Only `regn` has a rule (is_raining)
## and a visual; the other ids are labels.

const WEATHER_IDS: Array[StringName] = [&"klart", &"regn", &"taage", &"sne", &"torden"]

## Default weights per season (the previous hard-coded rolls); klart is the remainder.
const DEFAULT_WEATHER_CHANCES := {
	&"foraar": {&"regn": 0.25, &"taage": 0.15},
	&"sommer": {&"regn": 0.16, &"torden": 0.12},
	&"efteraar": {&"regn": 0.35, &"taage": 0.20},
	&"vinter": {&"taage": 0.25, &"sne": 0.45},
}

var time_scale: float = 1.0
var is_paused: bool = false
var weather: StringName = &"klart"  # klart, regn, taage, sne, torden
var weather_duration_hours: int = 6
## Daily rolls made since the last reset (tests assert "once per day").
var weather_rolls: int = 0

var _acc_minutes: float = 0.0
var _weather_day: int = -1       # GameManager.total_day() the current weather belongs to

# Crop growth modifiers by season
var season_growth_mod: Dictionary = {
	&"foraar": 1.0,
	&"sommer": 1.15,
	&"efteraar": 0.9,
	&"vinter": 0.35,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.day_started.connect(_on_day_started)
	EventBus.new_game_started.connect(reset)


func _process(delta: float) -> void:
	tick(delta)


## Feeds real time into the game clock. Only while PLAYING and not paused; a paused or modal game never ticks.
func tick(delta: float) -> void:
	if is_paused or GameManager.current_phase != GameManager.GamePhase.PLAYING:
		return
	_acc_minutes += delta * GameManager.minutes_per_real_second() * time_scale
	if _acc_minutes >= 1.0:
		var whole := int(_acc_minutes)
		_acc_minutes -= whole
		GameManager.advance_time(whole)


## Stops the clock (the forest runs on the lantern-oil clock). Idempotent: pausing twice and resuming once runs it.
func pause_time() -> void:
	is_paused = true


func resume_time() -> void:
	is_paused = false


func set_time_scale(scale: float) -> void:
	time_scale = maxf(scale, 0.1)


## New game: weather, clock accumulator and pause state back to the start of a run (day 1 is sunny).
func reset() -> void:
	time_scale = 1.0
	is_paused = false
	_acc_minutes = 0.0
	weather_duration_hours = 6
	weather_rolls = 0
	_weather_day = GameManager.total_day()
	_apply_weather(&"klart")


func get_day_fraction() -> float:
	return (GameManager.hour * 60.0 + GameManager.minute) / (GameManager.day_end_hour() * 60.0)


## `time.night_start_hour` / `time.night_end_hour` (defaults 20 and 5).
func is_night() -> bool:
	var night_start := int(GameManager.config_value("time.night_start_hour", 20))
	var night_end := int(GameManager.config_value("time.night_end_hour", 5))
	return GameManager.hour >= night_start or GameManager.hour < night_end


# ------------------------------------------------------------------ calendar names

## `time.first_weekday` (game_balance.lua): 0 = Monday is day 1 of every season.
func first_weekday() -> int:
	return posmod(int(GameManager.config_value("time.first_weekday", 0)), 7)


## 0 = Mandag .. 6 = Søndag for a day of the season (default: today).
func weekday_index(p_day: int = -1) -> int:
	var d := GameManager.day if p_day < 0 else p_day
	return posmod(d - 1 + first_weekday(), 7)


func weekday_name(p_day: int = -1) -> String:
	return tr("UI_WEEKDAY_%d" % (weekday_index(p_day) + 1))


## Month name of a season id (default: the current season): Blomstermåned for foraar ...
func season_month_name(p_season: StringName = &"") -> String:
	var s := p_season if p_season != &"" else GameManager.season
	return tr("UI_MONTH_%s" % String(s).to_upper())


## "Tirsdag 16. Blomstermåned" (da) / "Tuesday 16. Month of Blooms" (en).
func date_text(p_day: int = -1, p_season: StringName = &"") -> String:
	var d := GameManager.day if p_day < 0 else p_day
	return "%s %d. %s" % [weekday_name(d), d, season_month_name(p_season)]


# ------------------------------------------------------------------ weather

func weather_name(p_weather: StringName = &"") -> String:
	var id := p_weather if p_weather != &"" else weather
	return tr("UI_WEATHER_%s" % String(id).to_upper())


func is_raining() -> bool:
	return weather == &"regn"


## Sets the weather by hand (tests, debug, scripted events) and announces it.
func set_weather(weather_id: StringName) -> void:
	if weather_id not in WEATHER_IDS:
		push_error("TimeManager.set_weather: unknown weather id '%s'" % weather_id)
		return
	_apply_weather(weather_id)


## Normalised probability per weather id for a season (sums to 1.0, klart included, sne only in vinter).
func weather_chances(p_season: StringName = &"") -> Dictionary:
	var s := p_season if p_season != &"" else GameManager.season
	var configured: Variant = GameManager.config_value("time.weather_chances.%s" % s, null)
	var source: Dictionary = configured if configured is Dictionary else DEFAULT_WEATHER_CHANCES.get(s, {})
	var weights := {}
	var others := 0.0
	for id in WEATHER_IDS:
		if id == &"klart" or (id == &"sne" and s != &"vinter"):
			continue
		var weight := maxf(float(source.get(id, 0.0)), 0.0)
		if weight > 0.0:
			weights[id] = weight
			others += weight
	if source.has(&"klart"):
		weights[&"klart"] = maxf(float(source[&"klart"]), 0.0)
	else:
		weights[&"klart"] = maxf(1.0 - others, 0.0)
	var total := 0.0
	for id in weights:
		total += float(weights[id])
	if total <= 0.0:
		return {&"klart": 1.0}
	var out := {}
	for id in weights:
		if float(weights[id]) > 0.0:
			out[id] = float(weights[id]) / total
	return out


## Rolls the weather of the new day exactly once: a second call for the same day (a stray day_started) does nothing.
func roll_weather_for_day() -> void:
	var today := GameManager.total_day()
	if _weather_day == today:
		return
	_weather_day = today
	weather_rolls += 1
	roll_weather()


## Always rolls (a roll value in 0..1 can be passed in to make a test deterministic). The buckets run in the order of
## WEATHER_IDS with klart last, so the rare weather sits at the low end of the roll.
func roll_weather(p_roll: float = -1.0) -> void:
	var r := randf() if p_roll < 0.0 else minf(p_roll, 0.999999)
	var chances := weather_chances()
	var accumulated := 0.0
	var picked: StringName = &"klart"
	for id in WEATHER_IDS:
		if id == &"klart" or not chances.has(id):
			continue
		accumulated += float(chances[id])
		if r < accumulated:
			picked = id
			break
	weather_duration_hours = randi_range(3, 10)
	_apply_weather(picked)


func _apply_weather(weather_id: StringName) -> void:
	weather = weather_id
	EventBus.weather_changed.emit(weather)


func get_growth_modifier() -> float:
	var base: float = season_growth_mod.get(GameManager.season, 1.0)
	match weather:
		&"regn":
			return base * 1.1
		&"taage":
			return base * 0.95
		&"sne":
			return base * 0.7
		&"torden":
			return base * 1.2
	return base


func _on_day_started(_day: int, _season: StringName) -> void:
	roll_weather_for_day()


# ------------------------------------------------------------------ save / load

func to_dict() -> Dictionary:
	return {
		"time_scale": time_scale,
		"weather": String(weather),
		"weather_duration_hours": weather_duration_hours,
		"weather_day": _weather_day,
	}


func from_dict(data: Dictionary) -> void:
	time_scale = maxf(float(data.get("time_scale", 1.0)), 0.1)
	var saved := StringName(str(data.get("weather", "klart")))
	weather_duration_hours = int(data.get("weather_duration_hours", 6))
	_weather_day = int(data.get("weather_day", GameManager.total_day()))
	_acc_minutes = 0.0
	_apply_weather(saved if saved in WEATHER_IDS else &"klart")
