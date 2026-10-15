#!/usr/bin/env python3
"""clock_edits.py  -  THE list of exact edits of docs/design/CLOCK_26_ADDENDUM.md (the 06:00-02:00 game day), as data.
  python3 -I clock_edits.py apply CLONE [--stage data|code|tests|docs|all] [--when fix|docs] [--only C01,T02] [--except C04] [--docs-from DIR]
        apply to an APFS clone of the base (m1a head df5d641); stops (exit 1) when a 'before' text is not found exactly `count` times
        --except is the MUTATION switch: leave one edit out and the named check must fail (see MUTATIONS below)
        --docs-from DIR  copies DIR/<name> over CLONE/docs/design/<name> for every docs file that the docs stage edits (the docs live in main, which is newer than
                         the base: the docs edits are proven against main's CURRENT text, not against the base's older copy)
  python3 -I clock_edits.py check [--root DIR] [--docs-from DIR]
        every 'before' matches exactly once in ROOT (default: the read-only base), every owner label is an owner of the file in impl/owners.json (audit/who_owns.py),
        built flags agree with impl/built_ids.json + the wave table, no edit touches a sha-pinned file (city_levels PINNED) or a Codex file; exit 1 on any problem
  python3 -I clock_edits.py md        the markdown table (addendum section 12)
  python3 -I clock_edits.py json      the list as JSON (for clock_packages.json tasks)
Final round (reviewer A pass 2 + the final editor): C03 got an always-valid fallback, X12-X18 were added (50 edits); the section file sections/clock26.gd carries the DT55 switch and the new checks.
Each edit: id, stage, pkg (the package that OWNS the file; "(built)" = the fix round before wave 4, otherwise the owner applies it at its own wave), file, before, after, why, count.
Nothing is ever applied to the real repo, the base checkout, the lift or the m1a worktree: the fix-round package (CK1) and the owners apply the same pairs by hand or with this script.
NEW FILE (not an edit): sections/clock26.gd -> tests/sections/clock26.gd (package CK1-clock-section); copied by `apply --stage tests`."""
import json, re, shutil, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE = Path('/Users/magnusudbjorg/Documents/projects/PongPong-worktrees/design6-base')
MAIN = Path('/Users/magnusudbjorg/Documents/projects/PongPong')
NEW_FILES = {'tests/sections/clock26.gd': ('sections/clock26.gd', 'CK1-clock-section')}
E = []


def L(*lines):
    """lines joined with a newline (readable multi-line before / after texts)"""
    return '\n'.join(lines)


def edit(eid, stage, pkg, file, before, after, why, count=1):
    # when: fix = the fix round (BUILT files, before wave 4); docs = the lead's docs commit (docs/design/**, proven against main's docs)
    E.append(dict(id=eid, stage=stage, pkg=pkg, file=file, before=before, after=after, why=why, count=count, when='docs' if stage == 'docs' else 'fix'))


GM = 'scripts/autoload/game_manager.gd'
TM = 'scripts/autoload/time_manager.gd'
P02 = 'P02-bus-gamemanager-time (built)'

# ======================================================================================================== DATA: the one number (P10)
edit('D01', 'data', 'P10-data-contracts (built)', 'lua/config/game_balance.lua',
     L('  -- time: TimeManager / GameManager (P02).  06:00-24:00 at 2 game minutes per real second = 9 real minutes per day.',
       '  time = {',
       '    minutes_per_real_second = 2.0,',
       '    day_start_hour = 6,',
       '    day_end_hour = 24,             -- 24:00 passes the player out',
       '    days_per_season = 28,',
       '    seasons = { "foraar", "sommer", "efteraar", "vinter" },',
       '    first_weekday = 0,             -- weekday of day 1 of every season: 0 = Monday ... 6 = Sunday',
       '    night_start_hour = 20,         -- is_night(): hour >= night_start_hour or hour < night_end_hour'),
     L('  -- time: TimeManager / GameManager (P02).  06:00-02:00 (game hours 6..25, 20 hours) at 2 game minutes per real second = 10 real minutes per day.',
       '  -- THE CLOCK CONTRACT (docs/design/CLOCK_26_ADDENDUM.md): every hour of every Lua table is a float of GAME HOURS on the axis 6..26 (6.5 = 06:30, 25.0 = 01:00,',
       '  -- 25.5 = 01:30); 24.0 and 25.5 belong to the SAME game day as 23.0; the day rolls (calendar, weather, bin, restock, crop growth, autosave) at day_end_hour.',
       '  time = {',
       '    minutes_per_real_second = 2.0,',
       '    day_start_hour = 6,',
       '    day_end_hour = 26,             -- game hour 26 = 02:00 passes the player out; the hours 24 and 25 are the SAME game day (shown 00:xx and 01:xx); valid 7..29',
       '    days_per_season = 28,',
       '    seasons = { "foraar", "sommer", "efteraar", "vinter" },',
       '    first_weekday = 0,             -- weekday of day 1 of every season: 0 = Monday ... 6 = Sunday',
       '    night_start_hour = 20,         -- is_night(): hour >= night_start_hour or hour < night_end_hour (the raw hours 24 and 25 count as night)'),
     'the ONE number of the user rule "until 2 at night": day_end_hour 24 -> 26. minutes_per_real_second stays 2.0 (a game hour = 30 real seconds, so every "x game minutes = y real seconds" figure of the towns / social / ghost designs stays true): the day grows from 9 to 10 real minutes')
edit('D02', 'data', 'P10-data-contracts (built)', 'lua/config/game_balance.lua',
     L('  -- water_window = { from, to } (hours, wraps midnight): the crop only grows when it was watered inside the window',
       '  -- (moon crops: 20:00-06:00).  The sprite stage (crop_<id>_0..3) follows the growth ratio, not `stages`.'),
     L('  -- water_window = { from, to } (game hours on the stored axis, see `time` below): the crop only grows when it was watered inside the window; from > to wraps:',
       '  -- hour >= from or hour < to, so { 20, 6 } (moon crops) = 20:00-06:00 = the raw hours 20..25 and 2..5 (00:xx and 01:xx count, a watering at 01:30 belongs to the day that',
       '  -- rolls at 02:00).  The sprite stage (crop_<id>_0..3) follows the growth ratio, not `stages`.'),
     'P06 reads the window on the RAW hour: the playable part of the moon window grows from 4 h (20-24) to 6 h (20-26); the comment said "wraps midnight", which is no longer where the day ends')

