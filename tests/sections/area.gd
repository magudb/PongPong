extends RefCounted
## Section "area" (P04-area-framework): the 2D area framework - Iso maths, the ASCII map parser, the TileSet factory, IsoArea (props,
## strips, skirts, water, markers, growth, builders), ArtCatalog with its placeholder fallback, WorldRoot2D (registry, travel, parking,
## zones, sleep / pass-out, save dict, opening hook), DayNight, WeatherFx and the player stub.
##
## Named checks (order VERIFY of P04 and the addendum amendments): area.geometry, area.collision_slide, area.ysort_probes,
## area.marker_handlers, area.strips_sort, area.skirts_placed, area.water_frames, area.player_stub_contract, area.when_conditions,
## area.area_switch, area.artcatalog_missing_expected, area.placeholder_boot_cost, area.marker_registry_from_lua,
## area.growth_stage_deck_and_skirts, area.builder_delegate_and_zoom_range, area.artcatalog_feature_dirs,
## area.home_ambient_and_cache_rule, area.builder_bounds_clamp_camera; windowed: area.render_not_blank, area.filter_seams, area.sort_pixels.
## Fix round 1: area.when_hides_prop_strips_and_collider (+ when_shows..., marker_prop_parts_are_tracked), area.failed_enter_keeps_the_old_area
## (+ failed_travel..., failed_rebuild...), area.saved_position_of_an_unknown_area_is_not_applied, area.pending_world_of_an_unknown_area_starts_on_the_platform,
## area.world_free_frees_parked_areas, area.scene_change_frees_the_parked_areas, area.ysort_probes / ysort_probe_tree (real node probes).
##
## Fix round 2: area.rebuild_queued_during_the_night (+ rebuilt_room_leaves_the_player_awake_and_free, rebuild_queued_during_the_pass_out,
## rebuild_request_is_kept_while_traveling, flush_without_a_request_does_nothing, rebuild_request_dies_with_the_room_the_player_leaves,
## enter_after_a_request_builds_the_room_once, rebuild_request_during_the_fade_in_runs_when_the_travel_ends),
## area.saved_position_garbage_starts_at_the_spawn (+ _raises_no_script_error, saved_position_accepts_whole_numbers,
## pending_world_with_a_garbage_position_starts_at_the_spawn), area.map_without_default_spawn_gets_a_fallback (+ player_starts_on_the_walkable_fallback_spawn,
## map_with_a_spawn_reports_nothing, builder_without_a_spawn_starts_in_the_middle_of_its_bounds), area.builder_keeps_the_saved_position
## (+ builder_without_walkable_test_clamps_into_the_bounds, pending_world_in_a_builder_room_keeps_the_position),
## area.world_restores_the_project_clear_colour (+ world_exit_tree_restores_..., next_world_sets_its_own_clear_colour),
## area.welcome_toast_is_the_zone_title_only / _on_a_new_game / _is_not_shown_on_continue_in_the_saved_area / _needs_a_title,
## area.quest_spot_reports_the_objective, area.warp_when_disables_the_trigger, area.growth_cells_are_clipped_to_the_map (+ _without_a_map_size_...,
## _over_the_map_..., _absurd_range_does_not_freeze_the_build), area.skirts_under_rim_water_but_not_under_bridge_planks;
## windowed area.sort_pixels re-derived from the strip geometry (pixel oracle, see run_windowed).
##
## Fix round RT6 (the `when=` grammar of the towns / social addendum): area.when_new_kinds_delegate, area.when_unknown_kind_is_a_map_error
## (+ when_unknown_kind_is_reported_once), area.when_refresh_on_hour_edge (+ when_refresh_on_friend_events_and_flags,
## when_signals_hooked_in_the_tree_and_released_out_of_it), area.when_old_kinds_unchanged, area.when_without_a_social_manager_is_local_and_quiet
## (a visible SKIP once S-core's real SocialManager autoload exists: then it is the real one that answers).
##
## The section is also the test BUILDER / MARKER HANDLER of the checks that need a script path: the static functions at the bottom
## (build, create_marker) are what a map header (`@builder res://tests/sections/area.gd`) or the Lua registry points at.
const SECTION := "area"
const TIMEOUT_S := 170.0

const SELF_PATH := "res://tests/sections/area.gd"

## 16 x 16 open iso platform for the physics probes: a pond, a tree, the spawn char. Everything else is grass.
const OPEN_MAP := """
@id _t_open
@projection iso
@ambient farm
@theme farm
@zone farm
@flight true
@prop T tree_oak_farm
@marker 1 spawn name=east
@ground
################
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..............#
#..~~~.........#
#..~~~.........#
#..~~~.........#
#..............#
#..............#
#..............#
################
@objects
................
................
................
................
................
..........T.....
................
................
........@.......
................
................
................
................
................
.......1........
................
"""

## An iso platform with a pond on its south edge and a bridge leaving to the east: the skirt rules of R.10 on a known shape.
const SKIRT_MAP := """
@id _t_skirt
@projection iso
@ambient farm
@theme farm
@ground
#########
#########
#.......#
#.......=
#.......#
#.~~....#
#..~~...#
#########
@objects
.........
.........
.........
.........
.........
.........
.........
.........
"""

var _t
var _world: Node2D
var _seen: Array = []                # whisper keys / signal log of the running check

# data the static test script functions below write to
static var built_calls: Array = []
static var made_markers: Array = []


func run(t) -> void:
	_t = t
	_static_checks(t)
	await _art_and_boot_cost(t)
	if not await t.start_world():
		return
	_world = t.world()
	_geometry(t)
	_player_stub_contract(t)
	await _registry_and_default(t)
	_fixture_build(t)
	await _marker_handlers(t)
	_marker_registry_from_lua(t)
	await _when_conditions(t)
	await _when_grammar(t)
	await _when_hides_whole_props(t)
	_strips(t)
	await _skirts_and_growth(t)
	await _default_spawn_fallback(t)
	await _water(t)
	await _physics(t)
	await _area_switch_and_cache(t)
	await _failed_enter_keeps_the_area(t)
	await _farm_sized_map(t)
	await _zones_and_clock(t)
	await _builder_areas(t)
	await _builder_rebuild_while_traveling(t)
	_artcatalog_feature_dirs(t)
	_day_night_and_weather(t)
	await _sleep_and_passout(t)
	await _save_dict_and_intro(t)
	_warm_jobs(t)
	await _clear_colour_after_quit(t)
	_cleanup(t)


# ================================================================== static checks (no world)

func _static_checks(t) -> void:
	# --- Iso: every constant of the decisions D3 / D4 lives in one file
	t.check("iso_constants", Iso.TILE_W == 128 and Iso.TILE_H == 76 and Iso.ORTHO_W == 96 and Iso.ORTHO_H == 56 and Iso.TILE_CELL_W == 144 and Iso.TILE_CELL_H == 84,
		"tile %dx%d cell %dx%d ortho %dx%d" % [Iso.TILE_W, Iso.TILE_H, Iso.TILE_CELL_W, Iso.TILE_CELL_H, Iso.ORTHO_W, Iso.ORTHO_H])
	t.check("iso_zoom_and_squash", is_equal_approx(Iso.DEFAULT_ZOOM, 0.4) and is_equal_approx(Iso.ZOOM_MIN, 0.3) and is_equal_approx(Iso.ZOOM_MAX, 0.7) and is_equal_approx(Iso.squash(), 76.0 / 128.0),
		"zoom %.2f in %.2f .. %.2f, squash %.5f (sin 36 = 0.5878)" % [Iso.DEFAULT_ZOOM, Iso.ZOOM_MIN, Iso.ZOOM_MAX, Iso.squash()])
	t.check("iso_no_sprite_scale", not Iso.new().get_script().get_script_constant_map().has("SPRITE_SCALE"), "sprites are never scaled individually (D4); Iso.S = %.4f is the literal rescale helper" % Iso.S)
	t.expect_near(Iso.S, 1.0 / 0.6, 0.0001, "Iso.S = 1 / 0.6")
	# --- cell maths round trips
	var ok: bool = true
	for y in range(-3, 24):
		for x in range(-3, 24):
			var c := Vector2i(x, y)
			if Iso.iso_cell(Iso.iso_center(c)) != c or Iso.ortho_cell(Iso.ortho_center(c)) != c:
				ok = false
	t.check("iso_cell_roundtrip", ok, "iso_cell(iso_center(c)) == c and ortho_cell(ortho_center(c)) == c for 27 x 27 cells")
	var corner_ok: bool = true
	for c2 in [Vector2i(4, 4), Vector2i(0, 7), Vector2i(12, 3)]:
		var d: PackedVector2Array = Iso.iso_diamond(c2)
		var ctr: Vector2 = Iso.iso_center(c2)
		# points 5 px inside each corner belong to the cell
		for p in d:
			var inside: Vector2 = (p as Vector2).lerp(ctr, 0.12)
			if Iso.iso_cell(inside) != c2:
				corner_ok = false
	t.check("iso_diamond_corners_inside", corner_ok, "points just inside every diamond corner map back to their cell")
	var fp: PackedVector2Array = Iso.iso_footprint(Vector2i(5, 5), 3, 2)
	var slope_ok: bool = absf((fp[2].y - fp[3].y) - Iso.squash() * (fp[2].x - fp[3].x)) < 0.001 and absf((fp[2].y - fp[1].y) - Iso.squash() * (fp[1].x - fp[2].x)) < 0.001
	var centre_ok: bool = Iso.iso_footprint_center(Vector2i(5, 5), 3, 2).distance_to((fp[0] + fp[2]) * 0.5) < 0.001 and Iso.iso_footprint_center(Vector2i(2, 2), 1, 1).distance_to(Iso.iso_center(Vector2i(2, 2))) < 0.001
	t.check("iso_footprint_geometry", slope_ok and centre_ok, "left and right corners lie on the squash slope of the bottom corner; the centre of a 1 x 1 footprint is the tile centre")
	t.check("iso_atlas_coords_periodic", Iso.atlas_coords(Vector2i(5, 7)) == Vector2i(1, 3) and Iso.atlas_coords(Vector2i(-1, 4)) == Vector2i(3, 0) and Iso.atlas_coords(Vector2i(5, 3), Vector2i(2, 2)) == Vector2i(1, 1), "(cell.x % 4, cell.y % 4), water 2 x 2")
	# --- ground / facing helpers
	t.check("iso_dir8_and_steps", Iso.dir8_of(Vector2(0, 1)) == 0 and Iso.dir8_of(Vector2(1, 0)) == 6 and Iso.dir8_of(Vector2(0, -1)) == 4 and Iso.DIR8_TO_CELL_STEP[0] == Vector2i(1, 1) and Iso.DIR8_TO_CELL_STEP[4] == Vector2i(-1, -1), "S row 0, E row 6, N row 4, step S (1,1)")
	var g: Vector2 = Vector2(100, 100)
	t.expect_near(Iso.to_ground(Iso.to_screen(g)).distance_to(g), 0.0, 0.001, "to_ground inverts to_screen")
	# --- AreaMap parser
	var m: AreaMap = AreaMap.parse_text("# c\n@id t1\n@title ZONE_FARM\n@projection iso\n@ambient home\n@zoom 0.7\n@zoom_min 0.35\n@zoom_max 1.2\n@builder res://x.gd\n@weird thing here\n@prop T tree_oak_farm flip=1\n@marker 5 spawn name=s1\n@ground\n###\n#.#\n@objects\n@..\n.5\n")
	t.check("area_map_parse", m.id == &"t1" and m.title == "ZONE_FARM" and m.ambient == &"home" and m.is_builder() and m.theme == &"home" and m.width == 3 and m.height == 2 and m.object_at(Vector2i(0, 0)) == "@" and m.object_at(Vector2i(1, 1)) == "5" and m.props["T"]["prop"] == "tree_oak_farm" and m.props["T"]["flip"] == "1" and m.markers["5"]["name"] == "s1" and m.extra.get("weird", "") == "thing here",
		"an objects row may start with the spawn char; unknown header kept in extra, no warning")
	t.check("area_map_zoom_range", is_equal_approx(m.zoom_range().x, 0.35) and is_equal_approx(m.zoom_range().y, 1.2) and is_equal_approx(m.zoom_default(), 0.7) and AreaMap.parse_text("@ground\n.\n").zoom_range() == Vector2(0.3, 0.7), "header zoom keys; default 0.3 .. 0.7")
	var padded: AreaMap = AreaMap.parse_text("@id p\n@ground\n#...\n#.\n@objects\n..@\n")
	t.check("area_map_padding", padded.width == 4 and padded.ground[1] == "#.##" and padded.objects[1] == "...." and padded.objects[0] == "..@.", "short rows padded with # / .")
	var missing: AreaMap = AreaMap.load_file("res://data/maps/_no_such_map.map")
	t.check("area_map_missing_file_is_quiet", missing == null and AreaMap.last_error != "", "returns null and sets last_error, no engine error: %s" % AreaMap.last_error)
	var cells: Array[Vector2i] = IsoArea.parse_cells("3..4,1;7,0")
	t.check("growth_cells_syntax", cells.size() == 3 and cells.has(Vector2i(3, 1)) and cells.has(Vector2i(4, 1)) and cells.has(Vector2i(7, 0)), "x,y lists and x0..x1,y0..y1 ranges")
	# a mistyped range is clipped to the map BEFORE it is expanded (it used to be expanded whole: a freeze), cells are unique, problems are reported
	var problems: Array[String] = []
	var t0: int = Time.get_ticks_msec()
	var clipped: Array[Vector2i] = IsoArea.parse_cells("0..99999999999999999999,0..3;5..2,1;x,1;4,4;11..30,11;-5..-1,2", Vector2i(12, 12), problems)
	var took: int = Time.get_ticks_msec() - t0
	var uniq: Dictionary = {}
	for c in clipped:
		uniq[c] = true
	t.check("growth_cells_are_clipped_to_the_map", clipped.size() == 12 * 4 + 1 + 1 and uniq.size() == clipped.size() and clipped.has(Vector2i(11, 3)) and clipped.has(Vector2i(4, 4)) and clipped.has(Vector2i(11, 11)) and not clipped.has(Vector2i(12, 0)) and not clipped.has(Vector2i(-5, 2)) and problems.size() == 4 and took < 200,
		"0..99999999999999999999 x 0..3 -> the 12 x 4 cells of the map, a reversed range is swapped (and adds nothing new), 'x,1' is refused, 11..30 is clipped, -5..-1 is outside (4 problems): %d cells, %d ms, problems %s" % [clipped.size(), took, problems])
	var refused: Array[String] = []
	var unbounded: Array[Vector2i] = IsoArea.parse_cells("0..999999,0..999999;2,3", Vector2i(-1, -1), refused)
	t.check("growth_cells_without_a_map_size_refuse_absurd_ranges", unbounded == [Vector2i(2, 3)] and refused.size() == 1, "no map size known: a part naming more than %d cells is refused (%s), the rest parses" % [IsoArea.MAX_PARSED_CELLS, refused])
	# --- the fixtures parse cleanly
	for id in ["_fixture_iso", "_fixture_ortho"]:
		var fm: AreaMap = AreaMap.load_file("res://data/maps/%s.map" % id)
		t.check("fixture_parses_%s" % id, fm != null and fm.errors.is_empty() and fm.id == StringName(id) and fm.width == 12 and fm.height >= 10, "%dx%d errors %s" % [fm.width, fm.height, fm.errors] if fm != null else "no map")
	var fi: AreaMap = AreaMap.load_file("res://data/maps/_fixture_iso.map")
	var ft: AreaMap = AreaMap.load_file("res://data/maps/_fixture_ortho.map")
	var types: Dictionary = {}
	for ch in fi.markers:
		types[fi.markers[ch]["marker"]] = true
	var all_types: Array = ["spawn", "warp", "npc", "enemy", "node", "whisper", "sign", "bed", "quest_spot", "animal_yard", "building_slot", "field_expansion", "light", "growth"]
	var missing_types: Array = all_types.filter(func(x: String) -> bool: return not types.has(x))
	t.check("fixture_iso_has_every_marker_type", missing_types.is_empty(), "missing %s" % [missing_types])
	var iso_count: int = fi.find_objects("1").size() + fi.find_objects("4").size()
	t.check("fixture_iso_places_markers_and_props", fi.find_objects("@").size() == 1 and iso_count == 2 and fi.find_objects("H").size() == 1 and fi.find_objects("M").size() == 1 and fi.walkable_count() > 60, "default spawn, from_other, an enemy, the farmhouse and the mushroom house, %d ground cells" % fi.walkable_count())
	var has_water: bool = false
	var has_bridge: bool = false
	var has_field: bool = false
	for row in fi.ground:
		has_water = has_water or row.contains("~")
		has_bridge = has_bridge or row.contains("=")
		has_field = has_field or row.contains("f")
	t.check("fixture_iso_has_water_bridge_field", has_water and has_bridge and has_field and fi.projection == &"iso", "water, bridge planks and a field")
	t.check("fixture_ortho_has_walls_and_bog", ft.projection == &"ortho" and ft.height == 10 and ft.ground[0].begins_with("WWW") and "".join(ft.ground).contains("~") and ft.ambient == &"forest", "12 x 10 ortho, wall tiles W, bog ~")
	# --- lua/config/props.lua and ambient.lua
	var lua: Node = t.autoload("LuaRuntime")
	var props: Dictionary = lua.get_config("props", {})
	var shapes: Dictionary = {"circle": true, "footprint": true, "bar": true, "none": true}
	var bad_props: Array[String] = []
	for id2 in props:
		var d: Dictionary = props[id2]
		var f: Array = d.get("footprint", [])
		var solid: Dictionary = d.get("solid", {})
		if f.size() != 2 or int(f[0]) < 1 or int(f[1]) < 1 or not shapes.has(str(solid.get("shape", ""))) or int(d.get("strips", -1)) < 0:
			bad_props.append(str(id2))
	t.check("props_lua_entries_valid", props.size() >= 40 and bad_props.is_empty(), "%d props, invalid: %s" % [props.size(), bad_props])
	t.check("props_lua_collision_rules", int(props["tree_oak_farm"]["solid"]["radius"]) == 26 and int(props["rock_grey"]["solid"]["radius"]) == 30 and str(props["bush_farm"]["solid"]["shape"]) == "none" and str(props["house_farm"]["solid"]["shape"]) == "footprint" and int(props["house_farm"]["solid"]["pad"]) == 20 and int(props["house_farm"]["strips"]) == 14 and props["house_farm"]["footprint"] == [3, 2] and int(props["house_mushroom_rose"]["strips"]) == 10 and props["house_mushroom_rose"]["footprint"] == [2, 2],
		"trunk r=26, rock r=30, bushes none, houses footprint + 20 px with strips 14 / 10")
	var amb: Dictionary = lua.get_config("ambient", {})
	var presets: Dictionary = amb.get("presets", {})
	var preset_ok: bool = true
	for pid in ["farm", "hyggebyen", "forest", "cave", "home"]:
		var keys: Array = presets.get(pid, {}).get("keys", [])
		if keys.size() < 2 or float(keys[0]["hour"]) != 0.0 or float(keys[keys.size() - 1]["hour"]) != 24.0:
			preset_ok = false
		var last_h: float = -1.0
		for k in keys:
			if float(k["hour"]) <= last_h:
				preset_ok = false
			last_h = float(k["hour"])
	t.check("ambient_lua_presets", preset_ok and presets.has("home") and not bool(presets["home"]["weather"]) and float(presets["home"]["wind"]) == 0.0 and amb["aliases"]["farm_day"] == "farm" and amb["area_zone"]["hyggebyen"] == "city" and amb["area_zone"]["krystalgrotten"] == "crystal_cave",
		"farm / hyggebyen / forest / cave / home with ascending keyframes 0..24; home: no weather, no wind")
	t.check("ambient_lua_palettes", str(presets["forest"]["keys"][0]["color"]) == "4d5e85" and str(amb["clear"]["forest"]) == "1c2138" and str(amb["clear"]["hyggebyen"]) == "d3c6ee" and str(amb["clear"]["farm"]) == "a9d3e0" and amb["season"].has("vinter") and amb["weather"].has("regn"),
		"guide palettes: navy 1c2138 clear colour of the dark zones, lavender / sky blue, season and weather multipliers")
	# --- localization
	var lm: Node = t.autoload("LocalizationManager")
	var keys_needed: Array[String] = ["UI_SLEEP", "WHISPER_TOO_EARLY", "WHISPER_FAINT", "NOTIF_PASSED_OUT", "NOTIF_PASSED_OUT_TITLE", "WORLD_PROMPT_USE", "WORLD_WARP_LOCKED", "WORLD_NEEDS_ITEMS"]
	var absent: Array[String] = []
	for k in keys_needed:
		if not lm.has_key(k):
			absent.append(k)
	t.check("world_csv_keys_exist", absent.is_empty() and FileAccess.file_exists("res://localization/world.csv.import"), "missing %s" % [absent])
	# --- the legacy 3D world is gone, the world scene is the 2D root
	t.check("legacy_world_files_deleted", not FileAccess.file_exists("res://scripts/world/world.gd") and not FileAccess.file_exists("res://scripts/world/zone_trigger.gd"), "scripts/world/world.gd and zone_trigger.gd")
	var packed: PackedScene = load("res://scenes/main/world.tscn") as PackedScene
	var root_node: Node = packed.instantiate()
	t.check("world_scene_is_node2d_with_world_root", root_node is Node2D and root_node is WorldRoot2D and root_node.get_child_count() == 0, "scenes/main/world.tscn: %s" % root_node.get_class())
	root_node.free()
	# --- source lints of the files this package owns
	var offenders_zone: Array[String] = []
	var offenders_mouse: Array[String] = []
	var offenders_da: Array[String] = []
	var rx_da := RegEx.new()
	rx_da.compile("\"[^\"\\n]*[æøåÆØÅ][^\"\\n]*\"")
	for path in _gd_files("res://scripts"):
		var text: String = FileAccess.get_file_as_string(path)
		if text.contains("zone_entered.emit(") and not path.ends_with("scripts/world2d/world_2d.gd"):
			offenders_zone.append(path)
		if text.contains("mouse_mode") and path.contains("scripts/world2d/"):
			offenders_mouse.append(path)
		if path.contains("scripts/world2d/"):
			for line in text.split("\n"):
				var code: String = line.get_slice("#", 0)
				if rx_da.search(code) != null:
					offenders_da.append("%s: %s" % [path, line.strip_edges().left(50)])
	t.check("zone_entered_only_from_world_root", offenders_zone.is_empty(), "other emitters: %s" % [offenders_zone])
	t.check("no_mouse_capture_in_world_scripts", offenders_mouse.is_empty(), "%s" % [offenders_mouse])
	t.check("no_danish_literals_in_world_scripts", offenders_da.is_empty(), "%s" % [offenders_da.slice(0, 3)])
	var da_in_lua: Array[String] = []
	for path2 in ["res://lua/config/props.lua", "res://lua/config/ambient.lua"]:
		var body: String = FileAccess.get_file_as_string(path2)
		if rx_da.search(body) != null:
			da_in_lua.append(path2)
	t.check("no_danish_text_in_world_lua", da_in_lua.is_empty(), "%s" % [da_in_lua])


func _gd_files(root_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			out.append_array(_gd_files(root_path.path_join(sub)))
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root_path.path_join(f))
	return out


# ================================================================== ArtCatalog and the placeholder boot cost (before any world)

