extends Node
## NON-headless screenshot driver (P04). Plays a short scripted session through the REAL world scene and saves PNGs.
##   tests/shot_world.tscn, run through impl/tools/windowed.sh (one window at a time), always with --quit-after:
##   godot --path . --resolution 1280x720 res://tests/shot_world.tscn --quit-after 3600 -- --out=DIR [--character=animal|fairy|hobbit|ghost] [--part=fixtures|cast|rim|farm|hyggebyen|forest]
## Parts:
##   fixtures    the iso fixture at noon / dusk / night / zoomed out / grown platform, then the ortho fixture (real tiles and props
##               appear as soon as assets/iso_tiles and assets/iso_props carry them: nothing here names an asset)
##   cast        the pack characters in a row on the iso fixture at game zoom 0.4
##   rim         a platform with ponds ON ITS RIM (south-west and south-east edge) and one inside: the bark skirts run under the rim water
##               (R.10, one skirt per platform-edge cell), no gap in the cliff, no water sheet floating over the sky
##   farm | hyggebyen | forest   the real maps when data/maps/<id>.map exists (skovkant for forest), else a note and no picture
## Every picture is also a pixel check target of tests/sections/area.gd run_windowed().
var out_dir := ""
var character := 0          # GameManager.CharacterType: 0 animal 1 fairy 2 hobbit 3 ghost
var part := "fixtures"
var world: Node2D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--character="):
			character = {"animal": 0, "fairy": 1, "hobbit": 2, "ghost": 3}.get(a.get_slice("=", 1), 0)
		elif a.begins_with("--part="):
			part = a.get_slice("=", 1)
	_run.call_deferred()


func shot(shot_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if out_dir != "":
		img.save_png("%s/%s.png" % [out_dir, shot_name])
	print("shot ", shot_name, " ", img.get_size())


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	GameManager.start_new_game("Tester", character, "Testgaarden")
	world = (load("res://scenes/main/world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(1.0)
	match part:
		"fixtures":
			await _fixtures()
		"cast":
			await _cast()
		"rim":
			await _rim()
		"farm", "hyggebyen":
			await _real_map(StringName(part))
		"forest":
			await _real_map(&"skovkant")
	print("missing art: ", ArtCatalog.missing())
	get_tree().quit()


func _set_hour(h: float) -> void:
	world.day_night.override_hour = h
	world.day_night.snap()
	world.area.set_night_factor(world.day_night.glow_factor)


func _go(id: StringName, spawn: StringName = &"default") -> void:
	world._enter(id, spawn)
	await wait(0.6)


func _fixtures() -> void:
	await _go(&"_fixture_iso")
	_set_hour(11.0)
	await wait(0.3)
	await shot("fixture_iso_noon")
	# tilled and watered soil swaps (what FarmGrid will do) show the real soil tiles
	var a: IsoArea = world.area
	for c in [Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4), Vector2i(7, 5), Vector2i(8, 5)]:
		a.set_terrain(c, &"soil_tilled")
	a.set_terrain(Vector2i(9, 5), &"soil_watered")
	world.player.global_position = a.cell_to_global(Vector2i(6, 6))
	world.player.camera.reset_smoothing()
	await wait(0.5)
	await shot("fixture_iso_field")
	_set_hour(18.8)
	await wait(0.6)
	await shot("fixture_iso_dusk")
	_set_hour(23.0)
	await wait(0.6)
	await shot("fixture_iso_night")
	_set_hour(11.0)
	world.player.camera.zoom = Vector2(0.3, 0.3)
	await wait(0.5)
	await shot("fixture_iso_zoomout")
	world.player.camera.zoom = Vector2(0.4, 0.4)
	a.set_growth_stage(2)
	world.player.global_position = a.cell_to_global(Vector2i(6, 2))
	world.player.camera.reset_smoothing()
	await wait(0.5)
	await shot("fixture_iso_grown")
	a.set_growth_stage(0)
	TimeManager.set_weather(&"regn")
	await wait(1.2)
	await shot("fixture_iso_rain")
	TimeManager.set_weather(&"klart")
	await _go(&"_fixture_ortho")
	await wait(0.6)
	await shot("fixture_ortho")
	world.player.global_position = world.area.cell_to_global(Vector2i(8, 4))
	world.player.camera.reset_smoothing()
	await wait(0.5)
	await shot("fixture_ortho_bog")


const CAST_MAP := "@id _shot_cast\n@projection iso\n@ambient farm\n@theme farm\n@zone farm\n@ground\n################\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n#..............#\n################\n@objects\n................\n................\n................\n................\n................\n................\n................\n........@.......\n................\n................\n................\n................\n................\n................\n................\n................\n"


func _cast() -> void:
	WorldRoot2D.register_map(&"_shot_cast", AreaMap.parse_text(CAST_MAP))
	await _go(&"_shot_cast")
	_set_hour(11.0)
	var a: IsoArea = world.area
	var ids: Array[String] = ["bat", "cat", "bear", "rabbit", "fairy", "monkey", "capybara", "fox", "raccoon", "penguin", "hedgehog", "frog"]
	# a diagonal row along the screen's east direction: cell step (+1, -1) is 128 ground px to the right
	for i in ids.size():
		var v: IsoChibiSprite2D = IsoChibiSprite2D.create(ids[i])
		a.objects.add_child(v)
		v.position = a.to_local(a.cell_to_global(Vector2i(2 + i, 13 - i)))
		v.set_direction_index(7)
	world.player.global_position = a.cell_to_global(Vector2i(8, 7))
	world.player.camera.reset_smoothing()
	await wait(0.8)
	await shot("cast_on_open_platform")


const RIM_MAP := "@id _shot_rim\n@projection iso\n@ambient farm\n@theme farm\n@zone farm\n@ground\n###############\n#.............#\n#.............#\n#............~#\n#............~#\n#............~#\n#.............#\n#......~~.....#\n#......~~.....#\n#.............#\n#.............#\n#.............#\n#..~~~~.......#\n#..~~~~.......#\n###############\n@objects\n...............\n...............\n...............\n.......@.......\n...............\n...............\n...............\n...............\n...............\n...............\n...............\n...............\n...............\n...............\n...............\n"


func _rim() -> void:
	WorldRoot2D.register_map(&"_shot_rim", AreaMap.parse_text(RIM_MAP))
	await _go(&"_shot_rim")
	_set_hour(11.0)
	var a: IsoArea = world.area
	world.player.global_position = a.cell_to_global(Vector2i(8, 11))
	world.player.camera.reset_smoothing()
	await wait(0.7)
	await shot("rim_pond_zoom40")
	world.player.camera.zoom = Vector2(0.7, 0.7)
	world.player.global_position = a.cell_to_global(Vector2i(5, 12))
	world.player.camera.reset_smoothing()
	await wait(0.7)
	await shot("rim_pond_sw_zoom70")
	world.player.global_position = a.cell_to_global(Vector2i(13, 4))
	world.player.camera.reset_smoothing()
	await wait(0.7)
	await shot("rim_pond_se_zoom70")
	world.player.camera.zoom = Vector2(0.4, 0.4)


func _real_map(id: StringName) -> void:
	if not WorldRoot2D.has_area(id):
		print("NOTE: data/maps/%s.map does not exist yet (P11 / P19): no picture" % id)
		return
	await _go(id)
	_set_hour(11.0)
	await wait(0.5)
	await shot("%s_noon" % id)
	_set_hour(23.0)
	await wait(0.6)
	await shot("%s_night" % id)
