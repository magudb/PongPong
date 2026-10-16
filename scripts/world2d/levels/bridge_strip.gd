class_name BridgeStrip
extends RefCounted
## One rope bridge of a levelled area (package V3-levels): the plank deck, the two sagging rope rails with their posts, the rail
## colliders on the bridge's OWN physics bit, and the strip polygon the LevelRegistry uses for level_at.
##
##   deck     one Line2D (tiled plank texture, an ink outline Line2D under it) in the non-sorted `floors` node at z = rank - 4; it follows the
##            AUTHORED path, so an `under` end simply vanishes below the platform that covers it (that platform's floor has the higher rank)
##   rails    per side ONE rope Line2D and a Sprite2D post every POST_SPACING sketch px. The side that
##            is nearer to the camera (its normal points down the screen) is drawn OVER the actors of the bridge (container at z = rank + 1),
##            the far side behind them (z = rank - 3): no y-sort needed, and the sprites of one texture batch
##   collider ONE StaticBody2D under `colliders`, layer = the level's bit and nothing else: the two rail lines along the STRIP (the gate
##            path: authored path, trimmed one body radius before an `under` end), so the walker leaves the bridge exactly where the
##            tracker hands it to the platform; the platform's Railing continues the walls from the rim to the gate (wings)
## A STUB (a bridge piece that leaves the map, part of the platform it leaves from) is built by the same code: build_stub().
## The art is passed in: {"deck": Texture2D, "post": Texture2D}; LevelStage makes stand-ins, V5's real tiles drop in without a code change.

const POST_SPACING := 46.0              # sketch px along each side (the sketch draws ~70 posts on nine bridges)
const RAIL_HEIGHT := 24.0               # sketch px from the deck to the rope
const ROPE_WIDTH := 6.0
const OUTLINE := 10.0                   # extra width of the ink outline under the deck (world px)
const ROPE_COLOR := Color("2b2340")
const OUTLINE_COLOR := Color("2b2340")

var level: Level
var polygon: PackedVector2Array = PackedVector2Array()
var deck: Line2D
var outline: Line2D
var ropes: Array[Line2D] = []
var posts := PackedVector2Array()
var body: StaticBody2D
var post_count_per_side: int = 0
var is_stub: bool = false
var stub_id: StringName = &""

var _scale: float = 3.0


## A registered bridge level. nodes = {floors: Node2D, objects: Node2D, colliders: Node2D}.
static func build(nodes: Dictionary, lv: Level, registry: LevelRegistry, art: Dictionary = {}) -> BridgeStrip:
	var s := BridgeStrip.new()
	s._scale = registry.scale
	s.level = lv
	s.polygon = lv.regions[0] if not lv.regions.is_empty() else PackedVector2Array()
	s._make(nodes, lv.path, lv.gate_path, lv.width, lv.sag, lv.rank, lv.bit, StringName("Bridge_%s" % lv.id), art)
	return s


## A stub of a platform (registry.stubs record): rank and bit of the platform, rails from the rim crossing outwards.
static func build_stub(nodes: Dictionary, stub: Dictionary, platform: Level, registry: LevelRegistry, art: Dictionary = {}) -> BridgeStrip:
	var s := BridgeStrip.new()
	s._scale = registry.scale
	s.level = platform
	s.is_stub = true
	s.stub_id = stub["id"]
	s.polygon = stub["polygon"]
	var path: PackedVector2Array = stub["path"]
	# the rails start where the centre line crosses the ring (walk ellipse) of the platform: the Railing's wings meet them there
	var dir: Vector2 = (path[1] - path[0]).normalized()
	var t: float = LevelRegistry.ray_leaves_ellipse(path[0], dir, platform.centre, platform.rx * platform.inset, platform.ry * platform.inset)
	var rail_path := PackedVector2Array(path)
	rail_path[0] = path[0] + dir * t
	s._make(nodes, path, rail_path, stub["width"], stub["sag"], platform.rank, platform.bit, StringName("Stub_%s" % stub["id"]), art)
	return s


