extends Node3D
## Dark forest zone: atmosphere, fog, lighting, enemy spawners, layered depth.

@export_group("Atmosphere")
@export var fog_density: float = 0.035
@export var fog_color: Color = Color(0.05, 0.08, 0.12)
@export var ambient_color: Color = Color(0.15, 0.2, 0.25)
@export var moonlight_energy: float = 0.4
@export var firefly_count: int = 40

@export_group("Layout")
@export var forest_radius: float = 60.0
@export var inner_clearing_radius: float = 15.0
@export var tree_density: float = 0.3

@export_group("Gameplay")
@export var max_enemies: int = 8
@export var enemy_spawn_interval: float = 25.0
@export var ore_respawn_days: int = 3

var active_enemies: Array[Node3D] = []
var fireflies: Array[Node3D] = []
var _spawn_timer: float = 0.0
var _is_active: bool = false

@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D
@onready var enemy_spawns: Node3D = $EnemySpawns
@onready var resource_nodes: Node3D = $ResourceNodes
@onready var atmosphere: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	add_to_group("dark_forest")
	EventBus.zone_entered.connect(_on_zone_entered)
	EventBus.zone_exited.connect(_on_zone_exited)
	EventBus.day_started.connect(_on_day_started)
	_setup_atmosphere()
	_populate_trees()
	_spawn_fireflies()


func _process(delta: float) -> void:
	if not _is_active:
		return
	_animate_fireflies(delta)
	_update_enemy_spawns(delta)
	_animate_fog(delta)


# --- Atmosphere ---

func _setup_atmosphere() -> void:
	if atmosphere and atmosphere.environment:
		var env := atmosphere.environment
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_density = fog_density
		env.ambient_light_color = ambient_color
		env.ambient_light_energy = 0.3

	# Moonlight
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.light_color = Color(0.7, 0.8, 1.0)
	moon.light_energy = moonlight_energy
	moon.shadow_enabled = true
	add_child(moon)


func _animate_fog(delta: float) -> void:
	if atmosphere and atmosphere.environment:
		var env := atmosphere.environment
		# Gentle fog density oscillation
		var t := Time.get_ticks_msec() / 1000.0
		env.fog_density = fog_density + sin(t * 0.1) * 0.005


# --- Trees & vegetation ---

func _populate_trees() -> void:
	var tree_count := int(forest_radius * forest_radius * tree_density / 10.0)
	for i in tree_count:
		var angle := randf() * TAU
		var dist := randf_range(inner_clearing_radius, forest_radius)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		_spawn_tree(pos)


func _spawn_tree(pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = pos

	# Trunk
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = randf_range(6.0, 14.0)
	trunk_mesh.top_radius = randf_range(0.2, 0.5)
	trunk_mesh.bottom_radius = trunk_mesh.top_radius * 1.5
	trunk.mesh = trunk_mesh
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.15, 0.1, 0.08)
	trunk.material_override = trunk_mat
	trunk.position.y = trunk_mesh.height / 2.0
	tree.add_child(trunk)

	# Canopy layers (dark, spooky)
	for layer in 3:
		var canopy := MeshInstance3D.new()
		var canopy_mesh := SphereMesh.new()
		var scale := randf_range(2.0, 4.5) - layer * 0.5
		canopy_mesh.radius = scale
		canopy_mesh.height = scale * 1.2
		canopy.mesh = canopy_mesh
		var canopy_mat := StandardMaterial3D.new()
		canopy_mat.albedo_color = Color(0.05 + randf() * 0.05, 0.12 + randf() * 0.08, 0.08)
		canopy.material_override = canopy_mat
		canopy.position.y = trunk_mesh.height - layer * 1.5
		tree.add_child(canopy)

	# Collision for trunk
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = trunk_mesh.height
	shape.radius = trunk_mesh.bottom_radius
	col.shape = shape
	col.position.y = trunk_mesh.height / 2.0
	body.add_child(col)
	tree.add_child(body)

	add_child(tree)


func _spawn_fireflies() -> void:
	for i in firefly_count:
		var fly := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.06
		mesh.height = 0.12
		fly.mesh = mesh

		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission = Color(0.8, 1.0, 0.6)
		mat.emission_energy_multiplier = 3.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fly.material_override = mat

		var angle := randf() * TAU
		var dist := randf_range(5.0, forest_radius * 0.8)
		fly.position = Vector3(
			cos(angle) * dist,
			randf_range(1.0, 8.0),
			sin(angle) * dist
		)
		fly.set_meta("base_pos", fly.position)
		fly.set_meta("phase", randf() * TAU)
		fly.set_meta("speed", randf_range(0.3, 0.8))
		add_child(fly)
		fireflies.append(fly)


func _animate_fireflies(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for fly in fireflies:
		if not is_instance_valid(fly):
			continue
		var base: Vector3 = fly.get_meta("base_pos", Vector3.ZERO)
		var phase: float = fly.get_meta("phase", 0.0)
		var speed: float = fly.get_meta("speed", 0.5)
		fly.position = base + Vector3(
			sin(t * speed + phase) * 0.5,
			cos(t * speed * 0.7 + phase) * 0.3,
			cos(t * speed + phase) * 0.5
		)
		# Pulsing glow
		var mesh := fly as MeshInstance3D
		if mesh and mesh.material_override:
			var mat := mesh.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 2.0 + sin(t * 2.0 + phase) * 1.0


# --- Enemies ---

func _update_enemy_spawns(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0 and active_enemies.size() < max_enemies:
		_spawn_enemy()
		_spawn_timer = enemy_spawn_interval


func _spawn_enemy() -> void:
	var angle := randf() * TAU
	var dist := randf_range(20.0, forest_radius * 0.7)
	var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)

	var enemy := CharacterBody3D.new()
	enemy.name = "ShadowCreature"
	enemy.position = pos
	enemy.collision_layer = 16  # enemy
	enemy.collision_mask = 1
	enemy.set_script(load("res://scripts/world/enemy.gd"))

	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.height = 1.2
	mesh.radius = 0.35
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.05, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.1, 0.5)
	mat.emission_energy_multiplier = 0.5
	visual.material_override = mat
	visual.position.y = 0.6
	enemy.add_child(visual)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.2
	shape.radius = 0.35
	col.shape = shape
	col.position.y = 0.6
	enemy.add_child(col)

	var nav := NavigationAgent3D.new()
	nav.name = "NavigationAgent3D"
	enemy.add_child(nav)

	add_child(enemy)
	active_enemies.append(enemy)


func _on_zone_entered(zone_id: StringName) -> void:
	if zone_id == &"dark_forest":
		_is_active = true
		AudioManager.play_music("dark_forest_theme")
		EventBus.notification_posted.emit(
			tr("ZONE_DARK_FOREST"),
			tr("DIALOGUE_OAK_GREET"),
			"zone"
		)


func _on_zone_exited(zone_id: StringName) -> void:
	if zone_id == &"dark_forest":
		_is_active = false


func _on_day_started(_day: int, _season: StringName) -> void:
	# Respawn depleted resources
	if _day % ore_respawn_days == 0:
		for i in 5:
			# Handled by dark_forest.gd resource spawner
			pass
	# Despawn far enemies
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.global_position.length() > forest_radius * 1.2:
			enemy.queue_free()
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
