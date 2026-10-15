extends Node
## SocialManager (autoload #12+, the sixth feature autoload; save section `social`, order 60) - package S-core of the towns / farm / social addendum
## (docs/design/TOWNS_FARM_SOCIAL_ADDENDUM.md sections 5 and 8).
##
## The ONE writer of friendship. Points per NPC live here; the world flags friend_<npc> (WHOLE hearts) and friend_last_<npc> (total_day of the last
## weekly heart) are a DERIVED MIRROR rewritten after every change and every load, so every reader (quest gates, LootService.check_friend_gifts, dialogue
## Lua `friend_x`, the shop discount) keeps working and an old save without the section keeps its hearts (reset() re-seeds points from the flags).
## Everything else a player experiences as "social" is a pure function of (this state, the calendar, the Lua data): birthdays, festivals, greetings, the
## routines of the towns track (override_for). Nothing here is saved that can be computed.
##
## Rules kept from the design: no new EventBus signal (friend_changed stays THE heart signal, emitted ONLY when WHOLE hearts change; everything else is
## game_event with the names below); from_dict never emits and never push_errors (content drift is a warning + the orphans bucket); daily work is DEFERRED,
## coalesced and keyed on total_day (a 50 hour skip catches up in one loop and emits nothing synchronously inside advance_time); hearts never decrease.
##
## LATE BINDING: this file names no class of a later package. S-gifts (GiftRules / GiftFlow), the towns track (NpcDirector, Hours) and every other
## sibling are reached through Svc (Svc.node for nodes and test fakes, Svc.static_call by script path for static classes), each with a safe default,
## so the autoload boots in a tree that has none of them (social.no_forward_class_refs scans this file for exactly that).
##
## THE 26 HOUR GAME DAY (docs/design/CLOCK_26_ADDENDUM.md): hours are RAW game hours (6..25 in play, 24 / 25 read 00:xx / 01:xx of the SAME game day);
## authored hours (festival windows, `hour:` specs) are normalised with GameManager.game_hour; the daily flush is the day roll at 02:00, not midnight.

const SECTION := "social"
const SECTION_ORDER := 60                      # after loot 40 and collection 50 (SaveManager.FEATURE_ORDERS has no entry for it: the order is passed explicitly)
const SAVE_V := 1
const LAST_GIFTS := 3                          # the `ls` list of a row: the last three gifts [item, day]

## Fields of a saved row (zero fields are omitted; wk and gwk default to -1 = "never"). pc = the purchase counter packed as week * 100000 + points * 1000 + gold
## remainder (shop friendliness; a deviation from the order's field list that is zero-omitted and exists only on keepers, see the report).
const ROW_INT_KEYS: Array[String] = ["p", "wk", "gt", "gd", "gwk", "gw", "bd", "bk", "rv", "rs", "pc", "tp"]
const ROW_NEVER_KEYS: Array[String] = ["wk", "gwk"]

const EV_POINTS := &"social_points"
const EV_CHAT := &"chat_done"
const EV_BIRTHDAY := &"birthday_today"
const EV_FEST_START := &"town_festival_started"
const EV_FEST_END := &"town_festival_ended"
const EV_RELATION := &"relationship_changed"

## What IsoArea (and every other `when=` consumer) refreshes on: the typed signals by name and the game_event names. town_festival_* are game events.
const WHEN_REFRESH_EVENTS: Array[String] = [
	"friend_changed", "day_started", "time_of_day_changed", "town_festival_started", "town_festival_ended", "birthday_today", "relationship_changed", "routine_changed",
]

## The kinds of the `when=` grammar: the four old ones plus the social ones (IsoArea.WHEN_DELEGATED_KINDS lists the delegated ten).
const WHEN_KINDS: Array[String] = ["quest", "done", "flag", "night", "at", "away", "open", "hearts", "fest", "hour", "weekday", "season", "birthday", "stage"]

const GIFT_RULES := "res://scripts/social/gifts/gift_rules.gd"      # S-gifts (wave 5): late bound, absent = safe defaults
const GIFT_FLOW := "res://scripts/social/gifts/gift_flow.gd"
const DIRECTOR := "res://scripts/towns/npc_director.gd"             # the static facade of the towns track (decision DT11: there is no NpcDirector autoload)

const SLEEP_KEY := "time.sleep_from_hour"      # the config key WorldRoot2D.can_sleep_now reads (the bed seam)
const TRAVEL_LEAD_HOURS := 1.0                 # citizens set off one game hour before a festival window, shops close then (keepers leave)

var world_seed: int = 0
var _rows: Dictionary = {}               # npc id (String) -> {p, wk, gt, gd, gwk, gw, bd, bk, ls, kn, rv, rs, pc}
var _seen: Dictionary = {}               # event id -> 1 (heart events: once) or year (festival scenes: once per year)
var _fest_year: Dictionary = {}          # festival id -> last year attended
var _last_day: int = 0                   # total_day processed by the daily step
var _partner: Dictionary = {}            # {id, since, stage}  (S-marriage)
var _orphans: Dictionary = {}            # rows of NPC ids that no longer exist (kept, never dropped)
var _festival_active: StringName = &""
var _pending: bool = false
var _lines: Dictionary = {}              # remember_line memory (S-talk): npc -> {slot -> line id}; a session memory, never saved
var _shop_now: String = ""               # the shop whose panel is open (shop friendliness)

# festival index: "season:day" -> festival id, rebuilt when the registry object changes; the festival of the last asked day and the windows of the festivals are memoised
var _fest_src: Variant = null
var _fest_index: Dictionary = {}
var _fest_day: int = -1
var _fest_day_id: StringName = &""
var _fest_windows: Dictionary = {}
var _fest_day_start: int = -1

# birthday index: "season:day" -> [npc ids], rebuilt when the friend list or the citizens table change
var _bday_src: Variant = null
var _bday_citizens: Variant = null
var _bday_index: Dictionary = {}
var _bday_memo_td: int = -1
var _bday_memo: Array[String] = []

# the bed hold: what this node set on GameManager's config override and what stood there before
var _hold_value: int = 0
var _hold_had_prev: bool = false
var _hold_prev: Variant = null

# `when=` parse cache: spec -> Array of [neg, kind, arg, rest]
var _when_cache: Dictionary = {}

# toasts: one per conversation, spaced by toast_gap_s (real seconds)
var _toast_queue: Array = []
var _toast_next_ms: int = 0
## Test seam: a value >= 0 replaces social.toast_gap_s (milliseconds).
var toast_gap_override_ms: int = -1

## Test seams: where the late-bound sibling scripts are looked up (a test points them at a path that does not exist to prove the safe defaults).
var gift_rules_path: String = GIFT_RULES
var gift_flow_path: String = GIFT_FLOW
var director_path: String = DIRECTOR


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	EventBus.new_game_started.connect(reset)
	EventBus.day_started.connect(_on_day_started)
	EventBus.time_of_day_changed.connect(_on_time_changed)
	EventBus.area_changed.connect(_on_area_changed)
	EventBus.game_event.connect(_on_game_event)
	EventBus.load_completed.connect(_on_load_completed)
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.item_purchased.connect(_on_item_purchased)
	var sm := Svc.node("SaveManager")
	if sm != null and sm.has_method("register_section"):
		sm.call("register_section", SECTION, self, SECTION_ORDER)


# ======================================================================================= seed / rng

