extends RefCounted
## Section home (package F2-home-core, M1b stage 1): HomeManager and HomeData - the ten tiers, the requirements, the construction, the perks, the home chest,
## the weekly guest gifts, the Fe-fest and the save section. Ported from the design prototype's 245-check section (tests/sections/home.gd of FD) to the content ids
## and the content schema (lua/data/home_tiers.lua); every upgrade is driven through the REAL APIs of EconomyManager, QuestManager, GameManager and the real
## fairy_builder dialogue (tests/lib/features/grant.gd gives what a tier asks for); only the managers that other packages own are stand-ins:
##   FurnitureManager   the stand-in store of F1 (tests/lib/features/fake_furniture.gd, hygge level + placed pieces) - the real one is F3's (the combination is F3's furniture.hygge_levels / F10 row 14)
##   LootService        a recorder that answers like open_container(zone, container, uid) - the real one is F4's
##   SocialManager      partner_in_home / partner / pick_visitor / start_house_party - the real ones are S-marriage's (the stand-in proves the hooks, the SKIP names the owner)
##
## Named checks (the verify list of the order): home.block_by_each_requirement, home.payment_exact, home.construction_days_absolute, home.gift_items_delivered_once,
## home.flags_mirror, home.upgrade_done_cleared_after_builder_dialogue, home.perks_energy_storage_capacity, home.stations_by_tier, home.festival_cooldown,
## home.guest_visit_gift_rolls, home.chest_deposit_withdraw_capacity, home.save_mid_construction, home.missing_section_resets, home.project_godot_line_once,
## home.unlock_status, home.flag_home_tier_always_set, home.guests_today_shape, home.visitor_gift_names_a_friend, home.house_party_calls_social.
## A named check that aggregates several lines is true only when every one of its lines passed (_ck keeps the failures).
const SECTION := "home"
const TIMEOUT_S := 400.0

const PENDING_DIALOGUES := ["guard_oak", "fairy_wizard", "fairy_king"]
## the numbers of addendum 2.2 (tier 1..10), pinned so that a change of lua/data/home_tiers.lua is seen here
const ENERGY := [0, 3, 6, 9, 12, 15, 18, 22, 26, 30]
const SLOTS := [12, 18, 24, 30, 40, 50, 60, 72, 84, 100]
const CAPACITY := [11, 16, 19, 26, 30, 38, 46, 57, 65, 74]
const GUESTS := [0, 0, 1, 1, 2, 2, 3, 3, 4, 5]
const GOLD := [0, 200, 300, 900, 2100, 4500, 7500, 12500, 19000, 27000]
const DAYS := [1, 1, 2, 2, 3, 3, 4, 5, 6, 8]
const GIFTS := {5: ["throne_root"], 6: ["clock_moon"], 7: ["piano_star"], 8: ["bookshelf_floating"], 9: ["throne_crystal"], 10: ["bed_moon", "chandelier_star"]}
const UNLOCK_TIER := {"workbench": 1, "oven": 2, "loom": 3, "guest_visits": 4, "forge_bench": 5, "forecast": 6, "festival": 8, "royal_visit": 10}
const UNLOCK_STATUS := {"workbench": "real", "oven": "real", "loom": "real", "guest_visits": "real", "forge_bench": "real", "forecast": "real", "festival": "real", "royal_visit": "real"}
## twelve different backpack items (one slot each): the chest holds one slot per item, whatever the stack size
const TWELVE_IDS := ["plank_pine", "plank_birch", "plank_oak", "plank_walnut", "stone_block", "slate", "brick", "lime", "nails", "glass_pane", "roof_tile", "timber_beam", "copper_plate"]


# ---------------------------------------------------------------------------------------------------------------- stand-ins

## listens to the signals of the home so a test can read what was emitted, and plays the part of F3's listener: the furniture manager follows home_upgraded
class Rec extends RefCounted:
	var started: Array = []
	var progress: Array = []
	var upgraded: Array = []
	var events: Array = []
	var gifts: Array = []
	var toasts: Array = []
	var gained: Array = []
	var upgraded_total := 0                       # never cleared by clear(): the whole ladder
	var fm: Node = null

	func attach(bus) -> void:
		bus.home_upgrade_started.connect(_on_started)
		bus.home_upgrade_progress.connect(_on_progress)
		bus.home_upgraded.connect(_on_upgraded)
		bus.game_event.connect(_on_event)
		bus.visitor_gift.connect(_on_gift)
		bus.notification_posted.connect(_on_toast)
		bus.item_gained.connect(_on_gained)

	func detach(bus) -> void:
		if bus.home_upgrade_started.is_connected(_on_started): bus.home_upgrade_started.disconnect(_on_started)
		if bus.home_upgrade_progress.is_connected(_on_progress): bus.home_upgrade_progress.disconnect(_on_progress)
		if bus.home_upgraded.is_connected(_on_upgraded): bus.home_upgraded.disconnect(_on_upgraded)
		if bus.game_event.is_connected(_on_event): bus.game_event.disconnect(_on_event)
		if bus.visitor_gift.is_connected(_on_gift): bus.visitor_gift.disconnect(_on_gift)
		if bus.notification_posted.is_connected(_on_toast): bus.notification_posted.disconnect(_on_toast)
		if bus.item_gained.is_connected(_on_gained): bus.item_gained.disconnect(_on_gained)

	func clear() -> void:
		started.clear(); progress.clear(); upgraded.clear(); events.clear(); gifts.clear(); toasts.clear(); gained.clear()

	func events_named(event_name: String) -> Array:
		var out: Array = []
		for e in events:
			if str(e[0]) == event_name:
				out.append(e[1])
		return out

	func gained_count(item_id: String) -> int:
		var n := 0
		for g in gained:
			if str(g[0]) == item_id:
				n += int(g[1])
		return n

	func _on_started(a: int, b: int, c: int) -> void:
		started.append([a, b, c])

	func _on_progress(a: int, b: int) -> void:
		progress.append([a, b])

	func _on_upgraded(a: int, b: int) -> void:
		upgraded.append([a, b])
		upgraded_total += 1
		if fm != null and is_instance_valid(fm) and fm.has_method("set_tier"):
			fm.set_tier(b)

	func _on_event(event_name: StringName, payload: Dictionary) -> void:
		events.append([event_name, payload])

	func _on_gift(npc_id: StringName, item_id: StringName) -> void:
		gifts.append([str(npc_id), str(item_id)])

	func _on_toast(title: String, message: String, icon: String) -> void:
		toasts.append([title, message, icon])

	func _on_gained(item_id: StringName, amount: int) -> void:
		gained.append([str(item_id), amount])


## the stand-in furniture store with a hygge level that a test can pin ("this requirement is missing")
class LevelFake extends FakeFurnitureManager:
	var forced: int = -1

	func _init(p_tier: int = 1) -> void:
		super(p_tier)

	func hygge_level_index() -> int:
		return forced if forced >= 0 else super()


## The live game always has a furniture store. Model a temporarily full store
## explicitly instead of assuming that clearing a service override removes it.
class FullGiftStore extends FakeFurnitureManager:
	var full := true
	func can_add(item_id: Variant, amount: int) -> bool:
		return not full and super.can_add(item_id,amount)


## hides completed quests from HomeManager (the only QuestManager call it makes is is_completed): "this quest is not done"
class QuestProxy extends Node:
	var inner: Node = null
	var hidden: Dictionary = {}

	func is_completed(quest_id: StringName) -> bool:
		return inner.is_completed(quest_id) and not hidden.has(str(quest_id))


## the quest state of the finale for the festival waiver
class FakeQuests extends Node:
	var active := false
	var hold_done := false

	func is_completed(_quest_id: StringName) -> bool:
		return false

	func is_active(quest_id: StringName) -> bool:
		return active and str(quest_id) == "slotsdroemmen"

	func get_quest_progress(quest_id: StringName) -> Dictionary:
		if not is_active(quest_id):
			return {}
		return {"id": quest_id, "objectives": {
			"furnish_treasures": {"current": 6, "target": 6, "done": true},
			"hold_feast": {"current": 1 if hold_done else 0, "target": 1, "done": hold_done}}}


## answers like LootService.open_container(zone, container_id, uid, ctx) -> {ok, results: [{id, amount, rarity, kind}], reason} (F4's real signature) and records every call
class FakeLoot extends Node:
	var calls: Array = []
	var item := "plank_pine"
	var empty := false                 # refuses every opening (ok = false, reason cooldown)
	var empty_openings := 0            # the next openings are ok but hold nothing (reason nothing), then the find comes
	var full := false                  # refuses every opening as LootService does for a full backpack (ok = false, reason full)
	var gm: Node = null

	func open_container(zone: String, container: String, uid: String, _ctx: Dictionary = {}) -> Dictionary:
		calls.append({"zone": zone, "container": container, "uid": uid, "day": gm.total_day() if gm != null else -1})
		if empty:
			return {"ok": false, "results": [], "reason": &"cooldown"}
		if full:
			return {"ok": false, "results": [], "reason": &"full"}
		if empty_openings > 0:
			empty_openings -= 1
			return {"ok": true, "results": [], "reason": &"nothing"}
		return {"ok": true, "results": [{"id": item, "amount": 1, "rarity": "normal", "kind": "material"}], "reason": &""}


## reports the find only through the loot_rolled signal (and answers nothing): the other way LootService may deliver its result
class FakeLootSignal extends Node:
	var calls := 0

	func open_container(_zone: String, _container: String, _uid: String, _ctx: Dictionary = {}) -> void:
		calls += 1
		var bus: Node = (Engine.get_main_loop() as SceneTree).root.get_node("EventBus")
		bus.loot_rolled.emit(&"home:visit", [{"id": "stone_block", "amount": 2, "rarity": "normal", "kind": "material"}])


## the three hooks S-marriage adds to SocialManager
class FakeSocial extends Node:
	var in_home := false
	var partner_id := "baker_maja"
	var party_ids: Array = []
	var picks: Array = []
	var party_calls := 0
	var names := ["pippin_boegeknop", "fairy_lily", "merchant_pip", "smith_thorin", "farmer_rosa"]

	func partner_in_home() -> bool:
		return in_home

	func partner() -> Dictionary:
		return {"id": partner_id, "since": 1, "stage": "gift"} if in_home else {}

	func pick_visitor(week: int, i: int) -> String:
		picks.append([week, i])
		return names[(week * 3 + i) % names.size()]

	func start_house_party() -> Array:
		party_calls += 1
		return party_ids.duplicate()


# ---------------------------------------------------------------------------------------------------------------- state

var _t
var _bus: Node
var _hm: Node
var _eco: Node
var _gm: Node
var _qm: Node
var _sm: Node
var _lr: Node
var _lm: Node
var _rec: Rec
var _saved_autosave := true
var _saved_dir := ""


func run(t) -> void:
	_t = t
	_bus = t.autoload("EventBus")
	_hm = t.autoload("HomeManager")
	_eco = t.autoload("EconomyManager")
	_gm = t.autoload("GameManager")
	_qm = t.autoload("QuestManager")
	_sm = t.autoload("SaveManager")
	_lr = t.autoload("LuaRuntime")
	_lm = t.autoload("LocalizationManager")
	if _hm == null:
		t.check("autoload_registered", false, "HomeManager is not an autoload (tools/features/add_autoload.py HomeManager)")
		return
	_saved_autosave = _sm.autosave_enabled
	_sm.autosave_enabled = false
	_saved_dir = _sm.save_dir
	_sm.save_dir = OS.get_user_data_dir().path_join("home_section_saves")
	Svc.clear_overrides()
	_rec = Rec.new()
	_rec.attach(_bus)
	_load_pending_dialogues()
	_registration(t)
	_new_game(t)
	_tier_tables(t)
	_cost_scale(t)
	_perks_and_unlocks(t)
	_ladder(t)
	_flag_mirror(t)
	_absolute_days(t)
	_gifts(t)
	_chest(t)
	_atomic_transfers(t)
	_festival(t)
	_visits(t)
	await _visit_waits_when_full(t)
	await _visit_waits_with_real_loot(t)
	_guests(t)
	_save_section(t)
	_project_godot(t)
	_cleanup(t)


