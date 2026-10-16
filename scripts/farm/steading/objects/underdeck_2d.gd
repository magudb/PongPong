extends RefCounted
static func create_marker(params: Dictionary, _pos: Vector2, cell: Vector2i, area: IsoArea) -> Node:
	var art := ArtCatalog.prop(StringName(str(params.get("prop", "trunk_under_a"))))
	var holder := Node2D.new()
	holder.name = "UnderDeck_%d_%d" % [cell.x, cell.y]
	holder.z_index = -11
	var sprite := Sprite2D.new()
	sprite.texture = art.texture
	sprite.centered = false
	sprite.offset = -art.pivot
	holder.add_child(sprite)
	area.add_child(holder)
	return holder
