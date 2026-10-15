extends RefCounted
## Fit, texture and clock contracts for the isolated Rasmus/Pedro art proof.
const SECTION := "art_equipment_fit"
const TIMEOUT_S := 150.0
const Figure = preload("res://tools/art/drawn/equipment_fit_figure.gd")
const DOC := "res://docs/art/equipment-fit/"

func run(t) -> void:
	var data := Figure.manifest()
	var packing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DOC + "packing.json"))
	t.check("scope", data["status"] == "fit_proof" and not data["mirror_ok"] and Vector2(data["canvas"][0], data["canvas"][1]) == Vector2(256, 256) and Vector2(data["ground_anchor"][0], data["ground_anchor"][1]) == Vector2(128, 200), "isolated art proof with native body coordinates and authored directions")
	t.check("coverage", data["bodies"].keys() == ["rasmus", "pedro"] and data["directions"] == ["S", "SW", "W", "NW", "N", "NE", "E", "SE"], "two planned proof bodies, all eight directions")
	for source in packing["sources"]:
		t.check("source_%s" % source.get_file(), FileAccess.get_sha256("res://" + source) == packing["sources"][source], "selected source painting hash is reproducible")
	for part in data["items"]:
		t.check("item_%s" % part, not EconomyManager.item_def(data["items"][part]).is_empty(), "art uses an existing item ID")
	var count := 0
	for body_id in data["bodies"]:
		var body: Dictionary = data["bodies"][body_id]
		var locomotion_bytes := 0
		for clip in body["clips"]:
			var spec: Dictionary = body["clips"][clip]
			var path: String = Figure.PACK + spec["file"]
			var image := Image.new()
			image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path))
			var settings := ConfigFile.new()
			settings.load(path + ".import")
			t.check("import_%s_%s" % [body_id, clip], int(settings.get_value("params", "compress/mode", -1)) == 0 and not settings.get_value("params", "mipmaps/generate", true), "painted layers stay lossless, no mip bleeding between packed frames")
			t.check("size_%s_%s" % [body_id, clip], image.get_size() == Vector2i(int(spec["size"][0]), int(spec["size"][1])) and spec["poses"].size() == 8, "export dimensions and eight pose rows")
			if clip != "interact":
				locomotion_bytes += image.get_width() * image.get_height() * 4
			for d in 8:
				t.check("frames_%s_%s_%d" % [body_id, clip, d], spec["poses"][d].size() == int(spec["frames"]), "complete directional animation frames")
				for frame in int(spec["frames"]):
					var pose: Dictionary = spec["poses"][d][frame]
					var key := "%s_%s_%d_%d" % [body_id, clip, d, frame]
					var valid: bool = pose["order"].size() == data["parts"].size() and pose["parts"].size() == data["parts"].size()
					for part in pose["parts"]:
						var rec: Dictionary = pose["parts"][part]
						if not rec["visible"]:
							continue
						var r: Array = rec["rect"]
						var o: Array = rec["canvas_offset"]
						valid = valid and r[0] >= 2 and r[1] >= 2 and r[0] + r[2] <= image.get_width() - 2 and r[1] + r[3] <= image.get_height() - 2 and o[0] >= 0 and o[1] >= 0 and o[0] + r[2] <= 256 and o[1] + r[3] <= 256
						valid = valid and image.get_pixel(int(r[0]) - 1, int(r[1]) - 1).a == 0.0
					var grip: Dictionary = pose["sockets"]["grip_r"]
					var position: Array = grip["position"]
					valid = valid and pose["held"]["grip"] == position and pose["held"]["socket"] == "grip_r" and pose["held"]["hands_required"] == 1 and position[0] >= 0 and position[0] < 256 and position[1] >= 0 and position[1] < 256
					if grip["visible"]:
						var hand: Dictionary = pose["parts"]["hand_r"]
						var h: Array = hand["rect"]
						var offset: Array = hand["canvas_offset"]
						var px := Vector2i(int(position[0] - offset[0]), int(position[1] - offset[1]))
						valid = valid and px.x >= 0 and px.y >= 0 and px.x < h[2] and px.y < h[3]
						if px.x >= 0 and px.y >= 0 and px.x < h[2] and px.y < h[3]:
							valid = valid and image.get_pixel(int(h[0]) + px.x, int(h[1]) + px.y).a > .1
						valid = valid and pose["order"].find("hand_r") > pose["order"].find("sword")
					valid = valid and (pose["order"].find("sword") < pose["order"].find("body") if pose["held"]["depth"] == "rear" else pose["order"].find("sword") > pose["order"].find("shirt"))
					if body_id == "pedro":
						valid = valid and not pose["parts"]["ears"]["visible"]
					t.check("fit_%s" % key, valid, "trim offsets, bounds, grips and body/garment/hand depth remain consistent")
					count += 1
		t.check("locomotion_budget_%s" % body_id, locomotion_bytes <= 32 * 1024 * 1024, "%.2f MiB full body + clothing + sword idle/walk/run; shared stock clock art separate" % (locomotion_bytes / 1048576.0))
	t.check("all_poses", count == 320 and packing["sockets"] == 640 and packing["maximum_socket_error_px"] < .01, "320 poses, both explicit grips per pose, solved against the exact body field")
	var before: Dictionary = EconomyManager.to_dict().duplicate(true)
	var profiles: Dictionary = {}
	for body_id in data["bodies"]:
		var figure := Figure.new()
		figure.body_id = body_id
		t.root.add_child(figure)
		figure.clock.set_process(false)
		figure.set_process(false)
		for clip in ["idle", "walk", "run", "interact"]:
			figure.clock.play_loop(&"idle")
			figure.select_clip(clip)
			var spec: Dictionary = data["bodies"][body_id]["clips"][clip]
			for frame in int(spec["frames"]):
				for d in 8:
					figure.clock.set_direction_index(d)
					figure.sync_pose()
					t.check("sample_%s_%s_%d_%d" % [body_id, clip, d, frame], not figure.clock.sprite.visible and figure.parts_root.visible and figure.pose == spec["poses"][d][frame], "every native frame/direction comes from the body clock without an independent timer")
				figure.clock._process(1.0 / float(spec["fps"]))
		figure.clock.set_spin(.72)
		figure.clock.set_altitude(31)
		figure.clock.display_scale = 1.2
		figure.clock.refresh_visual_scale()
		figure.clock.sprite.modulate = Color("eab0d1")
		figure.sync_pose()
		var transform_ok := figure.parts_root.position == figure.clock.sprite.position and figure.parts_root.rotation == figure.clock.sprite.rotation and figure.parts_root.scale == figure.clock.sprite.scale and figure.parts_root.modulate == figure.clock.sprite.modulate
		for part in figure.parts:
			var rec: Dictionary = figure.pose["parts"][part]
			if rec["visible"]:
				var o: Array = rec["canvas_offset"]
				transform_ok = transform_ok and figure.parts[part].offset == Vector2(o[0] - 128, o[1] - 200) + figure.clock.sprite.offset - figure.clock.base_sprite_offset
		t.check("shared_transform_%s" % body_id, transform_ok, "spin offset, altitude, scale and damage tint applied once to every part")
		figure.set_part_enabled("shirt", false)
		figure.set_part_enabled("hat", false)
		t.check("independent_layers_%s" % body_id, not figure.parts["shirt"].visible and not figure.parts["hat"].visible and figure.parts["pants"].visible and figure.parts["body"].visible, "removing one garment leaves a safe base and does not remove other slots")
		t.check("canvas_budget_%s" % body_id, figure.parts_root.get_child_count() + 1 <= 16 and figure.find_children("*", "CollisionObject2D", true, false).is_empty(), "ten added CanvasItems; no gameplay collision or global depth plane")
		figure.clock.set_spin(0)
		figure.select_clip("walk")
		var started := Time.get_ticks_usec()
		for n in 1200:
			figure.clock.set_direction_index(n % 8)
			figure.sync_pose()
		profiles[body_id] = {"changed_direction_update_mean_ms": (Time.get_ticks_usec() - started) / 1200000.0, "samples": 1200, "added_canvas_items": figure.parts_root.get_child_count() + 1, "note": "CPU direction change + presenter only on this development host, not renderer/GPU or target-device frame time"}
		figure.clock.play_loop(&"jump")
		figure.sync_pose()
		t.check("unsupported_clip_fallback_%s" % body_id, figure.clock.sprite.visible and not figure.parts_root.visible and figure.pose.is_empty(), "unproduced clips reveal the complete stock hero atomically")
		figure.free()
	t.check("no_inventory_mutation", before == EconomyManager.to_dict(), "fit review never grants or equips gameplay items")
	if OS.get_environment("EQUIPMENT_FIT_PROFILE") == "1":
		var output := FileAccess.open(DOC + "cpu-profile.json", FileAccess.WRITE)
		output.store_string(JSON.stringify(profiles, "  ") + "\n")
	var released := _released(t)
	await t.frames(2)
	t.check("release_with_host", released[0].get_ref() == null and released[1].get_ref() == null, "figure and selected proof texture resources release with their owner; renderer pools separate")

