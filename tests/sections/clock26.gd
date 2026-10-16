extends RefCounted
## Section clock26 (package CK1-clock-section, the fix round of the 06:00-02:00 game day; contract: docs/design/CLOCK_26_ADDENDUM.md). PROPOSED, proven in APFS clones of the base (m1a head df5d641) under animal, fairy, hobbit and ghost.
## The game day runs from 06:00 to 02:00 at night (user answer 2026-10-14): GameManager.hour is the RAW game hour 6..25 (24 and 25 are the same game day, shown 00:xx and 01:xx),
## the day rolls and the player passes out at game hour 26 (lua/config/game_balance.lua time.day_end_hour), the clock restarts at 02:00 of the new date, one game minute is 0.5 real second.
## Every NEW check of the clock lives here; the existing core / area / save checks that pinned the 24 hour day were only moved (clock_edits.py T01-T12).
##
## Named checks (all prefixed clock26.): config_day_runs_06_to_26, day_end_hour_config_edges, advance_time_conserves_calendar_minutes, hours_24_25_are_the_same_game_day,
## real_time_day_is_10_minutes, display_hours_wrap, game_hour_normaliser, from_dict_old_and_new_saves, save_payload_at_01_40, night_rules_after_midnight, date_and_shop_day_until_the_roll,
## shop_opening_weekday_after_midnight, towns_hours_after_midnight (SKIP until T-towns-core), no_pass_out_at_midnight, whole_day_passes_out_at_02_00, pass_out_at_02_00, bed_after_midnight_passes_one_day, bed_after_the_roll_skips_no_second_day,
## bed_hours_18_to_06, night_after_midnight (day / night look and glow), windowed: night_look_is_continuous_across_midnight.
## The section is a sandbox: it drives the autoloads synchronously for the pure part (no frame passes between a state change and its assertion), then starts the real world for the pass-out.
## Which clock the section runs at (DT55 of TOWNS_FARM_SOCIAL_ADDENDUM): this section is NOT about the opening-hours rule, so the one check that asks ShopSystem.is_open runs with the switch
## towns.hours_enabled = false (once T-towns-core and the P12 helper ShopHoursGate exist, the shop's own hours would answer first: flea_market's building loppeloftet is open 10-16 only).
## The Hours rule on the 26 hour day is proven by towns_data.hours_after_midnight / hours_weekday_is_the_game_day (CK-A-TC), never here.
const SECTION := "clock26"
const TIMEOUT_S := 240.0
const Fmt = preload("res://scripts/ui/theme/tt_format.gd")

var t
var gm: Node
var tm: Node
var bus: Node
var sm: Node
var _world: Node2D


func run(p_t) -> void:
	t = p_t
	gm = t.autoload("GameManager")
	tm = t.autoload("TimeManager")
	bus = t.autoload("EventBus")
	sm = t.autoload("SaveManager")
	if gm == null or tm == null or bus == null or sm == null:
		return
	gm.clear_config_overrides()
	t.new_game()
	gm.change_phase(gm.GamePhase.PLAYING)
	_contract()
	_conservation()
	_one_whole_day()
	_real_time()
	_display()
	_saves()
	_night_rules()
	_date_and_shops()
	if not await t.start_world():
		return
	_world = t.world()
	await _pass_out_and_bed()
	await _night_in_the_world()
	_cleanup()


# ================================================================ the contract: numbers

