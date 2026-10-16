class_name HeldEquipment2D
extends Node
## Dedicated painted equipment follows the shipped body's actual animation
## frame. It owns no inventory, action timing, combat hitbox or save data.
const MANIFEST := "res://assets/held_equipment/manifest.json"
const PAINTING := preload("res://assets/held_equipment/tools.webp")
const REST_ANGLES := [-20.0, -25.0, -20.0, -15.0, 20.0, 25.0, 20.0, 25.0]
static var _data: Dictionary = {}
var player: Player2D
var rear: Node2D
var front: Node2D
var tool: Sprite2D
var hand: Sprite2D
var item_id: StringName = &""
var pose: Dictionary = {}
var _key := ""

static func manifest() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _data

func _ready() -> void:
	player = get_parent() as Player2D
	process_priority = 100 # after the one IsoChibiSprite2D clock
	rear = Node2D.new()
	rear.name = "EquipmentRear"
	front = Node2D.new()
	front.name = "EquipmentFront"
	# Parenting to the actual Sprite inherits altitude, spin, scale and late
	# tween flashes exactly once, including changes after _process callbacks.
	player.visual.sprite.add_child(rear)
	rear.show_behind_parent = true
	player.visual.sprite.add_child(front)
	tool = Sprite2D.new()
	tool.name = "HeldPainting"
	tool.centered = false
	tool.region_enabled = true
	tool.texture = PAINTING
	tool.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	front.add_child(tool)
	hand = Sprite2D.new()
	hand.name = "HandOccluder"
	hand.centered = false
	hand.region_enabled = true
	hand.texture_filter = IsoChibiSprite2D.SPRITE_FILTER
	front.add_child(hand)
	sync_pose()

func _process(_delta: float) -> void:
	sync_pose()

func sync_pose() -> void:
	var snapshot := player.equipment_display()
	item_id = StringName(str(snapshot.id))
	var visual := player.visual
	var data := manifest()
	var body: Dictionary = data.bodies.get(visual.resolved_id, {})
	var clip := str(visual.current_clip)
	var frames: Array = body.get("clips", {}).get(clip, [])
	var frame := int(visual.sprite.region_rect.position.x / IsoChibiSprite2D.FRAME_SIZE)
	var direction := visual.direction_index
	var show: bool = snapshot.drawn and data.items.has(str(item_id)) and not frames.is_empty() and frame < frames[direction].size()
	rear.visible = show
	front.visible = show
	if not show:
		_key = ""
		pose = {}
		return
	var source := visual.sprite
	var delta := source.offset - visual.base_sprite_offset
	var key := "%s/%s/%d/%d/%s/%s/%s" % [visual.resolved_id, clip, direction, frame, item_id, snapshot.context, delta]
	if key == _key:
		return
	_key = key
	pose = frames[direction][frame]
	var art: Dictionary = data.items[str(item_id)]
	var view: Dictionary = art.views[direction]
	var target := rear if str(pose.depth) == "rear" else front
	if tool.get_parent() != target:
		tool.reparent(target, false)
		if target == front:
			front.move_child(tool, 0)
	var grip := Vector2(pose.grip[0], pose.grip[1])
	var anchor := Vector2(128, 200)
	tool.region_rect = Rect2(view.rect[0], view.rect[1], view.rect[2], view.rect[3])
	tool.offset = -Vector2(view.grip[0], view.grip[1])
	tool.position = grip - anchor + delta
	tool.scale = Vector2.ONE * float(art.height) / float(view.height)
	var angle: float = REST_ANGLES[direction]
	if player.state == PlayerBody2D.S.SWING and clip == "interact":
		angle += [-45.0, -10.0, 35.0, 65.0][mini(frame, 3)]
	elif player.state == PlayerBody2D.S.USING and clip == "interact":
		angle += [-15.0, -35.0, 20.0, 5.0][mini(frame, 3)]
	tool.rotation = deg_to_rad(angle)
	# Re-use only the matching painted hand patch from the live body texture.
	# This covers the handle; no new skin, detached hand or whole-body layer.
	hand.visible = target == front
	hand.texture = source.texture
	hand.region_rect = Rect2(source.region_rect.position + grip - Vector2(7, 7), Vector2(14, 14))
	hand.position = grip - anchor + delta - Vector2(7, 7)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(rear):
			rear.queue_free()
		if is_instance_valid(front):
			front.queue_free()
