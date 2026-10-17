extends RefCounted
## Section maps_farm (package N01-farm-map): the treetop farm "Min Traekronsgaard", data/maps/farm.map, on the REAL area framework.
##
## The file is the prototype of design3 track N, authoritative from the day it landed (generated once by tools/farm/farm_map_gen.py, hand-editable
## now): 61 x 51 cells, 1,206 of them ground. Everything here runs headless against the real IsoArea / WorldRoot2D / Warp2D / colliders; the
## probes were lifted from design3/farm/proto/farm_probe.gd (43 checks) and the farm halves of the P11 section maps_iso were re-homed here.
##
## What is NOT asserted here, and why: the handlers of the data markers belong to other packages (home F6, tent F6, dig_spot / unique_spot F4,
## mailbox V6, shipping_bin / tool_shed / field_expansion / underdeck / ambient_fx N02, dress N05, post / town the towns director, node P19,
## animal_yard / building_slot P20). Until they land those markers are skipped silently by IsoArea and stay readable through find_markers():
## this section lists them (info line) and proves the MAP side of every contract. Where a collider matters (walk, reach, clearance) the section
## stands in for the missing handler through tools/farm/farm_standins.gd, and ONLY for marker types that resolve to no handler yet.
##
## Windowed (`tests/run_playtest.sh --windowed --only=maps_farm`): the farm renders, the draw-call and texture budgets hold at zoom 0.4 / 0.3 / 0.2.

const SECTION := "maps_farm"
const TIMEOUT_S := 300.0

const Standins := preload("res://tools/farm/farm_standins.gd")

const MAP_PATH := "res://data/maps/farm.map"
const STANDINS_PATH := "res://tools/farm/farm_standins.gd"
const SIGNS_CSV := "res://localization/farm_signs.csv"
## The retired name of the fairy town (now Hyggebyen): assembled from pieces so that no file of the repo spells it out; it must appear nowhere.
const RETIRED_TOWN_NAME := "fe" + "sby"
const MARKERS_JSON := "res://data/features/map_markers.json"
const CHECKER := "tools/farm/check_farm_map.py"

## Warp targets of areas other tracks build: V4 closes `traetoppen` (the treetop city), then the section checks its arrival spawn.
const PENDING_AREAS: Array[String] = ["traetoppen"]
const REMOVED_FOREST_AREAS: Array[String] = ["skovkant", "dybe_bregner", "svampelunden", "krystalgrotten", "moerkeskoven", "hyggebyen"]
const SPAWN_NAMES: Array[String] = ["default", "from_home", "from_traetoppen", "from_greenhouse"]
const POSTS: Array[String] = ["bench_a", "field_edge", "hoppe_fence", "pip_mailbox", "porch"]
const GROUND_COUNTS := {".": 645, ",": 44, ";": 26, "p": 117, "d": 227, "=": 16, "f": 84, "~": 47, "#": 1905}
const MARKER_COUNTS := {"home": 1, "tent": 1, "bed": 1, "mailbox": 1, "shipping_bin": 1, "tool_shed": 1, "field_expansion": 1, "node": 8, "sign": 3,
	"dig_spot": 2, "unique_spot": 2, "warp": 1, "quest_spot": 1, "light": 3, "underdeck": 3, "ambient_fx": 1, "dress": 16, "post": 5, "town": 1,
	"animal_yard": 1, "building_slot": 3, "greenhouse_slot": 1}
## Built into IsoArea (a node or data, no handler script needed) / data markers other packages handle: every marker type of the map is one of these.
const BUILTIN_TYPES: Array[String] = ["spawn", "warp", "sign", "bed", "quest_spot", "light", "growth"]
const DATA_TYPES: Array[String] = ["home", "tent", "mailbox", "shipping_bin", "tool_shed", "field_expansion", "node", "dig_spot", "unique_spot",
	"animal_yard", "building_slot", "greenhouse_slot", "underdeck", "ambient_fx", "dress", "post", "town"]
const SLOT_FOOTPRINTS := {"coop": Vector2i(3, 2), "barn": Vector2i(4, 3), "house": Vector2i(3, 2)}
## The interactive markers that must stay clear of the HUD bands (guide section 06, UI_NAVIGATION S09) and that a player has to be able to reach.
const INTERACTIVE_TYPES: Array[String] = ["node", "sign", "bed", "mailbox", "shipping_bin", "tool_shed", "warp", "field_expansion", "dig_spot",
	"unique_spot", "quest_spot", "animal_yard", "building_slot", "home"]
const REACH_TYPES: Array[String] = ["warp", "bed", "mailbox", "shipping_bin", "tool_shed", "animal_yard", "field_expansion", "dig_spot", "unique_spot",
	"sign", "node", "quest_spot", "post", "building_slot", "home", "greenhouse_slot"]
const HOUSE_ROWS: Array[int] = [0, 0, 0, 0, 1, 1, 1, 2, 2, 3]       # platform.back_rows of home.json tier 1..10 (the contract the file names)
const TIER_CELLS: Array[int] = [4, 6, 12, 15, 20, 24, 28, 35, 45, 54]
const BODY := Vector2(25.0, 14.8)                                     # the player's collision ellipse in ground px (plan 3.3)
const HUD_BANDS := {"top": 140.0, "bottom": 70.0, "left": 90.0, "right": 90.0}   # screen px at zoom 0.4
const ROOF_HEADROOM_TIER10_PX := 468.0
const WALK_FRAMES_MAX := 600                                          # 10 s of physics frames
## Art that N03 bakes (wave 5): the ten farm-only props, the farm backdrops and the untilled terrain. Every other missing id is P22's.
const N03_IDS: Array[String] = ["prop:trunk_giant_a", "prop:trunk_giant_b", "prop:trunk_under_a", "prop:trunk_under_b", "prop:tool_shed", "prop:shipping_bin",
	"prop:stake_sign", "prop:rope_stake_x", "prop:rope_stake_z", "prop:build_stake", "backdrop:farm", "terrain:field_grass"]
## Props the handlers of the data markers place for this map (the markers carry no `prop=` for them) and the terrains the map and its field look use.
const HANDLER_PROPS: Array[String] = ["stake_sign", "rope_stake_x", "rope_stake_z", "build_stake", "trunk_under_a", "trunk_under_b", "coop_small", "barn_small",
	"animal_house", "apple_tree", "signpost", "tent", "bridge_x", "bridge_z", "platform_sw", "platform_se", "platform_corner"]
## The footprints the map is authored against (the building slots, the trunks, the shed, the bin): the rows of lua/config/props_extra.lua (P22).
const ASSUMED_FOOTPRINTS := {"trunk_giant_a": Vector2i(5, 3), "trunk_giant_b": Vector2i(3, 3), "tool_shed": Vector2i(2, 2), "shipping_bin": Vector2i(2, 1),
	"bench": Vector2i(2, 1), "coop_small": Vector2i(3, 2), "barn_small": Vector2i(4, 3), "animal_house": Vector2i(3, 2)}
const MAP_TERRAINS: Array[String] = ["grass", "grass_flowers", "path_dirt", "deck_farm", "water_0", "field_grass", "soil_tilled", "soil_watered"]

var _t
var _world: Node2D
var _m: AreaMap                         # the file, parsed on its own
var _by_type: Dictionary = {}           # marker type -> [{cell, params, ch}] from the object rows
var _props_by_art: Dictionary = {}      # art id -> [cell]
var _undeclared: Array = []
var _default_cell: Vector2i = Vector2i(-1, -1)
var _door: Vector2i = Vector2i.ZERO
var _a: IsoArea
var _astar: AStarGrid2D
var _standins: Dictionary = {}
var _info: Dictionary = {}


func run(t) -> void:
	_t = t
	_m = AreaMap.load_file(MAP_PATH)
	if _m == null:
		t.fail("maps_farm needs data/maps/farm.map: %s" % AreaMap.last_error)
		return
	_scan(_m)
	_door = _cell_of("home")
	if not await t.start_world():
		return
	_world = t.world()
	await _fresh_area(t)
	_the_file(t)
	_markers(t)
	_loc_and_header_notes(t)
	await _home_reserve(t)
	await _tiers(t)
	_spawns_and_warps(t)
	await _reachability(t)
	_bands_and_budgets(t)
	await _expansion(t)
	await _art(t)
	await _performance(t)
	await _bridge_and_the_city(t)
	_tool_selftest(t)
	await _cleanup(t)


# ================================================================== helpers

## Parses the object rows of a map into the marker / prop tables used by the file-level checks.
func _scan(m: AreaMap) -> void:
	_by_type.clear()
	_props_by_art.clear()
	_undeclared.clear()
	for y in m.height:
		var row: String = m.objects[y]
		for x in m.width:
			var ch: String = row[x]
			if ch == ".":
				continue
			var c := Vector2i(x, y)
			if ch == "@":
				_default_cell = c
			elif m.markers.has(ch):
				var d: Dictionary = m.markers[ch]
				var ty: String = str(d["marker"])
				if not _by_type.has(ty):
					_by_type[ty] = []
				(_by_type[ty] as Array).append({"cell": c, "params": d, "ch": ch})
			elif m.props.has(ch):
				var art: String = str(m.props[ch]["prop"])
				if not _props_by_art.has(art):
					_props_by_art[art] = []
				(_props_by_art[art] as Array).append(c)
			else:
				_undeclared.append([ch, c])


func _of(type: String) -> Array:
	return _by_type.get(type, []) as Array


func _cell_of(type: String) -> Vector2i:
	var l: Array = _of(type)
	return l[0]["cell"] if not l.is_empty() else Vector2i(-1, -1)


func _n(type: String) -> int:
	return _of(type).size()


func _count_props(art: String) -> int:
	return (_props_by_art.get(art, []) as Array).size()


## The world's farm area, built fresh (no growth stage, no leftovers of an earlier check), with the stand-ins of the unhandled markers.
func _fresh_area(t) -> void:
	_world.rebuild_current_area()
	await t.physics(1)
	if _world.area.map.id != &"farm":
		_world._enter(&"farm", &"default")
		await t.physics(1)
		_world.rebuild_current_area()
		await t.physics(1)
	_a = _world.area
	_standins = Standins.place_yard(_a)
	await t.physics(3)


func _walk_speed() -> float:
	return float(GameData.player_cfg("walk_speed", 285.0))


