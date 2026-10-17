class_name ForestDress
extends Node
## One instance per orthogonal forest. Markers defer attach until map build
## completes; generated floors call attach after area_ready.
var area: IsoArea
var params := {}
var fireflies: CPUParticles2D
var mist: Array[Sprite2D] = []
var soft_ground: SoftGround
var build_errors: Array[String] = []
var _actors: Dictionary = {}
var _poll := 0.0
var _mist_drift := 4.0
static var _lantern_texture: GradientTexture2D
static func attach(target: IsoArea, options: Dictionary = {}) -> ForestDress:
	if target == null or target.projection != &"ortho" or target.map.ambient not in [&"forest",&"cave"]: return null
	var existing := target.get_node_or_null("ForestLook") as ForestDress
	if existing != null: return existing
	var look := ForestDress.new()
	look.name = "ForestLook"
	look.area = target
	look.params = options.duplicate()
	target.add_child(look)
	return look
static func create_marker(options: Dictionary, _pos: Vector2, _cell: Vector2i, target: IsoArea) -> Node:
	# Building happens before the area enters the tree. Deferred attach sees all
	# authored markers, lights and props, irrespective of their text order.
	attach.call_deferred(target,options)
	return null
static func lantern_texture() -> GradientTexture2D:
	if _lantern_texture == null:
		var ring := LuaData.arr(Svc.lua_config("forest_look.lantern.ring",[1.0,.31,0.0]))
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0,.6,1])
		gradient.colors = PackedColorArray([Color(1,1,1,float(ring[0])),Color(1,1,1,float(ring[1])),Color(1,1,1,float(ring[2]))])
		_lantern_texture = GradientTexture2D.new()
		_lantern_texture.gradient = gradient
		_lantern_texture.width = 256
		_lantern_texture.height = 256
		_lantern_texture.fill = GradientTexture2D.FILL_RADIAL
		_lantern_texture.fill_from = Vector2(.5,.5)
		_lantern_texture.fill_to = Vector2(1,.5)
	return _lantern_texture
func _ready() -> void:
	soft_ground = SoftGround.new()
	soft_ground.name = "SoftGround"
	add_child(soft_ground)
	soft_ground.build(area)
	_build_fireflies()
	_build_mist()
	enforce_light_budget()
	_refresh_actors()
func _build_fireflies() -> void:
	if int(params.get("fireflies",14)) <= 0: return
	var cfg := LuaData.dict(Svc.lua_config("forest_look.fireflies",{}))
	fireflies = CPUParticles2D.new()
	fireflies.name = "Fireflies"
	fireflies.amount = int(cfg.get("cpu_particles",40))
	fireflies.lifetime = float(cfg.get("blink_max",4))
	fireflies.lifetime_randomness = 1.0-float(cfg.get("blink_min",2))/fireflies.lifetime
	fireflies.preprocess = 4
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.emission_rect_extents = Vector2(1700,1000)
	fireflies.gravity = Vector2.ZERO
	fireflies.direction = Vector2.UP
	fireflies.spread = 180
	fireflies.initial_velocity_min = float(cfg.get("drift_min",8))
	fireflies.initial_velocity_max = float(cfg.get("drift_max",16))
	fireflies.texture = ArtCatalog.prop(&"firefly_dot").texture
	fireflies.material = Glow.additive_material()
	fireflies.scale_amount_min = .35
	fireflies.scale_amount_max = .65
	var color := Color(str(cfg.get("color","f2e9a0")))
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0,.25,.75,1])
	ramp.colors = PackedColorArray([Color(color,0),Color(color,float(cfg.get("halo_alpha",.25))),Color(color,float(cfg.get("halo_alpha",.25))),Color(color,0)])
	fireflies.color_ramp = ramp
	area.add_child(fireflies)
	fireflies.z_index = 180
func _build_mist() -> void:
	var cfg := LuaData.dict(Svc.lua_config("forest_look.mist",{}))
	_mist_drift = float(cfg.get("drift",4))
	for index in clampi(int(params.get("mist",2)),0,2):
		var picture := Sprite2D.new()
		picture.texture = ArtCatalog.prop(&"mist_patch_a" if index == 0 else &"mist_patch_b").texture
		picture.modulate = Color(Color(str(cfg.get("color","cfd6f2"))),float(cfg.get("alpha",.06)))
		picture.scale = Vector2(4,3)
		picture.position = area.to_local(area.cell_to_global(Vector2i(area.map.width/2,area.map.height/2)))+Vector2(index*900-450,index*350-175)
		area.ground_fx.add_child(picture)
		mist.append(picture)
