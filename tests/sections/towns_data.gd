extends RefCounted
## Section towns_data (package T-towns-core, wave M1b-1; TOWNS addendum 4.1 / 4.5, CLOCK_26 CK-A-TC, GHOST_FAMILY AGF4): the DATA of the towns track and the ONE opening-hours rule.
##
##   config            lua/towns.lua = config key `towns` (the constants, the festival cap, the curfew on the 26 hour day)
##   buildings         lua/buildings/{traetoppen,hyggebyen}.lua: the 20 CORE rows (schema, shop ids, late ids, service rows, hours consistency, the opening days at noon, emblems)
##   the Hours rule    scripts/towns/hours.gd: the rule table, the clock-only context, the switch, the after-midnight notation, overrides, empty tables, the festival closure, the weekday of the game day
##   copy              localization/towns.csv: BLD_ (30), HOURS_, ACT_ (15 with `hide`), COUNTER_ - da and en, no raw keys, copy rules
##   fixtures          the fixture town (9 buildings, 6 citizens), the three sample rooms, the mutation helper
##   hooks             the registry kind seen from this package, ShopSystem's hours hook (through ShopHoursGate), the weekday rule of an unclaimed shop
##   forward refs      no script of the package names a class of a later wave (the identifier scan + every script reloads without a parse error)
##
## Which clock this section runs at (TOWNS addendum DT55): it IS about opening hours, so the switch towns.hours_enabled stays ON (the default) and every check sets the game clock or passes a context
## explicitly (Monday 12:00 unless a check names another moment). The section is a sandbox: the fixture registries, Svc fakes, config overrides, the gate's script path and the clock are put back.
##
## Named checks (prefix towns_data.): config_complete, constants_keys, festival_cap_covers_the_crowd, curfew_config_on_the_26_hour_day, buildings_schema, shop_ids_exist, late_shop_ids_listed_not_failed,
## service_rows_have_no_shop_id, hours_consistency, opening_days_at_noon, hours_rule_table, hours_now_ctx_is_clock_only, hours_switch_off_answers_null, hours_wrap_midnight, hours_after_midnight,
## hours_weekday_is_the_game_day, hours_minutes_to_close_after_midnight, hours_format_hour_wraps, hours_validator_accepts_close_up_to_the_day_end, hours_override_weekday, hours_empty_table_is_no_days,
## festival_closure_via_ctx, keys_da_en_complete, copy_lint_clean_for_towns, act_hide_known, fixtures_load, mutants_are_caught, registry_kind_loads_lints_and_claims, shop_system_hook,
## unclaimed_shop_keeps_weekday_rule, emblem_ids_exist_when_manifest_present, no_forward_class_refs, wave4_scripts_load_without_later_files, multi_building_shop.
const SECTION := "towns_data"
const TIMEOUT_S := 180.0

const Ctx := preload("res://tests/lib/towns/contexts.gd")
const FakeSocialScript := preload("res://tests/lib/towns/fake_social.gd")
const Rules := preload("res://tests/lib/towns/consistency.gd")
const Mutate := preload("res://tests/lib/towns/mutate.gd")
const Refs := preload("res://tests/lib/towns/forward_refs.gd")
const Gate := preload("res://scripts/economy/shop_hours_gate.gd")

const FIX := "res://tests/fixtures/towns/lua/"
const CSV_PATH := "res://localization/towns.csv"
const SCRIPTS: Array[String] = ["res://scripts/towns/hours.gd", "res://scripts/towns/interior_room.gd", "res://scripts/towns/piece_catalog.gd", "res://scripts/towns/door_2d.gd",
		"res://scripts/towns/shop_counter.gd", "res://scripts/towns/shop_hours.gd"]
## The later files of the towns track (T-routes wave 5, T-director wave 5b): present or absent, nothing of this package may need them.
const LATER_FILES: Array[String] = ["res://scripts/towns/routines.gd", "res://scripts/towns/route_table.gd", "res://scripts/towns/nav_grid.gd", "res://scripts/towns/npc_director.gd",
		"res://scripts/towns/town_director.gd", "res://scripts/towns/town_marker.gd", "res://scripts/towns/citizen_stub.gd"]
## The 30 buildings of both towns (TOWNS addendum 4.1): the 20 CORE rows live in this package, the 10 EXTENDED rows in lua/buildings/ext.lua (T-ext-content); the names (BLD_) are all here.
const CORE_IDS: Array[String] = ["uglehulen", "postkontoret", "brummes_vaerksted", "fjerpens_hytte", "badehuset", "gaestehytten", "koekkenhave_skuret", "raadhuset", "torvestanden", "natteblik_vinduet",
		"froebutikken", "bageriet", "smedjen", "dyrehuset", "troldmandstaarnet", "moebelbutikken", "skraedderiet", "toemmerhandlen", "loppeloftet", "pingvinens_hus"]
const EXT_IDS: Array[String] = ["hoppe_hut", "vagthytten", "brummes_hus", "kikis_hytte", "torvekroen", "musikstuen", "fekongens_hus", "hyldeblomsts_hus", "pippins_hus", "birks_bistade"]
## The 15 acts of the routine vocabulary (14 of design3 + `hide`, GHOST_FAMILY AGF4) and the 15 emblem plates of the I3 kit.
const ACTS: Array[String] = ["sit", "eat", "inside", "sleep", "work", "tend", "stand", "play", "fish", "patrol", "perch", "guard", "lamp", "away", "hide"]
const EMBLEMS: Array[String] = ["seed", "loaf", "anvil", "crystal", "paw", "plank", "chair", "thread", "posthorn", "tub", "scroll", "carrot", "hammer", "junk", "log"]
const HOURS_KEYS: Array[String] = ["HOURS_CLOSED_NOW", "HOURS_CLOSED_DAY", "HOURS_CLOSED_FESTIVAL", "HOURS_CLOSING_SOON", "HOURS_CLOSED_BELL", "HOURS_HOME_AWAY", "HOURS_HOME_STRANGER",
		"HOURS_HOME_LOCKED", "HOURS_CURFEW_SOON", "HOURS_CURFEW_HOME", "HOURS_SIGN"]
const COUNTER_KEYS: Array[String] = ["COUNTER_SHOP", "COUNTER_TALK", "COUNTER_DESK", "COUNTER_APPRAISE", "COUNTER_APPRAISE_SOON"]
## The retired town name, written in two halves so the repository never contains it (the same trick as tests/tools/check_project.gd).
const RETIRED_TOWN := "Fe" + "sby"

var t
var lr: Node
var gm: Node
var tm: Node
var lm: Node
var _fakes: Array[Node] = []
var _fixture_buildings: Dictionary = {}
var _fixture_citizens: Dictionary = {}


func run(p_t) -> void:
	t = p_t
	lr = t.autoload("LuaRuntime")
	gm = t.autoload("GameManager")
	tm = t.autoload("TimeManager")
	lm = t.autoload("LocalizationManager")
	if lr == null or gm == null or tm == null or lm == null:
		return
	await t.go_menu()
	t.new_game()
	Hours.override_registry = {}
	Gate.use_hours_script()
	_config()
	_buildings()
	_hours_rules()
	_copy()
	_fixtures_and_mutants()
	_registry_kind()
	_shop_system()
	_forward_refs()
	_cleanup()


# ================================================================================================ helpers

func _fresh() -> void:
	_release_fakes()
	gm.clear_config_overrides()
	Hours.override_registry = {}
	Gate.use_hours_script()
	t.new_game()
	Ctx.set_clock(gm, 0, 12.0)


func _fake_social() -> Node:
	var n: Node = FakeSocialScript.new()
	_fakes.append(n)
	Svc.override("SocialManager", n)
	return n


func _release_fakes() -> void:
	Svc.clear_overrides()
	for n in _fakes:
		if is_instance_valid(n):
			n.free()
	_fakes.clear()


func _cleanup() -> void:
	_release_fakes()
	gm.clear_config_overrides()
	Hours.override_registry = {}
	Gate.use_hours_script()
	lr.reload_scripts()                     # drops the fixture registries the checks loaded
	t.new_game()


func _open(id: String, wd: int, hour: float) -> bool:
	return Hours.is_open(id, Ctx.at(wd, hour))


func _row(id: String) -> Dictionary:
	return Hours.building(id)


func _load_fixture_town() -> void:
	if not _fixture_buildings.is_empty():
		return
	lr.load_file(FIX + "fixture_buildings.lua")
	lr.load_file(FIX + "fixture_citizens.lua")
	_fixture_buildings = lr.get_registry("towns_fixture_buildings")
	_fixture_citizens = lr.get_registry("towns_fixture_citizens")


func _csv_rows() -> Dictionary:
	var data: Dictionary = lm.read_csv(CSV_PATH)
	var rows: Dictionary = {}
	if data.is_empty():
		return rows
	for r in (data["rows"] as Array):
		var cells: PackedStringArray = r["cells"]
		var key: String = cells[0].strip_edges() if cells.size() > 0 else ""
		if key == "" or key.begins_with(";") or key.begins_with("#") or cells.size() < 3:
			continue
		rows[key] = {"da": cells[1], "en": cells[2], "line": int(r["line"])}
	return rows


func _npc_rows() -> Dictionary:
	return lr.get_npcs()


func _known_shop_ids() -> Array:
	return lr.get_shops().keys()


# ================================================================================================ config

