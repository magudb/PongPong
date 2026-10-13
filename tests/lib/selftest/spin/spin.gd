extends RefCounted
## Harness self-test (NEGATIVE): a section stuck in a SYNCHRONOUS loop blocks every timer, so no in-process watchdog
## can fire. Only the wrapper's external timeout (tests/run_playtest.sh --timeout=N) stops it (exit 124).
const SECTION := "spin"

func run(t) -> void:
	t.check("started", true)
	await t.frames(1)
	var n := 0
	while true:
		n += 1
