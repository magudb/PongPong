extends RefCounted
## Section maps_iso (package P11-maps-iso): the isometric / grid maps this package owns - HYGGEBYEN (data/maps/hyggebyen.map, the fairy shopping
## district, zone id `city`) and SKOVKANTEN, the hub of Moerkeskoven (data/maps/moerkeskoven.map, hand-authored ortho map) - on the REAL area
## framework (IsoArea, WorldRoot2D, Warp2D, the colliders of lua/config/props*.lua) plus the strings of localization/areas.csv.
##
## The farm (data/maps/farm.map) is N01's since the towns carve-out (RT12): its halves of this section (home_reserve_on_deck_after_growth,
## spawn_from_home_walkable, feature_markers_match_json of the farm entry, farm_warp_graph, farm_mailbox_marker, no_warp_to_removed_forest_areas,
## wake_spawn_from_home_walkable) live in tests/sections/maps_farm.gd under the prefix maps_farm.; `farm_checks_moved_to_maps_farm` below proves
## that and `hyggebyen_checks_unchanged` proves that nothing of the Hyggebyen half got lost.
##
## Named checks (maps_iso.<name>):
##   files       parse_no_errors, headers, rows_equal_width, no_unknown_chars, markers_resolve, npc_ids_exist, props_are_defined_and_drawable,
##               prop_footprints_fit_the_ground
##   graph       warp_targets_and_spawns, warp_roundtrips, no_warp_to_removed_forest_areas, warp_graph_pending_areas (with a self-test of the resolver),
##               hyggebyen_warp_graph, spawns_outside_warps
##   town        town_markers_present, doors_on_the_doorstep, door_arrival_cells_free, posts_on_free_cells, fest_set_cells_free,
##               feature_markers_match_json, feature_npcs_and_stalls, hyggebyen_is_filled, light_budget
##   strings     areas_csv_rows, loc_check_maps_clean
##   physics     connectivity (flood fill / A* on a grid baked from the REAL colliders, body x1.4 and x1.15), rim_blocks_the_body, spawn_to_warp_paths,
##               door_triggers_can_be_entered (Warp2D diamonds on the 14 doorsteps, a real body walks into each), walk_bridge_end_fires_the_warp
##   hub         hub_parses_and_connects, hub_spawns_reach_the_warps, hub_has_one_gate_to_the_skovlift, hub_rim_is_void
##   world       world_enters_the_areas, build_budget
##   art / meta  art_complete (SKIP until P22's art exists and while it is incomplete, strict in P27 through ART_STRICT), farm_checks_moved_to_maps_farm,
##               hyggebyen_checks_unchanged; windowed (run_windowed): both maps render by day and night, six screenshots.
##
## What is NOT asserted here, and why: the handlers of the markers belong to later packages (npc P14, door / post / town the towns director,
## unique_spot F4, runestone D2, forest_dress V8, whisper P19). Until they land those markers are skipped silently by IsoArea and stay readable
## through find_markers(): this section lists them (SKIP lines naming the owner) and proves the MAP side of every contract.

const SECTION := "maps_iso"
const TIMEOUT_S := 300.0

const HYG_PATH := "res://data/maps/hyggebyen.map"
const HUB_PATH := "res://data/maps/moerkeskoven.map"
const AREAS_CSV := "res://localization/areas.csv"
const MARKERS_JSON := "res://data/features/map_markers.json"
const MAPS_FARM_SECTION := "res://tests/sections/maps_farm.gd"
const ART_MANIFEST := "res://assets/iso_props/props.json"

## Warp targets other packages build: V4 closes `traetoppen` (the treetop city, wave 5b; its city_map.every_warp_round_trips makes the edge strict, V10
## re-checks the whole graph). A pending area stops being pending the moment its map exists: then the target and its spawn must resolve like any other.
const PENDING_AREAS: Array[String] = ["traetoppen"]
## Floors of the dungeon are generated and registered at run time (D2): their ids never exist at boot.
const GENERATED_PREFIX := "moerkeskoven_f"
## The four hand-authored forest maps of the first plan are the four BANDS of the dungeon now: no map of this package names them any more.
const REMOVED_FOREST_AREAS: Array[String] = ["skovkant", "dybe_bregner", "svampelunden", "krystalgrotten"]
## Translation keys a LATER package defines (V1 core.csv): a map may already name them, loc_check reports them MISS until then.
const PENDING_KEYS := {"ZONE_TRAETOPPEN": "V1-cast-data (core.csv, stage 2 of milestone 1a)"}
## NPC rows a later package adds to lua/config/npcs.lua.
const PENDING_NPCS := {"beekeeper_birk": "V1-cast-data (npcs.lua row, stage 2 of milestone 1a)"}

## Marker types of these two maps and who builds them. `builtin` = IsoArea itself; the others are skipped silently until their handler script exists.
const MARKER_OWNERS := {
	"spawn": "builtin", "warp": "builtin", "sign": "builtin", "light": "builtin", "quest_spot": "builtin",
	"npc": "P14-npc-dialogue (npc_2d.gd)", "unique_spot": "F4-loot-shops (marker handler)", "town": "T-director", "door": "T-director", "post": "T-director",
	"runestone": "D2-dungeon-floors (runestone_2d.gd)", "whisper": "P19-forest-combat (whisper_zone.gd)", "forest_dress": "V8-forest-look",
}

## The 14 doors of the towns addendum 4.1 (Hyggebyen half): building id -> the shop / role it houses.
const BUILDINGS: Array[String] = ["froebutikken", "bageriet", "smedjen", "troldmandstaarnet", "moebelbutikken", "skraedderiet", "toemmerhandlen",
	"dyrehuset", "loppeloftet", "fekongens_hus", "hyldeblomsts_hus", "pippins_hus", "birks_bistade", "pingvinens_hus"]
## The 24 named posts of the draft (act and cap as in the draft): name -> [act, cap].
const POSTS := {
	"torv_fountain_n": ["sit", 2], "torv_fountain_e": ["sit", 2], "torv_fountain_s": ["sit", 2], "torv_fountain_w": ["sit", 2],
	"torv_bench1": ["sit", 3], "torv_bench2": ["sit", 3], "torv_playground": ["play", 4], "well": ["stand", 2],
	"blossom_bench1": ["sit", 3], "blossom_bench2": ["sit", 3], "bakery_terrace": ["sit", 2], "forge_front": ["work", 1],
	"pond_dock": ["fish", 2], "bees1": ["tend", 1], "bees2": ["tend", 1], "rosa_pen": ["tend", 1],
	"market_row1": ["stand", 2], "market_row2": ["stand", 2], "market_row3": ["stand", 2], "king_balcony": ["sit", 1],
	"round_n": ["patrol", 1], "round_e": ["patrol", 1], "round_s": ["patrol", 1], "round_w": ["patrol", 1],
}
## The offsets of the festival post set of ONE `post set=fest` marker (towns addendum 4.3): host, judge, 4 stalls, 2 tables, 16 gather cells.
const FEST_OFFSETS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-4, -2), Vector2i(-2, -2), Vector2i(2, -2), Vector2i(4, -2),
	Vector2i(-3, 1), Vector2i(3, 1)]
## NPC markers Hyggebyen carries (roster of PLAN 3.8 + the feature fairies of the feature addendum + the v2 cast): `guard_oak` is NOT among them
## (he stands at the Skovlift of the city, decision DX2), the mayor lives here and works at the Raadhus of Traetoppen (DT-addendum 4.1).
const NPC_IDS: Array[String] = ["mayor_lyra", "baker_maja", "merchant_pip", "pippin_boegeknop", "fairy_king", "fairy_lily", "smith_thorin", "farmer_rosa",
	"fairy_wizard", "penguin_postman", "fairy_builder", "fairy_furnisher", "fairy_tailor", "beekeeper_birk", "cat_morfar_mis"]
const BODY := Vector2(25.0, 14.8)                                   # the player's collision ellipse in ground px (plan 3.3)
const WALK_FRAMES_MAX := 900

## The prop ids that make Hyggebyen a town (counts are minimums: the blueprint's fill list of review R.10 / task 6).
const FILL_MINIMUMS := {"houses": 14, "lanterns": 6, "stalls": 3, "blossom_trees": 12, "signs": 6, "benches": 3, "fountains": 1, "wells": 1}
const MAX_MAP_LIGHTS := 12
const ART_STRICT := false                                           # P27 flips this: incomplete P22 art is a failure, not a SKIP

var _t
var _world: Node2D
var _hyg: AreaMap
var _hub: AreaMap
var _hs: Dictionary = {}                # scan of hyggebyen
var _us: Dictionary = {}                # scan of the hub
var _a: IsoArea
var _astar: AStarGrid2D
var _info: Dictionary = {}


func run(t) -> void:
	_t = t
	_hyg = AreaMap.load_file(HYG_PATH)
	_hub = AreaMap.load_file(HUB_PATH)
	if _hyg == null or _hub == null:
		t.fail("maps_iso needs data/maps/hyggebyen.map and data/maps/moerkeskoven.map: %s" % AreaMap.last_error)
		return
	_hs = _scan(_hyg)
	_us = _scan(_hub)
	if not await t.start_world():
		return
	_world = t.world()
	_files(t)
	_markers_and_npcs(t)
	_props_and_footprints(t)
	_graph(t)
	_town(t)
	_features(t)
	_fill_and_lights(t)
	_strings(t)
	await _physics_connectivity(t)
	await _hub_checks(t)
	await _world_and_budget(t)
	await _art(t)
	_meta(t)
	await _cleanup(t)


