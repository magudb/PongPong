extends RefCounted
## Harness self-test: a message listed in the known-issues file is tolerated (and printed as KNOWN); with --strict
## the very same message fails the run.
const SECTION := "known_issue"

func run(t) -> void:
	push_warning("KNOWN-ISSUE-SELFTEST this tree has a documented problem")
	await t.frames(1)
	t.check("section_itself_is_fine", true)
