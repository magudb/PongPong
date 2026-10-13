extends SceneTree
## Runtime/import acceptance checks. Run after a clean --headless --editor --import.
## The source project's autoloads are accessed by path, not compile-time identifiers.

const Catalog = preload("res://scripts/characters/character_catalog.gd")
const REQUIRED := [&"idle", &"walk", &"run", &"jump", &"fall", &"land", &"celebrate", &"talk", &"interact", &"hit", &"sleep"]
var failures: Array[String] = []

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s: %s %s" % [file, line, function, code, rationale])

var catcher := ErrorCatcher.new()

func _initialize() -> void:
	OS.add_logger(catcher)
	_run.call_deferred()

func _run() -> void:
	for model in Catalog.CHARACTERS:
		var path := "res://scenes/characters/%s.tscn" % model
		var packed := load(path) as PackedScene
		check(packed != null, "load " + String(model))
		if packed == null:
			continue
		var visual := packed.instantiate() as Node3D
		root.add_child(visual)
		await process_frame
		var skeletons: Array[Node] = visual.find_children("*", "Skeleton3D", true, false)
		check(not skeletons.is_empty(), "%s imports a Skeleton3D" % model)
		if not skeletons.is_empty():
			check((skeletons[0] as Skeleton3D).get_bone_count() >= 18, "%s has a full rig" % model)
		var meshes: Array[Node] = visual.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), "%s imports a mesh" % model)
		for node in meshes:
			var mesh := node as MeshInstance3D
			check(mesh.skin != null, "%s mesh has a skin" % model)
			if mesh.mesh == null:
				check(false, "%s mesh resource is null" % model)
				continue
			var material: Material = mesh.get_active_material(0)
			check(material is BaseMaterial3D, "%s material imports" % model)
			if material is BaseMaterial3D:
				check(material.albedo_texture != null, "%s base color texture is present" % model)
		for clip in REQUIRED:
			check(visual.has_clip(clip), "%s/%s animation imports" % [model, clip])
		if model in Catalog.FLYERS:
			for clip in [&"takeoff", &"hover", &"fly", &"flight_land", &"turn_left", &"turn_right"]:
				check(visual.has_clip(clip), "%s/%s flight animation imports" % [model, clip])
		visual.play_clip(&"walk")
		await process_frame
		visual.animation_player.advance(0.2)
		check(visual.current_clip == &"walk", "%s animation driver plays walk" % model)
		root.remove_child(visual)
		visual.free()
	await _controller_checks()
	for message in catcher.errors:
		failures.append("ENGINE: " + message)
	if failures.is_empty():
		print("CHARACTER ACCEPTANCE PASS")
	else:
		for message in failures:
			printerr("FAIL: " + message)
		printerr("CHARACTER ACCEPTANCE FAILED: %d issues" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _controller_checks() -> void:
	var manager: Node = root.get_node("GameManager")
	manager.character_skin = &"animal_fox"
	manager.change_phase(manager.GamePhase.PLAYING)
	var arena := Node3D.new()
	root.add_child(arena)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.position.y = -0.5
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	ground_shape.shape = box
	ground.add_child(ground_shape)
	arena.add_child(ground)
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var player := packed.instantiate() as CharacterBody3D
	player.position = Vector3(0, 0.15, 0)
	arena.add_child(player)
	await frames(35)
	check(player.current_skin == &"animal_fox", "selected skin is applied on spawn")
	check(player.is_on_floor(), "player settles on the ground")
	check(absf(player.position.y) < 0.03, "physical feet align with floor height")
	var origin: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(30)
	Input.action_release("move_forward")
	check(player.position.z < origin.z - 0.8, "forward input moves forward")
	check(absf(player.position.x - origin.x) < 0.15, "forward input does not orbit sideways")
	await frames(40)
	origin = player.position
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check(player.position.x > origin.x + 0.8, "right input moves right after turning")
	await frames(40)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(12)
	check(player.position.y > 0.15, "jump leaves the ground")
	await frames(80)
	check(player.is_on_floor(), "jump lands")
	check(not player.set_flying(true), "fox cannot fly")
	var bus: Node = root.get_node("EventBus")
	bus.player_character_changed.emit(&"fairy_meadow")
	await frames(3)
	check(player.set_flying(true), "fairy can enable flight")
	Input.action_press("jump")
	await frames(40)
	Input.action_release("jump")
	check(player.position.y > 0.5, "fairy ascends in flight")
	player.set_flying(false)
	await frames(100)
	check(player.is_on_floor(), "fairy lands after flight ends")
	manager.change_phase(manager.GamePhase.PAUSED)
	var paused_position: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(10)
	Input.action_release("move_forward")
	check(player.position.distance_to(paused_position) < 0.001, "pausing freezes player physics")
	manager.change_phase(manager.GamePhase.PLAYING)
	var saved: Dictionary = manager.to_dict()
	manager.character_skin = &"animal_fox"
	manager.from_dict(saved)
	check(manager.character_skin == &"fairy_meadow", "skin survives save-state serialization")
	arena.queue_free()
	await process_frame

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS ", label)
	else:
		failures.append(label)
