class_name LoopWalker
extends RefCounted
## Town loop real-input walker: walk the REAL player to a point with REAL movement actions.
##  * steering = proportional on the delta, converted to GROUND space (the player reads Input.get_vector in ground px, velocity = Iso.to_screen(ground),
##    player_stub_2d.gd:153-156), analog strengths through t.hold(action, strength), re-evaluated every physics tick;
##  * route = straight line when it is free, else an A* route on a grid baked from the PHYSICS space with the player's body (the NavGrid recipe of
##    design3 areas_interiors.md 10.4, 8.4 ms per 3,600 cells), smoothed by line-of-sight; builder areas (city, interiors) pass `waypoints` from loop.json.
## No teleport, no velocity poke: collisions, warps, interactables and the area clock behave as for a human.
const ACTIONS := {"left": &"move_left", "right": &"move_right", "up": &"move_forward", "down": &"move_back"}


static func _steer(t, d: Vector2, strength: float = 1.0) -> void:
	var g: Vector2 = Iso.to_ground(d)
	var v := g.normalized() * strength if g.length() > 0.001 else Vector2.ZERO
	t.hold(ACTIONS["right"], maxf(v.x, 0.0)) if v.x > 0.02 else t.release(ACTIONS["right"])
	t.hold(ACTIONS["left"], maxf(-v.x, 0.0)) if v.x < -0.02 else t.release(ACTIONS["left"])
	t.hold(ACTIONS["down"], maxf(v.y, 0.0)) if v.y > 0.02 else t.release(ACTIONS["down"])
	t.hold(ACTIONS["up"], maxf(-v.y, 0.0)) if v.y < -0.02 else t.release(ACTIONS["up"])


## A* over the cells of a GRID area, solid = not walkable ground OR the body (x1.4) overlaps a world/ground_block collider at the cell centre.
static func bake(t, area: IsoArea, body_scale: float = 1.4) -> AStarGrid2D:
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
	q.collision_mask = int(t.player().collision_mask)          # what the player really collides with (walking mask 197: world, npc, resource node, ground block)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			q.transform = Transform2D(0.0, area.cell_to_global(c))
			g.set_point_solid(c, (not area.is_walkable(c)) or not space.intersect_shape(q, 1).is_empty())
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


static func walk_to(t, target: Vector2, tol: float = 30.0, timeout_game_s: float = 40.0, waypoints: Array = []) -> Dictionary:
	var p: Node2D = t.player()
	var area: Variant = p.get("area") if p != null else null
	var pts: Array = waypoints.duplicate()
	var transits: Array[Dictionary] = []
	var used_nav := false
	var director: TownDirector = TownProbe.director(t)
	if pts.is_empty() and director != null and director.level_nav != null:
		var registry := CityBuilder.of(area).registry
		var a := registry.level_at(p.global_position)
		var b := registry.level_at(target)
		var ai := -1
		var bi := -1
		for index in director.level_nav.levels.size():
			if a != null and str(director.level_nav.levels[index].id) == str(a.id):
				ai = index
			if b != null and str(director.level_nav.levels[index].id) == str(b.id):
				bi = index
		var planned := director.level_nav.route(Iso.to_ground(area.to_local(p.global_position)), ai, Iso.to_ground(area.to_local(target)), bi)
		for point in planned.get("polyline", PackedVector2Array()):
			pts.append(area.to_global(Iso.to_screen(point)))
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
			if str(segment.kind) == "ladder":
				var start: Vector2 = area.to_global(Iso.to_screen(segment.polyline[0]))
				var finish: Vector2 = area.to_global(Iso.to_screen(segment.polyline[-1]))
				transits.append({"start": start, "finish": finish, "index": pts.find(finish), "to": str(director.level_nav.levels[int(segment.to_level)].id), "done": false})
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
			var g: AStarGrid2D = await bake(t, area as IsoArea, sc)
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
	var i := 0
	var ticks := 0
	var max_ticks := mini(2700, int(timeout_game_s * Engine.physics_ticks_per_second))
	var stuck := 0
	var last := p.global_position
	var arrived := false
	var interactions := 0
	while ticks < max_ticks and i < pts.size():
		if p == null or not is_instance_valid(p) or p.get("area") != area:
			break                                             # an area change is the point of walking onto a warp: the caller checks it
		var wp: Vector2 = pts[i]
		var lane_failed := false
		for transit in transits:
			if transit.done or int(transit.index) != i:
				continue
			# A route's ladder edge is a real E interaction, not a walk through
			# the deck wall. The production lane owns its tween, mask and lock.
			t.release_all()
			await t.physics(2) # Stop the approach before pressing E.
			ticks += 2
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
			transit.done = str(ActorLevel.level_id(p)) == str(transit.to) and p.global_position.distance_to(transit.finish) <= 2.0 and not host.climbing
			lane_failed = not transit.done
			if lane_failed:
				t.info("Ladder %s did not reach %s: position=%s entry=%s finish=%s level=%s" % [host.name, transit.to, p.global_position, transit.start, transit.finish, ActorLevel.level_id(p)])
		if lane_failed:
			stuck = 3
			break
		var d: Vector2 = wp - p.global_position
		var is_last: bool = i == pts.size() - 1
		var ladder_entry: bool = transits.any(func(transit: Dictionary) -> bool: return not transit.done and int(transit.index) == i + 1)
		var distance := Iso.to_ground(d).length()
		# City paths use a 32-ground-pixel grid. The old prototype's 36-screen-
		# pixel tolerance skipped several bends and cut into rails/keepouts.
		if distance <= (tol if is_last else 1.0 if ladder_entry else 8.0):
			if is_last:
				arrived = true
				break
			i += 1
			continue
		# ClimbLane's collision-aware approach needs the actual entry point.
		# Slow down there rather than coasting across an eight-pixel waypoint.
		_steer(t, d, clampf(distance / 48.0, 0.25, 1.0) if ladder_entry else 1.0)
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
	return {"ok": arrived or changed, "area_changed": changed, "ticks": ticks, "seconds": float(ticks) / Engine.physics_ticks_per_second, "dist_left": Iso.to_ground(target - p.global_position).length() if p != null and is_instance_valid(p) else -1.0, "stuck": stuck >= 3, "nav": used_nav, "waypoints": pts.size(), "waypoint_index": i, "position": p.global_position if is_instance_valid(p) else Vector2.INF, "next": pts[i] if i < pts.size() else target, "collider": collider, "interactions": interactions}
