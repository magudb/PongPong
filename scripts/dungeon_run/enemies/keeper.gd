extends RefCounted
static func tick(enemy, _dt: float, direction: Vector2, distance: float) -> void:
	var row := LuaData.dict(enemy.cfg.get("keeper",{}))
	var desired := float(row.get("distance",400))
	enemy.ground_velocity = direction*enemy.speed if distance > desired+35 else -direction*enemy.speed if distance < desired-35 else Vector2.ZERO
	if enemy.cooldown <= 0:
		enemy.begin_windup({"shape":"line","width":float(row.get("width",45)),"length":float(row.get("length",650)),"direction":direction},float(row.get("line",.9)),"lance")
