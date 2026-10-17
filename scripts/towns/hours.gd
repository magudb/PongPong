class_name Hours
extends RefCounted
## OPENING HOURS of every building with a keeper (T-towns-core, TOWNS addendum 4.5 / DT12, edited for CLOCK_26 and for wave 4).
## Data: the registry `buildings` (lua/buildings/*.lua): hours = { open, close, closed = { weekdays, 0 = Monday }, overrides = { { weekday = { .. }, open, close } }, short_ok }.
## ONE rule for the door (Door2D), the shop (ShopSystem.is_open through ShopHoursGate -> shop_open), the closing whisper and the eviction (ShopHours).
##
## THE CLOCK (docs/design/CLOCK_26_ADDENDUM.md, CK-A-TC): every hour is a float of GAME HOURS on the axis 6..26. The game day runs 06:00 to 02:00; the raw hours 24 and 25 belong to the
## SAME game day (same weekday, same festival, same opening day) and print 00:xx and 01:xx; `close < open` is the after-midnight notation (close 1 = 25.0 = 01:00, close 0 = 24.0), mapped
## onto the axis by GameManager.game_hour() (the ONE normaliser). `inside = hour >= open and hour < close` is tested on the RAW hour, so a shop that closes at 25.5 is open at 24:30 and
## shut at 25:30, and a plain 17:00 close is shut at 24:30 (the old wrap `hour >= o or hour < c` would have kept a night shop open until 26:00). The weekday is the game day's
## (TimeManager.weekday_index): a Friday shop that closes at 25.5 is still a Friday shop at 00:30.
##
## A festival closes a shop ONLY through ctx.fest_closed_fn(shop_id) (production: SocialManager.shop_closed_by_festival, late bound; no social track = nothing closes): the festival def's
## `closes` / `stays_open` is the one place that decides, not the building. An empty Lua table arrives as a Dictionary (or an Array) and means NO days.
##
## Wave 4 has no Routines: Hours has its OWN clock-only context (now_ctx); Routines.now_ctx of T-routes (wave 5) EXTENDS it with hero and hearts. Nothing here names a class of a later wave.
## The switch: config towns.hours_enabled (default true). While it is false shop_open answers null (no rule) and the sections that are not about hours run as if the rule did not exist (DT55).

const _Svc := preload("res://scripts/data/svc.gd")

## Where the citizens' routine facade lives (T-routes, wave 5): reached ONLY as a path string through Svc.static_call, never by class name (TE1).
const ROUTINES_PATH := "res://scripts/towns/routines.gd"
## Tests point the rule at their own registry (a Dictionary building id -> row); empty = the real registry of LuaRuntime.
static var override_registry: Dictionary = {}
## Tests point the routines facade at a stand-in script (a path); the default is the real file.
static var routines_path: String = ROUTINES_PATH


# ------------------------------------------------------------------------------------------------ context and switch

## The CLOCK-ONLY context of the rule: {weekday (0 = Monday), hour (raw game hour as a float, 6..25.99), season, total_day, weather, fest_closed_fn}. GameManager, TimeManager and
## SocialManager are read late bound; without them the context is Monday 06:00, foraar, klart. Routines.now_ctx() extends this with hero and hearts.
static func now_ctx() -> Dictionary:
	var c: Dictionary = {"weekday": 0, "hour": 6.0, "season": "foraar", "total_day": 1, "weather": "klart"}
	var gm: Node = GameData.gm()
	var tm: Node = GameData.tm()
	if gm != null:
		c["hour"] = float(gm.get("hour")) + float(gm.get("minute")) / 60.0
		c["total_day"] = int(gm.call("total_day"))
		c["season"] = str(gm.get("season"))
	if tm != null:
		c["weekday"] = int(tm.call("weekday_index"))
		c["weather"] = str(tm.get("weather"))
	var sm: Node = _Svc.node("SocialManager")
	if sm != null and sm.has_method("shop_closed_by_festival"):
		c["fest_closed_fn"] = Callable(sm, "shop_closed_by_festival")
	return c


## The ONE switch of the opening-hours rule (config towns.hours_enabled, production default true).
static func enabled() -> bool:
	return bool(GameData.cfg("towns.hours_enabled", true))


# ------------------------------------------------------------------------------------------------ the registry

