extends Control
## Dev screenshot driver. Run (NON-headless, opens a window briefly, ALWAYS through impl/tools/windowed.sh or tools/dev/run_windowed.sh):
##   godot --path . --write-movie OUT/f.png --fixed-fps 10 --quit-after N res://scenes/ui/dev/shot_runner.tscn -- [win=WxH] components components_rarity ...
## Each name is shown for FRAMES_PER_SHOT frames; "SHOT name frame=N" is printed when the shot is ready (the movie frame to look at),
## "SHOT_SKIP name" when the screen's scene does not exist yet (screens land in any order).
## Fixtures live in scripts/ui/dev/ui_fixtures.gd (a screen owner registers its state setup there).
## win=WxH shows the screens inside an embedded borderless Window that uses the project's stretch settings
## (canvas_items, expand, 1280x720 base) so non-16:9 window shapes can be checked from a 1920x1080 capture.

const Fixtures = preload("res://scripts/ui/dev/ui_fixtures.gd")
const FRAMES_PER_SHOT := 6

var _names: PackedStringArray = []
var _host: Node = self


func _ready() -> void:
	var names := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("win="):
			var wh := a.get_slice("=", 1).split("x")
			var w := Window.new()
			w.size = Vector2i(int(wh[0]), int(wh[1]))
			w.position = (Vector2i(1280, 720) - w.size) / 2   # embedded windows live in the parent's logical (1280x720) space
			w.borderless = true
			w.unresizable = true
			w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
			w.content_scale_size = Vector2i(1280, 720)
			add_child(w)
			_host = w
			w.show()
		else:
			names.append(a)
	_names = names if not names.is_empty() else PackedStringArray(["components"])
	await get_tree().process_frame
	var vp := _host.get_viewport()
	print("VIEWPORT visible=%s window=%s" % [vp.get_visible_rect().size, (_host as Window).size if _host is Window else get_window().size])
	for n in _names:
		var node: Node = await Fixtures.make(n, _host)
		if node == null:
			print("SHOT_SKIP ", n)
			continue
		for i in FRAMES_PER_SHOT:
			await get_tree().process_frame
		print("SHOT %s frame=%d" % [n, Engine.get_frames_drawn()])
		await get_tree().process_frame
		for c in _host.get_children():       # screen + the fixture's backdrop
			c.queue_free()
		get_tree().paused = false
		await get_tree().process_frame
	get_tree().quit()
