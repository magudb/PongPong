extends Node
## LootService (autoload, package F4-loot-shops): every random find and every one-time treasure goes through here.
##
## WHAT IT IS. SCHEMA section 6 verbatim on config `loot` (lua/data/loot_tables.lua) for the static areas (farm and the forest zones skovkant dybe_bregner
## svampelunden krystalgrotten; Hyggebyen has no zone, its only find is the spot `kufferten`), plus the SEAMS of the dungeon addendum (DUNGEON_V2_ADDENDUM 5.7,
## 8.7): the API with `ctx`, the two-phase rule, the delegation seam, the keepsake registry, the appraisal host and the `DungeonFloors` host.
## Results are delivered ONLY through EconomyManager.add_item (deliver()); drop rates are designed and unit-tested, not tuned by play.
##
## API (every answer {ok: bool, results: Array, reason: StringName}; results = [{id, amount, rarity, kind}]; `sold` lists the duplicates that were sold at once)
##   open_container(zone, container_id, uid, ctx := {})   dig(zone, uid, ctx := {})   node_loot(kind, uid, ctx := {})   on_enemy_defeated(kind, ctx := {})
##   on_boss_defeated(boss_id, ctx := {})                  claim_spot(spot_id, ctx := {})   spot_state(spot_id) -> open | claimed | cooldown | locked
##   appraisal_quote(rough_id) -> {band, fee}              appraise(rough_id, ctx := {}) -> {ok, gem, rarity, fee, reason}      appraisal_available() -> bool (rules AND screen exist)
##   check_friend_gifts(npc_id)   grant_set_capstone(set_id)   set_capstone_granted(set_id) -> bool
##   deliver(item_id, amount := 1) -> {ok, sold, reason}    found(item_id) -> bool    day_value()   daily_cap_reached()   set_seed(int)
## ctx = {dungeon, floor, band, zone, rng, luck, lock_ok, first_kill, ready, uid, deliver, consume, quiet_full}: `deliver` = "add" (default) or "orbs" (return the results without adding
## them: the default of on_enemy_defeated, the pickup orb's pickup calls deliver()); `consume` = {item: n} is taken in the SAME transaction (the lake key, the three rune
## shards); `quiet_full` = true leaves the "full" refusal to the caller's own toast (the guest gift that waits at the door); `ctx.odds` is ignored; `rng` is used only when it is a RandomNumberGenerator (tests); luck defaults to Perks.total("luck") clamped to 0..0.20.
##
## TWO-PHASE (every MUTATING call): PLAN (pure draws, no state change except the rng) -> FIT (every backpack-bound roll TOGETHER on a virtual pack, the consumed items
## freeing their slots) -> DELIVER -> COMMIT (opened, wanderer / boss / spot state). When anything does not fit the answer is {ok = false, reason = &"full", results = []}
## and NOTHING happened: no delivery, no pity bump, no cooldown, no consumption, and the rng is put back to where it was (a chest on a full backpack stays closed).
## Furniture and clothing have their own stores and always fit (a duplicate is SOLD at once, config loot.duplicates, whisper FIND_UI_DUPLICATE_FMT); while a store
## does not exist yet EconomyManager keeps those items in the backpack, so then they count as backpack-bound.
##
## DELEGATION SEAM (late bound, Svc.static_call, `delegate_path` = res://scripts/dungeon_loot/dungeon_loot_rules.gd, DL5, wave 5): every call whose uid starts with `dg:` (or
## ctx.dungeon) goes to the delegate when the script exists; without it the container algorithm below runs on the band's tables (and writes no opened{} entry for a `dg:` uid:
## the consumed cells live in DungeonFloors.done). Farm and Hyggebyen containers always use the algorithm below. THE CONTRACT with DL5 (the fake delegate of the tests implements it):
##   static roll_container(state, req) roll_node(state, req) roll_drop(state, req) boss_result(state, req) roll_spot(state, req) roll_appraisal(state, req) -> plan
##       state = a deep copy of the `dungeon` sub-dict {found, claimed, wander, boss, appraise, day, unique_day}; req = {kind, zone, band, container, uid, ctx, luck, day, cfg, ...}
##       plan  = {ok: bool, reason: StringName, results: [{id, amount, rarity, kind}], ...opaque fields for commit}; a plan mutates NOTHING
##   static fits(plan, pack_view) -> bool          pack_view = {free_slots, stack_room{item}, max_stack{item}, own_store{item}: true when a store takes it}
##   static commit(state, plan) -> state           the ONLY mutator: pity, misses, day value, boss state, claimed, unique_day, appraise counter
##   static appraisal_quote(cfg, rough_id) -> {band, fee}      static spot_state(state, req) -> StringName      (both optional)
## `dungeon.found {item: day}` is written by deliver() for every keepsake (rank >= unique) and never pruned; `dungeon.day {day, value, capped}` is the daily cap's record.
##
## SAVE (SaveManager section "loot", order 40, v 1): {v, rng {seed, state} (decimal STRINGS: above 2^53), opened {uid: total_day}, claimed {spot id | "npc:hearts" | "set:<id>": day},
## wanderers {zone: {found [item], misses {container: n}}}, boss {id: {kills, last_day, misses, pool_left, first_done, last_uid}}, dungeon {optional}}.
## The one-time gifts are keyed `npc:hearts` inside `claimed` (TOWNS RT19); a legacy `gifts` table is merged into it on load.
##
## HOSTING. LootService adds the child node `DungeonFloors` (D2) when its script exists and registers it as the section `dungeon` (order 45); it listens to
## game_event `open_appraisal {npc}` and, when scenes/ui/appraisal_ui.tscn exists (DL7), opens the screen GameUI loaded for it (SCREEN_ORDER `appraisal_ui`;
## another scene path or a host without get_screen gets ONE instance under the first node of group `game_ui`) and calls its open(npc);
## without the scene the event is ignored (honest stub S21).

const _Svc := preload("res://scripts/data/svc.gd")
const _Data := preload("res://scripts/data/lua_data.gd")
const _Kinds := preload("res://scripts/data/item_kinds.gd")
const _Codec := preload("res://scripts/data/save_codec.gd")
const _Perks := preload("res://scripts/data/perks.gd")
const _RarityScript := preload("res://scripts/data/rarity.gd")
const _Rules := preload("res://scripts/loot/loot_rules.gd")
const _Economy := preload("res://scripts/autoload/economy_manager.gd")     # static total_of(): sold duplicates without int64 wrap-around

const SAVE_VERSION := 1
const SECTION := "loot"
const DUNGEON_SECTION := "dungeon"
const DUNGEON_SECTION_ORDER := 45
const DUNGEON_FLOORS_PATH := "res://scripts/dungeon/floors/dungeon_floors.gd"
const DELEGATE_PATH := "res://scripts/dungeon_loot/dungeon_loot_rules.gd"
const APPRAISAL_SCENE := "res://scenes/ui/appraisal_ui.tscn"
const GAME_UI_GROUP := &"game_ui"
## ctx.deliver values
const DELIVER_ADD := "add"
const DELIVER_ORBS := "orbs"
## `dg:` = a generated dungeon floor (DungeonFloors.uid_of): consumption lives in DungeonFloors.done, never in opened{}
const DUNGEON_UID_PREFIX := "dg:"
const KEY_BACKPACK_FULL := "DEXP_BACKPACK_FULL"
const KEY_DAY_TIRED := "LOOT_DAY_TIRED"
const KEY_KEEPSAKE_FMT := "LOOT_KEEPSAKE_FOUND_FMT"

