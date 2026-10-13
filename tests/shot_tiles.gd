extends Node2D
## Tile contact sheet (P04): every terrain of the art contract as a 5 x 5 block of one TileMapLayer, built exactly like an IsoArea
## builds its ground (AreaTileSet + ArtCatalog), so a REAL atlas and its PLACEHOLDER can be told apart and checked for seams by eye.
## Prints which terrains are real art. Iso terrains first sheet, ortho terrains second.
##   godot --path . --resolution 1280x720 res://tests/shot_tiles.tscn --quit-after 3600 -- --out=DIR
var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	_run.call_deferred()


func _block(ids: Array, projection: StringName, cols: int, spacing: Vector2) -> Node2D:
	var root := Node2D.new()
	for i in ids.size():
		var layer := TileMapLayer.new()
		layer.tile_set = AreaTileSet.tile_set(projection)
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var id: StringName = ids[i]
		var sid: int = AreaTileSet.source_for(projection, id)
		var n: int = 5
		for y in n:
			for x in n:
				layer.set_cell(Vector2i(x, y), sid, AreaTileSet.atlas_coords_for(id, Vector2i(x, y)))
		layer.position = Vector2(float(i % cols) * spacing.x + 320.0, float(i / cols) * spacing.y + 200.0)
		root.add_child(layer)
		var label := Label.new()
		label.text = "%s%s" % [id, "" if ArtCatalog.has_real_terrain(id) else " (placeholder)"]
		label.position = layer.position + Vector2(-30, -30)
		label.add_theme_font_size_override("font_size", 30)
		root.add_child(label)
	return root


func _run() -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	var real: Array[String] = []
	var fake: Array[String] = []
	for id in AreaTileSet.ISO_TERRAINS + AreaTileSet.ORTHO_TERRAINS:
		(real if ArtCatalog.has_real_terrain(id) else fake).append(String(id))
	print("real terrain art: ", real)
	print("placeholder terrains: ", fake)
	var iso_ids: Array = []
	for id2 in AreaTileSet.ISO_TERRAINS:
		iso_ids.append(id2)
	var sheet1: Node2D = _block(iso_ids, &"iso", 6, Vector2(1000, 600))
	add_child(sheet1)
	cam.position = Vector2(2900, 1100)
	cam.zoom = Vector2(0.2, 0.2)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if out_dir != "":
		img.save_png("%s/tiles_iso_sheet.png" % out_dir)
	sheet1.queue_free()
	var ortho_ids: Array = []
	for id3 in AreaTileSet.ORTHO_TERRAINS:
		ortho_ids.append(id3)
	var sheet2: Node2D = _block(ortho_ids, &"ortho", 4, Vector2(700, 420))
	add_child(sheet2)
	cam.position = Vector2(1100, 330)
	cam.zoom = Vector2(0.4, 0.4)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	if out_dir != "":
		get_viewport().get_texture().get_image().save_png("%s/tiles_ortho_sheet.png" % out_dir)
	get_tree().quit()
