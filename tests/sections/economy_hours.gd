extends RefCounted
## Section economy_hours (package P12, FIX ROUND RT5 of the towns / farm / social addendum, docs/design/TOWNS_FARM_SOCIAL_ADDENDUM.md DT12 / DT55 / DT58):
## the opening-hours hook of ShopSystem and the seed supply of the dedicated farm.
##
## ShopSystem.is_open asks the towns track's rule FIRST, through the helper ShopHoursGate (scripts/economy/shop_hours_gate.gd; the rule is
## scripts/towns/hours.gd, class Hours, T-towns-core, wave 4 - it does not exist yet): true / false decide alone, null (no building claims the shop, the switch
## towns.hours_enabled is false, or the towns track is absent) leaves the weekday rule of the shop def (open_weekdays) in charge. A closed shop refuses buy and sell
## (reason `closed`) and get_shop_info gains closed_reason / opens_at / next_open_weekday. The opening hours are NOT shop def fields: they live in the buildings registry (DT12).
##
## THE RULE IS A TEST DOUBLE HERE. The real Hours does not exist in this tree, so the section writes a stand-in script under user:// (PROBE_SOURCE) and points the gate at it
## (ShopHoursGate.use_hours_script): the stand-in follows the contract of the 26 hour game day (docs/design/CLOCK_26_ADDENDUM.md: RAW game hours 6..25 on the clock, an authored
## hour below the day start is after midnight of the SAME game day through GameManager.game_hour(), the weekday is the game day's) and asks a fake SocialManager first for
## the festival closure, like the real rule does. What the section proves is the WIRING (the gate, the switch, ShopSystem's answers and refusals, no third static_call line);
## the Hours rule itself is proven by T-towns-core's own section (towns_data.hours_after_midnight and friends). Once scripts/towns/hours.gd exists, one check compares the
## gate with the real rule for every shop.
##
## Named checks (prefix economy_hours.): shop_closed_refuses, shop_info_closed_reason, unclaimed_shop_keeps_weekday_rule, switch_off_ignores_the_buildings,
## shop_system_keeps_two_static_call_lines, carved_out_files_have_other_owners, seed_supply_covers_a_dedicated_field; and after_midnight_hours_pass_through,
## the_gate_answers_in_the_shape_the_shop_screen_reads, real_hours_rule_matches_the_gate (SKIP until T-towns-core).
##
## Which clock the section runs at (DT55): this IS a section about opening hours, so the switch stays ON (the default) and every check sets the game clock explicitly
## (Monday 12:00 unless it names another time). The section is a sandbox: probe script, fake SocialManager, Engine meta, config override and the gate's script path
## are all put back before it ends.
const SECTION := "economy_hours"
const TIMEOUT_S := 150.0

const Gate := preload("res://scripts/economy/shop_hours_gate.gd")
const PROBE_PATH := "user://p12_probe_hours.gd"
const NO_SUCH_HOURS := "user://p12_probe_no_such_hours.gd"
const META_RULES := "p12_probe_hours_rules"
const META_CALLS := "p12_probe_hours_calls"
## the carved-out files: path, LuaRuntime script id, owning package (the files do not exist before their package is built)
const CARVED_OUT: Array = [
	["lua/shops/festival_markets.lua", "shops/festival_markets", "S-fest-content"],
	["lua/recipes/social.lua", "recipes/social", "S-marriage"],
	["lua/shops/greenhouse_seeds.lua", "shops/greenhouse_seeds", "N07-farm-greenhouse (only if the greenhouse is activated)"],
]
## the balance model's profiles when tools/features/sim/balance_sim.py cannot be read: name -> [plots, eff]
const MODEL_FALLBACK := {"casual": [30, 0.55], "typical": [70, 0.70], "dedicated": [110, 0.85]}
## Sundays: the seed shop is closed one day a week (the towns buildings registry carries it; the probe does here)
const SEED_SHOP_CLOSED_WEEKDAYS: Array = [6]

