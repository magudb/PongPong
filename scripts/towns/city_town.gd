class_name CityTown
extends RefCounted
## Sidecar placements use actual city geometry; route approaches retain their
## authored/resolved coordinates in routes.json for review.
static func attach(area: IsoArea, area_id := "traetoppen") -> Node:
	var existing := area.get_node_or_null("TownDirector")
	if existing != null:
		return existing
	var col := LuaData.dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/towns/" + area_id + ".json")))
	if not RouteTable.is_loaded():
		RouteTable.load_table()
	for row in col.get("doors", []):
		var building := str(row.building)
		var authored := Vector2(float(row.sx), float(row.sy)) * CityData.scale_of(CityBuilder.of(area).data)
		var door := Door2D.new()
		door.setup_building({"building": building}, area, Vector2i.ZERO)
		door.position = authored
		area.triggers.add_child(door)
		var approach := RouteTable.position_of(area_id + ".door_" + building)
		area.spawns["from_int_" + building] = area.to_global(Iso.to_screen(approach))
		# The interaction host occupies the safe approach in front of the artwork.
		door.position = Iso.to_screen(approach)
		door.set_meta("authored_door", authored)
	# The sidecar predates the two stall rows. The real routine anchors own their
	# safe positions; the shop registry owns inventory/hours.
	for row in [{"anchor": "t_stall", "shop": "timber_yard", "keeper": "carpenter_brumme", "building": "torvestanden"}, {"anchor": "e_bat_window", "shop": "natteblik_maps", "keeper": "mapseller_natteblik", "building": "natteblik_vinduet"}]:
		var point := RouteTable.position_of(area_id + "." + str(row.anchor))
		if point == Vector2.INF:
			continue
		for host_index in 3:
			var kind: String = "shop" if host_index == 0 else "talk"
			var counter := ShopCounter.new()
			counter.setup(kind, {"id": row.shop, "keeper": row.keeper}, str(row.building))
			counter.position = Iso.to_screen(point) + Vector2(0, 48)
			if kind == "talk":
				counter.position.x += -96 if host_index == 1 else 96
			area.objects.add_child(counter)
	var director := TownDirector.create(area, {}, col)
	area.add_child(director)
	_add_life(area)
	return director

static func _add_life(area: IsoArea) -> void:
	# Five small crown caches, all on walkable crown platforms. The selected
	# daily slot and hero perk determine whether any host is visible/usable.
	var anchors := ["a_beds1", "a_bench", "b_bench", "e_bench", "t_bench1"]
	for i in anchors.size():
		var point := RouteTable.position_of("traetoppen." + anchors[i])
		if point != Vector2.INF:
			var cache := CrownCache2D.create_marker({"slot": i}, Vector2.ZERO, Vector2i.ZERO, area)
			cache.position = Iso.to_screen(point)
			area.objects.add_child(cache)
	for row in LuaData.arr(GameManager.config_value("traetoppen.fast_travel.stops", [])):
		var signpost := Rejsestolpe2D.create_marker({"id": row.id}, Vector2.ZERO, Vector2i.ZERO, area)
		signpost.position = area.to_local(area.get_spawn(str(row.spawn)))
		area.objects.add_child(signpost)
