extends RefCounted
const SECTION := "furniture"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await t.start_world()
	_rules(t)
	_ownership(t)

func _rules(t) -> void:
	var items := HomeData.furniture()

	var g := FurnitureGrid.new()
	g.setup(HomeData.room(5), items)
	# --- maths
	var tm := TileMapLayer.new()
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(128, 76)
	tm.tile_set = ts
	for c in [Vector2i(0, 0), Vector2i(3, 1), Vector2i(2, 5), Vector2i(8, 6)]:
		t.check("cell_to_local == map_to_local - half tile %s" % c, (tm.map_to_local(c) - Vector2(64, 38)).is_equal_approx(HomeData.cell_to_local(Vector2(c))), str(tm.map_to_local(c)) + " vs " + str(HomeData.cell_to_local(Vector2(c))))
	t.check("local_to_cell roundtrip", HomeData.local_to_cell(HomeData.cell_to_local(Vector2(3.5, 2.25))).is_equal_approx(Vector2(3.5, 2.25)))
	# --- footprint + rotation
	t.check("bed 2x3 rot0 dims", HomeData.rot_dims(items["bed_pine"]["footprint"], 0) == Vector2i(2, 3))
	t.check("bed rot1 dims swap", HomeData.rot_dims(items["bed_pine"]["footprint"], 1) == Vector2i(3, 2))
	t.check("footprint cells count rot1", g.footprint_cells("bed_pine", Vector2i(2, 2), 1).size() == 6)
	t.check("rot_vec front r1 = +x", HomeData.rot_vec(Vector2(0, 1), 1) == Vector2(1, 0))
	# --- floor rules
	t.check("place sofa free", g.can_place("sofa_pine_two", Vector2i(4, 3), 0)["ok"])
	t.check("out of room (wing is narrow)", g.can_place("sofa_pine_two", Vector2i(4, 5), 0)["reason"] == "out_of_room")
	t.check("out of room negative", g.can_place("chair_pine", Vector2i(-1, 2), 0)["reason"] == "out_of_room")
	var uid := g.place("sofa_pine_two", Vector2i(4, 3), 0)
	t.check("placed uid", uid > 0)
	t.check("overlap rejected", g.can_place("chair_pine", Vector2i(5, 3), 0)["reason"] == "overlap")
	t.check("adjacent ok", g.can_place("chair_pine", Vector2i(6, 3), 0)["ok"])
	t.check("door cell blocked", g.can_place("chair_pine", g.door_cell, 0)["reason"] == "door_blocked", str(g.can_place("chair_pine", g.door_cell, 0)))
	t.check("spawn cell blocked", g.can_place("chair_pine", g.spawn_cell, 0)["reason"] == "door_blocked")
	t.check("wardrobe in front of window rejected", g.can_place("wardrobe_pine", Vector2i(4, 0), 0)["reason"] == "blocks_window", str(g.can_place("wardrobe_pine", Vector2i(4, 0), 0)))
	t.check("chair in front of window allowed", g.can_place("chair_pine", Vector2i(4, 0), 0)["ok"])
	t.check("fireplace mid room needs wall", g.can_place("fireplace_granite", Vector2i(2, 2), 0)["reason"] == "needs_wall")
	t.check("fireplace rot2 needs wall", g.can_place("fireplace_granite", Vector2i(2, 0), 2)["reason"] == "needs_wall")
	t.check("fireplace at back wall ok", g.can_place("fireplace_granite", Vector2i(2, 0), 0)["ok"])
	t.check("fireplace on left wall rot1 ok", g.can_place("fireplace_granite", Vector2i(0, 5), 1)["ok"], str(g.can_place("fireplace_granite", Vector2i(0, 5), 1)))
	# --- rugs
	t.check("rug ok under sofa", g.can_place("rug_natural", Vector2i(3, 2), 0)["ok"])
	var _ru := g.place("rug_natural", Vector2i(3, 2), 0)
	t.check("rug overlap rug", g.can_place("rug_striped_blue", Vector2i(4, 3), 0)["reason"] == "overlap")
	t.check("furniture on rug ok", g.can_place("chair_pine", Vector2i(3, 2), 0)["ok"])
	# --- wall
	t.check("painting on plain segment", g.can_place("painting_small_pine", Vector2i(2, 0), 0)["ok"])
	t.check("painting on window segment rejected", g.can_place("painting_small_pine", Vector2i(1, 0), 0)["reason"] == "window_taken")
	t.check("curtain on plain segment rejected", g.can_place("curtain_natural", Vector2i(2, 0), 0)["reason"] == "needs_window")
	t.check("curtain on window ok", g.can_place("curtain_natural", Vector2i(1, 0), 0)["ok"])
	t.check("wall item rot2 invalid", g.can_place("painting_small_pine", Vector2i(2, 0), 2)["reason"] == "wall_orientation")
	t.check("wide painting spans 2 segments", g.can_place("painting_gold_wide", Vector2i(2, 0), 0)["ok"])
	t.check("wide painting over window seg rejected", g.can_place("painting_gold_wide", Vector2i(0, 0), 0)["reason"] == "window_taken")
	var _pw := g.place("painting_small_pine", Vector2i(2, 0), 0)
	t.check("wall slot taken", g.can_place("painting_small_pine", Vector2i(2, 0), 0)["reason"] == "wall_taken")
	t.check("tall floor item under low wall item rejected", g.can_place("bookshelf_pine", Vector2i(2, 0), 0)["reason"] == "too_tall", str(g.can_place("bookshelf_pine", Vector2i(2, 0), 0)))
	t.check("x wall segment out of range", g.can_place("painting_small_pine", Vector2i(0, 9), 1)["reason"] == "out_of_room")
	# --- tabletop
	var tb := g.place("table_dining_oak", Vector2i(6, 3), 0)
	t.check("table placed", tb > 0)
	t.check("vase needs surface (floor cell empty)", g.can_place("vase_clay", Vector2i(3, 4), 0)["reason"] == "needs_surface")
	t.check("vase on table slot 0", g.can_place("vase_clay", Vector2i(6, 3), 0)["ok"])
	t.check("vase on table slot 1", g.can_place("vase_clay", Vector2i(7, 3), 0)["ok"])
	var v1 := g.place("vase_clay", Vector2i(6, 3), 0)
	t.check("slot taken", g.can_place("vase_rose", Vector2i(6, 3), 0)["reason"] == "slot_taken")
	t.check("other slot still free", g.can_place("vase_rose", Vector2i(7, 3), 0)["ok"])
	# --- ceiling
	t.check("chandelier ok", g.can_place("chandelier_iron", Vector2i(4, 3), 0)["ok"])
	g.place("chandelier_iron", Vector2i(4, 3), 0)
	t.check("chandelier overlap", g.can_place("chandelier_copper", Vector2i(4, 3), 0)["reason"] == "overlap")
	# --- remove cascades
	g.remove(tb)
	t.check("removing a table removes its vase", not g.placements.has(v1))
	t.check("table cells free again", g.can_place("table_dining_oak", Vector2i(6, 3), 0)["ok"])
	# front of an interactive item must stay reachable
	var g3 := FurnitureGrid.new()
	g3.setup(HomeData.room(1), items)
	g3.place("bed_pine", Vector2i(3, 0), 0) if false else null
	g3.place("fireplace_granite", Vector2i(2, 0), 0)
	t.check("fireplace front is cells (2,1),(3,1)", g3.front_cells("fireplace_granite", Vector2i(2, 0), 0) == [Vector2i(2, 1), Vector2i(3, 1)], str(g3.front_cells("fireplace_granite", Vector2i(2, 0), 0)))
	g3.place("chest_pine", Vector2i(2, 1), 0)
	var r := g3.can_place("chest_pine", Vector2i(3, 1), 0)
	t.check("blocking the only access to the fireplace is rejected", r["reason"] == "blocks_path", str(r))
	# --- full / capacity
	var g4 := FurnitureGrid.new()
	g4.setup(HomeData.room(1), items)
	g4.max_items = 2
	g4.place("chest_pine", Vector2i(0, 0), 0)
	g4.place("chest_oak", Vector2i(4, 0), 0)
	t.check("room capacity", g4.can_place("chair_pine", Vector2i(1, 1), 0)["reason"] == "full")
	# --- save/load roundtrip
	var save := g.to_save()
	var g5 := FurnitureGrid.new()
	g5.setup(HomeData.room(5), items)
	tm.free()
	var rej := g5.load_save(save)
	t.check("save/load roundtrip keeps every placement", g5.placements.size() == g.placements.size() and rej.is_empty(), "rejected: " + str(rej))

