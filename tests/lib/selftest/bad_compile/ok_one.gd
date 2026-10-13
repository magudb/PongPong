extends RefCounted
const SECTION := "ok_one"

func run(t) -> void:
	t.check("fine", true)
