class_name IsoWanderer2D
extends CharacterBody2D
## Lightweight independent roaming character for NPCs / animal previews.

@export_enum("bat", "cat", "bear", "rabbit", "fairy", "monkey", "capybara", "fox", "raccoon", "penguin", "hedgehog", "frog")
var character_id: String = "bear"
@export var roam_radius: float = 135.0
@export var pace: float = 55.0

@onready var visual: IsoChibiSprite2D = $Visual
var _home: Vector2
var _target: Vector2
var _wait: float = 0.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.seed = absi(hash(str(get_instance_id()) + character_id))
	_home = global_position
	visual.load_character(character_id)
	_pick_destination()


func _physics_process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		velocity = velocity.move_toward(Vector2.ZERO, pace * delta * 4)
		move_and_slide()
		visual.update_motion(velocity)
		return
	var direction := _target - global_position
	if direction.length() <= 9.0:
		_wait = _random.randf_range(0.7, 2.5)
		_pick_destination()
		velocity = Vector2.ZERO
	else:
		velocity = direction.normalized() * pace
	move_and_slide()
	visual.update_motion(velocity)


func _pick_destination() -> void:
	var theta := _random.randf_range(0.0, TAU)
	var distance := _random.randf_range(20.0, roam_radius)
	_target = _home + Vector2(cos(theta), sin(theta) * 0.55) * distance
