extends RefCounted
## All installed CORE rooms, using the real collision geometry and player query.
const SECTION := "towns_interiors_core"
const TIMEOUT_S := 240.0
const Probe := preload("res://tests/lib/towns/room_probe.gd")
const Keeper := preload("res://tests/lib/towns/keeper_stub.gd")

func room_ids() -> Array[String]:
	var ids: Array[String] = []
	for file in DirAccess.get_files_at("res://data/interiors/core"):
		if file.ends_with(".json") and file.begins_with("int_"):
			ids.append(file.trim_suffix(".json"))
	ids.sort()
	return ids

func run(t) -> void:
	await t.start_world()
	var world: Node = t.world()
	var player: Node2D = world.player
	var original_area: IsoArea = player.get("area")
	var original_pos := player.global_position
	var processing := player.is_physics_processing()
	player.set_physics_process(false)
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("towns.hours_enabled", false)
	var lr: Node = t.autoload("LuaRuntime")
	var loc: Node = t.autoload("LocalizationManager")
	var ids := room_ids()
	t.check("json_schema_14", ids.size() >= 14)
	var notes: Array = []
	for id in ids:
		var p := Probe.new()
		var spec := InteriorRoom.load_spec(id)
		var source := FileAccess.get_file_as_string("res://data/maps/" + id + ".map")
		var map := AreaMap.parse_text(source)
		t.expect(map.projection == &"iso" and source.contains("@ambient home") and source.contains("@room " + id), id + " is an iso room with its installed builder")
		var zone := "city" if str(spec.exit.area) == "hyggebyen" else "traetoppen"
		t.expect(source.contains("@zone " + zone) and loc.has_key("BLD_" + str(spec.building).to_upper()), id + " has a translated title and outer zone")
		var area: IsoArea = await p.build(t, id, zone)
		t.expect(area != null and not spec.is_empty(), id + " builds its installed spec")
		if area == null:
			p.dispose()
			continue
		var stats := InteriorRoom.stats.duplicate(true)
		var start := Vector2i(int(spec.spawn_cell[0]), int(spec.spawn_cell[1]))
		var reached: Dictionary = p.reach(Iso.MASK_WALKING, start)
		var keeper_cell := Vector2i.ZERO
		var customers_ok := true
		for post in spec.posts:
			var cell := Vector2i(int(post.cell[0]), int(post.cell[1]))
			if post.get("kind") == "keeper":
				keeper_cell = cell
			if post.get("kind") == "customer":
				customers_ok = customers_ok and reached.has(cell)
		t.expect(customers_ok and not reached.has(keeper_cell), id + " customers reach their posts while the keeper stays behind the counter")
		var has_exit := false
		for child in area.triggers.get_children():
			if child is Door2D:
				has_exit = has_exit or child.always_open
		t.expect(has_exit, id + " always permits leaving the room")
		var keeper := Keeper.new()
		area.objects.add_child(keeper)
		keeper.global_position = p.cell_global(keeper_cell.x, keeper_cell.y)
		ShopCounter.keeper_resolver = func(_npc: String) -> Node: return keeper
		var talks: Array = []
		var centres: Array = []
		for child in area.objects.get_children():
			if child is ShopCounter:
				if child.kind == "talk":
					child._refresh()
					talks.append(child)
				elif child.kind != "desk":
					centres.append(child)
		var shops_valid := true
		for marker in spec.markers:
			if marker.type == "shop":
				var shop: Dictionary = lr.get_shop(str(marker.id))
				shops_valid = shops_valid and not shop.is_empty() and shop.get("keeper") == marker.get("keeper")
		t.expect(shops_valid and talks.size() == 2, id + " wires its shop/service and both keeper conversations")
		player.call("enter_area", area, p.cell_global(start.x, start.y))
		player.set("facing8", 5)
		await t.physics(1)
		var selected := 0
		var chosen: Array = []
		for column in [keeper_cell.x - 1, keeper_cell.x + 1]:
			player.global_position = p.cell_global(column, 3)
			var host: Node = player.call("nearest_interactable")
			chosen.append([str(host), player.get("state"), player.global_position])
			if host is ShopCounter and host.kind == "talk":
				host.interact(player)
				selected += 1
		t.expect(selected == 2 and keeper.interactions.size() == 2, id + " real player reaches the keeper from both counter ends " + str(chosen))
		player.global_position = p.cell_global(keeper_cell.x, 3)
		var centre: Node = player.call("nearest_interactable")
		t.expect(centre != null and not (centre is ShopCounter and centre.kind == "talk"), id + " centre selects the service rather than the talk hosts")
		# Median of repeated builds is the warm-room gate, not first texture decode.
		var times: Array[float] = []
		for repeat in 3:
			var other := Probe.new()
			await other.build(t, id, zone)
			times.append(other.build_ms)
			other.dispose()
		times.sort()
		t.expect(t.perf_ok("warm_build_" + id, times[1], 12.0), id + " warm build median %.2f ms of %s (native reference 12, runner limit %.0f)" % [times[1], str(times), t.perf_limit(12.0)])
		t.expect(int(stats.nodes) <= 130 and int(stats.lights) <= 4, id + " node/light budgets: " + str(stats))
		notes.append({"id": id, "warm_ms": times[1], "nodes": stats.nodes, "lights": stats.lights})
		ShopCounter.keeper_resolver = Callable()
		player.call("enter_area", original_area, original_pos)
		p.dispose()
	player.set_physics_process(processing)
	gm.clear_config_overrides()
	var validation: Dictionary = t.run_tool("python3", ["-B", "-I", ProjectSettings.globalize_path("res://tools/towns/interiors/validate.py"), ProjectSettings.globalize_path("res://data/interiors/core")])
	t.check("validator_all_core_rooms", validation.code == 0, validation.output)
	var f := FileAccess.open("user://core_room_budgets.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(notes, "  "))
	f.close()

func run_windowed(t) -> void:
	await t.start_world()
	var world: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.hour = 12
	gm.minute = 0
	for id in room_ids():
		# Select hours through real daily/time signals while safely on the farm.
		# A previous room may otherwise evict mid-search, and old daily flags or
		# rain shelters can disagree with the keeper's displayed clock.
		await world.travel(&"farm",&"from_home")
		var spec := InteriorRoom.load_spec(id)
		var keeper_id := ""
		for marker in spec.markers:
			if str(marker.get("type", "")) == "talk":
				keeper_id = str(marker.get("keeper", ""))
		var found := false
		for day in range(8,15):
			gm.day=day
			t.autoload("EventBus").day_started.emit(gm.day,gm.season)
			t.autoload("TimeManager").set_weather(&"klart")
			for hour in range(8,23):
				gm.hour=hour
				gm.minute=0
				t.autoload("EventBus").time_of_day_changed.emit(hour,0)
				var ctx := Routines.now_ctx()
				var where := Routines.where_is(keeper_id,ctx)
				if str(where.area)==id and str(where.state)=="stay" and str(where.act) not in ["sleep","inside"] and bool(Hours.state(str(spec.building),ctx).get("open",true)):
					found=true
					break
			if found:break
		t.expect(found, "Open staffed hours exist in " + id)
		world.travel(StringName(id), &"default")
		var arrived: bool = await t.until(func() -> bool: return not world.traveling and str(world.area.map.id) == id, 10.0)
		t.expect(arrived,"Travel enters the painted room " + id)
		if not arrived:continue
		t.autoload("EventBus").time_of_day_changed.emit(gm.hour, gm.minute)
		t.autoload("TimeManager").set_weather(&"klart")
		await t.frames(4)
		var image: Image = await t.capture("core_" + id)
		t.expect_not_blank(image, Rect2i(0, 0, 1280, 720), "Painted room: " + id)
		var keeper_present := false
		for child in world.area.objects.get_children():
			if child is ShopCounter and child.kind == "talk":
				keeper_present = keeper_present or child.keeper_node() != null
		t.expect(keeper_present, "Live keeper in " + id)
	gm.clear_config_overrides()
