class_name NpcGlow
extends Node2D
## One disposable glow owner per citizen. Only Silke adds a light; body art is immutable.
const CITY_LIGHT_CAP := 15
var npc: Npc2D
var halo: Sprite2D
var lantern_halo: Sprite2D
var light: PointLight2D
var _halo_alpha := 0.9
var _light_energy := 0.3
var _tick := 0.0
var _count_tick := 0.0
var _others := 0
static func attach(actor: Node) -> Node:
	if actor.has_node("NpcGlow"):return actor.get_node("NpcGlow")
	var row := LuaData.dict(Svc.lua_config("npc_glow."+str(actor.get("npc_id")),{}))
	if row.is_empty() or not actor is Npc2D:return null
	var node := NpcGlow.new()
	node.name = "NpcGlow"
	node.npc = actor
	node._configure(row)
	actor.add_child(node)
	return node
func _configure(row: Dictionary) -> void:
	var spec := LuaData.dict(row.get("halo",{}))
	_halo_alpha = float(spec.get("alpha",0.9))
	halo = _halo(Color.from_string(str(spec.get("color","bfe0ff")),Color.WHITE),float(spec.get("scale",1.25))*150.0/128.0,Vector2(float(spec.get("x",0)),float(spec.get("y",-70))))
	halo.z_index = -1
	if not row.has("light"):return
	spec = LuaData.dict(row.light)
	_light_energy = float(spec.get("energy",0.3))
	light = PointLight2D.new()
	light.texture = Glow.light_texture()
	light.texture_scale = float(spec.get("texture_scale",.45))
	light.color = Color.from_string(str(spec.get("color","ffd98a")),Color.WHITE)
	light.position = Vector2(float(spec.get("x",34)),float(spec.get("y",-22)))
	light.shadow_enabled = false
	light.energy = 0
	light.visible = false
	add_child(light)
	lantern_halo = _halo(light.color,.55,light.position)
func _halo(color: Color,size: float,at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Glow.halo_texture()
	sprite.material = Glow.additive_material()
	sprite.scale = Vector2.ONE*size
	sprite.position = at
	sprite.modulate = color
	sprite.visible = false
	add_child(sprite)
	return sprite
func _ready() -> void:
	_refresh()
func _process(delta: float) -> void:
	_tick += delta
	_count_tick += delta
	if _tick < .1:return
	_tick = 0
	# Other lights come and go rarely: recount them once a second, the fade follows the night at 10 Hz.
	var recount := _count_tick >= 1.0
	if recount:_count_tick = 0
	_refresh(recount)
func _refresh(recount := true) -> void:
	if not is_instance_valid(npc):return
	var factor := npc.area.night_factor if is_instance_valid(npc.area) else 0.0
	var hidden := bool(npc.get_meta("ghostfam_hiding",false))
	halo.visible = factor>.004 and not hidden
	halo.modulate.a = factor*_halo_alpha
	if light == null:return
	# Silke yields first if another effect uses the last safe light slot. By day (or hidden) her
	# lantern is off, so the other lights are not counted at all.
	var lit := factor>.004 and not hidden
	if lit and (recount or not light.visible):
		var world := get_tree().get_first_node_in_group("world_2d")
		_others = _enabled_lights(world) if world != null else 0
	light.visible = lit and _others<CITY_LIGHT_CAP
	light.energy = factor*_light_energy if light.visible else 0.0
	lantern_halo.visible = factor>.004 and not hidden
	lantern_halo.modulate.a = factor*.7
func _enabled_lights(root: Node) -> int:
	var count := 0
	for node in root.find_children("*","PointLight2D",true,false):
		if node!=light and (node as PointLight2D).is_visible_in_tree() and (node as PointLight2D).energy>.004:count += 1
	return count