## Bounding rectangle (position = the smallest cell, size = the extent in cells) of a list of cells.
func _bbox(cells: Array) -> Rect2i:
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for c in cells:
		var v: Vector2i = c
		lo = Vector2i(mini(lo.x, v.x), mini(lo.y, v.y))
		hi = Vector2i(maxi(hi.x, v.x), maxi(hi.y, v.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _rect_cells(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out.append(Vector2i(x, y))
	return out


func _ground(c: Vector2i) -> String:
	return _a.map.ground_at(c)


# ================================================================== A. the file: header, grid, zones, field, expansion

func _the_file(t) -> void:
	var m: AreaMap = _m
	var live: AreaMap = _a.map
	t.check("parse_no_errors", m.errors.is_empty() and live.errors.is_empty() and _undeclared.is_empty(), "file errors %s, errors of the live area after setup %s, undeclared object chars %s" % [m.errors, live.errors, _undeclared])
	t.check("header", m.id == &"farm" and m.title == "ZONE_FARM" and m.projection == &"iso" and m.ambient == &"farm" and m.theme == &"farm" and m.zone == &"farm" and m.flight_allowed and m.music == "farm_theme" and m.builder == "",
		"id %s title %s projection %s ambient %s theme %s zone %s flight %s music %s" % [m.id, m.title, m.projection, m.ambient, m.theme, m.zone, m.flight_allowed, m.music])
	t.check("no_unknown_chars", _a.unknown_chars.is_empty() and _undeclared.is_empty(), "area.unknown_chars %s: every object char of the file is declared by @prop or @marker (or is the `@` default spawn)" % [_a.unknown_chars])
	var rows_ok: bool = m.ground.size() == m.height and m.objects.size() == m.height
	for r in m.ground:
		rows_ok = rows_ok and r.length() == m.width
	for r2 in m.objects:
		rows_ok = rows_ok and r2.length() == m.width
	t.check("rows_equal_width", rows_ok, "%d x %d, ground and object rows are the same rectangle" % [m.width, m.height])
	t.check("default_start_area_is_the_farm", WorldRoot2D.has_area(&"farm") and WorldRoot2D.default_area_id() == &"farm", "with farm.map present the new game starts on `farm` (was the fixture): %s" % WorldRoot2D.default_area_id())
	# ---- zone cell counts
	var counts: Dictionary = {}
	for row in m.ground:
		for ch in row:
			counts[ch] = int(counts.get(ch, 0)) + 1
	var bridge_runs: Array = _bridge_runs(m)
	var run_lengths: Array = []
	for r3 in bridge_runs:
		run_lengths.append((r3 as Array).size())
	run_lengths.sort()
	var pond: int = _largest_component(m, "~")
	t.check("zone_cell_counts", m.width == 61 and m.height == 51 and m.walkable_count() == 1206 and counts == GROUND_COUNTS and run_lengths == [7, 9] and pond == 47 and int(counts.get("~", 0)) == 47,
		"61 x 51, %d ground cells; . %d , %d ; %d p %d d %d = %d f %d ~ %d; bridges (planks per straight run) %s; one pond of %d water cells" % [m.walkable_count(), counts.get(".", 0), counts.get(",", 0), counts.get(";", 0), counts.get("p", 0), counts.get("d", 0), counts.get("=", 0), counts.get("f", 0), counts.get("~", 0), run_lengths, pond])
	# ---- the field F0
	var f_cells: Array[Vector2i] = []
	for y in m.height:
		for x in m.width:
			if m.ground[y][x] == "f":
				f_cells.append(Vector2i(x, y))
	var fb: Rect2i = _bbox(f_cells)
	var ring_bad: Array = []
	var gates: int = 0
	for c2 in _rect_cells(fb.position.x - 1, fb.position.y - 1, fb.end.x, fb.end.y):
		var inside: bool = c2.x >= fb.position.x and c2.x < fb.end.x and c2.y >= fb.position.y and c2.y < fb.end.y
		var oc: String = m.object_at(c2)
		var art: String = str((m.props.get(oc, {}) as Dictionary).get("prop", ""))
		if inside:
			if oc != ".":
				ring_bad.append(["object inside the field", c2, oc])
		else:
			var on_ring: bool = (c2.x == fb.position.x - 1 or c2.x == fb.end.x or c2.y == fb.position.y - 1 or c2.y == fb.end.y)
			if on_ring and not (art in ["fence_x", "fence_z", "fence_gate_x"]):
				ring_bad.append(["ring cell without a fence", c2, art])
			if art == "fence_gate_x":
				gates += 1
				if c2.x != fb.end.x:
					ring_bad.append(["the gate is not on the plaza (east) side", c2])
	t.check("field_84_f_cells", f_cells.size() == 84 and fb.size == Vector2i(12, 7) and _a.farmable.size() == 84 and ring_bad.is_empty() and gates == 1,
		"%d `f` cells in a %d x %d block, area.farmable %d, fence ring of 42 cells with ONE gate towards the plaza; findings %s" % [f_cells.size(), fb.size.x, fb.size.y, _a.farmable.size(), ring_bad.slice(0, 3)])
	# ---- the expansion zone E1
	var ex: Dictionary = (_of("field_expansion")[0] as Dictionary) if _n("field_expansion") == 1 else {}
	var ex_p: Dictionary = ex.get("params", {}) as Dictionary
	var problems: Array[String] = []
	var e_cells: Array[Vector2i] = IsoArea.parse_cells(str(ex_p.get("cells", "")), Vector2i(m.width, m.height), problems)
	var e_grass: bool = true
	var e_free: bool = true
	var e_farm: bool = false
	var eb: Rect2i = _bbox(e_cells)
	for c3 in e_cells:
		e_grass = e_grass and m.ground_at(c3) == "."
		e_free = e_free and m.object_at(c3) == "."
		e_farm = e_farm or _a.is_farmable(c3)
	var in_reserve: bool = false
	for c4 in e_cells:
		in_reserve = in_reserve or (c4.x >= _door.x - 4 and c4.x <= _door.x + 4 and c4.y >= _door.y - 5 and c4.y <= _door.y)
	t.check("expansion_zone_42_cells", e_cells.size() == 42 and e_grass and e_free and not e_farm and eb.size == Vector2i(6, 7) and str(ex_p.get("id", "")) == "east" and str(ex_p.get("price", "")) == "800" and not in_reserve,
		"%d cells (a %d x %d block) of plain grass `.` behind the stake sign, price %s, id %s, none tillable before the purchase, outside the home reserve" % [e_cells.size(), eb.size.x, eb.size.y, ex_p.get("price"), ex_p.get("id")])
	var ranges_ok: bool = false
	var rx := RegEx.new()
	rx.compile("^-?\\d+\\.\\.\\d+,-?\\d+\\.\\.\\d+$")
	ranges_ok = rx.search(str(ex_p.get("cells", ""))) != null
	var rect_cells: Array[Vector2i] = _rect_cells(eb.position.x, eb.position.y, eb.end.x - 1, eb.end.y - 1)
	t.check("expansion_cells_grammar_parses", problems.is_empty() and ranges_ok and e_cells.size() == rect_cells.size(),
		"cells=%s uses the ranges grammar x0..x1,y0..y1 of IsoArea.parse_cells: %d cells, problems %s" % [ex_p.get("cells"), e_cells.size(), problems])


## The straight runs of `=` planks (cells in the same column, consecutive rows).
func _bridge_runs(m: AreaMap) -> Array:
	var runs: Array = []
	for x in m.width:
		var cur: Array = []
		for y in range(m.height + 1):
			if y < m.height and m.ground[y][x] == "=":
				cur.append(Vector2i(x, y))
			elif not cur.is_empty():
				runs.append(cur)
				cur = []
	return runs


## Size of the largest 4-connected component of one ground char.
func _largest_component(m: AreaMap, ch: String) -> int:
	var seen: Dictionary = {}
	var best: int = 0
	for y in m.height:
		for x in m.width:
			var c := Vector2i(x, y)
			if m.ground[y][x] != ch or seen.has(c):
				continue
			var stack: Array[Vector2i] = [c]
			seen[c] = true
			var n: int = 0
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				n += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + (d as Vector2i)
					if not seen.has(q) and m.ground_at(q) == ch:
						seen[q] = true
						stack.append(q)
			best = maxi(best, n)
	return best


# ================================================================== B. markers

func _markers(t) -> void:
	var m: AreaMap = _m
	# ---- counts: the object rows of the file AND the live area agree with the table of the order
	var file_counts: Dictionary = {}
	for ty in _by_type:
		file_counts[ty] = (_by_type[ty] as Array).size()
	var live_counts: Dictionary = {}
	for rec in _a.markers:
		var lt: String = str(rec["type"])
		live_counts[lt] = int(live_counts.get(lt, 0)) + 1
	var live_ok: bool = true
	for ty2 in MARKER_COUNTS:
		live_ok = live_ok and int(live_counts.get(ty2, 0)) == int(MARKER_COUNTS[ty2])
	var growth: Array = []
	for ch in m.markers:
		if str(m.markers[ch]["marker"]) == "growth":
			growth.append(int(str(m.markers[ch].get("stage", "0"))))
	growth.sort()
	var spawn_named: Array = []
	for r in _of("spawn"):
		spawn_named.append(str((r["params"] as Dictionary).get("name", "")))
	var lanterns: int = _count_props("lantern_post")
	t.check("marker_counts", file_counts == MARKER_COUNTS.merged({"spawn": 3}, true) and live_ok and growth == [1, 2, 3] and _default_cell != Vector2i(-1, -1) and _a.spawns.size() == 4 and _n("lift") == 0 and lanterns == 8,
		"1 home, 1 tent, 1 bed, 1 mailbox, 1 bin, 1 shed, 1 expansion, 4 spawns (default `@` + 3 named), 8 node, 3 sign, 2 dig, 2 unique, 1 warp, 1 quest_spot, 3 light, 3 underdeck, 1 ambient_fx, 16 dress, 5 post, 1 town, 1 yard, 3 slots, 1 greenhouse slot, 3 growth, 8 lantern_post props; file %s live-area ok %s" % [file_counts, live_ok])
	var kinds: Dictionary = {}
	for r2 in _of("node"):
		var k: String = str((r2["params"] as Dictionary).get("kind", ""))
		kinds[k] = int(kinds.get(k, 0)) + 1
	t.check("node_kinds", kinds == {"apple_tree": 3, "tree_chop": 2, "rock_stone": 2, "flower_patch": 1}, "%s" % [kinds])
	var slot_types: Array = []
	for r3 in _of("building_slot"):
		slot_types.append(str((r3["params"] as Dictionary).get("type", "")))
	slot_types.sort()
	var yard: Dictionary = (_of("animal_yard")[0]["params"] as Dictionary) if _n("animal_yard") == 1 else {}
	t.check("animal_yard_and_slot_types", slot_types == ["barn", "coop", "house"] and str(yard.get("r", "")) == "3", "yard r=%s, slots %s (coop 3x2, barn 4x3, house 3x2 on their FRONT cells)" % [yard.get("r"), slot_types])
	# ---- every marker type is either built in or a known data marker of a later package (a typo would be skipped silently otherwise)
	var unknown: Array = []
	var skipped_known: Array = []
	for ty3 in _by_type:
		if not (ty3 in BUILTIN_TYPES) and not (ty3 in DATA_TYPES):
			unknown.append(ty3)
	for ty4 in _a.skipped_markers:
		if not (str(ty4) in DATA_TYPES):
			unknown.append("skipped:%s" % ty4)
		else:
			skipped_known.append(str(ty4))
	skipped_known.sort()
	var no_handler: Array = []
	for ty5 in _by_type:
		if str(IsoArea.resolve_handler(str(ty5)).get("kind", "none")) == "none" and not (ty5 in BUILTIN_TYPES):
			no_handler.append(ty5)
	no_handler.sort()
	t.check("marker_types_are_known", unknown.is_empty(), "built-in %s; data markers %s; unknown or typo'd types %s" % [BUILTIN_TYPES, DATA_TYPES, unknown])
	t.info("marker types of the farm that no handler package has landed yet (skipped silently, readable through find_markers): %s; skipped_markers of the area %s" % [no_handler, skipped_known])
	# ---- the F1 data contract: dig spots and unique spots
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARKERS_JSON))
	var entry: Dictionary = ((j as Dictionary).get("areas", {}) as Dictionary).get("farm", {}) as Dictionary if j is Dictionary else {}
	var want_dig: int = int((entry.get("containers", {}) as Dictionary).get("dig", -1))
	var want_chests: int = 0
	for ck in (entry.get("containers", {}) as Dictionary):
		if str(ck) != "dig":
			want_chests += int((entry["containers"] as Dictionary)[ck])
	var unique_ids: Array = []
	for r4 in _of("unique_spot"):
		unique_ids.append(str((r4["params"] as Dictionary).get("id", "")))
	unique_ids.sort()
	var want_unique: Array = (entry.get("unique_spots", []) as Array).duplicate()
	want_unique.sort()
	var chests: int = _count_props("chest_trae") + _count_props("chest_jern") + _count_props("chest_fe") + _count_props("chest_konge") + _count_props("chest_closed") + _n("chest")
	t.check("feature_markers_match_json", not entry.is_empty() and _n("dig_spot") == want_dig and want_dig == 2 and unique_ids == want_unique and unique_ids == ["fuglehuset", "trae_hulning"] and chests == want_chests and _n("enemy") == (entry.get("creatures", {}) as Dictionary).size(),
		"data/features/map_markers.json farm: dig %d (map %d), unique spots %s (map %s), chests %d, no creatures" % [want_dig, _n("dig_spot"), want_unique, unique_ids, want_chests])
	# ---- no Skovport, no forest warp, the forest sign stands where the gate was
	var warps: Array = _of("warp")
	var targets: Array = []
	for r5 in warps:
		targets.append(str((r5["params"] as Dictionary).get("to", "")))
	var forbidden_spawn: bool = false
	for sn in _a.spawns:
		forbidden_spawn = forbidden_spawn or str(sn) in ["from_skovport", "from_forest", "from_skovkant", "from_hyggebyen"]
	t.check("no_skovport_and_no_forest_warp", _n("lift") == 0 and _count_props("warp_gate_stone") == 0 and targets == ["traetoppen"] and not forbidden_spawn,
		"no `lift` marker, no warp_gate_stone prop, no spawn named from_skovport / from_forest / from_skovkant; the only warp goes to %s" % [targets])
	var signs: Array = []
	var forest_sign: Dictionary = {}
	for r6 in _of("sign"):
		signs.append(str((r6["params"] as Dictionary).get("text", "")))
		if str((r6["params"] as Dictionary).get("text", "")) == "SIGN_FARM_FOREST":
			forest_sign = r6
	signs.sort()
	t.check("forest_sign_marker", signs == ["SIGN_FARM_BRIDGE", "SIGN_FARM_FOREST", "SIGN_ORCHARD"] and not forest_sign.is_empty(), "signs %s; SIGN_FARM_FOREST at local %s (the Skovport was there: the forest is entered by the Skovlift from Traetoppen)" % [signs, (forest_sign.get("cell", Vector2i.ZERO) as Vector2i) - _door])
	# ---- the towns contract
	var post_names: Array = []
	var posts_ok: bool = true
	for r7 in _of("post"):
		var pp: Dictionary = r7["params"]
		post_names.append(str(pp.get("name", "")))
		posts_ok = posts_ok and str(pp.get("facing", "")) != "" and str(pp.get("act", "")) in ["stand", "sit"] and _ground(r7["cell"]) not in "#~="
	post_names.sort()
	var town: Dictionary = (_of("town")[0]["params"] as Dictionary) if _n("town") == 1 else {}
	t.check("posts_and_town_anchor", post_names == POSTS and posts_ok and _n("town") == 1 and str(town.get("curfew", "")) == "false",
		"posts %s each with facing= and act=, on walkable ground; ONE `town curfew=%s` anchor for the towns director" % [post_names, town.get("curfew")])
	# ---- the dress markers (DT14: the world flag festival_now, never the method festival_today)
	var dress_bad: Array = []
	var events: Dictionary = {}
	for r8 in _of("dress"):
		var dp: Dictionary = r8["params"]
		var conds: int = int(dp.has("tier")) + int(dp.has("season")) + int(dp.has("event"))
		if str(dp.get("prop", "")) == "" or conds != 1 or _ground(r8["cell"]) in "#~=":
			dress_bad.append([r8["cell"], dp])
		if dp.has("season") and not (str(dp["season"]) in ["foraar", "sommer", "efteraar", "vinter"]):
			dress_bad.append(["season", dp])
		if dp.has("tier") and not (int(dp["tier"]) >= 1 and int(dp["tier"]) <= 10):
			dress_bad.append(["tier", dp])
		if dp.has("event"):
			events[str(dp["event"])] = int(events.get(str(dp["event"]), 0)) + 1
	t.check("dress_markers_wellformed", dress_bad.is_empty() and _n("dress") == 16, "16 dress markers, each with a prop and exactly one of tier / season / event, on walkable ground; findings %s" % [dress_bad.slice(0, 3)])
	var text: String = FileAccess.get_file_as_string(MAP_PATH)
	t.check("dress_event_flag_is_a_social_world_flag", events == {"festival_now": 2} and not text.contains("festival_today"),
		"the two bunting markers read event=festival_now (the world flag SocialManager writes: the id of the festival ACTIVE now, empty otherwise); festival_today is a method and does not appear: %s" % [events])
	var mailbox: Dictionary = _of("mailbox")[0] if _n("mailbox") == 1 else {}
	var pip: Vector2i = Vector2i(-99, -99)
	for r9 in _of("post"):
		if str((r9["params"] as Dictionary).get("name", "")) == "pip_mailbox":
			pip = r9["cell"]
	var mb_cell: Vector2i = mailbox.get("cell", Vector2i(-1, -1))
	t.check("farm_mailbox_marker", _n("mailbox") == 1 and str((mailbox["params"] as Dictionary).get("prop", "")) == "mailbox_red" and _ground(mb_cell) == "d" and maxi(absi(pip.x - mb_cell.x), absi(pip.y - mb_cell.y)) <= 2 and mb_cell.y > _door.y,
		"ONE mailbox (prop mailbox_red) on the terrace deck in front of the house at local %s, Pip's post pip_mailbox beside it at local %s" % [mb_cell - _door, pip - _door])


	# ---- the paw prints of the lost cat lie ON the hanging bridge and only show while the quest is active
	var qs: Dictionary = _of("quest_spot")[0] if _n("quest_spot") == 1 else {}
	var qp: Dictionary = qs.get("params", {}) as Dictionary
	var qcell: Vector2i = qs.get("cell", Vector2i(-1, -1))
	var hang: Array = []
	for r10 in _bridge_runs(m):
		if (r10 as Array).size() == 9:
			hang = r10
	var lm2: Node = _t.autoload("LocalizationManager")
	t.check("quest_spot_paw_prints_on_the_bridge", _n("quest_spot") == 1 and str(qp.get("quest", "")) == "lost_cat" and str(qp.get("objective", "")) == "follow_pawprints" and str(qp.get("when", "")) == "quest:lost_cat" and str(qp.get("prop", "")) == "paw_prints" and qcell in hang and lm2 != null and bool(lm2.call("has_key", str(qp.get("prompt", "")))),
		"quest_spot lost_cat.follow_pawprints (prop paw_prints, when=quest:lost_cat, prompt %s) on plank %d of the 9 of the hanging bridge" % [qp.get("prompt"), hang.find(qcell) + 1])
	# ---- the orchard platform is joined to the limb ONLY by the 7-plank rope bridge; the hanging bridge only leaves the limb
	var comp: Dictionary = _components_without_planks(m)
	var orchard_c: int = int(comp.get(_cell_of_node("apple_tree"), -1))
	var limb_c: int = int(comp.get(_default_cell, -2))
	var seven: Array = []
	for r11 in _bridge_runs(m):
		if (r11 as Array).size() == 7:
			seven = r11
	var ends_ok: bool = false
	if not seven.is_empty():
		var first_p: Vector2i = seven[0]
		var last_p: Vector2i = seven[6]
		var c_a: int = int(comp.get(first_p + Vector2i(0, -1), -3))
		var c_b: int = int(comp.get(last_p + Vector2i(0, 1), -4))
		ends_ok = (c_a == orchard_c and c_b == limb_c) or (c_a == limb_c and c_b == orchard_c)
	var hang_ok: bool = not hang.is_empty() and int(comp.get((hang[0] as Vector2i) + Vector2i(0, -1), -5)) == limb_c and _ground((hang[8] as Vector2i) + Vector2i(0, 1)) == "#"
	t.check("orchard_joined_by_the_seven_plank_bridge", orchard_c >= 0 and limb_c >= 0 and orchard_c != limb_c and ends_ok and hang_ok,
		"without its planks the orchard terrace (component %d, trunk_giant_b, 3 apple trees) is cut off from the limb (component %d): the 7 planks are its only way; the 9-plank hanging bridge starts on the limb and ends in the void (the city side is V4's)" % [orchard_c, limb_c])


## Component id (4-connected, walkable ground without bridge planks and water) of every ground cell of the map.
func _components_without_planks(m: AreaMap) -> Dictionary:
	var comp: Dictionary = {}
	var next_id: int = 0
	for y in m.height:
		for x in m.width:
			var c := Vector2i(x, y)
			if comp.has(c) or m.ground[y][x] in "#=~":
				continue
			var stack: Array[Vector2i] = [c]
			comp[c] = next_id
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + (d as Vector2i)
					if not comp.has(q) and not (m.ground_at(q) in "#=~"):
						comp[q] = next_id
						stack.append(q)
			next_id += 1
	return comp


func _cell_of_node(kind: String) -> Vector2i:
	for r in _of("node"):
		if str((r["params"] as Dictionary).get("kind", "")) == kind:
			return r["cell"]
	return Vector2i(-1, -1)


# ================================================================== C. translation keys and the header note

func _loc_and_header_notes(t) -> void:
	var rows: Dictionary = {}
	var f := FileAccess.open(SIGNS_CSV, FileAccess.READ)
	var head: PackedStringArray = f.get_csv_line() if f != null else PackedStringArray()
	while f != null and not f.eof_reached():
		var line: PackedStringArray = f.get_csv_line()
		if line.size() >= 3 and line[0] != "":
			rows[line[0]] = {"da": line[1], "en": line[2]}
	var lm: Node = _t.autoload("LocalizationManager")
	var keys: Array = ["SIGN_ORCHARD", "SIGN_FARM_BRIDGE", "SIGN_FARM_FOREST"]
	var ok: bool = head == PackedStringArray(["keys", "da", "en"]) and rows.size() == 3
	var resolved: Array[String] = []
	for k in keys:
		ok = ok and rows.has(k) and str(rows[k]["da"]) != "" and str(rows[k]["en"]) != "" and str(rows[k]["da"]) != str(rows[k]["en"])
		if lm != null:
			ok = ok and bool(lm.call("has_key", k)) and str(lm.call("text_in", k, "da")) == str(rows[k]["da"]) and str(lm.call("text_in", k, "en")) == str(rows[k]["en"])
		resolved.append("%s" % k)
	var forest_text: String = str((rows.get("SIGN_FARM_FOREST", {}) as Dictionary).get("da", ""))
	var no_old_town: bool = true
	for k2 in rows:
		no_old_town = no_old_town and not str(rows[k2]["da"]).to_lower().contains(RETIRED_TOWN_NAME) and not str(rows[k2]["en"]).to_lower().contains(RETIRED_TOWN_NAME)
	var keep := FileAccess.get_file_as_string("res://localization/farm_signs.csv.import")
	t.check("farm_signs_defined_da_en", ok and forest_text == "Mørkeskoven ligger under Trætoppen. Tag Skovliften ved Posthuset." and no_old_town and keep.contains("importer=\"keep\""),
		"SIGN_ORCHARD, SIGN_FARM_BRIDGE, SIGN_FARM_FOREST each with a Danish and an English text, loaded by LocalizationManager (%s), SIGN_FARM_FOREST = the V track text, keep-import present" % [resolved])
	# the sign markers name exactly these keys, and the three exist as translations
	var sign_keys: Array = []
	for r in _of("sign"):
		sign_keys.append(str((r["params"] as Dictionary).get("text", "")))
	sign_keys.sort()
	var tr_ok: bool = lm != null
	for k3 in sign_keys:
		tr_ok = tr_ok and bool(lm.call("has_key", k3))
	t.check("sign_markers_name_defined_keys", sign_keys == ["SIGN_FARM_BRIDGE", "SIGN_FARM_FOREST", "SIGN_ORCHARD"] and tr_ok, "the three sign markers read keys that exist: %s" % [sign_keys])
	var warp_label: String = str((_of("warp")[0]["params"] as Dictionary).get("label", "")) if _n("warp") == 1 else ""
	t.info("the warp label key %s (the city's name) is core.csv's (V1, a later stage): defined now = %s" % [warp_label, lm != null and bool(lm.call("has_key", warp_label))])
	t.check("header_documents_unhandled_marker_types", text_has("skipped silently") and text_has("handler registry"), "the header of farm.map says that marker types without a handler script are skipped silently and stay readable through find_markers")
	t.check("no_old_town_name_in_the_map", not FileAccess.get_file_as_string(MAP_PATH).to_lower().contains(RETIRED_TOWN_NAME), "the retired name of the fairy town appears nowhere in farm.map")


func text_has(s: String) -> bool:
	return FileAccess.get_file_as_string(MAP_PATH).contains(s)


# ================================================================== D. the home reserve

func _home_reserve(t) -> void:
	var a: IsoArea = _a
	var door: Vector2i = _door
	# the reserve is free of every object char except `H`, base rows are planks, growth rows are void at the start
	var bad: Array = []
	for x in range(door.x - 4, door.x + 5):
		for y in range(door.y - 5, door.y + 1):
			var c := Vector2i(x, y)
			if c == door:
				continue
			var in_base: bool = y >= door.y - 2
			if a.map.object_at(c) != ".":
				bad.append([c - door, "object", a.map.object_at(c)])
			if in_base and a.map.ground_at(c) != "d":
				bad.append([c - door, "base ground", a.map.ground_at(c)])
			if not in_base and a.map.ground_at(c) != "#":
				bad.append([c - door, "growth cell not void", a.map.ground_at(c)])
	var base_deck: int = 0
	for x in range(door.x - 4, door.x + 5):
		for y in range(door.y - 2, door.y + 1):
			if a.map.ground_at(Vector2i(x, y)) == "d":
				base_deck += 1
	var stage_sizes: Array = []
	for s in [1, 2, 3]:
		stage_sizes.append(a.growth_cells(s).size())
	t.check("home_reserve_free_and_void_at_start", bad.is_empty() and base_deck == 27 and stage_sizes == [9, 9, 9] and a.max_growth_stage() == 3 and a.map.object_at(door) == _by_type["home"][0]["ch"],
		"the door cell D carries `H`; the 9 x 3 base (x D-4..D+4, y D-2..D) is 27 planks free of objects; the 27 growth cells (rows D-3 / D-4 / D-5) are void: stages %s; findings %s" % [stage_sizes, bad.slice(0, 4)])
	var ms: Array = []
	var deck_ok: bool = true
	var deck_note: Array = []
	for st in [1, 2, 3]:
		var t1: int = Time.get_ticks_usec()
		a.set_growth_stage(st)
		ms.append(snappedf(float(Time.get_ticks_usec() - t1) / 1000.0, 0.1))
		var deck: int = 0
		for x in range(door.x - 4, door.x + 5):
			for y in range(door.y - 2 - st, door.y + 1):
				if a.map.ground_at(Vector2i(x, y)) == "d":
					deck += 1
		deck_ok = deck_ok and deck == 9 * (3 + st)
		deck_note.append("stage %d: %d planks" % [st, deck])
		t.check("growth_stage_%d_deck" % st, deck == 9 * (3 + st) and a.growth_stage == st, "set_growth_stage(%d): the %d x %d rect is deck (%d planks)" % [st, 9, 3 + st, deck])
	var full: int = 0
	for c in _rect_cells(door.x - 4, door.y - 5, door.x + 4, door.y):
		if a.map.ground_at(c) == "d" and a.is_walkable(c):
			full += 1
	a.set_growth_stage(0)
	var restored: bool = true
	for st2 in [1, 2, 3]:
		for c2 in a.growth_cells(st2):
			restored = restored and a.map.ground_at(c2) == "#"
	t.check("home_reserve_on_deck_after_growth", full == 54 and restored and a.growth_stage == 0 and ms.size() == 3,
		"after stage 3 all 54 cells of the tier-10 rect (9 x 6) are walkable deck, stage 0 gives the void rows back (derived state, never saved); set_growth_stage ms per stage %s" % [ms])
	_info["growth_ms"] = ms
	# the five stages of the design: tiers -> rows (the contract of home.json)
	var tiers: Array = Standins.home_tiers()
	var rows_ok: bool = tiers.size() == 10
	var rows_seen: Array = []
	for i in tiers.size():
		var pl: Dictionary = (tiers[i] as Dictionary).get("platform", {}) as Dictionary
		rows_seen.append(int(pl.get("back_rows", -1)))
	rows_ok = rows_ok and rows_seen == HOUSE_ROWS
	t.check("growth_rows_follow_home_json", rows_ok, "platform.back_rows of the ten tiers of home.json = %s" % [rows_seen])
	# ---- nothing walkable behind the castle (the silhouette box u -4.4..10.4, v -30..-1 north of the door row)
	var dead: Array = []
	for y in a.map.height:
		for x in a.map.width:
			var c3 := Vector2i(x, y)
			var ch: String = a.map.ground_at(c3)
			if ch == "#" or ch == "=":
				continue
			if x >= door.x - 4 and x <= door.x + 4 and y >= door.y - 5 and y <= door.y:
				continue
			var u: float = float((x - y) - (door.x - door.y))
			var v: float = float((x + y) - (door.x + door.y))
			if y <= door.y and u >= -4.4 and u <= 10.4 and v >= -30.0 and v < 0.0:
				dead.append(c3 - door)
	t.check("no_walkable_cell_behind_the_castle", dead.is_empty(), "%d ground cells inside the tier-10 silhouette box u -4.4..10.4, v -30..-1 behind the door row: %s" % [dead.size(), dead.slice(0, 6)])


# ================================================================== E. every tier: footprint on deck, spawn free, roof headroom

func _tiers(t) -> void:
	var a: IsoArea = _a
	var door: Vector2i = _door
	var tiers: Array = Standins.home_tiers()
	var tier_bad: Array = []
	var cells_seen: Array = []
	var spawn_bad: Array = []
	var clear_min: float = 1e9
	var head: Array = []
	var head_ok: bool = true
	var spawn_pos: Vector2 = a.get_spawn("from_home")
	var space: PhysicsDirectSpaceState2D = a.get_world_2d().direct_space_state
	var shape := _body_shape(1.0)
	for tier in range(1, 11):
		var rows: int = HOUSE_ROWS[tier - 1]
		a.set_growth_stage(rows)
		var fr: Array = (tiers[tier - 1] as Dictionary)["footprint_rect"]
		var n_cells: int = 0
		# the cells whose centre lies strictly inside the footprint rect around the door-centre anchor (cell-corner coordinates: anchor = (dx + 0.5, dy + 1))
		for x in range(door.x - 6, door.x + 7):
			for y in range(door.y - 8, door.y + 3):
				var cx: float = float(x) + 0.5 - (float(door.x) + 0.5)
				var cy: float = float(y) + 0.5 - (float(door.y) + 1.0)
				if cx > float(fr[0]) and cx < float(fr[2]) and cy > float(fr[1]) and cy < float(fr[3]):
					n_cells += 1
					if a.map.ground_at(Vector2i(x, y)) != "d":
						tier_bad.append([tier, Vector2i(x, y) - door, a.map.ground_at(Vector2i(x, y))])
		cells_seen.append(n_cells)
		# the real player body must fit at from_home with the padded footprint collider of this tier
		var holder: Node2D = Standins.place_home(a, tier, door, false)
		await t.physics(1)
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape
		q.collision_mask = Iso.LAYER_WORLD | Iso.LAYER_GROUND_BLOCK
		q.transform = Transform2D(0.0, spawn_pos)
		if not space.intersect_shape(q, 4).is_empty():
			spawn_bad.append(tier)
		clear_min = minf(clear_min, _clearance(Standins.footprint_polygon(tier), a, door, spawn_pos))
		holder.queue_free()
		await t.physics(1)
		# the roof stays below the camera limit (the camera rect follows the grown deck)
		var cam: Rect2 = a.camera_rect()
		var anchor: Vector2 = a.cell_to_global(door) + Standins.DOOR_ANCHOR
		var pivot_y: float = float(((tiers[tier - 1] as Dictionary)["exterior"] as Dictionary)["pivot"][1])
		var margin: float = (anchor.y - pivot_y) - cam.position.y
		head.append(snappedf(margin, 1.0))
		head_ok = head_ok and margin >= 0.0
	a.set_growth_stage(0)
	t.check("every_tier_footprint_on_deck", tier_bad.is_empty() and cells_seen == TIER_CELLS, "after its growth rows (%s) the footprint of EVERY tier is deck: cells per tier %s, cells without deck %d %s" % [HOUSE_ROWS, cells_seen, tier_bad.size(), tier_bad.slice(0, 4)])
	t.check("spawn_from_home_walkable", spawn_bad.is_empty() and a.is_walkable(a.global_to_cell(spawn_pos)) and a.global_to_cell(spawn_pos) == door + Vector2i(0, 2) and clear_min > 0.0,
		"from_home = D + (0, 2) is walkable and the real 25 x 14.8 body fits there against the padded footprint collider of all ten tiers (blocked at %s, closest padded edge %.0f ground px)" % [spawn_bad, clear_min])
	t.check("roof_headroom_all_tiers", head_ok and float(head[9]) >= ROOF_HEADROOM_TIER10_PX, "px between the camera limit and the roof top, tiers 1..10 (with each tier's growth rows): %s; tier 10 must leave >= %d" % [head, int(ROOF_HEADROOM_TIER10_PX)])
	# ---- the mutant: tier 5 without its growth row has no deck under part of the footprint (so every_tier_footprint_on_deck can fail)
	a.set_growth_stage(0)
	var fr5: Array = (tiers[4] as Dictionary)["footprint_rect"]
	var missing5: int = 0
	var total5: int = 0
	for x in range(door.x - 6, door.x + 7):
		for y in range(door.y - 8, door.y + 3):
			var cx5: float = float(x) + 0.5 - (float(door.x) + 0.5)
			var cy5: float = float(y) + 0.5 - (float(door.y) + 1.0)
			if cx5 > float(fr5[0]) and cx5 < float(fr5[2]) and cy5 > float(fr5[1]) and cy5 < float(fr5[3]):
				total5 += 1
				if a.map.ground_at(Vector2i(x, y)) != "d":
					missing5 += 1
	a.set_growth_stage(1)
	var after5: int = 0
	for x in range(door.x - 6, door.x + 7):
		for y in range(door.y - 8, door.y + 3):
			var cx6: float = float(x) + 0.5 - (float(door.x) + 0.5)
			var cy6: float = float(y) + 0.5 - (float(door.y) + 1.0)
			if cx6 > float(fr5[0]) and cx6 < float(fr5[2]) and cy6 > float(fr5[1]) and cy6 < float(fr5[3]) and a.map.ground_at(Vector2i(x, y)) != "d":
				after5 += 1
	a.set_growth_stage(0)
	t.check("mutant_tier5_without_growth_row_is_caught", total5 == 20 and missing5 == 5 and after5 == 0, "tier 5 (5 x 4 = %d cells) WITHOUT stage 1: %d cells have no deck (the check would fail); with stage 1: %d" % [total5, missing5, after5])
	# ---- the wake-up spawn: defeat and pass-out put the player at the door (D0 wires the world to it; the farm side is this contract)
	var world_player: Node2D = _world.player
	var tier10: Node2D = Standins.place_home(a, 10, door, false)
	await t.physics(2)
	world_player.call("enter_area", a, spawn_pos)
	await t.physics(3)
	var drift: float = world_player.global_position.distance_to(spawn_pos)
	tier10.queue_free()
	await t.physics(2)                       # the collider is really gone from the physics space before the navigation bake
	t.check("wake_spawn_from_home_walkable", a.spawns.has("from_home") and a.is_walkable(a.global_to_cell(spawn_pos)) and drift < 2.0,
		"the player stub entered at from_home beside the tier-10 collider and was not pushed out (drift %.2f px): the wake-up spawn of defeat and pass-out (area.get_spawn falls back to `default` only for names the map lacks)" % drift)
	world_player.call("enter_area", a, a.get_spawn("default"))


## A convex 12-gon of the player's body ellipse (x1 = the real 25 x 14.8), scaled by `scale` for the navigation bake.
func _body_shape(scale: float) -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var ang: float = TAU * float(i) / 12.0
		pts.append(Vector2(cos(ang) * BODY.x * scale, sin(ang) * BODY.y * scale))
	shape.points = pts
	return shape


## Distance in ground px from the edge of the player's body (a circle of ground radius 25 around `p`) to the padded footprint polygon of a
## tier placed at the door (polygon points are screen px relative to the anchor); everything is measured in ground space.
func _clearance(poly: PackedVector2Array, a: IsoArea, door: Vector2i, p: Vector2) -> float:
	var anchor: Vector2 = a.cell_to_global(door) + Standins.DOOR_ANCHOR
	var gp: Vector2 = Iso.to_ground(p)
	var best: float = 1e9
	for i in poly.size():
		var g1: Vector2 = Iso.to_ground(anchor + poly[i])
		var g2: Vector2 = Iso.to_ground(anchor + poly[(i + 1) % poly.size()])
		best = minf(best, gp.distance_to(Geometry2D.get_closest_point_to_segment(gp, g1, g2)))
	return best - BODY.x


# ================================================================== F. spawns and warps

func _spawns_and_warps(t) -> void:
	var a: IsoArea = _a
	var spawns_have: bool = true
	for s in SPAWN_NAMES:
		spawns_have = spawns_have and a.spawns.has(s)
	var warp: Dictionary = _of("warp")[0] if _n("warp") == 1 else {}
	var wp: Dictionary = warp.get("params", {}) as Dictionary
	var wcell: Vector2i = warp.get("cell", Vector2i.ZERO)
	var to: String = str(wp.get("to", ""))
	var target_ok: bool = WorldRoot2D.has_area(StringName(to)) or to in PENDING_AREAS
	var last_plank: bool = _ground(wcell) == "=" and _ground(wcell + Vector2i(0, 1)) == "#" and _ground(wcell - Vector2i(0, 1)) == "="
	var on_bridge: bool = _ground(_cell_of_spawn("from_traetoppen")) == "=" and _cell_of_spawn("from_traetoppen") == wcell - Vector2i(0, 3)
	t.check("warp_graph", spawns_have and a.spawns.size() == 4 and _n("warp") == 1 and to == "traetoppen" and str(wp.get("spawn", "")) == "from_farm" and str(wp.get("label", "")) == "ZONE_TRAETOPPEN" and target_ok and last_plank and on_bridge,
		"exactly four spawns %s; the ONLY warp -> %s:%s (label %s) sits on the LAST plank (local %s); `traetoppen` %s; from_traetoppen is on the bridge 3 planks before the warp" % [a.spawns.keys(), to, wp.get("spawn"), wp.get("label"), wcell - _door, "exists" if WorldRoot2D.has_area(&"traetoppen") else "is PENDING (V4 builds it; the arrival `from_farm` is V4's)"])
	if WorldRoot2D.has_area(&"traetoppen"):
		var city: AreaMap = WorldRoot2D.load_map(&"traetoppen")
		var arrival: bool = false
		var back_ok: bool = false
		if city != null:
			for ch in city.markers:
				var cm: Dictionary = city.markers[ch]
				if str(cm.get("marker", "")) == "spawn" and str(cm.get("name", "")) == "from_farm":
					arrival = true
				if str(cm.get("marker", "")) == "warp" and str(cm.get("to", "")) == "farm":
					back_ok = str(cm.get("spawn", "")) in a.spawns
			arrival = arrival or city.is_builder()
		t.info("traetoppen.map exists now: arrival spawn from_farm declared in the map text %s (a levelled builder map declares it in its data), its warp back lands on a farm spawn %s" % [arrival, back_ok])
	else:
		t.info("traetoppen.map does not exist yet (V4, a later stage of this milestone): the arrival spawn `from_farm` and the way back are checked once it does")
	var targets_removed: Array = []
	for r in _of("warp"):
		if str((r["params"] as Dictionary).get("to", "")) in REMOVED_FOREST_AREAS:
			targets_removed.append((r["params"] as Dictionary).get("to"))
	t.check("no_warp_to_removed_forest_areas", targets_removed.is_empty(), "no farm warp goes to the forest areas or to Hyggebyen (the Skovport is removed: the forest is entered by the Skovlift from Traetoppen, decision DN2): %s" % [targets_removed])
	var farm_graph_ok: bool = to == "traetoppen" and a.spawns.has("from_traetoppen") and not a.spawns.has("from_hyggebyen")
	t.check("farm_warp_graph", farm_graph_ok and _n("warp") == 1, "zone table of the addendum: farm -> traetoppen:from_farm only; the way back lands on farm:from_traetoppen (on the bridge, outside every warp diamond)")
	var min_gap: float = 1e9
	var worst: String = ""
	for r2 in _of("warp"):
		for sn in a.spawns:
			var g: float = Iso.ground_dist(a.spawns[sn], a.cell_to_global(r2["cell"]))
			if g < min_gap:
				min_gap = g
				worst = str(sn)
	t.check("spawns_outside_warps", min_gap > 2.0 * 90.0, "closest spawn-to-warp distance %.0f ground px (%s): no spawn lies inside a warp diamond, so an arrival never re-triggers the warp (limit 180)" % [min_gap, worst])


func _cell_of_spawn(name: String) -> Vector2i:
	for r in _of("spawn"):
		if str((r["params"] as Dictionary).get("name", "")) == name:
			return r["cell"]
	return Vector2i(-1, -1)


# ================================================================== G. connectivity from the REAL colliders

func _bake(a: IsoArea, scale: float) -> void:
	var space: PhysicsDirectSpaceState2D = a.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _body_shape(scale)
	q.collision_mask = Iso.LAYER_WORLD | Iso.LAYER_GROUND_BLOCK
	q.collide_with_areas = false
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, a.map.width, a.map.height)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	var solid: int = 0
	for y in a.map.height:
		for x in a.map.width:
			var c := Vector2i(x, y)
			var ch: String = a.map.ground_at(c)
			var blocked: bool = ch == "#" or ch == "~"
			if not blocked:
				q.transform = Transform2D(0.0, a.cell_to_global(c))
				blocked = not space.intersect_shape(q, 1).is_empty()
			if blocked:
				_astar.set_point_solid(c, true)
				solid += 1
	_info["nav_solid_x%.1f" % scale] = solid


