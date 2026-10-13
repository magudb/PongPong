extends RefCounted
## Harness self-test (NEGATIVE): a section that waits forever is stopped by its own TIMEOUT_S and fails the run.
const SECTION := "hang"
const TIMEOUT_S := 2.0

func run(t) -> void:
	t.check("started", true)
	await t.until(func() -> bool: return false, 600.0)
	t.check("never_reached", true)
