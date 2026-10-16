extends RefCounted
## Builds a walk-in room in a far-away holder and asks the REAL physics space about it (package T-towns-core): the flood fill with the real colliders, walking bodies, the E-query. The holder sits at
## FAR so nothing of the live world is in the way; positions are global. Used by the section towns_interiors (and by T-interiors-core / T-director for the 14 core rooms).
##   var p = await Probe.new().build(t, "int_froebutikken")      # IsoArea (setup done, two physics frames passed)
##   p.reach(Iso.MASK_WALKING, spawn_cell)                       Dictionary cell -> true: what a PLAYER can walk to
##   p.reach(Probe.CITIZEN_MASK, spawn_cell)                     the same for a citizen (the hatch is open)
## The probe frees its holder in dispose().

const FAR := Vector2(600000.0, 600000.0)
const BODY_RX := 25.0
const BODY_RY := 14.8
## What a citizen collides with: the world and the player, NOT the NPC layer (the hatch bars are on it).
const CITIZEN_MASK := Iso.LAYER_WORLD | Iso.LAYER_PLAYER | Iso.LAYER_GROUND_BLOCK

var t
var holder: Node2D
var area: IsoArea
var spec: Dictionary = {}
var cols: int = 0
var rows: int = 0
var build_ms: float = 0.0
# Geometry/counter-contract probes inject their own keeper. Production world
# entries and T-director tests exercise the actual scheduled population.
var populate_citizens := false
var _shape: ConvexPolygonShape2D


## Builds the room `room_id` (spec from InteriorRoom.spec_dirs) as an area under the holder; returns the area (null when the spec is missing).
func build(p_t, room_id: String, zone: String = "city") -> IsoArea:
	t = p_t
	spec = InteriorRoom.load_spec(room_id)
	if spec.is_empty():
		return null
	cols = int(spec["cols"])
	rows = int(spec["rows"])
	holder = Node2D.new()
	holder.position = FAR
	t.root.add_child(holder)
	area = IsoArea.new()
	holder.add_child(area)
	var t0: int = Time.get_ticks_usec()
	area.set_meta("town_population_enabled", populate_citizens)
	area.setup(AreaMap.parse_text(InteriorRoom.stub_map(room_id, str(spec["building"]), zone)))
	build_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	await t.physics(2)
	return area


func dispose() -> void:
	if holder != null and is_instance_valid(holder):
		if holder.get_parent() != null:
			holder.get_parent().remove_child(holder)
		holder.free()
	holder = null
	area = null


## Global position of a (possibly fractional) cell centre of the room.
func cell_global(x: float, z: float) -> Vector2:
	return area.to_global(InteriorRoom.cell_local(x, z))


## Is a body of the player's size at this global position blocked for `mask`?
func blocked(pos: Vector2, mask: int) -> bool:
	if _shape == null:
		_shape = ConvexPolygonShape2D.new()
		var pts := PackedVector2Array()
		for i in 12:
			var a: float = TAU * float(i) / 12.0
			pts.append(Vector2(cos(a) * BODY_RX, sin(a) * BODY_RY))
		_shape.points = pts
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape
	q.transform = Transform2D(0.0, pos)
	q.collision_mask = mask
	q.collide_with_bodies = true
	q.collide_with_areas = false
	return not area.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


## Cells a body reaches from `start` (4-neighbour flood fill over the room's cells; a step needs both cell centres AND the point between them free).
func reach(mask: int, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + (d as Vector2i)
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows or seen.has(n):
				continue
			if blocked(cell_global(float(n.x), float(n.y)), mask) or blocked(cell_global(float(c.x + n.x) * 0.5, float(c.y + n.y) * 0.5), mask):
				continue
			seen[n] = true
			stack.append(n)
	return seen


## The cells of a shortest walk (BFS) from `from` to `to`, [] when there is none.
func path(mask: int, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var parent: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == to:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + (d as Vector2i)
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows or parent.has(n):
				continue
			if blocked(cell_global(float(n.x), float(n.y)), mask) or blocked(cell_global(float(c.x + n.x) * 0.5, float(c.y + n.y) * 0.5), mask):
				continue
			parent[n] = c
			queue.append(n)
	var out: Array[Vector2i] = []
	if not parent.has(to):
		return out
	var cur: Vector2i = to
	while cur != from:
		out.push_front(cur)
		cur = parent[cur]
	out.push_front(from)
	return out


## A walking body with the 12-gon ellipse of a figure on `layer`, colliding with `mask`, parked in the area's Objects at a global position.
func make_body(mask: int, layer: int, at: Vector2) -> CharacterBody2D:
	var b := CharacterBody2D.new()
	b.collision_layer = layer
	b.collision_mask = mask
	b.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		var ang: float = TAU * float(k) / 12.0
		pts.append(Vector2(cos(ang) * BODY_RX, sin(ang) * BODY_RY))
	sh.points = pts
	cs.shape = sh
	b.add_child(cs)
	area.objects.add_child(b)
	b.global_position = at
	return b


## Moves `body` along global waypoints at `speed` ground px / s for at most `max_frames` physics frames (it gives up after 15 frames without moving: a body that is stopped by a collider);
## returns the frames used.
func walk(body: CharacterBody2D, waypoints: Array[Vector2], speed: float, max_frames: int) -> int:
	var wi: int = 0
	var f: int = 0
	var still: int = 0
	while f < max_frames and wi < waypoints.size() and still < 15:
		var dv: Vector2 = Iso.to_ground(waypoints[wi] - body.global_position)
		if dv.length() < 12.0:
			wi += 1
			continue
		body.velocity = Iso.to_screen(dv.normalized() * speed)
		var before: Vector2 = body.global_position
		body.move_and_slide()
		await t.physics(1)
		f += 1
		still = still + 1 if body.global_position.distance_to(before) < 0.2 else 0
	return f
