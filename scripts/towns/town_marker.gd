class_name TownMarker
extends RefCounted
## Data-only posts and doors share the baker's collection/clearance implementation.
static func create_marker(params: Dictionary, pos: Vector2, cell: Vector2i, area: IsoArea) -> Node:
	match str(params.get("marker", "")):
		"town":
			return TownDirector.create(area, params)
		"door":
			return Door2D.create_marker(params, pos, cell, area)
		"post":
			var post := Marker2D.new()
			post.name = "Post_" + str(params.get("name", params.get("spot", "fest")))
			post.add_to_group("town_post")
			return post
	return null
