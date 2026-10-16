extends RefCounted
## Authoring-time projection of the exact live footprint/flood calculation.
## Runtime validates both geometry and algorithm hashes before using the cells.
static func write() -> Dictionary:
	var previous := LevelNav.use_baked_cells
	LevelNav.use_baked_cells = false
	var nav := LevelNav.make()
	LevelNav.use_baked_cells = previous
	var records := {}
	for level in nav.levels:
		var rows: Array[String] = []
		for y in level.n.y:
			var row := ""
			for x in level.n.x:
				var cell := Vector2i(x, y)
				row += "1" if level.grid.is_point_solid(cell) else ("m" if level.main.has(cell) else "0")
			rows.append(row)
		records[str(level.id)] = rows
	var result := {"format": 1, "geometry": JSON.stringify(nav.data, "", true).sha256_text(), "algorithm": FileAccess.get_sha256("res://scripts/towns/level_nav.gd"), "levels": records}
	var file := FileAccess.open(LevelNav.BAKED_CELLS, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "", true) + "\n")
	return result
