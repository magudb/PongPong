class_name ForestActorLight
extends Node
## Change lighting without replacing wardrobe materials: their owners continue
## updating the same animation, palette and occlusion uniforms.
static var _shaders: Dictionary = {}
static var _plain: CanvasItemMaterial
var actor: Node
var area: IsoArea
var _sprites: Dictionary = {}
var _materials: Dictionary = {}
var _lantern: PointLight2D
var _lantern_texture: Texture2D
var _poll := 0.0
func _ready() -> void:
	actor = get_parent()
	refresh()
	EventBus.outfit_changed.connect(_outfit_changed)
func _outfit_changed(_outfit: Dictionary) -> void:
	refresh.call_deferred()
func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0:
		_poll = .1
		refresh()
func refresh() -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or not is_instance_valid(area) or actor.get_parent() != area.objects: return
	for key in _sprites.keys():
		if _sprites[key].node.get_ref() == null: _sprites.erase(key)
	for key in _materials.keys():
		if _materials[key].material.get_ref() == null: _materials.erase(key)
	_visit(actor)
func _visit(node: Node) -> void:
	if node is Sprite2D or node is LootDrop2D:
		_dress(node)
	elif node is PointLight2D and node.name == "Lantern" and _lantern == null:
		_lantern = node
		_lantern_texture = node.texture
		node.texture = ForestDress.lantern_texture()
	for child in node.get_children():
		if child != self: _visit(child)
func _dress(sprite: CanvasItem) -> void:
	var current := sprite.material
	if current is ShaderMaterial:
		var key := current.get_instance_id()
		if _materials.has(key): return
		var original: Shader = current.shader
		if original == null or "unshaded" in original.code: return
		var shader_id := original.code
		if not _shaders.has(shader_id):
			var variant := Shader.new()
			var code := original.code
			var mode := RegEx.new()
			mode.compile("render_mode\\s+([^;]+);")
			var found := mode.search(code)
			code = code.replace(found.get_string(),"render_mode "+found.get_string(1)+", unshaded;") if found != null else code.replace("shader_type canvas_item;","shader_type canvas_item;\nrender_mode unshaded;")
			variant.code = code
			_shaders[shader_id] = variant
		var applied: Shader = _shaders[shader_id]
		_materials[key] = {"material":weakref(current),"original":original,"applied":applied}
		current.shader = applied
	else:
		var key := sprite.get_instance_id()
		if _sprites.has(key) and current == _sprites[key].applied: return
		if current is CanvasItemMaterial and current.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED: return
		var applied: CanvasItemMaterial
		if current is CanvasItemMaterial:
			applied = current.duplicate()
			applied.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		else:
			if _plain == null:
				_plain = CanvasItemMaterial.new()
				_plain.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
			applied = _plain
		_sprites[key] = {"node":weakref(sprite),"original":current,"applied":applied}
		sprite.material = applied
func _exit_tree() -> void:
	for record in _sprites.values():
		var node: CanvasItem = record.node.get_ref()
		if is_instance_valid(node) and node.material == record.applied: node.material = record.original
	for record in _materials.values():
		var material: ShaderMaterial = record.material.get_ref()
		if material != null and material.shader == record.applied: material.shader = record.original
	if is_instance_valid(_lantern) and _lantern.texture == ForestDress.lantern_texture(): _lantern.texture = _lantern_texture
	_sprites.clear()
	_materials.clear()
	_lantern = null