func set_seed(value: int) -> void:
	world_seed = maxi(value, 1) & 0x1FFFFFFFFFFFFF          # below 2^53: it survives the JSON round trip exactly


func _ensure_seed() -> int:
	if world_seed == 0:
		set_seed(int(Time.get_unix_time_from_system()) * 7919 + Time.get_ticks_usec())
	return world_seed


## One deterministic roll of the social layer: SocialRng over the saved world seed (never randf, never String.hash).
func roll(parts: Array) -> float:
	return SocialRng.roll(_ensure_seed(), parts)


# ======================================================================================= calendar shortcuts

## total_day, memoised on (day, season, year, days per season): GameManager.total_day() rebuilds the season list on every call and this is asked by every
## `fest:` / `birthday:` / `weekday:` term and every limit check.
var _today_day: int = -1
var _today_season: StringName = &""
var _today_year: int = -1
var _today_dps: int = -1
var _today_value: int = 1


func today() -> int:
	var dps := GameManager.days_per_season()
	if GameManager.day != _today_day or GameManager.season != _today_season or GameManager.year != _today_year or dps != _today_dps:
		_today_value = GameManager.total_day()
		_today_day = GameManager.day
		_today_season = GameManager.season
		_today_year = GameManager.year
		_today_dps = dps
	return _today_value


func week() -> int:
	return CalendarUtil.week_of(today())


# ======================================================================================= late-bound siblings

## The towns track's NpcDirector in the ONE form of decision DT11: a node injected by a test first, then the static facade by path (what Svc.static_call does, with the
## loaded script and the "is it static" answer remembered per path and method: a festival day asks about 30 citizens per roster, and Svc.static_call alone costs
## about 30 microseconds a call, measured; the answer for an absent script, an absent method and an instance method is the safe default, like Svc's).
var _dir_path: String = "<unset>"
var _dir_script: Script = null
var _dir_static: Dictionary = {}


func _director(method: StringName, npc: String, default_value: Variant) -> Variant:
	var d := Svc.node("NpcDirector")
	if d != null and d.has_method(method):
		return d.call(method, npc)
	if director_path != _dir_path:
		_dir_path = director_path
		_dir_static.clear()
		_dir_script = (load(director_path) as Script) if ResourceLoader.exists(director_path) else null
	if _dir_script == null:
		return default_value
	if not _dir_static.has(method):
		var is_static := false
		if _dir_script.has_method(method):
			for m in _dir_script.get_script_method_list():
				if str(m["name"]) == str(method):
					is_static = (int(m["flags"]) & METHOD_FLAG_STATIC) != 0
		_dir_static[method] = is_static
	if not bool(_dir_static[method]):
		return default_value
	return _dir_script.callv(method, [npc])


## The hero-twin rule: the player chose this citizen's look, so he is not in the world and cannot be befriended.
func _absent(npc: String) -> bool:
	return bool(_director(&"is_absent", npc, false))


func _t(key: String, args: Array = []) -> String:
	var lm := Svc.node("LocalizationManager")
	if lm != null and lm.has_method("t"):
		return str(lm.call("t", key, args))
	return key


func _name_of(npc: String) -> String:
	var key := str(SocialData.npc_row(npc).get("name_key", ""))
	return _t(key) if key != "" else npc


# ======================================================================================= rows / hearts

## "" when `npc` can be befriended now, else why not: unknown_npc | locked (no friendship flag and the unlock is not met yet) | absent (hero twin).
func befriend_reason(npc: Variant) -> String:
	var id := str(npc)
	var row := SocialData.npc_row(id)
	if row.is_empty():
		return "unknown_npc"
	if not bool(row.get("friendship", false)):
		var unlock := SocialData.unlock_of(id)
		if unlock.is_empty() or not _unlock_met(unlock):
			return "locked"
	if _absent(id):
		return "absent"
	return ""


## friendship flag OR citizens.unlock {quest done | total_day >= day} (Morfar Mis), AND not absent (hero twin).
func can_befriend(npc: Variant) -> bool:
	return befriend_reason(npc) == ""


func _unlock_met(unlock: Dictionary) -> bool:
	var day := LuaData.int_of(unlock.get("day", 0))
	if day > 0 and today() >= day:
		return true
	var quest := str(unlock.get("quest", ""))
	if quest == "":
		return false
	var qm := Svc.node("QuestManager")
	return qm != null and qm.has_method("is_completed") and bool(qm.call("is_completed", StringName(quest)))


func _row(npc: String, create: bool = true) -> Dictionary:
	if not _rows.has(npc):
		if not create:
			return {}
		_rows[npc] = {"p": 0, "wk": -1, "gt": 0, "gd": 0, "gwk": -1, "gw": 0, "bd": 0, "bk": 0, "ls": [], "kn": {}, "rv": 0, "rs": 0, "pc": 0, "tp": 0}
	return _rows[npc]


## The LIVE state row of an NPC for the sibling packages that own parts of it (S-gifts: gd gwk gw bd ls kn; S-talk: rv; S-marriage: rs): the section is the single store.
## `create` false answers {} for an NPC without any state.
func row_of(npc: Variant, create: bool = true) -> Dictionary:
	return _row(str(npc), create)


func points_per_heart() -> int:
	return SocialData.heart_scale().x


func heart_cap() -> int:
	return SocialData.heart_scale().y


func points(npc: Variant) -> int:
	return LuaData.int_of(_row(str(npc), false).get("p", 0))


## Whole hearts: floor(points / 100), capped at 10.
func hearts(npc: Variant) -> int:
	var scale := SocialData.heart_scale()
	return mini(floori(float(points(npc)) / float(scale.x)), scale.y)


## 0..2 x cap: the row of heart glyphs (full = 2, half = 1); a half heart per 50 points.
func half_hearts(npc: Variant) -> int:
	var half := maxf(float(points_per_heart()) / 2.0, 1.0)
	return mini(floori(float(points(npc)) / half), heart_cap() * 2)


func friend_ids() -> Array[String]:
	return SocialData.friend_ids()


## The friendship stage by hearts (social.stage_order / stage_hearts); the marriage-style stages of S-marriage extend it through the row field `rs`
## (1, 2, 3 = social.rs_stages[rs - 1] when that list is authored).
func stage(npc: Variant) -> StringName:
	var id := str(npc)
	var rs := LuaData.int_of(_row(id, false).get("rs", 0))
	if rs > 0:
		var extra := LuaData.strings(SocialData.cfg("rs_stages", []))
		if rs <= extra.size():
			return StringName(extra[rs - 1])
	var h := hearts(id)
	var table: Array = SocialData.stage_table()
	var out: StringName = (table[0] as Array)[0] if not table.is_empty() else &"fremmed"
	for entry in table:
		if h >= int((entry as Array)[1]):
			out = (entry as Array)[0]
	return out