# ======================================================================================================== CODE: P02 (GameManager, TimeManager, EventBus)
edit('C01', 'code', P02, GM,
     L('## day_start_hour(), day_end_hour(), minutes_per_real_second()). The clock is a plain 24 hour clock:',
       '##   advance_time(minutes) is exact arithmetic. Crossing day_end_hour (24:00) rolls the day and carries the overflow, so',
       '##     06:00 + 25 h is 07:00 of the next day and a 50 h skip crosses two midnights (day_ended .. day_started per midnight).',
       '##     time_of_day_changed always carries hour 0..23.',
       '##   end_day() ends the current day NOW and starts the next morning at day_start_hour (bed, harness t.days()).',
       '##   sleep_until_morning() is the helper for WorldRoot2D: the bed (before midnight) and the pass-out (the clock already',
       '##     crossed midnight, so the new day has begun) both wake the player at day_start_hour; it never skips a day twice.',
       '##   WorldRoot2D detects the pass-out through EventBus.game_event(&"midnight_passed", {day, season}), emitted once per',
       '##     midnight that advance_time() crosses (after day_started; never by end_day or the bed). The clock hour is never 24.'),
     L('## day_start_hour(), day_end_hour(), minutes_per_real_second()). THE GAME DAY RUNS 06:00 TO 02:00 AT NIGHT (user answer 2026-10-14; the contract is',
       '## docs/design/CLOCK_26_ADDENDUM.md). The clock is READ with a RAW hour:',
       '##   `hour` is the raw game hour 6..25: the hours 24 and 25 belong to the SAME game day (same `day`, weekday, weather, shop opening day, festival',
       '##     day) and are DISPLAYED 00:xx and 01:xx (TTFormat.clock / clock_hour_of_day(): hour % 24). The player passes out at game hour 26 = 02:00',
       '##     (day_end_hour()). Hours of Lua tables are floats on the same axis (25.5 = 01:30); game_hour() maps an authored 1.5 onto it.',
       '##   advance_time(minutes) is exact arithmetic. Crossing day_end_hour (26:00) rolls the day: the calendar steps and the clock restarts at',
       '##     day_end_hour - 24 = 02:00 of the NEW date (00:00 when day_end_hour <= 24, the old behaviour), so the clock never jumps backwards (01:59',
       '##     -> 02:00) and every calendar day is exactly 24 clock hours: 06:00 + 25 h is 07:00 of the next day and a 50 h skip crosses two rolls',
       '##     (day_ended .. day_started per roll). time_of_day_changed carries the raw hour: 2..25 (6..25 in play, 2..5 only between the roll and the wake-up).',
       '##   end_day() ends the current day NOW and starts the next morning at day_start_hour (bed, harness t.days()).',
       '##   sleep_until_morning() is the helper for WorldRoot2D: the bed (any raw hour >= day_start_hour, so also 24:xx and 25:xx) and the pass-out',
       '##     (the clock already crossed the roll, so the new day has begun and the raw hour is 2..5) both wake the player at day_start_hour; it',
       '##     never skips a day twice.',
       '##   WorldRoot2D detects the pass-out through EventBus.game_event(&"midnight_passed", {day, season}), emitted once per roll that',
       '##     advance_time() crosses (after day_started; never by end_day or the bed). The id is kept from the 24:00 days: it means "the day-end',
       '##     roll" (02:00); real midnight (raw 24:00) emits nothing. The clock hour is never 26.'),
     'the header documents the 24 hour day in five places; with the contract in the header a reader of the file cannot re-introduce 24:00')
edit('C02', 'code', P02, GM, 'const DEFAULT_DAY_END_HOUR := 24', 'const DEFAULT_DAY_END_HOUR := 26',
     'the literal used when LuaRuntime or the key is missing (tools, -s drivers); tests/sections/core.gd config_literal_defaults pins it (edit T01)')
edit('C03', 'code', P02, GM,
     L('## The hour at which the clock wraps into the next day (24 by default).',
       'func day_end_hour() -> int:',
       '\tvar end_hour := int(config_value("time.day_end_hour", DEFAULT_DAY_END_HOUR))',
       '\tif end_hour <= day_start_hour() or end_hour > 48:',
       '\t\treturn DEFAULT_DAY_END_HOUR',
       '\treturn end_hour',
       ''),
     L('## The raw game hour at which the day rolls and the player passes out (26 = 02:00 by default; 24 = midnight, the old value).',
       '## Valid: day_start_hour < value < 24 + day_start_hour (the restart hour after the roll must stay BEFORE the wake-up hour, or',
       '## sleep_until_morning() could not tell the pass-out from the bed). Anything else falls back to the default 26 or, when 26 itself breaks the',
       '## range for a modded day start of 0..2 (26 >= 24 + start), to the largest valid value 23 + day_start_hour (24 at start 1, 25 at start 2).',
       '## (A day start of 0 has no hour below it: there the pass-out can not be told from the bed in ANY version, the 24 hour one included.)',
       'func day_end_hour() -> int:',
       '\tvar fallback := mini(DEFAULT_DAY_END_HOUR, 23 + day_start_hour())',
       '\tvar end_hour := int(config_value("time.day_end_hour", DEFAULT_DAY_END_HOUR))',
       '\tif end_hour <= day_start_hour() or end_hour >= 24 + day_start_hour():',
       '\t\treturn fallback',
       '\treturn end_hour',
       '',
       '',
       '## The raw clock hour the new calendar day starts with right after the roll: day_end_hour() - 24 (02:00 at 26), never negative.',
       'func day_roll_restart_hour() -> int:',
       '\treturn maxi(day_end_hour() - 24, 0)',
       '',
       '',
       '## The hour as the player reads it: the raw hours 24 and 25 (the same game day) read 0 and 1. Default: the current hour.',
       'func clock_hour_of_day(raw_hour: int = -1) -> int:',
       '\treturn posmod(hour if raw_hour < 0 else raw_hour, 24)',
       '',
       '',
       '## An hour as AUTHORED (a Lua value, a window end, a person typing 1.5 for 01:30) mapped onto the raw game-hour axis: everything below the',
       '## day start is after midnight of the SAME game day and gets +24 (1.5 -> 25.5, 0.0 -> 24.0); 6.0 and up stay. The ONE normaliser of the',
       '## opening-hours rule, the routine compiler and the when= hour selectors: nothing re-implements the wrap.',
       'func game_hour(clock_hour: float) -> float:',
       '\treturn clock_hour + 24.0 if clock_hour < float(day_start_hour()) else clock_hour',
       ''),
     'the old guard "> 48" accepted day_end_hour 30 (= 24 + day start), where the clock would restart AT the wake-up hour and sleep_until_morning() could not tell the pass-out from the bed (it would skip a second day); '
     'the fallback is always inside the valid range (reviewer A, pass 2: with a modded day_start_hour of 2 the default 26 would restart the clock at 02:00 = the wake hour and the pass-out roll would end a SECOND day: '
     'probe zz_rvb_probe2 skipped day 6 -> 7; with the fallback 23 + day_start the same probe skips none); '
     'three helpers instead of three copies of "% 24" and "+ 24" in the HUD, the Hours rule, the routine compiler and CalendarUtil')
edit('C04', 'code', P02, GM,
     L('## the overflow, as often as needed. time_of_day_changed fires once at the end with the settled hour 0..23.',
       'func advance_time(minutes: int) -> void:',
       '\tif minutes < 0:',
       '\t\treturn',
       '\tvar day_minutes := day_end_hour() * 60',
       '\tvar total := hour * 60 + minute + minutes',
       '\tvar midnights := floori(float(total) / float(day_minutes))',
       '\tvar settled := total - midnights * day_minutes',
       '\tfor i in midnights:',
       '\t\thour = 0',
       '\t\tminute = 0',
       '\t\t_roll_day()',
       '\thour = floori(float(settled) / 60.0)',
       '\tminute = settled - hour * 60'),
     L('## the overflow, as often as needed. Each roll puts the clock back by one calendar day (24 h; E h when day_end_hour E < 24), so',
       '## the clock restarts at day_roll_restart_hour(). time_of_day_changed fires once at the end with the settled raw hour (2..25).',
       'func advance_time(minutes: int) -> void:',
       '\tif minutes < 0:',
       '\t\treturn',
       '\tvar end_minutes := day_end_hour() * 60',
       '\tvar restart_minutes := day_roll_restart_hour() * 60',
       '\tvar day_minutes := end_minutes - restart_minutes',
       '\tvar total := hour * 60 + minute + minutes',
       '\tvar rolls := 0',
       '\tif total >= end_minutes:',
       '\t\trolls = floori(float(total - restart_minutes) / float(day_minutes))',
       '\t\ttotal -= rolls * day_minutes',
       '\tfor i in rolls:',
       '\t\thour = floori(float(restart_minutes) / 60.0)',
       '\t\tminute = 0',
       '\t\t_roll_day()',
       '\thour = floori(float(total) / 60.0)',
       '\tminute = total - hour * 60'),
     'MEASURED (probe m1, clone with ONLY day_end_hour = 26): the old arithmetic wraps by day_end_hour * 60 and restarts at hour 0, so 25:59 + 1 minute lands on 00:00 (the clock jumps back two hours), 06:00 + 25 h on 05:00, '
     '06:00 + 50 h on day 3 04:00 and a 29-day skip on day 28 01:30; with the restart at 02:00 every calendar day is exactly 24 clock hours and with day_end_hour 24 the arithmetic is bit-identical to the old one. No integer "/" (the harness fails on warnings)')
