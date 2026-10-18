class_name JourneyWalker
extends RefCounted
## Long-journey real-input controller, separate from the established town-loop walker.
## Walk the REAL player to a point with REAL movement actions.
##  * steering = proportional on the delta, converted to GROUND space (the player reads Input.get_vector in ground px, velocity = Iso.to_screen(ground),
##    player_stub_2d.gd:153-156), analog strengths through t.hold(action, strength), re-evaluated every physics tick;
##  * route = straight line when it is free, else an A* route on a grid baked from the PHYSICS space with the player's body (the NavGrid recipe of
##    design3 areas_interiors.md 10.4, 8.4 ms per 3,600 cells), smoothed by line-of-sight; builder areas (city, interiors) pass `waypoints` from loop.json.
## No teleport, no velocity poke: collisions, warps, interactables and the area clock behave as for a human.
const ACTIONS := {"left": &"move_left", "right": &"move_right", "up": &"move_forward", "down": &"move_back"}
static var tick_hook := Callable()
static var precise_city_navigation := false


static func _steer(t, d: Vector2) -> void:
	var g: Vector2 = Iso.to_ground(d)
	var v := g.normalized() if g.length() > 0.001 else Vector2.ZERO
	t.hold(ACTIONS["right"], maxf(v.x, 0.0)) if v.x > 0.02 else t.release(ACTIONS["right"])
	t.hold(ACTIONS["left"], maxf(-v.x, 0.0)) if v.x < -0.02 else t.release(ACTIONS["left"])
	t.hold(ACTIONS["down"], maxf(v.y, 0.0)) if v.y > 0.02 else t.release(ACTIONS["down"])
	t.hold(ACTIONS["up"], maxf(-v.y, 0.0)) if v.y < -0.02 else t.release(ACTIONS["up"])


## A* over the cells of a GRID area, solid = not walkable ground OR the body (x1.4) overlaps a world/ground_block collider at the cell centre.
static func bake(t, area: IsoArea, body_scale: float = 1.4, target := Vector2.INF) -> AStarGrid2D:
	await t.physics(2)                                        # static bodies reach the physics server one frame after they are added
	var w: int = area.map.width
	var h: int = area.map.height
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, w, h)
	g.cell_size = Vector2.ONE
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	var space: PhysicsDirectSpaceState2D = area.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var sh := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		var a: float = TAU * float(k) / 12.0
		pts.append(Vector2(cos(a) * 25.0 * body_scale, sin(a) * 14.8 * body_scale))
	sh.points = pts
	q.shape = sh
	# Static planning excludes moving citizens; the steering loop avoids
	# their actual physics bodies. Baking one into a coarse map cell can
	# otherwise seal the player's starting cell just after talking.
	q.collision_mask = int(t.player().collision_mask) & ~Iso.LAYER_NPC
	var exits := _warp_exclusions(t,area,target)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			q.transform = Transform2D(0.0, area.cell_to_global(c))
			var point := Iso.to_ground(area.cell_to_global(c))
			g.set_point_solid(c, (not area.is_walkable(c)) or not space.intersect_shape(q, 1).is_empty() or exits.any(func(poly):return Geometry2D.is_point_in_polygon(point,poly)))
	# A walk to a citizen, clue or enemy must not take a shortcut through a
	# stair trigger. Entrances remain traversable when they are the goal.
	for warp in t.tree.get_nodes_in_group("warp"):
		if warp is Warp2D and area.is_ancestor_of(warp) and warp.global_position.distance_to(target) > 1:
			var cell := area.global_to_cell(warp.global_position)
			if g.is_in_boundsv(cell): g.set_point_solid(cell,true)
	return g


static func route(area: IsoArea, g: AStarGrid2D, from_g: Vector2, to_g: Vector2) -> Array[Vector2]:
	var a: Vector2i = area.global_to_cell(from_g)
	var b: Vector2i = area.global_to_cell(to_g)
	# the target (a warp, a counter) may itself sit on a solid cell: route to the nearest free cell around it
	if not g.region.has_point(a) or not g.region.has_point(b):
		return []
	if g.is_point_solid(b):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var c := b + Vector2i(dx, dy)
				if g.region.has_point(c) and not g.is_point_solid(c) and Vector2(dx, dy).length() < bd:
					bd = Vector2(dx, dy).length(); best = c
		if best.x >= 0:
			b = best
	if g.is_point_solid(a):
		g.set_point_solid(a, false)
	var path: Array[Vector2i] = g.get_id_path(a, b)
	var out: Array[Vector2] = []
	if path.is_empty():
		return out
	for c in path:
		out.append(area.cell_to_global(c))
	out.append(to_g)
	return out