func _config() -> void:
	var cfg: Dictionary = GameData.dict_of(lr.get_config("towns", {}))
	var rain: Dictionary = GameData.dict_of(cfg.get("rain_shelter", {}))
	var curfew: Dictionary = GameData.dict_of(cfg.get("curfew", {}))
	var walk: float = float(GameData.player_cfg("walk_speed", 0.0))
	var speed_ok: bool = is_equal_approx(float(cfg.get("npc_speed", 0.0)), 0.65) and walk == 285.0 and absf(walk * float(cfg["npc_speed"]) - 185.25) < 0.01
	var acts_ok: bool = rain.get("acts", []) == ["sit", "tend", "play", "fish"] and is_equal_approx(float(rain.get("from", 0.0)), 8.0) and is_equal_approx(float(rain.get("to", 0.0)), 19.0)
	var rest_ok: bool = is_equal_approx(float(cfg.get("portal_seconds", 0.0)), 0.5) and int(cfg.get("max_live_visuals", 0)) == 16 and int(cfg.get("plan_visual_peak", 0)) == 14 \
		and is_equal_approx(float(cfg.get("live_min_dwell", 0.0)), 0.05) and int(cfg.get("closing_whisper_minutes", 0)) == 30 and is_equal_approx(float(cfg.get("carrot_max_speed", 0.0)), 1.6) \
		and cfg.get("hours_enabled", null) == true and bool(curfew.get("enabled", false))
	t.check("config_complete", not cfg.is_empty() and speed_ok and acts_ok and rest_ok,
		"npc_speed 0.65 of the player's walk speed %s = %s px/s (185) %s; portal_seconds 0.5, max_live_visuals 16 (hard cap), plan_visual_peak 14, live_min_dwell 0.05, closing_whisper_minutes 30, carrot_max_speed 1.6, hours_enabled true, curfew enabled %s; rain_shelter acts sit tend play fish from 8 to 19 %s" % [
			str(walk), str(walk * float(cfg.get("npc_speed", 0.0))), speed_ok, rest_ok, acts_ok])
	var expected: Array = ["npc_speed", "portal_seconds", "max_live_visuals", "max_live_visuals_festival", "plan_visual_peak", "live_min_dwell", "rain_shelter", "closing_whisper_minutes",
			"curfew", "carrot_max_speed", "hours_enabled"]
	var keys: Array = cfg.keys()
	keys.sort()
	expected.sort()
	var collides: bool = not lr.get_registry("towns").is_empty() or lr.get_config("buildings", null) != null
	t.check("constants_keys", keys == expected and not collides, "exactly the 11 constants %s (no unowned extra), the key `towns` does not collide with a registry name (get_registry(\"towns\") is empty %s)" % [str(keys), not collides])
	var crowd: int = 15 + 1 + 4
	var attendees: Variant = lr.get_config("social.festival.max_attendees", null)
	var attendees_ok: bool = attendees == null or int(attendees) == 15
	var cap: int = int(cfg.get("max_live_visuals_festival", 0))
	t.check("festival_cap_covers_the_crowd", cap == crowd and cap > int(cfg.get("max_live_visuals", 0)) and int(cfg.get("max_live_visuals", 0)) == 16 and int(cfg.get("plan_visual_peak", 0)) <= 16 and attendees_ok,
		"max_live_visuals_festival %d = 15 attendees + the host 1 + the four family members 4 = %d (social.festival.max_attendees %s); the ordinary day cap stays 16 and the plan peak 14" % [cap, crowd, str(attendees) if attendees != null else "not built yet, 15 by contract"])
	var whisper: float = float(curfew.get("whisper", 0.0))
	var home: float = float(curfew.get("go_home", 0.0))
	var end_hour: int = gm.day_end_hour()
	t.check("curfew_config_on_the_26_hour_day", whisper == 25.5 and home == 25.75 and end_hour == 26 and absf((float(end_hour) - whisper) * 60.0 - 30.0) < 0.01 and absf((float(end_hour) - home) * 60.0 - 15.0) < 0.01 \
		and whisper < home and home < float(end_hour),
		"curfew whisper %s (01:30) and go_home %s (01:45) on the axis 6..26: the same 30 / 15 minute cushions before the 02:00 pass-out (day end %d); format %s / %s" % [str(whisper), str(home), end_hour, Hours.format_hour(whisper), Hours.format_hour(home)])


# ================================================================================================ buildings

func _buildings() -> void:
	var reg: Dictionary = Hours.registry()                                                # the CORE rows of this package; ext.lua (T-ext-content, wave 6) adds the EXTENDED ones later
	var core_reg: Dictionary = {}
	for id in reg:
		if str(id) in CORE_IDS:
			core_reg[id] = reg[id]
	var ids: Array = core_reg.keys()
	ids.sort()
	var core_sorted: Array = CORE_IDS.duplicate()
	core_sorted.sort()
	var kinds: Dictionary = {}
	var rooms: int = 0
	for id in core_reg:
		var row: Dictionary = core_reg[id]
		kinds[str(row.get("kind", ""))] = int(kinds.get(str(row.get("kind", "")), 0)) + 1
		if str(row.get("interior", "")) != "":
			rooms += 1
	var ext_ok: bool = true
	for id in reg:
		if not core_reg.has(id):
			ext_ok = ext_ok and str((reg[id] as Dictionary).get("wave", "")) in ["core", "ext"]
	var emblem_ids: Array = []
	for k in EMBLEMS:
		emblem_ids.append(k)
	var schema: Array[String] = Rules.schema_problems(reg, {"emblem_ids": emblem_ids})
	for id in core_reg:
		var one: Array[String] = Rules.schema_problems({id: core_reg[id]}, {"emblem_ids": emblem_ids})
		var row: Dictionary = core_reg[id]
		t.expect(one.is_empty(), "building %s (%s%s) matches the row schema%s" % [id, row.get("kind", "?"), ", room " + str(row["interior"]) if row.has("interior") else ", no room", "" if one.is_empty() else ": " + str(one)])
	var shape_ok: bool = kinds == {"shop": 11, "service": 3, "public": 1, "stall": 2, "home": 3} and rooms == 15
	t.check("buildings_schema", schema.is_empty() and ids == core_sorted and shape_ok and ext_ok,
		"the 20 CORE rows of lua/buildings/{traetoppen,hyggebyen}.lua (area, kind, name_key BLD_<ID>, interior int_<id> + size, keeper, post, emblem, hours, wave core); kinds %s, 14 with a room (%d), 3 locked nameplate homes, 2 stalls, 1 decor hut; %d schema problems %s" % [
			str(kinds), rooms, schema.size(), str(schema.slice(0, 3))])
	# every shop id exists; the LATE ids (wave 4 like this package: no dependency edge is possible) are listed by name
	var known: Array = _known_shop_ids()
	var res: Dictionary = Rules.shop_problems(reg, {"known_shops": known, "check_shops": true})
	var problems: Array = res["problems"]
	var missing_late: Array = res["late_missing"]
	var shop_ids: Array = []
	for id in reg:
		if (reg[id] as Dictionary).has("shop"):
			var s: String = str((reg[id] as Dictionary)["shop"])
			if not (s in shop_ids):
				shop_ids.append(s)
	shop_ids.sort()
	t.check("shop_ids_exist", problems.is_empty() and shop_ids.size() >= 12,
		"the canonical 12 shop ids and any extensions in the registry %s: every one except the late ids is defined by a shop file (%d problems %s)" % [str(shop_ids), problems.size(), str(problems)])
	for late in missing_late:
		t.skip("towns_data.shop_ids_exist: LATE shop id %s (owner %s, wave 4 like this package) has no shop file yet: listed, not failed; towns_interiors_core.every_shop_marker_resolves and towns_director.stall_shop_ids_resolve REQUIRE it" % [late, Rules.LATE_SHOP_IDS[late]])
	# the late-id logic itself, whatever the tree holds: a registry whose late ids have no shop file passes and names them; any other missing id fails
	var without_late: Array = known.filter(func(s: Variant) -> bool: return not Rules.LATE_SHOP_IDS.has(str(s)))
	var listed: Dictionary = Rules.shop_problems(reg, {"known_shops": without_late, "check_shops": true})
	var broken: Dictionary = Rules.shop_problems(reg, {"known_shops": without_late.filter(func(s: Variant) -> bool: return str(s) != "seed_shop"), "check_shops": true})
	t.check("late_shop_ids_listed_not_failed", (listed["problems"] as Array).is_empty() and listed["late_missing"] == ["natteblik_maps", "timber_yard"] and Rules.LATE_SHOP_IDS == {"timber_yard": "V1-cast-data", "natteblik_maps": "DR7-dungeon-services"} \
		and (broken["problems"] as Array).size() == 1 and str(broken["problems"][0]).contains("seed_shop"),
		"without the two late shop files the rule lists them by name %s and fails nothing; a missing seed_shop is the one problem %s" % [str(listed["late_missing"]), str(broken["problems"])])
	var services: Array = []
	var service_ok: bool = true
	for id in reg:
		var row: Dictionary = reg[id]
		if str(row.get("kind", "")) == "service":
			services.append(str(id))
			service_ok = service_ok and not row.has("shop")
	var retired_draft: bool = lr.get_shop("fru_ugle_vurdering").is_empty() and not _text_of(FileAccess.get_file_as_string("res://lua/buildings/traetoppen.lua")).contains("fru_ugle_vurdering")
	services.sort()
	t.check("service_rows_have_no_shop_id", service_ok and services == ["badehuset", "postkontoret", "uglehulen"] and not (reg["uglehulen"] as Dictionary).has("shop") and retired_draft,
		"the service rows %s carry no `shop` (Uglehulen's appraisal is design2's game_event open_appraisal, not a ShopSystem shop; the draft id fru_ugle_vurdering never existed)" % str(services))
	# hours consistency of the real data (the late ids are skipped above)
	var npcs: Dictionary = _npc_rows()
	var hp: Array[String] = Rules.hours_problems(reg, {"npcs": npcs})
	var all_problems: Array[String] = Rules.problems(reg, {"npcs": npcs, "known_shops": known, "emblem_ids": emblem_ids})
	t.check("hours_consistency", hp.is_empty() and all_problems.is_empty(),
		"hours.consistency on the real registry: every shop, service, public building and stall has hours, is open >= 6 game hours (the night window of Natteblik is short_ok), closes by 26:00, closes on weekdays 0..6, and its keeper is a citizen with a routine (%d problems %s)" % [
			all_problems.size(), str(all_problems.slice(0, 3))])
	# the opening days at noon (design_towns.md 4.5): 7 / 8 / 8 / 8 / 8 / 10 / 8 of the 10 shops are open at 12:00
	var counts: Array = []
	var shop_list: Array = ["seed_shop", "bakery", "smithy", "animal_store", "magic_store", "furniture_shop", "tailor_shop", "builder_yard", "flea_market", "timber_yard"]
	for wd in 7:
		var n: int = 0
		for s in shop_list:
			if Hours.shop_open(s, Ctx.at(wd, 12.0)) == true:
				n += 1
		counts.append(n)
	var want_counts: Array = [7, 8, 8, 8, 8, 10, 8]
	for wd in 7:
		t.expect(counts[wd] == want_counts[wd], "%d of 10 shops are open at 12:00 on %s (design: %d)" % [counts[wd], Hours.weekday_text(wd), want_counts[wd]])
	t.check("opening_days_at_noon", counts == [7, 8, 8, 8, 8, 10, 8], "open shops of 10 at 12:00 Monday .. Sunday: %s (design: 7 8 8 8 8 10 8; the workshop and the Torvet stall count as ONE shop, timber_yard)" % str(counts))
	# emblems: every row's plate is one of the 15 plates; when the I3 manifest exists it lists them all
	var emblem_ok: bool = true
	var used: Array = []
	for id in reg:
		var e: String = str((reg[id] as Dictionary).get("emblem", ""))
		if e != "":
			used.append(e)
			emblem_ok = emblem_ok and e in EMBLEMS
	var kit_emblems: Array = PieceCatalog.kit_emblems().keys()
	kit_emblems.sort()
	var plates: Array[String] = PieceCatalog.emblem_ids()
	var manifest_ok: bool = plates.is_empty() or (plates.size() == 15 and used.all(func(e: Variant) -> bool: return str(e) in plates))
	var sorted_emblems: Array = EMBLEMS.duplicate()
	sorted_emblems.sort()
	t.check("emblem_ids_exist_when_manifest_present", emblem_ok and kit_emblems == sorted_emblems and manifest_ok and used.size() == 14,
		"the %d rows with an emblem name one of the 15 plates of the kit table (the 14 shop and service rooms + Brumme's stall); %s" % [used.size(),
			"assets/iso_props/shops/core/emblems.json lists all 15 plates" if not plates.is_empty() else "the I3 emblems.json does not exist yet: the plates are checked against the kit table only"])


