extends RefCounted
## Harness self-test (NEGATIVE): a section that hangs fails the run after its TIMEOUT_S, but the sections after it still run,
## and the stuck coroutine stays parked when its wait would end (it must not run on into the next section).
const SECTION := "a_stuck"
const TIMEOUT_S := 2.0

func run(t) -> void:
	t.check("started", true)
	await t.until(func() -> bool: return Engine.has_meta(&"st_release_the_stuck_section"), 600.0)
	print("ZOMBIE-RAN-ON")
	t.check("never_reached", true)
