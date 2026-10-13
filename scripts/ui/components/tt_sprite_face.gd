extends Control
## Shows one frame-animated character from the isometric pack inside a Control (cards, shop
## keeper, previews). Pure draw: no Node2D, so it behaves in containers and scales with stretch.
## Sheet layout (pack): 256x256 cells, 8 direction ROWS (S,SW,W,NW,N,NE,E,SE), frames in COLUMNS,
## ground pivot at (128,200).

const CELL := 256
const PIVOT := Vector2(128, 200)
const DIRS := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
const CLIPS := {
	"idle": [4, 5.0], "walk": [6, 9.0], "run": [6, 12.0], "celebrate": [6, 9.0],
	"talk": [4, 6.0], "interact": [4, 9.0], "hit": [3, 11.0], "sleep": [4, 3.0],
}
const SHADOW := preload("res://assets/isometric_characters/shadow.png")

@export var character_id: String = "fox":
	set(v):
		character_id = v
		_load_sheet()
@export var clip: String = "idle":
	set(v):
		clip = v
		_frame = 0
		_load_sheet()
@export_range(0, 7) var direction: int = 7:
	set(v):
		direction = v
		queue_redraw()
@export var sprite_scale: float = 1.0:
	set(v):
		sprite_scale = v
		queue_redraw()
## Where the feet sit, as fraction of the control height (0 = top, 1 = bottom).
@export_range(0.0, 1.0) var feet_y: float = 0.9
@export var animate: bool = true
@export var tint: Color = Color.WHITE
@export var show_shadow: bool = true

var _sheet: Texture2D
var _frames := 4
var _fps := 5.0
var _frame := 0
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	_load_sheet()


func _load_sheet() -> void:
	var p := "res://assets/isometric_characters/%s/%s.webp" % [character_id, clip]
	if not ResourceLoader.exists(p):
		_sheet = null
		queue_redraw()
		return
	_sheet = load(p)
	var spec: Array = CLIPS.get(clip, [4, 5.0])
	_frames = spec[0]
	_fps = spec[1]
	queue_redraw()


func _process(delta: float) -> void:
	if not animate or _sheet == null or not is_visible_in_tree():
		return
	_t += delta
	var f := int(_t * _fps) % _frames
	if f != _frame:
		_frame = f
		queue_redraw()


func _draw() -> void:
	if _sheet == null:
		return
	var feet := Vector2(size.x * 0.5, size.y * feet_y)
	var k := sprite_scale
	if show_shadow:
		var sw := SHADOW.get_size() * k
		draw_texture_rect(SHADOW, Rect2(feet - sw * 0.5 + Vector2(0, 4 * k), sw), false)
	var src := Rect2(_frame * CELL, direction * CELL, CELL, CELL)
	var dst := Rect2(feet - PIVOT * k, Vector2(CELL, CELL) * k)
	draw_texture_rect_region(_sheet, dst, src, tint)
