@tool
extends ColorRect
## Striped placeholder / backdrop (guide: repeating-linear-gradient(135deg ...)) with optional
## rounded corners and ink border, all drawn by shaders/stripes.gdshader. Real art replaces it by
## hiding this node or putting a TextureRect above it.

const SHADER := preload("res://shaders/stripes.gdshader")

@export var color_a: Color = Color("#cde0a6"):
	set(v):
		color_a = v
		_push()
@export var color_b: Color = Color("#bfd694"):
	set(v):
		color_b = v
		_push()
@export var band: float = 14.0:
	set(v):
		band = v
		_push()
## top-left, top-right, bottom-right, bottom-left
@export var radii := Vector4(0, 0, 0, 0):
	set(v):
		radii = v
		_push()
@export var border: float = 0.0:
	set(v):
		border = v
		_push()

var _mat: ShaderMaterial


func _init() -> void:
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(_push)
	_push()


func _push() -> void:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		material = _mat
	_mat.set_shader_parameter("color_a", color_a)
	_mat.set_shader_parameter("color_b", color_b)
	_mat.set_shader_parameter("band", band)
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("radii", radii)
	_mat.set_shader_parameter("border", border)
