extends RefCounted
## Harness self-test of the watchdogs under `run_playtest.sh --fast` (--fixed-fps 60): the section waits 1.5 WALL-CLOCK seconds, frame by frame, the way
## UiAudit's settle loops do. Under --fast a frame costs a fraction of a millisecond, so 1.5 s of wall time are thousands of frames, i.e. well over 5 GAME
## seconds: a watchdog that counted game time would stop this section (TIMEOUT_S 5) and the run (--max-seconds=8: the engine start-up alone takes 2-3 s on a busy machine) although nothing is stuck.
const SECTION := "wall_wait"
const TIMEOUT_S := 5.0
const WALL_MS := 1500


func run(t) -> void:
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - t0 < WALL_MS:
		await t.frames(1)
		frames += 1
	t.check("waited_on_the_wall_clock", true, "%d frames in %d ms" % [frames, Time.get_ticks_msec() - t0])
