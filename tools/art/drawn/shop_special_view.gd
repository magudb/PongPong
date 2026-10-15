extends "res://tools/art/drawn/shop_core_view.gd"
## Optional I4 dressing over read-only room snapshots. No gameplay/save writes.

static func room_ids() -> Array:
	return PaintedShopArt.table("res://docs/art/shop-special/dressing.json").keys()

func setup_special(id: String, dressed: bool = true, night: bool = false) -> void:
	var contracts := PaintedShopArt.table("res://docs/art/shop-special/room-contracts.json")
	setup_core(id, false, night, contracts["rooms"][id], str(contracts["keepers"][id]))
	if not dressed:
		return
	var overlay := PaintedShopArt.table("res://data/interiors/dress/" + str(room["id"]) + ".json")
	for item in overlay["items"]:
		var rot := int(item.get("rot", 0))
		var art := PaintedShopArt.piece(str(item["id"]), rot, false, true)
		var fp: Array = art["footprint"]
		var c: Array = item["cell"]
		var at := Vector2((float(c[0]) - float(c[1]) + (float(fp[0]) - float(fp[1])) * .5) * 64 + 64,
			(float(c[0]) + float(c[1]) + (float(fp[0]) + float(fp[1]) - 2) * .5) * 38 + 38)
		var layer := str(art["layer"])
		if layer == "wall":
			at = Vector2((float(c[0]) + .5) * 64 + 64, (float(c[0]) - .5) * 38 + 38) if rot == 0 else Vector2((-float(c[1]) - .5) * 64 + 64, (float(c[1]) - .5) * 38 + 38)
		var sprite := Sprite2D.new()
		sprite.name = "Dressing_" + str(item["id"])
		sprite.texture = load(str(art["path"])) as Texture2D
		sprite.centered = false
		var pivot: Array = art["pivot"]
		var ys: Array = art["ysort"]
		sprite.position = at + Vector2(ys[0], ys[1])
		sprite.offset = -Vector2(pivot[0] + ys[0], pivot[1] + ys[1])
		if layer == "wall":
			get_node("ReviewWalls").add_child(sprite)
		elif layer == "ceiling":
			sprite.z_index = 2
			add_child(sprite)
		else:
			get_node("ReviewObjects").add_child(sprite)
		_include(Rect2(at - Vector2(pivot[0], pivot[1]), sprite.texture.get_size()))
		if night and art.has("night"):
			var accent := Sprite2D.new()
			accent.name = "Accent_" + str(item["id"])
			accent.texture = load(str(art["night_path"])) as Texture2D
			accent.centered = false
			var offset: Array = art["night_offset"]
			accent.offset = Vector2(offset[0], offset[1])
			accent.position = sprite.offset
			accent.material = Glow.additive_material()
			sprite.add_child(accent)
	content_rect = content_rect.grow(8)
