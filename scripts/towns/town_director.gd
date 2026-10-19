class_name TownDirector
extends Node
## One live population per loaded area. Baked ground positions and real navigation
## drive ordinary painted NPC actors; parked areas retain no citizen sheets.
signal citizen_spawned(npc_id: String, node: Node2D)
signal citizen_removed(npc_id: String)
const CARROT_SNAP := 420.0
const NPC_MASK := Iso.LAYER_WORLD | Iso.LAYER_PLAYER | Iso.LAYER_GROUND_BLOCK
var area: IsoArea
var area_id := ""
var live: Dictionary = {}
var anchors: Dictionary = {} # names -> ground pixels, area-local
var col: Dictionary = {}
var nav: NavGrid
var level_nav: LevelNav
var targets: Dictionary = {}
var _paths: Dictionary = {}
var curfew_enabled := true
var running := false
var ready_for_population := false
var game_hours := 6.0
var last_dropped := 0
var max_live := 16
var stats := {"spawned": 0, "removed": 0, "snaps": 0, "resyncs": 0, "max_lag": 0.0}
var _params: Dictionary = {}
var _shop_open: Dictionary = {}
var _curfew_whispered := false
var _curfew_sent := false
var _tick := 0.0
var _ctx_override: Dictionary = {}
var _generation := 0
var _prepare_ticks := 0
var _window_perches: Dictionary = {}
var _post_offsets: Dictionary = {}
var _slot_query: PhysicsShapeQueryParameters2D

static func create(target_area: IsoArea, params: Dictionary = {}, collected: Dictionary = {}) -> TownDirector:
	var director := TownDirector.new()
	director.name = "TownDirector"
	director.area = target_area
	director.area_id = str(params.get("area", target_area.map.id))
	director._params = params.duplicate(true)
	director.col = collected.duplicate(true)
	director.curfew_enabled = str(params.get("curfew", "true")) != "false" and not director.area_id.begins_with("int_")
	return director

static func attach_room(target_area: IsoArea, spec: Dictionary) -> Node:
	var existing := target_area.get_node_or_null("TownDirector")
	if existing != null:
		return existing
	var director := create(target_area, {"curfew": false}, {"area": str(spec.id), "kind": "room", "doors": [], "posts": spec.get("posts", [])})
	target_area.add_child(director)
	return director

func _enter_tree() -> void:
	running = true
	_generation += 1
	NpcDirector.register(self)
	EventBus.time_of_day_changed.connect(_clock)
	EventBus.day_started.connect(_morning)
	EventBus.area_changed.connect(_area_changed)
	if is_node_ready():
		_initialize.call_deferred(_generation)

func _ready() -> void:
	add_to_group("town_director")
	_initialize.call_deferred(_generation)

func _initialize(generation: int) -> void:
	if not is_inside_tree() or generation != _generation:
		return
	if not RouteTable.is_loaded():
		RouteTable.load_table()
	if col.is_empty():
		col = TownMarks.collect(area, _params)
	for name in RouteTable.anchors_of(area_id):
		anchors[str(name)] = RouteTable.position_of(area_id + "." + str(name))
	if str(col.get("kind", "")) == "room":
		for name in LuaData.dict(area.get_meta("posts", {})):
			anchors[str(name)] = Iso.to_ground(area.get_meta("posts")[name])
	# A cancellable physics countdown avoids resuming an awaited member function
	# after a room probe or a parked area has been destroyed.
	_prepare_ticks = 2

