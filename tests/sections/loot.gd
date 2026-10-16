extends RefCounted
## Section loot (package F4-loot-shops, wave M1b-1): LootService (autoload), LootRules, the three marker handlers and lua/config/marker_handlers.lua.
##
## Task 1 / 2 (the algorithm):  rates_match_odds (40 000 seeded opens per container, z < 3, rarity AND kind shares, find_chance, roll counts), legendary_never_from_chests,
##   wanderer_once_with_pity, boss_pity, spots_one_time_and_conditions, duplicate_garment_sold, luck_bias, save_roundtrip_rng_strings, respawn_days
## Task 4 (handlers):  markers_open_claim_respawn (a copy of data/maps/_fixture_iso.map with the three markers added)
## Dungeon amendment:  dungeon_floors_node_hosted_and_section_registered, marker_handlers_registered, dungeon_markers_use_done_cells_and_uid, chest_lock_needs_key, locked_chest_consumes_key,
##   full_backpack_leaves_chest_closed, multi_roll_full_backpack_changes_nothing, lake_chest_has_art_or_padlock_fallback, hidden_chest_reveal_radius, dungeon_ctx_signatures_and_full_backpack,
##   two_phase_plan_fit_deliver_commit_with_fake, no_opened_entries_for_dungeon_uids, dungeon_delegate_seam_with_fake, save_roundtrip_dungeon_subdict_optional, boss_table_keyed_by_id,
##   legendary_never_from_ordinary_chests, open_appraisal_event_instantiates_scene_when_present, open_appraisal_event_ignored_without_scene, dungeon_keys_defined_da_en
## Towns / farm / social amendment (RT19):  marker_handlers_registered_farm_types, marker_handlers_town_door_post_rows, marker_handlers_table_valid, marker_handlers_registered_room_services,
##   check_friend_gifts_idempotent, price_curve_reads_keeper_hearts, set_capstone_granted_reads_the_record
## Everything statistical runs on SEEDED streams (the same numbers on every run) and finishes in well under 20 s. The real dungeon rules (DL5), the real DungeonFloors node (D2) and the
## real appraisal screen (DL7) belong to later waves: the seams are proven with FAKES written to user:// (SKIP lines name the owners).
const SECTION := "loot"
const TIMEOUT_S := 240.0
const FIXTURE_DIR := "user://f4_fixtures"
const FLOORS_FIXTURE := "user://f4_fixtures/fake_dungeon_floors.gd"
const RULES_FIXTURE := "user://f4_fixtures/fake_dungeon_loot_rules.gd"
const SCENE_FIXTURE := "user://f4_fixtures/fake_appraisal_ui.tscn"
const FLOOR_ITEMS := ["wood", "stone", "moss", "iron_ore", "copper_ore", "gold_ore", "amethyst", "emerald", "moonstone", "gem_bag", "rare_mushroom", "glow_mushroom",
	"lucky_clover", "wild_flower", "night_bloom", "fern", "apple", "friendship_token", "catnip", "carrot", "pumpkin", "turnip", "strawberry", "sunflower", "honey", "milk", "egg", "wool"]

## a furniture / clothing STORE that refuses a copy beyond `cap` (the contract of the stores of F3 / F5: add, remove, can_add, count_total)
class FakeStore extends Node:
	var held: Dictionary = {}
	var cap: int = 1

	func can_add(id: Variant, n: int) -> bool:
		return n > 0 and int(held.get(str(id), 0)) + n <= cap

	func add(id: Variant, n: int) -> bool:
		if not can_add(id, n):
			return false
		held[str(id)] = int(held.get(str(id), 0)) + n
		return true

	func remove(id: Variant, n: int) -> bool:
		if int(held.get(str(id), 0)) < n:
			return false
		held[str(id)] = int(held[str(id)]) - n
		return true

	func count_total(id: Variant) -> int:
		return int(held.get(str(id), 0))

	func count_stock(id: Variant) -> int:
		return count_total(id)

	func owned_ids() -> Array:
		return held.keys()

	func reset() -> void:
		held.clear()

## the perk sources the formula reads: gear luck and gear discount
class FakeGear extends Node:
	var luck: float = 0.0
	var discount: float = 0.0

	func gear_points(kind: String) -> float:
		return luck if kind == "luck" else (discount if kind == "discount" else 0.0)

var t
var ls: Node
var gm: Node
var eco: Node
var qm: Node
var sm: Node
var bus: Node
var _whispers: Array[String] = []
var _rolled: Array = []
var _events: Array = []
var _toasts: Array[String] = []
var _rank_memo: Dictionary = {}
var _one_memo: Dictionary = {}
var _group_ok: bool = true


func run(tt) -> void:
	t = tt
	ls = t.autoload("LootService")
	gm = t.autoload("GameManager")
	eco = t.autoload("EconomyManager")
	qm = t.autoload("QuestManager")
	sm = t.autoload("SaveManager")
	bus = t.autoload("EventBus")
	if ls == null:
		t.skip("LootService is not an autoload of this tree: add_autoload.py LootService was not run (the section needs the real service)")
		return
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)
	bus.whisper_requested.connect(_on_whisper)
	bus.loot_rolled.connect(_on_rolled)
	bus.game_event.connect(_on_event)
	bus.notification_posted.connect(_on_toast)
	var clock := Time.get_ticks_msec()
	var laps: Array[String] = []
	_data_shape()
	_rates()
	laps.append("rates %d" % (Time.get_ticks_msec() - clock))
	clock = Time.get_ticks_msec()
	_legendary()
	laps.append("legendary %d" % (Time.get_ticks_msec() - clock))
	clock = Time.get_ticks_msec()
	_luck()
	laps.append("luck %d" % (Time.get_ticks_msec() - clock))
	clock = Time.get_ticks_msec()
	_creatures()
	laps.append("creatures %d" % (Time.get_ticks_msec() - clock))
	clock = Time.get_ticks_msec()
	_wanderers()
	laps.append("wanderers %d" % (Time.get_ticks_msec() - clock))
	clock = Time.get_ticks_msec()
	_respawn()
	_boss()
	laps.append("respawn+boss %d" % (Time.get_ticks_msec() - clock))
	clock = Time.get_ticks_msec()
	_spots()
	_gifts_and_capstones()
	_duplicates()
	_full_backpack()
	_save()
	laps.append("spots..save %d" % (Time.get_ticks_msec() - clock))
	clock = Time.get_ticks_msec()
	await _markers_fixture()
	_marker_registry()
	_real_maps()
	_floors_hosting()
	await _dungeon_handlers()
	_delegate_seam()
	await _appraisal_host()
	_keys()
	_price_keeper()
	laps.append("handlers..price %d" % (Time.get_ticks_msec() - clock))
	t.info("laps (ms): " + ", ".join(laps))
	_cleanup()
	bus.whisper_requested.disconnect(_on_whisper)
	bus.loot_rolled.disconnect(_on_rolled)
	bus.game_event.disconnect(_on_event)
	bus.notification_posted.disconnect(_on_toast)


func _on_whisper(text: String) -> void:
	_whispers.append(text)


func _on_rolled(source: StringName, results: Array) -> void:
	_rolled.append([source, results])


func _on_event(event_name: StringName, payload: Dictionary) -> void:
	_events.append([event_name, payload])


func _on_toast(_title: String, _message: String, icon: String) -> void:
	_toasts.append(icon)


# ============================================================================================ helpers

func _fresh(seed_value: int = 424242) -> void:
	Svc.clear_overrides()
	ls.set_loot_config(null)
	ls.delegate_path = ls.DELEGATE_PATH
	ls.dungeon_floors_path = ls.DUNGEON_FLOORS_PATH
	ls.appraisal_scene_path = ls.APPRAISAL_SCENE
	Engine.set_meta("f4_log", [])
	Fresh.new_game(t, "", "Tester", "Testgaarden", "", seed_value)
	_whispers.clear()
	_rolled.clear()
	_events.clear()
	_toasts.clear()


func _z(k: float, n: float, p: float) -> float:
	if p <= 0.0 or p >= 1.0:
		return 0.0 if is_equal_approx(k, n * p) else 99.0
	return (k - n * p) / sqrt(n * p * (1.0 - p))


## is this row a keepsake (rank >= unique, or one-of-a-kind)? Memoised per id / rarity: the statistics call it for every found roll
func _keepsake(row: Dictionary) -> bool:
	var rar: String = row["rarity"]
	if not _rank_memo.has(rar):
		_rank_memo[rar] = Rarity.rank(rar)
	if int(_rank_memo[rar]) >= 4:
		return true
	var id: String = row["id"]
	if not _one_memo.has(id):
		_one_memo[id] = ItemKinds.is_one_of_a_kind(id)
	return bool(_one_memo[id])


## the kind shares an ordinary roll must have: P(kind) = sum over rarities of P(rarity) x w_kind / (sum of the weights of the kinds that HAVE an item of that rarity) - the empty-pool re-draw
func _expected_kinds(idx: Dictionary, zone: String, cc: Dictionary, luck: float) -> Dictionary:
	var odds := LootRules.luck_odds(cc["odds"], luck)
	var whole := 0.0
	for r in odds:
		whole += float(odds[r])
	var kinds: Dictionary = cc["kinds"]
	var out := {}
	for r in odds:
		var pr: float = float(odds[r]) / whole
		if pr <= 0.0:
			continue
		var avail := {}
		var wsum := 0.0
		for k in kinds:
			if not LootRules.slice_of(idx, zone, str(k), str(r)).is_empty():
				avail[k] = float(kinds[k])
				wsum += float(kinds[k])
		for k in avail:
			out[k] = float(out.get(k, 0.0)) + pr * float(avail[k]) / wsum
	return out


func _fill_backpack(except: Array = []) -> void:
	for id in FLOOR_ITEMS:
		if eco.free_slots() <= 0:
			break
		if id in except:
			continue
		eco.add_item(StringName(id), 1, true)


func _free_slots_to(n: int) -> void:
	while eco.free_slots() < n and eco.inventory.size() > 0:
		eco.inventory.remove_at(eco.inventory.size() - 1)


func _pool_cfg(items: Array, rolls: int = 1, kind: String = "material", rarity: String = "normal", extra: Dictionary = {}, zone_ids: Array = ["zz"]) -> Dictionary:
	var entries: Array = []
	for id in items:
		entries.append({"item": id, "w": 10})
	var zones := {}
	for zid in zone_ids:
		zones[zid] = {"pools": {kind: {rarity: entries.duplicate(true)}}, "containers": {}, "wanderers": []}
	var row := {"respawn_days": 7, "rolls": {"min": rolls, "max": rolls}, "find_chance": 1.0, "odds": {"normal": 10000, "uncommon": 0, "rare": 0}, "kinds": {kind: 100}, "wander_bp": 0, "pity_opens": 0}
	var cfg := {
		"odds_basis": 10000,
		"duplicates": {"kinds": ["clothing", "furniture"], "action": "sell"},
		"containers": {"trae": row.duplicate(true), "jern": row.duplicate(true), "noegle": row.duplicate(true), "dig": row.duplicate(true)},
		"creatures": {}, "spots": {}, "gifts": [], "tier_gifts": [], "set_rewards": [], "boss": {},
		"zones": zones,
	}
	(cfg["containers"]["dig"] as Dictionary)["respawn_days"] = 1
	cfg.merge(extra, true)
	return cfg


func _inventory_snapshot() -> String:
	return JSON.stringify(eco.to_dict()) + str(eco.gold)


func _day(total_day: int) -> void:
	Fresh.jump_to_total_day(total_day)


# ============================================================================================ data shape

func _data_shape() -> void:
	_fresh()
	var cfg: Dictionary = ls.loot_cfg()
	var zones: Dictionary = cfg.get("zones", {})
	var zone_ids: Array = zones.keys()
	zone_ids.sort()
	t.check("zones_are_the_five_area_ids", zone_ids == ["dybe_bregner", "farm", "krystalgrotten", "skovkant", "svampelunden"], "config loot has the five zones %s; Hyggebyen has none (its only find is the spot kufferten)" % str(zone_ids))
	var spots: Dictionary = cfg.get("spots", {})
	var kufferten: Dictionary = spots.get("kufferten", {})
	t.check("hyggebyen_has_only_the_spot_kufferten", not zones.has("hyggebyen") and str(kufferten.get("zone", "")) == "hyggebyen" and spots.size() == 15, "15 spots, kufferten in zone hyggebyen, no hyggebyen zone")
	var ok_sum := true
	for cid in (cfg["containers"] as Dictionary):
		var o: Dictionary = (cfg["containers"] as Dictionary)[cid]["odds"]
		ok_sum = ok_sum and int(o["normal"]) + int(o["uncommon"]) + int(o["rare"]) == 10000 and not o.has("unique") and not o.has("legendary")
	t.expect(ok_sum, "every container's odds sum to 10 000 basis points and have NO unique / legendary column")
	var shape: bool = ls.world_seed == ls.rng.seed
	t.expect(shape and ls.has_method("open_container") and ls.has_method("dig") and ls.has_method("claim_spot") and ls.has_method("check_friend_gifts") and ls.has_method("grant_set_capstone"), "the API of the order exists on the autoload")
	t.expect(not LootRules.container_cfg(cfg, "farm", "dig").is_empty() and absf(float(LootRules.container_cfg(cfg, "farm", "dig")["find_chance"]) - 0.06) < 1e-9 and absf(float(LootRules.container_cfg(cfg, "skovkant", "dig")["find_chance"]) - 0.12) < 1e-9,
		"the farm's dig overrides find_chance (0.06), the forest digs keep the base 0.12; `count` is map data and not part of the container")


# ============================================================================================ rates

func _rates() -> void:
	_fresh()
	var cfg: Dictionary = ls.loot_cfg()
	var idx := LootRules.build_index(cfg)
	var rng := RandomNumberGenerator.new()
	var plan := [["skovkant", "trae", 11], ["skovkant", "jern", 22], ["dybe_bregner", "fe", 33], ["dybe_bregner", "konge", 44], ["farm", "dig", 55]]
	var worst := 0.0
	var worst_what := ""
	var t0 := Time.get_ticks_msec()
	var total_checks := 0
	for pc in plan:
		var zone: String = pc[0]
		var cid: String = pc[1]
		var cc := LootRules.container_cfg(cfg, zone, cid)
		rng.seed = int(pc[2]) * 7919
		var by_r := {}
		var by_k := {}
		var by_n := {}
		var found := 0
		var slots := 0
		var keepsakes := 0
		var cplan := LootRules.compile(idx, zone, cc, 0.0)
		for _i in 40000:
			var n := LootRules.roll_count(cc, rng)
			by_n[n] = int(by_n.get(n, 0)) + 1
			for _j in n:
				slots += 1
				var row := LootRules.roll_plan(cplan, rng)
				if row.is_empty():
					continue
				found += 1
				by_r[row["rarity"]] = int(by_r.get(row["rarity"], 0)) + 1
				by_k[row["kind"]] = int(by_k.get(row["kind"], 0)) + 1
				if _keepsake(row):
					keepsakes += 1
		var fc := float(cc.get("find_chance", 1.0))
		var zs := {}
		zs["find_chance"] = _z(found, slots, fc)
		var odds := LootRules.luck_odds(cc["odds"], 0.0)
		for r in LootRules.ORDINARY:
			zs["rarity_" + r] = _z(float(by_r.get(r, 0)), found, float(odds[r]) / 10000.0)
		var exp_k := _expected_kinds(idx, zone, cc, 0.0)
		for k in exp_k:
			zs["kind_" + str(k)] = _z(float(by_k.get(k, 0)), found, float(exp_k[k]))
		var rolls: Dictionary = cc["rolls"]
		if int(rolls["max"]) > int(rolls["min"]):
			zs["rolls_max"] = _z(float(by_n.get(int(rolls["max"]), 0)), 40000.0, 1.0 / float(int(rolls["max"]) - int(rolls["min"]) + 1))
		for key in zs:
			total_checks += 1
			if absf(float(zs[key])) > worst:
				worst = absf(float(zs[key]))
				worst_what = "%s/%s %s" % [zone, cid, key]
		t.expect(keepsakes == 0, "%s/%s: 40 000 openings gave %d rolls and not one unique / legendary item" % [zone, cid, found])
	var ms := Time.get_ticks_msec() - t0
	t.check("rates_match_odds", worst < 3.0, "40 000 seeded openings per container (trae, jern, fe, konge, dig): %d z-tests (find_chance, rarity odds, kind shares after the empty-pool re-draw, roll counts), worst |z| = %.2f (%s), %d ms" % [total_checks, worst, worst_what, ms])
	t.expect(ms < 15000, "the statistics finish in %d ms (budget 20 s for the section)" % ms)
	# an EMPTY pool re-draws the kind: a zone whose only material pool is empty at `rare` never hands out a material at rare, and the other kinds absorb the roll
	var tiny := _pool_cfg(["wood"], 1, "material", "normal")
	(tiny["zones"]["zz"]["pools"] as Dictionary)["furniture"] = {"rare": [{"item": "bed_walnut", "w": 10}]}
	(tiny["containers"]["trae"] as Dictionary)["kinds"] = {"material": 50, "furniture": 50}
	(tiny["containers"]["trae"] as Dictionary)["odds"] = {"normal": 0, "uncommon": 0, "rare": 10000}
	var idx2 := LootRules.build_index(tiny)
	var cc2 := LootRules.container_cfg(tiny, "zz", "trae")
	var seen := {}
	rng.seed = 5
	for _i in 2000:
		var row2 := LootRules.roll_ordinary(idx2, "zz", cc2, 0.0, rng)
		seen[str(row2.get("id", "-"))] = true
	t.check("empty_pool_redraws_the_kind", seen.keys() == ["bed_walnut"], "rare odds 100 %%, only the furniture pool has a rare item: every roll is it (%s)" % str(seen.keys()))
	# the compiled draw (flat arrays) is the SAME draw as the straightforward dictionary algorithm: identical rows and an identical stream, on every real container, at three lucks and on
	# the pool with an empty slice (the re-draw path)
	var same := true
	var compared := 0
	var cases: Array = []
	for pc2 in plan:
		for lk in [0.0, 0.07, 0.2]:
			cases.append([idx, pc2[0], LootRules.container_cfg(cfg, pc2[0], pc2[1]), lk])
	cases.append([idx2, "zz", cc2, 0.0])
	for case in cases:
		var ra := RandomNumberGenerator.new()
		var rb := RandomNumberGenerator.new()
		ra.seed = 90210
		rb.seed = 90210
		var comp := LootRules.compile(case[0], case[1], case[2], case[3])
		for _i in 2500:
			var x := LootRules.roll_plan(comp, ra)
			var y := _reference_roll(case[0], case[1], case[2], case[3], rb)
			compared += 1
			if JSON.stringify(x) != JSON.stringify(y) or ra.state != rb.state:
				same = false
				break
	t.check("compiled_draw_equals_the_reference", same and compared == cases.size() * 2500, "LootRules.compile + roll_plan gives the same %d rows and the same stream state as the straightforward dictionary algorithm (5 containers x 3 lucks + the empty-pool config)" % compared)


