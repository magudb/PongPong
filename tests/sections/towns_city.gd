extends RefCounted
const SECTION := "towns_city"
const TIMEOUT_S := 180.0

func _director(t) -> TownDirector:
	return t.world().area.get_node("TownDirector") as TownDirector

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.set_config_override("towns.hours_enabled", false)
	gm.day = 2
	gm.hour = 12
	await t.world().travel(&"traetoppen", &"default")
	var director := _director(t)
	t.check("real_city_populated_at_noon", director.ready_for_population and not director.live.is_empty())
	var doors: Array = []
	for door in t.world().area.triggers.get_children():
		if door is Door2D:
			doors.append(door.building_id)
			var resolved := RouteTable.position_of("traetoppen.door_" + door.building_id)
			t.check("door_approach_" + door.building_id, resolved != Vector2.INF and door.position == Iso.to_screen(resolved) and t.world().area.spawns.has("from_int_" + door.building_id))
	t.check("sidecar_doors_complete", doors.size() == director.col.doors.size())
	var shops := {}
	var talks := {}
	for host in t.world().area.objects.get_children():
		if host is ShopCounter:
			if host.kind == "shop":
				shops[host.shop_id] = int(shops.get(host.shop_id, 0)) + 1
			elif host.kind == "talk":
				talks[host.shop_id] = int(talks.get(host.shop_id, 0)) + 1
	for id in ["timber_yard", "natteblik_maps"]:
		t.check("stall_shop_and_two_talk_hosts_" + id, shops.get(id) == 1 and talks.get(id) == 2 and not t.autoload("LuaRuntime").get_shop(id).is_empty())
	await _stall_talk_follows_keeper(t, director)
	for building in doors:
		var room := str(Hours.building(building).get("interior", ""))
		if room == "" or not t.world().has_area(StringName(room)):
			continue
		var door := t.world().area.triggers.get_node_or_null("Door_" + building) as Door2D
		t.check("live_door_"+building,door!=null)
		if door==null:continue
		var owner := str(Hours.building(building).get("owner",""))
		if owner!="" and not Hours.building(building).has("hours"):
			SocialManager.debug_set_hearts(owner,1)
			var available := false
			for quarter in range(24,104):
				var ctx := Routines.now_ctx()
				ctx.hour = quarter/4.0
				var place := Routines.where_is(owner,ctx)
				if str(place.get("place","")).begins_with(room+".") and str(place.get("act",""))!="sleep":
					gm.hour = quarter/4
					gm.minute = (quarter%4)*15
					EventBus.time_of_day_changed.emit(gm.hour,gm.minute)
					available = true
					break
			if not available:
				t.check("absent_or_sleeping_owner_keeps_home_closed_"+building,not door.is_open())
				continue
			await t.frames(3)
		door._on_body_entered(t.player())
		var arrived: bool = await t.until(func(): return not t.world().traveling and str(t.world().area.map.id) == room,8)
		t.check("door_enters_" + building,arrived)
		if not arrived:continue
		var exit: Warp2D
		for node in t.world().area.triggers.get_children():
			if node is Warp2D:
				exit = node
				break
		if exit != null:
			exit._on_body_entered(t.player())
			await t.until(func(): return not t.world().traveling and t.world().area.map.id == &"traetoppen", 8)
			# Private-home arrivals can depenetrate a few pixels at the door.
			# Stay within one foot radius and require walkable feet on the actual deck.
			t.check("door_returns_" + building, t.world().area.map.id == &"traetoppen" and Iso.ground_dist(t.player().global_position,t.world().area.get_spawn("from_int_" + building)) <= 25 and t.world().area.walkable_test.is_valid() and t.world().area.walkable_test.call(t.player().global_position),str([t.world().area.map.id,t.player().global_position,t.world().area.get_spawn("from_int_"+building)]))
	# Actual arrival discovers the first signpost; destinations require discovery.
	var signs: Array = []
	for node in t.world().area.objects.get_children():
		if node is Rejsestolpe2D:
			signs.append(node)
	t.check("four_fast_travel_stops_installed", signs.size() == 4)
	for signpost in signs:
		t.player().global_position = signpost.global_position
		signpost._process(0)
		t.check("fast_travel_unlock_" + signpost.stop, gm.flag_int(StringName("ft_" + signpost.stop)) == 1)
	var signpost: Rejsestolpe2D = signs[0]
	signpost.interact(t.player())
	var dialogue: Control = t.tree.get_first_node_in_group("dialogue_ui")
	await t.page_to_choices(dialogue)
	t.check("fast_travel_lists_discovered_stops", dialogue._buttons.size() == 4)
	dialogue._buttons[0].pressed.emit()
	await t.until(func(): return not t.world().traveling, 8)
	t.check("fast_travel_rebuilds_safely", not gm.is_modal_open() and t.world().area.map.id == &"traetoppen")
	gm.hour = 21
	gm.minute = 0
	t.autoload("EventBus").time_of_day_changed.emit(21, 0)
	await t.physics(2)
	var owl: Npc2D = NpcDirector.node_of("appraiser_fru_ugle")
	t.check("owl_window_pose_and_safe_body", owl != null and owl.visual.position != Vector2.ZERO and owl.visual.z_index == 176 and not owl.visual.shadow.visible)
	if owl != null:
		t.check("owl_window_retains_authored_reach", owl._interaction_reach == 420)
		t.player().global_position = owl.global_position + Vector2(80, 40)
		t.tap(&"interact")
		await t.frames(3)
		t.check("real_interact_reaches_window_owl", owl.is_talking and dialogue.is_open())
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
	gm.clear_config_overrides()

