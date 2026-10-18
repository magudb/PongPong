class_name EnemyHazard2D
extends Node2D
## Harmless spore clouds slow movement; thorn bolts have one visible collision circle.
var mode := "spore"
var seconds: float = 3
var radius: float = 150
var direction := Vector2.RIGHT
var speed: float = 260
var damage: int = 1
var age: float = 0
func _physics_process(dt: float) -> void:
	if GameManager.is_modal_open():return
	age += dt
	if age >= seconds:
		queue_free()
		return
	var player := PlayerRegistry.local_player(get_tree()) as Node2D
	if mode == "bolt":
		global_position += Iso.to_screen(direction*speed*dt)
		if player != null and Iso.ground_dist(global_position,player.global_position) <= radius and player.has_method("take_damage"):
			player.take_damage(1 if DungeonRun.assist("assist_dmg") else damage,global_position)
			queue_free()
	elif mode == "impact":
		if player != null and Iso.ground_dist(global_position,player.global_position) <= radius and player.has_method("take_damage"): player.take_damage(damage,global_position)
	elif player != null and Iso.ground_dist(global_position,player.global_position) <= radius and player.has_method("apply_slow"):
		player.apply_slow(.6,.12)
	queue_redraw()
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,Iso.squash()))
	if mode == "bolt":
		draw_line(-direction*22,direction*22,Color("fbf5e6"),7,true)
		draw_circle(Vector2.ZERO,8,Color("b9dbe8"))
	else:
		draw_circle(Vector2.ZERO,radius,Color("b9a3d4",.14*(1-age/seconds)))
		draw_arc(Vector2.ZERO,radius,0,TAU,48,Color("fbf5e6",.4),2,true)