func _atomic_transfers(t) -> void:
	Fresh.new_game(t)
	_eco.reset()
	_eco.add_item(&"wood", 12, true)
	var totals: Array = []
	var record := func(_inventory: Dictionary) -> void:
		totals.append(_eco.count_item(&"wood") + _hm.chest_count(&"wood"))
	_bus.player_inventory_changed.connect(record)
	var deposited: int = _hm.deposit(&"wood", 7)
	var withdrawn: int = _hm.withdraw(&"wood", 3)
	var consumed: bool = _hm.consume_material(&"wood", 9)
	_bus.player_inventory_changed.disconnect(record)
	t.check("chest_transfers_commit_before_observers", deposited == 7 and withdrawn == 3 and consumed and totals == [12, 12, 3],
		"inventory listeners see the complete backpack/chest transfer: totals %s; consumption is also committed before notification" % str(totals))
	Fresh.new_game(t)
	Grant.requirements(2)
	var materials: Dictionary = _hm.material_cost(2)
	for id in materials:
		_hm.deposit(StringName(str(id)), maxi(1, floori(float(materials[id]) / 2.0)))
	var gold_before: int = _eco.gold
	var cost: int = _hm.gold_cost(2)
	var before := {}
	for id in materials:
		before[id] = _hm.count_material(id)
	var samples: Array = []
	var snapshot := func() -> void:
		var valid: bool = _hm.is_under_construction() and _gm.flag_int(&"home_building", 0) == 2 and _eco.gold == gold_before - cost
		for id in materials:
			valid = valid and _hm.count_material(id) == int(before[id]) - int(materials[id])
		samples.append(valid)
	var gold_record := func(_gold: int, _delta: int) -> void: snapshot.call()
	var inventory_record := func(_inventory: Dictionary) -> void: snapshot.call()
	_bus.gold_changed.connect(gold_record)
	_bus.player_inventory_changed.connect(inventory_record)
	_hm.chest_changed.connect(snapshot)
	var result: Dictionary = _hm.start_upgrade()
	_bus.gold_changed.disconnect(gold_record)
	_bus.player_inventory_changed.disconnect(inventory_record)
	_hm.chest_changed.disconnect(snapshot)
	t.check("construction_commits_before_observers", bool(result["ok"]) and samples.size() >= 3 and samples.all(func(valid: bool) -> bool: return valid),
		"gold, inventory and chest listeners all see the paid construction and home_building flag together (%d snapshots)" % samples.size())
	Fresh.new_game(t)
	_eco.reset()
	var chairs_before: int = _eco.count_item(&"chair_pine")
	var chests_before: int = _eco.count_item(&"chest_pine")
	_hm._pending_gifts = ["chair_pine", "chest_pine"] as Array[String]
	var gift_snapshots: Array = []
	var on_gift := func(item: StringName, _amount: int) -> void:
		gift_snapshots.append(not str(item) in _hm.pending_gifts())
		_hm._retry_pending_gifts()
	_bus.item_gained.connect(on_gift)
	_hm._retry_pending_gifts()
	_bus.item_gained.disconnect(on_gift)
	t.check("pending_gifts_safe_during_gain", gift_snapshots == [true, true] and _hm.pending_gifts().is_empty() and _eco.count_item(&"chair_pine") == chairs_before+1 and _eco.count_item(&"chest_pine") == chests_before+1,
		"saving or retrying inside item_gained never leaves a delivered gift owed or grants it twice")


func _cleanup(t) -> void:
	_rec.detach(_bus)
	Svc.clear_overrides()
	_gm.clear_config_overrides()
	_sm.autosave_enabled = _saved_autosave
	_sm.save_dir = _saved_dir
	_lr.reload_scripts()
	Fresh.new_game(t)


func _load_pending_dialogues() -> void:
	for d in PENDING_DIALOGUES:
		_lr.load_file("res://data/features/pending/lua/dialogue/%s.lua" % d)


func _days(n: int) -> void:
	for i in n:
		_gm.end_day()


func _set_date(season: StringName, day: int, year: int) -> void:
	_gm.season = season
	_gm.day = day
	_gm.year = year


## ids a test needs in the backpack: gives them silently
func _give(id: String, n: int = 1) -> bool:
	return Fresh.give(id, n)


## t.expect that also remembers the label of a failure: the named checks of the verify list are the aggregate of the lines that belong to them
func _ck(ok: bool, label: String, bag: Array[String]) -> bool:
	_t.expect(ok, label)
	if not ok:
		bag.append(label)
	return ok


func _owned(fm: Node) -> Dictionary:
	var out := {}
	for id in fm.owned_ids():
		out[str(id)] = int(fm.count_total(StringName(str(id))))
	return out


