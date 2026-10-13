extends Node
## y-sort evidence (P04, review R.10): a magenta figure walks behind / in front of the iso fixture's house (cut into strips),
## its mushroom house, a tree and the ortho fixture's wall pillar. Saves one contact sheet per subject.
##   godot --path . --resolution 1280x720 res://tests/shot_sort.tscn --quit-after 3600 -- --out=DIR
## Counts the magenta pixels of the figure at every offset, so the sheet can be checked by number as well as by eye.
var out_dir := ""
var world: Node2D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	_run.call_deferred()


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	GameManager.start_new_game("T", 0, "F")
	world = (load("res://scenes/main/world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(1.0)
	var p: Node2D = world.player
	p.set("collision_mask", 0)
	p.set_physics_process(false)
	p.visual.sprite.self_modulate = Color(1, 0, 1)
	world.day_night.override_hour = 11.0
	world.day_night.snap()
	await _enter(&"_fixture_iso")
	var a: IsoArea = world.area
	for rec in a.prop_nodes:
		match str(rec["id"]):
			"house_farm":
				await _sheet(a, Iso.iso_footprint(rec["cell"], 3, 2)[2], [-60.0, -40.0, -26.0, -10.0, 10.0, 40.0], "sort_house")
			"house_mushroom_rose":
				await _sheet(a, Iso.iso_footprint(rec["cell"], 2, 2)[2], [-60.0, -40.0, -26.0, -10.0, 10.0, 40.0], "sort_mushroom")
			"tree_oak_farm":
				await _sheet(a, Iso.iso_center(rec["cell"]), [-40.0, -20.0, -5.0, 5.0, 20.0, 40.0], "sort_tree")
	await _enter(&"_fixture_ortho")
	var b: IsoArea = world.area
	var wall_bottom: Vector2 = b.cell_to_global(Vector2i(6, 6)) + Vector2(0, Iso.ORTHO_H * 0.5)
	await _sheet(b, wall_bottom, [-60.0, -30.0, -15.0, -5.0, 5.0, 30.0], "sort_wall")
	get_tree().quit()


func _enter(id: StringName) -> void:
	world._enter(id, &"default")
	world.day_night.override_hour = 11.0
	world.day_night.snap()
	await wait(0.5)


func _sheet(a: IsoArea, local_point: Vector2, offsets: Array, sheet_name: String) -> void:
	var p: Node2D = world.player
	var base: Vector2 = a.to_global(local_point)
	var crops: Array[Image] = []
	var counts: Array[String] = []
	for off in offsets:
		p.global_position = base + Vector2(0, float(off))
		p.camera.reset_smoothing()
		await wait(0.3)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var pc: Vector2 = get_viewport().get_canvas_transform() * p.global_position
		var n := 0
		for dy in range(-90, -10, 3):
			for dx in range(-24, 25, 3):
				var c := img.get_pixel(clampi(int(pc.x) + dx, 0, img.get_width() - 1), clampi(int(pc.y) + dy, 0, img.get_height() - 1))
				if c.r > c.g + 0.1 and c.b > c.g + 0.15:   # magenta, also when the dark ambient multiplies it
					n += 1
		counts.append("%d:%d" % [int(off), n])
		var r := Rect2i(int(pc.x) - 160, int(pc.y) - 150, 320, 240).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var crop := Image.create(320, 240, false, Image.FORMAT_RGBA8)
		crop.blit_rect(img, r, Vector2i(r.position.x - (int(pc.x) - 160), r.position.y - (int(pc.y) - 150)))
		crops.append(crop)
	var sheet := Image.create(320 * 3, 240 * 2, false, Image.FORMAT_RGBA8)
	for i in crops.size():
		sheet.blit_rect(crops[i], Rect2i(0, 0, 320, 240), Vector2i((i % 3) * 320, (i / 3) * 240))
	if out_dir != "":
		sheet.save_png("%s/%s.png" % [out_dir, sheet_name])
	print(sheet_name, " magenta pixels per offset (px below the sort point): ", ", ".join(counts))
