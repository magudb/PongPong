extends RefCounted
const SECTION := "farm_site"
const TIMEOUT_S := 180.0
var world: WorldRoot2D

func run_windowed(t) -> void:
	await t.start_world()
	world = t.world()
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
	t.autoload("TimeManager").set_weather(&"klart")
	world.day_night.override_hour = 10
	world.day_night.snap()
	t.player()._set_zoom(0.2)
	t.player().camera.reset_smoothing()
	await t.frames(20)
	await t.capture("overview")
	var expansion: FieldExpansion2D = _marker("field_expansion")
	var cells: Array = []
	for draw in expansion._ropes:
		var art := ArtCatalog.prop(StringName(draw.name))
		for i in draw.multimesh.instance_count:
			var origin: Vector2 = draw.multimesh.get_instance_transform_2d(i).origin + art.pivot - draw.texture.get_size() * 0.5
			cells.append(world.area.global_to_cell(world.area.objects.to_global(origin)))
	t.check("native_rope_transforms", cells.size() == 22 and Vector2i(45, 30) in cells and cells.all(func(cell): return cell in expansion.cells and (cell.x in [40, 45] or cell.y in [24, 30])), str(cells))
	t.player().global_position = world.area.cell_to_global(Vector2i(43, 28))
	t.player()._set_zoom(0.4)
	t.player().camera.reset_smoothing()
	await t.frames(10)
	await t.capture("east_locked")
	t.autoload("EconomyManager").gold = 1250
	expansion.interact(t.player())
	await t.frames(4)
	await t.capture("expansion_confirm")
	var confirm := expansion.find_child("UiConfirm", true, false)
	var panel: Control = confirm.get_node("%Panel")
	t.check("world_confirm_in_screen_space", panel.get_global_rect().position.x >= 0 and panel.get_global_rect().end.x <= 1280 and panel.get_global_rect().end.y <= 720, str(panel.get_global_rect()))
	UiAudit.expect(t, await UiAudit.ring_pixels(t, confirm.get_node("%CancelButton"), {"focus": false, "shot": "expansion_cancel_focus"}), "expansion_cancel_native_ring")
	confirm.get_node("%OkButton").pressed.emit()
	await t.frames(4)
	for cell in expansion.cells.slice(0, 6):
		world.farm.till(cell)
	await t.frames(4)
	await t.capture("east_unlocked_tilled")
	t.check("native_purchase", t.autoload("EconomyManager").gold == 450 and expansion._ropes.is_empty())
	world.day_night.override_hour = 24
	world.day_night.snap()
	await t.frames(5)
	await t.capture("night")
	var fx: FarmAmbientFx = _marker("ambient_fx")
	t.check("night_canopy_tint", fx.canopy.modulate == world.day_night.color and fx.canopy.modulate != Color.WHITE)
	t.autoload("GameManager").clear_config_overrides()

func run(t) -> void:
	await t.start_world()
	world = t.world()
	await t.frames(4)
	for type in ["shipping_bin", "tool_shed", "field_expansion", "ambient_fx", "underdeck"]:
		t.check("handler_" + type, world.area.handled_count(type) == world.area.find_markers(type).size() and world.area.handled_count(type) > 0)
	var added := 1 # world-lifetime FarmStage
	for type in ["shipping_bin", "tool_shed", "field_expansion", "ambient_fx", "underdeck"]:
		for marker in world.area.find_markers(type):
			added += _nodes(marker.node)
	for type in ["shipping_bin", "tool_shed"]:
		for part in world.area.prop_parts(_marker(type).prop_node):
			added += _nodes(part)
	var expansion: FieldExpansion2D = _marker("field_expansion")
	for part in world.area.prop_parts(expansion._stake):
		added += _nodes(part)
	for draw in expansion._ropes:
		added += _nodes(draw)
	t.check("all_handler_nodes_budget", added < 40, "%d nodes including props, colliders and world coordinator" % added)
	await _bin(t)
	await _expansion(t)
	_reserves_and_stage(t)
	await _scenery(t)
	await _save(t)
	await _lifetime(t)

func _nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children(true):
		count += _nodes(child)
	return count

