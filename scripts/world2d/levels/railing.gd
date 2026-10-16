class_name Railing
extends RefCounted
## The rim of one platform of a levelled area (package V3-levels): a ring of posts and rope arcs, the colliders of the level and the
## gaps where bridges, stubs and the ladder land.
##
##   ring      the walk ellipse of the platform (inset 0.96) as a polyline of short segments, cut at every GAP: a gap is centred on the angle where
##             a landing crosses the rim and is `width / 2 / rx` wide to each side (rx = the platform's full world radius), so a body of 50 px
##             passes the narrowest bridge (84 px) with room to spare. Overlapping gaps merge.
##   wings     at an `under` bridge end (the platform's rim covers the bridge) and at a stub, a short wall on each side from the cut edge of the
##             gap to where the bridge's own rails begin (the gate, one body radius before the rim), so the walls are continuous across the
##             level change
##   keep-outs the keep-out shapes of the walk region (trunk circle, hut circles, props) as convex bodies, the shadow of the Upper deck on the
##             Torvet as a wall with a gap where the ladder lane crosses it
##   posts     a Sprite2D post every POST_SPACING sketch px along each arc and a rope Line2D between neighbours (sag SAG). The half of the ring
##             behind the platform's centre (y above it) is drawn BEHIND every actor of the level (container "RailBack" at z = rank - 3), the half in
##             front of it OVER them ("RailFront" at z = rank + 1): an actor inside the disc is always behind the front rail and in front of the
##             back one, so no per-node y-sort is needed and consecutive sprites of one texture batch into few draw calls
## ALL colliders sit on ONE StaticBody2D whose layer is THIS level's bit and nothing else - never the shared world bit: a hut of platform A must
## not block a walker on a bridge that passes behind it.

const POST_SPACING := 64.0              # sketch px along the ring
const RAIL_HEIGHT := 24.0               # sketch px
const SAG := 10.0                       # sketch px
const ROPE_WIDTH := 6.0
const ROPE_COLOR := Color("2b2340")
const RING_STEP := 0.1                  # rad, longest collider segment of the ring
const HULL_STEP := 40.0                 # px, longest collider segment of a keep-out wall
const MIN_ARC := 0.02

var level: Level
var gaps: Array[Dictionary] = []        # merged gaps {start, end, ids: Array[StringName]} in ellipse-parameter angles, sorted
var landing_gap_count: int = 0          # the landings the platform has (the gaps before merging)
var hull_gap_count: int = 0             # gaps of keep-out walls (the ladder lane through the Upper deck's shadow)
var arcs: Array[PackedVector2Array] = []
var posts := PackedVector2Array()
var ropes: Array[Line2D] = []
var back: Node2D
var front: Node2D
var wing_count: int = 0
var keepout_shapes: int = 0
var body: StaticBody2D
var walls_shape: ConcavePolygonShape2D
var rope_color: Color = ROPE_COLOR


## nodes = {floors: Node2D, colliders: Node2D}; art = {"post": Texture2D}
static func build(nodes: Dictionary, lv: Level, registry: LevelRegistry, art: Dictionary = {}) -> Railing:
	var r := Railing.new()
	r.level = lv
	r._make(nodes, registry, art)
	return r