edit('C05', 'code', P02, GM,
     L('## Sleep helper for WorldRoot2D (bed and pass-out). Wakes at day_start_hour: before midnight the day ends first',
       '## (end_day), after midnight (the pass-out: advance_time already rolled the day) only the rest of the night is skipped.'),
     L('## Sleep helper for WorldRoot2D (bed and pass-out). Wakes at day_start_hour: while the raw hour is still >= day_start_hour (also',
       '## 24:xx and 25:xx) the day ends first (end_day), after the roll (the pass-out: advance_time already rolled the day, the raw hour',
       '## is 2..5) only the rest of the night is skipped.'),
     'comment only: the CODE of sleep_until_morning() is already right for the new day (hour < wake_hour = the pass-out case); proven by clock26.bed_after_midnight_passes_one_day and core.sleep_after_passout_no_double_day')
edit('C06', 'code', P02, GM,
     '## One midnight of advance_time: the clock is 00:00 here, the calendar steps, the weather is rolled, a new day starts.',
     '## One day-end roll of advance_time: the clock is at the restart hour (02:00) here, the calendar steps, the weather is rolled, a new day starts.',
     'comment only')
edit('C07', 'code', P02, GM,
     '\thour = clampi(int(data.get("hour", day_start_hour())), 0, day_end_hour() - 1)',
     L('\t# a saved raw hour below the restart hour (an old save taken at 00:xx / 01:xx right after the old midnight roll) is the same night:',
       '\t# it is lifted to the restart hour (02:00) instead of being read as 24 h later; 24 and 25 are valid (a save at 01:40 of the same game day)',
       '\thour = clampi(int(data.get("hour", day_start_hour())), day_roll_restart_hour(), day_end_hour() - 1)'),
     'OLD SAVES: hours 6..23 load unchanged under every variant, 24 / 25 (new saves) are accepted, 26+ clamps to 25, an hour 0 / 1 / negative becomes 02:00. SAVE_VERSION is NOT bumped (no field changes meaning for 6..23)')
edit('C08', 'code', P02, TM,
     L('func get_day_fraction() -> float:',
       '\treturn (GameManager.hour * 60.0 + GameManager.minute) / (GameManager.day_end_hour() * 60.0)',
       '',
       '',
       '## `time.night_start_hour` / `time.night_end_hour` (defaults 20 and 5).'),
     L('## The clock as a fraction of the 24 hour clock face (noon = 0.5). It passes 1.0 between 24:00 and 02:00 (the raw hours 24 and 25 of the',
       '## same game day); nothing divides by the day length any more, so changing day_end_hour never moves noon. No script reads it today.',
       'func get_day_fraction() -> float:',
       '\treturn (GameManager.hour * 60.0 + GameManager.minute) / 1440.0',
       '',
       '',
       '## `time.night_start_hour` / `time.night_end_hour` (defaults 20 and 5). The raw hours 24 and 25 (00:xx and 01:xx of the same game',
       '## day) are >= night_start and the hours 2..4 after the day roll are < night_end: the whole stretch 20:00-05:00 is night.'),
     'MEASURED: with day_end_hour 26 the old division made noon 0.4615 (core.day_fraction failed); the only reader is the test')
edit('C09', 'code', P02, TM,
     '## (GameManager.end_day / the midnight roll call roll_weather_for_day(); the day_started handler below is only a guarded',
     '## (GameManager.end_day / the day-end roll call roll_weather_for_day(); the day_started handler below is only a guarded',
     'comment only')
edit('C10', 'code', P02, 'scripts/autoload/event_bus.gd',
     L('signal day_ended(day: int, season: StringName)',
       'signal time_of_day_changed(hour: int, minute: int)'),
     L('signal day_ended(day: int, season: StringName)',
       '# hour is the RAW game hour 2..25 (6..25 in normal play): 24 and 25 are 00:xx and 01:xx of the SAME game day (the day runs to 02:00);',
       '# show it with TTFormat.clock() / GameManager.clock_hour_of_day(), compare it raw (night = hour >= 20 or hour < 5 holds for 24 and 25 too).',
       'signal time_of_day_changed(hour: int, minute: int)'),
     'the handoff text of P17 said "hour 0..23"; every HUD that prints the raw hour would show 24:30')
edit('C11', 'code', P02, 'scripts/autoload/event_bus.gd',
     '## GameManager.advance_time() emits midnight_passed {day, season} for every midnight the clock crosses (the pass-out trigger).',
     L('## GameManager.advance_time() emits midnight_passed {day, season} for every day-end roll the clock crosses (the pass-out trigger; the id is kept from the',
       '## days that ended at 24:00, the roll is now at game hour 26 = 02:00; real midnight, raw hour 24, emits nothing; a hook for a true midnight needs a NEW name).'),
     'the name is reserved by the towns addendum (8.2) and pinned by area.gd: NOT renamed; the comment says what it means now')
edit('C12', 'code', 'P07-ui-foundation (built)', 'scripts/ui/theme/tt_format.gd',
     L('static func clock(hour: int, minute: int) -> String:',
       '\treturn "%02d:%02d" % [hour, minute]'),
     L('## The ONE clock formatter of the UI. The raw game hour (GameManager.hour, 6..25: 24 and 25 are the same game day after midnight) is read mod 24: 25:30 -> "01:30".',
       'static func clock(hour: int, minute: int) -> String:',
       '\treturn "%02d:%02d" % [posmod(hour, 24), minute]'),
     'MEASURED (probe m1): clock(24, 5) = "24:05" and clock(25, 59) = "25:59"; P17 / P16 / S-ui format every clock through this helper (nothing in the base tests it with an hour >= 24)')
edit('C13', 'code', 'P15-save-system (built)', 'scripts/autoload/save_manager.gd',
     '## is PLAYING, and once after every day end (EventBus.day_ended fires at the bed and at every crossed midnight). The day-end',
     '## is PLAYING, and once after every day end (EventBus.day_ended fires at the bed and at every crossed day end, game hour 26 = 02:00). The day-end',
     'comment only: nothing saves at 24:00 any more (no day_ended there); the 5 minute timer covers 00:00-02:00')
