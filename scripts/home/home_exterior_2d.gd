extends Node2D
## One fixed door anchor across all painted tiers and construction stages.
var area: IsoArea
var _night: Sprite2D
var _visuals: Array[Node2D] = []
var _tier := 0
var _target := 0

static func create_marker(_params: Dictionary, pos: Vector2, _cell: Vector2i, target: IsoArea) -> Node:
	var result: Node2D = load("res://scripts/home/home_exterior_2d.gd").new()
	result.position = target.to_local(pos)
	result.area = target
	return result

func _ready() -> void:
	_refresh()
	EventBus.home_upgraded.connect(func(_a, _b): _refresh())
	EventBus.home_upgrade_started.connect(func(_a, _b, _c): _refresh())
	EventBus.load_completed.connect(func(_slot): _refresh())
	EventBus.game_event.emit(&"home_exterior_ready", {})

func _refresh() -> void:
	if _tier == HomeManager.tier and _target == int(HomeManager.construction.get("target", 0)):
		return
	_tier = HomeManager.tier
	_target = int(HomeManager.construction.get("target", 0))
	for node in _visuals:
		node.queue_free()
	_visuals.clear()
	var meta := HomeData.tier(_tier)
	var exterior: Dictionary = meta.exterior
	var house := _picture(exterior.day, exterior)
	_night = Sprite2D.new()
	_night.centered = false
	_night.texture = HomeData.tex(HomeData.PROPS + "home/" + str(exterior.night))
	_night.offset = house.get_node("Sprite").offset + Vector2(exterior.night_offset[0], exterior.night_offset[1])
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_night.material = material
	house.add_child(_night)
	if _target > 1:
		var scaffold: Dictionary = HomeData.tier(_target).scaffold_from_previous
		_picture(scaffold.file, scaffold)
	var rect: Array = meta.footprint_rect
	var body := StaticBody2D.new()
	body.collision_layer = Iso.LAYER_WORLD
	body.collision_mask = 0
	var poly := CollisionPolygon2D.new()
	var points := PackedVector2Array()
	for c in [Vector2(rect[0],rect[1]),Vector2(rect[2],rect[1]),Vector2(rect[2],rect[3]),Vector2(rect[0],rect[3])]:
		points.append(HomeData.cell_to_local(c) + Vector2(0,-20))
	poly.polygon = points
	body.add_child(poly)
	add_child(body)
	_visuals.append(body)
	var door: Interactable2D = load("res://scripts/home/home_door_2d.gd").new()
	door.position = Vector2(0, 18)
	add_child(door)
	_visuals.append(door)
	area.set_growth_stage(int(meta.platform.back_rows))

func _picture(file: String, meta: Dictionary) -> Node2D:
	var root := Node2D.new()
	var ys := Vector2(meta.ysort[0], meta.ysort[1])
	root.position = area.objects.to_local(global_position) + ys
	var picture := Sprite2D.new()
	picture.name = "Sprite"
	picture.texture = HomeData.tex(HomeData.PROPS + "home/" + file)
	picture.centered = false
	picture.offset = -Vector2(meta.pivot[0], meta.pivot[1]) - ys
	root.add_child(picture)
	area.objects.add_child(root)
	_visuals.append(root)
	return root

func _process(_dt: float) -> void:
	if is_instance_valid(_night):
		_night.visible = TimeManager.is_night()

