extends RefCounted
## Harness self-test (NEGATIVE): a section that hangs on an await that is not a wait helper of `t` (here a bare process frame
## loop, like a game method's own timer loop). It times out; when it wakes up after that, its checks print as `late` lines that
## count nowhere, and its next t wait parks it for good.
const SECTION := "a_late"
const TIMEOUT_S := 2.0

func run(t) -> void:
	t.check("started", true)
	while not Engine.has_meta(&"st_wake_the_late_section"):
		await t.tree.process_frame
	t.check("late_check_after_the_timeout", true)
	t.fail("late failure after the timeout")
	t.skip("late skip after the timeout")
	t.check("late_timing", t.perf_ok("late_timing", 10.0, 1.0))
	await t.frames(1)
	print("ZOMBIE-RAN-ON")
	t.check("never_reached", true)
