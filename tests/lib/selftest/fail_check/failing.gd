extends RefCounted
## Harness self-test: a failed check must fail the run (exit 1) and be listed as <section>.<label>.
const SECTION := "failing"

func run(t) -> void:
	t.check("this_one_passes", true)
	t.check("this_one_fails", false, "deliberate")
	t.expect(1 == 2, "this free-text check fails too")