# ================================================================== scan helpers (the file, not the live area)

## Walks the object rows of a map: markers by type, props by art id and front cell, undeclared chars, the default spawn.
func _scan(m: AreaMap) -> Dictionary:
	var by_type: Dictionary = {}
	var props_by_art: Dictionary = {}
	var prop_front: Dictionary = {}      # Vector2i -> art id (the object-row props)
	var undeclared: Array = []
	var default_cell := Vector2i(-1, -1)
	var marker_at: Dictionary = {}       # Vector2i -> {type, params, ch, cell}
	for y in m.height:
		var row: String = m.objects[y]
		for x in m.width:
			var ch: String = row[x]
			if ch == ".":
				continue
			var c := Vector2i(x, y)
			if ch == "@":
				default_cell = c
			elif m.markers.has(ch):
				var d: Dictionary = m.markers[ch]
				var rec := {"type": str(d["marker"]), "params": d, "ch": ch, "cell": c}
				if not by_type.has(rec["type"]):
					by_type[rec["type"]] = []
				(by_type[rec["type"]] as Array).append(rec)
				marker_at[c] = rec
			elif m.props.has(ch):
				var art: String = str(m.props[ch]["prop"])
				if not props_by_art.has(art):
					props_by_art[art] = []
				(props_by_art[art] as Array).append(c)
				prop_front[c] = art
			else:
				undeclared.append([ch, c])
	return {"by_type": by_type, "props_by_art": props_by_art, "prop_front": prop_front, "undeclared": undeclared, "default": default_cell, "marker_at": marker_at}


func _of(s: Dictionary, type: String) -> Array:
	return (s["by_type"] as Dictionary).get(type, []) as Array


func _count_of(s: Dictionary, type: String) -> int:
	return _of(s, type).size()


func _props_n(s: Dictionary, art: String) -> int:
	return ((s["props_by_art"] as Dictionary).get(art, []) as Array).size()


func _props_matching(s: Dictionary, prefix: String) -> int:
	var n: int = 0
	for art in (s["props_by_art"] as Dictionary):
		if str(art).begins_with(prefix):
			n += ((s["props_by_art"] as Dictionary)[art] as Array).size()
	return n


## Every prop that stands on the map: the object-row props plus the ones markers place at their own cell (warp / sign / quest_spot `prop=`, the sign's
## default signpost). [{art, front, source}]
func _all_props(m: AreaMap, s: Dictionary) -> Array:
	var out: Array = []
	for c in (s["prop_front"] as Dictionary):
		out.append({"art": str((s["prop_front"] as Dictionary)[c]), "front": c, "source": "row"})
	for type in ["warp", "sign", "quest_spot"]:
		for rec in _of(s, type):
			var p: Dictionary = rec["params"]
			var art: String = str(p.get("prop", "signpost" if type == "sign" else ""))
			if art != "":
				out.append({"art": art, "front": rec["cell"], "source": type})
	return out


func _footprint_cells(m: AreaMap, art: String, front: Vector2i) -> Array[Vector2i]:
	if not m.is_iso():
		return [front]                       # IsoArea.place_prop ignores the footprint in ortho areas
	var fp: Vector2i = GameData.footprint_of(art)
	var out: Array[Vector2i] = []
	for dy in fp.y:
		for dx in fp.x:
			out.append(Vector2i(front.x - dx, front.y - dy))
	return out


func _is_solid(art: String) -> bool:
	return str(GameData.dict_of(GameData.prop_def(art).get("solid", {})).get("shape", "none")) != "none"