func _path_len(a: IsoArea, from_c: Vector2i, to_c: Vector2i) -> float:
	var ids: Array[Vector2i] = _astar.get_id_path(from_c, to_c)
	if ids.is_empty():
		return -1.0
	var total: float = 0.0
	for i in range(1, ids.size()):
		total += Iso.ground_dist(a.cell_to_global(ids[i - 1]), a.cell_to_global(ids[i]))
	return total


## Shortest walking length from `start` to the nearest free cell within two cells of `cell` (a prop or a door stands ON its cell:
## the E query circle of the player reaches 45 ground px around the facing cell).
func _reach(a: IsoArea, start: Vector2i, cell: Vector2i) -> float:
	var best: float = -1.0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var c: Vector2i = cell + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= a.map.width or c.y >= a.map.height or _astar.is_point_solid(c):
				continue
			var l: float = _path_len(a, start, c)
			if l >= 0.0 and (best < 0.0 or l < best):
				best = l
	return best


func _reachability(t) -> void:
	var a: IsoArea = _a
	_bake(a, 1.4)
	var start: Vector2i = a.global_to_cell(a.spawns["default"])
	var targets: Array = []
	for rec in a.markers:
		if str(rec["type"]) in REACH_TYPES:
			targets.append([str(rec["type"]), rec["cell"]])
	for sn in a.spawns:
		targets.append(["spawn:" + String(sn), a.global_to_cell(a.spawns[sn])])
	var unreachable: Array = []
	var lens: Dictionary = {}
	for tg in targets:
		var l: float = _reach(a, start, tg[1])
		if l < 0.0:
			unreachable.append([tg[0], (tg[1] as Vector2i) - _door])
		else:
			lens["%s@%d,%d" % [tg[0], (tg[1] as Vector2i).x, (tg[1] as Vector2i).y]] = snappedf(l, 1.0)
	t.check("every_marker_reachable", unreachable.is_empty() and targets.size() >= 35, "%d targets (home, bed, mailbox, bin, shed, signs, nodes, dig / unique spots, slots, yard, stake, warp, posts, spawns) reachable from `default` with the body x1.4 baked from the physics space (%d solid cells); unreachable %s" % [targets.size(), int(_info.get("nav_solid_x1.4", 0)), unreachable])
	var f_unreach: int = 0
	for c in a.farmable:
		if _path_len(a, start, c) < 0.0:
			f_unreach += 1
	t.check("every_field_cell_reachable", f_unreach == 0 and a.farmable.size() == 84, "%d of %d field cells unreachable (an edge cell of the field is reached from outside the fence through the gate)" % [f_unreach, a.farmable.size()])
	var home_spawn: Vector2i = a.global_to_cell(a.spawns["from_home"])
	var warp_cell: Vector2i = _cell_of("warp")
	var l_bridge: float = _path_len(a, home_spawn, warp_cell)
	# no cell of the map is reachable only through a prop: every ground cell a body of x1.4 can stand on belongs to the one region of the spawn
	var islands: Array = []
	var standable: int = 0
	for yy in a.map.height:
		for xx in a.map.width:
			var cc := Vector2i(xx, yy)
			if a.map.ground_at(cc) in "#~" or _astar.is_point_solid(cc):
				continue
			standable += 1
			if _path_len(a, start, cc) < 0.0:
				islands.append(cc - _door)
	t.check("no_cell_cut_off_by_props", islands.is_empty() and standable > 700, "%d ground cells a body x1.4 can stand on, %d of them not reachable from `default` (a fence, a bench, a trunk or a shed would cut them off): %s" % [standable, islands.size(), islands.slice(0, 6)])
	var sign_cell: Vector2i = Vector2i.ZERO
	for r in _of("sign"):
		if str((r["params"] as Dictionary).get("text", "")) == "SIGN_FARM_FOREST":
			sign_cell = r["cell"]
	var l_sign: float = _reach(a, home_spawn, sign_cell)
	_info["path_to_bridge"] = l_bridge
	t.check("forest_sign_reachable", l_sign > 0.0 and l_sign / _walk_speed() < 12.0, "the forest sign is %.1f s from from_home walking (%.0f ground px at %.0f px/s)" % [l_sign / _walk_speed(), l_sign, _walk_speed()])
	t.info("home -> forest sign %.1f s walking" % (l_sign / _walk_speed()))
	# the corridor of the hanging bridge must stay open for the REAL body: bake x1.0 and walk it with a real CharacterBody2D
	_bake(a, 1.0)
	await _walk_the_bridge(t, a, home_spawn, warp_cell, l_bridge)