func _unmet(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		if not bool(r["met"]):
			out.append("%s:%s" % [r["kind"], r["id"]])
	return out


func _builder_line() -> String:
	var lines := LuaData.arr(_lr.get_dialogue("fairy_builder", {}).get("lines", []))
	return str(LuaData.dict(lines[0]).get("id", "")) if not lines.is_empty() else ""


func _lr_has_key(key: String) -> bool:
	return key != "" and _lm.has_key(key)


# ---------------------------------------------------------------------------------------------------------------- registration

func _registration(t) -> void:
	t.expect(_hm.get_script().resource_path == "res://scripts/home/home_manager.gd", "HomeManager is the autoload of scripts/home/home_manager.gd")
	var names: Array[String] = _sm.registered_section_names()
	t.expect(names.count("home") == 1 and _sm.has_section("home"), "SaveManager has the section `home` exactly once")
	t.expect(int(_sm.FEATURE_ORDERS["home"]) == 10 and _sm.section_names().find("home") > _sm.section_names().find("shops"), "order 10: after the built-in sections")
	t.expect(_sm.section_node("home") == _hm, "the node behind the section is HomeManager")
	t.expect(_bus.new_game_started.is_connected(_hm.reset), "reset() is wired to new_game_started by the manager itself")
	t.expect(_bus.day_started.is_connected(_hm._on_day_started), "the morning handler listens to day_started")
	t.expect(Fresh.FEATURE_NODES.has("HomeManager"), "the test helper Fresh resets HomeManager with the other feature managers")


# ---------------------------------------------------------------------------------------------------------------- a new game

func _new_game(t) -> void:
	Fresh.new_game(t)
	t.expect(_hm.tier == 1 and typeof(_hm.tier) == TYPE_INT, "a new game starts as a Skur: tier 1, a plain int")
	t.expect(not _hm.is_under_construction() and _hm.construction.is_empty() and _hm.days_left() == 0 and _hm.progress_ratio() == 0.0, "nothing under construction")
	t.expect(_hm.can_enter_home(), "the door is open")
	t.expect(_hm.tiers().size() == 10 and _hm.last_tier() == 10 and not _hm.is_max() and not _hm.castle_built(), "ten tiers are defined, tier 1 is not the end")
	t.expect(_hm.chest.is_empty() and _hm.festival_day == 0 and _hm.visit_week == -1 and _hm.pending_gifts().is_empty(), "empty chest, no festival, no visit, no pending gift")
	t.expect(_gm.flag_int(&"home_tier", 0) == 1 and typeof(_gm.get_flag(&"home_tier")) == TYPE_INT, "flag home_tier = 1 (an int)")
	t.expect(_gm.flag_int(&"home_building", -1) == 0 and _gm.flag_int(&"home_upgrade_done", -1) == 0, "flags home_building = 0 and home_upgrade_done = 0")
	t.expect(not _gm.get_flag(&"home_castle_built", false), "no castle yet")
	t.expect(_hm.requirements(1).is_empty() and _hm.requirements(0).is_empty() and _hm.requirements(11).is_empty(), "tier 1 and tiers outside 1..10 have no requirement rows")
	t.expect(_hm.tier_def(0).is_empty() and _hm.tier_def(11).is_empty() and str(_hm.tier_def(1).get("id", "")) == "skur" and str(_hm.tier_def(10).get("id", "")) == "slot", "tier_def: skur .. slot, {} outside")
	Fresh.gold(0)
	var c1: Dictionary = _hm.can_start_upgrade()
	t.expect(not bool(c1["ok"]) and c1["reason"] == "gold", "tier 2 on day one without gold: the first blocker is gold (%s)" % str(c1["reasons"]))
	t.expect("materials" in c1["reasons"] and "gate" in c1["reasons"], "every blocker is listed: gold, materials and the quest intro_lottery")
	Fresh.gold(500)
	var c2: Dictionary = _hm.can_start_upgrade()
	t.expect("gold" not in c2["reasons"] and c2["reasons"] == ["materials", "gate"], "the 500 starting acorns cover step 2 (200): materials and the quest are what is missing (%s)" % str(c2["reasons"]))
	t.expect(_hm.can_start_upgrade(3)["reason"] == "not_next" and _hm.can_start_upgrade(1)["reason"] == "not_next" and _hm.can_start_upgrade(11)["reason"] == "max", "only the next tier can be asked for")
	t.expect(not bool(_hm.start_upgrade()["ok"]) and not _hm.is_under_construction() and _eco.gold == 500, "start_upgrade with missing requirements changes nothing")
	var started_before: int = _rec.started.size()
	_hm.finish_upgrade()
	t.expect(_hm.tier == 1 and _rec.upgraded.is_empty() and _rec.started.size() == started_before, "finish_upgrade with nothing under construction does nothing")


# ---------------------------------------------------------------------------------------------------------------- the tier tables

func _tier_tables(t) -> void:
	Fresh.new_game(t)
	var total_gold := 0
	var problems: Array[String] = []
	for n in range(1, 11):
		var def: Dictionary = _hm.tier_def(n)
		var cost := LuaData.dict(def.get("cost", {}))
		t.expect(int(def.get("tier", 0)) == n and str(def.get("name_key", "")) == "HOME_TIER_%d" % n and _lr_has_key(str(def.get("name_key", ""))), "tier %d: record, name key HOME_TIER_%d translates" % [n, n])
		t.expect(_hm.gold_cost(n) == int(GOLD[n - 1]) and _hm.build_days(n) == int(DAYS[n - 1]) and (n == 1 or int(cost.get("days", 0)) == int(DAYS[n - 1])), "tier %d: %d guldagern, %d day(s)" % [n, GOLD[n - 1], DAYS[n - 1]])
		t.expect(_hm.material_cost(n) == LuaData.int_map(cost.get("materials", {})) and (n == 1 or not _hm.material_cost(n).is_empty()), "tier %d: materials %s" % [n, str(_hm.material_cost(n))])
		_hm.set_tier(n)
		t.expect(_hm.max_energy_bonus() == int(ENERGY[n - 1]) and _hm.storage_slots() == int(SLOTS[n - 1]) and _hm.furniture_capacity() == int(CAPACITY[n - 1]) and _hm.guest_visits_per_week() == int(GUESTS[n - 1]), "tier %d lives with +%d energy, %d chest slots, %d pieces, %d guest gifts a week" % [n, ENERGY[n - 1], SLOTS[n - 1], CAPACITY[n - 1], GUESTS[n - 1]])
		t.expect(int(HomeData.room(n).get("max_furniture", -1)) == _hm.furniture_capacity(), "tier %d: furniture_capacity equals max_furniture of room_t%02d.json" % [n, n])
		var art := HomeData.tier(n)
		t.expect(int(art.get("tier", 0)) == n and str(art.get("id", "")) == str(def.get("id", "x")), "tier %d: the art record of home.json is the same tier (%s)" % [n, str(art.get("id", ""))])
		total_gold += _hm.gold_cost(n)
		if _hm.gift_items(n) != (GIFTS[n] if GIFTS.has(n) else []):
			problems.append("t%d gifts %s" % [n, str(_hm.gift_items(n))])
	t.expect(total_gold == 74000, "the ten tiers cost 74,000 guldagern in total (%d)" % total_gold)
	t.expect(problems.is_empty(), "the housewarming pieces are the seven of the addendum (%s)" % str(problems))
	t.expect(HomeData.hygge_levels().size() == 6 and str(HomeData.hygge_level(2).get("id", "")) == "hyggeligt" and str(HomeData.hygge_level(3).get("id", "")) == "rigtig_hyggeligt" and str(HomeData.hygge_level(4).get("id", "")) == "eventyrligt" and HomeData.hygge_level(6).is_empty(), "requires.hygge is a LEVEL INDEX: 2 hyggeligt, 3 rigtig hyggeligt, 4 eventyrligt")
	var gates := {}
	for n in range(2, 11):
		for r in _hm.requirements(n):
			gates["%d:%s" % [n, r["kind"]]] = true
	t.expect(gates.has("2:quest") and gates.has("4:friend") and gates.has("5:quest") and gates.has("6:quest") and gates.has("7:quest") and gates.has("7:friend") and gates.has("7:hygge") and gates.has("8:quest") and gates.has("8:hygge") and gates.has("9:quest") and gates.has("9:hygge") and gates.has("10:friend") and gates.has("10:hygge"), "the gates of the addendum are rows: quests at 2, 5-9, hearts at 4, 7, 10, hygge at 7-10")
	t.expect(_hm.requirements(7).size() == 1 + 5 + 1 + 1 + 1 + 1, "tier 7: gold + 5 materials + days + quest + friend + hygge = 10 rows")
	_hm.reset()


func _cost_scale(t) -> void:
	Fresh.new_game(t)
	t.expect(HomeData.gold_cost(5) == 2100, "economy.home_cost_scale is 1.0 by default")
	_gm.set_config_override("economy.home_cost_scale", 2.0)
	t.expect(_hm.gold_cost(5) == 4200 and _hm.requirements(5)[0]["need"] == 4200, "scale 2.0: tier 5 costs 4200 and the gold row says so")
	_gm.set_config_override("economy.home_cost_scale", 0.5)
	t.expect(_hm.gold_cost(2) == 100 and _hm.gold_cost(10) == 13500, "scale 0.5: 100 and 13500")
	_gm.set_config_override("economy.home_cost_scale", 0.0)
	t.expect(_hm.gold_cost(7) == 0 and bool(_hm.requirements(7)[0]["met"]), "scale 0: the price is free")
	# the scaled price is what is paid (Grant reads the plain config, so the gold is given by hand here)
	_gm.set_config_override("economy.home_cost_scale", 3.0)
	var rep: Dictionary = Grant.requirements(2)
	t.expect(bool(rep["ok"]), "everything but the scaled gold given (%s)" % str(rep["missing"]))
	Fresh.gold(900)
	var gold0: int = _eco.gold
	var res: Dictionary = _hm.start_upgrade()
	t.expect(bool(res["ok"]) and _eco.gold == gold0 - 600, "start_upgrade at scale 3.0 takes 3 x 200 = 600 guldagern (%d -> %d)" % [gold0, _eco.gold])
	_gm.set_config_override("economy.home_cost_scale", 0.5)
	_hm.finish_upgrade()
	Fresh.gold(0)
	var poor: Dictionary = _hm.can_start_upgrade()
	t.expect(_hm.tier == 2 and poor["reason"] == "gold" and not bool(_hm.requirements(3)[0]["met"]) and int(_hm.requirements(3)[0]["need"]) == 150, "tier 3 at scale 0.5 costs 150: with 0 guldagern the gold row is unmet")
	Fresh.gold(150)
	t.expect(bool(_hm.requirements(3)[0]["met"]), "and met with exactly 150")
	_gm.clear_config_overrides()
	t.expect(_hm.gold_cost(2) == 200, "the override is gone: 200 again")
	_hm.reset()
	_eco.reset()


# ---------------------------------------------------------------------------------------------------------------- perks, stations, unlocks

func _perks_and_unlocks(t) -> void:
	Fresh.new_game(t)
	var station_open := {"snedkerbord": 1, "vaev": 3, "smedje": 5}
	var problems: Array[String] = []
	var perk_problems: Array[String] = []
	_hm.set_tier(1)
	var starting_energy := Perks.total("energy")
	for n in range(1, 11):
		_hm.set_tier(n)
		for station in station_open:
			if _hm.station_available(station) != (n >= int(station_open[station])):
				problems.append("%s at tier %d" % [station, n])
		for u in UNLOCK_TIER:
			if _hm.unlocked(u) != (n >= int(UNLOCK_TIER[u])):
				problems.append("unlock %s at tier %d" % [u, n])
		var bd: Dictionary = Perks.breakdown("energy")
		_ck(int(bd["home"]) == int(ENERGY[n - 1]) and is_equal_approx(Perks.total("energy"), minf(starting_energy+float(ENERGY[n - 1]), 60.0)), "tier %d: Perks.total(\"energy\") adds the home bonus +%d (%s)" % [n, ENERGY[n - 1], str(bd["total"])], perk_problems)
		_ck(_hm.max_energy_bonus() == int(ENERGY[n - 1]) and _hm.storage_slots() == int(SLOTS[n - 1]) and _hm.furniture_capacity() == int(CAPACITY[n - 1]) and _hm.guest_visits_per_week() == int(GUESTS[n - 1]) and _hm.perks().get("storage_slots") == SLOTS[n - 1] and _hm.perk_int(n, "storage_slots") == SLOTS[n - 1], "tier %d: the four perk numbers equal the addendum table" % n, perk_problems)
	t.check("stations_by_tier", problems.is_empty() and not _hm.station_available("nonsense") and not _hm.station_available(""), "snedkerbord <- workbench (T1), vaev <- loom (T3), smedje <- forge_bench (T5) at every tier; unknown stations are closed; %s" % str(problems.slice(0, 3)))
	t.check("perks_energy_storage_capacity", perk_problems.is_empty(), "max_energy_bonus / storage_slots / furniture_capacity / guest_visits_per_week of the ten tiers equal the addendum table, and Perks.total(\"energy\") adds the home bonus (30 at the castle)")
	_hm.set_tier(1)
	t.expect(_hm.station_available("snedkerbord") and not _hm.station_available("vaev") and not _hm.station_available("smedje"), "tier 1: only the carpenter's bench")
	_hm.set_tier(4)
	t.expect(_hm.station_available("vaev") and not _hm.station_available("smedje") and CraftingSystem.home_tier() == 4, "tier 4: the loom is open, the forge is not; CraftingSystem reads the same tier flag")
	# status of the unlocks: five real and three separately listed stubs
	var status_ok := true
	for u in UNLOCK_STATUS:
		status_ok = status_ok and _hm.unlock_status(u) == UNLOCK_STATUS[u]
	t.check("unlock_status", status_ok and _hm.unlock_status("nonsense") == "stub", "all eight listed unlocks real (%s); an unknown unlock is a stub" % str(UNLOCK_STATUS))
	var rows: Array[Dictionary] = _hm.unlock_rows()
	t.expect(rows.size() == 8 and str(rows[0]["id"]) == "workbench" and str(rows[0]["name_key"]) == "HOME_UNLOCK_WORKBENCH" and str(rows[7]["desc_key"]) == "HOME_UNLOCK_ROYAL_VISIT_DESC", "unlock_rows(): eight rows in the data's order with the loc keys of the perks card")
	var keys_ok := true
	var counts := {"real": 0, "partial": 0, "stub": 0}
	for r in rows:
		keys_ok = keys_ok and _lr_has_key(str(r["name_key"])) and _lr_has_key(str(r["desc_key"]))
		keys_ok = keys_ok and (r["unlocked"] == (_hm.tier >= int(UNLOCK_TIER[r["id"]]))) and int(r["tier"]) == int(UNLOCK_TIER[r["id"]])
		counts[r["status"]] = int(counts[r["status"]]) + 1
	t.expect(keys_ok, "every unlock row has translated name and description keys, its tier and its unlocked state (tier 4)")
	t.expect(counts == {"real": 8, "partial": 0, "stub": 0}, "eight unlocks include kitchen, forecast, visits and celebrations (%s)" % str(counts))
	_hm.reset()


# ---------------------------------------------------------------------------------------------------------------- the ladder: tier 1 to 10 through the real APIs

func _ladder(t) -> void:
	Fresh.new_game(t)
	_rec.clear()
	_rec.upgraded_total = 0
	var fake := LevelFake.new(1)
	_rec.fm = fake
	Svc.override("FurnitureManager", fake)
	var starting_energy := Perks.total("energy")
	# some real furniture so "nothing placed is lost" has something to lose: three pieces placed, two chairs and a lamp in the stock
	for id in ["bed_birch_single", "chest_pine", "table_round_pine"]:
		_give(id)
		var spot := fake.room.find_spot(id)
		if not spot.is_empty():
			fake.place_from_stock(StringName(id), spot["cell"], int(spot["rot"]))
	_give("chair_pine", 2)
	_give("floor_lamp_iron")
	var placed_start: int = fake.room.pieces.size()
	t.expect(placed_start >= 3 and fake.count_stock("chair_pine") == 2, "the stand-in furniture store holds %d placed pieces and 2 spare chairs" % placed_start)
	var block_problems: Array[String] = []
	var pay_problems: Array[String] = []
	var days_walked := 0
	var progress_expected := 0
	for n in range(2, 11):
		var tier_old := n - 1
		var rep: Dictionary = Grant.requirements(n)
		t.expect(bool(rep["ok"]), "tier %d: everything it asks for was given through the public APIs (%s)" % [n, str(rep["missing"])])
		var chk: Dictionary = _hm.can_start_upgrade()
		t.expect(bool(chk["ok"]) and chk["reason"] == "ok" and chk["reasons"].is_empty() and _unmet(chk["rows"]).is_empty(), "tier %d: with everything given the upgrade can start" % n)
		_break_each(t, n, fake, block_problems)
		# ---- pay
		var gold0: int = _eco.gold
		var mats: Dictionary = _hm.material_cost(n)
		var pack0: Dictionary = _eco.get_inventory_dict()
		var owned0 := _owned(fake)
		var day0: int = _gm.total_day()
		var days: int = _hm.build_days(n)
		_rec.clear()
		var res: Dictionary = _hm.start_upgrade()
		t.expect(bool(res["ok"]) and int(res["ready_day"]) == day0 + days, "tier %d: start_upgrade ok, ready on day %d" % [n, day0 + days])
		var pack1: Dictionary = _eco.get_inventory_dict()
		var pay_ok: bool = _eco.gold == gold0 - int(GOLD[n - 1])
		for m in mats:
			pay_ok = pay_ok and int(pack1.get(StringName(m), 0)) == int(pack0.get(StringName(m), 0)) - int(mats[m])
		for id in pack0:
			if not mats.has(str(id)):
				pay_ok = pay_ok and int(pack1.get(id, 0)) == int(pack0[id])
		_ck(pay_ok, "tier %d: exactly %d guldagern and exactly the listed materials left the backpack, nothing else" % [n, GOLD[n - 1]], pay_problems)
		t.expect(_hm.is_under_construction() and not _hm.can_enter_home() and _hm.days_left() == days and _hm.progress_ratio() == 0.0, "tier %d: the house is closed while it is built" % n)
		t.expect(_hm.construction == {"target": n, "start_day": day0, "ready_day": day0 + days} and typeof(_hm.construction["ready_day"]) == TYPE_INT, "tier %d: construction {target, start_day, ready_day} in absolute days" % n)
		t.expect(_rec.started == [[tier_old, n, day0 + days]], "tier %d: home_upgrade_started(%d, %d, %d)" % [n, tier_old, n, day0 + days])
		t.expect(_gm.flag_int(&"home_tier", 0) == tier_old and _gm.flag_int(&"home_building", 0) == n, "tier %d: flags home_tier %d, home_building %d while building" % [n, tier_old, n])
		t.expect(_builder_line() == "t%02d_building" % n, "tier %d: the REAL fairy_builder dialogue is in its 'building' branch (%s)" % [n, _builder_line()])
		var again: Dictionary = _hm.start_upgrade()
		t.expect(not bool(again["ok"]) and again["reason"] == "busy" and _hm.can_start_upgrade()["reason"] == "busy" and _eco.gold == gold0 - int(GOLD[n - 1]), "tier %d: a second upgrade is refused while building, nothing is taken twice" % n)
		# ---- build
		for k in range(1, days):
			_gm.end_day()
			days_walked += 1
			progress_expected += 1
			t.expect(_hm.tier == tier_old and _hm.days_left() == days - k and _rec.progress.back() == [days - k, days], "tier %d: morning %d of %d: still building, %d day(s) left" % [n, k, days, days - k])
			t.expect(is_equal_approx(_hm.progress_ratio(), float(k) / float(days)), "tier %d: the build is %d / %d done" % [n, k, days])
		t.expect(_rec.progress.size() == days - 1 and _rec.upgraded.is_empty(), "tier %d: one progress signal per morning before the last (%d), no upgrade yet" % [n, _rec.progress.size()])
		_gm.end_day()
		days_walked += 1
		t.expect(_hm.tier == n and typeof(_hm.tier) == TYPE_INT and not _hm.is_under_construction() and _hm.can_enter_home(), "tier %d reached after %d day(s)" % [n, days])
		t.expect(_gm.total_day() == day0 + days, "tier %d: exactly %d calendar days passed" % [n, days])
		t.expect(_rec.upgraded == [[tier_old, n]], "tier %d: home_upgraded(%d, %d) emitted once" % [n, tier_old, n])
		t.expect(_rec.events_named("home_upgraded") == [{"tier": n}], "tier %d: game_event home_upgraded {tier: %d}" % [n, n])
		t.expect(_gm.flag_int(&"home_tier", 0) == n and _gm.flag_int(&"home_building", -1) == 0 and _gm.flag_int(&"home_upgrade_done", 0) == n, "tier %d: flags home_tier %d, home_building 0, home_upgrade_done %d" % [n, n, n])
		t.expect(bool(_gm.get_flag(&"home_castle_built", false)) == (n == 10), "tier %d: home_castle_built is %s" % [n, "set" if n == 10 else "not set"])
		t.expect(_builder_line() == "t%02d_done" % n, "tier %d: the REAL fairy_builder dialogue celebrates (%s)" % [n, _builder_line()])
		_celebrate_and_check(t, n)
		t.expect(_hm.furniture_capacity() == int(CAPACITY[n - 1]) and _hm.max_energy_bonus() == int(ENERGY[n - 1]) and _hm.storage_slots() == int(SLOTS[n - 1]), "tier %d: the perks of the new tier apply" % n)
		var gifts_ok := true
		for g in GIFTS.get(n, []):
			gifts_ok = gifts_ok and _eco.count_item(StringName(g)) == 1 and fake.count_stock(g) == 1 and _rec.gained_count(g) == 1
		t.expect(gifts_ok, "tier %d: the housewarming piece(s) %s arrived once, routed to the furniture store" % [n, str(GIFTS.get(n, []))])
		var owned1 := _owned(fake)
		var lost: Array[String] = []
		for id in owned0:
			if int(owned1.get(id, 0)) < int(owned0[id]):
				lost.append(id)
		t.expect(lost.is_empty() and fake.room.pieces.size() >= placed_start, "tier %d: no piece lost (%s), %d placed" % [n, str(lost), fake.room.pieces.size()])
		var nxt: Dictionary = _hm.can_start_upgrade()
		t.expect(not bool(nxt["ok"]) and (nxt["reason"] == "max") == (n == 10), "tier %d: the next step is not free by itself (%s)" % [n, nxt["reason"]])
	t.check("block_by_each_requirement", block_problems.is_empty(), "every requirement of every tier 2..10 removed one at a time blocks the upgrade, and put back it starts: %s" % str(block_problems.slice(0, 4)))
	t.check("payment_exact", pay_problems.is_empty(), "gold times economy.home_cost_scale and the listed materials, backpack first, nothing else: %s" % str(pay_problems.slice(0, 4)))
	t.expect(_hm.tier == 10 and _hm.is_max() and _hm.castle_built() and _hm.can_start_upgrade()["reason"] == "max", "the castle is reached: no further upgrade")
	t.expect(_rec.upgraded_total == 9, "nine home_upgraded signals in total on the way from the Skur to the Slottet (%d)" % _rec.upgraded_total)
	t.expect(bool(_gm.get_flag(&"home_castle_built", false)) and _gm.flag_int(&"home_tier", 0) == 10, "flag home_castle_built is set, home_tier is 10")
	t.expect(days_walked == 1 + 2 + 2 + 3 + 3 + 4 + 5 + 6 + 8 and progress_expected == days_walked - 9, "the whole ladder took %d days (74,000 guldagern) with %d progress mornings" % [days_walked, progress_expected])
	t.expect(Perks.total("energy") == minf(starting_energy+30.0,60.0) and _hm.furniture_capacity() == 74 and _hm.storage_slots() == 100 and _hm.guest_visits_per_week() == 5, "the castle: +30 energy, 74 pieces, 100 chest slots, 5 guest gifts a week")
	t.expect(fake.room.pieces.size() >= placed_start and fake.count_total("throne_root") == 1 and fake.count_total("bed_moon") == 1 and fake.count_total("chandelier_star") == 1, "the seven housewarming pieces stand in the store, the placed pieces are still placed")
	Svc.clear_overrides()
	_rec.fm = null
	fake.free()


## removes ONE requirement at a time: the upgrade must be blocked with the right reason and exactly this row unmet; putting it back unblocks it
func _break_each(t, n: int, fake: LevelFake, problems: Array[String]) -> void:
	var proxy := QuestProxy.new()
	proxy.inner = _qm
	Svc.override("QuestManager", proxy)
	var broke := 0
	for row in _hm.requirements(n):
		if row["kind"] == "days":
			continue
		var key := "%s:%s" % [row["kind"], row["id"]]
		var undo: Callable = _break(row, proxy, fake)
		var after: Dictionary = _hm.can_start_upgrade()
		var want := "gold" if row["kind"] == "gold" else ("materials" if row["kind"] == "material" else "gate")
		var unmet := _unmet(_hm.requirements(n))
		var blocked: bool = not bool(after["ok"]) and want in after["reasons"] and after["reason"] != "ok"
		var refused: Dictionary = _hm.start_upgrade()
		_ck(blocked and unmet == [key] and not bool(refused["ok"]) and not _hm.is_under_construction(), "tier %d: only '%s' missing -> blocked (%s), start_upgrade refuses" % [n, key, str(after["reasons"])], problems)
		undo.call()
		var back: Dictionary = _hm.can_start_upgrade()
		_ck(bool(back["ok"]), "tier %d: '%s' put back -> the upgrade can start" % [n, key], problems)
		broke += 1
	_ck(broke >= 2 and bool(_hm.can_start_upgrade()["ok"]), "tier %d: %d single-requirement tests, restored" % [n, broke], problems)
	Svc.clear_overrides()
	Svc.override("FurnitureManager", fake)
	proxy.free()


## returns the Callable that puts the requirement back
func _break(row: Dictionary, proxy: QuestProxy, fake: LevelFake) -> Callable:
	match str(row["kind"]):
		"gold":
			var g: int = _eco.gold
			_eco.gold = int(row["need"]) - 1
			return func() -> void: _eco.gold = g
		"material":
			# a quest reward may have given more than the tier asks for: drop to exactly one unit short (from the backpack, else from the chest)
			var id := StringName(str(row["id"]))
			var drop: int = _hm.count_material(id) - (int(row["need"]) - 1)
			var from_pack: int = mini(drop, _eco.count_item(id))
			if from_pack > 0:
				_eco.remove_item(id, from_pack)
			var from_chest := drop - from_pack
			if from_chest > 0:
				_hm.chest[str(id)] = _hm.chest_count(id) - from_chest
			return func() -> void:
				if from_pack > 0:
					_eco.add_item(id, from_pack, true)
				if from_chest > 0:
					_hm.chest[str(id)] = _hm.chest_count(id) + from_chest
		"quest":
			proxy.hidden[str(row["id"])] = true
			return func() -> void: proxy.hidden.erase(str(row["id"]))
		"friend":
			var key := StringName("friend_%s" % row["id"])
			var old: Variant = _gm.get_flag(key, 0)
			_gm.set_flag(key, int(row["need"]) - 1)
			return func() -> void: _gm.set_flag(key, old)
		"hygge":
			fake.forced = int(row["need"]) - 1
			return func() -> void: fake.forced = -1
	return func() -> void: pass


## the builder has celebrated: the flag goes back to 0 and the dialogue is idle again (runs for every tier of the ladder)
func _celebrate_and_check(t, n: int) -> void:
	_bus.dialogue_started.emit(&"mayor_lyra", &"mayor_lyra")
	_bus.dialogue_ended.emit()
	var kept: bool = _gm.flag_int(&"home_upgrade_done", 0) == n
	_bus.dialogue_started.emit(&"fairy_builder", &"fairy_builder")
	t.expect(_gm.flag_int(&"home_upgrade_done", 0) == n, "tier %d: the flag stays while the dialogue with the builder is open" % n)
	_bus.dialogue_ended.emit()
	t.expect(kept and _gm.flag_int(&"home_upgrade_done", -1) == 0 and _builder_line() == "t%02d_idle" % n, "tier %d: talking to another citizen keeps home_upgrade_done, talking to the builder clears it (%s)" % [n, _builder_line()])


# ---------------------------------------------------------------------------------------------------------------- the flags

func _flag_mirror(t) -> void:
	Fresh.new_game(t)
	var bag: Array[String] = []
	var ok: bool = _gm.world_flags.has(&"home_tier") and typeof(_gm.get_flag(&"home_tier")) == TYPE_INT and _gm.flag_int(&"home_tier", 0) == 1
	t.check("flag_home_tier_always_set", ok, "new game: home_tier = 1 (int) although GameManager cleared every flag first")
	# upgrades
	_hm.set_tier(4)
	_ck(_gm.flag_int(&"home_tier", 0) == 4 and _gm.flag_int(&"home_building", -1) == 0, "set_tier mirrors the flag", bag)
	_hm.construction = {"target": 5, "start_day": 10, "ready_day": 13}
	_hm._sync_flags()
	_ck(_gm.flag_int(&"home_building", 0) == 5 and _gm.flag_int(&"home_tier", 0) == 4, "an upgrade under way: home_building = the target, home_tier = the tier you live in", bag)
	# a load: the flags of the game section are gone or wrong, the home section puts them right
	var section: Dictionary = _hm.to_dict()
	_gm.world_flags.clear()
	_ck(_hm.from_dict(section) and _gm.flag_int(&"home_tier", 0) == 4 and _gm.flag_int(&"home_building", 0) == 5 and _gm.flag_int(&"home_upgrade_done", -1) == 0, "load: from_dict re-mirrors home_tier 4 and home_building 5 even when the world flags were lost; home_upgrade_done is present", bag)
	_gm.set_flag(&"home_tier", 11)
	_hm.from_dict(_hm.to_dict())
	_ck(_gm.flag_int(&"home_tier", 0) == 4, "load: an unusable flag (11) is repaired from the section", bag)
	_gm.set_flag(&"home_tier", "x")
	_hm.from_dict(_hm.to_dict())
	_ck(_gm.flag_int(&"home_tier", 0) == 4 and typeof(_gm.get_flag(&"home_tier")) == TYPE_INT, "load: a text flag is repaired too", bag)
	_gm.set_flag(&"home_tier", 3.0)
	_hm.from_dict(_hm.to_dict())
	_ck(_gm.flag_int(&"home_tier", 0) == 4 and typeof(_gm.get_flag(&"home_tier")) == TYPE_INT, "load: a usable value of the game section that disagrees with the tier (3.0 for tier 4) is rewritten from the section too: the flag is a mirror (ARCH-07)", bag)
	_gm.set_flag(&"home_tier", 4)
	_gm.set_flag(&"home_building", 8)
	_gm.set_flag(&"home_castle_built", true)
	_hm.from_dict(_hm.to_dict())
	_ck(_gm.flag_int(&"home_building", -1) == 5 and not _gm.world_flags.has(&"home_castle_built"), "load: home_building and home_castle_built are derived from the section and always rewritten", bag)
	var via_json: Dictionary = SaveCodec.through_json(_hm.to_dict())
	_gm.world_flags.clear()
	_hm.from_dict(via_json)
	_ck(_gm.flag_int(&"home_tier", 0) == 4 and typeof(_gm.get_flag(&"home_tier")) == TYPE_INT, "load after a JSON round trip: the flag is an int again", bag)
	# the castle flag follows the tier both ways
	_hm.construction = {}
	_hm.set_tier(10)
	_ck(bool(_gm.get_flag(&"home_castle_built", false)), "tier 10: home_castle_built", bag)
	_hm.set_tier(9)
	_ck(not _gm.world_flags.has(&"home_castle_built"), "tier 9: no castle flag (it does not survive a lower tier)", bag)
	# reset
	_hm.construction = {"target": 10, "start_day": 1, "ready_day": 2}
	_gm.set_flag(&"home_upgrade_done", 7)
	_hm.reset()
	_ck(_hm.tier == 1 and _gm.flag_int(&"home_tier", 0) == 1 and _gm.flag_int(&"home_building", -1) == 0 and _gm.flag_int(&"home_upgrade_done", -1) == 0 and not _gm.world_flags.has(&"home_castle_built"), "reset(): tier 1 and flags home_tier = 1, home_building = 0, home_upgrade_done = 0", bag)
	# the full path: save to a slot, change everything, load
	_hm.set_tier(6)
	_ck(_sm.save_game(4), "save to slot 4", bag)
	_hm.set_tier(2)
	_gm.world_flags.clear()
	_ck(_sm.load_game(4) and _hm.tier == 6 and _gm.flag_int(&"home_tier", 0) == 6, "load slot 4: tier 6, flag home_tier 6", bag)
	_sm.delete_save(4)
	_ck(_builder_line() == "t06_idle", "the REAL builder dialogue reads home_tier 6 from the flag (%s)" % _builder_line(), bag)
	t.check("flags_mirror", bag.is_empty(), "home_tier / home_building / home_upgrade_done / home_castle_built follow reset, set_tier, start, finish and load (and every tier of the ladder above): %s" % str(bag.slice(0, 3)))
	# the flag home_upgrade_done: no dialogue with the builder, no clearing; a tier that finishes during the dialogue keeps its flag
	var dbag: Array[String] = []
	_gm.set_flag(&"home_upgrade_done", 3)
	_bus.dialogue_ended.emit()
	_ck(_gm.flag_int(&"home_upgrade_done", 0) == 3, "a dialogue_ended without a dialogue with the builder clears nothing", dbag)
	_bus.dialogue_started.emit(&"fairy_builder", &"fairy_builder")
	_gm.set_flag(&"home_upgrade_done", 4)
	_bus.dialogue_ended.emit()
	_ck(_gm.flag_int(&"home_upgrade_done", 0) == 4, "a tier that finished DURING the dialogue is celebrated at the next one", dbag)
	_bus.dialogue_started.emit(&"fairy_builder", &"fairy_builder")
	_bus.dialogue_ended.emit()
	_bus.dialogue_ended.emit()
	_ck(_gm.flag_int(&"home_upgrade_done", -1) == 0, "a dialogue with fairy_builder clears the flag; a second dialogue_ended does nothing", dbag)
	_bus.dialogue_started.emit(&"mayor_lyra", &"mayor_lyra")
	_gm.set_flag(&"home_upgrade_done", 5)
	_bus.dialogue_ended.emit()
	_ck(_gm.flag_int(&"home_upgrade_done", 0) == 5, "another citizen never clears it", dbag)
	t.check("upgrade_done_cleared_after_builder_dialogue", dbag.is_empty(), "home_upgrade_done is cleared after a dialogue with fairy_builder, never by another citizen (and the REAL dialogue goes from `done` to `idle` for every tier of the ladder above)")
	_hm.reset()


# ---------------------------------------------------------------------------------------------------------------- absolute days

func _absolute_days(t) -> void:
	var fake := LevelFake.new(1)
	_rec.fm = fake
	Svc.override("FurnitureManager", fake)
	var bag: Array[String] = []
	# one day, the second-to-last day of winter: ready on the last day of the season
	Fresh.new_game(t)
	_set_date(&"vinter", 27, 1)
	_ck(bool(Grant.requirements(2)["ok"]), "winter day 27: tier 2 given", bag)
	var td0: int = _gm.total_day()
	_ck(bool(_hm.start_upgrade()["ok"]) and int(_hm.construction["ready_day"]) == td0 + 1, "a 1-day build on day 27 of winter: ready_day is td + 1 (absolute)", bag)
	_days(1)
	_ck(_hm.tier == 2 and _gm.day == 28 and _gm.season == &"vinter", "finished on day 28 (the next morning)", bag)
	# two days across the season AND year wrap: winter 28 of year 1 -> foraar 1 of year 2
	Fresh.new_game(t)
	_hm.set_tier(2)
	fake.set_tier(2)
	_set_date(&"vinter", 28, 1)
	_ck(bool(Grant.requirements(3)["ok"]), "winter day 28: tier 3 given", bag)
	var start_total: int = _gm.total_day()
	_ck(bool(_hm.start_upgrade()["ok"]) and int(_hm.construction["ready_day"]) == start_total + 2, "a 2-day build on the last day of the year: ready_day = td + 2", bag)
	_days(1)
	_ck(_gm.season == &"foraar" and _gm.year == 2 and _hm.is_under_construction() and _hm.days_left() == 1 and _hm.tier == 2, "the season and the year wrapped: still building with 1 day left (days_left = %d)" % _hm.days_left(), bag)
	_days(1)
	_ck(_hm.tier == 3 and not _hm.is_under_construction() and _gm.total_day() == start_total + 2, "tier 3 done two days later across the year boundary", bag)
	# a build over a wrap of the season only: efteraar -> vinter, tier 5 (3 days)
	Fresh.new_game(t)
	_hm.set_tier(4)
	fake.set_tier(4)
	_set_date(&"efteraar", 27, 2)
	_ck(bool(Grant.requirements(5)["ok"]), "efteraar day 27 of year 2: tier 5 given", bag)
	var s5: int = _gm.total_day()
	_hm.start_upgrade()
	_days(2)
	_ck(_gm.season == &"vinter" and _gm.day == 1 and _hm.is_under_construction() and _hm.days_left() == 1, "season wrap: efteraar 29 is winter day 1, 1 day left", bag)
	_days(1)
	_ck(_hm.tier == 5 and _gm.total_day() == s5 + 3, "tier 5 done on winter day 2", bag)
	t.check("construction_days_absolute", bag.is_empty(), "1-day, 2-day and 3-day builds across a season wrap and a year wrap count absolute total days: %s" % str(bag.slice(0, 3)))
	# save in the middle of the construction, change everything, load, finish
	var sbag: Array[String] = []
	Fresh.new_game(t)
	_hm.set_tier(3)
	fake.set_tier(3)
	_set_date(&"sommer", 10, 1)
	_ck(bool(Grant.requirements(4)["ok"]), "tier 4 given (2 days, 2 hearts of the mayor)", sbag)
	_hm.chest = {"plank_pine": 7}
	_ck(bool(_hm.start_upgrade()["ok"]), "tier 4 started on sommer 10", sbag)
	_days(1)
	var ready: int = int(_hm.construction["ready_day"])
	var start: int = int(_hm.construction["start_day"])
	_ck(_sm.save_game(3), "mid-construction: save to slot 3", sbag)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_sm.slot_path(3)))
	var section: Dictionary = (parsed as Dictionary).get("home", {}) if parsed is Dictionary else {}
	_ck(typeof(section.get("tier")) == TYPE_FLOAT, "(control) the file holds the home section and JSON gives its numbers back as floats", sbag)
	_ck(int(section.get("v", 0)) == 1 and int(section.get("tier", 0)) == 3 and LuaData.dict(section.get("construction", {})).has("ready_day") and int(LuaData.dict(section.get("chest", {})).get("plank_pine", 0)) == 7, "the section v1 has tier 3, the construction and the chest", sbag)
	_hm.reset()
	_gm.world_flags.clear()
	_ck(_hm.tier == 1 and not _hm.is_under_construction(), "everything forgotten", sbag)
	_ck(_sm.load_game(3), "load slot 3", sbag)
	_ck(_hm.tier == 3 and typeof(_hm.tier) == TYPE_INT and _hm.is_under_construction(), "tier 3, still under construction after the load", sbag)
	_ck(typeof(_hm.construction["target"]) == TYPE_INT and typeof(_hm.construction["start_day"]) == TYPE_INT and typeof(_hm.construction["ready_day"]) == TYPE_INT and _hm.construction == {"target": 4, "start_day": start, "ready_day": ready}, "the construction came back with int fields and the same days", sbag)
	_ck(typeof(_hm.chest["plank_pine"]) == TYPE_INT and _hm.chest == {"plank_pine": 7}, "the chest came back with int amounts", sbag)
	_ck(_gm.flag_int(&"home_tier", 0) == 3 and _gm.flag_int(&"home_building", 0) == 4 and _hm.days_left() == 1, "flags home_tier 3 / home_building 4, 1 day left", sbag)
	_ck(_builder_line() == "t04_building", "the builder dialogue after the load: still building tier 4", sbag)
	var upgraded_before: int = _rec.upgraded.size()
	_days(1)
	_ck(_hm.tier == 4 and _rec.upgraded.size() == upgraded_before + 1 and _rec.upgraded.back() == [3, 4], "the next morning the tier flips exactly once: home_upgraded(3, 4)", sbag)
	_days(3)
	_ck(_hm.tier == 4 and _rec.upgraded.size() == upgraded_before + 1, "and never again", sbag)
	_sm.delete_save(3)
	t.check("save_mid_construction", sbag.is_empty(), "save in the middle of a build, load, finish on the same day, exactly once; ints after the JSON round trip: %s" % str(sbag.slice(0, 3)))
	Svc.clear_overrides()
	_rec.fm = null
	fake.free()