func _make(nodes: Dictionary, registry: LevelRegistry, art: Dictionary) -> void:
	rope_color = art.get("rope_color", ROPE_COLOR)
	var floors: Node2D = nodes["floors"]
	var colliders: Node2D = nodes["colliders"]
	var scale: float = registry.scale
	var ring_rx: float = level.rx * level.inset
	var ring_ry: float = level.ry * level.inset
	var lands: Array = registry.landings_of(level.id)
	landing_gap_count = lands.size()
	gaps = _merge_gaps(lands, level.rx)
	# --- the ring as arcs between the gaps
	var arc_ranges: Array[Vector2] = []              # (from angle, to angle)
	if gaps.is_empty():
		arc_ranges.append(Vector2(-PI, PI))
	else:
		for i in gaps.size():
			var a0: float = gaps[i]["end"]
			var a1: float = gaps[(i + 1) % gaps.size()]["start"]
			if a1 <= a0:
				a1 += TAU
			if a1 - a0 > MIN_ARC:
				arc_ranges.append(Vector2(a0, a1))
	var segs := PackedVector2Array()
	for rg in arc_ranges:
		var n: int = maxi(2, ceili((rg.y - rg.x) / RING_STEP))
		var line := PackedVector2Array()
		for k in range(n + 1):
			line.append(LevelRegistry.ellipse_point(level.centre, ring_rx, ring_ry, lerpf(rg.x, rg.y, float(k) / float(n))))
		arcs.append(line)
		for k in range(n):
			segs.append(line[k])
			segs.append(line[k + 1])
	# --- wings
	for l in lands:
		var lrec: Dictionary = l
		var kind: StringName = lrec["kind"]
		if not (kind == &"stub" or (kind == &"bridge" and bool(lrec["under"]))):
			continue
		var dir: Vector2 = lrec["dir"]
		var nrm := Vector2(-dir.y, dir.x)
		var half_w: float = (lrec["width"] as float) * 0.5
		var gate: Vector2 = lrec["gate"]
		var ang: float = lrec["angle"]
		var half_a: float = lrec["half_angle"]
		var cuts: Array[Vector2] = [
			LevelRegistry.ellipse_point(level.centre, ring_rx, ring_ry, ang - half_a),
			LevelRegistry.ellipse_point(level.centre, ring_rx, ring_ry, ang + half_a),
		]
		for side in [-1.0, 1.0]:
			var tip: Vector2 = gate + nrm * (side * half_w)
			var best: Vector2 = cuts[0] if cuts[0].distance_to(tip) <= cuts[1].distance_to(tip) else cuts[1]
			segs.append(best)
			segs.append(tip)
			wing_count += 1
	# --- keep-out walls with ladder gaps (hull keep-outs only; the ellipse keep-outs are convex bodies)
	var shapes: Array[Shape2D] = []
	for ko in level.keepouts:
		if not bool(ko.get("collide", true)):
			continue
		if ko["kind"] == &"hull":
			var poly: PackedVector2Array = ko["polygon"]
			var in_gap: bool = false
			for i in poly.size():
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[(i + 1) % poly.size()]
				var pieces: int = maxi(1, ceili(a.distance_to(b) / HULL_STEP))
				for k in pieces:
					var p0: Vector2 = a.lerp(b, float(k) / float(pieces))
					var p1: Vector2 = a.lerp(b, float(k + 1) / float(pieces))
					if _in_ladder_gap(registry, (p0 + p1) * 0.5):
						if not in_gap:
							hull_gap_count += 1
						in_gap = true
						continue
					in_gap = false
					segs.append(p0)
					segs.append(p1)
		else:
			var cv := ConvexPolygonShape2D.new()
			cv.points = ko["polygon"]
			shapes.append(cv)
			keepout_shapes += 1
	# --- one body for the whole level, on THE LEVEL's bit only
	body = StaticBody2D.new()
	body.name = "Colliders_%s" % level.id
	body.collision_layer = level.mask_bit()
	body.collision_mask = 0
	if not segs.is_empty():
		walls_shape = ConcavePolygonShape2D.new()
		walls_shape.segments = segs
		var wcs := CollisionShape2D.new()
		wcs.name = "Walls"
		wcs.shape = walls_shape
		body.add_child(wcs)
	for sh in shapes:
		var cs := CollisionShape2D.new()
		cs.shape = sh
		body.add_child(cs)
	colliders.add_child(body)
	# --- posts and ropes along the arcs, into the two non-sorted containers
	var post_tex: Texture2D = art.get("post", null)
	var back_posts := PostBatch.new()
	back_posts.texture = post_tex
	back = back_posts
	back.name = "RailBack_%s" % level.id
	back.z_index = level.rank - 3
	floors.add_child(back)
	var front_posts := PostBatch.new()
	front_posts.texture = post_tex
	front = front_posts
	front.name = "RailFront_%s" % level.id
	front.z_index = level.rank + 1
	floors.add_child(front)
	var rail_h: float = RAIL_HEIGHT * scale
	var perimeter: float = _ellipse_perimeter(ring_rx, ring_ry)
	for rg in arc_ranges:
		var length: float = perimeter * (rg.y - rg.x) / TAU
		var count: int = maxi(2, roundi(length / (POST_SPACING * scale)) + 1)
		var bases: Array[Vector2] = []
		for k in count:
			bases.append(LevelRegistry.ellipse_point(level.centre, ring_rx, ring_ry, lerpf(rg.x, rg.y, float(k) / float(count - 1))))
		if absf((rg.y - rg.x) - TAU) < 0.001:
			bases.remove_at(bases.size() - 1)                    # a closed ring: the last post is the first one
		for k in bases.size():
			if post_tex != null:
				(front_posts if bases[k].y >= level.centre.y else back_posts).positions.append(bases[k])
				posts.append(bases[k])
		var pair_count: int = bases.size() - 1
		if absf((rg.y - rg.x) - TAU) < 0.001:
			pair_count = bases.size()
		# the rope runs from post to post with a sag in every span; spans in front of the platform's centre form one Line2D, spans behind it
		# another (a run changes where the arc crosses the centre line)
		var run := PackedVector2Array()
		var run_front: bool = false
		for k in pair_count:
			var p0: Vector2 = bases[k]
			var p1: Vector2 = bases[(k + 1) % bases.size()]
			var mid: Vector2 = (p0 + p1) * 0.5
			var is_front: bool = mid.y >= level.centre.y
			if not run.is_empty() and is_front != run_front:
				_add_rope(run, run_front)
				run = PackedVector2Array()
			run_front = is_front
			if run.is_empty():
				run.append(p0 + Vector2(0, -rail_h))
			run.append(mid + Vector2(0, -rail_h + SAG * scale))
			run.append(p1 + Vector2(0, -rail_h))
		if not run.is_empty():
			_add_rope(run, run_front)