func _walk_the_bridge(t, a: IsoArea, home_spawn: Vector2i, warp_cell: Vector2i, l_bridge_14: float) -> void:
	var body := CharacterBody2D.new()
	body.add_to_group("player")
	body.collision_layer = Iso.LAYER_PLAYER
	body.collision_mask = Iso.MASK_WALKING
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	cs.shape = _body_shape(1.0)
	body.add_child(cs)
	a.objects.add_child(body)
	body.global_position = a.spawns["from_home"]
	var ids: Array[Vector2i] = _astar.get_id_path(home_spawn, warp_cell)
	var bus: Node = t.autoload("EventBus")
	var changes: Array = []
	var cb := func(area_id: StringName, spawn_name: StringName) -> void: changes.append([String(area_id), String(spawn_name)])
	bus.area_change_requested.connect(cb)
	# the world would travel as soon as the warp fires (and `traetoppen` may exist by then): record the request, do not follow it
	var muted: Array = []
	for conn in bus.area_change_requested.get_connections():
		var c: Callable = conn["callable"]
		if c.get_object() == _world:
			bus.area_change_requested.disconnect(c)
			muted.append(c)
	var speed: float = _walk_speed()
	var idx: int = 1
	var frames: int = 0
	var step: float = speed / 60.0
	while idx < ids.size() and frames < 3000 and changes.is_empty():
		var tgt: Vector2 = a.cell_to_global(ids[idx])
		var d: Vector2 = tgt - body.global_position
		if Iso.to_ground(d).length() < 30.0:
			idx += 1
			continue
		var gdir: Vector2 = Iso.to_ground(d).normalized()
		body.velocity = Iso.to_screen(gdir * speed)
		body.move_and_slide()
		await t.physics(1)
		frames += 1
	var fired_at: int = frames
	# stand in the warp for half a second: it fires on body_entered, once
	body.velocity = Vector2.ZERO
	await t.physics(30)
	bus.area_change_requested.disconnect(cb)
	for c2 in muted:
		bus.area_change_requested.connect(c2)
	var walked: float = float(fired_at) / 60.0
	t.check("walk_door_to_bridge_end_fires_the_warp", changes == [["traetoppen", "from_farm"]] and fired_at <= WALK_FRAMES_MAX,
		"a real CharacterBody2D (25 x 14.8) walks from_home to the last plank in %d physics frames (%.1f s at %.0f px/s over a path of %d cells) and the Warp2D emits area_change_requested(traetoppen, from_farm) exactly once: %s" % [fired_at, walked, speed, ids.size(), changes])
	t.check("home_to_bridge_under_10s", l_bridge_14 > 0.0 and l_bridge_14 / speed < 10.0 and fired_at <= WALK_FRAMES_MAX and walked < 10.0,
		"%.0f ground px door-spawn to the warp = %.1f s walking, %.1f s running (450 px/s), the real body needed %.1f s (measured by the prototype: 2,715 px, 559 frames, 9.3 s)" % [l_bridge_14, l_bridge_14 / speed, l_bridge_14 / 450.0, walked])
	_info["walk_frames"] = fired_at
	body.queue_free()
	await t.physics(1)


