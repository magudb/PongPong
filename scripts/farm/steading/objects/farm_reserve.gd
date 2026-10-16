class_name FarmReserve
extends RefCounted
## Geometry cache belongs to the area. No global mutable cache survives a new game.
static func blocked(area: IsoArea, cell: Vector2i) -> String:
	if area == null or area.map == null or area.map.id != &"farm":
		return ""
	if not area.has_meta("farm_reserve"):
		area.set_meta("farm_reserve", _build(area))
	var reserved: Dictionary = area.get_meta("farm_reserve")
	if reserved.has(cell):
		return str(reserved[cell])
	if area.farmable.has(cell):
		return "field"
	return "bridge" if area.map.ground_at(cell) == "=" else ""

static func _build(area: IsoArea) -> Dictionary:
	var out := {}
	var home: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/iso_props/home/home.json"))
	var tiers := LuaData.arr(home.get("tiers", []))
	var largest := LuaData.dict(tiers[-1]) if not tiers.is_empty() else {}
	var footprint := LuaData.arr(largest.get("footprint_tiles", [9, 6]))
	for marker in area.markers:
		var type := str(marker.type)
		var cell: Vector2i = marker.cell
		var reason := ""
		var size := Vector2i.ONE
		match type:
			"home":
				reason = "home"
				size = Vector2i(int(footprint[0]), int(footprint[1]))
			"field_expansion":
				for c in IsoArea.parse_cells(str(marker.params.get("cells", "")), Vector2i(area.map.width, area.map.height)):
					out[c] = "zone"
			"building_slot", "greenhouse_slot":
				reason = "slot"
				var kind := str(marker.params.get("type", "greenhouse"))
				var dimensions := LuaData.arr(Svc.lua_config("farm_site.slot_footprints." + kind, [4, 3]))
				size = Vector2i(int(dimensions[0]), int(dimensions[1]))
			"spawn":
				reason = "spawn"
			"warp":
				reason = "warp"
		if reason != "":
			var left := cell.x - int(size.x / 2) if reason == "home" else cell.x - size.x + 1
			for y in range(cell.y - size.y + 1, cell.y + 1):
				for x in range(left, left + size.x):
					if not out.has(Vector2i(x, y)):
						out[Vector2i(x, y)] = reason
	return out