## The stand-in of scripts/towns/hours.gd. rules = Engine meta META_RULES: {shop_id: {open, close, closed: [weekdays], festival_aware, shape: "state" | "final"}}; a shop
## without a rule answers null (no building claims it). Every call is appended to META_CALLS as "method:shop_id".
const PROBE_SOURCE := """extends RefCounted
static func _rule(method: String, shop_id: String) -> Variant:
	var calls: Array = Engine.get_meta("p12_probe_hours_calls", [])
	calls.append("%s:%s" % [method, shop_id])
	Engine.set_meta("p12_probe_hours_calls", calls)
	var rules: Dictionary = Engine.get_meta("p12_probe_hours_rules", {})
	return rules.get(shop_id, null)

static func _next_open(weekday: int, closed: Array) -> int:
	for i in range(1, 8):
		if not ((weekday + i) % 7 in closed):
			return (weekday + i) % 7
	return weekday

static func _state(shop_id: String, rule: Dictionary) -> Dictionary:
	var gm: Node = Svc.node("GameManager")
	var tm: Node = Svc.node("TimeManager")
	var weekday: int = int(tm.call("weekday_index"))
	var hour: float = float(gm.get("hour")) + float(gm.get("minute")) / 60.0
	var opens: float = float(gm.call("game_hour", float(rule.get("open", 6.0))))
	var closes: float = float(gm.call("game_hour", float(rule.get("close", 26.0))))
	var closed: Array = rule.get("closed", [])
	var st := {"open": false, "reason": "hours", "opens_at": opens, "closes_at": closes, "next_weekday": weekday}
	var social: Node = Svc.node("SocialManager")
	if bool(rule.get("festival_aware", false)) and social != null and social.has_method("shop_closed_by_festival") and bool(social.call("shop_closed_by_festival", shop_id)):
		st["reason"] = "festival"
		return st
	if weekday in closed:
		st["reason"] = "day"
		st["next_weekday"] = _next_open(weekday, closed)
		return st
	if hour < opens:
		return st
	if hour >= closes:
		st["next_weekday"] = _next_open(weekday, closed)
		return st
	st["open"] = true
	st["reason"] = "open"
	return st

static func shop_open(shop_id: String, _ctx: Dictionary = {}) -> Variant:
	var rule: Variant = _rule("shop_open", shop_id)
	if rule == null:
		return null
	return bool(_state(shop_id, rule)["open"])

static func closed_info(shop_id: String, _ctx: Dictionary = {}) -> Dictionary:
	var rule: Variant = _rule("closed_info", shop_id)
	if rule == null:
		return {}
	var st: Dictionary = _state(shop_id, rule)
	if str((rule as Dictionary).get("shape", "state")) == "final":
		return {"closed_reason": st["reason"], "opens_at": st["opens_at"], "next_open_weekday": st["next_weekday"]}
	return st
"""


## stands in for the social track's SocialManager: only shop_closed_by_festival(shop_id) is read
class FakeSocial extends Node:
	var closed_shops: Array = []
	func shop_closed_by_festival(shop_id: String) -> bool:
		return shop_id in closed_shops


var t
var eco: Node
var shop: Node
var gm: Node
var tm: Node
var lr: Node
var bus: Node
var _fakes: Array[Node] = []


func run(p_t) -> void:
	t = p_t
	eco = t.autoload("EconomyManager")
	shop = t.autoload("ShopSystem")
	gm = t.autoload("GameManager")
	tm = t.autoload("TimeManager")
	lr = t.autoload("LuaRuntime")
	bus = t.autoload("EventBus")
	if eco == null or shop == null or gm == null or tm == null or lr == null or bus == null:
		return
	await t.go_menu()
	_write_probe()
	_closed_shop_refuses()
	_info_closed_reason()
	_unclaimed_shop_keeps_the_weekday_rule()
	_switch_off()
	_after_midnight()
	_gate_shapes()
	_two_static_call_lines()
	_carved_out_files()
	_real_hours_rule()
	_seed_supply()
	_cleanup()


# ================================================================================================ helpers

func _write_probe() -> void:
	var file := FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	file.store_string(PROBE_SOURCE)
	file.close()


## A new game with the gate pointed at the stand-in (rules and call log cleared), Monday 12:00.
func _fresh(rules: Dictionary = {}) -> void:
	_release_fakes()
	gm.clear_config_overrides()
	t.new_game()
	Gate.use_hours_script(PROBE_PATH)
	Engine.set_meta(META_RULES, rules)
	Engine.set_meta(META_CALLS, [])
	_set_clock(1, 12, 0)


func _set_clock(day: int, hour: int, minute: int) -> void:
	gm.day = day
	gm.season = &"foraar"
	gm.year = 1
	gm.hour = hour
	gm.minute = minute


func _calls() -> Array:
	return Engine.get_meta(META_CALLS, [])


func _fake(node: Node) -> Node:
	_fakes.append(node)
	return node


func _release_fakes() -> void:
	Svc.clear_overrides()
	for n in _fakes:
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_fakes.clear()


func _inv() -> Dictionary:
	var out := {}
	var raw: Dictionary = eco.get_inventory_dict()
	for k in raw:
		out[str(k)] = int(raw[k])
	return out


func _row(shop_id: String, item_id: StringName) -> Dictionary:
	for row in shop.get_shop_inventory(shop_id):
		if row["item_id"] == item_id:
			return row
	return {}


## a day rule for the seed shop: open 08:00-18:00, closed on Sundays
func _seed_rule(extra: Dictionary = {}) -> Dictionary:
	var rule := {"open": 8, "close": 18, "closed": [6]}
	rule.merge(extra, true)
	return {"seed_shop": rule}


# ================================================================================================ the closed shop

