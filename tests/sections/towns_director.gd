extends RefCounted
const SECTION := "towns_director"
const TIMEOUT_S := 240.0
class FestivalFixture extends Node:
	func festival_active() -> StringName:
		return &"director_fixture"
	func festival_today() -> StringName:
		return &""


func _director(t) -> TownDirector:
	for node in t.tree.get_nodes_in_group("town_director"):
		if t.world().area.is_ancestor_of(node):
			return node
	return null

func _time(t, hour: int, minute := 0) -> void:
	var gm: Node = t.autoload("GameManager")
	gm.hour = hour
	gm.minute = minute
	t.autoload("EventBus").time_of_day_changed.emit(hour, minute)
	await t.physics(2)

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.day = 2
	for type in ["town", "post", "door"]:
		t.check("handler_" + type, str(IsoArea.resolve_handler(type).kind) == "script")
	for area in ["farm", "hyggebyen", "traetoppen", "int_froebutikken", "int_postkontoret", "int_badehuset"]:
		gm.set_config_override("towns.hours_enabled", false)
		await t.world().travel(StringName(area), &"default")
		await t.frames(5)
		var director := _director(t)
		t.check("director_" + area, director != null and director.ready_for_population)
		if director == null:
			continue
		for hour in range(6, 26):
			await _time(t, hour)
			var wanted := Routines.present_in(area, Routines.now_ctx())
			var expected: Array = wanted.map(func(row): return str(row.npc))
			var actual: Array = director.live.keys()
			expected.sort()
			actual.sort()
			t.check("population_" + area + "_" + str(hour), expected == actual, "%s expected %s actual %s" % [area, expected, actual])
			var safe := true
			var defects: Array = []
			for actor in director.live.values():
				safe = safe and actor is Npc2D and actor.driven and (actor.collision_mask & Iso.LAYER_NPC) == 0 and (actor.collision_mask & Iso.LAYER_PLAYER) != 0
				var lag := Iso.to_ground(actor.global_position - director.area.to_global(Iso.to_screen(director._carrot(director.targets[str(actor.npc_id)], director.game_hours)))).length()
				if not actor.driven or (actor.collision_mask & Iso.LAYER_PLAYER) == 0 or (actor.collision_mask & Iso.LAYER_NPC) != 0 or lag > 421:
					defects.append([actor.npc_id, actor.driven, actor.collision_mask, lag])
				safe = safe and lag <= 421
			t.check("driven_lag_and_masks_" + area + "_" + str(hour), safe, str(defects))
		if area == "farm":
			await _time(t, 7, 11)
			t.check("pip_at_mailbox", director.node_of("postman_pip") != null and director.post_ground(&"pip_mailbox") != Vector2.INF and not director.curfew_enabled)
		if area == "hyggebyen":
			await _time(t, 9, 30)
			var events: Array = []
			var listener := func(id, payload):
				if id == &"routine_changed":
					events.append(payload.hour)
			t.autoload("EventBus").game_event.connect(listener)
			for hour in range(6, 26):
				await _time(t, hour)
			t.autoload("EventBus").game_event.disconnect(listener)
			t.check("routine_events_include_24_25", events == range(6, 26), str(events))
			await _time(t, 10)
			await _talk(t, director)
		if area == "int_froebutikken":
			await _time(t, 10)
			var keeper := director.node_of("merchant_pip")
			t.check("real_room_keeper", keeper != null and NpcDirector.node_of("merchant_pip") == keeper)
			var talk_hosts := 0
			for host in t.world().area.objects.get_children():
				if host is ShopCounter and host.kind == "talk":
					host._refresh()
					talk_hosts += int(host.is_enabled() and host.keeper_node() == keeper)
			t.check("both_talk_hosts_forward_to_keeper", talk_hosts == 2)
			await _talk(t, director, "merchant_pip")
	await _crowd(t, false)
	await _arrivals(t)
	await _park(t)
	await _curfew(t)
	gm.clear_config_overrides()

