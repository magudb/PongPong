class_name TelegraphRing2D
extends Node2D
## The telegraph and attack share ground-plane geometry, including the line's direction.
const CAP := 8
var shape_kind := "ring"
var radius: float = 90.0
var width: float = 60.0
var length: float = 280.0
var direction := Vector2.RIGHT
var duration: float = 0.5
var elapsed: float = 0.0
var active := false
var serial: int = 0
static var _serial: int = 0
func _ready() -> void:
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ink.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = ink

static func warm(parent: Node) -> void:
	if parent.get_node_or_null("TelegraphPool") != null: return
	var pool := Node2D.new()
	pool.name = "TelegraphPool"
	parent.add_child(pool)
	for i in CAP:
		var ring := TelegraphRing2D.new()
		ring.name = "Ring%d" % i
		pool.add_child(ring)
		ring.finish()

static func play(parent: Node, at: Vector2, params: Dictionary) -> TelegraphRing2D:
	warm(parent)
	var pool := parent.get_node("TelegraphPool")
	var chosen: TelegraphRing2D = null
	for node in pool.get_children():
		if not node.active:
			chosen = node
			break
		if chosen == null or node.serial < chosen.serial: chosen = node
	_serial += 1
	chosen.serial = _serial
	chosen.global_position = at
	chosen.configure(params)
	return chosen

func configure(params: Dictionary) -> void:
	shape_kind = str(params.get("shape","ring"))
	radius = maxf(1,float(params.get("radius",90)))
	width = maxf(1,float(params.get("width",60)))
	length = maxf(1,float(params.get("length",280)))
	direction = Vector2(params.get("direction",Vector2.RIGHT)).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	duration = maxf(.01,float(params.get("duration",.5)))
	elapsed = 0
	active = true
	visible = true
	# The GroundFx parent already owns global z=-9; doubling it hides warnings below the tiles.
	z_index = 0
	set_process(true)
	queue_redraw()

func finish() -> void:
	active = false
	visible = false
	set_process(false)

func hit_area() -> Dictionary:
	return {"shape":shape_kind,"radius":radius,"rect":Rect2(0,-width/2,length,width),"direction":direction}

func contains_ground(offset: Vector2) -> bool:
	return offset.length() <= radius if shape_kind == "ring" else Rect2(0,-width/2,length,width).has_point(offset.rotated(-direction.angle()))

func polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	if shape_kind == "ring":
		for i in 32: points.append(Iso.to_screen(Vector2.from_angle(TAU*i/32.0)*radius))
	else:
		for point in [Vector2(0,-width/2),Vector2(length,-width/2),Vector2(length,width/2),Vector2(0,width/2)]:
			points.append(Iso.to_screen(point.rotated(direction.angle())))
	return points

func _process(dt: float) -> void:
	elapsed += dt
	if elapsed >= duration:
		finish()
		return
	queue_redraw()

func _draw() -> void:
	if not active: return
	var hz := 2.0 if DungeonRun.assist("assist_reduce_flash") else 6.0
	var alpha := lerpf(.4,.8,clampf(elapsed/duration,0,1)) * (.85+.15*sin(elapsed*TAU*hz))
	var points := polygon()
	draw_colored_polygon(points,Color("fbf5e6",alpha*.18))
	points.append(points[0])
	draw_polyline(points,Color("fbf5e6",alpha),4,true)
