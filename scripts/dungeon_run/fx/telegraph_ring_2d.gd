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
var _owner: WeakRef
var serial: int = 0
static var _serial: int = 0
func _ready() -> void:
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ink.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = ink

static func warm(parent: Node) -> void:
	warm_owned(parent, func(): return true)

static func _pool_current(parent: WeakRef, pool: WeakRef, current: Callable) -> bool:
	if not current.call(): return false
	var p: Variant = parent.get_ref()
	var q: Variant = pool.get_ref()
	return is_instance_valid(p) and is_instance_valid(q) and not p.is_queued_for_deletion() and not q.is_queued_for_deletion() and q.get_parent() == p and p.get_node_or_null("TelegraphPool") == q

static func _slot_attached(slot: WeakRef, pool: WeakRef, lease: int) -> bool:
	var node: Variant = slot.get_ref()
	var owner: Variant = pool.get_ref()
	return is_instance_valid(node) and is_instance_valid(owner) and not node.is_queued_for_deletion() and node.is_inside_tree() and node.get_parent() == owner and node.serial == lease

static func _slot_current(parent: WeakRef, pool: WeakRef, slot: WeakRef, lease: int, current: Callable) -> bool:
	return _pool_current(parent,pool,current) and _slot_attached(slot,pool,lease)

static func warm_owned(parent: Node, current: Callable) -> void:
	if not current.call() or not is_instance_valid(parent) or parent.is_queued_for_deletion(): return
	var owner: WeakRef = weakref(parent)
	var pool: Node = parent.get_node_or_null("TelegraphPool")
	var fresh := pool == null
	if fresh:
		pool = Node2D.new()
		pool.name = "TelegraphPool"
	var ref: WeakRef = weakref(pool)
	if fresh: parent.add_child(pool)
	if not _pool_current(owner,ref,current): return
	while pool.get_child_count() < CAP:
		var ring := TelegraphRing2D.new()
		ring.name = "Ring%d" % pool.get_child_count()
		ring.visible = false
		ring.set_process(false)
		pool.add_child(ring)
		if not _pool_current(owner,ref,current): return

static func play(parent: Node, at: Vector2, params: Dictionary) -> TelegraphRing2D:
	return play_owned(parent,at,params,func(): return true)

static func play_owned(parent: Node, at: Vector2, params: Dictionary, current: Callable) -> TelegraphRing2D:
	if not current.call() or not is_instance_valid(parent): return null
	var owner: WeakRef = weakref(parent)
	warm_owned(parent,current)
	if not current.call() or not is_instance_valid(owner.get_ref()): return null
	var pool: Node = owner.get_ref().get_node_or_null("TelegraphPool")
	if pool == null: return null
	var ref: WeakRef = weakref(pool)
	if not _pool_current(owner,ref,current): return null
	var chosen: TelegraphRing2D = null
	for node in pool.get_children():
		if node.is_queued_for_deletion() or not node.is_inside_tree(): continue
		if not node.active:
			chosen = node
			break
	# A live warning is a gameplay promise: saturation delays the producer.
	if chosen == null: return null
	_serial += 1
	chosen.serial = _serial
	var lease := chosen.serial
	var slot: WeakRef = weakref(chosen)
	chosen.global_position = at
	if not _slot_current(owner,ref,slot,lease,current): return null
	var attached := _slot_attached.bind(slot,ref,lease)
	chosen._configure_owned(params,func(): return _slot_current(owner,ref,slot,lease,current),lease,attached)
	if not _slot_current(owner,ref,slot,lease,current) or not chosen.active or not chosen.visible: return null
	return chosen

func configure(params: Dictionary) -> void:
	_configure_owned(params,func(): return true,serial)

func _configure_owned(params: Dictionary, current: Callable, lease: int, attached: Callable = Callable()) -> void:
	if serial != lease or not current.call(): return
	shape_kind = str(params.get("shape","ring"))
	radius = maxf(1,float(params.get("radius",90)))
	width = maxf(1,float(params.get("width",60)))
	length = maxf(1,float(params.get("length",280)))
	direction = Vector2(params.get("direction",Vector2.RIGHT)).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	duration = maxf(.01,float(params.get("duration",.5)))
	elapsed = 0
	var owner: Node = params.get("owner")
	_owner = weakref(owner) if owner!=null else null
	active = true
	visible = true
	if serial != lease or not active or not visible or not current.call():
		if not attached.is_valid() or attached.call(): finish_owned(lease)
		return
	# The GroundFx parent already owns global z=-9.
	z_index = 0
	set_process(true)
	queue_redraw()

func finish() -> void:
	finish_owned(serial)

func finish_owned(lease: int) -> void:
	if serial != lease: return
	# Retire BEFORE visibility observers: finish-only cannot resume activation,
	# and a callback's newer globally unique lease must not be disabled here.
	_serial += 1
	serial = _serial
	var retired := serial
	active = false
	visible = false
	if serial != retired: return
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
	# Gameplay owners finish their own warning when their simulation reaches
	# impact/cancellation. Hit-stop and modals can outlast a wall-time lease.
	if _owner!=null:
		var owner: Node = _owner.get_ref()
		if owner==null or not owner.is_inside_tree():finish()
		else:queue_redraw()
		return
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
