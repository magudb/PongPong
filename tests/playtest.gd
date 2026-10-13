extends SceneTree
## Automated playthrough driver. Plays the real game flow and fails on any engine/script error.
##
## Run (headless, errors only):
##   godot --headless --path . -s res://tests/playtest.gd -- --character=fairy
## Run with real rendering + frame capture (opens a window):
##   godot --path . --write-movie /tmp/frames/f.png --fixed-fps 10 -s res://tests/playtest.gd -- --character=animal
##
## Options (after `--`):
##   --character=animal|fairy|hobbit   which hero to pick on the character screen (default animal)
##   --scenario=flow|<name>            which scenario to run (default flow); see SCENARIOS
##   --play-seconds=N                  how long to let the world run after spawning (default 3)
##
## Autoloads are NOT visible to this script at compile time (it compiles before they exist),
## so reach them via _autoload("Name"). Scenes/scripts loaded later compile normally.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var msg := "%s:%d in %s(): %s %s" % [file, line, function, code, rationale]
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings.append(msg)
		else:
			errors.append(msg)


const SCENARIOS := ["flow"]

var _catcher := ErrorCatcher.new()
var _failures: Array[String] = []
var _character := "animal"
var _scenario := "flow"
var _play_seconds := 3.0
var _player: Node = null


func _initialize() -> void:
	OS.add_logger(_catcher)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--character="):
			_character = arg.get_slice("=", 1)
		elif arg.begins_with("--scenario="):
			_scenario = arg.get_slice("=", 1)
		elif arg.begins_with("--play-seconds="):
			_play_seconds = float(arg.get_slice("=", 1))
	_autoload("EventBus").player_spawned.connect(func(p): _player = p)
	_run.call_deferred()


func _run() -> void:
	print("PLAYTEST start scenario=%s character=%s" % [_scenario, _character])
	match _scenario:
		"flow":
			await _scenario_flow()
		_:
			_fail("unknown scenario '%s' (known: %s)" % [_scenario, SCENARIOS])
	_finish()


# ---------------------------------------------------------------- scenarios

func _scenario_flow() -> void:
	# 1. Main menu
	change_scene_to_file("res://scenes/main/main_menu.tscn")
	await _frames(5)
	_expect(current_scene != null and current_scene.name == "MainMenu", "main menu loaded (got %s)" % _scene_name())
	_press("%NewGameButton")
	await _frames(5)

	# 2. Character select
	_expect(_scene_name() == "CharacterSelect", "character select opened (got %s)" % _scene_name())
	if _scene_name() != "CharacterSelect":
		return
	_set_text("%NameInput", "Tester")
	_set_text("%FarmNameInput", "Testgaarden")
	match _character:
		"fairy": _press("%FairyButton")
		"hobbit": _press("%HobbitButton")
		_: _press("%AnimalButton")
	await _frames(2)
	_press("%ConfirmButton")
	await _frames(10)

	# 3. World
	var gm := _autoload("GameManager")
	_expect(_scene_name() == "World", "world loaded (got %s)" % _scene_name())
	_expect(gm.player_name == "Tester", "player name stored (got '%s')" % gm.player_name)
	_expect(gm.farm_name == "Testgaarden", "farm name stored (got '%s')" % gm.farm_name)
	_expect(gm.current_phase == gm.GamePhase.PLAYING, "phase is PLAYING")
	_expect(_player != null and is_instance_valid(_player), "player spawned")
	if _player == null:
		return
	await _frames(30)
	_expect(_player.is_on_floor(), "player settled on the ground")

	# 4. Movement
	var start: Vector3 = _player.global_position
	Input.action_press("move_forward")
	await _seconds(1.0)
	Input.action_release("move_forward")
	var moved := start.distance_to(_player.global_position)
	_expect(moved > 1.0, "player moves with input (moved %.2f m)" % moved)

	# 5. Let the world tick (time, NPCs, animals, quests)
	await _seconds(_play_seconds)

	# 6. Pause / resume
	_tap("pause")
	await _frames(5)
	_expect(gm.current_phase == gm.GamePhase.PAUSED, "pause key pauses")
	_tap("pause")
	await _frames(5)
	_expect(gm.current_phase == gm.GamePhase.PLAYING, "pause key resumes")

	# 7. Panels
	_tap("inventory")
	await _frames(5)
	_tap("journal")
	await _frames(5)


# ---------------------------------------------------------------- helpers

func _autoload(autoload_name: String) -> Node:
	return root.get_node(autoload_name)


func _scene_name() -> String:
	return current_scene.name if current_scene else "<none>"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _press(unique_path: String) -> void:
	var node := current_scene.get_node_or_null(unique_path) if current_scene else null
	if node is BaseButton:
		node.emit_signal("pressed")
	else:
		_fail("button %s not found in %s" % [unique_path, _scene_name()])


func _set_text(unique_path: String, text: String) -> void:
	var node := current_scene.get_node_or_null(unique_path) if current_scene else null
	if node is LineEdit:
		node.text = text
	else:
		_fail("line edit %s not found in %s" % [unique_path, _scene_name()])


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  ok    ", label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("  FAIL  ", label)


func _finish() -> void:
	for e in _catcher.errors:
		print("  ENGINE ERROR: ", e)
	for w in _catcher.warnings:
		print("  engine warning: ", w)
	var bad := _failures.size() + _catcher.errors.size()
	if bad == 0:
		print("PLAYTEST PASS (%d warnings)" % _catcher.warnings.size())
	else:
		print("PLAYTEST FAIL: %d check failures, %d engine errors" % [_failures.size(), _catcher.errors.size()])
	quit(0 if bad == 0 else 1)
