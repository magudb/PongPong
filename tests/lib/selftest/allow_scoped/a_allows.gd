extends RefCounted
const SECTION := "a_allows"

func run(t) -> void:
	t.allow("SCOPED-WARNING")
	push_warning("SCOPED-WARNING inside the section that allowed it")
	await t.frames(1)
	t.check("allowed_here", true)
