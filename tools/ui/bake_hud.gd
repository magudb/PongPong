extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	await process_frame
	var worker: Node = load("res://tools/ui/hud_scenes.gd").new()
	root.add_child(worker)
	worker.call("run")
