class_name IsoPlayerController2D
extends CharacterBody2D
## Top-down isometric-world player physics. Keyboard input is SCREEN-RELATIVE by default.
## Jumping and flying use visual height; body collision stays on the tile plane.

signal character_changed(id: String)

@export var walk_speed: float = 165.0
@export var run_speed: float = 260.0
@export var acceleration: float = 950.0
@export var deceleration: float = 1180.0
@export var jump_impulse: float = 370.0
@export var visual_gravity: float = 1050.0
@export var flight_altitude: float = 90.0
@export var flight_climb_speed: float = 135.0
@export var use_diamond_grid_axes: bool = false
@export var initial_character: String = "fox"

@onready var visual: IsoChibiSprite2D = $Visual

var is_flying: bool = false
var is_jumping: bool = false
var character_index: int = 7
var _altitude: float = 0.0
var _vertical_velocity: float = 0.0
var _landing: bool = false


func _ready() -> void:
	add_to_group("player_2d")
	set_character(initial_character)


func set_character(id: String) -> void:
	if id not in IsoChibiSprite2D.CHARACTER_IDS:
		return
	if is_flying and id not in ["bat", "fairy"]:
		is_flying = false
	visual.load_character(id)
	character_index = IsoChibiSprite2D.CHARACTER_IDS.find(id)
	character_changed.emit(id)


func cycle_character() -> void:
	set_character(IsoChibiSprite2D.CHARACTER_IDS[(character_index + 1) % IsoChibiSprite2D.CHARACTER_IDS.size()])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_TAB:
				cycle_character()
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_C:
				visual.play_action(&"celebrate")
			elif key.keycode == KEY_E:
				visual.play_action(&"interact")
	if event.is_action_pressed("fly_toggle"):
		if visual.character_id in ["bat", "fairy"]:
			is_flying = not is_flying
			if is_flying:
				is_jumping = false
				_vertical_velocity = 0.0
				visual.play_action(&"takeoff")
			else:
				_landing = true
				visual.play_action(&"flight_land")


func _physics_process(delta: float) -> void:
	var input_axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := input_axis
	if use_diamond_grid_axes:
		direction = Vector2(input_axis.x - input_axis.y, (input_axis.x + input_axis.y) * 0.5)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var sprinting := Input.is_action_pressed("run") and not is_flying
	var target := direction * (run_speed if sprinting else walk_speed)
	var response := acceleration if direction.length_squared() > 0.001 else deceleration
	velocity = velocity.move_toward(target, response * delta)
	move_and_slide()

	if is_flying:
		var climbing := Input.get_action_strength("jump") - Input.get_action_strength("fly_descend")
		_altitude = clampf(
			_altitude + climbing * flight_climb_speed * delta,
			0.0, flight_altitude * 1.8
		)
		if absf(climbing) < 0.1:
			_altitude = move_toward(_altitude, flight_altitude, delta * 100.0)
	elif _landing:
		_altitude = move_toward(_altitude, 0.0, delta * 160.0)
		if _altitude <= 0.0:
			_landing = false
			visual.play_action(&"land")
	else:
		if Input.is_action_just_pressed("jump") and not is_jumping:
			is_jumping = true
			_vertical_velocity = jump_impulse
			visual.play_action(&"jump")
		if is_jumping:
			_vertical_velocity -= visual_gravity * delta
			_altitude = maxf(0.0, _altitude + _vertical_velocity * delta)
			if _altitude == 0.0 and _vertical_velocity < 0.0:
				is_jumping = false
				_vertical_velocity = 0.0
				visual.play_action(&"land")

	visual.set_altitude(_altitude)
	visual.update_motion(velocity, sprinting, is_jumping or _landing, is_flying)
