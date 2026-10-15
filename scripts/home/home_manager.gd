extends Node
## HomeManager (autoload): the ten tiers of the home (Skur -> Slottet), the requirements and the construction of the next tier, the perks of the
## tier you live in, the home chest, the weekly guest gifts and the Fe-fest.
##
## DATA. lua/data/home_tiers.lua (config key `home`, read through HomeData): tiers[n] {cost{gold,days,materials}, requires{quests,friendship,hygge},
## perks{max_energy_bonus,storage_slots,furniture_capacity,guest_visits_per_week,unlocks}, gift_items}, hygge_levels, unlock_status. The gold price is
## multiplied with economy.home_cost_scale (P10, default 1.0).
##
## STATE (SaveManager section "home", order 10): {v, tier, construction{target,start_day,ready_day}, chest{item: int}, festival_day, visit_week}.
## `tier` is a plain int property (1..10). Construction days are ABSOLUTE (GameManager.total_day()), never the day of the season, so a build survives
## a season and a year wrap. Two optional keys are written only when they have something to say: `party` (the guests of today's Fe-fest, so a save made on
## the festival day keeps them) and `gifts_pending` (tier gifts that could not be delivered yet). A save without the section calls reset().
##
## WORLD FLAGS (GameManager, JSON-safe ints; the content dialogue and N02 / N05 read them as bare flags):
##   home_tier 1..10 (always set: new game, load, upgrade; a load keeps a usable value of the game section and repairs a missing one)   home_building = the tier under construction, else 0
##   home_upgrade_done = the tier that was just finished until the builder (fairy_builder) has celebrated it in a dialogue, else 0
##   home_castle_built = true from tier 10 on
##
## REQUIREMENT ROWS (requirements(n), what the Husbyggeri screen lists): {kind, key, id, have, need, met, name_key?}
##   gold      key HOME_UI_COST              have = guldagern, need = the price
##   material  key ITEM_<ID>                 have = backpack + home chest
##   days      key HOME_UI_BUILD_DAYS_FMT    informational, always met
##   quest     key HOME_GATE_QUEST_FMT       id = quest id, name_key QUEST_<ID>_TITLE        (QuestManager.is_completed)
##   friend    key HOME_GATE_FRIEND_FMT      id = npc id, name_key = the npc's name key       (world flag friend_<npc>, hearts)
##   hygge     key HOME_GATE_HYGGE_FMT       id = level id, have/need = LEVEL INDEX           (FurnitureManager.hygge_level_index())
##
## LATE BINDING. QuestManager, FurnitureManager, LootService and SocialManager are reached through Svc.node(): a manager that does not exist counts as
## "nothing done / nothing there" (hygge level 0, no gift roll, no named friend, no guest), never as an error. The guest hooks of SocialManager
## (partner_in_home, pick_visitor, start_house_party) belong to S-marriage: without them guests_today() is [] and the weekly gift stays anonymous (DT37).

const SAVE_VERSION := 1
const _Svc := preload("res://scripts/data/svc.gd")
const _Data := preload("res://scripts/data/lua_data.gd")
const _Codec := preload("res://scripts/data/save_codec.gd")
const _HomeData := preload("res://scripts/home/home_data.gd")
const _Kinds := preload("res://scripts/data/item_kinds.gd")

const FLAG_CASTLE_BUILT := &"home_castle_built"
const FINALE_QUEST := &"slotsdroemmen"
const FINALE_OBJECTIVE := "hold_feast"
const MAX_PARTY := 6
const NO_VISIT_WEEK := -1
## a visit container that opens empty is opened again (fresh uid) up to this many times in all
const VISIT_ATTEMPTS := 3

## the chest content changed (deposit / withdraw / paying a build from it)
signal chest_changed()

var tier: int = 1
## {} when idle, else {target, start_day, ready_day} in absolute total days
var construction: Dictionary = {}
## {item id: amount} - capacity storage_slots stacks of max_stack (99 when the item says nothing)
var chest: Dictionary = {}
## total day of the last Fe-fest (0 = never)
var festival_day: int = 0
## calendar week (0-based, HomeData.week_of) of the last weekly guest gift (-1 = none yet)
var visit_week: int = NO_VISIT_WEEK