func _closed_shop_refuses() -> void:
	_fresh(_seed_rule())
	eco.add_gold(2000)
	eco.add_item(&"wood", 3, true)
	t.expect(shop.get_sell_price("seed_shop", &"wood") > 0, "precondition: the seed shop pays for wood (%d each)" % shop.get_sell_price("seed_shop", &"wood"))
	var open_monday: bool = shop.is_open("seed_shop")
	var bought: bool = shop.buy_item("seed_shop", &"carrot_seeds", 2)
	var sold: bool = shop.sell_item("seed_shop", &"wood", 1)
	t.expect(open_monday and bought and sold and shop.last_refusal == &"", "Monday 12:00 (open 08-18): the shop is open, buying and selling work")
	# Monday 07:00: before opening (the hours rule), Sunday 12:00: the closed day (the day rule)
	var scenes := {"Monday 07:00": [1, 7, 0, "hours"], "Sunday 12:00": [7, 12, 0, "day"], "Monday 18:00": [1, 18, 0, "hours"]}
	var all_refused := true
	var shown: Array = []
	for label in scenes:
		var s: Array = scenes[label]
		_set_clock(int(s[0]), int(s[1]), int(s[2]))
		var gold: int = eco.gold
		var before := _inv()
		var rows: Array[Dictionary] = shop.get_shop_inventory("seed_shop")
		var none_buyable := rows.size() > 0
		for row in rows:
			none_buyable = none_buyable and not bool(row["buyable"])
		var buy_refused: bool = not shop.buy_item("seed_shop", &"carrot_seeds", 1) and shop.last_refusal == &"closed"
		var sell_refused: bool = not shop.sell_item("seed_shop", &"wood", 1) and shop.last_refusal == &"closed"
		var untouched: bool = eco.gold == gold and _inv() == before
		var closed_info: bool = not shop.is_open("seed_shop") and bool(shop.get_shop_info("seed_shop")["closed"]) and not bool(shop.get_shop_info("seed_shop")["open"])
		var line := buy_refused and sell_refused and untouched and none_buyable and closed_info
		all_refused = all_refused and line
		shown.append("%s %s" % [label, line])
	var watcher := {"opened": 0}
	var on_opened := func(_id: StringName) -> void: watcher["opened"] += 1
	bus.shop_opened.connect(on_opened)
	var opened: bool = shop.open_shop("seed_shop")
	bus.shop_opened.disconnect(on_opened)
	_set_clock(1, 12, 0)
	var back: bool = shop.buy_item("seed_shop", &"carrot_seeds", 1) and shop.sell_item("seed_shop", &"wood", 1)
	# the hours rule decides ALONE once a building claims the shop: the flea market's own weekday list (open_weekdays 5, 6) does not veto an open building
	var flea: Dictionary = lr.get_shop("flea_market")
	Engine.set_meta(META_RULES, {"flea_market": {"open": 6, "close": 26, "closed": []}})
	_set_clock(3, 12, 0)                                         # Wednesday
	var rule_overrules: bool = not flea.is_empty() and flea.get("open_weekdays") == [5, 6] and shop.is_open("flea_market")
	Engine.set_meta(META_RULES, {"flea_market": {"open": 6, "close": 26, "closed": [2]}})
	var rule_closes: bool = not shop.is_open("flea_market")      # Wednesday is weekday 2: the building is closed on it
	t.check("shop_closed_refuses", all_refused and opened and watcher["opened"] == 1 and back and rule_overrules and rule_closes,
		"the hours rule closes the seed shop (%s): buy and sell refused with `closed`, nothing changes (gold, backpack), no row buyable, get_shop_info closed; open_shop still emits shop_opened (the screen shows the closed state) %s (%d); open again at 12:00: buying and selling work %s; the rule decides alone: the flea market (open_weekdays 5, 6) is open on a Wednesday when its building says so %s and closed when the building is closed %s" % [
			", ".join(shown), opened, watcher["opened"], back, rule_overrules, rule_closes])


# ================================================================================================ get_shop_info