## Rows of the raw file: the @ground and @objects blocks, to prove they are one rectangle (AreaMap pads short rows silently).
func _raw_rows(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var section: String = ""
	var g: Array[int] = []
	var o: Array[int] = []
	for raw in text.split("\n"):
		var line: String = raw.trim_suffix("\r")
		if line.begins_with("@ground"):
			section = "g"
			continue
		if line.begins_with("@objects"):
			section = "o"
			continue
		if section == "g" and line != "":
			g.append(line.length())
		elif section == "o" and line != "":
			o.append(line.length())
	return {"g": g, "o": o}


func _rect_ok(rows: Array[int]) -> bool:
	if rows.is_empty():
		return false
	for n in rows:
		if n != rows[0]:
			return false
	return true


func _text_of(key: String, locale: String) -> String:
	var lm: Node = _t.autoload("LocalizationManager")
	return str(lm.call("text_in", key, locale)) if lm != null else ""


func _has_key(key: String) -> bool:
	var lm: Node = _t.autoload("LocalizationManager")
	return lm != null and bool(lm.call("has_key", key))


# ================================================================== A. the files

func _files(t) -> void:
	var hyg_live: IsoArea = _make_area(_hyg)
	var hub_live: IsoArea = _make_area(_hub)
	var hyg: AreaMap = _hyg
	var hub: AreaMap = _hub
	t.check("parse_no_errors", hyg.errors.is_empty() and hub.errors.is_empty() and hyg_live.map.errors.is_empty() and hub_live.map.errors.is_empty(),
		"file errors %s / %s, errors of the live areas after setup (default spawn, growth cells) %s / %s" % [hyg.errors, hub.errors, hyg_live.map.errors, hub_live.map.errors])
	t.check("headers", hyg.id == &"hyggebyen" and hyg.title == "ZONE_CITY" and hyg.projection == &"iso" and hyg.ambient == &"hyggebyen" and hyg.theme == &"hyggebyen" and hyg.zone == &"city" and hyg.flight_allowed and hyg.music == "city_theme" and hyg.builder == ""
		and hub.id == &"moerkeskoven" and hub.title == "ZONE_FOREST_EDGE" and hub.projection == &"ortho" and hub.ambient == &"forest" and hub.theme == &"forest" and hub.zone == &"dark_forest" and hub.depth == 0 and not hub.flight_allowed and hub.music == "forest_theme",
		"hyggebyen: %s %s %s %s zone %s flight %s music %s | hub: %s %s %s %s zone %s depth %d flight %s" % [hyg.id, hyg.title, hyg.projection, hyg.ambient, hyg.zone, hyg.flight_allowed, hyg.music, hub.id, hub.title, hub.projection, hub.ambient, hub.zone, hub.depth, hub.flight_allowed])
	var hr: Dictionary = _raw_rows(HYG_PATH)
	var ur: Dictionary = _raw_rows(HUB_PATH)
	var rect_ok: bool = _rect_ok(hr["g"]) and _rect_ok(hr["o"]) and (hr["g"] as Array).size() == (hr["o"] as Array).size() and (hr["g"] as Array)[0] == (hr["o"] as Array)[0]
	rect_ok = rect_ok and _rect_ok(ur["g"]) and _rect_ok(ur["o"]) and (ur["g"] as Array).size() == (ur["o"] as Array).size() and (ur["g"] as Array)[0] == (ur["o"] as Array)[0]
	t.check("rows_equal_width", rect_ok and hyg.width == 40 and hyg.height == 40,
		"hyggebyen %d x %d, hub %d x %d: every ground and object row of the raw files has the same length (the parser pads silently)" % [hyg.width, hyg.height, hub.width, hub.height])
	var unknown: Array = []
	unknown.append_array(_hs["undeclared"])
	unknown.append_array(_us["undeclared"])
	t.check("no_unknown_chars", unknown.is_empty() and hyg_live.unknown_chars.is_empty() and hub_live.unknown_chars.is_empty(),
		"every object char of both files is declared by @prop or @marker (or is the `@` default spawn) and every ground char is known to the builder: undeclared %s, area.unknown_chars %s / %s" % [unknown, hyg_live.unknown_chars, hub_live.unknown_chars])
	_free_holders()


## A standalone IsoArea of a map (not entered into the world): the structure checks and the build timing use it.
func _make_area(m: AreaMap) -> IsoArea:
	var holder := Node2D.new()
	_t.tree.root.add_child(holder)
	var a := IsoArea.new()
	holder.add_child(a)
	a.setup(AreaMap.load_file(m.path))
	_holders.append(holder)
	return a


var _holders: Array[Node2D] = []


func _free_holders() -> void:
	for h in _holders:
		if is_instance_valid(h):
			h.queue_free()
	_holders.clear()


# ================================================================== B. markers, npc ids

func _markers_and_npcs(t) -> void:
	var bad_types: Array = []
	var pending: Dictionary = {}
	var type_counts: Dictionary = {}
	for pair in [[_hs, "hyggebyen"], [_us, "moerkeskoven"]]:
		var s: Dictionary = pair[0]
		for ty in (s["by_type"] as Dictionary):
			if not MARKER_OWNERS.has(ty):
				bad_types.append([pair[1], ty])
			type_counts["%s:%s" % [pair[1], ty]] = _count_of(s, str(ty))
			var h: Dictionary = IsoArea.resolve_handler(str(ty))
			if MARKER_OWNERS.get(ty, "") != "builtin" and str(h["kind"]) == "none":
				pending[ty] = MARKER_OWNERS.get(ty, "?")
	# every declared marker / prop char is used (no dead @marker / @prop lines)
	var dead: Array = []
	for pair2 in [[_hyg, _hs], [_hub, _us]]:
		var m: AreaMap = pair2[0]
		var used: Dictionary = {}
		for y in m.height:
			for x in m.width:
				used[m.objects[y][x]] = true
		for ch in m.markers:
			if not used.has(ch) and ch != "@":
				dead.append([String(m.id), ch, "marker"])
		for ch2 in m.props:
			if not used.has(ch2):
				dead.append([String(m.id), ch2, "prop"])
	t.check("markers_resolve", bad_types.is_empty() and dead.is_empty(), "every marker type is one of %s; unknown types %s; declared-but-unused chars %s; counts %s" % [MARKER_OWNERS.keys(), bad_types, dead, type_counts])
	for ty2 in pending:
		t.skip("maps_iso.markers: type `%s` has no handler script yet (%s): skipped silently by IsoArea, stays readable through find_markers()" % [ty2, pending[ty2]])
	# ---- npc ids exist in npcs.lua (a pending row of a later package is a SKIP naming the package)
	var lua: Node = t.autoload("LuaRuntime")
	var missing: Array = []
	var pend_seen: Array = []
	var ids: Dictionary = {}
	for rec in _of(_hs, "npc"):
		var nid: String = str((rec["params"] as Dictionary).get("id", ""))
		ids[nid] = true
		var row: Dictionary = lua.call("get_npc", nid) if lua != null else {}
		if row.is_empty():
			if PENDING_NPCS.has(nid):
				pend_seen.append(nid)
			else:
				missing.append(nid)
	for rec2 in _of(_us, "npc"):
		missing.append("hub npc slot: %s" % str((rec2["params"] as Dictionary).get("id", "")))
	var want: Dictionary = {}
	for nid2 in NPC_IDS:
		want[nid2] = true
	var same: bool = ids.keys().size() == want.keys().size()
	for k in ids:
		same = same and want.has(k)
	t.check("npc_ids_exist", missing.is_empty() and same and not ids.has("guard_oak"), "%d npc markers %s: every id exists in lua/config/npcs.lua (pending rows %s), the roster is the expected one (no guard_oak: he stands at the Skovlift), the hub has no npc slot; missing %s" % [ids.size(), ids.keys(), pend_seen, missing])
	for nid3 in pend_seen:
		t.skip("maps_iso.npc_ids_exist: `%s` is not a row of lua/config/npcs.lua yet - %s" % [nid3, PENDING_NPCS[nid3]])


# ================================================================== C. props: defined, drawable, on the ground, not overlapping

func _props_and_footprints(t) -> void:
	var undefined: Array = []
	var undrawable: Array = []
	var arts: Dictionary = {}
	for pair in [[_hyg, _hs], [_hub, _us]]:
		for p in _all_props(pair[0] as AreaMap, pair[1] as Dictionary):
			arts[str(p["art"])] = true
	var defs: Array[String] = GameData.prop_ids()
	for art in arts:
		if not defs.has(str(art)):
			undefined.append(art)
		var d: Dictionary = ArtCatalog.prop(StringName(str(art)))
		if d.is_empty() or d.get("texture", null) == null:
			undrawable.append(art)
	t.check("props_are_defined_and_drawable", undefined.is_empty() and undrawable.is_empty(),
		"%d distinct prop ids: each is a row of lua/config/props.lua / props_extra.lua / props_features.lua (footprint, solid shape and strips are intentional, not the silent 1 x 1 default) and ArtCatalog answers a texture (real art or the placeholder); undefined %s, undrawable %s" % [arts.size(), undefined, undrawable])
	# ---- footprints on the ground, solid footprints never overlap each other or a marker
	var problems: Array = []
	for pair2 in [[_hyg, _hs, "hyggebyen"], [_hub, _us, "moerkeskoven"]]:
		var m: AreaMap = pair2[0]
		var s: Dictionary = pair2[1]
		var occ: Dictionary = {}
		var props: Array = _all_props(m, s)
		for p2 in props:
			var art2: String = str(p2["art"])
			var solid: bool = _is_solid(art2)
			for c in _footprint_cells(m, art2, p2["front"]):
				var g: String = m.ground_at(c)
				if m.is_iso():
					if g == "#" and art2 not in ["bridge_x", "bridge_z"]:
						problems.append("%s: %s footprint cell %s on void" % [pair2[2], art2, c])
					if solid and g == "~":
						problems.append("%s: solid %s footprint cell %s on water" % [pair2[2], art2, c])
				if solid:
					if occ.has(c):
						problems.append("%s: solid footprints overlap at %s (%s and %s)" % [pair2[2], c, occ[c], art2])
					occ[c] = art2
		# markers (not the ones that place their own prop) never stand inside a solid footprint
		for ty in (s["by_type"] as Dictionary):
			if m.is_iso():
				for rec in _of(s, str(ty)):
					var own: bool = false
					for p3 in props:
						if p3["front"] == rec["cell"] and p3["source"] != "row":
							own = true
					if occ.has(rec["cell"]) and not own and str(ty) not in ["light", "town"]:
						problems.append("%s: marker %s at %s inside the footprint of %s" % [pair2[2], ty, rec["cell"], occ[rec["cell"]]])
		if (s["default"] as Vector2i) != Vector2i(-1, -1) and occ.has(s["default"]):
			problems.append("%s: the default spawn lies inside the footprint of %s" % [pair2[2], occ[s["default"]]])
	t.check("prop_footprints_fit_the_ground", problems.is_empty(), "every footprint cell (2 x 2 houses, the 2 x 2 fountain, 2 x 1 stalls, 3 x 3 king's house ...) is on ground, no solid footprint overlaps another or a marker: %s" % [problems.slice(0, 6)])


# ================================================================== D. the warp graph

## Every warp of a map: [{to, spawn, label, cell, params, prop}].
func _warps(s: Dictionary) -> Array:
	var out: Array = []
	for rec in _of(s, "warp"):
		var p: Dictionary = rec["params"]
		out.append({"to": str(p.get("to", "")), "spawn": str(p.get("spawn", "default")), "label": str(p.get("label", "")), "cell": rec["cell"], "prop": str(p.get("prop", "")), "params": p})
	return out


## Is `id` still a pending area (named, not built yet)?
func _pending(id: String) -> bool:
	return PENDING_AREAS.has(id) and not WorldRoot2D.has_area(StringName(id))


## How a warp target resolves: "" = the area and its arrival spawn exist, "pending" = a named area whose map lands later, "generated" = a dungeon floor
## made at run time, anything else = the problem.
func _resolve_target(to: String, spawn: String) -> String:
	if to.begins_with(GENERATED_PREFIX):
		return "generated"
	if _pending(to):
		return "pending"
	if not WorldRoot2D.has_area(StringName(to)):
		return "no such area %s" % to
	var tm: AreaMap = WorldRoot2D.load_map(StringName(to))
	var names: Array[String] = _spawn_names(tm, _scan(tm))
	if not names.has(spawn):
		return "%s has no spawn %s (%s)" % [to, spawn, names]
	return ""


func _spawn_names(m: AreaMap, s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if (s["default"] as Vector2i) != Vector2i(-1, -1):
		out.append("default")
	for rec in _of(s, "spawn"):
		out.append(str((rec["params"] as Dictionary).get("name", "default")))
	return out


func _graph(t) -> void:
	var reg: Dictionary = WorldRoot2D.scan_maps(true)
	var real: Array[StringName] = WorldRoot2D.area_ids(false)
	# ---- every warp of every real map: the target exists (or is pending / generated) and its arrival spawn exists
	var bad: Array = []
	var skips: Array = []
	var trips: Array = []
	var removed: Array = []
	var checked: int = 0
	for id in real:
		var m: AreaMap = WorldRoot2D.load_map(id)
		if m == null:
			continue
		var s: Dictionary = _scan(m)
		for w in _warps(s):
			checked += 1
			var to: String = w["to"]
			if REMOVED_FOREST_AREAS.has(to):
				removed.append("%s -> %s" % [id, to])
			var verdict: String = _resolve_target(to, w["spawn"])
			if verdict == "generated":
				skips.append("%s -> %s:%s (generated floor, D2 registers it at run time)" % [id, to, w["spawn"]])
				continue
			if verdict == "pending":
				skips.append("%s -> %s:%s (pending area: its map lands with V4, whose city_map.every_warp_round_trips closes the edge)" % [id, to, w["spawn"]])
				continue
			if verdict != "":
				bad.append("%s -> %s" % [id, verdict])
				continue
			var tm: AreaMap = WorldRoot2D.load_map(StringName(to))
			# round trip: the target has a warp back to this area (the arrival spawn of that warp is checked on its own turn)
			var back: bool = false
			for w2 in _warps(_scan(tm)):
				if str(w2["to"]) == String(id):
					back = true
			if not back:
				trips.append("%s -> %s has no warp back" % [id, to])
	t.check("warp_targets_and_spawns", bad.is_empty() and checked >= 3, "%d warps of %d real maps: every target exists (or is pending / generated) and has the named arrival spawn; problems %s" % [checked, real.size(), bad])
	t.check("warp_roundtrips", trips.is_empty(), "every warp whose target exists has a warp back to its area; %s" % [trips])
	for sk in skips:
		t.skip("maps_iso.warp_roundtrips: %s" % sk)
	t.check("no_warp_to_removed_forest_areas", removed.is_empty() and not _mentions_removed(), "no map names %s any more (the forest is the dungeon behind the hub): %s" % [REMOVED_FOREST_AREAS, removed])
	var traetoppen_exists: bool = WorldRoot2D.has_area(&"traetoppen")
	var self_test: bool = _resolve_target("traetoppen", "from_farm") == ("" if traetoppen_exists else "pending") \
		and _resolve_target("moerkeskoven_f7", "default") == "generated" \
		and _resolve_target("no_such_area", "default").begins_with("no such area") \
		and _resolve_target("hyggebyen", "from_nowhere").contains("has no spawn") \
		and _resolve_target("hyggebyen", "from_traetoppen") == "" \
		and _resolve_target("skovkant", "default").begins_with("no such area")
	t.check("warp_graph_pending_areas", PENDING_AREAS == ["traetoppen"] and self_test,
		"PENDING_AREAS = %s; traetoppen.map %s -> the edge is %s; ids starting with `%s` are exempt (generated at run time); every other target must exist with its spawn: the resolver rejects an unknown area, an unknown spawn and the removed forest areas (self-test)" % [PENDING_AREAS, "exists" if traetoppen_exists else "does not exist yet", "strict" if traetoppen_exists else "pending", GENERATED_PREFIX])
	# ---- Hyggebyen's own graph
	var ws: Array = _warps(_hs)
	var w0: Dictionary = ws[0] if ws.size() == 1 else {}
	var warp_cell: Vector2i = w0.get("cell", Vector2i(-1, -1))
	var planks: int = 0
	for x in range(_hyg.width):
		if _hyg.ground_at(Vector2i(x, warp_cell.y)) == "=":
			planks += 1
	var last_plank: bool = _hyg.ground_at(warp_cell) == "=" and _hyg.is_void(warp_cell + Vector2i(1, 0)) and not _hyg.is_void(warp_cell - Vector2i(1, 0))
	var spawn_names: Array[String] = _spawn_names(_hyg, _hs)
	spawn_names.sort()
	var npcs_ids: Array = []
	for rec in _of(_hs, "npc"):
		npcs_ids.append(str((rec["params"] as Dictionary).get("id", "")))
	t.check("hyggebyen_warp_graph", ws.size() == 1 and w0.get("to") == "traetoppen" and w0.get("spawn") == "from_hyggebyen" and w0.get("label") == "ZONE_TRAETOPPEN"
		and warp_cell.x > _hyg.width / 2 and last_plank and planks >= 5 and spawn_names == ["default", "from_traetoppen"] and not npcs_ids.has("guard_oak")
		and _count_of(_hs, "door") == 14 and not _file_mentions(HYG_PATH, ["skovkant", "from_farm", "to=farm", "west gate", "mailbox"]),
		"ONE warp (the hanging bridge on the EAST side, %d plank cells in its row, the warp on the last plank at %s) to traetoppen:from_hyggebyen label ZONE_TRAETOPPEN; spawns %s; no farm bridge, no west gate, no Oak, no mailbox" % [planks, warp_cell, spawn_names])


func _mentions_removed() -> bool:
	return _file_mentions(HYG_PATH, REMOVED_FOREST_AREAS) or _file_mentions(HUB_PATH, REMOVED_FOREST_AREAS)


## Does a map file name one of the words in a header / marker line (comments are ignored)?
func _file_mentions(path: String, words: Array) -> bool:
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("#") or not line.begins_with("@") or line.begins_with("@ground") or line.begins_with("@objects"):
			continue
		for w in words:
			if line.contains(str(w)):
				return true
	return false


# ================================================================== E. the town markers of RT12 (draft D3/towns_scripts/proto/hyggebyen_draft.map)

func _town(t) -> void:
	var m: AreaMap = _hyg
	var s: Dictionary = _hs
	# ---- one `town`, 14 doors with the exact building ids, 24 named posts + the fest set, the spawn, the bridge warp
	var towns: int = _count_of(s, "town")
	var door_ids: Array = []
	for rec in _of(s, "door"):
		door_ids.append(str((rec["params"] as Dictionary).get("building", "")))
	var sorted_doors: Array = door_ids.duplicate()
	sorted_doors.sort()
	var want_doors: Array = BUILDINGS.duplicate()
	want_doors.sort()
	var post_names: Array = []
	var fest: int = 0
	var post_problems: Array = []
	for rec2 in _of(s, "post"):
		var p: Dictionary = rec2["params"]
		if str(p.get("set", "")) == "fest":
			fest += 1
			if str(p.get("spot", "")) != "hyggetorv":
				post_problems.append("fest spot %s" % p.get("spot"))
			continue
		var name: String = str(p.get("name", ""))
		post_names.append(name)
		if not POSTS.has(name):
			post_problems.append("unknown post %s" % name)
			continue
		if str(p.get("act", "stand")) != str((POSTS[name] as Array)[0]) or int(str(p.get("cap", "1"))) != int((POSTS[name] as Array)[1]):
			post_problems.append("%s act %s cap %s" % [name, p.get("act"), p.get("cap")])
	var sorted_posts: Array = post_names.duplicate()
	sorted_posts.sort()
	var want_posts: Array = POSTS.keys()
	want_posts.sort()
	var no_festival_decor: bool = _count_of(s, "dress") == 0
	var rathaus_here: bool = _file_mentions(HYG_PATH, ["raadhuset", "house_town_hall"])
	var from_t: bool = _spawn_names(m, s).has("from_traetoppen")
	t.check("town_markers_present", towns == 1 and sorted_doors == want_doors and sorted_posts == want_posts and post_problems.is_empty() and fest == 1 and from_t and _warps(s).size() == 1 and no_festival_decor and not rathaus_here,
		"%d `town` marker, %d `door` markers (%s), %d named posts (24 names, act and cap as in the draft) + %d `post set=fest spot=hyggetorv`, spawn from_traetoppen %s, the bridge warp is the gate (no extra marker), no festival decor markers, no Raadhus here; problems %s, doors %s vs %s" % [towns, door_ids.size(), "exact ids", post_names.size(), fest, from_t, post_problems, sorted_doors, want_doors])
	# ---- every door stands on the doorstep: the cell below the 2 x 2 (the king's 3 x 3) footprint of its house
	var step_bad: Array = []
	for rec3 in _of(s, "door"):
		var c: Vector2i = rec3["cell"]
		var front: Vector2i = c - Vector2i(0, 1)
		var art: String = str((s["prop_front"] as Dictionary).get(front, ""))
		var fp: Vector2i = GameData.footprint_of(art) if art != "" else Vector2i.ZERO
		var g: String = m.ground_at(c)
		if art == "" or fp.x < 2 or fp.y < 2 or not _is_solid(art) or not (g in "pcd,."):
			step_bad.append([(rec3["params"] as Dictionary).get("building"), c, art, fp, g])
	t.check("doors_on_the_doorstep", step_bad.is_empty() and _count_of(s, "door") == 14, "each of the 14 doors is on the walkable cell directly in front of (below) the front cell of a solid building of at least 2 x 2 cells; findings %s" % [step_bad])
	# ---- the arrival cell one cell further (from_int_<building>) is free ground
	var arr_bad: Array = []
	for rec4 in _of(s, "door"):
		var a_cell: Vector2i = (rec4["cell"] as Vector2i) + Vector2i(0, 1)
		var ga: String = m.ground_at(a_cell)
		if ga == "#" or ga == "~" or ga == "=" or (s["prop_front"] as Dictionary).has(a_cell) or (s["marker_at"] as Dictionary).has(a_cell):
			arr_bad.append([(rec4["params"] as Dictionary).get("building"), a_cell, ga])
	t.check("door_arrival_cells_free", arr_bad.is_empty(), "the cell one step in front of every doorstep (the arrival spawn from_int_<building> of the door handler) is free walkable ground: %s" % [arr_bad])
	# ---- posts and the fest set stand on free ground
	var solid_cells: Dictionary = {}
	for p4 in _all_props(m, s):
		if _is_solid(str(p4["art"])):
			for c4 in _footprint_cells(m, str(p4["art"]), p4["front"]):
				solid_cells[c4] = str(p4["art"])
	var post_bad: Array = []
	var seen_cells: Dictionary = {}
	for rec5 in _of(s, "post"):
		var pc: Vector2i = rec5["cell"]
		var gp: String = m.ground_at(pc)
		if str((rec5["params"] as Dictionary).get("set", "")) != "fest" and (gp == "#" or gp == "~" or solid_cells.has(pc)):
			post_bad.append([(rec5["params"] as Dictionary).get("name"), pc, gp, solid_cells.get(pc, "")])
	t.check("posts_on_free_cells", post_bad.is_empty(), "the 24 named posts stand on walkable cells outside every solid footprint (a post on a blocked cell would be moved by the director): %s" % [post_bad])
	var anchor: Vector2i = Vector2i(-1, -1)
	for rec6 in _of(s, "post"):
		if str((rec6["params"] as Dictionary).get("set", "")) == "fest":
			anchor = rec6["cell"]
	var fest_cells: Array[Vector2i] = []
	for off in FEST_OFFSETS:
		fest_cells.append(anchor + off)
	for k in 16:
		fest_cells.append(anchor + Vector2i((k % 4) - 1, 2 + k / 4))
	var fest_bad: Array = []
	for fc in fest_cells:
		var gf: String = m.ground_at(fc)
		if gf == "#" or gf == "~" or gf == "=" or solid_cells.has(fc):
			fest_bad.append([fc, gf, solid_cells.get(fc, "")])
	t.check("fest_set_cells_free", fest_cells.size() == 24 and fest_bad.is_empty() and m.ground_at(anchor) == "c", "the 24 posts of the festival set (host, judge, 4 stalls, 2 tables, 16 gather cells) around the anchor %s all fall on free ground of the torv (cobble), none on a solid footprint: %s" % [anchor, fest_bad])


# ================================================================== F. feature markers (data/features/map_markers.json) and the cast the amendments add

func _features(t) -> void:
	var s: Dictionary = _hs
	var json: Dictionary = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARKERS_JSON))
	if parsed is Dictionary:
		json = parsed
	var area: Dictionary = GameData.dict_of((GameData.dict_of(json.get("areas", {}))).get("hyggebyen", {}))
	var containers: Dictionary = GameData.dict_of(area.get("containers", {}))
	var want_spots: Array = GameData.array_of(area.get("unique_spots", []))
	want_spots.sort()
	var spots: Array = []
	for rec in _of(s, "unique_spot"):
		spots.append(str((rec["params"] as Dictionary).get("id", "")))
	spots.sort()
	var chest_like: int = _count_of(s, "chest") + _count_of(s, "dig_spot")
	var creatures: int = _count_of(s, "enemy")
	var want_chest: int = 0
	for k in containers:
		want_chest += int(containers[k])
	var want_creatures: int = 0
	for k2 in GameData.dict_of(area.get("creatures", {})):
		want_creatures += int((area["creatures"] as Dictionary)[k2])
	t.check("feature_markers_match_json", not area.is_empty() and spots == want_spots and spots == ["kufferten"] and chest_like == want_chest and creatures == want_creatures and _count_of(s, "mailbox") == 0,
		"areas.hyggebyen of data/features/map_markers.json (the file also holds forest areas that DL4 trims in wave 5: only `farm` and `hyggebyen` are read, the farm entry is maps_farm's): unique spots %s == %s, containers %d == %d (chests + dig spots), creatures %d == %d, no mailbox" % [spots, want_spots, chest_like, want_chest, creatures, want_creatures])
	# ---- the cast and the corner scenes of the amendments
	var cells: Dictionary = {}
	for rec2 in _of(s, "npc"):
		cells[str((rec2["params"] as Dictionary).get("id", ""))] = rec2
	var stalls: Array = []
	for art in (s["props_by_art"] as Dictionary):
		if str(art).begins_with("market_stall"):
			stalls.append(str(art))
	stalls.sort()
	var hives: Array = (s["props_by_art"] as Dictionary).get("beehive_stand", []) as Array
	var hive_ok: bool = hives.size() == 3
	for h in hives:
		hive_ok = hive_ok and (h as Vector2i).x >= 28 and (h as Vector2i).y >= 28      # the SE corner
	var birk_cell: Vector2i = (cells["beekeeper_birk"]["cell"] as Vector2i) if cells.has("beekeeper_birk") else Vector2i(-99, -99)
	var mis: Dictionary = cells.get("cat_morfar_mis", {}) as Dictionary
	var pippin_house: Vector2i = Vector2i(-99, -99)
	for rec3 in _of(s, "door"):
		if str((rec3["params"] as Dictionary).get("building", "")) == "pippins_hus":
			pippin_house = rec3["cell"]
	var mis_cell: Vector2i = mis["cell"] if not mis.is_empty() else Vector2i(-99, -99)
	var mis_ok: bool = not mis.is_empty() and str((mis["params"] as Dictionary).get("when", "")) == "done:lost_cat" and maxi(absi(mis_cell.x - pippin_house.x), absi(mis_cell.y - pippin_house.y)) <= 4
	var birk_near: bool = false
	for h2 in hives:
		birk_near = birk_near or maxi(absi(birk_cell.x - (h2 as Vector2i).x), absi(birk_cell.y - (h2 as Vector2i).y)) <= 4
	var builder_cell: Vector2i = (cells["fairy_builder"]["cell"] as Vector2i) if cells.has("fairy_builder") else Vector2i(-99, -99)
	var bridge_cell: Vector2i = (_warps(s)[0]["cell"] as Vector2i)
	var yard_near_bridge: bool = absi(builder_cell.x - bridge_cell.x) <= 8 and absi(builder_cell.y - bridge_cell.y) <= 8
	var stall_npc: bool = true
	for id in ["fairy_furnisher", "fairy_tailor"]:
		var nc: Vector2i = (cells[id]["cell"] as Vector2i) if cells.has(id) else Vector2i(-99, -99)
		var near: bool = false
		for art2 in stalls:
			for sc in ((s["props_by_art"] as Dictionary)[art2] as Array):
				near = near or maxi(absi(nc.x - (sc as Vector2i).x), absi(nc.y - (sc as Vector2i).y)) <= 3
		stall_npc = stall_npc and near
	var flea: bool = cells.has("pippin_boegeknop")
	t.check("feature_npcs_and_stalls", stalls.size() >= 3 and hive_ok and birk_near and mis_ok and yard_near_bridge and stall_npc and flea and _props_n(s, "plank_stack") + _props_matching(s, "plank_stack") >= 2,
		"market stalls %s; fairy_furnisher and fairy_tailor stand at stalls; fairy_builder at the builder yard (%d cells from the bridge end) with plank stacks; Pippin has his flea stall; 3 beehive_stand in the SE corner %s and Birk beside them; cat_morfar_mis `when=done:lost_cat` %d cells from Pippin's door" % [stalls, maxi(absi(builder_cell.x - bridge_cell.x), absi(builder_cell.y - bridge_cell.y)), hives, maxi(absi(mis_cell.x - pippin_house.x), absi(mis_cell.y - pippin_house.y))])


