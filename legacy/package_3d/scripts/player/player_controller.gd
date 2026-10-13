extends CharacterBody3D
## Camera-relative controller using the project's input actions and stable skin IDs.
## Physical movement stays on this body; only VisualRoot turns to face the travel direction.

const CharacterType = preload("res://scripts/autoload/game_manager.gd").CharacterType
const Catalog = preload("res://scripts/characters/character_catalog.gd")

@export var walk_speed: float = 5.5
@export var run_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var rotation_speed: float = 10.0
@export var acceleration: float = 12.0
@export_group("Flight")
@export var flight_vertical_speed: float = 3.0
@export var flight_height_limit: float = 7.0
@export var flight_stamina_per_second: float = 6.0

@onready var visual_root: Node3D = $VisualRoot
@onready var interact_ray: RayCast3D = $InteractRay
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D

var velocity_y: float = 0.0
var is_running: bool = false
var is_grounded: bool = true
var is_flying: bool = false
var current_skin: StringName = &"animal_rabbit"
var facing_direction: Vector3 = Vector3.FORWARD
var stamina: float = 100.0
var max_stamina: float = 100.0
var health: float = 100.0
var max_health: float = 100.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _camera_yaw: float = 0.0
var _camera_pitch: float = -0.35
var _camera_distance: float = 7.0
var _interaction_target: Node = null
var _chibi: Node3D = null
var _flight_origin_y: float = 0.0
var _was_grounded: bool = true

func _ready() -> void:
	# Receive Escape while paused, but gate all gameplay processing below.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visual_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	EventBus.player_character_changed.connect(_on_skin_changed)
	_apply_character_stats()
	current_skin = GameManager.character_skin
	if current_skin == &"default" or current_skin == &"":
		current_skin = &"animal_rabbit"
	_swap_visual(current_skin)
	_setup_camera()
	EventBus.player_spawned.emit(self)