static func registry() -> Dictionary:
	if not override_registry.is_empty():
		return override_registry
	var lr: Node = GameData.lua()
	return lr.call("get_registry", "buildings") if lr != null and lr.has_method("get_registry") else {}


## The row of a building ({} when the registry does not know the id).
static func building(id: String) -> Dictionary:
	var row: Variant = registry().get(id, {})
	return row as Dictionary if row is Dictionary else {}


## Every building with hours that claims the shop: the workshop and the Torvet stall are ONE shop (timber_yard), so a shop is open when ANY of them is.
static func buildings_of_shop(shop_id: String) -> Array[String]:
	var out: Array[String] = []
	var reg: Dictionary = registry()
	for id in reg:
		var row: Variant = reg[id]
		if row is Dictionary and str((row as Dictionary).get("shop", "")) == shop_id and (row as Dictionary).has("hours"):
			out.append(str(id))
	return out


## The first building with hours that claims the shop ("" = none). A shop with two buildings answers through buildings_of_shop.
static func building_of_shop(shop_id: String) -> String:
	var all: Array[String] = buildings_of_shop(shop_id)
	return all[0] if not all.is_empty() else ""


# ------------------------------------------------------------------------------------------------ the rule

## [open, close] of a building on a weekday on the GAME-HOUR AXIS: the base hours unless an `overrides` row names the weekday; close < open is after midnight (close + 24).
## A row without hours answers [day start, day end].
static func hours_on(b: Dictionary, wd: int) -> Array:
	var h: Variant = b.get("hours", {})
	if not (h is Dictionary) or (h as Dictionary).is_empty():
		return [float(_day_start()), float(_day_end())]
	var hd: Dictionary = h
	var raw_open: float = float(hd.get("open", float(_day_start())))
	var raw_close: float = float(hd.get("close", float(_day_end())))      # the default close of an hours row is the end of the game day
	for ov in _rows(hd.get("overrides", [])):
		if wd in _ints((ov as Dictionary).get("weekday", [])):
			raw_open = float((ov as Dictionary).get("open", raw_open))
			raw_close = float((ov as Dictionary).get("close", raw_close))
			break
	var o: float = _game_hour(raw_open)
	var c: float = _game_hour(raw_close)
	var c2: float = c + 24.0 if c < o else c
	return [o, c2]


## {open: bool, reason: "open" | "hours" | "day" | "festival" | "none", opens_at: float, closes_at: float, next_weekday: int}. "none" = the building has no hours (always open: a home, a decor hut,
## a service of the story). opens_at / closes_at are game hours on the 6..26 axis; when closed they describe the NEXT opening (today's before the opening hour, else the next open weekday's),
## closes_at is that day's close. next_weekday is the weekday of that opening (0 = Monday).
static func state(building_id: String, ctx: Dictionary = {}) -> Dictionary:
	var c: Dictionary = ctx if not ctx.is_empty() else now_ctx()
	var b: Dictionary = building(building_id)
	var wd: int = int(c.get("weekday", 0))
	var h: Variant = b.get("hours", {})
	if not (h is Dictionary) or (h as Dictionary).is_empty():
		return {"open": true, "reason": "none", "opens_at": float(_day_start()), "closes_at": float(_day_end()), "next_weekday": wd}
	var hour: float = float(c.get("hour", 12.0))
	var today: Array = hours_on(b, wd)
	var o: float = float(today[0])
	var c2: float = float(today[1])
	var closed: Array = closed_days(b)
	var res: Dictionary = {"open": false, "reason": "day", "opens_at": o, "closes_at": c2, "next_weekday": wd}
	var fc: Variant = c.get("fest_closed_fn", null)
	if fc is Callable and (fc as Callable).is_valid() and bool((fc as Callable).call(str(b.get("shop", building_id)))):
		res["reason"] = "festival"
		return res
	if wd in closed:
		_point_at_next_opening(res, b, wd, closed)
		return res
	if hour < o:
		res["reason"] = "hours"
		return res
	if hour >= c2:
		res["reason"] = "hours"
		_point_at_next_opening(res, b, wd, closed)
		return res
	res["open"] = true
	res["reason"] = "open"
	return res


static func is_open(building_id: String, ctx: Dictionary = {}) -> bool:
	return bool(state(building_id, ctx)["open"])