func _contract() -> void:
	var lua: Node = bus.get_node_or_null("/root/LuaRuntime")
	var cfg_end: int = 26 if lua == null else int(lua.get_config("time.day_end_hour", 26))
	var day_seconds: float = float((gm.day_end_hour() - gm.day_start_hour()) * 60) / gm.minutes_per_real_second()
	t.check("config_day_runs_06_to_26", cfg_end == 26 and gm.DEFAULT_DAY_END_HOUR == 26 and gm.day_end_hour() == 26 and gm.day_start_hour() == 6 and gm.day_roll_restart_hour() == 2
		and is_equal_approx(gm.minutes_per_real_second(), 2.0) and is_equal_approx(day_seconds, 600.0),
		"lua day_end_hour %d, fallback %d, 06:00 to %02d:00, the clock restarts at %02d:00, %.0f real seconds = 10 real minutes per day at %s game min/s (a game hour is 30 s)" % [cfg_end, gm.DEFAULT_DAY_END_HOUR, gm.day_end_hour() - 24, gm.day_roll_restart_hour(), day_seconds, gm.minutes_per_real_second()])
	# 24 is still a valid config: the old midnight roll with the clock restarting at 00:00; impossible values fall back to the default
	gm.set_config_override("time.day_end_hour", 24)
	_set_clock(1, &"foraar", 1, 23, 30)
	gm.advance_time(60)
	var old_midnight: bool = gm.day_end_hour() == 24 and gm.day_roll_restart_hour() == 0 and gm.day == 2 and gm.hour == 0 and gm.minute == 30
	gm.set_config_override("time.day_end_hour", 99)
	var fallback: bool = gm.day_end_hour() == 26
	gm.set_config_override("time.day_end_hour", 6)
	fallback = fallback and gm.day_end_hour() == 26
	gm.set_config_override("time.day_end_hour", 30)          # 24 + day_start_hour: the clock would restart AT the wake-up hour and the pass-out could not be told from the bed
	fallback = fallback and gm.day_end_hour() == 26
	gm.set_config_override("time.day_end_hour", 29)
	fallback = fallback and gm.day_end_hour() == 29 and gm.day_roll_restart_hour() == 5
	# a day end BELOW 24 restarts the clock at 00:00, never at a negative hour (end - 24 < 0): 21:30 + 1 h with day_end_hour 22 is day + 1 at 00:30
	gm.set_config_override("time.day_end_hour", 22)
	var restart_22: int = gm.day_roll_restart_hour()
	_set_clock(1, &"foraar", 1, 21, 30)
	gm.advance_time(60)
	var short_day: bool = restart_22 == 0 and gm.day == 2 and gm.hour == 0 and gm.minute == 30
	# for every day end <= 24 the arithmetic is BIT-IDENTICAL to the old advance_time (the model below IS the old code: total = h * 60 + m + skip, rolls = total / (end * 60), settled = total - rolls * end * 60)
	var model_bad: Array = []
	var model_cases := 0
	for end_hour in [7, 12, 22, 23, 24]:
		gm.set_config_override("time.day_end_hour", end_hour)
		for start_hour in [6, 6 + floori(float(end_hour - 6) / 2.0), end_hour - 1]:
			for start_minute in [0, 59]:
				for skip in [1, 59, 61, 600, 1439, 1441, 5000]:
					var end_minutes: int = end_hour * 60
					var total: int = int(start_hour) * 60 + int(start_minute) + int(skip)
					var rolls: int = floori(float(total) / float(end_minutes))
					var settled: int = total - rolls * end_minutes
					_set_clock(25, &"vinter", 1, int(start_hour), int(start_minute))
					var day_before: int = gm.total_day()
					gm.advance_time(int(skip))
					model_cases += 1
					if gm.total_day() - day_before != rolls or gm.hour != floori(float(settled) / 60.0) or gm.minute != settled - floori(float(settled) / 60.0) * 60:
						model_bad.append([end_hour, start_hour, start_minute, skip, gm.total_day() - day_before, rolls, gm.hour, gm.minute])
	# a modded day START of 1 or 2 (the clamp accepts 0..23): the default end 26 would break day_start < end < 24 + day_start (the clock would restart at 02:00 = the wake-up hour and
	# sleep_until_morning() would skip a SECOND day after the pass-out), so the fallback is the largest valid default, 23 + day_start: 24 at start 1, 25 at start 2, 26 from start 3 on
	gm.clear_config_overrides()
	gm.set_config_override("time.day_start_hour", 1)
	var start_1: bool = gm.day_end_hour() == 24 and gm.day_roll_restart_hour() == 0
	gm.set_config_override("time.day_start_hour", 2)
	var start_2: bool = gm.day_end_hour() == 25 and gm.day_roll_restart_hour() == 1
	gm.set_config_override("time.day_start_hour", 3)
	var start_3: bool = gm.day_end_hour() == 26 and gm.day_roll_restart_hour() == 2
	gm.set_config_override("time.day_start_hour", 2)
	_set_clock(5, &"foraar", 1, 24, 58)
	var day_start2: int = gm.total_day()
	gm.advance_time(5)                                                       # 00:58 + 5 min: the day rolls at raw 25:00 (01:00) and the clock restarts at 01:03
	var after_roll_2: bool = gm.total_day() == day_start2 + 1 and gm.hour == 1 and gm.minute == 3
	var skipped_2: int = gm.sleep_until_morning()                            # still BEFORE the wake-up hour 02:00: no second day
	var no_second_day: bool = after_roll_2 and skipped_2 == 0 and gm.total_day() == day_start2 + 1 and gm.hour == 2
	gm.clear_config_overrides()
	t.check("day_end_hour_config_edges", old_midnight and fallback and short_day and model_bad.is_empty() and start_1 and start_2 and start_3 and no_second_day,
		"day_end_hour 24 = the old midnight roll (23:30 + 1 h = day 2 00:30: %s); 99, 6 and 30 (= 24 + day start) fall back to 26, 29 (restart 05:00) is accepted: %s; day_end_hour 22 restarts at 00:00 (21:30 + 1 h = day 2 00:30: %s); the old arithmetic for end 7 / 12 / 22 / 23 / 24: %d cases, %d differ %s; day start 1 -> end 24 %s, day start 2 -> end 25 (restart 01:00) %s, day start 3 -> 26 %s, a roll under day start 2 skips no second day %s" % [
		old_midnight, fallback, short_day, model_cases, model_bad.size(), model_bad.slice(0, 2), start_1, start_2, start_3, no_second_day])


