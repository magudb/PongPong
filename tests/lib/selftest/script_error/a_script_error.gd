extends RefCounted
## Harness self-test (NEGATIVE): a GDScript runtime error inside the section ends the section but never hangs
## the run; the error fails it and the next section still runs.
const SECTION := "a_script_error"

func run(t) -> void:
	await t.frames(1)
	var nothing = null
	nothing.no_such_method()
	t.check("AFTER_ERROR_SHOULD_NOT_RUN", true)
