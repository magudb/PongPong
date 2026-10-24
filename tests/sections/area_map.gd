extends RefCounted
const SECTION := "area_map"
const TIMEOUT_S := 180.0
const Snapshot := preload("res://scripts/ui/maps/area_map_snapshot.gd")

func run(t) -> void:
	var project: Dictionary = t.run_godot_script("res://tests/tools/check_project.gd")
	t.check("project_input_contract", project.code == 0, project.output if project.code != 0 else "M extends the input contract without a binding collision")
	t.autoload("EventBus").new_game_started.connect(func(): t.autoload("GameManager").set_flag(GameManager.FLAG_INTRO_PENDING, false), CONNECT_ONE_SHOT)
	await t.start_world()
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
	t.autoload("GameManager").hour = 12
	var world: WorldRoot2D = t.world()
	var map: TTScreen = world.game_ui.get_screen(&"map_ui")
	t.check("map_loaded", map != null)
	if map == null: return
	for id in [&"farm", &"hyggebyen", &"traetoppen", &"home", &"int_bageriet", &"greenhouse", &"moerkeskoven"]:
		await world.travel(id, &"default")
		await t.frames(3)
		t.tap_key(KEY_M)
		await t.frames(3)
		t.check(str(id) + "_opens_and_pauses", map.is_open() and t.tree.paused and t.autoload("GameManager").top_modal() == &"map")
		var snapshot: Dictionary = map.view.snapshot
		t.check(str(id) + "_has_live_floor", snapshot.get("area_id") == id and not snapshot.get("surfaces", []).is_empty())
		t.check(str(id) + "_player_position", snapshot.get("player") == world.player.global_position)
		t.check(str(id) + "_focus", map.get_viewport().gui_get_focus_owner() == map._initial_focus())
		t.check(str(id) + "_destinations", not snapshot.get("places", []).is_empty())
		if id == &"traetoppen":
			t.check("city_bridges_and_stairs", snapshot.surfaces.size() >= 17 and snapshot.paths.size() >= 1 and snapshot.places.any(func(place): return place.label == "ZONE_FOREST_EDGE"))
		if id == &"farm":
			var known: Array = snapshot.places.map(func(place): return place.label)
			t.check("farm_exits", "ZONE_TRAETOPPEN" in known and "HOME_WORLD_TITLE" in known)
			var translated: String = map.title.text
			t.autoload("LocalizationManager").set_locale("en")
			await t.frames(2)
			t.check("english_map", map.title.text == "Map" and map.title.text != translated)
			t.autoload("LocalizationManager").set_locale("da")
			await t.frames(2)
		t.tap_key(KEY_M if id == &"farm" else KEY_ESCAPE)
		await t.frames(2)
		t.check(str(id) + "_closes_and_resumes", not map.is_open() and not t.tree.paused and map.view.snapshot.is_empty())
	for flag in ["traveling", "sleeping"]:
		world.set(flag, true)
		t.tap_key(KEY_M)
		await t.frames(2)
		t.check("refuses_" + flag, not map.is_open())
		world.set(flag, false)
	t.tap_key(KEY_I)
	await t.frames(2)
	t.tap_key(KEY_M)
	await t.frames(2)
	t.check("inventory_keeps_modal", not map.is_open() and world.game_ui.get_screen(&"inventory_ui").is_open())
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	var pause: TTScreen = world.game_ui.get_screen(&"pause_menu")
	var row := pause.get_node("%MapButton") as Button
	row.grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	t.check("pause_transfers_to_map", map.is_open() and not pause.is_open() and t.autoload("GameManager").modal_stack() == [&"map"])
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_B
	event.pressed = true
	Input.parse_input_event(event)
	await t.frames(2)
	t.check("pad_closes_map", not map.is_open() and not t.tree.paused)
	await _fog(t, world)
	var floors := DungeonFloors.inst()
	floors.enter(1)
	await t.until(func(): return world.area.map.id == &"moerkeskoven_f1" and not world.traveling, 10.0)
	t.tap_key(KEY_M)
	await t.frames(3)
	var fog: Minimap2D = world.game_ui.get_screen(&"forest_hud").minimap
	t.check("dungeon_map_uses_exploration", map.is_open() and map.legend.text.contains(TranslationServer.translate("MAP_EXPLORED")) and not map.view.snapshot.surfaces.is_empty() and map.view.snapshot.surfaces.size() < world.area.ground.get_used_cells().size())
	t.check("dungeon_markers_obey_fog", map.view.snapshot.places.all(func(place): return fog.is_seen(world.area.global_to_cell(place.position))))
	t.autoload("GameManager").pop_all_modals()
	await t.frames(2)
	t.check("forced_close_releases_map", not map.is_open() and map.view.snapshot.is_empty())
	await UiAudit.audit_screen(t, "area_map")

func _fog(t, world: WorldRoot2D) -> void:
	# The enlarged dungeon map must obey the same exploration state as the minimap.
	var fog := Minimap2D.new()
	t.root.add_child(fog)
	fog.hide()
	fog.set_area(world.area)
	fog.fog.clear()
	var hidden := Snapshot.capture(world.area, world.player, fog)
	t.check("unexplored_ground_hidden", hidden.surfaces.is_empty() and hidden.places.is_empty())
	fog.fully_revealed = true
	var revealed := Snapshot.capture(world.area, world.player, fog)
	t.check("revealed_ground_visible", not revealed.surfaces.is_empty() and not revealed.places.is_empty())
	fog.queue_free()

func run_windowed(t) -> void:
	await run(t)
	t.autoload("EventBus").new_game_started.connect(func(): t.autoload("GameManager").set_flag(GameManager.FLAG_INTRO_PENDING, false), CONNECT_ONE_SHOT)
	await t.start_world()
	t.autoload("GameManager").hour = 12
	var world: WorldRoot2D = t.world()
	var map: TTScreen = world.game_ui.get_screen(&"map_ui")
	for id in [&"farm", &"hyggebyen", &"traetoppen", &"home", &"int_bageriet", &"greenhouse"]:
		await world.travel(id, &"default")
		await t.frames(3)
		map.open()
		await t.frames(3)
		for locale in ["da", "en"]:
			t.autoload("LocalizationManager").set_locale(locale)
			await t.frames(3)
			t.check(str(id) + "_" + locale + "_canvas_fits", map.get_global_rect().encloses(map.view.get_global_rect()) and map.view.size.x > 500 and map.view.size.y > 300)
			await t.capture(str(id) + "_" + locale)
		map.close()
	t.autoload("LocalizationManager").set_locale("da")