var _party: Array[String] = []              # the friends of the Fe-fest held on festival_day
var _pending_gifts: Array[String] = []      # tier gifts that could not be delivered yet (retried every morning)
var _visit_day: int = 0                     # total day of the last guest visit (idempotence, never saved)
var _visit: Dictionary = {}                 # {npc, item, week, index} of that visit
var _dialogue_npc: StringName = &""
var _dialogue_done_at_start: int = 0
var _captured_loot: Array = []              # results of the loot_rolled signal seen while a visit container is opened
var _loot_reason: String = ""               # LootService's reason for the last visit container ("" = a find, "nothing" = it was empty, else why it refused)
var _loot_refused: bool = false             # LootService answered ok = false (full backpack, cooldown ...): no second attempt
var last_visit: Dictionary = {}             # {ok, reason, day, npc?, item?}: what the last visit attempt did (tests and the Husbyggeri card read it)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.register_section("home", self, SaveManager.FEATURE_ORDERS["home"])
	EventBus.day_started.connect(_on_day_started)
	EventBus.new_game_started.connect(reset)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)


# ---------------------------------------------------------------------------------------------------------------- data access

func tiers() -> Array:
	return _HomeData.tiers()


func last_tier() -> int:
	return _HomeData.last_tier()


func tier_def(n: int) -> Dictionary:
	return _HomeData.tier_def(n)


func perks(n: int = -1) -> Dictionary:
	return _HomeData.perks(tier if n < 0 else n)


func perk_int(n: int, key: String, default_value: int = 0) -> int:
	return _HomeData.perk_int(n, key, default_value)


## the price of tier n in guldagern (cost.gold x economy.home_cost_scale)
func gold_cost(n: int) -> int:
	return _HomeData.gold_cost(n)


func material_cost(n: int) -> Dictionary:
	return _HomeData.material_cost(n)


## the construction days of tier n (cost.days) - RV-P11
func build_days(n: int) -> int:
	return _HomeData.build_days(n)


func gift_items(n: int) -> Array[String]:
	return _HomeData.gift_items(n)


func is_max() -> bool:
	return tier >= last_tier()


func castle_built() -> bool:
	return tier >= last_tier()


## tests and tools only: sets the tier and mirrors the flags (the game changes the tier through start_upgrade / finish_upgrade)
func set_tier(n: int) -> void:
	tier = clampi(n, 1, last_tier())
	_sync_flags()


# ---------------------------------------------------------------------------------------------------------------- materials (backpack + home chest)

## backpack + home chest: what the builder counts
func count_material(item_id: Variant) -> int:
	return EconomyManager.count_item(StringName(str(item_id))) + chest_count(item_id)


## takes from the backpack first, then from the chest. All or nothing: false (nothing changed) when there is less than `amount`.
func consume_material(item_id: Variant, amount: int) -> bool:
	var taken := _take_material(item_id, amount)
	if bool(taken["ok"]) and int(taken["from_chest"]) > 0:
		chest_changed.emit()
	return bool(taken["ok"])


## {ok, from_pack, from_chest}: the units that left the backpack and the chest (nothing moved when ok is false)
func _take_material(item_id: Variant, amount: int) -> Dictionary:
	var id := StringName(str(item_id))
	var from_pack := mini(amount, EconomyManager.count_item(id))
	var from_chest := amount - from_pack
	if amount <= 0 or from_chest > chest_count(item_id):
		return {"ok": false, "from_pack": 0, "from_chest": 0}
	if from_pack > 0 and not EconomyManager.remove_item(id, from_pack):
		return {"ok": false, "from_pack": 0, "from_chest": 0}
	if from_chest > 0:
		_chest_take(str(item_id), from_chest)
	return {"ok": true, "from_pack": from_pack, "from_chest": from_chest}


# ---------------------------------------------------------------------------------------------------------------- requirements

## the rows of the Husbyggeri screen for tier n (see the header); [] for tier 1 and for a tier that does not exist
func requirements(n: int) -> Array:
	var rows: Array = []
	if n < 2 or n > last_tier():
		return rows
	var gold_need := gold_cost(n)
	rows.append({"kind": "gold", "key": "HOME_UI_COST", "id": "gold", "have": EconomyManager.gold, "need": gold_need, "met": EconomyManager.gold >= gold_need})
	var mats := material_cost(n)
	for m in mats:
		var have := count_material(m)
		rows.append({"kind": "material", "key": "ITEM_%s" % str(m).to_upper(), "id": str(m), "have": have, "need": int(mats[m]), "met": have >= int(mats[m])})
	rows.append({"kind": "days", "key": "HOME_UI_BUILD_DAYS_FMT", "id": "days", "have": 0, "need": build_days(n), "met": true})
	var req := _HomeData.requires(n)
	for q in _Data.strings(req.get("quests", [])):
		var done := _quest_completed(q)
		rows.append({"kind": "quest", "key": "HOME_GATE_QUEST_FMT", "id": q, "name_key": "QUEST_%s_TITLE" % q.to_upper(), "have": 1 if done else 0, "need": 1, "met": done})
	var friends := _Data.int_map(req.get("friendship", {}))
	for npc in friends:
		var hearts := hearts_of(npc)
		rows.append({"kind": "friend", "key": "HOME_GATE_FRIEND_FMT", "id": npc, "name_key": _npc_name_key(npc), "have": hearts, "need": int(friends[npc]), "met": hearts >= int(friends[npc])})
	if req.has("hygge"):
		var need_level := _Data.int_of(req["hygge"])
		var level := hygge_level_index()
		rows.append({"kind": "hygge", "key": "HOME_GATE_HYGGE_FMT", "id": str(_HomeData.hygge_level(need_level).get("id", need_level)), "name_key": str(_HomeData.hygge_level(need_level).get("name_key", "")), "have": level, "need": need_level, "met": level >= need_level})
	return rows


