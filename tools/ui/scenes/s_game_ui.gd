extends RefCounted
## scenes/ui/game_ui.tscn : the root of everything the player sees in the world - ONE CanvasLayer (layer 10, PROCESS_MODE_ALWAYS)
## with the script scripts/ui/game_ui.gd. It has NO children in the scene: game_ui.gd instances the screens dynamically from
## its ordered list when their scene file exists (so the packages that own the screens can land in any order).

func build(K) -> void:
	var r = K.begin("CanvasLayer", "GameUI", "res://scripts/ui/game_ui.gd")
	r.layer = 10
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	K.save("res://scenes/ui/game_ui.tscn")