## The single writer. `source`: chat gift quest event festival purchase birthday lua debug. `opts`: {toast: false} keeps the stage-up toast back (the caller merges
## toasts: one per conversation). Returns {ok, points, hearts, gained, hearts_before, stage_before, stage_after, source}; a refusal is {ok: false, reason,
## gained: 0, points, hearts} with the reasons bad_delta unknown_npc locked absent. At the cap the answer is ok with gained 0 and nothing is emitted.
func add_points(npc: Variant, delta: int, source: StringName = &"", opts: Dictionary = {}) -> Dictionary:
	var id := str(npc)
	if delta <= 0:
		return {"ok": false, "reason": "bad_delta", "gained": 0, "points": points(id), "hearts": hearts(id)}
	var why := befriend_reason(id)
	if why != "":
		return {"ok": false, "reason": why, "gained": 0, "points": points(id), "hearts": hearts(id)}
	var row := _row(id)
	var cap_points := heart_cap() * points_per_heart()
	var before_points := LuaData.int_of(row["p"])
	var before_hearts := hearts(id)
	var before_stage := stage(id)
	var gained := mini(delta, cap_points - before_points)
	var result := {"ok": true, "gained": maxi(gained, 0), "points": before_points, "hearts": before_hearts, "hearts_before": before_hearts, "stage_before": before_stage, "stage_after": before_stage, "source": String(source)}
	if gained <= 0:
		return result
	row["p"] = before_points + gained
	_mirror(id)
	var after_hearts := hearts(id)
	var after_stage := stage(id)
	result["points"] = int(row["p"])
	result["hearts"] = after_hearts
	result["stage_after"] = after_stage
	EventBus.game_event.emit(EV_POINTS, {"npc": id, "delta": gained, "points": int(row["p"]), "hearts": after_hearts, "source": String(source)})
	if after_hearts > before_hearts:
		EventBus.friend_changed.emit(StringName(id), after_hearts)
		var loot := Svc.node("LootService")
		if loot != null and loot.has_method("check_friend_gifts"):
			loot.call("check_friend_gifts", StringName(id))
	if after_stage != before_stage:
		_stage_changed(id, after_stage, bool(opts.get("toast", true)))
	return result


## Quest rewards (`rewards.friendship = {npc = n}`, api.add_hearts): n WHOLE hearts of points.
func add_hearts(npc: Variant, n: int, source: StringName = &"quest") -> Dictionary:
	return add_points(npc, n * points_per_heart(), source)


## Test / debug / Grant.set_hearts: raises to at least `n` hearts (never lowers), same signals, no toast.
func debug_set_hearts(npc: Variant, n: int) -> Dictionary:
	var want := clampi(n, 0, heart_cap()) * points_per_heart()
	var have := points(npc)
	if want > have:
		return add_points(npc, want - have, &"debug", {"toast": false})
	return {"ok": true, "gained": 0, "points": have, "hearts": hearts(npc)}


## friend_<npc> = WHOLE hearts: written after every change and every load (only for an NPC that has a row).
func _mirror(npc: String) -> void:
	if _row(npc, false).is_empty():
		return
	GameManager.set_flag(StringName("friend_" + npc), hearts(npc))


func _stage_changed(npc: String, new_stage: StringName, with_toast: bool) -> void:
	EventBus.game_event.emit(EV_RELATION, {"npc": npc, "stage": String(new_stage), "partner": false})
	if with_toast:
		_toast(_t("SOC_SYS_TOAST_TITLE"), _stage_line(npc, new_stage))


func _stage_line(npc: String, stage_id: StringName) -> String:
	return _t("SOC_SYS_TOAST_STAGE_FMT", [_name_of(npc), _t("REL_STAGE_" + String(stage_id).to_upper())])


# ======================================================================================= weekly chat

func chat_available(npc: Variant) -> bool:
	return can_befriend(npc) and LuaData.int_of(_row(str(npc), false).get("wk", -1), -1) != week()


func talked_today(npc: Variant) -> bool:
	return LuaData.int_of(_row(str(npc), false).get("gt", 0)) == today()


## Called by Npc2D exactly once per conversation: `lines_shown` lines were shown, `completed` = the last line was advanced or a closing choice was picked (an
## Esc after the first line is not). The FIRST FINISHED conversation of a calendar week (Monday..Sunday) gives exactly one heart (the DF3 floor); the daily
## greeting and every further chat of the week give nothing. ONE combined toast (heart, stage-up, keeper sample). Returns {weekly_heart}.
func on_conversation_finished(npc: Variant, lines_shown: int, completed: bool = true) -> Dictionary:
	var id := str(npc)
	if not can_befriend(id) or lines_shown < SocialData.cfg_int("chat_min_lines", 1):
		return {"weekly_heart": false}
	var row := _row(id)
	row["gt"] = today()
	row["bk"] = 1                                          # you know their birthday once you have talked
	if not completed:
		return {"weekly_heart": false}
	var got := false
	var stage_before := stage(id)
	var parts: Array[String] = []
	if LuaData.int_of(row["wk"], -1) != week():
		row["wk"] = week()
		GameManager.set_flag(StringName("friend_last_" + id), today())
		var r := add_points(id, SocialData.cfg_int("chat_points", 100), &"chat", {"toast": false})
		got = bool(r.get("ok", false)) and int(r.get("gained", 0)) > 0
		if got:
			parts.append(_t("SOC_SYS_TOAST_HEART_FMT", [_name_of(id), hearts(id), heart_cap()]))
			if stage(id) != stage_before:
				parts.append(_stage_line(id, stage(id)))
			var sample := _keeper_sample(id)
			if sample != "":
				parts.append(sample)
	EventBus.game_event.emit(EV_CHAT, {"npc": id, "weekly_heart": got})
	if not parts.is_empty():
		_toast(_t("SOC_SYS_TOAST_TITLE"), "\n".join(parts))
	return {"weekly_heart": got}


## The weekly keeper sample: with the weekly heart of a SHOPKEEPER whose citizens row names a sample {item, from_hearts} and hearts >= from_hearts, ONE
## cheap item is handed over through EconomyManager (the data and its price limits are S-data's). Returns the toast line, "" when nothing was given.
func _keeper_sample(npc: String) -> String:
	var sample := SocialData.sample_of(npc)
	var item := str(sample.get("item", ""))
	if item == "" or hearts(npc) < LuaData.int_of(sample.get("from_hearts", 0)):
		return ""
	var eco := Svc.node("EconomyManager")
	if eco == null or not eco.has_method("add_item") or not bool(eco.call("add_item", StringName(item), 1, true)):
		return ""
	var def: Variant = eco.call("item_def", item) if eco.has_method("item_def") else {}
	var item_name := _t(str(LuaData.dict(def).get("name_key", "ITEM_" + item.to_upper())))
	return _t("SOC_SYS_TOAST_SAMPLE_FMT", [_name_of(npc), item_name])


# ======================================================================================= shop friendliness (tiny and capped)

func _on_shop_opened(shop_id: StringName) -> void:
	_shop_now = String(shop_id)


func _on_shop_closed(shop_id: StringName) -> void:
	if _shop_now == String(shop_id):
		_shop_now = ""


## 1 point per social.purchase.gold_per_point gold spent in the panel of a KEEPER'S shop, at most social.purchase.weekly_cap points per keeper and calendar
## week; the gold that has not made a point yet is carried (the packed row field `pc`). A regular customer drifts toward a heart with no visible discount.
func _on_item_purchased(_item_id: StringName, _amount: int, cost: int) -> void:
	if _shop_now == "" or cost <= 0:
		return
	var keeper := SocialData.keeper_of(_shop_now)
	if keeper == "" or not can_befriend(keeper):
		return
	var gpp := clampi(SocialData.cfg_int("purchase.gold_per_point", 100), 1, 999)
	var cap := clampi(SocialData.cfg_int("purchase.weekly_cap", 10), 0, 99)
	var row := _row(keeper)
	var pc := LuaData.int_of(row["pc"])
	var in_week := floori(float(pc) / 100000.0)
	var used := floori(float(pc % 100000) / 1000.0)
	var rest := pc % 1000
	if in_week != week():
		used = 0
	rest += cost
	var gain := floori(float(rest) / float(gpp))
	rest -= gain * gpp
	gain = mini(gain, maxi(cap - used, 0))
	used += gain
	row["pc"] = week() * 100000 + used * 1000 + mini(rest, 999)
	if gain > 0:
		add_points(keeper, gain, &"purchase", {"toast": false})