func _talk(t, director: TownDirector, id := "") -> void:
	if id == "" and not director.live.is_empty():
		id = str(director.live.keys()[0])
	var actor: Npc2D = director.node_of(id)
	if actor == null:
		t.fail("Expected live actor for conversation")
		return
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	actor.interact(t.player())
	await t.frames(3)
	var position := actor.global_position
	await t.frames(8)
	t.check("conversation_holds_" + id, actor.is_talking and actor._held and screen.is_open() and actor.global_position == position)
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("conversation_resumes_" + id, not actor.is_talking and not actor._held and not t.autoload("GameManager").is_modal_open())

func _park(t) -> void:
	var gm: Node = t.autoload("GameManager")
	await _time(t, 10)
	await t.world().travel(&"hyggebyen", &"default")
	await t.frames(4)
	var old := _director(t)
	var grid: NavGrid = old.nav
	var old_actors: Array = old.live.values().map(func(actor): return weakref(actor))
	for i in 30:
		await t.world().travel(&"farm", &"default")
		await t.frames(3)
		if i == 0:
			t.check("park_frees_all_citizen_nodes", old.live.is_empty() and old_actors.all(func(ref): return ref.get_ref() == null))
		await t.world().travel(&"hyggebyen", &"default")
		await t.frames(3)
		t.check("park_reenter_" + str(i), _director(t) == old and old.ready_for_population and t.tree.get_nodes_in_group("town_director").size() == 1 and NpcDirector._active.size() == 1)
	# A parked town keeps its baked grid; the city's level graph and reflowed festival posts are shared by every entry (SIM-05).
	t.check("parked_town_keeps_its_grid", grid != null and old.nav == grid and old.init_ms > 0.0, "re-entry initialization %.3f ms" % old.init_ms)
	await t.world().travel(&"traetoppen", &"default")
	await t.frames(4)
	var city := _director(t)
	var city_nav: LevelNav = city.level_nav
	var posts := {}
	for name in city.anchors:
		if str(name).begins_with("fest_"):
			posts[name] = city.anchors[name]
	await t.world().travel(&"hyggebyen", &"default")
	await t.frames(3)
	await t.world().travel(&"traetoppen", &"default")
	await t.frames(4)
	var again := _director(t)
	var same_posts := not posts.is_empty() and posts.keys().all(func(name): return again.anchors.get(name) == posts[name])
	t.check("city_reentry_reuses_static_geometry", again != city and city_nav != null and again.level_nav == city_nav and same_posts, "re-entry initialization %.3f ms" % again.init_ms)
	await t.world().travel(&"hyggebyen", &"default")
	await t.frames(3)
	var started := Time.get_ticks_usec()
	for i in 500:
		old._physics_process(1.0 / 60)
	var ms := float(Time.get_ticks_usec() - started) / 500000.0
	t.check("director_frame_budget", ms <= 0.3, "%.4f ms with %d live" % [ms, old.live.size()])
	# Between clock ticks the carrot runs at the clock's own rate: scaled with it, still while it is paused.
	var tm: Node = t.autoload("TimeManager")
	gm.set_config_override("time.minutes_per_real_second", 2.0)
	tm.set_time_scale(2.0)
	var scaled: float = old.clock_rate()
	tm.pause_time()
	var paused: float = old.clock_rate()
	tm.resume_time()
	tm.set_time_scale(1.0)
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	t.check("director_follows_the_clock_rate", is_equal_approx(scaled, 4.0) and paused == 0.0, "scaled %s paused %s" % [scaled, paused])

