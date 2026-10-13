extends Area3D
## Detects when player enters/exits a zone.

var zone_id: StringName = &""


func _ready() -> void:
	zone_id = get_meta("zone_id", &"")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.unlock_zone(zone_id)
		EventBus.zone_entered.emit(zone_id)
		EventBus.player_moved.emit(zone_id)
		if zone_id == &"dark_forest":
			AudioManager.play_music("dark_forest_theme")
		elif zone_id == &"city":
			AudioManager.play_music("city_theme")
		else:
			AudioManager.play_music("forest_theme")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		EventBus.zone_exited.emit(zone_id)