# ---------------------------------------------------------------------------------------------------------------- housewarming gifts

func _gifts(t) -> void:
	var fake := LevelFake.new(1)
	_rec.fm = fake
	Svc.override("FurnitureManager", fake)
	var bag: Array[String] = []
	Fresh.new_game(t)
	_hm.set_tier(4)
	fake.set_tier(4)
	_ck(bool(Grant.requirements(5)["ok"]), "tier 5 given", bag)
	_rec.clear()
	_hm.start_upgrade()
	_days(_hm.build_days(5))
	_ck(_eco.count_item(&"throne_root") == 1 and fake.count_stock("throne_root") == 1 and _rec.gained_count("throne_root") == 1, "tier 5: Rodtronen (throne_root) arrived once in the furniture store", bag)
	_hm.finish_upgrade()
	_days(2)
	_ck(_eco.count_item(&"throne_root") == 1 and _rec.gained_count("throne_root") == 1, "a second finish_upgrade() and two more mornings give nothing again", bag)
	var section: Dictionary = _hm.to_dict()
	_hm.reset()
	_hm.from_dict(SaveCodec.through_json(section))
	_ck(_eco.count_item(&"throne_root") == 1 and _rec.gained_count("throne_root") == 1 and _hm.tier == 5, "a save/load round trip does not deliver it again", bag)
	# one-of-a-kind safe: the keepsake of tier 6 is already owned (found elsewhere): no second copy, no pending gift, no error
	_give("clock_moon")
	_ck(_eco.count_item(&"clock_moon") == 1, "the player already owns the Månestanduret (clock_moon) before tier 6", bag)
	_ck(bool(Grant.requirements(6)["ok"]), "tier 6 given", bag)
	_hm.start_upgrade()
	_days(_hm.build_days(6))
	_ck(_hm.tier == 6 and _eco.count_item(&"clock_moon") == 1 and _hm.pending_gifts().is_empty(), "tier 6: the keepsake the player already owned is not given twice and is not kept as pending", bag)
	# A full furniture store defers the gift even with a full backpack; retry after space returns.
	Svc.clear_overrides()
	_rec.fm = null
	Fresh.new_game(t)
	_hm.set_tier(6)
	_hm.construction = {"target": 7, "start_day": _gm.total_day(), "ready_day": _gm.total_day() + 1}
	var full_store := FullGiftStore.new()
	Svc.override("FurnitureManager",full_store)
	_fill_backpack()
	_ck(_eco.free_slots() == 0 and not _eco.can_add_item(&"piano_star", 1), "the furniture store and backpack are full: the gift cannot be delivered", bag)
	_hm.finish_upgrade()
	_ck(_hm.tier == 7 and _hm.pending_gifts() == ["piano_star"] and _eco.count_item(&"piano_star") == 0, "tier 7 flipped anyway; the Stjerneklaveret waits as a pending gift", bag)
	_ck(_hm.to_dict().get("gifts_pending", []) == ["piano_star"], "the pending gift is saved (key gifts_pending, only present when something is pending)", bag)
	var restored: Dictionary = SaveCodec.through_json(_hm.to_dict())
	_hm.reset()
	_fill_backpack()
	_hm.from_dict(restored)
	_ck(_hm.pending_gifts() == ["piano_star"], "and it survives a save/load", bag)
	_days(1)
	_ck(_hm.pending_gifts() == ["piano_star"], "still pending while there is no room", bag)
	full_store.full = false
	_days(1)
	_ck(_hm.pending_gifts().is_empty() and _eco.count_item(&"piano_star") == 1, "room again: the next morning delivers it", bag)
	_days(1)
	_ck(_eco.count_item(&"piano_star") == 1, "and only once", bag)
	t.check("gift_items_delivered_once", bag.is_empty(), "every tier gift arrives once through EconomyManager (the furniture store), never twice, never lost; one-of-a-kind safe: %s" % str(bag.slice(0, 3)))
	_eco.reset()
	_hm.reset()
	Svc.clear_overrides()
	full_store.free()
	fake.free()


