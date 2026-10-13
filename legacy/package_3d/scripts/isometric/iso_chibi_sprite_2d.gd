class_name IsoChibiSprite2D
extends Node2D
## Animated 8-direction sprite. Draw origin is the character's ground contact point.
## The textures are 8 rows (S, SW, W, NW, N, NE, E, SE), with frames in columns.
## No 3D mesh or 3D runtime dependency.

signal action_finished(clip_name: StringName)

const FRAME_SIZE := 256
const GROUND_ANCHOR_Y := 200
const TEXTURE_EXTENSION := ".png"
const BASE_ANIMATIONS := {
	"idle": {"frames": 4, "fps": 5, "loop": true},
	"walk": {"frames": 6, "fps": 9, "loop": true},
	"run": {"frames": 6, "fps": 12, "loop": true},
	"jump": {"frames": 4, "fps": 10, "loop": false},
	"fall": {"frames": 3, "fps": 6, "loop": true},
	"land": {"frames": 3, "fps": 11, "loop": false},
	"celebrate": {"frames": 6, "fps": 9, "loop": false},
	"interact": {"frames": 4, "fps": 9, "loop": false},
	"hit": {"frames": 3, "fps": 11, "loop": false},
	"sleep": {"frames": 4, "fps": 3, "loop": true},
	"talk": {"frames": 4, "fps": 6, "loop": true},
}
const FLIGHT_ANIMATIONS := {
	"takeoff": {"frames": 4, "fps": 10, "loop": false},
	"hover": {"frames": 5, "fps": 8, "loop": true},
	"fly": {"frames": 6, "fps": 12, "loop": true},
	"flight_land": {"frames": 4, "fps": 10, "loop": false},
}

const CHARACTER_IDS: Array[String] = [
	"bat", "cat", "bear", "rabbit", "fairy", "monkey", "capybara",
	"fox", "raccoon", "penguin", "hedgehog", "frog"
]

@export_enum("bat", "cat", "bear", "rabbit", "fairy", "monkey", "capybara", "fox", "raccoon", "penguin", "hedgehog", "frog")
var character_id: String = "fox"
@export_range(0.5, 2.5, 0.05) var playback_rate: float = 1.0
@export_range(0, 7, 1) var starting_direction: int = 0
@export var show_shadow: bool = true

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

var current_clip: StringName = &"idle"
var direction_index: int = 0
var _frame: int = 0
var _frame_timer: float = 0.0
var _animations: Dictionary = {}
var _textures: Dictionary = {}
var _locked: bool = false
var _altitude: float = 0.0
var _shadow_origin_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_shadow_origin_scale = shadow.scale
	shadow.visible = show_shadow
	sprite.region_enabled = true
	sprite.offset = Vector2(0.0, float(FRAME_SIZE) * 0.5 - GROUND_ANCHOR_Y)
	direction_index = clampi(starting_direction, 0, 7)
	load_character(character_id)


