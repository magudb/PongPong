extends RefCounted
const Chase := preload("res://scripts/dungeon_run/enemies/chase_lunge.gd")
static func tick(enemy, dt: float, direction: Vector2, distance: float) -> void:
	Chase.tick(enemy,dt,direction,distance)
	var row := LuaData.dict(enemy.cfg.get("hop",{}))
	var seconds := float(row.get("time",.35))
	var phase := fmod(enemy.clock,seconds+float(row.get("pause",.2)))
	enemy.ground_velocity = direction*float(row.get("distance",140))/seconds if phase < seconds else Vector2.ZERO
	enemy.hop_altitude = sin(phase/seconds*PI)*60 if phase < seconds else 0
