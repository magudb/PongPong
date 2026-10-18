extends SceneTree
## Run from each real exported executable; missing raw data must fail the release build.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var lua := root.get_node("LuaRuntime")
	_check("Lua items", lua.get_all_item_ids().size() > 100)
	_check("Town data", lua.get_registry("buildings").size() >= 10)
	_check("Danish copy", TranslationServer.translate("MENU_NEW_GAME") != "MENU_NEW_GAME")
	_check("Map copy", TranslationServer.translate("MAP_TITLE") != "MAP_TITLE")
	_check("Updater helpers", FileAccess.file_exists("res://scripts/release/install_windows.ps1") and FileAccess.file_exists("res://scripts/release/install_macos.sh"))
	_check("Raw maps", WorldRoot2D.area_ids().size() >= 10)
	_check("Characters", not CharacterCatalog.resolve("animal_fox").is_empty())
	var game := root.get_node("GameManager")
	root.get_node("EventBus").new_game_started.connect(func(): game.set_flag(GameManager.FLAG_INTRO_PENDING, false), CONNECT_ONE_SHOT)
	game.start_new_game("Release test", 0, "Smoke farm", &"animal_fox")
	var world: Node = load("res://scenes/main/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 12: await process_frame
	_check("World boots", world.area != null and world.player != null)
	_check("Map ships", world.game_ui.get_screen(&"map_ui") != null)
	await world.travel(&"traetoppen", &"default")
	_check("City runtime data", world.area.map.id == &"traetoppen" and LevelStage.of(world.area) != null)
	await world.travel(&"home", &"default")
	_check("Home runtime data", world.area.map.id == &"home" and not world.area.ground.get_used_cells().is_empty())
	game.pop_all_modals()
	world.queue_free()
	current_scene = null
	for frame in 3: await process_frame
	var report := {"result": "pass" if failures.is_empty() else "fail", "failures": failures, "version": ProjectSettings.get_setting("application/config/version", ""), "channel": ProjectSettings.get_setting("release/channel", "")}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.substr(9), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report))
	print("RELEASE_SMOKE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _check(label: String, passed: bool) -> void:
	if not passed: failures.append(label)