# ======================================================================================= toasts (one per conversation, spaced)

func _toast(title: String, message: String) -> void:
	var now := Time.get_ticks_msec()
	if _toast_queue.is_empty() and now >= _toast_next_ms:
		_post_toast(title, message, now)
		return
	if _toast_queue.size() >= 3:
		_toast_queue.pop_front()
	_toast_queue.append([title, message])
	set_process(true)


func _post_toast(title: String, message: String, now: int) -> void:
	var gap := toast_gap_override_ms if toast_gap_override_ms >= 0 else int(SocialData.cfg_num("toast_gap_s", 1.5) * 1000.0)
	_toast_next_ms = now + gap
	EventBus.notification_posted.emit(title, message, "social")


func _process(_delta: float) -> void:
	if _toast_queue.is_empty():
		set_process(false)
		return
	var now := Time.get_ticks_msec()
	if now >= _toast_next_ms:
		var next: Array = _toast_queue.pop_front()
		_post_toast(str(next[0]), str(next[1]), now)


# ======================================================================================= gifts (the surface lives here, the rules are S-gifts' and late bound)

## The limits of today and this calendar week for gifts to `npc`: {per_day, per_week, left_today, left_week} (the state fields gd gwk gw are in the row).
func gift_limits(npc: Variant) -> Dictionary:
	var row := _row(str(npc), false)
	var per_day := SocialData.cfg_int("gifts.per_day", 1)
	var per_week := SocialData.cfg_int("gifts.per_week", 2)
	var gifted_today := LuaData.int_of(row.get("gd", 0)) == today()
	var in_week := LuaData.int_of(row.get("gwk", -1), -1) == week()
	var used_week := LuaData.int_of(row.get("gw", 0)) if in_week else 0
	return {"per_day": per_day, "per_week": per_week, "left_today": (0 if gifted_today else per_day), "left_week": maxi(per_week - used_week, 0)}


## "" | "day" | "belated": which birthday rule a gift to `npc` falls under right now (a birthday gift needs no weekly slot and is given once per birthday;
## `bd` stores the total_day of the birthday that was celebrated).
func birthday_state(npc: Variant) -> String:
	var occ := last_birthday(npc)
	if occ <= 0 or LuaData.int_of(_row(str(npc), false).get("bd", 0)) == occ:
		return ""
	var since := today() - occ
	if since == 0:
		return "day"
	return "belated" if since <= SocialData.cfg_int("gifts.belated_days", 1) else ""


## The whole gift transaction is S-gifts' GiftFlow (late bound). {ok: false, reason: "gifts_not_installed"} while it is absent.
func give_gift(npc: Variant, item_id: Variant) -> Dictionary:
	var out: Variant = Svc.static_call(gift_flow_path, &"give_gift", [str(npc), str(item_id)], null)
	return out as Dictionary if typeof(out) == TYPE_DICTIONARY else {"ok": false, "reason": "gifts_not_installed"}


## The givable stock for the picker (GiftFlow); [] while S-gifts is absent.
func gift_options(npc: Variant) -> Array:
	var out: Variant = Svc.static_call(gift_flow_path, &"gift_options", [str(npc)], null)
	return out as Array if typeof(out) == TYPE_ARRAY else []


## {class, level, selector}: love like neutral dislike hate (GiftRules over the gift_tastes data). Neutral while S-gifts is absent.
func taste_of(npc: Variant, item_id: Variant) -> Dictionary:
	var id := str(npc)
	var out: Variant = Svc.static_call(gift_rules_path, &"taste_of", [LuaData.dict(Svc.lua_config("gift_tastes", {})), id, str(SocialData.citizen(id)["archetype"]), str(item_id), _item_def(str(item_id))], null)
	return out as Dictionary if typeof(out) == TYPE_DICTIONARY else {"class": "neutral", "level": "default", "selector": ""}


## {ok, reason}: may this item ever be given? Refused with "gifts_not_installed" while S-gifts is absent.
func is_giftable(item_id: Variant) -> Dictionary:
	var item := str(item_id)
	var out: Variant = Svc.static_call(gift_rules_path, &"giftable", [item, _item_def(item), _sell_value(item)], null)
	return out as Dictionary if typeof(out) == TYPE_DICTIONARY else {"ok": false, "reason": "gifts_not_installed"}


func _item_def(item_id: String) -> Dictionary:
	var eco := Svc.node("EconomyManager")
	if eco != null and eco.has_method("item_def"):
		return LuaData.dict(eco.call("item_def", item_id))
	var lr := Svc.node("LuaRuntime")
	return LuaData.dict(lr.call("get_item_def", item_id)) if lr != null and lr.has_method("get_item_def") else {}


func _sell_value(item_id: String) -> int:
	var eco := Svc.node("EconomyManager")
	return LuaData.int_of(eco.call("sell_value", item_id)) if eco != null and eco.has_method("sell_value") else 0


# ======================================================================================= birthdays

func _bday_rebuild() -> void:
	_bday_index.clear()
	var ids := SocialData.friend_ids()
	for id in ids:
		var b: Dictionary = SocialData.birthday_of(id)
		var key := CalendarUtil.date_key(StringName(str(b["season"])), LuaData.int_of(b["day"]))
		if not _bday_index.has(key):
			_bday_index[key] = []
		(_bday_index[key] as Array).append(id)
	_bday_src = ids
	_bday_citizens = SocialData.citizens()
	_bday_memo_td = -1


func _bday_ensure() -> void:
	if _bday_src == null or not is_same(_bday_src, SocialData.friend_ids()) or not is_same(_bday_citizens, SocialData.citizens()):
		_bday_rebuild()


## Who has a birthday on a total day (sorted ids). The answer for the day asked last is memoised (every `birthday:` term and dialogue context asks for today).
func birthdays_on(td: int) -> Array[String]:
	_bday_ensure()
	if td != _bday_memo_td:
		var d := CalendarUtil.date_of(td)
		var out: Array[String] = []
		for id in LuaData.arr(_bday_index.get(CalendarUtil.date_key(StringName(str(d["season"])), LuaData.int_of(d["day"])), [])):
			out.append(str(id))
		_bday_memo = out
		_bday_memo_td = td
	return _bday_memo.duplicate()


func birthdays_today() -> Array[String]:
	return birthdays_on(today())


func is_birthday(npc: Variant) -> bool:
	return str(npc) in birthdays_today()


## total_day of the most recent birthday of `npc` (today counts), 0 before the first one.
func last_birthday(npc: Variant) -> int:
	var b := SocialData.birthday_of(str(npc))
	var d := CalendarUtil.days_until(StringName(str(b["season"])), LuaData.int_of(b["day"]), today())
	var occ := today() if d == 0 else today() - (CalendarUtil.year_length() - d)
	return occ if occ >= 1 else 0


