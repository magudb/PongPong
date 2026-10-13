extends Node
## y-sort threshold probe (lifted from the world spike's sort_probe): a magenta figure at offsets around the sort point of the iso
## house front corner, a tree and the ortho wall pillar, with physics off so nothing can push it; prints the visible magenta count.
##   godot --path . --resolution 1280x720 res://tests/shot_sort_probe.tscn --quit-after 3600
var world: Node2D


func _ready() -> void:
	_run.call_deferred()


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func probe(label: String, base: Vector2, dxs: Array, offs: Array) -> void:
	var p: Node2D = world.player
	for dx in dxs:
		var res := []
		for off in offs:
			p.global_position = base + Vector2(float(dx), float(off))
			p.camera.reset_smoothing()
			await wait(0.2)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var pc: Vector2 = get_viewport().get_canvas_transform() * p.global_position
			var n := 0
			for dy in range(-90, -20, 6):
				for ddx in range(-12, 13, 6):
					var c := img.get_pixel(clampi(int(pc.x) + ddx, 0, img.get_width() - 1), clampi(int(pc.y) + dy, 0, img.get_height() - 1))
					if c.r > c.g + 0.1 and c.b > c.g + 0.15:   # magenta, also when the dark ambient multiplies it
						n += 1
			res.append("%d:%d" % [int(off), n])
		print(label, " dx=", dx, " -> ", ", ".join(res))


func _run() -> void:
	GameManager.start_new_game("T", 0, "F")
	world = (load("res://scenes/main/world.tscn") as PackedScene).instantiate()
	add_child(world)
	await wait(1.0)
	var p: Node2D = world.player
	p.visual.sprite.self_modulate = Color(1, 0, 1)
	p.set_physics_process(false)
	world._enter(&"_fixture_iso", &"default")
	await wait(0.4)
	var a: IsoArea = world.area
	for rec in a.prop_nodes:
		if rec["id"] == "house_farm":
			var front: Vector2 = a.to_global(Iso.iso_footprint(rec["cell"], 3, 2)[2])
			await probe("iso house (sort point = front corner)", front, [-60, 0, 60], [-70, -40, -20, -5, 5, 20, 40])
		if rec["id"] == "tree_oak_farm":
			await probe("iso tree", a.to_global(Iso.iso_center(rec["cell"])), [0], [-40, -20, -5, 5, 20, 40])
	world._enter(&"_fixture_ortho", &"default")
	await wait(0.4)
	var wc: Vector2 = world.area.cell_to_global(Vector2i(6, 6)) + Vector2(0, Iso.ORTHO_H * 0.5)
	await probe("ortho wall tile (sort origin = cell bottom edge)", wc, [0], [-60, -30, -15, -5, 5, 15, 30])
	get_tree().quit()
