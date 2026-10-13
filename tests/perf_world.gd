extends Node
## Performance / memory / loading probe and the cast line-up of the 12 pack characters (package P05).
## Self-contained: no world, no autoload game state, only IsoChibiSprite2D on a drawn isometric ground.
##
##   godot --path . --resolution 1280x720 res://tests/perf_world.tscn -- --cast --out=DIR      the line-up screenshots (windowed, ~15 s)
##   godot --path . --resolution 1280x720 res://tests/perf_world.tscn -- [--tag=x] [--quick]      100 / 200 animated characters, frame ms
##   godot --headless --path . res://tests/perf_world.tscn -- --quick                              script cost only (dummy renderer)
##
## Always run windowed through tools/dev/run_windowed.sh or impl/tools/windowed.sh with --quit-after as a safety net.
## Plan 8.6: 100 animated characters < 8 ms / frame in Compatibility on the Apple M3 reference (spike: 7.2 ms, 200: 8.6 ms),
## unwarmed first clip use < 40 ms, warmed < 8 ms.
##
## BUDGETS are asserted, not just printed: every windowed run prints "PERF BUDGET OK|OVER|BUSY <name> ..." per budget below; the
## process exits 1 when any is over on a quiet machine, 3 when some are over but the machine is loaded (inconclusive: rerun when
## quiet), 0 otherwise (headless: "n/a", the dummy renderer cannot see GPU cost). The
## static measure_* helpers are shared with tests/sections/characters.gd (run_windowed) so both report the same numbers.

const Chibi := preload("res://scripts/isometric/iso_chibi_sprite_2d.gd")

const BUDGET_100_MS := 8.0               # plan 8.6: mean frame with 100 animated characters
const BUDGET_UNWARMED_MS := 40.0         # plan 8.6: the frame that first uses a clip sheet which is not loaded yet
const BUDGET_WARMED_MS := 8.0            # plan 8.6: first use of a clip after warm_clips()
## Worst frame while warm_clips() brings in five cold sheets: no frame may exceed the 8 ms frame budget. Measured on the M3 (best
## of 3 characters, quiet-ish machine): 3.6-4.1 ms for the real code; a mutant that loads the five sheets synchronously in one frame
## gives 12.6-23.5 ms. (The ONE-sheet-per-frame pacing itself is guarded by the deterministic headless check
## characters.warm_clips_one_sheet_per_frame: in the Compatibility renderer the GPU upload of a sheet is cheap on the main thread,
## so the windowed number cannot see the pacing, only a real cost regression.)
const BUDGET_WARM_FRAME_MS := 8.0

const PACK_IDS: Array[String] = ["bat", "cat", "bear", "rabbit", "fairy", "monkey", "capybara", "fox", "raccoon", "penguin", "hedgehog", "frog"]
const CLIPS_STD: Array[String] = ["idle", "walk", "run", "jump", "fall", "land", "celebrate", "interact", "hit", "sleep", "talk"]
const CLIPS_FLY: Array[String] = ["takeoff", "hover", "fly", "flight_land"]
const TILE_W := 128.0
const TILE_H := 76.0
const GAME_ZOOM := 0.4          # Iso.DEFAULT_ZOOM at the 1280x720 base
const SE := 7                   # direction index of the south-east row of the sheets (S SW W NW N NE E SE)

var out_dir := ""
var tag := "x"
var quick := false
var cast_mode := false
var _vp: RID
var _over: Array[String] = []
var _busy: Array[String] = []


## Soft green isometric diamonds standing in for the farm ground (the real tiles are P22's art). ONE mesh = one draw call,
## so the frame time of the perf runs is the characters', not the ground's.
class Ground extends Node2D:
	var half_extent: int = 34
	var _mesh: ArrayMesh

	func _ready() -> void:
		var a := Color("8fb35c")
		var b := Color("86ab55")
		var verts := PackedVector2Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		for i in range(-half_extent, half_extent + 1):
			for j in range(-half_extent, half_extent + 1):
				var c := Vector2((i - j) * TILE_W * 0.5, (i + j) * TILE_H * 0.5)
				var base := verts.size()
				verts.append(c + Vector2(0, -TILE_H * 0.5))
				verts.append(c + Vector2(TILE_W * 0.5, 0))
				verts.append(c + Vector2(0, TILE_H * 0.5))
				verts.append(c + Vector2(-TILE_W * 0.5, 0))
				var col := a if (i + j) % 2 == 0 else b
				for k in 4:
					colors.append(col)
				indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		_mesh = ArrayMesh.new()
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		queue_redraw()

	func _draw() -> void:
		if _mesh != null:
			draw_mesh(_mesh, null)


