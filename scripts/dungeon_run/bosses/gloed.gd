extends RefCounted
static func next(boss) -> String:
	return "cloud" if boss.hp <= boss.max_hp*.5 and boss.cycle % 3 == 0 else "quake" if boss.cycle % 2 == 0 else "dash"