## {ok, reason, reasons[], rows[]}. reason = the FIRST blocker: max | not_next | busy | gold | materials | gate | ok.
## `n` is the tier asked about (default: the next one); only the next tier can be started.
func can_start_upgrade(n: int = -1) -> Dictionary:
	var target := tier + 1 if n < 0 else n
	if tier >= last_tier() or target > last_tier():
		return {"ok": false, "reason": "max", "reasons": ["max"], "rows": []}
	if target != tier + 1:
		return {"ok": false, "reason": "not_next", "reasons": ["not_next"], "rows": []}
	if is_under_construction():
		return {"ok": false, "reason": "busy", "reasons": ["busy"], "rows": []}
	var rows := requirements(target)
	var reasons: Array = []
	for r in rows:
		if not bool(r["met"]):
			var why := "gold" if r["kind"] == "gold" else ("materials" if r["kind"] == "material" else "gate")
			if why not in reasons:
				reasons.append(why)
	return {"ok": reasons.is_empty(), "reason": "ok" if reasons.is_empty() else str(reasons[0]), "reasons": reasons, "rows": rows}


## Pays gold and materials (all or nothing; materials from the backpack first, then the chest) and starts the construction of the next tier:
## construction {target, start_day, ready_day} in absolute total days, flag home_building, signal home_upgrade_started, a toast.
func start_upgrade() -> Dictionary:
	var chk := can_start_upgrade()
	if not bool(chk["ok"]):
		return chk
	var n := tier + 1
	var cost := gold_cost(n)
	var mats := material_cost(n)
	if not EconomyManager.spend_gold(cost):
		return {"ok": false, "reason": "gold", "reasons": ["gold"], "rows": chk["rows"]}
	var paid: Array = []                                    # [id, from_pack, from_chest] of what already left
	for m in mats:
		var taken := _take_material(m, int(mats[m]))
		if not bool(taken["ok"]):
			EconomyManager.add_gold(cost)                  # cannot happen after can_start_upgrade(); if it does, everything goes back
			for p in paid:
				if int(p[1]) > 0:
					EconomyManager.add_item(StringName(str(p[0])), int(p[1]), true)
				if int(p[2]) > 0:
					chest[str(p[0])] = chest_count(p[0]) + int(p[2])
			if not paid.is_empty():
				chest_changed.emit()
			return {"ok": false, "reason": "materials", "reasons": ["materials"], "rows": chk["rows"]}
		paid.append([str(m), int(taken["from_pack"]), int(taken["from_chest"])])
	for p in paid:
		if int(p[2]) > 0:
			chest_changed.emit()
			break
	var start := GameManager.total_day()
	construction = {"target": n, "start_day": start, "ready_day": start + build_days(n)}
	_sync_flags()
	EventBus.home_upgrade_started.emit(tier, n, int(construction["ready_day"]))
	_toast("HOME_UI_TITLE", _format(tr("HOME_UI_BUILDING_FMT"), [build_days(n)]))
	return {"ok": true, "reason": "ok", "reasons": [], "ready_day": int(construction["ready_day"]), "rows": chk["rows"]}


func is_under_construction() -> bool:
	return not construction.is_empty()


func days_left() -> int:
	return maxi(0, int(construction.get("ready_day", 0)) - GameManager.total_day()) if is_under_construction() else 0


## 0..1 of the construction that has passed
func progress_ratio() -> float:
	if not is_under_construction():
		return 0.0
	var total := maxi(1, int(construction["ready_day"]) - int(construction["start_day"]))
	return clampf(1.0 - float(days_left()) / float(total), 0.0, 1.0)


