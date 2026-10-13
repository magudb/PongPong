extends CharacterBody3D
## Third-person player controller with character types (animal / fairy / hobbit).
## Character visuals swap via skins; movement stats come from Lua config.

const CharacterType = preload("res://scripts/autoload/game_manager.gd").CharacterType

@export var walk_speed: float = 5.5
@export var run_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var rotation_speed: float = 10.0
@export var acceleration: float = 12.0

@onready var visual_root: Node3D = $VisualRoot
@onready var animation_tree: AnimationTree = get_node_or_null("AnimationTree")
@onready var interact_ray: RayCast3D = $InteractRay
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D

var velocity_y: float = 0.0
var is_running: bool = false
var is_grounded: bool = true
var current_skin: StringName = &"animal_rabbit"
var facing_direction: Vector3 = Vector3.FORWARD
var stamina: float = 100.0
var max_stamina: float = 100.0
var health: float = 100.0
var max_health: float = 100.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _camera_yaw: float = 0.0
var _camera_pitch: float = -0.35
var _interaction_target: Node = null


func _ready() -> void:
	add_to_group("player")
	EventBus.player_spawned.emit(self)
	EventBus.player_character_changed.connect(_on_skin_changed)
	_apply_character_stats()
	_setup_camera()


func _physics_process(delta: float) -> void:
	if GameManager.current_phase != GameManager.GamePhase.PLAYING:
		return

	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_interaction()
	_update_stamina(delta)
	_update_animation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw -= event.relative.x * 0.003
		_camera_pitch = clampf(_camera_pitch - event.relative.y * 0.002, -1.2, 0.4)
		_update_camera_transform()

	if event.is_action_pressed("pause"):
		_toggle_pause()
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("inventory"):
		EventBus.ui_panel_toggled.emit(&"inventory", true)
	if event.is_action_pressed("journal"):
		EventBus.ui_panel_toggled.emit(&"journal", true)


func _handle_gravity(delta: float) -> void:
	if is_on_floor():
		if not is_grounded:
			is_grounded = true
		velocity_y = -0.1
	else:
		is_grounded = false
		velocity_y -= _gravity * delta
		velocity.y = velocity_y


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	is_running = Input.is_key_pressed(KEY_SHIFT) and stamina > 0.0
	var target_speed := run_speed if is_running else walk_speed

	if direction.length() > 0.1:
		facing_direction = facing_direction.lerp(direction, rotation_speed * delta).normalized()
		var target_yaw := atan2(-facing_direction.x, -facing_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)

		var horizontal := Vector3(direction.x * target_speed, 0, direction.z * target_speed)
		velocity.x = move_toward(velocity.x, horizontal.x, acceleration * delta * target_speed)
		velocity.z = move_toward(velocity.z, horizontal.z, acceleration * delta * target_speed)

		if is_running:
			stamina = maxf(stamina - 15.0 * delta, 0.0)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity_y = jump_velocity
		velocity.y = velocity_y

	move_and_slide()


func _handle_interaction() -> void:
	if interact_ray.is_colliding():
		var collider := interact_ray.get_collider()
		if collider and collider.has_method("get_interaction_prompt"):
			_interaction_target = collider
			return
	_interaction_target = null


func _try_interact() -> void:
	if _interaction_target and _interaction_target.has_method("interact"):
		_interaction_target.interact(self)


func _update_stamina(delta: float) -> void:
	if not is_running:
		stamina = minf(stamina + 2.0 * delta, max_stamina)
	EventBus.player_stats_changed.emit({
		"health": health,
		"max_health": max_health,
		"stamina": stamina,
		"max_stamina": max_stamina,
	})


func _update_animation() -> void:
	if animation_tree == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	animation_tree.set("parameters/blend_position", speed / run_speed if is_running else speed / walk_speed)
	animation_tree.set("parameters/grounded/is_grounded", is_grounded)


func _apply_character_stats() -> void:
	var balance: Dictionary = LuaRuntime.get_config("player", {})
	walk_speed = balance.get("walk_speed", walk_speed)
	run_speed = balance.get("run_speed", run_speed)
	max_health = balance.get("max_health", 100.0)
	max_stamina = balance.get("max_stamina", 100.0)
	health = max_health
	stamina = max_stamina


func _on_skin_changed(skin: StringName) -> void:
	current_skin = skin
	_swap_visual(skin)


func _swap_visual(skin: StringName) -> void:
	# Clear existing visual children
	for child in visual_root.get_children():
		child.queue_free()

	var scene_path := "res://scenes/player/skins/%s.tscn" % skin
	if ResourceLoader.exists(scene_path):
		var scene := load(scene_path) as PackedScene
		if scene:
			visual_root.add_child(scene.instantiate())
	else:
		# Placeholder capsule until art is ready
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.height = 1.6
		capsule.radius = 0.4
		mesh.mesh = capsule
		mesh.position.y = 0.8
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _skin_color(skin)
		mesh.material_override = mat
		visual_root.add_child(mesh)


func _skin_color(skin: StringName) -> Color:
	match skin:
		&"animal_rabbit":
			return Color(0.95, 0.88, 0.82)
		&"animal_fox":
			return Color(0.9, 0.5, 0.2)
		&"animal_bear":
			return Color(0.55, 0.38, 0.25)
		&"fairy_meadow":
			return Color(0.7, 0.9, 0.75)
		&"fairy_stardust":
			return Color(0.75, 0.7, 0.95)
		&"hobbit_pip":
			return Color(0.85, 0.7, 0.55)
		&"hobbit_moss":
			return Color(0.6, 0.75, 0.5)
	return Color(0.8, 0.8, 0.8)


func _setup_camera() -> void:
	if camera_pivot:
		_update_camera_transform()


func _update_camera_transform() -> void:
	if camera_pivot == null:
		return
	camera_pivot.rotation.y = _camera_yaw
	if camera:
		camera.rotation.x = _camera_pitch
		var dist := 8.0
		if current_skin.begins_with("fairy"):
			dist = 6.0
		camera.position = Vector3(0, 2.0, dist)


func _toggle_pause() -> void:
	if GameManager.current_phase == GameManager.GamePhase.PLAYING:
		GameManager.change_phase(GameManager.GamePhase.PAUSED)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		EventBus.ui_panel_toggled.emit(&"pause", true)
	elif GameManager.current_phase == GameManager.GamePhase.PAUSED:
		GameManager.change_phase(GameManager.GamePhase.PLAYING)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		EventBus.ui_panel_toggled.emit(&"pause", false)


func get_interaction_prompt() -> String:
	if _interaction_target and _interaction_target.has_method("get_interaction_prompt"):
		return _interaction_target.get_interaction_prompt()
	return ""


func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	EventBus.player_stats_changed.emit({"health": health, "max_health": max_health})
	if health <= 0:
		_on_defeated()


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	EventBus.player_stats_changed.emit({"health": health, "max_health": max_health})


func _on_defeated() -> void:
	EventBus.notification_posted.emit(
		tr("NOTIF_DEFEATED_TITLE"),
		tr("NOTIF_DEFEATED_MSG"),
		"defeat"
	)
	# Respawn at farm
	health = max_health * 0.5
	stamina = max_stamina