## {days, total_day, season, day} of the next birthday (today = 0 days).
func next_birthday(npc: Variant) -> Dictionary:
	var b := SocialData.birthday_of(str(npc))
	var d := CalendarUtil.days_until(StringName(str(b["season"])), LuaData.int_of(b["day"]), today())
	return {"days": d, "total_day": today() + d, "season": str(b["season"]), "day": LuaData.int_of(b["day"])}


## Is the birthday known to the player? (a conversation marks it known).
func birthday_known(npc: Variant) -> bool:
	return LuaData.int_of(_row(str(npc), false).get("bk", 0)) == 1


## The calendar tab of the journal: [{day, kind: birthday | festival, id, known}] of one season, sorted by day (festival before birthday), unknown birthdays
## are listed with known = false (the UI hides the name). The year only matters to the attended-this-year flag of a festival.
func calendar_entries(season: Variant, year: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var season_id := str(season)
	for id in SocialData.friend_ids():
		var b := SocialData.birthday_of(id)
		if str(b["season"]) == season_id:
			out.append({"day": LuaData.int_of(b["day"]), "kind": "birthday", "id": id, "known": birthday_known(id)})
	for fid in _festival_ids():
		var meta := _meta(fid)
		if str(meta.get("season", "")) == season_id:
			out.append({"day": LuaData.int_of(meta.get("day", 0)), "kind": "festival", "id": fid, "known": true, "attended": LuaData.int_of(_fest_year.get(fid, 0)) == year})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["day"]) != int(b["day"]):
			return int(a["day"]) < int(b["day"])
		if str(a["kind"]) != str(b["kind"]):
			return str(a["kind"]) > str(b["kind"])            # festival before birthday
		return str(a["id"]) < str(b["id"]))
	return out


# ======================================================================================= festivals (state; the content is S-fest-content's)

func _festival_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in SocialData.festivals():
		ids.append(str(k))
	ids.sort()
	return ids


func _meta(fid: String) -> Dictionary:
	return LuaData.dict(SocialData.festival(fid).get("meta", {}))


func _fest_ensure() -> void:
	var reg: Dictionary = SocialData.festivals()
	if _fest_src != null and is_same(_fest_src, reg):
		return
	_fest_index.clear()
	_fest_windows.clear()
	_fest_day = -1
	for fid in _festival_ids():
		var meta := _meta(fid)
		var key := "%s:%d" % [str(meta.get("season", "")), LuaData.int_of(meta.get("day", 0))]
		if not _fest_index.has(key):
			_fest_index[key] = fid
	_fest_src = reg


## The festival of a total day ("" for an ordinary day).
func festival_on(td: int) -> StringName:
	_fest_ensure()
	if _fest_index.is_empty():
		return &""
	if td == _fest_day:
		return _fest_day_id
	var d := CalendarUtil.date_of(td)
	_fest_day_id = StringName(str(_fest_index.get("%s:%d" % [str(d["season"]), LuaData.int_of(d["day"])], "")))
	_fest_day = td
	return _fest_day_id


func festival_today() -> StringName:
	return festival_on(today())


## {from, to} of a festival window on the raw game-hour axis (authored hours normalised by GameManager.game_hour: a window may end at 25.0 = 01:00).
func festival_window(fid: Variant) -> Dictionary:
	_fest_ensure()
	var start := GameManager.day_start_hour()
	if start != _fest_day_start:
		_fest_windows.clear()
		_fest_day_start = start
	var key := str(fid)
	if not _fest_windows.has(key):
		var meta := _meta(key)
		_fest_windows[key] = {"from": GameManager.game_hour(LuaData.num(meta.get("from", 0.0))), "to": GameManager.game_hour(LuaData.num(meta.get("to", 0.0)))}
	return _fest_windows[key]


func _now_hours() -> float:
	return float(GameManager.hour) + float(GameManager.minute) / 60.0


## Today's festival while its window runs: today AND the hour in [from, to).
func festival_active() -> StringName:
	var f := festival_today()
	if f == &"":
		return &""
	var w := festival_window(f)
	var now := _now_hours()
	return f if now >= float(w["from"]) and now < float(w["to"]) else &""


## A festival that closes the shops (`closes = all`) closes every shop that is not listed in `stays_open` from one game hour BEFORE the window (the keepers
## walk to the festival then) until the window end; `closes = none` (Sofus' badedag) closes nothing.
func shop_closed_by_festival(shop_id: Variant) -> bool:
	var f := festival_today()
	if f == &"":
		return false
	var meta := _meta(String(f))
	if str(meta.get("closes", "all")) == "none":
		return false
	var w := festival_window(f)
	var now := _now_hours()
	if now < float(w["from"]) - TRAVEL_LEAD_HOURS or now >= float(w["to"]):
		return false
	return not (str(shop_id) in LuaData.strings(meta.get("stays_open", [])))


## The earliest hour the bed accepts while a festival with bed_hold runs (0 = no hold): the window end, rounded up.
func bed_hold_hour() -> int:
	var f := festival_active()
	if f == &"":
		return 0
	var meta := _meta(String(f))
	return ceili(float(festival_window(f)["to"])) if bool(meta.get("bed_hold", false)) else 0


## THE ZERO-EDIT BED SEAM. WorldRoot2D.can_sleep_now reads the config time.sleep_from_hour; while a festival with bed_hold runs this node keeps the override
## time.sleep_from_hour = the window end on GameManager and takes it away afterwards (restoring an override that a test had set before). Because that override is
## a never-saved test seam wiped by clear_config_overrides(), nothing relies on it surviving: this is called from the STATE (festival_active + bed_hold) on every
## flush, every load, every area_changed and every town_festival_* event, and it is idempotent.
func _apply_bed_hold() -> void:
	var want := bed_hold_hour()
	if want <= 0:
		_release_bed_hold()
		return
	var overrides := _overrides()
	var has := overrides.has(SLEEP_KEY)
	if _hold_value == 0 or not has or overrides[SLEEP_KEY] != _hold_value:
		# the current state is not ours (first time, wiped by clear_config_overrides, or somebody else set it): remember what is there
		_hold_had_prev = has
		_hold_prev = overrides.get(SLEEP_KEY, null)
	if not (has and overrides[SLEEP_KEY] == want):
		GameManager.set_config_override(SLEEP_KEY, want)
	_hold_value = want


## GameManager's live override table (a test / debug seam, never saved); {} when it cannot be read.
func _overrides() -> Dictionary:
	var live: Variant = GameManager.get("_config_overrides")
	return live as Dictionary if typeof(live) == TYPE_DICTIONARY else {}


func _release_bed_hold() -> void:
	if _hold_value == 0:
		return
	var overrides := _overrides()
	if overrides.has(SLEEP_KEY) and overrides[SLEEP_KEY] == _hold_value:
		if _hold_had_prev:
			GameManager.set_config_override(SLEEP_KEY, _hold_prev)
		else:
			overrides.erase(SLEEP_KEY)
			GameManager.invalidate_config_cache()
	_hold_value = 0
	_hold_had_prev = false
	_hold_prev = null


## The festival state machine: emits town_festival_ended / started on a CHANGE, keeps the world flag `festival_now` (the id of the festival active now, absent
## when none) and re-applies the bed hold. Never called from from_dict (a load restores the state silently, see _restore_state).
func _update_festival_state() -> void:
	var now := festival_active()
	if now != _festival_active:
		var prev := _festival_active
		_festival_active = now
		_write_festival_flag()
		if prev != &"":
			EventBus.game_event.emit(EV_FEST_END, {"id": String(prev)})
		if now != &"":
			EventBus.game_event.emit(EV_FEST_START, {"id": String(now)})
	_write_festival_flag()
	_apply_bed_hold()