## A drawn ground, a y-sorted Objects node and a camera at `zoom` under `parent`. Returns {root, objects, camera}.
static func make_world(parent: Node, zoom: float) -> Dictionary:
	var root := Node2D.new()
	root.name = "CastWorld"
	parent.add_child(root)
	var ground := Ground.new()
	ground.z_index = -10
	root.add_child(ground)
	var objects := Node2D.new()
	objects.name = "Objects"
	objects.y_sort_enabled = true
	objects.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(objects)
	var cam := Camera2D.new()
	cam.zoom = Vector2(zoom, zoom)
	root.add_child(cam)
	cam.make_current()
	return {"root": root, "objects": objects, "camera": cam}


## Puts `ids` on a grid: `cols` per row, `spacing` world px apart, the first one at `origin`. Returns the sprites.
static func place_cast(objects: Node2D, ids: Array, origin: Vector2, spacing: Vector2, cols: int, direction: int, clip: StringName) -> Array:
	var out: Array = []
	for n in ids.size():
		var vis = Chibi.create(str(ids[n]))
		vis.position = origin + Vector2((n % cols) * spacing.x, floori(float(n) / float(cols)) * spacing.y)
		vis.set_direction_index(direction)      # chosen BEFORE add_child: _ready keeps it (characters.configure_before_add_child)
		objects.add_child(vis)
		if clip != &"idle" and vis.has_clip(clip):
			vis.play_loop(clip)
		out.append(vis)
	return out


## `count` animated characters (walking, every third running, random facing and rate) at random spots of the y-sorted
## `objects` node; `made` collects them and is topped up to `count`. The same crowd for perf_world and the characters section.
static func fill_crowd(objects: Node2D, made: Array, count: int, rng: RandomNumberGenerator) -> void:
	while made.size() < count:
		var id: String = PACK_IDS[made.size() % PACK_IDS.size()]
		var vis = Chibi.create(id)
		vis.position = Vector2(rng.randf_range(-1400, 1400), rng.randf_range(-700, 700))
		vis.starting_direction = rng.randi() % 8
		objects.add_child(vis)
		vis.playback_rate = rng.randf_range(0.8, 1.3)
		vis.play_loop(&"walk" if made.size() % 3 != 0 else &"run")
		made.append(vis)


## vsync off and no fps cap, so frame times are the work and not the wait for the 60 Hz display. Returns the old settings.
static func uncap() -> Dictionary:
	var old := {"vsync": DisplayServer.window_get_vsync_mode(), "fps": Engine.max_fps}
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	return old


static func restore_cap(old: Dictionary) -> void:
	DisplayServer.window_set_vsync_mode(old["vsync"])
	Engine.max_fps = old["fps"]


## Frame times over `secs` seconds: {frames, fps, ms (mean), worst_ms, render cpu/gpu ms when `vp` is a measured viewport}.
static func measure_frames(tree: SceneTree, secs: float, vp: RID = RID()) -> Dictionary:
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var last := t0
	var worst := 0.0
	var gpu := 0.0
	var cpur := 0.0
	while (Time.get_ticks_usec() - t0) < int(secs * 1e6):
		await tree.process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
		if vp.is_valid():
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpur += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var el := float(Time.get_ticks_usec() - t0) / 1e6
	var n := maxi(frames, 1)
	return {"frames": frames, "fps": frames / el, "ms": el / n * 1000.0, "worst_ms": worst, "gpu_ms": gpu / n, "cpu_render_ms": cpur / n}


## Frame times while `probe.warm_clips(clips)` runs (the probe must be in the tree): {done, frames, worst_ms, wall_ms}.
static func measure_warm(tree: SceneTree, probe: Node, clips: Array) -> Dictionary:
	var done := [false]
	var runner := func() -> void:
		await probe.warm_clips(clips)
		done[0] = true
	var t0 := Time.get_ticks_usec()
	var last := t0
	var worst := 0.0
	var frames := 0
	runner.call()
	while not done[0] and Time.get_ticks_usec() - t0 < 20000000:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
	return {"done": done[0], "frames": frames, "worst_ms": worst, "wall_ms": float(Time.get_ticks_usec() - t0) / 1000.0}