# ================================================================== G. density and lights ("an empty 40 x 40 grass diamond is the known 6.5/10 failure")

func _fill_and_lights(t) -> void:
	var m: AreaMap = _hyg
	var s: Dictionary = _hs
	var houses: int = _props_matching(s, "house_") + _props_matching(s, "tower_")
	var lanterns: int = _props_matching(s, "lantern_post")
	var stalls: int = _props_matching(s, "market_stall")
	var trees: int = _props_n(s, "tree_blossom_hyggebyen")
	var signs: int = _count_of(s, "sign")
	var benches: int = _props_n(s, "bench")
	var fountains: int = _props_n(s, "fountain")
	var wells: int = _props_n(s, "well")
	var counts := {"houses": houses, "lanterns": lanterns, "stalls": stalls, "blossom_trees": trees, "signs": signs, "benches": benches, "fountains": fountains, "wells": wells}
	var short: Array = []
	for k in FILL_MINIMUMS:
		if int(counts[k]) < int(FILL_MINIMUMS[k]):
			short.append("%s %d < %d" % [k, counts[k], FILL_MINIMUMS[k]])
	var all_props: int = _all_props(m, s).size()
	var walk: int = m.walkable_count()
	var density: float = float(all_props) / float(maxi(walk, 1)) * 100.0
	# a spread check: every 10 x 10 quarter of the land holds at least 6 props or markers (no empty corner)
	var quarters: Array = []
	for qy in range(2):
		for qx in range(2):
			var n: int = 0
			for p in _all_props(m, s):
				var f: Vector2i = p["front"]
				if f.x >= 3 + qx * 17 and f.x < 3 + (qx + 1) * 17 and f.y >= 3 + qy * 17 and f.y < 3 + (qy + 1) * 17:
					n += 1
			quarters.append(n)
	var spread: bool = true
	for q in quarters:
		spread = spread and int(q) >= 12
	t.check("hyggebyen_is_filled", short.is_empty() and density >= 6.0 and spread, "%s; %d props on %d ground cells = %.1f per 100 cells (>= 6.0); props per quarter of the land %s (each >= 12); short: %s" % [counts, all_props, walk, density, quarters, short])
	# ---- light budget: lantern props carry a PointLight2D through lua/config/props*.lua, `light` markers add one each
	var lights: int = _count_of(s, "light")
	for art in (s["props_by_art"] as Dictionary):
		if not GameData.dict_of(GameData.prop_def(str(art)).get("light", {})).is_empty():
			lights += ((s["props_by_art"] as Dictionary)[art] as Array).size()
	var hub_lights: int = _count_of(_us, "light")
	t.check("light_budget", lights <= MAX_MAP_LIGHTS and hub_lights == 3, "Hyggebyen: %d map lights (%d lantern posts + %d light markers) <= %d (the Compatibility renderer drops lights above 16 per canvas item); the hub has %d glow lights" % [lights, lanterns, _count_of(s, "light"), MAX_MAP_LIGHTS, hub_lights])