## the seeded stream of the save (seed and state are saved as decimal strings)
var rng := RandomNumberGenerator.new()
var opened: Dictionary = {}           # container uid -> total_day of the last opening (static areas only)
var claimed: Dictionary = {}          # spot id | "npc:hearts" | "set:<id>" -> total_day
var wanderers: Dictionary = {}        # zone -> {found: [item ids], misses: {container id: openings without a wanderer}}
var boss_state: Dictionary = {}       # boss id -> {kills, last_day, misses, pool_left, first_done, last_uid}
var dungeon: Dictionary = {}          # the optional sub-dict: found, claimed, wander, boss, appraise, day, unique_day (the delegate's state)

## test seams (the production values are the constants above)
var delegate_path: String = DELEGATE_PATH
var dungeon_floors_path: String = DUNGEON_FLOORS_PATH
var appraisal_scene_path: String = APPRAISAL_SCENE

## the per-save constant the daily shop rotation is mixed with: the seed of the loot stream (it never changes while the stream advances)
var world_seed: int:
	get:
		return rng.seed

var _cfg_override: Dictionary = {}
var _has_cfg_override: bool = false
var _index: Dictionary = {}
var _index_cfg: Dictionary = {}
var _dungeon_item_facts: Dictionary = {}
var _source: String = "pickup"
var _cap_told_day: int = 0
var _appraisal_ui: Node = null
var _floors_node: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	SaveManager.register_section(SECTION, self, int(SaveManager.FEATURE_ORDERS.get(SECTION, 40)))
	EventBus.reset_wave_started.connect(reset)
	EventBus.game_event.connect(_on_game_event)
	host_dungeon_floors()


## A new game: nothing found, nothing claimed, a new seed.
func reset(origin: Dictionary = {}) -> void:
	if origin.is_empty(): origin = EventBus.reset_origin()
	if not EventBus.reset_current(origin): return
	opened.clear()
	claimed.clear()
	wanderers.clear()
	boss_state.clear()
	dungeon.clear()
	_cap_told_day = 0
	rng.randomize()


## Seeds the loot stream (tests, tests/lib/features/fresh.gd): the same seed gives the same chests, and the same shop rotation.
func set_seed(value: int) -> void:
	rng.seed = value


# ================================================================================================ config

## config `loot` (lua/data/loot_tables.lua); a test may replace it with set_loot_config().
func loot_cfg() -> Dictionary:
	if _has_cfg_override:
		return _cfg_override
	return _Data.dict(_Svc.lua_config("loot", {}))


## TEST SEAM: replaces config `loot` (an empty dictionary / null restores the data).
func set_loot_config(cfg: Variant = null) -> void:
	_has_cfg_override = typeof(cfg) == TYPE_DICTIONARY and not (cfg as Dictionary).is_empty()
	_cfg_override = (cfg as Dictionary) if _has_cfg_override else {}
	invalidate_index()


func invalidate_index() -> void:
	_index.clear()
	_index_cfg = {}
	_dungeon_item_facts.clear()


func _pool_index() -> Dictionary:
	var cfg := loot_cfg()
	if _index.is_empty() or not is_same(_index_cfg, cfg):
		_index = _Rules.build_index(cfg)
		_index_cfg = cfg
	return _index


## L = clamp(Perks.total("luck"), 0, 0.20)
func luck() -> float:
	return _Rules.clamp_luck(_Perks.total(&"luck"))


func _luck_of(ctx: Dictionary) -> float:
	return _Rules.clamp_luck(_Data.num(ctx["luck"])) if ctx.has("luck") else luck()


func _today() -> int:
	return GameManager.total_day()


func _duplicates_kinds() -> Array[String]:
	var d := _Data.dict(loot_cfg().get("duplicates", {}))
	var kinds := _Data.strings(d.get("kinds", ["clothing", "furniture"]))
	return kinds


# ================================================================================================ public API: containers

## Opens a container (chest, crate, boss chest of the base algorithm): n rolls, the wanderer check, ordinary rolls, delivery. `zone` = the AREA id of the map (farm, skovkant ...)
## or the dungeon band; `container_id` = trae | jern | fe | konge | dig | noegle ...; `uid` = area id + ":" + the marker cell (UID helper: container_uid), or `dg:<day>:<floor>:<cell>`.
func open_container(zone: String, container_id: String, uid: String, ctx: Dictionary = {}) -> Dictionary:
	if _is_dungeon(uid, ctx) and _delegate_has(&"roll_container"):
		return _run_delegate(&"roll_container", &"chest", {"kind": &"container", "zone": zone, "container": container_id}, uid, ctx)
	var cc := _Rules.container_cfg(loot_cfg(), zone, container_id)
	if cc.is_empty():
		return _answer(false, [], &"unknown_container")
	return _open_base(zone, container_id, cc, uid, ctx)


## A dig spot: the container `dig` (find_chance 0.12, the farm 0.06): a miss is still a dig, the spot is spent for the day.
func dig(zone: String, uid: String, ctx: Dictionary = {}) -> Dictionary:
	if _is_dungeon(uid, ctx) and _delegate_has(&"roll_container"):
		return _run_delegate(&"roll_container", &"dig", {"kind": &"dig", "zone": zone, "container": "dig"}, uid, ctx)
	var cc := _Rules.container_cfg(loot_cfg(), zone, "dig")
	if cc.is_empty():
		return _answer(false, [], &"unknown_container")
	return _open_base(zone, "dig", cc, uid, ctx)


## A resource node (crystal, ore, plant) of the dungeon: only the delegate knows the yields (dungeon_loot.node_yields); without it {ok = false, reason = &"no_rules"}.
func node_loot(kind: String, uid: String, ctx: Dictionary = {}) -> Dictionary:
	if _delegate_has(&"roll_node"):
		var c := ctx.duplicate()
		if not c.has("deliver"):
			c["deliver"] = DELIVER_ADD
		return _run_delegate(&"roll_node", &"node", {"kind": &"node", "node_kind": kind}, uid, c)
	return _answer(false, [], &"no_rules")


## A creature kill: one roll of loot.creatures.<kind>. The results are RETURNED (ctx.deliver = "orbs" is the default): the caller spawns one pickup orb per row and the
## pickup calls deliver(). Pass ctx.deliver = "add" to put the find into the backpack at once.
func on_enemy_defeated(kind: String, ctx: Dictionary = {}) -> Dictionary:
	var c := ctx.duplicate()
	if not c.has("deliver"):
		c["deliver"] = DELIVER_ORBS
	var uid := str(c.get("uid", ""))
	if _is_dungeon(uid, c) and _delegate_has(&"roll_drop"):
		return _run_delegate(&"roll_drop", &"creature", {"kind": &"drop", "creature": kind}, uid, c)
	var cc := _Data.dict(_Data.dict(loot_cfg().get("creatures", {})).get(kind, {}))
	if cc.is_empty():
		return _answer(false, [], &"unknown_creature")
	var zone := _zone_for_creature(kind, c)
	var r := _stream(c)
	var before := r.state
	var rows: Array = []
	var row := _Rules.roll_ordinary(_pool_index(), zone, cc, _luck_of(c), r)
	if not row.is_empty():
		rows.append(_typed_row(row))
	return _finish(StringName("creature:%s" % kind), {"ok": true, "results": rows, "delta": {}}, c, r, before)


# ================================================================================================ public API: bosses