func _text_of(s: String) -> String:
	return s


# ================================================================================================ the Hours rule

func _hours_rules() -> void:
	_fresh()
	_load_fixture_town()
	_rule_table()
	_now_ctx()
	_switch()
	_midnight()
	_game_day()
	_minutes_and_format()
	_validator_day_end()
	_overrides_and_empty()
	_festival()
	_multi_building()


func _rule_table() -> void:
	var rows: Array = [
		["bageriet", 1, 10.0, true], ["bageriet", 0, 10.0, false], ["bageriet", 1, 6.5, false], ["bageriet", 1, 17.0, false], ["bageriet", 1, 16.99, true], ["bageriet", 1, 7.0, true],
		["froebutikken", 6, 12.0, false], ["froebutikken", 5, 12.0, true], ["loppeloftet", 2, 12.0, false], ["loppeloftet", 5, 12.0, true], ["badehuset", 3, 20.5, true], ["badehuset", 3, 21.0, false],
		["raadhuset", 5, 10.0, false], ["raadhuset", 2, 10.0, true], ["uglehulen", 3, 14.0, false], ["uglehulen", 2, 14.0, true], ["uglehulen", 2, 11.9, false],
		["natteblik_vinduet", 3, 21.0, true], ["natteblik_vinduet", 3, 12.0, false], ["natteblik_vinduet", 3, 23.6, false], ["natteblik_vinduet", 3, 23.49, true],
		["torvestanden", 5, 12.0, true], ["torvestanden", 2, 12.0, false], ["smedjen", 6, 12.0, false], ["dyrehuset", 3, 12.0, false], ["troldmandstaarnet", 1, 12.0, false],
		["moebelbutikken", 2, 12.0, false], ["skraedderiet", 0, 12.0, false], ["toemmerhandlen", 4, 12.0, false], ["brummes_vaerksted", 5, 12.0, false], ["brummes_vaerksted", 2, 12.0, true],
		["postkontoret", 6, 12.0, false], ["postkontoret", 0, 9.0, true], ["fjerpens_hytte", 3, 3.0, true],
	]
	var bad: Array[String] = []
	for r in rows:
		var got: bool = _open(str(r[0]), int(r[1]), float(r[2]))
		t.expect(got == bool(r[3]), "hours rule: %s on %s at %s is %s (%s)" % [r[0], Hours.weekday_text(int(r[1])), Hours.format_hour(float(r[2])), "open" if got else "shut", "as the table says" if got == bool(r[3]) else "the table says " + str(r[3])])
		if got != bool(r[3]):
			bad.append("%s wd%d %.2f expected %s got %s" % [r[0], r[1], r[2], r[3], got])
	# what the state says when it is closed: the reason, the NEXT opening (hour and weekday)
	var s_mon: Dictionary = Hours.state("bageriet", Ctx.at(0, 10.0))
	var s_early: Dictionary = Hours.state("bageriet", Ctx.at(1, 6.0))
	var s_late: Dictionary = Hours.state("bageriet", Ctx.at(1, 18.0))
	var s_sat: Dictionary = Hours.state("bageriet", Ctx.at(5, 18.0))
	var s_sun: Dictionary = Hours.state("bageriet", Ctx.at(6, 18.0))
	var s_flea: Dictionary = Hours.state("loppeloftet", Ctx.at(0, 12.0))
	var s_open: Dictionary = Hours.state("bageriet", Ctx.at(1, 10.0))
	var s_home: Dictionary = Hours.state("fjerpens_hytte", Ctx.at(3, 3.0))
	t.expect(s_mon["reason"] == "day" and not s_mon["open"] and s_mon["next_weekday"] == 1 and is_equal_approx(float(s_mon["opens_at"]), 7.0), "state: the bakery on a Monday is closed for the DAY and next opens Tuesday 07:00")
	t.expect(s_early["reason"] == "hours" and s_early["next_weekday"] == 1 and is_equal_approx(float(s_early["opens_at"]), 7.0), "state: Tuesday 06:00 is closed for HOURS, opening 07:00 today")
	t.expect(s_late["reason"] == "hours" and s_late["next_weekday"] == 2 and is_equal_approx(float(s_late["opens_at"]), 7.0), "state: Tuesday 18:00 is closed for HOURS, the next opening is Wednesday 07:00")
	t.expect(s_sat["next_weekday"] == 6 and s_sun["next_weekday"] == 1, "state: Saturday 18:00 -> next Sunday; Sunday 18:00 -> next Tuesday (Monday is the closed day)")
	t.expect(s_flea["reason"] == "day" and s_flea["next_weekday"] == 5 and is_equal_approx(float(s_flea["opens_at"]), 10.0), "state: the flea loft on a Monday -> next Saturday 10:00")
	t.expect(s_open["open"] and s_open["reason"] == "open" and is_equal_approx(float(s_open["closes_at"]), 17.0), "state: an open bakery reports reason open and closes at 17.0")
	t.expect(s_home["open"] and s_home["reason"] == "none" and is_equal_approx(float(s_home["closes_at"]), 26.0), "state: a row without hours (a home) reads reason none and closes at the day end 26.0")
	var states_ok: bool = s_mon["reason"] == "day" and not s_mon["open"] and s_mon["next_weekday"] == 1 and is_equal_approx(float(s_mon["opens_at"]), 7.0) \
		and s_early["reason"] == "hours" and s_early["next_weekday"] == 1 and is_equal_approx(float(s_early["opens_at"]), 7.0) \
		and s_late["reason"] == "hours" and s_late["next_weekday"] == 2 and is_equal_approx(float(s_late["opens_at"]), 7.0) \
		and s_sat["next_weekday"] == 6 and s_sun["next_weekday"] == 1 \
		and s_flea["reason"] == "day" and s_flea["next_weekday"] == 5 and is_equal_approx(float(s_flea["opens_at"]), 10.0) \
		and s_open["open"] and s_open["reason"] == "open" and is_equal_approx(float(s_open["closes_at"]), 17.0) \
		and s_home["open"] and s_home["reason"] == "none" and is_equal_approx(float(s_home["closes_at"]), 26.0)
	t.check("hours_rule_table", bad.is_empty() and states_ok,
		"%d rows over the real registry (open <= hour < close on a weekday not in `closed`; a row without hours is always open) %s; states: Monday the bakery is closed for the DAY and next opens Tuesday 07:00 %s, Tuesday 06:00 for HOURS (07:00 today) %s, Tuesday 18:00 next Wednesday %s, Saturday 18:00 next Sunday and Sunday 18:00 next Tuesday (Monday is closed) %s, the flea loft on a Monday next Saturday 10:00 %s; an open state closes at 17.0 %s, a home reads reason none and closes at the day end 26.0 %s" % [
			rows.size(), "ALL AGREE" if bad.is_empty() else "DISAGREE " + str(bad), s_mon["reason"] == "day", s_early["reason"] == "hours", s_late["next_weekday"] == 2, s_sat["next_weekday"] == 6 and s_sun["next_weekday"] == 1,
			s_flea["next_weekday"] == 5, s_open["open"], s_home["reason"] == "none"])