func _art_and_boot_cost(t) -> void:
	IsoArea.clear_handler_cache()
	var holder := Node2D.new()
	t.root.add_child(holder)
	var m: AreaMap = AreaMap.load_file("res://data/maps/_fixture_iso.map")
	# the cost of painting every placeholder of the iso fixture from cold: best of up to 4 cold builds (a team build machine is busy with
	# other jobs and wall time is noisy; a real regression is slow in EVERY attempt). The same set painted at FULL resolution (what the
	# world spike did, 650 ms) is measured in the same run as the load-independent yardstick.
	PlaceholderArt.full_quality = true
	ArtCatalog.reset()
	AreaTileSet.reset()
	var af := IsoArea.new()
	holder.add_child(af)
	af.setup(m)
	var full_paint: float = ArtCatalog.paint_ms()
	af.free()
	PlaceholderArt.full_quality = false
	var best_paint: float = 1e9
	var first_ms: int = 0
	var attempts: int = 0
	var a: IsoArea = null
	for attempt in 4:
		ArtCatalog.reset()
		AreaTileSet.reset()
		if a != null:
			a.free()
		a = IsoArea.new()
		holder.add_child(a)
		var t0: int = Time.get_ticks_msec()
		a.setup(m)
		var ms: int = Time.get_ticks_msec() - t0
		attempts += 1
		if ArtCatalog.paint_ms() < best_paint:
			best_paint = ArtCatalog.paint_ms()
			first_ms = ms
		if best_paint < 200.0:
			break
	var cached_before: float = ArtCatalog.paint_ms()
	var a2 := IsoArea.new()
	holder.add_child(a2)
	var t1: int = Time.get_ticks_msec()
	a2.setup(AreaMap.load_file("res://data/maps/_fixture_iso.map"))
	var second_ms: int = Time.get_ticks_msec() - t1
	t.check("placeholder_boot_cost", best_paint < 200.0 or best_paint * 3.25 <= full_paint, "painting the placeholders of the iso fixture from cold (%d terrains / props / backdrop painted) took %.0f ms of a %d ms build (best of %d cold builds; budget 200 ms on an idle machine, i.e. at least 3.25x faster than the %.0f ms the same set costs at full resolution, the spike's 650 ms)" % [ArtCatalog.missing().size(), best_paint, first_ms, attempts, full_paint])
	t.check("placeholders_are_cached", absf(ArtCatalog.paint_ms() - cached_before) < 0.5, "a second build of the same area painted %.2f ms more and took %d ms (cold build %d ms)" % [ArtCatalog.paint_ms() - cached_before, second_ms, first_ms])
	# expected missing set: exactly the ids of the fixture that have no real asset
	var wanted: Dictionary = {}
	var ids_terrain: Dictionary = {}
	for v in a._terrain_of.values():
		ids_terrain[v] = true
	for wid in AreaTileSet.WATER_FRAMES:
		ids_terrain[wid] = true
	for tid in ids_terrain:
		if not ArtCatalog.has_real_terrain(tid):
			wanted["terrain:%s" % tid] = true
	var prop_ids: Dictionary = {String(a.skirt_nodes[a.skirt_nodes.keys()[0]].get_meta("skirt")): true, "platform_sw": true, "platform_se": true, "platform_corner": true}
	for rec in a.prop_nodes:
		prop_ids[str(rec["id"])] = true
	for pid in prop_ids:
		if not ArtCatalog.has_real_prop(StringName(pid)):
			wanted["prop:%s" % pid] = true
	var got: Dictionary = {}
	for k in ArtCatalog.missing():
		got[k] = true
	var extra_ids: Array = got.keys().filter(func(k: String) -> bool: return not wanted.has(k) and not k.begins_with("backdrop:"))
	var absent_ids: Array = wanted.keys().filter(func(k: String) -> bool: return not got.has(k))
	t.check("artcatalog_missing_expected", extra_ids.is_empty() and absent_ids.is_empty(), "missing() lists only fixture ids without a real asset: %d ids; unexpected %s, not listed %s" % [got.size(), extra_ids.slice(0, 4), absent_ids.slice(0, 4)])
	t.info("ArtCatalog.missing() of the iso fixture (%d): %s" % [ArtCatalog.missing().size(), ", ".join(ArtCatalog.missing())])
	# every terrain / prop answer is drawable and the same shape as the real art entry
	var tex_ok: bool = true
	for tid2 in AreaTileSet.ISO_TERRAINS + AreaTileSet.ORTHO_TERRAINS:
		var info: Dictionary = ArtCatalog.terrain(tid2)
		var cell: Vector2i = info["cell"]
		var variants: Vector2i = info["variants"]
		var tx: Texture2D = info["texture"]
		if tx == null or tx.get_width() != cell.x * variants.x or tx.get_height() != cell.y * variants.y:
			tex_ok = false
	t.check("terrain_atlas_shape", tex_ok, "every terrain id of the contract answers an atlas of variants x cell (placeholders 144x84 x 4x4, water 2x2, ortho 112x64)")
	var prop_ok: bool = true
	for pid2 in ["tree_oak_farm", "house_farm", "house_mushroom_rose", "platform_sw", "platform_se", "platform_corner", "bridge_x", "bridge_z", "lantern_post", "fence_x", "forest_wall_a", "some_unknown_prop_id"]:
		var pr: Dictionary = ArtCatalog.prop(StringName(pid2))
		var ptx: Texture2D = pr["texture"]
		var pv: Vector2 = pr["pivot"]
		if ptx == null or pv.x <= 0 or pv.y <= 0 or pv.x >= ptx.get_width() or pv.y >= ptx.get_height() or Vector2(ptx.get_size()) != (pr["size"] as Vector2):
			prop_ok = false
	t.check("prop_entry_shape", prop_ok, "placeholder props carry texture, pivot inside the image and size like a props.json entry (unknown ids get a generic block)")
	var sk: Dictionary = ArtCatalog.prop(&"platform_sw")
	var sk_p: Vector2 = sk["pivot"]
	var sk_s: Vector2 = sk["size"]
	t.check("skirt_placeholders_follow_the_real_pivots", sk_p == Vector2(73, 13) and sk_s == Vector2(79, 143) and (ArtCatalog.prop(&"platform_se")["pivot"] as Vector2) == Vector2(6, 13) and (ArtCatalog.prop(&"platform_corner")["size"] as Vector2) == Vector2(146, 146) or ArtCatalog.has_real_prop(&"platform_sw"), "platform_sw 79x143 pivot (73,13), platform_se pivot (6,13), platform_corner 146x146")
	var bd: Dictionary = ArtCatalog.backdrop(&"hyggebyen")
	t.check("backdrop_has_sky_and_far", bd["sky"] != null and bd["far"] != null and ArtCatalog.backdrop(&"nonsense_theme")["sky"] != null, "gradient sky + canopy haze when assets/backdrops is empty")
	t.check("icon_and_portrait_fallbacks", ArtCatalog.icon(&"no_such_item_icon") != null and ArtCatalog.portrait(&"no_such_portrait") != null and ArtCatalog.missing().has("icon:no_such_item_icon") and ArtCatalog.missing().has("portrait:no_such_portrait"), "icon 128 and portrait badge fallbacks are recorded")
	t.check("character_exists", ArtCatalog.character_exists("fox") and ArtCatalog.character_exists("hobbit_pip") and not ArtCatalog.character_exists("no_such_character_xyz"), "fox exists, hobbit_pip draws through its fallback chain, an unknown id does not (no warning)")
	# TileSet: contract shape of both projections
	var iso_set: Dictionary = AreaTileSet.get_set(&"iso")
	var ts: TileSet = iso_set["tileset"]
	var src_id: int = AreaTileSet.source_for(&"iso", &"grass")
	var src: TileSetAtlasSource = ts.get_source(src_id)
	t.check("tileset_iso_contract", ts.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC and ts.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN and ts.tile_size == Vector2i(128, 76) and src.texture_region_size == Vector2i(144, 84) and ts.get_physics_layers_count() == 2 and ts.get_physics_layer_collision_layer(0) == 128 and ts.get_physics_layer_collision_layer(1) == 1,
		"ISOMETRIC + DIAMOND_DOWN, tile 128x76, region 144x84, physics layer 0 -> 128, layer 1 -> 1")
	t.check("tileset_iso_periodic_tiles", src.get_tiles_count() == 16 and src.has_tile(Vector2i(3, 3)) and AreaTileSet.source_for(&"iso", &"water_0") != src_id and (ts.get_source(AreaTileSet.source_for(&"iso", &"water_0")) as TileSetAtlasSource).get_tiles_count() == 4, "4 x 4 variants per terrain, water 2 x 2")
	var water0: TileSetAtlasSource = ts.get_source(AreaTileSet.source_for(&"iso", &"water_0"))
	var water1: TileSetAtlasSource = ts.get_source(AreaTileSet.source_for(&"iso", &"water_1"))
	var blocker: TileSetAtlasSource = ts.get_source(AreaTileSet.SRC_BLOCKER)
	t.check("tileset_physics_water_0_only", water0.get_tile_data(Vector2i(0, 0), 0).get_collision_polygons_count(0) == 1 and water1.get_tile_data(Vector2i(0, 0), 0).get_collision_polygons_count(0) == 0 and src.get_tile_data(Vector2i(0, 0), 0).get_collision_polygons_count(0) == 0 and blocker.get_tile_data(Vector2i(0, 0), 0).get_collision_polygons_count(0) == 1,
		"ground_block polygons on the water_0 tiles and the invisible blocker tile only")
	var ortho_ts: TileSet = AreaTileSet.tile_set(&"ortho")
	t.check("tileset_ortho_contract", ortho_ts.tile_shape == TileSet.TILE_SHAPE_SQUARE and ortho_ts.tile_size == Vector2i(96, 56) and ortho_ts.get_physics_layers_count() == 2, "SQUARE 96 x 56 with the same two physics layers")
	var wall_sid: int = AreaTileSet.wall_source_for(&"forest_wall_a")
	var wall_td: TileData = (ortho_ts.get_source(wall_sid) as TileSetAtlasSource).get_tile_data(Vector2i(0, 0), 0)
	t.check("tileset_ortho_wall_tile", wall_td.y_sort_origin == 28 and wall_td.get_collision_polygons_count(1) == 1, "wall tile: y_sort_origin +H/2 (28), solid on the world physics layer")
	a.queue_free()
	a2.queue_free()
	holder.queue_free()
	await t.frames(2)


# ================================================================== geometry of the live world

func _geometry(t) -> void:
	var start_id: StringName = _world.area.map.id
	if start_id != &"_fixture_iso":
		_world._enter(&"_fixture_iso", &"default")
	var a: IsoArea = _world.area
	var ok: bool = true
	var seen: String = ""
	for c in [Vector2i(0, 0), Vector2i(5, 3), Vector2i(11, 11), Vector2i(7, 9), Vector2i(2, 10)]:
		var p: Vector2 = a.ground.map_to_local(c)
		var q: Vector2 = a.ground.to_local(a.cell_to_global(c))
		if p.distance_to(Iso.iso_center(c)) > 0.01 or q.distance_to(p) > 0.01 or a.global_to_cell(a.cell_to_global(c)) != c:
			ok = false
			seen = "cell %s map_to_local %s iso_center %s" % [c, p, Iso.iso_center(c)]
	t.check("geometry", ok, "Iso.iso_center == TileMapLayer.map_to_local and cell <-> world round-trips %s" % seen)
	var rnd_ok: bool = true
	for i in 300:
		var p2 := Vector2(t.rng.randf_range(-200.0, 1500.0), t.rng.randf_range(0.0, 900.0))
		var cc: Vector2i = Iso.iso_cell(p2)
		var ctr: Vector2 = Iso.iso_center(cc)
		var edge: float = 1.0 - (absf(p2.x - ctr.x) / (Iso.TILE_W * 0.5) + absf(p2.y - ctr.y) / (Iso.TILE_H * 0.5))
		if edge > 0.03 and a.ground.local_to_map(p2) != cc:
			rnd_ok = false
	t.check("geometry_random_points", rnd_ok, "Iso.iso_cell agrees with TileMapLayer.local_to_map for 300 random points")
	t.check("ground_layer_contract", a.ground.tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC and a.ground.z_index == -10 and a.ground.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and a.objects.y_sort_enabled and a.objects.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and a.ground_fx.z_index == -9 and a.backdrop.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"Ground z -10 filter 2 (no mipmaps), Objects y-sorted filter 4, GroundFx z -9, Backdrop filter 4 (R.1)")
	var periodic: bool = true
	for y in range(2, 8):
		for x in range(1, 10):
			var c2 := Vector2i(x, y)
			if a.cell_kind(c2) == &"grass" and a.ground.get_cell_atlas_coords(c2) != Vector2i(x % 4, y % 4):
				periodic = false
	t.check("atlas_coords_are_periodic", periodic, "atlas coords of the painted grass = Vector2i(cell.x % 4, cell.y % 4)")
	t.check("farmable_cells", a.is_farmable(Vector2i(8, 4)) and not a.is_farmable(Vector2i(2, 4)) and a.farmable.size() == 12, "'f' ground chars are tillable: %d cells" % a.farmable.size())
	t.check("spawns_parsed", a.spawns.has("default") and a.spawns.has("from_other") and a.get_spawn("nope") == a.spawns["default"], "spawn markers + the default spawn char, unknown names fall back to default")
	t.check("backdrop_parallax", a.backdrop.get_child_count() == 2 and a.backdrop.get_child(0) is Parallax2D and a.backdrop.get_child(1) is Parallax2D and a.backdrop.z_index == -20, "sky + far canopy as two Parallax2D behind the platform")
	if start_id != &"_fixture_iso":
		_world._enter(start_id, &"default")


# ================================================================== the player stub

func _player_stub_contract(t) -> void:
	var p: Node2D = _world.player
	var a: IsoArea = _world.area
	var scene_exists: bool = ResourceLoader.exists(WorldRoot2D.PLAYER_SCENE_PATH)
	t.check("player_stub_contract_class", scene_exists or p is PlayerStub2D, "world loads %s: %s" % [WorldRoot2D.PLAYER_SCENE_PATH if scene_exists else "the stub (player_2d.tscn does not exist yet)", p.get_class()])
	var members: Array[String] = ["enter_area", "take_damage", "begin_talk", "end_talk", "revive", "set_character"]
	var absent: Array[String] = []
	for mth in members:
		if not p.has_method(mth):
			absent.append(mth)
	t.check("player_stub_contract", p.is_in_group("player") and absent.is_empty() and p.get_parent() == a.objects and p.collision_layer == 2 and p.collision_mask == 197 and p.get("camera") is Camera2D and (p.get("camera") as Camera2D).is_current() and p.get("visual") is IsoChibiSprite2D,
		"group player, in Objects, layer 2 / mask 197, camera current, IsoChibiSprite2D visual, methods; absent: %s" % [absent])
	var hearts_before: int = int(p.get("half_hearts"))
	p.call("take_damage", 3, Vector2(10, 10))
	t.check("player_stub_take_damage_is_a_noop", int(p.get("half_hearts")) == hearts_before, "hearts %d unchanged" % hearts_before)
	var cam: Camera2D = p.get("camera")
	t.check("player_stub_camera_settings", cam.position_smoothing_enabled and is_equal_approx(cam.position_smoothing_speed, 6.0) and cam.limit_smoothed and is_equal_approx(cam.zoom.x, Iso.DEFAULT_ZOOM), "smoothing 6, limit_smoothed, zoom %.2f" % cam.zoom.x)
	# camera limits follow the playable rect (centred when smaller than the view)
	var r: Rect2 = IsoArea.camera_limits_for(a.camera_rect(), p.get_viewport().get_visible_rect().size / cam.zoom.x)
	t.check("player_stub_camera_limits", cam.limit_left == int(r.position.x) and cam.limit_right == int(r.end.x) and cam.limit_top == int(r.position.y) and cam.limit_bottom == int(r.end.y), "limits %s" % [r])
	var small: Rect2 = IsoArea.camera_limits_for(Rect2(0, 0, 100, 50), Vector2(400, 300))
	t.check("camera_limits_center_small_rects", small.size == Vector2(400, 300) and small.get_center().is_equal_approx(Vector2(50, 25)), "a rect smaller than the view is centred (Camera2D limits smaller than the view stick to the top-left)")
	# hero visual comes from the skin chain
	var gm: Node = t.autoload("GameManager")
	t.check("player_visual_from_skin_chain", (p.get("visual") as IsoChibiSprite2D).character_id == GameData.visual_for_skin(StringName(str(gm.get("character_skin")))) and (p.get("visual") as IsoChibiSprite2D).resolved_id != "", "visual %s -> art folder %s" % [(p.get("visual") as IsoChibiSprite2D).character_id, (p.get("visual") as IsoChibiSprite2D).resolved_id])
	# GameData (P05 handoff): skins through CharacterCatalog
	t.check("game_data_skins_through_character_catalog", GameData.visual_for_skin(&"animal_fox") == CharacterCatalog.visual_for_skin(&"animal_fox", "animal") and GameData.resolved_visual_for_skin(&"animal_fox") == CharacterCatalog.resolved_visual_for_skin(&"animal_fox", "animal") and GameData.visual_for_skin(&"fairy_stardust") == CharacterCatalog.visual_for_skin(&"fairy_stardust", GameData.race_key()) and GameData.stock_visual_for_skin(&"animal_fox") == "fox",
		"fox_base head of the chain, art folder %s, stock %s" % [GameData.resolved_visual_for_skin(&"animal_fox"), GameData.stock_visual_for_skin(&"animal_fox")])
	t.check("game_data_race_and_config", GameData.race_key() in ["animal", "fairy", "hobbit", "ghost"] and not CharacterCatalog.race(GameData.race_key()).is_empty() and is_equal_approx(float(GameData.player_cfg("walk_speed", 0.0)), 285.0) and is_equal_approx(float(GameData.combat("swing_radius", 0.0)), 197.0), "race %s, player.walk_speed 285 and combat.swing_radius 197 from lua/config" % GameData.race_key())


# ================================================================== registry, default area, fixtures through the world

func _registry_and_default(t) -> void:
	var reg: Dictionary = WorldRoot2D.scan_maps(true)
	t.check("registry_scans_data_maps", reg.has(&"_fixture_iso") and reg.has(&"_fixture_ortho") and bool(reg[&"_fixture_iso"]["fixture"]), "ids from @id: %s" % [reg.keys()])
	var real_ids: Array = WorldRoot2D.area_ids(false)
	var all_ids: Array = WorldRoot2D.area_ids(true)
	t.check("registry_fixtures_are_flagged", not real_ids.has(&"_fixture_iso") and all_ids.has(&"_fixture_iso") and all_ids.has(&"_fixture_ortho"), "real areas %s" % [real_ids])
	var want: StringName = &"farm" if FileAccess.file_exists("res://data/maps/farm.map") else &"_fixture_iso"
	t.check("default_area_falls_back_to_the_fixture", WorldRoot2D.default_area_id() == want and _world.area.map.id == want, "farm.map %s -> start area %s" % ["exists" if want == &"farm" else "does not exist yet", _world.area.map.id])
	var last_err: String = _world.last_travel_error
	_world.travel(&"no_such_area", &"default")
	t.check("travel_to_unknown_area_is_quiet", _world.area.map.id == want and _world.last_travel_error.begins_with("no such area") and not _world.traveling, "stays in %s, last_travel_error '%s' (was '%s')" % [want, _world.last_travel_error, last_err])
	t.check("intro_flag_waits_for_the_script", bool(t.autoload("GameManager").get_flag(&"intro_pending", false)) == not ResourceLoader.exists(WorldRoot2D.INTRO_PATH), "intro_pending stays set while scripts/world2d/intro_sequence.gd does not exist (P14)")


func _fixture_build(t) -> void:
	var a: IsoArea = _world.area
	if a.map.id != &"_fixture_iso":
		_world._enter(&"_fixture_iso", &"default")
		a = _world.area
	t.check("fixture_iso_built", a.build_ms >= 0 and a.prop_nodes.size() >= 12 and a.unknown_chars.is_empty() and a.markers.size() >= 13 and a.map.errors.is_empty(), "%d props, %d markers, %d skirts, unknown chars %s, %d ms" % [a.prop_nodes.size(), a.markers.size(), a.skirt_nodes.size(), a.unknown_chars, a.build_ms])
	var tree_cnt: int = _t.count_group(&"prop_tree")
	t.check("trees_are_in_group_prop_tree", tree_cnt >= 1, "%d trees" % tree_cnt)
	# solid props: a StaticBody2D per solid prop on layer world, none for bushes
	var bodies: Array = a.colliders.get_children()
	var tree_body: StaticBody2D = null
	var bush_has_body: bool = false
	for rec in a.prop_nodes:
		if rec["id"] == "tree_oak_farm" and rec["body"] != null:
			tree_body = rec["body"]
		if rec["id"] == "bush_farm" and rec["body"] != null:
			bush_has_body = true
	t.check("solid_props_have_colliders", tree_body != null and tree_body.collision_layer == 1 and tree_body.collision_mask == 0 and not bush_has_body and bodies.size() >= 8, "trunk body on layer world (1), bushes none, %d bodies" % bodies.size())
	if tree_body != null:
		var shape: ConvexPolygonShape2D = (tree_body.get_child(0) as CollisionShape2D).shape
		var xs: float = 0.0
		var ys: float = 0.0
		for p in shape.points:
			xs = maxf(xs, absf(p.x))
			ys = maxf(ys, absf(p.y))
		t.check("trunk_collider_is_a_flattened_circle", absf(xs - 26.0) < 0.5 and absf(ys - 26.0 * Iso.squash()) < 0.5, "ground r 26 -> screen ellipse %.1f x %.1f" % [xs, ys])
	var fence_ok: bool = false
	for rec2 in a.prop_nodes:
		if rec2["id"] == "fence_x" and rec2["body"] != null:
			var fs: ConvexPolygonShape2D = ((rec2["body"] as StaticBody2D).get_child(0) as CollisionShape2D).shape
			var minx: float = 1e9
			var maxx: float = -1e9
			for p2 in fs.points:
				minx = minf(minx, p2.x)
				maxx = maxf(maxx, p2.x)
			fence_ok = maxx - minx > 60.0
	t.check("fence_collider_is_a_bar_along_the_axis", fence_ok, "fence_x blocks along its cell axis")
	var house: Dictionary = {}
	for rec3 in a.prop_nodes:
		if rec3["id"] == "house_farm":
			house = rec3
	var hb: StaticBody2D = house["body"]
	var hshape: ConvexPolygonShape2D = (hb.get_child(0) as CollisionShape2D).shape
	var fpg: PackedVector2Array = Iso.iso_footprint(house["cell"], 3, 2)
	var width_h: float = 0.0
	for p3 in hshape.points:
		width_h = maxf(width_h, absf(p3.x))
	var inner_w: float = (fpg[1].x - fpg[3].x) * 0.5
	t.check("house_collider_is_the_padded_footprint", width_h > inner_w + 15.0 and hb.position.distance_to(Iso.iso_footprint_center(house["cell"], 3, 2)) < 0.01, "footprint half-width %.0f + pad -> %.0f; the body sits at the footprint centre" % [inner_w, width_h])
	# The facade's light mask must stay on its painted windows when the building
	# is sliced for sorting; the first strip's origin is not the house origin.
	var house_art: Dictionary = ArtCatalog.prop(&"house_farm")
	var window_glow: Dictionary = house_art.get("glow", {})
	var house_parts: Array = house["nodes"]
	var halo_node := (house_parts[0] as Node2D).get_node_or_null("Glow") as Sprite2D
	var glow_aligned := false
	if halo_node != null and not window_glow.is_empty():
		var image_origin: Vector2 = Iso.iso_footprint_center(house["cell"], 3, 2) - (house_art["pivot"] as Vector2)
		var expected: Vector2 = a.objects.to_global(image_origin + (window_glow["center"] as Vector2))
		glow_aligned = halo_node.global_position.distance_to(expected) < 0.01
	t.check("sliced_house_glow_matches_windows", glow_aligned and house_parts.size() > 1, "the sliced farmhouse light mask stays on the painted facade's image coordinates")
	var contact := house.get("ground") as Sprite2D
	t.check("building_contact_is_on_ground", contact != null and contact.get_parent() == a.ground_fx and contact.position.distance_to(hb.position) < 0.01 and a.ground_fx.z_index < a.objects.z_index,
		"building contact shares the collision footprint centre and draws below the y-sorted actors")
	t.check("building_contact_is_part_of_prop", contact != null and contact in a.prop_parts(house_parts[0]) and house_parts[0] in a.prop_parts(contact),
		"ground contact follows the building's visibility and lifecycle, from either part")
	var temporary := a.place_prop("house_farm", Vector2i(2, 2))
	var temporary_contact := a.prop_nodes.back().get("ground") as Sprite2D
	var removed := a.remove_prop(temporary)
	t.check("removing_building_removes_contact", removed and temporary_contact != null and temporary_contact.is_queued_for_deletion() and a.prop_parts(temporary_contact).is_empty() and a.prop_parts(null).is_empty() and not a.remove_prop(null),
		"removing a building also removes its ground layer, and null never matches an unrelated prop")
	# glow and lights ramp in with the night factor
	a.set_night_factor(0.0)
	var halo_off: bool = true
	for g in a._glows:
		if (g["node"] as CanvasItem).visible:
			halo_off = false
	a.set_night_factor(1.0)
	var halo_on: bool = not a._glows.is_empty()
	for g2 in a._glows:
		if not (g2["node"] as CanvasItem).visible or (g2["node"] as CanvasItem).modulate.a < 0.4:
			halo_on = false
	var lights_on: bool = not a._lights.is_empty()
	for l in a._lights:
		if (l["node"] as PointLight2D).energy < 0.4:
			lights_on = false
	t.check("glow_and_lights_ramp_with_night", halo_off and halo_on and lights_on and a._glows.size() >= 2 and a._lights.size() >= 2, "%d additive glows and %d PointLights: hidden at factor 0, on at 1" % [a._glows.size(), a._lights.size()])
	a.set_night_factor(0.0)
	# the Objects layer holds the props, y-sorted; the player stands in it
	t.check("objects_layer_holds_props_and_player", a.objects.get_child_count() >= a.prop_nodes.size() and _world.player.get_parent() == a.objects, "%d children of Objects" % a.objects.get_child_count())
	# the ortho fixture builds too (walls, bog) - through a throwaway area so the world stays put
	var holder := Node2D.new()
	t.root.add_child(holder)
	var oa := IsoArea.new()
	holder.add_child(oa)
	oa.setup(AreaMap.load_file("res://data/maps/_fixture_ortho.map"))
	var wall_cells: int = oa.walls.get_used_cells().size()
	var bog_blocks: bool = oa.ground.get_cell_source_id(Vector2i(9, 4)) == AreaTileSet.source_for(&"ortho", &"bog_o")
	t.check("fixture_ortho_built", oa.projection == &"ortho" and oa.walls != null and wall_cells >= 38 and bog_blocks and oa.skirt_nodes.is_empty() and oa.backdrop.get_child_count() == 0 and oa.camera_rect() == oa.play_rect and oa.play_rect.size == Vector2(12 * 96, 10 * 56),
		"%d wall tiles, bog on ground_block, no skirts, no backdrop, camera = the map %s" % [wall_cells, oa.play_rect])
	var wall_sort_ok: bool = oa.walls.y_sort_enabled and oa.walls.get_parent() == oa.objects
	t.check("ortho_walls_are_ysorted_in_objects", wall_sort_ok, "Walls TileMapLayer y-sorted inside Objects")
	holder.queue_free()
	await t.frames(2)


# ================================================================== markers

