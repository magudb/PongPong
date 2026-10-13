extends CharacterBody3D
## Simple enemy: patrols, chases player, deals contact damage.

enum EnemyState { PATROL, CHASE, ATTACK, STUNNED, DEAD }

@export var max_health: float = 30.0
@export var move_speed: float = 3.0
@export var chase_speed: float = 5.5
@export var damage: float = 8.0
@export var attack_range: float = 1.8
@export var detection_range: float = 12.0
@export var lose_interest_range: float = 20.0
@export var patrol_radius: float = 10.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var health: float
var current_state: int = EnemyState.PATROL
var home_position: Vector3 = Vector3.ZERO

var _player: Node3D = null
var _patrol_target: Vector3 = Vector3.ZERO
var _patrol_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _velocity_y: float = 0.0
var _stun_timer: float = 0.0


func _ready() -> void:
	health = max_health
	home_position = global_position
	_patrol_target = _random_patrol_point()
	_player = get_tree().get_first_node_in_group("player")
	EventBus.enemy_encountered.emit(name)


func _physics_process(delta: float) -> void:
	if current_state == EnemyState.DEAD:
		return

	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_apply_gravity(delta)

	match current_state:
		EnemyState.PATROL:
			_patrol(delta)
		EnemyState.CHASE:
			_chase(delta)
		EnemyState.ATTACK:
			_attack(delta)
		EnemyState.STUNNED:
			_stun(delta)

	move_and_slide()
	_check_player_distance()


func _patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0:
		_patrol_target = _random_patrol_point()
		_patrol_timer = randf_range(3.0, 8.0)

	_move_toward(_patrol_target, move_speed, delta)

	if global_position.distance_to(_patrol_target) < 1.5:
		_patrol_timer = randf_range(2.0, 5.0)


func _chase(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		current_state = EnemyState.PATROL
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist > lose_interest_range:
		current_state = EnemyState.PATROL
		return

	if dist <= attack_range:
		current_state = EnemyState.ATTACK
		return

	nav_agent.target_position = _player.global_position
	_move_toward(_player.global_position, chase_speed, delta)


func _attack(_delta: float) -> void:
	if _player == null:
		current_state = EnemyState.PATROL
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist > attack_range * 1.2:
		current_state = EnemyState.CHASE
		return

	if _attack_cooldown <= 0:
		_perform_attack()
		_attack_cooldown = 1.2


func _perform_attack() -> void:
	if _player and _player.has_method("take_damage"):
		_player.take_damage(damage)
		# Lunge animation hook
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3(1.15, 0.9, 1.15), 0.1)
		tween.tween_property(self, "scale", Vector3.ONE, 0.2)


func _stun(delta: float) -> void:
	_stun_timer -= delta
	velocity.x = 0
	velocity.z = 0
	if _stun_timer <= 0:
		current_state = EnemyState.CHASE if _player and is_instance_valid(_player) else EnemyState.PATROL


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var direction := (target - global_position).normalized()
	direction.y = 0
	velocity.x = move_toward(velocity.x, direction.x * speed, 8.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 8.0 * delta)

	if direction.length() > 0.1:
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 6.0 * delta)


func _check_player_distance() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= detection_range and current_state == EnemyState.PATROL:
		current_state = EnemyState.CHASE


func _random_patrol_point() -> Vector3:
	var angle := randf() * TAU
	var dist := randf_range(2.0, patrol_radius)
	return home_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_velocity_y = -0.1
	else:
		_velocity_y -= _gravity * delta
	velocity.y = _velocity_y


func take_damage(amount: float) -> void:
	health -= amount
	current_state = EnemyState.STUNNED
	_stun_timer = 0.3

	# Flash red
	_flash_damage()

	if health <= 0:
		_die()


func _flash_damage() -> void:
	for child in get_children():
		if child is MeshInstance3D and child.material_override:
			var mat := child.material_override as StandardMaterial3D
			var original := mat.albedo_color
			mat.albedo_color = Color.RED
			var tween := create_tween()
			tween.tween_property(mat, "albedo_color", original, 0.3)


func _die() -> void:
	current_state = EnemyState.DEAD
	# Drop loot
	var loot_tables := {
		"ShadowCreature": {"fairy_dust": 0.15, "amethyst": 0.08, "iron_ore": 0.3},
	}
	var drops: Array = []
	var table: Dictionary = loot_tables.get(name, loot_tables["ShadowCreature"])
	for item_id in table:
		if randf() < table[item_id]:
			drops.append({"id": StringName(item_id), "amount": 1})

	for entry in drops:
		EconomyManager.add_item(entry["id"], entry["amount"])

	EventBus.combat_finished.emit(true)
	EventBus.resource_node_depleted.emit(StringName(name), drops)

	# Death animation
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.2, 0.1, 0.3, 0.0), 0.5)
	tween.tween_callback(queue_free)