func _now_ctx() -> void:
	_fresh()
	Ctx.set_clock(gm, 2, 13.5)
	var c: Dictionary = Hours.now_ctx()
	var has_social: bool = Svc.node("SocialManager") != null and Svc.node("SocialManager").has_method("shop_closed_by_festival")
	var keys: Array = c.keys()
	keys.erase("fest_closed_fn")                                                          # present only while a SocialManager exists (S-core): late bound
	keys.sort()
	var clock_only: bool = keys == ["hour", "season", "total_day", "weather", "weekday"] and c["weekday"] == tm.weekday_index() and c["weekday"] == 2 and is_equal_approx(float(c["hour"]), 13.5) \
		and str(c["season"]) == "foraar" and int(c["total_day"]) == gm.total_day() and str(c["weather"]) == str(tm.weather) and c.has("fest_closed_fn") == has_social
	var none_of_routines: bool = not c.has("hero") and not c.has("hearts") and not c.has("flags")
	# with a social manager the festival closure comes along as a Callable; the context still has no hero or hearts
	var social: Node = _fake_social()
	var with_social: Dictionary = Hours.now_ctx()
	var callable_ok: bool = with_social.get("fest_closed_fn") is Callable and (with_social["fest_closed_fn"] as Callable).is_valid() and not with_social.has("hero") and not with_social.has("hearts")
	social.closed_shops = ["bakery"]
	var answers: bool = bool((with_social["fest_closed_fn"] as Callable).call("bakery")) and not bool((with_social["fest_closed_fn"] as Callable).call("seed_shop"))
	_release_fakes()
	Ctx.set_clock(gm, 6, 25.5)
	var night: Dictionary = Hours.now_ctx()
	var raw_hour_ok: bool = is_equal_approx(float(night["hour"]), 25.5) and night["weekday"] == 6
	t.check("hours_now_ctx_is_clock_only", clock_only and none_of_routines and callable_ok and answers and raw_hour_ok,
		"now_ctx = {weekday, hour, season, total_day, weather} read from GameManager and TimeManager (Wednesday 13:30 -> weekday 2, hour 13.5) %s, no hero, hearts or flags (Routines.now_ctx of T-routes extends it later) %s, the festival closure only as a late-bound Callable when SocialManager exists %s (answers %s), the raw hour 25.5 stays 25.5 on Sunday %s" % [
			clock_only, none_of_routines, callable_ok, answers, raw_hour_ok])


func _switch() -> void:
	_fresh()
	var before: Variant = Hours.shop_open("bakery", Ctx.at(0, 12.0))                  # Monday: closed by the building
	gm.set_config_override("towns.hours_enabled", false)
	var off_mon: Variant = Hours.shop_open("bakery", Ctx.at(0, 12.0))
	var off_tue: Variant = Hours.shop_open("bakery", Ctx.at(1, 12.0))
	var off_enabled: bool = Hours.enabled()
	var gate_off: Variant = Gate.open_override("bakery")
	Ctx.set_clock(gm, 0, 12.0)
	var shop: Node = t.autoload("ShopSystem")
	var shop_off: bool = shop.is_open("bakery")                                          # the def has no open_weekdays: with the rule off the bakery is always open
	var info_off: Dictionary = shop.get_shop_info("bakery")
	gm.clear_config_overrides()
	var on_again: Variant = Hours.shop_open("bakery", Ctx.at(0, 12.0))
	var shop_on: bool = shop.is_open("bakery")
	t.check("hours_switch_off_answers_null", before == false and off_mon == null and off_tue == null and not off_enabled and gate_off == null and shop_off and not info_off.has("closed_reason") \
		and on_again == false and not shop_on and Hours.enabled(),
		"towns.hours_enabled (default true): Monday 12:00 the bakery is closed %s; with the switch OFF Hours.shop_open answers null on every day (%s / %s), the gate answers null %s, ShopSystem.is_open is the def's own rule (open: %s, no closed_reason: %s); ON again: false %s, ShopSystem closed %s" % [
			before == false, str(off_mon), str(off_tue), gate_off == null, shop_off, not info_off.has("closed_reason"), on_again == false, not shop_on])


func _midnight() -> void:
	_fresh()
	var reg: Dictionary = _fixture_buildings
	Hours.override_registry = reg
	var bar: Dictionary = reg["fx_night_bar"]                                           # open 20, close 1: the notation "close < open" = after midnight of the SAME game day
	var oc: Array = Hours.hours_on(bar, 3)
	var zero: Dictionary = {"area": "fx_town", "kind": "public", "hours": {"open": 20, "close": 0, "closed": []}}              # close 0 = 24.0
	var zero_oc: Array = Hours.hours_on(zero, 0)
	var thu_22: bool = _open("fx_night_bar", 3, 22.0)
	var thu_2430: bool = _open("fx_night_bar", 3, 24.5)
	var thu_2459: bool = _open("fx_night_bar", 3, 24.99)
	var thu_2500: bool = _open("fx_night_bar", 3, 25.0)
	var thu_2530: bool = _open("fx_night_bar", 3, 25.5)
	var thu_19: bool = _open("fx_night_bar", 3, 19.9)
	var fri_22: bool = _open("fx_night_bar", 4, 22.0)                                    # closed on Friday (weekday 4)
	var st: Dictionary = Hours.state("fx_night_bar", Ctx.at(3, 25.5))
	Hours.override_registry = {"fx_zero": zero}
	var zero_ok: bool = float(zero_oc[1]) == 24.0 and _open("fx_zero", 0, 23.5) and not _open("fx_zero", 0, 24.0) and not _open("fx_zero", 0, 24.5)
	Hours.override_registry = reg
	# the old branch `hour >= o or hour < c` would have kept this shop open until 26:00 (hour < 1 never holds, but a plain close 17 + hour 25.5 < 17 is false: also check a day shop at night)
	var day_shop_midnight: bool = not _open("fx_workshop", 3, 24.5) and not _open("fx_workshop", 3, 25.5)
	t.check("hours_wrap_midnight", oc == [20.0, 25.0] and thu_22 and thu_2430 and thu_2459 and not thu_2500 and not thu_2530 and not thu_19 and not fri_22 and st["reason"] == "hours" and zero_ok and day_shop_midnight,
		"`close < open` is the after-midnight notation of the SAME game day: open 20 close 1 reads [20.0, 25.0]; Thursday 22:00, 24:30 and 24:59 are open, 25:00 (01:00) and 25:30 shut, 19:54 shut; closed on Friday; close 0 reads 24.0 %s; a plain day shop (workshop 08-16) is shut at 24:30 and 25:30 %s" % [zero_ok, day_shop_midnight])


func _game_day() -> void:
	_fresh()
	Hours.override_registry = _fixture_buildings
	var stall: Dictionary = _fixture_buildings["fx_late_stall"]                          # open 20, close 25.5
	var lantern: Dictionary = _fixture_buildings["fx_lantern_house"]                     # open 17, close = 25 (the lantern house of the ghost family: relies on CK-A-TC)
	var s_2430: Dictionary = Hours.state("fx_late_stall", Ctx.at(2, 24.5))
	var plain: bool = Hours.hours_on(stall, 2) == [20.0, 25.5] and Hours.hours_on(lantern, 0) == [17.0, 25.0]
	var open_2430: bool = _open("fx_late_stall", 2, 24.5)
	var open_2515: bool = _open("fx_late_stall", 2, 25.25)
	var open_2530: bool = _open("fx_late_stall", 2, 25.5)
	var lantern_2430: bool = _open("fx_lantern_house", 0, 24.5)
	var lantern_2500: bool = _open("fx_lantern_house", 0, 25.0)
	# an authored 1.5 means 25.5: the same row written in the after-midnight notation
	var authored: Dictionary = {"hours": {"open": 20, "close": 1.5, "closed": []}}
	var same: bool = Hours.hours_on(authored, 0) == [20.0, 25.5] and is_equal_approx(gm.game_hour(1.5), 25.5)
	t.check("hours_after_midnight", plain and open_2430 and open_2515 and not open_2530 and lantern_2430 and not lantern_2500 and same and is_equal_approx(float(s_2430["closes_at"]), 25.5) and Hours.format_hour(25.0) == "01:00" and Hours.format_hour(25.5) == "01:30",
		"Hours accepts a close up to 26 as a plain interval: the stall (open 20, close 25.5) is open at 24:30 and 25:15 and shut at 25:30 (closes_at 25.5 prints %s), the lantern house row `close = 25` is open at 24:30 and shut at 01:00 (prints %s); the notation close 1.5 equals 25.5 %s; `close <= day_end_hour` is the only bound" % [Hours.format_hour(25.5), Hours.format_hour(25.0), same])
	# the WEEKDAY of the rule is the game day's: a Friday shop that closes at 25.5 is still a Friday shop at 00:30, a Saturday morning rule does not start at midnight
	var friday: Dictionary = {"hours": {"open": 20, "close": 25.5, "closed": [5]}}      # closed on SATURDAY (weekday 5)
	Hours.override_registry = {"fx_fri_bar": {"area": "fx_town", "kind": "public", "hours": friday["hours"]}}
	Ctx.set_clock(gm, 4, 24.5)                                                          # the real clock: day 5 (Friday) 24:30 = 00:30 of the night after Friday
	var ctx_fri: Dictionary = Hours.now_ctx()
	var fri_0030: bool = Hours.is_open("fx_fri_bar", ctx_fri)
	Ctx.set_clock(gm, 5, 21.0)                                                          # Saturday evening: the closed day
	var sat_21: bool = Hours.is_open("fx_fri_bar")
	Ctx.set_clock(gm, 5, 6.5)
	var sat_morning: Dictionary = Hours.state("fx_fri_bar")
	# through the real clock roll: 01:59 -> 02:00 steps the calendar, the weekday changes only THEN
	Ctx.set_clock(gm, 4, 25.0)
	gm.minute = 58
	var before_roll: int = int(Hours.now_ctx()["weekday"])
	gm.advance_time(3)
	var after_roll: int = int(Hours.now_ctx()["weekday"])
	t.check("hours_weekday_is_the_game_day", int(ctx_fri["weekday"]) == 4 and fri_0030 and not sat_21 and sat_morning["reason"] == "day" and before_roll == 4 and after_roll == 5,
		"the weekday of the rule is TimeManager.weekday_index of the game day: Friday 24:30 (00:30) reads weekday 4 and the Friday bar (closed on Saturday) is open %s; Saturday 21:00 is shut for the DAY %s; the weekday steps only with the 02:00 roll (25:58 Friday -> 02:01 Saturday: %d -> %d)" % [fri_0030, not sat_21, before_roll, after_roll])
	Ctx.set_clock(gm, 0, 12.0)
	t.new_game()