## the house is closed (the door whispers HOME_UI_BUILDING_CLOSED) while it is built
func can_enter_home() -> bool:
	return not is_under_construction()


## Finishes the construction that is under way: the tier changes, the flags are mirrored, the tier's gift pieces are delivered, home_upgraded is
## emitted (+ game_event home_upgraded {tier}) and the player gets a toast. Does nothing when nothing is being built. The day check is done by the
## day_started handler (total_day >= ready_day), so a caller that wants the house done NOW (a test, the debug console) may call this directly.
func finish_upgrade() -> void:
	if not is_under_construction():
		return
	var old := tier
	tier = clampi(int(construction["target"]), 1, last_tier())
	construction = {}
	_sync_flags()
	GameManager.set_flag(GameManager.FLAG_HOME_UPGRADE_DONE, tier)
	for id in gift_items(tier):
		_deliver_gift(id)
	EventBus.home_upgraded.emit(old, tier)
	EventBus.game_event.emit(&"home_upgraded", {"tier": tier})
	_toast("HOME_UI_TITLE", _format(tr("HOME_UI_UPGRADED_FMT"), [tr(_HomeData.tier_name_key(tier))]))


func _on_day_started(_day: int, _season: StringName) -> void:
	_retry_pending_gifts()
	if is_under_construction():
		if GameManager.total_day() >= int(construction["ready_day"]):
			finish_upgrade()
		else:
			EventBus.home_upgrade_progress.emit(days_left(), int(construction["ready_day"]) - int(construction["start_day"]))
	_roll_weekly_visit()


# ---------------------------------------------------------------------------------------------------------------- flags

## home_tier / home_building (and home_castle_built) always follow the state; home_upgrade_done is only written by finish_upgrade() and the builder dialogue.
func _sync_flags() -> void:
	GameManager.set_flag(GameManager.FLAG_HOME_TIER, tier)
	_sync_derived_flags()


## home_building and home_castle_built are DERIVED from this section (the construction under way, the tier): always rewritten.
func _sync_derived_flags() -> void:
	GameManager.set_flag(GameManager.FLAG_HOME_BUILDING, int(construction["target"]) if is_under_construction() else 0)
	if castle_built():
		GameManager.set_flag(FLAG_CASTLE_BUILT, true)
	else:
		GameManager.clear_flag(FLAG_CASTLE_BUILT)


func _on_dialogue_started(npc_id: StringName, _dialogue_id: StringName) -> void:
	_dialogue_npc = npc_id
	_dialogue_done_at_start = GameManager.flag_int(GameManager.FLAG_HOME_UPGRADE_DONE, 0)


## The builder has had her celebration line (the dialogue branch reads home_upgrade_done): the flag goes back to 0. A tier that finished DURING the
## dialogue keeps its flag (the builder has not said anything about it yet).
func _on_dialogue_ended() -> void:
	var talked_to := _dialogue_npc
	_dialogue_npc = &""
	if str(talked_to) != str(_HomeData.config().get("builder_npc", "fairy_builder")):
		return
	var now := GameManager.flag_int(GameManager.FLAG_HOME_UPGRADE_DONE, 0)
	if now != 0 and now == _dialogue_done_at_start:
		GameManager.set_flag(GameManager.FLAG_HOME_UPGRADE_DONE, 0)


# ---------------------------------------------------------------------------------------------------------------- housewarming gifts

## one tier gift through EconomyManager (routed to the furniture store). A keepsake the player already owns is not given twice; a gift that cannot
## be delivered right now is kept and retried every morning, never dropped.
func _deliver_gift(item_id: String) -> void:
	var id := StringName(item_id)
	if _Kinds.is_one_of_a_kind(id) and EconomyManager.count_item(id) >= 1:
		return
	if not EconomyManager.add_item(id, 1) and item_id not in _pending_gifts:
		_pending_gifts.append(item_id)


func _retry_pending_gifts() -> void:
	if _pending_gifts.is_empty():
		return
	var still: Array[String] = []
	for item_id in _pending_gifts:
		var id := StringName(item_id)
		if _Kinds.is_one_of_a_kind(id) and EconomyManager.count_item(id) >= 1:
			continue
		if not EconomyManager.can_add_item(id, 1) or not EconomyManager.add_item(id, 1):       # can_add_item first: a retry that cannot succeed posts no "backpack full" toast
			still.append(item_id)
	_pending_gifts = still


func pending_gifts() -> Array[String]:
	return _pending_gifts.duplicate()


# ---------------------------------------------------------------------------------------------------------------- perks of the tier you live in