## A boss kill (idempotent per ctx.uid: the kill and the opening of the sealed chest may both ask). The first kill is the quest reward (the quest pays; first_kill_items,
## when the table lists any, are delivered); a repeat kill, once per respawn_days (7), pays a `konge` chest and rolls the legendary pool (legendary_bp, pity_kills, an exhausted
## pool pays exhausted_item x exhausted_amount). The boss table is keyed by boss id.
func on_boss_defeated(boss_id: String, ctx: Dictionary = {}) -> Dictionary:
	var uid := str(ctx.get("uid", ""))
	if _is_dungeon(uid, ctx) and _delegate_has(&"boss_result"):
		return _run_delegate(&"boss_result", &"boss", {"kind": &"boss", "boss": boss_id}, uid, ctx)
	var bcfg := _Data.dict(_Data.dict(loot_cfg().get("boss", {})).get(boss_id, {}))
	if bcfg.is_empty():
		return _answer(false, [], &"unknown_boss")
	var st := _boss_record(boss_id)
	if uid != "" and str(st.get("last_uid", "")) == uid:
		return _answer(true, [], &"already")                    # idempotent: the same kill / chest asked twice
	var r := _stream(ctx)
	var before := r.state
	var today := _today()
	var rows: Array = []
	var delta := {"boss": boss_id, "uid": uid}
	var first_done := bool(st.get("first_done", false))
	var kills := int(st.get("kills", 0)) + 1
	delta["kills"] = kills
	delta["last_day"] = today
	delta["first_done"] = true
	if not first_done:
		for id in _first_kill_items(bcfg):
			rows.append(_row_of_item(id, 1))
		delta["misses"] = int(st.get("misses", 0))
		delta["pool_left"] = _pool_left(bcfg, st)
		delta["first_kill"] = true
	else:
		var wait := _Data.int_of(bcfg.get("respawn_days", 7), 7)
		var due := today - int(st.get("last_day", -9999)) >= wait and bool(ctx.get("ready", true))
		if not due:
			return _answer(true, [], &"not_ready")
		var zone := str(ctx.get("band", ctx.get("zone", bcfg.get("zone", "dybe_bregner"))))
		var chest := str(bcfg.get("chest", "konge"))
		var cc := _Rules.container_cfg(loot_cfg(), zone, chest)
		var luck_now := _luck_of(ctx)
		if not cc.is_empty():
			var chest_plan := _Rules.compile(_pool_index(), zone, cc, luck_now)
			for _i in _Rules.roll_count(cc, r):
				var row := _Rules.roll_plan(chest_plan, r)
				if not row.is_empty():
					rows.append(_typed_row(row))
		var left := _pool_left(bcfg, st)
		var misses := int(st.get("misses", 0))
		if left.is_empty():
			var ex := str(bcfg.get("exhausted_item", ""))
			if ex != "":
				rows.append(_row_of_item(ex, maxi(_Data.int_of(bcfg.get("exhausted_amount", 1), 1), 1)))
		elif _Rules.boss_legendary_due(bcfg, misses, r):
			var pick := str(left[r.randi() % left.size()])
			rows.append(_row_of_item(pick, 1))
			left.erase(pick)
			misses = 0
		else:
			misses += 1
		delta["misses"] = misses
		delta["pool_left"] = left
	return _finish(StringName("boss:%s" % boss_id), {"ok": true, "results": rows, "delta": delta}, ctx, r, before)


# ================================================================================================ public API: spots, gifts, capstones

## The state of a hidden spot: open | claimed | cooldown (the unique pace of the dungeon, delegate) | locked (`requires` not met).
func spot_state(spot_id: String) -> StringName:
	var spot := _spot_def(spot_id)
	if spot.is_empty():
		return &"locked"
	if claimed.has(spot_id) or _Data.dict(dungeon.get("claimed",{})).has(spot_id) or found(str(spot.get("item",""))):
		return &"claimed"
	if not _requires_met(_Data.dict(spot.get("requires", {}))):
		return &"locked"
	if _delegate_has(&"spot_state"):
		var v: Variant = _delegate_call(&"spot_state", [dungeon.duplicate(true), {"spot": spot_id, "day": _today(), "cfg": _delegate_config()}])
		if typeof(v) == TYPE_STRING_NAME or typeof(v) == TYPE_STRING:
			return StringName(str(v))
	return &"open"


## Claims a hidden spot once: requires {quests, day_min, home_tier_min, items}, `consume` (the required items are taken), the spot's keepsake is delivered.
func claim_spot(spot_id: String, ctx: Dictionary = {}) -> Dictionary:
	var spot := _spot_def(spot_id)
	if spot.is_empty():
		return _answer(false, [], &"unknown_spot")
	var uid := str(ctx.get("uid", ""))
	if claimed.has(spot_id):
		return _answer(false, [], &"claimed")
	var req := _Data.dict(spot.get("requires", {}))
	if not _requires_met(req):
		return _answer(false, [], &"locked")
	var c := ctx.duplicate()
	var consume := _spot_consume(spot, req)
	if not consume.is_empty():
		var merged := _Data.dict(c.get("consume", {})).duplicate()
		merged.merge(consume, true)
		c["consume"] = merged
	if _is_dungeon(uid, ctx) and _delegate_has(&"roll_spot"):
		return _run_delegate(&"roll_spot", &"spot", {"kind": &"spot", "spot": spot_id}, uid, c)
	var item := str(spot.get("item", ""))
	if item == "" or (found(item) and _Kinds.is_one_of_a_kind(item)):
		return _answer(false, [], &"claimed")
	var r := _stream(c)
	var rows: Array = [_row_of_item(item, 1)]
	return _finish(StringName("spot:%s" % spot_id), {"ok": true, "results": rows, "delta": {"claimed": spot_id}}, c, r, r.state)


## The container a hidden spot stands for (spots with `container = <tier>` in a zone: the first lake chest of a band holds the band's unique gem): the id of the first
## open spot of (zone, container), "" when there is none.
func container_spot(zone: String, container_id: String) -> String:
	var spots := _Data.dict(loot_cfg().get("spots", {}))
	for sid in spots:
		var sd := _Data.dict(spots[sid])
		if str(sd.get("zone", "")) == zone and str(sd.get("container", "")) == container_id and spot_state(str(sid)) == &"open":
			return str(sid)
	return ""


## The one-time friendship gifts of loot.gifts: every row of `npc` whose hearts are reached (flag friend_<npc>) and that was not given yet, keyed `npc:hearts` in the claimed table.
## Public and idempotent: SocialManager calls it after EVERY heart gain; a second call grants nothing.
func _gift_origin() -> Dictionary:
	var id := PlayerRegistry.acting_id()
	return {"id": id, "profile": PlayerRegistry.peek_state(id), "stamp": SaveManager._save_owner_stamp()}

func _gift_current(origin: Dictionary) -> bool:
	if origin.has("interaction") and not EventBus.interaction_current(origin.interaction): return false
	return NetAuthority.can_write() and SaveManager.continuation_available(origin.profile) and PlayerRegistry.acting_id() == origin.id and PlayerRegistry.peek_state(origin.id) == origin.profile and origin.stamp == SaveManager._save_owner_stamp()