func _physics_process(delta: float) -> void:
	if GameManager.current_phase != GameManager.GamePhase.PLAYING:
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Basis(Vector3.UP, _camera_yaw) * Vector3(input_dir.x, 0.0, input_dir.y)
	is_running = Input.is_action_pressed("run") and input_dir.length() > 0.1 and stamina > 0.0
	var target_speed := run_speed if is_running else walk_speed
	var moving := direction.length_squared() > 0.001
	if moving:
		direction = direction.normalized()
		facing_direction = direction
		var target_yaw := atan2(-direction.x, -direction.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, 1.0 - exp(-rotation_speed * delta))
		interact_ray.rotation.y = visual_root.rotation.y
	var horizontal := direction * target_speed
	var change := acceleration * delta * (target_speed if moving else 1.0)
	velocity.x = move_toward(velocity.x, horizontal.x, change)
	velocity.z = move_toward(velocity.z, horizontal.z, change)

	if is_flying:
		var vertical := Input.get_action_strength("jump") - Input.get_action_strength("fly_descend")
		var desired_y := vertical * flight_vertical_speed
		if global_position.y >= _flight_origin_y + flight_height_limit:
			desired_y = minf(desired_y, 0.0)
		velocity.y = move_toward(velocity.y, desired_y, 10.0 * delta)
		stamina = maxf(stamina - flight_stamina_per_second * delta, 0.0)
		if stamina <= 0.0 or (is_on_floor() and vertical < -0.1):
			set_flying(false)
	else:
		if is_on_floor():
			velocity.y = -0.1
		else:
			velocity.y -= _gravity * delta
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
			_play_action(&"jump")
	_was_grounded = is_on_floor()
	move_and_slide()
	if is_on_ceiling() and velocity.y > 0.0:
		velocity.y = 0.0
	velocity_y = velocity.y
	is_grounded = is_on_floor()
	_handle_interaction()
	_update_stamina(delta)
	_update_animation(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if GameManager.current_phase != GameManager.GamePhase.PLAYING:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw -= event.relative.x * 0.003
		_camera_pitch = clampf(_camera_pitch - event.relative.y * 0.002, -1.15, 0.10)
		_update_camera_transform()
	if event.is_action_pressed("zoom_in"):
		_camera_distance = maxf(3.0, _camera_distance - 0.6)
		_update_camera_transform()
	if event.is_action_pressed("zoom_out"):
		_camera_distance = minf(12.0, _camera_distance + 0.6)
		_update_camera_transform()
	if event.is_action_pressed("fly_toggle"):
		set_flying(not is_flying)
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("inventory"):
		EventBus.ui_panel_toggled.emit(&"inventory", true)
	if event.is_action_pressed("journal"):
		EventBus.ui_panel_toggled.emit(&"journal", true)

func can_fly() -> bool:
	return Catalog.model_for_skin(current_skin) in Catalog.FLYERS

func set_flying(enabled: bool) -> bool:
	if enabled:
		if not can_fly() or stamina < 10.0:
			return false
		if not is_flying:
			_flight_origin_y = global_position.y
			velocity.y = maxf(velocity.y, 2.4)
		is_flying = true
	else:
		is_flying = false
		velocity.y = minf(velocity.y, 0.0)
	return true

func _handle_interaction() -> void:
	_interaction_target = null
	# Chest-height NPCs first; then low farm animals and plots.
	for target in [Vector3(0, 0, -2.5), Vector3(0, -1.0, -2.5)]:
		interact_ray.target_position = target
		interact_ray.force_raycast_update()
		if not interact_ray.is_colliding():
			continue
		var collider: Object = interact_ray.get_collider()
		if collider is Node and collider.has_method("get_interaction_prompt"):
			_interaction_target = collider as Node
			return


func _try_interact() -> void:
	if is_instance_valid(_interaction_target) and _interaction_target.has_method("interact"):
		_play_action(&"interact")
		_interaction_target.interact(self)

func _update_stamina(delta: float) -> void:
	if is_running:
		stamina = maxf(stamina - 15.0 * delta, 0.0)
	elif not is_flying:
		stamina = minf(stamina + 2.0 * delta, max_stamina)
	EventBus.player_stats_changed.emit({"health": health, "max_health": max_health, "stamina": stamina, "max_stamina": max_stamina})

func _update_animation(delta: float) -> void:
	if is_instance_valid(_chibi) and _chibi.has_method("update_motion"):
		# Actual motion, not requested velocity: pushing into a wall does not run in place.
		var measured := get_real_velocity()
		_chibi.update_motion(Vector2(measured.x, measured.z).length(), velocity.y, is_on_floor(), is_flying, is_running, delta)

func _play_action(clip: StringName) -> void:
	if is_instance_valid(_chibi) and _chibi.has_method("play_action"):
		_chibi.play_action(clip)

func _apply_character_stats() -> void:
	var balance: Dictionary = LuaRuntime.get_config("player", {})
	walk_speed = float(balance.get("walk_speed", walk_speed))
	run_speed = float(balance.get("run_speed", run_speed))
	max_health = float(balance.get("max_health", 100.0))
	max_stamina = float(balance.get("max_stamina", 100.0))
	health = max_health
	stamina = max_stamina

func _on_skin_changed(skin: StringName) -> void:
	current_skin = skin
	GameManager.character_skin = skin
	is_flying = false
	_swap_visual(skin)
	_update_camera_transform()

func _swap_visual(skin: StringName) -> void:
	_chibi = null
	for child in visual_root.get_children():
		visual_root.remove_child(child)
		child.queue_free()
	var path := "res://scenes/player/skins/%s.tscn" % skin
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed:
			_chibi = packed.instantiate() as Node3D
			visual_root.add_child(_chibi)
	if _chibi == null:
		# Preserve original, not-yet-modelled owl and hobbit choices/save IDs.
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
	var dimensions: Vector2 = Catalog.collider_for_skin(skin)
	var shape := CapsuleShape3D.new()
	shape.height = dimensions.x
	shape.radius = dimensions.y
	collision.shape = shape
	collision.position.y = dimensions.x * 0.5
	interact_ray.position.y = minf(0.85, dimensions.x * 0.60)
	# Include the NPC layer as well as the original interactable layers.
	interact_ray.collision_mask = 124

func _skin_color(skin: StringName) -> Color:
	match skin:
		&"hobbit_pip": return Color(0.85, 0.7, 0.55)
		&"hobbit_moss": return Color(0.6, 0.75, 0.5)
		&"hobbit_bramble": return Color(0.7, 0.55, 0.45)
		&"animal_owl": return Color(0.65, 0.55, 0.45)
	return Color(0.8, 0.8, 0.8)

func _setup_camera() -> void:
	camera.current = true
	_update_camera_transform()

func _update_camera_transform() -> void:
	if camera_pivot == null or camera == null:
		return
	camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)
	camera.rotation = Vector3.ZERO
	camera.position = Vector3(0.0, 0.0, _camera_distance)

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
	if is_instance_valid(_interaction_target) and _interaction_target.has_method("get_interaction_prompt"):
		return _interaction_target.get_interaction_prompt()
	return ""

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	_play_action(&"hit")
	EventBus.player_stats_changed.emit({"health": health, "max_health": max_health})
	if health <= 0.0:
		_on_defeated()

func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	EventBus.player_stats_changed.emit({"health": health, "max_health": max_health})

func _on_defeated() -> void:
	set_flying(false)
	EventBus.notification_posted.emit(tr("NOTIF_DEFEATED_TITLE"), tr("NOTIF_DEFEATED_MSG"), "defeat")
	health = max_health * 0.5
	stamina = max_stamina
