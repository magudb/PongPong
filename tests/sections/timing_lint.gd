extends RefCounted
## The timing policy of tests/lib/t.gd (TEST-02, TEST-03): the lint over every section (tests/tools/timing_lint.py: a wall-clock budget
## goes through t.perf_ok(), no frame-count wait ends in t.fail()) and the two helpers the policy asks for, t.until_game() and t.median_usec().
const SECTION := "timing_lint"

func run(t) -> void:
	t.check("software_renderers_do_not_claim_hardware_timings", ["llvmpipe (LLVM 20.1.2, 256 bits)", "softpipe", "lavapipe", "Google SwiftShader"].all(func(adapter: String) -> bool: return t.software_renderer(adapter)))
	t.check("hardware_renderers_keep_their_budgets", ["Apple M3", "NVIDIA GeForce RTX 4060", "AMD Radeon RX 7600", "Mesa Intel(R) UHD Graphics"].all(func(adapter: String) -> bool: return not t.software_renderer(adapter)))
	var lint: Dictionary = t.run_tool("python3", ["-I", ProjectSettings.globalize_path("res://tests/tools/timing_lint.py"), ProjectSettings.globalize_path("res://")])
	t.expect_tool_ids(lint, "Timing lint")
	if int(lint.code) != 0:
		t.info(str(lint.output))
	# until_game: true as soon as the condition holds, `each` runs every frame before the poll
	var box := {"frames": 0}
	var counted: bool = await t.until_game(func() -> bool: return box.frames >= 5, 10.0, func() -> void: box.frames += 1)
	t.check("until_game_returns_when_the_condition_holds", counted and box.frames == 5, "%d frames" % box.frames)
	# ... and false only after the bound has passed in GAME time, however many frames that is
	var started: float = t.game_seconds()
	var never: bool = await t.until_game(func() -> bool: return false, 0.25)
	var waited: float = t.game_seconds() - started
	t.check("until_game_gives_up_after_game_time", not never and waited >= 0.25 and waited < 5.0, "gave up after %.3f game seconds (bound 0.25)" % waited)
	# median_usec: one preempted batch (a 50 ms stall) does not move the result
	var calls := {"n": 0}
	var work := func() -> void:
		calls.n += 1
		if calls.n == 1:
			OS.delay_usec(50000)
	var stalled: float = t.median_usec(work, 5, 10)
	t.check("median_usec_ignores_one_stalled_batch", calls.n == 50 and stalled < 1000.0, "%d calls, median %.1f us per call (the stalled batch averages 5000 us)" % [calls.n, stalled]) # raw-time-ok: tests the helper itself, a 50x margin
	# perf_ok: inside the reference passes quietly, over the runner limit fails, except on an overloaded scaled local run (not judged)
	t.check("perf_ok_passes_inside_the_reference", t.perf_ok("perf_ok_probe", 1.0, 2.0))
	var load: Dictionary = t.machine_overloaded()
	var exempt: bool = t.not_judged(t.perf_limit(2.0) + 0.001, t.perf_limit(2.0), t.perf_scaled(), t.on_ci(), bool(load.overloaded))
	var judged_before: int = t.not_judged_count()
	var over: bool = t.perf_ok("perf_ok_probe", t.perf_limit(2.0) + 0.001, 2.0)
	var not_judged: int = t.not_judged_count() - judged_before
	t.check("perf_ok_fails_past_the_runner_limit", over == exempt and not_judged == (1 if exempt else 0), "runner limit %.1f for a reference of 2, %s, scaled %s, CI %s: passed %s, not judged %d" % [t.perf_limit(2.0), load.text, t.perf_scaled(), t.on_ci(), over, not_judged])
	if exempt:
		t.slow.pop_back() # the probe is not a timing of the game: keep it out of the summary
	# ... and who may skip the verdict: only a scaled local run on an overloaded machine, up to OVERLOAD_CEILING x the limit
	var ceiling: float = 8.0 * t.OVERLOAD_CEILING
	t.check("not_judged_only_overloaded_scaled_local_runs", t.not_judged(9.0, 8.0, true, false, true) and not t.not_judged(9.0, 8.0, true, false, false) and not t.not_judged(9.0, 8.0, false, false, true) and not t.not_judged(9.0, 8.0, true, true, true), "overloaded scaled local run: not judged; a quiet machine, an unscaled (native or windowed) run and a CI job judge")
	t.check("not_judged_has_a_ceiling", t.not_judged(ceiling, 8.0, true, false, true) and not t.not_judged(ceiling + 0.001, 8.0, true, false, true), "past %.1fx the runner limit a timing fails under any load" % t.OVERLOAD_CEILING)
