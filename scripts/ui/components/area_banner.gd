extends Control
## A brief title on arrival, never on loading a save or initially building the UI.
var _title_key := ""
var _landmark_key := ""
var _arrival: Tween
var _landmark: Tween
var _arriving := false
var _show_landmark := false
var _seen_world_arrival := false

func _ready() -> void:
	EventBus.area_changed.connect(_area_changed)
	EventBus.load_completed.connect(func(_slot): _dismiss())
	EventBus.modal_changed.connect(func(_stack): _visibility())
	EventBus.dialogue_started.connect(func(_npc, _dialogue): _dismiss())
	EventBus.game_event.connect(_event)
	%Title.set_meta("tt_text_same_ok", "Canonical area titles can be identical in Danish and English")
	%Title.visible = false
	%Landmark.visible = false

func _area_changed(id: StringName) -> void:
	_dismiss()
	var world := get_tree().get_first_node_in_group("world_2d")
	if world != null and world.is_ancestor_of(self) and not _seen_world_arrival:
		_seen_world_arrival = true
		return
	var map := WorldRoot2D.load_map(id)
	if map == null or not map.is_iso() or GameManager.is_modal_open():
		return
	_title_key = map.title
	%Title.text = tr(_title_key)
	_arriving = true
	%Title.modulate.a = 0.0
	_visibility()
	_arrival = create_tween()
	_arrival.tween_property(%Title, "modulate:a", 1.0, 0.15)
	_arrival.tween_interval(2.5)
	_arrival.tween_property(%Title, "modulate:a", 0.0, 0.35)
	_arrival.tween_callback(func(): _arriving = false; _visibility())

func _event(event: StringName, payload: Dictionary) -> void:
	if event != &"landmark_entered" or GameManager.is_modal_open():
		return
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.mode == &"action":
		return
	_landmark_key = str(payload.get("name_key", ""))
	if _landmark_key == "":
		return
	if _landmark != null and _landmark.is_valid():
		_landmark.kill()
	%Landmark.text = tr(_landmark_key)
	_show_landmark = true
	_visibility()
	_landmark = create_tween()
	_landmark.tween_interval(3.0)
	_landmark.tween_callback(func(): _show_landmark = false; _visibility())

func _visibility() -> void:
	var permitted := not GameManager.is_modal_open()
	%Title.visible = _arriving and permitted
	%Landmark.visible = _show_landmark and permitted

func _dismiss() -> void:
	for tween in [_arrival, _landmark]:
		if tween != null and tween.is_valid():
			tween.kill()
	_arriving = false
	_show_landmark = false
	_visibility()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		%Title.text = tr(_title_key)
		%Landmark.text = tr(_landmark_key)
