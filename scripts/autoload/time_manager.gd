extends Node
## In-game clock, seasons, weather. Ticks only while playing.

const MINUTES_PER_REAL_SECOND := 2.0  # 1 game-hour per 30 real seconds
const HOURS_PER_DAY := 24
const DAYS_PER_SEASON := 28
const SEASONS: Array[StringName] = [&"foraar", &"sommer", &"efteraar", &"vinter"]

var time_scale: float = 1.0
var is_paused: bool = false
var weather: StringName = &"klart"  # klart, regn, taage, sne, torden
var weather_duration_hours: int = 6
var _acc_minutes: float = 0.0

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


func _process(delta: float) -> void:
	if is_paused or GameManager.current_phase != GameManager.GamePhase.PLAYING:
		return
	_acc_minutes += delta * MINUTES_PER_REAL_SECOND * time_scale
	if _acc_minutes >= 1.0:
		var whole := int(_acc_minutes)
		_acc_minutes -= whole
		GameManager.advance_time(whole)


func pause_time() -> void:
	is_paused = true


func resume_time() -> void:
	is_paused = false


func set_time_scale(scale: float) -> void:
	time_scale = maxf(scale, 0.1)


func get_day_fraction() -> float:
	return (GameManager.hour * 60.0 + GameManager.minute) / (HOURS_PER_DAY * 60.0)


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


func is_night() -> bool:
	return GameManager.hour >= 20 or GameManager.hour < 5


func roll_weather() -> void:
	var roll := randf()
	var season: StringName = GameManager.season
	match season:
		&"vinter":
			weather = &"sne" if roll < 0.45 else (&"taage" if roll < 0.7 else &"klart")
		&"efteraar":
			weather = &"regn" if roll < 0.35 else (&"taage" if roll < 0.55 else &"klart")
		&"sommer":
			weather = &"torden" if roll < 0.12 else (&"regn" if roll < 0.28 else &"klart")
		_:
			weather = &"regn" if roll < 0.25 else (&"taage" if roll < 0.4 else &"klart")
	weather_duration_hours = randi_range(3, 10)


func _on_day_started(_day: int, _season: StringName) -> void:
	roll_weather()


func to_dict() -> Dictionary:
	return {
		"time_scale": time_scale,
		"weather": weather,
		"weather_duration_hours": weather_duration_hours,
	}


func from_dict(data: Dictionary) -> void:
	time_scale = data.get("time_scale", 1.0)
	weather = data.get("weather", &"klart")
	weather_duration_hours = data.get("weather_duration_hours", 6)
