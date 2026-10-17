extends Interactable2D
## Interaction points lie on reachable cells next to the painted furniture.
var kind := ""
func interact(player: Node) -> void:
	if not is_enabled():
		return
	match kind:
		"sleep": get_tree().call_group("world_2d", "sleep")
		"storage": EventBus.game_event.emit(&"open_home_chest", {})
		"warm":
			if HomeManager.unlocked("oven"):EventBus.game_event.emit(&"open_home_amenities",{})
			else:EventBus.whisper_requested.emit("HOME_WORLD_WARM")
		"sit", "play": EventBus.whisper_requested.emit("HOME_WORLD_" + kind.to_upper())
		_: super.interact(player)
