class_name NavGrid
extends RefCounted
## Town navigation service of the `NavGrid` service (towns track package T-navgrid): an AStarGrid2D over the iso cells of one area, baked from the
## PHYSICS SPACE with the real NPC body inflated x1.4 (analyst 1, areas_interiors.md 10.4: 0 stuck events in 7,200 frames x 30 agents), diagonals only
## when both neighbours are free, line-of-sight smoothing with 0.9 cell clearance. Path = PackedVector2Array of GLOBAL px, length in GROUND px.
## Interiors use `from_cells` (a cell grid built from the room spec: no physics needed, 0.1 ms).

const BODY_RX := 25.0
const BODY_RY := 14.8
const INFLATE := 1.4
const CLEARANCE := 0.9
const ORTHO_STEP := 90.5      # ground px of one cell step along a map axis (iso.gd: 64 x 38 screen px)
const DIAG_STEP := 128.0

var area: IsoArea
var astar: AStarGrid2D
var blocked: Dictionary = {}   # Vector2i -> true
var size: Vector2i = Vector2i.ZERO
var bake_us: int = 0
var _origin: Vector2 = Vector2.ZERO       # interior grids only (cell centre = origin + cell * step)


## Bake from a built IsoArea that is in the tree (two physics frames have run). mask = what blocks an NPC (world | ground_block).
static func bake_area(a: IsoArea, mask: int = -1) -> NavGrid:
	var n := NavGrid.new()
	n.area = a
	var t0: int = Time.get_ticks_usec()
	n.size = Vector2i(a.map.width, a.map.height)
	n.astar = AStarGrid2D.new()
	n.astar.region = Rect2i(0, 0, n.size.x, n.size.y)
	n.astar.cell_size = Vector2.ONE
	n.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	n.astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	n.astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	n.astar.update()
	var space: PhysicsDirectSpaceState2D = a.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var sh := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		var ang: float = TAU * float(k) / 12.0
		pts.append(Vector2(cos(ang) * BODY_RX * INFLATE, sin(ang) * BODY_RY * INFLATE))
	sh.points = pts
	q.shape = sh
	q.collision_mask = (Iso.LAYER_WORLD | Iso.LAYER_GROUND_BLOCK) if mask < 0 else mask
	for y in n.size.y:
		for x in n.size.x:
			var c := Vector2i(x, y)
			var hit: bool = not a.is_walkable(c) and a.map.ground_at(c) != "="
			if not hit:
				q.transform = Transform2D(0.0, a.cell_to_global(c))
				hit = not space.intersect_shape(q, 1).is_empty()
			if hit:
				n.blocked[c] = true
				n.astar.set_point_solid(c, true)
	n.bake_us = Time.get_ticks_usec() - t0
	return n


## Bake a builder room (no map grid): cols x rows cells at Iso.iso_center. mask = what blocks the walker: the NPC mask is world | ground_block (the hatch bars are on
## layer NPC, so citizens pass them), the player mask adds LAYER_NPC (the hatch stops him).
static func bake_room(a: IsoArea, cols: int, rows: int, mask: int) -> NavGrid:
	var n := NavGrid.new()
	n.area = a
	var t0: int = Time.get_ticks_usec()
	n.size = Vector2i(cols, rows)
	n.astar = AStarGrid2D.new()
	n.astar.region = Rect2i(0, 0, cols, rows)
	n.astar.cell_size = Vector2.ONE
	n.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	n.astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	n.astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	n.astar.update()
	var space: PhysicsDirectSpaceState2D = a.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var sh := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for k in 12:
		var ang: float = TAU * float(k) / 12.0
		pts.append(Vector2(cos(ang) * BODY_RX * 1.0, sin(ang) * BODY_RY * 1.0))   # rooms: the plain body (a room is walked by hand-placed cells, no house-pad problem)
	sh.points = pts
	q.shape = sh
	q.collision_mask = mask
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			q.transform = Transform2D(0.0, a.cell_to_global(c))
			if not space.intersect_shape(q, 1).is_empty():
				n.blocked[c] = true
				n.astar.set_point_solid(c, true)
	n.bake_us = Time.get_ticks_usec() - t0
	return n