func _lifetime(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var previous: StringName = gm.season
	gm.season = &"efteraar"
	EventBus.season_changed.emit(gm.season)
	await t.frames(2)
	for cap in [0, 80]:
		gm.set_config_override("farm_site.fx.leaves_max", cap)
		var temporary := FarmAmbientFx.new()
		world.area.add_child(temporary)
		t.check("particle_cap_" + str(cap), temporary.leaves.amount == (1 if cap == 0 else 16) and temporary.leaves.emitting == (cap > 0))
		temporary.queue_free()
		await t.frames(2)
	gm.clear_config_overrides()
	gm.season = previous
	EventBus.season_changed.emit(gm.season)
	await t.frames(2)
	var fx: FarmAmbientFx = _marker("ambient_fx")
	var canopy: WeakRef = weakref(fx.canopy)
	var leaves: WeakRef = weakref(fx.leaves)
	var old_world := world
	old_world.queue_free()
	await t.frames(3)
	t.check("scenery_freed_with_area", canopy.get_ref() == null and leaves.get_ref() == null)

func _marker(type: String) -> Node:
	return world.area.find_markers(type)[0].node

func _bin(t) -> void:
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	var bin := _marker("shipping_bin")
	var player: Node = t.player()
	var item := &"carrot"
	eco.add_item(item, 7, true)
	player.hotbar.assign(0, item)
	player.hotbar.select(0)
	var count: int = eco.count_item(item)
	var observed: Array = []
	var inspect := func(_player_id: StringName, _inventory):
		observed.append(eco.count_item(item) == 0 and int(world.get_area_flag(&"farm", "bin_carrot", 0)) == count)
		bin.interact(player)
	bus.player_inventory_changed.connect(inspect)
	bin.interact(player)
	bus.player_inventory_changed.disconnect(inspect)
	t.check("bin_ships_whole_stack_before_observers", observed == [true] and eco.count_item(item) == 0 and int(world.get_area_flag(&"farm", "bin_carrot", 0)) == count)
	player.hotbar.assign(0, &"hoe_wooden")
	var hoe: int = eco.count_item(&"hoe_wooden")
	bin.interact(player)
	t.check("bin_refuses_tools", eco.count_item(&"hoe_wooden") == hoe and world.get_area_flag(&"farm", "bin_hoe_wooden", 0) == 0)
	var price: int = eco.sell_value(item)
	t.check("bin_never_beats_seed_shop", price <= t.autoload("ShopSystem").get_sell_price(&"seed_shop", item))
	var gold: int = eco.gold
	await world.travel(&"traetoppen", &"from_farm")
	await t.frames(3)
	t.check("farm_is_parked", world.area.map.id == &"traetoppen" and not bin.is_inside_tree())
	var before: int = t.autoload("GameManager").day
	t.autoload("GameManager").end_day()
	await t.frames(3)
	t.check("bin_pays_while_away", eco.gold == gold + price * count and world.get_area_flag(&"farm", "bin_carrot", 0) == 0 and t.autoload("GameManager").day == before + 1)
	gold = eco.gold
	bus.day_started.emit(t.autoload("GameManager").day, t.autoload("GameManager").season)
	t.check("bin_pays_exactly_once", eco.gold == gold)
	await world.travel(&"farm", &"from_traetoppen")
	await t.frames(3)
	t.check("parked_farm_reuses_bin", _marker("shipping_bin") == bin)
	var requests: Array = []
	var listener := func(event, _data):
		if event == &"open_home_chest":
			requests.append(event)
	bus.game_event.connect(listener)
	_marker("tool_shed").interact(player)
	bus.game_event.disconnect(listener)
	t.check("shed_requests_home_chest", requests == [&"open_home_chest"] and int(t.autoload("GameManager").get_flag(&"shed_explained", 0)) == 1)
	var chest: Node = world.game_ui.get_screen(&"home_chest")
	if chest!=null and chest.is_open():chest.close()
	await t.frames(2)

func _expansion(t) -> void:
	var expansion: FieldExpansion2D = _marker("field_expansion")
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	t.check("expansion_matches_data", expansion.price == 800 and expansion.cells.size() == 42 and expansion.price == int(gm.config_value("farm_site.expansions.east.price")))
	t.check("locked_cells_are_not_farmable", expansion.cells.all(func(cell): return not world.farm.can_till(cell)))
	var ring_cells: Array = []
	for draw in expansion._ropes:
		# Dummy rendering does not retain MultiMesh transforms. Native tests below
		# verify the actual rendered transforms; this gate proves boundary geometry.
		ring_cells.append_array(draw.get_meta("farm_rope_cells"))
	t.check("rope_ring_uses_real_outer_boundary", ring_cells.size() == 22 and Vector2i(45, 30) in ring_cells and ring_cells.all(func(cell): return cell.x in [40, 45] or cell.y in [24, 30]), str(ring_cells))
	eco.gold = 1000
	expansion.interact(t.player())
	await t.frames(3)
	var confirm := expansion.find_child("UiConfirm", true, false)
	t.check("confirmation_default_cancel", confirm != null and confirm.get_viewport().gui_get_focus_owner() == confirm.get_node("%CancelButton") and gm.top_modal() == &"confirm")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("cancel_preserves_zone_and_money", eco.gold == 1000 and not bool(world.get_area_flag(&"farm", "zone_east", false)) and expansion.is_enabled())
	eco.gold = 799
	expansion.interact(t.player())
	await t.frames(3)
	confirm = expansion.find_child("UiConfirm", true, false)
	confirm.get_node("%OkButton").pressed.emit()
	await t.frames(3)
	t.check("poor_purchase_changes_nothing", eco.gold == 799 and not bool(world.get_area_flag(&"farm", "zone_east", false)) and expansion._ropes.size() == 2)
	eco.gold = 1000
	var observed: Array = []
	var inspect := func(_cell):
		observed.append(eco.gold == 200 and bool(world.get_area_flag(&"farm", "zone_east", false)) and expansion.cells.all(func(cell): return world.farm.can_till(cell) and world.area.map.ground_at(cell) == "f"))
		# A synchronous observer cannot purchase the same zone a second time.
		expansion.interact(t.player())
	world.farm.plot_changed.connect(inspect)
	expansion.interact(t.player())
	await t.frames(3)
	confirm = expansion.find_child("UiConfirm", true, false)
	confirm.get_node("%OkButton").pressed.emit()
	await t.frames(4)
	world.farm.plot_changed.disconnect(inspect)
	t.check("unlock_commits_all_cells_before_observers", observed.size() == 42 and observed.all(func(complete): return complete) and eco.gold == 200)
	t.check("unlock_removes_ring_and_stake", expansion._ropes.is_empty() and expansion._stake == null and not expansion.is_enabled() and gm.top_modal() == &"")
	var cell: Vector2i = expansion.cells[0]
	t.check("purchased_plot_can_be_farmed", world.farm.till(cell))
	await world.travel(&"traetoppen", &"from_farm")
	await world.travel(&"farm", &"from_traetoppen")
	await t.frames(4)
	t.check("reenter_preserves_unlocked_soil", world.farm.can_till(cell) and world.farm.state_of(cell) == FarmGrid.State.TILLED and world.area.cell_kind(cell) == _soil_of(cell) and not expansion.is_enabled(), "state %s terrain %s, cell %s" % [world.farm.state_of(cell), world.area.cell_kind(cell), cell])

func _reserves_and_stage(t) -> void:
	var area := world.area
	var door: Vector2i = area.find_markers("home")[0].cell
	var home := true
	for y in range(door.y - 5, door.y + 1):
		for x in range(door.x - 4, door.x + 5):
			home = home and FarmReserve.blocked(area, Vector2i(x, y)) == "home"
	t.check("reserve_matches_tier_ten_map_footprint", home)
	for marker in area.find_markers("building_slot"):
		t.check("slot_" + str(marker.params.type), FarmReserve.blocked(area, marker.cell) == "slot")
	t.check("greenhouse_reserved", FarmReserve.blocked(area, area.find_markers("greenhouse_slot")[0].cell) == "slot")
	t.check("fields_reserved_against_buildings_but_tillable", world.farm.farmable_cells().all(func(cell): return FarmReserve.blocked(area, cell) in ["field", "zone"] and world.farm.can_till(cell)))
	for tier in range(1, 11):
		var stage := FarmStage.of_tier(tier)
		t.check("stage_tier_" + str(tier), stage.index == [1, 1, 2, 2, 3, 3, 3, 4, 4, 5][tier - 1] and stage.rows == [0, 0, 0, 0, 1, 1, 1, 2, 2, 3][tier - 1])
	var service: Node = world.get_node("FarmSteading")
	var hm: Node = t.autoload("HomeManager")
	var old_tier: int = hm.tier
	var notes: Array = []
	var listener := func(title, _body, _icon):
		if title == tr("FARMSITE_STAGE_UP_TITLE"):
			notes.append(title)
	t.autoload("EventBus").notification_posted.connect(listener)
	hm.tier = 3
	service._refresh(true)
	service._refresh(true)
	t.check("stage_toast_only_on_rise", notes.size() == 1 and int(t.autoload("GameManager").get_flag(&"farm_stage", 0)) == 2)
	hm.tier = 8
	service._refresh(false)
	t.check("load_stage_has_no_toast", notes.size() == 1)
	hm.tier = old_tier
	service._refresh(false)
	t.autoload("EventBus").notification_posted.disconnect(listener)

func _scenery(t) -> void:
	for marker in world.area.find_markers("underdeck"):
		var node: Node2D = marker.node
		t.check("underdeck_" + str(marker.cell), node.get_parent() == world.area and node.z_index == -11)
	var fx: FarmAmbientFx = _marker("ambient_fx")
	t.check("bounded_painted_fx", fx.leaves.amount <= int({"foraar":20,"sommer":14,"efteraar":16,"vinter":40}.get(str(GameManager.season),16)) and fx.canopy.texture.resource_path == "res://assets/backdrops/farm_canopy.webp")
	world.day_night.override_hour = 24
	world.day_night.snap()
	await t.frames(3)
	t.check("canopy_follows_night_colour", fx.canopy.modulate == world.day_night.color and fx.canopy.modulate != Color.WHITE)
	var leaf_tint: Color = Color.WHITE if fx.leaves.material != null else world.day_night.color
	t.check("falling_leaves_follow_night_colour", fx.leaves.modulate == leaf_tint and (fx.leaves.material != null or fx.leaves.modulate != Color.WHITE),
		"the LeafFx layer (CanvasLayer 4) copies the night colour %s (fireflies, additive light, stay white): %s" % [world.day_night.color, fx.leaves.modulate])
	world.day_night.override_hour = -1
	var ms: float = t.median_usec(func() -> void: fx._process(1.0 / 60), 20, 500) / 1000.0
	t.check("handler_frame_budget", t.perf_ok("handler_frame_budget", ms, 0.3), "%s ms per ambient update, median of 20 batches of 500 (native reference 0.3)" % ms)

func _save(t) -> void:
	var eco: Node = t.autoload("EconomyManager")
	eco.add_item(&"carrot", 3, true)
	t.player().hotbar.assign(0, &"carrot")
	t.player().hotbar.select(0)
	_marker("shipping_bin").interact(t.player())
	var amount: int = world.get_area_flag(&"farm", "bin_carrot", 0)
	var sm: Node = t.autoload("SaveManager")
	var directory: String = sm.save_dir
	sm.save_dir = "user://farm-site-roundtrip"
	t.expect(sm.save_game(0), "Save bin and purchased field")
	t.expect(sm.load_and_enter(0), "Load farm with real world entry")
	await t.until(func(): return t.world() != world and t.player() != null, 10)
	world = t.world()
	await t.frames(6)
	t.check("bin_survives_save_load", int(world.get_area_flag(&"farm", "bin_carrot", 0)) == amount)
	var expansion: FieldExpansion2D = _marker("field_expansion")
	t.check("expansion_survives_save_load", not expansion.is_enabled() and expansion._ropes.is_empty() and expansion.cells.all(func(cell): return world.farm.can_till(cell)))
	t.check("soil_survives_zone_replay", world.farm.state_of(expansion.cells[0]) == FarmGrid.State.TILLED and world.area.cell_kind(expansion.cells[0]) == _soil_of(expansion.cells[0]), "state %s terrain %s" % [world.farm.state_of(expansion.cells[0]), world.area.cell_kind(expansion.cells[0])])
	sm.save_dir = directory

func _soil_of(cell: Vector2i) -> StringName:
	return &"soil_watered" if world.farm.get_plot(cell).watered else &"soil_tilled"
