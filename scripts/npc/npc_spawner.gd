extends Node3D
## Spawns NPCs with NavigationAgent3D and registers them with the navigation map.

@export var npc_scene: PackedScene

const NPC_DEFS := [
	{
		"id": &"mayor_lyra",
		"name_key": "NPC_MAYOR_LYRA",
		"dialogue_id": &"mayor_lyra",
		"position": Vector3(52, 0, 2),
		"home": Vector3(52, 0, 2),
		"work": Vector3(50, 0, 0),
		"quests": [&"intro_lottery"],
	},
	{
		"id": &"baker_maja",
		"name_key": "NPC_BAKER_MAJA",
		"dialogue_id": &"baker_maja",
		"shop_id": &"bakery",
		"position": Vector3(55, 0, -3),
		"home": Vector3(55, 0, -3),
		"work": Vector3(55, 0, -3),
		"market": Vector3(50, 0, 2),
		"quests": [&"fix_roof", &"cookie_delivery", &"birthday_cake"],
	},
	{
		"id": &"fairy_lily",
		"name_key": "NPC_FAIRY_LILY",
		"dialogue_id": &"fairy_lily",
		"position": Vector3(48, 0, 5),
		"home": Vector3(48, 0, 5),
		"work": Vector3(48, 0, 5),
		"quests": [&"lost_cat", &"flower_necklace"],
	},
	{
		"id": &"smith_thorin",
		"name_key": "NPC_SMITH_THORIN",
		"dialogue_id": &"smith_thorin",
		"shop_id": &"smithy",
		"position": Vector3(58, 0, 0),
		"home": Vector3(58, 0, 0),
		"work": Vector3(58, 0, 0),
		"quests": [&"dark_forest_mining", &"sword_upgrade"],
	},
	{
		"id": &"merchant_pip",
		"name_key": "NPC_MERCHANT_PIP",
		"dialogue_id": &"merchant_pip",
		"shop_id": &"general_store",
		"position": Vector3(50, 0, -5),
		"home": Vector3(50, 0, -5),
		"work": Vector3(50, 0, -5),
		"market": Vector3(52, 0, 2),
		"quests": [&"supply_run"],
	},
	{
		"id": &"fairy_wizard",
		"name_key": "NPC_FAIRY_WIZARD",
		"dialogue_id": &"fairy_wizard",
		"shop_id": &"magic_store",
		"position": Vector3(54, 0, 4),
		"home": Vector3(54, 0, 4),
		"work": Vector3(54, 0, 4),
		"quests": [],
	},
	{
		"id": &"farmer_rosa",
		"name_key": "NPC_FARMER_ROSA",
		"dialogue_id": &"farmer_rosa",
		"shop_id": &"animal_store",
		"position": Vector3(47, 0, -3),
		"home": Vector3(47, 0, -3),
		"work": Vector3(47, 0, -3),
		"market": Vector3(50, 0, 2),
		"quests": [],
	},
	{
		"id": &"guard_oak",
		"name_key": "NPC_GUARD_OAK",
		"dialogue_id": &"guard_oak",
		"position": Vector3(45, 0, 0),
		"home": Vector3(45, 0, 0),
		"work": Vector3(45, 0, 0),
		"quests": [&"forest_patrol"],
	},
]


func _ready() -> void:
	_spawn_npcs()


func _spawn_npcs() -> void:
	for def in NPC_DEFS:
		var npc: CharacterBody3D
		if npc_scene:
			npc = npc_scene.instantiate()
		else:
			npc = _create_npc_agent()

		npc.position = def["position"]
		npc.npc_id = def["id"]
		npc.display_name_key = def["name_key"]
		npc.dialogue_id = def["dialogue_id"]
		npc.shop_id = def.get("shop_id", &"")
		npc.offers_quests = def.get("quests", [])
		npc.home_position = def.get("home", def["position"])
		npc.work_position = def.get("work", def["position"])
		npc.market_position = def.get("market", Vector3.ZERO)
		add_child(npc)


func _create_npc_agent() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.set_script(load("res://scripts/npc/npc_agent.gd"))

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.4
	shape.radius = 0.35
	collision.shape = shape
	collision.position.y = 0.7
	body.add_child(collision)

	var visual := Node3D.new()
	visual.name = "VisualRoot"
	body.add_child(visual)

	var label := Label3D.new()
	label.name = "NameLabel"
	label.position.y = 1.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	body.add_child(label)

	var nav := NavigationAgent3D.new()
	nav.name = "NavigationAgent3D"
	body.add_child(nav)

	return body
