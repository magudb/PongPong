class_name Animal2D
extends CharacterBody2D
## Painted animal actors share the character animation presenter. State stays
## in AnimalHusbandry; leaving the farm never stops growth or production.
const VISUALS := {"chicken":["chick","hen"],"rabbit":["bunny","bunny"],"duck":["duck","duck"],"cat":["kitten","kitten"],"dog":["puppy","puppy"],"sheep":["lamb","lamb"],"cow":["calf","calf"],"deer":["fawn","fawn"],"fox":["fox_cub","fox_cub"],"owl":["owl","owl"]}
var animal_id: StringName
var yard: Node2D
var visual: IsoChibiSprite2D
var bubble: Label
var _look := ""
var _target := Vector2.ZERO
var _wait := 0.0
var _rng := RandomNumberGenerator.new()

static func create_marker(params: Dictionary, pos: Vector2, _cell: Vector2i, area: IsoArea) -> Node:
	var service: Node2D = load("res://scripts/farm/animal_yard.gd").new()
	service.area = area
	service.position = area.to_local(pos)
	service.radius = float(params.get("r",3))
	return service

func _ready() -> void:
	add_to_group("farm_animal")
	collision_layer = Iso.LAYER_NPC
	collision_mask = Iso.LAYER_WORLD
	var body := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16
	body.shape = shape
	add_child(body)
	var area := Area2D.new()
	area.collision_layer = Iso.LAYER_INTERACTABLE
	area.collision_mask = 0
	var reach := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 46
	reach.shape = circle
	area.add_child(reach)
	add_child(area)
	bubble = Label.new()
	bubble.text = "!"
	bubble.theme = load("res://assets/ui/theme.tres")
	bubble.theme_type_variation = &"Heading22"
	bubble.position = Vector2(-8,-110)
	add_child(bubble)
	_rng.seed = hash(str(animal_id))
	refresh()
	_target = global_position

func refresh() -> void:
	var animal = AnimalHusbandry.get_animal(animal_id)
	if animal == null: return
	var options: Array = VISUALS.get(str(animal.species),["chick","hen"])
	var id: String = options[0 if animal.is_baby else 1]
	var look := id + str(animal.is_baby)
	if look != _look:
		_look = look
		if visual != null:
			remove_child(visual)
			visual.queue_free()
		visual = IsoChibiSprite2D.create(id)
		visual.scale = Vector2.ONE * (0.55 if animal.is_baby else 0.8)
		add_child(visual)
		bubble.move_to_front()
	bubble.visible = animal.products_ready > 0

func get_interaction_prompt() -> String:
	var animal = AnimalHusbandry.get_animal(animal_id)
	return tr("ANIMAL_CARE_PROMPT") % animal.name if animal != null else ""
func interact(_player: Node) -> void:
	EventBus.game_event.emit(&"open_animal_care",{"animal":str(animal_id)})

func _physics_process(dt: float) -> void:
	_wait -= dt
	var delta := Iso.to_ground(_target - global_position)
	if delta.length() < 8.0:
		velocity = Vector2.ZERO
		if _wait <= 0:
			_target = yard.pick_target(_rng)
			_wait = _rng.randf_range(2,5)
	else:
		velocity = Iso.to_screen(delta.normalized() * 40.0)
		if _wait <= -3:
			_target = yard.pick_target(_rng)
			_wait = 2.0
	move_and_slide()
	if visual != null: visual.update_motion(velocity)