edit('C14', 'code', 'P04-area-framework (built)', 'lua/config/ambient.lua',
     L('-- Colours are hex WITHOUT \'#\'. A preset\'s `keys` are { hour, color } keyframes over a 24 hour day (the colour of the',
       '-- CanvasModulate; it MULTIPLIES the picture, so white = unchanged); DayNight interpolates smoothly between them and wraps at',
       '-- midnight. `glow` is the 0..1 factor that fades the additive glow sprites and PointLights in at dusk (lantern posts,'),
     L('-- Colours are hex WITHOUT \'#\'. A preset\'s `keys` are { hour, color } keyframes over a 24 hour day (the colour of the',
       '-- CanvasModulate; it MULTIPLIES the picture, so white = unchanged); DayNight interpolates smoothly between them and wraps at',
       '-- midnight (fposmod 24: the game day runs to 02:00, so the raw game hours 24..26 sample the keys 0.0..2.0 and every preset has the same colour at 0.0 and 24.0).',
       '-- `glow` is the 0..1 factor that fades the additive glow sprites and PointLights in at dusk (lantern posts,'),
     'comment only: DayNight needs NO code or data change (preset_color_at / glow_at already use fposmod(h, 24); probe: farm 23.99 = 576199 = 24.0, 25.99 = 5e68a0 = 1.99, glow 1.0 from 20:00 to 05:30; '
     'tests/sections/area.gd daynight_farm_keyframes asserts color(24.0) == color(0.0)); proven by clock26.night_after_midnight')

# ======================================================================================================== TESTS: the pins of the 24 hour day that must move (existing checks keep their ids and their intent)
# Every NEW check lives in the new section tests/sections/clock26.gd (package CK1). Here only the lines that PIN the old day are rewritten: measured with ONLY
# day_end_hour = 26 the base fails exactly 9 core checks and 2 area checks (impl evidence: design6/a2/harness_day_end26.log, design6/analyst1/logs/cfg26_full.log);
# with the 02:00 restart (C04) and day fraction / 1440 (C08) the set below is what is left.
CORE = 'tests/sections/core.gd'
edit('T01', 'tests', P02, CORE,
     '\t\tand gm.DEFAULT_DAY_START_HOUR == 6 and gm.DEFAULT_DAY_END_HOUR == 24 and gm.DEFAULT_MINUTES_PER_REAL_SECOND == 2.0, "28 days, 4 seasons, 06:00 to 24:00, 2 min/s")',
     '\t\tand gm.DEFAULT_DAY_START_HOUR == 6 and gm.DEFAULT_DAY_END_HOUR == 26 and gm.DEFAULT_MINUTES_PER_REAL_SECOND == 2.0, "28 days, 4 seasons, 06:00 to 26:00 (= 02:00 at night), 2 min/s")',
     'core.config_literal_defaults pins the fallback literal (C02)')
edit('T02', 'tests', P02, CORE,
     L('\tvar exactly_midnight: bool = gm.day == 2 and gm.hour == 0 and gm.minute == 0',
       '\t_set_clock(1, &"foraar", 1, 23, 59)',
       '\tgm.advance_time(1)',
       '\tvar one_minute: bool = gm.day == 2 and gm.hour == 0 and gm.minute == 0',
       '\t_set_clock(1, &"foraar", 1, 6, 0)',
       '\tvar start_total: int = gm.total_day()',
       '\tgm.advance_time(29 * 24 * 60 + 90)',
       '\tvar month_skip: bool = gm.total_day() == start_total + 29 and gm.hour == 7 and gm.minute == 30 and gm.season == &"sommer" and gm.day == 2',
       '\tt.check("advance_time_multiday", fifty and exactly_midnight and one_minute and month_skip,',
       '\t\t"50 h -> day 3 08:00 %s; 18 h -> midnight %s; 23:59 + 1 min %s; 29 days 90 min -> sommer day 2 07:30 %s" % [fifty, exactly_midnight, one_minute, month_skip])',
       '\t# the clock hours handed to listeners are always 0..23',
       '\tvar hours_ok := true',
       '\tfor entry in w["log"]:',
       '\t\tif entry[0] == "time_of_day_changed" and (int(entry[1][0]) < 0 or int(entry[1][0]) > 23 or int(entry[1][1]) < 0 or int(entry[1][1]) > 59):',
       '\t\t\thours_ok = false',
       '\tt.check("time_of_day_changed_range", hours_ok, "hour 0..23, minute 0..59")'),
     L('\tvar exactly_midnight: bool = gm.day == 1 and gm.hour == 24 and gm.minute == 0      # 06:00 + 18 h is 00:00 of the SAME game day (raw hour 24)',
       '\t_set_clock(1, &"foraar", 1, 6, 0)',
       '\tgm.advance_time(20 * 60)',
       '\tvar exactly_day_end: bool = gm.day == 2 and gm.hour == 2 and gm.minute == 0        # 06:00 + 20 h = 26:00: the day rolls, the clock restarts at 02:00',
       '\t_set_clock(1, &"foraar", 1, 23, 59)',
       '\tgm.advance_time(1)',
       '\tvar one_minute: bool = gm.day == 1 and gm.hour == 24 and gm.minute == 0            # 23:59 + 1 min = 00:00 of the same day: no roll, no pass-out event',
       '\t_set_clock(1, &"foraar", 1, 25, 59)',
       '\tgm.advance_time(1)',
       '\tvar one_minute_end: bool = gm.day == 2 and gm.hour == 2 and gm.minute == 0         # 01:59 (raw 25:59) + 1 min = the day end',
       '\t_set_clock(1, &"foraar", 1, 6, 0)',
       '\tvar start_total: int = gm.total_day()',
       '\tgm.advance_time(29 * 24 * 60 + 90)',
       '\tvar month_skip: bool = gm.total_day() == start_total + 29 and gm.hour == 7 and gm.minute == 30 and gm.season == &"sommer" and gm.day == 2',
       '\tt.check("advance_time_multiday", fifty and exactly_midnight and exactly_day_end and one_minute and one_minute_end and month_skip,',
       '\t\t"50 h -> day 3 08:00 %s; 18 h -> raw 24:00 of the same day %s; 20 h -> day 2 02:00 %s; 23:59 + 1 min -> raw 24:00 same day %s; 25:59 + 1 min -> day 2 02:00 %s; 29 days 90 min -> sommer day 2 07:30 %s" % [fifty, exactly_midnight, exactly_day_end, one_minute, one_minute_end, month_skip])',
       '\t# the clock hours handed to listeners are the raw game hours 2..25 (24 and 25 = 00:xx and 01:xx of the same day; never 26), minutes 0..59',
       '\tvar hours_ok := true',
       '\tfor entry in w["log"]:',
       '\t\tif entry[0] == "time_of_day_changed" and (int(entry[1][0]) < 2 or int(entry[1][0]) > 25 or int(entry[1][1]) < 0 or int(entry[1][1]) > 59):',
       '\t\t\thours_ok = false',
       '\tw["log"].clear()',
       '\t_set_clock(1, &"foraar", 1, 23, 0)',
       '\tgm.advance_time(90)',
       '\thours_ok = hours_ok and w["log"].size() == 1 and w["log"][0][0] == "time_of_day_changed" and w["log"][0][1] == [24, 30]',
       '\tt.check("time_of_day_changed_range", hours_ok, "raw hour 2..25 (a signal at 24:30 carries 24: the HUD shows 00:30), minute 0..59")'),
     'MEASURED to fail with only day_end_hour = 26: advance_time_multiday (18 h and 23:59 + 1 expected a roll at 24:00) and time_of_day_changed_range (hour 0..23). '
     '06:00 + 25 h = 07:00, +50 h = day 3 08:00 and the 29-day skip stay TRUE under the 02:00 restart (every calendar day is 24 clock hours) and stay untouched')
