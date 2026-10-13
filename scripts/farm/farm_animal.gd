extends CharacterBody3D
## Farm animal entity: visual, interaction, wandering on the farm.

@export var species: StringName = &""
@export var animal_id: StringName = &""

@export_group("Movement")
@export var wander_speed: float = 1.5
@export var follow_speed: float = 3.0
@export var wander_radius: float = 6.0
@export var idle_time_min: float = 3.0
@export var idle_time_max: float = 8.0

var _home_position: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _is_wandering: bool = false
var _is_following: bool = false
var _player_nearby: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _velocity_y: float = 0.0

@onready var visual_root: Node3D = $VisualRoot
@onready var name_label: Label3D = $NameLabel
@onready var interact_area: Area3D = $InteractArea


func _ready() -> void:
	add_to_group("farm_animal")
	add_to_group("animal_%s" % str(animal_id))
	_home_position = global_position
	_wander_target = _home_position
	_wander_timer = randf_range(idle_time_min, idle_time_max)

	_apply_visual()
	_setup_interaction()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_update_behavior(delta)
	move_and_slide()


func _update_behavior(delta: float) -> void:
	if _is_following and _player_nearby:
		_follow_player(delta)
	elif _is_wandering:
		_wander(delta)
	else:
		# Idle
		_wander_timer -= delta
		if _wander_timer <= 0:
			_pick_wander_target()
			_is_wandering = true


func _wander(delta: float) -> void:
	var dir := (_wander_target - global_position).normalized()
	dir.y = 0

	if global_position.distance_to(_wander_target) < 0.5:
		_is_wandering = false
		_wander_timer = randf_range(idle_time_min, idle_time_max)
		return

	velocity.x = dir.x * wander_speed
	velocity.z = dir.z * wander_speed
	_face_direction(dir, delta)


func _follow_player(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_is_following = false
		return

	var dist := global_position.distance_to(player.global_position)
	if dist < 2.0:
		velocity.x = 0
		velocity.z = 0
		return

	var dir := (player.global_position - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * follow_speed
	velocity.z = dir.z * follow_speed
	_face_direction(dir, delta)


func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(1.0, wander_radius)
	_wander_target = _home_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)


func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.1:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 6.0 * delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_velocity_y = -0.1
	else:
		_velocity_y -= _gravity * delta
	velocity.y = _velocity_y


# --- Interaction ---

func _setup_interaction() -> void:
	if interact_area == null:
		interact_area = Area3D.new()
		add_child(interact_area)

	interact_area.collision_layer = 0
	interact_area.collision_mask = 2  # player
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	col.shape = shape
	interact_area.add_child(col)

	interact_area.body_entered.connect(_on_player_near)
	interact_area.body_exited.connect(_on_player_far)


func _on_player_near(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		# Hop of joy if happy
		var handler := get_node_or_null("/root/AnimalHusbandry")
		if handler and handler.has_method("get_animal"):
			var animal = handler.get_animal(animal_id)
			if animal and animal.happiness > 60:
				_do_hop()


func _on_player_far(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_is_following = false


func _do_hop() -> void:
	var tween := create_tween()
	tween.tween_property(visual_root, "position:y", visual_root.position.y + 0.3, 0.15)
	tween.tween_property(visual_root, "position:y", visual_root.position.y, 0.15)


func get_interaction_prompt() -> String:
	return tr("UI_INTERACT_ANIMAL")


func interact(player: Node3D) -> void:
	# Open animal care menu
	EventBus.ui_panel_toggled.emit(&"animal_care", true)
	EventBus.lua_event.emit(&"animal_interacted", {
		"animal_id": str(animal_id),
		"species": str(species),
	})


# --- Visual ---

func _apply_visual() -> void:
	for child in visual_root.get_children():
		child.queue_free()

	var scene_path := "res://scenes/farm/animals/%s.tscn" % species
	if ResourceLoader.exists(scene_path):
		var scene := load(scene_path) as PackedScene
		if scene:
			visual_root.add_child(scene.instantiate())
			_update_name_label()
			return

	# Placeholder: capsule with species color
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 0.6
	capsule.radius = 0.25
	mesh.mesh = capsule
	mesh.position.y = 0.3

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _species_color()
	mesh.material_override = mat

	# Cute eyes
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.05
		eye_mesh.height = 0.1
		eye.mesh = eye_mesh
		var eye_mat := StandardMaterial3D.new()
		eye_mat.albedo_color = Color.BLACK
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.12, 0.45, -0.2)
		mesh.add_child(eye)

	visual_root.add_child(mesh)
	_update_name_label()


func _update_name_label() -> void:
	if name_label == null:
		return
	var handler := get_node_or_null("/root/AnimalHusbandry")
	var display_name := tr(SPECIES_NAME_KEY) if SPECIES_NAME_KEY != "" else str(species)
	if handler and handler.has_method("get_animal"):
		var animal = handler.get_animal(animal_id)
		if animal and animal.name != "":
			display_name = animal.name
	name_label.text = display_name


const SPECIES_NAME_KEY := ""

func _species_color() -> Color:
	match species:
		&"chicken": return Color(0.95, 0.9, 0.7)
		&"rabbit": return Color(0.92, 0.85, 0.8)
		&"duck": return Color(0.95, 0.85, 0.3)
		&"cat": return Color(0.7, 0.55, 0.4)
		&"dog": return Color(0.8, 0.65, 0.45)
		&"sheep": return Color(0.95, 0.93, 0.9)
		&"cow": return Color(0.85, 0.8, 0.75)
		&"deer": return Color(0.75, 0.55, 0.35)
		&"fox": return Color(0.9, 0.5, 0.2)
		&"owl": return Color(0.6, 0.5, 0.4)
	return Color(0.8, 0.8, 0.8)