func _write_festival_flag() -> void:
	if _festival_active == &"":
		if GameManager.world_flags.has(&"festival_now"):
			GameManager.clear_flag(&"festival_now")
	elif str(GameManager.get_flag(&"festival_now", "")) != String(_festival_active):
		GameManager.set_flag(&"festival_now", String(_festival_active))


## Who stands where on a festival day. The roster of a festival is built in this order (SocialData.festival_roster): (1) the host; (2) meta.first, in the
## given order, deduplicated, OUTSIDE the cap (a first member is a home citizen of the area and is removed from the ordered pool); (3) the other home citizens of
## the area (an absent hero twin excluded) ordered by SocialRng.roll(seed, [festival, npc]), the first social.festival.max_attendees (15); (4) meta.guests
## (citizens of ANOTHER area, outside the cap). Keepers of a `stays_open` shop stay at their shop (the host does not). One gather post per attendee, in that order.
func festival_roster(fid: Variant) -> Dictionary:
	var id := str(fid)
	var absent: Array[String] = []
	for npc in SocialData.npcs():
		if _absent(str(npc)):
			absent.append(str(npc))
	return SocialData.festival_roster(id, _meta(id), _ensure_seed(), SocialData.npcs(), absent, SocialData.cfg_int("festival.max_attendees", 15))


## override_for(npc, total_day, hour) -> {area, post, state: "stay", festival, from, to, until} | {}: the routine layer's question. {} when the citizen is not part of
## that day's festival (no festival, host absent, keeper of a stays_open shop, not in the roster) or `hour` (RAW game hour, -1 = any time) is outside his stay: from one
## game hour before the window until the window end, or until `meta.leave_early[npc]` hours before it (any listed attendee leaves early, whichever group he is in).
func override_for(npc: Variant, td: int, hour: float = -1.0) -> Dictionary:
	var fid := String(festival_on(td))
	if fid == "":
		return {}
	var id := str(npc)
	var meta := _meta(fid)
	var roster := festival_roster(fid)
	var post := ""
	if id == str(roster.get("host", "")):
		post = "fest_%s_host" % str(meta.get("spot", ""))
	else:
		var gather: Array = roster.get("gather", [])
		var i := gather.find(id)
		if i < 0:
			return {}
		post = "fest_%s_gather_%d" % [str(meta.get("spot", "")), i + 1]
	var w := festival_window(fid)
	var leave := LuaData.num(LuaData.dict(meta.get("leave_early", {})).get(id, 0.0))
	var until := maxf(float(w["to"]) - leave, float(w["from"]) - TRAVEL_LEAD_HOURS)
	if hour >= 0.0 and (hour < float(w["from"]) - TRAVEL_LEAD_HOURS or hour >= until):
		return {}
	return {"area": str(meta.get("area", "")), "post": post, "state": "stay", "festival": fid, "from": float(w["from"]), "to": float(w["to"]), "until": until}


# ======================================================================================= when= grammar (ONE implementation)

## `kind:arg[:arg]` terms joined by `&` (and), a leading `!` negates a term. Kinds: hearts:<npc>:<n> fest:<id|any> hour:<a>-<b> weekday:<0..6,..> season:<id,..>
## birthday:<npc> stage:<npc>:<stage> open:<shop> at:<npc> away:<npc> and the four old ones quest:<id> (active) done:<id> flag:<name> night. An UNKNOWN kind is false.
func eval_when(spec: String) -> bool:
	for term in _when_terms(spec):
		if _when_one(str(term[1]), str(term[2]), str(term[3])) == bool(term[0]):
			return false
	return true


func _when_terms(spec: String) -> Array:
	if _when_cache.has(spec):
		return _when_cache[spec]
	var out: Array = []
	for part in spec.split("&", false):
		var s := part.strip_edges()
		var neg := s.begins_with("!")
		if neg:
			s = s.substr(1).strip_edges()
		var p := s.split(":", true, 2)
		out.append([neg, p[0].strip_edges(), p[1].strip_edges() if p.size() > 1 else "", p[2].strip_edges() if p.size() > 2 else ""])
	if _when_cache.size() > 256:
		_when_cache.clear()
	_when_cache[spec] = out
	return out


func _when_one(kind: String, arg: String, rest: String) -> bool:
	match kind:
		"hearts":
			return hearts(arg) >= rest.to_int()
		"fest":
			var f := festival_active()
			return f != &"" if arg == "any" else String(f) == arg
		"hour":
			var ab := arg.split("-")
			return ab.size() == 2 and CalendarUtil.in_window(float(GameManager.hour), GameManager.game_hour(ab[0].to_float()), GameManager.game_hour(ab[1].to_float()))
		"weekday":
			var wd := CalendarUtil.weekday_of(today())
			for w in arg.split(",", false):
				if w.to_int() == wd:
					return true
			return false
		"season":
			return str(GameManager.season) in arg.split(",", false)
		"birthday":
			return is_birthday(arg)
		"stage":
			return String(stage(arg)) == rest
		"open":
			var ss := Svc.node("ShopSystem")
			return ss == null or not ss.has_method("is_open") or bool(ss.call("is_open", arg))
		"at":
			return bool(_director(&"is_present", arg, true))
		"away":
			return bool(_director(&"is_away", arg, false))
		"flag":
			return _truthy(GameManager.get_flag(StringName(arg), false))
		"night":
			var tm := Svc.node("TimeManager")
			return tm != null and tm.has_method("is_night") and bool(tm.call("is_night"))
		"quest":
			var qa := Svc.node("QuestManager")
			return qa != null and qa.has_method("is_active") and bool(qa.call("is_active", StringName(arg)))
		"done":
			var qd := Svc.node("QuestManager")
			return qd != null and qd.has_method("is_completed") and bool(qd.call("is_completed", StringName(arg)))
	return false


func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v) != ""
	return true