static func walk_to(t, target: Vector2, tol: float = 30.0, timeout_game_s: float = 40.0, waypoints: Array = [], target_level: StringName = &"", interaction_target: Node2D = null) -> Dictionary:
	var p: Node2D = t.player()
	var area: Variant = p.get("area") if p != null else null
	var pts: Array = waypoints.duplicate()
	var transits: Array[Dictionary] = []
	var bridge_targets: Array[Vector2] = []
	var used_nav := false
	var director: TownDirector = TownProbe.director(t)
	if pts.is_empty() and director != null and director.level_nav != null:
		var nav := _player_nav(t,area,director.level_nav,target) if precise_city_navigation else director.level_nav
		var plan_scale := 2.0 if precise_city_navigation else 1.0
		var registry := CityBuilder.of(area).registry
		var a := registry.get_level(ActorLevel.level_id(p))
		if a == null or a.kind != &"platform": a = registry.level_at(p.global_position)
		# Route onto the actual mouth of an outgoing stub. Snapping its far
		# warp directly to the nearest platform rim can select a closed rail
		# beside that mouth, which no amount of steering can walk through.
		var nav_target := target
		for stub in registry.stubs:
			var path: PackedVector2Array = stub.path
			if area.to_global(path[-1]).distance_to(target) < 1:
				nav_target = area.to_global(path[0])
				break
		var b := registry.get_level(target_level) if target_level != &"" else registry.level_at(nav_target)
		var ai := -1
		var bi := -1
		for index in nav.levels.size():
			if a != null and str(nav.levels[index].id) == str(a.id):
				ai = index
			if b != null and str(nav.levels[index].id) == str(b.id):
				bi = index
		var planned := nav.route(Iso.to_ground(area.to_local(p.global_position))*plan_scale, ai, Iso.to_ground(area.to_local(nav_target))*plan_scale, bi)
		for point in planned.get("polyline", PackedVector2Array()):
			pts.append(area.to_global(Iso.to_screen(point/plan_scale)))
		# LevelNav snaps a point outside its deck grid to the rim. Walk the
		# authored bridge stub as well; reaching that snapped rim is not arrival
		# at its warp. Curved stubs retain every authored bend.
		if not pts.is_empty():
			for stub in registry.stubs:
				var path: PackedVector2Array = stub.path
				if area.to_global(path[-1]).distance_to(target) < 1:
					for point in path:
						pts.append(area.to_global(point))
			if (pts[-1] as Vector2).distance_to(target) > 0.01:
				pts.append(target)
		for segment in planned.get("segments", []):
			if str(segment.kind) == "bridge":
				for point in segment.polyline:
					bridge_targets.append(area.to_global(Iso.to_screen(point/plan_scale)))
			if str(segment.kind) == "ladder":
				var start: Vector2 = area.to_global(Iso.to_screen(segment.polyline[0]/plan_scale))
				var finish: Vector2 = area.to_global(Iso.to_screen(segment.polyline[-1]/plan_scale))
				transits.append({"start": start, "finish": finish, "index": pts.find(finish), "to": str(nav.levels[int(segment.to_level)].id), "done": false})
		used_nav = true
	elif pts.is_empty() and area is IsoArea and area.has_meta("room_spec"):
		await t.physics(2)
		var spec: Dictionary = area.get_meta("room_spec")
		var nav := NavGrid.bake_room(area, int(spec.cols), int(spec.rows), int(p.collision_mask))
		var planned := nav.path(area.global_to_cell(p.global_position), area.global_to_cell(target))
		for point in planned.get("polyline", PackedVector2Array()):
			pts.append(point)
		if not pts.is_empty():
			pts.append(target)
		used_nav = true
	elif pts.is_empty() and area is IsoArea and (area as IsoArea).map != null and (area as IsoArea).map.has_grid():
		# body ladder: x1.4 keeps the walker off padded colliders (design3 areas_interiors 10.4: 0 stuck events), but a ONE-cell bridge corridor is narrower than a
		# x1.4 body (the void-rim blockers of both sides intrude), so the ladder falls back to the real body when the inflated grid has no route
		for sc in [1.4, 1.2, 1.0]:
			var g: AStarGrid2D = await bake(t, area as IsoArea, sc, target)
			pts = route(area as IsoArea, g, p.global_position, target)
			used_nav = true
			if pts.size() > 1:
				used_nav = true
				break
	elif pts.is_empty():
		pts = [target]
	if pts.is_empty():
		t.release_all()
		return {"ok": false, "ticks": 0, "seconds": 0.0, "dist_left": Iso.to_ground(target - p.global_position).length(), "stuck": false, "nav": used_nav, "waypoints": 0}
	# The first grid centre represents the cell already occupied by the
	# player. After a conversation another body's centre can share that
	# cell; walking back onto it pins the controller against the citizen.
	var i := 1 if pts.size() > 1 and Iso.to_ground(pts[0]-p.global_position).length() < 64 else 0
	var ticks := 0
	var max_ticks := int(timeout_game_s * Engine.physics_ticks_per_second)
	var stuck := 0
	var last := p.global_position
	var arrived := false
	var interactions := 0
	var last_advance := {}
	while ticks < max_ticks and i < pts.size():
		if p == null or not is_instance_valid(p) or p.get("area") != area:
			break                                             # an area change is the point of walking onto a warp: the caller checks it
		if is_instance_valid(interaction_target) and p.nearest_interactable() == interaction_target:
			arrived = true
			break
		if is_instance_valid(interaction_target) and interaction_target is Enemy2D:
			# Stop for a nearer threat encountered along the route. Walking
			# past a whole firing line to reach a stale target is not play.
			for foe in area.objects.get_children():
				if not foe is Enemy2D or foe.state == Enemy2D.S.DEAD or DungeonCombatRules.enemy_class(foe.kind) == "critter" or Iso.ground_dist(p.global_position,foe.global_position) >= 170: continue
				var ray := PhysicsRayQueryParameters2D.create(p.global_position,foe.global_position,Iso.LAYER_WORLD | Iso.LAYER_GROUND_BLOCK | Iso.LAYER_RESOURCE_NODE)
				if p.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): arrived = true; break
			if arrived: break
		var wp: Vector2 = pts[i]
		var lane_failed := false
		for transit in transits:
			if transit.done or int(transit.index) != i:
				continue
			# A route's ladder edge is a real E interaction, not a walk through
			# the deck wall. The production lane owns its tween, mask and lock.
			t.release_all()
			var host: Node = p.nearest_interactable()
			if not host is ClimbLane:
				lane_failed = true
				break
			t.tap(&"interact")
			interactions += 1
			await t.physics(2)
			ticks += 2
			var waited := 0
			while ActorLevel.is_locked(p) and waited < 300 and ticks < max_ticks:
				await t.physics(1)
				waited += 1
				ticks += 1
			transit.done = str(ActorLevel.level_id(p)) == str(transit.to)
			lane_failed = not transit.done
		if lane_failed:
			stuck = 3
			break
		var d: Vector2 = wp - p.global_position
		var is_last: bool = i == pts.size() - 1
		# LevelNav is a static deck graph. Citizens can occupy a grid centre
		# between planning and arrival; do not insist on standing inside one.
		var occupied := false
		for citizen in t.tree.get_nodes_in_group("npc"):
			if citizen is CollisionObject2D and citizen != p and (citizen.collision_layer & p.collision_mask) != 0 and Iso.ground_dist(citizen.global_position,wp) < 55:
				occupied = true
				break
		# Only skip nearby grid centres. A bridge mouth precedes a long
		# crossing; omitting it cuts diagonally through its platform rail.
		if occupied and not is_last and wp not in bridge_targets and Iso.to_ground(d).length() < 130:
			last_advance = {"reason":"occupied","point":wp,"position":p.global_position,"level":ActorLevel.level_id(p)}
			i += 1
			continue
		# City paths use a 32-ground-pixel grid. The old prototype's 36-screen-
		# pixel tolerance skipped several bends and cut into rails/keepouts.
		if Iso.to_ground(d).length() <= (tol if is_last else 8.0):
			if is_last:
				arrived = true
				break
			last_advance = {"reason":"reached","point":wp,"position":p.global_position,"level":ActorLevel.level_id(p)}
			i += 1
			continue
		# Side-stepping on an authored bridge can steer off its narrow lane.
		# Follow its centre line and let a crossing citizen clear the way.
		_steer(t, d if wp in bridge_targets else _around_citizen(t,p,d))
		if tick_hook.is_valid(): tick_hook.call(p)
		await t.physics(1)
		ticks += 1
		if ticks % 30 == 0:
			stuck = stuck + 1 if p.global_position.distance_to(last) < 6.0 else 0
			last = p.global_position
			if stuck >= 3:
				break
	t.release_all()
	var changed: bool = is_instance_valid(p) and p.get("area") != area
	var collider := ""
	if p is CharacterBody2D and p.get_slide_collision_count() > 0:
		var body: Object = p.get_slide_collision(0).get_collider()
		if body is Node and is_instance_valid(body):
			collider = str(body.name)
	return {"ok": arrived or changed, "area_changed": changed, "ticks": ticks, "seconds": float(ticks) / Engine.physics_ticks_per_second, "dist_left": Iso.to_ground(target - p.global_position).length() if p != null and is_instance_valid(p) else -1.0, "stuck": stuck >= 3, "nav": used_nav, "waypoints": pts.size(), "waypoint_index": i, "position": p.global_position if is_instance_valid(p) else Vector2.INF, "next": pts[i] if i < pts.size() else target, "collider": collider, "interactions": interactions,"last_advance":last_advance}