# ================================================================ arithmetic: no minute is lost or invented at the roll

func _conservation() -> void:
	# invariant of every roll: total_day * 1440 + hour * 60 + minute grows by EXACTLY the advanced minutes (the roll moves one calendar day and takes 24 clock hours back)
	var starts: Array = [[6, 0], [23, 59], [24, 0], [25, 59], [2, 0], [2, 1], [17, 30]]
	var skips: Array = [1, 7, 59, 60, 61, 119, 120, 600, 1199, 1200, 1439, 1440, 1441, 2999, 6000, 40320]
	var bad: Array = []
	var cases := 0
	for end_hour in [26, 24, 29]:
		gm.set_config_override("time.day_end_hour", end_hour)
		var restart: int = gm.day_roll_restart_hour()
		for st in starts:
			for skip in skips:
				if int(st[0]) >= end_hour or int(st[0]) < restart:
					continue                           # a start clock the day can not have (past the end, or before the restart hour)
				_set_clock(25, &"vinter", 1, int(st[0]), int(st[1]))
				var before: int = gm.total_day() * 1440 + gm.hour * 60 + gm.minute
				gm.advance_time(int(skip))
				var after: int = gm.total_day() * 1440 + gm.hour * 60 + gm.minute
				cases += 1
				if after - before != int(skip) or gm.hour >= end_hour or gm.hour < restart or gm.minute < 0 or gm.minute > 59:
					bad.append([end_hour, st, skip, gm.day, gm.hour, gm.minute])
	gm.clear_config_overrides()
	t.check("advance_time_conserves_calendar_minutes", bad.is_empty() and cases > 200, "%d advance_time cases over day_end_hour 26 / 24 / 29 x 7 start clocks x 16 skips (also across the season and year wrap): calendar minutes conserved, hour always in restart..end-1 %s" % [cases, bad.slice(0, 3)])


func _one_whole_day() -> void:
	var w := _watch(["day_ended", "day_started", "game_event", "time_of_day_changed"])
	_set_clock(3, &"foraar", 1, 6, 0)
	var hours := {}
	var early := false
	var clock_log: Callable = func()->Array:return w["log"].filter(func(entry):return entry[0]!="game_event" or entry[1][0]==&"midnight_passed")
	var same_day := true
	for i in 39:                               # 06:00 .. 25:30 in 30 minute steps
		gm.advance_time(30)
		hours[gm.hour] = true
		same_day = same_day and gm.day == 3
		early = early or _names(clock_log.call()).has("day_ended") or _names(clock_log.call()).has("game_event")
	var at_0130: bool = gm.hour == 25 and gm.minute == 30 and gm.day == 3
	var passed_midnight: bool = hours.has(24) and hours.has(25) and not hours.has(26)
	gm.advance_time(30)                        # 26:00: the day end
	var names: Array = _names(clock_log.call())
	var rolled: bool = gm.day == 4 and gm.hour == 2 and gm.minute == 0 and names.count("day_ended") == 1 and names.count("day_started") == 1 and names.count("game_event") == 1
	var order_ok := false
	for entry in clock_log.call():
		if entry[0] == "game_event":
			order_ok = entry[1][0] == &"midnight_passed" and entry[1][1] == {"day": 4, "season": "foraar"}
	_unwatch(w)
	t.check("hours_24_25_are_the_same_game_day", same_day and at_0130 and passed_midnight and not early and rolled and order_ok,
		"06:00 -> 01:30 in 39 steps: day stays 3, raw hours %s seen (24 and 25 yes, 26 never), no day_ended / midnight_passed before the end; +30 min = 02:00 of day 4 with exactly one day_ended, one day_started, one midnight_passed %s" % [hours.keys(), order_ok])


func _real_time() -> void:
	# the rate decision: minutes_per_real_second stays 2.0, so the day (20 game hours) is 600 real seconds; 540 s = raw 24:00 of the SAME day, 599 s = 25:58, 600 s = the roll
	gm.change_phase(gm.GamePhase.PLAYING)
	tm.reset()
	_set_clock(1, &"foraar", 1, 6, 0)
	var marks := {}
	for sec in 600:
		tm.tick(1.0)
		if sec + 1 in [539, 540, 599, 600]:
			marks[sec + 1] = [gm.day, gm.hour, gm.minute]
	t.check("real_time_day_is_10_minutes", marks[539] == [1, 23, 58] and marks[540] == [1, 24, 0] and marks[599] == [1, 25, 58] and marks[600] == [2, 2, 0],
		"tick(1 s) x N from 06:00: 539 s -> %s, 540 s -> %s, 599 s -> %s, 600 s -> %s ([day, hour, minute]; 9 minutes were the old day)" % [marks[539], marks[540], marks[599], marks[600]])


