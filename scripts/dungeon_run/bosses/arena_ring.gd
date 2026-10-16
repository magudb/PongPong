extends Node2D
var player: Node2D
func _process(_dt: float) -> void:
	visible = is_instance_valid(player) and Iso.ground_dist(global_position,player.global_position) <= 900
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,Iso.squash()))
	draw_arc(Vector2.ZERO,210,0,TAU,64,Color("fbf5e6",.3),3,true)