# ================================================================== H. strings

func _strings(t) -> void:
	var needed: Dictionary = {}
	for pair in [[_hs, "hyggebyen"], [_us, "moerkeskoven"]]:
		var s: Dictionary = pair[0]
		for rec in _of(s, "sign"):
			needed[str((rec["params"] as Dictionary).get("text", ""))] = pair[1]
		for rec2 in _of(s, "whisper"):
			needed[str((rec2["params"] as Dictionary).get("text", ""))] = pair[1]
	needed["UI_READ"] = "sign prompt"
	var missing: Array = []
	var csv: String = FileAccess.get_file_as_string(AREAS_CSV)
	var in_csv: Array = []
	for key in needed:
		var da: String = _text_of(str(key), "da")
		var en: String = _text_of(str(key), "en")
		if da == "" or en == "" or da == str(key) or en == str(key):
			missing.append(key)
		if csv.contains("\n%s," % key):
			in_csv.append(key)
	var farm_keys: Array = ["SIGN_ORCHARD", "SIGN_FARM_BRIDGE", "SIGN_FARM_FOREST"]
	var steals: Array = []
	for k in farm_keys:
		if csv.contains("\n%s," % k):
			steals.append(k)
	var hub_da: String = _text_of("SIGN_MOERKESKOVEN_HUB", "da")
	var hub_en: String = _text_of("SIGN_MOERKESKOVEN_HUB", "en")
	var whisper_da: String = _text_of("SIGN_MOERKESKOVEN_WHISPER", "da")
	t.check("areas_csv_rows", missing.is_empty() and in_csv.size() == needed.size() and steals.is_empty() and hub_da == "Her begynder Mørkeskoven. Husk lygten." and hub_en == "The Dark Wood begins here. Remember your lantern." and whisper_da == "Her dufter af vådt mos og gamle eventyr.",
		"%d keys (every sign / whisper text of both maps + UI_READ) are rows of localization/areas.csv with Danish and English text, the three farm keys of farm_signs.csv are not redefined %s, the two hub strings read as the addendum words; missing %s, outside areas.csv %s" % [needed.size(), steals, missing, needed.keys().filter(func(k: Variant) -> bool: return not in_csv.has(k))])
	# loc_check (lenient): the maps may name no key without a text, except the ones a later package defines (V1: ZONE_TRAETOPPEN)
	var res: Dictionary = t.run_godot_script("res://tests/loc_check.gd")
	var miss_lines: Array = []
	var pending_seen: Array = []
	for line in (res["lines"] as PackedStringArray):
		var l: String = str(line)
		if l.begins_with("MISS ") and (l.contains("data/maps/hyggebyen.map") or l.contains("data/maps/moerkeskoven.map")):
			var key: String = l.get_slice(" ", 2)
			if PENDING_KEYS.has(key):
				pending_seen.append(key)
			else:
				miss_lines.append(l)
	t.check("loc_check_maps_clean", int(res["code"]) == 0 and miss_lines.is_empty(), "tests/loc_check.gd exit %s: no MISS line names hyggebyen.map or moerkeskoven.map except the pending keys %s; MISS lines %s" % [res["code"], PENDING_KEYS.keys(), miss_lines])
	for k3 in pending_seen:
		t.skip("maps_iso.loc_check_maps_clean: %s is still MISS (named by the warp label of the maps) - %s" % [k3, PENDING_KEYS[k3]])