func load_character(id: String) -> void:
	if id not in CHARACTER_IDS:
		push_warning("Unknown chibi character: %s" % id)
		id = "fox"
	character_id = id
	# Embed safe defaults so character animation also works in exported builds
	# where *.json is excluded by an export preset.
	_animations = BASE_ANIMATIONS.duplicate(true)
	if id in ["bat", "fairy"]:
		_animations.merge(FLIGHT_ANIMATIONS.duplicate(true), true)
	for clip in _animations.keys():
		var spec := _animations[clip] as Dictionary
		spec["sheet"] = String(clip) + TEXTURE_EXTENSION
	var path := "res://assets/isometric_characters/%s/animations.json" % id
	if FileAccess.file_exists(path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
			var source := (json.data as Dictionary).get("animations", {}) as Dictionary
			if not source.is_empty():
				_animations = source
	_textures.clear()
	_locked = false
	current_clip = &"idle"
	_frame = 0
	_frame_timer = 0.0
	_sync_sprite()


func set_facing_direction(movement: Vector2) -> void:
	if movement.length_squared() < 0.001:
		return
	# S=0, SW=1, W=2, NW=3, N=4, NE=5, E=6, SE=7.
	var clockwise_from_south := fposmod(-atan2(movement.x, movement.y), TAU)
	var next_direction := wrapi(int(round(clockwise_from_south / (PI / 4.0))), 0, 8)
	if direction_index != next_direction:
		direction_index = next_direction
		_sync_sprite()


func update_motion(
	motion: Vector2,
	running: bool = false,
	airborne: bool = false,
	flying: bool = false
) -> void:
	set_facing_direction(motion)
	if _locked:
		return
	var selected: StringName = &"idle"
	if flying:
		selected = &"fly" if motion.length_squared() > 100.0 else &"hover"
	elif airborne:
		selected = &"fall"
	elif motion.length_squared() > 90.0:
		selected = &"run" if running else &"walk"
	play_loop(selected)


func play_loop(clip: StringName) -> void:
	if clip != current_clip and _animations.has(String(clip)):
		_play(clip)


func play_action(clip: StringName) -> void:
	if not _animations.has(String(clip)):
		return
	_locked = true
	_play(clip, true)


func _play(clip: StringName, force: bool = false) -> void:
	if clip == current_clip and not force:
		return
	if not _animations.has(String(clip)):
		clip = &"idle"
	if not _animations.has(String(clip)):
		return
	# Maintain stride continuity when changing walk/run state.
	var old_frames: int = int(_animations.get(String(current_clip), {}).get("frames", 1))
	var stride_transition := current_clip in [&"walk", &"run"] and clip in [&"walk", &"run"]
	var phase := float(_frame) / float(maxi(old_frames, 1))
	current_clip = clip
	var count := int(_animations[String(clip)]["frames"])
	_frame = clampi(int(phase * count), 0, count - 1) if stride_transition else 0
	_frame_timer = 0.0
	_sync_sprite()


func set_altitude(height_pixels: float) -> void:
	_altitude = maxf(height_pixels, 0.0)
	if not is_node_ready():
		return
	sprite.position.y = -_altitude
	var tint := shadow.modulate
	tint.a = lerpf(0.50, 0.20, clampf(_altitude / 135.0, 0.0, 1.0))
	shadow.modulate = tint
	shadow.scale = _shadow_origin_scale * (1.0 + minf(_altitude / 400.0, 0.28))


func _process(delta: float) -> void:
	if _animations.is_empty():
		return
	var spec: Dictionary = _animations[String(current_clip)]
	var fps: float = maxf(float(spec.get("fps", 6)) * playback_rate, 0.5)
	_frame_timer += delta
	var frame_length := 1.0 / fps
	var count: int = int(spec.get("frames", 1))
	while _frame_timer >= frame_length:
		_frame_timer -= frame_length
		_frame += 1
		if _frame >= count:
			if bool(spec.get("loop", false)):
				_frame = 0
			else:
				_frame = count - 1
				var completed := current_clip
				_locked = false
				_play(&"idle", true)
				action_finished.emit(completed)
				return
		_sync_sprite()


func _sync_sprite() -> void:
	if not is_node_ready() or not _animations.has(String(current_clip)):
		return
	var clip_key := String(current_clip)
	if not _textures.has(clip_key):
		var filename: String = String((_animations[clip_key] as Dictionary).get("sheet", clip_key + ".png"))
		var image_path := "res://assets/isometric_characters/%s/%s" % [character_id, filename]
		_textures[clip_key] = load(image_path) as Texture2D
	var image := _textures[clip_key] as Texture2D
	if image == null:
		push_error("Unable to load character sprite sheet: %s/%s" % [character_id, clip_key])
		return
	sprite.texture = image
	sprite.region_rect = Rect2(
		float(_frame * FRAME_SIZE), float(direction_index * FRAME_SIZE),
		float(FRAME_SIZE), float(FRAME_SIZE)
	)