func check_friend_gifts(npc_id: String) -> Dictionary:
	var origin := _gift_origin()
	var hearts := GameManager.flag_int(StringName("friend_%s" % npc_id), 0)
	var granted: Array = []
	var sold: Array = []
	for g in _Data.arr(loot_cfg().get("gifts", [])):
		if not _gift_current(origin): break
		var gd := _Data.dict(g)
		if str(gd.get("npc", "")) != npc_id:
			continue
		var need := _Data.int_of(gd.get("hearts", 0))
		var key := "%s:%d" % [npc_id, need]
		var item := str(gd.get("item", ""))
		if hearts < need or claimed.has(key) or item == "":
			continue
		var res := _finish(StringName("gift:%s" % key), {"ok": true, "results": [_row_of_item(item, 1)], "delta": {"claimed": key}}, {}, rng, rng.state)
		if bool(res["ok"]):
			granted.append_array(res["results"])
			sold.append_array(res.get("sold", []))
	return {"ok": true, "results": granted, "reason": &"" if not granted.is_empty() else &"nothing", "sold": sold}


## The legendary capstone of a wardrobe set (loot.set_rewards), once (idempotent). WardrobeManager calls it when every other member of the set is owned.
func grant_set_capstone(set_id: String) -> Dictionary:
	var key := "set:%s" % set_id
	if claimed.has(key):
		return _answer(true, [], &"already")
	for s in _Data.arr(loot_cfg().get("set_rewards", [])):
		var sd := _Data.dict(s)
		if str(sd.get("set", "")) == set_id and str(sd.get("item", "")) != "":
			return _finish(StringName("capstone:%s" % set_id), {"ok": true, "results": [_row_of_item(str(sd["item"]), 1)], "delta": {"claimed": key}}, {}, rng, rng.state)
	return _answer(false, [], &"unknown_set")


## Was the capstone of this set granted? A one-line read of the record grant_set_capstone writes (S-gifts hides the pieces of a set whose capstone is still open).
func set_capstone_granted(set_id: String) -> bool:
	return claimed.has("set:%s" % set_id)


# ================================================================================================ public API: appraisal, registry, daily value

## The band and the fee of an unknown stone (rough_<band>): the delegate knows dungeon_loot.appraisal; without it {band: "", fee: 0}.
func appraisal_quote(rough_id: String) -> Dictionary:
	if _delegate_has(&"appraisal_quote"):
		var v: Variant = _delegate_call(&"appraisal_quote", [_delegate_config(), rough_id])
		if typeof(v) == TYPE_DICTIONARY:
			return v
	return {"band": "", "fee": 0}


## Fru Ugle's appraisal of ONE unknown stone: the fee is paid, the stone is consumed and one cut gem delivered in ONE transaction (two-phase). Only the delegate has the rules.
func appraise(rough_id: String, ctx: Dictionary = {}) -> Dictionary:
	if not _delegate_has(&"roll_appraisal"):
		return {"ok": false, "gem": "", "rarity": "", "fee": 0, "reason": &"no_rules"}
	var quote := appraisal_quote(rough_id)
	var fee := _Data.int_of(quote.get("fee", 0))
	if EconomyManager.gold < fee:
		return {"ok": false, "gem": "", "rarity": "", "fee": fee, "reason": &"no_gold"}
	var c := ctx.duplicate()
	var consume := _Data.dict(c.get("consume", {})).duplicate()
	consume[rough_id] = 1
	c["consume"] = consume
	c["fee"] = fee
	var res := {}
	# Keep item/reveal observers outside the save boundary too, not just the caller.
	EconomyManager.defer_notifications(func() -> void:
		res.merge(_run_delegate(&"roll_appraisal", &"appraisal", {"kind": &"appraisal", "rough": rough_id, "band": str(quote.get("band", "")), "fee": fee}, str(c.get("uid", "")), c))
		if bool(res["ok"]) and bool(ctx.get("save",true)): SaveManager.autosave()
	)
	var rows: Array = res.get("results", [])
	var first: Dictionary = rows[0] if not rows.is_empty() and typeof(rows[0]) == TYPE_DICTIONARY else {}
	return {"ok": bool(res["ok"]), "gem": str(first.get("id", "")), "rarity": str(first.get("rarity", "")), "fee": fee if bool(res["ok"]) else 0, "reason": res["reason"]}


## Can Fru Ugle appraise a stone right now? True only when BOTH halves exist: the rules (the delegate has roll_appraisal, DL5) and the screen (scenes/ui/appraisal_ui.tscn, DL7).
## appraise() and open_appraisal() are always there (a stub answers no_rules / does nothing), so a caller must not test has_method(): the towns' counter asks THIS to decide between
## opening the screen and whispering that the appraisal is not ready yet.
func appraisal_available() -> bool:
	return _delegate_has(&"roll_appraisal") and ResourceLoader.exists(appraisal_scene_path)


## Has this keepsake (rank >= unique) ever been delivered? The registry survives a sale, a loss and the consumption of rune shards.
func found(item_id: Variant) -> bool:
	return _Data.dict(dungeon.get("found", {})).has(str(item_id))


## The value counted against today's cap (rarity-restricted sources only; the delegate keeps the record `dungeon.day {day, value, capped}`).
func day_value() -> int:
	var d := _Data.dict(dungeon.get("day", {}))
	return _Data.int_of(d.get("value", 0)) if _Data.int_of(d.get("day", 0)) == _today() else 0


func daily_cap_reached() -> bool:
	var d := _Data.dict(dungeon.get("day", {}))
	return _Data.int_of(d.get("day", 0)) == _today() and bool(d.get("capped", false))


# ================================================================================================ read-only helpers of the marker handlers

## The hosted DungeonFloors node (null = no dungeon): the handlers ask it for uid_of / is_done_cell / mark_done_cell / band_of.
func floors() -> Node:
	return _floors_node if _floors_node != null and is_instance_valid(_floors_node) else null


## respawn_days of a container as played in a zone (1 for an unknown container)
func respawn_days_of(zone: String, container_id: String) -> int:
	var cc := _Rules.container_cfg(loot_cfg(), zone, container_id)
	return maxi(_Data.int_of(cc.get("respawn_days", 1), 1), 1) if not cc.is_empty() else 1


## Days until the container with this uid can be opened again (0 = it can be opened now). Static areas only: a `dg:` uid is never in opened{}.
func days_left(uid: String, respawn_days: int) -> int:
	if not opened.has(uid):
		return 0
	return maxi(int(opened[uid]) + respawn_days - _today(), 0)


## The row of loot.spots for a spot id ({} when unknown): zone, item, name_key, hint_key, once, requires, consume, container.
func spot_def(spot_id: String) -> Dictionary:
	return _spot_def(spot_id)


## The items a spot still lacks: [item ids] of requires.items that the player does not hold (empty = nothing missing)
func missing_items(spot_id: String) -> Array[String]:
	var out: Array[String] = []
	var items := _items_of(_Data.dict(_spot_def(spot_id).get("requires", {})).get("items", {}))
	for id in items:
		if not EconomyManager.has_item(StringName(str(id)), int(items[id])):
			out.append(str(id))
	return out


# ================================================================================================ delivery (THE one place items enter)

## Gives the player `amount` of an item through EconomyManager.add_item. A find that cannot be taken (a garment already owned, furniture at its 9th copy, a weapon copy ...:
## the kinds of loot.duplicates) is SOLD at once at its sell value (whisper FIND_UI_DUPLICATE_FMT) - nothing is lost silently. Keepsakes (rank >= unique) are written to the
## registry `dungeon.found` and announced once. {ok, sold, reason, gold}: ok = false only when the item could not enter and may not be sold (a full backpack: the pickup
## orb stays on the ground).
func deliver(item_id: Variant, amount: int = 1) -> Dictionary:
	var result := {}
	EconomyManager.defer_notifications(func() -> void: result.merge(_deliver(item_id, amount)))
	return result