edit('T03', 'tests', P02, CORE,
     L('\tt.check("season_rollover", gm.day == 1 and gm.season == &"sommer" and gm.year == 1 and gm.hour == 1 and _names(w["log"]) == ["day_ended", "season_changed", "day_started", "game_event", "time_of_day_changed"] and w["log"][1][1] == [&"sommer"],',
       '\t\t"day 28 foraar + 2 h = day 1 sommer 01:00: %s" % [_names(w["log"])])',
       '\tw["log"].clear()',
       '\t_set_clock(28, &"vinter", 1, 23, 0)'),
     L('\tvar still_28: bool = gm.day == 28 and gm.season == &"foraar" and gm.hour == 25 and w["log"].size() == 1      # 23:00 + 2 h = 01:00 of the SAME day 28: no season change yet',
       '\tw["log"].clear()',
       '\t_set_clock(28, &"foraar", 1, 25, 0)',
       '\tgm.advance_time(120)',
       '\tt.check("season_rollover", still_28 and gm.day == 1 and gm.season == &"sommer" and gm.year == 1 and gm.hour == 3 and _names(w["log"]) == ["day_ended", "season_changed", "day_started", "game_event", "time_of_day_changed"] and w["log"][1][1] == [&"sommer"],',
       '\t\t"day 28 foraar 23:00 + 2 h = still day 28 (01:00); 01:00 (raw 25:00) + 2 h = day 1 sommer 03:00: %s" % [_names(w["log"])])',
       '\tw["log"].clear()',
       '\t_set_clock(28, &"vinter", 1, 25, 0)'),
     'MEASURED to fail (season_rollover, year_rollover): 23:00 + 2 h no longer crosses the day end; the rollover now starts from 01:00 (raw 25:00); year_rollover keeps its assertion and only moves its start clock')
edit('T04', 'tests', P02, CORE,
     L('\t# pass-out: the natural midnight roll already started the new day, sleeping must not skip another one',
       '\tw["log"].clear()',
       '\t_set_clock(4, &"foraar", 1, 23, 58)',
       '\tgm.advance_time(3)',
       '\tvar rolled: bool = gm.day == 5 and gm.hour == 0 and gm.minute == 1 and _names(w["log"]).has("day_ended") and _names(w["log"]).count("game_event") == 1',
       '\tw["log"].clear()',
       '\tdays_passed = gm.sleep_until_morning()',
       '\tt.check("sleep_after_passout_no_double_day", rolled and days_passed == 0 and gm.day == 5 and gm.hour == 6 and gm.minute == 0 and _names(w["log"]) == ["time_of_day_changed"],',
       '\t\t"after midnight: wake at 06:00 of the same calendar day (day %d)" % gm.day)'),
     L('\t# pass-out: the natural 02:00 day roll already started the new day, sleeping must not skip another one',
       '\tw["log"].clear()',
       '\t_set_clock(4, &"foraar", 1, 25, 58)',
       '\tgm.advance_time(3)',
       '\tvar rolled: bool = gm.day == 5 and gm.hour == 2 and gm.minute == 1 and _names(w["log"]).has("day_ended") and _names(w["log"]).count("game_event") == 1',
       '\tw["log"].clear()',
       '\tdays_passed = gm.sleep_until_morning()',
       '\tt.check("sleep_after_passout_no_double_day", rolled and days_passed == 0 and gm.day == 5 and gm.hour == 6 and gm.minute == 0 and _names(w["log"]) == ["time_of_day_changed"],',
       '\t\t"after the 02:00 roll: wake at 06:00 of the same calendar day (day %d)" % gm.day)'),
     'MEASURED to fail: 23:58 + 3 min is no longer a day roll; the pass-out case is now 01:58 + 3 min -> 02:01 of the new date. The bed AFTER midnight is a NEW check in clock26 (bed_after_midnight_passes_one_day)')
edit('T05', 'tests', P02, CORE,
     L('\t# ticking across midnight keeps the calendar exact',
       '\t_set_clock(1, &"foraar", 1, 23, 59)',
       '\ttm.tick(0.5)',
       '\tt.check("tick_crosses_midnight", gm.day == 2 and gm.hour == 0 and gm.minute == 0, "23:59 + 1 tick = day 2 00:00")'),
     L('\t# ticking across midnight does NOT end the day (it runs to 02:00); ticking across 02:00 keeps the calendar exact',
       '\t_set_clock(1, &"foraar", 1, 23, 59)',
       '\ttm.tick(0.5)',
       '\tvar past_midnight: bool = gm.day == 1 and gm.hour == 24 and gm.minute == 0',
       '\t_set_clock(1, &"foraar", 1, 25, 59)',
       '\ttm.tick(0.5)',
       '\tt.check("tick_crosses_midnight", past_midnight and gm.day == 2 and gm.hour == 2 and gm.minute == 0, "23:59 + 1 tick = day 1 raw 24:00 (00:00 of the same day); 01:59 + 1 tick = day 2 02:00")'),
     'MEASURED to fail; core.day_fraction (noon = 0.5) and core.is_night_from_config stay green UNCHANGED under C08 / the raw-hour is_night; their late-hour cases are clock26 checks')

AREA = 'tests/sections/area.gd'
P04 = 'P04-area-framework (built)'
edit('T06', 'tests', P04, AREA,
     L('\tvar room2: IsoArea = _world.area',
       '\tgm.set("hour", 23)',
       '\tgm.set("minute", 50)'),
     L('\tvar room2: IsoArea = _world.area',
       '\tgm.set("hour", gm.day_end_hour() - 1)         # the last hour of the game day (01:50 at day_end_hour 26): +20 min crosses the day end',
       '\tgm.set("minute", 50)'),
     'MEASURED to fail with only day_end_hour = 26: area.rebuild_queued_during_the_pass_out (23:50 + 20 min is 00:10 of the same day, nobody passes out). The WORLD code (world_2d.gd) needs NO change: '
     'harness_area_25h50.log = 240 area checks, 0 failed once the clock literal moved')
edit('T07', 'tests', P04, AREA,
     '\t\t"the day roll of advance_time (before midnight_passed) queued the rebuild, the pass-out night ran it exactly once behind the black screen (builder calls %d -> %d)" % [built1, built_calls.size()])',
     '\t\t"the day roll of advance_time at the day end (before midnight_passed) queued the rebuild, the pass-out night ran it exactly once behind the black screen (builder calls %d -> %d)" % [built1, built_calls.size()])',
     'message only')
edit('T08', 'tests', P04, AREA,
     L('\t# pass-out: the clock crosses midnight (GameManager emits game_event midnight_passed) -> sleep clip, fade, wake at day_start_hour, NOT a skipped day',
       '\tgm.set("hour", 23)',
       '\tgm.set("minute", 50)'),
     L('\t# pass-out: the clock crosses the DAY END 26:00 = 02:00 (GameManager emits game_event midnight_passed) -> sleep clip, fade, wake at day_start_hour, NOT a skipped day',
       '\tgm.set("hour", gm.day_end_hour() - 1)',
       '\tgm.set("minute", 50)'),
     'the second pin: area.pass_out_at_midnight (renamed pass_out_at_day_end by T09: nothing outside the file references the id)')