## Cost in ms of using a clip whose sheet is not resident yet: from the play call to the end of the frame that draws it
## (the synchronous load in the sprite plus the GPU upload of the sheet).
static func measure_first_play(tree: SceneTree, probe: Node, clip: StringName, as_action: bool) -> float:
	var t1 := Time.get_ticks_usec()
	if as_action:
		probe.play_action(clip)
	else:
		probe.play_loop(clip)
	await tree.process_frame
	return float(Time.get_ticks_usec() - t1) / 1000.0


## {load1, cores, busy, text}: the 1-minute load average from `uptime` (macOS "load averages: 4.1 3.9 3.5", Linux "load average:
## 0.50, 0.40, 0.30") against the core count; busy = load1 > cores / 2. Unknown load (no uptime) counts as not busy.
static func machine_load() -> Dictionary:
	var cores := OS.get_processor_count()
	var load1 := -1.0
	var out: Array = []
	if OS.execute("/usr/bin/uptime", PackedStringArray(), out, true) == 0 and not out.is_empty():
		var text := str(out[0])
		var at := text.find("load average")
		if at >= 0:
			var rest := text.substr(at).get_slice(":", 1).strip_edges()
			var token := rest.get_slice(" ", 0).trim_suffix(",").replace(",", ".")
			if token.is_valid_float():
				load1 = token.to_float()
	var busy := load1 > float(cores) * 0.5
	return {"load1": load1, "cores": cores, "busy": busy, "text": ("load %.1f on %d cores" % [load1, cores]) if load1 >= 0.0 else "load unknown, %d cores" % cores}


## NOISE RULE. These budgets are measured on a machine that other jobs share (and the plan reference is the quiet M3):
## load only ever ADDS time to a frame, so the smallest of a few repeated measurements is the intrinsic cost, while a real
## regression (five sheets finalised in one frame, a doubled draw cost) shows in EVERY repetition. The *_best helpers repeat
## `ATTEMPTS` times and report the best; the all-attempts numbers are returned too so a run prints what it saw.
const ATTEMPTS := 3
const WARM_LIST: Array = ["walk", "run", "interact", "talk", "hit"]
const WARM_PLAY_LIST: Array = ["walk", "run", "talk", "hit"]


## measure_frames over `attempts` windows; the window with the smallest mean frame wins ({..., all_ms}).
static func measure_frames_best(tree: SceneTree, secs: float, attempts: int = ATTEMPTS, vp: RID = RID()) -> Dictionary:
	var best := {}
	var all: Array[float] = []
	for i in attempts:
		var m: Dictionary = await measure_frames(tree, secs, vp)
		all.append(float(m["ms"]))
		if best.is_empty() or float(m["ms"]) < float(best["ms"]):
			best = m
	best["all_ms"] = all
	return best


## Cold first use of each clip: one FRESH character per entry of `ids` (their sheets are not resident), every clip of
## `clips` played for the first time on it ("action" clips with play_action, the rest looped). Per clip the best of the
## characters; {worst_ms (the slowest clip at its best), best: {clip: ms}, all: {clip: [ms per character]}}.
static func measure_cold_first_play(tree: SceneTree, objects: Node2D, ids: Array, clips: Array, action_clips: Array) -> Dictionary:
	var all := {}
	for c in clips:
		all[str(c)] = []
	for id in ids:
		var probe = Chibi.create(str(id))
		objects.add_child(probe)
		for i in 3:
			await tree.process_frame
		for c in clips:
			var ms: float = await measure_first_play(tree, probe, StringName(str(c)), str(c) in action_clips)
			(all[str(c)] as Array).append(ms)
			probe.cancel_action()
			await tree.create_timer(0.3).timeout
		probe.queue_free()
		await tree.process_frame
	var best := {}
	var worst := 0.0
	for c in clips:
		var lo := INF
		for ms in all[str(c)]:
			lo = minf(lo, float(ms))
		best[str(c)] = lo
		worst = maxf(worst, lo)
	return {"worst_ms": worst, "best": best, "all": all}


