extends RefCounted
## Harness self-test (NEGATIVE): a warning fails the run as well (plan 8.1: errors AND warnings).
const SECTION := "inject_warning"

func run(t) -> void:
	push_warning("INJECTED-ENGINE-WARNING from the harness self-test")
	await t.frames(1)
	t.check("after", true)