## fills the backpack: every slot taken (one building material each)
func _fill_backpack() -> void:
	for id in ItemKinds.all_ids("building_material"):
		if _eco.free_slots() <= 0:
			break
		_eco.add_item(StringName(id), 1, true)


# ---------------------------------------------------------------------------------------------------------------- the home chest

func _chest(t) -> void:
	var fake := LevelFake.new(1)
	Svc.override("FurnitureManager", fake)
	var bag: Array[String] = []
	Fresh.new_game(t)
	var changes := [0]
	var counter := func() -> void: changes[0] += 1
	_hm.chest_changed.connect(counter)
	_ck(_hm.chest_capacity() == 12 and _hm.chest_used() == 0 and _hm.chest_free_slots() == 12, "tier 1: a chest of 12 slots, empty", bag)
	_give("plank_pine", 150)
	_ck(_hm.deposit(&"plank_pine", 150) == 150 and _hm.chest_count("plank_pine") == 150 and _eco.count_item(&"plank_pine") == 0, "150 planks moved to the chest", bag)
	_ck(_hm.chest_used() == 2 and _hm.chest_free_slots() == 10, "150 planks take 2 slots of 99", bag)
	_ck(_hm.count_material("plank_pine") == 150 and _hm.chest_items() == {"plank_pine": 150}, "the builder counts the chest", bag)
	_ck(changes[0] == 1, "chest_changed fired once", bag)
	# fill up to the last slot: 10 more stacks of 99
	var moved_total := 0
	for i in 10:
		_give("stone_block", 99)
		moved_total += _hm.deposit(&"stone_block", 99)
	_ck(moved_total == 990 and _hm.chest_used() == 12 and _hm.chest_free_slots() == 0 and _hm.chest_room_for("stone_block") == 0, "10 stacks of stone fill the chest: 12 of 12 slots", bag)
	_give("stone_block", 99)
	_ck(_hm.deposit(&"stone_block", 99) == 0 and _eco.count_item(&"stone_block") == 99, "a full chest takes nothing more: the 99 stay in the backpack", bag)
	# the slack of an open stack: 150 = 99 + 51, so 48 more planks fit into the second slot
	_give("plank_pine", 60)
	_ck(_hm.chest_room_for("plank_pine") == 48 and _hm.deposit(&"plank_pine", 60) == 48 and _hm.chest_count("plank_pine") == 198 and _eco.count_item(&"plank_pine") == 12, "an open stack takes what fits (48 of 60), the rest stays in the backpack", bag)
	_ck(_hm.chest_used() == 12, "still 12 slots", bag)
	_ck(_hm.deposit(&"plank_pine", 0) == 0 and _hm.deposit(&"plank_pine", -3) == 0 and _hm.deposit(&"", 5) == 0 and _hm.deposit(&"not_an_item", 5) == 0, "amounts <= 0, no id and an unknown id move nothing", bag)
	# withdraw
	var gained_before: int = _rec.gained.size()
	_ck(_hm.withdraw(&"plank_pine", 60) == 60 and _hm.chest_count("plank_pine") == 138 and _eco.count_item(&"plank_pine") == 72, "withdraw 60 planks", bag)
	_ck(_rec.gained.size() == gained_before, "a withdrawal is silent: no item_gained (no quest counts it as a find)", bag)
	_ck(_hm.withdraw(&"plank_pine", 500) == 138 and _hm.chest_count("plank_pine") == 0 and _eco.count_item(&"plank_pine") == 210 and not _hm.chest.has("plank_pine"), "withdrawing more than the chest holds moves what is there (138) and removes the entry", bag)
	_ck(_hm.withdraw(&"nothing_here", 5) == 0 and _hm.withdraw(&"plank_pine", 0) == 0 and _hm.withdraw(&"plank_pine", -1) == 0, "nothing to withdraw", bag)
	# a full backpack limits a withdrawal
	_hm.chest = {"stone_block": 990}
	_fill_backpack()
	var room: int = _eco.backpack_room_for(&"stone_block")
	var got: int = _hm.withdraw(&"stone_block", 500)
	_ck(got == mini(500, room) and _hm.chest_count("stone_block") == 990 - got, "a withdrawal stops where the backpack is full (%d of 500, room %d)" % [got, room], bag)
	# consume: backpack first, then the chest
	Fresh.new_game(t)
	_give("lime", 5)
	_hm.chest = {"lime": 10}
	_ck(_hm.count_material("lime") == 15 and _hm.consume_material("lime", 12) and _eco.count_item(&"lime") == 0 and _hm.chest_count("lime") == 3, "consume 12 of (5 in the backpack + 10 in the chest): the backpack first, 3 stay in the chest", bag)
	_ck(not _hm.consume_material("lime", 4) and _hm.chest_count("lime") == 3 and not _hm.consume_material("lime", 0) and not _hm.consume_material("lime", -2), "all or nothing: 4 of 3 refused, nothing taken", bag)
	# furniture and clothing never go into the chest
	_give("chair_pine", 2)
	_ck(_eco.count_item(&"chair_pine") == 2 and _hm.deposit(&"chair_pine", 2) == 0 and _eco.count_item(&"chair_pine") == 2, "furniture lives in its own store: the chest refuses it", bag)
	_give("shirt_linen_cream")
	_ck(_hm.deposit(&"shirt_linen_cream", 1) == 0, "and so does clothing", bag)
	# capacity follows the tier
	Fresh.new_game(t)
	var caps_ok := true
	for n in range(1, 11):
		_hm.set_tier(n)
		caps_ok = caps_ok and _hm.chest_capacity() == int(SLOTS[n - 1]) and _hm.chest_free_slots() == int(SLOTS[n - 1])
	_ck(caps_ok, "the chest holds 12 / 18 / 24 / 30 / 40 / 50 / 60 / 72 / 84 / 100 slots at tiers 1-10", bag)
	_hm.set_tier(1)
	var last_id := ""
	for id in TWELVE_IDS:
		_give(id, 1)
		_hm.deposit(StringName(id), 1)
		last_id = id
	_ck(_hm.chest_used() == 12 and _hm.chest_count(last_id) == 0 and _eco.count_item(StringName(last_id)) == 1 and _hm.deposit(StringName(last_id), 1) == 0, "12 different items fill 12 slots whatever the stack size: the 13th (%s) stays in the backpack" % last_id, bag)
	_hm.set_tier(2)
	_ck(_hm.deposit(StringName(last_id), 1) == 1 and _hm.chest_used() == 13, "tier 2: 18 slots: room again", bag)
	# the chest pays a build: the planks are only in the chest, the backpack has none
	Fresh.new_game(t)
	_ck(bool(Grant.requirements(2)["ok"]), "tier 2 given", bag)
	var need_planks: int = int(_hm.material_cost(2)["plank_pine"])
	_hm.deposit(&"plank_pine", need_planks)
	var nails0: int = _eco.count_item(&"nails")
	_ck(_eco.count_item(&"plank_pine") == 0 and _hm.chest_count("plank_pine") == need_planks and bool(_hm.can_start_upgrade()["ok"]), "the planks are only in the chest and the upgrade can still start", bag)
	var res: Dictionary = _hm.start_upgrade()
	_ck(bool(res["ok"]) and _hm.chest_count("plank_pine") == 0 and not _hm.chest.has("plank_pine") and _eco.count_item(&"nails") == nails0 - int(_hm.material_cost(2)["nails"]), "start_upgrade took the planks from the chest and the nails from the backpack", bag)
	_hm.chest_changed.disconnect(counter)
	_ck(changes[0] >= 14, "chest_changed fired for deposits, withdrawals and payments (%d)" % changes[0], bag)
	# the chest section
	_hm.chest = {"stone_block": 120, "lime": 3}
	var back: Dictionary = SaveCodec.through_json(_hm.to_dict())
	_hm.reset()
	_hm.from_dict(back)
	_ck(_hm.chest == {"stone_block": 120, "lime": 3} and typeof(_hm.chest["stone_block"]) == TYPE_INT and _hm.chest_used() == 3, "the chest round-trips through JSON as ints (120 stone = 2 slots + 1 lime)", bag)
	t.check("chest_deposit_withdraw_capacity", bag.is_empty(), "stacks of max_stack (99), capacity = storage_slots, deposit / withdraw / pay / refusals: %s" % str(bag.slice(0, 3)))
	_eco.reset()
	_hm.reset()
	Svc.clear_overrides()
	fake.free()