## A room grid: cols x rows, `solid` = cells of floor pieces (+ hatch cells when `with_hatch`), centres at (origin + cell * (ORTHO_STEP)).
static func from_cells(cols: int, rows: int, solid: Array, origin: Vector2 = Vector2.ZERO) -> NavGrid:
	var n := NavGrid.new()
	var t0: int = Time.get_ticks_usec()
	n.size = Vector2i(cols, rows)
	n.astar = AStarGrid2D.new()
	n.astar.region = Rect2i(0, 0, cols, rows)
	n.astar.cell_size = Vector2.ONE
	n.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	n.astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	n.astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	n.astar.update()
	n._origin = origin
	for c in solid:
		var cc := Vector2i(c)
		if cc.x >= 0 and cc.y >= 0 and cc.x < cols and cc.y < rows:
			n.blocked[cc] = true
			n.astar.set_point_solid(cc, true)
	n.bake_us = Time.get_ticks_usec() - t0
	return n


func cell_pos(c: Vector2i) -> Vector2:
	if area != null:
		return area.cell_to_global(c)
	return Iso.iso_center(c) + _origin


func force_free(c: Vector2i) -> void:
	blocked.erase(c)
	if astar.is_in_boundsv(c):
		astar.set_point_solid(c, false)


func nearest_free(c: Vector2i) -> Vector2i:
	if astar.is_in_boundsv(c) and not blocked.has(c):
		return c
	var best := c
	var bd: float = INF
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cc := c + Vector2i(dx, dy)
				if astar.is_in_boundsv(cc) and not blocked.has(cc):
					var d: float = float(dx * dx + dy * dy)
					if d < bd:
						bd = d
						best = cc
		if bd < INF:
			break
	return best


func _los(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	var n: int = maxi(absi(d.x), absi(d.y))
	var perp := Vector2(-d.y, d.x).normalized() * CLEARANCE
	for i in range(n + 1):
		var t: float = float(i) / float(maxi(n, 1))
		var p := Vector2(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t))
		if blocked.has(Vector2i(roundi(p.x), roundi(p.y))):
			return false
		if blocked.has(Vector2i(roundi((p + perp).x), roundi((p + perp).y))) or blocked.has(Vector2i(roundi((p - perp).x), roundi((p - perp).y))):
			return false
	return true


## Cell path (smoothed) between two cells; empty when unreachable.
func cell_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var raw: Array[Vector2i] = astar.get_id_path(nearest_free(a), nearest_free(b))
	if raw.size() <= 2:
		return raw
	var out: Array[Vector2i] = [raw[0]]
	var i: int = 0
	while i < raw.size() - 1:
		var j: int = raw.size() - 1
		while j > i + 1 and not _los(raw[i], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	return out


## Global-px polyline and its length in ground px.
func path(a: Vector2i, b: Vector2i) -> Dictionary:
	var cp: Array[Vector2i] = cell_path(a, b)
	var pl := PackedVector2Array()
	var len_g: float = 0.0
	for k in cp.size():
		var p: Vector2 = cell_pos(cp[k])
		pl.append(p)
		if k > 0:
			len_g += Iso.to_ground(p - cell_pos(cp[k - 1])).length()
	return {"polyline": pl, "length": len_g, "ok": not cp.is_empty()}


## Reachable cells (4-neighbour flood) from a cell: the validator `nav.every_post_reachable` uses it.
func reachable_from(c: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	var s: Vector2i = nearest_free(c)
	var stack: Array[Vector2i] = [s]
	seen[s] = true
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for st in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + st
			if astar.is_in_boundsv(nx) and not blocked.has(nx) and not seen.has(nx):
				seen[nx] = true
				stack.append(nx)
	return seen
