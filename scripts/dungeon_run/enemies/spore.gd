extends RefCounted
static func tick(enemy, dt: float, _direction: Vector2, _distance: float) -> void:
	enemy.ground_velocity = Vector2.ZERO
	var row := LuaData.dict(enemy.cfg.get("spore",{}))
	enemy.behavior_clock += dt
	if enemy.behavior_clock >= float(row.get("period",5)):
		enemy.behavior_clock = 0
		enemy.begin_windup({"radius":float(row.get("radius",150)),"at":enemy.player.global_position},float(row.get("ring",1)),"spore")
