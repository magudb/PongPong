extends RefCounted
## Harness self-test: runs after a_late timed out and wakes it; the late lines of a_late land in this section's output but not
## in its counts.
const SECTION := "b_next"

func run(t) -> void:
	Engine.set_meta(&"st_wake_the_late_section", true)
	await t.frames(5)
	Engine.remove_meta(&"st_wake_the_late_section")
	t.check("own_counts_only", int(t.stats["b_next"]["checks"]) == 0 and int(t.stats["b_next"]["failed"]) == 0 and int(t.stats["b_next"]["skipped"]) == 0, t.stats["b_next"])
