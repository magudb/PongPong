class_name ShopHoursGate
extends RefCounted
## RT5 (P12 fix round): the ONE place where ShopSystem asks the towns track's opening-hours rule (scripts/towns/hours.gd, class Hours,
## T-towns-core, wave 4). The opening hours are NOT shop def fields: they live in the buildings registry (decision DT12), the rule is
## Hours.shop_open(shop_id) -> true | false | null (null = no building claims the shop). This file only ASKS; it compares no hour itself,
## so the 26 hour game day (docs/design/CLOCK_26_ADDENDUM.md: raw game hours 6..25, `close < open` = after midnight, GameManager.game_hour())
## is Hours' business and ShopSystem needs no clock knowledge. A festival closes a shop inside that rule (it asks
## SocialManager.shop_closed_by_festival(shop_id) first): neither this helper nor ShopSystem knows festivals.
##
## Why a helper file and not code in shop_system.gd: ShopSystem keeps exactly TWO Svc.static_call lines (ShopRotation.stock and
## PriceCurve.final_price, pinned by economy.late_binding_via_svc); the hours rule is the third late-bound script, so its ONE call
## site lives here. LATE BINDING (RV-P10, plan Appendix B): Hours is reached through Svc.static_call by path, never by class name (a
## direct reference is a parse error until T-towns-core landed and an --import ran); with scripts/towns absent this file compiles
## and every answer is "no rule" (null / {}), so the def's own open_weekdays decide alone.
##
## THE SWITCH (DT55): the config key towns.hours_enabled (default true; GameManager.set_config_override in a test) turns the rule OFF
## for the sections that are not about opening hours; with it false the rule is not even asked (open_override null, closed_info {}).
##
## THE CONTRACT with the towns track (what Hours must answer, nothing else is read):
##   res://scripts/towns/hours.gd  static func shop_open(shop_id: String) -> Variant      true | false | null
##   res://scripts/towns/hours.gd  static func closed_info(shop_id: String) -> Dictionary  {reason | closed_reason, opens_at, next_weekday | next_open_weekday} (+ open)
## closed_info() here normalises that answer to the three keys the shop screen reads (see closed_info).

const _Svc := preload("res://scripts/data/svc.gd")

const HOURS_SCRIPT := "res://scripts/towns/hours.gd"
const SWITCH := "towns.hours_enabled"

## where the rule is looked up: the contract's path; a test points it at a probe script under user:// (use_hours_script)
static var _hours_script: String = HOURS_SCRIPT


## TEST SEAM: another script path for the rule (a probe under user://); no argument = the contract's path again.
static func use_hours_script(path: String = HOURS_SCRIPT) -> void:
	_hours_script = path


## The rule is switched on (config towns.hours_enabled, default true).
static func enabled() -> bool:
	var gm: Node = _Svc.node("GameManager")
	return gm == null or bool(gm.call("config_value", SWITCH, true))


## true | false | null. null = the rule does not apply (towns track absent, switch off, or no building claims the shop): the def's
## open_weekdays decide alone (the flea market's open_weekdays 5, 6 keep working). true / false = the buildings decide (an open
## building overrules the def's weekday list: the buildings registry is the one place that holds opening hours).
static func open_override(shop_id: String) -> Variant:
	if not enabled():
		return null
	var answer: Variant = _Svc.static_call(_hours_script, &"shop_open", [shop_id], null)
	return bool(answer) if answer != null else null


## Why a closed shop is closed: {closed_reason: String ("hours" | "day" | "festival"), opens_at: float (game hour, the 6..26 axis),
## next_open_weekday: int (0 = Monday)}; {} when the rule does not apply, the shop is open, or the rule has nothing to say.
## The towns rule's own state names (reason, next_weekday) are accepted as well; a number it does not give is left out.
static func closed_info(shop_id: String) -> Dictionary:
	if not enabled():
		return {}
	var raw: Variant = _Svc.static_call(_hours_script, &"closed_info", [shop_id], null)
	if not (raw is Dictionary):
		return {}
	var state: Dictionary = raw
	var reason := str(state.get("closed_reason", state.get("reason", "")))
	if bool(state.get("open", false)) or reason == "" or reason == "open" or reason == "none":
		return {}
	var out := {"closed_reason": reason}
	var opens: Variant = state.get("opens_at", null)
	if opens is int or opens is float:
		out["opens_at"] = float(opens)
	var next_day: Variant = state.get("next_open_weekday", state.get("next_weekday", null))
	if next_day is int or next_day is float:
		out["next_open_weekday"] = int(next_day)
	return out