# ================================================================ display and normalisers

func _display() -> void:
	gm.hour = 13                                  # the default argument of clock_hour_of_day() reads THIS hour; an explicit 0 must still mean 00:xx (0 is a valid argument, -1 the "current hour" sentinel)
	t.check("display_hours_wrap", Fmt.clock(6, 5) == "06:05" and Fmt.clock(23, 59) == "23:59" and Fmt.clock(24, 0) == "00:00" and Fmt.clock(24, 30) == "00:30" and Fmt.clock(25, 59) == "01:59" and Fmt.clock(2, 0) == "02:00"
		and gm.clock_hour_of_day(25) == 1 and gm.clock_hour_of_day(24) == 0 and gm.clock_hour_of_day(13) == 13 and gm.clock_hour_of_day(0) == 0 and gm.clock_hour_of_day() == 13,
		"TTFormat.clock: 06:05 23:59 00:00 00:30 01:59 02:00 for raw 6:05 23:59 24:00 24:30 25:59 2:00; GameManager.clock_hour_of_day(25) = 1, (0) = 0, () = the current hour 13")
	gm.hour = 6
	t.check("game_hour_normaliser", is_equal_approx(gm.game_hour(1.5), 25.5) and is_equal_approx(gm.game_hour(0.0), 24.0) and is_equal_approx(gm.game_hour(5.9), 29.9) and is_equal_approx(gm.game_hour(6.0), 6.0)
		and is_equal_approx(gm.game_hour(24.0), 24.0) and is_equal_approx(gm.game_hour(25.5), 25.5) and is_equal_approx(gm.game_hour(23.75), 23.75),
		"an authored hour below the day start is after midnight of the same game day: 1.5 -> 25.5, 0.0 -> 24.0, 5.9 -> 29.9; 6.0, 23.75, 24.0 and 25.5 stay (the ONE normaliser of Hours / routines / when= selectors)")


# ================================================================ saves

func _saves() -> void:
	var hours_back := {}
	for saved_hour in [0, 1, 2, 5, 6, 14, 23, 24, 25, 26, 40, -3]:
		gm.from_dict({"day": 3, "season": "foraar", "year": 1, "hour": saved_hour, "minute": 30})
		hours_back[saved_hour] = gm.hour
	var old_ok: bool = hours_back[6] == 6 and hours_back[14] == 14 and hours_back[23] == 23       # an old save (hours 6..23) loads unchanged
	var new_ok: bool = hours_back[24] == 24 and hours_back[25] == 25 and hours_back[26] == 25 and hours_back[40] == 25
	var lift_ok: bool = hours_back[0] == 2 and hours_back[1] == 2 and hours_back[2] == 2 and hours_back[5] == 5 and hours_back[-3] == 2
	# the file of a build of the 24:00 days: version, hour 23:xx, no new field; and a file of this build at 01:40 after the JSON round trip
	gm.from_dict(JSON.parse_string(JSON.stringify({"version": 1, "day": 12, "season": "sommer", "year": 1, "hour": 23, "minute": 30, "player_name": "Gammel", "character_type": 0})))
	var old_file: bool = gm.hour == 23 and gm.minute == 30 and gm.day == 12 and gm.season == &"sommer"
	_set_clock(7, &"sommer", 2, 25, 40)
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(gm.to_dict()))
	_set_clock(1, &"foraar", 1, 6, 0)
	gm.from_dict(round_trip)
	var late_ok: bool = gm.hour == 25 and gm.minute == 40 and gm.day == 7 and gm.season == &"sommer" and gm.year == 2 and typeof(gm.hour) == TYPE_INT
	t.check("from_dict_old_and_new_saves", old_ok and new_ok and lift_ok and old_file and late_ok,
		"raw hour back %s: old 6 / 14 / 23 unchanged %s, 24 / 25 valid and 26+ -> 25 %s, 0 / 1 / negative -> 02:00 %s; a 24:00-day file at 23:30 loads %s; 01:40 of day 7 survives JSON %s (no SAVE_VERSION bump)" % [hours_back, old_ok, new_ok, lift_ok, old_file, late_ok])
	_set_clock(9, &"efteraar", 1, 25, 40)
	var payload: Dictionary = sm.gather_payload()
	var summary: Dictionary = (payload.get("meta", {}) as Dictionary).get("summary", {})
	t.check("save_payload_at_01_40", int(summary.get("hour", -1)) == 25 and int(summary.get("minute", -1)) == 40 and int((payload.get("game", {}) as Dictionary).get("hour", -1)) == 25 and bool((sm.validate_payload(JSON.parse_string(JSON.stringify(payload))) as Dictionary).get("ok", false)),
		"SaveManager.gather_payload at raw 25:40: summary hour %s minute %s, game.hour %s; the payload still validates after the JSON round trip" % [summary.get("hour"), summary.get("minute"), (payload.get("game", {}) as Dictionary).get("hour")])
	_set_clock(1, &"foraar", 1, 6, 0)


