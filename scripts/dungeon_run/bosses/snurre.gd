extends RefCounted
static func next(boss) -> String:
	return "puff" if boss.cycle % 3 == 0 else "dash"
