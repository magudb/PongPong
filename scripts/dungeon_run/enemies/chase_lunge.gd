extends RefCounted
static func tick(enemy, dt: float, direction: Vector2, distance: float) -> void:
	enemy.ground_velocity = direction*enemy.speed if distance > 70 else -direction*enemy.speed*.4
	var reach: float = enemy.speed*float(enemy.cfg.get("lunge_mult",3.1))*float(enemy.cfg.get("lunge_time",.3))
	if distance <= reach+float(enemy.cfg.get("trigger_extra",70)) and enemy.cooldown <= 0:
		enemy.begin_windup({"shape":"line","width":80,"length":reach+40,"direction":direction},float(enemy.cfg.get("windup",.5)),"dash")
