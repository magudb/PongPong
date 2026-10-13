extends Node2D
## Standalone playable demonstration of the 12 animated 2D characters.
## The original 3D game has NOT been automatically ported to 2D.

const NPC_SCENE: PackedScene = preload("res://scenes/isometric/npc_2d.tscn")
const IDS: Array[String] = [
	"bat", "cat", "bear", "rabbit", "fairy", "monkey", "capybara",
	"fox", "raccoon", "penguin", "hedgehog", "frog"
]

@onready var actors: Node2D = $World/Actors
@onready var player: IsoPlayerController2D = $World/Actors/Player
@onready var name_label: Label = $HUD/Panel/Margin/VBox/CharacterName


func _ready() -> void:
	player.character_changed.connect(_on_character_changed)
	_on_character_changed(player.visual.character_id)
	var other_ids := IDS.duplicate()
	other_ids.erase(player.visual.character_id)
	for index in range(other_ids.size()):
		var actor := NPC_SCENE.instantiate() as IsoWanderer2D
		actor.character_id = other_ids[index]
		actor.roam_radius = 50.0 + float(index % 3) * 18.0
		actor.pace = 25.0 + float(index % 4) * 8.0
		# Distribute characters on three staggered ground-depth rows.
		var column := index % 6
		var row := index / 6
		actor.position = Vector2((float(column) - 2.5) * 220.0, (float(row) - 0.5) * 225.0)
		actors.add_child(actor)


func _on_character_changed(id: String) -> void:
	name_label.text = "Playing as: %s  (%d / 12)" % [id.capitalize(), IDS.find(id) + 1]
