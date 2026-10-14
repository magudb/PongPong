class_name Level
extends RefCounted
## One level of a levelled builder area (package V3-levels): a walkable deck of the treetop city, either a PLATFORM (a round disc around
## a trunk) or a BRIDGE (the strip of a rope bridge). A level owns
##   * `rank`  the z_index of everything that stands on it (floors rank - 4, shadows rank - 2, lower trunks rank - 6),
##   * `bit`   its physics layer number (12.., see LevelRegistry.FIRST_BIT); every collider of the level lives on THAT bit only,
##   * the walk region in WORLD px (screen plane): `regions` (outer polygons) minus `holes` (keep-outs), plus `pads` (landing pads and
##     bridge stubs). `contains(p)` is the whole truth; `priority` decides where two levels overlap (a bridge strip wins, 1 > 0).
## Records are built by LevelRegistry from data/traetoppen/traetoppen.json; nothing here touches a node.

var id: StringName = &""
var kind: StringName = &"platform"          # &"platform" | &"bridge"
var rank: int = 0
var bit: int = 0                            # physics layer NUMBER (1-based); the bit VALUE is mask_bit()
var priority: int = 0
var tree: StringName = &""
var painted_z: float = 0.0                  # the sketch's painted height (data only, not used by the maths)
var centre: Vector2 = Vector2.ZERO          # platform: centre of the disc; bridge: middle of the centre line
var rx: float = 0.0                         # platform: world radii of the FULL ellipse (rim included)
var ry: float = 0.0
var rim: float = 0.0                        # rim (skirt) thickness, world px
var inset: float = 1.0                      # platform: the walk ellipse is the full one x inset
var regions: Array[PackedVector2Array] = []
var holes: Array[PackedVector2Array] = []
var pads: Array[PackedVector2Array] = []
var keepouts: Array[Dictionary] = []        # platform: {ref, kind, polygon, c, rx, ry, collide} resolved keep-outs (also the collider shapes)
# --- bridges
var from_id: StringName = &""
var to_id: StringName = &""
var path: PackedVector2Array = PackedVector2Array()      # the centre line as authored (world px), path[0] on `from_id`
var gate_path: PackedVector2Array = PackedVector2Array() # the centre line of the STRIP (trimmed at tucked ends)
var width: float = 0.0
var sag: float = 0.0
var ends: Array[StringName] = []            # per end: &"over" (the bridge lies over the disc) | &"under" (the disc's rim covers the bridge)
var rim_points: Array[Vector2] = []         # per end: where the centre line crosses the full ellipse of the end's platform

## Bounding box of the whole walk region (regions and pads): the registry tests it before it calls contains().
var bounds: Rect2 = Rect2()

var _rects: Array[Rect2] = []
var _hole_rects: Array[Rect2] = []
var _pad_rects: Array[Rect2] = []


## Caches the bounding boxes; the registry calls it once the polygons are final.
func finalize() -> void:
	_rects.clear()
	_hole_rects.clear()
	_pad_rects.clear()
	for p in regions:
		_rects.append(bounds_of(p))
	for p in holes:
		_hole_rects.append(bounds_of(p))
	for p in pads:
		_pad_rects.append(bounds_of(p))
	var all := Rect2()
	var first: bool = true
	for r in _rects + _pad_rects:
		all = r if first else all.merge(r)
		first = false
	bounds = all


static func bounds_of(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r := Rect2(poly[0], Vector2.ZERO)
	for i in range(1, poly.size()):
		r = r.expand(poly[i])
	return r


## The physics layer VALUE of this level (1 << (bit - 1)).
func mask_bit() -> int:
	return 1 << (bit - 1)


func is_bridge() -> bool:
	return kind == &"bridge"


## Is the world point on this level (inside a region and outside every hole, or inside a pad)?
func contains(p: Vector2) -> bool:
	for i in pads.size():
		if _pad_rects[i].has_point(p) and Geometry2D.is_point_in_polygon(p, pads[i]):
			return true
	var inside: bool = false
	for i in regions.size():
		if _rects[i].has_point(p) and Geometry2D.is_point_in_polygon(p, regions[i]):
			inside = true
			break
	if not inside:
		return false
	for i in holes.size():
		if _hole_rects[i].has_point(p) and Geometry2D.is_point_in_polygon(p, holes[i]):
			return false
	return true


## Inside the full ellipse of a platform (rim included): the disc the art draws, not only the walk region. Bridges: the strip.
func contains_disc(p: Vector2) -> bool:
	if kind == &"bridge":
		return contains(p)
	if rx <= 0.0 or ry <= 0.0:
		return false
	var d := (p - centre) / Vector2(rx, ry)
	return d.length_squared() <= 1.0


## Normalised radius of a point against the full ellipse (1.0 = the rim); platforms only.
func norm_radius(p: Vector2) -> float:
	if rx <= 0.0 or ry <= 0.0:
		return INF
	return ((p - centre) / Vector2(rx, ry)).length()


## Every outer polygon of the walk region, pads included (for planners and overlays).
func all_polygons() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append_array(regions)
	out.append_array(pads)
	return out


## Area of the walk region of the outer polygons minus the holes (px^2; holes are assumed to lie inside the outers).
func walk_area() -> float:
	var a: float = 0.0
	for p in regions:
		a += absf(polygon_area(p))
	for h in holes:
		a -= absf(polygon_area(h))
	return maxf(a, 0.0)


static func polygon_area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	var n: int = poly.size()
	for i in n:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return a * 0.5