func _info_closed_reason() -> void:
	_fresh(_seed_rule())
	var open_info: Dictionary = shop.get_shop_info("seed_shop")
	var open_ok: bool = not bool(open_info["closed"]) and not open_info.has("closed_reason") and not open_info.has("opens_at") and not open_info.has("next_open_weekday")
	# before opening: closed for hours, opens at 8.0 today (Monday = 0)
	_set_clock(1, 7, 0)
	var early: Dictionary = shop.get_shop_info("seed_shop")
	var early_ok: bool = bool(early["closed"]) and early.get("closed_reason") == "hours" and is_equal_approx(float(early.get("opens_at", -1.0)), 8.0) and early.get("next_open_weekday") == 0
	# after closing on a Saturday: the next open weekday skips the closed Sunday (Monday = 0)
	_set_clock(6, 18, 30)
	var late: Dictionary = shop.get_shop_info("seed_shop")
	var late_ok: bool = bool(late["closed"]) and late.get("closed_reason") == "hours" and late.get("next_open_weekday") == 0 and is_equal_approx(float(late.get("opens_at", -1.0)), 8.0)
	# the closed day: closed_reason day, back on Monday
	_set_clock(7, 12, 0)
	var sunday: Dictionary = shop.get_shop_info("seed_shop")
	var sunday_ok: bool = bool(sunday["closed"]) and sunday.get("closed_reason") == "day" and sunday.get("next_open_weekday") == 0 and sunday.get("opens_at") is float
	# a festival closes the shop inside the rule (the fake SocialManager answers shop_closed_by_festival first)
	var social := _fake(FakeSocial.new()) as FakeSocial
	Svc.override("SocialManager", social)
	social.closed_shops = ["seed_shop"]
	Engine.set_meta(META_RULES, _seed_rule({"festival_aware": true}))
	_set_clock(3, 12, 0)
	var festival: Dictionary = shop.get_shop_info("seed_shop")
	var festival_ok: bool = bool(festival["closed"]) and festival.get("closed_reason") == "festival" and not shop.buy_item("seed_shop", &"carrot_seeds", 1) and shop.last_refusal == &"closed"
	social.closed_shops = []
	var festival_over: bool = not bool(shop.get_shop_info("seed_shop")["closed"])
	# the legacy id general_store is the seed shop: the rule is asked with the resolved id
	Engine.set_meta(META_CALLS, [])
	_set_clock(7, 12, 0)
	var legacy: Dictionary = shop.get_shop_info("general_store")
	var asked: Array = _calls()
	var legacy_ok: bool = legacy.get("id") == "seed_shop" and legacy.get("closed_reason") == "day" and not asked.is_empty() and asked.all(func(c: String) -> bool: return c.ends_with(":seed_shop"))
	# a shop that the def's weekday list closes and no building claims has no closed_reason (the gate has nothing to say), an unknown shop has no info at all
	Engine.set_meta(META_RULES, {})
	_set_clock(3, 12, 0)
	var weekday_only: Dictionary = shop.get_shop_info("flea_market")
	var weekday_ok: bool = bool(weekday_only["closed"]) and not weekday_only.has("closed_reason") and not weekday_only.has("opens_at") and not weekday_only.has("next_open_weekday")
	var unknown_ok: bool = shop.get_shop_info("no_such_shop").is_empty()
	t.check("shop_info_closed_reason", open_ok and early_ok and late_ok and sunday_ok and festival_ok and festival_over and legacy_ok and weekday_ok and unknown_ok,
		"open shop has no closed_* keys %s; 07:00 -> hours, opens 8.0, next day 0 %s (%s); Saturday 18:30 -> hours, next open weekday 0 (Sunday skipped) %s; Sunday -> day, back Monday %s; a festival -> festival, buying refused %s and open again afterwards %s; the legacy id general_store asks the rule with seed_shop %s; closed by the def's weekday list only: closed and no closed_reason %s; unknown shop: {} %s" % [
			open_ok, early_ok, early.get("closed_reason"), late_ok, sunday_ok, festival_ok, festival_over, legacy_ok, weekday_ok, unknown_ok])


# ================================================================================================ null = the def's weekday rule

func _unclaimed_shop_keeps_the_weekday_rule() -> void:
	# no building claims the flea market: the rule answers null, open_weekdays 5, 6 (Saturday, Sunday) keep working
	_fresh({"seed_shop": {"open": 8, "close": 18, "closed": [6]}})
	var flea: Dictionary = lr.get_shop("flea_market")
	var results: Array = []
	var days_ok: bool = not flea.is_empty() and flea.get("open_weekdays") == [5, 6]
	var expected := {1: false, 2: false, 3: false, 4: false, 5: false, 6: true, 7: true, 8: false}
	for day in [1, 2, 3, 4, 5, 6, 7, 8]:
		_set_clock(day, 12, 0)
		var open: bool = shop.is_open("flea_market")
		results.append([day, open])
		days_ok = days_ok and open == expected[day] and bool(shop.get_shop_info("flea_market")["closed"]) == (not expected[day])
	var asked: bool = _calls().has("shop_open:flea_market")
	# a shop without open_weekdays that no building claims is always open (on a Sunday, while another shop's building is closed)
	_set_clock(7, 12, 0)
	var always: bool = shop.is_open("bakery") and not shop.is_open("seed_shop")
	# no hours rule at all (the towns track is absent, the script is missing): the same answers, no engine message
	var mark: int = t.log_mark()
	Gate.use_hours_script(NO_SUCH_HOURS)
	var absent := true
	for day in [3, 6, 7]:
		_set_clock(day, 12, 0)
		absent = absent and shop.is_open("flea_market") == (day >= 6) and shop.is_open("seed_shop")
	absent = absent and Gate.open_override("flea_market") == null and Gate.closed_info("flea_market").is_empty()
	t.expect_clean_since(mark, "an absent hours script logs no engine message")
	Gate.use_hours_script(PROBE_PATH)
	t.check("unclaimed_shop_keeps_weekday_rule", days_ok and asked and always and absent,
		"the rule answers null for the flea market (asked: %s) and open_weekdays 5, 6 decide: %s; a shop without weekdays stays open %s; without any hours script (scripts/towns absent) the same answers, nothing logged %s" % [asked, results, always, absent])


