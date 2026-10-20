extends RefCounted
## Section "city_map" (package V4-city-map, milestone M1a PREVIEW mode): the area `traetoppen` - data/maps/traetoppen.map (header only) built by
## CityBuilder from data/traetoppen/traetoppen.json with V5's art, wired to the farm, Hyggebyen and the forest hub, walked end to end by the stub player.
##
## Named checks of the order (VERIFY): city_map.json_matches_extract_within_1px, rank_order, builds_in_budget, no_builder_error, walkable_test_matches_levels,
## every_warp_round_trips, skovlift_closed_whisper_when_no_forest, zone_unlocks_on_first_arrival, landmarks_reachable_flood_fill,
## landmark_positions_within_3_percent_of_sketch, npc_markers_resolve_in_npcs_lua (the ids hard, the handler part SKIPs while P14 is absent),
## keys_da_en_complete, config_numbers_documented, save_inside_city_roundtrip, shot_overview_0_2 (windowed), frame_budget (windowed),
## skovlift_reaches_floor_1_and_back + defeat_wakes_at_the_farm (SKIP `capability missing: D2 landed`, REQUIRED by DQ's E1 / E2),
## chain_checks_skip_without_d2, planter_kinds_skipped_without_p19, town_attach_called, no_board_bath_markers_in_city;
## the real marker handlers: npc_markers_use_the_real_handler, handler_made_nodes_are_levelled, when_markers_follow_flags, every_level_reachable_with_the_stub_player,
## walk_farm_to_hyggebyen_windowed (the M1a preview citizens and hints were removed once the town director and the HUD landed).
## fix round of the review (regressions): canopy_gives_way_when_zoomed_out, camera_headroom_above_the_top_platforms, overview_keeps_the_top_platforms_in_view,
## scheduled_citizens_replace_preview_labels, hud_owns_prompts_whispers_and_toasts, and windowed
## overview_shows_the_top_platforms, vram_city_increment_within_budget, hints_visible_at_the_ladder_foot.
## Every check that needs a package of the next milestone SKIPs with a visible line `capability missing: <package>`.
const SECTION := "city_map"
const TIMEOUT_S := 170.0
const SELF_PATH := "res://tests/sections/city_map.gd"
const EXTRACT_PATH := "res://scripts/world2d/levels/source/v2_city_extract.json"
const LUA_PATH := "res://lua/config/traetoppen.lua"
const CSV_PATH := "res://localization/traetoppen.csv"
const BUILDER_PATH := "res://scripts/traetoppen/city_builder.gd"
const D2_PATH := "res://scripts/dungeon/floors/dungeon_floors.gd"
const P06_PATH := "res://scenes/world2d/player_2d.tscn"
const V7_DIALOGUE_PATH := "res://lua/dialogue/appraiser_fru_ugle.lua"
const NPC_IDS: Array[String] = ["gardener_hoppe", "postman_pip", "carpenter_brumme", "bathkeeper_sofus", "appraiser_fru_ugle", "guard_oak"]
const V6_TYPES: Array[String] = ["board", "bath", "seed_basket", "kiki_cache", "rejsestolpe"]
## The numbers of design 4.5 (lua/config/traetoppen.lua): what config_numbers_documented re-asserts.
const CONFIG_WANT := {
	"scale": 3.0, "zoom": {"default": 0.4, "min": 0.2, "max": 0.7},
	"post": {"givers": ["mayor_lyra", "baker_maja", "merchant_pip", "farmer_rosa", "fairy_lily", "smith_thorin"], "per_day": 1},
	"board": {"givers": ["mayor_lyra", "baker_maja", "merchant_pip", "farmer_rosa", "fairy_lily", "smith_thorin"], "max": 5},
	"bath": {"minutes": 30, "once_per_day": true},
	"swap": {"give": {"carrot": 2}, "table": {"moonflower_seeds": 3, "glow_berry_seeds": 2}, "once_per_day": true},
	"caches": {"slots": 5, "gold_min": 20, "gold_max": 50},
	"skovlift": {"to_area": "moerkeskoven", "spawn": "from_traetoppen", "seconds": 1.6},
}
## The anchors of the ten landmarks in the SKETCH (extract / design 4.4 "where"): the trigger circle must hold the anchor, or lie within 3 percent
## of the sketch's width of it. [kind, index or id]: hut index into the extract's huts, "raadhus" = the lavender hall (not in the extract, data).
const LANDMARK_ANCHORS := {
	1: ["platform", 3], 2: ["building", "raadhus"], 3: ["hut", 2], 4: ["hut", 0], 5: ["hut", 4], 6: ["prop", "bath_tub"], 7: ["planter", 1],
	8: ["bridge", 8], 9: ["owl", 0], 10: ["bat", 0],
}

static var attach_calls: Array = []
static var made_markers: Array = []

var _t
var _world: Node2D
var _area: IsoArea
var _city: CityBuilder
var _reg: LevelRegistry
var _data: Dictionary = {}
var _k: float = 3.0
var _extract: Dictionary = {}
var _caps: Array[String] = []
var _events: Array = []
var _start_id: StringName = &""
var _enter_errors: Array[String] = []


func run(t) -> void:
	_t = t
	_data = CityData.load_data()
	t.check("data_loads", not _data.is_empty() and LevelRegistry.last_error == "", "data/traetoppen/traetoppen.json: %s" % LevelRegistry.last_error)
	if _data.is_empty():
		return
	_k = CityData.scale_of(_data)
	_extract = JSON.parse_string(FileAccess.get_file_as_string(EXTRACT_PATH)) if FileAccess.file_exists(EXTRACT_PATH) else {}
	_header_and_data(t)
	_validator(t)
	_keys_and_config(t)
	_art_joins(t)
	if not await t.start_world():
		return
	_world = t.world()
	_start_id = _world.area.map.id if _world.area != null else &""
	await _enter_city(t)
	_build_checks(t)
	_extract_checks(t)
	await _budgets(t)
	await _markers_and_citizens(t)
	await _fix_round_checks(t)
	await _fake_handlers(t)
	_town_attach(t)
	await _landmarks(t)
	await _warps_and_zone(t)
	await _lift(t)
	await _walk(t)
	await _save_roundtrip(t)
	await _capability_summary(t)
	_world = null
	_area = null
	_city = null
	_reg = null
	_events.clear()


# ================================================================== helpers