## added to the maximum energy (Perks: energy = min(gear + furniture + home, 60)); natural points, no cap here
func max_energy_bonus() -> int:
	return perk_int(tier, "max_energy_bonus", 0)


func storage_slots() -> int:
	return perk_int(tier, "storage_slots", 0)


func furniture_capacity() -> int:
	return perk_int(tier, "furniture_capacity", 0)


func guest_visits_per_week() -> int:
	return perk_int(tier, "guest_visits_per_week", 0)


## Is the unlock `unlock_name` (workbench oven loom guest_visits forge_bench forecast festival royal_visit) listed by the tier you live in or an earlier one?
func unlocked(unlock_name: Variant) -> bool:
	var u := str(unlock_name)
	for n in range(1, mini(tier, tiers().size()) + 1):
		if u in _HomeData.unlocks_of(n):
			return true
	return false


## real | partial | stub (home.unlock_status): what the unlock actually does today. oven, forecast and royal_visit are listed and do nothing.
func unlock_status(unlock_name: Variant) -> String:
	return _HomeData.unlock_status(str(unlock_name))


## Is the crafting station (snedkerbord, vaev, smedje) open? snedkerbord <- workbench (tier 1), vaev <- loom (tier 3), smedje <- forge_bench (tier 5).
func station_available(station: Variant) -> bool:
	var unlock_name: String = str(_HomeData.STATION_UNLOCKS.get(str(station), ""))
	return unlock_name != "" and unlocked(unlock_name)


## every unlock the data lists: [{id, status, unlocked, tier, name_key, desc_key}] for the perks card of the Husbyggeri screen
func unlock_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for u in _HomeData.unlock_ids():
		rows.append({"id": u, "status": unlock_status(u), "unlocked": unlocked(u), "tier": _HomeData.unlock_tier(u),
			"name_key": "HOME_UNLOCK_%s" % u.to_upper(), "desc_key": "HOME_UNLOCK_%s_DESC" % u.to_upper()})
	return rows


# ---------------------------------------------------------------------------------------------------------------- home chest (Hjemmekiste)

func chest_capacity() -> int:
	return storage_slots()


## slots in use: every item takes ceil(amount / stack) slots
func chest_used() -> int:
	var n := 0
	for id in chest:
		n += ceili(float(int(chest[id])) / float(_HomeData.chest_stack(id)))
	return n


func chest_free_slots() -> int:
	return maxi(0, chest_capacity() - chest_used())


func chest_count(item_id: Variant) -> int:
	return int(chest.get(str(item_id), 0))


func chest_items() -> Dictionary:
	return chest.duplicate()


## how many more units of this item the chest can take: the room left in its last stack plus the free slots
func chest_room_for(item_id: Variant) -> int:
	var stack := _HomeData.chest_stack(item_id)
	var have := chest_count(item_id)
	var slack := (stack - have % stack) % stack
	return slack + chest_free_slots() * stack


## Backpack -> chest. Returns how many units moved (0 when the item is not a backpack item, the chest is full or the player has none). Furniture and
## clothing live in their own stores and never go into the chest.
func deposit(item_id: StringName, amount: int) -> int:
	if amount <= 0 or item_id == &"" or _Kinds.storage_of(item_id) != _Kinds.BACKPACK:
		return 0
	var moved := mini(mini(amount, EconomyManager.count_item(item_id)), chest_room_for(item_id))
	if moved <= 0 or not EconomyManager.remove_item(item_id, moved):
		return 0
	chest[str(item_id)] = chest_count(item_id) + moved
	chest_changed.emit()
	return moved