## warm_clips() and what follows it, on a FRESH character per entry of `ids`: the worst frame while `warm_list` is warmed
## (best attempt) and the cost of the first play of every clip of `play_list` afterwards (per clip the best attempt).
## {done, frames, wall_ms, worst_ms, all_worst_ms, warmed_worst_ms, warmed_best: {clip: ms}}.
static func measure_warm_suite(tree: SceneTree, objects: Node2D, ids: Array, warm_list: Array, play_list: Array) -> Dictionary:
	var all_worst: Array[float] = []
	var done_all := true
	var best_worst := INF
	var frames := 0
	var wall := 0.0
	var warmed := {}
	for id in ids:
		var probe = Chibi.create(str(id))
		objects.add_child(probe)
		for i in 3:
			await tree.process_frame
		var w: Dictionary = await measure_warm(tree, probe, warm_list)
		all_worst.append(float(w["worst_ms"]))
		done_all = done_all and bool(w["done"])
		if float(w["worst_ms"]) < best_worst:
			best_worst = float(w["worst_ms"])
			frames = int(w["frames"])
			wall = float(w["wall_ms"])
		for c in play_list:
			probe.play_loop(&"idle")
			await tree.process_frame
			await tree.process_frame
			var ms: float = await measure_first_play(tree, probe, StringName(str(c)), false)
			warmed[str(c)] = minf(float(warmed.get(str(c), INF)), ms)
		probe.queue_free()
		await tree.process_frame
	var warmed_worst := 0.0
	for c in warmed.keys():
		warmed_worst = maxf(warmed_worst, float(warmed[c]))
	return {"done": done_all, "frames": frames, "wall_ms": wall, "worst_ms": best_worst, "all_worst_ms": all_worst, "warmed_worst_ms": warmed_worst, "warmed_best": warmed}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="):
			tag = a.get_slice("=", 1)
		elif a == "--quick":
			quick = true
		elif a == "--cast":
			cast_mode = true
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _vram_mb() -> float:
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0


func _ram_mb() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0


## Average frame time over `secs` seconds (vsync off): measure_frames + the draw calls of the last frame.
func _measure(secs: float) -> Dictionary:
	var m: Dictionary = await measure_frames(get_tree(), secs, _vp)
	m["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return m


## One PERF line body. (The first version also printed Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS as "script process" and
## "physics": they showed 20-26 ms next to a 1.7 ms frame, i.e. nonsense for a frame time, so the columns are gone. The frame
## time, the render-server cpu/gpu time and the draw calls are the numbers that count.)
func _fmt(d: Dictionary) -> String:
	return "fps %.0f | frame %.2f ms (worst %.1f) | render cpu %.2f ms gpu %.2f ms | draw calls %d" % [
		d["fps"], d["ms"], d["worst_ms"], d["cpu_render_ms"], d["gpu_ms"], d["draw_calls"]]


## "PERF BUDGET OK|OVER|BUSY|n/a <name>: value (limit)". OVER on a quiet machine makes the run exit with code 1. BUSY = over
## budget while the machine is loaded (machine_load): not a verdict, the run then exits with code 3 ("inconclusive, rerun when quiet").
## A pass is always a pass: load only adds time.
func _budget(budget_name: String, value: float, limit: float) -> void:
	if DisplayServer.get_name() == "headless":
		print("PERF BUDGET n/a  %s: %.2f ms (limit %.1f ms; headless = dummy renderer, GPU cost is not measured)" % [budget_name, value, limit])
	elif value < limit:
		print("PERF BUDGET OK   %s: %.2f ms (limit %.1f ms)" % [budget_name, value, limit])
	elif bool(machine_load()["busy"]):
		print("PERF BUDGET BUSY %s: %.2f ms (limit %.1f ms) but the machine is busy (%s): not a verdict, rerun when quiet" % [budget_name, value, limit, machine_load()["text"]])
		_busy.append(budget_name)
	else:
		print("PERF BUDGET OVER %s: %.2f ms (limit %.1f ms; %s)" % [budget_name, value, limit, machine_load()["text"]])
		_over.append(budget_name)


## Ends the run: exit code 1 when a budget was over on a quiet machine, 3 when budgets were over on a busy one, 0 otherwise.
func _finish() -> void:
	if not _over.is_empty():
		print("PERF BUDGET RESULT OVER: %s" % ", ".join(_over))
		get_tree().quit(1)
	elif not _busy.is_empty():
		print("PERF BUDGET RESULT INCONCLUSIVE (machine busy): %s" % ", ".join(_busy))
		get_tree().quit(3)
	else:
		print("PERF BUDGET RESULT OK (every budget printed above is within its limit%s)" % (" or n/a in headless" if DisplayServer.get_name() == "headless" else ""))
		get_tree().quit(0)


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("PERF no image to save for ", shot_name, " (headless?)")
		return
	if out_dir == "":
		print("PERF (no --out=DIR: %s not saved)" % shot_name)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := "%s/%s_%s.png" % [out_dir, shot_name, tag]
	var err := img.save_png(path)
	print("PERF saved ", path, " (%dx%d)" % [img.get_width(), img.get_height()] if err == OK else " FAILED %d" % err)


func _clear_world(world: Dictionary) -> void:
	(world["root"] as Node).queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- the cast line-up

func _cast() -> void:
	var headless := DisplayServer.get_name() == "headless"
	print("=== CAST tag=%s renderer=%s adapter=%s window=%s" % [tag, RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), get_window().size])
	# 1. all 12 at game zoom, one row, south-east like the pack's own preview
	var w1 := make_world(self, GAME_ZOOM)
	var objects1: Node2D = w1["objects"]
	var step := Vector2(TILE_W * 2.0, 0.0)
	var ids: Array = PACK_IDS
	var first := Vector2(-step.x * (ids.size() - 1) * 0.5, 0)
	var row1 := place_cast(objects1, ids, first, step, ids.size(), SE, &"idle")
	(w1["camera"] as Camera2D).position = Vector2(0, -30)
	await _wait(0.8)
	await _save("cast_game_zoom")
	print("CAST game zoom %.1f: %d characters, rendered height of the pack figures about %d px" % [GAME_ZOOM, row1.size(), int(190.0 * GAME_ZOOM)])
	await _clear_world(w1)
	# 2. close-up 4x3 like docs/art/isometric_pack/isometric_previews/character_lineup_2d.png
	var w2 := make_world(self, 0.9)
	var objects2: Node2D = w2["objects"]
	var step2 := Vector2(330.0, 255.0)
	var origin2 := Vector2(-step2.x * 1.5, -161.0)
	place_cast(objects2, ids, origin2, step2, 4, SE, &"idle")
	(w2["camera"] as Camera2D).position = Vector2.ZERO
	await _wait(0.8)
	await _save("cast_closeup")
	await _clear_world(w2)
	# 3. all eight directions: fox walking on top, flying fairy below
	var w3 := make_world(self, 0.75)
	var objects3: Node2D = w3["objects"]
	var fox_ids: Array = []
	var fairy_ids: Array = []
	for d in 8:
		fox_ids.append("fox")
		fairy_ids.append("fairy")
	var step3 := Vector2(210.0, 0.0)
	var o3 := Vector2(-step3.x * 3.5, -150)
	var foxes := place_cast(objects3, fox_ids, o3, step3, 8, 0, &"walk")
	var fairies := place_cast(objects3, fairy_ids, o3 + Vector2(0, 300), step3, 8, 0, &"hover")
	for d in 8:
		foxes[d].set_direction_index(d)
		fairies[d].set_direction_index(d)
		fairies[d].set_altitude(40.0)
	(w3["camera"] as Camera2D).position = Vector2(0, 30)
	await _wait(0.8)
	await _save("cast_directions")
	await _clear_world(w3)
	if headless:
		print("CAST headless: no pixels (dummy renderer); only the scene construction was exercised")
	print("CAST done")


