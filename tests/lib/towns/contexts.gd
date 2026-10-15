extends RefCounted
## Context builders of the towns tests (package T-towns-core): a Hours context at a weekday and an hour, and the real game clock set to the same moment.
## Weekdays count from 0 = Monday; hours are GAME HOURS on the axis 6..26 (25.5 = 01:30 of the same game day). Reused by T-routes and T-director.


## A Hours context (the shape of Hours.now_ctx()): {weekday, hour, season, total_day, weather} plus `extra` (fest_closed_fn, hearts ...).
static func at(weekday: int, hour: float, extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"weekday": weekday, "hour": hour, "season": "foraar", "total_day": 1 + weekday, "weather": "klart"}
	c.merge(extra, true)
	return c


## The real GameManager clock at a weekday (0 = Monday, day 1 of foraar year 1 is a Monday) and a game hour (raw 6..25.99).
static func set_clock(gm: Node, weekday: int, hour: float) -> void:
	gm.set("day", 1 + weekday)
	gm.set("season", &"foraar")
	gm.set("year", 1)
	gm.set("hour", int(floor(hour)))
	gm.set("minute", int(round((hour - floor(hour)) * 60.0)))


## A registry (building id -> row) from a Dictionary written in code (the tests build rows inline).
static func registry(rows: Dictionary) -> Dictionary:
	return rows.duplicate(true)