func _marker_handlers(t) -> void:
	var a: IsoArea = _world.area
	# every marker type: built in or through a handler script, else skipped silently and counted
	var inconsistent: Array[String] = []
	var by_type: Dictionary = {}
	for m in a.markers:
		by_type[str(m["type"])] = int(by_type.get(str(m["type"]), 0)) + 1
	for type in by_type:
		var h: Dictionary = IsoArea.resolve_handler(type)
		var handled: int = a.handled_count(type)
		var skipped: int = int(a.skipped_markers.get(type, 0))
		if str(h["kind"]) == "none" and not (skipped == by_type[type] and handled == 0):
			inconsistent.append("%s none: handled %d skipped %d of %d" % [type, handled, skipped, by_type[type]])
		if str(h["kind"]) != "none" and skipped != 0 and str(h["kind"]) == "builtin":
			inconsistent.append("%s builtin skipped %d" % [type, skipped])
	t.check("marker_handlers", inconsistent.is_empty() and by_type.size() >= 12, "%d marker types: %s; skipped silently %s" % [by_type.size(), inconsistent, a.skipped_markers])
	var lazy_types: Array = ["npc", "enemy", "node", "whisper", "animal_yard", "building_slot", "field_expansion"]
	var skipped_known: bool = true
	for lt in lazy_types:
		if IsoArea.resolve_handler(lt)["kind"] == "none" and by_type.has(lt) and not a.skipped_markers.has(lt):
			skipped_known = false
	t.check("lazy_markers_skip_while_scripts_are_missing", skipped_known, "types whose script is absent or has no entry point are counted in skipped_markers")
	t.check("markers_are_recorded_for_their_consumers", a.find_markers("animal_yard").size() == 1 and a.find_markers("building_slot").size() == 1 and a.find_markers("field_expansion").size() == 1 and (a.find_markers("field_expansion")[0]["params"] as Dictionary).get("price", "") == "800" and a.find_markers("animal_yard")[0]["cell"] is Vector2i,
		"animal_yard / building_slot / field_expansion stay readable through find_markers() with cell and position")
	# warp: a trigger Area2D with the target
	var warp: Warp2D = a.triggers.get_child(0) as Warp2D
	t.check("warp_marker", warp != null and warp.to_area == &"_fixture_ortho" and warp.to_spawn == &"from_iso" and warp.label_key == "ZONE_DARK_FOREST" and warp.collision_mask == 2 and warp.is_in_group("warp") and warp.is_open(), "warp to %s:%s, mask player" % [warp.to_area, warp.to_spawn])
	# sign: interact -> whisper with the key; prompt UI_READ
	var sign_node: Interactable2D = _find_node(a.objects, "Sign_")
	var bed_node: Interactable2D = a.objects.get_node_or_null("Bed") as Interactable2D
	t.check("interactable_base", sign_node != null and sign_node.is_in_group("interactable") and sign_node.get_node("InteractArea").collision_layer == 8 and sign_node.get_node("InteractArea").collision_mask == 0 and sign_node.prompt_key == "UI_READ", "group interactable, Area2D on layer 4 (value 8), prompt key UI_READ")
	_seen.clear()
	var cb: Callable = func(k: String) -> void: _seen.append(k)
	t.autoload("EventBus").whisper_requested.connect(cb)
	sign_node.interact(_world.player)
	t.check("sign_interaction_whispers_its_key", _seen == ["ZONE_FARM"], "whispers %s" % [_seen])
	t.check("bed_marker", bed_node != null and bed_node.prompt_key == "UI_SLEEP" and bed_node.get_interaction_prompt() == tr_key("UI_SLEEP"), "bed prompt UI_SLEEP")
	t.autoload("EventBus").whisper_requested.disconnect(cb)
	# disabling an interactable hides it and removes its Area2D from the query layer
	sign_node.set_enabled(false)
	var layer_off: int = sign_node.get_node("InteractArea").collision_layer
	sign_node.set_enabled(true)
	t.check("interactable_set_enabled", layer_off == 0 and sign_node.visible and sign_node.get_node("InteractArea").collision_layer == 8, "disabled -> layer 0, enabled -> layer 8")
	# the player's E query finds the sign at the facing cell
	var p: Node2D = _world.player
	var sign_cell: Vector2i = a.global_to_cell(sign_node.global_position)
	p.global_position = a.cell_to_global(sign_cell - Vector2i(1, 1))
	p.set("facing8", 0)
	await t.physics(3)
	var found: Node = p.call("nearest_interactable")
	t.check("player_query_finds_interactables", found != null and found.is_in_group("interactable"), "E-query (r = 45 ground px, layer interactable) found %s" % [found.name if found != null else "nothing"])
	# a light marker is a PointLight2D that ramps in with the night
	var light_holder: Node2D = a.objects.get_node_or_null("Light_lantern") as Node2D
	t.check("light_marker", light_holder != null and light_holder.get_child(0) is PointLight2D, "PointLight2D + halo under Objects/Light_lantern")
	# quest_spot: needs + consume
	var qa: Node = a.find_markers("quest_spot")[0]["node"]
	t.check("quest_spot_is_an_interactable", qa is Interactable2D, "quest_spot builds an Interactable2D")
	await _quest_spot(t)
	# warp: the player walking into it asks for the area change (once the door is open)
	await _warp_walk(t)
	await _warp_when(t)


func tr_key(k: String) -> String:
	return _world.tr(k)


func _find_node(under: Node, prefix: String) -> Node:
	for c in under.get_children():
		if c.name.begins_with(prefix):
			return c
	return null


func _quest_spot(t) -> void:
	var map: AreaMap = AreaMap.parse_text("@id _t_quest\n@projection iso\n@theme farm\n@marker q quest_spot quest=lost_cat objective=follow_pawprints prompt=WORLD_PROMPT_USE needs=wood:2 consume=1\n@ground\n#####\n#...#\n#...#\n#####\n@objects\n.....\n..q..\n.....\n.....\n")
	var holder := Node2D.new()
	_t.root.add_child(holder)
	var a := IsoArea.new()
	holder.add_child(a)
	a.setup(map)
	var spot: Interactable2D = a.find_markers("quest_spot")[0]["node"]
	var eco: Node = _t.autoload("EconomyManager")
	while eco.count_item(&"wood") > 0:
		eco.remove_item(&"wood", 1)
	_seen.clear()
	var cb: Callable = func(k: String) -> void: _seen.append(k)
	_t.autoload("EventBus").whisper_requested.connect(cb)
	spot.interact(_world.player)
	var short_ok: bool = _seen == ["WORLD_NEEDS_ITEMS"] and eco.count_item(&"wood") == 0
	eco.add_item(&"wood", 3)
	spot.interact(_world.player)
	var consumed: bool = eco.count_item(&"wood") == 1 and _seen == ["WORLD_NEEDS_ITEMS"]
	_t.autoload("EventBus").whisper_requested.disconnect(cb)
	while eco.count_item(&"wood") > 0:
		eco.remove_item(&"wood", 1)
	_t.check("quest_spot_needs_and_consume", short_ok and consumed and spot.prompt_key == "WORLD_PROMPT_USE", "missing wood -> whisper and nothing taken; with wood 2 of 3 are consumed")
	# the objective is REPORTED to QuestManager: complete_manual(quest, objective) once (P13), update_objective(quest, objective, 1) as long
	# as that does not exist (the legacy autoload); nothing is reported while the items are missing. Recorder stubs stand in for the autoload.
	var interact: Callable = func() -> void: spot.interact(_world.player)
	var calls_short: Array = _with_quest_manager(FakeQuestManager.new(), interact)       # no wood in the bag
	eco.add_item(&"wood", 2)
	var calls_modern: Array = _with_quest_manager(FakeQuestManager.new(), interact)
	var wood_left: int = eco.count_item(&"wood")
	eco.add_item(&"wood", 2)
	var calls_legacy: Array = _with_quest_manager(LegacyQuestManager.new(), interact)
	while eco.count_item(&"wood") > 0:
		eco.remove_item(&"wood", 1)
	_t.check("quest_spot_reports_the_objective", calls_short.is_empty() and calls_modern == [["complete_manual", &"lost_cat", &"follow_pawprints"]] and wood_left == 0 and calls_legacy == [["update_objective", &"lost_cat", &"follow_pawprints", 1]],
		"short of wood: nothing reported %s; with wood: complete_manual(lost_cat, follow_pawprints) once %s, the 2 wood consumed (%d left); the legacy QuestManager gets update_objective(.., 1) %s" % [calls_short, calls_modern, wood_left, calls_legacy])
	holder.queue_free()
	await _t.frames(1)


## Runs `work` with `stub` standing in for the QuestManager autoload (the real node is renamed for the duration, then put back) and
## returns the calls the stub recorded. The stub is freed.
func _with_quest_manager(stub: Node, work: Callable) -> Array:
	var real: Node = _t.root.get_node("QuestManager")
	real.name = "QuestManager_real"
	stub.name = "QuestManager"
	_t.root.add_child(stub)
	work.call()
	var calls: Array = (stub.get("calls") as Array).duplicate()
	_t.root.remove_child(stub)
	stub.free()
	real.name = "QuestManager"
	return calls


class FakeQuestManager extends Node:
	var calls: Array = []

	func complete_manual(quest: StringName, objective: StringName) -> void:
		calls.append(["complete_manual", quest, objective])

	func update_objective(quest: StringName, objective: StringName, amount: int = 1) -> void:
		calls.append(["update_objective", quest, objective, amount])


## The QuestManager of before P13: no complete_manual, only update_objective(quest, objective, amount).
class LegacyQuestManager extends Node:
	var calls: Array = []

	func update_objective(quest: StringName, objective: StringName, amount: int = 1) -> void:
		calls.append(["update_objective", quest, objective, amount])


## `when=` on a warp: IsoArea owns the condition and calls Warp2D.set_enabled(): a hidden warp neither fires nor lets anything in. (Warp2D
## and Interactable2D used to carry an unused `when_spec` copy; a mutation of set_enabled went unnoticed.)
func _warp_when(t) -> void:
	var map: AreaMap = AreaMap.parse_text("@id _t_warpwhen\n@projection iso\n@theme farm\n@marker w warp to=_fixture_ortho spawn=from_iso label=ZONE_DARK_FOREST when=flag:t_warp_flag\n@ground\n#######\n#.....#\n#.....#\n#.....#\n#######\n@objects\n.......\n.......\n...w...\n.......\n.......\n")
	WorldRoot2D.register_map(&"_t_warpwhen", map)
	_world._enter(&"_t_warpwhen", &"default")
	var a: IsoArea = _world.area
	var warp: Warp2D = a.triggers.get_child(0) as Warp2D
	var gm: Node = t.autoload("GameManager")
	gm.set_flag(&"t_warp_flag", false)
	a.refresh_when()
	var asked: Array = []
	var cb: Callable = func(area_id: StringName, spawn: StringName) -> void: asked.append([area_id, spawn])
	t.autoload("EventBus").area_change_requested.disconnect(_world._on_area_change_requested)
	t.autoload("EventBus").area_change_requested.connect(cb)
	var p: Node2D = _world.player
	var away: Vector2 = a.cell_to_global(Vector2i(1, 1))
	p.global_position = away
	await t.physics(4)
	var hidden: bool = not warp.armed and not warp.visible and not warp.monitoring
	p.global_position = warp.global_position
	await t.physics(6)
	var shut: bool = asked.is_empty()
	p.global_position = away
	await t.physics(4)
	gm.set_flag(&"t_warp_flag", true)
	a.refresh_when()
	await t.physics(3)
	var shown: bool = warp.armed and warp.visible and warp.monitoring
	p.global_position = warp.global_position
	await t.physics(6)
	t.check("warp_when_disables_the_trigger", hidden and shut and shown and asked == [[&"_fixture_ortho", &"from_iso"]], "flag off: the warp is hidden, disarmed and not monitoring (%s), walking in asks for nothing (%s); flag on: armed (%s) and one area_change_requested %s" % [hidden, shut, shown, asked])
	p.global_position = away                 # off the door before the world re-parents the player (a body that re-enters an armed warp fires it again)
	await t.physics(3)
	t.autoload("EventBus").area_change_requested.disconnect(cb)
	t.autoload("EventBus").area_change_requested.connect(_world._on_area_change_requested)
	gm.set_flag(&"t_warp_flag", false)
	_world._enter(&"_fixture_iso", &"default")
	var parked: Node = _world._cache.get(&"_t_warpwhen", null)
	_world._cache.erase(&"_t_warpwhen")
	if parked != null:
		(parked as Node).free()
	WorldRoot2D.unregister_map(&"_t_warpwhen")


func _warp_walk(t) -> void:
	var map: AreaMap = AreaMap.parse_text("@id _t_warp\n@projection iso\n@theme farm\n@marker w warp to=_fixture_ortho spawn=from_iso label=ZONE_DARK_FOREST req_day=5\n@ground\n#######\n#.....#\n#.....#\n#.....#\n#######\n@objects\n.......\n.......\n...w...\n.......\n.......\n")
	WorldRoot2D.register_map(&"_t_warp", map)
	_world._enter(&"_t_warp", &"default")
	var a: IsoArea = _world.area
	var warp: Warp2D = a.triggers.get_child(0) as Warp2D
	var gm: Node = t.autoload("GameManager")
	var saved_day: int = gm.get("day")
	gm.set("day", 1)
	var asked: Array = []
	var cb: Callable = func(area_id: StringName, spawn: StringName) -> void: asked.append([area_id, spawn])
	t.autoload("EventBus").area_change_requested.disconnect(_world._on_area_change_requested)
	t.autoload("EventBus").area_change_requested.connect(cb)
	_seen.clear()
	var wcb: Callable = func(k: String) -> void: _seen.append(k)
	t.autoload("EventBus").whisper_requested.connect(wcb)
	var p: Node2D = _world.player
	p.global_position = a.cell_to_global(Vector2i(1, 1))
	await t.physics(4)
	p.global_position = warp.global_position
	await t.physics(6)
	var shut: bool = asked.is_empty() and _seen == ["WORLD_WARP_LOCKED"] and not warp.is_open()
	p.global_position = a.cell_to_global(Vector2i(1, 1))
	await t.physics(6)
	gm.set("day", 5)
	_seen.clear()
	p.global_position = warp.global_position
	await t.physics(6)
	var opened: bool = asked.size() >= 1 and asked[0] == [&"_fixture_ortho", &"from_iso"] and warp.is_open()
	t.check("warp_req_day_and_walk_in", shut and opened, "day 1 < req_day 5: whisper WORLD_WARP_LOCKED and no travel; day 5: area_change_requested(_fixture_ortho, from_iso)")
	t.autoload("EventBus").whisper_requested.disconnect(wcb)
	t.autoload("EventBus").area_change_requested.disconnect(cb)
	t.autoload("EventBus").area_change_requested.connect(_world._on_area_change_requested)
	gm.set("day", saved_day)
	_world._enter(&"_fixture_iso", &"default")
	WorldRoot2D.unregister_map(&"_t_warp")


# ================================================================== marker registry from Lua (amendment 1)

func _marker_registry_from_lua(t) -> void:
	var gm: Node = t.autoload("GameManager")
	IsoArea.clear_handler_cache()
	var base: Dictionary = IsoArea.marker_registry()
	var base_ok: bool = base.has("spawn") and base["spawn"]["builtin"] and base.has("npc") and base["npc"]["script"] == "res://scripts/world2d/npc_2d.gd" and base["whisper"]["script"].ends_with("whisper_zone.gd") and base.has("field_expansion") and base.has("light")
	t.check("marker_registry_built_in_table", base_ok and base.size() >= 14, "%d types: built in %s; lazy %s" % [base.size(), IsoArea.BUILTIN_MARKERS, IsoArea.LAZY_HANDLERS.keys()])
	# Lua entries (lua/config/marker_handlers.lua, F4) are merged OVER it: a new type, a replaced lazy type, a missing script, a script without entry point
	gm.set_config_override("marker_handlers", {"widget": SELF_PATH, "npc": SELF_PATH, "ghost": "res://scripts/world2d/no_such_handler.gd", "inert": "res://scripts/world2d/iso.gd", "sign": "res://scripts/world2d/no_such_sign.gd"})
	IsoArea.clear_handler_cache()
	var reg: Dictionary = IsoArea.marker_registry()
	t.check("marker_registry_merges_lua_over_the_table", reg["widget"]["script"] == SELF_PATH and reg["npc"]["script"] == SELF_PATH and reg["ghost"]["script"].ends_with("no_such_handler.gd") and bool(reg["sign"]["builtin"]) and reg["spawn"]["builtin"], "widget added, npc replaced, sign keeps its built-in flag, spawn untouched")
	var kinds: Dictionary = {"widget": IsoArea.resolve_handler("widget")["kind"], "npc": IsoArea.resolve_handler("npc")["kind"], "ghost": IsoArea.resolve_handler("ghost")["kind"], "inert": IsoArea.resolve_handler("inert")["kind"], "sign": IsoArea.resolve_handler("sign")["kind"], "unknown": IsoArea.resolve_handler("never_heard_of")["kind"]}
	t.check("marker_registry_resolution", kinds == {"widget": "script", "npc": "script", "ghost": "none", "inert": "none", "sign": "builtin", "unknown": "none"}, "%s" % [kinds])
	# build an area with those markers: widget + npc through the script, ghost / inert / unknown skipped silently and counted, sign built in
	var map: AreaMap = AreaMap.parse_text("@id _t_reg\n@projection iso\n@theme farm\n@marker a widget tag=one\n@marker b npc id=zed\n@marker c ghost\n@marker d inert\n@marker e never_heard_of\n@marker f sign text=ZONE_FARM\n@ground\n#######\n#.....#\n#.....#\n#.....#\n#######\n@objects\n.......\n.a.b.c.\n.d.e.f.\n.......\n.......\n")
	made_markers.clear()
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(map)
	var by_script: bool = made_markers.size() == 2 and str(made_markers[0]["marker"]) == "widget" and str(made_markers[1]["marker"]) == "npc" and made_markers[0]["tag"] == "one" and made_markers[1]["id"] == "zed"
	var skipped: bool = area.skipped_markers == {"ghost": 1, "inert": 1, "never_heard_of": 1}
	var built_in: bool = _find_node(area.objects, "Sign_") != null
	var nodes_in: bool = area.find_markers("widget")[0]["node"] != null and area.find_markers("widget")[0]["node"].get_parent() == area.objects and (area.find_markers("widget")[0]["node"] as Node2D).position.distance_to(area.to_local(area.find_markers("widget")[0]["pos"])) < 0.01
	t.check("marker_registry_from_lua", by_script and skipped and built_in and nodes_in, "script handlers called %s; skipped %s; sign built in %s; node adopted into Objects at its cell %s" % [made_markers.size(), area.skipped_markers, built_in, nodes_in])
	# a per-area override (the spike's Callable table) still wins over the registry
	area.marker_handlers = {}
	holder.queue_free()
	gm.clear_config_overrides()
	IsoArea.clear_handler_cache()
	var back: Dictionary = IsoArea.marker_registry()
	t.check("marker_registry_override_is_removable", not back.has("widget") and back["npc"]["script"] == "res://scripts/world2d/npc_2d.gd", "clearing the override restores the built-in table")
	# the legacy spike entry points still work for the spike's four types: create(params) / create(params, pos)
	t.check("legacy_create_entry_points_only_for_the_spike_types", IsoArea.LEGACY_CREATE_TYPES == ["npc", "enemy", "node", "whisper"], "Npc2D.create(m), Enemy2D.create(m), ResourceNode2D.create(m), WhisperZone.create(m, pos)")


# ================================================================== when= conditions

func _when_conditions(t) -> void:
	var text: String = "@id _t_when\n@projection iso\n@theme farm\n@marker a sign text=ZONE_FARM when=quest:lost_cat\n@marker b sign text=ZONE_FARM when=done:lost_cat\n@marker c sign text=ZONE_FARM when=flag:t_when_flag\n@marker d sign text=ZONE_FARM when=night\n@marker e sign text=ZONE_FARM\n@ground\n#######\n#.....#\n#.....#\n#.....#\n#######\n@objects\n.......\n.a.b...\n.c.d.e.\n.......\n.......\n"
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(AreaMap.parse_text(text))
	var gm: Node = t.autoload("GameManager")
	var tm: Node = t.autoload("TimeManager")
	var qm: Node = t.autoload("QuestManager")
	var saved_hour: int = gm.get("hour")
	gm.set("hour", 12)
	area.on_enter()
	var sign_of: Callable = func(ch: String) -> Interactable2D:
		for m in area.markers:
			if m["char"] == ch:
				return m["node"] as Interactable2D
		return null
	var init_ok: bool = area.when_total_count() == 4 and area.when_active_count() == 0 and not sign_of.call("a").visible and not sign_of.call("b").visible and not sign_of.call("c").visible and not sign_of.call("d").visible and sign_of.call("e").visible
	# quest:<id> (active) then done:<id>
	var accepted: bool = qm.accept_quest(&"lost_cat")
	var quest_on: bool = accepted and sign_of.call("a").visible and not sign_of.call("b").visible and sign_of.call("a").get_node("InteractArea").collision_layer == 8
	qm.complete_quest(&"lost_cat")
	var quest_done: bool = not sign_of.call("a").visible and sign_of.call("b").visible and sign_of.call("a").get_node("InteractArea").collision_layer == 0
	# flag:<name> is polled (flags have no signal)
	gm.set_flag(&"t_when_flag", true)
	area._process(0.3)
	var flag_on: bool = sign_of.call("c").visible
	gm.set_flag(&"t_when_flag", false)
	area._process(0.3)
	var flag_off: bool = not sign_of.call("c").visible
	# night follows the clock
	gm.set("hour", 22)
	t.autoload("EventBus").time_of_day_changed.emit(22, 0)
	var night_on: bool = tm.is_night() and sign_of.call("d").visible
	gm.set("hour", 12)
	t.autoload("EventBus").time_of_day_changed.emit(12, 0)
	var night_off: bool = not sign_of.call("d").visible
	gm.set("hour", saved_hour)
	t.check("when_conditions", init_ok and quest_on and quest_done and flag_on and flag_off and night_on and night_off,
		"hidden at build; quest active %s -> done %s; flag on %s off %s; night on %s off %s (init %s)" % [quest_on, quest_done, flag_on, flag_off, night_on, night_off, init_ok])
	# hidden = not findable: a disabled interactable does not answer the player's E-query
	t.check("when_hides_collider_too", sign_of.call("c").get_node("InteractArea").collision_layer == 0, "the Area2D of a hidden marker leaves the interactable layer")
	holder.queue_free()
	await t.frames(1)
	if qm.has_method("reset"):
		qm.reset()


# ================================================================== when= grammar: delegation, typos, refresh (RT6)

## A stand-in for the social track's autoload (S-core is not built yet): what IsoArea reaches through Svc.node("SocialManager").
class FakeSocial extends Node:
	const WHEN_REFRESH_EVENTS: Array[StringName] = [&"town_festival_started", &"town_festival_ended", &"birthday_today", &"relationship_changed", &"routine_changed"]
	var asked: Array[String] = []
	var answers: Dictionary = {}           # spec -> bool or a Callable returning one (true when not set)
	var errors_of: Dictionary = {}         # spec -> Array of texts

	func eval_when(spec: String) -> bool:
		asked.append(spec)
		var a: Variant = answers.get(spec, true)
		return bool((a as Callable).call()) if a is Callable else bool(a)

	func when_spec_errors(spec: String) -> Array[String]:
		var out: Array[String] = []
		for e in (errors_of.get(spec, []) as Array):
			out.append(str(e))
		return out


## A small iso room with the given markers (`<type> k=v ...` on the chars a, b, c ...) and the spawn: [holder, area]; the holder is in the tree.
func _when_area(t, id: String, marker_lines: Array[String]) -> Array:
	var rows: Array[String] = [".......", ".......", ".......", "...@...", "......."]
	var head: String = "@id %s\n@projection iso\n@theme farm\n" % id
	for i in marker_lines.size():
		var ch: String = "abcdefg"[i]
		head += "@marker %s %s\n" % [ch, marker_lines[i]]
		var y: int = 1 + floori(float(i) / 3.0)
		var x: int = 1 + 2 * (i % 3)
		rows[y] = rows[y].substr(0, x) + ch + rows[y].substr(x + 1)
	head += "@ground\n#######\n#.....#\n#.....#\n#.....#\n#######\n@objects\n" + "\n".join(rows) + "\n"
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(AreaMap.parse_text(head))
	return [holder, area]


func _when_node(area: IsoArea, ch: String) -> Node2D:
	for m in area.markers:
		if str(m["char"]) == ch:
			return m["node"] as Node2D
	return null


func _when_typos(area: IsoArea) -> Array[String]:
	var out: Array[String] = []
	for e in area.map.errors:
		if e.begins_with("when_unknown_kind"):
			out.append(e)
	return out