# ================================================================================================ the switch

func _switch_off() -> void:
	# the rule would close the seed shop (Sunday); with towns.hours_enabled false the rule is not even asked
	_fresh(_seed_rule())
	_set_clock(7, 12, 0)
	var on_closed: bool = not shop.is_open("seed_shop") and Gate.enabled() and Gate.open_override("seed_shop") == false
	Engine.set_meta(META_CALLS, [])
	gm.set_config_override("towns.hours_enabled", false)
	var off_gate: bool = not Gate.enabled() and Gate.open_override("seed_shop") == null and Gate.closed_info("seed_shop").is_empty()
	var off_open: bool = shop.is_open("seed_shop") and not bool(shop.get_shop_info("seed_shop")["closed"])
	eco.add_gold(500)
	var off_buys: bool = shop.buy_item("seed_shop", &"carrot_seeds", 1) and shop.last_refusal == &""
	var calls_while_off: Array = _calls().duplicate()
	var not_asked: bool = calls_while_off.is_empty()
	# the def's weekday rule is the only one left: the flea market follows open_weekdays 5, 6 whatever the buildings say
	Engine.set_meta(META_RULES, {"flea_market": {"open": 6, "close": 26, "closed": []}})
	_set_clock(3, 12, 0)
	var weekday_rules: bool = not shop.is_open("flea_market")
	_set_clock(6, 12, 0)
	weekday_rules = weekday_rules and shop.is_open("flea_market") and _calls().is_empty()
	# switched back on (the override removed, or set to true): the rule is asked again
	gm.set_config_override("towns.hours_enabled", true)
	_set_clock(3, 12, 0)
	var back_on: bool = Gate.enabled() and shop.is_open("flea_market") and _calls().has("shop_open:flea_market")
	gm.clear_config_overrides()
	var default_on: bool = Gate.enabled()
	t.check("switch_off_ignores_the_buildings", on_closed and off_gate and off_open and off_buys and not_asked and weekday_rules and back_on and default_on,
		"switch on: the Sunday seed shop is closed %s; towns.hours_enabled = false: the gate answers null / {} %s, the shop is open %s and sells %s, the rule was never asked %s (%s), the flea market follows open_weekdays alone %s; true again: asked again %s; the default (no override) is on %s" % [
			on_closed, off_gate, off_open, off_buys, not_asked, calls_while_off, weekday_rules, back_on, default_on])


# ================================================================================================ the 26 hour day

func _after_midnight() -> void:
	# a night shop, authored open 18, close 1 (= 25.0: 01:00 of the SAME game day, GameManager.game_hour normalises); Saturday = day 6 = weekday 5
	_fresh({"bakery": {"open": 18, "close": 1, "closed": []}})
	var scenes: Array = [[17, 59, false], [18, 0, true], [23, 59, true], [24, 30, true], [25, 30, false]]     # raw game hours: 24 = 00:xx, 25 = 01:xx
	var got: Array = []
	var ok := true
	for s in scenes:
		_set_clock(6, int(s[0]), int(s[1]))
		var open: bool = shop.is_open("bakery")
		got.append([s[0], s[1], open])
		ok = ok and open == bool(s[2])
	# closed again at 01:30 (raw 25:30): the numbers pass through the gate on the game-hour axis, unwrapped: it opens at 18.0
	var late: Dictionary = shop.get_shop_info("bakery")
	var late_ok: bool = bool(late["closed"]) and late.get("closed_reason") == "hours" and is_equal_approx(float(late.get("opens_at", -1.0)), 18.0)
	# a shop that OPENS after midnight (authored open 1 = 25.0, close 2 = 26.0): at 00:30 the gate reports opens_at 25.0 (not 1.0), at 01:30 it is open
	Engine.set_meta(META_RULES, {"bakery": {"open": 1, "close": 2, "closed": []}})
	_set_clock(6, 24, 30)
	var before: Dictionary = shop.get_shop_info("bakery")
	var before_ok: bool = bool(before["closed"]) and is_equal_approx(float(before.get("opens_at", -1.0)), 25.0)
	_set_clock(6, 25, 30)
	var opened: bool = shop.is_open("bakery")
	# the weekday is the GAME day's: Saturday 01:30 (raw 25:30) is still Saturday for the rule (a Sunday-closed shop that is open until 02:00 is open); the roll at 02:00 makes it Sunday
	Engine.set_meta(META_RULES, {"bakery": {"open": 18, "close": 2, "closed": [6]}})
	_set_clock(6, 25, 30)
	var sat_late: bool = shop.is_open("bakery")
	_set_clock(7, 2, 0)
	var sun_roll: bool = not shop.is_open("bakery") and shop.get_shop_info("bakery").get("closed_reason") == "day"
	t.check("after_midnight_hours_pass_through", ok and late_ok and before_ok and opened and sat_late and sun_roll,
		"night shop 18 -> 01: [raw hour, minute, open] %s %s; at 01:30 closed, opens_at 18.0 %s; a shop opening at authored 1: opens_at 25.0 (unwrapped) at 00:30 %s, open at 01:30 %s; Saturday 01:30 still Saturday %s, Sunday after the 02:00 roll %s" % [
			got, ok, late_ok, before_ok, opened, sat_late, sun_roll])