func _finish_initialize() -> void:
	if area_id == "traetoppen":
		level_nav = LevelNav.make()
		_window_perches.clear()
		for marker in CityData.markers_of(CityBuilder.of(area).data, "npc"):
			if bool(marker.get("window", false)):
				_window_perches[str(marker.id)] = {"point": marker.get("pose", marker.at), "reach": marker.reach, "rank": int(LuaData.dict(CityBuilder.of(area).data.get("decor_ranks", {})).get("owl_holes", 175)) + 1}
	elif str(col.get("kind", "")) == "room":
		var spec := LuaData.dict(area.get_meta("room_spec", {}))
		nav = NavGrid.bake_room(area, int(spec.get("cols", 1)), int(spec.get("rows", 1)), Iso.LAYER_WORLD | Iso.LAYER_GROUND_BLOCK)
	else:
		nav = NavGrid.bake_area(area)
		var resolved := TownMarks.resolve_cells(nav, col)
		# Keep exact baked positions when present. The baker and runtime share the
		# same map/physics geometry; resolved cells also expand festival satellites.
		for name in resolved.cells:
			if not anchors.has(str(name)):
				anchors[str(name)] = Iso.to_ground(area.to_local(area.cell_to_global(resolved.cells[name])))
	_space_festival_posts()
	ready_for_population = true
	game_hours = float(_context().hour)
	resync()
	_emit_shop_changes(true)
	Svc.static_call("res://scripts/festival/festival_decor.gd", &"attach", [self], false)