## Seats, arrivals and the minute tick of a running town: stable seats (SIM-08), quiet resyncs (SIM-01), staged sheets (REND-02).
func _arrivals(t) -> void:
	await t.world().travel(&"hyggebyen", &"default")
	await t.frames(4)
	var director := _director(t)
	var place := ""
	for name in RouteTable.anchors_of("hyggebyen"):
		var cap := RouteTable.capacity("hyggebyen." + str(name))
		if cap >= 3 and cap < 99 and not str(name).begins_with("fest_"):
			place = "hyggebyen." + str(name)
			break
	var everyone: Array = Routines.npc_ids()
	var cast: Array = everyone.slice(0, 3)
	var registry := {}
	for i in 2:
		registry[cast[i]] = {"priority": 50, "plans": {"day": {"blocks": [{"from": 6.0, "at": place, "act": "stand"}]}}, "select": [{"plan": "day"}]}
	Routines.override_registry = registry
	Routines.clear_cache()
	director.resync()
	var first: Dictionary = director._post_offsets.duplicate()
	registry[cast[2]] = registry[cast[0]].duplicate(true)
	Routines.clear_cache()
	director.resync()
	var kept := first.keys().all(func(id): return director._post_offsets.get(id) == first[id])
	var seats: Array = cast.map(func(id): return director._post_offsets.get(id, Vector2.INF))
	var apart := not seats.has(Vector2.INF)
	for i in seats.size():
		for j in range(i + 1, seats.size()):
			apart = apart and seats[i].distance_to(seats[j]) >= 40
	t.check("seats_stay_when_a_guest_joins", place != "" and first.size() == 2 and kept and apart, "%s: %s then %s" % [place, first, seats])
	var populated := [0]
	var listener := func(id: StringName, _payload: Dictionary) -> void:
		if id == &"area_populated":
			populated[0] += 1
	t.autoload("EventBus").game_event.connect(listener)
	director.resync(false)
	director.resync(false)
	var quiet: int = populated[0]
	registry.erase(cast[2])
	Routines.clear_cache()
	director.resync()
	t.autoload("EventBus").game_event.disconnect(listener)
	t.check("area_populated_only_on_change", quiet == 0 and populated[0] == 1, "%d events for unchanged resyncs, %d after a departure" % [quiet, populated[0] - quiet])
	var before: int = director.stats.resyncs
	for i in 120:
		director._physics_process(1.0 / 60)
	t.check("no_resync_between_minute_ticks", director.stats.resyncs == before, "%d resyncs in two seconds without a tick" % (director.stats.resyncs - before))
	# A walk-in whose sheets are not resident appears only once they are, loaded on worker threads.
	var newcomer := ""
	var sheet := ""
	for id in everyone:
		var look := IsoChibiSprite2D.resolve_id(str(t.autoload("LuaRuntime").get_npc(id).get("visual", "fairy")))
		var path := IsoChibiSprite2D.CHARACTERS_DIR + look + "/" + str(IsoChibiSprite2D.meta_for(look).animations.idle.sheet)
		if not id in cast and not ResourceLoader.has_cached(path):
			newcomer = id
			sheet = path
			break
	registry[newcomer] = registry[cast[0]].duplicate(true)
	Routines.clear_cache()
	var resident := []
	var spawned := func(id: String, _node: Node2D) -> void:
		if id == newcomer:
			resident.append(ResourceLoader.has_cached(sheet))
	director.citizen_spawned.connect(spawned)
	director.resync(false)
	var staged: bool = director._staging.has(newcomer) and not director.live.has(newcomer)
	await t.until(func(): return director.live.has(newcomer), 5.0)
	director.citizen_spawned.disconnect(spawned)
	t.check("walk_in_spawns_after_threaded_sheets", newcomer != "" and staged and resident == [true] and director._staging.is_empty(), "%s staged %s resident at spawn %s" % [newcomer, staged, resident])
	Routines.override_registry = {}
	Routines.clear_cache()
	director.resync()

func _curfew(t) -> void:
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("towns.curfew.enabled", true)
	var director := _director(t)
	var soon := float(gm.config_value("towns.curfew.whisper", 25.5))
	var home := float(gm.config_value("towns.curfew.go_home", 25.75))
	await _time(t, int(soon), int(round(fmod(soon, 1) * 60)))
	t.check("curfew_whisper", director._curfew_whispered and not director._curfew_sent)
	gm.push_modal(&"curfew_probe", false)
	await _time(t, int(home), int(round(fmod(home, 1) * 60)))
	t.check("curfew_held_during_modal", not director._curfew_sent and t.world().area.map.id == &"hyggebyen")
	gm.pop_modal(&"curfew_probe")
	await t.until(func(): return t.world().area.map.id == &"farm" and not t.world().traveling, 8)
	t.check("curfew_retries_and_returns_home", t.world().area.map.id == &"farm" and t.player().global_position.distance_to(t.world().area.get_spawn("from_home")) < 5)

