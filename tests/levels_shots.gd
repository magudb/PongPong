extends Node
## NON-headless screenshot driver of package V3-levels (own name: tests/shot_* belongs to P04). Builds the levelled stand-in city of
## data/traetoppen/traetoppen.json (LevelStage, flat vector art) inside the REAL world scene and takes the pictures the levels are judged by:
##   tests/levels_shots.tscn, run through impl/tools/windowed.sh (one window at a time), always with --quit-after:
##   godot --path . --resolution 1280x720 res://tests/levels_shots.tscn --quit-after 3600 -- --out=DIR [--part=all|overview|torvet|b8|ladder|overlap|ends|dusk|lift] [--character=animal|fairy|hobbit]
## Parts (every picture is at the game zoom 0.4 on the 1280 x 720 window unless it says otherwise):
##   overview   the whole composition at zoom 0.2 next to nothing else (compare with refs/miljoer_v2_render.png)
##   torvet     the Torvet at noon: fire pit, stall, huts, the main trunk, the Upper deck above, the player at the default spawn
##   b8         a magenta figure on bridge B8 in FRONT of the main trunk's base (the single-plane y-sort fails exactly here: 88 % of B8 sorts
##              behind the trunk) and the control picture with every z_index flattened; both counted by pixels
##   ladder     the player halfway up the ladder (the tween is paused on its way) and at the top
##   overlap    the Torvet and the Upper deck overlap on screen: a figure on each, the Upper deck's rim between them
##   ends       contact sheet of the six `under` bridge ends (B0 B1 B2 B3 B6 B7): a figure at the gate, one body radius before the rim
##   dusk       the Torvet at 20:30 with the lantern halos and PointLights
##   lift       the Skovlift rim of tree B with the basket and the rope
##   perf       draw calls and ms per frame at the Torvet, with groups of the scene hidden (what each part costs)
##   play       no pictures: the stand-in city stays open in the window so it can be WALKED by hand (WASD / arrows, E at the ladder foot and at the
##              Skovlift, wheel = zoom 0.2 .. 0.7). No --quit-after: close the window.
## Prints the pixel counts so a human and tests/sections/city_levels.gd (run_windowed) can check the same numbers.

const MAP := """
@id _levels_demo
@title ZONE_TRAETOPPEN
@projection iso
@ambient farm
@zone traetoppen
@flight false
@zoom 0.4
@zoom_min 0.2
@zoom_max 0.7
@builder res://scripts/world2d/levels/level_area_builder.gd
"""