# ---------------------------------------------------------------------------------------------------------------- the Fe-fest

func _festival(t) -> void:
	var bag: Array[String] = []
	Fresh.new_game(t)
	_rec.clear()
	_eco.gold = 5000
	_hm.set_tier(7)
	var r7: Dictionary = _hm.hold_festival()
	_ck(not bool(r7["ok"]) and r7["reason"] == "tier" and _eco.gold == 5000 and _hm.festival_day == 0 and _rec.events_named("festival_held").is_empty(), "tier 7: no festival (the hall comes with the Herregård): nothing paid, no event", bag)
	_hm.set_tier(8)
	_eco.gold = 499
	var poor: Dictionary = _hm.hold_festival()
	_ck(not bool(poor["ok"]) and poor["reason"] == "gold" and int(poor["cost"]) == 500 and _eco.gold == 499 and _hm.festival_day == 0, "tier 8 with 499 guldagern: 'gold', nothing paid", bag)
	_eco.gold = 5000
	var td: int = _gm.total_day()
	var held: Dictionary = _hm.hold_festival()
	_ck(bool(held["ok"]) and held["reason"] == "ok" and _eco.gold == 4500 and _hm.festival_day == td, "the festival costs 500 guldagern and is held today", bag)
	_ck(_rec.events_named("festival_held") == [{}], "game_event festival_held {} (the quest slotsdroemmen waits for it)", bag)
	_ck(_hm.festival_cooldown_left() == 28 and int(held["next_day"]) == td + 28, "once per 28 days: next on day %d" % (td + 28), bag)
	var again: Dictionary = _hm.hold_festival()
	_ck(not bool(again["ok"]) and again["reason"] == "cooldown" and int(again["next_day"]) == td + 28 and _eco.gold == 4500 and _rec.events_named("festival_held").size() == 1, "the same day again: 'cooldown', nothing paid, no second event", bag)
	Fresh.jump_to_total_day(td + 27)
	_ck(_hm.festival_cooldown_left() == 1 and _hm.hold_festival()["reason"] == "cooldown", "27 days later: one day left", bag)
	Fresh.jump_to_total_day(td + 28)
	_ck(_hm.festival_cooldown_left() == 0, "28 days later: free again", bag)
	var second: Dictionary = _hm.hold_festival()
	_ck(bool(second["ok"]) and _eco.gold == 4000 and _hm.festival_day == td + 28 and _rec.events_named("festival_held").size() == 2, "the second festival: another 500, another event", bag)
	_ck(_hm.can_hold_festival_unlock() and _hm.unlock_status("festival") == "real", "festival is a real unlock with named house guests", bag)
	# a festival never held before: no cooldown even on day 5 (festival_day 0 is "never", not "day 0")
	Fresh.new_game(t)
	_eco.gold = 1000
	_hm.set_tier(9)
	_ck(_hm.festival_cooldown_left() == 0 and bool(_hm.hold_festival()["ok"]), "the first festival is possible on day 1: festival_day 0 means never", bag)
	# the waiver of the finale
	Fresh.new_game(t)
	_rec.clear()
	_eco.gold = 5000
	_hm.set_tier(8)
	var quests := FakeQuests.new()
	Svc.override("QuestManager", quests)
	_hm.festival_day = _gm.total_day()
	_ck(not _hm.festival_waiver_active() and _hm.hold_festival()["reason"] == "cooldown", "slotsdroemmen not active: the cooldown holds", bag)
	quests.active = true
	_ck(_hm.festival_waiver_active(), "slotsdroemmen active with hold_feast open: the cooldown is waived", bag)
	var waived: Dictionary = _hm.hold_festival()
	_ck(bool(waived["ok"]) and _eco.gold == 4500 and _hm.festival_day == _gm.total_day() and _rec.events_named("festival_held").size() == 1, "a festival held at tier 8 in the middle of the cooldown completes hold_feast (it costs 500 as ever)", bag)
	quests.hold_done = true
	_ck(not _hm.festival_waiver_active() and _hm.hold_festival()["reason"] == "cooldown", "hold_feast done: the waiver is gone, the cooldown holds again", bag)
	quests.hold_done = false
	_eco.gold = 100
	_ck(_hm.festival_waiver_active() and _hm.hold_festival()["reason"] == "gold", "the waiver never waives the 500 guldagern", bag)
	t.check("festival_cooldown", bag.is_empty(), "tier >= 8, 500 guldagern, once per 28 days, the cooldown waived while slotsdroemmen needs the feast: %s" % str(bag.slice(0, 3)))
	Svc.clear_overrides()
	quests.free()
	_hm.reset()
	_eco.reset()


# ---------------------------------------------------------------------------------------------------------------- the weekly guest gifts