# ================================================================ night, date, shops

func _night_rules() -> void:
	var sweep := ""
	var ok := true
	for probe in [[19, false], [20, true], [23, true], [24, true], [25, true], [2, true], [4, true], [5, false], [6, false], [12, false]]:
		gm.hour = int(probe[0])
		var night: bool = tm.is_night()
		ok = ok and night == bool(probe[1])
		sweep += " %d=%s" % [probe[0], night]
	gm.hour = 12
	t.check("night_rules_after_midnight", ok, "TimeManager.is_night over the raw hours (night = 20.. or ..4): %s; the raw hours 24 and 25 are night (when=night markers, hulen_keeper, ambience), 06:00-19:59 is day" % sweep)


func _date_and_shops() -> void:
	# the date label, weekday and shop opening day belong to the GAME day: Tuesday 16 stays Tuesday at 23:50, 00:30 and 01:30; Wednesday starts with the roll at 02:00
	_set_clock(16, &"foraar", 1, 23, 50)
	var tue_text: String = tm.date_text()
	var tue_idx: int = tm.weekday_index()
	gm.advance_time(40)
	var at_0030: String = tm.date_text()
	var raw_0030: int = gm.hour
	gm.advance_time(60)
	var at_0130: String = tm.date_text()
	var idx_0130: int = tm.weekday_index()
	gm.advance_time(60)
	var after_roll: String = tm.date_text()
	var wed_idx: int = tm.weekday_index()
	t.check("date_and_shop_day_until_the_roll", tue_text == at_0030 and at_0030 == at_0130 and after_roll != tue_text and raw_0030 == 24 and tue_idx == 1 and idx_0130 == 1 and wed_idx == 2 and gm.day == 17,
		"'%s' at 23:50, '%s' at 00:30 (raw %d), '%s' at 01:30, '%s' at 02:00 (weekday index %d -> %d)" % [tue_text, at_0030, raw_0030, at_0130, after_roll, idx_0130, wed_idx])
	# the flea market opens Saturday and Sunday only (open_weekdays 5, 6): on Saturday it stays open at 00:30 and 01:30; the roll makes it Sunday (open); the next roll Monday (closed).
	# DT55: this check is about the WEEKDAY of the game day, not about opening hours, so it runs with the towns' hours rule switched OFF (config towns.hours_enabled = false: ShopHoursGate answers
	# null and the def's weekday rule decides alone). Without the switch, once T-towns-core is merged, ShopSystem.is_open asks Hours.shop_open first and the flea market's building (loppeloftet,
	# hours 10-16, closed Monday to Friday) is closed at 00:30 and 01:30 whatever the weekday is: measured in a throwaway clone (design6/clock/sim_hours_gate.sh). The key is unknown to the base: harmless.
	gm.set_config_override("towns.hours_enabled", false)
	var shop: Node = t.autoload("ShopSystem")
	var results: Array = []
	_set_clock(6, &"foraar", 1, 23, 50)                                     # day 6 = Saturday (first_weekday 0)
	gm.advance_time(40)
	results.append([gm.day, gm.hour, shop.is_open("flea_market")])           # Saturday 00:30: open
	gm.advance_time(60)
	results.append([gm.day, gm.hour, shop.is_open("flea_market")])           # Saturday 01:30: open
	gm.advance_time(60)
	results.append([gm.day, gm.hour, shop.is_open("flea_market")])           # the roll: Sunday 02:00: open
	_set_clock(7, &"foraar", 1, 25, 30)                                     # Sunday 01:30
	var sunday_late: bool = shop.is_open("flea_market")
	gm.advance_time(60)
	results.append([gm.day, gm.hour, shop.is_open("flea_market")])           # Monday 02:30: closed
	t.check("shop_opening_weekday_after_midnight", results[0] == [6, 24, true] and results[1] == [6, 25, true] and results[2] == [7, 2, true] and sunday_late and results[3] == [8, 2, false],
		"ShopSystem.is_open(flea_market) (Saturday + Sunday): Saturday 00:30 %s, Saturday 01:30 %s, Sunday 02:00 %s, Sunday 01:30 %s, Monday 02:30 %s ([day, raw hour, open])" % [results[0], results[1], results[2], sunday_late, results[3]])
	gm.clear_config_overrides()
	_set_clock(1, &"foraar", 1, 6, 0)
	# the opening-hours rule of the towns track (Hours, T-towns-core) is not built in the base: its own check towns_data.hours_after_midnight proves a close of 25.5 and the notation close < open
	if ResourceLoader.exists("res://scripts/towns/hours.gd"):
		t.info("towns_hours_after_midnight: scripts/towns/hours.gd exists - towns_data.hours_after_midnight and towns_data.hours_format_hour_wraps (T-towns-core amendment CK-TC) own that proof")
	else:
		t.skip("clock26.towns_hours_after_midnight: T-towns-core (the Hours rule) is not built yet; towns_data.hours_after_midnight (CK-TC) proves a shop that closes at 25.5 and the notation close < open")


