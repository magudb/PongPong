extends RefCounted
## Text formatting shared by the HUD, shop, journal ("1.250", "Tirsdag 14. Blomstermåned", "10:40").
## preload("res://scripts/ui/theme/tt_format.gd") - deliberately not a class_name (stale global class cache safe).

static func thousands(n: int) -> String:
	## Danish grouping: 1250 -> "1.250" (the English locale uses ","). Money and counts are shown with it.
	var s := str(absi(n))
	var out := ""
	var sep := "." if TranslationServer.get_locale().begins_with("da") else ","
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += sep
		out += s[i]
	return ("-" if n < 0 else "") + out


## The ONE clock formatter of the UI. The raw game hour (GameManager.hour, 6..25: 24 and 25 are the same game day after midnight) is read mod 24: 25:30 -> "01:30".
static func clock(hour: int, minute: int) -> String:
	return "%02d:%02d" % [posmod(hour, 24), minute]


static func season_day_text(day: int = -1, season: StringName = &"") -> String:
	var gm := Svc.node("GameManager")
	if gm == null:
		return ""
	var d := int(gm.day) if day < 0 else day
	var s := String(gm.season) if season == &"" else String(season)
	return str(TranslationServer.translate("HUD_SEASON_DAY_FMT")) % [TranslationServer.translate("UI_SEASON_" + s.to_upper()), d]


## "Tirsdag 16. Blomstermåned": ONE calendar implementation, TimeManager.date_text() (P02: weekday = (day - 1 + first_weekday)
## % 7, month names from UI_WEEKDAY_n / UI_MONTH_<SEASON>). No arguments = today. Returns "" while there is no TimeManager
## (a -s tool driver): the date is never re-implemented here.
static func date_text(day: int = -1, season: StringName = &"") -> String:
	var tm := Svc.node("TimeManager")
	if tm == null or not tm.has_method("date_text"):
		return ""
	return str(tm.call("date_text", day, season))
