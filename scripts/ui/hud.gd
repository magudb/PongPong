extends Control
## HUD: gold, time, season, weather, quest tracker, notifications.

@onready var gold_label: Label = %GoldLabel
@onready var time_label: Label = %TimeLabel
@onready var day_label: Label = %DayLabel
@onready var season_label: Label = %SeasonLabel
@onready var weather_label: Label = %WeatherLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var quest_tracker: VBoxContainer = %QuestTracker
@onready var notification_box: VBoxContainer = %NotificationBox
@onready var interaction_prompt: Label = %InteractionPrompt

const NOTIFICATION_DURATION := 4.0


func _ready() -> void:
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.time_of_day_changed.connect(_on_time_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_stats_changed.connect(_on_stats_changed)
	EventBus.notification_posted.connect(_on_notification)
	EventBus.quest_accepted.connect(_on_quest_changed)
	EventBus.quest_completed.connect(_on_quest_changed)
	EventBus.quest_objective_updated.connect(_on_quest_objective)
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt)
	_refresh_all()


func _refresh_all() -> void:
	_on_gold_changed(EconomyManager.gold, 0)
	_on_time_changed(GameManager.hour, GameManager.minute)
	_on_day_started(GameManager.day, GameManager.season)
	_on_season_changed(GameManager.season)
	_refresh_quest_tracker()


func _on_gold_changed(amount: int, _delta: int) -> void:
	if gold_label:
		gold_label.text = "%s: %d" % [tr("UI_GOLD"), amount]


func _on_time_changed(hour: int, minute: int) -> void:
	if time_label:
		time_label.text = "%02d:%02d" % [hour, minute]


func _on_day_started(day: int, season: StringName) -> void:
	if day_label:
		day_label.text = "%s %d" % [tr("UI_DAY"), day]
	_on_season_changed(season)


func _on_season_changed(season: StringName) -> void:
	if season_label:
		season_label.text = tr("UI_SEASON_%s" % season.to_upper())
	_on_weather_changed(TimeManager.weather)


func _on_weather_changed(weather: StringName) -> void:
	if weather_label:
		weather_label.text = tr("UI_WEATHER_%s" % weather.to_upper())


func _on_health_changed(half_hearts: int, max_half_hearts: int) -> void:
	if health_bar:
		health_bar.max_value = max_half_hearts
		health_bar.value = half_hearts


func _on_stats_changed(stats: Dictionary) -> void:
	if health_bar:
		# half-hearts keys win: they are the player contract (player_health_changed / player_stats_changed payloads)
		health_bar.max_value = stats.get("max_half_hearts", stats.get("max_health", 100))
		health_bar.value = stats.get("half_hearts", stats.get("health", 100))
	if stamina_bar:
		stamina_bar.max_value = stats.get("max_stamina", 100)
		stamina_bar.value = stats.get("stamina", 100)


func _on_notification(title: String, message: String, _icon: String) -> void:
	if notification_box == null:
		return
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	var msg_label := Label.new()
	msg_label.text = message
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_label)
	vbox.add_child(msg_label)
	panel.add_child(vbox)
	notification_box.add_child(panel)

	var tween := create_tween()
	tween.tween_interval(NOTIFICATION_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)


func _on_quest_changed(_id: StringName = &"") -> void:
	_refresh_quest_tracker()


func _on_quest_objective(_q: StringName, _o: StringName, _p: int, _t: int) -> void:
	_refresh_quest_tracker()


func _refresh_quest_tracker() -> void:
	if quest_tracker == null:
		return
	for child in quest_tracker.get_children():
		child.queue_free()

	for quest in QuestManager.get_active_quests():
		var title := Label.new()
		title.text = tr("QUEST_%s_TITLE" % str(quest.id).to_upper())
		title.add_theme_font_size_override("font_size", 16)
		quest_tracker.add_child(title)

		for obj_id in quest.objectives:
			var obj: Dictionary = quest.objectives[obj_id]
			var obj_label := Label.new()
			var desc := tr("OBJ_%s" % str(obj_id).to_upper())
			obj_label.text = "  %s (%d/%d)" % [desc, obj["current"], obj["target"]]
			obj_label.add_theme_font_size_override("font_size", 13)
			if obj["done"]:
				obj_label.modulate = Color(0.6, 1.0, 0.6)
			quest_tracker.add_child(obj_label)


## The player's facing-cell query emits the prompt text (EventBus.interaction_prompt_changed): the 2D player has no
## get_interaction_prompt() method, so polling one would never show anything.
func _on_interaction_prompt(text: String) -> void:
	if interaction_prompt == null:
		return
	interaction_prompt.text = text
	interaction_prompt.visible = text != ""