## RT6: IsoArea.evaluate_when delegates `&`, a leading `!` and the new kinds to SocialManager.eval_when (late bound), keeps the four old
## kinds on their fast path, answers FALSE for an unknown kind and reports it as `when_unknown_kind` in map.errors; the delegated specs
## are re-evaluated on the hour edge (raw game hours, CLOCK_26), on day_started, on friend_changed and on game events.
func _when_grammar(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	var qm: Node = t.autoload("QuestManager")
	var saved_hour: int = gm.get("hour")
	var fake := FakeSocial.new()
	Svc.clear_overrides()
	gm.set("hour", 12)
	gm.set_flag(&"t_wg_flag", true)

	# --- no SocialManager at all: the old kinds still work in `&` / `!` specs, a delegated kind has nobody to ask (false)
	if Svc.node("SocialManager") == null:
		var local_ok: bool = not IsoArea.evaluate_when("hearts:pip:4") and not IsoArea.evaluate_when("!hearts:pip:4") and not IsoArea.evaluate_when("fest:any&flag:t_wg_flag") \
			and IsoArea.evaluate_when("flag:t_wg_flag&!done:t_wg_none") and not IsoArea.evaluate_when("flag:t_wg_flag&flag:t_wg_missing") \
			and IsoArea.evaluate_when("!flag:t_wg_missing") and not IsoArea.evaluate_when("!flag:t_wg_flag")
		t.check("when_without_a_social_manager_is_local_and_quiet", local_ok, "no autoload: hearts / fest are false (also behind `!` and `&`), flag:a&!done:b and !flag:missing are evaluated here, no error")
	else:
		t.skip("area.when_without_a_social_manager_is_local_and_quiet: a real SocialManager autoload exists (S-core has landed); the absent-service fallback is only exercised while it does not")
	Svc.override("SocialManager", fake)

	# --- the new kinds, `&` and a leading `!` are answered by SocialManager.eval_when, once per call, with the spec as written
	var specs: Array[String] = ["hearts:gardener_hoppe:4", "fest:any", "hour:8-18", "weekday:1,2", "season:foraar", "birthday:baker_maja", "stage:baker_maja:friend",
		"at:baker_maja", "away:appraiser_fru_ugle", "open:bakery", "!quest:lost_cat", "quest:lost_cat&flag:t_wg_flag", "night&hearts:a:1", "!fest:any&open:bakery"]
	var bad: Array[String] = []
	for spec in specs:
		for want in [true, false]:
			fake.asked.clear()
			fake.answers[spec] = want
			var got: bool = IsoArea.evaluate_when(spec)
			if got != want or fake.asked.size() != 1 or fake.asked[0] != spec:
				bad.append("%s want %s got %s asked %s" % [spec, want, got, fake.asked])
	fake.answers.clear()
	fake.asked.clear()
	var padded: bool = IsoArea.evaluate_when("  hearts:pip:4  ") and fake.asked.size() == 1 and fake.asked[0] == "hearts:pip:4"
	# in an area: the nodes follow the delegate's answers
	fake.asked.clear()
	for s in ["hearts:pip:4&!fest:any", "hour:8-18", "!fest:any"]:
		fake.answers[s] = false
	var lines: Array[String] = ["sign text=ZONE_FARM when=hearts:pip:4&!fest:any", "sign text=ZONE_FARM when=hour:8-18", "sign text=ZONE_FARM when=!fest:any", "sign text=ZONE_FARM"]
	var made: Array = _when_area(t, "_t_when_delegate", lines)
	var area: IsoArea = made[1]
	area.on_enter()
	var hidden_ok: bool = not _when_node(area, "a").visible and not _when_node(area, "b").visible and not _when_node(area, "c").visible and _when_node(area, "d").visible
	for s in ["hearts:pip:4&!fest:any", "hour:8-18", "!fest:any"]:
		fake.answers[s] = true
	area.refresh_when()
	var shown_ok: bool = _when_node(area, "a").visible and _when_node(area, "b").visible and _when_node(area, "c").visible and _when_node(area, "d").visible
	t.check("when_new_kinds_delegate", bad.is_empty() and padded and hidden_ok and shown_ok and area.when_total_count() == 3 and area.map.errors.is_empty(),
		"14 specs x true / false: every answer is the autoload's and every call asks it once (bad: %s); a padded spec is trimmed (%s); in a room the 3 markers are hidden %s then shown %s by its answers; the room has no map error (%s)" % [bad, padded, hidden_ok, shown_ok, area.map.errors])
	(made[0] as Node).queue_free()

	# --- the four old kinds: the fast path, never asked of the autoload, real managers answer
	fake.asked.clear()
	var flag_ok: bool = IsoArea.evaluate_when("flag:t_wg_flag") and not IsoArea.evaluate_when("flag:t_wg_missing")
	gm.set("hour", 22)
	var night_on: bool = IsoArea.evaluate_when("night")
	gm.set("hour", 12)
	var night_off: bool = not IsoArea.evaluate_when("night")
	# a made-up quest id set straight in the manager's state (no reward, nothing left behind for the sections after this one)
	var quest_off: bool = not IsoArea.evaluate_when("quest:t_wg_quest") and not IsoArea.evaluate_when("done:t_wg_quest")
	qm.active_quests[&"t_wg_quest"] = null
	var quest_on: bool = IsoArea.evaluate_when("quest:t_wg_quest") and not IsoArea.evaluate_when("done:t_wg_quest")
	qm.active_quests.erase(&"t_wg_quest")
	qm.completed_quests.append(&"t_wg_quest")
	var quest_done: bool = not IsoArea.evaluate_when("quest:t_wg_quest") and IsoArea.evaluate_when("done:t_wg_quest")
	qm.completed_quests.erase(&"t_wg_quest")
	t.check("when_old_kinds_unchanged", fake.asked.is_empty() and flag_ok and night_on and night_off and quest_off and quest_on and quest_done and IsoArea.evaluate_when("") and IsoArea.evaluate_when("   "),
		"quest / done / flag / night never reach the autoload (asked %s) and the real managers answer: flag %s, night %s / %s, quest %s -> %s -> done %s; an empty spec is true" % [fake.asked, flag_ok, night_on, night_off, quest_off, quest_on, quest_done])

	# --- an unknown kind is false (never delegated, also behind `!` / `&`) and a `when_unknown_kind` entry of map.errors, once per spec
	fake.asked.clear()
	var unknown_false: bool = true
	for spec in ["frobnicate:x", "frobnicate", "quest:lost_cat&frobnicate:x", "!frobnicate:x", "hearts:pip:1&frobnicat:y", ":x", "!"]:
		fake.answers[spec] = true
		if IsoArea.evaluate_when(spec):
			unknown_false = false
	fake.errors_of["stage:pip"] = ["stage needs <npc>:<stage>"]
	var typo_lines: Array[String] = ["sign text=ZONE_FARM when=frobnicate:x", "sign text=ZONE_FARM when=quest:lost_cat&frobnicate:y", "sign text=ZONE_FARM when=stage:pip",
		"nosuchtype when=bogus:z", "sign text=ZONE_FARM when=hearts:pip:2", "sign text=ZONE_FARM when=night"]
	var made2: Array = _when_area(t, "_t_when_typos", typo_lines)
	var area2: IsoArea = made2[1]
	area2.on_enter()
	var typos: Array[String] = _when_typos(area2)
	var typo_text: String = " | ".join(typos)
	var names_specs: bool = typo_text.contains("when=frobnicate:x") and typo_text.contains("when=quest:lost_cat&frobnicate:y") and typo_text.contains("when=stage:pip") and typo_text.contains("stage needs <npc>:<stage>") and typo_text.contains("when=bogus:z")
	var good_clean: bool = not typo_text.contains("when=hearts:pip:2") and not typo_text.contains("when=night")
	var never_asked: bool = true
	for asked_spec in fake.asked:
		if asked_spec.contains("frobnicat") or asked_spec.contains("bogus"):
			never_asked = false
	t.check("when_unknown_kind_is_a_map_error", unknown_false and typos.size() == 4 and names_specs and good_clean and not _when_node(area2, "a").visible and not _when_node(area2, "b").visible and never_asked,
		"7 unknown specs are false and no typo is ever asked of the autoload (%s); the room reports exactly 4 entries (typo, typo in a `&`, a spec the autoload's when_spec_errors rejects, a typo on a skipped marker): %s; the two typo signs are hidden" % [fake.asked.size(), typo_text])
	var again: int = _when_typos(area2).size()
	area2.refresh_when()
	t.check("when_unknown_kind_is_reported_once", again == 4 and _when_typos(area2).size() == again and not area2.skipped_markers.is_empty() and int(area2.skipped_markers.get("nosuchtype", 0)) == 1, "a refresh adds no second entry; the marker of a type nobody handles stays silently skipped (%s)" % [area2.skipped_markers])
	(made2[0] as Node).queue_free()

	# --- the hour edge: the delegated specs follow the clock, `night` follows every tick, a flag inside a `&` is polled
	fake.answers.clear()
	fake.answers["hour:8-18"] = true
	fake.answers["hearts:pip:1&flag:t_wg_flag2"] = func() -> bool: return bool(gm.call("get_flag", &"t_wg_flag2", false))
	var edge_lines: Array[String] = ["sign text=ZONE_FARM when=hour:8-18", "sign text=ZONE_FARM when=night", "sign text=ZONE_FARM when=hearts:pip:1&flag:t_wg_flag2", "sign text=ZONE_FARM when=open:bakery"]
	var made3: Array = _when_area(t, "_t_when_edge", edge_lines)
	var area3: IsoArea = made3[1]
	gm.set("hour", 9)
	area3.on_enter()
	var h_node: Node2D = _when_node(area3, "a")
	var o_node: Node2D = _when_node(area3, "d")
	var f_node: Node2D = _when_node(area3, "c")
	var start_ok: bool = h_node.visible and o_node.visible and not f_node.visible
	fake.answers["hour:8-18"] = false
	bus.time_of_day_changed.emit(9, 30)
	var mid_hour: bool = h_node.visible                          # minute 30 of the same hour: NOT an edge
	bus.time_of_day_changed.emit(10, 0)
	var edge: bool = not h_node.visible                         # the hour edge re-asked
	fake.answers["hour:8-18"] = true
	bus.time_of_day_changed.emit(10, 15)
	var same_hour: bool = not h_node.visible                    # still hour 10
	bus.time_of_day_changed.emit(11, 15)
	var skipped_into: bool = h_node.visible                     # a time skip lands on a new hour at any minute
	fake.answers["hour:8-18"] = false
	bus.time_of_day_changed.emit(24, 0)
	var at_midnight: bool = not h_node.visible                  # raw game hours of CLOCK_26: 24 ...
	fake.answers["hour:8-18"] = true
	bus.time_of_day_changed.emit(25, 0)
	var at_one: bool = h_node.visible                           # ... 25 ...
	fake.answers["hour:8-18"] = false
	bus.time_of_day_changed.emit(2, 0)
	var after_roll: bool = not h_node.visible                   # ... and the clock restarting at 02:00 after the day roll
	t.check("when_refresh_on_hour_edge", start_ok and mid_hour and edge and same_hour and skipped_into and at_midnight and at_one and after_roll,
		"hour:8-18 re-asked at 10:00 (edge %s), not at 09:30 (%s) or 10:15 (%s), at 11:15 after a skip (%s), at raw 24:00 (%s), 25:00 (%s) and 02:00 (%s); start %s" % [edge, mid_hour, same_hour, skipped_into, at_midnight, at_one, after_roll, start_ok])
	# a stale answer is fixed by the other triggers: friend_changed (hearts / stage), the game events of the autoload's list, day_started
	fake.answers["open:bakery"] = false
	bus.friend_changed.emit(&"pip", 4)
	var on_friend: bool = not o_node.visible
	var every_event: bool = true
	for ev in FakeSocial.WHEN_REFRESH_EVENTS:
		fake.answers["open:bakery"] = true
		bus.game_event.emit(ev, {})
		if not o_node.visible:
			every_event = false
		fake.answers["open:bakery"] = false
		bus.game_event.emit(ev, {})
		if o_node.visible:
			every_event = false
	fake.answers["open:bakery"] = true
	area3._on_day_event(1, &"foraar")                           # the real signal would also run every other manager's day roll
	var on_day: bool = o_node.visible and bus.day_started.is_connected(Callable(area3, &"_on_day_event"))
	# a flag inside a `&` is polled like a plain `flag:` spec
	gm.set_flag(&"t_wg_flag2", true)
	area3._process(0.3)
	var polled_in: bool = f_node.visible
	gm.set_flag(&"t_wg_flag2", false)
	area3._process(0.3)
	var polled_out: bool = not f_node.visible
	t.check("when_refresh_on_friend_events_and_flags", on_friend and every_event and on_day and polled_in and polled_out,
		"friend_changed re-asks the delegate (%s), every game event of its WHEN_REFRESH_EVENTS (%s), day_started (%s); the flag of `hearts:..&flag:x` is polled in (%s) and out (%s)" % [on_friend, every_event, on_day, polled_in, polled_out])
	# the area listens only while it is in the tree
	var names: Array[StringName] = [&"_on_clock_event", &"_on_friend_event", &"_on_game_event", &"_on_day_event"]
	var hooked: bool = bus.time_of_day_changed.is_connected(Callable(area3, names[0])) and bus.friend_changed.is_connected(Callable(area3, names[1])) \
		and bus.game_event.is_connected(Callable(area3, names[2])) and bus.day_started.is_connected(Callable(area3, names[3]))
	(made3[0] as Node).remove_child(area3)
	var released: bool = not (bus.time_of_day_changed.is_connected(Callable(area3, names[0])) or bus.friend_changed.is_connected(Callable(area3, names[1])) \
		or bus.game_event.is_connected(Callable(area3, names[2])) or bus.day_started.is_connected(Callable(area3, names[3])))
	t.check("when_signals_hooked_in_the_tree_and_released_out_of_it", hooked and released, "clock, friend_changed, game_event and day_started are connected while the area is in the tree (%s) and none after it left (%s: a parked area never refreshes)" % [hooked, released])
	area3.free()
	(made3[0] as Node).queue_free()

	# --- clean up: the autoload stand-in, the flags, the clock
	Svc.clear_overrides()
	fake.free()
	gm.clear_flag(&"t_wg_flag")
	gm.clear_flag(&"t_wg_flag2")
	gm.set("hour", saved_hour)
	await t.frames(1)


## `when=` on a PROP (or on a marker's `prop=`) hides the WHOLE prop: every y-sort strip of its sprite and the StaticBody2D collider
## leaves the world layer (PLAN 3.7: "hides node + collider"). A hidden house must not stay an invisible wall.
func _when_hides_whole_props(t) -> void:
	var rows: Array[String] = []
	for y in 8:
		rows.append("###########" if y == 0 or y == 7 else "#.........#")
	var objs: Array[String] = [
		"...........",
		"...........",
		"........T..",
		".....H.....",
		"...........",
		"..a.....c..",
		"....b....U.",
		"...........",
	]
	var text: String = "@id _t_when_props\n@projection iso\n@theme farm\n@prop H house_farm when=flag:t_wp_flag\n@prop T tree_oak_farm when=flag:t_wp_flag\n@prop U tree_oak_farm\n"
	text += "@marker a sign text=ZONE_FARM when=flag:t_wp_flag\n@marker b quest_spot quest=lost_cat objective=x prop=scarecrow when=flag:t_wp_flag\n"
	text += "@marker c warp to=_fixture_ortho spawn=from_iso label=ZONE_DARK_FOREST prop=warp_gate_stone when=flag:t_wp_flag\n@ground\n" + "\n".join(rows) + "\n@objects\n" + "\n".join(objs) + "\n"
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(AreaMap.parse_text(text))
	var gm: Node = t.autoload("GameManager")
	gm.set_flag(&"t_wp_flag", false)
	area.on_enter()
	await t.physics(2)
	var control_cell := Vector2i(9, 6)
	var house: Dictionary = {}
	for r in area.prop_nodes:
		if r["id"] == "house_farm":
			house = r
	var house_body: StaticBody2D = house["body"]
	var strips_total: int = (house["nodes"] as Array).size()
	var off: Dictionary = _when_prop_state(area, control_cell, false)
	var off_hit: bool = _solid_hit(holder, house_body)
	t.check("when_hides_prop_strips_and_collider", strips_total >= 8 and int(off["sprites"]) == strips_total + 5 and off["sprites_ok"] == off["sprites"] and int(off["bodies"]) >= 4 and off["bodies_ok"] == off["bodies"] and off["control_ok"] and not off_hit,
		"flag false: %d of %d sprite nodes hidden (the house alone has %d strips) and %d of %d collider layers are 0; the house body no longer answers a physics point query (hit %s); the un-conditioned tree stays (%s)" % [off["sprites_ok"], off["sprites"], strips_total, off["bodies_ok"], off["bodies"], off_hit, off["control_ok"]])
	# the same prop comes back whole: every strip visible, every collider back on the world layer, solid again
	gm.set_flag(&"t_wp_flag", true)
	area._process(0.3)
	await t.physics(2)
	var on: Dictionary = _when_prop_state(area, control_cell, true)
	var on_hit: bool = _solid_hit(holder, house_body)
	t.check("when_shows_prop_strips_and_collider_again", on["sprites_ok"] == on["sprites"] and on["bodies_ok"] == on["bodies"] and on["control_ok"] and on_hit,
		"flag true: %d of %d sprite nodes visible, %d of %d colliders on layer %d, the house body is solid again (hit %s)" % [on["sprites_ok"], on["sprites"], on["bodies_ok"], on["bodies"], Iso.LAYER_WORLD, on_hit])
	gm.set_flag(&"t_wp_flag", false)
	area._process(0.3)
	var off2: Dictionary = _when_prop_state(area, control_cell, false)
	t.check("when_hides_props_again", off2["sprites_ok"] == off2["sprites"] and off2["bodies_ok"] == off2["bodies"], "flag false again: the whole prop is hidden a second time (%d / %d sprites, %d / %d colliders)" % [off2["sprites_ok"], off2["sprites"], off2["bodies_ok"], off2["bodies"]])
	# the marker records list every part of their prop too (all strips and the collider), not just the first sprite
	var sign_rec: Dictionary = area.find_markers("sign")[0]
	var spot_rec: Dictionary = area.find_markers("quest_spot")[0]
	var sign_parts: Array = area.prop_parts(area.prop_nodes[_prop_index(area, "signpost")]["nodes"][0])
	t.check("marker_prop_parts_are_tracked", (sign_rec["nodes"] as Array).size() == 1 + sign_parts.size() and sign_parts.size() == 2 and (spot_rec["nodes"] as Array).size() == 3,
		"a sign marker owns [Interactable2D + signpost sprite + signpost collider], a quest_spot [scarecrow sprite + collider + Interactable2D]")
	gm.set_flag(&"t_wp_flag", false)
	holder.queue_free()
	await t.frames(1)


func _prop_index(area: IsoArea, prop_id: String) -> int:
	for i in area.prop_nodes.size():
		if area.prop_nodes[i]["id"] == prop_id:
			return i
	return -1


## Counts, over every placed prop of `a` except the one at `control_cell` (no when=): sprite nodes (all strips) whose visibility is
## `want_on`, colliders whose layer is the world layer when on / 0 when off; `control_ok` = the control prop is always visible + solid.
func _when_prop_state(a: IsoArea, control_cell: Vector2i, want_on: bool) -> Dictionary:
	var out: Dictionary = {"sprites": 0, "sprites_ok": 0, "bodies": 0, "bodies_ok": 0, "control_ok": false}
	for rec in a.prop_nodes:
		var body: StaticBody2D = rec["body"]
		if rec["cell"] == control_cell:
			var vis_ok: bool = true
			for n in (rec["nodes"] as Array):
				vis_ok = vis_ok and (n as CanvasItem).visible
			out["control_ok"] = vis_ok and body != null and body.collision_layer == Iso.LAYER_WORLD
			continue
		var sprites: Array = (rec["nodes"] as Array).duplicate()
		if rec.get("ground") != null:
			sprites.append(rec["ground"])
		for n2 in sprites:
			out["sprites"] += 1
			if (n2 as CanvasItem).visible == want_on:
				out["sprites_ok"] += 1
		if body != null:
			out["bodies"] += 1
			if body.collision_layer == (Iso.LAYER_WORLD if want_on else 0):
				out["bodies_ok"] += 1
	return out


## Does a physics point query on the world layer at the centre of `body` find that body (a real solid)?
func _solid_hit(holder: Node2D, body: StaticBody2D) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = body.global_position
	q.collision_mask = Iso.LAYER_WORLD
	q.collide_with_bodies = true
	for hit in holder.get_world_2d().direct_space_state.intersect_point(q, 32):
		if hit["collider"] == body:
			return true
	return false


# ================================================================== strips (R.10)

func _strips(t) -> void:
	var a: IsoArea = _world.area
	# the exact numbers of R.10 on house_farm 436 x 406, pivot (192, 310), footprint 3 x 2, front cell (9, 6)
	var tex: ImageTexture = ImageTexture.create_from_image(Image.create_empty(436, 406, false, Image.FORMAT_RGBA8))
	var front := Vector2i(9, 6)
	var fp: Vector2i = Vector2i(3, 2)
	var pivot := Vector2(192, 310)
	var P: Vector2 = Iso.iso_footprint_center(front, fp.x, fp.y)
	var nodes: Array[Node2D] = a._make_strips(tex, pivot, P, front, fp, 14, "t_house")
	var poly: PackedVector2Array = Iso.iso_footprint(front, fp.x, fp.y)
	var L: Vector2 = poly[3]
	var B: Vector2 = poly[2]
	var R: Vector2 = poly[1]
	var count_ok: bool = nodes.size() == 14
	var region_sum: int = 0
	var formula_ok: bool = true
	var offsets_ok: bool = true
	var min_y: float = 1e9
	var max_y: float = -1e9
	for n in nodes:
		var s: Sprite2D = n as Sprite2D
		var at: AtlasTexture = s.texture as AtlasTexture
		var u0: float = at.region.position.x
		var u1: float = at.region.end.x
		region_sum += int(at.region.size.x)
		var xc: float = P.x + (u0 + u1) * 0.5 - pivot.x
		var want_y: float = B.y - Iso.squash() * absf(xc - B.x)
		if xc < B.x:
			want_y = maxf(want_y, L.y)
		elif xc > B.x:
			want_y = maxf(want_y, R.y)
		if absf(s.position.x - xc) > 0.001 or absf(s.position.y - want_y) > 0.001:
			formula_ok = false
		# position + offset is the sprite's top-left: exactly P + (u0 - pivot.x, -pivot.y)
		if (s.position + s.offset).distance_to(P + Vector2(u0 - pivot.x, -pivot.y)) > 0.001 or s.centered or at.region.size.y != 406.0:
			offsets_ok = false
		min_y = minf(min_y, s.position.y)
		max_y = maxf(max_y, s.position.y)
	t.check("strips_count_and_width", count_ok and region_sum == 436 and (nodes[0].texture as AtlasTexture).region.size.x == 32.0, "%d strips of 32 px cover %d px (house_farm 436 px: 14 strips)" % [nodes.size(), region_sum])
	t.check("strips_sort", formula_ok and offsets_ok and max_y <= B.y + 0.001 and min_y >= minf(L.y, R.y) - 0.001 and absf(max_y - B.y) < Iso.squash() * 16.0 + 0.5,
		"sort y = B.y - squash * |xc - B.x| clamped by L.y / R.y for all 14 strips (range %.1f .. %.1f, B.y %.1f); offsets draw the full sprite unchanged" % [min_y, max_y, B.y])
	for loose in nodes:                   # built for the formula check only, never added to a tree: free them or the run leaks 14 sprites at exit
		loose.free()
	# the placed house of the fixture is cut into strips directly under Objects (y-sort flattens children of a plain wrapper)
	var rec: Dictionary = {}
	for r in a.prop_nodes:
		if r["id"] == "house_farm":
			rec = r
	# y-sort probe on the REAL placed nodes: the player's feet 5 px above a strip's sort point draw behind it, 5 px below in front of it.
	# The order is read with the engine's rule for the children of a y-sorted node (_draws_before), from the live z_index / y / parent of
	# the nodes, so a player outside Objects, a strip with another z_index or an Objects that is not y-sorted fails here.
	var p0: Node2D = _world.player
	var saved_at: Vector2 = p0.global_position
	var behind_ok: bool = true
	var front_ok: bool = true
	var probed: int = 0
	for n2 in rec["nodes"]:
		var strip: Sprite2D = n2
		p0.global_position = a.objects.to_global(Vector2(strip.position.x, strip.position.y - 5.0))
		behind_ok = behind_ok and _draws_before(a.objects, p0, strip) and not _draws_before(a.objects, strip, p0)
		p0.global_position = a.objects.to_global(Vector2(strip.position.x, strip.position.y + 5.0))
		front_ok = front_ok and _draws_before(a.objects, strip, p0) and not _draws_before(a.objects, p0, strip)
		probed += 1
	# negative control: the same probe on an Objects whose y-sorting is off cannot order anything, so it must report neither order
	var first_strip: Sprite2D = (rec["nodes"] as Array)[0]
	a.objects.y_sort_enabled = false
	var control_blind: bool = not _draws_before(a.objects, p0, first_strip) and not _draws_before(a.objects, first_strip, p0)
	a.objects.y_sort_enabled = true
	p0.global_position = saved_at
	t.check("ysort_probes", probed >= 8 and probed == (rec["nodes"] as Array).size() and behind_ok and front_ok and control_blind and a.objects.y_sort_enabled and p0.get_parent() == a.objects,
		"player's feet at strip sort y - 5 draw behind and at + 5 in front of each of the %d strips of the placed house (behind %s, in front %s; probe blind without y-sorting %s). Pixel proof: windowed area.sort_pixels" % [probed, behind_ok, front_ok, control_blind])
	var spr_tex: Texture2D = ArtCatalog.prop(&"house_farm")["texture"]
	var strip_w: int = maxi(32, ceili(float(spr_tex.get_width()) / 14.0))
	var expect_n: int = ceili(float(spr_tex.get_width()) / float(strip_w))
	var all_direct: bool = true
	for n3 in rec["nodes"]:
		if (n3 as Node).get_parent() != a.objects or not (n3 as Sprite2D).texture is AtlasTexture:
			all_direct = false
	t.check("fixture_house_is_sliced", (rec["nodes"] as Array).size() == expect_n and all_direct and (rec["nodes"] as Array).size() >= 8, "%d strips directly under Objects for the %d px house" % [(rec["nodes"] as Array).size(), spr_tex.get_width()])
	var mush: Dictionary = {}
	for r2 in a.prop_nodes:
		if r2["id"] == "house_mushroom_rose":
			mush = r2
	var mw: int = (ArtCatalog.prop(&"house_mushroom_rose")["texture"] as Texture2D).get_width()
	t.check("fixture_mushroom_house_is_sliced", (mush["nodes"] as Array).size() == ceili(float(mw) / float(maxi(32, ceili(float(mw) / 10.0)))), "2 x 2 mushroom houses are sliced too (%d strips)" % (mush["nodes"] as Array).size())
	# one-cell props keep ONE sort key at their pivot (the tile centre)
	var tree_rec: Dictionary = {}
	for r3 in a.prop_nodes:
		if r3["id"] == "tree_oak_farm":
			tree_rec = r3
	var tn: Sprite2D = (tree_rec["nodes"] as Array)[0]
	t.check("single_prop_sorts_at_its_pivot", (tree_rec["nodes"] as Array).size() == 1 and tn.position.distance_to(Iso.iso_center(tree_rec["cell"])) < 0.01 and not tn.centered and tn.offset == -(ArtCatalog.prop(&"tree_oak_farm")["pivot"] as Vector2), "a tree is one Sprite2D, centered=false, offset=-pivot, node at the tile centre")
	# a player at the sort point +/- 5 px of the tree: behind above, in front below (same probe as the strips, on the tree's own node)
	p0.global_position = a.objects.to_global(Vector2(tn.position.x + 40.0, tn.position.y - 5.0))
	var tree_behind: bool = _draws_before(a.objects, p0, tn) and not _draws_before(a.objects, tn, p0)
	p0.global_position = a.objects.to_global(Vector2(tn.position.x + 40.0, tn.position.y + 5.0))
	var tree_front: bool = _draws_before(a.objects, tn, p0) and not _draws_before(a.objects, p0, tn)
	p0.global_position = saved_at
	t.check("ysort_probe_tree", tree_behind and tree_front, "player at the trunk's pivot y - 5 draws behind the tree, at + 5 in front of it (the tree is ONE sort key at its pivot)")


## The engine's draw order for two direct children of a y-sorted Node2D, read from the live nodes: lower z_index first (relative z only),
## then lower y in the parent's space, ties in tree order. False in BOTH directions when the parent does not y-sort or a node is not
## its child (nothing can be ordered then), so `a before b` and `b before a` can both be asserted.
func _draws_before(parent: Node2D, first: Node2D, second: Node2D) -> bool:
	if not parent.y_sort_enabled or first.get_parent() != parent or second.get_parent() != parent:
		return false
	if not first.z_as_relative or not second.z_as_relative:
		return false
	if first.z_index != second.z_index:
		return first.z_index < second.z_index
	var fy: float = parent.to_local(first.global_position).y
	var sy: float = parent.to_local(second.global_position).y
	if not is_equal_approx(fy, sy):
		return fy < sy
	return first.get_index() < second.get_index()


# ================================================================== skirts (R.10) and platform growth (amendment 2)

func _skirts_and_growth(t) -> void:
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(AreaMap.parse_text(SKIRT_MAP))
	# expected skirts straight from the rules of R.10: edge cell = platform ground with a void SW (x, y+1) or SE (x+1, y) neighbour
	var expect: Dictionary = _expected_skirts(area)
	var names_ok: bool = true
	var kinds: Dictionary = {"platform_sw": 0, "platform_se": 0, "platform_corner": 0}
	for c in area.skirt_nodes:
		var spr: Sprite2D = area.skirt_nodes[c]
		kinds[str(spr.get_meta("skirt"))] = int(kinds.get(str(spr.get_meta("skirt")), 0)) + 1
		if expect.get(c, "") != str(spr.get_meta("skirt")) or spr.get_parent() != area.skirts or spr.position != Iso.iso_center(c) or spr.centered or spr.offset != -(ArtCatalog.prop(StringName(str(spr.get_meta("skirt"))))["pivot"] as Vector2):
			names_ok = false
	t.check("skirts_placed", names_ok and area.skirt_nodes.size() == expect.size() and expect.size() == 10 and kinds["platform_corner"] == 1 and kinds["platform_sw"] == 6 and kinds["platform_se"] == 3,
		"%d skirts (sw %d, se %d, corner %d) = one per platform-edge cell (the two pond cells on the rim included), none for the bridge plank" % [area.skirt_nodes.size(), kinds["platform_sw"], kinds["platform_se"], kinds["platform_corner"]])
	var skirt_in_objects: bool = false
	for oc in area.objects.get_children():
		if oc.name.begins_with("Skirt_"):
			skirt_in_objects = true
	t.check("skirts_node_is_not_ysorted_and_below_objects", not area.skirts.y_sort_enabled and area.skirts.z_index == -9 and area.objects.z_index == 0 and area.skirts.get_parent() == area and not skirt_in_objects, "Skirts z -9, not y-sorted, no skirt sprite inside the y-sorted Objects (a sort tie would paint it over an actor)")
	# a pond on the rim of the platform: its cells are platform edge like any other, so the bark cliff has no gap under the water (R.10:
	# one skirt per platform-edge cell); water inside the platform has no void neighbour and no skirt; a bridge plank is no platform at all
	var rim_pond: bool = area.map.ground_at(Vector2i(3, 6)) == "~" and area.map.ground_at(Vector2i(4, 6)) == "~" and area.skirt_nodes.has(Vector2i(3, 6)) and area.skirt_nodes.has(Vector2i(4, 6)) and str((area.skirt_nodes[Vector2i(3, 6)] as Sprite2D).get_meta("skirt")) == "platform_sw" and str((area.skirt_nodes[Vector2i(4, 6)] as Sprite2D).get_meta("skirt")) == "platform_sw"
	var inner_pond: bool = area.map.ground_at(Vector2i(2, 5)) == "~" and not area.skirt_nodes.has(Vector2i(2, 5)) and not area.skirt_nodes.has(Vector2i(3, 5))
	var bridge_free: bool = area.map.ground_at(Vector2i(8, 3)) == "=" and not area.skirt_nodes.has(Vector2i(8, 3))
	t.check("skirts_under_rim_water_but_not_under_bridge_planks", rim_pond and inner_pond and bridge_free, "rim pond cells (3,6) (4,6): platform_sw skirts %s; inner pond cells none %s; bridge plank none %s" % [rim_pond, inner_pond, bridge_free])
	# growth: markers g (stage 1) and h (stage 2): rows y 0 and y -1 are outside the map here, so use the first two void rows through a real map
	var gm: AreaMap = AreaMap.parse_text("@id _t_growth\n@projection iso\n@theme farm\n@marker g growth stage=1 cells=2..4,1\n@marker h growth stage=2 cells=2..4,0\n@ground\n#######\n#######\n#.....#\n#.....#\n#.....#\n#######\n@objects\n.......\n..g....\n.......\n.......\n.......\n.......\n")
	var garea := IsoArea.new()
	holder.add_child(garea)
	garea.setup(gm)
	var skirts_before: Dictionary = garea.skirt_nodes.duplicate()
	var play_before: Rect2 = garea.play_rect
	var void_cell: Vector2i = Vector2i(3, 1)
	var d_before: bool = garea.max_growth_stage() == 2 and garea.growth_cells(1).size() == 3 and garea.growth_cells(2).size() == 3 and garea.map.is_void(void_cell)
	garea.set_growth_stage(1)
	var deck1: bool = garea.map.ground_at(Vector2i(3, 1)) == "d" and garea.cell_kind(Vector2i(3, 1)) == &"deck_farm" and garea.map.is_void(Vector2i(3, 0)) and garea.growth_stage == 1 and garea.is_walkable(Vector2i(3, 1))
	var expect1: Dictionary = _expected_skirts(garea)
	var skirts1_ok: bool = _same_keys(garea.skirt_nodes, expect1) and garea.skirt_nodes.has(Vector2i(5, 2)) == expect1.has(Vector2i(5, 2))
	var rim_ok: bool = garea.ground.get_cell_source_id(Vector2i(3, 0)) == AreaTileSet.SRC_BLOCKER and garea.ground.get_cell_source_id(Vector2i(1, 1)) == AreaTileSet.SRC_BLOCKER
	var play1: Rect2 = garea.play_rect
	garea.set_growth_stage(2)
	var expect2: Dictionary = _expected_skirts(garea)
	var facade_ok: bool = _same_keys(garea.skirt_nodes, expect2) and garea.skirt_nodes.has(Vector2i(4, 0)) and garea.skirt_nodes.has(Vector2i(4, 1)) and str((garea.skirt_nodes[Vector2i(4, 0)] as Sprite2D).get_meta("skirt")) == "platform_se"
	var play2: Rect2 = garea.play_rect
	var cam2: Rect2 = garea.camera_rect()
	garea.set_growth_stage(0)
	var back_ok: bool = _same_keys(garea.skirt_nodes, skirts_before) and garea.map.is_void(void_cell) and garea.growth_stage == 0 and garea.play_rect == play_before
	garea.set_growth_stage(9)
	var clamp_ok: bool = garea.growth_stage == 2
	t.check("growth_stage_deck_and_skirts", d_before and deck1 and skirts1_ok and rim_ok and facade_ok and back_ok and clamp_ok and play1.size.y >= play_before.size.y and play2.size.y > play_before.size.y and play2.position.y < play_before.position.y and cam2.size.y > play_before.grow(64).size.y,
		"stage 1/2 turn void growth cells into deck; skirts recomputed per edge cell incl. the right facade along grown rows (%d -> %d -> %d); blockers follow; stage 0 restores the map; rows %s -> %s [before %s deck1 %s skirts1 %s rim %s facade %s back %s clamp %s]" % [skirts_before.size(), expect1.size(), expect2.size(), play_before.size.y, play2.size.y, d_before, deck1, skirts1_ok, rim_ok, facade_ok, back_ok, clamp_ok])
	t.check("growth_is_derived_state", not str(_world.to_dict()).contains("growth"), "nothing about the growth stage is saved")
	# a mistyped `cells=` range: clipped to the map (a 7 x 4 map has 28 cells, not 3721), reported in map.errors, cells unique
	var over: AreaMap = AreaMap.parse_text("@id _t_growth_over\n@projection iso\n@theme farm\n@marker g growth stage=1 cells=0..60,0..60\n@ground\n#######\n#.....#\n#.....#\n#######\n@objects\n.......\n.......\n.......\n.......\n")
	var oarea := IsoArea.new()
	holder.add_child(oarea)
	oarea.setup(over)
	var ocells: Array = oarea.growth_cells(1)
	var ounique: Dictionary = {}
	for oc2 in ocells:
		ounique[oc2] = true
	t.check("growth_cells_over_the_map_are_clipped_and_reported", ocells.size() == 28 and ounique.size() == 28 and not ocells.has(Vector2i(7, 0)) and not ocells.has(Vector2i(0, 4)) and over.errors.any(func(e: String) -> bool: return e.begins_with("growth marker 'g' (stage 1): ")),
		"cells=0..60,0..60 on a 7 x 4 map: %d cells (the map), errors %s" % [ocells.size(), over.errors])
	# an absurd range does not freeze the build (it expanded 2 x 10^9 x 10^20 cells before, one Array.has() per cell)
	var huge: AreaMap = AreaMap.parse_text("@id _t_growth_huge\n@projection iso\n@theme farm\n@marker g growth stage=1 cells=0..99999999999999999999,0..2000000000\n@ground\n#######\n#.....#\n#.....#\n#######\n@objects\n.......\n.......\n.......\n.......\n")
	var harea := IsoArea.new()
	holder.add_child(harea)
	var hms0: int = Time.get_ticks_msec()
	harea.setup(huge)
	var hms: int = Time.get_ticks_msec() - hms0
	t.check("growth_cells_absurd_range_does_not_freeze_the_build", hms < 1500 and harea.growth_cells(1).size() == 28 and harea.map.errors.size() >= 1, "0..99999999999999999999 x 0..2000000000 builds in %d ms with %d growth cells" % [hms, harea.growth_cells(1).size()])
	holder.queue_free()
	await t.frames(1)


func _expected_skirts(area: IsoArea) -> Dictionary:
	var out: Dictionary = {}
	for y in area.map.height:
		for x in area.map.width:
			var c := Vector2i(x, y)
			var ch: String = area.map.ground_at(c)
			if ch == "#" or ch == "=":
				continue
			var sw: bool = area.map.is_void(Vector2i(x, y + 1))
			var se: bool = area.map.is_void(Vector2i(x + 1, y))
			if sw and se:
				out[c] = "platform_corner"
			elif sw:
				out[c] = "platform_sw"
			elif se:
				out[c] = "platform_se"
	return out


func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
	return true


# ================================================================== a map without a default spawn

const NO_SPAWN_MAP := """
@id _t_nospawn
@projection iso
@theme farm
@prop T tree_oak_farm
@ground
#########
#.......#
#.......#
#...~...#
#.......#
#.......#
#########
@objects
.........
.........
....T....
.........
.........
.........
.........
"""


## `default` is mandatory. A map that has none (no `@`, no spawn marker) used to put the player at global (0, 0), a void cell above the
## platform: now the area picks the walkable, empty cell nearest to the middle of the grid and the map says what is missing.
func _default_spawn_fallback(t) -> void:
	var map: AreaMap = AreaMap.parse_text(NO_SPAWN_MAP)
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(map)
	var spawn: Vector2 = area.get_spawn("default")
	var cell: Vector2i = area.global_to_cell(spawn)
	var mid := Vector2(float(map.width - 1) * 0.5, float(map.height - 1) * 0.5)
	# independent brute force: no free walkable cell may be nearer to the middle than the chosen one
	var nearer: int = 0
	for y in map.height:
		for x in map.width:
			var ch: String = map.ground_at(Vector2i(x, y))
			if (ch == "." or ch == ",") and map.object_at(Vector2i(x, y)) == "." and Vector2(x, y).distance_squared_to(mid) < Vector2(cell).distance_squared_to(mid):
				nearer += 1
	var errs: String = " ".join(map.errors)
	t.check("map_without_default_spawn_gets_a_fallback", area.spawns.has("default") and spawn != Vector2.ZERO and spawn.distance_to(area.global_position) > 100.0 and map.ground_at(cell) == "." and map.object_at(cell) == "." and nearer == 0 and errs.contains("no default spawn") and map.errors.size() == 1,
		"spawn %s = cell %s (ground '%s', nothing placed), %d free walkable cells nearer to the middle %s; map.errors %s" % [spawn, cell, map.ground_at(cell), nearer, mid, map.errors])
	area.free()
	holder.queue_free()
	WorldRoot2D.register_map(&"_t_nospawn", AreaMap.parse_text(NO_SPAWN_MAP))
	_world._enter(&"_t_nospawn", &"default")
	var p: Node2D = _world.player
	var pcell: Vector2i = _world.area.global_to_cell(p.global_position)
	t.check("player_starts_on_the_walkable_fallback_spawn", p.global_position.distance_to(_world.area.get_spawn("default")) < 2.0 and _world.area.map.ground_at(pcell) == "." and _world.area.camera_rect().has_point(p.global_position), "the player stands at %s, cell %s, on the platform" % [p.global_position.round(), pcell])
	_world._enter(&"_fixture_iso", &"default")
	var parked: Node = _world._cache.get(&"_t_nospawn", null)
	_world._cache.erase(&"_t_nospawn")
	if parked != null:
		(parked as Node).free()
	WorldRoot2D.unregister_map(&"_t_nospawn")
	# a map WITH a spawn gets no entry (the fixtures: errors stay empty, see fixture_iso_built)
	var with: IsoArea = _world.area
	t.check("map_with_a_spawn_reports_nothing", with.map.errors.is_empty() and with.spawns.has("default"), "fixture: errors %s" % [with.map.errors])
	await t.frames(1)


# ================================================================== water (R.10)

func _water(t) -> void:
	var a: IsoArea = _world.area
	var layers: Array[TileMapLayer] = a.water_layers
	var same_cells: bool = layers.size() == 4
	var base_cells: Array[Vector2i] = layers[0].get_used_cells()
	for l in layers:
		if l.get_used_cells().size() != base_cells.size():
			same_cells = false
	var visible_count: int = 0
	for l2 in layers:
		visible_count += 1 if l2.visible else 0
	t.check("water_layers_identical_cells", same_cells and base_cells.size() >= 9 and visible_count == 1 and layers[0].visible, "%d layers x %d cells, exactly one visible" % [layers.size(), base_cells.size()])
	var src_ok: bool = true
	for i in 4:
		if layers[i].get_cell_source_id(base_cells[0]) != AreaTileSet.source_for(&"iso", AreaTileSet.WATER_FRAMES[i]) or layers[i].get_cell_atlas_coords(base_cells[0]) != Iso.atlas_coords(base_cells[0], Vector2i(2, 2)):
			src_ok = false
	t.check("water_frames_use_four_atlases", src_ok, "layer i draws water_i (2 x 2 variants)")
	# swap every 0.5 s: advance the area's own timer
	a.set_water_frame(0)
	var seq: Array[int] = []
	for i in 6:
		a._process(0.5)
		var vis: Array[int] = []
		for k in 4:
			if layers[k].visible:
				vis.append(k)
		seq.append(vis[0] if vis.size() == 1 else -1)
	t.check("water_frames", seq == [1, 2, 3, 0, 1, 2], "visible layer after each 0.5 s: %s (O(1) visibility swap, no per-cell edits)" % [seq])
	a.set_water_frame(0)
	t.check("water_physics_on_layer_0_only", layers[0].tile_set == layers[1].tile_set, "one TileSet; collision polygons only on the water_0 tiles (tileset_physics_water_0_only)")


# ================================================================== physics through the open map

func _physics(t) -> void:
	var map: AreaMap = AreaMap.parse_text(OPEN_MAP)
	WorldRoot2D.register_map(&"_t_open", map)
	_world._enter(&"_t_open", &"default")
	var a: IsoArea = _world.area
	var p: Node2D = _world.player
	await t.physics(3)
	t.check("open_map_entered", a.map.id == &"_t_open" and p.get_parent() == a.objects and p.global_position.distance_to(a.cell_to_global(Vector2i(8, 8))) < 2.0, "player stands on the default spawn")
	# --- ground walkers never enter water, even while the visible water frame is not layer 0
	var shore := Vector2i(6, 10)
	var violated: bool = false
	for frame in [0, 2]:
		a.set_water_frame(frame)
		p.global_position = a.cell_to_global(shore)
		await t.physics(4)
		t.hold(&"move_left")
		for i in 90:
			await t.physics(1)
			var cc: Vector2i = a.global_to_cell(p.global_position)
			if a.map.ground_at(cc) == "~" or a.map.is_void(cc):
				violated = true
		t.release_all()
	a.set_water_frame(0)
	t.check("walker_never_enters_water", not violated, "walking into the pond at visible water frame 0 and 2 (physics sits on Water0 whether it is visible or not)")
	# --- void rim: walk off the SE edge
	violated = false
	p.global_position = a.cell_to_global(Vector2i(13, 7))
	await t.physics(4)
	t.hold(&"move_right")
	t.hold(&"move_back")
	for i in 120:
		await t.physics(1)
		if a.map.is_void(a.global_to_cell(p.global_position)):
			violated = true
	t.release_all()
	t.check("walker_never_leaves_the_platform", not violated, "the invisible blocker tiles of the void rim hold the stub on the deck")
	# --- the tree trunk is solid
	var tree: Node2D = null
	for n in t.tree.get_nodes_in_group("prop_tree"):
		if a.is_ancestor_of(n):
			tree = n
	p.global_position = tree.global_position + Vector2(70, 0)
	await t.physics(4)
	t.hold(&"move_left")
	var min_d: float = 1e9
	for i in 60:
		await t.physics(1)
		min_d = minf(min_d, Iso.ground_dist(tree.global_position, p.global_position))
	t.release_all()
	t.check("tree_trunk_is_solid", min_d > 22.0, "feet never closer than %.1f ground px (ellipses 25 + 26 slide around, never through)" % min_d)
	# --- slide along a diagonal wall: screen-west into the NW edge (x = 0 void) must slide down-left instead of sticking
	var start: Vector2 = a.cell_to_global(Vector2i(1, 2))
	p.global_position = start
	await t.physics(8)
	t.hold(&"move_left")
	await t.seconds(1.0)
	t.release_all()
	var along: float = absf(p.global_position.x - start.x)
	await t.physics(6)
	var free_start: Vector2 = a.cell_to_global(Vector2i(10, 12))
	p.global_position = free_start
	await t.physics(8)
	t.hold(&"move_right")
	await t.seconds(1.0)
	t.release_all()
	var free: float = absf(p.global_position.x - free_start.x)
	t.check("collision_slide", along > free * 0.6 and free > 150.0, "slides along the diagonal wall of ground_block diamonds without sticking: %.0f px vs %.0f px in the open (spike at walk 170: 150 vs 162)" % [along, free])
	# --- walking speed is the ground speed of lua/config/game_balance.lua player.walk_speed (screen vertical is squashed)
	p.global_position = a.cell_to_global(Vector2i(8, 6))
	await t.physics(8)
	var s0: Vector2 = p.global_position
	t.hold(&"move_back")
	await t.seconds(0.8)
	t.release_all()
	var d: Vector2 = p.global_position - s0
	t.check("screen_relative_movement", d.y > 20.0 and absf(d.x) < 8.0 and absf(d.y) / Iso.squash() < 285.0 * 0.8 * 1.05, "S moves DOWN the screen (%s); vertical screen speed is squashed, ground speed %.0f px/s <= 285" % [d.round(), absf(d.y) / Iso.squash() / 0.8])
	await t.seconds(0.4)


# ================================================================== area switch, parking and cache

class FakeUI extends Node:
	var modes: Array = []

	func set_mode(m: StringName) -> void:
		modes.append(m)


func _area_switch_and_cache(t) -> void:
	var tm: Node = t.autoload("TimeManager")
	var ui := FakeUI.new()
	_world.game_ui = ui
	_world._enter(&"_fixture_iso", &"default")
	var iso_area: IsoArea = _world.area
	var iso_id: int = iso_area.get_instance_id()
	var p: Node2D = _world.player
	t.check("area_switch_to_iso_fixture", iso_area.map.id == &"_fixture_iso" and p.get_parent() == iso_area.objects and not tm.is_paused and ui.modes[-1] == &"farm" and RenderingServer.get_default_clear_color().is_equal_approx(Color("a9d3e0")), "player reparented into Objects, time runs, GameUI.set_mode(farm), clear colour sky blue")
	var spawn_ok: bool = p.global_position.distance_to(iso_area.get_spawn("default")) < 2.0
	_world._enter(&"_fixture_ortho", &"from_iso")
	var ortho_area: IsoArea = _world.area
	var ortho_id: int = ortho_area.get_instance_id()
	t.check("area_switch_to_ortho_fixture", ortho_area.map.id == &"_fixture_ortho" and p.get_parent() == ortho_area.objects and tm.is_paused and ui.modes[-1] == &"action" and RenderingServer.get_default_clear_color().is_equal_approx(Color("1c2138")) and p.global_position.distance_to(ortho_area.get_spawn("from_iso")) < 2.0 and spawn_ok,
		"spawn from_iso, time paused (lantern-oil clock), GameUI.set_mode(action), clear colour navy 1c2138")
	t.check("iso_areas_are_parked_in_a_cache", not iso_area.is_inside_tree() and is_instance_valid(iso_area) and _world._cache.has(&"_fixture_iso") and iso_area.get_parent() == null, "the left iso area stays alive (crops, props, NPC state) outside the tree")
	_world._enter(&"_fixture_iso", &"from_other")
	t.check("parked_area_comes_back_unchanged", _world.area.get_instance_id() == iso_id and _world.area.is_inside_tree() and p.get_parent() == _world.area.objects and not tm.is_paused and p.global_position.distance_to(_world.area.get_spawn("from_other")) < 2.0 and ui.modes[-1] == &"farm", "same instance after the round trip, spawn from_other, time resumes")
	await t.frames(2)
	t.check("ortho_areas_are_rebuilt_each_visit", not is_instance_valid(ortho_area) or ortho_area.is_queued_for_deletion(), "the left ortho area is freed, not parked")
	_world._enter(&"_fixture_ortho", &"default")
	t.check("ortho_second_visit_is_a_new_instance", _world.area.get_instance_id() != ortho_id and WorldRoot2D.is_parkable(iso_area) and not WorldRoot2D.is_parkable(_world.area), "a fresh IsoArea per visit")
	_world._enter(&"_fixture_iso", &"default")
	# fade travel is awaitable and ends untravelled
	_world.game_ui = null
	ui.free()
	await _world.travel(&"_fixture_ortho", &"default")
	var travelled: bool = _world.area.map.id == &"_fixture_ortho" and not _world.traveling and _world._fade.color.a == 0.0
	await _world.travel(&"_fixture_iso", &"default")
	t.check("travel_fades_and_ends_clear", travelled and _world.area.map.id == &"_fixture_iso" and not _world.traveling and _world._fade.color.a == 0.0, "fade out 0.22 s, swap, fade in 0.25 s")
	if FileAccess.file_exists("res://data/maps/farm.map") and WorldRoot2D.has_area(&"farm"):
		_world._enter(&"farm", &"default")
		var farm_ok: bool = _world.area.map.id == &"farm"
		_world._enter(&"_fixture_iso", &"default")
		_world._enter(&"farm", &"default")
		t.check("farm_fixture_roundtrip", farm_ok and _world.area.map.id == &"farm", "farm <-> fixture switch with the real farm map")
		_world._enter(&"_fixture_iso", &"default")
	else:
		t.skip("area.farm_fixture_roundtrip: data/maps/farm.map does not exist yet (P11, wave 4); the iso <-> ortho fixture switch above covers the mechanism")


# ================================================================== a map that cannot load leaves the world where it is

## A registered map whose file is gone or empty (scan_maps() registered it, then it was deleted or truncated) must not tear down the
## area the player stands in: _enter / travel / rebuild_current_area validate BEFORE anything is parked or freed.
func _failed_enter_keeps_the_area(t) -> void:
	WorldRoot2D.scan_maps()
	var empty_path: String = "user://_t_empty_area.map"
	_write_text(empty_path, "")                                      # zero bytes on disk
	WorldRoot2D._registry[&"_t_ghost"] = {"path": "res://data/maps/_t_ghost_nofile.map", "fixture": true, "map": null}
	WorldRoot2D._registry[&"_t_empty"] = {"path": empty_path, "fixture": true, "map": null}
	_world._enter(&"_fixture_iso", &"default")
	var before: IsoArea = _world.area
	var p: Node2D = _world.player
	var pos: Vector2 = p.global_position
	var all_ok: bool = true
	var notes: Array[String] = []
	for id in [&"_t_ghost", &"_t_empty"]:
		var ok: bool = _world._enter(id, &"default")
		var kept: bool = not ok and _world.area == before and before.is_inside_tree() and before.get_parent() == _world.holder and p.get_parent() == before.objects and p.global_position == pos and _world.last_travel_error.begins_with("cannot load map of %s" % id)
		all_ok = all_ok and kept
		notes.append("%s: returned %s, area %s, error '%s'" % [id, ok, _world.area.map.id if _world.area != null else "<null>", _world.last_travel_error])
	t.check("failed_enter_keeps_the_old_area", all_ok, "a missing and a zero-byte map file: _enter returns false and the world still stands in the old area with the player in it (%s)" % "; ".join(notes))
	var d: Dictionary = _world.to_dict()
	t.check("failed_enter_leaves_a_saveable_world", d.get("area", "") == "_fixture_iso" and d["player_pos"].size() == 2, "to_dict() (autosave) after a failed _enter still works: area %s" % d.get("area", "<none>"))
	# travel() ends clear (fade back to 0), still in the old area, and does not stay in `traveling`
	await _world.travel(&"_t_ghost", &"default")
	t.check("failed_travel_ends_clear_in_the_old_area", _world.area == before and before.is_inside_tree() and not _world.traveling and _world._fade.color.a == 0.0, "travel() to a map that cannot load fades out and back in and stays in %s" % _world.area.map.id)
	# rebuild_current_area (a builder room after a tier change) with a file that went bad: the standing room is kept
	var room_text: String = OPEN_MAP.replace("@id _t_open", "@id _t_rebuild")
	var room_path: String = "user://_t_rebuild_area.map"
	_write_text(room_path, room_text)
	WorldRoot2D._registry[&"_t_rebuild"] = {"path": room_path, "fixture": true, "map": null}
	_world._enter(&"_t_rebuild", &"default")
	var room: IsoArea = _world.area
	DirAccess.remove_absolute(ProjectSettings.globalize_path(room_path))
	_world.rebuild_current_area()
	t.check("failed_rebuild_keeps_the_room", room.map.id == &"_t_rebuild" and _world.area == room and is_instance_valid(room) and room.is_inside_tree() and _world.player.get_parent() == room.objects and _world.last_travel_error.begins_with("cannot load map of _t_rebuild"),
		"rebuild_current_area() with a vanished file keeps the standing area (%s)" % _world.last_travel_error)
	_world._enter(&"_fixture_iso", &"default")
	if is_instance_valid(room) and room.get_parent() == null:         # parked by the _enter above: its file is gone for good
		_world._cache.erase(&"_t_rebuild")
		room.free()
	for gone in [&"_t_ghost", &"_t_empty", &"_t_rebuild"]:
		WorldRoot2D._registry.erase(gone)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(empty_path))


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