# ================================================================================================ the shape of the answers

func _gate_shapes() -> void:
	# both shapes of the rule's closed_info reach the shop screen as {closed_reason, opens_at, next_open_weekday}
	var shapes: Array = []
	var ok := true
	for shape in ["state", "final"]:
		_fresh(_seed_rule({"shape": shape}))
		_set_clock(7, 12, 0)
		var info: Dictionary = Gate.closed_info("seed_shop")
		var good: bool = info.keys().size() == 3 and info.get("closed_reason") == "day" and info.get("opens_at") is float and info.get("next_open_weekday") is int and info["next_open_weekday"] == 0
		_set_clock(1, 12, 0)
		good = good and Gate.closed_info("seed_shop").is_empty() and Gate.open_override("seed_shop") == true
		shapes.append("%s %s" % [shape, good])
		ok = ok and good
	# an unclaimed shop and a rule that says nothing: {}
	_fresh({})
	ok = ok and Gate.closed_info("seed_shop").is_empty() and Gate.open_override("seed_shop") == null
	t.check("the_gate_answers_in_the_shape_the_shop_screen_reads", ok, "closed_info -> exactly closed_reason (String), opens_at (float), next_open_weekday (int) for both the state shape and the final shape of the rule: %s; {} when open or unclaimed" % [shapes])


# ================================================================================================ the pin

func _two_static_call_lines() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/economy/shop_system.gd")
	var gate_source := FileAccess.get_file_as_string("res://scripts/economy/shop_hours_gate.gd")
	var code := _code_of(source)
	var gate_code := _code_of(gate_source)
	var bare := code.replace("preload(", "")
	var calls := _count_lines(code, "static_call(")
	var gate_calls := _count_lines(gate_code, "static_call(")
	var late_bound: bool = code.contains("static_call(_rotation_script, &\"stock\"") and code.contains("static_call(_curve_script, &\"final_price\"")
	var gate_asked: bool = gate_code.contains("static_call(_hours_script, &\"shop_open\"") and gate_code.contains("static_call(_hours_script, &\"closed_info\"")
	var uses_gate: bool = code.contains("preload(\"res://scripts/economy/shop_hours_gate.gd\")") and code.contains("open_override(") and code.contains("closed_info(")
	var forward_free := _forward_free()
	var loads_nothing: bool = not code.contains("ResourceLoader") and not bare.contains("load(") and not code.contains("callv(") and not code.contains("get_script_method_list")
	var towns_absent := not ResourceLoader.exists("res://scripts/towns/hours.gd")
	t.check("shop_system_keeps_two_static_call_lines", calls == 2 and late_bound and gate_calls == 2 and gate_asked and uses_gate and forward_free and loads_nothing,
		"shop_system.gd has %d `static_call(` code lines (ShopRotation.stock, PriceCurve.final_price: the economy.late_binding_via_svc pin) %s; the hours rule is asked in ONE helper, shop_hours_gate.gd (%d call sites: shop_open, closed_info) %s, which shop_system.gd reaches through %s; shop_system.gd names no Hours / Routines / SocialManager / scripts/towns / festival and the helper names no class of the towns or social track %s; no load / ResourceLoader / callv %s; scripts/towns %s and both files compile" % [
			calls, late_bound, gate_calls, gate_asked, uses_gate, forward_free, loads_nothing, "absent" if towns_absent else "present"])


## No direct reference to the towns or social track in ShopSystem or the gate (a parse error until that track landed): no path, no class name, no autoload name,
## no festival knowledge. The festival closure is the hours rule's business (it asks SocialManager.shop_closed_by_festival itself). Whole-line comments are not code.
func _forward_free() -> bool:
	var code := _code_of(FileAccess.get_file_as_string("res://scripts/economy/shop_system.gd"))
	var gate_code := _code_of(FileAccess.get_file_as_string("res://scripts/economy/shop_hours_gate.gd"))
	var classes := RegEx.new()
	classes.compile("\\b(Hours|Routines|SocialManager|TownDirector)\\b|festival")
	var path_rx := RegEx.new()
	path_rx.compile("scripts/towns")
	return classes.search(code) == null and path_rx.search(code) == null and classes.search(gate_code) == null


