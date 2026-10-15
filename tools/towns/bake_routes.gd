extends SceneTree
## Bootstrap without world-class references: -s compiles before autoload globals.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var script: GDScript = load("res://tools/towns/route_baker.gd")
	if script == null or not script.can_instantiate():
		quit(2)
		return
	var worker: Node = script.new()
	root.add_child(worker)
	worker.call("run")

static func input_paths() -> Array[String]:
	var script: GDScript = load("res://tools/towns/route_baker.gd")
	return script.call("input_paths")