## What is wrong with `spec` (typos and bad arguments), [] when it is fine: for the map lint (IsoArea) and the event validator. An unknown kind reads
## "unknown kind in '<term>'" like IsoArea's own report, so the two lists merge without duplicates.
func when_spec_errors(spec: String) -> Array[String]:
	var errors: Array[String] = []
	if spec.strip_edges() == "":
		return errors
	var friends := SocialData.npcs()
	for part in spec.split("&", true):
		var term := part.strip_edges()
		if term == "":
			errors.append("empty term in '%s'" % spec)
			continue
		var neg := term.begins_with("!")
		var body := term.substr(1).strip_edges() if neg else term
		var p := body.split(":", true, 2)
		var kind := p[0].strip_edges()
		var arg := p[1].strip_edges() if p.size() > 1 else ""
		var rest := p[2].strip_edges() if p.size() > 2 else ""
		if kind not in WHEN_KINDS:
			errors.append("unknown kind in '%s'" % term)
			continue
		match kind:
			"hearts":
				if not friends.is_empty() and not friends.has(arg):
					errors.append("hearts: unknown npc '%s' in '%s'" % [arg, term])
				if not rest.is_valid_int() or rest.to_int() < 0 or rest.to_int() > heart_cap():
					errors.append("hearts: '%s' needs hearts:<npc>:<0..%d> in '%s'" % [rest, heart_cap(), term])
			"stage":
				if not friends.is_empty() and not friends.has(arg):
					errors.append("stage: unknown npc '%s' in '%s'" % [arg, term])
				if rest not in LuaData.strings(SocialData.cfg("stage_order", [])) and rest not in LuaData.strings(SocialData.cfg("rs_stages", [])):
					errors.append("stage: unknown stage '%s' in '%s'" % [rest, term])
			"birthday", "at", "away":
				if not friends.is_empty() and not friends.has(arg):
					errors.append("%s: unknown npc '%s' in '%s'" % [kind, arg, term])
			"fest":
				if arg == "":
					errors.append("fest: needs an id or any in '%s'" % term)
				elif arg != "any" and not SocialData.festivals().is_empty() and not SocialData.festivals().has(arg):
					errors.append("fest: unknown festival '%s' in '%s'" % [arg, term])
			"hour":
				var ab := arg.split("-")
				if ab.size() != 2 or not ab[0].is_valid_float() or not ab[1].is_valid_float():
					errors.append("hour: needs hour:<a>-<b> in '%s'" % term)
				elif ab[0].to_float() < 0.0 or ab[0].to_float() > 26.0 or ab[1].to_float() < 0.0 or ab[1].to_float() > 26.0:
					errors.append("hour: hours are 0..26 in '%s'" % term)
			"weekday":
				for w in arg.split(",", false):
					if not w.is_valid_int() or w.to_int() < 0 or w.to_int() > 6:
						errors.append("weekday: '%s' is not 0..6 in '%s'" % [w, term])
				if arg == "":
					errors.append("weekday: needs a list in '%s'" % term)
			"season":
				for s in arg.split(",", false):
					if StringName(s) not in CalendarUtil.seasons():
						errors.append("season: unknown season '%s' in '%s'" % [s, term])
				if arg == "":
					errors.append("season: needs a list in '%s'" % term)
			"open":
				var lr := Svc.node("LuaRuntime")
				if arg == "":
					errors.append("open: needs a shop id in '%s'" % term)
				elif lr != null and lr.has_method("get_shops") and not LuaData.dict(lr.call("get_shops")).is_empty() and not LuaData.dict(lr.call("get_shops")).has(arg):
					errors.append("open: unknown shop '%s' in '%s'" % [arg, term])
			"quest", "done", "flag":
				if arg == "":
					errors.append("%s: needs an id in '%s'" % [kind, term])
	return errors


# ======================================================================================= context for dialogue and the People book

## The part of the day: morgen < 11 <= dag < 17 <= aften < 21 <= nat; a RAW hour below the day start (the transient 02:00..05:59 after the roll) is nat too.
func daypart(h: int = -1) -> String:
	var hh := GameManager.hour if h < 0 else h
	if hh < GameManager.day_start_hour():
		return "nat"
	if hh < 11:
		return "morgen"
	if hh < 17:
		return "dag"
	if hh < 21:
		return "aften"
	return "nat"


## What the dialogue layer (P14 / S-talk) reads about the citizen and the moment.
func dialogue_context(npc: Variant) -> Dictionary:
	var id := str(npc)
	var lim := gift_limits(id)
	return {
		"hearts": hearts(id), "stage": String(stage(id)), "weekday": CalendarUtil.weekday_of(today()), "weather": String(TimeManager.weather), "daypart": daypart(),
		"birthday": is_birthday(id), "festival": String(festival_active()), "chat_open": chat_available(id), "talked_today": talked_today(id),
		"gifts_left": int(lim["left_week"]) if int(lim["left_today"]) > 0 else 0, "partner": str(_partner.get("id", "")) == id and id != "",
	}


## Has the player met this citizen? (talked to him once, or has points with him)
func met(npc: Variant) -> bool:
	var row := _row(str(npc), false)
	return not row.is_empty() and (LuaData.int_of(row.get("bk", 0)) == 1 or LuaData.int_of(row.get("gt", 0)) > 0 or LuaData.int_of(row.get("p", 0)) > 0)


## The rows of the People book: only MET citizens (an absent hero twin stays hidden), sorted by id:
## {id, name_key, stage, hearts, half_hearts, birthday ({season, day} when known else {}), next_birthday ({days, total_day, season, day} when known else {}), chat_done (this week),
## gifts_left, tastes {item: class}, events_seen, events_ready}.
func people_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in SocialData.friend_ids():
		if not met(id) or _absent(id):
			continue
		var row := _row(id, false)
		var lim := gift_limits(id)
		var events := SocialData.events(id)
		var seen := 0
		for eid in events:
			if event_seen(str(eid)):
				seen += 1
		out.append({
			"id": id, "name_key": str(SocialData.npc_row(id).get("name_key", "")), "stage": String(stage(id)), "hearts": hearts(id), "half_hearts": half_hearts(id),
			"birthday": SocialData.birthday_of(id).duplicate() if birthday_known(id) else {}, "next_birthday": next_birthday(id) if birthday_known(id) else {}, "chat_done": LuaData.int_of(row.get("wk", -1), -1) == week(),
			"gifts_left": int(lim["left_week"]) if int(lim["left_today"]) > 0 else 0, "tastes": LuaData.dict(row.get("kn", {})).duplicate(),
			"events_seen": seen, "events_ready": events_ready(id).size(),
		})
	return out


## The heart events of a citizen that can be started now: meta.hearts reached, not seen yet, and meta.when holds (the scenes are S-heart-content's).
func events_ready(npc: Variant) -> Array[String]:
	var id := str(npc)
	var out: Array[String] = []
	var h := hearts(id)
	var events := SocialData.events(id)
	var ids: Array = events.keys()
	ids.sort()
	for eid in ids:
		var meta := LuaData.dict(LuaData.dict(events[eid]).get("meta", {}))
		if event_seen(str(eid)) or LuaData.int_of(meta.get("hearts", 0)) > h:
			continue
		var cond := str(meta.get("when", ""))
		if cond == "" or eval_when(cond):
			out.append(str(eid))
	return out


func event_seen(event_id: String) -> bool:
	return LuaData.int_of(_seen.get(event_id, 0)) > 0


## S-events / S-heart-content: a scene was played (1 = once for good, a year number = once per year).
func mark_event_seen(event_id: String, stamp: int = 1) -> void:
	if event_id != "":
		_seen[event_id] = maxi(stamp, 1)


func festival_attended_year(festival_id: String) -> int:
	return LuaData.int_of(_fest_year.get(festival_id, 0))


func mark_festival_attended(festival_id: String, year: int) -> void:
	if festival_id != "":
		_fest_year[festival_id] = maxi(year, 1)


## The no-repeat memory of S-talk: the last line id picked for (npc, slot). Session memory (not saved).
func remember_line(npc: Variant, slot: String, line_id: String) -> void:
	var memory: Dictionary = _lines.get(str(npc), {})
	memory[slot] = line_id
	_lines[str(npc)] = memory


func last_line(npc: Variant, slot: String) -> String:
	return str(LuaData.dict(_lines.get(str(npc), {})).get(slot, ""))


# ======================================================================================= day / time hooks

## Daily work is DEFERRED to the end of the frame and coalesced: a 50 h skip delivers several day_started in one call, tests count game_event emissions
## synchronously (core.advance_time_multiday pins "exactly 2 game_event" for 50 h: a synchronous birthday_today broke it in the prototype), and ONE catch-up
## loop over the skipped days is cheaper and simpler than a handler per day. flush() runs it at once (tests, loads).
func _on_day_started(_day: int, _season: StringName) -> void:
	_defer()


