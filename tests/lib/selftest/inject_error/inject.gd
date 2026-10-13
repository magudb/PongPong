extends RefCounted
## Harness self-test (NEGATIVE): an injected engine error must make the run fail.
const SECTION := "inject"

func run(t) -> void:
	t.check("before", true)
	push_error("INJECTED-ENGINE-ERROR from the harness self-test")
	await t.frames(1)
	t.check("after", true, "checks keep running; the run still fails")