# ================================================================== a farm-sized area (44 x 44) through the whole stack

func _farm_sized_map(t) -> void:
	var rows: Array[String] = []
	var objs: Array[String] = []
	for y in 44:
		var g: String = ""
		var o: String = ""
		for x in 44:
			var edge: bool = x == 0 or y == 0 or x == 43 or y == 43
			var ch: String = "#" if edge else "."
			var oc: String = "."
			if not edge:
				if x >= 9 and x <= 20 and y >= 12 and y <= 18:
					ch = "f"
				elif x >= 7 and x <= 13 and y >= 20 and y <= 24:
					ch = "~"
				elif y == 16 and x >= 21 and x <= 28:
					ch = "p"
				elif (x * 7 + y * 13) % 29 == 0 and ch == ".":
					oc = "T"
			if x == 22 and y == 22:
				oc = "H"
			if x == 21 and y == 21:
				oc = "@"
			g += ch
			o += oc
		rows.append(g)
		objs.append(o)
	var text: String = "@id _t_big\n@projection iso\n@theme farm\n@zone farm\n@prop T tree_oak_farm\n@prop H house_farm\n@ground\n%s\n@objects\n%s\n" % ["\n".join(rows), "\n".join(objs)]
	WorldRoot2D.register_map(&"_t_big", AreaMap.parse_text(text))
	var t0: int = Time.get_ticks_msec()
	_world._enter(&"_t_big", &"default")
	var ms: int = Time.get_ticks_msec() - t0
	var a: IsoArea = _world.area
	await t.physics(3)
	t.check("farm_sized_map_builds", a.map.id == &"_t_big" and a.map.width == 44 and a.map.height == 44 and a.farmable.size() == 84 and a.prop_nodes.size() > 40 and a.unknown_chars.is_empty() and ms < 2500 and _world.player.get_parent() == a.objects,
		"44 x 44 cells, 84 tillable, %d props, %d skirts, built in %d ms with the placeholders cached, %d ground cells, %d physics bodies" % [a.prop_nodes.size(), a.skirt_nodes.size(), ms, a.ground.get_used_cells().size(), a.colliders.get_child_count()])
	t.check("farm_sized_map_camera_limits", a.camera_rect().size.x > 5000.0 and a.camera_rect().size.y > 2800.0, "camera rect %s" % [a.camera_rect()])
	_world._enter(&"_fixture_iso", &"default")
	_world._cache.erase(&"_t_big")
	if is_instance_valid(a):
		a.free()
	WorldRoot2D.unregister_map(&"_t_big")


