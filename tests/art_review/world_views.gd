extends RefCounted
## Same native camera poses can be run against the original and painted worktrees.
const SECTION := "world_views"
const TIMEOUT_S := 120.0

func run_windowed(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var keep_auto: bool = sm.autosave_enabled
	sm.autosave_enabled = false
	await t.start_world("animal")
	var world: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	gm.hour = 11
	t.autoload("TimeManager").pause_time()
	world.call("_enter", &"traetoppen", &"default")
	t.autoload("TimeManager").pause_time()
	world.day_night.snap()
	_pose(world, world.area.camera_rect().get_center(), .2)
	await t.frames(8)
	_capture(t, "city_overview")
	_pose(world, Vector2(2610, 2100), .4)
	await t.frames(8)
	_capture(t, "city_close")
	gm.hour = 21
	world.day_night.snap()
	await t.frames(8)
	_capture(t, "city_night")
	world.call("_enter", &"moerkeskoven", &"default")
	t.autoload("TimeManager").pause_time()
	_pose(world, world.area.camera_rect().get_center(), .4)
	await t.frames(8)
	_capture(t, "forest_overview")
	_pose(world, world.area.get_spawn("from_floor") + Vector2(-180, 0), .65)
	await t.frames(8)
	_capture(t, "forest_close")
	await t.go_menu()
	sm.autosave_enabled = keep_auto
	t.check("captures_complete", true, "five native-engine views; inspect the PNGs")

func _pose(world: Node, at: Vector2, zoom: float) -> void:
	var player: Node2D = world.player
	player.global_position = at
	var stage := LevelStage.of(world.area)
	if stage != null:
		stage.tracker.refresh(player)
	for toast in world.find_children("Toast", "Label", true, false):
		toast.hide()
	var camera: Camera2D = player.get("camera")
	camera.zoom = Vector2.ONE * zoom
	camera.position_smoothing_enabled = false
	player.call("_apply_camera_limits")
	camera.reset_smoothing()

func _capture(t, label: String) -> void:
	# Like drawn/capture.gd, force a frame: minimized macOS windows can stop
	# emitting frame_post_draw even while the scene tree continues to tick.
	RenderingServer.force_draw(false)
	var frame: Image = t.tree.root.get_texture().get_image()
	var path: String = t.out_dir.path_join("world_views_%s.png" % label)
	var ok := frame != null and not frame.is_empty()
	if ok:
		ok = frame.save_png(path) == OK
	t.check("capture_%s" % label, ok, path)
