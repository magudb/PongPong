class_name SoftGround
extends Node
## Technical masks reuse approved seamless paintings. Terrain and its physics
## remain authoritative; removing the decals restores the normal tile art.
const SHADER := preload("res://scripts/forest_look/soft_ground.gdshader")
## Cells of empty mask kept around a feature's bounds: the cubic upscale softens the edge by well under one cell.
const MARGIN := 2
const FEATURES := {"path":{"chars":["p","x"],"art":"path_tile_o"},"pond":{"chars":["~"],"art":"pond_water_o"},"glow":{"chars":["g"],"terrain":"forest_floor_glow_o"}}
var masks: Dictionary = {}
var sprites: Array[Sprite2D] = []
var ponds: Array[Area2D] = []
var area: IsoArea
var build_usec := 0
func build(target: IsoArea) -> void:
	area = target
	var started := Time.get_ticks_usec()
	for feature in FEATURES:
		var image := Image.create(area.map.width,area.map.height,false,Image.FORMAT_L8)
		image.fill(Color.BLACK)
		var count := 0
		var low := Vector2i(area.map.width,area.map.height)
		var high := Vector2i(-1,-1)
		for y in area.map.height:
			for x in area.map.width:
				if area.map.ground_at(Vector2i(x,y)) in FEATURES[feature].chars:
					image.set_pixel(x,y,Color.WHITE)
					count += 1
					low = low.min(Vector2i(x,y))
					high = high.max(Vector2i(x,y))
		masks[feature] = image.duplicate()
		if count == 0: continue
		var painting: Dictionary
		if FEATURES[feature].has("terrain"):
			painting = ArtCatalog.terrain(StringName(str(FEATURES[feature].terrain)))
		else:
			var id := StringName(str(FEATURES[feature].art))
			if not ArtCatalog.has_real_prop(id): continue
			painting = ArtCatalog.prop(id)
		if not painting.get("real",false): continue
		var texture: Texture2D = painting.texture
		# The decal covers the feature's cells plus MARGIN, not the whole map: fragments outside it were blended at alpha 0 (review REND-07).
		# The painting stays anchored to the map's corner through `origin`, so cropping moves no pigment.
		var crop := Rect2i(low-Vector2i.ONE*MARGIN,high-low+Vector2i.ONE*(1+2*MARGIN)).intersection(Rect2i(0,0,area.map.width,area.map.height))
		var part := image.get_region(crop)
		part.resize(crop.size.x*8,crop.size.y*8,Image.INTERPOLATE_CUBIC)
		var cell := Vector2(Iso.ORTHO_W,Iso.ORTHO_H)
		var picture := Sprite2D.new()
		picture.name = str(feature).capitalize()+"Decal"
		picture.texture = ImageTexture.create_from_image(part)
		picture.centered = false
		picture.position = area.ground_fx.to_local(area.cell_to_global(crop.position))-cell*.5
		picture.scale = cell/8.0
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("paint",texture)
		material.set_shader_parameter("repeats",Vector2(crop.size)*cell/texture.get_size())
		material.set_shader_parameter("origin",Vector2(crop.position)*cell/texture.get_size())
		picture.material = material
		area.ground_fx.add_child(picture)
		sprites.append(picture)
	_build_ponds()
	build_usec = Time.get_ticks_usec()-started
func _build_ponds() -> void:
	var visited := {}
	for y in area.map.height:
		for x in area.map.width:
			var start := Vector2i(x,y)
			if visited.has(start) or area.map.ground_at(start) != "~": continue
			var cells: Array[Vector2i] = [start]
			visited[start] = true
			var low := start
			var high := start
			var index := 0
			while index < cells.size():
				var at := cells[index]
				index += 1
				low = low.min(at)
				high = high.max(at)
				for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i = at+step
					if not visited.has(next) and area.map.ground_at(next) == "~":
						visited[next] = true
						cells.append(next)
			var trigger := MoonPond.new()
			trigger.area = area
			trigger.cell = start
			trigger.bounds = Rect2(Vector2(low)-Vector2(1.5,1.5),Vector2(high-low)+Vector2(3,3))
			area.triggers.add_child(trigger)
			ponds.append(trigger)
func _exit_tree() -> void:
	for picture in sprites:
		if is_instance_valid(picture): picture.queue_free()
	for pond in ponds:
		if is_instance_valid(pond): pond.queue_free()
class MoonPond extends Area2D:
	var area: IsoArea
	var cell: Vector2i
	var bounds: Rect2
	var done := false
	func _ready() -> void:
		collision_layer = 0
		collision_mask = Iso.LAYER_PLAYER
		done = LootMarkers.is_done(area,cell,LootMarkers.context_for(area,cell))
		var shape := RectangleShape2D.new()
		shape.size = bounds.size*Vector2(Iso.ORTHO_W,Iso.ORTHO_H)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = to_local(area.cell_to_global(Vector2i.ZERO))+(bounds.position+bounds.size*.5)*Vector2(Iso.ORTHO_W,Iso.ORTHO_H)
		add_child(collision)
		body_entered.connect(_entered)
	func _entered(body: Node) -> void:
		if done or not body.is_in_group("player"): return
		done = true
		LootMarkers.mark_done(area,cell,LootMarkers.context_for(area,cell))
		EventBus.whisper_requested.emit("LOOK_MOONPOND_FISHING")
