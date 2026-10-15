extends RefCounted
## Observational CPU/resource measurements of the actual world, with the headless dummy renderer.
const SECTION := "review_performance"
const TIMEOUT_S := 120.0

func run(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var keep_auto: bool = sm.autosave_enabled
	sm.autosave_enabled = false
	await t.go_menu()
	var start := Time.get_ticks_usec()
	await t.start_world("animal")
	var world: Node = t.world()
	t.autoload("TimeManager").pause_time()
	t.info("REVIEW_PERF initial_farm_with_scene_frames_ms=%.3f static_mib=%.2f" % [float(Time.get_ticks_usec() - start) / 1000.0, _mib()])
	for cycle in 4:
		for id in [&"traetoppen", &"hyggebyen", &"moerkeskoven", &"farm"]:
			start = Time.get_ticks_usec()
			var entered: bool = world.call("_enter", id, &"default")
			var elapsed := float(Time.get_ticks_usec() - start) / 1000.0
			t.check("area_%s_%d" % [id, cycle], entered, "")
			t.autoload("TimeManager").pause_time()
			await t.frames(3)
			t.info("REVIEW_PERF area=%s cycle=%d enter_ms=%.3f area_build_ms=%s nodes=%d static_mib=%.2f" % [
				id, cycle, elapsed, world.area.build_ms, _nodes(world.area), _mib()])
			if id == &"traetoppen" and cycle == 3:
				var tracker: LevelTracker = LevelStage.of(world.area).tracker
				var timings: Array[float] = []
				for n in 200:
					world.player.global_position += Vector2(0.01, 0.0)
					start = Time.get_ticks_usec()
					tracker.call("_physics_process", 1.0 / 60.0)
					timings.append(float(Time.get_ticks_usec() - start) / 1000.0)
				timings.sort()
				t.info("REVIEW_PERF tracker_actual_actors=%d median_ms=%.4f p95_ms=%.4f" % [tracker.actors.size(), timings[100], timings[190]])
	await t.go_menu()
	await t.frames(4)
	t.info("REVIEW_PERF after_quit_to_menu_static_mib=%.2f" % _mib())
	sm.autosave_enabled = keep_auto

func _mib() -> float:
	return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0

func _nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _nodes(child)
	return count
