extends Node
## Central game state: player profile, world flags, run lifecycle.

enum CharacterType { ANIMAL, FAIRY, HOBBIT }
enum GamePhase { MENU, CHARACTER_SELECT, PLAYING, PAUSED, CUTSCENE }

const SAVE_VERSION := 1

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

var world_flags: Dictionary = {}
var unlocked_zones: Array[StringName] = [&"farm", &"city"]
var discovered_locations: Array[StringName] = []

var play_time_seconds: float = 0.0
var is_single_player: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.zone_entered.connect(_on_zone_entered)


func _process(delta: float) -> void:
	if current_phase == GamePhase.PLAYING:
		play_time_seconds += delta


func start_new_game(p_name: String, p_character: CharacterType, p_farm_name: String = "") -> void:
	player_name = p_name
	character_type = p_character
	character_skin = _default_skin_for(p_character)
	farm_name = p_farm_name if p_farm_name != "" else "Min Trækronsgård"
	day = 1
	season = &"foraar"
	year = 1
	hour = 6
	minute = 0
	world_flags.clear()
	unlocked_zones = [&"farm", &"city"]
	discovered_locations.clear()
	play_time_seconds = 0.0
	current_phase = GamePhase.PLAYING
	EventBus.player_character_changed.emit(character_skin)
	EventBus.day_started.emit(day, season)


func change_phase(phase: GamePhase) -> void:
	current_phase = phase
	if phase == GamePhase.PAUSED:
		get_tree().paused = true
	else:
		get_tree().paused = false


func set_flag(flag: StringName, value: Variant) -> void:
	world_flags[flag] = value


func get_flag(flag: StringName, default_value: Variant = false) -> Variant:
	return world_flags.get(flag, default_value)


func unlock_zone(zone_id: StringName) -> void:
	if zone_id not in unlocked_zones:
		unlocked_zones.append(zone_id)
		EventBus.zone_entered.emit(zone_id)
		EventBus.notification_posted.emit(
			tr("NOTIF_ZONE_UNLOCKED_TITLE"),
			tr("NOTIF_ZONE_UNLOCKED_MSG") % tr("ZONE_%s" % zone_id.to_upper()),
			"zone"
		)


func advance_time(minutes: int) -> void:
	minute += minutes
	while minute >= 60:
		minute -= 60
		hour += 1
	EventBus.time_of_day_changed.emit(hour, minute)
	if hour >= 24:
		end_day()


func end_day() -> void:
	EventBus.day_ended.emit(day, season)
	day += 1
	if day > 28:
		day = 1
		_advance_season()
	hour = 6
	minute = 0
	EventBus.day_started.emit(day, season)
	EventBus.time_of_day_changed.emit(hour, minute)


func _advance_season() -> void:
	var seasons: Array[StringName] = [&"foraar", &"sommer", &"efteraar", &"vinter"]
	var idx := seasons.find(season)
	season = seasons[(idx + 1) % seasons.size()]
	if season == &"foraar":
		year += 1
	EventBus.season_changed.emit(season)


func _default_skin_for(type: CharacterType) -> StringName:
	match type:
		CharacterType.ANIMAL:
			return &"animal_rabbit"
		CharacterType.FAIRY:
			return &"fairy_meadow"
		CharacterType.HOBBIT:
			return &"hobbit_pip"
	return &"default"


func _on_quest_completed(_quest_id: StringName) -> void:
	pass


func _on_zone_entered(zone_id: StringName) -> void:
	if zone_id not in discovered_locations:
		discovered_locations.append(zone_id)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_name": player_name,
		"character_type": character_type,
		"character_skin": character_skin,
		"farm_name": farm_name,
		"day": day,
		"season": season,
		"year": year,
		"hour": hour,
		"minute": minute,
		"world_flags": world_flags.duplicate(),
		"unlocked_zones": unlocked_zones.duplicate(),
		"discovered_locations": discovered_locations.duplicate(),
		"play_time_seconds": play_time_seconds,
	}


func from_dict(data: Dictionary) -> void:
	player_name = data.get("player_name", "")
	character_type = data.get("character_type", CharacterType.ANIMAL) as CharacterType
	character_skin = data.get("character_skin", &"animal_rabbit")
	farm_name = data.get("farm_name", "Min Trækronsgård")
	day = data.get("day", 1)
	season = data.get("season", &"foraar")
	year = data.get("year", 1)
	hour = data.get("hour", 6)
	minute = data.get("minute", 0)
	world_flags = data.get("world_flags", {}).duplicate()
	unlocked_zones.assign(data.get("unlocked_zones", [&"farm", &"city"]))
	discovered_locations.assign(data.get("discovered_locations", []))
	play_time_seconds = data.get("play_time_seconds", 0.0)
	current_phase = GamePhase.PLAYING