func _sk(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _k


func _skip(t, check: String, package: String, what: String) -> void:
	var line: String = "city_map.%s: capability missing: %s (%s)" % [check, package, what]
	_caps.append(line)
	t.skip(line)


func _enter_city(t, spawn: StringName = &"default") -> void:
	var mark: int = t.log_mark()
	_world._enter(&"traetoppen", spawn)
	await t.frames(3)
	_enter_errors = t.log_since(mark)
	_area = _world.area
	_city = CityBuilder.of(_area)
	_reg = _city.registry if _city != null else null


## A second area of the city in a host node under the world (the variants: fake handlers, a test town script ...); the caller frees the host.
func _fresh_area() -> Dictionary:
	var host := Node2D.new()
	host.name = "CityHost"
	_world.add_child(host)
	var a := IsoArea.new()
	host.add_child(a)
	a.setup(WorldRoot2D.load_map(&"traetoppen"))
	return {"host": host, "area": a, "city": CityBuilder.of(a)}


func _record_events() -> Callable:
	_events.clear()
	var cb: Callable = func(n: StringName, payload: Dictionary) -> void: _events.append([n, payload])
	EventBus.game_event.connect(cb)
	return cb


func _events_named(name: StringName) -> Array:
	var out: Array = []
	for e in _events:
		if e[0] == name:
			out.append(e[1])
	return out


## Every descendant of a node (the node included).
func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		stack.append_array(n.get_children())
	return out


func _count(root: Node, cls: String) -> int:
	var n: int = 0
	for x in _all_nodes(root):
		if x.is_class(cls):
			n += 1
	return n


# ================================================================== the map header and the data

func _header_and_data(t) -> void:
	var m: AreaMap = AreaMap.load_file(CityData.MAP_PATH)
	var ok: bool = m != null and m.errors.is_empty() and m.id == &"traetoppen" and m.title == "ZONE_TRAETOPPEN" and m.projection == &"iso" and m.ambient == &"farm" \
		and m.theme == &"treetop" and m.zone == &"traetoppen" and not m.flight_allowed and m.music == "city_theme" and is_equal_approx(m.zoom_default(), 0.4) \
		and m.zoom_range() == Vector2(0.2, 0.7) and m.builder == BUILDER_PATH and m.is_builder() and not m.has_grid()
	t.check("map_is_header_only", ok, "data/maps/traetoppen.map: @id traetoppen @title ZONE_TRAETOPPEN @projection iso @ambient farm @theme treetop @zone traetoppen @flight false @music city_theme @zoom 0.4 / 0.2 / 0.7 @builder %s; no ground rows (is_builder, no grid), parse errors %s" % [BUILDER_PATH, m.errors if m != null else "no file"])
	t.check("map_registered", WorldRoot2D.has_area(&"traetoppen") and not WorldRoot2D.area_ids(true).is_empty(), "the registry scans data/maps and lists `traetoppen` (area ids %s)" % [WorldRoot2D.area_ids(false)])
	# the header's @marker lines are declarations: the same spawns and ways out as the data
	var spawns_decl: Array[String] = []
	var warps_decl: Dictionary = {}
	for ch in m.markers:
		var d: Dictionary = m.markers[ch]
		if str(d.get("marker", "")) == "spawn":
			spawns_decl.append(str(d.get("name", "")))
		elif str(d.get("marker", "")) == "warp":
			warps_decl[str(d.get("to", ""))] = str(d.get("spawn", ""))
	spawns_decl.sort()
	var spawns_data: Array[String] = []
	for k in LuaData.dict(_data.get("spawns", {})):
		if str(k) != "default":
			spawns_data.append(str(k))
	spawns_data.sort()
	var exits_data: Dictionary = {}
	for lv in LuaData.arr(_data.get("levels", [])):
		for st in LuaData.arr((lv as Dictionary).get("stubs", [])):
			var ex: Dictionary = LuaData.dict((st as Dictionary).get("exit", {}))
			exits_data[str(ex.get("area", ""))] = str(ex.get("spawn", ""))
	var lift: Dictionary = LuaData.arr(_data.get("lifts", []))[0] as Dictionary
	exits_data[str(lift.get("to_area", ""))] = str(lift.get("spawn", ""))
	t.check("header_declarations_match_the_data", spawns_decl == spawns_data and warps_decl == exits_data and spawns_data == ["from_farm", "from_hyggebyen", "from_skovlift"],
		"the @marker declarations of the header (spawns %s, ways out %s) say what the data says (spawns %s, stubs and the lift %s); `default` is implicit" % [spawns_decl, warps_decl, spawns_data, exits_data])
	var counts: Dictionary = {
		"levels": LuaData.arr(_data.get("levels", [])).size(), "bridges": LuaData.arr(_data.get("bridges", [])).size(), "ladders": LuaData.arr(_data.get("ladders", [])).size(),
		"lifts": LuaData.arr(_data.get("lifts", [])).size(), "buildings": LuaData.arr(_data.get("buildings", [])).size(), "lanterns": LuaData.arr(_data.get("lanterns", [])).size(),
		"door_lamps": LuaData.arr(_data.get("door_lamps", [])).size(), "owl_holes": LuaData.arr(_data.get("owl_holes", [])).size(), "bat_houses": LuaData.arr(_data.get("bat_houses", [])).size(),
		"landmarks": LuaData.arr(_data.get("landmarks", [])).size(), "spawns": LuaData.dict(_data.get("spawns", {})).size(), "lights": LuaData.arr(_data.get("lights", [])).size(),
		"foliage": LuaData.arr(_data.get("foliage", [])).size(),
	}
	t.check("data_counts", counts == {"levels": 8, "bridges": 9, "ladders": 1, "lifts": 1, "buildings": 14, "lanterns": 32, "door_lamps": 14, "owl_holes": 3, "bat_houses": 3, "landmarks": 10, "spawns": 4, "lights": 12, "foliage": 2},
		"8 levels, 9 bridges, 1 ladder, 1 lift, 14 buildings (13 huts + the Raadhus), 32 lanterns + 14 door lamps, 3 owl holes, 3 bat houses, 10 landmarks, 4 spawns, 12 lights, 2 foliage clusters: %s" % [counts])
	var markers: Array[Dictionary] = CityData.markers(_data)
	var by_type: Dictionary = {}
	for mk in markers:
		by_type[str(mk["type"])] = int(by_type.get(str(mk["type"]), 0)) + 1
	t.check("marker_slots", by_type == {"npc": 7, "seed_basket": 1, "lift": 1, "climb": 1, "node": 3, "ambient_owl": 2},
		"the slots of design 4.4 / 4.5: 7 npc markers (Hoppe, Pip, Brumme twice, Sofus, Fru Ugle, Oak), the seed basket, the lift, the ladder, 3 `node` markers for the kitchen gardens, 2 ambient owls: %s" % [by_type])


func _validator(t) -> void:
	var problems: Array[String] = LevelRules.validate(_data)
	var ranks: Dictionary = {}
	var unique: bool = true
	var multiples: bool = true
	for key in ["levels", "bridges"]:
		for rec in LuaData.arr(_data.get(key, [])):
			var r: int = LuaData.int_of((rec as Dictionary).get("rank", 0))
			unique = unique and not ranks.has(r)
			multiples = multiples and r % 10 == 0
			ranks[r] = str((rec as Dictionary).get("id", ""))
	var want: Array[int] = [10, 20, 70, 80, 90, 100, 150, 160, 30, 40, 50, 60, 110, 120, 130, 140, 170]
	var got: Array[int] = []
	for r in ranks:
		got.append(int(r))
	want.sort()
	got.sort()
	t.check("validator_green_on_shipped_json", problems.is_empty(), "LevelRules.validate(data/traetoppen/traetoppen.json): %d problems %s" % [problems.size(), problems.slice(0, 3)])
	t.check("ranks_unique_multiples_of_ten", unique and multiples and got == want, "17 ranks, unique, multiples of 10: platforms 10 20 70 80 90 100 150 160, bridges 30 40 50 60 110 120 130 140 170 (got %s)" % [got])


# ================================================================== localization and config

func _csv_rows() -> Dictionary:
	var rows: Dictionary = {}
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return rows
	f.get_csv_line()
	while not f.eof_reached():
		var cols: PackedStringArray = f.get_csv_line()
		if cols.size() >= 3 and cols[0] != "":
			rows[cols[0]] = {"da": cols[1], "en": cols[2]}
	return rows


func _keys_and_config(t) -> void:
	var rows: Dictionary = _csv_rows()
	var want: Array[String] = []
	for i in range(1, 11):
		want.append("TRAE_LANDMARK_%d" % i)
	want.append_array(["TRAE_PROMPT_BOARD", "TRAE_PROMPT_BATH", "TRAE_PROMPT_SEEDS", "TRAE_PROMPT_CACHE", "TRAE_PROMPT_TRAVEL", "TRAE_LIFT_CLOSED", "TRAE_LIFT_LOCKED",
		"TRAE_SIGN_FARM", "TRAE_SIGN_HYGGEBYEN", "TRAE_SIGN_SKOVLIFT"])
	var missing: Array[String] = []
	var empty: Array[String] = []
	for key in want:
		if not rows.has(key):
			missing.append(key)
		elif str((rows[key] as Dictionary)["da"]) == "" or str((rows[key] as Dictionary)["en"]) == "":
			empty.append(key)
	var names_da: Array[String] = ["Torvet", "Rådhuset", "Postkontoret", "Hoppes hytte", "Brummes værksted", "Badehuset", "Køkkenhaverne", "Hængebroer", "Uglehulerne", "Flagermusenes huse"]
	var names_ok: bool = true
	for i in 10:
		names_ok = names_ok and str((rows.get("TRAE_LANDMARK_%d" % (i + 1), {}) as Dictionary).get("da", "")) == names_da[i]
	# every key the data and the builder name is a row (the landmarks' name_key, the signs, the lift gate, the preview tag)
	var named: Array[String] = []
	for lm in LuaData.arr(_data.get("landmarks", [])):
		named.append(str((lm as Dictionary).get("name_key", "")))
	for s in CityBuilder.SIGNS:
		named.append(str((s as Dictionary)["key"]))
	var unnamed: Array[String] = []
	for key in named:
		if not rows.has(key):
			unnamed.append(key)
	var foreign: Array[String] = []
	for key in rows:
		if not str(key).begins_with("TRAE_"):
			foreign.append(str(key))
	var lint: Dictionary = t.run_tool(t.python(), PackedStringArray(["-I", ProjectSettings.globalize_path("res://tools/loc/csv_lint.py")]))
	var lint_lines: PackedStringArray = lint["lines"]
	t.check("keys_da_en_complete", missing.is_empty() and empty.is_empty() and names_ok and unnamed.is_empty() and foreign.is_empty() and int(lint["code"]) == 0 \
		and FileAccess.file_exists(CSV_PATH + ".import") and FileAccess.get_file_as_string(CSV_PATH + ".import").contains("importer=\"keep\""),
		"localization/traetoppen.csv: %d rows, every TRAE_ key of the order (landmarks 1..10 with the sketch names, prompts, lift, signs, the preview tag) has da AND en (missing %s, empty %s), every key the data / builder names exists %s, only TRAE_ rows %s, keep-import present; tools/loc/csv_lint.py exit %s (%s)" % [rows.size(), missing, empty, unnamed, foreign, lint["code"], lint_lines[lint_lines.size() - 1] if lint_lines.size() > 0 else ""])
	# --- config_numbers_documented: lua/config/traetoppen.lua, read through GameData.cfg
	var gm: Node = t.autoload("GameManager")
	var cfg: Dictionary = CityData.config()
	var bad: Array[String] = []
	for key in CONFIG_WANT:
		var wanted: Variant = CONFIG_WANT[key]
		var have: Variant = cfg.get(key, null)
		if wanted is Dictionary:
			for sub in (wanted as Dictionary):
				var hv: Variant = LuaData.dict(have).get(sub, null)
				var wv: Variant = (wanted as Dictionary)[sub]
				if not _same(hv, wv):
					bad.append("%s.%s: %s != %s" % [key, sub, hv, wv])
		elif not _same(have, wanted):
			bad.append("%s: %s != %s" % [key, have, wanted])
	var text: String = FileAccess.get_file_as_string(LUA_PATH)
	var lines: PackedStringArray = text.split("\n")
	var undocumented: Array[String] = []
	for key in CityData.CONFIG_KEYS:
		var found: bool = false
		for i in lines.size():
			if lines[i].strip_edges().begins_with("%s = " % key):
				found = i > 0 and lines[i - 1].strip_edges().begins_with("--")
				break
		if not found:
			undocumented.append(key)
	var fast: Array = LuaData.arr(LuaData.dict(cfg.get("fast_travel", {})).get("stops", []))
	var stub_ok: bool = text.contains("used only by Rejsestolpen (V6, STRETCH)") and fast.size() == 4
	var same_scale: bool = is_equal_approx(float(cfg.get("scale", 0.0)), _k) and is_equal_approx(LuaData.num(LuaData.dict(cfg.get("zoom", {})).get("default", 0.0)), LuaData.num(LuaData.dict(_data.get("zoom", {})).get("default", 1.0)))
	t.check("config_numbers_documented", bad.is_empty() and undocumented.is_empty() and stub_ok and same_scale and gm != null,
		"lua/config/traetoppen.lua through GameData.cfg: %d keys read (%s), every key has its comment line (undocumented %s), the numbers of design 4.5 hold (deviations %s), scale = the JSON's %.1f, the fast_travel rows are labelled `used only by Rejsestolpen (V6, STRETCH)` (4 stops)" % [CityData.CONFIG_KEYS.size(), CityData.CONFIG_KEYS, undocumented, bad, _k])


func _same(a: Variant, b: Variant) -> bool:
	if a == null:
		return false
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same((a as Array)[i], (b as Array)[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		for key in (b as Dictionary):
			if not (a as Dictionary).has(key) or not _same((a as Dictionary)[key], (b as Dictionary)[key]):
				return false
		return true
	return str(a) == str(b)


# ================================================================== V5's art joins the data

func _art_joins(t) -> void:
	ArtCatalog.reset()
	CityData.clear_cache()
	var ids: Array[String] = CityData.art_ids(_data)
	var not_real: Array[String] = []
	for id in ids:
		if not ArtCatalog.has_real_prop(StringName(id)):
			not_real.append(id)
	var props: Dictionary = CityData.city_props()
	var hut_of: Dictionary = LuaData.dict(LuaData.dict(props.get("_city", {})).get("hut_of", {}))
	var bad_huts: Array[String] = []
	var no_night: Array[String] = []
	var no_pennant: Array[String] = []
	for b in LuaData.arr(_data.get("buildings", [])):
		var bd: Dictionary = b
		var id: String = str(bd["id"])
		var art: String = str(hut_of.get(id, ""))
		var rec: Dictionary = LuaData.dict(props.get(art, {}))
		if art == "" or rec.is_empty():
			bad_huts.append(id)
			continue
		var wall_art: float = LuaData.num(rec.get("wall_r", 0.0))
		if absf(wall_art - LuaData.num(bd["wall_r"])) > 0.15 * LuaData.num(bd["wall_r"]):
			bad_huts.append("%s (wall_r %.1f vs %.1f)" % [id, wall_art, LuaData.num(bd["wall_r"])])
		if CityData.night_art(StringName(art)) == &"":
			no_night.append(id)
		if bd.has("pennant") and CityData.pennant_art(str(bd["pennant"])) == &"":
			no_pennant.append(id)
	var discs: Array[String] = []
	for lv in LuaData.arr(_data.get("levels", [])):
		discs.append(String(CityData.disc_art(LuaData.num((lv as Dictionary)["rx"]))))
	var planters: Array[String] = []
	for kind in CityData.PLANTER_ART:
		planters.append(String(CityData.PLANTER_ART[kind]))
	t.check("art_joins_props_json", not_real.is_empty() and bad_huts.is_empty() and no_night.is_empty() and no_pennant.is_empty() and discs == ["platform_disc_184", "platform_disc_184", "platform_disc_196", "platform_disc_306", "platform_disc_171", "platform_disc_184", "platform_disc_184", "platform_disc_196"] \
		and planters == ["planter_box", "planter_box_berry"],
		"%d art ids named by the city data are real art in assets/iso_props/city (not real: %s); _city.hut_of covers the 14 buildings (wall_r within 15 percent, every hut has an additive night layer, every pennant colour resolves): problems %s %s %s; the discs by rx: %s; planter kinds herb / berry: %s" % [ids.size(), not_real, bad_huts, no_night, no_pennant, discs, planters])


# ================================================================== the built area

func _build_checks(t) -> void:
	var a: IsoArea = _area
	var stage: LevelStage = _city.stage if _city != null else null
	t.check("no_builder_error", _city != null and a.builder_error == "" and a.map.errors.is_empty() and _enter_errors.is_empty() and stage != null and a.map.is_builder() and a.map.id == &"traetoppen",
		"entering `traetoppen`: builder_error '%s', map errors %s, engine messages %s, CityBuilder and LevelStage on the area" % [a.builder_error, a.map.errors, _enter_errors.slice(0, 2)])
	if _city == null:
		return
	var floors: Node2D = stage.floors
	var counts: Dictionary = {
		"strips": stage.strips.size(), "railings": stage.railings.size(), "lanes": stage.lanes.size(), "lifts": stage.lifts.size(), "huts": _city.huts.size(),
		"discs": _named(floors, "Disc_"), "trunks": _named(floors, "Trunk_") + _named(a.objects, "Trunk_"), "lamp_groups": _named(floors, "Lamps_"),
		"lanterns": _sprites_of(floors, "lantern_hang").size(), "door_lamps": _sprites_of(floors, "lamp_door").size(), "owl_holes": _named(floors, "OwlHole_"), "owl_shelves": _named(floors, "OwlShelf_"),
		"bat_houses": _sprites_of(floors, "bat_house_hanging").size(), "bats": _named(floors, "bat_hang"), "foliage": _named(floors, "Foliage_"), "signs": _city.signs.size(), "warps": _city.warps.size(),
		"landmarks": _city.landmarks.size(), "halos": stage.glow.halos.size(), "lights": stage.glow.lights.size(),
	}
	var want: Dictionary = {"strips": 11, "railings": 8, "lanes": 4, "lifts": 1, "huts": 14, "discs": 8, "trunks": 15, "lamp_groups": 8, "lanterns": 32, "door_lamps": 14, "owl_holes": 3, "owl_shelves": 3,
		"bat_houses": 3, "bats": 3, "foliage": 2, "signs": 3, "warps": 2, "landmarks": 10, "halos": 46, "lights": 12}
	var wrong: Dictionary = {}
	for key in want:
		if int(counts.get(key, -1)) != int(want[key]):
			wrong[key] = "%s != %s" % [counts.get(key, -1), want[key]]
	var props_ok: bool = true
	for id in ["Prop_stall", "Prop_fire_pit", "Prop_mailbox", "Prop_log_stack", "Prop_notice_board", "Prop_seed_basket", "TubBack", "TubFront", "Ladder_main_ladder", "LadderCap_main_ladder"]:
		props_ok = props_ok and (a.objects.get_node_or_null(id) != null or a.get_node_or_null(id) != null)
	t.check("structure", wrong.is_empty() and props_ok and stage.fade.targets.size() == 22 and _city.art_problems.is_empty(),
		"the built city: 9 bridges + 2 stubs, 8 rim rails, the ladder (2 ends) and the trunk climb (2 ends), 1 Skovlift, 14 huts, 8 discs, 15 trunk segments, 32 lanterns + 14 door lamps, 3 owl holes with shelves, 3 bat houses with a hanging bat each, 2 foliage clusters, 3 signs, 2 warps, 10 landmark circles, 46 halos + 12 lights, the stall / fire pit / mailbox / log stack / notice board / seed basket / tub halves / ladder, 22 occluders; wrong %s, art problems %s" % [wrong, _city.art_problems])
	var player_lights := _count(_world.player,"PointLight2D")
	var citizen_lights := 0
	for node in _all_nodes(a):
		if node is NpcGlow: citizen_lights += _count(node,"PointLight2D")
	var point_lights: int = _count(a,"PointLight2D")-player_lights-citizen_lights
	var active_lights := _all_nodes(a).filter(func(node):return node is PointLight2D and node.enabled and node.is_visible_in_tree()).size()
	t.check("point_lights_max",point_lights<=12 and citizen_lights<=1 and stage.glow.halos.size()==46 and stage.glow.lights.size()<=LevelGlow.MAX_LIGHTS and point_lights==stage.glow.lights.size() and active_lights<=16,
		"city owns %d PointLight2D /12 and %d halos; player owns %d separately (lantern/ghost/burst); %d enabled visible lights /16 for the whole area" % [point_lights,stage.glow.halos.size(),player_lights,active_lights])
	# --- walkable_test: any level polygon
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261015
	var mismatch: int = 0
	var hits: int = 0
	var valid: bool = a.walkable_test.is_valid()
	for i in 1500:
		var p := Vector2(rng.randf_range(_reg.bounds.position.x, _reg.bounds.end.x), rng.randf_range(_reg.bounds.position.y, _reg.bounds.end.y))
		var on_level: bool = _reg.level_at(p) != null
		if on_level:
			hits += 1
		if valid and bool(a.walkable_test.call(p)) != on_level:
			mismatch += 1
	var spawns_walk: bool = true
	for name in a.spawns:
		spawns_walk = spawns_walk and bool(a.walkable_test.call(a.spawns[name]))
	t.check("walkable_test_matches_levels", valid and mismatch == 0 and hits > 200 and spawns_walk and a.bounds == Rect2(-600, -450, 6750, 4350) and a.bounds == CityBuilder.camera_bounds(_reg.bounds) and a.zoom_range == Vector2(0.2, 0.7) and is_equal_approx(a.zoom_default, 0.4) \
		and ["default","from_farm","from_hyggebyen","from_skovlift"].all(func(name):return a.spawns.has(name)) and not bool(a.walkable_test.call(_sk(100, 900))) and not bool(a.walkable_test.call(_sk(900, 630))),
		"area.walkable_test is any level polygon: 1500 random points agree with LevelRegistry.level_at (%d on a level, %d disagreements), all authored and interior-return spawns %s are walkable, the void and the main trunk are not; camera bounds %s (the sketch's bounds with %d px of headroom above), zoom %s default %.1f" % [hits, mismatch, a.spawns.keys(), a.bounds, int(CityBuilder.HEADROOM_PX), a.zoom_range, a.zoom_default])
	# --- the sky, the far trunks and the canopy
	var backdrop_ok: bool = false
	var sky: Sprite2D = a.backdrop.get_node_or_null("Sky") as Sprite2D
	var far: Node2D = a.backdrop.get_node_or_null("Far") as Node2D
	var far_above: Node2D = a.backdrop.get_node_or_null("FarAbove") as Node2D
	var sky_above: ColorRect = a.backdrop.get_node_or_null("SkyAbove") as ColorRect
	var headroom_rect: Rect2 = Rect2(a.bounds.position, Vector2(a.bounds.size.x, _reg.bounds.position.y - a.bounds.position.y))
	var above_ok: bool = false
	var tiles_ok: bool = false
	if sky != null and far != null:
		var sky_rect := Rect2(sky.position, Vector2(sky.texture.get_width(), sky.texture.get_height()) * sky.scale)
		var far_rect: Rect2 = _tiles_rect(far)
		# no tile repeats its texture: the bilinear filter would blend the dark ground rows of the tile into its top edge (a hairline at the sketch's top edge)
		tiles_ok = far.get_child_count() == CityBuilder.FAR_REPEATS
		for tile in far.get_children():
			tiles_ok = tiles_ok and (tile as Sprite2D).texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED
		backdrop_ok = sky_rect.encloses(_reg.bounds) and far_rect.encloses(_reg.bounds) and tiles_ok and bool(ArtCatalog.backdrop(&"treetop")["real"])
		# the camera may look HEADROOM_PX above the sketch: the sky above it and the mirrored far trunks (joined at the sketch's top edge) cover that strip
		if far_above != null and sky_above != null:
			var far_above_rect: Rect2 = _tiles_rect(far_above)
			above_ok = far_above.get_child_count() == CityBuilder.FAR_REPEATS and (far_above.get_child(0) as Sprite2D).flip_v and far_above_rect.encloses(headroom_rect) \
				and absf(far_above_rect.end.y - far.position.y) < 0.5 and (far_above.get_child(0) as Sprite2D).scale == (far.get_child(0) as Sprite2D).scale \
				and Rect2(sky_above.position, sky_above.size).encloses(headroom_rect)
	var canopy: CanvasLayer = a.get_node_or_null("Canopy") as CanvasLayer
	var strip: Sprite2D = canopy.get_node_or_null("Strip") as Sprite2D if canopy != null else null
	var vp_w: float = a.get_viewport().get_visible_rect().size.x
	var cam0: Camera2D = a.get_viewport().get_camera_2d()
	var zoom0: float = cam0.zoom.x if cam0 != null else 0.4
	t.check("backdrop_and_canopy", backdrop_ok and above_ok and canopy != null and canopy.layer == 3 and strip != null and absf(strip.scale.x - vp_w / 2048.0) < 0.001 \
		and absf(strip.position.y - (a.get_viewport().get_visible_rect().size.y * CityBuilder.CanopyFrame.fraction_for(zoom0) - float(strip.texture.get_height()) * strip.scale.x)) < 0.5 and strip.texture == ArtCatalog.prop(&"canopy_top_strip")["texture"],
		"the treetop sky and the far trunks (V5, real art through ArtCatalog.backdrop) cover the sketch's bounds %s and, mirrored, the %d px of camera headroom above them (%s; the builder sizes its own sky: IsoArea's backdrop assumes Iso.ZOOM_MIN); the canopy frame is CanvasLayer 3 drawn at viewport_width / 2048 = %.3f, slid up so its fringe takes %.0f percent of the screen height at the camera zoom %.2f (see canopy_gives_way_when_zoomed_out)" % [_reg.bounds, int(CityBuilder.HEADROOM_PX), above_ok, vp_w / 2048.0, CityBuilder.CanopyFrame.fraction_for(zoom0) * 100.0, zoom0])
	t.check("art_complete", ArtCatalog.missing().is_empty() and _city.art_problems.is_empty(), "ArtCatalog.missing() after building the city (every prop, backdrop and character the city draws is real art): %s" % [ArtCatalog.missing()])
	# --- the signs stand on open floor of their level next to the way they point at, and they read
	var sign_bad: Array[String] = []
	for sd in CityBuilder.SIGNS:
		var sp: Vector2 = _sk(float((sd["at"] as Array)[0]), float((sd["at"] as Array)[1]))
		if _reg.level_id_at(sp) != StringName(str(sd["level"])):
			sign_bad.append("%s is on %s" % [sd["id"], _reg.level_id_at(sp)])
	var reads: Array = []
	var rcb: Callable = func(key: String) -> void: reads.append(key)
	EventBus.whisper_requested.connect(rcb)
	for it in _city.signs:
		it.interact(null)
	EventBus.whisper_requested.disconnect(rcb)
	t.check("signs_stand_on_their_levels", sign_bad.is_empty() and reads == ["TRAE_SIGN_FARM", "TRAE_SIGN_HYGGEBYEN", "TRAE_SIGN_SKOVLIFT"],
		"the three signs (farm bridge on G, Hyggebyen bridge on F, the Skovlift on B) stand on open floor of their level (problems %s) and whisper their TRAE_SIGN_ keys when read: %s" % [sign_bad, reads])
	# --- the two ambient owls (landmark 9): idle pack owls in the holes after Fru Ugle's, drawn above the hole decals, nothing to talk to or bump into
	var owl_bad: Array[String] = []
	var hole_pts: Array[Vector2] = []
	for hd in LuaData.arr(_data.get("owl_holes", [])).slice(1):
		hole_pts.append(CityData.world(_data, (hd as Dictionary)["at"]))
	if _city.ambient_owls.size() != 2:
		owl_bad.append("%d owls" % _city.ambient_owls.size())
	for i in _city.ambient_owls.size():
		var holder: Node2D = _city.ambient_owls[i]
		var visual: IsoChibiSprite2D = holder.get_child(0) as IsoChibiSprite2D
		if holder.z_index != 176 or visual == null or visual.resolved_id != "owl" or visual.current_clip != &"idle" or holder.global_position.distance_to(hole_pts[i]) > 1.0:
			owl_bad.append("owl %d: z %d at %s" % [i, holder.z_index, holder.global_position])
		for n in _all_nodes(holder):
			if n is CollisionObject2D or n is Interactable2D or n.is_in_group("npc") or n.is_in_group("interactable"):
				owl_bad.append("owl %d has %s" % [i, n.name])
	t.check("ambient_owls_sit_in_their_holes", owl_bad.is_empty(), "the second and third owl holes hold a plain idle pack owl each (IsoChibiSprite2D `owl`, z 176 above the hole decals, no collision, no interaction, not an npc): problems %s" % [owl_bad])
	# --- ladder, climb zone, lift: V3's pieces, hard in preview mode
	var ladder_ok: bool = false
	var ends: Array = []
	for lane in stage.lanes:
		if not lane.perk_only:
			ends.append(String(lane.from_id))
	ends.sort()
	var lift: RopeLift = stage.lifts[0] if not stage.lifts.is_empty() else null
	ladder_ok = ends == ["torvet", "upper"] and lift != null and lift.to_area == &"moerkeskoven" and _city.lift_gate != null and not lift.is_enabled() and _city.lift_gate.is_enabled()
	t.check("ladder_and_lift_are_built", ladder_ok, "the ladder has its two ends (torvet, upper) and the Skovlift its basket at the rim of tree B; the lift answers through the gate (the rope's own interactable is off, so the player's E finds ONE target)")


## The rectangle (global px) the sprites under a container cover.
func _tiles_rect(container: Node2D) -> Rect2:
	var out := Rect2()
	var first: bool = true
	for c in container.get_children():
		var sp: Sprite2D = c as Sprite2D
		var size: Vector2 = sp.region_rect.size if sp.region_enabled else Vector2(sp.texture.get_width(), sp.texture.get_height())
		var r := Rect2(container.position + sp.position, size * sp.scale)
		out = r if first else out.merge(r)
		first = false
	return out


func _named(root: Node, prefix: String) -> int:
	var n: int = 0
	for c in root.get_children():
		if String(c.name).begins_with(prefix):
			n += 1
	return n


func _sprites_of(root: Node, art: String) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for x in _all_nodes(root):
		if x is Sprite2D and String(x.name).begins_with(art):
			out.append(x as Sprite2D)
	return out


## Of the sketch points `wanted`, how many have no built node within `tol` sketch px.
func _unmatched(built: Array[Vector2], wanted: Array, tol: float = 1.0) -> int:
	var missing: int = 0
	for w in wanted:
		var p: Vector2 = Vector2(float(w[0]), float(w[1])) * _k
		var hit: bool = false
		for b in built:
			if b.distance_to(p) <= tol * _k:
				hit = true
				break
		if not hit:
			missing += 1
	return missing


func _extract_checks(t) -> void:
	if _extract.is_empty():
		t.fail("extract %s is missing" % EXTRACT_PATH)
		return
	var stage: LevelStage = _city.stage
	var floors: Node2D = stage.floors
	var off: Dictionary = {}
	# platforms: the discs
	var discs: Array[Vector2] = []
	for x in floors.get_children():
		if String(x.name).begins_with("Disc_"):
			discs.append((x as Node2D).position)
	var plats: Array = []
	for p in LuaData.arr(_extract["platforms"]):
		plats.append([p["cx"], p["cy"]])
	off["discs"] = _unmatched(discs, plats)
	# huts (13 in the extract; the Raadhus is the design's addition)
	var huts: Array[Vector2] = []
	for id in _city.huts:
		huts.append((_city.huts[id] as Node2D).position)
	var hut_pts: Array = []
	for h in LuaData.arr(_extract["huts"]):
		hut_pts.append([h["cx"], h["base_y"]])
	off["huts"] = _unmatched(huts, hut_pts)
	# lanterns and door lamps
	var lamps: Array[Vector2] = []
	for s in _sprites_of(floors, "lantern_hang"):
		lamps.append(s.position)
	var doors: Array[Vector2] = []
	for s in _sprites_of(floors, "lamp_door"):
		doors.append(s.position)
	off["lanterns"] = _unmatched(lamps, LuaData.arr(_extract["lanterns"]))
	off["door_lamps"] = _unmatched(doors, LuaData.arr(_extract["door_lamps"]))
	# owl holes, bat houses, planters
	var holes: Array[Vector2] = []
	for x in floors.get_children():
		if String(x.name).begins_with("OwlHole_"):
			holes.append((x as Node2D).position)
	off["owl_holes"] = _unmatched(holes, LuaData.arr(_extract["owl_holes"]))
	var tips: Array[Vector2] = []
	for s in _sprites_of(floors, "bat_house_hanging"):
		tips.append(s.position)
	var tip_pts: Array = []
	for b in LuaData.arr(_extract["bat_houses"]):
		tip_pts.append([b["cx"], b["tip_y"]])
	off["bat_houses"] = _unmatched(tips, tip_pts)
	var beds: Array[Vector2] = []
	for m in CityData.markers_of(_data, "node"):
		beds.append(m["at"] as Vector2)
	off["planters"] = _unmatched(beds, LuaData.arr(_extract["planters"]))
	# trunks: the segment ends of every tree (cx and top) are among the data's trunks; the built containers sit at (cx, ground y)
	var tops: Array[Vector2] = []
	for rec in LuaData.arr(_data.get("trunks", [])):
		tops.append(Vector2(LuaData.num((rec as Dictionary)["cx"]), LuaData.num((rec as Dictionary)["y_top"])) * _k)
	var seg_pts: Array = []
	for key in _extract["trunks"]:
		for seg in LuaData.arr(_extract["trunks"][key]):
			seg_pts.append([seg["cx"], seg["y_top"]])
	off["trunk_segments"] = _unmatched(tops, seg_pts)
	var bases: Array[Vector2] = []
	for x in _all_nodes(_area):
		if x is Node2D and String(x.name).begins_with("Trunk_") and x.get_parent() != null and String(x.get_parent().name) in ["Floors", "Objects"]:
			bases.append((x as Node2D).position)
	var base_pts: Array = []
	for rec in LuaData.arr(_data.get("trunks", [])):
		base_pts.append([LuaData.num((rec as Dictionary)["cx"]), LuaData.num((rec as Dictionary)["y_bot"])])
	off["trunk_bases"] = _unmatched(bases, base_pts)
	# ladder and lift
	var ladder_node: Node2D = _area.objects.get_node_or_null("Ladder_main_ladder") as Node2D
	var ladder: Dictionary = LuaData.arr(_extract["ladders"])[0] as Dictionary
	off["ladder"] = 0 if ladder_node != null and ladder_node.position.distance_to(Vector2((float(ladder["x0"]) + float(ladder["x1"])) * 0.5, float(ladder["y_bottom"])) * _k) <= _k else 1
	var lf: Dictionary = _extract["lift"]
	var lift: RopeLift = stage.lifts[0]
	off["lift"] = 0 if lift.top_pos.distance_to(Vector2(float(lf["x"]), float(lf["y_top"])) * _k) <= _k and lift.basket_pos.distance_to(Vector2(float(lf["x"]), float(lf["y_basket"])) * _k) <= _k else 1
	# bridges: the ends of the centre lines
	var ends: Array[Vector2] = []
	for b in _reg.bridges:
		ends.append(b.path[0])
		ends.append(b.path[b.path.size() - 1])
	var end_pts: Array = []
	for b in LuaData.arr(_extract["bridges"]):
		end_pts.append(b["start"])
		end_pts.append(b["end"])
	off["bridge_ends"] = _unmatched(ends, end_pts)
	# the sketch's characters: the npc markers that have a drawn figure stand where it is drawn (Hoppe, Brumme at the stall, Sofus)
	var stands: Array[Vector2] = []
	for m in CityData.markers_of(_data, "npc"):
		stands.append(m["at"] as Vector2)
	var drawn: int = 0
	for c in LuaData.arr(_extract["characters"]):
		for s in stands:
			if s.distance_to(Vector2(float(c[1]), float(c[2])) * _k) <= _k:
				drawn += 1
				break
	var total_off: int = 0
	for key in off:
		total_off += int(off[key])
	t.check("json_matches_extract_within_1px", total_off == 0 and drawn >= 3,
		"the BUILT nodes against the parsed sketch (v2_city_extract.json), 1 sketch px = %.0f world px: discs, 13 huts, 32 lanterns, 14 door lamps, 3 owl holes, 3 bat houses, 3 planters, every trunk segment, the ladder, the Skovlift, the nine bridge lines; unmatched %s; %d npc markers stand where a sketch figure is drawn (Hoppe, Brumme, Sofus)" % [_k, off, drawn])
	# --- rank_order: V3's validator on the shipped data, and the built draw order follows it
	var problems: Array[String] = LevelRules.validate(_data)
	var wrong: Array[String] = []
	for lv in _reg.platforms:
		var disc: Node = floors.get_node_or_null("Disc_%s" % lv.id)
		if disc == null or (disc as Node2D).z_index != lv.rank - 4:
			wrong.append("disc %s" % lv.id)
	for b in LuaData.arr(_data.get("buildings", [])):
		var hut: Node2D = _city.huts.get(str((b as Dictionary)["id"]), null) as Node2D
		if hut == null or hut.z_index != CityData.rank_of(_data, (b as Dictionary)["level"]):
			wrong.append("hut %s" % (b as Dictionary)["id"])
	for strip in stage.strips:
		if not strip.is_stub and strip.deck.z_index != strip.level.rank - 4:
			wrong.append("deck %s" % strip.level.id)
	for rec in LuaData.arr(_data.get("trunks", [])):
		var tr: Dictionary = rec
		var holder: Node = floors if str(tr["part"]) == "lower" else _area.objects
		var node: Node2D = holder.get_node_or_null("Trunk_%s" % tr["id"]) as Node2D
		if node == null or node.z_index != LuaData.int_of(tr["rank"]):
			wrong.append("trunk %s" % tr["id"])
	var lamp_z: bool = true
	for g in floors.get_children():
		if String(g.name).begins_with("Lamps_"):
			lamp_z = lamp_z and (g as Node2D).z_index == CityData.rank_of(_data, String(g.name).trim_prefix("Lamps_")) + 1
	t.check("rank_order", problems.is_empty() and wrong.is_empty() and lamp_z,
		"LevelRules.validate(data/traetoppen/traetoppen.json): %d problems; the built draw order is the data's: discs at rank - 4, huts and objects at the rank of their level, lower trunks at rank - 6, upper trunks at the rank of the deck, bridge decks at rank - 4, lamps at rank + 1 (wrong %s)" % [problems.size(), wrong])


# ================================================================== budgets

func _budgets(t) -> void:
	var map: AreaMap = WorldRoot2D.load_map(&"traetoppen")
	var best: float = 1e9
	var worst: float = 0.0
	var city_best: float = 1e9
	for i in 8:
		var host := Node2D.new()
		_world.add_child(host)
		var a := IsoArea.new()
		host.add_child(a)
		a.setup(map)
		if i > 0:
			best = minf(best, float(a.build_ms))
			worst = maxf(worst, float(a.build_ms))
			city_best = minf(city_best, CityBuilder.of(a).build_ms)
		host.free()
	var nodes: int = _all_nodes(_area).size()
	t.check("builds_in_budget", best <= 40.0 and nodes < 1500, "IsoArea.setup of the city with V5's art and the preview citizens: warm rebuild best %.0f ms, worst %.0f ms (budget 40; the builder itself %.1f ms); %d nodes in the area (the first visit of a session also loads the textures: 0.4-0.6 s behind the black screen, later visits are warm, so no `@cache true`)" % [best, worst, city_best, nodes])
	# a builder area is never parked: leaving it frees it, coming back builds again
	var before: IsoArea = _area
	_world._enter(&"farm", &"default")
	await t.frames(2)
	var parked: bool = _world._cache.has(&"traetoppen")
	var freed: bool = not is_instance_valid(before) or before.is_queued_for_deletion()
	await _enter_city(t)
	t.check("builder_area_is_never_parked", not WorldRoot2D.is_parkable(_area) and not parked and freed and _area != before and CityBuilder.of(_area) != null,
		"leaving the city frees the area (parked: %s, freed: %s) and the next visit builds a new one; WorldRoot2D.is_parkable is false for a @builder map" % [parked, freed])


# ================================================================== markers, citizens

func _markers_and_citizens(t) -> void:
	var a: IsoArea = _area
	var npcs: Array[Dictionary] = CityData.markers_of(_data, "npc")
	var p14: bool = str(IsoArea.resolve_handler("npc")["kind"]) != "none"
	# --- the ids and the slots of design 4.4 / 4.5 (hard: npcs.lua is V1's, landed)
	var ids: Array[String] = []
	var missing: Array[String] = []
	var wrong_home: Array[String] = []
	var no_art: Array[String] = []
	for m in npcs:
		var id: String = str(m["id"])
		ids.append(id)
		var row: Dictionary = GameData.dict_of(GameData.cfg("npcs.%s" % id, {}))
		if row.is_empty():
			missing.append(id)
			continue
		if str(row.get("home_area", "")) != "traetoppen":
			wrong_home.append(id)
		if not IsoChibiSprite2D.character_exists(str(row.get("visual", ""))):
			no_art.append(id)
	ids.sort()
	var by_id: Dictionary = {}
	for m in npcs:
		if not by_id.has(str(m["id"])):
			by_id[str(m["id"])] = []
		(by_id[str(m["id"])] as Array).append(m)
	var hoppe: Dictionary = (by_id["gardener_hoppe"] as Array)[0]
	var pip: Dictionary = (by_id["postman_pip"] as Array)[0]
	var sofus: Dictionary = (by_id["bathkeeper_sofus"] as Array)[0]
	var ugle: Dictionary = (by_id["appraiser_fru_ugle"] as Array)[0]
	var oak: Dictionary = (by_id["guard_oak"] as Array)[0]
	var brumme_whens: Array = []
	var brumme_levels: Array = []
	for m in (by_id["carpenter_brumme"] as Array):
		brumme_whens.append(str(m["when"]))
		brumme_levels.append(str(m["level"]))
	brumme_whens.sort()
	brumme_levels.sort()
	var hut: Callable = func(id: String) -> Dictionary: return CityData.record(_data, "buildings", id)
	var lift_stand: Vector2 = _reg.lifts[0]["stand"]
	var ugle_row: Dictionary = GameData.dict_of(GameData.cfg("npcs.appraiser_fru_ugle", {}))
	var first_hole: Vector2 = CityData.world(_data, (LuaData.arr(_data["owl_holes"])[0] as Dictionary)["at"])
	var slots_ok: bool = str(hoppe["level"]) == "a" and str((hut.call("h1") as Dictionary).get("pennant", "")) == "e58fa6" and not CityData.markers_of(_data, "seed_basket").is_empty() \
		and str(pip["level"]) == "b" and str((hut.call("h3") as Dictionary).get("pennant", "")) == "6fa8e0" and not CityData.record(_data, "props", "mailbox").is_empty() and str(CityData.record(_data, "props", "mailbox")["level"]) == "b" \
		and brumme_whens == ["flag:brumme_at_stall", "flag:brumme_at_work"] and brumme_levels == ["c", "torvet"] and str(sofus["level"]) == "e" and not CityData.record(_data, "props", "bath_tub").is_empty() \
		and bool(ugle["window"]) and is_equal_approx(float(ugle["reach"]), 420.0) and str(ugle_row.get("schedule", "")) == "stay" and (ugle["at"] as Vector2).distance_to(first_hole) <= 15.0 * _k \
		and (oak["at"] as Vector2).distance_to(lift_stand) <= 60.0 * _k and not CityData.record(_data, "props", "stall").is_empty() and bool(CityData.record(_data, "props", "stall").get("decor", false))
	t.check("npc_markers_resolve_in_npcs_lua", ids == ["appraiser_fru_ugle", "bathkeeper_sofus", "carpenter_brumme", "carpenter_brumme", "gardener_hoppe", "guard_oak", "postman_pip"] and missing.is_empty() and wrong_home.is_empty() and no_art.is_empty() and slots_ok,
		"the 7 npc markers %s are rows of lua/config/npcs.lua (V1; missing %s, home elsewhere %s, no art %s) and fill the slots of design 4.4: Hoppe on A (H1 pink pennant, the seed basket at his door), Pip on B (H3 blue pennant, the mailbox), Brumme twice (the workshop on C `when=flag:brumme_at_work`, the Torvet stall `when=flag:brumme_at_stall`), Sofus in the tub on E, Fru Ugle in the first owl hole of tree A (reach 420, schedule stay), Oak at the Skovlift, the stall is decor: %s" % [ids, missing, wrong_home, no_art, slots_ok])
	var director := _current_director()
	if director!=null:
		var gm: Node = t.autoload("GameManager")
		var previous_hour: int = gm.hour
		var previous_minute: int = gm.minute
		gm.hour=11
		gm.minute=0
		EventBus.time_of_day_changed.emit(11,0)
		NpcDirector.resync()
		await t.physics(3)
		var wanted := NpcDirector.select_presences(Routines.present_in("traetoppen",Routines.now_ctx()),16)
		var expected: Array = wanted.rows.map(func(row):return str(row.npc))
		var actual: Array = director.live.keys()
		expected.sort()
		actual.sort()
		t.check("npc_markers_resolve_to_the_handler",not expected.is_empty() and actual==expected and director.live.values().all(func(actor):return actor is Npc2D and actor.is_inside_tree() and actor.area==a),
			"the live director owns the scheduled citizens instead of duplicating seven static prototype markers: actual %s / scheduled %s" % [actual,expected])
		gm.hour=previous_hour
		gm.minute=previous_minute
		EventBus.time_of_day_changed.emit(previous_hour,previous_minute)
		NpcDirector.resync()
		await t.physics(3)
	elif p14:
		var made: int = 0
		for m in npcs:
			for rec in a.find_markers("npc"):
				if rec["node"] != null and str((rec["params"] as Dictionary).get("id", "")) == str(m["id"]):
					made += 1
					break
		t.check("npc_markers_resolve_to_the_handler", made >= 6, "P14's npc handler exists: %d of the 7 markers produced an Npc2D node" % made)
	else:
		_skip(t, "npc_markers_resolve_in_npcs_lua", "P14-npc-dialogue", "the handler part: the markers resolve to Npc2D nodes through scripts/world2d/npc_2d.gd")
	# --- V6 / V7 / P06: the next milestone
	var v6_missing: Array[String] = []
	for ty in V6_TYPES:
		if str(IsoArea.resolve_handler(ty)["kind"]) == "none":
			v6_missing.append(ty)
	if v6_missing.is_empty():
		var basket: Array[Dictionary] = a.find_markers("seed_basket")
		t.check("v6_interactables_resolve", not basket.is_empty() and basket[0]["node"] != null, "V6's handlers exist for board / bath / seed_basket / kiki_cache / rejsestolpe: the seed basket marker has its node")
	else:
		_skip(t, "v6_interactables", "V6-city-life", "board / bath / seed_basket / kiki_cache / rejsestolpe handlers (%s): the Raadhus board, the tub, Hoppe's basket, Kiki's caches and the signpost come with city life" % ", ".join(v6_missing))
	if FileAccess.file_exists(V7_DIALOGUE_PATH):
		var absent: Array[String] = []
		for id in NPC_IDS:
			if not FileAccess.file_exists("res://lua/dialogue/%s.lua" % id):
				absent.append(id)
		t.check("city_dialogue_files_exist", absent.is_empty(), "V7's dialogue exists for the city's citizens; missing %s" % [absent])
	else:
		_skip(t, "board_dialogue", "V7-dialogue-v2", "the dialogue of the Raadhus board and of the city citizens (lua/dialogue/<id>.lua): in M1a nobody talks")
	if ResourceLoader.exists(P06_PATH):
		t.check("player_is_the_real_player", str((_world.player.get_script() as Script).resource_path) != "res://scripts/world2d/player_stub_2d.gd", "P06's Player2D walks the city")
	else:
		_skip(t, "player_features", "P06-player-farm-core", "the built PlayerStub2D (walk, run, jump-free, E) walks the city; hearts, stamina, tools and the hotbar come with Player2D")
	# --- the kitchen gardens are `node` markers (P19): skipped silently while its handler is missing
	var kinds: Array[String] = []
	for rec in a.find_markers("node"):
		kinds.append(str((rec["params"] as Dictionary).get("kind", "")))
	var node_handler: bool = str(IsoArea.resolve_handler("node")["kind"]) != "none"
	if not node_handler:
		var arts: Array[String] = []
		for pr in ["planter1", "planter2", "planter3"]:
			var holder: Node = a.objects.get_node_or_null("Prop_%s" % pr)
			arts.append(holder.get_child(0).name if holder != null and holder.get_child_count() > 0 else "?")
		t.check("planter_kinds_skipped_without_p19", kinds == ["planter_herb", "planter_herb", "planter_berry"] and int(a.skipped_markers.get("node", 0)) == 3 and _city.planters_drawn == 3 and arts == ["planter_box", "planter_box", "planter_box_berry"] and a.handled_count("node") == 0,
			"3 `node` markers (kinds %s) on level G: P19's handler is absent, so IsoArea-style bookkeeping skips them silently (skipped_markers %s) and the three beds are drawn as plain decoration (%s); no engine message" % [kinds, a.skipped_markers, arts])
		_skip(t, "planters_are_resource_nodes", "P19-forest-combat", "harvestable planter_herb / planter_berry nodes with a daily respawn")
	# --- RT29: the Raadhus board and the tub are not V4's markers
	var types: Dictionary = {}
	for m in LuaData.arr(_data.get("markers", [])):
		types[str((m as Dictionary).get("type", ""))] = true
	var live_types: Dictionary = {}
	for rec in a.markers:
		live_types[str(rec["type"])] = true
	var bad_nodes: Array[String] = []
	for n in a.get_tree().get_nodes_in_group("interactable"):
		if a.is_ancestor_of(n):
			var nm: String = String(n.name).to_lower()
			if nm.contains("board") or nm.contains("bath") or nm.contains("mailbox"):
				bad_nodes.append(String(n.name))
	t.check("no_board_bath_markers_in_city", not types.has("board") and not types.has("bath") and not types.has("mailbox") and not live_types.has("board") and not live_types.has("bath") and not live_types.has("mailbox") \
		and a.find_markers("board").is_empty() and a.find_markers("bath").is_empty() and a.find_markers("mailbox").is_empty() and bad_nodes.is_empty() \
		and a.objects.get_node_or_null("Prop_notice_board") != null and a.objects.get_node_or_null("TubBack") != null and a.objects.get_node_or_null("Prop_mailbox") != null,
		"the data and the built markers hold no board, bath or mailbox marker (their handlers live inside the interiors of the towns track, RT29); the notice board, the tub halves and the red mailbox are decor props only; data marker types %s, built %s, interactables named like them %s" % [types.keys(), live_types.keys(), bad_nodes])


# ================================================================== fix round of the review: regressions

## The overview's top edge lies this far above the sketch's top edge (the camera has CityBuilder.HEADROOM_PX of room above it).
const OVERVIEW_ABOVE_PX := 100.0
## A figure's head above its feet in world px.
const HEAD_PX := 222.0
## Clearance between the canopy's lower edge and what must stay in view, screen px.
const CANOPY_CLEAR_PX := 4.0


## Screen position of a world point through the stub player's camera as it is now (limits, zoom and viewport included).
func _to_screen(world_pos: Vector2) -> Vector2:
	var cam: Camera2D = _world.player.camera
	var vp: Vector2 = _world.get_viewport().get_visible_rect().size
	return (world_pos - cam.get_screen_center_position()) * cam.zoom + vp * 0.5


func _canopy() -> CityBuilder.CanopyFrame:
	return _area.get_node_or_null("Canopy") as CityBuilder.CanopyFrame


## The top (centre x, centre y - ry) and the bottom of a platform's disc in world px.
func _disc_edge(id: StringName, bottom: bool) -> Vector2:
	var rec: Dictionary = CityData.record(_data, "levels", String(id))
	var c: Array = LuaData.arr(rec["centre"])
	var ry: float = LuaData.num(rec["ry"])
	return Vector2(LuaData.num(c[0]), LuaData.num(c[1]) + (ry if bottom else -ry)) * _k


## The world y of the apex of a hut's sprite (its base minus the pivot's height above the base).
func _hut_apex(id: String) -> Vector2:
	var b: Dictionary = CityData.record(_data, "buildings", id)
	var pivot: Vector2 = ArtCatalog.prop(CityData.hut_art(id))["pivot"] as Vector2
	return Vector2(LuaData.num(b["cx"]) * _k, LuaData.num(b["base_y"]) * _k - pivot.y)


## The northernmost walkable point of a level (a 6 px scan of its bounds): where a player stands closest to the top edge of the world.
func _top_walkable(id: StringName) -> Vector2:
	var lv: Level = _reg.get_level(id)
	var best := Vector2(1e9, 1e9)
	var x: float = lv.bounds.position.x
	while x < lv.bounds.end.x:
		var y: float = lv.bounds.position.y
		while y < best.y and y < lv.bounds.end.y:
			if _reg.level_id_at(Vector2(x, y)) == id:
				best = Vector2(x, y)
				break
			y += 6.0
		x += 6.0
	return best


## The camera on a world point at a zoom, settled (smoothing is off while the section looks around).
func _stand(t, at: Vector2, zoom: float) -> void:
	var p: Node2D = _world.player
	p.camera.zoom = Vector2.ONE * zoom
	p.global_position = at
	p.camera.reset_smoothing()
	await t.physics(2)
	await t.frames(2)


## The camera centre of the overview at zoom 0.2: the view's top edge OVERVIEW_ABOVE_PX above the sketch's top edge.
func _overview_centre() -> Vector2:
	var vp_h: float = _world.get_viewport().get_visible_rect().size.y
	return Vector2(_sk(900, 0).x, _reg.bounds.position.y - OVERVIEW_ABOVE_PX + vp_h / 0.2 * 0.5)


func _fix_round_checks(t) -> void:
	var p: Node2D = _world.player
	var vp: Vector2 = _world.get_viewport().get_visible_rect().size
	var saved_pos: Vector2 = p.global_position
	var saved_zoom: Vector2 = p.camera.zoom
	var saved_smooth: bool = p.camera.position_smoothing_enabled
	var saved_physics: bool = p.is_physics_processing()
	p.set_physics_process(false)
	p.camera.position_smoothing_enabled = false
	var canopy: CityBuilder.CanopyFrame = _canopy()
	# --- the canopy frame gives way when the camera zooms out (defect: at 0.2 it hid the top platforms A and B)
	var frac: Array[float] = [CityBuilder.CanopyFrame.fraction_for(0.2), CityBuilder.CanopyFrame.fraction_for(0.3), CityBuilder.CanopyFrame.fraction_for(0.4), CityBuilder.CanopyFrame.fraction_for(0.7)]
	var curve_ok: bool = absf(frac[0] - 0.04) < 0.0001 and absf(frac[2] - 0.16) < 0.0001 and frac[3] == frac[2] and frac[1] > frac[0] and frac[1] < frac[2] \
		and is_equal_approx(_area.zoom_default, CityBuilder.CanopyFrame.ZOOM_FULL) and is_equal_approx(_area.zoom_range.x, CityBuilder.CanopyFrame.ZOOM_MIN)
	var live: Array[String] = []
	for z in [0.2, 0.3, 0.4, 0.7, 0.2]:
		p.camera.zoom = Vector2.ONE * float(z)
		await t.frames(3)
		var share: float = canopy.bottom_edge() / vp.y
		live.append("%.2f -> %.3f" % [z, share])
		if absf(share - CityBuilder.CanopyFrame.fraction_for(float(z))) > 0.002:
			curve_ok = false
	# --- the canopy frame (CanvasLayer 3) follows the night colour: the world's CanvasModulate does not reach its canvas (review REND-01)
	var dn: DayNight = _world.day_night
	dn.override_hour = 22.0
	dn.snap()
	await t.frames(2)
	var night_tint: Color = canopy.sprite.modulate
	var night_ok: bool = night_tint == dn.color and night_tint.get_luminance() < 0.8
	dn.override_hour = 12.0
	dn.snap()
	await t.frames(2)
	var day_ok: bool = canopy.sprite.modulate == dn.color
	dn.override_hour = -1.0
	dn.snap()
	t.check("canopy_frame_follows_night_colour", night_ok and day_ok, "22:00: the frame's tint %s = the city's night colour (luminance %.2f); noon: back to %s" % [night_tint, night_tint.get_luminance(), canopy.sprite.modulate])
	t.check("canopy_gives_way_when_zoomed_out", curve_ok,
		"the canopy fringe takes %.0f percent of the screen height at the game zoom 0.4 and only %.0f percent at the area's minimum zoom 0.2 (linear in between, clamped beyond; %s): the live strip follows the camera zoom frame by frame (zoom -> share of the screen: %s)" % [frac[2] * 100.0, frac[0] * 100.0, frac, live])
	# --- the camera may look above the sketch: a player on the north rim of A or B at the game zoom stands below the canopy, head included
	var head: Array[String] = []
	var head_ok: bool = true
	for id in [&"a", &"b"]:
		var top: Vector2 = _top_walkable(id)
		await _stand(t, top, 0.4)
		var foot: Vector2 = _to_screen(top)
		var head_y: float = foot.y - HEAD_PX * 0.4
		var edge: float = canopy.bottom_edge()
		head.append("%s: feet y %.0f, head y %.0f, canopy edge %.0f" % [id, foot.y, head_y, edge])
		head_ok = head_ok and head_y >= edge
	var limit_ok: bool = int(p.camera.limit_top) == int(_area.bounds.position.y) and _area.bounds.position.y == _reg.bounds.position.y - CityBuilder.HEADROOM_PX and is_equal_approx(_area.bounds.end.y, _reg.bounds.end.y)
	t.check("camera_headroom_above_the_top_platforms", head_ok and limit_ok,
		"area.bounds reaches %d px above the sketch's top edge (camera limit_top %d, bottom unchanged): a player on the northernmost floor of A and of B at the game zoom 0.4 is drawn clear of the canopy, head included (%s)" % [int(CityBuilder.HEADROOM_PX), int(p.camera.limit_top), head])
	# --- the overview at the minimum zoom: both top platforms (discs and huts) below the canopy, the lower platforms inside the screen
	await _stand(t, _overview_centre(), 0.2)
	var cb: float = canopy.bottom_edge()
	var seen: Array[String] = []
	var out_of_view: Array[String] = []
	for id in [&"a", &"b"]:
		var y: float = _to_screen(_disc_edge(id, false)).y
		seen.append("disc %s y %.0f" % [id, y])
		if y < cb + CANOPY_CLEAR_PX:
			out_of_view.append("disc %s at y %.0f under the canopy edge %.0f" % [id, y, cb])
	for hut_id in ["h1", "h3"]:
		var y: float = _to_screen(_hut_apex(hut_id)).y
		seen.append("%s apex y %.0f" % [hut_id, y])
		if y < cb + CANOPY_CLEAR_PX:
			out_of_view.append("%s apex at y %.0f under the canopy edge %.0f" % [hut_id, y, cb])
	if vp.y >= 700.0:
		for id in [&"f", &"g"]:
			var yb: float = _to_screen(_disc_edge(id, true)).y
			seen.append("disc %s bottom y %.0f" % [id, yb])
			if yb > vp.y:
				out_of_view.append("disc %s ends at y %.0f below the screen" % [id, yb])
	t.check("overview_keeps_the_top_platforms_in_view", out_of_view.is_empty(),
		"at the minimum zoom 0.2 (the whole composition of the sketch, view top %d px above the sketch) the discs and huts of the top platforms A and B lie below the canopy's lower edge (%.0f px), and F / G end inside the %.0f px screen: %s; problems %s" % [int(OVERVIEW_ABOVE_PX), cb, vp.y, seen, out_of_view])
	# --- the live citizens carry their own bubbles above their bodies (the M1a name plates are gone)
	var director := _current_director()
	t.check("scheduled_citizens_replace_preview_labels",director!=null and director.live.values().all(func(actor):return actor._bubble_label!=null and actor._bubble_label.position.y<0 and actor._bubble_label.get_parent()==actor),
		"live citizens own their quest/heart/candle bubbles above their bodies; names use the real interaction prompt")
	# --- the HUD shows prompts, whispers and toasts in the city
	await _hint_checks(t)
	# --- back to a clean city (the player was moved around; trigger circles and the tracker start fresh)
	p.camera.zoom = saved_zoom
	p.camera.position_smoothing_enabled = saved_smooth
	p.set_physics_process(saved_physics)
	p.global_position = saved_pos
	_world._enter(&"farm", &"default")
	await t.frames(2)
	await _enter_city(t)


func _hint_checks(t) -> void:
	if _world.game_ui == null:
		t.check("hud_owns_prompts_whispers_and_toasts",false,"the production HUD does not exist")
		return
	var hud: Node = _world.game_ui.get_screen(&"hud")
	var prompt: PromptPill = hud.get_node("PromptPill")
	var whisper: WhisperLine = hud.get_node("WhisperLine")
	var climb := prompt.tr("LEVEL_PROMPT_CLIMB")
	EventBus.interaction_prompt_changed.emit(climb)
	var prompt_ok: bool = prompt.shown().visible and prompt.shown().cap!="" and prompt.shown().verb==climb
	EventBus.interaction_prompt_changed.emit("")
	prompt_ok=prompt_ok and not prompt.shown().visible
	_city.signs[0].interact(_world.player)
	var whisper_ok := whisper.is_showing() and whisper.shown_text()==whisper.tr("TRAE_SIGN_FARM")
	hud.toasts.clear()
	await t.frames(1)
	EventBus.notification_posted.emit("toast title","toast message","zone")
	await t.frames(2)
	var toasts: Array = hud.toasts.toasts()
	var toast_ok: bool = toasts.size()==1 and toasts[0].title_label.text=="toast title" and toasts[0].message_label.text=="toast message"
	t.check("hud_owns_prompts_whispers_and_toasts",prompt_ok and whisper_ok and toast_ok,
		"real HUD receives translated prompt/empty hide, the sign's whisper and notification title/message")
	hud.toasts.clear()
	whisper._hide()


# ================================================================== with a real marker handler (P14 / P19 present)

## The section as the marker handler of the checks (the technique of tests/sections/area.gd): create_marker(params, pos, cell, area).
static func create_marker(params: Dictionary, _pos: Vector2, _cell: Vector2i, _area_node: IsoArea) -> Node:
	made_markers.append(params.duplicate())
	var n: Node2D
	if str(params.get("marker", "")) == "npc":
		var body := CharacterBody2D.new()
		body.collision_layer = Iso.LAYER_NPC
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = 12.0
		cs.shape = sh
		body.add_child(cs)
		n = body
	else:
		n = Node2D.new()
	n.name = "Made_%s_%s" % [params.get("marker", "?"), params.get("id", params.get("kind", "?"))]
	return n


## The towns track's CityTown.attach(area, "traetoppen"), as the section's own static function (CityBuilder.town_script_path points here).
static func attach(area: IsoArea, id: String) -> void:
	attach_calls.append([area, id])


func _fake_handlers(t) -> void:
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("marker_handlers", {"npc": SELF_PATH, "node": SELF_PATH})
	IsoArea.clear_handler_cache()
	made_markers.clear()
	var mark: int = t.log_mark()
	var v: Dictionary = _fresh_area()
	var a: IsoArea = v["area"]
	var city: CityBuilder = v["city"]
	await t.physics(3)
	var errors: Array[String] = t.log_since(mark)
	var ids: Array[String] = []
	var kinds: Array[String] = []
	for m in made_markers:
		if str((m as Dictionary).get("marker", "")) == "npc":
			ids.append(str((m as Dictionary)["id"]))
		else:
			kinds.append(str((m as Dictionary).get("kind", "")))
	ids.sort()
	kinds.sort()
	var recorded: int = 0
	for rec in a.markers:
		if str(rec["type"]) in ["npc", "node"] and rec["node"] != null and (rec["node"] as Node).get_parent() == a.objects:
			recorded += 1
	t.check("npc_markers_use_the_real_handler", ids == ["appraiser_fru_ugle", "bathkeeper_sofus", "carpenter_brumme", "carpenter_brumme", "gardener_hoppe", "guard_oak", "postman_pip"] and recorded == 10 \
		and not a.skipped_markers.has("npc") and not a.skipped_markers.has("node") and int(a.skipped_markers.get("seed_basket", 0)) == 1 and errors.is_empty() and city.planters_drawn == 0,
		"with a fake `npc` / `node` handler registered (marker_handlers override, the technique of area.gd): the handler was called for the 7 npc markers %s and the 3 node kinds %s, all 10 nodes sit in Objects and in area.markers, skipped_markers %s, no decor planter is drawn (the node draws itself); engine messages %s" % [ids, kinds, a.skipped_markers, errors.slice(0, 2)])
	# --- the made bodies are levelled: by the tracker, or by the data where no level holds the position; a figure in a hole is above the decals and locked
	var z_by: Dictionary = {}
	var locked: Array[String] = []
	for rec in a.markers:
		if str(rec["type"]) == "npc" and rec["node"] != null:
			var key: String = "%s@%s" % [(rec["params"] as Dictionary)["id"], str((rec["params"] as Dictionary).get("when", ""))]
			z_by[key] = (rec["node"] as Node2D).z_index
			if ActorLevel.is_locked(rec["node"] as Node):
				locked.append(str((rec["params"] as Dictionary)["id"]))
	locked.sort()
	var want_z: Dictionary = {"gardener_hoppe@": 10, "postman_pip@": 20, "carpenter_brumme@flag:brumme_at_work": 70, "carpenter_brumme@flag:brumme_at_stall": 80, "bathkeeper_sofus@": 100, "appraiser_fru_ugle@": 176, "guard_oak@": 60}
	var node_z_ok: bool = true
	for rec in a.markers:
		if str(rec["type"]) == "node":
			node_z_ok = node_z_ok and (rec["node"] as Node2D).z_index == 160
	t.check("handler_made_nodes_are_levelled", z_by == want_z and locked == ["appraiser_fru_ugle"] and node_z_ok,
		"the nodes a real handler makes get their place in the draw order: bodies by the LevelTracker or, where the sketch draws the figure inside a keep-out (Hoppe at the trunk, Brumme at the logs, Sofus in the tub) and no level holds the position, by the data once (Hoppe 10, Pip 20, Oak 20, Brumme 70 / 80, Sofus 100; Oak draws at the adjacent B3 join rank 60 while keeping B collision), Fru Ugle in the trunk hole at 176 and locked, the three kitchen-garden nodes at G's rank 160: %s locked %s" % [z_by, locked])
	# --- `when=`: Brumme twice, the flags decide (the one private call, IsoArea._track_when)
	var work: Node2D = null
	var stall: Node2D = null
	for rec in a.markers:
		if str(rec["type"]) == "npc" and str((rec["params"] as Dictionary)["id"]) == "carpenter_brumme":
			if str((rec["params"] as Dictionary).get("when", "")) == "flag:brumme_at_work":
				work = rec["node"] as Node2D
			else:
				stall = rec["node"] as Node2D
	var follows: bool = work != null and stall != null and a.when_total_count() == 2 and a.has_method("_track_when")
	if follows:
		gm.set_flag(&"brumme_at_stall", 1)
		gm.set_flag(&"brumme_at_work", 0)
		a.refresh_when()
		follows = follows and stall.visible and not work.visible and a.when_active_count() == 1
		gm.set_flag(&"brumme_at_stall", 0)
		gm.set_flag(&"brumme_at_work", 1)
		a.refresh_when()
		follows = follows and work.visible and not stall.visible
		gm.clear_flag(&"brumme_at_stall")
		gm.clear_flag(&"brumme_at_work")
		a.refresh_when()
		follows = follows and not work.visible and not stall.visible
	t.check("when_markers_follow_flags", follows, "the two Brumme markers carry `when=flag:...`: IsoArea._track_when (the one private call, guarded by has_method) tracks both; brumme_at_stall = 1 shows only the stall one, brumme_at_work = 1 only the workshop one, no flag hides both (as evaluate_when answers)")
	v["host"].free()
	gm.clear_config_overrides()
	IsoArea.clear_handler_cache()
	made_markers.clear()


# ================================================================== the towns track's hook

func _town_attach(t) -> void:
	attach_calls.clear()
	CityBuilder.town_script_path = SELF_PATH
	var v: Dictionary = _fresh_area()
	var called: bool = attach_calls.size() == 1 and attach_calls[0][0] == v["area"] and attach_calls[0][1] == "traetoppen" and (v["city"] as CityBuilder).town_attached
	v["host"].free()
	CityBuilder.town_script_path = CityBuilder.TOWN_SCRIPT
	attach_calls.clear()
	var mark: int = t.log_mark()
	var v2: Dictionary = _fresh_area()
	var quiet: bool = attach_calls.is_empty() and (v2["area"] as IsoArea).builder_error == "" and t.log_since(mark).is_empty() and (v2["city"] as CityBuilder).town_attached == ResourceLoader.exists(CityBuilder.TOWN_SCRIPT)
	v2["host"].free()
	t.check("town_attach_called", called and quiet and CityBuilder.TOWN_SCRIPT == "res://scripts/towns/city_town.gd",
		"after the build CityBuilder calls Svc.static_call(\"%s\", &\"attach\", [area, \"traetoppen\"]): with the path pointed at a script that has a static attach the call arrives once with this area and the id (%s); with the shipped path (T-director's CityTown %s) nothing is called and nothing breaks (quiet %s)" % [CityBuilder.TOWN_SCRIPT, called, "exists" if ResourceLoader.exists(CityBuilder.TOWN_SCRIPT) else "does not exist yet", quiet])


# ================================================================== landmarks

func _landmark_point(lm: Dictionary, circle_only: bool = true) -> Vector2:
	## the walkable point of the landmark's level nearest to the circle's centre (searched on a 24 px grid inside the circle)
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	var c: Vector2 = lm["centre"]
	var r: float = lm["r"] if circle_only else lm["r"] * 2.0
	var x: float = c.x - r
	while x <= c.x + r:
		var y: float = c.y - r
		while y <= c.y + r:
			var p := Vector2(x, y)
			var d: float = p.distance_to(c)
			if d <= r and d < best_d and _reg.level_id_at(p) == lm["level"]:
				best = p
				best_d = d
			y += 24.0
		x += 24.0
	return best


func _landmarks(t) -> void:
	var stage: LevelStage = _city.stage
	# --- reachability: flood fill over the level graph from the default spawn, and open floor inside every circle
	var graph: Dictionary = _reg.levels_graph()
	var adj: Dictionary = {}
	var link: Callable = func(from_id: StringName, to_id: StringName) -> void:
		if not adj.has(from_id):
			adj[from_id] = []
		if not adj.has(to_id):
			adj[to_id] = []
		(adj[from_id] as Array).append(to_id)
		(adj[to_id] as Array).append(from_id)
	for b in graph["bridges"]:
		link.call(b["from"], b["id"])
		link.call(b["id"], b["to"])
	for l in graph["ladders"]:
		link.call(l["from"], l["to"])
	var start: StringName = _reg.level_id_at(_area.spawns["default"])
	var reached: Dictionary = {start: true}
	var queue: Array[StringName] = [start]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		for nb in (adj.get(cur, []) as Array):
			if not reached.has(nb):
				reached[nb] = true
				queue.append(nb)
	var unreached: Array[String] = []
	for lv in _reg.levels:
		if not reached.has(lv.id):
			unreached.append(String(lv.id))
	var lm_bad: Array[String] = []
	for lm in _reg.landmarks:
		var pt: Vector2 = _landmark_point(lm)
		if not reached.has(lm["level"]) or pt == Vector2.INF:
			lm_bad.append("%s (%s)" % [lm["id"], lm["level"]])
	for sp in _area.spawns:
		if not reached.has(_reg.level_id_at(_area.spawns[sp])):
			lm_bad.append("spawn %s" % sp)
	# every standing npc is reached: open floor of its level within talking range; Fru Ugle from bridge B2 within her reach
	var npc_bad: Array[String] = []
	for m in CityData.markers_of(_data, "npc"):
		var lvl: StringName = StringName(str(m["level"]))
		var found: bool = false
		var pos: Vector2 = m["at"]
		if bool(m["window"]):
			var b2: Level = _reg.get_level(&"b2")
			for i in 41:
				var sample: Vector2 = b2.gate_path[0].lerp(b2.gate_path[b2.gate_path.size() - 1], float(i) / 40.0)
				if _reg.level_id_at(sample) == &"b2" and sample.distance_to(pos) <= float(m["reach"]):
					found = true
					break
		else:
			var q: Vector2 = pos
			for dx in range(-120, 121, 24):
				for dy in range(-120, 121, 24):
					var p2: Vector2 = q + Vector2(dx, dy)
					if p2.distance_to(q) <= 120.0 and _reg.level_id_at(p2) == lvl and reached.has(lvl):
						found = true
		if not found:
			npc_bad.append("%s on %s" % [m["id"], lvl])
	t.check("landmarks_reachable_flood_fill", unreached.is_empty() and lm_bad.is_empty() and npc_bad.is_empty() and reached.size() == 17,
		"a flood fill over the level graph (the 9 bridges and the ladder join the 8 platforms) from the default spawn reaches all %d levels (unreached %s); every one of the 10 landmark circles holds open floor of its level (problems %s); every spawn and every npc stands within talking range of walkable floor of its level, Fru Ugle within her reach of 420 from bridge B2 (problems %s)" % [reached.size(), unreached, lm_bad, npc_bad])
	# --- the circles lie where the sketch's own subjects are (within 3 percent of the sketch's width)
	var tol: float = 0.03 * CityData.SKETCH_SIZE.x
	var off: Array[String] = []
	var anchors: Dictionary = {}
	for n in LANDMARK_ANCHORS:
		var spec: Array = LANDMARK_ANCHORS[n]
		var anchor: Vector2 = Vector2.INF
		match str(spec[0]):
			"platform":
				var pl: Dictionary = (_extract["platforms"] as Array)[int(spec[1])]
				anchor = Vector2(float(pl["cx"]), float(pl["cy"]))
			"building":
				var bd: Dictionary = CityData.record(_data, "buildings", str(spec[1]))
				anchor = Vector2(LuaData.num(bd["cx"]), LuaData.num(bd["base_y"]))
			"hut":
				var hd: Dictionary = (_extract["huts"] as Array)[int(spec[1])]
				anchor = Vector2(float(hd["cx"]), float(hd["base_y"]))
			"prop":
				var pr: Dictionary = CityData.record(_data, "props", str(spec[1]))
				anchor = Vector2(float((pr["at"] as Array)[0]), float((pr["at"] as Array)[1]))
			"planter":
				var pt: Array = (_extract["planters"] as Array)[int(spec[1])]
				anchor = Vector2(float(pt[0]), float(pt[1]))
			"bridge":
				var br: Dictionary = (_extract["bridges"] as Array)[int(spec[1])]
				anchor = (Vector2(float((br["start"] as Array)[0]), float((br["start"] as Array)[1])) + Vector2(float((br["end"] as Array)[0]), float((br["end"] as Array)[1]))) * 0.5
			"owl":
				var oh: Array = (_extract["owl_holes"] as Array)[int(spec[1])]
				anchor = Vector2(float(oh[0]), float(oh[1]))
			"bat":
				var bh: Dictionary = (_extract["bat_houses"] as Array)[int(spec[1])]
				anchor = Vector2(float(bh["cx"]), (float(bh["y_top"]) + float(bh["tip_y"])) * 0.5)
		anchors[n] = anchor
	for rec in LuaData.arr(_data.get("landmarks", [])):
		var lm: Dictionary = rec
		var n: int = LuaData.int_of(lm["n"])
		var c: Array = lm["circle"]
		var centre := Vector2(LuaData.num(c[0]), LuaData.num(c[1]))
		var d: float = centre.distance_to(anchors.get(n, Vector2.INF))
		if d > LuaData.num(c[2]) + tol:
			off.append("%d %s: %.0f px from its subject, radius %.0f" % [n, lm["id"], d, LuaData.num(c[2])])
	var built_off: Array[String] = []
	for i in stage.registry.landmarks.size():
		var lmk: Dictionary = stage.registry.landmarks[i]
		var trig: CityBuilder.LandmarkTrigger = _city.landmarks[i]
		if trig.position.distance_to(lmk["centre"]) > 1.0 or not is_equal_approx(trig.radius, float(lmk["r"])) or trig.name_key != str(lmk["name_key"]):
			built_off.append(String(lmk["id"]))
	t.check("landmark_positions_within_3_percent_of_sketch", off.is_empty() and built_off.is_empty() and anchors.size() == 10 and _city.landmarks.size() == 10,
		"each of the ten circles holds the sketch's own subject (the Torvet platform, the Raadhus, the huts H3 / H1 / H5, the tub, the middle kitchen bed, bridge B8's middle, the first owl hole, the first bat house) or lies within 3 percent of the sketch's width (%.0f px) of it: off %s; the %d built trigger nodes sit at the data's centres with its radii and name keys: off %s" % [tol, off, _city.landmarks.size(), built_off])
	# --- the events: one per landmark and visit, only from the landmark's own level. A visit starts at the farm bridge's arrival (no circle there).
	var cb: Callable = _record_events()
	await _enter_city(t, &"from_farm")
	var p: Node2D = _world.player
	p.set_physics_process(false)
	await t.physics(4)
	var quiet_arrival: bool = _events_named(&"landmark_entered").is_empty() and ActorLevel.level_id(p) == &"g"
	# the Raadhus circle reaches over the Torvet's open floor: a walker THERE is not at the Raadhus
	var raad: Dictionary = {}
	for lm in _reg.landmarks:
		if lm["id"] == &"raadhuset":
			raad = lm
	var below: Vector2 = Vector2.INF
	var x: float = raad["centre"].x - raad["r"]
	while x <= raad["centre"].x + raad["r"] and below == Vector2.INF:
		var y: float = raad["centre"].y
		while y <= raad["centre"].y + raad["r"]:
			var cand := Vector2(x, y)
			if cand.distance_to(raad["centre"]) <= raad["r"] and _reg.level_id_at(cand) == &"torvet":
				below = cand
				break
			y += 24.0
		x += 24.0
	p.global_position = below
	ActorLevel.set_level(p,_reg.get_level(&"torvet"))
	await t.physics(4)
	var on_torvet: Array = _events_named(&"landmark_entered")
	var gated: bool = below != Vector2.INF and ActorLevel.level_id(p) == &"torvet" and on_torvet.size() == 1 and str((on_torvet[0] as Dictionary)["id"]) == "torvet"
	var order: Array[String] = []
	for lm in _reg.landmarks:
		var pt2: Vector2 = _landmark_point(lm)
		p.global_position = pt2
		# A teleport does not traverse the connecting bridge/ladder. Select its
		# authored floor explicitly; the separate tour proves real traversal.
		ActorLevel.set_level(p,_reg.get_level(StringName(lm["level"])))
		await t.physics(4)
		order.append("%s:%s" % [lm["id"], ActorLevel.level_id(p)])
	var got: Array = _events_named(&"landmark_entered")
	var got_ids: Array[String] = []
	var payload_ok: bool = true
	for e in got:
		got_ids.append(str((e as Dictionary)["id"]))
		payload_ok = payload_ok and (e as Dictionary).keys().size() == 2 and str((e as Dictionary)["name_key"]).begins_with("TRAE_LANDMARK_")
	var want_ids: Array[String] = []
	for lm in _reg.landmarks:
		want_ids.append(String(lm["id"]))
	got_ids.sort()
	want_ids.sort()
	# again: no second event in the same visit
	var first_count: int = got.size()
	p.global_position = _landmark_point(_reg.landmarks[0])
	ActorLevel.set_level(p,_reg.get_level(StringName(_reg.landmarks[0]["level"])))
	await t.physics(4)
	var again: int = _events_named(&"landmark_entered").size()
	# a new visit (the area is built again) fires it once more
	EventBus.game_event.disconnect(cb)
	var cb2: Callable = _record_events()
	await _enter_city(t, &"from_farm")
	p.set_physics_process(false)
	p.global_position = _landmark_point(_reg.landmarks[3])
	ActorLevel.set_level(p,_reg.get_level(StringName(_reg.landmarks[3]["level"])))
	await t.physics(4)
	var next_visit: Array = _events_named(&"landmark_entered")
	EventBus.game_event.disconnect(cb2)
	t.check("landmark_enter_events", quiet_arrival and gated and got_ids == want_ids and payload_ok and first_count == 10 and again == 10 and next_visit.size() == 1 and str((next_visit[0] as Dictionary)["id"]) == "hoppes_hytte" and order.size() == 10,
		"game_event(landmark_entered, {id, name_key}) fires once per landmark and visit and only for a walker on the landmark's own level: the arrival at the farm bridge fires nothing (%s); a walker on the Torvet inside the Raadhus circle fires the Torvet's event and not the Raadhus's (%s); walking into the ten circles in turn gives each of them exactly once %s (payload id + name_key only: %s); a second look at the Torvet gives no new event (%d of 10); after the area is built again (a new visit) the same landmark fires again (%s)" % [quiet_arrival, gated, got_ids, payload_ok, again, next_visit])
	p.set_physics_process(true)


# ================================================================== the walk: a grid planner per level, the real player steered by input

## Plans inside ONE level: a grid of 12 px cells over the level's own bounds (built when the level is first asked for) whose centre and four clearance
## samples (the body's half extents plus a margin) all lie on that level; 8-neighbour A* with no corner cutting. 12 px is what the Upper deck's
## 36 px crescent in front of the trunk needs. Level changes are NOT planned here: they are the explicit crossings of the tour (a bridge's centre
## line, the ladder).
class Planner:
	var reg: LevelRegistry
	var cell: float = 12.0
	var grids: Dictionary = {}
	const CLEAR: Array[Vector2] = [Vector2(28, 0), Vector2(-28, 0), Vector2(0, 16), Vector2(0, -16)]

	func _init(r: LevelRegistry, c: float = 12.0) -> void:
		reg = r
		cell = c

	func _grid(level: StringName) -> Dictionary:
		if grids.has(level):
			return grids[level]
		var lv: Level = reg.get_level(level)
		var rect: Rect2 = lv.bounds.grow(60.0)
		var cols: int = int(ceil(rect.size.x / cell))
		var rows: int = int(ceil(rect.size.y / cell))
		var ok: PackedByteArray = PackedByteArray()
		ok.resize(cols * rows)
		for iy in rows:
			for ix in cols:
				var p: Vector2 = rect.position + Vector2((float(ix) + 0.5) * cell, (float(iy) + 0.5) * cell)
				if reg.level_id_at(p) != level:
					continue
				var good: bool = true
				for off in CLEAR:
					if reg.level_id_at(p + off) != level:
						good = false
						break
				if good:
					ok[iy * cols + ix] = 1
		var g: Dictionary = {"origin": rect.position, "cols": cols, "rows": rows, "ok": ok}
		grids[level] = g
		return g

	func center(g: Dictionary, i: int) -> Vector2:
		var cols: int = g["cols"]
		return (g["origin"] as Vector2) + Vector2((float(i % cols) + 0.5) * cell, (float(floori(float(i) / float(cols))) + 0.5) * cell)

	func nearest(g: Dictionary, p: Vector2) -> int:
		var ok: PackedByteArray = g["ok"]
		var best: int = -1
		var best_d: float = INF
		for i in ok.size():
			if ok[i] == 1:
				var d: float = center(g, i).distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = i
		return best

	## Waypoints (world px) from the cell nearest to `a` to the cell nearest to `b` among the cells the start can REACH (Dijkstra over the whole level
	## from the start; a crescent that is cut off by a keep-out is simply not an answer); empty when nothing is reachable.
	func path(level: StringName, a: Vector2, b: Vector2) -> PackedVector2Array:
		var g: Dictionary = _grid(level)
		var cols: int = g["cols"]
		var rows: int = g["rows"]
		var ok: PackedByteArray = g["ok"]
		var s: int = nearest(g, a)
		var out := PackedVector2Array()
		if s < 0:
			return out
		var cost: PackedFloat32Array = PackedFloat32Array()
		cost.resize(ok.size())
		cost.fill(INF)
		var came: PackedInt32Array = PackedInt32Array()
		came.resize(ok.size())
		came.fill(-1)
		var heap_f: Array[float] = []
		var heap_i: Array[int] = []
		cost[s] = 0.0
		_push(heap_f, heap_i, 0.0, s)
		var closed: Dictionary = {}
		var goal: int = s
		var goal_d: float = INF
		while not heap_i.is_empty():
			var cur: int = _pop(heap_f, heap_i)
			if closed.has(cur):
				continue
			closed[cur] = true
			var d: float = center(g, cur).distance_squared_to(b)
			if d < goal_d:
				goal_d = d
				goal = cur
			var cx: int = cur % cols
			var cy: int = floori(float(cur) / float(cols))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx: int = cx + dx
					var ny: int = cy + dy
					if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
						continue
					var ni: int = ny * cols + nx
					if ok[ni] != 1:
						continue
					if dx != 0 and dy != 0 and (ok[cy * cols + nx] != 1 or ok[ny * cols + cx] != 1):
						continue
					var c2: float = cost[cur] + (1.41421 if dx != 0 and dy != 0 else 1.0)
					if c2 < cost[ni]:
						cost[ni] = c2
						came[ni] = cur
						_push(heap_f, heap_i, c2, ni)
		var chain: Array[int] = []
		var n: int = goal
		while n != -1:
			chain.append(n)
			n = came[n]
		chain.reverse()
		# drop the points that lie on a straight run (the same step as the one before)
		var last_step: Vector2i = Vector2i.ZERO
		for i in chain.size():
			var step: Vector2i = Vector2i(chain[i] % cols - chain[i - 1] % cols, floori(float(chain[i]) / float(cols)) - floori(float(chain[i - 1]) / float(cols))) if i > 0 else Vector2i.ZERO
			if i == 0 or i == chain.size() - 1 or step != last_step:
				out.append(center(g, chain[i]))
			last_step = step
		return out

	func _push(hf: Array[float], hi: Array[int], f: float, i: int) -> void:
		hf.append(f)
		hi.append(i)
		var k: int = hf.size() - 1
		while k > 0:
			var parent: int = (k - 1) >> 1
			if hf[parent] <= hf[k]:
				break
			var tf: float = hf[parent]
			hf[parent] = hf[k]
			hf[k] = tf
			var ti: int = hi[parent]
			hi[parent] = hi[k]
			hi[k] = ti
			k = parent

	func _pop(hf: Array[float], hi: Array[int]) -> int:
		var top: int = hi[0]
		var last_f: float = hf.pop_back()
		var last_i: int = hi.pop_back()
		if not hf.is_empty():
			hf[0] = last_f
			hi[0] = last_i
			var k: int = 0
			while true:
				var l: int = 2 * k + 1
				var r: int = l + 1
				var m: int = k
				if l < hf.size() and hf[l] < hf[m]:
					m = l
				if r < hf.size() and hf[r] < hf[m]:
					m = r
				if m == k:
					break
				var tf: float = hf[m]
				hf[m] = hf[k]
				hf[k] = tf
				var ti: int = hi[m]
				hi[m] = hi[k]
				hi[k] = ti
				k = m
		return top


func _press(t, dir: Vector2) -> void:
	var table: Array = [[&"move_right", maxf(dir.x, 0.0)], [&"move_left", maxf(-dir.x, 0.0)], [&"move_back", maxf(dir.y, 0.0)], [&"move_forward", maxf(-dir.y, 0.0)]]
	for e in table:
		if float(e[1]) > 0.02:
			t.hold(e[0], float(e[1]))
		else:
			t.release(e[0])


func _release_moves(t) -> void:
	for a in [&"move_right", &"move_left", &"move_back", &"move_forward", &"run"]:
		t.release(a)


## Walks the REAL player along waypoints (world px) by holding the move actions (screen-relative, as a hand on the keys) until the last one is reached,
## `stop_when` is true, or no progress is made (stuck). Returns {ok, frames, stuck_at}.
func _steer(t, pts: PackedVector2Array, stop_when: Callable = Callable(), tol: float = 22.0, max_frames: int = 4000) -> Dictionary:
	var p: Node2D = _world.player
	var idx: int = 0
	var frames: int = 0
	var last_pos: Vector2 = p.global_position
	var still: int = 0
	var ok: bool = false
	var stuck_at: Vector2 = Vector2.INF
	t.hold(&"run")
	while frames < max_frames:
		await t.tree.physics_frame
		frames += 1
		if stop_when.is_valid() and bool(stop_when.call()):
			ok = true
			break
		while idx < pts.size() and Iso.to_ground(pts[idx] - p.global_position).length() <= tol:
			idx += 1
		if idx >= pts.size():
			ok = true
			break
		_press(t, Iso.to_ground(pts[idx] - p.global_position).normalized())
		if frames % 40 == 0:
			if p.global_position.distance_to(last_pos) < 5.0:
				still += 1
				if still >= 2:
					stuck_at = p.global_position
					break
			else:
				still = 0
			last_pos = p.global_position
	_release_moves(t)
	await t.tree.physics_frame
	return {"ok": ok, "frames": frames, "stuck_at": stuck_at}


## The centre line of a bridge as waypoints, oriented from `from_id`, and 70 px past its far end (onto the next platform's floor).
func _bridge_pts(b: Level, from_id: StringName) -> PackedVector2Array:
	var pts := PackedVector2Array(b.path)
	if b.from_id != from_id:
		pts.reverse()
	var dir: Vector2 = (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	pts.append(pts[pts.size() - 1] + dir * 70.0)
	return pts


## One tour: the real player from where it stands over every bridge and the ladder to the end of tree F's stub (the warp to Hyggebyen). `on_visit` is called
## after each landmark with (landmark id, level id); returns {ok, legs: [...], problems: [...]}.
func _tour(t, on_visit: Callable = Callable()) -> Dictionary:
	var planner := Planner.new(_reg)
	var p: Node2D = _world.player
	var problems: Array[String] = []
	var legs: Array[String] = []
	var levels_seen: Dictionary = {}
	var spec: Array = [
		["visit", "g", "koekkenhaverne"], ["cross", "b8", "g"], ["cross", "b6", "f"], ["visit", "torvet", "torvet"], ["climb", "torvet"], ["visit", "upper", "raadhuset"],
		["cross", "b1", "upper"], ["visit", "b", "postkontoret"], ["cross", "b3", "b"], ["visit", "e", "badehuset"], ["visit", "e", "flagermusenes_huse"], ["cross", "b5", "e"],
		["cross", "b4", "torvet"], ["visit", "c", "brummes_vaerksted"], ["cross", "b2", "c"], ["visit", "a", "hoppes_hytte"], ["cross", "b0", "a"], ["climb", "upper"],
		["cross", "b7", "torvet"], ["cross", "b8", "g"], ["stub", "f"],
	]
	for leg in spec:
		var kind: String = str(leg[0])
		var label: String = "%s %s" % [kind, leg[1]]
		var level_before: StringName = ActorLevel.level_id(p)
		var res: Dictionary = {"ok": true, "frames": 0, "stuck_at": Vector2.INF}
		match kind:
			"visit":
				if level_before != StringName(str(leg[1])):
					problems.append("%s: the player is on %s" % [label, level_before])
					break
				var lm: Dictionary = {}
				for l in _reg.landmarks:
					if String(l["id"]) == str(leg[2]):
						lm = l
				var target: Vector2 = _landmark_point(lm)
				var pts: PackedVector2Array = planner.path(StringName(str(leg[1])), p.global_position, target)
				if pts.is_empty():
					problems.append("%s: no path" % label)
					break
				var trigger: CityBuilder.LandmarkTrigger = null
				for tr in _city.landmarks:
					if String(tr.landmark_id) == str(leg[2]):
						trigger = tr
				res = await _steer(t, pts, func() -> bool: return trigger != null and trigger.entered)
				label = "visit %s (%s)" % [leg[2], leg[1]]
				if on_visit.is_valid():
					await on_visit.call(str(leg[2]), ActorLevel.level_id(p))
				levels_seen[ActorLevel.level_id(p)] = true
			"cross":
				var b: Level = _reg.get_level(StringName(str(leg[1])))
				var from_id: StringName = StringName(str(leg[2]))
				if level_before != from_id:
					problems.append("%s: the player is on %s, not on %s" % [label, level_before, from_id])
					break
				var bp: PackedVector2Array = _bridge_pts(b, from_id)
				var to_id: StringName = b.to_id if b.from_id == from_id else b.from_id
				var approach: PackedVector2Array = planner.path(from_id, p.global_position, bp[0])
				if approach.is_empty():
					problems.append("%s: no way to the bridge end" % label)
					break
				res = await _steer(t, approach)
				if res["ok"]:
					res = await _steer(t, bp, func() -> bool: return ActorLevel.level_id(p) == to_id and p.global_position.distance_to(bp[bp.size() - 1]) < 220.0)
				levels_seen[b.id] = true
				levels_seen[to_id] = true
				label = "cross %s %s -> %s" % [b.id, from_id, to_id]
				if ActorLevel.level_id(p) != to_id:
					res["ok"] = false
			"climb":
				var lane: ClimbLane = null
				for c in _city.stage.lanes:
					if not c.perk_only and c.from_id == StringName(str(leg[1])):
						lane = c
				if lane == null or level_before != lane.from_id:
					problems.append("%s: no lane for %s" % [label, level_before])
					break
				var stand: Vector2 = lane.start_pos + Vector2(0, 48)
				var approach2: PackedVector2Array = planner.path(lane.from_id, p.global_position, stand)
				res = await _steer(t, approach2)
				# the real E: face the lane (north), then interact; nudge towards the lane end until the player's own query finds it
				var tries: int = 0
				while tries < 80 and p.call("nearest_interactable") != lane:
					await _steer(t, PackedVector2Array([lane.start_pos]), Callable(), 22.0, 3)
					tries += 1
				t.hold(&"move_forward")
				await t.tree.physics_frame
				await t.tree.physics_frame
				t.release(&"move_forward")
				t.tap(&"interact")
				var started: bool = await t.until(func() -> bool: return lane.climbing, 2.0)
				var done: bool = await t.until(func() -> bool: return not lane.climbing and ActorLevel.level_id(p) == lane.to_id, 6.0)
				await t.physics(3)
				label = "climb %s -> %s (E at the foot, %.1f s)" % [lane.from_id, lane.to_id, lane.last_duration]
				levels_seen[lane.from_id] = true
				levels_seen[lane.to_id] = true
				res["ok"] = started and done and ActorLevel.level_id(p) == lane.to_id
			"stub":
				var stub: Dictionary = _reg.get_stub(&"hyggebyen_stub")
				var sp: PackedVector2Array = stub["path"]
				var approach3: PackedVector2Array = planner.path(&"f", p.global_position, sp[0])
				res = await _steer(t, approach3)
				if res["ok"]:
					var stub_pts := PackedVector2Array(sp)
					stub_pts.append(sp[sp.size() - 1] + (sp[sp.size() - 1] - sp[sp.size() - 2]).normalized() * 200.0)
					res = await _steer(t, stub_pts, func() -> bool: return _world.area.map.id != &"traetoppen" or _world.traveling)
				label = "stub %s to the warp" % stub["id"]
		legs.append("%s %s (%d frames, now on %s)" % ["ok" if res["ok"] else "STUCK", label, int(res["frames"]), ActorLevel.level_id(p)])
		if not res["ok"]:
			problems.append("%s: stuck at %s on %s" % [label, (res["stuck_at"] as Vector2).round(), ActorLevel.level_id(p)])
			break
	return {"ok": problems.is_empty(), "legs": legs, "problems": problems, "levels": levels_seen.keys()}


# ================================================================== warps, the zone, the Skovlift

## The warps of a registered grid map: [{to, spawn}] and its declared spawn names.
func _map_exits(id: StringName) -> Dictionary:
	var m: AreaMap = WorldRoot2D.load_map(id)
	var warps: Array = []
	var spawns: Array[String] = ["default"]
	if m != null:
		for ch in m.markers:
			var d: Dictionary = m.markers[ch]
			if str(d.get("marker", "")) == "warp":
				warps.append({"to": str(d.get("to", "")), "spawn": str(d.get("spawn", "default"))})
			elif str(d.get("marker", "")) == "spawn":
				spawns.append(str(d.get("name", "")))
	return {"warps": warps, "spawns": spawns}


func _warp_node(a: IsoArea, to: String) -> Warp2D:
	for rec in a.find_markers("warp"):
		if str((rec["params"] as Dictionary).get("to", "")) == to and rec["node"] != null:
			return rec["node"] as Warp2D
	for n in _all_nodes(a.triggers):
		if n is Warp2D and String((n as Warp2D).to_area) == to:
			return n as Warp2D
	return null


func _arrived(t, area_id: StringName, timeout: float = 10.0) -> bool:
	return await t.until(func() -> bool: return _world.area != null and _world.area.map.id == area_id and not _world.traveling, timeout)


func _warps_and_zone(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var city_spawns: Array = _area.spawns.keys()
	# --- the graph: every way out of the city lands on an arrival spawn that exists, and every target has a way back that lands on a spawn of the city
	var problems: Array[String] = []
	var ways: Array = [[&"farm", "from_traetoppen", "from_farm"], [&"hyggebyen", "from_traetoppen", "from_hyggebyen"], [&"moerkeskoven", "from_traetoppen", "from_skovlift"]]
	for w in ways:
		var exits: Dictionary = _map_exits(w[0])
		var back: bool = false
		for e in exits["warps"]:
			if str((e as Dictionary)["to"]) == "traetoppen":
				back = true
				if str((e as Dictionary)["spawn"]) != str(w[2]) or not city_spawns.has(str(w[2])):
					problems.append("%s -> traetoppen:%s is no spawn of the city" % [w[0], (e as Dictionary)["spawn"]])
		if not back:
			problems.append("%s has no warp to traetoppen" % w[0])
		if not (exits["spawns"] as Array).has(str(w[1])):
			problems.append("%s has no spawn %s for the way out of the city" % [w[0], w[1]])
	var city_exits: Array[String] = []
	for wp in _city.warps:
		city_exits.append("%s:%s" % [wp.to_area, wp.to_spawn])
	city_exits.sort()
	var lift: RopeLift = _city.stage.lifts[0]
	city_exits.append("%s:%s" % [lift.to_area, lift.spawn_name])
	t.check("warp_graph", problems.is_empty() and city_exits == ["farm:from_traetoppen", "hyggebyen:from_traetoppen", "moerkeskoven:from_traetoppen"] and not WorldRoot2D.area_ids(false).has(&"skovkant"),
		"zone graph of addendum 2.3: the city's bridge G -> farm:from_traetoppen, bridge F -> hyggebyen:from_traetoppen, the Skovlift -> moerkeskoven:from_traetoppen (%s); the farm, Hyggebyen and the hub each have ONE way into the city that lands on from_farm / from_hyggebyen / from_skovlift (problems %s)" % [city_exits, problems])
	# --- the two ends of a bridge stub: a diamond that covers the stub's width, at its end
	var stub_ok: bool = true
	var notes: Array[String] = []
	for wp in _city.warps:
		var stub_id: StringName = StringName(String(wp.name).trim_prefix("Warp_"))
		var st: Dictionary = _reg.get_stub(stub_id)
		var path: PackedVector2Array = st["path"]
		var end: Vector2 = path[path.size() - 1]
		var polygon: PackedVector2Array = (wp.get_child(0) as CollisionPolygon2D).polygon
		var half_w: float = 0.0
		var half_h: float = 0.0
		for pt in polygon:
			half_w = maxf(half_w, absf(pt.x))
			half_h = maxf(half_h, absf(pt.y))
		var covers: bool = half_h >= float(st["width"]) * 0.5 * 0.5 and wp.position.distance_to(end) < 1.0 and wp.collision_mask == Iso.LAYER_PLAYER
		stub_ok = stub_ok and covers and _reg.level_id_at(end - (end - path[0]).normalized() * 60.0) == st["level"]
		notes.append("%s at %s, diamond %.0f x %.0f" % [stub_id, wp.position.round(), half_w * 2.0, half_h * 2.0])
	t.check("stub_warps_sit_at_the_bridge_ends", stub_ok, "the warp of each stub is a Warp2D (player mask) at the END of the stub's centre line, wide enough for the whole stub: %s" % [notes])
	# --- real round trips: farm <-> city, Hyggebyen <-> city; no bounce (no spawn lies inside a warp diamond)
	var requests: Array = []
	var cb: Callable = func(area_id: StringName, spawn_name: StringName) -> void: requests.append([String(area_id), String(spawn_name)])
	EventBus.area_change_requested.connect(cb)
	var trips: Array[String] = []
	var trip_ok: bool = true
	var p: Node2D = _world.player
	# farm -> city: the player steps onto the farm's own warp
	_world._enter(&"farm", &"from_traetoppen")
	await t.physics(2)
	var farm_warp: Warp2D = _warp_node(_world.area, "traetoppen")
	requests.clear()
	p.global_position = farm_warp.global_position
	var in_city: bool = await _arrived(t, &"traetoppen")
	await t.seconds(0.6)
	var at_spawn: bool = in_city and p.global_position.distance_to(_world.area.get_spawn("from_farm")) < 6.0
	var fired: Array = requests.duplicate()
	requests.clear()
	await t.seconds(0.8)
	var no_bounce: bool = _world.area.map.id == &"traetoppen" and requests.is_empty() and not fired.is_empty() and fired[0] == ["traetoppen", "from_farm"]
	trips.append("farm -> traetoppen:from_farm arrived %s at the spawn %s, the warp asked for %s, no bounce after the arrival %s (%s)" % [in_city, at_spawn, fired[0] if not fired.is_empty() else "nothing", no_bounce, requests])
	trip_ok = trip_ok and in_city and at_spawn and no_bounce
	_area = _world.area
	_city = CityBuilder.of(_area)
	_reg = _city.registry
	# city -> farm: the player walks east along the stub of tree G for real and the warp at its end fires
	requests.clear()
	var stub_g: Dictionary = _reg.get_stub(&"farm_stub")
	var gp: PackedVector2Array = stub_g["path"]
	var walk_g := PackedVector2Array(gp)
	walk_g.append(gp[1] + (gp[1] - gp[0]).normalized() * 200.0)
	var res_g: Dictionary = await _steer(t, walk_g, func() -> bool: return _world.area.map.id != &"traetoppen" or _world.traveling)
	var on_farm: bool = await _arrived(t, &"farm")
	await t.seconds(0.6)
	var farm_ok: bool = on_farm and p.global_position.distance_to(_world.area.get_spawn("from_traetoppen")) < 6.0
	var fired_g: Array = requests.duplicate()
	requests.clear()
	await t.seconds(0.8)
	var farm_stays: bool = _world.area.map.id == &"farm" and requests.is_empty() and not fired_g.is_empty() and fired_g[0] == ["farm", "from_traetoppen"]
	trips.append("traetoppen (G, east stub, walked %d frames) -> farm:from_traetoppen arrived %s at the spawn %s, the warp asked for %s, no bounce %s (%s)" % [int(res_g["frames"]), on_farm, farm_ok, fired_g[0] if not fired_g.is_empty() else "nothing", farm_stays, requests])
	trip_ok = trip_ok and bool(res_g["ok"]) and farm_ok and farm_stays
	# Hyggebyen <-> city
	_world._enter(&"hyggebyen", &"from_traetoppen")
	await t.physics(2)
	var hyg_warp: Warp2D = _warp_node(_world.area, "traetoppen")
	requests.clear()
	p.global_position = hyg_warp.global_position
	var to_city: bool = await _arrived(t, &"traetoppen")
	await t.seconds(0.6)
	var hyg_spawn: bool = to_city and p.global_position.distance_to(_world.area.get_spawn("from_hyggebyen")) < 6.0
	var fired_h: Array = requests.duplicate()
	requests.clear()
	await t.seconds(0.8)
	var hyg_bounce: bool = _world.area.map.id == &"traetoppen" and requests.is_empty() and not fired_h.is_empty() and fired_h[0] == ["traetoppen", "from_hyggebyen"]
	trips.append("hyggebyen -> traetoppen:from_hyggebyen arrived %s at the spawn %s, the warp asked for %s, no bounce %s (%s)" % [to_city, hyg_spawn, fired_h[0] if not fired_h.is_empty() else "nothing", hyg_bounce, requests])
	trip_ok = trip_ok and to_city and hyg_spawn and hyg_bounce
	_area = _world.area
	_city = CityBuilder.of(_area)
	_reg = _city.registry
	requests.clear()
	var stub_f: Dictionary = _reg.get_stub(&"hyggebyen_stub")
	var fp: PackedVector2Array = stub_f["path"]
	var walk_f := PackedVector2Array(fp)
	walk_f.append(fp[1] + (fp[1] - fp[0]).normalized() * 200.0)
	var res_f: Dictionary = await _steer(t, walk_f, func() -> bool: return _world.area.map.id != &"traetoppen" or _world.traveling)
	var on_hyg: bool = await _arrived(t, &"hyggebyen")
	await t.seconds(0.6)
	var hyg_ok: bool = on_hyg and p.global_position.distance_to(_world.area.get_spawn("from_traetoppen")) < 6.0
	var fired_f: Array = requests.duplicate()
	requests.clear()
	await t.seconds(0.8)
	var hyg_stays: bool = _world.area.map.id == &"hyggebyen" and requests.is_empty() and not fired_f.is_empty() and fired_f[0] == ["hyggebyen", "from_traetoppen"]
	trips.append("traetoppen (F, west stub, walked %d frames) -> hyggebyen:from_traetoppen arrived %s at the spawn %s, the warp asked for %s, no bounce %s (%s)" % [int(res_f["frames"]), on_hyg, hyg_ok, fired_f[0] if not fired_f.is_empty() else "nothing", hyg_stays, requests])
	trip_ok = trip_ok and bool(res_f["ok"]) and hyg_ok and hyg_stays
	EventBus.area_change_requested.disconnect(cb)
	t.check("every_warp_round_trips", trip_ok, "the two bridge warps round-trip with P11's farm and Hyggebyen (the pending-area allowance of maps_iso / maps_farm is closed here): %s" % [trips])
	# --- the zone unlocks on the first arrival (a new game: only farm and city are open), once, with the toast
	t.new_game()
	await t.frames(2)
	var before: bool = bool(gm.call("is_zone_unlocked", &"traetoppen"))
	var unlocked: Array = []
	var entered: Array = []
	var toasts: Array = []
	var zcb: Callable = func(z: StringName) -> void: unlocked.append(String(z))
	var ecb: Callable = func(z: StringName) -> void: entered.append(String(z))
	var tcb: Callable = func(title: String, message: String, icon: String) -> void:
		if icon == "zone":
			toasts.append([title, message])
	EventBus.zone_unlocked.connect(zcb)
	EventBus.zone_entered.connect(ecb)
	EventBus.notification_posted.connect(tcb)
	_world._enter(&"farm", &"default")
	await t.physics(2)
	var mid_state: bool = bool(gm.call("is_zone_unlocked", &"traetoppen"))
	_world._enter(&"traetoppen", &"from_farm")
	await t.physics(2)
	var first_count: int = unlocked.size()
	var after: bool = bool(gm.call("is_zone_unlocked", &"traetoppen"))
	_world._enter(&"farm", &"default")
	_world._enter(&"traetoppen", &"from_farm")
	await t.physics(2)
	EventBus.zone_unlocked.disconnect(zcb)
	EventBus.zone_entered.disconnect(ecb)
	EventBus.notification_posted.disconnect(tcb)
	var want_msg: String = _world.tr("NOTIF_ZONE_UNLOCKED_MSG") % _world.tr("ZONE_TRAETOPPEN")
	t.check("zone_unlocks_on_first_arrival", not before and not mid_state and after and unlocked == ["traetoppen"] and first_count == 1 and entered.has("traetoppen") and toasts.size() == 1 and (toasts[0] as Array)[1] == want_msg and want_msg.contains("Trætoppen"),
		"a new game has only farm and city open; the farm does not unlock the city (%s); the first arrival does (before %s, after %s): zone_unlocked(traetoppen) once (%s; a second visit adds none), zone_entered %s, the toast `%s`" % [mid_state, before, after, unlocked, entered, want_msg])
	_area = _world.area
	_city = CityBuilder.of(_area)
	_reg = _city.registry


func _lift(t) -> void:
	var gm: Node = t.autoload("GameManager")
	await _enter_city(t, &"from_skovlift")
	var p: Node2D = _world.player
	var gate: CityBuilder.LiftGate = _city.lift_gate
	var lift: RopeLift = _city.stage.lifts[0]
	var whispers: Array = []
	var wcb: Callable = func(key: String) -> void: whispers.append(key)
	EventBus.whisper_requested.connect(wcb)
	var requests: Array = []
	var rcb: Callable = func(area_id: StringName, spawn_name: StringName) -> void: requests.append([String(area_id), String(spawn_name)])
	EventBus.area_change_requested.connect(rcb)
	# --- the forest is not registered: the defensive answer, nothing moves, the player stays visible
	gm.set_config_override("traetoppen.skovlift.to_area", "no_such_forest")
	gate.interact(p)
	await t.frames(2)
	var closed_ok: bool = whispers == ["TRAE_LIFT_CLOSED"] and not lift.riding and lift.rides == 0 and p.visible and requests.is_empty() and p.get("state") == 0
	var closed_text: String = _world.tr("TRAE_LIFT_CLOSED")
	gm.clear_config_overrides()
	whispers.clear()
	# --- the unlock day (adventure.dark_forest_unlock_day, read like the old warp's req_day)
	gm.set_config_override("adventure.dark_forest_unlock_day", 99)
	gate.interact(p)
	await t.frames(2)
	var locked_ok: bool = whispers == ["TRAE_LIFT_LOCKED"] and not lift.riding and lift.rides == 0 and p.visible and requests.is_empty()
	gm.clear_config_overrides()
	whispers.clear()
	t.check("skovlift_closed_whisper_when_no_forest", closed_ok and locked_ok and closed_text != "TRAE_LIFT_CLOSED" and _world.tr("TRAE_LIFT_LOCKED") != "TRAE_LIFT_LOCKED",
		"E at the Skovlift while the forest hub is not registered whispers TRAE_LIFT_CLOSED (`%s`) and nothing moves, the player stays visible and free (%s); before adventure.dark_forest_unlock_day it whispers TRAE_LIFT_LOCKED and nothing moves (%s)" % [closed_text, closed_ok, locked_ok])
	# --- the ride: 1.6 s, the player hidden, the hub, its ONE gate back to the rim of tree B beside Oak
	var events: Callable = _record_events()
	requests.clear()
	gate.interact(p)
	await t.frames(2)
	var hidden: bool = lift.riding and not p.visible and int(p.get("state")) == 1
	var in_hub: bool = await _arrived(t, &"moerkeskoven", 10.0)
	await t.seconds(0.6)
	var ride_events: Array = _events_named(&"lift_ride")
	var hub_spawn: bool = in_hub and p.global_position.distance_to(_world.area.get_spawn("from_traetoppen")) < 6.0 and p.visible and int(p.get("state")) == 0
	var hub_zone: bool = _world.current_zone() == &"dark_forest" and not _world.area.map.flight_allowed
	var ride_ok: bool = in_hub and hub_spawn and not requests.is_empty() and requests[0] == ["moerkeskoven", "from_traetoppen"] and ride_events.size() == 1 and str((ride_events[0] as Dictionary)["to_area"]) == "moerkeskoven" and hub_zone
	requests.clear()
	var gate_warp: Warp2D = _warp_node(_world.area, "traetoppen")
	p.global_position = gate_warp.global_position
	var back: bool = await _arrived(t, &"traetoppen", 10.0)
	await t.seconds(0.6)
	var back_spawn: bool = back and p.global_position.distance_to(_world.area.get_spawn("from_skovlift")) < 6.0
	await t.physics(3)
	var gate_asked: Array = requests.duplicate()
	requests.clear()
	await t.seconds(0.8)
	_area = _world.area
	_city = CityBuilder.of(_area)
	_reg = _city.registry
	var oak: Dictionary = (CityData.markers_of(_data, "npc").filter(func(m: Dictionary) -> bool: return str(m["id"]) == "guard_oak"))[0]
	var beside_oak: bool = p.global_position.distance_to(oak["at"] as Vector2) <= 60.0 * _k and ActorLevel.level_id(p) == &"b"
	var no_bounce: bool = _world.area.map.id == &"traetoppen" and requests.is_empty() and not gate_asked.is_empty() and gate_asked[0] == ["traetoppen", "from_skovlift"]
	EventBus.game_event.disconnect(events)
	EventBus.whisper_requested.disconnect(wcb)
	EventBus.area_change_requested.disconnect(rcb)
	t.check("skovlift_ride_to_the_hub_and_back", hidden and ride_ok and back_spawn and beside_oak and no_bounce,
		"E at the Skovlift (the gate, then V3's RopeLift): the player rides hidden (%s), the world switches to the hub `moerkeskoven` at its spawn from_traetoppen (arrived %s, spawn %s, visible and free again, zone dark_forest, flight off), lift_ride fired once with to_area moerkeskoven (%s); the hub's ONE gate leads back to traetoppen:from_skovlift: arrived %s at the spawn %s, level b, %.0f px from guard Oak, no bounce %s" % [hidden, in_hub, hub_spawn, ride_events, back, back_spawn, p.global_position.distance_to(oak["at"] as Vector2), no_bounce])


# ================================================================== the whole city on foot

func _walk(t) -> void:
	await _enter_city(t, &"from_farm")
	var p: Node2D = _world.player
	var cb: Callable = _record_events()
	var old_scale: float = Engine.time_scale
	if not _t.has_window():
		Engine.time_scale = 2.0
	var t0: int = Time.get_ticks_msec()
	var report: Dictionary = await _tour(t)
	Engine.time_scale = old_scale
	var took: float = float(Time.get_ticks_msec() - t0) / 1000.0
	EventBus.game_event.disconnect(cb)
	var lm_ids: Array[String] = []
	for e in _events_named(&"landmark_entered"):
		lm_ids.append(str((e as Dictionary)["id"]))
	lm_ids.sort()
	var want_ids: Array[String] = []
	for lm in _reg.landmarks:
		want_ids.append(String(lm["id"]))
	want_ids.sort()
	var climbs: Array = _events_named(&"ladder_climbed")
	var dirs: Array[String] = []
	for c in climbs:
		dirs.append("%s>%s" % [(c as Dictionary)["from"], (c as Dictionary)["to"]])
	var arrived: bool = await _arrived(t, &"hyggebyen", 10.0)
	await t.seconds(0.5)
	var levels: Array = report["levels"]
	var all_levels: bool = true
	for lv in _reg.levels:
		all_levels = all_levels and levels.has(lv.id)
	t.check("every_level_reachable_with_the_stub_player", bool(report["ok"]) and lm_ids == want_ids and dirs == ["torvet>upper", "upper>torvet"] and all_levels and arrived and p.visible,
		"the built stub player WALKS the whole city on real input (screen-relative, run held): from the farm bridge's arrival over G, B8, F, B6, the Torvet, the ladder up, the Upper deck, B1, B, B3, E, B5, the Torvet, B4, C, B2, A, B0, the ladder down, B7, G, B8 and F to the end of the Hyggebyen stub, where the warp fires and Hyggebyen opens (arrived %s) - %.1f s of wall time, no stuck point; levels crossed %d of 17, landmarks entered %s, ladder %s: %s problems %s" % [arrived, took, levels.size(), lm_ids == want_ids, dirs, report["legs"], report["problems"]])
	for line in report["legs"]:
		t.info(str(line))
	_area = _world.area
	_city = CityBuilder.of(_area)
	_reg = _city.registry if _city != null else null


# ================================================================== save and continue inside the city

func _save_roundtrip(t) -> void:
	await _enter_city(t)
	var sm: Node = t.autoload("SaveManager")
	var p: Node2D = _world.player
	var b3: Level = _reg.get_level(&"b3")
	var on_bridge: Vector2 = (b3.gate_path[0] + b3.gate_path[b3.gate_path.size() - 1]) * 0.5
	p.global_position = on_bridge
	await t.physics(4)
	var d: Dictionary = _world.to_dict()
	var wire: Dictionary = JSON.parse_string(JSON.stringify(d))
	var keys_ok: bool = d["area"] == "traetoppen" and (d["player_pos"] as Array).size() == 2 and not d.has("level") and not d.has("levels") and absf(float((d["player_pos"] as Array)[0]) - on_bridge.x) < 1.0
	# Continue: the world scene is built again from SaveManager.pending_world
	t.new_game()
	sm.set("pending_world", wire)
	var ok: bool = await t.change_scene("res://scenes/main/world.tscn", 20.0)
	await t.until(func() -> bool: return t.player() != null, 10.0)
	await t.frames(5)
	var w2: Node2D = t.world()
	var p2: Node2D = w2.player
	await t.physics(4)
	var landed: bool = ok and w2.area.map.id == &"traetoppen" and p2.global_position.distance_to(on_bridge) < 2.0 and ActorLevel.level_id(p2) == &"b3" and p2.z_index == 60
	# a damaged save (a position in the void between the trees) starts at the spawn instead
	var void_pos: Vector2 = _sk(100, 900)
	t.new_game()
	sm.set("pending_world", {"v": 1, "area": "traetoppen", "player_pos": [void_pos.x, void_pos.y]})
	await t.change_scene("res://scenes/main/world.tscn", 20.0)
	await t.until(func() -> bool: return t.player() != null, 10.0)
	await t.frames(5)
	var w3: Node2D = t.world()
	await t.physics(4)
	var spawn_ok: bool = w3.area.map.id == &"traetoppen" and w3.player.global_position.distance_to(w3.area.get_spawn("default")) < 2.0 and ActorLevel.level_id(w3.player) == &"torvet"
	_world = w3
	_area = w3.area
	_city = CityBuilder.of(_area)
	_reg = _city.registry if _city != null else null
	t.check("save_inside_city_roundtrip", keys_ok and landed and spawn_ok,
		"a save made on bridge B3 stores the area and the position only (keys %s, no level: it is a function of the position); Continue through SaveManager.pending_world builds the city and puts the player back through walkable_test at %s - on level b3 at z 60 (landed %s); a damaged position in the void starts at the Torvet spawn instead (%s)" % [d.keys(), on_bridge.round(), landed, spawn_ok])


# ================================================================== the next milestone's capabilities

func _capability_summary(t) -> void:
	var d2: bool = ResourceLoader.exists(D2_PATH)
	if d2:
		await _chain_with_d2(t)
	else:
		_skip(t, "skovlift_reaches_floor_1_and_back", "D2 landed", "Skovlift ride -> hub -> the Hulen warp -> floor 1 -> its up cave -> hub -> the hub gate -> traetoppen:from_skovlift needs the dungeon floors; REQUIRED by DQ's E1")
		_skip(t, "defeat_wakes_at_the_farm", "D2 landed", "a defeat on floor 1 wakes the player at farm:from_home needs the dungeon floors and D0's hook; REQUIRED by DQ's E2")
	var d2_lines: int = 0
	for line in _caps:
		if line.contains("D2 landed"):
			d2_lines += 1
	t.check("chain_checks_skip_without_d2", (d2 and d2_lines == 0) or (not d2 and d2_lines == 2), "D2 (scripts/dungeon/floors/dungeon_floors.gd) is %s: the two chain checks of order task 7 %s with the capability `D2 landed`" % ["present" if d2 else "absent", "run for real (skovlift_reaches_floor_1_and_back, defeat_wakes_at_the_farm)" if d2 else "SKIP"])
	var needed: Array[String] = ["P14-npc-dialogue", "V6-city-life", "V7-dialogue-v2", "P06-player-farm-core", "P19-forest-combat", "D2 landed"]
	var named: Array[String] = []
	var plain: Array[String] = []
	for line in _caps:
		if not line.contains(": capability missing: "):
			plain.append(line)
		for pkg in needed:
			if line.contains("capability missing: %s" % pkg) and not named.has(pkg):
				named.append(pkg)
	var absent: Array[String] = []
	if str(IsoArea.resolve_handler("npc")["kind"]) == "none":
		absent.append("P14-npc-dialogue")
	if not ResourceLoader.exists(P06_PATH):
		absent.append("P06-player-farm-core")
	if not FileAccess.file_exists(V7_DIALOGUE_PATH):
		absent.append("V7-dialogue-v2")
	if str(IsoArea.resolve_handler("node")["kind"]) == "none":
		absent.append("P19-forest-combat")
	if not d2:
		absent.append("D2 landed")
	var v6_absent: bool = false
	for ty in V6_TYPES:
		v6_absent = v6_absent or str(IsoArea.resolve_handler(ty)["kind"]) == "none"
	if v6_absent:
		absent.append("V6-city-life")
	var unnamed: Array[String] = []
	for pkg in absent:
		if not named.has(pkg):
			unnamed.append(pkg)
	t.check("preview_skips_are_visible", plain.is_empty() and unnamed.is_empty() and (_caps.is_empty() == absent.is_empty()),
		"every check that needs a package of the next milestone SKIPs with the line `capability missing: <package>`: %d lines, packages named %s, every package that is absent now (%s) is named (unnamed %s), no skip without the capability text %s" % [_caps.size(), named, absent, unnamed, plain])


# ================================================================== windowed: LOOK at it (shots, the frame budget, the walk)

const SKETCH_PATH := "res://docs/Trætoppen Style Guide Review/refs/miljoer_v2_render.png"
## The sketch's city frame inside refs/miljoer_v2_render.png (1760 x 3283): the crop that is compared with city_02.
const SKETCH_CROP := Rect2i(80, 582, 1598, 1100)


func _save(name: String, img: Image) -> void:
	if _t.out_dir != "" and img != null:
		var path: String = "%s/%s_%s.png" % [_t.out_dir, SECTION, name]
		if img.save_png(path) == OK:
			_t.info("saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])


## A contact sheet: the images scaled into cells of `cell` px, `cols` per row.
func _sheet(images: Array[Image], cols: int, cell: Vector2i) -> Image:
	var rows: int = int(ceil(float(images.size()) / float(cols)))
	var sheet: Image = Image.create(cols * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1c2138"))
	for i in images.size():
		var im: Image = images[i].duplicate()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, cell.x, cell.y), Vector2i((i % cols) * cell.x, int(floor(float(i) / float(cols))) * cell.y))
	return sheet


func _look(t, at: Vector2, zoom: float, settle: float = 0.35) -> void:
	var p: Node2D = _world.player
	p.camera.zoom = Vector2.ONE * zoom
	p.global_position = at
	p.camera.reset_smoothing()
	await t.physics(2)
	await t.seconds(settle)


func _screen_of(world_pos: Vector2) -> Vector2:
	return _world.get_viewport().get_canvas_transform() * world_pos


func _current_director() -> TownDirector:
	for node in _world.get_tree().get_nodes_in_group("town_director"):
		if node.area==_area:return node
	return null


func _refresh_native_citizens() -> void:
	NpcDirector.resync()


func _clear_native_hints() -> void:
	var hud: Node = _world.game_ui.get_screen(&"hud")
	hud.toasts.clear()
	hud.get_node("AreaBanner")._dismiss()


func run_windowed(t) -> void:
	_t = t
	_data = CityData.load_data()
	_k = CityData.scale_of(_data)
	if not await t.start_world():
		return
	_world = t.world()
	await t.seconds(0.3)
	var mb: float = 1024.0 * 1024.0
	var tex_before: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / mb
	var vid_before: float = float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / mb
	await _enter_city(t)
	await t.seconds(0.5)
	var tex_after: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / mb
	var vid_after: float = float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / mb
	t.check("vram_city_increment_within_budget", tex_after - tex_before <= 100.0 and vid_after - vid_before <= 100.0 and vid_after > vid_before,
		"windowed, vram_mb budget 100 = what the CITY adds to the world it is entered from (the shared ArtCatalog textures of the farm stay): texture memory %.1f -> %.1f MB (+%.1f), video memory %.1f -> %.1f MB (+%.1f); the TOTAL resident after the city is %.1f MB of video memory - the budget is the city's own increment, not the resident total" % [tex_before, tex_after, tex_after - tex_before, vid_before, vid_after, vid_after - vid_before, vid_after])
	var p: Node2D = _world.player
	var gm: Node = t.autoload("GameManager")
	p.set_physics_process(false)
	p.camera.position_smoothing_enabled = false
	p.visible = false
	_world.day_night.override_hour = 11.0
	_world.day_night.snap()
	_world.area.set_night_factor(0.0)
	# --- city_01: the Torvet at zoom 0.4 with Brumme at his stall (the weekend flag V6's DailyFlags would set) and the other citizens at their slots
	gm.set_flag(&"brumme_at_stall", 1)
	gm.set_flag(&"brumme_at_work", 0)
	_refresh_native_citizens()
	_clear_native_hints()      # the toast of the first arrival (Du har laast op ...) is not part of the picture
	await _look(t, _sk(900, 690), 0.4)
	var torvet: Image = await t.capture("city_01_torvet_zoom_0_4")
	t.expect_not_blank(torvet, Rect2i(0, 200, 1280, 520), "the Torvet renders (planks, huts, trunk, bridges, the stall, the fire)", 60, 0.04)
	var stall_view: Image = torvet
	var slots: Array[Image] = [torvet]
	for spot in [["hoppe", Vector2(509.2, 203.2), 0.5, -40.0], ["pip_and_oak", Vector2(1390, 300), 0.5, -40.0], ["brumme_workshop", Vector2(225, 640), 0.5, -40.0], ["sofus", Vector2(1454.5, 620), 0.5, -40.0], ["fru_ugle", Vector2(519, 380), 0.5, -40.0]]:
		gm.set_flag(&"brumme_at_stall", 0)
		gm.set_flag(&"brumme_at_work", 1)
		_refresh_native_citizens()
		await _look(t, _sk((spot[1] as Vector2).x, (spot[1] as Vector2).y) + Vector2(0, float(spot[3]) * 3.0), float(spot[2]))
		slots.append(await t.capture("city_01_slot_%s" % spot[0]))
	_save("city_01_citizens_contact_sheet", _sheet(slots, 3, Vector2i(640, 360)))
	gm.clear_flag(&"brumme_at_stall")
	gm.clear_flag(&"brumme_at_work")
	# --- city_02: the whole composition at zoom 0.2 beside the sketch crop
	_refresh_native_citizens()
	_clear_native_hints()      # the arrival toast of the first visit is gone: it is not part of the composition
	await _look(t, _overview_centre(), 0.2, 0.5)
	var overview: Image = await t.capture("city_02_overview_zoom_0_2")
	t.expect_not_blank(overview, Rect2i(0, 0, 1280, 720), "the whole city at zoom 0.2", 80, 0.04)
	var warm: Array[String] = []
	for pair in [["torvet", Vector2(870, 700)], ["upper", Vector2(785, 505)], ["c", Vector2(300, 690)], ["e", Vector2(1523, 540)], ["f", Vector2(588, 1068)], ["g", Vector2(1300, 1005)]]:
		var sp: Vector2 = _screen_of(_sk((pair[1] as Vector2).x, (pair[1] as Vector2).y))
		var col: Color = overview.get_pixel(clampi(int(sp.x), 0, 1279), clampi(int(sp.y), 0, 719))
		if not (col.r > col.b + 0.12 and col.r >= col.g * 0.95):
			warm.append("%s %s" % [pair[0], col.to_html(false)])
	var sketch: Image = Image.load_from_file(ProjectSettings.globalize_path(SKETCH_PATH))
	var beside: Image = null
	if sketch != null and not sketch.is_empty():
		var crop: Image = sketch.get_region(SKETCH_CROP)
		crop.convert(Image.FORMAT_RGBA8)
		var shown: Image = overview.duplicate()
		shown.convert(Image.FORMAT_RGBA8)
		var crop_h: int = int(round(1280.0 * float(crop.get_height()) / float(crop.get_width())))
		crop.resize(1280, crop_h, Image.INTERPOLATE_BILINEAR)
		beside = Image.create(2560, maxi(720, crop_h), false, Image.FORMAT_RGBA8)
		beside.fill(Color("f1ede4"))
		beside.blit_rect(shown, Rect2i(0, 0, 1280, 720), Vector2i(0, int(float(beside.get_height() - 720) * 0.5)))
		beside.blit_rect(crop, Rect2i(0, 0, 1280, crop_h), Vector2i(1280, 0))
		_save("city_02_overview_vs_sketch", beside)
	t.check("shot_overview_0_2", warm.is_empty() and beside != null and is_equal_approx(_world.area.zoom_range.x, 0.2),
		"windowed: the whole city at zoom 0.2 (the area's minimum) renders; the planks of the Torvet, the Upper deck, C, E, F and G are wood-coloured at their open floor (off %s); the picture is saved beside the sketch crop of refs/miljoer_v2_render.png (city_02_overview_vs_sketch.png) to be compared by eye" % [warm])
	# the top platforms in the PICTURE: the planks of A's and B's northernmost floor (just below the rim) are wood-coloured, not canopy green
	var top_cells: Array[String] = []
	var top_bad: Array[String] = []
	for id in [&"a", &"b"]:
		var at: Vector2 = _to_screen(_top_walkable(id) + Vector2(0, 20))
		var sum := Vector3.ZERO
		var n: int = 0
		for dx in range(-4, 5):
			for dy in range(-4, 5):
				var px: Vector2i = Vector2i(clampi(int(at.x) + dx, 0, 1279), clampi(int(at.y) + dy, 0, 719))
				var c: Color = overview.get_pixel(px.x, px.y)
				sum += Vector3(c.r, c.g, c.b)
				n += 1
		var mean := Color(sum.x / float(n), sum.y / float(n), sum.z / float(n))
		top_cells.append("%s at (%.0f, %.0f) %s" % [id, at.x, at.y, mean.to_html(false)])
		if not (mean.r > mean.b + 0.10 and mean.r >= mean.g * 0.95):
			top_bad.append("%s %s" % [id, mean.to_html(false)])
	var cb_edge: float = _canopy().bottom_edge()
	var discs_ok: bool = _to_screen(_disc_edge(&"a", false)).y >= cb_edge + CANOPY_CLEAR_PX and _to_screen(_disc_edge(&"b", false)).y >= cb_edge + CANOPY_CLEAR_PX
	t.check("overview_shows_the_top_platforms", top_bad.is_empty() and discs_ok and beside != null,
		"windowed, city_02 at zoom 0.2: the discs of A and B project below the canopy's lower edge (%.0f px of the 720 px screen) and their northernmost planks are wood-coloured in the picture (%s; not wood: %s); the shot beside the sketch is city_02_overview_vs_sketch.png" % [cb_edge, top_cells, top_bad])
	# --- city_05: the player on the north rim of A at the game zoom stands below the canopy (the camera has room above the sketch)
	p.visible = true
	await _look(t, _top_walkable(&"a") + Vector2(0, 30), 0.4)
	await t.capture("city_05_top_deck_a_zoom_0_4")
	p.visible = false
	# --- city_03: bridge B8 in front of the trunk, the real figure on it
	var b8: Level = _reg.get_level(&"b8")
	p.visible = true
	await _look(t, (b8.path[0] + b8.path[1]) * 0.5, 0.4)
	await t.capture("city_03_bridge_b8")
	p.visible = false
	# --- city_04: dusk with lanterns (the Torvet) and the bath at dusk with its lights
	_world.day_night.override_hour = 20.5
	_world.day_night.snap()
	_world.area.set_night_factor(_world.day_night.glow_factor)
	await _look(t, _sk(900, 690), 0.4, 0.5)
	var dusk: Image = await t.capture("city_04_dusk_lanterns")
	var fire: Vector2 = _screen_of(_sk(879, 735))
	var r := Rect2i(int(fire.x) - 50, int(fire.y) - 50, 100, 100)
	var l_fire: float = float(t.region_stats(dusk, r)["luma_mean"])
	var l_far: float = float(t.region_stats(dusk, Rect2i(30, 240, 140, 140))["luma_mean"])
	await _look(t, _sk(1454.5, 650), 0.4, 0.5)
	await t.capture("city_04_bath_at_dusk")
	var counts: Vector2i = _city.stage.glow.visible_counts()
	var lit: int = 0
	for id in _city.huts:
		var layer: CanvasItem = (_city.huts[id] as Node).get_node_or_null("Night") as CanvasItem
		if layer != null and layer.visible:
			lit += 1
	t.check("dusk_lights_are_visible", counts == Vector2i(46, 12) and l_fire > l_far * 1.15 and lit == 14,
		"at 20:30 the 46 halos, the 12 PointLight2D and the additive night layers of all %d huts are on; the fire pit's surroundings (luma %.3f) are brighter than a corner far from any light (%.3f)" % [lit, l_fire, l_far])
	_world.day_night.override_hour = 12.0
	_world.day_night.snap()
	_world.area.set_night_factor(0.0)
	# --- the frame budget at the game zoom
	await _look(t, _sk(900, 690), 0.4, 0.4)
	var hud_visible: bool = _world.game_ui.visible
	_world.game_ui.hide() # Standalone map budget; I2 separately measures the full city with HUD.
	var old_vsync: int = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await t.frames(20)
	var best_avg: float = 1e9
	var peak_calls: int = 0
	var calls_sum: int = 0
	var calls_n: int = 0
	for window in 8:
		var ms: float = 0.0
		var last: int = Time.get_ticks_usec()
		for i in 40:
			await t.tree.process_frame
			var now: int = Time.get_ticks_usec()
			ms += float(now - last) / 1000.0
			last = now
			var dc: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			calls_sum += dc
			calls_n += 1
			peak_calls = maxi(peak_calls, dc)
		best_avg = minf(best_avg, ms / 40.0)
		if window >= 2 and best_avg <= 6.0:
			break
	DisplayServer.window_set_vsync_mode(old_vsync as DisplayServer.VSyncMode)
	_world.game_ui.visible = hud_visible
	t.check("frame_budget", best_avg <= 6.0 and peak_calls <= 250, "the city area with approved painted art and scheduled citizens at zoom 0.4, 1280x720, vsync off: best window %.2f ms per frame (budget 6), draw calls average %d, peak %d (budget 250)" % [best_avg, int(float(calls_sum) / float(maxi(calls_n, 1))), peak_calls])
	# --- the prompt overlay in the picture: at the foot of the ladder the player reads "E: Klatre", a sign's whisper and a toast stand above it
	_world.day_night.override_hour = 11.0
	_world.day_night.snap()
	_world.area.set_night_factor(0.0)
	var ladder: Dictionary = _reg.ladders[0]
	p.visible = true
	p.set_physics_process(true)
	p.camera.position_smoothing_enabled = true
	p.facing8 = Iso.dir8_of(Vector2.UP)
	await _look(t, (ladder["bottom"] as Vector2) + Vector2(0, 40), 0.4, 0.6)
	var hud: Node = _world.game_ui.get_screen(&"hud")
	var prompt: PromptPill = hud.get_node("PromptPill")
	var whisper: WhisperLine = hud.get_node("WhisperLine")
	await t.until(func() -> bool:return bool(prompt.shown().visible),3.0)
	var pill := prompt.shown()
	var shot_prompt: Image = await t.capture("city_06_hints_prompt_at_the_ladder")
	var prompt_rect := Rect2i((prompt.get_node("%Pill") as Control).get_global_rect().grow(-2))
	var prompt_stats: Dictionary = t.region_stats(shot_prompt,prompt_rect,2)
	_city.signs[0].interact(p)
	EventBus.notification_posted.emit("toast title","toast message","zone")
	await t.seconds(0.3)
	var shot_all: Image = await t.capture("city_06_hints_whisper_and_toast")
	var whisper_rect := Rect2i((whisper.get_node("%Panel") as Control).get_global_rect().grow(-2))
	var whisper_stats: Dictionary = t.region_stats(shot_all,whisper_rect,2)
	var toasts: Array = hud.toasts.toasts()
	var toast_stats := {"luma_min":1.0,"luma_max":0.0,"luma_std":0.0}
	if not toasts.is_empty():
		toast_stats=t.region_stats(shot_all,Rect2i((toasts.back() as Control).get_global_rect().grow(-2)),2)
	var has_ink: Callable = func(st: Dictionary)->bool:return float(st.luma_min)<0.25 and float(st.luma_max)>0.65 and float(st.luma_std)>0.1
	t.check("hints_visible_at_the_ladder_foot",pill.visible and str(pill.cap)!="" and pill.verb==prompt.tr("LEVEL_PROMPT_CLIMB") and prompt_rect.size.x>40 and has_ink.call(prompt_stats) and whisper.is_showing() and has_ink.call(whisper_stats) and not toasts.is_empty() and has_ink.call(toast_stats),
		"current HUD at the real ladder: %s; prompt, sign whisper and notification have visible ink/text contrast: %s / %s / %s; city_06_hints_*.png" % [pill,prompt_stats,whisper_stats,toast_stats])
	_clear_native_hints()
	whisper._hide()
	# --- the walk: from the farm bridge over the whole city to Hyggebyen
	await _enter_city(t, &"from_farm")
	p = _world.player
	p.visible = true
	p.set_physics_process(true)
	p.camera.position_smoothing_enabled = true
	_world.day_night.override_hour = 11.0
	_world.day_night.snap()
	var shots: Array[Image] = []
	var printed: Array[String] = []
	var shot_ids: Array[String] = []
	var settle_shot := func(landmark: String) -> void:
		shot_ids.append(landmark)
		shots.append(await t.capture("city_walk_%02d_%s" % [shots.size() + 1, landmark]))
	# the level of the player is printed at EVERY landmark the moment its event fires (two of them are crossings: the bridges B8 and B2)
	var lm_cb: Callable = func(name: StringName, payload: Dictionary) -> void:
		if name == &"landmark_entered":
			printed.append("%s -> level %s at z %d" % [payload["id"], ActorLevel.level_id(p), p.z_index])
			if str(payload["id"]) in ["haengebroer", "uglehulerne"]:
				settle_shot.call(str(payload["id"]))
	EventBus.game_event.connect(lm_cb)
	var events: Callable = _record_events()
	var on_visit: Callable = func(landmark: String, _level: StringName) -> void:
		await t.seconds(0.55)
		await settle_shot.call(landmark)
	var t0: int = Time.get_ticks_msec()
	var report: Dictionary = await _tour(t, on_visit)
	var took: float = float(Time.get_ticks_msec() - t0) / 1000.0
	EventBus.game_event.disconnect(events)
	EventBus.game_event.disconnect(lm_cb)
	var arrived: bool = await _arrived(t, &"hyggebyen", 10.0)
	await t.seconds(0.8)
	var hyg: Image = await t.capture("city_walk_99_hyggebyen")
	shots.append(hyg)
	_save("city_walk_contact_sheet", _sheet(shots, 4, Vector2i(480, 270)))
	var lm_ids: Array[String] = []
	for e in _events_named(&"landmark_entered"):
		lm_ids.append(str((e as Dictionary)["id"]))
	for line in printed:
		t.info("walk: %s" % line)
	for line in report["legs"]:
		t.info("walk: %s" % str(line))
	t.check("walk_farm_to_hyggebyen_windowed", bool(report["ok"]) and arrived and lm_ids.size() == 10 and printed.size() == 10 and _events_named(&"ladder_climbed").size() == 2 and shots.size() >= 11,
		"windowed: the stub player walked from the farm bridge's arrival over every bridge and the ladder (both ways) to Hyggebyen in %.0f s on real time, no stuck point (%s); the level of the player at each of the 10 landmarks: %s; %d shots city_walk_*.png and the contact sheet" % [took, report["problems"], printed, shots.size()])
	_world.day_night.override_hour = -1.0
	_world.day_night.snap()
	p.visible = true


## Order task 7 with the dungeon present (REQUIRED by DQ's E1 / E2): the Skovlift ride -> the hub (spawn from_traetoppen) -> the Hulen warp -> floor 1 -> its up cave
## -> the hub (from_floor) -> the hub gate -> traetoppen:from_skovlift beside guard Oak; and a defeat on floor 1 wakes the player at farm:from_home. Written against
## D2's documented API (DUNGEON_V2_ADDENDUM 8.7: DungeonFloors.ensure_registered(floor, total_day) -> area id) and D0's world hook; it runs only when D2 exists, so
## it is UNPROVEN until then (the section skips it with `capability missing: D2 landed`).
func _chain_with_d2(t) -> void:
	var gm: Node = t.autoload("GameManager")
	await _enter_city(t, &"from_skovlift")
	var p: Node2D = _world.player
	_city.lift_gate.interact(p)
	var in_hub: bool = await _arrived(t, &"moerkeskoven", 10.0)
	await t.seconds(0.4)
	var floor_id: StringName = StringName(str(Svc.static_call(D2_PATH, &"ensure_registered", [1, int(gm.call("total_day"))], "")))
	var hulen: Warp2D = _warp_node(_world.area, String(floor_id)) if floor_id != &"" else null
	var on_floor: bool = false
	var up_cave: bool = false
	var gate_back: bool = false
	if in_hub and hulen != null:
		p.global_position = hulen.global_position
		on_floor = await _arrived(t, floor_id, 12.0)
		await t.seconds(0.5)
		on_floor = on_floor and p.global_position.distance_to(_world.area.get_spawn("default")) < 8.0
		var up: Warp2D = _warp_node(_world.area, "moerkeskoven")
		if on_floor and up != null:
			p.global_position = up.global_position
			up_cave = await _arrived(t, &"moerkeskoven", 12.0)
			await t.seconds(0.5)
			up_cave = up_cave and p.global_position.distance_to(_world.area.get_spawn("from_floor")) < 8.0
		var gate: Warp2D = _warp_node(_world.area, "traetoppen")
		if up_cave and gate != null:
			p.global_position = gate.global_position
			gate_back = await _arrived(t, &"traetoppen", 12.0)
			await t.seconds(0.5)
			_area = _world.area
			_city = CityBuilder.of(_area)
			_reg = _city.registry
			var oak: Dictionary = (CityData.markers_of(_data, "npc").filter(func(m: Dictionary) -> bool: return str(m["id"]) == "guard_oak"))[0]
			gate_back = gate_back and p.global_position.distance_to(_world.area.get_spawn("from_skovlift")) < 8.0 and p.global_position.distance_to(oak["at"] as Vector2) <= 60.0 * _k
	t.check("skovlift_reaches_floor_1_and_back", in_hub and floor_id == &"moerkeskoven_f1" and on_floor and up_cave and gate_back,
		"with the dungeon (D2): the Skovlift ride lands in the hub (%s), the Hulen warp opens floor 1 `%s` at its arrival clearing (%s), the floor's up cave leads back to the hub spawn from_floor (%s), the hub gate leads to traetoppen:from_skovlift at the rim of tree B beside guard Oak (%s)" % [in_hub, floor_id, on_floor, up_cave, gate_back])
	# a defeat on floor 1: the player wakes at the farm (D0's hook replaces the old farm:from_skovkant)
	var woke: bool = false
	if floor_id != &"" and on_floor:
		_world._enter(floor_id, &"default")
		await t.physics(3)
		EventBus.player_defeated.emit()
		woke = await t.until(func() -> bool: return _world.area != null and _world.area.map.id == &"farm" and not _world.traveling, 10.0)
		await t.seconds(0.6)
		woke = woke and _world.player.global_position.distance_to(_world.area.get_spawn("from_home")) < 8.0
	t.check("defeat_wakes_at_the_farm", woke, "with the dungeon (D2 + D0's world hook): player_defeated on floor 1 brings the world to the farm and the player stands at the spawn from_home (%s)" % [woke])