func _make(nodes: Dictionary, vis_path: PackedVector2Array, rail_path: PackedVector2Array, width: float, sag: float, rank: int, bit: int, label: StringName, art: Dictionary) -> void:
	var floors: Node2D = nodes["floors"]
	var colliders: Node2D = nodes["colliders"]
	# --- deck: ink outline first, plank line on top
	outline = Line2D.new()
	outline.name = "%s_Outline" % label
	outline.points = vis_path
	outline.width = width + OUTLINE
	outline.default_color = art.get("outline_color", OUTLINE_COLOR)
	outline.z_index = rank - 5
	outline.begin_cap_mode = Line2D.LINE_CAP_NONE
	outline.end_cap_mode = Line2D.LINE_CAP_NONE
	floors.add_child(outline)
	deck = Line2D.new()
	deck.name = "%s_Deck" % label
	deck.points = vis_path
	deck.width = width
	deck.default_color = Color.WHITE
	deck.z_index = rank - 4
	var tex: Texture2D = art.get("deck", null)
	if tex != null:
		deck.texture = tex
		deck.texture_mode = Line2D.LINE_TEXTURE_TILE
		deck.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	else:
		deck.default_color = Color("c9925a")
	floors.add_child(deck)
	# --- rails: posts and ropes on both sides of the visual path
	var total: float = 0.0
	for i in range(1, vis_path.size()):
		total += vis_path[i].distance_to(vis_path[i - 1])
	var spans: int = maxi(2, roundi(total / (POST_SPACING * _scale)))
	post_count_per_side = spans + 1
	var rail_h: float = RAIL_HEIGHT * _scale
	var post_tex: Texture2D = art.get("post", null)
	var overall: Vector2 = (vis_path[vis_path.size() - 1] - vis_path[0]).normalized()
	for side in [-1.0, 1.0]:
		var host := PostBatch.new()
		host.texture = post_tex
		host.name = "%s_Rail%s" % [label, "Near" if Vector2(-overall.y, overall.x).y * side >= 0.0 else "Far"]
		host.z_index = rank + 1 if Vector2(-overall.y, overall.x).y * side >= 0.0 else rank - 3
		floors.add_child(host)
		var bases: Array[Vector2] = []
		for step in range(spans + 1):
			var at: float = total * float(step) / float(spans)
			bases.append(_point_at(vis_path, at) + _normal_at(vis_path, at) * (side * width * 0.5))
		for b in bases:
			if post_tex != null:
				host.positions.append(b)
				posts.append(b)
		# the rope of this side: post top to post top with a sag in every span, ONE Line2D (the side is drawn as a whole over / behind the actors)
		var pts := PackedVector2Array()
		for j in range(spans + 1):
			pts.append(bases[j] + Vector2(0, -rail_h))
			if j < spans:
				pts.append((bases[j] + bases[j + 1]) * 0.5 + Vector2(0, -rail_h + sag))
		var rope := Line2D.new()
		rope.points = pts
		rope.width = ROPE_WIDTH
		rope.default_color = art.get("rope_color", ROPE_COLOR)
		rope.joint_mode = Line2D.LINE_JOINT_ROUND
		host.add_child(rope)
		ropes.append(rope)
	# --- collider: the two rails of the strip on the level's own bit
	body = StaticBody2D.new()
	body.name = "Rails_%s" % label
	body.collision_layer = 1 << (bit - 1)
	body.collision_mask = 0
	var segs := PackedVector2Array()
	for side in [-1.0, 1.0]:
		for i in range(1, rail_path.size()):
			var n0: Vector2 = _segment_normal(rail_path, i - 1)
			segs.append(rail_path[i - 1] + n0 * (side * width * 0.5))
			segs.append(rail_path[i] + n0 * (side * width * 0.5))
	var cs := CollisionShape2D.new()
	var sh := ConcavePolygonShape2D.new()
	sh.segments = segs
	cs.shape = sh
	body.add_child(cs)
	colliders.add_child(body)


## The point at arc length `d` of a polyline.
static func _point_at(line: PackedVector2Array, d: float) -> Vector2:
	var rest: float = d
	for i in range(1, line.size()):
		var seg: float = line[i].distance_to(line[i - 1])
		if rest <= seg or i == line.size() - 1:
			return line[i - 1].lerp(line[i], clampf(rest / maxf(seg, 0.0001), 0.0, 1.0))
		rest -= seg
	return line[line.size() - 1]


static func _normal_at(line: PackedVector2Array, d: float) -> Vector2:
	var rest: float = d
	for i in range(1, line.size()):
		var seg: float = line[i].distance_to(line[i - 1])
		if rest <= seg or i == line.size() - 1:
			return _segment_normal(line, i - 1)
		rest -= seg
	return _segment_normal(line, line.size() - 2)


static func _segment_normal(line: PackedVector2Array, i: int) -> Vector2:
	var d: Vector2 = (line[i + 1] - line[i]).normalized()
	return Vector2(-d.y, d.x)
