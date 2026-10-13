extends Node3D
## Crystal cave: sub-area of the dark forest with rare gems.

const GEM_TYPES := {
	"amethyst": {"color": Color(0.6, 0.2, 0.8), "chance": 0.4, "value": 90},
	"emerald": {"color": Color(0.1, 0.7, 0.3), "chance": 0.25, "value": 200},
	"ruby": {"color": Color(0.8, 0.1, 0.15), "chance": 0.15, "value": 350},
	"crystal_shard": {"color": Color(0.5, 0.8, 1.0), "chance": 0.35, "value": 120},
}

@export var crystal_count: int = 20
@export var glow_intensity: float = 1.5

var _collected: Array[StringName] = []


func _ready() -> void:
	add_to_group("crystal_cave")
	_spawn_crystals()
	_setup_cave_lighting()
	EventBus.zone_entered.connect(_on_zone_entered)


func _spawn_crystals() -> void:
	for i in crystal_count:
		var angle := randf() * TAU
		var dist := randf_range(2.0, 18.0)
		var pos := Vector3(cos(angle) * dist, randf_range(0, 4), sin(angle) * dist)
		_spawn_crystal(pos)


func _spawn_crystal(pos: Vector3) -> void:
	# Pick gem type
	var roll := randf()
	var gem_id := "crystal_shard"
	var cumulative := 0.0
	for gid in GEM_TYPES:
		cumulative += GEM_TYPES[gid]["chance"]
		if roll <= cumulative:
			gem_id = gid
			break

	var gem: Dictionary = GEM_TYPES[gem_id]
	var mesh := MeshInstance3D.new()

	var prism := PrismMesh.new()
	var size := randf_range(0.3, 0.9)
	prism.size = Vector3(size, size * randf_range(1.5, 2.5), size)
	mesh.mesh = prism

	var mat := StandardMaterial3D.new()
	mat.albedo_color = gem["color"]
	mat.emission_enabled = true
	mat.emission = gem["color"]
	mat.emission_energy_multiplier = glow_intensity
	mat.roughness = 0.2
	mat.metallic = 0.3
	mesh.material_override = mat

	mesh.position = pos
	mesh.rotation = Vector3(randf() * 0.5, randf() * TAU, randf() * 0.5)
	mesh.set_meta("gem_id", gem_id)

	var body := StaticBody3D.new()
	body.collision_layer = 64
	body.collision_mask = 0
	body.set_meta("node_id", StringName("crystal_%s_%d" % [gem_id, _collected.size()]))
	body.set_meta("node_type", "crystal_node")
	body.set_script(load("res://scripts/world/resource_node_interactable.gd"))

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, size * 2, size)
	col.shape = shape
	body.add_child(col)

	mesh.add_child(body)

	# Glow light
	var light := OmniLight3D.new()
	light.light_color = gem["color"]
	light.light_energy = 0.4
	light.omni_range = size * 4.0
	mesh.add_child(light)

	add_child(mesh)


func _setup_cave_lighting() -> void:
	# Ambient purple/blue glow
	var ambient := OmniLight3D.new()
	ambient.name = "CaveAmbient"
	ambient.light_color = Color(0.3, 0.2, 0.5)
	ambient.light_energy = 0.6
	ambient.omni_range = 30.0
	ambient.position.y = 8
	add_child(ambient)

	# Central crystal light
	var center := OmniLight3D.new()
	center.name = "CenterGlow"
	center.light_color = Color(0.5, 0.6, 1.0)
	center.light_energy = 1.0
	center.omni_range = 25.0
	center.position = Vector3(0, 5, 0)
	add_child(center)


func _on_zone_entered(zone_id: StringName) -> void:
	if zone_id == &"crystal_cave":
		EventBus.notification_posted.emit(
			tr("ZONE_CRYSTAL_CAVE"),
			tr("QUEST_CRYSTAL_CAVE_OFFER"),
			"zone"
		)
		AudioManager.play_music("crystal_cave_theme")


func get_gem_value(gem_id: String) -> int:
	return GEM_TYPES.get(gem_id, {}).get("value", 50)