# ---------------------------------------------------------------- performance

func _run() -> void:
	if cast_mode:
		await _cast()
		get_tree().quit()
		return
	var headless := DisplayServer.get_name() == "headless"
	print("=== PERF tag=%s renderer=%s adapter=%s%s" % [tag, RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
		"  (HEADLESS: dummy renderer, script cost only)" if headless else ""])
	if not headless:
		uncap()
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	Engine.max_fps = 0
	var vr0 := _vram_mb()
	var rr0 := _ram_mb()
	var world := make_world(self, GAME_ZOOM)
	var objects: Node2D = world["objects"]
	await _wait(0.5)
	print("PERF P1 empty ground: ", _fmt(await _measure(3.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var made: Array = []
	var result := {}
	for n in [100, 200]:
		fill_crowd(objects, made, n, rng)
		await _wait(1.0)
		var m := await _measure(4.0)
		if n == 100:
			# the budget number: best of three more 2 s windows (see the NOISE RULE), the 4 s mean above stays as printed
			var b: Dictionary = await measure_frames_best(get_tree(), 2.0, ATTEMPTS, _vp)
			m["budget_ms"] = float(b["ms"])
			m["budget_all_ms"] = b["all_ms"]
		result[n] = m
		print("PERF P2 %d animated characters (walk/run, 8 dirs, y-sorted, linear mipmaps): %s" % [n, _fmt(m)])
	print("PERF RESULT characters=100 frame_ms=%.2f characters=200 frame_ms=%.2f (plan 8.6 budget: 100 characters < 8 ms on the M3 reference)" % [result[100]["ms"], result[200]["ms"]])
	print("PERF    100 characters, three 2 s windows (mean frame ms): %s" % str(result[100]["budget_all_ms"]))
	_budget("100 animated characters, mean frame (best of 3 windows)", float(result[100]["budget_ms"]), BUDGET_100_MS)
	var vr_after := _vram_mb()
	print("PERF memory: vram %.1f -> %.1f MB, ram %.1f -> %.1f MB" % [vr0, vr_after, rr0, _ram_mb()])
	if not headless and out_dir != "":
		await _save("perf_200")
	for v in made:
		v.queue_free()
	await _wait(0.3)
	if quick:
		_finish()
		return

	# P3: load time and texture memory of every sheet, loaded synchronously
	print("PERF P3 loading every sheet synchronously (12 characters x 11 clips + 2 fliers x 4 clips + 12 portraits)...")
	var total_ms := 0.0
	var worst_ms := 0.0
	var sheets := 0
	var vram_before := _vram_mb()
	var cache: Array = []
	for id in PACK_IDS:
		var clips: Array = CLIPS_STD.duplicate()
		if id in ["bat", "fairy"]:
			clips.append_array(CLIPS_FLY)
		for clip in clips:
			var t1 := Time.get_ticks_usec()
			var tex := load("res://assets/isometric_characters/%s/%s.webp" % [id, clip]) as Texture2D
			var ms := float(Time.get_ticks_usec() - t1) / 1000.0
			total_ms += ms
			worst_ms = maxf(worst_ms, ms)
			sheets += 1
			cache.append(tex)
		cache.append(load("res://assets/isometric_characters/%s/portrait.webp" % id))
	await get_tree().process_frame
	await get_tree().process_frame
	print("PERF    %d sheets loaded in %.0f ms (avg %.1f ms, worst %.1f ms)" % [sheets, total_ms, total_ms / maxf(sheets, 1), worst_ms])
	print("PERF    texture memory (render server): %.1f -> %.1f MB (+%.1f MB = %.1f MB per character)" % [vram_before, _vram_mb(), _vram_mb() - vram_before, (_vram_mb() - vram_before) / PACK_IDS.size()])
	var rgba_bytes := 0
	for tex in cache:
		rgba_bytes += int((tex as Texture2D).get_width()) * int((tex as Texture2D).get_height()) * 4
	print("PERF    analytic RGBA8 size of everything loaded: %.1f MB (S3TC is a quarter of it, plus 1/3 for mipmaps)" % (rgba_bytes / 1048576.0))
	cache.clear()
	await _wait(0.5)

	# P4: first use of an unloaded clip (sync load inside _sync_sprite) versus warm_clips(); fresh characters per attempt
	print("PERF P4 first use of a clip (three fresh characters per measurement, best per clip)")
	var cold: Dictionary = await measure_cold_first_play(get_tree(), objects, ["penguin", "bear", "raccoon"], ["walk", "run", "celebrate", "interact", "talk"], ["celebrate", "interact"])
	for clip in cold["all"].keys():
		print("PERF    unwarmed first play of '%s': %s ms (best %.1f)" % [clip, ", ".join(PackedStringArray((cold["all"][clip] as Array).map(func(v): return "%.1f" % v))), cold["best"][clip]])
	_budget("unwarmed first play of a clip, slowest clip at its best", float(cold["worst_ms"]), BUDGET_UNWARMED_MS)
	var wsuite: Dictionary = await measure_warm_suite(get_tree(), objects, ["rabbit", "cat", "frog"], WARM_LIST, WARM_PLAY_LIST)
	print("PERF    warm_clips(5 clips) finished in %.0f ms wall time over %d frames, worst frame %.1f ms (all attempts: %s)" % [wsuite["wall_ms"], wsuite["frames"], wsuite["worst_ms"], str(wsuite["all_worst_ms"])])
	_budget("worst frame while warm_clips runs (best of 3 characters)", float(wsuite["worst_ms"]), BUDGET_WARM_FRAME_MS)
	for clip in wsuite["warmed_best"].keys():
		print("PERF    after warm_clips: first play of '%s': frame took %.1f ms (best of 3)" % [clip, wsuite["warmed_best"][clip]])
	_budget("first play after warm_clips, slowest clip at its best", float(wsuite["warmed_worst_ms"]), BUDGET_WARMED_MS)
	if not bool(wsuite["done"]):
		_over.append("warm_clips did not finish")
		print("PERF BUDGET OVER warm_clips did not finish within 20 s")
	_finish()