func run_windowed(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.day = 2
	for row in [["hyggebyen", 2, 9, 30], ["hyggebyen", 7, 15, 0], ["traetoppen", 2, 12, 0], ["traetoppen", 2, 19, 0], ["farm", 2, 7, 11]]:
		gm.day = row[1]
		t.autoload("EventBus").day_started.emit(gm.day, gm.season)
		await _time(t, row[2], row[3])
		await t.world().travel(StringName(row[0]), &"default")
		await t.frames(5)
		var director := _director(t)
		if row[0] == "farm":
			t.player().global_position = director.area.to_global(Iso.to_screen(director.post_ground(&"pip_mailbox"))) + Vector2(100, 70)
		elif row[0] == "traetoppen":
			t.player().global_position = director.area.to_global(Iso.to_screen(director.post_ground(&"t_fire_s"))) + Vector2(100, 100)
		t.player().camera.reset_smoothing()
		await t.world().warm_clips()
		await t.frames(8)
		await t.capture("%s_%s_%s" % [row[0], row[2], row[3]])
		t.check("native_population_" + str(row), director != null and director.live.size() == Routines.present_in(str(row[0]), Routines.now_ctx()).size(), "%d scheduled citizens" % director.live.size())
	await _crowd(t, true)
	gm.clear_config_overrides()

func _crowd(t, capture: bool) -> void:
	var gm: Node = t.autoload("GameManager")
	gm.hour = 12
	gm.minute = 0
	t.autoload("EventBus").time_of_day_changed.emit(gm.hour, gm.minute)
	await t.world().travel(&"hyggebyen", &"default")
	var director := _director(t)
	var registry := {}
	var looks := {}
	var ids: Array = Routines.npc_ids()
	for id in ids:
		var look := str(t.autoload("LuaRuntime").get_npc(id).get("visual", ""))
		if look == "" or looks.has(look):
			continue
		looks[look] = true
		var index := registry.size()
		registry[id] = {"priority": 50 - index, "plans": {"work": {"blocks": [{"from": 6.0, "at": "hyggebyen.fest_hyggetorv_gather_" + str(index % 20 + 1), "act": "hide" if index == 0 else "stand"}]}}, "select": [{"plan": "work"}]}
		if registry.size() >= 22:
			break
	Routines.override_registry = registry
	Routines.clear_cache()
	director._ctx_override = Routines.make_ctx(1, 12, "regn")
	director.resync()
	t.check("ordinary_distinct_look_cap", director.live.size() == mini(16, registry.size()) and director.last_dropped == maxi(0, registry.size() - 16))
	var fixture := FestivalFixture.new()
	t.tree.root.add_child(fixture)
	Svc.override("SocialManager", fixture)
	director._ctx_override["fest"] = {"area": "hyggebyen", "id": "director_fixture", "from": 6.0, "to": 26.0}
	director.resync()
	await t.physics(2)
	var positions: Array = director.live.values().map(func(actor): return Iso.to_ground(actor.global_position))
	var spread := true
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			spread = spread and positions[i].distance_to(positions[j]) >= 199
	t.check("painted_crowd_has_readable_spacing", spread)
	t.check("festival_twenty_look_cap", director.live.size() == mini(20, registry.size()) and director.max_live == 20, "%d available distinct looks, %d live" % [registry.size(), director.live.size()])
	var first: Npc2D = director.node_of(str(registry.keys()[0]))
	t.check("hide_is_idle_and_stays_in_rain", director.targets[str(first.npc_id)].act == "hide" and first.visual.current_clip == &"idle" and str(director.targets[str(first.npc_id)].place).contains("fest_"))
	var begin := Time.get_ticks_usec()
	for i in 500:
		director._physics_process(1.0 / 60)
	var ms := float(Time.get_ticks_usec() - begin) / 500000.0
	t.check("festival_frame_budget", ms <= 0.3, "%.4f ms with %d live" % [ms, director.live.size()])
	if capture:
		t.player().global_position = director.area.to_global(Iso.to_screen(director.post_ground(&"fest_hyggetorv_host"))) + Vector2(100, 150)
		t.player().camera.reset_smoothing()
		await t.world().warm_clips()
		await t.frames(10)
		await t.capture("festival_green")
	director._ctx_override.clear()
	Svc.clear_overrides()
	fixture.free()
	Routines.override_registry.clear()
	Routines.clear_cache()
	director.resync()
