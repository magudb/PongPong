extends RefCounted
## The timing policy of tests/lib/t.gd (TEST-02, TEST-03): the lint over every section (tests/tools/timing_lint.py: a wall-clock budget
## goes through t.perf_ok(), no frame-count wait ends in t.fail()) and the two helpers the policy asks for, t.until_game() and t.median_usec().
const SECTION := "timing_lint"

func run(t) -> void:
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
	# perf_ok: inside the reference passes quietly, over the runner limit fails, except on an overloaded machine (not judged)
	t.check("perf_ok_passes_inside_the_reference", t.perf_ok("perf_ok_probe", 1.0, 2.0))
	var load: Dictionary = t.machine_overloaded()
	var overloaded: bool = load.overloaded
	var judged_before: int = t.slow.filter(func(row) -> bool: return not bool(row.get("judged", true))).size()
	var over: bool = t.perf_ok("perf_ok_probe", t.perf_limit(2.0) + 0.001, 2.0)
	var not_judged: int = t.slow.filter(func(row) -> bool: return not bool(row.get("judged", true))).size() - judged_before
	t.check("perf_ok_fails_past_the_runner_limit", over == overloaded and not_judged == (1 if overloaded else 0), "runner limit %.1f for a reference of 2, %s: passed %s, not judged %d" % [t.perf_limit(2.0), load.text, over, not_judged])
	if overloaded:
		t.slow.pop_back() # the probe is not a timing of the game: keep it out of the summary