func _minutes_and_format() -> void:
	_fresh()
	Hours.override_registry = _fixture_buildings
	var bar_2430: int = Hours.minutes_to_close("fx_night_bar", Ctx.at(3, 24.5))               # close 1 = 25.0
	var bar_2530: int = Hours.minutes_to_close("fx_night_bar", Ctx.at(3, 25.5))               # already closed
	var bar_20: int = Hours.minutes_to_close("fx_night_bar", Ctx.at(3, 20.0))
	var stall_25: int = Hours.minutes_to_close("fx_late_stall", Ctx.at(2, 25.0))
	var bakery: int = Hours.minutes_to_close("fx_bakery", Ctx.at(1, 16.5))
	var closed_day: int = Hours.minutes_to_close("fx_bakery", Ctx.at(0, 12.0))
	var no_hours: int = Hours.minutes_to_close("fx_home", Ctx.at(0, 12.0))
	t.check("hours_minutes_to_close_after_midnight", bar_2430 == 30 and bar_2530 == 0 and bar_20 == 300 and stall_25 == 30 and bakery == 30 and closed_day == 0 and no_hours == 0,
		"d = closes_at - hour on the normalised axis: the bar that closes at 01:00 has 30 minutes at 24:30, 0 at 25:30 (the draft added 24 when negative: wrong there) and 300 at 20:00; the 25.5 stall has 30 at 25:00; the bakery 30 at 16:30; a closed building and a home 0")
	var wraps: bool = Hours.format_hour(25.0) == "01:00" and Hours.format_hour(24.5) == "00:30" and Hours.format_hour(24.0) == "00:00" and Hours.format_hour(6.0) == "06:00" and Hours.format_hour(17.5) == "17:30" \
		and Hours.format_hour(23.999) == "00:00" and Hours.format_hour(25.999) == "02:00" and Hours.format_hour(7.25) == "07:15"
	var shorts: bool = Hours.format_hour_short(8.0) == "8" and Hours.format_hour_short(18.0) == "18" and Hours.format_hour_short(23.5) == "23:30" and Hours.format_hour_short(25.0) == "01:00" and Hours.format_hour_short(24.0) == "00:00"
	t.check("hours_format_hour_wraps", wraps and shorts, "format_hour keeps the hour part mod 24: 25.0 prints 01:00, 24.5 00:30, 24.0 00:00, 06:00, 17:30, 07:15; the door sign's compact form prints 8, 18, 23:30 and keeps the full form from midnight (01:00, 00:00) so `1` is never read as 13:00")


func _validator_day_end() -> void:
	var base: Dictionary = {"area": "traetoppen", "kind": "stall", "name_key": "BLD_X", "shop": "s", "keeper": "k", "post": "traetoppen.p", "wave": "core"}
	var cases: Array = [["close 26 (the day end)", 20, 26, true], ["close 25.5", 20, 25.5, true], ["close 1 (= 25.0)", 20, 1, true], ["close 0 (= 24.0)", 20, 0, true], ["close 27", 20, 27, false],
		["open 5.5 close 14 (normalised open 29.5)", 5.5, 14, false], ["open 6 close 12", 6, 12, true], ["close 2 (= 26.0)", 20, 2, true], ["close 3 (= 27.0)", 20, 3, false]]
	var bad: Array[String] = []
	for c in cases:
		var row: Dictionary = base.duplicate(true)
		row["hours"] = {"open": c[1], "close": c[2], "closed": [], "short_ok": true}
		var problems: Array[String] = Rules.hours_problems({"x": row}, {"check_keepers": false})
		if (problems.is_empty()) != bool(c[3]):
			bad.append("%s -> %s" % [c[0], str(problems)])
	# the day end follows GameManager.day_end_hour(): a day that ends at 24 refuses a close of 25
	var strict: Array[String] = Rules.hours_problems({"x": _with_hours(base, 20, 25)}, {"check_keepers": false, "day_end": 24.0})
	t.check("hours_validator_accepts_close_up_to_the_day_end", bad.is_empty() and not strict.is_empty(),
		"hours.consistency evaluates the NORMALISED close: 26, 25.5, 1, 0 and 2 (= 26.0) pass, 27 / 3 (= 27.0) and an open of 5.5 fail %s; with a day that ends at 24 a close of 25 fails %s" % ["ALL AGREE" if bad.is_empty() else str(bad), not strict.is_empty()])


func _with_hours(base: Dictionary, o: float, c: float) -> Dictionary:
	var row: Dictionary = base.duplicate(true)
	row["hours"] = {"open": o, "close": c, "closed": [], "short_ok": true}
	return row


func _overrides_and_empty() -> void:
	_fresh()
	Hours.override_registry = _fixture_buildings
	var inn: Dictionary = _fixture_buildings["fx_inn"]                                      # 11-23, Monday from 17:00
	var mon: Array = Hours.hours_on(inn, 0)
	var tue: Array = Hours.hours_on(inn, 1)
	var mon_noon: Dictionary = Hours.state("fx_inn", Ctx.at(0, 12.0))
	var mon_18: bool = _open("fx_inn", 0, 18.0)
	var tue_noon: bool = _open("fx_inn", 1, 12.0)
	t.check("hours_override_weekday", mon == [17.0, 23.0] and tue == [11.0, 23.0] and not mon_noon["open"] and mon_noon["reason"] == "hours" and is_equal_approx(float(mon_noon["opens_at"]), 17.0) and mon_18 and tue_noon,
		"overrides = { { weekday = { 0 }, open = 17, close = 23 } } changes one weekday: Monday reads [17, 23] and is shut at noon (opens 17.0), open at 18:00; Tuesday keeps [11, 23] and is open at noon")
	# an empty Lua table arrives as a Dictionary (or an Array) and means NO days
	var lua_empty: Variant = (_fixture_buildings["fx_inn"] as Dictionary)["hours"]["closed"]
	var types_ok: bool = lua_empty is Dictionary or lua_empty is Array
	var days: Array = []
	for wd in 7:
		days.append(_open("fx_inn", wd, 18.0))
	var all_open: bool = days.all(func(d: Variant) -> bool: return bool(d))
	var as_dict: Dictionary = {"hours": {"open": 8, "close": 18, "closed": {}}}
	var as_array: Dictionary = {"hours": {"open": 8, "close": 18, "closed": []}}
	var neither: Dictionary = {"hours": {"open": 8, "close": 18}}
	var empty_hours: Dictionary = {"hours": {}}
	var forms_ok: bool = Hours.closed_days(as_dict) == [] and Hours.closed_days(as_array) == [] and Hours.closed_days(neither) == [] and Hours.closed_days(empty_hours) == []
	var clinic: bool = _open("fx_clinic", 0, 13.0) and _open("fx_clinic", 6, 13.0)
	t.check("hours_empty_table_is_no_days", types_ok and all_open and forms_ok and clinic and Hours.closed_days({"hours": {"closed": [0, 3]}}) == [0, 3],
		"`closed = {}` arrives from Lua as %s and means no closed day: the inn is open on all 7 weekdays at 18:00 %s, closed_days reads [] for a Dictionary, an Array, a missing key and an empty hours table %s, `{ 0, 3 }` reads [0, 3]" % [type_string(typeof(lua_empty)), all_open, forms_ok])


