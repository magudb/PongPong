extends Node
## Flight draw order (P04: flying actors sit at z_index 20, their shadow stays on the floor at z -5 absolute): a pack fairy hovers
## at altitude 110 behind a tree. The same figure at z_index 0 is hidden behind the crown, at z 20 it is drawn over it.
## Works with the player stub; once Player2D (P06) lands its own fly_toggle can be driven the same way.
##   godot --path . --resolution 1280x720 res://tests/shot_flight.tscn --quit-after 3600 -- --out=DIR
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
	GameManager.start_new_game("T", 1, "F")
	world = (load("res://scenes/main/world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(1.0)
	world._enter(&"_fixture_iso", &"default")
	world.day_night.override_hour = 11.0
	world.day_night.snap()
	var a: IsoArea = world.area
	var tree_pos: Vector2 = Vector2.ZERO
	for rec in a.prop_nodes:
		if rec["id"] == "tree_oak_farm":
			tree_pos = a.to_global(Iso.iso_center(rec["cell"]))
	var p: Node2D = world.player
	p.set_physics_process(false)
	p.visible = false
	var results: Array[String] = []
	for z in [0, 20]:
		var fairy: IsoChibiSprite2D = IsoChibiSprite2D.create("fairy")
		a.objects.add_child(fairy)
		fairy.global_position = tree_pos + Vector2(-6, -34)   # standing BEHIND the trunk: y-sort alone hides it behind the crown
		fairy.set_altitude(110.0)
		fairy.z_index = z
		fairy.play_loop(&"hover")
		fairy.sprite.self_modulate = Color(1, 0, 1)
		p.global_position = tree_pos + Vector2(-40, 60)
		p.camera.reset_smoothing()
		await wait(0.5)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var pc: Vector2 = get_viewport().get_canvas_transform() * fairy.global_position
		var n := 0
		for dy in range(-170, -20, 3):
			for dx in range(-60, 61, 3):
				var c := img.get_pixel(clampi(int(pc.x) + dx, 0, img.get_width() - 1), clampi(int(pc.y) + dy, 0, img.get_height() - 1))
				if c.r > c.g + 0.1 and c.b > c.g + 0.15:   # magenta, also when the dark ambient multiplies it
					n += 1
		results.append("z_index %d -> %d magenta pixels" % [z, n])
		var r := Rect2i(int(pc.x) - 300, int(pc.y) - 330, 600, 420).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if out_dir != "":
			img.get_region(r).save_png("%s/flight_over_tree_z%d.png" % [out_dir, z])
		fairy.queue_free()
	print("flight over the tree: ", " | ".join(results))
	get_tree().quit()
