class_name LoopClock
extends RefCounted
## Advance through production time/day paths, including their signals and fades.
static func settle(t) -> void:
	await t.until(func(): return t.world() != null and not t.world().traveling and not t.world().sleeping, 8)
	await t.physics(2)

static func to(t, hour: int, minute := 0) -> void:
	var gm: Node = t.autoload("GameManager")
	var target := hour * 60 + minute
	var now: int = gm.hour * 60 + gm.minute
	if target < now:
		await next_day(t)
		now = gm.hour * 60 + gm.minute
	gm.advance_time(maxi(0, target - now))
	await settle(t)

static func at(t, weekday: int, hour: int, minute := 0) -> void:
	for i in 8:
		var gm: Node = t.autoload("GameManager")
		if CalendarUtil.weekday_of(t.autoload("SocialManager").today()) == weekday and gm.hour * 60 + gm.minute <= hour * 60 + minute:
			break
		await next_day(t)
	await to(t, hour, minute)

static func next_day(t) -> void:
	t.autoload("GameManager").end_day()
	await settle(t)

static func bed_sleep(t) -> bool:
	var beds: Array = t.world().area.find_markers("bed")
	if beds.is_empty() or not beds[0].get("node") is Interactable2D:
		return false
	var day: int = t.autoload("GameManager").total_day()
	beds[0].node.interact(t.player())
	await settle(t)
	return t.autoload("GameManager").total_day() == day + 1
