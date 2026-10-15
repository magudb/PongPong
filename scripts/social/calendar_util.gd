class_name CalendarUtil
extends RefCounted
## Deterministic calendar helpers of the social layer (package S-core). Pure statics: no autoload name is written here, so the class compiles in
## `-s` drivers and before the autoloads exist (Svc is the late-bound bridge).
##
## Model: seasons of `time.days_per_season` (28) days, 4 seasons, a year of 112 days; day 1 of EVERY season has the weekday `time.first_weekday`
## (0 = Monday) because 28 % 7 == 0. A "week" is the calendar week Monday..Sunday: week_of(total_day) is the same number for every player on every
## machine. `weeks_valid()` is false when days_per_season is not a multiple of 7: the week helpers then drift and tests/sections/social.gd fails
## (the week rules need 28 % 7 == 0). total_day = days played, 1-based, the SAME number as GameManager.total_day() (the section asserts it).
##
## The calendar numbers are read through GameManager.config_value (late bound) so a test override of time.* is honoured like everywhere else; without
## a GameManager (a tool driver) the lua config and finally the literals below answer.
##
## THE 26 HOUR GAME DAY (docs/design/CLOCK_26_ADDENDUM.md): hours are RAW game hours, 6..25 in play (24 and 25 read 00:xx and 01:xx of the SAME game day).
## hour_in() normalises both window ends with GameManager.game_hour (an authored 2 means 26, a 0 means 24) and compares the raw hour.

const DEFAULT_SEASONS: Array[StringName] = [&"foraar", &"sommer", &"efteraar", &"vinter"]
const DEFAULT_DAYS_PER_SEASON := 28
const DEFAULT_DAY_START_HOUR := 6
const WEEK := 7


static func _cfg(path: String, default_value: Variant) -> Variant:
	var gm := Svc.node("GameManager")
	if gm != null and gm.has_method("config_value"):
		return gm.call("config_value", path, default_value)
	return Svc.lua_config(path, default_value)


static func days_per_season() -> int:
	return clampi(LuaData.int_of(_cfg("time.days_per_season", DEFAULT_DAYS_PER_SEASON), DEFAULT_DAYS_PER_SEASON), 1, 365)


static func seasons() -> Array[StringName]:
	var cfg: Variant = _cfg("time.seasons", null)
	var out: Array[StringName] = []
	if typeof(cfg) == TYPE_ARRAY:
		for s in cfg:
			if str(s) != "":
				out.append(StringName(str(s)))
	if out.is_empty():
		out.assign(DEFAULT_SEASONS)
	return out


static func first_weekday() -> int:
	return posmod(LuaData.int_of(_cfg("time.first_weekday", 0), 0), WEEK)


static func year_length() -> int:
	return days_per_season() * seasons().size()


static func weeks_valid() -> bool:
	return days_per_season() % WEEK == 0


## Index of a season id (0 for an unknown one, like GameManager.total_day_for).
static func season_index(season: StringName) -> int:
	return maxi(seasons().find(season), 0)


## Same formula as GameManager.total_day_for (the section asserts they agree).
static func total_day(day: int, season: StringName, year: int) -> int:
	var dps := days_per_season()
	return ((maxi(year, 1) - 1) * seasons().size() + season_index(season)) * dps + clampi(day, 1, dps)


## Inverse of total_day: {day, season, year, season_idx}.
static func date_of(td: int) -> Dictionary:
	var dps := days_per_season()
	var season_list := seasons()
	var n := season_list.size()
	var z := maxi(td, 1) - 1
	var s_abs := floori(float(z) / float(dps))
	return {"day": z % dps + 1, "season": season_list[s_abs % n], "year": floori(float(s_abs) / float(n)) + 1, "season_idx": s_abs % n}


## 0 = Monday .. 6 = Sunday of a total day.
static func weekday_of(td: int) -> int:
	return posmod(td - 1 + first_weekday(), WEEK)


## Calendar week index (0-based, counted from day 1): the key of every "once per week" rule.
static func week_of(td: int) -> int:
	return floori(float(td - 1 + first_weekday()) / float(WEEK))


static func is_weekend(td: int) -> bool:
	return weekday_of(td) >= 5


## total day of the first Monday of the week `td` belongs to.
static func week_start(td: int) -> int:
	return td - weekday_of(td)


## Days from `from_td` until the next occurrence (0 = today) of the annual date (season, day).
static func days_until(season: StringName, day: int, from_td: int) -> int:
	var yl := year_length()
	var target := total_day(day, season, 1)               # year 1 position
	var cur := posmod(from_td - 1, yl) + 1                 # position inside the year, 1..yl
	return posmod(target - cur, yl)


static func next_total_day(season: StringName, day: int, from_td: int) -> int:
	return from_td + days_until(season, day, from_td)


## An authored clock hour mapped onto the raw game-hour axis (GameManager.game_hour: everything below the day start is after midnight of the SAME
## game day and gets +24). Without a GameManager the day start is 6.
static func normalise_hour(clock_hour: float) -> float:
	var gm := Svc.node("GameManager")
	if gm != null and gm.has_method("game_hour"):
		return float(gm.call("game_hour", clock_hour))
	return clock_hour + 24.0 if clock_hour < float(DEFAULT_DAY_START_HOUR) else clock_hour


## Is the RAW hour `h` inside [from_h, to_h)? Both ends are authored hours and are normalised first: `22-2` is [22, 26) (true at 24 and 25), `0-2` is
## [24, 26), `22-6` wraps (22..25 and 2..5), `8-18` is unchanged, `6-26` is the whole play day; from == to is always true.
static func hour_in(h: float, from_h: float, to_h: float) -> bool:
	return in_window(h, normalise_hour(from_h), normalise_hour(to_h))


## [a, b) on the raw axis for ends that are ALREADY normalised: a == b is always true, a > b wraps (a..25 and 2..b).
static func in_window(h: float, a: float, b: float) -> bool:
	if is_equal_approx(a, b):
		return true
	if a < b:
		return h >= a and h < b
	return h >= a or h < b


## "foraar:12" - the key of an annual date.
static func date_key(season: StringName, day: int) -> String:
	return "%s:%d" % [season, day]