static func _around_citizen(t, player: CharacterBody2D, wanted: Vector2) -> Vector2:
	var direction := Iso.to_ground(wanted).normalized()
	var blocked := false
	for citizen in t.tree.get_nodes_in_group("npc"):
		if not citizen is CollisionObject2D or citizen == player or (citizen.collision_layer & player.collision_mask) == 0: continue
		var offset := Iso.to_ground(citizen.global_position-player.global_position)
		if offset.length() < 110 and direction.dot(offset.normalized()) > .25:
			blocked = true
			break
	if not blocked: return wanted
	for angle in [0.0,.5,-.5,1.0,-1.0,1.5,-1.5,2.0,-2.0,PI]:
		var motion := Iso.to_screen(direction.rotated(angle)*90)
		if not player.test_move(player.global_transform,motion): return motion
	return wanted

static func _player_nav(t, area: IsoArea, original: LevelNav, target: Vector2) -> LevelNav:
	# Use the real player footprint against each deck's actual colliders.
	# NPC cardinal clearance can put a centre just inside a slanted rail;
	# changing authored geometry would conceal that controller mistake.
	# Double planning coordinates gives a 16 px physical grid without
	# changing production's 32 px schedule graph or its cache.
	var graph := original.data.duplicate(true)
	for level in graph.levels:
		level.centre *= 2
		level.rx *= 2
		level.ry *= 2
		for field in ["polygons","holes"]:
			for i in level[field].size(): level[field][i] = _scaled_polygon(level[field][i])
		for keepout in level.keepouts: keepout.polygon = _scaled_polygon(keepout.polygon)
	for bridge in graph.bridges:
		for field in ["a","b","gate_a","gate_b"]: bridge[field] *= 2
	for ladder in graph.ladders:
		ladder.bottom *= 2
		ladder.top *= 2
	var nav := LevelNav.make(graph)
	var registry := CityBuilder.of(area).registry
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := ConvexPolygonShape2D.new()
	var points := PackedVector2Array()
	for i in 12:
		var angle := TAU*i/12.0
		points.append(Vector2(cos(angle)*25,sin(angle)*14.8))
	shape.points = points
	query.shape = shape
	var space := area.get_world_2d().direct_space_state
	var exits := _warp_exclusions(t,area,target)
	for level in nav.levels:
		var authored := registry.get_level(StringName(level.id))
		query.collision_mask = Iso.LAYER_WORLD | authored.mask_bit()
		for y in level.grid.region.size.y:
			for x in level.grid.region.size.x:
				var cell := Vector2i(x,y)
				var point := nav._centre(level,cell)
				query.transform = Transform2D(0,area.to_global(Iso.to_screen(point/2)))
				var global_point := Iso.to_ground(query.transform.origin)
				level.grid.set_point_solid(cell,not nav._walkable(level,point) or not space.intersect_shape(query,1).is_empty() or exits.any(func(poly):return Geometry2D.is_point_in_polygon(global_point,poly)))
		# The larger player can split a deck into multiple components. Keep
		# its actual starting component available instead of snapping across
		# a hut into whichever component happens to contain the most cells.
		level.erase("main")
	for edge in nav._links.keys():
		if str(nav._links[edge].kind) == "walk": nav._links.erase(edge)
	for a in nav.gates.size():
		for b in range(a+1,nav.gates.size()):
			if nav.gates[a].level == nav.gates[b].level:
				nav._connect(a,b,nav._local(nav.gates[a].pos,nav.gates[b].pos,int(nav.gates[a].level)),"walk")
	return nav

static func _scaled_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in polygon: out.append(point*2)
	return out

static func _warp_exclusions(t, area: IsoArea, target: Vector2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for warp in t.tree.get_nodes_in_group("warp"):
		if not warp is Warp2D or not area.is_ancestor_of(warp) or warp.global_position.distance_to(target) < 1: continue
		var ground := PackedVector2Array()
		for child in warp.get_children():
			if child is CollisionPolygon2D:
				for point in child.polygon: ground.append(Iso.to_ground(child.to_global(point)))
			elif child is CollisionShape2D and child.shape is RectangleShape2D:
				var half: Vector2 = child.shape.size/2
				for point in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]: ground.append(Iso.to_ground(child.to_global(point)))
		if ground.size() >= 3:
			for polygon in Geometry2D.offset_polygon(ground,26): out.append(polygon)
	return out