# ================================================================== zones, clock, unlocks

func _zones_and_clock(t) -> void:
	var bus: Node = t.autoload("EventBus")
	var gm: Node = t.autoload("GameManager")
	var log: Array = []
	var ze := func(z: StringName) -> void: log.append(["entered", z])
	var zx := func(z: StringName) -> void: log.append(["exited", z])
	var ac := func(a: StringName) -> void: log.append(["area", a])
	bus.zone_entered.connect(ze)
	bus.zone_exited.connect(zx)
	bus.area_changed.connect(ac)
	_world._enter(&"_fixture_iso", &"default")
	log.clear()
	_world._enter(&"_fixture_ortho", &"default")
	t.check("zone_events_from_the_world_root", log == [["exited", &"farm"], ["entered", &"dark_forest"], ["area", &"_fixture_ortho"]] and _world.current_zone() == &"dark_forest" and gm.is_zone_unlocked(&"dark_forest"), "farm -> forest edge: %s; the zone unlocked through GameManager" % [log])
	log.clear()
	_world._enter(&"_fixture_iso", &"default")
	t.check("zone_id_comes_from_the_map_header", log[1] == ["entered", &"farm"] and _world._zone_of_area() == &"farm", "@zone farm of the fixture")
	# a map without @zone falls back to lua/config/ambient.lua area_zone (hyggebyen -> city)
	WorldRoot2D.register_map(&"hyggebyen", AreaMap.parse_text("@id hyggebyen\n@projection iso\n@ambient hyggebyen\n@ground\n###\n#.#\n###\n"))
	_world._enter(&"hyggebyen", &"default")
	t.check("zone_default_from_ambient_lua", _world.current_zone() == &"city" and _world.area.map.theme == &"hyggebyen", "no @zone: area_zone.hyggebyen = city; theme follows the ambient")
	_world._enter(&"_fixture_iso", &"default")
	WorldRoot2D.unregister_map(&"hyggebyen")
	if _world._cache.has(&"hyggebyen"):
		(_world._cache[&"hyggebyen"] as Node).free()
		_world._cache.erase(&"hyggebyen")
	bus.zone_entered.disconnect(ze)
	bus.zone_exited.disconnect(zx)
	bus.area_changed.disconnect(ac)


# ================================================================== builder areas, home ambient, cache rule, camera bounds

const BUILDER_MAP := """
@id _t_builder
@title ZONE_FARM
@projection iso
@ambient home
@zone farm
@builder res://tests/sections/area.gd
@zoom 0.7
@zoom_min 0.35
@zoom_max 1.2
"""


func _builder_areas(t) -> void:
	var bus: Node = t.autoload("EventBus")
	var map: AreaMap = AreaMap.parse_text(BUILDER_MAP)
	built_calls.clear()
	t.check("builder_header_is_header_only", map.is_builder() and not map.has_grid() and map.builder == SELF_PATH and map.ambient == &"home" and map.title == "ZONE_FARM", "@builder, @title and @ambient home are read; no @ground needed")
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(map)
	var call_ok: bool = built_calls.size() == 1 and built_calls[0]["area"] == area and built_calls[0]["header"]["id"] == &"_t_builder" and is_equal_approx(built_calls[0]["header"]["zoom"], 0.7) and is_equal_approx(built_calls[0]["header"]["zoom_min"], 0.35) and is_equal_approx(built_calls[0]["header"]["zoom_max"], 1.2) and built_calls[0]["header"]["ambient"] == &"home"
	t.check("builder_delegate_and_zoom_range", call_ok and area.zoom_range == Vector2(0.35, 1.2) and area.builder_error == "" and area.ground.get_cell_source_id(Vector2i(2, 2)) != -1,
		"IsoArea delegates to builder.build(area, header) with %s; area.zoom_range %s, default %.2f after the builder's per-tier override" % [built_calls[0]["header"].keys().slice(0, 5) if call_ok else "nothing", area.zoom_range, area.zoom_default])
	t.check("builder_may_override_the_zoom_default", is_equal_approx(area.zoom_default, 0.55), "the header says 0.7, the builder set %.2f (HomeRoom does this per tier)" % area.zoom_default)
	var plain: AreaMap = AreaMap.parse_text("@id _t_plain\n@ground\n###\n#.#\n###\n")
	t.check("default_zoom_range_is_0_3_to_0_7", plain.zoom_range() == Vector2(0.3, 0.7) and is_equal_approx(plain.zoom_default(), 0.4), "areas without zoom keys: 0.3 - 0.7, default 0.4")
	holder.queue_free()
	await t.frames(1)
	# a missing builder script is silent
	var missing: AreaMap = AreaMap.parse_text("@id _t_nobuilder\n@projection iso\n@ambient home\n@builder res://scripts/home/no_such_room.gd\n")
	var holder2 := Node2D.new()
	t.root.add_child(holder2)
	var a2 := IsoArea.new()
	holder2.add_child(a2)
	a2.setup(missing)
	t.check("missing_builder_script_is_silent", a2.builder_error.contains("does not exist") and a2.get_child_count() >= 6, "builder_error '%s', no engine message (F6's script lands in wave 5)" % a2.builder_error)
	holder2.queue_free()
	await t.frames(1)
	# --- through the world: cache rule + rebuild signals + bounds
	WorldRoot2D.register_map(&"_t_builder", map)
	_world._enter(&"_fixture_iso", &"default")
	_world._enter(&"_t_builder", &"default")
	var home_area: IsoArea = _world.area
	var first_id: int = home_area.get_instance_id()
	var p: Node2D = _world.player
	var cam: Camera2D = p.get("camera")
	t.check("home_ambient_preset", _world.day_night.preset_id() == &"home" and not _world.day_night.weather_allowed and _world.day_night.wind == 0.0 and RenderingServer.get_default_clear_color().is_equal_approx(Color("2b2340")) and is_equal_approx(_world.area.night_factor, 1.0), "preset home: warm light, no weather overlay, no wind, lamp halos always on (glow 1)")
	# rain does not fall indoors
	var tm: Node = t.autoload("TimeManager")
	tm.set_weather(&"regn")
	var rain_indoors: bool = _world.weather_fx.is_emitting()
	_world._enter(&"_fixture_iso", &"default")
	var rain_outdoors: bool = _world.weather_fx.is_emitting()
	tm.set_weather(&"klart")
	t.check("rain_overlay_only_outdoors", not rain_indoors and rain_outdoors, "raining: indoors %s, farm %s" % [rain_indoors, rain_outdoors])
	t.check("builder_area_is_never_parked", not _world._cache.has(&"_t_builder") and is_instance_valid(_world.area) and WorldRoot2D.is_parkable(_world.area) and not WorldRoot2D.is_parkable(home_area), "left the room: %s in cache" % [_world._cache.keys()])
	_world._enter(&"_t_builder", &"default")
	var second_id: int = _world.area.get_instance_id()
	t.check("builder_area_is_rebuilt_on_every_enter", second_id != first_id and built_calls.size() >= 2, "new instance per visit (builder called %d times)" % built_calls.size())
	# rebuilt on home_upgraded / furniture_changed (placed, removed, tier, load) - not on stock changes
	var before: int = _world.area.get_instance_id()
	bus.furniture_changed.emit(&"stock")
	await t.frames(3)
	var stock_same: bool = _world.area.get_instance_id() == before
	bus.home_upgraded.emit(1, 2)
	await t.frames(3)
	var upgraded: bool = _world.area.get_instance_id() != before
	var before2: int = _world.area.get_instance_id()
	bus.furniture_changed.emit(&"placed")
	bus.furniture_changed.emit(&"removed")
	await t.frames(3)
	var placed: bool = _world.area.get_instance_id() != before2
	t.check("home_ambient_and_cache_rule", stock_same and upgraded and placed and _world.player.get_parent() == _world.area.objects, "stock change: no rebuild (%s); home_upgraded rebuilds (%s); placed / removed rebuild once per frame (%s); the player moves into the new room" % [stock_same, upgraded, placed])
	# camera bounds: a builder may set area.bounds; Player2D's camera limits follow it, a rect smaller than the view is centred
	var b: Rect2 = _world.area.bounds
	var view: Vector2 = p.get_viewport().get_visible_rect().size / cam.zoom.x
	var lim: Rect2 = IsoArea.camera_limits_for(b, view)
	t.check("builder_bounds_clamp_camera", b == Rect2(-300, -200, 3000, 2400) and cam.limit_left == int(lim.position.x) and cam.limit_right == int(lim.end.x) and cam.limit_top == int(lim.position.y) and cam.limit_bottom == int(lim.end.y) and _world.area.camera_rect() == b,
		"area.bounds %s -> camera limits %s..%s (view %s)" % [b, cam.limit_left, cam.limit_right, view])
	cam.zoom = Vector2.ONE * 0.02       # a view larger than the room: limits are centred instead of sticking to the top-left
	p.call("_apply_camera_limits")
	var big: Rect2 = IsoArea.camera_limits_for(b, p.get_viewport().get_visible_rect().size / 0.02)
	t.check("builder_bounds_smaller_than_the_view_are_centered", cam.limit_left == int(big.position.x) and big.get_center().is_equal_approx(b.get_center()), "limits %d .. %d around the room centre" % [cam.limit_left, cam.limit_right])
	cam.zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
	# stub zoom stays inside the area's range
	p.call("_set_zoom", 5.0)
	var hi: float = cam.zoom.x
	p.call("_set_zoom", 0.001)
	var lo: float = cam.zoom.x
	t.check("player_zoom_follows_area_zoom_range", is_equal_approx(hi, 1.2) and is_equal_approx(lo, 0.35), "wheel zoom clamps to the header range %.2f .. %.2f (default areas 0.3 .. 0.7)" % [lo, hi])
	_world._enter(&"_fixture_iso", &"default")
	WorldRoot2D.unregister_map(&"_t_builder")
	t.check("default_area_zoom_range_in_the_world", _world.area.zoom_range == Vector2(0.3, 0.7) and is_equal_approx((p.get("camera") as Camera2D).zoom.x, 0.4), "fixture areas: 0.3 - 0.7, camera starts at 0.4")


# ================================================================== a room that changes while the world travels / sleeps (major defect of review 2)

## F6's builders finish construction in the day roll of the night: GameManager.sleep_until_morning() -> day_started -> home_upgraded /
## furniture_changed. _sleep_sequence() holds `traveling` for the whole night, and rebuild_current_area() used to return silently while
## it was set (after clearing the queue flag), so the room kept the OLD tier until the player left and came back. The request must be
## kept and run when the night / the travel is over (behind the black screen, before the fade-in).
func _builder_rebuild_while_traveling(t) -> void:
	var bus: Node = t.autoload("EventBus")
	var gm: Node = t.autoload("GameManager")
	WorldRoot2D.register_map(&"_t_room", AreaMap.parse_text(BUILDER_MAP.replace("@id _t_builder", "@id _t_room")))
	_world._enter(&"_fixture_iso", &"default")
	var p: Node2D = _world.player
	var fade_at_rebuild: Array = []
	var seen_ready: Callable = func(id: StringName) -> void:
		if id == &"_t_room":
			fade_at_rebuild.append(_world._fade.color.a)
	_world.area_ready.connect(seen_ready)
	var roll: Callable = func(_d: int, _s: StringName) -> void:      # what F6 does when the builders finish: inside end_day() -> day_started
		bus.home_upgraded.emit(1, 2)
		bus.furniture_changed.emit(&"tier")
		bus.furniture_changed.emit(&"load")
	# --- 1. the bed: sleeping in the room, the day roll finishes the builders
	_world._enter(&"_t_room", &"default")
	var room0: IsoArea = _world.area
	var at0: Vector2 = Vector2(420.0, 310.0)
	p.global_position = at0
	gm.set("hour", 19)
	gm.set("minute", 0)
	var built0: int = built_calls.size()
	fade_at_rebuild.clear()
	bus.day_started.connect(roll, CONNECT_ONE_SHOT)
	Engine.time_scale = 4.0
	_world.sleep()
	await t.frames(2)
	var night_started: bool = _world.sleeping and _world.traveling and _world.area == room0
	var slept: bool = await t.until(func() -> bool: return not _world.sleeping, 12.0)
	Engine.time_scale = 1.0
	var room1: IsoArea = _world.area
	t.check("rebuild_queued_during_the_night", night_started and slept and room1 != room0 and room1.map.id == &"_t_room" and built_calls.size() == built0 + 1 and not _world._rebuild_queued and p.get_parent() == room1.objects and p.global_position.distance_to(at0) < 2.0 and fade_at_rebuild.size() == 1 and fade_at_rebuild[0] >= 0.99,
		"home_upgraded + 2 x furniture_changed inside the day roll of the night: the room was rebuilt exactly once (builder calls %d -> %d), behind the black screen (fade alpha %s), the player is in the new room at his old position %s" % [built0, built_calls.size(), fade_at_rebuild, p.global_position.round()])
	t.check("rebuilt_room_leaves_the_player_awake_and_free", int(p.get("state")) == 0 and p.get("forced_clip") == &"" and not _world.sleeping and not _world.traveling and _world._fade.color.a == 0.0, "after the night the player is free (state %s, forced clip '%s'), the fade is clear" % [p.get("state"), p.get("forced_clip")])
	# --- 2. the pass-out: the day rolled INSIDE advance_time before midnight_passed starts the sequence; the deferred rebuild of that
	# frame finds `traveling` set and used to be dropped
	var room2: IsoArea = _world.area
	gm.set("hour", gm.day_end_hour() - 1)         # the last hour of the game day (01:50 at day_end_hour 26): +20 min crosses the day end
	gm.set("minute", 50)
	var built1: int = built_calls.size()
	fade_at_rebuild.clear()
	bus.day_started.connect(roll, CONNECT_ONE_SHOT)
	Engine.time_scale = 4.0
	gm.advance_time(20)
	await t.frames(2)
	var passing_out: bool = _world.sleeping
	var passed: bool = await t.until(func() -> bool: return not _world.sleeping, 12.0)
	Engine.time_scale = 1.0
	t.check("rebuild_queued_during_the_pass_out", passing_out and passed and _world.area != room2 and built_calls.size() == built1 + 1 and not _world._rebuild_queued and fade_at_rebuild.size() == 1 and fade_at_rebuild[0] >= 0.99 and p.get_parent() == _world.area.objects,
		"the day roll of advance_time at the day end (before midnight_passed) queued the rebuild, the pass-out night ran it exactly once behind the black screen (builder calls %d -> %d)" % [built1, built_calls.size()])
	# --- 3. a travel keeps the request too (the primitive: rebuild_current_area() while traveling does not drop it)
	var room3: IsoArea = _world.area
	var built2: int = built_calls.size()
	_world.traveling = true
	_world.rebuild_current_area()
	await t.frames(2)
	var kept: bool = _world._rebuild_queued and _world.area == room3 and built_calls.size() == built2
	_world.traveling = false
	_world._flush_rebuild()
	t.check("rebuild_request_is_kept_while_traveling", kept and _world.area != room3 and built_calls.size() == built2 + 1 and not _world._rebuild_queued, "rebuild_current_area() during a travel stays queued (%s) and _flush_rebuild() runs it once afterwards" % kept)
	# furniture 'stock' changes and a call without a request never rebuild
	var room4: IsoArea = _world.area
	bus.furniture_changed.emit(&"stock")
	_world._flush_rebuild()
	await t.frames(3)
	t.check("flush_without_a_request_does_nothing", _world.area == room4 and not _world._rebuild_queued, "'stock' is not a rebuild reason; _flush_rebuild() with nothing queued leaves the room alone")
	# --- 4. events while a travel LEAVES the room: nothing is left to rebuild in the area the player arrives in
	_world._enter(&"_fixture_iso", &"default")
	var iso_area: IsoArea = _world.area
	_world._enter(&"_t_room", &"default")
	var built3: int = built_calls.size()
	_world.travel(&"_fixture_iso", &"default")
	bus.home_upgraded.emit(2, 3)
	await t.frames(2)
	var queued_in_flight: bool = _world._rebuild_queued and _world.traveling
	await t.until(func() -> bool: return not _world.traveling, 6.0)
	t.check("rebuild_request_dies_with_the_room_the_player_leaves", queued_in_flight and _world.area == iso_area and not _world._rebuild_queued and built_calls.size() == built3 and iso_area.is_inside_tree(), "a tier change during the fade-out was queued (%s); the player arrived in the parked fixture area, which was NOT rebuilt" % queued_in_flight)
	# --- 4b. a request followed by an _enter of the room in the same frame (Continue, from_dict): the fresh room already read the new tier
	_world._enter(&"_fixture_iso", &"default")
	var built3b: int = built_calls.size()
	_world._enter(&"_t_room", &"default")
	bus.home_upgraded.emit(4, 5)
	_world._enter(&"_t_room", &"default")
	await t.frames(4)
	t.check("enter_after_a_request_builds_the_room_once", built_calls.size() == built3b + 2 and not _world._rebuild_queued, "_enter, request, _enter in one frame: the two _enters built the room (calls %d -> %d), the deferred rebuild of the request found nothing left to do" % [built3b, built_calls.size()])
	# --- 5. events AFTER the travel entered the room (during the fade-in) are run when the travel ends
	_world._enter(&"_fixture_iso", &"default")
	var built4: int = built_calls.size()
	_world.travel(&"_t_room", &"default")
	await t.until(func() -> bool: return _world.area.map.id == &"_t_room", 4.0)
	var entered: IsoArea = _world.area
	var in_fade_in: bool = _world.traveling
	bus.home_upgraded.emit(3, 4)
	await t.until(func() -> bool: return not _world.traveling, 6.0)
	await t.frames(2)
	t.check("rebuild_request_during_the_fade_in_runs_when_the_travel_ends", in_fade_in and _world.area != entered and _world.area.map.id == &"_t_room" and built_calls.size() == built4 + 2 and not _world._rebuild_queued and p.get_parent() == _world.area.objects,
		"entered the room by travel (builder call 1), tier change in the fade-in, rebuilt when the travel ended (call 2): calls %d -> %d" % [built4, built_calls.size()])
	_world.area_ready.disconnect(seen_ready)
	if bus.day_started.is_connected(roll):
		bus.day_started.disconnect(roll)
	# --- 6. the saved position of a builder room (no ground rows) is kept; garbage or off-room positions start at the spawn
	var room: IsoArea = _world.area
	var spawn: Vector2 = room.get_spawn("default")
	var inside: Vector2 = Vector2(450.0, 350.0)
	var results: Dictionary = {}
	for case_name in ["inside", "outside_walkable", "far_away", "garbage"]:
		p.global_position = Vector2(100.0, 100.0)
		var pos: Variant = [inside.x, inside.y]
		match case_name:
			"outside_walkable":
				pos = [2000.0, 1500.0]             # inside the camera bounds but not in the room
			"far_away":
				pos = [9000.0, 9000.0]
			"garbage":
				pos = [null, 3.0]
		_world.from_dict({"v": 1, "area": "_t_room", "player_pos": pos})
		results[case_name] = p.global_position
	t.check("builder_keeps_the_saved_position", results["inside"].distance_to(inside) < 1.0 and results["outside_walkable"] == spawn and results["far_away"] == spawn and results["garbage"] == spawn and spawn == Vector2(300.0, 200.0),
		"Continue inside the home keeps the saved position %s (it used to start at the door: a grid-less area reads as all void); outside the room, far away and garbage start at the spawn %s: %s" % [inside, spawn, results])
	# a builder without walkable_test: the camera bounds alone decide (the position is clamped into them)
	room.walkable_test = Callable()
	p.global_position = Vector2(100.0, 100.0)
	_world.from_dict({"v": 1, "area": "_t_room", "player_pos": [2000.0, 1500.0]})
	var free_inside: Vector2 = p.global_position
	_world.from_dict({"v": 1, "area": "_t_room", "player_pos": [9000.0, 9000.0]})
	var clamped: Vector2 = p.global_position
	t.check("builder_without_walkable_test_clamps_into_the_bounds", free_inside.distance_to(Vector2(2000.0, 1500.0)) < 1.0 and room.bounds.has_point(clamped) and clamped.x > 2000.0 and clamped.y > 1500.0, "no walkable_test: a position inside the bounds stays %s, one far outside is pulled to the bounds edge %s" % [free_inside, clamped.round()])
	# a builder that sets no spawn: the middle of its bounds and a map.errors entry
	var nm: AreaMap = AreaMap.parse_text(BUILDER_MAP.replace("@id _t_builder", "@id _t_nospawn_room") + "@nospawn 1\n")
	var nholder := Node2D.new()
	t.root.add_child(nholder)
	var narea := IsoArea.new()
	nholder.add_child(narea)
	narea.setup(nm)
	t.check("builder_without_a_spawn_starts_in_the_middle_of_its_bounds", narea.get_spawn("default") == narea.bounds.get_center() and nm.errors.size() == 1 and nm.errors[0].contains("builder area sets no default spawn"), "spawn %s = centre of %s; errors %s" % [narea.get_spawn("default"), narea.bounds, nm.errors])
	nholder.queue_free()
	await t.frames(1)
	_world._enter(&"_fixture_iso", &"default")
	WorldRoot2D.unregister_map(&"_t_room")


# ================================================================== ArtCatalog: feature directories, icons, merge order