var out_dir := ""
var character := 0
var part := "all"
var world: Node2D
var stage: LevelStage
var registry: LevelRegistry
var scale_k := 3.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--character="):
			character = {"animal": 0, "fairy": 1, "hobbit": 2}.get(a.get_slice("=", 1), 0)
		elif a.begins_with("--part="):
			part = a.get_slice("=", 1)
	_run.call_deferred()


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(shot_name: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if out_dir != "":
		img.save_png("%s/%s.png" % [out_dir, shot_name])
	print("shot ", shot_name, " ", img.get_size())
	return img


func _run() -> void:
	GameManager.start_new_game("Tester", character, "Testgaarden")
	world = (load("res://scenes/main/world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(1.0)
	WorldRoot2D.register_map(&"_levels_demo", AreaMap.parse_text(MAP))
	await _enter_city()
	if part == "play":
		var pl: Node2D = world.player
		pl.set_physics_process(true)
		pl.camera.position_smoothing_enabled = true
		world.day_night.override_hour = -1.0
		print("levels play: the stand-in city is open, walk with WASD / arrows, E at the ladder foot and at the Skovlift rim, wheel zooms")
		return
	var all := part == "all"
	if all or part == "overview":
		await _overview()
	if all or part == "torvet":
		await _torvet()
	if all or part == "b8":
		await _b8()
	if all or part == "ladder":
		await _ladder()
	if all or part == "overlap":
		await _overlap()
	if all or part == "ends":
		await _ends()
	if all or part == "dusk":
		await _dusk()
	if all or part == "lift":
		await _lift()
	if all or part == "perf":
		await _perf()
	print("level_at probes ok; stage build ms ", stage.build_ms)
	get_tree().quit()


func _enter_city(spawn: StringName = &"default") -> void:
	world._enter(&"_levels_demo", spawn)
	var p: Node2D = world.player
	p.set_physics_process(false)
	p.camera.position_smoothing_enabled = false
	stage = LevelStage.of(world.area)
	registry = stage.registry
	scale_k = registry.scale
	_set_hour(11.0)
	await wait(0.6)


func _set_hour(h: float) -> void:
	world.day_night.override_hour = h
	world.day_night.snap()
	world.area.set_night_factor(world.day_night.glow_factor)


## world position of a sketch point
func sk(x: float, y: float) -> Vector2:
	return Vector2(x, y) * scale_k


func _look_at(pos: Vector2, zoom: float = 0.4) -> void:
	var p: Node2D = world.player
	p.camera.zoom = Vector2.ONE * zoom
	p.global_position = pos
	p.camera.reset_smoothing()


func _put_player(pos: Vector2, zoom: float = 0.4) -> void:
	_look_at(pos, zoom)
	# the tracker derives the level on the next physics frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await wait(0.25)


func _make_actor(pos: Vector2, visual_id: String, tint: Color) -> CharacterBody2D:
	var a := CharacterBody2D.new()
	a.collision_layer = Iso.LAYER_NPC
	a.collision_mask = 0
	var v: IsoChibiSprite2D = IsoChibiSprite2D.create(visual_id)
	v.name = "Visual"
	a.add_child(v)
	world.area.objects.add_child(a)
	a.global_position = pos
	v.sprite.self_modulate = tint
	return a


## Magenta pixels (the tinted figure) in a box around a screen point.
func magenta(img: Image, centre: Vector2, half: Vector2 = Vector2(60, 100)) -> int:
	return count_magenta(img, centre, half)


static func count_magenta(img: Image, centre: Vector2, half: Vector2 = Vector2(60, 100)) -> int:
	var n := 0
	var x0 := int(centre.x - half.x)
	var y0 := int(centre.y - half.y * 1.6)
	for y in range(y0, int(centre.y + half.y * 0.2), 2):
		for x in range(x0, int(centre.x + half.x), 2):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			if c.r > c.g + 0.1 and c.b > c.g + 0.15:
				n += 1
	return n


func screen_of(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _overview() -> void:
	await _put_player(sk(900, 640), 0.2)
	await shot("levels_01_overview_zoom_0_2")


func _torvet() -> void:
	await _put_player(registry.spawns["default"], 0.4)
	await shot("levels_02_torvet_zoom_0_4")


## The y-sort proof: the figure stands on B8 at the middle of the bridge, in front of the Torvet's lower trunk base.
func _b8() -> void:
	var b8: Level = registry.get_level(&"b8")
	var pos: Vector2 = (b8.path[0] + b8.path[1]) * 0.5
	var p: Node2D = world.player
	p.visual.sprite.self_modulate = Color(1, 0, 1)
	await _put_player(pos, 0.4)
	var img: Image = await shot("levels_03_b8_in_front_of_trunk")
	var seen: int = magenta(img, screen_of(pos))
	# reference: the same figure on open Torvet floor, nothing in front of it
	var open: Vector2 = registry.spawns["default"] + Vector2(-260, 40)
	await _put_player(open, 0.4)
	var img_ref: Image = await shot("levels_03_b8_reference_open_floor")
	var ref: int = magenta(img_ref, screen_of(open))
	# control: every z_index flattened to 0, the lower trunks into the y-sorted node = the single-plane model
	var saved: Dictionary = _flatten(world.area)
	await _put_player(pos, 0.4)
	var img_flat: Image = await shot("levels_03_b8_control_single_plane")
	var flat: int = magenta(img_flat, screen_of(pos))
	_unflatten(saved)
	print("b8 magenta pixels: levelled ", seen, " reference ", ref, " single-plane control ", flat, " (levelled/reference ", "%.2f" % (float(seen) / float(maxi(ref, 1))), ", control/reference ", "%.2f" % (float(flat) / float(maxi(ref, 1))), ")")
	p.visual.sprite.self_modulate = Color.WHITE


## Every z_index of the area to 0 and the lower trunks into the y-sorted node. Returns what to undo.
func _flatten(area: IsoArea) -> Dictionary:
	return flatten_area(world, stage, registry)


static func flatten_area(world: Node2D, stage: LevelStage, registry: LevelRegistry) -> Dictionary:
	var area: IsoArea = world.area
	var scale_k: float = registry.scale
	var saved: Dictionary = {}
	var stack: Array[Node] = [stage.floors, area.objects]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is CanvasItem and (n as CanvasItem).z_index != 0:
			saved[n] = (n as CanvasItem).z_index
			(n as CanvasItem).z_index = 0
	# the single-plane model: the floors are drawn first, everything else sorts by its pivot y in ONE node (a lower trunk by its base)
	saved["floors_index"] = stage.floors.get_index()
	area.move_child(stage.floors, area.objects.get_index())
	var trunk_base: Dictionary = {}
	for rec in registry.data["trunks"]:
		trunk_base[str(rec["id"])] = (float(rec["y_bot"]) - float(rec["y_top"])) * scale_k
	for n in stage.floors.get_children():
		if str(n.name).begins_with("t_") and str(n.name).ends_with("_lower"):
			saved[n] = {"parent": stage.floors, "dy": trunk_base[str(n.name)], "z": int(saved.get(n, 0))}
			stage.floors.remove_child(n)
			area.objects.add_child(n)
			(n as Node2D).position.y += trunk_base[str(n.name)]
			for c in n.get_children():
				(c as Node2D).position.y -= trunk_base[str(n.name)]
	stage.tracker.set_physics_process(false)
	var pl: Node2D = world.player
	saved[pl] = pl.z_index
	pl.z_index = 0
	var sh: Sprite2D = ActorLevel.shadow_of(pl)
	if sh != null:
		saved[sh] = {"shadow": sh.z_index}
		sh.z_index = -5
	return saved


func _unflatten(saved: Dictionary) -> void:
	unflatten_area(world, stage, saved)


static func unflatten_area(world: Node2D, stage: LevelStage, saved: Dictionary) -> void:
	for n in saved:
		var v: Variant = saved[n]
		if n is String:
			continue
		if not is_instance_valid(n):
			continue
		if v is int:
			(n as CanvasItem).z_index = v
		elif v is Dictionary and (v as Dictionary).has("parent"):
			var dy: float = float((v as Dictionary)["dy"])
			(n as CanvasItem).z_index = int((v as Dictionary)["z"])
			(n.get_parent()).remove_child(n)
			((v as Dictionary)["parent"] as Node).add_child(n)
			(n as Node2D).position.y -= dy
			for c in n.get_children():
				(c as Node2D).position.y += dy
	world.area.move_child(stage.floors, int(saved["floors_index"]))
	stage.tracker.set_physics_process(true)
	ActorLevel.clear(world.player)
	stage.tracker.refresh(world.player)


func _ladder() -> void:
	var lad: Dictionary = registry.ladders[0]
	var p: Node2D = world.player
	await _put_player(lad["bottom"] + Vector2(0, 10), 0.4)
	var lane: ClimbLane = null
	for c in stage.lanes:
		if c.lane_id == lad["id"] and c.from_id == lad["from"]:
			lane = c
	var ok: bool = lane.climb(p)
	print("ladder climb started: ", ok, " duration ", lane.last_duration)
	await wait(0.5)
	await shot("levels_05_ladder_mid_climb")
	await wait(1.0)
	await shot("levels_05_ladder_top")
	print("ladder: player level after the climb ", ActorLevel.level_id(p), " z ", p.z_index)


func _overlap() -> void:
	var upper: Level = registry.get_level(&"upper")
	var torvet: Level = registry.get_level(&"torvet")
	# a figure on the Torvet just in front of the Upper deck's rim, one on the Upper deck at its front, and the player on the deck
	var on_torvet: Vector2 = sk(760, 600)
	var on_upper: Vector2 = sk(785, 505)
	var a: CharacterBody2D = _make_actor(on_torvet, "rabbit", Color.WHITE)
	var b: CharacterBody2D = _make_actor(on_upper, "bunny", Color.WHITE)
	await _put_player(sk(800, 556), 0.4)
	await get_tree().physics_frame
	await wait(0.3)
	var img: Image = await shot("levels_06_torvet_and_upper_overlap")
	print("overlap: actor on torvet z ", a.z_index, " level ", ActorLevel.level_id(a), "; actor on upper z ", b.z_index, " level ", ActorLevel.level_id(b), "; torvet rank ", torvet.rank, " upper rank ", upper.rank)
	a.queue_free()
	b.queue_free()
	img = null


## Contact sheet of the six `under` bridge ends: the figure stands at the gate (one body radius before the rim), its level is printed.
func _ends() -> void:
	var crops: Array[Image] = []
	var p: Node2D = world.player
	p.visual.sprite.self_modulate = Color(1, 0, 1)
	var labels: Array[String] = []
	for id in ["b0", "b1", "b2", "b3", "b6", "b7"]:
		var lv: Level = registry.get_level(StringName(id))
		var gate: Vector2 = lv.gate_path[0] if lv.ends[0] == &"under" else lv.gate_path[lv.gate_path.size() - 1]
		var inward: Vector2 = (lv.path[0] - lv.path[lv.path.size() - 1]).normalized() if lv.ends[0] == &"under" else (lv.path[lv.path.size() - 1] - lv.path[0]).normalized()
		# stand ON the strip, 10 px before the gate (still the bridge's level)
		var pos: Vector2 = gate - inward * 10.0
		await _put_player(pos, 0.4)
		var img: Image = await shot("levels_07_end_%s" % id)
		var sc: Vector2 = screen_of(pos)
		var r := Rect2i(int(sc.x) - 213, int(sc.y) - 200, 426, 300).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var crop := Image.create(426, 300, false, Image.FORMAT_RGBA8)
		crop.blit_rect(img, r, Vector2i(r.position.x - (int(sc.x) - 213), r.position.y - (int(sc.y) - 200)))
		crops.append(crop)
		labels.append("%s level %s z %d magenta %d" % [id, ActorLevel.level_id(p), p.z_index, magenta(img, sc)])
	var sheet := Image.create(426 * 3, 300 * 2, false, Image.FORMAT_RGBA8)
	for i in crops.size():
		sheet.blit_rect(crops[i], Rect2i(0, 0, 426, 300), Vector2i((i % 3) * 426, (i / 3) * 300))
	if out_dir != "":
		sheet.save_png("%s/levels_07_tuck_ends_sheet.png" % out_dir)
	print("ends: ", " | ".join(labels))
	p.visual.sprite.self_modulate = Color.WHITE


func _dusk() -> void:
	_set_hour(20.5)
	await _put_player(registry.spawns["default"] + Vector2(120, 0), 0.4)
	await wait(0.5)
	await shot("levels_08_dusk_lanterns")
	var counts: Vector2i = stage.glow.visible_counts()
	print("dusk: glow factor ", stage.glow.factor, " halos ", counts.x, " lights ", counts.y, " of ", stage.glow.lights.size())
	_set_hour(11.0)


## Draw calls and frame time at the Torvet, then with groups of the stand-in scene hidden (what each part costs).
func _perf() -> void:
	await _put_player(registry.spawns["default"], 0.4)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var area: IsoArea = world.area
	var groups := {
		"everything": null,
		"backdrop": area.backdrop,
		"floors (discs, decks, rails, lamps)": stage.floors,
		"objects (trunks, huts, props, actor)": area.objects,
		"glow": stage.glow,
		"canopy": stage.canopy_layer,
	}
	for k in groups:
		var node: Variant = groups[k]
		if node != null:
			(node as CanvasItem if node is CanvasItem else node).set("visible", false)
		var calls := 0
		var ms := 0.0
		var last := Time.get_ticks_usec()
		for i in 60:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			ms += float(now - last) / 1000.0
			last = now
			calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("perf %-40s draw calls %4d   %.2f ms/frame" % [("without " + k) if node != null else k, calls, ms / 60.0])
		if node != null:
			(node as Object).set("visible", true)


func _lift() -> void:
	var lf: Dictionary = registry.lifts[0]
	await _put_player((lf["stand"] as Vector2) + Vector2(0, 40), 0.4)
	await shot("levels_09_skovlift_rim")