# ================================================================== I. connectivity from the REAL colliders (Hyggebyen)

func _body_shape(scale: float) -> ConvexPolygonShape2D:
	var pts := PackedVector2Array()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * BODY.x * scale, sin(a) * BODY.y * scale))
	var sh := ConvexPolygonShape2D.new()
	sh.points = pts
	return sh


## A grid of the area: a cell is solid when the ground is void / water or a body of `scale` x the player's ellipse standing on the cell touches
## the world or ground_block layer of the REAL physics space.
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
			var blocked: bool = ch == "#" or ch == "~" or ch == "W"
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


## Void cells that touch walkable ground (the rim): does the physics space really stop a body standing on them? (the explicit `#` rule of _bake would hide a
## missing blocker: this asks the physics server only)
func _rim_blocked_by_physics(a: IsoArea) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = a.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _body_shape(1.0)
	q.collision_mask = Iso.LAYER_WORLD | Iso.LAYER_GROUND_BLOCK
	q.collide_with_areas = false
	var rim: int = 0
	var open: Array = []
	for y in a.map.height:
		for x in a.map.width:
			var c := Vector2i(x, y)
			if a.map.ground_at(c) != "#":
				continue
			var touches: bool = false
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var n: Vector2i = c + Vector2i(dx, dy)
					if (dx != 0 or dy != 0) and a.map.ground_at(n) != "#" and a.map.ground_at(n) != "=":
						touches = true
			if not touches:
				continue
			rim += 1
			q.transform = Transform2D(0.0, a.cell_to_global(c))
			if space.intersect_shape(q, 1).is_empty():
				open.append(c)
	return {"rim": rim, "open": open}


## Shortest walking length from `start` to the nearest free cell within two cells of `cell` (a sign or a runestone stands ON its cell; the E query
## circle of the player reaches 45 ground px around the facing cell).
func _reach(a: IsoArea, start: Vector2i, cell: Vector2i, radius: int = 2) -> float:
	var best: float = -1.0
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var c: Vector2i = cell + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= a.map.width or c.y >= a.map.height or _astar.is_point_solid(c):
				continue
			var l: float = _path_len(a, start, c)
			if l >= 0.0 and (best < 0.0 or l < best):
				best = l
	return best


func _walk_speed() -> float:
	return float(GameData.player_cfg("walk_speed", 285.0))


func _enter(t, id: StringName, spawn: StringName = &"default") -> IsoArea:
	_world._enter(id, spawn)
	await t.physics(1)
	_world.rebuild_current_area()
	await t.physics(3)
	return _world.area


func _physics_connectivity(t) -> void:
	var a: IsoArea = await _enter(t, &"hyggebyen", &"default")
	_a = a
	_bake(a, 1.4)
	var start: Vector2i = a.global_to_cell(a.spawns["default"])
	var targets: Array = []
	for rec in a.markers:
		var ty: String = str(rec["type"])
		if ty in ["spawn", "warp", "sign", "door", "post", "npc", "quest_spot", "unique_spot", "town"]:
			targets.append([ty, rec["cell"], rec["params"]])
	for sn in a.spawns:
		targets.append(["spawn:" + String(sn), a.global_to_cell(a.spawns[sn]), {}])
	var unreachable: Array = []
	for tg in targets:
		if _reach(a, start, tg[1]) < 0.0:
			unreachable.append([tg[0], tg[1], (tg[2] as Dictionary).get("name", (tg[2] as Dictionary).get("building", (tg[2] as Dictionary).get("id", "")))])
	var door_cells: Array = []
	for rec2 in a.find_markers("door"):
		door_cells.append(rec2["cell"])
	var approach: Dictionary = {}                      # door cell -> the nearest free (body x1.4), reachable cell within one cell
	for dc in door_cells:
		var best: float = INF
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var c: Vector2i = (dc as Vector2i) + Vector2i(dx, dy)
				if _astar.is_point_solid(c):
					continue
				var l: float = _path_len(a, start, c)
				if l >= 0.0 and l < best:
					best = l
					approach[dc] = c
	# every walkable land cell a body 1.15 x the player's can stand on is connected to `default` (no sealed pocket behind props or between a house and the rim)
	var n1400: int = int(_info.get("nav_solid_x1.4", 0))
	_bake(a, 1.15)
	var pockets: Array = []
	for y in a.map.height:
		for x in a.map.width:
			var c2 := Vector2i(x, y)
			if not _astar.is_point_solid(c2) and _path_len(a, start, c2) < 0.0:
				pockets.append(c2)
	t.check("connectivity", unreachable.is_empty() and targets.size() >= 60 and pockets.is_empty() and approach.size() == 14,
		"Hyggebyen: %d targets (spawns, the bridge warp, 14 doors, 24 posts + fest anchor, npcs, signs, quest spot, unique spot, town) reachable from `default` with the player's body x1.4 baked from the physics space (%d solid cells; a doorstep touches the padded house, so the door is entered from the neighbour cell, see door_triggers_can_be_entered); sealed pockets of free ground for a body x1.15: %d %s; unreachable %s" % [targets.size(), n1400, pockets.size(), pockets.slice(0, 4), unreachable])
	var rim_h: Dictionary = _rim_blocked_by_physics(a)
	t.check("rim_blocks_the_body", (rim_h["open"] as Array).is_empty() and int(rim_h["rim"]) > 100,
		"Hyggebyen: %d void cells touch the platform and each stops a body in the physics space (the invisible rim blockers; the bridge planks have none by design); open %s" % [rim_h["rim"], (rim_h["open"] as Array).slice(0, 5)])
	# every spawn reaches every warp (both directions of the one hanging bridge)
	var warp_cell: Vector2i = (_warps(_hs)[0]["cell"] as Vector2i)
	var spawn_paths: Array = []
	var bad_spawn: Array = []
	for sn2 in a.spawns:
		var l2: float = _path_len(a, a.global_to_cell(a.spawns[sn2]), warp_cell)
		if l2 < 0.0:
			bad_spawn.append(String(sn2))
		else:
			spawn_paths.append("%s %.1f s" % [sn2, l2 / _walk_speed()])
	t.check("spawn_to_warp_paths", bad_spawn.is_empty() and spawn_paths.size() == 2, "a walkable path leads from every spawn to the bridge warp (flood fill on the cells a body 1.15 x the player's can stand on): %s" % [spawn_paths])
	# spawns lie outside every warp diamond (an arrival never re-triggers the warp)
	var min_gap: float = INF
	for sn3 in a.spawns:
		for w in _warps(_hs):
			min_gap = minf(min_gap, Iso.ground_dist(a.spawns[sn3], a.cell_to_global(w["cell"])))
	t.check("spawns_outside_warps", min_gap > 2.0 * 90.0, "closest spawn-to-warp distance %.0f ground px: no spawn lies inside a warp diamond (limit 180)" % min_gap)
	# the real body walks from the arrival spawn to the end of the bridge and the Warp2D fires exactly once
	_bake(a, 1.0)
	await _walk_the_bridge(t, a)
	await _door_triggers(t, a, approach)


