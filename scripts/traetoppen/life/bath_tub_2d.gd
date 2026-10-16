class_name BathTub2D
extends Interactable2D
var _busy := false
static func create_marker(_params: Dictionary, _pos: Vector2, _cell: Vector2i, _area: IsoArea) -> Node:
	var tub := BathTub2D.new()
	tub.prompt_key = "LIFE_BATH_PROMPT"
	return tub

func _ready() -> void:
	super._ready()

func refusal() -> String:
	if GameManager.flag_int(&"bath_day") == GameManager.total_day():
		return "LIFE_BATH_USED"
	var minutes := maxi(0, int(GameManager.config_value("traetoppen.bath.minutes", 30)))
	if GameManager.hour * 60 + GameManager.minute + minutes >= GameManager.day_end_hour() * 60:
		return "LIFE_BATH_LATE"
	return ""

func interact(player: Node) -> void:
	if _busy or not is_enabled() or player == null:
		return
	var reason := refusal()
	if reason != "":
		EventBus.whisper_requested.emit(reason)
		return
	_busy = true
	GameManager.push_modal(&"bath", false)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var veil := ColorRect.new()
	veil.color = Color(0.94, 0.91, 0.82, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(veil, "color:a", 0.92, 0.6)
	await tween.finished
	if is_instance_valid(player):
		var minutes := maxi(0, int(GameManager.config_value("traetoppen.bath.minutes", 30)))
		GameManager.set_flag(&"bath_day", GameManager.total_day())
		GameManager.advance_time(minutes)
		player.restore_stamina(player.max_stamina)
		player.heal_half(player.max_half_hearts)
		EventBus.game_event.emit(&"bath_taken", {"minutes": minutes})
		EventBus.whisper_requested.emit("LIFE_BATH_DONE")
	tween = create_tween()
	tween.tween_property(veil, "color:a", 0.0, 0.6)
	await tween.finished
	layer.queue_free()
	GameManager.pop_modal(&"bath")
	_busy = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _busy:
		GameManager.pop_modal(&"bath")
