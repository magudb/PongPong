extends RefCounted
## NEGATIVE: the allow() of the previous section must not leak into this one.
const SECTION := "b_leak"

func run(t) -> void:
	push_warning("SCOPED-WARNING in a section that did NOT allow it")
	await t.frames(1)
	t.check("end", true)
