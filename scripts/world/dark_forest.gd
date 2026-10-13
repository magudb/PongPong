extends Node3D
## Dark forest adventure: resource nodes, mining, rare loot, simple encounters.

const NODE_TYPES := {
	"iron_node": {
		"item_id": "iron_ore",
		"hp": 3,
		"yield_min": 1,
		"yield_max": 3,
		"rare_table": {"amethyst": 0.08, "emerald": 0.03},
	},
	"gold_node": {
		"item_id": "gold_ore",
		"hp": 5,
		"yield_min": 1,
		"yield_max": 2,
		"rare_table": {"emerald": 0.1, "fairy_dust": 0.05},
	},
	"stone_node": {
		"item_id": "stone",
		"hp": 2,
		"yield_min": 2,
		"yield_max": 4,
		"rare_table": {"amethyst": 0.04},
	},
	"crystal_node": {
		"item_id": "amethyst",
		"hp": 4,
		"yield_min": 1,
		"yield_max": 2,
		"rare_table": {"emerald": 0.15, "fairy_dust": 0.1},
	},
	"mushroom_patch": {
		"item_id": "rare_mushroom",
		"hp": 1,
		"yield_min": 1,
		"yield_max": 2,
		"rare_table": {"lucky_clover": 0.12},
	},
}

@export var spawn_radius: float = 40.0
@export var max_nodes: int = 30

var active_nodes: Dictionary = {}  # node_id -> {type, hp, position}
var _node_counter: int = 0


func _ready() -> void:
	add_to_group("dark_forest")
	EventBus.zone_entered.connect(_on_zone_entered)
	EventBus.day_started.connect(_on_day_started)


func _on_zone_entered(zone_id: StringName) -> void:
	if zone_id == &"dark_forest" and active_nodes.is_empty():
		populate_forest()


func populate_forest() -> void:
	for i in max_nodes:
		_spawn_random_node()


func _spawn_random_node() -> void:
	var types := NODE_TYPES.keys()
	var type: String = types[randi() % types.size()]
	var angle := randf() * TAU
	var dist := randf_range(5.0, spawn_radius)
	var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)

	_node_counter += 1
	var node_id := StringName("node_%d" % _node_counter)
	active_nodes[node_id] = {
		"type": type,
		"hp": NODE_TYPES[type]["hp"],
		"position": pos,
		"depleted": false,
	}
	_spawn_node_visual(node_id, type, pos)


func _spawn_node_visual(node_id: StringName, type: String, pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	match type:
		"iron_node":
			box.size = Vector3(1.2, 1.0, 1.2)
			mesh.mesh = box
			_set_color(mesh, Color(0.55, 0.55, 0.6))
		"gold_node":
			box.size = Vector3(1.0, 0.9, 1.0)
			mesh.mesh = box
			_set_color(mesh, Color(0.9, 0.75, 0.2))
		"crystal_node":
			var prism := PrismMesh.new()
			prism.size = Vector3(0.8, 1.5, 0.8)
			mesh.mesh = prism
			_set_color(mesh, Color(0.6, 0.3, 0.8))
		"mushroom_patch":
			var sphere := SphereMesh.new()
			sphere.radius = 0.4
			sphere.height = 0.8
			mesh.mesh = sphere
			_set_color(mesh, Color(0.8, 0.3, 0.3))
		_:
			box.size = Vector3(1.0, 0.8, 1.0)
			mesh.mesh = box
			_set_color(mesh, Color(0.5, 0.5, 0.5))

	mesh.position = pos + Vector3(0, 0.5, 0)
	mesh.set_meta("node_id", node_id)

	var body := StaticBody3D.new()
	body.collision_layer = 64  # resource_node
	body.collision_mask = 0
	body.set_meta("node_id", node_id)
	body.set_meta("node_type", type)
	body.set_script(load("res://scripts/world/resource_node_interactable.gd"))

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 1.2)
	col.shape = shape
	body.add_child(col)
	mesh.add_child(body)
	add_child(mesh)


func hit_node(node_id: StringName, damage: int = 1) -> Dictionary:
	if not active_nodes.has(node_id):
		return {}
	var node: Dictionary = active_nodes[node_id]
	if node["depleted"]:
		return {}

	node["hp"] -= damage
	EventBus.resource_node_hit.emit(node_id, StringName(node["type"]), damage)

	if node["hp"] <= 0:
		return _deplete_node(node_id)
	return {"hp": node["hp"], "max_hp": NODE_TYPES[node["type"]]["hp"]}


func _deplete_node(node_id: StringName) -> Dictionary:
	var node: Dictionary = active_nodes[node_id]
	var type: String = node["type"]
	var def: Dictionary = NODE_TYPES[type]

	var loot: Array = []
	var main_amount := randi_range(def["yield_min"], def["yield_max"])
	loot.append({"id": StringName(def["item_id"]), "amount": main_amount})

	for rare_id in def.get("rare_table", {}):
		if randf() < def["rare_table"][rare_id]:
			loot.append({"id": StringName(rare_id), "amount": 1})
			EventBus.rare_item_found.emit(StringName(rare_id), &"rare")

	for entry in loot:
		EconomyManager.add_item(entry["id"], entry["amount"])

	node["depleted"] = true
	EventBus.resource_node_depleted.emit(node_id, loot)
	EventBus.notification_posted.emit(
		tr("NOTIF_ITEM_GAINED_TITLE"),
		"%s x%d" % [tr("ITEM_%s" % str(def["item_id"]).to_upper()), main_amount],
		"loot"
	)
	return {"loot": loot, "depleted": true}


func _set_color(mesh: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.r > 0.7 and color.b > 0.5:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.5
	mesh.material_override = mat


func _on_day_started(day: int, _season: StringName) -> void:
	# Respawn some nodes periodically
	if day % 3 == 0:
		for i in 5:
			_spawn_random_node()


func get_node_info(node_id: StringName) -> Dictionary:
	return active_nodes.get(node_id, {})
