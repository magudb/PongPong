extends RefCounted
## Harness self-test: runs after a_stuck timed out, with a fresh t; it releases the condition the stuck section waits on.
const SECTION := "b_next"

func run(t) -> void:
	t.check("runs_after_a_timeout", true)
	t.check("gets_a_fresh_t", not t.detached and t.section == "b_next")
	Engine.set_meta(&"st_release_the_stuck_section", true)
	await t.frames(5)
	t.check("the_stuck_section_stays_parked", true, "the stuck section printed nothing after its timeout")
