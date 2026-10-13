extends Node3D
## Mushroom grove: foraging area with rare mushrooms and glowing flora.

const MUSHROOM_TYPES := {
	"rare_mushroom": {"color": Color(0.8, 0.3, 0.3), "chance": 0.3, "value": 35},
	"glowing_mushroom": {"color": Color(0.3, 0.9, 0.5), "chance": 0.15, "value": 80},
	"moon_cap": {"color": Color(0.7, 0.7, 0.9), "chance": 0.1, "value": 120},
	"common_mushroom": {"color": Color(0.7, 0.55, 0.4), "chance": 0.5, "value": 10},
}

@export var mushroom_count: int = 25
@export var regrow_days: int = 2

var _harvested: Array[StringName] = []


func _ready() -> void:
	add_to_group("mushroom_grove")
	_spawn_mushrooms()
	_spawn_glowing_flora()
	EventBus.day_started.connect(_on_day_started)


func _spawn_mushrooms() -> void:
	for i in mushroom_count:
		var angle := randf() * TAU
		var dist := randf_range(1.0, 12.0)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		_spawn_mushroom(pos)


func _spawn_mushroom(pos: Vector3) -> void:
	var roll := randf()
	var mush_id := "common_mushroom"
	var cumulative := 0.0
	for mid in MUSHROOM_TYPES:
		cumulative += MUSHROOM_TYPES[mid]["chance"]
		if roll <= cumulative:
			mush_id = mid
			break

	var mush: Dictionary = MUSHROOM_TYPES[mush_id]

	var node := Node3D.new()
	node.position = pos

	# Stem
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.height = randf_range(0.3, 0.7)
	stem_mesh.top_radius = 0.06
	stem_mesh.bottom_radius = 0.1
	stem.mesh = stem_mesh
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.9, 0.85, 0.7)
	stem.material_override = stem_mat
	stem.position.y = stem_mesh.height / 2
	node.add_child(stem)

	# Cap
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = randf_range(0.15, 0.35)
	cap_mesh.height = cap_mesh.radius * 0.8
	cap.mesh = cap_mesh
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = mush["color"]
	if mush_id == "glowing_mushroom" or mush_id == "moon_cap":
		cap_mat.emission_enabled = true
		cap_mat.emission = mush["color"]
		cap_mat.emission_energy_multiplier = 1.2
	cap.material_override = cap_mat
	cap.position.y = stem_mesh.height
	node.add_child(cap)

	# Interaction
	var body := StaticBody3D.new()
	body.collision_layer = 64
	body.collision_mask = 0
	body.set_meta("node_id", StringName("mushroom_%s_%d" % [mush_id, _harvested.size()]))
	body.set_meta("node_type", "mushroom_patch")
	body.set_script(load("res://scripts/world/resource_node_interactable.gd"))

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	col.shape = shape
	col.position.y = 0.3
	body.add_child(col)

	node.add_child(body)

	# Small glow light for special mushrooms
	if mush_id == "glowing_mushroom":
		var light := OmniLight3D.new()
		light.light_color = mush["color"]
		light.light_energy = 0.3
		light.omni_range = 2.0
		light.position.y = 0.4
		node.add_child(light)

	add_child(node)


func _spawn_glowing_flora() -> void:
	for i in 15:
		var angle := randf() * TAU
		var dist := randf_range(2.0, 14.0)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)

		var flora := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.08, 0.15)
		mesh.height = mesh.radius
		flora.mesh = mesh

		var mat := StandardMaterial3D.new()
		var hue := randf()
		mat.albedo_color = Color.from_hsv(hue, 0.7, 1.0)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.8
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flora.material_override = mat

		flora.position = pos + Vector3(0, 0.1, 0)
		add_child(flora)


func _on_day_started(day: int, _season: StringName) -> void:
	if day % regrow_days == 0:
		for i in 5:
			var angle := randf() * TAU
			var dist := randf_range(1.0, 12.0)
			_spawn_mushroom(Vector3(cos(angle) * dist, 0, sin(angle) * dist))
