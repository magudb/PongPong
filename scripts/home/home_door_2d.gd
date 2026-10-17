extends Interactable2D
func _init() -> void:
	prompt_key = "HOME_WORLD_ENTER"
	radius = Vector2(65, 42)
func interact(_player: Node) -> void:
	if HomeManager.can_enter_home():
		EventBus.area_change_requested.emit(&"home", &"default")
	else:
		EventBus.whisper_requested.emit("HOME_WORLD_BUILDING")