# ================================================================ the real world: pass-out, bed, light

func _pass_out_and_bed() -> void:
	gm.clear_config_overrides()
	_world._enter(&"_fixture_iso", &"default")
	gm.change_phase(gm.GamePhase.PLAYING)
	var notes: Array = []
	var ncb: Callable = func(title: String, msg: String, icon: String) -> void: notes.append([title, msg, icon])
	bus.notification_posted.connect(ncb)
	var w := _watch(["day_ended", "day_started"])
	# --- midnight is NOT the end of the day: 23:50 + 20 min is 00:10 of the SAME game day, nobody passes out, the bed still accepts
	gm.set("hour", 23)
	gm.set("minute", 50)
	var day_mid: int = gm.total_day()
	tm.pause_time()                           # the real clock must not add a minute while the two frames run: the assertion is exact
	gm.advance_time(20)
	await t.frames(2)
	t.check("no_pass_out_at_midnight", not _world.sleeping and not _world.traveling and gm.total_day() == day_mid and gm.hour == 24 and gm.minute == 10 and _world.can_sleep_now() and _names(w["log"]).is_empty(),
		"23:50 + 20 min = raw 24:10 (00:10): same game day %d (now %d), awake, no day_ended, the bed still accepts" % [day_mid, gm.total_day()])
	tm.resume_time()
	# --- a WHOLE day driven by the real tick (1 real second = 2 game minutes): from 06:00 nobody passes out before the 600th second, the sequence starts AT it, the player wakes at 06:00 of the next date
	notes.clear()
	w["log"].clear()
	gm.change_phase(gm.GamePhase.PLAYING)
	tm.reset()
	gm.set("hour", 6)
	gm.set("minute", 0)
	var day_whole: int = gm.total_day()
	var slept_early := false
	for sec in 599:
		tm.tick(1.0)
		slept_early = slept_early or _world.sleeping
	var awake_late: bool = not slept_early and gm.hour == 25 and gm.minute == 58 and gm.total_day() == day_whole
	Engine.time_scale = 4.0
	tm.tick(1.0)                                # the 600th second: 25:58 + 2 min = 26:00
	var started_at_600: bool = _world.sleeping
	var whole_done: bool = await t.until(func() -> bool: return not _world.sleeping, 8.0)
	Engine.time_scale = 1.0
	t.check("whole_day_passes_out_at_02_00", awake_late and started_at_600 and whole_done and gm.total_day() == day_whole + 1 and gm.hour == gm.day_start_hour() and _names(w["log"]).count("day_ended") == 1,
		"06:00 + 599 s of tick(1 s) = raw 25:58 awake (never slept early: %s), the 600th second starts the pass-out %s, awake again %s, total_day %d -> %d, %02d:%02d, one day_ended" % [not slept_early, started_at_600, whole_done, day_whole, gm.total_day(), gm.hour, gm.minute])
	# --- the bed after midnight: one day passes (the day has not ended yet), the player wakes at 06:00 of the NEXT date, no pass-out toast
	notes.clear()
	w["log"].clear()
	gm.set("hour", 24)
	gm.set("minute", 40)
	var day_bed: int = gm.total_day()
	Engine.time_scale = 4.0
	_world.sleep()
	await t.frames(2)
	var bed_started: bool = _world.sleeping
	var bed_done: bool = await t.until(func() -> bool: return not _world.sleeping, 8.0)
	Engine.time_scale = 1.0
	var bed_toast := false
	for n in notes:
		bed_toast = bed_toast or n[2] == "sleep"
	t.check("bed_after_midnight_passes_one_day", bed_started and bed_done and gm.total_day() == day_bed + 1 and gm.hour == gm.day_start_hour() and gm.minute < 10 and not bed_toast and _names(w["log"]).count("day_ended") == 1 and _names(w["log"]).count("day_started") == 1,
		"bed at raw 24:40 (00:40): started %s, finished %s, total_day %d -> %d, %02d:%02d, no pass-out toast %s, one day_ended and one day_started %s" % [bed_started, bed_done, day_bed, gm.total_day(), gm.hour, gm.minute, not bed_toast, _names(w["log"])])
	# --- the pass-out at the day end: 01:50 + 20 min crosses 26:00 = 02:00 -> sleep, fade, toast, wake at 06:00, exactly one new day
	notes.clear()
	w["log"].clear()
	gm.set("hour", gm.day_end_hour() - 1)
	gm.set("minute", 50)
	var day_pass: int = gm.total_day()
	Engine.time_scale = 4.0
	gm.advance_time(20)
	await t.frames(2)
	var passing: bool = _world.sleeping
	var pass_done: bool = await t.until(func() -> bool: return not _world.sleeping, 8.0)
	Engine.time_scale = 1.0
	var toast := false
	for n in notes:
		toast = toast or (n[2] == "sleep" and n[1] == _world.tr("NOTIF_PASSED_OUT"))
	t.check("pass_out_at_02_00", passing and pass_done and gm.total_day() == day_pass + 1 and gm.hour == gm.day_start_hour() and gm.minute < 10 and toast and _names(w["log"]).count("day_ended") == 1 and _names(w["log"]).count("day_started") == 1,
		"raw 25:50 + 20 min: sleeping %s, awake again %s, total_day %d -> %d (ONE day: the roll, then sleep_until_morning skips none), %02d:%02d, NOTIF_PASSED_OUT %s, %s" % [passing, pass_done, day_pass, gm.total_day(), gm.hour, gm.minute, toast, _names(w["log"])])
	# --- the bed after the roll (a save resumed at 02:xx awake, a roll during a travel): it must not skip a SECOND day
	notes.clear()
	w["log"].clear()
	gm.set("hour", 3)
	gm.set("minute", 10)
	var day_after: int = gm.total_day()
	Engine.time_scale = 4.0
	_world.sleep()
	await t.frames(2)
	var after_done: bool = await t.until(func() -> bool: return not _world.sleeping, 8.0)
	Engine.time_scale = 1.0
	t.check("bed_after_the_roll_skips_no_second_day", after_done and gm.total_day() == day_after and gm.hour == gm.day_start_hour() and _names(w["log"]).is_empty(),
		"bed at raw 03:10 (after the 02:00 roll, before the wake-up): same date, wakes at 06:00, no day_ended: total_day %d -> %d" % [day_after, gm.total_day()])
	# --- the bed hours: 18:00 until the wake-up, including the raw hours 24 / 25 and the transient 2..5; never in the day
	var sweep := ""
	var bed_ok := true
	for probe in [[18, true], [23, true], [24, true], [25, true], [2, true], [5, true], [6, false], [12, false], [17, false]]:
		gm.set("hour", int(probe[0]))
		var may: bool = _world.can_sleep_now()
		bed_ok = bed_ok and may == bool(probe[1])
		sweep += " %d=%s" % [probe[0], may]
	t.check("bed_hours_18_to_06", bed_ok, "WorldRoot2D.can_sleep_now over the raw hours:%s (the bed accepts 18:00-05:59 including 00:xx and 01:xx, refuses 06:00-17:59)" % sweep)
	bus.notification_posted.disconnect(ncb)
	_unwatch(w)
	gm.set("hour", 12)
	gm.set("minute", 0)