# ================================================================== H. camera and HUD bands, lights, building slots

func _bands_and_budgets(t) -> void:
	var a: IsoArea = _a
	var cam: Rect2 = a.camera_rect()
	var bad: Array = []
	var closest: float = 1e9
	for rec in a.markers:
		var ty: String = str(rec["type"])
		if not (ty in INTERACTIVE_TYPES):
			continue
		var p: Vector2 = rec["pos"]
		var top: float = (p.y - cam.position.y) * Iso.DEFAULT_ZOOM
		var bottom: float = (cam.end.y - p.y) * Iso.DEFAULT_ZOOM
		var left: float = (p.x - cam.position.x) * Iso.DEFAULT_ZOOM
		var right: float = (cam.end.x - p.x) * Iso.DEFAULT_ZOOM
		closest = minf(closest, top)
		if top < float(HUD_BANDS["top"]) or bottom < float(HUD_BANDS["bottom"]) or left < float(HUD_BANDS["left"]) or right < float(HUD_BANDS["right"]):
			bad.append([ty, (rec["cell"] as Vector2i) - _door, snappedf(top, 1.0), snappedf(bottom, 1.0), snappedf(left, 1.0), snappedf(right, 1.0)])
	t.check("interactives_clear_of_hud_and_canopy_bands", bad.is_empty(), "every interactive marker keeps >= 140 / 70 / 90 / 90 screen px (zoom 0.4) from the top (canopy frame band) / bottom / left / right camera limit; the nearest to the top is %.0f px; violations %s" % [closest, bad])
	var markers_lights: int = _n("light")
	var posts: int = _count_props("lantern_post")
	var all_lights: Array[Node] = a.find_children("*", "PointLight2D", true, false)
	var scenery: Array = all_lights.filter(func(light):
		var parent: Node = light.get_parent()
		while parent != null and parent != a:
			if parent.is_in_group("player"):
				return false
			parent = parent.get_parent()
		return true)
	var lights := scenery.size()
	t.check("light_budget", posts + markers_lights == 11 and lights <= 12 and lights >= posts + markers_lights, "%d lantern posts + %d light markers; %d scenery lights (cap 12). Player lantern/ghost/burst effects have the aggregate canvas gate." % [posts, markers_lights, lights])
	t.check("canvas_light_budget_with_player", all_lights.size() <= 16, "%d total allocated lights including the player's three effects (canvas cap 16)" % all_lights.size())
	# ---- the footprints of the building slots, the greenhouse slot and the expansion zone hold no object char
	var slot_bad: Array = []
	for rec2 in _of("building_slot"):
		var type: String = str((rec2["params"] as Dictionary).get("type", ""))
		var fp: Vector2i = SLOT_FOOTPRINTS.get(type, Vector2i.ZERO)
		var fc: Vector2i = rec2["cell"]
		for c in _rect_cells(fc.x - fp.x + 1, fc.y - fp.y + 1, fc.x, fc.y):
			var g: String = _m.ground_at(c)
			if g in "#~=p" or (_m.object_at(c) != "." and c != fc):
				slot_bad.append([type, c - _door, g, _m.object_at(c)])
	var gh: Vector2i = _cell_of("greenhouse_slot")
	for c2 in _rect_cells(gh.x - 3, gh.y - 2, gh.x, gh.y):
		if _m.ground_at(c2) in "#~=p" or (_m.object_at(c2) != "." and c2 != gh):
			slot_bad.append(["greenhouse", c2 - _door])
	var ex_bad: int = 0
	var problems: Array[String] = []
	for c3 in IsoArea.parse_cells(str((_of("field_expansion")[0]["params"] as Dictionary).get("cells", "")), Vector2i(_m.width, _m.height), problems):
		if _m.object_at(c3) != ".":
			ex_bad += 1
	t.check("building_slot_footprints_free", slot_bad.is_empty() and ex_bad == 0, "coop 3x2, barn 4x3, animal house 3x2 and the greenhouse 4x3 stand on plain ground with no object char but their own marker; the 42 expansion cells hold none; findings %s" % [slot_bad.slice(0, 4)])
	var pr: Rect2 = a.play_rect
	t.check("grid_budget", _m.width == 61 and _m.height == 51 and absf(pr.size.x - 3520.0) < 4.0 and absf(pr.size.y - 3382.0) < 4.0,
		"play rect %.0f x %.0f px = %.2f x %.2f screens at zoom 0.4 (budget 3,520 x 3,382 = 1.10 x 1.88)" % [pr.size.x, pr.size.y, pr.size.x / 3200.0, pr.size.y / 1800.0])
	t.check("area_switch_fade_budget", is_equal_approx(WorldRoot2D.FADE_OUT + WorldRoot2D.FADE_IN, 0.47), "fade out %.2f + fade in %.2f s = 0.47 s, unchanged by the bigger map" % [WorldRoot2D.FADE_OUT, WorldRoot2D.FADE_IN])