func _visits(t) -> void:
	var bag: Array[String] = []
	Fresh.new_game(t)
	_rec.clear()
	# the weekdays
	var expected := {0: [], 1: [3], 2: [1, 5], 3: [1, 3, 5], 4: [0, 2, 4, 6], 5: [0, 2, 3, 4, 6], 6: [0, 1, 2, 4, 5, 6], 7: [0, 1, 2, 3, 4, 5, 6], 9: [0, 1, 2, 3, 4, 5, 6]}
	var wd_ok := true
	for n in expected:
		var got: Array = HomeData.visit_weekdays(int(n))
		var distinct := {}
		for d in got:
			distinct[d] = true
		wd_ok = wd_ok and got == expected[n] and distinct.size() == got.size()
	_ck(wd_ok, "the visits of a week are spread over distinct weekdays: 1 -> Thu, 2 -> Tue+Sat, 3 -> Tue+Thu+Sat, 4 -> Mon+Wed+Fri+Sun, 5 -> Mon+Wed+Thu+Fri+Sun", bag)
	_ck(HomeData.weekday_of(1) == 0 and HomeData.weekday_of(7) == 6 and HomeData.weekday_of(8) == 0 and HomeData.weekday_of(29) == 0, "weekday_of: day 1 of every season is a Monday", bag)
	_ck(HomeData.week_of(1) == 0 and HomeData.week_of(7) == 0 and HomeData.week_of(8) == 1 and HomeData.week_of(29) == 4 and HomeData.week_of(113) == 16, "week_of counts calendar weeks from day 1", bag)
	var loot := FakeLoot.new()
	loot.gm = _gm
	Svc.override("LootService", loot)
	# tiers without guest gifts: nothing happens
	for n in [1, 2]:
		_hm.set_tier(n)
		_set_date(&"foraar", 1, 1)
		_days(28)
	_ck(loot.calls.is_empty() and _rec.gifts.is_empty() and _hm.last_visit.is_empty(), "tiers 1 and 2 have no guest gifts: 56 mornings, no roll", bag)
	# tier 5: two visits a week, four weeks
	Fresh.new_game(t)
	_rec.clear()
	loot.calls.clear()
	_hm.set_tier(5)
	_set_date(&"foraar", 1, 1)
	_days(28)
	var tds: Array = []
	var zone_ok := true
	var week_days := {}
	for c in loot.calls:
		tds.append(int(c["day"]))
		zone_ok = zone_ok and c["zone"] == "farm" and c["container"] == "trae"
		var wk: int = floori(float(int(c["day"]) - 1) / 7.0)
		week_days[wk] = (week_days.get(wk, []) as Array) + [(int(c["day"]) - 1) % 7]
	var all_distinct := true
	for wk in week_days:
		var wds: Array = week_days[wk]
		all_distinct = all_distinct and wds.size() == 2 and wds[0] != wds[1]
	_ck(loot.calls.size() == 8 and zone_ok, "tier 5 (2 a week): 8 rolls in 4 weeks, each ONE container `trae` of zone `farm` (%d)" % loot.calls.size(), bag)
	_ck(tds == [2, 6, 9, 13, 16, 20, 23, 27] and all_distinct, "on Tuesdays and Saturdays, two distinct weekdays per week (%s)" % str(tds), bag)
	var uids_expected: Array = []
	for td in tds:
		uids_expected.append("home:visit:%d:%d" % [floori(float(td - 1) / 7.0), 0 if (td - 1) % 7 == 1 else 1])
	var uids: Array = []
	for c in loot.calls:
		uids.append(c["uid"])
	_ck(uids == uids_expected, "the container uid names the week and the visit of the week: home:visit:<week>:<i> (%s ...)" % str(uids.slice(0, 2)), bag)
	_ck(_rec.gifts.size() == 8 and _rec.gifts[0] == ["", "plank_pine"], "visitor_gift fires for every visit; without a friend system the visitor is an unnamed fairy (npc \"\")", bag)
	var gift_toasts := _rec.toasts.filter(func(x): return x[0] == _lm.t("HOME_UNLOCK_GUEST_VISITS"))
	_ck(gift_toasts.size() == 8 and str(gift_toasts[0][1]).contains(_lm.t("ITEM_PLANK_PINE")) and gift_toasts[0][2] == "home", "one toast per visit, naming the item (%s)" % str(gift_toasts[0] if not gift_toasts.is_empty() else "none"), bag)
	_ck(_hm.visit_week == 3 and _hm.last_visit["ok"] and _hm.last_visit["item"] == "plank_pine", "visit_week = the week of the last visit (3), last_visit tells what happened", bag)
	# the castle: five a week
	Fresh.new_game(t)
	_rec.clear()
	loot.calls.clear()
	_hm.set_tier(10)
	_set_date(&"foraar", 1, 1)
	_days(28)
	_ck(loot.calls.size() == 20, "tier 10 (5 a week): 20 rolls in 4 weeks (%d)" % loot.calls.size(), bag)
	# tier 3 and 4: one a week, on Thursdays
	for n in [3, 4]:
		Fresh.new_game(t)
		loot.calls.clear()
		_hm.set_tier(n)
		_set_date(&"foraar", 1, 1)
		_days(28)
		var thursdays := true
		for c in loot.calls:
			thursdays = thursdays and (int(c["day"]) - 1) % 7 == 3
		_ck(loot.calls.size() == 4 and thursdays, "tier %d (1 a week): 4 rolls in 4 weeks, every Thursday" % n, bag)
	# nobody comes while the house is built
	Fresh.new_game(t)
	loot.calls.clear()
	_hm.set_tier(4)
	_hm.construction = {"target": 5, "start_day": 1, "ready_day": 30}
	_set_date(&"foraar", 1, 1)
	_days(14)
	_ck(loot.calls.is_empty() and _hm.last_visit.get("reason", "") == "building", "while the house is under construction nobody leaves a gift (%s)" % str(_hm.last_visit.get("reason", "")), bag)
	# the day is processed once
	Fresh.new_game(t)
	loot.calls.clear()
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	_ck(loot.calls.size() == 1, "Thursday (day 4): one roll", bag)
	_hm._on_day_started(_gm.day, _gm.season)
	_ck(loot.calls.size() == 1, "the same day twice rolls once", bag)
	# nothing came out of the container
	Fresh.new_game(t)
	_rec.clear()
	loot.calls.clear()
	loot.empty = true
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	_ck(loot.calls.size() == 1 and _rec.gifts.is_empty() and _hm.last_visit.get("reason", "") == "nothing_left" and _hm.last_visit.get("loot_reason", "") == "cooldown" and _hm.visit_week == -1, "a refused opening (cooldown): one call, no retry, no visitor_gift, no toast, no visit recorded, LootService's reason is kept (%s)" % str(_hm.last_visit), bag)
	loot.empty = false
	# an opening that is ok but holds nothing is opened again with a fresh uid (the real farm container is empty about 3 times in 10)
	Fresh.new_game(t)
	_rec.clear()
	loot.calls.clear()
	loot.empty_openings = 2
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	var uids_retry: Array = loot.calls.map(func(c): return c["uid"])
	_ck(uids_retry == ["home:visit:0:0", "home:visit:0:0:1", "home:visit:0:0:2"] and _rec.gifts == [["", "plank_pine"]] and _hm.visit_week == 0, "two empty openings are repeated with fresh uids, the third holds the find: ONE visitor_gift (%s)" % str(uids_retry), bag)
	Fresh.new_game(t)
	_rec.clear()
	loot.calls.clear()
	loot.empty_openings = 5
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	_ck(loot.calls.size() == 3 and _rec.gifts.is_empty() and _hm.last_visit.get("reason", "") == "nothing_left" and _hm.last_visit.get("loot_reason", "") == "nothing", "never more than three attempts: then the visit finds nothing (%d calls)" % loot.calls.size(), bag)
	loot.empty_openings = 0
	# LootService answers through the loot_rolled signal only
	var by_signal := FakeLootSignal.new()
	Svc.override("LootService", by_signal)
	Fresh.new_game(t)
	_rec.clear()
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	_ck(by_signal.calls == 1 and _rec.gifts == [["", "stone_block"]], "a LootService that reports its find through loot_rolled works as well (%s)" % str(_rec.gifts), bag)
	# no LootService (or one without open_container): honest stub
	var no_loot := Node.new()
	Svc.override("LootService", no_loot)
	Fresh.new_game(t)
	_rec.clear()
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	_ck(_rec.gifts.is_empty() and _hm.last_visit.get("reason", "") == "no_loot_service", "without a LootService there is nothing to leave: no gift, no error (%s)" % str(_hm.last_visit.get("reason", "")), bag)
	t.check("guest_visit_gift_rolls", bag.is_empty(), "per game week the tier's guest_visits_per_week visits on distinct weekdays, each = one toast + one container roll `trae` in zone `farm`, signal visitor_gift; nobody walks in: %s" % str(bag.slice(0, 3)))
	Svc.clear_overrides()
	var real_loot: Node = Svc.node("LootService")
	if real_loot == null:
		t.skip("home.guest_visit_real_loot_service: LootService (F4-loot-shops) is not installed yet: the visit is proven against a recorder with the same open_container(zone, container, uid) signature")
	else:
		_visit_with_real_loot(t)
	loot.free()
	by_signal.free()
	no_loot.free()
	_hm.reset()
	_eco.reset()


## SYS-10: a full backpack on a visit morning does not cost the week's gift: it waits at the door (named toast, saved) and arrives once there is room.
func _visit_waits_when_full(t) -> void:
	var bag: Array[String] = []
	var loot := FakeLoot.new()
	loot.gm = _gm
	Svc.override("LootService", loot)
	Fresh.new_game(t)
	_rec.clear()
	loot.full = true
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	var waiting := _rec.toasts.filter(func(x): return str(x[1]) == _lm.t("HOME_GUEST_GIFT_WAITING"))
	_ck(loot.calls.size() == 1 and _rec.gifts.is_empty() and _hm.last_visit.get("reason", "") == "full" and waiting.size() == 1, "Thursday with a full backpack: one refused opening, no gift yet, a toast that says the gift waits at the door (%s)" % str(_hm.last_visit), bag)
	_ck(_hm.to_dict().get("visits_owed", []) == [{"week": 0, "index": 0, "npc": ""}], "the waiting gift is saved (%s)" % str(_hm.to_dict().get("visits_owed", [])), bag)
	_hm.from_dict(JSON.parse_string(JSON.stringify(_hm.to_dict())))
	_eco.add_item(&"wood", 1, true)
	await t.frames(2)
	_ck(loot.calls.size() == 2 and _rec.gifts.is_empty() and _rec.toasts.filter(func(x): return str(x[1]) == _lm.t("HOME_GUEST_GIFT_WAITING")).size() == 1, "still full: the retry after an inventory change is refused quietly, the gift keeps waiting", bag)
	loot.full = false
	_eco.add_item(&"wood", 1, true)
	await t.frames(2)
	var uids: Array = loot.calls.map(func(c): return c["uid"])
	_ck(_rec.gifts == [["", "plank_pine"]] and uids[-1] == "home:visit:0:0" and _hm.last_visit.get("ok", false) and _hm.to_dict().get("visits_owed", []).is_empty(), "with room again the same visit's gift arrives once (%s)" % str(uids), bag)
	_eco.add_item(&"wood", 1, true)
	await t.frames(2)
	_ck(_rec.gifts.size() == 1, "and only once", bag)
	t.check("guest_gift_waits_when_backpack_full", bag.is_empty(), "a full backpack keeps the week's guest gift at the door until there is room: %s" % str(bag.slice(0, 3)))
	Svc.clear_overrides()
	loot.free()
	_hm.reset()


## SYS-10 with the REAL LootService: the full morning gives ONE toast (the guest's, not LootService's generic "inventory full" on top of it), and a retry that
## is refused again stays quiet. The farm's `trae` is narrowed to its backpack materials so the find cannot go to a store of its own.
func _visit_waits_with_real_loot(t) -> void:
	var ls: Node = Svc.node("LootService")
	if ls == null or not ls.has_method("set_loot_config"):
		t.skip("home.guest_gift_waits_real_loot_one_toast: LootService (F4-loot-shops) is not installed yet")
		return
	var bag: Array[String] = []
	Fresh.new_game(t)
	_eco.reset()
	var cfg: Dictionary = (ls.call("loot_cfg") as Dictionary).duplicate(true)
	var trae: Dictionary = cfg["containers"]["trae"]
	trae["kinds"] = {"material": 1}
	trae["odds"] = {"normal": 10000, "uncommon": 0, "rare": 0}
	trae["wander_bp"] = 0
	ls.call("set_loot_config", cfg)
	var finds := ["nails", "plank_pine", "straw_bundle"]
	for id in ItemKinds.all_ids("building_material") + ["wood", "stone", "moss", "iron_ore", "copper_ore", "apple", "carrot", "turnip", "honey", "milk", "egg", "wool"]:
		if _eco.free_slots() <= 0:
			break
		if not id in finds:
			_eco.add_item(StringName(id), 1, true)
	var filler := StringName(str(ItemKinds.all_ids("building_material").filter(func(id): return not id in finds)[0]))
	_rec.clear()
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	var full_title: String = _lm.t("NOTIF_INVENTORY_FULL_TITLE")
	var count_full := func() -> int: return _rec.toasts.filter(func(x): return str(x[0]) == full_title).size()
	var count_waiting := func() -> int: return _rec.toasts.filter(func(x): return str(x[1]) == _lm.t("HOME_GUEST_GIFT_WAITING")).size()
	_ck(_eco.free_slots() == 0 and _hm.last_visit.get("reason", "") == "full", "a full backpack: the real LootService refuses Thursday's visit as full (%s, %d free)" % [str(_hm.last_visit), _eco.free_slots()], bag)
	_ck(count_waiting.call() == 1 and count_full.call() == 0, "the full morning gives exactly one toast, the guest's: %d waiting, %d inventory-full" % [count_waiting.call(), count_full.call()], bag)
	_ck(_eco.add_item(filler, 1, true), "one more %s still fits its stack" % filler, bag)
	await t.frames(2)
	_ck(_hm.to_dict().get("visits_owed", []).size() == 1 and count_waiting.call() == 1 and count_full.call() == 0, "an inventory change that leaves no free slot: the gift keeps waiting, no toast", bag)
	var quiet: Dictionary = ls.call("open_container", "farm", "trae", "home:visit:0:0", {"quiet_full": true})
	_ck(str(quiet.get("reason", "")) == "full" and count_full.call() == 0, "a retry the real service refuses as full stays quiet with quiet_full (%s)" % str(quiet.get("reason", "")), bag)
	ls.call("open_container", "farm", "trae", "home:visit:0:0")
	_ck(count_full.call() == 1, "without quiet_full the same refusal posts the generic inventory-full toast (the flag is what keeps it quiet)", bag)
	_eco.remove_item(filler, _eco.count_item(filler))
	await t.frames(2)
	var gift_toasts := _rec.toasts.filter(func(x): return str(x[0]) == _lm.t("HOME_UNLOCK_GUEST_VISITS") and str(x[1]) != _lm.t("HOME_GUEST_GIFT_WAITING"))
	_ck(_rec.gifts.size() == 1 and str(_rec.gifts[0][1]) in finds and gift_toasts.size() == 1 and _hm.to_dict().get("visits_owed", []).is_empty() and count_full.call() == 1, "a free slot: the waiting gift arrives once with its own toast (%s)" % str(_rec.gifts), bag)
	t.check("guest_gift_waits_real_loot_one_toast", bag.is_empty(), "with the real LootService a full visit morning toasts once and a refused retry stays quiet: %s" % str(bag.slice(0, 3)))
	ls.call("set_loot_config", null)
	_eco.reset()
	_hm.reset()


func _visit_with_real_loot(t) -> void:
	Fresh.new_game(t)
	_rec.clear()
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	t.expect(_rec.gifts.size() == 1 and _rec.gifts[0][1] != "" and not _rec.gained.is_empty(), "the REAL LootService: Thursday's visit rolls a find, delivers it through EconomyManager and fires visitor_gift (%s)" % str(_rec.gifts))


# ---------------------------------------------------------------------------------------------------------------- guests, the party and named friends

