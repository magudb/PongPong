class_name TutorialHints
extends Node
## Event-fed once-per-save hints; proximity/clock conditions share a 3Hz check.
const GAP := 12.0
var world: Node
var hints: Array = []
var queued: Dictionary = {}
var last_shown := -1000.0
var _poll := 0.0

static func attach(target: Node) -> Node:
	var engine := TutorialHints.new()
	engine.name = "FarmTutorialHints"
	engine.world = target
	target.add_child(engine)
	return engine

func _ready() -> void:
	refresh_data()
	EventBus.game_event.connect(_event)
	EventBus.crop_planted.connect(func(_plot, _crop): _trigger("crop_planted"))
	EventBus.crop_watered.connect(func(_plot): _trigger("crop_watered"))
	EventBus.crop_harvested.connect(func(_plot, _crop, _amount): _trigger("crop_harvested"))
	EventBus.player_stats_changed.connect(_stats)
	EventBus.quest_completed.connect(_completed)

func refresh_data() -> void:
	hints = LuaData.arr(GameManager.config_value("farm_tutorial.hints", [])).duplicate(true)

func _active() -> bool:
	return QuestManager.is_active(&"forste_dage") and not bool(GameManager.get_flag(&"tut_done", false))

func _completed(_player_id: StringName, id: StringName) -> void:
	if id == &"forste_dage":
		GameManager.set_flag(&"tut_done", 1)
		queued.clear()

func _stats(_player_id: StringName, stats: Dictionary) -> void:
	if float(stats.get("stamina", 100)) <= float(stats.get("max_stamina", 100)) * 0.2:
		_trigger("energy_low")

func _event(id: StringName, payload: Dictionary) -> void:
	if id == &"tutorial_hint_request":
		request(str(payload.get("id", "")))
	elif id == &"crop_ready":
		_trigger("crop_ready")
	else:
		_trigger("game_event", str(id))

func _trigger(kind: String, event := "") -> void:
	if not _active():
		return
	for hint in hints:
		if str(hint.get("on", "")) == kind and (kind != "game_event" or str(hint.get("event", "")) == event):
			request(str(hint.id))

func request(id: String) -> void:
	if _active() and not bool(GameManager.get_flag(StringName("tut_hint_" + id), false)):
		queued[id] = true

func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.33:
		return
	_poll = 0
	tick(float(Time.get_ticks_msec()) / 1000.0)

## Explicit monotonic clock is also the deterministic test seam for the 12s gap.
func tick(now: float) -> void:
	if not _active() or GameManager.current_phase != GameManager.GamePhase.PLAYING or not is_instance_valid(world) or world.area == null or str(world.area.map.id) != "farm":
		return
	for hint in hints:
		match str(hint.get("on", "")):
			"hour_at_least":
				if GameManager.hour + GameManager.minute / 60.0 >= float(hint.get("hour", 26)):
					request(str(hint.id))
			"day_at_least":
				if GameManager.total_day() >= int(hint.get("day", 1)):
					request(str(hint.id))
			"gold_at_least":
				if GameManager.total_day() >= int(hint.get("day", 1)) and EconomyManager.gold >= int(hint.get("gold", 0)):
					request(str(hint.id))
			"near_warp":
				for marker in world.area.find_markers("warp"):
					if Iso.to_ground(world.player.global_position - world.area.cell_to_global(marker.cell)).length() < 220:
						request(str(hint.id))
	if now - last_shown < GAP:
		return
	for hint in hints:
		var id := str(hint.id)
		if not queued.has(id) or bool(GameManager.get_flag(StringName("tut_hint_" + id), false)):
			continue
		queued.erase(id)
		GameManager.set_flag(StringName("tut_hint_" + id), 1)
		last_shown = now
		EventBus.whisper_requested.emit(UiHints.format_line(hint))
		EventBus.game_event.emit(&"tutorial_hint_shown", {"id": id})
		return