func _night_in_the_world() -> void:
	var dn: DayNight = _world.day_night
	dn.set_ambient(&"farm")
	dn.override_hour = -1.0
	var wrap_ok: bool = dn.preset_color_at(24.0).is_equal_approx(dn.preset_color_at(0.0)) and dn.preset_color_at(30.0).is_equal_approx(dn.preset_color_at(6.0)) and is_equal_approx(dn.glow_at(24.5), 1.0) and is_equal_approx(dn.glow_at(25.99), 1.0) and is_equal_approx(dn.glow_at(23.0), 1.0) and is_equal_approx(dn.glow_at(30.5), dn.glow_at(6.5)) and dn.glow_at(6.5) < 1.0
	# continuity: the colour at 23:59 and 00:01, and at 01:59 and (the roll) 02:01, differs by less than a few parts in a hundred
	var jump_mid: float = _color_delta(dn.preset_color_at(23.99), dn.preset_color_at(24.01))
	var jump_roll: float = _color_delta(dn.preset_color_at(25.99), dn.preset_color_at(26.01))
	# the real chain: the clock hour -> DayNight.glow -> glow_changed -> WorldRoot2D -> IsoArea.night_factor (lantern halos, point lights)
	_world._enter(&"_fixture_iso", &"default")
	var area: IsoArea = _world.area
	var factors := {}
	for spec in [[12, 0], [23, 30], [24, 30], [25, 30], [8, 0]]:
		gm.set("hour", int(spec[0]))
		gm.set("minute", int(spec[1]))
		_world.day_night.snap()
		await t.frames(2)
		factors[spec[0]] = [area.night_factor, _world.day_night.color.get_luminance()]
	var dark_ok: bool = float(factors[23][0]) == 1.0 and float(factors[24][0]) == 1.0 and float(factors[25][0]) == 1.0 and float(factors[12][0]) == 0.0 and float(factors[8][0]) == 0.0
	var same_look: bool = absf(float(factors[23][1]) - float(factors[25][1])) < 0.05 and float(factors[25][1]) < float(factors[12][1]) - 0.2
	t.check("night_after_midnight", wrap_ok and jump_mid < 0.01 and jump_roll < 0.01 and dark_ok and same_look,
		"farm preset: colour and glow wrap at 24 (24.0 = 0.0, 30.0 = 6.0, glow 1.0 from 20:00 to 05:30), colour step at 00:00 %.4f and at the roll %.4f; IsoArea.night_factor 12:00 %s, 23:30 %s, 00:30 %s, 01:30 %s, 08:00 %s; luminance 23:30 %.3f vs 01:30 %.3f vs noon %.3f" % [
		jump_mid, jump_roll, factors[12][0], factors[23][0], factors[24][0], factors[25][0], factors[8][0], float(factors[23][1]), float(factors[25][1]), float(factors[12][1])])
	gm.set("hour", 12)
	gm.set("minute", 0)
	_world.day_night.snap()


