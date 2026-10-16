class_name PostBatch
extends Node2D
## Posts on one rail share its depth and texture. Keep every authored position
## while issuing their draw commands from a single CanvasItem.
var texture: Texture2D
var positions := PackedVector2Array()

func _draw() -> void:
	if texture == null:
		return
	var pivot := Vector2(texture.get_width() * 0.5, texture.get_height())
	for point in positions:
		draw_texture(texture, point - pivot)