## Explicit model delivery for an enclosing interaction; no fresh root adoption.
func deliver_owned(item_id: Variant, amount: int, interaction: Dictionary) -> Dictionary:
	if not EventBus.interaction_current(interaction): return {"ok":false, "reason":&"superseded", "sold":false, "gold":0}
	return PlayerRegistry.for_player(interaction.recipient.player_id, func():
		var result := {}
		EconomyManager.defer_notifications(func() -> void: result.merge(_deliver(item_id, amount, interaction)))
		return result)

func _deliver(item_id: Variant, amount: int, interaction: Dictionary = {}) -> Dictionary:
	var origin := _gift_origin()
	if not interaction.is_empty(): origin["interaction"] = interaction
	if not interaction.is_empty() and not _gift_current(origin): return {"ok":false, "reason":&"superseded", "sold":false, "gold":0}
	var id := StringName(str(item_id))
	if id == &"" or amount <= 0:
		return {"ok": false, "sold": false, "reason": &"invalid", "gold": 0}
	if EconomyManager.add_item(id, amount):
		if not _gift_current(origin):
			return {"ok": true, "sold": false, "reason": &"superseded", "gold": 0}
		_note_keepsake(id, interaction)
		return {"ok": true, "sold": false, "reason": &"", "gold": 0}
	if not _gift_current(origin):
		return {"ok": false, "sold": false, "reason": &"superseded", "gold": 0}
	var def := _Kinds.def(id)
	var no_room := _goes_to_backpack(id) and EconomyManager.backpack_room_for(id) < amount and not (_Kinds.is_one_of_a_kind(id) and EconomyManager.count_item(id) >= 1)
	if str(def.get("category", "")) in _duplicates_kinds() and not no_room:
		var unit: int = EconomyManager.sell_value(id)
		var gold := mini(_Economy.total_of(unit, amount), _Economy.MAX_GOLD)
		if gold > 0:
			EconomyManager.add_gold(gold)
		_note_keepsake(id, interaction)
		var shown := tr(str(def.get("name_key", "ITEM_%s" % str(id).to_upper())))
		_announce_after_transaction(&"whisper_requested", [tr("FIND_UI_DUPLICATE_FMT") % [shown, gold]], interaction)
		return {"ok": true, "sold": true, "reason": &"sold", "gold": gold}
	return {"ok": false, "sold": false, "reason": &"full" if no_room else &"refused", "gold": 0}


func _note_keepsake(id: StringName, interaction: Dictionary = {}) -> void:
	if not _Kinds.is_one_of_a_kind(id):
		return
	var registry := _Data.dict(dungeon.get("found", {}))
	if registry.has(str(id)):
		return
	registry[str(id)] = _today()
	dungeon["found"] = registry
	var rarity := _Kinds.rarity_of(id)
	_announce_after_transaction(&"game_event", [&"loot_keepsake_found", {"item": str(id), "rarity": str(rarity), "source": _source}], interaction)
	var shown := tr(str(_Kinds.def(id).get("name_key", "ITEM_%s" % str(id).to_upper())))
	_announce_after_transaction(&"whisper_requested", [tr(KEY_KEEPSAKE_FMT) % shown], interaction)


func _announce_after_transaction(event_name: StringName, args: Array, interaction: Dictionary = {}) -> void:
	EconomyManager.after_transaction(func() -> void:
		if interaction.is_empty() or EventBus.interaction_current(interaction): EventBus.emit_signal.callv([event_name] + args))


# ================================================================================================ the container algorithm (base)

func _open_base(zone: String, container_id: String, cc: Dictionary, uid: String, ctx: Dictionary) -> Dictionary:
	var dg := _is_dungeon(uid, ctx)
	var today := _today()
	if not dg and uid != "" and opened.has(uid):
		var wait := _Data.int_of(cc.get("respawn_days", 1), 1)
		var left := int(opened[uid]) + wait - today
		if left > 0:
			var out := _answer(false, [], &"cooldown")
			out["days_left"] = left
			return out
	var r := _stream(ctx)
	var before := r.state
	var luck_now := _luck_of(ctx)
	var cfg := loot_cfg()
	var rows: Array = []
	var delta := {"opened": "" if dg else uid}
	var rolls := _Rules.roll_count(cc, r)
	var wander_item := ""
	var wst := _Data.dict(wanderers.get(zone, {}))
	var unfound := _Rules.unfound_wanderers(cfg, zone, container_id, _Data.strings(wst.get("found", [])), _owned_or_found)
	if not unfound.is_empty() and _Data.num(cc.get("wander_bp", 0)) > 0.0:
		var misses := _Data.int_of(_Data.dict(wst.get("misses", {})).get(container_id, 0))
		if _Rules.wanderer_due(cc, luck_now, misses, r):
			wander_item = str(unfound[0]["item"])
			delta["wander_found"] = [zone, wander_item, container_id]
		else:
			delta["wander_miss"] = [zone, container_id]
	var plan := _Rules.compile(_pool_index(), zone, cc, luck_now)
	for i in rolls:
		if i == 0 and wander_item != "":
			rows.append(_row_of_item(wander_item, 1))
			continue
		var row := _Rules.roll_plan(plan, r)
		if not row.is_empty():
			rows.append(_typed_row(row))
	var source := StringName("%s:%s" % ["dig" if container_id == "dig" else "chest", container_id])
	var c := ctx.duplicate()
	if dg:
		c["dungeon"] = true                                       # a `dg:` uid is a dungeon call whatever the ctx says (the refusal whisper depends on it)
	var res := _finish(source, {"ok": true, "results": rows, "delta": delta}, c, r, before)
	if bool(res["ok"]) and rows.is_empty():
		res["reason"] = &"nothing"
	return res


## the common end of every mutating call: fit, consume, deliver, commit. plan = {ok, reason, results, delta, delegate?}
func _finish(source: StringName, plan: Dictionary, ctx: Dictionary, r: RandomNumberGenerator, rng_before: int) -> Dictionary:
	var origin := _gift_origin()
	var own_stream := r == rng
	if not bool(plan.get("ok", false)):
		_restore(r, rng_before, own_stream)
		return _answer(false, [], StringName(str(plan.get("reason", "refused"))))
	var rows: Array = plan.get("results", [])
	var consume := _consume_of(ctx)
	if not consume.is_empty() and not EconomyManager.has_items(consume):
		_restore(r, rng_before, own_stream)
		return _answer(false, [], &"missing_items")
	var fee := maxi(_Data.int_of(ctx.get("fee", 0)), 0)
	if fee > 0 and not EconomyManager.can_afford(fee):
		_restore(r, rng_before, own_stream)
		return _answer(false, [], &"no_gold")
	var orbs := str(ctx.get("deliver", DELIVER_ADD)) == DELIVER_ORBS
	if not orbs and not _fits_plan(plan, rows, consume):
		_restore(r, rng_before, own_stream)
		if not bool(ctx.get("quiet_full", false)):
			_announce_full(bool(ctx.get("dungeon", false)) or str(ctx.get("uid", "")).begins_with(DUNGEON_UID_PREFIX))
		return _answer(false, [], &"full")
	var out_rows: Array = []
	var sold: Array = []
	var refused := [false]
	var committed := [false]
	EconomyManager.defer_notifications(func() -> void:
		# has_items counts placed and worn copies, which remove_items never takes: the consumption decides, before anything is delivered (SYS-06)
		if not consume.is_empty() and not EconomyManager.remove_items(consume):
			refused[0] = true
			return
		if fee > 0:
			EconomyManager.spend_gold(fee)
		var prior := _source
		_source = str(source)
		if orbs:
			out_rows.append_array(rows.duplicate(true))
		else:
			for row in rows:
				if not _gift_current(origin): break
				var res := deliver(str(row["id"]), int(row["amount"]))
				out_rows.append(row)
				if bool(res.get("sold", false)):
					sold.append({"id": str(row["id"]), "gold": int(res.get("gold", 0))})
		_source = prior
		if not _gift_current(origin): return
		_commit(plan)
		committed[0] = true
	)
	if not _gift_current(origin):
		var superseded := _answer(committed[0], out_rows, &"superseded")
		superseded["sold"] = sold
		return superseded
	if refused[0]:
		_restore(r, rng_before, own_stream)
		return _answer(false, [], &"missing_items")
	if not orbs and not out_rows.is_empty():
		_announce_after_transaction(&"loot_rolled",[source,out_rows])
	_announce_cap()
	var surprise := _Data.dict(plan.get("surprise",{}))
	if not surprise.is_empty(): _announce_after_transaction(&"game_event",[&"dungeon_surprise",surprise.duplicate(true)])
	var answer := _answer(true, out_rows, &"")
	answer["sold"] = sold
	return answer