func _ownership(t) -> void:
	var fm: Node = t.autoload("FurnitureManager")
	var home: Node = t.autoload("HomeManager")
	var eco: Node = t.autoload("EconomyManager")
	var original: Dictionary = fm.to_dict()
	var tier: int = home.tier
	t.check("catalogue_content_matches_all_painted_footprints", FurnitureCatalog.mismatches().is_empty(), str(FurnitureCatalog.mismatches()))
	t.check("registered_save_section", t.autoload("SaveManager").has_section("furniture"))
	fm.reset()
	t.check("starter_bed_and_chest_reachable", fm.count_placed("bed_birch_single") == 1 and fm.count_placed("chest_pine") == 1)
	t.check("starter_stock", fm.count_stock("chair_pine") == 2 and fm.count_stock("rug_runner_natural") == 1)
	t.check("placed_cannot_be_sold", not fm.remove("bed_birch_single") and not eco.remove_item(&"bed_birch_single"))
	fm.from_dict({"stock":{},"placed":[]})
	t.check("invalid_items_rejected", not fm.add("hoe_wooden") and not fm.add("nothing") and not fm.add("chair_pine", 0))
	t.check("ordinary_stack_cap", fm.add("chair_pine", 9) and not fm.add("chair_pine") and not fm.remove("chair_pine", 10))
	var result: Dictionary = fm.place_from_stock("chair_pine", Vector2i(0, 0), 0)
	t.check("placement_moves_stock_to_grid", result.ok and fm.count_stock("chair_pine") == 8 and fm.count_total("chair_pine") == 9)
	t.check("placed_copies_count_toward_cap", not fm.can_add("chair_pine", 1))
	var snapshot: Dictionary = fm.to_dict()
	t.check("failed_placement_atomic", not fm.place_from_stock("chair_pine", fm.grid.door_cell, 0).ok and snapshot == fm.to_dict())
	fm.pickup(result.uid)
	t.check("pickup_conserves_ownership", fm.count_stock("chair_pine") == 9 and fm.count_placed("chair_pine") == 0)
	t.check("unique_cap", fm.add("throne_root") and not fm.add("throne_root"))
	fm.from_dict({"stock":{"table_dining_oak":1,"vase_clay":1},"placed":[]})
	var table: Dictionary = fm.place_from_stock("table_dining_oak", Vector2i(0, 0), 0)
	var vase: Dictionary = fm.place_from_stock("vase_clay", Vector2i(0, 0), 0)
	t.check("table_and_vase_placed", table.ok and vase.ok)
	fm.pickup(table.uid)
	t.check("pickup_returns_host_and_tabletop", fm.count_stock("vase_clay") == 1 and fm.count_stock("table_dining_oak") == 1 and fm.grid.placements.is_empty())
	var wire: Dictionary = JSON.parse_string(JSON.stringify(fm.to_dict()))
	t.check("json_roundtrip", fm.from_dict(wire) and JSON.parse_string(JSON.stringify(fm.to_dict())) == wire)
	snapshot = fm.to_dict()
	t.check("bad_section_atomic", not fm.from_dict({"v":8}) and fm.to_dict() == snapshot and not fm.from_dict({"stock":[]}))
	fm.from_dict({"placed":[{"item":"chair_pine","cell":[999,999],"rot":0},{"item":"chest_pine","cell":"bad"}]})
	t.check("rejected_saved_placements_return_to_stock", fm.count_stock("chair_pine") == 1 and fm.count_stock("chest_pine") == 1 and fm.grid.placements.is_empty())
	fm.from_dict({"stock":{"throne_root":1},"placed":[{"item":"throne_root","cell":[0,0],"rot":0}]})
	t.check("loaded_unique_never_duplicates", fm.count_total("throne_root") == 1)
	for current in range(1, 11):
		home.tier = current
		fm.from_dict({"stock":{},"placed":[]})
		for id in ["chair_pine","chest_pine","table_round_pine","floor_lamp_iron","rug_natural","plant_fern","painting_small_pine"]:
			fm.add(id)
			AutoFurnish.place_any(id)
		var owned: Dictionary = {}
		for id in fm.owned_ids():
			owned[id] = fm.count_total(id)
		if current < 10:
			home.tier += 1
			fm.rebuild_for_tier()
		var conserved := true
		for id in owned:
			conserved = conserved and fm.count_total(id) == owned[id]
		t.check("upgrade_%d_conserves_every_piece" % current, conserved)
		t.check("tier_%d_all_interactions_reachable" % current, _reachable(fm.grid))
		t.check("tier_%d_capacity_counts_all_layers" % current, fm.grid.max_items == home.furniture_capacity())
		var score := 0
		for p in fm.grid.placements.values():
			score += LuaData.int_of(ItemKinds.def(p.item_id).get("decor", 0))
		t.check("tier_%d_hygge_is_placed_decor" % current, fm.hygge_score() == score)
	var saved_cells: Array = fm.to_dict().placed
	t.check("save_uses_arrays_without_runtime_uids", saved_cells.all(func(p): return p.cell is Array and not p.has("uid")))
	home.tier = tier
	fm.from_dict(original)

func _reachable(grid: FurnitureGrid) -> bool:
	var seen := grid.reachable()
	if not seen.has(grid.spawn_cell):
		return false
	for p in grid.placements.values():
		var fronts := grid.front_cells(p.item_id, p.cell, p.rot)
		if p.layer == "floor" and not fronts.is_empty() and not fronts.any(func(c): return seen.has(c)):
			return false
	return true