edit('T09', 'tests', P04, AREA,
     L('\tt.check("pass_out_at_midnight", sleeping_now and done'),
     L('\tt.check("pass_out_at_day_end", sleeping_now and done'),
     'the id said "midnight"; the check proves the 02:00 pass-out (and clock26.no_pass_out_at_midnight proves the negative)')
edit('T10', 'tests', P04, AREA,
     '\t\t"23:50 + 20 min crosses midnight: one new day (%d -> %d), wake at 06:00, NOTIF_PASSED_OUT posted" % [day2, gm.get("day")])',
     '\t\t"01:50 (raw 25:50) + 20 min crosses the day end 02:00: one new day (%d -> %d), wake at 06:00, NOTIF_PASSED_OUT posted" % [day2, gm.get("day")])',
     'message only')

SAVE = 'tests/sections/save.gd'
P15 = 'P15-save-system (built)'
edit('T11', 'tests', P15, SAVE,
     L('\tt.check("autosave_coalesces_midnights", _saved_slots == [6], "50 hours crossed two midnights, save_completed %s" % [_saved_slots])',
       '\t# the switch stops the DAY-END trigger as well as the timer: at the day end itself, and for a save that is already queued'),
     L('\tt.check("autosave_coalesces_midnights", _saved_slots == [6], "50 hours crossed two midnights, save_completed %s" % [_saved_slots])',
       '\t# the pass-out roll (02:00) is a day end too: ONE auto save, taken at the restart hour of the new date (the sleep sequence has not woken the player yet);',
       '\t# real midnight (raw 24:00) is NOT a day end: nothing is saved there (the 5 minute timer covers 00:00-02:00)',
       '\tDirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))',
       '\t_saved_slots.clear()',
       '\tgm.hour = 23',
       '\tgm.minute = 55',
       '\tgm.advance_time(10)',
       '\tawait t.frames(2)',
       '\tvar no_save_at_midnight: bool = _saved_slots.is_empty() and not sm.has_save(sm.AUTO_SLOT) and gm.hour == 24',
       '\tgm.hour = gm.day_end_hour() - 1',
       '\tgm.minute = 55',
       '\tvar roll_day: int = gm.day',
       '\tgm.advance_time(10)',
       '\tawait t.frames(2)',
       '\tvar roll_doc: Variant = _read_json(sm.slot_path(sm.AUTO_SLOT))',
       '\tt.check("autosave_on_the_day_end_roll", no_save_at_midnight and _saved_slots == [6] and roll_doc != null and roll_doc["game"]["day"] == roll_day + 1 and roll_doc["game"]["hour"] == gm.day_roll_restart_hour(),',
       '\t\t"23:55 + 10 min = raw 24:05: no save; 01:55 + 10 min = the day-end roll: one auto save of day %s at raw hour %s (restart hour %d); save_completed %s" % [roll_doc["game"]["day"] if roll_doc != null else "-", roll_doc["game"]["hour"] if roll_doc != null else "-", gm.day_roll_restart_hour(), _saved_slots])',
       '\t# the switch stops the DAY-END trigger as well as the timer: at the day end itself, and for a save that is already queued'),
     'NEW check in the owner\'s sandbox (the autosave preconditions live here): the day-end autosave now fires at the 02:00 roll and NOT at 24:00 (no day_ended there); the deferred save runs in the roll\'s own frame, before the 0.7 s sleep fade has woken the player: '
     'Continue resumes at 02:00 awake with the new date (the same quirk the 00:00 roll had; open question Q4 of the addendum)')
edit('T12', 'tests', P15, SAVE,
     L('\tt.check("summary_types", typeof(s["day"]) == TYPE_INT and typeof(s["gold"]) == TYPE_INT and typeof(s["total_day"]) == TYPE_INT and typeof(s["play_time_seconds"]) == TYPE_FLOAT, "ints after the JSON round trip")',
       '\tgm.play_time_seconds = 600.0                                     # a whole number of seconds is an int after the JSON load, the summary says float'),
     L('\tt.check("summary_types", typeof(s["day"]) == TYPE_INT and typeof(s["gold"]) == TYPE_INT and typeof(s["total_day"]) == TYPE_INT and typeof(s["play_time_seconds"]) == TYPE_FLOAT, "ints after the JSON round trip")',
       '\t# the game day runs to 02:00: a save at raw 25:40 (01:40, the same game day) keeps hour 25 in the summary and loads back as 25:40 (the summary validator has no hour range);',
       '\t# a file that a build of the 24:00 days wrote right after its midnight roll (hour 0) loads as 02:00, not 24 h later; hours 6..23 of old saves are untouched (core.from_dict_* of clock26)',
       '\tgm.hour = 25',
       '\tgm.minute = 40',
       '\tsm.save_game(3)',
       '\tvar late: Dictionary = sm.get_save_summary(3)',
       '\tgm.hour = 6',
       '\tgm.minute = 0',
       '\tvar late_loaded: bool = sm.load_game(3)',
       '\tvar late_back: bool = gm.hour == 25 and gm.minute == 40 and gm.day == 16',
       '\tvar old_doc: Variant = _read_json(sm.slot_path(3))',
       '\told_doc["game"]["hour"] = 0',
       '\told_doc["meta"]["summary"]["hour"] = 0',
       '\t_put(3, old_doc)',
       '\tvar old_loaded: bool = sm.load_game(3)',
       '\tt.check("save_late_hour_roundtrip_and_old_midnight_save", late.get("hour") == 25 and late.get("minute") == 40 and late_loaded and late_back and old_loaded and gm.hour == 2 and gm.day == 16,',
       '\t\t"raw 25:40 -> summary %s:%s, loads back %s; an old save at hour 0 loads at raw %02d:%02d (day %d)" % [late.get("hour"), late.get("minute"), late_back, gm.hour, gm.minute, gm.day])',
       '\tsm.delete_save(3)',
       '\tgm.play_time_seconds = 600.0                                     # a whole number of seconds is an int after the JSON load, the summary says float'),
     'NEW check in the owner\'s sandbox: a slot file written at 01:40 round-trips with hour 25 (no SAVE_VERSION bump, no summary range), an old file at hour 0 is lifted to 02:00')

# ======================================================================================================== DATA / DOCS OF THE BALANCE MODEL (F1, built)
F1 = 'F1-feature-data (built)'
edit('B01', 'data', F1, 'tools/features/sim/balance_sim.py',
     L('REAL_MIN_PER_DAY = 9.0                     # PLAN 3.9: 06:00-24:00 at 2 game minutes per real second',
       'DAYS_PER_HOUR = 60.0 / REAL_MIN_PER_DAY    # 6.667 game days per real hour'),
     L('REAL_MIN_PER_DAY = 10.0                    # CLOCK_26: 06:00-02:00 (20 game hours) at 2 game minutes per real second = 600 s',
       'DAYS_PER_HOUR = 60.0 / REAL_MIN_PER_DAY    # 6.000 game days per real hour'),
     'the sim assumes the clock of PLAN 3.9: one game day = 9 real minutes -> 10. The DAY counts of BALANCE.md do not change (per-day output is bound by energy and chores, not by the clock; the clock is paused in the forest), the REAL-HOUR column grows by 11 %')
edit('B02', 'data', F1, 'tools/features/sim/balance_sim.py',
     "    P('BALANCE SIMULATION  (expected values, deterministic).  1 game day = 9 real minutes -> 6.67 days per real hour.')",
     "    P('BALANCE SIMULATION  (expected values, deterministic).  1 game day = 10 real minutes -> 6.00 days per real hour.')",
     'the printed header of the sim (the only other place that says 9 minutes)')