func _artcatalog_feature_dirs(t) -> void:
	ArtCatalog.reset()
	var ids: Array[String] = ArtCatalog.prop_manifest_ids()
	var base_exists: bool = FileAccess.file_exists("res://assets/iso_props/props.json")
	var feature_ids: Array = []
	var fj: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/iso_props/features/props.json"))
	if fj is Dictionary:
		for k in fj:
			if not str(k).begins_with("_"):
				feature_ids.append(str(k))
	var union_ok: bool = not feature_ids.is_empty()
	for fid in feature_ids:
		if not ids.has(fid):
			union_ok = false
	var home_json_ignored: bool = not ids.has("house_t01") and not ids.has("room_t01") and not ids.has("_contract")
	var chest: Dictionary = ArtCatalog.prop(&"chest_fe")
	var glow: Dictionary = chest["glow"]
	var additive: Dictionary = ArtCatalog.prop(&"dig_glimmer")
	t.check("artcatalog_feature_dirs", union_ok and home_json_ignored and chest["real"] and not (chest["pivot"] as Vector2).is_zero_approx() and (chest["pivot"] as Vector2) == Vector2(57, 72) and chest["footprint"] == Vector2i(1, 1) and not glow.is_empty() and (glow["color"] as Color).is_equal_approx(Color.from_string("#9BE7D8", Color.WHITE)) and (glow["center"] as Vector2) == Vector2(36, 54) and additive["blend"] == "add" and ArtCatalog.has_real_prop(&"tent"),
		"assets/iso_props/props.json (%s) UNION assets/iso_props/*/props.json: %d ids incl. the feature props chest_fe (glow), dig_glimmer (additive), tent; home / furniture / interior jsons are not read" % ["present" if base_exists else "absent until P22", ids.size()])
	# icons: items, home, wardrobe in that order; the night variant of legendary icons
	t.check("icon_lookup_order", ArtCatalog.ICON_DIRS == ["res://assets/icons/items/", "res://assets/icons/home/", "res://assets/icons/wardrobe/"], "%s" % [ArtCatalog.ICON_DIRS])
	var amber: String = ArtCatalog.icon_path(&"amber")
	var night: String = ArtCatalog.icon_path(&"bed_moon", true)
	var plain_moon: String = ArtCatalog.icon_path(&"bed_moon", false)
	t.check("icons_found_in_the_home_dir", amber == "res://assets/icons/home/amber.webp" and night == "res://assets/icons/home/bed_moon_night.webp" and plain_moon == "res://assets/icons/home/bed_moon.webp" and ArtCatalog.icon(&"amber").get_width() == 128 and not ArtCatalog.missing().has("icon:amber"), "amber -> %s, bed_moon night variant -> %s" % [amber, night.get_file()])
	t.check("night_icon_falls_back_to_the_plain_icon", ArtCatalog.icon_path(&"amber", true) == amber, "no _night file -> the plain icon")
	# GameData merges props, props_extra, props_features key by key (later wins)
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("props", {"t_prop": {"art": "a", "footprint": [1, 1], "strips": 3, "only_base": 1}})
	gm.set_config_override("props_extra", {"t_prop": {"footprint": [2, 2], "extra": 2}})
	gm.set_config_override("props_features", {"t_prop": {"strips": 9, "feat": 3}, "t_only_feat": {"art": "z"}})
	var def: Dictionary = GameData.prop_def("t_prop")
	t.check("game_data_merges_the_three_prop_tables", def.get("art", "") == "a" and def["footprint"] == [2, 2] and int(def["strips"]) == 9 and int(def["only_base"]) == 1 and int(def["extra"]) == 2 and int(def["feat"]) == 3 and GameData.prop_def("t_only_feat")["art"] == "z" and GameData.prop_ids().has("t_only_feat") and GameData.footprint_of("t_prop") == Vector2i(2, 2) and GameData.prop_def("no_such").is_empty(),
		"props -> props_extra -> props_features, later keys win: %s" % [def])
	gm.clear_config_overrides()
	var real_def: Dictionary = GameData.prop_def("chest_trae")
	t.check("game_data_reads_props_features_lua", str(real_def.get("art", "")) == "chest_trae" and str(real_def.get("interact", "")) == "chest" and GameData.prop_def("tree_oak_farm")["solid"]["radius"] == 26, "lua/config/props_features.lua (A1) and props.lua (P04) both answer through GameData.prop_def")
	# a placed feature prop uses the real art with its additive glow
	var holder := Node2D.new()
	t.root.add_child(holder)
	var area := IsoArea.new()
	holder.add_child(area)
	area.setup(AreaMap.parse_text("@id _t_feat\n@projection iso\n@theme farm\n@prop C chest_fe\n@prop G dig_glimmer\n@ground\n#####\n#...#\n#...#\n#####\n@objects\n.....\n.C.G.\n.....\n.....\n"))
	var chest_node: Sprite2D = _find_node(area.objects, "chest_fe") as Sprite2D
	var glimmer: Sprite2D = _find_node(area.objects, "dig_glimmer") as Sprite2D
	t.check("feature_props_are_placed_with_real_art", chest_node != null and chest_node.get_node_or_null("Glow") != null and (chest_node.get_node("Glow") as Sprite2D).material is CanvasItemMaterial and ((chest_node.get_node("Glow") as Sprite2D).material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and glimmer != null and glimmer.material is CanvasItemMaterial and chest_node.get_meta("prop_id") == "chest_fe", "chest_fe carries an additive halo, dig_glimmer is itself additive")
	t.check("real_art_is_not_listed_as_missing", not ArtCatalog.missing().has("prop:chest_fe") and not ArtCatalog.missing().has("prop:dig_glimmer"), "")
	holder.queue_free()


# ================================================================== day / night, season, weather

func _day_night_and_weather(t) -> void:
	var dn: DayNight = _world.day_night
	var gm: Node = t.autoload("GameManager")
	dn.set_ambient(&"farm_day")
	var alias_id: StringName = dn.preset_id()
	dn.set_ambient(&"no_such_preset")
	t.check("daynight_alias_and_default", alias_id == &"farm" and dn.preset_id() == &"farm", "farm_day -> farm, unknown ids use the default preset of the Lua file")
	dn.set_ambient(&"farm")
	var noon: Color = dn.preset_color_at(12.0)
	var midnight: Color = dn.preset_color_at(0.0)
	var dusk: Color = dn.preset_color_at(19.0)
	t.check("daynight_farm_keyframes", _luma(noon) > 0.95 and _luma(midnight) > 0.35 and _luma(midnight) < 0.45 and dusk.r > dusk.b and dn.preset_color_at(24.0).is_equal_approx(midnight) and dn.preset_color_at(30.0).is_equal_approx(dn.preset_color_at(6.0)),
		"noon luminance %.2f, night %.2f, dusk honey-orange, wraps at midnight" % [_luma(noon), _luma(midnight)])
	dn.set_ambient(&"hyggebyen")
	var hn: Color = dn.preset_color_at(12.0)
	var hd: Color = dn.preset_color_at(19.0)
	t.check("daynight_hyggebyen_lavender_rose", hn.b >= hn.g and hd.r > hd.g and hd.b > hd.g - 0.1, "noon %s, dusk %s" % [hn.to_html(false), hd.to_html(false)])
	dn.set_ambient(&"forest")
	var f0: Color = dn.preset_color_at(3.0)
	var f1: Color = dn.preset_color_at(14.0)
	t.check("daynight_forest_is_a_fixed_navy_night", f0.is_equal_approx(f1) and f0.is_equal_approx(Color.from_string("4d5e85", Color.BLACK)) and dn.glow_at(12.0) == 1.0 and dn.vignette_strength > 0.5 and not dn.weather_allowed, "forest tint %s at any hour, glow 1, vignette %.2f" % [f0.to_html(false), dn.vignette_strength])
	dn.set_ambient(&"cave")
	t.check("daynight_cave_is_darker", _luma(dn.preset_color_at(12.0)) < _luma(f0), "cave %.2f < forest %.2f" % [_luma(dn.preset_color_at(12.0)), _luma(f0)])
	dn.set_ambient(&"farm")
	t.check("glow_curve_fades_in_at_dusk", dn.glow_at(12.0) == 0.0 and dn.glow_at(22.0) == 1.0 and dn.glow_at(18.5) > 0.0 and dn.glow_at(18.5) < 1.0 and dn.glow_at(6.0) > 0.0 and dn.glow_at(8.0) == 0.0, "0 at noon, ramps 17:30-19:30, 1 at night, off after 07:00")
	# season multiplier: neutral / warm / orange / cool
	var saved_season: String = str(gm.get("season"))
	var tints: Dictionary = {}
	for s in ["foraar", "sommer", "efteraar", "vinter"]:
		tints[s] = dn.season_color(StringName(s))
	t.check("season_tints", tints["foraar"].is_equal_approx(Color.WHITE) and tints["sommer"].r >= tints["sommer"].b and tints["efteraar"].r > tints["efteraar"].g and tints["efteraar"].g > tints["efteraar"].b and tints["vinter"].b > tints["vinter"].r, "foraar neutral, sommer warm, efteraar orange, vinter cool")
	gm.set("season", &"efteraar")
	dn.override_hour = 12.0
	var autumn: Color = dn.target_color()
	gm.set("season", &"foraar")
	var spring: Color = dn.target_color()
	gm.set("season", StringName(saved_season))
	dn.override_hour = -1.0
	t.check("target_color_includes_the_season", autumn.b < spring.b, "autumn blue %.2f < spring blue %.2f at noon" % [autumn.b, spring.b])
	# rain: the only weather with a visual
	var tm: Node = t.autoload("TimeManager")
	var vis: Dictionary = {}
	for w in _weather_ids():
		tm.set_weather(w)
		vis[w] = _world.weather_fx.is_emitting() if _world.area.projection == &"iso" else false
	t.check("rain_is_the_only_weather_visual", vis == {&"klart": false, &"regn": true, &"taage": false, &"sne": false, &"torden": false} and WeatherFx.VISUAL_WEATHER == [&"regn"], "emitting per weather on the farm: %s (fog, snow, thunder are label-only stubs)" % [vis])
	tm.set_weather(&"klart")
	t.check("rain_stops_with_the_weather", not _world.weather_fx.is_emitting(), "weather_changed(klart) switches the overlay off")
	var wx: CPUParticles2D = _world.weather_fx.get_node("Rain")
	t.check("rain_overlay_is_a_particle_curtain", wx is CPUParticles2D and wx.amount >= 100 and wx.texture != null and _world.weather_fx.layer == 6, "CPUParticles2D with a streak texture on canvas layer 6")


func _weather_ids() -> Array[StringName]:
	return [&"klart", &"regn", &"taage", &"sne", &"torden"]


func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


# ================================================================== sleep and pass-out

func _sleep_and_passout(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	_world._enter(&"_fixture_iso", &"default")
	var p: Node2D = _world.player
	_seen.clear()
	var wcb: Callable = func(k: String) -> void: _seen.append(k)
	bus.whisper_requested.connect(wcb)
	gm.set("hour", 12)
	gm.set("minute", 0)
	var day0: int = gm.get("day")
	await _world.sleep()
	t.check("bed_before_18_whispers_too_early", _seen == ["WHISPER_TOO_EARLY"] and gm.get("day") == day0 and not _world.sleeping and not _world.can_sleep_now(), "12:00 -> whisper, no day passes")
	_seen.clear()
	gm.set("hour", 19)
	t.check("bed_hours", _world.can_sleep_now(), "19:00 may sleep")
	Engine.time_scale = 4.0
	p.set("stamina", 3.0)
	var notes: Array = []
	var ncb: Callable = func(title: String, msg: String, icon: String) -> void: notes.append([title, msg, icon])
	bus.notification_posted.connect(ncb)
	var started: float = Time.get_ticks_msec()
	_world.sleep()
	await t.frames(2)
	var was_sleeping: bool = _world.sleeping and _world.traveling
	var slept: bool = await t.until(func() -> bool: return not _world.sleeping, 8.0)
	Engine.time_scale = 1.0
	var day1: int = gm.get("day")
	t.check("bed_sleeps_until_morning", was_sleeping and slept and day1 == day0 % 28 + 1 and gm.get("hour") == gm.day_start_hour() and gm.get("minute") < 10 and float(p.get("stamina")) >= float(p.get("max_stamina")) - 0.01 and _world._fade.color.a == 0.0 and int(p.get("state")) == 0,
		"19:00 -> next morning %02d:00 on day %d (was %d), energy restored, fade clear, took %d ms at time scale 4 [sleeping %s slept %s stamina %s/%s fade %s state %s]" % [gm.get("hour"), day1, day0, Time.get_ticks_msec() - started, was_sleeping, slept, p.get("stamina"), p.get("max_stamina"), _world._fade.color.a, p.get("state")])
	bus.notification_posted.disconnect(ncb)
	# pass-out: the clock crosses the DAY END 26:00 = 02:00 (GameManager emits game_event midnight_passed) -> sleep clip, fade, wake at day_start_hour, NOT a skipped day
	gm.set("hour", gm.day_end_hour() - 1)
	gm.set("minute", 50)
	var day2: int = gm.get("day")
	var notes2: Array = []
	var ncb2: Callable = func(title: String, msg: String, icon: String) -> void: notes2.append([title, msg, icon])
	bus.notification_posted.connect(ncb2)
	Engine.time_scale = 4.0
	gm.advance_time(20)
	await t.frames(2)
	var sleeping_now: bool = _world.sleeping
	var done: bool = await t.until(func() -> bool: return not _world.sleeping, 8.0)
	Engine.time_scale = 1.0
	var passed_note: Array = []
	for n in notes2:
		if n[2] == "sleep":
			passed_note = n
	t.check("pass_out_at_day_end", sleeping_now and done and gm.get("day") == day2 % 28 + 1 and gm.get("hour") == gm.day_start_hour() and not passed_note.is_empty() and passed_note[1] == _world.tr("NOTIF_PASSED_OUT") and passed_note[0] == _world.tr("NOTIF_PASSED_OUT_TITLE"),
		"01:50 (raw 25:50) + 20 min crosses the day end 02:00: one new day (%d -> %d), wake at 06:00, NOTIF_PASSED_OUT posted" % [day2, gm.get("day")])
	bus.notification_posted.disconnect(ncb2)
	# no pass-out in the forest (time is paused there; nothing may trigger it)
	_world._enter(&"_fixture_ortho", &"default")
	var d3: int = gm.get("day")
	bus.game_event.emit(&"midnight_passed", {"day": d3, "season": "foraar"})
	await t.frames(2)
	t.check("no_pass_out_in_action_areas", not _world.sleeping and gm.get("day") == d3, "midnight_passed in an ortho area is ignored")
	_world._enter(&"_fixture_iso", &"default")
	# faint (EventBus.player_defeated) returns to farm:from_skovkant with a whisper - only when a farm map exists
	bus.whisper_requested.disconnect(wcb)
	if WorldRoot2D.has_area(&"farm"):
		_world._enter(&"_fixture_ortho", &"default")
		_seen.clear()
		bus.whisper_requested.connect(wcb)
		bus.player_defeated.emit()
		var back: bool = await t.until(func() -> bool: return _world.area.map.id == &"farm" and not _world._faint_pending, 8.0)
		bus.whisper_requested.disconnect(wcb)
		t.check("faint_returns_to_the_farm", back and _seen.has("WHISPER_FAINT"), "player_defeated -> farm, whisper WHISPER_FAINT")
		_world._enter(&"_fixture_iso", &"default")
	else:
		t.skip("area.faint_returns_to_the_farm: needs data/maps/farm.map (P11); the faint handler is exercised by the P06 / P19 sections")


# ================================================================== to_dict / from_dict, pending_world, intro hook

func _save_dict_and_intro(t) -> void:
	_world._enter(&"_fixture_iso", &"default")
	var p: Node2D = _world.player
	p.global_position = _world.area.cell_to_global(Vector2i(5, 7))
	_world.placed_items = [{"item": "scarecrow", "cell": [4, 5]}]
	_world.set_area_flag(&"_fixture_iso", "chest_a", 3)
	_world.set_area_flag(&"_fixture_iso", "picked", true)
	var d: Dictionary = _world.to_dict()
	var json_ok: bool = JSON.parse_string(JSON.stringify(d)) is Dictionary
	t.check("world_to_dict", d["area"] == "_fixture_iso" and d["player_pos"].size() == 2 and d["placed"] == [{"item": "scarecrow", "cell": [4, 5]}] and d["area_flags"]["_fixture_iso"]["chest_a"] == 3 and d.has("v") and json_ok, "area, player_pos, placed items, area flags (JSON-safe) + crops / hotbar when P06 exists: keys %s" % [d.keys()])
	_world.placed_items = []
	_world.area_flags = {}
	p.global_position = _world.area.cell_to_global(Vector2i(2, 2))
	var wire: Dictionary = JSON.parse_string(JSON.stringify(d))
	_world.from_dict(wire)
	var placed_ok: bool = _world.placed_items.size() == 1 and _world.placed_items[0]["item"] == "scarecrow" and int(_world.placed_items[0]["cell"][0]) == 4 and int(_world.placed_items[0]["cell"][1]) == 5
	t.check("world_from_dict_roundtrip", placed_ok and int(_world.get_area_flag(&"_fixture_iso", "chest_a", -1)) == 3 and _world.get_area_flag(&"_fixture_iso", "picked", false) == true and p.global_position.distance_to(_world.area.cell_to_global(Vector2i(5, 7))) < 1.0, "values survive JSON; the player is put back at his position [placed %s flag %s pos %s want %s]" % [_world.placed_items, _world.get_area_flag(&"_fixture_iso", "chest_a", -1), p.global_position, _world.area.cell_to_global(Vector2i(5, 7))])
	var other: Dictionary = d.duplicate(true)
	other["area"] = "_fixture_ortho"
	other["player_pos"] = [200.0, 150.0]
	_world.from_dict(other)
	t.check("world_from_dict_switches_area", _world.area.map.id == &"_fixture_ortho" and p.global_position.distance_to(Vector2(200, 150)) < 1.0 and _world.last_travel_error == "", "a saved area id enters that area (no fade) and sets the position")
	_world._enter(&"_fixture_iso", &"default")
	_world.set_area_flag(&"_fixture_iso", "picked", null)
	t.check("area_flags_can_be_cleared", _world.get_area_flag(&"_fixture_iso", "picked", "gone") == "gone", "")
	# a save of a map that is gone (renamed, removed, another build): its coordinates mean nothing in the area the world stays in
	var iso: IsoArea = _world.area
	var stay: Vector2 = iso.get_spawn("default")
	p.global_position = stay
	_world.from_dict({"v": 1, "area": "no_such_area_x", "player_pos": [9000.0, 9000.0]})
	t.check("saved_position_of_an_unknown_area_is_not_applied", _world.area == iso and p.global_position == stay and iso.camera_rect().has_point(p.global_position), "from_dict(area gone, pos 9000,9000) keeps the player at %s inside the platform %s (no void)" % [p.global_position, iso.camera_rect()])
	# the same area but a position off the platform (a map that shrank, a damaged save): never left in the void, back at the spawn
	var elsewhere: Vector2 = iso.cell_to_global(Vector2i(2, 2))
	var off_ok: bool = elsewhere.distance_to(stay) > 10.0 and iso.map.ground_at(Vector2i(2, 2)) != "#"
	var void_note: Array[String] = []
	for spot in [Vector2(9000.0, 9000.0), iso.cell_to_global(Vector2i(0, 0)), iso.cell_to_global(Vector2i(11, 11)) + Vector2(0, 300)]:
		p.global_position = elsewhere
		_world.from_dict({"v": 1, "area": "_fixture_iso", "player_pos": [spot.x, spot.y]})
		var landed: bool = _world.area == iso and p.global_position == stay and iso.camera_rect().has_point(p.global_position)
		off_ok = off_ok and landed
		void_note.append("%s -> %s" % [spot.round(), p.global_position.round()])
	t.check("saved_position_off_the_platform_returns_to_the_spawn", off_ok, "far outside, on the void cell (0,0) and below the platform: the player stands on the spawn %s, not in the void [%s]" % [stay, "; ".join(void_note)])
	# the void cells of a growth row are not off the platform: F6 turns them into deck on enter, the saved position stays
	var grow_cell := Vector2i(4, 1)
	p.global_position = elsewhere
	_world.from_dict({"v": 1, "area": "_fixture_iso", "player_pos": [iso.cell_to_global(grow_cell).x, iso.cell_to_global(grow_cell).y]})
	t.check("saved_position_on_a_growth_row_is_kept", iso.map.is_void(grow_cell) and p.global_position.distance_to(iso.cell_to_global(grow_cell)) < 1.0, "a position on the not yet grown deck row %s stays where it was saved: %s" % [grow_cell, p.global_position.round()])
	# a save file is untrusted: player_pos that is not two finite numbers (null, Array, Dictionary, string, bool, NaN ...) used to raise a
	# SCRIPT ERROR in float(); the position is damaged, so the player starts at the spawn
	var garbage: Array = [[null, 5.0], [[1.0], 2.0], [{"x": 1.0}, 3.0], ["7", 3.0], [true, 1.0], [1.0], [], "abc", null, {"x": 1.0}, 12.5, [NAN, 1.0], [INF, 2.0], [elsewhere.x, null], [elsewhere.x, [2.0]]]
	var garbage_ok: bool = true
	var garbage_bad: Array[String] = []
	var garbage_mark: int = t.log_mark()
	for g in garbage:
		p.global_position = elsewhere
		_world.from_dict({"v": 1, "area": "_fixture_iso", "player_pos": g})
		if p.global_position != stay or _world.area != iso:
			garbage_ok = false
			garbage_bad.append("%s -> %s" % [g, p.global_position.round()])
	var garbage_errors: Array[String] = t.log_since(garbage_mark)
	t.check("saved_position_garbage_starts_at_the_spawn", garbage_ok, "%d damaged player_pos values (null / Array / Dictionary / string / bool / short / NaN / INF elements, non-array): the player stands at the spawn %s; bad: %s" % [garbage.size(), stay, garbage_bad])
	t.check("saved_position_garbage_raises_no_script_error", garbage_errors.is_empty(), "float() of a null / Array / Dictionary element used to raise an engine (script) error in _apply_saved: %s" % [garbage_errors.slice(0, 2)])
	# whole numbers are numbers (a hand-built dictionary): they are accepted
	var good: Vector2 = iso.cell_to_global(Vector2i(5, 7))
	p.global_position = elsewhere
	_world.from_dict({"v": 1, "area": "_fixture_iso", "player_pos": [int(good.x), int(good.y)]})
	t.check("saved_position_accepts_whole_numbers", p.global_position.distance_to(good) < 1.5, "[%d, %d] -> %s (cell centre %s)" % [int(good.x), int(good.y), p.global_position.round(), good.round()])
	p.global_position = stay
	# parked areas leave with the world: a WorldRoot2D that is deleted frees every area it parked outside the tree
	await _parked_areas_are_freed(t)
	# pending_world: consumed in _ready (P15's SaveManager.pending_world), only when that member exists
	var sm: Node = t.autoload("SaveManager")
	if "pending_world" in sm:
		# end to end: the real scene change that frees this world (quit to menu does the same) must free what it parked
		_world._enter(&"_fixture_ortho", &"default")                 # parks the iso fixture (and `_t_open` is parked since the physics checks)
		var toasts: Array = []
		var tcb: Callable = func(title: String, message: String, icon: String) -> void:
			if icon == "welcome":
				toasts.append([title, message])
		t.autoload("EventBus").notification_posted.connect(tcb)
		var parked_before: Array = []
		for pa in _world._cache.values():
			if is_instance_valid(pa) and (pa as Node).get_parent() == null:
				parked_before.append(pa)
		t.new_game()
		sm.set("pending_world", {"v": 1, "area": "_fixture_ortho", "player_pos": [310.0, 140.0], "placed": [{"item": "fence_x", "cell": [1, 1]}], "area_flags": {"_fixture_ortho": {"seen": true}}})
		var ok: bool = await t.change_scene("res://scenes/main/world.tscn", 20.0)
		await t.until(func() -> bool: return t.player() != null, 10.0)
		await t.frames(5)
		var w2: Node = t.world()
		t.check("pending_world_is_consumed_in_ready", ok and w2 != null and w2.area.map.id == &"_fixture_ortho" and w2.player.global_position.distance_to(Vector2(310, 140)) < 2.0 and w2.placed_items == [{"item": "fence_x", "cell": [1, 1]}] and (sm.get("pending_world") as Dictionary).is_empty(),
			"Continue starts the world in the saved area at the saved position; the hand-over dictionary is cleared")
		t.check("welcome_toast_is_not_shown_on_continue_in_the_saved_area", toasts.is_empty(), "Continue in the area it was saved in shows no welcome toast: %s" % [toasts])
		toasts.clear()
		var leaked: int = 0
		for pa2 in parked_before:
			if is_instance_valid(pa2):
				leaked += 1
		t.check("scene_change_frees_the_parked_areas", parked_before.size() >= 2 and leaked == 0, "%d areas were parked outside the tree when the world scene was replaced; %d of them are still alive (a leak per quit to menu)" % [parked_before.size(), leaked])
		# a pending save of an area that no longer exists: the world starts in the default area, at its spawn, not at the saved coordinates
		t.new_game()
		sm.set("pending_world", {"v": 1, "area": "area_that_is_gone", "player_pos": [8000.0, 8000.0]})
		var ok2: bool = await t.change_scene("res://scenes/main/world.tscn", 20.0)
		await t.until(func() -> bool: return t.player() != null, 10.0)
		await t.frames(5)
		var w3: Node = t.world()
		var w3_rect: Rect2 = w3.area.camera_rect()
		t.check("pending_world_of_an_unknown_area_starts_on_the_platform", ok2 and w3.area.map.id == WorldRoot2D.default_area_id() and w3_rect.has_point(w3.player.global_position) and w3.player.global_position.distance_to(w3.area.get_spawn("default")) < 2.0 and (sm.get("pending_world") as Dictionary).is_empty(),
			"area gone: the default area %s at its spawn %s (player at %s), not at 8000,8000" % [w3.area.map.id, w3.area.get_spawn("default"), w3.player.global_position])
		# the toast of a world start is the ZONE title only (it was GAME_TITLE + zone title = "Trætoppen / Trætoppen"); a Continue that had to
		# fall back to another area announces where the player ended up
		var zone_title: String = w3.tr(w3.area.map.title)
		t.check("welcome_toast_is_the_zone_title_only", w3.area.map.title != "" and toasts == [[zone_title, ""]], "the saved area is gone, so the fallback area announces itself: %s (title key %s)" % [toasts, w3.area.map.title])
		toasts.clear()
		# a new game: the same single toast
		t.new_game()
		sm.set("pending_world", {})
		await t.change_scene("res://scenes/main/world.tscn", 20.0)
		await t.until(func() -> bool: return t.player() != null, 10.0)
		await t.frames(5)
		var w4: Node = t.world()
		t.check("welcome_toast_on_a_new_game", w4 != null and toasts == [[w4.tr(w4.area.map.title), ""]], "new game: exactly one toast, title %s, no second line: %s" % [w4.area.map.title, toasts])
		toasts.clear()
		# an untitled map shows nothing (the fixture maps of other tests, a map whose author has not set @title yet)
		WorldRoot2D.register_map(&"_t_untitled", AreaMap.parse_text("@id _t_untitled\n@projection iso\n@ground\n###\n#.#\n###\n@objects\n...\n.@.\n...\n"))
		w4._enter(&"_t_untitled", &"default")
		w4._welcome_toast({})
		t.check("welcome_toast_needs_a_title", toasts.is_empty(), "no @title -> no toast: %s" % [toasts])
		w4._enter(&"_fixture_iso", &"default")
		WorldRoot2D.unregister_map(&"_t_untitled")
		var untitled_parked: Node = w4._cache.get(&"_t_untitled", null)
		w4._cache.erase(&"_t_untitled")
		if untitled_parked != null:
			(untitled_parked as Node).free()
		# Continue with a damaged position: the saved coordinates must not abort _ready (the player, the music, the toast, the intro come after them)
		var pending_mark: int = t.log_mark()
		t.new_game()
		sm.set("pending_world", {"v": 1, "area": "_fixture_iso", "player_pos": [null, 5.0]})
		await t.change_scene("res://scenes/main/world.tscn", 20.0)
		await t.until(func() -> bool: return t.player() != null, 10.0)
		await t.frames(5)
		var w5: Node = t.world()
		var pending_errors: Array[String] = t.log_since(pending_mark)
		t.check("pending_world_with_a_garbage_position_starts_at_the_spawn", w5 != null and pending_errors.is_empty() and w5.warm_skipped >= 1 and w5.area.map.id == &"_fixture_iso" and w5.player.global_position.distance_to(w5.area.get_spawn("default")) < 2.0 and (sm.get("pending_world") as Dictionary).is_empty(),
			"player_pos [null, 5.0] through SaveManager.pending_world: no script error %s, _ready ran to its end (warm-up reached: %s), the player stands at the spawn %s" % [pending_errors.slice(0, 1), w5.warm_skipped if w5 != null else -1, w5.player.global_position if w5 != null else Vector2.ZERO])
		# Continue inside a builder room (no ground rows): the saved position is kept, not sent to the door
		WorldRoot2D.register_map(&"_t_room", AreaMap.parse_text(BUILDER_MAP.replace("@id _t_builder", "@id _t_room")))
		t.new_game()
		sm.set("pending_world", {"v": 1, "area": "_t_room", "player_pos": [450.0, 350.0]})
		await t.change_scene("res://scenes/main/world.tscn", 20.0)
		await t.until(func() -> bool: return t.player() != null, 10.0)
		await t.frames(5)
		var w6: Node = t.world()
		t.check("pending_world_in_a_builder_room_keeps_the_position", w6 != null and w6.area.map.id == &"_t_room" and w6.player.global_position.distance_to(Vector2(450.0, 350.0)) < 1.0 and w6.area.get_spawn("default") == Vector2(300.0, 200.0) and toasts.is_empty(),
			"Continue after saving inside the home: the player stands at %s, not at the door %s; no welcome toast: %s" % [w6.player.global_position if w6 != null else Vector2.ZERO, w6.area.get_spawn("default") if w6 != null else Vector2.ZERO, toasts])
		w6._enter(&"_fixture_iso", &"default")
		WorldRoot2D.unregister_map(&"_t_room")
		t.autoload("EventBus").notification_posted.disconnect(tcb)
		_world = w6
	else:
		t.skip("area.pending_world_is_consumed_in_ready: SaveManager.pending_world does not exist yet (P15, same wave); to_dict / from_dict above are the contract it hands over")
	# opening hook: the intro script is called once on a new game and clears the flag
	var gm: Node = t.autoload("GameManager")
	gm.set_flag(&"intro_pending", true)
	_world.set_meta("intro_calls", 0)
	_world.intro_script = FakeIntro
	await _world._maybe_intro()
	t.check("intro_hook_calls_the_script_once", int(_world.get_meta("intro_calls", 0)) == 1 and not bool(gm.get_flag(&"intro_pending", false)), "IntroSequence entry point (run / start / play) called with the world, intro_pending cleared")
	await _world._maybe_intro()
	t.check("intro_hook_does_not_repeat", int(_world.get_meta("intro_calls", 0)) == 1, "second call does nothing (flag cleared)")
	_world.intro_script = null
	gm.set_flag(&"intro_pending", not ResourceLoader.exists(WorldRoot2D.INTRO_PATH))


## WorldRoot2D frees the areas it parked outside the tree when it is deleted (nothing else references them). Unit form: a world that never
## enters the tree (so _ready, its signals and its UI do not run) holds three areas in its cache, two parked and one entered.
func _parked_areas_are_freed(t) -> void:
	var w2 := WorldRoot2D.new()
	var holder := Node2D.new()
	t.root.add_child(holder)
	var parked: Array[IsoArea] = []
	var total_nodes: int = 0
	for i in 2:
		var pa := IsoArea.new()
		holder.add_child(pa)
		pa.setup(AreaMap.parse_text(SKIRT_MAP))
		holder.remove_child(pa)
		w2._cache[StringName("_t_parked_%d" % i)] = pa
		parked.append(pa)
		total_nodes += _count_nodes(pa)
	var entered := IsoArea.new()                                         # a cached area that is ALSO in the tree: the tree owns it, no double free
	holder.add_child(entered)
	entered.setup(AreaMap.parse_text(SKIRT_MAP))
	w2._cache[&"_t_entered"] = entered
	await t.frames(2)                                                    # let nodes queued for deletion by earlier checks go first: the drop below is this world's
	var before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	w2.free()
	await t.frames(2)
	var after: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var alive: int = 0
	for pa3 in parked:
		if is_instance_valid(pa3):
			alive += 1
	t.check("world_free_frees_parked_areas", alive == 0 and float(before - after) >= float(total_nodes) * 0.5 and is_instance_valid(entered) and entered.is_inside_tree(),
		"deleting a WorldRoot2D frees its %d parked areas (%d nodes: orphan count %d -> %d, %d still alive); the entered area stays with the tree" % [parked.size(), total_nodes, before, after, alive])
	holder.queue_free()
	await t.frames(1)


func _count_nodes(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c


# ================================================================== warm clips

func _warm_jobs(t) -> void:
	var w: WorldRoot2D = _world as WorldRoot2D
	var jobs: Array = w.warm_jobs()
	t.check("warm_jobs_player", jobs.size() >= 1 and jobs[0][0] == w.player.get("visual") and jobs[0][1] == WorldRoot2D.PLAYER_WARM_CLIPS, "the player's visual with %s" % [WorldRoot2D.PLAYER_WARM_CLIPS])
	# NPCs: only those of this area that are in view
	var a: IsoArea = w.area
	var near := FakeNpc.new()
	var far := FakeNpc.new()
	near.add_to_group("npc")
	far.add_to_group("npc")
	a.objects.add_child(near)
	a.objects.add_child(far)
	near.global_position = w.player.global_position + Vector2(300, 80)
	far.global_position = w.player.global_position + Vector2(9000, 0)
	var jobs2: Array = w.warm_jobs()
	var near_in: bool = false
	var far_in: bool = false
	for j in jobs2:
		if j[0] == near.visual:
			near_in = true
		if j[0] == far.visual:
			far_in = true
	t.check("warm_jobs_visible_npcs_only", near_in and not far_in and jobs2.size() == jobs.size() + 1, "an NPC in view is warmed (%s), one 9000 px away is not (%s)" % [near_in, far_in])
	var skipped: int = w.warm_skipped
	await w.warm_clips()
	t.check("warm_clips_skips_the_dummy_renderer", w.warm_skipped == skipped + 1 and near.visual.warm_calls == 0, "headless: no threaded sheet loads (they raced the dummy renderer in 2 of 120 runs); counted in warm_skipped")
	near.queue_free()
	far.queue_free()


class FakeVisual extends RefCounted:
	var warm_calls: int = 0

	func warm_clips(_clips: Array) -> void:
		warm_calls += 1


class FakeNpc extends Node2D:
	var visual := FakeVisual.new()


# ================================================================== the clear colour does not outlive the world

## RenderingServer.set_default_clear_color() is a process-wide setting: the forest sets navy, the home plum. A world that leaves the tree
## (quit to menu) must put the PROJECT colour back, or the title scene inherits the area's colour.
func _clear_colour_after_quit(t) -> void:
	_world._enter(&"_fixture_ortho", &"default")
	var navy: Color = RenderingServer.get_default_clear_color()
	var project: Color = WorldRoot2D.project_clear_color()
	# the lifecycle methods themselves (the live world stays in the tree: only their bodies run)
	_world._exit_tree()
	var left: Color = RenderingServer.get_default_clear_color()
	_world._enter_tree()
	var back: Color = RenderingServer.get_default_clear_color()
	t.check("world_exit_tree_restores_and_enter_tree_reapplies_the_clear_colour", left.is_equal_approx(project) and back.is_equal_approx(navy), "_exit_tree -> project colour %s, _enter_tree -> the forest's %s again" % [left.to_html(false), back.to_html(false)])
	var went: bool = await t.go_menu()
	var after: Color = RenderingServer.get_default_clear_color()
	t.check("world_restores_the_project_clear_colour", went and navy.is_equal_approx(Color("1c2138")) and not navy.is_equal_approx(project) and after.is_equal_approx(project) and project.is_equal_approx(Color(0.6627451, 0.827451, 0.8784314)),
		"quit to menu from the forest (clear %s): the title scene shows the project colour %s (it showed %s)" % [navy.to_html(false), after.to_html(false), navy.to_html(false)])
	# the next world sets its own again (the old one's _exit_tree ran before the new _ready)
	if await t.start_world():
		_world = t.world()
		var farm_clear: Color = RenderingServer.get_default_clear_color()
		_world._enter(&"_fixture_ortho", &"default")
		t.check("next_world_sets_its_own_clear_colour", farm_clear.is_equal_approx(Color("a9d3e0")) and RenderingServer.get_default_clear_color().is_equal_approx(Color("1c2138")), "farm %s, forest %s" % [farm_clear.to_html(false), RenderingServer.get_default_clear_color().to_html(false)])
		_world._enter(&"_fixture_iso", &"default")


# ================================================================== cleanup

func _cleanup(t) -> void:
	var gm: Node = t.autoload("GameManager")
	gm.clear_config_overrides()
	Engine.time_scale = 1.0
	t.release_all()
	WorldRoot2D.scan_maps(true)
	t.autoload("TimeManager").set_weather(&"klart")
	t.new_game()


# ================================================================== windowed checks (tests/run_playtest.sh --windowed)

func run_windowed(t) -> void:
	if not await t.start_world():
		return
	var w: WorldRoot2D = t.world()
	if w.area.map.id != &"_fixture_iso":
		w._enter(&"_fixture_iso", &"default")
	w.warm_in_headless = true
	await w.warm_clips()
	var p: Node2D = w.player
	var vis: IsoChibiSprite2D = p.get("visual")
	t.check("windowed_warm_clips_loads_sheets", vis.resident_clip_count() >= 3, "%d clip sheets resident after the real warm-up" % vis.resident_clip_count())
	w.day_night.override_hour = 11.0
	w.day_night.snap()
	var a: IsoArea = w.area
	a.set_night_factor(w.day_night.glow_factor)
	p.global_position = a.cell_to_global(Vector2i(4, 7))
	(p.get("camera") as Camera2D).reset_smoothing()
	await t.seconds(0.6)
	var img: Image = await t.capture("render_noon")
	# --- render_not_blank: ground, sky and the player differ from the clear colour and from each other
	var ct: Transform2D = w.get_viewport().get_canvas_transform()
	var ground_px: Vector2i = Vector2i(ct * a.cell_to_global(Vector2i(5, 8)))
	var sky_px := Vector2i(60, 60)
	var player_px: Vector2i = Vector2i(ct * p.global_position + Vector2(0, -58))
	t.expect_not_clear(img, ground_px, "area.render_not_blank ground pixel %s is drawn" % ground_px)
	t.expect_not_clear(img, sky_px, "area.render_not_blank sky pixel %s is drawn (the backdrop, not the clear colour)" % sky_px)
	t.expect_not_clear(img, player_px, "area.render_not_blank player pixel %s is drawn" % player_px)
	t.expect_differs(img, ground_px, sky_px, 20.0, "area.render_not_blank ground differs from sky")
	t.expect_differs(img, ground_px, player_px, 12.0, "area.render_not_blank ground differs from the player")
	t.expect_differs(img, sky_px, player_px, 20.0, "area.render_not_blank sky differs from the player")
	t.expect_not_blank(img, Rect2i(320, 140, 640, 420), "area.render_not_blank the platform region is not a flat fill")
	t.check("render_not_blank", true, "see the three expectations above")
	# --- filter_seams (R.6): no hairline step between neighbouring tiles at zoom 0.3 / 0.4 / 0.7 (on a plain grass platform)
	WorldRoot2D.register_map(&"_t_open", AreaMap.parse_text(OPEN_MAP))
	w._enter(&"_t_open", &"default")
	a = w.area
	w.day_night.override_hour = 11.0
	w.day_night.snap()
	var seams_ok: bool = true
	for z in [0.3, 0.4, 0.7]:
		(p.get("camera") as Camera2D).zoom = Vector2.ONE * z
		(p.get("camera") as Camera2D).reset_smoothing()
		p.global_position = a.cell_to_global(Vector2i(8, 7))
		await t.seconds(0.4)
		var zimg: Image = await t.capture("seams_zoom_%d" % int(z * 100.0))
		var st: Dictionary = _seam_step(w, a, zimg.duplicate() as Image)
		if z == 0.4:
			var neg: Dictionary = _seam_step(w, a, zimg.duplicate() as Image, 0.08)
			t.check("filter_seams_probe_sees_a_hairline", float(neg["border"]) - float(neg["control"]) > 3.0 / 255.0, "negative control: a deliberate 20 / 255 hairline on the borders reads as excess %.1f / 255" % ((float(neg["border"]) - float(neg["control"])) * 255.0))
		var excess: float = float(st["border"]) - float(st["control"])
		seams_ok = seams_ok and _last_pairs >= 3 and excess < 3.0 / 255.0
		t.check("filter_seams_zoom_%d" % int(z * 100.0), _last_pairs >= 3 and excess < 3.0 / 255.0, "luminance step across %d grass tile borders %.1f / 255 vs %.1f / 255 across tile middles: excess %.1f / 255 at zoom %.1f (limit 3 / 255; nearest-neighbour hairlines and mipmap bleeding would show here)" % [_last_pairs, float(st["border"]) * 255.0, float(st["control"]) * 255.0, excess * 255.0, z])
	t.check("filter_seams", seams_ok, "no hairline seams between the tiles at zoom 0.3 / 0.4 / 0.7 (Ground texture_filter 2, atlases without mipmaps)")
	(p.get("camera") as Camera2D).zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
	w._enter(&"_fixture_iso", &"default")
	WorldRoot2D.unregister_map(&"_t_open")
	a = w.area
	w.day_night.override_hour = 11.0
	w.day_night.snap()
	# --- sort pixels: a magenta figure stands behind / in front of the big sprites that are sliced into y-sort strips (R.10)
	#
	# What the old probe measured: the figure's magenta pixels at +-5 px around the FRONT CORNER, compared by count. That does not test the
	# rule: strip k is drawn in front of the figure iff ITS sort y (B.y - squash * |xc - B.x|, clamped, R.10) is greater than the figure's feet
	# y, and the strips are 32 px wide, so which strip centres lie within 5 px / 0.59 = 8.5 px of the corner depends on the phase of the strip
	# lattice against the footprint: with the placeholder art one strip sits there (-5 px hides most of the figure), with the spike's real
	# house none does (-5 px shows all of it, 45 pixels like +5 px) - the old assertion `-5 < +5` held or failed with the art, not with the sort.
	#
	# The derived expectation, for every probe (figure feet f = (x, line(x) + offset), line(x) = the sort line of the footprint at x):
	#   figure   = the pixels the figure covers when the house is hidden (a render without the house; the figure's animation is frozen),
	#   front    = the strips whose sort y is > f.y; the sort y is RECOMPUTED here from Iso.iso_footprint and the strip's x (never read
	#              back from the node, so a shifted sort point cannot hide itself),
	#   a figure pixel is DEFINITELY hidden when every point of a small cross around it (5 px) lies on an opaque pixel (alpha >= 0.95) of a
	#   strip of `front` (read from the atlas image), DEFINITELY visible when no strip of `front` has alpha > 0.05 anywhere in that cross; the
	#   pixels in between (antialiased and mip-blurred strip edges) are not judged.
	# In the render WITH the house the definitely hidden pixels must have lost the figure's colour and the definitely visible ones must
	# have kept it, up to 4 percent (min 3 pixels) of the judged pixels (solid figure pixels only). The probes are placed at the front corner and at the middle of
	# both faces, at -40 / -6 / +6 / +40 px around the sort line, so they include figures completely behind the strips, completely in
	# front of them and partly hidden by the nearest strip. A run in which no probe is hidden or no probe is clear proves nothing.
	p.set("collision_mask", 0)
	p.set_physics_process(false)
	vis.sprite.self_modulate = Color(1, 0, 1)
	vis.set_process(false)                   # freeze the idle animation: the render without and the render with the house must show the same frame
	var sort_rows: Array[String] = []
	var sort_ok: bool = true
	var hidden_n: int = 0
	var clear_n: int = 0
	var partial_n: int = 0
	var worst: float = 0.0
	for prop_id in ["house_farm", "house_mushroom_rose"]:
		var rec: Dictionary = {}
		for r in a.prop_nodes:
			if r["id"] == prop_id:
				rec = r
		if rec.is_empty():
			sort_ok = false
			sort_rows.append("%s: not placed" % prop_id)
			continue
		var res: Dictionary = await _sort_probes(t, w, a, p, rec, prop_id == "house_farm")
		sort_ok = sort_ok and bool(res["ok"])
		hidden_n += int(res["hidden"])
		clear_n += int(res["clear"])
		partial_n += int(res["partial"])
		worst = maxf(worst, float(res["worst"]))
		sort_rows.append("%s: %s" % [prop_id, res["summary"]])
	t.check("sort_pixels", sort_ok and hidden_n >= 2 and clear_n >= 2,
		"pixels of a magenta figure around the sort lines of the sliced houses, measured against the geometric expectation (%d probes with the figure behind the strips, %d partly hidden, %d in front of them; worst %.1f %% of the judged pixels wrong): %s" % [hidden_n, partial_n, clear_n, worst * 100.0, " | ".join(sort_rows)])
	vis.sprite.self_modulate = Color.WHITE
	vis.set_process(true)
	p.set_physics_process(true)
	p.set("collision_mask", 197)


## Probes of one sliced prop (see run_windowed): returns {ok, hidden, clear, partial, worst (fraction of the figure), summary}.
func _sort_probes(t, w: WorldRoot2D, a: IsoArea, p: Node2D, rec: Dictionary, save_shots: bool) -> Dictionary:
	var fp: Vector2i = GameData.footprint_of(str(rec["id"]))
	var poly: PackedVector2Array = Iso.iso_footprint(rec["cell"], fp.x, fp.y)
	var left: Vector2 = a.to_global(poly[3])
	var bottom: Vector2 = a.to_global(poly[2])
	var right: Vector2 = a.to_global(poly[1])
	var line_of: Callable = func(x: float) -> float:
		var y: float = bottom.y - Iso.squash() * absf(x - bottom.x)
		if x < bottom.x:
			y = maxf(y, left.y)
		elif x > bottom.x:
			y = maxf(y, right.y)
		return y
	var strips: Array[Dictionary] = []
	var images: Dictionary = {}
	for n in rec["nodes"]:
		var spr: Sprite2D = n as Sprite2D
		if spr == null or not (spr.texture is AtlasTexture):
			continue
		var at: AtlasTexture = spr.texture
		if not images.has(at.atlas):
			var img: Image = at.atlas.get_image()
			if img.is_compressed():
				img.decompress()
			images[at.atlas] = img
		strips.append({"node": spr, "region": at.region, "image": images[at.atlas], "sort_y": float(line_of.call(spr.global_position.x))})
	# the prop under test stands alone with the figure: every other prop, sign, NPC ... of the area is hidden for the probes (a tree
	# in front of the left face would hide part of the figure for reasons that have nothing to do with these strips)
	var hidden_others: Array[CanvasItem] = []
	for other in a.objects.get_children():
		if other is CanvasItem and (other as CanvasItem).visible and other != p and not (other in rec["nodes"]):
			(other as CanvasItem).visible = false
			hidden_others.append(other as CanvasItem)
	var cam: Camera2D = p.get("camera")
	var rows: Array[String] = []
	var ok: bool = strips.size() >= 5
	var counts: Dictionary = {"hidden": 0, "clear": 0, "partial": 0}
	var worst: float = 0.0
	var xs: Array[float] = [bottom.x, bottom.x + 0.55 * (right.x - bottom.x), bottom.x + 0.55 * (left.x - bottom.x)]
	var xnames: Array[String] = ["corner", "right", "left"]
	for xi in xs.size():
		for off in [-40.0, -6.0, 6.0, 40.0]:
			var feet := Vector2(xs[xi], float(line_of.call(xs[xi])) + off)
			p.global_position = feet
			cam.reset_smoothing()
			for st in strips:
				(st["node"] as Sprite2D).visible = false
			await t.seconds(0.25)
			var free_img: Image = await t.capture("")
			for st2 in strips:
				(st2["node"] as Sprite2D).visible = true
			await t.frames(1)
			var shot: String = "sort_%s_%s_%+d" % [rec["id"], xnames[xi], int(off)] if save_shots and absf(off) < 10.0 else ""
			var with_img: Image = await t.capture(shot)
			var ct: Transform2D = w.get_viewport().get_canvas_transform()
			var inv: Transform2D = ct.affine_inverse()
			var pc: Vector2 = ct * p.global_position
			var front: Array[Dictionary] = []
			for st3 in strips:
				if float(st3["sort_y"]) > feet.y:
					front.append(st3)
			var figure: int = 0
			var hidden_px: int = 0
			var visible_px: int = 0
			var bad: int = 0
			for dy in range(-130, -1, 3):
				for dx in range(-64, 65, 3):
					var px := Vector2i(int(pc.x) + dx, int(pc.y) + dy)
					if px.x < 0 or px.y < 0 or px.x >= free_img.get_width() or px.y >= free_img.get_height():
						continue
					var fc: Color = free_img.get_pixelv(px)
					# a SOLID figure pixel: the sprite is modulated to (1, 0, 1), so its green is 0; the antialiased fringe has green from the
					# background, and the background differs between the two renders (the house stands behind the fringe)
					if not (fc.g < 0.1 and fc.r > 0.4 and fc.b > 0.25):
						continue
					figure += 1
					var wpt: Vector2 = inv * Vector2(px)
					var a_lo: float = 1.0
					var a_hi: float = 0.0
					for cross in [Vector2.ZERO, Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
						var al: float = _strips_alpha(front, wpt + (cross as Vector2))
						a_lo = minf(a_lo, al)
						a_hi = maxf(a_hi, al)
					var wc: Color = with_img.get_pixelv(px)
					var kept: bool = maxf(absf(wc.r - fc.r), maxf(absf(wc.g - fc.g), absf(wc.b - fc.b))) < 0.12
					if a_lo >= 0.95:
						hidden_px += 1
						if kept:
							bad += 1
					elif a_hi <= 0.05:
						visible_px += 1
						if not kept:
							bad += 1
			var judged: int = hidden_px + visible_px
			var tol: int = maxi(3, int(ceil(0.04 * float(judged))))
			var agree: bool = figure >= 20 and judged >= int(0.6 * float(figure)) and bad <= tol
			ok = ok and agree
			worst = maxf(worst, float(bad) / maxf(float(judged), 1.0))
			if float(visible_px) <= 0.25 * float(figure):
				counts["hidden"] += 1
			elif float(visible_px) >= 0.9 * float(figure):
				counts["clear"] += 1
			else:
				counts["partial"] += 1
			rows.append("%s %+d: %d visible %d hidden of %d%s" % [xnames[xi], int(off), visible_px, hidden_px, figure, "" if agree else " MISMATCH (%d wrong)" % bad])
	for other2 in hidden_others:
		other2.visible = true
	return {"ok": ok, "hidden": counts["hidden"], "clear": counts["clear"], "partial": counts["partial"], "worst": worst, "summary": "%d strips, visible / hidden pixels of the figure: %s" % [strips.size(), ", ".join(rows)]}


## Alpha of the strips (Array of {node, region, image}) at a GLOBAL point: 0 outside every strip.
func _strips_alpha(strips: Array[Dictionary], wpt: Vector2) -> float:
	for st in strips:
		var node: Sprite2D = st["node"]
		var lp: Vector2 = wpt - (node.global_position + node.offset)
		var reg: Rect2 = st["region"]
		if lp.x >= 0.0 and lp.y >= 0.0 and lp.x < reg.size.x and lp.y < reg.size.y:
			return (st["image"] as Image).get_pixel(int(reg.position.x + lp.x), int(reg.position.y + lp.y)).a
	return 0.0


## The seam probe of R.6: across the SE and SW borders of neighbouring grass cells the luminance may not step more than it does
## across the middle of a tile (a hairline or a block edge shows as an EXCESS over that control). Returns {border, control}: the
## median of |L(edge) - mean(L(left), L(right))| over five points along every border and over the same points across tile middles.
func _seam_step(w: WorldRoot2D, a: IsoArea, img: Image, inject: float = 0.0) -> Dictionary:
	var ct: Transform2D = w.get_viewport().get_canvas_transform()
	var borders: Array[float] = []
	var controls: Array[float] = []
	var pairs: int = 0
	var size: Vector2 = Vector2(img.get_size())
	for y in range(1, a.map.height - 1):
		for x in range(1, a.map.width - 1):
			var c := Vector2i(x, y)
			if a.cell_kind(c) != &"grass":
				continue
			var clear: bool = true
			for rec in a.prop_nodes:
				var pc: Vector2i = rec["cell"]
				if absi(pc.x - x) <= 1 and absi(pc.y - y) <= 1:
					clear = false
			for m in a.markers:
				var mc: Vector2i = m["cell"]
				if absi(mc.x - x) <= 1 and absi(mc.y - y) <= 1:
					clear = false
			if not clear:
				continue
			for step in [Vector2i(1, 0), Vector2i(0, 1)]:
				if a.cell_kind(c + step) != &"grass":
					continue
				var p0: Vector2 = ct * a.cell_to_global(c)
				var p1: Vector2 = ct * a.cell_to_global(c + step)
				if p0.x < 40.0 or p1.x < 40.0 or p0.x > size.x - 40.0 or p1.x > size.x - 40.0 or p0.y < 40.0 or p1.y < 40.0 or p0.y > size.y - 40.0 or p1.y > size.y - 40.0:
					continue
				var n: Vector2 = (p1 - p0).normalized()
				var tangent := Vector2(-n.y, n.x)
				var mid: Vector2 = (p0 + p1) * 0.5
				var reach: float = 74.0 * ct.get_scale().x * 0.12
				for k in range(-2, 3):
					if inject > 0.0:   # negative control: a deliberate hairline of `inject` luminance on the border samples
						var hp := Vector2i(mid + tangent * reach * float(k))
						var hc: Color = img.get_pixelv(hp)
						img.set_pixelv(hp, Color(hc.r - inject, hc.g - inject, hc.b - inject))
					borders.append(_step_at(img, mid + tangent * reach * float(k), n))
					controls.append(_step_at(img, p0 + tangent * reach * float(k), n))
				pairs += 1
	_last_pairs = pairs
	# a hairline would lift EVERY border sample, so compare the medians (tufts, props and the player disturb only a few samples)
	borders.sort()
	controls.sort()
	return {"border": borders[borders.size() / 2] if pairs > 0 else 0.0, "control": controls[controls.size() / 2] if pairs > 0 else 0.0}


var _last_pairs: int = 0


func _step_at(img: Image, at: Vector2, normal: Vector2) -> float:
	var la: float = _luma(img.get_pixelv(Vector2i(at + normal * 4.0)))
	var lb: float = _luma(img.get_pixelv(Vector2i(at - normal * 4.0)))
	var le: float = _luma(img.get_pixelv(Vector2i(at)))
	return absf(le - (la + lb) * 0.5)


# ================================================================== the section as test builder / marker handler / intro script

## `@builder res://tests/sections/area.gd`: header-only areas call this (the contract of the home interior of F6).
static func build(area: IsoArea, header: Dictionary) -> void:
	built_calls.append({"area": area, "header": header})
	var ts_src: int = AreaTileSet.source_for(&"iso", &"floor_plank")
	for y in range(2, 6):
		for x in range(2, 6):
			area.ground.set_cell(Vector2i(x, y), ts_src, Vector2i(x % 4, y % 4))
	area.bounds = Rect2(-300, -200, 3000, 2400)
	area.zoom_default = 0.55
	area.play_rect = Rect2(0, 0, 600, 400)
	if not (header.get("extra", {}) as Dictionary).has("nospawn"):
		area.spawns["default"] = Vector2(300, 200)
	if not (header.get("extra", {}) as Dictionary).has("anywhere"):
		area.walkable_test = func(p: Vector2) -> bool: return area.play_rect.has_point(p)


## A Lua-registered marker handler (marker_handlers.lua): create_marker(params, pos, cell, area).
static func create_marker(params: Dictionary, pos: Vector2, cell: Vector2i, area: IsoArea) -> Node:
	made_markers.append(params.duplicate())
	var n := Node2D.new()
	n.name = "Made_%s_%d_%d" % [params.get("marker", "?"), cell.x, cell.y]
	return n


## The opening hook script of the checks (an inner class, so the section's own `run(t)` is never mistaken for it).
class FakeIntro extends RefCounted:
	static func run(world: Node) -> void:
		world.set_meta("intro_calls", int(world.get_meta("intro_calls", 0)) + 1)