func _count_nodes(n: Node, class_filter: String = "") -> int:
	var c: int = 1 if (class_filter == "" or n.is_class(class_filter)) else 0
	for ch in n.get_children():
		c += _count_nodes(ch, class_filter)
	return c


# ================================================================== I. the expansion through the PUBLIC IsoArea API only

func _expansion(t) -> void:
	var a: IsoArea = _a
	var zones: Dictionary = _standins.get("zones", {})
	var ropes: Dictionary = _standins.get("ropes", {})
	var cells: Array = zones.get("east", [])
	var rope_nodes: Array = ropes.get("east", [])
	if cells.is_empty():
		# a real handler (N02) built the zone: ask the map itself
		var problems: Array[String] = []
		cells = IsoArea.parse_cells(str((_of("field_expansion")[0]["params"] as Dictionary).get("cells", "")), Vector2i(_m.width, _m.height), problems)
	var props_before: int = a.prop_nodes.size()
	var farmable_before: int = a.farmable.size()
	var none_farmable_before: bool = true
	for c in cells:
		none_farmable_before = none_farmable_before and not a.is_farmable(c)
	ArtCatalog.terrain(Standins.FIELD_LOOK)                    # the placeholder of the look is painted once; the unlock is timed warm
	var t0: int = Time.get_ticks_usec()
	var n: int = Standins.unlock(a, cells, rope_nodes)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	await t.physics(2)
	var f_now: bool = true
	var look: bool = true
	for c2 in cells:
		f_now = f_now and a.map.ground_at(c2) == "f" and a.is_farmable(c2)
		look = look and a.cell_kind(c2) == Standins.FIELD_LOOK
	var src: String = FileAccess.get_file_as_string(STANDINS_PATH)
	var rx := RegEx.new()
	rx.compile("\\barea\\._[a-z]")
	var private_access: bool = rx.search(src) != null
	var removed: bool = rope_nodes.is_empty() or a.prop_nodes.size() == props_before - rope_nodes.size()
	t.check("expansion_unlock_public_api", cells.size() == 42 and none_farmable_before and farmable_before == 84 and n == 42 and a.farmable.size() == 126 and f_now and look and removed and not private_access and ms < 60.0,
		"%d cells unlocked in %.1f ms (budget 4.5 ms measured by the prototype, test limit 60): map ground `f`, area.farmable 84 -> %d, terrain field_grass, %d rope props removed with remove_prop; the recipe touches no private member of IsoArea (P04 needs no edit): %s" % [n, ms, a.farmable.size(), rope_nodes.size(), "ok" if not private_access else "ACCESSES A PRIVATE MEMBER"])
	_info["unlock_ms"] = ms
	# the field look on every plot (what FarmView.setup will do) costs one set_terrain per cell
	var t1: int = Time.get_ticks_usec()
	var looked: int = Standins.apply_field_look(a)
	var look_ms: float = float(Time.get_ticks_usec() - t1) / 1000.0
	t.check("field_look_on_all_plots", looked == 126, "%d plots wear the untilled field_grass look in %.1f ms (P06's FarmView does this; the +36 draw calls of the look are part of the 502 budget)" % [looked, look_ms])


