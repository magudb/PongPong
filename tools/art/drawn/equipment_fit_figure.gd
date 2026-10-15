extends Node2D
## Browse-only fitted art. The stock body supplies the sole animation clock.
## Never registered as a wardrobe base, inventory presenter, or save owner.
const MANIFEST := "res://assets/art_studies/equipment_fit/manifest.json"
const PACK := "res://assets/art_studies/equipment_fit/"
static var _manifest: Dictionary = {}
var body_id := "rasmus"
var clock: IsoChibiSprite2D
var parts_root: Node2D
var parts: Dictionary = {}
var textures: Dictionary = {}
var enabled_parts: Dictionary = {}
var pose: Dictionary = {}
var _body: Dictionary
var _pose_key := ""

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _manifest

func _ready() -> void:
	_body = manifest()["bodies"][body_id]
	clock = IsoChibiSprite2D.create(str(_body["stock"]))
	add_child(clock)
	# Warm the four stock clock sheets during studio setup. A bare threaded
	# request must not be left without load_threaded_get when this view closes.
	for clip in _body["clips"]:
		clock.play_loop(StringName(clip))
	clock.play_loop(&"idle")
	parts_root = Node2D.new()
	parts_root.name = "FittedArt"
	clock.add_child(parts_root)
	clock.move_child(parts_root, clock.sprite.get_index())
	for part in manifest()["parts"]:
		var sprite := Sprite2D.new()
		sprite.name = part
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		parts_root.add_child(sprite)
		parts[part] = sprite
	for clip in _body["clips"]:
		textures[clip] = load(PACK + str(_body["clips"][clip]["file"])) as Texture2D
	# Process after the IsoChibiSprite2D frame update. No second frame timer.
	process_priority = 1
	sync_pose()

func _process(_delta: float) -> void:
	sync_pose()

func set_part_enabled(part: String, value: bool) -> void:
	enabled_parts[part] = value
	_pose_key = ""
	if is_node_ready():
		sync_pose()

func sync_pose() -> void:
	var clip := str(clock.current_clip)
	if not _body["clips"].has(clip):
		parts_root.visible = false
		clock.sprite.visible = true
		_pose_key = ""
		pose = {}
		return
	var spec: Dictionary = _body["clips"][clip]
	var frame := int(clock.sprite.region_rect.position.x / IsoChibiSprite2D.FRAME_SIZE)
	if frame < 0 or frame >= int(spec["frames"]) or textures[clip] == null:
		parts_root.visible = false
		clock.sprite.visible = true
		return
	parts_root.visible = true
	clock.sprite.visible = false
	var source := clock.sprite
	parts_root.position = source.position
	parts_root.rotation = source.rotation
	parts_root.scale = source.scale
	parts_root.modulate = source.modulate
	var key := "%s/%d/%d" % [clip, clock.direction_index, frame]
	var offset_delta := source.offset - clock.base_sprite_offset
	if key != _pose_key:
		_pose_key = key
		pose = spec["poses"][clock.direction_index][frame]
		for index in (pose["order"] as Array).size():
			parts_root.move_child(parts[pose["order"][index]], index)
		for part in parts:
			var sprite: Sprite2D = parts[part]
			var rec: Dictionary = pose["parts"][part]
			sprite.visible = bool(rec["visible"]) and bool(enabled_parts.get(part, true))
			if not bool(rec["visible"]):
				continue
			var rect: Array = rec["rect"]
			sprite.texture = textures[clip]
			sprite.region_rect = Rect2(rect[0], rect[1], rect[2], rect[3])
	# Offset can change during spin without advancing the animation frame.
	for part in parts:
		var rec: Dictionary = pose["parts"][part]
		if rec["visible"]:
			var origin: Array = rec["canvas_offset"]
			(parts[part] as Sprite2D).offset = Vector2(origin[0] - 128, origin[1] - 200) + offset_delta

func select_clip(clip: String) -> void:
	clock.cancel_action()
	if clip == "interact":
		clock.play_action(&"interact")
	else:
		clock.play_loop(StringName(clip))
	sync_pose()
