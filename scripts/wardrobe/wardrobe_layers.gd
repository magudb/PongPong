class_name WardrobeLayers
extends Node
## World and local preview use the same fitted paintings and the body's clock.
## Static turnarounds share the exact stock puppet field in the canvas shaders.
const LAYER_SHADER := preload("res://shaders/wardrobe_layer.gdshader")
const BODY_SHADER := preload("res://shaders/wardrobe_body.gdshader")
const MOTIONS := {"idle":0, "walk":1, "run":2, "interact":3, "attack":4, "celebrate":5, "hover":6, "fly":6, "takeoff":6, "flight_land":6, "jump":7, "fall":8, "land":9, "sleep":10, "hit":11, "spin":12, "talk":13}
var world_outfit := false
var clock: IsoChibiSprite2D
var root: Node2D
var occluder: Sprite2D
var layers: Dictionary = {}
var current_outfit: Dictionary = {}
var body_material: ShaderMaterial
var mask_material: ShaderMaterial
var _previous_material: Material
var _body: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pose_key := ""
var _applied := false
var _body_id := ""
var _bound_layers: Array[Sprite2D] = []

func _ready() -> void:
	clock = get_parent() as IsoChibiSprite2D
	process_priority = 90 # after the body, before its held attachment at 100
	_previous_material = clock.sprite.material
	root = Node2D.new()
	root.name = "WornClothing"
	clock.sprite.add_child(root)
	if world_outfit:
		EventBus.outfit_changed.connect(set_outfit)
		EventBus.player_character_changed.connect(_character_changed)
		set_outfit(WardrobeManager.outfit())
	else:
		set_outfit(current_outfit)

func set_outfit(snapshot: Dictionary) -> bool:
	if clock == null or root == null:
		current_outfit = snapshot.duplicate()
		return true
	if _applied and snapshot == current_outfit and _body_id == clock.resolved_id:
		return true
	var body := WardrobeCatalog.body(clock.resolved_id)
	if body.is_empty():
		if _applied and _body_id != clock.resolved_id:
			clock.sprite.material = _previous_material
			root.hide()
			_applied = false
		return false
	# Prepare every resource before changing the visible outfit/material.
	var prepared: Array = []
	for slot in snapshot:
		var id := str(snapshot[slot])
		var record := WardrobeCatalog.resolve(clock.resolved_id, id)
		if record.is_empty():
			return false
		var texture := WardrobeCatalog.texture(str(record.file))
		if texture == null:
			return false
		prepared.append({"slot":str(slot), "id":id, "record":record, "texture":texture})
	var base := WardrobeCatalog.texture(str(body.get("base", "")))
	var mask := WardrobeCatalog.texture(str(body.mask))
	if base == null or mask == null:
		return false
	prepared.sort_custom(func(a,b): return _order(a) < _order(b))
	for node in root.get_children():
		root.remove_child(node)
		node.queue_free()
	layers.clear()
	_bound_layers.clear()
	_materials.clear()
	_body = body
	_body_id = clock.resolved_id
	current_outfit = snapshot.duplicate()
	body_material = _body_mat(base, false)
	mask_material = _body_mat(base, true)
	mask_material.set_shader_parameter("mask_image", mask)
	clock.sprite.material = body_material if str(body.get("base", "")) != "" else _previous_material
	for index in 7:
		mask_material.set_shader_parameter("garment_%d" % index, prepared[index].texture if index < prepared.size() else WardrobeCatalog.empty_texture())
	for entry in prepared:
		var sprite := _sprite(entry.slot)
		sprite.texture = entry.texture
		var material := ShaderMaterial.new()
		material.shader = LAYER_SHADER
		var palette: Array = ItemKinds.def(entry.id).get("art", {}).get("palette", [])
		for index in 3:
			var pigment: Array = entry.record.source_palette[index]
			material.set_shader_parameter("source_%d" % index, Vector3(pigment[0],pigment[1],pigment[2]))
			material.set_shader_parameter("palette_%d" % index, Color("#" + str(palette[index])) if index < palette.size() else Color(pigment[0],pigment[1],pigment[2]))
		sprite.material = material
		_materials.append(material)
		layers[entry.slot] = sprite
		_bound_layers.append(sprite)
	occluder = _sprite("ClothingOccluder")
	occluder.material = mask_material
	_pose_key = ""
	_applied = true
	root.show()
	sync_pose()
	return true

func _body_mat(base: Texture2D, mask: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter("base_image", base)
	material.set_shader_parameter("use_base", str(_body.get("base", "")) != "")
	material.set_shader_parameter("occluder", mask)
	_materials.append(material)
	return material

func _order(entry: Dictionary) -> int:
	return int(Svc.lua_config("wardrobe.layer_z."+str(entry.record.family),WardrobeManager.slots().get(entry.slot, {}).get("z",0)))

func _character_changed(_id: StringName) -> void:
	# PlayerBody2D connected first and has already installed the new stock body.
	set_outfit(WardrobeManager.outfit())

func _sprite(label: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = label
	sprite.centered = false
	sprite.region_enabled = true
	sprite.texture_filter = IsoChibiSprite2D.SPRITE_FILTER
	root.add_child(sprite)
	return sprite

func _process(_delta: float) -> void:
	sync_pose()

func sync_pose() -> void:
	if not _applied:
		return
	var source := clock.sprite
	var frame := int(source.region_rect.position.x / IsoChibiSprite2D.FRAME_SIZE)
	var direction := clock.direction_index
	var clip := str(clock.current_clip)
	var delta := source.offset - clock.base_sprite_offset
	var key := "%s/%d/%d/%s" % [clip,direction,frame,delta]
	if key == _pose_key:
		return
	_pose_key = key
	var frames := int(IsoChibiSprite2D.meta_for(clock.resolved_id).animations[clock.current_clip].frames)
	for material in _materials:
		material.set_shader_parameter("figure_height", float(_body.height))
		material.set_shader_parameter("frame_phase", float(frame)/frames)
		material.set_shader_parameter("pulse_phase", (float(frame)+0.5)/frames)
		material.set_shader_parameter("motion_kind", int(MOTIONS.get(clip,0)))
		material.set_shader_parameter("direction", direction)
	body_material.set_shader_parameter("source_origin", source.region_rect.position)
	mask_material.set_shader_parameter("source_origin", source.region_rect.position)
	for slot in layers:
		var sprite: Sprite2D = layers[slot]
		sprite.region_rect = Rect2(0,direction*256,256,256)
		sprite.offset = Vector2(-128,-200) + delta
		# A front pendant belongs under the chin, never on the hero's back.
		sprite.visible = not (slot == "necklace" and direction in [3,4,5])
	for index in 7:
		var texture: Texture2D = WardrobeCatalog.empty_texture()
		if index < _bound_layers.size() and _bound_layers[index].visible:
			texture = _bound_layers[index].texture
		mask_material.set_shader_parameter("garment_%d" % index,texture)
	occluder.texture = source.texture
	occluder.region_rect = source.region_rect
	occluder.offset = Vector2(-128,-200) + delta

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(clock) and is_instance_valid(clock.sprite) and clock.sprite.material == body_material:
			clock.sprite.material = _previous_material
		if is_instance_valid(root):
			root.queue_free()
