extends RefCounted
static func tick(enemy, _dt: float, direction: Vector2, distance: float) -> void:
	var row := LuaData.dict(enemy.cfg.get("flee",{}))
	enemy.ground_velocity = -direction*float(row.get("speed",190)) if distance < float(row.get("radius",330)) else Vector2.ZERO
	if enemy.is_on_wall():
		enemy.ground_velocity = Vector2.ZERO
		enemy.visual.play_loop(&"sleep")
