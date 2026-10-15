extends Node
## WINDOWED screenshot driver of the treetop farm (package N01). One window, <= 2 minutes, always with --quit-after, run through
## impl/tools/windowed.sh (one window at a time on the user's screen):
##   godot --path <clone> --resolution 1280x720 res://tools/farm/farm_shot.tscn --quit-after 5000 -- --out=DIR [--part=all|main|tiers|night|tour|expansion|plain] [--character=animal|fairy|hobbit]
## Parts (the shot names are the ones of the order and of design3/farm/shots):
##   main       farm_t01_morning_start (zoom 0.4 at the default spawn), farm_t01_zoom03_field, farm_t01_zoom02_overview
##   tiers      farm_t05_stage1 (tier 5 on the first grown row), farm_t10_stage3_zoom03 (the castle on the full 9 x 6 deck), farm_t10_door
##   night      farm_t03_dusk, farm_t03_night, farm_t03_rain
##   tour       farm_bridge, farm_orchard_forest_sign, farm_animal_yard
##   expansion  farm_e1_locked, farm_e1_unlocked_tilled
##   plain      farm_plain_noon, farm_plain_night: the farm exactly as the game builds it TODAY (no stand-ins at all)
##   perf       no pictures: draw calls, process ms and texture memory of tier 1 / tier 10 at zoom 0.4 / 0.3 / 0.2 (printed as PERF lines)
## Everything except `plain` stands in for the handlers other packages own (house, tent, mailbox, shed, bin, the rope ring of the locked
## expansion, the untilled field look) through tools/farm/farm_standins.gd: placeholders where the art is not baked yet (N03 / P22).
const Standins := preload("res://tools/farm/farm_standins.gd")
const ROWS: Array[int] = [0, 0, 0, 0, 1, 1, 1, 2, 2, 3]

var out_dir: String = ""
var part: String = "all"
var character: int = 0
var world: WorldRoot2D
var yard: Dictionary = {}
var door: Vector2i = Vector2i.ZERO
var house: Node2D = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--part="):
			part = a.get_slice("=", 1)
		elif a.begins_with("--character="):
			character = {"animal": 0, "fairy": 1, "hobbit": 2}.get(a.get_slice("=", 1), 0)
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


func _hour(h: float) -> void:
	world.day_night.override_hour = h
	world.day_night.snap()
	world.area.set_night_factor(world.day_night.glow_factor)


func _at(c: Vector2i, zoom: float) -> void:
	world.player.global_position = world.area.cell_to_global(c)
	world.player.camera.zoom = Vector2(zoom, zoom)
	world.player.camera.reset_smoothing()


## A fresh farm with the stand-ins: the house of `tier` on the deck of its growth rows, the yard props, the field look.
func _tier(tier: int) -> void:
	world.rebuild_current_area()
	await wait(0.4)
	var a: IsoArea = world.area
	yard = Standins.place_yard(a)
	house = Standins.place_home(a, tier, door, true, false)
	a.set_growth_stage(ROWS[tier - 1])
	Standins.apply_field_look(a)
	_hour(11.0)


func _run() -> void:
	GameManager.start_new_game("Tester", character, "Min Traekronsgaard")
	world = (load("res://scenes/main/world.tscn") as PackedScene).instantiate() as WorldRoot2D
	add_child(world)
	await wait(1.0)
	world._enter(&"farm", &"default")
	await wait(0.6)
	var a: IsoArea = world.area
	door = a.find_markers("home")[0]["cell"]
	var spawn_cell: Vector2i = a.global_to_cell(a.spawns["default"])
	var all: bool = part == "all"
	if part == "plain":
		_hour(11.0)
		_at(spawn_cell, 0.4)
		await wait(0.7)
		await shot("farm_plain_noon")
		_hour(23.0)
		await wait(0.7)
		await shot("farm_plain_night")
	if all or part == "main":
		await _tier(1)
		a = world.area
		_at(spawn_cell, 0.4)
		_hour(10.0)
		await wait(0.7)
		await shot("farm_t01_morning_start")
		_at(spawn_cell + Vector2i(-8, 14), 0.3)
		await wait(0.6)
		await shot("farm_t01_zoom03_field")
		_at(spawn_cell + Vector2i(-6, 6), 0.2)
		await wait(0.6)
		await shot("farm_t01_zoom02_overview")
	if all or part == "tiers":
		await _tier(5)
		a = world.area
		_at(spawn_cell + Vector2i(0, 4), 0.33)
		await wait(0.6)
		await shot("farm_t05_stage1")
		await _tier(10)
		a = world.area
		_at(spawn_cell + Vector2i(0, 4), 0.3)
		await wait(0.6)
		await shot("farm_t10_stage3_zoom03")
		_at(door + Vector2i(0, -3), 0.33)
		await wait(0.6)
		await shot("farm_t10_door")
	if all or part == "night":
		await _tier(3)
		a = world.area
		house.queue_free()
		house = Standins.place_home(a, 3, door, true, true)
		_at(spawn_cell, 0.4)
		_hour(19.0)
		await wait(0.8)
		await shot("farm_t03_dusk")
		_hour(23.0)
		await wait(0.8)
		await shot("farm_t03_night")
		TimeManager.set_weather(&"regn")
		_hour(11.0)
		await wait(1.4)
		await shot("farm_t03_rain")
		TimeManager.set_weather(&"klart")
	if all or part == "tour":
		await _tier(2)
		a = world.area
		var warp_cell: Vector2i = a.find_markers("warp")[0]["cell"]
		_at(warp_cell + Vector2i(0, -6), 0.4)
		await wait(0.6)
		await shot("farm_bridge")
		var sk: Vector2i = Vector2i.ZERO
		for rec in a.find_markers("sign"):
			if str(rec["params"].get("text", "")) == "SIGN_FARM_FOREST":
				sk = rec["cell"]
		_at(sk + Vector2i(5, 3), 0.4)
		await wait(0.6)
		await shot("farm_orchard_forest_sign")
		var an: Vector2i = a.find_markers("animal_yard")[0]["cell"]
		_at(an, 0.4)
		await wait(0.6)
		await shot("farm_animal_yard")
	if all or part == "expansion":
		await _tier(1)
		a = world.area
		_at(spawn_cell + Vector2i(2, 9), 0.4)
		await wait(0.6)
		await shot("farm_e1_locked")
		var cells: Array = (yard.get("zones", {}) as Dictionary).get("east", [])
		Standins.unlock(a, cells, (yard.get("ropes", {}) as Dictionary).get("east", []))
		# till a few cells the way FarmGrid will (soil swap through the public API)
		var k: int = 0
		for c in cells:
			if k % 3 != 2 and k < 28:
				a.set_terrain(c, &"soil_tilled")
			k += 1
		await wait(0.6)
		await shot("farm_e1_unlocked_tilled")
	if part == "perf":
		for tier in [1, 10]:
			await _tier(tier)
			a = world.area
			for z in [0.4, 0.3, 0.2]:
				_at(spawn_cell + Vector2i(0, 4), z)
				for hour in [11.0, 22.0]:
					_hour(hour)
					await wait(1.2)
					var ms_sum: float = 0.0
					var dc_max: int = 0
					for i in 120:
						await get_tree().process_frame
						ms_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
						dc_max = maxi(dc_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
					print("PERF tier %d zoom %.1f hour %.0f: process %.2f ms, draw calls max %d, texture mem %.1f MB, nodes %d" % [tier, z, hour, ms_sum / 120.0, dc_max,
						Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	print("missing art: ", ArtCatalog.missing())
	get_tree().quit()
