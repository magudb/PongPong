extends Node2D
## A stand-in for the keeper of a room (package T-towns-core): what ShopCounter's `talk` host reaches through NpcDirector.node_of in the real game (T-director builds the real Npc2D).
## interact(player) records the call; with_visual(id) gives it a body drawn by IsoChibiSprite2D (the windowed shots).

var interactions: Array = []
var visual: Node2D


func interact(player: Node) -> void:
	interactions.append(player)


func get_interaction_prompt() -> String:
	return ""


func with_visual(visual_id: String) -> void:
	visual = IsoChibiSprite2D.create(visual_id)
	add_child(visual)