func _add_rope(points: PackedVector2Array, in_front: bool) -> void:
	var rope := Line2D.new()
	rope.points = points
	rope.width = ROPE_WIDTH
	rope.default_color = rope_color
	rope.joint_mode = Line2D.LINE_JOINT_ROUND
	(front if in_front else back).add_child(rope)
	ropes.append(rope)


## Gaps of a platform: one per landing, centred on its rim angle, `width / 2 / rx` to each side; overlapping gaps merge.
static func _merge_gaps(lands: Array, full_rx: float) -> Array[Dictionary]:
	var raw: Array[Dictionary] = []
	for l in lands:
		var half: float = (l["width"] as float) * 0.5 / maxf(full_rx, 1.0)
		var start: float = fposmod((l["angle"] as float) - half + PI, TAU) - PI
		raw.append({"start": start, "end": start + 2.0 * half, "ids": [l["id"]]})
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["start"] as float) < (b["start"] as float))
	var out: Array[Dictionary] = []
	for g in raw:
		if not out.is_empty() and (g["start"] as float) <= (out[out.size() - 1]["end"] as float):
			var last: Dictionary = out[out.size() - 1]
			last["end"] = maxf(last["end"] as float, g["end"] as float)
			(last["ids"] as Array).append_array(g["ids"] as Array)
		else:
			out.append(g)
	return out


static func _ellipse_perimeter(a: float, b: float) -> float:
	return PI * (3.0 * (a + b) - sqrt((3.0 * a + b) * (a + 3.0 * b)))


## Is the point on a lane of a ladder (within half its width)? The shadow wall of the Upper deck is open there.
static func _in_ladder_gap(registry: LevelRegistry, p: Vector2) -> bool:
	for l in registry.ladders:
		var a: Vector2 = l["bottom"]
		var b: Vector2 = l["top"]
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) <= (l["width"] as float) * 0.5:
			return true
	return false


## The merged gap (index) an angle falls into, -1 when none.
func gap_at(angle: float) -> int:
	for i in gaps.size():
		var a: float = fposmod(angle - (gaps[i]["start"] as float), TAU)
		if a <= (gaps[i]["end"] as float) - (gaps[i]["start"] as float):
			return i
	return -1