## the straightforward draw of SCHEMA 6 with plain dictionaries (the oracle of compiled_draw_equals_the_reference): find_chance, kind, rarity after luck, [kind again for an empty pool], item
func _reference_roll(idx: Dictionary, zone: String, cc: Dictionary, luck: float, rng: RandomNumberGenerator) -> Dictionary:
	var fc := float(cc.get("find_chance", 1.0))
	if fc < 1.0 and rng.randf() >= fc:
		return {}
	var kinds: Dictionary = cc.get("kinds", {})
	var kind := LootRules.pick_weighted(rng, kinds)
	var rarity := LootRules.pick_weighted(rng, LootRules.luck_odds(cc.get("odds", {}), luck))
	if kind == "" or rarity == "":
		return {}
	var slice := LootRules.slice_of(idx, zone, kind, rarity)
	if slice.is_empty():
		var open_kinds := {}
		for k in kinds:
			if not LootRules.slice_of(idx, zone, str(k), rarity).is_empty():
				open_kinds[k] = kinds[k]
		kind = LootRules.pick_weighted(rng, open_kinds)
		if kind == "":
			return {}
		slice = LootRules.slice_of(idx, zone, kind, rarity)
	return {"id": LootRules.pick_item(rng, slice), "amount": 1, "rarity": rarity, "kind": kind}


# ============================================================================================ legendary never from chests