func run_windowed(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.day = 2
	gm.hour = 12
	gm.minute = 0
	t.autoload("EventBus").day_started.emit(gm.day, gm.season)
	t.autoload("TimeManager").set_weather(&"klart")
	t.autoload("EventBus").time_of_day_changed.emit(12, 0)
	await t.world().travel(&"traetoppen", &"default")
	var director := _director(t)
	var route_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/towns/routes.json"))
	var inspect_anchors: Array = ["door_postkontoret", "e_bat_window", "door_badehuset"]
	for shift in route_data.areas.traetoppen.snaps:
		if float(shift.distance) > 64 and str(shift.name) not in inspect_anchors:
			inspect_anchors.append(str(shift.name))
	for anchor in inspect_anchors:
		var ground := director.post_ground(StringName(anchor))
		t.check("native_approach_" + anchor, ground != Vector2.INF)
		if ground == Vector2.INF:
			continue
		t.player().global_position = director.area.to_global(Iso.to_screen(ground)) + Vector2(0, 75)
		t.player().camera.reset_smoothing()
		await t.world().warm_clips()
		await t.frames(6)
		t.tree.get_first_node_in_group("game_ui").get_screen(&"hud").toasts.clear()
		await t.frames(2)
		await t.capture(anchor)
	gm.hour = 21
	gm.minute = 0
	t.autoload("EventBus").time_of_day_changed.emit(21, 0)
	director.resync()
	var owl: Npc2D = director.node_of("appraiser_fru_ugle")
	t.check("window_owl_has_live_safe_body", owl != null and owl.visual.z_index == 176 and not owl.visual.shadow.visible)
	if owl != null:
		t.player().global_position = owl.global_position + Vector2(0, 75)
		t.player().camera.reset_smoothing()
		await t.world().warm_clips()
		await t.frames(5)
		await t.capture("owl_window_2100")
	gm.hour = 12
	gm.minute = 0
	t.autoload("EventBus").time_of_day_changed.emit(12, 0)
	# A real room, keeper and real Lua shop panel share one native capture.
	await t.world().travel(&"int_froebutikken", &"default")
	await t.frames(6)
	var keeper := NpcDirector.node_of("merchant_pip")
	t.check("native_keeper_behind_counter", keeper != null)
	await t.capture("seed_shop_room")
	var shop: Node = t.autoload("ShopSystem")
	shop.open_shop(&"seed_shop")
	await t.frames(6)
	await t.capture("seed_shop_panel")
	t.check("native_shop_over_live_room", gm.top_modal() == &"shop" and keeper != null)
	t.tree.get_first_node_in_group("game_ui").get_screen(&"shop_ui").close()
	gm.clear_config_overrides()


## SIM-03: the open city is one "room", so a stall's talk hosts also need the keeper AT the stall: on a weekday at 16:30 Brumme sits on a
## bench across town and his stall must not offer "Tal med Brumme"; at a weekend noon he keeps the stall and it does.
func _stall_talk_follows_keeper(t, director: TownDirector) -> void:
	var gm: Node = t.autoload("GameManager")
	var tm: Node = t.autoload("TimeManager")
	var hosts: Array = t.world().area.objects.get_children().filter(func(n: Node) -> bool: return n is ShopCounter and n.kind == "talk" and n.shop_id == "timber_yard")
	var weekday := -1
	var weekend := -1
	for day in range(1, 8):
		var index: int = tm.weekday_index(day)
		if index in [5, 6] and weekend == -1:
			weekend = day
		elif index in [0, 1, 2, 3] and weekday == -1:
			weekday = day
	var keep: Array = [gm.day, gm.hour, gm.minute]
	var seen := {}
	for moment in [[weekday, 16, 30, "weekday"], [weekend, 12, 0, "weekend"]]:
		gm.day = moment[0]
		gm.hour = moment[1]
		gm.minute = moment[2]
		EventBus.time_of_day_changed.emit(gm.hour, gm.minute)
		await t.physics(30)
		var brumme: Node2D = director.node_of("carpenter_brumme")
		for host in hosts:
			host._refresh()
		seen[moment[3]] = [brumme != null, hosts.all(func(h: ShopCounter) -> bool: return h.is_enabled()), hosts.any(func(h: ShopCounter) -> bool: return h.is_enabled())]
	t.check("stall_talk_hosts_follow_keeper_to_the_stall", hosts.size() == 2 and seen.weekday == [true, false, false] and seen.weekend == [true, true, true], str(seen))
	gm.day = keep[0]
	gm.hour = keep[1]
	gm.minute = keep[2]
	EventBus.time_of_day_changed.emit(gm.hour, gm.minute)
	await t.physics(3)