## The late-bound hook of ShopSystem.is_open (through ShopHoursGate): true | false | null. null = the rule does not apply: the switch is off, or no building with hours claims the shop
## (the def's own weekday rule decides alone, so `flea_market open_weekdays 5, 6` keeps working). A shop claimed by several buildings is open when any of them is.
static func shop_open(shop_id: String, ctx: Dictionary = {}) -> Variant:
	if not enabled():
		return null
	var social := _Svc.node("SocialManager")
	if social != null and social.has_method("festival_shop_state"):
		var stall: Variant = social.call("festival_shop_state",shop_id,ctx)
		if stall is Dictionary: return bool(stall.open)
	var claimed: Array[String] = buildings_of_shop(shop_id)
	if claimed.is_empty():
		return null
	var c: Dictionary = ctx if not ctx.is_empty() else now_ctx()
	for id in claimed:
		if is_open(id, c):
			return true
	return false


## What ShopSystem.get_shop_info shows for a shop: the state of the building that matters ({} when no building claims the shop): an open one if any is, else the one that opens first.
## {open, reason, opens_at, closes_at, next_weekday} like state().
static func closed_info(shop_id: String, ctx: Dictionary = {}) -> Dictionary:
	var social := _Svc.node("SocialManager")
	if social != null and social.has_method("festival_shop_state"):
		var stall: Variant = social.call("festival_shop_state",shop_id,ctx)
		if stall is Dictionary: return stall
	var claimed: Array[String] = buildings_of_shop(shop_id)
	if claimed.is_empty():
		return {}
	var c: Dictionary = ctx if not ctx.is_empty() else now_ctx()
	var best: Dictionary = {}
	var best_wait: float = INF
	for id in claimed:
		var st: Dictionary = state(id, c)
		if bool(st["open"]):
			return st
		var wait: float = _wait_hours(st, c)
		if best.is_empty() or wait < best_wait:
			best = st
			best_wait = wait
	return best


## Game MINUTES until the building closes (0 = closed now or no hours); exact on the 26 hour axis: at 25:30 a shop that closes at 01:00 (25.0) is already closed, at 24:30 it has 30 minutes left.
static func minutes_to_close(building_id: String, ctx: Dictionary = {}) -> int:
	var c: Dictionary = ctx if not ctx.is_empty() else now_ctx()
	var st: Dictionary = state(building_id, c)
	if not bool(st["open"]) or str(st["reason"]) == "none":
		return 0
	var d: float = float(st["closes_at"]) - float(c.get("hour", 12.0))
	return maxi(int(round(d * 60.0)), 0)


## "HH:MM" on the 24 hour clock: the hour part is the game hour mod 24, so 25.0 prints "01:00" and 24.5 "00:30".
static func format_hour(h: float) -> String:
	var total: int = roundi(h * 60.0)
	return "%02d:%02d" % [posmod(floori(float(total) / 60.0), 24), posmod(total, 60)]


## The compact form of the door sign: "8", "23:30"; the hours of the night (24 and later) keep the full form so "1" is never read as 13:00 ("01:00").
static func format_hour_short(h: float) -> String:
	var total: int = roundi(h * 60.0)
	if posmod(total, 60) == 0 and h < 24.0:
		return str(floori(float(total) / 60.0))
	return format_hour(h)


## The weekday numbers a building is closed on (an empty Lua table `{ }` is no days).
static func closed_days(b: Dictionary) -> Array:
	var h: Variant = b.get("hours", {})
	return _ints((h as Dictionary).get("closed", [])) if h is Dictionary else []


## The translation key of the whisper a closed state gets ("" when the state is open): HOURS_CLOSED_NOW | HOURS_CLOSED_DAY | HOURS_CLOSED_FESTIVAL.
static func closed_key(st: Dictionary) -> String:
	match str(st.get("reason", "")):
		"hours":
			return "HOURS_CLOSED_NOW"
		"day":
			return "HOURS_CLOSED_DAY"
		"festival":
			return "HOURS_CLOSED_FESTIVAL"
	return ""