edit('B03', 'data', F1, 'docs/features/BALANCE.md',
     'Hours are REAL hours (one game day = 9 real minutes, 6.67 days per hour) until the Slottet (tier 10) is finished.',
     'Hours are REAL hours (one game day = 10 real minutes, 6.0 days per hour: the day runs 06:00-02:00, CLOCK_26) until the Slottet (tier 10) is finished. The day numbers do not depend on the clock; the real-hour figures of the tables below were computed for a 9 minute day (multiply them by 10 / 9) and are re-derived by `tools/features/sim/run_balance.sh --quests stage` (re-run in a clone: typical 345 d = 57.5 h, casual 919 d = 153.2 h, dedicated 185 d = 30.8 h).',
     'the reader of BALANCE.md must not read 51.8 h as the current figure; the tables themselves are regenerated from the sim (CK1 task), never edited by hand')
edit('B04', 'data', F1, 'docs/features/BALANCE.md',
     '* The hours do not include talking, walking or menus; 9 real minutes per game day is the PLAN\'s clock.',
     '* The hours do not include talking, walking or menus; 10 real minutes per game day is the clock of CLOCK_26 (06:00-02:00 at 2 game minutes per real second; it was 9 minutes in PLAN 3.9 when the day ended at 24:00).',
     'the second statement of the clock')

# ======================================================================================================== DOCS: the binding documents that state the old clock (lead edits, owner P01-project-config)
# Proven against main's CURRENT docs (apply --docs-from /Users/magnusudbjorg/Documents/projects/PongPong/docs/design). The ghost family addendum is NOT edited here: another designer rewrites it right
# now (cousin, hide and seek, festivals); its clock sentences are a HANDOFF text in CLOCK_26_ADDENDUM.md section 11. The work-package JSONs of the older addenda are NOT edited (their tasks are superseded
# by the amendments of clock_packages.json, which land in the work orders).
P01 = 'P01-project-config (built)'
PL = 'docs/design/PLAN_2D.md'
edit('X01', 'docs', P01, PL, '| PLAYABILITY: day/night, sleep in bed, midnight pass-out |', '| PLAYABILITY: day/night, sleep in bed, 02:00 pass-out (the game day runs 06:00-02:00, CLOCK_26) |', 'the pass-out is not at midnight any more')
edit('X02', 'docs', P01, PL, '06:00 to 24:00 = **9 real minutes per day**',
     '06:00 to 02:00 (game hours 6..25: the hours 24 and 25 are 00:xx and 01:xx of the same game day) = **10 real minutes per day** (CLOCK_26, user answer 2026-10-14)', 'the day length of PLAN 3.9')
edit('X03', 'docs', P01, PL, '24:00 passes the player out (sleep clip', '02:00 (game hour 26) passes the player out (sleep clip', 'the pass-out of PLAN 3.9')
edit('X04', 'docs', P01, PL, 'loop while hour >= 24 so multi-day skips are exact',
     'loop while hour >= day_end_hour (26) so multi-day skips are exact (each roll restarts the clock at 02:00 of the new date)', 'the P02 task text (BUILT; the fix round C04 is the new arithmetic)')
UI = 'docs/design/UI_NAVIGATION.md'
edit('X05', 'docs', P01, UI, 'bed `interact` / midnight |', 'bed `interact` / the 02:00 pass-out |', 'registry row of the sleep fade')
edit('X06', 'docs', P01, UI, 'bed and midnight pass-out: fade', 'bed and the 02:00 pass-out (and no pass-out at midnight): fade', 'P27 acceptance row')
TW = 'docs/design/TOWNS_FARM_SOCIAL_ADDENDUM.md'
edit('X07', 'docs', P01, TW, '`close < open` wraps midnight',
     '`close < open` is the after-midnight notation (close 1 = 25.0 = 01:00 of the SAME game day; GameManager.game_hour() normalises it; the hours 24..26 belong to the game day, nothing wraps into the next calendar day)',
     'the Hours rule on the 26 hour day (T-towns-core amendment CK-TC)')
edit('X08', 'docs', P01, TW,
     '* **Night.** At 23:30 a whisper, at 23:45 the night watch sends you home to `farm:from_home`; the bed opens at 18:00.',
     '* **Night.** At 01:30 a whisper, at 01:45 the night watch sends you home to `farm:from_home` (the day ends with the 02:00 pass-out; `towns.curfew` 25.5 / 25.75, CLOCK_26 Q1); the bed opens at 18:00.',
     'the player story of the night; default of Q1')
edit('X09', 'docs', P01, TW,
     'in a town area (not the farm, not a home) at 23:30 the whisper `HOURS_CURFEW_SOON` "Det er blevet sent. Tid til at gå hjem.", at 23:45 `HOURS_CURFEW_HOME` "Nattevagten følger dig hjem." + `area_change_requested(farm, from_home)`; held during any modal and retried next tick; `towns.curfew {enabled, whisper 23.5, go_home 23.75}`; protects the hour where the 24:00 pass-out would wake the player in a shop; coexists with D0\'s pass-out relocation.',
     'in a town area (not the farm, not a home) at 01:30 the whisper `HOURS_CURFEW_SOON` "Det er blevet sent. Tid til at gå hjem.", at 01:45 `HOURS_CURFEW_HOME` "Nattevagten følger dig hjem." + `area_change_requested(farm, from_home)`; held during any modal and retried next tick; `towns.curfew {enabled, whisper 25.5, go_home 25.75}` (game hours on the 6..26 axis; the day ends with the 02:00 pass-out); coexists with D0\'s pass-out relocation (which wakes the player at home anyway: the watch only spares the walk).',
     'DT24 on the 26 hour day: the same 30 / 15 minute cushions before the pass-out, moved by two hours (Q1 default); the first draft said the curfew protects the 24:00 pass-out')
edit('X10', 'docs', P01, TW, 'A festival window ends by 23:00 (the pass-out is at 24:00);',
     'A festival window ends by 25:00 (01:00; the pass-out is at 26:00 = 02:00; every shipped window still ends by 23:00, CLOCK_26 Q3);', 'DT25 and the validators SV9 / SV10')
edit('X11', 'docs', P01, TW, '**DT50 - The 24:00 pass-out wakes at home.**', '**DT50 - The 02:00 pass-out wakes at home.**', 'DT50 title')

# Found by reviewer A after X01-X11 were applied (grep of the patched docs): five statements of the SAME binding addendum still said the old clock and contradicted X08 / X09 in the same file (X12-X16);
# my own grep of the other binding documents found the dungeon defeat sentence (X17, X18). `check` proves each `before` matches exactly once in main's CURRENT text.
edit('X12', 'docs', P01, TW,
     'At 23:30 a whisper, at 23:45 the night watch sends the player to farm:from_home (held during modals; off on the farm and in homes).',
     'At 01:30 (game hour 25.5) a whisper, at 01:45 (25.75) the night watch sends the player to farm:from_home (the day ends with the 02:00 pass-out, `towns.curfew` 25.5 / 25.75, CLOCK_26 Q1; held during modals; off on the farm and in homes).',
     'DT24, the decision text of the night watch: the same 30 / 15 minute cushions before the pass-out as X08 / X09 (the player story and the contract row of the same file)')
edit('X13', 'docs', P01, TW,
     '| warm-clips rule R-V4 (walkers warm walk); the 24:00 pass-out wakes at farm:from_home |',
     '| warm-clips rule R-V4 (walkers warm walk); the 02:00 pass-out wakes at farm:from_home |',
     'the RT22 row of the amendment table (the same pass-out as X11 / DT50)')
