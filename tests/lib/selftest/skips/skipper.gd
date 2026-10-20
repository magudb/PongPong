extends RefCounted
## Harness self-test: a section that skips two checks, against the budget files next to it (--skip-budget=...).
const SECTION := "skipper"

func run(t) -> void:
	t.check("ran", true)
	t.skip("first skipped check")
	t.skip("second skipped check")