func _festival() -> void:
	_fresh()
	var ctx_closed: Dictionary = Ctx.at(1, 12.0, {"fest_closed_fn": func(shop_id: String) -> bool: return shop_id == "bakery"})
	var st: Dictionary = Hours.state("bageriet", ctx_closed)
	var other: bool = Hours.is_open("froebutikken", ctx_closed)
	var shop_open: Variant = Hours.shop_open("bakery", ctx_closed)
	var info: Dictionary = Hours.closed_info("bakery", ctx_closed)
	var plain: bool = Hours.is_open("bageriet", Ctx.at(1, 12.0))
	var no_fn: bool = Hours.is_open("bageriet", Ctx.at(1, 12.0, {"fest_closed_fn": null}))
	# production: SocialManager.shop_closed_by_festival through the late-bound Callable of now_ctx
	Ctx.set_clock(gm, 1, 12.0)
	var social: Node = _fake_social()
	var open_before: Variant = Hours.shop_open("bakery")
	social.closed_shops = ["bakery"]
	var closed_now: Variant = Hours.shop_open("bakery")
	var asked: bool = "shop_closed_by_festival:bakery" in social.calls
	var door_state: Dictionary = Hours.state("bageriet")
	social.closed_shops = []
	var reopened: Variant = Hours.shop_open("bakery")
	_release_fakes()
	# Restoring the real social service can restore an authored festival too.
	# A plain node models the missing capability without relying on the date.
	var no_social := Node.new()
	t.root.add_child(no_social)
	_fakes.append(no_social)
	Svc.override("SocialManager", no_social)
	var without: Variant = Hours.shop_open("bakery")
	_release_fakes()
	t.check("festival_closure_via_ctx", st["reason"] == "festival" and not st["open"] and other and shop_open == false and info["reason"] == "festival" and plain and no_fn and open_before == true and closed_now == false and asked \
		and door_state["reason"] == "festival" and reopened == true and without == true,
		"a festival closes a shop ONLY through ctx.fest_closed_fn(shop_id): the bakery reads reason festival, shop_open false, closed_info festival, the seed shop stays open %s; no function = nothing closes %s; production: SocialManager.shop_closed_by_festival is asked late bound (open %s -> closed %s -> open again %s) and without a social track nothing closes %s" % [
			other, no_fn, open_before == true, closed_now == false, reopened == true, without == true])


func _multi_building() -> void:
	_fresh()
	# timber_yard: the workshop (Mon-Fri 08-16) and the Torvet stall (Sat-Sun 10-16) are ONE shop
	var by: Array[String] = Hours.buildings_of_shop("timber_yard")
	var mon: Variant = Hours.shop_open("timber_yard", Ctx.at(0, 12.0))
	var sat: Variant = Hours.shop_open("timber_yard", Ctx.at(5, 12.0))
	var sun_9: Variant = Hours.shop_open("timber_yard", Ctx.at(6, 9.0))
	var mon_7: Dictionary = Hours.closed_info("timber_yard", Ctx.at(0, 7.0))
	var fri_17: Dictionary = Hours.closed_info("timber_yard", Ctx.at(4, 17.0))
	var sat_9: Dictionary = Hours.closed_info("timber_yard", Ctx.at(5, 9.0))
	var open_info: Dictionary = Hours.closed_info("timber_yard", Ctx.at(2, 12.0))
	t.check("multi_building_shop", by == ["brummes_vaerksted", "torvestanden"] and mon == true and sat == true and sun_9 == false and is_equal_approx(float(mon_7["opens_at"]), 8.0) and mon_7["next_weekday"] == 0 \
		and fri_17["next_weekday"] == 5 and is_equal_approx(float(fri_17["opens_at"]), 10.0) and is_equal_approx(float(sat_9["opens_at"]), 10.0) and bool(open_info["open"]),
		"timber_yard is claimed by the workshop and the Torvet stall %s: open when ANY of them is (Monday noon %s, Saturday noon %s, Sunday 09:00 shut %s); closed_info points at the building that opens first: Monday 07:00 -> 08:00 today %s, Friday 17:00 -> Saturday 10:00 (the stall) %s, an open day answers the open state %s" % [
			str(by), mon == true, sat == true, sun_9 == false, is_equal_approx(float(mon_7["opens_at"]), 8.0), fri_17["next_weekday"] == 5, bool(open_info["open"])])


# ================================================================================================ copy

func _copy() -> void:
	var rows: Dictionary = _csv_rows()
	var missing: Array[String] = []
	var parity: Array[String] = []
	var empties: Array[String] = []
	for key in rows:
		var r: Dictionary = rows[key]
		if str(r["da"]).strip_edges() == "" or str(r["en"]).strip_edges() == "":
			empties.append(str(key))
		if str(r["da"]).count("%s") != str(r["en"]).count("%s"):
			parity.append(str(key))
	var all_ids: Array[String] = []
	all_ids.append_array(CORE_IDS)
	all_ids.append_array(EXT_IDS)
	for id in all_ids:
		var key: String = "BLD_%s" % id.to_upper()
		var has: bool = rows.has(key) and str((rows[key] as Dictionary)["da"]).strip_edges() != "" and str((rows[key] as Dictionary)["en"]).strip_edges() != ""
		t.expect(has, "%s has a Danish and an English name%s" % [key, (": " + str((rows[key] as Dictionary)["da"]) + " / " + str((rows[key] as Dictionary)["en"])) if has else ""])
		if not rows.has(key):
			missing.append(key)
	for k in HOURS_KEYS:
		if not rows.has(k):
			missing.append(k)
	for k in COUNTER_KEYS:
		if not rows.has(k):
			missing.append(k)
	for a in ACTS:
		if not rows.has("ACT_%s" % a.to_upper()):
			missing.append("ACT_%s" % a.to_upper())
	for wd in 7:
		if not rows.has("HOURS_WEEKDAY_%d" % (wd + 1)):
			missing.append("HOURS_WEEKDAY_%d" % (wd + 1))
	var bld: int = 0
	var families_ok: bool = true
	for key in rows:
		if str(key).begins_with("BLD_"):
			bld += 1
		families_ok = families_ok and (str(key).begins_with("BLD_") or str(key).begins_with("HOURS_") or str(key).begins_with("ACT_") or str(key).begins_with("COUNTER_"))
	var pinned: bool = str((rows.get("HOURS_CLOSED_NOW", {}) as Dictionary).get("da", "")) == "Lukket lige nu. Åbner kl. %s." and str((rows.get("HOURS_CLOSED_DAY", {}) as Dictionary).get("da", "")) == "Lukket i dag. Åbner igen %s." \
		and str((rows.get("HOURS_CLOSING_SOON", {}) as Dictionary).get("da", "")) == "Vi lukker om en halv time." and str((rows.get("HOURS_SIGN", {}) as Dictionary).get("da", "")) == "%s - åbent %s-%s" \
		and str((rows.get("COUNTER_SHOP", {}) as Dictionary).get("da", "")) == "Se varer" and str((rows.get("COUNTER_TALK", {}) as Dictionary).get("da", "")) == "Tal med %s" \
		and str((rows.get("COUNTER_DESK", {}) as Dictionary).get("da", "")) == "Husbyggeri" and str((rows.get("COUNTER_APPRAISE", {}) as Dictionary).get("da", "")) == "Vurdér fund" \
		and str((rows.get("COUNTER_APPRAISE_SOON", {}) as Dictionary).get("da", "")) == "Fru Ugle åbner for vurderinger lidt senere." and str((rows.get("HOURS_CLOSED_NOW", {}) as Dictionary).get("en", "")) == "Closed right now. Opens at %s."
	# the loaded translations (what the game shows): every key has a Danish AND an English text in the live loader, never a raw key
	var raw: Array[String] = []
	for key in rows:
		if lm.text_in(str(key), "da") == "" or lm.text_in(str(key), "en") == "":
			raw.append(str(key))
	t.check("keys_da_en_complete", missing.is_empty() and empties.is_empty() and parity.is_empty() and raw.is_empty() and bld == 30 and families_ok and pinned,
		"towns.csv holds BLD_ for all 30 buildings (%d; core and ext, so the ext package adds no copy), the 11 HOURS_ whisper keys, 7 weekday names, 15 ACT_ labels, 5 COUNTER_ prompts: da and en present, the same %%s placeholders in both, loaded by the game (%d keys, %d missing in the loader), only the four families; the Danish texts of design_towns.md 4.5 are pinned %s; missing %s" % [
			bld, rows.size(), raw.size(), pinned, str(missing)])
	var act_keys: Array = []
	for key in rows:
		if str(key).begins_with("ACT_"):
			act_keys.append(str(key))
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors/schema.json"))
	var schema_acts: Array = (((schema["$defs"] as Dictionary)["post"] as Dictionary)["properties"]["act"] as Dictionary)["enum"]
	var from_schema: Array = schema_acts.map(func(a: Variant) -> String: return "ACT_%s" % str(a).to_upper())
	from_schema.sort()
	act_keys.sort()
	t.check("act_hide_known", str((rows.get("ACT_HIDE", {}) as Dictionary).get("da", "")) == "gemmer sig" and (rows.get("ACT_HIDE", {}) as Dictionary).get("en", "") != "" and act_keys.size() == 15 and act_keys == from_schema,
		"ACT_HIDE reads 'gemmer sig' (Blund's hiding blocks, GHOST_FAMILY AGF4); the 14 acts of the routine vocabulary + hide = %d labels, and they are exactly the acts a room post may carry (schema.json): %s" % [act_keys.size(), str(act_keys == from_schema)])
	_copy_lint(rows)


