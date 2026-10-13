extends Node3D
## Main world scene: farm, city, forest connections. Spawns player, wires systems.

@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var farm_root: Node3D = $Farm
@onready var city_root: Node3D = $City
@onready var forest_root: Node3D = $DarkForest

var player_scene := preload("res://scenes/player/player.tscn")
var npc_scene := preload("res://scenes/npc/npc.tscn")
var forest_scene := preload("res://scenes/forest/dark_forest.tscn")

# NPC id -> world position, dialogue id, quests they offer
const NPC_SPAWNS: Array[Dictionary] = [
	{"id": &"mayor_lyra", "pos": Vector3(50, 0, 2), "quests": [&"intro_lottery"]},
	{"id": &"baker_maja", "pos": Vector3(44, 0, 8), "quests": [&"fix_roof", &"cookie_delivery", &"math_bakery_counts"]},
	{"id": &"smith_thorin", "pos": Vector3(56, 0, 8), "quests": [&"dark_forest_mining", &"sword_upgrade"]},
	{"id": &"merchant_pip", "pos": Vector3(44, 0, -8), "quests": [&"supply_run", &"cookie_delivery"]},
	{"id": &"fairy_wizard", "pos": Vector3(56, 0, -8), "quests": [&"math_wizard_quiz", &"enchanted_garden"]},
	{"id": &"farmer_rosa", "pos": Vector3(58, 0, -2), "quests": [&"math_harvest_puzzle", &"animal_products", &"first_animal"]},
	{"id": &"fairy_lily", "pos": Vector3(-24, 0, 16), "quests": [&"lost_cat", &"fairy_friendship", &"flower_necklace", &"birthday_cake"]},
	{"id": &"guard_oak", "pos": Vector3(-18, 0, -4), "quests": [&"forest_patrol", &"night_flower"]},
]


func _ready() -> void:
	GameManager.change_phase(GameManager.GamePhase.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_spawn_player()
	_setup_zones()
	_spawn_npcs()
	_populate_city()
	AudioManager.play_music("forest_theme")
	EventBus.notification_posted.emit(
		tr("GAME_TITLE"),
		tr("DIALOGUE_LYRA_LOTTERY"),
		"welcome"
	)


func _spawn_player() -> void:
	var player := player_scene.instantiate()
	player.position = player_spawn.position if player_spawn else Vector3.ZERO
	add_child(player)
	EventBus.player_spawned.emit(player)


func _setup_zones() -> void:
	# Farm zone
	if farm_root:
		farm_root.add_to_group("farm_system")

	# Dark forest — instance the full scene (trees, fog, cave, grove, nodes)
	if forest_root:
		forest_root.add_to_group("dark_forest")
		var forest := forest_scene.instantiate()
		forest_root.add_child(forest)

	# Zone triggers
	_create_zone_trigger(&"farm", Vector3(0, 0, 0), Vector3(30, 10, 30))
	_create_zone_trigger(&"city", Vector3(50, 0, 0), Vector3(25, 10, 25))
	_create_zone_trigger(&"dark_forest", Vector3(-50, 0, 0), Vector3(40, 10, 40))
	_create_zone_trigger(&"mushroom_grove", Vector3(-25, 0, -30), Vector3(20, 10, 20))


func _spawn_npcs() -> void:
	for def in NPC_SPAWNS:
		var npc := npc_scene.instantiate()
		npc.npc_id = def["id"]
		npc.dialogue_id = def["id"]
		npc.display_name_key = "NPC_%s" % String(def["id"]).to_upper()
		npc.offers_quests.assign(def["quests"])
		npc.position = def["pos"]
		npc.home_position = def["pos"]
		add_child(npc)


func _populate_city() -> void:
	# Placeholder buildings — colored boxes until real assets exist.
	var buildings := [
		{"pos": Vector3(0, 1.6, 10), "size": Vector3(6, 3.2, 5), "color": Color(0.75, 0.6, 0.5)},    # bakery
		{"pos": Vector3(6, 1.9, 12), "size": Vector3(5, 3.8, 5), "color": Color(0.5, 0.55, 0.7)},    # smithy
		{"pos": Vector3(-6, 1.5, -12), "size": Vector3(5, 3.0, 5), "color": Color(0.5, 0.7, 0.55)},  # shop
		{"pos": Vector3(6, 2.2, -12), "size": Vector3(5, 4.4, 5), "color": Color(0.65, 0.5, 0.75)},  # magic store
		{"pos": Vector3(10, 1.7, -2), "size": Vector3(5, 3.4, 5), "color": Color(0.7, 0.65, 0.5)},   # animal store
	]
	for b in buildings:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = b["pos"]
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = b["size"]
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = b["color"]
		mesh.material_override = mat
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b["size"]
		col.shape = shape
		body.add_child(mesh)
		body.add_child(col)
		city_root.add_child(body)


func _create_zone_trigger(zone_id: StringName, pos: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # player
	area.position = pos

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)

	var script := load("res://scripts/world/zone_trigger.gd")
	area.set_script(script)
	area.set_meta("zone_id", zone_id)
	add_child(area)


func _on_player_spawned(_player: Node3D) -> void:
	pass
