extends Node
## Stands in for the SocialManager autoload in the towns tests (package T-towns-core): the three calls of the S track's contract that the towns track reads
## (TOWNS addendum 8.8): festival_today() -> id, override_for(npc, total_day, hour) -> {area, post, state} | {}, shop_closed_by_festival(shop_id) -> bool; plus hearts(npc).
## Inject it with Svc.override("SocialManager", fake) and take it away with Svc.clear_overrides(); the fake only has to offer the methods the caller uses.

var festival: String = ""
var closed_shops: Array = []
var overrides: Dictionary = {}          # npc id -> {area, post, state}
var hearts_table: Dictionary = {}       # npc id -> whole hearts
var calls: Array = []                   # "method:arg" per call, for the tests


func festival_today() -> String:
	calls.append("festival_today")
	return festival


func festival_active() -> String:
	return festival


func shop_closed_by_festival(shop_id: String) -> bool:
	calls.append("shop_closed_by_festival:%s" % shop_id)
	return shop_id in closed_shops


func override_for(npc: String, _total_day: int, _hour: float) -> Dictionary:
	calls.append("override_for:%s" % npc)
	return (overrides.get(npc, {}) as Dictionary).duplicate()


func hearts(npc: String) -> int:
	calls.append("hearts:%s" % npc)
	return int(hearts_table.get(npc, 0))