## Chest -> backpack (silent: no item_gained, no toast: a withdrawal is not a find). Returns how many units moved; stops when the backpack is full.
func withdraw(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var moved := mini(mini(amount, chest_count(item_id)), EconomyManager.backpack_room_for(item_id))
	if moved <= 0 or not EconomyManager.add_item(item_id, moved, true):
		return 0
	_chest_take(str(item_id), moved)
	chest_changed.emit()
	return moved


func _chest_take(item_key: String, amount: int) -> void:
	var left := int(chest.get(item_key, 0)) - amount
	if left > 0:
		chest[item_key] = left
	else:
		chest.erase(item_key)


# ---------------------------------------------------------------------------------------------------------------- guests: the weekly gift, the Fe-fest, who is at home

## Every morning of a visit day (HomeData.visit_weekdays(guest_visits_per_week)): ONE container `trae` of zone `farm` is opened by LootService (it delivers to
## the stores; an empty opening is repeated up to VISIT_ATTEMPTS times), the player gets a toast and visitor_gift(npc, item) fires. The visitor is a FRIEND (SocialManager.pick_visitor(week, i): hearts >= 4,
## deterministic, never the same citizen twice a week) when S-marriage provides it, else an unnamed fairy friend (npc = ""). Nobody walks in. While the
## house is being built nobody comes; without a LootService there is nothing to leave.
func _roll_weekly_visit() -> void:
	var per_week := guest_visits_per_week()
	if per_week <= 0:
		return
	var td := GameManager.total_day()
	var index := _HomeData.visit_weekdays(per_week).find(_HomeData.weekday_of(td))
	if index < 0 or _visit_day == td:
		return
	_visit_day = td
	_visit = {}
	if is_under_construction():
		last_visit = {"ok": false, "reason": "building", "day": td}
		return
	var week := _HomeData.week_of(td)
	var loot := _Svc.node("LootService")
	if loot == null or not loot.has_method("open_container"):
		last_visit = {"ok": false, "reason": "no_loot_service", "day": td}
		return
	var npc := _visitor_for(week, index)
	var result: Dictionary = {}
	for attempt in VISIT_ATTEMPTS:
		# a container that opens and holds nothing (the farm has no uncommon or rare pool, so about 3 of 10 `trae` openings are empty) is opened again with a fresh uid;
		# a container that LootService REFUSES (full backpack, cooldown, unknown) is not retried
		result = _open_visit_container(loot, "home:visit:%d:%d" % [week, index] + ("" if attempt == 0 else ":%d" % attempt))
		if not result.is_empty() or _loot_refused:
			break
	if result.is_empty():
		last_visit = {"ok": false, "reason": "nothing_left", "day": td, "loot_reason": _loot_reason}
		return
	var item := str(result.get("id", ""))
	visit_week = week
	_visit = {"npc": npc, "item": item, "week": week, "index": index}
	last_visit = {"ok": true, "reason": "ok", "day": td, "npc": npc, "item": item}
	EventBus.visitor_gift.emit(StringName(npc), StringName(item))
	_toast("HOME_UNLOCK_GUEST_VISITS", _format(tr("FIND_UI_FOUND_FMT"), [tr("ITEM_%s" % item.to_upper())]))


func _visitor_for(week: int, index: int) -> String:
	var sm := _Svc.node("SocialManager")
	if sm == null or not sm.has_method("pick_visitor"):
		return ""
	return str(sm.call("pick_visitor", week, index))


## Opens the visit container and returns the first result {id, amount, ...}; {} when nothing came out. LootService.open_container(zone, container_id, uid)
## answers {ok, results: [{id, amount, rarity, kind}], reason}; a plain Array of results and/or the loot_rolled signal are accepted as well. The reason of a
## refused open (cooldown, full backpack ...) is kept in _loot_reason.
func _open_visit_container(loot: Node, uid: String) -> Dictionary:
	_captured_loot = []
	_loot_reason = ""
	_loot_refused = false
	EventBus.loot_rolled.connect(_on_loot_rolled)
	var answer: Variant = loot.call("open_container", _HomeData.VISIT_ZONE, _HomeData.VISIT_CONTAINER, uid)
	EventBus.loot_rolled.disconnect(_on_loot_rolled)
	var results: Array = []
	if answer is Array:
		results = answer
	elif answer is Dictionary:
		results = _Data.arr((answer as Dictionary).get("results", []))
		_loot_reason = str((answer as Dictionary).get("reason", ""))
		_loot_refused = not bool((answer as Dictionary).get("ok", true))
	if results.is_empty():
		results = _captured_loot
	for r in results:
		if r is Dictionary and str((r as Dictionary).get("id", "")) != "":
			return r
	return {}


func _on_loot_rolled(_source_id: StringName, results: Array) -> void:
	_captured_loot.append_array(results)


## Holds the Fe-fest in the great hall: unlock `festival` (tier 8), once per 28 days, 500 guldagern. Emits game_event festival_held {} (the quest slotsdroemmen waits
## for it) and asks SocialManager.start_house_party() for the friends (<= 6, hearts >= 4) who come for the day. The 28-day cooldown is WAIVED while the quest
## slotsdroemmen is active and its objective hold_feast is still open, so a festival held at tier 8-9 can never block the finale.
## {ok, reason: ok | tier | cooldown | gold, cost, guests[], next_day}
func hold_festival() -> Dictionary:
	var cost := _HomeData.festival_cost()
	if not can_hold_festival_unlock():
		return {"ok": false, "reason": "tier", "cost": cost, "guests": [], "next_day": 0}
	var td := GameManager.total_day()
	if festival_cooldown_left() > 0 and not festival_waiver_active():
		return {"ok": false, "reason": "cooldown", "cost": cost, "guests": [], "next_day": festival_day + _HomeData.festival_cooldown_days()}
	if not EconomyManager.spend_gold(cost):
		return {"ok": false, "reason": "gold", "cost": cost, "guests": [], "next_day": 0}
	festival_day = td
	_party = _start_house_party()
	EventBus.game_event.emit(&"festival_held", {})
	_toast("HOME_UNLOCK_FESTIVAL", "")
	return {"ok": true, "reason": "ok", "cost": cost, "guests": _party.duplicate(), "next_day": festival_day + _HomeData.festival_cooldown_days()}


## the festival is unlocked: the data lists it for the tier you live in or an earlier one
func can_hold_festival_unlock() -> bool:
	return unlocked(_HomeData.FESTIVAL_UNLOCK)


## days until the next Fe-fest may be held (0 = now); the waiver of the finale quest is NOT counted here (see festival_waiver_active)
func festival_cooldown_left() -> int:
	if festival_day <= 0:
		return 0
	return maxi(0, festival_day + _HomeData.festival_cooldown_days() - GameManager.total_day())


## slotsdroemmen is active and its objective hold_feast is open: the player needs a festival now, the cooldown does not apply
func festival_waiver_active() -> bool:
	var qm := _Svc.node("QuestManager")
	if qm == null or not qm.has_method("is_active") or not bool(qm.call("is_active", FINALE_QUEST)):
		return false
	if qm.has_method("get_quest_progress"):
		var objectives := _Data.dict(_Data.dict(qm.call("get_quest_progress", FINALE_QUEST)).get("objectives", {}))
		if objectives.has(FINALE_OBJECTIVE):
			var o := _Data.dict(objectives[FINALE_OBJECTIVE])
			return not (bool(o.get("done", false)) or (o.has("current") and o.has("target") and _Data.int_of(o["current"]) >= _Data.int_of(o["target"])))
	return true


## the friends SocialManager lists for the party (<= 6), [] without S-marriage
func _start_house_party() -> Array[String]:
	var out: Array[String] = []
	var sm := _Svc.node("SocialManager")
	if sm == null or not sm.has_method("start_house_party"):
		return out
	var listed: Variant = sm.call("start_house_party")
	if listed is Array:
		for id in listed:
			if str(id) != "" and str(id) not in out and out.size() < MAX_PARTY:
				out.append(str(id))
	return out


## Who is at home today: [{npc, reason: partner | party | visit}], one entry per citizen (partner before party before visit).
##   partner  SocialManager.partner_in_home() - the partner stands in the farmhouse room (S-marriage)
##   party    the friends of today's Fe-fest (hold_festival -> SocialManager.start_house_party())
##   visit    the named friend who left today's weekly gift (an unnamed fairy is not a guest)
## Without S-marriage this is [] (honest stub, DT37).
func guests_today() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	var td := GameManager.total_day()
	var partner := _partner_in_home()
	if partner != "":
		_add_guest(out, seen, partner, "partner")
	if festival_day == td:
		for id in _party:
			_add_guest(out, seen, id, "party")
	if _visit_day == td and str(_visit.get("npc", "")) != "":
		_add_guest(out, seen, str(_visit["npc"]), "visit")
	return out


func _add_guest(out: Array[Dictionary], seen: Dictionary, npc: String, reason: String) -> void:
	if npc == "" or seen.has(npc):
		return
	seen[npc] = true
	out.append({"npc": npc, "reason": reason})


func _partner_in_home() -> String:
	var sm := _Svc.node("SocialManager")
	if sm == null or not sm.has_method("partner_in_home"):
		return ""
	var at_home: Variant = sm.call("partner_in_home")
	if at_home is String or at_home is StringName:
		return str(at_home)
	if not bool(at_home) or not sm.has_method("partner"):
		return ""
	return str(_Data.dict(sm.call("partner")).get("id", ""))


## today's visitor {npc, item, week, index}, {} when nobody came
func visit_today() -> Dictionary:
	return _visit.duplicate() if _visit_day == GameManager.total_day() else {}


# ---------------------------------------------------------------------------------------------------------------- lookups of the other managers (late bound)

func _quest_completed(quest_id: String) -> bool:
	var qm := _Svc.node("QuestManager")
	return qm != null and qm.has_method("is_completed") and bool(qm.call("is_completed", StringName(quest_id)))


## whole hearts of a citizen: the world flag friend_<npc> (SocialManager mirrors its hearts into it)
func hearts_of(npc_id: String) -> int:
	return GameManager.flag_int(StringName("friend_%s" % npc_id), 0)


## FurnitureManager.hygge_level_index() (0..5 into home.hygge_levels); 0 while the furniture manager does not exist
func hygge_level_index() -> int:
	var fm := _Svc.node("FurnitureManager")
	return _Data.int_of(fm.call("hygge_level_index")) if fm != null and fm.has_method("hygge_level_index") else 0


func _npc_name_key(npc_id: String) -> String:
	var npc := _Data.dict(_Svc.lua_config("npcs.%s" % npc_id, {}))
	return str(npc.get("name_key", "NPC_%s" % npc_id.to_upper()))


func _toast(title_key: String, message: String) -> void:
	EventBus.notification_posted.emit(tr(title_key), message, "home")


## `template % args` only when the template has a placeholder (a translation that is missing comes back as its key: it must never reach the formatter)
func _format(template: String, args: Array) -> String:
	return template % args if template.contains("%") else template


# ---------------------------------------------------------------------------------------------------------------- lifecycle and save section

## A new game (and a save without the section): a Skur, nothing under construction, an empty chest, no festival, no visits; the flags follow.
func reset() -> void:
	tier = 1
	construction = {}
	chest = {}
	festival_day = 0
	visit_week = NO_VISIT_WEEK
	_party = []
	_pending_gifts = []
	_visit_day = 0
	_visit = {}
	_dialogue_npc = &""
	last_visit = {}
	_sync_flags()
	GameManager.set_flag(GameManager.FLAG_HOME_UPGRADE_DONE, 0)


func to_dict() -> Dictionary:
	var out := {
		"v": SAVE_VERSION,
		"tier": tier,
		"construction": construction.duplicate(),
		"chest": chest.duplicate(),
		"festival_day": festival_day,
		"visit_week": visit_week,
	}
	if not _party.is_empty() and festival_day == GameManager.total_day():
		out["party"] = _party.duplicate()
	if not _pending_gifts.is_empty():
		out["gifts_pending"] = _pending_gifts.duplicate()
	return out


## Reads a section after the JSON round trip (every number is a float, ints are restored). Damaged values are repaired, never rejected: a bad tier is
## clamped, a construction that does not lead to the next tier is dropped, a chest entry that is not a positive number is dropped.
func from_dict(d: Dictionary) -> bool:
	tier = clampi(_Codec.to_int(d.get("tier", 1), 1), 1, maxi(last_tier(), 1))
	construction = {}
	var c := _Data.dict(d.get("construction", {}))
	if c.has("target"):
		var target := _Codec.to_int(c["target"])
		if target == tier + 1 and target <= last_tier():
			var start := _Codec.to_int(c.get("start_day", 0))
			var ready := _Codec.to_int(c.get("ready_day", 0))
			if ready <= start:
				ready = start + build_days(target)
			construction = {"target": target, "start_day": start, "ready_day": ready}
	chest = _Codec.int_counts(d.get("chest", {}))
	festival_day = maxi(_Codec.to_int(d.get("festival_day", 0)), 0)
	visit_week = _Codec.to_int(d.get("visit_week", NO_VISIT_WEEK), NO_VISIT_WEEK)
	_party = []
	for id in _Data.arr(d.get("party", [])):
		if str(id) != "" and str(id) not in _party and _party.size() < MAX_PARTY:
			_party.append(str(id))
	_pending_gifts = []
	for id in _Data.arr(d.get("gifts_pending", [])):
		if str(id) != "" and str(id) not in _pending_gifts:
			_pending_gifts.append(str(id))
	_visit_day = 0
	_visit = {}
	last_visit = {}
	_dialogue_npc = &""
	# the `game` section (applied before this one) brought home_tier from the same moment of the same save: a usable value (1..10) is kept exactly as it was
	# loaded (P15's JSON round trip test of world flags uses it as its int flag); a missing or unusable one is repaired from this section. home_building and
	# home_castle_built are derived, home_upgrade_done is present.
	var saved_flag := GameManager.flag_int(GameManager.FLAG_HOME_TIER, 0)
	if saved_flag < 1 or saved_flag > last_tier() or not GameManager.world_flags.has(GameManager.FLAG_HOME_TIER):
		GameManager.set_flag(GameManager.FLAG_HOME_TIER, tier)
	_sync_derived_flags()
	if not GameManager.world_flags.has(GameManager.FLAG_HOME_UPGRADE_DONE):
		GameManager.set_flag(GameManager.FLAG_HOME_UPGRADE_DONE, 0)
	return true
