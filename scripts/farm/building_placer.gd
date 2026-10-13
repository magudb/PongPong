extends Node3D
## Animal building placement: coop, barn, house on the farm.

@export var building_scene: PackedScene

var _placed_buildings: Array[Node3D] = []


func _ready() -> void:
	add_to_group("building_placer")
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)


func place_building(building_type: StringName, position: Vector3) -> void:
	var building := Node3D.new()
	building.position = position

	# Visual placeholder
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	match building_type:
		&"coop":
			box.size = Vector3(3, 2, 3)
		&"barn":
			box.size = Vector3(5, 3, 5)
		&"house":
			box.size = Vector3(3, 2.5, 3)
		_:
			box.size = Vector3(3, 2, 3)
	mesh.mesh = box
	mesh.position.y = box.size.y / 2

	var mat := StandardMaterial3D.new()
	match building_type:
		&"coop":
			mat.albedo_color = Color(0.85, 0.7, 0.5)
		&"barn":
			mat.albedo_color = Color(0.7, 0.35, 0.3)
		&"house":
			mat.albedo_color = Color(0.75, 0.6, 0.45)
		_:
			mat.albedo_color = Color(0.7, 0.7, 0.7)
	mesh.material_override = mat

	# Roof
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(box.size.x + 0.5, 1.0, box.size.z + 0.5)
	roof.mesh = roof_mesh
	roof.position.y = box.size.y + 0.5
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.5, 0.25, 0.2)
	roof.material_override = roof_mat

	# Collision
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	col.position.y = box.size.y / 2
	body.add_child(col)

	building.add_child(mesh)
	building.add_child(roof)
	building.add_child(body)

	# Door area for interaction
	var door_area := Area3D.new()
	door_area.collision_layer = 0
	door_area.collision_mask = 2
	var door_col := CollisionShape3D.new()
	var door_shape := BoxShape3D.new()
	door_shape.size = Vector3(1.5, 2, 1.5)
	door_col.shape = door_shape
	door_col.position = Vector3(0, 1, box.size.z / 2 + 0.5)
	door_area.add_child(door_col)
	building.add_child(door_area)

	# Sign label
	var label := Label3D.new()
	label.text = tr("BUILDING_%s" % str(building_type).to_upper())
	label.position.y = box.size.y + 1.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	building.add_child(label)

	add_child(building)
	_placed_buildings.append(building)


func _on_panel_toggled(panel: StringName, _is_open: bool) -> void:
	if panel == &"build_placed":
		# Triggered after build — find a free spot
		pass