func _guests(t) -> void:
	Fresh.new_game(t)
	_rec.clear()
	var bag: Array[String] = []
	var social := FakeSocial.new()
	var loot := FakeLoot.new()
	loot.gm = _gm
	Svc.override("LootService", loot)
	# without S-marriage: no guests, an unnamed visitor
	_ck(_hm.guests_today().is_empty() and _hm.visit_today().is_empty(), "without the S-marriage hooks: guests_today() is [] (honest stub, DT37)", bag)
	var no_hooks := Node.new()
	Svc.override("SocialManager", no_hooks)
	_ck(_hm.guests_today().is_empty() and _hm.hold_festival()["reason"] == "tier", "a SocialManager without the S-marriage hooks: still []", bag)
	_hm.set_tier(3)
	_set_date(&"foraar", 3, 1)
	_gm.end_day()
	_ck(_rec.gifts == [["", "plank_pine"]] and _hm.guests_today().is_empty(), "and the weekly gift stays anonymous: visitor_gift(\"\", plank_pine)", bag)
	# the partner at home
	Svc.override("SocialManager", social)
	_ck(_hm.guests_today().is_empty(), "the partner is not at home: []", bag)
	social.in_home = true
	var g1: Array[Dictionary] = _hm.guests_today()
	_ck(g1 == [{"npc": "baker_maja", "reason": "partner"}], "the partner at home: [{npc: baker_maja, reason: partner}]", bag)
	# named visitors: pick_visitor(week, i), hearts >= 4 decided by SocialManager, the gift carries the friend
	Fresh.new_game(t)
	_rec.clear()
	social.in_home = false
	social.picks.clear()
	loot.calls.clear()
	_hm.set_tier(5)
	_set_date(&"foraar", 1, 1)
	_gm.end_day()
	_ck(_gm.day == 2 and social.picks == [[0, 0]] and _rec.gifts == [["pippin_boegeknop", "plank_pine"]], "Tuesday of week 0: pick_visitor(0, 0) names Pippin and the gift carries him (%s)" % str(_rec.gifts), bag)
	var visit_guests: Array[Dictionary] = _hm.guests_today()
	_ck(visit_guests == [{"npc": "pippin_boegeknop", "reason": "visit"}] and _hm.visit_today()["npc"] == "pippin_boegeknop", "on the day of the visit the friend is a guest with the reason `visit`", bag)
	_days(4)
	_ck(social.picks == [[0, 0], [0, 1]] and _rec.gifts.size() == 2 and _rec.gifts[1] == ["fairy_lily", "plank_pine"], "Saturday: pick_visitor(0, 1): the next visit of the week names the next friend (%s)" % str(_rec.gifts), bag)
	_gm.end_day()
	_ck(_hm.guests_today().is_empty() and _hm.visit_today().is_empty(), "the next morning nobody is a guest any more", bag)
	_ck(_rec.toasts.size() >= 2, "a toast per visit", bag)
	t.check("visitor_gift_names_a_friend", _rec.gifts.size() == 2 and _rec.gifts[0][0] == "pippin_boegeknop" and _rec.gifts[1][0] == "fairy_lily", "with SocialManager.pick_visitor(week, i) the visitor_gift carries the friend instead of an anonymous fairy")
	# the party: tier 8 + hold_festival calls start_house_party()
	Fresh.new_game(t)
	_rec.clear()
	social.party_calls = 0
	social.party_ids = ["pippin_boegeknop", "fairy_lily", "merchant_pip", "smith_thorin", "farmer_rosa", "baker_maja", "mayor_lyra", "guard_oak"]
	_hm.set_tier(8)
	_eco.gold = 5000
	_ck(social.party_calls == 0 and _hm.guests_today().is_empty(), "no party before the festival", bag)
	var fest: Dictionary = _hm.hold_festival()
	_ck(bool(fest["ok"]) and social.party_calls == 1 and fest["guests"] == ["pippin_boegeknop", "fairy_lily", "merchant_pip", "smith_thorin", "farmer_rosa", "baker_maja"], "hold_festival() calls SocialManager.start_house_party() once and keeps at most 6 friends (%s)" % str(fest["guests"]), bag)
	var party: Array[Dictionary] = _hm.guests_today()
	_ck(party.size() == 6 and party[0] == {"npc": "pippin_boegeknop", "reason": "party"} and party[5] == {"npc": "baker_maja", "reason": "party"}, "guests_today() lists the six party guests with the reason `party`", bag)
	var refused: Dictionary = _hm.hold_festival()
	_ck(not bool(refused["ok"]) and social.party_calls == 1, "a refused festival does not start a party", bag)
	# the partner is counted once and comes first
	social.in_home = true
	social.partner_id = "farmer_rosa"
	var mixed: Array[Dictionary] = _hm.guests_today()
	_ck(mixed.size() == 6 and mixed[0] == {"npc": "farmer_rosa", "reason": "partner"} and mixed.filter(func(g): return g["npc"] == "farmer_rosa").size() == 1, "the partner is one entry, before the party guests, never twice", bag)
	var shape_ok := true
	for g in mixed:
		shape_ok = shape_ok and g.keys().size() == 2 and g.has("npc") and g.has("reason") and str(g["npc"]) != "" and str(g["reason"]) in ["partner", "party", "visit"]
	t.check("guests_today_shape", shape_ok and party.size() == 6 and g1.size() == 1 and visit_guests.size() == 1, "Array[{npc, reason: partner | party | visit}], one entry per citizen")
	# the party is saved with the day and gone the next day
	var saved: Dictionary = SaveCodec.through_json(_hm.to_dict())
	_ck(saved.has("party") and saved["party"].size() == 6 and int(saved["festival_day"]) == _gm.total_day(), "the section keeps today's party (key `party`, only on the festival day)", bag)
	social.in_home = false
	_hm.reset()
	_ck(_hm.guests_today().is_empty(), "reset(): no guests", bag)
	_hm.from_dict(saved)
	_ck(_hm.guests_today().size() == 6, "a save made on the festival day brings the party back", bag)
	_gm.end_day()
	var next_day: Array[Dictionary] = _hm.guests_today()
	_ck(next_day.filter(func(g): return g["reason"] == "party").is_empty() and not _hm.to_dict().has("party"), "the day after the festival nobody is at the party and the section no longer carries it (a visitor of the day may be at home: %s)" % str(next_day), bag)
	t.check("house_party_calls_social", social.party_calls == 1 and bag.is_empty(), "hold_festival() also calls SocialManager.start_house_party(); <= 6 friends; the partner comes first: %s" % str(bag.slice(0, 3)))
	Svc.clear_overrides()
	if not _real_social_has_marriage():
		t.skip("home.social_marriage_hooks_real: SocialManager.partner_in_home / pick_visitor / start_house_party belong to S-marriage (LATER): the hooks are proven against a stand-in, without them guests_today() is [] and the gift is anonymous")
	social.free()
	loot.free()
	no_hooks.free()
	_hm.reset()
	_eco.reset()


func _real_social_has_marriage() -> bool:
	var sm := Svc.node("SocialManager")
	return sm != null and sm.has_method("partner_in_home") and sm.has_method("pick_visitor") and sm.has_method("start_house_party")


# ---------------------------------------------------------------------------------------------------------------- the save section

func _save_section(t) -> void:
	Fresh.new_game(t)
	var d0: Dictionary = _hm.to_dict()
	t.expect(d0 == {"v": 1, "tier": 1, "construction": {}, "chest": {}, "festival_day": 0, "visit_week": -1}, "a new game saves exactly {v, tier, construction, chest, festival_day, visit_week} (%s)" % str(d0))
	_hm.tier = 6
	_hm.construction = {"target": 7, "start_day": 100, "ready_day": 104}
	_hm.chest = {"plank_oak": 12, "slate": 99}
	_hm.festival_day = 77
	_hm.visit_week = 31
	var d1: Dictionary = _hm.to_dict()
	t.expect(d1.keys().size() == 6 and not d1.has("party") and not d1.has("gifts_pending"), "the optional keys `party` and `gifts_pending` are absent when empty")
	var back: Dictionary = SaveCodec.through_json(d1)
	t.expect(typeof(back["tier"]) == TYPE_FLOAT or typeof(back["tier"]) == TYPE_INT, "(control) JSON gives numbers back as floats")
	_hm.reset()
	t.expect(_hm.from_dict(back), "from_dict accepts its own output")
	t.expect(_hm.tier == 6 and typeof(_hm.tier) == TYPE_INT and _hm.construction == {"target": 7, "start_day": 100, "ready_day": 104} and typeof(_hm.construction["start_day"]) == TYPE_INT, "tier and construction restored as ints")
	t.expect(_hm.chest == {"plank_oak": 12, "slate": 99} and typeof(_hm.chest["slate"]) == TYPE_INT and _hm.festival_day == 77 and typeof(_hm.festival_day) == TYPE_INT and _hm.visit_week == 31, "chest, festival_day and visit_week restored as ints")
	t.expect(_hm.to_dict() == d1, "to_dict() after from_dict() is the same section")
	t.expect(_hm.is_under_construction() and _gm.flag_int(&"home_building", 0) == 7, "the build under way and its flag survive the round trip")
	# damaged values are repaired, never rejected
	_hm.reset()
	_hm.from_dict({"tier": 99, "construction": {"target": 4, "start_day": 5, "ready_day": 9}, "chest": {"a": -3, "b": "x", "c": 4.0, "d": "7"}, "festival_day": -5, "visit_week": "abc", "party": ["a", "a", "b", "", "c", "d", "e", "f", "g", "h"], "gifts_pending": ["x", "x", ""]})
	t.expect(_hm.tier == 10 and not _hm.is_under_construction(), "tier 99 is clamped to 10; a construction that does not lead to tier 11 is dropped")
	t.expect(_hm.chest == {"c": 4, "d": 7} and _hm.festival_day == 0 and _hm.visit_week == -1, "chest entries that are not positive numbers, a negative festival day and a text visit week are repaired")
	t.expect(_hm.pending_gifts() == ["x"], "gifts_pending is deduplicated")
	_hm.from_dict({"tier": -4, "construction": {"target": 2, "start_day": 10, "ready_day": 3}})
	t.expect(_hm.tier == 1 and _hm.construction == {"target": 2, "start_day": 10, "ready_day": 11}, "tier -4 becomes 1; a ready_day before the start becomes start + the build days of the tier")
	_hm.from_dict({})
	t.expect(_hm.tier == 1 and _hm.chest.is_empty() and not _hm.is_under_construction(), "an empty dictionary is a fresh home")
	# a save without the section calls reset()
	Fresh.new_game(t)
	_hm.set_tier(7)
	_hm.chest = {"slate": 5}
	_hm.festival_day = 12
	var payload: Dictionary = _sm.gather_payload()
	t.expect(payload.has("home") and int(payload["home"]["tier"]) == 7, "the payload carries the section `home`")
	payload.erase("home")
	DirAccess.make_dir_recursive_absolute(_sm.save_dir)
	var f := FileAccess.open(_sm.slot_path(2), FileAccess.WRITE)
	f.store_string(JSON.stringify(payload))
	f.close()
	_hm.set_tier(9)
	_hm.chest = {"stone_block": 3}
	_gm.set_flag(&"home_upgrade_done", 5)
	var loaded: bool = _sm.load_game(2)
	_sm.delete_save(2)
	t.check("missing_section_resets", loaded and _hm.tier == 1 and _hm.chest.is_empty() and _hm.festival_day == 0 and _gm.flag_int(&"home_tier", 0) == 1 and _gm.flag_int(&"home_building", -1) == 0 and _gm.flag_int(&"home_upgrade_done", -1) == 0, "a save of a time before the feature loads with a Skur, an empty chest and the flags reset - never stale state")
	# a new game resets everything the section holds
	_hm.tier = 5
	_hm.chest = {"slate": 1}
	_hm.festival_day = 4
	_hm.construction = {"target": 6, "start_day": 1, "ready_day": 3}
	Fresh.new_game(t)
	t.expect(_hm.tier == 1 and _hm.chest.is_empty() and _hm.festival_day == 0 and _hm.construction.is_empty() and _hm.visit_week == -1, "a new game resets tier, chest, festival, construction and visits")


# ---------------------------------------------------------------------------------------------------------------- project.godot

func _project_godot(t) -> void:
	var text := FileAccess.get_file_as_string("res://project.godot")
	var lines := text.split("\n")
	var hits: Array[String] = []
	for line in lines:
		if str(line).begins_with("HomeManager="):
			hits.append(str(line))
	var names: Array[String] = []
	var in_autoload := false
	for line in lines:
		if str(line).strip_edges() == "[autoload]":
			in_autoload = true
			continue
		if in_autoload and str(line).begins_with("["):
			break
		if in_autoload and "=" in str(line):
			names.append(str(line).get_slice("=", 0))
	var order_ok: bool = names.find("HomeManager") > names.find("AnimalHusbandry") and names.find("AnimalHusbandry") == 10
	var res: Dictionary = t.run_godot_script("res://tests/tools/check_project.gd", PackedStringArray(["--text=" + ProjectSettings.globalize_path("res://project.godot")]))
	var ids: Dictionary = t.parse_tool_ids(res)
	var idem: Dictionary = t.run_tool(t.python(), PackedStringArray(["-I", ProjectSettings.globalize_path("res://tools/features/add_autoload.py"), "--dry-run", "HomeManager"]))
	t.check("project_godot_line_once", hits == ['HomeManager="*res://scripts/home/home_manager.gd"'] and order_ok and (ids["fail"] as Array).is_empty() and "p01.autoloads_base_in_order_features_after" in ids["pass"] and int(idem.get("code", -1)) == 0, "exactly one HomeManager line behind AnimalHusbandry (%s), check_project.gd accepts it (%s), add_autoload.py is a no-op (exit %s)" % [str(hits), str(ids["fail"]), str(idem.get("code"))])