func _legendary() -> void:
	_fresh()
	var cfg: Dictionary = ls.loot_cfg()
	var idx := LootRules.build_index(cfg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad := 0
	var combos := 0
	var wanderer_ids := {}
	for zone in (cfg["zones"] as Dictionary):
		for w in LuaData.arr(((cfg["zones"] as Dictionary)[zone] as Dictionary).get("wanderers", [])):
			wanderer_ids[str(w["item"])] = true
	for zone in (cfg["zones"] as Dictionary):
		var zc: Dictionary = (cfg["zones"] as Dictionary)[zone]
		for cid in (cfg["containers"] as Dictionary):
			var cc := LootRules.container_cfg(cfg, str(zone), str(cid))
			combos += 1
			var plan := LootRules.compile(idx, str(zone), cc, 0.2)
			for _i in 1500:
				for _j in LootRules.roll_count(cc, rng):
					var row := LootRules.roll_plan(plan, rng)
					if not row.is_empty() and _keepsake(row):
						bad += 1
		# the data: every pool entry sits under its own rarity and is no keepsake
		for kind in (zc.get("pools", {}) as Dictionary):
			for r in (zc["pools"][kind] as Dictionary):
				for e in LuaData.arr(zc["pools"][kind][r]):
					var def := ItemKinds.def(str(e["item"]))
					if def.is_empty() or str(Rarity.normalize(def.get("rarity", "normal"))) != str(r) or ItemKinds.is_one_of_a_kind(str(e["item"])):
						bad += 1
	t.check("legendary_never_from_chests", bad == 0, "%d zone x container combinations at luck 0.2 (1 500 openings each) and every pool entry of the data: %d legendary or unique items, every entry sits under its own rarity" % [combos, bad])
	# a pool that someone poisoned with a keepsake never hands it out (the runtime guard), whatever the odds
	var poisoned := _pool_cfg(["wood"], 1, "furniture", "normal")
	poisoned["zones"]["zz"]["pools"]["furniture"]["normal"] = [{"item": "throne_root", "w": 1000}, {"item": "bed_pine", "w": 1}]
	var idx2 := LootRules.build_index(poisoned)
	var cc2 := LootRules.container_cfg(poisoned, "zz", "trae")
	var legend_rank := Rarity.rank(ItemKinds.rarity_of("throne_root"))
	var got := {}
	for _i in 500:
		got[str(LootRules.roll_ordinary(idx2, "zz", cc2, 0.0, rng).get("id", "-"))] = true
	t.check("keepsake_in_a_pool_is_skipped", legend_rank >= 4 and got.keys() == ["bed_pine"], "throne_root (rank %d) sits in a pool at weight 1000: the draw never returns it (%s)" % [legend_rank, str(got.keys())])
	# through the service in a dungeon band, with a ctx that tries to force odds
	_fresh()
	ls.set_seed(31)
	var seen_rank := 0
	var uniques := 0
	for i in 3000:
		for tier in ["trae", "jern", "fe", "konge"]:
			var res: Dictionary = ls.open_container("dybe_bregner", tier, "dg:1:4:%d" % i, {"dungeon": true, "band": "dybe_bregner", "deliver": "orbs", "odds": {"normal": 0, "legendary": 10000}})
			for row in res["results"]:
				if Rarity.rank(row["rarity"]) >= 5:
					seen_rank += 1
				elif Rarity.rank(row["rarity"]) == 4:
					uniques += 1
	t.check("legendary_never_from_ordinary_chests", seen_rank == 0 and uniques <= 1, "12 000 dungeon-band openings with ctx.odds = 100 %% legendary (ignored): %d legendary; the only unique is the one wanderer of the band (%d)" % [seen_rank, uniques])


# ============================================================================================ luck

func _luck() -> void:
	_fresh()
	var cfg: Dictionary = ls.loot_cfg()
	t.expect(is_equal_approx(LootRules.clamp_luck(0.5), 0.2) and is_equal_approx(LootRules.clamp_luck(-0.3), 0.0) and is_equal_approx(LootRules.clamp_luck(0.07), 0.07), "L = clamp(Perks.total(luck), 0, 0.20)")
	var gear := FakeGear.new()
	Svc.override("WardrobeManager", gear)
	gear.luck = 0.15
	var l15: float = ls.luck()
	gear.luck = 0.5
	var l50: float = ls.luck()
	t.expect(is_equal_approx(l15, 0.15) and is_equal_approx(l50, 0.2), "luck() reads Perks.total('luck'): 0.15 -> %.2f, a gear of 0.5 is capped at %.2f" % [l15, l50])
	Svc.clear_overrides()
	gear.free()
	var trae := LootRules.container_cfg(cfg, "skovkant", "trae")
	var o2 := LootRules.luck_odds(trae["odds"], 0.2)
	t.expect(is_equal_approx(float(o2["uncommon"]), 5200.0) and is_equal_approx(float(o2["rare"]), 800.0) and is_equal_approx(float(o2["normal"]), 4000.0), "trae at luck 0.2: uncommon 2600 -> 5200, rare 400 -> 800, normal absorbs 7000 -> 4000")
	var konge := LootRules.container_cfg(cfg, "dybe_bregner", "konge")
	var o3 := LootRules.luck_odds(konge["odds"], 0.2)
	t.expect(is_equal_approx(float(o3["normal"]), 0.0) and is_equal_approx(float(o3["uncommon"]) + float(o3["rare"]), 10000.0), "the king's chest has no normal roll to give: uncommon and rare are scaled down together, the sum stays 10 000")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var idx := LootRules.build_index(cfg)
	var worst := 0.0
	var shares := {}
	for lk in [0.0, 0.1, 0.2]:
		var counts := {"normal": 0, "uncommon": 0, "rare": 0}
		var n := 0
		var plan := LootRules.compile(idx, "skovkant", trae, lk)
		for _i in 40000:
			var row := LootRules.roll_plan(plan, rng)
			if row.is_empty():
				continue
			n += 1
			counts[row["rarity"]] = int(counts[row["rarity"]]) + 1
		var want := LootRules.luck_odds(trae["odds"], lk)
		for r in LootRules.ORDINARY:
			worst = maxf(worst, absf(_z(float(counts[r]), n, float(want[r]) / 10000.0)))
		shares[lk] = float(counts["uncommon"]) / float(n)
	t.check("luck_bias", worst < 3.0 and float(shares[0.2]) > float(shares[0.1]) and float(shares[0.1]) > float(shares[0.0]) and absf(float(shares[0.2]) / float(shares[0.0]) - 2.0) < 0.15, "trae, 40 000 rolls at luck 0 / 0.1 / 0.2: worst |z| %.2f; uncommon share %.3f / %.3f / %.3f (x1 / x1.5 / x2)" % [worst, shares[0.0], shares[0.1], shares[0.2]])
	var jern := LootRules.container_cfg(cfg, "skovkant", "jern")
	t.expect(is_equal_approx(LootRules.wander_chance_bp(jern, 0.0), 1200.0) and is_equal_approx(LootRules.wander_chance_bp(jern, 0.2), 2400.0) and LootRules.wander_chance_bp({"wander_bp": 9000}, 0.2) == 10000.0, "the wanderer chance is wander_bp x (1 + 5 L), at most 100 %: jern 1200 -> 2400 at luck 0.2")
	var hits := 0
	for _i in 40000:
		if LootRules.wanderer_due({"wander_bp": 1200, "pity_opens": 0}, 0.2, 0, rng):
			hits += 1
	t.expect(absf(_z(hits, 40000, 0.24)) < 3.0, "the wanderer decision at luck 0.2 fires %.3f of the openings (want 0.24, z %.2f)" % [hits / 40000.0, _z(hits, 40000, 0.24)])
	# through the service: ctx.luck is honoured and clamped
	_fresh()
	ls.set_seed(8)
	var up0 := 0
	var up2 := 0
	for i in 3000:
		var a: Dictionary = ls.open_container("skovkant", "trae", "lk0:%d" % i, {"luck": 0.0, "deliver": "orbs"})
		var b: Dictionary = ls.open_container("skovkant", "trae", "lk2:%d" % i, {"luck": 0.9, "deliver": "orbs"})
		for row in a["results"]:
			up0 += 1 if row["rarity"] != "normal" else 0
		for row in b["results"]:
			up2 += 1 if row["rarity"] != "normal" else 0
	t.expect(up2 > up0 * 1.6, "open_container(ctx.luck) shifts the odds through the service as well (%d vs %d non-normal finds in 3 000 openings; 0.9 is clamped to 0.2)" % [up2, up0])


# ============================================================================================ creatures, sources and events

func _creatures() -> void:
	_fresh(15)
	var cfg: Dictionary = ls.loot_cfg()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var found := 0
	var n := 40000
	var by_rarity := {}
	var keepsakes := 0
	for _i in n:
		var res: Dictionary = ls.on_enemy_defeated("bat", {"rng": rng, "zone": "skovkant"})
		for row in res["results"]:
			found += 1
			by_rarity[row["rarity"]] = int(by_rarity.get(row["rarity"], 0)) + 1
			keepsakes += 1 if Rarity.rank(row["rarity"]) >= 4 else 0
	var fc := float(cfg["creatures"]["bat"]["find_chance"])
	var z := _z(found, n, fc)
	var odds := LootRules.luck_odds(cfg["creatures"]["bat"]["odds"], 0.0)
	var worst := absf(z)
	for r in LootRules.ORDINARY:
		worst = maxf(worst, absf(_z(float(by_rarity.get(r, 0)), found, float(odds[r]) / 10000.0)))
	t.check("creature_drop_rate", worst < 3.0 and keepsakes == 0 and eco.count_item(&"wood") == 0, "40 000 bat kills (find_chance %.2f): %d drops, worst |z| %.2f over the find chance and the three rarity shares, no keepsake" % [fc, found, worst])
	# the default is `orbs`: the results come back, nothing is added, no loot_rolled; deliver = add puts the find into the pack
	_fresh(16)
	_rolled.clear()
	var inv := _inventory_snapshot()
	var seen_rows := 0
	for i in 400:
		var res2: Dictionary = ls.on_enemy_defeated("ugleoje", {"zone": "dybe_bregner", "uid": "k%d" % i})
		seen_rows += (res2["results"] as Array).size()
	t.expect(seen_rows > 0 and _inventory_snapshot() == inv and _rolled.is_empty(), "on_enemy_defeated returns its drops without adding them (ctx.deliver = orbs is the default): %d rows, backpack and gold unchanged, no loot_rolled" % seen_rows)
	var delivered := 0
	for i in 600:
		var res3: Dictionary = ls.on_enemy_defeated("ugleoje", {"zone": "dybe_bregner", "deliver": "add", "rng": rng})
		delivered += (res3["results"] as Array).size()
	var cfg_pool: Dictionary = ls.loot_cfg()
	t.expect(delivered > 0 and _rolled.size() == delivered and not bool(ls.on_enemy_defeated("no_such_beast")["ok"]) and ls.on_enemy_defeated("no_such_beast")["reason"] == &"unknown_creature" and cfg_pool["creatures"].has("bat"), "deliver = add hands the find over at once (%d finds, one loot_rolled each); an unknown creature is refused" % delivered)
	# the zone of a kill without ctx: the zone whose creature list names the kind (first), so a bat from the forest edge rolls the forest edge's pools
	var by_kind := {}
	for _i in 4000:
		for row in ls.on_enemy_defeated("bat", {"rng": rng})["results"]:
			by_kind[ItemKinds.def(row["id"]).get("category", "")] = true
	t.expect(not by_kind.is_empty(), "a kill without ctx.zone / ctx.band still rolls (the zone is looked up: the first zone that lists the creature)")
	# loot_rolled: source = kind:id, rows = [{id, amount, rarity, kind}], rare_item_found through EconomyManager for rank >= rare
	_fresh(17)
	var rares: Array = []
	var rare_cb := func(id: StringName, rarity: StringName) -> void: rares.append([id, rarity])
	bus.rare_item_found.connect(rare_cb)
	ls.set_loot_config(_pool_cfg(["bed_walnut"], 1, "furniture", "rare"))
	(ls.loot_cfg()["containers"]["trae"] as Dictionary)["odds"] = {"normal": 0, "uncommon": 0, "rare": 10000}
	ls.invalidate_index()
	_rolled.clear()
	var open: Dictionary = ls.open_container("zz", "trae", "zz:1,1")
	var row0: Dictionary = (_rolled[0][1][0]) if not _rolled.is_empty() else {}
	t.check("loot_rolled_and_rare_item_found", bool(open["ok"]) and _rolled.size() == 1 and _rolled[0][0] == &"chest:trae" and row0.keys().size() == 4 and row0["id"] == "bed_walnut" and row0["amount"] == 1 and row0["rarity"] == "rare" and row0["kind"] == "furniture" and rares == [[&"bed_walnut", &"rare"]],
		"opening a trae crate emits loot_rolled(&\"chest:trae\", [{id, amount, rarity, kind}]) once and, for the rare find, EconomyManager's rare_item_found (%s)" % str(rares))
	bus.rare_item_found.disconnect(rare_cb)
	(ls.loot_cfg()["containers"]["dig"] as Dictionary)["odds"] = {"normal": 0, "uncommon": 0, "rare": 10000}
	_rolled.clear()
	ls.dig("zz", "zz:2,2")
	t.expect(_rolled.size() == 1 and _rolled[0][0] == &"dig:dig", "a dig's source is dig:dig")


# ============================================================================================ wanderers

func _wanderers() -> void:
	_fresh()
	var cfg: Dictionary = ls.loot_cfg()
	var jern := LootRules.container_cfg(cfg, "skovkant", "jern")
	var pity := int(jern["pity_opens"])
	var p := float(jern["wander_bp"]) / 10000.0
	var q := 1.0 - p
	# analytic mean and variance of the openings until the wanderer, capped at `pity`
	var mean := (1.0 - pow(q, pity)) / p
	var second := 0.0
	for k in range(1, pity):
		second += float(k * k) * pow(q, k - 1) * p
	second += float(pity * pity) * pow(q, pity - 1)
	var sd := sqrt(second - mean * mean)
	var trials := 400
	var total := 0.0
	var worst_gap := 0
	var multi := 0
	var first_is_wanderer := true
	var item := "rug_flower_petal"
	for s in trials:
		ls.reset()                                  # a fresh save: nothing found, nothing opened (the cheap half of Fresh.new_game, which seeds the same way)
		ls.set_seed(1000 + s)
		var opens := 0
		var got := false
		while not got and opens < 40:
			opens += 1
			var res: Dictionary = ls.open_container("skovkant", "jern", "w%d:%d" % [s, opens], {"deliver": "orbs"})
			var uniques := 0
			for i in (res["results"] as Array).size():
				var row: Dictionary = res["results"][i]
				if row["rarity"] == "unique":
					uniques += 1
					if row["id"] == item:
						got = true
						first_is_wanderer = first_is_wanderer and i == 0
			multi += 1 if uniques > 1 else 0
		total += opens
		worst_gap = maxi(worst_gap, opens)
	var z := (total / trials - mean) / (sd / sqrt(float(trials)))
	t.check("wanderer_once_with_pity", worst_gap <= pity and multi == 0 and first_is_wanderer and absf(z) < 3.0, "jern in skovkant (wander_bp %d, pity_opens %d): %d fresh saves, the wanderer came after at most %d openings (pity), mean %.2f vs analytic %.2f (z %.2f), never two uniques in one opening, always the FIRST roll" % [int(jern["wander_bp"]), pity, trials, worst_gap, total / trials, mean, z])
	# once per save: after it was found it never comes again, the record is saved
	_fresh(5)
	var found_at := 0
	for i in 40:
		var r2: Dictionary = ls.open_container("skovkant", "jern", "o:%d" % i, {"deliver": "orbs"})
		for row in r2["results"]:
			if row["id"] == item:
				found_at += 1
	var rec: Dictionary = ls.wanderers.get("skovkant", {})
	t.check("wanderer_found_only_once", found_at == 1 and (rec.get("found", []) as Array) == [item] and int((rec["misses"] as Dictionary).get("jern", 0)) == 0, "40 openings of one save give the wanderer exactly once (%d) and record it as found" % found_at)
	var elsewhere := 0
	for i in 200:
		for row in (ls.open_container("skovkant", "trae", "e:%d" % i, {"deliver": "orbs"})["results"] as Array):
			elsewhere += 1 if row["id"] == item else 0
	t.expect(elsewhere == 0, "the jern wanderer never shows up in a trae chest of the same zone, and no other zone has it")
	# a wanderer the player already owns is not offered again
	_fresh(9)
	eco.add_item(StringName(item), 1, true)
	var owned_hits := 0
	for i in 60:
		for row in (ls.open_container("skovkant", "jern", "ow:%d" % i, {"deliver": "orbs"})["results"] as Array):
			owned_hits += 1 if row["id"] == item else 0
	t.expect(owned_hits == 0, "an owned keepsake is never offered as a wanderer (60 openings)")


# ============================================================================================ respawn

func _respawn() -> void:
	var table := [["skovkant", "trae", 7], ["skovkant", "jern", 14], ["dybe_bregner", "fe", 21], ["dybe_bregner", "konge", 7], ["skovkant", "dig", 1]]
	var all_ok := true
	var report: Array[String] = []
	for row in table:
		_fresh(3)
		_day(10)
		var zone: String = row[0]
		var tier: String = row[1]
		var wait: int = row[2]
		var uid := "%s:3,4" % zone
		var first: Dictionary = ls.open_container(zone, tier, uid, {"deliver": "orbs"})
		var again: Dictionary = ls.open_container(zone, tier, uid, {"deliver": "orbs"})
		_day(10 + wait - 1)
		var almost: Dictionary = ls.open_container(zone, tier, uid, {"deliver": "orbs"})
		_day(10 + wait)
		var ready: Dictionary = ls.open_container(zone, tier, uid, {"deliver": "orbs"})
		var other: Dictionary = ls.open_container(zone, tier, zone + ":9,9", {"deliver": "orbs"})
		var ok_row: bool = bool(first["ok"]) and not bool(again["ok"]) and again["reason"] == &"cooldown" and int(again["days_left"]) == wait and not bool(almost["ok"]) and int(almost["days_left"]) == 1 and bool(ready["ok"]) and bool(other["ok"])
		all_ok = all_ok and ok_row
		report.append("%s %dd %s" % [tier, wait, "ok" if ok_row else "FAIL"])
	t.check("respawn_days", all_ok, "a container stays closed for its respawn_days and opens again on the day it is due; other cells are independent: %s" % ", ".join(report))
	# the days_left helper the handlers use, and the real flow (items arrive) on top of it
	_fresh(4)
	_day(20)
	var res: Dictionary = ls.open_container("skovkant", "trae", "skovkant:1,1")
	t.expect(bool(res["ok"]) and ls.days_left("skovkant:1,1", ls.respawn_days_of("skovkant", "trae")) == 7 and ls.respawn_days_of("skovkant", "dig") == 1 and ls.respawn_days_of("skovkant", "nope") == 1, "days_left / respawn_days_of: a crate opened today is closed for 7 days; an unknown container counts 1")
	_day(27)
	t.expect(ls.days_left("skovkant:1,1", 7) == 0, "seven days later it is ready")
	var nothing_closed: Dictionary = ls.open_container("skovkant", "no_such_tier", "x:1,1")
	t.expect(not bool(nothing_closed["ok"]) and nothing_closed["reason"] == &"unknown_container" and ls.opened.has("x:1,1") == false, "an unknown container is refused and writes nothing")


# ============================================================================================ boss

func _boss() -> void:
	_fresh(21)
	_day(10)
	var res: Dictionary = ls.on_boss_defeated("snurresvamp", {"uid": "k1"})
	var st: Dictionary = ls.boss_state.get("snurresvamp", {})
	t.expect(bool(res["ok"]) and (res["results"] as Array).is_empty() and bool(st.get("first_done", false)) and int(st["kills"]) == 1 and int(st["last_day"]) == 10, "the FIRST kill is the quest reward (snurresvampen pays): LootService delivers no chest, it records the kill")
	var again: Dictionary = ls.on_boss_defeated("snurresvamp", {"uid": "k1"})
	t.expect(bool(again["ok"]) and again["reason"] == &"already" and int(ls.boss_state["snurresvamp"]["kills"]) == 1, "the same uid asked twice (the kill and the opening of the sealed chest) changes nothing: idempotent per ctx.uid")
	var early: Dictionary = ls.on_boss_defeated("snurresvamp", {"uid": "k2"})
	_day(16)
	var six: Dictionary = ls.on_boss_defeated("snurresvamp", {"uid": "k3"})
	t.expect(early["reason"] == &"not_ready" and six["reason"] == &"not_ready" and (six["results"] as Array).is_empty(), "a repeat kill before respawn_days (7) is a pure fight: nothing is paid (day 10 and day 16)")
	_day(17)
	var veto: Dictionary = ls.on_boss_defeated("snurresvamp", {"uid": "k4", "ready": false})
	t.expect(veto["reason"] == &"not_ready", "ctx.ready = false vetoes a payment")
	var paid: Dictionary = ls.on_boss_defeated("snurresvamp", {"uid": "k5"})
	var chest_rows := 0
	var legend := 0
	for row in paid["results"]:
		if Rarity.rank(row["rarity"]) >= 5:
			legend += 1
		else:
			chest_rows += 1
	t.expect(bool(paid["ok"]) and chest_rows == 2 and legend <= 1 and int(ls.boss_state["snurresvamp"]["kills"]) == 2 and int(ls.boss_state["snurresvamp"]["last_day"]) == 17, "on day 17 (seven days later) a repeat kill pays the konge chest (2 rolls) + at most one legendary: %d rolls, %d legendary" % [chest_rows, legend])
	# the pity: legendary_bp 0 and pity_kills 3: the third paying kill is certain, then the counter starts again; an exhausted pool pays fairy_dust x3
	var cfg_pity := {"boss": {"zz_boss": {"enemy": "zz_boss", "respawn_days": 7, "chest": "konge", "legendary_bp": 0, "pity_kills": 3, "pool": ["sofa_cloud", "rug_magic_circle"], "exhausted_item": "fairy_dust", "exhausted_amount": 3}}}
	_fresh(22)
	ls.set_loot_config(_pool_cfg(["wood"], 1, "material", "normal", cfg_pity))
	var day := 10
	_day(day)
	ls.on_boss_defeated("zz_boss", {"uid": "p0"})
	var pays: Array = []
	var items: Array = []
	for k in 8:
		day += 7
		_day(day)
		var r: Dictionary = ls.on_boss_defeated("zz_boss", {"uid": "p%d" % (k + 1), "band": "zz"})
		var got := ""
		for row in r["results"]:
			if str(row["id"]) in ["sofa_cloud", "rug_magic_circle", "fairy_dust"]:
				got = str(row["id"])
		pays.append(got)
		items.append(got)
	t.check("boss_pity", pays.size() == 8 and pays[0] == "" and pays[1] == "" and pays[2] in ["sofa_cloud", "rug_magic_circle"] and pays[3] == "" and pays[4] == "" and pays[5] in ["sofa_cloud", "rug_magic_circle"] and pays[5] != pays[2] and pays[6] == "fairy_dust" and pays[7] == "fairy_dust",
		"legendary_bp 0, pity_kills 3, a pool of two: the legendary comes on the 3rd and the 6th paying kill, then the pool is empty and every kill pays fairy_dust: %s" % str(pays))
	var dust_rows: Array = []
	for row in _rolled:
		for rr in row[1]:
			if rr["id"] == "fairy_dust":
				dust_rows.append(rr["amount"])
	t.expect(dust_rows == [3, 3], "the exhausted pool pays fairy_dust x3 (%s)" % str(dust_rows))
	# the repeat-kill chest: bp 10 000 pays a legendary EVERY paying kill until the pool of four is gone
	_fresh(23)
	var real: Dictionary = ls.loot_cfg().duplicate(true)
	real["boss"]["snurresvamp"]["legendary_bp"] = 10000
	ls.set_loot_config(real)
	_day(10)
	ls.on_boss_defeated("snurresvamp", {"uid": "a0"})
	var legends: Array = []
	for k in 5:
		_day(10 + 7 * (k + 1))
		for row in ls.on_boss_defeated("snurresvamp", {"uid": "a%d" % (k + 1)})["results"]:
			if Rarity.rank(row["rarity"]) >= 5 or row["id"] == "fairy_dust":
				legends.append(row["id"])
	var pool: Array = real["boss"]["snurresvamp"]["pool"]
	var four := legends.slice(0, 4)
	four.sort()
	var pool_sorted := pool.duplicate()
	pool_sorted.sort()
	t.expect(four == pool_sorted and legends[4] == "fairy_dust", "bp 10 000: the four pool items arrive once each (%s) and the fifth kill pays the exhausted fairy_dust" % str(legends))
	# the statistics of the pity itself: never more than pity_kills kills apart, the mean matches the closed form
	var bcfg: Dictionary = {"legendary_bp": 800, "pity_kills": 10}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var gaps: Array = []
	var misses := 0
	var since := 0
	for _i in 200000:
		since += 1
		if LootRules.boss_legendary_due(bcfg, misses, rng):
			gaps.append(since)
			since = 0
			misses = 0
		else:
			misses += 1
	var maxg := 0
	var sum := 0.0
	for g in gaps:
		maxg = maxi(maxg, int(g))
		sum += float(g)
	var pb := 0.08
	var expect_mean := (1.0 - pow(1.0 - pb, 10)) / pb
	var ex2 := 0.0
	for k in range(1, 10):
		ex2 += float(k * k) * pow(1.0 - pb, k - 1) * pb
	ex2 += 100.0 * pow(1.0 - pb, 9)
	var sdg := sqrt(ex2 - expect_mean * expect_mean)
	var zg := (sum / gaps.size() - expect_mean) / (sdg / sqrt(float(gaps.size())))
	t.expect(maxg <= 10 and absf(zg) < 3.0, "8 %% per kill with pity 10 (200 000 kills): never more than %d kills without a legendary, mean %.3f vs closed form %.3f (z %.2f)" % [maxg, sum / gaps.size(), expect_mean, zg])


# ============================================================================================ spots

func _spots() -> void:
	_fresh(31)
	_day(13)
	var locked: Dictionary = ls.claim_spot("fuglehuset")
	t.expect(ls.spot_state("fuglehuset") == &"locked" and not bool(locked["ok"]) and locked["reason"] == &"locked", "fuglehuset needs day 14: locked on day 13")
	_day(14)
	t.expect(ls.spot_state("fuglehuset") == &"open", "...open on day 14")
	var got: Dictionary = ls.claim_spot("fuglehuset", {"uid": "farm:5,5"})
	var again: Dictionary = ls.claim_spot("fuglehuset")
	var row: Dictionary = (got["results"] as Array)[0] if not (got["results"] as Array).is_empty() else {}
	t.expect(bool(got["ok"]) and row.get("id", "") == "shelf_birdhouse" and eco.count_item(&"shelf_birdhouse") >= 1 and ls.found("shelf_birdhouse") and ls.spot_state("fuglehuset") == &"claimed", "claimed once: the birdhouse shelf is delivered, the spot is claimed and the keepsake is in the registry")
	t.expect(not bool(again["ok"]) and again["reason"] == &"claimed" and eco.count_item(&"shelf_birdhouse") == 1, "a spot is ONE time: the second claim gives nothing")
	# home tier, quests, day gates of the other spots
	gm.set_flag(&"home_tier", 2)
	var tier2: StringName = ls.spot_state("trae_hulning")
	gm.set_flag(&"home_tier", 3)
	var tier3: StringName = ls.spot_state("trae_hulning")
	t.expect(tier2 == &"locked" and tier3 == &"open", "trae_hulning needs home tier 3: locked at tier 2, open at tier 3")
	t.expect(ls.spot_state("mis_hjoerne") == &"locked" and ls.spot_state("runealteret") == &"locked", "mis_hjoerne wants the quest lost_cat, runealteret the quest moonstone_crown")
	qm.completed_quests.append(&"lost_cat")
	t.expect(ls.spot_state("mis_hjoerne") == &"open" and ls.spot_state("runealteret") == &"locked", "...lost_cat done opens mis_hjoerne only")
	qm.completed_quests.append(&"moonstone_crown")
	t.expect(ls.spot_state("runealteret") == &"open", "...moonstone_crown done opens the altar")
	_day(14)
	t.expect(ls.spot_state("kufferten") == &"locked", "kufferten (the only find of Hyggebyen) needs day 15")
	_day(15)
	var k: Dictionary = ls.claim_spot("kufferten")
	t.expect(bool(k["ok"]) and (k["results"] as Array)[0]["id"] == "shoes_slippers_pompom" and ls.spot_state("kufferten") == &"claimed", "...and gives the pompom slippers on day 15")
	var free: Dictionary = ls.claim_spot("svampering")
	t.expect(bool(free["ok"]) and ls.spot_state("svampering") == &"claimed", "a spot without `requires` is open from the start")
	t.expect(not bool(ls.claim_spot("no_such_spot")["ok"]) and ls.claim_spot("no_such_spot")["reason"] == &"unknown_spot", "an unknown spot is refused")
	t.check("spots_one_time_and_conditions", ls.claimed.has("fuglehuset") and ls.claimed.has("kufferten") and ls.claimed.has("svampering") and not ls.claimed.has("trae_hulning"), "claimed table: %s" % str(ls.claimed.keys()))
	# requires.items + consume: the three rune shards of the vault (fake data), taken in the SAME transaction as the delivery
	_fresh(32)
	var spots := {"spots": {"zz_vault": {"zone": "zz", "item": "gem_bag", "name_key": "FIND_SPOT_X", "hint_key": "ITEM_BED_TOADSTOOL_HINT", "once": true, "requires": {"items": {"moss": 2, "stone": 1}}, "consume": true}}}
	ls.set_loot_config(_pool_cfg(["wood"], 1, "material", "normal", spots))
	var lacking: StringName = ls.spot_state("zz_vault")
	eco.add_item(&"moss", 2, true)
	var half: StringName = ls.spot_state("zz_vault")
	eco.add_item(&"stone", 1, true)
	var moss_before: int = eco.count_item(&"moss")
	var vault: Dictionary = ls.claim_spot("zz_vault")
	t.expect(lacking == &"locked" and half == &"locked" and bool(vault["ok"]) and eco.count_item(&"moss") == 0 and eco.count_item(&"stone") == 0 and eco.count_item(&"gem_bag") == 1 and moss_before == 2, "requires.items + consume: locked while one item is missing, then the claim takes exactly the required items and delivers the keepsake")
	t.expect(ls.missing_items("zz_vault").size() == 2, "missing_items lists what the vault still lacks once the items are gone (moss, stone)")


# ============================================================================================ gifts, capstones

func _gifts_and_capstones() -> void:
	_fresh(41)
	gm.set_flag(&"friend_guard_oak", 3)
	var none: Dictionary = ls.check_friend_gifts("guard_oak")
	gm.set_flag(&"friend_guard_oak", 4)
	var one: Dictionary = ls.check_friend_gifts("guard_oak")
	var two: Dictionary = ls.check_friend_gifts("guard_oak")
	t.check("check_friend_gifts_idempotent", (none["results"] as Array).is_empty() and (one["results"] as Array).size() == 1 and (one["results"] as Array)[0]["id"] == "table_stump" and (two["results"] as Array).is_empty() and eco.count_item(&"table_stump") == 1 and ls.claimed.has("guard_oak:4"),
		"guard_oak: 3 hearts give nothing, 4 hearts give the stump table once (row keyed guard_oak:4 in claimed), a second call grants nothing")
	gm.set_flag(&"friend_fairy_lily", 6)
	var lily: Dictionary = ls.check_friend_gifts("fairy_lily")
	var ids: Array = []
	for row in lily["results"]:
		ids.append(row["id"])
	ids.sort()
	t.expect(ids == ["dress_sun_meadow", "sofa_leaf"] and ls.check_friend_gifts("fairy_lily")["results"] == [] and not bool(ls.check_friend_gifts("nobody")["results"].size() > 0), "fairy_lily at 6 hearts: both gifts (3 and 6 hearts) arrive once; an unknown friend has none")
	# the round trip keeps the claimed gift keys
	var d: Dictionary = JSON.parse_string(JSON.stringify(ls.to_dict()))
	ls.reset()
	ls.from_dict(d)
	t.expect(ls.claimed.has("guard_oak:4") and ls.check_friend_gifts("guard_oak")["results"] == [], "the claimed gift keys survive a save and a load (no second table stump)")
	# the capstone
	_fresh(42)
	t.expect(not ls.set_capstone_granted("marken"), "set_capstone_granted is false before the capstone was granted")
	var cap: Dictionary = ls.grant_set_capstone("marken")
	var cap2: Dictionary = ls.grant_set_capstone("marken")
	t.check("set_capstone_granted_reads_the_record", ls.set_capstone_granted("marken") and (cap["results"] as Array)[0]["id"] == "shirt_knit_dawn" and (cap2["results"] as Array).is_empty() and eco.count_item(&"shirt_knit_dawn") == 1 and ls.claimed.has("set:marken") and not ls.set_capstone_granted("fe_festen") and not bool(ls.grant_set_capstone("no_such_set")["ok"]),
		"marken capstone: shirt_knit_dawn once (idempotent), set_capstone_granted reads the record written by grant_set_capstone, other sets stay open")


# ============================================================================================ duplicates

func _duplicates() -> void:
	_fresh(51)
	var wardrobe := FakeStore.new()
	Svc.override("WardrobeManager", wardrobe)
	var garment := "shirt_linen_cream"
	t.expect(eco.add_item(StringName(garment), 1, true) and not eco.add_item(StringName(garment), 1, true), "the garment store refuses a second copy (max_stack 1): the premise of the duplicate policy")
	var gold_before: int = eco.gold
	var sell: int = eco.sell_value(StringName(garment))
	_whispers.clear()
	var res: Dictionary = ls.deliver(garment, 1)
	var shown := TranslationServer.translate(str(ItemKinds.def(garment).get("name_key", "")))
	var want: String = TranslationServer.translate("FIND_UI_DUPLICATE_FMT") % [shown, sell]
	t.check("duplicate_garment_sold", bool(res["ok"]) and bool(res["sold"]) and eco.gold == gold_before + sell and sell > 0 and eco.count_item(StringName(garment)) == 1 and _whispers.has(want),
		"a garment already owned is SOLD at once at its sell value (+%d gold) and the whisper says so: %s" % [sell, want])
	# through a container: the roll counts as found for loot_rolled, the pile of gold is reported in `sold`
	var cfg := _pool_cfg([garment], 1, "clothing", "normal")
	ls.set_loot_config(cfg)
	_rolled.clear()
	var open: Dictionary = ls.open_container("zz", "trae", "zz:1,1")
	t.expect(bool(open["ok"]) and (open["results"] as Array).size() == 1 and (open["sold"] as Array).size() == 1 and int(open["sold"][0]["gold"]) == sell and _rolled.size() == 1 and _rolled[0][1][0]["id"] == garment and ls.opened.has("zz:1,1"),
		"the duplicate from a chest: result row and loot_rolled still list it, `sold` carries the gold, the chest counts as opened")
	# furniture at its 9th copy
	Svc.clear_overrides()
	var furn := FakeFurnitureManager.new(1)
	Svc.override("FurnitureManager", furn)
	var chair := "chair_pine"
	var nine := true
	for _i in 9:
		nine = nine and eco.add_item(StringName(chair), 1, true)
	var gold2: int = eco.gold
	var r2: Dictionary = ls.deliver(chair, 1)
	t.expect(nine and bool(r2["ok"]) and bool(r2["sold"]) and eco.gold == gold2 + eco.sell_value(StringName(chair)) and furn.count_total(chair) == 9, "furniture at its 9th copy is sold at once too (nothing is lost, nothing is added)")
	# the kinds are DATA: with only clothing listed a furniture copy is not sold
	var narrow := _pool_cfg(["wood"])
	narrow["duplicates"] = {"kinds": ["clothing"], "action": "sell"}
	ls.set_loot_config(narrow)
	var r3: Dictionary = ls.deliver(chair, 1)
	t.expect(not bool(r3["ok"]) and not bool(r3["sold"]) and r3["reason"] == &"refused" and eco.gold == gold2 + eco.sell_value(StringName(chair)), "loot.duplicates.kinds is read from the data: furniture is not listed, so it is refused, not sold")
	ls.set_loot_config(null)
	# a material with a full backpack is NOT sold: it stays where it is
	Svc.clear_overrides()
	_fresh(52)
	_fill_backpack(["copper_ore"])
	var gold3: int = eco.gold
	var r4: Dictionary = ls.deliver("copper_ore", 1)
	t.expect(eco.free_slots() == 0 and not bool(r4["sold"]) and eco.gold == gold3, "a material that does not fit a full backpack is neither added nor sold (%s)" % str(r4))
	var bad: Dictionary = ls.deliver("", 1)
	t.expect(not bool(bad["ok"]) and bad["reason"] == &"invalid" and not bool(ls.deliver("wood", 0)["ok"]), "deliver validates its arguments")
	Svc.clear_overrides()
	wardrobe.free()
	furn.free()


# ============================================================================================ two-phase and the backpack

func _full_backpack() -> void:
	_fresh(60)
	ls.set_loot_config(_pool_cfg(["wood"], 3, "material", "normal"))
	var wood_before: int = eco.count_item(&"wood")
	var observations: Array = []
	var reentry: Array = []
	var on_gain := func(_id: StringName, _amount: int) -> void:
		observations.append(ls.opened.has("zz:atomic") and eco.count_item(&"wood") == wood_before + 3)
		reentry.append(ls.open_container("zz", "trae", "zz:atomic")["ok"])
	bus.item_gained.connect(on_gain)
	var atomic: Dictionary = ls.open_container("zz", "trae", "zz:atomic")
	bus.item_gained.disconnect(on_gain)
	t.check("loot_commits_before_gain_observers", bool(atomic["ok"]) and observations == [true, true, true] and reentry == [false, false, false] and eco.count_item(&"wood") == wood_before + 3,
		"each gain observer sees all three rolls and the opened record; re-entering the same chest is refused")
	_fresh(61)
	var cfg := _pool_cfg(["iron_sword"], 3, "material", "normal")
	ls.set_loot_config(cfg)
	_fill_backpack()
	_free_slots_to(2)
	t.expect(eco.free_slots() == 2, "premise: the backpack has exactly two free slots")
	var inv_before := _inventory_snapshot()
	var state_before: int = ls.rng.state
	_toasts.clear()
	_rolled.clear()
	var res: Dictionary = ls.open_container("zz", "trae", "zz:2,2")
	t.check("multi_roll_full_backpack_changes_nothing", not bool(res["ok"]) and res["reason"] == &"full" and (res["results"] as Array).is_empty() and _inventory_snapshot() == inv_before and ls.opened.is_empty() and ls.rng.state == state_before and _rolled.is_empty() and _toasts.has("inventory"),
		"3 rolls of an item that takes a slot each, 2 free slots: {ok = false, reason = full, results = []}, NOTHING delivered (the first two rolls are not kept), no opened entry, the stream is where it was, the inventory-full notice came")
	var same_results := true
	var first_try := ""
	for i in 1000:
		var again: Dictionary = ls.open_container("zz", "trae", "zz:2,2")
		same_results = same_results and not bool(again["ok"]) and again["reason"] == &"full"
		if i == 0:
			first_try = _inventory_snapshot()
	t.expect(same_results and _inventory_snapshot() == inv_before and first_try == inv_before and ls.rng.state == state_before and ls.opened.is_empty(), "1 000 retries on the full pack deliver nothing and change no state (no retry faucet, no re-roll)")
	_free_slots_to(3)
	var ok_res: Dictionary = ls.open_container("zz", "trae", "zz:2,2")
	t.expect(bool(ok_res["ok"]) and (ok_res["results"] as Array).size() == 3 and eco.count_item(&"iron_sword") == 3 and ls.opened.has("zz:2,2"), "with three free slots the same chest opens and delivers all three rolls TOGETHER")
	# a single full roll: the container stays closed, the existing notice is posted
	_fresh(62)
	ls.set_loot_config(_pool_cfg(["wood"], 1, "material", "normal"))
	_fill_backpack(["wood"])
	_toasts.clear()
	var inv2 := _inventory_snapshot()
	var full: Dictionary = ls.open_container("zz", "trae", "zz:3,3")
	t.expect(eco.free_slots() == 0 and not bool(full["ok"]) and full["reason"] == &"full" and ls.opened.is_empty() and _inventory_snapshot() == inv2 and _toasts.has("inventory"), "a material roll that cannot enter a full backpack leaves the chest closed with the existing inventory-full notice")
	# own-store kinds always fit: with real stores present a full backpack does not stop a garment
	_fresh(63)
	var wardrobe := FakeStore.new()
	wardrobe.cap = 5
	Svc.override("WardrobeManager", wardrobe)
	ls.set_loot_config(_pool_cfg(["shirt_linen_cream"], 1, "clothing", "normal"))
	_fill_backpack()
	var garment: Dictionary = ls.open_container("zz", "trae", "zz:4,4")
	t.expect(eco.free_slots() == 0 and bool(garment["ok"]) and wardrobe.count_total("shirt_linen_cream") == 1, "clothing and furniture have their own stores: a full backpack does not stop them")
	Svc.clear_overrides()
	wardrobe.free()
	# the API shape of the dungeon amendment: every answer {ok, results, reason}; ctx keys are accepted; ctx.odds is ignored
	_fresh(64)
	var ctx_all := {"dungeon": true, "floor": 3, "band": "skovkant", "rng": RandomNumberGenerator.new(), "luck": 0.1, "lock_ok": true, "first_kill": true, "ready": true, "uid": "dg:1:3:7", "deliver": "orbs", "odds": {"legendary": 10000}}
	var shapes_ok := true
	for answer in [ls.open_container("skovkant", "trae", "dg:1:3:7", ctx_all), ls.dig("skovkant", "dg:1:3:8", ctx_all), ls.node_loot("crystal", "dg:1:3:9", ctx_all), ls.on_enemy_defeated("bat", ctx_all),
			ls.on_boss_defeated("snurresvamp", ctx_all), ls.claim_spot("svampering", ctx_all), ls.check_friend_gifts("guard_oak"), ls.grant_set_capstone("marken")]:
		shapes_ok = shapes_ok and answer.has("ok") and answer.has("results") and answer.has("reason") and typeof(answer["ok"]) == TYPE_BOOL and typeof(answer["results"]) == TYPE_ARRAY and typeof(answer["reason"]) == TYPE_STRING_NAME
	var sigs_ok := true
	for spec in [["open_container", 4], ["dig", 3], ["node_loot", 3], ["on_enemy_defeated", 2], ["on_boss_defeated", 2], ["claim_spot", 2], ["spot_state", 1], ["appraisal_quote", 1], ["appraise", 2], ["found", 1], ["deliver", 2], ["day_value", 0], ["daily_cap_reached", 0], ["set_seed", 1]]:
		var found_m := false
		for m in ls.get_method_list():
			if str(m["name"]) == spec[0]:
				found_m = true
				sigs_ok = sigs_ok and (m["args"] as Array).size() == int(spec[1])
		sigs_ok = sigs_ok and found_m
	var full_pack := _pool_cfg(["wood", "stone", "moss"], 1, "material", "normal")
	ls.set_loot_config(full_pack)
	_fill_backpack(["wood", "stone", "moss"])
	var dg_full: Dictionary = ls.open_container("zz", "trae", "dg:1:3:11", {"dungeon": true, "band": "zz"})
	t.check("dungeon_ctx_signatures_and_full_backpack", shapes_ok and sigs_ok and not bool(dg_full["ok"]) and dg_full["reason"] == &"full" and (dg_full["results"] as Array).is_empty() and ls.opened.is_empty(),
		"every call answers {ok: bool, results: Array, reason: StringName}, the 14 API signatures match the contract, ctx with every key (and ctx.odds) is accepted, a dungeon chest on a full pack answers {false, [], full}")
	t.expect(ls.day_value() == 0 and not ls.daily_cap_reached() and not ls.found("wood") and not bool(ls.node_loot("crystal", "dg:1:3:12", {})["ok"]) and ls.node_loot("crystal", "dg:1:3:12", {})["reason"] == &"no_rules" and ls.appraisal_quote("rough_skovkant")["fee"] == 0 and not bool(ls.appraise("rough_skovkant")["ok"]), "without the dungeon rules (DL5): no day value, node_loot / appraise answer no_rules, honestly")


# ============================================================================================ save

func _save() -> void:
	_fresh(71)
	var big := 0x7fffffffffffffff - 12345
	ls.set_seed(big)
	for _i in 7:
		ls.rng.randi()
	_day(33)
	ls.open_container("skovkant", "trae", "skovkant:5,5", {"deliver": "orbs"})
	ls.claim_spot("svampering")
	ls.on_boss_defeated("snurresvamp", {"uid": "s1"})
	var d: Dictionary = ls.to_dict()
	var seed_text := str(d["rng"]["seed"])
	var state_text := str(d["rng"]["state"])
	t.check("save_roundtrip_rng_strings", typeof(d["rng"]["seed"]) == TYPE_STRING and typeof(d["rng"]["state"]) == TYPE_STRING and seed_text == str(ls.rng.seed) and state_text == str(ls.rng.state) and big > 9007199254740992 and int(d["v"]) == 1,
		"seed and state are saved as DECIMAL STRINGS (seed %s is above 2^53), the section carries v 1" % seed_text)
	var json: Variant = JSON.parse_string(JSON.stringify(d))
	var want: Array = []
	for _i in 5:
		want.append(ls.rng.randi())
	ls.reset()
	t.expect(ls.from_dict(json as Dictionary) and str(ls.rng.seed) == seed_text and str(ls.rng.state) == state_text, "after the JSON round trip the stream is at the same seed and state (no 2^53 loss)")
	var got: Array = []
	for _i in 5:
		got.append(ls.rng.randi())
	t.expect(got == want, "save -> load -> roll gives the SAME next numbers (no save-scumming a chest by reloading)")
	t.expect(int(ls.opened["skovkant:5,5"]) == 33 and ls.claimed.has("svampering") and ls.boss_state["snurresvamp"]["first_done"] == true and int(ls.boss_state["snurresvamp"]["kills"]) == 1, "opened{uid: total_day}, claimed spots and the boss counters survive the JSON round trip as ints")
	t.expect(not ls.from_dict({"v": 2}) and not ls.from_dict({"v": 1, "opened": []}) and not ls.validate_dict({"boss": 3}) and ls.validate_dict({"v": 1}) and ls.validate_dict(json as Dictionary), "from_dict / validate_dict reject a newer version and a section of the wrong shape, accept a good one")
	t.expect(sm.has_section("loot") and sm.registered_section_names().has("loot"), "the section `loot` is registered with SaveManager")
	var order := -1
	for entry in sm._sections:
		if entry["name"] == "loot":
			order = int(entry["order"])
	t.expect(order == 40 and sm.FEATURE_ORDERS["loot"] == 40, "...at order 40 (FEATURE_ORDERS)")
	var payload: Dictionary = sm.gather_payload()
	t.expect(payload.has("loot") and bool(sm.validate_payload(payload)["ok"]) and typeof((payload["loot"] as Dictionary)["rng"]["seed"]) == TYPE_STRING, "gather_payload carries the loot section and the payload validates")
	# a real save and load through SaveManager
	var saved: bool = sm.save_game(4)
	ls.reset()
	var loaded: bool = sm.load_game(4)
	t.expect(saved and loaded and ls.opened.has("skovkant:5,5") and str(ls.rng.seed) == seed_text, "save_game(4) -> reset -> load_game(4) restores the section")
	sm.delete_save(4)
	# a new game wipes it
	Fresh.new_game(t)
	t.expect(ls.opened.is_empty() and ls.claimed.is_empty() and ls.boss_state.is_empty() and ls.dungeon.is_empty() and str(ls.rng.seed) != seed_text, "a new game resets everything and reseeds")
	# the dungeon sub-dict is optional
	_fresh(72)
	var no_sub: Dictionary = ls.to_dict()
	var with_sub := {"v": 1, "dungeon": {"found": {"wpn_sword_moon": 12}, "claimed": ["soeskatten_skov"], "day": {"day": 5, "value": 900, "capped": false}, "future_key": [1, 2]}}
	ls.from_dict(JSON.parse_string(JSON.stringify(with_sub)))
	var round2: Dictionary = JSON.parse_string(JSON.stringify(ls.to_dict()))
	var found_ok: bool = ls.found("wpn_sword_moon") and not ls.found("wood")
	ls.from_dict(no_sub)
	t.check("save_roundtrip_dungeon_subdict_optional", not no_sub.has("dungeon") and found_ok and (round2["dungeon"]["found"] as Dictionary).has("wpn_sword_moon") and (round2["dungeon"] as Dictionary).has("future_key") and ls.dungeon.is_empty(),
		"a section without `dungeon` is valid and leaves it empty; a section with it round-trips (found registry, claimed, day record, unknown keys kept); loading one without it afterwards clears it")
	t.expect(ls.found("wpn_sword_moon") == false and ls.day_value() == 0, "found() and day_value() read the sub-dict (empty after the load without it)")
	var delta_day := {"v": 1, "dungeon": {"day": {"day": 5, "value": 900, "capped": true}}}
	ls.from_dict(delta_day)
	_day(5)
	t.expect(ls.day_value() == 900 and ls.daily_cap_reached(), "day_value() / daily_cap_reached() read dungeon.day for TODAY only")
	_day(6)
	t.expect(ls.day_value() == 0 and not ls.daily_cap_reached(), "...and are 0 / false the next day")
	# boss table keyed by id: each row of the table behaves by its OWN numbers
	_fresh(73)
	var two := {"boss": {
		"boss_a": {"enemy": "boss_a", "respawn_days": 7, "chest": "konge", "legendary_bp": 10000, "pity_kills": 0, "pool": ["sofa_cloud"], "first_kill_items": ["moss"], "exhausted_item": "stone", "exhausted_amount": 2},
		"boss_b": {"enemy": "boss_b", "respawn_days": 3, "chest": "konge", "legendary_bp": 0, "pity_kills": 0, "pool": ["rug_magic_circle"], "exhausted_item": "wood", "exhausted_amount": 1}}}
	ls.set_loot_config(_pool_cfg(["wood"], 1, "material", "normal", two))
	_day(10)
	var a1: Dictionary = ls.on_boss_defeated("boss_a", {"uid": "a1"})
	var b1: Dictionary = ls.on_boss_defeated("boss_b", {"uid": "b1"})
	var a_items: Array = []
	for row in a1["results"]:
		a_items.append(row["id"])
	t.expect(a_items == ["moss"] and (b1["results"] as Array).is_empty(), "first_kill_items is read per boss id: boss_a delivers its moss at the first kill, boss_b has none")
	_day(13)
	var b2: Dictionary = ls.on_boss_defeated("boss_b", {"uid": "b2", "band": "zz"})
	var a2: Dictionary = ls.on_boss_defeated("boss_a", {"uid": "a2", "band": "zz"})
	var a2_ids: Array = []
	for row in a2["results"]:
		a2_ids.append(row["id"])
	t.check("boss_table_keyed_by_id", bool(b2["ok"]) and b2["reason"] != &"not_ready" and a2["reason"] == &"not_ready" and a2_ids.is_empty(), "boss_b (respawn 3 days) pays on day 13, boss_a (7 days) does not: every row of loot.boss is read by its id (boss_b %s, boss_a %s)" % [str(b2["reason"]) if str(b2["reason"]) != "" else "paid", str(a2["reason"])])
	_day(17)
	var a3: Dictionary = ls.on_boss_defeated("boss_a", {"uid": "a3", "band": "zz"})
	var got_legend := false
	for row in a3["results"]:
		got_legend = got_legend or row["id"] == "sofa_cloud"
	_day(24)
	var a4: Dictionary = ls.on_boss_defeated("boss_a", {"uid": "a4", "band": "zz"})
	var exhausted := false
	for row in a4["results"]:
		exhausted = exhausted or (row["id"] == "stone" and int(row["amount"]) == 2)
	t.expect(got_legend and exhausted, "legendary_bp 10 000 pays the pool item, then boss_a's own exhausted_item (stone x2) - not another boss's")


# ============================================================================================ handlers on the fixture map

const MARKER_MAP_EXTRA := "@marker K chest tier=trae\n@marker D dig_spot\n@marker U unique_spot id=fuglehuset\n@marker V unique_spot id=svampering when=flag:f4_glimmer_visible\n"


## the text of data/maps/_fixture_iso.map with the three markers added: K (chest) at (7,7), D (dig_spot) at (8,7), U (unique_spot) at (4,7), V (unique_spot behind when=) at (1,7)
func _fixture_text() -> String:
	var text := FileAccess.get_file_as_string("res://data/maps/_fixture_iso.map")
	text = text.replace("@ground\n", MARKER_MAP_EXTRA + "@ground\n")
	var parts := text.split("@objects\n")
	var rows := parts[1].split("\n")
	var row7: String = rows[7]
	row7 = row7.substr(0, 1) + "V" + row7.substr(2, 2) + "U" + row7.substr(5, 2) + "KD" + row7.substr(9)
	rows[7] = row7
	return parts[0] + "@objects\n" + "\n".join(rows)


## t.expect that also feeds the named check of the group: markers_open_claim_respawn is green only when EVERY step of the handler walk-through was
func _g(cond: Variant, label: Variant) -> void:
	var good: bool = t.expect(cond, label)
	_group_ok = _group_ok and good


func _markers_fixture() -> void:
	_group_ok = true
	_fresh(81)
	_day(3)
	IsoArea.clear_handler_cache()
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	var map: AreaMap = AreaMap.parse_text(_fixture_text(), "res://data/maps/_fixture_iso.map")
	area.setup(map)
	var chest: LootChest2D = _node_of(area, "chest") as LootChest2D
	var dig: DigSpot2D = _node_of(area, "dig_spot") as DigSpot2D
	var spot: UniqueSpot2D = _node_of(area, "unique_spot", "fuglehuset") as UniqueSpot2D
	var hidden_spot: UniqueSpot2D = _node_of(area, "unique_spot", "svampering") as UniqueSpot2D
	_g(chest != null and dig != null and spot != null and hidden_spot != null and not area.skipped_markers.has("chest") and not area.skipped_markers.has("dig_spot") and not area.skipped_markers.has("unique_spot"), "the fixture map: chest, dig_spot and both unique_spot markers are built by the F4 handlers (nothing skipped)")
	if chest == null or dig == null or spot == null:
		t.check("markers_open_claim_respawn", false, "the three handlers did not build their nodes on the fixture map (chest %s, dig_spot %s, unique_spot %s)" % [str(chest), str(dig), str(spot)])
		holder.queue_free()
		return
	var player := PlayerStub2D.new()
	holder.add_child(player)
	player.global_position = chest.global_position + Vector2(40, 0)
	# the chest
	var uid := LootRules.container_uid("_fixture_iso", Vector2i(7, 7))
	_g(chest.uid == uid and chest.zone == "_fixture_iso" and chest.tier == "trae" and chest.is_closed() and chest.prompt_key == "LOOT_PROMPT_OPEN" and chest.get_interaction_prompt() != "" and chest.is_in_group("interactable"), "the chest knows its uid (area id : cell), zone and tier, offers a prompt and is an Interactable2D")
	ls.set_loot_config(_pool_cfg(["wood"], 1, "material", "normal", {}, ["_fixture_iso"]))
	_rolled.clear()
	chest.interact(player)
	_g(ls.opened.has(uid) and int(ls.opened[uid]) == 3 and chest.is_open and _rolled.size() == 1 and eco.count_item(&"wood") >= 1 and is_equal_approx(chest._sprite.modulate.r, 0.55) and chest.get_interaction_prompt() == "" and _whispers.size() > 0,
		"E opens it: LootService.open_container(area id, tier, uid) delivers, the sprite is DARKENED (0.55), the prompt goes, the find is whispered")
	var wood_after: int = eco.count_item(&"wood")
	_whispers.clear()
	chest.interact(player)
	_g(eco.count_item(&"wood") == wood_after and _whispers.has("LOOT_CHEST_RESTING"), "E on the spent chest gives nothing and says it fills again in a few days")
	_day(9)
	bus.day_started.emit(gm.day, gm.season)
	_g(chest.is_open, "six days later it is still dark (respawn_days 7)")
	_day(10)
	bus.day_started.emit(gm.day, gm.season)
	_g(not chest.is_open and is_equal_approx(chest._sprite.modulate.r, 1.0) and chest.get_interaction_prompt() != "", "on day 10 (7 days later) the chest has respawned: bright again, E works")
	chest.interact(player)
	_g(chest.is_open and int(ls.opened[uid]) == 10, "...and opens a second time")
	# a PARKED iso area (removed from the tree, back later: no second _ready) keeps its handlers alive: signals are re-connected on entry and the state is read again at once
	holder.remove_child(area)
	_day(16)
	var stale_while_parked: bool = chest.is_open
	_day(17)
	holder.add_child(area)
	_g(stale_while_parked and not chest.is_open and bus.day_started.is_connected(chest._on_day_started), "an area that was parked for seven days shows its chest respawned the moment it re-enters the tree (state re-read in _enter_tree, signals connected again)")
	chest.interact(player)
	# the dig spot
	_day(11)
	player.stamina = 3.0
	_whispers.clear()
	dig.interact(player)
	var duid := dig.uid
	_g(not ls.opened.has(duid) and _whispers.has("LOOT_TOO_TIRED") and is_equal_approx(player.stamina, 3.0), "a player with 3 stamina cannot dig: whisper LOOT_TOO_TIRED, nothing opened, nothing paid")
	player.stamina = 50.0
	ls.set_loot_config(_pool_cfg(["wood"], 1, "material", "normal", {}, ["_fixture_iso"]))
	dig.interact(player)
	_g(ls.opened.has(duid) and is_equal_approx(player.stamina, 46.0) and dig.spent and dig.prompt_key == "" and not dig._glimmer.visible, "E digs: 4 stamina (50 -> 46), LootService.dig(area id, uid), the shimmer is gone for today")
	_whispers.clear()
	dig.interact(player)
	_g(_whispers.has("LOOT_DIG_RESTING") and is_equal_approx(player.stamina, 46.0), "a second dig the same day only says it is spent (no stamina paid)")
	_day(12)
	bus.day_started.emit(gm.day, gm.season)
	_g(not dig.spent and dig._glimmer.visible and dig.prompt_key == "LOOT_PROMPT_DIG", "respawn daily: the next morning the soil shimmers again")
	# the unique spot: locked glimmer -> hint once per visit -> day 14 -> claim (the real data again)
	ls.set_loot_config(null)
	_day(12)
	spot.refresh()
	player.global_position = spot.global_position
	_whispers.clear()
	var first_hint := spot.check_hint()
	var second_hint := spot.check_hint()
	_g(spot.state == &"locked" and first_hint and not second_hint and _whispers == ["ITEM_SHELF_BIRDHOUSE_HINT"], "fuglehuset is locked on day 12: standing at the glimmer whispers its hint_key ONCE (%s)" % str(_whispers))
	bus.area_changed.emit(&"hyggebyen")
	_whispers.clear()
	var third_hint := spot.check_hint()
	_g(third_hint and _whispers == ["ITEM_SHELF_BIRDHOUSE_HINT"], "a new visit (area_changed) allows the hint again")
	_whispers.clear()
	spot.interact(player)
	_g(_whispers == ["ITEM_SHELF_BIRDHOUSE_HINT"] and not ls.claimed.has("fuglehuset"), "E on a locked spot repeats the hint and claims nothing")
	_day(14)
	spot.refresh()
	spot.interact(player)
	_g(ls.claimed.has("fuglehuset") and eco.count_item(&"shelf_birdhouse") == 1 and spot.claimed and not spot._glimmer.visible and spot.prompt_key == "", "day 14: E claims it ONCE: the keepsake arrives and the glimmer is gone")
	var before_second: int = eco.count_item(&"shelf_birdhouse")
	spot.interact(player)
	_g(eco.count_item(&"shelf_birdhouse") == before_second, "a claimed spot does nothing a second time")
	# `when=` is honoured through IsoArea
	_g(not hidden_spot.is_enabled() and not hidden_spot.visible, "a unique_spot behind when=flag:... is hidden and disabled until the flag is set")
	gm.set_flag(&"f4_glimmer_visible", true)
	area.refresh_when()
	_g(hidden_spot.is_enabled() and hidden_spot.visible, "...and shows once the flag is set")
	gm.set_flag(&"f4_glimmer_visible", null)
	t.check("markers_open_claim_respawn", _group_ok, "handlers on the fixture map: chest opens / darkens / respawns, dig costs stamina and rests, unique spot hints once per visit and claims once, `when=` is obeyed")
	holder.queue_free()
	await t.frames(2)
	ls.set_loot_config(null)


func _node_of(area: IsoArea, type: String, spot_id: String = "") -> Node:
	for rec in area.find_markers(type):
		if spot_id == "" or str((rec["params"] as Dictionary).get("id", "")) == spot_id:
			return rec["node"]
	return null


# ============================================================================================ marker_handlers.lua

const EXPECTED_ROWS := {
	"chest": "res://scripts/world2d/loot_chest_2d.gd", "dig_spot": "res://scripts/world2d/dig_spot_2d.gd", "unique_spot": "res://scripts/world2d/unique_spot_2d.gd",
	"home": "res://scripts/home/home_exterior_2d.gd", "tent": "res://scripts/home/tent_2d.gd",
	"runestone": "res://scripts/dungeon/markers/runestone_2d.gd", "forest_dress": "res://scripts/forest_look/forest_dress.gd", "hulen_keeper": "res://scripts/forest_look/hulen_keeper.gd",
	"mailbox": "res://scripts/traetoppen/life/post_box_2d.gd",
	"secret_garden": "res://scripts/world2d/story/secret_garden_marker.gd",
	"shipping_bin": "res://scripts/farm/steading/objects/shipping_bin_2d.gd", "tool_shed": "res://scripts/farm/steading/objects/tool_shed_2d.gd", "field_expansion": "res://scripts/farm/steading/objects/field_expansion_2d.gd",
	"underdeck": "res://scripts/farm/steading/objects/underdeck_2d.gd", "ambient_fx": "res://scripts/farm/steading/objects/ambient_fx_2d.gd", "dress": "res://scripts/farm/steading/dress/dress_2d.gd",
	"town": "res://scripts/towns/town_marker.gd", "door": "res://scripts/towns/town_marker.gd", "post": "res://scripts/towns/town_marker.gd",
	"bath": "res://scripts/traetoppen/life/bath_tub_2d.gd", "board": "res://scripts/traetoppen/life/notice_board_2d.gd",
	"seed_basket": "res://scripts/traetoppen/life/seed_basket_2d.gd", "kiki_cache": "res://scripts/traetoppen/life/crown_cache_2d.gd", "rejsestolpe": "res://scripts/traetoppen/life/rejsestolpe_2d.gd",
}


func _marker_registry() -> void:
	IsoArea.clear_handler_cache()
	var rows: Dictionary = GameData.marker_handlers()
	var reg: Dictionary = IsoArea.marker_registry()
	var all_there := true
	var wrong: Array[String] = []
	for type in EXPECTED_ROWS:
		if str(rows.get(type, "")) != EXPECTED_ROWS[type] or str((reg.get(type, {}) as Dictionary).get("script", "")) != EXPECTED_ROWS[type]:
			all_there = false
			wrong.append(str(type))
	t.check("marker_handlers_registered", all_there and rows.size() == EXPECTED_ROWS.size(), "lua/config/marker_handlers.lua carries the %d rows of the orders (F4 3, F6 2, D2 1, V8 2, V6 six service handlers, farm 6, towns 3) and IsoArea.marker_registry() merges them; wrong or missing: %s" % [EXPECTED_ROWS.size(), str(wrong)])
	var farm_types := ["shipping_bin", "tool_shed", "field_expansion", "underdeck", "ambient_fx", "dress"]
	var farm_ok := true
	for ty in farm_types:
		farm_ok = farm_ok and str(rows.get(ty, "")) == EXPECTED_ROWS[ty]
	t.check("marker_handlers_registered_farm_types", farm_ok and str(rows["field_expansion"]).contains("steading/objects/field_expansion_2d.gd") and not str(rows["field_expansion"]).contains("farm_view") and not rows.has("greenhouse_slot"),
		"the six farm types point at scripts/farm/steading/** (field_expansion replaces the lazy farm_view.gd entry); `greenhouse_slot` stays an unregistered data marker")
	var tdp := true
	for ty in ["town", "door", "post"]:
		tdp = tdp and str(rows.get(ty, "")) == "res://scripts/towns/town_marker.gd"
	t.check("marker_handlers_town_door_post_rows", tdp, "town, door and post are three rows of ONE script (scripts/towns/town_marker.gd, create_marker(params, pos, cell, area) -> Node)")
	t.check("marker_handlers_registered_room_services", str(rows.get("bath", "")) == "res://scripts/traetoppen/life/bath_tub_2d.gd" and str(rows.get("board", "")) == "res://scripts/traetoppen/life/notice_board_2d.gd" and str(rows.get("mailbox", "")) == "res://scripts/traetoppen/life/post_box_2d.gd",
		"the rooms place the V6 services through IsoArea.resolve_handler: bath, board and the mailbox have rows")
	# the table is valid: text of the file, no duplicate keys, only .gd paths, a real entry point for every script that exists
	var text := FileAccess.get_file_as_string("res://lua/config/marker_handlers.lua")
	var rx := RegEx.new()
	rx.compile("(?m)^\\s*([a-z_]+)\\s*=\\s*\"(res://[^\"]+)\"")
	var seen := {}
	var dup: Array[String] = []
	var bad_path: Array[String] = []
	for m in rx.search_all(text):
		var key := m.get_string(1)
		if seen.has(key):
			dup.append(key)
		seen[key] = m.get_string(2)
		if not m.get_string(2).ends_with(".gd"):
			bad_path.append(key)
	var no_entry: Array[String] = []
	var pending: Array[String] = []
	for type in seen:
		var path: String = seen[type]
		if not ResourceLoader.exists(path):
			pending.append(str(type))
			continue
		var s: Script = load(path)
		var has_entry := false
		for me in s.get_script_method_list():
			if (str(me["name"]) == "create_marker" or str(me["name"]) == "setup_marker") and (me["args"] as Array).size() == 4:
				has_entry = true
		if not has_entry:
			no_entry.append(str(type))
	var builtins_free := true
	for ty in IsoArea.BUILTIN_MARKERS:
		builtins_free = builtins_free and not seen.has(ty)
	t.check("marker_handlers_table_valid", dup.is_empty() and bad_path.is_empty() and no_entry.is_empty() and seen.size() == EXPECTED_ROWS.size() and builtins_free and text.contains("kind = \"config\""),
		"%d rows, no duplicate type, every path a res:// .gd script, every script that exists has a 4-argument create_marker / setup_marker entry point (missing entry: %s), no row for a built-in type; absent scripts of later packages are skipped silently: %s" % [seen.size(), str(no_entry), str(pending)])
	var h_chest: Dictionary = IsoArea.resolve_handler("chest")
	var h_dig: Dictionary = IsoArea.resolve_handler("dig_spot")
	var h_uni: Dictionary = IsoArea.resolve_handler("unique_spot")
	t.expect(h_chest["mode"] == "create_marker" and h_dig["mode"] == "create_marker" and h_uni["mode"] == "create_marker", "the three F4 handlers are picked up through the framework's create_marker entry point")
	if not pending.is_empty():
		t.skip("handler scripts of other packages not in this tree yet (silent skips by the framework): %s" % ", ".join(pending))


## the REAL maps: the farm's two dig spots and two hidden spots, Hyggebyen's one hidden spot are built by the F4 handlers (zone = the area id, spot ids = the marker ids of the data)
func _real_maps() -> void:
	_fresh(95)
	IsoArea.clear_handler_cache()
	var holder := Node2D.new()
	t.root.add_child(holder)
	var farm := IsoArea.new()
	holder.add_child(farm)
	farm.setup(AreaMap.load_file("res://data/maps/farm.map"))
	var digs: Array = []
	var spots: Array = []
	for rec in farm.find_markers("dig_spot"):
		digs.append(rec["node"])
	for rec in farm.find_markers("unique_spot"):
		spots.append(rec["node"])
	var spot_ids: Array = []
	var zones_ok := true
	for n in spots:
		spot_ids.append((n as UniqueSpot2D).spot_id)
	for n in digs:
		zones_ok = zones_ok and (n as DigSpot2D).zone == "farm" and (n as DigSpot2D).uid.begins_with("farm:")
	spot_ids.sort()
	var town := IsoArea.new()
	holder.add_child(town)
	town.setup(AreaMap.load_file("res://data/maps/hyggebyen.map"))
	var town_spots: Array = []
	for rec in town.find_markers("unique_spot"):
		if rec["node"] != null:
			town_spots.append((rec["node"] as UniqueSpot2D).spot_id)
	t.check("real_maps_get_their_nodes", digs.size() == 2 and not digs.has(null) and zones_ok and spot_ids == ["fuglehuset", "trae_hulning"] and town_spots == ["kufferten"] and not farm.skipped_markers.has("dig_spot") and not farm.skipped_markers.has("unique_spot") and not town.skipped_markers.has("unique_spot"),
		"farm.map: 2 dig spots (zone farm, uid farm:x,y) and the hidden spots %s are real nodes; hyggebyen.map: the hidden spot %s (its only find)" % [str(spot_ids), str(town_spots)])
	holder.queue_free()


# ============================================================================================ hosting the DungeonFloors node

func _write_fixture(path: String, source: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(source)
	f.close()


const FLOORS_SOURCE := """extends Node
## fixture DungeonFloors (tests/sections/loot.gd): uid_of / is_done_cell / mark_done_cell / band_of + the section contract
var done: Dictionary = {}
var resets: int = 0

func floor_of(area) -> int:
	return int(area.map.extra.get("floor", 0))

func uid_of(area, cell) -> String:
	return "dg:1:%d:%d" % [floor_of(area), cell.y * 1000 + cell.x]

func is_done_cell(area, cell) -> bool:
	return done.has(uid_of(area, cell))

func mark_done_cell(area, cell) -> void:
	done[uid_of(area, cell)] = true

func band_of(n: int) -> StringName:
	return &"dybe_bregner" if n >= 4 else &"skovkant"

func to_dict() -> Dictionary:
	return {"v": 1}

func from_dict(_d: Dictionary) -> bool:
	return true

func reset() -> void:
	resets += 1
	done.clear()
"""


func _floors_hosting() -> void:
	_fresh(91)
	_write_fixture(FLOORS_FIXTURE, FLOORS_SOURCE)
	var real_exists := ResourceLoader.exists(ls.DUNGEON_FLOORS_PATH)
	ls.dungeon_floors_path = FLOORS_FIXTURE
	var hosted: bool = ls.host_dungeon_floors()
	var node: Node = ls.get_node_or_null("DungeonFloors")
	var section: Node = sm.section_node("dungeon")
	var order := -1
	for entry in sm._sections:
		if entry["name"] == "dungeon":
			order = int(entry["order"])
	var wired := false
	if node != null:
		for c in bus.new_game_started.get_connections():
			if (c["callable"] as Callable).get_object() == node:
				wired = true
	t.check("dungeon_floors_node_hosted_and_section_registered", hosted and node != null and section == node and order == 45 and wired and sm.FEATURE_ORDERS.size() == 5 and not sm.FEATURE_ORDERS.has("dungeon") and ls.floors() == node,
		"LootService adds the child node 'DungeonFloors' when its script exists and registers it as the section `dungeon` with the explicit order 45 (FEATURE_ORDERS stays 5 entries, reset() wired to new_game_started)")
	var again: bool = ls.host_dungeon_floors()
	t.expect(again and ls.get_children().filter(func(n: Node) -> bool: return n.name == "DungeonFloors").size() == 1, "hosting twice adds no second node")
	var payload: Dictionary = sm.gather_payload()
	t.expect(payload.has("dungeon") and sm.section_names().find("dungeon") > sm.section_names().find("loot"), "the dungeon section is gathered after loot (order 45 > 40)")
	# detach the fixture again
	if node != null:
		(node as Node).queue_free()
		ls.remove_child(node)
		sm.unregister_section("dungeon")
		ls._floors_node = null
	ls.dungeon_floors_path = ls.DUNGEON_FLOORS_PATH
	if real_exists:
		t.expect(ls.get_node_or_null("DungeonFloors") != null or ls.host_dungeon_floors(), "the real DungeonFloors (D2) is hosted")
	else:
		t.skip("scripts/dungeon/floors/dungeon_floors.gd (D2) is not in this tree: hosting was proven with the fixture node; without the script LootService hosts nothing")
		t.expect(ls.floors() == null and not sm.has_section("dungeon") and not ls.host_dungeon_floors(), "without the D2 script nothing is hosted and no `dungeon` section is registered")


# ============================================================================================ dungeon handlers on generated floors

const DUNGEON_MAP := """@id _t_floor
@projection iso
@theme farm
@floor 5
@marker c chest tier=jern role=main
@marker n chest tier=trae role=nook hidden=1
@marker l chest tier=noegle role=lake lock=wood
@marker b chest tier=konge role=boss boss=snurresvamp when=flag:dg_boss_clear
@marker d dig_spot
@marker e dig_spot
@marker u unique_spot id=svampering
@ground
#########
#.......#
#.......#
#.......#
#.......#
#.......#
#########
@objects
.........
.c.n.l...
.........
.b.d.u.e.
.........
.........
.........
"""


func _dungeon_handlers() -> void:
	_fresh(101)
	_write_fixture(FLOORS_FIXTURE, FLOORS_SOURCE)
	ls.dungeon_floors_path = FLOORS_FIXTURE
	ls.host_dungeon_floors()
	var floors: Node = ls.floors()
	IsoArea.clear_handler_cache()
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(AreaMap.parse_text(DUNGEON_MAP, "res://data/maps/_t_floor.map"))
	var jern: LootChest2D = _node_of(area, "chest") as LootChest2D
	var nook: LootChest2D = null
	var lake: LootChest2D = null
	var boss: LootChest2D = null
	for rec in area.find_markers("chest"):
		var p: Dictionary = rec["params"]
		if rec["node"] == null:
			continue
		match str(p.get("role", "")):
			"nook":
				nook = rec["node"]
			"lake":
				lake = rec["node"]
			"boss":
				boss = rec["node"]
	var dig: DigSpot2D = _node_of(area, "dig_spot") as DigSpot2D
	var spot: UniqueSpot2D = _node_of(area, "unique_spot", "svampering") as UniqueSpot2D
	var uid := str(floors.uid_of(area, jern.cell)) if jern != null else ""
	t.expect(jern != null and nook != null and lake != null and boss != null and dig != null and spot != null and jern.ctx["dungeon"] == true and int(jern.ctx["floor"]) == 5 and jern.zone == "dybe_bregner" and jern.uid == uid and uid.begins_with("dg:"),
		"on a generated floor (map.extra floor = 5) the handlers take uid = DungeonFloors.uid_of(area, cell) (%s) and the band of the floor as the zone" % uid)
	if jern == null or nook == null or lake == null or boss == null or dig == null or spot == null:
		holder.queue_free()
		return
	var player := PlayerStub2D.new()
	holder.add_child(player)
	player.global_position = jern.global_position + Vector2(30, 0)
	# is_done_cell before creation, mark_done_cell when consumed; no opened{} entry
	ls.set_loot_config(_pool_cfg(["wood"], 1, "material", "normal", {}, ["dybe_bregner"]))
	jern.interact(player)
	var done_after: bool = bool(floors.is_done_cell(area, jern.cell))
	t.check("dungeon_markers_use_done_cells_and_uid", jern.is_open and done_after and ls.opened.is_empty() and eco.count_item(&"wood") >= 1,
		"opening a floor chest marks the cell done through DungeonFloors (mark_done_cell), writes NO opened{} entry and delivers")
	# a second area built from the same seed day: the done chest is built OPEN, a done dig / spot is not built at all
	var holder2 := Node2D.new()
	t.root.add_child(holder2)
	var area2 := IsoArea.new()
	holder2.add_child(area2)
	area2.setup(AreaMap.parse_text(DUNGEON_MAP, "res://data/maps/_t_floor.map"))
	var jern2: LootChest2D = _node_of(area2, "chest") as LootChest2D
	floors.mark_done_cell(area2, Vector2i(7, 3))
	var holder3 := Node2D.new()
	t.root.add_child(holder3)
	var area3 := IsoArea.new()
	holder3.add_child(area3)
	area3.setup(AreaMap.parse_text(DUNGEON_MAP, "res://data/maps/_t_floor.map"))
	var dig_cells: Array[Vector2i] = []
	for rec3 in area3.find_markers("dig_spot"):
		if rec3["node"] != null:
			dig_cells.append(rec3["cell"])
	var chest3: LootChest2D = _node_of(area3, "chest") as LootChest2D
	t.expect(jern2 != null and jern2.is_open and jern2.get_interaction_prompt() == "" and dig_cells == [Vector2i(3, 3)] and chest3.is_open and int(area3.skipped_markers.get("dig_spot", 0)) == 1,
		"a consumed cell is read BEFORE the node is built: the chest of a done cell is built open (darkened, no prompt), the dig spot of a done cell is not built at all (built: %s, skipped %s)" % [str(dig_cells), str(area3.skipped_markers)])
	holder2.queue_free()
	holder3.queue_free()
	# the lock: without the key the lake chest whispers LOOT_LAKE_LOCKED and nothing happens; with it the key is consumed in the SAME transaction
	var cfg := _pool_cfg(["stone"], 2, "material", "normal", {}, ["dybe_bregner"])
	ls.set_loot_config(cfg)
	eco.remove_item(&"wood", eco.count_item(&"wood"))
	lake.refresh()
	_whispers.clear()
	lake.interact(player)
	t.check("chest_lock_needs_key", _whispers == ["LOOT_LAKE_LOCKED"] and not lake.is_open and not floors.is_done_cell(area, lake.cell) and eco.count_item(&"stone") == 0,
		"the lake chest (lock=wood) without the key: whisper LOOT_LAKE_LOCKED, still closed, not done, nothing delivered")
	eco.add_item(&"wood", 2, true)
	lake.interact(player)
	t.check("locked_chest_consumes_key", lake.is_open and floors.is_done_cell(area, lake.cell) and eco.count_item(&"wood") == 1 and eco.count_item(&"stone") == 2,
		"with the key the chest opens, ONE key is consumed (2 -> 1) and the two rolls arrive")
	# the first locked chest of a band holds the band's unique gem (the spot whose container is this tier); a full backpack refunds the key
	var spot_cfg := {"spots": {"soeskatten_t": {"zone": "dybe_bregner", "item": "gem_bag", "name_key": "FIND_SPOT_X", "hint_key": "ITEM_BED_TOADSTOOL_HINT", "once": true, "container": "noegle", "requires": {"items": {"wood": 1}}, "consume": true}}}
	var cfg2 := _pool_cfg(["stone"], 2, "material", "normal", spot_cfg, ["dybe_bregner"])
	ls.set_loot_config(cfg2)
	floors.done.clear()
	var holder4 := Node2D.new()
	t.root.add_child(holder4)
	var area4 := IsoArea.new()
	holder4.add_child(area4)
	area4.setup(AreaMap.parse_text(DUNGEON_MAP, "res://data/maps/_t_floor.map"))
	var lake4: LootChest2D = null
	for rec4 in area4.find_markers("chest"):
		if str((rec4["params"] as Dictionary).get("role", "")) == "lake":
			lake4 = rec4["node"]
	eco.add_item(&"wood", 3, true)
	_fill_backpack(["gem_bag"])
	var wood_before: int = eco.count_item(&"wood")
	var snapshot := _inventory_snapshot()
	var state_before: int = ls.rng.state
	lake4.interact(player)
	t.check("full_backpack_leaves_chest_closed", not lake4.is_open and not floors.is_done_cell(area4, lake4.cell) and eco.count_item(&"wood") == wood_before and eco.free_slots() == 0 and ls.rng.state == state_before and ls.claimed.is_empty() and _inventory_snapshot() == snapshot,
		"a plan that does not fit the backpack AS A WHOLE leaves the chest closed AND not done and changes nothing: the key stays, the claim is not recorded, the stream is where it was (open %s, done %s, wood %d/%d, free %d, claimed %s)" % [str(lake4.is_open), str(floors.is_done_cell(area4, lake4.cell)), eco.count_item(&"wood"), wood_before, eco.free_slots(), str(ls.claimed.keys())])
	_free_slots_to(3)
	lake4.interact(player)
	t.expect(lake4.is_open and ls.claimed.has("soeskatten_t") and eco.count_item(&"gem_bag") == 1 and eco.count_item(&"wood") == wood_before - 1, "with room the first locked chest opens the band's spot: the unique gem arrives, one key is consumed")
	holder4.queue_free()
	# the same when the spot lists NO required item: the chest's own lock still takes exactly ONE key (the spot route used to take none)
	ls.claimed.erase("soeskatten_t")
	eco.remove_item(&"gem_bag", eco.count_item(&"gem_bag"))
	eco.remove_item(&"wood", eco.count_item(&"wood"))
	_free_slots_to(4)
	eco.add_item(&"wood", 2, true)
	var spot_cfg_b := {"spots": {"soeskatten_t": {"zone": "dybe_bregner", "item": "gem_bag", "name_key": "FIND_SPOT_X", "hint_key": "ITEM_BED_TOADSTOOL_HINT", "once": true, "container": "noegle"}}}
	ls.set_loot_config(_pool_cfg(["stone"], 2, "material", "normal", spot_cfg_b, ["dybe_bregner"]))
	floors.done.clear()
	var holder_b := Node2D.new()
	t.root.add_child(holder_b)
	var area_b := IsoArea.new()
	holder_b.add_child(area_b)
	area_b.setup(AreaMap.parse_text(DUNGEON_MAP, "res://data/maps/_t_floor.map"))
	var lake_b: LootChest2D = null
	for rec_b in area_b.find_markers("chest"):
		if str((rec_b["params"] as Dictionary).get("role", "")) == "lake":
			lake_b = rec_b["node"]
	lake_b.interact(player)
	t.check("locked_spot_chest_takes_one_key", lake_b.is_open and ls.claimed.has("soeskatten_t") and eco.count_item(&"gem_bag") == 1 and eco.count_item(&"wood") == 1,
		"a lake chest whose spot lists no required item: the band's gem arrives and the chest's lock consumed ONE key (2 -> %d); with the key in the spot's own requires (above) it is still ONE" % eco.count_item(&"wood"))
	holder_b.queue_free()
	# the sealed boss chest: behind when=flag:dg_boss_clear; opening calls on_boss_defeated(kind, ctx{uid, floor, band})
	t.expect(not boss.is_enabled() and not boss.visible, "the boss chest is sealed (hidden, not interactable) until the flag dg_boss_clear is set")
	gm.set_flag(&"dg_boss_clear", true)
	area.refresh_when()
	_day(10)
	_rolled.clear()
	var fake := FakeLootRecorder.new()
	Svc.override("LootService", fake)
	boss.interact(player)
	Svc.clear_overrides()
	t.expect(boss.is_enabled() and fake.calls.size() == 1 and fake.calls[0][0] == "on_boss_defeated" and fake.calls[0][1] == "snurresvamp" and str((fake.calls[0][2] as Dictionary).get("uid", "")).begins_with("dg:") and int((fake.calls[0][2] as Dictionary).get("floor", 0)) == 5 and str((fake.calls[0][2] as Dictionary).get("band", "")) == "dybe_bregner" and bool((fake.calls[0][2] as Dictionary).get("dungeon", false)),
		"opening the unsealed boss chest calls LootService.on_boss_defeated(snurresvamp, {uid dg:..., floor 5, band dybe_bregner, dungeon})")
	gm.set_flag(&"dg_boss_clear", null)
	fake.free()
	# the lake chest art: chest_noegle when it exists, else chest_konge with the code-drawn padlock (honest stub S20)
	var has_art := ArtCatalog.has_real_prop(&"chest_noegle")
	var plain := lake.art_id == "chest_noegle" and not lake.padlock_drawn if has_art else lake.art_id == "chest_konge" and lake.padlock_drawn
	LootChest2D.force_fallback_art = true
	var holder5 := Node2D.new()
	t.root.add_child(holder5)
	var area5 := IsoArea.new()
	holder5.add_child(area5)
	area5.setup(AreaMap.parse_text(DUNGEON_MAP, "res://data/maps/_t_floor.map"))
	var fallback: LootChest2D = null
	for rec5 in area5.find_markers("chest"):
		if str((rec5["params"] as Dictionary).get("role", "")) == "lake":
			fallback = rec5["node"]
	LootChest2D.force_fallback_art = false
	t.check("lake_chest_has_art_or_padlock_fallback", plain and fallback != null and fallback.art_id == "chest_konge" and fallback.padlock_drawn and fallback.get_node_or_null("Padlock") != null and fallback.get_node("Sprite").texture != null,
		"chest_noegle art %s: the lake chest draws %s; with the art forced away it draws chest_konge + a brass Padlock node" % ["exists" if has_art else "does not exist yet", lake.art_id])
	holder5.queue_free()
	# the hidden chest
	nook.refresh()
	t.expect(not nook.revealed and not nook._sprite.visible and nook.get_interaction_prompt() == "" and nook._body.collision_layer == 0, "hidden=1: the chest is invisible, not interactable and not solid at first")
	nook.update_reveal(600.0)
	t.expect(not nook.revealed and not nook._glimmer.visible, "600 px away without chest sense: still nothing")
	t.expect(is_equal_approx(LootMarkers.REVEAL_PX, 240.0), "the base reveal radius is 240 px")
	nook.update_reveal(239.0)
	var revealed_near := nook.revealed and nook._sprite.visible and nook.get_interaction_prompt() != ""
	var holder6 := Node2D.new()
	t.root.add_child(holder6)
	var area6 := IsoArea.new()
	holder6.add_child(area6)
	area6.setup(AreaMap.parse_text(DUNGEON_MAP, "res://data/maps/_t_floor.map"))
	var nook6: LootChest2D = null
	for rec6 in area6.find_markers("chest"):
		if str((rec6["params"] as Dictionary).get("role", "")) == "nook":
			nook6 = rec6["node"]
	nook6.update_reveal(241.0)
	var edge_hidden := not nook6.revealed
	# chest sense: DungeonRun.chest_sense_px() / the species perk (700 px for the monkey) show the glint between 240 px and the sense radius
	var real_sense := LootMarkers.sense_px()
	_write_fixture(RUN_SENSE_PATH, "extends RefCounted\nstatic func chest_sense_px() -> int:\n\treturn 700\n")
	LootMarkers.run_script_path = RUN_SENSE_PATH
	nook6.update_reveal(650.0)
	var glint_far := nook6.glimmer_shown and nook6._glimmer.visible and not nook6.revealed
	nook6.update_reveal(800.0)
	var glint_gone := not nook6._glimmer.visible
	var sensed := LootMarkers.sense_px()
	t.check("hidden_chest_reveal_radius", revealed_near and edge_hidden and glint_far and glint_gone and sensed == 700.0 and real_sense <= 700.0 and LootMarkers.SENSE_CAP_PX == 1152.0,
		"hidden chest: shown for good within 240 px (239 yes, 241 no); with a chest sense of %d px (DungeonRun.chest_sense_px through the seam; the hero's own perk alone is %d px) the glint unique_glimmer shows out to the sense radius (650 yes, 800 no), capped at 12 cells (1152 px)" % [int(sensed), int(real_sense)])
	LootMarkers.run_script_path = LootMarkers.DUNGEON_RUN_SCRIPT
	DirAccess.remove_absolute(RUN_SENSE_PATH)
	holder6.queue_free()
	# done cells for dig and unique spot on the floor: marked done after use
	floors.done.clear()
	_free_slots_to(8)
	ls.set_loot_config(null)
	var dig_done_before: bool = floors.is_done_cell(area, dig.cell)
	dig.interact(player)
	t.expect(not dig_done_before and floors.is_done_cell(area, dig.cell) and ls.opened.is_empty(), "a dig on a floor marks its cell done and writes no opened{} entry")
	_day(20)
	spot.refresh()
	player.global_position = spot.global_position
	var spot_done_before: bool = floors.is_done_cell(area, spot.cell)
	spot.interact(player)
	t.expect(not spot_done_before and floors.is_done_cell(area, spot.cell) and ls.claimed.has("svampering"), "claiming a spot on a floor marks its cell done")
	holder.queue_free()
	await t.frames(2)
	if floors != null:
		floors.queue_free()
		ls.remove_child(floors)
		sm.unregister_section("dungeon")
		ls._floors_node = null
	ls.dungeon_floors_path = ls.DUNGEON_FLOORS_PATH
	ls.set_loot_config(null)
	gm.set_flag(&"dg_boss_clear", null)


const RUN_SENSE_PATH := "user://f4_fixtures/unused_run_sense.gd"

## records the calls the boss chest makes: a stand-in LootService for the handler test
class FakeLootRecorder extends Node:
	var calls: Array = []

	func on_boss_defeated(boss_id: String, ctx: Dictionary) -> Dictionary:
		calls.append(["on_boss_defeated", boss_id, ctx])
		return {"ok": true, "results": [], "reason": &""}

	func days_left(_uid: String, _days: int) -> int:
		return 0

	func respawn_days_of(_zone: String, _tier: String) -> int:
		return 1

	func floors() -> Node:
		return null


# ============================================================================================ the delegation seam with a FAKE delegate (DL5 replaces it)

const RULES_SOURCE := """extends RefCounted
## fixture dungeon_loot_rules.gd (tests/sections/loot.gd): the plan / fits / commit contract of the delegation seam
static func _log(entry: String) -> void:
	var l: Array = Engine.get_meta("f4_log", [])
	l.append(entry)
	Engine.set_meta("f4_log", l)

static func _rows() -> Array:
	return Engine.get_meta("f4_rows", [{"id": "wood", "amount": 3, "rarity": "normal", "kind": "material"}])

static func _plan(kind: String, state: Dictionary, req: Dictionary) -> Dictionary:
	_log("plan:%s" % kind)
	Engine.set_meta("f4_last_req", req)
	Engine.set_meta("f4_state_seen", state.duplicate(true))
	if Engine.get_meta("f4_refuse", false):
		return {"ok": false, "reason": &"capped", "results": []}
	return {"ok": true, "reason": &"", "results": _rows(), "kind": kind, "uid": req.get("uid", ""), "bump": 1}

static func roll_container(state: Dictionary, req: Dictionary) -> Dictionary:
	return _plan("container", state, req)

static func roll_node(state: Dictionary, req: Dictionary) -> Dictionary:
	return _plan("node", state, req)

static func roll_drop(state: Dictionary, req: Dictionary) -> Dictionary:
	return _plan("drop", state, req)

static func boss_result(state: Dictionary, req: Dictionary) -> Dictionary:
	return _plan("boss", state, req)

static func roll_spot(state: Dictionary, req: Dictionary) -> Dictionary:
	return _plan("spot", state, req)

static func roll_appraisal(state: Dictionary, req: Dictionary) -> Dictionary:
	return _plan("appraisal", state, req)

static func appraisal_quote(_cfg: Dictionary, rough_id: String) -> Dictionary:
	return {"band": rough_id.replace("rough_", ""), "fee": 30}

static func spot_state(_state: Dictionary, req: Dictionary) -> StringName:
	_log("spot_state:%s" % req.get("spot", ""))
	return &"cooldown" if Engine.get_meta("f4_cooldown", false) else &"open"

static func fits(plan: Dictionary, pack_view: Dictionary) -> bool:
	_log("fits")
	Engine.set_meta("f4_pack_view", pack_view)
	var free: int = int(pack_view.get("free_slots", 0))
	var need := {}
	for row in plan.get("results", []):
		if bool((pack_view.get("own_store", {}) as Dictionary).get(str(row["id"]), false)):
			continue
		need[str(row["id"])] = int(need.get(str(row["id"]), 0)) + int(row["amount"])
	for id in need:
		var ms: int = int((pack_view["max_stack"] as Dictionary).get(id, 1))
		var rest: int = int(need[id]) - int((pack_view["stack_room"] as Dictionary).get(id, 0))
		if rest > 0:
			free -= int(ceil(float(rest) / float(ms)))
	return free >= 0

static func commit(state: Dictionary, plan: Dictionary) -> Dictionary:
	_log("commit")
	var s := state.duplicate(true)
	s["commits"] = int(s.get("commits", 0)) + int(plan.get("bump", 1))
	return s
"""


func _delegate_seam() -> void:
	_fresh(111)
	_write_fixture(RULES_FIXTURE, RULES_SOURCE)
	ls.delegate_path = RULES_FIXTURE
	Engine.set_meta("f4_rows", [{"id": "wood", "amount": 3, "rarity": "normal", "kind": "material"}])
	# a dungeon uid goes to the delegate: plan -> fits -> deliver -> commit, in that order, with the keyed request
	var res: Dictionary = ls.open_container("skovkant", "trae", "dg:7:2:15", {"dungeon": true, "floor": 2, "band": "skovkant", "odds": {"legendary": 10000}})
	var log: Array = Engine.get_meta("f4_log", [])
	var req: Dictionary = Engine.get_meta("f4_last_req", {})
	t.check("two_phase_plan_fit_deliver_commit_with_fake", bool(res["ok"]) and log == ["plan:container", "fits", "commit"] and eco.count_item(&"wood") >= 3 and int(ls.dungeon.get("commits", 0)) == 1 and (res["results"] as Array).size() == 1,
		"with a fake delegate the order is PLAN (roll_container) -> FIT (fits) -> deliver -> COMMIT (commit): %s, the state came back through commit (commits %d)" % [str(log), int(ls.dungeon.get("commits", 0))])
	t.check("dungeon_delegate_seam_with_fake", str(req.get("uid", "")) == "dg:7:2:15" and str(req.get("band", "")) == "skovkant" and str(req.get("container", "")) == "trae" and not (req["ctx"] as Dictionary).has("odds") and req.has("luck") and req.has("day") and req.has("cfg") and str(req.get("kind", "")) == "container",
		"the delegate got state + req {kind, zone, band, container, uid, ctx (without odds), luck, day, cfg}; a ctx.odds that tried to force a legendary never reaches it")
	# a farm uid never goes to the delegate, even when it exists
	Engine.set_meta("f4_log", [])
	ls.set_loot_config(_pool_cfg(["stone"], 1, "material", "normal"))
	var farm: Dictionary = ls.open_container("zz", "trae", "zz:4,4")
	t.expect(bool(farm["ok"]) and (Engine.get_meta("f4_log", []) as Array).is_empty() and ls.opened.has("zz:4,4"), "a static-area container always runs the built-in algorithm (the delegate was not asked)")
	ls.set_loot_config(null)
	# no opened{} entry for dg: uids, with and without the delegate
	var d1: Dictionary = ls.to_dict()
	var no_dg := true
	for k in (d1["opened"] as Dictionary):
		no_dg = no_dg and not str(k).begins_with("dg:")
	ls.delegate_path = ls.DELEGATE_PATH
	ls.set_loot_config(_pool_cfg(["stone"], 1, "material", "normal"))
	ls.open_container("zz", "trae", "dg:7:2:16", {"dungeon": true, "band": "zz"})
	for k in ls.to_dict()["opened"]:
		no_dg = no_dg and not str(k).begins_with("dg:")
	t.check("no_opened_entries_for_dungeon_uids", no_dg and not ls.opened.has("dg:7:2:15") and not ls.opened.has("dg:7:2:16"), "a `dg:` uid never writes opened{} (consumption lives in DungeonFloors.done), through the delegate or the built-in algorithm")
	ls.set_loot_config(null)
	ls.delegate_path = RULES_FIXTURE
	# every dungeon call is routed: node, drop, boss, spot, appraisal
	var routed: Array = []
	for pair in [["node", func() -> Dictionary: return ls.node_loot("crystal", "dg:7:2:20", {"band": "skovkant"})],
			["drop", func() -> Dictionary: return ls.on_enemy_defeated("bat", {"uid": "dg:7:2:21", "dungeon": true, "band": "skovkant"})],
			["boss", func() -> Dictionary: return ls.on_boss_defeated("snurresvamp", {"uid": "dg:7:2:22", "dungeon": true, "band": "dybe_bregner"})],
			["spot", func() -> Dictionary: return ls.claim_spot("svampering", {"uid": "dg:7:2:23", "dungeon": true})]]:
		Engine.set_meta("f4_log", [])
		var answer: Dictionary = (pair[1] as Callable).call()
		routed.append("%s:%s" % [pair[0], str((Engine.get_meta("f4_log", []) as Array)[0] if not (Engine.get_meta("f4_log", []) as Array).is_empty() else "-")])
		if pair[0] == "drop":
			t.expect(bool(answer["ok"]) and (answer["results"] as Array).size() == 1 and (answer["sold"] as Array).is_empty(), "on_enemy_defeated returns the drop (deliver = orbs is the default): nothing added yet")
	t.expect(routed == ["node:plan:node", "drop:plan:drop", "boss:plan:boss", "spot:plan:spot"], "node_loot, on_enemy_defeated, on_boss_defeated and claim_spot of a dg: uid each go through the delegate: %s" % str(routed))
	# appraisal: the fee is charged, the stone consumed, the gem delivered, autosave runs, in ONE transaction
	Engine.set_meta("f4_log", [])
	Engine.set_meta("f4_rows", [{"id": "gem_bag", "amount": 1, "rarity": "normal", "kind": "gem"}])
	eco.add_item(&"moss", 2, true)
	eco.gold = 500
	var quote: Dictionary = ls.appraisal_quote("rough_skovkant")
	var stamp := FileAccess.get_modified_time(sm.slot_path(sm.AUTO_SLOT)) if FileAccess.file_exists(sm.slot_path(sm.AUTO_SLOT)) else 0
	var app: Dictionary = ls.appraise("moss")
	var auto_written: bool = FileAccess.file_exists(sm.slot_path(sm.AUTO_SLOT)) and (FileAccess.get_modified_time(sm.slot_path(sm.AUTO_SLOT)) >= stamp)
	t.expect(int(quote["fee"]) == 30 and str(quote["band"]) == "skovkant" and bool(app["ok"]) and str(app["gem"]) == "gem_bag" and int(app["fee"]) == 30 and eco.gold == 470 and eco.count_item(&"moss") == 1 and eco.count_item(&"gem_bag") >= 1 and auto_written,
		"appraise through the seam: fee 30 charged, the stone (moss as stand-in) consumed, the gem delivered, SaveManager.autosave ran before the answer (%s)" % str(app))
	eco.gold = 10
	var poor: Dictionary = ls.appraise("moss")
	t.expect(not bool(poor["ok"]) and poor["reason"] == &"no_gold" and eco.gold == 10 and eco.count_item(&"moss") == 1, "without the gold nothing is consumed or paid")
	# the unique pace of the dungeon (7 days between two HUNTED keepsakes) is the delegate's: spot_state answers cooldown, the handler says so
	_fresh(115)
	ls.delegate_path = RULES_FIXTURE
	var spot_map := "@id _t_pace\n@projection iso\n@theme farm\n@marker u unique_spot id=svampering\n@ground\n#####\n#...#\n#...#\n#####\n@objects\n.....\n..u..\n.....\n.....\n"
	var holder_p := Node2D.new()
	t.root.add_child(holder_p)
	var area_p := IsoArea.new()
	holder_p.add_child(area_p)
	area_p.setup(AreaMap.parse_text(spot_map))
	var spot_p: UniqueSpot2D = _node_of(area_p, "unique_spot") as UniqueSpot2D
	var open_state: StringName = ls.spot_state("svampering")
	Engine.set_meta("f4_cooldown", true)
	spot_p.refresh()
	var paced: StringName = ls.spot_state("svampering")
	_whispers.clear()
	spot_p.interact(null)
	Engine.remove_meta("f4_cooldown")
	t.expect(open_state == &"open" and paced == &"cooldown" and spot_p.state == &"cooldown" and _whispers == ["LOOT_SPOT_PACED"] and not ls.claimed.has("svampering"), "spot_state asks the delegate (the unique pace): open -> cooldown; the handler whispers LOOT_SPOT_PACED and claims nothing")
	holder_p.queue_free()
	# a full backpack: the delegate planned, fits said no, commit NEVER ran, nothing changed
	_fresh(112)
	ls.delegate_path = RULES_FIXTURE
	Engine.set_meta("f4_log", [])
	Engine.set_meta("f4_rows", [{"id": "iron_sword", "amount": 1, "rarity": "normal", "kind": "material"}, {"id": "copper_ore", "amount": 1, "rarity": "normal", "kind": "material"}])
	_fill_backpack(["iron_sword", "copper_ore"])
	_free_slots_to(1)
	var inv := _inventory_snapshot()
	var commits_before := int(ls.dungeon.get("commits", 0))
	var full: Dictionary = ls.open_container("skovkant", "trae", "dg:7:2:30", {"dungeon": true, "band": "skovkant"})
	var log2: Array = Engine.get_meta("f4_log", [])
	t.expect(not bool(full["ok"]) and full["reason"] == &"full" and (full["results"] as Array).is_empty() and log2 == ["plan:container", "fits"] and _inventory_snapshot() == inv and int(ls.dungeon.get("commits", 0)) == commits_before,
		"two items, one free slot: the delegate planned and fits() refused -> {false, full, []}, commit was NEVER called, the inventory is untouched (%s)" % str(log2))
	var view: Dictionary = Engine.get_meta("f4_pack_view", {})
	t.expect(int(view.get("free_slots", -1)) == 1 and (view.get("stack_room", {}) as Dictionary).has("iron_sword") and (view.get("max_stack", {}) as Dictionary).has("copper_ore") and (view.get("own_store", {}) as Dictionary).has("iron_sword"), "the pack_view the delegate receives: free_slots, stack_room{item}, max_stack{item}, own_store{item}")
	# a plan the delegate refuses (cap reached): nothing happens either
	Engine.set_meta("f4_refuse", true)
	var refused: Dictionary = ls.open_container("skovkant", "trae", "dg:7:2:31", {"dungeon": true, "band": "skovkant"})
	Engine.set_meta("f4_refuse", false)
	t.expect(not bool(refused["ok"]) and refused["reason"] == &"capped" and (refused["results"] as Array).is_empty(), "a plan the rules refuse is answered as {false, [], their reason}")
	# the cap whisper and event come ONCE per day, from the state the commit wrote
	_fresh(113)
	ls.delegate_path = RULES_FIXTURE
	_day(5)
	ls.dungeon = {"day": {"day": 5, "value": 3300, "capped": true}}
	Engine.set_meta("f4_rows", [{"id": "wood", "amount": 1, "rarity": "normal", "kind": "material"}])
	_whispers.clear()
	_events.clear()
	ls.open_container("skovkant", "trae", "dg:7:2:40", {"dungeon": true, "band": "skovkant"})
	ls.open_container("skovkant", "trae", "dg:7:2:41", {"dungeon": true, "band": "skovkant"})
	var told := 0
	for e in _events:
		told += 1 if e[0] == &"loot_day_capped" else 0
	t.expect(told == 1 and _whispers.count("LOOT_DAY_TIRED") == 1, "the capped day is announced ONCE: game_event loot_day_capped + the whisper LOOT_DAY_TIRED")
	# the keepsake registry and its announcement
	_fresh(114)
	_events.clear()
	_whispers.clear()
	var keep: Dictionary = ls.deliver("throne_root", 1)
	var keep2: Dictionary = ls.deliver("throne_root", 1)
	var ev := 0
	for e2 in _events:
		ev += 1 if e2[0] == &"loot_keepsake_found" and str(e2[1]["item"]) == "throne_root" and str(e2[1]["rarity"]) == "unique" else 0
	var shown_name := String(TranslationServer.translate(StringName(str(ItemKinds.def("throne_root").get("name_key", "")))))
	var whisper_seen: bool = _whispers.any(func(w: String) -> bool: return w.contains(shown_name))
	t.expect(bool(keep["ok"]) and ls.found("throne_root") and ev == 1 and whisper_seen and int(keep2["gold"]) == 0, "a keepsake enters through deliver(): the registry `found` records it (never pruned), game_event loot_keepsake_found {item, rarity, source} fires once, LOOT_KEEPSAKE_FOUND_FMT is whispered (found %s, events %d, whisper %s, second delivery gold %s, whispers %s, events %s)" % [str(ls.found("throne_root")), ev, str(whisper_seen), str(keep2["gold"]), str(_whispers), str(_events)])
	var removed: bool = eco.remove_item(&"throne_root", 1)
	t.expect(removed and ls.found("throne_root"), "the registry survives losing the item: a keepsake can never be found twice")
	if not ResourceLoader.exists("res://scripts/dungeon_loot/dungeon_loot_rules.gd"):
		t.skip("scripts/dungeon_loot/dungeon_loot_rules.gd (DL5, wave 5) is not in this tree: the seam was proven with a fake delegate; without it the built-in algorithm runs (checked above)")
	ls.delegate_path = ls.DELEGATE_PATH
	Engine.remove_meta("f4_rows")
	Engine.remove_meta("f4_refuse")


# ============================================================================================ the appraisal screen host

const APPRAISAL_SOURCE := """extends Node
var opened_with: Array = []
func open(npc) -> void:
	opened_with.append(str(npc))
"""


func _appraisal_host() -> void:
	_fresh(121)
	var script := GDScript.new()
	script.source_code = APPRAISAL_SOURCE
	script.reload()
	var scene_root := Node.new()
	scene_root.name = "AppraisalUiFixture"
	scene_root.set_script(script)
	var packed := PackedScene.new()
	packed.pack(scene_root)
	ResourceSaver.save(packed, SCENE_FIXTURE)
	scene_root.free()
	var real_ui: Array[Node] = t.tree.get_nodes_in_group("game_ui")
	for n in real_ui:
		n.remove_from_group("game_ui")
	var game_ui := Control.new()
	game_ui.name = "GameUiFixture"
	game_ui.add_to_group("game_ui")
	t.root.add_child(game_ui)
	var other := Control.new()
	other.add_to_group("game_ui")
	t.root.add_child(other)
	ls.appraisal_scene_path = SCENE_FIXTURE
	bus.game_event.emit(&"open_appraisal", {"npc": "appraiser_fru_ugle"})
	var ui: Node = game_ui.get_node_or_null("AppraisalUiFixture")
	var count_after_first := game_ui.get_child_count()
	bus.game_event.emit(&"open_appraisal", {"npc": "appraiser_fru_ugle", "building": "uglehulen"})
	var opened: Array = ui.get("opened_with") if ui != null else []
	t.check("open_appraisal_event_instantiates_scene_when_present", ui != null and count_after_first == 1 and game_ui.get_child_count() == 1 and opened == ["appraiser_fru_ugle", "appraiser_fru_ugle"] and other.get_child_count() == 0,
		"game_event open_appraisal {npc} with the scene present: it is instantiated ONCE as a child of the FIRST node of group game_ui and its open(npc) is called every time (%s)" % str(opened))
	# appraisal_available(): true only when the rules (the delegate's roll_appraisal) AND the screen exist; appraise() / open_appraisal() themselves always exist
	var scene_only: bool = ls.appraisal_available()
	_write_fixture(RULES_FIXTURE, RULES_SOURCE)
	ls.delegate_path = RULES_FIXTURE
	var both: bool = ls.appraisal_available()
	ls.appraisal_scene_path = "user://f4_fixtures/no_such_scene.tscn"
	var rules_only: bool = ls.appraisal_available()
	ls.delegate_path = ls.DELEGATE_PATH
	var neither: bool = ls.appraisal_available()
	ls.appraisal_scene_path = SCENE_FIXTURE
	t.check("appraisal_available_needs_rules_and_screen", not scene_only and both and not rules_only and not neither and ls.has_method("appraise") and ls.has_method("open_appraisal"),
		"appraisal_available(): scene only %s, rules + scene %s, rules only %s, neither %s; the stubs appraise() / open_appraisal() exist regardless, so the towns' counter must ask this and not has_method" % [str(scene_only), str(both), str(rules_only), str(neither)])
	game_ui.queue_free()
	other.queue_free()
	ls._appraisal_ui = null
	await t.frames(1)
	# without the scene the event is ignored: no node, no error
	var holder := Control.new()
	holder.add_to_group("game_ui")
	t.root.add_child(holder)
	ls.appraisal_scene_path = "user://f4_fixtures/no_such_scene.tscn"
	var mark: int = t.log_mark()
	bus.game_event.emit(&"open_appraisal", {"npc": "appraiser_fru_ugle"})
	t.check("open_appraisal_event_ignored_without_scene", holder.get_child_count() == 0 and not ls.open_appraisal(&"x") and t.log_since(mark).is_empty(),
		"without scenes/ui/appraisal_ui.tscn (honest stub S21) the event is ignored: nothing instantiated, no engine message")
	if ResourceLoader.exists(ls.APPRAISAL_SCENE):
		t.skip("scenes/ui/appraisal_ui.tscn exists in this tree (DL7): the real screen's behaviour is DL7's own section")
	else:
		t.skip("scenes/ui/appraisal_ui.tscn (DL7, wave 5b) is not in this tree: Fru Ugle's choice does nothing visible yet (stub S21)")
	holder.queue_free()
	ls.appraisal_scene_path = ls.APPRAISAL_SCENE
	ls._appraisal_ui = null
	DirAccess.remove_absolute(SCENE_FIXTURE)
	for n in real_ui:
		if is_instance_valid(n):
			n.add_to_group("game_ui")


# ============================================================================================ copy

func _keys() -> void:
	var lm: Node = t.autoload("LocalizationManager")
	var want := {
		"LOOT_DAY_TIRED": ["Skoven har givet, hvad den kan i dag. Kom igen i morgen.", "The forest has given what it can today. Come back tomorrow."],
		"LOOT_RUNE_VAULT_NEEDS": ["Hvælvingen mangler runeskår. Tre skal der til.", "The vault is missing rune shards. It needs three."],
		"LOOT_LAKE_LOCKED": ["Låst. Måske kender Fru Ugle en nøgle?", "Locked. Maybe Mrs Owl knows a key?"],
	}
	var ok := true
	for key in want:
		ok = ok and lm.text_in(key, "da") == want[key][0] and lm.text_in(key, "en") == want[key][1]
	var fmt_ok: bool = lm.text_in("LOOT_KEEPSAKE_FOUND_FMT", "da").contains("%s") and lm.text_in("LOOT_KEEPSAKE_FOUND_FMT", "en").contains("%s") and lm.text_in("LOOT_KEEPSAKE_FOUND_FMT", "da") != ""
	var used_ok := true
	for key in ["LOOT_PROMPT_OPEN", "LOOT_PROMPT_DIG", "LOOT_PROMPT_SEARCH", "LOOT_TOO_TIRED", "LOOT_CHEST_RESTING", "LOOT_DIG_RESTING", "LOOT_SPOT_PACED"]:
		used_ok = used_ok and lm.text_in(key, "da") != "" and lm.text_in(key, "en") != ""
	var csv := FileAccess.get_file_as_string("res://localization/loot_dungeon.csv")
	var imp := FileAccess.get_file_as_string("res://localization/loot_dungeon.csv.import")
	t.check("dungeon_keys_defined_da_en", ok and fmt_ok and used_ok and imp.contains("importer=\"keep\"") and csv.begins_with("keys,da,en"),
		"loot_dungeon.csv (+ keep-import) defines the four service messages (LOOT_DAY_TIRED, LOOT_KEEPSAKE_FOUND_FMT, LOOT_RUNE_VAULT_NEEDS with 'Tre', LOOT_LAKE_LOCKED) and the handler prompts, da + en")
	var offenders: Array[String] = []
	for path in ["res://scripts/loot/loot_service.gd", "res://scripts/loot/loot_rules.gd", "res://scripts/loot/loot_markers.gd", "res://scripts/world2d/loot_chest_2d.gd", "res://scripts/world2d/dig_spot_2d.gd", "res://scripts/world2d/unique_spot_2d.gd",
			"res://scripts/economy/shop_rotation.gd", "res://scripts/economy/price_curve.gd"]:
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := line.split("#")[0]
			for ch in "æøåÆØÅ":
				if code.contains(ch) and code.contains("\""):
					offenders.append("%s:%d" % [path.get_file(), n])
	t.expect(offenders.is_empty(), "no Danish literal in the package's scripts: %s" % str(offenders))


# ============================================================================================ PriceCurve reads the keeper's hearts

func _price_keeper() -> void:
	_fresh(131)
	Svc.clear_overrides()
	gm.set("character_type", 0)
	var price := func(shop: String) -> int: return PriceCurve.final_price(shop, "bed_pine", 1600)
	var furn0: int = price.call("furniture_shop")
	var flea0: int = price.call("flea_market")
	gm.set_flag(&"friend_fairy_furnisher", 10)
	var furn10: int = price.call("furniture_shop")
	var flea_after: int = price.call("flea_market")
	gm.set_flag(&"friend_fairy_furnisher", null)
	gm.set_flag(&"friend_pippin_boegeknop", 10)
	var flea10: int = price.call("flea_market")
	var furn_after: int = price.call("furniture_shop")
	gm.set_flag(&"friend_pippin_boegeknop", null)
	gm.set_flag(&"friend_fairy_furnisher", 3)
	var furn3: int = price.call("furniture_shop")
	var src := FileAccess.get_file_as_string("res://scripts/economy/price_curve.gd")
	var shop: Dictionary = ShopRotation.shop_def("furniture_shop")
	t.check("price_curve_reads_keeper_hearts", furn0 == 1600 and furn10 == 1520 and flea_after == flea0 and flea10 == 1520 and furn_after == furn0 and furn3 == 1576 and str(shop.get("keeper", "")) == "fairy_furnisher" and src.contains("KEEPER") and src.contains("friend_<keeper>"),
		"the friend discount reads the hearts of THE KEEPER of the shop (flag friend_<keeper> of the shop def): 1600 -> %d with 10 hearts of fairy_furnisher in her furniture shop (-5 %%), %d with 3 hearts (-1.5 %%), the same hearts do nothing in Pippin's flea market (%d) and Pippin's hearts do nothing at Stokrose (%d); the header says so" % [furn10, furn3, flea_after, furn_after])
	gm.set_flag(&"friend_fairy_furnisher", null)


# ============================================================================================ cleanup

func _cleanup() -> void:
	Svc.clear_overrides()
	ls.set_loot_config(null)
	ls.delegate_path = ls.DELEGATE_PATH
	ls.dungeon_floors_path = ls.DUNGEON_FLOORS_PATH
	ls.appraisal_scene_path = ls.APPRAISAL_SCENE
	for engine_key in ["f4_log", "f4_rows", "f4_refuse", "f4_last_req", "f4_state_seen", "f4_pack_view", "f4_cooldown"]:
		if Engine.has_meta(engine_key):
			Engine.remove_meta(engine_key)
	for path in [FLOORS_FIXTURE, RULES_FIXTURE, SCENE_FIXTURE, RUN_SENSE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(FIXTURE_DIR)
	Fresh.new_game(t)
	for flag in ["f4_glimmer_visible", "dg_boss_clear"]:
		gm.set_flag(StringName(flag), null)


# ============================================================================================ windowed: what the handlers look like (real window, run through tools/dev/run_windowed.sh)

## the look sheet: row 2 the five chest tiers CLOSED (trae jern fe konge, the lake chest with its lock), row 4 the same four tiers OPENED (darkened until respawn), row 6 a dig spot, a dug spot,
## a locked glimmer, an open glimmer and a hidden chest (revealed)
const LOOK_MAP := """@id _t_loot_look
@projection iso
@theme farm
@zone farm
@marker 1 chest tier=trae
@marker 2 chest tier=jern
@marker 3 chest tier=fe
@marker 4 chest tier=konge
@marker 5 chest tier=noegle role=lake lock=wood
@marker 6 chest tier=trae
@marker 7 chest tier=jern
@marker 8 chest tier=fe
@marker 9 chest tier=konge
@marker d dig_spot
@marker e dig_spot
@marker u unique_spot id=fuglehuset
@marker v unique_spot id=svampering
@ground
##################
#................#
#................#
#................#
#................#
#................#
#................#
#................#
#................#
##################
@objects
..................
...1.2.3.4.5......
..................
...6.7.8.9........
..................
.@.d.e.u.v........
..................
..................
..................
..................
"""


const PADLOCK_MAP := """@id _t_loot_padlock
@projection iso
@theme farm
@zone farm
@marker 5 chest tier=noegle role=lake lock=wood
@ground
########
#......#
#......#
#......#
#......#
########
@objects
........
.@.5....
........
........
........
........
"""


func run_windowed(tt) -> void:
	t = tt
	ls = t.autoload("LootService")
	gm = t.autoload("GameManager")
	if ls == null:
		return
	if not await t.start_world():
		return
	var w: WorldRoot2D = t.world()
	Fresh.new_game(null)
	Fresh.jump_to_total_day(3)
	ls.set_loot_config(null)
	WorldRoot2D.register_map(&"_t_loot_look", AreaMap.parse_text(LOOK_MAP))
	# the second row of chests and the dug spot were used today: they are built dark
	for cell in [Vector2i(3, 3), Vector2i(5, 3), Vector2i(7, 3), Vector2i(9, 3), Vector2i(5, 5)]:
		ls.opened[LootRules.container_uid("_t_loot_look", cell)] = 3
	w._enter(&"_t_loot_look", &"default")
	w.warm_in_headless = true
	await w.warm_clips()
	var a: IsoArea = w.area
	w.day_night.override_hour = 11.0
	w.day_night.snap()
	a.set_night_factor(w.day_night.glow_factor)
	var p: Node2D = w.player
	p.global_position = a.cell_to_global(Vector2i(1, 5))
	var cam: Camera2D = p.get("camera")
	cam.zoom = Vector2.ONE * 0.9
	cam.global_position = a.cell_to_global(Vector2i(6, 3))
	cam.position_smoothing_enabled = false
	cam.reset_smoothing()
	await t.seconds(0.5)
	var img: Image = await t.capture("look_sheet")
	var ct: Transform2D = w.get_viewport().get_canvas_transform()
	var chest_at := func(cell: Vector2i) -> Rect2i:
		var px: Vector2i = Vector2i(ct * a.cell_to_global(cell))
		return Rect2i(px.x - 34, px.y - 82, 68, 70)
	var closed_luma: Array[float] = []
	var open_luma: Array[float] = []
	for pair in [[Vector2i(3, 1), Vector2i(3, 3)], [Vector2i(5, 1), Vector2i(5, 3)], [Vector2i(7, 1), Vector2i(7, 3)], [Vector2i(9, 1), Vector2i(9, 3)]]:
		var sc: Dictionary = t.region_stats(img, chest_at.call(pair[0]), 2)
		var so: Dictionary = t.region_stats(img, chest_at.call(pair[1]), 2)
		closed_luma.append(float(sc["luma_mean"]))
		open_luma.append(float(so["luma_mean"]))
		t.expect(int(sc["distinct"]) > 12 and int(so["distinct"]) > 12, "windowed: the chest at %s and its opened twin at %s are drawn (%d / %d distinct colours)" % [pair[0], pair[1], int(sc["distinct"]), int(so["distinct"])])
	var darker := 0
	for i in 4:
		darker += 1 if open_luma[i] < closed_luma[i] - 0.02 else 0
	t.check("look_opened_chests_are_darker", darker == 4, "windowed: every opened chest reads darker than its closed twin (closed %s, opened %s mean luma)" % [str(closed_luma.map(func(v: float) -> String: return "%.3f" % v)), str(open_luma.map(func(v: float) -> String: return "%.3f" % v))])
	var lake := chest_at.call(Vector2i(11, 1)) as Rect2i
	t.expect(int(t.region_stats(img, lake, 2)["distinct"]) > 12, "windowed: the lake chest (art chest_noegle or the konge chest with the brass padlock) is drawn")
	# the sparkle burst: open the closed trae chest and look a few frames later
	var chest := _node_of(a, "chest") as LootChest2D
	_fresh_window_state()
	chest.interact(p)
	await t.seconds(0.25)
	var burst_img: Image = await t.capture("look_burst")
	var burst_nodes := 0
	for c in chest.get_children():
		burst_nodes += 1 if c is CPUParticles2D else 0
	t.expect(burst_nodes >= 1 or chest.is_open, "windowed: opening a chest fires a sparkle burst (%d particle node, chest open %s)" % [burst_nodes, str(chest.is_open)])
	t.expect_not_blank(burst_img, Rect2i(200, 100, 880, 480), "windowed: the look sheet after the burst is not blank")
	# the padlock fallback of the lake chest (what the player sees until chest_noegle has art): konge chest + brass padlock, next to the real art
	WorldRoot2D.register_map(&"_t_loot_padlock", AreaMap.parse_text(PADLOCK_MAP))
	LootChest2D.force_fallback_art = true
	w._enter(&"_t_loot_padlock", &"default")
	LootChest2D.force_fallback_art = false
	var pa: IsoArea = w.area
	w.day_night.override_hour = 11.0
	w.day_night.snap()
	var pcam: Camera2D = p.get("camera")
	pcam.zoom = Vector2.ONE * 1.6
	pcam.global_position = pa.cell_to_global(Vector2i(3, 2)) + Vector2(0, -30)
	pcam.position_smoothing_enabled = false
	pcam.reset_smoothing()
	await t.seconds(0.4)
	var pimg: Image = await t.capture("look_padlock")
	var pct: Transform2D = w.get_viewport().get_canvas_transform()
	var brass := 0
	var padlock_chest := _node_of(pa, "chest") as LootChest2D
	var pc: Vector2i = Vector2i(pct * padlock_chest.global_position)
	for y in range(pc.y - 160, pc.y + 20):
		for x in range(pc.x - 100, pc.x + 100):
			if x >= 0 and y >= 0 and x < pimg.get_width() and y < pimg.get_height() and t.color_delta(pimg.get_pixel(x, y), LootChest2D.PADLOCK_COLOUR) < 28.0:
				brass += 1
	t.check("look_padlock_fallback_is_drawn", padlock_chest != null and padlock_chest.padlock_drawn and padlock_chest.art_id == "chest_konge" and brass > 60, "windowed: with chest_noegle forced away the lake chest is the konge chest with a brass padlock (%d brass pixels around it)" % brass)
	w._enter(&"_fixture_iso", &"default")
	WorldRoot2D.unregister_map(&"_t_loot_padlock")
	w._enter(&"_t_loot_look", &"default")
	# the REAL area cache: leave the look sheet (it is parked outside the tree), let seven days pass, come back: the chest is respawned (signals reconnected on re-entry, state re-read)
	var opened_before := chest.is_open
	w._enter(&"_fixture_iso", &"default")
	var parked_outside: bool = not a.is_inside_tree()
	Fresh.jump_to_total_day(10)
	w._enter(&"_t_loot_look", &"default")
	t.check("look_parked_area_respawns_its_chest", opened_before and parked_outside and a.is_inside_tree() and not chest.is_open, "windowed: the look sheet was parked by WorldRoot2D's cache (outside the tree: %s), seven days later the chest in it is closed again (%s)" % [str(parked_outside), str(not chest.is_open)])
	w._enter(&"_fixture_iso", &"default")
	WorldRoot2D.unregister_map(&"_t_loot_look")


func _fresh_window_state() -> void:
	ls.set_loot_config(null)
	eco = t.autoload("EconomyManager")
	_free_slots_to(6)
