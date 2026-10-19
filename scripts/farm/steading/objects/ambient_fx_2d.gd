class_name FarmAmbientFx
extends Node2D
## Existing painted foliage, instanced on two bounded screen-space layers.
var world: Node
var canopy: TextureRect
var leaves: CPUParticles2D

static func create_marker(_params: Dictionary, _pos: Vector2, _cell: Vector2i, _area: IsoArea) -> Node:
	return FarmAmbientFx.new()

func _ready() -> void:
	world = get_tree().get_first_node_in_group("world_2d")
	var layer := CanvasLayer.new()
	layer.name = "CanopyFrame"
	layer.layer = 3
	add_child(layer)
	canopy = TextureRect.new()
	canopy.name = "PaintedCanopy"
	canopy.texture = load("res://assets/backdrops/farm_canopy.webp")
	canopy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	canopy.stretch_mode = TextureRect.STRETCH_SCALE
	canopy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canopy.visible = bool(GameManager.config_value("farm_site.fx.canopy_frame", true))
	layer.add_child(canopy)
	var fx := CanvasLayer.new()
	fx.name = "LeafFx"
	fx.layer = 4
	add_child(fx)
	leaves = CPUParticles2D.new()
	leaves.name = "PaintedLeaves"
	var cap := clampi(int(GameManager.config_value("farm_site.fx.leaves_max", 16)), 0, 16)
	leaves.amount = maxi(1, cap)
	leaves.emitting = cap > 0
	leaves.lifetime = 9
	leaves.preprocess = 9
	var texture := AtlasTexture.new()
	texture.atlas = canopy.texture
	texture.region = Rect2(80, 294, 32, 28)
	texture.filter_clip = true
	leaves.texture = texture
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.direction = Vector2(-0.55, 1)
	leaves.spread = 18
	leaves.initial_velocity_min = 45
	leaves.initial_velocity_max = 85
	leaves.angular_velocity_min = -90
	leaves.angular_velocity_max = 90
	leaves.scale_amount_min = 0.35
	leaves.scale_amount_max = 0.7
	leaves.color = Color(1, 1, 1, 0.9)
	fx.add_child(leaves)
	get_viewport().size_changed.connect(_resize)
	_resize()
	Svc.static_call("res://scripts/farm/steading/dress/seasonal_fx.gd", &"attach", [self])

func _enter_tree() -> void:
	if is_node_ready():
		get_viewport().size_changed.connect(_resize)
		_resize()

func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_resize):
		get_viewport().size_changed.disconnect(_resize)

func _resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var height := viewport.x * 360.0 / 2048.0
	canopy.size = Vector2(viewport.x, height)
	canopy.position = Vector2(0, -height * 0.28)
	leaves.position = Vector2(viewport.x * 0.6, -20)
	leaves.emission_rect_extents = Vector2(viewport.x * 0.7, 6)

## The canopy and the falling leaves sit on their own CanvasLayers, which the world's CanvasModulate does not reach: both copy its colour
## (review REND-01). Summer's fireflies are additive light (a material) and keep their own glow.
func _process(_delta: float) -> void:
	if not is_instance_valid(world) or world.day_night == null:
		return
	var tint: Color = world.day_night.color
	if canopy.modulate != tint:
		canopy.modulate = tint
	if is_instance_valid(leaves):
		var leaf_tint: Color = Color.WHITE if leaves.material != null else tint
		if leaves.modulate != leaf_tint:
			leaves.modulate = leaf_tint
