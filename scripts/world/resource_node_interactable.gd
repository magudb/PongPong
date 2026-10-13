extends StaticBody3D
## Interactable resource node in the dark forest.

var node_id: StringName = &""
var node_type: StringName = &""


func _ready() -> void:
	node_id = get_meta("node_id", &"")
	node_type = get_meta("node_type", &"")
	collision_layer = 64
	collision_mask = 0


func get_interaction_prompt() -> String:
	return tr("UI_INTERACT_MINE") if node_type != &"mushroom_patch" else tr("UI_INTERACT_FORAGE")


func interact(player: Node3D) -> void:
	var forest := get_tree().get_first_node_in_group("dark_forest")
	if forest == null:
		return

	# Determine tool power
	var tool_power := 1
	var weapon = EconomyManager.equipment.get("weapon", &"")
	if weapon == &"iron_sword":
		tool_power = 2

	# Pickaxe power for mining
	var pickaxe = EconomyManager.equipment.get("tool_pickaxe", &"")
	if pickaxe == &"pickaxe_iron":
		tool_power = maxi(tool_power, 2)

	forest.hit_node(node_id, tool_power)