func _color_delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _cleanup() -> void:
	gm.clear_config_overrides()
	Engine.time_scale = 1.0
	t.release_all()
	tm.set_weather(&"klart")
	t.new_game()


# ================================================================ helpers (the pattern of core.gd)

func _set_clock(p_day: int, p_season: StringName, p_year: int, p_hour: int, p_minute: int) -> void:
	gm.day = p_day
	gm.season = p_season
	gm.year = p_year
	gm.hour = p_hour
	gm.minute = p_minute


func _arity_of(signal_name: String) -> int:
	for info in bus.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


func _watch(signal_names: Array) -> Dictionary:
	var box := {"log": [], "cbs": {}}
	for n in signal_names:
		var sig_name := str(n)
		var arity := _arity_of(sig_name)
		var cb := func(a1 = null, a2 = null, a3 = null, a4 = null, a5 = null) -> void:
			(box["log"] as Array).append([sig_name, [a1, a2, a3, a4, a5].slice(0, arity)])
		Signal(bus, sig_name).connect(cb)
		box["cbs"][sig_name] = cb
	return box


func _unwatch(box: Dictionary) -> void:
	for sig_name in box["cbs"]:
		var s := Signal(bus, str(sig_name))
		if s.is_connected(box["cbs"][sig_name]):
			s.disconnect(box["cbs"][sig_name])
	(box["cbs"] as Dictionary).clear()


func _names(log: Array) -> Array:
	var out: Array = []
	for entry in log:
		out.append(entry[0])
	return out


# ================================================================ windowed (tests/run_playtest.sh --windowed --only=clock26): the real farm at 23:30 and at 01:30

func run_windowed(p_t) -> void:
	t = p_t
	gm = t.autoload("GameManager")
	if gm == null or not await t.start_world():
		return
	var w: WorldRoot2D = t.world()
	var farm_id: StringName = &"farm" if WorldRoot2D.has_area(&"farm") else &"_fixture_iso"
	if w.area.map.id != farm_id:
		w._enter(farm_id, &"default")
	t.autoload("TimeManager").pause_time()
	w.day_night.override_hour = -1.0
	var shots := {}
	for spec in [[12, 0], [23, 30], [25, 30]]:
		gm.set("hour", int(spec[0]))
		gm.set("minute", int(spec[1]))
		t.autoload("EventBus").time_of_day_changed.emit(int(spec[0]), int(spec[1]))
		w.day_night.snap()
		await t.frames(8)
		var img: Image = await t.capture("farm_%02d%02d" % [spec[0], spec[1]])
		shots[int(spec[0])] = img
		t.expect_not_blank(img, Rect2i(0, 0, 1280, 720), "the farm renders at %s (raw %02d:%02d)" % [Fmt.clock(int(spec[0]), int(spec[1])), spec[0], spec[1]])
	var night_vs_late: float = t.mean_abs_diff(shots[23], shots[25])
	var night_vs_noon: float = t.mean_abs_diff(shots[12], shots[25])
	t.check("night_look_is_continuous_across_midnight", night_vs_late < 12.0 and night_vs_noon > night_vs_late * 3.0,
		"mean abs diff (0-255): 23:30 vs 01:30 = %.2f (the same navy night, lantern glow on), noon vs 01:30 = %.2f" % [night_vs_late, night_vs_noon])
	t.autoload("TimeManager").resume_time()
	gm.set("hour", 12)
	gm.set("minute", 0)