func _released(t) -> Array[WeakRef]:
	var figure := Figure.new()
	t.root.add_child(figure)
	var refs: Array[WeakRef] = [weakref(figure), weakref(figure.textures["idle"])]
	figure.free()
	return refs

func run_windowed(t) -> void:
	var data := Figure.manifest()
	for body_id in data["bodies"]:
		for clip in data["bodies"][body_id]["clips"]:
			var sheet := Node2D.new()
			t.root.add_child(sheet)
			var bg := ColorRect.new()
			bg.color = Color("eee7d8")
			bg.size = Vector2(1280, 720)
			sheet.add_child(bg)
			var title := Label.new()
			title.text = "%s · %s · S SW W NW N NE E SE · all baked frames top to bottom" % [body_id.capitalize(), clip]
			title.position = Vector2(18, 4)
			title.add_theme_color_override("font_color", Color("4b3c49"))
			sheet.add_child(title)
			var spec: Dictionary = data["bodies"][body_id]["clips"][clip]
			for frame in int(spec["frames"]):
				for d in 8:
					var f := Figure.new()
					f.body_id = body_id
					f.position = Vector2(80 + d * 158, 124 + frame * 105)
					f.scale = Vector2.ONE * .55
					sheet.add_child(f)
					f.set_process(false)
					f.clock.set_process(false)
					f.select_clip(clip)
					f.clock.set_direction_index(d)
					f.clock._process((frame + .001) / float(spec["fps"]))
					f.sync_pose()
				await t.frames(1)
			var image: Image = await t.capture("fit_%s_%s_all_frames" % [body_id, clip])
			t.expect_not_blank(image, Rect2i(0, 25, 1280, 680), "all %s %s frames" % [body_id, clip])
			sheet.free()
			await t.frames(1)
		var studio = load("res://tools/art/drawn/equipment_fit_gallery.tscn").instantiate()
		t.root.add_child(studio)
		studio._select_body(body_id)
		for figure in studio.figures:
			figure.set_process(false)
			figure.clock.set_process(false)
		await t.frames(2)
		await t.capture("fit_%s_floors" % body_id)
		studio._buttons["hat"].button_pressed = false
		studio._buttons["shirt"].button_pressed = false
		await t.frames(2)
		await t.capture("fit_%s_removed_layers" % body_id)
		studio._buttons["hat"].button_pressed = true
		studio._buttons["shirt"].button_pressed = true
		studio._spin(.65)
		for figure in studio.figures:
			figure.clock.set_altitude(24)
			figure.clock.sprite.modulate = Color("eab4cc")
			figure.sync_pose()
		await t.frames(2)
		await t.capture("fit_%s_spin_altitude_tint" % body_id)
		studio.free()