func _on_time_changed(_hour: int, _minute: int) -> void:
	_defer()


func _on_area_changed(_area_id: StringName) -> void:
	_apply_bed_hold()


func _on_game_event(event_name: StringName, _payload: Dictionary) -> void:
	if event_name == EV_FEST_START or event_name == EV_FEST_END:
		_apply_bed_hold()


func _on_load_completed(_slot: int) -> void:
	_defer()


func _defer() -> void:
	if not _pending:
		_pending = true
		call_deferred("flush")


## The daily work and the festival state, now. Public for tests and loads; loops over every skipped day keyed on total_day. The world flag birthday_today follows the
## STATE (written here, idempotently, not by the day roll and not by reset()): a new game that starts on somebody's birthday (fairy_lily, foraar 1, in the design data)
## gets it with the first flush after the start, so the world flags are still exactly the new game's own at the moment new_game_started fires (core pins that).
func flush() -> void:
	_pending = false
	_process_days()
	_write_birthday_flag(birthdays_today())
	_update_festival_state()


func _process_days() -> void:
	var td := today()
	if _last_day == 0:
		_last_day = td
	var guard := 0
	while _last_day < td and guard < 400:
		_last_day += 1
		guard += 1
		_day_step(_last_day, _last_day == td)
	_last_day = td


## One day of daily work. Only TODAY posts events: a skipped day posts nothing (state queries instead of edge triggers).
func _day_step(td: int, is_today: bool) -> void:
	if not is_today:
		return
	for npc in birthdays_on(td):
		EventBus.game_event.emit(EV_BIRTHDAY, {"npc": npc})


## birthday_today = the first citizen (sorted id) whose birthday is today, absent when nobody's is. Writes only when the value differs.
func _write_birthday_flag(names: Array[String]) -> void:
	if names.is_empty():
		if GameManager.world_flags.has(&"birthday_today"):
			GameManager.clear_flag(&"birthday_today")
	elif str(GameManager.get_flag(&"birthday_today", "")) != names[0]:
		GameManager.set_flag(&"birthday_today", names[0])


## The derived flags, state only (no event): used by from_dict() (a load puts the world in the state the save was in). reset() deliberately does NOT call it.
func _restore_state() -> void:
	_write_birthday_flag(birthdays_today())
	_festival_active = festival_active()
	_write_festival_flag()
	_apply_bed_hold()


# ======================================================================================= save / reset

## A new game (and a save without the section): points are re-seeded from the flags friend_<npc> so the old hearts-only saves keep their hearts; the weekly
## chat of a heart that was given in the week of friend_last_<npc> counts as taken.
func reset() -> void:
	_rows.clear()
	_seen.clear()
	_fest_year.clear()
	_partner.clear()
	_orphans.clear()
	_lines.clear()
	_toast_queue.clear()
	_toast_next_ms = 0
	_shop_now = ""
	_release_bed_hold()
	world_seed = 0
	for id in SocialData.friend_ids():
		var h := GameManager.flag_int(StringName("friend_" + id), 0)
		if h > 0:
			var row := _row(id)
			row["p"] = mini(h, heart_cap()) * points_per_heart()
			var last := GameManager.flag_int(StringName("friend_last_" + id), 0)
			if last > 0:
				row["wk"] = CalendarUtil.week_of(last)
	_last_day = today()
	# the derived flags (birthday_today, festival_now) and the bed hold are brought in line by the flush that follows (a new game's world flags stay exactly its own
	# at the moment new_game_started fires): _festival_active is cleared so a festival that is running by then is announced like any other state change
	_festival_active = &""
	_defer()


func to_dict() -> Dictionary:
	var npcs := {}
	for id in _rows:
		var r: Dictionary = _rows[id]
		var o := {}
		for k in ROW_INT_KEYS:
			var v := LuaData.int_of(r.get(k, 0))
			if v != (-1 if k in ROW_NEVER_KEYS else 0):
				o[k] = v
		if not LuaData.arr(r.get("ls", [])).is_empty():
			o["ls"] = LuaData.arr(r["ls"]).duplicate(true)
		if not LuaData.dict(r.get("kn", {})).is_empty():
			o["kn"] = LuaData.dict(r["kn"]).duplicate()
		if not o.is_empty():
			npcs[id] = o
	var out := {"v": SAVE_V, "seed": world_seed, "last": _last_day, "npcs": npcs, "seen": _seen.duplicate(), "fest": _fest_year.duplicate(), "partner": _partner.duplicate()}
	if not _orphans.is_empty():
		out["orphans"] = _orphans.duplicate(true)
	return out


## Applies a saved section. NEVER emits and NEVER push_errors (a push_error would reject the whole load): an unknown NPC id (content drift) is a push_warning and
## goes to the orphans bucket, which the next save keeps; an orphan whose NPC exists again is taken back. Returns true.
func from_dict(d: Dictionary) -> bool:
	_rows.clear()
	_orphans.clear()
	_lines.clear()
	_toast_queue.clear()
	_toast_next_ms = 0
	_shop_now = ""
	world_seed = LuaData.int_of(d.get("seed", 0)) & 0x1FFFFFFFFFFFFF
	_last_day = LuaData.int_of(d.get("last", 0))
	_seen = LuaData.int_map(d.get("seen", {}))
	_fest_year = LuaData.int_map(d.get("fest", {}))
	_partner = {}
	for k in LuaData.dict(d.get("partner", {})):
		var v: Variant = LuaData.dict(d["partner"])[k]
		_partner[str(k)] = LuaData.int_of(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else v
	var known := SocialData.npcs()
	var src := LuaData.dict(d.get("npcs", {}))
	var old_orphans := LuaData.dict(d.get("orphans", {}))
	for id in src:
		if known.has(id):
			_load_row(str(id), LuaData.dict(src[id]))
		else:
			_orphans[str(id)] = LuaData.dict(src[id]).duplicate(true)
			push_warning("SocialManager.from_dict: unknown NPC '%s' kept in the orphans bucket" % str(id))
	for id in old_orphans:
		if known.has(id):
			_load_row(str(id), LuaData.dict(old_orphans[id]))
		else:
			_orphans[str(id)] = LuaData.dict(old_orphans[id]).duplicate(true)
	for id in _rows:
		_mirror(str(id))
	_restore_state()
	return true


func _load_row(id: String, raw: Dictionary) -> void:
	var row := _row(id)
	for k in ROW_INT_KEYS:
		if raw.has(k):
			row[k] = LuaData.int_of(raw[k], -1 if k in ROW_NEVER_KEYS else 0)
	row["p"] = clampi(LuaData.int_of(row["p"]), 0, heart_cap() * points_per_heart())
	var ls: Array = []
	for e in LuaData.arr(raw.get("ls", [])):
		if e is Array and (e as Array).size() == 2 and ls.size() < LAST_GIFTS:
			ls.append([str(e[0]), LuaData.int_of(e[1])])
	row["ls"] = ls
	var kn := {}
	var known_cap := SocialData.cfg_int("gifts.known_cap", 40)
	for item in LuaData.dict(raw.get("kn", {})):
		if kn.size() < known_cap:
			kn[str(item)] = str(raw["kn"][item])
	row["kn"] = kn