func _copy_lint(rows: Dictionary) -> void:
	# (1) the loader's own lint finds nothing in towns.csv; (2) the copy rules every CSV of this package obeys; (3) I1's lint when it exists
	var report: Dictionary = lm.parse_dir(lm.LOC_DIR, "res://", true)
	var own: Array[String] = []
	for iss in (report["issues"] as Array):
		if str((iss as Dictionary).get("file", "")) == "towns.csv":
			own.append(lm.format_issue(iss))
	var findings: Array[String] = []
	for key in rows:
		for locale in ["da", "en"]:
			var text: String = str(rows[key][locale])
			if text.contains(RETIRED_TOWN) or text.contains("PongPong") or text.contains("Eventyrskoven") or text.contains("Mjau"):
				findings.append("%s (%s): a retired name" % [key, locale])
			if text.contains("  ") or text != text.strip_edges():
				findings.append("%s (%s): stray spaces" % [key, locale])
			if text.contains("\"") or text.contains("--"):
				findings.append("%s (%s): an ASCII quote or `--` (typography)" % [key, locale])
			if text.begins_with("HOURS_") or text.begins_with("BLD_") or text.begins_with("ACT_") or text.begins_with("COUNTER_"):
				findings.append("%s (%s): the text is a raw key" % [key, locale])
	var lint_py: String = ProjectSettings.globalize_path("res://tools/copy/copy_lint.py")
	var i1_ran: bool = false
	var i1_ok: bool = true
	if FileAccess.file_exists(lint_py):
		var res: Dictionary = t.run_tool(t.python(), PackedStringArray(["-I", lint_py, "--files", ProjectSettings.globalize_path(CSV_PATH)]))
		i1_ran = true
		i1_ok = int(res["code"]) == 0
		if not i1_ok:
			findings.append("tools/copy/copy_lint.py: %s" % str(res["output"]).left(200))
	else:
		t.info("towns_data.copy_lint_clean_for_towns: tools/copy/copy_lint.py (I1-copy-system, same wave) does not exist in this tree yet: the loader's lint and this package's own copy rules ran; the check runs I1's lint on towns.csv as soon as the file exists")
	t.check("copy_lint_clean_for_towns", own.is_empty() and findings.is_empty() and i1_ok,
		"towns.csv: the loader's lint reports nothing for the file (%d issues %s), no retired name (the retired town name, PongPong, Eventyrskoven), no stray spaces, no ASCII quote, no raw-key text (%d findings %s); I1's copy lint C1-C10 %s" % [
			own.size(), str(own.slice(0, 2)), findings.size(), str(findings.slice(0, 2)), "ran clean" if i1_ran and i1_ok else "is not in this tree yet (I1-copy-system)"])


# ================================================================================================ fixtures and mutants

func _fixtures_and_mutants() -> void:
	_fresh()
	_load_fixture_town()
	var rooms: Array[String] = ["int_froebutikken", "int_hoppe_hut", "int_postkontoret"]
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors/schema.json"))
	var room_problems: Array[String] = []
	for r in rooms:
		var p: String = "res://tests/fixtures/towns/interiors/%s.json" % r
		if not FileAccess.file_exists(p):
			room_problems.append("%s is missing" % r)
			continue
		var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if not (spec is Dictionary):
			room_problems.append("%s is not JSON" % r)
			continue
		var sch: Array[String] = SchemaLiteScript.problems(spec, schema)
		if not sch.is_empty():
			room_problems.append("%s: %s" % [r, str(sch[0])])
	var buildings_ok: bool = _fixture_buildings.size() == 10 and _fixture_citizens.size() == 6
	var links: Array[String] = []
	for c in _fixture_citizens:
		var row: Dictionary = _fixture_citizens[c]
		if not _fixture_buildings.has(str(row.get("home", ""))):
			links.append("%s: home %s" % [c, row.get("home", "")])
		if row.has("work") and not _fixture_buildings.has(str(row["work"])):
			links.append("%s: work %s" % [c, row["work"]])
	for b in _fixture_buildings:
		var keeper: String = str((_fixture_buildings[b] as Dictionary).get("keeper", ""))
		if keeper != "" and not _fixture_citizens.has(keeper):
			links.append("%s: keeper %s is no fixture citizen" % [b, keeper])
		var owner_id: String = str((_fixture_buildings[b] as Dictionary).get("owner", ""))
		if owner_id != "" and not _fixture_citizens.has(owner_id):
			links.append("%s: owner %s is no fixture citizen" % [b, owner_id])
	var clean: Array[String] = Rules.problems(_fixture_buildings, {"npcs": _fixture_citizens, "known_shops": ["fx_bread", "fx_lanterns", "fx_maps", "fx_timber"], "areas": ["fx_town"]})
	var fake: Node = FakeSocialScript.new()
	fake.closed_shops = ["x"]
	fake.festival = "fx_fest"
	fake.overrides = {"fx_baker": {"area": "fx_town", "post": "p", "state": "stay"}}
	var contract: bool = fake.festival_today() == "fx_fest" and fake.shop_closed_by_festival("x") and not fake.shop_closed_by_festival("y") and fake.override_for("fx_baker", 1, 12.0).get("post") == "p" and fake.override_for("nobody", 1, 12.0).is_empty()
	fake.free()
	var ctx: Dictionary = Ctx.at(3, 25.5)
	var ctx_ok: bool = ctx["weekday"] == 3 and ctx["hour"] == 25.5 and ctx["total_day"] == 4
	t.check("fixtures_load", room_problems.is_empty() and buildings_ok and links.is_empty() and clean.is_empty() and contract and ctx_ok,
		"the fixture town loads through the registry kind (%d buildings in towns_fixture_buildings, %d citizens in towns_fixture_citizens, every home, work place, keeper and owner resolves %s) and passes the rules (%d problems %s); the three sample rooms %s parse and match data/interiors/schema.json %s; FakeSocial offers festival_today, override_for and shop_closed_by_festival %s; the context builder %s" % [
			_fixture_buildings.size(), _fixture_citizens.size(), str(links), clean.size(), str(clean.slice(0, 2)), str(rooms), str(room_problems), contract, ctx_ok])
	# the mutants: every one violates exactly one rule and must be reported
	var opts: Dictionary = {"npcs": _fixture_citizens, "known_shops": ["fx_bread", "fx_lanterns", "fx_maps", "fx_timber"], "areas": ["fx_town"]}
	var mutants: Array[Dictionary] = Mutate.mutants(_fixture_buildings)
	var missed: Array[String] = []
	for m in mutants:
		var found: Array[String] = Rules.problems(m["registry"], opts)
		t.expect(not found.is_empty(), "fixture mutant %s is reported (%s)" % [m["name"], str(found[0]) if not found.is_empty() else "NOT CAUGHT"])
		if found.is_empty():
			missed.append(str(m["name"]))
	# the same helper against the REAL registry (with the real npcs and shop ids)
	var real_opts: Dictionary = {"npcs": _npc_rows(), "known_shops": _known_shop_ids()}
	var real_missed: Array[String] = []
	var real_mutants: Array[Dictionary] = Mutate.mutants(Hours.registry())
	for m in real_mutants:
		var found: Array[String] = Rules.problems(m["registry"], real_opts)
		t.expect(not found.is_empty(), "real-registry mutant %s is reported (%s)" % [m["name"], str(found[0]) if not found.is_empty() else "NOT CAUGHT"])
		if found.is_empty():
			real_missed.append(str(m["name"]))
	t.check("mutants_are_caught", mutants.size() >= 15 and missed.is_empty() and real_missed.is_empty() and Rules.problems(_fixture_buildings, opts).is_empty() and Rules.problems(Hours.registry(), real_opts).is_empty(),
		"%d mutants of the fixture registry and %d of the real one (a shop without hours, a close after the end of the day, open == close, closed on all seven days, a weekday out of range, an unknown shop id, a keeper that is no citizen, a wrong name_key, an interior without size, an unknown field, a service with a shop id, a stall with an interior, a night row without short_ok, a home without an owner ...) are ALL reported; the unmutated registries pass; missed %s %s" % [
			mutants.size(), real_mutants.size(), str(missed), str(real_missed)])


const SchemaLiteScript := preload("res://tests/lib/towns/schema_lite.gd")


# ================================================================================================ the registry kind and the hooks

func _registry_kind() -> void:
	lr.reload_scripts()
	var real: Dictionary = lr.get_registry("buildings")
	var ids: Array = []
	for id in real:
		if str((real[id] as Dictionary).get("wave", "")) == "core":
			ids.append(id)
	ids.sort()
	var core_sorted: Array = CORE_IDS.duplicate()
	core_sorted.sort()
	var entry: Dictionary = lr.get_registry_entry("buildings", "bageriet")
	var lint_clean: bool = true
	var own_paths: Array = ["lua/towns.lua", "lua/buildings/traetoppen.lua", "lua/buildings/hyggebyen.lua"]
	for f in lr.lint_report:
		for p in own_paths:
			if str((f as Dictionary).get("path", "")).ends_with(p):
				lint_clean = false
	var findings: Array = []
	for p in own_paths:
		findings.append_array(lr.lint_source(FileAccess.get_file_as_string("res://" + p), "res://" + p))
	var claims_real: bool = true
	for n in lr.data_report:
		if str((n as Dictionary).get("message", "")).contains("registry:buildings"):
			claims_real = false
	# a duplicate id across two files is reported once (claim registry:<name>), the later file wins; a file without its `registry = ` header is a finding
	var data_before: int = lr.data_report.size()
	var lint_before: int = lr.lint_report.size()
	lr.load_file(FIX + "fixture_buildings_dup_a.lua")
	lr.load_file(FIX + "fixture_buildings_dup_b.lua")
	var dups: Array = []
	for n in lr.data_report:
		if str((n as Dictionary).get("rule", "")) == "duplicate_id" and str((n as Dictionary).get("token", "")) == "fx_dup":
			dups.append(n)
	var winner: Dictionary = lr.get_registry_entry("towns_fixture_dups", "fx_dup")
	var claim_ok: bool = dups.size() == 1 and str(dups[0]["message"]).contains("registry:towns_fixture_dups") and str(dups[0]["path"]).ends_with("fixture_buildings_dup_b.lua") and winner.get("source") == "b" and lr.data_report.size() == data_before + 1
	lr.load_file(FIX + "fixture_buildings_noheader.lua")
	var header: Array = lr.lint_report.slice(lint_before).filter(func(x: Variant) -> bool: return str((x as Dictionary)["rule"]) == "registry_header")
	var header_ok: bool = header.size() == 1 and str(header[0]["path"]).ends_with("fixture_buildings_noheader.lua") and lr.get_registry("towns_fixture_headless").is_empty()
	lr.reload_scripts()
	t.check("registry_kind_loads_lints_and_claims", ids == core_sorted and entry.get("shop") == "bakery" and entry.get("keeper") == "baker_maja" and lint_clean and findings.is_empty() and claims_real and claim_ok and header_ok \
		and lr.get_registry("towns").is_empty() and lr.get_config("towns") != null,
		"kind = \"registry\": the 20 CORE ids load from the two files (get_registry(\"buildings\"), get_registry_entry(\"buildings\", \"bageriet\") = shop bakery, keeper baker_maja), the three Lua files lint with 0 findings %s, no id of the real registry is claimed twice %s; a duplicate id across two files is ONE duplicate_id note naming registry:<name>, the later file wins %s; a registry file without `registry = ` is the finding registry_header %s; the config key `towns` collides with no registry name" % [
			findings.is_empty() and lint_clean, claims_real, claim_ok, header_ok])


