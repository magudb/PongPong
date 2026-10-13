extends RefCounted
## Harness self-test: the section name comes from SECTION, not from the file name; TIMEOUT_S is honoured.
const SECTION := "second_named"
const TIMEOUT_S := 45.0

func run(t) -> void:
	t.expect_eq(t.section, "second_named", "t.section is the SECTION constant")
	t.check("runs_after_a_basics", true, "alphabetical file order: a_basics.gd before second_named.gd")