edit('X14', 'docs', P01, TW,
     'At 23:45 a forced walk home to the farm door (whispered from 23:30, never during a modal) protects you from waking up in a shop.',
     'At 01:45 a forced walk home to the farm door (whispered from 01:30, never during a modal; the day ends with the 02:00 pass-out) protects you from waking up in a shop.',
     'Q6 (the night watch) of the user questions of the towns addendum: the default text is the player-facing promise')
edit('X15', 'docs', P01, TW,
     '2. The 24:00 PASS-OUT wakes at the door of the house (DT50)',
     '2. The 02:00 PASS-OUT wakes at the door of the house (DT50)',
     'the D0 task text of the same addendum (X11 changed the DT50 title only)')
edit('X16', 'docs', P01, TW,
     'carrots + move_and_slide, cap 16 looks, curfew 23:30 / 23:45',
     'carrots + move_and_slide, cap 16 looks, curfew 01:30 / 01:45 (25.5 / 25.75)',
     'the module overview of the architecture section')
DV = 'docs/design/DUNGEON_V2_ADDENDUM.md'
edit('X17', 'docs', P01, DV,
     '(the farm grows one day; before midnight the day-end autosave fires)',
     '(the farm grows one day; before the 02:00 day-end roll, the raw hours 6..25, the day-end autosave fires)',
     'the defeat sequence of the dungeon addendum: sleep_until_morning() ends the day while the raw hour is >= 6 (also 24:xx and 25:xx)')
edit('X18', 'docs', P01, DV,
     'a defeat after midnight still wakes at 06:00 of the same date;',
     'a defeat after the 02:00 day-end roll (raw hours 2..5) still wakes at 06:00 of the same date, a defeat at 00:xx or 01:xx (raw 24 / 25, the same game day) wakes at 06:00 of the NEXT date (CLOCK_26 CK-A-D0);',
     'the edge case of the same sentence (CK-A-D0 task 3 amends the work order; the binding text now agrees): midnight is not the end of the day any more')

DOC_FILES = sorted({e['file'] for e in E if e['stage'] == 'docs'})


# ======================================================================================================== engine
def _owner_id(label):
    return label.split(' ')[0]


def _is_built_label(label):
    return '(built)' in label


def apply(clone, stage='all', only=None, skip=None, docs_from=None, when=None):
    clone = Path(clone)
    if docs_from:
        for f in DOC_FILES:
            shutil.copyfile(Path(docs_from) / Path(f).name, clone / f)
    log = []
    for e in E:
        if stage != 'all' and e['stage'] != stage:
            continue
        if when is not None and e['when'] != when:
            continue
        if only is not None and e['id'] not in only:
            continue
        if skip is not None and e['id'] in skip:
            print('  skipped (mutation)', e['id'])
            continue
        p = clone / e['file']
        s = p.read_text()
        n = s.count(e['before'])
        if n != e['count']:
            raise SystemExit(f"{e['id']} {e['file']}: expected {e['count']} match(es) of {e['before'][:90]!r}, found {n}")
        p.write_text(s.replace(e['before'], e['after']))
        log.append(e['file'])
    if stage in ('all', 'tests') and only is None and when in (None, 'fix'):
        for dest, (src, _pkg) in NEW_FILES.items():
            if skip is not None and 'N01' in skip:
                continue
            shutil.copyfile(HERE / src, clone / dest)
            log.append(dest)
    print('applied', stage, len(log), 'edits / files in', len(set(log)), 'files')
    for f in sorted(set(log)):
        print('  ', f)


def check(root=BASE, docs_from=None):
    sys.path.insert(0, str(HERE / 'audit'))
    import who_owns
    root = Path(root)
    owners = json.load(open('/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/impl/owners.json'))
    built_ids = set(json.load(open('/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/impl/built_ids.json')))
    wave = {pid: v['wave'] for pid, v in owners['owners'].items()}
    pinned = set(re.findall(r'"res://([^"]+)":\s*"[0-9a-f]{64}"', (root / 'tests/sections/city_levels.gd').read_text()))
    problems = []
    ids = [e['id'] for e in E]
    if len(ids) != len(set(ids)):
        problems.append(('duplicate edit id', [i for i in ids if ids.count(i) > 1]))
    seen = {}
    for e in E:
        base_file = (Path(docs_from) / Path(e['file']).name) if (e['stage'] == 'docs' and docs_from) else root / e['file']
        if not base_file.exists():
            problems.append((e['id'], 'file does not exist', str(base_file)))
            continue
        txt = base_file.read_text()
        # earlier edits of the same file may have changed the text: apply them in memory in order
        txt = seen.get(e['file'], txt)
        n = txt.count(e['before'])
        if n != e['count']:
            problems.append((e['id'], f"expected {e['count']} match(es), found {n}", e['before'][:80]))
            continue
        seen[e['file']] = txt.replace(e['before'], e['after'])
        owner = _owner_id(e['pkg'])
        if owner not in who_owns.owners_of(e['file']):
            problems.append((e['id'], 'owner label is not an owner of the file in owners.json', e['pkg'], e['file'], who_owns.owners_of(e['file'])))
        built = owner in built_ids or wave.get(owner) in ('1', '2', '3')
        if _is_built_label(e['pkg']) != built:
            problems.append((e['id'], 'built flag disagrees with impl/built_ids.json + waves 1-3', e['pkg'], built))
        if e['file'] in pinned:
            problems.append((e['id'], 'touches a sha-pinned file (city_levels.built_framework_files_untouched)', e['file']))
        if e['file'].startswith(('tools/art/drawn/', 'tools/art/storybook/', 'assets/')):
            problems.append((e['id'], 'touches a Codex file', e['file']))
    print(f'check: {len(E)} edits in {len({e["file"] for e in E})} files; pinned files {sorted(pinned)}')
    for p in problems:
        print('  PROBLEM', p)
    print('RESULT:', 'OK, every before matches exactly once, every owner is right, no pinned / Codex file' if not problems else f'{len(problems)} problem(s)')
    return 1 if problems else 0


def md():
    out = ['| id | stage | owner (owners.json) | file | why | exact edit (before -> after) |', '|---|---|---|---|---|---|']

    def cell(t):
        t = t.replace('\t', '    ').replace('\n', ' ⏎ ').replace('|', '\\|')
        return '`' + (t if len(t) < 300 else t[:290] + ' ...') + '`'
    for e in E:
        out.append(f"| {e['id']} | {e['stage']} | {e['pkg']} | `{e['file']}` | {e['why']} | {cell(e['before'])} → {cell(e['after'])} |")
    for dest, (src, pkg) in NEW_FILES.items():
        out.append(f"| N01 | tests | {pkg} (NEW package) | `{dest}` | the new section: every new check of the clock contract | new file `{src}` |")
    print('\n'.join(out))


def _arg(flag):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else None


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'apply':
        apply(sys.argv[2], _arg('--stage') or 'all', _arg('--only').split(',') if _arg('--only') else None,
              _arg('--except').split(',') if _arg('--except') else None, _arg('--docs-from'), _arg('--when'))
    elif cmd == 'check':
        sys.exit(check(_arg('--root') or BASE, _arg('--docs-from')))
    elif cmd == 'md':
        md()
    elif cmd == 'json':
        print(json.dumps(E, ensure_ascii=False, indent=1))