# ================================================================== J. art

func _art(t) -> void:
	# the gameplay rows of the props the map names (P22's lua/config/props_extra.lua): footprints as authored, the orchard trunk is solid
	var row_problems: Array = []
	for id in ASSUMED_FOOTPRINTS:
		var def: Dictionary = GameData.prop_def(String(id))
		if def.is_empty():
			row_problems.append("%s has no row" % id)
		elif GameData.footprint_of(String(id)) != ASSUMED_FOOTPRINTS[id]:
			row_problems.append("%s footprint %s, the map assumes %s" % [id, GameData.footprint_of(String(id)), ASSUMED_FOOTPRINTS[id]])
	if str(GameData.dict_of(GameData.prop_def("trunk_giant_b").get("solid", {})).get("shape", "none")) != "footprint":
		row_problems.append("trunk_giant_b is not solid (the orchard trunk must block)")
	if row_problems.is_empty():
		t.check("props_extra_rows_the_map_relies_on", true, "%d props have the footprints the map is authored against; the orchard trunk trunk_giant_b is solid" % ASSUMED_FOOTPRINTS.size())
	else:
		t.skip("maps_farm.props_extra_rows_the_map_relies_on: %s (lua/config/props_extra.lua is P22's)" % [row_problems])
	# ArtCatalog caches its placeholders (missing() only lists the FIRST request of an id), so ask each entry whether it is real art
	var named: Dictionary = {}
	for art in _props_by_art:
		named[str(art)] = true
	for ty in _by_type:
		if str(ty) == "dress":
			continue                                 # the dress props are N06's (EXTENDED) and are not part of art_complete
		for rec in (_by_type[ty] as Array):
			var pid: String = str((rec["params"] as Dictionary).get("prop", ""))
			if pid != "":
				named[pid] = true
	for pid2 in HANDLER_PROPS:
		named[pid2] = true
	var missing: Array[String] = []
	for pid3 in named:
		if not bool(ArtCatalog.prop(StringName(str(pid3))).get("real", false)):
			missing.append("prop:%s" % pid3)
	for tid in MAP_TERRAINS:
		if not bool(ArtCatalog.terrain(StringName(tid)).get("real", false)):
			missing.append("terrain:%s" % tid)
	if not bool(ArtCatalog.backdrop(&"farm").get("real", false)):
		missing.append("backdrop:farm")
	missing.sort()
	var n03: Array = []
	var p22: Array = []
	for id in missing:
		if id in N03_IDS:
			n03.append(id)
		else:
			p22.append(id)
	if missing.is_empty():
		t.check("art_complete", true, "every prop, terrain and backdrop the farm names has real art (%d props named)" % named.size())
	else:
		t.skip("maps_farm.art_complete: %d of %d named art ids are still P04 placeholders; N03 (wave 5) owns %s, P22 owns %s; strict in N08 / P27" % [missing.size(), named.size() + MAP_TERRAINS.size() + 1, n03, p22])
	_info["missing_art"] = missing


# ================================================================== K. performance of the build

