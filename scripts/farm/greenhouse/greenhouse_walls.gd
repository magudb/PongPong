class_name GreenhouseWalls2D
extends Node2D
var area: IsoArea
static func create_marker(_params: Dictionary, pos: Vector2, _cell: Vector2i, target: IsoArea) -> Node:
	var node := GreenhouseWalls2D.new()
	node.area = target
	node.position = target.objects.to_local(pos)
	return node
func _ready() -> void:
	var art := ArtCatalog.prop(&"greenhouse_walls")
	var sprite := Sprite2D.new()
	sprite.texture = art.texture
	sprite.centered = false
	sprite.offset = -art.pivot
	sprite.z_index = -8
	sprite.position = to_local(area.cell_to_global(Vector2i(5,5)))
	add_child(sprite)