## the code lines of a script: no whole-line comments (the same reading as economy.late_binding_via_svc)
func _code_of(source: String) -> String:
	var lines: Array[String] = []
	for line in source.split("\n"):
		var text := line.strip_edges()
		if not text.begins_with("#"):
			lines.append(text)
	return "\n".join(lines)


func _count_lines(code: String, needle: String) -> int:
	var n := 0
	for line in code.split("\n"):
		n += 1 if line.contains(needle) else 0
	return n


# ================================================================================================ the carve-outs

func _carved_out_files() -> void:
	# three NEW files inside P12's globs belong to other packages. ShopSystem keeps answering is_open as the towns track's rule decides, and that rule asks
	# SocialManager.shop_closed_by_festival(shop_id) first: neither ShopSystem nor the gate knows a festival (the source scan of shop_system_keeps_two_static_call_lines),
	# and a market closed by a festival is closed through ShopSystem all the same (the fake SocialManager below).
	var present: Array[String] = []
	for entry in CARVED_OUT:
		var path: String = entry[0]
		if FileAccess.file_exists("res://" + path):
			present.append(path)
			t.expect(lr.has_script(str(entry[1])), "%s (%s) exists and LuaRuntime registered it (data.kinds_shops_recipes validates its content)" % [path, entry[2]])
		else:
			t.skip("economy_hours.carved_out_%s: %s is %s's file and does not exist yet; its content is proven by that package's own gate (data.kinds_shops_recipes covers the file once it exists)" % [path.get_file().get_basename(), path, entry[2]])
	# P12 does not ship what the carve-outs carry: its own shop files hold exactly the shops of the base, none of them a festival market
	var own_shops := ["seed_shop", "bakery", "smithy", "magic_store", "animal_store"]
	var own_ok := true
	for id in own_shops:
		own_ok = own_ok and lr.get_shop(id).size() > 0 and not str(id).contains("festival") and not lr.get_shop(id).has("festival")
	for path in ["lua/shops/seed_shop.lua", "lua/shops/bakery.lua", "lua/shops/smithy.lua", "lua/shops/magic_store.lua", "lua/shops/animal_store.lua", "lua/recipes/guide_recipes.lua"]:
		own_ok = own_ok and not FileAccess.get_file_as_string("res://" + path).to_lower().contains("festival")
	# a festival closes a market through the one rule: the stand-in asks the fake SocialManager before the clock
	_fresh({"bakery": {"open": 6, "close": 26, "closed": [], "festival_aware": true}})
	var social := _fake(FakeSocial.new()) as FakeSocial
	Svc.override("SocialManager", social)
	var open_before: bool = shop.is_open("bakery")
	social.closed_shops = ["bakery"]
	eco.add_gold(300)
	var gold: int = eco.gold
	var knows_no_festival := _forward_free()
	var closed_by_festival: bool = not shop.is_open("bakery") and not shop.buy_item("bakery", &"flour", 1) and shop.last_refusal == &"closed" and eco.gold == gold and shop.get_shop_info("bakery").get("closed_reason") == "festival"
	social.closed_shops = []
	var reopened: bool = shop.is_open("bakery") and shop.buy_item("bakery", &"flour", 1)
	t.check("carved_out_files_have_other_owners", own_ok and knows_no_festival and open_before and closed_by_festival and reopened,
		"P12 ships its five shops and no festival market (festival_markets.lua is S-fest-content's, recipes/social.lua S-marriage's, greenhouse_seeds.lua N07's; present now: %s) %s; ShopSystem and the gate know no festival, no SocialManager, no towns class %s; a market the festival closes is closed through ShopSystem (is_open false, buy refused `closed`, closed_reason festival) %s and opens again %s: the festival is the hours rule's business" % [
			present, own_ok, knows_no_festival, closed_by_festival, reopened])


# ================================================================================================ the real rule

func _real_hours_rule() -> void:
	if not ResourceLoader.exists("res://scripts/towns/hours.gd"):
		t.skip("economy_hours.real_hours_rule_matches_the_gate: T-towns-core (scripts/towns/hours.gd, class Hours) is not built yet; towns_data.hours_after_midnight proves the rule on the 26 hour day, this section proves the wiring against its stand-in")
		return
	_release_fakes()
	gm.clear_config_overrides()
	t.new_game()
	Gate.use_hours_script()                                        # the contract's path: the REAL rule
	var diffs: Array = []
	for id in shop.get_shop_ids():
		var real: Variant = Svc.static_call(Gate.HOURS_SCRIPT, &"shop_open", [str(id)], null)
		var gate: Variant = Gate.open_override(str(id))
		if real != gate or (real != null and shop.is_open(id) != bool(real)):
			diffs.append([str(id), real, gate])
	gm.set_config_override("towns.hours_enabled", false)
	var off_ok: bool = true
	for id in shop.get_shop_ids():
		off_ok = off_ok and Gate.open_override(str(id)) == null
	gm.clear_config_overrides()
	t.check("real_hours_rule_matches_the_gate", diffs.is_empty() and off_ok, "ShopHoursGate.open_override equals Hours.shop_open and ShopSystem.is_open follows it for every shop at the new-game clock; differences %s; with towns.hours_enabled = false every answer is null %s" % [diffs, off_ok])


