extends Node2D
## 2:1 diamond terrain drawn with CanvasItem, demonstrating the coordinate system.
## Replace with a Godot TileMapLayer when the actual map tiles are available.

@export var tiles_across: int = 22
@export var half_tile_width: float = 68.0
@export var half_tile_height: float = 34.0


func _draw() -> void:
	var tiles := maxi(tiles_across, 4)
	var half := int(tiles / 2)
	for row in range(-half, half):
		for col in range(-half, half):
			var x := float(col - row) * half_tile_width
			var y := float(col + row) * half_tile_height
			var center := Vector2(x, y)
			var corners := PackedVector2Array([
				center + Vector2(0, -half_tile_height),
				center + Vector2(half_tile_width, 0),
				center + Vector2(0, half_tile_height),
				center + Vector2(-half_tile_width, 0)
			])
			var shade := Color("b9dbb8") if (row + col) % 2 == 0 else Color("b3d5b0")
			draw_colored_polygon(corners, shade)
			draw_polyline(
				PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]),
				Color(0.40, 0.60, 0.41, 0.14), 1.0, true
			)
			if posmod(row * 17 + col * 7, 13) == 0:
				draw_circle(center + Vector2(-15, 0), 3.0, Color("f7e5b1"))
				draw_circle(center + Vector2(-8, -2), 2.0, Color("ffffff"))