## The 14 doors are Warp2D diamonds on the doorstep cells (the towns director builds them there): a real body (the player's ellipse x1.4) walks from the
## nearest free neighbour cell straight at the door and must enter the trigger - the padded house stops it before the centre of the doorstep, so this
## proves the doorstep is operable, not merely that a path exists.
func _door_triggers(t, a: IsoArea, approach: Dictionary) -> void:
	var bus: Node = t.autoload("EventBus")
	var hits: Array = []
	var cb := func(area_id: StringName, _spawn_name: StringName) -> void: hits.append(String(area_id))
	bus.area_change_requested.connect(cb)
	var body := CharacterBody2D.new()
	body.add_to_group("player")
	body.collision_layer = Iso.LAYER_PLAYER
	body.collision_mask = Iso.MASK_WALKING
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	cs.shape = _body_shape(1.4)
	body.add_child(cs)
	a.objects.add_child(body)
	var failed: Array = []
	var frames_used: int = 0
	var n: int = 0
	for dc in approach:
		var door: Vector2i = dc
		var wp := Warp2D.new()
		wp.setup({"to": "_door_probe_%d_%d" % [door.x, door.y], "spawn": "default", "label": "X"}, a, door)
		wp.position = a.to_local(a.cell_to_global(door))
		a.triggers.add_child(wp)
		body.global_position = a.cell_to_global(approach[dc])
		body.velocity = Vector2.ZERO
		await t.physics(2)
		hits.clear()
		var target: Vector2 = a.cell_to_global(door)
		var f: int = 0
		while f < 120 and hits.is_empty():
			var dir: Vector2 = Iso.to_ground(target - body.global_position)
			body.velocity = Iso.to_screen(dir.normalized() * _walk_speed())
			body.move_and_slide()
			await t.physics(1)
			f += 1
		frames_used += f
		n += 1
		if hits.size() != 1:
			failed.append([door, hits.size()])
		wp.queue_free()
		await t.physics(1)
	bus.area_change_requested.disconnect(cb)
	body.queue_free()
	t.check("door_triggers_can_be_entered", failed.is_empty() and n == 14, "%d door diamonds (Warp2D geometry on the doorstep cells): a body x1.4 walking from the nearest free neighbour cell enters each trigger exactly once (%d physics frames in all); failed %s" % [n, frames_used, failed])


func _walk_the_bridge(t, a: IsoArea) -> void:
	var warp_cell: Vector2i = (_warps(_hs)[0]["cell"] as Vector2i)
	var start_c: Vector2i = a.global_to_cell(a.spawns["from_traetoppen"])
	var ids: Array[Vector2i] = _astar.get_id_path(start_c, warp_cell)
	var body := CharacterBody2D.new()
	body.add_to_group("player")
	body.collision_layer = Iso.LAYER_PLAYER
	body.collision_mask = Iso.MASK_WALKING
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	cs.shape = _body_shape(1.0)
	body.add_child(cs)
	a.objects.add_child(body)
	body.global_position = a.spawns["from_traetoppen"]
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
	var step: float = _walk_speed() / 60.0
	var idx: int = 1
	var frames: int = 0
	await t.physics(2)
	var fired_at_start: int = changes.size()
	while idx < ids.size() and frames < WALK_FRAMES_MAX and changes.is_empty():
		var target: Vector2 = a.cell_to_global(ids[idx])
		var to_t: Vector2 = target - body.global_position
		if to_t.length() < 6.0:
			idx += 1
			continue
		body.velocity = Iso.to_screen(Iso.to_ground(to_t).normalized() * _walk_speed())
		body.move_and_slide()
		await t.physics(1)
		frames += 1
	var end_pos: Vector2 = body.global_position
	await t.physics(10)
	bus.area_change_requested.disconnect(cb)
	for m in muted:
		bus.area_change_requested.connect(m)
	body.queue_free()
	var warp_pos: Vector2 = a.cell_to_global(warp_cell)
	t.check("walk_bridge_end_fires_the_warp", fired_at_start == 0 and changes.size() == 1 and changes[0] == ["traetoppen", "from_hyggebyen"] and not ids.is_empty(),
		"a real CharacterBody2D (25 x 14.8) walks %d cells from from_traetoppen (nothing fired at the arrival) in %d physics frames and the Warp2D emits area_change_requested(traetoppen, from_hyggebyen) exactly once (%s), ends %.0f px from the warp cell" % [ids.size(), frames, changes, end_pos.distance_to(warp_pos)])


# ================================================================== J. the hub

func _hub_checks(t) -> void:
	var m: AreaMap = _hub
	var s: Dictionary = _us
	var a: IsoArea = await _enter(t, &"moerkeskoven", &"default")
	_bake(a, 1.4)
	var start: Vector2i = a.global_to_cell(a.spawns["default"])
	var spawn_names: Array[String] = _spawn_names(m, s)
	spawn_names.sort()
	var unreachable: Array = []
	var targets: int = 0
	for rec in a.markers:
		var ty: String = str(rec["type"])
		if ty in ["spawn", "warp", "sign", "whisper", "runestone", "light", "forest_dress"]:
			targets += 1
			if _reach(a, start, rec["cell"]) < 0.0:
				unreachable.append([ty, rec["cell"]])
	var spawn_free: bool = true
	var spawn_info: Array = []
	for sn in a.spawns:
		var c: Vector2i = a.global_to_cell(a.spawns[sn])
		var free: bool = not _astar.is_point_solid(c)
		spawn_free = spawn_free and free
		spawn_info.append("%s %s" % [sn, "free" if free else "BLOCKED"])
	var pockets: int = 0
	for y in a.map.height:
		for x in a.map.width:
			var c2 := Vector2i(x, y)
			if not _astar.is_point_solid(c2) and _path_len(a, start, c2) < 0.0:
				pockets += 1
	t.check("hub_parses_and_connects", m.errors.is_empty() and a.map.errors.is_empty() and a.unknown_chars.is_empty() and spawn_names == ["default", "from_floor", "from_traetoppen"] and unreachable.is_empty() and spawn_free and pockets == 0 and targets >= 9,
		"the hub (%d x %d, %d floor cells): parse errors %s, errors after setup %s, spawns %s (%s), %d markers (spawns, both warps, sign, whisper zone, runestone, 3 glow lights, forest_dress) reachable from `default` with the body x1.4 baked from the physics space, floor pockets %d, unreachable %s" % [m.width, m.height, m.walkable_count(), m.errors, a.map.errors, spawn_names, spawn_info, targets, pockets, unreachable])
	_bake(a, 1.15)
	var hub_paths: Array = []
	var hub_bad: Array = []
	for w0 in _warps(s):
		for sn2 in a.spawns:
			var l: float = _path_len(a, a.global_to_cell(a.spawns[sn2]), w0["cell"])
			if l < 0.0:
				hub_bad.append("%s -> %s" % [sn2, w0["to"]])
			else:
				hub_paths.append("%s -> %s %.1f s" % [sn2, w0["to"], l / _walk_speed()])
	var gap: float = a.spawns["default"].distance_to(a.spawns["from_traetoppen"])
	var min_warp: float = INF
	for w1 in _warps(s):
		for sn3 in a.spawns:
			min_warp = minf(min_warp, (a.spawns[sn3] as Vector2).distance_to(a.cell_to_global(w1["cell"])))
	t.check("hub_spawns_reach_the_warps", hub_bad.is_empty() and hub_paths.size() == 6 and gap <= 1.5 * 96.0 and min_warp > 2.0 * 56.0,
		"every hub spawn walks to both warps (a body 1.15 x the player's): %s; no spawn lies inside a warp rectangle (closest %.0f px, limit 112); default and from_traetoppen lie %.0f px apart (a cell holds ONE object char, so the Skovlift arrival is the neighbour cell of `default`)" % [hub_paths, min_warp, gap])
	# ---- ONE gate to the Skovlift, the Hulen, the strings, the look markers
	var ws: Array = _warps(s)
	var gate: Dictionary = {}
	var hulen: Dictionary = {}
	for w in ws:
		if w["to"] == "traetoppen":
			gate = w
		elif String(w["to"]).begins_with(GENERATED_PREFIX):
			hulen = w
	var runes: Array = _of(s, "runestone")
	var rune_ok: bool = runes.size() == 1 and str((runes[0]["params"] as Dictionary).get("id", "")) == "rune_hub" and str((runes[0]["params"] as Dictionary).get("hub", "")) == "1"
	var sign_ok: bool = _count_of(s, "sign") == 1 and str((_of(s, "sign")[0]["params"] as Dictionary).get("text", "")) == "SIGN_MOERKESKOVEN_HUB"
	var whisper_ok: bool = _count_of(s, "whisper") == 1 and str((_of(s, "whisper")[0]["params"] as Dictionary).get("text", "")) == "SIGN_MOERKESKOVEN_WHISPER" and str((_of(s, "whisper")[0]["params"] as Dictionary).get("r", "")) == "2"
	var crowns: int = _props_matching(s, "crown_")
	var gate_free_of_walls: bool = a.map.ground_at(gate.get("cell", Vector2i(-1, -1))) != "#"
	t.check("hub_has_one_gate_to_the_skovlift", ws.size() == 2 and not gate.is_empty() and gate["spawn"] == "from_skovlift" and gate["label"] == "ZONE_TRAETOPPEN" and gate["prop"] == "warp_gate_stone"
		and not hulen.is_empty() and hulen["to"] == "moerkeskoven_f1" and hulen["spawn"] == "default" and hulen["label"] == "ZONE_DARK_FOREST" and hulen["prop"] == "cave_ring"
		and rune_ok and sign_ok and whisper_ok and _count_of(s, "forest_dress") == 1 and _count_of(s, "light") == 3 and _count_of(s, "npc") == 0 and crowns >= 30 and gate_free_of_walls
		and not _file_mentions(HUB_PATH, ["to=farm", "to=hyggebyen", "from_farm", "from_hyggebyen", "skovkant"]),
		"%d warps: the ONE gate arch (warp_gate_stone) to traetoppen:from_skovlift label ZONE_TRAETOPPEN %s and the Hulen mouth (cave_ring) to moerkeskoven_f1:default label ZONE_DARK_FOREST %s; the farm and Hyggebyen gates of the draft are gone; Port-runen rune_hub hub=1 %s; sign SIGN_MOERKESKOVEN_HUB %s; whisper SIGN_MOERKESKOVEN_WHISPER r=2 %s; forest_dress %d; glow lights %d; npc slots %d; %d rim crowns as @prop rows" % [ws.size(), gate.get("cell"), hulen.get("cell"), rune_ok, sign_ok, whisper_ok, _count_of(s, "forest_dress"), _count_of(s, "light"), _count_of(s, "npc"), crowns])
	# the wall depth of the hub is 0: no `W` chars (the void rim blockers keep the player in, the crowns are the visible rim)
	var walls: int = 0
	for row in m.ground:
		walls += row.count("W")
	var rim_u: Dictionary = _rim_blocked_by_physics(a)
	t.check("hub_rim_is_void", walls == 0 and not m.props.is_empty() and (rim_u["open"] as Array).is_empty() and int(rim_u["rim"]) > 60,
		"no `W` wall cells (rim.wall_depth 0): the rim is void and the %d void cells that touch the clearing each stop a body in the physics space (invisible blockers; open %s); the crowns are scenery props" % [rim_u["rim"], (rim_u["open"] as Array).slice(0, 5)])