# ================================================================================================ seed supply

## What a dedicated farm needs of ONE seed: the balance model (tools/features/sim/balance_sim.py PROFILES) plants plots / (grow / eff + 1) a day: a plot is replanted
## after grow / eff days of growing plus one day of work. Returns {name: [plots, eff]}, read from the model when it can be read.
func _model_profiles() -> Dictionary:
	var profiles := MODEL_FALLBACK.duplicate(true)
	var source := FileAccess.get_file_as_string("res://tools/features/sim/balance_sim.py")
	var rx := RegEx.new()
	rx.compile("\\('([a-z]+)',\\s*dict\\(plots_cap=(\\d+),\\s*tau=[0-9.]+,\\s*eff=([0-9.]+)")
	for m in rx.search_all(source):
		profiles[m.get_string(1)] = [int(m.get_string(2)), float(m.get_string(3))]
	return profiles


func _seed_supply() -> void:
	# a dedicated player (110 plots after the 800 g field expansion) plants 27.5 carrot seeds a day when every bed is watered, and the seed shop is closed on Sundays: the six open days
	# have to carry seven. The shelf is bought out every open day through the real ShopSystem for a whole week (Monday to Sunday), the restock comes with every morning.
	var carrot: Dictionary = lr.get_config("crops.carrot", {})
	var grow: float = float(int(carrot.get("stages", 0)) * int(carrot.get("days_per_stage", 1)))
	var profiles := _model_profiles()
	var def: Dictionary = (lr.get_shop("seed_shop").get("stock", {}) as Dictionary).get("carrot_seeds", {})
	_fresh({"seed_shop": {"open": 6, "close": 26, "closed": SEED_SHOP_CLOSED_WEEKDAYS}})
	eco.add_gold(999999)
	var bought_each_day: Array = []
	var weekly := 0
	for d in 7:
		var row := _row("seed_shop", &"carrot_seeds")
		var left: int = int(row.get("stock", 0))
		var bought := 0
		if shop.is_open("seed_shop") and left > 0 and shop.buy_item("seed_shop", &"carrot_seeds", left):
			bought = left
		bought_each_day.append(bought)
		weekly += bought
		gm.end_day()
	var open_days: int = bought_each_day.filter(func(n: int) -> bool: return n > 0).size()
	var closed_days: int = bought_each_day.filter(func(n: int) -> bool: return n == 0).size()
	var per_open_day: int = floori(float(weekly) / float(maxi(open_days, 1)))
	var shown: Array = []
	var covered := grow > 0.0 and closed_days == SEED_SHOP_CLOSED_WEEKDAYS.size()
	var order := profiles.keys()
	order.sort()
	for profile in order:
		var plots: float = float(profiles[profile][0])
		var need_day: float = plots / grow
		var need_week: float = need_day * 7.0
		var need_open_day: float = need_week / maxf(float(open_days), 1.0)
		covered = covered and float(weekly) >= need_week and float(per_open_day) >= need_open_day
		shown.append("%s %d plots needs %.1f a day = %.1f a week = %.1f per open day" % [profile, int(plots), need_day, need_week, need_open_day])
	var dedicated: Array = profiles.get("dedicated", MODEL_FALLBACK["dedicated"])
	var dedicated_week: float = 7.0 * float(dedicated[0]) / grow
	# The old shelf (25/day) cannot support a fully watered 110-plot field.
	var old_short: bool = 6.0 * 25.0 < dedicated_week
	t.check("seed_supply_covers_a_dedicated_field", covered and old_short and float(def.get("stock", 0)) * 6.0 >= dedicated_week and float(def.get("restock", 0)) * 6.0 >= dedicated_week,
		"carrot seeds: stock %s restock %s (was 25 / 25); bought out day by day for a week %s = %d (%d open days, %d closed, %d per open day) against the model (grow %d days): %s; the old 6 x 25 = 150 would have been short of the dedicated %.1f a week %s" % [
			def.get("stock"), def.get("restock"), bought_each_day, weekly, open_days, closed_days, per_open_day, int(grow), "; ".join(shown), dedicated_week, old_short])


# ================================================================================================ cleanup

func _cleanup() -> void:
	_release_fakes()
	gm.clear_config_overrides()
	Gate.use_hours_script()
	for key in [META_RULES, META_CALLS]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	t.new_game()
	t.expect(Gate.enabled() and not Engine.has_meta(META_RULES) and not FileAccess.file_exists(PROBE_PATH), "the section leaves the gate on its contract path, the switch on, no probe script and a fresh new game behind")