## The fit of a plan: the delegate's own fits(plan, pack_view) when it has one (the pack_view already has the consumed items taken out), else the virtual pack of this service
func _fits_plan(plan: Dictionary, rows: Array, consume: Dictionary) -> bool:
	if bool(plan.get("delegate", false)) and _delegate_has(&"fits"):
		var ok: Variant = _delegate_call(&"fits", [plan, _pack_view(rows, consume)])
		if typeof(ok) == TYPE_BOOL:
			return ok
	return _fits_pack(_backpack_needs(rows), consume)


func _commit(plan: Dictionary) -> void:
	if bool(plan.get("delegate", false)):
		var st: Variant = _delegate_call(&"commit", [dungeon.duplicate(true), plan])
		if typeof(st) == TYPE_DICTIONARY:
			# the registry written by deliver() during this transaction must survive a delegate that returns its own copy of the state
			var keep := _Data.dict(dungeon.get("found", {}))
			dungeon = (st as Dictionary).duplicate(true)
			if not keep.is_empty():
				var merged := _Data.dict(dungeon.get("found", {}))
				merged.merge(keep, false)
				dungeon["found"] = merged
		return
	var delta := _Data.dict(plan.get("delta", {}))
	var today := _today()
	if str(delta.get("opened", "")) != "":
		opened[str(delta["opened"])] = today
	if delta.has("claimed"):
		claimed[str(delta["claimed"])] = today
	if delta.has("wander_found"):
		var wf: Array = delta["wander_found"]
		var wst := _wander_record(str(wf[0]))
		var list: Array = wst["found"]
		list.append(str(wf[1]))
		(wst["misses"] as Dictionary)[str(wf[2])] = 0
	if delta.has("wander_miss"):
		var wm: Array = delta["wander_miss"]
		var rec := _wander_record(str(wm[0]))
		var misses_of: Dictionary = rec["misses"]
		misses_of[str(wm[1])] = int(misses_of.get(str(wm[1]), 0)) + 1
	if delta.has("boss"):
		boss_state[str(delta["boss"])] = {
			"kills": int(delta.get("kills", 0)), "last_day": int(delta.get("last_day", 0)), "misses": int(delta.get("misses", 0)),
			"pool_left": _Data.strings(delta.get("pool_left", [])), "first_done": bool(delta.get("first_done", false)), "last_uid": str(delta.get("uid", "")),
		}


## The delegate path of a mutating call: plan -> fit -> deliver -> commit through the late-bound rules.
func _run_delegate(method: StringName, source_kind: StringName, extra: Dictionary, uid: String, ctx: Dictionary) -> Dictionary:
	var c := ctx.duplicate()
	c.erase("odds")                                              # ctx.odds is ignored
	c["uid"] = uid
	if uid.begins_with(DUNGEON_UID_PREFIX): c["dungeon"] = true
	var req := {"zone": str(ctx.get("band", "")), "band": str(ctx.get("band", "")), "uid": uid, "ctx": c, "luck": _luck_of(c), "day": _today(), "cfg": _delegate_config()}
	req.merge(extra, true)
	if str(req["zone"]) == "" and extra.has("zone"):
		req["zone"] = extra["zone"]
	if str(req["band"]) == "": req["band"] = req["zone"]
	var key: Variant = uid
	var stream := str(method)
	if method == &"roll_appraisal":
		stream = "appraise:"+str(req.band)
		key = int(_Data.dict(dungeon.get("appraise",{})).get(str(req.band),0))
	req["rng"] = c.get("rng",DungeonLootRng.keyed(stream,key))
	var v: Variant = _delegate_call(method, [dungeon.duplicate(true), req])
	if typeof(v) != TYPE_DICTIONARY:
		return _answer(false, [], &"no_rules")
	var plan: Dictionary = (v as Dictionary).duplicate(true)
	plan["delegate"] = true
	plan["ok"] = bool(plan.get("ok", false))
	var typed: Array = []
	for row in _Data.arr(plan.get("results", [])):
		typed.append(_typed_row(_Data.dict(row)))
	plan["results"] = typed
	var source := StringName("%s:%s" % [source_kind, str(extra.get("container", extra.get("boss", extra.get("spot", extra.get("creature", extra.get("node_kind", ""))))))])
	return _finish(source, plan, c, _stream(c), _stream(c).state)

## Snapshot primitive item facts once per data load; the delegate never reads services.
func _delegate_config() -> Dictionary:
	if _dungeon_item_facts.is_empty():
		for id in _Kinds.all_ids():
			var def := _Kinds.def(id)
			_dungeon_item_facts[str(id)] = {"category":str(def.get("category","")),"rarity":str(def.get("rarity","normal")),"sell_price":EconomyManager.sell_value(id),"max_stack":EconomyManager.max_stack_of(id)}
	var cfg := loot_cfg().duplicate()
	cfg["_items"] = _dungeon_item_facts
	cfg["_dungeon_rules"] = _Data.dict(_Svc.lua_config("dungeon_loot",{}))
	return cfg


# ================================================================================================ delegate access

func _is_dungeon(uid: String, ctx: Dictionary) -> bool:
	return uid.begins_with(DUNGEON_UID_PREFIX) or bool(ctx.get("dungeon", false))


func _delegate_has(method: StringName) -> bool:
	if not ResourceLoader.exists(delegate_path):
		return false
	var script: Variant = load(delegate_path)
	return script is Script and (script as Script).has_method(method)


func _delegate_call(method: StringName, args: Array) -> Variant:
	return _Svc.static_call(delegate_path, method, args, null)


## what a delegate's fits() may need, with the items of `consume` already taken out: the free slots, the room left in the existing stacks and the max stack of every item of
## the plan, and whether a store (not the backpack) takes it
func _pack_view(rows: Array, consume: Dictionary = {}) -> Dictionary:
	var pack := _virtual_pack(consume)
	var room := {}
	var max_stack := {}
	var own := {}
	for row in rows:
		var id := StringName(str(row["id"]))
		var ms: int = EconomyManager.max_stack_of(id)
		max_stack[str(id)] = ms
		var r := 0
		for a in (pack["stacks"] as Dictionary).get(id, []):
			r += maxi(ms - int(a), 0)
		room[str(id)] = r
		own[str(id)] = not _goes_to_backpack(id)
	return {"free_slots": int(pack["free"]), "stack_room": room, "max_stack": max_stack, "own_store": own}