func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if fireflies != null and camera != null: fireflies.global_position = camera.get_screen_center_position()
	for picture in mist:
		picture.position.x += _mist_drift*delta
	_poll -= delta
	if _poll <= 0:
		_poll = .1
		_refresh_actors()
func _refresh_actors() -> void:
	if str(params.get("unshaded",true)).to_lower() in ["false","0"]: return
	for node in area.objects.get_children():
		if not (node is PlayerBody2D or node is Npc2D or node is Enemy2D or node is LootChest2D or node is LootDrop2D or node.name == "SleepingNatteblik"): continue
		var key := node.get_instance_id()
		if _actors.has(key) and is_instance_valid(_actors[key]): continue
		var light := ForestActorLight.new()
		light.name = "ForestActorLight"
		light.area = area
		node.add_child(light)
		_actors[key] = light
	for key in _actors.keys():
		if not is_instance_valid(_actors[key]):
			_actors.erase(key)
			continue
		var light: Node = _actors[key]
		if light.get_parent().get_parent() != area.objects:
			light.free()
			_actors.erase(key)
func enforce_light_budget() -> Array[String]:
	build_errors.clear()
	var lights: Array[PointLight2D] = []
	_collect_lights(area,lights)
	var accepted: Array[PointLight2D] = []
	var cap := int(Svc.lua_config("forest_look.light_budget.map_lights_overlapping_max",12))
	var view_cap := int(Svc.lua_config("forest_look.light_budget.in_view_max",16))-1 # reserve the player's lantern
	var mushroom_cap := int(Svc.lua_config("forest_look.light_budget.glow_mushroom_lights_max",8))
	var mushrooms := 0
	for light in lights:
		var candidate: Array[PointLight2D] = accepted.duplicate()
		candidate.append(light)
		var mushroom := _mushroom_light(light)
		if candidate.size() > view_cap or _max_overlap(candidate) > cap or (mushroom and mushrooms >= mushroom_cap):
			light.enabled = false
			light.hide()
			var error := "forest_light_budget: refused "+str(light.name)+" (map overlap <= %d, map lights <= %d)" % [cap,view_cap]
			build_errors.append(error)
			if error not in area.map.errors: area.map.errors.append(error)
		else:
			accepted.append(light)
			if mushroom: mushrooms += 1
	return build_errors
func _mushroom_light(light: PointLight2D) -> bool:
	var node: Node = light
	while node != null and node != area:
		if str(node.get_meta("prop_id","")).begins_with("glow_mushroom"): return true
		node = node.get_parent()
	for marker in area.markers:
		var holder: Node = marker.get("node")
		if is_instance_valid(holder) and holder.is_ancestor_of(light) and str(marker.params.get("prop","")).begins_with("glow_mushroom"): return true
	return false
func _collect_lights(node: Node,out: Array[PointLight2D]) -> void:
	for child in node.get_children():
		if child is PlayerBody2D: continue
		if child is PointLight2D: out.append(child)
		_collect_lights(child,out)
static func _radius(light: PointLight2D) -> float:
	return maxf(light.texture.get_width(),light.texture.get_height())*.5*light.texture_scale*light.global_scale.abs().x if light.texture != null else 0.0
static func _max_overlap(lights: Array[PointLight2D]) -> int:
	var points: Array[Vector2] = []
	for light in lights: points.append(light.global_position)
	for i in lights.size():
		for j in range(i+1,lights.size()):
			var a := lights[i].global_position
			var b := lights[j].global_position
			var r := _radius(lights[i])
			var s := _radius(lights[j])
			var distance := a.distance_to(b)
			if distance <= .001 or distance > r+s or distance < absf(r-s): continue
			var along := (r*r-s*s+distance*distance)/(2*distance)
			var across := sqrt(maxf(0,r*r-along*along))
			var direction := (b-a)/distance
			points.append(a+direction*along+direction.orthogonal()*across)
			points.append(a+direction*along-direction.orthogonal()*across)
	var maximum := 0
	for point in points:
		var count := 0
		for light in lights:
			if point.distance_to(light.global_position) <= _radius(light)+.01: count += 1
		maximum = maxi(maximum,count)
	return maximum
func _exit_tree() -> void:
	for light in _actors.values():
		if is_instance_valid(light): light.free()
	_actors.clear()
	if is_instance_valid(fireflies): fireflies.queue_free()
	for picture in mist:
		if is_instance_valid(picture): picture.queue_free()
