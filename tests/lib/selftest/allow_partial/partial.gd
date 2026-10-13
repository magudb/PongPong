extends RefCounted
## Harness self-test (NEGATIVE): allow() only covers what it names; any other message still fails the run.
const SECTION := "partial"

func run(t) -> void:
	t.allow("EXPECTED-ONLY-THIS")
	push_warning("EXPECTED-ONLY-THIS is fine")
	push_warning("SOMETHING-ELSE-UNEXPECTED is not")
	await t.frames(1)
	t.check("end", true)
