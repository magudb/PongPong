extends RefCounted
static func tick(enemy, dt: float, direction: Vector2, distance: float) -> void:
	enemy.ground_velocity = Vector2.ZERO
	var contact := LuaData.dict(enemy.cfg.get("contact",{}))
	if distance <= float(contact.get("radius",70)) and enemy.cooldown <= 0:
		enemy.begin_windup({"radius":float(contact.get("radius",70))},float(contact.get("after",.3)),"contact")
	var shoot := LuaData.dict(enemy.cfg.get("shoot",{}))
	if enemy.tier < int(shoot.get("from_tier",2)): return
	enemy.behavior_clock += dt
	if enemy.behavior_clock >= float(shoot.get("period",3.5)):
		enemy.behavior_clock = 0
		enemy.shoot(direction,float(shoot.get("speed",260)),1)