## The backpack as plain numbers after `consume` {id: amount} was taken out of it (the last stacks first, like EconomyManager): {stacks: {id: [amounts]}, free: free slots}.
func _virtual_pack(consume: Dictionary = {}) -> Dictionary:
	var stacks := {}
	var used := 0
	for slot in EconomyManager.inventory:
		(stacks.get_or_add(StringName(str(slot["id"])), []) as Array).append(int(slot["amount"]))
		used += 1
	for cid in consume:
		var left := int(consume[cid])
		var amounts: Array = stacks.get(StringName(str(cid)), [])
		var i := amounts.size() - 1
		while i >= 0 and left > 0:
			var take := mini(int(amounts[i]), left)
			amounts[i] = int(amounts[i]) - take
			left -= take
			if int(amounts[i]) <= 0:
				amounts.remove_at(i)
				used -= 1
			i -= 1
	return {"stacks": stacks, "free": EconomyManager.INVENTORY_SLOTS - used}


# ================================================================================================ fit (the virtual pack)

func _goes_to_backpack(id: StringName) -> bool:
	var kind := _Kinds.storage_of(id)
	if kind == _Kinds.WEAPON: return EconomyManager.get_node_or_null("Arsenal") == null
	if kind == _Kinds.BACKPACK:
		return true
	# furniture and clothing have their own stores; while the store does not exist EconomyManager keeps the item in the backpack
	return _Svc.node("FurnitureManager" if kind == _Kinds.FURNITURE else "WardrobeManager") == null


func _backpack_needs(rows: Array) -> Dictionary:
	var need := {}
	for row in rows:
		var id := StringName(str(row["id"]))
		if not _goes_to_backpack(id):
			continue
		if _Kinds.is_one_of_a_kind(id) and EconomyManager.count_item(id) >= 1:
			continue                                              # refused anyway: a keepsake is never taken twice
		need[id] = int(need.get(id, 0)) + int(row["amount"])
	return need


## Do all of `need` {id: amount} fit into the backpack TOGETHER (existing stacks first, then free slots) once `consume` {id: amount} has been taken out of it?
func _fits_pack(need: Dictionary, consume: Dictionary = {}) -> bool:
	if need.is_empty():
		return true
	var pack := _virtual_pack(consume)
	var stacks: Dictionary = pack["stacks"]
	var free: int = pack["free"]
	for nid in need:
		var ms: int = EconomyManager.max_stack_of(nid)
		var room := 0
		for a in stacks.get(StringName(str(nid)), []):
			room += maxi(ms - int(a), 0)
		var rest := int(need[nid]) - room
		if rest > 0:
			var slots := ceili(float(rest) / float(ms))
			if slots > free:
				return false
			free -= slots
	return true


func _announce_full(dungeon_call: bool) -> void:
	if dungeon_call and LocalizationManager.has_key(KEY_BACKPACK_FULL):
		EventBus.whisper_requested.emit(KEY_BACKPACK_FULL)
	else:
		EventBus.notification_posted.emit(tr("NOTIF_INVENTORY_FULL_TITLE"), tr("NOTIF_INVENTORY_FULL_MSG"), "inventory")


## the whisper and the event of a day that reached the cap, ONCE per day
func _announce_cap() -> void:
	if not daily_cap_reached() or _cap_told_day == _today():
		return
	_cap_told_day = _today()
	EventBus.game_event.emit(&"loot_day_capped", {"day": _today()})
	EventBus.whisper_requested.emit(KEY_DAY_TIRED)


# ================================================================================================ small helpers

func _answer(ok: bool, rows: Array, reason: StringName) -> Dictionary:
	return {"ok": ok, "results": rows, "reason": reason}


## the stream of a call: ctx.rng when a test passes a RandomNumberGenerator, else the saved stream of the save
func _stream(ctx: Dictionary) -> RandomNumberGenerator:
	var v: Variant = ctx.get("rng", null)
	return v as RandomNumberGenerator if v is RandomNumberGenerator else rng


## a refused plan changes NOTHING: the saved stream goes back to where it was
func _restore(r: RandomNumberGenerator, state_before: int, own_stream: bool) -> void:
	if own_stream:
		r.state = state_before


func _consume_of(ctx: Dictionary) -> Dictionary:
	var out := {}
	var raw := _Data.dict(ctx.get("consume", {}))
	for id in raw:
		var n := _Data.int_of(raw[id])
		if n > 0:
			out[StringName(str(id))] = n
	return out


func _typed_row(row: Dictionary) -> Dictionary:
	return {"id": str(row.get("id", "")), "amount": maxi(_Data.int_of(row.get("amount", 1), 1), 1), "rarity": str(row.get("rarity", "normal")), "kind": str(row.get("kind", ""))}


func _row_of_item(item_id: String, amount: int) -> Dictionary:
	return {"id": item_id, "amount": amount, "rarity": str(_Kinds.rarity_of(item_id)), "kind": _Rules.kind_of_item(item_id)}


## a wanderer that was found, or that the player already owns, is not offered again
func _owned_or_found(item_id: String) -> bool:
	return found(item_id) or _Kinds.owned_total(item_id) > 0


func _wander_record(zone: String) -> Dictionary:
	if not wanderers.has(zone):
		wanderers[zone] = {"found": [], "misses": {}}
	return wanderers[zone]


func _boss_record(boss_id: String) -> Dictionary:
	return _Data.dict(boss_state.get(boss_id, {}))


## the legendary pool of a boss that is still open: the table's pool minus what was found or is owned (the saved list wins once it exists)
func _pool_left(bcfg: Dictionary, st: Dictionary) -> Array:
	var out: Array = []
	var saved := st.has("pool_left")
	var source: Array = _Data.strings(st.get("pool_left", [])) if saved else _Data.strings(bcfg.get("pool", []))
	for id in source:
		if not found(id) and _Kinds.owned_total(id) == 0:
			out.append(str(id))
	return out


func _first_kill_items(bcfg: Dictionary) -> Array[String]:
	var raw: Variant = bcfg.get("first_kill_items", [])
	var out: Array[String] = []
	if typeof(raw) == TYPE_DICTIONARY:
		for id in raw:
			out.append(str(id))
	else:
		out = _Data.strings(raw)
	return out


func _spot_def(spot_id: String) -> Dictionary:
	return _Data.dict(_Data.dict(loot_cfg().get("spots", {})).get(spot_id, {}))


## `requires` of a spot: quests (all completed), day_min (total day), home_tier_min (flag home_tier), items ({id: n} or [id] all owned)
func _requires_met(req: Dictionary) -> bool:
	for q in _Data.strings(req.get("quests", [])):
		if not QuestManager.is_completed(StringName(q)):
			return false
	if _Data.int_of(req.get("day_min", 0)) > _today():
		return false
	if _Data.int_of(req.get("home_tier_min", 0)) > GameManager.flag_int(&"home_tier", 1):
		return false
	var items := _items_of(req.get("items", {}))
	for id in items:
		if not EconomyManager.has_item(StringName(str(id)), int(items[id])):
			return false
	return true


## {id: n} of a table `{id = n}` or a list `{id, id}` (n = 1)
func _items_of(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) == TYPE_DICTIONARY:
		for id in raw:
			out[str(id)] = maxi(_Data.int_of((raw as Dictionary)[id], 1), 1)
	else:
		for id in _Data.strings(raw):
			out[id] = 1
	return out