func _exit_tree() -> void:
	running = false
	ready_for_population = false
	_prepare_ticks = 0
	_generation += 1
	NpcDirector.unregister(self)
	for pair in [[EventBus.time_of_day_changed, _clock], [EventBus.day_started, _morning], [EventBus.area_changed, _area_changed]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	clear_all()
	nav = null
	level_nav = null
	_paths.clear()

func clear_all() -> void:
	for id in live.keys():
		_remove(str(id))

func _remove(id: String) -> void:
	var actor: Node = live.get(id)
	live.erase(id)
	targets.erase(id)
	if is_instance_valid(actor):
		actor.queue_free()
	stats.removed += 1
	citizen_removed.emit(id)

func _context() -> Dictionary:
	return Routines.now_ctx() if _ctx_override.is_empty() else _ctx_override.duplicate(true)

func _clock(hour: int, minute: int) -> void:
	if not ready_for_population:
		return
	var now := float(_context().hour)
	var skipped := absf(now - game_hours) > 2.0 / 60.0
	game_hours = now
	if minute == 0:
		EventBus.game_event.emit(&"routine_changed", {"hour": hour})
	resync(skipped)
	_emit_shop_changes(false)

func _morning(_day: int, _season: StringName) -> void:
	_curfew_whispered = false
	_curfew_sent = false
	game_hours = float(_context().hour)
	resync()

func _area_changed(id: StringName) -> void:
	if str(id) == area_id:
		game_hours = float(_context().hour)
		resync()
		_emit_shop_changes(true)

func _emit_shop_changes(quiet: bool) -> void:
	for door in col.get("doors", []):
		var id := str(door.get("building", ""))
		var building := Hours.building(id)
		if not building.has("hours"):
			continue
		var state := Hours.state(id, _context())
		if not quiet and _shop_open.has(id) and bool(_shop_open[id]) != bool(state.open):
			EventBus.game_event.emit(&"shop_open_changed", {"shop": str(building.get("shop", id)), "open": bool(state.open), "reason": str(state.reason), "opens_at": state.get("opens_at", -1), "closes_at": Hours.hours_on(building, int(_context().weekday))[1]})
		_shop_open[id] = bool(state.open)

func curfew_check(ctx: Dictionary) -> void:
	if not curfew_enabled or not bool(GameManager.config_value("towns.curfew.enabled", true)):
		return
	var hour := float(ctx.hour)
	if hour >= float(GameManager.config_value("towns.curfew.go_home", 25.75)):
		if _curfew_sent or GameManager.is_modal_open() or GameManager.current_phase != GameManager.GamePhase.PLAYING:
			return
		var world := get_tree().get_first_node_in_group("world_2d")
		if world != null and (world.traveling or world.sleeping):
			return
		_curfew_sent = true
		EventBus.whisper_requested.emit("HOURS_CURFEW_HOME")
		EventBus.area_change_requested.emit(&"farm", &"from_home")
	elif hour >= float(GameManager.config_value("towns.curfew.whisper", 25.5)) and not _curfew_whispered:
		_curfew_whispered = true
		EventBus.whisper_requested.emit("HOURS_CURFEW_SOON")

func resync(hard := true, only := "") -> void:
	if not ready_for_population or not is_inside_tree():
		return
	stats.resyncs += 1
	var ctx := _context()
	if hard:
		game_hours = float(ctx.hour)
	curfew_check(ctx)
	var festival := false
	var social := Svc.node("SocialManager")
	if social != null and social.has_method("festival_active"):
		festival = str(social.call("festival_active")) != "" and str(LuaData.dict(_context().get("fest", {})).get("area", "")) == area_id
	max_live = maxi(1, int(GameManager.config_value("towns.max_live_visuals_festival" if festival else "towns.max_live_visuals", 20 if festival else 16)))
	var room := area.has_meta("room_spec")
	var keeper := ""
	if room:
		var spec: Dictionary = area.get_meta("room_spec")
		var building := Hours.building(str(spec.get("building","")))
		keeper=str(building.get("keeper",building.get("owner","")))
	var selected := NpcDirector.select_presences(Routines.present_in(area_id,ctx),max_live,keeper,(11 if area_id == "int_torvekroen" else 4) if room else -1)
	var wanted := {}
	var looks: Dictionary = selected.looks
	last_dropped=int(selected.dropped)
	for row in selected.rows:wanted[str(row.npc)]=row
	_assign_post_slots(wanted)
	for id in live.keys():
		if not wanted.has(id) and (only == "" or only == str(id)):
			# Dialogue owns the actor until its result has completed.
			if not live[id].is_talking and not live[id]._held:
				_remove(str(id))
	for id in wanted:
		if only != "" and only != str(id):
			continue
		if not live.has(id):
			var actor := Npc2D.create({"id": id, "wander": "0"})
			actor.area = area
			actor.set_driven(true)
			actor.position = Iso.to_screen(_position(str(wanted[id].place)))
			area.objects.add_child(actor)
			actor.collision_mask = NPC_MASK
			live[id] = actor
			stats.spawned += 1
			citizen_spawned.emit(str(id), actor)
		_update_target(str(id), wanted[id], hard)
	EventBus.game_event.emit(&"area_populated", {"area": area_id, "citizens": live.size(), "visuals": looks.size(), "dropped": last_dropped})

func _position(anchor: String) -> Vector2:
	var name := anchor.get_slice(".", 1) if anchor.contains(".") else anchor
	return anchors.get(name, Iso.to_ground(area.to_local(area.get_spawn("default"))))

func _assign_post_slots(wanted: Dictionary) -> void:
	_post_offsets.clear()
	var groups := {}
	for id in wanted:
		var row: Dictionary = wanted[id]
		var cap := RouteTable.capacity(str(row.place))
		if str(row.state) == "move" or cap <= 1 or cap >= 99:
			continue
		if not groups.has(str(row.place)):
			groups[str(row.place)] = []
		groups[str(row.place)].append(str(id))
	for place in groups:
		var ids: Array = groups[place]
		if ids.size() < 2:
			continue
		ids.sort()
		var used: Array[Vector2] = []
		for index in ids.size():
			var offset := _post_slot(_position(place), index, ids.size(), used)
			_post_offsets[ids[index]] = offset
			used.append(offset)

	if area_id == "int_torvekroen": _inn_guest_slots(wanted)

func _inn_guest_slots(wanted: Dictionary) -> void:
	# The inn is a meeting room; spread its guests across reachable customer
	# floor instead of stacking three large painted bodies on a chair anchor.
	if nav == null: return
	var used: Array[Vector2] = []
	var cells: Array[Vector2] = []
	var entry := Iso.to_ground(area.to_local(area.get_spawn("default")))
	for y in range(3,nav.size.y-1):
		for x in range(1,nav.size.x-1):
			var cell := Vector2i(x,y)
			if not nav.blocked.has(cell):
				var point := Iso.to_ground(area.to_local(nav.cell_pos(cell)))
				if point.distance_to(entry) >= 120.0: cells.append(point)
	for id in wanted:
		var row: Dictionary = wanted[id]
		if str(row.state) != "stay" or str(row.npc) == "innkeeper_kvak": continue
		var base := _position(str(row.place))
		if str(row.place).ends_with(".bed"): continue
		var options := cells.duplicate()
		options.sort_custom(func(a: Vector2,b: Vector2):return a.distance_squared_to(base) < b.distance_squared_to(base))
		var found := false
		for spacing in [200.0,170.0,140.0]:
			for point in options:
				if used.all(func(p: Vector2):return p.distance_to(point) >= spacing):
					_post_offsets[str(id)] = point-base
					used.append(point)
					found = true
					break
			if found: break

func _post_slot(base: Vector2, index: int, count: int, used: Array[Vector2]) -> Vector2:
	if _slot_query == null:
		_slot_query = PhysicsShapeQueryParameters2D.new()
		var body := ConvexPolygonShape2D.new()
		body.points = Npc2D._ellipse(Vector2(25, 14.8))
		_slot_query.shape = body
		_slot_query.collision_mask = Iso.LAYER_WORLD | Iso.LAYER_GROUND_BLOCK
	var space := area.get_world_2d().direct_space_state
	for radius in [60.0, 42.0, 22.0]:
		for turn in 8:
			var angle := TAU * float(index) / count + float(turn) * PI / 4
			var offset: Vector2 = Vector2(cos(angle), sin(angle)) * float(radius)
			if used.any(func(previous): return previous.distance_to(offset) < 40):
				continue
			var point := area.to_global(Iso.to_screen(base + offset))
			if area.walkable_test.is_valid() and not bool(area.walkable_test.call(point)):
				continue
			var fits := true
			if area.walkable_test.is_valid():
				for edge in (_slot_query.shape as ConvexPolygonShape2D).points:
					fits = fits and bool(area.walkable_test.call(point + edge))
			if not fits:
				continue
			_slot_query.collision_mask = Iso.LAYER_WORLD | Iso.LAYER_GROUND_BLOCK
			var city := CityBuilder.of(area)
			if city != null:
				var level := city.registry.level_at(point)
				if level == null:
					continue
				_slot_query.collision_mask |= level.mask_bit()
			_slot_query.transform = Transform2D(0, point)
			if space.intersect_shape(_slot_query, 1).is_empty():
				return offset
	return Vector2.ZERO

func _path(from: String, to: String) -> Dictionary:
	var key := from + "|" + to
	if _paths.has(key):
		return _paths[key]
	var a := _position(from)
	var b := _position(to)
	var points := PackedVector2Array()
	if level_nav != null:
		var registry := CityBuilder.of(area).registry
		var la := registry.level_at(area.to_global(Iso.to_screen(a)))
		var lb := registry.level_at(area.to_global(Iso.to_screen(b)))
		var ai := -1
		var bi := -1
		for i in level_nav.levels.size():
			if la != null and str(level_nav.levels[i].id) == str(la.id):
				ai = i
			if lb != null and str(level_nav.levels[i].id) == str(lb.id):
				bi = i
		points = level_nav.route(a, ai, b, bi).polyline
	elif nav != null:
		var route := nav.path(area.global_to_cell(area.to_global(Iso.to_screen(a))), area.global_to_cell(area.to_global(Iso.to_screen(b))))
		for p in route.get("polyline", PackedVector2Array()):
			points.append(Iso.to_ground(area.to_local(p)))
	if points.size() < 2:
		# A missing local path never authorizes walking through a wall. Keep the
		# citizen at the safe destination until the next valid schedule leg.
		points = PackedVector2Array([b, b])
	else:
		points[0] = a
		points[-1] = b
	var lengths := PackedFloat32Array([0])
	for i in range(1, points.size()):
		lengths.append(lengths[-1] + points[i].distance_to(points[i - 1]))
	var result := {"points": points, "lengths": lengths}
	_paths[key] = result
	return result

func _carrot(row: Dictionary, hour: float) -> Vector2:
	var leg := LuaData.dict(row.get("leg", {}))
	if leg.is_empty():
		# Hash % capacity gave two relatives the very same spot. Slots are
		# assigned uniquely to the live group and checked against room/deck geometry.
		return _position(str(row.place)) + (_post_offsets.get(str(row.npc), Vector2.ZERO) as Vector2)
	if str(leg.get("kind", "")) == "portal":
		return _position(str(leg.to))
	var path := _path(str(leg.from), str(leg.to))
	var fraction := clampf((hour - float(leg.t0)) / maxf(0.000001, float(leg.t1) - float(leg.t0)), 0, 1)
	var distance := fraction * float(path.lengths[-1])
	for i in range(1, path.points.size()):
		if path.lengths[i] >= distance:
			return path.points[i - 1].lerp(path.points[i], clampf((distance - float(path.lengths[i - 1])) / maxf(0.000001, float(path.lengths[i] - path.lengths[i - 1])), 0, 1))
	return path.points[-1]

func _update_target(id: String, row: Dictionary, hard: bool) -> void:
	var actor: Npc2D = live[id]
	targets[id] = row
	if actor.is_talking or actor._held:
		return
	var point := area.to_global(Iso.to_screen(_carrot(row, game_hours)))
	if hard or not actor.has_meta("town_placed"):
		if Iso.to_ground(point - actor.global_position).length() > CARROT_SNAP or not actor.has_meta("town_placed"):
			actor.global_position = point
			stats.snaps += 1
		actor.set_meta("town_placed", true)
	var name := str(row.place).get_slice(".", 1)
	for post in col.get("posts", []):
		if str(post.get("name", post.get("id", ""))) == name and str(post.get("facing", "")) != "":
			actor.face(str(post.facing))
	actor.set_act("idle" if str(row.act) in ["hide", "stand", "inside"] else str(row.act))
	# The route owns safe feet on the deck; the authored window owns the owl's
	# painted pose. This keeps her reachable without drawing her inside the bark.
	var perched := str(row.act) == "perch" and not str(row.state) == "move" and _window_perches.has(id)
	if perched:
		actor.visual.position = area.to_local(_window_perches[id].point) - actor.position
		actor.visual.z_as_relative = false
		actor.visual.z_index = int(_window_perches[id].rank)
		actor.visual.shadow.visible = false
		actor.face("S")
		actor.set_interaction_reach(maxf(60, float(_window_perches[id].reach)))
		actor._bubble_label.position = actor.visual.position + Vector2(-16, -142)
		actor._bubble_label.z_as_relative = false
		actor._bubble_label.z_index = int(_window_perches[id].rank) + 1
	else:
		actor.visual.position = Vector2.ZERO
		actor.visual.z_as_relative = true
		actor.visual.z_index = 0
		actor.visual.shadow.visible = true
		actor.set_interaction_reach(60)
		actor._bubble_label.position = Vector2(-16, -142)
		actor._bubble_label.z_as_relative = true
		actor._bubble_label.z_index = 0

func _physics_process(delta: float) -> void:
	if _prepare_ticks > 0:
		_prepare_ticks -= 1
		if _prepare_ticks == 0:
			_finish_initialize()
		return
	if not ready_for_population or not running or (GameManager.current_phase != GameManager.GamePhase.PLAYING and _ctx_override.is_empty()):
		return
	game_hours += delta * clock_rate() / 60.0
	_tick += delta
	if _tick >= 0.5:
		_tick = 0
		resync(false)
	for id in live:
		var actor: Npc2D = live[id]
		if not is_instance_valid(actor) or actor.is_talking or actor._held or not targets.has(id):
			continue
		var row: Dictionary = targets[id]
		var point := area.to_global(Iso.to_screen(_carrot(row, game_hours)))
		var offset := Iso.to_ground(point - actor.global_position)
		var distance := offset.length()
		if distance > CARROT_SNAP:
			actor.global_position = point
			stats.snaps += 1
			distance = 0
		var speed := RouteTable.speed * Routines.speed_mult(str(id)) * 1.6
		actor.velocity = Iso.to_screen(offset.normalized() * minf(speed, distance / maxf(delta, 0.0001))) if distance > 3 else Vector2.ZERO
		if distance > 3:
			actor.face(Iso.dir8_of(actor.velocity))
		actor.move_and_slide()
		actor.visual.update_motion(actor.velocity)
		stats.max_lag = maxf(float(stats.max_lag), distance)

## Game minutes per real second between two clock ticks: the rate TimeManager
## feeds the clock (nothing while it is paused, faster under its time scale).
func clock_rate() -> float:
	if not _ctx_override.is_empty():
		return RouteTable.game_min_per_s
	return 0.0 if TimeManager.is_paused else GameManager.minutes_per_real_second() * TimeManager.time_scale

func post_ground(name: StringName) -> Vector2:
	return anchors.get(str(name), Vector2.INF)
func door_ground(building: StringName) -> Vector2:
	return post_ground(StringName("door_" + str(building)))
func node_of(id: String) -> Node:
	return live.get(id)
func controls(id: String) -> bool:
	return Routines.registry().has(id)

## Painted chibi heads need more room than the prototype's one-cell crowd.
## Reflow named festival posts onto safe floor, preserving the public names.
func _space_festival_posts() -> void:
	var sets: Array = col.get("fest", []).duplicate()
	sets.append_array(col.get("fest_sets", []))
	for spot in sets:
		var prefix := "fest_" + str(spot.spot) + "_"
		var centre: Vector2 = anchors.get(prefix + "host", Vector2.INF)
		if centre == Vector2.INF:
			continue
		var available: Array[Vector2] = []
		if nav != null:
			var base := area.global_to_cell(area.to_global(Iso.to_screen(centre)))
			for y in range(-10, 11):
				for x in range(-10, 11):
					var cell := base + Vector2i(x, y)
					if nav.astar.is_in_boundsv(cell) and not nav.blocked.has(cell):
						available.append(Iso.to_ground(area.to_local(area.cell_to_global(cell))))
		elif level_nav != null:
			for radius in range(0, 9):
				for direction in 24:
					var angle := TAU * float(direction) / 24.0
					var candidate := centre + Vector2(cos(angle), sin(angle)) * float(radius) * 100
					var snapped := level_nav.snap(candidate, int(spot.level))
					if bool(snapped.get("ok", false)):
						available.append(snapped.pos)
		var taken: Array[Vector2] = [centre]
		for role in FestSet.roles():
			var name := prefix + str(role[0])
			if str(role[0]) == "host":
				continue
			var offset: Vector2i = role[1]
			var desired := centre + Iso.to_ground(Iso.iso_center(offset) - Iso.iso_center(Vector2i.ZERO))
			var candidates: Array[Vector2] = available.duplicate()
			candidates.sort_custom(func(a: Vector2, b: Vector2): return a.distance_squared_to(desired) < b.distance_squared_to(desired))
			# A small deck (the bathhouse) cannot fit 28 posts at the preferred
			# spacing. Keep every named post on safe floor, reducing spacing only
			# when needed; never fall back to the player's arrival position.
			var placed := false
			for spacing in [200.0,160.0,120.0,80.0]:
				for candidate in candidates:
					if taken.all(func(point: Vector2): return candidate.distance_squared_to(point) >= spacing * spacing):
						anchors[name] = candidate
						taken.append(candidate)
						placed = true
						break
				if placed: break
			if not placed:
				push_error("TownDirector: no safe festival post for "+area_id+"."+name)
