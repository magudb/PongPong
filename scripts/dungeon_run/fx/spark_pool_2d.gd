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
	if parent.get_node_or_null("SparkPool") != null: return
	var pool := Node2D.new()
	pool.name = "SparkPool"
	parent.add_child(pool)
	for i in CAP:
		var node := DungeonSpark2D.new()
		pool.add_child(node)
		node.finish()

static func play(parent: Node, at: Vector2, color: Color) -> DungeonSpark2D:
	warm(parent)
	var chosen: DungeonSpark2D = null
	for node in parent.get_node("SparkPool").get_children():
		if not node.active:
			chosen = node
			break
		if chosen == null or node.serial < chosen.serial: chosen = node
	_serial += 1
	chosen.serial = _serial
	chosen.age = 0
	chosen.tint = color
	chosen.global_position = at
	chosen.active = true
	chosen.visible = true
	chosen.set_process(true)
	return chosen

func finish() -> void:
	active = false
	visible = false
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
