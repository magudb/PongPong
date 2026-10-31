class_name DungeonSpark2D
extends Node2D
## Twelve deterministic motes per burst; the area's small pool owns their whole lifetime.
const CAP := 12
var active := false
var age: float = 0
var tint := Color.WHITE
var serial: int = 0
static var _serial: int = 0
func _ready() -> void:
	var glow := CanvasItemMaterial.new()
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow

static func warm(parent: Node) -> void:
	warm_owned(parent, func(): return true)

static func _pool_current(parent: WeakRef, pool: WeakRef, current: Callable) -> bool:
	if not current.call(): return false
	var p: Variant = parent.get_ref()
	var q: Variant = pool.get_ref()
	return is_instance_valid(p) and is_instance_valid(q) and not p.is_queued_for_deletion() and not q.is_queued_for_deletion() and q.get_parent() == p and p.get_node_or_null("SparkPool") == q

static func warm_owned(parent: Node, current: Callable) -> void:
	if not current.call() or not is_instance_valid(parent) or parent.is_queued_for_deletion(): return
	var owner: WeakRef = weakref(parent)
	var pool: Node = parent.get_node_or_null("SparkPool")
	if pool == null:
		pool = Node2D.new()
		pool.name = "SparkPool"
		parent.add_child(pool)
	var ref: WeakRef = weakref(pool)
	if not _pool_current(owner, ref, current): return
	# A reentrant current play may already have filled a partially warm pool.
	while pool.get_child_count() < CAP:
		var node := DungeonSpark2D.new()
		node.visible = false
		node.set_process(false)
		pool.add_child(node)
		if not _pool_current(owner, ref, current): return

static func play(parent: Node, at: Vector2, color: Color) -> DungeonSpark2D:
	return play_owned(parent, at, color, func(): return true)

static func play_owned(parent: Node, at: Vector2, color: Color, current: Callable) -> DungeonSpark2D:
	if not current.call() or not is_instance_valid(parent): return null
	var owner: WeakRef = weakref(parent)
	warm_owned(parent, current)
	if not current.call() or not is_instance_valid(owner.get_ref()): return null
	var pool: Node = owner.get_ref().get_node_or_null("SparkPool")
	if pool == null: return null
	var ref: WeakRef = weakref(pool)
	if not _pool_current(owner, ref, current): return null
	var chosen: DungeonSpark2D = null
	for node in pool.get_children():
		if not node.active:
			chosen = node
			break
		if chosen == null or node.serial < chosen.serial: chosen = node
	if chosen == null: return null
	_serial += 1
	chosen.serial = _serial
	var lease := chosen.serial
	var slot: WeakRef = weakref(chosen)
	chosen.age = 0
	chosen.tint = color
	chosen.global_position = at
	if not _pool_current(owner, ref, current) or not is_instance_valid(slot.get_ref()) or chosen.serial != lease: return null
	chosen.active = true
	chosen.visible = true
	if not _pool_current(owner, ref, current) or not is_instance_valid(slot.get_ref()) or chosen.serial != lease:
		if is_instance_valid(slot.get_ref()): slot.get_ref().finish_owned(lease)
		return null
	chosen.set_process(true)
	return chosen

func finish() -> void:
	finish_owned(serial)

func finish_owned(lease: int) -> void:
	if serial != lease: return
	active = false
	visible = false
	if serial != lease: return
	set_process(false)

func _process(dt: float) -> void:
	age += dt
	if age >= .45: finish()
	else: queue_redraw()

func _draw() -> void:
	if not active: return
	var fade := 1.0-age/.45
	for i in 12:
		var angle := i*TAU/12+.17
		var point := Vector2.from_angle(angle)*(8+age*(90+i*7))
		point.y -= 50*age
		draw_circle(point,6*fade,Color(tint,fade*.18))
		draw_circle(point,2.5*fade,Color(tint,fade))
