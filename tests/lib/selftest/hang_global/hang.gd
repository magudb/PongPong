extends RefCounted
## Harness self-test (NEGATIVE): no TIMEOUT_S here, so only the whole-run watchdog (--max-seconds) can stop this.
const SECTION := "hang_global"

func run(t) -> void:
	t.check("started", true)
	await t.until(func() -> bool: return false, 600.0)
	t.check("never_reached", true)
