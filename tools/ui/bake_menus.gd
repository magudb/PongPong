extends SceneTree
## Load the scene compiler after the autoloads, as with the town route baker.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	await process_frame
	var worker: Node = load("res://tools/ui/menu_scenes.gd").new()
	root.add_child(worker)
	worker.call("run")
