extends RefCounted
## Harness self-test of `tests/run_playtest.sh --fast`: measures what the flag is for. 300 physics ticks are 5 game seconds at the project's
## 60 ticks per second; the engine waits for the wall clock between ticks unless it runs with `--fixed-fps 60` (the engine strips that
## argument from OS.get_cmdline_args, so the effect is the only evidence there is). The section prints one machine-readable line,
## `FASTPROBE ticks=<n> wall_ms=<n>`, which tools/dev/selftest_harness.sh matches: about 5000 ms without the flag, a few ms with it.
const SECTION := "fast_probe"
const TICKS := 300


func run(t) -> void:
	var p0 := Engine.get_physics_frames()
	var g0: float = t.game_seconds()
	var t0 := Time.get_ticks_msec()
	await t.physics(TICKS)
	var wall := Time.get_ticks_msec() - t0
	var ticks := Engine.get_physics_frames() - p0
	var game: float = t.game_seconds() - g0
	t.check("ran_the_ticks", ticks >= TICKS, "%d physics ticks ran" % ticks)
	t.expect_near(game, float(TICKS) / 60.0, 0.05, "game_seconds() measures 5 game seconds with or without --fast (wall %d ms)" % wall)
	print("FASTPROBE ticks=%d wall_ms=%d" % [ticks, wall])