# ================================================================== K. the world, build budget

func _world_and_budget(t) -> void:
	var ids: Array[StringName] = WorldRoot2D.area_ids(false)
	var reg_ok: bool = ids.has(&"hyggebyen") and ids.has(&"moerkeskoven") and ids.has(&"farm") and WorldRoot2D.default_area_id() == &"farm"
	var a: IsoArea = await _enter(t, &"hyggebyen", &"from_traetoppen")
	var p: Node2D = _world.player
	var d1: float = p.global_position.distance_to(a.spawns["from_traetoppen"])
	var amb1: StringName = _world.area.map.ambient
	var zone1: StringName = _world.current_zone()
	var a2: IsoArea = await _enter(t, &"moerkeskoven", &"from_traetoppen")
	var d2: float = p.global_position.distance_to(a2.spawns["from_traetoppen"])
	var zone2: StringName = _world.current_zone()
	var a3: IsoArea = await _enter(t, &"hyggebyen", &"default")
	var d3: float = p.global_position.distance_to(a3.spawns["default"])
	t.check("world_enters_the_areas", reg_ok and d1 < 1.0 and d2 < 1.0 and d3 < 1.0 and amb1 == &"hyggebyen" and zone1 == &"city" and zone2 == &"dark_forest",
		"registry lists hyggebyen + moerkeskoven (default start area %s); the player arrives on the spawn from_traetoppen of Hyggebyen (%.1f px off, zone %s) and of the hub (%.1f px, zone %s), on `default` of Hyggebyen (%.1f px)" % [WorldRoot2D.default_area_id(), d1, zone1, d2, zone2, d3])
	# ---- build budget: the minimum of five builds of each map (the first one paints the placeholder atlases)
	var best_h: int = 1 << 30
	var best_u: int = 1 << 30
	var nodes_h: int = 0
	for i in 5:
		var ah: IsoArea = _make_area(_hyg)
		best_h = mini(best_h, ah.build_ms)
		nodes_h = _count_nodes(ah)
		var au: IsoArea = _make_area(_hub)
		best_u = mini(best_u, au.build_ms)
	_free_holders()
	t.check("build_budget", best_h < 180 and best_u < 120 and nodes_h < 1200, "Hyggebyen builds in %d ms (min of 5, %d nodes), the hub in %d ms (budgets 180 / 120 ms on a loaded headless machine; the farm of N01 budgets 60 ms for 496 nodes)" % [best_h, nodes_h, best_u])


func _count_nodes(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c


# ================================================================== L. art

func _art(t) -> void:
	var present: bool = FileAccess.file_exists(ART_MANIFEST)
	if not present:
		t.skip("maps_iso.art_complete: assets/iso_props/props.json does not exist yet - P22-art-environment bakes the real art (strict in P27-qa-acceptance); every prop id of both maps falls back to the placeholder meanwhile")
		return
	ArtCatalog.clear_missing()
	for m in [_hyg, _hub]:
		var a: IsoArea = _make_area(m as AreaMap)
		a.set_night_factor(0.0)
	var missing: Array[String] = ArtCatalog.missing()
	var mine: Array = []
	for id in missing:
		if str(id).begins_with("icon:") or str(id).begins_with("portrait:"):
			continue
		mine.append(id)
	_free_holders()
	if mine.is_empty():
		t.check("art_complete", true, "ArtCatalog.missing() is empty for Hyggebyen and the hub: every prop, terrain and backdrop is real art")
	elif ART_STRICT:
		t.check("art_complete", false, "ArtCatalog.missing() for Hyggebyen and the hub: %s" % [mine])
	else:
		t.skip("maps_iso.art_complete: P22's art is still incomplete for %d ids of these two maps (strict in P27, ART_STRICT): %s" % [mine.size(), mine.slice(0, 12)])


# ================================================================== M. meta: the carve-outs

func _meta(t) -> void:
	var farm_names: Array[String] = ["home_reserve_on_deck_after_growth", "spawn_from_home_walkable", "feature_markers_match_json", "farm_warp_graph", "farm_mailbox_marker", "wake_spawn_from_home_walkable"]
	var farm_src: String = FileAccess.get_file_as_string(MAPS_FARM_SECTION) if FileAccess.file_exists(MAPS_FARM_SECTION) else ""
	var own_src: String = FileAccess.get_file_as_string("res://tests/sections/maps_iso.gd")
	var found: Array = []
	var absent: Array = []
	for n in farm_names:
		if farm_src.contains("\"%s\"" % n):
			found.append(n)
		else:
			absent.append(n)
	# this file asserts nothing about the farm: it neither loads farm.map nor produces one of the moved check names
	var farm_here: Array = []
	for n3 in ["farm_warp_graph", "farm_mailbox_marker", "home_reserve_on_deck_after_growth", "spawn_from_home_walkable", "wake_spawn_from_home_walkable"]:
		if own_src.contains("check(\"%s\"" % n3):
			farm_here.append(n3)
	if farm_src == "":
		t.skip("maps_iso.farm_checks_moved_to_maps_farm: tests/sections/maps_farm.gd does not exist yet - N01-farm-map re-homes the farm halves there")
	else:
		t.check("farm_checks_moved_to_maps_farm", absent.is_empty() and farm_here.is_empty(), "the farm halves are maps_farm.* (N01): found %s in tests/sections/maps_farm.gd, not found %s; this section produces none of them %s" % [found, absent, farm_here])
	# the Hyggebyen half is intact: every check name of the order and its amendments is still produced by this file
	var want: Array[String] = ["parse_no_errors", "markers_resolve", "npc_ids_exist", "connectivity", "warp_roundtrips", "warp_graph_pending_areas", "hyggebyen_warp_graph", "feature_markers_match_json",
		"hub_parses_and_connects", "hub_has_one_gate_to_the_skovlift", "town_markers_present", "no_warp_to_removed_forest_areas"]
	var lost: Array = []
	for n2 in want:
		if not own_src.contains("check(\"%s\"" % n2):
			lost.append(n2)
	if not own_src.contains("check(\"art_complete\"") or not own_src.contains("maps_iso.art_complete: "):
		lost.append("art_complete")
	t.check("hyggebyen_checks_unchanged", lost.is_empty() and PENDING_AREAS == ["traetoppen"], "the Hyggebyen halves of the original order (%d named checks + art_complete) and PENDING_AREAS for the hyggebyen warp are all still in this section; lost %s" % [want.size(), lost])


func _cleanup(t) -> void:
	_free_holders()
	if _world != null and is_instance_valid(_world):
		_world._enter(WorldRoot2D.default_area_id(), &"default")
		await t.physics(2)


# ================================================================== windowed: the two maps render (tests/run_playtest.sh --windowed --only=maps_iso)

func run_windowed(t) -> void:
	_t = t
	# an occluded / unfocused macOS window can block on presenting a frame (vsync): the capture would wait for ever; frames at full speed instead
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if not await t.start_world():
		return
	_world = t.world()
	var stops := [
		["hyggebyen_torv", &"hyggebyen", Vector2i(20, 22), 0.4, 11.0],
		["hyggebyen_bridge", &"hyggebyen", Vector2i(31, 21), 0.4, 11.0],
		["hyggebyen_overview", &"hyggebyen", Vector2i(20, 20), 0.22, 11.0],
		["hyggebyen_night", &"hyggebyen", Vector2i(20, 22), 0.4, 22.5],
		["hub_gate", &"moerkeskoven", Vector2i(24, 27), 0.4, 23.0],
		["hub_overview", &"moerkeskoven", Vector2i(24, 19), 0.3, 23.0],
	]
	for stop in stops:
		# few frames per stop: a window that is not frontmost is throttled by macOS, and every awaited frame then costs seconds
		_world._enter(stop[1], &"default")
		var a: IsoArea = _world.area
		_world.day_night.override_hour = float(stop[4])
		_world.day_night.snap()
		a.set_night_factor(_world.day_night.glow_factor)
		_world.player.global_position = a.cell_to_global(stop[2])
		_world.player.camera.zoom = Vector2(float(stop[3]), float(stop[3]))
		_world.player.camera.reset_smoothing()
		await t.frames(4)
		var img: Image = await t.capture(str(stop[0]))
		if img != null:
			t.expect_not_blank(img, Rect2i(0, 0, 1280, 720), "%s renders (not a flat fill)" % stop[0], 24, 0.02)
			t.expect_not_clear(img, Vector2i(640, 360), "%s: the centre pixel is drawn" % stop[0])
	_world.day_night.override_hour = -1.0
	await _cleanup(t)
