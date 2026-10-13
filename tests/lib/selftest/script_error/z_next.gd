extends RefCounted
const SECTION := "z_next"

func run(t) -> void:
	t.check("next_section_still_runs", true)