func _shop_system() -> void:
	_fresh()
	_fake_social() # Isolate weekly hours from authored festival dates.
	var shop: Node = t.autoload("ShopSystem")
	var eco: Node = t.autoload("EconomyManager")
	eco.add_gold(2000)
	# with the buildings registry loaded ShopSystem.is_open answers Hours.shop_open: the bakery is open Tuesday 10:00 and shut on Monday
	Ctx.set_clock(gm, 1, 10.0)
	var tue_open: bool = shop.is_open("bakery") and shop.is_open("seed_shop")
	var tue_info: Dictionary = shop.get_shop_info("bakery")
	Ctx.set_clock(gm, 0, 10.0)
	var mon_open: bool = shop.is_open("bakery")
	var mon_info: Dictionary = shop.get_shop_info("bakery")
	var bought: bool = shop.buy_item("bakery", &"cookie", 1) if shop.has_method("buy_item") else false
	var refusal: StringName = shop.last_refusal
	Ctx.set_clock(gm, 6, 12.0)
	var sunday_seed: bool = shop.is_open("seed_shop")
	var seed_info: Dictionary = shop.get_shop_info("seed_shop")
	var seed_refused: bool = not shop.buy_item("seed_shop", &"carrot_seeds", 1) and shop.last_refusal == &"closed"
	Ctx.set_clock(gm, 1, 6.0)
	var early_info: Dictionary = shop.get_shop_info("bakery")
	Ctx.set_clock(gm, 1, 10.0)
	var bought_open: bool = shop.buy_item("seed_shop", &"carrot_seeds", 1)
	t.check("shop_system_hook", tue_open and not tue_info.get("closed", true) and not mon_open and bool(mon_info["closed"]) and mon_info.get("closed_reason") == "day" and is_equal_approx(float(mon_info.get("opens_at", 0.0)), 7.0) \
		and mon_info.get("next_open_weekday") == 1 and not bought and refusal == &"closed" and not sunday_seed and seed_info.get("closed_reason") == "day" and seed_info.get("next_open_weekday") == 0 and seed_refused \
		and early_info.get("closed_reason") == "hours" and is_equal_approx(float(early_info.get("opens_at", 0.0)), 7.0) and bought_open,
		"with the buildings registry loaded ShopSystem.is_open answers Hours.shop_open through ShopHoursGate: Tuesday 10:00 the bakery and the seed shop are open %s, Monday the bakery is closed with closed_reason day, opens_at 7.0, next_open_weekday 1 %s and buying is refused with reason `closed` %s; Sunday the seed shop is closed (day, back on Monday) and buy_item is refused %s; Tuesday 06:00 the bakery reason is hours, opens 07:00 %s; open again, buying works %s" % [
			tue_open, mon_info.get("closed_reason") == "day", refusal == &"closed", seed_refused, early_info.get("closed_reason") == "hours", bought_open])
	_unclaimed()


func _unclaimed() -> void:
	_fresh()
	_fake_social() # Festival behaviour has its own live-social checks.
	var shop: Node = t.autoload("ShopSystem")
	var flea: Dictionary = lr.get_shop("flea_market")
	# the flea market is claimed by the Loppeloft (Saturday and Sunday 10-16): the building and the def's own open_weekdays 5, 6 AGREE
	var agree: bool = true
	var expected: Dictionary = {1: false, 2: false, 3: false, 4: false, 5: false, 6: true, 7: true}
	for day in expected:
		Ctx.set_clock(gm, int(day) - 1, 12.0)
		agree = agree and shop.is_open("flea_market") == bool(expected[day])
	Ctx.set_clock(gm, 5, 9.0)
	var before_ten: bool = not shop.is_open("flea_market")                                # the building says 10:00, the def alone would say open
	# a shop NO building claims keeps the weekday-only rule of its def: take the Loppeloft away
	var without: Dictionary = Hours.registry().duplicate(true)
	without.erase("loppeloftet")
	Hours.override_registry = without
	var unclaimed: bool = Hours.shop_open("flea_market") == null
	var weekday_only: bool = true
	for day in expected:
		Ctx.set_clock(gm, int(day) - 1, 3.0 if int(day) == 6 else 12.0)                   # even at 03:00 on Saturday: no hours rule, the def's weekdays decide alone
		weekday_only = weekday_only and shop.is_open("flea_market") == bool(expected[day])
	Ctx.set_clock(gm, 5, 12.0)
	var info: Dictionary = shop.get_shop_info("flea_market")
	var no_reason: bool = not info.has("closed_reason") and not bool(info["closed"])
	Ctx.set_clock(gm, 2, 12.0)
	var wed_info: Dictionary = shop.get_shop_info("flea_market")
	var wed_ok: bool = bool(wed_info["closed"]) and not wed_info.has("closed_reason")
	Hours.override_registry = {}
	# with scripts/towns/hours.gd absent nothing changes: the gate answers "no rule"
	Gate.use_hours_script("res://scripts/towns/no_such_hours.gd")
	Ctx.set_clock(gm, 0, 10.0)
	var absent: bool = Gate.open_override("bakery") == null and shop.is_open("bakery") and Gate.closed_info("bakery").is_empty()
	Gate.use_hours_script()
	t.check("unclaimed_shop_keeps_weekday_rule", agree and before_ten and unclaimed and weekday_only and no_reason and wed_ok and absent and flea.get("open_weekdays") == [5, 6],
		"flea_market (open_weekdays 5, 6) is claimed by the Loppeloft: the building and the def agree on every weekday at noon %s (Saturday 09:00 the building's 10:00 wins %s); with no building claiming it the rule answers null %s and the def's weekdays decide alone, at any hour (Saturday open, Wednesday closed, no closed_reason: %s / %s); with scripts/towns/hours.gd absent the gate answers no rule and nothing changes %s" % [
			agree, before_ten, unclaimed, no_reason, wed_ok, absent])


# ================================================================================================ forward references

func _forward_refs() -> void:
	var hits: Array[String] = Refs.scan(SCRIPTS)
	# the scanner itself: an identifier in code is found, one inside a string or a comment is not
	var probe: String = "extends Node\n# Routines is only a comment here\nvar a := \"Routines\"\nvar b := 'NavGrid'\nfunc f() -> void:\n\tRoutines.where_is(1)\n\tvar x := NavGrid.new()\n\tvar s := \"\"\"\nTownDirector in a long string\n\"\"\"\n"
	var found: Array[String] = Refs.scan_text(probe, Refs.WAVE4_FORBIDDEN, "probe")
	var scanner_ok: bool = found.size() == 2 and str(found[0]).ends_with("Routines") and str(found[1]).ends_with("NavGrid") and Refs.scan_text("var s := \"GiftRules\" # SocialTalk\n", Refs.WAVE4_FORBIDDEN).is_empty()
	t.check("no_forward_class_refs", hits.is_empty() and scanner_ok,
		"none of the %d scripts of the package names a class of a later wave outside a string or a comment (Routines, RouteTable, NavGrid, FestSet, NpcDirector, TownsValidate, TownMarks, LevelNav, TownDirector, TownMarker, CitizenStub, CityTown, GiftRules, GiftFlow, SocialTalk, and the autoloads SocialManager, LootService, HomeManager: they appear only as path strings in Svc.static_call / Svc.node): %d hits %s; the scanner finds an identifier in code (%s) and ignores strings and comments %s" % [
			SCRIPTS.size(), hits.size(), str(hits), str(found), scanner_ok])
	var broken: Array[String] = []
	for s in SCRIPTS:
		var script: Script = load(s) as Script
		if script == null:
			broken.append("%s does not load" % s)
		elif script.reload() != OK:
			broken.append("%s: reload() failed" % s)
	var present: Array[String] = []
	for f in LATER_FILES:
		if ResourceLoader.exists(f):
			present.append(f.get_file())
	# the late-bound paths are plain strings: with or without the later files every script loads and the rule still answers
	var where: Variant = Hours.where_is("anybody", {})
	var survives: bool = Hours.state("bageriet", Ctx.at(1, 10.0))["open"] == true and (where == null or where is Dictionary)
	t.check("wave4_scripts_load_without_later_files", broken.is_empty() and survives,
		"every script of the package loads and reloads without a parse error (%d scripts, %d problems %s); the later files of the towns track that exist in this tree: %s; Routines is reached only through Hours.where_is (a path string with the default null): %s" % [
			SCRIPTS.size(), broken.size(), str(broken), str(present) if not present.is_empty() else "none (a wave-4 tree: the unedited drafts gave 43 `Identifier Routines not declared` parse errors here)", survives])