func _performance(t) -> void:
	var host := Node2D.new()
	host.name = "FarmBuildHost"
	t.root.add_child(host)
	var ms_list: Array = []
	var node_count: int = 0
	for i in 5:
		var t2: int = Time.get_ticks_usec()
		var m2: AreaMap = AreaMap.load_file(MAP_PATH)
		var ar := IsoArea.new()
		host.add_child(ar)
		ar.setup(m2)
		ms_list.append(snappedf(float(Time.get_ticks_usec() - t2) / 1000.0, 0.1))
		if i == 4:
			node_count = _count_nodes(ar)
		ar.queue_free()
		await t.frames(1)
	host.queue_free()
	var best: float = 1e9
	for v in ms_list:
		best = minf(best, float(v))
	var fa: IsoArea = _a
	t.info("the live farm: %d nodes under the area, %d prop sprites, %d skirt pieces, %d colliders, %d PointLights (prototype with its stand-ins: 496 / 124 / 111 / 76 / 11)" % [_count_nodes(fa), fa.prop_nodes.size(), fa.skirt_nodes.size(), fa.colliders.get_child_count(), _count_nodes(fa, "PointLight2D")])
	t.check("build_budget", best < 60.0 and node_count <= 700, "rebuild ms of 5 builds %s: the MINIMUM %.1f ms < 60 (prototype: 20.4-20.9 quiet, 41.4-47.4 loaded); %d nodes in one area (budget 700, prototype 496)" % [ms_list, best, node_count])
	# parked round trip: leave to the fixture and come back (the iso area stays alive in the cache)
	_world._enter(&"_fixture_iso", &"default")
	await t.physics(1)
	var trips: Array = []
	for k in 3:
		var t3: int = Time.get_ticks_usec()
		_world._enter(&"farm", &"default")
		trips.append(snappedf(float(Time.get_ticks_usec() - t3) / 1000.0, 0.01))
		await t.physics(1)
		_world._enter(&"_fixture_iso", &"default")
		await t.physics(1)
	_world._enter(&"farm", &"default")
	var best_trip: float = 1e9
	for v2 in trips:
		best_trip = minf(best_trip, float(v2))
	t.check("parked_round_trip", best_trip < 5.0 and _world.area.map.id == &"farm", "coming back to the parked farm: %s ms, the minimum %.2f ms < 5 (prototype: 0.66-1.6 ms)" % [trips, best_trip])


# ================================================================== K2. the end of the bridge (the milestone's walk from the farm into Traetoppen)

## Without `traetoppen.map` (V4) the warp at the end of the bridge is quiet: the world stays on the farm, nothing breaks. With it, the round trip
## farm -> traetoppen:from_farm -> farm:from_traetoppen lands on both arrival spawns and never bounces (no spawn lies inside a warp diamond).
func _bridge_and_the_city(t) -> void:
	var bus: Node = t.autoload("EventBus")
	_world._enter(&"farm", &"default")
	await t.physics(1)
	if not WorldRoot2D.has_area(&"traetoppen"):
		_world.last_travel_error = ""
		bus.area_change_requested.emit(&"traetoppen", &"from_farm")
		await t.seconds(0.4)
		t.check("bridge_end_without_the_city_is_quiet", _world.area.map.id == &"farm" and _world.last_travel_error.begins_with("no such area") and not _world.traveling,
			"the warp fires area_change_requested(traetoppen, from_farm) while data/maps/traetoppen.map does not exist: the world stays on the farm (last_travel_error '%s'), no fade is left running, no engine message" % _world.last_travel_error)
		t.skip("maps_farm.bridge_round_trip_with_the_city: data/maps/traetoppen.map does not exist yet (V4 builds the treetop city; its arrival spawn `from_farm` and its warp back to farm:from_traetoppen are checked here as soon as it does)")
		return
	var seen: Array = []
	var cb := func(area_id: StringName, spawn_name: StringName) -> void: seen.append([String(area_id), String(spawn_name)])
	bus.area_change_requested.connect(cb)
	await _world.travel(&"traetoppen", &"from_farm")
	var in_city: bool = _world.area.map.id == &"traetoppen"
	var arrival: Vector2 = _world.area.get_spawn("from_farm")
	await t.seconds(1.0)
	var arrived_ok: bool = in_city and _world.player.global_position.distance_to(arrival) < 4.0
	await _world.travel(&"farm", &"from_traetoppen")
	var back: Vector2 = _world.area.get_spawn("from_traetoppen")
	await t.seconds(1.0)
	bus.area_change_requested.disconnect(cb)
	var back_ok: bool = _world.area.map.id == &"farm" and _world.player.global_position.distance_to(back) < 4.0
	t.check("bridge_round_trip_with_the_city", arrived_ok and back_ok and seen.is_empty(),
		"farm -> traetoppen:from_farm (in the city %s, at the spawn %s) -> farm:from_traetoppen (back on the farm %s, at the spawn %s); requests made by an arrival (a bounce): %s" % [in_city, arrived_ok, _world.area.map.id == &"farm", back_ok, seen])


# ================================================================== L. the offline tool

func _tool_selftest(t) -> void:
	var root: String = ProjectSettings.globalize_path("res://")
	var py: String = root + "tools/art/.venv/bin/python"
	if not FileAccess.file_exists("res://tools/art/.venv/bin/python"):
		py = "python3"
	var plain: Dictionary = t.run_tool(py, PackedStringArray(["-I", root + CHECKER, root + "data/maps/farm.map"]))
	t.check("offline_checker_passes_on_the_map", int(plain["code"]) == 0, "python %s data/maps/farm.map: exit %s, %s" % [CHECKER, plain["code"], (plain["lines"] as PackedStringArray)[-1] if not (plain["lines"] as PackedStringArray).is_empty() else ""])
	var res: Dictionary = t.run_tool(py, PackedStringArray(["-I", root + CHECKER, "--selftest"]))
	var ids: Dictionary = t.parse_tool_ids(res)
	var caught: int = 0
	for line in (res["lines"] as PackedStringArray):
		if str(line).contains(": CAUGHT"):
			caught += 1
	t.check("farm_map_tool.selftest_catches_eight_mutants", int(res["code"]) == 0 and caught == 8 and "farm_map_tool.selftest_catches_eight_mutants" in (ids["pass"] as Array) and (ids["fail"] as Array).is_empty(),
		"`%s --selftest`: exit %s, baseline clean, %d of 8 mutants caught (E1 cells in the reserve, 83 f cells, spawn from_home removed, a gap in the bridge, a growth marker on the wrong row, a post renamed, the town anchor missing, a Skovport lift marker back)" % [CHECKER, res["code"], caught])
	var gen: Dictionary = t.run_tool(py, PackedStringArray(["-I", root + "tools/farm/farm_map_gen.py", "--check", root + "data/maps/farm.map"]))
	t.info("farm_map_gen.py --check: %s" % (gen["lines"] as PackedStringArray)[0] if not (gen["lines"] as PackedStringArray).is_empty() else "no output")


# ================================================================== cleanup

func _cleanup(t) -> void:
	# leave the world on a pristine farm for the sections that follow
	_world.rebuild_current_area()
	await t.physics(1)
	if _info.has("missing_art"):
		t.info("placeholders still on the farm: %s" % [_info["missing_art"]])


# ================================================================== windowed (real window: the budgets in the engine that draws)

func run_windowed(t) -> void:
	if not await t.start_world():
		return
	_t = t
	_world = t.world()
	_world.warm_in_headless = true
	await _world.warm_clips()
	_m = AreaMap.load_file(MAP_PATH)
	_scan(_m)
	_door = _cell_of("home")
	await _fresh_area(t)
	var a: IsoArea = _a
	var p: Node2D = _world.player
	var cam: Camera2D = p.get("camera")
	Standins.apply_field_look(a)
	_world.day_night.override_hour = 11.0
	_world.day_night.snap()
	a.set_night_factor(_world.day_night.glow_factor)
	var spawn_cell: Vector2i = a.global_to_cell(a.spawns["default"])
	var house: Node2D = Standins.place_home(a, 1, _door, true, false)
	# draw calls of the farm in a real window (the y-sorted Ground layer is ~390 of them; the field look costs +36), noon and night (lights + halos)
	var budgets := {0.4: 560, 0.3: 640, 0.2: 780}
	# These map-prototype draw budgets predate the shared HUD. The I2 budget
	# section records both area and full-screen costs with the current HUD.
	var hud_visible: bool = _world.game_ui.visible
	_world.game_ui.hide()
	for z in [0.4, 0.3, 0.2]:
		var per_hour: Array = []
		for hour in [11.0, 22.0]:
			_world.day_night.override_hour = hour
			_world.day_night.snap()
			a.set_night_factor(_world.day_night.glow_factor)
			p.global_position = a.cell_to_global(spawn_cell + Vector2i(0, 4))
			cam.zoom = Vector2.ONE * float(z)
			cam.reset_smoothing()
			await t.seconds(0.8)
			var mx: int = 0
			for i in 40:
				await t.frames(1)
				mx = maxi(mx, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			per_hour.append(mx)
			if hour == 11.0:
				await t.capture("farm_zoom_%d" % int(float(z) * 100.0))
		t.check("windowed_draw_calls_zoom_%d" % int(float(z) * 100.0), int(per_hour[0]) <= int(budgets[z]) and int(per_hour[1]) <= int(budgets[z]), "%d draw calls at noon and %d at night at zoom %.1f (budget %d; the prototype measured 502-524 / 597 / 723 with the real art; process time is measured by tools/farm/farm_shot.tscn --part=perf, not here)" % [int(per_hour[0]), int(per_hour[1]), z, int(budgets[z])])
	_world.game_ui.visible = hud_visible
	_world.day_night.override_hour = 11.0
	_world.day_night.snap()
	a.set_night_factor(_world.day_night.glow_factor)
	var tex_mb: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	t.check("windowed_texture_memory", tex_mb <= 130.0, "%.1f MB of textures in use (budget 130, prototype 100.0 / 105.7 with the real art)" % tex_mb)
	cam.zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
	p.global_position = a.cell_to_global(spawn_cell)
	cam.reset_smoothing()
	await t.seconds(0.6)
	var img2: Image = await t.capture("farm_morning_start")
	var ct: Transform2D = _world.get_viewport().get_canvas_transform()
	var ground_px: Vector2i = Vector2i(ct * a.cell_to_global(spawn_cell + Vector2i(4, 1)))
	var sky_px := Vector2i(1240, 60)
	t.expect_not_clear(img2, ground_px, "maps_farm.render_not_blank the deck beside the spawn %s is drawn" % ground_px)
	t.expect_not_blank(img2, Rect2i(320, 140, 640, 420), "maps_farm.render_not_blank the farm is not a flat fill")
	t.expect_differs(img2, ground_px, sky_px, 12.0, "maps_farm.render_not_blank the deck differs from the sky/canopy corner")
	t.check("render_not_blank", true, "see the three expectations above")
	house.queue_free()
	await _cleanup(t)