## the items a spot consumes: `consume = true` = every required item, `consume = {id = n}` / `{id}` = exactly those
func _spot_consume(spot: Dictionary, req: Dictionary) -> Dictionary:
	var c: Variant = spot.get("consume", false)
	if typeof(c) == TYPE_BOOL:
		return _items_of(req.get("items", {})) if bool(c) else {}
	return _items_of(c)


## The area a creature kill belongs to: ctx.zone / ctx.band, else the zone whose creature list names the kind (the first), else the area the player stands in.
func _zone_for_creature(kind: String, ctx: Dictionary) -> String:
	var z := str(ctx.get("zone", ctx.get("band", "")))
	if z != "":
		return z
	var world := get_tree().get_first_node_in_group("world_2d")
	if world != null and world.get("area") is Object:
		var map: Variant = (world.get("area") as Object).get("map")
		if map is Object:
			var here := str((map as Object).get("id"))
			if _Data.dict(_Data.dict(loot_cfg().get("zones", {})).get(here, {})).has("pools"):
				return here
	var zones := _Data.dict(loot_cfg().get("zones", {}))
	for zid in zones:
		if _Data.dict(_Data.dict(zones[zid]).get("creatures", {})).has(kind):
			return str(zid)
	return "skovkant"


# ================================================================================================ hosting: DungeonFloors and the appraisal screen

## Adds the child node DungeonFloors (D2) when its script exists and registers it as the section `dungeon` (order 45; FEATURE_ORDERS is not extended). Idempotent.
func host_dungeon_floors() -> bool:
	if _floors_node != null and is_instance_valid(_floors_node):
		return true
	if not ResourceLoader.exists(dungeon_floors_path):
		return false
	var script: Variant = load(dungeon_floors_path)
	if not (script is GDScript) or not (script as GDScript).can_instantiate():
		return false
	var node: Node = (script as GDScript).new()
	node.name = "DungeonFloors"
	add_child(node)
	_floors_node = node
	SaveManager.register_section(DUNGEON_SECTION, node, DUNGEON_SECTION_ORDER)
	if node.has_method("reset") and not EventBus.reset_wave_started.is_connected(Callable(node, "reset")):
		EventBus.reset_wave_started.connect(Callable(node, "reset"))
	return true


func _on_game_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"open_appraisal":
		open_appraisal(StringName(str(payload.get("npc", ""))))


## Opens Fru Ugle's appraisal screen (DL7). True when it opened. Without the scene the event is ignored (honest stub S21).
func open_appraisal(npc_id: StringName = &"") -> bool:
	if not ResourceLoader.exists(appraisal_scene_path):
		return false
	if _appraisal_ui == null or not is_instance_valid(_appraisal_ui) or _appraisal_ui.is_queued_for_deletion():
		var host := get_tree().get_first_node_in_group(GAME_UI_GROUP)
		if host == null:
			return false
		# GameUI loads the real screen at its place in SCREEN_ORDER (below the pause menu); only another scene (a test fixture)
		# or a host without that registry gets an instance of its own.
		_appraisal_ui = host.call("get_screen", &"appraisal_ui") if appraisal_scene_path == APPRAISAL_SCENE and host.has_method("get_screen") else null
		if _appraisal_ui == null:
			var scene: Variant = load(appraisal_scene_path)
			if not (scene is PackedScene):
				return false
			_appraisal_ui = (scene as PackedScene).instantiate()
			host.add_child(_appraisal_ui)
	if _appraisal_ui.has_method("open_for_npc"):
		_appraisal_ui.call("open_for_npc",npc_id)
	elif _appraisal_ui.has_method("open"):
		_appraisal_ui.call("open", npc_id)
	return true


# ================================================================================================ save

func to_dict() -> Dictionary:
	var wander_out := {}
	for zone in wanderers:
		var rec := _Data.dict(wanderers[zone])
		wander_out[str(zone)] = {"found": _Data.strings(rec.get("found", [])), "misses": _Data.int_map(rec.get("misses", {}))}
	var boss_out := {}
	for id in boss_state:
		var b := _Data.dict(boss_state[id])
		boss_out[str(id)] = {
			"kills": _Data.int_of(b.get("kills", 0)), "last_day": _Data.int_of(b.get("last_day", 0)), "misses": _Data.int_of(b.get("misses", 0)),
			"pool_left": _Data.strings(b.get("pool_left", [])), "first_done": bool(b.get("first_done", false)), "last_uid": str(b.get("last_uid", "")),
		}
	var out := {"v": SAVE_VERSION, "rng": _Codec.rng_to_json(rng), "opened": _plain_ints(opened), "claimed": _plain_ints(claimed), "wanderers": wander_out, "boss": boss_out}
	if not dungeon.is_empty():
		out["dungeon"] = dungeon.duplicate(true)
	return out


## Rollback restores the exact already-validated runtime preimage. The ordinary
## disk loader deliberately expands optional dungeon defaults; doing so while
## unwinding a friendship gift would change its sparse committed accounting.
func restore_rollback(d: Dictionary) -> bool:
	if not from_dict(d): return false
	dungeon = _Data.dict(d.get("dungeon", {})).duplicate(true)
	return true

## false rejects the load (the whole load is then rolled back): a newer version or a section of the wrong shape
func from_dict(d: Dictionary) -> bool:
	if not validate_dict(d):
		return false
	_Codec.rng_from_json(rng, d.get("rng", {}))
	opened = _plain_ints(d.get("opened", {}))
	claimed = _plain_ints(d.get("claimed", {}))
	for key in _plain_ints(d.get("gifts", {})):                    # the first draft kept the gifts in a table of their own
		if not claimed.has(key):
			claimed[key] = int(_plain_ints(d.get("gifts", {}))[key])
	wanderers = {}
	var w := _Data.dict(d.get("wanderers", {}))
	for zone in w:
		var rec := _Data.dict(w[zone])
		wanderers[str(zone)] = {"found": _Data.strings(rec.get("found", [])), "misses": _Data.int_map(rec.get("misses", {}))}
	boss_state = {}
	var b := _Data.dict(d.get("boss", {}))
	for id in b:
		var rec2 := _Data.dict(b[id])
		boss_state[str(id)] = {
			"kills": _Data.int_of(rec2.get("kills", 0)), "last_day": _Data.int_of(rec2.get("last_day", 0)), "misses": _Data.int_of(rec2.get("misses", 0)),
			"pool_left": _Data.strings(rec2.get("pool_left", [])), "first_done": bool(rec2.get("first_done", false)), "last_uid": str(rec2.get("last_uid", "")),
		}
	dungeon = _Data.dict(d.get("dungeon", {})).duplicate(true)
	if _delegate_has(&"from_dict"):
		var normalized: Variant = _delegate_call(&"from_dict",[dungeon])
		if normalized is Dictionary: dungeon = normalized
	_cap_told_day = 0
	return true


## pure check of a saved section (SaveManager calls it while inspecting a slot, before any live state changes)
func validate_dict(d: Dictionary) -> bool:
	if _Data.int_of(d.get("v", SAVE_VERSION), SAVE_VERSION) > SAVE_VERSION:
		return false
	for key in ["opened", "claimed", "wanderers", "boss", "dungeon", "rng", "gifts"]:
		if d.has(key) and typeof(d[key]) != TYPE_DICTIONARY:
			return false
	return true


## {key: int} of a table that went through JSON (every number is a float there); entries that are not numbers are dropped
func _plain_ints(v: Variant) -> Dictionary:
	var out := {}
	var src := _Data.dict(v)
	for k in src:
		var t := typeof(src[k])
		if t == TYPE_INT or t == TYPE_FLOAT:
			out[str(k)] = int(src[k])
	return out