## The whisper TEXT of a closed state, composed at runtime from the CSV template (tr(KEY) % args): "Lukket lige nu. Åbner kl. 07:00." / "Lukket i dag. Åbner igen tirsdag." /
## "Lukket for dagens fest.". "" for an open state. Never applies `%` to a text without a placeholder (an untranslated key stays a key).
static func closed_text(st: Dictionary) -> String:
	var key: String = closed_key(st)
	if key == "":
		return ""
	match key:
		"HOURS_CLOSED_NOW":
			return format_text(key, format_hour(float(st.get("opens_at", 0.0))))
		"HOURS_CLOSED_DAY":
			return format_text(key, weekday_text(int(st.get("next_weekday", 0))))
	return TranslationServer.translate(key)


## tr(KEY) % args, but only when the translated text really has placeholders (`args` is one value or an Array of values).
static func format_text(key: String, args: Variant) -> String:
	var text: String = TranslationServer.translate(key)
	var list: Array = args as Array if args is Array else [args]
	return text % list if text.count("%s") == list.size() else text


## The translated name of a weekday (0 = Monday) as it reads inside a sentence (HOURS_WEEKDAY_n: lower case in Danish).
static func weekday_text(wd: int) -> String:
	return TranslationServer.translate("HOURS_WEEKDAY_%d" % (posmod(wd, 7) + 1))


# ------------------------------------------------------------------------------------------------ routines facade (late bound)

## Routines.where_is through its PATH (T-routes, wave 5): {state, place, act, ...} or null while the facade does not exist. Door2D and ShopHours reach it only here.
static func where_is(npc_id: String, ctx: Dictionary) -> Variant:
	return _Svc.static_call(routines_path, &"where_is", [npc_id, ctx], null)


## Hearts with a citizen: SocialManager.hearts (late bound), then the world flag friend_<npc>. Never through Routines.
static func hearts_of(npc_id: String) -> int:
	var sm: Node = _Svc.node("SocialManager")
	if sm != null and sm.has_method("hearts"):
		return int(sm.call("hearts", npc_id))
	var gm: Node = GameData.gm()
	return int(gm.call("flag_int", StringName("friend_" + npc_id), 0)) if gm != null else 0


# ------------------------------------------------------------------------------------------------ internals

static func _day_start() -> int:
	var gm: Node = GameData.gm()
	return int(gm.call("day_start_hour")) if gm != null else 6


static func _day_end() -> int:
	var gm: Node = GameData.gm()
	return int(gm.call("day_end_hour")) if gm != null else 26


## An authored hour on the game-hour axis (GameManager.game_hour(): below the day start = after midnight of the same game day).
static func _game_hour(h: float) -> float:
	var gm: Node = GameData.gm()
	if gm != null and gm.has_method("game_hour"):
		return float(gm.call("game_hour", h))
	return h + 24.0 if h < 6.0 else h


## Fills opens_at / closes_at / next_weekday of a closed state with the NEXT opening (the next weekday that is not a closed day).
static func _point_at_next_opening(res: Dictionary, b: Dictionary, wd: int, closed: Array) -> void:
	var nd: int = _next_open_weekday(wd, closed)
	var oc: Array = hours_on(b, nd)
	res["next_weekday"] = nd
	res["opens_at"] = float(oc[0])
	res["closes_at"] = float(oc[1])


static func _next_open_weekday(wd: int, closed: Array) -> int:
	for i in range(1, 8):
		var d: int = (wd + i) % 7
		if not (d in closed):
			return d
	return wd


## Game hours from now until a closed state opens (large when it never does): the ranking of closed_info for a shop with several buildings.
static func _wait_hours(st: Dictionary, c: Dictionary) -> float:
	var wd: int = int(c.get("weekday", 0))
	var nd: int = int(st["next_weekday"])
	var days: int = posmod(nd - wd, 7)
	if str(st["reason"]) == "festival" or (str(st["reason"]) == "day" and nd == wd):
		return INF                                    # a festival has no end the rule knows; a building closed on all seven days never opens
	if days == 0 and float(st["opens_at"]) <= float(c.get("hour", 12.0)):
		days = 7                                      # the same weekday again = next week
	return float(days) * 24.0 + float(st["opens_at"]) - float(c.get("hour", 12.0))


static func _ints(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x in (v as Array):
			out.append(int(x))
	return out                                       # an empty Lua table `{ }` arrives as a Dictionary (or an empty Array): that is "no days"


static func _rows(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x in (v as Array):
			if x is Dictionary:
				out.append(x)
	return out
