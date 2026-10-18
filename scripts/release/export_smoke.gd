extends Node
## Run from each real exported executable; missing raw data must fail the release build.
var failures: Array[String] = []
var tree: SceneTree

func _ready() -> void:
	tree = get_tree()
	_run.call_deferred()

func _run() -> void:
	await tree.process_frame
	if tree.current_scene != null:
		tree.current_scene.queue_free()
		tree.current_scene = null
		for frame in 2: await tree.process_frame
	var lua := tree.root.get_node("LuaRuntime")
	_check("Lua items", lua.get_all_item_ids().size() > 100)
	_check("Town data", lua.get_registry("buildings").size() >= 10)
	_check("Danish copy", TranslationServer.translate("MENU_NEW_GAME") != "MENU_NEW_GAME")
	_check("Map copy", TranslationServer.translate("MAP_TITLE") != "MAP_TITLE")
	_check("Updater helpers", FileAccess.file_exists("res://scripts/release/install_windows.ps1") and FileAccess.file_exists("res://scripts/release/install_macos.sh"))
	_check("Raw maps", WorldRoot2D.area_ids().size() >= 10)
	_check("Characters", not CharacterCatalog.resolved_visual_for_skin("animal_fox").is_empty())
	var game := tree.root.get_node("GameManager")
	game.start_new_game("Release test", 0, "Smoke farm", &"animal_fox")
	game.set_flag(game.FLAG_INTRO_PENDING, false)
	game.set_flag(&"intro_done", true)
	var world: Node = load("res://scenes/main/world.tscn").instantiate()
	tree.root.add_child(world)
	tree.current_scene = world
	for frame in 120:
		if world.ready_for_play: break
		await tree.process_frame
	_check("World boots", world.area != null and world.player != null)
	_check("Map ships", world.game_ui.get_screen(&"map_ui") != null)
	await world.travel(&"traetoppen", &"default")
	_check("City runtime data", world.area.map.id == &"traetoppen" and LevelStage.of(world.area) != null)
	await world.travel(&"home", &"default")
	_check("Home runtime data", world.area.map.id == &"home" and not world.area.ground.get_used_cells().is_empty())
	game.pop_all_modals()
	world.queue_free()
	tree.current_scene = null
	for frame in 3: await tree.process_frame
	var report := {"result": "pass" if failures.is_empty() else "fail", "failures": failures, "version": ProjectSettings.get_setting("application/config/version", ""), "channel": ProjectSettings.get_setting("release/channel", "")}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.substr(9), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report))
	print("RELEASE_SMOKE ", JSON.stringify(report))
	game.quit_game(0 if failures.is_empty() else 1)

func _check(label: String, passed: bool) -> void:
	print("SMOKE ", label, ": ", passed)
	if not passed: failures.append(label)
